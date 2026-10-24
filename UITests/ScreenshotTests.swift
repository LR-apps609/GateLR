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
        XCTAssertTrue(app.tabBars.buttons.element(boundBy: 0).waitForExistence(timeout: 15))
        sleep(2)
        snap("01-home")
        app.swipeUp()
        sleep(1)
        snap("01b-home-cities")

        // Viaggio: l'unica ricerca dell'app
        let plan = app.buttons["varco.plan"]
        if plan.waitForExistence(timeout: 3) { plan.tap() } else { app.tabBars.buttons.element(boundBy: 2).tap() }
        sleep(1)
        snap("02-trip-empty")
        let field = app.textFields["trip.search"]
        if field.waitForExistence(timeout: 3) {
            field.tap()
            field.typeText("Palazzo Vecchio")
            sleep(4)
            snap("03-trip-search")
            let first = app.buttons["trip.result.0"]
            if first.waitForExistence(timeout: 5) {
                first.tap()
                sleep(4)
                snap("04-trip-answer")
                app.swipeUp()
                sleep(1)
                snap("05-trip-hotel-message")
            }
        }

        app.tabBars.buttons.element(boundBy: 1).tap()
        sleep(6)                       // le mappe si caricano dalla rete
        snap("06-map-place")

        app.tabBars.buttons.element(boundBy: 3).tap()
        sleep(1)
        snap("07-garage")

        app.tabBars.buttons.element(boundBy: 4).tap()
        sleep(1)
        snap("08-account")
    }

    func test2Onboarding() {
        app.launchArguments = ["-uitest", "-showOnboarding", "-onboarded", "NO"]
        app.launch()
        sleep(2)
        snap("09-onboarding")
    }

    /// Milano di sera: il Duomo in Area C dentro l'Area B verde, il percorso e la guida
    func test3MilanDark() {
        app.launchArguments = ["-uitest", "-uiDark", "-uiPlace", "Duomo di Milano", "45.4641", "9.1919", "-uiOrigin", "45.4850", "9.2040"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons.element(boundBy: 0).waitForExistence(timeout: 15))
        sleep(2)
        snap("10-home-dark")
        app.tabBars.buttons.element(boundBy: 1).tap()
        sleep(6)
        snap("11-map-milan-dark")
        app.tabBars.buttons.element(boundBy: 2).tap()
        sleep(2)
        snap("12-trip-milan-dark")
        let route = app.buttons["trip.route"]
        if route.waitForExistence(timeout: 3) {
            route.tap()
            sleep(10)                  // percorso e parcheggio dalla rete
            app.swipeUp()
            sleep(1)
            snap("13-route-milan-dark")
            let start = app.buttons["route.start"]
            if start.waitForExistence(timeout: 3) {
                start.tap()
                sleep(8)
                snap("14-drive-milan-dark")
                let end = app.buttons["drive.end"]
                if end.waitForExistence(timeout: 3) { end.tap(); sleep(1) }
            }
        }
    }

    /// Tutto in italiano: per controllare che non resti inglese in giro
    func test4Italian() {
        app.launchArguments = ["-uitest", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT",
                               "-uiPlace", "Piazza Maggiore", "44.4939", "11.3426"]
        app.launch()
        sleep(3)
        snap("15-it-home")
        app.tabBars.buttons.element(boundBy: 2).tap()
        sleep(2)
        snap("16-it-trip")
        let why = app.buttons["Perché?"].firstMatch
        if why.waitForExistence(timeout: 5) {
            why.tap(); sleep(1); snap("17-it-zone")
            app.swipeUp(); sleep(1); snap("18-it-zone-sources")
            app.buttons["Fine"].tap()
        }
        app.tabBars.buttons.element(boundBy: 1).tap()
        sleep(5)
        snap("19-it-map")
        app.tabBars.buttons.element(boundBy: 4).tap()
        sleep(1)
        snap("20-it-account")
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
