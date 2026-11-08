package app.gatelr.core

import java.text.NumberFormat
import java.time.Instant
import java.util.Currency
import java.util.Locale

// 2.0.1: le correzioni dei bug Android dei tester (test20) che si possono provare senza telefono: le decisioni stanno qui
// (provate in BugAndroidTest), le schermate dell'app le leggono.

/** B12: la mappa colorata per RISPOSTA (come Access.of dell'iPhone), non per tipo di zona */
object MappaRisposte {
    /** Il tono di una zona sulla mappa: la RispostaFinale per quel veicolo, quei permessi e quell'ora ([a] = risposta del motore) */
    fun tono(a: Answer, zone: Zone, city: City?): Tono = RispostaFinale.forZone(a, zone, city?.status, city).color

    /** Le aree pedonali: sempre «Non entrare» */
    val pedestrian: Tono = Stato.NON_ENTRARE.color

    /** La legenda: le risposte che una zona può avere sulla mappa (forma + parola + colore), mai i tipi */
    val legend: List<Stato> = listOf(Stato.NON_ENTRARE, Stato.CONDIZIONE, Stato.ENTRA_PURE, Stato.ZTL_NON_ATTIVA, Stato.CONTROLLA_CARTELLO)
}

/** B31: quando il widget si risveglia da solo. Al cambio della ZTL (un minuto dopo), e comunque entro 30 minuti: la
 *  posizione cambia anche senza cambi d'orario. Mai nel passato */
object WidgetSchedule {
    const val MAX_WAIT_MS = 30 * 60_000L
    const val AFTER_CHANGE_MS = 30_000L

    fun next(nextChange: Instant?, now: Instant): Instant {
        val cap = now.plusMillis(MAX_WAIT_MS)
        val change = nextChange?.plusMillis(AFTER_CHANGE_MS)?.takeIf { it.isAfter(now) } ?: return cap
        return if (change.isBefore(cap)) change else cap
    }

    /** «Aggiornato alle 7:31»: la riga in fondo al widget */
    fun updatedLine(at: Instant): String {
        val d = at.atZone(RuleEngine.ROME)
        return F("Updated %@", String.format(Locale.ROOT, "%d:%02d", d.hour, d.minute))
    }
}

/** B169, B173: le parole del widget. Il titolo va a capo dove lo dice la parola su due righe («Controlla il|cartello»),
 *  più piccolo se una riga non ci sta; la riga sotto dice «⚠︎» per una fonte non ufficiale */
object WidgetText {
    /** Le righe del titolo, in maiuscolo nella lingua dell'app */
    fun titleLines(stato: Stato): List<String> = stato.lines.map { it.uppercase(Locale.forLanguageTag(Strings.language)) }

    /** La grandezza del titolo (sp): la riga più lunga deve stare nella larghezza utile ([widthDp], ~0,62 em per lettera) */
    fun titleSize(stato: Stato, widthDp: Int, max: Int): Int {
        val longest = titleLines(stato).maxOf { it.length }.coerceAtLeast(1)
        return (widthDp / (longest * 0.62)).toInt().coerceIn(12, max)
    }

    /** La riga sotto il titolo: motivo (con «⚠︎» se la fonte non è ufficiale) e «fino alle 20:00» */
    fun extra(f: RispostaFinale, until: String?): String? {
        val reason = f.reasonShort?.let { if (f.unofficial || f.motivo == Motivo.NON_UFFICIALE) "⚠︎ $it" else it }
        return listOfNotNull(reason, until).joinToString(" · ").ifEmpty { null }
    }
}

/** B81: il tasto Indietro. Prima chiude il posto aperto (Viaggio) o lo spillo (Mappa), poi torna ad Adesso, poi esce */
object BackStep {
    enum class Action { CLOSE_PLACE, CLOSE_PIN, GO_NOW, EXIT }

    fun next(tab: Int, hasPlace: Boolean, hasPin: Boolean): Action = when {
        tab == 2 && hasPlace -> Action.CLOSE_PLACE
        tab == 1 && hasPin -> Action.CLOSE_PIN
        tab != 0 -> Action.GO_NOW
        else -> Action.EXIT
    }
}

