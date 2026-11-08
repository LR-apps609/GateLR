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
    /// Non pubblicata: cambia a ogni posizione e ridisegnerebbe la pagina Varco per niente (la legge solo Siri).
    /// 2.0 (B75): si azzera quando il guardiano si ferma, così Siri non risponde per l'ultimo punto del viaggio
    private(set) var here: Coordinate?
    /// 2.0 (B13): acceso ma ancora senza una posizione precisa. Finché è vero la Live Activity e il riquadro dicono
    /// «In attesa del GPS» (mai «Nessuna ZTL attiva davanti» né «Non conosciamo le ZTL di questo posto»)
    @Published private(set) var waitingForFix = true

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
    /// 2.0 (B143): il movimento si misura da un punto fermo (prima dal passo precedente: 15 m alla volta non contavano mai)
    private var moveAnchor: Coordinate?
    private var startedAt = Date()
    /// 2.0 (B34): l'ultima posizione buona; la Live Activity si rinnova solo finché arrivano posizioni
    private var lastFixAt = Date.distantPast
    private var watchdog: Task<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.activityType = .automotiveNavigation
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 15
        manager.pausesLocationUpdatesAutomatically = false
    }

    /// Parte il guardiano e si apre il navigatore scelto verso la meta. 2.0 (B13): con la posizione negata o
    /// «approssimativa» il guardiano non parte in silenzio: prima la richiesta di precisione temporanea di iOS, poi,
    /// se resta approssimativa o negata, il messaggio «Serve la posizione precisa per i varchi» (GuardianNotice) con il
    /// link alle Impostazioni. Mai uno stato che sembri una protezione attiva
    func start(to place: Place, with navigator: Navigator, store: Store) {
        // 2.0 (B76): un solo viaggio attivo: la guida dentro l'app si ferma (due Live Activity e due voci)
        if DriveSession.shared.active { DriveSession.shared.stop() }
        if active { stop() }
        switch LocationGate.readiness(status: manager.authorizationStatus, accuracy: manager.accuracyAuthorization) {
        case .denied:
            GuardianNotice.shared.show(.denied, place: place, navigator: navigator)
        case .approximate:
            Task {
                _ = try? await manager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: LocationGate.purposeKey)
                if manager.accuracyAuthorization == .fullAccuracy {
                    begin(to: place, with: navigator, store: store)
                } else {
                    GuardianNotice.shared.show(.approximate, place: place, navigator: navigator)
                }
            }
        case .ready, .notDetermined:
            begin(to: place, with: navigator, store: store)
        }
    }

    private func begin(to place: Place, with navigator: Navigator, store: Store) {
        self.store = store
        destination = place
        lastDistances = [:]; threat = nil; resting = .unknownPlace; waitingForFix = true; here = nil
        lastMove = Date(); startedAt = Date(); moveAnchor = nil; lastFixAt = .distantPast
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
                if let why = Self.autoStop(lastMove: self.lastMove, startedAt: self.startedAt, now: Date()) { self.stopped(why); return }
                // 2.0 (B34): la Live Activity resta «fresca» solo finché arrivano posizioni: senza GPS (o con l'app
                // chiusa da iOS) dopo tre minuti si mostra vecchia, mai verde congelata
                if Date().timeIntervalSince(self.lastFixAt) < 120 { self.refreshActivity(force: true) }
            }
        }
        // 2.0 (B144): la posizione già nota solo se recente e precisa (una vecchia poteva dire subito «Sei arrivato»)
        if let p = manager.location, LocationGate.usable(p, accuracy: manager.accuracyAuthorization, limit: LocationGate.guardAccuracy, maxAge: 15) {
            update(Coordinate(lat: p.coordinate.latitude, lon: p.coordinate.longitude), course: p.course)
        }
        navigator.open(to: place)
    }

    /// Perché il guardiano si ferma da solo: fermo da 15 minuti o acceso da più di 4 ore (testabile)
    nonisolated static func autoStop(lastMove: Date, startedAt: Date, now: Date) -> String? {
        if now.timeIntervalSince(lastMove) > 15 * 60 { return "still" }
        if now.timeIntervalSince(startedAt) > 4 * 3600 { return "long" }
        return nil
    }

    /// 2.0 (B143): uno stop automatico si dice (prima la Live Activity spariva in silenzio)
    private func stopped(_ why: String) {
        if !Self.demo { notify(title: L("Guardian stopped."), body: L("GateLR has stopped watching the gates."), id: "stopped") }
        stop()
    }

    func stop() {
        manager.stopUpdatingLocation()
        if manager.allowsBackgroundLocationUpdates { manager.allowsBackgroundLocationUpdates = false }
        if let activity { Task { await activity.end(nil, dismissalPolicy: .immediate) } }
        activity = nil; lastShown = nil
        // 2.0 (B149): «Ferma» ferma anche la frase che stava dicendo
        if voiceMade { voice.stopSpeaking(at: .immediate) }
        VoiceSession.deactivate()
        watchdog?.cancel(); watchdog = nil
        active = false; threat = nil; destination = nil
        // 2.0 (B75): Siri non usa più la posizione di un guardiano fermo
        here = nil; moveAnchor = nil; waitingForFix = true
    }

    /// Vero dopo la prima frase (la voce si crea solo quando serve)
    private var voiceMade = false

    // MARK: A ogni posizione

    func update(_ p: Coordinate, course: Double = -1, speed: Double? = nil) {
        guard active, let store else { return }
        if let a = moveAnchor {
            if PathMath.meters(a, p) > 50 { lastMove = Date(); moveAnchor = p }
        } else {
            moveAnchor = p; lastMove = Date()
        }
        here = p
        lastFixAt = Date()
        if waitingForFix { waitingForFix = false }

        // Arrivo, fermo da 15 minuti o più di 4 ore: il guardiano si ferma da solo
        if let d = destination, PathMath.meters(p, d.location) < 120 {
            if !Self.demo { notify(title: L("You have arrived"), body: L("GateLR has stopped watching the gates."), id: "arrived") }
            stop(); return
        }
        if let why = Self.autoStop(lastMove: lastMove, startedAt: startedAt, now: Date()) { stopped(why); return }

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
        lastMove = Date(); startedAt = Date(); moveAnchor = nil
        active = true
        update(p, course: course)
        // Un secondo punto 60 m più avanti: «ti avvicini» anche per il calcolo senza direzione
        update(PathMath.offset(p, meters: 60, bearing: course), course: course)
    }

    private static var demo: Bool { ProcessInfo.processInfo.arguments.contains("-uitest") }

    // MARK: Live Activity

    private var state: DriveAttributes.ContentState {
        waitingForFix ? Self.waitingState : Self.state(threat: threat, resting: resting)
    }

    /// 2.0 (B13): acceso ma senza ancora una posizione precisa: neutro, scudo vuoto, «In attesa del GPS…» (mai verde)
    nonisolated static var waitingState: DriveAttributes.ContentState {
        DriveAttributes.ContentState(symbol: "location.slash", distance: "", instruction: L("Waiting for GPS…"),
                                     warning: nil, eta: nil, level: "none", zone: nil)
    }

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
                                         content: ActivityContent(state: state.withoutPlates(PlatePrivacy.knownPlates), staleDate: DriveAttributes.staleDate()), pushType: nil)
        lastShown = state
    }

    /// «force»: anche senza cambiamenti, per spostare in avanti la data oltre cui la Live Activity è vecchia (B34)
    private func refreshActivity(force: Bool = false) {
        guard let activity else { return }
        let s = state
        // Distanza arrotondata: si aggiorna ogni 50-100 metri, non a ogni passo
        guard force || s != lastShown else { return }
        lastShown = s
        let shown = s.withoutPlates(PlatePrivacy.knownPlates)
        Task { await activity.update(ActivityContent(state: shown, staleDate: DriveAttributes.staleDate())) }
    }

    // MARK: Voce e notifiche

    private func say(_ text: String) {
        guard !Self.demo else { return }
        VoiceSession.activate()
        voiceMade = true
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
        // 2.0 (B144): solo posizioni recenti (quelle arrivate in ritardo tutte insieme non si usano)
        guard let l = locations.last, l.horizontalAccuracy >= 0, l.horizontalAccuracy < LocationGate.guardAccuracy,
              abs(l.timestamp.timeIntervalSinceNow) < 15 else { return }
        let c = Coordinate(lat: l.coordinate.latitude, lon: l.coordinate.longitude)
        // La direzione conta solo se il GPS la dà abbastanza precisa (come nella guida)
        let course = l.course >= 0 && (l.courseAccuracy < 0 || l.courseAccuracy <= 45) ? l.course : -1
        let speed = l.speed >= 0 ? l.speed : nil
        Task { @MainActor in self.update(c, course: course, speed: speed) }
    }

    /// 2.0 (B13): se durante il viaggio la posizione diventa negata o approssimativa, il guardiano si ferma e lo dice
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let ready = LocationGate.readiness(status: manager.authorizationStatus, accuracy: manager.accuracyAuthorization)
        Task { @MainActor in
            guard self.active, let place = self.destination, ready == .denied || ready == .approximate else { return }
            self.stop()
            GuardianNotice.shared.show(ready == .denied ? .denied : .approximate, place: place, navigator: nil)
        }
    }
}

