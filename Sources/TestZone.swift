import Foundation

// «Modalità prova» (Tu → Impostazioni): una ZTL FINTA intorno a dove sei, larga circa 400 m, con uno o due varchi
// sulle strade vere lì vicino e un parcheggio finto fuori. Passa da tutto il resto dell'app come una zona vera (motore
// delle regole, risposta in Varco, mappa, guardiano, navigazione, Live Activity, voce, «Parcheggia fuori»), così si
// prova tutto senza girare l'Italia. Solo su questo telefono: mai accesa da sola, mai sincronizzata né inviata.
// Questa parte è senza mappe (la usano anche il widget, tramite Store, e i test); i varchi sulle strade li cerca
// TestModeBuilder (TestMode.swift) con le indicazioni di Apple.

/// La zona di prova salvata sul telefono: dove sta, i varchi, il parcheggio e se è accesa
struct TestModeState: Codable, Equatable {
    var center: Coordinate
    var gates: [Gate]
    var parking: Coordinate
    /// true = ZTL attiva adesso (tutto il giorno, anche nei festivi); false = spenta
    var active: Bool
    var created: Date = Date()
}

enum TestZone {
    static let cityId = "gatelr-prova"
    static let zoneId = "gatelr-prova-ztl"
    static let parkingId = "gatelr-prova-parcheggio"
    /// Metri dal centro al bordo: la zona è larga circa 400 m (tra 300 e 500 m chiesti)
    static let radius = 200.0
    static let sides = 16
    /// Da dove arrivano i varchi: sud-ovest e nord-est
    static let gateBearings: [Double] = [225, 45]
    /// Il parcheggio finto: a sud-est, fuori dalla zona
    static let parkingBearing = 135.0
    static let parkingDistance = radius + 230

    static func isTest(cityId: String) -> Bool { cityId == Self.cityId }
    static func isTest(zoneId: String) -> Bool { zoneId == Self.zoneId }

    /// Il punto a «meters» metri da «c» in direzione «bearing» (gradi da nord, in senso orario)
    static func offset(_ c: Coordinate, meters: Double, bearing: Double) -> Coordinate {
        let b = bearing * .pi / 180
        let dLat = meters * cos(b) / 111_320
        let dLon = meters * sin(b) / (111_320 * cos(c.lat * .pi / 180))
        return Coordinate(lat: c.lat + dLat, lon: c.lon + dLon)
    }

    static func meters(_ a: Coordinate, _ b: Coordinate) -> Double {
        let k = cos((a.lat + b.lat) / 2 * .pi / 180)
        return hypot((a.lat - b.lat) * 111_320, (a.lon - b.lon) * 111_320 * k)
    }

    /// Il perimetro: un poligono regolare di «sides» lati intorno al centro
    static func perimeter(around c: Coordinate) -> [Coordinate] {
        (0..<sides).map { offset(c, meters: radius, bearing: Double($0) * 360 / Double(sides)) }
    }

    /// I varchi senza le strade (giro delle foto, nessuna rete): sul bordo, nelle direzioni di gateBearings
    static func plainGates(around c: Coordinate) -> [Gate] {
        gateBearings.enumerated().map { i, b in
            Gate(id: "prova-\(i + 1)", name: gateName(i + 1, street: nil), location: offset(c, meters: radius, bearing: b))
        }
    }

    static func gateName(_ n: Int, street: String?) -> String {
        let base = String(format: L("Test gate %lld"), n)
        guard let street, !street.isEmpty else { return base }
        return base + " · " + street
    }

    /// Il primo punto della strada che cade dentro il perimetro: lì si entra davvero con l'auto
    static func entry(on path: [Coordinate], perimeter: [Coordinate]) -> Coordinate? {
        guard let first = path.first, !Zone.inside(perimeter, lat: first.lat, lon: first.lon) else { return nil }
        return path.first { Zone.inside(perimeter, lat: $0.lat, lon: $0.lon) }
    }

    /// Una zona di prova nuova, con i varchi dati (o quelli sul bordo) e il parcheggio fuori
    static func make(at c: Coordinate, gates: [Gate]? = nil, parking: Coordinate? = nil, active: Bool = true,
                     now: Date = Date()) -> TestModeState {
        let list = gates.flatMap { $0.isEmpty ? nil : $0 } ?? plainGates(around: c)
        return TestModeState(center: c, gates: list, parking: parking ?? offset(c, meters: parkingDistance, bearing: parkingBearing),
                             active: active, created: now)
    }

    /// La zona per il motore delle regole: «ZONA DI PROVA», attiva tutto il giorno ogni giorno (anche nei festivi) o spenta
    static func zone(_ s: TestModeState, now: Date = Date()) -> Zone {
        let title = L("TEST ZONE")
        var z = Zone(
            id: zoneId,
            name: title + " · GateLR",
            name_it: title + " · GateLR",
            name_de: title + " · GateLR",
            kind: .restricted,
            summary: L("A fake ZTL made by test mode around where you were, to try alerts, navigation and answers. It isn't a real rule: turn it off in You → Settings."),
            perimeter: perimeter(around: s.center),
            gates: s.gates,
            windows: s.active ? [TimeWindow(weekdays: Set(1...7), start: 0, end: 24 * 60)] : [],
            freeOnHolidays: false,
            exemptFuels: [],
            hotelCanRegister: false,
            source: Source(
                authority: "GateLR test mode",
                pageURL: URL(string: "https://github.com/LR-apps609/GateLR/blob/main/docs/prova-sul-campo.md")!,
                ordinance: nil, ordinanceURL: nil,
                quote: nil, quoteTranslation: nil,
                // Sempre «controllata oggi»: il motore non la dà mai per vecchia
                checkedOn: now,
                reviewedByHuman: false,
                pending: [], links: []))
        z.prepare()
        return z
    }

    /// La città finta che contiene solo la zona di prova (stato «sample»: l'app dice «Dati di esempio, non reali»)
    static func city(_ s: TestModeState, now: Date = Date()) -> City {
        City(id: cityId, name: L("Test mode"), center: s.center, zones: [zone(s, now: now)], status: .sample, license: nil)
    }

    /// Le città dell'app con la zona di prova (se c'è) e senza quella vecchia
    static func merged(_ cities: [City], with s: TestModeState?, now: Date = Date()) -> [City] {
        var list = cities.filter { !isTest(cityId: $0.id) }
        if let s { list.append(city(s, now: now)) }
        return list
    }
}
