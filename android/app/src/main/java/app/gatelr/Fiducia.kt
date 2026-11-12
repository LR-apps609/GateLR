package app.gatelr

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.gatelr.core.City
import app.gatelr.core.F
import app.gatelr.core.Fiducia
import app.gatelr.core.L
import app.gatelr.core.Place
import app.gatelr.core.Strings
import app.gatelr.core.Zone
import java.time.Instant

// 2.0.2 «Fiducia» (bozza approvata: chip «✓ Controllata …», chip giallo «Non ancora verificata a mano», «Fonte: Comune di …»,
// pulsante bordato «Mandalo al tuo hotel / noleggio», riga piccola con le due pagine). Sotto la risposta, mai al posto suo:
// il colore della risposta non cambia. Come FiduciaFooter dell'iPhone e la riga «fid» del sito.

/**
 * La riga della fiducia sotto una risposta. [zone] la zona che decide (null fuori dalle zone: niente data, solo link e
 * pulsante); [place] il posto cercato (null o la tua posizione: si condivide la pagina della città, mai dove sei)
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun TrustBox(zone: Zone?, city: City?, place: Place?) {
    val ctx = LocalContext.current
    fun open(url: String) = runCatching { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) }
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        zone?.let { z ->
            val c = Fiducia.control(z.source, Instant.now(), AppState.engine)
            FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                // La spunta solo con i dati freschi (verificati o letti da al più 120 giorni, pagina non cambiata)
                TrustChip(c.text, if (c.fresh) Palette.greenSoft else Ink.surface2, if (c.fresh) Palette.greenInk else Ink.text2, check = c.fresh)
                if (!c.byHand) TrustChip(L("Not yet verified by hand"), Palette.amberSoft, Palette.amberInk)
            }
            // La fonte: il sito non ufficiale con il suo nome, se le regole vengono da lì; altrimenti il Comune
            val u = z.source.unofficialSource.takeIf { !z.source.isOfficial }
            Text(F("Source: %@", u?.name ?: z.source.localizedAuthority) + " ›", color = MaterialTheme.colorScheme.primary, fontSize = 15.sp,
                modifier = Modifier.heightIn(min = 48.dp).clickable(role = Role.Button) { open(u?.url ?: z.source.pageURL) }.padding(vertical = 12.dp))
        }
        val shareCity = city ?: zone?.let { AppState.cityOf(it) }
        val own = place == null || place.name == L("My position") || place.name == L("Your position")
        Column(Modifier.fillMaxWidth().heightIn(min = 56.dp).border(1.5.dp, MaterialTheme.colorScheme.primary, RoundedCornerShape(16.dp))
            .clickable(role = Role.Button) {
                val url = Fiducia.shareURL(Strings.language, shareCity?.id, if (own) null else place?.name,
                    if (own) null else place?.location?.lat, if (own) null else place?.location?.lon, Fiducia.vehicleKey(AppState.vehicle))
                val name = if (own) shareCity?.localizedName ?: "" else place!!.name
                runCatching { ctx.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).setType("text/plain")
                    .putExtra(Intent.EXTRA_TEXT, Fiducia.shareText(name, url)), L("Send it to your hotel / rental"))) }
            }.padding(horizontal = 14.dp, vertical = 8.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.Share, null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(8.dp))
                Text(L("Send it to your hotel / rental"), color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold, fontSize = 16.sp)
            }
            Text(L("Opens in the browser, nothing to install"), color = Ink.text2, fontSize = 13.sp)
        }
        FlowRow(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            Text(L("How we check the data") + " ›", color = Ink.text2, fontSize = 14.sp,
                modifier = Modifier.heightIn(min = 48.dp).clickable(role = Role.Button) { Nav.tool = "checks" }.padding(vertical = 12.dp))
            Text(L("What to do if you get a fine") + " ›", color = Ink.text2, fontSize = 14.sp,
                modifier = Modifier.heightIn(min = 48.dp).clickable(role = Role.Button) { Nav.tool = "finehelp" }.padding(vertical = 12.dp))
        }
    }
}

@Composable
private fun TrustChip(text: String, fill: Color, ink: Color, check: Boolean = false) {
    Row(Modifier.background(fill, RoundedCornerShape(50)).padding(horizontal = 12.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
        if (check) { Icon(Icons.Filled.Check, null, tint = ink, modifier = Modifier.size(16.dp)); Spacer(Modifier.width(4.dp)) }
        Text(text, color = ink, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
    }
}

/** «Come controlliamo i dati»: breve e onesta, dai fatti del repository (fonti, controllo quotidiano, verifica a mano) */
@Composable
fun ChecksPage() {
    InfoPage(L("How we check the data"), null, listOf(
        "Where the data comes from" to "Hours, rules and ZTL borders come from the official pages and open data of each city (the Comune). Where a city publishes nothing usable, the source is marked unofficial and those answers are never green.",
        "Checked automatically every morning" to "Every morning a program opens the city pages we cite and compares them with the last reading. If a page has changed, the answers for that zone turn yellow («Check the sign») until a person reads it again.",
        "The date and the source on every answer" to "Under every answer you see when we last checked the rules against the official sources, and a link to the city's page, so you can read it yourself.",
        "Verification by hand: still in progress" to "A person still has to compare each zone with the signs and the official acts. Until that's done, the answer shows the yellow label «Not yet verified by hand». The colour of the answer doesn't change because of it.",
        "When we're not sure: yellow" to "If the data is older than 120 days, the city's page has changed, the source is unofficial or it's a public holiday we couldn't confirm, the answer is yellow: «Check the sign». We'd rather say we're not sure than say green by mistake.",
    ), links = emptyList(), foot = L("Road signs on site always win over the app."))
}

