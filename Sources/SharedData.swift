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
    /// Il veicolo della risposta (nil = non lo sappiamo: auto a noleggio come nell'app appena installata). 1.19.4: mai
    /// la targa, nemmeno se scritta nel nome (il widget si vede anche a telefono bloccato)
    var vehicleName: String?
    /// 2.1: lo stato della RispostaFinale (per la riga sotto: niente «ZTL non attiva» due volte)
    var stato: Stato = .controllaCartello

    static func tone(_ t: Tono) -> Tone {
        switch t {
        case .rosso: .red
        case .giallo: .amber
        case .verde, .spento: .green
        case .grigio, .neutro: .grey
        }
    }

    static func make(zone: Zone, cityId: String?, garage: SharedData.Garage?, at date: Date, engine: RuleEngine = RuleEngine()) -> WidgetAnswer {
        let vehicle = garage?.vehicle ?? SampleData.rental
        // Un permesso vale solo nella sua città e nella sua zona (Permit.covers), come in Store.answer
        let permits = (garage?.permits ?? []).filter { $0.cityId == cityId }
        // 1.20.1: la stessa verifica dei dati dell'app (mai verde né grigio da una regola non verificata o cambiata)
        let a = engine.trustedAnswer(zone: zone, vehicle: vehicle, permits: permits, hotelInside: false, at: date)
        let age = engine.age(zone.source.checkedOn)
        let stale = age > engine.staleAfterDays
        // 2.1: la RispostaFinale della zona (shared/risposta-finale.md): parola, forma e colore come nell'app.
        // «ZTL non attiva» ha la sua parola e il colore del token unico (RispostaFinale.stateOff, oggi verde)
        let f = RispostaFinale.of(a, zone: zone)
        var w = WidgetAnswer(tone: Self.tone(f.color), symbol: f.symbol, title: f.title, stale: stale,
                             gatesOn: a.gatesOn, next: a.nextChange, vehicleName: garage.map { PlatePrivacy.displayName($0.vehicle) })
        w.stato = f.stato
        return w
    }
}
