import Foundation

/// Legge il testo di un pannello ZTL («7.30-20.00 feriali», «LUN-VEN 0-24», «festivi esclusi»…)
/// e ne ricava giorni e orari. Niente mappe né fotocamera: si può provare con i test.
enum SignReader {
    /// Cosa fa la regola nei festivi infrasettimanali (Natale di martedì, 2 giugno…). La domenica la decide il giorno
    enum Holidays: Equatable {
        /// Il cartello non dice niente: il festivo conta come il suo giorno della settimana (prudente: resta accesa)
        case asWeekday
        /// «feriali», «festivi esclusi»: nei festivi la regola non vale
        case excluded
        /// «festivi», «domenica e festivi», «feriali e festivi»: il festivo conta come una domenica
        case asSunday
    }

    struct Rule: Equatable {
        var days: Set<Int>          // 1 = domenica … 7 = sabato
        var start: Int              // minuti
        var end: Int
        var holidays: Holidays = .asWeekday
    }

    struct Result: Equatable {
        var rules: [Rule]
        var holidaysExcluded: Bool
        var holidaysIncluded: Bool
        var understood: Bool { !rules.isEmpty }
    }

    /// 1.19.2: quello che la schermata «Leggi il cartello» può dire. Mai verde: il cartello non conosce il tuo veicolo,
    /// i permessi, i divieti per classe Euro né le aree pedonali, e la lettura della foto può sbagliare
    enum Reading: Equatable {
        /// Secondo il cartello la ZTL è accesa: rosso, non entrare
        case active
        /// Secondo il cartello sembra spenta: giallo con il «?», controlla che non ci siano altri divieti
        case seemsOff
        /// Giorni e orari non trovati: giallo, «Non riesco a leggerlo»
        case unreadable
    }

    static func reading(_ r: Result, at date: Date, calendar: Calendar = RuleEngine().calendar) -> Reading {
        guard r.understood else { return .unreadable }
        return isActive(r, at: date, calendar: calendar) ? .active : .seemsOff
    }

    static let allDays: Set<Int> = [1, 2, 3, 4, 5, 6, 7]

    static func parse(_ raw: String) -> Result {
        let text = raw.lowercased()
            .replacingOccurrences(of: "–", with: "-").replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "÷", with: "-")
        var rules: [Rule] = []
        // Si legge riga per riga: i giorni stanno di solito sulla stessa riga degli orari, o su quella dopo
        let lines = text.components(separatedBy: CharacterSet.newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        for (i, line) in lines.enumerated() {
            let times = timeRanges(in: line)
            guard !times.isEmpty else { continue }
            // 2.0 (B45): più gruppi di giorni e orari sulla stessa riga («lun-ven 7.30-20.00 sab 7.30-14.00»): ogni orario con
            // i giorni scritti subito prima (prima il sabato prendeva i giorni lun-ven)
            if let pieces = splitByDays(line), pieces.count == times.count {
                for (t, info) in zip(times, pieces) { rules.append(Rule(days: info.days, start: t.0, end: t.1, holidays: info.holidays)) }
                continue
            }
            var info = dayInfo(in: line)
            if info == nil, i + 1 < lines.count, timeRanges(in: lines[i + 1]).isEmpty { info = dayInfo(in: lines[i + 1]) }
            if info == nil, i > 0, timeRanges(in: lines[i - 1]).isEmpty { info = dayInfo(in: lines[i - 1]) }
            for t in times { rules.append(Rule(days: info?.days ?? allDays, start: t.0, end: t.1, holidays: info?.holidays ?? .asWeekday)) }
        }
        let excluded = excludesHolidays(text) || (!rules.isEmpty && rules.allSatisfy { $0.holidays == .excluded })
        let included = !excluded && (rules.contains { $0.holidays == .asSunday } || text.contains("tutti i giorni"))
        return Result(rules: rules, holidaysExcluded: excluded, holidaysIncluded: included)
    }

    /// «festivi esclusi», «esclusi i festivi», «escluso festivi», «tranne i festivi», «holidays excluded»
    static func excludesHolidays(_ text: String) -> Bool {
        text.range(of: #"festivi\s+esclus|esclus[oi]\s+(i\s+)?(giorni\s+)?festivi|tranne\s+(i\s+)?festivi|holidays\s+excluded"#,
                   options: .regularExpression) != nil
    }

