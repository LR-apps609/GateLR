import SwiftUI

/// Il logo: cartello ZTL con la porta, sul tricolore
struct LogoMark: View {
    var size: CGFloat = 36
    var body: some View {
        Canvas { ctx, s in
            let u = s.width / 100
            let clip = Path(roundedRect: CGRect(origin: .zero, size: s), cornerRadius: 22 * u)
            ctx.clip(to: clip)
            ctx.fill(Path(CGRect(x: 0, y: 0, width: 34 * u, height: s.height)), with: .color(Color(hex: 0x1F9D55)))
            ctx.fill(Path(CGRect(x: 33 * u, y: 0, width: 34 * u, height: s.height)), with: .color(.white))
            ctx.fill(Path(CGRect(x: 66 * u, y: 0, width: 34 * u, height: s.height)), with: .color(Color(hex: 0xD32F2F)))
            ctx.fill(Path(ellipseIn: CGRect(x: 12 * u, y: 12 * u, width: 76 * u, height: 76 * u)), with: .color(.white))
            ctx.stroke(Path(ellipseIn: CGRect(x: 19 * u, y: 19 * u, width: 62 * u, height: 62 * u)), with: .color(Color(hex: 0xD32F2F)), lineWidth: 8 * u)
            var door = Path()
            door.move(to: CGPoint(x: 38 * u, y: 70 * u))
            door.addLine(to: CGPoint(x: 38 * u, y: 52 * u))
            door.addArc(center: CGPoint(x: 50 * u, y: 52 * u), radius: 12 * u, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            door.addLine(to: CGPoint(x: 62 * u, y: 70 * u))
            ctx.stroke(door, with: .color(Color(hex: 0x1B2128)), style: StrokeStyle(lineWidth: 7 * u, lineCap: .round))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// «GateLR» con il logo, come in testa a ogni schermata principale
struct Wordmark: View {
    var size: CGFloat = 24
    var body: some View {
        HStack(spacing: 10) {
            LogoMark(size: size * 1.5)
            (Text(verbatim: "Gate").foregroundStyle(Theme.ink) + Text(verbatim: "LR").foregroundStyle(Theme.brand))
                .font(Theme.display(size))
                // 2.3 (Dispositivi, iPhone SE con testo grande): mai a capo («GateL / R»)
                .lineLimit(1).fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("GateLR")
    }
}

struct SectionLabel: View {
    var text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(L(text).uppercased())
            .font(Theme.label(13))
            .tracking(1.1)
            .foregroundStyle(Theme.muted)
            .accessibilityAddTraits(.isHeader)
    }
}

struct CardBackground: ViewModifier {
    var radius: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .background(Theme.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Theme.line.opacity(0.6), lineWidth: 0.5))
    }
}
extension View {
    func card(_ radius: CGFloat = 16) -> some View { modifier(CardBackground(radius: radius)) }

    /// 2.3: il fondo del tema sotto la barra di stato, così chi scorre non finisce sotto l'ora e la batteria
    /// (Dispositivi, iPhone SE: la risposta e i chip di Viaggio sotto la barra di stato)
    func statusBarBackground(_ color: Color = Theme.ground) -> some View {
        overlay(alignment: .top) {
            color.frame(height: 0).ignoresSafeArea(edges: .top).allowsHitTesting(false).accessibilityHidden(true)
        }
    }
}

struct Pill: View {
    var text: String
    var fill: Color
    var ink: Color
    var body: some View {
        Text(text)
            .font(.app(size: 12, weight: .semibold))
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(fill, in: Capsule())
            .foregroundStyle(ink)
            .fixedSize()
    }
}

/// La risposta in breve (S-Risposta, taglia S): forma + parola + colore, piena come il blocco, uguale nei due temi
struct VerdictPill: View {
    var verdict: Verdict
    /// Regole da fonti non ufficiali: il titolo fisso detto con prudenza (un «sì» diventa «Controlla il cartello»)
    var unofficial = false
    /// 2.1: i varchi della zona; spenti con un «sì» la pillola dice «ZTL non attiva» (la parola della RispostaFinale)
    var gatesOn = true
    var body: some View {
        // 1.19.0: un «sì» da fonte non ufficiale è giallo con il «?», mai verde
        RispostaChip(stato: RispostaFinale.decide(Answer(verdict: verdict, gatesOn: gatesOn, nextChange: nil), unofficial: unofficial).0)
    }
}

// MARK: 2.3 · Il componente «Risposta» (tavole S-Risposta, S-Movimento)

/// La forma della risposta, disegnata su una griglia di 48 come nelle tavole: disco con barra (Non entrare), rombo con
/// «!» (A una condizione), disco con spunta (Entra pure), cerchio con trattino (ZTL non attiva), rombo con «?»
/// (Controlla il cartello), anello tratteggiato con «?» (posto che non conosciamo), anello con il punto (Fuori dalla ZTL).
/// Si legge anche senza colori (schermata di blocco monocromatica, daltonismo)
struct RispostaShape: View {
    var stato: Stato
    var size: CGFloat = 46
    /// Monocromatica (schermata di blocco): la forma nel colore del testo, il segno ritagliato
    var mono = false

    var body: some View {
        let fill = mono ? Color.clear : stato.fill
        let on = mono ? Color.primary : stato.onFill
        Canvas { ctx, s in
            let u = s.width / 48
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * u, y: y * u) }
            func circle(_ r: CGFloat, _ cx: CGFloat = 24, _ cy: CGFloat = 24) -> Path {
                Path(ellipseIn: CGRect(x: (cx - r) * u, y: (cy - r) * u, width: 2 * r * u, height: 2 * r * u))
            }
            var diamond = Path()
            diamond.move(to: pt(24, 2)); diamond.addLine(to: pt(46, 24)); diamond.addLine(to: pt(24, 46)); diamond.addLine(to: pt(2, 24))
            diamond.closeSubpath()
            func question(_ color: Color, _ fontSize: CGFloat) {
                let q = ctx.resolve(Text(verbatim: "?").font(.custom("TitilliumWeb-Black", fixedSize: fontSize * u)).foregroundStyle(color))
                ctx.draw(q, at: pt(24, 25), anchor: .center)
            }
            // Monocromatica: il segno «bucato» nella forma piena
            var mark = ctx
            if mono { mark.blendMode = .destinationOut }
            let markColor = mono ? Color.black : fill
            switch stato {
            case .nonEntrare:
                ctx.fill(circle(22), with: .color(on))
                mark.fill(Path(roundedRect: CGRect(x: 10 * u, y: 19 * u, width: 28 * u, height: 10 * u), cornerRadius: 2 * u), with: .color(markColor))
            case .entraPure:
                ctx.fill(circle(22), with: .color(on))
                var tick = Path()
                tick.move(to: pt(13, 25)); tick.addLine(to: pt(20, 32)); tick.addLine(to: pt(35, 16))
                mark.stroke(tick, with: .color(markColor), style: StrokeStyle(lineWidth: 5.5 * u, lineCap: .round, lineJoin: .round))
            case .condizione:
                ctx.fill(diamond, with: .color(on))
                var bar = Path()
                bar.move(to: pt(24, 13)); bar.addLine(to: pt(24, 27))
                mark.stroke(bar, with: .color(markColor), style: StrokeStyle(lineWidth: 5.5 * u, lineCap: .round))
                mark.fill(circle(3.2, 24, 34), with: .color(markColor))
            case .controllaCartello:
                ctx.fill(diamond, with: .color(on))
                let q = mark.resolve(Text(verbatim: "?").font(.custom("TitilliumWeb-Black", fixedSize: 26 * u)).foregroundStyle(markColor))
                mark.draw(q, at: pt(24, 25), anchor: .center)
            case .ztlNonAttiva:
                ctx.stroke(circle(20), with: .color(on), lineWidth: 4.5 * u)
                var dash = Path()
                dash.move(to: pt(14, 24)); dash.addLine(to: pt(34, 24))
                ctx.stroke(dash, with: .color(on), style: StrokeStyle(lineWidth: 5 * u, lineCap: .round))
            case .nonCoperto:
                ctx.stroke(circle(20), with: .color(on), style: StrokeStyle(lineWidth: 3.5 * u, dash: [6 * u, 5 * u]))
                question(on, 24)
            case .fuoriZTL:
                ctx.stroke(circle(20), with: .color(on), lineWidth: 4.5 * u)
                ctx.fill(circle(6), with: .color(on))
            }
        }
        .frame(width: size, height: size)
        .compositingGroup()
        .accessibilityHidden(true)
    }
}

