import WidgetKit
import SwiftUI
import AppIntents

// Widget per la schermata Home e di blocco: lo stato dei varchi del settore scelto, adesso.
// Calcola tutto sul telefono con gli stessi dati e lo stesso motore dell'app.

struct GateEntry: TimelineEntry {
    let date: Date
    let city: String
    let zone: Zone?
    let on: Bool
    let next: Date?
}

/// Una zona da scegliere nelle impostazioni del widget (tieni premuto → Modifica widget)
struct ZoneEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "ZTL zone"
    static var defaultQuery = ZoneQuery()
    var id: String
    var name: String
    var city: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)", subtitle: "\(city)") }

    static func all() -> [ZoneEntity] {
        CityLoader.shared.flatMap { c in c.zones.map { ZoneEntity(id: $0.id, name: $0.localizedName, city: c.localizedName) } }
    }
}

struct ZoneQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ZoneEntity] { ZoneEntity.all().filter { identifiers.contains($0.id) } }
    func suggestedEntities() async throws -> [ZoneEntity] { ZoneEntity.all() }
    func defaultResult() async -> ZoneEntity? { ZoneEntity.all().first { $0.id == "firenze-b" } ?? ZoneEntity.all().first }
}

struct SelectZoneIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose the zone"
    static var description = IntentDescription("The ZTL zone the widget shows.")
    @Parameter(title: "Zone") var zone: ZoneEntity?
}

struct GateProvider: AppIntentTimelineProvider {
    private let engine = RuleEngine()

    private func zone(_ wanted: String?) -> (City, Zone)? {
        let cities = CityLoader.shared
        let id = wanted ?? "firenze-b"
        if let city = cities.first(where: { $0.zones.contains { $0.id == id } }), let z = city.zones.first(where: { $0.id == id }) {
            return (city, z)
        }
        guard let city = cities.first else { return nil }
        return (city, city.zones[0])
    }

    private func entry(at date: Date, zone wanted: String?) -> GateEntry {
        guard let pair = zone(wanted) else { return GateEntry(date: date, city: "–", zone: nil, on: false, next: nil) }
        let (city, z) = pair
        return GateEntry(date: date, city: city.localizedName, zone: z, on: engine.isActive(z, at: date), next: engine.nextChange(z, after: date))
    }

    func placeholder(in context: Context) -> GateEntry { entry(at: Date(), zone: nil) }
    func snapshot(for configuration: SelectZoneIntent, in context: Context) async -> GateEntry {
        entry(at: Date(), zone: configuration.zone?.id)
    }

    /// Una voce adesso e una a ogni cambio di stato nelle prossime 24 ore
    func timeline(for configuration: SelectZoneIntent, in context: Context) async -> Timeline<GateEntry> {
        let id = configuration.zone?.id
        var entries = [entry(at: Date(), zone: id)]
        while let next = entries.last?.next, next < Date().addingTimeInterval(86_400), entries.count < 12 {
            entries.append(entry(at: next, zone: id))
        }
        // Zone sempre attive (es. zona T di Bologna): nessun cambio, si ricontrolla tra qualche ora
        return Timeline(entries: entries, policy: entries.count > 1 ? .atEnd : .after(Date().addingTimeInterval(6 * 3600)))
    }
}

struct GateWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GateEntry

    private var letter: String { entry.zone?.letter ?? "–" }
    /// Sulla schermata di blocco c'è poco posto: un triangolo davanti se le regole vengono da fonti non ufficiali
    private var warn: String { entry.zone?.isUnofficial == true ? "⚠︎ " : "" }
    private var state: String { entry.on ? L("ZTL active") : L("ZTL not active") }
    private var change: String {
        guard let next = entry.next else { return "" }
        // Ora italiana e, se non è oggi, anche il giorno (il sabato sera «Inizia alle 07:30» voleva dire lunedì)
        return String(format: L(entry.on ? "Ends at %@" : "Starts at %@"), RuleEngine().clock(next, from: entry.date))
    }
    /// Fonte non ufficiale: mai verde (1.19.0), giallo con il «?» anche a varchi spenti
    private var unofficial: Bool { entry.zone?.isUnofficial == true }
    /// Il simbolo a varchi spenti: «?» se la fonte non è ufficiale
    private var offSymbol: String {
        if unofficial { return "questionmark" }
        return "checkmark"
    }
    private var tint: Color { entry.on ? Color(hex: 0xC1272D) : (unofficial ? Color(hex: 0xD99A00) : Color(hex: 0x0FA34A)) }

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text(letter).font(.system(size: 20, weight: .bold))
                    Image(systemName: entry.on ? "video.fill" : offSymbol).font(.system(size: 11, weight: .bold))
                }
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: warn + "ZTL \(entry.city) · \(letter)").font(.system(size: 13, weight: .semibold))
                Text(state).font(.system(size: 17, weight: .bold))
                Text(change).font(.system(size: 12))
            }
        case .accessoryInline:
            Text(verbatim: warn + "ZTL \(letter): \(state.lowercased()) · \(change)")
        default:
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    LogoMark(size: 24)
                    Spacer()
                    Text("\(entry.city) · \(letter)").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                }
                if let z = entry.zone, z.isUnofficial {
                    // Regole da fonti non ufficiali: l'avviso al posto del tipo di zona
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(verbatim: L("Unofficial source"))
                    }
                    .font(.system(size: 11, weight: .bold)).lineLimit(1)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(UnofficialBanner.fill, in: Capsule())
                    .foregroundStyle(UnofficialBanner.ink)
                } else if let z = entry.zone {
                    // Il tipo di zona con il suo colore (vietato, pass, verde)
                    HStack(spacing: 4) {
                        Image(systemName: z.type.symbol).foregroundStyle(z.type.color)
                        Text(z.type.title).foregroundStyle(.secondary)
                    }
                    .font(.system(size: 11, weight: .semibold)).lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: entry.on ? "video.fill" : offSymbol + ".circle.fill")
                    .font(.system(size: 22, weight: .bold)).foregroundStyle(tint)
                Text(state).font(.system(size: 24, weight: .bold)).foregroundStyle(tint).minimumScaleFactor(0.7).lineLimit(1)
                Text(change).font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
            }
        }
    }
}

