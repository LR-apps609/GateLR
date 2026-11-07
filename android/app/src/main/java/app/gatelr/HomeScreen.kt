package app.gatelr

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.LocalParking
import androidx.compose.material.icons.filled.LocationOff
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
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
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.gatelr.core.RispostaFinale
import app.gatelr.core.Stato
import app.gatelr.core.panel
import app.gatelr.core.panelLine
import app.gatelr.core.spoken
import app.gatelr.core.subtitle
import app.gatelr.core.F
import app.gatelr.core.L
import app.gatelr.core.PermissionPlan
import app.gatelr.core.Zone
import kotlinx.coroutines.delay
import java.time.Instant

/** L'ora che scorre: le risposte si aggiornano da sole ogni 30 secondi */
@Composable
fun rememberNow(): Instant {
    var now by remember { mutableStateOf(Instant.now()) }
    LaunchedEffect(Unit) { while (true) { delay(30_000); now = Instant.now() } }
    return now
}

/** 2.0 «Adesso» (A-Adesso): la risposta per dove sei, adesso, per il tuo veicolo; la frase-contesto ora + veicolo;
 *  «Parcheggia fuori» / «Naviga comunque»; il pannello come al varco; il perché con la fonte */
@Composable
fun HomeScreen(modifier: Modifier) {
    val now = rememberNow()
    val ctx = LocalContext.current
    LazyColumn(modifier.fillMaxSize().background(MaterialTheme.colorScheme.background),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(start = 12.dp, end = 12.dp, top = 8.dp, bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)) {

        val here = Here.coordinate
        val result = if (Here.allowed && here != null) NowAnswer.compute(here, Here.course, now) else null

        if (result == null) item { LocationCard() }
        else {
            val f = result.final
            val until = NowAnswer.untilText(result.answer, now)
            item {
                AnswerBlock(f, f.subtitle(until), result.line,
                    f.spoken(until, NowAnswer.vehicleLabel(), L("now")))
            }
        }

        // La frase-contesto: ora + veicolo (tocco sul veicolo: Garage e impostazioni) + leggi il cartello
        item { ContextRow() }

        if (result != null) {
            val f = result.final
            item {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    when (f.stato) {
                        Stato.NON_ENTRARE, Stato.CONTROLLA_CARTELLO, Stato.CONDIZIONE -> {
                            PillButton(L("Park outside"), { parkOutside(ctx, f.zone, here!!) }, Modifier.weight(1f), Icons.Filled.LocalParking)
                            PillButton(L("Navigate anyway"), { Nav.whereTo = "trip" }, Modifier.weight(1f), filled = false)
                        }
                        else -> PillButton(L("Where are you going?"), { Nav.whereTo = "trip" }, Modifier.weight(1f), Icons.Filled.Search)
                    }
                }
            }
            f.panel?.let { panel ->
                item {
                    Row(Modifier.fillMaxWidth().background(cardColor, RoundedCornerShape(16.dp)).padding(horizontal = 14.dp, vertical = 12.dp),
                        verticalAlignment = Alignment.CenterVertically) {
                        LedPanel(panel)
                        Spacer(Modifier.width(14.dp))
                        Text(listOfNotNull(f.panelLine ?: L("That's how you'll see it at the gate."), result.answer?.let { changeText(it, now) })
                            .joinToString(" "), fontSize = 14.sp, color = Ink.text2, lineHeight = 19.sp)
                    }
                }
            }
            f.zone?.let { z -> item { WhyRow(z) } }
        } else item {
            PillButton(L("Where are you going?"), { Nav.whereTo = "trip" }, Modifier.fillMaxWidth(), Icons.Filled.Search)
        }

        if (GuardianService.active) item {
            Row(Modifier.fillMaxWidth().background(cardColor, RoundedCornerShape(16.dp)).padding(start = 14.dp, end = 4.dp, top = 4.dp, bottom = 4.dp),
                verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.Shield, null)
                Spacer(Modifier.width(10.dp))
                Text(GuardianService.destination?.let { F("Guardian on · to %@", it.name) } ?: L("Guardian on"), fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                TextButton(onClick = { GuardianService.stop(ctx) }, modifier = Modifier.heightIn(min = 48.dp)) { Text(L("Stop")) }
            }
        }

        // Il prossimo viaggio salvato (fino a un giorno dopo l'arrivo)
        AppState.trips.filter { it.arrival > System.currentTimeMillis() - 24 * 3_600_000 }.minByOrNull { it.arrival }?.let { t ->
            item {
                CardBox(Modifier.clickable { AppState.open(t); Nav.tab = 2 }) {
                    Column {
                        Text(L("Your next trip").uppercase(), fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Ink.text2)
                        Text(t.place.name, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                        Text(shortWhen(t.arrival), fontSize = 13.sp, color = Ink.text2)
                    }
                }
            }
        }

        // Le zone della città scelta
        item { SectionLabel("Cities") }
        item {
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(AppState.cities, key = { it.id }) { c ->
                    val active = c.zones.count { AppState.engine.isActive(it, now) }
                    val sel = c.id == AppState.cityId
                    Column(Modifier.background(if (sel) MaterialTheme.colorScheme.primary else cardColor, RoundedCornerShape(14.dp))
                        .clickable { AppState.chooseCity(c.id) }.heightIn(min = 48.dp).padding(horizontal = 14.dp, vertical = 10.dp)) {
                        Text(c.localizedName, fontWeight = FontWeight.SemiBold, color = if (sel) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurface)
                        Text(if (active == 0) L("All open") else F("%lld active", active), fontSize = 12.sp,
                            color = if (sel) MaterialTheme.colorScheme.onPrimary.copy(alpha = 0.85f) else Ink.text2)
                    }
                }
            }
        }
        items(AppState.city.zones, key = { it.id }) { z -> ZoneRow(z, now) }
        item {
            Text(L("Road signs on site always win over the app."), fontSize = 12.sp, color = Ink.text2,
                modifier = Modifier.padding(top = 4.dp, bottom = 12.dp))
        }
    }
}