/// Le parole della risposta in maiuscolo, a capo SOLO fra una parola e l'altra: una parola troppo lunga per la riga si
/// stringe da sola (fino a «minScale»), mai spezzata a metà né tagliata con «…» (Dynamic Type fino ad AX5)
struct AnswerWords: View {
    var text: String
    var font: Font
    var color: Color
    var minScale: CGFloat = 0.45
    @ScaledMetric private var gap: CGFloat
    @ScaledMetric private var lineGap: CGFloat

    init(_ text: String, font: Font, color: Color, baseSize: CGFloat = 40, minScale: CGFloat = 0.45) {
        self.text = text; self.font = font; self.color = color; self.minScale = minScale
        _gap = ScaledMetric(wrappedValue: baseSize * 0.24, relativeTo: .largeTitle)
        _lineGap = ScaledMetric(wrappedValue: -baseSize * 0.22, relativeTo: .largeTitle)
    }

    static func words(_ text: String) -> [String] {
        text.uppercased(with: Locale.current).split(separator: " ").map(String.init)
    }

    var body: some View {
        let words = Self.words(text)
        WordFlow(gap: gap, lineGap: lineGap) {
            ForEach(Array(words.enumerated()), id: \.offset) { _, w in
                Text(verbatim: w).font(font).foregroundStyle(color)
                    .lineLimit(1).minimumScaleFactor(minScale).allowsTightening(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: text))
    }
}

/// Le parole una accanto all'altra, a capo quando la riga è piena; una parola più larga della riga riceve la riga
/// intera (e si stringe con minimumScaleFactor)
struct WordFlow: Layout {
    var gap: CGFloat
    var lineGap: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let f = frames(width: proposal.width ?? .infinity, subviews: subviews)
        return CGSize(width: f.map(\.maxX).max() ?? 0, height: f.map(\.maxY).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (v, f) in zip(subviews, frames(width: bounds.width, subviews: subviews)) {
            v.place(at: CGPoint(x: bounds.minX + f.minX, y: bounds.minY + f.minY), proposal: ProposedViewSize(width: f.width, height: f.height))
        }
    }

