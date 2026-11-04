package app.gatelr.core

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.double
import kotlinx.serialization.json.int
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.io.File
import java.time.OffsetDateTime
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/** 1.20.0 «Motore unico»: gli stessi casi di prova dell'iPhone e del sito (shared/engine-cases.json), sugli stessi file
 *  delle città (anche quelle da fonti non ufficiali). Posto + ora + veicolo → colore, risposta come si mostra, zona che decide */
class SharedEngineCasesTest {
    // 1.20.1: anche zone non verificate, verifiche vecchie e pagine dei Comuni cambiate (RuleEngine.trustedAnswer)
    private val citiesDir = File(System.getProperty("gatelr.cities"))
    private val file = Json.parseToJsonElement(File(citiesDir, "../../shared/engine-cases.json").readText()).jsonObject

    /** Tutte le città del manifest, ufficiali e non */
    private val cities: List<City> by lazy {
        val man = Json.parseToJsonElement(File(citiesDir, "manifest.json").readText()).jsonObject
        (man["cities"]!!.jsonArray + (man["unofficialCities"]?.jsonArray ?: emptyList()))
            .map { CityLoader.decode(File(citiesDir, it.jsonObject["file"]!!.jsonPrimitive.content).readText()) }
    }

    private fun vehicle(j: JsonObject) = Vehicle(
        name = j["name"]?.jsonPrimitive?.contentOrNull ?: "",
        fuel = Fuel.entries.first { it.name.lowercase() == j["fuel"]!!.jsonPrimitive.content },
        euro = j["euro"]!!.jsonPrimitive.int,
        type = j["type"]?.jsonPrimitive?.contentOrNull?.let { t -> VehicleType.entries.first { it.raw == t } },
        motoClass = j["motoClass"]?.jsonPrimitive?.contentOrNull,
        stroke = j["stroke"]?.jsonPrimitive?.intOrNull,
    )

    private fun trustName(t: DataTrust) = when (t) {
        DataTrust.VERIFIED -> "verified"; DataTrust.UNVERIFIED -> "unverified"; DataTrust.OLD -> "old"; DataTrust.PAGE_CHANGED -> "pageChanged"
    }

    private fun name(v: Verdict) = when (v) { is Verdict.Yes -> "yes"; is Verdict.No -> "no"; is Verdict.Conditional -> "conditional"; is Verdict.Unsure -> "unsure" }

    @Test fun sharedEngineCases() {
        assertTrue(cities.size > 40, "le città di Resources/Cities")
        assertTrue(cities.any { it.id == "salerno" } && cities.any { it.id == "cagliari" }, "anche le città da fonti non ufficiali")
        val vehicles = file["vehicles"]!!.jsonObject
        val defaultNow = OffsetDateTime.parse(file["now"]!!.jsonPrimitive.content).toInstant()
        val assume = file["assumeVerifiedOn"]?.jsonPrimitive?.contentOrNull
        val cases = file["cases"]!!.jsonArray.map { it.jsonObject }
        assertTrue(cases.size >= 30)
        val errors = mutableListOf<String>()
        for (c in cases) {
            val id = c["id"]!!.jsonPrimitive.content
            val place = c["place"]!!.jsonObject
            val at = OffsetDateTime.parse(c["at"]!!.jsonPrimitive.content).toInstant()
            val now = c["now"]?.jsonPrimitive?.contentOrNull?.let { OffsetDateTime.parse(it).toInstant() } ?: defaultNow
            val v = vehicle(vehicles[c["vehicle"]!!.jsonPrimitive.content]!!.jsonObject)
            val engine = RuleEngine(now = { now })
            val hotel = c["hotel"]?.jsonPrimitive?.booleanOrNull ?: false
            // 1.20.1: la verifica delle zone come dice il caso (di serie «assumeVerifiedOn»): solo nel test, i file non cambiano
            val src = c["source"]?.jsonObject
            val verifiedOn = if (src != null && "verifiedOn" in src) src["verifiedOn"]!!.jsonPrimitive.contentOrNull else assume
            val pageChanged = src?.get("pageChanged")?.jsonPrimitive?.booleanOrNull
            val cities = cities.map { city -> city.copy(zones = city.zones.map { z ->
                z.copy(source = z.source.copy(verifiedOn = verifiedOn, pageChanged = pageChanged ?: z.source.pageChanged)) }) }
            val p = PlaceCheck.of(cities, Coordinate(place["lat"]!!.jsonPrimitive.double, place["lon"]!!.jsonPrimitive.double), engine, v, emptyList(), hotel, at)
            val expect = c["expect"]!!.jsonObject
            fun check(what: String, want: Any?, got: Any?) { if (want != got) errors += "$id: $what atteso $want, ottenuto $got" }
            check("colore", expect["colour"]!!.jsonPrimitive.content, p.color.name.lowercase())
            expect["verdict"]?.let { check("risposta", it.jsonPrimitive.content, name(p.verdict)) }
            if ("zone" in expect) check("zona che decide", expect["zone"]!!.jsonPrimitive.contentOrNull, p.zone?.id)
            expect["gatesOn"]?.let { check("varchi", it.jsonPrimitive.boolean, p.gatesOn) }
            expect["unofficial"]?.let { check("fonte non ufficiale", it.jsonPrimitive.boolean, p.unofficial) }
            expect["pedestrian"]?.let { check("area pedonale", it.jsonPrimitive.boolean, p.pedestrian != null) }
            // Le regole fisse, qualunque cosa dica il file
            if (!p.covered && p.color != AnswerColor.NEUTRAL) errors += "$id: fuori copertura non neutro"
            if (p.unofficial && p.color == AnswerColor.GREEN) errors += "$id: fonte non ufficiale verde"
            val trust = p.zone?.let { engine.trust(it) }
            expect["trust"]?.let { check("verifica", it.jsonPrimitive.content, trust?.let(::trustName)) }
            // 1.20.1: mai verde né grigio da una zona non verificata, con verifica vecchia o con la pagina del Comune cambiata
            if (p.pedestrian == null && trust != null && trust != DataTrust.VERIFIED && (p.color == AnswerColor.GREEN || p.color == AnswerColor.GREY))
                errors += "$id: zona non sicura verde o grigia"
        }
        assertEquals(emptyList(), errors, errors.joinToString("\n"))
    }
}
