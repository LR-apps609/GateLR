import Foundation
import CoreLocation

// I dati di GateLR: città, zone, varchi, orari, fonte ufficiale. Tutto Codable, così le città
// potranno arrivare da un file JSON scaricato (e restare disponibili offline).

struct Coordinate: Codable, Hashable {
    var lat: Double
    var lon: Double
    var cl: CLLocationCoordinate2D { .init(latitude: lat, longitude: lon) }
}

/// Il rettangolo (in gradi) che contiene un perimetro: si calcola una volta quando si legge la città e
/// scarta subito i punti lontani, prima del calcolo sul poligono (centinaia di lati a Milano e Firenze)
struct BBox: Codable, Hashable {
    var minLat: Double, minLon: Double, maxLat: Double, maxLon: Double

    init(minLat: Double, minLon: Double, maxLat: Double, maxLon: Double) {
        self.minLat = minLat; self.minLon = minLon; self.maxLat = maxLat; self.maxLon = maxLon
    }

    /// nil se il perimetro è vuoto
    init?(_ points: [Coordinate]) {
        guard let first = points.first else { return nil }
        var lo = first, hi = first
        for p in points {
            if p.lat < lo.lat { lo.lat = p.lat }
            if p.lon < lo.lon { lo.lon = p.lon }
            if p.lat > hi.lat { hi.lat = p.lat }
            if p.lon > hi.lon { hi.lon = p.lon }
        }
        self.init(minLat: lo.lat, minLon: lo.lon, maxLat: hi.lat, maxLon: hi.lon)
    }

    func contains(lat: Double, lon: Double) -> Bool {
        lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon
    }

    func intersects(_ o: BBox) -> Bool {
        minLat <= o.maxLat && maxLat >= o.minLat && minLon <= o.maxLon && maxLon >= o.minLon
    }

    /// Più largo di «fraction» della sua misura per lato (0.5 = metà in più a sinistra, a destra, sopra e sotto)
    func expanded(by fraction: Double) -> BBox {
        let dLat = (maxLat - minLat) * fraction, dLon = (maxLon - minLon) * fraction
        return BBox(minLat: minLat - dLat, minLon: minLon - dLon, maxLat: maxLat + dLat, maxLon: maxLon + dLon)
    }

    /// Distanza approssimata in metri dal rettangolo (0 se dentro): mai più grande della distanza
    /// dai punti del perimetro, quindi va bene per scartare le zone lontane
    func distance(lat: Double, lon: Double) -> Double {
        let dLat = lat < minLat ? minLat - lat : (lat > maxLat ? lat - maxLat : 0)
        let dLon = lon < minLon ? minLon - lon : (lon > maxLon ? lon - maxLon : 0)
        return hypot(dLat * 111_000, dLon * 111_000 * cos(lat * .pi / 180))
    }
}

struct City: Codable, Identifiable, Hashable {
    var id: String              // "firenze"
    var name: String            // "Florence"
    var name_it: String?
    var name_de: String?
    var localizedName: String { pick(name, it: name_it, de: name_de) }
    var center: Coordinate
    var zones: [Zone]
    var status: Status
    var license: String?
    var pedestrian: [PedestrianArea]? = nil   // aree pedonali: chiuse alle auto sempre
    var cameras: [Camera]? = nil              // telecamere delle corsie bus e delle aree pedonali
    var localHolidays: [String]? = nil        // feste del patrono che valgono come festivi, "MM-DD" (es. Roma "06-29")

    /// sample = dati inventati; draft = presi dalle fonti ufficiali ma non ancora rivisti da una persona
    enum Status: String, Codable { case sample, draft, verified }
}