    private func frames(width: CGFloat, subviews: Subviews) -> [CGRect] {
        let sizes = subviews.map { v -> CGSize in
            let ideal = v.sizeThatFits(.unspecified)
            return ideal.width <= width ? ideal : v.sizeThatFits(ProposedViewSize(width: width, height: nil))
        }
        return Self.arrange(sizes, width: width, gap: gap, lineGap: lineGap)
    }

    /// Le parole in righe: a capo solo fra una parola e l'altra; nessuna parola più larga della riga
    static func arrange(_ sizes: [CGSize], width: CGFloat, gap: CGFloat, lineGap: CGFloat) -> [CGRect] {
        var out: [CGRect] = []
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        for size in sizes {
            let w = min(size.width, width)
            if x > 0, x + gap + w > width {
                x = 0; y += row + lineGap; row = 0
            }
            let px = x > 0 ? x + gap : 0
            out.append(CGRect(x: px, y: y, width: w, height: size.height))
            x = px + w
            row = max(row, size.height)
        }
        return out
    }
}

/// Il blocco della risposta (S-Risposta, taglie L e M): pieno del colore dello stato, la forma, la parola in maiuscolo
/// (Titillium 900, almeno 34 punti), la riga della zona e la frase. Identico di giorno e di notte. «Non conosciamo questo
/// posto» non ha pieno: contorno tratteggiato sul fondo. Per VoiceOver un solo elemento, letto per primo
struct RispostaBlock: View {
    enum Size { case large, medium, car }
    var stato: Stato
    /// La parola (titolo fisso dello stato)
    var title: String
    /// «Firenze · Settore B · fino alle 20:00»
    var line: String? = nil
    /// La frase sotto: il motivo del «?», la condizione, il varco davanti
    var detail: String? = nil
    /// Detto solo da VoiceOver, alla fine («Per Golf diesel Euro 5, adesso»)
    var spokenExtra: String? = nil
    var size: Size = .large
    var identifier = "risposta.block"
    @Environment(\.dynamicTypeSize) private var typeSize

    private var wordSize: CGFloat { size == .car ? 64 : size == .medium ? 34 : 40 }
    /// Quanto può stringersi una parola troppo lunga per la riga, invece di andare a capo a metà (GraficaTests la prova
    /// con la parola più lunga di ogni lingua ad AX5)
    static let minScale: CGFloat = 0.45

