package app.gatelr.core

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.double
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.io.File
import java.time.OffsetDateTime
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/** 2.0.2 «Fiducia»: gli stessi casi dell'iPhone e del sito (shared/fiducia-cases.json): la data dell'ultimo controllo,
 *  «Non ancora verificata a mano» e il link per l'hotel o il noleggio */
class FiduciaTest {
    private val citiesDir = File(System.getProperty("gatelr.cities"))
    private val file = Json.parseToJsonElement(File(citiesDir, "../../shared/fiducia-cases.json").readText()).jsonObject
    private val app = File(System.getProperty("gatelr.app"))

    private fun source(j: JsonObject) = Source(
        authority = "City of Florence", pageURL = "https://www.comune.fi.it/",
        checkedOn = j["checkedOn"]!!.jsonPrimitive.content,
        verifiedOn = j["verifiedOn"]?.jsonPrimitive?.contentOrNull,
        reviewedByHuman = j["reviewedByHuman"]!!.jsonPrimitive.boolean,
        pageChanged = j["pageChanged"]?.jsonPrimitive?.booleanOrNull,
        pending = emptyList(), links = emptyList(),
    )

    @Test fun controlCases() {
        val cases = file["control"]!!.jsonArray
        assertTrue(cases.size >= 8)
        for (c in cases.map { it.jsonObject }) {
            val id = c["id"]!!.jsonPrimitive.content
            val now = OffsetDateTime.parse(c["now"]!!.jsonPrimitive.content).toInstant()
            val got = Fiducia.control(source(c["source"]!!.jsonObject), now)
            val e = c["expect"]!!.jsonObject
            assertEquals(e["when"]!!.jsonPrimitive.content, got.whenDay.name.lowercase(), id)
            assertEquals(e["label"]!!.jsonPrimitive.content, got.label, id)
            assertEquals(e["fresh"]!!.jsonPrimitive.boolean, got.fresh, id)
            assertEquals(e["byHand"]!!.jsonPrimitive.boolean, got.byHand, id)
        }
    }

    @Test fun shareCases() {
        assertEquals(file["site"]!!.jsonPrimitive.content, Fiducia.SITE)
        assertEquals(file["siteVehicles"]!!.jsonArray.map { it.jsonPrimitive.content }, Fiducia.SITE_VEHICLES)
        for (c in file["share"]!!.jsonArray.map { it.jsonObject }) {
            val id = c["id"]!!.jsonPrimitive.content
            val v = c["vehicle"]!!.jsonObject
            val key = Fiducia.vehicleKey(v["fuel"]!!.jsonPrimitive.content, v["euro"]!!.jsonPrimitive.int,
                v["type"]?.jsonPrimitive?.contentOrNull == "motorcycle", v["unknown"]?.jsonPrimitive?.booleanOrNull == true)
            val p = c["place"]?.takeIf { it != JsonNull }?.jsonObject
            val url = Fiducia.shareURL(c["lang"]!!.jsonPrimitive.content, c["city"]!!.jsonPrimitive.content,
                p?.get("name")?.jsonPrimitive?.content, p?.get("lat")?.jsonPrimitive?.double, p?.get("lon")?.jsonPrimitive?.double, key)
            assertEquals(c["expect"]!!.jsonPrimitive.content, url, id)
        }
    }

    /** Il testo condiviso ha il link e dice che non serve installare nulla; mai la targa */
    @Test fun shareTextSaysNoInstall() {
        val t = Fiducia.shareText("Hotel Brunelleschi", "https://lr-apps609.github.io/GateLR/it/#p=1")
        assertTrue(t.endsWith("\nhttps://lr-apps609.github.io/GateLR/it/#p=1"))
        assertTrue("nothing to install" in t)
        assertTrue("Hotel Brunelleschi" in t)
    }

    /** Il colore della risposta non dipende dalla verifica a mano: la stessa zona, verificata o no, stessa risposta */
    @Test fun byHandDoesNotChangeTheColour() {
        val src = source(Json.parseToJsonElement("""{"checkedOn":"2026-10-23T12:00:00Z","reviewedByHuman":false}""").jsonObject)
        val now = OffsetDateTime.parse("2026-11-12T10:00:00+01:00").toInstant()
        val e = RuleEngine(now = { now })
        assertEquals(e.trust(src), e.trust(src.copy(reviewedByHuman = true)))
    }

    /** Android alla pari: la riga, il pulsante e le due pagine ci sono su Adesso, Viaggio e nella scheda della zona */
    @Test fun androidShowsTheTrustRow() {
        val src = File(app, "java/app/gatelr")
        val box = File(src, "Fiducia.kt").readText()
        for (k in listOf("Send it to your hotel / rental", "Opens in the browser, nothing to install", "Not yet verified by hand",
                "Source: %@", "How we check the data", "What to do if you get a fine", "Intent.ACTION_SEND"))
            assertTrue(k in box, "manca $k in Fiducia.kt")
        assertFalse("Palette.red" in box || "Tono." in box, "la riga non usa i colori della risposta")
        for (f in listOf("HomeScreen.kt", "TripScreen.kt", "ZoneDetail.kt"))
            assertTrue("TrustBox(" in File(src, f).readText(), "manca la riga della fiducia in $f")
        val help = File(src, "HelpScreen.kt").readText()
        assertTrue("\"checks\"" in help && "\"finehelp\"" in help, "le due pagine da Aiuto")
    }

    /** I testi nuovi in tutte le lingue di Android */
    @Test fun stringsInEveryLanguage() {
        val dir = File(System.getProperty("gatelr.i18n"))
        for (f in dir.listFiles()!!.filter { it.name.startsWith("strings_") }) {
            val t = Json.parseToJsonElement(f.readText()).jsonObject
            for (k in listOf("Last checked today", "Last checked yesterday", "Last checked %@", "Not yet verified by hand",
                    "Send it to your hotel / rental", "How we check the data", "What to do if you get a fine",
                    "I'm arriving by car: %@. Here GateLR shows if a car can enter the ZTL. It opens in the browser, nothing to install:"))
                assertTrue(t[k]?.jsonPrimitive?.content?.isNotBlank() == true, "${f.name}: manca $k")
        }
    }
}
