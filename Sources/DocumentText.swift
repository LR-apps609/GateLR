import Foundation

/// Gli attrezzi comuni per leggere il testo di un documento fotografato (libretto, verbale): maiuscole senza
/// accenti, espressioni regolari, le date scritte a numeri e le righe ricostruite dai pezzi letti da Vision.
/// Niente fotocamera qui: si prova con i test.
enum DocumentText {
    /// «Città di Firenze – Lì» → «CITTA DI FIRENZE - LI»: maiuscole, senza accenti, trattini e apostrofi semplici
    static func fold(_ s: String) -> String {
        var t = s.folding(options: [.diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX")).uppercased()
        for (a, b) in [("\u{00A0}", " "), ("\t", " "), ("–", "-"), ("—", "-"), ("‐", "-"), ("’", "'"), ("‘", "'"), ("´", "'"), ("`", "'"), ("\r", "")] {
            t = t.replacingOccurrences(of: a, with: b)
        }
        return t
    }

    /// Solo lettere e cifre: «Mercedes-Benz» → «MERCEDESBENZ»
    static func compact(_ s: String) -> String {
        String(String.UnicodeScalarView(fold(s).unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }))
    }

    struct Match {
        let ns: NSString
        let result: NSTextCheckingResult
        var range: NSRange { result.range }
        var end: Int { result.range.location + result.range.length }
        func group(_ i: Int) -> String? {
            guard i < result.numberOfRanges else { return nil }
            let r = result.range(at: i)
            return r.location == NSNotFound ? nil : ns.substring(with: r)
        }
        func range(_ i: Int) -> NSRange { result.range(at: i) }
    }

    /// Tutte le corrispondenze; ^ e $ valgono a ogni riga
    static func matches(_ pattern: String, in s: String) -> [Match] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return [] }
        let ns = s as NSString
        return re.matches(in: s, range: NSRange(location: 0, length: ns.length)).map { Match(ns: ns, result: $0) }
    }

    static func first(_ pattern: String, in s: String) -> Match? { matches(pattern, in: s).first }

    static func contains(_ pattern: String, in s: String) -> Bool { first(pattern, in: s) != nil }

    /// Una parola o frase intera nel testo (già in maiuscolo): «ROMA» non vale dentro «ROMANA»
    static func containsWord(_ word: String, in s: String) -> Bool {
        contains("(?<![A-Z0-9])" + NSRegularExpression.escapedPattern(for: word) + "(?![A-Z0-9])", in: s)
    }

    static func count(word: String, in s: String) -> Int {
        matches("(?<![A-Z0-9])" + NSRegularExpression.escapedPattern(for: word) + "(?![A-Z0-9])", in: s).count
    }

    static func substring(_ s: String, from: Int, to: Int) -> String {
        let ns = s as NSString
        let a = max(0, min(from, ns.length)), b = max(a, min(to, ns.length))
        return ns.substring(with: NSRange(location: a, length: b - a))
    }

    static func trim(_ s: String, _ extra: String = "") -> String {
        s.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: extra)))
    }

    // MARK: Date

    struct DateHit: Equatable {
        var location: Int
        var length: Int
        var year: Int, month: Int, day: Int
        var end: Int { location + length }
    }

    static let months = ["GENNAIO", "FEBBRAIO", "MARZO", "APRILE", "MAGGIO", "GIUGNO", "LUGLIO", "AGOSTO", "SETTEMBRE", "OTTOBRE", "NOVEMBRE", "DICEMBRE"]

    /// Le date nel testo (già passato da fold): «12/03/2026», «12.03.26», «12-03-2026», «12 marzo 2026».
    /// Una «O» letta al posto dello zero si corregge.
    static func dates(in t: String, thisYear: Int) -> [DateHit] {
        var out: [DateHit] = []
        let numeric = #"(?<![0-9A-Z])([0-3O]?[0-9O])\s?[./\-]\s?([01O]?[0-9O])\s?[./\-]\s?((?:19|20)[0-9O]{2}|[0-9]{2})(?![0-9])"#
        for m in matches(numeric, in: t) {
            func n(_ i: Int) -> Int? { m.group(i).flatMap { Int($0.replacingOccurrences(of: "O", with: "0")) } }
            guard let d = n(1), let mo = n(2), var y = n(3) else { continue }
            if y < 100 { y += y <= thisYear % 100 + 1 ? 2000 : 1900 }
            if valid(y, mo, d, thisYear: thisYear) { out.append(DateHit(location: m.range.location, length: m.range.length, year: y, month: mo, day: d)) }
        }
        let textual = #"(?<![0-9])([0-3]?[0-9])\s+("# + months.joined(separator: "|") + #")\s+((?:19|20)[0-9]{2})(?![0-9])"#
        for m in matches(textual, in: t) {
            guard let d = m.group(1).flatMap({ Int($0) }), let name = m.group(2), let mo = months.firstIndex(of: name),
                  let y = m.group(3).flatMap({ Int($0) }) else { continue }
            if valid(y, mo + 1, d, thisYear: thisYear) { out.append(DateHit(location: m.range.location, length: m.range.length, year: y, month: mo + 1, day: d)) }
        }
        return out.sorted { $0.location < $1.location }
    }

    static func valid(_ y: Int, _ m: Int, _ d: Int, thisYear: Int) -> Bool {
        y >= 1950 && y <= thisYear + 1 && m >= 1 && m <= 12 && d >= 1 && d <= 31
    }

    /// Una data e ora in ora italiana
    static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0, calendar: Calendar = RuleEngine.rome) -> Date? {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))
    }

    /// «12/03/2026» in ora italiana, come si scrive su un ricorso
    static func italian(_ date: Date, calendar: Calendar = RuleEngine.rome) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%02d/%02d/%04d", c.day ?? 0, c.month ?? 0, c.year ?? 0)
    }

    static func italianTime(_ date: Date, calendar: Calendar = RuleEngine.rome) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    /// «VIA DE' TORNABUONI» → «Via de' Tornabuoni»
    static func titled(_ s: String) -> String {
        let small: Set<String> = ["di", "de", "de'", "del", "della", "delle", "dei", "degli", "dello", "dell'", "d'", "e", "a", "al", "alla", "in"]
        let words = trim(s).lowercased().split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        return words.enumerated().map { i, w -> String in
            if i > 0 && small.contains(w) { return w }
            // «dell'agnolo» → «dell'Agnolo»
            if let q = w.firstIndex(of: "'"), w.index(after: q) < w.endIndex {
                let head = String(w[...q]), tail = String(w[w.index(after: q)...])
                return (i > 0 && small.contains(head) ? head : head.capitalized) + tail.capitalized
            }
            return w.capitalized
        }.joined(separator: " ")
    }

    // MARK: Righe

    /// Un pezzo di testo letto da Vision, con la sua posizione (coordinate 0…1, y dal basso come in Vision)
    struct Piece: Equatable {
        var text: String
        var x: Double
        var midY: Double
        var height: Double
    }

    /// I pezzi sulla stessa riga del documento (stessa altezza) uniti da tre spazi, da sinistra a destra;
    /// le righe dall'alto in basso. Così «D.1» e «FIAT», letti come due pezzi, tornano vicini.
    static func rows(_ pieces: [Piece]) -> String {
        var rows: [[Piece]] = []
        for p in pieces.sorted(by: { $0.midY > $1.midY }) {
            if let ref = rows.last?.first, abs(ref.midY - p.midY) < max(ref.height, p.height) * 0.5 {
                rows[rows.count - 1].append(p)
            } else {
                rows.append([p])
            }
        }
        return rows.map { $0.sorted { $0.x < $1.x }.map(\.text).joined(separator: "   ") }.joined(separator: "\n")
    }
}
