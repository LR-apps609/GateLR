import XCTest
import MapKit

/// 1.19.1: l'area pedonale vince, Viaggio all'ora scelta, il percorso conosce le aree pedonali. Dati veri delle città
/// (Resources/Cities), «oggi» fisso perché le schede non diventino vecchie.
final class PedestrianWinsTests: XCTestCase {
    private static let cities = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Resources/Cities")

    private let engine: RuleEngine = {
        var e = RuleEngine()
        let today = RuleEngine.rome.date(from: DateComponents(year: 2026, month: 10, day: 30, hour: 12))!
        e.now = { today }
        return e
    }()

    private func city(_ id: String) throws -> City {
        try CityLoader.decode(Data(contentsOf: Self.cities.appendingPathComponent("\(id).json")))
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        RuleEngine.rome.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    /// Come PlaceCheck(_:store:at:), senza Store: zone, area pedonale, risposte all'ora data per il veicolo dato
    private func check(_ name: String, _ lat: Double, _ lon: Double, in cities: [City],
                       vehicle: Vehicle = SampleData.rental, at d: Date) -> PlaceCheck {
        let p = Coordinate(lat: lat, lon: lon)
        let hits = Store.zones(at: p, in: cities)
        let area = cities.lazy.compactMap { $0.pedestrian?.first(where: { $0.contains(lat: lat, lon: lon) }) }.first
        return PlaceCheck(place: Place(name: name, address: "", location: p), hits: hits, pedestrian: area,
                          answers: hits.map { engine.answer(zone: $0.zone, vehicle: vehicle, permits: [], hotelInside: false, at: d) },
                          covered: Store.covers(p, in: cities))
    }

    // MARK: Area pedonale fuori dalle zone

    /// Bologna, via Galliera: area pedonale fuori da ogni zona. Prima in Viaggio: riquadro rosso e sotto il verde
    /// «Fuori dalla ZTL. Puoi andarci». Adesso solo «no», a ogni ora, per ogni veicolo
    func testBolognaViaGallieraOutsideZonesIsNo() throws {
        let bologna = try city("bologna")
        for (h, v) in [(12, SampleData.rental), (23, SampleData.rental), (3, Vehicle(name: "", fuel: .electric, euro: 6))] {
            let c = check("Via Galliera", 44.50337, 11.34431, in: [bologna], vehicle: v, at: date(2026, 11, 3, h))
            XCTAssertEqual(c.pedestrian?.name, "Via Galliera")
            XCTAssertTrue(c.hits.isEmpty, "via Galliera è fuori dalle zone (il caso della diagnosi)")
            XCTAssertEqual(c.kind, .pedestrian)
            guard case .no = c.verdict else { return XCTFail("atteso no alle \(h)") }
            XCTAssertFalse(c.showsOutside, "mai «Fuori dalla ZTL. Puoi andarci» in un'area pedonale")
            XCTAssertTrue(c.parkingFirst)
            XCTAssertEqual(Home2Answer(c, now: date(2026, 11, 3, h)).mood, .red)
        }
        // Un posto vicino, fuori da zone e aree pedonali: la scheda verde resta
        let outside = check("Stazione", 44.5060, 11.3430, in: [bologna], at: date(2026, 11, 3, 12))
        if outside.pedestrian == nil && outside.hits.isEmpty { XCTAssertTrue(outside.showsOutside) }
    }

    // MARK: Viaggio all'ora scelta

    /// Bologna, Piazza Maggiore (area pedonale nella ZTL 7–20) alle 23:58: la risposta è «no» per l'area pedonale, ma i
    /// varchi della ZTL sono SPENTI. Prima «ZTL attiva» era scritto fisso
    func testBolognaPedestrianAt2358ShowsGatesOff() throws {
        let bologna = try city("bologna")
        let night = date(2026, 11, 3, 23, 58)
        let c = check("Piazza Maggiore", 44.4939, 11.3426, in: [bologna], at: night)
        XCTAssertEqual(c.zone?.id, "bologna-ztl")
        XCTAssertNotNil(c.pedestrian)
        XCTAssertFalse(engine.isActive(c.zone!, at: night), "la ZTL di Bologna è 7–20")
        let shown = try XCTUnwrap(c.shownAnswer)
        XCTAssertFalse(shown.gatesOn, "alle 23:58 i varchi sono spenti: niente «ZTL attiva»")
        guard case .no = shown.verdict else { return XCTFail("area pedonale: sempre no") }
        // Alle 10 i varchi sono accesi, la risposta è sempre no
        let day = check("Piazza Maggiore", 44.4939, 11.3426, in: [bologna], at: date(2026, 11, 3, 10))
        XCTAssertEqual(day.shownAnswer?.gatesOn, true)
    }

    /// Un punto della ZTL di Bologna fuori dalle aree pedonali alle 23:58: varchi spenti e «sì» per l'auto di serie;
    /// la risposta dipende dall'ora scelta, non da adesso
    func testBolognaZoneAt2358GatesOff() throws {
        let bologna = try city("bologna")
        let c = check("Via Castiglione", 44.4920, 11.3480, in: [bologna], at: date(2026, 11, 3, 23, 58))
        XCTAssertNil(c.pedestrian)
        XCTAssertEqual(c.zone?.id, "bologna-ztl")
        XCTAssertEqual(c.shownAnswer?.gatesOn, false)
        XCTAssertEqual(c.kind, .open)
        let morning = check("Via Castiglione", 44.4920, 11.3480, in: [bologna], at: date(2026, 11, 4, 9))
        XCTAssertEqual(morning.shownAnswer?.gatesOn, true)
        XCTAssertEqual(morning.kind, .conditional, "ZTL attiva con il biglietto giornaliero: a una condizione")
        XCTAssertFalse(morning.parkingFirst, "solo con il «no» «Parcheggia fuori» passa per primo")
        // Firenze, Palazzo Vecchio, diesel Euro 1 di notte: lo Scudo Verde dice no → «Parcheggia fuori» per primo
        // (1.20.4: il punto è il palazzo, non Piazza della Signoria, che dai dati aperti del Comune è area pedonale)
        let firenze = try city("firenze")
        let euro1 = check("Palazzo Vecchio", 43.7693, 11.2563, in: [firenze], vehicle: Vehicle(name: "", fuel: .diesel, euro: 1),
                          at: date(2026, 11, 3, 22))
        XCTAssertEqual(euro1.kind, .closed)
        XCTAssertTrue(euro1.parkingFirst)
    }

    // MARK: Percorso

    /// Un percorso che finisce nell'area pedonale dell'Alzaia Naviglio Pavese (Milano, fuori da Area B e C): prima
    /// «Nessuna ZTL sulla strada»; adesso l'area pedonale è una tappa «no» e la destinazione è bloccata
    func testRouteEndingInMilanPedestrianAreaIsNo() throws {
        let milano = try city("milano")
        let areas = milano.pedestrian ?? []
        let target = Coordinate(lat: 45.41857, lon: 9.16493)
        let path = RouteCheck.densify([Coordinate(lat: 45.405, lon: 9.160), target])
        let departure = date(2026, 11, 3, 23)
        let before = RouteCheck.crossings(path: path, zones: milano.zones, departure: departure, travelTime: 600) {
            engine.answer(zone: $0, vehicle: SampleData.rental, permits: [], hotelInside: false, at: $1)
        }
        XCTAssertFalse(before.contains { $0.isDestination }, "senza aree pedonali la destinazione non era in nessuna zona")
        let crossings = RouteCheck.crossings(path: path, zones: milano.zones, pedestrian: areas, departure: departure, travelTime: 600) {
            engine.answer(zone: $0, vehicle: SampleData.rental, permits: [], hotelInside: false, at: $1)
        }
        let dest = try XCTUnwrap(crossings.first { $0.isDestination && $0.pedestrian != nil })
        XCTAssertEqual(dest.pedestrian?.name, "Alzaia Naviglio Pavese")
        guard case .no = dest.answer.verdict else { return XCTFail("area pedonale: no") }
        guard case .no = RouteCheck.worst(crossings)?.answer.verdict else { return XCTFail("il percorso: no") }
        XCTAssertTrue(dest.title.contains("Alzaia Naviglio Pavese"))
        let plan = RoutePlan(destination: Place(name: "Alzaia", address: "", location: target), path: path, distance: 1_500,
                             travelTime: 600, departure: departure, crossings: crossings)
        XCTAssertTrue(plan.destinationBlocked, "la destinazione nell'area pedonale: «Non entrare» e parcheggio fuori")
        XCTAssertTrue(plan.blocked)
    }

    /// Partire da dentro un'area pedonale non conta come entrarci (come per le zone)
    func testRouteStartingInsidePedestrianAreaIgnoresIt() throws {
        let milano = try city("milano")
        let path = RouteCheck.densify([Coordinate(lat: 45.41857, lon: 9.16493), Coordinate(lat: 45.405, lon: 9.160)])
        let crossings = RouteCheck.crossings(path: path, zones: milano.zones, pedestrian: milano.pedestrian ?? [],
                                             departure: date(2026, 11, 3, 23), travelTime: 600) {
            engine.answer(zone: $0, vehicle: SampleData.rental, permits: [], hotelInside: false, at: $1)
        }
        XCTAssertFalse(crossings.contains { $0.pedestrian?.name == "Alzaia Naviglio Pavese" })
    }

    // MARK: Mappa

    /// L'etichetta del posto sta sopra il punto: la regione lascia almeno metà dell'altezza sopra il posto
    func testMapRegionLeavesRoomAboveThePlace() {
        let place = CLLocationCoordinate2D(latitude: 43.7790, longitude: 11.2558)
        let zone = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 43.7700, longitude: 11.2558),
                                      span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))
        let r = MapScreen.roomAbove(zone, for: place)
        let top = r.center.latitude + r.span.latitudeDelta / 2, bottom = r.center.latitude - r.span.latitudeDelta / 2
        XCTAssertGreaterThanOrEqual((top - place.latitude) / (top - bottom), 0.549)
        XCTAssertLessThanOrEqual(bottom, zone.center.latitude - zone.span.latitudeDelta / 2 + 1e-9, "la zona resta tutta in vista")
        XCTAssertGreaterThan(place.latitude, bottom)
    }
}
