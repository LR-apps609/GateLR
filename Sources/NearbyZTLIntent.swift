import AppIntents
import CoreLocation

/// «Ehi Siri, ZTL vicine con GateLR»: la ZTL più vicina, a che distanza e se adesso si entra.
/// Funziona anche a telefono bloccato e in CarPlay; la risposta è detta da Siri.
struct NearbyZTLIntent: AppIntent {
    static var title: LocalizedStringResource = "ZTL near me"
    static var description = IntentDescription("Tells you the nearest ZTL, how far it is and whether you can drive in now.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let here = await Self.location() else {
            return .result(dialog: IntentDialog(stringLiteral: L("I can't find your position. Open GateLR and allow location access.")))
        }
        await Store.shared.whenLoaded()          // con l'app appena aperta da Siri le città si stanno ancora leggendo
        return .result(dialog: IntentDialog(stringLiteral: Self.answer(at: here, store: Store.shared)))
    }

    /// La frase da dire (testabile, senza Siri). 1.19.3: la stessa risposta di Varco e del guardiano. Dentro una zona
    /// la più severa tra quelle che ti contengono (PlaceCheck), l'area pedonale vince, fonte non ufficiale detta con
    /// prudenza; fuori la zona o l'area pedonale più vicina (ThreatEvaluator); fuori dalle città che conosciamo
    /// «Non conosciamo le ZTL di questo posto», mai «Nessuna ZTL entro 5 km», che suonava come un via libera
    /// 1.19.4: senza le targhe del Garage (Siri la dice ad alta voce)
    @MainActor
    static func answer(at p: Coordinate, store: Store, now: Date = Date()) -> String {
        PlatePrivacy.scrub(spokenAnswer(at: p, store: store, now: now), plates: store.vehicles.map(\.plate))
    }

    @MainActor
    private static func spokenAnswer(at p: Coordinate, store: Store, now: Date) -> String {
        let check = PlaceCheck(Place(name: "", address: "", location: p), store: store, at: now)
        if let area = check.pedestrian {
            return String(format: L("You're inside %@: %@."), String(format: L("Pedestrian area · %@"), area.name), L("Don't enter"))
        }
        if let zone = check.zone, let a = check.answer {
            // 2.1: le parole della RispostaFinale («ZTL non attiva», «Controlla il cartello · Dati scaduti»)
            var text = String(format: L("You're inside %@: %@."), zone.shortName, check.finale.spoken)
            text += next(a, store: store, now: now)
            return text
        }
        // Fuori: la zona o l'area pedonale più vicina entro 5 km, con la risposta all'ora in cui ci arrivi
        let near = ThreatEvaluator.candidates(store.cities, near: p, within: 5_000, now: now)
            .map { ($0, ThreatEvaluator.nearestPoint($0.zone.perimeter, to: p).meters) }
            .min { $0.1 != $1.1 ? $0.1 < $1.1 : $0.0.zone.roughArea < $1.0.zone.roughArea }
        guard let near, near.1 < 5_000 else {
            return check.covered ? L("No ZTL within 5 km of you.") : L("We don't know the ZTLs of this place") + "."
        }
        let (c, d) = near
        let a = store.threatAnswer(c, at: ThreatEvaluator.arrival(in: d, speed: nil, now: now), destination: nil)
        let name = c.pedestrian != nil ? c.zone.localizedName : c.zone.shortName
        var text = String(format: L("%@ is %@ away: %@."), name, DriveSession.distanceText(d), ThreatEvaluator.spoken(a.verdict, c))
        if c.pedestrian == nil { text += next(a, store: store, now: now) }
        return text
    }

    /// « I varchi si spengono oggi alle 20:00.»
    @MainActor
    private static func next(_ a: Answer, store: Store, now: Date) -> String {
        guard let next = a.nextChange else { return "" }
        return " " + String(format: L(a.gatesOn ? "The gates switch off %@." : "The gates switch on %@."), store.engine.describe(next, from: now))
    }

    /// La zona più vicina con la distanza; a parità (dentro a due zone) la più piccola
    static func nearest(_ zones: [Zone], to p: Coordinate) -> (Zone, Double)? {
        zones.map { ($0, $0.distance(lat: p.lat, lon: p.lon)) }
            .min { $0.1 != $1.1 ? $0.1 < $1.1 : $0.0.roughArea < $1.0.roughArea }
    }

    /// La posizione: quella che GateLR sta già seguendo, oppure una nuova lettura veloce
    @MainActor
    static func location() async -> Coordinate? {
        // 2.0 (B75): la posizione del guardiano o della guida solo se sono accesi (azzerata quando si fermano)
        if Guardian.shared.active, let h = Guardian.shared.here { return h }
        if DriveSession.shared.active, let h = DriveSession.shared.here { return h }
        // 2.0 (B27): mai una posizione approssimativa (può essere a chilometri: la risposta di un'altra zona)
        let manager = CLLocationManager()
        guard manager.accuracyAuthorization == .fullAccuracy else { return nil }
        if let l = manager.location, LocationGate.usable(l, accuracy: manager.accuracyAuthorization) {
            return Coordinate(lat: l.coordinate.latitude, lon: l.coordinate.longitude)
        }
        return await withTaskGroup(of: Coordinate?.self) { group in
            group.addTask {
                do {
                    for try await u in CLLocationUpdate.liveUpdates() {
                        if let l = u.location, l.horizontalAccuracy >= 0, l.horizontalAccuracy <= LocationGate.answerAccuracy { return Coordinate(lat: l.coordinate.latitude, lon: l.coordinate.longitude) }
                    }
                } catch {}
                return nil
            }
            group.addTask { try? await Task.sleep(for: .seconds(8)); return nil }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }
}

struct GateLRShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: NearbyZTLIntent(),
                    phrases: ["ZTL near me with \(.applicationName)",
                              "Any ZTL nearby in \(.applicationName)",
                              "\(.applicationName) ZTL",
                              "Ask \(.applicationName) about ZTL"],
                    shortTitle: "ZTL near me",
                    systemImageName: "shield.lefthalf.filled")
        // «Posso entrare a Firenze Settore A con GateLR?»: le zone sono quelle dello Store (CityZoneQuery)
        AppShortcut(intent: CanIDriveIntoIntent(),
                    phrases: ["Can I drive into \(\.$zone) with \(.applicationName)",
                              "Can I enter \(\.$zone) with \(.applicationName)",
                              "\(.applicationName) \(\.$zone)",
                              "Can I drive in with \(.applicationName)"],
                    shortTitle: "Can I drive in?",
                    systemImageName: "questionmark.circle")
        AppShortcut(intent: StopGuardianIntent(),
                    phrases: ["Stop the guardian in \(.applicationName)",
                              "Stop the \(.applicationName) guardian",
                              "\(.applicationName) stop the guardian"],
                    shortTitle: "Stop the guardian",
                    systemImageName: "shield.slash")
    }
}
