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
        XCTAssertTrue(app.tabBars.buttons["Now"].waitForExistence(timeout: 10))
        sleep(1)
        snap("01-now")
        app.swipeUp()
        sleep(1)
        snap("02-now-sectors")
        app.swipeDown()

        let why = app.buttons["Why?"].firstMatch
        if why.waitForExistence(timeout: 5) {
            why.tap()
            sleep(1)
            snap("03-zone")
            app.swipeUp()
            sleep(1)
            snap("04-zone-sources")
            app.buttons["Done"].tap()
        }

        app.tabBars.buttons["Map"].tap()
        sleep(6)                       // le mappe si caricano dalla rete
        snap("05-map")
        let park = app.buttons["Park outside"].firstMatch
        if park.waitForExistence(timeout: 3) {
            park.tap()
            sleep(6)
            snap("06-map-parking")
        }

        app.tabBars.buttons["Trip"].tap()
        sleep(1)
        snap("07-trip")
        app.swipeUp()
        sleep(1)
        snap("08-trip-message")

        app.tabBars.buttons["Garage"].tap()
        sleep(1)
        snap("09-garage")
        app.swipeUp()
        sleep(1)
        snap("10-garage-settings")
    }

    func test2Onboarding() {
        app.launchArguments = ["-uitest", "-showOnboarding", "-onboarded", "NO"]
        app.launch()
        sleep(2)
        snap("11-onboarding")
    }

    func test3Dark() {
        XCUIDevice.shared.appearance = .dark
        app.launchArguments = ["-uitest"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Now"].waitForExistence(timeout: 10))
        sleep(1)
        snap("12-now-dark")
        app.tabBars.buttons["Map"].tap()
        sleep(5)
        snap("13-map-dark")
        XCUIDevice.shared.appearance = .light
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
