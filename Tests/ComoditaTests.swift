import XCTest
import Combine
import CoreLocation

/// 1.20.2 «Comodità»: Invio nella ricerca, «Riprova», permessi al momento giusto, conferma prima di cancellare,
/// la città dalla posizione, lo Store diviso, la mappa di riserva dopo 5 s e un solo raggio per i parcheggi di Apple
final class ComoditaTests: XCTestCase {

    private func city(_ id: String) throws -> City {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/Cities/\(id).json")
        return try CityLoader.decode(Data(contentsOf: url))
    }

    // MARK: Ricerca

    /// Invio con un suggerimento: il primo, come un tocco
    func testEnterPicksFirstSuggestion() {
        XCTAssertEqual(SearchSubmit.action(query: "Palazzo Vecchio", results: 3, failed: false), .pickFirst)
    }

    /// Invio dopo una ricerca senza risposta: si riprova (e si sceglie il primo quando arriva)
    func testEnterAfterFailureRetries() {
        XCTAssertEqual(SearchSubmit.action(query: "Palazzo Vecchio", results: 0, failed: true), .retry)
    }

    /// Invio mentre i suggerimenti arrivano: si aspetta il primo; con meno di due lettere niente
    func testEnterWaitsOrDoesNothing() {
        XCTAssertEqual(SearchSubmit.action(query: "Pa", results: 0, failed: false), .wait)
        XCTAssertEqual(SearchSubmit.action(query: "P", results: 5, failed: false), .nothing)
        XCTAssertEqual(SearchSubmit.action(query: "   ", results: 0, failed: true), .nothing)
    }

    // MARK: Permessi

    /// All'apertura dell'app nessuna richiesta, e nel giro delle foto mai (la richiesta copriva la foto della guida)
    func testNoPermissionAtLaunchOrInTour() {
        XCTAssertEqual(PermissionPolicy.ask(at: .launch, uiTest: false), .nothing)
        for m in PermissionMoment.allCases {
            XCTAssertEqual(PermissionPolicy.ask(at: m, uiTest: true), .nothing, "\(m) nel giro delle foto")
        }
    }

    /// Ogni cosa chiede solo quello che usa
    func testPermissionWhenTheFeatureIsUsed() {
        XCTAssertEqual(PermissionPolicy.ask(at: .useMyLocation, uiTest: false), PermissionAsk(location: .whenInUse, notifications: false))
        XCTAssertEqual(PermissionPolicy.ask(at: .drive, uiTest: false), PermissionAsk(location: .whenInUse, notifications: false))
        XCTAssertEqual(PermissionPolicy.ask(at: .guardian, uiTest: false), PermissionAsk(location: .always, notifications: true))
        XCTAssertEqual(PermissionPolicy.ask(at: .turnOnAlerts, uiTest: false), PermissionAsk(location: .always, notifications: true))
        XCTAssertEqual(PermissionPolicy.ask(at: .reminder, uiTest: false), PermissionAsk(location: nil, notifications: true))
        XCTAssertTrue(PermissionPolicy.allowed(.authorizedWhenInUse))
        XCTAssertFalse(PermissionPolicy.allowed(.notDetermined))
        XCTAssertFalse(PermissionPolicy.allowed(.denied))
    }

    // MARK: Conferma prima di cancellare

    /// Il dialogo dice cosa si cancella; con il veicolo spariscono i suoi permessi, e si cancella solo con apply
    @MainActor
    func testDeleteVehicleOnlyAfterConfirmWithItsPermits() async {
        let store = Store()
        await store.whenLoaded()
        let saved = (store.vehicles, store.activeVehicleId, store.permits)
        defer { store.vehicles = saved.0; store.activeVehicleId = saved.1; store.permits = saved.2 }
        let a = Vehicle(name: "A", fuel: .petrol, euro: 6), b = Vehicle(name: "B", fuel: .diesel, euro: 4)
        store.vehicles = [a, b]; store.activeVehicleId = a.id
        let pa = Permit(kind: .resident, cityId: "firenze", zoneId: "firenze-a", vehicleId: a.id, from: Date(), to: Date(), status: .confirmed)
        let pb = Permit(kind: .resident, cityId: "firenze", zoneId: "firenze-a", vehicleId: b.id, from: Date(), to: Date(), status: .confirmed)
        store.permits = [pa, pb]

        let pending = PendingDelete.vehicles([a.id])
        XCTAssertEqual(pending.title, L("Delete this vehicle?"))
        XCTAssertEqual(store.vehicles.count, 2, "prima della conferma non si cancella niente")
        pending.apply(to: store)
        XCTAssertEqual(store.vehicles.map(\.id), [b.id])
        XCTAssertEqual(store.permits.map(\.id), [pb.id])
        XCTAssertEqual(store.activeVehicleId, b.id, "il veicolo in uso cancellato: si passa al primo")
    }

