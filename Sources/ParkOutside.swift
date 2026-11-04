import Foundation
import MapKit
import SwiftUI

// «Parcheggia fuori e cammina»: quando la destinazione è rossa o ambra, i parcheggi più vicini FUORI da ogni ZTL
// attiva all'ora d'arrivo, con minuti a piedi, prezzo e orari da OpenStreetMap, e «Avvia» verso il parcheggio.
// I dati: Resources/Parking/<città>.json (Tools/fetch_parking.py + Tools/build_parking.py, ODbL), per l'uso offline;
// per una città senza file, Overpass dal telefono con la copia sul disco; se manca anche quello, la ricerca di Apple.

/// Un parcheggio di OpenStreetMap (amenity=parking)
struct ParkingSpot: Codable, Hashable, Identifiable {
    var id: String              // «w123» (way), «n45» (node), «r6» (relation)
    var name: String?
    var lat: Double
    var lon: Double
    var kind: String?           // parking=multi-storey, underground, surface, rooftop
    var fee: String?            // fee=yes / no
    var charge: String?         // charge=2 EUR/hour
    var hours: String?          // opening_hours
    var capacity: Int?

    var location: Coordinate { Coordinate(lat: lat, lon: lon) }
    var displayName: String { name ?? L("Car park") }

    var place: Place { Place(name: displayName, address: "", location: location) }

    var symbol: String {
        switch kind {
        case "multi-storey", "rooftop": "building.2.fill"
        case "underground": "arrow.down.square.fill"
        default: "parkingsign"
        }
    }

    var kindText: String? {
        switch kind {
        case "multi-storey", "rooftop": L("Multi-storey")
        case "underground": L("Underground")
        case "surface": L("Open-air")
        default: nil
        }
    }

    /// «Gratis», «2 EUR/ora», «A pagamento», «Prezzo non indicato»
    var priceText: String {
        if let charge, !charge.isEmpty { return String(format: L("Price: %@"), charge) }
        switch fee?.lowercased() {
        case "no": return L("Free")
        case nil: return L("Price not listed")
        default: return L("Paid parking")
        }
    }
}

struct ParkingFile: Codable {
    var city: String
    var generated: String?
    var license: String?
    var spots: [ParkingSpot]
}

/// I parcheggi di una città: dentro l'app, dal disco o da Overpass
@MainActor
enum ParkingData {
    private static var memory: [String: [ParkingSpot]] = [:]
    static let hosts = ["https://overpass-api.de/api/interpreter", "https://overpass.kumi.systems/api/interpreter",
                        "https://maps.mail.ru/osm/tools/overpass/api/interpreter"]

    static func spots(for city: City) async -> [ParkingSpot] {
        // Modalità prova: il parcheggio finto fuori dalla zona di prova (mai in memoria: la zona si può spostare)
        if TestZone.isTest(cityId: city.id) { return [TestZone.parkingSpot(at: city.center, store: Store.shared)] }
        if let hit = memory[city.id] { return hit }
        // 1.19.5: la stessa città chiesta due volte insieme (il percorso di Viaggio e il riquadro «Parcheggia fuori»)
        // aspetta la stessa ricerca invece di farne due
        if let running = inFlight[city.id] { return await running.value }
        let task = Task { @MainActor in await load(city) }
        inFlight[city.id] = task
        let list = await task.value
        inFlight[city.id] = nil
        return list
    }

    private static var inFlight: [String: Task<[ParkingSpot], Never>] = [:]

    private static func load(_ city: City) async -> [ParkingSpot] {
        if let list = bundled(city.id) { memory[city.id] = list; return list }
        let cached = Misure.noParkingCache ? nil : cache(city.id)
        if let cached, cached.fresh { memory[city.id] = cached.spots; return cached.spots }
        // Nel giro delle foto niente rete: si usa quello che c'è (il test delle misure con -uiLive la usa)
        guard !ProcessInfo.processInfo.arguments.contains("-uitest") || Misure.live else { return cached?.spots ?? [] }
        if let live = await live(city) {
            memory[city.id] = live
            store(live, for: city.id)
            return live
        }
        return cached?.spots ?? []
    }

