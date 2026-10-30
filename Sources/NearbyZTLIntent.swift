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

    /// La frase da dire (testabile, senza Siri)
    @MainActor
    static func answer(at p: Coordinate, store: Store, now: Date = Date()) -> String {
        let zones = store.cities.flatMap(\.zones)
        // Dentro più zone (Area C dentro l'Area B): la più piccola, come nel resto dell'app, non la prima del file
        let near = Self.nearest(zones, to: p)
        // Fuori dalle città che conosciamo (1.19.0): non diciamo «nessuna ZTL», perché non lo sappiamo
        guard let near, near.1 < 5_000 else {
            return Store.covers(p, in: store.cities) ? L("No ZTL within 5 km of you.") : L("We don't know the ZTLs of this area yet.")
        }
        let (z, d) = near
        let a = store.answer(at: now, zone: z, hotelInside: false)
        // Un «sì» da fonte non ufficiale: «Probabilmente sì · fonte non ufficiale: controlla il cartello»
        let short = a.verdict.spokenText(unofficial: z.isUnofficial)
        var text = d == 0 ? String(format: L("You're inside %@: %@."), z.shortName, short)
                          : String(format: L("%@ is %@ away: %@."), z.shortName, DriveSession.distanceText(d), short)
        if let next = a.nextChange {
            let when = store.engine.describe(next, from: now)
            text += " " + String(format: L(a.gatesOn ? "The gates switch off %@." : "The gates switch on %@."), when)
        }
        return text
    }

    /// La zona più vicina con la distanza; a parità (dentro a due zone) la più piccola
    static func nearest(_ zones: [Zone], to p: Coordinate) -> (Zone, Double)? {
        zones.map { ($0, $0.distance(lat: p.lat, lon: p.lon)) }
            .min { $0.1 != $1.1 ? $0.1 < $1.1 : $0.0.roughArea < $1.0.roughArea }
    }

    /// La posizione: quella che GateLR sta già seguendo, oppure una nuova lettura veloce
    @MainActor
    static func location() async -> Coordinate? {
        if let h = Guardian.shared.here ?? DriveSession.shared.here { return h }
        if let l = CLLocationManager().location, l.timestamp.timeIntervalSinceNow > -120 {
            return Coordinate(lat: l.coordinate.latitude, lon: l.coordinate.longitude)
        }
        return await withTaskGroup(of: Coordinate?.self) { group in
            group.addTask {
                do {
                    for try await u in CLLocationUpdate.liveUpdates() {
                        if let l = u.location, l.horizontalAccuracy < 200 { return Coordinate(lat: l.coordinate.latitude, lon: l.coordinate.longitude) }
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
