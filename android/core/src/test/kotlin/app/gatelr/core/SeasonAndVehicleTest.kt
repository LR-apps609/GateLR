package app.gatelr.core

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.io.File
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/** Stagioni con le regole (1.17.1) e moto/scooter: gli stessi casi di Tests/SeasonAndVehicleTests.swift */
class SeasonAndVehicleTest {
    private val engine = RuleEngine(now = { date(2026, 10, 26, 12) })
    private val car = Vehicle(name = "Rental car", model = "Fiat 500", fuel = Fuel.PETROL, euro = 6, isRental = true)
    private val moto = Vehicle(name = "Scooter", model = "SH 125", fuel = Fuel.PETROL, euro = 5, type = VehicleType.MOTORCYCLE)

    private fun date(y: Int, m: Int, d: Int, h: Int, min: Int = 0): Instant =
        LocalDateTime.of(y, m, d, h, min).atZone(RuleEngine.ROME).toInstant()

    private val dir = File(System.getProperty("gatelr.cities"))
    private val cities: Map<String, City> by lazy {
        dir.listFiles { f -> f.extension == "json" && f.name != "manifest.json" }!!
            .map { CityLoader.decode(it.readText()) }.associateBy { it.id }
    }
    private fun zone(city: String, id: String) = cities[city]!!.zones.first { it.id == id }
    private fun verdict(z: Zone, v: Vehicle, at: Instant) = engine.answer(z, v, emptyList(), false, at).verdict

    @Test fun nthWeekdayRules() {
        val firstThuApril = TimeWindow.Season.DayRule(4, 5, 1)
        val firstSunOctober = TimeWindow.Season.DayRule(10, 1, 1)
        assertEquals(LocalDate.of(2026, 4, 2), firstThuApril.day(2026))
        assertEquals(LocalDate.of(2027, 4, 1), firstThuApril.day(2027))
        assertEquals(LocalDate.of(2028, 4, 6), firstThuApril.day(2028))
        assertEquals(LocalDate.of(2026, 10, 4), firstSunOctober.day(2026))
        assertEquals(LocalDate.of(2027, 10, 3), firstSunOctober.day(2027))
        assertEquals(LocalDate.of(2028, 10, 1), firstSunOctober.day(2028))
        // Ultima domenica di marzo e di ottobre (ora legale), con lo spostamento in giorni
        assertEquals(LocalDate.of(2026, 3, 29), TimeWindow.Season.DayRule(3, 1, -1).day(2026))
        assertEquals(LocalDate.of(2026, 4, 2), TimeWindow.Season.DayRule(3, 1, -1, 4).day(2026))
        assertEquals(LocalDate.of(2027, 10, 30), TimeWindow.Season.DayRule(10, 1, -1, -1).day(2027))
        assertEquals(null, TimeWindow.Season.DayRule(2, 2, 5).day(2026))           // nessun quinto lunedì di febbraio
    }

    /** Firenze, notti d'estate «dal primo giovedì di aprile alla prima domenica di ottobre», 23 → 3 */
    @Test fun florenceSummerNights2026to2028() {
        val g = zone("firenze", "firenze-g")
        val s = g.windows.first { it.season != null }.season!!
        assertEquals(listOf(4, 1, 10, 7), listOf(s.fromMonth, s.fromDay, s.toMonth, s.toDay))      // ripiego largo per le app vecchie
        // 2026: dal 2 aprile al 4 ottobre
        assertFalse(engine.isActive(g, date(2026, 3, 28, 23, 30)))          // sabato prima della stagione
        assertTrue(engine.isActive(g, date(2026, 4, 2, 23, 30)))            // primo giovedì
        assertTrue(engine.isActive(g, date(2026, 4, 3, 2)))                 // la notte dopo, oltre la mezzanotte
        assertTrue(engine.isActive(g, date(2026, 10, 3, 23, 30)))           // ultimo sabato
        assertTrue(engine.isActive(g, date(2026, 10, 4, 2, 30)))            // domenica 4 ottobre alle 2:30, notte di sabato
        assertFalse(engine.isActive(g, date(2026, 10, 8, 23, 30)))
        assertEquals(date(2026, 4, 2, 23), engine.nextChange(g, date(2026, 4, 1, 12)))
        // 2027: dal 1° aprile al 3 ottobre (il giovedì 7 ottobre le date fisse direbbero «attiva»)
        assertFalse(engine.isActive(g, date(2027, 3, 27, 23, 30)))
        assertTrue(engine.isActive(g, date(2027, 4, 1, 23, 30)))
        assertTrue(engine.isActive(g, date(2027, 4, 2, 1)))
        assertTrue(engine.isActive(g, date(2027, 10, 2, 23, 30)))
        assertTrue(engine.isActive(g, date(2027, 10, 3, 2)))
        assertFalse(engine.isActive(g, date(2027, 10, 7, 23, 30)))
        // 2028: dal 6 aprile al 1° ottobre (sabato 1° aprile le date fisse direbbero «attiva»)
        assertFalse(engine.isActive(g, date(2028, 4, 1, 23, 30)))
        assertFalse(engine.isActive(g, date(2028, 4, 2, 2)))
        assertTrue(engine.isActive(g, date(2028, 4, 6, 23, 30)))
        assertTrue(engine.isActive(g, date(2028, 4, 7, 2)))
        assertTrue(engine.isActive(g, date(2028, 9, 30, 23, 30)))
        assertTrue(engine.isActive(g, date(2028, 10, 1, 2, 30)))            // domenica 1° ottobre, notte di sabato
        assertFalse(engine.isActive(g, date(2028, 10, 5, 23, 30)))
        assertFalse(engine.isActive(g, date(2028, 10, 6, 1)))
        // Le date mostrate: la stagione in corso o la prossima
        assertEquals(LocalDate.of(2027, 4, 1) to LocalDate.of(2027, 10, 3), s.shown(LocalDate.of(2026, 10, 28)))
        assertEquals(LocalDate.of(2026, 4, 2) to LocalDate.of(2026, 10, 4), s.shown(LocalDate.of(2026, 2, 1)))
    }

