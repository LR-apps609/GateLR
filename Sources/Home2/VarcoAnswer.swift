import SwiftUI

// La prima pagina 2.0 («Varco», VarcoView): la risposta del motore delle regole detta come sul pannello del varco
// e il pannello stesso come un oggetto vero. Usati anche dalla striscia di mappa in cima alla pagina (Home2Map).

// MARK: La risposta per la pagina

/// La risposta del motore delle regole detta come sul pannello: colore, frase breve, ora del prossimo cambio
struct Home2Answer: Equatable {
    enum Mood: Hashable, CaseIterable {
        /// «neutral» (1.19.0): fuori copertura, non sappiamo. Né verde né giallo: un contorno grigio-azzurro
        case red, green, amber, neutral
        var color: Color {
            switch self {
            case .red: Notte.ledRed
            case .green: Notte.ledGreen
            case .amber: Notte.ledAmber
            case .neutral: Notte.muted
            }
        }
        var hex: UInt32 {
            switch self {
            case .red: 0xFF4D3D
            case .green: 0x3BE07A
            case .amber: 0xFFB21E
            case .neutral: 0xA9B3D1
            }
        }
    }

    var mood: Mood
    var headline: String
    /// La frase sotto il titolo: la condizione («a una condizione:») o il motivo del dubbio, sempre in vista, non solo
    /// dietro «Perché?»
    var detail: String?
    var timeLabel: String?
    var time: String?
    /// Il giorno, se il cambio non è oggi
    var day: String?
    var zoneLine: String
    var panel: GatePanelState
    var city: City?
    /// Le regole della zona vengono solo da fonti non ufficiali: il titolo si dice con prudenza e sopra c'è l'avviso
    var unofficial = false
    var unofficialSource: UnofficialSource?

    static func == (l: Home2Answer, r: Home2Answer) -> Bool {
        l.mood == r.mood && l.headline == r.headline && l.detail == r.detail && l.time == r.time && l.panel == r.panel && l.zoneLine == r.zoneLine
            && l.unofficial == r.unofficial
    }

