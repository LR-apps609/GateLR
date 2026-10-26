import Foundation

// «Targa automatica»: dalla targa italiana a marca, modello, alimentazione e classe Euro con un servizio a pagamento.
// NON è approvata: qui c'è solo il contratto e un sostituto spento, nessuna richiesta in rete.
// Opzioni, costi e il piccolo server che servirebbe per nascondere la chiave: docs/targa-automatica.md

/// I dati di un veicolo trovati dalla targa
struct PlateLookupResult: Equatable {
    var make: String?
    var model: String?
    var fuel: Fuel?
    var euro: Int?
    var firstRegistrationYear: Int?
}

enum PlateLookupError: Error, Equatable {
    case notEnabled         // la funzione non è attiva
    case notFound
    case unavailable        // servizio irraggiungibile o quota finita
}

/// Chi cerca una targa. Un'implementazione vera parlerebbe solo con il nostro server (mai con il fornitore
/// direttamente: la chiave a pagamento non deve stare nell'app)
protocol PlateLookup {
    var isAvailable: Bool { get }
    func lookup(plate: String) async throws -> PlateLookupResult
}

/// Il sostituto spento: non è disponibile e non chiama nessuno
struct DisabledPlateLookup: PlateLookup {
    var isAvailable: Bool { false }
    func lookup(plate: String) async throws -> PlateLookupResult { throw PlateLookupError.notEnabled }
}

enum PlateLookupService {
    /// Quello in uso nell'app: per ora sempre spento
    static let current: any PlateLookup = DisabledPlateLookup()
}
