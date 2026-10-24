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
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
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

fun Verdict.fill(): Color = when (this) {
    is Verdict.Yes -> Palette.green; is Verdict.No -> Palette.red
    is Verdict.Conditional -> Palette.amberSoft; is Verdict.Unsure -> Color(0xFFE3E6E8)
}
fun Verdict.onFill(): Color = when (this) {
    is Verdict.Yes, is Verdict.No -> Color.White; is Verdict.Conditional -> Palette.amberInk; is Verdict.Unsure -> Palette.ink
}
fun Verdict.pillFill(): Color = when (this) {
    is Verdict.Yes -> Palette.greenSoft; is Verdict.No -> Palette.redSoft; is Verdict.Conditional -> Palette.amberSoft; is Verdict.Unsure -> Color(0xFFE3E6E8)
}
fun Verdict.pillInk(): Color = when (this) {
    is Verdict.Yes -> Palette.greenInk; is Verdict.No -> Palette.redInk; is Verdict.Conditional -> Palette.amberInk; is Verdict.Unsure -> Palette.ink
}

@Composable
fun Pill(text: String, fill: Color, ink: Color) {
    Text(text, color = ink, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, maxLines = 1,
        modifier = Modifier.background(fill, RoundedCornerShape(50)).padding(horizontal = 9.dp, vertical = 4.dp))
}

@Composable
fun VerdictPill(v: Verdict) = Pill(v.short, v.pillFill(), v.pillInk())

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
fun VerdictCard(answer: Answer, heading: String, onWhy: (() -> Unit)? = null) {
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
            Text(v.title, color = v.onFill(), fontSize = 30.sp, fontWeight = FontWeight.Bold, lineHeight = 32.sp)
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
