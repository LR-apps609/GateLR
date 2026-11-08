import XCTest
import CoreLocation
import UIKit

/// 2.0 «bug iPhone»: le correzioni dei bug confermati dai tester (test20, per-lavoro/nuovo.json). Ogni test dice il bug
final class BugIphoneTests: XCTestCase {
    private let cal = RuleEngine.rome

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    private func city(_ id: String) throws -> City {
        let url = Self.root.appendingPathComponent("Resources/Cities/\(id).json")
        return try CityLoader.decode(Data(contentsOf: url))
    }

    private static var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    /// Il contrasto WCAG tra due colori «0xRRGGBB»
    private func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        func lum(_ h: UInt32) -> Double {
            func f(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
            return 0.2126 * f(Double((h >> 16) & 255) / 255) + 0.7152 * f(Double((h >> 8) & 255) / 255) + 0.0722 * f(Double(h & 255) / 255)
        }
        let (x, y) = (lum(a), lum(b))
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }

    private func hex(_ c: UIColor) -> UInt32 {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return UInt32((r * 255).rounded()) << 16 | UInt32((g * 255).rounded()) << 8 | UInt32((b * 255).rounded())
    }

    private func location(accuracy: Double, age: TimeInterval = 0, now: Date) -> CLLocation {
        CLLocation(coordinate: CLLocationCoordinate2D(latitude: 43.77, longitude: 11.25), altitude: 0,
                   horizontalAccuracy: accuracy, verticalAccuracy: 5, timestamp: now.addingTimeInterval(-age))
    }

    // MARK: B13, B27, B144 · posizione negata o approssimativa

    /// B13: negata e approssimativa non sono «pronte»: il guardiano non parte in silenzio
    func testB13LocationReadiness() {
        XCTAssertEqual(LocationGate.readiness(status: .denied, accuracy: .fullAccuracy), .denied)
        XCTAssertEqual(LocationGate.readiness(status: .restricted, accuracy: .fullAccuracy), .denied)
        XCTAssertEqual(LocationGate.readiness(status: .authorizedWhenInUse, accuracy: .reducedAccuracy), .approximate)
        XCTAssertEqual(LocationGate.readiness(status: .authorizedAlways, accuracy: .reducedAccuracy), .approximate)
        XCTAssertEqual(LocationGate.readiness(status: .authorizedAlways, accuracy: .fullAccuracy), .ready)
        XCTAssertEqual(LocationGate.readiness(status: .notDetermined, accuracy: .fullAccuracy), .notDetermined)
    }

    /// B13: senza posizione precisa la Live Activity e il riquadro dicono «In attesa del GPS», neutri, mai il riposo
    @MainActor
    func testB13WaitingForFixIsNeutral() {
        let s = Guardian.waitingState
        XCTAssertEqual(s.level, "none")
        XCTAssertEqual(s.instruction, L("Waiting for GPS…"))
        XCTAssertNotEqual(s.instruction, L("We don't know the ZTLs of this place"))
        let look = VarcoView.guardianLook(threat: nil, resting: .clear, waiting: true)
        XCTAssertEqual(look.text, L("Waiting for GPS…"))
        XCTAssertNotEqual(look.text, L("No active ZTL ahead"))
    }

    /// B13: il messaggio dice perché e come rimediare (Impostazioni), per la posizione negata e per l'approssimativa
    @MainActor
    func testB13NoticeMessages() {
        let place = Place(name: "Hotel", address: "", location: Coordinate(lat: 43.77, lon: 11.25))
        let denied = GuardianNotice.Pending(problem: .denied, place: place, navigator: .google)
        let approx = GuardianNotice.Pending(problem: .approximate, place: place, navigator: nil)
        XCTAssertTrue(denied.message.contains("GateLR"))
        XCTAssertNotEqual(denied.message, approx.message)
        XCTAssertNotEqual(denied.id, approx.id)
        XCTAssertEqual(LocationGate.purposeKey, "GateLRGates")
    }

