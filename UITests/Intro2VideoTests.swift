import XCTest

// Il prototipo della nuova presentazione (-intro2), percorso da cima a fondo con i tempi di una persona:
// il workflow registra lo schermo del simulatore intanto (simctl io recordVideo) e pubblica il video nel ramo
// «intro-video». Non fa parte del giro delle foto (lì si salta con -skip-testing).
final class Intro2VideoTests: XCTestCase {
    private let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = true
    }

    func testIntro2Walkthrough() {
        app.launchArguments = ["-uitest", "-intro2", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"]
        app.launch()

        // 1. L'auto entra dal varco, arriva il verbale
        let avoid = app.buttons["intro2.avoid"]
        XCTAssertTrue(avoid.waitForExistence(timeout: 30))
        sleep(2)
        snap("intro-1-verbale")
        avoid.tap()
        // Il percorso intorno alla zona fino al parcheggio
        let next1 = app.buttons["intro2.next1"]
        XCTAssertTrue(next1.waitForExistence(timeout: 20))
        sleep(1)
        snap("intro-2-arrivato")
        next1.tap()

        // 2. Il pannello rosso/ambra/verde e l'avviso dall'alto
        let alerts = app.buttons["intro2.alerts"]
        XCTAssertTrue(alerts.waitForExistence(timeout: 10))
        sleep(3)
        snap("intro-3-avvisi")
        sleep(3)
        alerts.tap()

        // 3. Il cartello letto e spiegato, poi gli altri cartelli
        let next3 = app.buttons["intro2.next3"]
        XCTAssertTrue(next3.waitForExistence(timeout: 10))
        sleep(4)
        snap("intro-4-cartello")
        sleep(3)
        snap("intro-5-cartelli")
        next3.tap()

        // 4. Dove vai e con che auto
        let florence = app.buttons["intro2.city.firenze"]
        if florence.waitForExistence(timeout: 10) { florence.tap() }
        let diesel = app.buttons["intro2.fuel.diesel"]
        if diesel.waitForExistence(timeout: 3) { diesel.tap() }
        let euro6 = app.buttons["intro2.euro.6"]
        if euro6.waitForExistence(timeout: 3) { euro6.tap() }
        sleep(1)
        snap("intro-6-dove-vai")
        let start = app.buttons["intro2.start"]
        if start.waitForExistence(timeout: 3) { start.tap() }
        sleep(2)
        app.terminate()

        // Il disegno di riserva senza mappa (come senza rete): la prima pagina ancora una volta
        app.launchArguments = ["-uitest", "-intro2", "-intro2Fallback", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"]
        app.launch()
        let avoid2 = app.buttons["intro2.avoid"]
        XCTAssertTrue(avoid2.waitForExistence(timeout: 30))
        sleep(1)
        snap("intro-7-riserva-verbale")
        avoid2.tap()
        if app.buttons["intro2.next1"].waitForExistence(timeout: 20) {
            sleep(1)
            snap("intro-8-riserva-arrivato")
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
