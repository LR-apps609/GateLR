package app.gatelr.core

import java.util.Locale

/**
 * Ricerca dei posti (1.19.5): dove orientarla e cosa ricordare. Parte pura, provata nei test di core/;
 * la richiesta a Photon è in app/ (Geocoder).
 */
object SearchPlan {
    /** Entro questa distanza dalla città scelta la ricerca parte dalla tua posizione, oltre dal centro della città */
    const val NEAR_CITY_M = 50_000.0

    /** Attesa dopo l'ultimo tasto e lettere minime prima di chiedere a Photon */
    const val DEBOUNCE_MS = 350L
    const val MIN_CHARS = 3

    /** Tempi massimi della richiesta (prima 8 + 8 s, senza un modo di riprovare) */
    const val CONNECT_TIMEOUT_MS = 5_000
    const val READ_TIMEOUT_MS = 6_000

    /**
     * Il punto verso cui ordinare i risultati: la posizione se sei nella città scelta (o vicino), altrimenti il centro della
     * città scelta. Prima vinceva sempre la posizione: da Milano, cercando un hotel a Firenze, uscivano prima le vie di Milano.
     */
    fun near(here: Coordinate?, city: Coordinate): Coordinate =
        if (here != null && Geometry.meters(here, city) <= NEAR_CITY_M) here else city

    /** La stessa domanda (lettere, lingua, zona di circa 1 km) dà la stessa risposta: la chiave della memoria */
    fun key(query: String, lang: String, near: Coordinate): String =
        String.format(Locale.ROOT, "%s|%.2f|%.2f|%s", lang, near.lat, near.lon, query.trim().lowercase(Locale.ROOT))

    fun worthAsking(query: String) = query.trim().length >= MIN_CHARS
}

/** Una piccola memoria «gli ultimi N»: il più vecchio esce quando è piena. Sicura tra thread. */
class RecentCache<K, V>(private val max: Int) {
    private val map = object : LinkedHashMap<K, V>(16, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<K, V>?) = size > max
    }

    @Synchronized operator fun get(key: K): V? = map[key]
    @Synchronized operator fun set(key: K, value: V) { map[key] = value }
    @Synchronized fun clear() = map.clear()
    val size: Int @Synchronized get() = map.size
}
