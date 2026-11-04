import Foundation
import CryptoKit
import WidgetKit

/// Aggiornamento dei dati delle città senza una nuova versione dell'app: si legge l'elenco su GitHub
/// (Resources/Cities/manifest.json); se è più nuovo, si scaricano le città, si controlla l'impronta
/// e che si leggano bene, e solo allora si salvano. Alla prossima apertura l'app usa i dati nuovi.
/// 1.20.1 «Dati»: l'elenco deve essere FIRMATO (manifest.sig, CitySignature): senza firma o con una firma sbagliata non si
/// scarica niente, lo stato è «Non firmati: restano i tuoi dati» e l'app resta con quelli che ha.
@MainActor
final class CityUpdater: ObservableObject {
    static let shared = CityUpdater()
    nonisolated static let base = URL(string: "https://raw.githubusercontent.com/LR-apps609/GateLR/main/Resources/Cities/")!
    /// 1.19.5: ogni richiesta al più 20 secondi (prima il minuto di iOS, e lo scaricamento intero poteva durare di più)
    nonisolated static let timeout: TimeInterval = 20
    /// L'ETag dell'ultimo elenco letto: se GitHub risponde «non cambiato» (304) non si scarica niente
    /// 1.20.1: chiave nuova, così l'ETag salvato dalle versioni senza firma non fa saltare il primo controllo firmato
    nonisolated static let etagKey = "cities.manifestETag.signed"

    /// «rejected» (1.20.1): l'elenco su GitHub non è firmato o la firma non vale: niente scaricato, restano i dati che ci sono
    enum State: Equatable { case idle, checking, upToDate, updated(String), failed, rejected }
    @Published private(set) var state: State = .idle
    @Published private(set) var lastCheck: Date? = UserDefaults.standard.object(forKey: "cities.lastCheck") as? Date

    /// La versione dell'ultimo aggiornamento firmato sul telefono, letta una volta (controllare firma e impronte costa)
    private var signedVersion: String? = CityLoader.verifiedDownloadedVersion

