import Foundation
import MapKit
import AVFoundation
import UIKit
import ActivityKit

/// Conti sul percorso, senza mappe (testabili): distanza da una linea e strada che manca
enum PathMath {
    /// Il punto a «meters» metri da p nella direzione «bearing» (gradi, 0 = nord)
    static func offset(_ p: Coordinate, meters m: Double, bearing: Double) -> Coordinate {
        let r = bearing * .pi / 180
        let dLat = m * cos(r) / 111_320
        let dLon = m * sin(r) / (111_320 * max(0.2, cos(p.lat * .pi / 180)))
        return Coordinate(lat: p.lat + dLat, lon: p.lon + dLon)
    }

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

    /// Il punto del percorso più vicino, cercando solo un po' avanti (si va sempre avanti)
    static func nearestIndex(of p: Coordinate, in path: [Coordinate], from start: Int) -> Int {
        guard !path.isEmpty else { return 0 }
        // Si cerca solo poco più avanti (al massimo 250 m di strada): se il percorso torna vicino a sé
        // stesso (rotonde, vie parallele) non si salta avanti colorando di grigio la strada ancora da fare
        let lo = max(0, min(start, path.count - 1))
        var best = lo, d = meters(p, path[lo]), along = 0.0, i = lo
        while i + 1 < path.count && along < 250 {
            along += meters(path[i], path[i + 1]); i += 1
            let m = meters(p, path[i])
            if m < d { d = m; best = i }
        }
        return best
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

/// La navigazione dentro l'app: istruzioni svolta per svolta con la voce, ricalcolo se esci dal percorso
/// o vai contromano, e avvisi a voce prima di entrare in una ZTL attiva.
/// A ogni posizione si fa poco lavoro: la strada si cerca vicino al punto raggiunto, i metri che mancano
/// sono già sommati, le risposte delle ZTL e le telecamere lungo il percorso si calcolano una volta.
@MainActor
final class DriveSession: NSObject, ObservableObject, CLLocationManagerDelegate, AVSpeechSynthesizerDelegate {
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
    /// Il colore dell'avviso nella Live Activity: «no» rosso, «cond» giallo (condizioni, dubbi, fonte non ufficiale)
    private var warningLevel = "no"
    @Published private(set) var arrived = false
    @Published private(set) var rerouting = false
    @Published private(set) var error: String?
    @Published private(set) var here: Coordinate?
    @Published private(set) var course: Double = 0             // direzione di marcia in gradi
    @Published private(set) var speed: Double = 0              // km/h
    @Published private(set) var progress = 0                   // tratto del percorso già raggiunto
    @Published private(set) var nextZTL: (crossing: RouteCrossing, meters: Double, answer: Answer)?
    @Published var muted = false
    @Published private(set) var routeLength: Double = 0          // metri totali del percorso
    /// Cambia a ogni percorso nuovo (anche dopo un ricalcolo): la mappa ridisegna linee e simboli solo allora
    @Published private(set) var routeVersion = 0
    private(set) var signals: [(point: Coordinate, along: Double)] = []
    /// Il percorso con le distanze già sommate
    private(set) var track = RouteTrack([])
    /// A quanti metri dall'inizio del percorso si entra in ogni ZTL (per id della zona)
    private(set) var entryAlong: [String: Double] = [:]

    private let manager = CLLocationManager()
    // La voce si crea solo quando serve: niente lavoro audio all'avvio dell'app
    private lazy var voice: AVSpeechSynthesizer = {
        let v = AVSpeechSynthesizer()
        v.delegate = self
        return v
    }()
    private weak var store: Store?
    private var secondsPerMeter = 0.08
    private var announced = Set<String>()
    private var activity: Activity<DriveAttributes>?
    private var lastShown: DriveAttributes.ContentState?

    // Percorso: fine di ogni tratto (metri dall'inizio) e lunghezza di ogni tratto
    private var stepEnds: [Double] = []
    private var stepLengths: [Double] = []
    private var along: Double = 0
    // Le telecamere delle corsie bus a meno di 25 m dal percorso, trovate una volta per percorso
    private var busCameras: [Camera] = []
    // Le risposte delle ZTL: si ricalcolano ogni 30 s o se l'ora d'ingresso stimata cambia di due minuti
    private var answerCache: [String: (time: Date, bucket: Int, answer: Answer)] = [:]

    // Ricalcolo
    private var detector = OffRouteDetector()
    private var needsReroute = false
    private var routing = false
    private var lastRerouteAt = Date.distantPast
    private var lastRecalcSpoken = Date.distantPast
    private var backOnRoute = 0
    /// Non più di un ricalcolo ogni tanti secondi (anche per riprovare se la rete non risponde)
    static let rerouteInterval: TimeInterval = 8

    // Movimento fluido
    private var interpolator = PoseInterpolator()

    /// La prossima manovra (l'istruzione del tratto successivo)
    var nextInstruction: String? { index + 1 < steps.count ? steps[index + 1].instruction : nil }
    /// La manovra dopo quella successiva («Poi …»), se è vicina
    var thenInstruction: String? {
        guard index + 2 < steps.count, index + 1 < stepLengths.count, stepLengths[index + 1] < 250 else { return nil }
        return steps[index + 2].instruction
    }
    /// Metri già percorsi lungo il percorso
    var done: Double { max(0, routeLength - remaining) }
    /// I semafori davanti, entro 900 m, e il primo con la sua distanza
    var signalsAhead: [Coordinate] { signals.filter { $0.along > done + 5 && $0.along < done + 900 }.map(\.point) }
    var nextSignal: Double? { signals.first { $0.along > done + 5 }.map { $0.along - done } }
    /// Dove avviene la prossima manovra (per disegnarla sulla strada)
    var nextManeuverPoint: Coordinate? { index + 1 < steps.count ? steps[index + 1].path.first : nil }
    /// Percorso già fatto e da fare (per disegnarli in modo diverso)
    var travelled: [Coordinate] { Array(path.prefix(progress + 1)) }
    var ahead: [Coordinate] { Array(path.dropFirst(progress)) }

    /// Dove disegnare l'auto adesso (tra una posizione GPS e l'altra), «time» = CACurrentMediaTime()
    func displayPose(at time: Double) -> Pose? { interpolator.pose(at: time, track: track) }

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
        error = nil; arrived = false; warning = nil; announced = []
        detector.reset(); needsReroute = false; routing = false; backOnRoute = 0
        lastRerouteAt = .distantPast; lastRecalcSpoken = .distantPast
        interpolator.reset(); here = nil
        manager.requestWhenInUseAuthorization()
        let origin = manager.location?.coordinate ?? RoutePlanner.testOrigin
        guard let r = await calculate(from: origin, to: place, course: nil) else {
            error = origin == nil ? L("Couldn't find your position. Allow location access to plan the drive.")
                                  : L("Couldn't plan the drive right now. Check your connection.")
            return
        }
        apply(r)
        active = true
        UIApplication.shared.isIdleTimerDisabled = true
        VoiceSession.configure()
        SpeechVoice.prepare()
        if Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") != nil {
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
        }
        // Durante la guida: ogni posizione (il filtro lo fa il codice), mai in pausa da sola
        manager.distanceFilter = kCLDistanceFilterNone
        manager.pausesLocationUpdatesAutomatically = false
        manager.startUpdatingLocation()
        if let first = steps.first?.instruction, !first.isEmpty { say(first) }
        startActivity(to: place)
        if let origin { update(Coordinate(lat: origin.latitude, lon: origin.longitude)) }
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.distanceFilter = 5
        if manager.allowsBackgroundLocationUpdates { manager.allowsBackgroundLocationUpdates = false }
        voice.stopSpeaking(at: .immediate)
        VoiceSession.deactivate()
        UIApplication.shared.isIdleTimerDisabled = false
        if let activity {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
        activity = nil; lastShown = nil
        active = false
        steps = []; path = []; crossings = []; warning = nil; destination = nil; nextZTL = nil; progress = 0
        track = RouteTrack([]); entryAlong = [:]; signals = []; busCameras = []; answerCache = [:]
        stepEnds = []; stepLengths = []; along = 0
        interpolator.reset()
        routeVersion += 1
        // Anche lo stato del ricalcolo e dell'arrivo: alla guida dopo non deve restare «Ricalcolo…»
        rerouting = false; needsReroute = false; routing = false; detector.reset(); arrived = false; eta = nil
    }

    /// Il percorso Apple. Con la direzione di marcia (ricalcolo) si chiedono anche le alternative e si
    /// preferisce quella che parte nel verso in cui stai andando, invece di farti fare inversione.
    private func calculate(from origin: CLLocationCoordinate2D?, to place: Place, course: Double?) async -> MKRoute? {
        let request = MKDirections.Request()
        request.source = origin.map { MKMapItem(placemark: MKPlacemark(coordinate: $0)) } ?? .forCurrentLocation()
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: place.location.cl))
        request.transportType = .automobile
        request.requestsAlternateRoutes = course != nil
        guard let routes = try? await MKDirections(request: request).calculate().routes, let first = routes.first else { return nil }
        guard let course else { return first }
        let fastest = first.expectedTravelTime
        return routes.first { r in
            r.expectedTravelTime < fastest * 1.4 && Self.initialBearing(r.polyline.coordinates).map {
                abs(Heading.delta(course, $0)) < 90
            } ?? true
        } ?? first
    }

    /// La direzione dei primi metri del percorso
    private static func initialBearing(_ coords: [CLLocationCoordinate2D]) -> Double? {
        guard let a = coords.first else { return nil }
        let start = Coordinate(lat: a.latitude, lon: a.longitude)
        for c in coords.dropFirst() {
            let p = Coordinate(lat: c.latitude, lon: c.longitude)
            if PathMath.meters(start, p) > 15 { return Heading.bearing(start, p) }
        }
        return nil
    }

    /// Il percorso nuovo: tratti con le istruzioni, distanze già sommate, ZTL, semafori e telecamere lungo la strada
    private func apply(_ r: MKRoute) {
        steps = r.steps.map { s in
            Step(instruction: s.instructions, path: s.polyline.coordinates.map { Coordinate(lat: $0.latitude, lon: $0.longitude) })
        }.filter { !$0.path.isEmpty }
        index = 0
        progress = 0
        along = 0
        path = r.polyline.coordinates.map { Coordinate(lat: $0.latitude, lon: $0.longitude) }
        track = RouteTrack(path)
        routeLength = track.length > 0 ? track.length : r.distance
        // La fine di ogni tratto in metri dall'inizio: le lunghezze dei tratti, riportate alla lunghezza del percorso
        stepLengths = steps.map { RouteTrack($0.path).length }
        let sum = stepLengths.reduce(0, +)
        let scale = sum > 0 ? routeLength / sum : 1
        var acc = 0.0
        stepEnds = stepLengths.map { acc += $0 * scale; return acc }
        signals = TrafficSignals.along(path)
        secondsPerMeter = r.distance > 0 ? r.expectedTravelTime / r.distance : 0.08
        answerCache = [:]
        if let store {
            crossings = RouteCheck.crossings(path: RouteCheck.densify(path), zones: store.cities.flatMap(\.zones),
                                             departure: Date(), travelTime: r.expectedTravelTime) {
                store.answer(at: $1, zone: $0, hotelInside: false)
            }
            busCameras = Self.camerasNear(path, cameras: store.cities.flatMap { $0.cameras ?? [] }.filter { $0.kind == .bus })
        } else {
            crossings = []; busCameras = []
        }
        entryAlong = Dictionary(crossings.compactMap { c in
            c.entry.flatMap { track.locateAnywhere($0) }.map { (c.id, $0.along) }
        }, uniquingKeysWith: { a, _ in a })
        detector.reset()
        interpolator.dropAlong()
        routeVersion += 1
    }

    /// Le telecamere a meno di 25 m dal percorso (prima un rettangolo attorno alla strada, poi la distanza vera)
    static func camerasNear(_ path: [Coordinate], cameras: [Camera]) -> [Camera] {
        guard path.count > 1, !cameras.isEmpty else { return [] }
        let lats = path.map(\.lat), lons = path.map(\.lon)
        let (s, n, w, e) = (lats.min()! - 0.001, lats.max()! + 0.001, lons.min()! - 0.0015, lons.max()! + 0.0015)
        return cameras.filter { c in
            c.location.lat > s && c.location.lat < n && c.location.lon > w && c.location.lon < e
                && PathMath.distance(from: c.location, to: path) < 25
        }
    }

    // MARK: A ogni nuova posizione

    func update(_ p: Coordinate, course c: Double? = nil, speed v: Double? = nil, accuracy acc: Double = 10) {
        let previous = here
        var validCourse: Double?
        if let c, c >= 0 { validCourse = c; course = c } else if let previous, PathMath.meters(previous, p) > 8 {
            course = Heading.bearing(previous, p)
        }
        if let v, v >= 0 { speed = v * 3.6 }
        here = p
        let now = CACurrentMediaTime()
        guard active, let destination, !steps.isEmpty, !track.isEmpty else {
            interpolator.push(Pose(coordinate: p, heading: course, along: nil), speed: max(0, v ?? 0), at: now, track: nil)
            return
        }

        // Dove sei sul percorso: si cerca vicino al tratto raggiunto; se lì non c'è strada (dopo una galleria,
        // o il GPS tornato dopo un po') si guarda tutto il percorso, solo più avanti
        var fix = track.locate(p, near: progress, course: speed > OffRouteDetector.minSpeedKmh ? validCourse : nil)
        if let f = fix, f.distance > OffRouteDetector.threshold(accuracy: acc),
           let g = track.locateAnywhere(p), g.distance <= OffRouteDetector.threshold(accuracy: acc),
           g.along > along - 50, g.along < along + 2_000 {
            fix = g
        }
        guard let fix else { return }
        let onRoad = fix.distance <= OffRouteDetector.threshold(accuracy: acc)
        if onRoad {
            along = fix.along
            if fix.segment != progress { progress = fix.segment }
        }

        // L'auto disegnata: agganciata alla strada se sei sul percorso con un GPS buono, altrimenti dove sei
        let snapped = !needsReroute && fix.distance < 20 && acc <= 30
        let target = snapped ? Pose(coordinate: fix.point, heading: fix.bearing, along: fix.along)
                             : Pose(coordinate: p, heading: course, along: nil)
        interpolator.push(target, speed: max(0, v ?? speed / 3.6), at: now, track: track)

        // Arrivo
        if PathMath.meters(p, destination.location) < 35 {
            if !arrived { arrived = true; say(L("You have arrived.")) }
            refreshActivity()
            return
        }

        // Fuori percorso o contromano → ricalcolo (detto una volta, al massimo uno ogni 8 secondi, riprova se fallisce)
        let verdict = detector.feed(distance: fix.distance, accuracy: acc, course: validCourse, speedKmh: speed, routeBearing: fix.bearing)
        if verdict == .offRoute || verdict == .wrongWay {
            backOnRoute = 0
            if !needsReroute {
                needsReroute = true
                rerouting = true
                if Date().timeIntervalSince(lastRecalcSpoken) > 15 {
                    lastRecalcSpoken = Date()
                    say(L("Recalculating."))
                }
            }
        } else if verdict == .onRoute && needsReroute && !routing {
            // Tornato sulla strada prima del ricalcolo (o mentre si riprovava): si continua col percorso di prima
            backOnRoute += 1
            if backOnRoute >= 3 { needsReroute = false; rerouting = false; backOnRoute = 0 }
        }
        if needsReroute && !routing && Date().timeIntervalSince(lastRerouteAt) >= Self.rerouteInterval {
            reroute(from: p, course: validCourse, speed: speed / 3.6, to: destination)
        }

        // Tratto attuale: si passa al successivo quando la sua fine è vicina
        while index + 1 < steps.count && index < stepEnds.count && stepEnds[index] - along < 15 {
            index += 1
        }
        toNext = max(0, (index < stepEnds.count ? stepEnds[index] : routeLength) - along)
        remaining = track.remaining(fromAlong: along)
        eta = Date().addingTimeInterval(remaining * secondsPerMeter)

        // La prossima manovra a voce: una volta da lontano e una appena prima
        if !needsReroute, let next = nextInstruction, !next.isEmpty {
            if toNext < 500 && toNext > 120 && !announced.contains("far|\(index)") {
                announced.insert("far|\(index)")
                say(String(format: L("In %@, %@"), Self.distanceText(toNext), next))
            } else if toNext <= 60 && !announced.contains("near|\(index)") {
                announced.insert("near|\(index)")
                say(next)
            }
        }

        // ZTL davanti: la prossima sempre visibile (anche lontana o non attiva), avviso a voce verso i 500 metri
        // se a quell'ora non si entra liberamente. Metri lungo la strada, risposta tenuta per 30 s.
        var ahead: [(crossing: RouteCrossing, meters: Double, answer: Answer)] = []
        for c in crossings {
            guard let entryAt = entryAlong[c.id], !c.zone.contains(lat: p.lat, lon: p.lon) else { continue }
            let m = entryAt - along
            guard m > 0 else { continue }
            ahead.append((c, m, cachedAnswer(c, inSeconds: m * secondsPerMeter)))
        }
        ahead.sort { $0.meters < $1.meters }
        nextZTL = ahead.first

        var newWarning: String?
        for a in ahead where a.meters < 800 {
            let zone = a.crossing.zone
            // Un «sì» da fonte non ufficiale non è un via libera (1.19.0): si avvisa, in giallo
            if a.answer.verdict.shown(unofficial: zone.isUnofficial).isYes { continue }
            let short = a.answer.verdict.spokenText(unofficial: zone.isUnofficial)
            newWarning = String(format: L("%@ in %@: %@"), zone.shortName, Self.distanceText(a.meters), short)
            if case .no = a.answer.verdict { warningLevel = "no" } else { warningLevel = "cond" }
            if a.meters < 550 && !announced.contains("ztl|\(zone.id)") {
                announced.insert("ztl|\(zone.id)")
                say(String(format: L("Attention: in %@ you enter %@. %@."), Self.distanceText(a.meters), zone.shortName, short))
            }
            break
        }
        if newWarning != warning { warning = newWarning }

        // Telecamere delle corsie bus vicine (solo quelle lungo il percorso): avviso a voce una volta sola
        for cam in busCameras where !announced.contains("cam|\(cam.id)") && PathMath.meters(p, cam.location) < 150 {
            announced.insert("cam|\(cam.id)")
            say(L("Bus lane camera ahead: stay out of the bus lane."))
        }
        refreshActivity()
    }

    /// La risposta per una ZTL, ricalcolata solo ogni 30 s o se l'ora d'ingresso stimata cambia di due minuti
    private func cachedAnswer(_ c: RouteCrossing, inSeconds s: Double) -> Answer {
        let bucket = Int(s / 120)
        if let e = answerCache[c.id], e.bucket == bucket, Date().timeIntervalSince(e.time) < 30 { return e.answer }
        guard let store else { return c.answer }
        let a = store.answer(at: Date().addingTimeInterval(s), zone: c.zone, hotelInside: false)
        answerCache[c.id] = (Date(), bucket, a)
        return a
    }

    /// Il ricalcolo da dove sei, nel verso in cui vai. Se la rete non risponde si riprova alla posizione dopo
    /// (non prima di 8 secondi), mostrando sempre «Ricalcolo…».
    private func reroute(from p: Coordinate, course: Double?, speed: Double, to destination: Place) {
        routing = true
        lastRerouteAt = Date()
        // In movimento si parte un po' più avanti (dove sarai quando arriva la risposta), nel verso di marcia
        let origin = course.map { c in speed > 2.2 ? PathMath.offset(p, meters: min(25, speed * 1.5), bearing: c) : p } ?? p
        Task {
            let r = await calculate(from: origin.cl, to: destination, course: course)
            routing = false
            // Guida finita (o un'altra destinazione) mentre si ricalcolava: il percorso nuovo non deve tornare sulla mappa
            guard active, self.destination == destination else { return }
            guard needsReroute, let r else { return }        // tornato sulla strada, oppure errore: si riprova
            apply(r)
            announced = announced.filter { $0.hasPrefix("ztl|") || $0.hasPrefix("cam|") }
            needsReroute = false
            rerouting = false
            backOnRoute = 0
        }
    }

    // MARK: Live Activity

    private var state: DriveAttributes.ContentState {
        DriveAttributes.ContentState(
            symbol: DriveView.symbol(for: arrived ? "" : (nextInstruction ?? "")),
            distance: arrived ? "" : DriveSession.distanceText(toNext),
            instruction: arrived ? L("You have arrived") : (nextInstruction ?? destination?.name ?? ""),
            warning: warning, eta: eta, level: warning == nil ? nil : warningLevel)
    }

    /// L'id della Live Activity della guida, se è aperta
    var activityId: String? { activity?.id }

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
        VoiceSession.activate()
        voice.speak(SpeechVoice.utterance(text, rate: 1.02))
    }

    // MARK: Posizione

    /// Finito di parlare: la musica e il navigatore tornano al volume normale
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard !synthesizer.isSpeaking else { return }
        VoiceSession.deactivate()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Le posizioni vecchie (arrivate in ritardo tutte insieme) o troppo imprecise non si usano
        guard let l = locations.last, l.horizontalAccuracy >= 0, l.horizontalAccuracy < 65,
              abs(l.timestamp.timeIntervalSinceNow) < 5 else { return }
        let c = Coordinate(lat: l.coordinate.latitude, lon: l.coordinate.longitude)
        // La direzione conta solo se il GPS la dà abbastanza precisa
        let courseOK = l.course >= 0 && (l.courseAccuracy < 0 || l.courseAccuracy <= 45)
        let course = courseOK ? l.course : -1, speed = l.speed, accuracy = l.horizontalAccuracy
        Task { @MainActor in self.update(c, course: course, speed: speed, accuracy: accuracy) }
    }
}
