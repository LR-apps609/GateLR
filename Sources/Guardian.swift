import Foundation
import CoreLocation
import ActivityKit
import AVFoundation
import UserNotifications
import UIKit

/// Modalità Guardiano: guidi con il navigatore che preferisci (Google Maps, Apple Maps, Waze) e GateLR resta
/// in sottofondo. Segue la posizione, mostra la distanza dalla prossima ZTL che a quell'ora non ti fa entrare
/// (Dynamic Island e schermata di blocco) e avvisa con notifica e voce. Si ferma all'arrivo o da fermo.
@MainActor
final class Guardian: NSObject, ObservableObject, CLLocationManagerDelegate, AVSpeechSynthesizerDelegate {
    static let shared = Guardian()

    /// 1.19.3: la minaccia è quella di ThreatEvaluator, la stessa della guida e degli avvisi ad app chiusa
    typealias Threat = ZoneThreat

    @Published private(set) var active = false
    @Published private(set) var destination: Place?
    @Published private(set) var threat: Threat?          // la ZTL più vicina verso cui stai andando, se a quell'ora non entri
    /// Senza minacce davanti: «nessuna zona nota qui» (neutro, fuori dalle città che conosciamo) o «nessuna ZTL attiva
    /// davanti» (in una città che conosciamo). Prima era sempre lo scudo verde con la spunta, anche a Pistoia
    @Published private(set) var resting: ThreatResting = .unknownPlace
    /// Non pubblicata: cambia a ogni posizione e ridisegnerebbe la pagina Varco per niente (la legge solo Siri)
    private(set) var here: Coordinate?

