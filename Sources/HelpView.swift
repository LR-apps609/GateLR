import SwiftUI

/// 2.2 «Aiuto» (tavola I-Aiuto, come HelpScreen su Android): dopo, e quando hai un dubbio. Leggi il cartello; le multe
/// (cosa fare, la foto del verbale, il diario dei passaggi dentro Multe); impara e segnala. Prima stava in «Tu»
struct HelpView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: AppRouter
    /// Il numero delle righe del diario (DriveLogBook ha il suo oggetto: la pagina si ridisegna solo quando cambia)
    @ObservedObject private var logBook = Store.shared.logBook
    @ObservedObject private var monitor = GateMonitor.shared
    @State private var reporting = false

    var body: some View {
        NavigationStack(path: $router.helpPath) {
            List {
                Section {
                    row(.sign, "Read the sign", "camera.viewfinder", Theme.blueFill, L("Point the camera at the sign: days and hours"),
                        id: "learn.sign")
                    // Come su Android: con la posizione negata gli avvisi in auto sono spenti, e lo diciamo qui
                    if monitor.locationDenied {
                        Button { LocationGate.openSettings() } label: {
                            Label(L("Location denied: car alerts are off."), systemImage: "location.slash")
                                .font(.app(size: 15, weight: .semibold)).foregroundStyle(Theme.amberInk)
                        }
                        .accessibilityHint(L("Open Settings"))
                        .accessibilityIdentifier("help.locationDenied")
                    }
                }

                Section {
                    row(.fineGuide, "Got a fine?", "envelope.badge.fill", Theme.red, L("What to do, in 4 steps"), id: "help.fine")
                    row(.fineScan, "Photograph the notice", "doc.text.viewfinder", Theme.red, L("We check date, time and gate"),
                        id: "fines.scan")
                    row(.log, "Drive log", "list.bullet.rectangle", Theme.blueFill, L("Passages near the gates, only on this phone"),
                        badge: store.log.isEmpty ? nil : "\(store.log.count)", id: "fines.log")
                } header: { Text("Fines") }

                Section {
                    row(.learn, "What are ZTLs", "graduationcap.fill", Theme.red, L("The signs and the «ZTL ATTIVA» panel"), id: "help.learn")
                    Button { router.showIntro = true } label: {
                        MenuRow(title: "Replay the intro", symbol: "play.rectangle.fill", tint: Theme.blueFill,
                                subtitle: L("What GateLR answers, in a minute"))
                    }
                    .accessibilityIdentifier("learn.intro")
                    // 2.2 (funzione 23): una sola voce «Segnala», con il testo nella lingua dell'utente
                    Button { reporting = true } label: {
                        MenuRow(title: "Report an error", symbol: "exclamationmark.bubble.fill", tint: Color(hex: 0x5D6670),
                                subtitle: L("Hours, gates or zones that are wrong"))
                    }
                    .accessibilityIdentifier("help.report")
                } header: { Text("Learn and report") } footer: {
                    Text("Road signs on site always win over the app.")
                }
            }
            .navigationTitle("Help")
            .tint(Theme.blue)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { TopActions() } }
            .navigationDestination(for: HelpRoute.self) { destination($0) }
        }
        .sheet(isPresented: $reporting) { BugReportView().environmentObject(store) }
    }

    private func row(_ route: HelpRoute, _ title: LocalizedStringKey, _ symbol: String, _ tint: Color, _ subtitle: String,
                     badge: String? = nil, id: String) -> some View {
        NavigationLink(value: route) {
            MenuRow(title: title, symbol: symbol, tint: tint, subtitle: subtitle, badge: badge)
        }
        .accessibilityIdentifier(id)
    }

    @ViewBuilder
    private func destination(_ route: HelpRoute) -> some View {
        switch route {
        case .sign: SignReaderView().readableScrollWidth()
        case .fineGuide: FineGuideView().readableScrollWidth()
        case .fineScan: FineScanView().readableScrollWidth()
        case .log: DriveLogView().readableScrollWidth()
        case .learn: LearnZTLView().readableScrollWidth()
        }
    }
}

/// Una riga dei menu di Aiuto e del foglio del veicolo: il simbolo nel quadratino colorato, titolo, riga sotto e numero
struct MenuRow: View {
    var title: LocalizedStringKey
    var symbol: String
    var tint: Color
    var subtitle: String
    var badge: String? = nil

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.app(size: 16, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(tint, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.app(size: 17, weight: .semibold)).foregroundStyle(Theme.ink)
                Text(verbatim: subtitle).font(.app(size: 13)).foregroundStyle(Theme.muted).lineLimit(2)
            }
            Spacer(minLength: 4)
            if let badge { Pill(text: badge, fill: Theme.amberSoft, ink: Theme.amberInk) }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
