import XCTest

/// «Parcheggia fuori e cammina»: orari di OpenStreetMap, parcheggi fuori dalle ZTL attive, ordine delle proposte;
/// e l'ora scelta nei chip («Adesso», «Stasera 20:00», «Domani 9:00»)
final class ParkingTests: XCTestCase {
    private let cal = RuleEngine.rome
    private let engine: RuleEngine = {
        var e = RuleEngine()
        let today = RuleEngine.rome.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 12))!
        e.now = { today }
        return e
    }()

    /// 26 ottobre 2026 è lunedì
    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    private func open(_ text: String, _ d: Date, holiday: Bool = false, file: StaticString = #filePath, line: UInt = #line) -> Bool {
        guard let h = OpeningHours.parse(text) else { XCTFail("non letto: \(text)", file: file, line: line); return false }
        return h.isOpen(at: d, calendar: cal, holiday: holiday)
    }

    // MARK: opening_hours

    func testAlwaysOpen() {
        XCTAssertTrue(open("24/7", date(2026, 10, 26, 3)))
        XCTAssertTrue(open("Mo-Su 00:00-24:00", date(2026, 11, 1, 23, 59)))
        XCTAssertEqual(OpeningHours.parse("24/7")?.alwaysOpen, true)
    }

    func testWeekdaysAndSaturday() {
        let s = "Mo-Fr 07:00-20:00; Sa 08:00-13:00"
        XCTAssertTrue(open(s, date(2026, 10, 26, 10)))           // lunedì
        XCTAssertFalse(open(s, date(2026, 10, 26, 6, 59)))
        XCTAssertFalse(open(s, date(2026, 10, 26, 20)))          // alle 20:00 chiude
        XCTAssertTrue(open(s, date(2026, 10, 31, 12, 59)))       // sabato
        XCTAssertFalse(open(s, date(2026, 10, 31, 13)))
        XCTAssertFalse(open(s, date(2026, 11, 1, 10)))           // domenica: non nominata, chiuso
    }

    func testSplitHoursListsAndSpaces() {
        let s = "Mo, We 08:00-12:00,14:00-18:30"
        XCTAssertTrue(open(s, date(2026, 10, 28, 9)))            // mercoledì
        XCTAssertFalse(open(s, date(2026, 10, 28, 13)))
        XCTAssertTrue(open(s, date(2026, 10, 28, 18, 29)))
        XCTAssertFalse(open(s, date(2026, 10, 27, 9)))           // martedì
        XCTAssertTrue(open("7.30-19.30", date(2026, 11, 1, 7, 30)))  // senza giorni: tutti i giorni
    }

    func testOvernight() {
        XCTAssertTrue(open("Mo-Su 22:00-06:00", date(2026, 10, 27, 2)))
        XCTAssertFalse(open("Mo-Su 22:00-06:00", date(2026, 10, 27, 12)))
        // La notte del venerdì finisce sabato alle 2; quella del sabato non c'è
        XCTAssertTrue(open("Fr 22:00-02:00", date(2026, 10, 31, 1)))
        XCTAssertFalse(open("Fr 22:00-02:00", date(2026, 11, 1, 1)))
    }

    func testLaterRulesReplaceAndOff() {
        let s = "Mo-Fr 08:00-20:00; Fr off"
        XCTAssertTrue(open(s, date(2026, 10, 29, 10)))           // giovedì
        XCTAssertFalse(open(s, date(2026, 10, 30, 10)))          // venerdì
        XCTAssertTrue(open("Fr-Mo 10:00-12:00", date(2026, 11, 1, 11)))   // domenica: dentro «Fr-Mo»
        XCTAssertFalse(open("Fr-Mo 10:00-12:00", date(2026, 10, 28, 11))) // mercoledì
    }

    func testPublicHolidays() {
        let s = "Mo-Su 07:00-24:00; PH off"
        XCTAssertTrue(open(s, date(2026, 12, 8, 10)))
        XCTAssertFalse(open(s, date(2026, 12, 8, 10), holiday: true))
        XCTAssertFalse(open("24/7; PH off", date(2026, 12, 8, 10), holiday: true))
        XCTAssertTrue(open("24/7; PH off", date(2026, 12, 9, 10)))
        XCTAssertTrue(open("Mo-Sa 08:00-20:00", date(2026, 12, 8, 10), holiday: true))   // PH non nominato: orario del giorno
    }

    func testUnreadableFormats() {
        for s in ["", "Jan-Mar 08:00-20:00", "sunrise-sunset", "Mo-Fr 08:00+", "Mo-Fr", "8h-20h", "Mo-Fr 08:00-20:00 \"su prenotazione\"",
                  "Mo-Fr 25:00-26:00", "Mo-Fr 08:00-12:00 || Sa 08:00-12:00", "week 1-20 Mo 08:00-12:00"] {
            XCTAssertNil(OpeningHours.parse(s), s)
        }
        XCTAssertNil(OpeningHours.parse(nil))
    }

    // MARK: Fuori dalle ZTL attive

    private var zone: Zone { SampleData.sectorA }                // Firenze di esempio: lun–ven 7:30–20, sab 7:30–16
    private let inside = Coordinate(lat: 43.7730, lon: 11.2550)
    private let outside = Coordinate(lat: 43.7620, lon: 11.2550)

    private func isOutside(_ p: Coordinate, at d: Date, pedestrian: [PedestrianArea] = [], vehicle: Vehicle = SampleData.rental) -> Bool {
        ParkOutside.isOutside(p, zones: [zone], pedestrian: pedestrian, at: d) { z, when in
            engine.answer(zone: z, vehicle: vehicle, permits: [], hotelInside: false, at: when)
        }
    }

    func testOutsideFilterUsesArrivalTime() {
        XCTAssertFalse(isOutside(inside, at: date(2026, 10, 26, 18)))     // lunedì 18: ZTL attiva
        XCTAssertTrue(isOutside(inside, at: date(2026, 10, 26, 21)))      // alle 21 è spenta
        XCTAssertTrue(isOutside(outside, at: date(2026, 10, 26, 18)))
        var electric = SampleData.rental
        electric.fuel = .electric
        var z = zone
        z.exemptFuels = [.electric]
        let ok = ParkOutside.isOutside(inside, zones: [z], pedestrian: [], at: date(2026, 10, 26, 18)) { zz, when in
            engine.answer(zone: zz, vehicle: electric, permits: [], hotelInside: false, at: when)
        }
        XCTAssertTrue(ok, "un'elettrica ammessa può parcheggiare dentro")
    }

    func testPedestrianAreaIsNeverOutside() {
        let square = PedestrianArea(id: "p", name: "Piazza", perimeter: [
            Coordinate(lat: 43.7610, lon: 11.2540), Coordinate(lat: 43.7610, lon: 11.2560),
            Coordinate(lat: 43.7630, lon: 11.2560), Coordinate(lat: 43.7630, lon: 11.2540)])
        XCTAssertFalse(isOutside(outside, at: date(2026, 10, 26, 21), pedestrian: [square]))
    }

    // MARK: Ordine

    private func spot(_ id: String, _ meters: Double, name: String? = "P", hours: String? = nil, capacity: Int? = nil) -> ParkingSpot {
        // «meters» verso sud dalla destinazione
        ParkingSpot(id: id, name: name, lat: outside.lat - meters / 111_000, lon: outside.lon, hours: hours, capacity: capacity)
    }

    func testRankingByWalkAndPenalties() {
        let monday18 = date(2026, 10, 26, 18)
        let spots = [
            spot("far", 900, name: "Lontano"),
            spot("near", 300, name: "Vicino"),
            spot("noname", 200, name: nil),                         // 200 m ma senza nome: +250
            spot("closed", 100, name: "Chiuso", hours: "Mo-Fr 08:00-12:00"),
            spot("tiny", 250, name: "Piccolo", capacity: 8),        // +150
            spot("toofar", 2_500, name: "Troppo lontano"),
        ]
        let ranked = ParkOutside.rank(spots, to: outside, at: monday18, calendar: cal)
        XCTAssertEqual(ranked.map(\.id), ["near", "tiny", "noname", "far"])
        XCTAssertEqual(ranked.first?.walkMinutes, 5)                // 300 m × 1,3 / 80 m al minuto
        XCTAssertNil(ranked.first?.open)
    }

    func testSameNameNearbyCountsOnce() {
        let spots = [spot("a", 300, name: "Garage Centrale"), spot("b", 380, name: "Garage Centrale"), spot("c", 600, name: "Altro")]
        XCTAssertEqual(ParkOutside.rank(spots, to: outside, at: date(2026, 10, 26, 18), calendar: cal).map(\.id), ["a", "c"])
    }

    func testFinalizeDropsBlockedRoutesAndKeepsThree() {
        func option(_ id: String, _ walk: Double, clear: Bool?) -> ParkingOption {
            var o = ParkingOption(spot: spot(id, walk), walkMeters: walk, score: walk)
            o.routeClear = clear
            return o
        }
        let out = ParkOutside.finalize([option("a", 900, clear: true), option("b", 100, clear: false), option("c", 400, clear: nil),
                                        option("d", 300, clear: true), option("e", 1_200, clear: true)])
        XCTAssertEqual(out.map(\.id), ["d", "c", "a"])
    }

    func testOverpassFilter() {
        XCTAssertTrue(ParkingData.keep(["amenity": "parking", "name": "Parcheggio Porta al Prato"]))
        XCTAssertTrue(ParkingData.keep(["amenity": "parking", "parking": "underground"]))
        XCTAssertTrue(ParkingData.keep(["amenity": "parking", "capacity": "120"]))
        XCTAssertFalse(ParkingData.keep(["amenity": "parking", "name": "Condominio", "access": "private"]))
        XCTAssertFalse(ParkingData.keep(["amenity": "parking", "access": "customers", "name": "Supermercato"]))
        XCTAssertFalse(ParkingData.keep(["amenity": "parking", "parking": "street_side"]))
        XCTAssertFalse(ParkingData.keep(["amenity": "parking"]))           // piccolo e senza nome
        let json = #"{"elements":[{"type":"way","id":7,"center":{"lat":43.77,"lon":11.25},"tags":{"amenity":"parking","name":"Fortezza","fee":"yes","opening_hours":"24/7","capacity":"500","parking":"underground"}},{"type":"node","id":8,"lat":43.7,"lon":11.2,"tags":{"amenity":"parking","access":"private"}}]}"#
        let spots = ParkingData.fromOverpass(Data(json.utf8))
        XCTAssertEqual(spots?.count, 1)
        XCTAssertEqual(spots?.first?.id, "w7")
        XCTAssertEqual(spots?.first?.capacity, 500)
        XCTAssertEqual(spots?.first?.priceText, L("Paid parking"))
    }

    func testBundledParkingFilesDecode() throws {
        let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/Parking")
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil))?.filter { $0.pathExtension == "json" } ?? []
        for f in files {
            let file = try JSONDecoder().decode(ParkingFile.self, from: Data(contentsOf: f))
            XCTAssertEqual(file.city, f.deletingPathExtension().lastPathComponent)
            XCTAssertFalse(file.spots.isEmpty, f.lastPathComponent)
        }
    }

    // MARK: L'ora dei chip

    func testTimeChoices() {
        let afternoon = date(2026, 10, 26, 15, 10)
        XCTAssertEqual(TimeChoice.tonight(now: afternoon, calendar: cal), date(2026, 10, 26, 20))
        XCTAssertNil(TimeChoice.tonight(now: date(2026, 10, 26, 20, 30), calendar: cal))
        XCTAssertEqual(TimeChoice.tomorrowMorning(now: date(2026, 10, 26, 23, 50), calendar: cal), date(2026, 10, 27, 9))
        // Un'ora già passata vale «adesso»
        XCTAssertEqual(TimeChoice.effective(date(2026, 10, 26, 9), now: afternoon), afternoon)
        XCTAssertEqual(TimeChoice.effective(nil, now: afternoon), afternoon)
        XCTAssertEqual(TimeChoice.effective(date(2026, 10, 26, 20), now: afternoon), date(2026, 10, 26, 20))
        XCTAssertEqual(TimeChoice.label(nil, now: afternoon, calendar: cal), L("Now"))
    }

    func testAccessFromVerdict() {
        XCTAssertEqual(Access(.no(reason: "")), .closed)
        XCTAssertEqual(Access(.conditional(reason: "", condition: "")), .conditional)
        XCTAssertEqual(Access(.unsure(reason: "")), .check)
        XCTAssertEqual(Access(.yes(reason: "")), .open)
        XCTAssertEqual(Access(.yes(reason: ""), status: .sample), .check)      // dati di esempio: mai un «sì» pieno
        XCTAssertEqual(Access(.no(reason: ""), status: .sample), .closed)
        XCTAssertEqual(Access(.yes(reason: ""), status: .draft), .open)
    }
}
