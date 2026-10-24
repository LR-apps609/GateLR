package app.gatelr

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Looper
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material.icons.filled.Luggage
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
import app.gatelr.core.Coordinate
import app.gatelr.core.L
import app.gatelr.core.Zone

/** La posizione mentre l'app è aperta (per la prima pagina e la mappa) */
object Here {
    var coordinate by mutableStateOf<Coordinate?>(null)
    var at = 0L                       // quando è arrivata la posizione
    var allowed by mutableStateOf(false)
}

/** Navigazione tra le schede e la scheda della zona aperta */
object Nav {
    var tab by mutableIntStateOf(0)
    var zone by mutableStateOf<Zone?>(null)
    var tool by mutableStateOf<String?>(null)      // "sign" | "fines"
}

class MainActivity : ComponentActivity() {
    private val ask = registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { r ->
        Here.allowed = r[Manifest.permission.ACCESS_FINE_LOCATION] == true || r[Manifest.permission.ACCESS_COARSE_LOCATION] == true
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        Here.allowed = GuardianService.canStart(this)
        val prefs = getSharedPreferences("gatelr", MODE_PRIVATE)
        if (prefs.getBoolean("welcomed", false)) askPermissions()
        else welcome = true
        setContent {
            GateTheme {
                if (welcome) Onboarding {
                    prefs.edit().putBoolean("welcomed", true).apply()
                    welcome = false
                    askPermissions()
                } else Root()
            }
        }
    }

    private var welcome by mutableStateOf(false)

    /** Posizione (se manca) e notifiche (Android 13+), dopo la spiegazione del benvenuto */
    private fun askPermissions() {
        val list = mutableListOf<String>()
        if (!Here.allowed) list += listOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED)
            list += Manifest.permission.POST_NOTIFICATIONS
        if (list.isNotEmpty()) ask.launch(list.toTypedArray())
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
    val tabs = listOf(
        Triple("Gate", Icons.Filled.Shield, "varco"),
        Triple("Map", Icons.Filled.Map, "map"),
        Triple("Trip", Icons.Filled.Luggage, "trip"),
        Triple("Garage", Icons.Filled.DirectionsCar, "garage"),
        Triple("Account", Icons.Filled.Person, "account"),
    )
    Scaffold(bottomBar = {
        NavigationBar {
            tabs.forEachIndexed { i, t ->
                NavigationBarItem(selected = Nav.tab == i, onClick = { Nav.tab = i },
                    icon = { Icon(t.second, null) }, label = { Text(L(t.first), maxLines = 1) })
            }
        }
    }) { pad ->
        val m = Modifier.padding(pad)
        when (Nav.tab) {
            0 -> HomeScreen(m)
            1 -> MapScreen(m)
            2 -> TripScreen(m)
            3 -> GarageScreen(m)
            else -> AccountScreen(m)
        }
    }
    Nav.zone?.let { z ->
        ModalBottomSheet(onDismissRequest = { Nav.zone = null }, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) {
            ZoneDetail(z)
        }
    }
    Nav.tool?.let { t ->
        ModalBottomSheet(onDismissRequest = { Nav.tool = null }, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) {
            if (t == "sign") SignReaderScreen() else FineGuide()
        }
    }
}

@SuppressLint("MissingPermission")
@Composable
fun LocationWhileOpen() {
    val ctx = LocalContext.current
    val allowed = Here.allowed
    val lifecycle = androidx.compose.ui.platform.LocalLifecycleOwner.current.lifecycle
    DisposableEffect(allowed, lifecycle) {
        val lm = ctx.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val listener = LocationListener { l -> Here.coordinate = Coordinate(l.latitude, l.longitude); Here.at = System.currentTimeMillis() }
        fun on() {
            if (!allowed) return
            for (p in listOf(LocationManager.NETWORK_PROVIDER, LocationManager.GPS_PROVIDER)) {
                if (lm.allProviders.contains(p)) {
                    runCatching { lm.getLastKnownLocation(p) }.getOrNull()?.let { if (Here.coordinate == null) Here.coordinate = Coordinate(it.latitude, it.longitude) }
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
