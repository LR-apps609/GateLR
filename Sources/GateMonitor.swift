import Foundation
import CoreLocation
import UserNotifications

// Avvisi ad app chiusa: un cerchio attorno a ogni varco delle città salvate (CLMonitor, iOS 17).
// Quando entri nel cerchio, GateLR calcola la risposta per quel momento e manda la notifica.
@MainActor
final class GateMonitor: NSObject, ObservableObject, CLLocationManagerDelegate, UNUserNotificationCenterDelegate {
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
        UNUserNotificationCenter.current().delegate = self
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
        let gates = Self.nearest(ordered.flatMap { c in c.zones.flatMap { z in z.gates.map { (z, $0) } } }, to: here, limit: maxRegions)
        for (zone, gate) in gates {
            let condition = CLMonitor.CircularGeographicCondition(center: gate.location.cl, radius: store.alertDistance)
            await monitor.add(condition, identifier: "\(zone.id)|\(gate.id)", assuming: .unsatisfied)
        }
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
        UNUserNotificationCenter.current().delegate = self
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            let content = UNMutableNotificationContent()
            content.title = String(format: L("ZTL gate in %lld m · ZTL active"), Int(store.alertDistance))
            content.body = (store.zone.gates.first?.name ?? store.zone.shortName) + ". " + L("Don't drive in. Tap for parking outside.")
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
            try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "test", content: content, trigger: trigger))
        }
    }

    /// Ultimo avviso per ogni varco: niente doppioni quando i cerchi vengono rifatti mentre ci sei vicino
    private var lastNotified: [String: Date] = [:]

    private func notify(identifier: String) {
        guard let store, store.alertsOn else { return }
        if let last = lastNotified[identifier], Date().timeIntervalSince(last) < 30 * 60 { return }
        lastNotified[identifier] = Date()
        let parts = identifier.split(separator: "|").map(String.init)
        guard parts.count == 2,
              let zone = store.cities.flatMap(\.zones).first(where: { $0.id == parts[0] }),
              let gate = zone.gates.first(where: { $0.id == parts[1] }) else { return }
        let answer = store.answer(zone: zone)
        guard answer.gatesOn else { return }      // varco spento: nessun disturbo
        if case .yes = answer.verdict {} else { store.record(.nearGate, zone: zone, gate: gate, verdict: answer.verdict) }

        let content = UNMutableNotificationContent()
        content.title = String(format: L("ZTL gate in %lld m · ZTL active"), Int(store.alertDistance))
        switch answer.verdict {
        case .yes(let r): content.body = "\(gate.name). \(r)"
        case .no: content.body = "\(gate.name). " + L("Don't drive in. Tap for parking outside.")
        case .conditional(_, let c): content.body = "\(gate.name). \(c)"
        case .unsure(let r): content.body = "\(gate.name). \(r)"
        }
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil))
    }

    /// Anche con l'app aperta l'avviso si vede in alto
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        Task { @MainActor in self.moved(to: last) }
    }
}
