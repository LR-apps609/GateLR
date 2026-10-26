# Assisi: fonti della scheda ZTL (bozza)

Scheda generata da `Tools/build_assisi.py` → `data/drafts/assisi.json` (**bozza, non nell'app**: manca il perimetro e gli orari sono confermati solo dalla stampa locale).

## Perché è una bozza
Il 26/10/2026 dal sandbox www.comune.assisi.pg.it, i server Overpass e api.openstreetmap.org erano rifiutati dal proxy (403, host non consentito per la sessione); WebFetch non li risolveva. Il workflow «Scarica pagine» **non** è stato usato perché aggirerebbe il blocco di rete della sessione (vietato dall'incarico). Su www.dati.gov.it nessun dataset ZTL per Assisi.

Ogni regola viene dai **riassunti della ricerca web** salvati in `data/raw/assisi/websearch-*.txt` (non testo letterale; le frasi tra virgolette sono quelle riportate dal motore di ricerca dagli articoli). `quote` è `null`; lo script controlla che ogni fatto usato sia nei file salvati.

## Fatti usati

| Fatto | Pagina indicata dalla ricerca | Tipo | Letto il |
|---|---|---|---|
| Varchi elettronici dopo 8 mesi di sperimentazione (dal 15/01/2026, prorogata), in funzione con multe dal 16/09/2026 | https://www.assisinews.it/cronaca/dal-16-settembre-entrano-in-funzione-i-varchi-elettronici-con-multe-in-caso-di-violazioni/ ; https://terrenostre.info/2026/09/ztlassisi-16092026-in-funzione-varchi-elettronici/ ; https://www.vivoumbria.it/zona-a-traffico-limitato-di-assisi-attivi-dal-16-settembre-i-nuovi-varchi-elettronici-con-sanzioni/ | non ufficiale (comunicato del Comune ripreso) | 26/10/2026 |
| 5 varchi: Porta San Giacomo, Largo Properzio, via Porta Perlici, via Marconi (parcheggio Giovanni Paolo II), via del Turrione | idem, La Nazione | non ufficiale | 26/10/2026 |
| Chiusura: feriali 11–12:30 e 15:30–17:30; prefestivi e festivi 11–20 | Assisi News | **confermato solo da** Assisi News (una seconda ricerca non lo ha ritrovato) | 26/10/2026 |
| Turisti diretti agli alberghi: solo carico/scarico bagagli, max 60 minuti; targa e giorni di arrivo/partenza al titolare, comunicazione sul parabrezza | Assisi News; https://www.visit-assisi.it/muoversi-in-citta/ | non ufficiale | 26/10/2026 |
| Disciplinare per gli accessi in deroga sul sito del Comune; permesso ZTL | https://www.comune.assisi.pg.it/servizi/mobilita_e_trasporti/servizio_23.html | ufficiale (non letto) | 26/10/2026 |
| Elettriche: possono accedere e sostare (escluse aree riservate) → non esentate in GateLR per prudenza (targhe estere) | Assisi News | non ufficiale | 26/10/2026 |
| Disabili: max due targhe, prima o entro 72 ore, permessivarchi@comune.assisi.pg.it | ricerca (pagina del Comune / ilportaledellaccessibilita.it) | da verificare | 26/10/2026 |
| Multa 84 € (58,10 € entro 5 giorni); oltre 300 violazioni dal 18 al 20/09 | ricerca, La Nazione | non ufficiale | 26/10/2026 |
| Ricorso al TAR annunciato da Altea (locazioni turistiche) | https://www.corrieredellumbria.it/news/attualita/419274/ztl-di-assisi-varchi-elettronici-attivi-da-oggi-altea-prepara-ricorso-al-tar.html | non ufficiale | 26/10/2026 |
| Corrieri: pacchi solo entro le 10, deroga in preparazione | https://www.corrieredellumbria.it/news/attualita/466407/assisi-la-nuova-ztl-apre-per-i-corrieri.html | non ufficiale | 26/10/2026 |

Scelte: lun–ven 11–12:30 e 15:30–17:30, sab–dom 11–20 (`holidaysAsSunday: true`, `freeOnHolidays: false`); sabato trattato come prefestivo; altri prefestivi non modellati (pending). `localHolidays: ["10-04"]` (San Francesco, patrono). Nota: il 4 ottobre non è nell'elenco dei festivi nazionali dell'app (`ItalianHolidays` in Sources/RuleEngine.swift), da valutare a parte (codice dell'app non toccato).

## Geometria
Nessun perimetro ufficiale trovato. Da fare quando la rete lo consente: strade OSM raggiungibili solo dai 5 varchi (come `Tools/build_perugia.py`) o relazione OSM con il nome ufficiale; salvare in `data/raw/assisi/ztl_perimetro.geojson`, varchi sui nodi OSM, e rilanciare lo script.
