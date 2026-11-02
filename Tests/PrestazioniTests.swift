import XCTest

/// 1.19.5 «Più veloce»: le parti pure delle ottimizzazioni. Le città lette su più core danno le stesse città nello stesso
/// ordine; Overpass: la prima risposta buona, i server di riserva solo se servono; impronte e chiavi della ricerca.
final class PrestazioniTests: XCTestCase {
    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    private var citiesDir: URL { Self.root.appendingPathComponent("Resources/Cities") }

    private func cityFiles() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: citiesDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" && $0.lastPathComponent != "manifest.json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    // MARK: Lettura delle città

    func testParallelDecodeGivesTheSameCities() throws {
        let files = try cityFiles()
        let sequential = files.compactMap { try? CityLoader.decode(Data(contentsOf: $0)) }
        let parallel = CityLoader.decodeAll(files)
        XCTAssertEqual(parallel.count, files.count)
        XCTAssertEqual(parallel.map(\.id), sequential.map(\.id))
        XCTAssertEqual(parallel, sequential, "le città lette insieme devono essere identiche a quelle lette una alla volta")
    }

    func testParallelDecodeSkipsBrokenFilesLikeBefore() throws {
        let broken = FileManager.default.temporaryDirectory.appendingPathComponent("rotta-\(UUID().uuidString).json")
        try Data("{".utf8).write(to: broken)
        defer { try? FileManager.default.removeItem(at: broken) }
        let files = try Array(cityFiles().prefix(3)) + [broken]
        XCTAssertEqual(CityLoader.decodeAll(files).count, 3)
    }

    // MARK: Aggiornamento delle città

    func testSha256MatchesTheManifest() throws {
        let manifest = try JSONDecoder().decode(CityLoader.Manifest.self, from: Data(contentsOf: citiesDir.appendingPathComponent("manifest.json")))
        for entry in manifest.allCities.prefix(5) {
            let d = try Data(contentsOf: citiesDir.appendingPathComponent(entry.file))
            XCTAssertEqual(CityUpdater.sha256(d), entry.sha256, entry.file)
        }
    }

    func testCityRequestsHaveATimeoutAndSkipTheLocalCache() {
        let r = CityUpdater.request(CityUpdater.base.appendingPathComponent("manifest.json"))
        XCTAssertEqual(r.timeoutInterval, 20)
        XCTAssertEqual(r.cachePolicy, .reloadIgnoringLocalCacheData)
    }

    // MARK: Overpass: la prima risposta buona

    private actor Calls {
        var started: [String] = []
        func add(_ s: String) { started.append(s) }
    }

    private func requests(_ n: Int) -> [URLRequest] {
        (0..<n).map { URLRequest(url: URL(string: "https://example.org/\($0)")!) }
    }

    private func spot(_ id: String) -> ParkingSpot { ParkingSpot(id: id, lat: 43.77, lon: 11.25) }

    func testFirstServerAnsweringWinsAndTheOthersNeverStart() async {
        let calls = Calls()
        let result = await ParkingData.firstGood(requests(3), hedge: 0.5) { req in
            await calls.add(req.url!.lastPathComponent)
            return [ParkingSpot(id: "n" + req.url!.lastPathComponent, lat: 43.77, lon: 11.25)]
        }
        XCTAssertEqual(result?.map(\.id), ["n0"])
        let started = await calls.started
        XCTAssertEqual(started, ["0"], "i server di riserva partono solo se il primo tarda")
    }

    func testFailedServerStartsTheNextAtOnce() async {
        let calls = Calls()
        let t0 = Date()
        let result = await ParkingData.firstGood(requests(3), hedge: 5) { req in
            await calls.add(req.url!.lastPathComponent)
            return req.url!.lastPathComponent == "0" ? nil : [ParkingSpot(id: "n" + req.url!.lastPathComponent, lat: 43.77, lon: 11.25)]
        }
        XCTAssertEqual(result?.map(\.id), ["n1"])
        XCTAssertLessThan(Date().timeIntervalSince(t0), 2, "dopo un errore il server seguente parte subito, senza aspettare")
    }

    func testSlowServerIsOvertakenByTheBackup() async {
        let result = await ParkingData.firstGood(requests(2), hedge: 0.2) { req in
            if req.url!.lastPathComponent == "0" { try? await Task.sleep(for: .seconds(3)); return [ParkingSpot(id: "lento", lat: 0, lon: 0)] }
            return [ParkingSpot(id: "riserva", lat: 0, lon: 0)]
        }
        XCTAssertEqual(result?.map(\.id), ["riserva"])
    }

    func testAllServersFailingGivesNil() async {
        let calls = Calls()
        let result = await ParkingData.firstGood(requests(3), hedge: 0.1) { req in
            await calls.add(req.url!.lastPathComponent)
            return nil
        }
        XCTAssertNil(result)
        let started = await calls.started
        XCTAssertEqual(Set(started), ["0", "1", "2"])
    }

    func testOverpassTimeoutsAreShort() {
        XCTAssertLessThanOrEqual(ParkingData.hostTimeout, 20)
        XCTAssertLessThan(ParkingData.hedgeDelay, ParkingData.hostTimeout)
    }

    // MARK: Ricerca

    func testSearchCacheKeyIgnoresCase() {
        XCTAssertEqual(AddressSearch.key(region: "firenze", query: "Palazzo Vecchio"), AddressSearch.key(region: "firenze", query: "palazzo vecchio"))
        XCTAssertNotEqual(AddressSearch.key(region: "firenze", query: "duomo"), AddressSearch.key(region: "milano", query: "duomo"))
    }
}
