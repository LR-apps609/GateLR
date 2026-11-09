import XCTest

/// 1.20.0 «Motore unico»: gli stessi casi di prova per iPhone, Android e sito (shared/engine-cases.json). Posto + ora +
/// veicolo → colore (rosso, giallo, verde, grigio, neutro), risposta come si mostra, zona che decide. Dati veri delle
/// città (Resources/Cities, anche quelle da fonti non ufficiali) e «oggi» fisso dal file, perché le schede non invecchino.
final class SharedEngineCasesTests: XCTestCase {
    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    private static let citiesDir = root.appendingPathComponent("Resources/Cities")

    /// Tutte le città del manifest, ufficiali e non
    private static let cities: [City] = {
        guard let data = try? Data(contentsOf: citiesDir.appendingPathComponent("manifest.json")),
              let man = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        let entries = (man["cities"] as? [[String: Any]] ?? []) + (man["unofficialCities"] as? [[String: Any]] ?? [])
        return entries.compactMap { e in
            guard let file = e["file"] as? String,
                  let d = try? Data(contentsOf: citiesDir.appendingPathComponent(file)) else { return nil }
            return try? CityLoader.decode(d)
        }
    }()

    private static func date(_ s: String) -> Date? {
        ISO8601DateFormatter().date(from: s)
    }

    private static func colour(_ a: Access?) -> String {
        switch a {
        case nil: "neutral"
        case .closed?: "red"
        case .conditional?, .check?: "yellow"
        case .open?: "green"
        case .off?: "green"          // 1.20.1: ZTL spenta = verde
        }
    }

    private static func trustName(_ t: DataTrust) -> String {
        switch t {
        case .verified: "verified"
        case .read: "read"
        case .unverified: "unverified"
        case .old: "old"
        case .pageChanged: "pageChanged"
        }
    }

    private static func name(_ v: Verdict) -> String {
        switch v {
        case .yes: "yes"
        case .no: "no"
        case .conditional: "conditional"
        case .unsure: "unsure"
        }
    }

    private static func vehicle(_ j: [String: Any]) -> Vehicle? {
        guard let fuel = (j["fuel"] as? String).flatMap(Fuel.init(rawValue:)), let euro = j["euro"] as? Int else { return nil }
        return Vehicle(name: j["name"] as? String ?? "", fuel: fuel, euro: euro,
                       type: (j["type"] as? String).flatMap(VehicleType.init(rawValue:)),
                       motoClass: (j["motoClass"] as? String).flatMap(MotoClass.init(rawValue:)),
                       stroke: j["stroke"] as? Int)
    }

