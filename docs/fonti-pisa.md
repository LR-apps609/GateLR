# Pisa: fonti e stato delle verifiche

Letture del **24/10/2026**. Scheda `data/drafts/pisa.json` (bozza, **non nell'app**) in stato **draft** (`reviewedByHuman: false`), generata da `Tools/build_pisa.py` a partire dai file in `data/raw/pisa/`.

**Raggiungibilità:** www.comune.pisa.it funziona. Le pagine si leggono via API OpenCity (`/api/opendata/v2/content/read/<id>`), e i JSON sono salvati come `comune-pisa-content-<id>.json`. Non raggiungibili (CONNECT 403 o DNS): pisamo.it, mobilita.pisamo.it/.net, varchi.pisamo.it, opendata.comune.pisa.it, overpass-api.de e i mirror, api.openstreetmap.org, geofabrik. Su dati.gov.it (CKAN) non c'è nessun dataset ZTL del Comune di Pisa: `package_search` per "pisa ztl" dà 0 risultati, e per "pisa" escono solo i dati acustici RNDT.

## Fatti e fonti

| Fatto | Fonte | Stato |
|---|---|---|
| Le strutture ricettive registrano le targhe dei clienti su un portale web: *"Solo alle strutture ricettive professionali: Alberghi, B&B e similari"*. Serve la registrazione, soggetta ad approvazione. Portale: https://varchi.pisamo.it/tzi/ | https://www.comune.pisa.it/Servizi/Registrazione-Targhe-per-accesso-veicoli-in-ZTL (mod. 03/08/2026; obj 3404, 13536) | **Verificato** → `hotelCanRegister: true` |
| Clienti delle strutture ricettive: 12 € per 24 ore (accesso a ZTL e ZSC e sosta sulle strisce blu). La targa va inserita sul portale Pisamo, e i permessi non possono superare il numero di camere | https://www.comune.pisa.it/Novita/Comunicati/Turismo-e-mobilita-in-centro-cambia-la-sosta-per-i-clienti-delle-strutture-ricettive (20/02/2023; obj 5972) | Comunicato del 2023: **da confermare** (pending) |
| Tempo per caricare la targa portato da 6 a 10 ore; transiti caricabili fino a 3 giorni consecutivi; in vigore dal 6/3/2023 | https://www.comune.pisa.it/Novita/Comunicati/Rinviate-al-6-marzo-le-nuove-modalita-di-sosta-e-accesso-alla-Ztl-per-le-strutture-ricettive (28/02/2023; obj 5674) | **Da confermare** (pending) |
| Nel 2022 i permessi temporanei erano riservati ai clienti di alberghi e pensioni dentro la ZTL, B&B esclusi (modifica dell'ord. 486/2010) | https://www.comune.pisa.it/Novita/Comunicati/Viabilita-accesso-a-ZTL-permessi-temporanei-solo-per-clienti-di-alberghi-e-pensioni (19/08/2022; obj 5893) | Storico. Contraddetto dalla pagina del servizio del 2026, che cita anche i B&B |
| ZTL Stadio (Porta a Lucca): attiva nelle partite casalinghe del Pisa SC, *"due ore prima del fischio d'inizio"* fino al termine del primo tempo. Moto libere. Elenco dei varchi per nome di via, senza coordinate | https://www.comune.pisa.it/Novita/Comunicati/Calcio-con-l-avvio-della-nuova-stagione-torna-attiva-la-ZTL-Stadio-in-occasione-delle-partite-casalinghe-del-Pisa-SC (10/08/2026; obj 30326; vedi anche 30591, 31288, 27780) | Verificato, ma **non modellato**: dipende dal calendario delle partite. Il 22/10/2026 il sanzionamento automatico non era ancora attivo (obj 31288) |
| ZTL notturna dei Lungarni: ven, sab e dom 22–5 (proroghe del 2022) | obj 5445, 5498 (2022) | **Superato o ignoto**, non modellato |
| Area pedonale urbana di via Corsica e piazza Buonamici, 24 ore su 24 | obj 28250 (13/03/2026), 18556 (2024) | Verificato, **senza geometria**, non modellata |
| Auto elettriche ammesse in ZTL solo per il 2011 (ord. 487/2010). L'ordinanza cita le ZTL "Nord, Sud e dei Lungarni" (ord. 486/2010 e 150/2010) | `ordinanza-487-2010-veicoli-elettrici.pdf` | Regola attuale **ignota** → `exemptFuels: []` |
| Orari 2002 (7–19 in alcuni quartieri, 0–24 a San Martino e sull'asse turistico) | `ordinanza-303-2002-riepilogo-ztl.pdf` | **Superato** (ord. 486/2010 e regolamento in vigore dal 1/1/2025, non pubblicati online). Non usato |
| Nuovo regolamento ZTL/ZSC dal 1/1/2025: 1 targa per permesso, residenti e artigiani | obj 20500 | Non riguarda i turisti |
| Contatti: Ufficio ZTL Varchi Elettronici, pm.ztl@comune.pisa.it, 050 910828; Pisamo 050 7062 | obj 13525, 30326 | Verificato |

## Cosa resta da verificare (pending nella scheda)

- **Orari della ZTL del centro: non trovati in nessuna fonte ufficiale raggiungibile.** Solo guide non ufficiali (fleetmagazine.com, sicurauto.it) parlano di "24 ore su 24, tutti i giorni, festivi compresi". La scheda usa una fascia **prudenziale 0–24 tutti i giorni**: è una scelta di GateLR e non un dato del Comune, ed è dichiarata nel primo punto pending. `freeOnHolidays: null`.
- Settori: il Comune parla di ZTL "Nord", "Sud", "Lungarni" (2010) e di quartieri (San Francesco, Santa Maria, San Martino, Sant'Antonio). Composizione e orari attuali sono ignoti, quindi la scheda ha **una sola zona**.
- Nessun ticket giornaliero per turisti trovato (`ticket` assente). Il servizio "Autorizzazione giornaliera" (obj 3414) vale solo per disabili e taxi/NCC.
- Prezzo (12 €/24 h) e scadenza (10 ore) per gli ospiti delle strutture: dati del 2023.
- Varchi: elenco e coordinate non pubblicati nelle fonti ufficiali aperte. Nel JSON ci sono i 15 di OpenStreetMap, da verificare.

## Geometria

**Perimetro: nessuno. Varchi: 15, da OpenStreetMap** (© OpenStreetMap contributors, ODbL 1.0, scritto nel campo `license`).

- Dati: `data/raw/geo/pisa-ztl.json` e `pisa-gates.json`, scaricati con `Tools/fetch_geo.py` (GitHub Actions, Overpass `out geom`).
- La relazione [9342809](https://www.openstreetmap.org/relation/9342809) «Zona a Traffico Limitato» (`type=enforcement`, `operator=Comune di Pisa`) contiene **solo le 15 telecamere** (ruolo `device`): niente contorno e niente strade, quindi non si può ricavare un perimetro senza inventarlo. I 15 varchi sono nel JSON (id `pi-osm<id nodo>`, nome «Varco ZTL»), con la nota «posizioni da OpenStreetMap, da verificare».
- Le mura (`pisa-walls.json`) racchiudono tutta la città storica, che non coincide con la ZTL (settori Nord, Sud e Lungarni): non sono usate.
- `Tools/build_pisa.py` usa da solo un perimetro se in `pisa-ztl.json` compare una relazione `boundary=limited_traffic_zone` (o se si salva `data/raw/pisa/osm-ztl.json` con una way chiusa).

**Pisa resta in `data/drafts/` anche con un perimetro**: nello script `HOURS_OFFICIAL = False`, perché la fascia 0–24 è una scelta prudenziale di GateLR e non un orario del Comune. Quando gli orari saranno verificati, si mette `True` e si toglie il primo punto «pending».

La Fig. 2-1 del Piano del traffico del 2002 ("Il Centro Storico e la ZTL", obj 18166) è una mappa raster datata, ed è stata scartata.

## File in data/raw/pisa/

`comune-pisa-content-{3404,13536,3414,13525,5972,5674,5893,20500,30326,30591,31288,27780,27924,28250,18556,5445,5498,28529}.json`, `comune-pisa-search-ZTL-p1.json`, `ordinanza-303-2002-riepilogo-ztl.pdf`, `ordinanza-487-2010-veicoli-elettrici.pdf`. Licenza dei contenuti del sito: CC BY 4.0, come dichiarato nei metadati dei documenti.
