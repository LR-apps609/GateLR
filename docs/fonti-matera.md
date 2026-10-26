# Matera: fonti della scheda ZTL (bozza)

Scheda generata da `Tools/build_matera.py` → `data/drafts/matera.json` (**bozza, non nell'app**: nessuna citazione verificata sul testo ufficiale in vigore; perimetri ricavati dalle strade).

## Perché è una bozza
Il 26/10/2026 dal sandbox comune.matera.it, www.comune.matera.it, dati.comune.matera.it, materawelcome.it e la stampa locale rispondevano con rifiuto del proxy (403, host non consentito per la sessione); WebFetch non risolveva gli host. Il workflow «Scarica pagine» **non** è stato usato per aggirare il blocco (lanciato una sola volta, `pagine-matera-1`, per Overpass: risposta 406, non usata). Raggiungibili solo www.dati.gov.it, www.openstreetmap.org (API) e la ricerca web.

Le regole 2024–2026 vengono dai **riassunti della ricerca web** (`data/raw/matera/websearch-*.txt`, non testo letterale). L'unico testo ufficiale letterale è l'**estratto dell'ordinanza del 2014** nei metadati del dataset «ZTL e APU» su dati.gov.it (`data/raw/matera/dati-gov-ztl-e-apu-estratto-ordinanza-2014.txt`), usato solo per l'elenco delle strade e per le categorie esenti: i suoi orari sono superati. `quote` è `null`.

## Zone
- **Sassi** (Sasso Barisano e Caveoso, ZTL Sassi): 10–20:30 dal 16/09 al 30/06, 10–24 dal 01/07 al 15/09, tutti i giorni.
- **Centro e Civita** (ZTL Centro: vie Scotellaro, Corso, Beccherie, Duomo, Sedile, San Francesco): 0–24 tutti i giorni.
- **San Biagio** (ZTL San Giovanni/San Biagio: via Stigliani, via San Biagio): 0–24 tutti i giorni.
- Non modellate: ZTL Prefettura (via Roma, via XX Settembre) e ZTL Ridola (via Ridola, vico Duni), 20:30–24 (la ricerca riporta anche una fascia stagionale per Ridola, in contrasto); ZTL Mercato (orari non trovati); ZTL Piave (O.D. 148/2025, non approfondita); aree pedonali (APU).

## Fatti usati

| Fatto | Pagina indicata | Tipo | Letto il |
|---|---|---|---|
| ZTL Sassi: «Periodo estivo compreso dal 01 luglio al 15 settembre, di ogni anno, dalle ore 10.00 alle ore 24:00; periodo invernale compreso dal 16 settembre al 30 giugno, di ogni anno, dalle ore 10.00 alle ore 20:30» (O.D. 147/2025) | https://comune.matera.it/wp-content/uploads/2025/05/Ordinanza_Dirigenziale_147_2025-ZTL-SASSI.pdf ; tabella https://comune.matera.it/wp-content/uploads/2025/05/ORARI-TELECAMERE-BARRIERE.pdf | ufficiale (via riassunto) | 26/10/2026 |
| Varchi Sassi: via Buozzi, via Madonna delle Virtù, via D'Addozio; carico/scarico 7–10:30 e 15–17 | tabella orari 2025 | ufficiale (via riassunto) | 26/10/2026 |
| Apertura sperimentale 13–15:30 dal 19/01 al 15/03/2026 (finita); nessuna modifica per l'estate 2026 trovata | oltrefreepress.com (Confesercenti) | non ufficiale | 26/10/2026 |
| ZTL Centro e San Giovanni/San Biagio 0–24; Prefettura e Ridola 20:30–24 | https://www.comune.matera.it/wp-content/uploads/2025/03/Orari-Telecamere-Barriere-dal-09.09.2024.pdf (O.D. 261/2024) | ufficiale (via riassunto) | 26/10/2026 |
| Civita e San Biagio 0–24 dal 01/01 al 31/12 | tolltracker.eu; estratto 2014 («Zona AZZURRA … dal 01/01 al 31/12 dalle ore 00.00 dalle ore 24.00») | non ufficiale + ufficiale datato | 26/10/2026 |
| Strutture ricettive: targhe comunicate sul portale matera.sismic.it («RICHIESTA PASS»), solo per le ZTL dove gli ospiti possono entrare per i bagagli → `hotelCanRegister: true`; scadenza non trovata | https://comune.matera.it/wp-content/uploads/2024/01/Procedura-per-comunicazione-transiti-da-parte-di-strutture-ricettive-e-autorimesse.pdf | ufficiale (via riassunto) | 26/10/2026 |
| 2014: esclusi dal divieto autorizzati, forze dell'ordine, soccorso, disabili, «veicoli a completa trazione elettrica», taxi, NCC; moto solo transito | estratto 2014 (dati.gov.it) | ufficiale ma datato → elettriche **non** esentate (`exemptFuels: []`) | 26/10/2026 |
| Disabili: avviso preventivo al numero verde 800 091 980 o e-mail a ztl@comune.mt.it entro 48 ore | tag `description` dei nodi OSM dei varchi «ZTL Prefettura» e «ZTL San Giovanni/San Biagio» | non ufficiale | 26/10/2026 |

Festivi: stessi orari tutti i giorni → `freeOnHolidays: false`. Patrona Madonna della Bruna (2 luglio): non serve in `localHolidays`; la festa ha ordinanze di viabilità proprie, non modellate.

## Geometria: provenienza e licenza
**Da OpenStreetMap, non ufficiale** (© OpenStreetMap contributors, ODbL 1.0). In OSM Matera non ha aree ZTL, solo nodi dei varchi.
- Dati: `data/raw/geo/matera-sassi.json`, scaricato il 26/10/2026 con `Tools/fetch_osm_api.py` (bbox 40,658–40,672 / 16,600–16,616), ridotto a strade, scalinate, le due aree `place=neighbourhood` «Sasso Caveoso» (way 326515081) e «Sasso Barisano» (way 326515348) e gli 8 nodi varco con nome.
- **Sassi**: `osm_geo.street_area` (celle 5 m, chiusura 40 m) sulle strade carrabili nominate dall'ordinanza più ogni strada/scalinata con punto centrale dentro le due aree dei Sassi, escluse via Casalnuovo, via Santo Stefano e le strade delle ZTL Centro e Ridola: 0,265 km². Comprende la Civita (racchiusa dai Sassi), che è anche nella zona Centro.
- **Centro e Civita**: area delle strade dell'elenco (più i Gradoni Duomo, che uniscono il Sedile alla Civita), chiusura 60 m: 0,035 km².
- **San Biagio**: area di via Tommaso Stigliani e via San Biagio, chiusura 60 m: 0,002 km² (solo le strade).
- Varchi: nodi OSM «ZTL Sassi», «ZTL Via D'addozio», «ZTL Centro», «ZTL San Giovanni/San Biagio», «ZTL Via Tommaso Stigliani» (vicini al bordo della rispettiva zona).
- Controlli: San Pietro Barisano e Casa Grotta nei Sassi dentro i Sassi; piazza del Sedile e piazza Duomo dentro il Centro; via San Biagio dentro San Biagio; piazza Vittorio Veneto e stazione Matera Centrale fuori.
- Esiste un perimetro **ufficiale** (2014): `ZTL_APU_MATERA_AGO2014.json`/`.kml` su dati.comune.matera.it (catalogato su dati.gov.it). Salvandolo come `data/raw/matera/ztl_sassi.geojson`, `ztl_centro.geojson`, `ztl_san-biagio.geojson` lo script usa quelli.

## Da verificare (`pending`)
Testo delle ordinanze 147/2025 e 261/2024; orari 2026 dei Sassi; ZTL Prefettura, Ridola, Mercato, Piave non modellate; perimetri approssimativi; scadenza hotel; elettriche e moto; procedura disabili.
