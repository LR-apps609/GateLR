import Foundation
import SwiftUI

// Lo stato dell'app: città, garage (veicoli e permessi), impostazioni. Il garage resta sul telefono.
@MainActor
final class Store: ObservableObject {
    static let shared = Store()

    @Published var cities: [City] = CityLoader.bundled()
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
    /// Il posto scelto nella pagina Varco (indirizzo, hotel, piazza); nil = solo la città
    @Published var place: Place?

    let engine = RuleEngine()
    private let key = "garage.v1"

    private struct Saved: Codable {
        var vehicles: [Vehicle], activeVehicleId: UUID?, permits: [Permit]
        var hotelInside: Bool, alertsOn: Bool, alertDistance: Double
        var trips: [Trip]?
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: key), let s = try? JSONDecoder().decode(Saved.self, from: data) {
            vehicles = s.vehicles; activeVehicleId = s.activeVehicleId; permits = s.permits
            hotelInside = s.hotelInside; alertsOn = s.alertsOn; alertDistance = s.alertDistance
            trips = s.trips ?? []
        } else {
            vehicles = [SampleData.rental]; activeVehicleId = SampleData.rental.id; permits = []; trips = []
        }
    }

    private func save() {
        let s = Saved(vehicles: vehicles, activeVehicleId: activeVehicleId, permits: permits,
                      hotelInside: hotelInside, alertsOn: alertsOn, alertDistance: alertDistance, trips: trips)
        if let data = try? JSONEncoder().encode(s) { UserDefaults.standard.set(data, forKey: key) }
    }

    var city: City { cities.first { $0.id == cityId } ?? cities[0] }
    var zone: Zone { city.zones.first { $0.id == zoneId } ?? city.zones[0] }
    var vehicle: Vehicle { vehicles.first { $0.id == activeVehicleId } ?? vehicles.first ?? SampleData.rental }

    func answer(at date: Date = Date(), zone: Zone? = nil, hotelInside: Bool? = nil) -> Answer {
        engine.answer(zone: zone ?? self.zone, vehicle: vehicle, permits: permits, hotelInside: hotelInside ?? self.hotelInside, at: date)
    }

    /// Le zone che contengono il punto, dalla più piccola (es. Area C dentro Area B)
    func zones(at c: Coordinate) -> [(city: City, zone: Zone)] {
        cities.flatMap { city in city.zones.filter { $0.contains(lat: c.lat, lon: c.lon) }.map { (city, $0) } }
            .sorted { $0.zone.roughArea < $1.zone.roughArea }
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

    /// Sceglie il posto: la pagina passa alla sua città e alla zona che lo contiene
    func select(_ place: Place?) {
        self.place = place
        guard let place else { return }
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

    static func bundled() -> [City] {
        let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "Cities") ?? []
        let cities = urls.compactMap { try? decode(Data(contentsOf: $0)) }.sorted { $0.name < $1.name }
        return cities.isEmpty ? [SampleData.florence] : cities
    }
}
