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
        manager.startUpdatingLocation()
        guard store.alertsOn else { return }
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        manager.requestAlwaysAuthorization()

        let monitor = await CLMonitor("gates")
        self.monitor = monitor
        for id in await monitor.identifiers { await monitor.remove(id) }
        let ordered = [store.city] + store.cities.filter { $0.id != store.city.id }
        var gates = ordered.flatMap { c in c.zones.flatMap { z in z.gates.map { (z, $0) } } }
        // Se sappiamo dove sei, i varchi più vicini a te (Area B di Milano da sola ne ha più di 180)
        if let here = manager.location {
            gates.sort { here.distance(from: CLLocation(latitude: $0.1.location.lat, longitude: $0.1.location.lon))
                       < here.distance(from: CLLocation(latitude: $1.1.location.lat, longitude: $1.1.location.lon)) }
        }
        for (zone, gate) in gates.prefix(maxRegions) {
            let condition = CLMonitor.CircularGeographicCondition(center: gate.location.cl, radius: store.alertDistance)
            await monitor.add(condition, identifier: "\(zone.id)|\(gate.id)", assuming: .unsatisfied)
        }
        do {
            for try await event in await monitor.events where event.state == .satisfied {
                notify(identifier: event.identifier)
            }
        } catch {}
    }

    /// Un avviso di prova, dalla scheda Account: com'è fatto, senza aspettare un varco vero
    func sendTest(store: Store) {
        UNUserNotificationCenter.current().delegate = self
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            let content = UNMutableNotificationContent()
            content.title = String(format: L("ZTL gate in %lld m · it's ON"), Int(store.alertDistance))
            content.body = (store.zone.gates.first?.name ?? store.zone.shortName) + ". " + L("Don't drive in. Tap for parking outside.")
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
            try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "test", content: content, trigger: trigger))
        }
    }

    private func notify(identifier: String) {
        guard let store, store.alertsOn else { return }
        let parts = identifier.split(separator: "|").map(String.init)
        guard parts.count == 2,
              let zone = store.cities.flatMap(\.zones).first(where: { $0.id == parts[0] }),
              let gate = zone.gates.first(where: { $0.id == parts[1] }) else { return }
        let answer = store.answer(zone: zone)
        guard answer.gatesOn else { return }      // varco spento: nessun disturbo

        let content = UNMutableNotificationContent()
        content.title = String(format: L("ZTL gate in %lld m · it's ON"), Int(store.alertDistance))
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
        Task { @MainActor in self.location = last }
    }
}
