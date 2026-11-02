import Foundation

// 1.19.3 «Un solo avviso». Prima c'erano tre sistemi con regole diverse: la guida (lungo il percorso), il guardiano
// (distanza in linea d'aria dal perimetro, senza aree pedonali, velocità fissa) e gli avvisi ad app chiusa (cerchi
// attorno ai 20 varchi più vicini, senza direzione, titolo fisso «ZTL attiva» anche quando si entrava). Ora tutti e tre
// chiedono qui: la stessa risposta del motore per il TUO veicolo all'ora d'arrivo (permessi della zona, hotel, aree
// pedonali, fonte non ufficiale = giallo, copertura), solo le zone DAVANTI nel verso di marcia, e le stesse parole.
// Mai un avviso verde.

/// Una zona (o un'area pedonale) che si può avere davanti
struct ThreatCandidate: Equatable {
    /// Per un'area pedonale: la zona fatta dal suo perimetro (RouteCheck.pedestrianZone), sempre chiusa
    var zone: Zone
    var cityName: String
    var pedestrian: PedestrianArea? = nil
    var id: String { zone.id }

    /// «Firenze Settore A», «Area pedonale · Via Galliera»
    var name: String { pedestrian != nil ? zone.localizedName : "\(cityName) \(zone.shortName)" }
    var unofficial: Bool { pedestrian == nil && zone.isUnofficial }
}

/// Quanto è grave quello che c'è davanti, come si mostra (colori di GateLR)
enum ThreatLevel: String, Equatable {
    /// Rosso: non entrare (anche l'area pedonale)
    case stop
    /// Giallo: entri a una condizione
    case condition
    /// Giallo con il «?»: non sicuro, dati vecchi, festivo non confermato, «sì» da fonte non ufficiale
    case check
    /// Puoi entrare: nessun avviso
    case clear

    init(_ shown: Verdict) {
        switch shown {
        case .no: self = .stop
        case .conditional: self = .condition
        case .unsure: self = .check
        case .yes: self = .clear
        }
    }

    /// Il livello della Live Activity («no» rosso, «cond» giallo)
    var activity: String {
        switch self {
        case .stop: "no"
        case .condition, .check: "cond"
        case .clear: "ok"
        }
    }
}

/// Lo stato a riposo, quando davanti non c'è niente da segnalare
enum ThreatResting: Equatable {
    /// Nessuna zona conosciuta qui (fuori dalle città che conosciamo): neutro, mai verde
    case unknownPlace
    /// Siamo in una città che conosciamo e davanti non c'è una ZTL attiva per te: grigio «nessuna ZTL attiva»
    case clear
}

/// Una zona davanti con la sua risposta
struct ZoneThreat: Equatable {
    var candidate: ThreatCandidate
    /// Metri in linea d'aria fino al bordo (0 = ci sei dentro)
    var meters: Double
    var answer: Answer
    /// Il punto dove si entra (il punto del perimetro più vicino, o il varco)
    var point: Coordinate

    var zone: Zone { candidate.zone }
    var shown: Verdict { ThreatEvaluator.shown(answer.verdict, candidate) }
    var level: ThreatLevel { ThreatLevel(shown) }
    /// «Non entrare · Firenze Settore A»; nil se puoi entrare (mai un avviso verde)
    var title: String? { ThreatEvaluator.title(shown: shown, candidate: candidate) }
    var body: String { ThreatEvaluator.body(self) }
    /// La frase breve: «Non entrare», «Probabilmente sì · fonte non ufficiale: controlla il cartello»
    var spoken: String { ThreatEvaluator.spoken(answer.verdict, candidate) }
}

enum ThreatEvaluator {
    /// Oltre questi metri una zona non conta (né per l'avviso né per «nessuna zona nota qui»)
    static let lookahead: Double = 3_000
    /// Davanti = entro questo angolo dal verso di marcia
    static let aheadCone: Double = 70
    /// Da qui in giù la zona è «davanti» in ogni caso (ci sei sopra)
    static let onTop: Double = 30

    // MARK: La risposta come si mostra

    /// Area pedonale: sempre «no». Un «sì» da fonte non ufficiale: «non sicuro» (giallo con il «?»)
    static func shown(_ v: Verdict, _ c: ThreatCandidate) -> Verdict {
        if c.pedestrian != nil { return RouteCheck.pedestrianAnswer.verdict }
        return v.shown(unofficial: c.unofficial)
    }

    /// Vero se bisogna avvisare: tutto tranne il verde
    static func alerts(_ v: Verdict, _ c: ThreatCandidate) -> Bool { !shown(v, c).isYes }

    /// La frase breve detta da Siri, dalla voce e nella Live Activity
    static func spoken(_ v: Verdict, _ c: ThreatCandidate) -> String {
        if c.pedestrian != nil { return L("Don't enter") }
        return v.spokenText(unofficial: c.unofficial)
    }

