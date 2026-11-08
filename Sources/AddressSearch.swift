import Foundation
import MapKit
import Combine

/// Ricerca di indirizzi e luoghi con Apple Maps (gratis): suggerimenti mentre scrivi, poi la posizione esatta.
@MainActor
final class AddressSearch: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query = "" { didSet { update() } }
    @Published private(set) var results: [MKLocalSearchCompletion] = []
    @Published private(set) var failed = false

    /// 1.20.2: il suggerimento scelto con Invio (subito, o appena arriva): le pagine lo ricevono come un tocco
    let picks = PassthroughSubject<MKLocalSearchCompletion, Never>()
    private var pickWhenReady = false

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

    /// 2.0 (B131): tutta l'Italia, quando non sappiamo ancora dove vai (né città scelta né posizione)
    static let italy = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 41.9, longitude: 12.5),
                                          latitudinalMeters: 1_300_000, longitudinalMeters: 1_100_000)
    func focusOnItaly() { completer.region = Self.italy }

    private func update() {
        let q = query.trimmingCharacters(in: .whitespaces)
        failed = false
        pickWhenReady = false
        if q.count < 2 { results = []; completer.cancel() } else { completer.queryFragment = q }
    }

    func clear() { query = ""; results = []; pickWhenReady = false }

    /// 1.20.2: «Riprova» dopo una ricerca senza risposta: la stessa domanda di nuovo ad Apple
    func retry() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { return }
        failed = false
        completer.cancel()
        completer.queryFragment = ""
        completer.queryFragment = q
    }

    /// 1.20.2: Invio (il tasto «Cerca» della tastiera): il primo suggerimento, come toccarlo. Se non è ancora arrivato
    /// si sceglie appena arriva; se la ricerca non aveva risposto, prima si riprova (SearchSubmit)
    func submit() {
        switch SearchSubmit.action(query: query, results: results.count, failed: failed) {
        case .pickFirst: if let first = results.first { picks.send(first) }
        case .retry: pickWhenReady = true; retry()
        case .wait: pickWhenReady = true
        case .nothing: break
        }
    }

    private func arrived(_ found: [MKLocalSearchCompletion]) {
        results = found
        if pickWhenReady, let first = found.first {
            pickWhenReady = false
            picks.send(first)
        }
    }

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
        Task { @MainActor in self.arrived(found) }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in self.results = []; self.failed = true }
    }
}
