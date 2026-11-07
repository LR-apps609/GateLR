package app.gatelr

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ExitToApp
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.PowerSettingsNew
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.gatelr.core.AnswerShape
import app.gatelr.core.AnswerTone
import app.gatelr.core.FinalAnswer

// 2.0: il componente «Risposta» (S-Risposta): una forma, una parola, un colore. Lo stesso blocco su Adesso, Mappa,
// Viaggio e scheda della zona; uguale di giorno e di notte.

/** Il colore pieno della risposta (S-Colori, AA): neutro = nessun pieno, solo il contorno tratteggiato */
fun AnswerTone.fill(): Color = when (this) {
    AnswerTone.RED -> Palette.red; AnswerTone.GREEN -> Palette.green; AnswerTone.AMBER -> Palette.amberFill
    AnswerTone.GREY -> Palette.off; AnswerTone.NEUTRAL -> Color.Transparent
}

/** Il testo sul pieno: bianco, inchiostro scuro sul giallo; sul neutro il testo del tema */
@Composable
fun AnswerTone.onFill(): Color = when (this) {
    AnswerTone.AMBER -> Palette.night
    AnswerTone.NEUTRAL -> MaterialTheme.colorScheme.onBackground
    else -> Color.White
}

/** La forma della risposta, disegnata: si riconosce anche senza colori */
@Composable
fun AnswerMark(shape: AnswerShape, tone: AnswerTone, size: Dp = 46.dp) {
    val ink = tone.onFill()
    val disc = if (tone == AnswerTone.NEUTRAL) Color.Transparent else ink
    val glyph = if (tone == AnswerTone.NEUTRAL) ink else tone.fill()
    Box(Modifier.size(size).drawBehind {
        if (shape == AnswerShape.QUESTION_DASHED) drawCircle(ink, radius = this.size.minDimension / 2 - 2.dp.toPx(),
            style = Stroke(width = 2.5.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(7.dp.toPx(), 5.dp.toPx()))))
        else drawCircle(disc)
        if (shape == AnswerShape.NO_ENTRY) {
            val w = this.size.width * 0.6f; val h = this.size.height * 0.2f
            drawRoundRect(glyph, topLeft = androidx.compose.ui.geometry.Offset((this.size.width - w) / 2, (this.size.height - h) / 2),
                size = androidx.compose.ui.geometry.Size(w, h), cornerRadius = CornerRadius(2.dp.toPx()))
        }
    }, contentAlignment = Alignment.Center) {
        val icon: ImageVector? = when (shape) {
            AnswerShape.CHECK -> Icons.Filled.Check
            AnswerShape.OFF -> Icons.Filled.PowerSettingsNew
            AnswerShape.OUTSIDE -> Icons.AutoMirrored.Filled.ExitToApp
            else -> null
        }
        val symbol = when (shape) { AnswerShape.EXCLAMATION -> "!"; AnswerShape.QUESTION, AnswerShape.QUESTION_DASHED -> "?"; else -> null }
        if (icon != null) Icon(icon, null, tint = glyph, modifier = Modifier.size(size * 0.62f))
        if (symbol != null) Text(symbol, color = glyph, fontFamily = Titillium, fontWeight = FontWeight.Black, fontSize = (size.value * 0.6f).sp)
    }
}

enum class AnswerSize { L, M }

/**
 * Il blocco della risposta. [spoken] è quello che legge TalkBack: un solo elemento, letto per primo
 * («Non entrare. Firenze, Settore B, fino alle 20:00. Per Golf diesel Euro 5, adesso.»)
 */
@Composable
fun AnswerBlock(f: FinalAnswer, subtitle: String?, line: String?, spoken: String, modifier: Modifier = Modifier, size: AnswerSize = AnswerSize.L) {
    val tone = f.tone
    val ink = tone.onFill()
    val shape = RoundedCornerShape(28.dp)
    val base = modifier.fillMaxWidth()
        .clearAndSetSemantics { contentDescription = spoken; heading() }
    val box = if (tone == AnswerTone.NEUTRAL) base.drawBehind {
        drawRoundRect(ink.copy(alpha = 0.7f), cornerRadius = CornerRadius(28.dp.toPx()),
            style = Stroke(width = 2.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(8.dp.toPx(), 6.dp.toPx()))))
    } else base.background(tone.fill(), shape)
    Column(box.padding(start = 20.dp, end = 20.dp, top = 18.dp, bottom = 20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            AnswerMark(f.shape, tone, if (size == AnswerSize.L) 46.dp else 38.dp)
            Spacer(Modifier.width(14.dp))
            Text(f.title, color = ink, fontFamily = Titillium, fontWeight = FontWeight.Black,
                fontSize = if (size == AnswerSize.L) 38.sp else 30.sp, lineHeight = if (size == AnswerSize.L) 40.sp else 32.sp)
        }
        val sub = listOfNotNull(f.reason?.text, subtitle).joinToString(" · ")
        if (sub.isNotEmpty()) Text(sub, color = ink, fontFamily = Titillium, fontWeight = FontWeight.Bold,
            fontSize = if (size == AnswerSize.L) 20.sp else 17.sp, lineHeight = 25.sp)
        line?.takeIf { it.isNotBlank() }?.let { Text(it, color = ink, fontWeight = FontWeight.SemiBold, fontSize = 16.sp, lineHeight = 21.sp) }
    }
}

/** La pillola piccola (taglia S): forma + parola + colore, per elenchi e percorsi */
@Composable
fun AnswerPill(f: FinalAnswer) {
    val tone = f.tone
    val m = if (tone == AnswerTone.NEUTRAL) Modifier.border(1.dp, tone.onFill().copy(alpha = 0.6f), RoundedCornerShape(50))
    else Modifier.background(tone.fill(), RoundedCornerShape(50))
    Row(m.padding(start = 4.dp, end = 10.dp, top = 3.dp, bottom = 3.dp), verticalAlignment = Alignment.CenterVertically) {
        AnswerMark(f.shape, tone, 20.dp)
        Spacer(Modifier.width(6.dp))
        Text(f.word, color = tone.onFill(), fontSize = 13.sp, fontWeight = FontWeight.SemiBold, maxLines = 1)
    }
}

/** Il pannello LED come in strada: luce neutra bianco caldo, sempre in italiano, mai rosso o verde */
@Composable
fun LedPanel(text: String) {
    Box(Modifier.background(Palette.ledGround, RoundedCornerShape(10.dp)).border(3.dp, Ink.line, RoundedCornerShape(10.dp))
        .padding(horizontal = 14.dp, vertical = 8.dp), contentAlignment = Alignment.Center) {
        Text(text, color = Palette.led, fontFamily = LedFont, fontSize = 16.sp, letterSpacing = 1.9.sp, maxLines = 1)
    }
}

/** Il pulsante pillola alto 56 (M3): pieno chiaro su Notte, scuro su Giorno; mai rosso */
@Composable
fun PillButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier, icon: ImageVector? = null, filled: Boolean = true) {
    val content: @Composable () -> Unit = {
        if (icon != null) { Icon(icon, null, modifier = Modifier.size(20.dp)); Spacer(Modifier.width(8.dp)) }
        Text(text, fontSize = 16.sp, fontWeight = FontWeight.SemiBold, maxLines = 2)
    }
    if (filled) Button(onClick = onClick, modifier = modifier.heightIn(min = 56.dp), shape = RoundedCornerShape(50),
        colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary, contentColor = MaterialTheme.colorScheme.onPrimary)) { content() }
    else OutlinedButton(onClick = onClick, modifier = modifier.heightIn(min = 56.dp), shape = RoundedCornerShape(50)) { content() }
}
