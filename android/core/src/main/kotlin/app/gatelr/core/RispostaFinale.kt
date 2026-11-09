package app.gatelr.core

import java.time.Instant

// 2.1 «Una risposta, sette stati» (shared/risposta-finale.md): la stessa RispostaFinale dell'iPhone
// (Sources/RispostaFinale.swift) e del sito (finale() in web/template.html), provata dagli stessi casi
// (shared/engine-cases.json, «stato» e «motivo»). Ogni superficie (Varco, mappa, widget, guardiano, notifiche) legge da qui
// parola, forma e colore: mai solo colore.

/** Il motivo del «Controlla il cartello», detto nella riga sotto, mai nel titolo */
enum class Motivo(val raw: String, val key: String) {
    NON_SICURO("nonSicuro", "Not sure"),
    SCADUTI("scaduti", "Data out of date"),
    NON_UFFICIALE("nonUfficiale", "Unofficial source"),
    FESTIVO("festivo", "Holiday not confirmed"),
    /** Il veicolo «Non so» (2.2): dove contano i divieti Euro. Oggi nessun veicolo lo produce */
    EURO_SCONOSCIUTO("euroSconosciuto", "Euro class unknown");

    val label: String get() = L(key)
}

/** Il colore semantico. SPENTO (ZTL non attiva) è un solo token: oggi verde, vedi [RispostaFinale.STATE_OFF] */
enum class Tono(val raw: String) { ROSSO("rosso"), GIALLO("giallo"), VERDE("verde"), SPENTO("spento"), GRIGIO("grigio"), NEUTRO("neutro") }

/** I sette stati, con la parola (chiave inglese di Tools/translations.py), la forma e il tono */
enum class Stato(val raw: String, val key: String, val lineKey: String, val symbol: String, val tono: Tono) {
    NON_ENTRARE("nonEntrare", "Don't enter", "Don't|enter", "✕", Tono.ROSSO),
    CONDIZIONE("condizione", "On one condition", "On one|condition", "!", Tono.GIALLO),
    ENTRA_PURE("entraPure", "You can enter", "You can|enter", "✓", Tono.VERDE),
    ZTL_NON_ATTIVA("ztlNonAttiva", "ZTL not active", "ZTL not|active", "–", Tono.SPENTO),
    CONTROLLA_CARTELLO("controllaCartello", "Check the sign", "Check the|sign", "?", Tono.GIALLO),
    NON_COPERTO("nonCoperto", "We don't know this place", "We don't know|this place", "?", Tono.NEUTRO),
    FUORI_ZTL("fuoriZTL", "Outside the ZTL", "Outside|the ZTL", "⌖", Tono.GRIGIO);

    val title: String get() = L(key)
    val lines: List<String> get() = L(lineKey).split("|")
    /** Il colore da disegnare: SPENTO diventa [RispostaFinale.STATE_OFF] */
    val color: Tono get() = if (tono == Tono.SPENTO) RispostaFinale.STATE_OFF else tono
    /** Solo questi stati fanno scattare un avviso in auto: mai un avviso verde, né per la ZTL non attiva */
    val alerts: Boolean get() = this == NON_ENTRARE || this == CONDIZIONE || this == CONTROLLA_CARTELLO
    /** Il contorno tratteggiato (posto che non conosciamo) */
    val dashed: Boolean get() = this == NON_COPERTO
}