    private let manager = CLLocationManager()
    // La voce si crea solo quando serve: niente lavoro audio all'avvio dell'app
    private lazy var voice: AVSpeechSynthesizer = {
        let v = AVSpeechSynthesizer()
        v.delegate = self
        return v
    }()
    private weak var store: Store?
    private var activity: Activity<DriveAttributes>?
    private var lastShown: DriveAttributes.ContentState?
    private var lastDistances: [String: Double] = [:]
    private var lastMove = Date()
    private var startedAt = Date()
    private var watchdog: Task<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.activityType = .automotiveNavigation
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 15
        manager.pausesLocationUpdatesAutomatically = false
    }

    /// Parte il guardiano e si apre il navigatore scelto verso la meta
    func start(to place: Place, with navigator: Navigator, store: Store) {
        self.store = store
        destination = place
        lastDistances = [:]; threat = nil; resting = .unknownPlace
        lastMove = Date(); startedAt = Date()
        // 1.20.2: posizione «Sempre» e notifiche quando parte il guardiano (PermissionPolicy, mai nel giro delle foto)
        Task { await PermissionPolicy.request(.guardian, manager: manager) }
        if Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") != nil {
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
        }
        manager.startUpdatingLocation()
        VoiceSession.configure()
        SpeechVoice.prepare()
        active = true
        startActivity()
        // Controllo ogni minuto anche senza movimento: con l'auto parcheggiata non arrivano posizioni nuove
        watchdog?.cancel()
        watchdog = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard let self, self.active else { return }
                if Date().timeIntervalSince(self.lastMove) > 15 * 60 || Date().timeIntervalSince(self.startedAt) > 4 * 3600 { self.stop() }
            }
        }
        if let p = manager.location { update(Coordinate(lat: p.coordinate.latitude, lon: p.coordinate.longitude), course: p.course) }
        navigator.open(to: place)
    }

    func stop() {
        manager.stopUpdatingLocation()
        if manager.allowsBackgroundLocationUpdates { manager.allowsBackgroundLocationUpdates = false }
        if let activity { Task { await activity.end(nil, dismissalPolicy: .immediate) } }
        activity = nil; lastShown = nil
        VoiceSession.deactivate()
        watchdog?.cancel(); watchdog = nil
        active = false; threat = nil; destination = nil
    }

    // MARK: A ogni posizione

    func update(_ p: Coordinate, course: Double = -1, speed: Double? = nil) {
        guard active, let store else { return }
        if let here, PathMath.meters(here, p) > 20 { lastMove = Date() }
        here = p

        // Arrivo, fermo da 15 minuti o più di 4 ore: il guardiano si ferma da solo
        if let d = destination, PathMath.meters(p, d.location) < 120 {
            if !Self.demo { notify(title: L("You have arrived"), body: L("GateLR has stopped watching the gates."), id: "arrived") }
            stop(); return
        }
        if Date().timeIntervalSince(lastMove) > 15 * 60 || Date().timeIntervalSince(startedAt) > 4 * 3600 { stop(); return }

        // 1.19.3: lo stesso calcolo della guida e degli avvisi ad app chiusa (ThreatEvaluator): zone E aree pedonali,
        // solo davanti nel verso di marcia, la risposta per il tuo veicolo all'ora d'arrivo (permessi, hotel della meta)
        let destination = self.destination
        let scan = ThreatEvaluator.scan(at: p, course: course >= 0 ? course : nil,
                                        candidates: ThreatEvaluator.candidates(store.cities, near: p),
                                        last: lastDistances, covered: store.covers(p)) { c, d in
            store.threatAnswer(c, at: ThreatEvaluator.arrival(in: d, speed: speed), destination: destination)
        }
        lastDistances = scan.distances
        ThreatAlerts.shared.moved(scan.distances)
        for t in scan.entered {
            store.record(.entered, zone: t.zone, verdict: t.answer.verdict)
            // Il consiglio che evita le multe a catena: non girare dentro cercando l'uscita
            if t.level == .stop, ThreatAlerts.shared.post(t, prefix: "in") {
                say(String(format: L("You're inside %@. Leave by the nearest exit and don't drive around: every gate can mean another fine."), t.candidate.name))
            }
        }
        if scan.threat != threat { threat = scan.threat }      // si pubblica solo se cambia davvero
        if scan.resting != resting { resting = scan.resting }

        // Un avviso per avvicinamento (lo stesso ThreatDeduper della guida e degli avvisi ad app chiusa)
        if let t = scan.threat, t.meters < max(store.alertDistance, 300), ThreatAlerts.shared.post(t) {
            say(String(format: L("Attention: in %@ you enter %@. %@."), DriveSession.distanceText(t.meters), t.candidate.name, t.spoken))
        }
        refreshActivity()
    }

    /// Solo per il giro delle foto (-uitest -uiGuardian lat lon rotta): il guardiano acceso in quel punto, senza GPS,
    /// navigatore, voce né Live Activity, per fotografare lo stato a riposo e l'avviso dentro l'app
    func startDemo(at p: Coordinate, course: Double, store: Store) {
        self.store = store
        destination = Place(name: L("Guardian"), address: "", location: PathMath.offset(p, meters: 5_000, bearing: course))
        lastDistances = [:]; threat = nil; resting = .unknownPlace
        lastMove = Date(); startedAt = Date()
        active = true
        update(p, course: course)
        // Un secondo punto 60 m più avanti: «ti avvicini» anche per il calcolo senza direzione
        update(PathMath.offset(p, meters: 60, bearing: course), course: course)
    }

    private static var demo: Bool { ProcessInfo.processInfo.arguments.contains("-uitest") }

    // MARK: Live Activity

    private var state: DriveAttributes.ContentState { Self.state(threat: threat, resting: resting) }

    /// Quello che mostrano Dynamic Island e schermata di blocco (testabile): la minaccia con le parole della risposta;
    /// senza, «Nessuna ZTL attiva davanti» (grigio, scudo con la spunta) o, fuori dalle città che conosciamo,
    /// «Non conosciamo le ZTL di questo posto» (neutro, scudo vuoto). Mai verde per una cosa che non sappiamo
    nonisolated static func state(threat: Threat?, resting: ThreatResting) -> DriveAttributes.ContentState {
        if let t = threat {
            // Il titolo fisso e, da fonte non ufficiale, la spiegazione: «Controlla il cartello · Probabilmente sì · fonte non ufficiale» (1.20.3)
            let short = t.spoken
            let name = t.candidate.pedestrian != nil ? t.zone.localizedName : t.zone.shortName
            return DriveAttributes.ContentState(symbol: t.candidate.pedestrian != nil ? "figure.walk" : t.zone.type.symbol,
                                                distance: DriveSession.distanceText(t.meters),
                                                instruction: "\(name) · \(short)",
                                                warning: t.meters < 600 ? String(format: L("%@ in %@: %@"), name, DriveSession.distanceText(t.meters), short) : nil,
                                                eta: nil, level: t.level.activity, zone: name)
        }
        switch resting {
        case .clear:
            // 1.20.4: grigio e scudo vuoto (fuori dalla ZTL in una città che conosciamo: mai verde né spunta)
            return DriveAttributes.ContentState(symbol: "shield", distance: "",
                                                instruction: L("No active ZTL ahead"), warning: nil, eta: nil, level: "clear", zone: nil)
        case .unknownPlace:
            return DriveAttributes.ContentState(symbol: "shield", distance: "",
                                                instruction: L("We don't know the ZTLs of this place"), warning: nil, eta: nil, level: "none", zone: nil)
        }
    }

    /// L'id della Live Activity di questo guardiano, se è aperta
    var activityId: String? { activity?.id }

    /// Le Live Activity rimaste da un'esecuzione precedente (app chiusa da iOS o dal multitasking con il guardiano
    /// o la guida accesi): restavano sulla schermata di blocco fino a 8 ore, con dati vecchi e senza modo di toglierle.
    /// Si chiudono tutte tranne quelle del guardiano e della guida di adesso. Vero se ne ha chiusa almeno una.
    @discardableResult
    static func endOrphanActivities() async -> Bool {
        let mine = Set([Guardian.shared.activityId, DriveSession.shared.activityId].compactMap { $0 })
        let orphans = Activity<DriveAttributes>.activities.filter { !mine.contains($0.id) }
        for a in orphans { await a.end(nil, dismissalPolicy: .immediate) }
        return !orphans.isEmpty
    }

    private func startActivity() {
        guard !Self.demo, ActivityAuthorizationInfo().areActivitiesEnabled, activity == nil else { return }
        activity = try? Activity.request(attributes: DriveAttributes(destination: PlatePrivacy.clean(destination?.name ?? "GateLR")),
                                         content: ActivityContent(state: state.withoutPlates(PlatePrivacy.knownPlates), staleDate: nil), pushType: nil)
        lastShown = state
    }

    private func refreshActivity() {
        guard let activity else { return }
        let s = state
        // Distanza arrotondata: si aggiorna ogni 50-100 metri, non a ogni passo
        guard s != lastShown else { return }
        lastShown = s
        let shown = s.withoutPlates(PlatePrivacy.knownPlates)
        Task { await activity.update(ActivityContent(state: shown, staleDate: nil)) }
    }

    // MARK: Voce e notifiche

    private func say(_ text: String) {
        guard !Self.demo else { return }
        VoiceSession.activate()
        voice.speak(SpeechVoice.utterance(text))
    }

    private func notify(title: String, body: String, id: String) {
        let c = UNMutableNotificationContent()
        c.title = PlatePrivacy.clean(title); c.body = PlatePrivacy.clean(body); c.sound = .default   // 1.19.4: mai una targa
        c.interruptionLevel = .timeSensitive
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "guardian|\(id)", content: c, trigger: nil))
    }

    /// Finito di parlare: la musica e il navigatore tornano al volume normale
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard !synthesizer.isSpeaking else { return }
        VoiceSession.deactivate()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let l = locations.last, l.horizontalAccuracy >= 0, l.horizontalAccuracy < 80 else { return }
        let c = Coordinate(lat: l.coordinate.latitude, lon: l.coordinate.longitude)
        // La direzione conta solo se il GPS la dà abbastanza precisa (come nella guida)
        let course = l.course >= 0 && (l.courseAccuracy < 0 || l.courseAccuracy <= 45) ? l.course : -1
        let speed = l.speed >= 0 ? l.speed : nil
        Task { @MainActor in self.update(c, course: course, speed: speed) }
    }
}
