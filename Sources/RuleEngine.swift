import Foundation

// «Posso entrare, con questa auto, a quest'ora?» Quattro risposte, mai una sola:
// sì, no, con condizioni, non sicuro (e allora si rimanda alla fonte).

enum Verdict: Equatable {
    case yes(reason: String)
    case no(reason: String)
    case conditional(reason: String, condition: String)
    case unsure(reason: String)

    /// 1.20.3 «Parole»: il titolo fisso della risposta (AnswerWord), lo stesso ovunque
    var title: String { word(unofficial: false).title }
}

/// 1.20.3 «Parole»: la risposta detta con UNA sola forma per lingua, ovunque (Varco, Mappa, Viaggio, notifiche, widget,
/// Live Activity, CarPlay, Siri; le stesse parole su Android, AnswerWord.kt, e sul sito, «w*» in web/template.html).
/// 2.1 «Una risposta, sette stati»: una parola per ogni stato della RispostaFinale (Stato.word); «ZTL non attiva» e «Fuori
/// dalla ZTL» hanno la loro. «Probabilmente sì», «Area pedonale»… restano la frase di spiegazione, mai il titolo
enum AnswerWord: String, CaseIterable {
    /// Rosso: «no» del motore, area pedonale, «no» da fonte non ufficiale
    case dontEnter
    /// Verde: «sì» (anche a ZTL non attiva) e fuori dalle zone di una città che conosciamo
    case enter
    /// Giallo con «!»: la risposta con una condizione (ticket, hotel, permesso in attesa)
    case condition
    /// Giallo con «?»: «non sicuro» del motore e il «sì» da fonte non ufficiale
    case checkSign
    /// Neutro: fuori dalle città che conosciamo
    case unknownPlace
    /// 2.1: la ZTL non attiva (varchi spenti), con il suo colore (Theme.stateOff, oggi verde)
    case notActive
    /// 2.1: fuori dalle zone di una città che conosciamo (grigio)
    case outside

    /// La chiave (inglese) del titolo in Localizable.strings
    var key: String {
        switch self {
        case .dontEnter: "Don't enter"
        case .enter: "You can enter"
        case .condition: "On one condition"
        case .checkSign: "Check the sign"
        case .unknownPlace: "We don't know this place"
        case .notActive: "ZTL not active"
        case .outside: "Outside the ZTL"
        }
    }

    /// Il titolo nella lingua del telefono
    var title: String { L(key) }

    /// Lo stesso titolo spezzato a mano in righe («|»), per i riquadri grandi
    var lineKey: String {
        switch self {
        case .dontEnter: "Don't|enter"
        case .enter: "You can|enter"
        case .condition: "On one|condition"
        case .checkSign: "Check the|sign"
        case .unknownPlace: "We don't know|this place"
        case .notActive: "ZTL not|active"
        case .outside: "Outside|the ZTL"
        }
    }
    var lines: [String] { L(lineKey).components(separatedBy: "|") }

    var symbol: String {
        switch self {
        case .dontEnter: "xmark"
        case .enter: "checkmark"
        case .condition: "exclamationmark"
        case .checkSign, .unknownPlace: "questionmark"
        case .notActive: "minus"
        case .outside: "mappin.and.ellipse"
        }
    }
}

extension Verdict {
    /// Il titolo fisso per la risposta del motore. Fonte non ufficiale (1.19.0): un «sì» si dice «Controlla il cartello»
    /// (giallo, «Probabilmente sì» resta la spiegazione); un «no» resta «Non entrare»
    func word(unofficial: Bool) -> AnswerWord {
        switch self {
        case .no: return .dontEnter
        case .conditional: return .condition
        case .unsure: return .checkSign
        case .yes: return unofficial ? .checkSign : .enter
        }
    }

    /// La frase di spiegazione delle risposte da fonte non ufficiale (mai titolo): «Probabilmente sì · fonte non ufficiale»
    func unofficialNote(unofficial: Bool) -> String? {
        guard unofficial else { return nil }
        switch self {
        case .yes: return L("Probably yes · unofficial source")
        case .no: return L("Probably not · unofficial source")
        case .conditional, .unsure: return L("Unofficial source")
        }
    }
}

