import SwiftUI
import UIKit

/// 2.2 «Struttura» (tavole P24-Navigazione, P23-Funzioni): quattro schede, come Android. «Adesso» (la risposta qui e
/// ora), «Mappa», «Viaggio» (pianificare l'arrivo) e «Aiuto» (cartello, multe, diario, impara). Garage, permessi e
/// Impostazioni stanno dietro l'icona del veicolo in alto, la fotocamera del cartello accanto, in ogni scheda
enum Tab: Hashable { case now, map, trip, help }

/// Le pagine dietro l'icona del veicolo (foglio «Garage e impostazioni»)
enum AccountRoute: Hashable { case garage, settings, privacy, about }

/// Le pagine di «Aiuto»
enum HelpRoute: Hashable { case sign, fineGuide, fineScan, log, learn }

/// Dove si va nell'app: la scheda scelta, le pagine aperte in «Aiuto», il foglio del veicolo e la presentazione
@MainActor final class AppRouter: ObservableObject {
    @Published var tab: Tab = .now
    @Published var helpPath: [HelpRoute] = []
    /// Il foglio dietro l'icona del veicolo e le sue pagine
    @Published var showAccount = false
    @Published var accountPath: [AccountRoute] = []
    /// «Leggi il cartello» dalla fotocamera in alto, da ogni scheda
    @Published var showSign = false
    /// La modalità «In auto» a tutto schermo (tavola I-InAuto)
    @Published var inCar = false
    /// La presentazione 2.0 a tutto schermo: al primo avvio e da Aiuto → «Rivedi la presentazione»
    @Published var showIntro = false

    /// Dove porta un indirizzo gatelr://
    enum Destination: Equatable {
        case tab(Tab)
        case help(HelpRoute)
        /// Il foglio del veicolo, su una sua pagina o sull'elenco (nil)
        case account(AccountRoute?)
    }

    /// Una pagina dietro l'icona del veicolo, da qualsiasi scheda
    func open(_ route: AccountRoute) {
        accountPath = [route]
        showAccount = true
    }

    /// Una pagina di «Aiuto», da qualsiasi scheda
    func open(_ route: HelpRoute) {
        showAccount = false
        helpPath = [route]
        tab = .help
    }

    func go(_ d: Destination) {
        switch d {
        case .tab(let t):
            showAccount = false
            if t == .help { helpPath = [] }
            tab = t
        case .help(let r): open(r)
        case .account(let r):
            accountPath = r.map { [$0] } ?? []
            showAccount = true
        }
    }

    /// gatelr://adesso (widget, Live Activity; anche il vecchio gatelr://varco), gatelr://map, gatelr://trip (widget),
    /// gatelr://guardian, gatelr://multe, gatelr://cartello, gatelr://garage, gatelr://account
    func handle(_ url: URL) {
        // gatelr://park?zone=…&lat=…&lon=… (1.19.3, il tocco su un avviso): «Parcheggia fuori» per quella zona
        if url.host?.lowercased() == "park" { ThreatAlerts.shared.open(url); return }
        go(Self.destination(for: url.host))
    }

    /// I vecchi indirizzi delle cinque e delle tre schede portano alle quattro nuove (il sito e i widget già installati
    /// li usano ancora): «varco» e «now» ad Adesso, «you»/«tu»/«account» al foglio del veicolo
    nonisolated static func destination(for host: String?) -> Destination {
        switch host?.lowercased() {
        case "map", "mappa": .tab(.map)
        case "trip", "viaggio", "guardian", "guardiano": .tab(.trip)
        case "help", "aiuto": .tab(.help)
        case "fines", "multe": .help(.fineGuide)
        case "log", "diario": .help(.log)
        case "learn", "impara": .help(.learn)
        case "cartello", "sign": .help(.sign)
        case "garage": .account(.garage)
        case "settings", "impostazioni": .account(.settings)
        case "privacy": .account(.privacy)
        case "account", "you", "tu": .account(nil)
        default: .tab(.now)
        }
    }

    /// La posizione della scheda nella barra (per il rimbalzo dell'icona): 0 Adesso, 1 Mappa, 2 Viaggio, 3 Aiuto
    nonisolated static func index(of tab: Tab) -> Int {
        switch tab {
        case .now: 0
        case .map: 1
        case .trip: 2
        case .help: 3
        }
    }

    /// La versione della presentazione: chi ha visto solo una versione più vecchia (o nessuna, perché era già
    /// «onboarded» prima della 2.0) la vede una volta dopo l'aggiornamento. Si alza solo con una presentazione nuova
    nonisolated static let introVersion = 2