    /// Quello che VoiceOver legge, in un colpo solo: «Non entrare. Firenze · Settore B · fino alle 20:00. …»
    static func spoken(title: String, line: String?, detail: String?, extra: String?) -> String {
        [title, line, detail, extra].compactMap { $0?.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            .map { $0.hasSuffix(".") ? String($0.dropLast()) : $0 }.joined(separator: ". ") + "."
    }

    var body: some View {
        let on = stato.onFill
        // Alle misure di accessibilità la forma va sopra la parola: la parola ha tutta la riga
        let stacked = typeSize.isAccessibilitySize || size == .car
        VStack(alignment: .leading, spacing: 10) {
            let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(alignment: .top, spacing: 14))
            layout {
                RispostaShape(stato: stato, size: size == .car ? 72 : 46)
                AnswerWords(title, font: Theme.answerWord(wordSize, car: size == .car), color: on, baseSize: wordSize,
                            minScale: Self.minScale)
                    // 2.0.1: dove sta la parola, per il segno dei test dell'interfaccia in Adesso (VarcoView)
                    .anchorPreference(key: AnswerWordBounds.self, value: .bounds) { $0 }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, stacked ? 0 : 2)
            }
            if let line, !line.isEmpty {
                Text(verbatim: line).font(Theme.answerLine(size == .car ? 24 : 20)).foregroundStyle(on)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let detail, !detail.isEmpty {
                Text(verbatim: detail).font(.app(size: size == .car ? 20 : 16, weight: .semibold)).foregroundStyle(on)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(stato.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
        .overlay {
            if stato.dashed {
                RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                    .strokeBorder(Theme.muted, style: StrokeStyle(lineWidth: 3, dash: [9, 6]))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: Self.spoken(title: title, line: line, detail: detail, extra: spokenExtra)))
        .accessibilityAddTraits([.isHeader, .isStaticText])
        .accessibilityIdentifier(identifier)
        .accessibilitySortPriority(10)
    }
}

/// 2.0.1: la cornice della parola della risposta nel blocco (il primo blocco della pagina che la chiede)
struct AnswerWordBounds: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}

/// La risposta in piccolo (S-Risposta, taglia S): pillola piena con la forma e la parola
struct RispostaChip: View {
    var stato: Stato
    var title: String? = nil
    var body: some View {
        HStack(spacing: 6) {
            RispostaShape(stato: stato, size: 18)
            Text(verbatim: title ?? stato.word.title)
        }
        .font(.app(size: 13, weight: .heavy))
        .lineLimit(1)
        .padding(.leading, 6).padding(.trailing, 11).padding(.vertical, 5)
        .foregroundStyle(stato.onFill)
        .background(stato.fill, in: Capsule())
        .overlay { if stato.dashed { Capsule().strokeBorder(Theme.muted, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])) } }
        .fixedSize()
        .accessibilityElement(children: .combine)
    }
}

/// Il pannello LED come lo vedrai al varco (S-Risposta, «Regole del pannello LED»): luce neutra bianco caldo su nero,
/// sempre sotto la risposta e più piccolo. Il testo viene dal motore (varchi accesi o no), mai dalla risposta. Si gira
/// solo quando cambia (400 ms); con «Riduci movimento» non si muove
struct GateLEDPanel: View {
    var text: String
    var caption: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: String?
    @State private var angle = 0.0
    @State private var flipping = false
    private static let uiTest = ProcessInfo.processInfo.arguments.contains("-uitest")
    private static let settledWord = "settled", movingWord = "moving"

    var body: some View {
        HStack(spacing: 14) {
            Text(verbatim: shown ?? text)
                .font(Theme.led(16)).tracking(1.9)
                .foregroundStyle(Tokens.led.color)
                .shadow(color: Color(hex: 0xFFD68C).opacity(0.7), radius: 4)
                .lineLimit(1).minimumScaleFactor(0.6)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Tokens.ledGround.color, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Tokens.ledFrame.color, lineWidth: 3))
                .rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
                .fixedSize()
                .accessibilityElement()
                .accessibilityLabel(Text(verbatim: text))
                // Solo nel giro delle foto: «settled» quando il pannello è fermo (la foto aspetta questo)
                .accessibilityIdentifier("gate.panel")
                .accessibilityValue(Text(verbatim: Self.uiTest ? (!flipping && (shown ?? text) == text ? Self.settledWord : Self.movingWord) : ""))
            if let caption {
                Text(verbatim: caption).font(.app(size: 14, weight: .medium)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
        .onAppear { shown = text }
        .onChange(of: text) { _, new in flip(to: new) }
    }

    private func flip(to new: String) {
        guard !reduceMotion else { shown = new; return }
        flipping = true
        withAnimation(.easeIn(duration: 0.2)) { angle = 90 } completion: {
            shown = new
            angle = -90
            withAnimation(.easeOut(duration: 0.2)) { angle = 0 } completion: { flipping = false }
        }
        // Se il completamento non arriva (vista sparita a metà), il pannello torna dritto
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            guard flipping else { return }
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) { shown = text; angle = 0; flipping = false }
        }
    }
}

