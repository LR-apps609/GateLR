package app.gatelr

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import app.gatelr.core.Coordinate
import app.gatelr.core.Place
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.double
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale

/** I navigatori del telefono. Senza servizi Google (Huawei, Honor) restano Petal Maps e le altre app «geo:». */
enum class Navigator(val id: String, val label: String, val pkg: String?) {
    GOOGLE("google", "Google Maps", "com.google.android.apps.maps"),
    WAZE("waze", "Waze", "com.waze"),
    PETAL("petal", "Petal Maps", "com.huawei.maps.app"),
    OTHER("other", "Altra app di mappe", null);

    fun installed(ctx: Context): Boolean = pkg == null || ctx.packageManager.getLaunchIntentForPackage(pkg) != null

    fun open(ctx: Context, p: Place) {
        val c = p.location
        val intent = when (this) {
            GOOGLE -> Intent(Intent.ACTION_VIEW, Uri.parse("google.navigation:q=${c.lat},${c.lon}")).setPackage(pkg)
            WAZE -> Intent(Intent.ACTION_VIEW, Uri.parse("https://waze.com/ul?ll=${c.lat},${c.lon}&navigate=yes"))
            PETAL -> Intent(Intent.ACTION_VIEW, Uri.parse("geo:${c.lat},${c.lon}?q=${c.lat},${c.lon}")).setPackage(pkg)
            OTHER -> Intent(Intent.ACTION_VIEW, Uri.parse("geo:${c.lat},${c.lon}?q=${c.lat},${c.lon}(${Uri.encode(p.name)})"))
        }.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try { ctx.startActivity(intent) } catch (_: ActivityNotFoundException) {
            ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://www.openstreetmap.org/?mlat=${c.lat}&mlon=${c.lon}#map=17/${c.lat}/${c.lon}")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
    }

    companion object {
        fun available(ctx: Context) = entries.filter { it.installed(ctx) }
        fun preferred(ctx: Context): Navigator =
            entries.firstOrNull { it.id == AppState.preferredNavigator && it.installed(ctx) } ?: available(ctx).first()
    }
}

/** Ricerca dei posti con Photon (dati OpenStreetMap): funziona su tutti i telefoni, anche senza Google */
object Geocoder {
    private val json = Json { ignoreUnknownKeys = true }

    suspend fun search(q: String, near: Coordinate?): List<Place> = withContext(Dispatchers.IO) {
        if (q.isBlank()) return@withContext emptyList()
        val lang = when (Locale.getDefault().language) { "it", "de", "fr" -> Locale.getDefault().language; else -> "en" }
        val bias = near?.let { "&lat=${it.lat}&lon=${it.lon}" } ?: "&lat=43.77&lon=11.25"
        val url = URL("https://photon.komoot.io/api/?q=${URLEncoder.encode(q, "UTF-8")}&limit=8&lang=$lang$bias")
        runCatching {
            val c = url.openConnection() as HttpURLConnection
            c.connectTimeout = 8000; c.readTimeout = 8000
            c.setRequestProperty("User-Agent", "GateLR-Android/0.1")
            val text = c.inputStream.bufferedReader().use { it.readText() }
            json.parseToJsonElement(text).jsonObject["features"]!!.jsonArray.mapNotNull { f ->
                val o = f.jsonObject
                val xy = o["geometry"]!!.jsonObject["coordinates"]!!.jsonArray
                val pr = o["properties"]!!.jsonObject
                fun s(k: String) = pr[k]?.jsonPrimitive?.content
                val name = s("name") ?: listOfNotNull(s("street"), s("housenumber")).joinToString(" ").ifBlank { null } ?: return@mapNotNull null
                val address = listOfNotNull(s("street")?.let { st -> listOfNotNull(st, s("housenumber")).joinToString(" ") }, s("city"))
                    .filter { it != name }.joinToString(", ")
                Place(name, address, Coordinate(xy[1].jsonPrimitive.double, xy[0].jsonPrimitive.double))
            }
        }.getOrDefault(emptyList())
    }
}

/** Il messaggio per l'hotel, nella lingua scelta (lo stesso testo dell'app iPhone) */
object HotelMessage {
    fun text(lang: String, arrival: ZonedDateTime, plate: String, hotel: String?, departure: ZonedDateTime?): String {
        val loc = Locale.forLanguageTag(lang)
        val dayF = DateTimeFormatter.ofPattern("EEEE d MMMM", loc)
        val day = arrival.format(dayF)
        val time = arrival.format(DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT).withLocale(loc))
        val until = departure?.format(dayF)
        return when (lang) {
            "it" -> {
                val to = hotel?.let { "Gentile staff di $it,\n\n" } ?: "Buongiorno,\n\n"
                val span = until?.let { " Riparto $it: vi chiedo di registrarla per tutti i giorni, compreso quello di partenza, e di confermarmelo per iscritto." } ?: " Vi chiedo di confermarmelo per iscritto."
                "${to}arrivo in auto $day verso le $time. Potete registrare la mia targa $plate per la ZTL, così raggiungo l'hotel senza multa?$span\n\nGrazie!"
            }
            "de" -> {
                val to = hotel?.let { "Liebes Team von $it,\n\n" } ?: "Guten Tag,\n\n"
                val span = until?.let { " Ich reise am $it ab. Bitte melden Sie es für jeden Tag an, auch für den Abreisetag, und bestätigen Sie es mir schriftlich." } ?: " Bitte bestätigen Sie es mir schriftlich."
                "${to}ich komme am $day gegen $time mit dem Auto an. Könnten Sie bitte mein Kennzeichen $plate für die ZTL anmelden, damit ich das Hotel ohne Bußgeld erreiche?$span\n\nVielen Dank!"
            }
            else -> {
                val to = hotel?.let { "Dear $it team,\n\n" } ?: "Hello,\n\n"
                val span = until?.let { " I'll leave on $it. Please register it for every day, including the day I leave, and confirm in writing that it's done." } ?: " Please confirm in writing that it's done."
                "${to}I'm arriving by car on $day at about $time. Could you please register my plate $plate for the ZTL, so I can reach the hotel without a fine?$span\n\nThank you!"
            }
        }
    }

    fun share(ctx: Context, text: String) {
        val send = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, text)
        ctx.startActivity(Intent.createChooser(send, null).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }
}

val ROME: ZoneId = app.gatelr.core.RuleEngine.ROME