    /// La presentazione al primo avvio, o una volta dopo l'aggiornamento a una presentazione nuova (introSeen: la
    /// versione già vista, «introVersionSeen»; 0 = nessuna), poi mai più (-intro2: sempre, per il video su GitHub;
    /// -showOnboarding: anche nel giro automatico delle foto; -uitest: mai, se no copre le schermate)
    nonisolated static func showIntroAtLaunch(onboarded: Bool, introSeen: Int = introVersion, arguments: [String]) -> Bool {
        if arguments.contains("-intro2") { return true }
        if arguments.contains("-showOnboarding") { return !onboarded }
        if arguments.contains("-uitest") { return false }
        return !onboarded || introSeen < introVersion
    }
}

struct RootView: View {
    @EnvironmentObject var store: Store
    @AppStorage("onboarded") private var onboarded = false
    /// La versione della presentazione già vista (0 = nessuna, anche per chi era già entrato prima della 2.0)
    @AppStorage("introVersionSeen") private var introSeen = 0
    @StateObject private var router = AppRouter()
    @State private var showZone = false
    @State private var whatsNew = false
    @ObservedObject private var alerts = ThreatAlerts.shared
    @State private var driving = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        // Finché le città non sono pronte (si leggono in sottofondo) si vede la stessa schermata d'avvio di iOS
        Group {
            if store.loaded { tabs } else { LaunchSplash() }
        }
        // 1.19.5: il contatore dei fotogrammi, solo nel test delle misure (-uitest -uiFps)
        .overlay(alignment: .topLeading) {
            if Misure.fps {
                FrameMeter().frame(width: 280, height: 12).allowsHitTesting(false)
            }
            // 1.20.4: il contatore della memoria, solo nel test delle misure (-uitest -uiMemory)
            if Misure.memory {
                MemoryMeter().frame(width: 200, height: 12).padding(.top, 14).allowsHitTesting(false)
            }
        }
        .onOpenURL { router.handle($0) }
    }

    private var tabs: some View {
        TabView(selection: $router.tab) {
            VarcoView(showZone: $showZone, tab: $router.tab)
                .tabItem { Label("Now", systemImage: "smallcircle.filled.circle") }.tag(Tab.now)
            // La mappa con il simbolo più grande: è il punto forte dell'app
            MapScreen(showZone: $showZone, tab: $router.tab)
                .tabItem { Label { Text("Map") } icon: { Image(uiImage: Self.mapIcon) } }.tag(Tab.map)
            TripView(showZone: $showZone, tab: $router.tab)
                .readableScrollWidth()
                .tabItem { Label("Trip", systemImage: "suitcase.rolling.fill") }.tag(Tab.trip)
            HelpView()
                .tabItem { Label("Help", systemImage: "questionmark.circle") }.tag(Tab.help)
        }
        // «Modalità prova attiva» in cima a ogni scheda finché la modalità prova è accesa
        .testModeBar()
        // 1.19.3: l'avviso del guardiano o della guida con l'app aperta (al posto della notifica): tocco = parcheggi fuori
        .overlay(alignment: .top) {
            if let b = alerts.banner {
                ThreatBannerView(banner: b, onTap: { alerts.openBanner() }, onClose: { alerts.dismissBanner() })
                    .padding(.top, 4)
                    // 2.0 (B125): con «Riduci movimento» solo una dissolvenza
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: alerts.banner)
        // Il tocco su un avviso (notifica o banner): «Parcheggia fuori» per la zona dell'avviso
        .sheet(item: $alerts.parkFor) { place in
            ScrollView {
                ParkOutsideCard(destination: place, arrival: Date(), onStart: { target in
                    alerts.parkFor = nil
                    Task {
                        try? await Task.sleep(for: .milliseconds(450))
                        await DriveSession.shared.start(to: target, store: store)
                        driving = DriveSession.shared.active
                    }
                }, onGuardian: { target, navigator in
                    alerts.parkFor = nil
                    Guardian.shared.start(to: target, with: navigator, store: store)
                })
                .padding(16)
            }
            .background(Theme.ground)
            .presentationDetents([.medium, .large])
            .environmentObject(store)
        }
        .fullScreenCover(isPresented: $driving) { DriveView().environmentObject(store) }
        // 2.0 (B13): il guardiano non è partito (o si è fermato) per la posizione negata o approssimativa
        .modifier(GuardianNoticeAlert())
        // 2.0 (B68): al ritorno dalle Impostazioni di iOS si rileggono i permessi (posizione e notifiche)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await GateMonitor.shared.refreshPermissions() } }
        }
        .environmentObject(router)
        // 2.3: i pulsanti e la scheda scelta nel colore del testo (chiari su Notte, scuri su Giorno); il rosso del marchio
        // solo nel logo e per «Non entrare»
        .tint(Theme.ink)
        .sensoryFeedback(.selection, trigger: router.tab)
        // Il piccolo rimbalzo dell'icona della scheda scelta (simboli SF: rimbalzo di sistema; mappa: scala 1 → 1,12 → 1)
        .onChange(of: router.tab) { _, tab in
            TabBarBounce.play(index: AppRouter.index(of: tab), symbol: tab != .map)
        }
        // 2.2: Garage, permessi e Impostazioni dietro l'icona del veicolo in alto
        .sheet(isPresented: $router.showAccount) {
            AccountView()
                .environmentObject(store)
                .environmentObject(router)
                .testModeBar()
        }
        // 2.2: «Leggi il cartello» dalla fotocamera in alto, da ogni scheda
        .sheet(isPresented: $router.showSign) {
            NavigationStack {
                SignReaderView()
                    .readableScrollWidth()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(L("Close")) { router.showSign = false }
                                .accessibilityIdentifier("sign.close")
                        }
                    }
            }
            .environmentObject(store)
        }
        // 2.2: la modalità «In auto» (tavola I-InAuto)
        .fullScreenCover(isPresented: $router.inCar) {
            InCarView()
                .environmentObject(store)
                .environmentObject(router)
        }
        .sheet(isPresented: $showZone) {
            NavigationStack { ZoneDetailView(zone: store.zone, city: store.city) }
                .readableScrollWidth()
                .testModeBar()
        }
        // «Novità»: una volta sola dopo ogni aggiornamento, mai al primo avvio (c'è la presentazione)
        .sheet(isPresented: $whatsNew) {
            WhatsNewView { whatsNew = false }
                .readableFrame(640)
                .background(Theme.ground.ignoresSafeArea())
        }
        .task {
            if AppRouter.showIntroAtLaunch(onboarded: onboarded, introSeen: introSeen, arguments: ProcessInfo.processInfo.arguments) {
                router.showIntro = true
            } else if WhatsNewView.shouldShow(onboarded: onboarded) {
                try? await Task.sleep(for: .milliseconds(500))      // dopo che la pagina è comparsa
                whatsNew = true
            }
        }
        // La presentazione 2.0: al primo avvio, poi solo se la chiedi. Alla fine partono gli avvisi con i permessi già dati
        // (nessuna richiesta di iOS all'apertura: le chiedono «Attiva gli avvisi», «Usa la mia posizione», guida e guardiano)
        .fullScreenCover(isPresented: $router.showIntro) {
            Intro2View {
                router.showIntro = false
                // Vista: non ricompare più da sola (né al prossimo avvio né al prossimo aggiornamento)
                introSeen = max(introSeen, AppRouter.introVersion)
                if !onboarded {
                    onboarded = true
                    Task { await GateMonitor.shared.startIfReady(store: store) }
                }
            }
            .environmentObject(store)
            .environmentObject(router)
            .readableFrame(640)
            .background(Notte.navy.ignoresSafeArea())
        }
    }

    /// Il simbolo della mappa più grande degli altri (le schede di iOS non lo ingrandiscono da sole)
    private static let mapIcon: UIImage = {
        let config = UIImage.SymbolConfiguration(pointSize: 27, weight: .semibold)
        return UIImage(systemName: "map.fill", withConfiguration: config) ?? UIImage()
    }()
}