    /// B27, B144: una posizione approssimativa, troppo incerta o vecchia non dà una risposta «dove sei»
    func testB27B144UsableLocation() {
        let now = Date()
        XCTAssertTrue(LocationGate.usable(location(accuracy: 30, now: now), accuracy: .fullAccuracy, now: now))
        XCTAssertFalse(LocationGate.usable(location(accuracy: 30, now: now), accuracy: .reducedAccuracy, now: now), "approssimativa")
        XCTAssertFalse(LocationGate.usable(location(accuracy: 3_000, now: now), accuracy: .fullAccuracy, now: now), "a chilometri")
        XCTAssertFalse(LocationGate.usable(location(accuracy: -1, now: now), accuracy: .fullAccuracy, now: now), "non valida")
        XCTAssertFalse(LocationGate.usable(location(accuracy: 20, age: 60, now: now), accuracy: .fullAccuracy,
                                           limit: LocationGate.guardAccuracy, maxAge: 15, now: now), "B144: vecchia")
        XCTAssertFalse(LocationGate.usable(nil, accuracy: .fullAccuracy))
    }

    // MARK: B14 · la cache dei colori

    /// B14: ciclomotore e 2 tempi cambiano la chiave della cache (prima la mappa restava verde)
    func testB14CacheKeyReadsMotoClassAndStroke() {
        var v = Vehicle(name: "Scooter", fuel: .petrol, euro: 1, type: .motorcycle, motoClass: .moped, stroke: 4)
        let four = AccessCache.vehicleKey(v)
        v.stroke = 2
        XCTAssertNotEqual(AccessCache.vehicleKey(v), four)
        let two = AccessCache.vehicleKey(v)
        v.motoClass = .motorcycle
        XCTAssertNotEqual(AccessCache.vehicleKey(v), two)
        v.type = .car
        XCTAssertNotEqual(AccessCache.vehicleKey(v), two)
    }

    // MARK: B15 · la mappa e il passare del tempo

    /// B15: quando una zona si accende o si spegne la «firma» della mappa cambia (la mappa si ridisegna); da un minuto
    /// all'altro senza cambiamenti resta uguale (la mappa non si ridisegna per niente)
    @MainActor
    func testB15MapSignatureFollowsTheClock() async throws {
        let store = Store()
        await store.whenLoaded()
        let saved = (store.cities, store.vehicles, store.activeVehicleId, store.permits)
        defer { store.cities = saved.0; store.vehicles = saved.1; store.activeVehicleId = saved.2; store.permits = saved.3 }
        store.cities = [try city("firenze")]
        store.vehicles = [SampleData.rental]; store.activeVehicleId = SampleData.rental.id; store.permits = []
        let zones = store.cities[0].zones
        var t = cal.startOfDay(for: date(2026, 11, 9, 0))
        var found = false
        for _ in 0..<(7 * 96) {
            let next = t.addingTimeInterval(15 * 60)
            let on = zones.map { store.answer(at: t, zone: $0, hotelInside: false).gatesOn }
            let onNext = zones.map { store.answer(at: next, zone: $0, hotelInside: false).gatesOn }
            if on != onNext {
                XCTAssertNotEqual(MapScreen.signature(store, zones: zones, place: nil, at: t),
                                  MapScreen.signature(store, zones: zones, place: nil, at: next))
                found = true
                break
            }
            t = next
        }
        XCTAssertTrue(found, "in una settimana a Firenze almeno una zona si accende o si spegne")
        let quiet = date(2026, 11, 10, 3, 10)
        XCTAssertEqual(MapScreen.signature(store, zones: zones, place: nil, at: quiet),
                       MapScreen.signature(store, zones: zones, place: nil, at: quiet.addingTimeInterval(60)))
    }

    /// B151: con un'ora scelta la scheda della zona non dice «ora»
    @MainActor
    func testB151GatesLineWithChosenTime() {
        let now = date(2026, 11, 9, 20)
        XCTAssertEqual(MapScreen.gatesLine(on: true, count: 5, when: nil, now: now), String(format: L("%lld gates · on now"), 5))
        let later = MapScreen.gatesLine(on: true, count: 5, when: date(2026, 11, 10, 9), now: now)
        XCTAssertEqual(later, String(format: L("%lld gates · on · %@"), 5, TimeChoice.label(date(2026, 11, 10, 9), now: now)))
        XCTAssertNotEqual(later, String(format: L("%lld gates · on now"), 5))
    }

    // MARK: B16, B43, B71, B72, B141 · hotel e soggiorni

