package app.gatelr

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import app.gatelr.core.F
import app.gatelr.core.L

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun AccountScreen(modifier: Modifier) {
    val ctx = LocalContext.current
    val version = runCatching { ctx.packageManager.getPackageInfo(ctx.packageName, 0).versionName }.getOrNull() ?: "?"
    fun open(url: String) = runCatching { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) }
    val muted = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.65f)

    LazyColumn(modifier.fillMaxSize().background(MaterialTheme.colorScheme.background), contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)) {
        item { Text(L("Account"), fontSize = 28.sp, fontWeight = FontWeight.Bold) }

        item { SectionLabel("Preferred navigator") }
        item {
            CardBox {
                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Navigator.available(ctx).forEach { n ->
                        FilterChip(selected = Navigator.preferred(ctx) == n, onClick = { AppState.preferredNavigator = n.id; AppState.save() }, label = { Text(n.label) })
                    }
                }
            }
        }

        item { SectionLabel("Gate alerts") }
        item {
            CardBox {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text(L("Bubble over the navigator"), fontWeight = FontWeight.SemiBold)
                            Text(L("Distance to the next ZTL on top of Google Maps or Waze. You can move it with your finger."), fontSize = 13.sp, color = muted)
                        }
                        Switch(checked = AppState.overlayOn, onCheckedChange = { AppState.overlayOn = it; AppState.save() })
                    }
                    if (AppState.overlayOn && Build.VERSION.SDK_INT >= 23 && !Settings.canDrawOverlays(ctx)) {
                        Text(L("Allow «Display over other apps»") + " ›", color = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.clickable { ctx.startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:${ctx.packageName}"))) })
                    }
                    // Samsung, Xiaomi, Huawei, Honor: il risparmio energetico può fermare il guardiano
                    Text(L("Battery: if alerts stop, set GateLR to «Unrestricted» in the battery settings.") + " ›", fontSize = 13.sp, color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.clickable { runCatching { ctx.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${ctx.packageName}"))) } })
                }
            }
        }

        item { SectionLabel("Learn") }
        item {
            CardBox {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(L("Read the sign") + " ›", color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.SemiBold, modifier = Modifier.clickable { Nav.tool = "sign" })
                    Text(L("Drive log") + " ›", color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.SemiBold, modifier = Modifier.clickable { Nav.tool = "log" })
                    Text(L("Got a fine?") + " ›", color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.SemiBold, modifier = Modifier.clickable { Nav.tool = "fines" })
                }
            }
        }

        item { SectionLabel("Rules and maps") }
        item {
            CardBox {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    AppState.cities.forEach { c ->
                        val checked = c.zones.minOfOrNull { it.source.checkedOn }?.let(::shortDate) ?: ""
                        Text("${c.localizedName} · ${F("Checked on %@", checked)}", fontSize = 14.sp)
                    }
                    Text(L("Road signs on site always win over the app."), fontSize = 12.sp, color = muted)
                }
            }
        }

        item { SectionLabel("Help") }
        item {
            CardBox {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(L("Report a bug") + " ›", color = MaterialTheme.colorScheme.primary, modifier = Modifier.clickable {
                        val body = "GateLR Android $version\n${Build.MANUFACTURER} ${Build.MODEL} · Android ${Build.VERSION.RELEASE}\n\n"
                        val i = Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:support@example.com"))
                            .putExtra(Intent.EXTRA_SUBJECT, "GateLR – bug").putExtra(Intent.EXTRA_TEXT, body)
                        runCatching { ctx.startActivity(i) }.onFailure { HotelMessage.share(ctx, body) }
                    })
                    Text(L("Website") + " ›", color = MaterialTheme.colorScheme.primary, modifier = Modifier.clickable { open("https://lr-apps609.github.io/GateLR/") })
                    Text(L("Map data © OpenStreetMap contributors, OpenFreeMap"), fontSize = 12.sp, color = muted,
                        modifier = Modifier.clickable { open("https://www.openstreetmap.org/copyright") })
                }
            }
        }
        item { Text(F("Version %@", version), fontSize = 12.sp, color = muted, modifier = Modifier.padding(top = 8.dp)) }
    }
}
