import MapKit
import SwiftUI

/// La presentazione: tre pagine animate (circa 40 s in tutto) e, dalla 2.2, la pagina «Con cosa entri?» (il veicolo).
/// «Salta» è sempre in alto a destra e porta all'ultima pagina. Con «Riduci movimento» le pagine si scambiano in
/// dissolvenza, la camera sta ferma e l'auto non corre.
struct Intro2View: View {
    @EnvironmentObject var store: Store
    var done: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0
    @State private var fill = 0.0

    /// Quanto dura ogni pagina, per riempire la sua barretta
    private static let durations: [Double] = [28, 7, 9]

    var body: some View {
        ZStack(alignment: .top) {
            Notte.navy.ignoresSafeArea()
            Group {
                switch page {
                case 0: IntroDriveSlide(next: advance)
                case 1: IntroStatusSlide(gateName: IntroScene.load(store).gateName, next: advance)
                case 2: IntroSignsSlide(next: advance)
                default: IntroVehiclePage(done: done)
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
                        // 2.0 (B123): 44 punti da toccare (il disegno resta di 36)
                        .frame(minHeight: 44).contentShape(Rectangle())
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

/// 2.2 L'ultima pagina (tavola I-Veicolo, funzione 26 «3 pagine + veicolo»): con cosa entri? Tipo, alimentazione e classe
/// Euro, ognuna con «Non so» (decisione 8: dove contano i divieti Euro diciamo «Controlla il cartello», mai «Puoi entrare»).
/// Prima c'era «Dove vuoi andare?» con la promessa di un percorso fuori dalla ZTL, che GateLR non fa: la ricerca è in Adesso
struct IntroVehiclePage: View {
    @EnvironmentObject var store: Store
    var done: () -> Void
    @State private var type: VehicleType = .car
    /// nil = «Non so»
    @State private var fuel: Fuel?
    @State private var euro: Int?
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Color.clear.frame(height: 50)
                VStack(alignment: .leading, spacing: 12) {
                    IntroTitle(text: L("What are you driving?"), size: 38)
                    Text(L("The answer changes with the vehicle: in the same place an electric car may enter and a Euro 2 diesel may not."))
                        .font(Notte.font(17)).foregroundStyle(Notte.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .opacity(shown ? 1 : 0).offset(y: shown || reduceMotion ? 0 : 12)
                group(L("Vehicle")) {
                    ForEach(VehicleType.allCases) { t in chip(t.label, selected: type == t, id: "intro2.type.\(t.rawValue)") { type = t } }
                }
                group(L("Fuel")) {
                    ForEach(Fuel.allCases) { f in chip(f.label, selected: fuel == f, id: "intro2.fuel.\(f.rawValue)") { fuel = f } }
                    chip(L("Don't know"), selected: fuel == nil, id: "intro2.fuel.unknown") { fuel = nil }
                }
                // Per un'elettrica la classe Euro non conta
                if fuel != .electric {
                    group(L("Euro class (registration document, field V.9)")) {
                        ForEach(0...6, id: \.self) { n in chip("\(n)", selected: euro == n, id: "intro2.euro.\(n)") { euro = n } }
                        chip(L("Don't know"), selected: euro == nil, id: "intro2.euro.unknown") { euro = nil }
                    }
                }
                Text(verbatim: Self.hint)
                    .font(Notte.font(15)).foregroundStyle(Notte.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20).padding(.bottom, 12)
        }
        .scrollBounceBehavior(.basedOnSize)
        // 2.0 (B39): i pulsanti restano fissi in basso anche con «Testo più grande»
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 6) {
                IntroButton(title: L("Done"), systemImage: "checkmark", identifier: "intro2.done") { save() }
                Button(action: later) {
                    Text(L("Later")).font(Notte.font(17, .semibold)).foregroundStyle(Notte.muted)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("intro2.later")
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 12)
            .background(Notte.navy)
        }
        .animation(.snappy, value: fuel)
        .task { withAnimation(.easeOut(duration: 0.6).delay(0.15)) { shown = true } }
    }

    /// «Auto a noleggio? …»: con le parole vere delle risposte (Tools/translations.py, docs/parole.md)
    static var hint: String {
        String(format: L("Rental car? The Euro class is on the registration document in the glovebox. With «%@» we say «%@» where Euro bans matter, never «%@»."),
               L("Don't know"), Stato.controllaCartello.word.title, Stato.entraPure.word.title)
    }

    /// Il veicolo scelto (nil = «Non so» per alimentazione o classe Euro)
    static func vehicle(type: VehicleType, fuel: Fuel?, euro: Int?) -> Vehicle {
        var v = Vehicle.unknown(type)
        if let fuel { v.fuel = fuel; v.fuelUnknown = nil }
        if let euro { v.euro = euro; v.euroUnknown = nil }
        if fuel == .electric { v.euroUnknown = nil }
        return v
    }

    private func save() {
        store.adoptVehicle(Self.vehicle(type: type, fuel: fuel, euro: euro))
        done()
    }

    /// «Più tardi»: niente auto di serie (funzione 17). L'auto di esempio mai toccata diventa il veicolo «Non so»
    /// (mai nel giro delle foto, che risponde per l'auto di esempio)
    private func later() {
        if Store.isUntouchedSample(store.vehicles) && !ProcessInfo.processInfo.arguments.contains("-uitest") {
            store.adoptVehicle(.unknown())
        }
        done()
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(Notte.font(13, .bold)).kerning(1.2).foregroundStyle(Notte.muted)
                .accessibilityAddTraits(.isHeader)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) { content() }
            }
        }
    }

    private func chip(_ text: String, selected: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: text).font(Notte.font(16, .semibold))
                .foregroundStyle(selected ? Notte.navy : Notte.text)
                .padding(.horizontal, 16).frame(minHeight: 44)
                .background(selected ? Notte.text : Notte.surface, in: Capsule())
                .overlay(Capsule().stroke(selected ? Notte.text : Notte.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(id)
    }
}