struct Zone: Codable, Identifiable, Hashable {
    var id: String
    var name: String            // "Sector A · Historic Centre"
    var name_it: String?
    var name_de: String?
    var kind: ZoneKind?         // tipo di zona: colore sulla mappa e logica della risposta
    /// Il nome nella lingua del telefono
    var localizedName: String { pick(name, it: name_it, de: name_de) }
    var type: ZoneKind { kind ?? (ticket != nil ? .pass : .restricted) }
    var summary: String         // il riassunto «In short», con parole nostre
    var summary_it: String?
    var summary_de: String?
    /// Il riassunto nella lingua del telefono, se c'è
    var localizedSummary: String { pick(summary, it: summary_it, de: summary_de) }
    var perimeter: [Coordinate]
    var gates: [Gate]
    var windows: [TimeWindow]   // quando i varchi sono accesi
    var freeOnHolidays: Bool?   // nil = non sappiamo: nei festivi la risposta è «non sicuro»
    /// true = nei festivi valgono gli orari della domenica (es. Padova 14–23:30, San Giovanni Valdarno chiusa tutto il giorno)
    var holidaysAsSunday: Bool? = nil
    var exemptFuels: Set<Fuel>  // es. elettriche ammesse
    var hotelCanRegister: Bool  // l'hotel dentro la zona può comunicare la targa
    var ticket: Ticket? = nil   // ZTL a pagamento (es. Area C di Milano): si entra pagando
    var bans: [EuroBan]? = nil  // divieti ambientali per carburante e classe Euro (Area B e C di Milano)
    var source: Source
    /// Le feste del patrono della città ("MM-DD"): copiate dalla città quando si legge il file (CityLoader)
    var localHolidays: [String]? = nil
    /// Calcolati una volta quando si legge la città (prepare()): rettangolo e area del perimetro
    var bounds: BBox? = nil
    var area: Double? = nil

    /// Rettangolo e area pronti: zones(at:) e la zona più vicina non rifanno i conti a ogni posizione
    mutating func prepare() {
        bounds = BBox(perimeter)
        area = Zone.polygonArea(perimeter)
    }
}

/// Un'area pedonale: le auto non entrano mai (salvo i mezzi autorizzati)
struct PedestrianArea: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var perimeter: [Coordinate]
    var bounds: BBox? = nil

    func contains(lat: Double, lon: Double) -> Bool {
        if let bounds, !bounds.contains(lat: lat, lon: lon) { return false }
        return Zone.inside(perimeter, lat: lat, lon: lon)
    }
}

/// Una telecamera fuori dalle ZTL: corsia riservata a bus e taxi, o ingresso di un'area pedonale
struct Camera: Codable, Hashable, Identifiable {
    enum Kind: String, Codable { case bus, pedestrian }
    var id: String
    var name: String
    var location: Coordinate
    var kind: Kind
}

/// Rosso: accesso vietato senza permesso · giallo: si entra con il pass · verde: zona a basse emissioni
enum ZoneKind: String, Codable, CaseIterable {
    case restricted, pass, green
    var title: String {
        switch self {
        case .restricted: L("No entry")
        case .pass: L("Pass needed")
        case .green: L("Green zone")
        }
    }
}

/// Il testo nella lingua del telefono, se c'è; altrimenti l'inglese
func pick(_ en: String, it: String?, de: String?) -> String {
    switch Locale.current.language.languageCode?.identifier {
    case "it": it ?? en
    case "de": de ?? en
    default: en
    }
}

/// Le auto con questo carburante e classe Euro fino a maxEuro non entrano dalla data «since» (AAAA-MM-GG)
struct EuroBan: Codable, Hashable {
    var fuel: Fuel
    var maxEuro: Int
    var since: String

    var date: Date {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Rome")!
        let p = since.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return .distantFuture }      // data scritta male: meglio non vietare nulla
        return c.date(from: DateComponents(year: p[0], month: p[1], day: p[2])) ?? .distantFuture
    }
}

extension Fuel {
    /// Per i divieti ambientali ibride, GPL e metano contano come benzina (da confermare città per città)
    var banGroup: Fuel? {
        switch self {
        case .petrol, .hybrid, .lpg: .petrol
        case .diesel: .diesel
        case .electric: nil
        }
    }
}

extension Zone {
    /// Il divieto che ferma questa auto a quella data, se c'è
    func ban(for vehicle: Vehicle, at date: Date) -> EuroBan? {
        guard let group = vehicle.fuel.banGroup else { return nil }
        return (bans ?? []).filter { $0.fuel == group && vehicle.euro <= $0.maxEuro && $0.date <= date }.max { $0.date < $1.date }
    }
    /// Lasciare l'auto qui è un problema? Zone vietate o a pagamento sì; zone verdi solo se l'auto è vietata
    func closes(to vehicle: Vehicle, at date: Date) -> Bool {
        type != .green || ban(for: vehicle, at: date) != nil
    }
    /// Il prossimo divieto che toccherà questa auto, se c'è
    func nextBan(for vehicle: Vehicle, after date: Date) -> EuroBan? {
        guard let group = vehicle.fuel.banGroup else { return nil }
        return (bans ?? []).filter { $0.fuel == group && vehicle.euro <= $0.maxEuro && $0.date > date }.min { $0.date < $1.date }
    }
}

