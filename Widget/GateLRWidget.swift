import WidgetKit
import SwiftUI
import AppIntents

// Widget per la schermata Home e di blocco: la risposta per il TUO veicolo nella zona scelta, adesso.
// Calcola tutto sul telefono con gli stessi dati e lo stesso motore dell'app: dalla 1.19.3 le città aggiornate e il
// veicolo con i permessi arrivano dall'App Group (SharedData), e i dati più vecchi di 120 giorni sono gialli con il «?».

struct GateEntry: TimelineEntry {
    let date: Date
    let city: String
    let zone: Zone?
    let on: Bool
    let next: Date?
    /// La risposta per il veicolo scelto nell'app (WidgetAnswer.make)
    var answer: WidgetAnswer? = nil
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

    private func zone(_ wanted: String?, garage: SharedData.Garage?) -> (City, Zone)? {
        let cities = CityLoader.shared
        // Senza una zona scelta nel widget: quella scelta nell'app
        let id = wanted ?? garage?.zoneId ?? "firenze-b"
        if let city = cities.first(where: { $0.zones.contains { $0.id == id } }), let z = city.zones.first(where: { $0.id == id }) {
            return (city, z)
        }
        guard let city = cities.first else { return nil }
        return (city, city.zones[0])
    }

    private func entry(at date: Date, zone wanted: String?, garage: SharedData.Garage? = SharedData.garage()) -> GateEntry {
        guard let pair = zone(wanted, garage: garage) else { return GateEntry(date: date, city: "–", zone: nil, on: false, next: nil) }
        let (city, z) = pair
        let answer = WidgetAnswer.make(zone: z, cityId: city.id, garage: garage, at: date, engine: engine)
        return GateEntry(date: date, city: city.localizedName, zone: z, on: answer.gatesOn, next: answer.next, answer: answer)
    }

    func placeholder(in context: Context) -> GateEntry { entry(at: Date(), zone: nil) }
    func snapshot(for configuration: SelectZoneIntent, in context: Context) async -> GateEntry {
        entry(at: Date(), zone: configuration.zone?.id)
    }

    /// Una voce adesso e una a ogni cambio di stato nelle prossime 24 ore
    func timeline(for configuration: SelectZoneIntent, in context: Context) async -> Timeline<GateEntry> {
        let id = configuration.zone?.id
        let garage = SharedData.garage()
        var entries = [entry(at: Date(), zone: id, garage: garage)]
        while let next = entries.last?.next, next < Date().addingTimeInterval(86_400), entries.count < 12 {
            entries.append(entry(at: next, zone: id, garage: garage))
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
    /// 1.19.3: la risposta per il tuo veicolo, non più solo «attiva / non attiva». 1.20.3: sempre il titolo fisso
    /// («Non entrare», «A una condizione», «Controlla il cartello», «Puoi entrare»)
    private var state: String { entry.answer?.title ?? (entry.on ? L("ZTL active") : L("ZTL not active")) }
    private var change: String {
        guard let next = entry.next else { return "" }
        // Ora italiana e, se non è oggi, anche il giorno (il sabato sera «Inizia alle 07:30» voleva dire lunedì)
        return String(format: L(entry.on ? "Ends at %@" : "Starts at %@"), RuleEngine().clock(next, from: entry.date))
    }
    private var symbol: String { entry.answer?.symbol ?? "questionmark" }
    private var tint: Color { GateWidgetView.color(entry.answer?.tone ?? .amber) }

    /// Il simbolo pieno grande: «xmark.circle.fill», «moon.zzz.fill»
    static func filled(_ symbol: String) -> String {
        if symbol == "moon.zzz" { return "moon.zzz.fill" }
        return symbol + ".circle.fill"
    }

    /// Rosso non entrare, giallo condizione o «?», verde puoi entrare, grigio ZTL non attiva
    static func color(_ tone: WidgetAnswer.Tone) -> Color {
        switch tone {
        case .red: Color(hex: 0xC1272D)
        case .amber: Color(hex: 0xD99A00)
        case .green: Color(hex: 0x0FA34A)
        case .grey: Color(hex: 0x7C8596)
        }
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text(letter).font(.system(size: 20, weight: .bold))
                    Image(systemName: symbol).font(.system(size: 11, weight: .bold))
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
                Image(systemName: Self.filled(symbol))
                    .font(.system(size: 22, weight: .bold)).foregroundStyle(tint)
                Text(state).font(.system(size: 22, weight: .bold)).foregroundStyle(tint).minimumScaleFactor(0.6).lineLimit(1)
                // 1.20.3: sotto il titolo fisso lo stato della ZTL (o «Dati da ricontrollare») e il prossimo cambio
                Text(verbatim: [entry.answer?.stale == true ? L("Data to recheck") : entry.on ? L("ZTL active") : L("ZTL not active"), change]
                        .filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
                if let v = entry.answer?.vehicleName {
                    Text(verbatim: v).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
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
        .description("Whether your vehicle can enter your zone now, and when that changes.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// Widget «Guardiano»: la zona scelta adesso e un tocco per partire con il guardiano dalla scheda Viaggio.
// Il widget non sa se il guardiano è già acceso: mostra la risposta per il tuo veicolo e apre l'app con gatelr://trip.
struct GuardianWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GateEntry

    private var letter: String { entry.zone?.letter ?? "–" }
    /// Sulla schermata di blocco c'è poco posto: un triangolo davanti se le regole vengono da fonti non ufficiali
    private var warn: String { entry.zone?.isUnofficial == true ? "⚠︎ " : "" }
    /// La stessa risposta del widget «Varchi ZTL» (veicolo scelto, dati vecchi gialli), 1.19.3
    private var state: String { entry.answer?.title ?? (entry.on ? L("ZTL active") : L("ZTL not active")) }
    private var tint: Color { GateWidgetView.color(entry.answer?.tone ?? .amber) }
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
