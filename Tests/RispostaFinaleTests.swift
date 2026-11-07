import XCTest

/// 2.1 «Una risposta, sette stati»: RispostaFinale (shared/risposta-finale.md), la parola, la forma e il colore di ogni
/// stato, il token unico della ZTL non attiva e la distanza d'avviso del valutatore di minaccia. Gli stessi controlli su
/// Android (RispostaFinaleTest.kt); i casi su posti veri sono in SharedEngineCasesTests (shared/engine-cases.json)
final class RispostaFinaleTests: XCTestCase {
    private let zone = SampleData.sectorA
    private var unofficialZone: Zone { var z = SampleData.sectorA; z.source.official = false; return z }

    private func a(_ v: Verdict, on: Bool = true, doubt: Motivo? = nil) -> Answer {
        Answer(verdict: v, gatesOn: on, nextChange: nil, doubt: doubt)
    }
    private let yes = Verdict.yes(reason: "r"), no = Verdict.no(reason: "r")
    private let cond = Verdict.conditional(reason: "r", condition: "c"), unsure = Verdict.unsure(reason: "r")

    func testSevenStatesFromTheEngine() {
        XCTAssertEqual(RispostaFinale.of(a(no), zone: zone).stato, .nonEntrare)
        XCTAssertEqual(RispostaFinale.of(a(cond), zone: zone).stato, .condizione)
        XCTAssertEqual(RispostaFinale.of(a(yes), zone: zone).stato, .entraPure)
        XCTAssertEqual(RispostaFinale.of(a(yes, on: false), zone: zone).stato, .ztlNonAttiva)
        let holiday = RispostaFinale.of(a(unsure, doubt: .festivo), zone: zone)
        XCTAssertEqual(holiday.stato, .controllaCartello)
        XCTAssertEqual(holiday.motivo, .festivo)
        XCTAssertEqual(holiday.reasonLine, L("Holiday not confirmed"))
        XCTAssertEqual(RispostaFinale.of(a(unsure), zone: zone).motivo, .nonSicuro)
        XCTAssertEqual(RispostaFinale.of(a(unsure, doubt: .scaduti), zone: zone).motivo, .scaduti)
        // Fonte non ufficiale: il «sì» è «Controlla il cartello», il «no» resta rosso (Salerno resta rossa)
        XCTAssertEqual(RispostaFinale.of(a(yes), zone: unofficialZone).stato, .controllaCartello)
        XCTAssertEqual(RispostaFinale.of(a(yes, on: false), zone: unofficialZone).motivo, .nonUfficiale)
        let salerno = RispostaFinale.of(a(no), zone: unofficialZone)
        XCTAssertEqual(salerno.stato, .nonEntrare)
        XCTAssertEqual(salerno.color, .rosso)
        XCTAssertNil(salerno.motivo)
        XCTAssertEqual(salerno.reasonLine, L("Probably not · unofficial source"))
        // Città di esempio: mai verde
        XCTAssertEqual(RispostaFinale.of(a(yes), zone: zone, status: .sample).stato, .controllaCartello)
        // Area pedonale: sempre «Non entrare»
        XCTAssertEqual(RispostaFinale.of(a(yes, on: false), zone: zone, pedestrian: true).stato, .nonEntrare)
    }

    func testPlaceStates() {
        let city = SampleData.florence
        let place = Place(name: "Prova", address: "", location: city.center)
        XCTAssertEqual(PlaceCheck(place: place, hits: [], answer: nil, covered: true).finale.stato, .fuoriZTL)
        XCTAssertEqual(PlaceCheck(place: place, hits: [], answer: nil, covered: false).finale.stato, .nonCoperto)
        let area = PedestrianArea(id: "p", name: "Via Prova", perimeter: zone.perimeter)
        XCTAssertEqual(PlaceCheck(place: place, hits: [(city: city, zone: zone)], pedestrian: area, answer: a(yes)).finale.stato, .nonEntrare)
        // La peggiore tra le zone decide
        var other = zone; other.id = "altra"
        let worst = PlaceCheck(place: place, hits: [(city: city, zone: zone), (city: city, zone: other)], answers: [a(yes, on: false), a(no)])
        XCTAssertEqual(worst.finale.stato, .nonEntrare)
        XCTAssertEqual(worst.finale.zoneId, "altra")
    }

