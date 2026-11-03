package app.gatelr.core

import java.time.Instant

/** I colori delle risposte di GateLR: rosso non entrare, giallo a una condizione o da verificare («?»), verde puoi entrare,
 *  grigio ZTL non attiva, neutro un posto che non conosciamo (mai verde) */
enum class AnswerColor { RED, YELLOW, GREEN, GREY, NEUTRAL }

/**
 * 1.20.0 «Motore unico»: la risposta per un posto come PlaceCheck dell'iPhone (Sources/PlaceCheck.swift).
 * - Tutte le zone che contengono il posto, dalla più piccola; decide la risposta PEGGIORE (no > condizione > non sicuro > sì,
 *   un «sì» da fonte non ufficiale conta come «non sicuro»), a parità la più piccola. Prima Android guardava solo la più
 *   piccola: a Palazzo Vecchio di notte un diesel Euro 1 riceveva «sì» dal Settore A spento, ma lo Scudo Verde lo vieta.
 * - L'area pedonale vince sempre (rosso).
 * - Fuori dalle zone: verde solo in una città che conosciamo (City.covers), altrimenti neutro.
 * Gli stessi casi di prova dell'iPhone e del sito: shared/engine-cases.json.
 */
class PlaceCheck(
    val hits: List<Pair<City, Zone>>,
    val pedestrian: PedestrianArea?,
    /** La risposta di ogni zona in [hits], nello stesso ordine */
    val answers: List<Answer>,
    covered: Boolean,
) {
    enum class Kind { UNCOVERED, OUTSIDE, OPEN, CLOSED, CONDITIONAL, UNSURE, PEDESTRIAN }

    val covered: Boolean = covered || hits.isNotEmpty() || pedestrian != null

    /** L'indice in [hits] della zona che decide */
    val decider: Int? = worst(hits.map { it.second }, answers)
    val answer: Answer? get() = decider?.let { answers[it] }
    val hit: Pair<City, Zone>? get() = decider?.let { hits[it] } ?: hits.firstOrNull()
    val zone: Zone? get() = hit?.second
    val city: City? get() = hit?.first

    val kind: Kind get() {
        if (pedestrian != null) return Kind.PEDESTRIAN
        val a = answer ?: return if (covered) Kind.OUTSIDE else Kind.UNCOVERED
        return when (a.verdict) {
            is Verdict.Yes -> Kind.OPEN; is Verdict.No -> Kind.CLOSED
            is Verdict.Conditional -> Kind.CONDITIONAL; is Verdict.Unsure -> Kind.UNSURE
        }
    }

    /** Le regole della zona che decide vengono solo da fonti non ufficiali: la risposta si dice con prudenza */
    val unofficial: Boolean get() = pedestrian == null && zone?.isUnofficial == true

    /** Un «sì» da fonte non ufficiale: si mostra giallo con il «?» */
    val hedged: Boolean get() = unofficial && kind == Kind.OPEN

    /** La risposta come si mostra: area pedonale «no», fuori dalle zone conosciute «sì», fuori copertura «non sicuro» */
    val verdict: Verdict get() = when (kind) {
        Kind.UNCOVERED -> Verdict.Unsure(L("We don't know the ZTLs of this place. Check the signs at the entrance."))
        Kind.OUTSIDE -> Verdict.Yes(L("This address isn't inside any ZTL we know. You can drive there."))
        Kind.PEDESTRIAN -> Verdict.No(L("It's a pedestrian area: cars can't drive in at any time, whatever the ZTL hours."))
        else -> answer!!.verdict.shown(unofficial)
    }

    /** I varchi della zona che decide (anche nell'area pedonale: lo stato vero della ZTL a quell'ora) */
    val gatesOn: Boolean? get() = answer?.gatesOn

    /** Il colore, come la mappa dell'iPhone (Access): pedonale rosso, fuori verde, fuori copertura neutro; la zona che
     *  decide spenta grigia; non sicuro o fonte non ufficiale mai verde né grigio, ma giallo */
    val color: AnswerColor get() {
        if (pedestrian != null) return AnswerColor.RED
        val a = answer ?: return if (covered) AnswerColor.GREEN else AnswerColor.NEUTRAL
        return zoneColor(a, zone!!, city?.status)
    }

    companion object {
        /** Il colore della risposta di una zona (come Access.of dell'iPhone) */
        fun zoneColor(a: Answer, zone: Zone, status: City.Status?): AnswerColor {
            val sample = status == City.Status.SAMPLE
            val c = when {
                a.verdict is Verdict.Unsure -> AnswerColor.YELLOW
                !a.gatesOn -> if (sample) AnswerColor.YELLOW else AnswerColor.GREY
                a.verdict is Verdict.No -> AnswerColor.RED
                sample -> AnswerColor.YELLOW
                a.verdict is Verdict.Conditional -> AnswerColor.YELLOW
                else -> AnswerColor.GREEN
            }
            return if (zone.isUnofficial && (c == AnswerColor.GREEN || c == AnswerColor.GREY)) AnswerColor.YELLOW else c
        }

        /** La zona con la risposta peggiore (come si mostra); a parità la prima, cioè la più piccola */
        fun worst(zones: List<Zone>, answers: List<Answer>): Int? {
            var best: Int? = null
            for (i in answers.indices) {
                if (i >= zones.size) break
                val s = answers[i].verdict.shown(zones[i].isUnofficial).severity
                if (best == null || s > answers[best].verdict.shown(zones[best].isUnofficial).severity) best = i
            }
            return best
        }

        /** Le zone, l'area pedonale e la copertura del punto, con la risposta di ogni zona */
        fun of(cities: List<City>, c: Coordinate, answer: (Zone) -> Answer): PlaceCheck {
            val hits = zonesAt(cities, c)
            return PlaceCheck(hits, pedestrianAreaAt(cities, c), hits.map { answer(it.second) }, cities.any { it.covers(c.lat, c.lon) })
        }

        fun of(cities: List<City>, c: Coordinate, engine: RuleEngine, vehicle: Vehicle, permits: List<Permit>, hotelInside: Boolean, at: Instant): PlaceCheck =
            of(cities, c) { engine.answer(it, vehicle, permits, hotelInside, at) }
    }
}
