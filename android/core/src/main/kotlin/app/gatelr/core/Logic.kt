package app.gatelr.core

import java.time.Instant
import java.time.ZonedDateTime

// Le parti «pure» dell'app iPhone (RouteCheck, SignReader, Guardian.scan, CarCatalog, Store), in Kotlin.

/** Le zone che contengono il punto, dalla più piccola (es. Area C dentro Area B) */
fun zonesAt(cities: List<City>, c: Coordinate): List<Pair<City, Zone>> =
    cities.flatMap { city -> city.zones.filter { it.contains(c.lat, c.lon) }.map { city to it } }.sortedBy { it.second.roughArea }

fun nearestZone(cities: List<City>, c: Coordinate): Triple<City, Zone, Double>? =
    cities.flatMap { city -> city.zones.map { Triple(city, it, it.distance(c.lat, c.lon)) } }.minByOrNull { it.third }

fun pedestrianAreaAt(cities: List<City>, c: Coordinate): PedestrianArea? =
    cities.firstNotNullOfOrNull { city -> city.pedestrian?.firstOrNull { it.contains(c.lat, c.lon) } }

// ---- Percorso

data class RouteCrossing(val zone: Zone, val answer: Answer, val at: Instant, val isDestination: Boolean, val entry: Coordinate?)

object RouteCheck {
    fun crossings(path: List<Coordinate>, zones: List<Zone>, departure: Instant, travelSeconds: Double,
                  answer: (Zone, Instant) -> Answer): List<RouteCrossing> {
        val first = path.firstOrNull() ?: return emptyList()
        val last = path.last()
        val candidates = zones.filter { !it.contains(first.lat, first.lon) }
        val result = mutableListOf<RouteCrossing>()
        val total = maxOf(path.size - 1, 1).toDouble()
        path.forEachIndexed { i, p ->
            for (z in candidates) {
                if (result.any { it.zone.id == z.id } || !z.contains(p.lat, p.lon)) continue
                val whenAt = departure.plusMillis((travelSeconds * 1000 * i / total).toLong())
                result += RouteCrossing(z, answer(z, whenAt), whenAt, z.contains(last.lat, last.lon), p)
            }
        }
        return result
    }

    fun worst(c: List<RouteCrossing>): RouteCrossing? = c.maxByOrNull {
        when (it.answer.verdict) { is Verdict.No -> 3; is Verdict.Unsure -> 2; is Verdict.Conditional -> 1; is Verdict.Yes -> 0 }
    }

    /** Punti ogni ~40 m: un rettilineo non salta una zona piccola */
    fun densify(path: List<Coordinate>, step: Double = 40.0): List<Coordinate> {
        if (path.size < 2) return path
        val out = mutableListOf(path[0])
        for ((a, b) in path.zipWithNext()) {
            val n = maxOf(1, (Geometry.meters(a, b) / step).toInt())
            for (j in 1..n) { val t = j.toDouble() / n; out += Coordinate(a.lat + (b.lat - a.lat) * t, a.lon + (b.lon - a.lon) * t) }
        }
        return out
    }
}

// ---- Guardiano

data class Threat(val zone: Zone, val meters: Double, val answer: Answer)

object GuardianScan {
    data class Result(val threat: Threat?, val entered: List<Pair<Zone, Answer>>, val distances: Map<String, Double>)

    /** La ZTL più vicina verso cui ti avvicini dove non entri liberamente, e le zone in cui sei appena entrato */
    fun scan(p: Coordinate, zones: List<Zone>, last: Map<String, Double>, answer: (Zone, Double) -> Answer): Result {
        val distances = last.toMutableMap()
        var best: Threat? = null
        val entered = mutableListOf<Pair<Zone, Answer>>()
        for (z in zones) {
            val d = z.distance(p.lat, p.lon)
            val before = last[z.id]
            distances[z.id] = d
            if (d >= 3_000) continue
            if (d == 0.0) {
                if (before != null && before > 0) { val a = answer(z, 0.0); if (a.verdict !is Verdict.Yes) entered += z to a }
                continue
            }
            val a = answer(z, d)
            if (a.verdict is Verdict.Yes) continue
            if (before != null && d >= before - 3) continue           // solo se ti stai avvicinando
            if (best == null || d < best.meters) best = Threat(z, d, a)
        }
        return Result(best, entered, distances)
    }
}

// ---- Leggi il cartello

object SignReader {
    data class Rule(val days: Set<Int>, val start: Int, val end: Int)
    data class Result(val rules: List<Rule>, val holidaysExcluded: Boolean, val holidaysIncluded: Boolean) { val understood get() = rules.isNotEmpty() }
    private val allDays = (1..7).toSet()

    fun parse(raw: String): Result {
        val text = raw.lowercase().replace("–", "-").replace("—", "-").replace("÷", "-")
        val lines = text.lines().map { it.trim() }.filter { it.isNotEmpty() }
        val rules = mutableListOf<Rule>()
        lines.forEachIndexed { i, line ->
            val times = timeRanges(line)
            if (times.isEmpty()) return@forEachIndexed
            var days = days(line)
            if (days == null && i + 1 < lines.size && timeRanges(lines[i + 1]).isEmpty()) days = days(lines[i + 1])
            if (days == null && i > 0 && timeRanges(lines[i - 1]).isEmpty()) days = days(lines[i - 1])
            times.forEach { rules += Rule(days ?: allDays, it.first, it.second) }
        }
        val excluded = "festivi esclusi" in text || "escluso festivi" in text || "esclusi festivi" in text ||
            "holidays excluded" in text || ("feriali" in text && "festivi" !in text)
        val included = !excluded && ("festivi" in text || "tutti i giorni" in text)
        return Result(rules, excluded, included)
    }

