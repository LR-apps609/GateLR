import SwiftUI
import UIKit

/// Le tre schede di GateLR 2.0: «Varco» (la risposta), «Mappa» (al centro, la più grande) e «Tu» (tutto il resto)
enum Tab: Hashable { case varco, map, you }

/// Le pagine di «Tu»
enum YouRoute: Hashable { case garage, trip, fines, learn, settings, subscription }

/// Dove si va nell'app: la scheda scelta, le pagine aperte in «Tu» e la presentazione
@MainActor final class AppRouter: ObservableObject {
    @Published var tab: Tab = .varco
    @Published var youPath: [YouRoute] = []
    /// La presentazione 2.0 a tutto schermo: al primo avvio e da Tu → Cosa sono le ZTL → «Rivedi la presentazione»
    @Published var showIntro = false

    /// Una pagina di «Tu», aperta da qualsiasi scheda
    func open(_ route: YouRoute) {
        youPath = [route]
        tab = .you
    }

    /// gatelr://varco (widget, Live Activity), gatelr://map, gatelr://trip (widget), gatelr://garage, gatelr://account
    func handle(_ url: URL) {
        let (tab, route) = Self.destination(for: url.host)
        youPath = route.map { [$0] } ?? []
        self.tab = tab
    }

    /// I vecchi indirizzi delle cinque schede portano alle tre nuove (il sito e i widget già installati li usano ancora)
    nonisolated static func destination(for host: String?) -> (Tab, YouRoute?) {
        switch host?.lowercased() {
        case "map", "mappa": (.map, nil)
        case "trip", "viaggio": (.you, .trip)
        case "garage": (.you, .garage)
        case "fines", "multe": (.you, .fines)
        case "learn": (.you, .learn)
        case "settings": (.you, .settings)
        case "account", "you", "tu": (.you, nil)
        default: (.varco, nil)
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

    var body: some View {
        // Finché le città non sono pronte (si leggono in sottofondo) si vede la stessa schermata d'avvio di iOS
        Group {
            if store.loaded { tabs } else { LaunchSplash() }
        }
        .onOpenURL { router.handle($0) }
    }

    private var tabs: some View {
        TabView(selection: $router.tab) {
            VarcoView(showZone: $showZone, tab: $router.tab)
                .tabItem { Label("Gate", systemImage: "smallcircle.filled.circle") }.tag(Tab.varco)
            // La mappa al centro, con il simbolo più grande: è il punto forte dell'app
            MapScreen(showZone: $showZone, tab: $router.tab)
                .tabItem { Label { Text("Map") } icon: { Image(uiImage: Self.mapIcon) } }.tag(Tab.map)
            YouView(showZone: $showZone, tab: $router.tab)
                .tabItem { Label("You", systemImage: "person.crop.circle") }.tag(Tab.you)
        }
        .environmentObject(router)
        .tint(Theme.red)
        .sensoryFeedback(.selection, trigger: router.tab)
        .sheet(isPresented: $showZone) {
            NavigationStack { ZoneDetailView(zone: store.zone, city: store.city) }
                .readableScrollWidth()
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
        // La presentazione 2.0: al primo avvio, poi solo se la chiedi. Alla fine parte la posizione (la richiesta di iOS
        // arriva dopo la presentazione, non prima)
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

    /// Il simbolo della mappa più grande degli altri due (le schede di iOS non lo ingrandiscono da sole)
    private static let mapIcon: UIImage = {
        let config = UIImage.SymbolConfiguration(pointSize: 27, weight: .semibold)
        return UIImage(systemName: "map.fill", withConfiguration: config) ?? UIImage()
    }()
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
