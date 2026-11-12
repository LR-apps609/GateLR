package app.gatelr.core

import java.net.URLEncoder
import java.time.Instant
import java.time.temporal.ChronoUnit
import java.util.Locale

/**
 * 2.0.2 «Fiducia»: la riga sotto ogni risposta e il link da mandare all'hotel o al noleggio. Gli stessi casi dell'iPhone
 * (Sources/Fiducia.swift) e del sito (fiducia* in web/template.html): shared/fiducia-cases.json.
 *
 * - La data mostrata è la più recente tra «letto il» (source.checkedOn: quando abbiamo letto le pagine ufficiali) e
 *   «verificato il» (source.verifiedOn), in giorni di calendario di Roma. Mai un'ora: quella di checkedOn non è affidabile.
 * - «Non ancora verificata a mano»: source.reviewedByHuman falso. Un'etichetta gialla accanto alla data: il colore della
 *   risposta NON cambia (la regola «mai verde se non verificata» non è stata decisa).
 * - Il link porta alla risposta sul sito, senza installare nulla: #p=lat,lon&n=nome&v=veicolo (linkHash del sito).
 */
object Fiducia {
    const val SITE = "https://lr-apps609.github.io/GateLR/"

    /** I veicoli del menu del sito (CARS in web/template.html): solo questi vanno nel link */
    val SITE_VEHICLES = listOf("petrol-6", "petrol-3", "diesel-4", "diesel-6", "hybrid-6", "electric-6", "moto-5", "diesel-5", "petrol-4", "petrol-5")

    enum class When { TODAY, YESTERDAY, DATE }

    data class Control(
        /** Il giorno (a Roma) dell'ultimo controllo */
        val day: java.time.LocalDate,
        val whenDay: When,
        /** «23/10», con l'anno se non è quello di adesso: «23/10/2026» */
        val label: String,
        /** Verificata o letta da al più 120 giorni, pagina del Comune non cambiata: la spunta */
        val fresh: Boolean,
        /** Verificata da una persona (source.reviewedByHuman) */
        val byHand: Boolean,
    ) {
        /** «Controllata oggi», «Controllata ieri», «Controllata il 23/10» */
        val text: String get() = when (whenDay) {
            When.TODAY -> L("Last checked today")
            When.YESTERDAY -> L("Last checked yesterday")
            When.DATE -> F("Last checked %@", label)
        }
    }

    fun control(source: Source, now: Instant, engine: RuleEngine = RuleEngine(now = { now })): Control {
        val at = engine.freshest(source)
        val day = at.atZone(RuleEngine.ROME).toLocalDate()
        val today = now.atZone(RuleEngine.ROME).toLocalDate()
        val whenDay = when (ChronoUnit.DAYS.between(day, today)) { 0L -> When.TODAY; 1L -> When.YESTERDAY; else -> When.DATE }
        val label = String.format(Locale.ROOT, "%02d/%02d", day.dayOfMonth, day.monthValue) +
            if (day.year != today.year) "/${day.year}" else ""
        val trust = RuleEngine(now = { now }, staleAfterDays = engine.staleAfterDays).trust(source)
        return Control(day, whenDay, label, trust == DataTrust.VERIFIED || trust == DataTrust.READ, source.reviewedByHuman)
    }

    /** «diesel-4», «moto-5»: solo se il sito conosce quel veicolo; mai per un veicolo «Non so» */
    fun vehicleKey(fuel: String, euro: Int, motorcycle: Boolean, unknown: Boolean = false): String? {
        if (unknown) return null
        val k = if (motorcycle) "moto-$euro" else "$fuel-$euro"
        return k.takeIf { it in SITE_VEHICLES }
    }

    fun vehicleKey(v: Vehicle): String? = vehicleKey(v.fuel.name.lowercase(), v.euro, v.kind == VehicleType.MOTORCYCLE)

    /** La pagina del sito nella lingua: it/, de/; le altre lingue la pagina inglese */
    fun sitePrefix(lang: String): String = when (lang.substringBefore('-').substringBefore('_')) { "it" -> "it/"; "de" -> "de/"; else -> "" }

    /** Come URLSearchParams del browser (application/x-www-form-urlencoded, UTF-8): lo stesso link su ogni superficie */
    fun formEncode(s: String): String = URLEncoder.encode(s, "UTF-8")

    /**
     * Il link da condividere. Con un posto: la risposta per quel posto (la home del sito con #p=…); senza (o con la
     * posizione del telefono, che non si condivide): la pagina della città
     */
    fun shareURL(lang: String, cityId: String?, placeName: String?, lat: Double?, lon: Double?, vehicleKey: String?): String {
        val base = SITE + sitePrefix(lang)
        if (placeName == null || lat == null || lon == null) return base + (cityId?.let { "$it/" } ?: "")
        val p = String.format(Locale.ROOT, "%.5f,%.5f", lat, lon)
        val parts = mutableListOf("p" to p, "n" to placeName.trim().take(120))
        vehicleKey?.let { parts += "v" to it }
        return base + "#" + parts.joinToString("&") { (k, v) -> k + "=" + formEncode(v) }
    }

    /** Il testo da mandare: chi lo riceve apre la risposta nel browser, senza installare nulla. Mai la targa */
    fun shareText(name: String, url: String): String =
        F("I'm arriving by car: %@. Here GateLR shows if a car can enter the ZTL. It opens in the browser, nothing to install:", name) + "\n" + url
}
