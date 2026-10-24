import SwiftUI
import UIKit

// Lo stile della segnaletica italiana: rosso del divieto, blu dei pannelli, verde del «via libera».
// Ogni colore ha la sua versione per la modalità scura.
/// Testo tradotto (Resources/Localizations/*.lproj/Localizable.strings); senza traduzione resta l'inglese
func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

enum Theme {
    static let ground = Color(light: 0xF3F4F2, dark: 0x0F1318)
    static let card = Color(light: 0xFFFFFF, dark: 0x1A2027)
    static let raised = Color(light: 0xF7F8F7, dark: 0x222A33)      // campi dentro le schede
    static let ink = Color(light: 0x1B2128, dark: 0xE8ECEF)
    static let muted = Color(light: 0x5D6670, dark: 0x9BA5AE)
    static let line = Color(light: 0xE6E9E7, dark: 0x2C343D)
    static let red = Color(light: 0xC1272D, dark: 0xEF5B55)
    static let blue = Color(light: 0x1F4E9E, dark: 0x8CB0EE)
    /// Fondo dei pulsanti pieni: abbastanza scuro anche in modalità scura, per il testo bianco
    static let blueFill = Color(light: 0x1F4E9E, dark: 0x2F5FB3)
    static let blueSoft = Color(light: 0xE2EAF6, dark: 0x1D2B44)
    static let green = Color(hex: 0x2B7A47)
    static let greenSoft = Color(light: 0xDCEFE2, dark: 0x183021)
    static let greenInk = Color(light: 0x22653A, dark: 0x7FD19B)
    static let amber = Color(hex: 0x8A5A00)
    static let amberSoft = Color(light: 0xFBECC8, dark: 0x3A2C0E)
    static let amberInk = Color(light: 0x5C3C00, dark: 0xF2CB79)
    static let brass = Color(light: 0xA97E3F, dark: 0xD6AA62)       // il filo della famiglia LR

    /// Titoli: Titillium Web, il carattere dei cartelli (licenza OFL, in Resources/Fonts), interlinea stretta
    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        let name = weight == .black ? "TitilliumWeb-Black" : weight == .semibold ? "TitilliumWeb-SemiBold" : "TitilliumWeb-Bold"
        return Font.custom(name, size: size).leading(.tight)
    }
    static func label(_ size: CGFloat = 13) -> Font { .custom("TitilliumWeb-SemiBold", size: size) }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
    init(light: UInt32, dark: UInt32) {
        func ui(_ h: UInt32) -> UIColor {
            UIColor(red: CGFloat((h >> 16) & 0xFF) / 255, green: CGFloat((h >> 8) & 0xFF) / 255, blue: CGFloat(h & 0xFF) / 255, alpha: 1)
        }
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? ui(dark) : ui(light) })
    }
}

extension Verdict {
    var fill: Color {
        switch self {
        case .yes: Theme.green
        case .no: Color(hex: 0xC1272D)
        case .conditional: Theme.amberSoft
        case .unsure: Color(light: 0xE3E6E8, dark: 0x2A323B)
        }
    }
    var onFill: Color {
        switch self {
        case .yes, .no: .white
        case .conditional: Theme.amberInk
        case .unsure: Theme.ink
        }
    }
    /// Il cerchio con il simbolo: bianco sui fondi pieni, scuro su quelli chiari
    var badgeFill: Color {
        switch self {
        case .yes, .no: .white
        case .conditional: Theme.amber
        case .unsure: Theme.muted
        }
    }
    var badgeInk: Color {
        switch self {
        case .yes, .no: fill
        case .conditional, .unsure: .white
        }
    }
    var symbol: String {
        switch self {
        case .yes: "checkmark"
        case .no: "xmark"
        case .conditional: "exclamationmark"
        case .unsure: "questionmark"
        }
    }
    /// Il titolo spezzato a mano in righe: Titillium ha un'interlinea ampia, così le righe stanno strette
    var titleLines: [String] {
        switch self {
        case .yes: L("Yes, you can|enter").components(separatedBy: "|")
        case .no: L("No, don't|enter").components(separatedBy: "|")
        case .conditional: L("Yes, on one|condition").components(separatedBy: "|")
        case .unsure: [L("Not sure")]
        }
    }
    /// Versione breve per pillole e liste
    var short: String {
        switch self {
        case .yes: L("You can enter")
        case .no: L("Don't enter")
        case .conditional: L("On one condition")
        case .unsure: L("Not sure")
        }
    }
    var pillFill: Color {
        switch self {
        case .yes: Theme.greenSoft
        case .no: Color(light: 0xF8DADB, dark: 0x3D1A1C)
        case .conditional: Theme.amberSoft
        case .unsure: Color(light: 0xE3E6E8, dark: 0x2A323B)
        }
    }
    var pillInk: Color {
        switch self {
        case .yes: Theme.greenInk
        case .no: Color(light: 0x9E1F25, dark: 0xF59A96)
        case .conditional: Theme.amberInk
        case .unsure: Theme.ink
        }
    }
}

extension ZoneKind {
    /// Rosso del divieto, giallo del pass, verde della zona a basse emissioni
    var color: Color {
        switch self {
        case .restricted: Color(light: 0xC1272D, dark: 0xEF5B55)
        case .pass: Color(light: 0xD99A00, dark: 0xF2C14E)
        case .green: Color(light: 0x2B7A47, dark: 0x5CC27F)
        }
    }
    var symbol: String {
        switch self {
        case .restricted: "nosign"
        case .pass: "ticket"
        case .green: "leaf"
        }
    }
}
