import XCTest
import CryptoKit

/// 1.16.2: zone con regole solo da fonti non ufficiali (source.official = false). L'avviso ovunque si vede la risposta,
/// le parole più prudenti («Probabilmente…»), la stessa risposta del motore, e le app vecchie che non le vedono mai.
final class UnofficialSourceTests: XCTestCase {
    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    private static let cities = root.appendingPathComponent("Resources/Cities")

    /// lucca.json com'è, o con «official» e «unofficialSource» aggiunti alla fonte della prima zona
    private func lucca(official: Bool? = nil, site: Bool = false) throws -> City {
        var json = try String(contentsOf: Self.cities.appendingPathComponent("lucca.json"), encoding: .utf8)
        var extra = ""
        if let official { extra += "\"official\": \(official), " }
        if site { extra += "\"unofficialSource\": {\"name\": \"Guida di prova\", \"url\": \"https://example.org/lucca\"}, " }
        if !extra.isEmpty, let r = json.range(of: "\"reviewedByHuman\"") { json.replaceSubrange(r, with: extra + "\"reviewedByHuman\"") }
        return try CityLoader.decode(Data(json.utf8))
    }

    func testMissingFieldMeansOfficial() throws {
        let c = try lucca()
        XCTAssertNil(c.zones[0].source.official)
        XCTAssertNil(c.zones[0].source.unofficialSource)
        XCTAssertTrue(c.zones[0].source.isOfficial)
        XCTAssertFalse(c.hasUnofficialZones)
    }

    func testExplicitTrueIsOfficial() throws {
        let c = try lucca(official: true)
        XCTAssertEqual(c.zones[0].source.official, true)
        XCTAssertFalse(c.zones[0].isUnofficial)
    }

    func testFalseWithSiteDecodes() throws {
        let c = try lucca(official: false, site: true)
        let z = c.zones[0]
        XCTAssertTrue(z.isUnofficial)
        XCTAssertEqual(z.source.unofficialSource?.name, "Guida di prova")
        XCTAssertEqual(z.source.unofficialSource?.url.absoluteString, "https://example.org/lucca")
        XCTAssertTrue(c.hasUnofficialZones)
        XCTAssertFalse(c.zones.dropFirst().contains(where: \.isUnofficial))
    }

    /// Tutte le città dell'app si leggono e la promessa vale: chi sta in «cities» non ha zone non ufficiali
    /// (le leggono le app fino alla 1.16.1, che non mostrano l'avviso); chi ne ha sta in «unofficialCities»
    func testManifestKeepsUnofficialCitiesAwayFromOldApps() throws {
        let m = try JSONDecoder().decode(CityLoader.Manifest.self, from: Data(contentsOf: Self.cities.appendingPathComponent("manifest.json")))
        XCTAssertEqual(m.schema, 1, "Con uno schema diverso le app vecchie smettono di aggiornare anche le città ufficiali")
        for e in m.cities {
            let c = try CityLoader.decode(Data(contentsOf: Self.cities.appendingPathComponent(e.file)))
            XCTAssertFalse(c.hasUnofficialZones, "\(e.file) ha zone non ufficiali: rilancia Tools/build_manifest.py")
        }
        for e in m.unofficialCities ?? [] {
            let c = try CityLoader.decode(Data(contentsOf: Self.cities.appendingPathComponent(e.file)))
            XCTAssertTrue(c.hasUnofficialZones, "\(e.file) è tutta ufficiale: va in «cities»")
            let data = try Data(contentsOf: Self.cities.appendingPathComponent(e.file))
            let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            XCTAssertEqual(hash, e.sha256, "Rilancia Tools/build_manifest.py dopo aver cambiato \(e.file)")
        }
        XCTAssertEqual(m.allCities.count, m.cities.count + (m.unofficialCities?.count ?? 0))
        // Ogni file delle città è in una delle due liste
        let files = try FileManager.default.contentsOfDirectory(atPath: Self.cities.path).filter { $0.hasSuffix(".json") && $0 != "manifest.json" }
        XCTAssertEqual(Set(files), Set(m.allCities.map(\.file)))
    }

    /// Il manifest di prima (senza la chiave nuova) si legge ancora; con la chiave nuova la 1.16.2 scarica anche quelle
    func testManifestWithAndWithoutNewKey() throws {
        let old = #"{"version":"1","digest":"x","schema":1,"cities":[{"id":"a","file":"a.json","sha256":"0"}]}"#
        let m1 = try JSONDecoder().decode(CityLoader.Manifest.self, from: Data(old.utf8))
        XCTAssertNil(m1.unofficialCities)
        XCTAssertEqual(m1.allCities.map(\.id), ["a"])
        let new = #"{"version":"2","digest":"y","schema":1,"cities":[{"id":"a","file":"a.json","sha256":"0"}],"unofficialCities":[{"id":"b","file":"b.json","sha256":"1"}]}"#
        let m2 = try JSONDecoder().decode(CityLoader.Manifest.self, from: Data(new.utf8))
        XCTAssertEqual(m2.cities.map(\.id), ["a"])               // quello che vede un'app fino alla 1.16.1
        XCTAssertEqual(m2.allCities.map(\.id), ["a", "b"])
    }

