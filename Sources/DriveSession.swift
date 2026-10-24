import Foundation
import MapKit
import AVFoundation
import UIKit
import ActivityKit

/// Conti sul percorso, senza mappe (testabili): distanza da una linea e strada che manca
enum PathMath {
    static func meters(_ a: Coordinate, _ b: Coordinate) -> Double {
        let k = cos(a.lat * .pi / 180)
        return hypot((a.lat - b.lat) * 111_000, (a.lon - b.lon) * 111_000 * k)
    }

    /// Il punto più vicino su un segmento, in coordinate locali in metri
    private static func project(_ p: Coordinate, _ a: Coordinate, _ b: Coordinate) -> (distance: Double, t: Double) {
        let k = cos(p.lat * .pi / 180)
        let ax = (a.lon - p.lon) * 111_000 * k, ay = (a.lat - p.lat) * 111_000
        let bx = (b.lon - p.lon) * 111_000 * k, by = (b.lat - p.lat) * 111_000
        let dx = bx - ax, dy = by - ay
        let len2 = dx * dx + dy * dy
        let t = len2 == 0 ? 0 : max(0, min(1, -(ax * dx + ay * dy) / len2))
        return (hypot(ax + t * dx, ay + t * dy), t)
    }

    /// Distanza in metri dal percorso (dal tratto più vicino)
    static func distance(from p: Coordinate, to path: [Coordinate]) -> Double {
        guard path.count > 1 else { return path.first.map { meters(p, $0) } ?? .infinity }
        return zip(path, path.dropFirst()).map { project(p, $0, $1).distance }.min() ?? .infinity
    }

    /// I metri di strada che restano, dal punto del percorso più vicino fino alla fine
    static func remaining(from p: Coordinate, along path: [Coordinate]) -> Double {
        guard path.count > 1 else { return path.first.map { meters(p, $0) } ?? 0 }
        var best = (i: 0, d: Double.infinity, t: 0.0)
        for (i, (a, b)) in zip(path, path.dropFirst()).enumerated() {
            let r = project(p, a, b)
            if r.distance < best.d { best = (i, r.distance, r.t) }
        }
        var total = meters(path[best.i], path[best.i + 1]) * (1 - best.t)
        for j in (best.i + 1)..<(path.count - 1) { total += meters(path[j], path[j + 1]) }
        return total
    }
}