    @MainActor
    func testDeletePermitTripAndLogRow() async {
        let store = Store()
        await store.whenLoaded()
        let saved = (store.permits, store.trips, store.log)
        defer { store.permits = saved.0; store.trips = saved.1; store.log = saved.2 }
        let p = Permit(kind: .resident, cityId: "firenze", zoneId: "firenze-a", vehicleId: UUID(), from: Date(), to: Date(), status: .confirmed)
        store.permits = [p]
        PendingDelete.permits([p.id]).apply(to: store)
        XCTAssertTrue(store.permits.isEmpty)

        let t = Trip(hotel: nil, hotelName: "Hotel", arrival: Date(), departure: Date())
        store.trips = [t]
        XCTAssertEqual(PendingDelete.trip(t.id).title, L("Delete this trip?"))
        PendingDelete.trip(t.id).apply(to: store)
        XCTAssertTrue(store.trips.isEmpty)

        let e1 = LogEntry(date: Date(), kind: .nearGate, zoneId: "z", zoneName: "Z", gateName: nil, verdict: "", plate: "")
        let e2 = LogEntry(date: Date(), kind: .entered, zoneId: "z", zoneName: "Z", gateName: nil, verdict: "", plate: "")
        store.log = [e1, e2]
        XCTAssertEqual(PendingDelete.logEntries([e1.id, e2.id]).title, String(format: L("Delete %lld rows of the log?"), 2))
        PendingDelete.logEntries([e1.id]).apply(to: store)
        XCTAssertEqual(store.log.map(\.id), [e2.id])
    }

    // MARK: Lo Store diviso

    /// Una riga nuova del diario non ridisegna le pagine che osservano lo Store (Varco, Mappa, Viaggio): cambia solo
    /// il diario. Il diario si salva come prima
    @MainActor
    func testLogWritesDoNotRedrawStoreObservers() async {
        let store = Store()
        await store.whenLoaded()
        let saved = store.log
        defer { store.log = saved }
        var storeChanges = 0, logChanges = 0
        let a = store.objectWillChange.sink { _ in storeChanges += 1 }
        let b = store.logBook.objectWillChange.sink { _ in logChanges += 1 }
        store.log = [LogEntry(date: Date(), kind: .nearGate, zoneId: "z", zoneName: "Z", gateName: nil, verdict: "", plate: "")]
        XCTAssertEqual(storeChanges, 0)
        XCTAssertEqual(logChanges, 1)
        XCTAssertEqual(Store().log.count, 1, "il diario si salva con il garage")
        a.cancel(); b.cancel()
    }

    // MARK: La città dalla posizione

    /// Dentro una città: quella e la zona che ti contiene; vicino (entro 15 km): la più vicina; lontano: nessuna
    func testCityFromPosition() throws {
        let cities = [try city("firenze"), try city("bologna"), try city("milano")]
        XCTAssertEqual(CityFromPosition.pick(Coordinate(lat: 44.4939, lon: 11.3426), cities: cities)?.city.id, "bologna")   // Piazza Maggiore
        XCTAssertEqual(CityFromPosition.pick(Coordinate(lat: 45.4641, lon: 9.1919), cities: cities)?.city.id, "milano")     // Duomo
        // Aeroporto di Bologna (circa 6 km dal centro): Bologna
        XCTAssertEqual(CityFromPosition.pick(Coordinate(lat: 44.5354, lon: 11.2887), cities: cities)?.city.id, "bologna")
        // Roma, lontano da queste tre città: nessuna, resta quella di prima
        XCTAssertNil(CityFromPosition.pick(Coordinate(lat: 41.9028, lon: 12.4964), cities: cities))
    }

    /// Una volta sola, e mai sopra un posto o una città scelti a mano
    @MainActor
    func testAdoptCityOnlyOnceAndNotOverChoices() async throws {
        let store = Store()
        await store.whenLoaded()
        store.cities = [try city("firenze"), try city("bologna")]
        store.cityId = "firenze"
        XCTAssertTrue(store.adoptCity(near: Coordinate(lat: 44.4939, lon: 11.3426)))
        XCTAssertEqual(store.cityId, "bologna")
        XCTAssertFalse(store.adoptCity(near: Coordinate(lat: 43.7696, lon: 11.2558)), "solo alla prima posizione")
        XCTAssertEqual(store.cityId, "bologna")

        let other = Store()
        await other.whenLoaded()
        other.cities = store.cities
        other.chooseCity("firenze")
        XCTAssertFalse(other.adoptCity(near: Coordinate(lat: 44.4939, lon: 11.3426)), "città scelta a mano")
        XCTAssertEqual(other.cityId, "firenze")
    }

    // MARK: Mappa di riserva e parcheggi

    func testMapboxFallbackAfterFiveSeconds() {
        XCTAssertEqual(MapboxFallback.seconds, 5)
    }

    /// Un solo lato (4 km) per la ricerca dei parcheggi di Apple, nel percorso di Viaggio e in «Parcheggia fuori»
    func testAppleParkingRadiusIsOneValue() {
        XCTAssertEqual(ParkingFallback.span, 4_000)
        let r = ParkingFallback.region(around: Coordinate(lat: 43.7696, lon: 11.2558))
        XCTAssertEqual(r.span.latitudeDelta * 111_000, 4_000, accuracy: 60)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        for f in ["Sources/ParkOutside.swift", "Sources/RoutePlanner.swift"] {
            let text = (try? String(contentsOf: root.appendingPathComponent(f), encoding: .utf8)) ?? ""
            XCTAssertTrue(text.contains("ParkingFallback.region"), f)
            XCTAssertFalse(text.contains("latitudinalMeters: 3_000"), f)
        }
    }

    /// La ricerca dei parcheggi che non risponde dice «non risponde» (con «Riprova»), non «nessun parcheggio»
    @MainActor
    func testParkingFailedIsNotEmpty() {
        XCTAssertEqual(ParkOutsideFinder.phase(options: 0, appleFailed: true), .failed)
        XCTAssertEqual(ParkOutsideFinder.phase(options: 0, appleFailed: false), .empty)
        XCTAssertEqual(ParkOutsideFinder.phase(options: 2, appleFailed: true), .done)
    }
}
