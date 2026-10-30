import XCTest

/// 1.19.0 «Mai un verde che non sappiamo»: la zona peggiore decide, fuori copertura neutro, fonte non ufficiale gialla,
/// pannello LED dallo stato vero dei varchi, nessun «hotelInside» nascosto.
final class NeverGreenTests: XCTestCase {
    private static let cities = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Resources/Cities")

    /// «Oggi» fisso: le schede non diventano «vecchie» (oltre 120 giorni) col passare dei mesi
    private let engine: RuleEngine = {
        var e = RuleEngine()
        let today = RuleEngine.rome.date(from: DateComponents(year: 2026, month: 10, day: 30, hour: 12))!
        e.now = { today }
        return e
    }()

    private func city(_ id: String) throws -> City {
        try CityLoader.decode(Data(contentsOf: Self.cities.appendingPathComponent("\(id).json")))
    }

    private func allCities() throws -> [City] {
        try FileManager.default.contentsOfDirectory(at: Self.cities, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" && $0.lastPathComponent != "manifest.json" }
            .map { try CityLoader.decode(Data(contentsOf: $0)) }
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        RuleEngine.rome.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    /// La risposta del posto con le stesse regole di PlaceCheck(_:store:at:), senza Store
    private func check(_ name: String, _ lat: Double, _ lon: Double, in cities: [City], vehicle: Vehicle, at d: Date) -> PlaceCheck {
        let p = Coordinate(lat: lat, lon: lon)
        let hits = Store.zones(at: p, in: cities)
        return PlaceCheck(place: Place(name: name, address: "", location: p), hits: hits,
                          answers: hits.map { engine.answer(zone: $0.zone, vehicle: vehicle, permits: [], hotelInside: false, at: d) },
                          covered: Store.covers(p, in: cities))
    }

    // MARK: #3 La zona peggiore decide

    /// Palazzo Vecchio, martedì 3 novembre 2026 alle 22, diesel Euro 1: il Settore A è spento ma lo Scudo Verde
    /// (sempre attivo) lo vieta. Prima «Entra pure.» dalla zona più piccola
    func testPalazzoVecchioDieselEuro1AtNightIsNo() throws {
        let firenze = try city("firenze")
        let euro1 = Vehicle(name: "", fuel: .diesel, euro: 1)
        let c = check("Palazzo Vecchio", 43.7696, 11.2558, in: [firenze], vehicle: euro1, at: date(2026, 11, 3, 22))
        XCTAssertEqual(c.hits.map(\.zone.id), ["firenze-a", "firenze-scudo-verde"], "dalla più piccola")
        XCTAssertTrue(c.answers[0].verdict.isYes, "il Settore A da solo direbbe sì")
        XCTAssertEqual(c.kind, .closed)
        XCTAssertEqual(c.zone?.id, "firenze-scudo-verde", "la zona che decide si vede")
        let a = Home2Answer(c, now: date(2026, 11, 3, 21))
        XCTAssertEqual(a.headline, L("Don't enter."))
        XCTAssertEqual(a.mood, .red)
        XCTAssertEqual(a.panel.lines, ["ZTL", "ATTIVA"], "lo Scudo Verde è acceso")
        // La stessa auto Euro 6 entra: decide il Settore A (spento), come prima
        let euro6 = check("Palazzo Vecchio", 43.7696, 11.2558, in: [firenze], vehicle: SampleData.rental, at: date(2026, 11, 3, 22))
        XCTAssertEqual(euro6.kind, .open)
        XCTAssertEqual(euro6.zone?.id, "firenze-a")
    }

    /// Milano, Corso Magenta (Area C dentro l'Area B), mercoledì alle 11, benzina Euro 6: l'Area B la ammette, l'Area C
    /// chiede il biglietto: decide la condizione. Diesel Euro 5: vietata in entrambe
    func testMilanAreaCInsideAreaBTakesTheWorst() throws {
        let milano = try city("milano")
        let petrol = check("Corso Magenta", 45.4658, 9.1780, in: [milano], vehicle: SampleData.rental, at: date(2026, 11, 4, 11))
        XCTAssertEqual(Set(petrol.hits.map(\.zone.id)), ["milano-c", "milano-b"])
        XCTAssertEqual(petrol.kind, .conditional)
        XCTAssertEqual(petrol.zone?.id, "milano-c")
        let diesel = check("Corso Magenta", 45.4658, 9.1780, in: [milano], vehicle: Vehicle(name: "", fuel: .diesel, euro: 5), at: date(2026, 11, 4, 11))
        XCTAssertEqual(diesel.kind, .closed)
    }

    /// L'ordine: no > condizione > non sicuro > sì; a parità la prima (la più piccola)
    func testWorstOrder() {
        let z = SampleData.sectorA
        func a(_ v: Verdict) -> Answer { Answer(verdict: v, gatesOn: true, nextChange: nil) }
        let yes = a(.yes(reason: "")), no = a(.no(reason: "")), cond = a(.conditional(reason: "", condition: "")), unsure = a(.unsure(reason: ""))
        XCTAssertEqual(PlaceCheck.worst([z, z], [yes, no]), 1)
        XCTAssertEqual(PlaceCheck.worst([z, z], [no, cond]), 0)
        XCTAssertEqual(PlaceCheck.worst([z, z], [unsure, cond]), 1)
        XCTAssertEqual(PlaceCheck.worst([z, z], [yes, unsure]), 1)
        XCTAssertEqual(PlaceCheck.worst([z, z], [yes, yes]), 0)
        XCTAssertNil(PlaceCheck.worst([], []))
        // Un «sì» da fonte non ufficiale conta come «non sicuro»
        var u = z; u.source.official = false
        XCTAssertEqual(PlaceCheck.worst([z, u], [yes, yes]), 1)
    }

    // MARK: #2 Fuori copertura

    /// Pistoia non è tra le città: «Non conosciamo le ZTL di questo posto», neutro, mai verde né «Arrivo sereno»
    func testPistoiaIsUncovered() throws {
        let all = try allCities()
        let pistoia = Coordinate(lat: 43.9333, lon: 10.9167)
        XCTAssertFalse(Store.covers(pistoia, in: all))
        XCTAssertTrue(Store.zones(at: pistoia, in: all).isEmpty)
        let c = check("Piazza del Duomo", pistoia.lat, pistoia.lon, in: all, vehicle: SampleData.rental, at: date(2026, 11, 3, 10))
        XCTAssertEqual(c.kind, .uncovered)
        XCTAssertFalse(c.verdict.isYes)
        XCTAssertEqual(c.zoneLine, L("We don't know the ZTLs of this place"))
        XCTAssertEqual(c.symbol, "questionmark")
        let a = Home2Answer(c, now: Date())
        XCTAssertEqual(a.mood, .neutral)
        XCTAssertNotEqual(a.headline, L("Easy arrival."))
        XCTAssertEqual(a.headline, L("We don't know this place."))
        XCTAssertEqual(a.panel.lines, ["ZONA", "NON COPERTA"])
        XCTAssertEqual(a.panel.mood, .neutral)
    }

    /// Dentro una città che conosciamo ma fuori dalle sue zone: «Fuori dalla ZTL», verde. A Prato (10 km dallo Scudo
    /// Verde) no: è fuori copertura
    func testOutsideOnlyInsideACoveredCity() throws {
        let all = try allCities()
        // Lucca, 1 km fuori dalle zone → fuori dalla ZTL; 5,5 km → fuori copertura
        let lucca = try city("lucca")
        let box = try XCTUnwrap(lucca.coverage)
        let near = Coordinate(lat: box.minLat - 0.009, lon: (box.minLon + box.maxLon) / 2)     // ~1 km a sud
        XCTAssertTrue(Store.covers(near, in: all))
        let c = check("Lucca sud", near.lat, near.lon, in: all, vehicle: SampleData.rental, at: date(2026, 11, 3, 10))
        XCTAssertEqual(c.kind, .outside)
        XCTAssertEqual(Home2Answer(c, now: Date()).mood, .green)
        let far = Coordinate(lat: box.minLat - 0.05, lon: (box.minLon + box.maxLon) / 2)        // ~5,5 km a sud
        XCTAssertFalse(Store.covers(far, in: all))
        XCTAssertFalse(Store.covers(Coordinate(lat: 43.8777, lon: 11.1022), in: all), "Prato")
        XCTAssertTrue(Store.covers(Coordinate(lat: 43.7696, lon: 11.2558), in: all), "Palazzo Vecchio")
    }

    // MARK: #1 Fonte non ufficiale

    /// Un «sì» da fonte non ufficiale è giallo con il «?» ovunque: PlaceCheck, Varco, pillole, Siri, guardiano
    func testUnofficialYesIsYellow() throws {
        var firenze = try city("firenze")
        for i in firenze.zones.indices { firenze.zones[i].source.official = false }
        let c = check("Palazzo Vecchio", 43.7696, 11.2558, in: [firenze], vehicle: SampleData.rental, at: date(2026, 11, 3, 22))
        XCTAssertEqual(c.kind, .open)
        XCTAssertTrue(c.unofficial)
        XCTAssertTrue(c.hedged)
        XCTAssertEqual(c.symbol, "questionmark")
        XCTAssertNotEqual(c.tint, Theme.green)
        let a = Home2Answer(c, now: date(2026, 11, 3, 21))
        XCTAssertEqual(a.mood, .amber)
        XCTAssertEqual(a.panel.mood, .amber)
        XCTAssertEqual(a.headline, L("Probably yes."))
        XCTAssertEqual(a.detail, L("Unofficial source: check the sign."))
        // Il motore non cambia: la risposta è sì, si MOSTRA come «non sicuro»
        let yes = Verdict.yes(reason: "r")
        guard case .unsure = yes.shown(unofficial: true) else { return XCTFail("atteso non sicuro") }
        XCTAssertEqual(yes.shown(unofficial: false), yes)
        XCTAssertEqual(yes.spokenText(unofficial: true), L("Probably yes · unofficial source: check the sign"))
        XCTAssertEqual(yes.spokenText(unofficial: false), yes.short)
        XCTAssertEqual(yes.shown(unofficial: true).symbol, "questionmark")
        // Il guardiano avvisa anche per un «sì» non ufficiale (prima lo saltava come via libera)
        var zone = SampleData.sectorA
        zone.source.official = false
        let far = Coordinate(lat: 43.7700, lon: 11.2300), nearer = Coordinate(lat: 43.7710, lon: 11.2360)
        let open: (Zone, Double) -> Answer = { _, _ in Answer(verdict: .yes(reason: ""), gatesOn: false, nextChange: nil) }
        let first = Guardian.scan(at: far, zones: [zone], last: [:], answer: open)
        XCTAssertNotNil(Guardian.scan(at: nearer, zones: [zone], last: first.distances, answer: open).threat)
        let first2 = Guardian.scan(at: far, zones: [SampleData.sectorA], last: [:], answer: open)
        XCTAssertNil(Guardian.scan(at: nearer, zones: [SampleData.sectorA], last: first2.distances, answer: open).threat)
    }

    // MARK: #6 Il pannello LED

    /// Il testo dallo stato vero dei varchi, il colore dalla risposta: mai «NON ATTIVA» a varchi accesi né «ATTIVA» a spenti
    func testLEDMatrix() throws {
        let firenze = try city("firenze")
        let hits = [(city: firenze, zone: firenze.zones[0])]
        let place = Place(name: "Prova", address: "", location: firenze.center)
        let verdicts: [(Verdict, Home2Answer.Mood)] = [
            (.yes(reason: ""), .green), (.no(reason: ""), .red),
            (.conditional(reason: "", condition: "c"), .amber), (.unsure(reason: ""), .amber),
        ]
        for gatesOn in [true, false] {
            for (v, mood) in verdicts {
                let a = Home2Answer(PlaceCheck(place: place, hits: hits, answer: Answer(verdict: v, gatesOn: gatesOn, nextChange: nil)), now: Date())
                let text = a.panel.lines.joined(separator: " ")
                XCTAssertEqual(a.panel.mood, mood, "\(v) \(gatesOn)")
                XCTAssertEqual(a.mood, mood)
                if gatesOn {
                    XCTAssertTrue(text.contains("ZTL ATTIVA") || a.panel.lines == ["ZTL", "ATTIVA"], text)
                    XCTAssertFalse(text.contains("NON ATTIVA"), text)
                } else {
                    XCTAssertEqual(a.panel.lines, ["ZTL", "NON ATTIVA"], "\(v)")
                }
                if gatesOn, v.isYes { XCTAssertEqual(a.panel.lines, ["ZTL ATTIVA", "SEI ESENTE"]) }
                XCTAssertFalse(text.contains("VARCO"), "dicitura vecchia: \(text)")
            }
        }
    }

    // MARK: #12 hotelInside

    /// La condizione «l'hotel registra la targa» vale solo se il posto è il tuo hotel (un viaggio salvato)
    @MainActor
    func testHotelInsideOnlyForYourHotel() async {
        let store = Store()
        await store.whenLoaded()
        let savedTrips = store.trips, savedVehicles = store.vehicles, savedActive = store.activeVehicleId, savedPermits = store.permits
        defer { store.trips = savedTrips; store.vehicles = savedVehicles; store.activeVehicleId = savedActive; store.permits = savedPermits }
        store.cities = [SampleData.florence]
        store.vehicles = [SampleData.rental]; store.activeVehicleId = SampleData.rental.id; store.permits = []
        store.trips = []
        // Un giorno feriale alle 10 a Roma, non festivo: il Settore A di esempio è acceso
        let cal = RuleEngine.rome
        var day = cal.startOfDay(for: Date())
        repeat { day = cal.date(byAdding: .day, value: 1, to: day)! } while !(2...6).contains(cal.component(.weekday, from: day)) || ItalianHolidays.isHoliday(day, calendar: cal)
        let at = cal.date(bySettingHour: 10, minute: 0, second: 0, of: day)!
        let hotel = Place(name: "Hotel di prova", address: "", location: Coordinate(lat: 43.7731, lon: 11.2560))
        XCTAssertFalse(store.isHotel(hotel))
        guard case .no = PlaceCheck(hotel, store: store, at: at).answer?.verdict else { return XCTFail("senza hotel: non entrare") }
        // La scheda zona, la mappa, gli avvisi e CarPlay passano false: niente condizione nascosta
        guard case .no = store.answer(at: at, zone: SampleData.sectorA, hotelInside: false).verdict else { return XCTFail("atteso no") }
        store.trips = [Trip(hotel: hotel, hotelName: hotel.name, arrival: at, departure: at, vehicleId: nil)]
        XCTAssertTrue(store.isHotel(hotel))
        guard case .conditional = PlaceCheck(hotel, store: store, at: at).answer?.verdict else { return XCTFail("il tuo hotel: a una condizione") }
    }
}
