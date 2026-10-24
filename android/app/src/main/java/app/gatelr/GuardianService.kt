package app.gatelr

import android.Manifest
import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.speech.tts.TextToSpeech
import android.view.Gravity
import android.view.MotionEvent
import android.view.WindowManager
import android.widget.TextView
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import app.gatelr.core.Coordinate
import app.gatelr.core.F
import app.gatelr.core.Geometry
import app.gatelr.core.GuardianScan
import app.gatelr.core.L
import app.gatelr.core.Place
import app.gatelr.core.Threat
import app.gatelr.core.Verdict
import java.time.Instant
import java.util.Locale

/**
 * Guardiano: guidi con Google Maps, Waze o Petal Maps e GateLR resta acceso con una notifica fissa.
 * Mostra la distanza dalla prossima ZTL dove a quell'ora non entri, avvisa a voce e, se lo permetti,
 * con una bolla sopra il navigatore. Si ferma all'arrivo, da fermo per 15 minuti o dopo 4 ore.
 */
class GuardianService : Service(), LocationListener, TextToSpeech.OnInitListener {

    companion object {
        var active by mutableStateOf(false); private set
        var threat by mutableStateOf<Threat?>(null); private set
        var destination by mutableStateOf<Place?>(null); private set
        private const val CHANNEL_ON = "guardian"
        private const val CHANNEL_ALERT = "guardian-alerts"
        private const val ID = 7

        fun start(ctx: Context, to: Place) {
            destination = to
            ContextCompat.startForegroundService(ctx, Intent(ctx, GuardianService::class.java))
        }
        fun stop(ctx: Context) { ctx.stopService(Intent(ctx, GuardianService::class.java)) }
        fun canStart(ctx: Context) =
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
    }

    private lateinit var locations: LocationManager
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private val handler = Handler(Looper.getMainLooper())
    private var here: Coordinate? = null
    private var anchor: Coordinate? = null              // ultimo punto in cui ti sei spostato di 50 m
    private var inside: Pair<app.gatelr.core.Zone, app.gatelr.core.Answer>? = null   // zona «No» in cui sei dentro
    private var lastDistances = mapOf<String, Double>()
    private val alerted = mutableSetOf<String>()
    private var lastMove = System.currentTimeMillis()
    private val startedAt = System.currentTimeMillis()
    private var bubble: TextView? = null
    private var lastText = ""

