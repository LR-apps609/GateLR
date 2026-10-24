package app.gatelr

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.LocationOff
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.gatelr.core.F
import app.gatelr.core.Geometry
import app.gatelr.core.L
import app.gatelr.core.Verdict
import app.gatelr.core.Zone
import app.gatelr.core.nearestZone
import kotlinx.coroutines.delay
import java.time.Instant

/** L'ora che scorre: le risposte si aggiornano da sole ogni 30 secondi */
@Composable
fun rememberNow(): Instant {
    var now by remember { mutableStateOf(Instant.now()) }
    LaunchedEffect(Unit) { while (true) { delay(30_000); now = Instant.now() } }
    return now
}

@Composable
fun HomeScreen(modifier: Modifier) {
    val now = rememberNow()
    val ctx = LocalContext.current
    LazyColumn(modifier.fillMaxSize().background(MaterialTheme.colorScheme.background),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {

        if (GuardianService.active) item {
            Row(Modifier.fillMaxWidth().background(Palette.blue, RoundedCornerShape(16.dp)).padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.Shield, null, tint = Color.White)
                Spacer(Modifier.width(10.dp))
                Text(GuardianService.destination?.let { F("Guardian on · to %@", it.name) } ?: L("Guardian on"), color = Color.White, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                TextButton(onClick = { GuardianService.stop(ctx) }) { Text(L("Stop"), color = Color.White) }
            }
        }

        // Il riquadro d'impatto: cosa fa l'app, in cinque secondi
        item {
            Column(Modifier.fillMaxWidth().background(Palette.blue, RoundedCornerShape(26.dp)).padding(22.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(L("Know before|the gate.").replace("|", "\n"), color = Color.White, fontSize = 32.sp, fontWeight = FontWeight.Bold, lineHeight = 34.sp)
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Pill(L("Clear answer"), Color.White.copy(alpha = 0.16f), Color.White)
                    Pill(L("Official sources"), Color.White.copy(alpha = 0.16f), Color.White)
                    Pill(L("Gate alerts"), Color.White.copy(alpha = 0.16f), Color.White)
                }
                Button(onClick = { Nav.tab = 2 }, colors = ButtonDefaults.buttonColors(containerColor = Color.White, contentColor = Palette.blue),
                    modifier = Modifier.fillMaxWidth().padding(top = 6.dp)) {
                    Icon(Icons.Filled.Search, null); Spacer(Modifier.width(8.dp)); Text(L("Where are you going?"), fontWeight = FontWeight.SemiBold)
                }
                Text(L("Hotel, address or square: answer, route and hotel message"), color = Color.White.copy(alpha = 0.85f), fontSize = 13.sp)
            }
        }

        // La ZTL vicino a te
        item { NearYou(now) }

        item { SectionLabel("Cities") }
        item {
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(AppState.cities, key = { it.id }) { c ->
                    val active = c.zones.count { AppState.engine.isActive(it, now) }
                    val sel = c.id == AppState.cityId
                    Column(Modifier.background(if (sel) Palette.blue else MaterialTheme.colorScheme.surface, RoundedCornerShape(14.dp))
                        .clickable { AppState.selectCity(c.id) }.padding(horizontal = 14.dp, vertical = 10.dp)) {
                        Text(c.localizedName, fontWeight = FontWeight.SemiBold, color = if (sel) Color.White else MaterialTheme.colorScheme.onSurface)
                        Text(if (active == 0) L("All open") else F("%lld active", active), fontSize = 12.sp,
                            color = if (sel) Color.White.copy(alpha = 0.85f) else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f))
                    }
                }
            }
        }
        items(AppState.city.zones, key = { it.id }) { z -> ZoneRow(z, now) }

        item { SectionLabel("New to ZTLs?") }
        item {
            CardBox(Modifier.clickable { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://lr-apps609.github.io/GateLR/"))) }) {
                Column {
                    Text(L("New to ZTLs?"), fontWeight = FontWeight.SemiBold)
                    Text(L("The signs, the panels and what to do if you drove in by mistake. 1 minute."), fontSize = 14.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f))
                }
            }
        }
        item {
            Text(L("Road signs on site always win over the app."), fontSize = 12.sp, color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.55f),
                modifier = Modifier.padding(top = 4.dp, bottom = 12.dp))
        }
    }
}

@Composable
fun NearYou(now: Instant) {
    val here = Here.coordinate
    if (!Here.allowed || here == null) {
        CardBox {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.LocationOff, null, tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f))
                Spacer(Modifier.width(10.dp))
                Text(L("Allow location access to see the ZTL near you."), fontSize = 14.sp)
            }
        }
        return
    }
    val near = nearestZone(AppState.cities, here)
    if (near == null || near.third > 5_000) {
        CardBox { Text(L("No ZTL near you. GateLR covers Florence, Bologna and Milan for now."), fontSize = 14.sp) }
        return
    }
    val (_, z, d) = near
    val a = AppState.answer(z, now)
    val v = a.verdict
    Column(Modifier.fillMaxWidth().background(v.fill(), RoundedCornerShape(20.dp)).clickable { Nav.zone = z }.padding(16.dp)) {
        Text(if (d == 0.0) F("You're inside %@", z.shortName) else F("%@ is %@ away", z.shortName, Geometry.distanceText(d)),
            color = v.onFill(), fontWeight = FontWeight.SemiBold)
        Text(v.title, color = v.onFill(), fontSize = 24.sp, fontWeight = FontWeight.Bold)
        a.nextChange?.let {
            Text((if (a.gatesOn) F("Ends at %@", AppState.engine.describe(it, now)) else F("Starts at %@", AppState.engine.describe(it, now))),
                color = v.onFill().copy(alpha = 0.85f), fontSize = 13.sp)
        }
    }
}

@Composable
fun ZoneRow(z: Zone, now: Instant) {
    val a = AppState.answer(z, now)
    CardBox(Modifier.clickable { Nav.zone = z }) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(z.letter.take(2), color = Color.White, fontWeight = FontWeight.Bold, fontSize = 13.sp,
                modifier = Modifier.size(30.dp).background(Palette.kind(z.type), CircleShape).padding(top = 6.dp),
                textAlign = androidx.compose.ui.text.style.TextAlign.Center)
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(z.localizedName, fontWeight = FontWeight.SemiBold, maxLines = 1)
                Text(z.type.title + " · " + (if (a.gatesOn) L("ZTL active") else L("ZTL not active")), fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f))
            }
            VerdictPill(a.verdict)
            Icon(Icons.Filled.ChevronRight, null, tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f))
        }
    }
}
