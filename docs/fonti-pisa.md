# Pisa: fonti e stato delle verifiche

Letture del **24–25/10/2026**. Scheda generata da `Tools/build_pisa.py` a partire dai file in `data/raw/pisa/`. Oggi è in `data/drafts/pisa.json` (bozza, **non nell'app**) solo perché manca il perimetro: orari e regole sono pronti. Lo script la sposta da solo in `Resources/Cities/pisa.json` quando c'è `data/raw/geo/pisa-streets.json` e i controlli di plausibilità passano.

**Raggiungibilità:** www.comune.pisa.it funziona. Le pagine si leggono via API OpenCity (`/api/opendata/v2/content/read/<id>`, salvate come `comune-pisa-content-<id>.json`), e la ricerca `q = 'ZTL'` (227 risultati, indice in `comune-pisa-search-ZTL-index.json`) ha portato alle ordinanze storiche della sezione «Documenti albo pretorio». Restano non raggiungibili da qui (CONNECT 403 o DNS), anche ritentando il 25/10: pisamo.it, mobilita.pisamo.it/.net, varchi.pisamo.it, albopretorio.comune.pisa.it, opendata.comune.pisa.it, web.archive.org, overpass-api.de e i mirror, api.openstreetmap.org. Non si aprono neanche le fonti non ufficiali (pisatoday.it, viviamopisa.it, cnapisa.it): di queste si sono letti solo i risultati di ricerca. Su dati.gov.it (CKAN) non c'è nessun dataset ZTL del Comune di Pisa.

## Zone

| Zona | Orari | Nella scheda |
|---|---|---|
| **ZTL Centro Storico Nord** (a nord dell'Arno: Duomo/Miracoli, Cavalieri, San Francesco, Santa Maria) | **0–24 tutti i giorni**, festivi compresi | Sì (`pisa-ztl-nord`) |
| **ZTL Centro Storico Sud** (a sud dell'Arno: San Martino, Sant'Antonio) | **0–24 tutti i giorni**, festivi compresi | Sì (`pisa-ztl-sud`) |
| ZTL notturna dei Lungarni (Lungarno Pacinotti, Mediceo, Galilei, Gambacorti, piazza Carrara, piazza Mazzini, via San Nicola, Ponte di Mezzo) | ven, sab, dom 22–5 | No: l'ultima proroga ufficiale trovata arriva a gennaio 2023 (obj 5498); stato attuale ignoto (pending) |
| ZTL Stadio (Porta a Lucca) | partite casalinghe del Pisa SC, da due ore prima del fischio d'inizio a fine primo tempo; 24 varchi | No: dipende dal calendario delle partite (pending) |
| Aree pedonali dentro la ZTL: via Corsica e piazza Buonamici (24 ore su 24, 2026); via Santa Maria (A: 9:30–7:00; B: 9:30–20 apr–set, 9:30–19 ott–mar, ord. 531/2015) | — | No: sono già dentro la ZTL Nord 0–24 |

**Festivi e patrono:** la regola vale «tutti i giorni», quindi `freeOnHolidays: false` e nessun `localHolidays` (San Ranieri, 17 giugno, non cambia niente).

## Fatti e fonti

| Fatto | Fonte | Stato |
|---|---|---|
| *"Nelle zone come definite nella prima parte è istituito il divieto di accesso, transito e sosta di tutti i veicoli, nell’orario 0-24 di tutti i giorni, fatte salve le deroghe espresse ai punti successivi."* Due settori, Centro Storico Nord e Sud, con l'elenco delle strade e dei varchi (6 Nord, 9 Sud) | Ordinanza n. 486 Dir. 22 del 22/12/2010, https://www.comune.pisa.it/content/download/9436/249453/1/486_2010.pdf (pagina: https://www.comune.pisa.it/content/view/full/9958; obj 9436) → `ordinanza-486-2010-disciplina-ztl.pdf/.txt` | **Ufficiale** → citazione della scheda, `windows` 0–24 tutti i giorni |
| Dal 1/1/2025 la disciplina è l'**ordinanza n. 2386 del 24/10/2024** (stesso titolo, "a partire dal 1 gennaio 2025"), modificata dalle ord. 2719/2024, 2847/2024 e 406/2025 | Pisamo, https://mobilita.pisamo.it/download-category/ztl/ (visto solo nei risultati di ricerca); comunicato del Comune obj 20500 | Testo **non leggibile** da qui (pending) |
| ZTL Nord e Sud attive 24 ore su 24 tutti i giorni (2025–2026) | viviamopisa.it «ZTL a Pisa: zone, permessi e multe» (2026), fleetmagazine.com, sicurauto.it; nessuna fonte parla di orari diversi | **Confermato solo da fonti non ufficiali** per l'ord. 2386/2024 (pending). La fascia 7–20 citata da CNA Pisa riguarda i permessi degli artigiani, non la ZTL |
| La ZTL Nord esiste ancora: *"veicoli autorizzati ZTL NORD secondo la vigente normativa"* (2024) | obj 18556 | Ufficiale |
| Via San Ranierino e via Cardinal Maffi inserite nella ZTL Nord; varchi spostati da via Camozzo a via San Ranierino e da via Carducci a via San Lorenzo | Ord. DN-18 n. 215 del 10/06/2014 (obj 11691) e n. 277 del 18/07/2014 (obj 10354) → `ordinanza-215-2014-san-ranierino-maffi-ztl-nord.txt` | Ufficiale → strade aggiunte al settore Nord |
| Ciclomotori e motoveicoli a due ruote entrano liberamente | Ord. 486/2010, punto 1.1 | Ufficiale (pending per il 2025) |
| Disabili: veicolo in "lista bianca A"; dal 2024 Pisa aderisce al CUDE, e chi è iscritto entra senza comunicazione; cartelli CUDE a tutti i varchi (2026) | Ord. 486/2010; obj 14179, 20262, 28529 | Ufficiale |
| Le strutture ricettive registrano le targhe dei clienti sul portale: *"Solo alle strutture ricettive professionali: Alberghi, B&B e similari"* | https://www.comune.pisa.it/Servizi/Registrazione-Targhe-per-accesso-veicoli-in-ZTL (mod. 03/08/2026; obj 3404) | Ufficiale → `hotelCanRegister: true` |
| Strutture dentro la ZTL: accesso dei clienti **gratuito**, targa e ora di accesso sul portale (6 ore, poi **10 ore** dal 6/3/2023), sosta solo carico/scarico bagagli fino a 30 minuti; transiti caricabili fino a 3 giorni | obj 5972 (20/02/2023), 5674 (28/02/2023) | Ufficiale ma del 2023 (pending) |
| Tutte le strutture ricettive del Comune: permesso **12 € per 24 ore** per ZTL, ZSC e strisce blu, non oltre il numero di camere | obj 5972; Pisamo cita ancora 12 €/24 ore con l'ord. 2386/2024, cap. 5 punto 5.1 (solo risultati di ricerca) | Ufficiale 2023, conferma 2025 non aperta (pending) |
| Nessun ticket giornaliero per turisti. L'autorizzazione giornaliera (obj 3414) è solo per disabili e taxi/NCC | obj 3414 | Ufficiale |
| Auto elettriche ammesse solo nel 2011 e con iscrizione (ord. 487/2010) | `ordinanza-487-2010-veicoli-elettrici.pdf` | Nessuna esenzione attuale → `exemptFuels: []` |
| Multe: *"saranno applicate le sanzioni previste dal vigente Codice della Strada"* (art. 7) | Ord. 486/2010 | Importo non riportato nella scheda |
| Contatti: Ufficio ZTL Varchi Elettronici, pm.ztl@comune.pisa.it, 050 910828; Pisamo 050 7062, frontoffice@pisamo.it | obj 13525, 14801, 30326 | Ufficiale |
| Storico: orari 2002 (7–19 in alcuni quartieri), ordinanze 1988–2008 | `ordinanza-303-2002-riepilogo-ztl.pdf`, indice della ricerca | Superato, non usato |

## Cosa resta da verificare (pending nella scheda)

- Orari dell'ord. 2386/2024 (in vigore dal 2025): lo 0–24 viene dall'ord. 486/2010 ed è confermato solo da guide non ufficiali recenti. Per questo `HOURS_OFFICIAL = True` è una scelta "fortemente incrociata", dichiarata nel primo punto pending.
- Perimetro approssimato (vedi sotto); strade aggiunte o tolte dopo il 2014 possono mancare.
- Prezzo e scadenza per gli ospiti delle strutture: dati del 2023.
- Varchi: le 15 telecamere di OSM, da confrontare con l'elenco ufficiale.
- ZTL notturna dei Lungarni: nessuna notizia ufficiale dopo gennaio 2023.

## Geometria

**Perimetri: non ancora presenti. Varchi: 15, da OpenStreetMap** (© OpenStreetMap contributors, ODbL 1.0, scritto nel campo `license`).

- OSM non ha il contorno: la relazione [9342809](https://www.openstreetmap.org/relation/9342809) «Zona a Traffico Limitato» contiene **solo le 15 telecamere** (ruolo `device`), come i 15 varchi elencati nell'ord. 486/2010.
- Il perimetro di ogni settore si ricava **dall'elenco ufficiale delle strade** dell'ord. 486/2010 (più via San Ranierino e via Cardinal Maffi, 2014), con la geometria OSM di quelle strade, unite con `osm_geo.street_area` (chiusura morfologica, come per Siena). I tratti parziali dell'ordinanza (via San Francesco da via Oberdan a via Buonarroti, via Santa Maria e via Roma da piazza del Duomo a via San Nicola / via Savi, via Mercanti, via Lalli, via San Bernardo fino a vicolo dell'Oro) sono tagliati tra le due strade indicate. Nessun punto è disegnato a mano.
- **Serve far girare il workflow «Geometrie città»** (`Tools/fetch_geo.py`): in fondo al file c'è il blocco «Pisa», che scarica `data/raw/geo/pisa-streets.json` (strade con nome del centro storico). Poi si rilancia `python3 Tools/build_pisa.py`.
- Lo script stampa le strade dell'ordinanza non trovate in OSM e scrive la scheda nell'app solo se: ne mancano al massimo il 10% per settore; piazza dei Miracoli e piazza dei Cavalieri cadono nel settore Nord e piazza San Martino nel Sud; la stazione di Pisa Centrale è fuori; le aree sono plausibili (Nord 0,6–2 km², Sud 0,25–1,2 km²). Altrimenti la scheda resta in `data/drafts/`.
- I varchi vanno al settore più vicino una volta che ci sono i perimetri; finché mancano, stanno tutti nella zona Nord.

## File in data/raw/pisa/

- Ordinanze: `ordinanza-486-2010-disciplina-ztl.pdf` e `.txt`, `ordinanza-215-2014-san-ranierino-maffi-ztl-nord.txt`, `ordinanza-531-2015-ztl-santa-maria.txt`, `ordinanza-303-2002-riepilogo-ztl.pdf`, `ordinanza-487-2010-veicoli-elettrici.pdf`.
- Pagine del Comune (API OpenCity): `comune-pisa-content-{3404,13536,3414,13525,5972,5674,5893,20500,30326,30591,31288,27780,27924,28250,18556,5445,5498,28529,9436,11691,10354,14179,20262}.json`.
- `comune-pisa-search-ZTL-index.json`: indice dei 227 risultati della ricerca «ZTL» sul sito del Comune.

Licenza dei contenuti del sito: CC BY 4.0, come dichiarato nei metadati dei documenti.
