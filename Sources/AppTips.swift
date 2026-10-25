import SwiftUI
import TipKit

/// I consigli al momento giusto (TipKit, iOS 17): tre in tutto, ognuno si vede una volta e si chiude con la X.
/// Sono riquadri dentro la pagina (TipView), mai fumetti sopra i pulsanti. Nel giro automatico delle foto
/// (-uitest) TipKit non si configura, quindi non compaiono.
enum AppTips {
    static func configure() {
        guard !ProcessInfo.processInfo.arguments.contains("-uitest") else { return }
        try? Tips.configure([.displayFrequency(.immediate), .datastoreLocation(.applicationDefault)])
    }
}

/// Viaggio, dopo la prima risposta: il guardiano accanto a Google Maps
struct StartGuardianTip: Tip {
    var title: Text { Text("Gate alerts with Google Maps") }
    var message: Text? { Text("Tap Start to get gate alerts while you use Google Maps") }
    var image: Image? { Image(systemName: "shield.lefthalf.filled") }
}

/// Mappa: cerca l'hotel per vedere se è dentro la zona
struct MapSearchTip: Tip {
    var title: Text { Text("Is your hotel inside?") }
    var message: Text? { Text("Search your hotel to see if it's inside") }
    var image: Image? { Image(systemName: "magnifyingglass") }
}

/// Account, solo se il telefono ha soltanto la voce di base
struct BetterVoiceTip: Tip {
    var title: Text { Text("Download a better voice") }
    var message: Text? { Text("A Premium or Enhanced voice reads street names more clearly.") }
    var image: Image? { Image(systemName: "waveform") }
}
