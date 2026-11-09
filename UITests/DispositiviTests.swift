import XCTest

// Il controllo su più dispositivi (workflow «dispositivi.yml»): iPhone piccolo, medio, grande e iPad, ognuno normale,
// in tema scuro e con il testo più grande di Dynamic Type. Si aprono le schermate principali (Adesso, Mappa, Viaggio,
// Aiuto, presentazione), si fa una foto e si controlla che gli elementi importanti siano dentro la finestra e toccabili.
// Nel giro normale delle foto questi test si saltano: partono solo con TEST_RUNNER_DISPOSITIVI=1 (xcodebuild passa al
// test le variabili con il prefisso TEST_RUNNER_ senza il prefisso). La variante arriva da TEST_RUNNER_DISPOSITIVI_VARIANTE
// («normale», «scuro», «testo-grande»), la cartella delle foto da TEST_RUNNER_SCREENSHOT_DIR.
final class DispositiviTests: XCTestCase {
    private let app = XCUIApplication()
    private var variant = "normale"

    override func setUpWithError() throws {
        continueAfterFailure = true
        let env = ProcessInfo.processInfo.environment
        guard env["DISPOSITIVI"] != nil else {
            throw XCTSkip("Solo per il controllo su più dispositivi (TEST_RUNNER_DISPOSITIVI=1)")
        }
        variant = env["DISPOSITIVI_VARIANTE"] ?? "normale"
    }

    /// Come nel giro delle foto: l'app si chiude e basta, senza ricerche nell'albero di accessibilità
    override func tearDown() {
        if app.state != .notRunning { app.terminate() }
        super.tearDown()
    }

    // MARK: Avvio

