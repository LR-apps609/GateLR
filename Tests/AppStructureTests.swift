import XCTest

/// GateLR 2.0 (1.16.0): tre schede, i vecchi indirizzi gatelr:// che portano alle nuove, la presentazione al primo
/// avvio una volta sola e «Cerca dalla targa» chiuso
final class AppStructureTests: XCTestCase {
    func testOldLinksOpenTheNewTabs() {
        XCTAssertTrue(AppRouter.destination(for: "varco") == (.varco, nil))
        XCTAssertTrue(AppRouter.destination(for: "now") == (.varco, nil))
        XCTAssertTrue(AppRouter.destination(for: nil) == (.varco, nil))
        XCTAssertTrue(AppRouter.destination(for: "map") == (.map, nil))
        XCTAssertTrue(AppRouter.destination(for: "trip") == (.you, .trip))
        XCTAssertTrue(AppRouter.destination(for: "garage") == (.you, .garage))
        XCTAssertTrue(AppRouter.destination(for: "account") == (.you, nil))
        XCTAssertTrue(AppRouter.destination(for: "Settings") == (.you, .settings))
    }

    @MainActor func testOpenRoutePicksYouTab() {
        let router = AppRouter()
        router.open(.trip)
        XCTAssertEqual(router.tab, .you)
        XCTAssertEqual(router.youPath, [.trip])
        router.handle(URL(string: "gatelr://map")!)
        XCTAssertEqual(router.tab, .map)
        XCTAssertTrue(router.youPath.isEmpty)
    }

    func testIntroOnlyAtFirstLaunch() {
        XCTAssertTrue(AppRouter.showIntroAtLaunch(onboarded: false, arguments: []))
        XCTAssertFalse(AppRouter.showIntroAtLaunch(onboarded: true, arguments: []))
        // Il giro automatico delle foto non la vede, se non la chiede
        XCTAssertFalse(AppRouter.showIntroAtLaunch(onboarded: false, arguments: ["-uitest"]))
        XCTAssertTrue(AppRouter.showIntroAtLaunch(onboarded: false, arguments: ["-uitest", "-showOnboarding"]))
        XCTAssertFalse(AppRouter.showIntroAtLaunch(onboarded: true, arguments: ["-uitest", "-showOnboarding"]))
        // Il video della presentazione su GitHub: sempre
        XCTAssertTrue(AppRouter.showIntroAtLaunch(onboarded: true, arguments: ["-uitest", "-intro2"]))
    }

    func testPlateLookupStaysOff() async {
        XCTAssertFalse(PlateLookupService.current.isAvailable)
        do {
            _ = try await PlateLookupService.current.lookup(plate: "AB123CD")
            XCTFail("La ricerca dalla targa non è attiva")
        } catch {
            XCTAssertEqual(error as? PlateLookupError, .notEnabled)
        }
    }

    func testWhatsNew116() {
        XCTAssertEqual(WhatsNewView.notes["1.16.0"]?.count, 3)
        XCTAssertTrue(WhatsNewView.shouldShow(version: "1.16.0", seen: "1.15.3", onboarded: true))
        XCTAssertFalse(WhatsNewView.shouldShow(version: "1.16.0", seen: nil, onboarded: false))
    }
}
