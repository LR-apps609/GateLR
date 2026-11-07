package app.gatelr.core

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