    private var italian: [String] { ["-uitest", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"] }
    private var place: [String] { ["-uiPlace", "Palazzo Vecchio", "43.7696", "11.2558"] }

    /// Gli argomenti della variante: tema scuro o testo più grande di Dynamic Type
    private var variantArgs: [String] {
        switch variant {
        case "scuro": return ["-uiDark"]
        case "testo-grande": return ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        default: return []
        }
    }

    private func start(_ extra: [String]) {
        XCUIDevice.shared.appearance = variant == "scuro" ? .dark : .light
        app.launchArguments = italian + extra + variantArgs
        app.launch()
    }

    /// Le quattro schede: sulla barra in basso (iPhone) o, se non c'è (iPad con la barra in alto), per nome
    private func tab(_ index: Int, _ names: [String]) -> XCUIElement {
        let bar = app.tabBars.buttons.element(boundBy: index)
        if bar.exists { return bar }
        return app.buttons.matching(NSPredicate(format: "label IN %@", names)).firstMatch
    }
    private var nowTab: XCUIElement { tab(0, ["Adesso", "Now"]) }
    private var mapTab: XCUIElement { tab(1, ["Mappa", "Map"]) }
    private var tripTab: XCUIElement { tab(2, ["Viaggio", "Trip"]) }
    private var helpTab: XCUIElement { tab(3, ["Aiuto", "Help"]) }

    private func launchOnNow() -> Bool {
        start(place)
        guard app.windows.firstMatch.waitForExistence(timeout: 20),
              nowTab.waitForExistence(timeout: 20) else { XCTFail("[\(variant)] mancano le schede"); return false }
        sleep(4)
        return true
    }

    // MARK: Controlli

    private var window: CGRect { app.windows.firstMatch.frame }

    /// Un elemento importante: c'è, è dentro la finestra in larghezza e, scorrendo al massimo quattro volte, si può toccare
    private func checkReachable(_ element: XCUIElement, _ name: String, screen: String, scroll: Bool = true) {
        guard element.waitForExistence(timeout: 6) else {
            XCTFail("[\(variant)] \(screen): manca «\(name)»"); return
        }
        if scroll {
            for _ in 0..<4 where !element.isHittable { app.swipeUp(); sleep(1) }
        }
        let f = element.frame, w = window
        XCTAssertTrue(element.isHittable,
                      "[\(variant)] \(screen): «\(name)» non si può toccare (cornice \(rect(f)), finestra \(rect(w)))")
        XCTAssertTrue(f.width > 0 && f.minX >= w.minX - 1 && f.maxX <= w.maxX + 1,
                      "[\(variant)] \(screen): «\(name)» esce dalla finestra in larghezza (cornice \(rect(f)), finestra \(rect(w)))")
    }

    /// Un elemento che deve stare dentro la finestra senza scorrere (le schede, l'icona del veicolo)
    private func checkVisible(_ element: XCUIElement, _ name: String, screen: String) {
        guard element.waitForExistence(timeout: 6) else {
            XCTFail("[\(variant)] \(screen): manca «\(name)»"); return
        }
        let f = element.frame, w = window
        XCTAssertTrue(element.isHittable && w.insetBy(dx: -1, dy: -1).contains(f),
                      "[\(variant)] \(screen): «\(name)» fuori dallo schermo o non toccabile (cornice \(rect(f)), finestra \(rect(w)))")
    }

    private func rect(_ r: CGRect) -> String {
        "\(Int(r.minX)),\(Int(r.minY)) \(Int(r.width))×\(Int(r.height))"
    }

    private func checkTabs(screen: String) {
        checkVisible(nowTab, "scheda Adesso", screen: screen)
        checkVisible(mapTab, "scheda Mappa", screen: screen)
        checkVisible(tripTab, "scheda Viaggio", screen: screen)
        checkVisible(helpTab, "scheda Aiuto", screen: screen)
    }

    // MARK: Schermate

    /// Adesso con un posto scelto (Palazzo Vecchio): la risposta, il pannello e i tre pulsanti sotto
    func testD1Adesso() {
        guard launchOnNow() else { return }
        print("DISPOSITIVO finestra \(rect(window)) variante \(variant)")
        snap("01-adesso")
        checkVisible(app.buttons["top.vehicle"].firstMatch, "icona del veicolo", screen: "Adesso")
        checkTabs(screen: "Adesso")
        // La parola della risposta: dentro la finestra in larghezza e non vuota
        let answer = app.staticTexts["varco.answer"].firstMatch
        if answer.waitForExistence(timeout: 10) {
            let f = answer.frame, w = window
            XCTAssertFalse(answer.label.isEmpty, "[\(variant)] Adesso: risposta vuota")
            XCTAssertTrue(f.minX >= w.minX - 1 && f.maxX <= w.maxX + 1,
                          "[\(variant)] Adesso: la risposta «\(answer.label)» esce dalla finestra (cornice \(rect(f)), finestra \(rect(w)))")
        } else {
            XCTFail("[\(variant)] Adesso: manca la risposta")
        }
        checkReachable(app.descendants(matching: .any)["gate.panel"].firstMatch, "pannello", screen: "Adesso", scroll: false)
        for (id, name) in [("varco.map", "Guarda la mappa"), ("varco.why", "Perché?"), ("varco.details", "Dettagli del viaggio")] {
            checkReachable(app.buttons[id].firstMatch, name, screen: "Adesso")
        }
        snap("01b-adesso-sotto")
    }

    /// Mappa: la ricerca e la legenda (niente ricerche sulla mappa stessa: l'albero è grande e va in tempo scaduto)
    func testD2Mappa() {
        guard launchOnNow() else { return }
        mapTab.tap()
        sleep(6)
        snap("02-mappa")
        checkTabs(screen: "Mappa")
        checkReachable(app.buttons["map.legend"].firstMatch, "legenda", screen: "Mappa", scroll: false)
        checkReachable(app.descendants(matching: .any)["map.search"].firstMatch, "ricerca", screen: "Mappa", scroll: false)
    }

    /// Viaggio con il posto scelto: la ricerca e «Percorso»
    func testD3Viaggio() {
        guard launchOnNow() else { return }
        tripTab.tap()
        sleep(2)
        snap("03-viaggio")
        checkTabs(screen: "Viaggio")
        checkReachable(app.descendants(matching: .any)["trip.search"].firstMatch, "ricerca", screen: "Viaggio", scroll: false)
        checkReachable(app.buttons["trip.route"].firstMatch, "Percorso", screen: "Viaggio")
        snap("03b-viaggio-sotto")
    }

    /// Aiuto: le tre righe principali
    func testD4Aiuto() {
        guard launchOnNow() else { return }
        helpTab.tap()
        sleep(2)
        snap("04-aiuto")
        checkTabs(screen: "Aiuto")
        for (id, name) in [("help.fine", "Hai preso una multa?"), ("help.learn", "Cosa sono le ZTL"), ("help.report", "Segnala un errore")] {
            checkReachable(app.buttons[id].firstMatch, name, screen: "Aiuto")
        }
    }

    /// La presentazione del primo avvio: «Salta» e poi «Più tardi», tutti e due toccabili
    func testD5Presentazione() {
        start(["-showOnboarding", "-onboarded", "NO"])
        sleep(5)
        snap("05-presentazione")
        let skip = app.buttons["intro2.skip"].firstMatch
        checkVisible(skip, "Salta", screen: "Presentazione")
        guard skip.exists, skip.isHittable else { return }
        skip.tap()
        sleep(2)
        snap("05b-presentazione-veicolo")
        let later = app.buttons["intro2.later"].firstMatch
        checkReachable(later, "Più tardi", screen: "Presentazione")
        guard later.exists, later.isHittable else { return }
        later.tap()
        sleep(3)
        XCTAssertTrue(nowTab.waitForExistence(timeout: 10), "[\(variant)] dopo la presentazione mancano le schede")
        snap("05c-dopo-presentazione")
    }

    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = "\(variant)-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
        guard let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] else { return }
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? shot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(variant)-\(name).png"))
    }
}
