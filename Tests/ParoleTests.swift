import XCTest
import UIKit

/// 1.20.3 «Parole»: una sola forma della risposta per lingua, i dati delle città in italiano + inglese dove manca la
/// lingua, pillole neutre, velocità dal locale, frecce dalla forma della strada
final class ParoleTests: XCTestCase {
    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    private static let titles = Set(AnswerWord.allCases.map(\.title))

    private func answer(_ v: Verdict, on: Bool = true) -> Answer { Answer(verdict: v, gatesOn: on, nextChange: nil) }
    private let yes = Verdict.yes(reason: "r"), no = Verdict.no(reason: "r")
    private let cond = Verdict.conditional(reason: "r", condition: "Solo con il ticket."), unsure = Verdict.unsure(reason: "Festivo da confermare.")

    // MARK: Il titolo fisso per stato

    func testFixedTitlePerEngineState() {
        XCTAssertEqual(no.word(unofficial: false), .dontEnter)
        XCTAssertEqual(no.word(unofficial: true), .dontEnter, "un «no» non ufficiale resta «Non entrare» (rosso)")
        XCTAssertEqual(yes.word(unofficial: false), .enter)
        XCTAssertEqual(yes.word(unofficial: true), .checkSign, "un «sì» non ufficiale è «Controlla il cartello» (giallo)")
        XCTAssertEqual(cond.word(unofficial: false), .condition)
        XCTAssertEqual(cond.word(unofficial: true), .condition)
        XCTAssertEqual(unsure.word(unofficial: false), .checkSign)
        // Tutte le forme brevi sono il titolo fisso
        for v in [yes, no, cond, unsure] {
            XCTAssertEqual(v.title, v.word(unofficial: false).title)
            XCTAssertEqual(v.short, v.title)
            for u in [false, true] {
                XCTAssertEqual(v.shortText(unofficial: u), v.word(unofficial: u).title)
                XCTAssertTrue(v.spokenText(unofficial: u).hasPrefix(v.word(unofficial: u).title))
                XCTAssertEqual(v.titleLines(unofficial: u), v.word(unofficial: u).lines)
            }
        }
        XCTAssertEqual(AnswerWord.dontEnter.key, "Don't enter")
        XCTAssertEqual(AnswerWord.enter.key, "You can enter")
        XCTAssertEqual(AnswerWord.condition.key, "On one condition")
        XCTAssertEqual(AnswerWord.checkSign.key, "Check the sign")
        XCTAssertEqual(AnswerWord.unknownPlace.key, "We don't know this place")
    }

    /// Ogni stato del posto (PlaceCheck.Kind) ha il suo titolo fisso, lo stesso in Varco, Mappa e notifiche
    func testEveryPlaceKindHasAFixedTitle() {
        let city = SampleData.florence, zone = SampleData.sectorA
        var unofficialZone = zone; unofficialZone.source.official = false
        let place = Place(name: "Prova", address: "", location: city.center)
        func pc(_ z: Zone?, _ a: Answer?, covered: Bool = true, pedestrian: PedestrianArea? = nil) -> PlaceCheck {
            PlaceCheck(place: place, hits: z.map { [(city: city, zone: $0)] } ?? [], pedestrian: pedestrian, answer: a, covered: covered)
        }
        let area = PedestrianArea(id: "p", name: "Via Prova", perimeter: zone.perimeter)
        let cases: [(PlaceCheck, AnswerWord, String)] = [
            (pc(nil, nil, covered: false), .unknownPlace, "fuori copertura"),
            (pc(nil, nil), .enter, "fuori dalla ZTL"),
            (pc(zone, answer(yes)), .enter, "sì"),
            (pc(zone, answer(yes, on: false)), .enter, "ZTL non attiva"),
            (pc(unofficialZone, answer(yes)), .checkSign, "sì non ufficiale"),
            (pc(zone, answer(no)), .dontEnter, "no"),
            (pc(unofficialZone, answer(no)), .dontEnter, "no non ufficiale"),
            (pc(zone, answer(cond)), .condition, "condizione"),
            (pc(zone, answer(unsure)), .checkSign, "non sicuro"),
            (pc(nil, nil, pedestrian: area), .dontEnter, "area pedonale"),
        ]
        for (check, word, what) in cases {
            XCTAssertEqual(check.word, word, what)
            XCTAssertEqual(check.callout, word.title, what)
            let a = Home2Answer(check, now: Date())
            XCTAssertEqual(a.headline, word.title, what)
            XCTAssertTrue(Self.titles.contains(a.headline), "\(what): «\(a.headline)» non è un titolo fisso")
            if let d = a.detail { XCTAssertFalse(Self.titles.contains(d), "\(what): la spiegazione non è un titolo") }
        }
        // Le altre forme sono spiegazione, mai titolo
        XCTAssertEqual(pc(zone, answer(cond)).explanation, "Solo con il ticket.")
        XCTAssertEqual(pc(zone, answer(unsure)).explanation, "Festivo da confermare.")
        XCTAssertEqual(pc(unofficialZone, answer(yes)).explanation, L("Probably yes · unofficial source"))
        XCTAssertEqual(pc(unofficialZone, answer(no)).explanation, L("Probably not · unofficial source"))
        XCTAssertNil(pc(zone, answer(yes)).explanation)
    }

