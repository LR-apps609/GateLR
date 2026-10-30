import XCTest

// Un giro dell'app nel simulatore, con una foto per ogni schermata.
// Le foto finiscono nella cartella indicata da SCREENSHOT_DIR (la imposta il workflow su GitHub)
// e negli allegati del risultato del test.
final class ScreenshotTests: XCTestCase {
    private let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = true
    }

    // Le tre schede di GateLR 2.0: 0 «Varco», 1 «Mappa» (al centro), 2 «Tu»
    private var varcoTab: XCUIElement { app.tabBars.buttons.element(boundBy: 0) }
    private var mapTab: XCUIElement { app.tabBars.buttons.element(boundBy: 1) }
    private var youTab: XCUIElement { app.tabBars.buttons.element(boundBy: 2) }

    /// Una pagina di «Tu» (identificatore «you.<pagina>»)
    @discardableResult
    private func openYou(_ page: String) -> Bool {
        let row = app.buttons["you.\(page)"].firstMatch
        guard row.waitForExistence(timeout: 4) else { return false }
        row.tap()
        sleep(1)
        return true
    }

    /// Indietro con il gesto dal bordo sinistro: nessuna ricerca di elementi (sul Mac di GitHub la ricerca del pulsante
    /// «indietro» andava a volte in tempo scaduto e faceva fallire tutto il giro)
    private func back() {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.45))
        start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.45)))
        sleep(1)
    }

    func test1Tour() {
        XCUIDevice.shared.appearance = .light
        app.launchArguments = ["-uitest"]
        app.launch()
        XCTAssertTrue(varcoTab.waitForExistence(timeout: 15))
        sleep(4)                       // la striscia di mappa si carica dalla rete
        snap("01-varco")

        // Varco: la ricerca, poi la risposta con il pannello
        let field = app.textFields["varco.search"].firstMatch
        if field.waitForExistence(timeout: 3) {
            field.tap()
            field.typeText("Palazzo Vecchio")
            sleep(4)
            snap("02-varco-search")
            let first = app.buttons["varco.result.0"].firstMatch
            if first.waitForExistence(timeout: 5) {
                first.tap()
                sleep(4)
                snap("03-varco-answer")
                app.swipeUp()
                sleep(1)
                snap("03b-varco-answer-more")
            }
        }

        // «Guarda la mappa»: la scheda Mappa sulla zona della risposta
        // Una sola ricerca, con firstMatch: in più «isHittable» rifaceva la fotografia dell'albero di accessibilità
        // della risposta (grande, con la striscia di mappa) e sul Mac di GitHub andava in tempo scaduto (corsa
        // 40782824915: «Failed to get matching snapshots: Timed out while evaluating UI query»). Dopo lo swipe il
        // pulsante è sullo schermo
        let seeMap = app.buttons["varco.map"].firstMatch
        if seeMap.waitForExistence(timeout: 5) { seeMap.tap() } else { mapTab.tap() }
        sleep(6)                       // le mappe si caricano dalla rete
        snap("04-map-place")

        // Dopo la mappa l'app si riapre: con la scheda Mappa viva l'albero di accessibilità è enorme e sul Mac di GitHub
        // la ricerca delle righe di «Tu» andava in tempo scaduto (corse 40613295232 e 40612515432). Il posto scelto resta
        app.terminate()
        app.launch()
        XCTAssertTrue(youTab.waitForExistence(timeout: 15))
        youTab.tap()
        sleep(1)
        snap("05-you")

        // Viaggio e hotel: il posto scelto in Varco, il messaggio per l'hotel
        if openYou("trip") {
            sleep(2)
            snap("06-trip-answer")
            app.swipeUp()
            sleep(1)
            snap("06b-trip-hotel-message")
            back()
        }

        // Garage e il modulo del veicolo con «Cerca dalla targa» chiuso
        if openYou("garage") {
            snap("07-garage")
            let add = app.navigationBars.buttons["Add a vehicle"].firstMatch
            if add.waitForExistence(timeout: 3) {
                add.tap(); sleep(1)
                snap("07b-vehicle-form")
                let cancel = app.buttons["Cancel"].firstMatch
                if cancel.waitForExistence(timeout: 3) { cancel.tap() } else { app.swipeDown(velocity: .fast) }
                sleep(1)
            }
            back()
        }

        if openYou("fines") {
            snap("08-fines")
            let fine = app.buttons["Got a fine?"].firstMatch
            if fine.waitForExistence(timeout: 3) { fine.tap(); sleep(1); snap("08b-fine-guide"); back() }
            let log = app.buttons["Drive log"].firstMatch
            if log.waitForExistence(timeout: 3) { log.tap(); sleep(1); snap("08c-drive-log"); back() }
            back()
        }

        // Cosa sono le ZTL → Leggi il cartello: testo scritto a mano (nel simulatore non c'è la fotocamera)
        if openYou("learn") {
            snap("08d-learn")
            let sign = app.buttons["learn.sign"].firstMatch
            if sign.waitForExistence(timeout: 3) {
                sign.tap()
                let t = app.descendants(matching: .any)["sign.text"]
                if t.waitForExistence(timeout: 3) {
                    t.tap(); t.typeText("ZONA TRAFFICO LIMITATO\n7.30-20.00\nFERIALI")
                    sleep(1)
                    snap("08e-sign-reader")
                }
                back()
            }
            back()
        }

        if openYou("settings") { snap("08f-settings"); back() }
        if openYou("subscription") { snap("08g-subscription"); back() }
    }

    /// Il primo avvio: la presentazione 2.0, «Salta» porta all'ultima pagina, «Più tardi» all'app
    func test2Onboarding() {
        app.launchArguments = ["-uitest", "-showOnboarding", "-onboarded", "NO"]
        app.launch()
        sleep(4)
        snap("09-intro")
        let skip = app.buttons["intro2.skip"].firstMatch
        if skip.waitForExistence(timeout: 5) {
            skip.tap(); sleep(2)
            snap("09b-intro-where")
            let later = app.buttons["intro2.later"].firstMatch
            if later.waitForExistence(timeout: 3) {
                later.tap(); sleep(3)
                snap("09c-after-intro")
            }
        }
    }

    /// Milano di sera: il Duomo in Area C dentro l'Area B verde, il percorso e la guida
    func test3MilanDark() {
        app.launchArguments = ["-uitest", "-uiDark", "-uiPlace", "Duomo di Milano", "45.4641", "9.1919", "-uiOrigin", "45.4850", "9.2040"]
        app.launch()
        XCTAssertTrue(varcoTab.waitForExistence(timeout: 15))
        sleep(4)
        snap("10-varco-dark")
        mapTab.tap()
        sleep(6)
        snap("11-map-milan-dark")
        youTab.tap()
        sleep(1)
        snap("11b-you-dark")
        guard openYou("trip") else { return }
        sleep(1)
        snap("12-trip-milan-dark")
        let route = app.buttons["trip.route"].firstMatch
        if route.waitForExistence(timeout: 3) {
            route.tap()
            sleep(10)                  // percorso e parcheggio dalla rete
            app.swipeUp()
            sleep(1)
            snap("13-route-milan-dark")
            let start = app.buttons["route.start"].firstMatch
            if start.waitForExistence(timeout: 3) {
                start.tap()
                sleep(1)
                snap("13b-start-menu-dark")
                let own = app.buttons["GateLR navigation"].firstMatch
                if own.waitForExistence(timeout: 3) { own.tap() }
                sleep(8)
                snap("14-drive-milan-dark")
                let end = app.buttons["drive.end"].firstMatch
                if end.waitForExistence(timeout: 3) { end.tap(); sleep(1) }
            }
        }
    }

    /// Tutto in italiano: per controllare che non resti inglese in giro
    func test4Italian() {
        app.launchArguments = ["-uitest", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT",
                               "-uiPlace", "Piazza Maggiore", "44.4939", "11.3426"]
        app.launch()
        sleep(4)
        snap("15-it-varco")
        let why = app.buttons["varco.why"].firstMatch
        if why.waitForExistence(timeout: 5) {
            if !why.isHittable { app.swipeUp(); sleep(1) }
            why.tap(); sleep(1); snap("17-it-zone")
            app.swipeUp(); sleep(1); snap("18-it-zone-sources")
            app.buttons["Fine"].firstMatch.tap()
            sleep(1)
        }
        youTab.tap()
        sleep(1)
        snap("20-it-tu")
        if openYou("trip") { sleep(1); snap("16-it-trip"); back() }
        if openYou("learn") { snap("21-it-learn"); back() }
        if openYou("settings") { snap("22-it-settings"); back() }
        // La mappa per ultima: con tutte le città l'albero di accessibilità della mappa è grande e, sul Mac di GitHub,
        // la ricerca della scheda «Tu» subito dopo andava a volte in tempo scaduto (run 40556483108)
        mapTab.tap()
        sleep(5)
        snap("19-it-map")
    }

    /// 1.16.2: una zona con regole da fonti non ufficiali (Firenze segnata così solo nel giro delle foto): l'avviso
    /// «Fonte non ufficiale: verifica sempre il cartello al varco» in Varco, nella scheda della zona e sulla mappa
    func test5Unofficial() {
        app.launchArguments = ["-uitest", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT", "-uiUnofficial", "firenze",
                               "-uiPlace", "Palazzo Vecchio", "43.7696", "11.2558"]
        app.launch()
        XCTAssertTrue(varcoTab.waitForExistence(timeout: 15))
        sleep(4)
        snap("23-unofficial-varco")
        XCTAssertTrue(app.descendants(matching: .any)["unofficial.banner"].firstMatch.waitForExistence(timeout: 5),
                      "Manca l'avviso «Fonte non ufficiale» in Varco")
        let why = app.buttons["varco.why"].firstMatch
        if why.waitForExistence(timeout: 5) {
            if !why.isHittable { app.swipeUp(); sleep(1) }
            why.tap(); sleep(1); snap("24-unofficial-zone")
            XCTAssertTrue(app.descendants(matching: .any)["unofficial.banner"].firstMatch.waitForExistence(timeout: 3),
                          "Manca l'avviso nella scheda della zona")
            app.buttons["Fine"].firstMatch.tap()
            sleep(1)
        }
        mapTab.tap()
        sleep(5)
        snap("25-unofficial-map")
    }

    /// 1.16.3: con un posto scelto il pannello senza palo e «Guarda la mappa», «Perché?» e «Dettagli del viaggio» nello
    /// schermo senza scorrere. Il controllo vale su iPhone da 6,9" (Pro Max, 440×956 punti): il workflow lancia questo test
    /// anche su un simulatore Pro Max; sugli altri iPhone fa solo la foto
    func test6VarcoProMax() {
        app.launchArguments = ["-uitest", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT",
                               "-uiPlace", "Palazzo Vecchio", "43.7696", "11.2558"]
        app.launch()
        XCTAssertTrue(varcoTab.waitForExistence(timeout: 15))
        sleep(5)
        let window = app.windows.firstMatch.frame
        let big = window.height >= 950
        snap(big ? "26-varco-69" : "26-varco-place")
        // Il bordo alto della barra delle schede: quello che sta sopra si vede senza scorrere
        let tabTop = app.tabBars.firstMatch.exists ? app.tabBars.firstMatch.frame.minY : window.maxY
        for id in ["varco.map", "varco.why", "varco.details"] {
            let b = app.buttons[id].firstMatch
            XCTAssertTrue(b.waitForExistence(timeout: 5), "Manca \(id)")
            if big {
                XCTAssertTrue(b.isHittable && b.frame.maxY <= tabTop + 1,
                              "\(id) non si vede senza scorrere su \(Int(window.width))×\(Int(window.height)): fondo a \(Int(b.frame.maxY)), barra a \(Int(tabTop))")
            }
        }
        // La legenda della mappa: si apre con un tocco e si richiude con un tocco sulla legenda stessa
        mapTab.tap()
        sleep(4)
        let strip = app.buttons["map.legend"].firstMatch
        if strip.waitForExistence(timeout: 4) {
            strip.tap(); sleep(1)
            snap(big ? "27-legend-open-69" : "27-legend-open")
            let full = app.descendants(matching: .any)["map.legend.full"].firstMatch
            if full.waitForExistence(timeout: 3) {
                full.tap(); sleep(1)
                XCTAssertTrue(app.buttons["map.legend"].firstMatch.waitForExistence(timeout: 3), "La legenda non si è richiusa")
            }
        }
    }

    /// 1.17.0: la modalità prova (zona finta intorno a Campo di Marte a Firenze, senza rete) con la striscia viola,
    /// la scheda della zona, il modulo «Segnala un errore», Impostazioni e la mappa con «ZONA DI PROVA»
    func test7TestModeAndReport() {
        app.launchArguments = ["-uitest", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT",
                               "-uiTestMode", "43.7765", "11.2830", "-uiPlace", "Zona di prova", "43.7765", "11.2830"]
        app.launch()
        XCTAssertTrue(varcoTab.waitForExistence(timeout: 15))
        sleep(5)
        XCTAssertTrue(app.descendants(matching: .any)["testmode.banner"].firstMatch.waitForExistence(timeout: 5),
                      "Manca la striscia «Modalità prova attiva»")
        snap("28-prova-varco")
        let why = app.buttons["varco.why"].firstMatch
        if why.waitForExistence(timeout: 5) {
            if !why.isHittable { app.swipeUp(); sleep(1) }
            why.tap(); sleep(2)
            snap("29-prova-zona")
            let report = app.buttons["zone.report"].firstMatch
            if report.waitForExistence(timeout: 4) {
                if !report.isHittable { app.swipeUp(); sleep(1) }
                report.tap(); sleep(2)
                snap("30-prova-segnala")
                let cancel = app.buttons["Annulla"].firstMatch
                if cancel.waitForExistence(timeout: 3) { cancel.tap() } else { app.swipeDown(velocity: .fast) }
                sleep(1)
            } else {
                XCTFail("Manca «Segnala un errore» nella scheda della zona")
            }
            let done = app.buttons["Fine"].firstMatch
            if done.waitForExistence(timeout: 3) { done.tap() } else { app.swipeDown(velocity: .fast) }
            sleep(1)
        }
        youTab.tap()
        sleep(1)
        if openYou("settings") { sleep(1); snap("32-prova-impostazioni"); back() }
        // La mappa per ultima (albero di accessibilità grande, vedi test4Italian)
        mapTab.tap()
        sleep(5)
        snap("31-prova-mappa")
    }

    /// 1.19.0 «Mai un verde che non sappiamo»: il pannello e il colore di Varco nei casi nuovi. Per ultimo: il veicolo
    /// di prova resta salvato nel garage del simulatore
    func test9NeverGreenUnknown() {
        let it = ["-uitest", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"]
        let cases: [(String, [String])] = [
            // Fonte non ufficiale, varchi spenti (martedì 22:00): giallo con il «?», «Probabilmente sì»
            ("33-varco-unofficial-yes", ["-uiUnofficial", "firenze", "-uiAt", "22:00", "-uiPlace", "Palazzo Vecchio", "43.7696", "11.2558"]),
            // Pistoia non è tra le città: neutro, «Non conosciamo questo posto»
            ("34-varco-uncovered", ["-uiPlace", "Piazza del Duomo Pistoia", "43.9333", "10.9167"]),
            // Diesel Euro 1 di notte a Palazzo Vecchio: Settore A spento, ma lo Scudo Verde lo vieta
            ("35-varco-scudo-euro1-night", ["-uiVehicle", "diesel", "1", "-uiAt", "22:00", "-uiPlace", "Palazzo Vecchio", "43.7696", "11.2558"]),
            // Elettrica nell'Area C attiva (Corso Magenta, fuori dall'area pedonale del Duomo): verde «ZTL ATTIVA · SEI ESENTE»
            ("36-varco-active-exempt", ["-uiVehicle", "electric", "6", "-uiAt", "11:00", "-uiPlace", "Corso Magenta", "45.4658", "9.1780"]),
        ]
        for (name, extra) in cases {
            app.terminate()
            app.launchArguments = it + extra
            app.launch()
            XCTAssertTrue(varcoTab.waitForExistence(timeout: 15))
            sleep(5)
            snap(name)
        }
    }

    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        guard let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] else { return }
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? shot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
    }
}
