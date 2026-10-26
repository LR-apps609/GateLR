import SwiftUI

/// Il prototipo della nuova presentazione: tre pagine animate (circa 40 s in tutto) e la pagina «Dove vai e con che auto?».
/// «Salta» è sempre in alto a destra e porta all'ultima pagina. Con «Riduci movimento» le pagine si scambiano in
/// dissolvenza, la camera sta ferma e l'auto non corre.
struct Intro2View: View {
    @EnvironmentObject var store: Store
    var done: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0
    @State private var fill = 0.0

    /// Quanto dura ogni pagina, per riempire la sua barretta
    private static let durations: [Double] = [21, 7, 9]

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

/// L'ultima pagina: un solo invito, «Dove vuoi andare?», con la ricerca. L'auto si imposta poi nell'app (Garage).
struct IntroSetupPage: View {
    @EnvironmentObject var store: Store
    var done: () -> Void
    @State private var query = ""
    @FocusState private var focused: Bool
    @State private var shown = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: 14) {
                IntroTitle(text: L("Where do you want to go?"), size: 40)
                Text(L("We'll find the route that keeps you out of the ZTL."))
                    .font(Notte.font(19)).foregroundStyle(Notte.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(shown ? 1 : 0).offset(y: shown ? 0 : 12)
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass").font(.system(size: 20, weight: .semibold)).foregroundStyle(Notte.action)
                TextField("", text: $query, prompt: Text(L("Hotel, address or square")).foregroundColor(Notte.muted))
                    .font(Notte.font(20, .semibold)).foregroundStyle(Notte.text)
                    .focused($focused)
                    .submitLabel(.search)
                    .onSubmit(finish)
                    .accessibilityIdentifier("intro2.search")
            }
            .padding(.horizontal, 18).frame(height: 64)
            .background(Notte.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(focused || !query.isEmpty ? Notte.action : Notte.line, lineWidth: focused || !query.isEmpty ? 2 : 1))
            .shadow(color: Notte.action.opacity(focused || !query.isEmpty ? 0.25 : 0), radius: 18)
            .padding(.top, 28)
            .opacity(shown ? 1 : 0).offset(y: shown ? 0 : 18)
            Spacer()
            Spacer()
            Button(action: done) {
                Text(L("Later")).font(Notte.font(17, .semibold)).foregroundStyle(Notte.muted)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("intro2.later")
        }
        .padding(.horizontal, 20).padding(.bottom, 12)
        .task {
            withAnimation(.easeOut(duration: 0.6).delay(0.15)) { shown = true }
            // Nel video: si scrive come farebbe una persona, senza confermare
            guard IntroAutoplay.on else { return }
            try? await Task.sleep(for: .milliseconds(1200))
            for ch in "Palazzo Vecchio" {
                query.append(ch)
                try? await Task.sleep(for: .milliseconds(90))
            }
        }
    }

    /// Prototipo: la ricerca vera è quella di Viaggio (AddressSearch); qui si chiude e si torna all'app.
    private func finish() { done() }
}
