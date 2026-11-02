import XCTest
import UIKit

/// 1.19.2: il cartello mai verde e letto meglio (parole intere, «feriali e festivi», «festivi»), il verbale giallo sui dati
/// non rivisti e la bozza al condizionale con appunti solo locali, i permessi solo per una zona e con il dialogo.
final class TrustFixTests: XCTestCase {
    private let cal = RuleEngine.rome
    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    private func firenze() throws -> City {
        try CityLoader.decode(Data(contentsOf: Self.root.appendingPathComponent("Resources/Cities/firenze.json")))
    }

    // Giorni di prova (ora di Roma): lunedì 26/10/2026, domenica 25/10/2026, martedì 8/12/2026 (Immacolata),
    // martedì 2/6/2026 (Festa della Repubblica), mercoledì 9/12/2026
    private var monday: Date { date(2026, 10, 26, 12) }
    private var sunday: Date { date(2026, 10, 25, 12) }
    private var immacolata: Date { date(2026, 12, 8, 12) }

    // MARK: Cartello: giorni come parole intere

    func testWeekdaysAreWholeWords() {
        // Prima «\bmer» trovava «merci», «\bmar» «marzo», «\bgio» «giorni»: un cartello merci diventava «solo mercoledì»
        XCTAssertNil(SignReader.days(in: "carico e scarico merci"))
        XCTAssertNil(SignReader.days(in: "dal 1 marzo al 31 ottobre"))
        XCTAssertNil(SignReader.days(in: "nei giorni di mercato"))
        XCTAssertNil(SignReader.days(in: "domani"))
        XCTAssertNil(SignReader.days(in: "venti minuti"))
        XCTAssertEqual(SignReader.days(in: "lun-ven"), [2, 3, 4, 5, 6])
        XCTAssertEqual(SignReader.days(in: "lunedì - sabato"), [2, 3, 4, 5, 6, 7])
        XCTAssertEqual(SignReader.days(in: "da lunedì a venerdì"), [2, 3, 4, 5, 6])
        XCTAssertEqual(SignReader.days(in: "dal lun. al sab."), [2, 3, 4, 5, 6, 7])
        XCTAssertEqual(SignReader.days(in: "mar gio sab"), [3, 5, 7])
        XCTAssertEqual(SignReader.days(in: "sabato e domenica"), [7, 1])
        XCTAssertEqual(SignReader.days(in: "ven-dom"), [6, 7, 1])
        XCTAssertEqual(SignReader.days(in: "tutti i giorni"), SignReader.allDays)

        // Il cartello delle merci: la fascia vale tutti i giorni (prima solo il mercoledì → verde gli altri giorni)
        let merci = SignReader.parse("ZTL\nCARICO E SCARICO MERCI\nDALLE 6 ALLE 10")
        XCTAssertEqual(merci.rules.first?.days, SignReader.allDays)
        XCTAssertTrue(SignReader.isActive(merci, at: date(2026, 10, 26, 8), calendar: cal))
        // «dal 1 marzo»: non è il martedì
        let marzo = SignReader.parse("DAL 1 MARZO AL 31 OTTOBRE\n20.00-24.00")
        XCTAssertEqual(marzo.rules.first?.days, SignReader.allDays)
    }

    // MARK: Cartello: festivi

    /// «feriali e festivi» = tutti i giorni, domenica e festivi compresi (prima giorni 2…7: verde la domenica)
    func testFerialiEFestiviIsEveryDay() {
        let r = SignReader.parse("ZONA TRAFFICO LIMITATO\n0-24\nFERIALI E FESTIVI")
        XCTAssertEqual(r.rules.first?.days, SignReader.allDays)
        XCTAssertFalse(r.holidaysExcluded)
        XCTAssertTrue(r.holidaysIncluded)
        for d in [monday, sunday, immacolata, date(2026, 6, 2, 3)] {
            XCTAssertTrue(SignReader.isActive(r, at: d, calendar: cal), "\(d)")
        }
        let inverted = SignReader.parse("7.30-20.00 festivi e feriali")
        XCTAssertTrue(SignReader.isActive(inverted, at: sunday, calendar: cal))
    }