/** Ora + veicolo, come una frase: «Adesso · Golf diesel Euro 5»; il veicolo apre Garage e impostazioni */
@Composable
fun ContextRow() {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
        ContextChip(Icons.Filled.Schedule, L("Now"), null)
        ContextChip(Icons.Filled.DirectionsCar, NowAnswer.vehicleLabel(), Modifier.weight(1f, fill = false)) { Nav.settings = true }
        IconButton(onClick = { Nav.tool = "sign" }, modifier = Modifier.size(48.dp).border(1.dp, Ink.line, RoundedCornerShape(12.dp))) {
            Icon(Icons.Filled.CameraAlt, L("Read the sign"))
        }
    }
}

@Composable
private fun ContextChip(icon: androidx.compose.ui.graphics.vector.ImageVector, text: String, modifier: Modifier?, onClick: (() -> Unit)? = null) {
    val base = (modifier ?: Modifier).heightIn(min = 48.dp).border(1.dp, Ink.line, RoundedCornerShape(12.dp))
    Row((if (onClick != null) base.clickable(role = Role.Button, onClickLabel = L("Garage and settings"), onClick = onClick) else base)
        .padding(horizontal = 14.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, null, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(8.dp))
        Text(text, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, maxLines = 1, modifier = Modifier.padding(vertical = 12.dp))
    }
}

/** «Perché · Comune di Firenze, letto il 23 ott 2026 ›»: apre la scheda della zona */
@Composable
fun WhyRow(z: Zone) {
    Row(Modifier.fillMaxWidth().heightIn(min = 52.dp).background(cardColor, RoundedCornerShape(16.dp))
        .clickable(role = Role.Button) { Nav.zone = z }.padding(horizontal = 14.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(Icons.Filled.Description, null, tint = Ink.text2, modifier = Modifier.size(20.dp))
        Spacer(Modifier.width(10.dp))
        Text(F("Why · %@", z.source.localizedAuthority + ", " + F("Read %@", shortDate(z.source.checkedOn))), fontSize = 14.sp, color = Ink.text2, modifier = Modifier.weight(1f))
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = Ink.text2)
    }
}

/** Senza posizione: la si chiede qui, al tocco */
@Composable
private fun LocationCard() {
    val ctx = LocalContext.current
    CardBox(Modifier.clickable(enabled = !Here.allowed, role = Role.Button) { Permissions.ask(ctx, PermissionPlan.Moment.USE_MY_LOCATION) }) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.heightIn(min = 48.dp)) {
            Icon(Icons.Filled.LocationOff, null, tint = Ink.text2)
            Spacer(Modifier.width(10.dp))
            Text(L("Allow location access to see the ZTL near you."), fontSize = 15.sp, modifier = Modifier.weight(1f))
            if (!Here.allowed) Text(L("Use my location"), fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
        }
    }
}

/** «Parcheggia fuori»: i parcheggi vicino alla zona nell'app di mappe */
fun parkOutside(ctx: android.content.Context, zone: Zone?, here: app.gatelr.core.Coordinate) {
    val c = zone?.let { app.gatelr.core.ThreatEvaluator.nearest(it.perimeter, here).first } ?: here
    runCatching { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("geo:${c.lat},${c.lon}?q=" + Uri.encode(L("Parking"))))) }
}

@Composable
fun ZoneRow(z: Zone, now: Instant) {
    val a = AppState.answer(z, now)
    val city = AppState.cityOf(z)
    val f = RispostaFinale.forZone(a, z, city?.status, city)
    CardBox(Modifier.clickable { Nav.zone = z }) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.heightIn(min = 48.dp)) {
            Text(z.letter.take(2), color = Color.White, fontWeight = FontWeight.Bold, fontSize = 13.sp,
                modifier = Modifier.size(30.dp).background(Palette.kind(z.type), CircleShape).padding(top = 6.dp),
                textAlign = androidx.compose.ui.text.style.TextAlign.Center)
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(z.localizedName, fontWeight = FontWeight.SemiBold, maxLines = 2)
                Text(z.type.title + " · " + (if (a.gatesOn) L("ZTL active") else L("ZTL not active")), fontSize = 12.sp, color = Ink.text2)
            }
            AnswerPill(f)
            Icon(Icons.Filled.ChevronRight, null, tint = Ink.text2)
        }
    }
}
