package app.gatelr

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.Navigation
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import kotlinx.coroutines.launch
import app.gatelr.core.RouteCheck
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.gatelr.core.Answer
import app.gatelr.core.F
import app.gatelr.core.Geometry
import app.gatelr.core.L
import app.gatelr.core.Permit
import app.gatelr.core.Place
import app.gatelr.core.Strings
import app.gatelr.core.Ticket
import app.gatelr.core.Verdict
import app.gatelr.core.Zone
import app.gatelr.core.nearestZone
import app.gatelr.core.pedestrianAreaAt
import app.gatelr.core.zonesAt
import kotlinx.coroutines.delay
import java.time.Instant
import java.time.LocalTime
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import java.util.Locale

/** Quando arrivi: adesso, tra un'ora, stasera, domani mattina */
private enum class Arrival(val label: String) { NOW("Now"), HOUR("In 1 hour"), EVENING("This evening"), TOMORROW("Tomorrow morning");
    fun at(now: ZonedDateTime): ZonedDateTime = when (this) {
        NOW -> now; HOUR -> now.plusHours(1)
        EVENING -> now.with(LocalTime.of(20, 0)).let { if (it.isBefore(now)) it.plusDays(1) else it }
        TOMORROW -> now.plusDays(1).with(LocalTime.of(10, 0))
    }
}

@Composable
fun TripScreen(modifier: Modifier) {
    var query by remember { mutableStateOf("") }
    var results by remember { mutableStateOf(listOf<Place>()) }
    var searching by remember { mutableStateOf(false) }
    val place = AppState.place

    LaunchedEffect(query) {
        if (query.length < 3) { results = emptyList(); return@LaunchedEffect }
        delay(350)
        searching = true
        results = Geocoder.search(query, Here.coordinate ?: AppState.city.center)
        searching = false
    }

    LazyColumn(modifier.fillMaxSize().background(MaterialTheme.colorScheme.background), contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            OutlinedTextField(value = query, onValueChange = { query = it }, singleLine = true,
                placeholder = { Text(L("Hotel, address or square")) },
                leadingIcon = { Icon(Icons.Filled.Search, null) },
                trailingIcon = { if (query.isNotEmpty() || place != null) IconButton(onClick = { query = ""; results = emptyList(); AppState.select(null) }) { Icon(Icons.Filled.Close, null) } },
                shape = RoundedCornerShape(14.dp), modifier = Modifier.fillMaxWidth())
        }
        if (results.isNotEmpty()) {
            items(results) { p -> PlaceRow(p) { AppState.select(p); query = ""; results = emptyList() } }
        } else if (query.length >= 3 && !searching) {
            item { Text(L("No results"), color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f)) }
        } else if (place == null) {
            item {
                Column(Modifier.padding(vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(L("Where are you going?"), fontSize = 28.sp, fontWeight = FontWeight.Bold)
                    Text(L("Search your hotel or where you're going: GateLR tells you if you can drive in, when, and how to get the plate registered."),
                        color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.7f))
                }
            }
            if (AppState.recent.isNotEmpty()) {
                item { SectionLabel("Recent") }
                items(AppState.recent, key = { it.key }) { p -> PlaceRow(p, recent = true) { AppState.select(p) } }
            }
        } else {
            item { TripAnswer(place) }
        }
    }
}

@Composable
private fun PlaceRow(p: Place, recent: Boolean = false, onClick: () -> Unit) {
    CardBox(Modifier.clickable(onClick = onClick)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (recent) { Icon(Icons.Filled.History, null, tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)); Spacer(Modifier.width(10.dp)) }
            Column {
                Text(p.name, fontWeight = FontWeight.SemiBold)
                if (p.address.isNotEmpty()) Text(p.address, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f))
            }
        }
    }
}

