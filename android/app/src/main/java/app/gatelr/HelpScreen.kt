package app.gatelr

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.FactCheck
import androidx.compose.material.icons.filled.Gavel
import androidx.compose.material.icons.filled.LocationOff
import androidx.compose.material.icons.filled.ReceiptLong
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.gatelr.core.L

/** 2.0 «Aiuto» (A-Aiuto): leggi il cartello, posizione negata, la multa, il diario dei passaggi, cos'è una ZTL */
@Composable
fun HelpScreen(modifier: Modifier) {
    val ctx = LocalContext.current
    LazyColumn(modifier.fillMaxSize().background(MaterialTheme.colorScheme.background), contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)) {
        item { ScreenTitle(L("Help")) }
        item { HelpRow(Icons.Filled.CameraAlt, L("Read the sign"), L("Point the camera at the sign: days and hours")) { Nav.tool = "sign" } }
        if (!Here.allowed) item {
            Row(Modifier.fillMaxWidth().background(Palette.amberSoft, RoundedCornerShape(16.dp)).padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.LocationOff, null, tint = Palette.amberInk)
                Spacer(Modifier.width(10.dp))
                Text(L("Location denied: car alerts are off."), color = Palette.amberInk, fontSize = 15.sp, modifier = Modifier.weight(1f))
                Text(L("Open settings"), color = Palette.amberInk, fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.heightIn(min = 48.dp).clickable(role = Role.Button) {
                        runCatching { ctx.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${ctx.packageName}"))) }
                    }.padding(start = 8.dp, top = 14.dp))
            }
        }
        item { HelpRow(Icons.Filled.ReceiptLong, L("Got a fine?"), L("What to do, in 4 steps")) { Nav.tool = "fines" } }
        item { HelpRow(Icons.Filled.History, L("Drive log"), L("Passages near the gates, only on this phone")) { Nav.tool = "log" } }
        // 2.0.2 «Fiducia»: le due pagine, anche da qui (oltre che sotto ogni risposta)
        item { SectionLabel("About the answers") }
        item { HelpRow(Icons.Filled.FactCheck, L("How we check the data"), L("Sources, daily check, what we don't know yet")) { Nav.tool = "checks" } }
        item { HelpRow(Icons.Filled.Gavel, L("What to do if you get a fine"), L("Check the notice, appeals, who to ask")) { Nav.tool = "finehelp" } }
        item {
            HelpRow(Icons.Filled.MenuBook, L("What is a ZTL?"), L("The signs and the «ZTL ATTIVA» panel")) {
                runCatching { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://lr-apps609.github.io/GateLR/"))) }
            }
        }
        item {
            Text(L("Road signs on site always win over the app."), fontSize = 12.sp, color = Ink.text2, modifier = Modifier.padding(top = 8.dp))
        }
    }
}

@Composable
private fun HelpRow(icon: ImageVector, title: String, sub: String, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 64.dp).background(cardColor, RoundedCornerShape(16.dp))
        .clickable(role = Role.Button, onClick = onClick).padding(horizontal = 14.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, null, modifier = Modifier.size(24.dp))
        Spacer(Modifier.width(14.dp))
        Column(Modifier.weight(1f)) {
            Text(title, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
            Text(sub, fontSize = 14.sp, color = Ink.text2)
        }
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = Ink.text2)
    }
}
