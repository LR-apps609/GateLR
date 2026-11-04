package app.gatelr.core

import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.temporal.ChronoUnit

// «Posso entrare, con questa auto, a quest'ora?» Quattro risposte, mai una sola:
// sì, no, con condizioni, non sicuro. Stesso ordine delle regole dell'app iPhone (Sources/RuleEngine.swift).

sealed class Verdict {
    data class Yes(val reason: String) : Verdict()
    data class No(val reason: String) : Verdict()
    data class Conditional(val reason: String, val condition: String) : Verdict()
    data class Unsure(val reason: String) : Verdict()

    /** 1.20.3 «Parole»: il titolo fisso (AnswerWord), lo stesso ovunque; prima «Sì, puoi entrare», «Non sicuro»… */
    val title: String get() = word(false).title
    val short: String get() = word(false).title

    /** Il titolo fisso per questa risposta. Fonte non ufficiale: un «sì» si dice «Controlla il cartello», un «no» resta «Non entrare» */
    fun word(unofficial: Boolean): AnswerWord = when (this) {
        is No -> AnswerWord.DONT_ENTER
        is Conditional -> AnswerWord.CONDITION
        is Unsure -> AnswerWord.CHECK_SIGN
        is Yes -> if (unofficial) AnswerWord.CHECK_SIGN else AnswerWord.ENTER
    }

    /** La spiegazione delle risposte da fonte non ufficiale (mai titolo): «Probabilmente sì · fonte non ufficiale» */
    fun unofficialNote(unofficial: Boolean): String? = if (!unofficial) null else when (this) {
        is Yes -> L("Probably yes · unofficial source")
        is No -> L("Probably not · unofficial source")
        else -> L("Unofficial source")
    }
    val detail: String get() = when (this) {
        is Yes -> reason; is No -> reason; is Unsure -> reason; is Conditional -> "$reason $condition"
    }

    /** 1.19.0 dell'iPhone «Mai un verde che non sappiamo»: la risposta come si MOSTRA. Un «sì» da fonte non ufficiale
     *  non è mai verde: «non sicuro» (giallo con «?», «Probabilmente sì · fonte non ufficiale: controlla il cartello») */
    fun shown(unofficial: Boolean): Verdict = if (unofficial && this is Yes) Unsure(reason) else this

    /** Quanto è grave, per scegliere la peggiore tra più zone dello stesso posto: no > condizione > non sicuro > sì */
    val severity: Int get() = when (this) { is No -> 3; is Conditional -> 2; is Unsure -> 1; is Yes -> 0 }
}

/**
 * 1.20.3 «Parole»: la risposta detta con UNA sola forma per lingua, come l'iPhone (AnswerWord in Sources/RuleEngine.swift)
 * e il sito. Il titolo è sempre una di queste cinque frasi; «Probabilmente sì», «Fuori dalla ZTL», «Area pedonale»,
 * «ZTL non attiva» sono la spiegazione, mai il titolo. Solo parole: colori e risposte non cambiano.
 */
enum class AnswerWord(val key: String, val lineKey: String, val symbol: String) {
    DONT_ENTER("Don't enter", "Don't|enter", "✕"),
    ENTER("You can enter", "You can|enter", "✓"),
    CONDITION("On one condition", "On one|condition", "!"),
    CHECK_SIGN("Check the sign", "Check the|sign", "?"),
    UNKNOWN_PLACE("We don't know this place", "We don't know|this place", "?");

    val title: String get() = L(key)
    val lines: List<String> get() = L(lineKey).split("|")
}

data class Answer(val verdict: Verdict, val gatesOn: Boolean, val nextChange: Instant?)

/** 1.20.1 «Dati»: quanto ci si può fidare delle regole di una zona (come DataTrust dell'iPhone e trustOf del sito).
 *  Regola A (decisa da Ledion): VERIFIED e READ danno la risposta normale (anche verde), gli altri mai verde */
enum class DataTrust {
    /** Verificata da al più [RuleEngine.staleAfterDays] giorni e pagina del Comune non cambiata dopo la verifica */
    VERIFIED,
    /** Senza verifica recente ma letta da al più [RuleEngine.staleAfterDays] giorni, pagina non cambiata da allora */
    READ,
    /** Mai verificata e letta più di [RuleEngine.staleAfterDays] giorni fa */
    UNVERIFIED,
    /** Verificata più di [RuleEngine.staleAfterDays] giorni fa e nessuna lettura più recente entro quei giorni */
    OLD,
    /** La pagina del Comune è cambiata dopo la verifica (source.pageChanged) */
    PAGE_CHANGED,
}

