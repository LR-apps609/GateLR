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
            (Text(verbatim: "Gate").foregroundStyle(Theme.ink) + Text(verbatim: "LR").foregroundStyle(Theme.red))
                .font(Theme.display(size))
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
}

struct Pill: View {
    var text: String
    var fill: Color
    var ink: Color
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(fill, in: Capsule())
            .foregroundStyle(ink)
            .fixedSize()
    }
}

struct VerdictPill: View {
    var verdict: Verdict
    var body: some View { Pill(text: verdict.short, fill: verdict.pillFill, ink: verdict.pillInk) }
}

/// Il riquadro grande con la risposta
struct VerdictCard: View {
    var answer: Answer
    var heading: String
    var source: Source
    var since: Date? = nil
    var onWhy: (() -> Void)? = nil

    var body: some View {
        let v = answer.verdict
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(heading.uppercased()).font(Theme.label(13)).tracking(1.1).opacity(0.9)
                Spacer()
                Pill(text: answer.gatesOn ? L("ZTL active") : L("ZTL not active"), fill: v.onFill.opacity(0.16), ink: v.onFill)
            }
            HStack(spacing: 14) {
                Image(systemName: v.symbol)
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(v.badgeInk)
                    .frame(width: 56, height: 56)
                    .background(v.badgeFill, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: -15) {
                    ForEach(v.titleLines, id: \.self) { line in
                        Text(line).font(Theme.display(36)).lineLimit(1).minimumScaleFactor(0.6)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(v.title)
                .accessibilityAddTraits(.isHeader)
            }
            Text(detail).font(.system(size: 16)).fixedSize(horizontal: false, vertical: true)
            if let next = answer.nextChange { countdown(to: next) }
            Rectangle().fill(v.onFill.opacity(0.22)).frame(height: 1)
            HStack {
                Label(String(format: L(source.reviewedByHuman ? "Checked %@" : "Read %@"), source.checkedOn.formatted(.dateTime.day().month())),
                      systemImage: source.reviewedByHuman ? "checkmark.seal" : "doc.text.magnifyingglass")
                    .font(.system(size: 13)).opacity(0.92)
                Text("· \(source.localizedAuthority)").font(.system(size: 13)).opacity(0.92).lineLimit(1)
                Spacer()
                if let onWhy {
                    Button(action: onWhy) {
                        HStack(spacing: 3) { Text("Why?"); Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)) }
                    }
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(v.onFill)
                    .accessibilityLabel("Why?")
                    .accessibilityHint("Shows the official source")
                }
            }
        }
        .padding(20)
        .foregroundStyle(v.onFill)
        .background(v.fill, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
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
                        Capsule().fill(answer.verdict.onFill.opacity(0.22))
                        Capsule().fill(answer.verdict.onFill)
                            .frame(width: g.size.width * min(1, max(0.03, 1 - left / span)))
                    }
                }
                .frame(height: 6)
                .accessibilityHidden(true)
            }
            HStack {
                if let since { Text(String(format: L(answer.gatesOn ? "Active since %@" : "Not active since %@"), since.formatted(date: .omitted, time: .shortened))) }
                Spacer()
                Text(String(format: L(answer.gatesOn ? "Ends in %@" : "Starts in %@"), Self.duration(left)))
            }
            .font(.system(size: 12.5, weight: .medium)).opacity(0.9).monospacedDigit()
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
        case .yes(let r), .no(let r), .unsure(let r): r
        case .conditional(let r, let c): "\(r) \(c)"
        }
    }
}

struct StatusBanner: View {
    var status: City.Status
    var body: some View {
        if status != .verified {
            Label(L(status == .sample ? "Sample data, not real" : "Draft: from official sources, not yet reviewed by a person"),
                  systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
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
            .font(.system(size: 15, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(prominent ? Theme.blueFill : Theme.blueSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(prominent ? Color.white : Theme.blue)
        }
        .buttonStyle(.plain)
    }
}