    /// B16: cambiando veicolo il permesso dell'hotel resta al veicolo della richiesta; senza targa mai «confermato».
    /// B72: un permesso per ogni zona che accetta l'hotel
    @MainActor
    func testB16B72HotelPermitStaysWithItsVehicle() async throws {
        let store = Store()
        await store.whenLoaded()
        let saved = (store.cities, store.vehicles, store.activeVehicleId, store.permits, store.stays)
        defer { store.cities = saved.0; store.vehicles = saved.1; store.activeVehicleId = saved.2; store.permits = saved.3; store.stays = saved.4 }
        let firenze = try city("firenze")
        store.cities = [firenze]
        let a = Vehicle(name: "A", fuel: .petrol, euro: 6, plate: "AB123CD"), b = Vehicle(name: "B", fuel: .diesel, euro: 6, plate: "")
        store.vehicles = [a, b]; store.activeVehicleId = a.id; store.permits = []; store.stays = [:]
        let zones = Array(firenze.zones.prefix(2))
        var stay = HotelStay(arrival: date(2026, 11, 20, 15), departure: date(2026, 11, 22, 10), status: .confirmed)
        stay = store.syncHotelPermits(stay, zones: zones)
        XCTAssertEqual(stay.vehicleId, a.id)
        XCTAssertEqual(store.permits.count, 2, "B72: una per zona")
        XCTAssertEqual(Set(store.permits.compactMap(\.zoneId)), Set(zones.map(\.id)))
        XCTAssertTrue(store.permits.allSatisfy { $0.vehicleId == a.id && $0.status == .confirmed })
        // Si passa al veicolo B e si cambia una data: il permesso resta di A
        store.activeVehicleId = b.id
        stay.departure = date(2026, 11, 23, 10)
        stay = store.syncHotelPermits(stay, zones: zones)
        XCTAssertTrue(store.permits.allSatisfy { $0.vehicleId == a.id }, "B16: mai di nascosto all'auto attiva")
        XCTAssertEqual(store.permits.count, 2, "i vecchi permessi si tolgono")
        // B senza targa: confermato non diventa mai un permesso confermato
        var other = HotelStay(arrival: date(2026, 11, 20, 15), departure: date(2026, 11, 22, 10), status: .confirmed, vehicleId: b.id)
        other = store.syncHotelPermits(other, zones: [zones[0]])
        XCTAssertEqual(store.permits.first { other.allPermitIds.contains($0.id) }?.status, .waiting)
    }

    /// B43: un viaggio verso un posto qualunque non lo rende «hotel»; il soggiorno chiesto vale solo vicino alle sue date
    @MainActor
    func testB43HotelOnlyWhenSaidAndNearTheDates() async {
        let store = Store()
        await store.whenLoaded()
        let saved = (store.trips, store.stays)
        defer { store.trips = saved.0; store.stays = saved.1 }
        let place = Place(name: "Ristorante", address: "", location: Coordinate(lat: 43.7731, lon: 11.2560))
        let arrival = date(2026, 11, 20, 15), departure = date(2026, 11, 22, 10)
        store.stays = [:]
        store.trips = [Trip(hotel: place, hotelName: place.name, arrival: arrival, departure: departure)]
        XCTAssertFalse(store.isHotel(place, at: arrival), "un viaggio salvato non è un hotel")
        store.stays = [place.key: HotelStay(arrival: arrival, departure: departure, status: .notAsked)]
        XCTAssertFalse(store.isHotel(place, at: arrival), "il riquadro toccato ma nessuna richiesta all'hotel")
        store.stays = [place.key: HotelStay(arrival: arrival, departure: departure, status: .asked)]
        XCTAssertTrue(store.isHotel(place, at: arrival))
        XCTAssertTrue(store.isHotel(place, at: date(2026, 11, 22, 20)))
        XCTAssertFalse(store.isHotel(place, at: date(2026, 12, 15, 12)), "lontano dalle date del soggiorno")
        XCTAssertFalse(store.isHotel(place, at: date(2026, 11, 1, 12)))
        store.stays = [:]
        store.trips = [Trip(hotel: place, hotelName: place.name, arrival: arrival, departure: departure, isHotel: true)]
        XCTAssertTrue(store.isHotel(place, at: arrival))
    }