    /// Parola, forma e colore: mai due stati uguali, mai solo colore
    func testWordShapeAndColour() {
        XCTAssertEqual(Stato.allCases.count, 7)
        XCTAssertEqual(Set(Stato.allCases.map(\.word)).count, 7, "una parola per stato")
        XCTAssertEqual(Set(Stato.allCases.map { "\($0.symbol)|\($0.color)|\($0.dashed)" }).count, 7)
        XCTAssertEqual(Stato.ztlNonAttiva.tono, .spento)
        XCTAssertEqual(Stato.ztlNonAttiva.color, RispostaFinale.stateOff, "un solo token")
        XCTAssertEqual(RispostaFinale.stateOff, .verde, "oggi verde per regola di Ledion")
        XCTAssertEqual(Stato.fuoriZTL.color, .grigio)
        XCTAssertEqual(Stato.nonCoperto.color, .neutro)
        XCTAssertTrue(Stato.nonCoperto.dashed)
        // Mai verde per quello che non sappiamo
        for s in [Stato.nonCoperto, .controllaCartello, .condizione, .fuoriZTL] { XCTAssertNotEqual(s.color, .verde, "\(s)") }
        XCTAssertEqual(Stato.allCases.filter(\.alerts), [.nonEntrare, .condizione, .controllaCartello])
        XCTAssertEqual(Motivo.allCases.count, 5)
        XCTAssertEqual(Set(Motivo.allCases.map(\.label)).count, 5)
    }

    /// Le parole e i motivi in tutte le lingue, con le righe uguali al titolo
    func testWordsInEveryLanguage() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        for lang in ["it", "de", "fr", "es", "nl", "pl", "zh-Hans"] {
            let url = root.appendingPathComponent("Resources/Localizations/\(lang).lproj/Localizable.strings")
            let t = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String], lang)
            for s in Stato.allCases {
                let title = try XCTUnwrap(t[s.word.key], "\(lang): \(s.word.key)")
                let lines = try XCTUnwrap(t[s.word.lineKey], "\(lang): \(s.word.lineKey)")
                XCTAssertEqual(lines.replacingOccurrences(of: "|", with: "").replacingOccurrences(of: " ", with: ""),
                               title.replacingOccurrences(of: " ", with: ""), "\(lang): «\(lines)»")
            }
            for m in Motivo.allCases { XCTAssertNotNil(t[m.key], "\(lang): \(m.key)") }
            XCTAssertNotNil(t["Alerts 300 m before a ZTL, 600 m above 50 km/h"], lang)
        }
    }

    /// Decisione 9: 300 m in città, 600 m sopra 50 km/h, per guida, guardiano e avvisi ad app chiusa
    func testAlertDistance() {
        XCTAssertEqual(ThreatEvaluator.alertDistance(speed: nil), 300)
        XCTAssertEqual(ThreatEvaluator.alertDistance(speed: -1), 300)
        XCTAssertEqual(ThreatEvaluator.alertDistance(speed: 13), 300)
        XCTAssertEqual(ThreatEvaluator.alertDistance(speed: 14), 600, "sopra 50 km/h")
    }

    /// Il titolo dell'avviso viene dalla RispostaFinale: mai un avviso per «Entra pure» né per la ZTL non attiva
    func testThreatTitleFromTheAnswer() {
        let c = ThreatCandidate(zone: zone, cityName: "Firenze")
        let p = Coordinate(lat: 43.77, lon: 11.25)
        XCTAssertEqual(ZoneThreat(candidate: c, meters: 200, answer: a(no), point: p).title, L("Don't enter") + " · " + c.name)
        XCTAssertEqual(ZoneThreat(candidate: c, meters: 200, answer: a(unsure, doubt: .festivo), point: p).finale.motivo, .festivo)
        XCTAssertNil(ZoneThreat(candidate: c, meters: 200, answer: a(yes), point: p).title)
        XCTAssertNil(ZoneThreat(candidate: c, meters: 200, answer: a(yes, on: false), point: p).title)
        let u = ThreatCandidate(zone: unofficialZone, cityName: "Firenze")
        XCTAssertEqual(ZoneThreat(candidate: u, meters: 200, answer: a(yes, on: false), point: p).title, L("Check the sign") + " · " + u.name)
    }

    /// Il motivo del «?» va nella riga sotto, mai nel titolo
    func testReasonGoesUnderTheTitle() {
        let city = SampleData.florence
        let place = Place(name: "Prova", address: "", location: city.center)
        let stale = PlaceCheck(place: place, hits: [(city: city, zone: zone)], answer: a(.unsure(reason: "Vecchi."), doubt: .scaduti))
        XCTAssertEqual(stale.word, .checkSign)
        XCTAssertEqual(stale.explanation, L("Data out of date") + " · Vecchi.")
        XCTAssertEqual(Home2Answer(stale, now: Date()).headline, L("Check the sign"))
    }
}
