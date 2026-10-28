import XCTest

// Solo per il video di anteprima dell'App Store (workflow manuale «anteprima.yml»): l'app vera guidata con i tempi di una
// persona mentre il simulatore registra lo schermo. Nel giro normale delle foto questi test si saltano: partono solo con
// TEST_RUNNER_ANTEPRIMA=1 (xcodebuild passa al test le variabili con il prefisso TEST_RUNNER_ senza il prefisso).
final class AnteprimaTests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = true
        guard ProcessInfo.processInfo.environment["ANTEPRIMA"] != nil else {
            throw XCTSkip("Solo per il video di anteprima (TEST_RUNNER_ANTEPRIMA=1)")
        }
    }

    /// Varco: «Hotel, indirizzo o piazza», un posto scritto lettera per lettera, la risposta, «Guarda la mappa»,
    /// e la legenda aperta
    func testA1RicercaFirenze() { tour(query: "Palazzo Vecchio") }

    /// Lo stesso con un'altra città (ZTL 0–24): nel montaggio si sceglie la risposta che si legge meglio
    func testA2RicercaTreviso() { tour(query: "Piazza dei Signori Treviso", prefer: "Treviso") }

    private func tour(query: String, prefer: String? = nil) {
        XCUIDevice.shared.appearance = .dark
        app.launchArguments = ["-uitest", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"]
        app.launch()
        let varco = app.tabBars.buttons.element(boundBy: 0)
        XCTAssertTrue(varco.waitForExistence(timeout: 20))
        sleep(4)                                   // la striscia di mappa in alto si carica dalla rete

        let field = app.textFields["varco.search"]
        guard field.waitForExistence(timeout: 5) else { return XCTFail("Manca la ricerca di Varco") }
        field.tap()
        usleep(700_000)
        // A pezzi di quattro lettere, come chi scrive in fretta: i suggerimenti compaiono mentre si scrive. Lettera per
        // lettera sul Mac Intel di GitHub ci volevano circa 6 s a lettera e il test finiva prima della mappa
        var rest = Substring(query)
        while !rest.isEmpty {
            field.typeText(String(rest.prefix(4)))
            rest = rest.dropFirst(4)
            usleep(250_000)
        }
        sleep(3)

        // Il primo suggerimento, o il primo che nomina la città voluta
        var pick = app.buttons["varco.result.0"]
        if let prefer {
            for i in 0..<5 {
                let b = app.buttons["varco.result.\(i)"]
                if b.exists, b.label.localizedCaseInsensitiveContains(prefer) { pick = b; break }
            }
        }
        guard pick.waitForExistence(timeout: 8) else { return XCTFail("Nessun suggerimento per «\(query)»") }
        pick.tap()
        sleep(6)                                   // la risposta: pannello, titolo, orari

        // «Guarda la mappa»: la scheda Mappa sulla zona del posto
        let seeMap = app.buttons["varco.map"]
        if seeMap.waitForExistence(timeout: 4) && seeMap.isHittable {
            seeMap.tap()
        } else {
            app.tabBars.buttons.element(boundBy: 1).tap()
        }
        sleep(6)                                   // mattonelle della mappa dalla rete

        // La legenda, come nel giro delle foto. Niente app.maps né pinch: l'istantanea della mappa (piena di zone) nella
        // corsa 40610078905 ha fatto perdere al test il contatto con l'app per 300 s
        let legend = app.buttons["map.legend"].firstMatch
        if legend.waitForExistence(timeout: 4) {
            legend.tap()
            sleep(5)
        }
    }
}
