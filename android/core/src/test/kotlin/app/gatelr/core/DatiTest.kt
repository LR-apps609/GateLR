package app.gatelr.core

import java.io.File
import java.time.LocalDateTime
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** 1.20.1 «Dati»: «letto il» e «verificato il»; regola A; pagina cambiata = giallo; ZTL spenta = verde */
class DatiTest {
    private val dir = File(System.getProperty("gatelr.cities"))
    private fun city(id: String) = CityLoader.decode(File(dir, "$id.json").readText())
    private fun date(y: Int, m: Int, d: Int, h: Int) = LocalDateTime.of(y, m, d, h, 0).atZone(RuleEngine.ROME).toInstant()
    private fun iso(y: Int, m: Int, d: Int) = date(y, m, d, 12).toString()
    private val car = Vehicle(id = "car", name = "Rental car", fuel = Fuel.PETROL, euro = 6)
    private val engine = RuleEngine(now = { date(2026, 11, 3, 12) })
    private val night = date(2026, 11, 10, 23)      // Settore A spento
    private val day = date(2026, 11, 10, 10)        // Settore A acceso
    private fun zoneA(read: String = iso(2026, 10, 23), verified: String? = null, changed: Boolean? = null) =
        city("firenze").zones.first { it.id == "firenze-a" }.let { it.copy(source = it.source.copy(checkedOn = read, verifiedOn = verified, pageChanged = changed)) }

    /** Nei file nessuna zona ha una data di verifica (non si inventa); tutte hanno le impronte della lettura */
    @Test fun noVerificationDatesInTheData() {
        val all = dir.listFiles { f -> f.name.endsWith(".json") && f.name != "manifest.json" }!!.map { CityLoader.decode(it.readText()) }
        assertTrue(all.size > 40)
        for (z in all.flatMap { it.zones }) {
            assertNull(z.source.verifiedOn, z.id)
            assertNotNull(z.source.readFingerprints, z.id)
        }
    }

    /** Regola A: letta da poco, non verificata, pagina non cambiata: la risposta normale; ZTL spenta verde */
    @Test fun recentlyReadIsNormal() {
        val a = zoneA()
        assertEquals(DataTrust.READ, engine.trust(a))
        val off = engine.trustedAnswer(a, car, emptyList(), false, night)
        assertTrue(off.verdict is Verdict.Yes)
        assertEquals(AnswerColor.GREEN, PlaceCheck.zoneColor(off, a, City.Status.DRAFT))
        assertTrue(engine.trustedAnswer(a, car, emptyList(), false, day).verdict is Verdict.No)
    }

    @Test fun oldReadIsUnsure() {
        val a = zoneA(read = iso(2026, 6, 1))
        assertEquals(DataTrust.UNVERIFIED, engine.trust(a))
        for (t in listOf(day, night)) assertTrue(engine.trustedAnswer(a, car, emptyList(), false, t).verdict is Verdict.Unsure)
    }

    @Test fun verificationAge() {
        assertEquals(DataTrust.VERIFIED, engine.trust(zoneA(read = iso(2026, 5, 1), verified = iso(2026, 7, 10))))   // 116 giorni
        assertEquals(DataTrust.OLD, engine.trust(zoneA(read = iso(2026, 5, 1), verified = iso(2026, 6, 30))))        // 126 giorni
        assertTrue(engine.trustedAnswer(zoneA(read = iso(2026, 5, 1), verified = iso(2026, 6, 30)), car, emptyList(), false, night).verdict is Verdict.Unsure)
        // Verifica vecchia ma lettura recente: la regola A sulla lettura
        assertEquals(DataTrust.READ, engine.trust(zoneA(verified = iso(2026, 6, 30))))
        assertTrue(engine.trustedAnswer(zoneA(read = iso(2026, 5, 1), verified = iso(2026, 10, 30)), car, emptyList(), false, night).verdict is Verdict.Yes)
    }

    /** Pagina del Comune cambiata dopo la lettura o la verifica: anche il «no» diventa giallo «?» */
    @Test fun changedPageMakesEverythingUnsure() {
        val a = zoneA(changed = true)
        assertEquals(DataTrust.PAGE_CHANGED, engine.trust(a))
        for (t in listOf(day, night)) {
            val v = engine.trustedAnswer(a, car, emptyList(), false, t).verdict
            assertTrue(v is Verdict.Unsure && v.detail.startsWith(L("The city's page has changed: check the sign.")), "$t: $v")
        }
    }

    /** Le zone da fonti non ufficiali restano come prima: il «sì» lo fa giallo Verdict.shown, il «no» resta «no» */
    @Test fun unofficialUnchanged() {
        val s = city("salerno").zones.first().let { it.copy(source = it.source.copy(pageChanged = null)) }
        assertEquals(engine.answer(s, car, emptyList(), false, night), engine.trustedAnswer(s, car, emptyList(), false, night))
    }
}
