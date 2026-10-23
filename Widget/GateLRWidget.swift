import WidgetKit
import SwiftUI

// Widget per la schermata Home e di blocco: lo stato dei varchi del settore scelto, adesso.
// Calcola tutto sul telefono con gli stessi dati e lo stesso motore dell'app.

struct GateEntry: TimelineEntry {
    let date: Date
    let city: String
    let zone: Zone?
    let on: Bool
    let next: Date?
}

struct GateProvider: TimelineProvider {
    private let engine = RuleEngine()

    private func zone() -> (City, Zone)? {
        let cities = CityLoader.bundled()
        guard let city = cities.first(where: { $0.id == "firenze" }) ?? cities.first else { return nil }
        let wanted = UserDefaults.standard.string(forKey: "widget.zone") ?? "firenze-b"
        return (city, city.zones.first { $0.id == wanted } ?? city.zones[0])
    }

    private func entry(at date: Date) -> GateEntry {
        guard let (city, z) = zone() else { return GateEntry(date: date, city: "–", zone: nil, on: false, next: nil) }
        return GateEntry(date: date, city: city.name, zone: z, on: engine.isActive(z, at: date), next: engine.nextChange(z, after: date))
    }

    func placeholder(in context: Context) -> GateEntry { entry(at: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (GateEntry) -> Void) { completion(entry(at: Date())) }

    /// Una voce adesso e una a ogni cambio di stato nelle prossime 24 ore
    func getTimeline(in context: Context, completion: @escaping (Timeline<GateEntry>) -> Void) {
        var entries = [entry(at: Date())]
        while let next = entries.last?.next, next < Date().addingTimeInterval(86_400), entries.count < 12 {
            entries.append(entry(at: next))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct GateWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GateEntry

    private var letter: String { entry.zone?.letter ?? "–" }
    private var state: String { entry.on ? "Gates on" : "Gates off" }
    private var change: String {
        guard let next = entry.next else { return "" }
        return "\(entry.on ? "Off" : "On") at \(next.formatted(date: .omitted, time: .shortened))"
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
        StaticConfiguration(kind: "GateLRWidget", provider: GateProvider()) { entry in
            GateWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "gatelr://now"))
        }
        .configurationDisplayName("ZTL gates")
        .description("Whether the gates of your sector are on, and when that changes.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
