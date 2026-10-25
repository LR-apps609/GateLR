import Foundation

// I conti del navigatore, senza mappe né GPS (testabili): angoli, percorso con le distanze già sommate,
// l'auto «agganciata» alla strada, il movimento fluido tra una posizione e l'altra, l'uscita dal percorso.

/// Direzioni in gradi (0 = nord, in senso orario)
enum Heading {
    /// Tra 0 e 360
    static func normalize(_ a: Double) -> Double {
        let r = a.truncatingRemainder(dividingBy: 360)
        return r < 0 ? r + 360 : r
    }

    /// La rotazione più corta da «a» a «b», tra -180 e 180 (da 350° a 10° sono +20°, non -340°)
    static func delta(_ a: Double, _ b: Double) -> Double {
        var d = normalize(b) - normalize(a)
        if d > 180 { d -= 360 } else if d <= -180 { d += 360 }
        return d
    }

    /// Da «a» verso «b» per la via più corta: t = 0 è «a», t = 1 è «b»
    static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        normalize(a + delta(a, b) * max(0, min(1, t)))
    }

    /// Avvicinamento morbido a ogni fotogramma: dopo «tau» secondi si è fatto il 63% della strada
    static func smooth(_ current: Double, toward target: Double, dt: Double, tau: Double) -> Double {
        lerp(current, target, 1 - exp(-max(0, dt) / max(0.001, tau)))
    }

    /// La direzione da a verso b
    static func bearing(_ a: Coordinate, _ b: Coordinate) -> Double {
        normalize(atan2((b.lon - a.lon) * cos(a.lat * .pi / 180), b.lat - a.lat) * 180 / .pi)
    }
}

/// Il percorso con la distanza dall'inizio già sommata a ogni punto: «quanto manca» costa O(1) e
/// la posizione si cerca solo nei tratti vicini a quello raggiunto, non su tutta la strada a ogni posizione.
struct RouteTrack {
    let points: [Coordinate]
    /// Metri dall'inizio a ogni punto
    let cum: [Double]
    var length: Double { cum.last ?? 0 }
    var isEmpty: Bool { points.count < 2 }

    init(_ points: [Coordinate]) {
        self.points = points
        var c = [0.0]
        c.reserveCapacity(points.count)
        for (a, b) in zip(points, points.dropFirst()) { c.append(c[c.count - 1] + PathMath.meters(a, b)) }
        cum = points.isEmpty ? [] : c
    }

    /// Dove sei rispetto al percorso
    struct Fix: Equatable {
        var segment: Int          // il tratto tra points[segment] e points[segment + 1]
        var t: Double             // 0…1 lungo il tratto
        var along: Double         // metri dall'inizio del percorso
        var distance: Double      // metri dalla strada
        var point: Coordinate     // il punto sulla strada (l'auto «agganciata»)
        var bearing: Double       // la direzione del tratto
    }

    /// Il punto più vicino su un tratto, in metri locali attorno a p
    static func project(_ p: Coordinate, _ a: Coordinate, _ b: Coordinate) -> (distance: Double, t: Double) {
        let k = cos(p.lat * .pi / 180)
        let ax = (a.lon - p.lon) * 111_000 * k, ay = (a.lat - p.lat) * 111_000
        let bx = (b.lon - p.lon) * 111_000 * k, by = (b.lat - p.lat) * 111_000
        let dx = bx - ax, dy = by - ay
        let len2 = dx * dx + dy * dy
        let t = len2 == 0 ? 0 : max(0, min(1, -(ax * dx + ay * dy) / len2))
        return (hypot(ax + t * dx, ay + t * dy), t)
    }

    private func fix(_ p: Coordinate, segment i: Int, _ r: (distance: Double, t: Double)) -> Fix {
        let a = points[i], b = points[i + 1]
        let point = Coordinate(lat: a.lat + (b.lat - a.lat) * r.t, lon: a.lon + (b.lon - a.lon) * r.t)
        return Fix(segment: i, t: r.t, along: cum[i] + (cum[i + 1] - cum[i]) * r.t, distance: r.distance,
                   point: point, bearing: Heading.bearing(a, b))
    }

