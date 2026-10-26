# Matera: fonti della scheda ZTL

Scheda generata da `Tools/build_matera.py` → `Resources/Cities/matera.json` (stato **draft**, `reviewedByHuman: false`). Dal 26/10/2026 è **nell'app** (`manifest.json`). Ogni frase usata è ricontrollata dallo script sui testi salvati in `data/raw/matera/` (estratti con pdftotext dai PDF ufficiali, letti il 26/10/2026 da comune.matera.it).

## Zone (9) e orari
Dalla tabella ufficiale «ZTL - TELECAMERE» (Ord. Dir. 147 e 148/2025), https://comune.matera.it/wp-content/uploads/2025/05/ORARI-TELECAMERE-BARRIERE.pdf → `orari-telecamere-barriere-2025.txt` (citazione di ogni zona tranne Sassi e Piave):

| Zona | Strade (atto) | Orario (feriali = festivi) |
|---|---|---|
| Sassi | via Buozzi, via Madonna delle Virtù, via D'Addozio e strade interne ai rioni Sassi, escluse via Casalnuovo e via Santo Stefano | 10–24 dal 01/07 al 15/09; 10–20:30 dal 16/09 al 30/06 (O.D. 147/2025, citazione) |
| Piave | via Piave, vico I e II F. P. Festa, via F. P. Festa, recinto I Piave, via O. Tataranni (tra via F. Volpe e via Piave) | come i Sassi (O.D. 148/2025, citazione) |
| Centro (con la Civita) | vie Scotellaro, Corso, Beccherie, Duomo, Sedile, San Francesco | 0–24 |
| San Giovanni/San Biagio | via Stigliani (da vico XX Settembre a via San Biagio), via San Biagio | 0–24 |
| Santa Cesarea | via S. Cesarea (da via Piave a vico Piave), vico Piave | 0–24 |
| Prefettura | via Roma (da via Lucana a via XX Settembre), via XX Settembre (da via Roma a via Lucana) | 20:30–24 |
| Ridola | via Ridola (da via Lucana a via Duni), via Duni, recinto, vico I e II Duni | 20:30–24 |
| Casalnuovo | via Casalnuovo | 20:30–24 |
| Stigliani | via T. Stigliani (da via Amendola a vico XX Settembre), vico XX Settembre | 20:30–24 |

Carico/scarico: 7–10:30 e 15–17 (Centro, San Biagio, Santa Cesarea, Piave, Sassi). Le APU con dissuasori (piazza Vittorio Veneto, via Ridola, via Don Minzoni, piazza Ascanio Persio, Mercato) non sono disegnate.

Festivi: stessi orari → `freeOnHolidays: false`. Patrona Madonna della Bruna (2 luglio): ordinanze proprie, non modellate.

## Altri fatti

| Fatto | Fonte (ufficiale, 26/10/2026) | File |
|---|---|---|
| Strade e varchi delle ZTL Ridola, Casalnuovo, Stigliani, Prefettura (2021), orario allora 20:30–2 (la tabella 2025 dice 20:30–24: si usa la tabella, nota in pending) | O.D. 2941/2021 | `od-2941-2021-ztl.txt` |
| Nei Sassi, durante la ZTL, divieto di transito ai clienti delle strutture ricettive per carico/scarico, salvo strutture nei Sassi con sosta privata → Sassi `hotelCanRegister: false` | O.D. 2941/2021, punto 17 | idem |
| Varchi: via Scotellaro, via Roma Sud, via Stigliani/vico XX Settembre, via Buozzi/via Casalnuovo, via D'Addozio/via Santo Stefano, via Stigliani/via Amendola, via Casalnuovo/via Cappuccini, via Duni/via Lucana, via XX Settembre/vico XX Settembre (uscita) | O.D. 270/2022 (le due righe Buozzi/D'Addozio sono scambiate dall'estrazione del testo: si usa l'abbinamento dell'ordinanza 2014 nei metadati open data) | `od-270-2022-varchi.txt`, `dati-gov-…-2014.txt` |
| Varchi Piave (via Piave/via Stigliani, vico II Festa/via Pentasuglia, via Tataranni/via Volpe) e Santa Cesarea (via S. Cesarea/via Piave), in esercizio | O.D. 148/2025, O.D. 257/2025 | `od-148-…`, `od-257-…` |
| Strutture ricettive: portale https://matera.sismic.it («RICHIESTA PASS», SPID); regolarizzazione «che non potrà avvenire trascorso il giorno solare successivo al transito» → `hotelCanRegister: true` (tranne Sassi) | Procedura per strutture ricettive e autorimesse; disciplinare (clienti senza garage: solo transito e fermata per i bagagli) | `procedura-strutture-ricettive.txt`, `disciplinare-2019.txt` |
| Elettriche: «potranno accedere alla Z.T.L., senza alcun limite di fascia oraria, purché preventivamente autorizzati» → non esentate (`exemptFuels: []`) | disciplinare | idem |
| Moto e ciclomotori: senza autorizzazione solo per raggiungere le aree di sosta riservate | disciplinare | idem |
| Disabili non in lista: numero verde 800 091 980 prima dell'accesso; Ufficio ZTL ztl@comune.mt.it, 0835 241335 | https://comune.matera.it/ztl-apu/ | `comune-ztl-apu.txt` |

## Geometria: provenienza e licenza
Nessun perimetro ufficiale scaricabile: il GeoJSON open data «ZTL_APU_MATERA_AGO2014» su dati.comune.matera.it non risponde (proxy) ed è del 2014; la «Planimetria ZTL» (PDF) è un disegno senza coordinate. Quindi **perimetro dall'elenco ufficiale delle vie con le geometrie OSM** (© OpenStreetMap contributors, ODbL 1.0):
- Dati: `data/raw/geo/matera-sassi.json`, scaricato il 26/10/2026 con `Tools/fetch_osm_api.py` (bbox 40,654–40,676 / 16,598–16,620), ridotto a strade (con id dei nodi), aree «Sasso Caveoso»/«Sasso Barisano» e telecamere con nome.
- Tratti «dall'intersezione con … all'intersezione con …»: percorso più breve sulle way OSM tra i nodi d'incrocio. Area = `osm_geo.street_area` (celle 5 m; ogni strada anche spostata di ±3 m per tenere unite le celle), semplificata a 4 m.
- Sassi: strade carrabili dell'ordinanza + strade/scalinate con punto centrale nelle due aree OSM dei Sassi, escluse Casalnuovo, Santo Stefano e le strade delle altre ZTL (0,27 km², comprende la Civita).
- Varchi: nodo OSM dell'incrocio indicato dall'atto; per «via Scotellaro» e «via Roma Sud» il nodo OSM della telecamera («ZTL Centro», «ZTL Prefettura»).
- Controlli: San Pietro Barisano e Casa Grotta dentro i Sassi; piazza del Sedile e piazza Duomo dentro il Centro; stazione Matera Centrale e piazza Vittorio Veneto fuori da tutte; varchi a meno di 40 m dalla zona.

## Da verificare (`pending`)
Perimetri approssimativi (aree delle strade); orari serali 20:30–24 (tabella 2025) contro 20:30–2 (ordinanza 2021); regole per gli ospiti negli hotel dei Sassi; elettriche solo con permesso; moto.
