package app.gatelr.core

import java.time.Instant

// 2.0 «Android alla pari»: come si MOSTRA la RispostaFinale (RispostaFinale.kt, comune a iPhone e sito) sulle superfici di
// Android: la forma accanto alla parola, il pannello LED dal motore, la riga sotto il titolo e la frase di TalkBack
// (S-Risposta, W-Risposte). Le decisioni (stato, motivo, colore) restano nella RispostaFinale.

/** La forma della risposta: si riconosce anche senza colori (forma + parola + colore) */
enum class Forma { DIVIETO, ESCLAMATIVO, SPUNTA, SPENTA, DOMANDA, DOMANDA_TRATTEGGIATA, FUORI }

val Stato.forma: Forma get() = when (this) {
    Stato.NON_ENTRARE -> Forma.DIVIETO
    Stato.CONDIZIONE -> Forma.ESCLAMATIVO
    Stato.ENTRA_PURE -> Forma.SPUNTA
    Stato.ZTL_NON_ATTIVA -> Forma.SPENTA
    Stato.CONTROLLA_CARTELLO -> Forma.DOMANDA
    Stato.NON_COPERTO -> Forma.DOMANDA_TRATTEGGIATA
    Stato.FUORI_ZTL -> Forma.FUORI
}

/** Il pannello LED come in strada, sempre in italiano: dal motore (varchi accesi o no), mai dalla risposta. Fuori copertura
 *  e fuori dalla ZTL: nessun pannello */
val RispostaFinale.panel: String? get() = when {
    stato == Stato.NON_COPERTO || stato == Stato.FUORI_ZTL || pedestrian -> null
    gatesOn == null -> null
    gatesOn -> "ZTL ATTIVA"
    else -> "ZTL NON ATTIVA"
}

/** La riga accanto al pannello (S-Risposta): «Il pannello dirà ZTL ATTIVA: per te va bene.», «Se il pannello dice così, non entrare.» */
val RispostaFinale.panelLine: String? get() = when {
    panel == null || gatesOn != true -> null
    stato == Stato.ENTRA_PURE || stato == Stato.CONDIZIONE -> L("The panel will say ZTL ATTIVA: that's fine for you.")
    stato == Stato.CONTROLLA_CARTELLO -> L("If the panel says so, don't enter.")
    else -> null
}

/** «Firenze · Settore B», «Area pedonale · Bologna», «Bologna» (fuori dalla ZTL) */
val RispostaFinale.place: String? get() = when {
    pedestrian -> listOfNotNull(L("Pedestrian area"), city?.localizedName).joinToString(" · ")
    zone != null -> listOfNotNull(city?.localizedName, zone.shortName).joinToString(" · ")
    else -> city?.localizedName
}

/** Il motivo del giallo, nella riga sotto (mai nel titolo): «Fonte non ufficiale», «Dati scaduti», «Non sicuro» */
val RispostaFinale.reasonShort: String? get() = motivo?.label ?: reasonLine

/** La riga sotto il titolo: motivo, posto e «fino alle 20:00» */
fun RispostaFinale.subtitle(untilText: String?): String? =
    listOfNotNull(reasonShort, place, untilText?.takeIf { stato != Stato.FUORI_ZTL && stato != Stato.NON_COPERTO && !pedestrian })
        .joinToString(" · ").ifEmpty { null }

/** La spiegazione sotto: la condizione, il motivo del motore, la frase fissa dei posti fuori */
fun RispostaFinale.detail(a: Answer?): String? = when {
    pedestrian -> L("It's a pedestrian area: cars can't drive in at any time, whatever the ZTL hours.")
    stato == Stato.FUORI_ZTL -> L("This address isn't inside any ZTL we know. You can drive there.")
    stato == Stato.NON_COPERTO -> L("We don't know the ZTLs of this place. Check the signs at the entrance.")
    else -> when (val v = a?.verdict) {
        is Verdict.Conditional -> v.condition
        null -> null
        else -> v.detail
    }
}

