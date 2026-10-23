import Foundation
import CoreLocation

// I dati di GateLR: città, zone, varchi, orari, fonte ufficiale. Tutto Codable, così le città
// potranno arrivare da un file JSON scaricato (e restare disponibili offline).

struct Coordinate: Codable, Hashable {
    var lat: Double
    var lon: Double
    var cl: CLLocationCoordinate2D { .init(latitude: lat, longitude: lon) }
}

struct City: Codable, Identifiable, Hashable {
    var id: String              // "firenze"
    var name: String            // "Florence"
    var center: Coordinate
    var zones: [Zone]
    var status: Status
    var license: String?

    /// sample = dati inventati; draft = presi dalle fonti ufficiali ma non ancora rivisti da una persona
    enum Status: String, Codable { case sample, draft, verified }
}

struct Zone: Codable, Identifiable, Hashable {
    var id: String
    var name: String            // "Historic Centre · Sector A"
    var summary: String         // il riassunto «In short», con parole nostre
    var perimeter: [Coordinate]
    var gates: [Gate]
    var windows: [TimeWindow]   // quando i varchi sono accesi
    var freeOnHolidays: Bool?   // nil = non sappiamo: nei festivi la risposta è «non sicuro»
    var exemptFuels: Set<Fuel>  // es. elettriche ammesse
    var hotelCanRegister: Bool  // l'hotel dentro la zona può comunicare la targa
    var source: Source
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
    var checkedOn: Date         // quando abbiamo letto le fonti
    var reviewedByHuman: Bool   // la promessa: nessuna scheda «verificata» senza un controllo umano
    var pending: [String]       // punti ancora da verificare, mostrati nella scheda
    var links: [SourceLink]
}

struct SourceLink: Codable, Hashable {
    var title: String
    var url: URL
}

enum Fuel: String, Codable, CaseIterable, Identifiable {
    case petrol, diesel, hybrid, electric, lpg
    var id: String { rawValue }
    var label: String {
        switch self {
        case .petrol: "Petrol"
        case .diesel: "Diesel"
        case .hybrid: "Hybrid"
        case .electric: "Electric"
        case .lpg: "LPG / methane"
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
        case .hotelRegistration: "Hotel registration"
        case .resident: "Resident permit"
        case .disabledBadge: "Disabled badge"
        case .other: "Other permit"
        }
    }
}

/// La multa per l'ingresso in ZTL senza permesso (art. 7 Codice della Strada): Resources/Rules/fine.json
struct FineInfo: Codable {
    var min: Int
    var max: Int
    var notes: [String]
    var status: String?

    static let bundled: FineInfo? = {
        guard let url = Bundle.main.url(forResource: "fine", withExtension: "json", subdirectory: "Rules"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(FineInfo.self, from: data)
    }()
}

extension Zone {
    /// «B» da «Sector B · Historic Centre»
    var letter: String { name.split(separator: "·").first.map { String($0.split(separator: " ").last ?? "") } ?? "" }
    /// «Historic Centre» da «Sector B · Historic Centre»
    var place: String { name.split(separator: "·").dropFirst().joined(separator: "·").trimmingCharacters(in: .whitespaces) }
    var shortName: String { "Sector \(letter)" }
}