    /// B71: cancellando il viaggio spariscono soggiorno e permessi; un permesso tolto dal Garage riporta il soggiorno a
    /// «Non chiesto»
    @MainActor
    func testB71DeletingTripOrPermitCleansTheStay() async throws {
        let store = Store()
        await store.whenLoaded()
        let saved = (store.cities, store.vehicles, store.activeVehicleId, store.permits, store.stays, store.trips)
        defer {
            store.cities = saved.0; store.vehicles = saved.1; store.activeVehicleId = saved.2
            store.permits = saved.3; store.stays = saved.4; store.trips = saved.5
        }
        let firenze = try city("firenze")
        store.cities = [firenze]
        let a = Vehicle(name: "A", fuel: .petrol, euro: 6, plate: "AB123CD")
        store.vehicles = [a]; store.activeVehicleId = a.id; store.permits = []
        let place = Place(name: "Hotel", address: "", location: Coordinate(lat: 43.7731, lon: 11.2560))
        let stay = store.syncHotelPermits(HotelStay(arrival: date(2026, 11, 20, 15), departure: date(2026, 11, 22, 10), status: .confirmed),
                                          zones: [firenze.zones[0]])
        store.stays = [place.key: stay]
        XCTAssertEqual(store.permits.count, 1)
        // Il permesso tolto dal Garage
        PendingDelete.permits(Set(store.permits.map(\.id))).apply(to: store)
        XCTAssertEqual(store.stays[place.key]?.status, .notAsked)
        XCTAssertEqual(store.stay(for: place, arrival: Date()).status, .notAsked)
        // Il viaggio cancellato porta via il soggiorno e i suoi permessi
        let again = store.syncHotelPermits(HotelStay(arrival: date(2026, 11, 20, 15), departure: date(2026, 11, 22, 10), status: .asked),
                                           zones: [firenze.zones[0]])
        store.stays = [place.key: again]
        let trip = Trip(hotel: place, hotelName: "Hotel", arrival: again.arrival, departure: again.departure, isHotel: true)
        store.trips = [trip]
        PendingDelete.trip(trip.id).apply(to: store)
        XCTAssertNil(store.stays[place.key])
        XCTAssertTrue(store.permits.isEmpty)
        XCTAssertFalse(store.isHotel(place, at: again.arrival))
    }

    /// B141: il promemoria del soggiorno è il giorno prima alle 18 ora italiana, anche con il telefono in un altro fuso
    func testB141StayReminderInItalianTime() throws {
        let when = try XCTUnwrap(Store.stayReminderDate(arrival: date(2026, 11, 20, 1, 30)))
        XCTAssertEqual(cal.component(.day, from: when), 19)
        XCTAssertEqual(cal.component(.hour, from: when), 18)
        XCTAssertEqual(cal.component(.minute, from: when), 0)
    }

    // MARK: B29, B30, B134 · parcheggi e percorso

    /// B29: un ciclomotore 2 tempi Euro 1 non parcheggia «fuori dalla ZTL» dentro lo Scudo Verde
    func testB29ClosesReadsMotoBans() throws {
        let scudo = try XCTUnwrap(try city("firenze").zones.first { $0.type == .green && $0.motoBans != nil })
        let moped = Vehicle(name: "Ciao", fuel: .petrol, euro: 1, type: .motorcycle, motoClass: .moped, stroke: 2)
        let modern = Vehicle(name: "Scooter", fuel: .petrol, euro: 5, type: .motorcycle, motoClass: .moped, stroke: 4)
        let at = date(2026, 11, 9, 10)
        XCTAssertNotNil(scudo.motoBan(for: moped, at: at))
        XCTAssertTrue(scudo.closes(to: moped, at: at))
        XCTAssertFalse(scudo.closes(to: modern, at: at))
    }

    /// B30: «Nessuna ZTL sul percorso» in verde solo se tutto il percorso è in città che conosciamo
    func testB30RouteCoverage() throws {
        let cities = [try city("firenze")]
        let inFlorence = [Coordinate(lat: 43.7731, lon: 11.2560), Coordinate(lat: 43.7700, lon: 11.2500)]
        XCTAssertTrue(RoutePlanner.covered(inFlorence, cities: cities))
        let toVenice = inFlorence + [Coordinate(lat: 45.4380, lon: 12.3270)]
        XCTAssertFalse(RoutePlanner.covered(toVenice, cities: cities))
        XCTAssertFalse(RoutePlanner.covered([], cities: cities))
    }

