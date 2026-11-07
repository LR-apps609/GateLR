package app.gatelr.core

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.double
import kotlinx.serialization.json.int
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.io.File
import java.time.Instant
import java.time.LocalDateTime
import java.time.OffsetDateTime
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** 2.0 «Android alla pari»: le sette risposte (forma + parola + colore), le città non ufficiali, i festivi, il
 *  valutatore della minaccia (direzione, 300/600 m) e le parole nelle 8 lingue */
class AllaPariTest {
    private val dir = File(System.getProperty("gatelr.cities"))
    private val i18n = File(System.getProperty("gatelr.i18n"))
    private val cities: List<City> by lazy {
        val man = Json.parseToJsonElement(File(dir, "manifest.json").readText()).jsonObject
        (man["cities"]!!.jsonArray + (man["unofficialCities"]?.jsonArray ?: emptyList()))
            .map { CityLoader.decode(File(dir, it.jsonObject["file"]!!.jsonPrimitive.content).readText()) }
    }
    private fun date(y: Int, m: Int, d: Int, h: Int): Instant = LocalDateTime.of(y, m, d, h, 0).atZone(RuleEngine.ROME).toInstant()
    private val car = Vehicle(name = "Golf", fuel = Fuel.PETROL, euro = 6)

    @AfterTest fun english() { Strings.language = "en"; Strings.table = emptyMap() }

    /** Forma + parola + colore: sette forme diverse, sette parole diverse; «Fuori dalla ZTL» grigio, fuori copertura neutro */
    @Test fun sevenAnswersHaveShapeWordAndTone() {
        assertEquals(7, Stato.entries.size)
        assertEquals(7, Stato.entries.map { it.forma }.toSet().size, "ogni risposta ha la sua forma")
        assertEquals(7, Stato.entries.map { it.key }.toSet().size, "ogni risposta ha la sua parola")
        assertEquals(Tono.GRIGIO, Stato.FUORI_ZTL.color, "Fuori dalla ZTL è grigio (Ledion, 07/11)")
        assertEquals(Tono.NEUTRO, Stato.NON_COPERTO.color)
        assertEquals(Forma.DOMANDA_TRATTEGGIATA, Stato.NON_COPERTO.forma)
        assertEquals(RispostaFinale.STATE_OFF, Stato.ZTL_NON_ATTIVA.color)
    }

    /** Il pannello LED dal motore (varchi accesi o no), mai dalla risposta; nessun pannello fuori dalla ZTL o fuori copertura */
    @Test fun ledPanelFromEngineNotFromAnswer() {
        val z = cities.first { it.id == "firenze" }.zones.first()
        val on = RispostaFinale.forZone(Answer(Verdict.No("r"), true, null), z)
        assertEquals("ZTL ATTIVA", on.panel); assertNull(on.panelLine)
        val off = RispostaFinale.forZone(Answer(Verdict.Yes("r"), false, null), z)
        assertEquals(Stato.ZTL_NON_ATTIVA, off.stato); assertEquals("ZTL NON ATTIVA", off.panel)
        val ok = RispostaFinale.forZone(Answer(Verdict.Yes("r"), true, null), z)
        assertEquals(Stato.ENTRA_PURE, ok.stato); assertEquals("ZTL ATTIVA", ok.panel); assertNotNull(ok.panelLine)
        val check = RispostaFinale.forZone(Answer(Verdict.Unsure("r"), true, null), z)
        assertEquals("ZTL ATTIVA", check.panel); assertNotNull(check.panelLine)
        assertNull(RispostaFinale(Stato.NON_COPERTO).panel)
        assertNull(RispostaFinale(Stato.FUORI_ZTL, gatesOn = false).panel)
        // TalkBack: un solo elemento, la parola per prima
        val firenze = cities.first { it.id == "firenze" }
        val s = RispostaFinale.forZone(Answer(Verdict.No("r"), true, null), z, city = firenze).spoken("until 20:00", "Golf · diesel Euro 5", "now")
        assertTrue(s.startsWith("Don't enter. Florence, "), s)
        assertTrue(s.endsWith("For Golf · diesel Euro 5, now."), s)
    }

