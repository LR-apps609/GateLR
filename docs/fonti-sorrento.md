# Sorrento: fonti della scheda ZTL

Scheda generata da `Tools/build_sorrento.py` → `Resources/Cities/sorrento.json` (stato **draft**, `reviewedByHuman: false`). Dal 27/10/2026 è **nell'app** (`manifest.json`) e sul sito, con area e varchi da OpenStreetMap sulle strade elencate nell'ordinanza.

## Fonti ufficiali lette (27/10/2026)
| Fatto | URL | Tipo | Letto il |
|---|---|---|---|
| **Citazione**: periodi di vigenza 1 aprile – 25 ottobre e 7 dicembre – 6 gennaio (solo festivi e prefestivi); orari feriali 19:30–4, festivi 10–13 e 19:30–4; elenco delle strade della «ZTL CENTRO»; 4 varchi (Fuorimura/Caruso, Corso Italia al Carmine, Correale al parcheggio Lauro, San Francesco/De Maio); permessi secondo il regolamento D.C. 7 del 16/03/2023 modificato con D.C. 28 del 26/05/2023; sosta solo negli stalli | Ordinanza n. 230 del 16/06/2023, https://www.comune.sorrento.na.it/download/b81cb24c5b6b4de7a26a24f08057427e/ORD%20N.%20230.pdf → `data/raw/sorrento/ord-230-2023.txt` | ufficiale | 27/10/2026 |
| Stessi periodi e orari; permesso annuale (scade il 31/12, rinnovo 1/12–28/2); permessi temporanei sul portale online «disponibile dal 1 aprile» o chiamando il numero verde 800 477 311 al passaggio | https://www.comune.sorrento.na.it/it/novita/page/z-t-l-centro (agg. 18/08/2025) → `comune-ztl-centro.txt` | ufficiale | 27/10/2026 |
| Hotel e strutture: portale «permesso di transito in ZTL per strutture», permesso temporaneo, rilascio «da immediato a 30 gg» | https://www.comune.sorrento.na.it/it/servizi/page/richiesta-autorizzazione-ztl-per-strutture (agg. 05/09/2025) → `comune-ztl-strutture.txt` | ufficiale | 27/10/2026 |
| Permesso temporaneo per cittadini con esigenze documentate | https://www.comune.sorrento.na.it/it/servizi/page/rilascio-autorizzazioni-ztl → `comune-ztl-temporanea.txt` | ufficiale | 27/10/2026 |
| Comunicato 28/03/2025: ZTL 1/4–25/10, tutti i giorni 19:30–4, festivi anche 10–13; posizione dei 4 varchi elettronici | https://www.comune.sorrento.na.it/it/novita/page/sorrento-viabilita-ritorna-la-zona-a-traffico-limitato → `comune-news-2025-03-28-ritorna-ztl.txt` | ufficiale | 27/10/2026 |

Il regolamento dei permessi (`nuovo-regolamento-ZTLCentro-DCC28-2023.pdf`, 7 MB) è una scansione senza testo: non è stato letto (nessun OCR nel sandbox). Esenzioni per elettriche, moto e disabili quindi non verificate.

## Fonti non ufficiali
- Stagione 2026 (1 aprile – 25 ottobre, stessi orari e varchi): metropolisweb.it 30/03/2026, ilgazzettinovesuviano.com 31/03/2026, ansa.it 30/03/2026; multa 83–332 € (tyremap.com). Riassunto in `data/raw/sorrento/websearch-1-stagione-2026.txt`. Nessuna ordinanza 2026 trovata: la base resta la n. 230/2023.

## Come sono modellati gli orari
- 1/4–25/10: tutti i giorni 19:30–4 (la parte dopo mezzanotte appartiene al giorno d'inizio); domenica e festivi anche 10–13 (`holidaysAsSunday: true`, `freeOnHolidays: false`).
- 7/12–6/1 («limitatamente ai festivi ed ai prefestivi»): sabati 19:30–4; domeniche 10–13 e 19:30–4; le vigilie che non sono sabati (7/12, 24/12, 31/12, 5/1) 19:30–4 con stagioni di un giorno; i festivi nazionali del periodo (8/12, 25/12, 26/12, 1/1, 6/1) come la domenica. Lettura nostra di «prefestivi», nei pending.
- Patrono (Sant'Antonino, 14 febbraio): fuori da entrambi i periodi, non serve.

## Geometria
- OpenStreetMap (© OpenStreetMap contributors, ODbL 1.0), scaricato il 27/10/2026 dall'API principale con `Tools/fetch_osm_api.py` e ridotto in `data/raw/geo/sorrento-ztl.json` (strade dell'ordinanza e vicine, telecamere, parcheggio Achille Lauro). Nessuna relazione ZTL in OSM, nessun open data (Comune o dati.regione.campania.it).
- Area = `osm_geo.street_area` sulle strade dell'ordinanza: viale Enrico Caruso, piazza Tasso, via Luigi de Maio, piazza Sant'Antonino, via San Francesco, via Vittorio Veneto, piazza della Vittoria (intere); Corso Italia solo way 220483717 e 766566070 (da piazza Tasso all'incrocio con via Marziale, controllato nel builder); via Correale solo way 1127707893 (dal nodo davanti al parcheggio Lauro a piazza Tasso); via Marina Grande solo il tratto carrabile 657729900 (il tratto basso è separato da una scalinata e senza varco). 0,067 km².
- Varchi: nodo 679052212 (via Fuorimura / viale Caruso), telecamera OSM 10907830588 (Corso Italia davanti al Carmine), nodo 10006422062 (via Correale al parcheggio Lauro), nodo 1622123958 (via San Francesco / via De Maio).
- Controlli: piazza Tasso e piazza Sant'Antonino dentro; stazione Circumvesuviana, Corso Italia pedonale e parcheggio Lauro fuori.

## Host bloccati dal proxy (403, non aggirati)
- `sorrento.domosweb.it` (portali dei permessi ZTL).

## Pending (nella scheda)
Lettura dei prefestivi invernali; stagione 2026 confermata solo dalla stampa; termine per la targa degli ospiti non indicato; elettriche/moto/disabili non verificati (regolamento scansionato); area non ufficiale.
