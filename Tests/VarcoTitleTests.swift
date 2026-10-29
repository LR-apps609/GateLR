import XCTest

/// 1.17.3: nella scheda di Varco il nome del posto è il titolo; la tua posizione si dice «La tua posizione»
final class VarcoTitleTests: XCTestCase {
    private func check(_ name: String) -> PlaceCheck {
        PlaceCheck(place: Place(name: name, address: "", location: Coordinate(lat: 43.7718, lon: 11.2513)), hits: [], answer: nil)
    }

    func testPlaceNameIsTheTitle() {
        XCTAssertEqual(VarcoView.placeTitle(check("Hotel Cavour")), "Hotel Cavour")
    }

    func testMyPositionReadsAsYourPosition() {
        XCTAssertEqual(VarcoView.placeTitle(check(L("My position"))), L("Your position"))
        XCTAssertNotEqual(L("Your position"), L("My position"))
    }
}
