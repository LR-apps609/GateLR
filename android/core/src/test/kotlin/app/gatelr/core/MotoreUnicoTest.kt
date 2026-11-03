package app.gatelr.core

import java.io.File
import java.time.LocalDateTime
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/** 1.20.0 «Motore unico»: le differenze con l'iPhone corrette nel motore Android (oltre ai casi comuni di shared/) */
class MotoreUnicoTest {
    private val dir = File(System.getProperty("gatelr.cities"))
    private fun city(id: String) = CityLoader.decode(File(dir, "$id.json").readText())
    private fun date(y: Int, m: Int, d: Int, h: Int) = LocalDateTime.of(y, m, d, h, 0).atZone(RuleEngine.ROME).toInstant()
    private val car = Vehicle(id = "car", name = "Rental car", fuel = Fuel.PETROL, euro = 6)

    /** holidaysAsSunday si legge dal file (prima Android lo ignorava) */
    @Test fun holidaysAsSundayDecodes() {
        val b = city("bergamo")
        assertEquals(true, b.zones.first { it.id == "bergamo-colli" }.holidaysAsSunday)
        assertEquals(null, b.zones.first { it.id == "bergamo-citta-alta" }.holidaysAsSunday)
    }

    /** Come l'iPhone dalla 1.19.2: un permesso senza zona non copre niente, uno con la zona solo quella */
    @Test fun permitOnlyForItsZone() {
        val f = city("firenze")
        val a = f.zones.first { it.id == "firenze-a" }; val b = f.zones.first { it.id == "firenze-b" }
        val at = date(2026, 11, 10, 10)
        val noZone = Permit(kind = Permit.Kind.HOTEL, cityId = "firenze", zoneId = null, vehicleId = car.id,
            from = at.toEpochMilli() - 3_600_000, to = at.toEpochMilli() + 3_600_000, status = Permit.Status.CONFIRMED)
        assertFalse(noZone.covers(a, car, at))
        val forA = noZone.copy(zoneId = "firenze-a")
        assertTrue(forA.covers(a, car, at))
        assertFalse(forA.covers(b, car, at))
        val engine = RuleEngine(now = { date(2026, 11, 3, 12) })
        assertTrue(engine.answer(a, car, listOf(forA), false, at).verdict is Verdict.Yes)
        assertTrue(engine.answer(b, car, listOf(forA), false, at).verdict is Verdict.No)
    }

    /** Fonte non ufficiale: il «sì» si mostra «non sicuro»; il «no» resta «no» (rosso, «Probabilmente no»), come l'iPhone */
    @Test fun unofficialYesIsShownUnsure() {
        assertTrue(Verdict.Yes("x").shown(true) is Verdict.Unsure)
        assertTrue(Verdict.Yes("x").shown(false) is Verdict.Yes)
        assertTrue(Verdict.No("x").shown(true) is Verdict.No)
        assertTrue(city("salerno").zones.all { it.isUnofficial })
    }
}