    /** Le 5 città da fonti non ufficiali ci sono e non sono mai verdi */
    @Test fun unofficialCitiesPresentAndNeverGreen() {
        val ids = listOf("cagliari", "mantova", "ostuni", "polignano-a-mare", "salerno")
        val engine = RuleEngine(now = { date(2026, 11, 1, 12) })
        for (id in ids) {
            val city = cities.firstOrNull { it.id == id }
            assertNotNull(city, id)
            for (z in city.zones) {
                assertTrue(z.isUnofficial, z.id)
                for (h in listOf(3, 12, 23)) for (d in 2..8) {
                    val a = engine.trustedAnswer(z, car, emptyList(), false, date(2026, 11, d, h))
                    val f = RispostaFinale.forZone(a.copy(verdict = a.verdict.shown(z.isUnofficial)), z, city.status, city)
                    assertFalse(f.color == Tono.VERDE, "${z.id} verde")
                    if (f.stato == Stato.CONTROLLA_CARTELLO && a.doubt == null) assertEquals(Motivo.NON_UFFICIALE, f.motivo)
                }
            }
        }
    }

    /** Festivi come domenica (Bergamo l'8 dicembre) e festivi locali (Roma, San Pietro e Paolo) */
    @Test fun holidaysLikeIphone() {
        val engine = RuleEngine(now = { date(2026, 11, 1, 12) })
        val colli = cities.first { it.id == "bergamo" }.zones.first { it.id == "bergamo-colli" }
        assertEquals(true, colli.holidaysAsSunday)
        assertTrue(engine.isActive(colli, date(2026, 12, 8, 11)), "l'8 dicembre vale l'orario della domenica")
        val roma = cities.first { it.id == "roma" }
        assertTrue(roma.zones.first().localHolidays.orEmpty().contains("06-29"))
        assertTrue(engine.isHoliday(roma.zones.first(), java.time.LocalDate.of(2027, 6, 29)))
    }

    @Test fun alertDistanceBySpeed() {
        assertEquals(300.0, ThreatEvaluator.alertDistance(null))
        assertEquals(300.0, ThreatEvaluator.alertDistance(40 / 3.6))
        assertEquals(600.0, ThreatEvaluator.alertDistance(70 / 3.6))
    }

    /** «Adesso»: la zona in cui sei, o quella entro 300 m DAVANTI; alle spalle non conta */
    @Test fun nowOnlyAheadInDirection() {
        val square = listOf(Coordinate(43.0, 11.0), Coordinate(43.0, 11.01), Coordinate(43.01, 11.01), Coordinate(43.01, 11.0))
        val z = Zone(id = "t", name = "Sector T · Test", summary = "", perimeter = square, gates = emptyList(), windows = emptyList(),
            hotelCanRegister = false, source = Source(authority = "x", pageURL = "x", checkedOn = "2026-11-01T00:00:00Z", reviewedByHuman = true, pending = emptyList(), links = emptyList()))
        val c = ThreatCandidate(z, null)
        val south = Coordinate(42.9982, 11.0)          // circa 200 m a sud dello spigolo della zona
        assertEquals(0.0, Adesso.zone(Coordinate(43.005, 11.005), null, listOf(c))!!.second)
        val ahead = Adesso.zone(south, 0.0, listOf(c))
        assertNotNull(ahead, "verso nord la zona è davanti"); assertTrue(ahead.second in 150.0..250.0)
        assertNull(Adesso.zone(south, 180.0, listOf(c)), "verso sud è alle spalle")
        assertNull(Adesso.zone(Coordinate(42.99, 11.0), 0.0, listOf(c)), "oltre 300 m non conta")
    }

    /** Le parole nuove della 2.0 ci sono in tutte le 8 lingue */
    @Test fun newWordsInEightLanguages() {
        val keys = listOf("Outside the ZTL", "ZTL not active", "Data out of date", "Unofficial source", "Not sure", "Help", "Pedestrian area",
            "Now", "Map", "Trip", "Navigate anyway", "Garage and settings", "Share the answer",
            "The panel will say ZTL ATTIVA: that's fine for you.", "If the panel says so, don't enter.", "For %@")
        for (lang in listOf("it", "de", "fr", "es", "nl", "pl", "zh")) {
            val t = Json.parseToJsonElement(File(i18n, "strings_$lang.json").readText()).jsonObject
            for (k in keys) assertNotNull(t[k], "$lang: manca «$k»")
        }
        Strings.language = "it"
        Strings.table = Json.parseToJsonElement(File(i18n, "strings_it.json").readText()).jsonObject.mapValues { it.value.jsonPrimitive.content }
        assertEquals("Fuori dalla ZTL", RispostaFinale(Stato.FUORI_ZTL).title)
        assertEquals("Non entrare", RispostaFinale(Stato.NON_ENTRARE).title)
    }
}
