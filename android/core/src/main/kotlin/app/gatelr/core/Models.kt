package app.gatelr.core

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.time.Instant

// I dati di GateLR: gli stessi file JSON delle città dell'app iPhone (Resources/Cities).

@Serializable
data class Coordinate(val lat: Double, val lon: Double)

@Serializable
data class City(
    val id: String,
    val name: String,
    @SerialName("name_it") val nameIt: String? = null,
    @SerialName("name_de") val nameDe: String? = null,
    val center: Coordinate,
    val zones: List<Zone>,
    val status: Status,
    val license: String? = null,
    val pedestrian: List<PedestrianArea>? = null,
    val cameras: List<Camera>? = null,
    /** Feste del patrono che valgono come festivi, "MM-DD" (es. Roma "06-29") */
    val localHolidays: List<String>? = null,
) {
    @Serializable
    enum class Status { @SerialName("sample") SAMPLE, @SerialName("draft") DRAFT, @SerialName("verified") VERIFIED }

    val localizedName: String get() = pick(name, nameIt, nameDe)
}

@Serializable
enum class ZoneKind {
    @SerialName("restricted") RESTRICTED, @SerialName("pass") PASS, @SerialName("green") GREEN;

    val title: String get() = when (this) {
        RESTRICTED -> L("No entry")
        PASS -> L("Pass needed")
        GREEN -> L("Green zone")
    }
}

@Serializable
data class Zone(
    val id: String,
    val name: String,
    @SerialName("name_it") val nameIt: String? = null,
    @SerialName("name_de") val nameDe: String? = null,
    val kind: ZoneKind? = null,
    val summary: String,
    @SerialName("summary_it") val summaryIt: String? = null,
    @SerialName("summary_de") val summaryDe: String? = null,
    val perimeter: List<Coordinate>,
    val gates: List<Gate>,
    val windows: List<TimeWindow>,
    val freeOnHolidays: Boolean? = null,
    val exemptFuels: Set<Fuel> = emptySet(),
    val hotelCanRegister: Boolean,
    val ticket: Ticket? = null,
    val bans: List<EuroBan>? = null,
    val source: Source,
    /** Le feste del patrono della città ("MM-DD"): copiate dalla città quando si legge il file (CityLoader) */
    val localHolidays: List<String>? = null,
) {
    val localizedName: String get() = pick(name, nameIt, nameDe)
    val localizedSummary: String get() = pick(summary, summaryIt, summaryDe)
    val type: ZoneKind get() = kind ?: if (ticket != null) ZoneKind.PASS else ZoneKind.RESTRICTED

    /** «B» da «Sector B · Historic Centre» */
    val letter: String get() = name.split("·").first().trim().split(" ").last()
    /** «Settore B», «Area C», «Zona T» */
    val shortName: String get() = localizedName.split("·").first().trim()

    fun contains(lat: Double, lon: Double): Boolean = Geometry.inside(perimeter, lat, lon)

    /** Area approssimata: serve a scegliere la zona più piccola quando sono una dentro l'altra */
    val roughArea: Double get() {
        var s = 0.0
        var j = perimeter.size - 1
        for (i in perimeter.indices) { s += (perimeter[j].lon + perimeter[i].lon) * (perimeter[j].lat - perimeter[i].lat); j = i }
        return kotlin.math.abs(s / 2)
    }

    /** Distanza approssimata in metri dal perimetro (0 se dentro) */
    fun distance(lat: Double, lon: Double): Double {
        if (contains(lat, lon)) return 0.0
        val k = kotlin.math.cos(lat * Math.PI / 180)
        return perimeter.minOfOrNull { kotlin.math.hypot((it.lat - lat) * 111_000, (it.lon - lon) * 111_000 * k) } ?: Double.POSITIVE_INFINITY
    }

    /** Il divieto per classe Euro che ferma questa auto a quella data, se c'è */
    fun ban(vehicle: Vehicle, at: Instant): EuroBan? {
        val group = vehicle.fuel.banGroup ?: return null
        return bans.orEmpty().filter { it.fuel == group && vehicle.euro <= it.maxEuro && !it.date.isAfter(at) }.maxByOrNull { it.date }
    }

    fun nextBan(vehicle: Vehicle, after: Instant): EuroBan? {
        val group = vehicle.fuel.banGroup ?: return null
        return bans.orEmpty().filter { it.fuel == group && vehicle.euro <= it.maxEuro && it.date.isAfter(after) }.minByOrNull { it.date }
    }

    /** Lasciare l'auto qui è un problema? Zone vietate o a pagamento sì; verdi solo se l'auto è vietata */
    fun closes(vehicle: Vehicle, at: Instant): Boolean = type != ZoneKind.GREEN || ban(vehicle, at) != null
}

@Serializable
data class Gate(val id: String, val name: String, val location: Coordinate)

@Serializable
data class TimeWindow(
    val weekdays: Set<Int>,      // 1 = domenica … 7 = sabato, come sull'iPhone
    val start: Int,              // minuti dalla mezzanotte
    val end: Int,                // se < start, finisce il giorno dopo
    val season: Season? = null,
) {
    @Serializable
    data class Season(val fromMonth: Int, val fromDay: Int, val toMonth: Int, val toDay: Int)
}

@Serializable
data class Ticket(
    val price: Double,
    val howTo: String,
    @SerialName("howTo_it") val howToIt: String? = null,
    @SerialName("howTo_de") val howToDe: String? = null,
    val url: String? = null,
    val deadline: String? = null,
) {
    val localizedHowTo: String get() = pick(howTo, howToIt, howToDe)
}