    /// Il riquadro della mappa e il widget usano lo stesso titolo; le notifiche «Titolo · zona»
    func testWidgetAndNotificationsUseTheFixedTitle() {
        XCTAssertEqual(Access.closed.title, AnswerWord.dontEnter.title)
        XCTAssertEqual(Access.conditional.title, AnswerWord.condition.title)
        XCTAssertEqual(Access.check.title, AnswerWord.checkSign.title)
        XCTAssertEqual(Access.open.title, AnswerWord.enter.title)
    }

    // MARK: Le traduzioni dei titoli in tutte le lingue

    private func strings(_ lang: String) throws -> [String: String] {
        let url = Self.root.appendingPathComponent("Resources/Localizations/\(lang).lproj/Localizable.strings")
        return try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String], lang)
    }

    /// In ogni lingua i cinque titoli ci sono, sono diversi tra loro, e la versione in righe dice le stesse parole
    func testTitlesExistInEveryLanguageAndLinesMatch() throws {
        func squash(_ s: String) -> String { s.replacingOccurrences(of: "|", with: "").replacingOccurrences(of: " ", with: "") }
        for lang in ["it", "de", "fr", "es", "nl", "pl", "zh-Hans"] {
            let t = try strings(lang)
            var seen = Set<String>()
            for w in AnswerWord.allCases {
                let title = try XCTUnwrap(t[w.key], "\(lang): manca «\(w.key)»")
                let lines = try XCTUnwrap(t[w.lineKey], "\(lang): manca «\(w.lineKey)»")
                XCTAssertEqual(squash(lines), squash(title), "\(lang): «\(lines)» non dice «\(title)»")
                XCTAssertTrue(seen.insert(title).inserted, "\(lang): titolo ripetuto «\(title)»")
            }
        }
        XCTAssertEqual(try strings("it")["Don't enter"], "Non entrare")
        XCTAssertEqual(try strings("it")["You can enter"], "Puoi entrare")
        XCTAssertEqual(try strings("it")["On one condition"], "A una condizione")
        XCTAssertEqual(try strings("it")["Check the sign"], "Controlla il cartello")
    }

    /// 10. Le lingue più lunghe (tedesco e polacco): i titoli nelle pillole (12 pt) stanno su una riga in 170 pt e ogni
    /// riga del titolo grande (36 pt) in 300 pt (lo spazio accanto al simbolo su un iPhone piccolo)
    func testLongLanguagesFit() throws {
        let pill = UIFont.systemFont(ofSize: 12, weight: .semibold), big = UIFont.systemFont(ofSize: 36, weight: .bold)
        func width(_ s: String, _ f: UIFont) -> CGFloat { (s as NSString).size(withAttributes: [.font: f]).width }
        for lang in ["de", "pl"] {
            let t = try strings(lang)
            for w in AnswerWord.allCases {
                let title = try XCTUnwrap(t[w.key])
                XCTAssertLessThan(width(title, pill), 170, "\(lang): pillola «\(title)» troppo lunga")
                for line in try XCTUnwrap(t[w.lineKey]).components(separatedBy: "|") {
                    XCTAssertLessThan(width(line, big), 300, "\(lang): riga «\(line)» troppo lunga")
                }
            }
            for k in ["ZTL with pass", "Green zone"] {
                XCTAssertLessThan(width(try XCTUnwrap(t[k]), pill), 170, "\(lang): «\(k)»")
            }
        }
    }

    // MARK: Pillole neutre

    func testZoneKindPillsAreNeutral() {
        XCTAssertEqual(ZoneKind.restricted.title, "ZTL")
        XCTAssertEqual(ZoneKind.pass.title, L("ZTL with pass"))
        XCTAssertEqual(ZoneKind.green.title, L("Green zone"))
        for k in ZoneKind.allCases {
            XCTAssertFalse(Self.titles.contains(k.title), "la pillola del tipo non è una risposta")
            XCTAssertNotEqual(k.title, L("No entry"))
            XCTAssertNotEqual(k.title, L("Pass needed"))
        }
    }

    // MARK: Dati delle città: italiano + inglese dove manca la lingua

    func testCityDataFallsBackToItalianAndEnglish() {
        let en = "Sector A · Historic Centre", it = "Settore A · Centro storico", de = "Sektor A · Altstadt"
        XCTAssertEqual(pick(en, it: it, de: de, language: "en"), en)
        XCTAssertEqual(pick(en, it: it, de: de, language: "it"), it)
        XCTAssertEqual(pick(en, it: it, de: de, language: "de"), de)
        for lang in ["fr", "es", "nl", "pl", "zh"] {
            XCTAssertEqual(pick(en, it: it, de: de, language: lang), "Settore A · Centro storico (Sector A · Historic Centre)", lang)
            XCTAssertEqual(pick("Buy it online.", it: "Si compra online.", de: nil, fallback: .italianAndEnglish(long: true), language: lang),
                           "Si compra online.\n\nBuy it online.", lang)
            XCTAssertEqual(pick("Florence", it: "Firenze", de: "Florenz", fallback: .english, language: lang), "Florence", "nomi delle città")
            XCTAssertEqual(pick(en, it: nil, de: nil, language: lang), en, "senza italiano resta l'inglese")
            XCTAssertEqual(pick("ZTL", it: "ZTL", de: nil, language: lang), "ZTL", "uguali: una volta sola")
            XCTAssertEqual(pickList(["Hours"], it: ["Orari"], de: nil, language: lang), ["Orari\nHours"])
        }
        XCTAssertEqual(pick(en, it: nil, de: nil, language: "de"), en, "tedesco senza traduzione: inglese, come prima")
    }

    // MARK: Unità e frecce

    func testSpeedFollowsTheLocale() {
        let us = Locale(identifier: "en_US"), it = Locale(identifier: "it_IT")
        XCTAssertEqual(DriveView.speed(100, locale: us).unit, UnitSpeed.milesPerHour)
        XCTAssertEqual(DriveView.speedValue(100, locale: us), "62")
        XCTAssertEqual(DriveView.speed(100, locale: it).unit, UnitSpeed.kilometersPerHour)
        XCTAssertEqual(DriveView.speedValue(50, locale: it), "50")
        XCTAssertFalse(DriveView.unitText(locale: it).isEmpty)
        XCTAssertNotEqual(DriveView.unitText(locale: us), DriveView.unitText(locale: it))
    }

    func testManeuverArrowsFromGeometry() {
        let o = Coordinate(lat: 43.77, lon: 11.25)
        func go(_ from: Coordinate, north: Double = 0, east: Double = 0) -> Coordinate {
            Coordinate(lat: from.lat + north / 110_540, lon: from.lon + east / (111_320 * cos(from.lat * .pi / 180)))
        }
        let a = go(o, north: 200)                          // verso nord
        XCTAssertEqual(Maneuver.symbol(turn: Maneuver.turn(from: [o, a], into: [a, go(a, north: 200)])), "arrow.up")
        XCTAssertEqual(Maneuver.symbol(turn: Maneuver.turn(from: [o, a], into: [a, go(a, east: 200)])), "arrow.turn.up.right")
        XCTAssertEqual(Maneuver.symbol(turn: Maneuver.turn(from: [o, a], into: [a, go(a, east: -200)])), "arrow.turn.up.left")
        XCTAssertEqual(Maneuver.symbol(turn: Maneuver.turn(from: [o, a], into: [a, go(a, north: 150, east: 80)])), "arrow.up.right")
        XCTAssertEqual(Maneuver.symbol(turn: Maneuver.turn(from: [o, a], into: [a, go(a, north: -200, east: -5)])), "arrow.uturn.left")
        XCTAssertNil(Maneuver.turn(from: [o], into: [a]), "tratti senza lunghezza: nessuna svolta")
        XCTAssertEqual(Maneuver.symbol(turn: nil), "arrow.up")
    }

    // MARK: Segnala un errore

    func testReportHasNoEnglishTechnicalLines() {
        let r = ZoneReport(topic: .hours, note: "", cityId: "firenze", cityName: "Firenze", zoneId: "firenze-a",
                           zoneName: "Settore A", when: Date(timeIntervalSince1970: 0), vehicle: "Fiat 500", appVersion: "1.20.3 (56)",
                           system: "18.1", language: "it")
        for prefix in ["What: hours", "City: Firenze (firenze)", "Date/time:", "App: ", "iOS: ", "Lang: "] {
            XCTAssertFalse(r.body.contains(prefix), prefix)
        }
        XCTAssertEqual(r.context.last, String(format: L("Ref.: %@"), "hours · firenze · firenze-a · 1.20.3 (56) · iOS 18.1 · it"))
    }
}
