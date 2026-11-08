package app.gatelr

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import app.gatelr.core.Answer
import app.gatelr.core.City
import app.gatelr.core.CityFromPosition
import app.gatelr.core.CityFromPositionGate
import app.gatelr.core.CityLoader
import app.gatelr.core.Lingua
import app.gatelr.core.Coordinate
import app.gatelr.core.Fuel
import app.gatelr.core.L
import app.gatelr.core.Permit
import app.gatelr.core.Place
import app.gatelr.core.PlaceCheck
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

/** Una riga del diario dei passaggi (solo sul telefono) */
@kotlinx.serialization.Serializable
data class LogEntry(val date: Long, val kind: String, val zoneId: String, val zoneName: String, val verdict: String, val plate: String)

/** Un viaggio salvato: il posto e l'ora d'arrivo */
@kotlinx.serialization.Serializable
data class SavedTrip(val id: String = java.util.UUID.randomUUID().toString(), val place: Place, val arrival: Long)

/** Lo stato dell'app: città, garage, posto scelto, impostazioni. Resta sul telefono. */
/** Le lingue dei testi (assets/i18n/strings_<lingua>.json), le stesse dell'iPhone */
val SUPPORTED_LANGUAGES = listOf("en", "it", "de", "fr", "es", "nl", "pl", "zh")

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
    var log by mutableStateOf(listOf<LogEntry>())
    var trips by mutableStateOf(listOf<SavedTrip>())
    var tripAt by mutableStateOf<Long?>(null)         // ora d'arrivo del viaggio salvato aperto

    fun init(ctx: Context) {
        // Lingua come il telefono: le 8 dell'iPhone (1.20.3: anche francese, spagnolo, olandese, polacco e cinese, dalla
        // stessa fonte Tools/translations.py); le altre in inglese
        loadStrings(ctx)
        cities = (ctx.assets.list("Cities") ?: emptyArray()).filter { it.endsWith(".json") && it != "manifest.json" }
            .mapNotNull { runCatching { CityLoader.decode(ctx.assets.open("Cities/$it").bufferedReader().readText()) }.getOrNull() }
            // 1.20.0: anche le città con zone da fonti non ufficiali (Salerno, Cagliari…), come sull'iPhone: risposte con
            // l'avviso «Fonte non ufficiale» e mai verdi (Verdict.shown)
            .sortedBy { it.localizedName }

        prefs = ctx.getSharedPreferences("gatelr", Context.MODE_PRIVATE)
        vehicles = prefs.getString("vehicles", null)?.let { runCatching { json.decodeFromString(ListSerializer(Vehicle.serializer()), it) }.getOrNull() }
            ?: listOf(Vehicle(name = L("Rental car"), model = "Fiat 500", fuel = Fuel.PETROL, euro = 6, isRental = true))
        activeVehicleId = prefs.getString("activeVehicle", null) ?: vehicles.first().id
        permits = prefs.getString("permits", null)?.let { runCatching { json.decodeFromString(ListSerializer(Permit.serializer()), it) }.getOrNull() } ?: emptyList()
        recent = prefs.getString("recent", null)?.let { runCatching { json.decodeFromString(ListSerializer(Place.serializer()), it) }.getOrNull() } ?: emptyList()
        preferredNavigator = prefs.getString("navigator", "") ?: ""
        overlayOn = prefs.getBoolean("overlay", true)
        cityId = prefs.getString("city", cityId) ?: cityId
        trips = prefs.getString("trips", null)?.let { runCatching { json.decodeFromString(ListSerializer(SavedTrip.serializer()), it) }.getOrNull() } ?: emptyList()
        log = prefs.getString("log", null)?.let { runCatching { json.decodeFromString(ListSerializer(LogEntry.serializer()), it) }.getOrNull() } ?: emptyList()
        zoneId = prefs.getString("zone", zoneId) ?: zoneId
    }

    /** 2.0.1 (B161): i testi nella lingua dell'app, ricaricati a ogni creazione dell'attività: su Android 13+ la lingua
     *  dell'app si cambia dalle Impostazioni e prima restava quella dell'avvio del processo (interfaccia in due lingue) */
    fun loadStrings(ctx: Context) {
        val locales = ctx.resources.configuration.locales
        val lang = Lingua.pick(if (locales.isEmpty) Locale.getDefault().language else locales[0].language)
        if (lang == Strings.language && (lang == "en" || Strings.table.isNotEmpty())) return
        Strings.table = if (lang == "en") emptyMap() else runCatching {
            json.parseToJsonElement(ctx.assets.open("i18n/strings_$lang.json").bufferedReader().readText()).jsonObject.mapValues { it.value.jsonPrimitive.content }
        }.getOrDefault(emptyMap())
        Strings.language = lang
    }

    fun save() {
        prefs.edit()
            .putString("vehicles", json.encodeToString(ListSerializer(Vehicle.serializer()), vehicles))
            .putString("activeVehicle", activeVehicleId)
            .putString("permits", json.encodeToString(ListSerializer(Permit.serializer()), permits))
            .putString("recent", json.encodeToString(ListSerializer(Place.serializer()), recent))
            .putString("navigator", preferredNavigator)
            .putBoolean("overlay", overlayOn)
            .putString("city", cityId)
            .putString("trips", json.encodeToString(ListSerializer(SavedTrip.serializer()), trips))
            .putString("log", json.encodeToString(ListSerializer(LogEntry.serializer()), log))
            .putString("zone", zoneId)
            .apply()
    }

    val city: City get() = cities.firstOrNull { it.id == cityId } ?: cities.first()
    val zone: Zone get() = city.zones.firstOrNull { it.id == zoneId } ?: city.zones.first()
    val vehicle: Vehicle get() = vehicles.firstOrNull { it.id == activeVehicleId } ?: vehicles.first()

    /** La risposta come si MOSTRA (1.20.0, come l'iPhone): un «sì» da fonte non ufficiale è «non sicuro», giallo con il «?».
     *  La usano elenchi, scheda della zona, percorso, guardiano e widget */
    fun answer(zone: Zone, at: Instant = Instant.now(), hotelInside: Boolean = false): Answer {
        val a = rawAnswer(zone, at, hotelInside)
        return a.copy(verdict = a.verdict.shown(zone.isUnofficial))
    }

    /** La risposta del motore. Un permesso vale solo nella sua città: la registrazione dell'hotel a Firenze non apre l'Area C di Milano.
     *  1.20.1: con la verifica dei dati (RuleEngine.trustedAnswer): regola non verificata, verifica vecchia o pagina del
     *  Comune cambiata = mai verde né grigio */
    fun rawAnswer(zone: Zone, at: Instant = Instant.now(), hotelInside: Boolean = false): Answer {
        val city = cityOf(zone)?.id
        return engine.trustedAnswer(zone, vehicle, permits.filter { it.cityId == city }, hotelInside, at)
    }

    /** 1.20.0: la risposta per un posto come l'iPhone (PlaceCheck): la zona peggiore tra tutte quelle del posto, l'area
     *  pedonale che vince, fuori dalle città che conosciamo neutro */
    fun check(c: Coordinate, at: Instant = Instant.now(), hotelInside: Boolean = false): PlaceCheck =
        PlaceCheck.of(cities, c) { rawAnswer(it, at, hotelInside) }

    /** 1.20.2: la città dalla posizione una volta per apertura e mai dopo una scelta a mano. 2.0.1 (B166): «apertura» è
     *  l'attività creata di nuovo (newOpening da MainActivity.onCreate), non più il processo */
    private val cityGate = CityFromPositionGate()

    fun newOpening() = cityGate.newOpening()

    /** Alla prima posizione di ogni apertura la pagina va sulla città dove sei (CityFromPosition), se non hai già
     *  scelto un posto o una città. Vero se ha cambiato città */
    fun adoptCity(here: Coordinate): Boolean {
        if (!::cities.isInitialized || !cityGate.shouldAdopt()) return false
        if (place != null) return false
        val (c, z) = CityFromPosition.pick(here, cities) ?: return false
        if (c.id == cityId) return false
        cityId = c.id; zoneId = z.id; save()
        return true
    }

    /** La città scelta dal menu */
    fun chooseCity(id: String) { cityGate.choseByHand(); selectCity(id) }

    fun selectCity(id: String) {
        cityId = id
        if (city.zones.none { it.id == zoneId }) zoneId = city.zones.first().id
        save()
    }

    /** Sceglie il posto: la pagina passa alla sua città e alla zona che lo contiene */
    fun open(t: SavedTrip) { select(t.place); tripAt = t.arrival }

    fun select(p: Place?) {
        place = p
        tripAt = null
        if (p == null) return
        recent = (listOf(p) + recent.filter { it.key != p.key }).take(6)
        val hit = zonesAt(cities, p.location).firstOrNull()
        if (hit != null) { cityId = hit.first.id; zoneId = hit.second.id }
        else cities.minByOrNull { (it.center.lat - p.location.lat).let { a -> a * a } + (it.center.lon - p.location.lon).let { b -> b * b } }
            ?.let { selectCity(it.id) }
        save()
    }

    /** Aggiunge al diario, senza doppioni nella stessa mezz'ora per la stessa zona */
    fun record(kind: String, zone: Zone, verdict: app.gatelr.core.Verdict) {
        val now = System.currentTimeMillis()
        if (log.any { it.zoneId == zone.id && it.kind == kind && now - it.date < 30 * 60_000 }) return
        log = (listOf(LogEntry(now, kind, zone.id, zone.localizedName, verdict.short, vehicle.plate)) + log).take(500)
        save()
    }

    fun cityOf(zone: Zone): City? = cities.firstOrNull { c -> c.zones.any { it.id == zone.id } }

    fun near(c: Coordinate) = c
}
