import WidgetKit
import SwiftUI
import ActivityKit

/// La guida sulla schermata di blocco e nella Dynamic Island: prossima manovra, distanza, avviso ZTL
struct DriveLiveActivity: Widget {
    private static let blue = Color(hex: 0x1F4E9E)
    private static let red = Color(hex: 0xC1272D)

    private static let green = Color(hex: 0x34C26B)
    private static let amber = Color(hex: 0xF2B230)

    private static let neutral = Color(hex: 0xA9B3D1)

    /// Colore della risposta: rosso non entrare, giallo con condizioni o «?», verde nessuna ZTL attiva davanti
    /// («clear», 1.20.1: prima grigio), neutro se non conosciamo le ZTL del posto («none», 1.19.3: prima era lo scudo verde anche lì)
    static func tint(_ s: DriveAttributes.ContentState) -> Color {
        if s.warning != nil && s.level == nil { return red }
        switch s.level {
        case "no": return Color(hex: 0xFF4D52)
        case "cond": return amber
        case "ok": return green
        case "clear": return green          // 1.20.1: nessuna ZTL attiva davanti = verde (si entra)
        case "none": return neutral
        default: return .white
        }
    }

    static func shield(_ s: DriveAttributes.ContentState) -> String {
        switch s.level {
        case "no": return "exclamationmark.shield.fill"
        case "cond": return "shield.lefthalf.filled"
        case "ok": return "checkmark.shield.fill"
        case "clear": return "checkmark.shield"
        case "none": return "shield"
        default: return s.warning == nil ? s.symbol : "exclamationmark.triangle.fill"
        }
    }

    /// Accanto allo scudo, senza distanza: un segno uguale in ogni lingua (1.20.3: prima «OK» fisso in inglese, anche
    /// accanto al rosso). «✕» non entrare, «!» condizione, «✓» puoi entrare, «–» niente davanti, «?» non conosciamo il posto
    static func idleMark(_ s: DriveAttributes.ContentState) -> String {
        switch s.level {
        case "no": return "✕"
        case "cond": return "!"
        case "ok": return "✓"
        case "none": return "?"
        default: return "–"
        }
    }

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DriveAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: context.state.symbol).font(.system(size: 30, weight: .bold))
                        .frame(width: 44)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(context.state.distance).font(.system(size: 24, weight: .bold)).monospacedDigit()
                        Text(context.state.instruction).font(.system(size: 15, weight: .semibold)).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    if let eta = context.state.eta {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(eta, style: .time).font(.system(size: 17, weight: .bold)).monospacedDigit()
                            Text(context.attributes.destination).font(.system(size: 12)).lineLimit(1).opacity(0.85)
                        }
                    }
                }
                if let w = context.state.warning {
                    Label(w, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Self.red, in: Capsule())
                }
            }
            .foregroundStyle(.white)
            .padding(16)
            .activityBackgroundTint(Self.blue)
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.level == nil ? context.state.symbol : Self.shield(context.state))
                        .font(.system(size: 28, weight: .bold)).foregroundStyle(context.state.level == nil ? .white : Self.tint(context.state))
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.distance).font(.system(size: 22, weight: .bold)).monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.state.instruction).font(.system(size: 15, weight: .semibold)).lineLimit(2)
                        if let w = context.state.warning {
                            Label(w, systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 13, weight: .bold)).foregroundStyle(Self.red)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                // Lo scudo di GateLR colorato come la risposta: si riconosce anche accanto ad Apple Maps
                Image(systemName: Self.shield(context.state)).foregroundStyle(Self.tint(context.state))
            } compactTrailing: {
                if context.state.distance.isEmpty {
                    Text(verbatim: Self.idleMark(context.state)).font(.system(size: 13, weight: .bold)).foregroundStyle(Self.tint(context.state))
                } else {
                    Text(context.state.distance).font(.system(size: 13, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(Self.tint(context.state))
                }
            } minimal: {
                // Quando un'altra app (es. Apple Maps) occupa l'isola, resta questo pallino
                Image(systemName: Self.shield(context.state)).foregroundStyle(Self.tint(context.state))
            }
            .keylineTint(Self.tint(context.state))
            .widgetURL(URL(string: "gatelr://varco"))
        }
    }
}
