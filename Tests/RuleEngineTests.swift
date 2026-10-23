import XCTest

final class RuleEngineTests: XCTestCase {
    private let engine = RuleEngine()
    private var cal: Calendar { engine.calendar }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    private var zone: Zone { SampleData.sectorA }
    private var car: Vehicle { SampleData.rental }

    func testGatesOffAtNightMeansYes() {
        // venerdì 23 ottobre 2026, 21:40
        let a = engine.answer(zone: zone, vehicle: car, permits: [], hotelInside: false, at: date(2026, 10, 23, 21, 40))
        XCTAssertFalse(a.gatesOn)
        guard case .yes = a.verdict else { return XCTFail("atteso sì, ottenuto \(a.verdict)") }
        XCTAssertEqual(a.nextChange, date(2026, 10, 24, 7, 30))      // sabato mattina
        XCTAssertEqual(engine.previousChange(zone, before: date(2026, 10, 23, 21, 40)), date(2026, 10, 23, 20))
    }

    func testWeekdayDaytimeIsNo() {
        let a = engine.answer(zone: zone, vehicle: car, permits: [], hotelInside: false, at: date(2026, 10, 26, 18))
        XCTAssertTrue(a.gatesOn)
        guard case .no = a.verdict else { return XCTFail("atteso no, ottenuto \(a.verdict)") }
        XCTAssertEqual(a.nextChange, date(2026, 10, 26, 20))
    }

    func testHotelInsideIsConditional() {
        let a = engine.answer(zone: zone, vehicle: car, permits: [], hotelInside: true, at: date(2026, 10, 26, 18))
        guard case .conditional = a.verdict else { return XCTFail("atteso con condizioni, ottenuto \(a.verdict)") }
    }

    func testConfirmedPermitIsYes() {
        let p = Permit(kind: .hotelRegistration, cityId: "x", zoneId: nil, vehicleId: car.id,
                       from: date(2026, 10, 26, 0), to: date(2026, 10, 28, 23), status: .confirmed)
        let a = engine.answer(zone: zone, vehicle: car, permits: [p], hotelInside: true, at: date(2026, 10, 26, 18))
        guard case .yes = a.verdict else { return XCTFail("atteso sì, ottenuto \(a.verdict)") }
    }

    func testPermitForAnotherCarDoesNotCount() {
        let p = Permit(kind: .resident, cityId: "x", zoneId: nil, vehicleId: UUID(),
                       from: date(2026, 10, 26, 0), to: date(2026, 10, 28, 23), status: .confirmed)
        let a = engine.answer(zone: zone, vehicle: car, permits: [p], hotelInside: false, at: date(2026, 10, 26, 18))
        guard case .no = a.verdict else { return XCTFail("atteso no, ottenuto \(a.verdict)") }
    }

    func testSaturdayAfternoonAndSundayAreFree() {
        XCTAssertFalse(engine.isActive(zone, at: date(2026, 10, 24, 17)))
        XCTAssertTrue(engine.isActive(zone, at: date(2026, 10, 24, 10)))
        XCTAssertFalse(engine.isActive(zone, at: date(2026, 10, 25, 10)))
    }

    func testHolidaysAreFree() {
        XCTAssertFalse(engine.isActive(zone, at: date(2026, 12, 8, 10)))   // Immacolata, martedì
        XCTAssertFalse(engine.isActive(zone, at: date(2026, 4, 6, 10)))    // Pasquetta 2026
        XCTAssertTrue(engine.isActive(zone, at: date(2026, 4, 7, 10)))
    }

    func testNightWindowCrossesMidnight() {
        var z = zone
        // ZTL notturna estiva: giovedì, venerdì, sabato 23:00 – 3:00, da maggio a ottobre
        z.windows = [TimeWindow(weekdays: [5, 6, 7], start: 23 * 60, end: 3 * 60,
                                season: .init(fromMonth: 5, fromDay: 1, toMonth: 10, toDay: 31))]
        XCTAssertTrue(engine.isActive(z, at: date(2026, 7, 3, 23, 30)))    // venerdì sera
        XCTAssertTrue(engine.isActive(z, at: date(2026, 7, 4, 2, 0)))      // la notte dopo
        XCTAssertFalse(engine.isActive(z, at: date(2026, 7, 4, 4, 0)))
        XCTAssertFalse(engine.isActive(z, at: date(2026, 7, 6, 1, 0)))     // lunedì notte
        XCTAssertFalse(engine.isActive(z, at: date(2026, 12, 4, 23, 30)))  // fuori stagione
    }

