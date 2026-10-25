import SwiftUI

// Prototipo della nuova presentazione (GateLR 2.0, direzione «Notte»): colori, caratteri e i due segni del marchio,
// la barretta rossa e il pannello «VARCO» a matrice di punti che gira come un tabellone a palette.
// Si vede solo avviando l'app con -intro2 (vedi RootView); la presentazione attuale resta quella di Onboarding.swift.

enum Notte {
    static let navy = Color(hex: 0x0B1530)
    static let surface = Color(hex: 0x142049)
    static let line = Color(hex: 0x24315E)
    static let text = Color(hex: 0xF2F4FA)
    static let muted = Color(hex: 0xA9B3D1)
    static let action = Color(hex: 0xE5322D)
    /// Le luci dei varchi: solo per lo stato dei varchi, mai per altro
    static let ledRed = Color(hex: 0xFF4D3D)
    static let ledAmber = Color(hex: 0xFFB21E)
    static let ledGreen = Color(hex: 0x3BE07A)
    /// Il gesso del percorso buono
    static let chalk = Color(hex: 0xF4F1E8)

    /// Titillium Web (Resources/Fonts, OFL)
    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .black, .heavy: name = "TitilliumWeb-Black"
        case .bold: name = "TitilliumWeb-Bold"
        case .semibold, .medium: name = "TitilliumWeb-SemiBold"
        default: name = "TitilliumWeb-Regular"
        }
        return .custom(name, size: size).leading(.tight)
    }
    /// DotGothic16 (Resources/Fonts, OFL): il carattere a punti dei pannelli
    static func dots(_ size: CGFloat) -> Font { .custom("DotGothic16-Regular", size: size) }
}

/// La barretta rossa del logo: sopra i titoli
struct RedBar: View {
    var width: CGFloat = 34
    var body: some View {
        Capsule().fill(Notte.action).frame(width: width, height: 6).accessibilityHidden(true)
    }
}

/// L'avanzamento: tre barrette che si riempiono, una per pagina
struct IntroProgress: View {
    var page: Int
    /// Riempimento della barretta della pagina attuale, da 0 a 1
    var fill: Double
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Notte.line)
                        Capsule().fill(Notte.action)
                            .frame(width: g.size.width * (i < page ? 1 : i == page ? fill : 0))
                    }
                }
                .frame(width: 34, height: 6)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: "\(min(page + 1, 3))/3"))
    }
}

/// Titolo con la barretta rossa sopra
struct IntroTitle: View {
    var text: String
    var size: CGFloat = 34
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RedBar()
            Text(text).font(Notte.font(size, .bold)).foregroundStyle(Notte.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Il pulsante rosso pieno
struct IntroButton: View {
    var title: String
    var systemImage: String? = nil
    var identifier: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 17, weight: .bold)) }
                Text(title).font(Notte.font(20, .bold))
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(.white)
            .background(Notte.action, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Notte.action.opacity(0.45), radius: 18, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

// MARK: Pannello «VARCO»

/// Uno stato del pannello: testo (quello vero del cartello, in italiano) e luce
struct LEDState: Equatable {
    enum Light { case red, amber, green }
    var text: String
    var light: Light
    /// Spento a metà: il pannello prima che il varco si accenda
    var dim = false

    var color: Color {
        switch light {
        case .red: Notte.ledRed
        case .amber: Notte.ledAmber
        case .green: Notte.ledGreen
        }
    }

    static let idle = LEDState(text: "Z T L", light: .red, dim: true)
    static let active = LEDState(text: "VARCO ATTIVO", light: .red)
    static let soon = LEDState(text: "ATTIVO TRA 15'", light: .amber)
    static let off = LEDState(text: "VARCO NON ATTIVO", light: .green)
    static var arrived: LEDState { LEDState(text: L("ARRIVED · NO FINE"), light: .green) }
}

/// Il pannello nero a punti. Quando lo stato cambia gira sull'asse orizzontale come una paletta;
/// con «Riduci movimento» il testo cambia in dissolvenza.
struct LEDPanel: View {
    var state: LEDState
    var size: CGFloat = 20
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: LEDState
    @State private var angle: Double = 0

    init(state: LEDState, size: CGFloat = 20) {
        self.state = state
        self.size = size
        _shown = State(initialValue: state)
    }

    var body: some View {
        face(shown)
            .rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0), anchor: .center, perspective: 0.6)
            .onChange(of: state) { _, new in flip(to: new) }
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: shown.text))
    }

    private func flip(to new: LEDState) {
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.35)) { shown = new }
            return
        }
        withAnimation(.easeIn(duration: 0.16)) { angle = 90 } completion: {
            shown = new
            angle = -90
            withAnimation(.spring(response: 0.42, dampingFraction: 0.5)) { angle = 0 }
        }
    }

    private func face(_ s: LEDState) -> some View {
        let c = s.color.opacity(s.dim ? 0.35 : 1)
        return Text(verbatim: s.text)
            .font(Notte.dots(size))
            .foregroundStyle(c)
            .shadow(color: s.dim ? .clear : s.color.opacity(0.9), radius: size * 0.25)
            .shadow(color: s.dim ? .clear : s.color.opacity(0.6), radius: size * 0.7)
            .lineLimit(1)
            .padding(.horizontal, size * 0.7).padding(.vertical, size * 0.45)
            .background {
                RoundedRectangle(cornerRadius: size * 0.3, style: .continuous).fill(Color.black)
                    .overlay(DotGrid(pitch: max(3, size * 0.16)).opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            }
            .overlay {
                // La fessura tra le due metà della paletta
                Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
            }
            .overlay(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous).stroke(Color(hex: 0x30364A), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
    }
}

/// La trama a punti dei pannelli luminosi
struct DotGrid: View {
    var pitch: CGFloat
    var body: some View {
        Canvas { ctx, size in
            var p = Path()
            var y = pitch / 2
            while y < size.height {
                var x = pitch / 2
                while x < size.width {
                    p.addEllipse(in: CGRect(x: x - 0.6, y: y - 0.6, width: 1.2, height: 1.2))
                    x += pitch
                }
                y += pitch
            }
            ctx.fill(p, with: .color(Color.white.opacity(0.10)))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
