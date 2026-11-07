package app.gatelr.core

import java.io.File
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** 2.1 «Una risposta, sette stati»: RispostaFinale e il valutatore di minaccia, come Tests/RispostaFinaleTests.swift */
class RispostaFinaleTest {
    private val cities: Map<String, City> by lazy {
        File(System.getProperty("gatelr.cities")).listFiles { f -> f.extension == "json" && f.name != "manifest.json" }!!
            .map { CityLoader.decode(it.readText()) }.associateBy { it.id }
    }
    private val florence get() = cities["firenze"]!!
    private val sectorA get() = florence.zones.first { it.id == "firenze-a" }
    private val unofficialA get() = sectorA.copy(source = sectorA.source.copy(official = false))

    private fun a(v: Verdict, on: Boolean = true, doubt: Motivo? = null) = Answer(v, on, null, doubt)
    private val yes = Verdict.Yes("r"); private val no = Verdict.No("r")
    private val cond = Verdict.Conditional("r", "c"); private val unsure = Verdict.Unsure("r")

    @Test fun sevenStatesFromTheEngine() {
        fun s(ans: Answer, z: Zone = sectorA, status: City.Status? = City.Status.DRAFT) = RispostaFinale.forZone(ans, z, status)
        assertEquals(Stato.NON_ENTRARE, s(a(no)).stato)
        assertEquals(Stato.CONDIZIONE, s(a(cond)).stato)
        assertEquals(Stato.ENTRA_PURE, s(a(yes)).stato)
        assertEquals(Stato.ZTL_NON_ATTIVA, s(a(yes, on = false)).stato)
        assertEquals(RispostaFinale(Stato.CONTROLLA_CARTELLO, Motivo.FESTIVO, sectorA, null, false, true, null), s(a(unsure, doubt = Motivo.FESTIVO)))
        assertEquals(Motivo.NON_SICURO, s(a(unsure)).motivo)
        assertEquals(Motivo.SCADUTI, s(a(unsure, doubt = Motivo.SCADUTI)).motivo)
        // Fonte non ufficiale: il «sì» è «Controlla il cartello», il «no» resta rosso (Salerno resta rossa)
        assertEquals(Stato.CONTROLLA_CARTELLO, s(a(yes), unofficialA).stato)
        assertEquals(Motivo.NON_UFFICIALE, s(a(yes, on = false), unofficialA).motivo)
        assertEquals(Stato.NON_ENTRARE, s(a(no), unofficialA).stato)
        assertNull(s(a(no), unofficialA).motivo)
        assertEquals(L("Probably not · unofficial source"), s(a(no), unofficialA).reasonLine)
        // Città di esempio: mai verde
        assertEquals(Stato.CONTROLLA_CARTELLO, s(a(yes), status = City.Status.SAMPLE).stato)
        // Posto: fuori dalle zone, fuori copertura, area pedonale
        assertEquals(Stato.FUORI_ZTL, PlaceCheck(emptyList(), null, emptyList(), true).finale.stato)
        assertEquals(Stato.NON_COPERTO, PlaceCheck(emptyList(), null, emptyList(), false).finale.stato)
        val area = PedestrianArea("p", "Via Prova", sectorA.perimeter)
        assertEquals(Stato.NON_ENTRARE, PlaceCheck(listOf(florence to sectorA), area, listOf(a(yes)), true).finale.stato)
    }

