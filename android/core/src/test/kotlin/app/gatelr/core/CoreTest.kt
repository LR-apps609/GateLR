package app.gatelr.core

import java.io.File
import java.time.Instant
import java.time.LocalDateTime
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlin.test.fail

/** Gli stessi casi dei test dell'app iPhone (Tests/RuleEngineTests.swift), sugli stessi file delle città */
class CoreTest {
    private val engine = RuleEngine(now = { date(2026, 10, 26, 12) })
    private val car = Vehicle(name = "Rental car", model = "Fiat 500", fuel = Fuel.PETROL, euro = 6, isRental = true)

    private fun date(y: Int, m: Int, d: Int, h: Int, min: Int = 0): Instant =
        LocalDateTime.of(y, m, d, h, min).atZone(RuleEngine.ROME).toInstant()

    private val cities: Map<String, City> by lazy {
        val dir = File(System.getProperty("gatelr.cities"))
        dir.listFiles { f -> f.extension == "json" && f.name != "manifest.json" }!!
            .map { CityLoader.decode(it.readText()) }.associateBy { it.id }
    }
    private fun zone(city: String, id: String) = cities[city]!!.zones.first { it.id == id }
    private fun verdict(z: Zone, v: Vehicle = car, at: Instant, hotel: Boolean = false) = engine.answer(z, v, emptyList(), hotel, at).verdict

    @Test fun allCitiesLoad() {
        assertTrue(cities.size >= 3)
        cities.values.forEach { c -> c.zones.forEach { z -> assertNotNull(z.kind, z.id); assertTrue(z.perimeter.size > 3, z.id) } }
    }

    @Test fun florenceDayAndNight() {
        val b = zone("firenze", "firenze-b")
        assertTrue(verdict(b, at = date(2026, 10, 26, 18)) is Verdict.No)                  // lunedì 18:00
        val night = engine.answer(b, car, emptyList(), false, date(2026, 10, 23, 21, 40))
        assertTrue(night.verdict is Verdict.Yes)
        assertEquals(date(2026, 10, 24, 7, 30), night.nextChange)                       // sabato mattina
        assertEquals(date(2026, 10, 23, 20), engine.previousChange(b, date(2026, 10, 23, 21, 40)))
        assertTrue(verdict(b, at = date(2026, 10, 26, 18), hotel = true) is Verdict.Conditional)
    }

    @Test fun summerNightSector() {
        val g = zone("firenze", "firenze-g")
        assertEquals(date(2026, 7, 2, 23), engine.nextChange(g, date(2026, 7, 2, 12)))
        assertEquals(date(2026, 7, 3, 3), engine.nextChange(g, date(2026, 7, 2, 23, 30)))
        assertEquals(date(2026, 7, 2, 23), engine.previousChange(g, date(2026, 7, 3, 1)))
    }

    @Test fun bolognaAndMilan() {
        val bo = zone("bologna", "bologna-ztl")
        assertTrue(engine.isActive(bo, date(2026, 10, 25, 10)))                           // domenica: tutti i giorni
        assertFalse(engine.isActive(bo, date(2026, 10, 25, 21)))
        assertTrue(verdict(bo, at = date(2026, 10, 26, 10)) is Verdict.Conditional)       // ticket
        val c = zone("milano", "milano-c")
        assertTrue(engine.isActive(c, date(2026, 10, 26, 10)))
        assertFalse(engine.isActive(c, date(2026, 10, 24, 10)))                           // sabato
        assertFalse(engine.isActive(c, date(2026, 12, 8, 10)))                            // Immacolata
        assertNull(engine.nextChange(zone("bologna", "bologna-t"), date(2026, 10, 26, 10)))
    }

    @Test fun euroBans() {
        val b = zone("milano", "milano-b"); val c = zone("milano", "milano-c")
        val monday = date(2026, 10, 26, 10)
        assertTrue(verdict(b, at = monday) is Verdict.Yes)
        assertTrue(verdict(b, car.copy(fuel = Fuel.ELECTRIC, euro = 0), monday) is Verdict.Yes)
        assertTrue(verdict(b, car.copy(fuel = Fuel.DIESEL, euro = 5), monday) is Verdict.No)
        assertTrue(verdict(b, car.copy(euro = 3), monday) is Verdict.No)
        val e4 = verdict(b, car.copy(euro = 4), monday)
        assertTrue(e4 is Verdict.Yes && "2028" in e4.reason, e4.toString())
        assertTrue(verdict(b, car.copy(euro = 4), date(2028, 10, 2, 10)) is Verdict.No)
        assertTrue(verdict(c, car.copy(fuel = Fuel.DIESEL, euro = 5), monday) is Verdict.No)
        assertTrue(verdict(c, at = monday) is Verdict.Conditional)
        val lines = carAdvice(car.copy(fuel = Fuel.DIESEL, euro = 5), cities.values.toList(), monday)
        assertEquals(2, lines.count { !it.ok })
    }

