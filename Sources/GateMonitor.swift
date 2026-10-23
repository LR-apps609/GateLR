import Foundation
import CoreLocation
import UserNotifications

// Avvisi ad app chiusa: un cerchio attorno a ogni varco delle città salvate (CLMonitor, iOS 17).
// Quando entri nel cerchio, GateLR calcola la risposta per quel momento e manda la notifica.
@MainActor
final class GateMonitor: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = GateMonitor()

    @Published private(set) var location: CLLocation?
    private let manager = CLLocationManager()
    private var monitor: CLMonitor?
    private weak var store: Store?
    /// iOS segue al massimo 20 regioni per app: si scelgono i varchi più vicini
    private let maxRegions = 20

    func start(store: Store) async {
        self.store = store
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        guard store.alertsOn else { return }
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        manager.requestAlwaysAuthorization()

        let monitor = await CLMonitor("gates")
        self.monitor = monitor
        for id in await monitor.identifiers { await monitor.remove(id) }
        let gates = store.cities.flatMap { c in c.zones.flatMap { z in z.gates.map { (z, $0) } } }
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

    private func notify(identifier: String) {
        guard let store, store.alertsOn else { return }
        let parts = identifier.split(separator: "|").map(String.init)
        guard parts.count == 2,
              let zone = store.cities.flatMap(\.zones).first(where: { $0.id == parts[0] }),
              let gate = zone.gates.first(where: { $0.id == parts[1] }) else { return }
        let answer = store.answer(zone: zone)
        guard answer.gatesOn else { return }      // varco spento: nessun disturbo

        let content = UNMutableNotificationContent()
        content.title = "ZTL gate in \(Int(store.alertDistance)) m · it's ON"
        switch answer.verdict {
        case .yes(let r): content.body = "\(gate.name). \(r)"
        case .no: content.body = "\(gate.name). Don't drive in. Tap for parking outside."
        case .conditional(_, let c): content.body = "\(gate.name). \(c)"
        case .unsure(let r): content.body = "\(gate.name). \(r)"
        }
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil))
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        Task { @MainActor in self.location = last }
    }
}
