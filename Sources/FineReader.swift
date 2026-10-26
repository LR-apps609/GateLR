import Foundation

/// «Fotografa il verbale»: dal testo di un verbale per ingresso in ZTL ricava data e ora della violazione,
/// varco o strada, Comune, importi, data del verbale e della notifica, articolo, numero e targa.
/// Niente fotocamera qui: si prova con i test sui testi di vari Comuni.
enum FineReader {
    struct Notice: Equatable {
        var violation: Date?
        var violationHasTime = false
        var place: String?
        var city: String?
        var amount: Double?
        var reducedAmount: Double?
        var noticeDate: Date?
        var notificationDate: Date?
        var article: Int?
        var articleText: String?
        var number: String?
        var plate: String?
        var understood: Bool { violation != nil || place != nil || city != nil || amount != nil || article != nil }
    }

    enum DateKind: Equatable { case violation, notification, notice, other }

    static func parse(_ raw: String, calendar: Calendar = RuleEngine.rome,
                      thisYear: Int = Calendar.current.component(.year, from: Date())) -> Notice {
        let t = DocumentText.fold(raw)
        let ns = t as NSString
        var n = Notice()

        // Le date, ognuna con il suo tipo (dalle parole subito prima) e l'ora vicina
        let hits = DocumentText.dates(in: t, thisYear: thisYear)
        let kinds = hits.map { kind(segment(before: $0.location, in: ns)) }
        let times = hits.map { time(near: $0, in: ns) }
        func pick(_ k: DateKind, needTime: Bool = false) -> Int? {
            hits.indices.first { kinds[$0] == k && (!needTime || times[$0] != nil) }
        }
        if let i = pick(.violation) ?? pick(.other, needTime: true) ?? pick(.other) {
            let h = hits[i]
            if let tm = times[i] {
                n.violation = DocumentText.date(h.year, h.month, h.day, tm.0, tm.1, calendar: calendar)
                n.violationHasTime = true
            } else {
                n.violation = DocumentText.date(h.year, h.month, h.day, 12, 0, calendar: calendar)
            }
        }
        if let i = pick(.notification) { n.notificationDate = DocumentText.date(hits[i].year, hits[i].month, hits[i].day, 12, 0, calendar: calendar) }
        if let i = pick(.notice) { n.noticeDate = DocumentText.date(hits[i].year, hits[i].month, hits[i].day, 12, 0, calendar: calendar) }

        n.city = city(in: t)
        let violationEnd = pick(.violation).map { hits[$0].end } ?? 0
        n.place = place(in: t, after: violationEnd)
        (n.amount, n.reducedAmount) = amounts(in: t)
        (n.article, n.articleText) = article(in: t)
        n.number = number(in: t)
        n.plate = plate(in: t)
        return n
    }

    // MARK: Date e ore

    /// Le parole subito prima della data, sulla stessa riga (o sulla riga sopra, se la data è da sola)
    static func segment(before location: Int, in ns: NSString) -> String {
        let start = max(0, location - 90)
        let before = ns.substring(with: NSRange(location: start, length: location - start))
        var lines = before.components(separatedBy: "\n")
        var seg = lines.removeLast()
        // Una colonna accanto (tre spazi): conta solo il pezzo vicino alla data
        if let r = seg.range(of: "   ", options: .backwards), DocumentText.contains("[A-Z]", in: String(seg[r.upperBound...])) {
            seg = String(seg[r.upperBound...])
        }
        if !DocumentText.contains("[A-Z]{2}", in: seg), let prev = lines.last { seg = prev + " " + seg }
        return seg
    }

