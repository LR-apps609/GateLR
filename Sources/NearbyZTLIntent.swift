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
        return .result(dialog: IntentDialog(stringLiteral: Self.answer(at: here, store: Store.shared)))
    }

    /// La frase da dire (testabile, senza Siri)
    @MainActor
    static func answer(at p: Coordinate, store: Store, now: Date = Date()) -> String {
        let zones = store.cities.flatMap(\.zones)
        let near = zones.map { ($0, $0.distance(lat: p.lat, lon: p.lon)) }.min { $0.1 < $1.1 }
        guard let near, near.1 < 5_000 else { return L("No ZTL within 5 km of you.") }
        let (z, d) = near
        let a = store.answer(at: now, zone: z, hotelInside: false)
        var text = d == 0 ? String(format: L("You're inside %@: %@."), z.shortName, a.verdict.short)
                          : String(format: L("%@ is %@ away: %@."), z.shortName, DriveSession.distanceText(d), a.verdict.short)
        if let next = a.nextChange {
            let when = store.engine.describe(next, from: now)
            text += " " + String(format: L(a.gatesOn ? "The gates switch off %@." : "The gates switch on %@."), when)
        }
        return text
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
    }
}
