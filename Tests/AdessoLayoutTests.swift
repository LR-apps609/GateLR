import XCTest

/// 2.0.1 (giro «Dispositivi»): Adesso si stringe sopra la risposta sugli schermi bassi e con il testo grande, perché la
/// parola della risposta stia sopra la barra delle schede senza scorrere
final class AdessoLayoutTests: XCTestCase {
    func testTallScreenWithNormalTextStaysFull() {
        // iPhone 17 (874), Pro Max (956), mini (812)
        for h: CGFloat in [874, 956, 812] {
            XCTAssertEqual(AdessoLayout.make(screenHeight: h, accessibilityText: false, hasAnswer: true), .full, "\(h)")
        }
    }

    func testShortScreenIsCompact() {
        // iPhone SE (667)
        XCTAssertEqual(AdessoLayout.make(screenHeight: 667, accessibilityText: false, hasAnswer: true), .compact)
        XCTAssertEqual(AdessoLayout.make(screenHeight: AdessoLayout.shortScreen, accessibilityText: false, hasAnswer: true), .compact)
    }

    func testAccessibilityTextIsCompactEvenOnTallScreens() {
        XCTAssertEqual(AdessoLayout.make(screenHeight: 874, accessibilityText: true, hasAnswer: true), .compact)
        XCTAssertEqual(AdessoLayout.make(screenHeight: 956, accessibilityText: true, hasAnswer: true), .compact)
    }

    func testShortScreenWithAccessibilityTextDropsTheStrip() {
        let l = AdessoLayout.make(screenHeight: 667, accessibilityText: true, hasAnswer: true)
        XCTAssertEqual(l, .tight)
        XCTAssertFalse(l.showsStrip)
    }

    func testWithoutAnAnswerNothingChanges() {
        // Senza un posto c'è la domanda grande e la ricerca: niente da stringere
        XCTAssertEqual(AdessoLayout.make(screenHeight: 667, accessibilityText: true, hasAnswer: false), .full)
        XCTAssertEqual(AdessoLayout.make(screenHeight: 0, accessibilityText: false, hasAnswer: true), .full)
    }

    func testCompactIsSmallerThanFull() {
        XCTAssertNil(AdessoLayout.full.stripHeight)
        XCTAssertLessThan(AdessoLayout.compact.stripHeight ?? 999, 112)
        XCTAssertTrue(AdessoLayout.compact.showsStrip)
        XCTAssertLessThan(AdessoLayout.compact.spacing, AdessoLayout.full.spacing)
        XCTAssertLessThan(AdessoLayout.tight.spacing, AdessoLayout.full.spacing)
    }
}