    /// B134: nel controllo del percorso l'hotel vale per la zona della meta, se la meta è il tuo hotel
    @MainActor
    func testB134RouteUsesTheHotel() async throws {
        let store = Store()
        await store.whenLoaded()
        let saved = store.stays
        defer { store.stays = saved }
        let zone = try city("firenze").zones[0]
        let inside = zone.perimeter.reduce(Coordinate(lat: 0, lon: 0)) { Coordinate(lat: $0.lat + $1.lat, lon: $0.lon + $1.lon) }
        let center = Coordinate(lat: inside.lat / Double(zone.perimeter.count), lon: inside.lon / Double(zone.perimeter.count))
        try XCTSkipUnless(zone.contains(lat: center.lat, lon: center.lon), "il centro dei vertici non è dentro la zona")
        let hotel = Place(name: "Hotel", address: "", location: center)
        let at = date(2026, 11, 20, 15)
        store.stays = [:]
        XCTAssertFalse(RoutePlanner.hotelInside(zone, place: hotel, at: at, store: store))
        store.stays = [hotel.key: HotelStay(arrival: at, departure: at.addingTimeInterval(86_400), status: .asked)]
        XCTAssertTrue(RoutePlanner.hotelInside(zone, place: hotel, at: at, store: store))
    }

    // MARK: B34, B73 · Live Activity

    /// B34: ogni aggiornamento ha una data oltre cui la Live Activity si mostra vecchia (3 minuti)
    func testB34StaleDate() {
        let now = Date()
        XCTAssertEqual(DriveAttributes.staleDate(from: now).timeIntervalSince(now), 180, accuracy: 0.001)
    }

    // MARK: B38, B64, B65 · Testo più grande

