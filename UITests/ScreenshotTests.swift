import XCTest

// Un giro dell'app nel simulatore, con una foto per ogni schermata.
// Le foto finiscono nella cartella indicata da SCREENSHOT_DIR (la imposta il workflow su GitHub)
// e negli allegati del risultato del test.
final class ScreenshotTests: XCTestCase {
    private let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = true
    }

    func test1Tour() {
        XCUIDevice.shared.appearance = .light
        app.launchArguments = ["-uitest"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Gate"].waitForExistence(timeout: 10))
        sleep(1)
        snap("01-varco-city")

        // Ricerca di un indirizzo vero (serve la rete del simulatore)
        let field = app.textFields["varco.search"]
        if field.waitForExistence(timeout: 3) {
            field.tap()
            field.typeText("Palazzo Vecchio")
            sleep(4)
            snap("02-varco-search")
            let first = app.buttons["varco.result.0"]
            if first.waitForExistence(timeout: 5) {
                first.tap()
                sleep(3)
                snap("03-varco-address")
            }
        }

        let why = app.buttons["Why?"].firstMatch
        if why.waitForExistence(timeout: 5) {
            why.tap()
            sleep(1)
            snap("04-zone")
            app.swipeUp()
            sleep(1)
            snap("05-zone-sources")
            app.buttons["Done"].tap()
        }

        app.tabBars.buttons["Map"].tap()
        sleep(6)                       // le mappe si caricano dalla rete
        snap("06-map")
        let park = app.buttons["Park outside"].firstMatch
        if park.waitForExistence(timeout: 3) {
            park.tap()
            sleep(6)
            snap("07-map-parking")
        }

        app.tabBars.buttons["Trip"].tap()
        sleep(1)
        let hotel = app.textFields["trip.search"]
        if hotel.waitForExistence(timeout: 3) {
            hotel.tap()
            hotel.typeText("Hotel Brunelleschi Firenze")
            let first = app.buttons["trip.result.0"]
            if first.waitForExistence(timeout: 8) { first.tap(); sleep(3) }
        }
        snap("08-trip")
        app.swipeUp()
        sleep(1)
        snap("09-trip-message")

        app.tabBars.buttons["Garage"].tap()
        sleep(1)
        snap("10-garage")

        app.tabBars.buttons["Account"].tap()
        sleep(1)
        snap("11-account")
        let learn = app.buttons["What is a ZTL?"].firstMatch
        if learn.waitForExistence(timeout: 3) {
            learn.tap()
            sleep(1)
            snap("12-learn")
        }
    }

    func test2Onboarding() {
        app.launchArguments = ["-uitest", "-showOnboarding", "-onboarded", "NO"]
        app.launch()
        sleep(2)
        snap("13-onboarding")
    }

    /// Milano: il Duomo è in Area C, dentro l'Area B verde. Mappa da lontano con le scritte grandi.
    func test3MilanDark() {
        app.launchArguments = ["-uitest", "-uiDark", "-uiPlace", "Duomo di Milano", "45.4641", "9.1919", "-uiOrigin", "45.4850", "9.2040"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Gate"].waitForExistence(timeout: 10))
        sleep(2)
        snap("14-varco-milan-dark")
        let route = app.buttons["varco.route"]
        if route.waitForExistence(timeout: 3) {
            route.tap()
            sleep(10)                  // percorso e parcheggio dalla rete
            app.swipeUp()
            sleep(1)
            snap("14b-route-milan-dark")
        }
        app.tabBars.buttons["Map"].tap()
        sleep(5)
        app.pinch(withScale: 0.25, velocity: -1)
        sleep(4)
        snap("15-map-milan-far-dark")
    }

    /// Tutto in italiano: per controllare che non resti inglese in giro
    func test4Italian() {
        app.launchArguments = ["-uitest", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT",
                               "-uiPlace", "Piazza Maggiore", "44.4939", "11.3426"]
        app.launch()
        sleep(3)
        snap("16-it-varco")
        let why = app.buttons["Perché?"].firstMatch
        if why.waitForExistence(timeout: 5) {
            why.tap(); sleep(1); snap("17-it-zone")
            app.swipeUp(); sleep(1); snap("18-it-zone-sources")
            app.buttons["Fine"].tap()
        }
        app.tabBars.buttons.element(boundBy: 1).tap()
        sleep(5)
        snap("19-it-map")
        app.tabBars.buttons.element(boundBy: 2).tap()
        sleep(1)
        snap("20-it-trip")
        app.tabBars.buttons.element(boundBy: 4).tap()
        sleep(1)
        snap("21-it-account")
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