@Serializable
data class EuroBan(val fuel: Fuel, val maxEuro: Int, val since: String) {
    val date: Instant get() {
        val p = since.split("-").mapNotNull { it.toIntOrNull() }
        if (p.size != 3) return Instant.MAX
        return java.time.LocalDate.of(p[0], p[1], p[2]).atStartOfDay(RuleEngine.ROME).toInstant()
    }
}

@Serializable
data class Source(
    val authority: String,
    val pageURL: String,
    val ordinance: String? = null,
    val ordinanceURL: String? = null,
    val quote: String? = null,
    val quoteTranslation: String? = null,
    @SerialName("quoteTranslation_de") val quoteTranslationDe: String? = null,
    @SerialName("pending_it") val pendingIt: List<String>? = null,
    @SerialName("pending_de") val pendingDe: List<String>? = null,
    val checkedOn: String,
    val reviewedByHuman: Boolean,
    val pending: List<String>,
    val links: List<SourceLink>,
    /** false = regole solo da fonti non ufficiali (come l'iPhone dalla 1.16.2); assente = ufficiale */
    val official: Boolean? = null,
    /** Il sito da cui vengono i dati quando la fonte non è ufficiale */
    val unofficialSource: UnofficialSource? = null,
) {
    val isOfficial: Boolean get() = official ?: true
    val checked: Instant get() = Instant.parse(checkedOn)
    val localizedAuthority: String get() = L(authority)
    val localizedPending: List<String> get() = when (Strings.language) { "it" -> pendingIt ?: pending; "de" -> pendingDe ?: pending; else -> pending }
    val localizedTranslation: String? get() = when (Strings.language) { "it" -> null; "de" -> quoteTranslationDe ?: quoteTranslation; else -> quoteTranslation }
}

@Serializable
data class UnofficialSource(val name: String, val url: String)

@Serializable
data class SourceLink(
    val title: String,
    @SerialName("title_it") val titleIt: String? = null,
    @SerialName("title_de") val titleDe: String? = null,
    val url: String,
) {
    val localizedTitle: String get() = pick(title, titleIt, titleDe)
}

@Serializable
data class PedestrianArea(val id: String, val name: String, val perimeter: List<Coordinate>) {
    fun contains(lat: Double, lon: Double) = Geometry.inside(perimeter, lat, lon)
}

@Serializable
data class Camera(val id: String, val name: String, val location: Coordinate, val kind: Kind) {
    @Serializable
    enum class Kind { @SerialName("bus") BUS, @SerialName("pedestrian") PEDESTRIAN }
}

@Serializable
enum class Fuel {
    @SerialName("petrol") PETROL, @SerialName("diesel") DIESEL, @SerialName("hybrid") HYBRID,
    @SerialName("electric") ELECTRIC, @SerialName("lpg") LPG;

    val label: String get() = when (this) {
        PETROL -> L("Petrol"); DIESEL -> L("Diesel"); HYBRID -> L("Hybrid"); ELECTRIC -> L("Electric"); LPG -> L("LPG / methane")
    }
    /** Per i divieti ambientali ibride, GPL e metano contano come benzina (da confermare città per città) */
    val banGroup: Fuel? get() = when (this) { PETROL, HYBRID, LPG -> PETROL; DIESEL -> DIESEL; ELECTRIC -> null }
}

@Serializable
data class Vehicle(
    val id: String = java.util.UUID.randomUUID().toString(),
    val name: String,
    val model: String = "",
    val fuel: Fuel,
    val euro: Int,
    val plate: String = "",
    val isRental: Boolean = false,
    val make: String? = null,
    val year: Int? = null,
)

@Serializable
data class Permit(
    val id: String = java.util.UUID.randomUUID().toString(),
    val kind: Kind,
    val cityId: String,
    val zoneId: String? = null,
    val vehicleId: String,
    val from: Long,                 // millisecondi
    val to: Long,
    val status: Status,
) {
    @Serializable enum class Kind { @SerialName("hotelRegistration") HOTEL, @SerialName("resident") RESIDENT, @SerialName("disabledBadge") DISABLED, @SerialName("other") OTHER }
    @Serializable enum class Status { @SerialName("waiting") WAITING, @SerialName("confirmed") CONFIRMED }

    fun covers(zone: Zone, vehicle: Vehicle, at: Instant): Boolean =
        vehicleId == vehicle.id && (zoneId == null || zoneId == zone.id) && at.toEpochMilli() in from..to
}

@Serializable
data class Place(val name: String, val address: String = "", val location: Coordinate) {
    val key: String get() = "$name|${Math.round(location.lat * 10_000)}|${Math.round(location.lon * 10_000)}"
}

/** Le città: dai file JSON (nell'app Android stanno negli «assets») */
object CityLoader {
    val json = Json { ignoreUnknownKeys = true; coerceInputValues = true }
    fun decode(text: String): City {
        val city = json.decodeFromString(City.serializer(), text)
        // Il motore riceve solo la zona: le feste del patrono della città le porta lei
        val local = city.localHolidays ?: return city
        return city.copy(zones = city.zones.map { it.copy(localHolidays = local) })
    }
}

/** Il testo nella lingua del telefono, se c'è; altrimenti l'inglese */
fun pick(en: String, it: String?, de: String?): String = when (Strings.language) { "it" -> it ?: en; "de" -> de ?: en; else -> en }
