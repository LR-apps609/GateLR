# Sirmione: fonti della scheda ZTL

Scheda generata da `Tools/build_sirmione.py` → `Resources/Cities/sirmione.json` (stato **draft**, `reviewedByHuman: false`), nell'app tramite `manifest.json` dal 27/10/2026. Regole e citazione **verificate** sui testi ufficiali letti il **27/10/2026** e salvati in `data/raw/sirmione/` (URL e data in testa a ogni file; il builder controlla che ogni frase usata compaia parola per parola).

## Zona
**Sirmione · ZTL centro storico** (`sirmione-ztl`, `restricted`): 0–24 tutti i giorni per chi non è autorizzato (`freeOnHolidays: false`), nessun ticket, `hotelCanRegister: true`, nessuna esenzione per le elettriche.

Citazione (ordinanza n. 30 del 06/03/2026, https://www.comune.sirmione.bs.it/s3/6918/allegati/ordinanza-ztl-2026-n-30.pdf, ufficiale): «È istituito il divieto, nella Z.T.L. come sopra definita, di circolazione dinamica e statica per tutte le categorie di veicoli non compresi e/o autorizzati ai sensi del predetto Disciplinare di Gestione della Z.T.L.»

| Fatto | Fonte (letta il 27/10/2026) | Tipo |
|---|---|---|
| Area: dalle Grotte di Catullo (nord) all'intersezione di largo Goethe con viale Marconi, civico 5/7 (sud), con l'elenco delle vie; limite 30 km/h; tolleranza 10 minuti sugli orari; sistema K53700/SA in funzione dal 17/02/2020 | ordinanza 30/2026 → `ord-30-2026.txt` | ufficiale |
| Servizio comunale di sosta per i veicoli dei clienti delle strutture ricettive del centro storico (GC 243/2018) | ordinanza 30/2026 (premesse) | ufficiale |
| Unico punto d'ingresso con rilevazione elettronica; serve l'autorizzazione con targa nel sistema; permessi giornalieri/temporanei entro 7 giorni dal modulo; multe 83–333 € (art. 7 c. 14 CdS); estate dal 23/03 al 13/10/2026 | https://www.comune.sirmione.bs.it/it/public_documents/regolamentazione-della-ztl (agg. 26/03/2026) → `comune-regolamentazione-ztl.txt` | ufficiale |
| Orari per categoria; «soggiornanti»: inverno feriali 0–24 due accessi, festivi 0–9 e 19–24; estate feriali 0–24 due accessi, prefestivi 0–10, 12–14, 19–21, 22:30–24, festivi 0–10, 19–21, 22:30–24 (2 accessi/giorno); pedonalizzazione 14–19 nelle 31 giornate elencate, eccetto Grifoparking, soccorsi, residenti in uscita per emergenze; taxi/NCC solo per residenti, dimoranti e soggiornanti | allegato C → `ord-30-2026-allegato-c.txt` (tabella: le colonne sono ricostruite dalla disposizione del testo, le icone dei veicoli non sono testo) | ufficiale |
| Welcome Point: barriera che si alza per le targhe autorizzate; le strutture ricettive inseriscono la targa degli ospiti nel portale | FAQ ZTL sperimentale → `faq-ztl-welcome-point.txt` (non datata) | ufficiale |
| 31 giornate di pedonalizzazione 14–19, transito vietato anche in uscita, golf car elettriche per ospiti e bagagli; filtro alla Bagnera per i bus | notizia «Stagione turistica 2026» (30/03/2026) → `comune-news-stagione-turistica-2026.txt` | ufficiale |
| Modulo 05: richiesta almeno 7 giorni prima, varco «Via Marconi/Largo Goethe», massimo 3 giorni consecutivi; voci «Alberghi carico/scarico bagagli (in primo arrivo)» e «Ospiti presso privati per carico e scarico bagagli (solo un accesso)» | https://municipium-images-production.s3-eu-west-1.amazonaws.com/s3/6918/allegati/ztl/mod-05-permesso-giornaliero-e-temporaneo.pdf (PDF scansionato, letto come immagine: non controllato dal builder) | ufficiale |
| Grifo Parking per gli ospiti delle strutture senza parcheggio, QR code, navetta elettrica; prezzi discordanti (15–21 €/giorno) | Fleet Magazine, Wanderlog, annuncio Airbnb (riassunti della ricerca web; siti non raggiungibili dal sandbox) | non ufficiale |

Allegato A («Disciplina di gestione della Z.T.L.») e B (sosta) non sono pubblicati sul sito: il termine per la registrazione delle targhe da parte degli hotel non è confermato (pending). Festa del patrono: non serve con 0–24 tutti i giorni.

## Host bloccati dal proxy (403, non aggirati)
sirmione-api.municipiumapp.it (gli stessi allegati sono stati letti da www.comune.sirmione.bs.it/s3/…), comune.sirmione.bs.it (senza www), www.sirmionebs.it, visitsirmione.com, www.accessibilitacentristorici.it, www.fleetmagazine.com, www.locautorent.com.

## Geometria (non ufficiale, da OpenStreetMap)
- Nessun open data della ZTL di Sirmione (dati.lombardia.it, dati.gov.it); nessuna planimetria pubblicata.
- Dati OSM scaricati il 27/10/2026 con l'API OSM (`Tools/fetch_osm_api.py`, riquadro 45.484–45.507 N, 10.596–10.615 E) → estratto in `data/raw/geo/sirmione-centro.json` (© OpenStreetMap contributors, ODbL 1.0).
- Perimetro: relazione OSM 19456915 «ZTL Sirmione» (`boundary=limited_traffic_zone`, operator Polizia Locale di Sirmione, source Comune di Sirmione, check_date 2025-08-13, v2 del 15/06/2026), il contorno della penisola chiuso al fossato del castello; 0,40 km².
- Controlli: le 21 vie dell'ordinanza presenti in OSM stanno dentro (almeno l'80% dei punti: fuori solo il ponte del castello di via Vittorio Emanuele e un pontile in legno di piazza Carducci); Grotte di Catullo e Santa Maria Maggiore dentro; piazzale Porto, Grifo Parking e piazzale Europa fuori. Non trovate in OSM per nome: piazzale Orti Manara, via S. Pietro in Mavino, via Faustina, via Piana, piazza Flaminia, piazza Castello, piazzetta Mosaici, via Campane, sentiero dei Pini.
- Varco: sbarra OSM (nodo 10041235164, `barrier=lift_gate`) su largo Goethe a 5 m da via Marconi, cioè il limite sud dell'ordinanza; circa 50 m a sud del bordo disegnato (il tratto largo Goethe–fossato non è nella relazione OSM).
