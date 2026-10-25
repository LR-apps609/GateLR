import SwiftUI

/// Il primo avvio: tre pagine per spiegare la ZTL, la risposta e il guardiano; poi «Dove vai?» con le città
/// (la scelta diventa la città della prima pagina) e la spiegazione della posizione prima della richiesta di iOS.
struct Onboarding: View {
    @EnvironmentObject var store: Store
    /// «askLocation»: vero se hai toccato «Consenti la posizione» (allora parte la richiesta di sistema)
    var done: (_ askLocation: Bool) -> Void
    @State private var page = 0

    private let pages: [(symbol: String, tint: Color, title: String, text: String)] = [
        ("video.fill", Theme.red, "Italy's old towns have camera gates",
         "ZTL means limited traffic zone. Cameras read every plate, and driving in at the wrong time means a fine that reaches you months later, even at home."),
        ("checkmark.circle.fill", Theme.green, "One clear answer",
         "Search your hotel or destination: GateLR tells you if you can drive there, now or when you arrive, and prepares the message for the hotel."),
        ("shield.lefthalf.filled", Color(hex: 0x1F4E9E), "A guardian next to your navigator",
         "Drive with Google Maps, Apple Maps or Waze: GateLR warns you before every active ZTL, also in the Dynamic Island. Every rule links to the city's official page."),
    ]
    /// Le pagine dopo quelle di presentazione: la città, poi la posizione
    private var cityPage: Int { pages.count }
    private var locationPage: Int { pages.count + 1 }

    /// Le città della domanda «Dove vai?», nell'ordine delle più visitate; le altre in coda
    private static let order = ["firenze", "bologna", "milano", "roma", "siena"]
    private var cities: [City] {
        store.cities.sorted { (Self.order.firstIndex(of: $0.id) ?? 99, $0.name) < (Self.order.firstIndex(of: $1.id) ?? 99, $1.name) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack { Wordmark(size: 22); Spacer() }
                .padding(.horizontal, 24).padding(.top, 20)
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { i in
                    let p = pages[i]
                    VStack(alignment: .leading, spacing: 18) {
                        Spacer()
                        badge(p.symbol, p.tint)
                        Text(L(p.title)).font(.app(size: 36, weight: .bold)).foregroundStyle(Theme.ink)
                        Text(L(p.text)).font(.app(size: 18)).foregroundStyle(Theme.muted)
                        Spacer(); Spacer()
                    }
                    .padding(.horizontal, 28)
                    .tag(i)
                }
                whereTo.tag(cityPage)
                location.tag(locationPage)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            buttons
                .padding(.horizontal, 24).padding(.bottom, 16)
        }
        .background(Theme.ground.ignoresSafeArea())
    }

    private func badge(_ symbol: String, _ tint: Color) -> some View {
        Image(systemName: symbol)
            .font(.app(size: 40, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 88, height: 88)
            .background(tint, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .accessibilityHidden(true)
    }

    // MARK: «Dove vai?»

    private var whereTo: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            badge("mappin.and.ellipse", Theme.red)
            Text("Where are you going?").font(.app(size: 36, weight: .bold)).foregroundStyle(Theme.ink)
            Text("Pick the city: the first page opens there, with its zones and gates.")
                .font(.app(size: 18)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            FlowChips(cities: cities, selected: store.cityId) { id in
                store.cityId = id
                withAnimation { page = locationPage }
            }
            Spacer(); Spacer()
        }
        .padding(.horizontal, 28)
    }

    // MARK: Perché la posizione

    private var location: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            badge("location.fill", Color(hex: 0x1F4E9E))
            Text("To warn you before gates").font(.app(size: 36, weight: .bold)).foregroundStyle(Theme.ink)
            Text("GateLR needs your location to tell you, while you drive, that an active ZTL gate is coming: before the camera, not after.")
                .font(.app(size: 18)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Label("Your location stays on this iPhone: it is never sent or stored anywhere.", systemImage: "lock.fill")
                .font(.app(size: 15, weight: .semibold)).foregroundStyle(Theme.greenInk)
            Spacer(); Spacer()
        }
        .padding(.horizontal, 28)
    }

    // MARK: Pulsanti in basso

    @ViewBuilder
    private var buttons: some View {
        VStack(spacing: 4) {
            if page < cityPage {
                WideButton(title: "Next", systemImage: nil) { withAnimation { page += 1 } }
                Button("Skip") { withAnimation { page = cityPage } }
                    .font(.app(size: 15)).foregroundStyle(Theme.muted).frame(height: 40)
            } else if page == cityPage {
                // Nessuna città da scegliere adesso: si resta su quella attuale
                WideButton(title: "Skip", systemImage: nil, prominent: false) { withAnimation { page = locationPage } }
                    .accessibilityIdentifier("onboarding.skipCity")
                Color.clear.frame(height: 40)
            } else {
                WideButton(title: "Allow location", systemImage: "location.fill") { done(true) }
                    .accessibilityIdentifier("onboarding.allowLocation")
                Button("Not now") { done(false) }
                    .font(.app(size: 15)).foregroundStyle(Theme.muted).frame(height: 40)
            }
        }
    }
}

/// Le città come pastiglie che vanno a capo
private struct FlowChips: View {
    var cities: [City]
    var selected: String
    var choose: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(cities) { c in
                let on = c.id == selected
                Button { choose(c.id) } label: {
                    Text(c.localizedName).font(.app(size: 17, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(on ? Theme.blueFill : Theme.card, in: Capsule())
                        .overlay(Capsule().stroke(Theme.line, lineWidth: on ? 0 : 1))
                        .foregroundStyle(on ? Color.white : Theme.ink)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
                .accessibilityIdentifier("onboarding.city.\(c.id)")
            }
        }
    }
}