/// Il biglietto d'ingresso di una ZTL a pagamento
struct Ticket: Codable, Hashable {
    var price: Double           // euro
    var howTo: String           // come si paga, con parole nostre
    var howTo_it: String?
    var howTo_de: String?
    var url: URL?
    /// Entro quando va attivato: «beforeEntry» (Bologna) o «nextDayMidnight» (Milano Area C)
    var deadline: String? = nil

    var localizedHowTo: String { pick(howTo, it: howTo_it, de: howTo_de) }

    var priceText: String { price.formatted(.currency(code: "EUR")) }
}

struct Gate: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var location: Coordinate
}

/// Una fascia oraria in cui la ZTL è attiva. Può passare la mezzanotte (ZTL notturne)
/// e può valere solo in una stagione.
struct TimeWindow: Codable, Hashable {
    var weekdays: Set<Int>      // 1 = domenica … 7 = sabato, come Calendar
    var start: Int              // minuti dalla mezzanotte
    var end: Int                // se < start, finisce il giorno dopo
    var season: Season?

    struct Season: Codable, Hashable {
        var fromMonth: Int, fromDay: Int
        var toMonth: Int, toDay: Int
    }
}

/// La prova: ogni regola mostrata ha la sua fonte e la data dell'ultimo controllo umano.
struct Source: Codable, Hashable {
    var authority: String       // "City of Florence"
    var pageURL: URL
    var ordinance: String?      // "Ordinance no. …"
    var ordinanceURL: URL?
    var quote: String?          // la frase originale, in italiano
    var quoteTranslation: String?
    var quoteTranslation_de: String?
    var pending_it: [String]?
    var pending_de: [String]?
    var checkedOn: Date         // quando abbiamo letto le fonti
    var reviewedByHuman: Bool   // la promessa: nessuna scheda «verificata» senza un controllo umano
    var pending: [String]       // punti ancora da verificare, mostrati nella scheda
    var links: [SourceLink]
}

extension Source {
    /// «City of Florence» → «Comune di Firenze»
    var localizedAuthority: String { L(authority) }
    /// La traduzione della frase del Comune (in italiano non serve: la frase è già italiana)
    var localizedTranslation: String? {
        switch Locale.current.language.languageCode?.identifier {
        case "it": nil
        case "de": quoteTranslation_de ?? quoteTranslation
        default: quoteTranslation
        }
    }
    var localizedPending: [String] {
        switch Locale.current.language.languageCode?.identifier {
        case "it": pending_it ?? pending
        case "de": pending_de ?? pending
        default: pending
        }
    }
}

struct SourceLink: Codable, Hashable {
    var title: String
    var title_it: String?
    var title_de: String?
    var url: URL
    var localizedTitle: String { pick(title, it: title_it, de: title_de) }
}

enum Fuel: String, Codable, CaseIterable, Identifiable {
    case petrol, diesel, hybrid, electric, lpg
    var id: String { rawValue }
    var label: String {
        switch self {
        case .petrol: L("Petrol")
        case .diesel: L("Diesel")
        case .hybrid: L("Hybrid")
        case .electric: L("Electric")
        case .lpg: L("LPG / methane")
        }
    }
}

struct Vehicle: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var model: String = ""
    var fuel: Fuel
    var euro: Int
    var plate: String = ""
    var isRental = false
    var make: String? = nil
    var year: Int? = nil
}

/// Marche e modelli più diffusi (Resources/Rules/cars.json) e la classe Euro probabile dall'anno
enum CarCatalog {
    struct Make: Codable, Hashable { var make: String; var models: [String] }
    private struct File: Codable { var makes: [Make] }

