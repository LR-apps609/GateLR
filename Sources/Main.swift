import SwiftUI

// Il punto d'ingresso dell'app, da solo in questo file: i test automatici compilano tutto il resto.
@main
struct GateLRApp: App {
    @StateObject private var store = Store.shared

    init() {
        // I consigli (TipKit) una volta sola all'avvio; mai nel giro automatico delle foto
        AppTips.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                // Solo per il giro automatico delle foto: forza il tema scuro
                .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("-uiDark") ? .dark : nil)
                // Tutto dopo che le città sono pronte (si leggono in sottofondo, vedi Store.load)
                .task {
                    // Live Activity rimaste da prima (app chiusa con il guardiano o la guida accesi): via subito
                    await Guardian.endOrphanActivities()
                    await store.whenLoaded()
                    Self.uiTestPlace(store)
                    // Siri impara i nomi delle zone («posso entrare a Firenze Settore A…») dalle città appena lette
                    GateLRShortcuts.updateAppShortcutParameters()
                    SpeechVoice.prepare()
                    await GateMonitor.shared.startIfReady(store: store)
                }
                .task {
                    await store.whenLoaded()
                    await CityUpdater.shared.checkIfDue(store: store)
                }
        }
    }

    /// Solo per le foto automatiche: «-uiPlace "Duomo di Milano" 45.4641 9.1919» sceglie un posto senza cercarlo in rete
    @MainActor private static func uiTestPlace(_ store: Store) {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-uiPlace"), args.count > i + 3,
              let lat = Double(args[i + 2]), let lon = Double(args[i + 3]) else { return }
        store.select(Place(name: args[i + 1], address: "", location: Coordinate(lat: lat, lon: lon)))
    }
}
