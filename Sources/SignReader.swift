import Foundation

/// Legge il testo di un pannello ZTL («7.30-20.00 feriali», «LUN-VEN 0-24», «festivi esclusi»…)
/// e ne ricava giorni e orari. Niente mappe né fotocamera: si può provare con i test.
enum SignReader {
    struct Rule: Equatable {
        var days: Set<Int>          // 1 = domenica … 7 = sabato
        var start: Int              // minuti
        var end: Int
    }

    struct Result: Equatable {
        var rules: [Rule]
        var holidaysExcluded: Bool
        var holidaysIncluded: Bool
        var understood: Bool { !rules.isEmpty }
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
            var days = self.days(in: line)
            if days == nil, i + 1 < lines.count, timeRanges(in: lines[i + 1]).isEmpty { days = self.days(in: lines[i + 1]) }
            if days == nil, i > 0, timeRanges(in: lines[i - 1]).isEmpty { days = self.days(in: lines[i - 1]) }
            for t in times { rules.append(Rule(days: days ?? allDays, start: t.0, end: t.1)) }
        }
        let excluded = text.contains("festivi esclusi") || text.contains("escluso festivi") || text.contains("esclusi festivi")
            || text.contains("holidays excluded") || (text.contains("feriali") && !text.contains("festivi"))
        let included = !excluded && (text.contains("festivi") || text.contains("tutti i giorni"))
        return Result(rules: rules, holidaysExcluded: excluded, holidaysIncluded: included)
    }

    /// «7.30-20», «7:30 - 20:00», «0-24», «dalle 23 alle 3»
    static func timeRanges(in line: String) -> [(Int, Int)] {
        let pattern = #"(?:dalle\s+)?(\d{1,2})(?:[.:,h](\d{2}))?\s*(?:-|alle|a|/)\s*(\d{1,2})(?:[.:,h](\d{2}))?"#
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = line as NSString
        return re.matches(in: line, range: NSRange(location: 0, length: ns.length)).compactMap { m in
            func n(_ i: Int) -> Int? { m.range(at: i).location == NSNotFound ? nil : Int(ns.substring(with: m.range(at: i))) }
            guard let h1 = n(1), let h2 = n(3), h1 <= 24, h2 <= 24 else { return nil }
            let m1 = n(2) ?? 0, m2 = n(4) ?? 0
            guard m1 < 60, m2 < 60 else { return nil }
            // Un intervallo di giorni («1-31») o di date non è un orario: serve almeno un minuto o un'ora plausibile
            if n(2) == nil && n(4) == nil && h1 == h2 { return nil }
            return (h1 * 60 + m1, h2 * 60 + m2)
        }
    }

    /// I giorni scritti sul pannello, in italiano (e qualche abbreviazione inglese)
    static func days(in line: String) -> Set<Int>? {
        let names: [(String, Int)] = [("dom", 1), ("lun", 2), ("mar", 3), ("mer", 4), ("gio", 5), ("ven", 6), ("sab", 7),
                                      ("sun", 1), ("mon", 2), ("tue", 3), ("wed", 4), ("thu", 5), ("fri", 6), ("sat", 7)]
        if line.contains("tutti i giorni") || line.contains("every day") || line.contains("giornaliero") { return allDays }
        // Intervallo «lun-ven», «lunedì - sabato»
        let range = #"(dom|lun|mar|mer|gio|ven|sab|sun|mon|tue|wed|thu|fri|sat)[a-zì]*\.?\s*-\s*(dom|lun|mar|mer|gio|ven|sab|sun|mon|tue|wed|thu|fri|sat)"#
        if let re = try? NSRegularExpression(pattern: range),
           let m = re.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) {
            let ns = line as NSString
            let a = names.first { $0.0 == ns.substring(with: m.range(at: 1)) }!.1
            let b = names.first { $0.0 == ns.substring(with: m.range(at: 2)) }!.1
            var out = Set<Int>(); var d = a
            for _ in 0..<7 { out.insert(d); if d == b { break }; d = d % 7 + 1 }
            return out
        }
        if line.contains("feriali") { return [2, 3, 4, 5, 6, 7] }
        if line.contains("festivi") && !line.contains("esclus") { return [1] }
        var found = Set<Int>()
        for (k, v) in names where line.range(of: #"\b"# + k, options: .regularExpression) != nil { found.insert(v) }
        return found.isEmpty ? nil : found
    }

    /// Secondo il cartello, a quell'ora la ZTL è attiva?
    static func isActive(_ r: Result, at date: Date, calendar: Calendar = .current) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        let minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        if r.holidaysExcluded && ItalianHolidays.isHoliday(date, calendar: calendar) { return false }
        let yesterday = weekday == 1 ? 7 : weekday - 1
        return r.rules.contains { rule in
            if rule.end > rule.start { return rule.days.contains(weekday) && minute >= rule.start && minute < rule.end }
            if rule.end == rule.start { return rule.days.contains(weekday) }
            return (rule.days.contains(weekday) && minute >= rule.start) || (rule.days.contains(yesterday) && minute < rule.end)
        }
    }
}