/// 2.0 (B13): il messaggio «Serve la posizione precisa per i varchi» quando il guardiano non può partire (o si ferma)
/// perché la posizione è negata o approssimativa. Un oggetto a parte, osservato solo dall'avviso in RootView
@MainActor
final class GuardianNotice: ObservableObject {
    static let shared = GuardianNotice()

    struct Pending: Identifiable, Equatable {
        enum Problem: Equatable { case denied, approximate }
        var problem: Problem
        var place: Place
        /// Il navigatore scelto: «Apri comunque il navigatore» (senza guardiano); nil se il viaggio era già partito
        var navigator: Navigator?
        var id: String { "\(problem)|\(place.key)" }

        /// Il testo del messaggio (testabile)
        var message: String {
            switch problem {
            case .denied: L("Location is off for GateLR, so the guardian can't warn you before a gate. Turn it on in Settings → GateLR → Location.")
            case .approximate: L("With approximate location the guardian can't tell which gate is ahead. Turn on Precise Location in Settings → GateLR → Location.")
            }
        }
    }

    @Published var pending: Pending?

    func show(_ problem: Pending.Problem, place: Place, navigator: Navigator?) {
        pending = Pending(problem: problem, place: place, navigator: navigator)
        // Anche se GateLR non è davanti (il navigatore già aperto): una notifica, se permesse
        let c = UNMutableNotificationContent()
        c.title = L("Precise location is needed for the gates")
        c.body = PlatePrivacy.clean(pending?.message ?? "")
        c.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "guardian|location", content: c, trigger: nil))
    }
}

extension DriveAttributes {
    /// 2.0 (B34): oltre questa data la Live Activity si mostra vecchia (grigia, mai verde): 3 minuti senza aggiornamenti
    static func staleDate(from now: Date = Date()) -> Date { now.addingTimeInterval(180) }
}
