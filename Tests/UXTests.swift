import XCTest

/// La 1.13.0 «UX»: giorni del soggiorno e messaggio per l'hotel in ora italiana, hotel dei viaggi salvati
/// come scorciatoia nella prima pagina, novità della versione
final class UXTests: XCTestCase {
    private let cal = RuleEngine.rome

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    /// Arrivo alle 00:30 di Roma (le 23:30 del giorno prima a Londra): i giorni contano da quello italiano
    func testHotelStayDaysAreRomeDays() {
        let stay = HotelStay(arrival: date(2026, 11, 3, 0, 30), departure: date(2026, 11, 4, 10))
        XCTAssertEqual(stay.days, [date(2026, 11, 3, 0), date(2026, 11, 4, 0)])
    }

    /// Il messaggio per l'hotel scrive l'ora italiana, qualunque sia il fuso del telefono
    func testHotelMessageUsesRomeTime() {
        let m = MessageLanguage.it.message(arrival: date(2026, 11, 2, 18), plate: "AB123CD")
        XCTAssertTrue(m.contains("18:00"), m)
        XCTAssertTrue(m.contains("2 novembre"), m)
    }

    func testFormatIsRomeTime() {
        var f = Date.FormatStyle(date: .omitted, time: .shortened)
        f.timeZone = TimeZone(identifier: "Europe/Rome")!
        XCTAssertEqual(RuleEngine.format(date(2026, 7, 1, 9, 15), .init(date: .omitted, time: .shortened)),
                       date(2026, 7, 1, 9, 15).formatted(f))
    }

    /// «Il tuo hotel»: prima i viaggi non finiti (dal più vicino), poi gli altri; niente doppioni, al massimo due
    @MainActor
    func testSavedHotelsOrder() {
        let now = date(2026, 10, 26, 12)
        let a = Place(name: "Hotel A", address: "", location: Coordinate(lat: 43.77, lon: 11.25))
        let b = Place(name: "Hotel B", address: "", location: Coordinate(lat: 44.49, lon: 11.34))
        let c = Place(name: "Hotel C", address: "", location: Coordinate(lat: 45.46, lon: 9.19))
        let trips = [
            Trip(hotel: c, hotelName: "", arrival: date(2026, 9, 1, 18), departure: date(2026, 9, 3, 10)),          // passato
            Trip(hotel: b, hotelName: "Il B", arrival: date(2026, 11, 20, 18), departure: date(2026, 11, 22, 10)),
            Trip(hotel: a, hotelName: "", arrival: date(2026, 10, 30, 18), departure: date(2026, 11, 1, 10)),
            Trip(hotel: a, hotelName: "", arrival: date(2026, 12, 30, 18), departure: date(2027, 1, 1, 10)),
            Trip(hotel: nil, hotelName: "Senza posto", arrival: date(2026, 10, 27, 18), departure: date(2026, 10, 28, 10)),
        ]
        XCTAssertEqual(VarcoView.savedHotels(trips, now: now).map(\.name), ["Hotel A", "Il B"])
        XCTAssertTrue(VarcoView.savedHotels([], now: now).isEmpty)
    }

    @MainActor
    func testWhatsNew113() {
        XCTAssertEqual(WhatsNewView.notes["1.13.0"]?.count, 3)
        XCTAssertTrue(WhatsNewView.shouldShow(version: "1.13.0", seen: "1.12.1", onboarded: true))
    }
}