    static let makes: [Make] = {
        guard let url = Bundle.main.url(forResource: "cars", withExtension: "json", subdirectory: "Rules"),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode(File.self, from: data))?.makes ?? []
    }()

    /// Dall'anno di prima immatricolazione alla classe Euro (auto, valori tipici: va controllata sul libretto, campo V.9)
    static func euro(forYear y: Int) -> Int {
        switch y {
        case 2016...: 6
        case 2011...2015: 5
        case 2006...2010: 4
        case 2001...2005: 3
        case 1997...2000: 2
        case 1993...1996: 1
        default: 0
        }
    }
}

struct Permit: Codable, Identifiable, Hashable {
    enum Kind: String, Codable, CaseIterable { case hotelRegistration, resident, disabledBadge, other }
    enum Status: String, Codable { case waiting, confirmed }

    var id = UUID()
    var kind: Kind
    var cityId: String
    var zoneId: String?         // nil = tutta la città
    var vehicleId: UUID
    var from: Date
    var to: Date
    var status: Status

    func covers(zone: Zone, vehicle: Vehicle, at date: Date) -> Bool {
        vehicleId == vehicle.id && (zoneId == nil || zoneId == zone.id) && from <= date && date <= to
    }
}

extension Permit.Kind {
    var label: String {
        switch self {
        case .hotelRegistration: L("Hotel registration")
        case .resident: L("Resident permit")
        case .disabledBadge: L("Disabled badge")
        case .other: L("Other permit")
        }
    }
}

/// La multa per l'ingresso in ZTL senza permesso (art. 7 Codice della Strada): Resources/Rules/fine.json
struct FineInfo: Codable {
    var min: Int
    var max: Int
    var notes: [String]
    var notes_it: [String]?
    var notes_de: [String]?
    var status: String?

    var localizedNotes: [String] {
        switch Locale.current.language.languageCode?.identifier {
        case "it": notes_it ?? notes
        case "de": notes_de ?? notes
        default: notes
        }
    }

    static let bundled: FineInfo? = {
        guard let url = Bundle.main.url(forResource: "fine", withExtension: "json", subdirectory: "Rules"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(FineInfo.self, from: data)
    }()
}

extension Zone {
    /// «B» da «Sector B · Historic Centre»
    var letter: String { name.split(separator: "·").first.map { String($0.split(separator: " ").last ?? "") } ?? "" }
    /// «Centro storico» da «Settore B · Centro storico»
    var place: String { localizedName.split(separator: "·").dropFirst().joined(separator: "·").trimmingCharacters(in: .whitespaces) }
    /// «Settore B», «Area C», «Zona T»
    var shortName: String {
        localizedName.split(separator: "·").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? localizedName
    }

    /// Il punto è dentro il perimetro? (ray casting sulle coordinate)
    func contains(lat: Double, lon: Double) -> Bool {
        if let bounds, !bounds.contains(lat: lat, lon: lon) { return false }      // fuori dal rettangolo: niente poligono
        return Zone.inside(perimeter, lat: lat, lon: lon)
    }

    static func inside(_ perimeter: [Coordinate], lat: Double, lon: Double) -> Bool {
        var inside = false
        var j = perimeter.count - 1
        for i in perimeter.indices {
            let a = perimeter[i], b = perimeter[j]
            if (a.lat > lat) != (b.lat > lat), lon < (b.lon - a.lon) * (lat - a.lat) / (b.lat - a.lat) + a.lon {
                inside.toggle()
            }
            j = i
        }
        return inside
    }

    /// Area approssimata (gradi²): serve a scegliere il settore più piccolo quando sono uno dentro l'altro
    var roughArea: Double { area ?? Zone.polygonArea(perimeter) }

    static func polygonArea(_ perimeter: [Coordinate]) -> Double {
        var s = 0.0
        var j = perimeter.count - 1
        for i in perimeter.indices { s += (perimeter[j].lon + perimeter[i].lon) * (perimeter[j].lat - perimeter[i].lat); j = i }
        return abs(s / 2)
    }

    /// Distanza approssimata in metri dal perimetro (0 se dentro)
    func distance(lat: Double, lon: Double) -> Double {
        if contains(lat: lat, lon: lon) { return 0 }
        guard !perimeter.isEmpty else { return .infinity }
        let k = cos(lat * .pi / 180)
        return perimeter.map { p in hypot((p.lat - lat) * 111_000, (p.lon - lon) * 111_000 * k) }.min() ?? .infinity
    }
}
