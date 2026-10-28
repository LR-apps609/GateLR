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
    /// Il calendario delle regole: gregoriano, in ora italiana. Lo usano anche le date mostrate (viaggio, soggiorno, arrivo)
    static let rome: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Rome")!
        return c
    }()
    var calendar: Calendar = RuleEngine.rome
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
        if zone.freeOnHolidays == nil && activeStartDays(zone, at: date).contains(where: { isHoliday(zone, $0) }) {
            return Answer(verdict: .unsure(reason: L("It's a public holiday and we haven't confirmed whether the gates are off. Check the sign at the gate.")),
                          gatesOn: true, nextChange: next)
        }
        guard on else {
            let until = next.map { " " + String(format: L("It becomes active again %@."), describe($0, from: date)) } ?? ""
            return Answer(verdict: .yes(reason: L("The ZTL is not active.") + until), gatesOn: false, nextChange: next)
        }
        let mine = permits.filter { $0.covers(zone: zone, vehicle: vehicle, at: date) }
        if mine.contains(where: { $0.status == .confirmed }) {
            return Answer(verdict: .yes(reason: L("The ZTL is active, but your permit covers this vehicle.")), gatesOn: true, nextChange: next)
        }
        // Prima il tipo di veicolo, poi alimentazione e classe Euro (lo stesso ordine nel sito e su Android)
        if zone.exempts(vehicle) {
            return Answer(verdict: .yes(reason: L("The ZTL is active, but motorbikes and scooters may enter.")), gatesOn: true, nextChange: next)
        }
        if zone.exemptFuels.contains(vehicle.fuel) {
            return Answer(verdict: .yes(reason: String(format: L("The ZTL is active, but %@ vehicles may enter."), vehicle.fuel.label.lowercased())), gatesOn: true, nextChange: next)
        }
        if mine.contains(where: { $0.status == .waiting }) {
            return Answer(verdict: .conditional(reason: L("The ZTL is active."), condition: L("Your permit is still waiting for confirmation. Drive in only once it's confirmed.")),
                          gatesOn: true, nextChange: next)
        }
        // I divieti per classe Euro sono scritti per le auto: le moto hanno limiti loro, che GateLR non ha
        if vehicle.kind == .motorcycle && zone.bans != nil {
            return Answer(verdict: .conditional(reason: zone.type == .green ? L("The low-emission zone is active.") : L("The ZTL is active."),
                                                condition: L("Motorbikes have their own Euro limits here. Check yours on the city's page.")),
                          gatesOn: true, nextChange: next)
        }
        if zone.ban(for: vehicle, at: date) != nil {
            return Answer(verdict: .no(reason: String(format: L("%@ Euro %lld cars can't enter this zone while it's active, not even with a ticket. A few free days a year may apply: see the city's page."),
                                                     vehicle.fuel.label, vehicle.euro)), gatesOn: true, nextChange: next)
        }
        if zone.bans != nil && zone.type == .green {
            let until = zone.nextBan(for: vehicle, after: date).map { " " + String(format: L("Until %@."), day($0.date, style: .long)) } ?? ""
            return Answer(verdict: .yes(reason: String(format: L("Your car (%@ Euro %lld) is allowed in this low-emission zone."), vehicle.fuel.label, vehicle.euro) + until),
                          gatesOn: true, nextChange: next)
        }
        if zone.type == .green {
            return Answer(verdict: .conditional(reason: L("The low-emission zone is active."),
                                                condition: L("Most cars can enter; the most polluting can't. Check your car on the city's page.")),
                          gatesOn: true, nextChange: next)
        }
        if hotelInside && zone.hotelCanRegister {
            return Answer(verdict: .conditional(reason: L("The ZTL is active."), condition: L("You can drive to the hotel only if the hotel registers your plate with the city.")),
                          gatesOn: true, nextChange: next)
        }
        if let ticket = zone.ticket {
            return Answer(verdict: .conditional(reason: L("The ZTL is active."),
                                                condition: String(format: L("You can enter with the day ticket (%@). %@"), ticket.priceText, ticket.localizedHowTo)),
                          gatesOn: true, nextChange: next)
        }
        let off = next.map { " " + String(format: L("It ends %@."), describe($0, from: date)) } ?? ""
        return Answer(verdict: .no(reason: L("The ZTL is active.") + off), gatesOn: true, nextChange: next)
    }

    // MARK: Orari

    func isActive(_ zone: Zone, at date: Date, ignoringHolidays: Bool = false) -> Bool {
        let starts = activeStartDays(zone, at: date)
        if ignoringHolidays || zone.freeOnHolidays != true { return !starts.isEmpty }
        return starts.contains { !isHoliday(zone, $0) }
    }

    /// I giorni in cui sono iniziate le fasce accese in questo momento (festivi a parte).
    /// Per la parte dopo mezzanotte di una fascia notturna il giorno è quello prima: la notte
    /// tra sabato festivo e domenica è libera, quella tra venerdì e un sabato festivo no.
    private func activeStartDays(_ zone: Zone, at date: Date) -> [Date] {
        let minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let dayBefore = calendar.date(byAdding: .day, value: -1, to: date)!
        let weekday = effectiveWeekday(zone, date)
        let yesterday = effectiveWeekday(zone, dayBefore)
        var out: [Date] = []
        for w in zone.windows {
            if w.end > w.start {
                if w.weekdays.contains(weekday) && inSeason(w, date) && minute >= w.start && minute < w.end { out.append(date) }
                continue
            }
            // Fascia che passa la mezzanotte: la sera del giorno indicato o la notte dopo
            if w.weekdays.contains(weekday) && inSeason(w, date) && minute >= w.start { out.append(date) }
            if w.weekdays.contains(yesterday) && inSeason(w, dayBefore) && minute < w.end { out.append(dayBefore) }
        }
        return out
    }

    /// Il giorno della settimana per gli orari: un festivo conta come domenica se la zona lo dice (holidaysAsSunday)
    private func effectiveWeekday(_ zone: Zone, _ day: Date) -> Int {
        if zone.holidaysAsSunday == true && isHoliday(zone, day) { return 1 }
        return calendar.component(.weekday, from: day)
    }

    /// Festivo nazionale o festa del patrono della città della zona
    func isHoliday(_ zone: Zone, _ date: Date) -> Bool {
        ItalianHolidays.isHoliday(date, calendar: calendar, local: zone.localHolidays)
    }

    /// Il prossimo momento in cui lo stato cambia, cercato a passi di 5 minuti per 8 giorni.
    /// I soli istanti in cui lo stato può cambiare: inizio e fine di ogni fascia e le mezzanotti
    /// (festivi e stagioni), da «days» giorni prima a «days» giorni dopo. Pochi controlli invece di uno ogni 5 minuti.
    private func boundaries(_ zone: Zone, around date: Date, back: Int, forward: Int) -> [Date] {
        let today = calendar.startOfDay(for: date)
        var out: [Date] = []
        for d in -back...forward {
            guard let day = calendar.date(byAdding: .day, value: d, to: today) else { continue }
            out.append(day)
            for w in zone.windows {
                for m in [w.start, w.end] where m > 0 && m < 24 * 60 {
                    if let t = calendar.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: day) { out.append(t) }
                }
            }
        }
        return out
    }

    func nextChange(_ zone: Zone, after date: Date) -> Date? {
        let now = isActive(zone, at: date)
        return boundaries(zone, around: date, back: 0, forward: 8).filter { $0 > date }.sorted()
            .first { isActive(zone, at: $0) != now }
    }

    /// L'ultimo momento in cui lo stato è cambiato (per la barra «da quando / fino a quando»)
    func previousChange(_ zone: Zone, before date: Date) -> Date? {
        let now = isActive(zone, at: date)
        return boundaries(zone, around: date, back: 8, forward: 0).filter { $0 <= date }.sorted(by: >)
            .first { isActive(zone, at: $0.addingTimeInterval(-60)) != now && isActive(zone, at: $0) == now }
    }

    private func inSeason(_ w: TimeWindow, _ date: Date) -> Bool {
        guard let s = w.season else { return true }
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return s.contains(year: c.year ?? 2026, month: c.month ?? 1, day: c.day ?? 1)
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

    /// Il giorno in ora italiana («1 dicembre 2026»): le date dei divieti sono mezzanotti di Roma e,
    /// scritte nel fuso del telefono (es. New York), diventavano il giorno prima
    func day(_ date: Date, style: Date.FormatStyle.DateStyle = .long) -> String {
        var f = Date.FormatStyle(date: style, time: .omitted)
        f.timeZone = calendar.timeZone
        return date.formatted(f)
    }

    /// Una data in ora italiana con il formato dato («lun 2 nov, 18:00»): le stesse ore che usa il motore
    func format(_ date: Date, _ style: Date.FormatStyle) -> String {
        Self.format(date, style, calendar: calendar)
    }

    static func format(_ date: Date, _ style: Date.FormatStyle, calendar: Calendar = RuleEngine.rome) -> String {
        var f = style
        f.timeZone = calendar.timeZone
        return date.formatted(f)
    }

    /// L'ora di un cambio in ora italiana, come le frasi del motore: «20:00» se è lo stesso giorno di «ref»,
    /// altrimenti con il giorno («lun 07:30»). Prima il widget scriveva solo l'ora, nel fuso del telefono:
    /// il sabato sera «Inizia alle 07:30» voleva dire lunedì.
    func clock(_ date: Date, from ref: Date) -> String {
        var f = Date.FormatStyle(date: .omitted, time: .shortened)
        f.timeZone = calendar.timeZone
        return calendar.isDate(date, inSameDayAs: ref) ? date.formatted(f) : date.formatted(f.weekday(.abbreviated))
    }
}

enum ItalianHolidays {
    /// «local»: le feste del patrono della città, come "MM-DD" (es. "06-29" a Roma)
    static func isHoliday(_ date: Date, calendar: Calendar, local: [String]? = nil) -> Bool {
        let y = calendar.component(.year, from: date)
        let m = calendar.component(.month, from: date), d = calendar.component(.day, from: date)
        if calendar.component(.weekday, from: date) == 1 { return false }   // la domenica la decide l'orario
        let fixed: Set<Int> = [101, 106, 425, 501, 602, 815, 1101, 1208, 1225, 1226]
        if fixed.contains(m * 100 + d) { return true }
        if let local, local.contains(String(format: "%02d-%02d", m, d)) { return true }
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