class RuleEngine(
    var now: () -> Instant = { Instant.now() },
    /** Dopo questi giorni dalla lettura (checkedOn) la zona è «da ricontrollare»; 1.20.1: e dopo questi giorni dalla
     *  verifica (verifiedOn) un «sì» non è più sicuro. 120 giorni su iPhone, Android e sito (docs/dati-verifica.md) */
    var staleAfterDays: Long = 120,
) {
    companion object { val ROME: ZoneId = ZoneId.of("Europe/Rome") }

    /** 1.20.1 «Dati»: la pagina cambiata prima di tutto, poi la verifica recente, poi la lettura recente (regola A) */
    fun trust(zone: Zone): DataTrust {
        if (zone.source.pageChanged == true) return DataTrust.PAGE_CHANGED
        val v = zone.source.verified
        if (v != null && ChronoUnit.DAYS.between(v, now()) <= staleAfterDays) return DataTrust.VERIFIED
        if (ChronoUnit.DAYS.between(zone.source.checked, now()) <= staleAfterDays) return DataTrust.READ
        return if (v == null) DataTrust.UNVERIFIED else DataTrust.OLD
    }

    /** La data più recente tra lettura e verifica: da qui contano i giorni dei «dati da ricontrollare» */
    fun freshest(s: Source): Instant = s.verified?.takeIf { it > s.checked } ?: s.checked

    /** La risposta da mostrare (app, widget, guardiano, casi comuni): quella del motore con la verifica dei dati.
     *  [answer] resta la sola regola, per i test delle regole */
    fun trustedAnswer(zone: Zone, vehicle: Vehicle, permits: List<Permit>, hotelInside: Boolean, at: Instant): Answer =
        applyTrust(answer(zone, vehicle, permits, hotelInside, at), zone)

    /** Pagina del Comune cambiata dopo la verifica: ogni risposta diventa «non sicuro» (giallo «?»), anche il «no».
     *  Zona ufficiale non verificata o con verifica vecchia: un «sì» (verde o grigio) diventa «non sicuro»; «no» e
     *  condizioni restano. Le zone da fonti non ufficiali hanno già il «sì» giallo (Verdict.shown) */
    fun applyTrust(a: Answer, zone: Zone): Answer {
        val t = trust(zone)
        val v = a.verdict
        if (t == DataTrust.PAGE_CHANGED) return a.copy(verdict = Verdict.Unsure(L("The city's page has changed: check the sign.") + " " + v.detail))
        if ((t == DataTrust.UNVERIFIED || t == DataTrust.OLD) && zone.source.isOfficial && v is Verdict.Yes) {
            val why = if (t == DataTrust.OLD) F("Last verified more than %lld days ago: check the sign.", staleAfterDays) else L("This rule hasn't been verified yet: check the sign.")
            return a.copy(verdict = Verdict.Unsure(why + " " + v.reason))
        }
        return a
    }

    fun answer(zone: Zone, vehicle: Vehicle, permits: List<Permit>, hotelInside: Boolean, at: Instant): Answer {
        val on = isActive(zone, at)
        val next = nextChange(zone, at)

        val age = ChronoUnit.DAYS.between(freshest(zone.source), now())      // 1.20.1: lettura o verifica, la più recente
        if (age > staleAfterDays) {
            return Answer(Verdict.Unsure(F("This zone hasn't been checked for %lld days. Look at the city's page before driving in.", age)), on, next)
        }
        if (zone.freeOnHolidays == null && activeStartDays(zone, at).any { isHoliday(zone, it) }) {
            return Answer(Verdict.Unsure(L("It's a public holiday and we haven't confirmed whether the gates are off. Check the sign at the gate.")), true, next)
        }
        if (!on) {
            val until = next?.let { " " + F("It becomes active again %@.", describe(it, at)) } ?: ""
            return Answer(Verdict.Yes(L("The ZTL is not active.") + until), false, next)
        }
        val mine = permits.filter { it.covers(zone, vehicle, at) }
        if (mine.any { it.status == Permit.Status.CONFIRMED }) {
            return Answer(Verdict.Yes(L("The ZTL is active, but your permit covers this vehicle.")), true, next)
        }
        // Prima il tipo di veicolo, poi alimentazione e classe Euro (come Sources/RuleEngine.swift)
        if (zone.exempts(vehicle)) {
            return Answer(Verdict.Yes(L("The ZTL is active, but motorbikes and scooters may enter.")), true, next)
        }
        if (vehicle.fuel in zone.exemptFuels) {
            return Answer(Verdict.Yes(F("The ZTL is active, but %@ vehicles may enter.", vehicle.fuel.label.lowercase())), true, next)
        }
        if (mine.any { it.status == Permit.Status.WAITING }) {
            return Answer(Verdict.Conditional(L("The ZTL is active."), L("Your permit is still waiting for confirmation. Drive in only once it's confirmed.")), true, next)
        }
        // Moto e scooter: i limiti loro, dove una fonte ufficiale li scrive («motoBans», 1.17.2, come sull'iPhone)
        if (vehicle.kind == VehicleType.MOTORCYCLE && zone.motoBans != null) {
            val moto = F(if (vehicle.strokes == 2) "%@, 2-stroke" else "%@, 4-stroke", if (vehicle.motoCategory == "moped") L("moped") else L("motorbike"))
            if (zone.motoBan(vehicle, at) != null) {
                return Answer(Verdict.No(F("Motorbikes and scooters Euro %lld (%@) can't enter this zone while it's active.", vehicle.euro, moto)), true, next)
            }
            if (zone.type == ZoneKind.GREEN) {
                val until = zone.nextMotoBan(vehicle, at)?.let { " " + F("Until %@.", it.since) } ?: ""
                return Answer(Verdict.Yes(F("Your motorbike (%@, Euro %lld) is allowed in this low-emission zone.", moto, vehicle.euro) + until), true, next)
            }
        }
        // I divieti per classe Euro sono scritti per le auto: senza «motoBans» le moto hanno limiti loro
        else if (vehicle.kind == VehicleType.MOTORCYCLE && zone.bans != null) {
            return Answer(Verdict.Conditional(if (zone.type == ZoneKind.GREEN) L("The low-emission zone is active.") else L("The ZTL is active."),
                L("Motorbikes have their own Euro limits here. Check yours on the city's page.")), true, next)
        }
        if (zone.ban(vehicle, at) != null) {
            return Answer(Verdict.No(F("%@ Euro %lld cars can't enter this zone while it's active, not even with a ticket. A few free days a year may apply: see the city's page.",
                vehicle.fuel.label, vehicle.euro)), true, next)
        }
        if (zone.bans != null && zone.type == ZoneKind.GREEN) {
            val until = zone.nextBan(vehicle, at)?.let { " " + F("Until %@.", it.since) } ?: ""
            return Answer(Verdict.Yes(F("Your car (%@ Euro %lld) is allowed in this low-emission zone.", vehicle.fuel.label, vehicle.euro) + until), true, next)
        }
        if (zone.type == ZoneKind.GREEN) {
            return Answer(Verdict.Conditional(L("The low-emission zone is active."),
                L("Most cars can enter; the most polluting can't. Check your car on the city's page.")), true, next)
        }
        if (hotelInside && zone.hotelCanRegister) {
            return Answer(Verdict.Conditional(L("The ZTL is active."), L("You can drive to the hotel only if the hotel registers your plate with the city.")), true, next)
        }
        zone.ticket?.let { t ->
            return Answer(Verdict.Conditional(L("The ZTL is active."), F("You can enter with the day ticket (%@). %@", "€" + String.format("%.2f", t.price), t.localizedHowTo)), true, next)
        }
        val off = next?.let { " " + F("It ends %@.", describe(it, at)) } ?: ""
        return Answer(Verdict.No(L("The ZTL is active.") + off), true, next)
    }

    // ---- Orari

    /** 1 = domenica … 7 = sabato, come Calendar dell'iPhone */
    private fun weekday(d: ZonedDateTime): Int = d.dayOfWeek.value % 7 + 1

    fun isActive(zone: Zone, at: Instant, ignoringHolidays: Boolean = false): Boolean {
        val starts = activeStartDays(zone, at)
        if (ignoringHolidays || zone.freeOnHolidays != true) return starts.isNotEmpty()
        return starts.any { !isHoliday(zone, it) }
    }

    /** I giorni in cui sono iniziate le fasce accese in questo momento (festivi a parte).
     *  Per la parte dopo mezzanotte di una fascia notturna il giorno è quello prima: la notte
     *  tra sabato festivo e domenica è libera, quella tra venerdì e un sabato festivo no. */
    private fun activeStartDays(zone: Zone, at: Instant): List<LocalDate> {
        val d = at.atZone(ROME)
        val minute = d.hour * 60 + d.minute
        val dayBefore = d.minusDays(1)
        // Un festivo conta come domenica se la zona lo dice (holidaysAsSunday), come effectiveWeekday dell'iPhone
        val wd = effectiveWeekday(zone, d)
        val yesterday = effectiveWeekday(zone, dayBefore)
        val out = mutableListOf<LocalDate>()
        for (w in zone.windows) {
            if (w.end > w.start) {
                if (wd in w.weekdays && inSeason(w, d) && minute >= w.start && minute < w.end) out += d.toLocalDate()
                continue
            }
            // Fascia che passa la mezzanotte: la sera del giorno indicato o la notte dopo
            if (wd in w.weekdays && inSeason(w, d) && minute >= w.start) out += d.toLocalDate()
            if (yesterday in w.weekdays && inSeason(w, dayBefore) && minute < w.end) out += dayBefore.toLocalDate()
        }
        return out
    }

    /** Il giorno della settimana per gli orari: un festivo conta come domenica se la zona lo dice (holidaysAsSunday) */
    private fun effectiveWeekday(zone: Zone, d: ZonedDateTime): Int =
        if (zone.holidaysAsSunday == true && isHoliday(zone, d.toLocalDate())) 1 else weekday(d)

    /** Festivo nazionale o festa del patrono della città della zona */
    fun isHoliday(zone: Zone, day: LocalDate): Boolean = ItalianHolidays.isHoliday(day, zone.localHolidays)

    private fun inSeason(w: TimeWindow, d: ZonedDateTime): Boolean {
        val s = w.season ?: return true
        return s.contains(d.toLocalDate())
    }

    /** I soli istanti in cui lo stato può cambiare: inizio e fine delle fasce e le mezzanotti */
    private fun boundaries(zone: Zone, around: Instant, back: Int, forward: Int): List<Instant> {
        val today = around.atZone(ROME).toLocalDate()
        val out = mutableListOf<Instant>()
        for (n in -back..forward) {
            val day = today.plusDays(n.toLong())
            out += day.atStartOfDay(ROME).toInstant()
            for (w in zone.windows) for (m in listOf(w.start, w.end)) if (m in 1 until 24 * 60) {
                out += day.atTime(m / 60, m % 60).atZone(ROME).toInstant()
            }
        }
        return out
    }

    fun nextChange(zone: Zone, after: Instant): Instant? {
        val now = isActive(zone, after)
        return boundaries(zone, after, 0, 8).filter { it.isAfter(after) }.sorted().firstOrNull { isActive(zone, it) != now }
    }

    fun previousChange(zone: Zone, before: Instant): Instant? {
        val now = isActive(zone, before)
        return boundaries(zone, before, 8, 0).filter { !it.isAfter(before) }.sortedDescending()
            .firstOrNull { isActive(zone, it.minusSeconds(60)) != now && isActive(zone, it) == now }
    }

    fun describe(date: Instant, from: Instant): String {
        val d = date.atZone(ROME); val r = from.atZone(ROME)
        val time = String.format("%02d:%02d", d.hour, d.minute)
        return when (d.toLocalDate()) {
            r.toLocalDate() -> F("today at %@", time)
            r.toLocalDate().plusDays(1) -> F("tomorrow at %@", time)
            else -> F("on %@ at %@", d.dayOfWeek.getDisplayName(java.time.format.TextStyle.FULL, java.util.Locale.forLanguageTag(Strings.language)), time)
        }
    }
}