    /// Il tipo di data dalla parola più vicina: notifica, verbale (redatto, emesso, «verbale n. … del»), violazione
    static func kind(_ seg: String) -> DateKind {
        func last(_ words: [String]) -> Int {
            words.compactMap { seg.range(of: $0, options: .backwards).map { seg.distance(from: seg.startIndex, to: $0.upperBound) } }.max() ?? -1
        }
        var notice = last(["REDATT", "EMESS", "EMISSIONE", "DATA VERBALE", "DATA DEL VERBALE", "STAMPA", "ELABORAT", " LI ", ", LI", "LI'"])
        if DocumentText.contains(#"(?:VERBALE|ATTO|AVVISO|PROT)[^\n]{0,80}(?<![A-Z])DEL\s*:?\s*$"#, in: seg) { notice = seg.count + 1 }
        let scores: [(DateKind, Int)] = [
            (.notification, last(["NOTIFIC", "CONSEGN", "RICEVUT", "RECAPIT", "PERFEZION", "RITIRAT"])),
            (.notice, notice),
            (.violation, last(["VIOLAZIONE", "ACCERTAT", "COMMESS", "RILEVAT", "TRANSIT", "INFRAZIONE", "DATA E ORA", "DATA/ORA", "ACCERTAMENTO"])),
        ]
        if let best = scores.filter({ $0.1 >= 0 }).max(by: { $0.1 < $1.1 }) { return best.0 }
        if DocumentText.contains(#"(?<![A-Z])(?:GIORNO|IN DATA|IL)\s*:?\s*$"#, in: seg) { return .violation }
        return .other
    }

    /// L'ora vicino alla data: «alle ore 10:32», «ora: 10.32», «- 10:32:15», o «ore 10:32 del» prima della data
    static func time(near hit: DocumentText.DateHit, in ns: NSString) -> (Int, Int)? {
        let after = ns.substring(with: NSRange(location: hit.end, length: min(45, ns.length - hit.end)))
        let before = ns.substring(with: NSRange(location: max(0, hit.location - 40), length: min(40, hit.location)))
        let patterns: [(String, String)] = [
            (after, #"^[^0-9]{0,30}?(?<![A-Z])(?:ORE|ORA|H)(?![A-Z])[^0-9]{0,15}?([0-2]?[0-9])\s?[:.,]\s?([0-5][0-9])"#),
            (after, #"^\s*[-,]?\s*([0-2]?[0-9]):([0-5][0-9])"#),
            (before, #"(?<![A-Z])(?:ORE|ORA)(?![A-Z])\s*:?\s*([0-2]?[0-9])\s?[:.,]\s?([0-5][0-9])[^0-9]{0,30}$"#),
        ]
        for (s, p) in patterns {
            if let m = DocumentText.first(p, in: s), let h = m.group(1).flatMap({ Int($0) }), let mi = m.group(2).flatMap({ Int($0) }), h < 24 {
                return (h, mi)
            }
        }
        return nil
    }

    // MARK: Comune

    static let cityStop = #"(?=\s{2,}|\s*[-,.(/;]|\s+(?:SETTORE|DIREZIONE|CORPO|COMANDO|UFFICIO|SERVIZIO|POLIZIA|AREA|DIPARTIMENTO|VIA|PIAZZA|SEZIONE|MOBILITA|U\.O|VERBALE|AVVISO|ATTO|ACCERTAMENTO|PROT|TEL|NOTIFICA|SEDE)(?![A-Z])|\s*$)"#

    /// «COMUNE DI FIRENZE», «ROMA CAPITALE», «POLIZIA LOCALE DI MILANO», «CITTÀ DI TORINO» → «Firenze», «Roma», …
    static func city(in t: String) -> String? {
        if DocumentText.containsWord("ROMA CAPITALE", in: t) { return "Roma" }
        let patterns = [
            #"(?<![A-Z])C[O0]MUNE\s+DI\s+([A-Z][A-Z' ]{1,30}?)"# + cityStop,
            #"POLIZIA\s+(?:MUNICIPALE|LOCALE)\s+(?:DEL\s+COMUNE\s+)?DI\s+([A-Z][A-Z' ]{1,30}?)"# + cityStop,
            #"(?<![A-Z])CITTA'?\s+(?:METROPOLITANA\s+)?DI\s+([A-Z][A-Z' ]{1,30}?)"# + cityStop,
        ]
        for p in patterns {
            if let v = DocumentText.first(p, in: t)?.group(1) {
                let name = DocumentText.trim(v, "'")
                if name.count >= 2 { return DocumentText.titled(name) }
            }
        }
        return nil
    }

    // MARK: Luogo

    static let streetWords = #"(?:VIA|VIALE|V\.LE|PIAZZA|PIAZZALE|P\.ZA|P\.ZZA|P\.LE|LUNGARNO|L\.NO|LUNGOTEVERE|CORSO|C\.SO|BORGO|B\.GO|LARGO|L\.GO|VICOLO|PONTE|PORTA|STRADA|SALITA)"#

    /// Il varco («Varco ZTL n. 5 - Via Guelfa»), il luogo («Luogo della violazione: …») o la prima strada dopo la data
    static func place(in t: String, after start: Int) -> String? {
        let varco = #"(?<![A-Z])VARCO(?:\s+(?:ZTL|Z\.T\.L\.?|ELETTRONICO|TELEMATICO|DI ACCESSO|D'ACCESSO|DI CONTROLLO|N\.?\s*[0-9]+|NR\.?\s*[0-9]+|NUMERO\s*[0-9]+))*\s*[:\-]?\s*([^\n]{3,90})"#
        let luogo = #"(?<![A-Z])(?:LUOGO(?:\s+DELLA\s+VIOLAZIONE|\s+DI\s+ACCERTAMENTO|\s+DELL'INFRAZIONE|\s+INFRAZIONE)?|LOCALITA'?)\s*:?\s*([^\n]{3,90})"#
        for p in [varco, luogo] {
            for m in DocumentText.matches(p, in: t) {
                if let v = m.group(1), let c = cleanPlace(v) { return c }
            }
        }
        let tail = DocumentText.substring(t, from: start, to: start + 260)
        if let v = DocumentText.first(#"(?<![A-Z])("# + streetWords + #"\s+[A-Z0-9'][A-Z0-9' .]{1,50})"#, in: tail)?.group(1), let c = cleanPlace(v) { return c }
        return nil
    }

    static func cleanPlace(_ raw: String) -> String? {
        var v = DocumentText.trim(raw, ".:-()")
        if let cut = DocumentText.first(#"\s{3,}|[,;]|\s+(?:ALLE|ORE|IL GIORNO|IN DATA|DEL GIORNO|DIREZIONE|IN DIR\.?|TARGA|VEICOLO|SENZA|NONOSTANTE|PER)(?![A-Z])|\s\("#, in: v) {
            v = DocumentText.substring(v, from: 0, to: cut.range.location)
        }
        v = DocumentText.trim(v, ".:-()")
        // «… alla ZTL Settore B situato in Via Cavour»: conta quello che viene dopo «situato in»
        if let m = DocumentText.first(#"(?<![A-Z])(?:SITUATO|UBICATO|SITO|POSTO|POSIZIONATO|COLLOCATO)\s+(?:IN\s+)?(.{3,})$"#, in: v), let after = m.group(1) {
            v = DocumentText.trim(after, ".:-")
        }
        if v.hasPrefix("ATTIVO") || v.hasPrefix("NON ATTIVO") { return nil }
        // «situato in», «ubicato in», «denominato», «n. 3 -»
        for _ in 0..<3 {
            if let m = DocumentText.first(#"^(?:N\.?\s*[0-9]+\s*[-:]?|SITUATO\s+IN|UBICATO\s+IN|SITO\s+IN|POSTO\s+IN|POSIZIONATO\s+IN|DENOMINATO|IN|DI|ZTL)\s+"#, in: v) {
                v = DocumentText.trim(DocumentText.substring(v, from: m.end, to: (v as NSString).length), ".:-")
            }
        }
        guard DocumentText.contains("[A-Z]{3}", in: v), !["ATTIVO", "NON ATTIVO", "FOSSE ATTIVO"].contains(v) else { return nil }
        return DocumentText.titled(v)
    }

    // MARK: Importi

    /// L'importo da pagare (totale entro 60 giorni, o la sanzione) e quello ridotto entro 5 giorni
    static func amounts(in t: String) -> (Double?, Double?) {
        let p = #"(?:€|(?<![A-Z])EUR(?:O)?(?![A-Z]))\s*\.?\s*([0-9]{1,4}(?:[.,][0-9]{2})?)(?![0-9])|(?<![0-9.,])([0-9]{1,4}[.,][0-9]{2})\s*(?:€|EUR(?:O)?(?![A-Z]))"#
        var total: Double?, sanction: Double?, other: Double?, reduced: Double?
        var previousEnd = 0
        let ns = t as NSString
        for m in DocumentText.matches(p, in: t) {
            guard let s = m.group(1) ?? m.group(2), let value = Double(s.replacingOccurrences(of: ",", with: ".")), value > 0 else { continue }
            let lineStart = ns.range(of: "\n", options: .backwards, range: NSRange(location: 0, length: m.range.location)).location
            let from = max(previousEnd, lineStart == NSNotFound ? 0 : lineStart, m.range.location - 70)
            let seg = DocumentText.substring(t, from: from, to: m.range.location)
            previousEnd = m.end
            func has(_ w: [String]) -> Bool { w.contains { seg.contains($0) } }
            if has(["5 GIORNI", "CINQUE GIORNI", "RIDOTT", "SCONT", "30%", "30 %"]) { reduced = reduced ?? value }
            else if has(["TOTALE", "DA PAGARE", "DOVUTO", "ENTRO 60", "60 GIORNI", "SESSANTA", "COMPLESSIV"]) { total = total ?? value }
            else if has(["SPESE", "NOTIFICA", "PROCEDIMENTO", "POSTAL"]) { continue }
            else if has(["SANZIONE", "IMPORTO", "SOMMA", "MINIMO", "PAGAMENTO"]) { sanction = sanction ?? value }
            else { other = other ?? value }
        }
        return (total ?? sanction ?? other, reduced)
    }

    // MARK: Articolo, numero, targa

    /// «art. 7 comma 9 e 14 C.d.S.» → (7, «art. 7, c. 9 e 14 C.d.S.»); si preferisce l'art. 7 (le ZTL) a quelli sulla procedura
    static func article(in t: String) -> (Int?, String?) {
        let p = #"(?<![A-Z])ART(?:ICOLO|T)?\.?\s*([0-9]{1,3})(?:\s*(?:,|-)?\s*(?:COMMA|COMMI|C\.|CO\.)\s*([0-9]{1,2}(?:\s*(?:,|E|-|/)\s*[0-9]{1,2})*(?:\s*BIS)?))?"#
        let found = DocumentText.matches(p, in: t).compactMap { m -> (Int, String?)? in
            guard let n = m.group(1).flatMap({ Int($0) }) else { return nil }
            return (n, m.group(2))
        }
        guard let best = found.first(where: { $0.0 == 7 }) ?? found.first(where: { !(200...210).contains($0.0) }) else { return (nil, nil) }
        var text = "art. \(best.0)"
        if let c = best.1 { text += ", c. " + DocumentText.trim(c).lowercased() }
        return (best.0, text + " C.d.S.")
    }

    static func number(in t: String) -> String? {
        let patterns = [
            #"(?<![A-Z])N(?:\.|°|R\.?|UM\.?|UMERO)?\s*(?:DI\s+|DEL\s+)?VERBALE\s*:?\s*([0-9A-Z][0-9A-Z/\-]{3,24})"#,
            #"(?:VERBALE|ATTO|AVVISO)[^\n]{0,50}?(?<![A-Z])N(?:R\.?|UM\.?|UMERO|\.|°)\s*:?\s*([0-9A-Z][0-9A-Z/\-]{3,24})"#,
        ]
        for p in patterns {
            for m in DocumentText.matches(p, in: t) {
                if let v = m.group(1).map({ DocumentText.trim($0, ".-/") }), v.contains(where: { $0.isNumber }) { return v }
            }
        }
        return nil
    }

    /// La targa: italiana («AB123CD») o straniera come scritta («M AB 1234»)
    static func plate(in t: String) -> String? {
        for m in DocumentText.matches(#"(?<![A-Z])TARGA(?:TO|TA)?\s*:?\s*(?:N\.?\s*)?([^\n]{4,30})"#, in: t) {
            guard let v = m.group(1) else { continue }
            if let it = DocumentText.first(#"(?<![A-Z0-9])([A-Z]{2})\s?([0-9]{3})\s?([A-Z]{2})(?![A-Z0-9])"#, in: v) {
                return (it.group(1) ?? "") + (it.group(2) ?? "") + (it.group(3) ?? "")
            }
            var parts: [String] = []
            for w in v.split(separator: " ") {
                let s = String(w)
                guard s.contains(where: { $0.isNumber }) || (s.count <= 3 && s.allSatisfy({ $0.isLetter || $0 == "-" })) else { break }
                parts.append(s)
            }
            let p = parts.joined(separator: " ")
            if p.contains(where: { $0.isNumber }), p.filter({ $0.isLetter || $0.isNumber }).count >= 4, p.count <= 12 { return p }
        }
        return nil
    }
}

/// Il verbale confrontato con i nostri dati: Comune, zona e varco, se a quell'ora il varco era attivo
/// secondo le regole che conosciamo, le scadenze e la bozza del ricorso.
enum FineCheck {
    struct Match {
        var city: City
        var zone: Zone?
        var gate: Gate?
    }

    enum Status: Equatable { case active, inactive, unsure }

    static let stopwords: Set<String> = [
        "VIA", "VIALE", "PIAZZA", "PIAZZALE", "LARGO", "CORSO", "BORGO", "VICOLO", "LUNGARNO", "LUNGOTEVERE", "PONTE", "PORTA", "STRADA",
        "ZTL", "VARCO", "SETTORE", "ZONA", "AREA", "DI", "DE", "DEL", "DELLA", "DELLE", "DEI", "DEGLI", "DELLO", "DELL", "D", "L", "E", "N", "NR",
        "IL", "LA", "LE", "LO", "GLI", "A", "IN", "DA", "PER", "CON", "SU", "AL", "ALLA", "ALLE", "AI", "SAN", "SANTA", "SANTO", "SANT",
        "NOTTURNA", "DIURNA", "NOTTE", "ACCESSO", "ELETTRONICO", "TELEMATICO", "USCITA", "TRAFFICO", "LIMITATO", "ENTRATA", "SOLO",
    ]

    /// Le parole che contano di un nome di strada o di varco, con le abbreviazioni sciolte
    static func tokens(_ s: String) -> [String] {
        var t = DocumentText.fold(s)
        for (a, b) in [("P.ZZA", "PIAZZA "), ("P.ZA", "PIAZZA "), ("P.LE", "PIAZZALE "), ("V.LE", "VIALE "), ("L.NO", "LUNGARNO "),
                       ("C.SO", "CORSO "), ("B.GO", "BORGO "), ("L.GO", "LARGO ")] {
            t = t.replacingOccurrences(of: a, with: b)
        }
        t = t.replacingOccurrences(of: #"(?<![A-Z])S\."#, with: "SAN ", options: .regularExpression)
        return t.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init).filter { $0.count >= 2 && !stopwords.contains($0) }
    }

    /// Uguali, o quasi (una lettera di differenza nelle parole lunghe: la foto sbaglia)
    static func similar(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        let n = min(a.count, b.count)
        guard n >= 5, abs(a.count - b.count) <= 2 else { return false }
        return levenshtein(a, b) <= (n >= 9 ? 2 : 1)
    }

    static func levenshtein(_ a: String, _ b: String) -> Int {
        let x = Array(a), y = Array(b)
        var row = Array(0...y.count)
        for i in 1...max(1, x.count) where !x.isEmpty {
            var prev = row[0]
            row[0] = i
            for j in 1...max(1, y.count) where !y.isEmpty {
                let cur = row[j]
                row[j] = min(row[j] + 1, row[j - 1] + 1, prev + (x[i - 1] == y[j - 1] ? 0 : 1))
                prev = cur
            }
        }
        return x.isEmpty ? y.count : row[y.count]
    }

    static func names(_ c: City) -> [String] {
        [c.name_it, c.name, c.id.replacingOccurrences(of: "-", with: " ")].compactMap { $0 }.map(DocumentText.fold)
    }

    /// Il Comune del verbale tra le nostre città: dal nome letto, o il nome di città che compare più volte nel testo
    static func city(for notice: FineReader.Notice, text: String, cities: [City]) -> City? {
        if let n = notice.city.map(DocumentText.fold), let c = cities.first(where: { names($0).contains(n) }) { return c }
        let t = DocumentText.fold(text)
        let counted: [(City, Int)] = cities.map { c in (c, names(c).map { DocumentText.count(word: $0, in: t) }.max() ?? 0) }.filter { $0.1 > 0 }
        return counted.max { $0.1 < $1.1 }?.0
    }

    static func match(_ notice: FineReader.Notice, text: String, cities: [City]) -> Match? {
        guard let c = city(for: notice, text: text, cities: cities) else { return nil }
        if let found = gate(notice.place ?? "", in: c) { return Match(city: c, zone: found.zone, gate: found.gate) }
        return Match(city: c, zone: zone(for: notice, text: text, in: c), gate: nil)
    }

    /// Il varco con il nome più simile al luogo del verbale; a parità, quello di una ZTL (non della zona verde)
    static func gate(_ place: String, in city: City) -> (zone: Zone, gate: Gate)? {
        let words = tokens(place)
        guard !words.isEmpty else { return nil }
        var best: (zone: Zone, gate: Gate, matched: Int, score: Double, rank: Int)?
        for z in city.zones {
            for g in z.gates {
                let gt = tokens(g.name)
                guard !gt.isEmpty else { continue }
                let matched = gt.filter { a in words.contains { similar(a, $0) } }
                guard matched.contains(where: { $0.count >= 4 }) else { continue }
                let score = Double(matched.count) / Double(gt.count)
                guard score >= 0.5 else { continue }
                let rank = z.type == .green ? 0 : 1
                if let b = best, (b.matched, b.score, b.rank) >= (matched.count, score, rank) { continue }
                best = (z, g, matched.count, score, rank)
            }
        }
        return best.map { (zone: $0.zone, gate: $0.gate) }
    }

    /// Senza varco: la zona nominata («Settore B», «Area C», «ZTL Tridente»), o l'unica ZTL della città
    static func zone(for notice: FineReader.Notice, text: String, in city: City) -> Zone? {
        let lines = DocumentText.fold(text).components(separatedBy: .newlines)
            .filter { DocumentText.contains(#"ZTL|Z\.T\.L|VARCO|SETTORE|ZONA|AREA"#, in: $0) }
        let t = (lines + [DocumentText.fold(notice.place ?? "")]).joined(separator: "\n")
            .replacingOccurrences(of: "ZONA A TRAFFICO LIMITATO", with: "ZTL").replacingOccurrences(of: "ZONE A TRAFFICO LIMITATO", with: "ZTL")
        func italian(_ z: Zone) -> String { DocumentText.fold(z.name_it ?? z.name) }
        // «SETTORE B», «AREA C», «ZONA T», «ZTL 1»: la prima parte del nome, se ha almeno due parole
        let short = city.zones.filter { z in
            let s = DocumentText.trim(italian(z).components(separatedBy: "·").first ?? "")
            return s.contains(" ") && DocumentText.containsWord(s, in: t)
        }
        if short.count == 1 { return short[0] }
        // Le parole del nome della zona («Tridente», «Trastevere», «Centro Storico»): vince solo se è l'unica con più parole trovate
        let words = tokens(t)
        let scored: [(Zone, Int)] = city.zones.map { z in (z, Set(tokens(italian(z))).filter { a in words.contains { similar(a, $0) } }.count) }
        if let top = scored.max(by: { $0.1 < $1.1 }), top.1 > 0, scored.filter({ $0.1 == top.1 }).count == 1 { return top.0 }
        let main = city.zones.filter { $0.type != .green }
        return main.count == 1 ? main[0] : nil
    }

    /// A quell'ora, secondo gli orari che conosciamo, il varco era acceso? Nei festivi che non abbiamo confermato: non si sa
    static func status(_ zone: Zone, at date: Date, engine: RuleEngine = RuleEngine()) -> Status {
        let on = engine.isActive(zone, at: date)
        if on && zone.freeOnHolidays == nil && engine.isHoliday(zone, date) { return .unsure }
        return on ? .active : .inactive
    }

    // MARK: Scadenze

    struct Deadlines: Equatable {
        var reduced: Date       // pagamento ridotto del 30%: 5 giorni dalla notifica
        var pay: Date           // pagamento in misura ridotta: 60 giorni
        var giudice: Date       // ricorso al Giudice di Pace: 30 giorni
        var prefetto: Date      // ricorso al Prefetto: 60 giorni
    }

    static func deadlines(notifiedOn: Date, calendar: Calendar = RuleEngine.rome) -> Deadlines {
        let day = calendar.startOfDay(for: notifiedOn)
        func plus(_ n: Int) -> Date { calendar.date(byAdding: .day, value: n, to: day) ?? day }
        return Deadlines(reduced: plus(5), pay: plus(60), giudice: plus(30), prefetto: plus(60))
    }

    /// Entro quando va notificato il verbale (art. 201 C.d.S.): 90 giorni in Italia, 360 per chi risiede all'estero
    static func notificationLimits(violation: Date, calendar: Calendar = RuleEngine.rome) -> (italy: Date, abroad: Date) {
        let day = calendar.startOfDay(for: violation)
        return (calendar.date(byAdding: .day, value: 90, to: day) ?? day, calendar.date(byAdding: .day, value: 360, to: day) ?? day)
    }

    /// Il Codice della Strada su Normattiva (il testo ufficiale)
    static func law(_ article: String) -> URL {
        URL(string: "https://www.normattiva.it/uri-res/N2Ls?urn:nir:stato:decreto.legislativo:1992-04-30;285~art" + article)!
    }

    static let references: [(String, URL)] = [
        ("Codice della Strada, art. 7 (ZTL)", law("7")),
        ("Codice della Strada, art. 201 (notifica)", law("201")),
        ("Codice della Strada, art. 202 (pagamento)", law("202")),
        ("Codice della Strada, art. 203 (ricorso al Prefetto)", law("203")),
        ("Codice della Strada, art. 204-bis (Giudice di Pace)", law("204bis")),
    ]

    // MARK: Bozza del ricorso

    /// Una bozza in italiano con i dati letti, da completare: chiaramente segnata come bozza, non è una consulenza legale
    static func appealDraft(_ n: FineReader.Notice, city: String?, zone: String?, status: Status?, source: URL?,
                            calendar: Calendar = RuleEngine.rome) -> String {
        let comune = city ?? n.city ?? "[Comune]"
        let number = n.number.map { "n. " + $0 } ?? "n. [numero]"
        let noticeDate = n.noticeDate.map { " del " + DocumentText.italian($0, calendar: calendar) } ?? ""
        let notified = n.notificationDate.map { DocumentText.italian($0, calendar: calendar) } ?? "[data di notifica]"
        let when = n.violation.map { DocumentText.italian($0, calendar: calendar) } ?? "[data]"
        let hour = n.violation != nil && n.violationHasTime ? DocumentText.italianTime(n.violation!, calendar: calendar) : "[ora]"
        let place = n.place ?? "[varco o luogo]"
        let zonePart = zone.map { ", " + $0 } ?? ""
        let article = n.articleText ?? "art. 7 del Codice della Strada"
        var reasons: [String] = []
        if status == .inactive {
            let src = source.map { " (fonte: " + $0.absoluteString + ")" } ?? ""
            reasons.append("1. Secondo gli orari pubblicati dal Comune" + src + ", nel giorno e nell'ora indicati la zona a traffico limitato non risultava attiva. Si chiede di verificare lo stato del varco e del pannello luminoso al momento del transito.")
            reasons.append("2. [Altri motivi, se ci sono]")
        } else {
            reasons.append("1. [Indicare i motivi: ad esempio pannello «varco attivo» spento o guasto; segnaletica assente o non leggibile; targa comunicata dall'hotel o permesso valido; più verbali per la stessa ZTL nello stesso giorno; notifica oltre i termini dell'art. 201 C.d.S.]")
        }
        let lines: [String] = [
            "BOZZA – DA VERIFICARE E COMPLETARE PRIMA DI INVIARE",
            "(Testo preparato con GateLR dai dati letti sul verbale. Non è una consulenza legale: controlla dati, termini e motivi.)",
            "",
            "Al Prefetto di " + comune,
            "per il tramite del Comando di Polizia Locale di " + comune,
            "",
            "Oggetto: ricorso ai sensi dell'art. 203 del Codice della Strada avverso il verbale " + number + noticeDate,
            "",
            "Il/La sottoscritto/a [nome e cognome], nato/a a [luogo] il [data], residente in [indirizzo], in qualità di [proprietario / conducente / locatario] del veicolo targato " + (n.plate ?? "[targa]") + ",",
            "",
            "PREMESSO CHE",
            "- in data " + notified + " gli/le è stato notificato il verbale sopra indicato, per la violazione dell'" + article + " (accesso a zona a traffico limitato);",
            "- la violazione sarebbe stata accertata il " + when + " alle ore " + hour + " presso " + place + zonePart + ", Comune di " + comune + ";",
            "",
            "RICORRE",
            "per i seguenti motivi:",
        ] + reasons + [
            "",
            "e chiede l'annullamento del verbale.",
            "",
            "Allegati: copia del verbale; [documenti: conferma dell'hotel, permesso, foto della segnaletica, contratto di noleggio].",
            "",
            "[Luogo e data]                [Firma]",
            "",
            "(Ricorso al Prefetto entro 60 giorni dalla notifica; in alternativa ricorso al Giudice di Pace entro 30 giorni. Segui le istruzioni scritte sul verbale.)",
        ]
        return lines.joined(separator: "\n")
    }
}
