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
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.gatelr.core.F
import app.gatelr.core.Forma
import app.gatelr.core.Tono
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
    val now = rememberNow()
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
            // 2.0.1 (B03): come l'iPhone (SignReaderView.verdictBox) un cartello letto non dà mai verde: accesa = rosso,
            // altrimenti giallo con il «?» «sembra spenta: controlla»
            val verdict = SignReader.reading(result, now)
            if (verdict == SignReader.Reading.UNREADABLE) {
                AmberSignBox(L("I can't read it"), L("I can't find days and hours in this text. Try again closer to the panel, or type them."))
            } else {
                if (verdict == SignReader.Reading.ACTIVE) {
                    Row(Modifier.fillMaxWidth().background(Palette.red, RoundedCornerShape(20.dp)).padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                        AnswerMark(Forma.DIVIETO, Tono.ROSSO, 30.dp)
                        Spacer(Modifier.width(12.dp))
                        Text(L("Active now, according to the sign: don't drive in"), color = Color.White, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                    }
                } else AmberSignBox(L("According to the sign, the ZTL seems off right now: check that there are no other bans"),
                    L("The sign doesn't know your vehicle, your permits, Euro bans or pedestrian areas, and the photo can be misread. Check the sign."))
                CardBox {
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        result.rules.forEach { r -> Text(TimeWindow(r.days, r.start, if (r.end == r.start) 1440 else r.end).text()) }
                        if (result.holidaysExcluded) Text(L("Public holidays: not active."), color = muted)
                        if (result.holidaysIncluded) Text(L("Also on public holidays."), color = muted)
                        Text(L("Check that the days and hours above are the ones on the panel: the photo can be misread."), fontSize = 13.sp, color = muted)
                    }
                }
            }
        }
        Text(L("GateLR reads the panel for you, but it can misread a photo: if in doubt, the sign wins."), fontSize = 12.sp, color = muted)
    }
}

/** Il riquadro giallo con il «?» (mai verde), come amberBox dell'iPhone */
@Composable
private fun AmberSignBox(title: String, detail: String) {
    Row(Modifier.fillMaxWidth().background(Palette.amberSoft, RoundedCornerShape(20.dp)).padding(16.dp).semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.Top) {
        AnswerMark(Forma.DOMANDA, Tono.GIALLO, 30.dp)
        Spacer(Modifier.width(12.dp))
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(title, color = Palette.amberInk, fontWeight = FontWeight.Bold, fontSize = 17.sp)
            Text(detail, color = Palette.amberInk, fontSize = 14.sp)
        }
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

/** Diario dei passaggi: quando sei passato vicino a un varco attivo o sei entrato dove non potevi */
@Composable
fun DriveLog() {
    val ctx = LocalContext.current
    val f = java.time.format.DateTimeFormatter.ofPattern("d MMM yyyy · HH:mm", java.util.Locale.forLanguageTag(Strings.language))
    fun d(ms: Long) = Instant.ofEpochMilli(ms).atZone(java.time.ZoneId.systemDefault()).format(f)
    val muted = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.65f)
    var confirmLog by remember { mutableStateOf(false) }
    if (confirmLog) ConfirmDelete("log", onConfirm = { AppState.log = emptyList(); AppState.save() }, onDismiss = { confirmLog = false })
    Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp).padding(bottom = 32.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(L("Drive log"), fontSize = 24.sp, fontWeight = FontWeight.Bold)
        Text(L("GateLR writes here when you pass close to an active gate or drive into a zone you can't enter. Only on this phone."), color = muted, fontSize = 14.sp)
        if (AppState.log.isEmpty()) CardBox { Text(L("Nothing yet: no active gate on your way.")) }
        AppState.log.forEach { e ->
            CardBox {
                Column {
                    Text((if (e.kind == "entered") L("Drove into the zone") else L("Near an active gate")) + " · " + e.zoneName, fontWeight = FontWeight.SemiBold,
                        color = if (e.kind == "entered") Palette.red else MaterialTheme.colorScheme.onSurface)
                    Text(listOf(d(e.date), e.verdict, e.plate).filter { it.isNotBlank() }.joinToString(" · "), fontSize = 13.sp, color = muted)
                }
            }
        }
        if (AppState.log.isNotEmpty()) {
            Text(L("A row here doesn't mean you'll be fined: maybe you didn't cross the gate, or your plate was registered. It's a reminder, and a note of when and where."), fontSize = 12.sp, color = muted)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(onClick = {
                    // 1.19.4: il testo condiviso non ha mai la targa (prima era in fondo a ogni riga)
                    val plates = AppState.vehicles.map { it.plate } + AppState.log.map { it.plate }
                    HotelMessage.share(ctx, AppState.log.joinToString("\n") { e ->
                        app.gatelr.core.PlatePrivacy.logLine(d(e.date), e.zoneName,
                            if (e.kind == "entered") L("Drove into the zone") else L("Near an active gate"), e.verdict, plates)
                    })
                }) { Text(L("Share the log")) }
                // 1.20.2: prima la conferma
                OutlinedButton(onClick = { confirmLog = true }) { Text(L("Delete the log")) }
            }
        }
    }
}
