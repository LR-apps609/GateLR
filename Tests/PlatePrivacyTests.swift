import XCTest

/// 1.19.4 «Privacy onesta»: la targa non esce mai dall'app (condivisioni, copie, bozza del ricorso, widget e App Group,
/// Siri, Live Activity, notifiche, segnalazioni). Unica eccezione voluta: il messaggio per l'hotel.
/// E la telemetria di Mapbox spenta di serie.
final class PlatePrivacyTests: XCTestCase {
    private let plate = "GX482KM"

    func testScrubMasksPlateWrittenAnyWay() {
        for text in ["GX482KM", "gx482km", "GX 482 KM", "GX-482-KM", "Auto GX482KM, Firenze"] {
            XCTAssertFalse(PlatePrivacy.scrub(text, plates: [plate]).uppercased().contains("482"), text)
            XCTAssertTrue(PlatePrivacy.leaks(text, plates: [plate]), text)
        }
        XCTAssertEqual(PlatePrivacy.scrub("Targa GX 482-KM ok", plates: [plate]), "Targa ••• ok")
        // Una targa straniera del Garage, anche con spazi diversi
        XCTAssertEqual(PlatePrivacy.scrub("Auto M AB 1234", plates: ["M-AB1234"]), "Auto •••")
        // Le targhe italiane anche senza saperle
        XCTAssertEqual(PlatePrivacy.scrub("veicolo AB123CD."), "veicolo •••.")
        // Il resto non si tocca: vie, numeri, date, numeri dei verbali, zone
        for text in ["Via Cavour 12, Firenze", "2026/F/0123456", "12/03/2026 21:32", "Settore A · Non entrare", "Euro 6", "A1 GX4"] {
            XCTAssertEqual(PlatePrivacy.scrub(text, plates: [plate]), text)
        }
        // Una targa troppo corta non diventa una caccia a ogni lettera
        XCTAssertEqual(PlatePrivacy.scrub("Settore B", plates: ["B"]), "Settore B")
    }

    func testVehicleNameNeverCarriesThePlate() {
        var v = Vehicle(name: "Panda GX482KM", fuel: .petrol, euro: 6, plate: plate)
        XCTAssertEqual(PlatePrivacy.displayName(v), "Panda")
        v.name = "GX482KM"
        v.make = "Fiat"; v.model = "Panda"
        XCTAssertEqual(PlatePrivacy.displayName(v), "Fiat Panda")
        v.make = nil; v.model = ""
        XCTAssertEqual(PlatePrivacy.displayName(v), L("your vehicle"))
        let shared = PlatePrivacy.withoutPlate(Vehicle(name: "Mia (GX482KM)", fuel: .diesel, euro: 5, plate: plate))
        XCTAssertEqual(shared.plate, "")
        XCTAssertEqual(shared.name, "Mia")
        XCTAssertEqual(shared.fuel, .diesel)
        XCTAssertEqual(shared.euro, 5)
    }

    /// Il diario dei passaggi condiviso: quando, zona, varco, cosa, risposta. Mai la targa (prima in fondo a ogni riga)
    @MainActor
    func testDriveLogShareTextHasNoPlate() {
        let log = [
            LogEntry(date: Date(), kind: .entered, zoneId: "firenze-a", zoneName: "Settore A", gateName: "Via Cavour",
                     verdict: "Non entrare", plate: plate),
            LogEntry(date: Date(), kind: .nearGate, zoneId: "firenze-b", zoneName: "Settore B", gateName: nil,
                     verdict: "Non entrare", plate: "AB-123-CD"),
        ]
        let text = DriveLogView.shareText(log, plates: [plate])
        XCTAssertFalse(text.contains("GX482KM"))
        XCTAssertFalse(text.contains("AB-123-CD"))
        XCTAssertFalse(text.contains("•••"), "la targa si omette, non si copre: \(text)")
        XCTAssertTrue(text.contains("Settore A · Via Cavour"))
        XCTAssertTrue(text.contains(L("Drove into the zone")))
        XCTAssertEqual(text.components(separatedBy: "\n").count, 2)
    }

