import XCTest

// Un giro dell'app nel simulatore, con una foto per ogni schermata.
// Le foto finiscono nella cartella indicata da SCREENSHOT_DIR (la imposta il workflow su GitHub).
final class ScreenshotTests: XCTestCase {
    private let app = XCUIApplication()

    func testTour() {
        app.launchArguments = ["-uitest"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Now"].waitForExistence(timeout: 10))
        sleep(1)
        snap("1-now")

        let why = app.buttons["Why?"]
        if why.waitForExistence(timeout: 5) {
            why.tap()
            sleep(1)
            snap("2-zone")
            app.swipeUp()
            sleep(1)
            snap("3-zone-sources")
            app.buttons["Done"].tap()
        }

        app.tabBars.buttons["Map"].tap()
        sleep(5)                       // le mappe si caricano dalla rete
        snap("4-map")

        app.tabBars.buttons["Trip"].tap()
        sleep(1)
        snap("5-trip")
        app.swipeUp()
        sleep(1)
        snap("6-trip-message")

        app.tabBars.buttons["Garage"].tap()
        sleep(1)
        snap("7-garage")
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
