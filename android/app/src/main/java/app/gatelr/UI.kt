package app.gatelr

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.runtime.remember
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.PriorityHigh
import androidx.compose.material.icons.filled.QuestionMark
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.TextButton
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.gatelr.core.Answer
import app.gatelr.core.L
import app.gatelr.core.Verdict
import app.gatelr.core.ZoneKind

/** Gli stessi colori dell'app iPhone (Sources/Theme.swift): segnaletica italiana e famiglia LR */
object Palette {
    val red = Color(0xFFC1272D); val blue = Color(0xFF1F4E9E); val green = Color(0xFF2B7A47)
    val amber = Color(0xFF8A5A00); val amberSoft = Color(0xFFFBECC8); val amberInk = Color(0xFF5C3C00)
    val greenSoft = Color(0xFFDCEFE2); val greenInk = Color(0xFF22653A)
    val redSoft = Color(0xFFF8DADB); val redInk = Color(0xFF9E1F25)
    val ground = Color(0xFFF3F4F2); val card = Color.White; val ink = Color(0xFF1B2128); val muted = Color(0xFF5D6670)
    val groundDark = Color(0xFF0F1318); val cardDark = Color(0xFF1A2027); val inkDark = Color(0xFFE8ECEF)
    val brass = Color(0xFFA97E3F)

    fun kind(k: ZoneKind): Color = when (k) {
        ZoneKind.RESTRICTED -> red; ZoneKind.PASS -> Color(0xFFD99A00); ZoneKind.GREEN -> Color(0xFF0FA34A)
    }
}

@Composable
fun GateTheme(content: @Composable () -> Unit) {
    val dark = isSystemInDarkTheme()
    val scheme = if (dark) darkColorScheme(primary = Color(0xFF8CB0EE), background = Palette.groundDark, surface = Palette.cardDark,
        onBackground = Palette.inkDark, onSurface = Palette.inkDark, error = Color(0xFFEF5B55))
    else lightColorScheme(primary = Palette.blue, background = Palette.ground, surface = Palette.card,
        onBackground = Palette.ink, onSurface = Palette.ink, error = Palette.red)
    MaterialTheme(colorScheme = scheme, content = content)
}

// 1.20.0: «non sicuro» (dati vecchi, festivo non confermato, fonte non ufficiale) è giallo con il «?», come sull'iPhone; il
// grigio dice solo «ZTL non attiva»
fun Verdict.fill(): Color = when (this) {
    is Verdict.Yes -> Palette.green; is Verdict.No -> Palette.red
    is Verdict.Conditional, is Verdict.Unsure -> Palette.amberSoft
}
fun Verdict.onFill(): Color = when (this) {
    is Verdict.Yes, is Verdict.No -> Color.White; is Verdict.Conditional, is Verdict.Unsure -> Palette.amberInk
}
fun Verdict.pillFill(): Color = when (this) {
    is Verdict.Yes -> Palette.greenSoft; is Verdict.No -> Palette.redSoft; is Verdict.Conditional, is Verdict.Unsure -> Palette.amberSoft
}
fun Verdict.pillInk(): Color = when (this) {
    is Verdict.Yes -> Palette.greenInk; is Verdict.No -> Palette.redInk; is Verdict.Conditional, is Verdict.Unsure -> Palette.amberInk
}

/** 1.20.0: l'avviso «Fonte non ufficiale» sopra le risposte di una zona con regole solo da fonti non ufficiali (come l'iPhone) */
@Composable
fun UnofficialNote(zone: app.gatelr.core.Zone, hedgedYes: Boolean = false) {
    if (!zone.isUnofficial) return
    Column(Modifier.fillMaxWidth().background(Palette.amberSoft, RoundedCornerShape(14.dp)).padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(L("Unofficial source: always check the sign at the gate"), color = Palette.amberInk, fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
        if (hedgedYes) Text(L("Probably yes · unofficial source"), color = Palette.amberInk, fontSize = 13.sp)
        zone.source.unofficialSource?.let { Text(app.gatelr.core.F("Data from %@", it.name), color = Palette.amberInk, fontSize = 13.sp) }
    }
}

@Composable
fun Pill(text: String, fill: Color, ink: Color) {
    Text(text, color = ink, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, maxLines = 1,
        modifier = Modifier.background(fill, RoundedCornerShape(50)).padding(horizontal = 9.dp, vertical = 4.dp))
}

@Composable
/** La risposta in breve con il titolo fisso (1.20.3); da fonte non ufficiale un «sì» è «Controlla il cartello», giallo */
fun VerdictPill(v: Verdict, unofficial: Boolean = false) = v.shown(unofficial).let { look -> Pill(v.word(unofficial).title, look.pillFill(), look.pillInk()) }

/** 1.19.5: la ricerca non ha avuto risposta (rete): lo si dice e si può riprovare, invece di «Nessun risultato» */
@Composable
fun SearchRetry(onRetry: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(top = 4.dp).background(MaterialTheme.colorScheme.surface, RoundedCornerShape(14.dp)).padding(start = 12.dp, end = 4.dp),
        verticalAlignment = Alignment.CenterVertically) {
        Text(L("Search isn't working right now. Check your connection."), fontSize = 14.sp, modifier = Modifier.weight(1f).padding(vertical = 10.dp),
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.8f))
        TextButton(onClick = onRetry) { Text(L("Try again"), fontWeight = FontWeight.SemiBold) }
    }
}

