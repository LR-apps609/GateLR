import SwiftUI

/// «Tu»: tutto quello che non è la risposta né la mappa, in un elenco. Garage, Viaggio e hotel, Multe e passaggi,
/// Cosa sono le ZTL, Impostazioni e Abbonamento. Senza login: tutto resta sul telefono.
struct YouView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: AppRouter
    @Binding var showZone: Bool
    @Binding var tab: Tab

    var body: some View {
        NavigationStack(path: $router.youPath) {
            List {
                Section {
                    HStack(spacing: 14) {
                        LogoMark(size: 46)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Your GateLR").font(Theme.display(22)).foregroundStyle(Theme.ink)
                            Text("No account needed: your cars, permits and trips stay on this iPhone.")
                                .font(.app(size: 13)).foregroundStyle(Theme.muted)
                        }
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }

                Section {
                    row(.garage, "Garage", "car.fill", Theme.blueFill, store.vehicles.isEmpty ? L("Your cars and permits") : store.vehicle.chipLabel)
                    row(.trip, "Trip and hotel", "suitcase.rolling.fill", Theme.blueFill, L("Destination, route and message for the hotel"))
                    row(.fines, "Fines and passages", "envelope.badge.fill", Theme.red, L("Drive log, got a fine, photograph the notice"),
                        badge: store.log.isEmpty ? nil : "\(store.log.count)")
                    row(.learn, "What are ZTLs", "graduationcap.fill", Theme.red, L("Signs, gate panels and the intro"))
                }

                Section {
                    row(.settings, "Settings", "gearshape.fill", Color(hex: 0x5D6670), L("Alerts, navigator, language and city data"))
                    row(.subscription, "Subscription", "star.fill", Theme.brass, L("GateLR Plus: coming soon"))
                }
            }
            .navigationTitle("You")
            .tint(Theme.blue)
            .navigationDestination(for: YouRoute.self) { destination($0) }
        }
    }

    private func row(_ route: YouRoute, _ title: LocalizedStringKey, _ symbol: String, _ tint: Color, _ subtitle: String,
                     badge: String? = nil) -> some View {
        NavigationLink(value: route) {
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
        }
        .accessibilityIdentifier("you.\(route)")
    }

    @ViewBuilder
    private func destination(_ route: YouRoute) -> some View {
        switch route {
        case .garage: GarageView().readableScrollWidth()
        case .trip:
            TripView(showZone: $showZone, tab: $tab)
                .readableScrollWidth()
                .navigationTitle("Trip and hotel")
                .navigationBarTitleDisplayMode(.inline)
        case .fines: FinesHubView().readableScrollWidth()
        case .learn: LearnHubView().readableScrollWidth()
        case .settings: SettingsView().readableScrollWidth()
        case .subscription: SubscriptionView().readableScrollWidth()
        }
    }
}

/// «Multe e passaggi»: il diario dei passaggi, cosa fare con una multa e la foto del verbale
struct FinesHubView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        List {
            Section {
                NavigationLink { DriveLogView() } label: {
                    HStack {
                        Label("Drive log", systemImage: "list.bullet.rectangle")
                        Spacer()
                        if !store.log.isEmpty { Pill(text: "\(store.log.count)", fill: Theme.amberSoft, ink: Theme.amberInk) }
                    }
                }
                NavigationLink { FineGuideView() } label: { Label("Got a fine?", systemImage: "envelope.badge") }
                NavigationLink { FineScanView() } label: { Label("Photograph the notice", systemImage: "doc.text.viewfinder") }
                    .accessibilityIdentifier("fines.scan")
            }
        }
        .navigationTitle("Fines and passages")
    }
}

/// «Cosa sono le ZTL»: la guida, il cartello letto con la fotocamera e la presentazione da rivedere
struct LearnHubView: View {
    @EnvironmentObject var router: AppRouter

    var body: some View {
        List {
            Section {
                NavigationLink { LearnZTLView() } label: { Label("Learn", systemImage: "graduationcap") }
                NavigationLink { SignReaderView() } label: { Label("Read the sign", systemImage: "camera.viewfinder") }
                    .accessibilityIdentifier("learn.sign")
                Button { router.showIntro = true } label: { Label("Replay the intro", systemImage: "play.rectangle") }
                    .accessibilityIdentifier("learn.intro")
            } footer: {
                Text("The signs, the gate panels, and what to do if you drove in by mistake.")
            }
        }
        .navigationTitle("What are ZTLs")
    }
}

/// «Abbonamento»: GateLR Plus non c'è ancora. Nessun acquisto: solo cosa arriverà
struct SubscriptionView: View {
    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "star.circle.fill").font(.app(size: 34)).foregroundStyle(Theme.brass)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("GateLR Plus").font(.app(size: 18, weight: .semibold))
                        Text("Coming soon: more cities, trip alerts and sync between devices.")
                            .font(.app(size: 14)).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Pill(text: L("Soon"), fill: Theme.brass.opacity(0.18), ink: Theme.brass)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            } footer: {
                Text("No account needed: your cars, permits and trips stay on this iPhone.")
            }
        }
        .navigationTitle("Subscription")
    }
}
