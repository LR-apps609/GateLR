package app.gatelr

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.ColorStateList
import android.os.Build
import android.widget.RemoteViews
import androidx.compose.ui.graphics.toArgb
import app.gatelr.core.Verdict
import java.time.Instant

/** Widget: la zona scelta nell'app (o quella più vicina) con la risposta di adesso. Tocco → apre GateLR. */
class ZoneWidget : AppWidgetProvider() {
    override fun onUpdate(ctx: Context, manager: AppWidgetManager, ids: IntArray) {
        if (!AppStateReady.ok) AppState.init(ctx.applicationContext).also { AppStateReady.ok = true }
        val now = Instant.now()
        val zone = Here.coordinate?.takeIf { System.currentTimeMillis() - Here.at < 10 * 60_000 }?.let { c -> app.gatelr.core.zonesAt(AppState.cities, c).minByOrNull { it.second.roughArea }?.second } ?: AppState.zone
        val a = AppState.answer(zone, now)
        val color = when (a.verdict) { is Verdict.Yes -> Palette.green; is Verdict.No -> Palette.red; is Verdict.Conditional -> Palette.amber; is Verdict.Unsure -> Palette.muted }
        val open = PendingIntent.getActivity(ctx, 0, Intent(ctx, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
        for (id in ids) {
            val v = RemoteViews(ctx.packageName, R.layout.widget)
            v.setTextViewText(R.id.widget_zone, zone.shortName + (AppState.cityOf(zone)?.let { " · " + it.localizedName } ?: ""))
            v.setTextViewText(R.id.widget_verdict, a.verdict.short)
            v.setTextViewText(R.id.widget_next, changeText(a, now) ?: "")
            if (Build.VERSION.SDK_INT >= 31) v.setColorStateList(R.id.widget_root, "setBackgroundTintList", ColorStateList.valueOf(color.toArgb()))
            else v.setInt(R.id.widget_root, "setBackgroundColor", color.toArgb())
            v.setOnClickPendingIntent(R.id.widget_root, open)
            manager.updateAppWidget(id, v)
        }
        // Si riaggiorna da solo quando la ZTL si accende o si spegne (allarme non esatto: nessun permesso speciale)
        a.nextChange?.let { t ->
            val pi = PendingIntent.getBroadcast(ctx, 1, Intent(ctx, ZoneWidget::class.java).setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            ctx.getSystemService(AlarmManager::class.java)?.set(AlarmManager.RTC, t.toEpochMilli() + 60_000, pi)
        }
    }

    companion object {
        fun refresh(ctx: Context) {
            val m = AppWidgetManager.getInstance(ctx)
            val ids = m.getAppWidgetIds(ComponentName(ctx, ZoneWidget::class.java))
            if (ids.isNotEmpty()) ZoneWidget().onUpdate(ctx, m, ids)
        }
    }
}

/** L'app (GateLRApp) carica già lo stato; il widget lo fa solo se il processo parte da lui */
object AppStateReady { var ok = false }