data class RispostaFinale(
    val stato: Stato,
    /** Solo con [Stato.CONTROLLA_CARTELLO] */
    val motivo: Motivo? = null,
    val zone: Zone? = null,
    val city: City? = null,
    /** La fonte della zona che decide non è ufficiale (anche per un «Non entrare»: la riga sotto lo dice) */
    val unofficial: Boolean = false,
    val gatesOn: Boolean? = null,
    val nextChange: Instant? = null,
    val pedestrian: Boolean = false,
    /** 2.3 (decisione di Ledion del 09/11): solo con «Non entrare» (DaChiedere) e «Puoi entrare» (Registrata) */
    val hotel: HotelNota? = null,
) {
    val title: String get() = stato.title
    val color: Tono get() = stato.color

    /** La riga sotto il titolo: il motivo del «?», o «Probabilmente no · fonte non ufficiale» per un «no» da fonte non ufficiale */
    val reasonLine: String? get() = when {
        motivo != null && motivo != Motivo.NON_UFFICIALE -> motivo.label
        hotel == HotelNota.DaChiedere -> L("Ask the hotel to register your plate")
        hotel is HotelNota.Registrata -> F("The hotel registered your plate · from %@ to %@", shortDay(hotel.from), shortDay(hotel.to))
        unofficial && stato == Stato.NON_ENTRARE -> L("Probably not · unofficial source")
        unofficial && stato == Stato.CONTROLLA_CARTELLO -> L("Probably yes · unofficial source")
        else -> null
    }

    companion object {
        /** La ZTL non attiva: un solo token. Oggi verde per regola di Ledion; la bozza proponeva grigio */
        val STATE_OFF: Tono = Tono.VERDE

        /** La risposta di una zona (o di un'area pedonale) come si mostra: lo stesso ordine della specifica */
        fun forZone(a: Answer, zone: Zone, status: City.Status? = null, city: City? = null, pedestrian: Boolean = false): RispostaFinale {
            if (pedestrian) return RispostaFinale(Stato.NON_ENTRARE, zone = zone, city = city, gatesOn = a.gatesOn, pedestrian = true)
            val unoff = zone.isUnofficial
            fun r(s: Stato, m: Motivo? = null) = RispostaFinale(s, m, zone, city, unoff, a.gatesOn, a.nextChange, hotel = hotelNota(a.hotel, s, unoff))
            return when (a.verdict) {
                is Verdict.No -> r(Stato.NON_ENTRARE)
                is Verdict.Conditional -> r(Stato.CONDIZIONE)
                is Verdict.Unsure -> r(Stato.CONTROLLA_CARTELLO, a.doubt ?: if (unoff) Motivo.NON_UFFICIALE else Motivo.NON_SICURO)
                is Verdict.Yes -> when {
                    unoff -> r(Stato.CONTROLLA_CARTELLO, Motivo.NON_UFFICIALE)
                    status == City.Status.SAMPLE -> r(Stato.CONTROLLA_CARTELLO, Motivo.NON_SICURO)
                    !a.gatesOn -> r(Stato.ZTL_NON_ATTIVA)
                    else -> r(Stato.ENTRA_PURE)
                }
            }
        }

        /** 2.3: la riga dell'hotel solo con la sua risposta: «Non entrare» senza conferma, «Puoi entrare» con la conferma. Mai
         *  con un'area pedonale, una fonte non ufficiale o dati scaduti (allora vale «Controlla il cartello» e il suo motivo) */
        fun hotelNota(h: HotelNota?, stato: Stato, unofficial: Boolean): HotelNota? = when {
            h == null || unofficial -> null
            h == HotelNota.DaChiedere -> h.takeIf { stato == Stato.NON_ENTRARE }
            else -> h.takeIf { stato == Stato.ENTRA_PURE }
        }

        /** «9 nov» in ora italiana, nella lingua del telefono */
        fun shortDay(ms: Long): String = java.time.Instant.ofEpochMilli(ms).atZone(java.time.ZoneId.of("Europe/Rome")).toLocalDate()
            .format(java.time.format.DateTimeFormatter.ofPattern("d MMM", java.util.Locale.forLanguageTag(Strings.language)))

        /** La risposta per un posto: area pedonale, fuori dalle zone (coperto o no), poi la zona che decide */
        fun of(p: PlaceCheck): RispostaFinale {
            val a = p.answer
            if (p.pedestrian != null) return RispostaFinale(Stato.NON_ENTRARE, zone = p.zone, city = p.city, gatesOn = a?.gatesOn, pedestrian = true)
            val zone = p.zone
            if (a == null || zone == null) return when {
                !p.covered -> RispostaFinale(Stato.NON_COPERTO)
                // 2.1 (B22): fuori dalle zone di una città da fonti non ufficiali: anche il confine non lo sappiamo
                p.unofficial -> RispostaFinale(Stato.CONTROLLA_CARTELLO, Motivo.NON_UFFICIALE, unofficial = true)
                else -> RispostaFinale(Stato.FUORI_ZTL)
            }
            return forZone(a, zone, p.city?.status, p.city)
        }
    }
}
