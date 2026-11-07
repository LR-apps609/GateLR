package app.gatelr.core

import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.hypot

// 2.0 «Alla pari»: il valutatore della minaccia, lo stesso dell'iPhone (Sources/ThreatEvaluator.swift) per il guardiano,
// il widget e «Adesso». Solo le zone DAVANTI nel verso di marcia, la risposta del motore per il TUO veicolo all'ora
// d'arrivo, mai un avviso verde. Avvisi a 300 m in città e a 600 m sopra i 50 km/h (D-Decisioni).

/** Una zona (o un'area pedonale) che si può avere davanti */
data class ThreatCandidate(
    /** Per un'area pedonale: la zona fatta dal suo perimetro ([ThreatEvaluator.pedestrianZone]) */
    val zone: Zone,
    val cityName: String,
    val pedestrian: PedestrianArea? = null,
) {
    val id: String get() = zone.id
    /** «Firenze Settore A», «Area pedonale · Via Galliera» */
    val name: String get() = if (pedestrian != null) zone.localizedName else "$cityName ${zone.shortName}"
    val unofficial: Boolean get() = pedestrian == null && zone.isUnofficial
}

/** Una zona davanti con la sua risposta */
data class ZoneThreat(val candidate: ThreatCandidate, val meters: Double, val answer: Answer, val point: Coordinate) {
    val zone: Zone get() = candidate.zone
    val shown: Verdict get() = ThreatEvaluator.shown(answer.verdict, candidate)
    /** «Non entrare · Firenze Settore A»; null se puoi entrare (mai un avviso verde) */
    val title: String? get() = ThreatEvaluator.title(shown, candidate)
}

/** Lo stato a riposo, quando davanti non c'è niente da segnalare */
enum class ThreatResting { UNKNOWN_PLACE, CLEAR }

object ThreatEvaluator {
    /** Oltre questi metri una zona non conta */
    const val LOOKAHEAD = 3_000.0
    /** Davanti = entro questo angolo dal verso di marcia */
    const val AHEAD_CONE = 70.0
    /** Da qui in giù la zona è «davanti» in ogni caso (ci sei sopra) */
    const val ON_TOP = 30.0
    /** L'avviso in città */
    const val ALERT_CITY = 300.0
    /** L'avviso sopra i 50 km/h */
    const val ALERT_FAST = 600.0
    /** 50 km/h in metri al secondo */
    const val FAST_SPEED = 50.0 / 3.6

    /** A quanti metri si avvisa a questa velocità (m/s; null = non la sappiamo: in città) */
    fun alertDistance(speed: Double?): Double = if ((speed ?: 0.0) > FAST_SPEED) ALERT_FAST else ALERT_CITY

    /** «Adesso» risponde per la zona più vicina entro 300 m nella direzione in cui vai */
    const val NOW_RADIUS = 300.0

    val pedestrianAnswer: Answer
        get() = Answer(Verdict.No(L("It's a pedestrian area: cars can't drive in at any time, whatever the ZTL hours.")), true, null)

    /** Una zona fatta dal perimetro dell'area pedonale, sempre chiusa (come RouteCheck.pedestrianZone dell'iPhone) */
    fun pedestrianZone(a: PedestrianArea, checkedOn: String): Zone {
        val name = F("Pedestrian area · %@", a.name)
        return Zone(id = "pedestrian:" + a.id, name = name, nameIt = name, nameDe = name, kind = ZoneKind.RESTRICTED,
            summary = L("Cars can't drive in here at any time, except authorised vehicles. Park outside and walk."),
            perimeter = a.perimeter, gates = emptyList(), windows = listOf(TimeWindow((1..7).toSet(), 0, 24 * 60)),
            freeOnHolidays = false, hotelCanRegister = false,
            source = Source(authority = "OpenStreetMap", pageURL = "https://www.openstreetmap.org", checkedOn = checkedOn,
                reviewedByHuman = false, pending = emptyList(), links = emptyList()))
    }

    /** Area pedonale: sempre «no». Un «sì» da fonte non ufficiale: «non sicuro» */
    fun shown(v: Verdict, c: ThreatCandidate): Verdict = if (c.pedestrian != null) pedestrianAnswer.verdict else v.shown(c.unofficial)

    /** Vero se bisogna avvisare: tutto tranne il verde */
    fun alerts(v: Verdict, c: ThreatCandidate): Boolean = shown(v, c) !is Verdict.Yes

    /** Il titolo dell'avviso: «Non entrare · Firenze Settore A». null = verde */
    fun title(shown: Verdict, c: ThreatCandidate): String? = if (shown is Verdict.Yes) null else shown.word(false).title + " · " + c.name

    /** Le zone e le aree pedonali entro [within] metri */
    fun candidates(cities: List<City>, near: Coordinate, within: Double = LOOKAHEAD, checkedOn: String = java.time.Instant.now().toString()): List<ThreatCandidate> {
        val out = mutableListOf<ThreatCandidate>()
        for (city in cities) {
            for (z in city.zones) if (z.distance(near.lat, near.lon) < within) out += ThreatCandidate(z, city.localizedName)
            for (a in city.pedestrian.orEmpty()) {
                val d = if (a.contains(near.lat, near.lon)) 0.0 else nearestPoint(a.perimeter, near).second
                if (d < within) out += ThreatCandidate(pedestrianZone(a, checkedOn), city.localizedName, a)
            }
        }
        return out
    }

