package app.gatelr

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.content.Intent
import android.os.Bundle
import android.os.Looper
import android.provider.Settings
import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.HelpOutline
import androidx.compose.material.icons.filled.GpsFixed
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Luggage
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.heightIn
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import app.gatelr.core.BackStep
import app.gatelr.core.Coordinate
import app.gatelr.core.Freshness
import app.gatelr.core.L
import app.gatelr.core.Zone

/** La posizione mentre l'app è aperta (per la prima pagina e la mappa) */
object Here {
    var coordinate by mutableStateOf<Coordinate?>(null)
    /** 2.0.1 (B160): la posizione vale come «dove sei» solo se recente (10 minuti, come il widget); altrimenti null */
    val fresh: Coordinate? get() = coordinate?.takeIf { Freshness.isFresh(at, System.currentTimeMillis()) }
    /** 2.0: la direzione di marcia (gradi), solo se ti muovi: «Adesso» guarda la zona davanti */
    var course by mutableStateOf<Double?>(null)
    var at = 0L                       // quando è arrivata la posizione
    var allowed by mutableStateOf(false)
}

/** Navigazione tra le schede e la scheda della zona aperta */
object Nav {
    /** 2.0: 0 Adesso · 1 Mappa · 2 Viaggio · 3 Aiuto, lo stesso ordine dell'iPhone 2.0 */
    var tab by mutableIntStateOf(0)
    /** Il foglio unico «Dove vai?» aperto: "trip" (da Adesso e Viaggio) o "map" */
    var whereTo by mutableStateOf<String?>(null)
    /** Il posto scelto dalla mappa */
    var mapPin by mutableStateOf<app.gatelr.core.Place?>(null)
    /** Garage e impostazioni, dietro l'icona del veicolo */
    var settings by mutableStateOf(false)
    var zone by mutableStateOf<Zone?>(null)
    var tool by mutableStateOf<String?>(null)      // "sign" | "fines" | "log" | 2.0.2: "checks" (come controlliamo i dati) | "finehelp" (se ricevi una multa)
}

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 2.0.1 (B161): la lingua dell'app (Android 13+ la cambia per app e ricrea l'attività): i testi si ricaricano qui
        AppState.loadStrings(this)
        // 2.0.1 (B166): a ogni apertura (non alla rotazione) la città si sceglie di nuovo dalla posizione
        if (savedInstanceState == null) AppState.newOpening()
        enableEdgeToEdge()
        // 1.20.2: nessuna richiesta all'apertura (prima posizione e notifiche subito, a ogni avvio): le chiede chi le usa
        Permissions.install(this)
        Here.allowed = GuardianService.canStart(this)
        if (intent?.data?.host == "adesso") Nav.tab = 0          // 2.0: dal widget
        val prefs = getSharedPreferences("gatelr", MODE_PRIVATE)
        if (!prefs.getBoolean("welcomed", false)) welcome = true
        openZone(intent)
        setContent {
            GateTheme {
                if (welcome) Onboarding {
                    prefs.edit().putBoolean("welcomed", true).apply()
                    welcome = false
                } else Root()
            }
        }
    }

    private var welcome by mutableStateOf(false)

    /** 2.1: il tocco su un avviso del guardiano apre la scheda della zona davanti */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        openZone(intent)
    }

    private fun openZone(intent: Intent?) {
        val id = intent?.getStringExtra("zone") ?: return
        AppState.cities.flatMap { it.zones }.firstOrNull { it.id == id }?.let { Nav.zone = it }
    }

    override fun onResume() {
        super.onResume()
        // 2.0.1 (B80): il permesso dato dalle Impostazioni con l'app aperta si vede subito
        Here.allowed = GuardianService.canStart(this)
    }

    override fun onStop() {
        super.onStop()
        ZoneWidget.refresh(this)          // il widget segue la zona scelta nell'app
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun Root() {
    LocationWhileOpen()
    // 2.0: quattro schede come l'iPhone 2.0; Garage e impostazioni dietro l'icona del veicolo
    val tabs = listOf(
        Pair("Now", Icons.Filled.GpsFixed),
        Pair("Map", Icons.Filled.Map),
        Pair("Trip", Icons.Filled.Luggage),
        Pair("Help", Icons.AutoMirrored.Filled.HelpOutline),
    )
    // Indietro (anche «predictive back»): 2.0.1 (B81) prima chiude il posto aperto in Viaggio o lo spillo sulla mappa,
    // poi torna ad Adesso; da Adesso esce
    val back = BackStep.next(Nav.tab, AppState.place != null, Nav.mapPin != null)
    BackHandler(enabled = back != BackStep.Action.EXIT) {
        when (back) {
            BackStep.Action.CLOSE_PLACE -> AppState.select(null)
            BackStep.Action.CLOSE_PIN -> Nav.mapPin = null
            BackStep.Action.GO_NOW -> Nav.tab = 0
            BackStep.Action.EXIT -> {}
        }
    }
    Scaffold(bottomBar = {
        NavigationBar(containerColor = cardColor) {
            tabs.forEachIndexed { i, t ->
                NavigationBarItem(selected = Nav.tab == i, onClick = { Nav.tab = i },
                    icon = { TabIcon(t.second, Nav.tab == i) }, label = { Text(L(t.first), maxLines = 1, fontWeight = if (Nav.tab == i) FontWeight.Bold else FontWeight.Medium) },
                    colors = NavigationBarItemDefaults.colors(indicatorColor = Ink.surface2))
            }
        }
    }) { pad ->
        val m = Modifier.padding(pad)
        // Cambio di scheda: dissolvenza breve (150 ms, la barra si tocca spessissimo), niente scorrimento; con le animazioni spente è immediato
        Crossfade(targetState = Nav.tab, animationSpec = tween(if (animationsOn()) 150 else 0), label = "scheda") { tab ->
            when (tab) {
                0 -> HomeScreen(m)
                1 -> MapScreen(m)
                2 -> TripScreen(m)
                else -> HelpScreen(m)
            }
        }
    }
    Nav.zone?.let { z ->
        ModalBottomSheet(onDismissRequest = { Nav.zone = null }, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) {
            ZoneDetail(z)
        }
    }
    Nav.tool?.let { t ->
        ModalBottomSheet(onDismissRequest = { Nav.tool = null }, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) {
            when (t) { "sign" -> SignReaderScreen(); "log" -> DriveLog(); "checks" -> ChecksPage(); "finehelp" -> FineHelpPage(); else -> FineGuide() }
        }
    }
    Nav.whereTo?.let { target ->
        ModalBottomSheet(onDismissRequest = { Nav.whereTo = null }, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) {
            WhereToSheet { p ->
                Nav.whereTo = null
                if (target == "map") Nav.mapPin = p else { AppState.select(p); Nav.tab = 2 }
            }
        }
    }
    if (Nav.settings) {
        ModalBottomSheet(onDismissRequest = { Nav.settings = false }, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) {
            var page by rememberSaveable { mutableIntStateOf(0) }
            Column(Modifier.fillMaxHeight(0.94f)) {
                TabRow(selectedTabIndex = page, containerColor = Color.Transparent) {
                    Tab(selected = page == 0, onClick = { page = 0 }, text = { Text(L("Garage")) }, modifier = Modifier.heightIn(min = 48.dp))
                    Tab(selected = page == 1, onClick = { page = 1 }, text = { Text(L("Settings")) }, modifier = Modifier.heightIn(min = 48.dp))
                }
                if (page == 0) GarageScreen(Modifier.weight(1f)) else AccountScreen(Modifier.weight(1f))
            }
        }
    }
}

/** Le animazioni di sistema sono accese? (Opzioni sviluppatore / Accessibilità → «Rimuovi animazioni» le mette a 0) */
@Composable
fun animationsOn(): Boolean {
    val ctx = LocalContext.current
    return remember(ctx) {
        Settings.Global.getFloat(ctx.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) > 0f
    }
}

/** L'icona della scheda: quando diventa scelta fa un piccolo rimbalzo 1 → 1,12 → 1 (120 ms + molla senza rimbalzo,
 *  in tutto meno di 0,3 s, solo la scala). Niente animazione se le animazioni di sistema sono spente. */
@Composable
fun TabIcon(icon: ImageVector, selected: Boolean) {
    val scale = remember { Animatable(1f) }
    val animate = animationsOn()
    var first by remember { mutableStateOf(true) }
    LaunchedEffect(selected) {
        if (first) { first = false; return@LaunchedEffect }       // all'avvio nessun rimbalzo
        if (!selected || !animate) { scale.snapTo(1f); return@LaunchedEffect }
        scale.animateTo(1.12f, tween(durationMillis = 90, easing = FastOutSlowInEasing))
        scale.animateTo(1f, spring(dampingRatio = Spring.DampingRatioNoBouncy, stiffness = Spring.StiffnessMediumLow))
    }
    Icon(icon, null, modifier = Modifier.graphicsLayer { scaleX = scale.value; scaleY = scale.value })
}

@SuppressLint("MissingPermission")
@Composable
fun LocationWhileOpen() {
    val ctx = LocalContext.current
    val allowed = Here.allowed
    val lifecycle = androidx.compose.ui.platform.LocalLifecycleOwner.current.lifecycle
    DisposableEffect(allowed, lifecycle) {
        val lm = ctx.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val listener = LocationListener { l ->
            Here.coordinate = Coordinate(l.latitude, l.longitude); Here.at = System.currentTimeMillis()
            Here.course = if (l.hasBearing() && l.hasSpeed() && l.speed > 2f) l.bearing.toDouble() else null
            AppState.adoptCity(Coordinate(l.latitude, l.longitude))      // 1.20.2: alla prima posizione, la città dove sei
        }
        fun on() {
            if (!allowed) return
            for (p in listOf(LocationManager.NETWORK_PROVIDER, LocationManager.GPS_PROVIDER)) {
                if (lm.allProviders.contains(p)) {
                    runCatching { lm.getLastKnownLocation(p) }.getOrNull()?.let {
                        // 2.0.1 (B160): l'ultima posizione nota vale solo se recente (meno di 10 minuti), con la sua ora:
                        // prima una posizione di ieri a Firenze diventava «dove sei» anche a Bologna
                        if (Freshness.isFresh(it.time, System.currentTimeMillis()) && it.time > Here.at) {
                            Here.coordinate = Coordinate(it.latitude, it.longitude); Here.at = it.time
                            AppState.adoptCity(Coordinate(it.latitude, it.longitude))
                        }
                    }
                    runCatching { lm.requestLocationUpdates(p, 10_000L, 50f, listener, Looper.getMainLooper()) }
                }
            }
        }
        // Solo con l'app aperta: in sottofondo la posizione la segue il guardiano, se l'hai avviato
        val obs = androidx.lifecycle.LifecycleEventObserver { _, e ->
            if (e == androidx.lifecycle.Lifecycle.Event.ON_START) on()
            if (e == androidx.lifecycle.Lifecycle.Event.ON_STOP) runCatching { lm.removeUpdates(listener) }
        }
        lifecycle.addObserver(obs)
        onDispose { lifecycle.removeObserver(obs); runCatching { lm.removeUpdates(listener) } }
    }
}
