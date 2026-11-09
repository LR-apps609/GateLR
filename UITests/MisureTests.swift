import XCTest
import CoreLocation

// 1.19.5: le misure delle prestazioni (workflow «misure.yml», rami prestazioni-* e a mano). Nel giro delle foto si saltano:
// partono solo con TEST_RUNNER_MISURE=1 (xcodebuild passa al test le variabili TEST_RUNNER_ senza il prefisso).
// Ogni misura scrive anche una riga «MISURA <nome> <valore>» (il workflow le mette nelle annotazioni) e XCTest le sue
// («measured [Clock Monotonic Time, s] …»). Sul simulatore di GitHub (Mac Intel, senza scheda grafica): valori relativi,
// da confrontare solo tra corse sullo stesso tipo di macchina.
final class MisureTests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = true
        guard ProcessInfo.processInfo.environment["MISURE"] != nil else {
            throw XCTSkip("Solo per le misure delle prestazioni (TEST_RUNNER_MISURE=1)")
        }
    }

    override func tearDown() {
        if app.state == .runningForeground || app.state == .runningBackground { app.terminate() }
        super.tearDown()
    }

    private func report(_ name: String, _ value: Double, unit: String = "s") {
        print(String(format: "MISURA %@ %.3f %@", name, value, unit))
    }

    private func reportSeries(_ name: String, _ values: [Double], unit: String = "s") {
        guard !values.isEmpty else { print("MISURA \(name) nessun-valore"); return }
        let sorted = values.sorted()
        let median = sorted[sorted.count / 2]
        let list = values.map { String(format: "%.2f", $0) }.joined(separator: ",")
        print(String(format: "MISURA %@ mediana=%.3f%@ primo=%.3f%@ min=%.3f max=%.3f n=%d valori=[%@]",
                     name, median, unit, values[0], unit, sorted[0], sorted[sorted.count - 1], values.count, list))
    }

    /// Uno qualsiasi degli identificatori, con una sola ricerca nell'albero di accessibilità
    private func waitAny(_ ids: [String], timeout: TimeInterval) -> XCUIElement? {
        let q = app.descendants(matching: .any).matching(NSPredicate(format: "identifier IN %@", ids)).firstMatch
        return q.waitForExistence(timeout: timeout) ? q : nil
    }

    private func options(_ n: Int, manualStart: Bool = false) -> XCTMeasureOptions {
        let o = XCTMeasureOptions()
        o.iterationCount = n
        o.invocationOptions = manualStart ? [.manuallyStart, .manuallyStop] : [.manuallyStop]
        return o
    }

    private var it: [String] { ["-uitest", "-AppleLanguages", "(en)", "-AppleLocale", "en_GB"] }

    // MARK: 1. Dall'avvio alla prima risposta

    /// Dall'avvio dell'app al titolo della risposta («varco.answer») per Palazzo Vecchio (città lette, posto scelto, risposta)
    func testM1LaunchToAnswer() {
        app.launchArguments = it + ["-uiPlace", "Palazzo Vecchio", "43.7693", "11.2556"]
        var times: [Double] = []
        measure(metrics: [XCTClockMetric()], options: options(5)) {
            let t0 = Date()
            app.launch()
            let ok = app.staticTexts["varco.answer"].firstMatch.waitForExistence(timeout: 60)
            stopMeasuring()
            if ok { times.append(Date().timeIntervalSince(t0)) } else { XCTFail("risposta non arrivata") }
            app.terminate()
        }
        reportSeries("avvio-risposta", times)
    }

    // MARK: 2. Ricerca di un indirizzo

    private func searchField() -> XCUIElement {
        let field = app.textFields["varco.search"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 20))
        return field
    }

    private func focus(_ field: XCUIElement) {
        field.tap()
        if !app.keyboards.firstMatch.waitForExistence(timeout: 3) { field.tap(); _ = app.keyboards.firstMatch.waitForExistence(timeout: 3) }
    }

    /// Dalla prima lettera al primo suggerimento («varco.result.0»): la stessa ricerca ripetuta (la prima è a freddo)
    func testM2aAddressSuggestions() {
        app.launchArguments = it
        app.launch()
        let field = searchField()
        sleep(3)
        var times: [Double] = []
        measure(metrics: [XCTClockMetric()], options: options(5, manualStart: true)) {
            focus(field)
            startMeasuring()
            let t0 = Date()
            field.typeText("Palazzo Vecchio")
            let ok = app.buttons["varco.result.0"].firstMatch.waitForExistence(timeout: 30)
            stopMeasuring()
            if ok { times.append(Date().timeIntervalSince(t0)) } else { XCTFail("nessun suggerimento") }
            let clear = app.buttons["Clear"].firstMatch
            if clear.waitForExistence(timeout: 3) { clear.tap() }
            sleep(1)
        }
        reportSeries("ricerca-suggerimenti", times)
    }

    /// Dal tocco sul suggerimento alla risposta per quel posto (MKLocalSearch, poi il motore)
    func testM2bAddressResolve() {
        app.launchArguments = it
        app.launch()
        let field = searchField()
        sleep(3)
        var times: [Double] = []
        measure(metrics: [XCTClockMetric()], options: options(5, manualStart: true)) {
            focus(field)
            field.typeText("Palazzo Vecchio")
            let first = app.buttons["varco.result.0"].firstMatch
            guard first.waitForExistence(timeout: 30) else { XCTFail("nessun suggerimento"); startMeasuring(); stopMeasuring(); return }
            sleep(2)
            startMeasuring()
            let t0 = Date()
            first.tap()
            let ok = app.staticTexts["varco.answer"].firstMatch.waitForExistence(timeout: 30)
            stopMeasuring()
            if ok { times.append(Date().timeIntervalSince(t0)) } else { XCTFail("risposta non arrivata") }
            let clear = app.buttons["varco.clear"].firstMatch
            if clear.waitForExistence(timeout: 3) { clear.tap() }
            sleep(1)
        }
        reportSeries("ricerca-risposta", times)
    }

    // MARK: 3. Parcheggi fuori

    /// Dal tocco su «Parcheggia fuori e cammina» al primo parcheggio (o a «nessun parcheggio»); l'app si riapre a ogni giro
    private func parking(_ name: String, args: [String], iterations: Int, timeout: TimeInterval) {
        app.launchArguments = args
        var times: [Double] = []
        var empty = 0
        measure(metrics: [XCTClockMetric()], options: options(iterations, manualStart: true)) {
            app.launch()
            let park = app.buttons["varco.park"].firstMatch
            guard park.waitForExistence(timeout: 30) else {
                XCTFail("manca «Parcheggia fuori»"); startMeasuring(); stopMeasuring(); app.terminate(); return
            }
            if !park.isHittable { app.swipeUp(); sleep(1) }
            sleep(2)
            startMeasuring()
            let t0 = Date()
            park.tap()
            let hit = waitAny(["park.option.0", "park.empty", "park.failed"], timeout: timeout)   // 1.20.2: anche «non risponde»
            stopMeasuring()
            if let hit {
                times.append(Date().timeIntervalSince(t0))
                if hit.identifier != "park.option.0" { empty += 1 }
            } else { XCTFail("nessun risultato dei parcheggi in \(Int(timeout)) s") }
            app.terminate()
        }
        reportSeries(name, times)
        report(name + "-vuoti", Double(empty), unit: "volte")
    }

    /// Dati dentro l'app (Firenze), senza rete: solo il lavoro dell'app (lettura, filtro, ordine, disegno)
    func testM3aParkingBundledOffline() {
        parking("parcheggi-offline", args: it + ["-uiAt", "10:00", "-uiPlace", "Palazzo Vecchio", "43.7693", "11.2556"],
                iterations: 5, timeout: 60)
    }

    /// Dal vivo: Treviso (nessun file dentro l'app, copia sul disco ignorata) con Overpass e i percorsi di Apple
    func testM3bParkingLive() {
        parking("parcheggi-live", args: it + ["-uiLive", "-uiNoParkingCache", "-uiAt", "10:00",
                                               "-uiPlace", "Piazza dei Signori", "45.6664", "12.2430",
                                               "-uiOrigin", "45.6500", "12.2200"],
                iterations: 3, timeout: 200)
    }

    // MARK: 4. Mappa con tanti varchi (Milano Area B)

    private func meter() -> (frames: Double, hitches: Double, missed: Double, seconds: Double)? {
        let e = app.descendants(matching: .any)["misure.fps"].firstMatch
        guard e.waitForExistence(timeout: 5) else { return nil }
        var v: [String: Double] = [:]
        for part in e.label.split(separator: " ") {
            let kv = part.split(separator: "=")
            if kv.count == 2, let d = Double(kv[1]) { v[String(kv[0])] = d }
        }
        guard let f = v["frames"], let h = v["hitches"], let m = v["missed"], let s = v["seconds"] else { return nil }
        return (f, h, m, s)
    }

    private func pans(_ n: Int) {
        let dirs: [(CGFloat, CGFloat)] = [(0.25, 0), (-0.25, 0), (0, 0.18), (0, -0.18)]
        for i in 0..<n {
            let d = dirs[i % dirs.count]
            let a = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let b = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5 + d.0, dy: 0.5 + d.1))
            a.press(forDuration: 0.05, thenDragTo: b, withVelocity: .default, thenHoldForDuration: 0)
        }
    }

    private func fpsWindow(_ name: String, _ action: () -> Void) {
        guard let a = meter() else { print("MISURA \(name) contatore-assente"); return }
        action()
        guard let b = meter() else { print("MISURA \(name) contatore-assente"); return }
        let frames = b.frames - a.frames, secs = max(0.001, b.seconds - a.seconds)
        report(name + "-fps", frames / secs, unit: "fps")
        report(name + "-scatti", b.hitches - a.hitches, unit: "scatti")
        report(name + "-fotogrammi-persi-pct", 100 * (b.missed - a.missed) / max(1, frames + b.missed - a.missed), unit: "%")
    }

    /// La scheda Mappa su via degli Abeti (il gruppo di varchi dell'Area B più fitto): spostamenti, poi da vicino (varchi)
    func testM4MapMilanoAreaB() {
        app.launchArguments = it + ["-uiFps", "-uiPlace", "Via degli Abeti", "45.4524", "9.0849"]
        app.launch()
        let mapTab = app.tabBars.buttons.element(boundBy: 1)
        XCTAssertTrue(mapTab.waitForExistence(timeout: 30))
        mapTab.tap()
        sleep(8)
        fpsWindow("mappa-ferma") { sleep(5) }
        measure(metrics: [XCTClockMetric()], options: options(3)) {
            fpsWindow("mappa-spostamenti") { pans(8) }
            stopMeasuring()
        }
        // Da vicino: i varchi compaiono da z16
        let c = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        for _ in 0..<2 { c.doubleTap(); sleep(2) }
        sleep(4)
        fpsWindow("mappa-varchi-spostamenti") { pans(8) }
    }

    // MARK: 5. Guardiano: processore in un giro simulato (stima della batteria)

    /// Il guardiano acceso a Milano verso est (Area B, poi Area C), una posizione al secondo a 12 m/s per 90 secondi;
    /// si misurano 60 secondi di processore dell'app con la pagina Varco davanti (la stima per 30 minuti: × 30)
    func testM5GuardianDriveCPU() {
        app.launchArguments = it + ["-uiGuardian", "45.4642", "9.1600", "90", "-uiGuardianDrive", "90", "12"]
        measure(metrics: [XCTCPUMetric(application: app), XCTMemoryMetric(application: app), XCTClockMetric()],
                options: options(3, manualStart: true)) {
            app.launch()
            XCTAssertTrue(app.descendants(matching: .any)["guardian.banner"].firstMatch.waitForExistence(timeout: 40))
            sleep(5)
            startMeasuring()
            sleep(60)
            stopMeasuring()
            app.terminate()
        }
    }

    // MARK: 7. Memoria durante una guida simulata (1.20.4)

    /// La memoria dell'app (MB, phys_footprint) letta dal contatore «misure.memory» ogni 10 secondi per «seconds»
    /// secondi. Ritorna la serie (il primo valore dopo 15 secondi dall'avvio)
    private func memorySeries(_ name: String, args: [String], seconds: Int, setup: () -> Void = {}) -> [Double] {
        app.launchArguments = it + ["-uiMemory"] + args
        app.launch()
        let meter = app.descendants(matching: .any)["misure.memory"].firstMatch
        guard meter.waitForExistence(timeout: 40) else { print("MISURA memoria-\(name) manca-contatore"); return [] }
        setup()
        sleep(15)
        func read() -> Double? {
            let label = meter.label
            guard let r = label.range(of: #"mb=([0-9.]+)"#, options: .regularExpression) else { return nil }
            return Double(label[r].dropFirst(3))
        }
        var values: [Double] = []
        for _ in 0...(seconds / 10) {
            if let v = read() { values.append(v) }
            sleep(10)
        }
        reportSeries("memoria-\(name)", values, unit: "MB")
        // La crescita dopo l'avvio (dai 35 secondi): il massimo meno il minimo. La memoria che sale e scende a ondate
        // (1.19.5–1.20.3: da 100 a 250 MB e ritorno) conta anche se l'ultimo valore è basso
        let settled = Array(values.dropFirst(2))
        if let lo = settled.min(), let hi = settled.max() {
            report("memoria-\(name)-crescita", hi - lo, unit: "MB")
        }
        app.terminate()
        return settled
    }

    private func assertSteady(_ v: [Double], _ what: String) {
        guard let lo = v.min(), let hi = v.max() else { return XCTFail("nessuna misura della memoria") }
        XCTAssertLessThan(hi - lo, 40, "\(what): \(v)")
    }

    /// Il guardiano a Milano con una posizione al secondo per 150 secondi, la pagina Varco davanti: la memoria non deve
    /// crescere (1.19.5: da 115 a 243 MB). Fallisce se tra 35 e 135 secondi varia di più di 40 MB
    func testM7aGuardianDriveMemory() {
        let v = memorySeries("guardiano-guida", args: ["-uiGuardian", "45.4642", "9.1600", "90", "-uiGuardianDrive", "150", "12"], seconds: 120)
        assertSteady(v, "la memoria cresce durante la guida del guardiano")
    }

    /// Lo stesso senza la striscia di mappa in Varco: quanto pesa la mappa e quanto il guardiano
    func testM7bGuardianDriveMemoryNoStrip() {
        _ = memorySeries("guardiano-senza-striscia", args: ["-uiGuardian", "45.4642", "9.1600", "90", "-uiGuardianDrive", "150", "12", "-uiNoStrip"], seconds: 120)
    }

    /// 1.20.4: Varco senza un posto e senza guardiano (la striscia mostra tutta la zona scelta, vista dall'alto): la memoria
    /// della striscia di mappa da sola. Fallisce se cresce più di 40 MB
    func testM7eVarcoNoPlaceMemory() {
        let v = memorySeries("varco-senza-posto", args: [], seconds: 120)
        assertSteady(v, "la memoria della striscia di Varco cresce")
    }

    // MARK: 6. Guida di GateLR da fermo (la mappa della guida)

    /// La guida dentro l'app verso il Duomo, con l'auto ferma (posizione del simulatore fissa): 30 secondi di processore
    func testM6DriveStillCPU() {
        XCUIDevice.shared.location = XCUILocation(location: CLLocation(latitude: 45.4850, longitude: 9.2040))
        // 2.2: il navigatore interno è dietro il flag di sviluppo (AppConfig.internalNavigator)
        app.launchArguments = it + ["-uiPlace", "Duomo di Milano", "45.4641", "9.1919", "-uiOrigin", "45.4850", "9.2040",
                                    "-devInternalNavigator", "YES"]
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        measure(metrics: [XCTCPUMetric(application: app), XCTClockMetric()], options: options(2, manualStart: true)) {
            app.launch()
            // 2.2: Viaggio è la terza scheda
            let trip = app.tabBars.buttons.element(boundBy: 2)
            guard trip.waitForExistence(timeout: 30) else { print("MISURA guida-ferma manca-viaggio"); startMeasuring(); stopMeasuring(); return }
            trip.tap(); sleep(2)
            let route = app.buttons["trip.route"].firstMatch
            guard route.waitForExistence(timeout: 5) else { print("MISURA guida-ferma manca-percorso"); startMeasuring(); stopMeasuring(); return }
            route.tap(); sleep(10)
            app.swipeUp(); sleep(1)
            let start = app.buttons["route.start"].firstMatch
            guard start.waitForExistence(timeout: 10) else { print("MISURA guida-ferma manca-avvia"); startMeasuring(); stopMeasuring(); return }
            start.tap(); sleep(1)
            let own = app.buttons["GateLR navigation"].firstMatch
            if own.waitForExistence(timeout: 3) { own.tap() }
            for label in ["Allow While Using App", "Allow Once", "Allow"] {
                let b = springboard.buttons[label]
                if b.waitForExistence(timeout: 3) { b.tap(); break }
            }
            let end = app.buttons["drive.end"].firstMatch
            guard end.waitForExistence(timeout: 30) else { print("MISURA guida-ferma guida-non-partita"); startMeasuring(); stopMeasuring(); return }
            sleep(8)
            startMeasuring()
            sleep(30)
            stopMeasuring()
            print("MISURA guida-ferma ok")
            end.tap()
            app.terminate()
        }
    }
}
