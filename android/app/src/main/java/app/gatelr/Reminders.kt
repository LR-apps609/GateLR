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
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import app.gatelr.core.L

/** Promemoria (ticket da attivare, conferma dell'hotel): allarme non esatto, nessun permesso speciale */
object Reminders {
    private const val CHANNEL = "reminders"

    fun schedule(ctx: Context, key: String, atMillis: Long, title: String, body: String) {
        val when_ = maxOf(atMillis, System.currentTimeMillis() + 5_000)
        ctx.getSystemService(AlarmManager::class.java)?.set(AlarmManager.RTC_WAKEUP, when_, intent(ctx, key, title, body))
    }

    fun cancel(ctx: Context, key: String) {
        ctx.getSystemService(AlarmManager::class.java)?.cancel(intent(ctx, key, "", ""))
    }

    private fun intent(ctx: Context, key: String, title: String, body: String) = PendingIntent.getBroadcast(ctx, key.hashCode(),
        Intent(ctx, ReminderReceiver::class.java).setAction("reminder|$key").putExtra("title", title).putExtra("body", body),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)

    fun show(ctx: Context, id: Int, title: String, body: String) {
        if (Build.VERSION.SDK_INT >= 33 && ContextCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        val nm = ctx.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) nm.createNotificationChannel(NotificationChannel(CHANNEL, L("Reminders"), NotificationManager.IMPORTANCE_HIGH))
        val open = PendingIntent.getActivity(ctx, 0, Intent(ctx, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
        nm.notify(id, NotificationCompat.Builder(ctx, CHANNEL).setSmallIcon(R.drawable.ic_launcher)
            .setContentTitle(title).setContentText(body).setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(open).setAutoCancel(true).setPriority(NotificationCompat.PRIORITY_HIGH).build())
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, i: Intent) {
        Reminders.show(ctx, (i.action ?: "").hashCode(), i.getStringExtra("title") ?: "GateLR", i.getStringExtra("body") ?: "")
    }
}
