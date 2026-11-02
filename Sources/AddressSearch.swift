import Foundation
import MapKit

/// Ricerca di indirizzi e luoghi con Apple Maps (gratis): suggerimenti mentre scrivi, poi la posizione esatta.
/// 1.19.5: i suggerimenti già visti tornano subito (anche cancellando una lettera), Apple riceve il testo solo dopo una
/// breve pausa nella scrittura, e un posto già trovato non si cerca di nuovo
@MainActor
final class AddressSearch: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query = "" { didSet { update() } }
    @Published private(set) var results: [MKLocalSearchCompletion] = []
    @Published private(set) var failed = false

    private let completer = MKLocalSearchCompleter()
    /// L'attesa dopo l'ultima lettera prima di chiedere ad Apple
    nonisolated static let debounce: Duration = .milliseconds(150)
    private var pending: Task<Void, Never>?
    /// Vero quando i suggerimenti mostrati vengono dalla memoria: quelli in ritardo di Apple non li sostituiscono
    private var fromCache = false
    /// Suggerimenti per «zona|testo» (al più 60) e posti per suggerimento (al più 60): solo in memoria, per questa schermata
    private var cache: [String: [MKLocalSearchCompletion]] = [:]
    private var places: [String: Place] = [:]
    private var regionKey = ""

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    /// I suggerimenti vengono prima dalla zona della città scelta
    func focus(on city: City) {
        completer.region = MKCoordinateRegion(center: city.center.cl, latitudinalMeters: 30_000, longitudinalMeters: 30_000)
        regionKey = city.id
    }

    nonisolated static func key(region: String, query: String) -> String {
        region + "|" + query.lowercased()
    }

    private func update() {
        let q = query.trimmingCharacters(in: .whitespaces)
        failed = false
        pending?.cancel()
        if q.count < 2 { results = []; fromCache = false; completer.cancel(); return }
        // Già visti: subito, e Apple non serve
        if let hit = cache[Self.key(region: regionKey, query: q)] { results = hit; fromCache = true; completer.cancel(); return }
        fromCache = false
        pending = Task { [weak self] in
            try? await Task.sleep(for: Self.debounce)
            guard !Task.isCancelled, let self else { return }
            self.completer.queryFragment = q
        }
    }

    func clear() { pending?.cancel(); query = ""; results = [] }

    /// Dal suggerimento alla posizione (un suggerimento già scelto non si cerca di nuovo)
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
        let fragment = completer.queryFragment
        Task { @MainActor in
            if !found.isEmpty {
                if self.cache.count > 60 { self.cache.removeAll() }
                self.cache[Self.key(region: self.regionKey, query: fragment)] = found
            }
            guard !self.fromCache else { return }
            self.results = found
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            guard !self.fromCache else { return }
            self.results = []; self.failed = true
        }
    }
}
