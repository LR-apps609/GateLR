import XCTest

/// Stagioni con le regole («dal primo giovedì di aprile alla prima domenica di ottobre», 1.17.1) e moto/scooter
/// (exemptVehicleTypes). Gli stessi casi di android/core/.../SeasonAndVehicleTest.kt, sugli stessi file delle città.
final class SeasonAndVehicleTests: XCTestCase {
    private let engine: RuleEngine = {
        var e = RuleEngine()
        let today = RuleEngine.rome.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 12))!
        e.now = { today }
        return e
    }()
    private var car: Vehicle { SampleData.rental }
    private var moto: Vehicle {
        var v = Vehicle(name: "Scooter", model: "SH 125", fuel: .petrol, euro: 5)
        v.type = .motorcycle
        return v
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        RuleEngine.rome.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    private func fileData(_ id: String) throws -> Data {
        try Data(contentsOf: Self.root.appendingPathComponent("Resources/Cities/\(id).json"))
    }
    private func zone(_ city: String, _ id: String) throws -> Zone {
        try XCTUnwrap(CityLoader.decode(fileData(city)).zones.first { $0.id == id }, id)
    }
    private func verdict(_ z: Zone, _ v: Vehicle, _ at: Date) -> Verdict {
        engine.answer(zone: z, vehicle: v, permits: [], hotelInside: false, at: at).verdict
    }
    private func isYes(_ v: Verdict) -> Bool { if case .yes = v { return true }; return false }
    private func isNo(_ v: Verdict) -> Bool { if case .no = v { return true }; return false }
    private func isConditional(_ v: Verdict) -> Bool { if case .conditional = v { return true }; return false }

    func testNthWeekdayRules() {
        typealias Rule = TimeWindow.Season.DayRule
        func md(_ r: Rule, _ y: Int) -> Int? { r.day(in: y).map { $0.month * 100 + $0.day } }
        let firstThuApril = Rule(month: 4, weekday: 5, nth: 1), firstSunOctober = Rule(month: 10, weekday: 1, nth: 1)
        XCTAssertEqual(md(firstThuApril, 2026), 402)
        XCTAssertEqual(md(firstThuApril, 2027), 401)
        XCTAssertEqual(md(firstThuApril, 2028), 406)
        XCTAssertEqual(md(firstSunOctober, 2026), 1004)
        XCTAssertEqual(md(firstSunOctober, 2027), 1003)
        XCTAssertEqual(md(firstSunOctober, 2028), 1001)
        // Ultima domenica di marzo e di ottobre (ora legale), con lo spostamento in giorni
        XCTAssertEqual(md(Rule(month: 3, weekday: 1, nth: -1), 2026), 329)
        XCTAssertEqual(md(Rule(month: 3, weekday: 1, nth: -1, offset: 4), 2026), 402)
        XCTAssertEqual(md(Rule(month: 10, weekday: 1, nth: -1, offset: -1), 2027), 1030)
        XCTAssertNil(md(Rule(month: 2, weekday: 2, nth: 5), 2026))           // nessun quinto lunedì di febbraio
        XCTAssertEqual(CivilDay.weekday(2026, 10, 28), 4)                     // mercoledì
        XCTAssertEqual(CivilDay.daysIn(2028, 2), 29)
    }

    /// Firenze, notti d'estate «dal primo giovedì di aprile alla prima domenica di ottobre», giovedì–sabato 23 → 3
    func testFlorenceSummerNights2026to2028() throws {
        let g = try zone("firenze", "firenze-g")
        let s = try XCTUnwrap(g.windows.first { $0.season != nil }?.season)
        XCTAssertEqual([s.fromMonth, s.fromDay, s.toMonth, s.toDay], [4, 1, 10, 7])   // ripiego largo per le app vecchie
        // 2026: dal 2 aprile al 4 ottobre
        XCTAssertFalse(engine.isActive(g, at: date(2026, 3, 28, 23, 30)))
        XCTAssertTrue(engine.isActive(g, at: date(2026, 4, 2, 23, 30)))      // primo giovedì
        XCTAssertTrue(engine.isActive(g, at: date(2026, 4, 3, 2)))           // la notte dopo, oltre la mezzanotte
        XCTAssertTrue(engine.isActive(g, at: date(2026, 10, 3, 23, 30)))     // ultimo sabato
        XCTAssertTrue(engine.isActive(g, at: date(2026, 10, 4, 2, 30)))      // domenica 4 alle 2:30, notte di sabato
        XCTAssertFalse(engine.isActive(g, at: date(2026, 10, 8, 23, 30)))
        XCTAssertEqual(engine.nextChange(g, after: date(2026, 4, 1, 12)), date(2026, 4, 2, 23))
        // 2027: dal 1° aprile al 3 ottobre (giovedì 7 ottobre le date fisse direbbero «attiva»)
        XCTAssertFalse(engine.isActive(g, at: date(2027, 3, 27, 23, 30)))
        XCTAssertTrue(engine.isActive(g, at: date(2027, 4, 1, 23, 30)))
        XCTAssertTrue(engine.isActive(g, at: date(2027, 4, 2, 1)))
        XCTAssertTrue(engine.isActive(g, at: date(2027, 10, 2, 23, 30)))
        XCTAssertTrue(engine.isActive(g, at: date(2027, 10, 3, 2)))
        XCTAssertFalse(engine.isActive(g, at: date(2027, 10, 7, 23, 30)))
        // 2028: dal 6 aprile al 1° ottobre (sabato 1° aprile le date fisse direbbero «attiva»)
        XCTAssertFalse(engine.isActive(g, at: date(2028, 4, 1, 23, 30)))
        XCTAssertFalse(engine.isActive(g, at: date(2028, 4, 2, 2)))
        XCTAssertTrue(engine.isActive(g, at: date(2028, 4, 6, 23, 30)))
        XCTAssertTrue(engine.isActive(g, at: date(2028, 4, 7, 2)))
        XCTAssertTrue(engine.isActive(g, at: date(2028, 9, 30, 23, 30)))
        XCTAssertTrue(engine.isActive(g, at: date(2028, 10, 1, 2, 30)))      // domenica 1° ottobre, notte di sabato
        XCTAssertFalse(engine.isActive(g, at: date(2028, 10, 5, 23, 30)))
        XCTAssertFalse(engine.isActive(g, at: date(2028, 10, 6, 1)))
        // Le date mostrate nella scheda: la stagione in corso o la prossima
        let shown = s.shown(year: 2026, month: 10, day: 28)
        XCTAssertEqual([shown.from.year, shown.from.month, shown.from.day, shown.to.year, shown.to.month, shown.to.day], [2027, 4, 1, 2027, 10, 3])
        let spring = s.shown(year: 2026, month: 2, day: 1)
        XCTAssertEqual([spring.from.month, spring.from.day, spring.to.month, spring.to.day], [4, 2, 10, 4])
    }

    /// Bergamo, Città Alta e Colli: dal giovedì dopo l'ultima domenica di marzo al sabato prima dell'ultima di ottobre, 21 → 1
    func testBergamoSummerTimeEvenings() throws {
        let colli = try zone("bergamo", "bergamo-colli")
        XCTAssertTrue(engine.isActive(colli, at: date(2026, 4, 2, 21, 30)))
        XCTAssertFalse(engine.isActive(colli, at: date(2026, 3, 28, 21, 30)))
        XCTAssertTrue(engine.isActive(colli, at: date(2026, 10, 24, 23)))    // ultimo sabato
        XCTAssertTrue(engine.isActive(colli, at: date(2026, 10, 25, 0, 30))) // dopo mezzanotte, ancora la sera di sabato
        XCTAssertFalse(engine.isActive(colli, at: date(2026, 10, 30, 21, 30))) // con le date fisse sarebbe attiva
        XCTAssertTrue(engine.isActive(colli, at: date(2027, 10, 30, 21, 30)))  // nel 2027 l'ultimo sabato è il 30
    }

    /// Le date fisse da sole valgono come prima, anche a cavallo del capodanno
    func testFixedSeasonStillWorks() {
        let s = TimeWindow.Season(fromMonth: 5, fromDay: 1, toMonth: 10, toDay: 31)
        XCTAssertTrue(s.contains(year: 2027, month: 5, day: 1))
        XCTAssertFalse(s.contains(year: 2027, month: 11, day: 1))
        let winter = TimeWindow.Season(fromMonth: 12, fromDay: 8, toMonth: 1, toDay: 6)
        XCTAssertTrue(winter.contains(year: 2027, month: 1, day: 3))
        XCTAssertFalse(winter.contains(year: 2027, month: 2, day: 3))
    }

    /// Le app fino alla 1.17.0 leggono le città senza «from»/«to» né «exemptVehicleTypes»: JSONDecoder salta le chiavi
    /// che non conosce e le date fisse restano quelle larghe
    func testOldAppsReadTheNewFields() throws {
        struct OldSeason: Decodable, Equatable { var fromMonth: Int, fromDay: Int, toMonth: Int, toDay: Int }
        struct OldWindow: Decodable { var weekdays: Set<Int>; var start: Int; var end: Int; var season: OldSeason? }
        struct OldZone: Decodable { var id: String; var windows: [OldWindow]; var exemptFuels: Set<Fuel> }
        struct OldCity: Decodable { var id: String; var zones: [OldZone] }
        let fi = try JSONDecoder().decode(OldCity.self, from: fileData("firenze"))
        let s = fi.zones.first { $0.id == "firenze-g" }?.windows.first?.season
        XCTAssertEqual(s, OldSeason(fromMonth: 4, fromDay: 1, toMonth: 10, toDay: 7))
        XCTAssertNoThrow(try JSONDecoder().decode(OldCity.self, from: fileData("roma")))
    }

    func testMotorbikes() throws {
        let monday = date(2026, 10, 26, 12)
        // Esenti: Firenze (disciplinare, punto 17), Roma Centro, Arezzo ZTL A; non esenti: Roma Tridente, Ostuni, Arezzo ZTL B
        XCTAssertTrue(isYes(verdict(try zone("firenze", "firenze-a"), moto, monday)))
        XCTAssertTrue(isNo(verdict(try zone("firenze", "firenze-a"), car, monday)))
        XCTAssertTrue(isYes(verdict(try zone("roma", "roma-centro"), moto, monday)))
        XCTAssertTrue(isNo(verdict(try zone("roma", "roma-tridente"), moto, monday)))
        XCTAssertTrue(isNo(verdict(try zone("ostuni", "ostuni-centro"), moto, date(2026, 10, 26, 20))))
        XCTAssertTrue(isNo(verdict(try zone("arezzo", "arezzo-ztl-b"), moto, date(2026, 10, 26, 20))))
        XCTAssertTrue(isYes(verdict(try zone("arezzo", "arezzo-ztl-a"), moto, date(2026, 10, 26, 10))))
        // Napoli Centro Antico: dentro c'è Mezzocannone, vietato alle moto
        XCTAssertFalse(isYes(verdict(try zone("napoli", "napoli-centro-antico"), moto, monday)))
        // Scudo Verde: dalla 1.17.2 i limiti delle moto dalle fonti ufficiali («motoBans»): una moto Euro 5 entra.
        // Milano Area B non li ha: per le moto «controlla sul sito del Comune»
        let sv = try zone("firenze", "firenze-scudo-verde")
        XCTAssertTrue(isYes(verdict(sv, moto, date(2026, 12, 1, 3))))
        XCTAssertTrue(isConditional(verdict(try zone("milano", "milano-b"), moto, monday)))
        var old = moto; old.euro = 0
        XCTAssertNil(sv.ban(for: old, at: date(2026, 12, 1, 3)))              // i divieti delle auto non toccano le moto
        // Il tipo prima dell'alimentazione: la risposta parla di moto
        let a = engine.answer(zone: try zone("firenze", "firenze-a"), vehicle: moto, permits: [], hotelInside: false, at: monday)
        XCTAssertEqual(a.verdict, .yes(reason: L("The ZTL is active, but motorbikes and scooters may enter.")))
        // Senza «type» i veicoli salvati restano auto
        let saved = try JSONDecoder().decode(Vehicle.self, from: Data(#"{"id":"6F9619FF-8B86-D011-B42D-00CF4FC964FF","name":"x","model":"","fuel":"petrol","euro":6,"plate":"","isRental":false}"#.utf8))
        XCTAssertEqual(saved.kind, .car)
        XCTAssertEqual(CarCatalog.euro(forYear: 2022, type: .motorcycle), 5)
        XCTAssertEqual(CarCatalog.euro(forYear: 2022, type: .car), 6)
        // Consigli del Garage: «Moto e scooter possono entrare» dove sono esenti, nessuna riga sui divieti delle auto
        let fi = try CityLoader.decode(fileData("firenze"))
        let lines = CarAdvice.lines(for: moto, cities: [fi], at: monday)
        XCTAssertEqual(lines.filter { $0.text == L("Motorbikes and scooters may enter") }.count, 5)
        XCTAssertFalse(lines.contains { !$0.ok })
    }
}
