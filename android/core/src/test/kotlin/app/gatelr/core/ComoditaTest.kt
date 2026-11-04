package app.gatelr.core

import java.io.File
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertSame
import kotlin.test.assertTrue

/** 1.20.2 «Comodità»: Invio nella ricerca, permessi al momento giusto, conferma prima di cancellare, città dalla posizione */
class ComoditaTest {
    private val dir = File(System.getProperty("gatelr.cities"))
    private fun city(id: String) = CityLoader.decode(File(dir, "$id.json").readText())

    @Test fun enterPicksFirstOrRetriesOrSearchesNow() {
        assertEquals(SearchSubmit.PICK_FIRST, SearchSubmit.action("Palazzo Vecchio", results = 4, failed = false))
        assertEquals(SearchSubmit.RETRY, SearchSubmit.action("Palazzo Vecchio", results = 0, failed = true))
        assertEquals(SearchSubmit.SEARCH_NOW, SearchSubmit.action("Palazzo Vecchio", results = 0, failed = false))
        assertEquals(SearchSubmit.NOTHING, SearchSubmit.action("Pa", results = 3, failed = false))
    }

    @Test fun nothingAskedAtLaunch() {
        assertTrue(PermissionPlan.needs(PermissionPlan.Moment.LAUNCH, hasLocation = false, hasNotifications = false, sdk = 35).isEmpty())
    }

    @Test fun eachFeatureAsksOnlyWhatItUses() {
        val loc = PermissionPlan.Need.LOCATION; val notif = PermissionPlan.Need.NOTIFICATIONS
        assertEquals(setOf(loc), PermissionPlan.needs(PermissionPlan.Moment.USE_MY_LOCATION, false, false, 35))
        assertEquals(setOf(loc, notif), PermissionPlan.needs(PermissionPlan.Moment.GUARDIAN, false, false, 35))
        assertEquals(setOf(notif), PermissionPlan.needs(PermissionPlan.Moment.REMINDER, true, false, 35))
        // Già dati, o notifiche prima di Android 13: niente richiesta
        assertTrue(PermissionPlan.needs(PermissionPlan.Moment.GUARDIAN, true, true, 35).isEmpty())
        assertEquals(setOf(loc), PermissionPlan.needs(PermissionPlan.Moment.GUARDIAN, false, false, 30))
    }

    @Test fun deletingAVehicleTakesItsPermitsAndMovesTheActiveOne() {
        val a = Vehicle(id = "a", name = "A", fuel = Fuel.PETROL, euro = 6)
        val b = Vehicle(id = "b", name = "B", fuel = Fuel.DIESEL, euro = 4)
        val pa = Permit(kind = Permit.Kind.RESIDENT, cityId = "firenze", zoneId = "firenze-a", vehicleId = "a", from = 0, to = 1, status = Permit.Status.CONFIRMED)
        val pb = pa.copy(id = "pb", vehicleId = "b")
        val after = GarageEdit.deleteVehicle(GarageState(listOf(a, b), listOf(pa, pb), "a"), "a")
        assertEquals(listOf(b), after.vehicles)
        assertEquals(listOf(pb), after.permits)
        assertEquals("b", after.activeVehicleId)
        // L'ultimo veicolo resta
        val one = GarageState(listOf(b), listOf(pb), "b")
        assertSame(one, GarageEdit.deleteVehicle(one, "b"))
    }

    @Test fun confirmationTexts() {
        assertEquals("Delete this vehicle?", GarageEdit.question("vehicle"))
        assertEquals("Its permits are deleted too. You can't undo this.", GarageEdit.detail("vehicle"))
        assertEquals("You can't undo this.", GarageEdit.detail("trip"))
    }

    @Test fun cityFromPosition() {
        val cities = listOf(city("firenze"), city("bologna"), city("milano"))
        assertEquals("bologna", CityFromPosition.pick(Coordinate(44.4939, 11.3426), cities)?.first?.id)    // Piazza Maggiore
        assertEquals("milano", CityFromPosition.pick(Coordinate(45.4641, 9.1919), cities)?.first?.id)      // Duomo
        assertEquals("bologna", CityFromPosition.pick(Coordinate(44.5354, 11.2887), cities)?.first?.id)    // aeroporto
        assertNull(CityFromPosition.pick(Coordinate(41.9028, 12.4964), cities))                             // Roma: nessuna
    }
}