    /** L'angolo da a verso b (gradi, 0 = nord, in senso orario) */
    fun bearing(a: Coordinate, b: Coordinate): Double {
        val k = cos(a.lat * Math.PI / 180)
        val deg = atan2((b.lon - a.lon) * k, b.lat - a.lat) * 180 / Math.PI
        return if (deg < 0) deg + 360 else deg
    }

    /** La differenza tra due direzioni, da 0 a 180 gradi */
    fun angle(a: Double, b: Double): Double {
        val d = abs(a - b) % 360
        return if (d > 180) 360 - d else d
    }

    /** Il punto del perimetro più vicino e la distanza in metri */
    fun nearestPoint(perimeter: List<Coordinate>, p: Coordinate): Pair<Coordinate, Double> {
        val k = cos(p.lat * Math.PI / 180)
        var best = p to Double.POSITIVE_INFINITY
        for (q in perimeter) {
            val m = hypot((q.lat - p.lat) * 111_000, (q.lon - p.lon) * 111_000 * k)
            if (m < best.second) best = q to m
        }
        return best
    }

    /** La zona è davanti? Con la direzione (course ≥ 0): entro ±70°. Senza: conta se ti avvicini, o se non lo sappiamo */
    fun isAhead(from: Coordinate, to: Coordinate, meters: Double, course: Double?, approaching: Boolean?): Boolean {
        if (meters < ON_TOP) return true
        if (course != null && course >= 0) return angle(course, bearing(from, to)) <= AHEAD_CONE
        return approaching ?: true
    }

    data class Scan(
        /** La zona più vicina davanti in cui non entri liberamente (a parità di metri la più grave) */
        val threat: ZoneThreat?,
        /** Le zone in cui sei appena entrato e dove non potevi entrare liberamente */
        val entered: List<ZoneThreat>,
        /** I metri da ogni zona vicina (per sapere al prossimo giro se ti avvicini) */
        val distances: Map<String, Double>,
        val resting: ThreatResting,
    )

    /** [answer] dà la risposta del motore per la zona a quella distanza (all'ora d'arrivo stimata) */
    fun scan(p: Coordinate, course: Double?, candidates: List<ThreatCandidate>, last: Map<String, Double>, covered: Boolean,
             answer: (ThreatCandidate, Double) -> Answer): Scan {
        val distances = mutableMapOf<String, Double>()
        var best: ZoneThreat? = null
        val entered = mutableListOf<ZoneThreat>()
        for (c in candidates) {
            val inside = c.zone.contains(p.lat, p.lon)
            val (point, d) = if (inside) p to 0.0 else nearestPoint(c.zone.perimeter, p)
            val before = last[c.id]
            distances[c.id] = d
            if (d >= LOOKAHEAD) continue
            if (d == 0.0) {
                if (before != null && before > 0) {
                    val a = answer(c, 0.0)
                    if (alerts(a.verdict, c)) entered += ZoneThreat(c, 0.0, a, p)
                }
                continue
            }
            if (!isAhead(p, point, d, course, before?.let { d < it - 3 })) continue
            val a = answer(c, d)
            if (!alerts(a.verdict, c)) continue
            val t = ZoneThreat(c, d, a, point)
            val b = best
            if (b != null && (b.meters < d || (b.meters == d && b.shown.severity >= t.shown.severity))) continue
            best = t
        }
        return Scan(best, entered, distances, if (covered) ThreatResting.CLEAR else ThreatResting.UNKNOWN_PLACE)
    }

    /** La zona per «Adesso»: quella in cui sei, altrimenti la più vicina DAVANTI entro [NOW_RADIUS] m (qualunque risposta) */
    fun nowZone(p: Coordinate, course: Double?, candidates: List<ThreatCandidate>): Pair<ThreatCandidate, Double>? {
        candidates.filter { it.zone.contains(p.lat, p.lon) }.minByOrNull { if (it.pedestrian != null) -1.0 else it.zone.roughArea }?.let { return it to 0.0 }
        return candidates.mapNotNull { c ->
            val (point, d) = nearestPoint(c.zone.perimeter, p)
            if (d <= NOW_RADIUS && isAhead(p, point, d, course, null)) c to d else null
        }.minByOrNull { it.second }
    }

    /** Secondi fino a quella distanza: la velocità vera se ti muovi, altrimenti 9 m/s (32 km/h in città) */
    fun secondsTo(meters: Double, speed: Double?): Long {
        val v = if ((speed ?: 0.0) > 3) speed!! else 9.0
        return (meters / v).toLong()
    }
}

/** Lo stesso avviso una volta sola per avvicinamento: torna possibile oltre 900 m o dopo 30 minuti */
class ThreatDeduper(private val resetDistance: Double = 900.0, private val cooldownMs: Long = 30 * 60_000L) {
    private val fired = mutableMapOf<String, Long>()

    fun shouldAlert(key: String, now: Long = System.currentTimeMillis()): Boolean {
        val t = fired[key]
        if (t != null && now - t < cooldownMs) return false
        fired[key] = now
        return true
    }

    /** Le zone da cui ti sei allontanato si possono avvisare di nuovo (chiavi «<id>» o «<prefisso>|<id>») */
    fun moved(distances: Map<String, Double>) {
        fired.keys.toList().forEach { key ->
            val id = key.substringAfterLast("|")
            if ((distances[id] ?: 0.0) > resetDistance) fired.remove(key)
        }
    }
}
