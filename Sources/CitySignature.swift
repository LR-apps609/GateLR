import Foundation
import CryptoKit

/// 1.20.1 «Dati»: i dati delle città scaricati da GitHub si usano solo se FIRMATI. Il workflow «Firma dei dati delle città»
/// firma Resources/Cities/manifest.json (Tools/sign_cities.py, Ed25519, chiave privata nel segreto CITY_DATA_SIGNING_KEY,
/// mai nel repository) e scrive la firma in manifest.sig. Il manifest ha la versione e l'impronta SHA-256 di ogni città:
/// con la firma giusta e le impronte giuste i file sono quelli firmati. Altrimenti (firma mancante, sbagliata, chiave
/// pubblica assente nell'app, file diverso) l'aggiornamento si ignora e restano i dati che l'app ha: quelli dentro l'app
/// o l'ultimo aggiornamento firmato. Mai dati non firmati in silenzio.
enum CitySignature {
    /// Davanti al manifest prima di firmarlo (lo stesso in Tools/sign_cities.py): una firma fatta per altro non vale qui
    static let context = Data("GateLR-cities-v1\n".utf8)
    static let manifestFile = "manifest.json"
    static let signatureFile = "manifest.sig"

    /// La chiave pubblica dentro l'app: shared/city-signing-key.txt (copiato nell'app e nel widget, project.yml).
    /// nil finché il file non ha la chiave: allora nessun aggiornamento scaricato è accettato
    static let bundledKey: Curve25519.Signing.PublicKey? = {
        guard let url = Bundle.main.url(forResource: "city-signing-key", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return key(fromFile: text)
    }()

    /// La prima riga che non è vuota né un commento (#): 32 byte in base64
    static func key(fromFile text: String) -> Curve25519.Signing.PublicKey? {
        let line = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty && !$0.hasPrefix("#") }
        guard let line, let raw = Data(base64Encoded: line) else { return nil }
        return try? Curve25519.Signing.PublicKey(rawRepresentation: raw)
    }

    /// La firma (manifest.sig: 64 byte in base64) vale per questo manifest, byte per byte
    static func isValid(manifest: Data, signature: Data, key: Curve25519.Signing.PublicKey?) -> Bool {
        guard let key, let text = String(data: signature, encoding: .utf8),
              let sig = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines)), sig.count == 64 else { return false }
        return key.isValidSignature(sig, for: context + manifest)
    }

    static func sha256(_ d: Data) -> String {
        SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined()
    }

    /// Un nome di file del manifest che resta nella cartella delle città («firenze.json», mai «../x» o una sottocartella)
    static func isPlainFileName(_ name: String) -> Bool {
        !name.isEmpty && !name.hasPrefix(".") && !name.contains("/") && !name.contains("\\") && name.hasSuffix(".json")
    }

    /// Un aggiornamento salvato sul telefono che si può usare: firma valida e ogni file con la sua impronta
    struct Verified {
        var version: String
        /// I file delle città, nell'ordine del manifest
        var files: [(name: String, data: Data)]
    }

    /// Controlla la cartella degli aggiornamenti (manifest.json, manifest.sig e le città). nil = niente da usare
    static func verifiedDownload(in dir: URL?, key: Curve25519.Signing.PublicKey? = bundledKey) -> Verified? {
        guard let dir,
              let manifest = try? Data(contentsOf: dir.appendingPathComponent(manifestFile)),
              let signature = try? Data(contentsOf: dir.appendingPathComponent(signatureFile)),
              isValid(manifest: manifest, signature: signature, key: key),
              let m = try? JSONDecoder().decode(CityLoader.Manifest.self, from: manifest), m.schema == 1 else { return nil }
        var files: [(name: String, data: Data)] = []
        for e in m.allCities {
            guard isPlainFileName(e.file), let d = try? Data(contentsOf: dir.appendingPathComponent(e.file)), sha256(d) == e.sha256 else { return nil }
            files.append((e.file, d))
        }
        return Verified(version: m.version, files: files)
    }
}
