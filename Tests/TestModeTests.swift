import XCTest

/// 1.17.0: la «Modalità prova» (la ZTL finta intorno a dove sei) e il testo di «Segnala un errore»
final class TestModeTests: XCTestCase {
    private let cal = RuleEngine.rome
    /// Mercoledì 28 ottobre 2026, 10:00 a Roma
    private lazy var day = cal.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 10))!
    private let here = Coordinate(lat: 43.7765, lon: 11.2830)

    private var engine: RuleEngine {
        var e = RuleEngine()
        let now = day
        e.now = { now }
        return e
    }

    private func answer(_ s: TestModeState, at d: Date) -> Answer {
        engine.answer(zone: TestZone.zone(s, now: day), vehicle: SampleData.rental, permits: [], hotelInside: false, at: d)
    }

    // MARK: La zona

    func testZoneIsAbout400MetresAroundTheCentre() {
        let z = TestZone.zone(TestZone.make(at: here, now: day), now: day)
        XCTAssertEqual(z.id, TestZone.zoneId)
        XCTAssertEqual(z.perimeter.count, TestZone.sides)
        XCTAssertTrue(z.contains(lat: here.lat, lon: here.lon), "il centro è dentro")
        // Largo tra 300 e 500 m da est a ovest e da nord a sud
        let b = try! XCTUnwrap(z.bounds)
        let ns = TestZone.meters(Coordinate(lat: b.minLat, lon: here.lon), Coordinate(lat: b.maxLat, lon: here.lon))
        let ew = TestZone.meters(Coordinate(lat: here.lat, lon: b.minLon), Coordinate(lat: here.lat, lon: b.maxLon))
        XCTAssertTrue((300...500).contains(ns), "nord-sud \(ns) m")
        XCTAssertTrue((300...500).contains(ew), "est-ovest \(ew) m")
        // 300 m più in là si è fuori
        let far = TestZone.offset(here, meters: 300, bearing: 90)
        XCTAssertFalse(z.contains(lat: far.lat, lon: far.lon))
        XCTAssertEqual(z.type, .restricted)
    }

    func testGatesOnTheEdgeAndParkingOutside() {
        let s = TestZone.make(at: here, now: day)
        XCTAssertTrue((1...2).contains(s.gates.count))
        for g in s.gates {
            XCTAssertEqual(TestZone.meters(g.location, here), TestZone.radius, accuracy: 2, "\(g.name) sul bordo")
        }
        let z = TestZone.zone(s, now: day)
        XCTAssertFalse(z.contains(lat: s.parking.lat, lon: s.parking.lon), "il parcheggio è fuori")
        XCTAssertLessThan(TestZone.meters(s.parking, here), 700, "a pochi minuti a piedi")
        // Il parcheggio è «fuori» anche per «Parcheggia fuori e cammina»
        XCTAssertTrue(ParkOutside.isOutside(s.parking, zones: [z], pedestrian: [], at: day) { zone, d in
            self.engine.answer(zone: zone, vehicle: SampleData.rental, permits: [], hotelInside: false, at: d)
        })
        // Varchi passati da fuori (quelli trovati sulle strade): restano quelli
        let road = [Gate(id: "prova-1", name: "Varco di prova 1 · Via Uno", location: TestZone.offset(here, meters: 195, bearing: 10))]
        XCTAssertEqual(TestZone.make(at: here, gates: road, now: day).gates, road)
        XCTAssertEqual(TestZone.make(at: here, gates: [], now: day).gates.count, TestZone.gateBearings.count, "senza strade, sul bordo")
    }

    func testActiveNowAndOff() {
        var s = TestZone.make(at: here, active: true, now: day)
        // Attiva a ogni ora, anche di domenica e a Natale
        for d in [day, cal.date(byAdding: .hour, value: 13, to: day)!,
                  cal.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 3))!,
                  cal.date(from: DateComponents(year: 2026, month: 12, day: 25, hour: 12))!] {
            let a = answer(s, at: d)
            XCTAssertTrue(a.gatesOn, "\(d)")
            guard case .no = a.verdict else { return XCTFail("attiva: la risposta è «no», non \(a.verdict)") }
        }
        s.active = false
        let off = answer(s, at: day)
        XCTAssertFalse(off.gatesOn)
        guard case .yes = off.verdict else { return XCTFail("spenta: la risposta è «sì», non \(off.verdict)") }
    }

    func testFreshEvenIfCreatedLongAgo() {
        // La zona è sempre «controllata oggi»: mai la risposta «non controllata da N giorni»
        var s = TestZone.make(at: here, now: day)
        s.created = cal.date(byAdding: .year, value: -1, to: day)!
        guard case .no = answer(s, at: day).verdict else { return XCTFail("zona di prova vecchia di un anno") }
    }

    // MARK: Accesa e spenta nelle città

    func testExcludedWhenOff() {
        let real = [SampleData.florence]
        XCTAssertEqual(TestZone.merged(real, with: nil).map(\.id), real.map(\.id), "spenta: nessuna zona di prova")
        let s = TestZone.make(at: here, now: day)
        let on = TestZone.merged(real, with: s)
        XCTAssertEqual(on.filter { TestZone.isTest(cityId: $0.id) }.count, 1)
        // Di nuovo con la zona già dentro: niente doppioni; poi spenta: via
        XCTAssertEqual(TestZone.merged(on, with: s).filter { TestZone.isTest(cityId: $0.id) }.count, 1)
        let offAgain = TestZone.merged(on, with: nil)
        XCTAssertFalse(offAgain.contains { TestZone.isTest(cityId: $0.id) })
        XCTAssertFalse(offAgain.flatMap(\.zones).contains { TestZone.isTest(zoneId: $0.id) })
        // Il punto al centro: dentro la zona di prova solo quando è accesa
        XCTAssertEqual(Store.zones(at: here, in: on).first?.zone.id, TestZone.zoneId)
        XCTAssertTrue(Store.zones(at: here, in: offAgain).isEmpty)
    }

    func testMovedZoneReplacesTheOldOne() {
        let a = TestZone.make(at: here, now: day)
        let there = TestZone.offset(here, meters: 2_000, bearing: 0)
        let b = TestZone.make(at: there, now: day)
        let list = TestZone.merged(TestZone.merged([SampleData.florence], with: a), with: b)
        XCTAssertEqual(list.filter { TestZone.isTest(cityId: $0.id) }.count, 1)
        XCTAssertTrue(Store.zones(at: here, in: list).isEmpty, "la vecchia posizione non c'è più")
        XCTAssertEqual(Store.zones(at: there, in: list).first?.zone.id, TestZone.zoneId)
    }

    func testSmallestZoneWinsInsideARealCity() {
        // Dentro una zona vera più grande la zona di prova (più piccola) è la prima, come i settori uno dentro l'altro
        let inA = Coordinate(lat: 43.7735, lon: 11.2550)
        let list = TestZone.merged([SampleData.florence], with: TestZone.make(at: inA, now: day))
        XCTAssertEqual(Store.zones(at: inA, in: list).map(\.zone.id), [TestZone.zoneId, SampleData.sectorA.id])
    }

    func testEntryIsWhereTheRoadCrossesTheEdge() {
        let ring = TestZone.perimeter(around: here)
        let path = RouteCheck.densify([TestZone.offset(here, meters: 500, bearing: 225), here], step: 5)
        let e = try! XCTUnwrap(TestZone.entry(on: path, perimeter: ring))
        XCTAssertEqual(TestZone.meters(e, here), TestZone.radius, accuracy: 12)
        XCTAssertNil(TestZone.entry(on: [here], perimeter: ring), "partenza già dentro: nessun ingresso")
    }

    func testStateRoundTripsAsJSON() throws {
        let s = TestZone.make(at: here, active: false, now: day)
        let back = try JSONDecoder().decode(TestModeState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(back, s)
    }

    // MARK: Segnala un errore

    private func report(location: Coordinate? = nil) -> ZoneReport {
        ZoneReport(topic: .gate, note: "  Il varco è 50 m più avanti  ", cityId: "firenze", cityName: "Firenze", zoneId: "firenze-a",
                   zoneName: "Settore A · Centro storico", when: day, whenIsNow: false, vehicle: "Fiat 500 · Petrol · Euro 6",
                   appVersion: "1.17.0 (41)", location: location)
    }

    func testReportCarriesTheContext() {
        let r = report()
        XCTAssertTrue(r.subject.contains("Firenze") && r.subject.contains("Settore A"))
        let body = r.body
        XCTAssertTrue(body.contains("Il varco è 50 m più avanti\n"), "la nota senza spazi intorno")
        XCTAssertTrue(body.contains("What: gate"))
        XCTAssertTrue(body.contains("(firenze-a)"))
        XCTAssertTrue(body.contains("Date/time: 2026-10-28 10:00 (Europe/Rome) · chosen"))
        XCTAssertTrue(body.contains("Vehicle: Fiat 500 · Petrol · Euro 6"))
        XCTAssertTrue(body.contains("App: 1.17.0 (41)"))
        XCTAssertFalse(body.contains("Test zone"))
    }

    func testReportPositionOnlyWhenTicked() {
        XCTAssertFalse(report().body.contains("Position"), "senza «Allega posizione» niente coordinate")
        let r = report(location: Coordinate(lat: 43.771234, lon: 11.255678))
        XCTAssertTrue(r.body.contains("Position: 43.77123, 11.25568"))
    }

    func testReportVehicleLineHasNoPlate() {
        var v = SampleData.rental
        v.plate = "AB123CD"
        XCTAssertFalse(ZoneReport.vehicleLine(v).contains("AB123CD"))
        XCTAssertTrue(ZoneReport.vehicleLine(v).contains("Euro 6"))
    }

    @MainActor func testSupportAddressIsThePlaceholder() {
        // Un solo posto per l'indirizzo, e mai uno personale finché non c'è quello vero
        XCTAssertEqual(AppConfig.supportEmail, "support@example.com")
        XCTAssertEqual(BugReportView.supportEmail, AppConfig.supportEmail)
    }
}