    static func bundled(_ id: String) -> [ParkingSpot]? {
        guard let url = Bundle.main.url(forResource: id, withExtension: "json", subdirectory: "Parking"),
              let data = try? Data(contentsOf: url) else { return nil }
        return (try? JSONDecoder().decode(ParkingFile.self, from: data))?.spots
    }

    private static var cacheDir: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("Parking", isDirectory: true)
    }

    /// La copia sul disco: vale 30 giorni, poi si riprova la rete (e se non c'è si usa lo stesso)
    private static func cache(_ id: String) -> (spots: [ParkingSpot], fresh: Bool)? {
        guard let url = cacheDir?.appendingPathComponent("\(id).json"), let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(ParkingFile.self, from: data) else { return nil }
        let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
        return (file.spots, Date().timeIntervalSince(date) < 30 * 86_400)
    }

    private static func store(_ spots: [ParkingSpot], for id: String) {
        guard let dir = cacheDir else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = ParkingFile(city: id, generated: ISO8601DateFormatter().string(from: Date()),
                               license: "© OpenStreetMap contributors, ODbL", spots: spots)
        if let data = try? JSONEncoder().encode(file) { try? data.write(to: dir.appendingPathComponent("\(id).json")) }
    }

    /// Il rettangolo delle zone vietate o a pagamento (le verdi, grandi come la città, solo se non c'è altro), più 2,5 km
    static func searchBox(_ city: City, margin: Double = 2_500) -> BBox? {
        let strict = city.zones.filter { $0.type != .green }
        let points = (strict.isEmpty ? city.zones : strict).flatMap(\.perimeter)
        guard let b = BBox(points) else { return nil }
        let dLat = margin / 111_000, dLon = margin / (111_000 * cos((b.minLat + b.maxLat) / 2 * .pi / 180))
        return BBox(minLat: b.minLat - dLat, minLon: b.minLon - dLon, maxLat: b.maxLat + dLat, maxLon: b.maxLon + dLon)
    }

    /// Quanto aspettare un server di Overpass (prima 40 secondi per server, uno dopo l'altro: fino a 2 minuti di «Cerco…»)
    nonisolated static let hostTimeout: TimeInterval = 20
    /// Il server di riserva parte dopo questa attesa se il primo non ha ancora risposto (non tutti e tre insieme
    /// a ogni ricerca: i server di Overpass sono gratuiti e condivisi)
    nonisolated static let hedgeDelay: TimeInterval = 3

    /// Overpass dal telefono, con un User-Agent che dice chi siamo. 1.19.5: i server di riserva partono a 3 e 6 secondi
    /// se il primo non ha ancora risposto (o subito, se ha già sbagliato); vale la prima risposta buona e le altre si
    /// annullano. Ognuno al massimo 20 secondi: al peggio circa 26 secondi, prima fino a 2 minuti
    private static func live(_ city: City) async -> [ParkingSpot]? {
        guard let b = searchBox(city) else { return nil }
        let bb = String(format: "%.5f,%.5f,%.5f,%.5f", b.minLat, b.minLon, b.maxLat, b.maxLon)
        let query = "[out:json][timeout:25];( nwr[\"amenity\"=\"parking\"](\(bb)); );out center tags;"
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let body = "data=" + (query.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1"
        let requests: [URLRequest] = hosts.compactMap { host in
            guard let url = URL(string: host) else { return nil }
            var req = URLRequest(url: url, timeoutInterval: hostTimeout)
            req.httpMethod = "POST"
            req.setValue("GateLR/\(version) (iOS; ZTL parking outside)", forHTTPHeaderField: "User-Agent")
            req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            req.httpBody = body.data(using: .utf8)
            return req
        }
        return await firstGood(requests)
    }

    private enum Outcome: Sendable { case timer, done([ParkingSpot]?) }

    /// La prima risposta buona: la richiesta i parte dopo i × «hedge» secondi, o subito se quelle partite hanno già
    /// sbagliato; nil se nessuna risponde bene. Le altre si annullano appena una risponde
    nonisolated static func firstGood(_ requests: [URLRequest], hedge: TimeInterval = hedgeDelay,
                                      fetch: @escaping @Sendable (URLRequest) async -> [ParkingSpot]? = overpass) async -> [ParkingSpot]? {
        guard !requests.isEmpty else { return nil }
        return await withTaskGroup(of: Outcome.self) { group in
            var next = 1, running = 1
            let first = requests[0]
            group.addTask { .done(await fetch(first)) }
            for i in 1..<requests.count {
                group.addTask {
                    try? await Task.sleep(for: .seconds(hedge * Double(i)))
                    return .timer
                }
            }
            while let outcome = await group.next() {
                var start = false
                switch outcome {
                case .done(let list?):
                    group.cancelAll()
                    return list
                case .done(nil):
                    running -= 1
                    start = true
                case .timer:
                    start = true
                }
                if start && next < requests.count {
                    let req = requests[next]
                    next += 1; running += 1
                    group.addTask { .done(await fetch(req)) }
                }
                if running == 0 && next >= requests.count { break }
            }
            group.cancelAll()
            return nil
        }
    }

    nonisolated static func overpass(_ req: URLRequest) async -> [ParkingSpot]? {
        guard let (data, response) = try? await URLSession.shared.data(for: req),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return fromOverpass(data)
    }

    private struct Overpass: Decodable {
        struct Center: Decodable { var lat: Double; var lon: Double }
        struct Element: Decodable {
            var type: String
            var id: Int64
            var lat: Double?
            var lon: Double?
            var center: Center?
            var tags: [String: String]?
        }
        var elements: [Element]
    }

    /// La risposta di Overpass → parcheggi utili (le stesse regole di Tools/build_parking.py)
    nonisolated static func fromOverpass(_ data: Data) -> [ParkingSpot]? {
        guard let r = try? JSONDecoder().decode(Overpass.self, from: data) else { return nil }
        return r.elements.compactMap { e -> ParkingSpot? in
            let tags = e.tags ?? [:]
            guard let lat = e.lat ?? e.center?.lat, let lon = e.lon ?? e.center?.lon, keep(tags) else { return nil }
            let prefix = e.type == "way" ? "w" : e.type == "relation" ? "r" : "n"
            return ParkingSpot(id: "\(prefix)\(e.id)", name: tags["name"] ?? tags["name:it"], lat: lat, lon: lon,
                               kind: tags["parking"], fee: tags["fee"], charge: tags["charge"], hours: tags["opening_hours"],
                               capacity: tags["capacity"].flatMap { Int($0.trimmingCharacters(in: .whitespaces)) })
        }
    }

    /// Solo parcheggi aperti a tutti e abbastanza grandi da trovarli: niente privati, clienti, residenti, posti in strada
    nonisolated static func keep(_ tags: [String: String]) -> Bool {
        guard tags["amenity"] == nil || tags["amenity"] == "parking" else { return false }
        let closed: Set<String> = ["private", "no", "customers", "residents", "delivery", "permit", "employees", "agricultural", "forestry", "military"]
        if let a = tags["access"], closed.contains(a) { return false }
        let street: Set<String> = ["street_side", "lane", "on_kerb", "half_on_kerb", "layby", "sheds", "carports", "garage_boxes", "garages"]
        if let p = tags["parking"], street.contains(p) { return false }
        let capacity = tags["capacity"].flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        if tags["name"] != nil || tags["name:it"] != nil { return true }
        if ["multi-storey", "underground", "rooftop"].contains(tags["parking"] ?? "") { return true }
        if tags["park_ride"].map({ $0 != "no" }) == true { return true }
        return (capacity ?? 0) >= 30 || (tags["fee"] != nil && (capacity ?? 30) >= 30)
    }
}