    /// Varco: l'avviso c'è, il titolo è prudente; il «no» resta rosso, il «sì» diventa giallo (1.19.0: mai un verde
    /// che non sappiamo), il testo del pannello resta lo stato vero dei varchi
    func testVarcoAnswerShowsBannerAndSoftensWording() throws {
        let official = try lucca(), unofficial = try lucca(official: false, site: true)
        let place = Place(name: "Prova", address: "", location: unofficial.center)
        for (verdict, gatesOn) in [(Verdict.no(reason: "r"), true), (Verdict.yes(reason: "r"), false)] {
            let answer = Answer(verdict: verdict, gatesOn: gatesOn, nextChange: nil)
            let a = Home2Answer(PlaceCheck(place: place, hits: [(city: official, zone: official.zones[0])], answer: answer), now: Date())
            let b = Home2Answer(PlaceCheck(place: place, hits: [(city: unofficial, zone: unofficial.zones[0])], answer: answer), now: Date())
            XCTAssertFalse(a.unofficial)
            XCTAssertTrue(b.unofficial)
            XCTAssertEqual(b.unofficialSource?.name, "Guida di prova")
            if gatesOn {
                XCTAssertEqual(a.mood, b.mood)
                XCTAssertEqual(a.panel, b.panel)
            } else {
                XCTAssertEqual(a.mood, .green)
                XCTAssertEqual(b.mood, .amber)
                XCTAssertEqual(a.panel.lines, b.panel.lines)
                XCTAssertEqual(b.panel.mood, .amber)
            }
            XCTAssertNotEqual(a.headline, b.headline)
            XCTAssertEqual(b.headline, gatesOn ? L("Probably not.") : L("Probably yes."))
            let check = PlaceCheck(place: place, hits: [(city: unofficial, zone: unofficial.zones[0])], answer: answer)
            XCTAssertTrue(check.unofficial)
            XCTAssertEqual(check.callout, gatesOn ? L("Probably not") : L("Probably yes"))
        }
        // Condizioni e «non sicuro» sono già prudenti: le parole non cambiano
        let cond = Answer(verdict: .conditional(reason: "r", condition: "c"), gatesOn: true, nextChange: nil)
        let c = Home2Answer(PlaceCheck(place: place, hits: [(city: unofficial, zone: unofficial.zones[0])], answer: cond), now: Date())
        XCTAssertEqual(c.headline, L("You can enter, on one condition:"))
        XCTAssertEqual(c.detail, "c")      // 1.17.2: la condizione sotto il titolo, sempre in vista
        XCTAssertTrue(c.unofficial)
    }

    func testVerdictShortTextOnlyHedgesYesAndNo() {
        XCTAssertEqual(Verdict.yes(reason: "").shortText(unofficial: false), Verdict.yes(reason: "").short)
        XCTAssertEqual(Verdict.yes(reason: "").shortText(unofficial: true), L("Probably yes"))
        XCTAssertEqual(Verdict.no(reason: "").shortText(unofficial: true), L("Probably not"))
        XCTAssertEqual(Verdict.unsure(reason: "").shortText(unofficial: true), Verdict.unsure(reason: "").short)
        XCTAssertEqual(Verdict.no(reason: "").titleLines(unofficial: true), [L("Probably not.")])
    }

    /// «Entra pure.» sopra «Accesso vietato · Settore A» si leggeva male: ora «ZTL · Settore A»
    func testZoneLineReadsNaturally() throws {
        let firenze = try CityLoader.decode(Data(contentsOf: Self.cities.appendingPathComponent("firenze.json")))
        let a = try XCTUnwrap(firenze.zones.first { $0.letter == "A" })
        XCTAssertEqual(a.kindLine, "ZTL · " + a.shortName)
        XCTAssertFalse(a.kindLine.contains(ZoneKind.restricted.title))
        let milano = try CityLoader.decode(Data(contentsOf: Self.cities.appendingPathComponent("milano.json")))
        let c = try XCTUnwrap(milano.zones.first { $0.id == "milano-c" })
        XCTAssertEqual(c.kindLine, L("Paid ZTL") + " · " + c.shortName)
        // Il nome dice già ZTL: non si ripete
        let ferrara = try CityLoader.decode(Data(contentsOf: Self.cities.appendingPathComponent("ferrara.json")))
        XCTAssertFalse(ferrara.zones[0].kindLine.hasPrefix(L("Paid ZTL")))
        let place = Place(name: "Prova", address: "", location: firenze.center)
        let check = PlaceCheck(place: place, hits: [(city: firenze, zone: a)], answer: Answer(verdict: .yes(reason: ""), gatesOn: false, nextChange: nil))
        XCTAssertEqual(check.zoneLine, a.kindLine)
    }
}
