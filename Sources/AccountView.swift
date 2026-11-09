import SwiftUI

/// 2.2 La barra in alto di ogni scheda (tavola P24-Navigazione): la fotocamera di «Leggi il cartello» (un tocco, da ogni
/// scheda) e l'icona del veicolo, che apre Garage, permessi e Impostazioni
struct TopActions: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: AppRouter
    /// Sopra il blu notte di Adesso o sopra la mappa: il vetro smerigliato
    var material = false
    /// Il lato dei cerchi: 44 punti; 36 nella testata di Adesso, alta come il menu della città (la risposta resta nello
    /// schermo senza scorrere, ScreenshotTests.test6VarcoProMax), con l'area del tocco sempre di 44
    var size: CGFloat = 44

    var body: some View {
        HStack(spacing: 8) {
            Button { router.showSign = true } label: { circle(Self.signSymbol) }
                .buttonStyle(.plain)
                .accessibilityLabel(L("Read the sign"))
                .accessibilityIdentifier("top.sign")
            Button { router.go(.account(nil)) } label: { circle(store.vehicle.kind.symbol) }
                .buttonStyle(.plain)
                .accessibilityLabel(L("Garage and settings"))
                .accessibilityValue(store.vehicle.chipLabel)
                .accessibilityIdentifier("top.vehicle")
        }
    }

    static let signSymbol = "camera.viewfinder"

    private func circle(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.app(size: 16, weight: .semibold))
            .frame(width: size, height: size)
            .background(material ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Theme.card), in: Circle())
            .foregroundStyle(material ? AnyShapeStyle(.primary) : AnyShapeStyle(Theme.ink))
            .padding((44 - min(size, 44)) / 2)
            .contentShape(Rectangle())
            .padding(-(44 - min(size, 44)) / 2)
    }
}

/// 2.2 Il foglio dietro l'icona del veicolo (tavole I-VeicoloFoglio, I-Garage, I-Impostazioni): il veicolo per cui
/// rispondiamo, Garage e permessi, Impostazioni, privacy, fonti e «Segnala». Prima erano righe della scheda «Tu»
struct AccountView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: AppRouter
    @State private var reporting = false

    var body: some View {
        NavigationStack(path: $router.accountPath) {
            List {
                Section {
                    ForEach(store.vehicles) { v in
                        Button { store.activeVehicleId = v.id } label: {
                            HStack(spacing: 12) {
                                Image(systemName: v.kind.symbol).foregroundStyle(Theme.blue).frame(width: 28)
                                    .accessibilityHidden(true)
                                Text(verbatim: v.chipLabel).font(.app(size: 16, weight: .semibold)).foregroundStyle(Theme.ink)
                                Spacer()
                                if v.id == store.vehicle.id {
                                    Image(systemName: "checkmark").font(.app(size: 15, weight: .bold)).foregroundStyle(Theme.blue)
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                        .accessibilityAddTraits(v.id == store.vehicle.id ? .isSelected : [])
                    }
                } header: { Text("The answers are for") }

                Section {
                    link(.garage, "Garage", "car.fill", Theme.blueFill, L("Your cars and permits"))
                    link(.settings, "Settings", "gearshape.fill", Color(hex: 0x5D6670), L("Alerts, navigator, language and city data"))
                    link(.privacy, "Privacy", "hand.raised.fill", Theme.blueFill, L("What stays on this iPhone and what goes out"))
                    link(.about, "About", "info.circle.fill", Theme.blueFill, L("Sources, licences and disclaimer"))
                    Button { reporting = true } label: {
                        MenuRow(title: "Report an error", symbol: "exclamationmark.bubble.fill", tint: Color(hex: 0x5D6670),
                                subtitle: L("Hours, gates or zones that are wrong"))
                    }
                    .accessibilityIdentifier("account.report")
                } footer: {
                    Text("No account needed: your cars, permits and trips stay on this iPhone.")
                }

                // Solo quando l'app ha il suo numero su App Store (APP_STORE_ID): la pagina per scrivere la recensione
                if let url = ReviewPrompter.writeReviewURL {
                    Section {
                        Link(destination: url) {
                            Label("Leave a review", systemImage: "star.bubble.fill")
                                .font(.app(size: 17, weight: .semibold)).foregroundStyle(Theme.ink)
                        }
                        .accessibilityIdentifier("account.review")
                    }
                }
            }
            .navigationTitle("Garage and settings")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Theme.blue)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Done")) { router.showAccount = false }
                        .accessibilityIdentifier("account.done")
                }
            }
            .navigationDestination(for: AccountRoute.self) { destination($0) }
        }
        .sheet(isPresented: $reporting) { BugReportView().environmentObject(store) }
    }

    private func link(_ route: AccountRoute, _ title: LocalizedStringKey, _ symbol: String, _ tint: Color, _ subtitle: String) -> some View {
        NavigationLink(value: route) {
            MenuRow(title: title, symbol: symbol, tint: tint, subtitle: subtitle)
        }
        .accessibilityIdentifier("account.\(route)")
    }

    @ViewBuilder
    private func destination(_ route: AccountRoute) -> some View {
        switch route {
        case .garage: GarageView().readableScrollWidth()
        case .settings: SettingsView().readableScrollWidth()
        case .privacy: PrivacyView().readableScrollWidth()
        case .about: AboutView().readableScrollWidth()
        }
    }
}
