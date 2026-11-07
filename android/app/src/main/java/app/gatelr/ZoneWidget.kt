package app.gatelr

import android.annotation.SuppressLint
import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.location.LocationManager
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.LocalSize
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.updateAll
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.semantics.contentDescription
import androidx.glance.semantics.semantics
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import app.gatelr.core.Answer
import app.gatelr.core.Forma
import app.gatelr.core.Tono
import app.gatelr.core.forma
import app.gatelr.core.place
import app.gatelr.core.reasonShort
import app.gatelr.core.spoken
import app.gatelr.core.Coordinate
import app.gatelr.core.RispostaFinale
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.launch
import java.time.Instant

/** 2.0: il widget con Glance, piccolo e medio, sulla risposta vera di «Adesso» (stesso motore e stesso valutatore):
 *  dove sei, adesso; senza posizione recente la zona scelta nell'app. Tocco → gatelr://adesso */
class GateWidget : GlanceAppWidget() {
    companion object {
        val SMALL = DpSize(110.dp, 110.dp)
        val MEDIUM = DpSize(250.dp, 110.dp)
    }

    override val sizeMode = SizeMode.Responsive(setOf(SMALL, MEDIUM))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val data = WidgetData.compute(context)
        provideContent { WidgetContent(data) }
    }
}

/** Quello che il widget mostra */
data class WidgetData(val final: RispostaFinale, val answer: Answer?, val place: String?, val until: String?, val spoken: String) {
    companion object {
        @SuppressLint("MissingPermission")
        fun compute(ctx: Context): WidgetData {
            if (!AppStateReady.ok) { AppState.init(ctx.applicationContext); AppStateReady.ok = true }
            val now = Instant.now()
            // La posizione: quella dell'app se recente, altrimenti l'ultima nota del telefono (meno di 15 minuti)
            val here: Coordinate? = Here.coordinate?.takeIf { System.currentTimeMillis() - Here.at < 15 * 60_000 } ?: runCatching {
                if (!GuardianService.canStart(ctx)) null else {
                    val lm = ctx.getSystemService(Context.LOCATION_SERVICE) as LocationManager
                    listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER).mapNotNull { runCatching { lm.getLastKnownLocation(it) }.getOrNull() }
                        .filter { System.currentTimeMillis() - it.time < 15 * 60_000 }.maxByOrNull { it.time }
                        ?.let { Coordinate(it.latitude, it.longitude) }
                }
            }.getOrNull()
            val (f, a) = if (here != null) NowAnswer.compute(here, null, now).let { it.final to it.answer }
            else AppState.zone.let { z -> val ans = AppState.answer(z, now); AppState.cityOf(z).let { city -> RispostaFinale.forZone(ans, z, city?.status, city) } to ans }
            val until = NowAnswer.untilText(a, now)
            return WidgetData(f, a, f.place, until, f.spoken(until, null, null))
        }
    }
}

private fun Tono.widgetFill(): Color = if (this == Tono.NEUTRO) Palette.nightSurface else fill()
private fun Tono.widgetInk(): Color = if (this == Tono.GIALLO) Palette.night else Color.White

private fun Forma.symbol(): String = when (this) {
    Forma.DIVIETO -> "—"; Forma.ESCLAMATIVO -> "!"; Forma.SPUNTA -> "✓"; Forma.SPENTA -> "○"
    Forma.DOMANDA, Forma.DOMANDA_TRATTEGGIATA -> "?"; Forma.FUORI -> "↗"
}

@Composable
private fun WidgetContent(d: WidgetData) {
    val f = d.final
    val ink = ColorProvider(f.color.widgetInk())
    val medium = LocalSize.current.width >= GateWidget.MEDIUM.width
    val open = actionStartActivity(Intent(Intent.ACTION_VIEW, Uri.parse("gatelr://adesso")).setClass(androidx.glance.LocalContext.current, MainActivity::class.java))
    Column(GlanceModifier.fillMaxSize().background(ColorProvider(f.color.widgetFill())).cornerRadius(24.dp).padding(14.dp)
        .clickable(open).semantics { contentDescription = d.spoken }) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            // La forma: un disco con il segno, come nell'app (forma + parola + colore)
            Box(GlanceModifier.size(30.dp).background(ColorProvider(f.color.widgetInk())).cornerRadius(15.dp), contentAlignment = Alignment.Center) {
                Text(f.stato.forma.symbol(), style = TextStyle(color = ColorProvider(f.color.widgetFill()), fontSize = 17.sp, fontWeight = FontWeight.Bold))
            }
            Spacer(GlanceModifier.width(8.dp))
            if (medium) d.place?.let { Text(it, maxLines = 1, style = TextStyle(color = ink, fontSize = 13.sp, fontWeight = FontWeight.Medium)) }
        }
        Spacer(GlanceModifier.height(6.dp))
        Text(f.title.uppercase(java.util.Locale.forLanguageTag(app.gatelr.core.Strings.language)), maxLines = 2, style = TextStyle(color = ink, fontSize = if (medium) 24.sp else 19.sp, fontWeight = FontWeight.Bold))
        if (!medium) d.place?.let { Text(it, maxLines = 1, style = TextStyle(color = ink, fontSize = 12.sp)) }
        val extra = listOfNotNull(f.reasonShort, d.until).joinToString(" · ")
        if (extra.isNotEmpty()) Text(extra, maxLines = if (medium) 2 else 1, style = TextStyle(color = ink, fontSize = 12.sp))
    }
}

/** Il ricevitore del widget (stesso nome di prima: i widget già messi sulla schermata restano) */
class ZoneWidget : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = GateWidget()

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        scheduleNext(context)
    }

    companion object {
        /** Aggiorna tutti i widget (dall'app quando va in secondo piano) */
        fun refresh(ctx: Context) {
            val app = ctx.applicationContext
            val ids = AppWidgetManager.getInstance(app).getAppWidgetIds(ComponentName(app, ZoneWidget::class.java))
            if (ids.isEmpty()) return
            MainScope().launch { runCatching { GateWidget().updateAll(app) } }
            scheduleNext(app)
        }

        /** Si riaggiorna da solo quando la ZTL si accende o si spegne (allarme non esatto: nessun permesso speciale) */
        private fun scheduleNext(ctx: Context) {
            val next = runCatching { WidgetData.compute(ctx).answer?.nextChange }.getOrNull() ?: return
            val ids = AppWidgetManager.getInstance(ctx).getAppWidgetIds(ComponentName(ctx, ZoneWidget::class.java))
            val pi = PendingIntent.getBroadcast(ctx, 1, Intent(ctx, ZoneWidget::class.java).setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            ctx.getSystemService(AlarmManager::class.java)?.set(AlarmManager.RTC, next.toEpochMilli() + 60_000, pi)
        }
    }
}

/** L'app (GateLRApp) carica già lo stato; il widget lo fa solo se il processo parte da lui */
object AppStateReady { var ok = false }
