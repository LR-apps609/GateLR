package app.gatelr

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.gatelr.core.L

/**
 * Benvenuto alla prima apertura. Spiega perché serve la posizione PRIMA di chiederla
 * (lo chiede Google Play: «prominent disclosure»). «Continua» → richiesta dei permessi.
 */
@Composable
fun Onboarding(onDone: () -> Unit) {
    Column(Modifier.fillMaxSize().background(Palette.blue).systemBarsPadding().verticalScroll(rememberScrollState()).padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp)) {
        Text("GateLR", color = Color.White.copy(alpha = 0.8f), fontWeight = FontWeight.SemiBold, letterSpacing = 1.sp)
        Text(L("Know before|the gate.").replace("|", "\n"), color = Color.White, fontSize = 36.sp, fontWeight = FontWeight.Bold, lineHeight = 38.sp)
        Point(Icons.Filled.CameraAlt, "Italy's old towns have camera gates",
            "ZTL means limited traffic zone. Cameras read every plate, and driving in at the wrong time means a fine that reaches you months later, even at home.")
        Point(Icons.Filled.CheckCircle, "One clear answer",
            "Search your hotel or destination: GateLR tells you if you can drive there, now or when you arrive, and prepares the message for the hotel.")
        Point(Icons.Filled.Shield, "A guardian next to your navigator",
            "Drive with Google Maps, Waze or Petal Maps: GateLR warns you before every active ZTL with a notification, a voice and a small bubble.")
        Point(Icons.Filled.LocationOn, "Your location stays on your phone",
            "GateLR uses your location to show the ZTL near you and, only while the guardian is on (with its notification), to warn you before the gates. It is never sent or stored anywhere.")
        Spacer(Modifier.size(4.dp))
        Button(onClick = onDone, colors = ButtonDefaults.buttonColors(containerColor = Color.White, contentColor = Palette.blue),
            modifier = Modifier.fillMaxWidth()) { Text(L("Continue"), fontWeight = FontWeight.SemiBold) }
        Text(L("Road signs on site always win over the app."), color = Color.White.copy(alpha = 0.7f), fontSize = 12.sp)
    }
}

@Composable
private fun Point(icon: ImageVector, title: String, body: String) {
    Row(verticalAlignment = Alignment.Top) {
        Box(Modifier.size(40.dp).background(Color.White.copy(alpha = 0.16f), CircleShape), contentAlignment = Alignment.Center) {
            Icon(icon, null, tint = Color.White)
        }
        Spacer(Modifier.width(14.dp))
        Column {
            Text(L(title), color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 18.sp)
            Text(L(body), color = Color.White.copy(alpha = 0.85f), fontSize = 14.sp)
        }
    }
}
