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
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
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

/** 2.0: i colori veri dai token di S-Colori (direzione C). I colori della risposta sono semantici e uguali di giorno e di
 *  notte; niente colore dinamico per la risposta e le superfici */
object Palette {
    // Risposta, uguale di giorno e di notte
    val red = Color(0xFFC62A24); val green = Color(0xFF147A3C); val amberFill = Color(0xFFFFC629); val off = Color(0xFF5E6982)
    /** Il giallo come testo su fondo chiaro (al posto del giallo su bianco) */
    val amber = Color(0xFF8A6100)
    val amberSoft = Color(0xFFFFF1C2); val amberInk = Color(0xFF5C4100)
    val greenSoft = Color(0xFFD9F0E2); val greenInk = Color(0xFF0F5E2E)
    val redSoft = Color(0xFFF9DCDA); val redInk = Color(0xFFB3261E)
    // Notte
    val night = Color(0xFF0B1530); val nightSurface = Color(0xFF142049); val nightSurface2 = Color(0xFF1B2A5C); val nightLine = Color(0xFF2A3A70)
    val nightText = Color(0xFFF2F4FA); val nightText2 = Color(0xFFB4BEDB); val nightText3 = Color(0xFF8E9AC0)
    // Giorno
    val day = Color(0xFFF4F6FA); val daySurface = Color.White; val daySurface2 = Color(0xFFE9EDF5); val dayLine = Color(0xFFD5DAE6)
    val dayText = Color(0xFF0B1530); val dayText2 = Color(0xFF4A5675)
    /** Il rosso del marchio: solo nel logo, mai sui pulsanti */
    val brand = Color(0xFFE5322D)
    /** Pannello LED: luce neutra bianco caldo, non contraddice mai la risposta */
    val led = Color(0xFFFFE7B0); val ledGround = Color(0xFF050505)
    /** Il segno «P» dei parcheggi, come i cartelli */
    val parking = Color(0xFF0A4FB8)
    // Nomi di prima, sui token nuovi
    val blue = night; val ground = day; val card = daySurface; val ink = dayText; val muted = dayText2
    val groundDark = night; val cardDark = nightSurface; val inkDark = nightText; val brass = Color(0xFF8A6100)

    fun kind(k: ZoneKind): Color = when (k) {
        ZoneKind.RESTRICTED -> red; ZoneKind.PASS -> Color(0xFFD99A00); ZoneKind.GREEN -> Color(0xFF0FA34A)
    }
}

/** Il tema è Notte? (Giorno e Notte automatici, dal telefono) */
val LocalNight = staticCompositionLocalOf { false }

/** Gli inchiostri che cambiano tra Giorno e Notte (S-Colori: parola su fondo, testo secondario, linea) */
object Ink {
    val no: Color @Composable @ReadOnlyComposable get() = if (LocalNight.current) Color(0xFFFF6B5E) else Color(0xFFB3261E)
    val yes: Color @Composable @ReadOnlyComposable get() = if (LocalNight.current) Color(0xFF4FD18B) else Color(0xFF147A3C)
    val amber: Color @Composable @ReadOnlyComposable get() = if (LocalNight.current) Palette.amberFill else Palette.amber
    val text2: Color @Composable @ReadOnlyComposable get() = if (LocalNight.current) Palette.nightText2 else Palette.dayText2
    val line: Color @Composable @ReadOnlyComposable get() = if (LocalNight.current) Palette.nightLine else Palette.dayLine
    val surface2: Color @Composable @ReadOnlyComposable get() = if (LocalNight.current) Palette.nightSurface2 else Palette.daySurface2
}

/** Titillium per i titoli (famiglia LR), il carattere di sistema per il corpo; DotGothic per il pannello LED */
val Titillium = FontFamily(
    Font(R.font.titillium_semibold, FontWeight.SemiBold),
    Font(R.font.titillium_bold, FontWeight.Bold),
    Font(R.font.titillium_black, FontWeight.Black),
)
val LedFont = FontFamily(Font(R.font.dotgothic16, FontWeight.Normal))

