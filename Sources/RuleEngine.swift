import Foundation

// «Posso entrare, con questa auto, a quest'ora?» Quattro risposte, mai una sola:
// sì, no, con condizioni, non sicuro (e allora si rimanda alla fonte).

enum Verdict: Equatable {
    case yes(reason: String)
    case no(reason: String)
    case conditional(reason: String, condition: String)
    case unsure(reason: String)

    var title: String {
        switch self {
        case .yes: L("Yes, you can enter")
        case .no: L("No, don't enter")
        case .conditional: L("Yes, on one condition")
        case .unsure: L("Not sure")
        }
    }
}

struct Answer: Equatable {
    var verdict: Verdict
    var gatesOn: Bool
    var nextChange: Date?       // quando i varchi si accendono o si spengono
}

struct RuleEngine {
    var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Rome")!
        return c
    }()
    var now: () -> Date = Date.init
    /// Dopo questi giorni senza un controllo umano la scheda non è più «sicura».
    var staleAfterDays = 120

    func answer(zone: Zone, vehicle: Vehicle, permits: [Permit], hotelInside: Bool, at date: Date) -> Answer {
        let on = isActive(zone, at: date)
        let next = nextChange(zone, after: date)

        if let age = calendar.dateComponents([.day], from: zone.source.checkedOn, to: now()).day, age > staleAfterDays {
            return Answer(verdict: .unsure(reason: String(format: L("This zone hasn't been checked for %lld days. Look at the city's page before driving in."), age)),
                          gatesOn: on, nextChange: next)
        }
        if zone.freeOnHolidays == nil && ItalianHolidays.isHoliday(date, calendar: calendar) && isActive(zone, at: date, ignoringHolidays: true) {
            return Answer(verdict: .unsure(reason: L("It's a public holiday and we haven't confirmed whether the gates are off. Check the sign at the gate.")),
                          gatesOn: true, nextChange: next)
        }
        guard on else {
            let until = next.map { " " + String(format: L("The gates switch back on %@."), describe($0, from: date)) } ?? ""
            return Answer(verdict: .yes(reason: L("The gates are off.") + until), gatesOn: false, nextChange: next)
        }
        let mine = permits.filter { $0.covers(zone: zone, vehicle: vehicle, at: date) }
        if mine.contains(where: { $0.status == .confirmed }) {
            return Answer(verdict: .yes(reason: L("The gates are on, but your permit covers this vehicle.")), gatesOn: true, nextChange: next)
        }
        if zone.exemptFuels.contains(vehicle.fuel) {
            return Answer(verdict: .yes(reason: String(format: L("The gates are on, but %@ vehicles may enter."), vehicle.fuel.label.lowercased())), gatesOn: true, nextChange: next)
        }
        if mine.contains(where: { $0.status == .waiting }) {
            return Answer(verdict: .conditional(reason: L("The gates are on."), condition: L("Your permit is still waiting for confirmation. Drive in only once it's confirmed.")),
                          gatesOn: true, nextChange: next)
        }
        if hotelInside && zone.hotelCanRegister {
            return Answer(verdict: .conditional(reason: L("The gates are on."), condition: L("You can drive to the hotel only if the hotel registers your plate with the city.")),
                          gatesOn: true, nextChange: next)
        }
        if let ticket = zone.ticket {
            return Answer(verdict: .conditional(reason: L("The gates are on."),
                                                condition: String(format: L("You can enter with the day ticket (%@). %@"), ticket.priceText, ticket.howTo)),
                          gatesOn: true, nextChange: next)
        }
        let off = next.map { " " + String(format: L("They switch off %@."), describe($0, from: date)) } ?? ""
        return Answer(verdict: .no(reason: L("The gates are on.") + off), gatesOn: true, nextChange: next)
    }

    // MARK: Orari

    func isActive(_ zone: Zone, at date: Date, ignoringHolidays: Bool = false) -> Bool {
        if !ignoringHolidays && zone.freeOnHolidays == true && ItalianHolidays.isHoliday(date, calendar: calendar) { return false }
        let weekday = calendar.component(.weekday, from: date)
        let minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let yesterday = weekday == 1 ? 7 : weekday - 1
        let dayBefore = calendar.date(byAdding: .day, value: -1, to: date)!
        return zone.windows.contains { w in
            if w.end > w.start {
                return w.weekdays.contains(weekday) && inSeason(w, date) && minute >= w.start && minute < w.end
            }
            // Fascia che passa la mezzanotte: la sera del giorno indicato o la notte dopo
            return (w.weekdays.contains(weekday) && inSeason(w, date) && minute >= w.start)
                || (w.weekdays.contains(yesterday) && inSeason(w, dayBefore) && minute < w.end)
        }
    }

    /// Il prossimo momento in cui lo stato cambia, cercato a passi di 5 minuti per 8 giorni.
    func nextChange(_ zone: Zone, after date: Date) -> Date? {
        let now = isActive(zone, at: date)
        var t = calendar.date(bySetting: .second, value: 0, of: date) ?? date
        let minute = calendar.component(.minute, from: t)
        t = calendar.date(byAdding: .minute, value: 5 - minute % 5, to: t)!
        for _ in 0..<(8 * 24 * 12) {
            if isActive(zone, at: t) != now { return t }
            t = calendar.date(byAdding: .minute, value: 5, to: t)!
        }
        return nil
    }

    /// L'ultimo momento in cui lo stato è cambiato (per la barra «da quando / fino a quando»)
    func previousChange(_ zone: Zone, before date: Date) -> Date? {
        let now = isActive(zone, at: date)
        var t = calendar.date(bySetting: .second, value: 0, of: date) ?? date
        t = calendar.date(byAdding: .minute, value: -(calendar.component(.minute, from: t) % 5), to: t)!
        for _ in 0..<(8 * 24 * 12) {
            let before = calendar.date(byAdding: .minute, value: -5, to: t)!
            if isActive(zone, at: before) != now { return t }
            t = before
        }
        return nil
    }

    private func inSeason(_ w: TimeWindow, _ date: Date) -> Bool {
        guard let s = w.season else { return true }
        let md = calendar.component(.month, from: date) * 100 + calendar.component(.day, from: date)
        let from = s.fromMonth * 100 + s.fromDay, to = s.toMonth * 100 + s.toDay
        return from <= to ? (md >= from && md <= to) : (md >= from || md <= to)
    }

    func describe(_ date: Date, from ref: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.timeZone = calendar.timeZone
        f.timeStyle = .short
        let time = f.string(from: date)
        if calendar.isDate(date, inSameDayAs: ref) { return String(format: L("today at %@"), time) }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: ref), calendar.isDate(date, inSameDayAs: tomorrow) { return String(format: L("tomorrow at %@"), time) }
        f.timeStyle = .none
        f.dateFormat = "EEEE"
        return String(format: L("on %@ at %@"), f.string(from: date), time)
    }
}

enum ItalianHolidays {
    static func isHoliday(_ date: Date, calendar: Calendar) -> Bool {
        let y = calendar.component(.year, from: date)
        let m = calendar.component(.month, from: date), d = calendar.component(.day, from: date)
        if calendar.component(.weekday, from: date) == 1 { return false }   // la domenica la decide l'orario
        let fixed: Set<Int> = [101, 106, 425, 501, 602, 815, 1101, 1208, 1225, 1226]
        if fixed.contains(m * 100 + d) { return true }
        let easter = easterSunday(y)
        let monday = calendar.date(byAdding: .day, value: 1, to: calendar.date(from: easter)!)!
        return calendar.isDate(date, inSameDayAs: monday)
    }

    /// Pasqua (algoritmo di Gauss/Meeus, calendario gregoriano)
    static func easterSunday(_ y: Int) -> DateComponents {
        let a = y % 19, b = y / 100, c = y % 100, d = b / 4, e = b % 4
        let f = (b + 8) / 25, g = (b - f + 1) / 3, h = (19 * a + b - d - g + 15) % 30
        let i = c / 4, k = c % 4, l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31, day = (h + l - 7 * m + 114) % 31 + 1
        return DateComponents(year: y, month: month, day: day, hour: 12)
    }
}
