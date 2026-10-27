import XCTest

/// La presentazione dice la verità: il giorno e la sera della prima pagina sono quelli del Settore A di Firenze secondo
/// il RuleEngine e Resources/Cities/firenze.json. E le regole della richiesta di recensione (ReviewPrompter).
final class IntroAndReviewTests: XCTestCase {
    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

    private func sectorA() throws -> Zone {
        let city = try CityLoader.decode(Data(contentsOf: Self.root.appendingPathComponent("Resources/Cities/firenze.json")))
        return try XCTUnwrap(city.zones.first { $0.id == "firenze-a" })
    }

    func testIntroDayMomentIsActive() throws {
        let a = RuleEngine().answer(zone: try sectorA(), vehicle: SampleData.rental, permits: [], hotelInside: false,
                                    at: IntroScene.dayMoment)
        XCTAssertTrue(a.gatesOn, "alle 11:30 del giorno della presentazione il Settore A deve essere attivo")
    }

    func testIntroEveningMomentIsNotActive() throws {
        let a = RuleEngine().answer(zone: try sectorA(), vehicle: SampleData.rental, permits: [], hotelInside: false,
                                    at: IntroScene.nightMoment)
        XCTAssertFalse(a.gatesOn, "alle 21:00 del giorno della presentazione il Settore A deve essere spento")
    }

    func testIntroMomentsAreAWeekdayOutsideSummerNightsAndHolidays() {
        let cal = RuleEngine.rome
        XCTAssertEqual(cal.component(.weekday, from: IntroScene.dayMoment), 3)          // martedì
        XCTAssertTrue(cal.isDate(IntroScene.dayMoment, inSameDayAs: IntroScene.nightMoment))
        XCTAssertFalse(ItalianHolidays.isHoliday(IntroScene.dayMoment, calendar: cal))
        XCTAssertEqual(cal.component(.month, from: IntroScene.dayMoment), 11)           // fuori dal 2 aprile – 3 ottobre
    }

    // MARK: Recensione

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testFirstAnswerAsksOnce() {
        XCTAssertTrue(ReviewPrompter.shouldRequest(lastVersion: nil, lastDate: nil, version: "1.16.3", now: now, blocked: false))
    }

    func testNeverWhenBlocked() {
        XCTAssertFalse(ReviewPrompter.shouldRequest(lastVersion: nil, lastDate: nil, version: "1.16.3", now: now, blocked: true))
    }

    func testNotAgainInTheSameVersion() {
        let long = now.addingTimeInterval(-400 * 86_400)
        XCTAssertFalse(ReviewPrompter.shouldRequest(lastVersion: "1.16.3", lastDate: long, version: "1.16.3", now: now, blocked: false))
    }

    func testNewVersionWaits120Days() {
        let recent = now.addingTimeInterval(-119 * 86_400)
        let old = now.addingTimeInterval(-120 * 86_400)
        XCTAssertFalse(ReviewPrompter.shouldRequest(lastVersion: "1.16.3", lastDate: recent, version: "1.17.0", now: now, blocked: false))
        XCTAssertTrue(ReviewPrompter.shouldRequest(lastVersion: "1.16.3", lastDate: old, version: "1.17.0", now: now, blocked: false))
    }

    func testStoredRequestAndUITest() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "IntroAndReviewTests"))
        defaults.removePersistentDomain(forName: "IntroAndReviewTests")
        XCTAssertFalse(ReviewPrompter.shouldRequest(now: now, blocked: false, defaults: defaults, arguments: ["-uitest"]))
        XCTAssertTrue(ReviewPrompter.shouldRequest(now: now, blocked: false, defaults: defaults, arguments: []))
        ReviewPrompter.recordRequest(now: now, defaults: defaults)
        XCTAssertFalse(ReviewPrompter.shouldRequest(now: now.addingTimeInterval(500 * 86_400), blocked: false,
                                                    defaults: defaults, arguments: []))   // stessa versione
        defaults.removePersistentDomain(forName: "IntroAndReviewTests")
    }

    func testNoReviewRowWithoutAppStoreID() {
        // APP_STORE_ID è vuoto finché l'app non è su App Store
        XCTAssertNil(ReviewPrompter.writeReviewURL)
    }
}
