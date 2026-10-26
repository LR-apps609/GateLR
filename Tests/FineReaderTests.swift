import XCTest

/// «Fotografa il verbale»: testi di verbali di Firenze, Roma, Milano, Bologna e Pisa come li legge una foto,
/// il confronto con i nostri varchi e orari, le scadenze e la bozza del ricorso
final class FineReaderTests: XCTestCase {
    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    private static let cities: [City] = ["firenze", "roma", "milano", "bologna", "pisa"].compactMap { id in
        try? CityLoader.decode(Data(contentsOf: root.appendingPathComponent("Resources/Cities/\(id).json")))
    }
    private let cal = RuleEngine.rome

    private func day(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    private func read(_ text: String) -> FineReader.Notice { FineReader.parse(text, thisYear: 2026) }

    func testCitiesAreReadable() {
        XCTAssertEqual(Self.cities.count, 5)
    }

    func testFirenzeSettoreB() {
        let text = #"""
        COMUNE DI FIRENZE
        DIREZIONE POLIZIA MUNICIPALE
        VERBALE DI ACCERTAMENTO DI VIOLAZIONE N. 2026/F/0123456 DEL 20/03/2026
        Il giorno 12/03/2026 alle ore 10:32 il veicolo targato GX482KM
        transitava attraverso il varco elettronico di accesso alla ZTL Settore B situato in Via Cavour
        senza autorizzazione, in violazione dell'art. 7 comma 9 e 14 del C.d.S.
        Importo della sanzione € 83,00
        Spese di procedimento e notifica € 14,95
        Pagamento entro 5 giorni dalla notifica: € 72,05
        Totale da pagare entro 60 giorni dalla notifica € 97,95
        Notificato il 02/04/2026
        """#
        let n = read(text)
        XCTAssertEqual(n.violation, day(2026, 3, 12, 10, 32))
        XCTAssertTrue(n.violationHasTime)
        XCTAssertEqual(n.city, "Firenze")
        XCTAssertEqual(n.place, "Via Cavour")
        XCTAssertEqual(n.amount ?? 0, 97.95, accuracy: 0.001)
        XCTAssertEqual(n.reducedAmount ?? 0, 72.05, accuracy: 0.001)
        XCTAssertEqual(n.noticeDate, day(2026, 3, 20))
        XCTAssertEqual(n.notificationDate, day(2026, 4, 2))
        XCTAssertEqual(n.article, 7)
        XCTAssertEqual(n.articleText, "art. 7, c. 9 e 14 C.d.S.")
        XCTAssertEqual(n.number, "2026/F/0123456")
        XCTAssertEqual(n.plate, "GX482KM")
        let match = FineCheck.match(n, text: text, cities: Self.cities)
        XCTAssertEqual(match?.city.id, "firenze")
        XCTAssertEqual(match?.zone?.id, "firenze-b")
        XCTAssertEqual(match?.gate?.name, "Via Cavour")
    }

    func testFirenzeNoisyColumns() {
        let text = #"""
        C0MUNE DI FIRENZE   Verbale N. 2026/F/0099887
        Polizia Municipale
        Data e ora violazione: 03/11/2025 - 08:05:41
        Varco n. 12 - VIA GUELFA   Direzione: centro
        Veicolo targato AB 123 CD
        Art. 7, c. 9 e 14 Cod. della Strada
        Importo € 83,00 - Pagamento ridotto entro 5 gg € 58,10
        Data di consegna 15/12/2025
        """#
        let n = read(text)
        XCTAssertEqual(n.violation, day(2025, 11, 3, 8, 5))
        XCTAssertTrue(n.violationHasTime)
        XCTAssertEqual(n.city, "Firenze")
        XCTAssertEqual(n.place, "Via Guelfa")
        XCTAssertEqual(n.amount ?? 0, 83.0, accuracy: 0.001)
        XCTAssertEqual(n.reducedAmount ?? 0, 58.1, accuracy: 0.001)
        XCTAssertEqual(n.noticeDate, nil)
        XCTAssertEqual(n.notificationDate, day(2025, 12, 15))
        XCTAssertEqual(n.article, 7)
        XCTAssertEqual(n.articleText, "art. 7, c. 9 e 14 C.d.S.")
        XCTAssertEqual(n.number, "2026/F/0099887")
        XCTAssertEqual(n.plate, "AB123CD")
        let match = FineCheck.match(n, text: text, cities: Self.cities)
        XCTAssertEqual(match?.city.id, "firenze")
        XCTAssertEqual(match?.zone?.id, "firenze-b")
        XCTAssertEqual(match?.gate?.name, "Via Guelfa")
    }

    func testRomaTridente() {
        let text = #"""
        ROMA CAPITALE
        Polizia Locale di Roma Capitale - Gruppo I Centro
        VERBALE DI CONTESTAZIONE N° 14/0005678/2026
        Data violazione: 07/03/2026   Ora: 09:15
        Luogo: Varco ZTL Tridente - Via del Babuino
        Veicolo: autovettura targa AB-123-CD (F)
        Violazione: art. 7 c. 9 e 14 C.d.S. - transito in ZTL senza autorizzazione
        Importo minimo: Euro 83,00
        Data di notifica: 28/04/2026
        """#
        let n = read(text)
        XCTAssertEqual(n.violation, day(2026, 3, 7, 9, 15))
        XCTAssertTrue(n.violationHasTime)
        XCTAssertEqual(n.city, "Roma")
        XCTAssertEqual(n.place, "Tridente - Via del Babuino")
        XCTAssertEqual(n.amount ?? 0, 83.0, accuracy: 0.001)
        XCTAssertEqual(n.reducedAmount, nil)
        XCTAssertEqual(n.noticeDate, nil)
        XCTAssertEqual(n.notificationDate, day(2026, 4, 28))
        XCTAssertEqual(n.article, 7)
        XCTAssertEqual(n.articleText, "art. 7, c. 9 e 14 C.d.S.")
        XCTAssertEqual(n.number, "14/0005678/2026")
        XCTAssertEqual(n.plate, "AB-123-CD")
        let match = FineCheck.match(n, text: text, cities: Self.cities)
        XCTAssertEqual(match?.city.id, "roma")
        XCTAssertEqual(match?.zone?.id, "roma-tridente")
        XCTAssertEqual(match?.gate?.name, "Varco ZTL Tridente")
    }

    func testMilanoAreaC() {
        let text = #"""
        COMUNE DI MILANO
        POLIZIA LOCALE
        Verbale n. 2026/AC/778899
        In data 10/02/2026 alle ore 19.45 in Milano, Corso di Porta Romana
        varco Area C n. 27 Porta Romana, il veicolo targato FA 300 XY
        accedeva alla ZTL "Area C" senza aver attivato il ticket (art. 7 comma 9 e 14 C.d.S.)
        Sanzione: € 83,00
        Spese di notifica: € 12,50
        Totale: € 95,50
        Ridotto del 30% se pagato entro 5 giorni: € 70,60
        """#
        let n = read(text)
        XCTAssertEqual(n.violation, day(2026, 2, 10, 19, 45))
        XCTAssertTrue(n.violationHasTime)
        XCTAssertEqual(n.city, "Milano")
        XCTAssertEqual(n.place, "Area C N. 27 Porta Romana")
        XCTAssertEqual(n.amount ?? 0, 95.5, accuracy: 0.001)
        XCTAssertEqual(n.reducedAmount ?? 0, 70.6, accuracy: 0.001)
        XCTAssertEqual(n.noticeDate, nil)
        XCTAssertEqual(n.notificationDate, nil)
        XCTAssertEqual(n.article, 7)
        XCTAssertEqual(n.articleText, "art. 7, c. 9 e 14 C.d.S.")
        XCTAssertEqual(n.number, "2026/AC/778899")
        XCTAssertEqual(n.plate, "FA300XY")
        let match = FineCheck.match(n, text: text, cities: Self.cities)
        XCTAssertEqual(match?.city.id, "milano")
        XCTAssertEqual(match?.zone?.id, "milano-c")
        XCTAssertEqual(match?.gate?.name, "Porta Romana")
    }

    func testBolognaMarconi() {
        let text = #"""
        COMUNE DI BOLOGNA - CORPO DI POLIZIA LOCALE
        AVVISO DI ACCERTAMENTO DI VIOLAZIONE
        Verbale nr. 0045123/2026 redatto il 05/05/2026
        Violazione accertata il giorno 19/04/2026 ore 08:30
        Luogo della violazione: BOLOGNA, VIA MARCONI (varco ZTL Marconi)
        Art. 7 C.d.S. commi 9 e 14
        Importo: 83,00 euro
        Data notifica 20/05/2026
        """#
        let n = read(text)
        XCTAssertEqual(n.violation, day(2026, 4, 19, 8, 30))
        XCTAssertTrue(n.violationHasTime)
        XCTAssertEqual(n.city, "Bologna")
        XCTAssertEqual(n.place, "Marconi")
        XCTAssertEqual(n.amount ?? 0, 83.0, accuracy: 0.001)
        XCTAssertEqual(n.reducedAmount, nil)
        XCTAssertEqual(n.noticeDate, day(2026, 5, 5))
        XCTAssertEqual(n.notificationDate, day(2026, 5, 20))
        XCTAssertEqual(n.article, 7)
        XCTAssertEqual(n.articleText, "art. 7 C.d.S.")
        XCTAssertEqual(n.number, "0045123/2026")
        XCTAssertEqual(n.plate, nil)
        let match = FineCheck.match(n, text: text, cities: Self.cities)
        XCTAssertEqual(match?.city.id, "bologna")
        XCTAssertEqual(match?.zone?.id, "bologna-ztl")
        XCTAssertEqual(match?.gate?.name, "Marconi")
    }

    func testPisaTextualDate() {
        let text = #"""
        Comune di Pisa
        Polizia Municipale
        Verbale di accertamento n. P/2026/004567
        Il giorno 14 marzo 2026 alle ore 23,10 il conducente del veicolo targa CZ 512 PL
        transitava in Via San Lorenzo, accesso alla Zona a Traffico Limitato, senza titolo autorizzativo
        (art. 7, comma 9, C.d.S.)
        Sanzione amministrativa pecuniaria € 83,00
        Pisa, lì 30/03/2026
        """#
        let n = read(text)
        XCTAssertEqual(n.violation, day(2026, 3, 14, 23, 10))
        XCTAssertTrue(n.violationHasTime)
        XCTAssertEqual(n.city, "Pisa")
        XCTAssertEqual(n.place, "Via San Lorenzo")
        XCTAssertEqual(n.amount ?? 0, 83.0, accuracy: 0.001)
        XCTAssertEqual(n.reducedAmount, nil)
        XCTAssertEqual(n.noticeDate, day(2026, 3, 30))
        XCTAssertEqual(n.notificationDate, nil)
        XCTAssertEqual(n.article, 7)
        XCTAssertEqual(n.articleText, "art. 7, c. 9 C.d.S.")
        XCTAssertEqual(n.number, "P/2026/004567")
        XCTAssertEqual(n.plate, "CZ512PL")
        let match = FineCheck.match(n, text: text, cities: Self.cities)
        XCTAssertEqual(match?.city.id, "pisa")
        XCTAssertEqual(match?.zone?.id, nil)
        XCTAssertEqual(match?.gate?.name, nil)
    }

    func testTimeBeforeDate() {
        let text = #"""
        Violazione accertata alle ore 17:45 del 02/02/2026 in Via Indipendenza
        """#
        let n = read(text)
        XCTAssertEqual(n.violation, day(2026, 2, 2, 17, 45))
        XCTAssertTrue(n.violationHasTime)
        XCTAssertEqual(n.city, nil)
        XCTAssertEqual(n.place, "Via Indipendenza")
        XCTAssertEqual(n.amount, nil)
        XCTAssertEqual(n.reducedAmount, nil)
        XCTAssertEqual(n.noticeDate, nil)
        XCTAssertEqual(n.notificationDate, nil)
        XCTAssertEqual(n.article, nil)
        XCTAssertEqual(n.articleText, nil)
        XCTAssertEqual(n.number, nil)
        XCTAssertEqual(n.plate, nil)
    }

    /// Il motore delle regole sugli orari: attivo, non attivo, e «non si sa» nei festivi non confermati
    func testStatusFromTheTimetable() throws {
        var z = try XCTUnwrap(Self.cities.first { $0.id == "firenze" }?.zones.first { $0.id == "firenze-b" })
        z.windows = [TimeWindow(weekdays: [2, 3, 4, 5, 6], start: 450, end: 1200)]
        z.freeOnHolidays = false
        XCTAssertEqual(FineCheck.status(z, at: day(2026, 3, 12, 10, 32)), .active)
        XCTAssertEqual(FineCheck.status(z, at: day(2026, 3, 12, 21, 0)), .inactive)
        XCTAssertEqual(FineCheck.status(z, at: day(2026, 3, 14, 10, 0)), .inactive)      // sabato
        z.freeOnHolidays = nil
        XCTAssertEqual(FineCheck.status(z, at: day(2026, 4, 6, 10, 0)), .unsure)        // Pasquetta, festivi non confermati
        z.freeOnHolidays = true
        XCTAssertEqual(FineCheck.status(z, at: day(2026, 4, 6, 10, 0)), .inactive)
    }

    /// Con i dati veri: Firenze Settore B un giovedì mattina è attivo, il Tridente il sabato alle 9:15 non ancora
    func testStatusWithRealZones() throws {
        let b = try XCTUnwrap(Self.cities.first { $0.id == "firenze" }?.zones.first { $0.id == "firenze-b" })
        XCTAssertEqual(FineCheck.status(b, at: day(2026, 3, 12, 10, 32)), .active)
        let tridente = try XCTUnwrap(Self.cities.first { $0.id == "roma" }?.zones.first { $0.id == "roma-tridente" })
        XCTAssertEqual(FineCheck.status(tridente, at: day(2026, 3, 7, 9, 15)), .inactive)
    }

    /// Le scadenze dalla notifica: 5 giorni (−30%), 30 (Giudice di Pace), 60 (pagamento, Prefetto); 90 e 360 giorni per notificare
    func testDeadlines() {
        let d = FineCheck.deadlines(notifiedOn: day(2026, 4, 2, 15, 0))
        XCTAssertEqual(d.reduced, day(2026, 4, 7, 0))
        XCTAssertEqual(d.giudice, day(2026, 5, 2, 0))
        XCTAssertEqual(d.pay, day(2026, 6, 1, 0))
        XCTAssertEqual(d.prefetto, day(2026, 6, 1, 0))
        let limits = FineCheck.notificationLimits(violation: day(2026, 3, 12, 10, 32))
        XCTAssertEqual(limits.italy, day(2026, 6, 10, 0))
        XCTAssertEqual(limits.abroad, day(2027, 3, 7, 0))
    }

    /// La bozza del ricorso: segnata come bozza, con i dati letti, e il motivo degli orari solo se il varco risultava spento
    func testAppealDraft() {
        var n = FineReader.Notice()
        n.violation = day(2026, 3, 12, 10, 32)
        n.violationHasTime = true
        n.place = "Via Cavour"
        n.number = "2026/F/0123456"
        n.notificationDate = day(2026, 4, 2)
        n.articleText = "art. 7, c. 9 e 14 C.d.S."
        n.plate = "GX482KM"
        let url = URL(string: "https://www.comune.firenze.it/ztl")!
        let off = FineCheck.appealDraft(n, city: "Firenze", zone: "Settore B", status: .inactive, source: url)
        XCTAssertTrue(off.hasPrefix("BOZZA"))
        for part in ["Al Prefetto di Firenze", "n. 2026/F/0123456", "02/04/2026", "12/03/2026", "10:32", "Via Cavour, Settore B",
                     "GX482KM", "art. 7, c. 9 e 14 C.d.S.", "non risultava attiva", url.absoluteString] {
            XCTAssertTrue(off.contains(part), part)
        }
        let on = FineCheck.appealDraft(n, city: "Firenze", zone: nil, status: .active, source: url)
        XCTAssertFalse(on.contains("non risultava attiva"))
        XCTAssertTrue(on.contains("[Indicare i motivi"))
        let empty = FineCheck.appealDraft(FineReader.Notice(), city: nil, zone: nil, status: nil, source: nil)
        XCTAssertTrue(empty.contains("[Comune]"))
        XCTAssertTrue(empty.contains("[data di notifica]"))
    }

    func testReferencesAreOfficialLinks() {
        XCTAssertEqual(FineCheck.references.count, 5)
        for (_, url) in FineCheck.references { XCTAssertEqual(url.host, "www.normattiva.it") }
    }

    /// I nomi dei varchi: abbreviazioni sciolte, parole generiche tolte, una lettera sbagliata dalla foto va bene
    func testGateNameMatching() {
        XCTAssertEqual(FineCheck.tokens("P.zza Vittorio Veneto - L.no Vespucci"), ["VITTORIO", "VENETO", "VESPUCCI"])
        XCTAssertTrue(FineCheck.similar("CAVOUR", "CAV0UR"))
        XCTAssertFalse(FineCheck.similar("MARCO", "MARCONI"))
        let firenze = Self.cities.first { $0.id == "firenze" }
        XCTAssertEqual(firenze.flatMap { FineCheck.gate("VIA CAV0UR", in: $0) }?.zone.id, "firenze-b")
        XCTAssertNil(firenze.flatMap { FineCheck.gate("Via Inesistente", in: $0) })
    }

    func testUnreadableNotice() {
        XCTAssertFalse(read("hello world").understood)
    }
}
