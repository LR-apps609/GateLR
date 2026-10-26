import SwiftUI

// La prima pagina 2.0 («Varco», VarcoView): la risposta del motore delle regole detta come sul pannello del varco
// e il pannello stesso come un oggetto vero. Usati anche dalla striscia di mappa in cima alla pagina (Home2Map).

// MARK: La risposta per la pagina

/// La risposta del motore delle regole detta come sul pannello: colore, frase breve, ora del prossimo cambio
struct Home2Answer: Equatable {
    enum Mood: Equatable {
        case red, green, amber
        var color: Color {
            switch self {
            case .red: Notte.ledRed
            case .green: Notte.ledGreen
            case .amber: Notte.ledAmber
            }
        }
        var hex: UInt32 {
            switch self {
            case .red: 0xFF4D3D
            case .green: 0x3BE07A
            case .amber: 0xFFB21E
            }
        }
    }

    var mood: Mood
    var headline: String
    var timeLabel: String?
    var time: String?
    /// Il giorno, se il cambio non è oggi
    var day: String?
    var zoneLine: String
    var panel: GatePanelState
    var city: City?

    static func == (l: Home2Answer, r: Home2Answer) -> Bool {
        l.mood == r.mood && l.headline == r.headline && l.time == r.time && l.panel == r.panel && l.zoneLine == r.zoneLine
    }

    init(_ check: PlaceCheck, now: Date) {
        zoneLine = check.zoneLine
        city = check.hits.first?.city
        switch check.kind {
        case .closed:
            mood = .red; headline = L("Don't enter."); panel = GatePanelState(lines: ["VARCO", "ATTIVO"], mood: .red)
        case .open:
            mood = .green; headline = L("Drive in."); panel = GatePanelState(lines: ["VARCO", "NON ATTIVO"], mood: .green)
        case .outside:
            mood = .green; headline = L("Easy arrival."); panel = GatePanelState(lines: ["FUORI", "ZTL"], mood: .green)
        case .conditional:
            mood = .amber; headline = L("On one condition."); panel = GatePanelState(lines: ["VARCO", "ATTIVO"], mood: .amber)
        case .unsure:
            mood = .amber; headline = L("Check the sign."); panel = GatePanelState(lines: ["VARCO", "ATTIVO"], mood: .amber)
        case .pedestrian:
            mood = .red; headline = L("Pedestrian area."); panel = GatePanelState(lines: ["AREA", "PEDONALE"], mood: .red)
        }
        if check.kind == .pedestrian {
            timeLabel = L("At any time"); time = nil
        } else if let answer = check.answer, let next = answer.nextChange {
            timeLabel = answer.gatesOn ? L("Gates off at") : L("Gates on at")
            time = RuleEngine.format(next, .init(date: .omitted, time: .shortened))
            day = RuleEngine.rome.isDate(next, inSameDayAs: now) ? nil : RuleEngine.format(next, .dateTime.weekday(.wide))
        }
    }
}

/// Lo stato del pannello: due righe di testo vero (in italiano, come sui cartelli) e la luce
struct GatePanelState: Equatable {
    var lines: [String]
    var mood: Home2Answer.Mood
}

// MARK: Il pannello come oggetto

/// Il pannello del varco come un oggetto vero: cornice di metallo spazzolato con quattro viti, schermo nero a punti
/// che si accendono riga per riga, riflesso del vetro, palo corto e la luce che si spande intorno.
/// Quando lo stato cambia lo schermo gira come una paletta (con un colpo di vibrazione).
struct GatePanelObject: View {
    var panel: GatePanelState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: GatePanelState?
    @State private var angle = 0.0
    /// Quante righe di punti sono accese (da 0 a rows)
    @State private var lit = 0
    private static let rows = 16