/** «Cosa fare se ricevi una multa»: informativa e prudente, non consulenza legale; GateLR non rimborsa multe */
@Composable
fun FineHelpPage() {
    InfoPage(L("What to do if you get a fine"),
        L("GateLR can't refund fines, and we'd rather say so clearly. This page is general information, not legal advice: here is what you can check."),
        listOf(
            "Check the notice" to "Read date, time, gate (camera) and plate. Check that the plate is yours and that you really drove there at that time.",
            "Compare with the city's page" to "Open the city's official page (the link is under every answer) and check the hours that applied that day. Photos of the signs and panels help.",
            "Rental car or hotel?" to "With a rental car the notice usually reaches the rental company first: ask them what they received and what they charged you. If your hotel was meant to register your plate, ask the hotel in writing whether and when it did.",
            "Appeals in Italy" to "You can appeal to the Prefetto within 60 days of the notification, or to the Giudice di Pace (justice of the peace) within 30 days (Highway Code, art. 203 and 204-bis). If you pay first, you can no longer appeal. The notice says where and how: what it says counts.",
        ),
        links = FINE_SOURCES,
        foot = L("For advice on your own case, ask a lawyer or a consumer association.") + " " +
            L("General information, not legal advice. The notice you receive always wins: read its deadlines and amounts."),
        more = L("Got a fine?") to { Nav.tool = "fines" })
}

/** Le fonti ufficiali dei termini dei ricorsi (gli stessi link dell'iPhone e del sito) */
val FINE_SOURCES = listOf(
    "Highway Code, art. 203 (appeal to the Prefetto)" to "https://www.normattiva.it/uri-res/N2Ls?urn:nir:stato:decreto.legislativo:1992-04-30;285~art203",
    "Highway Code, art. 204-bis (Giudice di Pace)" to "https://www.normattiva.it/uri-res/N2Ls?urn:nir:stato:decreto.legislativo:1992-04-30;285~art204bis",
    "Example: Prefecture of Turin, appeals against traffic fines" to "https://prefettura.interno.gov.it/it/prefetture/torino/ricorso-violazioni-codice-strada",
)

@Composable
private fun InfoPage(title: String, intro: String?, sections: List<Pair<String, String>>, links: List<Pair<String, String>>, foot: String,
                     more: Pair<String, () -> Unit>? = null) {
    val ctx = LocalContext.current
    Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp).padding(bottom = 32.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(title, fontSize = 24.sp, fontWeight = FontWeight.Bold, modifier = Modifier.semantics { heading() })
        intro?.let { Text(it, fontSize = 16.sp, fontWeight = FontWeight.SemiBold) }
        sections.forEach { (t, b) ->
            CardBox {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(L(t), fontWeight = FontWeight.SemiBold, fontSize = 17.sp, modifier = Modifier.semantics { heading() })
                    Text(L(b), fontSize = 15.sp, color = Ink.text2)
                }
            }
        }
        if (links.isNotEmpty()) {
            SectionLabel("Official sources")
            links.forEach { (t, u) ->
                Text(L(t) + " ›", color = MaterialTheme.colorScheme.primary, fontSize = 15.sp,
                    modifier = Modifier.heightIn(min = 48.dp).clickable(role = Role.Button) {
                        runCatching { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(u))) }
                    }.padding(vertical = 12.dp))
            }
        }
        more?.let { (t, go) ->
            Text("$t ›", color = MaterialTheme.colorScheme.primary, fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
                modifier = Modifier.heightIn(min = 48.dp).clickable(role = Role.Button, onClick = go).padding(vertical = 12.dp))
        }
        Text(foot, fontSize = 12.sp, color = Ink.text2)
    }
}