/// La navigazione dentro l'app: istruzioni svolta per svolta con la voce, ricalcolo se esci dal percorso,
/// e avvisi a voce prima di entrare in una ZTL attiva.
@MainActor
final class DriveSession: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = DriveSession()

    struct Step: Equatable {
        var instruction: String
        var path: [Coordinate]
        var end: Coordinate { path.last ?? Coordinate(lat: 0, lon: 0) }
    }

    @Published private(set) var active = false
    @Published private(set) var destination: Place?
    @Published private(set) var steps: [Step] = []
    @Published private(set) var index = 0
    @Published private(set) var toNext: Double = 0            // metri alla prossima manovra
    @Published private(set) var remaining: Double = 0         // metri alla destinazione
    @Published private(set) var eta: Date?
    @Published private(set) var path: [Coordinate] = []
    @Published private(set) var crossings: [RouteCrossing] = []
    @Published private(set) var warning: String?
    @Published private(set) var arrived = false
    @Published private(set) var rerouting = false
    @Published private(set) var error: String?
    @Published private(set) var here: Coordinate?
    @Published var muted = false

    private let manager = CLLocationManager()
    private let voice = AVSpeechSynthesizer()
    private weak var store: Store?
    private var secondsPerMeter = 0.08
    private var announced = Set<String>()
    private var offRouteCount = 0
    private var activity: Activity<DriveAttributes>?
    private var lastShown: DriveAttributes.ContentState?

    /// La prossima manovra (l'istruzione del tratto successivo)
    var nextInstruction: String? { index + 1 < steps.count ? steps[index + 1].instruction : nil }

    override init() {
        super.init()
        manager.delegate = self
        manager.activityType = .automotiveNavigation
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 5
    }

    // MARK: Inizio e fine

    func start(to place: Place, store: Store) async {
        self.store = store
        destination = place
        error = nil; arrived = false; warning = nil; announced = []; offRouteCount = 0
        manager.requestWhenInUseAuthorization()
        let origin = manager.location?.coordinate ?? RoutePlanner.testOrigin
        guard await route(from: origin, to: place) else { return }
        active = true
        UIApplication.shared.isIdleTimerDisabled = true
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .voicePrompt, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
        if Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") != nil {
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
        }
        manager.startUpdatingLocation()
        if let first = steps.first?.instruction, !first.isEmpty { say(first) }
        startActivity(to: place)
        if let origin { update(Coordinate(lat: origin.latitude, lon: origin.longitude)) }
    }

    func stop() {
        manager.stopUpdatingLocation()
        if manager.allowsBackgroundLocationUpdates { manager.allowsBackgroundLocationUpdates = false }
        voice.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        UIApplication.shared.isIdleTimerDisabled = false
        if let activity {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
        activity = nil; lastShown = nil
        active = false
        steps = []; path = []; crossings = []; warning = nil; destination = nil
    }

    /// Il percorso Apple, diviso in tratti con le istruzioni, e il controllo delle ZTL lungo la strada
    private func route(from origin: CLLocationCoordinate2D?, to place: Place) async -> Bool {
        let request = MKDirections.Request()
        request.source = origin.map { MKMapItem(placemark: MKPlacemark(coordinate: $0)) } ?? .forCurrentLocation()
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: place.location.cl))
        request.transportType = .automobile
        guard let r = try? await MKDirections(request: request).calculate().routes.first else {
            error = origin == nil ? L("Couldn't find your position. Allow location access to plan the drive.")
                                  : L("Couldn't plan the drive right now. Check your connection.")
            return false
        }
        steps = r.steps.map { s in
            Step(instruction: s.instructions, path: s.polyline.coordinates.map { Coordinate(lat: $0.latitude, lon: $0.longitude) })
        }.filter { !$0.path.isEmpty }
        index = 0
        path = r.polyline.coordinates.map { Coordinate(lat: $0.latitude, lon: $0.longitude) }
        secondsPerMeter = r.distance > 0 ? r.expectedTravelTime / r.distance : 0.08
        if let store {
            crossings = RouteCheck.crossings(path: RouteCheck.densify(path), zones: store.cities.flatMap(\.zones),
                                             departure: Date(), travelTime: r.expectedTravelTime) {
                store.answer(at: $1, zone: $0, hotelInside: false)
            }
        }
        return true
    }

    // MARK: A ogni nuova posizione

    func update(_ p: Coordinate) {
        here = p
        guard active, let destination, !steps.isEmpty else { return }

        // Arrivo
        if PathMath.meters(p, destination.location) < 35 {
            if !arrived { arrived = true; say(L("You have arrived.")) }
            refreshActivity()
            return
        }

        // Fuori percorso per tre posizioni di fila → ricalcolo
        if PathMath.distance(from: p, to: path) > 70 {
            offRouteCount += 1
            if offRouteCount >= 3 && !rerouting {
                rerouting = true
                say(L("Recalculating."))
                Task {
                    _ = await route(from: p.cl, to: destination)
                    announced = announced.filter { $0.hasPrefix("ztl|") }
                    offRouteCount = 0
                    rerouting = false
                }
            }
        } else {
            offRouteCount = 0
        }

        // Tratto attuale: si passa al successivo quando la sua fine è vicina
        while index + 1 < steps.count && PathMath.remaining(from: p, along: steps[index].path) < 15 {
            index += 1
        }
        toNext = PathMath.remaining(from: p, along: steps[index].path)
        remaining = PathMath.remaining(from: p, along: path)
        eta = Date().addingTimeInterval(remaining * secondsPerMeter)

        // La prossima manovra a voce: una volta da lontano e una appena prima
        if let next = nextInstruction, !next.isEmpty {
            if toNext < 500 && toNext > 120 && !announced.contains("far|\(index)") {
                announced.insert("far|\(index)")
                say(String(format: L("In %@, %@"), Self.distanceText(toNext), next))
            } else if toNext <= 60 && !announced.contains("near|\(index)") {
                announced.insert("near|\(index)")
                say(next)
            }
        }

        // ZTL davanti: avviso a voce verso i 500 metri, se a quell'ora non si entra liberamente
        warning = nil
        for c in crossings {
            guard let entry = c.entry, let store else { continue }
            let d = PathMath.meters(p, entry)
            let answer = store.answer(at: Date().addingTimeInterval(d * secondsPerMeter), zone: c.zone, hotelInside: false)
            if case .yes = answer.verdict { continue }
            if d < 800 && !c.zone.contains(lat: p.lat, lon: p.lon) {
                warning = String(format: L("%@ in %@: %@"), c.zone.shortName, Self.distanceText(d), answer.verdict.short)
                if d < 550 && !announced.contains("ztl|\(c.zone.id)") {
                    announced.insert("ztl|\(c.zone.id)")
                    say(String(format: L("Attention: in %@ you enter %@. %@."), Self.distanceText(d), c.zone.shortName, answer.verdict.short))
                }
                break
            }
        }
        refreshActivity()
    }

    // MARK: Live Activity

    private var state: DriveAttributes.ContentState {
        DriveAttributes.ContentState(
            symbol: DriveView.symbol(for: arrived ? "" : (nextInstruction ?? "")),
            distance: arrived ? "" : DriveSession.distanceText(toNext),
            instruction: arrived ? L("You have arrived") : (nextInstruction ?? destination?.name ?? ""),
            warning: warning, eta: eta)
    }

    private func startActivity(to place: Place) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled, activity == nil else { return }
        let content = ActivityContent(state: state, staleDate: nil)
        activity = try? Activity.request(attributes: DriveAttributes(destination: place.name), content: content, pushType: nil)
        lastShown = state
    }

    /// Si aggiorna solo quando cambia qualcosa che si vede (non a ogni metro)
    private func refreshActivity() {
        guard let activity else { return }
        let s = state
        guard s.symbol != lastShown?.symbol || s.distance != lastShown?.distance || s.warning != lastShown?.warning
                || s.instruction != lastShown?.instruction else { return }
        lastShown = s
        Task { await activity.update(ActivityContent(state: s, staleDate: nil)) }
    }

    static func distanceText(_ m: Double) -> String {
        let rounded = m >= 1_000 ? (m / 100).rounded() * 100 : m >= 100 ? (m / 50).rounded() * 50 : (m / 10).rounded() * 10
        return Measurement(value: rounded, unit: UnitLength.meters).formatted(.measurement(width: .wide, usage: .road))
    }

    private func say(_ text: String) {
        guard !muted, !text.isEmpty else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: Locale.preferredLanguages.first ?? "en-GB")
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 1.02
        voice.speak(u)
    }

    // MARK: Posizione

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let l = locations.last, l.horizontalAccuracy >= 0, l.horizontalAccuracy < 65 else { return }
        let c = Coordinate(lat: l.coordinate.latitude, lon: l.coordinate.longitude)
        Task { @MainActor in self.update(c) }
    }
}
