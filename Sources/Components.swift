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
            ctx.stroke(door, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 7 * u, lineCap: .round))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct SectionLabel: View {
    var text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 13, weight: .semibold))
            .tracking(1)
            .foregroundStyle(Theme.muted)
    }
}

struct CardBackground: ViewModifier {
    var radius: CGFloat = 14
    func body(content: Content) -> some View {
        content.background(Theme.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}
extension View {
    func card(_ radius: CGFloat = 14) -> some View { modifier(CardBackground(radius: radius)) }
}

struct Pill: View {
    var text: String
    var fill: Color
    var ink: Color
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 9).padding(.vertical, 3)
            .background(fill, in: Capsule())
            .foregroundStyle(ink)
    }
}

/// Il riquadro grande con la risposta
struct VerdictCard: View {
    var answer: Answer
    var heading: String
    var source: Source
    var onWhy: () -> Void = {}

    var body: some View {
        let v = answer.verdict
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(heading.uppercased()).font(.system(size: 13, weight: .semibold)).tracking(1).opacity(0.9)
                Spacer()
                Pill(text: answer.gatesOn ? "Gates on" : "Gates off", fill: v.onFill.opacity(0.18), ink: v.onFill)
            }
            HStack(spacing: 14) {
                Image(systemName: v.symbol)
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(v.badgeInk)
                    .frame(width: 56, height: 56)
                    .background(v.badgeFill, in: Circle())
                Text(v.title).font(Theme.display(36, .black)).lineLimit(2).minimumScaleFactor(0.7)
            }
            Text(detail).font(.system(size: 16)).fixedSize(horizontal: false, vertical: true)
            Divider().overlay(v.onFill.opacity(0.3))
            HStack {
                Text("Checked \(source.checkedOn.formatted(.dateTime.day().month())) · \(source.authority)")
                    .font(.system(size: 13)).opacity(0.92)
                Spacer()
                Button("Why?", action: onWhy).font(.system(size: 13, weight: .semibold)).underline().foregroundStyle(v.onFill)
            }
        }
        .padding(20)
        .foregroundStyle(v.onFill)
        .background(v.fill, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        switch answer.verdict {
        case .yes(let r), .no(let r), .unsure(let r): r
        case .conditional(let r, let c): "\(r) \(c)"
        }
    }
}

struct SampleBanner: View {
    var body: some View {
        Label("Sample data, not verified", systemImage: "exclamationmark.triangle.fill")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.amberInk)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Theme.amberSoft, in: Capsule())
    }
}
