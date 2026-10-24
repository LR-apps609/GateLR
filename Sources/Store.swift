import Foundation
import SwiftUI

// Lo stato dell'app: città, garage (veicoli e permessi), impostazioni. Il garage resta sul telefono.
@MainActor
final class Store: ObservableObject {
    static let shared = Store()

    @Published var cities: [City] = CityLoader.shared
    @Published var cityId: String = "firenze" {
        didSet { if !city.zones.contains(where: { $0.id == zoneId }) { zoneId = city.zones[0].id } }
    }
    @Published var zoneId: String = "firenze-b"
    @Published var vehicles: [Vehicle] { didSet { save() } }
    @Published var activeVehicleId: UUID? { didSet { save() } }
    @Published var permits: [Permit] { didSet { save() } }
    @Published var hotelInside = true { didSet { save() } }
    @Published var alertsOn = true { didSet { save() } }
    @Published var alertDistance: Double = 500 { didSet { save() } }
    @Published var trips: [Trip] { didSet { save() } }
    /// I soggiorni in hotel dentro la ZTL: date e stato della registrazione della targa (chiave: Place.key)
    @Published var stays: [String: HotelStay] = [:] { didSet { save() } }
    /// Il diario dei passaggi: quando sei stato vicino o dentro una ZTL attiva (solo sul telefono)
    @Published var log: [LogEntry] = [] { didSet { save() } }
    /// Il posto scelto nella pagina Varco (indirizzo, hotel, piazza); nil = solo la città
    @Published var place: Place?

    let engine = RuleEngine()
    private let key = "garage.v1"

    private struct Saved: Codable {
        var vehicles: [Vehicle], activeVehicleId: UUID?, permits: [Permit]
        var hotelInside: Bool, alertsOn: Bool, alertDistance: Double
        var trips: [Trip]?
        var stays: [String: HotelStay]?
        var log: [LogEntry]?
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: key), let s = try? JSONDecoder().decode(Saved.self, from: data) {
            vehicles = s.vehicles; activeVehicleId = s.activeVehicleId; permits = s.permits; trips = s.trips ?? []; stays = s.stays ?? [:]; log = s.log ?? []
            hotelInside = s.hotelInside; alertsOn = s.alertsOn; alertDistance = s.alertDistance
        } else {
            vehicles = [SampleData.rental]; activeVehicleId = SampleData.rental.id; permits = []; trips = []
        }
    }

    private func save() {
        let s = Saved(vehicles: vehicles, activeVehicleId: activeVehicleId, permits: permits,
                      hotelInside: hotelInside, alertsOn: alertsOn, alertDistance: alertDistance, trips: trips, stays: stays, log: log)
        if let data = try? JSONEncoder().encode(s) { UserDefaults.standard.set(data, forKey: key) }
    }

    var city: City { cities.first { $0.id == cityId } ?? cities[0] }
    var zone: Zone { city.zones.first { $0.id == zoneId } ?? city.zones[0] }
    var vehicle: Vehicle { vehicles.first { $0.id == activeVehicleId } ?? vehicles.first ?? SampleData.rental }

    func answer(at date: Date = Date(), zone: Zone? = nil, hotelInside: Bool? = nil) -> Answer {
        let z = zone ?? self.zone
        // Un permesso vale solo nella sua città: la registrazione dell'hotel a Firenze non apre l'Area C di Milano
        let city = cities.first { $0.zones.contains { $0.id == z.id } }?.id
        engine.answer(zone: z, vehicle: vehicle, permits: permits.filter { $0.cityId == city }, hotelInside: hotelInside ?? self.hotelInside, at: date)
    }

    /// Le zone che contengono il punto, dalla più piccola (es. Area C dentro Area B)
    func zones(at c: Coordinate) -> [(city: City, zone: Zone)] {
        cities.flatMap { city in city.zones.filter { $0.contains(lat: c.lat, lon: c.lon) }.map { (city, $0) } }
            .sorted { $0.zone.roughArea < $1.zone.roughArea }
    }

    /// L'area pedonale che contiene il punto, se c'è
    func pedestrianArea(at c: Coordinate) -> PedestrianArea? {
        for city in cities { if let a = city.pedestrian?.first(where: { $0.contains(lat: c.lat, lon: c.lon) }) { return a } }
        return nil
    }

    /// La zona più vicina (se il punto è fuori da tutte), con la distanza in metri
    func nearestZone(to c: Coordinate) -> (city: City, zone: Zone, meters: Double)? {
        cities.flatMap { city in city.zones.map { (city: city, zone: $0, meters: $0.distance(lat: c.lat, lon: c.lon)) } }
            .min { $0.meters < $1.meters }
    }

    /// La città più vicina al punto (per spostare la pagina sulla città giusta)
    func nearestCity(to c: Coordinate) -> City? {
        cities.min { hypot($0.center.lat - c.lat, $0.center.lon - c.lon) < hypot($1.center.lat - c.lat, $1.center.lon - c.lon) }
    }

    /// Gli ultimi posti cercati (scorciatoie in Viaggio)
    @Published var recent: [Place] = {
        guard let d = UserDefaults.standard.data(forKey: "recent.places") else { return [] }
        return (try? JSONDecoder().decode([Place].self, from: d)) ?? []
    }() {
        didSet { if let d = try? JSONEncoder().encode(recent) { UserDefaults.standard.set(d, forKey: "recent.places") } }
    }

    /// Sceglie il posto: la pagina passa alla sua città e alla zona che lo contiene
    func select(_ place: Place?) {
        self.place = place
        guard let place else { return }
        if place.address != "" || place.name != L("My position") {
            recent = [place] + recent.filter { $0.key != place.key }.prefix(5)
        }
        if let hit = zones(at: place.location).first {
            cityId = hit.city.id; zoneId = hit.zone.id
        } else if let city = nearestCity(to: place.location), city.id != cityId {
            cityId = city.id; zoneId = city.zones[0].id
        }
    }
}

