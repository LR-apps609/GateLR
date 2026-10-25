import XCTest

/// Le correzioni della 1.12.1: ore e date in ora italiana, arrivi mai nel passato, «Novità» solo con le note
final class FixesTests: XCTestCase {
    private let engine = RuleEngine()
    private var cal: Calendar { engine.calendar }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    private func city(_ id: String) throws -> City {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/Cities/\(id).json")
        return try CityLoader.decode(Data(contentsOf: url))
    }

    /// Una versione di sole correzioni non apre il foglio «Novità» (prima: vuoto o con le note vecchie)
    @MainActor
    func testWhatsNewOnlyForVersionsWithNotes() {
        XCTAssertTrue(WhatsNewView.shouldShow(version: "1.12.0", seen: "1.11.0", onboarded: true))
        XCTAssertFalse(WhatsNewView.shouldShow(version: "1.12.1", seen: "1.12.0", onboarded: true))
        XCTAssertFalse(WhatsNewView.shouldShow(version: "1.12.0", seen: "1.12.0", onboarded: true))
        XCTAssertFalse(WhatsNewView.shouldShow(version: "1.12.0", seen: nil, onboarded: false))
    }

    /// L'ora del cambio in ora italiana; con il giorno se non è lo stesso giorno
    func testClockIsRomeTimeAndAddsTheDay() {
        var rome = Date.FormatStyle(date: .omitted, time: .shortened)
        rome.timeZone = cal.timeZone
        let eight = date(2026, 10, 26, 20)
        XCTAssertEqual(engine.clock(eight, from: date(2026, 10, 26, 10)), eight.formatted(rome))
        let monday = date(2026, 10, 26, 7, 30)
        let saturday = engine.clock(monday, from: date(2026, 10, 24, 21))
        XCTAssertTrue(saturday.contains(monday.formatted(rome)))
        XCTAssertGreaterThan(saturday.count, monday.formatted(rome).count)
    }

    /// Il giorno di un divieto (mezzanotte di Roma) è quello giusto in qualsiasi fuso del telefono
    func testBanDayIsRomeDay() {
        let ban = EuroBan(fuel: .diesel, maxEuro: 2, since: "2026-12-01")
        XCTAssertEqual(engine.day(ban.date), engine.day(date(2026, 12, 1, 12)))
        XCTAssertNotEqual(engine.day(ban.date), engine.day(date(2026, 11, 30, 12)))
    }

    /// Siri, «arrivo alle 8» detto alle 10: vale domani alle 8, anche attraverso il cambio dell'ora
    @MainActor
    func testPastArrivalRollsToNextOccurrence() {
        let now = date(2026, 10, 26, 10)
        XCTAssertEqual(CanIDriveIntoIntent.arrival(date(2026, 10, 26, 8), now: now, calendar: cal), date(2026, 10, 27, 8))
        XCTAssertEqual(CanIDriveIntoIntent.arrival(date(2026, 10, 24, 8), now: now, calendar: cal), date(2026, 10, 27, 8))
        XCTAssertEqual(CanIDriveIntoIntent.arrival(date(2026, 10, 19, 9), now: now, calendar: cal), date(2026, 10, 27, 9))
        let soon = now.addingTimeInterval(-5 * 60), later = date(2026, 10, 26, 18)
        XCTAssertEqual(CanIDriveIntoIntent.arrival(soon, now: now, calendar: cal), soon)
        XCTAssertEqual(CanIDriveIntoIntent.arrival(later, now: now, calendar: cal), later)
    }

    /// Partenza per arrivare a un'ora: mai prima di adesso
    func testDepartureIsNeverInThePast() {
        let now = date(2026, 10, 26, 10)
        XCTAssertEqual(RoutePlanner.departure(arriving: nil, travelTime: 1_800, now: now), now)
        XCTAssertEqual(RoutePlanner.departure(arriving: now.addingTimeInterval(600), travelTime: 1_800, now: now), now)
        XCTAssertEqual(RoutePlanner.departure(arriving: now.addingTimeInterval(7_200), travelTime: 1_800, now: now),
                       now.addingTimeInterval(5_400))
    }

    /// «ZTL vicine» dal Duomo di Milano: l'Area C, non l'Area B verde che la contiene
    @MainActor
    func testNearbyPicksTheSmallestZoneWhenInside() throws {
        let milano = try city("milano")
        let hit = try XCTUnwrap(NearbyZTLIntent.nearest(milano.zones, to: Coordinate(lat: 45.4641, lon: 9.1919)))
        XCTAssertEqual(hit.0.id, "milano-c")
        XCTAssertEqual(hit.1, 0)
    }

    /// Il cartello si legge in ora italiana: lunedì alle 20:30 a Roma «7.30-20.00 feriali» è spento
    func testSignReaderUsesRomeTime() {
        let sign = SignReader.parse("7.30-20.00\nFERIALI")
        XCTAssertFalse(SignReader.isActive(sign, at: date(2026, 10, 26, 20, 30)))
        XCTAssertTrue(SignReader.isActive(sign, at: date(2026, 10, 26, 19, 30)))
    }

    /// Area C: il ticket va attivato entro la mezzanotte del giorno dopo, di Milano
    @MainActor
    func testTicketDeadlineIsMilanMidnight() {
        let ticket = Ticket(price: 7.5, howTo: "", url: nil, deadline: "nextDayMidnight")
        let card = TicketCard(zone: SampleData.sectorA, ticket: ticket, entry: date(2026, 10, 26, 10))
        XCTAssertEqual(card.deadline, date(2026, 10, 27, 23, 59))
    }
}
