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

    val title: String get() = when (this) {
        is Yes -> L("Yes, you can enter"); is No -> L("No, don't enter")
        is Conditional -> L("Yes, on one condition"); is Unsure -> L("Not sure")
    }
    val short: String get() = when (this) {
        is Yes -> L("You can enter"); is No -> L("Don't enter")
        is Conditional -> L("On one condition"); is Unsure -> L("Not sure")
    }
    val detail: String get() = when (this) {
        is Yes -> reason; is No -> reason; is Unsure -> reason; is Conditional -> "$reason $condition"
    }
}

data class Answer(val verdict: Verdict, val gatesOn: Boolean, val nextChange: Instant?)

class RuleEngine(
    var now: () -> Instant = { Instant.now() },
    /** Dopo questi giorni senza un controllo umano la scheda non è più «sicura» */
    var staleAfterDays: Long = 120,
) {
    companion object { val ROME: ZoneId = ZoneId.of("Europe/Rome") }

    fun answer(zone: Zone, vehicle: Vehicle, permits: List<Permit>, hotelInside: Boolean, at: Instant): Answer {
        val on = isActive(zone, at)
        val next = nextChange(zone, at)

        val age = ChronoUnit.DAYS.between(zone.source.checked, now())
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
        if (vehicle.fuel in zone.exemptFuels) {
            return Answer(Verdict.Yes(F("The ZTL is active, but %@ vehicles may enter.", vehicle.fuel.label.lowercase())), true, next)
        }
        if (mine.any { it.status == Permit.Status.WAITING }) {
            return Answer(Verdict.Conditional(L("The ZTL is active."), L("Your permit is still waiting for confirmation. Drive in only once it's confirmed.")), true, next)
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
        val wd = weekday(d)
        val minute = d.hour * 60 + d.minute
        val yesterday = if (wd == 1) 7 else wd - 1
        val dayBefore = d.minusDays(1)
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

    /** Festivo nazionale o festa del patrono della città della zona */
    fun isHoliday(zone: Zone, day: LocalDate): Boolean = ItalianHolidays.isHoliday(day, zone.localHolidays)

    private fun inSeason(w: TimeWindow, d: ZonedDateTime): Boolean {
        val s = w.season ?: return true
        val md = d.monthValue * 100 + d.dayOfMonth
        val from = s.fromMonth * 100 + s.fromDay; val to = s.toMonth * 100 + s.toDay
        return if (from <= to) md in from..to else md >= from || md <= to
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
