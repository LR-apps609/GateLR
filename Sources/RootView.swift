import SwiftUI

enum Tab: Hashable { case now, map, trip, garage }

struct RootView: View {
    @EnvironmentObject var store: Store
    @State private var tab: Tab = .now
    @State private var showZone = false

    var body: some View {
        TabView(selection: $tab) {
            NowView(showZone: $showZone, tab: $tab)
                .tabItem { Label("Now", systemImage: "smallcircle.filled.circle") }.tag(Tab.now)
            MapScreen(showZone: $showZone, tab: $tab)
                .tabItem { Label("Map", systemImage: "map") }.tag(Tab.map)
            TripView()
                .tabItem { Label("Trip", systemImage: "calendar") }.tag(Tab.trip)
            GarageView()
                .tabItem { Label("Garage", systemImage: "car") }.tag(Tab.garage)
        }
        .tint(Theme.red)
        .sheet(isPresented: $showZone) {
            NavigationStack { ZoneDetailView(zone: store.zone, city: store.city) }
        }
    }
}