@main
struct GateLRWidgets: WidgetBundle {
    var body: some Widget {
        GateLRWidget()
        GuardianWidget()
        DriveLiveActivity()
    }
}

struct GateLRWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "GateLRWidget", intent: SelectZoneIntent.self, provider: GateProvider()) { entry in
            GateWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "gatelr://varco"))
        }
        .configurationDisplayName("ZTL gates")
        .description("Whether the gates of your sector are on, and when that changes.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// Widget «Guardiano»: la zona scelta adesso e un tocco per partire con il guardiano dalla scheda Viaggio.
// Il widget non sa se il guardiano è già acceso (servirebbe un App Group, che con un account gratuito
// può bloccare la firma): mostra lo stato dei varchi e apre l'app con gatelr://trip.
struct GuardianWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GateEntry

    private var letter: String { entry.zone?.letter ?? "–" }
    /// Sulla schermata di blocco c'è poco posto: un triangolo davanti se le regole vengono da fonti non ufficiali
    private var warn: String { entry.zone?.isUnofficial == true ? "⚠︎ " : "" }
    private var state: String { entry.on ? L("ZTL active") : L("ZTL not active") }
    /// Fonte non ufficiale: mai verde (1.19.0)
    private var tint: Color { entry.on ? Color(hex: 0xC1272D) : (entry.zone?.isUnofficial == true ? Color(hex: 0xD99A00) : Color(hex: 0x0FA34A)) }
    private var change: String {
        guard let next = entry.next else { return "" }
        // Ora italiana e, se non è oggi, anche il giorno (il sabato sera «Inizia alle 07:30» voleva dire lunedì)
        return String(format: L(entry.on ? "Ends at %@" : "Starts at %@"), RuleEngine().clock(next, from: entry.date))
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Image(systemName: "shield.lefthalf.filled").font(.system(size: 18, weight: .bold))
                    Text(letter).font(.system(size: 11, weight: .bold))
                }
            }
            .accessibilityLabel(Text(L("Start the guardian")))
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Label(L("Guardian"), systemImage: "shield.lefthalf.filled").font(.system(size: 13, weight: .semibold))
                Text("\(entry.city) · \(letter): \(state)").font(.system(size: 14, weight: .bold)).lineLimit(1)
                Text(L("Start the guardian")).font(.system(size: 12)).lineLimit(1)
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "shield.lefthalf.filled").font(.system(size: 18, weight: .bold)).foregroundStyle(tint)
                    Text(L("Guardian")).font(.system(size: 14, weight: .bold))
                    Spacer(minLength: 0)
                }
                Text("\(entry.city) · \(letter)").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary).lineLimit(1)
                Spacer(minLength: 0)
                Text(state).font(.system(size: 18, weight: .bold)).foregroundStyle(tint).minimumScaleFactor(0.7).lineLimit(1)
                if !change.isEmpty {
                    Text(change).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary).lineLimit(1)
                }
                Label(L("Start the guardian"), systemImage: "play.fill")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color(hex: 0x1F4E9E), in: Capsule())
            }
        }
    }
}

struct GuardianWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "GuardianWidget", intent: SelectZoneIntent.self, provider: GateProvider()) { entry in
            GuardianWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "gatelr://trip"))
        }
        .configurationDisplayName("Guardian")
        .description("Your zone right now, and one tap to start the guardian from Trip.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}
