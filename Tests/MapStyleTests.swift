import XCTest
import MapKit

/// 1.18.0: il nuovo stile delle zone sulla mappa. Il colore è la risposta per IL veicolo all'ora scelta (rosso, giallo,
/// verde, grigio), le vie strette diventano corridoi (Tools/build_map_shapes.py), le righe a 45° si ritagliano dentro le
/// zone (MapKit non ha i motivi), i segni non si coprono.
final class MapStyleTests: XCTestCase {
    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    private func city(_ id: String) throws -> City {
        try CityLoader.decode(Data(contentsOf: Self.root.appendingPathComponent("Resources/Cities/\(id).json")))
    }
    private func shapes() throws -> [String: ZoneShape] {
        try ZoneShapes.decode(Data(contentsOf: Self.root.appendingPathComponent("Resources/Map/zone-shapes.json")))
    }
    private func engine(today: Date) -> RuleEngine {
        var e = RuleEngine()
        e.now = { today }
        return e
    }
    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        RuleEngine.rome.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }
    private func access(_ z: Zone, _ v: Vehicle, _ at: Date, today: Date? = nil) -> Access {
        Access(engine(today: today ?? at).answer(zone: z, vehicle: v, permits: [], hotelInside: false, at: at))
    }

    // MARK: Colore = risposta per il veicolo

    /// La stessa zona, la stessa ora: verde per la mia auto, rossa per il diesel Euro 2 di un amico (Scudo Verde di
    /// Firenze, divieto dei diesel fino a Euro 2 dal 1° dicembre 2026)
    func testSameZoneDifferentColourPerVehicle() throws {
        let sv = try XCTUnwrap(city("firenze").zones.first { $0.id == "firenze-scudo-verde" })
        let at = date(2026, 12, 3, 13, 25)
        XCTAssertEqual(access(sv, Vehicle(name: "Mia", fuel: .petrol, euro: 6), at), .open)
        XCTAssertEqual(access(sv, Vehicle(name: "Amico", fuel: .diesel, euro: 2), at), .closed)
        XCTAssertEqual(MapTheme.tone(.open).lineLight, 0x2C7543)
        XCTAssertEqual(MapTheme.tone(.closed).lineLight, 0xA82F2F)
    }

    /// Settore A: attivo il giovedì alle 13:25 → rosso per la benzina, grigio per tutti alle 22 (ZTL spenta, non «verde»)
    func testInactiveZoneIsGreyForEveryVehicle() throws {
        let a = try XCTUnwrap(city("firenze").zones.first { $0.id == "firenze-a" })
        let petrol = Vehicle(name: "Golf", fuel: .petrol, euro: 6), diesel = Vehicle(name: "Panda", fuel: .diesel, euro: 2)
        XCTAssertEqual(access(a, petrol, date(2026, 10, 29, 13, 25)), .closed)
        XCTAssertEqual(access(a, petrol, date(2026, 10, 29, 22, 0)), .off)
        XCTAssertEqual(access(a, diesel, date(2026, 10, 29, 22, 0)), .off)
        XCTAssertEqual(MapTheme.tone(.off).lineLight, MapTheme.grey.lineLight)
    }

    /// «Da verificare» (dati vecchi) è giallo col «?», anche a varchi spenti: mai grigio, che direbbe «nessuna ZTL»
    func testUnsureIsYellowWithQuestionMarkNeverGrey() throws {
        let a = try XCTUnwrap(city("firenze").zones.first { $0.id == "firenze-a" })
        let car = Vehicle(name: "Golf", fuel: .petrol, euro: 6)
        let later = date(2027, 9, 1, 12)                     // più di 120 giorni dopo il controllo
        for hour in [13, 23] {
            let a1 = access(a, car, date(2027, 9, 1, hour), today: later)
            XCTAssertEqual(a1, .check, "ore \(hour)")
            XCTAssertEqual(MapTheme.tone(a1).fillLight, MapTheme.yellow.fillLight)
            XCTAssertEqual(MapTheme.badgeText(a1, kind: a.type), "ZTL ?")
        }
        XCTAssertFalse(Access.legend.contains(.check))         // in legenda è il giallo
        XCTAssertEqual(Access.legend, [.closed, .conditional, .open, .off])
    }

    /// Le quattro risposte e i varchi: con i varchi spenti grigio, con il ticket giallo
    func testAccessFromAnswer() {
        XCTAssertEqual(Access(Answer(verdict: .yes(reason: ""), gatesOn: false)), .off)
        XCTAssertEqual(Access(Answer(verdict: .yes(reason: ""), gatesOn: true)), .open)
        XCTAssertEqual(Access(Answer(verdict: .no(reason: ""), gatesOn: true)), .closed)
        XCTAssertEqual(Access(Answer(verdict: .conditional(reason: "", condition: ""), gatesOn: true)), .conditional)
        XCTAssertEqual(Access(Answer(verdict: .unsure(reason: ""), gatesOn: false)), .check)
        XCTAssertEqual(Access(Answer(verdict: .yes(reason: ""), gatesOn: false), status: .sample), .check)
        XCTAssertEqual(MapTheme.badgeText(.closed, kind: .restricted), "ZTL")
        XCTAssertEqual(MapTheme.badgeText(.open, kind: .green), "LEZ")
        XCTAssertEqual(MapTheme.dash(.closed), [5, 4])
        XCTAssertEqual(MapTheme.dash(.off), [3, 5])
    }

    /// Milano Area C (ticket) attiva: giallo per l'auto ammessa col ticket
    func testTicketZoneIsYellow() throws {
        let c = try XCTUnwrap(city("milano").zones.first { $0.ticket != nil })
        let at = date(2026, 10, 29, 10, 0)
        XCTAssertEqual(access(c, Vehicle(name: "Golf", fuel: .petrol, euro: 6), at), .conditional)
        XCTAssertEqual(access(c, Vehicle(name: "Vecchia", fuel: .diesel, euro: 5), at), .closed)
        XCTAssertEqual(access(c, Vehicle(name: "Golf", fuel: .petrol, euro: 6), date(2026, 10, 29, 21, 0)), .off)
    }

    // MARK: Corridoi delle vie

    private func meters(_ p: [Coordinate], lat0: Double) -> [(Double, Double)] {
        let kx = 111_320 * cos(lat0 * .pi / 180)
        return p.map { ($0.lon * kx, $0.lat * 110_540) }
    }
    private func inside(_ x: Double, _ y: Double, _ ring: [(Double, Double)]) -> Bool {
        var inside = false
        var j = ring.count - 1
        for i in ring.indices {
            let (xi, yi) = ring[i], (xj, yj) = ring[j]
            if (yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi { inside.toggle() }
            j = i
        }
        return inside
    }

    /// Le vie di Trieste (8–10 m) diventano corridoi di circa 7 m per lato che contengono tutta la via
    func testStreetZonesBecomeCorridors() throws {
        let ts = try city("trieste"), table = try shapes()
        let streets = ts.zones.filter { $0.id.hasPrefix("trieste-ztl-b-") }
        XCTAssertGreaterThanOrEqual(streets.count, 6)
        for z in streets {
            let s = try XCTUnwrap(ZoneShapes.shape(id: z.id, perimeter: z.perimeter, in: table), z.id)
            XCTAssertTrue(s.isStreet, z.id)
            XCTAssertLessThan(s.t, 15)
            let corridor = try XCTUnwrap(s.corridor).map { Coordinate(lat: $0[0], lon: $0[1]) }
            let ring = meters(corridor, lat0: ts.center.lat), street = meters(z.perimeter, lat0: ts.center.lat)
            // la via e una fascia di 6,5 m intorno a ogni suo punto stanno nel corridoio (7 m per lato, angoli tondi)
            for p in street {
                XCTAssertTrue(inside(p.0, p.1, ring), "\(z.id): la via esce dal corridoio")
                for k in 0..<8 {
                    let a = Double(k) * .pi / 4
                    XCTAssertTrue(inside(p.0 + 6.5 * cos(a), p.1 + 6.5 * sin(a), ring), "\(z.id): corridoio più stretto di 6,5 m")
                }
            }
            // quindi largo almeno t + 13 m: più di 10 punti a z15
            XCTAssertGreaterThan((s.t + 13) / MapZoom.metersPerPoint(zoom: 15, latitude: ts.center.lat), 10, z.id)
            XCTAssertEqual(s.axis?.count, 2)
            // sotto z15 solo il segno, da z15 il corridoio
            let shape = MapShapes.Shape(zone: z, coords: z.perimeter.map(\.cl), label: s.labelCoord, width: z.widthMeters,
                                        bounds: BBox(z.perimeter)!, corridor: s.corridorCoords, axis: s.axisCoords,
                                        fromZoom: MapShapes.fromZoom(meters: s.ext, latitude: ts.center.lat, street: true))
            XCTAssertNil(shape.drawn(zoom: 14.5))
            XCTAssertEqual(shape.drawn(zoom: 15)?.count, corridor.count)
        }
        // Le aree grandi restano il loro perimetro (niente corridoio)
        let fi = try city("firenze")
        let a = try XCTUnwrap(fi.zones.first { $0.id == "firenze-a" })
        XCTAssertFalse(try XCTUnwrap(ZoneShapes.shape(id: a.id, perimeter: a.perimeter, in: table)).isStreet)
    }

    /// Una città aggiornata senza rilanciare Tools/build_map_shapes.py: la forma vecchia non si usa (resta il perimetro)
    func testStaleShapeIsIgnored() throws {
        let table = try shapes()
        var z = try XCTUnwrap(city("trieste").zones.first { $0.id == "trieste-ztl-b-trento" })
        XCTAssertNotNil(ZoneShapes.shape(id: z.id, perimeter: z.perimeter, in: table))
        z.perimeter.append(z.perimeter[0])
        XCTAssertNil(ZoneShapes.shape(id: z.id, perimeter: z.perimeter, in: table))
    }

    /// Sotto ~16 punti solo il segno; fino a z12,5 solo le zone grandi; le vie da z15
    func testDrawingThresholds() {
        let lat = 45.65
        XCTAssertEqual(MapShapes.fromZoom(meters: 120, latitude: lat, street: true), 15)
        // 60 m: 16 punti solo da z≈13,8
        XCTAssertEqual(MapShapes.fromZoom(meters: 60, latitude: lat, street: false), MapZoom.fromZoom(meters: 60, latitude: lat), accuracy: 0.001)
        XCTAssertGreaterThan(MapShapes.fromZoom(meters: 60, latitude: lat, street: false), 13.5)
        // 400 m: già 16 punti a z12, ma fino a z12,5 solo le zone di almeno 64 punti
        XCTAssertEqual(MapShapes.fromZoom(meters: 400, latitude: lat, street: false), 12.5, accuracy: 0.001)
        // 2 km: da 64 punti sullo schermo (z≈10,8); le LEZ grandi quasi sempre
        XCTAssertEqual(MapShapes.fromZoom(meters: 2_000, latitude: lat, street: false), MapZoom.fromZoom(meters: 2_000, latitude: lat) + 2, accuracy: 0.001)
        XCTAssertLessThan(MapShapes.fromZoom(meters: 20_000, latitude: lat, street: false), 10)
    }

    // MARK: Righe a 45° ritagliate

    func testHatchStaysInsideThePolygon() {
        let square = [MKMapPoint(x: 0, y: 0), MKMapPoint(x: 100, y: 0), MKMapPoint(x: 100, y: 100), MKMapPoint(x: 0, y: 100)]
        let segs = Hatch.segments(rings: [square], pitch: 10)
        XCTAssertFalse(segs.isEmpty)
        // diagonali «/»: v = (x + y)/√2 da 0 a 141,4, una riga ogni 10 → 14 righe
        XCTAssertEqual(segs.count, 14)
        for (a, b) in segs {
            for p in [a, b] {
                XCTAssertTrue((-0.001...100.001).contains(p.x) && (-0.001...100.001).contains(p.y))
            }
            XCTAssertEqual(b.x - a.x, -(b.y - a.y), accuracy: 0.001)   // 45°, «/» come sul sito
        }
        // Una «L»: nessun tratto passa nel buco in alto a destra
        let l = [MKMapPoint(x: 0, y: 0), MKMapPoint(x: 40, y: 0), MKMapPoint(x: 40, y: 60), MKMapPoint(x: 100, y: 60),
                 MKMapPoint(x: 100, y: 100), MKMapPoint(x: 0, y: 100)]
        for (a, b) in Hatch.segments(rings: [l], pitch: 5) {
            let m = MKMapPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
            XCTAssertFalse(m.x > 40.5 && m.y < 59.5, "tratto fuori dalla L")
        }
        // Ritagliate alla parte visibile, e al massimo «limit»
        let clip = MKMapRect(x: 0, y: 0, width: 50, height: 50)
        for (a, b) in Hatch.segments(rings: [square], pitch: 10, clip: clip) {
            XCTAssertTrue(a.x <= 50.001 && a.y <= 50.001 && b.x <= 50.001 && b.y <= 50.001)
        }
        XCTAssertEqual(Hatch.segments(rings: [square], pitch: 1, limit: 30).count, 30)
    }

    // MARK: Segni senza sovrapposizioni

    func testBadgesDoNotOverlap() {
        let p = MKMapPoint(x: 1_000, y: 1_000)
        let items = [
            BadgeLayout.Item(id: "spenta", point: p, size: CGSize(width: 40, height: 18), priority: BadgeLayout.priority(.off, kind: .restricted, pedestrian: false), force: false),
            BadgeLayout.Item(id: "attiva", point: MKMapPoint(x: 1_010, y: 1_000), size: CGSize(width: 40, height: 18), priority: BadgeLayout.priority(.closed, kind: .restricted, pedestrian: false), force: false),
            BadgeLayout.Item(id: "lontana", point: MKMapPoint(x: 5_000, y: 1_000), size: CGSize(width: 40, height: 18), priority: 5, force: false),
        ]
        XCTAssertEqual(BadgeLayout.place(items, mapPointsPerPoint: 1), ["attiva", "lontana"])
        // la zona scelta c'è sempre
        var forced = items
        forced[0] = BadgeLayout.Item(id: "spenta", point: p, size: CGSize(width: 40, height: 18), priority: 5, force: true)
        XCTAssertTrue(BadgeLayout.place(forced, mapPointsPerPoint: 1).contains("spenta"))
        // più lontano (più punti di mappa per punto) i segni si scontrano di più
        XCTAssertEqual(BadgeLayout.place(items, mapPointsPerPoint: 200).count, 1)
    }
}