    @Test fun holidaysAndEaster() {
        assertEquals(java.time.LocalDate.of(2026, 4, 5), ItalianHolidays.easterSunday(2026))
        assertEquals(java.time.LocalDate.of(2027, 3, 28), ItalianHolidays.easterSunday(2027))
        assertTrue(ItalianHolidays.isHoliday(date(2026, 4, 6, 10)))                       // Pasquetta
        assertTrue(ItalianHolidays.isHoliday(date(2026, 12, 8, 10)))
        assertFalse(ItalianHolidays.isHoliday(date(2026, 4, 7, 10)))
        val a = zone("firenze", "firenze-a")
        assertTrue(verdict(a, at = date(2026, 12, 8, 10)) is Verdict.Unsure)              // festivo non confermato
    }

    @Test fun stale() {
        val old = RuleEngine(now = { date(2027, 6, 1, 12) })
        assertTrue(old.answer(zone("firenze", "firenze-b"), car, emptyList(), false, date(2027, 6, 1, 12)).verdict is Verdict.Unsure)
    }

    @Test fun addressLookup() {
        val all = cities.values.toList()
        assertEquals(listOf("milano-c", "milano-b"), zonesAt(all, Coordinate(45.4641, 9.1919)).map { it.second.id })
        assertEquals(ZoneKind.RESTRICTED, zonesAt(all, Coordinate(43.7696, 11.2558)).first().second.type)
        assertTrue(zonesAt(all, Coordinate(41.9028, 12.4964)).isEmpty())
        assertTrue(zone("milano", "milano-c").distance(45.4850, 9.2040) > 300)
        assertNotNull(pedestrianAreaAt(all, Coordinate(44.4939, 11.3426)))                 // Piazza Maggiore
    }

    @Test fun route() {
        val florence = cities["firenze"]!!
        val path = RouteCheck.densify(listOf(Coordinate(43.79, 11.24), Coordinate(43.7696, 11.2558)))
        assertTrue(path.size > 20)
        val monday10 = date(2026, 10, 26, 10)
        val c = RouteCheck.crossings(path, florence.zones, monday10, 600.0) { z, t -> engine.answer(z, car, emptyList(), false, t) }
        assertTrue(c.isNotEmpty() && c.any { it.isDestination })
        assertTrue(RouteCheck.worst(c)!!.answer.verdict is Verdict.No)
        val total = Geometry.remaining(Coordinate(43.77, 11.25), listOf(Coordinate(43.77, 11.25), Coordinate(43.77, 11.26), Coordinate(43.78, 11.26)))
        assertEquals(1916.0, total, 30.0)
    }

    @Test fun guardian() {
        val zones = cities["firenze"]!!.zones
        val monday10 = date(2026, 10, 26, 10)
        val ans: (Zone, Double) -> Answer = { z, _ -> engine.answer(z, car, emptyList(), false, monday10) }
        val first = GuardianScan.scan(Coordinate(43.79, 11.24), zones, emptyMap(), ans)
        val second = GuardianScan.scan(Coordinate(43.785, 11.245), zones, first.distances, ans)
        assertNotNull(second.threat); assertTrue(second.threat!!.meters < first.threat!!.meters)
        assertNull(GuardianScan.scan(Coordinate(43.79, 11.24), zones, second.distances, ans).threat)
        val inside = GuardianScan.scan(Coordinate(43.7696, 11.2558), zones, second.distances, ans)
        assertTrue(inside.entered.any { it.first.id == "firenze-a" })
    }

    @Test fun signReader() {
        val a = SignReader.parse("ZONA TRAFFICO LIMITATO\n7.30-20.00\nFERIALI\nCONTROLLO ELETTRONICO")
        assertEquals(listOf(SignReader.Rule(setOf(2, 3, 4, 5, 6, 7), 450, 1200)), a.rules)
        assertTrue(a.holidaysExcluded)
        assertTrue(SignReader.isActive(a, date(2026, 10, 26, 10)))
        assertFalse(SignReader.isActive(a, date(2026, 10, 25, 10)))
        val b = SignReader.parse("LUN-VEN 7:30 - 19:30\nfestivi esclusi")
        assertEquals(setOf(2, 3, 4, 5, 6), b.rules.first().days)
        assertFalse(SignReader.isActive(b, date(2026, 12, 8, 10)))
        val c = SignReader.parse("GIO VEN SAB dalle 23 alle 3")
        assertEquals(setOf(5, 6, 7), c.rules.first().days)
        assertTrue(SignReader.isActive(c, date(2026, 7, 3, 1)))
        assertFalse(SignReader.parse("Benvenuti a Firenze").understood)
        assertEquals(7, SignReader.parse("TUTTI I GIORNI 0-24").rules.first().days.size)
    }

    @Test fun catalog() {
        assertEquals(6, CarCatalog.euroForYear(2019)); assertEquals(5, CarCatalog.euroForYear(2012)); assertEquals(3, CarCatalog.euroForYear(2004))
        if (verdict(zone("firenze", "firenze-a"), at = date(2026, 10, 26, 22)) !is Verdict.Yes) fail("di notte si entra")
    }
}