@Composable
fun GateTheme(content: @Composable () -> Unit) {
    val night = isSystemInDarkTheme()
    val scheme = if (night) darkColorScheme(
        primary = Palette.nightText, onPrimary = Palette.night,
        primaryContainer = Palette.nightSurface2, onPrimaryContainer = Palette.nightText,
        secondary = Palette.nightText2, onSecondary = Palette.night,
        secondaryContainer = Palette.nightSurface2, onSecondaryContainer = Palette.nightText,
        background = Palette.night, onBackground = Palette.nightText,
        surface = Palette.night, onSurface = Palette.nightText,
        surfaceVariant = Palette.nightSurface2, onSurfaceVariant = Palette.nightText2,
        surfaceTint = Color.Transparent, outline = Palette.nightText2, outlineVariant = Palette.nightLine,
        error = Color(0xFFFF6B5E), onError = Palette.night,
        surfaceContainerLowest = Palette.night, surfaceContainerLow = Palette.nightSurface, surfaceContainer = Palette.nightSurface,
        surfaceContainerHigh = Palette.nightSurface, surfaceContainerHighest = Palette.nightSurface2,
        surfaceBright = Palette.nightSurface2, surfaceDim = Palette.night,
    ) else lightColorScheme(
        primary = Palette.dayText, onPrimary = Color.White,
        primaryContainer = Palette.daySurface2, onPrimaryContainer = Palette.dayText,
        secondary = Palette.dayText2, onSecondary = Color.White,
        secondaryContainer = Palette.daySurface2, onSecondaryContainer = Palette.dayText,
        background = Palette.day, onBackground = Palette.dayText,
        surface = Palette.day, onSurface = Palette.dayText,
        surfaceVariant = Palette.daySurface2, onSurfaceVariant = Palette.dayText2,
        surfaceTint = Color.Transparent, outline = Palette.dayText2, outlineVariant = Palette.dayLine,
        error = Color(0xFFB3261E), onError = Color.White,
        surfaceContainerLowest = Color.White, surfaceContainerLow = Color.White, surfaceContainer = Color.White,
        surfaceContainerHigh = Color.White, surfaceContainerHighest = Palette.daySurface2,
        surfaceBright = Color.White, surfaceDim = Palette.daySurface2,
    )
    val base = Typography()
    fun TextStyle.title() = copy(fontFamily = Titillium, fontWeight = FontWeight.Bold)
    val type = base.copy(
        displayLarge = base.displayLarge.title(), displayMedium = base.displayMedium.title(), displaySmall = base.displaySmall.title(),
        headlineLarge = base.headlineLarge.title(), headlineMedium = base.headlineMedium.title(), headlineSmall = base.headlineSmall.title(),
        titleLarge = base.titleLarge.title(),
    )
    CompositionLocalProvider(LocalNight provides night) {
        MaterialTheme(colorScheme = scheme, typography = type, content = content)
    }
}

/** Le superfici delle schede (card): bianco di giorno, #142049 di notte */
val cardColor: Color @Composable @ReadOnlyComposable get() = if (LocalNight.current) Palette.nightSurface else Palette.daySurface

// 1.20.0: «non sicuro» (dati vecchi, festivo non confermato, fonte non ufficiale) è giallo con il «?», come sull'iPhone; il
// grigio dice solo «ZTL non attiva»
fun Verdict.fill(): Color = when (this) {
    is Verdict.Yes -> Palette.green; is Verdict.No -> Palette.red
    is Verdict.Conditional, is Verdict.Unsure -> Palette.amberFill
}
fun Verdict.onFill(): Color = when (this) {
    is Verdict.Yes, is Verdict.No -> Color.White; is Verdict.Conditional, is Verdict.Unsure -> Palette.night
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
    Row(Modifier.fillMaxWidth().padding(top = 4.dp).background(cardColor, RoundedCornerShape(14.dp)).padding(start = 12.dp, end = 4.dp),
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
    Surface(shape = RoundedCornerShape(16.dp), color = cardColor, tonalElevation = 0.dp,
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
