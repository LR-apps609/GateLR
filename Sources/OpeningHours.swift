import Foundation

/// Gli orari di un parcheggio come li scrive OpenStreetMap (opening_hours), solo nelle forme più comuni:
/// «24/7», «Mo-Fr 07:00-20:00; Sa 08:00-13:00», «Mo-Su 00:00-24:00», «Mo,We 08:00-12:00,14:00-18:30»,
/// «22:00-06:00» (dopo mezzanotte), «Su off», «PH off». Mesi, settimane, alba e tramonto, «+» e commenti
/// non si leggono: parse restituisce nil e l'app mostra il testo così com'è, senza dire «aperto».
/// Come in OSM, una regola successiva sostituisce le precedenti per i giorni che nomina.
struct OpeningHours: Equatable {
    struct Interval: Equatable {
        var start: Int          // minuti dalla mezzanotte
        var end: Int            // oltre 1440 = finisce il giorno dopo
    }

    var alwaysOpen = false
    /// Gli intervalli di ogni giorno: indice 0 = domenica … 6 = sabato (Calendar.weekday - 1)
    var days: [[Interval]] = Array(repeating: [], count: 7)
    /// I festivi (PH), se la stringa ne parla; nil = valgono gli orari del giorno della settimana
    var holidays: [Interval]?

    /// Mo … Su → giorno di Calendar (1 = domenica … 7 = sabato)
    private static let dayCodes: [String: Int] = ["Su": 1, "Mo": 2, "Tu": 3, "We": 4, "Th": 5, "Fr": 6, "Sa": 7]
    /// L'ordine della settimana in OSM, da lunedì
    private static let order = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    static func parse(_ raw: String?) -> OpeningHours? {
        guard var text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        text = text.replacingOccurrences(of: "\u{2013}", with: "-").replacingOccurrences(of: "\u{2014}", with: "-")
        if text.contains("||") || text.contains("\"") { return nil }
        var out = OpeningHours()
        var any = false
        for part in text.split(separator: ";") {
            let rule = part.trimmingCharacters(in: .whitespaces)
            if rule.isEmpty { continue }
            if rule == "24/7" {
                out.alwaysOpen = true
                out.days = Array(repeating: [Interval(start: 0, end: 1440)], count: 7)
                any = true
                continue
            }
            guard let r = split(rule) else { return nil }
            let intervals: [Interval]
            if r.times == "off" || r.times == "closed" {
                intervals = []
            } else if r.times == "24/7" {
                intervals = [Interval(start: 0, end: 1440)]
            } else {
                guard let list = parseTimes(r.times) else { return nil }
                intervals = list
            }
            for d in r.days { out.days[d - 1] = intervals }
            if r.holiday { out.holidays = intervals }
            any = true
        }
        guard any else { return nil }
        // «24/7» seguito da altre regole («24/7; PH off») non è più sempre aperto
        if out.alwaysOpen { out.alwaysOpen = out.days.allSatisfy { $0 == [Interval(start: 0, end: 1440)] } && out.holidays == nil }
        return out
    }

    /// Una regola in giorni (1…7), festivi sì o no, e la parte degli orari. Senza giorni: tutti i giorni
    private static func split(_ rule: String) -> (days: [Int], holiday: Bool, times: String)? {
        let scalars = Array(rule)
        var i = 0
        // La parte dei giorni: lettere, trattini e virgole all'inizio (spazi dopo le virgole ammessi)
        var selector = ""
        while i < scalars.count {
            let c = scalars[i]
            if c.isLetter || c == "-" || c == "," {
                selector.append(c); i += 1
            } else if c == " ", selector.hasSuffix(",") {
                i += 1
            } else {
                break
            }
        }
        let rest = String(scalars[i...]).trimmingCharacters(in: .whitespaces)
        // Senza giorni la regola comincia con un numero, oppure è solo «off»
        if selector.isEmpty || selector == "off" || selector == "closed" {
            if selector.isEmpty { return (Array(1...7), false, rest) }
            return rest.isEmpty ? (Array(1...7), false, selector) : nil
        }
        var days: [Int] = []
        var holiday = false
        for item in selector.split(separator: ",") {
            let s = String(item)
            if s == "PH" { holiday = true; continue }
            let ends = s.split(separator: "-").map(String.init)
            if ends.count == 1, let d = dayCodes[ends[0]] {
                days.append(d)
            } else if ends.count == 2, let a = order.firstIndex(of: ends[0]), let b = order.firstIndex(of: ends[1]) {
                // «Fr-Mo» passa per il fine settimana
                var k = a
                while true {
                    days.append(dayCodes[order[k]]!)
                    if k == b { break }
                    k = (k + 1) % 7
                }
            } else {
                return nil          // mesi, settimane, «SH», giorni sconosciuti
            }
        }
        guard !rest.isEmpty else { return nil }
        return (days, holiday, rest)
    }

    /// «07:00-20:00,21:00-23:00» → intervalli; la fine prima dell'inizio passa la mezzanotte
    private static func parseTimes(_ text: String) -> [Interval]? {
        var out: [Interval] = []
        for span in text.split(separator: ",") {
            let ends = span.trimmingCharacters(in: .whitespaces).split(separator: "-").map { $0.trimmingCharacters(in: .whitespaces) }
            guard ends.count == 2, let a = minutes(ends[0]), let b = minutes(ends[1]) else { return nil }
            out.append(Interval(start: a, end: b <= a ? b + 1440 : b))
        }
        return out.isEmpty ? nil : out
    }

    /// «7:30», «07:30», «7.30» → minuti; «24:00» = 1440
    private static func minutes(_ s: String) -> Int? {
        let parts = s.split(whereSeparator: { $0 == ":" || $0 == "." })
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]),
              parts[1].count == 2, (0...24).contains(h), (0...59).contains(m), h * 60 + m <= 1440 else { return nil }
        return h * 60 + m
    }

    /// Aperto a quell'ora? I festivi contano solo se la stringa ne parla (PH)
    func isOpen(at date: Date, calendar: Calendar = RuleEngine.rome, holiday: Bool = false) -> Bool {
        if alwaysOpen { return true }
        let minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let wd = calendar.component(.weekday, from: date)
        let today = holiday ? (holidays ?? days[wd - 1]) : days[wd - 1]
        if today.contains(where: { minute >= $0.start && minute < min($0.end, 1440) }) { return true }
        // La coda dopo mezzanotte della fascia di ieri
        let yesterday = days[(wd + 5) % 7]
        return yesterday.contains { $0.end > 1440 && minute < $0.end - 1440 }
    }
}
