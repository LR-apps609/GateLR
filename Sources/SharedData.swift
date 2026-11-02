import Foundation

/// 1.19.3: quello che app e widget condividono nel contenitore dell'App Group (group.it.ledion.GateLR): le città
/// scaricate (CityLoader.downloadDir) e il veicolo scelto con i permessi. Prima il widget leggeva solo i dati dentro
/// l'app e non sapeva il veicolo: dopo un aggiornamento correttivo mostrava il dato vecchio, e il verde «ZTL non attiva»
/// anche con dati scaduti. Senza App Group (firma che non lo permette) tutto torna come prima: dati dell'app e auto a noleggio.
/// Compilato nell'app e nel widget.
enum SharedData {
    static let groupId = "group.it.ledion.GateLR"

    /// La cartella condivisa; nil se l'App Group non c'è (firma senza la capacità)
    static var container: URL? { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupId) }

    /// Le impostazioni condivise: solo se la cartella condivisa c'è davvero (senza, UserDefaults(suiteName:) scriverebbe
    /// in una cartella dell'app che il widget non vede)
    static var defaults: UserDefaults? { container == nil ? nil : UserDefaults(suiteName: groupId) }

    /// Il veicolo scelto, i permessi e la zona scelta nell'app: quello che serve al widget per la risposta
    struct Garage: Codable, Equatable {
        var vehicle: Vehicle
        var permits: [Permit]
        var zoneId: String?
    }

    static let garageKey = "widget.garage.v1"

    /// Salva il garage per il widget; vero se è cambiato (allora l'app ricarica i widget)
    @discardableResult
    static func save(_ g: Garage) -> Bool {
        guard let defaults, let data = try? JSONEncoder().encode(g) else { return false }
        if defaults.data(forKey: garageKey) == data { return false }
        defaults.set(data, forKey: garageKey)
        return true
    }

    static func garage() -> Garage? {
        guard let data = defaults?.data(forKey: garageKey) else { return nil }
        return try? JSONDecoder().decode(Garage.self, from: data)
    }
}

/// La risposta del widget per una zona (testabile): la stessa del motore dell'app per il veicolo scelto e i suoi
/// permessi, con i colori di GateLR. Rosso non entrare, giallo a una condizione o «?» (non sicuro, festivo non
/// confermato, dati più vecchi di 120 giorni, fonte non ufficiale), verde puoi entrare a varchi accesi (esente o
/// permesso), grigio ZTL non attiva. Prima: solo «attiva / non attiva», verde anche con dati scaduti.
struct WidgetAnswer: Equatable {
    enum Tone: Equatable { case red, amber, green, grey }

    var tone: Tone
    var symbol: String
    var title: String
    /// I dati della zona non sono stati controllati da più di 120 giorni
    var stale: Bool
    var gatesOn: Bool
    var next: Date?
    /// Il veicolo della risposta (nil = non lo sappiamo: auto a noleggio come nell'app appena installata)
    var vehicleName: String?

    static func make(zone: Zone, cityId: String?, garage: SharedData.Garage?, at date: Date, engine: RuleEngine = RuleEngine()) -> WidgetAnswer {
        let vehicle = garage?.vehicle ?? SampleData.rental
        // Un permesso vale solo nella sua città e nella sua zona (Permit.covers), come in Store.answer
        let permits = (garage?.permits ?? []).filter { $0.cityId == cityId }
        let a = engine.answer(zone: zone, vehicle: vehicle, permits: permits, hotelInside: false, at: date)
        let age = engine.calendar.dateComponents([.day], from: zone.source.checkedOn, to: engine.now()).day ?? 0
        let stale = age > engine.staleAfterDays
        var w = WidgetAnswer(tone: .amber, symbol: "questionmark", title: L("Check the sign"), stale: stale,
                             gatesOn: a.gatesOn, next: a.nextChange, vehicleName: garage?.vehicle.name)
        switch a.verdict.shown(unofficial: zone.isUnofficial) {
        case .no:
            w.tone = .red; w.symbol = "xmark"; w.title = L(zone.isUnofficial ? "Probably not" : "Don't enter")
        case .conditional:
            w.tone = .amber; w.symbol = "exclamationmark"; w.title = L("On one condition")
        case .unsure:
            w.tone = .amber; w.symbol = "questionmark"; w.title = L(stale ? "Data to recheck" : "Check the sign")
        case .yes:
            if a.gatesOn { w.tone = .green; w.symbol = "checkmark"; w.title = L("You can enter") }
            else { w.tone = .grey; w.symbol = "moon.zzz"; w.title = L("ZTL not active") }
        }
        return w
    }
}