    /// La posizione sul percorso cercando solo vicino al tratto «near» (un po' indietro, «ahead» metri avanti).
    /// A parità di distanza vince il tratto più vicino a quello raggiunto; con la direzione di marcia
    /// si scartano i tratti percorsi al contrario (andata e ritorno sulla stessa via).
    func locate(_ p: Coordinate, near: Int, back: Double = 60, ahead: Double = 400, course: Double? = nil) -> Fix? {
        guard !isEmpty else { return nil }
        let start = max(0, min(near, points.count - 2))
        var lo = start
        while lo > 0 && cum[start] - cum[lo] < back { lo -= 1 }
        var hi = start
        while hi < points.count - 2 && cum[hi] - cum[start] < ahead { hi += 1 }
        return best(p, in: lo...hi, from: cum[start], course: course)
    }

    /// Su tutto il percorso (una volta per percorso, o quando la ricerca vicina non trova la strada)
    func locateAnywhere(_ p: Coordinate, course: Double? = nil) -> Fix? {
        guard !isEmpty else { return nil }
        return best(p, in: 0...(points.count - 2), from: 0, course: nil)
    }

    private func best(_ p: Coordinate, in range: ClosedRange<Int>, from along0: Double, course: Double?) -> Fix? {
        var bestScore = Double.infinity, bestFix: Fix?
        for i in range {
            let r = Self.project(p, points[i], points[i + 1])
            let along = cum[i] + (cum[i + 1] - cum[i]) * r.t
            var score = r.distance + abs(along - along0) * 0.01          // 100 m di strada valgono 1 m
            if let course, cum[i + 1] - cum[i] > 3,
               abs(Heading.delta(course, Heading.bearing(points[i], points[i + 1]))) > 100 { score += 15 }
            if score < bestScore { bestScore = score; bestFix = fix(p, segment: i, r) }
        }
        return bestFix
    }

    /// Metri che restano da un punto del percorso alla fine: O(1)
    func remaining(fromAlong a: Double) -> Double { max(0, length - a) }

    /// Il tratto e la frazione a «a» metri dall'inizio (ricerca binaria)
    func segment(atAlong a: Double) -> (index: Int, t: Double) {
        guard !isEmpty else { return (0, 0) }
        let a = max(0, min(length, a))
        var lo = 0, hi = points.count - 1
        while hi - lo > 1 {
            let mid = (lo + hi) / 2
            if cum[mid] <= a { lo = mid } else { hi = mid }
        }
        let len = cum[lo + 1] - cum[lo]
        return (lo, len > 0 ? (a - cum[lo]) / len : 0)
    }

    /// Il punto a «a» metri dall'inizio
    func point(atAlong a: Double) -> Coordinate {
        guard !isEmpty else { return points.first ?? Coordinate(lat: 0, lon: 0) }
        let (i, t) = segment(atAlong: a)
        let p = points[i], q = points[i + 1]
        return Coordinate(lat: p.lat + (q.lat - p.lat) * t, lon: p.lon + (q.lon - p.lon) * t)
    }

    /// La direzione della strada a «a» metri dall'inizio (salta i tratti di lunghezza zero)
    func bearing(atAlong a: Double) -> Double {
        guard !isEmpty else { return 0 }
        var i = segment(atAlong: a).index
        while i < points.count - 2 && cum[i + 1] - cum[i] < 0.5 { i += 1 }
        return Heading.bearing(points[i], points[i + 1])
    }
}

/// Dove disegnare l'auto: punto, direzione e (se è sulla strada) i metri dall'inizio del percorso
struct Pose: Equatable {
    var coordinate: Coordinate
    var heading: Double
    var along: Double?
}

/// Il movimento fluido dell'auto: il GPS dà una posizione al secondo, la mappa ne disegna 60.
/// A ogni posizione nuova si parte da dove l'auto è disegnata adesso e si arriva alla posizione nuova
/// spinta un po' avanti con la velocità (al massimo un secondo), in tempo per la posizione dopo.
/// Sul percorso si scorre lungo la strada (le curve restano curve), fuori si va in linea retta.
struct PoseInterpolator {
    private(set) var from: Pose?
    private(set) var to: Pose?
    private var start: Double = 0
    private var duration: Double = 1
    private var lastFix: Double?
    /// Secondi al massimo di previsione oltre l'ultima posizione
    var maxPrediction: Double = 1
    /// Oltre questa distanza l'auto salta (GPS ritrovato dopo una galleria): non si fa scivolare per 300 m
    var teleport: Double = 120