/// Un parcheggio proposto: quanto si cammina, se è aperto all'arrivo, se la strada per arrivarci è libera
struct ParkingOption: Identifiable, Equatable {
    var spot: ParkingSpot
    var walkMeters: Double
    var walkMeasured = false        // percorso a piedi di Apple, non la stima in linea d'aria
    var open: Bool?                 // nil = orari non indicati o non leggibili
    var routeClear: Bool?           // nil = non controllata (posizione sconosciuta)
    var score: Double
    var id: String { spot.id }
    var walkMinutes: Int { max(1, Int((walkMeters / ParkOutside.walkSpeed).rounded())) }
}

enum ParkOutside {
    /// Metri al minuto a piedi (4,8 km/h)
    static let walkSpeed = 80.0
    /// Le strade non sono in linea d'aria: la stima a piedi senza percorso
    static let detour = 1.3

    /// Fuori da ogni ZTL attiva all'ora d'arrivo (e da ogni area pedonale): in ogni zona che contiene il punto
    /// quel veicolo, a quell'ora, deve poter entrare («sì»). Le condizioni e i «non sicuro» non bastano.
    static func isOutside(_ p: Coordinate, zones: [Zone], pedestrian: [PedestrianArea], at date: Date,
                          answer: (Zone, Date) -> Answer) -> Bool {
        if pedestrian.contains(where: { $0.contains(lat: p.lat, lon: p.lon) }) { return false }
        for z in zones where z.contains(lat: p.lat, lon: p.lon) {
            if case .yes = answer(z, date).verdict { continue }
            return false
        }
        return true
    }

