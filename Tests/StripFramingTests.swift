import XCTest

/// 1.17.2: la striscia di mappa di «Varco». La ripresa tiene dentro anche te se sei a meno di 5 km (così si vede che sei
/// fuori dalla ZTL), altrimenti solo la zona; il segno del posto non è mai un pallino.
final class StripFramingTests: XCTestCase {
    /// Il centro di San Giovanni Valdarno e un punto a circa 550 m (il caso visto sull'iPhone)
    private let zone = Coordinate(lat: 43.5640, lon: 11.5300)
    private let near = Coordinate(lat: 43.5690, lon: 11.5300)

    func testWithoutPositionOnlyTheZone() {
        let f = StripFrame.make(target: zone, user: nil)
        XCTAssertFalse(f.includesUser)
        XCTAssertEqual(f.center, zone)
        XCTAssertEqual(f.zoom(points: 168), StripFrame.closeZoom)
    }

    func testNearbyUserIsInTheFrame() {
        let f = StripFrame.make(target: zone, user: near)
        XCTAssertTrue(f.includesUser)
        XCTAssertEqual(f.center.lat, (zone.lat + near.lat) / 2, accuracy: 1e-9)
        XCTAssertEqual(f.center.lon, zone.lon, accuracy: 1e-9)
        let d = StripFrame.meters(zone, near)
        XCTAssertEqual(d, 555, accuracy: 10)
        XCTAssertEqual(f.spanMeters, max(StripFrame.minSpan, d * StripFrame.margin), accuracy: 0.001)
        // Tutti e due dentro la ripresa: metà della distanza dal centro, meno della metà del lato
        XCTAssertLessThan(StripFrame.meters(f.center, near), f.spanMeters / 2)
        XCTAssertLessThan(StripFrame.meters(f.center, zone), f.spanMeters / 2)
        // Più lontana della ripresa vicina, ma i due punti stanno nella striscia allo zoom scelto
        let z = f.zoom(points: 168)
        XCTAssertLessThan(z, StripFrame.closeZoom)
        let metersPerPoint = 40_075_016.686 / 512 * cos(f.center.lat * .pi / 180) / pow(2, z)
        XCTAssertGreaterThanOrEqual(metersPerPoint * 168, d)
    }

    func testVeryCloseUserKeepsAMinimumSpan() {
        let f = StripFrame.make(target: zone, user: Coordinate(lat: zone.lat + 0.0005, lon: zone.lon))
        XCTAssertTrue(f.includesUser)
        XCTAssertEqual(f.spanMeters, StripFrame.minSpan)
        XCTAssertLessThanOrEqual(f.zoom(points: 112), StripFrame.closeZoom)
    }

    func testFarUserOnlyTheZone() {
        // A Firenze, a 45 km: solo la zona
        let far = StripFrame.make(target: zone, user: Coordinate(lat: 43.7717, lon: 11.2510))
        XCTAssertFalse(far.includesUser)
        XCTAssertEqual(far.center, zone)
        XCTAssertEqual(far.spanMeters, 0)
        // Appena oltre i 5 km: ancora solo la zona; appena sotto: tutti e due
        let justOut = Coordinate(lat: zone.lat + 5_100 / 111_000, lon: zone.lon)
        let justIn = Coordinate(lat: zone.lat + 4_900 / 111_000, lon: zone.lon)
        XCTAssertFalse(StripFrame.make(target: zone, user: justOut).includesUser)
        XCTAssertTrue(StripFrame.make(target: zone, user: justIn).includesUser)
    }

    func testAppleRegionCoversTheSpan() {
        let f = StripFrame.make(target: zone, user: near)
        let d = f.degrees
        XCTAssertEqual(d.lat * 111_000, f.spanMeters, accuracy: 1)
        XCTAssertGreaterThan(d.lon, d.lat)      // a 43° un grado di longitudine è più corto
    }

    func testCameraMovesOnlyOnRealChanges() {
        let a = StripFrame.make(target: zone, user: near)
        let b = StripFrame.make(target: zone, user: Coordinate(lat: near.lat + 0.0002, lon: near.lon))
        XCTAssertFalse(a.differs(from: b))
        XCTAssertTrue(a.differs(from: StripFrame.make(target: zone, user: nil)))
        XCTAssertTrue(a.differs(from: StripFrame.make(target: zone, user: Coordinate(lat: zone.lat + 0.03, lon: zone.lon))))
    }

    func testMarkerLabels() {
        XCTAssertEqual(StripMarkerKind.zone("Centro").label, "Centro")
        XCTAssertEqual(StripMarkerKind.destination("Hotel Cavour").label, "Hotel Cavour")
        XCTAssertTrue(StripMarkerKind.zone("Centro").accessibilityText.contains("Centro"))
        XCTAssertTrue(StripMarkerKind.destination("Hotel Cavour").accessibilityText.contains("Hotel Cavour"))
        XCTAssertNotEqual(StripMarkerKind.zone("Centro").accessibilityText, StripMarkerKind.destination("Centro").accessibilityText)
    }
}
