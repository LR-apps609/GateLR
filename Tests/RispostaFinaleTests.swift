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

    /// Il titolo dell'avviso viene dalla RispostaFinale: mai un avviso per «Puoi entrare» né per la ZTL non attiva
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

    /// B09: la distanza da un perimetro si misura dal lato, non dal vertice (lato lungo di un rettangolo di 1 km)
    func testDistanceFromTheSide() {
        let ring = [Coordinate(lat: 45.0, lon: 7.0), Coordinate(lat: 45.0, lon: 7.0127),
                    Coordinate(lat: 45.009, lon: 7.0127), Coordinate(lat: 45.009, lon: 7.0)]
        let p = Coordinate(lat: 44.99991, lon: 7.00635)
        XCTAssertEqual(PerimeterMath.nearest(ring, to: p).meters, 10, accuracy: 2)
        XCTAssertEqual(ThreatEvaluator.nearestPoint(ring, to: p).meters, 10, accuracy: 2)
        var z = zone; z.perimeter = ring
        XCTAssertEqual(z.distance(lat: p.lat, lon: p.lon), 10, accuracy: 2)
    }

    /// B26: senza un posto la luce della zona scelta viene dalla RispostaFinale: dati non sicuri o fonte non ufficiale
    /// ambra, mai verde
    func testCityMoodFromTheAnswer() {
        XCTAssertEqual(Home2Answer.Mood(RispostaFinale.of(a(yes, on: false), zone: unofficialZone).color), .amber)
        XCTAssertEqual(Home2Answer.Mood(RispostaFinale.of(a(unsure, on: false, doubt: .scaduti), zone: zone).color), .amber)
        XCTAssertEqual(Home2Answer.Mood(RispostaFinale.of(a(no), zone: zone).color), .red)
        XCTAssertEqual(Home2Answer.Mood(RispostaFinale.of(a(yes, on: false), zone: zone).color), .green, "ZTL non attiva: oggi verde")
    }

    /// B22: fuori dalle zone di una città da fonti non ufficiali «Controlla il cartello», mai «Fuori dalla ZTL» verde
    func testOutsideUnofficialCity() {
        let place = Place(name: "Prova", address: "", location: SampleData.florence.center)
        let check = PlaceCheck(place: place, hits: [], answers: [], covered: true, coverUnofficial: true)
        XCTAssertEqual(check.finale.stato, .controllaCartello)
        XCTAssertEqual(check.finale.motivo, .nonUfficiale)
        XCTAssertEqual(check.access, .check)
        XCTAssertTrue(check.unofficial)
        XCTAssertEqual(Home2Answer(check, now: Date()).mood, .amber)
    }

    /// B24: il 4 ottobre è festa nazionale dal 2026
    func testFourthOfOctober() {
        let cal = RuleEngine.rome
        func d(_ y: Int) -> Date { cal.date(from: DateComponents(year: y, month: 10, day: 4, hour: 12))! }
        XCTAssertTrue(ItalianHolidays.isHoliday(d(2027), calendar: cal))     // lunedì
        XCTAssertFalse(ItalianHolidays.isHoliday(d(2025), calendar: cal))
    }

    /// B33: i giorni si contano a blocchi di 24 ore, come Android e il sito
    func testDaysAre24HourBlocks() {
        let read = ISO8601DateFormatter().date(from: "2026-07-10T10:00:00Z")!
        let now = ISO8601DateFormatter().date(from: "2026-11-08T10:30:00Z")!
        XCTAssertEqual(RuleEngine.days(from: read, to: now), 121)
    }

    /// Avvisi in auto: l'hotel della meta vale all'ora d'ARRIVO (il soggiorno conta solo vicino alle sue date), non «adesso»
    @MainActor
    func testThreatAnswerUsesTheArrivalTimeForTheHotel() async throws {
        let store = Store()
        await store.whenLoaded()
        let saved = (store.trips, store.stays)
        defer { store.trips = saved.0; store.stays = saved.1 }
        func d(_ m: Int, _ day: Int, _ h: Int) -> Date { RuleEngine.rome.date(from: DateComponents(year: 2026, month: m, day: day, hour: h))! }
        let place = Place(name: "Hotel", address: "", location: Coordinate(lat: 43.7731, lon: 11.2560))
        let hit = try XCTUnwrap(store.zones(at: place.location).first { $0.zone.hotelCanRegister })
        store.trips = []
        store.stays = [place.key: HotelStay(arrival: d(11, 20, 15), departure: d(11, 22, 10), status: .asked)]
        let c = ThreatCandidate(zone: hit.zone, cityName: hit.city.localizedName)
        let atArrival = store.threatAnswer(c, at: d(11, 20, 15), destination: place)
        let later = store.threatAnswer(c, at: d(12, 15, 15), destination: place)
        // 2.3 (decisione di Ledion del 09/11): chiesto ma non confermato = «Non entrare» con «Chiedi all'hotel…»
        guard case .no = atArrival.verdict else { return XCTFail("all'arrivo: non entrare (hotel senza conferma), ottenuto \(atArrival.verdict)") }
        XCTAssertEqual(atArrival.hotel, .daChiedere)
        XCTAssertNil(later.hotel, "lontano dal soggiorno l'hotel non vale più")
    }
}
