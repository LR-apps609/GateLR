import Foundation
import CoreLocation
import UserNotifications

// Avvisi ad app chiusa: un cerchio attorno ai varchi (e alle telecamere delle aree pedonali) più vicini (CLMonitor, iOS 17).
// Quando entri nel cerchio, GateLR chiede a ThreatEvaluator (lo stesso calcolo di guida e guardiano) se il varco è davanti
// e la risposta per il tuo veicolo; l'avviso lo consegna ThreatAlerts, con le parole della risposta (1.19.3).
@MainActor
final class GateMonitor: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = GateMonitor()

    @Published private(set) var location: CLLocation?
    private let manager = CLLocationManager()
    private var monitor: CLMonitor?
    private weak var store: Store?
    /// iOS segue al massimo 20 regioni per app: si scelgono i varchi più vicini
    private let maxRegions = 20

    private var started = false

    /// «Attiva gli avvisi» nella presentazione: le due richieste di iOS, notifiche e posizione mentre usi l'app (gli avvisi
    /// «Varco attivo tra 250 m» servono a tutte e due). Un «no» va bene: si va avanti, l'app funziona lo stesso e i
    /// permessi si possono dare dopo da Impostazioni. Restituisce se le notifiche sono permesse.
    @discardableResult
    func requestAlertPermissions() async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
        if manager.authorizationStatus == .notDetermined {
            manager.delegate = self
            manager.requestWhenInUseAuthorization()
        }
        return granted
    }

    /// Si parte solo dopo la presentazione del primo avvio (i permessi si chiedono dopo averli spiegati)
    /// e mai nel giro automatico delle foto.
    func startIfReady(store: Store) async {
        guard !started, UserDefaults.standard.bool(forKey: "onboarded"),
              !ProcessInfo.processInfo.arguments.contains("-uitest") else { return }
        started = true
        await start(store: store)
    }

    func start(store: Store) async {
        self.store = store
        manager.delegate = self
        ThreatAlerts.shared.install()
        manager.requestWhenInUseAuthorization()
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 50
        manager.startUpdatingLocation()
        await startAlerts()
    }

    /// Gli avvisi: permessi, cerchi attorno ai varchi più vicini, ascolto degli ingressi
    private func startAlerts() async {
        guard let store, store.alertsOn, monitor == nil else { return }
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        manager.requestAlwaysAuthorization()

        let monitor = await CLMonitor("gates")
        self.monitor = monitor
        await registerNearest(to: manager.location)
        // Ti sposti di qualche chilometro → si passa ai varchi più vicini (anche ad app chiusa)
        manager.startMonitoringSignificantLocationChanges()
        do {
            for try await event in await monitor.events where event.state == .satisfied {
                notify(identifier: event.identifier)
            }
        } catch {}
    }

    /// Dalla scheda Account: avvisi accesi o spenti, nuova distanza
    func settingsChanged() {
        guard started, let store else { return }
        if !store.alertsOn {
            manager.stopMonitoringSignificantLocationChanges()
            Task { if let monitor { for id in await monitor.identifiers { await monitor.remove(id) } }; registeredAt = nil }
        } else if monitor == nil {
            Task { await startAlerts() }
        } else {
            manager.startMonitoringSignificantLocationChanges()
            Task { await registerNearest(to: location ?? manager.location) }
        }
    }

    private var registeredAt: CLLocation?

    /// iOS segue al massimo 20 cerchi: si scelgono i varchi più vicini a dove sei (Area B di Milano da sola ne ha più di 180)
    func registerNearest(to here: CLLocation?) async {
        guard let monitor, let store else { return }
        registeredAt = here
        for id in await monitor.identifiers { await monitor.remove(id) }
        let ordered = [store.city] + store.cities.filter { $0.id != store.city.id }
        // I varchi delle zone e, dalla 1.19.3, le telecamere agli ingressi delle aree pedonali (prima ignorate)
        var points = ordered.flatMap { c in c.zones.flatMap { z in z.gates.map { (z, $0) } } }
        for c in ordered {
            for cam in (c.cameras ?? []) where cam.kind == .pedestrian {
                guard let area = Self.area(for: cam, in: c) else { continue }
                points.append((RouteCheck.pedestrianZone(area, checkedOn: Date()), Gate(id: "cam-" + cam.id, name: cam.name, location: cam.location)))
            }
        }
        for (zone, gate) in Self.nearest(points, to: here, limit: maxRegions) {
            let condition = CLMonitor.CircularGeographicCondition(center: gate.location.cl, radius: store.alertDistance)
            await monitor.add(condition, identifier: "\(zone.id)|\(gate.id)", assuming: .unsatisfied)
        }
    }

    /// L'area pedonale di una telecamera: quella che la contiene o la più vicina entro 80 m
    nonisolated static func area(for cam: Camera, in city: City) -> PedestrianArea? {
        (city.pedestrian ?? []).map { a in (a, a.contains(lat: cam.location.lat, lon: cam.location.lon) ? 0 : ThreatEvaluator.nearestPoint(a.perimeter, to: cam.location).meters) }
            .filter { $0.1 < 80 }.min { $0.1 < $1.1 }?.0
    }

    nonisolated static func nearest(_ gates: [(Zone, Gate)], to here: CLLocation?, limit: Int) -> [(Zone, Gate)] {
        guard let here else { return Array(gates.prefix(limit)) }
        func d(_ g: Gate) -> CLLocationDistance { here.distance(from: CLLocation(latitude: g.location.lat, longitude: g.location.lon)) }
        return Array(gates.sorted { d($0.1) < d($1.1) }.prefix(limit))
    }

    private func moved(to here: CLLocation) {
        location = here
        guard monitor != nil, store?.alertsOn == true else { return }
        if registeredAt.map({ here.distance(from: $0) > 1_500 }) ?? true {
            Task { await registerNearest(to: here) }
        }
    }

    /// Un avviso di prova, dalla scheda Account: com'è fatto, senza aspettare un varco vero
    func sendTest(store: Store) {
        ThreatAlerts.shared.install()
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            let content = UNMutableNotificationContent()
            // Com'è fatto un avviso vero: il titolo con le parole della risposta (1.19.3), il tocco apre i parcheggi fuori
            let zone = store.zone
            let place = zone.gates.first?.location ?? zone.perimeter.first ?? store.city.center
            let cand = ThreatCandidate(zone: zone, cityName: store.city.localizedName)
            content.title = ThreatEvaluator.title(shown: .no(reason: ""), candidate: cand) ?? ""
            content.body = String(format: L("In %@."), DriveSession.distanceText(store.alertDistance)) + " " + (zone.gates.first?.name ?? zone.shortName) + ". " + L("Tap for car parks outside.")
            if let url = ParkLink.url(zoneId: zone.id, name: cand.name, at: place) { content.userInfo = ["url": url.absoluteString] }
            content.title = PlatePrivacy.clean(content.title); content.body = PlatePrivacy.clean(content.body)
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
            try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "test", content: content, trigger: trigger))
        }
    }

    private func notify(identifier: String) {
        guard let store, store.alertsOn else { return }
        // Con il guardiano o la guida accesi avvisano loro, con lo stesso calcolo: niente doppioni
        guard !Guardian.shared.active, !DriveSession.shared.active else { return }
        let parts = identifier.split(separator: "|").map(String.init)
        guard parts.count == 2, let target = Self.target(parts[0], gate: parts[1], in: store.cities) else { return }
        let fix = manager.location.flatMap { $0.timestamp.timeIntervalSinceNow > -120 && $0.horizontalAccuracy < 150 ? $0 : nil }
        guard let t = Self.threat(target.candidate, gate: target.gate, from: fix.map { Coordinate(lat: $0.coordinate.latitude, lon: $0.coordinate.longitude) },
                                  course: fix.flatMap { $0.course >= 0 && ($0.courseAccuracy < 0 || $0.courseAccuracy <= 45) ? $0.course : nil },
                                  alertDistance: store.alertDistance,
                                  answer: { c, d in store.threatAnswer(c, at: ThreatEvaluator.arrival(in: d, speed: fix.map(\.speed)), destination: nil) })
        else { return }
        if ThreatAlerts.shared.post(t), t.candidate.pedestrian == nil {
            store.record(.nearGate, zone: t.zone, gate: target.gate, verdict: t.answer.verdict)
        }
    }

    /// La zona (o l'area pedonale) e il varco di un cerchio («<id zona>|<id varco>»)
    static func target(_ zoneId: String, gate gateId: String, in cities: [City]) -> (candidate: ThreatCandidate, gate: Gate)? {
        for c in cities {
            if let z = c.zones.first(where: { $0.id == zoneId }), let g = z.gates.first(where: { $0.id == gateId }) {
                return (ThreatCandidate(zone: z, cityName: c.localizedName), g)
            }
            if gateId.hasPrefix("cam-"), let cam = c.cameras?.first(where: { "cam-" + $0.id == gateId }), let a = area(for: cam, in: c),
               RouteCheck.pedestrianZoneId(a) == zoneId {
                return (ThreatCandidate(zone: RouteCheck.pedestrianZone(a, checkedOn: Date()), cityName: c.localizedName, pedestrian: a),
                        Gate(id: gateId, name: cam.name, location: cam.location))
            }
        }
        return nil
    }

    /// Il calcolo puro (testabile) dell'avviso ad app chiusa: il varco è davanti (con la direzione di marcia; senza,
    /// prudente: sì) e da fuori della zona? La risposta non è verde? Senza una posizione recente: il varco a «alertDistance»
    nonisolated static func threat(_ c: ThreatCandidate, gate: Gate, from p: Coordinate?, course: Double?, alertDistance: Double,
                                   answer: (ThreatCandidate, Double) -> Answer) -> ZoneThreat? {
        var meters = alertDistance
        if let p {
            // Già dentro la zona: il varco è un'uscita (o sei già entrato), non un ingresso davanti
            if c.zone.contains(lat: p.lat, lon: p.lon) { return nil }
            meters = PathMath.meters(p, gate.location)
            guard ThreatEvaluator.isAhead(from: p, to: gate.location, meters: meters, course: course, approaching: nil) else { return nil }
        }
        let a = answer(c, meters)
        guard ThreatEvaluator.alerts(a.verdict, c) else { return nil }
        return ZoneThreat(candidate: c, meters: meters, answer: a, point: gate.location)
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        Task { @MainActor in self.moved(to: last) }
    }
}