    /// «7.30-20», «7:30 - 20:00», «0-24», «dalle 23 alle 3»
    static func timeRanges(in line: String) -> [(Int, Int)] { timeMatches(in: line).map(\.minutes) }

    /// Gli orari della riga con dove stanno (per dividere la riga in gruppi di giorni e orari)
    static func timeMatches(in line: String) -> [(minutes: (Int, Int), range: NSRange)] {
        let pattern = #"(?:dalle\s+)?(\d{1,2})(?:[.:,h](\d{2}))?\s*(?:-|alle|a)\s*(\d{1,2})(?:[.:,h](\d{2}))?"#
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = line as NSString
        return re.matches(in: line, range: NSRange(location: 0, length: ns.length)).compactMap { m -> (minutes: (Int, Int), range: NSRange)? in
            func n(_ i: Int) -> Int? { m.range(at: i).location == NSNotFound ? nil : Int(ns.substring(with: m.range(at: i))) }
            guard let h1 = n(1), let h2 = n(3), h1 <= 24, h2 <= 24 else { return nil }
            let m1 = n(2) ?? 0, m2 = n(4) ?? 0
            guard m1 < 60, m2 < 60 else { return nil }
            // Un intervallo di giorni («1-31») o di date non è un orario: serve almeno un minuto o un'ora plausibile
            if n(2) == nil && n(4) == nil && h1 == h2 { return nil }
            // 2.0 (B157): le classi Euro («EURO 0-1-2», «euro 3-4») non sono un orario: dopo «euro» o seguite da un altro «-n»
            let before = ns.substring(to: m.range.location)
            if before.range(of: #"euro\s*$"#, options: .regularExpression) != nil { return nil }
            let after = ns.substring(from: m.range.location + m.range.length)
            if n(2) == nil, n(4) == nil, h1 <= 6, h2 <= 6, after.range(of: #"^-\d(?!\d)"#, options: .regularExpression) != nil { return nil }
            return ((h1 * 60 + m1, h2 * 60 + m2), m.range)
        }
    }

    /// 2.0 (B45): la riga divisa in pezzi «giorni + orario»: per ogni orario i giorni scritti tra l'orario prima e lui.
    /// nil se c'è un solo orario o se un pezzo non ha giorni suoi (allora valgono i giorni di tutta la riga, come prima)
    static func splitByDays(_ line: String) -> [(days: Set<Int>, holidays: Holidays)]? {
        let matches = timeMatches(in: line)
        guard matches.count > 1 else { return nil }
        let ns = line as NSString
        var start = 0
        var out: [(days: Set<Int>, holidays: Holidays)] = []
        for m in matches {
            let piece = ns.substring(with: NSRange(location: start, length: m.range.location - start))
            guard let info = dayInfo(in: piece) else { return nil }
            out.append(info)
            start = m.range.location + m.range.length
        }
        return out
    }

    /// Un giorno della settimana come parola intera: «lun», «lun.», «lunedì», «lunedi» (mai dentro «marzo», «merci»,
    /// «giorni», «venti», «domani»…), e le abbreviazioni inglesi
    static let dayWord = #"(?<![a-zà-ü])(dom(?:enica)?|lun(?:ed[iìí])?|mar(?:ted[iìí])?|mer(?:coled[iìí])?|gio(?:ved[iìí])?|ven(?:erd[iìí])?|sab(?:ato)?|sun(?:day)?|mon(?:day)?|tue(?:s(?:day)?)?|wed(?:nesday)?|thu(?:rs(?:day)?)?|fri(?:day)?|sat(?:urday)?)(?![a-zà-ü])\.?"#

    static func dayNumber(_ word: String) -> Int? {
        let w = String(word.prefix(3))
        return ["dom": 1, "lun": 2, "mar": 3, "mer": 4, "gio": 5, "ven": 6, "sab": 7,
                "sun": 1, "mon": 2, "tue": 3, "wed": 4, "thu": 5, "fri": 6, "sat": 7][w]
    }

    /// I giorni scritti sul pannello, in italiano (e qualche abbreviazione inglese)
    static func days(in line: String) -> Set<Int>? { dayInfo(in: line)?.days }

    /// I giorni e cosa succede nei festivi, per una riga del pannello
    static func dayInfo(in line: String) -> (days: Set<Int>, holidays: Holidays)? {
        let feriali = line.range(of: #"(?<![a-z])feriali(?![a-z])"#, options: .regularExpression) != nil
        let festivi = line.range(of: #"(?<![a-z])festivi(?![a-z])"#, options: .regularExpression) != nil && !excludesHolidays(line)
        let excluded = excludesHolidays(line)
        // «feriali e festivi» (o «festivi e feriali»): tutti i giorni, domeniche e festivi compresi
        if feriali && festivi { return (allDays, .asSunday) }
        if line.contains("tutti i giorni") || line.contains("every day") || line.contains("giornaliero") {
            return (allDays, excluded ? Holidays.excluded : Holidays.asWeekday)
        }
        let ns = line as NSString
        let full = NSRange(location: 0, length: ns.length)
        // Intervallo «lun-ven», «lunedì - sabato», «da lunedì a venerdì», «dal lun. al sab.»
        if let re = try? NSRegularExpression(pattern: dayWord + #"\s*(?:-|/|\ba\b|\bal\b)\s*"# + dayWord),
           let m = re.firstMatch(in: line, range: full),
           let a = dayNumber(ns.substring(with: m.range(at: 1))), let b = dayNumber(ns.substring(with: m.range(at: 2))) {
            var out = Set<Int>(); var d = a
            for _ in 0..<7 { out.insert(d); if d == b { break }; d = d % 7 + 1 }
            if festivi { out.insert(1) }
            return (out, excluded ? Holidays.excluded : (festivi ? Holidays.asSunday : Holidays.asWeekday))
        }
        // «feriali» = da lunedì a sabato, festivi esclusi (feriale vuol dire non festivo)
        if feriali { return ([2, 3, 4, 5, 6, 7], .excluded) }
        var found = Set<Int>()
        if let re = try? NSRegularExpression(pattern: dayWord) {
            for m in re.matches(in: line, range: full) { if let d = dayNumber(ns.substring(with: m.range(at: 1))) { found.insert(d) } }
        }
        // «festivi» = le domeniche e i festivi nazionali; «sabato e festivi» = il sabato, le domeniche e i festivi
        if festivi { found.insert(1); return (found, .asSunday) }
        if found.isEmpty { return nil }
        return (found, excluded ? Holidays.excluded : Holidays.asWeekday)
    }

    /// Secondo il cartello, a quell'ora la ZTL è attiva? Il cartello è in Italia: giorni, ore e festivi
    /// si contano in ora italiana anche se il telefono è ancora nel fuso di casa
    static func isActive(_ r: Result, at date: Date, calendar: Calendar = RuleEngine().calendar) -> Bool {
        let minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let dayBefore = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        let holidayToday = ItalianHolidays.isHoliday(date, calendar: calendar)
        let holidayYesterday = ItalianHolidays.isHoliday(dayBefore, calendar: calendar)
        /// Il giorno della settimana come lo legge la regola: nei festivi «feriali» non vale, «festivi» li conta come domenica
        func weekday(_ d: Date, holiday: Bool, _ rule: Rule) -> Int? {
            let w = calendar.component(.weekday, from: d)
            guard holiday else { return w }
            if r.holidaysExcluded { return nil }
            switch rule.holidays {
            case .asWeekday: return w
            case .excluded: return nil
            case .asSunday: return 1
            }
        }
        return r.rules.contains { rule in
            let today = weekday(date, holiday: holidayToday, rule)
            let yesterday = weekday(dayBefore, holiday: holidayYesterday, rule)
            let onToday = today.map { rule.days.contains($0) } ?? false
            let onYesterday = yesterday.map { rule.days.contains($0) } ?? false
            if rule.end > rule.start { return onToday && minute >= rule.start && minute < rule.end }
            if rule.end == rule.start { return onToday }
            // Fascia che passa la mezzanotte: la sera del giorno indicato o la notte dopo
            return (onToday && minute >= rule.start) || (onYesterday && minute < rule.end)
        }
    }
}