    /// «festivi» = le domeniche e i festivi nazionali (prima solo la domenica: verde a Natale di venerdì o l'8 dicembre)
    func testFestiviIsSundaysAndHolidays() {
        let r = SignReader.parse("ZTL\n10.00-18.00\nFESTIVI")
        XCTAssertEqual(r.rules.first?.days, [1])
        XCTAssertEqual(r.rules.first?.holidays, .asSunday)
        XCTAssertTrue(SignReader.isActive(r, at: sunday, calendar: cal))
        XCTAssertTrue(SignReader.isActive(r, at: immacolata, calendar: cal))
        XCTAssertTrue(SignReader.isActive(r, at: date(2026, 12, 25, 12), calendar: cal))     // Natale, venerdì
        XCTAssertTrue(SignReader.isActive(r, at: date(2026, 6, 2, 12), calendar: cal))       // 2 giugno, martedì
        XCTAssertFalse(SignReader.isActive(r, at: monday, calendar: cal))
        XCTAssertFalse(SignReader.isActive(r, at: date(2026, 12, 9, 12), calendar: cal))

        // «sabato e festivi»: il sabato, le domeniche e i festivi
        let s = SignReader.parse("SABATO E FESTIVI 20-24")
        XCTAssertEqual(s.rules.first?.days, [7, 1])
        XCTAssertTrue(SignReader.isActive(s, at: date(2026, 12, 8, 21), calendar: cal))
        XCTAssertFalse(SignReader.isActive(s, at: date(2026, 12, 9, 21), calendar: cal))

        // Notturna nei festivi: la notte dopo l'8 dicembre è ancora accesa all'una
        let night = SignReader.parse("FESTIVI 22-2")
        XCTAssertTrue(SignReader.isActive(night, at: date(2026, 12, 8, 23), calendar: cal))
        XCTAssertTrue(SignReader.isActive(night, at: date(2026, 12, 9, 1), calendar: cal))
        XCTAssertFalse(SignReader.isActive(night, at: date(2026, 12, 10, 1), calendar: cal))
    }

    /// «feriali» = da lunedì a sabato, non nei festivi (questo era già giusto e resta così)
    func testFerialiExcludesHolidays() {
        let r = SignReader.parse("7.30-20.00\nFERIALI")
        XCTAssertEqual(r.rules.first?.days, [2, 3, 4, 5, 6, 7])
        XCTAssertTrue(r.holidaysExcluded)
        XCTAssertTrue(SignReader.isActive(r, at: monday, calendar: cal))
        XCTAssertFalse(SignReader.isActive(r, at: sunday, calendar: cal))
        XCTAssertFalse(SignReader.isActive(r, at: immacolata, calendar: cal))

        // Due fasce sullo stesso pannello: nei festivi vale quella dei festivi
        let two = SignReader.parse("7.30-20.00 FERIALI\n10.00-18.00 FESTIVI")
        XCTAssertFalse(two.holidaysExcluded)
        XCTAssertFalse(SignReader.isActive(two, at: date(2026, 12, 8, 8), calendar: cal))
        XCTAssertTrue(SignReader.isActive(two, at: date(2026, 12, 8, 12), calendar: cal))
        XCTAssertTrue(SignReader.isActive(two, at: date(2026, 10, 26, 8), calendar: cal))

        // Il pannello scritto per esteso con «escluso festivi» su un'altra riga
        let long = SignReader.parse("ZONA TRAFFICO LIMITATO\nDAL LUNEDÌ AL SABATO\n7,30 - 20,00\nESCLUSO FESTIVI")
        XCTAssertEqual(long.rules.first?.days, [2, 3, 4, 5, 6, 7])
        XCTAssertTrue(long.holidaysExcluded)
        XCTAssertTrue(SignReader.isActive(long, at: date(2026, 10, 31, 10), calendar: cal))   // sabato
        XCTAssertFalse(SignReader.isActive(long, at: immacolata, calendar: cal))

        // Senza parole sui festivi la fascia resta accesa anche nel festivo (prudente)
        let plain = SignReader.parse("LUN-SAB 8-20")
        XCTAssertTrue(SignReader.isActive(plain, at: immacolata, calendar: cal))
    }

    // MARK: Cartello: mai verde

    func testSignReadingIsNeverGreen() {
        XCTAssertEqual(SignReader.reading(SignReader.parse("Benvenuti a Firenze"), at: monday, calendar: cal), .unreadable)
        XCTAssertEqual(SignReader.reading(SignReader.parse(""), at: monday, calendar: cal), .unreadable)
        let r = SignReader.parse("7.30-20.00\nFERIALI")
        XCTAssertEqual(SignReader.reading(r, at: monday, calendar: cal), .active)
        // Spenta secondo il cartello: il meglio è «sembra spenta» (giallo con il «?»), non «puoi entrare»
        XCTAssertEqual(SignReader.reading(r, at: sunday, calendar: cal), .seemsOff)
        XCTAssertEqual(SignReader.reading(r, at: date(2026, 10, 26, 22), calendar: cal), .seemsOff)
    }

    // MARK: Verbale

    private func zone(reviewed: Bool, official: Bool = true) throws -> Zone {
        var z = try XCTUnwrap(try firenze().zones.first { $0.id == "firenze-b" })
        z.source.reviewedByHuman = reviewed
        z.source.official = official
        z.freeOnHolidays = false
        return z
    }