extension Verdict {
    /// 1.19.0 «Mai un verde che non sappiamo»: la risposta come si MOSTRA. Un «sì» da fonte non ufficiale non è mai
    /// verde: si mostra come «non sicuro» (giallo con «?», «Probabilmente sì · fonte non ufficiale: controlla il cartello»).
    /// Le parole prudenti restano quelle di shortText(unofficial:) e titleLines(unofficial:); il motore non cambia.
    func shown(unofficial: Bool) -> Verdict {
        if unofficial, case .yes(let reason) = self { return .unsure(reason: reason) }
        return self
    }

    /// Quanto è grave per chi guida, per scegliere la peggiore tra più zone che contengono lo stesso posto
    /// (Settore A dentro lo Scudo Verde, Area C dentro l'Area B): no > condizione > non sicuro > sì
    var severity: Int {
        switch self {
        case .no: 3
        case .conditional: 2
        case .unsure: 1
        case .yes: 0
        }
    }

    var isYes: Bool {
        if case .yes = self { return true }
        return false
    }

    /// Il motivo (e la condizione) in una frase
    var detailText: String {
        switch self {
        case .yes(let r), .no(let r), .unsure(let r): r
        case .conditional(let r, let c): "\(r) \(c)"
        }
    }
}

struct Answer: Equatable {
    var verdict: Verdict
    var gatesOn: Bool
    var nextChange: Date?       // quando i varchi si accendono o si spengono
    /// 2.1: il motivo del «non sicuro» (dati scaduti, festivo da confermare), per RispostaFinale (shared/risposta-finale.md)
    var doubt: Motivo? = nil
}

/// 1.20.1 «Dati»: quanto ci si può fidare delle regole di una zona. Gli stessi stati su Android (DataTrust) e sul sito
/// (trustOf), provati dagli stessi casi (shared/engine-cases.json, «trust»). Regola A (decisa da Ledion): «verified» e
/// «read» danno la risposta normale (anche verde), gli altri mai verde
enum DataTrust: Equatable {
    /// Verificata da al più RuleEngine.staleAfterDays giorni, e la pagina del Comune non è cambiata dopo
    case verified
    /// Senza una verifica recente, ma letta da al più RuleEngine.staleAfterDays giorni e la pagina del Comune non è
    /// cambiata da quella lettura (tutte le zone dei file, oggi): la risposta normale
    case read
    /// Mai verificata e letta più di RuleEngine.staleAfterDays giorni fa
    case unverified
    /// Verificata più di RuleEngine.staleAfterDays giorni fa, e nessuna lettura più recente entro quei giorni
    case old
    /// La pagina del Comune è cambiata dopo la verifica (source.pageChanged, dalle impronte del controllo giornaliero)
    case pageChanged
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
    /// Dopo questi giorni dalla lettura (checkedOn) la zona è «da ricontrollare» (ogni risposta «non sicuro»);
    /// 1.20.1: e dopo questi giorni dalla verifica (verifiedOn) un «sì» non è più sicuro. 120 giorni su iPhone, Android
    /// e sito (docs/dati-verifica.md)
    var staleAfterDays = 120

    // MARK: Verifica dei dati (1.20.1 «Dati»)

    /// La pagina cambiata prima di tutto (rispetto alla verifica o alla lettura, Tools/source_trust.py), poi la verifica
    /// recente, poi la lettura recente (regola A)
    func trust(_ zone: Zone) -> DataTrust { trust(zone.source) }

    func trust(_ source: Source) -> DataTrust {
        if source.pageChanged == true { return .pageChanged }
        if let v = source.verifiedOn, age(v) <= staleAfterDays { return .verified }
        if age(source.checkedOn) <= staleAfterDays { return .read }
        return source.verifiedOn == nil ? .unverified : .old
    }

    /// Giorni da quella data a adesso
    /// 2.1 (B33): blocchi di 24 ore, come Android (ChronoUnit.DAYS) e il sito (Math.floor): prima giorni di calendario,
    /// e per un'ora intorno al 120° giorno l'iPhone dava verde dove gli altri davano «?»
    func age(_ d: Date) -> Int { Self.days(from: d, to: now()) }
    static func days(from a: Date, to b: Date) -> Int { Int((b.timeIntervalSince(a) / 86_400).rounded(.towardZero)) }

