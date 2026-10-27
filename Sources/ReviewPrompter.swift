import Foundation

/// La richiesta di una recensione su App Store (SwiftUI, @Environment(\.requestReview) di StoreKit): nessuna domanda
/// nostra prima (linea guida 5.6.1 di Apple), solo la richiesta di iOS, che decide da sé se mostrarla.
/// Quando: circa 2 secondi dopo che la prima ricerca di un posto o di un hotel ha dato la sua risposta in Varco.
/// Poi al massimo una volta per versione dell'app e non prima di 120 giorni dall'ultima.
/// Mai durante la navigazione, la presentazione o le pagine delle multe (la scheda Varco deve essere quella in vista),
/// mai nel giro automatico delle foto (-uitest). Le date e la versione dell'ultima richiesta stanno in UserDefaults.
enum ReviewPrompter {
    static let minDays = 120.0
    /// Quanto aspettare dopo la risposta, perché si veda prima della richiesta
    static let delay: Duration = .seconds(2)
    static let versionKey = "reviewRequestVersion"
    static let dateKey = "reviewRequestDate"

    /// Le regole, senza UserDefaults: «blocked» se ora non è il momento (navigazione, presentazione, multe, -uitest)
    static func shouldRequest(lastVersion: String?, lastDate: Date?, version: String, now: Date, blocked: Bool) -> Bool {
        guard !blocked else { return false }
        // Mai chiesta: è la prima ricerca con risposta
        guard let lastVersion, let lastDate else { return true }
        return lastVersion != version && now.timeIntervalSince(lastDate) >= minDays * 86_400
    }

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// Se adesso si può chiedere (con quello che è salvato)
    static func shouldRequest(now: Date = Date(), blocked: Bool, defaults: UserDefaults = .standard,
                              arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        shouldRequest(lastVersion: defaults.string(forKey: versionKey), lastDate: defaults.object(forKey: dateKey) as? Date,
                      version: appVersion, now: now, blocked: blocked || arguments.contains("-uitest"))
    }

    /// Dopo aver chiesto
    static func recordRequest(now: Date = Date(), defaults: UserDefaults = .standard) {
        defaults.set(appVersion, forKey: versionKey)
        defaults.set(now, forKey: dateKey)
    }

    /// L'indirizzo per scrivere una recensione, se l'app ha già il suo numero su App Store (impostazione APP_STORE_ID,
    /// vuota finché l'app non è pubblicata: allora la riga «Lascia una recensione» di Tu non c'è)
    static var writeReviewURL: URL? {
        guard let id = (Bundle.main.object(forInfoDictionaryKey: "GateLRAppStoreID") as? String)?
            .trimmingCharacters(in: .whitespaces), !id.isEmpty, id.allSatisfy(\.isNumber) else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(id)?action=write-review")
    }
}
