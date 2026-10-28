import Foundation

/// Le impostazioni dell'app in un posto solo
enum AppConfig {
    /// L'indirizzo a cui arrivano «Segnala un errore» e «Segnala un bug». Segnaposto: da sostituire con l'indirizzo
    /// di assistenza vero prima della pubblicazione (mai un indirizzo personale)
    static let supportEmail = "support@example.com"

    /// «1.17.0 (41)»
    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] as? String ?? "–") (\(info?["CFBundleVersion"] as? String ?? "–"))"
    }
}