    /// La data più recente tra lettura e verifica: da qui contano i giorni dei «dati da ricontrollare»
    static func freshest(_ s: Source) -> Date { max(s.checkedOn, s.verifiedOn ?? .distantPast) }

    /// La riga breve accanto a «Letto il …» (risposta, CarPlay): «Verificato il 3 nov», «Non verificato», «Pagina del
    /// Comune cambiata». Una verifica vecchia mostra la sua data (il motivo del «?» lo dice la risposta)
    func verifiedShort(_ source: Source) -> String {
        switch trust(source) {
        case .pageChanged: L("City page changed")
        case .unverified, .read: L("Not verified")
        case .verified, .old:
            source.verifiedOn.map { String(format: L("Verified %@"), Self.format($0, .dateTime.day().month(), calendar: calendar)) } ?? L("Not verified")
        }
    }

    /// La frase della scheda della zona, sotto «Letto dalle fonti ufficiali il …»
    func verifiedSentence(_ source: Source) -> String {
        let long = { (d: Date) in self.day(d, style: .long) }
        switch trust(source) {
        case .pageChanged: return L("The city's page has changed since we last read or verified it: check the sign.")
        case .unverified: return L("Not verified yet: check the sign.")
        case .read: return L("Not verified by a person yet.")
        case .old:
            guard let v = source.verifiedOn else { return L("Not verified yet: check the sign.") }
            return String(format: L("Verified on %@, more than %lld days ago: check the sign."), long(v), staleAfterDays)
        case .verified:
            guard let v = source.verifiedOn else { return L("Not verified yet: check the sign.") }
            return String(format: L("Verified by a person on %@."), long(v))
        }
    }

    /// La risposta da MOSTRARE (Store.answer, widget, avvisi, casi comuni): quella delle regole con la verifica dei dati.
    /// `answer` resta la sola regola, per i test delle regole
    func trustedAnswer(zone: Zone, vehicle: Vehicle, permits: [Permit], hotelInside: Bool, at date: Date) -> Answer {
        applyTrust(answer(zone: zone, vehicle: vehicle, permits: permits, hotelInside: hotelInside, at: date), zone: zone)
    }

    /// Pagina del Comune cambiata dopo la verifica: ogni risposta diventa «non sicuro» (giallo «?»), anche il «no».
    /// Zona ufficiale non verificata o con la verifica vecchia: un «sì» (verde, o grigio a ZTL spenta) diventa «non sicuro»;
    /// «no» e condizioni restano. Le zone da fonti non ufficiali hanno già il «sì» giallo (Verdict.shown(unofficial:))
    func applyTrust(_ a: Answer, zone: Zone) -> Answer {
        var out = a
        switch trust(zone) {
        case .pageChanged:
            out.verdict = .unsure(reason: L("The city's page has changed: check the sign.") + " " + a.verdict.detailText)
            out.doubt = .scaduti
        case .unverified, .old:
            // Di solito c'è già il «non sicuro» dei dati da ricontrollare (answer): questa è la rete di sicurezza
            guard zone.source.isOfficial, case .yes(let r) = a.verdict else { return a }
            let why = trust(zone) == .old ? String(format: L("Last verified more than %lld days ago: check the sign."), staleAfterDays)
                                          : L("This rule hasn't been verified yet: check the sign.")
            out.verdict = .unsure(reason: why + " " + r)
            out.doubt = .scaduti
        case .verified, .read:
            break
        }
        return out
    }

