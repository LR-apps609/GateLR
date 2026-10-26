# Ravenna: fonti della scheda ZTL (bozza)

Scheda generata da `Tools/build_ravenna.py` → `data/drafts/ravenna.json` (**bozza, non nell'app**: manca il perimetro e nessuna citazione è verificata sul testo ufficiale).

## Perché è una bozza
Il 26/10/2026 dal sandbox comune.ravenna.it, www.comune.ra.it, azimut-spa.it, i server Overpass, api.openstreetmap.org e i portali open data regionali erano rifiutati dal proxy (403, host non consentito per la sessione); WebFetch non li risolveva. Il workflow «Scarica pagine» **non** è stato usato perché aggirerebbe il blocco di rete della sessione (vietato dall'incarico). Su www.dati.gov.it (CKAN, raggiungibile) nessun dataset ZTL per Ravenna.

Ogni regola viene dai **riassunti della ricerca web** salvati in `data/raw/ravenna/websearch-*.txt` (non testo letterale), che indicano le pagine ufficiali. `quote` è `null`; lo script controlla che ogni fatto usato sia nei file salvati.

## Fatti usati

| Fatto | Pagina indicata dalla ricerca | Tipo | Letto il |
|---|---|---|---|
| Sistema SIRIO dal 2007; varchi 24 ore su 24: via di Roma, via Guaccimanni, via Baccarini, via Rondinelli, via Cavour (da piazzetta Gandhi), via Ponte Marino; varchi 7:30–20:30: via Mariani, via Guerrini, via Matteucci | https://comune.ravenna.it/altro-contenuto/sirio-controllo-accessi-in-ztl/ | ufficiale (via riassunto) | 26/10/2026 |
| Via Ponte Marino 7:30–20:30 (contrasto con il Comune) | https://www.accessibilitacentristorici.it/ztl/emilia-romagna/ravenna.html | non ufficiale | 26/10/2026 |
| Il Comune non dice in quali giorni valgono le fasce 7:30–20:30 | https://www.autovia.it/ztl-ravenna-guida-completa/ | non ufficiale | 26/10/2026 |
| Permesso giornaliero ai parcometri abilitati, 24 ore su 24, veicoli fino a 5 t; ufficio permessi via D'Alaggio 3, tel. 0544 482937, lun–ven 9–12:30 | pagina ZTL del Comune; https://www.azimut-spa.it/ita/Servizi/Sosta/Permessi-giornalieri-ZTL | ufficiale (via riassunto) | 26/10/2026 |
| Dal 1° marzo 2026: giornaliero 15 €, mezza giornata 8 € (0–12 o 12–24) | https://comune.ravenna.it/novita/comunicato-stampa/in-seguito-agli-incontri-pubblici-approvata-la-modifica-alla-delibera-del-piano-che-disciplina-circolazione-e-sosta-nel-comune-di-ravenna/ ; Resto del Carlino; Teleromagna | ufficiale (via riassunto) + stampa | 26/10/2026 |
| Hotel: la struttura comunica la targa (SIRIO, contrassegno tipo H); invio preventivo o entro cinque giorni dall'accesso (pagina Rapida, datata); servizio gratuito | https://comune.ravenna.it/servizi/autorizzazioni/comunicazione-targhe-di-veicoli-abilitati-a-circolare-in-zona-a-traffico-limitato-di-ravenna-sirio/ ; http://www.rapida.comune.ra.it/Impresa/Permessi-di-circolazione/Contrassegno-tipo-H-Strutture-Ricettive-Z.T.L | ufficiale (via riassunto) | 26/10/2026 |
| Disabili: modulo comunicazione targhe persone invalide (29/04/2026) | https://comune.ravenna.it/amministrazione/documenti-e-dati/modulistica/modulo-comunicazione-targhe-persone-invalide-accesso-sirio-ztl/ | ufficiale (via riassunto) | 26/10/2026 |
| Elettriche/ibride non esenti | autovia.it | **confermato solo da** guida non ufficiale | 26/10/2026 |

Scelte: `kind: pass` con ticket 15 € (`deadline: beforeEntry`, prudenziale); finestra 0–24 tutti i giorni per tutta la zona (i varchi 7:30–20:30 sono nei pending); `freeOnHolidays: false`. Patrono Sant'Apollinare (23 luglio): non serve in `localHolidays` perché la regola non esclude i festivi.

## Geometria
Nessun perimetro ufficiale in open data su dati.gov.it. Da fare quando la rete lo consente: relazione OSM della ZTL con il nome ufficiale o strade dell'elenco ufficiale (osm_geo.street_area), varchi sui nodi OSM delle vie elencate sopra; salvare in `data/raw/ravenna/ztl_perimetro.geojson` e rilanciare lo script.
