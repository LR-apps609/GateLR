import SwiftUI

/// Seconda pagina, «Non sai se puoi entrare?»: il pannello passa da rosso ad ambra a verde con una riga di spiegazione,
/// e dall'alto scende l'avviso «Varco attivo tra 250 m» come una Live Activity.
struct IntroStatusSlide: View {
    var gateName: String
    var next: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0
    @State private var banner = false
    @State private var bannerOpen = false

    private let states: [LEDState] = [.active, .soon, .off]
    private var explanation: String {
        switch states[index].light {
        case .red: L("Camera on: drive in and you're fined.")
        case .amber: L("It switches on in 15 minutes: decide now.")
        case .green: L("Camera off: you can drive in.")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            alert
                .frame(height: 86, alignment: .top)
                .padding(.top, 60)
            Spacer(minLength: 12)
            IntroTitle(text: L("Not sure if you can drive in?"))
            Spacer(minLength: 24)
            VStack(spacing: 18) {
                LEDPanel(state: states[index], size: 30)
                    .accessibilityIdentifier("intro2.panel")
                HStack(spacing: 10) {
                    ForEach(states.indices, id: \.self) { i in
                        Circle().fill(states[i].color.opacity(i == index ? 1 : 0.18))
                            .frame(width: 12, height: 12)
                            .shadow(color: i == index ? states[i].color : .clear, radius: 6)
                    }
                }
                .accessibilityHidden(true)
                Text(explanation)
                    .font(Notte.font(20, .semibold)).foregroundStyle(Notte.text)
                    .multilineTextAlignment(.center)
                    .id(index)
                    .transition(.opacity)
                    .frame(minHeight: 54)
            }
            .frame(maxWidth: .infinity)
            Spacer(minLength: 24)
            Label {
                Text(L("Every hour comes from the city's own ordinance."))
                    .font(Notte.font(15, .semibold)).foregroundStyle(Notte.muted)
            } icon: {
                Image(systemName: "doc.text.fill").foregroundStyle(Notte.muted)
            }
            .padding(.bottom, 16)
            // Qui, nell'app vera, la richiesta dei permessi: notifiche (UNUserNotificationCenter.requestAuthorization)
            // e posizione con GateMonitor.shared.startIfReady(store:). Nel prototipo si va solo avanti.
            IntroButton(title: L("Turn on alerts"), systemImage: "bell.fill", identifier: "intro2.alerts", action: next)
        }
        .padding(.horizontal, 20).padding(.bottom, 12)
        .task { await cycle() }
        .task {
            guard IntroAutoplay.on else { return }
            try? await Task.sleep(for: .milliseconds(6600))
            next()
        }
    }

    /// L'avviso nello stile dell'Isola dinamica: una pillola nera che scende e si allarga
    private var alert: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Notte.ledRed.opacity(0.18)).frame(width: 42, height: 42)
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Notte.ledRed)
            }
            if bannerOpen {
                VStack(alignment: .leading, spacing: 1) {
                    Text(L("Gate active in 250 m")).font(Notte.font(17, .bold)).foregroundStyle(.white)
                    Text(verbatim: "\(gateName) · GateLR").font(Notte.font(13, .semibold)).foregroundStyle(Notte.muted)
                }
                .transition(.opacity)
                Spacer(minLength: 4)
                Text(verbatim: "250 m").font(Notte.dots(17)).foregroundStyle(Notte.ledRed)
                    .shadow(color: Notte.ledRed.opacity(0.8), radius: 5)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: bannerOpen ? .infinity : 66)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 16, y: 6)
        .frame(maxWidth: .infinity)
        .offset(y: banner ? 0 : -140)
        .opacity(banner ? 1 : 0)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("intro2.banner")
    }

    private func cycle() async {
        try? await Task.sleep(for: .milliseconds(600))
        withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : .spring(response: 0.5, dampingFraction: 0.75)) { banner = true }
        try? await Task.sleep(for: .milliseconds(450))
        withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : .spring(response: 0.55, dampingFraction: 0.72)) { bannerOpen = true }
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(1900))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) { index = (index + 1) % states.count }
        }
    }
}
