package app.gatelr

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.CardTravel
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.SmallFloatingActionButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import app.gatelr.core.City
import app.gatelr.core.Coordinate
import app.gatelr.core.F
import app.gatelr.core.Geometry
import app.gatelr.core.L
import app.gatelr.core.Place
import app.gatelr.core.Verdict
import app.gatelr.core.ZoneKind
import app.gatelr.core.nearestZone
import app.gatelr.core.pedestrianAreaAt
import app.gatelr.core.zonesAt
import kotlinx.coroutines.delay
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.camera.CameraUpdateFactory
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.geometry.LatLngBounds
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.MapView
import org.maplibre.android.maps.Style
import org.maplibre.android.style.expressions.Expression
import org.maplibre.android.style.layers.CircleLayer
import org.maplibre.android.style.layers.FillLayer
import org.maplibre.android.style.layers.LineLayer
import org.maplibre.android.style.layers.PropertyFactory
import org.maplibre.android.style.sources.GeoJsonSource
import java.time.Instant

private const val STYLE = "https://tiles.openfreemap.org/styles/liberty"
private const val STYLE_DARK = "https://tiles.openfreemap.org/styles/dark"

private fun hex(c: Color) = String.format("#%06X", 0xFFFFFF and c.toArgb())

/**
 * Le zone in GeoJSON: colore per tipo (verde ben visibile), aree pedonali più piccole sopra.
 * Con un posto cercato ([lit] non nullo) le zone che lo contengono si accendono del colore della risposta
 * ([neon]) con un bagliore, le altre restano appena accennate: si vede subito se è dentro o fuori.
 */
private fun zonesGeoJson(cities: List<City>, lit: Set<String>? = null, neon: Color = Palette.green): String {
    val sb = StringBuilder("{\"type\":\"FeatureCollection\",\"features\":[")
    var first = true
    fun ring(points: List<Coordinate>) = (points + points.first()).joinToString(",") { "[${it.lon},${it.lat}]" }
    // Prima le zone grandi, così le piccole restano sopra e si toccano
    for (c in cities) for (z in c.zones.sortedByDescending { it.roughArea }) {
        if (!first) sb.append(','); first = false
        val green = z.type == ZoneKind.GREEN
        sb.append("{\"type\":\"Feature\",\"properties\":{\"id\":\"${z.id}\",")
            .append(look(Palette.kind(z.type), if (green) 0.30 else 0.22, if (green) 4.0 else 2.5, lit, z.id, neon)).append("},")
            .append("\"geometry\":{\"type\":\"Polygon\",\"coordinates\":[[${ring(z.perimeter)}]]}}")
    }
    for (c in cities) for (p in c.pedestrian.orEmpty()) {
        if (!first) sb.append(','); first = false
        sb.append("{\"type\":\"Feature\",\"properties\":{\"id\":\"${p.id}\",")
            .append(look(Color(0xFF7A1F5C), 0.28, 1.5, lit, p.id, neon)).append("},")
            .append("\"geometry\":{\"type\":\"Polygon\",\"coordinates\":[[${ring(p.perimeter)}]]}}")
    }
    return sb.append("]}").toString()
}

/** Colore, riempimento, linea e bagliore di una zona, normale o con un posto cercato */
private fun look(color: Color, opacity: Double, width: Double, lit: Set<String>?, id: String, neon: Color): String = when {
    lit == null -> "\"color\":\"${hex(color)}\",\"opacity\":$opacity,\"width\":$width,\"line\":1.0,\"glow\":0"
    id in lit -> "\"color\":\"${hex(neon)}\",\"opacity\":0.32,\"width\":3.0,\"line\":1.0,\"glow\":12"
    else -> "\"color\":\"${hex(color)}\",\"opacity\":0.05,\"width\":1.0,\"line\":0.35,\"glow\":0"
}

private fun pinGeoJson(p: Place?, color: Color): String =
    if (p == null) "{\"type\":\"FeatureCollection\",\"features\":[]}"
    else "{\"type\":\"Feature\",\"properties\":{\"color\":\"${hex(color)}\"},\"geometry\":{\"type\":\"Point\",\"coordinates\":[${p.location.lon},${p.location.lat}]}}"

/** Il posto cercato come sull'iPhone (PlaceCheck): fuori, area pedonale o la risposta della zona */
private enum class PlaceKind { OUTSIDE, OPEN, CLOSED, CONDITIONAL, UNSURE, PEDESTRIAN }

