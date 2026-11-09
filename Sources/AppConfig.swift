import Foundation

/// Le impostazioni dell'app in un posto solo
enum AppConfig {
    /// L'indirizzo a cui arrivano «Segnala un errore» e «Segnala un bug». Segnaposto: da sostituire con l'indirizzo
    /// di assistenza vero prima della pubblicazione (mai un indirizzo personale)
    static let supportEmail = "support@example.com"

    /// 2.2 Gli strumenti di sviluppo (modalità prova, navigatore interno; funzioni 28 e 32 di P23-Funzioni): solo nelle
    /// build di sviluppo. Debug sempre (simulatore, giro delle foto); Release solo con GATELR_DEV_TOOLS = YES in
    /// Config/Local.xcconfig (mai nelle .ipa della CI né per gli store)
    static var devTools: Bool {
        #if DEBUG
        return true
        #else
        return (Bundle.main.object(forInfoDictionaryKey: "GateLRDevTools") as? String)?.uppercased() == "YES"
        #endif
    }

    /// 2.2 (funzione 28, TOGLI): il navigatore interno di GateLR non è più nell'interfaccia. Resta dietro questo flag di
    /// sviluppo (Impostazioni → sezione di sviluppo, o l'argomento di avvio -devInternalNavigator YES)
    static var internalNavigator: Bool {
        devTools && UserDefaults.standard.bool(forKey: devNavigatorKey)
    }
    static let devNavigatorKey = "devInternalNavigator"

    /// «1.17.0 (41)»
    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] as? String ?? "–") (\(info?["CFBundleVersion"] as? String ?? "–"))"
    }
}