/// Il riquadro grande con la risposta
struct VerdictCard: View {
    var answer: Answer
    var heading: String
    var source: Source
    var since: Date? = nil
    var onWhy: (() -> Void)? = nil

    var body: some View {
        // 2.3: i colori e la forma dallo stato della RispostaFinale (la ZTL non attiva ha la sua parola e il suo token)
        let stato = RispostaFinale.decide(answer, unofficial: !source.isOfficial).0
        let word = stato.word
        let ink = stato.onFill
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(heading.uppercased()).font(Theme.label(13)).tracking(1.1).opacity(0.9)
                Spacer()
                Pill(text: answer.gatesOn ? L("ZTL active") : L("ZTL not active"), fill: ink.opacity(0.16), ink: ink)
            }
            if !source.isOfficial { UnofficialBanner(source: source.unofficialSource) }
            HStack(spacing: 14) {
                RispostaShape(stato: stato, size: 46)
                AnswerWords(word.title, font: Theme.answerWord(34), color: ink, baseSize: 34, minScale: 0.6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .ignore)
                .accessibilityLabel(word.title)
                .accessibilityAddTraits(.isHeader)
            }
            Text(detail).font(.app(size: 16)).fixedSize(horizontal: false, vertical: true)
            if let next = answer.nextChange { countdown(to: next) }
            Rectangle().fill(ink.opacity(0.22)).frame(height: 1)
            HStack(alignment: .top) {
                // 1.20.1 «Dati»: «letto il» (quando abbiamo letto la fonte) e, sotto, «verificato il» (o «non verificato»,
                // «pagina del Comune cambiata»): non sono più la stessa data
                VStack(alignment: .leading, spacing: 4) {
                    // 2.3 (Dispositivi, testo grande): una sola riga che va a capo, mai «Comune di F…»
                    Label {
                        Text(verbatim: String(format: L("Read %@"), source.checkedOn.formatted(.dateTime.day().month())) + " · " + source.localizedAuthority)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: { Image(systemName: "doc.text.magnifyingglass") }
                    let engine = RuleEngine()
                    let trust = engine.trust(source)
                    Label(engine.verifiedShort(source), systemImage: trust == .verified ? "checkmark.seal" : trust == .read ? "person.crop.circle.badge.questionmark" : "exclamationmark.triangle")
                        .accessibilityIdentifier("verdict.verified")
                }
                .font(.app(size: 13)).opacity(0.92)
                Spacer()
                if let onWhy {
                    Button(action: onWhy) {
                        HStack(spacing: 3) { Text("Why?"); Image(systemName: "chevron.right").font(.app(size: 11, weight: .bold)) }
                    }
                    .font(.app(size: 14, weight: .semibold)).foregroundStyle(ink)
                    .accessibilityLabel("Why?")
                    .accessibilityHint("Shows the official source")
                }
            }
        }
        .padding(20)
        .foregroundStyle(ink)
        .background(stato.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
        .animation(.snappy, value: answer)
    }

    @ViewBuilder
    private func countdown(to next: Date) -> some View {
        let now = Date()
        let left = max(0, next.timeIntervalSince(now))
        let span = since.map { next.timeIntervalSince($0) } ?? 0
        VStack(alignment: .leading, spacing: 6) {
            if span > 0 {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(RispostaFinale.decide(answer, unofficial: !source.isOfficial).0.onFill.opacity(0.22))
                        Capsule().fill(RispostaFinale.decide(answer, unofficial: !source.isOfficial).0.onFill)
                            .frame(width: g.size.width * min(1, max(0.03, 1 - left / span)))
                    }
                }
                .frame(height: 6)
                .accessibilityHidden(true)
            }
            HStack {
                if let since { Text(String(format: L(answer.gatesOn ? "Active since %@" : "Not active since %@"), RuleEngine.format(since, .init(date: .omitted, time: .shortened)))) }
                Spacer()
                Text(String(format: L(answer.gatesOn ? "Ends in %@" : "Starts in %@"), Self.duration(left)))
            }
            .font(.app(size: 12.5, weight: .medium)).opacity(0.9).monospacedDigit()
        }
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let m = Int(seconds / 60), h = m / 60, d = h / 24
        if d >= 1 { return String(format: L("%lld d %lld h"), d, h % 24) }
        if h >= 1 { return String(format: L("%lld h %lld min"), h, m % 60) }
        return String(format: L("%lld min"), m)
    }

    private var detail: String {
        switch answer.verdict {
        case .yes(let r) where !source.isOfficial: L("Unofficial source: check the sign.") + " " + r
        case .yes(let r), .no(let r), .unsure(let r): r
        case .conditional(let r, let c): "\(r) \(c)"
        }
    }
}