    func testElectricExemption() {
        var z = zone
        z.exemptFuels = [.electric]
        let ev = Vehicle(name: "EV", fuel: .electric, euro: 6)
        let a = engine.answer(zone: z, vehicle: ev, permits: [], hotelInside: false, at: date(2026, 10, 26, 18))
        guard case .yes = a.verdict else { return XCTFail("atteso sì, ottenuto \(a.verdict)") }
    }

    func testStaleSourceIsUnsure() {
        var z = zone
        z.source.checkedOn = date(2026, 1, 1, 12)
        var e = engine
        e.now = { self.date(2026, 10, 23, 12) }
        let a = e.answer(zone: z, vehicle: car, permits: [], hotelInside: false, at: date(2026, 10, 26, 18))
        guard case .unsure = a.verdict else { return XCTFail("atteso non sicuro, ottenuto \(a.verdict)") }
    }

    func testUnknownHolidayIsUnsure() {
        var z = zone
        z.freeOnHolidays = nil
        let a = engine.answer(zone: z, vehicle: car, permits: [], hotelInside: false, at: date(2026, 12, 8, 10))
        guard case .unsure = a.verdict else { return XCTFail("atteso non sicuro, ottenuto \(a.verdict)") }
        // fuori orario, anche di festa, la risposta resta «sì»
        let b = engine.answer(zone: z, vehicle: car, permits: [], hotelInside: false, at: date(2026, 12, 8, 21))
        guard case .yes = b.verdict else { return XCTFail("atteso sì, ottenuto \(b.verdict)") }
    }

    /// Il file di Firenze incluso nell'app si legge e dà le risposte attese
    func testFlorenceFile() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/Cities/firenze.json")
        let city = try CityLoader.decode(Data(contentsOf: url))
        XCTAssertEqual(city.status, .draft)
        XCTAssertEqual(Set(city.zones.map(\.id)), ["firenze-a", "firenze-b", "firenze-o", "firenze-f", "firenze-g"])
        let b = try XCTUnwrap(city.zones.first { $0.id == "firenze-b" })
        let g = try XCTUnwrap(city.zones.first { $0.id == "firenze-g" })
        XCTAssertFalse(b.gates.isEmpty)
        XCTAssertGreaterThan(b.perimeter.count, 10)
        XCTAssertTrue(engine.isActive(b, at: date(2026, 10, 26, 10)))       // lunedì mattina
        XCTAssertFalse(engine.isActive(b, at: date(2026, 10, 26, 20, 30)))  // lunedì sera
        XCTAssertTrue(engine.isActive(b, at: date(2026, 7, 4, 1, 0)))       // notte estiva, sabato
        XCTAssertFalse(engine.isActive(b, at: date(2026, 10, 10, 1, 0)))    // estate finita il 3 ottobre
        XCTAssertTrue(engine.isActive(g, at: date(2026, 6, 5, 23, 30)))     // G solo d'estate, venerdì notte
        XCTAssertFalse(engine.isActive(g, at: date(2026, 10, 26, 10)))
    }

    /// Il file delle multe, condiviso con il sito, si legge
    func testFineFile() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/Rules/fine.json")
        let fine = try JSONDecoder().decode(FineInfo.self, from: Data(contentsOf: url))
        XCTAssertLessThan(fine.min, fine.max)
        XCTAssertFalse(fine.notes.isEmpty)
    }

    func testPaidZoneIsConditional() {
        var z = zone
        z.ticket = Ticket(price: 7.5, howTo: "Pay online by midnight of the next day.", url: nil)
        let a = engine.answer(zone: z, vehicle: car, permits: [], hotelInside: false, at: date(2026, 10, 26, 18))
        guard case .conditional(_, let c) = a.verdict else { return XCTFail("atteso con condizioni, ottenuto \(a.verdict)") }
        XCTAssertTrue(c.contains("7"))
    }

    func testEaster() {
        XCTAssertEqual(ItalianHolidays.easterSunday(2026).month, 4)
        XCTAssertEqual(ItalianHolidays.easterSunday(2026).day, 5)
        XCTAssertEqual(ItalianHolidays.easterSunday(2027).month, 3)
        XCTAssertEqual(ItalianHolidays.easterSunday(2027).day, 28)
    }

    func testHotelMessageHasPlate() {
        let m = MessageLanguage.de.message(arrival: date(2026, 10, 26, 18), plate: "AB123CD")
        XCTAssertTrue(m.contains("AB123CD"))
    }
}