@Composable
private fun TripAnswer(p: Place) {
    val ctx = LocalContext.current
    var arrival by remember(p.key) { mutableStateOf(Arrival.NOW) }
    val nowZ = ZonedDateTime.now(ROME).also { rememberNow() }
    val at = arrival.at(nowZ)
    val zone = zonesAt(AppState.cities, p.location).minByOrNull { it.second.roughArea }?.second
    val pedestrian = pedestrianAreaAt(AppState.cities, p.location)
    var hotelInside by remember(p.key) { mutableStateOf(false) }
    val answer = zone?.let { AppState.answer(it, at.toInstant(), hotelInside) }

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Column {
            Text(p.name, fontSize = 24.sp, fontWeight = FontWeight.Bold)
            if (p.address.isNotEmpty()) Text(p.address, color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Arrival.entries.forEach { a -> FilterChip(selected = arrival == a, onClick = { arrival = a }, label = { Text(L(a.label), fontSize = 12.sp) }) }
        }

        when {
            pedestrian != null -> Column(Modifier.fillMaxWidth().background(Palette.red, RoundedCornerShape(22.dp)).padding(18.dp)) {
                Text(L("Pedestrian area").uppercase(), color = androidx.compose.ui.graphics.Color.White, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                Text(L("No, don't enter"), color = androidx.compose.ui.graphics.Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold)
                Text(L("Cars can't drive here. Park outside and walk."), color = androidx.compose.ui.graphics.Color.White)
            }
            zone != null && answer != null -> {
                VerdictCard(answer, if (arrival == Arrival.NOW) L("Now") else F("Arriving %@", AppState.engine.describe(at.toInstant(), nowZ.toInstant())), onWhy = { Nav.zone = zone })
                Text(zone.localizedName, fontSize = 13.sp, color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f), modifier = Modifier.clickable { Nav.zone = zone })
            }
            else -> {
                val near = nearestZone(AppState.cities, p.location)
                CardBox {
                    Column {
                        Pill(L("Outside the ZTL"), Palette.greenSoft, Palette.greenInk)
                        Spacer(Modifier.padding(3.dp))
                        Text(L("You can drive here freely."), fontWeight = FontWeight.SemiBold)
                        near?.let { Text(F("%@ is %@ away", it.second.shortName, Geometry.distanceText(it.third)), fontSize = 14.sp) }
                    }
                }
            }
        }

        zone?.ticket?.let { TicketBox(it) }
        if (zone != null && zone.hotelCanRegister && pedestrian == null) {
            HotelBox(p, zone, at, hotelInside) { hotelInside = it }
        }
        RouteBox(p, if (arrival == Arrival.NOW) null else at)
        StartButtons(p)
    }
}

