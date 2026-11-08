package app.gatelr

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import app.gatelr.core.PermissionPlan

/**
 * 1.20.2: i permessi si chiedono quando usi la cosa che ne ha bisogno (PermissionPlan), non più all'apertura dell'app:
 * la posizione con «Usa la mia posizione» (prima pagina) o con «Avvia», le notifiche con il guardiano o un promemoria.
 */
object Permissions {
    private var launcher: ActivityResultLauncher<Array<String>>? = null
    private var after: (() -> Unit)? = null

    /** Da MainActivity.onCreate (la richiesta di Android va registrata prima che l'attività parta) */
    fun install(activity: ComponentActivity) {
        launcher = activity.registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {
            Here.allowed = GuardianService.canStart(activity)
            after?.invoke(); after = null
        }
    }

    private fun has(ctx: Context, p: String) = ContextCompat.checkSelfPermission(ctx, p) == PackageManager.PERMISSION_GRANTED

    /** Chiede quello che manca per quel momento, poi «then» (anche con un no: chi chiama controlla di nuovo) */
    fun ask(ctx: Context, moment: PermissionPlan.Moment, then: () -> Unit = {}) {
        val notif = Build.VERSION.SDK_INT < 33 || has(ctx, Manifest.permission.POST_NOTIFICATIONS)
        // 2.0.1 (B80): il permesso può essere arrivato dalle Impostazioni con l'app aperta: lo si rilegge qui
        Here.allowed = GuardianService.canStart(ctx)
        val needs = PermissionPlan.needs(moment, GuardianService.canStart(ctx), notif, Build.VERSION.SDK_INT)
        val l = launcher
        if (needs.isEmpty() || l == null) { then(); return }
        val list = mutableListOf<String>()
        if (PermissionPlan.Need.LOCATION in needs) list += listOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)
        if (PermissionPlan.Need.NOTIFICATIONS in needs && Build.VERSION.SDK_INT >= 33) list += Manifest.permission.POST_NOTIFICATIONS
        after = then
        l.launch(list.toTypedArray())
    }
}