    /// Distanza in metri (approssimata, va bene sotto qualche chilometro)
    static func meters(_ a: Coordinate, _ b: Coordinate) -> Double {
        let k = cos((a.lat + b.lat) / 2 * .pi / 180)
        return hypot((a.lat - b.lat) * 111_000, (a.lon - b.lon) * 111_000 * k)
    }

    /// L'ordine: meno strada a piedi; un parcheggio senza nome conta 250 m in più, uno piccolo (meno di 15 posti)
    /// 150 m, orari scritti ma non leggibili 50 m. Esclusi quelli chiusi all'arrivo e quelli oltre «maxWalk» in linea d'aria.
    /// Due parcheggi con lo stesso nome a meno di 150 m (ingressi dello stesso) contano una volta sola.
    static func rank(_ spots: [ParkingSpot], to destination: Coordinate, at date: Date, holiday: Bool = false,
                     calendar: Calendar = RuleEngine.rome, maxWalk: Double = 2_000) -> [ParkingOption] {
        var options: [ParkingOption] = []
        for s in spots {
            let straight = meters(s.location, destination)
            guard straight <= maxWalk else { continue }
            let hours = OpeningHours.parse(s.hours)
            let open = hours?.isOpen(at: date, calendar: calendar, holiday: holiday)
            if open == false { continue }
            let walk = straight * detour
            options.append(ParkingOption(spot: s, walkMeters: walk, open: open, score: score(s, walk: walk, readable: hours != nil)))
        }
        options.sort { $0.score != $1.score ? $0.score < $1.score : $0.id < $1.id }
        var out: [ParkingOption] = []
        for o in options where !out.contains(where: { $0.spot.name != nil && $0.spot.name == o.spot.name && meters($0.spot.location, o.spot.location) < 150 }) {
            out.append(o)
        }
        return out
    }

    static func score(_ s: ParkingSpot, walk: Double, readable: Bool) -> Double {
        var x = walk
        if s.name == nil { x += 250 }
        if let c = s.capacity, c < 15 { x += 150 }
        if s.hours != nil && !readable { x += 50 }
        return x
    }

    /// Dopo i percorsi veri: tolti quelli la cui strada attraversa una ZTL attiva, riordinati con i metri a piedi misurati
    static func finalize(_ options: [ParkingOption], limit: Int = 3) -> [ParkingOption] {
        let clear = options.filter { $0.routeClear != false }
        return clear.map { o in
            var o = o
            o.score = score(o.spot, walk: o.walkMeters, readable: o.spot.hours == nil || o.open != nil)
            return o
        }
        .sorted { $0.score != $1.score ? $0.score < $1.score : $0.id < $1.id }
        .prefix(limit).map { $0 }
    }
}

