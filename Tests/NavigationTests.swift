import XCTest

/// Il navigatore: auto fluida tra una posizione e l'altra, agganciata alla strada, metri che mancano,
/// ricalcolo dopo una svolta sbagliata o un'inversione (e niente ricalcolo per l'oscillazione del GPS)
final class NavigationTests: XCTestCase {
    private let base = Coordinate(lat: 43.7700, lon: 11.2500)

    /// Un percorso dritto verso est, un punto ogni 100 m
    private func eastRoute(_ meters: Double = 1_200) -> RouteTrack {
        RouteTrack(stride(from: 0.0, through: meters, by: 100).map { PathMath.offset(base, meters: $0, bearing: 90) })
    }

    private func at(_ along: Double, north: Double = 0) -> Coordinate {
        PathMath.offset(PathMath.offset(base, meters: along, bearing: 90), meters: north, bearing: 0)
    }

    // MARK: Angoli

    func testHeadingWrapsTheShortWay() {
        XCTAssertEqual(Heading.normalize(-90), 270, accuracy: 1e-9)
        XCTAssertEqual(Heading.normalize(725), 5, accuracy: 1e-9)
        XCTAssertEqual(Heading.delta(350, 10), 20, accuracy: 1e-9)
        XCTAssertEqual(Heading.delta(10, 350), -20, accuracy: 1e-9)
        XCTAssertEqual(Heading.delta(0, 180), 180, accuracy: 1e-9)
        XCTAssertEqual(Heading.lerp(350, 10, 0.5), 0, accuracy: 1e-9)       // passa per il nord, non per sud
        XCTAssertEqual(Heading.lerp(10, 350, 0.25), 5, accuracy: 1e-9)
        XCTAssertEqual(Heading.lerp(90, 270, 2), 270, accuracy: 1e-9)        // t oltre 1: si ferma all'arrivo
        let s = Heading.smooth(350, toward: 20, dt: 1, tau: 1)
        XCTAssertTrue(s > 350 || s < 20, "smooth va per la via corta: \(s)")
        XCTAssertEqual(Heading.bearing(base, at(100)), 90, accuracy: 0.5)
        XCTAssertEqual(Heading.bearing(at(100), base), 270, accuracy: 0.5)
    }

    // MARK: Percorso

    func testCumulativeRemainingMatchesPathMath() {
        let track = eastRoute()
        XCTAssertEqual(track.length, 1_200, accuracy: 15)
        XCTAssertEqual(track.remaining(fromAlong: 0), PathMath.remaining(from: track.points[0], along: track.points), accuracy: 0.5)
        let p = at(450, north: 6)
        let fix = track.locate(p, near: 0)!
        XCTAssertEqual(fix.along, 450, accuracy: 6)
        XCTAssertEqual(track.remaining(fromAlong: fix.along), PathMath.remaining(from: p, along: track.points), accuracy: 1)
        XCTAssertEqual(track.remaining(fromAlong: 5_000), 0)
        let (i, t) = track.segment(atAlong: 450)
        XCTAssertEqual(i, 4)
        XCTAssertEqual(t, 0.5, accuracy: 0.05)
        XCTAssertEqual(PathMath.meters(track.point(atAlong: 450), at(450)), 0, accuracy: 6)
        XCTAssertEqual(track.bearing(atAlong: 450), 90, accuracy: 0.5)
    }

    func testSnapProjectsOntoTheRoad() {
        let track = eastRoute()
        let raw = at(230, north: 8)                           // 8 m a lato della strada
        let fix = track.locate(raw, near: 2)!
        XCTAssertEqual(fix.distance, 8, accuracy: 0.5)
        XCTAssertEqual(PathMath.meters(fix.point, at(230)), 0, accuracy: 3)   // l'auto disegnata sulla strada
        XCTAssertEqual(PathMath.distance(from: fix.point, to: track.points), 0, accuracy: 0.5)
        XCTAssertEqual(fix.segment, 2)
        XCTAssertEqual(fix.bearing, 90, accuracy: 0.5)
    }