/// Un indirizzo o un luogo cercato (hotel, piazza, parcheggio)
struct Place: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var address: String
    var location: Coordinate
}

extension Place {
    /// Identifica lo stesso posto anche se cercato due volte
    var key: String { "\(name)|\((location.lat * 10_000).rounded())|\((location.lon * 10_000).rounded())" }
}

/// Il soggiorno in un hotel dentro la ZTL: la targa va registrata per ogni giorno, compreso quello di partenza
struct HotelStay: Codable, Hashable {
    enum Status: String, Codable { case notAsked, asked, confirmed }
    var arrival: Date
    var departure: Date
    var status: Status = .notAsked
    var permitId: UUID? = nil

    /// I giorni da coprire, dal giorno di arrivo a quello di partenza compresi
    var days: [Date] {
        let c = Calendar.current
        var d = c.startOfDay(for: arrival), out: [Date] = []
        let last = c.startOfDay(for: max(departure, arrival))
        while d <= last && out.count < 31 { out.append(d); d = c.date(byAdding: .day, value: 1, to: d) ?? last.addingTimeInterval(1) }
        return out
    }
}

/// Una riga del diario dei passaggi
struct LogEntry: Codable, Hashable, Identifiable {
    enum Kind: String, Codable { case nearGate, entered }
    var id = UUID()
    var date: Date
    var kind: Kind
    var zoneId: String
    var zoneName: String
    var gateName: String?
    var verdict: String              // «Non entrare», «A una condizione»…
    var plate: String
}

extension Store {
    /// Aggiunge al diario, senza doppioni nella stessa mezz'ora per la stessa zona
    func record(_ kind: LogEntry.Kind, zone: Zone, gate: Gate? = nil, verdict: Verdict) {
        if let last = log.first(where: { $0.zoneId == zone.id && $0.kind == kind }), Date().timeIntervalSince(last.date) < 30 * 60 { return }
        log.insert(LogEntry(date: Date(), kind: kind, zoneId: zone.id, zoneName: zone.localizedName, gateName: gate?.name,
                            verdict: verdict.short, plate: vehicle.plate), at: 0)
        if log.count > 500 { log.removeLast(log.count - 500) }
    }
}

/// Un viaggio salvato: hotel, arrivo, partenza, auto
struct Trip: Codable, Hashable, Identifiable {
    var id = UUID()
    var hotel: Place?
    var hotelName: String
    var arrival: Date
    var departure: Date
    var vehicleId: UUID?
}

/// Le città incluse nell'app: Resources/Cities/*.json, costruiti dagli script in Tools/
enum CityLoader {
    static func decode(_ data: Data) throws -> City {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return try d.decode(City.self, from: data)
    }

    /// Letti una volta sola (il widget li chiede a ogni voce della sua cronologia).
    /// Se dal sito sono arrivati dati più nuovi di quelli dentro l'app, si usano quelli.
    static let shared: [City] = best()

    static func best() -> [City] {
        let mine = bundled()
        guard let newer = downloaded(), (downloadedVersion ?? "") > (bundledVersion ?? "") else { return mine }
        // Le città scaricate sostituiscono quelle dell'app con lo stesso id; le altre restano
        let ids = Set(newer.map(\.id))
        return (newer + mine.filter { !ids.contains($0.id) }).sorted { $0.name < $1.name }
    }

    static func bundled() -> [City] {
        let urls = (Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "Cities") ?? [])
            .filter { $0.lastPathComponent != "manifest.json" }
        let cities = urls.compactMap { try? decode(Data(contentsOf: $0)) }.sorted { $0.name < $1.name }
        return cities.isEmpty ? [SampleData.florence] : cities
    }

    struct Manifest: Codable {
        struct Entry: Codable { var id: String; var file: String; var sha256: String }
        var version: String
        var schema: Int
        var cities: [Entry]
    }

    static var bundledVersion: String? {
        guard let url = Bundle.main.url(forResource: "manifest", withExtension: "json", subdirectory: "Cities"),
              let data = try? Data(contentsOf: url) else { return nil }
        return (try? JSONDecoder().decode(Manifest.self, from: data))?.version
    }

    /// Dove si salvano le città scaricate (Application Support/Cities)
    static var downloadDir: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("Cities", isDirectory: true)
    }
    static var downloadedVersion: String? { UserDefaults.standard.string(forKey: "cities.version") }

    static func downloaded() -> [City]? {
        guard let dir = downloadDir,
              let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return nil }
        let cities = files.filter { $0.pathExtension == "json" }.compactMap { try? decode(Data(contentsOf: $0)) }
        return cities.isEmpty ? nil : cities
    }
}