    /// Il titolo dell'avviso dalle parole della risposta. nil = verde: non si avvisa
    static func title(shown: Verdict, candidate c: ThreatCandidate) -> String? {
        switch shown {
        case .yes: return nil
        case .no: return String(format: L(c.unofficial ? "Probably not · %@" : "Don't enter · %@"), c.name)
        case .conditional: return String(format: L("You can enter on one condition: %@"), c.name)
        case .unsure: return String(format: L("? Check the sign · %@"), c.name)
        }
    }

    /// «Tra 400 m. Puoi entrare solo con il biglietto… Tocca per i parcheggi fuori.»
    static func body(_ t: ZoneThreat) -> String {
        var parts: [String] = []
        parts.append(t.meters > 0 ? String(format: L("In %@."), DriveSession.distanceText(t.meters)) : String(format: L("You're inside %@"), t.candidate.name) + ".")
        switch t.shown {
        case .no(let reason): parts.append(t.candidate.unofficial ? t.spoken : reason)
        case .conditional(_, let condition): parts.append(condition)
        case .unsure(let reason): parts.append(t.candidate.unofficial ? t.spoken : reason)
        case .yes: break
        }
        parts.append(L("Tap for car parks outside."))
        return parts.filter { !$0.isEmpty }.joined(separator: " ")
    }

    // MARK: Le zone vicine

    /// Le zone e le aree pedonali entro «within» metri (dal loro rettangolo): le altre non si guardano
    static func candidates(_ cities: [City], near p: Coordinate, within: Double = lookahead, now: Date = Date()) -> [ThreatCandidate] {
        var out: [ThreatCandidate] = []
        for city in cities {
            for z in city.zones where ((z.bounds ?? BBox(z.perimeter))?.distance(lat: p.lat, lon: p.lon) ?? .infinity) < within {
                out.append(ThreatCandidate(zone: z, cityName: city.localizedName))
            }
            for a in city.pedestrian ?? [] where ((a.bounds ?? BBox(a.perimeter))?.distance(lat: p.lat, lon: p.lon) ?? .infinity) < within {
                out.append(ThreatCandidate(zone: RouteCheck.pedestrianZone(a, checkedOn: now), cityName: city.localizedName, pedestrian: a))
            }
        }
        return out
    }

    // MARK: Davanti o dietro

    /// L'angolo da a verso b (gradi, 0 = nord, in senso orario)
    static func bearing(_ a: Coordinate, _ b: Coordinate) -> Double {
        let k = cos(a.lat * .pi / 180)
        let x = (b.lon - a.lon) * k, y = b.lat - a.lat
        let deg = atan2(x, y) * 180 / .pi
        return deg < 0 ? deg + 360 : deg
    }

    /// La differenza tra due direzioni, da 0 a 180 gradi
    static func angle(_ a: Double, _ b: Double) -> Double {
        let d = abs(a - b).truncatingRemainder(dividingBy: 360)
        return d > 180 ? 360 - d : d
    }

    /// Il punto del perimetro più vicino e la distanza in metri (la stessa misura di Zone.distance)
    static func nearestPoint(_ perimeter: [Coordinate], to p: Coordinate) -> (point: Coordinate, meters: Double) {
        let k = cos(p.lat * .pi / 180)
        var best = (point: p, meters: Double.infinity)
        for q in perimeter {
            let m = hypot((q.lat - p.lat) * 111_000, (q.lon - p.lon) * 111_000 * k)
            if m < best.meters { best = (q, m) }
        }
        return best
    }

    /// La zona è davanti? Con la direzione di marcia (course ≥ 0): solo entro ±70°. Senza direzione (fermo, GPS
    /// impreciso, avviso ad app chiusa): prudente, conta se ti stai avvicinando, o se non lo sappiamo ancora
    static func isAhead(from p: Coordinate, to target: Coordinate, meters: Double, course: Double?, approaching: Bool?) -> Bool {
        if meters < onTop { return true }
        if let course, course >= 0 { return angle(course, bearing(p, target)) <= aheadCone }
        return approaching ?? true
    }

    // MARK: Il calcolo (puro, testabile)

    struct Scan: Equatable {
        /// La zona più vicina davanti in cui non entri liberamente (a parità di metri la più grave)
        var threat: ZoneThreat?
        /// Le zone in cui sei appena entrato e dove non potevi entrare liberamente
        var entered: [ZoneThreat]
        /// I metri da ogni zona vicina (per sapere al prossimo giro se ti avvicini)
        var distances: [String: Double]
        /// Senza minacce: neutro fuori dalle città che conosciamo, «nessuna ZTL attiva» dentro
        var resting: ThreatResting
    }

