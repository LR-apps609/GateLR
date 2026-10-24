import SwiftUI

/// Il primo avvio: tre pagine per spiegare la ZTL, la risposta e i permessi.
struct Onboarding: View {
    var done: () -> Void
    @State private var page = 0

    private let pages: [(symbol: String, tint: Color, title: String, text: String)] = [
        ("video.fill", Theme.red, "Italy's old towns have camera gates",
         "ZTL means limited traffic zone. Cameras read every plate, and driving in at the wrong time means a fine that reaches you months later, even at home."),
        ("checkmark.circle.fill", Theme.green, "One clear answer",
         "Search your hotel or destination: GateLR tells you if you can drive there, now or when you arrive, and prepares the message for the hotel."),
        ("shield.lefthalf.filled", Color(hex: 0x1F4E9E), "A guardian next to your navigator",
         "Drive with Google Maps, Apple Maps or Waze: GateLR warns you before every active ZTL, also in the Dynamic Island. Every rule links to the city's official page."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack { Wordmark(size: 22); Spacer() }
                .padding(.horizontal, 24).padding(.top, 20)
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { i in
                    let p = pages[i]
                    VStack(alignment: .leading, spacing: 18) {
                        Spacer()
                        Image(systemName: p.symbol)
                            .font(.app(size: 40, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 88, height: 88)
                            .background(p.tint, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .accessibilityHidden(true)
                        Text(L(p.title)).font(.app(size: 36, weight: .bold)).foregroundStyle(Theme.ink)
                        Text(L(p.text)).font(.app(size: 18)).foregroundStyle(Theme.muted)
                        Spacer(); Spacer()
                    }
                    .padding(.horizontal, 28)
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            WideButton(title: page < pages.count - 1 ? "Next" : "Start", systemImage: page < pages.count - 1 ? nil : "arrow.right") {
                if page < pages.count - 1 { withAnimation { page += 1 } } else { done() }
            }
            .padding(.horizontal, 24).padding(.bottom, 12)
            Button("Skip", action: done)
                .font(.app(size: 15)).foregroundStyle(Theme.muted)
                .padding(.bottom, 16)
                .opacity(page < pages.count - 1 ? 1 : 0)
        }
        .background(Theme.ground.ignoresSafeArea())
    }
}
