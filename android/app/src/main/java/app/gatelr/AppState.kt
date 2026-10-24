package app.gatelr

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import app.gatelr.core.Answer
import app.gatelr.core.City
import app.gatelr.core.CityLoader
import app.gatelr.core.Coordinate
import app.gatelr.core.Fuel
import app.gatelr.core.L
import app.gatelr.core.Permit
import app.gatelr.core.Place
import app.gatelr.core.RuleEngine
import app.gatelr.core.Strings
import app.gatelr.core.Vehicle
import app.gatelr.core.Zone
import app.gatelr.core.zonesAt
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.time.Instant
import java.util.Locale

/** Lo stato dell'app: città, garage, posto scelto, impostazioni. Resta sul telefono. */
object AppState {
    lateinit var cities: List<City>
    val engine = RuleEngine()
    private lateinit var prefs: SharedPreferences
    private val json = Json { ignoreUnknownKeys = true }

    var cityId by mutableStateOf("firenze")
    var zoneId by mutableStateOf("firenze-b")
    var place by mutableStateOf<Place?>(null)
    var vehicles by mutableStateOf(listOf<Vehicle>())
    var activeVehicleId by mutableStateOf<String?>(null)
    var permits by mutableStateOf(listOf<Permit>())
    var recent by mutableStateOf(listOf<Place>())
    var preferredNavigator by mutableStateOf("")
    var overlayOn by mutableStateOf(true)

    fun init(ctx: Context) {
        // Lingua: italiano, tedesco o inglese, come il telefono
        val lang = Locale.getDefault().language
        Strings.language = if (lang == "it" || lang == "de") lang else "en"
        if (Strings.language != "en") {
            val text = ctx.assets.open("i18n/strings_${Strings.language}.json").bufferedReader().readText()
            Strings.table = json.parseToJsonElement(text).jsonObject.mapValues { it.value.jsonPrimitive.content }
        }
        cities = (ctx.assets.list("Cities") ?: emptyArray()).filter { it.endsWith(".json") && it != "manifest.json" }
            .mapNotNull { runCatching { CityLoader.decode(ctx.assets.open("Cities/$it").bufferedReader().readText()) }.getOrNull() }
            .sortedBy { it.localizedName }

        prefs = ctx.getSharedPreferences("gatelr", Context.MODE_PRIVATE)
        vehicles = prefs.getString("vehicles", null)?.let { runCatching { json.decodeFromString(ListSerializer(Vehicle.serializer()), it) }.getOrNull() }
            ?: listOf(Vehicle(name = L("Rental car"), model = "Fiat 500", fuel = Fuel.PETROL, euro = 6, isRental = true))
        activeVehicleId = prefs.getString("activeVehicle", null) ?: vehicles.first().id
        permits = prefs.getString("permits", null)?.let { runCatching { json.decodeFromString(ListSerializer(Permit.serializer()), it) }.getOrNull() } ?: emptyList()
        recent = prefs.getString("recent", null)?.let { runCatching { json.decodeFromString(ListSerializer(Place.serializer()), it) }.getOrNull() } ?: emptyList()
        preferredNavigator = prefs.getString("navigator", "") ?: ""
        overlayOn = prefs.getBoolean("overlay", true)
    }

    fun save() {
        prefs.edit()
            .putString("vehicles", json.encodeToString(ListSerializer(Vehicle.serializer()), vehicles))
            .putString("activeVehicle", activeVehicleId)
            .putString("permits", json.encodeToString(ListSerializer(Permit.serializer()), permits))
            .putString("recent", json.encodeToString(ListSerializer(Place.serializer()), recent))
            .putString("navigator", preferredNavigator)
            .putBoolean("overlay", overlayOn)
            .apply()
    }

    val city: City get() = cities.firstOrNull { it.id == cityId } ?: cities.first()
    val zone: Zone get() = city.zones.firstOrNull { it.id == zoneId } ?: city.zones.first()
    val vehicle: Vehicle get() = vehicles.firstOrNull { it.id == activeVehicleId } ?: vehicles.first()

    fun answer(zone: Zone, at: Instant = Instant.now(), hotelInside: Boolean = false): Answer =
        engine.answer(zone, vehicle, permits, hotelInside, at)

    fun selectCity(id: String) {
        cityId = id
        if (city.zones.none { it.id == zoneId }) zoneId = city.zones.first().id
    }

    /** Sceglie il posto: la pagina passa alla sua città e alla zona che lo contiene */
    fun select(p: Place?) {
        place = p
        if (p == null) return
        recent = (listOf(p) + recent.filter { it.key != p.key }).take(6)
        save()
        val hit = zonesAt(cities, p.location).firstOrNull()
        if (hit != null) { cityId = hit.first.id; zoneId = hit.second.id }
        else cities.minByOrNull { (it.center.lat - p.location.lat).let { a -> a * a } + (it.center.lon - p.location.lon).let { b -> b * b } }
            ?.let { selectCity(it.id) }
    }

    fun cityOf(zone: Zone): City? = cities.firstOrNull { c -> c.zones.any { it.id == zone.id } }

    fun near(c: Coordinate) = c
}