/** B160: una posizione vale come «dove sei» solo se recente (lo stesso limite del widget) */
object Freshness {
    const val MAX_AGE_MS = 10 * 60_000L
    fun isFresh(atMillis: Long, nowMillis: Long, maxAge: Long = MAX_AGE_MS): Boolean = atMillis > 0 && nowMillis - atMillis in 0..maxAge
}

/** B161: la lingua dei testi dalla lingua dell'app (Android 13+ la cambia per app): una delle 8, altrimenti inglese */
object Lingua {
    val SUPPORTED = listOf("en", "it", "de", "fr", "es", "nl", "pl", "zh")
    fun pick(language: String?): String = language?.lowercase()?.substringBefore('-')?.substringBefore('_')?.takeIf { it in SUPPORTED } ?: "en"
}

/** B162: le righe della prima pagina */
object HomeText {
    /** «1 attiva», «3 attive», «Tutto libero» */
    fun activeCount(n: Int): String = when (n) { 0 -> L("All open"); 1 -> L("1 active"); else -> F("%lld active", n) }

    /** «ZTL non attiva» (senza «ZTL · » davanti), «Zona verde · ZTL attiva» */
    fun zoneLine(type: ZoneKind, gatesOn: Boolean): String {
        val state = if (gatesOn) L("ZTL active") else L("ZTL not active")
        return if (type == ZoneKind.RESTRICTED) state else type.title + " · " + state
    }
}

/** B166: la città dalla posizione, una volta per APERTURA (non per processo), e mai dopo una scelta a mano in questa apertura */
class CityFromPositionGate {
    private var done = false
    private var byHand = false
    /** Una nuova apertura dell'app (l'attività riparte): si sceglie di nuovo dalla posizione */
    fun newOpening() { done = false; byHand = false }
    fun choseByHand() { byHand = true }
    /** Vero alla prima posizione di questa apertura, se non hai scelto a mano */
    fun shouldAdopt(): Boolean {
        if (done) return false
        done = true
        return !byHand
    }
}

/** B86: i promemoria salvati sul telefono, da ripianificare dopo il riavvio */
@kotlinx.serialization.Serializable
data class SavedReminder(val key: String, val at: Long, val title: String, val body: String)

object ReminderBook {
    /** Aggiunge o sostituisce (stessa chiave) e toglie quelli già passati da più di un giorno */
    fun add(list: List<SavedReminder>, r: SavedReminder, now: Long): List<SavedReminder> = prune(list.filter { it.key != r.key } + r, now)
    fun remove(list: List<SavedReminder>, key: String): List<SavedReminder> = list.filter { it.key != key }
    fun prune(list: List<SavedReminder>, now: Long): List<SavedReminder> = list.filter { it.at > now - 24 * 3_600_000L }
    /** Dopo il riavvio: quelli da ripianificare, all'ora giusta o subito se l'ora è passata mentre il telefono era spento */
    fun toReschedule(list: List<SavedReminder>, now: Long): List<SavedReminder> = prune(list, now).map { if (it.at < now) it.copy(at = now + 5_000) else it }
}

/** B87: il riquadro del ticket solo se la zona è attiva all'ora scelta e il posto non è in un'area pedonale (come l'iPhone) */
object TicketShow {
    fun visible(zone: Zone?, pedestrian: PedestrianArea?, active: Boolean): Boolean = pedestrian == null && zone?.ticket != null && active
}

/** B88: l'avviso sopra la risposta, come StatusBanner dell'iPhone: «Dati di esempio» o «Bozza: dalle fonti ufficiali, non
 *  ancora rivista da una persona». Per una zona non ufficiale l'avviso è già nella risposta («Fonte non ufficiale») */
object CityBanner {
    fun text(city: City?, zone: Zone?): String? = when {
        city == null || zone == null || zone.isUnofficial -> null
        city.status == City.Status.SAMPLE -> L("Sample data, not real")
        city.status == City.Status.DRAFT -> L("Draft: from official sources, not yet reviewed by a person")
        else -> null
    }
}

/** B176: il prezzo in un solo formato, quello della lingua dell'app (come priceText dell'iPhone): «7,50 €», «€7.50» */
object Money {
    fun euro(price: Double, language: String = Strings.language): String =
        NumberFormat.getCurrencyInstance(Locale.forLanguageTag(if (language == "en") "en-IE" else language)).apply {
            currency = Currency.getInstance("EUR")
        }.format(price)
}