    /// Il widget (si vede a telefono bloccato) e il garage nell'App Group: senza targa
    func testWidgetNeverShowsThePlate() {
        let zone = SampleData.florence.zones[0]
        let car = Vehicle(name: "GX482KM", model: "Panda", fuel: .petrol, euro: 6, plate: plate)
        let w = WidgetAnswer.make(zone: zone, cityId: SampleData.florence.id, garage: SharedData.Garage(vehicle: car, permits: [], zoneId: zone.id),
                                  at: Date())
        XCTAssertEqual(w.vehicleName, "Panda")
        let stored = SharedData.Garage(vehicle: PlatePrivacy.withoutPlate(car), permits: [], zoneId: zone.id)
        let json = String(data: try! JSONEncoder().encode(stored), encoding: .utf8)!
        XCTAssertFalse(json.contains("GX482KM"))
        XCTAssertEqual(stored.vehicle.id, car.id, "i permessi del veicolo valgono ancora nel widget")
    }

    /// Dynamic Island e schermata di blocco
    func testLiveActivityStateHasNoPlate() {
        let s = DriveAttributes.ContentState(symbol: "car", distance: "300 m", instruction: "Verso GX482KM",
                                             warning: "Settore A tra 300 m: GX 482 KM", eta: nil, level: "stop", zone: "GX482KM")
            .withoutPlates([plate])
        for text in [s.distance, s.instruction, s.warning ?? "", s.zone ?? ""] { XCTAssertFalse(text.contains("482"), text) }
        XCTAssertEqual(s.symbol, "car")
        XCTAssertEqual(s.level, "stop")
    }

    /// Siri: la risposta non dice la targa del Garage
    @MainActor
    func testSiriAnswersHaveNoPlate() {
        let store = Store()
        store.cities = [SampleData.florence]
        let car = Vehicle(name: "GX482KM", fuel: .petrol, euro: 6, plate: plate)
        store.vehicles = [car]
        store.activeVehicleId = car.id
        let city = SampleData.florence
        let zone = city.zones[0]
        let inside = zone.perimeter.first ?? city.center
        for text in [NearbyZTLIntent.answer(at: inside, store: store),
                     NearbyZTLIntent.answer(at: city.center, store: store),
                     DriveIntoIntent.answer(city: city, zone: zone, at: nil, store: store)] {
            XCTAssertFalse(text.contains("GX482KM"), text)
            XCTAssertFalse(text.isEmpty)
        }
    }

    /// La segnalazione di un errore: il veicolo senza targa anche se è scritta nel nome
    func testReportVehicleLineWithPlateInName() {
        let v = Vehicle(name: "GX482KM", fuel: .petrol, euro: 6, plate: plate)
        XCTAssertFalse(ZoneReport.vehicleLine(v).contains("GX482KM"))
        XCTAssertTrue(ZoneReport.vehicleLine(v).contains("Euro 6"))
    }

    /// La bozza del ricorso (si copia negli appunti): «[targa]» da completare, mai quella letta sul verbale
    func testAppealDraftHasNoPlate() {
        var n = FineReader.Notice()
        n.plate = plate
        n.place = "Via Cavour (veicolo GX482KM)"
        let draft = FineCheck.appealDraft(n, city: "Firenze", zone: nil, status: nil, source: nil)
        XCTAssertFalse(draft.contains("GX482KM"))
        XCTAssertTrue(draft.contains("veicolo targato [targa]"))
    }

    /// Mapbox: telemetria spenta al primo avvio, poi decide chi usa l'app (qui o dalla (i) della mappa)
    func testMapboxTelemetryOffByDefault() {
        let suite = "gatelr.tests.mapbox.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        defer { d.removePersistentDomain(forName: suite) }
        // Mapbox registra «acceso» di serie (EventsManager): la nostra scelta deve valere lo stesso
        d.register(defaults: [MapboxTelemetry.key: true])
        MapboxTelemetry.applyDefault(d)
        XCTAssertFalse(d.bool(forKey: MapboxTelemetry.key))
        XCTAssertFalse(MapboxTelemetry.isOn(d))
        // Chi la accende la ritrova accesa al prossimo avvio
        d.set(true, forKey: MapboxTelemetry.key)
        MapboxTelemetry.applyDefault(d)
        XCTAssertTrue(MapboxTelemetry.isOn(d))
    }
}
