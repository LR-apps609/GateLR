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

    struct Threat: Equatable {
        var zone: Zone
        var meters: Double
        var answer: Answer
    }

    @Published private(set) var active = false
    @Published private(set) var destination: Place?
    @Published private(set) var threat: Threat?          // la ZTL più vicina verso cui stai andando, se a quell'ora non entri
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
    private var alerted = Set<String>()
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
        alerted = []; lastDistances = [:]; threat = nil
        lastMove = Date(); startedAt = Date()
        manager.requestAlwaysAuthorization()
        if Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") != nil {
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
        }
        manager.startUpdatingLocation()
        Task { _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) }
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

    func update(_ p: Coordinate, course: Double = -1) {
        guard active, let store else { return }
        if let here, PathMath.meters(here, p) > 20 { lastMove = Date() }
        here = p

        // Arrivo, fermo da 15 minuti o più di 4 ore: il guardiano si ferma da solo
        if let d = destination, PathMath.meters(p, d.location) < 120 {
            notify(title: L("You have arrived"), body: L("GateLR has stopped watching the gates."), id: "arrived")
            stop(); return
        }
        if Date().timeIntervalSince(lastMove) > 15 * 60 || Date().timeIntervalSince(startedAt) > 4 * 3600 { stop(); return }

        // Le zone vicine che a quell'ora non ti fanno entrare liberamente, e verso cui ti stai avvicinando
        let scan = Self.scan(at: p, zones: store.cities.flatMap(\.zones), last: lastDistances) { z, d in
            store.answer(at: Date().addingTimeInterval(d / 9), zone: z, hotelInside: false)
        }
        lastDistances = scan.distances
        for (z, a) in scan.entered {
            store.record(.entered, zone: z, verdict: a.verdict)
            // Il consiglio che evita le multe a catena: non girare dentro cercando l'uscita
            if case .no = a.verdict, !alerted.contains("in|\(z.id)") {
                alerted.insert("in|\(z.id)")
                say(String(format: L("You're inside %@. Leave by the nearest exit and don't drive around: every gate can mean another fine."), z.shortName))
                notify(title: String(format: L("You're inside %@"), z.shortName),
                       body: L("Leave by the nearest exit and don't drive around: every gate can mean another fine."), id: "in|\(z.id)")
            }
        }
        let best = scan.threat
        if best != threat { threat = best }      // si pubblica solo se cambia davvero

        if let t = best {
            if t.meters < 550 && !alerted.contains("far|\(t.zone.id)") {
                alerted.insert("far|\(t.zone.id)")
                let text = String(format: L("Attention: in %@ you enter %@. %@."), DriveSession.distanceText(t.meters), t.zone.shortName, t.answer.verdict.spokenText(unofficial: t.zone.isUnofficial))
                say(text)
                notify(title: String(format: L("%@ in %@"), t.zone.shortName, DriveSession.distanceText(t.meters)), body: t.answer.verdict.spokenText(unofficial: t.zone.isUnofficial), id: "far|\(t.zone.id)")
            }
            if t.meters < 150 && !alerted.contains("near|\(t.zone.id)") {
                alerted.insert("near|\(t.zone.id)")
                say(String(format: L("Gate ahead: %@."), t.answer.verdict.spokenText(unofficial: t.zone.isUnofficial)))
                notify(title: String(format: L("Gate ahead: %@"), t.zone.shortName), body: t.answer.verdict.spokenText(unofficial: t.zone.isUnofficial), id: "near|\(t.zone.id)")
            }
        } else {
            // Ti sei allontanato: gli avvisi si possono ripetere se torni verso la zona
            alerted = alerted.filter { key in lastDistances.contains { key.hasSuffix("|\($0.key)") && $0.value < 900 } }
        }
        refreshActivity()
    }

    /// Il calcolo puro (testabile): la ZTL più vicina verso cui ti avvicini e dove non entri liberamente,
    /// e le zone in cui sei appena entrato. «answer» dà la risposta per la zona a quella distanza.
    nonisolated static func scan(at p: Coordinate, zones: [Zone], last: [String: Double],
                                 answer: (Zone, Double) -> Answer) -> (threat: Threat?, entered: [(Zone, Answer)], distances: [String: Double]) {
        var distances = last
        var best: Threat?
        var entered: [(Zone, Answer)] = []
        for z in zones {
            let d = z.distance(lat: p.lat, lon: p.lon)
            let before = last[z.id]
            distances[z.id] = d
            guard d < 3_000 else { continue }
            if d == 0 {
                if let before, before > 0 {
                    let a = answer(z, 0)
                    // Un «sì» da fonte non ufficiale non è un via libera (1.19.0): si mostra giallo e si avvisa
                    if !a.verdict.shown(unofficial: z.isUnofficial).isYes { entered.append((z, a)) }
                }
                continue
            }
            let a = answer(z, d)
            if a.verdict.shown(unofficial: z.isUnofficial).isYes { continue }
            guard before.map({ d < $0 - 3 }) ?? true else { continue }       // solo se ti stai avvicinando
            if best == nil || d < best!.meters { best = Threat(zone: z, meters: d, answer: a) }
        }
        return (best, entered, distances)
    }

    // MARK: Live Activity

    private var state: DriveAttributes.ContentState {
        if let t = threat {
            // Il livello dalla risposta come si mostra: un «sì» da fonte non ufficiale è giallo («cond»), mai «ok» verde
            let level: String = switch t.answer.verdict.shown(unofficial: t.zone.isUnofficial) { case .no: "no"; case .yes: "ok"; default: "cond" }
            // Fonte non ufficiale: «Probabilmente no · Fonte non ufficiale», «Probabilmente sì · fonte non ufficiale: controlla il cartello»
            let short = t.answer.verdict.spokenText(unofficial: t.zone.isUnofficial)
            return DriveAttributes.ContentState(symbol: t.zone.type.symbol, distance: DriveSession.distanceText(t.meters),
                                                instruction: "\(t.zone.shortName) · \(short)",
                                                warning: t.meters < 600 ? String(format: L("%@ in %@: %@"), t.zone.shortName, DriveSession.distanceText(t.meters), short) : nil,
                                                eta: nil, level: level, zone: t.zone.shortName)
        }
        return DriveAttributes.ContentState(symbol: "checkmark.shield.fill", distance: "",
                                            instruction: L("No active ZTL ahead"), warning: nil, eta: nil, level: "ok", zone: nil)
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
        guard ActivityAuthorizationInfo().areActivitiesEnabled, activity == nil else { return }
        activity = try? Activity.request(attributes: DriveAttributes(destination: destination?.name ?? "GateLR"),
                                         content: ActivityContent(state: state, staleDate: nil), pushType: nil)
        lastShown = state
    }

    private func refreshActivity() {
        guard let activity else { return }
        let s = state
        // Distanza arrotondata: si aggiorna ogni 50-100 metri, non a ogni passo
        guard s != lastShown else { return }
        lastShown = s
        Task { await activity.update(ActivityContent(state: s, staleDate: nil)) }
    }

    // MARK: Voce e notifiche

    private func say(_ text: String) {
        VoiceSession.activate()
        voice.speak(SpeechVoice.utterance(text))
    }

    private func notify(title: String, body: String, id: String) {
        let c = UNMutableNotificationContent()
        c.title = title; c.body = body; c.sound = .default
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
        let course = l.course
        Task { @MainActor in self.update(c, course: course) }
    }
}
