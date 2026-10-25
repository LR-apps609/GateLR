import SwiftUI

/// Il prototipo della nuova presentazione: tre pagine animate (≤ 30 s in tutto) e la pagina «Dove vai e con che auto?».
/// «Salta» è sempre in alto a destra e porta all'ultima pagina. Con «Riduci movimento» le pagine si scambiano in
/// dissolvenza, la camera sta ferma e l'auto non corre.
struct Intro2View: View {
    @EnvironmentObject var store: Store
    var done: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0
    @State private var fill = 0.0

    /// Quanto dura ogni pagina, per riempire la sua barretta
    private static let durations: [Double] = [13, 8, 9]

    var body: some View {
        ZStack(alignment: .top) {
            Notte.navy.ignoresSafeArea()
            Group {
                switch page {
                case 0: IntroDriveSlide(next: advance)
                case 1: IntroStatusSlide(gateName: IntroScene.load(store).gateName, next: advance)
                case 2: IntroSignsSlide(next: advance)
                default: IntroSetupPage(done: done)
                }
            }
            .id(page)
            .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                              removal: .move(edge: .leading).combined(with: .opacity)))
            header
        }
        .preferredColorScheme(.dark)
        .onAppear { fillBar() }
    }

    private var header: some View {
        HStack {
            if page < 3 {
                IntroProgress(page: page, fill: fill)
            } else {
                RedBar()
            }
            Spacer()
            if page < 3 {
                Button { go(3) } label: {
                    Text(L("Skip")).font(Notte.font(17, .semibold)).foregroundStyle(Notte.text)
                        .padding(.horizontal, 14).frame(height: 36)
                        .background(Notte.surface.opacity(0.85), in: Capsule())
                        .overlay(Capsule().stroke(Notte.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("intro2.skip")
            }
        }
        .padding(.horizontal, 20).padding(.top, 8)
    }

    private func advance() { go(page + 1) }

    private func go(_ p: Int) {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.35) : .spring(response: 0.5, dampingFraction: 0.9)) { page = p }
        fillBar()
    }

    private func fillBar() {
        guard page < 3 else { return }
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) { fill = 0 }
        DispatchQueue.main.async {
            withAnimation(.linear(duration: Self.durations[page])) { fill = 1 }
        }
    }
}

/// L'ultima pagina: la città (quelle che l'app conosce) e l'auto, con due scelte veloci
struct IntroSetupPage: View {
    @EnvironmentObject var store: Store
    var done: () -> Void
    @State private var city = ""
    @State private var fuel: Fuel = .petrol
    @State private var euro = 6

    private static let order = ["firenze", "bologna", "milano", "roma", "siena"]
    private var cities: [City] {
        store.cities.sorted { (Self.order.firstIndex(of: $0.id) ?? 99, $0.name) < (Self.order.firstIndex(of: $1.id) ?? 99, $1.name) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    IntroTitle(text: L("Where are you going, and in what car?"), size: 32)
                    chips(cities.map { ($0.id, $0.localizedName) }, selected: city, id: "intro2.city") { city = $0 }
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L("Fuel")).font(Notte.font(15, .semibold)).foregroundStyle(Notte.muted)
                        chips(Fuel.allCases.map { ($0.rawValue, $0.label) }, selected: fuel.rawValue, id: "intro2.fuel") {
                            fuel = Fuel(rawValue: $0) ?? .petrol
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text(verbatim: "Euro").font(Notte.font(15, .semibold)).foregroundStyle(Notte.muted)
                        chips((1...6).map { ("\($0)", "\($0)") }, selected: "\(euro)", id: "intro2.euro", minWidth: 44) {
                            euro = Int($0) ?? 6
                        }
                    }
                }
                .padding(.top, 64)
            }
            .scrollIndicators(.hidden)
            IntroButton(title: L("Start"), identifier: "intro2.start") { finish() }
                .padding(.top, 12)
        }
        .padding(.horizontal, 20).padding(.bottom, 12)
        .onAppear {
            if city.isEmpty { city = store.cityId }
            if let v = store.vehicles.first(where: { $0.id == store.activeVehicleId }) { fuel = v.fuel; euro = v.euro }
        }
    }

    private func chips(_ items: [(String, String)], selected: String, id: String, minWidth: CGFloat = 104,
                       choose: @escaping (String) -> Void) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minWidth), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.0) { item in
                let on = item.0 == selected
                Button { withAnimation(.easeInOut(duration: 0.2)) { choose(item.0) } } label: {
                    Text(verbatim: item.1).font(Notte.font(16, .semibold)).lineLimit(1).minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(on ? Color.white : Notte.text)
                        .background(on ? Notte.action : Notte.surface, in: Capsule())
                        .overlay(Capsule().stroke(on ? Color.clear : Notte.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
                .accessibilityIdentifier("\(id).\(item.0)")
            }
        }
    }

    private func finish() {
        if !city.isEmpty { store.cityId = city }
        // Prototipo: si aggiorna solo l'auto di esempio, mai un'auto che hai già inserito tu
        if store.activeVehicleId == SampleData.rental.id, let i = store.vehicles.firstIndex(where: { $0.id == SampleData.rental.id }) {
            store.vehicles[i].fuel = fuel
            store.vehicles[i].euro = euro
        }
        done()
    }
}
