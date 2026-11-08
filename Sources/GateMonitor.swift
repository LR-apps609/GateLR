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
    /// 1.20.2: la posizione non è ancora stata chiesta (il pulsante «Usa la mia posizione» la chiede al primo tocco)
    @Published private(set) var canAskLocation = false
    /// 1.20.2: gli avvisi sono accesi ma iOS non li ha ancora permessi (Impostazioni → «Consenti gli avvisi»).
    /// 2.0 (B40): pronti solo con la posizione «Sempre»: con «Mentre usi l'app» ad app chiusa CLMonitor non avvisa
    @Published private(set) var alertsNeedPermission = false
    /// 2.0 (B68): la posizione è negata (o vietata): i pulsanti portano alle Impostazioni di iOS, non spariscono
    @Published private(set) var locationDenied = false
    /// 2.0 (B68, B129): le notifiche sono negate in Impostazioni di iOS
    @Published private(set) var notificationsDenied = false
    /// 2.0 (B27): la posizione è «approssimativa» (iOS 14+): può essere spostata di chilometri, mai una risposta da lì
    @Published private(set) var approximate = false

    /// 2.0 (B27): la posizione buona per una risposta «dove sei» (Varco, «La mia posizione», Viaggio, Siri): precisa
    /// ed entro 150 m; nil con la posizione approssimativa o troppo incerta
    var answerLocation: CLLocation? {
        LocationGate.usable(location, accuracy: approximate ? .reducedAccuracy : .fullAccuracy, maxAge: .infinity) ? location : nil
    }

    /// La richiesta di precisione temporanea di iOS («Consenti una volta la posizione esatta»)
    func askPrecise() async {
        guard approximate, !PermissionPolicy.uiTest else { return }
        _ = try? await manager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: LocationGate.purposeKey)
        approximate = manager.accuracyAuthorization == .reducedAccuracy
    }
    private let manager = CLLocationManager()
    private var monitor: CLMonitor?
    private weak var store: Store?
    /// iOS segue al massimo 20 regioni per app: si scelgono i varchi più vicini
    private let maxRegions = 20

    private var started = false
    private var alertsStarting = false

    /// «Attiva gli avvisi» nella presentazione: le richieste di iOS del momento .turnOnAlerts (PermissionPolicy):
    /// notifiche e posizione «Sempre», che serve agli avvisi ad app chiusa (2.0, B40: prima solo «Mentre usi l'app», e gli
    /// avvisi risultavano pronti senza poter arrivare). Un «no» va bene: si va avanti, l'app funziona lo stesso e i
    /// permessi si possono dare dopo da Impostazioni. Restituisce se le notifiche sono permesse.
    @discardableResult
    func requestAlertPermissions() async -> Bool {
        manager.delegate = self
        await PermissionPolicy.request(.turnOnAlerts, manager: manager)
        let granted = await Self.notificationsAllowed()
        await refreshPermissions()
        return granted
    }

    /// Le notifiche si possono mostrare (permesse o provvisorie)
    nonisolated static func notificationsAllowed() async -> Bool {
        let s = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        return s == .authorized || s == .provisional || s == .ephemeral
    }

    /// 2.0 (B40): gli avvisi ad app chiusa sono pronti solo con la posizione «Sempre» e le notifiche permesse (testabile)
    nonisolated static func alertsReady(location: CLAuthorizationStatus, notifications: Bool) -> Bool {
        location == .authorizedAlways && notifications
    }

    /// 2.0 (B68): rilegge i permessi (al ritorno in primo piano: qualcuno li ha cambiati in Impostazioni di iOS). Con le
    /// notifiche o la posizione permesse adesso gli avvisi partono senza riavviare l'app
    func refreshPermissions() async {
        // Nel giro delle foto i permessi non si leggono (le pagine restano come prima, senza pulsanti in più)
        guard !PermissionPolicy.uiTest else { return }
        let status = manager.authorizationStatus
        locationDenied = status == .denied || status == .restricted
        approximate = PermissionPolicy.allowed(status) && manager.accuracyAuthorization == .reducedAccuracy
        canAskLocation = status == .notDetermined
        let notifications = await Self.notificationsAllowed()
        notificationsDenied = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
        guard started, let store, store.alertsOn else { return }
        if monitor == nil {
            // Non si aspetta: startAlerts resta ad ascoltare gli eventi del monitor
            Task { await self.startAlerts(asking: false) }
        } else {
            alertsNeedPermission = !Self.alertsReady(location: status, notifications: notifications)
        }
    }

    /// Si parte solo dopo la presentazione del primo avvio (i permessi si chiedono dopo averli spiegati)
    /// e mai nel giro automatico delle foto.
    func startIfReady(store: Store) async {
        guard !started, UserDefaults.standard.bool(forKey: "onboarded"),
              !ProcessInfo.processInfo.arguments.contains("-uitest") else { return }
        started = true
        await start(store: store)
    }

    /// 2.0 (B42): iOS rilancia GateLR in sottofondo per un evento di CLMonitor (o un cambio di posizione) senza aprire la
    /// finestra: il .task di RootView non parte. Da didFinishLaunching (AppDelegate in Main.swift) si ricrea subito il
    /// monitor «gates», così l'evento arriva e l'avviso parte. Vero se la partenza va fatta (testabile)
    nonisolated static func startsAtLaunch(onboarded: Bool, uitest: Bool) -> Bool {
        onboarded && !uitest
    }

    /// 1.20.2: all'apertura nessuna richiesta (PermissionPolicy, momento .launch): la posizione parte solo se è già
    /// permessa, gli avvisi solo se notifiche e posizione ci sono già. Le richieste arrivano quando usi la cosa che
    /// ne ha bisogno: «Usa la mia posizione», «Attiva gli avvisi», la guida, il guardiano
    func start(store: Store) async {
        self.store = store
        lastAlertsOn = store.alertsOn
        manager.delegate = self
        ThreatAlerts.shared.install()
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 50
        canAskLocation = manager.authorizationStatus == .notDetermined
        if PermissionPolicy.allowed(manager.authorizationStatus) { manager.startUpdatingLocation() }
        await refreshPermissions()
        await startAlerts(asking: false)
    }

    /// «Usa la mia posizione» senza permesso: la richiesta di iOS adesso, la posizione appena arriva il sì
    func askLocation(store: Store) {
        self.store = store
        manager.delegate = self
        guard !PermissionPolicy.uiTest else { return }
        if manager.authorizationStatus == .notDetermined {
            Task { await PermissionPolicy.request(.useMyLocation, manager: manager) }
        } else if PermissionPolicy.allowed(manager.authorizationStatus) {
            manager.startUpdatingLocation()
            // 2.0 (B27): approssimativa → la richiesta di precisione temporanea
            if manager.accuracyAuthorization == .reducedAccuracy { Task { await askPrecise() } }
        } else {
            // 2.0 (B68): negata → le Impostazioni di iOS (prima il tocco non faceva nulla)
            LocationGate.openSettings()
        }
    }

    /// Impostazioni → «Consenti gli avvisi»: notifiche e posizione «Sempre», poi gli avvisi partono
    func askAlertPermissions(store: Store) async {
        self.store = store
        manager.delegate = self
        // 2.0 (B68): iOS chiede una volta sola. Con un «no» già dato (o «Sempre» già chiesto) si va nelle Impostazioni
        if Self.needsSettings(location: manager.authorizationStatus, notificationsDenied: notificationsDenied,
                              askedAlways: UserDefaults.standard.bool(forKey: Self.askedAlwaysKey)) {
            LocationGate.openSettings()
            return
        }
        if manager.authorizationStatus == .authorizedWhenInUse { UserDefaults.standard.set(true, forKey: Self.askedAlwaysKey) }
        if monitor == nil {
            Task { await self.startAlerts(asking: true) }
        } else {
            await PermissionPolicy.request(.turnOnAlerts, manager: manager)
        }
        try? await Task.sleep(for: .seconds(1))
        await refreshPermissions()
    }

    private static let askedAlwaysKey = "gateMonitor.askedAlways"

    /// 2.0 (B68): il pulsante «Consenti gli avvisi» porta alle Impostazioni di iOS quando iOS non chiederebbe più niente
    nonisolated static func needsSettings(location: CLAuthorizationStatus, notificationsDenied: Bool, askedAlways: Bool) -> Bool {
        location == .denied || location == .restricted || notificationsDenied || (location == .authorizedWhenInUse && askedAlways)
    }

    /// Gli avvisi: permessi, cerchi attorno ai varchi più vicini, ascolto degli ingressi. Senza «asking» si parte solo
    /// con i permessi già dati (all'apertura dell'app non compare nessuna richiesta)
    private func startAlerts(asking: Bool) async {
        guard let store, store.alertsOn, monitor == nil, !alertsStarting else { return }
        // Una sola partenza alla volta (all'avvio arrivano insieme start e il cambio di permesso)
        alertsStarting = true
        defer { alertsStarting = false }
        if asking {
            await PermissionPolicy.request(.turnOnAlerts, manager: manager)
        }
        let notifications = await Self.notificationsAllowed()
        // 2.0 (B40): con «Mentre usi l'app» gli avvisi non sono pronti: resta «Consenti gli avvisi» (che chiede «Sempre»).
        // Il monitor parte lo stesso con l'app in uso (l'avviso arriva mentre GateLR è aperta)
        alertsNeedPermission = !Self.alertsReady(location: manager.authorizationStatus, notifications: notifications)
        guard PermissionPolicy.allowed(manager.authorizationStatus), notifications else { return }
        if PermissionPolicy.allowed(manager.authorizationStatus) { manager.startUpdatingLocation() }

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

    /// L'ultimo valore di «Avvisi» visto da settingsChanged
    private var lastAlertsOn: Bool?

    /// Dalla scheda Account: avvisi accesi o spenti, nuova distanza. 2.0 (B130): le richieste di iOS solo quando si
    /// accendono gli avvisi, mai cambiando la distanza
    func settingsChanged() {
        guard started, let store else { return }
        let turnedOn = Self.turnedOn(was: lastAlertsOn, now: store.alertsOn)
        lastAlertsOn = store.alertsOn
        if !store.alertsOn {
            manager.stopMonitoringSignificantLocationChanges()
            Task { if let monitor { for id in await monitor.identifiers { await monitor.remove(id) } }; registeredAt = nil }
        } else if monitor == nil {
            // Gli avvisi accesi a mano: è il momento di chiedere i permessi che servono
            Task { await startAlerts(asking: turnedOn) }
        } else {
            manager.startMonitoringSignificantLocationChanges()
            Task { await registerNearest(to: location ?? manager.location) }
        }
    }

    /// Vero se l'interruttore degli avvisi è appena passato su acceso (prima volta: vero solo se acceso)
    nonisolated static func turnedOn(was: Bool?, now: Bool) -> Bool { now && was != true }

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
        // 1.20.2: alla prima posizione la pagina va sulla città dove sei (una volta, se non ne hai scelta una)
        store?.adoptCity(near: Coordinate(lat: here.coordinate.latitude, lon: here.coordinate.longitude))
        guard monitor != nil, store?.alertsOn == true else { return }
        if registeredAt.map({ here.distance(from: $0) > 1_500 }) ?? true {
            Task { await registerNearest(to: here) }
        }
    }

    /// Un avviso di prova, dalla scheda Account: com'è fatto, senza aspettare un varco vero. 2.0 (B129): restituisce se
    /// le notifiche sono permesse (con le notifiche negate «Inviato» era falso)
    @discardableResult
    func sendTest(store: Store) async -> Bool {
        ThreatAlerts.shared.install()
        do {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            guard await Self.notificationsAllowed() else { notificationsDenied = true; return false }
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
            do {
                try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "test", content: content, trigger: trigger))
            } catch { return false }
            return true
        }
    }

    private func notify(identifier: String) {
        guard let store, store.alertsOn else { return }
        // Con il guardiano o la guida accesi avvisano loro, con lo stesso calcolo: niente doppioni. 2.0 (B74): una guida
        // già arrivata non avvisa più, quindi non blocca gli avvisi ad app chiusa
        guard !Guardian.shared.active, !DriveSession.shared.active || DriveSession.shared.arrived else { return }
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

    /// 1.20.2: la risposta alla richiesta (o un cambio da Impostazioni di iOS): con il sì la posizione parte subito
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.canAskLocation = status == .notDetermined
            await self.refreshPermissions()
            guard PermissionPolicy.allowed(status) else { return }
            self.manager.startUpdatingLocation()
            if self.started, self.monitor == nil { await self.startAlerts(asking: false) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        Task { @MainActor in self.moved(to: last) }
    }
}
