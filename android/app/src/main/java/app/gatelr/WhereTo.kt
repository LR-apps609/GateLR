package app.gatelr

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Place
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.gatelr.core.L
import app.gatelr.core.Place
import app.gatelr.core.SearchPlan
import app.gatelr.core.SearchSubmit
import kotlinx.coroutines.delay

/**
 * 2.0: il foglio unico «Dove vai?», lo stesso da Adesso, Mappa e Viaggio: hotel, indirizzo o piazza; i viaggi salvati e i
 * posti recenti. Scelto un posto: dalla mappa lo spillo sulla mappa, altrimenti Viaggio con la risposta.
 */
@Composable
fun WhereToSheet(onPick: (Place) -> Unit) {
    var query by remember { mutableStateOf("") }
    var results by remember { mutableStateOf(listOf<Place>()) }
    var searching by remember { mutableStateOf(false) }
    var searchFailed by remember { mutableStateOf(false) }
    var retry by remember { mutableIntStateOf(0) }
    // Invio con la ricerca ancora in corso: si cerca subito e si sceglie il primo risultato
    var pickFirst by remember { mutableStateOf(false) }
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }
    LaunchedEffect(query, retry) {
        searchFailed = false
        if (!SearchPlan.worthAsking(query)) { results = emptyList(); return@LaunchedEffect }
        val near = Geocoder.near()
        Geocoder.cached(query, near)?.let { results = it; return@LaunchedEffect }
        if (!pickFirst) delay(SearchPlan.DEBOUNCE_MS)
        searching = true
        try { val r = Geocoder.find(query, near); searchFailed = r == null; results = r ?: emptyList() } finally { searching = false }
    }
    fun pick(p: Place) { pickFirst = false; onPick(p) }
    LaunchedEffect(results, pickFirst) { if (pickFirst) results.firstOrNull()?.let { pick(it) } }

    // 2.0.1 (B165): con edge-to-edge adjustResize non agisce: la lista si alza sopra la tastiera con imePadding
    Column(Modifier.fillMaxWidth().fillMaxHeight(0.92f).imePadding().padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(L("Where are you going?"), style = MaterialTheme.typography.headlineMedium)
        OutlinedTextField(value = query, onValueChange = { query = it; pickFirst = false }, singleLine = true,
            placeholder = { Text(L("Hotel, address or square")) },
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
            keyboardActions = KeyboardActions(onSearch = {
                when (SearchSubmit.action(query, results.size, searchFailed)) {
                    SearchSubmit.PICK_FIRST -> pick(results.first())
                    SearchSubmit.RETRY, SearchSubmit.SEARCH_NOW -> { pickFirst = true; retry++ }
                    SearchSubmit.NOTHING -> {}
                }
            }),
            leadingIcon = { Icon(Icons.Filled.Search, null) },
            trailingIcon = { if (query.isNotEmpty()) IconButton(onClick = { query = ""; results = emptyList() }) { Icon(Icons.Filled.Close, L("Cancel")) } },
            shape = RoundedCornerShape(28.dp), modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp).focusRequester(focus))

        LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp), contentPadding = PaddingValues(bottom = 24.dp)) {
            when {
                results.isNotEmpty() -> items(results) { p -> PlaceLine(p, Icons.Filled.Place) { pick(p) } }
                searchFailed && !searching -> item { SearchRetry { retry++ } }
                SearchPlan.worthAsking(query) && !searching -> item { Text(L("No results"), color = Ink.text2) }
                SearchPlan.worthAsking(query) -> item { Text(L("Searching…"), color = Ink.text2) }
                else -> {
                    if (AppState.trips.isNotEmpty()) {
                        item { SectionLabel("Saved trips") }
                        items(AppState.trips.sortedBy { it.arrival }, key = { it.id }) { t ->
                            PlaceLine(t.place, Icons.Filled.Place, shortWhen(t.arrival)) { AppState.open(t); Nav.whereTo = null; Nav.tab = 2 }
                        }
                    }
                    if (AppState.recent.isNotEmpty()) {
                        item { SectionLabel("Recent") }
                        items(AppState.recent, key = { "r" + it.key }) { p -> PlaceLine(p, Icons.Filled.History) { pick(p) } }
                    }
                }
            }
        }
    }
}

@Composable
private fun PlaceLine(p: Place, icon: androidx.compose.ui.graphics.vector.ImageVector, extra: String? = null, onClick: () -> Unit) {
    CardBox(Modifier.clickable(role = Role.Button, onClick = onClick)) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.heightIn(min = 40.dp)) {
            Icon(icon, null, tint = Ink.text2)
            Spacer(Modifier.width(12.dp))
            Column {
                Text(p.name, fontWeight = FontWeight.SemiBold)
                val sub = listOfNotNull(p.address.ifEmpty { null }, extra).joinToString(" · ")
                if (sub.isNotEmpty()) Text(sub, fontSize = 13.sp, color = Ink.text2)
            }
        }
    }
}
