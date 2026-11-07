package app.gatelr.core

import java.io.File
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/** 1.20.3 «Parole»: una sola forma della risposta per lingua (come l'iPhone), dati delle città in italiano + inglese,
 *  pillole neutre, Android nelle 8 lingue dell'iPhone */
class ParoleTest {
    private val dir = File(System.getProperty("gatelr.cities"))
    private val i18n = File(System.getProperty("gatelr.i18n"))
    private fun city(id: String) = CityLoader.decode(File(dir, "$id.json").readText())
    private fun table(lang: String): Map<String, String> =
        Json.parseToJsonElement(File(i18n, "strings_$lang.json").readText()).jsonObject.mapValues { it.value.jsonPrimitive.content }

    @AfterTest fun english() { Strings.language = "en"; Strings.table = emptyMap() }

    private fun a(v: Verdict, on: Boolean = true) = Answer(v, on, null)
    private val yes = Verdict.Yes("r"); private val no = Verdict.No("r")
    private val cond = Verdict.Conditional("r", "Solo con il ticket."); private val unsure = Verdict.Unsure("Festivo da confermare.")

    @Test fun fixedTitlePerEngineState() {
        assertEquals(AnswerWord.DONT_ENTER, no.word(false)); assertEquals(AnswerWord.DONT_ENTER, no.word(true))
        assertEquals(AnswerWord.ENTER, yes.word(false)); assertEquals(AnswerWord.CHECK_SIGN, yes.word(true))
        assertEquals(AnswerWord.CONDITION, cond.word(false)); assertEquals(AnswerWord.CHECK_SIGN, unsure.word(false))
        for (v in listOf(yes, no, cond, unsure)) { assertEquals(v.word(false).title, v.title); assertEquals(v.title, v.short) }
        // Le stesse chiavi dell'iPhone (AnswerWord in Sources/RuleEngine.swift)
        assertEquals(listOf("Don't enter", "You can enter", "On one condition", "Check the sign", "We don't know this place"), AnswerWord.entries.map { it.key })
    }

    @Test fun everyPlaceKindHasAFixedTitle() {
        val firenze = city("firenze"); val zone = firenze.zones.first()
        val unofficial = city("salerno").let { it to it.zones.first() }
        val area = PedestrianArea("p", "Via Prova", zone.perimeter)
        fun pc(hit: Pair<City, Zone>?, ans: Answer?, covered: Boolean = true, ped: PedestrianArea? = null) =
            PlaceCheck(listOfNotNull(hit), ped, listOfNotNull(ans), covered)
        val cases = listOf(
            Triple(pc(null, null, covered = false), Stato.NON_COPERTO, "fuori copertura"),
            Triple(pc(null, null), Stato.FUORI_ZTL, "fuori dalla ZTL"),
            Triple(pc(firenze to zone, a(yes)), Stato.ENTRA_PURE, "sì"),
            Triple(pc(firenze to zone, a(yes, on = false)), Stato.ZTL_NON_ATTIVA, "ZTL non attiva"),
            Triple(pc(unofficial, a(yes)), Stato.CONTROLLA_CARTELLO, "sì non ufficiale"),
            Triple(pc(firenze to zone, a(no)), Stato.NON_ENTRARE, "no"),
            Triple(pc(unofficial, a(no)), Stato.NON_ENTRARE, "no non ufficiale"),
            Triple(pc(firenze to zone, a(cond)), Stato.CONDIZIONE, "condizione"),
            Triple(pc(firenze to zone, a(unsure)), Stato.CONTROLLA_CARTELLO, "non sicuro"),
            Triple(pc(null, null, ped = area), Stato.NON_ENTRARE, "area pedonale"),
        )
        // 2.1: sette stati, ognuno con la sua parola (ZTL non attiva e Fuori dalla ZTL hanno la loro)
        for ((check, stato, what) in cases) { assertEquals(stato, check.finale.stato, what); assertEquals(stato.title, check.finale.title, what) }
        assertEquals("Solo con il ticket.", pc(firenze to zone, a(cond)).explanation)
        assertEquals(L("Probably yes · unofficial source"), pc(unofficial, a(yes)).explanation)
        assertEquals(L("Probably not · unofficial source"), pc(unofficial, a(no)).explanation)
        assertNull(pc(firenze to zone, a(yes)).explanation)
    }