    /// «answer» dà la risposta del motore per la zona a quella distanza (all'ora d'arrivo stimata)
    static func scan(at p: Coordinate, course: Double?, candidates: [ThreatCandidate], last: [String: Double],
                     covered: Bool, answer: (ThreatCandidate, Double) -> Answer) -> Scan {
        var distances: [String: Double] = [:]
        var best: ZoneThreat?
        var entered: [ZoneThreat] = []
        for c in candidates {
            let inside = c.zone.contains(lat: p.lat, lon: p.lon)
            let edge: (point: Coordinate, meters: Double) = inside ? (point: p, meters: 0) : nearestPoint(c.zone.perimeter, to: p)
            let point = edge.point, d = edge.meters
            let before = last[c.id]
            distances[c.id] = d
            guard d < lookahead else { continue }
            if d == 0 {
                if let before, before > 0 {
                    let a = answer(c, 0)
                    if alerts(a.verdict, c) { entered.append(ZoneThreat(candidate: c, meters: 0, answer: a, point: p)) }
                }
                continue
            }
            guard isAhead(from: p, to: point, meters: d, course: course, approaching: before.map { d < $0 - 3 }) else { continue }
            let a = answer(c, d)
            guard alerts(a.verdict, c) else { continue }
            let t = ZoneThreat(candidate: c, meters: d, answer: a, point: point)
            if let b = best, b.meters < d || (b.meters == d && b.shown.severity >= t.shown.severity) { continue }
            best = t
        }
        return Scan(threat: best, entered: entered, distances: distances,
                    resting: covered ? .clear : .unknownPlace)
    }

    /// L'ora d'arrivo stimata a quella distanza: la velocità vera se ti muovi, altrimenti 9 m/s (32 km/h in città)
    static func arrival(in meters: Double, speed: Double?, now: Date = Date()) -> Date {
        let v = (speed ?? 0) > 3 ? speed! : 9
        return now.addingTimeInterval(meters / v)
    }
}

/// Lo stesso avviso una volta sola per avvicinamento: torna possibile quando ti allontani (oltre 900 m) o dopo 30
/// minuti. Uno solo per tutta l'app: guida, guardiano e avvisi ad app chiusa non si ripetono a vicenda
struct ThreatDeduper {
    var resetDistance: Double = 900
    var cooldown: TimeInterval = 30 * 60
    private(set) var fired: [String: Date] = [:]

    /// Vero la prima volta per questo avvicinamento (e lo segna)
    mutating func shouldAlert(_ key: String, now: Date = Date()) -> Bool {
        if let t = fired[key], now.timeIntervalSince(t) < cooldown { return false }
        fired[key] = now
        return true
    }

    /// Le zone da cui ti sei allontanato si possono avvisare di nuovo. «distances» per id della zona; le chiavi
    /// sono «<id>» o «<prefisso>|<id>»
    mutating func moved(_ distances: [String: Double]) {
        for key in fired.keys {
            let id = key.split(separator: "|").last.map(String.init) ?? key
            if let d = distances[id], d > resetDistance { fired[key] = nil }
        }
    }

    mutating func reset() { fired = [:] }
}

/// L'indirizzo che apre «Parcheggia fuori» per una zona: gatelr://park?zone=<id>&lat=…&lon=…&name=…
enum ParkLink {
    static func url(zoneId: String, name: String, at p: Coordinate) -> URL? {
        var c = URLComponents()
        c.scheme = "gatelr"; c.host = "park"
        c.queryItems = [URLQueryItem(name: "zone", value: zoneId), URLQueryItem(name: "lat", value: String(format: "%.6f", p.lat)),
                        URLQueryItem(name: "lon", value: String(format: "%.6f", p.lon)), URLQueryItem(name: "name", value: name)]
        return c.url
    }

    /// Il posto per cui cercare i parcheggi fuori, da un indirizzo gatelr://park
    static func place(from url: URL) -> Place? {
        guard url.scheme == "gatelr", url.host?.lowercased() == "park",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let lat = items.first(where: { $0.name == "lat" })?.value.flatMap(Double.init),
              let lon = items.first(where: { $0.name == "lon" })?.value.flatMap(Double.init) else { return nil }
        let name = items.first(where: { $0.name == "name" })?.value ?? ""
        return Place(name: name, address: "", location: Coordinate(lat: lat, lon: lon))
    }
}

extension Store {
    /// 1.19.3: la risposta per una zona davanti, uguale per guida, guardiano, avvisi ad app chiusa e Siri: il veicolo
    /// scelto e i permessi della sua zona (Store.answer), l'area pedonale sempre «no», l'hotel solo se la meta è il tuo
    /// hotel ed è dentro quella zona (prima il guardiano diceva hotelInside false e gli avvisi ad app chiusa true)
    func threatAnswer(_ c: ThreatCandidate, at date: Date, destination: Place?) -> Answer {
        if c.pedestrian != nil { return RouteCheck.pedestrianAnswer }
        let hotel = destination.map { isHotel($0) && c.zone.contains(lat: $0.location.lat, lon: $0.location.lon) } ?? false
        return answer(at: date, zone: c.zone, hotelInside: hotel)
    }

}
