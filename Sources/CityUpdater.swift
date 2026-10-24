import Foundation
import CryptoKit

/// Aggiornamento dei dati delle città senza una nuova versione dell'app: si legge l'elenco su GitHub
/// (Resources/Cities/manifest.json); se è più nuovo, si scaricano le città, si controlla l'impronta
/// e che si leggano bene, e solo allora si salvano. Alla prossima apertura l'app usa i dati nuovi.
@MainActor
final class CityUpdater: ObservableObject {
    static let shared = CityUpdater()
    static let base = URL(string: "https://raw.githubusercontent.com/LR-apps609/GateLR/main/Resources/Cities/")!

    enum State: Equatable { case idle, checking, upToDate, updated(String), failed }
    @Published private(set) var state: State = .idle
    @Published private(set) var lastCheck: Date? = UserDefaults.standard.object(forKey: "cities.lastCheck") as? Date

    /// La versione dei dati in uso (scaricati o dentro l'app)
    var currentVersion: String {
        max(CityLoader.downloadedVersion ?? "", CityLoader.bundledVersion ?? "")
    }

    /// Al più una volta ogni 12 ore, all'apertura dell'app
    func checkIfDue(store: Store) async {
        if let lastCheck, Date().timeIntervalSince(lastCheck) < 12 * 3600 { return }
        await check(store: store)
    }

    func check(store: Store) async {
        guard state != .checking, !ProcessInfo.processInfo.arguments.contains("-uitest") else { return }
        state = .checking
        defer {
            lastCheck = Date()
            UserDefaults.standard.set(lastCheck, forKey: "cities.lastCheck")
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: Self.base.appendingPathComponent("manifest.json"))
            let manifest = try JSONDecoder().decode(CityLoader.Manifest.self, from: data)
            guard manifest.schema == 1, manifest.version > currentVersion else { state = .upToDate; return }
            var files: [(String, Data, String)] = []
            for entry in manifest.cities {
                let (d, _) = try await URLSession.shared.data(from: Self.base.appendingPathComponent(entry.file))
                files.append((entry.file, d, entry.sha256))
            }
            // Impronta, prova di lettura, salvataggio e nuova lettura delle città: tutto fuori dal thread principale
            // (prima si faceva qui, sul principale, e al ritorno dell'app la bloccava per qualche istante)
            let version = manifest.version, all = files
            let fresh: [City]? = try await Task.detached(priority: .utility) { () throws -> [City]? in
                for (_, d, sha) in all {
                    let hash = SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined()
                    guard hash == sha, (try? CityLoader.decode(d))?.zones.isEmpty == false else { return nil }
                }
                guard let dir = CityLoader.downloadDir else { return nil }
                try? FileManager.default.removeItem(at: dir)
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                for (name, d, _) in all { try d.write(to: dir.appendingPathComponent(name), options: .atomic) }
                UserDefaults.standard.set(version, forKey: "cities.version")
                return CityLoader.best()
            }.value
            guard let fresh else { state = .failed; return }
            store.cities = fresh
            state = .updated(manifest.version)
        } catch {
            state = .failed
        }
    }

    /// «24 ott 2026, 06:44» da «202610240644»
    static func label(_ version: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyyMMddHHmm"; f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: version)?.formatted(date: .abbreviated, time: .shortened) ?? version
    }
}
