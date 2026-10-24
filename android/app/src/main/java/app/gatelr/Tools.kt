package app.gatelr

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Image
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.gatelr.core.F
import app.gatelr.core.L
import app.gatelr.core.SignReader
import app.gatelr.core.Strings
import app.gatelr.core.TimeWindow
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.time.Instant

/** «Leggi il cartello»: foto del pannello (letta sul telefono) o testo scritto a mano → spiegazione e «attiva adesso?» */
@Composable
fun SignReaderScreen() {
    val ctx = LocalContext.current
    var text by remember { mutableStateOf("") }
    var reading by remember { mutableStateOf(false) }
    fun read(b: Bitmap) {
        reading = true
        TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS).process(InputImage.fromBitmap(b, 0))
            .addOnSuccessListener { text = it.text }
            .addOnCompleteListener { reading = false }
    }
    val camera = rememberLauncherForActivityResult(ActivityResultContracts.TakePicturePreview()) { b -> b?.let(::read) }
    val gallery = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        uri?.let { u -> runCatching { ctx.contentResolver.openInputStream(u)?.use { BitmapFactory.decodeStream(it) } }.getOrNull()?.let(::read) }
    }
    val result = remember(text) { SignReader.parse(text) }
    val muted = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.65f)

    Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp).padding(bottom = 32.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(L("Read the sign"), fontSize = 24.sp, fontWeight = FontWeight.Bold)
        Text(L("Point the camera at the white panel under the ZTL sign, or pick a photo of it."), color = muted)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = { camera.launch(null) }) { Icon(Icons.Filled.CameraAlt, null); Spacer(Modifier.width(6.dp)); Text(L("Camera")) }
            OutlinedButton(onClick = { gallery.launch("image/*") }) { Icon(Icons.Filled.Image, null); Spacer(Modifier.width(6.dp)); Text(L("Choose a photo")) }
        }
        OutlinedTextField(text, { text = it }, placeholder = { Text(L("e.g. 7.30-20.00 feriali")) }, minLines = 3, modifier = Modifier.fillMaxWidth())
        if (reading) Text(L("Reading…"), color = muted)
        if (text.isNotBlank()) {
            if (!result.understood) {
                CardBox { Text(L("I can't find days and hours in this text. Type them as on the panel, e.g. 7.30-20.00 feriali.")) }
            } else {
                val on = SignReader.isActive(result, Instant.now())
                Column(Modifier.fillMaxWidth().background(if (on) Palette.red else Palette.green, RoundedCornerShape(20.dp)).padding(16.dp)) {
                    Text(if (on) L("Active now, according to the sign: don't drive in") else L("Not active now, according to the sign: you may drive in"),
                        color = Color.White, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                }
                CardBox {
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        result.rules.forEach { r -> Text(TimeWindow(r.days, r.start, if (r.end == r.start) 1440 else r.end).text()) }
                        if (result.holidaysExcluded) Text(L("Public holidays: not active."), color = muted)
                        if (result.holidaysIncluded) Text(L("Also on public holidays."), color = muted)
                    }
                }
            }
        }
        Text(L("GateLR reads the panel for you, but it can misread a photo: if in doubt, the sign wins."), fontSize = 12.sp, color = muted)
    }
}

/** «Ho preso una multa?»: sette passi chiari */
@Composable
fun FineGuide() {
    val ctx = LocalContext.current
    val fine = remember {
        runCatching {
            val o = Json.parseToJsonElement(ctx.assets.open("Rules/fine.json").bufferedReader().readText()).jsonObject
            F("From €%lld to €%lld per entry (in some cities once a day per zone). About 30%% off if you pay within 5 days of the notice; after 60 days it goes up.",
                o["min"]!!.jsonPrimitive.int, o["max"]!!.jsonPrimitive.int)
        }.getOrDefault("")
    }
    val steps = listOf(
        "When it arrives" to L("In Italy the notice must arrive within 90 days. If you live abroad it can take up to a year (360 days). With a rental car, the company is asked first and then passes on your details."),
        "The rental company's charge" to L("The rental company often charges your card €30–90 for passing on your details. That's their fee, not the fine: the fine arrives later, by post, from the city."),
        "How much" to fine,
        "How to pay" to L("The notice has the amount, the deadline and the payment details (often an IBAN for a bank transfer; some cities also take cards online through pagoPA). Foreign cards are sometimes refused: a bank transfer always works. Keep the receipt and write the notice number in the payment reference."),
        "Disagree? Appeal" to L("Within 60 days to the Prefetto, or within 30 days to the Giudice di Pace (justice of the peace), as written on the notice. Common reasons: the electronic panel was off or broken, the sign had no hours, the panel still said \"Varco attivo\", your hotel had registered your plate, or several fines for the same zone on the same day."),
        "What to keep" to L("The hotel's written confirmation, photos of the signs and panels, your rental contract, and GateLR's drive log with dates and places."),
        "Don't ignore it" to L("Unpaid fines grow after 60 days and can be sent to a collection agency, also abroad."),
    )
    Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp).padding(bottom = 32.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(L("Got a fine?"), fontSize = 24.sp, fontWeight = FontWeight.Bold)
        steps.forEachIndexed { i, (title, body) ->
            CardBox {
                Row(verticalAlignment = Alignment.Top) {
                    Box(Modifier.size(34.dp).background(Palette.red, CircleShape), contentAlignment = Alignment.Center) {
                        Text("${i + 1}", color = Color.White, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
                    }
                    Spacer(Modifier.width(12.dp))
                    Column {
                        Text(L(title), fontWeight = FontWeight.SemiBold, fontSize = 17.sp)
                        Text(body, fontSize = 14.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f))
                    }
                }
            }
        }
        Text(L("General information, not legal advice. The notice you receive always wins: read its deadlines and amounts."), fontSize = 12.sp,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f))
    }
}
