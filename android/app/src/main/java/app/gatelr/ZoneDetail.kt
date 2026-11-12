package app.gatelr

import app.gatelr.core.detail
import app.gatelr.core.panel
import app.gatelr.core.panelLine
import app.gatelr.core.spoken
import app.gatelr.core.subtitle
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.ui.Alignment
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
import app.gatelr.core.DataTrust
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
    // Le date della stagione in corso o della prossima: con le regole («primo giovedì di aprile») cambiano ogni anno
    val when_ = season?.let { s -> val (a, b) = s.shown(java.time.LocalDate.now(app.gatelr.core.RuleEngine.ROME))
        " (${a.dayOfMonth}/${a.monthValue}–${b.dayOfMonth}/${b.monthValue})" } ?: ""
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
        Text(z.localizedName, style = MaterialTheme.typography.headlineSmall)
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Pill(z.type.title, Palette.kind(z.type).copy(alpha = 0.18f), MaterialTheme.colorScheme.onSurface)
            AppState.cityOf(z)?.let { Pill(it.localizedName, MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f), MaterialTheme.colorScheme.onSurface) }
        }
        // 1.20.0: zona da fonti non ufficiali (Salerno, Cagliari…): l'avviso sopra la risposta, mai verde (come l'iPhone)
        UnofficialNote(z, hedgedYes = z.isUnofficial && AppState.rawAnswer(z, now).verdict is app.gatelr.core.Verdict.Yes)
        // 2.0: lo stesso blocco della risposta (taglia M), con il pannello come al varco
        val city = AppState.cityOf(z)
        val f = app.gatelr.core.RispostaFinale.forZone(a, z, city?.status, city)
        val until = NowAnswer.untilText(a, now)
        AnswerBlock(f, f.subtitle(until), f.detail(a), f.spoken(until, NowAnswer.vehicleLabel(), L("now")), size = AnswerSize.M)
        f.panel?.let { panel ->
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                LedPanel(panel)
                Text(f.panelLine ?: L("That's how you'll see it at the gate."), color = muted, fontSize = 14.sp)
            }
        }
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
                    Text(app.gatelr.core.Money.euro(t.price), fontSize = 22.sp, fontWeight = FontWeight.Bold)
                    Text(t.localizedHowTo, fontSize = 14.sp)
                    t.url?.let { u -> Text(L("Pay the ticket") + " ›", color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.SemiBold, modifier = Modifier.clickable { open(u) }) }
                }
            }
        }

        // 2.0.2 «Fiducia»: data dell'ultimo controllo, verifica a mano, fonte, condivisione (pagina della città), le due pagine
        TrustBox(z, AppState.cityOf(z), null)
        SectionLabel("Official sources")
        CardBox {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(z.source.localizedAuthority, fontWeight = FontWeight.SemiBold)
                z.source.quote?.let { q ->
                    Text("«$q»", fontStyle = FontStyle.Italic, fontSize = 14.sp)
                    z.source.localizedTranslation?.let { Text(it, fontSize = 13.sp, color = muted) }
                }
                // 1.20.1 «Dati»: «letto il» (quando abbiamo letto le pagine) e «verificato il» (una persona ha confermato la regola)
                Text(F("Read %@", shortDate(z.source.checkedOn)), fontSize = 12.sp, color = muted)
                val calm = AppState.engine.trust(z).let { it == DataTrust.VERIFIED || it == DataTrust.READ }
                Text(verifiedText(z), fontSize = 12.sp, color = if (calm) muted else MaterialTheme.colorScheme.onSurface,
                    fontWeight = if (calm) FontWeight.Normal else FontWeight.SemiBold)
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

/** 1.20.1 «Dati»: «Verificato il …», «Non ancora verificato: controlla il cartello» o «La pagina del Comune è cambiata» */
fun verifiedText(z: Zone): String = when (AppState.engine.trust(z)) {
    DataTrust.PAGE_CHANGED -> L("The city's page has changed: check the sign.")
    DataTrust.UNVERIFIED -> L("Not verified yet: check the sign.")
    DataTrust.READ -> L("Not verified by a person yet.")
    DataTrust.OLD -> z.source.verifiedOn?.let { F("Verified %@", shortDate(it)) + " · " + F("Last verified more than %lld days ago: check the sign.", AppState.engine.staleAfterDays) } ?: L("Not verified yet: check the sign.")
    DataTrust.VERIFIED -> F("Verified %@", shortDate(z.source.verifiedOn ?: ""))
}
