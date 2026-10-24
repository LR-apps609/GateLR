package app.gatelr.core

/**
 * I testi: le chiavi sono le frasi inglesi dell'app iPhone, le traduzioni arrivano dallo stesso
 * Tools/translations.py (assets strings_it.json, strings_de.json). Senza traduzione resta l'inglese.
 */
object Strings {
    var language: String = "en"
    var table: Map<String, String> = emptyMap()
}

fun L(key: String): String = Strings.table[key] ?: key

/** Come String(format:) dell'iPhone: %@ e %lld diventano %s e %d */
fun F(key: String, vararg args: Any): String =
    String.format(L(key).replace("%@", "%s").replace("%lld", "%d").replace("%%", "%%"), *args)
