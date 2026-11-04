package app.gatelr.core

/**
 * 1.20.2 «Comodità», come l'iPhone (Sources/Comodita.swift): Invio nella ricerca, permessi al momento giusto,
 * conferma prima di cancellare, la città dalla posizione. Parti pure, provate in ComoditaTest.
 */

/** Cosa fa Invio (il tasto «Cerca» della tastiera) nel campo di ricerca */
enum class SearchSubmit {
    /** C'è almeno un risultato: il primo, come toccarlo */
    PICK_FIRST,
    /** La ricerca non ha avuto risposta: si riprova subito */
    RETRY,
    /** Si cerca subito, senza l'attesa dopo l'ultimo tasto, e si sceglie il primo risultato */
    SEARCH_NOW,
    /** Troppo poco da cercare */
    NOTHING;

    companion object {
        fun action(query: String, results: Int, failed: Boolean): SearchSubmit = when {
            !SearchPlan.worthAsking(query) -> NOTHING
            results > 0 -> PICK_FIRST
            failed -> RETRY
            else -> SEARCH_NOW
        }
    }
}

/** I permessi di Android che una cosa usa, chiesti solo quando la usi (mai all'apertura dell'app) */
object PermissionPlan {
    enum class Moment { LAUNCH, USE_MY_LOCATION, GUARDIAN, REMINDER }
    enum class Need { LOCATION, NOTIFICATIONS }

    /** Notifiche solo da Android 13 (prima non si chiedono); quelle già date non si chiedono di nuovo */
    fun needs(moment: Moment, hasLocation: Boolean, hasNotifications: Boolean, sdk: Int): Set<Need> {
        val wanted = when (moment) {
            Moment.LAUNCH -> emptySet()
            Moment.USE_MY_LOCATION -> setOf(Need.LOCATION)
            Moment.GUARDIAN -> setOf(Need.LOCATION, Need.NOTIFICATIONS)
            Moment.REMINDER -> setOf(Need.NOTIFICATIONS)
        }
        return wanted.filter { n ->
            when (n) {
                Need.LOCATION -> !hasLocation
                Need.NOTIFICATIONS -> sdk >= 33 && !hasNotifications
            }
        }.toSet()
    }
}

/** Il garage dopo una cancellazione confermata */
data class GarageState(val vehicles: List<Vehicle>, val permits: List<Permit>, val activeVehicleId: String?)

object GarageEdit {
    /** Il veicolo e i suoi permessi; se era quello in uso si passa al primo rimasto. L'ultimo veicolo non si cancella */
    fun deleteVehicle(state: GarageState, id: String): GarageState {
        if (state.vehicles.size <= 1 || state.vehicles.none { it.id == id }) return state
        val vehicles = state.vehicles.filter { it.id != id }
        return GarageState(vehicles, state.permits.filter { it.vehicleId != id },
            if (state.activeVehicleId == id || vehicles.none { it.id == state.activeVehicleId }) vehicles.first().id else state.activeVehicleId)
    }

    /** La domanda del dialogo di conferma */
    fun question(what: String): String = when (what) {
        "vehicle" -> L("Delete this vehicle?")
        "permit" -> L("Delete this permit?")
        "trip" -> L("Delete this trip?")
        "log" -> L("Delete the whole log?")
        else -> L("Delete")
    }

    fun detail(what: String): String =
        if (what == "vehicle") L("Its permits are deleted too. You can't undo this.") else L("You can't undo this.")
}

/**
 * La città dalla posizione (come CityFromPosition dell'iPhone): dentro la copertura di una città quella, con la zona
 * che ti contiene o la più vicina; fuori, la città della zona più vicina entro [NEAR_M]; più lontano nessuna
 */
object CityFromPosition {
    const val NEAR_M = 15_000.0

    fun pick(here: Coordinate, cities: List<City>): Pair<City, Zone>? {
        val covering = cities.filter { it.covers(here.lat, here.lon) }
        zonesAt(covering, here).firstOrNull()?.let { return it }
        val best = nearestZone(covering.ifEmpty { cities }, here) ?: return null
        if (covering.isEmpty() && best.third > NEAR_M) return null
        return best.first to best.second
    }
}
