import SwiftUI

// Il punto d'ingresso dell'app, da solo in questo file: i test automatici compilano tutto il resto.
@main
struct GateLRApp: App {
    @StateObject private var store = Store.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .task {
                    // Nel giro automatico con le foto niente richieste di permessi
                    guard !ProcessInfo.processInfo.arguments.contains("-uitest") else { return }
                    await GateMonitor.shared.start(store: store)
                }
        }
    }
}
