package app.gatelr

import app.gatelr.core.Adesso
import app.gatelr.core.Answer
import app.gatelr.core.Coordinate
import app.gatelr.core.F
import app.gatelr.core.Geometry
import app.gatelr.core.L
import app.gatelr.core.RispostaFinale
import app.gatelr.core.resolve
import app.gatelr.core.Stato
import java.time.Instant

/** 2.0: la risposta di «Adesso» (e del widget): la zona in cui sei, o la più vicina entro 300 m nella direzione in cui vai;
 *  fuori dalle zone grigio «Fuori dalla ZTL», fuori dalle città che conosciamo neutro. Lo stesso valutatore del guardiano */
data class NowResult(
    val final: RispostaFinale,
    /** La risposta del motore per la zona (null fuori dalle zone) */
    val answer: Answer?,
    /** Metri dal bordo (0 = ci sei dentro) */
    val meters: Double?,
    /** «Via Guelfa a 40 m, davanti a te.» */
    val line: String?,
)

object NowAnswer {
    /** 2.0.1 (B11): dentro una zona decide PlaceCheck (zona peggiore, area pedonale che vince), come Viaggio e l'iPhone */
    fun compute(here: Coordinate, course: Double?, at: Instant = Instant.now()): NowResult {
        val pick = Adesso.resolve(AppState.cities, here, course, at) { z, t -> AppState.rawAnswer(z, t) }
        val f = pick.final
        val d = pick.meters
        val line = when {
            f.stato == Stato.FUORI_ZTL -> L("No ZTL within 300 m ahead.")
            f.stato == Stato.NON_COPERTO -> L("We don't know the ZTLs of this place. Check the signs at the entrance.")
            pick.pedestrian != null && d == 0.0 -> L("Cars can't drive here. Park outside and walk.")
            pick.pedestrian != null -> F("%@ in %@, ahead of you.", pick.pedestrian.name, Geometry.distanceText(d ?: 0.0))
            pick.zone == null || d == null -> null
            d == 0.0 -> F("You're inside %@", pick.zone.shortName) + "."
            else -> {
                val zone = pick.zone
                val gate = zone.gates.minByOrNull { Geometry.meters(it.location, here) }?.takeIf { Geometry.meters(it.location, here) < d + 150 }
                F("%@ in %@, ahead of you.", gate?.name ?: zone.shortName, Geometry.distanceText(d))
            }
        }
        return NowResult(f, pick.answer, d, line)
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