    func testSharedEngineCases() throws {
        let data = try Data(contentsOf: Self.root.appendingPathComponent("shared/engine-cases.json"))
        let file = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let cases = try XCTUnwrap(file["cases"] as? [[String: Any]])
        let vehicles = try XCTUnwrap(file["vehicles"] as? [String: [String: Any]])
        let defaultNow = try XCTUnwrap(Self.date(file["now"] as? String ?? ""))
        let cities = Self.cities
        XCTAssertGreaterThan(cities.count, 40, "le città di Resources/Cities")
        XCTAssertTrue(cities.contains { $0.id == "salerno" } && cities.contains { $0.id == "cagliari" }, "anche le città da fonti non ufficiali")
        XCTAssertGreaterThanOrEqual(cases.count, 30)
        // 2.1: gli stessi stati, motivi e colori semantici del file su iPhone, Android e sito
        XCTAssertEqual(file["stati"] as? [String], Stato.allCases.map(\.rawValue))
        XCTAssertEqual(file["motivi"] as? [String], Motivo.allCases.map(\.rawValue))
        let toni = try XCTUnwrap(file["toni"] as? [String: String])
        for s in Stato.allCases { XCTAssertEqual(toni[s.rawValue], s.tono.rawValue, "tono di \(s)") }
        XCTAssertEqual(file["statoSpento"] as? String, RispostaFinale.stateOff.rawValue, "ZTL non attiva: un solo token")

        for c in cases {
            let id = c["id"] as? String ?? "?"
            guard let place = c["place"] as? [String: Any], let lat = place["lat"] as? Double, let lon = place["lon"] as? Double,
                  let at = Self.date(c["at"] as? String ?? ""), let v = (c["vehicle"] as? String).flatMap({ vehicles[$0] }).flatMap(Self.vehicle),
                  let expect = c["expect"] as? [String: Any] else { XCTFail("\(id): caso scritto male"); continue }
            let now = (c["now"] as? String).flatMap(Self.date) ?? defaultNow
            var engine = RuleEngine()
            engine.now = { now }
            // 1.20.1: «pageChanged» dei file cambia ogni mattina: i casi lo ignorano (false) salvo «source»; «source» può
            // anche dare «verifiedOn» e «checkedOn» a tutte le zone. Solo nel test, i file non cambiano
            let src = c["source"] as? [String: Any] ?? [:]
            let pageChanged = src["pageChanged"] as? Bool ?? false
            let caseCities = cities.map { city -> City in
                var copy = city
                for i in copy.zones.indices {
                    copy.zones[i].source.pageChanged = pageChanged
                    if src.keys.contains("verifiedOn") { copy.zones[i].source.verifiedOn = (src["verifiedOn"] as? String).flatMap(Self.date) }
                    if let read = (src["checkedOn"] as? String).flatMap(Self.date) { copy.zones[i].source.checkedOn = read }
                }
                return copy
            }
            let p = Coordinate(lat: lat, lon: lon)
            let hits = Store.zones(at: p, in: caseCities)
            let area = caseCities.lazy.compactMap { $0.pedestrian?.first(where: { $0.contains(lat: lat, lon: lon) }) }.first
            let hotel = c["hotel"] as? Bool ?? false
            let check = PlaceCheck(place: Place(name: place["name"] as? String ?? id, address: "", location: p), hits: hits, pedestrian: area,
                                   answers: hits.map { engine.trustedAnswer(zone: $0.zone, vehicle: v, permits: [], hotelInside: hotel, at: at) },
                                   covered: Store.covers(p, in: caseCities),
                                   coverUnofficial: hits.isEmpty && Store.coverUnofficial(p, in: caseCities))

            XCTAssertEqual(check.colourName, expect["colour"] as? String, "\(id): colore")
            // Lo stesso nome del colore della mappa quando decide una zona (1.20.4: fuori dalla ZTL «grey», senza zona)
            if check.access != nil { XCTAssertEqual(check.colourName, Self.colour(check.access), "\(id): colore della mappa") }
            if check.showsOutside && !check.unofficial { XCTAssertEqual(check.colourName, "grey", "\(id): fuori dalla ZTL è grigio") }
            if let want = expect["verdict"] as? String {
                XCTAssertEqual(Self.name(check.verdict.shown(unofficial: check.unofficial)), want, "\(id): risposta")
            }
            if expect.keys.contains("zone") {
                XCTAssertEqual(check.zone?.id, expect["zone"] as? String, "\(id): zona che decide")
            }
            if let want = expect["gatesOn"] as? Bool {
                XCTAssertEqual(check.shownAnswer?.gatesOn, want, "\(id): varchi")
            }
            if let want = expect["unofficial"] as? Bool {
                XCTAssertEqual(check.unofficial, want, "\(id): fonte non ufficiale")
            }
            if let want = expect["pedestrian"] as? Bool {
                XCTAssertEqual(check.pedestrian != nil, want, "\(id): area pedonale")
            }
            // 2.1 (B09): la distanza dal lato della zona più vicina (5 m di tolleranza)
            if let want = expect["nearestMeters"] as? Double {
                let m = caseCities.flatMap(\.zones).map { $0.distance(lat: lat, lon: lon) }.min() ?? .infinity
                XCTAssertEqual(m, want, accuracy: 5, "\(id): distanza dal lato")
            }
            // 2.1 «Una risposta, sette stati»: la RispostaFinale del posto (shared/risposta-finale.md)
            let f = check.finale
            XCTAssertEqual(f.stato.rawValue, expect["stato"] as? String, "\(id): stato")
            XCTAssertEqual(f.motivo?.rawValue, expect["motivo"] as? String, "\(id): motivo")
            XCTAssertEqual(f.motivo != nil, f.stato == .controllaCartello, "\(id): il motivo solo con «Controlla il cartello»")
            XCTAssertEqual(check.word, f.word, "\(id): il titolo è la parola dello stato")
            if f.color == .verde { XCTAssertTrue(check.covered && !check.unofficial, "\(id): \(f.stato) verde dove non sappiamo") }
            // Le regole fisse, qualunque cosa dica il file: mai verde fuori copertura o da fonte non ufficiale
            if !check.covered { XCTAssertNil(check.access, "\(id): fuori copertura è neutro") }
            if check.unofficial { XCTAssertNotEqual(check.access, .open, "\(id): fonte non ufficiale mai verde") }
            let trust = check.zone.map { engine.trust($0) }
            if let want = expect["trust"] as? String {
                XCTAssertEqual(trust.map(Self.trustName), want, "\(id): verifica")
            }
            // 1.20.1 (regola A): mai verde da una zona senza verifica né lettura recente o con la pagina del Comune cambiata
            if check.pedestrian == nil, let trust, trust != .verified, trust != .read {
                XCTAssertNotEqual(check.access, .open, "\(id): zona non sicura verde")
                XCTAssertNotEqual(check.access, .off, "\(id): zona non sicura verde (spenta)")
            }
        }
    }
}
