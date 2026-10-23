import SwiftUI

// Il punto d'ingresso dell'app, da solo in questo file: i test automatici compilano tutto il resto.
@main
struct GateLRApp: App {
    @StateObject private var store = Store.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .task { await GateMonitor.shared.start(store: store) }
        }
    }
}
