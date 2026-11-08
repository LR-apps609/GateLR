import SwiftUI
import UIKit

// Il punto d'ingresso dell'app, da solo in questo file: i test automatici compilano tutto il resto.
@main
struct GateLRApp: App {
    @StateObject private var store = Store.shared
    // 2.0 (B42): il rilancio in sottofondo di iOS per un avviso ad app chiusa passa da qui, non dalla finestra
    @UIApplicationDelegateAdaptor(GateLRAppDelegate.self) private var appDelegate

    init() {
        // 1.19.4: la telemetria di Mapbox spenta di serie, prima che si crei una mappa (poi decide chi usa l'app)
        MapboxTelemetry.applyDefault()
        // I consigli (TipKit) una volta sola all'avvio; mai nel giro automatico delle foto
        AppTips.configure()
        // 1.19.3: il tocco su un avviso apre «Parcheggia fuori» anche quando l'avviso ha riaperto l'app
        ThreatAlerts.shared.install()
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
                    Self.uiTestUnofficial(store)
                    Self.uiTestMode(store)
                    Self.uiTestVehicle(store)
                    Self.uiTestPlate(store)
                    Self.uiTestAt(store)
                    Self.uiTestPlace(store)
                    Self.uiTestGuardian(store)
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

    /// Solo per le foto automatiche (-uitest): «-uiUnofficial firenze» segna le zone di quella città come prese da una
    /// fonte non ufficiale, per fotografare l'avviso «Fonte non ufficiale» (i dati veri non cambiano)
    @MainActor private static func uiTestUnofficial(_ store: Store) {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-uitest"), let i = args.firstIndex(of: "-uiUnofficial"), args.count > i + 1,
              let c = store.cities.firstIndex(where: { $0.id == args[i + 1] }) else { return }
        var city = store.cities[c]
        for z in city.zones.indices {
            city.zones[z].source.official = false
            city.zones[z].source.unofficialSource = UnofficialSource(name: "example.org", url: URL(string: "https://example.org")!)
        }
        store.cities[c] = city
    }

    /// Solo per le foto automatiche: «-uiTestMode 43.7765 11.2830» accende la modalità prova intorno a quel punto
    /// (varchi sul bordo, senza rete), per fotografare la striscia «Modalità prova attiva» e la zona di prova
    @MainActor private static func uiTestMode(_ store: Store) {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-uitest"), let i = args.firstIndex(of: "-uiTestMode"), args.count > i + 2,
              let lat = Double(args[i + 1]), let lon = Double(args[i + 2]) else { return }
        store.testMode = TestZone.make(at: Coordinate(lat: lat, lon: lon))
        store.cityId = TestZone.cityId
        store.zoneId = TestZone.zoneId
    }

    /// Solo per le foto automatiche (1.19.0): «-uiVehicle diesel 1» mette quel veicolo nel garage e lo sceglie
    /// (Palazzo Vecchio di notte con un diesel Euro 1: lo Scudo Verde lo vieta anche a Settore A spento)
    @MainActor private static func uiTestVehicle(_ store: Store) {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-uitest"), let i = args.firstIndex(of: "-uiVehicle"), args.count > i + 2,
              let fuel = Fuel(rawValue: args[i + 1]), let euro = Int(args[i + 2]) else { return }
        let v = Vehicle(name: "Prova", fuel: fuel, euro: euro)
        store.vehicles = [v]
        store.activeVehicleId = v.id
    }

    /// Solo per le foto automatiche (1.19.4): «-uiPlate GX482KM» mette quella targa al veicolo scelto e due righe nel diario
    /// dei passaggi, per fotografare il testo da condividere SENZA la targa (nell'app la riga la mostra, sul telefono)
    @MainActor private static func uiTestPlate(_ store: Store) {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-uitest"), let i = args.firstIndex(of: "-uiPlate"), args.count > i + 1 else { return }
        var v = store.vehicle
        v.plate = args[i + 1]
        if let k = store.vehicles.firstIndex(where: { $0.id == v.id }) { store.vehicles[k] = v } else { store.vehicles = [v] }
        store.activeVehicleId = v.id
        guard let zone = store.cities.first(where: { $0.id == "firenze" })?.zones.first else { return }
        let now = Date()
        store.log = [
            LogEntry(date: now.addingTimeInterval(-3_600), kind: .entered, zoneId: zone.id, zoneName: zone.localizedName,
                     gateName: zone.gates.first?.name, verdict: L("Don't enter"), plate: v.plate),
            LogEntry(date: now.addingTimeInterval(-86_400), kind: .nearGate, zoneId: zone.id, zoneName: zone.localizedName,
                     gateName: zone.gates.dropFirst().first?.name, verdict: L("Don't enter"), plate: v.plate),
        ]
    }

    /// Solo per le foto automatiche (1.19.0): «-uiAt 22:00» sceglie nel chip quell'ora (di Roma) del prossimo martedì,
    /// mercoledì o giovedì non festivo: la foto non dipende dall'ora in cui gira il giro
    @MainActor private static func uiTestAt(_ store: Store) {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-uitest"), let i = args.firstIndex(of: "-uiAt"), args.count > i + 1 else { return }
        let parts = args[i + 1].split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return }
        let cal = RuleEngine.rome
        var day = cal.startOfDay(for: Date())
        for _ in 0..<14 {
            day = cal.date(byAdding: .day, value: 1, to: day) ?? day
            let w = cal.component(.weekday, from: day)
            if (3...5).contains(w) && !ItalianHolidays.isHoliday(day, calendar: cal) { break }
        }
        store.when = cal.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: day)
    }

    /// Solo per le foto automatiche (1.19.3): «-uiGuardian 43.9333 10.9167 90» accende il guardiano in quel punto e in
    /// quella direzione (senza GPS né navigatore), per lo stato a riposo e l'avviso dentro l'app
    @MainActor private static func uiTestGuardian(_ store: Store) {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-uitest"), let i = args.firstIndex(of: "-uiGuardian"), args.count > i + 3,
              let lat = Double(args[i + 1]), let lon = Double(args[i + 2]), let course = Double(args[i + 3]) else { return }
        Guardian.shared.startDemo(at: Coordinate(lat: lat, lon: lon), course: course, store: store)
        // 1.19.5: il giro simulato del test delle misure (-uiGuardianDrive), spento nel giro delle foto
        Misure.startGuardianDrive(from: Coordinate(lat: lat, lon: lon), course: course)
    }

    /// Solo per le foto automatiche: «-uiPlace "Duomo di Milano" 45.4641 9.1919» sceglie un posto senza cercarlo in rete
    @MainActor private static func uiTestPlace(_ store: Store) {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-uiPlace"), args.count > i + 3,
              let lat = Double(args[i + 2]), let lon = Double(args[i + 3]) else { return }
        store.select(Place(name: args[i + 1], address: "", location: Coordinate(lat: lat, lon: lon)))
    }
}

/// 2.0 (B42): quando iOS rilancia GateLR in sottofondo per un evento di CLMonitor (app chiusa da iOS), la finestra non si
/// apre e il .task di RootView non parte: senza questo il monitor «gates» non veniva ricreato e l'avviso non arrivava.
/// Qui, prima della UI, si ricrea (GateMonitor.startIfReady non parte due volte)
final class GateLRAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let args = ProcessInfo.processInfo.arguments
        if GateMonitor.startsAtLaunch(onboarded: UserDefaults.standard.bool(forKey: "onboarded"), uitest: args.contains("-uitest")) {
            Task { @MainActor in
                ThreatAlerts.shared.install()
                let store = Store.shared
                await store.whenLoaded()
                await GateMonitor.shared.startIfReady(store: store)
            }
        }
        return true
    }
}
