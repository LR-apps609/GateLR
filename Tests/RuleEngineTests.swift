import XCTest
import CoreLocation
import CryptoKit

final class RuleEngineTests: XCTestCase {
    /// «Oggi» fisso al 26 ottobre 2026: le schede delle città non diventano «vecchie» col passare dei mesi
    private let engine: RuleEngine = {
        var e = RuleEngine()
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Europe/Rome")!
        let today = c.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 12))!
        e.now = { today }
        return e
    }()
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
        XCTAssertEqual(Set(city.zones.map(\.id)), ["firenze-a", "firenze-b", "firenze-o", "firenze-f", "firenze-g", "firenze-scudo-verde"])
        // Scudo Verde: Duomo dentro, aeroporto fuori; diesel Euro 2 libero fino al 30/11/2026, vietato dal 1/12/2026
        let sv = try XCTUnwrap(city.zones.first { $0.id == "firenze-scudo-verde" })
        XCTAssertEqual(sv.type, .green)
        XCTAssertTrue(sv.contains(lat: 43.7731, lon: 11.2560))
        XCTAssertFalse(sv.contains(lat: 43.8100, lon: 11.2051))
        var diesel2 = car; diesel2.fuel = .diesel; diesel2.euro = 2
        XCTAssertNil(sv.ban(for: diesel2, at: date(2026, 11, 30, 12)))
        XCTAssertNotNil(sv.ban(for: diesel2, at: date(2026, 12, 1, 12)))
        XCTAssertNil(sv.ban(for: car, at: date(2026, 12, 1, 12)))
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

    /// Tutte le città incluse nell'app si leggono, e Bologna e Milano rispondono come dicono i Comuni
    func testAllCityFiles() throws {
        let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/Cities")
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" && $0.lastPathComponent != "manifest.json" }
        XCTAssertGreaterThanOrEqual(files.count, 3)
        var cities: [String: City] = [:]
        for f in files { let c = try CityLoader.decode(Data(contentsOf: f)); cities[c.id] = c }
        let bo = try XCTUnwrap(cities["bologna"]?.zones.first { $0.id == "bologna-ztl" })
        XCTAssertTrue(engine.isActive(bo, at: date(2026, 10, 25, 10)))          // domenica: attiva tutti i giorni
        XCTAssertFalse(engine.isActive(bo, at: date(2026, 10, 25, 21)))
        let a = engine.answer(zone: bo, vehicle: car, permits: [], hotelInside: false, at: date(2026, 10, 26, 10))
        guard case .conditional = a.verdict else { return XCTFail("Bologna: atteso biglietto, ottenuto \(a.verdict)") }
        let mi = try XCTUnwrap(cities["milano"]?.zones.first { $0.id == "milano-c" })
        XCTAssertTrue(engine.isActive(mi, at: date(2026, 10, 26, 10)))           // lunedì
        XCTAssertFalse(engine.isActive(mi, at: date(2026, 10, 24, 10)))          // sabato
        XCTAssertFalse(engine.isActive(mi, at: date(2026, 12, 8, 10)))           // Immacolata: festivi esclusi
        XCTAssertNotNil(mi.ticket)
    }

    /// Fasce notturne e festivi: dopo mezzanotte conta il giorno in cui è iniziata la fascia.
    /// Feste del patrono: il 29 giugno a Roma è festivo, a Firenze no.
    func testNightHolidaysAndPatronDays() throws {
        let cities = try bundledCities()
        let centro = try XCTUnwrap(cities["roma"]?.zones.first { $0.id == "roma-centro" })
        // Sabato 1° maggio 2027 è festivo: la notte sabato 23 → domenica 3 è libera
        XCTAssertFalse(engine.isActive(centro, at: date(2027, 5, 1, 23, 30)))
        XCTAssertFalse(engine.isActive(centro, at: date(2027, 5, 2, 1, 0)))
        // La notte di venerdì 30 aprile (feriale) che sfocia nel sabato festivo resta attiva
        XCTAssertTrue(engine.isActive(centro, at: date(2027, 4, 30, 23, 30)))
        XCTAssertTrue(engine.isActive(centro, at: date(2027, 5, 1, 1, 0)))
        // Una notte qualsiasi resta attiva, prima e dopo mezzanotte
        XCTAssertTrue(engine.isActive(centro, at: date(2026, 10, 24, 1, 0)))
        // Lunedì 29 giugno 2026, Santi Pietro e Paolo: a Roma è festa, ZTL diurna spenta
        XCTAssertEqual(centro.localHolidays, ["06-29"])
        XCTAssertFalse(engine.isActive(centro, at: date(2026, 6, 29, 10)))
        XCTAssertTrue(engine.isActive(centro, at: date(2026, 6, 30, 10)))
        // Stesso giorno a Firenze (nessuna festa locale): attiva secondo i suoi orari
        let fiA = try XCTUnwrap(cities["firenze"]?.zones.first { $0.id == "firenze-a" })
        XCTAssertNil(fiA.localHolidays)
        XCTAssertTrue(engine.isActive(fiA, at: date(2026, 6, 29, 10)))
        let a = engine.answer(zone: fiA, vehicle: car, permits: [], hotelInside: false, at: date(2026, 6, 29, 10))
        XCTAssertTrue(a.gatesOn)
        if case .unsure = a.verdict { XCTFail("Firenze 29 giugno: non è festivo, atteso attiva") }
        // Festivo sconosciuto (freeOnHolidays nil): anche qui conta il giorno d'inizio della notte
        var fi = fiA; fi.freeOnHolidays = nil
        let fri = engine.answer(zone: fi, vehicle: car, permits: [], hotelInside: false, at: date(2027, 5, 1, 1, 0))
        if case .unsure = fri.verdict { XCTFail("notte di venerdì feriale: non è un festivo") }
        let sat = engine.answer(zone: fi, vehicle: car, permits: [], hotelInside: false, at: date(2027, 5, 2, 1, 0))
        guard case .unsure = sat.verdict else { return XCTFail("notte del sabato festivo: atteso non sicuro, ottenuto \(sat.verdict)") }
    }

    private func bundledCities() throws -> [String: City] {
        let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/Cities")
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" && $0.lastPathComponent != "manifest.json" }
        var cities: [String: City] = [:]
        for f in files { let c = try CityLoader.decode(Data(contentsOf: f)); cities[c.id] = c }
        return cities
    }

    /// Area B di Milano: zona verde con i divieti per classe Euro; elettriche sempre sì
    func testGreenZone() throws {
        let milan = try XCTUnwrap(try bundledCities()["milano"])
        let b = try XCTUnwrap(milan.zones.first { $0.id == "milano-b" })
        let c = try XCTUnwrap(milan.zones.first { $0.id == "milano-c" })
        XCTAssertEqual(b.type, .green)
        let monday = date(2026, 10, 26, 10)
        func verdict(_ z: Zone, _ fuel: Fuel, _ euro: Int, _ d: Date) -> Verdict {
            var v = car; v.fuel = fuel; v.euro = euro
            return engine.answer(zone: z, vehicle: v, permits: [], hotelInside: false, at: d).verdict
        }
        guard case .yes = verdict(b, .petrol, 6, monday) else { return XCTFail("benzina Euro 6: atteso sì") }
        guard case .yes = verdict(b, .electric, 0, monday) else { return XCTFail("elettrica: atteso sì") }
        guard case .no = verdict(b, .diesel, 5, monday) else { return XCTFail("diesel Euro 5: atteso no") }
        guard case .no = verdict(b, .petrol, 3, monday) else { return XCTFail("benzina Euro 3: atteso no") }
        guard case .yes(let r) = verdict(b, .petrol, 4, monday) else { return XCTFail("benzina Euro 4 nel 2026: atteso sì") }
        XCTAssertTrue(r.contains("2028"), r)
        guard case .no = verdict(b, .petrol, 4, date(2028, 10, 2, 10)) else { return XCTFail("benzina Euro 4 nel 2028: atteso no") }
        guard case .no = verdict(c, .diesel, 5, monday) else { return XCTFail("Area C diesel Euro 5: atteso no anche col ticket") }
        guard case .conditional = verdict(c, .petrol, 6, monday) else { return XCTFail("Area C benzina Euro 6: atteso ticket") }
        XCTAssertFalse(engine.isActive(b, at: date(2026, 10, 25, 10)))     // domenica
    }

    /// Dall'indirizzo alla zona: il Duomo di Milano è in Area C (dentro Area B), Palazzo Vecchio in un settore di Firenze
    func testZoneAtAddress() throws {
        let cities = try bundledCities()
        func zones(_ lat: Double, _ lon: Double) -> [Zone] {
            cities.values.flatMap(\.zones).filter { $0.contains(lat: lat, lon: lon) }.sorted { $0.roughArea < $1.roughArea }
        }
        XCTAssertEqual(zones(45.4641, 9.1919).map(\.id), ["milano-c", "milano-b"])
        XCTAssertEqual(zones(43.7696, 11.2558).first?.type, .restricted)
        XCTAssertTrue(zones(43.7764, 11.2480).contains { $0.id.hasPrefix("firenze") })      // Santa Maria Novella
        XCTAssertTrue(zones(41.9028, 12.4964).isEmpty)                                       // Roma, piazza della Repubblica: fuori dalle ZTL
        XCTAssertTrue(zones(41.8986, 12.4769).contains { $0.id == "roma-centro" })            // Pantheon (perimetro OSM dal 24/10/2026)
        let c = try XCTUnwrap(cities["milano"]?.zones.first { $0.id == "milano-c" })
        XCTAssertEqual(c.distance(lat: 45.4641, lon: 9.1919), 0)
        XCTAssertGreaterThan(c.distance(lat: 45.4850, lon: 9.2040), 300)                     // Stazione Centrale: fuori
    }

    func testCitiesAreTranslated() throws {
        for city in try bundledCities().values {
            XCTAssertNotNil(city.name_it, city.id)
            for z in city.zones {
                XCTAssertNotNil(z.summary_it, z.id); XCTAssertNotNil(z.summary_de, z.id)
                XCTAssertNotNil(z.kind, z.id)
                XCTAssertNotNil(z.source.pending_it, z.id)
                XCTAssertNotNil(z.source.quoteTranslation_de, z.id)
                if let t = z.ticket { XCTAssertNotNil(t.howTo_it, z.id) }
            }
        }
    }

    /// Il controllo del percorso: entrando a Firenze di giorno il centro dice «no»; la zona di partenza non conta
    func testRouteCrossings() throws {
        let florence = try XCTUnwrap(try bundledCities()["firenze"])
        let path = RouteCheck.densify([Coordinate(lat: 43.7900, lon: 11.2400), Coordinate(lat: 43.7696, lon: 11.2558)])
        XCTAssertGreaterThan(path.count, 20)
        let monday10 = date(2026, 10, 26, 10)
        let crossings = RouteCheck.crossings(path: path, zones: florence.zones, departure: monday10, travelTime: 600) {
            self.engine.answer(zone: $0, vehicle: self.car, permits: [], hotelInside: false, at: $1)
        }
        XCTAssertFalse(crossings.isEmpty)
        XCTAssertTrue(crossings.contains { $0.isDestination })
        guard case .no = RouteCheck.worst(crossings)?.answer.verdict else { return XCTFail("atteso no") }
        XCTAssertTrue(crossings.allSatisfy { $0.at >= monday10 && $0.at <= monday10.addingTimeInterval(600) })
        // Di notte (lunedì 22:00, fuori stagione estiva) tutto libero
        let night = RouteCheck.crossings(path: path, zones: florence.zones, departure: date(2026, 10, 26, 22), travelTime: 600) {
            self.engine.answer(zone: $0, vehicle: self.car, permits: [], hotelInside: false, at: $1)
        }
        XCTAssertTrue(night.allSatisfy { if case .yes = $0.answer.verdict { true } else { false } })
        // Partendo da dentro, la zona di partenza non è un «ingresso»
        let fromInside = RouteCheck.crossings(path: Array(path.reversed()), zones: florence.zones, departure: monday10, travelTime: 600) {
            self.engine.answer(zone: $0, vehicle: self.car, permits: [], hotelInside: false, at: $1)
        }
        XCTAssertFalse(fromInside.contains { $0.zone.contains(lat: 43.7696, lon: 11.2558) })
    }

    func testCarAdvice() throws {
        XCTAssertEqual(CarCatalog.euro(forYear: 2019), 6)
        XCTAssertEqual(CarCatalog.euro(forYear: 2012), 5)
        XCTAssertEqual(CarCatalog.euro(forYear: 2004), 3)
        let cities = Array(try bundledCities().values)
        var v = car; v.fuel = .diesel; v.euro = 5
        let lines = CarAdvice.lines(for: v, cities: cities, at: date(2026, 10, 26, 10))
        XCTAssertEqual(lines.filter { !$0.ok }.count, 2)                       // Area B e Area C
        v.fuel = .electric
        XCTAssertTrue(CarAdvice.lines(for: v, cities: cities, at: date(2026, 10, 26, 10)).allSatisfy(\.ok))
        let catalog = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/Rules/cars.json"))) as? [String: Any]
        XCTAssertGreaterThan((catalog?["makes"] as? [Any])?.count ?? 0, 20)
    }

    func testNearestGates() throws {
        let milan = try XCTUnwrap(try bundledCities()["milano"])
        let all = milan.zones.flatMap { z in z.gates.map { (z, $0) } }
        XCTAssertGreaterThan(all.count, 200)
        let duomo = CLLocation(latitude: 45.4641, longitude: 9.1919)
        let near = GateMonitor.nearest(all, to: duomo, limit: 20)
        XCTAssertEqual(near.count, 20)
        let far = near.map { duomo.distance(from: CLLocation(latitude: $0.1.location.lat, longitude: $0.1.location.lon)) }
        XCTAssertEqual(far, far.sorted())
        XCTAssertTrue(near.allSatisfy { $0.0.id == "milano-c" } || near.contains { $0.0.id == "milano-c" })
    }

    /// Zone sempre attive o ferme per mesi: il calcolo del prossimo cambio deve restare veloce
    func testChangeScanIsFast() throws {
        let cities = try bundledCities()
        let t = try XCTUnwrap(cities["bologna"]?.zones.first { $0.id == "bologna-t" })
        let g = try XCTUnwrap(cities["firenze"]?.zones.first { $0.id == "firenze-g" })
        let start = Date()
        for _ in 0..<200 {
            _ = engine.nextChange(t, after: date(2026, 10, 26, 10)); _ = engine.previousChange(t, before: date(2026, 10, 26, 10))
            _ = engine.nextChange(g, after: date(2026, 11, 26, 10))
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 8)      // prima: oltre 2.000 controlli per calcolo
        XCTAssertNil(engine.nextChange(t, after: date(2026, 10, 26, 10)))
        // ZTL notturna estiva: dal giovedì 23:00 al venerdì 3:00
        XCTAssertEqual(engine.nextChange(g, after: date(2026, 7, 2, 12)), date(2026, 7, 2, 23))
        XCTAssertEqual(engine.nextChange(g, after: date(2026, 7, 2, 23, 30)), date(2026, 7, 3, 3))
        XCTAssertEqual(engine.previousChange(g, before: date(2026, 7, 3, 1)), date(2026, 7, 2, 23))
    }

    func testPathMathAndManeuvers() {
        let path = [Coordinate(lat: 43.7700, lon: 11.2500), Coordinate(lat: 43.7700, lon: 11.2600), Coordinate(lat: 43.7800, lon: 11.2600)]
        let total = PathMath.remaining(from: path[0], along: path)
        XCTAssertEqual(total, 806 + 1110, accuracy: 30)                                   // ~806 m verso est + ~1110 m verso nord
        XCTAssertEqual(PathMath.remaining(from: path[2], along: path), 0, accuracy: 1)
        XCTAssertLessThan(PathMath.distance(from: Coordinate(lat: 43.7701, lon: 11.2550), to: path), 15)
        XCTAssertGreaterThan(PathMath.distance(from: Coordinate(lat: 43.7750, lon: 11.2500), to: path), 300)
        XCTAssertEqual(DriveView.symbol(for: "Svolta a sinistra in Via Roma"), "arrow.turn.up.left")
        XCTAssertEqual(DriveView.symbol(for: "Turn right onto Via Roma"), "arrow.turn.up.right")
        XCTAssertEqual(DriveView.symbol(for: "Im Kreisverkehr die zweite Ausfahrt nehmen"), "arrow.triangle.turn.up.right.circle")
    }

    /// L'elenco scaricato dall'app deve corrispondere ai file (altrimenti l'aggiornamento li scarterebbe)
    func testManifestMatchesFiles() throws {
        let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/Cities")
        let m = try JSONDecoder().decode(CityLoader.Manifest.self, from: Data(contentsOf: dir.appendingPathComponent("manifest.json")))
        XCTAssertEqual(m.schema, 1)
        for e in m.cities {
            let data = try Data(contentsOf: dir.appendingPathComponent(e.file))
            let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            XCTAssertEqual(hash, e.sha256, "Rilancia Tools/build_manifest.py dopo aver cambiato \(e.file)")
        }
    }

    func testPedestrianAreasAndCameras() throws {
        let cities = try bundledCities()
        let bo = try XCTUnwrap(cities["bologna"])
        XCTAssertGreaterThan(bo.pedestrian?.count ?? 0, 30)
        XCTAssertTrue(bo.pedestrian?.contains { $0.contains(lat: 44.4939, lon: 11.3426) } ?? false)   // Piazza Maggiore
        XCTAssertGreaterThan(cities["milano"]?.pedestrian?.count ?? 0, 50)
        XCTAssertGreaterThan(bo.cameras?.filter { $0.kind == .bus }.count ?? 0, 10)
        XCTAssertGreaterThan(cities["firenze"]?.cameras?.count ?? 0, 3)
    }

    func testHotelStayDaysAndMessage() {
        let stay = HotelStay(arrival: date(2026, 11, 2, 18), departure: date(2026, 11, 5, 10))
        XCTAssertEqual(stay.days.count, 4)                                           // 2, 3, 4 e 5 (partenza)
        let m = MessageLanguage.it.message(arrival: date(2026, 11, 2, 18), plate: "AB123CD", hotel: "Hotel Test", departure: date(2026, 11, 5, 10))
        XCTAssertTrue(m.contains("AB123CD") && m.contains("per iscritto") && m.contains("partenza"))
        let p = Place(name: "Hotel Test", address: "", location: Coordinate(lat: 43.77, lon: 11.25))
        XCTAssertEqual(p.key, Place(name: "Hotel Test", address: "x", location: Coordinate(lat: 43.770001, lon: 11.250001)).key)
    }

    func testSignReader() {
        let a = SignReader.parse("ZONA TRAFFICO LIMITATO\n7.30-20.00\nFERIALI\nCONTROLLO ELETTRONICO")
        XCTAssertEqual(a.rules, [SignReader.Rule(days: [2, 3, 4, 5, 6, 7], start: 450, end: 1200)])
        XCTAssertTrue(a.holidaysExcluded)
        XCTAssertTrue(SignReader.isActive(a, at: date(2026, 10, 26, 10), calendar: cal))       // lunedì
        XCTAssertFalse(SignReader.isActive(a, at: date(2026, 10, 25, 10), calendar: cal))      // domenica
        XCTAssertFalse(SignReader.isActive(a, at: date(2026, 10, 26, 21), calendar: cal))

        let b = SignReader.parse("LUN-VEN 7:30 - 19:30\nfestivi esclusi")
        XCTAssertEqual(b.rules.first?.days, [2, 3, 4, 5, 6])
        XCTAssertEqual(b.rules.first?.start, 450)
        XCTAssertFalse(SignReader.isActive(b, at: date(2026, 12, 8, 10), calendar: cal))        // Immacolata

        let c = SignReader.parse("GIO VEN SAB dalle 23 alle 3")
        XCTAssertEqual(c.rules.first?.days, [5, 6, 7])
        XCTAssertTrue(SignReader.isActive(c, at: date(2026, 7, 3, 1), calendar: cal))           // venerdì all'una
        XCTAssertFalse(SignReader.parse("Benvenuti a Firenze").understood)
        XCTAssertEqual(SignReader.parse("TUTTI I GIORNI 0-24").rules.first?.days.count, 7)
    }

    /// Il guardiano: avvisa solo se ti avvicini a una zona dove non entri; segnala l'ingresso
    func testGuardianScan() throws {
        let florence = try XCTUnwrap(try bundledCities()["firenze"])
        let monday10 = date(2026, 10, 26, 10)
        let answer: (Zone, Double) -> Answer = { z, _ in self.engine.answer(zone: z, vehicle: self.car, permits: [], hotelInside: false, at: monday10) }
        let far = Coordinate(lat: 43.7900, lon: 11.2400), nearer = Coordinate(lat: 43.7850, lon: 11.2450)
        let first = Guardian.scan(at: far, zones: florence.zones, last: [:], answer: answer)
        XCTAssertNotNil(first.threat)
        let second = Guardian.scan(at: nearer, zones: florence.zones, last: first.distances, answer: answer)
        XCTAssertNotNil(second.threat)
        XCTAssertLessThan(second.threat!.meters, first.threat!.meters)
        // Allontanandosi: nessun avviso
        let away = Guardian.scan(at: far, zones: florence.zones, last: second.distances, answer: answer)
        XCTAssertNil(away.threat)
        // Entrando nel settore A (Palazzo Vecchio): segnalato come ingresso
        let inside = Guardian.scan(at: Coordinate(lat: 43.7696, lon: 11.2558), zones: florence.zones, last: second.distances, answer: answer)
        XCTAssertTrue(inside.entered.contains { $0.0.id == "firenze-a" })
        // Di notte (lunedì 22): niente da segnalare
        let night: (Zone, Double) -> Answer = { z, _ in self.engine.answer(zone: z, vehicle: self.car, permits: [], hotelInside: false, at: self.date(2026, 10, 26, 22)) }
        XCTAssertNil(Guardian.scan(at: nearer, zones: florence.zones, last: first.distances, answer: night).threat)
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

    /// Siri: «Florence Sector B» sceglie solo quella zona, «Firenze» tutte le zone della città
    func testSiriZoneMatching() {
        var city = SampleData.florence
        city.name_it = "Firenze"
        var b = SampleData.sectorA
        b.id = "firenze-b"; b.name = "Sector B · Outer ring"
        city.zones = [SampleData.sectorA, b]
        let all = city.zones.map { CityZoneEntity(city: city, zone: $0) }
        XCTAssertEqual(CityZoneEntity.matching("Florence Sector B", in: all).map(\.id), ["firenze-b"])
        XCTAssertEqual(CityZoneEntity.matching("firenze", in: all).count, 2)
        XCTAssertEqual(CityZoneEntity.matching("Flor", in: all).count, 2)
        XCTAssertTrue(CityZoneEntity.matching("Milano", in: all).isEmpty)
    }
}
