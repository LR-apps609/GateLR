import Foundation
import SwiftUI

// Lo stato dell'app: città, garage (veicoli e permessi), impostazioni. Il garage resta sul telefono.
@MainActor
final class Store: ObservableObject {
    static let shared = Store()

    @Published var cities: [City] = [SampleData.florence]
    @Published var cityId: String = SampleData.florence.id
    @Published var vehicles: [Vehicle] { didSet { save() } }
    @Published var activeVehicleId: UUID? { didSet { save() } }
    @Published var permits: [Permit] { didSet { save() } }
    @Published var hotelInside = true { didSet { save() } }
    @Published var alertsOn = true { didSet { save() } }
    @Published var alertDistance: Double = 500 { didSet { save() } }

    let engine = RuleEngine()
    private let key = "garage.v1"

    private struct Saved: Codable {
        var vehicles: [Vehicle], activeVehicleId: UUID?, permits: [Permit]
        var hotelInside: Bool, alertsOn: Bool, alertDistance: Double
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: key), let s = try? JSONDecoder().decode(Saved.self, from: data) {
            vehicles = s.vehicles; activeVehicleId = s.activeVehicleId; permits = s.permits
            hotelInside = s.hotelInside; alertsOn = s.alertsOn; alertDistance = s.alertDistance
        } else {
            vehicles = [SampleData.rental]; activeVehicleId = SampleData.rental.id; permits = []
        }
    }

    private func save() {
        let s = Saved(vehicles: vehicles, activeVehicleId: activeVehicleId, permits: permits,
                      hotelInside: hotelInside, alertsOn: alertsOn, alertDistance: alertDistance)
        if let data = try? JSONEncoder().encode(s) { UserDefaults.standard.set(data, forKey: key) }
    }

    var city: City { cities.first { $0.id == cityId } ?? cities[0] }
    var zone: Zone { city.zones[0] }
    var vehicle: Vehicle { vehicles.first { $0.id == activeVehicleId } ?? vehicles.first ?? SampleData.rental }

    func answer(at date: Date = Date(), zone: Zone? = nil) -> Answer {
        engine.answer(zone: zone ?? self.zone, vehicle: vehicle, permits: permits, hotelInside: hotelInside, at: date)
    }
}
