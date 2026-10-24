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
    var allowed by mutableStateOf(false)
}

/** Navigazione tra le schede e la scheda della zona aperta */
object Nav {
    var tab by mutableIntStateOf(0)
    var zone by mutableStateOf<Zone?>(null)
}

class MainActivity : ComponentActivity() {
    private val ask = registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { r ->
        Here.allowed = r[Manifest.permission.ACCESS_FINE_LOCATION] == true || r[Manifest.permission.ACCESS_COARSE_LOCATION] == true
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        Here.allowed = GuardianService.canStart(this)
        if (!Here.allowed) {
            val list = mutableListOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)
            if (Build.VERSION.SDK_INT >= 33) list += Manifest.permission.POST_NOTIFICATIONS
            ask.launch(list.toTypedArray())
        }
        setContent { GateTheme { Root() } }
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
}

@SuppressLint("MissingPermission")
@Composable
fun LocationWhileOpen() {
    val ctx = LocalContext.current
    val allowed = Here.allowed
    DisposableEffect(allowed) {
        val lm = ctx.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val listener = LocationListener { l -> Here.coordinate = Coordinate(l.latitude, l.longitude) }
        if (allowed) {
            for (p in listOf(LocationManager.NETWORK_PROVIDER, LocationManager.GPS_PROVIDER)) {
                if (lm.allProviders.contains(p)) {
                    runCatching { lm.getLastKnownLocation(p) }.getOrNull()?.let { if (Here.coordinate == null) Here.coordinate = Coordinate(it.latitude, it.longitude) }
                    runCatching { lm.requestLocationUpdates(p, 10_000L, 50f, listener, Looper.getMainLooper()) }
                }
            }
        }
        onDispose { runCatching { lm.removeUpdates(listener) } }
    }
}
