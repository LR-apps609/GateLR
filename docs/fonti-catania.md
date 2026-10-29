# Catania: fonti della scheda ZTL

Scheda generata da `Tools/build_catania.py` → `Resources/Cities/catania.json` (stato **draft**, `reviewedByHuman: false`). Dal 26/10/2026 è **nell'app** (`manifest.json`); dal 29/10/2026 il perimetro segue le vie perimetrali ufficiali (linee delle strade OSM), varchi e aree pedonali da OpenStreetMap.

## Fonte ufficiale letta (26/10/2026)
«Disposizioni operative per la gestione degli accessi alle Zone a Traffico Limitato ed Aree Pedonali» (Comune di Catania / AMTS Catania), https://www.amts.ct.it/wp-content/uploads/Sostare/Disposizioni_%20operative_%20accesso_alle_ZTL_e_%20AP.pdf → `data/raw/catania/amts-disposizioni-operative-ztl-ap.txt` (pdftotext). Da qui:
- **citazione**: «La zona a traffico limitato e le aree pedonali di cui all’articolo 1 sono in vigore h 24 tutti i giorni dell’anno.» (art. 3) → il dubbio sull'orario (un sito indicava lun–ven 8–20) è risolto: 0–24;
- perimetro (via di Sangiuliano, via Mancini, via Euplio Reina, via della Loggetta, via S. Maria del Rosario, via Sant'Agata, via Vittorio Emanuele, via Leonardi, via Valle, via Landolina; le vie perimetrali sono fuori) e vie interne (Euplio Reina, piazza Ogninella, via Sant'Orsola, via Perrotta, piazza Scammacca, via Pulvirenti, via Sant'Agata, via Mazza, via Leonardi, via Birreria);
- aree pedonali: San Giovanni Li Cuti (non disegnata), piazza Duomo e via Etnea da via Dusmet a piazza Stesicoro, via Rapisarda e piazza Bellini;
- strutture ricettive (art. 8): permesso sulla piattaforma AMTS per scarico bagagli nei giorni di arrivo e partenza, al massimo 12 ore, non più permessi delle camere → `hotelCanRegister: true`;
- elettriche (art. 17): permesso di transito su domanda → non esentate; disabili (art. 15): registrazione online di targa e contrassegno; transiti non registrati giustificabili entro 48 ore (art. 4); carico/scarico 6–8 e 14–16; permessi gratuiti.
www.comune.catania.it non rispondeva: il comunicato del 2022 (avvio delle sanzioni dal 28/07/2022) resta letto tramite ricerca web.

## Zone
- **ZTL Centro Storico** attorno al Teatro Massimo Bellini: unica ZTL trovata. `restricted`, 0–24 tutti i giorni.
- **Aree pedonali** (campo `pedestrian`): piazza Vincenzo Bellini (relazione OSM 20064601) e via Etnea da via Dusmet a piazza Stesicoro con piazza Duomo (way OSM `highway=pedestrian` fino a lat 37,5078, area con `osm_geo.street_area`). Non disegnata: San Giovanni Li Cuti.

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
- **Perimetro** (rifatto il 29/10/2026): tracciato sulle linee di mezzeria OSM delle **vie perimetrali dell'elenco ufficiale** (art. 1 delle Disposizioni AMTS), nell'ordine del testo: via Antonino di Sangiuliano, via Antonino Mancini (OSM «Via Antonio Mancini»), via Euplio Reina fino a via della Loggetta, via della Loggetta, via Santa Maria del Rosario, via Sant'Agata fino a via Vittorio Emanuele, via Vittorio Emanuele, via Leonardi fino a via Valle, via Valle (OSM «Via Domenico Danzuso», `old_name=Via Valle`), via Landolina; tra la fine di via Landolina e via di Sangiuliano il confine segue l'area pedonale di piazza Bellini/via Rapisarda (art. 1 c. 5: regole proprie). Semplificato a 3 m: 19 punti, 0,046 km². Le vie del file sono state scaricate il 29/10/2026 con `Tools/fetch_osm_api.py` e aggiunte a `data/raw/geo/catania-ztl.json`.
  - Prima il perimetro era la relazione OSM [14421298](https://www.openstreetmap.org/relation/14421298) (22 punti, 0,028 km²): copriva circa il 60% della ZTL ufficiale e lasciava fuori l'isolato tra via Mancini, via di Sangiuliano e via Sant'Orsola (con via Cestai) e quello tra via della Loggetta e via Sant'Agata, che le vie perimetrali del Comune racchiudono.
  - Controlli in `build_catania.py`: dentro le vie interne dell'elenco (via Perrotta, via Pulvirenti, via Mazza, via Maria Callas = ex via Birreria, via Sant'Orsola, piazza Scammacca, piazza Ogninella = OSM «Piazza Emilio Greco», via Euplio Reina dopo via della Loggetta) e il Teatro Massimo; fuori Cattedrale, via Etnea, stazione e piazza Bellini; varchi a meno di 15 m dal bordo; area tra 0,03 e 0,06 km².
- **Varchi**: nodi `device` delle relazioni `enforcement` 14421293 e 14421292, `operator=Comune di Catania`. Sono dove l'elenco ufficiale fa cominciare le vie interne: via Sant'Agata «dopo l'incrocio con via Santa Maria del Rosario» (salendo da via Vittorio Emanuele, ~55 m più a nord) e via Leonardi «dopo l'incrocio con via Valle» (arrivando da via Landolina). I nomi dei varchi ora dicono questi incroci (prima «… / Via Vittorio Emanuele II», come le guide).
- **Area pedonale**: relazione [20064601](https://www.openstreetmap.org/relation/20064601) «Area Pedonale Piazza Vincenzo Bellini».
- Una guida descrive un perimetro più ampio (via di Sangiuliano, via Ventimiglia, via Vittorio Emanuele II, via Raddusa, via S. Maria del Rosario, via della Loggetta, via Mancini, «ZTL del 2014 attorno a piazza Bellini, poi estesa»): non coincide con l'elenco ufficiale delle Disposizioni AMTS, che è quello usato.

## Da verificare (`pending`)
Testo ufficiale e numero dell'ordinanza; orario 0–24 (solo guide); scadenza della richiesta hotel; moto; procedura disabili; aree pedonali non disegnate.