    /** Bergamo, Città Alta e Colli: sere con l'ora legale, dal giovedì dopo l'ultima domenica di marzo al sabato prima dell'ultima di ottobre */
    @Test fun bergamoSummerTimeEvenings() {
        val colli = zone("bergamo", "bergamo-colli")
        assertTrue(engine.isActive(colli, date(2026, 4, 2, 21, 30)))
        assertFalse(engine.isActive(colli, date(2026, 3, 28, 21, 30)))
        assertTrue(engine.isActive(colli, date(2026, 10, 24, 23)))          // ultimo sabato
        assertTrue(engine.isActive(colli, date(2026, 10, 25, 0, 30)))       // dopo mezzanotte, ancora la sera di sabato
        assertFalse(engine.isActive(colli, date(2026, 10, 30, 21, 30)))     // venerdì 30: con le date fisse sarebbe attiva
        assertTrue(engine.isActive(colli, date(2027, 10, 30, 21, 30)))      // nel 2027 l'ultimo sabato è il 30
    }

    /** Le date fisse da sole valgono come prima */
    @Test fun fixedSeasonStillWorks() {
        val s = TimeWindow.Season(5, 1, 10, 31)
        assertTrue(s.contains(LocalDate.of(2027, 5, 1)))
        assertFalse(s.contains(LocalDate.of(2027, 11, 1)))
        val winter = TimeWindow.Season(12, 8, 1, 6)
        assertTrue(winter.contains(LocalDate.of(2027, 1, 3)))
        assertFalse(winter.contains(LocalDate.of(2027, 2, 3)))
    }

    /** Le app fino alla 1.17.0 leggono le città con modelli senza «from»/«to» e «exemptVehicleTypes»: le chiavi nuove si ignorano */
    @Serializable private data class OldSeason(val fromMonth: Int, val fromDay: Int, val toMonth: Int, val toDay: Int)
    @Serializable private data class OldWindow(val weekdays: Set<Int>, val start: Int, val end: Int, val season: OldSeason? = null)
    @Serializable private data class OldZone(val id: String, val windows: List<OldWindow>, val exemptFuels: Set<Fuel> = emptySet())
    @Serializable private data class OldCity(val id: String, val zones: List<OldZone>)

    @Test fun oldAppsReadTheNewFields() {
        val json = Json { ignoreUnknownKeys = true; coerceInputValues = true }
        val city = json.decodeFromString(OldCity.serializer(), File(dir, "firenze.json").readText())
        val s = city.zones.first { it.id == "firenze-g" }.windows.first().season!!
        assertEquals(OldSeason(4, 1, 10, 7), s)
        json.decodeFromString(OldCity.serializer(), File(dir, "roma.json").readText())
    }