/// «Fonte non ufficiale: verifica sempre il cartello al varco»: ben visibile (ambra pieno, testo scuro, triangolo)
/// ovunque si mostra una risposta per una zona con regole da fonti non ufficiali. Con il nome del sito, se c'è.
/// Niente da chiudere o nascondere: resta finché la zona non ha una fonte ufficiale.
struct UnofficialBanner: View {
    var source: UnofficialSource? = nil
    /// Una riga sola, per i riquadri piccoli (striscia della mappa, widget)
    var compact = false

    /// 2.3: il giallo pieno della risposta con l'inchiostro scuro (11,5:1), uguale di giorno e di notte
    static let fill = Tokens.condFill.color
    static let ink = Tokens.onCond.color

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.app(size: compact ? 13 : 16, weight: .bold))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: L("Unofficial source: always check the sign at the gate"))
                    .font(.app(size: compact ? 12 : 15, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                if let source, !compact {
                    Text(verbatim: String(format: L("Data from %@"), source.name))
                        .font(.app(size: 13, weight: .medium))
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(Self.ink)
        .padding(.horizontal, compact ? 10 : 12).padding(.vertical, compact ? 6 : 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Self.fill, in: RoundedRectangle(cornerRadius: compact ? 8 : 12, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("unofficial.banner")
    }
}

struct StatusBanner: View {
    var status: City.Status
    /// La città ha zone con regole da fonti non ufficiali: al posto di «Bozza: dalle fonti ufficiali…»
    var unofficial = false
    var body: some View {
        if unofficial {
            UnofficialBanner()
        } else if status != .verified {
            Label(L(status == .sample ? "Sample data, not real" : "Draft: from official sources, not yet reviewed by a person"),
                  systemImage: "exclamationmark.triangle.fill")
                .font(.app(size: 13, weight: .semibold))
                .foregroundStyle(Theme.amberInk)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.amberSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

/// Un pulsante largo, per le azioni principali
struct WideButton: View {
    var title: String
    var systemImage: String? = nil
    var prominent = true
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(L(title))
            }
            .font(.app(size: 15, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: Theme.Target.standard)
            // 2.3: chiaro su Notte, scuro su Giorno; mai rosso (S-Componenti)
            .background(prominent ? Theme.primary : Theme.raised, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
            .foregroundStyle(prominent ? Theme.onPrimary : Theme.ink)
        }
        .buttonStyle(.plain)
    }
}

/// Una pagina o un elenco ancora vuoti: un disegno fatto di simboli, una riga di spiegazione e un pulsante
struct EmptyStateView: View {
    var symbol: String
    var badge: String
    var tint: Color = Theme.blue
    var title: String
    var text: String
    var action: String
    var actionSymbol: String? = nil
    var perform: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(tint.opacity(0.12)).frame(width: 96, height: 96)
                Circle().strokeBorder(tint.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [4, 5])).frame(width: 118, height: 118)
                Image(systemName: symbol).font(.app(size: 38, weight: .semibold)).foregroundStyle(tint)
                Image(systemName: badge)
                    .font(.app(size: 15, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(tint, in: Circle())
                    .overlay(Circle().stroke(Theme.card, lineWidth: 3))
                    .offset(x: 36, y: 34)
            }
            .frame(height: 124)
            .accessibilityHidden(true)
            Text(L(title)).font(Theme.display(22)).foregroundStyle(Theme.ink).multilineTextAlignment(.center)
            Text(L(text)).font(.app(size: 14)).foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            WideButton(title: action, systemImage: actionSymbol, action: perform)
                .padding(.top, 4)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }
}
