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

    @Test fun sevenAnswersHaveShapeWordAndTone() {
        val states = AnswerState.entries
        assertEquals(7, states.size)
        assertEquals(7, states.map { FinalAnswer.shapeOf(it) }.toSet().size, "ogni risposta ha la sua forma")
        assertEquals(7, states.map { FinalAnswer.wordKeyOf(it) }.toSet().size, "ogni risposta ha la sua parola")
        assertEquals(AnswerTone.RED, FinalAnswer.toneOf(AnswerState.NO))
        assertEquals(AnswerTone.GREEN, FinalAnswer.toneOf(AnswerState.YES))
        assertEquals(AnswerTone.AMBER, FinalAnswer.toneOf(AnswerState.CONDITION))
        assertEquals(AnswerTone.AMBER, FinalAnswer.toneOf(AnswerState.CHECK))
        assertEquals(AnswerTone.GREY, FinalAnswer.toneOf(AnswerState.OUTSIDE), "Fuori dalla ZTL è grigio (Ledion, 07/11)")
        assertEquals(AnswerTone.NEUTRAL, FinalAnswer.toneOf(AnswerState.UNCOVERED))
        // ZTL non attiva: un solo token, oggi verde
        assertEquals(AnswerTokens.stateOff, FinalAnswer.toneOf(AnswerState.OFF))
        assertEquals(AnswerTone.GREEN, AnswerTokens.stateOff)
    }

    /** Gli stessi casi dell'iPhone e del sito: la risposta finale segue il colore della mappa, salvo «Fuori dalla ZTL» grigio */
    @Test fun sharedCasesAsFinalAnswers() {
        val file = Json.parseToJsonElement(File(dir, "../../shared/engine-cases.json").readText()).jsonObject
        val vehicles = file["vehicles"]!!.jsonObject
        val now = OffsetDateTime.parse(file["now"]!!.jsonPrimitive.content).toInstant()
        val errors = mutableListOf<String>()
        for (c in file["cases"]!!.jsonArray.map { it.jsonObject }) {
            if ("source" in c || c["now"] != null) continue
            val id = c["id"]!!.jsonPrimitive.content
            val j = vehicles[c["vehicle"]!!.jsonPrimitive.content]!!.jsonObject
            val v = Vehicle(name = "", fuel = Fuel.entries.first { it.name.lowercase() == j["fuel"]!!.jsonPrimitive.content }, euro = j["euro"]!!.jsonPrimitive.int,
                type = j["type"]?.jsonPrimitive?.contentOrNull?.let { t -> VehicleType.entries.first { it.raw == t } },
                motoClass = j["motoClass"]?.jsonPrimitive?.contentOrNull, stroke = j["stroke"]?.jsonPrimitive?.intOrNull)
            val engine = RuleEngine(now = { now })
            val all = cities.map { city -> city.copy(zones = city.zones.map { z -> z.copy(source = z.source.copy(pageChanged = false)) }) }
            val place = c["place"]!!.jsonObject
            val at = OffsetDateTime.parse(c["at"]!!.jsonPrimitive.content).toInstant()
            val p = PlaceCheck.of(all, Coordinate(place["lat"]!!.jsonPrimitive.double, place["lon"]!!.jsonPrimitive.double), engine, v, emptyList(), false, at)
            val f = FinalAnswer.of(p, engine)
            val want = c["expect"]!!.jsonObject["colour"]!!.jsonPrimitive.content
            val got = when (f.tone) {
                AnswerTone.RED -> "red"; AnswerTone.AMBER -> "yellow"; AnswerTone.GREEN -> "green"; AnswerTone.NEUTRAL -> "neutral"
                AnswerTone.GREY -> if (p.zone == null && p.covered) "green" else "grey"
            }
            if (want != got) errors += "$id: atteso $want, ottenuto $got (${f.state})"
            if (p.zone == null && p.pedestrian == null && p.covered && f.state != AnswerState.OUTSIDE) errors += "$id: fuori dalla ZTL non grigio"
            if (!p.covered && f.state != AnswerState.UNCOVERED) errors += "$id: fuori copertura non neutro"
            if (p.unofficial && f.isGreen) errors += "$id: fonte non ufficiale verde"
            if (f.state == AnswerState.CHECK && p.unofficial && f.reason != AnswerReason.UNOFFICIAL) errors += "$id: motivo del giallo"
        }
        assertEquals(emptyList(), errors, errors.joinToString("\n"))
    }

    @Test fun ledPanelFromEngineNotFromAnswer() {
        val z = cities.first { it.id == "firenze" }.zones.first()
        val on = FinalAnswer.of(z, null, Answer(Verdict.No("r"), true, null))
        assertEquals("ZTL ATTIVA", on.panel)
        val off = FinalAnswer.of(z, null, Answer(Verdict.Yes("r"), false, null))
        assertEquals(AnswerState.OFF, off.state); assertEquals("ZTL NON ATTIVA", off.panel)
        val ok = FinalAnswer.of(z, null, Answer(Verdict.Yes("r"), true, null))
        assertEquals(AnswerState.YES, ok.state); assertEquals("ZTL ATTIVA", ok.panel); assertNotNull(ok.panelLine)
        assertNull(FinalAnswer(AnswerState.UNCOVERED).panel)
        assertNull(FinalAnswer(AnswerState.OUTSIDE, gatesOn = false).panel)
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
                    val f = FinalAnswer.of(z, city, a, engine)
                    assertFalse(f.isGreen, "${z.id} verde")
                    if (f.state == AnswerState.CHECK) assertEquals(AnswerReason.UNOFFICIAL, f.reason)
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

    /** Solo le zone davanti: la stessa zona a 200 m non avvisa se è alle spalle */
    @Test fun onlyAheadInDirection() {
        val square = listOf(Coordinate(43.0, 11.0), Coordinate(43.0, 11.01), Coordinate(43.01, 11.01), Coordinate(43.01, 11.0))
        val z = Zone(id = "t", name = "Sector T · Test", summary = "", perimeter = square, gates = emptyList(), windows = emptyList(),
            hotelCanRegister = false, source = Source(authority = "x", pageURL = "x", checkedOn = "2026-11-01T00:00:00Z", reviewedByHuman = true, pending = emptyList(), links = emptyList()))
        val c = ThreatCandidate(z, "Test")
        val south = Coordinate(42.9982, 11.0)          // circa 200 m a sud dello spigolo della zona
        val no = Answer(Verdict.No("r"), true, null)
        val north = ThreatEvaluator.scan(south, 0.0, listOf(c), emptyMap(), true) { _, _ -> no }
        assertNotNull(north.threat, "verso nord la zona è davanti")
        assertTrue(north.threat!!.meters in 150.0..250.0)
        val away = ThreatEvaluator.scan(south, 180.0, listOf(c), emptyMap(), true) { _, _ -> no }
        assertNull(away.threat, "verso sud è alle spalle")
        val yes = ThreatEvaluator.scan(south, 0.0, listOf(c), emptyMap(), true) { _, _ -> Answer(Verdict.Yes("r"), true, null) }
        assertNull(yes.threat, "mai un avviso verde")
        // Dentro la zona: «Adesso» risponde per quella
        assertEquals(0.0, ThreatEvaluator.nowZone(Coordinate(43.005, 11.005), null, listOf(c))!!.second)
        assertNull(ThreatEvaluator.nowZone(south, 180.0, listOf(c)), "alle spalle non conta per «Adesso»")
        val d = ThreatDeduper()
        assertTrue(d.shouldAlert("far|t", 0)); assertFalse(d.shouldAlert("far|t", 1000))
        d.moved(mapOf("t" to 1000.0)); assertTrue(d.shouldAlert("far|t", 2000))
    }

    /** Le parole nuove della 2.0 ci sono in tutte le 8 lingue */
    @Test fun newWordsInEightLanguages() {
        val keys = listOf("Outside the ZTL", "ZTL not active", "Data out of date", "Unofficial source", "Not sure", "Help",
            "Now", "Map", "Trip", "Navigate anyway", "Garage and settings", "Share the answer",
            "The panel will say ZTL ATTIVA: that's fine for you.", "If the panel says so, don't enter.", "For %@")
        for (lang in listOf("it", "de", "fr", "es", "nl", "pl", "zh")) {
            val t = Json.parseToJsonElement(File(i18n, "strings_$lang.json").readText()).jsonObject
            for (k in keys) assertNotNull(t[k], "$lang: manca «$k»")
        }
        Strings.language = "it"
        Strings.table = Json.parseToJsonElement(File(i18n, "strings_it.json").readText()).jsonObject.mapValues { it.value.jsonPrimitive.content }
        assertEquals("FUORI DALLA ZTL", FinalAnswer(AnswerState.OUTSIDE).title)
        assertEquals("NON ENTRARE", FinalAnswer(AnswerState.NO).title)
    }
}
