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
        XCTAssertEqual(a.headline, L("Don't enter"))
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
        XCTAssertNotEqual(a.headline, L("You can enter"))
        XCTAssertEqual(a.headline, L("We don't know this place"))
        XCTAssertEqual(a.panel.lines, ["ZONA", "NON COPERTA"])
        XCTAssertEqual(a.panel.mood, .neutral)
    }

    /// Dentro una città che conosciamo ma fuori dalle sue zone: «Fuori dalla ZTL», grigio (1.20.4, prima verde). A Prato
    /// (10 km dallo Scudo Verde) no: è fuori copertura
    func testOutsideOnlyInsideACoveredCity() throws {
        let all = try allCities()
        // Lucca, 1 km fuori dalle zone → fuori dalla ZTL; 5,5 km → fuori copertura
        let lucca = try city("lucca")
        let box = try XCTUnwrap(lucca.coverage)
        let near = Coordinate(lat: box.minLat - 0.009, lon: (box.minLon + box.maxLon) / 2)     // ~1 km a sud
        XCTAssertTrue(Store.covers(near, in: all))
        let c = check("Lucca sud", near.lat, near.lon, in: all, vehicle: SampleData.rental, at: date(2026, 11, 3, 10))
        XCTAssertEqual(c.kind, .outside)
        XCTAssertEqual(Home2Answer(c, now: Date()).mood, .grey)
        let far = Coordinate(lat: box.minLat - 0.05, lon: (box.minLon + box.maxLon) / 2)        // ~5,5 km a sud
        XCTAssertFalse(Store.covers(far, in: all))
        XCTAssertFalse(Store.covers(Coordinate(lat: 43.8777, lon: 11.1022), in: all), "Prato")
        XCTAssertTrue(Store.covers(Coordinate(lat: 43.7696, lon: 11.2558), in: all), "Palazzo Vecchio")
    }

    /// 1.20.4 (decisione di Ledion del 07/11): «Fuori dalla ZTL» in una città coperta è grigio neutro, con la stessa parola
    /// di prima e una forma neutra (il trattino, non la spunta): mai verde, né in Varco né sulla mappa né in Viaggio
    @MainActor
    func testOutsideIsGreyNeverGreen() throws {
        let all = try allCities()
        let lucca = try city("lucca")
        let box = try XCTUnwrap(lucca.coverage)
        let near = Coordinate(lat: box.minLat - 0.009, lon: (box.minLon + box.maxLon) / 2)
        let c = check("Lucca sud", near.lat, near.lon, in: all, vehicle: SampleData.rental, at: date(2026, 11, 3, 10))
        XCTAssertEqual(c.kind, .outside)
        XCTAssertTrue(c.showsOutside)
        XCTAssertEqual(c.colourName, "grey")
        XCTAssertNil(c.access, "fuori dalla ZTL non ha il colore di una zona")
        XCTAssertEqual(c.tint, Theme.outside)
        XCTAssertNotEqual(c.tint, Theme.green)
        XCTAssertEqual(c.symbol, "minus")
        XCTAssertNotEqual(c.symbol, "checkmark")
        XCTAssertEqual(c.zoneLine, L("Outside the ZTL"))
        // 2.1 «sette stati»: «Fuori dalla ZTL» ha la sua parola (prima «Puoi entrare»)
        XCTAssertEqual(c.word, .outside)
        XCTAssertEqual(c.finale.stato, .fuoriZTL)
        let a = Home2Answer(c, now: Date())
        XCTAssertEqual(a.mood, .grey)
        XCTAssertEqual(a.panel.mood, .grey)
        XCTAssertEqual(a.panel.lines, ["FUORI", "ZTL"])
        XCTAssertNotEqual(a.mood.hex, Home2Answer.Mood.green.hex)
        // Il grigio non è il neutro del posto che non conosciamo (quello resta con il «?»)
        XCTAssertNotEqual(a.mood, .neutral)
        // Il riquadro del guardiano e la Live Activity senza zone davanti: grigio, scudo vuoto
        let look = VarcoView.guardianLook(threat: nil, resting: .clear)
        XCTAssertEqual(look.symbol, "shield")
        XCTAssertEqual(Guardian.state(threat: nil, resting: .clear).symbol, "shield")
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
        XCTAssertEqual(a.headline, L("Check the sign"))
        XCTAssertEqual(a.detail, L("Probably yes · unofficial source"))
        // Il motore non cambia: la risposta è sì, si MOSTRA come «non sicuro»
        let yes = Verdict.yes(reason: "r")
        guard case .unsure = yes.shown(unofficial: true) else { return XCTFail("atteso non sicuro") }
        XCTAssertEqual(yes.shown(unofficial: false), yes)
        XCTAssertEqual(yes.spokenText(unofficial: true), L("Check the sign") + " · " + L("Probably yes · unofficial source"))
        XCTAssertEqual(yes.spokenText(unofficial: false), yes.short)
        XCTAssertEqual(yes.shown(unofficial: true).symbol, "questionmark")
        // Il guardiano avvisa anche per un «sì» non ufficiale (prima lo saltava come via libera)
        var zone = SampleData.sectorA
        zone.source.official = false
        let far = Coordinate(lat: 43.7700, lon: 11.2300), nearer = Coordinate(lat: 43.7710, lon: 11.2360)
        let open: (ThreatCandidate, Double) -> Answer = { _, _ in Answer(verdict: .yes(reason: ""), gatesOn: false, nextChange: nil) }
        func scan(_ p: Coordinate, _ z: Zone, _ last: [String: Double]) -> ThreatEvaluator.Scan {
            ThreatEvaluator.scan(at: p, course: nil, candidates: [ThreatCandidate(zone: z, cityName: "Firenze")], last: last, covered: true, answer: open)
        }
        let first = scan(far, zone, [:])
        XCTAssertNotNil(scan(nearer, zone, first.distances).threat)
        let first2 = scan(far, SampleData.sectorA, [:])
        XCTAssertNil(scan(nearer, SampleData.sectorA, first2.distances).threat)
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
        // 2.0 (B43): un viaggio salvato come hotel (prima bastava un viaggio qualunque)
        store.trips = [Trip(hotel: hotel, hotelName: hotel.name, arrival: at, departure: at, vehicleId: nil, isHotel: true)]
        XCTAssertTrue(store.isHotel(hotel, at: at))
        // 2.3 (decisione di Ledion del 09/11): il tuo hotel senza la conferma della targa è rosso, con «Chiedi all'hotel…»
        let ask = PlaceCheck(hotel, store: store, at: at).finale
        XCTAssertEqual(ask.stato, .nonEntrare, "il tuo hotel senza conferma: non entrare")
        XCTAssertEqual(ask.hotel, .daChiedere)
        XCTAssertEqual(ask.reasonLine, L("Ask the hotel to register your plate"))
        // Con la conferma segnata (per questo veicolo, per questi giorni, nel Settore A): verde con i giorni
        let c = RuleEngine.rome
        let permit = Permit(kind: .hotelRegistration, cityId: SampleData.florence.id, zoneId: SampleData.sectorA.id, vehicleId: store.vehicle.id,
                            from: c.startOfDay(for: at), to: c.date(bySettingHour: 23, minute: 59, second: 0, of: at)!, status: .confirmed)
        store.permits = [permit]
        let ok = PlaceCheck(hotel, store: store, at: at)
        XCTAssertTrue(ok.answer?.verdict.isYes == true, "il tuo hotel con la conferma: sì")
        XCTAssertEqual(ok.answer?.hotel, .registrata(from: permit.from, to: permit.to))
        // La città di esempio non è mai verde: «Controlla il cartello», senza la riga dell'hotel
        XCTAssertEqual(ok.finale.stato, .controllaCartello)
        XCTAssertNil(ok.finale.hotel)
        // La stessa risposta in una città vera è «Puoi entrare» con i giorni
        let real = RispostaFinale.of(ok.answer!, zone: SampleData.sectorA)
        XCTAssertEqual(real.stato, .entraPure)
        XCTAssertEqual(real.reasonLine, String(format: L("The hotel registered your plate · from %@ to %@"),
                                               RuleEngine.format(permit.from, .dateTime.day().month(.abbreviated)),
                                               RuleEngine.format(permit.to, .dateTime.day().month(.abbreviated))))
    }

    /// 2.3: solo l'hotel confermato diventa verde. Il ticket resta mai verde («A una condizione», anche se segnato), un
    /// permesso dell'hotel in una zona dove l'hotel non registra non vale, e la riga dell'hotel non va mai con un altro stato
    func testOnlyTheConfirmedHotelIsGreen() {
        var withTicket = SampleData.sectorA
        withTicket.ticket = Ticket(price: 6, howTo: "Pay online before you drive in.", url: nil)
        let car = SampleData.rental
        let at = date(2026, 11, 3, 10)
        for hotel in [false, true] {
            let ticket = engine.answer(zone: withTicket, vehicle: car, permits: [], hotelInside: hotel, at: at)
            XCTAssertEqual(RispostaFinale.of(ticket, zone: withTicket).stato, .condizione, "il ticket non è mai verde (resta anche per l'hotel)")
        }
        var noHotel = SampleData.sectorA
        noHotel.hotelCanRegister = false
        let p = Permit(kind: .hotelRegistration, cityId: "firenze", zoneId: noHotel.id, vehicleId: car.id,
                       from: at.addingTimeInterval(-86_400), to: at.addingTimeInterval(86_400), status: .confirmed)
        XCTAssertFalse(p.covers(zone: noHotel, vehicle: car, at: at))
        let red = RispostaFinale.of(engine.answer(zone: noHotel, vehicle: car, permits: [p], hotelInside: true, at: at), zone: noHotel)
        XCTAssertEqual(red.stato, .nonEntrare)
        XCTAssertNil(red.hotel, "dove l'hotel non registra la targa niente riga dell'hotel")
        // Fonte non ufficiale o area pedonale: la conferma non fa mai verde né porta la riga dell'hotel
        var unofficial = SampleData.sectorA
        unofficial.source.official = false
        var yes = Answer(verdict: .yes(reason: "r"), gatesOn: true, nextChange: nil)
        yes.hotel = .registrata(from: at, to: at)
        XCTAssertEqual(RispostaFinale.of(yes, zone: unofficial).stato, .controllaCartello)
        XCTAssertNil(RispostaFinale.of(yes, zone: unofficial).hotel)
        XCTAssertEqual(RispostaFinale.of(yes, zone: SampleData.sectorA, pedestrian: true).stato, .nonEntrare)
        XCTAssertNil(RispostaFinale.of(yes, zone: SampleData.sectorA, pedestrian: true).hotel)
    }
}
