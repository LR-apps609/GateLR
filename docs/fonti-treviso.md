# Treviso: fonti della scheda ZTL

Scheda generata da `Tools/build_treviso.py` → `Resources/Cities/treviso.json` (stato **draft**: da fonti ufficiali, non ancora rivista da una persona).

## Zone
| Zona | Orari | Fonte |
|---|---|---|
| **Piazza dei Signori · ZTL del centro** (area blu della mappa ufficiale) | 0–24 tutti i giorni, festivi compresi | disciplinare 2014 («tutti i giorni della settimana e permanentemente, dalle ore 00:00 alle 24:00»); portale ZTL: varchi 1, 2, 3, 5, 6, 7 «attivo H24» (citazione) |
| **Via Manin · ZTL notturna** (striscia verde della mappa ufficiale) | 22–6 tutti i giorni | portale ZTL: «8) Via Manin - Orari di attività dalle 22:00 alle 6:00 tutti i giorni» (citazione) |

Varco 4 (Ponte San Francesco): telecamera attiva 22–6 dal lunedì al venerdì e 0–24 sabato, domenica e festivi (1/1, 6/1, Pasquetta, 25/4, 1/5, 2/6, 15/8, 1/11, 8/12, 25/12, 26/12). La zona resta 0–24 (disciplinare): scritto nei pending.

## Fonti ufficiali (lette il 27/10/2026)
| Fatto | URL | Tipo | File |
|---|---|---|---|
| 8 varchi e loro orari; elettriche/ibride ammesse con comunicazione della targa; categorie ammesse | https://www.ztltreviso.it/myportal/C_L407_ZTL/varchi (portale «ZTL nel Centro di Treviso» della Città di Treviso; pagina Angular, testo letto dal pacchetto `build.js` del portale) | ufficiale | `data/raw/treviso/ztltreviso-varchi.txt` |
| Mappa ufficiale (area blu H24, striscia verde via Manin 22–6, posizione dei varchi) | https://www.ztltreviso.it/myportal/C_L407_ZTL/api/content/download?id=63cfdcb70206d0008c0bec21 | ufficiale | `data/raw/treviso/mappa-ztl-varchi.png` |
| Disciplinare vigente linkato dal portale («Nuovo Disciplinare ZTL novembre 2017»): pass obbligatorio, comunicazione a posteriori entro cinque giorni per ospiti di strutture ricettive in ZTL e disabili, veicoli a trazione esclusivamente elettrica | https://www.ztltreviso.it/myportal/C_L407_ZTL/api/content/download?id=6377665b8dee9000a28f07f2 | ufficiale | `disciplinare-ztl-novembre-2017.txt` |
| Disciplinare vers. 4 (21/02/2017): clienti di alberghi e strutture ricettive in ZTL, per la durata del soggiorno, 00:00–24:00, sosta 20 minuti | www2.comune.treviso.it (PDF «Disciplinare ZTL vers.4») | ufficiale | `disciplinare-ztl-v4-2017.txt` |
| Disciplinare 2014 (allegato A alla DGC): regime ZTL tutti i giorni 00:00–24:00 | www2.comune.treviso.it (PDF «DISCIPLINARE ZTL», 29/07/2014) | ufficiale | `disciplinare-ztl-2014.txt` |

I due PDF di www2.comune.treviso.it sono stati letti in questa sessione; l'indirizzo esatto non è stato registrato (la home di www2 ora rimanda a www.comune.treviso.it). Le regole citate nella scheda vengono dal portale ZTL e dal disciplinare 2017 linkato dal portale, entrambi con URL.

## Pending
- Ibride: la pagina dei varchi le ammette con la targa comunicata, il disciplinare 2017 nomina solo le elettriche → nella scheda solo `electric`.
- Via Manin: il disciplinare 2014 dice 0–24 per tutte le ZTL, la pagina ufficiale dà alla telecamera di via Manin 22–6 → la scheda segue la pagina ufficiale.
- Importo delle multe non pubblicato nelle pagine ufficiali.
- La mappa My Maps incorporata nella home del portale (google.com/maps/d, mid=1hYQD5g3YkxTCzOdt9czawg6PnCQ) non è raggiungibile: il proxy rifiuta www.google.com (non aggirato).

## Geometria
- OpenStreetMap (© OpenStreetMap contributors, ODbL 1.0), API principale con `Tools/fetch_osm_api.py`, 27/10/2026, bbox 45.660–45.672 N, 12.232–12.254 E, ridotto in `data/raw/geo/treviso-ztl.json`: relazione **19430980** (`boundary=limited_traffic_zone`, way 1420376662, agosto 2025), 0,17 km². Confrontata con la mappa ufficiale: coincide con l'unione area blu + striscia verde (stessi confini lungo via Roggia, Cornarotta, piazza San Francesco, riviera, via San Leonardo, piazza Santa Maria dei Battuti, via Martiri della Libertà, Corso del Popolo, via Avogari).
- La striscia di via Manin è la parte della relazione entro 35 m dall'asse OSM di via Daniele Manin (way 107739894, 1168227718); il resto è la zona H24 (0,148 + 0,022 km²).
- Varchi: telecamere OSM 8180786497 (San Leonardo), 8176957946 (Ponte San Francesco), 8176957944 (Cornarotta), 8180571113 (via Manin); per via XX Settembre, via Martiri della Libertà, vicolo Buranelli e Calmaggiore il punto della strada più vicino al bordo della zona.
- Controlli: piazza dei Signori, Loggia dei Cavalieri, piazza Rinaldi, Calmaggiore, Isola della Pescheria dentro; via Manin nella striscia; stazione, Corso del Popolo, piazza Filodrammatici, via San Parisio, piazza della Vittoria fuori.