    @Test fun motorbikes() {
        val monday = date(2026, 10, 26, 12)
        // Esenti: Firenze (disciplinare, punto 17), Roma Centro; non esenti: Roma Tridente, Ostuni, Arezzo ZTL B
        assertTrue(verdict(zone("firenze", "firenze-a"), moto, monday) is Verdict.Yes)
        assertTrue(verdict(zone("firenze", "firenze-a"), car, monday) is Verdict.No)
        assertTrue(verdict(zone("roma", "roma-centro"), moto, monday) is Verdict.Yes)
        assertTrue(verdict(zone("roma", "roma-tridente"), moto, monday) is Verdict.No)
        assertTrue(verdict(zone("ostuni", "ostuni-centro"), moto, date(2026, 10, 26, 20)) is Verdict.No)
        assertTrue(verdict(zone("arezzo", "arezzo-ztl-b"), moto, date(2026, 10, 26, 20)) is Verdict.No)
        assertTrue(verdict(zone("arezzo", "arezzo-ztl-a"), moto, date(2026, 10, 26, 10)) is Verdict.Yes)
        // Napoli Centro Antico: dentro c'è Mezzocannone, vietato alle moto
        assertFalse(verdict(zone("napoli", "napoli-centro-antico"), moto, date(2026, 10, 26, 12)) is Verdict.Yes)
        // Scudo Verde: dalla 1.17.2 i limiti delle moto dalle fonti ufficiali («motoBans»): una moto Euro 5 entra.
        // Milano Area B non li ha: per le moto «controlla sul sito del Comune»
        assertTrue(verdict(zone("firenze", "firenze-scudo-verde"), moto, date(2026, 12, 1, 3)) is Verdict.Yes)
        assertTrue(verdict(zone("milano", "milano-b"), moto, monday) is Verdict.Conditional)
        // Una moto Euro 2 non è un'auto Euro 2: i divieti delle auto non la toccano
        assertEquals(null, zone("firenze", "firenze-scudo-verde").ban(moto.copy(euro = 0), date(2026, 12, 1, 3)))
        // Senza «type» i veicoli salvati restano auto
        assertEquals(VehicleType.CAR, CityLoader.json.decodeFromString(Vehicle.serializer(), """{"name":"x","fuel":"petrol","euro":6}""").kind)
        assertEquals(5, CarCatalog.euroForYear(2022, VehicleType.MOTORCYCLE))
        assertEquals(6, CarCatalog.euroForYear(2022, VehicleType.CAR))
    }

    /** 1.17.2: i limiti delle moto dove le fonti ufficiali li scrivono (gli stessi casi di Tests/MotoBanTests.swift) */
    @Test fun motorbikeBansFromOfficialSources() {
        val sv = zone("firenze", "firenze-scudo-verde")
        val oct = date(2026, 10, 29, 12); val dec = date(2026, 12, 2, 12)
        fun m(euro: Int, cls: String, stroke: Int) = moto.copy(euro = euro, motoClass = cls, stroke = stroke)
        assertTrue(verdict(sv, m(1, "moped", 2), oct) is Verdict.No)          // ciclomotore 2 tempi Euro 0–1
        assertTrue(verdict(sv, m(1, "moped", 4), oct) is Verdict.Yes)         // 4 tempi: solo Euro 0 nella fase 1
        assertTrue(verdict(sv, m(0, "moped", 4), oct) is Verdict.No)
        assertTrue(verdict(sv, m(0, "motorcycle", 2), oct) is Verdict.No)     // motociclo 2 tempi Euro 0
        assertTrue(verdict(sv, m(0, "motorcycle", 4), oct) is Verdict.Yes)
        assertTrue(verdict(sv, m(1, "motorcycle", 4), dec) is Verdict.No)     // fase 2: tutte le due ruote Euro 0–1
        assertTrue(verdict(sv, m(2, "moped", 2), dec) is Verdict.Yes)
        // Le auto non cambiano
        assertTrue(verdict(sv, car.copy(fuel = Fuel.DIESEL, euro = 1), oct) is Verdict.No)
        assertTrue(verdict(sv, car.copy(fuel = Fuel.DIESEL, euro = 5), oct) is Verdict.Yes)
        assertEquals(null, sv.motoBan(car.copy(euro = 0), dec))
        // Padova, antismog (ordinanza 46/2026): moto Euro 0 vietate
        val pd = zone("padova", "padova-antismog")
        assertTrue(verdict(pd, moto.copy(euro = 0), date(2026, 11, 2, 10)) is Verdict.No)
        assertTrue(verdict(pd, moto.copy(euro = 1), date(2026, 11, 2, 10)) is Verdict.Yes)
        // Milano Area B: nessun limite delle moto nei dati, resta «a una condizione»
        assertTrue(verdict(zone("milano", "milano-b"), moto, date(2026, 10, 26, 12)) is Verdict.Conditional)
    }
}
