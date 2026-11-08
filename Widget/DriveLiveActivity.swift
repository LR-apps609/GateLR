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
    /// 1.20.4: fuori dalla ZTL in una città che conosciamo, grigio neutro (decisione di Ledion del 07/11, mai verde)
    private static let outside = Color(hex: 0xAEB4BC)

    /// Colore della risposta: rosso non entrare, giallo con condizioni o «?», grigio nessuna ZTL attiva davanti in una città
    /// che conosciamo («clear», 1.20.4: fuori dalla ZTL è grigio; 1.20.1–1.20.3 verde), neutro se non conosciamo le ZTL del
    /// posto («none», 1.19.3: prima era lo scudo verde anche lì)
    static func tint(_ s: DriveAttributes.ContentState) -> Color {
        if s.warning != nil && s.level == nil { return red }
        switch s.level {
        case "no": return Color(hex: 0xFF4D52)
        case "cond": return amber
        case "ok": return green
        case "clear": return outside        // 1.20.4: grigio, come il riquadro del guardiano in Varco
        case "none": return neutral
        default: return .white
        }
    }

    static func shield(_ s: DriveAttributes.ContentState) -> String {
        switch s.level {
        case "no": return "exclamationmark.shield.fill"
        case "cond": return "shield.lefthalf.filled"
        case "ok": return "checkmark.shield.fill"
        case "clear": return "shield"       // 1.20.4: forma neutra (prima lo scudo con la spunta), accanto il «–»
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

    /// 2.0 (B73): il fondo dell'avviso: rosso per «no» (e per gli avvisi della guida senza livello), ambra per «cond»
    static func warningFill(_ s: DriveAttributes.ContentState) -> Color { s.level == "cond" ? amber : red }
    static func warningInk(_ s: DriveAttributes.ContentState) -> Color { s.level == "cond" ? Color(hex: 0x1B2128) : .white }
    /// Il testo dell'avviso sul fondo scuro dell'isola espansa
    static func warningText(_ s: DriveAttributes.ContentState) -> Color { s.level == "cond" ? amber : Color(hex: 0xFF4D52) }

    /// 2.0 (B34): una Live Activity non più aggiornata (oltre la staleDate: GPS perso, app chiusa da iOS) si mostra
    /// vecchia: neutra, senza avviso né distanza, con «Non aggiornato: apri GateLR». Mai verde congelata
    static func shown(_ s: DriveAttributes.ContentState, stale: Bool) -> DriveAttributes.ContentState {
        guard stale else { return s }
        var out = s
        out.level = "none"; out.warning = nil; out.distance = ""; out.eta = nil; out.symbol = "shield"
        out.instruction = L("Not updated: open GateLR")
        return out
    }

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DriveAttributes.self) { context in
            let s = Self.shown(context.state, stale: context.isStale)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: s.symbol).font(.system(size: 30, weight: .bold))
                        .frame(width: 44)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(s.distance).font(.system(size: 24, weight: .bold)).monospacedDigit()
                        Text(s.instruction).font(.system(size: 15, weight: .semibold)).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    if let eta = s.eta {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(eta, style: .time).font(.system(size: 17, weight: .bold)).monospacedDigit()
                            Text(context.attributes.destination).font(.system(size: 12)).lineLimit(1).opacity(0.85)
                        }
                    }
                }
                if let w = s.warning {
                    // 2.0 (B73): la capsula del colore della risposta: rossa solo per «Non entrare», gialla con il testo
                    // scuro per condizioni, «Controlla il cartello» e fonte non ufficiale (prima sempre rossa)
                    Label(w, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Self.warningFill(s), in: Capsule())
                        .foregroundStyle(Self.warningInk(s))
                }
            }
            .foregroundStyle(.white)
            .padding(16)
            .activityBackgroundTint(Self.blue)
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let s = Self.shown(context.state, stale: context.isStale)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: s.level == nil ? s.symbol : Self.shield(s))
                        .font(.system(size: 28, weight: .bold)).foregroundStyle(s.level == nil ? .white : Self.tint(s))
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(s.distance).font(.system(size: 22, weight: .bold)).monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(s.instruction).font(.system(size: 15, weight: .semibold)).lineLimit(2)
                        if let w = s.warning {
                            Label(w, systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 13, weight: .bold)).foregroundStyle(Self.warningText(s))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                // Lo scudo di GateLR colorato come la risposta: si riconosce anche accanto ad Apple Maps
                Image(systemName: Self.shield(s)).foregroundStyle(Self.tint(s))
            } compactTrailing: {
                if s.distance.isEmpty {
                    Text(verbatim: Self.idleMark(s)).font(.system(size: 13, weight: .bold)).foregroundStyle(Self.tint(s))
                } else {
                    Text(s.distance).font(.system(size: 13, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(Self.tint(s))
                }
            } minimal: {
                // Quando un'altra app (es. Apple Maps) occupa l'isola, resta questo pallino
                Image(systemName: Self.shield(s)).foregroundStyle(Self.tint(s))
            }
            .keylineTint(Self.tint(s))
            .widgetURL(URL(string: "gatelr://varco"))
        }
    }
}
