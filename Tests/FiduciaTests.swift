import XCTest

/// 2.0.2 «Fiducia»: gli stessi casi di Android e del sito (shared/fiducia-cases.json): la data dell'ultimo controllo sotto
/// la risposta, «Non ancora verificata a mano», il link per l'hotel o il noleggio. E il colore della risposta non cambia
final class FiduciaTests: XCTestCase {
    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

    private func cases() throws -> [String: Any] {
        let data = try Data(contentsOf: Self.root.appendingPathComponent("shared/fiducia-cases.json"))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private static func date(_ s: String?) -> Date? {
        guard let s else { return nil }
        return ISO8601DateFormatter().date(from: s)
    }

    private static func source(_ j: [String: Any]) -> Source {
        Source(authority: "City of Florence", pageURL: URL(string: "https://www.comune.fi.it/")!,
               ordinance: nil, ordinanceURL: nil, quote: nil, quoteTranslation: nil,
               checkedOn: date(j["checkedOn"] as? String)!,
               reviewedByHuman: j["reviewedByHuman"] as? Bool ?? false,
               pending: [], links: [],
               verifiedOn: date(j["verifiedOn"] as? String),
               pageChanged: j["pageChanged"] as? Bool)
    }

    func testControlCases() throws {
        let list = try XCTUnwrap(try cases()["control"] as? [[String: Any]])
        XCTAssertGreaterThanOrEqual(list.count, 8)
        for c in list {
            let id = c["id"] as? String ?? "?"
            let now = try XCTUnwrap(Self.date(c["now"] as? String), id)
            let got = Fiducia.control(Self.source(try XCTUnwrap(c["source"] as? [String: Any])), now: now)
            let e = try XCTUnwrap(c["expect"] as? [String: Any])
            XCTAssertEqual(got.when.rawValue, e["when"] as? String, id)
            XCTAssertEqual(got.label, e["label"] as? String, id)
            XCTAssertEqual(got.fresh, e["fresh"] as? Bool, id)
            XCTAssertEqual(got.byHand, e["byHand"] as? Bool, id)
        }
    }

    func testShareCases() throws {
        let file = try cases()
        XCTAssertEqual(file["site"] as? String, Fiducia.site)
        XCTAssertEqual(file["siteVehicles"] as? [String], Fiducia.siteVehicles)
        for c in try XCTUnwrap(file["share"] as? [[String: Any]]) {
            let id = c["id"] as? String ?? "?"
            let v = try XCTUnwrap(c["vehicle"] as? [String: Any])
            let key = Fiducia.vehicleKey(fuel: v["fuel"] as? String ?? "", euro: v["euro"] as? Int ?? 0,
                                         motorcycle: v["type"] as? String == "motorcycle", unknown: v["unknown"] as? Bool ?? false)
            let p = c["place"] as? [String: Any]
            let url = Fiducia.shareURL(lang: c["lang"] as? String ?? "en", cityId: c["city"] as? String,
                                       placeName: p?["name"] as? String, lat: p?["lat"] as? Double, lon: p?["lon"] as? Double,
                                       vehicleKey: key)
            XCTAssertEqual(url, c["expect"] as? String, id)
        }
    }

    /// Il testo condiviso ha il link e dice che non serve installare nulla; il veicolo «Non so» non va nel link
    func testShareTextAndUnknownVehicle() {
        let t = Fiducia.shareText(name: "Hotel Brunelleschi", url: "https://lr-apps609.github.io/GateLR/it/#p=1")
        XCTAssertTrue(t.hasSuffix("\nhttps://lr-apps609.github.io/GateLR/it/#p=1"))
        XCTAssertTrue(t.contains("Hotel Brunelleschi"))
        var v = Vehicle(name: "Golf", fuel: .diesel, euro: 6)
        XCTAssertEqual(Fiducia.vehicleKey(v), "diesel-6")
        v.euroUnknown = true
        XCTAssertNil(Fiducia.vehicleKey(v))
    }

    /// La verifica a mano non cambia la risposta (la regola «mai verde se non verificata» non è stata decisa)
    func testByHandDoesNotChangeTheAnswer() throws {
        var engine = RuleEngine()
        let now = try XCTUnwrap(Self.date("2026-11-12T09:00:00Z"))
        engine.now = { now }
        var s = Self.source(["checkedOn": "2026-10-23T12:00:00Z", "reviewedByHuman": false])
        let before = engine.trust(s)
        s.reviewedByHuman = true
        XCTAssertEqual(engine.trust(s), before)
    }

    /// I testi nuovi in tutte le lingue dell'app
    func testStringsInEveryLanguage() throws {
        let dir = Self.root.appendingPathComponent("Resources/Localizations")
        let langs = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasSuffix(".lproj") && $0 != "en.lproj" && $0 != "Base.lproj" }
        XCTAssertGreaterThanOrEqual(langs.count, 7)
        for l in langs {
            let file = dir.appendingPathComponent(l).appendingPathComponent("Localizable.strings")
            let table = try XCTUnwrap(NSDictionary(contentsOf: file) as? [String: String], l)
            for k in ["Last checked today", "Last checked yesterday", "Last checked %@", "Not yet verified by hand", "Source: %@",
                      "Send it to your hotel / rental", "How we check the data", "What to do if you get a fine"] {
                XCTAssertFalse((table[k] ?? "").isEmpty, "\(l): manca «\(k)»")
            }
        }
    }

    /// iPhone alla pari con Android e il sito: la riga sotto la risposta in Adesso e nella scheda della zona, le due pagine
    /// da Aiuto e da Informazioni; in Adesso dopo i pulsanti della risposta (la risposta resta prima di tutto)
    func testFooterIsWhereTheAnswerIs() throws {
        func src(_ f: String) throws -> String { try String(contentsOf: Self.root.appendingPathComponent("Sources/" + f), encoding: .utf8) }
        let varco = try src("VarcoView.swift")
        XCTAssertTrue(varco.contains("FiduciaFooter("))
        let actions = try XCTUnwrap(varco.range(of: "            actions(check)\n"))
        let footer = try XCTUnwrap(varco.range(of: "if !compact { fiducia(check) }"))
        XCTAssertLessThan(actions.lowerBound, footer.lowerBound, "la riga della fiducia va dopo i pulsanti della risposta")
        XCTAssertTrue(try src("ZoneDetailView.swift").contains("FiduciaFooter("))
        let help = try src("HelpView.swift"), about = try src("AboutView.swift")
        XCTAssertTrue(help.contains("FiduciaPageView(page: .checks)") && help.contains("FiduciaPageView(page: .fine)"))
        XCTAssertTrue(about.contains("FiduciaPageView(page: .checks)") && about.contains("FiduciaPageView(page: .fine)"))
    }

    /// Le due pagine: «Come controlliamo i dati» ha cinque sezioni; quella delle multe i ricorsi con le fonti ufficiali
    func testPages() {
        XCTAssertEqual(FiduciaPageView.sections(.checks).count, 5)
        XCTAssertEqual(FiduciaPageView.sections(.fine).count, 4)
        XCTAssertTrue(Fiducia.fineSources.contains { $0.url.host == "www.normattiva.it" && $0.url.absoluteString.hasSuffix("art203") })
        XCTAssertTrue(Fiducia.fineSources.contains { $0.url.absoluteString.hasSuffix("art204bis") })
    }
}
