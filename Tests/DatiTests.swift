import XCTest
import CryptoKit

/// 1.20.1 «Dati»: «letto il» non è «verificato il»; regole non verificate, verificate da più di 120 giorni o con la pagina
/// del Comune cambiata dopo la verifica non danno mai verde né grigio; i dati scaricati valgono solo se firmati
final class DatiTests: XCTestCase {
    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    private static let citiesDir = root.appendingPathComponent("Resources/Cities")
    private let cal = RuleEngine.rome

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    private func zoneA() throws -> Zone {
        let city = try CityLoader.decode(Data(contentsOf: Self.citiesDir.appendingPathComponent("firenze.json")))
        return try XCTUnwrap(city.zones.first { $0.id == "firenze-a" })
    }

    private var engine: RuleEngine {
        var e = RuleEngine()
        let now = date(2026, 11, 3, 12)
        e.now = { now }
        return e
    }

    private let car = Vehicle(name: "Rental car", fuel: .petrol, euro: 6)
    private var night: Date { date(2026, 11, 10, 23) }     // Settore A spento
    private var day: Date { date(2026, 11, 10, 10) }       // Settore A acceso

    // MARK: Verificato il

    /// Nei file nessuna zona ha una data di verifica (non si inventa): sono tutte «non verificate»
    func testNoVerificationDatesInTheData() throws {
        let files = try FileManager.default.contentsOfDirectory(at: Self.citiesDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" && $0.lastPathComponent != "manifest.json" }
        XCTAssertGreaterThan(files.count, 40)
        for f in files {
            let city = try CityLoader.decode(Data(contentsOf: f))
            for z in city.zones {
                XCTAssertNil(z.source.verifiedOn, z.id)
                XCTAssertEqual(engine.trust(z), .unverified, z.id)
            }
        }
    }

    func testUnverifiedYesIsNeverGreenNorGrey() throws {
        var z = try zoneA()
        z.source.verifiedOn = nil
        guard case .yes = engine.answer(zone: z, vehicle: car, permits: [], hotelInside: false, at: night).verdict else { return XCTFail("la regola: ZTL spenta") }
        let shown = engine.trustedAnswer(zone: z, vehicle: car, permits: [], hotelInside: false, at: night)
        guard case .unsure(let why) = shown.verdict else { return XCTFail("atteso non sicuro, ottenuto \(shown.verdict)") }
        XCTAssertTrue(why.hasPrefix(L("This rule hasn't been verified yet: check the sign.")), why)
        XCTAssertFalse(shown.gatesOn)
        XCTAssertEqual(Access.of(shown, zone: z, status: .draft), .check)
        // Un «no» non verificato resta «no»: la prudenza non diventa un via libera
        guard case .no = engine.trustedAnswer(zone: z, vehicle: car, permits: [], hotelInside: false, at: day).verdict else { return XCTFail("atteso no") }
    }

    func testVerificationAge() throws {
        var z = try zoneA()
        z.source.verifiedOn = date(2026, 7, 10, 12)        // 116 giorni prima
        XCTAssertEqual(engine.trust(z), .verified)
        guard case .yes = engine.trustedAnswer(zone: z, vehicle: car, permits: [], hotelInside: false, at: night).verdict else { return XCTFail("verificata da poco: sì") }
        XCTAssertEqual(Access.of(engine.trustedAnswer(zone: z, vehicle: car, permits: [], hotelInside: false, at: night), zone: z, status: .draft), .off)
        z.source.verifiedOn = date(2026, 6, 30, 12)        // 126 giorni prima
        XCTAssertEqual(engine.trust(z), .old)
        guard case .unsure(let why) = engine.trustedAnswer(zone: z, vehicle: car, permits: [], hotelInside: false, at: night).verdict else { return XCTFail("verifica vecchia: non sicuro") }
        XCTAssertTrue(why.hasPrefix(String(format: L("Last verified more than %lld days ago: check the sign."), 120)), why)
    }

    /// La pagina del Comune è cambiata dopo la verifica: tutte le risposte gialle con il «?», anche il «no»
    func testChangedPageMakesEverythingUnsure() throws {
        var z = try zoneA()
        z.source.verifiedOn = date(2026, 10, 30, 12)
        z.source.pageChanged = true
        XCTAssertEqual(engine.trust(z), .pageChanged)
        for t in [day, night] {
            let a = engine.trustedAnswer(zone: z, vehicle: car, permits: [], hotelInside: false, at: t)
            guard case .unsure(let why) = a.verdict else { return XCTFail("\(t): atteso non sicuro, ottenuto \(a.verdict)") }
            XCTAssertTrue(why.hasPrefix(L("The city's page has changed: check the sign.")), why)
            XCTAssertEqual(Access.of(a, zone: z, status: .draft), .check)
        }
        XCTAssertEqual(engine.verifiedSentence(z.source), L("The city's page has changed since it was verified: check the sign."))
    }

    /// Le zone da fonti non ufficiali restano come prima (il «sì» lo fa giallo Verdict.shown, il «no» resta «no»)
    func testUnofficialUnchanged() throws {
        let city = try CityLoader.decode(Data(contentsOf: Self.citiesDir.appendingPathComponent("salerno.json")))
        let z = try XCTUnwrap(city.zones.first)
        XCTAssertEqual(engine.answer(zone: z, vehicle: car, permits: [], hotelInside: false, at: night),
                       engine.trustedAnswer(zone: z, vehicle: car, permits: [], hotelInside: false, at: night))
    }

    /// Il campo si legge dai file (formato di Tools/source_trust.py)
    func testVerifiedOnDecodes() throws {
        let json = """
        {"authority": "City", "pageURL": "https://www.comune.example.it", "checkedOn": "2026-10-23T12:00:00Z", "reviewedByHuman": true,
         "pending": [], "links": [], "verifiedOn": "2026-11-01T09:30:00Z", "verifiedFingerprints": {"https://www.comune.example.it": "abcd"}, "pageChanged": true}
        """
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
        let s = try d.decode(Source.self, from: Data(json.utf8))
        XCTAssertEqual(s.verifiedOn, ISO8601DateFormatter().date(from: "2026-11-01T09:30:00Z"))
        XCTAssertEqual(s.verifiedFingerprints?["https://www.comune.example.it"], "abcd")
        XCTAssertEqual(s.pageChanged, true)
    }

    // MARK: Firma dei dati scaricati

    /// Una firma fatta con Tools/sign_cities.py (Python, «cryptography») con una chiave di prova buttata via: CryptoKit la
    /// accetta, quindi le firme del workflow valgono nell'app
    func testSignatureFromToolsIsAccepted() throws {
        let key = try XCTUnwrap(CitySignature.key(fromFile: "# prova\nrGGbD01Ipm0WWBrE6QK0B8HTUZ8YmRW0wKoUl17fcO0=\n"))
        let manifest = Data("{\"version\": \"test\"}\n".utf8)
        let sig = Data("MVCeTpR2X0O5S81ia7HN7k7573Ikk2rYtaYTvJVFk/4qsXEDfdLM0GE0QJDb8mi4W7u9chLwxRRdCF4zABtjCg==\n".utf8)
        XCTAssertTrue(CitySignature.isValid(manifest: manifest, signature: sig, key: key))
        XCTAssertFalse(CitySignature.isValid(manifest: Data("{\"version\": \"tesT\"}\n".utf8), signature: sig, key: key))
        XCTAssertFalse(CitySignature.isValid(manifest: manifest, signature: sig, key: nil), "senza chiave nell'app niente è valido")
        XCTAssertFalse(CitySignature.isValid(manifest: manifest, signature: Data(), key: key))
        XCTAssertNil(CitySignature.key(fromFile: "# solo commenti\n"))
    }

    /// La chiave nel repository ha solo commenti finché Ledion non la crea: l'app non accetta niente (e non si rompe)
    func testRepositoryKeyFileParses() throws {
        let text = try String(contentsOf: Self.root.appendingPathComponent("shared/city-signing-key.txt"), encoding: .utf8)
        let line = text.split(whereSeparator: \.isNewline).map(String.init).first { !$0.hasPrefix("#") && !$0.isEmpty }
        if line != nil { XCTAssertNotNil(CitySignature.key(fromFile: text), "riga della chiave non valida") }
    }

    private func writeDownload(_ dir: URL, key: Curve25519.Signing.PrivateKey?, tamper: Bool = false) throws -> Data {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let city = try Data(contentsOf: Self.citiesDir.appendingPathComponent("siena.json"))
        try city.write(to: dir.appendingPathComponent("siena.json"))
        let manifest = Data("""
        {"version": "209901010000", "digest": "x", "schema": 1, "cities": [{"id": "siena", "file": "siena.json", "sha256": "\(CitySignature.sha256(city))"}]}
        """.utf8)
        try manifest.write(to: dir.appendingPathComponent("manifest.json"))
        if let key {
            let sig = try key.signature(for: CitySignature.context + manifest)
            try Data(sig.base64EncodedString().utf8).write(to: dir.appendingPathComponent("manifest.sig"))
        }
        if tamper { try (city + Data(" ".utf8)).write(to: dir.appendingPathComponent("siena.json")) }
        return manifest
    }

    func testSignedDownloadIsUsedUnsignedIgnored() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("dati-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: base) }
        let priv = Curve25519.Signing.PrivateKey()
        let pub = priv.publicKey

        let good = base.appendingPathComponent("good")
        _ = try writeDownload(good, key: priv)
        let v = try XCTUnwrap(CitySignature.verifiedDownload(in: good, key: pub))
        XCTAssertEqual(v.version, "209901010000")
        XCTAssertEqual(v.files.map(\.name), ["siena.json"])
        XCTAssertEqual(CityLoader.decoded(v)?.first?.id, "siena")

        // Come le versioni fino alla 1.20.0: città scaricate senza firma → ignorate
        let unsigned = base.appendingPathComponent("unsigned")
        _ = try writeDownload(unsigned, key: nil)
        XCTAssertNil(CitySignature.verifiedDownload(in: unsigned, key: pub))
        // Firma di un'altra chiave
        XCTAssertNil(CitySignature.verifiedDownload(in: good, key: Curve25519.Signing.PrivateKey().publicKey))
        // Nessuna chiave nell'app
        XCTAssertNil(CitySignature.verifiedDownload(in: good, key: nil))
        // Un file cambiato dopo la firma (impronta diversa dal manifest firmato)
        let tampered = base.appendingPathComponent("tampered")
        _ = try writeDownload(tampered, key: priv, tamper: true)
        XCTAssertNil(CitySignature.verifiedDownload(in: tampered, key: pub))
        // Un manifest cambiato dopo la firma
        let edited = base.appendingPathComponent("edited")
        let m = try writeDownload(edited, key: priv)
        try (m + Data("\n".utf8)).write(to: edited.appendingPathComponent("manifest.json"))
        XCTAssertNil(CitySignature.verifiedDownload(in: edited, key: pub))
    }

    func testFileNamesStayInTheFolder() {
        XCTAssertTrue(CitySignature.isPlainFileName("firenze.json"))
        for bad in ["../firenze.json", "a/b.json", ".hidden.json", "firenze.txt", ""] {
            XCTAssertFalse(CitySignature.isPlainFileName(bad), bad)
        }
    }
}
