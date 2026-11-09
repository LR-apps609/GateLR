import XCTest
import CoreLocation

/// 2.2 «Struttura» (tavole P23-Funzioni, P24-Navigazione, I-InAuto, I-Veicolo): le quattro schede e i vecchi indirizzi,
/// «Adesso» per la zona davanti entro 300 m, il veicolo «Non so», niente auto di serie, gli strumenti di sviluppo
final class StrutturaTests: XCTestCase {

    // MARK: Le quattro schede

    func testLinksOpenTheFourTabs() {
        XCTAssertEqual(AppRouter.destination(for: "varco"), .tab(.now))
        XCTAssertEqual(AppRouter.destination(for: "adesso"), .tab(.now))
        XCTAssertEqual(AppRouter.destination(for: "now"), .tab(.now))
        XCTAssertEqual(AppRouter.destination(for: nil), .tab(.now))
        XCTAssertEqual(AppRouter.destination(for: "map"), .tab(.map))
        XCTAssertEqual(AppRouter.destination(for: "trip"), .tab(.trip))
        XCTAssertEqual(AppRouter.destination(for: "guardian"), .tab(.trip))
        XCTAssertEqual(AppRouter.destination(for: "aiuto"), .tab(.help))
        XCTAssertEqual(AppRouter.destination(for: "multe"), .help(.fineGuide))
        XCTAssertEqual(AppRouter.destination(for: "cartello"), .help(.sign))
        XCTAssertEqual(AppRouter.destination(for: "learn"), .help(.learn))
        XCTAssertEqual(AppRouter.destination(for: "garage"), .account(.garage))
        XCTAssertEqual(AppRouter.destination(for: "Settings"), .account(.settings))
        XCTAssertEqual(AppRouter.destination(for: "you"), .account(nil))
        XCTAssertEqual([Tab.now, .map, .trip, .help].map(AppRouter.index(of:)), [0, 1, 2, 3])
    }

    @MainActor func testRouterOpensSheetsAndHelpPages() {
        let router = AppRouter()
        router.open(AccountRoute.garage)
        XCTAssertTrue(router.showAccount)
        XCTAssertEqual(router.accountPath, [.garage])
        XCTAssertEqual(router.tab, .now, "il foglio del veicolo non cambia scheda")
        router.handle(URL(string: "gatelr://multe")!)
        XCTAssertFalse(router.showAccount)
        XCTAssertEqual(router.tab, .help)
        XCTAssertEqual(router.helpPath, [.fineGuide])
        router.handle(URL(string: "gatelr://aiuto")!)
        XCTAssertTrue(router.helpPath.isEmpty)
        router.handle(URL(string: "gatelr://account")!)
        XCTAssertTrue(router.showAccount)
        XCTAssertTrue(router.accountPath.isEmpty)
        router.handle(URL(string: "gatelr://trip")!)
        XCTAssertEqual(router.tab, .trip)
        XCTAssertFalse(router.showAccount)
    }

    // MARK: Adesso: la zona davanti entro 300 m

    /// Una zona quadrata stretta: il bordo sud a 200 m a nord di `here`
    private let here = Coordinate(lat: 43.8000, lon: 11.2500)
    private func zone(southLat: Double = 43.8018, id: String = "test-zone") -> Zone {
        var z = SampleData.sectorA
        z.id = id
        z.perimeter = [Coordinate(lat: southLat, lon: 11.2495), Coordinate(lat: southLat, lon: 11.2505),
                       Coordinate(lat: southLat + 0.0018, lon: 11.2505), Coordinate(lat: southLat + 0.0018, lon: 11.2495)]
        z.gates = [Gate(id: "g", name: "Varco Via Prova", location: Coordinate(lat: southLat, lon: 11.2500))]
        z.prepare()
        return z
    }
    private func candidate(_ z: Zone) -> ThreatCandidate { ThreatCandidate(zone: z, cityName: "Firenze") }

    func testAdessoPicksTheZoneAheadWithin300m() throws {
        let c = candidate(zone())
        let a = try XCTUnwrap(Adesso.ahead(from: here, course: 0, candidates: [c]), "verso nord: davanti, a 200 m")
        XCTAssertEqual(a.meters, 200, accuracy: 15)
        XCTAssertEqual(Adesso.name(a), "Varco Via Prova", "il varco vicino al punto del bordo")
        XCTAssertNil(Adesso.ahead(from: here, course: 180, candidates: [c]), "alle spalle")
        XCTAssertNil(Adesso.ahead(from: here, course: 90, candidates: [c]), "di lato")
        XCTAssertNotNil(Adesso.ahead(from: here, course: nil, candidates: [c]), "fermo: la più vicina, in ogni direzione")
    }