private fun placeKind(pedestrian: Boolean, v: Verdict?): PlaceKind = when {
    pedestrian -> PlaceKind.PEDESTRIAN
    v == null -> PlaceKind.OUTSIDE
    v is Verdict.Yes -> PlaceKind.OPEN; v is Verdict.No -> PlaceKind.CLOSED
    v is Verdict.Conditional -> PlaceKind.CONDITIONAL; else -> PlaceKind.UNSURE
}

/** Verde si entra, rosso no, ambra con una condizione: colori accesi per la mappa scura */
private fun PlaceKind.neon(): Color = when (this) {
    PlaceKind.OUTSIDE, PlaceKind.OPEN -> Color(0xFF3DDC74)
    PlaceKind.CLOSED, PlaceKind.PEDESTRIAN -> Color(0xFFFF4D4D)
    else -> Color(0xFFF2C14E)
}

/** La scritta del riquadro: «ZTL ATTIVA · NON ENTRARE», «FUORI DALLA ZTL»… */
private fun PlaceKind.callout(gatesOn: Boolean): String = when (this) {
    PlaceKind.OUTSIDE -> L("Outside the ZTL")
    PlaceKind.PEDESTRIAN -> L("Pedestrian area · don't enter")
    PlaceKind.CLOSED -> L("ZTL active · don't enter")
    PlaceKind.OPEN -> if (gatesOn) L("You can enter") else L("ZTL off · you can enter")
    PlaceKind.CONDITIONAL -> L("On one condition")
    PlaceKind.UNSURE -> L("Not sure")
}

/** Aggiunge sorgenti e strati delle zone e dello spillo a uno stile appena caricato */
private fun addLayers(style: Style, zones: String, pin: String) {
    style.addSource(GeoJsonSource("zones", zones))
    style.addLayer(LineLayer("zones-glow", "zones").withProperties(
        PropertyFactory.lineColor(Expression.get("color")), PropertyFactory.lineWidth(Expression.get("glow")),
        PropertyFactory.lineOpacity(0.35f), PropertyFactory.lineBlur(6f)))
    style.addLayer(FillLayer("zones-fill", "zones").withProperties(
        PropertyFactory.fillColor(Expression.get("color")), PropertyFactory.fillOpacity(Expression.get("opacity"))))
    style.addLayer(LineLayer("zones-line", "zones").withProperties(
        PropertyFactory.lineColor(Expression.get("color")), PropertyFactory.lineWidth(Expression.get("width")),
        PropertyFactory.lineOpacity(Expression.get("line"))))
    style.addSource(GeoJsonSource("pin", pin))
    style.addLayer(CircleLayer("pin-halo", "pin").withProperties(
        PropertyFactory.circleColor(Expression.get("color")), PropertyFactory.circleRadius(20f), PropertyFactory.circleOpacity(0.3f)))
    style.addLayer(CircleLayer("pin-dot", "pin").withProperties(
        PropertyFactory.circleColor(Expression.get("color")), PropertyFactory.circleRadius(11f),
        PropertyFactory.circleStrokeColor("#FFFFFF"), PropertyFactory.circleStrokeWidth(3.5f)))
}

