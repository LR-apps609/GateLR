package app.gatelr.core

import java.io.File
import java.time.LocalDateTime
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** 1.20.1 «Dati»: «letto il» non è «verificato il»; dati non verificati, vecchi o con la pagina cambiata mai verdi */
class DatiTest {
    private val dir = File(System.getProperty("gatelr.cities"))
    private fun city(id: String) = CityLoader.decode(File(dir, "$id.json").readText())
    private fun date(y: Int, m: Int, d: Int, h: Int) = LocalDateTime.of(y, m, d, h, 0).atZone(RuleEngine.ROME).toInstant()
    private val car = Vehicle(id = "car", name = "Rental car", fuel = Fuel.PETROL, euro = 6)
    private val engine = RuleEngine(now = { date(2026, 11, 3, 12) })
    private val night = date(2026, 11, 10, 23)      // Settore A spento
    private val day = date(2026, 11, 10, 10)        // Settore A acceso
    private fun zoneA() = city("firenze").zones.first { it.id == "firenze-a" }
    private fun Zone.with(verifiedOn: String?, pageChanged: Boolean? = null) = copy(source = source.copy(verifiedOn = verifiedOn, pageChanged = pageChanged))

    /** Nei file nessuna zona ha ancora una data di verifica: non la inventiamo, ed è «non verificata» */
    @Test fun noVerificationDatesInTheData() {
        val all = dir.listFiles { f -> f.name.endsWith(".json") && f.name != "manifest.json" }!!.map { CityLoader.decode(it.readText()) }
        assertTrue(all.size > 40)
        for (z in all.flatMap { it.zones }) {
            assertNull(z.source.verifiedOn, z.id)
            assertEquals(DataTrust.UNVERIFIED, engine.trust(z), z.id)
        }
    }

    @Test fun unverifiedYesIsUnsure() {
        val a = zoneA().with(null)
        assertTrue(engine.answer(a, car, emptyList(), false, night).verdict is Verdict.Yes, "la regola: ZTL spenta")
        val shown = engine.trustedAnswer(a, car, emptyList(), false, night)
        assertTrue(shown.verdict is Verdict.Unsure)
        assertTrue(shown.verdict.detail.startsWith(L("This rule hasn't been verified yet: check the sign.")))
        assertEquals(false, shown.gatesOn)
        assertEquals(AnswerColor.YELLOW, PlaceCheck.zoneColor(shown, a, City.Status.DRAFT))
        // Un «no» non verificato resta «no»
        assertTrue(engine.trustedAnswer(a, car, emptyList(), false, day).verdict is Verdict.No)
    }

    @Test fun verificationAge() {
        assertEquals(DataTrust.VERIFIED, engine.trust(zoneA().with("2026-07-10T12:00:00Z")))      // 116 giorni
        assertEquals(DataTrust.OLD, engine.trust(zoneA().with("2026-06-30T12:00:00Z")))           // 126 giorni
        val old = engine.trustedAnswer(zoneA().with("2026-06-30T12:00:00+02:00"), car, emptyList(), false, night)
        assertTrue(old.verdict is Verdict.Unsure && old.verdict.detail.startsWith(F("Last verified more than %lld days ago: check the sign.", 120L)))
        val fresh = engine.trustedAnswer(zoneA().with("2026-10-30T12:00:00Z"), car, emptyList(), false, night)
        assertTrue(fresh.verdict is Verdict.Yes)
        assertEquals(AnswerColor.GREY, PlaceCheck.zoneColor(fresh, zoneA(), City.Status.DRAFT))
    }

    /** Pagina del Comune cambiata dopo la verifica: anche il «no» diventa giallo «?» */
    @Test fun changedPageMakesEverythingUnsure() {
        val a = zoneA().with("2026-10-30T12:00:00Z", pageChanged = true)
        assertEquals(DataTrust.PAGE_CHANGED, engine.trust(a))
        for (t in listOf(day, night)) {
            val v = engine.trustedAnswer(a, car, emptyList(), false, t).verdict
            assertTrue(v is Verdict.Unsure && v.detail.startsWith(L("The city's page has changed: check the sign.")), "$t: $v")
        }
    }

    /** Le zone da fonti non ufficiali restano come prima: il «sì» lo fa giallo Verdict.shown, il «no» resta «no» */
    @Test fun unofficialUnchanged() {
        val s = city("salerno").zones.first()
        val raw = engine.answer(s, car, emptyList(), false, night)
        assertEquals(raw, engine.trustedAnswer(s, car, emptyList(), false, night))
    }
}
