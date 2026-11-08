import Foundation
import CoreLocation
import UIKit

/// 2.0 (bug B13, B27, B75, B144): quando una posizione vale per una risposta o per un avviso. Con la posizione
/// «approssimativa» di iOS (reducedAccuracy) il punto può essere spostato di chilometri: mai usarlo come se fosse esatto
/// (la risposta dell'Area B mentre sei in Area C), né far partire un guardiano che poi scarta ogni posizione in silenzio.
enum LocationGate {
    /// Oltre questa incertezza (metri) una posizione non dà una risposta «dove sei»
    static let answerAccuracy: Double = 150
    /// Il guardiano e la guida vogliono di più (i varchi distano poche decine di metri)
    static let guardAccuracy: Double = 80
    /// La chiave di NSLocationTemporaryUsageDescriptionDictionary (project.yml) per la richiesta di precisione temporanea
    static let purposeKey = "GateLRGates"

    /// Cosa si può fare con la posizione adesso
    enum Readiness: Equatable {
        /// Permessa e precisa
        case ready
        /// Non ancora chiesta
        case notDetermined
        /// Negata o vietata (Impostazioni → GateLR → Posizione)
        case denied
        /// Permessa ma «approssimativa»: va chiesta la precisione (o cambiata in Impostazioni)
        case approximate
    }

    nonisolated static func readiness(status: CLAuthorizationStatus, accuracy: CLAccuracyAuthorization) -> Readiness {
        switch status {
        case .notDetermined: return .notDetermined
        case .denied, .restricted: return .denied
        case .authorizedAlways, .authorizedWhenInUse: return accuracy == .reducedAccuracy ? .approximate : .ready
        @unknown default: return .denied
        }
    }

    /// Una posizione buona per dire «sei qui»: precisione piena, incertezza entro «limit» metri, non più vecchia di «maxAge»
    nonisolated static func usable(_ l: CLLocation?, accuracy: CLAccuracyAuthorization, limit: Double = answerAccuracy,
                                   maxAge: TimeInterval = 120, now: Date = Date()) -> Bool {
        guard let l, accuracy == .fullAccuracy else { return false }
        return l.horizontalAccuracy >= 0 && l.horizontalAccuracy <= limit && now.timeIntervalSince(l.timestamp) <= maxAge
    }

    /// Le Impostazioni di iOS sulla pagina di GateLR (posizione, notifiche)
    @MainActor static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