/// 2.0 (B13): «Serve la posizione precisa per i varchi», con «Apri Impostazioni» e, se il viaggio non era ancora
/// partito, «Naviga comunque» (il navigatore senza guardiano). Osserva solo GuardianNotice, non il guardiano
private struct GuardianNoticeAlert: ViewModifier {
    @ObservedObject private var notice = GuardianNotice.shared

    func body(content: Content) -> some View {
        content.alert(L("Precise location is needed for the gates"),
                      isPresented: Binding(get: { notice.pending != nil }, set: { if !$0 { notice.pending = nil } }),
                      presenting: notice.pending) { p in
            Button(L("Open Settings")) { notice.pending = nil; LocationGate.openSettings() }
            if let navigator = p.navigator {
                Button(L("Navigate anyway")) { notice.pending = nil; navigator.open(to: p.place) }
            }
            Button(L("Cancel"), role: .cancel) { notice.pending = nil }
        } message: { p in
            Text(verbatim: p.message)
        }
    }
}

/// La stessa schermata d'avvio di iOS (UILaunchScreen in project.yml): fondo blu e logo al centro
struct LaunchSplash: View {
    var body: some View {
        ZStack {
            Color("LaunchBackground").ignoresSafeArea()
            Image("LaunchLogo").accessibilityHidden(true)
        }
        .accessibilityLabel("GateLR")
    }
}
