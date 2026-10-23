import SwiftUI

enum Tab: Hashable { case varco, map, trip, garage, account }

struct RootView: View {
    @EnvironmentObject var store: Store
    @AppStorage("onboarded") private var onboarded = false
    @State private var tab: Tab = .varco
    @State private var showZone = false

    var body: some View {
        TabView(selection: $tab) {
            VarcoView(showZone: $showZone, tab: $tab)
                .tabItem { Label("Gate", systemImage: "smallcircle.filled.circle") }.tag(Tab.varco)
            MapScreen(showZone: $showZone, tab: $tab)
                .tabItem { Label("Map", systemImage: "map") }.tag(Tab.map)
            TripView(showZone: $showZone)
                .tabItem { Label("Trip", systemImage: "calendar") }.tag(Tab.trip)
            GarageView()
                .tabItem { Label("Garage", systemImage: "car") }.tag(Tab.garage)
            AccountView()
                .tabItem { Label("Account", systemImage: "person.crop.circle") }.tag(Tab.account)
        }
        .tint(Theme.red)
        .sensoryFeedback(.selection, trigger: tab)
        .onOpenURL { url in
            switch url.host {
            case "map": tab = .map
            case "trip": tab = .trip
            case "garage": tab = .garage
            case "account": tab = .account
            default: tab = .varco
            }
        }
        .sheet(isPresented: $showZone) {
            NavigationStack { ZoneDetailView(zone: store.zone, city: store.city) }
        }
        .fullScreenCover(isPresented: Binding(get: { RootView.showOnboarding(onboarded) },
                                              set: { if !$0 { onboarded = true } })) {
            Onboarding {
                onboarded = true
                Task { await GateMonitor.shared.startIfReady(store: store) }
            }
        }
    }

    private static func showOnboarding(_ onboarded: Bool) -> Bool {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-showOnboarding") { return !onboarded }
        return !onboarded && !args.contains("-uitest")
    }
}