object ItalianHolidays {
    fun isHoliday(at: Instant): Boolean = isHoliday(at.atZone(RuleEngine.ROME).toLocalDate())

    /** «local»: le feste del patrono della città, come "MM-DD" (es. "06-29" a Roma) */
    fun isHoliday(d: LocalDate, local: List<String>? = null): Boolean {
        if (d.dayOfWeek == DayOfWeek.SUNDAY) return false      // la domenica la decide l'orario
        val fixed = setOf(101, 106, 425, 501, 602, 815, 1101, 1208, 1225, 1226)
        if (d.monthValue * 100 + d.dayOfMonth in fixed) return true
        if (local != null && String.format(java.util.Locale.ROOT, "%02d-%02d", d.monthValue, d.dayOfMonth) in local) return true
        return d == easterSunday(d.year).plusDays(1)
    }

    /** Pasqua (Gauss/Meeus, calendario gregoriano) */
    fun easterSunday(y: Int): LocalDate {
        val a = y % 19; val b = y / 100; val c = y % 100; val d = b / 4; val e = b % 4
        val f = (b + 8) / 25; val g = (b - f + 1) / 3; val h = (19 * a + b - d - g + 15) % 30
        val i = c / 4; val k = c % 4; val l = (32 + 2 * e + 2 * i - h - k) % 7
        val m = (a + 11 * h + 22 * l) / 451
        val month = (h + l - 7 * m + 114) / 31; val day = (h + l - 7 * m + 114) % 31 + 1
        return LocalDate.of(y, month, day)
    }
}
