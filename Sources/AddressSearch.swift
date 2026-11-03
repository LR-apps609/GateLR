import Foundation
import MapKit

/// Ricerca di indirizzi e luoghi con Apple Maps (gratis): suggerimenti mentre scrivi, poi la posizione esatta.
@MainActor
final class AddressSearch: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query = "" { didSet { update() } }
    @Published private(set) var results: [MKLocalSearchCompletion] = []
    @Published private(set) var failed = false

    private let completer = MKLocalSearchCompleter()
    /// 1.19.5: un suggerimento già scelto non si cerca di nuovo (al più 60, solo in memoria). I suggerimenti invece vanno
    /// ad Apple a ogni lettera come prima: con l'attesa e la memoria dei suggerimenti il giro delle foto si fermava a «Pa»
    /// (corsa 41582622000) e le misure non erano più veloci
    private var places: [String: Place] = [:]

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    /// I suggerimenti vengono prima dalla zona della città scelta
    func focus(on city: City) {
        completer.region = MKCoordinateRegion(center: city.center.cl, latitudinalMeters: 30_000, longitudinalMeters: 30_000)
    }

    private func update() {
        let q = query.trimmingCharacters(in: .whitespaces)
        failed = false
        if q.count < 2 { results = []; completer.cancel() } else { completer.queryFragment = q }
    }

    func clear() { query = ""; results = [] }

    /// Dal suggerimento alla posizione
    func resolve(_ completion: MKLocalSearchCompletion) async -> Place? {
        let key = completion.title + "|" + completion.subtitle
        if let hit = places[key] { return hit }
        guard let item = try? await MKLocalSearch(request: MKLocalSearch.Request(completion: completion)).start().mapItems.first else {
            failed = true
            return nil
        }
        let c = item.placemark.coordinate
        let place = Place(name: completion.title,
                          address: completion.subtitle.isEmpty ? (item.placemark.title ?? "") : completion.subtitle,
                          location: Coordinate(lat: c.latitude, lon: c.longitude))
        if places.count > 60 { places.removeAll() }
        places[key] = place
        return place
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let found = Array(completer.results.prefix(6))
        Task { @MainActor in self.results = found }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in self.results = []; self.failed = true }
    }
}
