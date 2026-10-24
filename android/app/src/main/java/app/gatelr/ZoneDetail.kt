package app.gatelr

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.gatelr.core.F
import app.gatelr.core.L
import app.gatelr.core.Strings
import app.gatelr.core.TimeWindow
import app.gatelr.core.Zone
import app.gatelr.core.ZoneKind
import java.time.DayOfWeek
import java.time.format.TextStyle
import java.util.Locale

/** «Lun–Ven 7:30–20:00» dalle finestre della zona */
fun TimeWindow.text(): String {
    val loc = Locale.forLanguageTag(Strings.language)
    // 1 = domenica … 7 = sabato → lunedì per primo
    val order = listOf(2, 3, 4, 5, 6, 7, 1)
    fun name(d: Int) = DayOfWeek.of(if (d == 1) 7 else d - 1).getDisplayName(TextStyle.SHORT, loc)
    val days = order.filter { it in weekdays }
    val runs = mutableListOf<List<Int>>()
    for (d in days) {
        val last = runs.lastOrNull()
        if (last != null && order.indexOf(d) == order.indexOf(last.last()) + 1) runs[runs.size - 1] = last + d else runs += listOf(d)
    }
    val dayText = if (days.size == 7) L("Every day") else runs.joinToString(", ") { r -> if (r.size > 2) "${name(r.first())}–${name(r.last())}" else r.joinToString(", ") { name(it) } }
    fun hm(m: Int) = String.format("%d:%02d", (m / 60) % 24, m % 60)
    val hours = if (start == 0 && (end == 0 || end == 1440)) L("all day") else "${hm(start)}–${hm(end)}"
    val when_ = season?.let { s -> " (${s.fromDay}/${s.fromMonth}–${s.toDay}/${s.toMonth})" } ?: ""
    return "$dayText · $hours$when_"
}

@Composable
fun ZoneDetail(z: Zone) {
    val ctx = LocalContext.current
    val now = rememberNow()
    val a = AppState.answer(z, now)
    fun open(url: String) = runCatching { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) }
    val muted = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.65f)
    Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp).padding(bottom = 32.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(z.localizedName, fontSize = 24.sp, fontWeight = FontWeight.Bold)
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Pill(z.type.title, Palette.kind(z.type).copy(alpha = 0.18f), MaterialTheme.colorScheme.onSurface)
            AppState.cityOf(z)?.let { Pill(it.localizedName, MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f), MaterialTheme.colorScheme.onSurface) }
        }
        VerdictCard(a, AppState.vehicle.name)
        changeText(a, now)?.let { Text(it, color = muted) }
        Text(z.localizedSummary, fontSize = 15.sp)

        SectionLabel(if (z.type == ZoneKind.GREEN) "Bans" else "Hours")
        CardBox {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                z.windows.forEach { Text(it.text()) }
                if (z.freeOnHolidays == true) Text(L("Free on public holidays"), color = muted, fontSize = 13.sp)
                z.bans?.forEach { b -> Text(F("%@ up to Euro %lld: banned since %@", b.fuel.label, b.maxEuro, b.since), fontSize = 14.sp) }
            }
        }

        z.ticket?.let { t ->
            SectionLabel("Ticket")
            CardBox {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(String.format(Locale.ITALY, "€ %.2f", t.price), fontSize = 22.sp, fontWeight = FontWeight.Bold)
                    Text(t.localizedHowTo, fontSize = 14.sp)
                    t.url?.let { u -> Text(L("Pay the ticket") + " ›", color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.SemiBold, modifier = Modifier.clickable { open(u) }) }
                }
            }
        }

        SectionLabel("Official sources")
        CardBox {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(z.source.localizedAuthority, fontWeight = FontWeight.SemiBold)
                z.source.quote?.let { q ->
                    Text("«$q»", fontStyle = FontStyle.Italic, fontSize = 14.sp)
                    z.source.localizedTranslation?.let { Text(it, fontSize = 13.sp, color = muted) }
                }
                Text(F("Checked on %@", z.source.checkedOn.take(10)), fontSize = 12.sp, color = muted)
                Text(L("Official page") + " ›", color = MaterialTheme.colorScheme.primary, modifier = Modifier.clickable { open(z.source.pageURL) })
                z.source.ordinanceURL?.let { u -> Text((z.source.ordinance ?: L("Ordinance")) + " ›", color = MaterialTheme.colorScheme.primary, modifier = Modifier.clickable { open(u) }) }
                z.source.links.forEach { l -> Text(l.localizedTitle + " ›", color = MaterialTheme.colorScheme.primary, modifier = Modifier.clickable { open(l.url) }) }
            }
        }
        if (z.source.localizedPending.isNotEmpty()) {
            SectionLabel("Still to check")
            CardBox { Column { z.source.localizedPending.forEach { Text("• $it", fontSize = 14.sp) } } }
        }
        Text(L("Road signs on site always win over the app."), fontSize = 12.sp, color = muted)
    }
}