    @Test fun wordShapeAndColour() {
        assertEquals(7, Stato.entries.size)
        assertEquals(7, Stato.entries.map { it.symbol to it.tono }.distinct().size, "forma e colore: mai due stati uguali")
        assertEquals(Stato.entries.size, Stato.entries.map { it.key }.distinct().size, "una parola per stato")
        assertEquals(Tono.VERDE, Stato.ZTL_NON_ATTIVA.color, "ZTL non attiva: oggi verde (token unico)")
        assertEquals(Tono.GRIGIO, Stato.FUORI_ZTL.color)
        assertEquals(Tono.NEUTRO, Stato.NON_COPERTO.color)
        assertTrue(Stato.NON_COPERTO.dashed)
        assertEquals(listOf(Stato.NON_ENTRARE, Stato.CONDIZIONE, Stato.CONTROLLA_CARTELLO), Stato.entries.filter { it.alerts })
        // Le parole in tutte le 8 lingue
        val dir = File(System.getProperty("gatelr.i18n"))
        for (lang in listOf("it", "de", "fr", "es", "nl", "pl", "zh")) {
            val t = kotlinx.serialization.json.Json.parseToJsonElement(File(dir, "strings_$lang.json").readText()) as kotlinx.serialization.json.JsonObject
            for (s in Stato.entries) { assertNotNull(t[s.key], "$lang: ${s.key}"); assertNotNull(t[s.lineKey], "$lang: ${s.lineKey}") }
            for (m in Motivo.entries) assertNotNull(t[m.key], "$lang: ${m.key}")
        }
    }

    @Test fun alertDistanceAndDirection() {
        assertEquals(300.0, ThreatEvaluator.alertDistance(null))
        assertEquals(300.0, ThreatEvaluator.alertDistance(13.0))
        assertEquals(600.0, ThreatEvaluator.alertDistance(15.0), "sopra 50 km/h")
        val here = Coordinate(43.7800, 11.2550)
        val north = Coordinate(43.7810, 11.2550)
        assertTrue(ThreatEvaluator.isAhead(here, north, 110.0, 0.0, null))
        assertFalse(ThreatEvaluator.isAhead(here, north, 110.0, 180.0, null), "alle spalle")
        assertTrue(ThreatEvaluator.isAhead(here, north, 110.0, null, null), "senza direzione: prudente")
        assertFalse(ThreatEvaluator.isAhead(here, north, 110.0, null, false), "ti allontani")
    }

    @Test fun oneEvaluatorWithPedestrianAreasAndTitleFromTheAnswer() {
        val f = florence
        val monday10 = java.time.LocalDateTime.of(2026, 10, 26, 10, 0).atZone(RuleEngine.ROME).toInstant()
        val engine = RuleEngine(now = { monday10 })
        val car = Vehicle(name = "Rental car", fuel = Fuel.PETROL, euro = 6)
        // Da nord verso il centro: il Settore A davanti, rosso
        val p = Coordinate(43.7790, 11.2540)
        val cands = ThreatEvaluator.candidates(listOf(f), p)
        assertTrue(cands.any { it.zone?.id == "firenze-a" })
        val ans = { c: ThreatCandidate, _: Double -> engine.trustedAnswer(c.zone!!, car, emptyList(), false, monday10) }
        val south = ThreatEvaluator.scan(p, 180.0, cands, emptyMap(), ans).threat
        assertNotNull(south)
        assertTrue(south.title.startsWith(Stato.NON_ENTRARE.title + " · "), south.title)
        assertTrue(south.finale.stato.alerts)
        // Alle spalle (verso nord, via dal centro) nessuna minaccia dal Settore A
        val back = ThreatEvaluator.scan(p, 0.0, cands.filter { it.zone?.id == "firenze-a" }, emptyMap(), ans).threat
        assertNull(back)
        // Elettrica nell'Area C attiva: entra pure, nessun avviso
        val milano = cities["milano"]!!
        val ev = Vehicle(name = "EV", fuel = Fuel.ELECTRIC, euro = 6)
        val q = Coordinate(45.4760, 9.1925)
        val mc = ThreatEvaluator.candidates(listOf(milano), q).filter { it.zone?.id == "milano-c" }
        val t = ThreatEvaluator.scan(q, 180.0, mc, emptyMap()) { c, _ -> engine.trustedAnswer(c.zone!!, ev, emptyList(), false, monday10) }
        assertNull(t.threat, "verde: nessun avviso")
        // Un solo avviso per avvicinamento
        val d = ThreatDeduper()
        assertTrue(d.shouldAlert("firenze-a", 0)); assertFalse(d.shouldAlert("firenze-a", 1000))
        d.moved(mapOf("firenze-a" to 1200.0)); assertTrue(d.shouldAlert("firenze-a", 2000))
    }

}