    /// Andata e ritorno su due vie parallele a 30 m: si resta sulla via raggiunta, non si salta all'altra
    func testLocalWindowKeepsTheCurrentLeg() {
        var pts = stride(from: 0.0, through: 800, by: 50).map { at($0) }
        pts += stride(from: 800.0, through: 0, by: -50).map { at($0, north: 30) }
        let track = RouteTrack(pts)
        let fix = track.locate(at(300, north: 14), near: 5, course: 90)!
        XCTAssertLessThan(fix.along, 800, "ancora sull'andata")
        // Il ritorno è più vicino (14 m contro 16 m) ma è a 1 km di strada: si resta sull'andata
        let back = track.locate(at(300, north: 16), near: 5, course: 90)!
        XCTAssertLessThan(back.along, 800, "la ricerca vicina tiene l'andata anche se il ritorno è più vicino")
        // Cercando su tutto il percorso, invece, vince il ritorno quando è chiaramente più vicino (5 m contro 25 m)
        XCTAssertGreaterThan(track.locateAnywhere(at(300, north: 25))!.along, 800)
    }

    // MARK: Movimento fluido

    func testInterpolationBetweenFixes() {
        var i = PoseInterpolator()
        i.push(Pose(coordinate: at(0), heading: 350, along: nil), speed: 0, at: 0, track: nil)
        i.push(Pose(coordinate: at(14), heading: 10, along: nil), speed: 0, at: 1, track: nil)
        let mid = i.pose(at: 1.5, track: nil)!
        XCTAssertEqual(PathMath.meters(mid.coordinate, at(7)), 0, accuracy: 0.5)
        XCTAssertEqual(mid.heading, 0, accuracy: 0.01)          // 350° → 10° passando per il nord
        let end = i.pose(at: 3, track: nil)!
        XCTAssertEqual(PathMath.meters(end.coordinate, at(14)), 0, accuracy: 0.5)
    }

    func testPredictionAlongTheRouteIsCappedAtOneSecond() {
        let track = eastRoute()
        var i = PoseInterpolator()
        i.push(Pose(coordinate: at(100), heading: 90, along: 100), speed: 10, at: 0, track: track)
        XCTAssertEqual(i.pose(at: 1, track: track)!.along!, 110, accuracy: 0.01)   // un secondo avanti a 10 m/s
        i.push(Pose(coordinate: at(110), heading: 90, along: 110), speed: 10, at: 1, track: track)
        XCTAssertEqual(i.pose(at: 1.5, track: track)!.along!, 115, accuracy: 0.01)
        XCTAssertEqual(i.pose(at: 2, track: track)!.along!, 120, accuracy: 0.01)
        // Il GPS tace (galleria): l'auto si ferma un secondo dopo l'ultima posizione, non continua a correre
        XCTAssertEqual(i.pose(at: 9, track: track)!.along!, 120, accuracy: 0.01)
        // Una posizione un po' indietro (frenata, GPS che oscilla): niente marcia indietro
        i.push(Pose(coordinate: at(112), heading: 90, along: 112), speed: 0, at: 9, track: track)
        XCTAssertEqual(i.pose(at: 9.5, track: track)!.along!, 120, accuracy: 0.01)
        // Il punto disegnato è sulla strada
        let p = i.pose(at: 9.5, track: track)!
        XCTAssertEqual(PathMath.distance(from: p.coordinate, to: track.points), 0, accuracy: 0.5)
        // Dopo un ricalcolo i metri dal vecchio inizio non valgono più
        i.dropAlong()
        XCTAssertNil(i.pose(at: 9.5, track: track)!.along)
    }

    func testBigJumpTeleports() {
        var i = PoseInterpolator()
        i.push(Pose(coordinate: at(0), heading: 90, along: nil), speed: 0, at: 0, track: nil)
        i.push(Pose(coordinate: at(600), heading: 90, along: nil), speed: 0, at: 1, track: nil)
        XCTAssertEqual(PathMath.meters(i.pose(at: 1, track: nil)!.coordinate, at(600)), 0, accuracy: 0.5)
    }

    // MARK: Fuori percorso e contromano