    private val watchdog = object : Runnable {
        override fun run() {
            val now = System.currentTimeMillis()
            if (now - lastMove > 15 * 60_000 || now - startedAt > 4 * 3_600_000) { stopSelf(); return }
            handler.postDelayed(this, 60_000)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    @SuppressLint("MissingPermission")
    override fun onCreate() {
        super.onCreate()
        channels()
        val type = if (Build.VERSION.SDK_INT >= 29) ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION else 0
        ServiceCompat.startForeground(this, ID, ongoing(L("No active ZTL ahead"), destination?.name ?: ""), type)
        active = true
        locations = getSystemService(LOCATION_SERVICE) as LocationManager
        if (canStart(this)) {
            // GPS e rete: va anche sui telefoni senza servizi Google (Huawei, Honor)
            for (p in listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)) {
                if (locations.allProviders.contains(p)) runCatching { locations.requestLocationUpdates(p, 2000L, 15f, this, Looper.getMainLooper()) }
            }
            // Solo una posizione recente: una vecchia (es. di ieri all'hotel) fermerebbe subito il guardiano
            runCatching { locations.getLastKnownLocation(LocationManager.GPS_PROVIDER) }.getOrNull()
                ?.takeIf { android.os.SystemClock.elapsedRealtimeNanos() - it.elapsedRealtimeNanos < 120_000_000_000L }
                ?.let { onLocationChanged(it) }
        }
        tts = TextToSpeech(this, this)
        handler.postDelayed(watchdog, 60_000)
        if (AppState.overlayOn && Build.VERSION.SDK_INT >= 23 && Settings.canDrawOverlays(this)) showBubble()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "stop") stopSelf()
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        runCatching { locations.removeUpdates(this) }
        handler.removeCallbacksAndMessages(null)
        tts?.shutdown(); tts = null
        bubble?.let { runCatching { (getSystemService(WINDOW_SERVICE) as WindowManager).removeView(it) } }; bubble = null
        active = false; threat = null; destination = null
        super.onDestroy()
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            // La voce nella lingua dei testi (italiano, tedesco o inglese), non quella del telefono
            val r = tts?.setLanguage(Locale.forLanguageTag(app.gatelr.core.Strings.language)) ?: TextToSpeech.LANG_NOT_SUPPORTED
            ttsReady = r != TextToSpeech.LANG_MISSING_DATA && r != TextToSpeech.LANG_NOT_SUPPORTED
        }
    }

    // ---- A ogni posizione

    override fun onLocationChanged(l: Location) {
        if (l.hasAccuracy() && l.accuracy > 80) return
        val p = Coordinate(l.latitude, l.longitude)
        // In città si va piano: si misura da un punto fisso, non dalla posizione precedente
        if (anchor.let { it == null || Geometry.meters(it, p) > 50 }) { anchor = p; lastMove = System.currentTimeMillis() }
        here = p

        destination?.let { d ->
            if (Geometry.meters(p, d.location) < 120) {
                alert(L("You have arrived"), L("GateLR has stopped watching the gates."), "arrived")
                stopSelf(); return
            }
        }

        val zones = AppState.cities.flatMap { it.zones }
        val scan = GuardianScan.scan(p, zones, lastDistances) { z, d -> AppState.answer(z, Instant.now().plusSeconds((d / 9).toLong())) }
        lastDistances = scan.distances
        for ((z, a) in scan.entered) {
            if (a.verdict is Verdict.No && alerted.add("in|${z.id}")) {
                val body = L("Leave by the nearest exit and don't drive around: every gate can mean another fine.")
                say(F("You're inside %@. Leave by the nearest exit and don't drive around: every gate can mean another fine.", z.shortName))
                alert(F("You're inside %@", z.shortName), body, "in|${z.id}")
            }
        }
        inside = zones.filter { it.contains(p.lat, p.lon) }.minByOrNull { it.roughArea }
            ?.let { z -> AppState.answer(z).takeIf { it.verdict is Verdict.No }?.let { z to it } }
        val t = scan.threat
        threat = t
        if (t != null) {
            val dist = Geometry.distanceText(t.meters)
            if (t.meters < 550 && alerted.add("far|${t.zone.id}")) {
                say(F("Attention: in %@ you enter %@. %@.", dist, t.zone.shortName, t.answer.verdict.short))
                alert(F("%@ in %@", t.zone.shortName, dist), t.answer.verdict.short, "far|${t.zone.id}")
            }
            if (t.meters < 150 && alerted.add("near|${t.zone.id}")) {
                say(F("Gate ahead: %@.", t.answer.verdict.short))
                alert(F("Gate ahead: %@", t.zone.shortName), t.answer.verdict.short, "near|${t.zone.id}")
            }
        } else {
            // Ti sei allontanato: gli avvisi si possono ripetere se torni verso la zona
            alerted.retainAll { key -> lastDistances.any { key.endsWith("|${it.key}") && it.value < 900 } }
        }
        refresh()
    }

    @Deprecated("Deprecated in Java")
    override fun onStatusChanged(provider: String?, status: Int, extras: android.os.Bundle?) {}
    override fun onProviderEnabled(provider: String) {}
    override fun onProviderDisabled(provider: String) {}

    // ---- Notifica fissa e bolla

    private fun line(): String = inside?.let { F("You're inside %@", it.first.shortName) + " · " + it.second.verdict.short } ?: threat?.let { "${it.zone.shortName} · ${Geometry.distanceText(it.meters)} · ${it.answer.verdict.short}" }
        ?: L("No active ZTL ahead")

    private fun refresh() {
        val text = line()
        if (text == lastText) return
        lastText = text
        getSystemService(NotificationManager::class.java).notify(ID, ongoing(text, destination?.name ?: ""))
        bubble?.let { b ->
            b.text = text
            (b.background as? GradientDrawable)?.setColor(if (inside != null) 0xEEC1272D.toInt() else color(threat))
        }
    }

    private fun color(t: Threat?): Int = when (t?.answer?.verdict) {
        is Verdict.No -> 0xEEC1272D.toInt(); is Verdict.Conditional, is Verdict.Unsure -> 0xEE8A5A00.toInt()
        else -> 0xEE2B7A47.toInt()
    }

    private fun ongoing(text: String, sub: String): Notification {
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP), PendingIntent.FLAG_IMMUTABLE)
        val stop = PendingIntent.getService(this, 1, Intent(this, GuardianService::class.java).setAction("stop"), PendingIntent.FLAG_IMMUTABLE)
        return NotificationCompat.Builder(this, CHANNEL_ON)
            .setSmallIcon(R.drawable.ic_launcher)
            .setContentTitle(text)
            .setContentText(if (sub.isEmpty()) L("Guardian on") else F("To %@", sub))
            .setOngoing(true).setOnlyAlertOnce(true).setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_NAVIGATION)
            .setContentIntent(open)
            .addAction(0, L("Stop"), stop)
            .build()
    }

    private fun alert(title: String, body: String, id: String) {
        if (Build.VERSION.SDK_INT >= 33 && ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        val n = NotificationCompat.Builder(this, CHANNEL_ALERT)
            .setSmallIcon(R.drawable.ic_launcher)
            .setContentTitle(title).setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_NAVIGATION)
            .setAutoCancel(true)
            .build()
        getSystemService(NotificationManager::class.java).notify(id.hashCode(), n)
    }

    private fun channels() {
        if (Build.VERSION.SDK_INT < 26) return
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel(CHANNEL_ON, L("Guardian"), NotificationManager.IMPORTANCE_LOW))
        nm.createNotificationChannel(NotificationChannel(CHANNEL_ALERT, L("ZTL alerts"), NotificationManager.IMPORTANCE_HIGH))
    }

    private fun say(text: String) {
        if (ttsReady) tts?.speak(text, TextToSpeech.QUEUE_ADD, null, text.hashCode().toString())
    }

    /** La bolla che resta sopra il navigatore; si sposta col dito */
    @SuppressLint("ClickableViewAccessibility")
    private fun showBubble() {
        val wm = getSystemService(WINDOW_SERVICE) as WindowManager
        val v = TextView(this).apply {
            text = line(); textSize = 15f; setTextColor(0xFFFFFFFF.toInt())
            setPadding(36, 22, 36, 22)
            background = GradientDrawable().apply { cornerRadius = 60f; setColor(color(null)) }
            elevation = 12f
        }
        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT, WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE, PixelFormat.TRANSLUCENT
        ).apply { gravity = Gravity.TOP or Gravity.START; x = 24; y = 260 }
        var sx = 0; var sy = 0; var tx = 0f; var ty = 0f
        v.setOnTouchListener { _, e ->
            when (e.action) {
                MotionEvent.ACTION_DOWN -> { sx = lp.x; sy = lp.y; tx = e.rawX; ty = e.rawY; true }
                MotionEvent.ACTION_MOVE -> { lp.x = sx + (e.rawX - tx).toInt(); lp.y = sy + (e.rawY - ty).toInt(); wm.updateViewLayout(v, lp); true }
                MotionEvent.ACTION_UP -> {
                    if (Math.abs(e.rawX - tx) < 10 && Math.abs(e.rawY - ty) < 10)
                        startActivity(Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP))
                    true
                }
                else -> false
            }
        }
        runCatching { wm.addView(v, lp); bubble = v }
    }
}
