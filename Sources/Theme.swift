import SwiftUI

// Lo stile della segnaletica italiana: rosso del divieto, blu dei pannelli, verde del «via libera».
enum Theme {
    static let ground = Color(hex: 0xF3F4F2)
    static let card = Color.white
    static let ink = Color(hex: 0x1B2128)
    static let muted = Color(hex: 0x5D6670)
    static let line = Color(hex: 0xE6E9E7)
    static let red = Color(hex: 0xC1272D)
    static let blue = Color(hex: 0x1F4E9E)
    static let blueSoft = Color(hex: 0xE2EAF6)
    static let green = Color(hex: 0x2B7A47)
    static let greenSoft = Color(hex: 0xDCEFE2)
    static let greenInk = Color(hex: 0x22653A)
    static let amber = Color(hex: 0x8A5A00)
    static let amberSoft = Color(hex: 0xFBECC8)
    static let amberInk = Color(hex: 0x5C3C00)

    /// Titoli: pesanti e stretti come i cartelli (Titillium Web quando sarà incluso nell'app)
    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

extension Verdict {
    var fill: Color {
        switch self {
        case .yes: Theme.green
        case .no: Theme.red
        case .conditional: Theme.amberSoft
        case .unsure: Color(hex: 0xE3E6E8)
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
}
