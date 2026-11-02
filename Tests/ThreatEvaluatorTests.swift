import XCTest

/// 1.19.3 «Un solo avviso»: il valutatore comune a guida, guardiano e avvisi ad app chiusa (ThreatEvaluator), il
/// «una volta per avvicinamento» (ThreatDeduper), lo stato a riposo del guardiano e la risposta del widget (WidgetAnswer)
final class ThreatEvaluatorTests: XCTestCase {
    private let engine: RuleEngine = {
        var e = RuleEngine()
        let today = RuleEngine.rome.date(from: DateComponents(year: 2026, month: 10, day: 30, hour: 12))!
        e.now = { today }
        return e
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        RuleEngine.rome.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    /// Dove si guida: 200 m a sud di una zona quadrata stretta (80 m di larghezza, 200 m di altezza)
    private let here = Coordinate(lat: 43.8000, lon: 11.2500)
    private var square: [Coordinate] {
        [Coordinate(lat: 43.8018, lon: 11.2495), Coordinate(lat: 43.8018, lon: 11.2505),
         Coordinate(lat: 43.8036, lon: 11.2505), Coordinate(lat: 43.8036, lon: 11.2495)]
    }

    private func zone(official: Bool = true) -> Zone {
        var z = SampleData.sectorA
        z.id = "test-zone"
        z.perimeter = square
        z.source.official = official
        z.source.checkedOn = engine.now()
        z.prepare()
        return z
    }

    private func candidate(_ z: Zone) -> ThreatCandidate { ThreatCandidate(zone: z, cityName: "Firenze") }

    private let no = Answer(verdict: .no(reason: "La ZTL è attiva."), gatesOn: true, nextChange: nil)
    private let yes = Answer(verdict: .yes(reason: "La ZTL non è attiva."), gatesOn: false, nextChange: nil)

    private func scan(_ c: ThreatCandidate, course: Double?, last: [String: Double] = [:], covered: Bool = true,
                      answer: Answer? = nil) -> ThreatEvaluator.Scan {
        let a = answer ?? no
        return ThreatEvaluator.scan(at: here, course: course, candidates: [c], last: last, covered: covered) { _, _ in a }
    }

    // MARK: Direzione

    /// Solo le zone davanti nel verso di marcia: verso nord sì, verso sud o di lato no
    func testOnlyZonesAhead() {
        let c = candidate(zone())
        let ahead = scan(c, course: 0)
        XCTAssertNotNil(ahead.threat)
        XCTAssertEqual(ahead.threat?.meters ?? 0, 200, accuracy: 15)
        XCTAssertNil(scan(c, course: 180).threat, "zona alle spalle")
        XCTAssertNil(scan(c, course: 90).threat, "zona di lato")
        XCTAssertNotNil(scan(c, course: 350).threat, "leggermente a sinistra è ancora davanti")
    }

    /// Senza direzione: prudente al primo punto, poi solo se ti avvicini
    func testUnknownCourseIsConservative() {
        let c = candidate(zone())
        XCTAssertNotNil(scan(c, course: nil).threat, "primo punto senza direzione: si avvisa")
        XCTAssertNotNil(scan(c, course: nil, last: [c.id: 400]).threat, "ti avvicini")
        XCTAssertNil(scan(c, course: nil, last: [c.id: 150]).threat, "ti allontani")
        XCTAssertNotNil(scan(c, course: -1).threat, "rotta -1 (GPS senza direzione) = sconosciuta")
    }

    /// Bearing e angoli
    func testBearing() {
        XCTAssertEqual(ThreatEvaluator.bearing(here, Coordinate(lat: 43.81, lon: 11.25)), 0, accuracy: 0.5)
        XCTAssertEqual(ThreatEvaluator.bearing(here, Coordinate(lat: 43.80, lon: 11.26)), 90, accuracy: 0.5)
        XCTAssertEqual(ThreatEvaluator.angle(350, 10), 20, accuracy: 0.001)
        XCTAssertEqual(ThreatEvaluator.angle(90, 270), 180, accuracy: 0.001)
        XCTAssertTrue(ThreatEvaluator.isAhead(from: here, to: here, meters: 10, course: 180, approaching: false), "ci sei sopra")
    }

    // MARK: Una volta per avvicinamento

    func testDedupeOncePerApproach() {
        var d = ThreatDeduper()
        let t0 = date(2026, 10, 30, 10)
        XCTAssertTrue(d.shouldAlert("firenze-a", now: t0))
        XCTAssertFalse(d.shouldAlert("firenze-a", now: t0.addingTimeInterval(60)), "stesso avvicinamento")
        XCTAssertTrue(d.shouldAlert("firenze-b", now: t0.addingTimeInterval(60)), "un'altra zona")
        // Ancora vicino: niente di nuovo
        d.moved(["firenze-a": 400])
        XCTAssertFalse(d.shouldAlert("firenze-a", now: t0.addingTimeInterval(120)))
        // Ti allontani oltre 900 m: il prossimo avvicinamento avvisa di nuovo
        d.moved(["firenze-a": 1_200])
        XCTAssertTrue(d.shouldAlert("firenze-a", now: t0.addingTimeInterval(180)))
        // Dopo 30 minuti anche senza allontanarsi (avvisi ad app chiusa, senza distanze)
        XCTAssertTrue(d.shouldAlert("firenze-a", now: t0.addingTimeInterval(180 + 31 * 60)))
        // Le chiavi con il prefisso («in|») seguono la loro zona
        XCTAssertTrue(d.shouldAlert("in|firenze-c", now: t0))
        d.moved(["firenze-c": 2_000])
        XCTAssertTrue(d.shouldAlert("in|firenze-c", now: t0.addingTimeInterval(5)))
    }

    // MARK: Le parole e i colori

    /// L'area pedonale vince: sempre «Non entrare», rosso, anche se il motore dice «sì»
    func testPedestrianAlwaysStops() {
        let area = PedestrianArea(id: "via-prova", name: "Via Prova", perimeter: square)
        let c = ThreatCandidate(zone: RouteCheck.pedestrianZone(area, checkedOn: engine.now()), cityName: "Bologna", pedestrian: area)
        let t = scan(c, course: 0, answer: yes).threat
        XCTAssertNotNil(t, "l'area pedonale avvisa anche con un «sì» del motore")
        XCTAssertEqual(t?.level, .stop)
        XCTAssertEqual(t?.title, String(format: L("Don't enter · %@"), String(format: L("Pedestrian area · %@"), "Via Prova")))
        XCTAssertEqual(t?.spoken, L("Don't enter"))
    }

    /// Fonte non ufficiale: un «sì» è giallo con il «?» e avvisa («? Controlla il cartello»); un «no» resta rosso, detto con prudenza
    func testUnofficialYesIsYellow() {
        let c = candidate(zone(official: false))
        let t = scan(c, course: 0, answer: yes).threat
        XCTAssertEqual(t?.level, .check)
        XCTAssertEqual(t?.title, String(format: L("? Check the sign · %@"), c.name))
        XCTAssertEqual(t?.spoken, L("Probably yes · unofficial source: check the sign"))
        let red = scan(c, course: 0, answer: no).threat
        XCTAssertEqual(red?.level, .stop)
        XCTAssertEqual(red?.title, String(format: L("Probably not · %@"), c.name))
        // Ufficiale e «sì»: nessun avviso, mai un avviso verde
        XCTAssertNil(scan(candidate(zone()), course: 0, answer: yes).threat)
    }

    /// I titoli con le parole della risposta: mai verde, mai «ZTL attiva» fisso
    func testTitleWords() {
        let c = candidate(zone())
        XCTAssertEqual(c.name, "Firenze " + c.zone.shortName)
        XCTAssertEqual(ThreatEvaluator.title(shown: .no(reason: ""), candidate: c), String(format: L("Don't enter · %@"), c.name))
        XCTAssertEqual(ThreatEvaluator.title(shown: .conditional(reason: "", condition: "ticket"), candidate: c),
                       String(format: L("You can enter on one condition: %@"), c.name))
        XCTAssertEqual(ThreatEvaluator.title(shown: .unsure(reason: ""), candidate: c), String(format: L("? Check the sign · %@"), c.name))
        XCTAssertNil(ThreatEvaluator.title(shown: .yes(reason: ""), candidate: c))
        // Il corpo: la distanza, la condizione, il tocco per i parcheggi
        let cond = Answer(verdict: .conditional(reason: "La ZTL è attiva.", condition: "Solo con il biglietto."), gatesOn: true, nextChange: nil)
        let t = scan(c, course: 0, answer: cond).threat
        XCTAssertEqual(t?.level, .condition)
        XCTAssertTrue(t?.body.contains("Solo con il biglietto.") == true)
        XCTAssertTrue(t?.body.hasSuffix(L("Tap for car parks outside.")) == true)
    }

    /// Fuori dalle città che conosciamo il riposo è neutro (mai lo scudo verde); dentro grigio «Nessuna ZTL attiva davanti»
    func testUncoveredRestingIsNeutral() {
        let c = candidate(zone())
        XCTAssertEqual(scan(c, course: 180, covered: false).resting, .unknownPlace)
        XCTAssertEqual(scan(c, course: 180, covered: true).resting, .clear)
        let unknown = Guardian.state(threat: nil, resting: .unknownPlace)
        XCTAssertEqual(unknown.level, "none")
        XCTAssertEqual(unknown.instruction, L("We don't know the ZTLs of this place"))
        let clear = Guardian.state(threat: nil, resting: .clear)
        XCTAssertEqual(clear.level, "clear")
        XCTAssertEqual(clear.instruction, L("No active ZTL ahead"))
        XCTAssertNotEqual(clear.symbol, "checkmark.shield.fill")
        // Con una zona davanti: il colore della risposta
        let t = scan(c, course: 0).threat!
        XCTAssertEqual(Guardian.state(threat: t, resting: .clear).level, "no")
    }

    /// Ingresso in una zona dove non si entra: segnalato una volta (passaggio da fuori a dentro)
    func testEnteredZone() {
        let c = candidate(zone())
        let inside = Coordinate(lat: 43.8027, lon: 11.2500)
        let s = ThreatEvaluator.scan(at: inside, course: 0, candidates: [c], last: [c.id: 50], covered: true) { _, _ in self.no }
        XCTAssertEqual(s.entered.map(\.zone.id), [c.id])
        XCTAssertNil(s.threat)
        let again = ThreatEvaluator.scan(at: inside, course: 0, candidates: [c], last: s.distances, covered: true) { _, _ in self.no }
        XCTAssertTrue(again.entered.isEmpty)
    }

    // MARK: Avvisi ad app chiusa

    /// Il varco: davanti e da fuori; la direzione conta; senza posizione recente si avvisa (prudente)
    func testGateMonitorDirection() {
        let c = candidate(zone())
        let gate = Gate(id: "g", name: "Via Prova", location: Coordinate(lat: 43.8018, lon: 11.2500))
        let answer: (ThreatCandidate, Double) -> Answer = { _, _ in self.no }
        XCTAssertNotNil(GateMonitor.threat(c, gate: gate, from: here, course: 0, alertDistance: 500, answer: answer))
        XCTAssertNil(GateMonitor.threat(c, gate: gate, from: here, course: 180, alertDistance: 500, answer: answer), "il varco è alle spalle")
        XCTAssertNotNil(GateMonitor.threat(c, gate: gate, from: here, course: nil, alertDistance: 500, answer: answer), "senza direzione: prudente")
        XCTAssertNil(GateMonitor.threat(c, gate: gate, from: Coordinate(lat: 43.8027, lon: 11.2500), course: 180, alertDistance: 500, answer: answer),
                     "dentro la zona il varco è un'uscita")
        XCTAssertNotNil(GateMonitor.threat(c, gate: gate, from: nil, course: nil, alertDistance: 500, answer: answer))
        XCTAssertNil(GateMonitor.threat(c, gate: gate, from: here, course: 0, alertDistance: 500) { _, _ in self.yes }, "verde: nessun avviso")
    }

    /// Il tocco sull'avviso: gatelr://park porta il punto e il nome per «Parcheggia fuori»
    func testParkLinkRoundTrip() throws {
        let url = try XCTUnwrap(ParkLink.url(zoneId: "firenze-a", name: "Firenze Settore A", at: Coordinate(lat: 43.7786, lon: 11.2412)))
        let place = try XCTUnwrap(ParkLink.place(from: url))
        XCTAssertEqual(place.name, "Firenze Settore A")
        XCTAssertEqual(place.location.lat, 43.7786, accuracy: 1e-6)
        XCTAssertEqual(place.location.lon, 11.2412, accuracy: 1e-6)
        XCTAssertNil(ParkLink.place(from: URL(string: "gatelr://varco")!))
    }

    // MARK: Widget

    private func widget(_ z: Zone, vehicle: Vehicle = SampleData.rental, permits: [Permit] = [], at d: Date) -> WidgetAnswer {
        WidgetAnswer.make(zone: z, cityId: "firenze", garage: SharedData.Garage(vehicle: vehicle, permits: permits, zoneId: z.id), at: d, engine: engine)
    }

    func testWidgetAnswerForVehicle() {
        let z = zone()
        let thursday10 = date(2026, 10, 29, 10), thursday22 = date(2026, 10, 29, 22)
        let red = widget(z, at: thursday10)
        XCTAssertEqual(red.tone, .red)
        XCTAssertEqual(red.title, L("Don't enter"))
        // Varchi spenti: grigio «ZTL non attiva», non verde
        let off = widget(z, at: thursday22)
        XCTAssertEqual(off.tone, .grey)
        XCTAssertEqual(off.title, L("ZTL not active"))
        // Elettrica esente a varchi accesi: verde «Puoi entrare»
        var exempt = z
        exempt.exemptFuels = [.electric]
        let ev = Vehicle(name: "EV", fuel: .electric, euro: 6)
        XCTAssertEqual(widget(exempt, vehicle: ev, at: thursday10).tone, .green)
        XCTAssertEqual(widget(exempt, vehicle: ev, at: thursday10).vehicleName, "EV")
        // Permesso confermato per QUESTA zona: verde; per un'altra zona: rosso
        let car = Vehicle(name: "Auto", fuel: .petrol, euro: 6)
        let mine = Permit(kind: .resident, cityId: "firenze", zoneId: z.id, vehicleId: car.id, from: date(2026, 1, 1, 0), to: date(2027, 1, 1, 0), status: .confirmed)
        var other = mine; other.zoneId = "firenze-b"
        XCTAssertEqual(widget(z, vehicle: car, permits: [mine], at: thursday10).tone, .green)
        XCTAssertEqual(widget(z, vehicle: car, permits: [other], at: thursday10).tone, .red)
        // Un permesso di un'altra città non conta
        var elsewhere = mine; elsewhere.cityId = "milano"
        XCTAssertEqual(widget(z, vehicle: car, permits: [elsewhere], at: thursday10).tone, .red)
    }

    /// Dati più vecchi di 120 giorni: giallo «?» «Dati da ricontrollare», anche a varchi spenti
    func testWidgetStaleIsYellow() {
        var z = zone()
        z.source.checkedOn = engine.now().addingTimeInterval(-200 * 86_400)
        let w = widget(z, at: date(2026, 10, 29, 22))
        XCTAssertTrue(w.stale)
        XCTAssertEqual(w.tone, .amber)
        XCTAssertEqual(w.symbol, "questionmark")
        XCTAssertEqual(w.title, L("Data to recheck"))
        // Fonte non ufficiale a varchi spenti: giallo, mai verde né grigio
        let u = widget(zone(official: false), at: date(2026, 10, 29, 22))
        XCTAssertEqual(u.tone, .amber)
    }

    /// Senza il garage condiviso (App Group assente): l'auto a noleggio come nell'app appena installata, mai un verde in più
    func testWidgetWithoutGarage() {
        let w = WidgetAnswer.make(zone: zone(), cityId: "firenze", garage: nil, at: date(2026, 10, 29, 10), engine: engine)
        XCTAssertEqual(w.tone, .red)
        XCTAssertNil(w.vehicleName)
    }

    // MARK: Siri

    /// Fuori dalle città che conosciamo: «Non conosciamo le ZTL di questo posto», non «Nessuna ZTL entro 5 km»
    @MainActor
    func testSiriUncovered() {
        let store = Store()
        store.cities = [SampleData.florence]
        let pistoia = NearbyZTLIntent.answer(at: Coordinate(lat: 43.9333, lon: 10.9167), store: store)
        XCTAssertEqual(pistoia, L("We don't know the ZTLs of this place") + ".")
        XCTAssertNotEqual(pistoia, L("No ZTL within 5 km of you."))
    }
}