/** «Controlla il tragitto»: tempo, km, ZTL attraversate con l'ora del passaggio e la risposta */
@Composable
private fun RouteBox(p: Place, arrival: ZonedDateTime?) {
    var working by remember(p.key) { mutableStateOf(false) }
    var error by remember(p.key) { mutableStateOf<String?>(null) }
    var route by remember(p.key) { mutableStateOf<Router.Route?>(null) }
    val scope = rememberCoroutineScope()
    val r = route
    if (r == null) {
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            OutlinedButton(onClick = {
                val from = Here.coordinate
                if (from == null) { error = L("Couldn't find your position. Allow location access to plan the drive."); return@OutlinedButton }
                working = true; error = null
                scope.launch {
                    val got = Router.drive(from, p.location)
                    working = false
                    if (got == null) error = L("Couldn't plan the drive right now. Check your connection.") else route = got
                }
            }, enabled = !working, modifier = Modifier.fillMaxWidth()) {
                Icon(Icons.Filled.DirectionsCar, null); Spacer(Modifier.width(8.dp)); Text(if (working) L("Planning…") else L("Check the drive"))
            }
            error?.let { Text(it, fontSize = 13.sp, color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f)) }
        }
        return
    }
    // Partenza: adesso, oppure all'ora giusta per arrivare quando hai scelto
    val departure = arrival?.toInstant()?.minusSeconds(r.seconds.toLong()) ?: Instant.now()
    val crossings = remember(r, departure.epochSecond / 60) {
        RouteCheck.crossings(RouteCheck.densify(r.path), AppState.cities.flatMap { it.zones }, departure, r.seconds) { z, t -> AppState.answer(z, t) }
    }
    val tf = DateTimeFormatter.ofPattern("HH:mm")
    fun hm(i: Instant) = i.atZone(ROME).format(tf)
    CardBox {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.Bottom) {
                val min = (r.seconds / 60).toInt()
                Text(if (min >= 60) "${min / 60} h ${min % 60} min" else "$min min", fontSize = 26.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.width(10.dp))
                Text(String.format(Locale.getDefault(), "%.1f km", r.meters / 1000), color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f))
                Spacer(Modifier.weight(1f))
                Text(F("Arrive %@", hm(departure.plusSeconds(r.seconds.toLong()))), fontWeight = FontWeight.SemiBold)
            }
            if (crossings.isEmpty()) Text(L("No ZTL on the way."), color = Palette.green, fontWeight = FontWeight.SemiBold)
            crossings.forEach { c ->
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.clickable { Nav.zone = c.zone }) {
                    Column(Modifier.weight(1f)) {
                        Text(c.zone.shortName, fontWeight = FontWeight.SemiBold)
                        Text(if (c.isDestination) F("Destination · at %@", hm(c.at)) else F("On the way · at %@", hm(c.at)), fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f))
                    }
                    VerdictPill(c.answer.verdict)
                }
            }
            if (crossings.any { !it.isDestination && it.answer.verdict !is Verdict.Yes })
                Text(L("A zone on the way is active: your navigator may route you through it. Watch the signs and avoid the gates."), fontSize = 13.sp, color = Palette.amber)
        }
    }
}

@Composable
private fun TicketBox(t: Ticket) {
    val ctx = LocalContext.current
    CardBox {
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(L("Ticket").uppercase(), fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Palette.amber)
            Text(String.format(Locale.ITALY, "€ %.2f", t.price), fontSize = 24.sp, fontWeight = FontWeight.Bold)
            Text(t.localizedHowTo, fontSize = 14.sp)
            when (t.deadline) {
                "nextDayMidnight" -> Text(L("Activate it by midnight of the next day."), fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                "beforeEntry" -> Text(L("Activate it before you drive in."), fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
            }
            t.url?.let { u -> Button(onClick = { runCatching { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(u))) } }) { Text(L("Pay the ticket")) } }
        }
    }
}

/** Hotel dentro la ZTL: giorni, messaggio per l'hotel, stato della registrazione */
@Composable
private fun HotelBox(p: Place, zone: Zone, arrival: ZonedDateTime, inside: Boolean, setInside: (Boolean) -> Unit) {
    val ctx = LocalContext.current
    var nights by remember(p.key) { mutableIntStateOf(2) }
    var lang by remember { mutableStateOf(if (Strings.language == "de") "de" else "it") }
    val vehicle = AppState.vehicle
    val city = AppState.cityOf(zone)
    val departure = arrival.plusDays(nights.toLong())
    val existing = AppState.permits.firstOrNull { it.kind == Permit.Kind.HOTEL && it.cityId == city?.id && it.vehicleId == vehicle.id &&
        it.to >= arrival.toInstant().toEpochMilli() && it.from <= departure.toInstant().toEpochMilli() }

    CardBox {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(L("Hotel registration"), fontWeight = FontWeight.SemiBold)
                    Text(L("Is this your hotel? It can register your plate."), fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.65f))
                }
                Switch(checked = inside, onCheckedChange = setInside)
            }
            if (!inside) return@Column
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(L("Nights"), modifier = Modifier.weight(1f))
                listOf(1, 2, 3, 4, 5, 7).forEach { n -> FilterChip(selected = nights == n, onClick = { nights = n }, label = { Text("$n") }) }
            }
            Text(F("%lld days to register, including the day you leave.", nights + 1), fontSize = 13.sp)
            if (vehicle.plate.isBlank()) {
                Text(if (vehicle.isRental) L("Rental car: you'll know the plate only at pick-up. Add it in Garage then, and send the message to the hotel straight away.")
                     else L("Add your plate in Garage first."), fontSize = 13.sp, color = Palette.amber)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                listOf("it" to "Italiano", "en" to "English", "de" to "Deutsch").forEach { (k, n) -> FilterChip(selected = lang == k, onClick = { lang = k }, label = { Text(n, fontSize = 12.sp) }) }
            }
            val text = HotelMessage.text(lang, arrival, vehicle.plate.ifBlank { "…" }, p.name, departure)
            Text(text, fontSize = 13.sp, modifier = Modifier.background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.05f), RoundedCornerShape(10.dp)).padding(10.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(onClick = { HotelMessage.share(ctx, text) }) { Icon(Icons.Filled.Share, null); Spacer(Modifier.width(6.dp)); Text(L("Send to the hotel")) }
            }
            // Stato: da chiedere → chiesta → confermata (la conferma vale come permesso nel Garage)
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                val state = existing?.status
                FilterChip(selected = existing == null, onClick = { existing?.let { e -> AppState.permits = AppState.permits - e; AppState.save() } }, label = { Text(L("To ask"), fontSize = 12.sp) })
                FilterChip(selected = state == Permit.Status.WAITING, onClick = { savePermit(existing, zone, arrival, departure, Permit.Status.WAITING) }, label = { Text(L("Asked"), fontSize = 12.sp) })
                FilterChip(selected = state == Permit.Status.CONFIRMED, onClick = { savePermit(existing, zone, arrival, departure, Permit.Status.CONFIRMED) }, label = { Text(L("Confirmed"), fontSize = 12.sp) })
            }
        }
    }
}