/** TalkBack, un solo elemento letto per primo: «Non entrare. Firenze, Settore B, fino alle 20:00. Per Golf diesel Euro 5, adesso.» */
fun RispostaFinale.spoken(untilText: String?, vehicle: String?, whenText: String?): String {
    val parts = mutableListOf(title)
    reasonShort?.let { parts += it }
    listOfNotNull(place?.replace(" · ", ", "), untilText).joinToString(", ").takeIf { it.isNotEmpty() }?.let { parts += it }
    listOfNotNull(vehicle?.let { F("For %@", it) }, whenText).joinToString(", ").takeIf { it.isNotEmpty() }?.let { parts += it }
    return parts.joinToString(". ") + "."
}

/** «Adesso» (D-Decisioni): risponde per la zona in cui sei o la più vicina entro 300 m nella direzione in cui vai */
object Adesso {
    const val RADIUS = 300.0

    /** La zona di «Adesso» tra i candidati del valutatore ([ThreatEvaluator.candidates]); qualunque risposta, anche verde */
    fun zone(p: Coordinate, course: Double?, candidates: List<ThreatCandidate>): Pair<ThreatCandidate, Double>? {
        candidates.filter { it.contains(p) }.minByOrNull { if (it.pedestrian != null) -1.0 else it.zone!!.roughArea }?.let { return it to 0.0 }
        return candidates.mapNotNull { c ->
            val (point, d) = ThreatEvaluator.nearest(c.perimeter, p)
            if (d <= RADIUS && ThreatEvaluator.isAhead(p, point, d, course, null)) c to d else null
        }.minByOrNull { it.second }
    }
}

/** 2.0.1: quello che «Adesso» e il widget mostrano: la risposta, la risposta del motore (come si mostra), i metri dal bordo
 *  (0 = dentro) e la zona o l'area pedonale che decide */
data class AdessoPick(val final: RispostaFinale, val answer: Answer?, val meters: Double?, val zone: Zone?, val pedestrian: PedestrianArea?)

/**
 * 2.0.1 (bug B11 dei tester): dentro una zona «Adesso» e il widget rispondono come PlaceCheck (Viaggio, mappa, iPhone):
 * la zona PEGGIORE tra tutte quelle del posto e l'area pedonale che vince. Prima prendevano la zona più piccola: in via
 * Accademia Albertina a Torino o a Palazzo Vecchio di notte con un diesel Euro 1 dicevano «Entra pure» / «ZTL non attiva»
 * dove Viaggio dice «Non entrare». Fuori dalle zone: la più vicina entro 300 m davanti, poi «Fuori dalla ZTL» o «Posto
 * non coperto». [answer] è la risposta del motore (RuleEngine.trustedAnswer, non ancora «come si mostra»).
 */
fun Adesso.resolve(cities: List<City>, here: Coordinate, course: Double?, at: Instant, answer: (Zone, Instant) -> Answer): AdessoPick {
    val check = PlaceCheck.of(cities, here) { answer(it, at) }
    if (check.pedestrian != null) return AdessoPick(check.finale, ThreatEvaluator.pedestrianAnswer, 0.0, check.zone, check.pedestrian)
    if (check.hits.isNotEmpty()) return AdessoPick(check.finale, check.answer?.copy(verdict = check.verdict), 0.0, check.zone, null)
    val candidates = ThreatEvaluator.candidates(cities, here, RADIUS + 50)
    val pick = zone(here, course, candidates)
    if (pick == null) {
        val city = cities.firstOrNull { it.covers(here.lat, here.lon) }
        return AdessoPick(if (city != null) RispostaFinale(Stato.FUORI_ZTL, city = city) else RispostaFinale(Stato.NON_COPERTO), null, null, null, null)
    }
    val (c, d) = pick
    if (c.pedestrian != null) return AdessoPick(ThreatEvaluator.finale(c, ThreatEvaluator.pedestrianAnswer), ThreatEvaluator.pedestrianAnswer, d, null, c.pedestrian)
    val z = c.zone!!
    val raw = answer(z, ThreatEvaluator.arrival(d, null, at))
    return AdessoPick(RispostaFinale.forZone(raw, z, c.city?.status, c.city), raw.copy(verdict = raw.verdict.shown(z.isUnofficial)), d, z, null)
}
