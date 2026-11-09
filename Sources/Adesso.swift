import CoreLocation
import Foundation

// 2.2 «Adesso» (decisione 10 di D-Decisioni, tavole I-Si, I-No, I-InAuto): senza un posto cercato la risposta è per la
// zona in cui sei o, fuori dalle zone, per la più vicina entro 300 m NELLA DIREZIONE IN CUI VAI (lo stesso «davanti» del
// valutatore degli avvisi, ThreatEvaluator.isAhead). Altrimenti «Fuori dalla ZTL» (grigio) in una città che conosciamo,
// «Posto non coperto» fuori. Lo stesso comportamento di Android (Adesso.resolve, RispostaAndroid.kt).

enum Adesso {
    /// Oltre questi metri dal bordo una zona non è più «quella di adesso»
    static let radius: Double = 300
    /// Una posizione più vecchia di così non vale come «dove sei» (come il widget e Android, B160)
    static let maxAge: TimeInterval = 10 * 60

    /// La zona (o l'area pedonale) davanti, con il punto del bordo più vicino e i metri
    struct Ahead: Equatable {
        var candidate: ThreatCandidate
        var point: Coordinate
        var meters: Double
    }

    /// La più vicina entro `radius` che è davanti (senza direzione: la più vicina, come il valutatore). Solo le zone di cui
    /// NON sei dentro: dentro decide PlaceCheck (la zona peggiore tra tutte quelle del posto)
    static func ahead(from p: Coordinate, course: Double?, candidates: [ThreatCandidate]) -> Ahead? {
        var best: Ahead?
        for c in candidates where !c.zone.contains(lat: p.lat, lon: p.lon) {
            let edge = ThreatEvaluator.nearestPoint(c.zone.perimeter, to: p)
            guard edge.meters <= radius,
                  ThreatEvaluator.isAhead(from: p, to: edge.point, meters: edge.meters, course: course, approaching: nil) else { continue }
            if best.map({ edge.meters < $0.meters }) ?? true {
                best = Ahead(candidate: c, point: edge.point, meters: edge.meters)
            }
        }
        return best
    }

    /// La direzione di marcia, solo se ti muovi (oltre 2 m/s, come Android) e se iOS la dà abbastanza precisa
    static func course(_ l: CLLocation) -> Double? {
        guard l.speed > 2, l.course >= 0, l.courseAccuracy < 0 || l.courseAccuracy <= 45 else { return nil }
        return l.course
    }

    /// La posizione vale per «Adesso»: c'è ed è recente
    static func usable(_ l: CLLocation?, now: Date = Date()) -> CLLocation? {
        guard let l, now.timeIntervalSince(l.timestamp) <= maxAge else { return nil }
        return l
    }

    /// Il nome del posto davanti: il varco più vicino al punto del bordo, se c'è; altrimenti il nome della zona
    static func name(_ a: Ahead) -> String {
        if a.candidate.pedestrian != nil { return a.candidate.name }
        let gate = a.candidate.zone.gates.min { PathMath.meters($0.location, a.point) < PathMath.meters($1.location, a.point) }
        if let gate, PathMath.meters(gate.location, a.point) < 150 { return gate.name }
        return a.candidate.zone.localizedName
    }

    /// La riga «120 m davanti a te»
    static func aheadLine(_ meters: Double) -> String {
        String(format: L("%@ ahead of you"), DriveSession.distanceText(meters))
    }

    /// Quello per cui risponde Adesso
    struct Subject {
        var check: PlaceCheck
        /// I metri dal bordo della zona davanti; nil per il posto cercato o la tua posizione
        var aheadMeters: Double?
    }

    /// Il posto cercato, se c'è; altrimenti dove sei (dentro una zona), la zona davanti entro 300 m o la tua posizione
    /// fuori dalle zone. nil senza una posizione precisa e recente
    @MainActor
    static func subject(store: Store, place: Place?, location: CLLocation?, at date: Date) -> Subject? {
        if let place { return Subject(check: PlaceCheck(place, store: store, at: date), aheadMeters: nil) }
        guard let location = usable(location) else { return nil }
        let here = Coordinate(lat: location.coordinate.latitude, lon: location.coordinate.longitude)
        let mine = PlaceCheck(Place(name: L("My position"), address: "", location: here), store: store, at: date)
        if !mine.hits.isEmpty || mine.pedestrian != nil { return Subject(check: mine, aheadMeters: nil) }
        let candidates = ThreatEvaluator.candidates(store.cities, near: here, within: radius + 50, now: date)
        guard let a = ahead(from: here, course: course(location), candidates: candidates) else {
            return Subject(check: mine, aheadMeters: nil)
        }
        let place = Place(name: name(a), address: "", location: a.point)
        if let pedestrian = a.candidate.pedestrian {
            return Subject(check: PlaceCheck(place: place, hits: [], pedestrian: pedestrian, answers: [], covered: true), aheadMeters: a.meters)
        }
        let zone = a.candidate.zone
        guard let city = store.cities.first(where: { $0.zones.contains { $0.id == zone.id } }) else {
            return Subject(check: mine, aheadMeters: nil)
        }
        // La risposta all'ora d'arrivo stimata, come gli avvisi
        let arrival = ThreatEvaluator.arrival(in: a.meters, speed: location.speed, now: date)
        let answer = store.answer(at: arrival, zone: zone, hotelInside: false)
        return Subject(check: PlaceCheck(place: place, hits: [(city: city, zone: zone)], answers: [answer], covered: true),
                       aheadMeters: a.meters)
    }
}
