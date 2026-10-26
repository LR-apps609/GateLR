# Siracusa (Ortigia): fonti della scheda ZTL

Scheda generata da `Tools/build_siracusa.py` → `Resources/Cities/siracusa.json` (stato **draft**, `reviewedByHuman: false`). Dal 26/10/2026 è **nell'app** (`manifest.json`), con perimetro e varchi da OpenStreetMap.

## Fonti ufficiali lette (26/10/2026)
- Pagina «ZTL – Zona a Traffico Limitato» del Comune, https://www.comune.siracusa.it/area_tematica/ztl-zona-a-traffico-limitato (ultimo aggiornamento 20/07/2026) → `data/raw/siracusa/comune-ztl-zona-a-traffico-limitato.txt`. Da qui la **citazione** (orari), le regole per le strutture ricettive (Connect Pass dall'11/06/2026, solo transito, 48 ore, limite camere), le fasce di carico/scarico e l'elenco delle ordinanze (O.D.C.S. 499/16, 638/16, 322/2019, 493/2023, 304/2025, 417/2025, **189/2026**, **292/2026**).
- Scheda «Rilascio Pass di sosta/transito nella ZTL di Ortigia», https://www.comune.siracusa.it/servizio/rilascio-di-pass-di-sosta-transito-nella-ztl-di-ortigia → `data/raw/siracusa/comune-rilascio-pass-ztl-ortigia.txt`: categorie e costi dei pass (temporaneo 5 €, per «necessità episodiche e di breve durata motivate»), orari invernali 2025–26 (O.D. 791 del 23/12/2025: venerdì e prefestivi 20–24, sabato 17–24, domenica e festivi 11–24, fino al 31/03/2026).
- I PDF delle ordinanze su static-www.comune.siracusa.it **non** erano scaricabili (proxy 403): il testo dell'ordinanza 189/2026 non è stato letto; gli orari citati sono quelli della pagina ufficiale.
- I riassunti della ricerca web (`websearch-*.txt`) restano per i fatti di contorno (stampa, moto, multe), segnati come non ufficiali.

## Zone
- **ZTL di Ortigia**: unica zona, `restricted`, a orari (vedi sotto). La punta nord (piazza Pancali, Tempio di Apollo, largo XXV Luglio, parcheggio Talete) è fuori.
- Non modellate: aree pedonali interne (piazza Duomo ecc.), variazioni per feste (Santa Lucia, Capodanno).

## Fatti usati

| Fatto | Pagina indicata | Tipo | Letto il |
|---|---|---|---|
| Dal 01/04/2026 (ordinanza n. 189 del 30/03/2026): lun–sab 11–15:30 e 17–2 del giorno dopo; domenica e festivi 10–2 del giorno dopo; esenti residenti e autorizzati | https://www.comune.siracusa.it/area_tematica/ztl-zona-a-traffico-limitato («lists the same weekday and Sunday windows»); siracusaoggi.it; siracusapress.it | ufficiale (via riassunto) + stampa | 26/10/2026 |
| Ordinanza n. 292 dell'08/05/2026 (contenuto non letto; la stampa di maggio parla di consegne merci anche nei festivi) | pagina ZTL del Comune; siracusapress.it | ufficiale (via riassunto) | 26/10/2026 |
| Carico/scarico 2–11 e 15:30–17, stalli con disco orario 30 min | siracusaoggi.it (aprile 2026) | non ufficiale | 26/10/2026 |
| Inverno 2025–26: O.D. 791 del 23/12/2025, dal 24/12/2025 al 31/03/2026, venerdì e prefestivi 20–24, sabato 17–24, domenica e festivi 11–24; ordinanza per l'inverno 2026–27 non trovata | siracusaoggi.it (dicembre 2025) | non ufficiale | 26/10/2026 |
| Strutture ricettive: piattaforma Connect Pass dall'11/06/2026 (canali precedenti disattivati); targa e durata del soggiorno al Comando entro 48 ore dal transito; pass solo per accesso/carico bagagli, non per sosta; numero giornaliero legato alle camere → `hotelCanRegister: true` | https://www.comune.siracusa.it/area_tematica/ztl-zona-a-traffico-limitato ; https://www.comune.siracusa.it/novita/online-listanza-per-la-richiesta-pass-ztl-temporanei-per-alberghi ; siracusaturismo.it ; siracusapress.it | ufficiale (via riassunto) | 26/10/2026 |
| Moto fermate ai varchi come le auto; elettriche e disabili: regole di Ortigia non trovate (`exemptFuels: []`); multa 84–335 € | blogsicilia.it; sicurauto.it | non ufficiale | 26/10/2026 |

Festivi: nei festivi vale l'orario della domenica → `holidaysAsSunday: true`, `freeOnHolidays: false`. Santa Lucia (13 dicembre, patrona): non messa in `localHolidays` (non confermato che valga come festivo per la ZTL; la festa ha ordinanze proprie).

## Geometria: provenienza e licenza
**Da OpenStreetMap, non ufficiale** (© OpenStreetMap contributors, ODbL 1.0).
- Dati: `data/raw/geo/siracusa-ztl.json`, scaricato il 26/10/2026 con `Tools/fetch_osm_api.py` (bbox 37,054–37,068 / 15,286–15,298), ridotto agli elementi usati.
- **Perimetro**: relazione [14425414](https://www.openstreetmap.org/relation/14425414) «ZTL Siracusa» (`boundary=limited_traffic_zone`, `motor_vehicle:conditional=permit @ (Mo-Sa 00:00-02:00, 11:00-15:30, 17:00-24:00; Su, PH 00:00-02:00,10:00-24:00)`, uguale agli orari 2026: lo script si ferma se cambia), semplificata a 4 m: 70 punti, 0,38 km².
- **Varchi**: nodi `device` delle relazioni `enforcement` 14438941 (via Vittorio Veneto), 14438943 (via Malta / Riva della Darsena), 14438942 (via dei Mille / corso Umberto I), `operator=Comune di Siracusa`; nomi dalla strada OSM più vicina; a meno di 4 m dal bordo.
- Controlli: piazza Duomo e Ipogeo dentro; Tempio di Apollo, parcheggio Talete, Molo Sant'Antonio fuori; area tra 0,2 e 0,6 km².

## Da verificare (`pending`)
Testo delle ordinanze 189 e 292/2026; orario invernale 2026–27 (atteso a dicembre); elettriche, moto, disabili; multa; feste; perimetro ufficiale.