    /// B38, B64, B65: i caratteri dei titoli crescono al massimo del 30% (prima ~178 punti ad AX5)
    func testB38FontsAreCapped() {
        let ax5 = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)
        let normal = UITraitCollection(preferredContentSizeCategory: .large)
        XCTAssertEqual(Theme.capped(44, traits: ax5), 44 * 1.3, accuracy: 0.01)
        XCTAssertEqual(Theme.capped(44, traits: normal), 44, accuracy: 0.5)
        XCTAssertLessThanOrEqual(Theme.capped(21, traits: ax5), 21 * 1.3 + 0.01)
    }

    // MARK: B40, B42, B68, B130 · avvisi e permessi

    /// B40: gli avvisi ad app chiusa sono pronti solo con «Sempre» e le notifiche
    func testB40AlertsNeedAlways() {
        XCTAssertFalse(GateMonitor.alertsReady(location: .authorizedWhenInUse, notifications: true))
        XCTAssertFalse(GateMonitor.alertsReady(location: .authorizedAlways, notifications: false))
        XCTAssertTrue(GateMonitor.alertsReady(location: .authorizedAlways, notifications: true))
        XCTAssertEqual(PermissionPolicy.ask(at: .turnOnAlerts, uiTest: false).location, .always)
    }

    /// B42: dopo la presentazione gli avvisi ripartono già da didFinishLaunching (rilancio in sottofondo di iOS)
    func testB42StartsAtLaunch() {
        XCTAssertTrue(GateMonitor.startsAtLaunch(onboarded: true, uitest: false))
        XCTAssertFalse(GateMonitor.startsAtLaunch(onboarded: false, uitest: false))
        XCTAssertFalse(GateMonitor.startsAtLaunch(onboarded: true, uitest: true))
    }

    /// B68: con un «no» già dato «Consenti gli avvisi» porta alle Impostazioni di iOS
    func testB68DeniedGoesToSettings() {
        XCTAssertTrue(GateMonitor.needsSettings(location: .denied, notificationsDenied: false, askedAlways: false))
        XCTAssertTrue(GateMonitor.needsSettings(location: .authorizedAlways, notificationsDenied: true, askedAlways: false))
        XCTAssertTrue(GateMonitor.needsSettings(location: .authorizedWhenInUse, notificationsDenied: false, askedAlways: true))
        XCTAssertFalse(GateMonitor.needsSettings(location: .authorizedWhenInUse, notificationsDenied: false, askedAlways: false))
        XCTAssertFalse(GateMonitor.needsSettings(location: .notDetermined, notificationsDenied: false, askedAlways: false))
    }

    /// B130: cambiare la distanza non fa partire le richieste di iOS: solo accendere gli avvisi
    func testB130OnlyTurningOnAsks() {
        XCTAssertFalse(GateMonitor.turnedOn(was: true, now: true))
        XCTAssertTrue(GateMonitor.turnedOn(was: false, now: true))
        XCTAssertFalse(GateMonitor.turnedOn(was: false, now: false))
    }

    // MARK: B41 · Time Sensitive

    /// B41: l'app chiede la capacità «Time Sensitive Notifications» (gli avvisi superano la Full immersione «Guida»)
    func testB41TimeSensitiveEntitlement() throws {
        let file = try String(contentsOf: Self.root.appendingPathComponent("Config/GateLR.entitlements"), encoding: .utf8)
        XCTAssertTrue(file.contains("com.apple.developer.usernotifications.time-sensitive"))
        let project = try String(contentsOf: Self.root.appendingPathComponent("project.yml"), encoding: .utf8)
        XCTAssertTrue(project.contains("com.apple.developer.usernotifications.time-sensitive: true"))
        XCTAssertTrue(project.contains("NSLocationTemporaryUsageDescriptionDictionary"))
    }

    // MARK: B44, B156, B158 · verbale

    /// B44: l'ora si legge anche col punto dopo la data e dopo «ALLE»
    func testB44ViolationTimeFormats() {
        let a = FineReader.parse("COMUNE DI FIRENZE\nVERBALE N. 123\nDATA E ORA: 12.07.2026 23.40\nVIA CAVOUR")
        XCTAssertTrue(a.violationHasTime)
        if let v = a.violation {
            XCTAssertEqual(cal.component(.hour, from: v), 23)
            XCTAssertEqual(cal.component(.minute, from: v), 40)
        } else { XCTFail("data della violazione non letta") }
        let b = FineReader.parse("COMUNE DI FIRENZE\nVIOLAZIONE ACCERTATA IL 12/07/2026 ALLE 23:40 IN VIA CAVOUR")
        XCTAssertTrue(b.violationHasTime)
        if let v = b.violation { XCTAssertEqual(cal.component(.hour, from: v), 23) }
    }

    /// B44: senza ora letta (le 12:00 di ripiego) nessun esito, anche cambiando solo la data; con l'ora scritta a mano sì
    func testB44NoTimeNoVerdict() {
        var n = FineReader.Notice()
        n.violation = date(2026, 7, 12, 12)
        n.violationHasTime = false
        XCTAssertFalse(FineCheck.timeKnown(read: n, chosen: date(2026, 7, 12, 12)))
        XCTAssertFalse(FineCheck.timeKnown(read: n, chosen: date(2026, 7, 13, 12)), "cambiata solo la data")
        XCTAssertTrue(FineCheck.timeKnown(read: n, chosen: date(2026, 7, 12, 23, 40)), "ora scritta a mano")
        n.violationHasTime = true
        XCTAssertTrue(FineCheck.timeKnown(read: n, chosen: date(2026, 7, 12, 12)))
    }

    /// B156: i riferimenti di legge nella lingua dell'app
    func testB156LawReferencesAreLocalized() {
        XCTAssertEqual(FineCheck.references.count, 5)
        XCTAssertEqual(FineCheck.references.first?.0, L("Highway Code, art. 7 (ZTL)"))
    }

    // MARK: B45, B157 · cartello

    /// B45: «lun-ven … sab …» sulla stessa riga: il sabato ha il suo orario
    func testB45TwoDayGroupsOnOneLine() {
        let r = SignReader.parse("ZONA TRAFFICO LIMITATO\nLUN-VEN 7.30-20.00 SAB 7.30-14.00")
        XCTAssertEqual(r.rules.count, 2)
        XCTAssertEqual(r.rules.first?.days, [2, 3, 4, 5, 6])
        XCTAssertEqual(r.rules.last?.days, [7])
        XCTAssertEqual(r.rules.last?.end, 14 * 60)
        // Sabato 14 novembre 2026 alle 10: attiva secondo il cartello
        XCTAssertTrue(SignReader.isActive(r, at: date(2026, 11, 14, 10), calendar: cal))
        XCTAssertFalse(SignReader.isActive(r, at: date(2026, 11, 14, 16), calendar: cal))
    }

    /// B157: le classi Euro non sono un orario
    func testB157EuroClassesAreNotHours() {
        let r = SignReader.parse("VIETATO EURO 0-1-2\n7.30-20.00 FERIALI")
        XCTAssertEqual(r.rules.count, 1)
        XCTAssertEqual(r.rules.first?.start, 7 * 60 + 30)
        XCTAssertFalse(SignReader.timeRanges(in: "euro 0-1-2").contains { $0 == (0, 60) })
        XCTAssertEqual(SignReader.timeRanges(in: "8-13 - 15-19").count, 2, "due fasce restano due fasce")
    }

    // MARK: B67, B79, B124 · contrasti e VoiceOver

    /// B67: testo leggibile (almeno 4,5:1) sull'avviso e sul riquadro del guardiano
    @MainActor
    func testB67BannerContrast() {
        for level in [ThreatLevel.stop, .condition, .check, .clear] {
            let c = ThreatBannerView.colors(level)
            XCTAssertGreaterThanOrEqual(contrast(c.fill, c.ink), 4.5, "\(level)")
        }
        XCTAssertGreaterThanOrEqual(contrast(0x946600, 0xFFFFFF), 4.5)
    }

    /// B79: il rosso dei fondi con il testo bianco resta scuro anche al buio
    func testB79RedFillContrastInDark() {
        let dark = UIColor(Theme.redFill).resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        let light = UIColor(Theme.redFill).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        XCTAssertGreaterThanOrEqual(contrast(hex(dark), 0xFFFFFF), 4.5)
        XCTAssertGreaterThanOrEqual(contrast(hex(light), 0xFFFFFF), 4.5)
    }

    /// B124: con VoiceOver il banner non si chiude da solo
    func testB124BannerStaysWithVoiceOver() {
        XCTAssertFalse(ThreatAlerts.autoHides(uitest: false, voiceOver: true))
        XCTAssertTrue(ThreatAlerts.autoHides(uitest: false, voiceOver: false))
        XCTAssertFalse(ThreatAlerts.autoHides(uitest: true, voiceOver: false))
    }

    // MARK: B74, B143 · fine della guida e del guardiano

    /// B74: la guida finisce da sola poco dopo l'arrivo
    func testB74DriveStopsAfterArrival() {
        XCTAssertGreaterThan(DriveSession.stopAfterArrival, 0)
        XCTAssertLessThanOrEqual(DriveSession.stopAfterArrival, 5 * 60)
    }

    /// B143: fermo da 15 minuti o acceso da 4 ore: il guardiano si ferma (e lo dice)
    func testB143GuardianAutoStop() {
        let now = Date()
        XCTAssertNil(Guardian.autoStop(lastMove: now.addingTimeInterval(-60), startedAt: now.addingTimeInterval(-600), now: now))
        XCTAssertEqual(Guardian.autoStop(lastMove: now.addingTimeInterval(-16 * 60), startedAt: now.addingTimeInterval(-3_600), now: now), "still")
        XCTAssertEqual(Guardian.autoStop(lastMove: now, startedAt: now.addingTimeInterval(-5 * 3_600), now: now), "long")
    }

    // MARK: B78, B155 · diario dei passaggi

    /// B78: data e ora del diario in ora italiana
    @MainActor
    func testB78LogTimeIsItalian() {
        let e = LogEntry(date: date(2026, 7, 12, 23, 40), kind: .entered, zoneId: "z", zoneName: "Settore A", gateName: nil,
                         verdict: L("Don't enter"), plate: "")
        let text = DriveLogView.shareText([e], plates: [])
        XCTAssertTrue(text.contains(RuleEngine.format(e.date, .dateTime.hour().minute())), text)
        XCTAssertTrue(text.contains(L("(Italian time)")))
    }

    /// B155: il colore della riga dalla risposta, non dal tipo
    func testB155LogColourFromVerdict() {
        var e = LogEntry(date: Date(), kind: .entered, zoneId: "z", zoneName: "Z", gateName: nil, verdict: L("On one condition"), plate: "")
        e.level = LogEntry.levelCond
        XCTAssertFalse(e.isNo)
        e.level = LogEntry.levelNo
        XCTAssertTrue(e.isNo)
        let old = LogEntry(date: Date(), kind: .nearGate, zoneId: "z", zoneName: "Z", gateName: nil, verdict: Verdict.no(reason: "").short, plate: "")
        XCTAssertTrue(old.isNo, "righe fino alla 1.20: dal testo")
    }

    // MARK: B131 · ricerca della presentazione

    /// B131: senza città né posizione la ricerca copre tutta l'Italia (Milano e Palermo dentro)
    @MainActor
    func testB131SearchRegionIsItaly() {
        let r = AddressSearch.italy
        for (lat, lon) in [(45.4641, 9.1919), (38.1157, 13.3615), (46.4983, 11.3548)] {
            XCTAssertLessThan(abs(lat - r.center.latitude), r.span.latitudeDelta / 2 + 0.5)
            XCTAssertLessThan(abs(lon - r.center.longitude), r.span.longitudeDelta / 2 + 0.5)
        }
    }

    // MARK: B133 · codice morto

    /// B133: una sola presentazione (Onboarding.swift tolto)
    func testB133OldOnboardingRemoved() {
        XCTAssertFalse(FileManager.default.fileExists(atPath: Self.root.appendingPathComponent("Sources/Onboarding.swift").path))
    }

    // MARK: B136–B139 · viaggi e messaggio all'hotel

    /// B136: l'arrivo nel messaggio ha il giorno del soggiorno e l'ora scelta
    func testB136MessageArrivalTime() {
        let d = MessageLanguage.combine(day: date(2026, 11, 20, 0), time: date(2026, 11, 8, 15))
        XCTAssertEqual(cal.component(.day, from: d), 20)
        XCTAssertEqual(cal.component(.hour, from: d), 15)
    }

    /// B137: salvare due volte lo stesso viaggio non crea doppioni
    @MainActor
    func testB137NoDuplicateTrips() {
        let place = Place(name: "Hotel", address: "", location: Coordinate(lat: 43.77, lon: 11.25))
        let t = Trip(hotel: place, hotelName: "Hotel", arrival: date(2026, 11, 20, 15), departure: date(2026, 11, 22, 10))
        var trips = TripView.saving(t, into: [])
        trips = TripView.saving(Trip(hotel: place, hotelName: "Hotel", arrival: t.arrival, departure: t.departure), into: trips)
        XCTAssertEqual(trips.count, 1)
        trips = TripView.saving(Trip(hotel: place, hotelName: "Hotel", arrival: date(2026, 12, 1, 15), departure: date(2026, 12, 2, 10)), into: trips)
        XCTAssertEqual(trips.count, 2)
    }

    /// B138: un viaggio in corso non è «Passato»
    @MainActor
    func testB138TripInProgress() {
        let now = date(2026, 11, 21, 12)
        let t = Trip(hotel: nil, hotelName: "Hotel", arrival: date(2026, 11, 20, 15), departure: date(2026, 11, 22, 10))
        XCTAssertEqual(TripView.tripTag(t, now: now), L("In progress"))
        XCTAssertEqual(TripView.tripTag(t, now: date(2026, 11, 23, 12)), L("Past"))
        XCTAssertNil(TripView.tripTag(t, now: date(2026, 11, 19, 12)))
    }

    /// B139: lingua iniziale dall'app, segnaposto tradotto, saluto senza nome se non c'è un hotel
    func testB139MessageLanguageAndPlaceholder() {
        XCTAssertEqual(MessageLanguage.from("it"), .it)
        XCTAssertEqual(MessageLanguage.from("de"), .de)
        XCTAssertEqual(MessageLanguage.from("fr"), .en)
        XCTAssertEqual(MessageLanguage.it.platePlaceholder, "[TARGA]")
        XCTAssertEqual(MessageLanguage.de.platePlaceholder, "[KENNZEICHEN]")
        let m = MessageLanguage.it.message(arrival: date(2026, 11, 20, 15), plate: "[TARGA]", hotel: nil)
        XCTAssertTrue(m.hasPrefix("Buongiorno"))
        XCTAssertFalse(m.contains("[PLATE]"))
    }

    // MARK: B159 · tedesco

    /// B159: in tedesco il varco è sempre «Einfahrt»
    func testB159GermanGateIsEinfahrt() throws {
        let de = try String(contentsOf: Self.root.appendingPathComponent("Resources/Localizations/de.lproj/Localizable.strings"), encoding: .utf8)
        XCTAssertFalse(de.contains("Die Tore schalten"))
        XCTAssertFalse(de.contains("Kameras · jetzt"))
        XCTAssertFalse(de.contains("Tor oder Straße"))
        XCTAssertTrue(de.contains("Einfahrt oder Straße"))
    }
}