    /// Il percorso visto dal navigatore: posizione sulla strada vicino al tratto raggiunto, poi il controllo
    private struct Sim {
        let track: RouteTrack
        var progress = 0
        var detector = OffRouteDetector()
        mutating func feed(_ p: Coordinate, course: Double?, kmh: Double, accuracy: Double = 5) -> OffRouteDetector.Verdict {
            let f = track.locate(p, near: progress, course: kmh > OffRouteDetector.minSpeedKmh ? course : nil)!
            if f.distance <= OffRouteDetector.threshold(accuracy: accuracy) { progress = f.segment }
            return detector.feed(distance: f.distance, accuracy: accuracy, course: course, speedKmh: kmh, routeBearing: f.bearing)
        }
    }

    func testGPSJitterDoesNotReroute() {
        for accuracy in [5.0, 10, 15] {
            var sim = Sim(track: eastRoute())
            for i in 0..<80 {
                let jitter = 15 * sin(Double(i) * 1.7)                       // fino a 15 m da una parte e dall'altra
                let v = sim.feed(at(Double(i) * 14, north: jitter), course: 90 + 20 * sin(Double(i)), kmh: 50, accuracy: accuracy)
                XCTAssertNotEqual(v, .offRoute, "posizione \(i), precisione \(accuracy)")
                XCTAssertNotEqual(v, .wrongWay, "posizione \(i), precisione \(accuracy)")
            }
        }
    }

    func testWrongTurnIntoParallelStreetReroutes() throws {
        var sim = Sim(track: eastRoute())
        var fixes: [(Coordinate, Double)] = (0...14).map { (at(Double($0) * 14), 90) }       // sul percorso fino a 196 m
        fixes += [(at(200, north: 14), 0), (at(200, north: 28), 0), (at(200, north: 40), 0)]  // svolta a sinistra sbagliata
        let turnedAt = fixes.count
        fixes += (1...10).map { (at(200 + Double($0) * 14, north: 40), 90) }                // la via parallela a 40 m
        var triggered: Int?
        for (n, f) in fixes.enumerated() {
            let v = sim.feed(f.0, course: f.1, kmh: 40)
            if v == .offRoute || v == .wrongWay {
                triggered = n
                break
            }
        }
        let t = try XCTUnwrap(triggered, "la via parallela a 40 m deve far ricalcolare")
        XCTAssertGreaterThanOrEqual(t, turnedAt - 2, "non prima della svolta")
        XCTAssertLessThanOrEqual(t, turnedAt + 3, "entro pochi secondi")
    }

    func testUTurnIsWrongWay() {
        var sim = Sim(track: eastRoute())
        for i in 0..<10 { XCTAssertEqual(sim.feed(at(Double(i) * 14), course: 90, kmh: 40), .onRoute) }
        // Inversione: stessa strada, verso ovest
        var verdicts: [OffRouteDetector.Verdict] = []
        for i in 1...4 { verdicts.append(sim.feed(at(126 - Double(i) * 10), course: 270, kmh: 30)) }
        XCTAssertEqual(Array(verdicts.prefix(2)), [.unsure, .unsure])
        XCTAssertEqual(verdicts[2], .wrongWay)
    }

    func testSlowOrUnreliableFixesDoNotReroute() {
        var det = OffRouteDetector()
        // Fermo o a passo d'uomo: la direzione del GPS non conta
        for _ in 0..<6 { XCTAssertNotEqual(det.feed(distance: 3, accuracy: 5, course: 270, speedKmh: 4, routeBearing: 90), .wrongWay) }
        det.reset()
        // GPS impreciso (60 m): nessuna decisione, nemmeno lontano dalla strada
        for _ in 0..<6 { XCTAssertEqual(det.feed(distance: 120, accuracy: 60, course: 90, speedKmh: 40, routeBearing: 90), .unsure) }
        // Con il GPS impreciso (20 m) il limite si allarga a 40 m
        XCTAssertEqual(OffRouteDetector.threshold(accuracy: 5), 25)
        XCTAssertEqual(OffRouteDetector.threshold(accuracy: 20), 40)
        XCTAssertEqual(OffRouteDetector.threshold(accuracy: 40), 50)
        // Molto lontano: bastano due posizioni
        det.reset()
        XCTAssertEqual(det.feed(distance: 80, accuracy: 5, course: 90, speedKmh: 40, routeBearing: 90), .unsure)
        XCTAssertEqual(det.feed(distance: 80, accuracy: 5, course: 90, speedKmh: 40, routeBearing: 90), .offRoute)
    }
}
