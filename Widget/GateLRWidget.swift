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
        return Timeline(entries: entries, policy: .atEnd)
    }
}

struct GateWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GateEntry

    private var letter: String { entry.zone?.letter ?? "–" }
    private var state: String { entry.on ? L("ZTL active") : L("ZTL not active") }
    private var change: String {
        guard let next = entry.next else { return "" }
        return String(format: L(entry.on ? "Ends at %@" : "Starts at %@"), next.formatted(date: .omitted, time: .shortened))
    }
    private var tint: Color { entry.on ? Color(hex: 0xC1272D) : Color(hex: 0x2B7A47) }

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text(letter).font(.system(size: 20, weight: .bold))
                    Image(systemName: entry.on ? "video.fill" : "checkmark").font(.system(size: 11, weight: .bold))
                }
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text("ZTL \(entry.city) · \(letter)").font(.system(size: 13, weight: .semibold))
                Text(state).font(.system(size: 17, weight: .bold))
                Text(change).font(.system(size: 12))
            }
        case .accessoryInline:
            Text("ZTL \(letter): \(state.lowercased()) · \(change)")
        default:
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    LogoMark(size: 24)
                    Spacer()
                    Text("\(entry.city) · \(letter)").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: entry.on ? "video.fill" : "checkmark.circle.fill")
                    .font(.system(size: 22, weight: .bold)).foregroundStyle(tint)
                Text(state).font(.system(size: 24, weight: .bold)).foregroundStyle(tint).minimumScaleFactor(0.7).lineLimit(1)
                Text(change).font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
            }
        }
    }
}

@main
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
