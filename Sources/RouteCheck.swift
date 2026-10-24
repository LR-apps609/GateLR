import Foundation

// Il controllo ZTL di un percorso, senza mappe: dato il tragitto (una lista di punti) e l'orario,
// quali zone attraversa e con quale risposta al momento in cui ci passi.

struct RouteCrossing: Identifiable, Equatable {
    var zone: Zone
    var answer: Answer
    var at: Date                // quando ci entri, stimato
    var isDestination: Bool     // la destinazione è dentro questa zona
    var id: String { zone.id }
}

enum RouteCheck {
    /// Le zone in cui il percorso entra, nell'ordine in cui le incontri.
    /// Le zone che contengono già la partenza non contano: da lì si esce, non si entra.
    static func crossings(path: [Coordinate], zones: [Zone], departure: Date, travelTime: TimeInterval,
                          answer: (Zone, Date) -> Answer) -> [RouteCrossing] {
        guard let first = path.first, let last = path.last else { return [] }
        let candidates = zones.filter { !$0.contains(lat: first.lat, lon: first.lon) }
        var result: [RouteCrossing] = []
        let total = Double(max(path.count - 1, 1))
        for (i, p) in path.enumerated() {
            for z in candidates where !result.contains(where: { $0.zone.id == z.id }) && z.contains(lat: p.lat, lon: p.lon) {
                let when = departure.addingTimeInterval(travelTime * Double(i) / total)
                result.append(RouteCrossing(zone: z, answer: answer(z, when), at: when,
                                            isDestination: z.contains(lat: last.lat, lon: last.lon)))
            }
        }
        return result
    }

    /// Il punto peggiore del percorso decide: un «no» vince su tutto, poi «non sicuro», poi le condizioni
    static func worst(_ crossings: [RouteCrossing]) -> RouteCrossing? {
        func rank(_ v: Verdict) -> Int {
            switch v { case .no: 3; case .unsure: 2; case .conditional: 1; case .yes: 0 }
        }
        return crossings.max { rank($0.answer.verdict) < rank($1.answer.verdict) }
    }

    /// Punti in più lungo i tratti lunghi, così un rettilineo non «salta» una zona piccola (ogni ~40 m)
    static func densify(_ path: [Coordinate], step: Double = 40) -> [Coordinate] {
        guard path.count > 1 else { return path }
        var out: [Coordinate] = [path[0]]
        for (a, b) in zip(path, path.dropFirst()) {
            let k = cos(a.lat * .pi / 180)
            let d = hypot((b.lat - a.lat) * 111_000, (b.lon - a.lon) * 111_000 * k)
            let n = max(1, Int(d / step))
            for j in 1...n {
                let t = Double(j) / Double(n)
                out.append(Coordinate(lat: a.lat + (b.lat - a.lat) * t, lon: a.lon + (b.lon - a.lon) * t))
            }
        }
        return out
    }
}