@Composable
fun SectionLabel(text: String) {
    Text(L(text).uppercase(), fontSize = 13.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.sp,
        color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f), modifier = Modifier.padding(top = 8.dp, bottom = 4.dp))
}

@Composable
fun CardBox(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Surface(shape = RoundedCornerShape(16.dp), color = MaterialTheme.colorScheme.surface, tonalElevation = 1.dp,
        modifier = modifier.fillMaxWidth()) { Box(Modifier.padding(14.dp)) { content() } }
}

/** Il riquadro grande con la risposta */
@Composable
fun VerdictCard(answer: Answer, heading: String, onWhy: (() -> Unit)? = null, title: String? = null) {
    val v = answer.verdict
    Column(
        Modifier.fillMaxWidth().background(v.fill(), RoundedCornerShape(26.dp)).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(heading.uppercase(), color = v.onFill(), fontSize = 13.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.sp, modifier = Modifier.weight(1f))
            Pill(if (answer.gatesOn) L("ZTL active") else L("ZTL not active"), v.onFill().copy(alpha = 0.16f), v.onFill())
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            val icon = when (v) { is Verdict.Yes -> Icons.Filled.Check; is Verdict.No -> Icons.Filled.Close; is Verdict.Conditional -> Icons.Filled.PriorityHigh; is Verdict.Unsure -> Icons.Filled.QuestionMark }
            Box(Modifier.size(56.dp).background(if (v is Verdict.Yes || v is Verdict.No) Color.White else v.onFill(), CircleShape), contentAlignment = Alignment.Center) {
                Icon(icon, null, tint = v.fill(), modifier = Modifier.size(30.dp))
            }
            Spacer(Modifier.width(14.dp))
            Text(title ?: v.title, color = v.onFill(), fontSize = 30.sp, fontWeight = FontWeight.Bold, lineHeight = 32.sp)
        }
        Text(v.detail, color = v.onFill(), fontSize = 16.sp)
        if (onWhy != null) {
            Text(L("Why?") + " ›", color = v.onFill(), fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(top = 4.dp).clickableNoRipple(onWhy))
        }
    }
}

@Composable
fun Modifier.clickableNoRipple(onClick: () -> Unit): Modifier =
    clickable(interactionSource = remember { MutableInteractionSource() }, indication = null, onClick = onClick)

/** «Finisce alle 16:00» oggi, «Finisce domani alle 7:30» negli altri giorni */
fun changeText(a: Answer, now: java.time.Instant): String? {
    val n = a.nextChange ?: return null
    val d = n.atZone(app.gatelr.core.RuleEngine.ROME); val r = now.atZone(app.gatelr.core.RuleEngine.ROME)
    if (d.toLocalDate() == r.toLocalDate()) {
        val t = String.format("%d:%02d", d.hour, d.minute)
        return if (a.gatesOn) app.gatelr.core.F("Ends at %@", t) else app.gatelr.core.F("Starts at %@", t)
    }
    val w = AppState.engine.describe(n, now)
    return if (a.gatesOn) app.gatelr.core.F("Ends %@", w) else app.gatelr.core.F("Starts %@", w)
}

/** «2026-10-23T…» → «23 ott 2026» nella lingua dell'app */
fun shortDate(iso: String): String = runCatching {
    java.time.LocalDate.parse(iso.take(10)).format(java.time.format.DateTimeFormatter.ofLocalizedDate(java.time.format.FormatStyle.MEDIUM)
        .withLocale(java.util.Locale.forLanguageTag(app.gatelr.core.Strings.language)))
}.getOrDefault(iso.take(10))

/** 1.20.2: la conferma prima di cancellare (veicolo, permesso, viaggio, diario): «Elimina» in rosso o «Annulla» */
@Composable
fun ConfirmDelete(what: String, onConfirm: () -> Unit, onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(app.gatelr.core.GarageEdit.question(what)) },
        text = { Text(app.gatelr.core.GarageEdit.detail(what)) },
        confirmButton = { TextButton(onClick = { onConfirm(); onDismiss() }) { Text(L("Delete"), color = MaterialTheme.colorScheme.error, fontWeight = FontWeight.SemiBold) } },
        dismissButton = { TextButton(onClick = onDismiss) { Text(L("Cancel")) } }
    )
}
