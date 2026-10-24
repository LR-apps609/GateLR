package app.gatelr

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.RadioButtonUnchecked
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.gatelr.core.CarCatalog
import app.gatelr.core.F
import app.gatelr.core.Fuel
import app.gatelr.core.L
import app.gatelr.core.Permit
import app.gatelr.core.Vehicle
import app.gatelr.core.carAdvice
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale

@Composable
fun GarageScreen(modifier: Modifier) {
    var editing by remember { mutableStateOf<Vehicle?>(null) }
    var adding by remember { mutableStateOf(false) }
    val now = rememberNow()
    LazyColumn(modifier.fillMaxSize().background(MaterialTheme.colorScheme.background), contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)) {
        item { Text(L("Garage"), fontSize = 28.sp, fontWeight = FontWeight.Bold) }
        item { SectionLabel("Your cars") }
        items(AppState.vehicles, key = { it.id }) { v ->
            val active = v.id == AppState.vehicle.id
            CardBox(Modifier.clickable { AppState.activeVehicleId = v.id; AppState.save() }) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(if (active) Icons.Filled.CheckCircle else Icons.Filled.RadioButtonUnchecked, null,
                        tint = if (active) Palette.green else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f))
                    Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f)) {
                        Text(v.name, fontWeight = FontWeight.SemiBold)
                        Text(listOf(v.model, v.fuel.label, "Euro ${v.euro}", v.plate).filter { it.isNotBlank() }.joinToString(" · "), fontSize = 13.sp,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.65f))
                    }
                    TextButton(onClick = { editing = v }) { Text(L("Edit")) }
                }
            }
        }
        item { OutlinedButton(onClick = { adding = true }) { Icon(Icons.Filled.Add, null); Spacer(Modifier.width(6.dp)); Text(L("Add a car")) } }

        val advice = carAdvice(AppState.vehicle, AppState.cities, now)
        if (advice.isNotEmpty()) {
            item { SectionLabel("Where your car can go") }
            items(advice) { a ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Pill(if (a.ok) "✓" else "✕", if (a.ok) Palette.greenSoft else Palette.redSoft, if (a.ok) Palette.greenInk else Palette.redInk)
                    Spacer(Modifier.width(8.dp))
                    Text("${a.city} · ${a.zone}: ${readableDates(a.text)}", fontSize = 14.sp)
                }
            }
        }

        item { SectionLabel("Permits") }
        if (AppState.permits.isEmpty()) item {
            Text(L("No permits yet. A hotel registration you confirm in Trip shows up here."), fontSize = 14.sp,
                color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f))
        }
        items(AppState.permits, key = { it.id }) { p -> PermitRow(p) }
    }
    if (adding) VehicleDialog(null) { adding = false }
    editing?.let { v -> VehicleDialog(v) { editing = null } }
}

@Composable
private fun PermitRow(p: Permit) {
    val f = DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM).withLocale(Locale.getDefault())
    fun d(ms: Long) = Instant.ofEpochMilli(ms).atZone(ZoneId.systemDefault()).format(f)
    val city = AppState.cities.firstOrNull { it.id == p.cityId }?.localizedName ?: p.cityId
    CardBox {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text((if (p.kind == Permit.Kind.HOTEL) L("Hotel registration") else L("Permit")) + " · " + city, fontWeight = FontWeight.SemiBold)
                Text("${d(p.from)} – ${d(p.to)}", fontSize = 13.sp)
                if (p.status == Permit.Status.CONFIRMED) Pill(L("Confirmed"), Palette.greenSoft, Palette.greenInk) else Pill(L("Waiting"), Palette.amberSoft, Palette.amberInk)
            }
            IconButton(onClick = { AppState.permits = AppState.permits - p; AppState.save() }) { Icon(Icons.Filled.Delete, L("Delete")) }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun VehicleDialog(v: Vehicle?, close: () -> Unit) {
    var name by remember { mutableStateOf(v?.name ?: L("My car")) }
    var model by remember { mutableStateOf(v?.model ?: "") }
    var plate by remember { mutableStateOf(v?.plate ?: "") }
    var fuel by remember { mutableStateOf(v?.fuel ?: Fuel.PETROL) }
    var euro by remember { mutableStateOf(v?.euro ?: 6) }
    var year by remember { mutableStateOf(v?.year?.toString() ?: "") }
    var rental by remember { mutableStateOf(v?.isRental ?: false) }
    AlertDialog(onDismissRequest = close,
        title = { Text(if (v == null) L("Add a car") else L("Edit")) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(name, { name = it }, label = { Text(L("Name")) }, singleLine = true)
                OutlinedTextField(model, { model = it }, label = { Text(L("Model")) }, singleLine = true)
                OutlinedTextField(plate, { plate = it.uppercase() }, label = { Text(L("Plate")) }, singleLine = true,
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Characters))
                OutlinedTextField(year, { y -> year = y.filter { it.isDigit() }.take(4); year.toIntOrNull()?.takeIf { it in 1950..2100 }?.let { euro = CarCatalog.euroForYear(it) } },
                    label = { Text(L("Year of first registration")) }, singleLine = true, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number))
                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Fuel.entries.forEach { f -> FilterChip(selected = fuel == f, onClick = { fuel = f }, label = { Text(f.label, fontSize = 12.sp) }) }
                }
                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    (0..6).forEach { e -> FilterChip(selected = euro == e, onClick = { euro = e }, label = { Text("Euro $e", fontSize = 12.sp) }) }
                }
                Text(L("Check it on the registration document, field V.9."), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(L("Rental car"), modifier = Modifier.weight(1f)); Switch(checked = rental, onCheckedChange = { rental = it })
                }
            }
        },
        confirmButton = {
            TextButton(onClick = {
                val nv = Vehicle(id = v?.id ?: java.util.UUID.randomUUID().toString(), name = name.ifBlank { L("My car") }, model = model, fuel = fuel, euro = euro,
                    plate = plate.trim(), isRental = rental, make = v?.make, year = year.toIntOrNull())
                AppState.vehicles = if (v == null) AppState.vehicles + nv else AppState.vehicles.map { if (it.id == nv.id) nv else it }
                if (v == null) AppState.activeVehicleId = nv.id
                AppState.save(); close()
            }) { Text(L("Save")) }
        },
        dismissButton = {
            Row {
                if (v != null && AppState.vehicles.size > 1) TextButton(onClick = {
                    AppState.vehicles = AppState.vehicles.filter { it.id != v.id }
                    if (AppState.activeVehicleId == v.id) AppState.activeVehicleId = AppState.vehicles.first().id
                    AppState.save(); close()
                }) { Text(L("Delete"), color = MaterialTheme.colorScheme.error) }
                TextButton(onClick = close) { Text(L("Cancel")) }
            }
        })
}

/** «Può entrare fino al 2026-12-01» → «Può entrare fino al 30 nov 2026»: il divieto vale dal giorno indicato, l'ultimo giorno buono è quello prima */
private fun readableDates(text: String): String = Regex("""\d{4}-\d{2}-\d{2}""").replace(text) { m ->
    runCatching { shortDate(java.time.LocalDate.parse(m.value).minusDays(1).toString()) }.getOrDefault(m.value)
}
