# Lecce: fonti della scheda ZTL (bozza)

Scheda generata da `Tools/build_lecce.py` → `data/drafts/lecce.json` (**bozza, non nell'app**: nessuna citazione è verificata sul testo ufficiale). Il perimetro c'è (OpenStreetMap).

## Perché è ancora una bozza
Ricontrollato il 26/10/2026 dopo l'apertura della rete: **www.comune.lecce.it e comune.lecce.it rispondono ancora con rifiuto del proxy (403)**, come sgmlecce.it, albo e servizi online del Comune, regione.puglia.it. Quindi né le ordinanze (1679, 1689, 2069/2025), né i comunicati del 2026, né il regolamento ZTL sono leggibili: nessuna citazione verificabile (`quote: null`), e non si può risolvere il dubbio sui varchi h24 (Porta Napoli, Trinchese, Mocenigo, via delle Bombarde, e le delibere 2026). Per pubblicare serve il testo di almeno l'ordinanza 1679/2025 o del comunicato del 17/07/2025.

Raggiungibile invece **dati.comune.lecce.it**: scaricato il dataset ufficiale «ZTL APU CENTRO STORICO LECCE» (CC BY 4.0) → `data/raw/lecce/ztlapucomunedilecce-2014.geojson` (metadati in `dati-comune-lecce-package.json`). È del **2014** (risorsa creata il 22/12/2014): strade «Zona a Traffico Limitato H24», «H24 Domenica e Festivi, ore 21 - 6 nei giorni feriali», «Aree pedonali» e 8 punti «Varchi». Il perimetro è superato (ridefinito con la delibera del 03/04/2025) e **non** si usa; gli 8 varchi sì: 7 coincidono entro 9 m con i nodi OSM «Varco ZTL», l'ottavo è in via Casale Fornello / viale De Pietro.

Il workflow «Scarica pagine» non è stato usato per aggirare il blocco.

## Zone
- **ZTL centro storico (dentro le mura)**: una zona `restricted` a orario variabile. Non modellati a parte: i varchi h24 (Porta Napoli, Trinchese, Mocenigo, via delle Bombarde) e le aree pedonali (piazza Sant'Oronzo, via Vittorio Emanuele II, ecc.), che stanno dentro il perimetro.
- Nessuna ZTL notturna o estiva separata trovata.

## Fatti usati

| Fatto | Pagina indicata dalla ricerca | Tipo | Letto il |
|---|---|---|---|
| Dal 01/08/2025 (delibera GC n. 280 del 10/07/2025, ordinanze n. 1679 e n. 1689): nei feriali varchi spenti 10–13 e 16:30–20, attivi nelle altre ore; domenica e festivi attivi tutto il giorno | https://www.comune.lecce.it/news/dettaglio/2025/07/17/modifiche-ztl-nuove-ordinanze ; ecodallecitta.it ; autovia.it ; leccesette.it | ufficiale (via riassunto) + non ufficiali concordi | 26/10/2026 |
| «Feriali» = lunedì–sabato | tag OSM della relazione 20670025 (`vehicle:conditional=yes @ (Mo-Sa 10:00-13:00,16:30-20:00)`, `source=Città di Lecce`); ordinanza 1689 distingue «feriali» da «domenica e festivi» | non ufficiale (OSM) | 26/10/2026 |
| Porta Napoli vietata h24 tutti i giorni (ord. 1679 del 16/07/2025) | comunicato del Comune 17/07/2025; leccesette.it | ufficiale (via riassunto) | 26/10/2026 |
| Carico/scarico: feriali 5:30–9:30 e 15–16, domenica e festivi 6–9:30 (ord. 1689 del 17/07/2025, pieno vigore dal 01/01/2026) | https://comune.lecce.it/docs/default-source/altri-documenti/ztl_carico_scarico_ord_01689_17-07-2025.pdf?sfvrsn=cf14c427_6 ; comunicato 23/12/2025 | ufficiale (via riassunto) | 26/10/2026 |
| Ord. 2069 del 09/09/2025: h24 anche viale XXV Luglio/via Trinchese e via dei Mocenigo; 17 varchi in tutto | quotidianodipuglia.it (2025) | non ufficiale | 26/10/2026 |
| Delibera di giunta 11/03/2026: h24 via Mario Bernardini, via Cairoli (entrata), Porta Rudiae–via Adua (uscita), via Marino Brancaccio; via Marco Aurelio esclusa dalla ZTL, varco spostato su vico Mondo Nuovo; atto di indirizzo, da attuare | https://www.comune.lecce.it/news/dettaglio/2026/03/12/ztl-nuovi-provvedimenti-che-interessando-il-centro-storico ; citynext.it 16/03/2026 | ufficiale (via riassunto) | 26/10/2026 |
| Delibera di luglio 2026: varco di via Pietro Palumbo h24 (eccetto disabili), via delle Bombarde resta h24, nuovi sensi di marcia; serve ordinanza della Polizia Locale, data non trovata | corrieresalentino.it 07/2026 ; lagazzettadelmezzogiorno.it ; quotidianodipuglia.it ; leccesette.it | non ufficiale | 26/10/2026 |
| Hotel/B&B in ZTL: permesso HTL chiesto dalla struttura (solo arrivo/partenza, sosta 20 min); targhe trasmesse dalla struttura accreditata (foglio Excel), «preferibilmente prima dell'arrivo e comunque al massimo entro 48 ore dall'accesso» → `hotelCanRegister: true` | https://www.comune.lecce.it/aree-tematiche/imprese/servizi-comunali/permesso-di-transito-e-sosta-nelle-ztl-del-centro-storico ; Gazzetta del Mezzogiorno ; autovia.it | ufficiale (via riassunto) + non ufficiali | 26/10/2026 |
| Ingresso non registrato: «Dichiarazione di transito in ZTL» entro 48 ore via PEC (protocollo@pec.comune.lecce.it) con fattura/ricevuta | pagina permessi del Comune; regolamento ZTL (PDF) | ufficiale (via riassunto) | 26/10/2026 |
| Permessi: ~14 categorie (HTL, OCC, CUDE gratuito, C-S…); Ufficio Permessi ZTL e CUDE, viale Rossini 110, online con SPID o PEC; OCC 5 €; ~7 giorni lavorativi → nessun `ticket` | autovia.it | non ufficiale | 26/10/2026 |
| Elettriche/ibride: nessuna regola trovata → `exemptFuels: []`; moto: non trattate | ricerca web | — | 26/10/2026 |
| Multa 83–332 €, −30% entro 5 giorni | autovia.it | non ufficiale | 26/10/2026 |
| Dataset ufficiale «ZTL APU CENTRO STORICO LECCE» (CC BY 4.0, GeoJSON) | https://www.dati.gov.it/view-dataset/dataset?id=ztl-apu-centro-storico-lecce (metadati in `data/raw/lecce/dati-gov-ztl-apu-centro-storico-lecce.json`); file su dati.comune.lecce.it non raggiungibile | ufficiale | 26/10/2026 |

Festivi: domenica e festivi la ZTL è attiva tutto il giorno → `freeOnHolidays: false`, `holidaysAsSunday: true`. Patrono Sant'Oronzo (26 agosto): non confermato come festivo per la ZTL, non messo in `localHolidays` (vedi pending).

## Geometria: provenienza e licenza
**Da OpenStreetMap, non ufficiale** (© OpenStreetMap contributors, ODbL 1.0).
- Dati: `data/raw/geo/lecce-ztl.json`, estratto il 26/10/2026 con `Tools/fetch_osm_api.py` dall'API principale di OSM (www.openstreetmap.org/api/0.6, tasselli bbox 40,346–40,358 / 18,161–18,178, più `relation/20670025/full`), ridotto agli elementi usati.
- **Perimetro**: relazione [20670025](https://www.openstreetmap.org/relation/20670025) «ZTL Lecce» (`boundary=limited_traffic_zone`, creata il 10/05/2026, `source=Città di Lecce`, `website` = comunicato del 17/07/2025), un solo membro outer (way 1511705702, 92 nodi), semplificato a 4 m: 54 punti, 0,74 km².
- **Varchi**: gli 8 punti ufficiali dell'open data del Comune (CC BY 4.0, 2014); nomi dalla strada OSM del nodo «Varco ZTL» coincidente (≤ 9 m) o, per l'ottavo, dalla strada OSM più vicina (via Casale Fornello). I tag orari dei nodi OSM (`Mo-Fr 6:00-21:00`) sono vecchi e non sono usati. La stampa parla di circa 17 varchi oggi.
- Controlli nello script: Duomo, colonna di Sant'Oronzo, basilica di Santa Croce, Teatro Romano dentro; stazione, Castello Carlo V, mercato di Porta Rudiae fuori; area tra 0,4 e 1,1 km²; varchi a meno di 40 m dal bordo.
- Se si scarica il GeoJSON ufficiale (dati.comune.lecce.it, CC BY 4.0) come `data/raw/lecce/ztl_perimetro.geojson`, lo script usa quello.

## Da verificare (`pending`)
Testo ufficiale (citazione); varchi h24 dentro una zona a orario variabile; attuazione delle delibere 2026 (Bernardini, Cairoli, Brancaccio, Palumbo, via Marco Aurelio fuori); perimetro ufficiale; regola hotel (48 ore) confermata solo da riassunti; OCC per turisti; elettriche e moto; multa; 26 agosto.