/// 1.19.5: la ricerca dei parcheggi fuori, una sola per il riquadro «Parcheggia fuori e cammina» (ParkOutsideFinder)
/// e per il parcheggio del percorso di Viaggio (RoutePlanner.parkingOutside): stessa città, stessi dati, stesso ordine
@MainActor
enum ParkOutsideSearch {
    /// La città della destinazione: quella della zona che la contiene, o la più vicina
    static func city(for destination: Coordinate, store: Store) -> City? {
        store.zones(at: destination).first?.city ?? store.nearestCity(to: destination)
    }

    /// I parcheggi fuori da ogni ZTL attiva all'arrivo, nell'ordine di ParkOutside.rank
    static func rankOutside(_ spots: [ParkingSpot], to destination: Coordinate, at date: Date, city: City?, store: Store) -> [ParkingOption] {
        let zones = store.cities.flatMap(\.zones)
        let pedestrian = store.cities.flatMap { $0.pedestrian ?? [] }
        let answer: (Zone, Date) -> Answer = { store.answer(at: $1, zone: $0, hotelInside: false) }
        let outside = spots.filter { ParkOutside.isOutside($0.location, zones: zones, pedestrian: pedestrian, at: date, answer: answer) }
        let holiday = ItalianHolidays.isHoliday(date, calendar: RuleEngine.rome, local: city?.localHolidays)
        return ParkOutside.rank(outside, to: destination, at: date, holiday: holiday)
    }

    /// I parcheggi di OpenStreetMap della città della destinazione (ParkingData: dentro l'app, disco o Overpass, con una
    /// sola ricerca alla volta per città) e quelli fuori, in ordine
    static func osm(to destination: Coordinate, at date: Date, store: Store) async
        -> (city: City?, spots: [ParkingSpot], ranked: [ParkingOption]) {
        guard let city = city(for: destination, store: store) else { return (nil, [], []) }
        let spots = await ParkingData.spots(for: city)
        return (city, spots, rankOutside(spots, to: destination, at: date, city: city, store: store))
    }
}

/// Cerca e controlla i parcheggi per una destinazione
@MainActor
final class ParkOutsideFinder: ObservableObject {
    /// 1.20.2: «failed» = nessun parcheggio e la ricerca di Apple non ha risposto (rete): lo si dice, con «Riprova»
    enum Phase: Equatable { case idle, searching, done, empty, failed }

    /// Come finisce una ricerca: le proposte, altrimenti «non ha risposto» se la rete è mancata, altrimenti «nessuno»
    nonisolated static func phase(options: Int, appleFailed: Bool) -> Phase {
        options > 0 ? .done : (appleFailed ? .failed : .empty)
    }
    @Published private(set) var options: [ParkingOption] = []
    @Published private(set) var phase: Phase = .idle
    /// Vero se la lista viene dalla ricerca di Apple (senza orari né prezzi)
    @Published private(set) var fromApple = false

