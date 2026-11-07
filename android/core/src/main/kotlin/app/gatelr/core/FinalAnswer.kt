package app.gatelr.core

import java.time.Instant

// 2.0 «Alla pari»: la risposta finale («RispostaFinale» delle tavole S-Risposta e W-Risposte), la stessa su ogni
// superficie di Android (Adesso, Mappa, Viaggio, guardiano, widget). Sette risposte, ognuna con forma + parola + colore,
// mai solo colore. Si calcola dal motore (PlaceCheck, RuleEngine): qui solo come si dice e come si mostra.

/** Le sette risposte */
enum class AnswerState {
    /** Rosso, cerchio con la barra: non entrare */
    NO,
    /** Giallo, «!»: entri a una condizione (ticket, hotel, permesso in attesa) */
    CONDITION,
    /** Verde, spunta: entra pure (anche a ZTL attiva quando il veicolo è ammesso) */
    YES,
    /** ZTL spenta: un solo token di colore ([AnswerTokens.stateOff], oggi verde per regola di Ledion) */
    OFF,
    /** Giallo, «?»: controlla il cartello (non sicuro, dati scaduti, fonte non ufficiale) */
    CHECK,
    /** Neutro con contorno tratteggiato, «?»: un posto che non conosciamo (fuori copertura) */
    UNCOVERED,
    /** Grigio: un posto fuori dalla ZTL in una città che conosciamo (deciso da Ledion il 07/11/2026) */
    OUTSIDE,
}

/** Perché il giallo «?»: va nella riga sotto, mai nel titolo */
enum class AnswerReason(val key: String) {
    NOT_SURE("Not sure"), STALE("Data out of date"), UNOFFICIAL("Unofficial source");
    val text: String get() = L(key)
}

/** I colori della risposta: semantici, uguali di giorno e di notte (S-Colori) */
enum class AnswerTone { RED, AMBER, GREEN, GREY, NEUTRAL }

/** La forma accanto alla parola: si riconosce anche senza colori */
enum class AnswerShape { NO_ENTRY, EXCLAMATION, CHECK, OFF, QUESTION, QUESTION_DASHED, OUTSIDE }

object AnswerTokens {
    /** Il colore di «ZTL non attiva». Le bozze proponevano grigio; per regola di Ledion resta verde. Cambia solo qui */
    val stateOff: AnswerTone = AnswerTone.GREEN
}

