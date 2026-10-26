# Catania: fonti della scheda ZTL (bozza)

Scheda generata da `Tools/build_catania.py` → `data/drafts/catania.json` (**bozza, non nell'app**: nessuna citazione verificata sul testo ufficiale). Perimetro, varchi e area pedonale ci sono (OpenStreetMap).

## Perché è una bozza
Il 26/10/2026 dal sandbox www.comune.catania.it, www.amts.ct.it, cataniatoday.it, newsicilia.it e le guide rispondevano con rifiuto del proxy (403, host non consentito per la sessione); WebFetch non risolveva gli host. Il workflow «Scarica pagine» **non** è stato usato per aggirare il blocco (lanciato una sola volta, `pagine-catania-1`, per Overpass: risposta 406, non usata). Raggiungibili solo www.dati.gov.it (nessun dataset ZTL di Catania: `q=ztl catania` → 0), www.openstreetmap.org (API) e la ricerca web. Le regole vengono dai **riassunti della ricerca web** (`data/raw/catania/websearch-*.txt`, non testo letterale). `quote` è `null`.

## Zone
- **ZTL Centro Storico** attorno al Teatro Massimo Bellini: unica ZTL trovata. `restricted`, 0–24 tutti i giorni.
- **Area pedonale di piazza Vincenzo Bellini**: nel campo `pedestrian` della città.
- Non modellate: le altre aree pedonali con telecamera (via Etnea, via Crociferi, via Sciuti, via Mazzini, lungomare di San Giovanni li Cuti). Nessuna ZTL notturna o stagionale trovata.

## Fatti usati

| Fatto | Pagina indicata | Tipo | Letto il |
|---|---|---|---|
| ZTL Centro Storico (piazza Ogninella, via Pulvirenti, presso il Teatro Massimo), telecamere in pre-esercizio, sanzioni elettroniche dal 28/07/2022; pass solo online su AMTS; info ztl@amts.ct.it, 095 7519367/68 | https://www.comune.catania.it/informazioni/cstampa/default.aspx?cs=84326 ; cataniatoday.it, gds.it, newsicilia.it (luglio 2022) | ufficiale (via riassunto) + stampa | 26/10/2026 |
| Strade: piazza Scammacca, via Pulvirenti, via Mazza, piazza Ogninella, via Sant'Orsola, via Euplio Reina, via Maria Callas | newsicilia.it, cataniatoday.it | non ufficiale | 26/10/2026 |
| Attiva 24 ore su 24, tutti i giorni dell'anno | autovia.it (2026), sicurauto.it | **non ufficiale** (in contrasto: tyremap.com lun–ven 8–20) | 26/10/2026 |
| Varchi: via Sant'Agata e via Landolina all'incrocio nord con via Vittorio Emanuele II | autovia.it, sicurauto.it; confermati dalle relazioni OSM `enforcement` | non ufficiale | 26/10/2026 |
| Strutture ricettive: permesso temporaneo gratuito per i veicoli degli ospiti, carico/scarico bagagli a arrivo e partenza, massimo 12 ore, non più permessi delle camere, richiesta online su AMTS → `hotelCanRegister: true` | https://www.amts.ct.it/wp-content/uploads/Sostare/Disposizioni_%20operative_%20accesso_alle_ZTL_e_%20AP.pdf | ufficiale (via riassunto) | 26/10/2026 |
| Disabili ammessi con contrassegno e persona a bordo; elettriche non esenti in automatico (`exemptFuels: []`); multa 84–335 € | sicurauto.it | non ufficiale | 26/10/2026 |

Festivi: 0–24 tutti i giorni → `freeOnHolidays: false`; Sant'Agata (5 febbraio) non serve in `localHolidays` (la festa ha ordinanze di viabilità proprie, non modellate).

## Geometria: provenienza e licenza
**Da OpenStreetMap, non ufficiale** (© OpenStreetMap contributors, ODbL 1.0).
- Dati: `data/raw/geo/catania-ztl.json`, scaricato il 26/10/2026 con `Tools/fetch_osm_api.py` (bbox 37,498–37,510 / 15,080–15,096) e ridotto agli elementi usati.
- **Perimetro**: relazione [14421298](https://www.openstreetmap.org/relation/14421298) «ZTL Centro Storico» (`boundary=limited_traffic_zone`, un membro outer), semplificata a 3 m: 22 punti, 0,028 km². Le strade OSM con punto centrale dentro sono esattamente quelle dell'elenco 2022 (via Pulvirenti, via Maria Callas, via Leonardi, via Mazza, via Perrotta, piazza Scammacca, via Euplio Reina, via Sant'Orsola, via Sant'Agata).
- **Varchi**: nodi `device` delle relazioni `enforcement` 14421293 (via Sant'Agata) e 14421292 (via Landolina), `operator=Comune di Catania`, a meno di 40 m dal bordo.
- **Area pedonale**: relazione [20064601](https://www.openstreetmap.org/relation/20064601) «Area Pedonale Piazza Vincenzo Bellini».
- Controlli: Teatro Massimo Bellini dentro; Cattedrale, via Etnea e (coordinate approssimate) stazione Centrale fuori; area tra 0,01 e 0,1 km².
- Una guida descrive un perimetro più ampio (via di Sangiuliano, via Ventimiglia, via Vittorio Emanuele II, via Raddusa, via S. Maria del Rosario, via della Loggetta, via Mancini, «ZTL del 2014 attorno a piazza Bellini, poi estesa»): da verificare se coincide con l'insieme di ZTL e aree pedonali.

## Da verificare (`pending`)
Testo ufficiale e numero dell'ordinanza; orario 0–24 (solo guide); scadenza della richiesta hotel; moto; procedura disabili; aree pedonali non disegnate; perimetro più ampio citato da una guida.