    func find(to destination: Place, arrival: Date, origin: CLLocationCoordinate2D?, store: Store) async {
        phase = .searching
        options = []
        // 1.19.5: la stessa ricerca del percorso di Viaggio (RoutePlanner.parkingOutside): ParkOutsideSearch
        let found = await ParkOutsideSearch.osm(to: destination.location, at: arrival, store: store)
        var spots = found.spots
        var ranked = found.ranked
        fromApple = spots.isEmpty
        var appleFailed = false
        // Nel giro delle foto (-uitest) niente ricerche di Apple né percorsi: solo i dati dentro l'app
        let offline = ProcessInfo.processInfo.arguments.contains("-uitest") && !Misure.live
        if spots.isEmpty && !offline {
            let apple = await Self.appleParkings(near: destination)
            appleFailed = apple == nil
            spots = apple ?? []
            ranked = ParkOutsideSearch.rankOutside(spots, to: destination.location, at: arrival, city: found.city, store: store)
        }
        ranked = Array(ranked.prefix(5))
        let zones = store.cities.flatMap(\.zones)
        let answer: (Zone, Date) -> Answer = { store.answer(at: $1, zone: $0, hotelInside: false) }
        // Percorsi veri per i primi: a piedi fino alla destinazione, in auto da qui al parcheggio (ZTL lungo la strada).
        // 1.19.5: tre parcheggi alla volta invece di uno (prima 10 richieste ad Apple una dopo l'altra); i conti
        // delle ZTL lungo la strada restano gli stessi, sul thread principale
        if !offline && !ranked.isEmpty {
            let target = destination.location
            let job: (Int) -> @Sendable () async -> (Int, Double?, Bool?) = { i in
                let spot = ranked[i].spot.location
                return {
                    async let walk = Self.walking(from: spot, to: target)
                    async let clear = Self.routeIsClear(from: origin, to: spot, arrival: arrival, zones: zones, answer: answer)
                    return (i, await walk, await clear)
                }
            }
            await withTaskGroup(of: (Int, Double?, Bool?).self) { group in
                var next = 0
                while next < min(3, ranked.count) { group.addTask(operation: job(next)); next += 1 }
                for await (i, walk, clear) in group {
                    if let walk {
                        ranked[i].walkMeters = walk
                        ranked[i].walkMeasured = true
                    }
                    ranked[i].routeClear = clear
                    if next < ranked.count && !Task.isCancelled { group.addTask(operation: job(next)); next += 1 }
                }
            }
            if Task.isCancelled { return }
        }
        options = ParkOutside.finalize(ranked)
        phase = Self.phase(options: options.count, appleFailed: appleFailed)
    }

    private static func walking(from a: Coordinate, to b: Coordinate) async -> Double? {
        let r = MKDirections.Request()
        r.source = MKMapItem(placemark: MKPlacemark(coordinate: a.cl))
        r.destination = MKMapItem(placemark: MKPlacemark(coordinate: b.cl))
        r.transportType = .walking
        return try? await MKDirections(request: r).calculate().routes.first?.distance
    }

    /// La strada in auto fino al parcheggio non entra in una ZTL dove non si può («sì» in ogni zona attraversata)
    /// nil anche senza la tua posizione (non controllata)
    private static func routeIsClear(from origin: CLLocationCoordinate2D?, to spot: Coordinate, arrival: Date,
                                     zones: [Zone], answer: (Zone, Date) -> Answer) async -> Bool? {
        guard let origin else { return nil }
        let r = MKDirections.Request()
        r.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        r.destination = MKMapItem(placemark: MKPlacemark(coordinate: spot.cl))
        r.transportType = .automobile
        guard let route = try? await MKDirections(request: r).calculate().routes.first else { return nil }
        let path = RouteCheck.densify(route.polyline.coordinates.map { Coordinate(lat: $0.latitude, lon: $0.longitude) })
        let departure = RoutePlanner.departure(arriving: arrival, travelTime: route.expectedTravelTime)
        let crossings = RouteCheck.crossings(path: path, zones: zones, departure: departure, travelTime: route.expectedTravelTime, answer: answer)
        guard let worst = RouteCheck.worst(crossings) else { return true }
        if case .yes = worst.answer.verdict { return true }
        return false
    }

    /// Senza i dati di OpenStreetMap: i parcheggi della ricerca di Apple (nome e posizione)
    /// nil se Apple non ha risposto (rete), [] se ha risposto senza parcheggi
    private static func appleParkings(near place: Place) async -> [ParkingSpot]? {
        let region = ParkingFallback.region(around: place.location)      // 1.20.2: lo stesso lato del percorso di Viaggio
        let poi = MKLocalPointsOfInterestRequest(coordinateRegion: region)
        poi.pointOfInterestFilter = MKPointOfInterestFilter(including: [.parking])
        let items: [MKMapItem]
        do { items = try await MKLocalSearch(request: poi).start().mapItems } catch {
            // MKError.placemarkNotFound = nessun risultato, non un errore di rete
            if (error as? MKError)?.code == .placemarkNotFound { return [] }
            return nil
        }
        return items.enumerated().map { i, item in
            let c = item.placemark.coordinate
            return ParkingSpot(id: "a\(i)", name: item.name, lat: c.latitude, lon: c.longitude)
        }
    }
}