data class FinalAnswer(
    val state: AnswerState,
    val reason: AnswerReason? = null,
    /** La zona che decide (null fuori dalle zone e nell'area pedonale senza zona) */
    val zone: Zone? = null,
    val city: City? = null,
    /** Il nome dell'area pedonale, se il posto è in un'area pedonale */
    val pedestrian: String? = null,
    /** Quando cambia lo stato dei varchi della zona che decide */
    val until: Instant? = null,
    /** I varchi della zona che decide sono accesi? (lo dice il motore, mai la risposta) */
    val gatesOn: Boolean? = null,
    /** La frase sotto: condizione, motivo, spiegazione del motore */
    val detail: String? = null,
) {
    val tone: AnswerTone get() = toneOf(state)
    val shape: AnswerShape get() = shapeOf(state)

    /** La parola (chiave inglese): «Don't enter», «On one condition», … */
    val wordKey: String get() = wordKeyOf(state)
    /** La parola nella lingua dell'app, come nelle pillole («Non entrare») */
    val word: String get() = L(wordKey)
    /** Il titolo del blocco grande e del widget, in maiuscolo («NON ENTRARE») */
    val title: String get() = word.uppercase(java.util.Locale.forLanguageTag(Strings.language))

    /** Il pannello LED come in strada, sempre in italiano: dal motore (varchi accesi o no), mai dalla risposta.
     *  Fuori copertura e fuori dalla ZTL: nessun pannello */
    val panel: String? get() = when {
        state == AnswerState.UNCOVERED || state == AnswerState.OUTSIDE || gatesOn == null -> null
        gatesOn -> "ZTL ATTIVA"
        else -> "ZTL NON ATTIVA"
    }

    /** La riga accanto al pannello: «Il pannello dirà ZTL ATTIVA: per te va bene.» (S-Risposta) */
    val panelLine: String? get() = when {
        panel == null -> null
        gatesOn == true && (state == AnswerState.YES || state == AnswerState.CONDITION) -> L("The panel will say ZTL ATTIVA: that's fine for you.")
        gatesOn == true && state == AnswerState.CHECK -> L("If the panel says so, don't enter.")
        else -> null
    }

    /** «Firenze · Settore B», «Area pedonale · Via Galliera», «Pistoia» */
    val place: String? get() = when {
        pedestrian != null -> F("Pedestrian area · %@", pedestrian)
        zone != null -> listOfNotNull(city?.localizedName, zone.shortName).joinToString(" · ")
        else -> city?.localizedName
    }

    /** La riga sotto il titolo: posto e «fino alle 20:00» */
    fun subtitle(untilText: String?): String? =
        listOfNotNull(place, untilText?.takeIf { gatesOn != null && state != AnswerState.OUTSIDE && state != AnswerState.UNCOVERED })
            .joinToString(" · ").ifEmpty { null }

    /** TalkBack, un solo elemento letto per primo: «Non entrare. Firenze, Settore B, fino alle 20:00. Per Golf diesel Euro 5, adesso.» */
    fun spoken(untilText: String?, vehicle: String?, whenText: String?): String {
        val parts = mutableListOf(word)
        reason?.let { parts += it.text }
        listOfNotNull(place?.replace(" · ", ", "), untilText).joinToString(", ").takeIf { it.isNotEmpty() }?.let { parts += it }
        listOfNotNull(vehicle?.let { F("For %@", it) }, whenText).joinToString(", ").takeIf { it.isNotEmpty() }?.let { parts += it }
        return parts.joinToString(". ") + "."
    }

    /** La risposta è verde? Mai per fuori copertura, fonte non ufficiale, dati scaduti */
    val isGreen: Boolean get() = tone == AnswerTone.GREEN

    companion object {
        fun toneOf(s: AnswerState): AnswerTone = when (s) {
            AnswerState.NO -> AnswerTone.RED
            AnswerState.CONDITION, AnswerState.CHECK -> AnswerTone.AMBER
            AnswerState.YES -> AnswerTone.GREEN
            AnswerState.OFF -> AnswerTokens.stateOff
            AnswerState.OUTSIDE -> AnswerTone.GREY
            AnswerState.UNCOVERED -> AnswerTone.NEUTRAL
        }

        fun shapeOf(s: AnswerState): AnswerShape = when (s) {
            AnswerState.NO -> AnswerShape.NO_ENTRY
            AnswerState.CONDITION -> AnswerShape.EXCLAMATION
            AnswerState.YES -> AnswerShape.CHECK
            AnswerState.OFF -> AnswerShape.OFF
            AnswerState.CHECK -> AnswerShape.QUESTION
            AnswerState.UNCOVERED -> AnswerShape.QUESTION_DASHED
            AnswerState.OUTSIDE -> AnswerShape.OUTSIDE
        }

        fun wordKeyOf(s: AnswerState): String = when (s) {
            AnswerState.NO -> AnswerWord.DONT_ENTER.key
            AnswerState.CONDITION -> AnswerWord.CONDITION.key
            AnswerState.YES -> AnswerWord.ENTER.key
            AnswerState.OFF -> "ZTL not active"
            AnswerState.CHECK -> AnswerWord.CHECK_SIGN.key
            AnswerState.UNCOVERED -> AnswerWord.UNKNOWN_PLACE.key
            AnswerState.OUTSIDE -> "Outside the ZTL"
        }

        /** Perché una risposta di una zona è gialla «?»: fonte non ufficiale, dati scaduti (o pagina cambiata), altrimenti
         *  «non sicuro» (festivo non confermato, moto senza limiti scritti…) */
        fun reasonFor(zone: Zone, engine: RuleEngine?): AnswerReason {
            if (zone.isUnofficial) return AnswerReason.UNOFFICIAL
            val trust = engine?.trust(zone)
            if (trust == DataTrust.UNVERIFIED || trust == DataTrust.OLD || trust == DataTrust.PAGE_CHANGED) return AnswerReason.STALE
            if (engine != null && java.time.temporal.ChronoUnit.DAYS.between(engine.freshest(zone.source), engine.now()) > engine.staleAfterDays) return AnswerReason.STALE
            return AnswerReason.NOT_SURE
        }

        /** La risposta di una sola zona (già «come si mostra»: AppState.answer, Verdict.shown) */
        fun of(zone: Zone, city: City?, answer: Answer, engine: RuleEngine? = null): FinalAnswer {
            val v = answer.verdict.shown(zone.isUnofficial)
            val state = when (v) {
                is Verdict.No -> AnswerState.NO
                is Verdict.Conditional -> AnswerState.CONDITION
                is Verdict.Unsure -> AnswerState.CHECK
                is Verdict.Yes -> if (answer.gatesOn) AnswerState.YES else AnswerState.OFF
            }
            // Città d'esempio: mai verde
            val safe = if (city?.status == City.Status.SAMPLE && (state == AnswerState.YES || state == AnswerState.OFF)) AnswerState.CHECK else state
            val detail = when (v) {
                is Verdict.Conditional -> v.condition
                is Verdict.No, is Verdict.Unsure -> if (zone.isUnofficial) v.unofficialNote(true) ?: v.detail else v.detail
                is Verdict.Yes -> v.reason
            }
            return FinalAnswer(safe, if (safe == AnswerState.CHECK) reasonFor(zone, engine) else null, zone, city, null,
                answer.nextChange, answer.gatesOn, detail)
        }

        /** La risposta per un posto (PlaceCheck: la zona peggiore, l'area pedonale che vince, la copertura) */
        fun of(check: PlaceCheck, engine: RuleEngine? = null, near: City? = null): FinalAnswer {
            check.pedestrian?.let { p ->
                return FinalAnswer(AnswerState.NO, null, check.zone, check.city, p.name, null, check.gatesOn,
                    L("It's a pedestrian area: cars can't drive in at any time, whatever the ZTL hours."))
            }
            val z = check.zone
            val a = check.answer
            if (z == null || a == null) {
                return if (check.covered) FinalAnswer(AnswerState.OUTSIDE, city = near, detail = L("This address isn't inside any ZTL we know. You can drive there."))
                else FinalAnswer(AnswerState.UNCOVERED, detail = L("We don't know the ZTLs of this place. Check the signs at the entrance."))
            }
            return of(z, check.city, a, engine)
        }
    }
}
