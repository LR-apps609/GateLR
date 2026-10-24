package app.gatelr

import android.app.Application
import org.maplibre.android.MapLibre

class GateLRApp : Application() {
    override fun onCreate() {
        super.onCreate()
        MapLibre.getInstance(this)
        AppState.init(this)
        AppStateReady.ok = true
    }
}
