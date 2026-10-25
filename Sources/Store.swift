import Foundation
import SwiftUI

// Lo stato dell'app: città, garage (veicoli e permessi), impostazioni. Il garage resta sul telefono.
@MainActor
final class Store: ObservableObject {
    static let shared = Store()

    /// Le città si leggono in sottofondo (Store.load): fino ad allora c'è la città di esempio e RootView mostra
    /// la schermata d'avvio. Così il primo fotogramma arriva subito, invece di uno schermo nero di qualche secondo.
    @Published var cities: [City] = [SampleData.florence] { didSet { citiesVersion &+= 1 } }
    /// Vero quando le città vere sono pronte
    @Published private(set) var loaded = false
    /// Cambia a ogni nuovo elenco di città: le forme pronte per la mappa si ricalcolano solo allora
    private(set) var citiesVersion = 0
    private var loading: Task<Void, Never>?
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
        loading = Task { await self.load() }
    }

    /// Lettura e decodifica dei JSON delle città fuori dal thread principale (milano e firenze sono grandi)
    private func load() async {
        let fresh = await Task.detached(priority: .userInitiated) { CityLoader.shared }.value
        cities = fresh
        if !city.zones.contains(where: { $0.id == zoneId }) { zoneId = city.zones[0].id }
        loaded = true
    }

    /// Aspetta che le città vere siano pronte (avvisi, Siri, CarPlay, giro delle foto)
    func whenLoaded() async {
        await loading?.value
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
        return engine.answer(zone: z, vehicle: vehicle, permits: permits.filter { $0.cityId == city }, hotelInside: hotelInside ?? self.hotelInside, at: date)
    }

    /// Le zone che contengono il punto, dalla più piccola (es. Area C dentro Area B)
    func zones(at c: Coordinate) -> [(city: City, zone: Zone)] {
        Store.zones(at: c, in: cities)
    }

    /// Prima il rettangolo della zona (calcolato alla lettura), poi il poligono; l'area è già pronta
    nonisolated static func zones(at c: Coordinate, in cities: [City]) -> [(city: City, zone: Zone)] {
        var hits: [(city: City, zone: Zone)] = []
        for city in cities {
            for z in city.zones where z.contains(lat: c.lat, lon: c.lon) { hits.append((city: city, zone: z)) }
        }
        return hits.count < 2 ? hits : hits.sorted { $0.zone.roughArea < $1.zone.roughArea }
    }

    /// L'area pedonale che contiene il punto, se c'è
    func pedestrianArea(at c: Coordinate) -> PedestrianArea? {
        for city in cities { if let a = city.pedestrian?.first(where: { $0.contains(lat: c.lat, lon: c.lon) }) { return a } }
        return nil
    }

    /// La zona più vicina (se il punto è fuori da tutte), con la distanza in metri
    func nearestZone(to c: Coordinate) -> (city: City, zone: Zone, meters: Double)? {
        Store.nearestZone(to: c, in: cities)
    }

    /// Le zone in ordine di distanza dal loro rettangolo: appena il rettangolo è più lontano della zona
    /// migliore trovata, le altre non possono essere più vicine e i loro perimetri non si guardano
    nonisolated static func nearestZone(to c: Coordinate, in cities: [City]) -> (city: City, zone: Zone, meters: Double)? {
        typealias Candidate = (city: City, zone: Zone, low: Double)
        var ranked: [Candidate] = []
        for city in cities {
            for z in city.zones {
                let low: Double = z.bounds?.distance(lat: c.lat, lon: c.lon) ?? 0
                ranked.append((city: city, zone: z, low: low))
            }
        }
        ranked.sort { $0.low < $1.low }
        var best: (city: City, zone: Zone, meters: Double)? = nil
        for r in ranked {
            if let b = best, r.low > b.meters { break }
            let m: Double = r.zone.distance(lat: c.lat, lon: c.lon)
            if let b = best, b.meters <= m { continue }
            best = (city: r.city, zone: r.zone, meters: m)
        }
        return best
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
        var city = try d.decode(City.self, from: data)
        // Il motore riceve solo la zona: le feste del patrono della città le porta lei
        if let local = city.localHolidays {
            for i in city.zones.indices { city.zones[i].localHolidays = local }
        }
        prepare(&city)
        return city
    }

    /// Rettangoli e aree calcolati una volta qui, in sottofondo: le ricerche a ogni posizione scartano
    /// subito le zone lontane senza scorrere i loro perimetri
    static func prepare(_ city: inout City) {
        for i in city.zones.indices { city.zones[i].prepare() }
        if var areas = city.pedestrian {
            for i in areas.indices { areas[i].bounds = BBox(areas[i].perimeter) }
            city.pedestrian = areas
        }
    }

    /// Letti una volta sola (il widget li chiede a ogni voce della sua cronologia).
    /// Se dal sito sono arrivati dati più nuovi di quelli dentro l'app, si usano quelli.
    static let shared: [City] = best()

    static func best() -> [City] {
        guard (downloadedVersion ?? "") > (bundledVersion ?? ""), let newer = downloaded() else { return bundled() }
        // Le città scaricate sostituiscono quelle dell'app con lo stesso id; le altre restano
        // (e quelle sostituite non si decodificano nemmeno: si risparmia metà del lavoro all'avvio)
        let ids = Set(newer.map(\.id))
        let mine = bundled(skipping: ids)
        return (newer + mine.filter { !ids.contains($0.id) }).sorted { $0.name < $1.name }
    }

    /// I file sono «<id>.json»: quelli in «skipping» non si leggono
    static func bundled(skipping ids: Set<String> = []) -> [City] {
        let urls = (Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "Cities") ?? [])
            .filter { $0.lastPathComponent != "manifest.json" && !ids.contains($0.deletingPathExtension().lastPathComponent) }
        let cities = urls.compactMap { try? decode(Data(contentsOf: $0)) }.sorted { $0.name < $1.name }
        return cities.isEmpty && ids.isEmpty ? [SampleData.florence] : cities
    }

    struct Manifest: Codable {
        struct Entry: Codable { var id: String; var file: String; var sha256: String }
        var version: String
        var schema: Int
        var cities: [Entry]
    }

    /// Letta una volta sola (Account la mostra a ogni aggiornamento della pagina)
    static let bundledVersion: String? = {
        guard let url = Bundle.main.url(forResource: "manifest", withExtension: "json", subdirectory: "Cities"),
              let data = try? Data(contentsOf: url) else { return nil }
        return (try? JSONDecoder().decode(Manifest.self, from: data))?.version
    }()

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