@Composable
fun MapScreen(modifier: Modifier) {
    val ctx = LocalContext.current
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    var map by remember { mutableStateOf<MapLibreMap?>(null) }
    var styleReady by remember { mutableStateOf(false) }
    var query by remember { mutableStateOf("") }
    var results by remember { mutableStateOf(listOf<Place>()) }
    var pin by remember { mutableStateOf<Place?>(null) }
    var legend by remember { mutableStateOf(false) }
    var styleUri by remember { mutableStateOf("") }
    val focus = LocalFocusManager.current
    val now = rememberNow()
    val dark = androidx.compose.foundation.isSystemInDarkTheme()

    val mapView = remember {
        MapView(ctx).apply {
            onCreate(null)
            getMapAsync { m ->
                m.uiSettings.isCompassEnabled = true
                m.uiSettings.isRotateGesturesEnabled = true
                val c = AppState.city.center
                m.cameraPosition = CameraPosition.Builder().target(LatLng(c.lat, c.lon)).zoom(13.0).build()
                // Tocco sulla mappa: la zona sotto il dito
                m.addOnMapClickListener { ll ->
                    val hit = zonesAt(AppState.cities, Coordinate(ll.latitude, ll.longitude)).minByOrNull { it.second.roughArea }
                    if (hit != null) Nav.zone = hit.second
                    hit != null
                }
                map = m
            }
        }
    }

    DisposableEffect(lifecycle) {
        val obs = LifecycleEventObserver { _, e ->
            when (e) {
                Lifecycle.Event.ON_START -> mapView.onStart(); Lifecycle.Event.ON_RESUME -> mapView.onResume()
                Lifecycle.Event.ON_PAUSE -> mapView.onPause(); Lifecycle.Event.ON_STOP -> mapView.onStop()
                else -> {}
            }
        }
        lifecycle.addObserver(obs)
        if (lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)) mapView.onStart()
        if (lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)) mapView.onResume()
        onDispose {
            lifecycle.removeObserver(obs)
            if (lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)) mapView.onPause()
            if (lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)) mapView.onStop()
            mapView.onDestroy()
        }
    }

    // Ricerca con una piccola attesa mentre scrivi
    LaunchedEffect(query) {
        if (query.length < 3) { results = emptyList(); return@LaunchedEffect }
        delay(350)
        results = Geocoder.search(query, Here.coordinate ?: AppState.city.center)
    }

    val pinZone = pin?.let { p -> zonesAt(AppState.cities, p.location).minByOrNull { it.second.roughArea }?.second }
    val pinAnswer = pinZone?.let { AppState.answer(it, now) }
    val pinPedestrian = pin?.let { pedestrianAreaAt(AppState.cities, it.location) }
    val pinKind = pin?.let { placeKind(pinPedestrian != null, pinAnswer?.verdict) }
    val pinColor = pinKind?.neon() ?: Palette.green

    // Con un posto cercato la mappa passa allo stile scuro (le zone accese si vedono meglio), poi torna com'era
    val wantStyle = if (dark || pin != null) STYLE_DARK else STYLE
    LaunchedEffect(map, wantStyle) {
        val m = map ?: return@LaunchedEffect
        if (styleUri == wantStyle) return@LaunchedEffect
        styleUri = wantStyle; styleReady = false
        m.setStyle(Style.Builder().fromUri(wantStyle)) { style ->
            addLayers(style, zonesGeoJson(AppState.cities), pinGeoJson(null, Palette.green))
            styleReady = true
        }
    }
    // Le sorgenti si aggiornano solo quando cambia il posto o la sua risposta, non a ogni minuto
    LaunchedEffect(pin?.key, pinKind, styleReady) {
        if (!styleReady) return@LaunchedEffect
        val style = map?.style ?: return@LaunchedEffect
        val lit = pin?.let { p -> (zonesAt(AppState.cities, p.location).map { it.second.id } + listOfNotNull(pinPedestrian?.id)).toSet() }
        style.getSourceAs<GeoJsonSource>("zones")?.setGeoJson(zonesGeoJson(AppState.cities, lit, pinColor))
        style.getSourceAs<GeoJsonSource>("pin")?.setGeoJson(pinGeoJson(pin, pinColor))
    }
    LaunchedEffect(pin?.key, map) {
        pin?.let { map?.animateCamera(CameraUpdateFactory.newLatLngZoom(LatLng(it.location.lat, it.location.lon), 15.0)) }
    }
    // Cambio città dalla prima pagina: la mappa va lì
    LaunchedEffect(AppState.cityId, map) {
        val m = map ?: return@LaunchedEffect
        if (pin != null) return@LaunchedEffect
        val pts = AppState.city.zones.flatMap { it.perimeter }
        if (pts.isEmpty()) return@LaunchedEffect
        val b = LatLngBounds.Builder().apply { pts.forEach { include(LatLng(it.lat, it.lon)) } }.build()
        m.easeCamera(CameraUpdateFactory.newLatLngBounds(b, 80))
    }

    Box(modifier.fillMaxSize()) {
        AndroidView(factory = { mapView }, modifier = Modifier.fillMaxSize())

        Column(Modifier.fillMaxWidth().padding(12.dp)) {
            OutlinedTextField(
                value = query, onValueChange = { query = it }, singleLine = true,
                placeholder = { Text(L("Search hotel or address")) },
                leadingIcon = { Icon(Icons.Filled.Search, null) },
                trailingIcon = { if (query.isNotEmpty() || pin != null) IconButton(onClick = { query = ""; pin = null; results = emptyList() }) { Icon(Icons.Filled.Close, null) } },
                shape = RoundedCornerShape(14.dp),
                colors = OutlinedTextFieldDefaults.colors(focusedContainerColor = MaterialTheme.colorScheme.surface, unfocusedContainerColor = MaterialTheme.colorScheme.surface),
                modifier = Modifier.fillMaxWidth()
            )
            if (results.isNotEmpty() && pin?.name != query) {
                LazyColumn(Modifier.fillMaxWidth().heightIn(max = 280.dp).padding(top = 4.dp)
                    .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(14.dp))) {
                    items(results) { p ->
                        Column(Modifier.fillMaxWidth().clickable { pin = p; query = p.name; results = emptyList(); focus.clearFocus() }.padding(12.dp)) {
                            Text(p.name, fontWeight = FontWeight.SemiBold)
                            if (p.address.isNotEmpty()) Text(p.address, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f))
                        }
                    }
                }
            }
        }

        Column(Modifier.align(Alignment.CenterEnd).padding(12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            SmallFloatingActionButton(onClick = { legend = !legend }) { Icon(Icons.Filled.Info, L("Legend")) }
            if (Here.coordinate != null) SmallFloatingActionButton(onClick = {
                Here.coordinate?.let { map?.animateCamera(CameraUpdateFactory.newLatLngZoom(LatLng(it.lat, it.lon), 15.0)) }
            }) { Icon(Icons.Filled.MyLocation, null) }
        }

        if (legend) {
            Column(Modifier.align(Alignment.TopEnd).padding(top = 80.dp, end = 64.dp)
                .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(14.dp)).padding(12.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp)) {
                listOf(ZoneKind.RESTRICTED, ZoneKind.PASS, ZoneKind.GREEN).forEach { k -> LegendRow(Palette.kind(k), k.title) }
                LegendRow(Color(0xFF7A1F5C), L("Pedestrian area"))
            }
        }

        // La scheda in basso con la risposta per il posto cercato
        pin?.let { p ->
            Column(Modifier.align(Alignment.BottomCenter).fillMaxWidth().padding(12.dp)
                .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(20.dp)).padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp)) {
                pinKind?.let { k -> Callout(k.callout(pinAnswer?.gatesOn == true), k.neon()) }
                Text(p.name, fontWeight = FontWeight.Bold, fontSize = 18.sp, maxLines = 1)
                when {
                    pinPedestrian != null -> {
                        Pill(L("Pedestrian area"), Palette.redSoft, Palette.redInk)
                        Text(L("Cars can't drive here. Park outside and walk."), fontSize = 14.sp)
                    }
                    pinZone != null && pinAnswer != null -> {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            VerdictPill(pinAnswer.verdict); Spacer(Modifier.width(8.dp))
                            Text(pinZone.shortName, fontSize = 14.sp, modifier = Modifier.clickable { Nav.zone = pinZone })
                        }
                        Text(pinAnswer.verdict.detail, fontSize = 14.sp, maxLines = 3)
                    }
                    else -> {
                        val near = nearestZone(AppState.cities, p.location)
                        Pill(L("Outside the ZTL"), Palette.greenSoft, Palette.greenInk)
                        near?.let { Text(F("%@ is %@ away", it.second.shortName, Geometry.distanceText(it.third)), fontSize = 14.sp) }
                    }
                }
                // «Avvia» direttamente da qui: il navigatore preferito con il guardiano
                StartControls(p, Modifier.padding(top = 4.dp))
                OutlinedButton(onClick = { AppState.select(p); Nav.tab = 2 }, modifier = Modifier.fillMaxWidth()) {
                    Icon(Icons.Filled.CardTravel, null); Spacer(Modifier.width(8.dp)); Text(L("Trip details"))
                }
            }
        }
    }
}

/** Il riquadro scuro con la scritta accesa, come il cartello sulla mappa dell'iPhone */
@Composable
private fun Callout(text: String, neon: Color) {
    Text(text.uppercase(), color = neon, fontSize = 13.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.1.sp, maxLines = 1,
        modifier = Modifier.background(Color.Black.copy(alpha = 0.85f), RoundedCornerShape(4.dp))
            .border(1.dp, neon, RoundedCornerShape(4.dp)).padding(horizontal = 10.dp, vertical = 5.dp))
}

@Composable
private fun LegendRow(c: Color, text: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(14.dp).background(c, CircleShape)); Spacer(Modifier.width(8.dp)); Text(text, fontSize = 13.sp)
    }
}
