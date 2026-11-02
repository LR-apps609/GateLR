import Foundation
import ActivityKit

/// Quello che la Live Activity (schermata di blocco e Dynamic Island) mostra durante la guida.
/// Questo file è compilato sia nell'app sia nel widget.
struct DriveAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var symbol: String          // la freccia della prossima manovra
        var distance: String        // «350 m»
        var instruction: String     // «Svolta a destra in Via Roma»
        var warning: String?        // «Settore A tra 400 m: Non entrare»
        var eta: Date?
        /// guardiano: «no» non entrare, «cond» con condizioni o «?», «clear» nessuna ZTL attiva davanti (grigio),
        /// «none» non conosciamo le ZTL del posto (neutro). «ok» (verde) non lo manda più nessuno dalla 1.19.3
        var level: String? = nil
        var zone: String? = nil     // guardiano: il nome corto della zona («Settore A»)
    }
    var destination: String
}