    private val timeRe = Regex("""(?:dalle\s+)?(\d{1,2})(?:[.:,h](\d{2}))?\s*(?:-|alle|a)\s*(\d{1,2})(?:[.:,h](\d{2}))?""")

    fun timeRanges(line: String): List<Pair<Int, Int>> = timeRe.findAll(line).mapNotNull { m ->
        val h1 = m.groupValues[1].toInt(); val h2 = m.groupValues[3].toInt()
        val m1s = m.groupValues[2]; val m2s = m.groupValues[4]
        if (h1 > 24 || h2 > 24) return@mapNotNull null
        val m1 = m1s.toIntOrNull() ?: 0; val m2 = m2s.toIntOrNull() ?: 0
        if (m1 >= 60 || m2 >= 60) return@mapNotNull null
        if (m1s.isEmpty() && m2s.isEmpty() && h1 == h2) return@mapNotNull null
        (h1 * 60 + m1) to (h2 * 60 + m2)
    }.toList()

    private val names = listOf("dom" to 1, "lun" to 2, "mar" to 3, "mer" to 4, "gio" to 5, "ven" to 6, "sab" to 7,
        "sun" to 1, "mon" to 2, "tue" to 3, "wed" to 4, "thu" to 5, "fri" to 6, "sat" to 7)
    private val rangeRe = Regex("""(dom|lun|mar|mer|gio|ven|sab|sun|mon|tue|wed|thu|fri|sat)[a-zì]*\.?\s*-\s*(dom|lun|mar|mer|gio|ven|sab|sun|mon|tue|wed|thu|fri|sat)""")

    fun days(line: String): Set<Int>? {
        if ("tutti i giorni" in line || "every day" in line || "giornaliero" in line) return allDays
        rangeRe.find(line)?.let { m ->
            val a = names.first { it.first == m.groupValues[1] }.second
            val b = names.first { it.first == m.groupValues[2] }.second
            val out = mutableSetOf<Int>(); var d = a
            repeat(7) { out += d; if (d == b) return out; d = d % 7 + 1 }
            return out
        }
        if ("feriali" in line) return setOf(2, 3, 4, 5, 6, 7)
        if ("festivi" in line && "esclus" !in line) return setOf(1)
        val found = names.filter { Regex("""\b${it.first}""").containsMatchIn(line) }.map { it.second }.toSet()
        return found.ifEmpty { null }
    }

    fun isActive(r: Result, at: Instant): Boolean {
        val d: ZonedDateTime = at.atZone(RuleEngine.ROME)
        val wd = d.dayOfWeek.value % 7 + 1
        val minute = d.hour * 60 + d.minute
        if (r.holidaysExcluded && ItalianHolidays.isHoliday(at)) return false
        val yesterday = if (wd == 1) 7 else wd - 1
        return r.rules.any { rule ->
            when {
                rule.end > rule.start -> wd in rule.days && minute >= rule.start && minute < rule.end
                rule.end == rule.start -> wd in rule.days
                else -> (wd in rule.days && minute >= rule.start) || (yesterday in rule.days && minute < rule.end)
            }
        }
    }
}

// ---- Garage

object CarCatalog {
    /** Dall'anno di prima immatricolazione alla classe Euro tipica (da controllare sul libretto, campo V.9) */
    fun euroForYear(y: Int): Int = when {
        y >= 2016 -> 6; y >= 2011 -> 5; y >= 2006 -> 4; y >= 2001 -> 3; y >= 1997 -> 2; y >= 1993 -> 1; else -> 0
    }

    /** Moto e scooter: Euro 3 dal 2007, 4 dal 2017, 5 dal 2021 (valori tipici, da controllare sul libretto) */
    fun euroForYear(y: Int, type: VehicleType): Int = if (type != VehicleType.MOTORCYCLE) euroForYear(y) else when {
        y >= 2021 -> 5; y >= 2017 -> 4; y >= 2007 -> 3; y >= 2004 -> 2; y >= 1999 -> 1; else -> 0
    }
}

data class AdviceLine(val city: String, val zone: String, val text: String, val ok: Boolean)

fun carAdvice(v: Vehicle, cities: List<City>, at: Instant): List<AdviceLine> = cities.flatMap { city ->
    city.zones.mapNotNull { z ->
        when {
            z.exempts(v) -> AdviceLine(city.localizedName, z.shortName, L("Motorbikes and scooters may enter"), true)
            v.fuel in z.exemptFuels -> AdviceLine(city.localizedName, z.shortName, F("%@ cars may enter", v.fuel.label), true)
            z.bans == null || v.kind != VehicleType.CAR -> null
            z.ban(v, at) != null -> AdviceLine(city.localizedName, z.shortName, L("Your car can't enter while it's active"), false)
            z.nextBan(v, at) != null -> AdviceLine(city.localizedName, z.shortName, F("Allowed until %@", z.nextBan(v, at)!!.since), true)
            else -> AdviceLine(city.localizedName, z.shortName, L("Your car's class is allowed"), true)
        }
    }
}
