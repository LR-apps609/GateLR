package app.gatelr

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import app.gatelr.core.ReminderBook
import app.gatelr.core.SavedReminder
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import app.gatelr.core.L

/** Promemoria (ticket da attivare, conferma dell'hotel): allarme non esatto, nessun permesso speciale */
object Reminders {
    private const val CHANNEL = "reminders"

    fun schedule(ctx: Context, key: String, atMillis: Long, title: String, body: String) {
        // 1.20.2: le notifiche si chiedono qui, al primo promemoria (non più all'apertura dell'app)
        Permissions.ask(ctx, app.gatelr.core.PermissionPlan.Moment.REMINDER)
        val when_ = maxOf(atMillis, System.currentTimeMillis() + 5_000)
        // 2.0.1 (B86): salvato sul telefono (si ripianifica dopo il riavvio) e con un allarme che suona anche in Doze
        store(ctx, ReminderBook.add(load(ctx), SavedReminder(key, when_, title, body), System.currentTimeMillis()))
        arm(ctx, SavedReminder(key, when_, title, body))
    }

    private fun arm(ctx: Context, r: SavedReminder) {
        ctx.getSystemService(AlarmManager::class.java)?.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, r.at, intent(ctx, r.key, r.title, r.body))
    }

    fun cancel(ctx: Context, key: String) {
        ctx.getSystemService(AlarmManager::class.java)?.cancel(intent(ctx, key, "", ""))
        store(ctx, ReminderBook.remove(load(ctx), key))
    }

    /** Dopo il riavvio (BootReceiver): gli allarmi spariscono, i promemoria salvati si rimettono */
    fun rescheduleAll(ctx: Context) {
        val now = System.currentTimeMillis()
        val list = ReminderBook.toReschedule(load(ctx), now)
        store(ctx, list)
        list.forEach { arm(ctx, it) }
    }

    /** Il promemoria è arrivato: non serve più ripianificarlo */
    fun delivered(ctx: Context, key: String) = store(ctx, ReminderBook.remove(load(ctx), key))

    private val json = Json { ignoreUnknownKeys = true }
    private fun prefs(ctx: Context) = ctx.getSharedPreferences("gatelr", Context.MODE_PRIVATE)
    private fun load(ctx: Context): List<SavedReminder> = prefs(ctx).getString("reminders", null)
        ?.let { runCatching { json.decodeFromString(ListSerializer(SavedReminder.serializer()), it) }.getOrNull() } ?: emptyList()
    private fun store(ctx: Context, list: List<SavedReminder>) {
        prefs(ctx).edit().putString("reminders", json.encodeToString(ListSerializer(SavedReminder.serializer()), list)).apply()
    }

    private fun intent(ctx: Context, key: String, title: String, body: String) = PendingIntent.getBroadcast(ctx, key.hashCode(),
        Intent(ctx, ReminderReceiver::class.java).setAction("reminder|$key").putExtra("title", title).putExtra("body", body),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)

    fun show(ctx: Context, id: Int, title: String, body: String) {
        if (Build.VERSION.SDK_INT >= 33 && ContextCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        val nm = ctx.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) nm.createNotificationChannel(NotificationChannel(CHANNEL, L("Reminders"), NotificationManager.IMPORTANCE_HIGH))
        val open = PendingIntent.getActivity(ctx, 0, Intent(ctx, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
        nm.notify(id, NotificationCompat.Builder(ctx, CHANNEL).setSmallIcon(R.drawable.ic_stat_gatelr)
            .setContentTitle(title).setContentText(body).setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(open).setAutoCancel(true).setPriority(NotificationCompat.PRIORITY_HIGH).build())
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, i: Intent) {
        (i.action ?: "").removePrefix("reminder|").takeIf { it.isNotEmpty() }?.let { Reminders.delivered(ctx, it) }
        Reminders.show(ctx, (i.action ?: "").hashCode(), i.getStringExtra("title") ?: "GateLR", i.getStringExtra("body") ?: "")
    }
}

/** 2.0.1 (B86): al riavvio del telefono rimette i promemoria salvati (gli allarmi di Android non sopravvivono al riavvio) */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, i: Intent) {
        if (i.action == Intent.ACTION_BOOT_COMPLETED) Reminders.rescheduleAll(ctx)
    }
}