    /// Una posizione nuova (alle «time» secondi), con la velocità in m/s
    mutating func push(_ target: Pose, speed: Double, at time: Double, track: RouteTrack?) {
        let interval = lastFix.map { max(0.25, min(1.5, time - $0)) } ?? 1
        lastFix = time
        let lead = speed > 1 ? min(maxPrediction, interval) : 0
        var aim = target
        if let a = target.along, let track, !track.isEmpty {
            let ahead = min(track.length, a + speed * lead)
            aim = Pose(coordinate: track.point(atAlong: ahead), heading: track.bearing(atAlong: ahead), along: ahead)
        } else if lead > 0 {
            aim.coordinate = PathMath.offset(target.coordinate, meters: speed * lead, bearing: target.heading)
        }
        var now = pose(at: time, track: track) ?? aim
        if PathMath.meters(now.coordinate, aim.coordinate) > teleport { now = aim }
        // Sulla strada non si torna indietro per pochi metri (il GPS che oscilla, una frenata): si aspetta lì
        if let na = now.along, let aa = aim.along, aa < na, na - aa < 15 {
            aim.along = na; aim.coordinate = now.coordinate
        }
        if (now.along == nil) != (aim.along == nil) { now.along = nil; aim.along = nil }
        from = now; to = aim; start = time; duration = interval
    }

    /// Il percorso è cambiato (ricalcolo): i metri dall'inizio non valgono più, si continua in linea retta
    mutating func dropAlong() {
        from?.along = nil; to?.along = nil
    }

    mutating func reset() { from = nil; to = nil; lastFix = nil }

    /// Dove disegnare l'auto all'istante «time»
    func pose(at time: Double, track: RouteTrack?) -> Pose? {
        guard let from, let to else { return nil }
        let u = max(0, min(1, (time - start) / duration))
        let heading = Heading.lerp(from.heading, to.heading, u)
        if let fa = from.along, let ta = to.along, let track, !track.isEmpty {
            let a = fa + (ta - fa) * u
            return Pose(coordinate: track.point(atAlong: a), heading: heading, along: a)
        }
        let c = Coordinate(lat: from.coordinate.lat + (to.coordinate.lat - from.coordinate.lat) * u,
                           lon: from.coordinate.lon + (to.coordinate.lon - from.coordinate.lon) * u)
        return Pose(coordinate: c, heading: heading, along: nil)
    }
}

/// Fuori percorso o contromano: si decide solo con posizioni buone e per qualche posizione di fila,
/// così l'oscillazione del GPS non fa ricalcolare e una via parallela a 40 m sì.
struct OffRouteDetector {
    enum Verdict: Equatable { case onRoute, unsure, offRoute, wrongWay }

    /// Precisione oltre la quale la posizione non conta (né per uscire né per tornare)
    static let goodAccuracy = 40.0
    /// Sotto questa velocità la direzione del GPS non è affidabile
    static let minSpeedKmh = 8.0

    private(set) var offCount = 0
    private(set) var wrongCount = 0

    /// Quanto lontano dalla strada si è fuori: almeno 25 m, di più se il GPS è impreciso (al massimo 50 m)
    static func threshold(accuracy: Double) -> Double { max(25, min(50, 2 * accuracy)) }

    mutating func reset() { offCount = 0; wrongCount = 0 }

    /// distance: metri dalla strada; course: direzione di marcia (nil se non valida); routeBearing: direzione del tratto
    mutating func feed(distance: Double, accuracy: Double, course: Double?, speedKmh: Double, routeBearing: Double?) -> Verdict {
        guard accuracy >= 0, accuracy <= Self.goodAccuracy else { return .unsure }
        let limit = Self.threshold(accuracy: accuracy)
        if distance > limit {
            offCount += 1
            wrongCount = 0
            // Molto lontano: bastano due posizioni; appena fuori ne servono tre
            return offCount >= (distance > 2 * limit ? 2 : 3) ? .offRoute : .unsure
        }
        offCount = 0
        // Sulla strada ma al contrario (inversione, senso sbagliato): tre posizioni di fila in movimento
        if let course, let routeBearing, speedKmh > Self.minSpeedKmh {
            if abs(Heading.delta(course, routeBearing)) > 100 { wrongCount += 1 } else { wrongCount = 0 }
        }
        if wrongCount >= 3 { return .wrongWay }
        return wrongCount > 0 ? .unsure : .onRoute
    }
}