    /** Android nelle 8 lingue dell'iPhone: i cinque titoli ci sono, diversi tra loro, e uguali a quelli dell'iPhone */
    @Test fun titlesInEveryLanguage() {
        val iphone = File(dir, "../Localizations")
        for (lang in listOf("it", "de", "fr", "es", "nl", "pl", "zh")) {
            val t = table(lang)
            val titles = AnswerWord.entries.map { assertNotNull(t[it.key], "$lang: manca «${it.key}»") }
            assertEquals(titles.size, titles.toSet().size, "$lang: titoli ripetuti")
            val stati = Stato.entries.map { assertNotNull(t[it.key], "$lang: manca «${it.key}»") }
            assertEquals(stati.size, stati.toSet().size, "$lang: parole dei sette stati ripetute")
            for (w in Stato.entries) {
                val lines = assertNotNull(t[w.lineKey], "$lang: manca «${w.lineKey}»")
                assertEquals(t[w.key]!!.replace(" ", ""), lines.replace("|", "").replace(" ", ""), "$lang: «$lines»")
            }
            for (w in AnswerWord.entries) {
                val lines = assertNotNull(t[w.lineKey], "$lang: manca «${w.lineKey}»")
                assertEquals(t[w.key]!!.replace(" ", ""), lines.replace("|", "").replace(" ", ""), "$lang: «$lines»")
            }
            val lproj = File(iphone, (if (lang == "zh") "zh-Hans" else lang) + ".lproj/Localizable.strings").readText()
            for (w in AnswerWord.entries) assertTrue(lproj.contains("\"${w.key.replace("\"", "\\\"")}\" = \"${t[w.key]}\";"), "$lang: «${w.key}» diverso dall'iPhone")
            // Le parole delle schede come l'iPhone: «Varco», «Tu»
            assertNotNull(t["Gate"]); assertNotNull(t["You"])
        }
        assertEquals("Non entrare", table("it")["Don't enter"]); assertEquals("Puoi entrare", table("it")["You can enter"])
        assertEquals("A una condizione", table("it")["On one condition"]); assertEquals("Controlla il cartello", table("it")["Check the sign"])
        assertEquals("Varco", table("it")["Gate"]); assertEquals("Tu", table("it")["You"])
    }

    /** 10. Le lingue lunghe (tedesco, polacco): i titoli stanno in una pillola corta (al massimo 24 caratteri) */
    @Test fun longLanguagesStayShort() {
        for (lang in listOf("de", "pl")) {
            val t = table(lang)
            for (w in AnswerWord.entries) assertTrue(t[w.key]!!.length <= 24, "$lang: «${t[w.key]}» troppo lungo per una pillola")
            for (k in listOf("ZTL with pass", "Green zone")) assertTrue(t[k]!!.length <= 18, "$lang: «${t[k]}»")
        }
    }

    @Test fun zoneKindPillsAreNeutral() {
        assertEquals("ZTL", ZoneKind.RESTRICTED.title)
        assertEquals(L("ZTL with pass"), ZoneKind.PASS.title)
        assertEquals(L("Green zone"), ZoneKind.GREEN.title)
        Strings.language = "it"; Strings.table = table("it")
        assertEquals(listOf("ZTL", "ZTL con pass", "Zona verde"), ZoneKind.entries.map { it.title })
        assertFalse(ZoneKind.entries.any { it.title == "Accesso vietato" || it.title == "Pass necessario" })
    }

    @Test fun cityDataFallsBackToItalianAndEnglish() {
        val en = "Sector A · Historic Centre"; val it = "Settore A · Centro storico"; val de = "Sektor A · Altstadt"
        assertEquals(en, pick(en, it, de, language = "en"))
        assertEquals(it, pick(en, it, de, language = "it"))
        assertEquals(de, pick(en, it, de, language = "de"))
        for (lang in listOf("fr", "es", "nl", "pl", "zh")) {
            assertEquals("Settore A · Centro storico (Sector A · Historic Centre)", pick(en, it, de, language = lang))
            assertEquals("Si compra online.\n\nBuy it online.", pick("Buy it online.", "Si compra online.", null, long = true, language = lang))
            assertEquals("Florence", pick("Florence", "Firenze", "Florenz", italianFallback = false, language = lang))
            assertEquals(en, pick(en, null, null, language = lang))
            assertEquals(listOf("Orari\nHours"), pickList(listOf("Hours"), listOf("Orari"), null, language = lang))
        }
        // Con i dati veri: in francese il riassunto di Firenze ha l'italiano e l'inglese; il nome breve resta «Settore A»
        val z = city("firenze").zones.first { it.letter == "A" }
        Strings.language = "fr"
        assertTrue(z.localizedSummary.startsWith(z.summaryIt!!) && z.localizedSummary.endsWith(z.summary))
        assertEquals("Settore A", z.shortName)
        assertTrue(z.localizedName.contains(z.nameIt!!) && z.localizedName.contains(z.name))
    }
}