private fun savePermit(existing: Permit?, zone: Zone, arrival: ZonedDateTime, departure: ZonedDateTime, status: Permit.Status) {
    val city = AppState.cityOf(zone) ?: return
    val from = arrival.truncatedTo(ChronoUnit.DAYS).toInstant().toEpochMilli()
    val to = departure.truncatedTo(ChronoUnit.DAYS).plusDays(1).minusSeconds(1).toInstant().toEpochMilli()
    val p = Permit(id = existing?.id ?: java.util.UUID.randomUUID().toString(), kind = Permit.Kind.HOTEL, cityId = city.id, zoneId = null,
        vehicleId = AppState.vehicle.id, from = from, to = to, status = status)
    AppState.permits = AppState.permits.filter { it.id != p.id } + p
    AppState.save()
}

/** «Avvia»: il navigatore preferito con il guardiano, oppure gli altri */
@Composable
fun StartButtons(p: Place) {
    val ctx = LocalContext.current
    var menu by remember { mutableStateOf(false) }
    val preferred = Navigator.preferred(ctx)
    fun go(n: Navigator) {
        if (!GuardianService.canStart(ctx)) { Toast.makeText(ctx, L("Allow location access to see the ZTL near you."), Toast.LENGTH_LONG).show(); return }
        GuardianService.start(ctx, p)
        n.open(ctx, p)
    }
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Button(onClick = { go(preferred) }, modifier = Modifier.weight(1f)) {
                Icon(Icons.Filled.Navigation, null); Spacer(Modifier.width(8.dp)); Text(F("Start · %@", preferred.label), fontWeight = FontWeight.SemiBold)
            }
            Box {
                IconButton(onClick = { menu = true }) { Icon(Icons.Filled.MoreHoriz, L("More")) }
                DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                    Navigator.available(ctx).forEach { n -> DropdownMenuItem(text = { Text(n.label) }, onClick = { menu = false; go(n) }) }
                }
            }
        }
        Text(L("GateLR stays on with a notification and warns you before every gate."), fontSize = 12.sp,
            color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f))
        if (AppState.overlayOn && Build.VERSION.SDK_INT >= 23 && !Settings.canDrawOverlays(ctx)) {
            OutlinedButton(onClick = {
                ctx.startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:${ctx.packageName}")))
            }) { Text(L("Show the bubble over the navigator")) }
        }
    }
}