    func answer(zone: Zone, vehicle: Vehicle, permits: [Permit], hotelInside: Bool, at date: Date) -> Answer {
        let on = isActive(zone, at: date)
        let next = nextChange(zone, after: date)

        // 1.20.1: dalla data più recente tra «letto il» e «verificato il»
        let dataAge = age(Self.freshest(zone.source))
        if dataAge > staleAfterDays {
            return Answer(verdict: .unsure(reason: String(format: L("This zone hasn't been checked for %lld days. Look at the city's page before driving in."), dataAge)),
                          gatesOn: on, nextChange: next, doubt: .scaduti)
        }
        // 2.1: un giorno in cui la fonte ufficiale non dice se la ZTL è attiva (uncertainDays): mai una risposta certa
        if let days = zone.uncertainDays, activeStartDays(zone, at: date).contains(where: { days.contains(Self.monthDay($0, calendar: calendar)) }) {
            return Answer(verdict: .unsure(reason: L("On this day the city doesn't say whether the ZTL is active. Check the sign at the gate.")),
                          gatesOn: true, nextChange: next, doubt: .festivo)
        }
        if zone.freeOnHolidays == nil && activeStartDays(zone, at: date).contains(where: { isHoliday(zone, $0) }) {
            return Answer(verdict: .unsure(reason: L("It's a public holiday and we haven't confirmed whether the gates are off. Check the sign at the gate.")),
                          gatesOn: true, nextChange: next, doubt: .festivo)
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
        // Moto e scooter: i limiti loro, dove una fonte ufficiale li scrive («motoBans», 1.17.2)
        if vehicle.kind == .motorcycle && zone.motoBans != nil {
            if zone.motoBan(for: vehicle, at: date) != nil {
                return Answer(verdict: .no(reason: String(format: L("Motorbikes and scooters Euro %lld (%@) can't enter this zone while it's active."),
                                                         vehicle.euro, Self.motoText(vehicle))), gatesOn: true, nextChange: next)
            }
            if zone.type == .green {
                let until = zone.nextMotoBan(for: vehicle, after: date).map { " " + String(format: L("Until %@."), day($0.date, style: .long)) } ?? ""
                return Answer(verdict: .yes(reason: String(format: L("Your motorbike (%@, Euro %lld) is allowed in this low-emission zone."),
                                                          Self.motoText(vehicle), vehicle.euro) + until), gatesOn: true, nextChange: next)
            }
        }
        // I divieti per classe Euro sono scritti per le auto: senza «motoBans» le moto hanno limiti loro, che GateLR non ha
        else if vehicle.kind == .motorcycle && zone.bans != nil {
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

    /// "MM-DD" di un giorno, in ora italiana (giorni incerti e feste del patrono)
    static func monthDay(_ d: Date, calendar: Calendar) -> String {
        String(format: "%02d-%02d", calendar.component(.month, from: d), calendar.component(.day, from: d))
    }

    /// «ciclomotore 2 tempi», «motociclo 4 tempi»
    static func motoText(_ v: Vehicle) -> String {
        String(format: L(v.strokes == 2 ? "%@, 2-stroke" : "%@, 4-stroke"), v.motoCategory == .moped ? L("moped") : L("motorbike"))
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
        let weekday = effectiveWeekdays(zone, date)
        let yesterday = effectiveWeekdays(zone, dayBefore)
        var out: [Date] = []
        for w in zone.windows {
            let today = !weekday.isDisjoint(with: w.weekdays), before = !yesterday.isDisjoint(with: w.weekdays)
            if w.end > w.start {
                if today && inSeason(w, date) && minute >= w.start && minute < w.end { out.append(date) }
                continue
            }
            // Fascia che passa la mezzanotte: la sera del giorno indicato o la notte dopo
            if today && inSeason(w, date) && minute >= w.start { out.append(date) }
            if before && inSeason(w, dayBefore) && minute < w.end { out.append(dayBefore) }
        }
        return out
    }

    /// I giorni della settimana per gli orari: un festivo conta come domenica se la zona lo dice (holidaysAsSunday)
    private func effectiveWeekdays(_ zone: Zone, _ day: Date) -> Set<Int> {
        let real = calendar.component(.weekday, from: day)
        if zone.holidaysAsSunday == true && isHoliday(zone, day) { return [1] }
        return [real]
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
        // 2.1 (B24): San Francesco, 4 ottobre, festa nazionale dal 2026 (L. 8 ottobre 2025 n. 151)
        if m == 10 && d == 4 && y >= 2026 { return true }
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
