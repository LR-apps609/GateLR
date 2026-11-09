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
        DataTrust.VERIFIED -> "verified"; DataTrust.READ -> "read"; DataTrust.UNVERIFIED -> "unverified"; DataTrust.OLD -> "old"; DataTrust.PAGE_CHANGED -> "pageChanged"
    }

    private fun name(v: Verdict) = when (v) { is Verdict.Yes -> "yes"; is Verdict.No -> "no"; is Verdict.Conditional -> "conditional"; is Verdict.Unsure -> "unsure" }

    @Test fun sharedEngineCases() {
        assertTrue(cities.size > 40, "le città di Resources/Cities")
        assertTrue(cities.any { it.id == "salerno" } && cities.any { it.id == "cagliari" }, "anche le città da fonti non ufficiali")
        val vehicles = file["vehicles"]!!.jsonObject
        val defaultNow = OffsetDateTime.parse(file["now"]!!.jsonPrimitive.content).toInstant()
        val cases = file["cases"]!!.jsonArray.map { it.jsonObject }
        assertTrue(cases.size >= 30)
        val errors = mutableListOf<String>()
        for (c in cases) {
            val id = c["id"]!!.jsonPrimitive.content
            val place = c["place"]!!.jsonObject
            val at = OffsetDateTime.parse(c["at"]!!.jsonPrimitive.content).toInstant()
            val now = c["now"]?.jsonPrimitive?.contentOrNull?.let { OffsetDateTime.parse(it).toInstant() } ?: defaultNow
            // Lo stesso veicolo per la stessa chiave (la conferma dell'hotel vale per un veicolo preciso)
            val byKey = vehicles.mapValues { (_, j) -> vehicle(j.jsonObject) }
            val v = byKey[c["vehicle"]!!.jsonPrimitive.content]!!
            val engine = RuleEngine(now = { now })
            // 2.3 «hotel»: il posto è il tuo hotel; «chiesto» e «confermato» diventano un permesso «registrazione hotel» per ogni
            // zona del posto dove l'hotel può registrare, per il veicolo «veicolo», dalla mezzanotte di «dal» alle 23:59 di «al»
            val h = c["hotel"]?.jsonObject
            val hotel = h != null
            // 1.20.1: «pageChanged» dei file cambia ogni mattina: i casi lo ignorano (false) salvo «source»; «source» può
            // anche dare «verifiedOn» e «checkedOn» a tutte le zone. Solo nel test, i file non cambiano
            val src = c["source"]?.jsonObject
            val pageChanged = src?.get("pageChanged")?.jsonPrimitive?.booleanOrNull ?: false
            val read = src?.get("checkedOn")?.jsonPrimitive?.contentOrNull?.let { OffsetDateTime.parse(it).toInstant().toString() }
            val cities = cities.map { city -> city.copy(zones = city.zones.map { z ->
                z.copy(source = z.source.copy(pageChanged = pageChanged,
                    verifiedOn = if (src != null && "verifiedOn" in src) src["verifiedOn"]!!.jsonPrimitive.contentOrNull else z.source.verifiedOn,
                    checkedOn = read ?: z.source.checkedOn)) }) }
            val coord = Coordinate(place["lat"]!!.jsonPrimitive.double, place["lon"]!!.jsonPrimitive.double)
            val permits = h?.let { hj ->
                val stato = hj["stato"]!!.jsonPrimitive.content
                if (stato == "nonChiesto") return@let emptyList()
                val car = byKey[hj["veicolo"]!!.jsonPrimitive.content]!!
                val from = java.time.LocalDate.parse(hj["dal"]!!.jsonPrimitive.content).atStartOfDay(RuleEngine.ROME).toInstant().toEpochMilli()
                val to = java.time.LocalDate.parse(hj["al"]!!.jsonPrimitive.content).atTime(23, 59).atZone(RuleEngine.ROME).toInstant().toEpochMilli()
                cities.flatMap { city -> city.zones.filter { it.hotelCanRegister && it.contains(coord.lat, coord.lon) }.map { z ->
                    Permit(kind = Permit.Kind.HOTEL, cityId = city.id, zoneId = z.id, vehicleId = car.id, from = from, to = to,
                        status = if (stato == "confermato") Permit.Status.CONFIRMED else Permit.Status.WAITING) } }
            } ?: emptyList()
            val p = PlaceCheck.of(cities, coord, engine, v, permits, hotel, at)
            val expect = c["expect"]!!.jsonObject
            fun check(what: String, want: Any?, got: Any?) { if (want != got) errors += "$id: $what atteso $want, ottenuto $got" }
            check("colore", expect["colour"]!!.jsonPrimitive.content, p.color.name.lowercase())
            expect["verdict"]?.let { check("risposta", it.jsonPrimitive.content, name(p.verdict)) }
            if ("zone" in expect) check("zona che decide", expect["zone"]!!.jsonPrimitive.contentOrNull, p.zone?.id)
            expect["gatesOn"]?.let { check("varchi", it.jsonPrimitive.boolean, p.gatesOn) }
            expect["unofficial"]?.let { check("fonte non ufficiale", it.jsonPrimitive.boolean, p.unofficial) }
            expect["pedestrian"]?.let { check("area pedonale", it.jsonPrimitive.boolean, p.pedestrian != null) }
            // 2.1 (B09): la distanza dal lato della zona più vicina (5 m di tolleranza)
            expect["nearestMeters"]?.let { want ->
                val m = nearestZone(cities, Coordinate(place["lat"]!!.jsonPrimitive.double, place["lon"]!!.jsonPrimitive.double))!!.third
                if (kotlin.math.abs(m - want.jsonPrimitive.double) > 5) errors += "$id: distanza attesa ${want.jsonPrimitive.double}, ottenuta $m"
            }
            // 2.1 «Una risposta, sette stati»: la RispostaFinale del posto (shared/risposta-finale.md)
            val f = p.finale
            if ("stato" in expect) {
                check("stato", expect["stato"]?.jsonPrimitive?.content, f.stato.raw)
                check("motivo", expect["motivo"]?.jsonPrimitive?.content, f.motivo?.raw)
            }
            // 2.3: la riga dell'hotel (assente = nessuna)
            check("hotel", expect["hotel"]?.jsonPrimitive?.content, f.hotel?.raw)
            if (f.color == Tono.VERDE && (!p.covered || p.unofficial)) errors += "$id: ${f.stato.raw} verde dove non sappiamo"
            // Le regole fisse, qualunque cosa dica il file
            if (!p.covered && p.color != AnswerColor.NEUTRAL) errors += "$id: fuori copertura non neutro"
            // 1.20.4: fuori dalla ZTL in una città che conosciamo è grigio, mai verde
            if (p.kind == PlaceCheck.Kind.OUTSIDE && !p.unofficial && p.color != AnswerColor.GREY) errors += "$id: fuori dalla ZTL non grigio"
            if (p.unofficial && p.color == AnswerColor.GREEN) errors += "$id: fonte non ufficiale verde"
            val trust = p.zone?.let { engine.trust(it) }
            expect["trust"]?.let { check("verifica", it.jsonPrimitive.content, trust?.let(::trustName)) }
            // 1.20.1 (regola A): mai verde da una zona senza verifica né lettura recente o con la pagina del Comune cambiata
            if (p.pedestrian == null && trust != null && trust != DataTrust.VERIFIED && trust != DataTrust.READ && p.color == AnswerColor.GREEN)
                errors += "$id: zona non sicura verde"
        }
        // 2.1: gli stessi stati, motivi e colori semantici del file
        // (Android 2.0: si controllano quando il file li ha; arrivano con la specifica 2.1 in shared/)
        file["stati"]?.let { s -> assertEquals(s.jsonArray.map { it.jsonPrimitive.content }, Stato.entries.map { it.raw }, "stati") }
        file["motivi"]?.let { m -> assertEquals(m.jsonArray.map { it.jsonPrimitive.content }, Motivo.entries.map { it.raw }, "motivi") }
        file["toni"]?.let { t -> for ((k, v) in t.jsonObject) assertEquals(v.jsonPrimitive.content, Stato.entries.first { it.raw == k }.tono.raw, "tono di $k") }
        file["statoSpento"]?.let { assertEquals(it.jsonPrimitive.content, RispostaFinale.STATE_OFF.raw, "ZTL non attiva: un solo token") }
        assertEquals(emptyList(), errors, errors.joinToString("\n"))
    }
}