    init(_ check: PlaceCheck, now: Date) {
        zoneLine = check.zoneLine
        city = check.city
        unofficial = check.unofficial
        unofficialSource = check.unofficial ? check.zone?.source.unofficialSource : nil
        let gatesOn = check.answer?.gatesOn ?? false
        // Prima in variabili locali: il pannello si fa dal colore, prima che la struttura sia tutta pronta
        let m: Mood, h: String
        switch check.kind {
        case .closed:
            m = .red; h = L("Don't enter.")
        case .open:
            // Fonte non ufficiale: mai verde (1.19.0). Giallo con il «?», «Probabilmente sì · fonte non ufficiale: controlla il cartello»
            m = check.hedged ? .amber : .green; h = L("Drive in.")
        case .outside:
            m = .green; h = L("Easy arrival.")
        case .uncovered:
            m = .neutral; h = L("We don't know this place.")
        case .conditional:
            m = .amber; h = L("You can enter, on one condition:")
        case .unsure:
            m = .amber; h = L("Check the sign.")
        case .pedestrian:
            m = .red; h = L("Pedestrian area.")
        }
        mood = m; headline = h
        panel = GatePanelState.make(kind: check.kind, gatesOn: gatesOn, mood: m)
        switch check.answer?.verdict {
        case .conditional(_, let condition)? where check.kind == .conditional: detail = condition
        case .unsure(let reason)? where check.kind == .unsure: detail = reason
        default: detail = nil
        }
        if check.kind == .uncovered { detail = L("We don't know the ZTLs of this place. Check the signs at the entrance.") }
        // Fonte non ufficiale: parole più prudenti; il «sì» anche giallo, con l'invito a guardare il cartello
        if unofficial {
            if check.kind == .closed { headline = L("Probably not.") }
            if check.kind == .open { headline = L("Probably yes."); detail = L("Unofficial source: check the sign.") }
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

    /// 1.19.0: il TESTO dice lo stato vero dei varchi (answer.gatesOn), con la dicitura ufficiale dei pannelli
    /// «ZTL ATTIVA» / «ZTL NON ATTIVA» (docs/parole.md); il COLORE dice la risposta. Varchi accesi ma puoi entrare
    /// (elettrica, moto esente, permesso, zona verde ammessa): verde «ZTL ATTIVA · SEI ESENTE». Mai «NON ATTIVA» a
    /// varchi accesi né «ATTIVA» a varchi spenti (prima «VARCO NON ATTIVO» per ogni «sì», «VARCO ATTIVO» per ogni dubbio)
    static func make(kind: PlaceCheck.Kind, gatesOn: Bool, mood: Home2Answer.Mood) -> GatePanelState {
        switch kind {
        case .pedestrian: return GatePanelState(lines: ["AREA", "PEDONALE"], mood: mood)
        case .outside: return GatePanelState(lines: ["FUORI", "ZTL"], mood: mood)
        case .uncovered: return GatePanelState(lines: ["ZONA", "NON COPERTA"], mood: mood)
        case .open where gatesOn: return GatePanelState(lines: ["ZTL ATTIVA", "SEI ESENTE"], mood: mood)
        case .open, .closed, .conditional, .unsure:
            return GatePanelState(lines: gatesOn ? ["ZTL", "ATTIVA"] : ["ZTL", "NON ATTIVA"], mood: mood)
        }
    }
}

// MARK: Il pannello come oggetto

/// Il pannello del varco come un oggetto vero: cornice di metallo spazzolato con quattro viti, schermo nero a punti
/// che si accendono riga per riga, riflesso del vetro, palo corto e la luce che si spande intorno.
/// Quando lo stato cambia lo schermo gira come una paletta (con un colpo di vibrazione).
struct GatePanelObject: View {
    var panel: GatePanelState
    /// Il palo con l'ombra a terra; senza (scheda Varco con un posto scelto) solo la scatola dei punti luminosi, più bassa
    var showsPole = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: GatePanelState?
    @State private var angle = 0.0
    /// Quanta parte dello schermo è accesa, dall'alto (da 0 a 1). Di base accesa: se l'accensione animata non parte
    /// (nella 1.16.0 il pannello verde dopo una ricerca restava spento) il pannello si legge comunque
    @State private var lit = 1.0

    var body: some View {
        let s = shown ?? panel
        VStack(spacing: 0) {
            ZStack {
                // La luce che si spande sulla scena dietro
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(s.mood.color)
                    .frame(width: 300, height: 150)
                    .blur(radius: 50)
                    .opacity(0.45 * lit)
                bezel(s)
            }
            if showsPole { pole(s) }
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
        .shadow(color: s.mood.color.opacity(0.35 * lit), radius: 26)
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
                    Rectangle().frame(height: g.size.height * lit)
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
            Ellipse().fill(s.mood.color.opacity(0.35 * lit)).frame(width: 160, height: 26).blur(radius: 14)
            Ellipse().fill(Color.black.opacity(0.45)).frame(width: 60, height: 10).blur(radius: 4)
            Rectangle()
                .fill(LinearGradient(colors: [Color(hex: 0x3A4256), Color(hex: 0x9AA3B8), Color(hex: 0x4A5266), Color(hex: 0x262B3A)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 12, height: 74)
                .padding(.bottom, 4)
        }
        .frame(height: 84)
    }

    /// I punti che si accendono dall'alto in basso (tutti insieme con «Riduci movimento»); alla fine sempre accesi
    private func light() {
        if reduceMotion { lit = 1; return }
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { lit = 0 }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.45)) { lit = 1 }
        }
        // In ogni caso, poco dopo, tutto acceso
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { if lit < 1 { lit = 1 } }
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