    private func engine(daysAfterCheck days: Int, of z: Zone) -> RuleEngine {
        var e = RuleEngine()
        let now = cal.date(byAdding: .day, value: days, to: z.source.checkedOn)!
        e.now = { now }
        return e
    }

    /// «Non attivo» è verde solo con dati ufficiali, recenti e rivisti; altrimenti giallo con il «?»
    func testFineStatusNeverGreenOnUnreviewedData() throws {
        let unreviewed = try zone(reviewed: false)
        XCTAssertEqual(FineCheck.shown(.inactive, zone: unreviewed, engine: engine(daysAfterCheck: 10, of: unreviewed)), .probablyInactive)
        let reviewed = try zone(reviewed: true)
        XCTAssertEqual(FineCheck.shown(.inactive, zone: reviewed, engine: engine(daysAfterCheck: 10, of: reviewed)), .inactive)
        XCTAssertEqual(FineCheck.shown(.inactive, zone: reviewed, engine: engine(daysAfterCheck: 200, of: reviewed)), .unknownData)
        let unofficial = try zone(reviewed: true, official: false)
        XCTAssertEqual(FineCheck.shown(.inactive, zone: unofficial, engine: engine(daysAfterCheck: 10, of: unofficial)), .unknownData)
        XCTAssertEqual(FineCheck.shown(.active, zone: unreviewed, engine: engine(daysAfterCheck: 10, of: unreviewed)), .active)
        XCTAssertEqual(FineCheck.shown(.unsure, zone: unreviewed, engine: engine(daysAfterCheck: 10, of: unreviewed)), .unsure)
        // Con i dati veri di oggi: nessuna zona di Firenze è rivista da una persona → mai verde
        let e = engine(daysAfterCheck: 5, of: unreviewed)
        for z in try firenze().zones {
            XCTAssertNotEqual(FineCheck.shown(.inactive, zone: z, engine: e), .inactive, z.id)
        }
    }

    /// Gli orari si contano al giorno e all'ora del verbale, non a oggi: il Settore F di Firenze (notti d'estate, da aprile
    /// a inizio ottobre) è acceso un venerdì di luglio alle 23:30 e spento lo stesso giorno della settimana a novembre;
    /// una violazione lontana più di 120 giorni dalla lettura dei dati non si dice «non attiva»
    func testFineStatusAtTheNoticeDate() throws {
        let f = try XCTUnwrap(try firenze().zones.first { $0.id == "firenze-f" })
        XCTAssertEqual(FineCheck.status(f, at: date(2026, 7, 3, 23, 30)), .active)       // venerdì d'estate
        XCTAssertEqual(FineCheck.status(f, at: date(2026, 7, 4, 1, 30)), .active)        // la notte dopo
        XCTAssertEqual(FineCheck.status(f, at: date(2026, 11, 6, 23, 30)), .inactive)    // venerdì di novembre
        XCTAssertEqual(FineCheck.status(f, at: date(2026, 7, 1, 23, 30)), .inactive)     // mercoledì d'estate

        let b = try zone(reviewed: true)
        let e = engine(daysAfterCheck: 10, of: b)
        let near = cal.date(byAdding: .day, value: -30, to: b.source.checkedOn)!
        let far = cal.date(byAdding: .day, value: -300, to: b.source.checkedOn)!
        XCTAssertTrue(FineCheck.dataIsReliable(b, engine: e, violation: near))
        XCTAssertFalse(FineCheck.dataIsReliable(b, engine: e, violation: far))
        XCTAssertEqual(FineCheck.shown(.inactive, zone: b, engine: e, violation: near), .inactive)
        XCTAssertEqual(FineCheck.shown(.inactive, zone: b, engine: e, violation: far), .unknownData)
    }

    /// La bozza: al condizionale con la data della lettura; con dati vecchi o non ufficiali nessun motivo dagli orari
    func testAppealDraftIsConditional() throws {
        var n = FineReader.Notice()
        n.violation = date(2026, 3, 12, 21)
        n.violationHasTime = true
        n.plate = "GX482KM"
        let url = URL(string: "https://www.comune.firenze.it/ztl")!
        let checked = date(2026, 10, 23, 12)
        let ok = FineCheck.appealDraft(n, city: "Firenze", zone: "Settore B", status: .inactive, source: url,
                                       checkedOn: checked, reliable: true)
        for part in ["Secondo i dati disponibili", "non risulterebbe attiva", "consultati il 23/10/2026", "si chiede di verificare"] {
            XCTAssertTrue(ok.contains(part), part)
        }
        for claim in ["non risultava attiva", "non era attiva"] { XCTAssertFalse(ok.contains(claim), claim) }

        let old = FineCheck.appealDraft(n, city: "Firenze", zone: "Settore B", status: .inactive, source: url,
                                        checkedOn: checked, reliable: false)
        XCTAssertFalse(old.contains("risulterebbe"))
        XCTAssertTrue(old.contains("[Verificare sul sito del Comune"))
        XCTAssertFalse(old.contains("non risultava attiva"))
    }

