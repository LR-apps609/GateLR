import XCTest

/// Velocità della ricerca delle zone (rettangoli calcolati alla lettura) e semplificazione dei perimetri per la mappa
final class GeometryTests: XCTestCase {
    private func bundledCities() throws -> [City] {
        let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/Cities")
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" && $0.lastPathComponent != "manifest.json" }
        return try files.map { try CityLoader.decode(Data(contentsOf: $0)) }
    }

    /// Punti sempre uguali intorno ai centri delle città (generatore fisso: il test non cambia da una volta all'altra)
    private func points(_ n: Int, around cities: [City]) -> [Coordinate] {
        var seed: UInt64 = 0x9E3779B97F4A7C15
        func next() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 11) / Double(1 << 53)
        }
        return (0..<n).map { i in
            let c = cities[i % cities.count].center
            return Coordinate(lat: c.lat + (next() - 0.5) * 0.2, lon: c.lon + (next() - 0.5) * 0.3)
        }
    }

    func testZonesAtIsFastAndCorrect() throws {
        let cities = try bundledCities()
        XCTAssertFalse(cities.isEmpty)
        XCTAssertTrue(cities.allSatisfy { $0.zones.allSatisfy { $0.bounds != nil && $0.area != nil } }, "rettangoli e aree calcolati alla lettura")
        let pts = points(2_000, around: cities)
        let start = Date()
        var hits = 0
        for p in pts { hits += Store.zones(at: p, in: cities).count }
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertGreaterThan(hits, 0)
        XCTAssertLessThan(elapsed, 5, "zones(at:) per 2000 punti: \(elapsed) s")
        // Stesso risultato del conto senza rettangoli (poligono di tutte le zone)
        for p in pts.prefix(300) {
            let fast = Store.zones(at: p, in: cities).map(\.zone.id)
            let slow = cities.flatMap(\.zones).filter { Zone.inside($0.perimeter, lat: p.lat, lon: p.lon) }
                .sorted { Zone.polygonArea($0.perimeter) < Zone.polygonArea($1.perimeter) }.map(\.id)
            XCTAssertEqual(fast, slow)
        }
    }

    func testNearestZoneMatchesFullSearch() throws {
        let cities = try bundledCities()
        for p in points(150, around: cities) {
            let fast = try XCTUnwrap(Store.nearestZone(to: p, in: cities))
            let slow = try XCTUnwrap(cities.flatMap(\.zones).map { $0.distance(lat: p.lat, lon: p.lon) }.min())
            XCTAssertEqual(fast.meters, slow, accuracy: 0.001)
        }
    }

    func testSimplifierKeepsEndpointsReducesPointsAndStaysWithinTolerance() throws {
        // Un cerchio frastagliato da 800 punti, come i perimetri grandi
        let n = 800
        let line: [Coordinate] = (0..<n).map { i in
            let a = Double(i) / Double(n) * 2 * .pi
            let r = 0.02 + 0.0003 * sin(Double(i) * 1.7)
            return Coordinate(lat: 45.46 + r * sin(a), lon: 9.19 + r * cos(a) * 1.4)
        }
        let tolerance = 0.0005
        let out = Simplifier.simplify(line, tolerance: tolerance)
        XCTAssertEqual(out.first, line.first)
        XCTAssertEqual(out.last, line.last)
        XCTAssertLessThan(out.count, line.count / 3)
        XCTAssertGreaterThanOrEqual(out.count, 4)
        for p in line {
            var best = Double.infinity
            for i in 0..<(out.count - 1) { best = min(best, Simplifier.segmentDistance(p, out[i], out[i + 1])) }
            XCTAssertLessThanOrEqual(best, tolerance * 1.0001)
        }
        // Tolleranza zero o pochi punti: tutto com'era
        XCTAssertEqual(Simplifier.simplify(line, tolerance: 0), line)
        XCTAssertEqual(Simplifier.simplify(Array(line.prefix(2)), tolerance: 1), Array(line.prefix(2)))
        // Un poligono non sparisce mai: sotto i 4 punti si tiene quello intero
        XCTAssertEqual(Simplifier.simplifyPolygon(line, tolerance: 10), line)
    }

    func testSimplifiedCityPerimetersStayClose() throws {
        for city in try bundledCities() {
            for z in city.zones where z.perimeter.count > 50 {
                let t = MapDetail.tolerance(for: 4)
                let out = Simplifier.simplifyPolygon(z.perimeter, tolerance: t)
                XCTAssertLessThanOrEqual(out.count, z.perimeter.count, z.id)
                XCTAssertEqual(out.first, z.perimeter.first, z.id)
            }
        }
        XCTAssertEqual(MapDetail.bucket(for: 1_000), 0)
        XCTAssertEqual(MapDetail.tolerance(for: 0), 0)
        XCTAssertLessThan(MapDetail.bucket(for: 5_000), MapDetail.bucket(for: 50_000))
    }
}
