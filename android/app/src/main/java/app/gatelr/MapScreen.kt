package app.gatelr

import androidx.compose.foundation.background
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
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
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

/** Le zone in GeoJSON: colore per tipo (verde ben visibile), aree pedonali più piccole sopra */
private fun zonesGeoJson(cities: List<City>): String {
    val sb = StringBuilder("{\"type\":\"FeatureCollection\",\"features\":[")
    var first = true
    fun ring(points: List<Coordinate>) = (points + points.first()).joinToString(",") { "[${it.lon},${it.lat}]" }
    // Prima le zone grandi, così le piccole restano sopra e si toccano
    for (c in cities) for (z in c.zones.sortedByDescending { it.roughArea }) {
        if (!first) sb.append(','); first = false
        val green = z.type == ZoneKind.GREEN
        sb.append("{\"type\":\"Feature\",\"properties\":{\"id\":\"${z.id}\",\"color\":\"${hex(Palette.kind(z.type))}\",")
            .append("\"opacity\":${if (green) 0.30 else 0.22},\"width\":${if (green) 4.0 else 2.5}},")
            .append("\"geometry\":{\"type\":\"Polygon\",\"coordinates\":[[${ring(z.perimeter)}]]}}")
    }
    for (c in cities) for (p in c.pedestrian.orEmpty()) {
        if (!first) sb.append(','); first = false
        sb.append("{\"type\":\"Feature\",\"properties\":{\"id\":\"${p.id}\",\"color\":\"#7A1F5C\",\"opacity\":0.28,\"width\":1.5},")
            .append("\"geometry\":{\"type\":\"Polygon\",\"coordinates\":[[${ring(p.perimeter)}]]}}")
    }
    return sb.append("]}").toString()
}

private fun pinGeoJson(p: Place?, color: Color): String =
    if (p == null) "{\"type\":\"FeatureCollection\",\"features\":[]}"
    else "{\"type\":\"Feature\",\"properties\":{\"color\":\"${hex(color)}\"},\"geometry\":{\"type\":\"Point\",\"coordinates\":[${p.location.lon},${p.location.lat}]}}"

private fun verdictColor(v: Verdict?): Color = when (v) {
    is Verdict.Yes, null -> Palette.green; is Verdict.No -> Palette.red; else -> Color(0xFFD99A00)
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
                m.setStyle(Style.Builder().fromUri(if (dark) STYLE_DARK else STYLE)) { style ->
                    style.addSource(GeoJsonSource("zones", zonesGeoJson(AppState.cities)))
                    style.addLayer(FillLayer("zones-fill", "zones").withProperties(
                        PropertyFactory.fillColor(Expression.get("color")), PropertyFactory.fillOpacity(Expression.get("opacity"))))
                    style.addLayer(LineLayer("zones-line", "zones").withProperties(
                        PropertyFactory.lineColor(Expression.get("color")), PropertyFactory.lineWidth(Expression.get("width"))))
                    style.addSource(GeoJsonSource("pin", pinGeoJson(null, Palette.green)))
                    style.addLayer(CircleLayer("pin-dot", "pin").withProperties(
                        PropertyFactory.circleColor(Expression.get("color")), PropertyFactory.circleRadius(11f),
                        PropertyFactory.circleStrokeColor("#FFFFFF"), PropertyFactory.circleStrokeWidth(3.5f)))
                    styleReady = true
                }
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
    val pinColor = if (pinPedestrian != null) Palette.red else verdictColor(pinAnswer?.verdict)

    LaunchedEffect(pin, pinColor, styleReady) {
        if (!styleReady) return@LaunchedEffect
        map?.style?.getSourceAs<GeoJsonSource>("pin")?.setGeoJson(pinGeoJson(pin, pinColor))
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
                        Column(Modifier.fillMaxWidth().clickable { pin = p; query = p.name; results = emptyList() }.padding(12.dp)) {
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
                Text(L("Plan this trip") + " ›", color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.clickable { AppState.select(p); Nav.tab = 2 })
            }
        }
    }
}

@Composable
private fun LegendRow(c: Color, text: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(14.dp).background(c, CircleShape)); Spacer(Modifier.width(8.dp)); Text(text, fontSize = 13.sp)
    }
}
