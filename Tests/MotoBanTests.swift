import XCTest

/// 1.17.2: i limiti delle moto dove le fonti ufficiali li scrivono («motoBans»: Scudo Verde di Firenze, antismog di
/// Padova), le app vecchie che non li vedono, e la mappa che colora ogni zona con la SUA risposta. Gli stessi casi di
/// android/core/.../SeasonAndVehicleTest.kt (motorbikeBansFromOfficialSources).
final class MotoBanTests: XCTestCase {
    private let engine: RuleEngine = {
        var e = RuleEngine()
        let today = RuleEngine.rome.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 12))!
        e.now = { today }
        return e
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        RuleEngine.rome.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    private func fileData(_ id: String) throws -> Data {
        try Data(contentsOf: Self.root.appendingPathComponent("Resources/Cities/\(id).json"))
    }
    private func city(_ id: String) throws -> City { try CityLoader.decode(fileData(id)) }
    private func zone(_ c: String, _ id: String) throws -> Zone {
        try XCTUnwrap(city(c).zones.first { $0.id == id }, id)
    }
    private func verdict(_ z: Zone, _ v: Vehicle, _ at: Date) -> Verdict {
        engine.answer(zone: z, vehicle: v, permits: [], hotelInside: false, at: at).verdict
    }
    private func isYes(_ v: Verdict) -> Bool { if case .yes = v { return true }; return false }
    private func isNo(_ v: Verdict) -> Bool { if case .no = v { return true }; return false }
    private func isConditional(_ v: Verdict) -> Bool { if case .conditional = v { return true }; return false }

    private func moto(_ euro: Int, _ cls: MotoClass? = nil, stroke: Int? = nil, fuel: Fuel = .petrol) -> Vehicle {
        var v = Vehicle(name: "Scooter", fuel: fuel, euro: euro)
        v.type = .motorcycle
        v.motoClass = cls
        v.stroke = stroke
        return v
    }

    // MARK: Moto

    /// Comunicato del 31/03/2025: ciclomotori 2 tempi Euro 0–1 e 4 tempi Euro 0, motocicli 2 tempi Euro 0;
    /// dal 1/12/2026 (comunicato del 21/08/2026) tutte le due ruote Euro 0–1
    func testFlorenceScudoVerdeMotorbikes() throws {
        let sv = try zone("firenze", "firenze-scudo-verde")
        let oct = date(2026, 10, 29, 12), dec = date(2026, 12, 2, 12)
        XCTAssertTrue(isNo(verdict(sv, moto(1, .moped, stroke: 2), oct)))
        XCTAssertTrue(isYes(verdict(sv, moto(1, .moped, stroke: 4), oct)))
        XCTAssertTrue(isNo(verdict(sv, moto(0, .moped, stroke: 4), oct)))
        XCTAssertTrue(isNo(verdict(sv, moto(0, .motorcycle, stroke: 2), oct)))
        XCTAssertTrue(isYes(verdict(sv, moto(0, .motorcycle, stroke: 4), oct)))
        XCTAssertTrue(isNo(verdict(sv, moto(1, .motorcycle, stroke: 4), dec)))
        XCTAssertTrue(isYes(verdict(sv, moto(2, .moped, stroke: 2), dec)))
        // Di serie (campi assenti): motociclo 4 tempi
        XCTAssertTrue(isYes(verdict(sv, moto(0), oct)))
        XCTAssertTrue(isNo(verdict(sv, moto(0), dec)))
        // Elettrica: mai vietata
        XCTAssertTrue(isYes(verdict(sv, moto(0, .moped, stroke: 2, fuel: .electric), dec)))
        // «Fino al …» quando arriva la fase 2
        if case .yes(let reason) = verdict(sv, moto(1), oct) {
            XCTAssertTrue(reason.contains("Euro 1"), reason)
        } else { XCTFail("moto Euro 1 a ottobre: sì") }
    }

    func testCarsAreUnchanged() throws {
        let sv = try zone("firenze", "firenze-scudo-verde")
        let oct = date(2026, 10, 29, 12)
        XCTAssertTrue(isNo(verdict(sv, Vehicle(name: "d1", fuel: .diesel, euro: 1), oct)))
        XCTAssertTrue(isYes(verdict(sv, Vehicle(name: "d5", fuel: .diesel, euro: 5), oct)))
        XCTAssertTrue(isNo(verdict(sv, Vehicle(name: "p0", fuel: .petrol, euro: 0), oct)))
        XCTAssertNil(sv.motoBan(for: Vehicle(name: "p0", fuel: .petrol, euro: 0), at: date(2026, 12, 2, 12)))
    }

    /// Ordinanza 46/2026, livello verde, lettera d): ciclomotori e motoveicoli Euro 0
    func testPaduaSmogLimits() throws {
        let pd = try zone("padova", "padova-antismog")
        let monday = date(2026, 11, 2, 10)
        XCTAssertTrue(isNo(verdict(pd, moto(0), monday)))
        XCTAssertTrue(isYes(verdict(pd, moto(1, .moped, stroke: 2), monday)))
    }

    /// Senza limiti delle moto nei dati: «a una condizione», con la condizione scritta
    func testOtherZonesKeepTheCondition() throws {
        let b = try zone("milano", "milano-b")
        let v = verdict(b, moto(5), date(2026, 10, 26, 12))
        XCTAssertTrue(isConditional(v))
        if case .conditional(_, let condition) = v {
            XCTAssertEqual(condition, L("Motorbikes have their own Euro limits here. Check yours on the city's page."))
        }
    }

    /// Le app fino alla 1.17.1 leggono «bans» come divieti delle auto: lì non c'è mai un divieto delle moto
    /// (ognuno ha «fuel»), e «motoBans» è una chiave che non conoscono e ignorano
    func testOldAppsNeverSeeMotorbikeBansAsCarBans() throws {
        struct OldBan: Decodable { var fuel: String; var maxEuro: Int; var since: String }
        struct OldZone: Decodable { var id: String; var bans: [OldBan]? }
        struct OldCity: Decodable { var zones: [OldZone] }
        let dir = Self.root.appendingPathComponent("Resources/Cities")
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" && $0.lastPathComponent != "manifest.json" }
        XCTAssertGreaterThan(files.count, 30)
        for f in files {
            // Ogni divieto in «bans» ha «fuel»: una voce senza farebbe fallire la lettura nelle app vecchie
            XCTAssertNoThrow(try JSONDecoder().decode(OldCity.self, from: Data(contentsOf: f)), f.lastPathComponent)
            let raw = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: f)) as? [String: Any])
            for z in raw["zones"] as? [[String: Any]] ?? [] {
                for b in z["bans"] as? [[String: Any]] ?? [] {
                    XCTAssertNil(b["category"], "\(f.lastPathComponent): un divieto delle moto dentro «bans»")
                    XCTAssertNil(b["stroke"], "\(f.lastPathComponent): un divieto delle moto dentro «bans»")
                }
            }
        }
        let fi = try JSONDecoder().decode(OldCity.self, from: fileData("firenze"))
        XCTAssertEqual(fi.zones.first { $0.id == "firenze-scudo-verde" }?.bans?.count, 4)
        // Le città con i limiti delle moto: solo dove una fonte ufficiale li scrive
        let all = try files.map { try CityLoader.decode(Data(contentsOf: $0)) }
        let withMoto = Set(all.flatMap { c in c.zones.filter { $0.motoBans != nil }.map(\.id) })
        XCTAssertEqual(withMoto, ["firenze-scudo-verde", "padova-antismog"])
        // Un veicolo salvato prima della 1.17.2: motociclo 4 tempi
        let saved = try JSONDecoder().decode(Vehicle.self, from: Data(#"{"id":"6F9619FF-8B86-D011-B42D-00CF4FC964FF","name":"x","model":"","fuel":"petrol","euro":3,"plate":"","isRental":false,"type":"motorcycle"}"#.utf8))
        XCTAssertEqual(saved.motoCategory, .motorcycle)
        XCTAssertEqual(saved.strokes, 4)
    }

    // MARK: I colori della mappa

    /// Hotel Helvetia & Bristol (via dei Pescioni 2), diesel Euro 5, giovedì 29/10/2026 alle 13:25: il Settore A è
    /// rosso, lo Scudo Verde che lo contiene resta verde (prima la mappa li colorava tutti e due di rosso)
    func testEachZoneKeepsItsOwnColour() throws {
        let fi = try city("firenze")
        let hotel = Coordinate(lat: 43.77176, lon: 11.25128)
        let car = Vehicle(name: "Personal Car", fuel: .diesel, euro: 5)
        let at = date(2026, 10, 29, 13, 25)
        let hits = fi.zones.filter { $0.contains(lat: hotel.lat, lon: hotel.lon) }
        XCTAssertEqual(Set(hits.map(\.id)), ["firenze-a", "firenze-scudo-verde"])
        func access(_ id: String) -> Access {
            let z = fi.zones.first { $0.id == id }!
            return Access(engine.answer(zone: z, vehicle: car, permits: [], hotelInside: false, at: at).verdict)
        }
        XCTAssertEqual(access("firenze-a"), .closed)
        XCTAssertEqual(access("firenze-scudo-verde"), .open)
        // Accese tutte e due (contengono il posto), ognuna con il suo colore (1.18.0: i colori di MapTheme)
        XCTAssertEqual(MapTheme.tone(access("firenze-a")).lineLight, MapTheme.red.lineLight)
        XCTAssertEqual(MapTheme.tone(access("firenze-scudo-verde")).lineLight, MapTheme.green.lineLight)
        XCTAssertNotEqual(MapTheme.tone(.open).lineLight, MapTheme.tone(.closed).lineLight)
    }
}