    var body: some View {
        let s = shown ?? panel
        VStack(spacing: 0) {
            ZStack {
                // La luce che si spande sulla scena dietro
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(s.mood.color)
                    .frame(width: 300, height: 150)
                    .blur(radius: 50)
                    .opacity(0.45 * Double(lit) / Double(Self.rows))
                bezel(s)
            }
            pole(s)
        }
        .sensoryFeedback(.impact(weight: .heavy, intensity: 0.9), trigger: panel)
        .onAppear {
            shown = panel
            light()
        }
        .onChange(of: panel) { _, new in flip(to: new) }
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: s.lines.joined(separator: " ")))
    }

    private func bezel(_ s: GatePanelState) -> some View {
        ZStack {
            // Metallo spazzolato con luce dall'alto
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x8A93A8), Color(hex: 0x4A5266), Color(hex: 0x2A3042), Color(hex: 0x5A6378)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(LinearGradient(colors: [.white.opacity(0.65), .white.opacity(0.08), .black.opacity(0.5)],
                                               startPoint: .top, endPoint: .bottom), lineWidth: 1.5))
            screws
            screen(s)
                .padding(16)
                .rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0), anchor: .center, perspective: 0.5)
        }
        .frame(width: 270, height: 140)
        .shadow(color: .black.opacity(0.55), radius: 18, y: 14)
        .shadow(color: s.mood.color.opacity(0.35 * Double(lit) / Double(Self.rows)), radius: 26)
    }

    private var screws: some View {
        GeometryReader { g in
            ForEach(0..<4, id: \.self) { i in
                Screw(angle: Double(i) * 37 + 20)
                    .position(x: i % 2 == 0 ? 9 : g.size.width - 9, y: i < 2 ? 9 : g.size.height - 9)
            }
        }
    }

    private func screen(_ s: GatePanelState) -> some View {
        let color = s.mood.color
        return ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color(hex: 0x05070C))
            DotGrid(pitch: 4).opacity(0.9)
            VStack(spacing: 2) {
                ForEach(s.lines, id: \.self) { line in
                    Text(verbatim: line)
                        .font(Notte.dots(30))
                        .foregroundStyle(color)
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .shadow(color: color.opacity(0.9), radius: 3)
                        .shadow(color: color.opacity(0.6), radius: 10)
                }
            }
            .padding(.horizontal, 8)
            // I punti si accendono a righe, dall'alto in basso
            .mask(alignment: .top) {
                GeometryReader { g in
                    Rectangle().frame(height: g.size.height * Double(lit) / Double(Self.rows))
                }
            }
            // La trama a punti sopra il testo: sembra fatto di LED
            DotGrid(pitch: 3).opacity(0.35).blendMode(.multiply)
            // Il vetro: riflesso in diagonale e un filo di luce in alto
            LinearGradient(stops: [.init(color: .white.opacity(0.16), location: 0), .init(color: .white.opacity(0.04), location: 0.45),
                                   .init(color: .clear, location: 0.46), .init(color: .clear, location: 1)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .allowsHitTesting(false)
            // La fessura della paletta
            Rectangle().fill(Color.black.opacity(0.7)).frame(height: 1.5)
        }
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.black.opacity(0.8), lineWidth: 2))
    }

    private func pole(_ s: GatePanelState) -> some View {
        ZStack(alignment: .bottom) {
            // L'ombra a terra e la luce che ci cade sopra
            Ellipse().fill(s.mood.color.opacity(0.35 * Double(lit) / Double(Self.rows))).frame(width: 160, height: 26).blur(radius: 14)
            Ellipse().fill(Color.black.opacity(0.45)).frame(width: 60, height: 10).blur(radius: 4)
            Rectangle()
                .fill(LinearGradient(colors: [Color(hex: 0x3A4256), Color(hex: 0x9AA3B8), Color(hex: 0x4A5266), Color(hex: 0x262B3A)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 12, height: 74)
                .padding(.bottom, 4)
        }
        .frame(height: 84)
    }

    /// Le righe di punti che si accendono una dopo l'altra (tutte insieme con «Riduci movimento»)
    private func light() {
        if reduceMotion { lit = Self.rows; return }
        lit = 0
        Task { @MainActor in
            for i in 1...Self.rows {
                try? await Task.sleep(for: .milliseconds(28))
                lit = i
            }
        }
    }

    /// La paletta: metà giro, cambia la faccia, l'altra metà con un piccolo rimbalzo; poi i punti si riaccendono
    private func flip(to new: GatePanelState) {
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.35)) { shown = new }
            return
        }
        withAnimation(.easeIn(duration: 0.18)) { angle = 90 } completion: {
            shown = new
            angle = -90
            lit = 0
            withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { angle = 0 }
            light()
        }
    }
}

/// Una vite a croce nella cornice
private struct Screw: View {
    var angle: Double
    var body: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [Color(hex: 0xC9CFDC), Color(hex: 0x5A6276)], center: .topLeading, startRadius: 0, endRadius: 8))
            Circle().stroke(Color.black.opacity(0.5), lineWidth: 0.5)
            Rectangle().fill(Color.black.opacity(0.55)).frame(width: 6, height: 1.2).rotationEffect(.degrees(angle))
            Rectangle().fill(Color.black.opacity(0.55)).frame(width: 6, height: 1.2).rotationEffect(.degrees(angle + 90))
        }
        .frame(width: 9, height: 9)
    }
}