    func testAdessoIgnoresZonesBeyond300mAndTheOneYouAreIn() {
        let far = candidate(zone(southLat: 43.8036))           // 400 m
        XCTAssertNil(Adesso.ahead(from: here, course: 0, candidates: [far]))
        let inside = candidate(zone(southLat: 43.7995))        // ci sei dentro: decide PlaceCheck
        XCTAssertNil(Adesso.ahead(from: here, course: 0, candidates: [inside]))
    }

    func testAdessoPicksTheNearest() throws {
        let near = candidate(zone(id: "near"))
        let farther = candidate(zone(southLat: 43.8025, id: "farther"))
        XCTAssertEqual(try XCTUnwrap(Adesso.ahead(from: here, course: 0, candidates: [farther, near])).candidate.id, "near")
    }

    func testAdessoLocationMustBeRecent() {
        let now = Date()
        let fresh = CLLocationFixture.at(here, age: 60, now: now)
        let old = CLLocationFixture.at(here, age: 11 * 60, now: now)
        XCTAssertNotNil(Adesso.usable(fresh, now: now))
        XCTAssertNil(Adesso.usable(old, now: now), "una posizione di 11 minuti fa non è «dove sei»")
        XCTAssertNil(Adesso.usable(nil, now: now))
    }

    // MARK: Il veicolo «Non so» (decisione 8)

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int) -> Date {
        RuleEngine.rome.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    func testUnknownFuelWhereFuelsAreExemptIsCheckTheSign() {
        var z = SampleData.sectorA
        z.exemptFuels = [.electric]
        let tuesday = date(2026, 11, 10, 10)
        let a = RuleEngine().answer(zone: z, vehicle: .unknown(), permits: [], hotelInside: false, at: tuesday)
        guard case .unsure = a.verdict else { return XCTFail("«Non so» dove le elettriche entrano: \(a.verdict)") }
        XCTAssertEqual(a.doubt, .euroSconosciuto)
        let f = RispostaFinale.of(a, zone: z)
        XCTAssertEqual(f.stato, .controllaCartello)
        XCTAssertEqual(f.motivo, .euroSconosciuto)
        XCTAssertNotEqual(f.color, .verde)
        // Di notte la ZTL è spenta: la risposta di sempre
        let night = RuleEngine().answer(zone: z, vehicle: .unknown(), permits: [], hotelInside: false, at: date(2026, 11, 10, 23))
        XCTAssertTrue(night.verdict.isYes)
        XCTAssertFalse(night.gatesOn)
    }

    func testUnknownEuroInALowEmissionZoneIsNeverGreen() {
        var z = SampleData.sectorA
        z.kind = .green
        z.bans = [EuroBan(fuel: .diesel, maxEuro: 2, since: "2020-01-01")]
        var diesel = Vehicle(name: "", fuel: .diesel, euro: 6)
        diesel.euroUnknown = true
        let a = RuleEngine().answer(zone: z, vehicle: diesel, permits: [], hotelInside: false, at: date(2026, 11, 10, 10))
        XCTAssertEqual(a.doubt, .euroSconosciuto)
        XCTAssertEqual(RispostaFinale.of(a, zone: z).stato, .controllaCartello)
        // L'elettrica senza classe Euro: la classe non conta
        var electric = Vehicle(name: "", fuel: .electric, euro: 6)
        electric.euroUnknown = true
        XCTAssertFalse(electric.specsUnknown)
        XCTAssertFalse(RuleEngine.specsMatter(z, electric))
    }

    func testUnknownSpecsDontMatterInAPlainZTL() {
        // Settore A senza esenzioni né divieti Euro: con o senza «Non so» la stessa risposta
        let z = SampleData.sectorA
        let at = date(2026, 11, 10, 10)
        let known = RuleEngine().answer(zone: z, vehicle: Vehicle(name: "", fuel: .petrol, euro: 6), permits: [], hotelInside: false, at: at)
        let unknown = RuleEngine().answer(zone: z, vehicle: .unknown(), permits: [], hotelInside: false, at: at)
        XCTAssertEqual(known, unknown)
        XCTAssertNil(unknown.doubt)
    }

    func testUnknownVehicleLabelsAndCoding() throws {
        let v = Vehicle.unknown()
        XCTAssertTrue(v.specsUnknown)
        XCTAssertEqual(v.euroText, "Euro ?")
        XCTAssertTrue(v.chipShort.hasSuffix("?"))
        XCTAssertFalse(v.chipLabel.contains("Euro 6"), "mai la classe finta del veicolo «Non so»: \(v.chipLabel)")
        // I garage salvati prima della 2.2 si leggono ancora (i campi nuovi mancano = noti)
        let old = try JSONDecoder().decode(Vehicle.self, from: Data(#"{"id":"\#(UUID().uuidString)","name":"Golf","model":"","fuel":"diesel","euro":5,"plate":"","isRental":false}"#.utf8))
        XCTAssertFalse(old.specsUnknown)
        let again = try JSONDecoder().decode(Vehicle.self, from: JSONEncoder().encode(v))
        XCTAssertEqual(again, v)
    }

    // MARK: La presentazione con il veicolo, niente auto di serie

    func testIntroVehicleChoice() {
        let unknown = IntroVehiclePage.vehicle(type: .car, fuel: nil, euro: nil)
        XCTAssertEqual(unknown.fuelUnknown, true)
        XCTAssertTrue(unknown.specsUnknown)
        let diesel5 = IntroVehiclePage.vehicle(type: .car, fuel: .diesel, euro: 5)
        XCTAssertFalse(diesel5.specsUnknown)
        XCTAssertEqual(diesel5.fuel, .diesel)
        XCTAssertEqual(diesel5.euro, 5)
        let electric = IntroVehiclePage.vehicle(type: .car, fuel: .electric, euro: nil)
        XCTAssertFalse(electric.specsUnknown, "per un'elettrica la classe Euro non serve")
        let moto = IntroVehiclePage.vehicle(type: .motorcycle, fuel: .petrol, euro: nil)
        XCTAssertEqual(moto.kind, .motorcycle)
        XCTAssertTrue(moto.specsUnknown)
        // Il suggerimento usa le parole vere delle risposte
        XCTAssertTrue(IntroVehiclePage.hint.contains(Stato.controllaCartello.word.title))
        XCTAssertTrue(IntroVehiclePage.hint.contains(Stato.entraPure.word.title))
    }

    func testUntouchedSampleGarage() {
        XCTAssertTrue(Store.isUntouchedSample([SampleData.rental]))
        var withPlate = SampleData.rental
        withPlate.plate = "AB123CD"
        XCTAssertFalse(Store.isUntouchedSample([withPlate]), "un'auto con la targa è tua")
        XCTAssertFalse(Store.isUntouchedSample([SampleData.rental, .unknown()]))
        XCTAssertFalse(Store.isUntouchedSample([.unknown()]))
        XCTAssertFalse(Store.isUntouchedSample([]))
    }

    // MARK: In auto e strumenti di sviluppo

    func testInCarTitle() {
        XCTAssertEqual(InCarView.title(guardianOn: false), L("In the car").uppercased())
        XCTAssertTrue(InCarView.title(guardianOn: true).contains(L("Guardian").uppercased()))
    }

    func testInternalNavigatorIsBehindADevFlag() {
        let d = UserDefaults.standard
        let before = d.object(forKey: AppConfig.devNavigatorKey)
        defer { d.set(before, forKey: AppConfig.devNavigatorKey) }
        d.removeObject(forKey: AppConfig.devNavigatorKey)
        XCTAssertFalse(AppConfig.internalNavigator, "spento di serie, anche nelle build di sviluppo")
        d.set(true, forKey: AppConfig.devNavigatorKey)
        XCTAssertEqual(AppConfig.internalNavigator, AppConfig.devTools)
    }
}

/// Una posizione finta con la sua ora
enum CLLocationFixture {
    static func at(_ c: Coordinate, age: TimeInterval, now: Date) -> CLLocation {
        CLLocation(coordinate: CLLocationCoordinate2D(latitude: c.lat, longitude: c.lon), altitude: 0, horizontalAccuracy: 10,
                   verticalAccuracy: 10, timestamp: now.addingTimeInterval(-age))
    }
}
