package app.gatelr.core

/**
 * 1.19.4 «Privacy onesta» (come Sources/PlatePrivacy.swift sull'iPhone): la targa resta nel Garage del telefono e non
 * entra mai in un testo che si condivide. Unica eccezione voluta, detta in Account → Privacy: il messaggio per l'hotel,
 * che serve proprio a far registrare la targa e che mandi tu.
 */
object PlatePrivacy {
    const val MASK = "•••"

    /** Le targhe italiane dal 1994: «AB123CD», «AB 123 CD», «AB-123-CD» */
    private val italian = Regex("(?<![A-Z0-9])[A-Z]{2}[ \\-]?[0-9]{3}[ \\-]?[A-Z]{2}(?![A-Z0-9])", RegexOption.IGNORE_CASE)

    fun normalized(plate: String): String = plate.uppercase().filter { it.isLetterOrDigit() }

    /** Il testo senza le targhe date (anche con spazi, trattini o punti in mezzo) e senza targhe italiane */
    fun scrub(text: String, plates: List<String> = emptyList()): String {
        var out = text
        for (plate in plates.map(::normalized).filter { it.length >= 4 }.toSet()) {
            val body = plate.map { Regex.escape(it.toString()) }.joinToString("[\\s\\-.·]?")
            out = Regex("(?<![A-Z0-9])$body(?![A-Z0-9])", RegexOption.IGNORE_CASE).replace(out, MASK)
        }
        return italian.replace(out, MASK)
    }

    fun leaks(text: String, plates: List<String> = emptyList()): Boolean = scrub(text, plates) != text

    /** Una riga del diario da condividere: quando, zona, cosa, risposta. Mai la targa */
    fun logLine(whenText: String, zoneName: String, what: String, verdict: String, plates: List<String>): String =
        scrub(listOf(whenText, zoneName, what, verdict).filter { it.isNotBlank() }.joinToString(" · "), plates)
}
