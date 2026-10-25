import SwiftUI

/// Terza pagina, «Impara con GateLR»: il cartello della ZTL disegnato, una riga di scansione lo legge e il testo
/// italiano diventa la spiegazione nella lingua del telefono; poi passano altri cartelli con il loro significato.
struct IntroSignsSlide: View {
    var next: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scan: CGFloat = 0
    @State private var scanning = false
    @State private var translated = 0          // quante righe del cartello sono già spiegate
    @State private var card = -1               // il cartello che scorre sotto

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            IntroTitle(text: L("Learn with GateLR"))
                .padding(.top, 64)
            Text(L("Point the camera at the sign: GateLR explains it."))
                .font(Notte.font(17)).foregroundStyle(Notte.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
            Spacer(minLength: 16)
            ztlSign.frame(maxWidth: .infinity)
            Spacer(minLength: 16)
            carousel.frame(height: 104)
            Spacer(minLength: 16)
            IntroButton(title: L("Continue"), identifier: "intro2.next3", action: next)
        }
        .padding(.horizontal, 20).padding(.bottom, 12)
        .task { await play() }
        .task {
            guard IntroAutoplay.on else { return }
            try? await Task.sleep(for: .milliseconds(9200))
            next()
        }
    }

    // MARK: Il cartello ZTL

    private let lines: [(sign: String, meaning: String)] = [
        ("ZONA TRAFFICO LIMITATO", "Cars can't drive in"),
        ("7.30 – 20.00 FERIALI", "Mon–Sat, 7:30 am to 8 pm"),
        ("ECCETTO AUTORIZZATI", "Only with a permit"),
    ]

    private var ztlSign: some View {
        VStack(spacing: 12) {
            signLine(0, size: 16, weight: .black)
            ZStack {
                Circle().fill(Color.white)
                Circle().strokeBorder(Color(hex: 0xC8102E), lineWidth: 11)
            }
            .frame(width: 78, height: 78)
            signLine(1, size: 18, weight: .bold)
            signLine(2, size: 14, weight: .semibold)
            LEDPanel(state: .active, size: 14)
        }
        .padding(.vertical, 18).padding(.horizontal, 14)
        .frame(width: 250)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color(hex: 0x1B2033), lineWidth: 2).padding(5))
        .overlay(alignment: .top) {
            GeometryReader { g in
                LinearGradient(colors: [Notte.action.opacity(0), Notte.action.opacity(0.35), Notte.action], startPoint: .top, endPoint: .bottom)
                    .frame(height: 46)
                    .overlay(alignment: .bottom) { Rectangle().fill(Notte.action).frame(height: 2).shadow(color: Notte.action, radius: 6) }
                    .offset(y: scan * (g.size.height + 46) - 46)
                    .opacity(scanning ? 1 : 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .allowsHitTesting(false)
        }
        .overlay(Viewfinder().padding(-14).opacity(scanning || translated == 0 ? 1 : 0.35))
        .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("intro2.sign")
    }

    @ViewBuilder private func signLine(_ i: Int, size: CGFloat, weight: Font.Weight) -> some View {
        let done = translated > i
        Group {
            if done {
                Text(L(lines[i].meaning))
                    .font(Notte.font(size + 1, .bold)).foregroundStyle(Color(hex: 0xB3261E))
                    .transition(.blurReplace)
            } else {
                Text(verbatim: lines[i].sign)
                    .font(Notte.font(size, weight)).foregroundStyle(Color(hex: 0x1B2033))
                    .transition(.blurReplace)
            }
        }
        .multilineTextAlignment(.center)
        .lineLimit(2).minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity, minHeight: size * 1.4)
    }

    // MARK: Altri cartelli

    private var carousel: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                if i == card {
                    HStack(spacing: 14) {
                        miniSign(i).frame(width: 88, height: 80)
                        Text(L(Self.meanings[i])).font(Notte.font(17, .semibold)).foregroundStyle(Notte.text)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(Notte.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Notte.line, lineWidth: 1))
                    .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                                      removal: .move(edge: .leading).combined(with: .opacity)))
                }
            }
        }
        .clipped()
    }

    private static let meanings = ["Pedestrian area: no cars at all.", "Camera off: you can drive in.", "End of the zone: you're out."]

    @ViewBuilder private func miniSign(_ i: Int) -> some View {
        switch i {
        case 0:
            VStack(spacing: 4) {
                Image(systemName: "figure.walk").font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 42, height: 42).background(Color(hex: 0x1F4E9E), in: Circle())
                Text(verbatim: "AREA PEDONALE").font(Notte.font(9, .black)).foregroundStyle(Color(hex: 0x1B2033))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 6))
        case 1:
            LEDPanel(state: .off, size: 9)
        default:
            ZStack {
                VStack(spacing: 0) {
                    Text(verbatim: "FINE").font(Notte.font(12, .black))
                    Text(verbatim: "ZTL").font(Notte.font(26, .black))
                }
                .foregroundStyle(Color(hex: 0x5A5F70))
                Rectangle().fill(Color(hex: 0xC8102E)).frame(width: 96, height: 5).rotationEffect(.degrees(-35))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 6))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private func play() async {
        try? await Task.sleep(for: .milliseconds(500))
        scanning = true
        if reduceMotion {
            scan = 1
        } else {
            withAnimation(.easeInOut(duration: 1.6)) { scan = 1 }
        }
        try? await Task.sleep(for: .milliseconds(1700))
        withAnimation(.easeOut(duration: 0.3)) { scanning = false }
        for i in 1...3 {
            withAnimation(.easeInOut(duration: 0.5)) { translated = i }
            try? await Task.sleep(for: .milliseconds(320))
        }
        try? await Task.sleep(for: .milliseconds(600))
        for i in 0..<3 {
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : .spring(response: 0.5, dampingFraction: 0.85)) { card = i }
            try? await Task.sleep(for: .milliseconds(1500))
        }
    }
}

/// Gli angoli del mirino della fotocamera intorno al cartello
private struct Viewfinder: View {
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height, l: CGFloat = 26
            Path { p in
                p.move(to: .init(x: 0, y: l)); p.addLine(to: .zero); p.addLine(to: .init(x: l, y: 0))
                p.move(to: .init(x: w - l, y: 0)); p.addLine(to: .init(x: w, y: 0)); p.addLine(to: .init(x: w, y: l))
                p.move(to: .init(x: w, y: h - l)); p.addLine(to: .init(x: w, y: h)); p.addLine(to: .init(x: w - l, y: h))
                p.move(to: .init(x: l, y: h)); p.addLine(to: .init(x: 0, y: h)); p.addLine(to: .init(x: 0, y: h - l))
            }
            .stroke(Notte.text, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