    /// La versione dei dati in uso (l'aggiornamento firmato o i dati dentro l'app). Un aggiornamento senza firma delle
    /// versioni fino alla 1.20.0 non conta: l'app non lo usa
    var currentVersion: String {
        max(signedVersion ?? "", CityLoader.bundledVersion ?? "")
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
            // 1.19.5: richiesta condizionale (If-None-Match): con l'elenco uguale GitHub risponde 304 senza mandarlo
            var req = Self.request(Self.base.appendingPathComponent("manifest.json"))
            let etag = UserDefaults.standard.string(forKey: Self.etagKey)
            if let etag { req.setValue(etag, forHTTPHeaderField: "If-None-Match") }
            let (data, response) = try await URLSession.shared.data(for: req)
            let http = response as? HTTPURLResponse
            if http?.statusCode == 304 { state = .upToDate; return }
            guard http == nil || http?.statusCode == 200 else { state = .failed; return }
            let newTag = http?.value(forHTTPHeaderField: "ETag")
            let manifest = try JSONDecoder().decode(CityLoader.Manifest.self, from: data)
            guard manifest.schema == 1, manifest.version > currentVersion else {
                state = .upToDate
                Self.saveETag(newTag)
                return
            }
            // 1.20.1: prima di scaricare le città, la firma dell'elenco (che ha l'impronta di ogni città). Senza firma
            // valida niente: l'ETag non si salva, così al prossimo controllo si riprova (la firma arriva dal workflow
            // qualche minuto dopo le città)
            let (signature, sigResponse) = try await URLSession.shared.data(for: Self.request(Self.base.appendingPathComponent(CitySignature.signatureFile)))
            let sigCode = (sigResponse as? HTTPURLResponse)?.statusCode
            guard sigCode == nil || sigCode == 200, CitySignature.isValid(manifest: data, signature: signature, key: CitySignature.bundledKey) else {
                state = .rejected
                return
            }
            // Anche le città con zone da fonti non ufficiali: questa versione mostra l'avviso (vedi Manifest.unofficialCities).
            // 1.19.5: insieme invece che una dopo l'altra, e quelle che il telefono ha già uguali (stessa impronta, nell'app
            // o già scaricate) non si scaricano di nuovo
            let entries = manifest.allCities
            let files: [(String, Data, String)] = try await withThrowingTaskGroup(of: (Int, String, Data, String).self) { group in
                for (i, entry) in entries.enumerated() {
                    group.addTask {
                        if let local = Self.localCopy(entry) { return (i, entry.file, local, entry.sha256) }
                        let (d, r) = try await URLSession.shared.data(for: Self.request(Self.base.appendingPathComponent(entry.file)))
                        if let code = (r as? HTTPURLResponse)?.statusCode, code != 200 { throw URLError(.badServerResponse) }
                        return (i, entry.file, d, entry.sha256)
                    }
                }
                var out = [(String, Data, String)?](repeating: nil, count: entries.count)
                for try await (i, file, d, sha) in group { out[i] = (file, d, sha) }
                return out.compactMap { $0 }
            }
            // Impronta, prova di lettura, salvataggio e nuova lettura delle città: tutto fuori dal thread principale
            // (prima si faceva qui, sul principale, e al ritorno dell'app la bloccava per qualche istante)
            let version = manifest.version, all = files, signedManifest = data
            let fresh: [City]? = try await Task.detached(priority: .utility) { () throws -> [City]? in
                for (name, d, sha) in all {
                    guard CitySignature.isPlainFileName(name), CitySignature.sha256(d) == sha,
                          (try? CityLoader.decode(d))?.zones.isEmpty == false else { return nil }
                }
                guard let dir = CityLoader.downloadDir else { return nil }
                try? FileManager.default.removeItem(at: dir)
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                for (name, d, _) in all { try d.write(to: dir.appendingPathComponent(name), options: .atomic) }
                // Elenco e firma accanto alle città: a ogni apertura (app e widget) CityLoader.best() li ricontrolla
                try signedManifest.write(to: dir.appendingPathComponent(CitySignature.manifestFile), options: .atomic)
                try signature.write(to: dir.appendingPathComponent(CitySignature.signatureFile), options: .atomic)
                CityLoader.setDownloadedVersion(version)
                return CityLoader.best()
            }.value
            guard let fresh else { state = .failed; return }
            signedVersion = version
            Self.saveETag(newTag)
            store.replaceCities(fresh)
            state = .updated(manifest.version)
            // 1.19.3: il widget legge le stesse città (App Group): si ricalcola subito con i dati nuovi
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            state = .failed
        }
    }

    /// Una richiesta a GitHub con il tempo massimo, senza la copia di iOS (la decide l'ETag)
    nonisolated static func request(_ url: URL) -> URLRequest {
        var r = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        return r
    }

    nonisolated static func saveETag(_ tag: String?) {
        if let tag, !tag.isEmpty { UserDefaults.standard.set(tag, forKey: etagKey) }
    }

    /// La città già sul telefono con la stessa impronta (scaricata prima o dentro l'app): non serve scaricarla
    nonisolated static func localCopy(_ entry: CityLoader.Manifest.Entry) -> Data? {
        let candidates = [CityLoader.downloadDir?.appendingPathComponent(entry.file),
                          Bundle.main.url(forResource: entry.file, withExtension: nil, subdirectory: "Cities")].compactMap { $0 }
        for url in candidates {
            guard let d = try? Data(contentsOf: url) else { continue }
            if CitySignature.sha256(d) == entry.sha256 { return d }
        }
        return nil
    }


    nonisolated static func sha256(_ d: Data) -> String { CitySignature.sha256(d) }

    /// «24 ott 2026, 06:44» da «202610240644»
    static func label(_ version: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyyMMddHHmm"; f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: version)?.formatted(date: .abbreviated, time: .shortened) ?? version
    }
}