/// Il riquadro «Parcheggia fuori e cammina»: i tre parcheggi migliori, uno scelto, «Avvia» con la nota «poi a piedi»
struct ParkOutsideCard: View {
    /// Il giro delle foto e le misure distinguono «nessun parcheggio» da «non risponde»
    static func identifier(_ phase: ParkOutsideFinder.Phase) -> String {
        switch phase {
        case .failed: "park.failed"
        default: "park.empty"
        }
    }

    @EnvironmentObject var store: Store
    var destination: Place
    var arrival: Date
    var onStart: (Place) -> Void
    var onGuardian: (Place, Navigator) -> Void
    var onOptions: ([ParkingOption]) -> Void = { _ in }
    @StateObject private var finder = ParkOutsideFinder()
    @State private var chosen: String?
    /// «Riprova»: cambia la chiave, la ricerca riparte
    @State private var attempt = 0

    private var key: String {
        "\(destination.key)|\(Int(arrival.timeIntervalSinceReferenceDate / 300))|\(store.vehicle.id)|\(store.vehicle.fuel.rawValue)\(store.vehicle.euro)|\(attempt)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "figure.walk").font(.app(size: 15, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 30, height: 30).background(Theme.blueFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Park outside and walk").font(.app(size: 17, weight: .bold)).foregroundStyle(Theme.ink)
                    Text("Car parks outside every ZTL active when you arrive.")
                        .font(.app(size: 12)).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
            }
            switch finder.phase {
            case .idle, .searching:
                // Senza rotella che gira: il giro delle foto aspetta che l'app sia ferma
                Label(L("Searching…"), systemImage: "hourglass").font(.app(size: 14)).foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("park.searching")
                // 1.19.5: la forma delle righe che arrivano, ferma e grigia (niente colori né risposte prima del tempo)
                ParkingSkeleton()
            case .empty, .failed:
                // 1.20.2: il motivo e «Riprova» sulla stessa riga: il riquadro è più basso e il pulsante non finisce
                // sotto la barra delle schede (foto 39); «non risponde» se è mancata la rete, non «nessun parcheggio»
                HStack(alignment: .center, spacing: 10) {
                    Text(finder.phase == .failed ? L("Couldn't search car parks right now. Check your connection.")
                                                 : L("No car parks found just outside the zone."))
                        .font(.app(size: 14)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier(Self.identifier(finder.phase))
                    Button { attempt += 1 } label: {
                        Label(L("Try again"), systemImage: "arrow.clockwise")
                            .font(.app(size: 14, weight: .semibold)).foregroundStyle(Theme.blue)
                            .padding(.horizontal, 12).frame(minHeight: 40)
                            .background(Theme.blueSoft, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .accessibilityIdentifier("park.retry")
                }
            case .done:
                VStack(spacing: 0) {
                    ForEach(Array(finder.options.enumerated()), id: \.element.id) { i, o in
                        row(o, selected: o.id == (chosen ?? finder.options.first?.id))
                            .accessibilityIdentifier("park.option.\(i)")
                        if o.id != finder.options.last?.id { Divider().padding(.leading, 44) }
                    }
                }
                if let pick = finder.options.first(where: { $0.id == chosen }) ?? finder.options.first {
                    StartControls(target: pick.spot.place, label: L("Start"), onStart: onStart, onGuardian: onGuardian,
                                  identifier: "park.start")
                    Label(String(format: L("Then %lld min on foot to %@"), pick.walkMinutes, destination.name), systemImage: "figure.walk")
                        .font(.app(size: 13, weight: .semibold)).foregroundStyle(Theme.ink)
                }
                Text(finder.fromApple ? L("Prices and opening hours: check the car park before you go.")
                                      : L("Car parks, prices and hours: © OpenStreetMap contributors. Check the signs on site."))
                    .font(.app(size: 11)).foregroundStyle(Theme.muted)
            }
        }
        .padding(16)
        .card(20)
        .task(id: key) {
            chosen = nil
            await finder.find(to: destination, arrival: arrival,
                              origin: GateMonitor.shared.location?.coordinate ?? RoutePlanner.testOrigin, store: store)
        }
        .onChange(of: finder.options) { onOptions(finder.options) }
    }

    private func row(_ o: ParkingOption, selected: Bool) -> some View {
        let s = o.spot
        let now = abs(arrival.timeIntervalSinceNow) < 120
        return Button { withAnimation(.snappy) { chosen = o.id } } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: s.symbol).font(.app(size: 15, weight: .bold))
                    .foregroundStyle(selected ? Color.white : Theme.blue)
                    .frame(width: 32, height: 32)
                    .background(selected ? Theme.blueFill : Theme.blueSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: s.displayName).font(.app(size: 15, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(2)
                    Text(verbatim: [String(format: L(o.walkMeasured ? "%lld min on foot" : "about %lld min on foot"), o.walkMinutes),
                                    s.priceText].joined(separator: " · "))
                        .font(.app(size: 13)).foregroundStyle(Theme.muted)
                    HStack(spacing: 6) {
                        if let open = o.open {
                            Label(L(open ? (now ? "Open now" : "Open when you arrive") : "Closed"), systemImage: Symbols.pick(open, "clock.fill", else: "clock"))
                                .foregroundStyle(open ? Theme.greenInk : Theme.red)
                        } else if let h = s.hours {
                            Label(h, systemImage: "clock").foregroundStyle(Theme.muted).lineLimit(1)
                        } else {
                            Label(L("Hours not listed"), systemImage: "clock").foregroundStyle(Theme.muted)
                        }
                        if let kind = s.kindText { Text(verbatim: "· " + kind).foregroundStyle(Theme.muted) }
                        if let c = s.capacity { Text(verbatim: "· " + String(format: L("%lld spaces"), c)).foregroundStyle(Theme.muted) }
                    }
                    .font(.app(size: 12, weight: .medium)).lineLimit(1).minimumScaleFactor(0.8)
                    switch o.routeClear {
                    case true?:
                        Label(L("Route there without active ZTL"), systemImage: "checkmark.shield.fill")
                            .font(.app(size: 12, weight: .semibold)).foregroundStyle(Theme.greenInk)
                    case false?:
                        EmptyView()
                    case nil:
                        Label(L("Route not checked: allow location access"), systemImage: "location.slash")
                            .font(.app(size: 12)).foregroundStyle(Theme.muted)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: Symbols.pick(selected, "checkmark.circle.fill", else: "circle"))
                    .font(.app(size: 18)).foregroundStyle(selected ? Theme.blue : Theme.line)
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// 1.19.5: le righe dei parcheggi mentre arrivano: tre righe grigie ferme (nessuna animazione, il giro delle foto
/// aspetta che l'app sia ferma), con la forma delle righe vere (simbolo, nome, minuti e prezzo, orari)
struct ParkingSkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { i in
                HStack(alignment: .top, spacing: 12) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.line.opacity(0.6)).frame(width: 32, height: 32)
                    VStack(alignment: .leading, spacing: 7) {
                        bar(width: [170, 140, 190][i], height: 13)
                        bar(width: [120, 150, 110][i], height: 10)
                        bar(width: [90, 80, 100][i], height: 10)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 10)
                if i < 2 { Divider().padding(.leading, 44) }
            }
        }
        .accessibilityHidden(true)
    }

    private func bar(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous).fill(Theme.line.opacity(0.6)).frame(width: width, height: height)
    }
}

extension PlaceCheck {
    /// Rosso o ambra: conviene lasciare l'auto fuori
    var suggestsParking: Bool { kind == .closed || kind == .conditional || kind == .pedestrian }
}
