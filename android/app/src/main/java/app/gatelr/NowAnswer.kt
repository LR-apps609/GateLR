package app.gatelr

import app.gatelr.core.Answer
import app.gatelr.core.AnswerState
import app.gatelr.core.Coordinate
import app.gatelr.core.F
import app.gatelr.core.FinalAnswer
import app.gatelr.core.Geometry
import app.gatelr.core.L
import app.gatelr.core.ThreatEvaluator
import java.time.Instant

/** 2.0: la risposta di «Adesso» (e del widget): la zona in cui sei, o la più vicina entro 300 m nella direzione in cui vai;
 *  fuori dalle zone grigio «Fuori dalla ZTL», fuori dalle città che conosciamo neutro. Lo stesso valutatore del guardiano */
data class NowResult(
    val final: FinalAnswer,
    /** La risposta del motore per la zona (null fuori dalle zone) */
    val answer: Answer?,
    /** Metri dal bordo (0 = ci sei dentro) */
    val meters: Double?,
    /** «Varco Via Guelfa a 40 m, davanti a te.» */
    val line: String?,
)

object NowAnswer {
    fun compute(here: Coordinate, course: Double?, at: Instant = Instant.now()): NowResult {
        val candidates = ThreatEvaluator.candidates(AppState.cities, here, within = ThreatEvaluator.NOW_RADIUS + 50)
        val pick = ThreatEvaluator.nowZone(here, course, candidates)
        if (pick == null) {
            val city = AppState.cities.firstOrNull { it.covers(here.lat, here.lon) }
            return if (city != null) NowResult(FinalAnswer(AnswerState.OUTSIDE, city = city, detail = L("No ZTL within 300 m ahead.")), null, null, L("No ZTL within 300 m ahead."))
            else NowResult(FinalAnswer(AnswerState.UNCOVERED, detail = L("We don't know the ZTLs of this place. Check the signs at the entrance.")), null, null,
                L("We don't know the ZTLs of this place. Check the signs at the entrance."))
        }
        val (c, d) = pick
        val city = AppState.cities.firstOrNull { it.localizedName == c.cityName }
        if (c.pedestrian != null) {
            val a = ThreatEvaluator.pedestrianAnswer
            return NowResult(FinalAnswer(AnswerState.NO, city = city, pedestrian = c.pedestrian.name, gatesOn = null, detail = a.verdict.detail), a, d,
                L("Cars can't drive here. Park outside and walk."))
        }
        val a = AppState.answer(c.zone, at.plusSeconds(ThreatEvaluator.secondsTo(d, null)))
        val f = FinalAnswer.of(c.zone, city, a, AppState.engine)
        val line = if (d == 0.0) F("You're inside %@", c.zone.shortName) + "."
        else {
            val gate = c.zone.gates.minByOrNull { Geometry.meters(it.location, here) }?.takeIf { Geometry.meters(it.location, here) < d + 150 }
            F("%@ in %@, ahead of you.", gate?.name ?: c.zone.shortName, Geometry.distanceText(d))
        }
        return NowResult(f, a, d, line)
    }

    /** «fino alle 20:00» oggi a ZTL accesa; altrimenti «Si accende alle 7:00», «Finisce domani alle 7:30» */
    fun untilText(a: Answer?, now: Instant): String? {
        a ?: return null
        val n = a.nextChange ?: return null
        val d = n.atZone(app.gatelr.core.RuleEngine.ROME)
        if (a.gatesOn && d.toLocalDate() == now.atZone(app.gatelr.core.RuleEngine.ROME).toLocalDate())
            return F("until %@", String.format("%d:%02d", d.hour, d.minute))
        return changeText(a, now)
    }

    /** «Golf diesel Euro 5»: il veicolo scelto, per la frase-contesto e per TalkBack */
    fun vehicleLabel(): String {
        val v = AppState.vehicle
        val name = v.model.ifBlank { v.name }
        return if (v.kind == app.gatelr.core.VehicleType.MOTORCYCLE) "$name · Euro ${v.euro}" else "$name · ${v.fuel.label.lowercase()} Euro ${v.euro}"
    }
}
