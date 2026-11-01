import Foundation

// Il controllo ZTL di un percorso, senza mappe: dato il tragitto (una lista di punti) e l'orario,
// quali zone attraversa e con quale risposta al momento in cui ci passi.

struct RouteCrossing: Identifiable, Equatable {
    var zone: Zone
    var answer: Answer
    var at: Date                // quando ci entri, stimato
    var isDestination: Bool     // la destinazione è dentro questa zona
    var entry: Coordinate? = nil // il punto del percorso in cui si entra
    /// 1.19.1: l'area pedonale attraversata (o dove arrivi): «zone» è allora una zona fatta dal suo perimetro, sempre
    /// chiusa, e la risposta è sempre «no» (non si ricalcola con il motore delle regole)
    var pedestrian: PedestrianArea? = nil
    var id: String { zone.id }

    /// Il nome da mostrare: «Area pedonale · Via Galliera» o il nome breve della zona
    var title: String { pedestrian != nil ? zone.localizedName : zone.shortName }
}

enum RouteCheck {
    /// Le zone in cui il percorso entra, nell'ordine in cui le incontri.
    /// Le zone che contengono già la partenza non contano: da lì si esce, non si entra.
    /// 1.19.1: anche le aree pedonali («pedestrian»): chiuse alle auto a ogni ora, la risposta è sempre «no»
    /// (prima il percorso le ignorava: una destinazione in via Galliera a Bologna risultava «Nessuna ZTL sulla strada»).
    static func crossings(path: [Coordinate], zones: [Zone], pedestrian: [PedestrianArea] = [], departure: Date, travelTime: TimeInterval,
                          answer: (Zone, Date) -> Answer) -> [RouteCrossing] {
        guard let first = path.first, let last = path.last else { return [] }
        let areas = Dictionary(pedestrian.map { (pedestrianZoneId($0), $0) }, uniquingKeysWith: { a, _ in a })
        let all = zones + pedestrian.map { pedestrianZone($0, checkedOn: departure) }
        // Il rettangolo di ogni zona: si fa il conto preciso solo per i punti che ci cadono dentro
        let candidates = all.filter { !$0.contains(lat: first.lat, lon: first.lon) }.map { z -> (Zone, ClosedRange<Double>, ClosedRange<Double>) in
            let lats = z.perimeter.map(\.lat), lons = z.perimeter.map(\.lon)
            return (z, (lats.min() ?? 0)...(lats.max() ?? 0), (lons.min() ?? 0)...(lons.max() ?? 0))
        }
        var result: [RouteCrossing] = []
        let total = Double(max(path.count - 1, 1))
        for (i, p) in path.enumerated() {
            for (z, lat, lon) in candidates where lat.contains(p.lat) && lon.contains(p.lon)
                && !result.contains(where: { $0.zone.id == z.id }) && z.contains(lat: p.lat, lon: p.lon) {
                let when = departure.addingTimeInterval(travelTime * Double(i) / total)
                let area = areas[z.id]
                result.append(RouteCrossing(zone: z, answer: area != nil ? pedestrianAnswer : answer(z, when), at: when,
                                            isDestination: z.contains(lat: last.lat, lon: last.lon), entry: p, pedestrian: area))
            }
        }
        return result
    }

    /// La risposta per un'area pedonale: mai, a nessuna ora (la stessa frase di Viaggio e Varco)
    static var pedestrianAnswer: Answer {
        Answer(verdict: .no(reason: L("It's a pedestrian area: cars can't drive in at any time, whatever the ZTL hours.")),
               gatesOn: true, nextChange: nil)
    }

    static func pedestrianZoneId(_ a: PedestrianArea) -> String { "pedestrian:" + a.id }

    /// Una zona fatta dal perimetro dell'area pedonale, attiva a ogni ora: la usano la lista del percorso, la mappa
    /// della guida e la barra del viaggio come una zona qualsiasi. Il nome breve è «Area pedonale»
    static func pedestrianZone(_ a: PedestrianArea, checkedOn: Date) -> Zone {
        let name = String(format: L("Pedestrian area · %@"), a.name)
        var z = Zone(id: pedestrianZoneId(a), name: name, name_it: name, name_de: name, kind: .restricted,
                     summary: L("Cars can't drive in here at any time, except authorised vehicles. Park outside and walk."),
                     perimeter: a.perimeter, gates: [],
                     windows: [TimeWindow(weekdays: Set(1...7), start: 0, end: 24 * 60)],
                     freeOnHolidays: false, exemptFuels: [], hotelCanRegister: false,
                     source: Source(authority: "OpenStreetMap", pageURL: URL(string: "https://www.openstreetmap.org")!,
                                    ordinance: nil, ordinanceURL: nil, quote: nil, quoteTranslation: nil,
                                    checkedOn: checkedOn, reviewedByHuman: false, pending: [], links: []))
        z.prepare()
        return z
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
