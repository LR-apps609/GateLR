import AppIntents
import Foundation

// «Ehi Siri, posso entrare a Firenze Settore A con GateLR?» e «Ehi Siri, ferma il guardiano di GateLR».
// Le zone arrivano dallo Store dopo la lettura delle città (whenLoaded): Siri può aprire l'app in sottofondo
// proprio per questa domanda, quando le città non sono ancora pronte.

/// Una zona ZTL da nominare a Siri o da scegliere in Comandi rapidi («Firenze Settore A», «Milano Area C»)
struct CityZoneEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "ZTL zone"
    static var defaultQuery = CityZoneQuery()

    var id: String
    var title: String
    /// Città e zona in tutte le lingue dei dati, senza accenti e in minuscolo (per capire «Florence», «Firenze», «Florenz»)
    fileprivate var cityKeys: [String] = []
    fileprivate var fullKeys: [String] = []

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }

    init(city: City, zone: Zone) {
        id = zone.id
        title = "\(city.localizedName) \(zone.shortName)"
        let cities = Set([city.name, city.name_it, city.name_de, city.localizedName, city.id].compactMap { $0 }.map(Self.fold))
        let zones = Set([zone.name, zone.name_it, zone.name_de, zone.localizedName].compactMap { $0 }
            .map { Self.fold(String($0.split(separator: "·").first ?? Substring($0))) })
        cityKeys = Array(cities)
        fullKeys = cities.flatMap { c in zones.map { "\(c) \($0)" } }
    }

    static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Tutte le zone, appena le città vere sono pronte
    @MainActor static func all() async -> [CityZoneEntity] {
        await Store.shared.whenLoaded()
        return Store.shared.cities.flatMap { c in c.zones.map { CityZoneEntity(city: c, zone: $0) } }
    }

    /// Le zone che corrispondono a quello che si è detto: prima città e zona insieme, poi solo la città
    static func matching(_ text: String, in all: [CityZoneEntity]) -> [CityZoneEntity] {
        let q = fold(text)
        guard !q.isEmpty else { return all }
        let exact = all.filter { $0.fullKeys.contains { q.contains($0) } }
        if !exact.isEmpty { return exact }
        let city = all.filter { $0.cityKeys.contains { q.contains($0) || $0.hasPrefix(q) } }
        if !city.isEmpty { return city }
        return all.filter { fold($0.title).contains(q) || $0.fullKeys.contains { $0.contains(q) } }
    }
}

struct CityZoneQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [CityZoneEntity] {
        await CityZoneEntity.all().filter { identifiers.contains($0.id) }
    }
    func suggestedEntities() async throws -> [CityZoneEntity] { await CityZoneEntity.all() }
    func entities(matching string: String) async throws -> [CityZoneEntity] {
        CityZoneEntity.matching(string, in: await CityZoneEntity.all())
    }
}

/// «Posso entrare in <zona> adesso?» (o all'ora di arrivo): la risposta del motore detta da Siri
struct CanIDriveIntoIntent: AppIntent {
    static var title: LocalizedStringResource = "Can I drive in?"
    static var description = IntentDescription("Tells you whether your car can drive into a ZTL zone now or at the time you arrive.")
    static var openAppWhenRun = false

    @Parameter(title: "Zone", requestValueDialog: IntentDialog("Which ZTL zone?"))
    var zone: CityZoneEntity

    @Parameter(title: "Arriving at")
    var date: Date?

    static var parameterSummary: some ParameterSummary {
        Summary("Can I drive into \(\.$zone)?") { \.$date }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = Store.shared
        await store.whenLoaded()
        guard let city = store.cities.first(where: { $0.zones.contains { $0.id == zone.id } }),
              let z = city.zones.first(where: { $0.id == zone.id }) else {
            return .result(dialog: IntentDialog(stringLiteral: L("I can't find this zone in GateLR.")))
        }
        return .result(dialog: IntentDialog(stringLiteral: Self.answer(city: city, zone: z, at: date, store: store)))
    }

    /// La frase da dire (testabile, senza Siri): «Firenze Settore A: Non entrare. I varchi si spengono oggi alle 20:00.»
    @MainActor
    static func answer(city: City, zone z: Zone, at asked: Date?, store: Store, now: Date = Date()) -> String {
        let date = asked.map { arrival($0, now: now, calendar: store.engine.calendar) }
        let when = date ?? now
        let a = store.answer(at: when, zone: z, hotelInside: false)
        let name = "\(city.localizedName) \(z.shortName)"
        var text: String
        if let date, abs(date.timeIntervalSince(now)) > 10 * 60 {
            text = String(format: L("%@, %@: %@."), name, store.engine.describe(date, from: now), a.verdict.short)
        } else {
            text = String(format: L("%@: %@."), name, a.verdict.short)
        }
        switch a.verdict {
        case .conditional(_, let condition): text += " " + condition
        case .unsure(let reason): text += " " + reason
        default: break
        }
        if let next = a.nextChange {
            text += " " + String(format: L(a.gatesOn ? "The gates switch off %@." : "The gates switch on %@."), store.engine.describe(next, from: now))
        }
        return text
    }

    /// L'ora di arrivo già passata («alle 8» detto alle 10, o una data vecchia da Comandi rapidi) vale per la
    /// prossima volta che sono quelle ore: prima la risposta era per un momento passato («I varchi si spengono
    /// oggi alle 20:00» quando erano già spenti). Dieci minuti di tolleranza per «adesso».
    static func arrival(_ date: Date, now: Date, calendar: Calendar) -> Date {
        guard date < now.addingTimeInterval(-10 * 60) else { return date }
        let days = calendar.dateComponents([.day], from: date, to: now).day ?? 0
        var out = calendar.date(byAdding: .day, value: max(0, days), to: date) ?? date
        while out < now.addingTimeInterval(-10 * 60) {
            guard let next = calendar.date(byAdding: .day, value: 1, to: out) else { break }
            out = next
        }
        return out
    }
}

/// «Ferma il guardiano»: da Siri, da Comandi rapidi o dal tasto Azione, senza aprire l'app
struct StopGuardianIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop the guardian"
    static var description = IntentDescription("Stops GateLR's guardian and its ZTL alerts.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard Guardian.shared.active else {
            // App chiusa da iOS con il guardiano acceso: la Live Activity resta sulla schermata di blocco
            // anche se il guardiano non c'è più. Si chiude qui, così «ferma il guardiano» la toglie davvero.
            if await Guardian.endOrphanActivities() {
                return .result(dialog: IntentDialog(stringLiteral: L("Guardian stopped.")))
            }
            return .result(dialog: IntentDialog(stringLiteral: L("The guardian isn't on.")))
        }
        Guardian.shared.stop()
        return .result(dialog: IntentDialog(stringLiteral: L("Guardian stopped.")))
    }
}