    /// Gli appunti (bozza del ricorso e messaggio per l'hotel): solo su questo iPhone (niente Appunti universali) e con una scadenza di 10 minuti
    func testAppealCopyIsLocalOnly() {
        let now = date(2026, 11, 2, 10)
        let o = LocalClipboard.options(now: now)
        XCTAssertEqual(o[.localOnly] as? Bool, true)
        XCTAssertEqual(o[.expirationDate] as? Date, now.addingTimeInterval(600))
        let board = UIPasteboard(name: UIPasteboard.Name("it.ledion.GateLR.tests"), create: true)!
        LocalClipboard.copy("BOZZA GX482KM", to: board, now: Date())
        XCTAssertEqual(board.string, "BOZZA GX482KM")
        UIPasteboard.remove(withName: board.name)
    }

    // MARK: Permessi

    func testPermitCountsOnlyInItsZone() throws {
        let city = try firenze()
        let a = try XCTUnwrap(city.zones.first { $0.id == "firenze-a" })
        let b = try XCTUnwrap(city.zones.first { $0.id == "firenze-b" })
        let car = SampleData.rental
        var e = RuleEngine()
        let today = date(2026, 10, 30, 12)
        e.now = { today }
        let tuesday = date(2026, 11, 3, 10)        // Settore A e B accesi
        let from = date(2026, 11, 1, 0), to = date(2026, 11, 5, 23, 59)

        // Senza zona (permessi salvati fino alla 1.19.1): non vale da nessuna parte
        let global = Permit(kind: .hotelRegistration, cityId: "firenze", zoneId: nil, vehicleId: car.id, from: from, to: to, status: .confirmed)
        XCTAssertTrue(global.needsZone)
        XCTAssertFalse(global.covers(zone: a, vehicle: car, at: tuesday))
        XCTAssertEqual(e.answer(zone: a, vehicle: car, permits: [global], hotelInside: false, at: tuesday).verdict.severity, 3)

        // Con la zona: vale solo lì
        var scoped = global
        scoped.zoneId = "firenze-a"
        XCTAssertTrue(scoped.covers(zone: a, vehicle: car, at: tuesday))
        XCTAssertFalse(scoped.covers(zone: b, vehicle: car, at: tuesday))
        XCTAssertTrue(e.answer(zone: a, vehicle: car, permits: [scoped], hotelInside: false, at: tuesday).verdict.isYes)
        XCTAssertEqual(e.answer(zone: b, vehicle: car, permits: [scoped], hotelInside: false, at: tuesday).verdict.severity, 3)

        // In attesa: giallo solo nella sua zona
        scoped.status = .waiting
        XCTAssertEqual(e.answer(zone: a, vehicle: car, permits: [scoped], hotelInside: false, at: tuesday).verdict.severity, 2)
        // Un altro veicolo o fuori dai giorni: niente
        XCTAssertFalse(scoped.covers(zone: a, vehicle: Vehicle(name: "Altra", fuel: .petrol, euro: 6), at: tuesday))
        XCTAssertFalse(scoped.covers(zone: a, vehicle: car, at: date(2026, 11, 7, 10)))
    }

    /// Il dialogo serve quando il permesso spinge la risposta verso il «sì» (nuovo, in attesa → confermato), non indietro
    func testPermitConsent() {
        XCTAssertTrue(Permit.Status.needsConsent(from: nil, to: .waiting))
        XCTAssertTrue(Permit.Status.needsConsent(from: nil, to: .confirmed))
        XCTAssertTrue(Permit.Status.needsConsent(from: .waiting, to: .confirmed))
        XCTAssertFalse(Permit.Status.needsConsent(from: .confirmed, to: .waiting))
        XCTAssertFalse(Permit.Status.needsConsent(from: .waiting, to: nil))
        XCTAssertFalse(Permit.Status.needsConsent(from: .waiting, to: .waiting))
        // Il soggiorno in hotel: «Chiesto» e «Confermato» chiedono conferma, «Non chiesto» no
        XCTAssertTrue(Permit.Status.needsConsent(from: HotelStay.Status.notAsked.permitStatus, to: HotelStay.Status.asked.permitStatus))
        XCTAssertTrue(Permit.Status.needsConsent(from: HotelStay.Status.asked.permitStatus, to: HotelStay.Status.confirmed.permitStatus))
        XCTAssertFalse(Permit.Status.needsConsent(from: HotelStay.Status.confirmed.permitStatus, to: HotelStay.Status.notAsked.permitStatus))
    }
}
