# Rimini: fonti della scheda ZTL

Scheda generata da `Tools/build_rimini.py` → `Resources/Cities/rimini.json` (stato **draft**, `reviewedByHuman: false`), nell'app tramite `manifest.json` dal 27/10/2026. Regole e citazioni **verificate** sui testi ufficiali letti il **27/10/2026** e salvati in `data/raw/rimini/` (URL e data in testa a ogni file; il builder si ferma se una frase citata non è nel testo salvato).

## Zone
La ZTL del centro storico e del Borgo San Giuliano (sanzioni automatiche dal **29/01/2026**, 13 varchi) è divisa dalla mappa ufficiale in settori con orari diversi; ogni settore è una zona `pass` (permesso giornaliero 5 €, hotel registrano la targa), tutti i giorni, `freeOnHolidays: false`, `exemptFuels: []`.

| Zona (id) | Orario | Varchi |
|---|---|---|
| Centro storico · ZTL 9–12 e 16–19:30 (`rimini-centro`) | 9–12, 16–19:30 | 06 Bertani, 08 Castelfidardo/Clari, 09 Dante/Aponia, 10 XXII Giugno/Angherà |
| Piazzetta dei Servi (`rimini-servi`), Sferisterio (`rimini-sferisterio`) | 9–12, 16–19:30 | — |
| Borgo San Giuliano · ZTL 0–24 (`rimini-borgo`) | 0–24 | 12 Marecchia/Matteotti, 13 Trai/Matteotti |
| Corso Giovanni XXIII (`rimini-corso-xxiii`) | 0–24 | 11 Corso Giovanni XXIII/piazza Ferrari |
| Piazzetta Teatini (`rimini-teatini`), via Garibaldi – via Cairoli (`rimini-garibaldi`) | 0–24 | — |
| Via Michele Rosa (`rimini-michele-rosa`) | 9–12 | 07 Michele Rosa/Castelfidardo |
| Via Ducale (`rimini-ducale`) | 20:30–7:30 | 02 Corso d'Augusto/Circonvallazione Occidentale |
| Via d'Azeglio (`rimini-azeglio`) | 22–6 | 04 d'Azeglio/Circonvallazione Occidentale |
| Bastioni Meridionali (`rimini-bastioni`) | 22–6 | 05 Bastioni Meridionali/Largo Unità d'Italia |
| Corso d'Augusto nord (`rimini-corso-augusto-nord`, tratto via Ducale – via S. Maria in Corte) | 7:30–20:30 | 03 Corso d'Augusto/via Ducale |
| Centro storico · Area pedonale (`rimini-apu-centro`) | 0–24 | — |
| Viale Tiberio · Area pedonale (`rimini-apu-borgo`) | 0–24 | 01 Viale Tiberio/via San Giuliano |

Aree pedonali vietate anche con permesso (`pedestrian`): piazza Cavour, piazza Tre Martiri, piazza Malatesta (aree OSM).

Citazioni: per le zone con varco la riga dell'elenco ufficiale dei varchi (es. «09 - Via Dante Alighieri intersezione via Aponia funzionamento 9.00 -12.00 e 16.00-19.30»); per le zone senza varco la voce della legenda dell'Allegato A (es. «ZONA TRAFFICO LIMITATO 00:00-24:00»); per l'area pedonale del centro il divieto dell'Allegato B («divieto di circolazione in piazza Cavour; piazza Tre Martiri; …; Piazza Malatesta;»).

| Fatto | Fonte (letta il 27/10/2026) | Tipo |
|---|---|---|
| 13 varchi con orari; due aree distinte (centro storico / Borgo), il permesso dell'una non vale nell'altra; moto e ciclomotori ammessi sull'itinerario via Bertani – Largo Giulio Cesare – via dell'Onestà | https://www.comune.rimini.it/amministrazione/documenti-e-dati/documento-tecnico-di-supporto/varchi-ztl-centro-storico-e-borgo (aggiornata 09/02/2026) → `comune-varchi-ztl-centro-storico-borgo.txt` | ufficiale |
| Sanzioni automatiche dal 29/01/2026; residenti 30 accessi/mese; ristoranti in ZTL 0/24 fino a 5 targhe entro 72 ore; permessi giornalieri; elenco varchi | https://www.comune.rimini.it/novita/notizie/ztl-centro-storico-e-borgo-san-giuliano-dal-29-gennaio-partono-le-sanzioni → `comune-notizia-sanzioni-29-gennaio-2026.txt` | ufficiale |
| Permesso giornaliero 5 € (max 3 volte al mese per targa), quadrigiornaliero 15 € (una volta al mese), solo online sul portale https://servizimobilita.comune.rimini.it, comunicabile entro 72 ore, transito senza limiti d'orario nel centro e nel Borgo, niente sosta; piazze vietate; disabili via emergenze.ztl@comune.rimini.it | https://www.comune.rimini.it/servizi/mobilita-e-trasporti/richiedere-il-permesso-giornaliero-laccesso-alla-zona-traffico → `comune-permesso-giornaliero-ztl.txt` | ufficiale |
| Regole per tutti i veicoli «benzina, diesel, elettrici ed ibridi»; strutture ricettive (art. 4.2): targhe sul portale entro 72 ore, max tanti permessi quanti i posti letto, sosta non consentita; ristorazione (art. 4.6) | Allegato B aggiornato con la delibera 393/2025 → `allegato-b-permessi-ztl-apu-estratto.txt` (estratto) | ufficiale |
| Perimetro e settori, legenda con gli orari | Allegato A alla delibera di Giunta 393/2025 → `allegato-a-dgc-393-2025-mappa-ztl.pdf`, scritte in `allegato-a-dgc-393-2025-legenda.txt` | ufficiale |
| Delibera 393/2025 (perimetro, Allegato B, ristoranti) e delibera 161/2024 (varchi 04 e 05 solo 22–6, tratto di Corso d'Augusto 7:30–20:30, moto verso le Poste) | `dgc-393-2025.txt`, `dgc-161-2024.txt` | ufficiale |
| Sanzione 83 € | volantino ZTL gennaio 2026 → `volantino-ztl-2026.txt` | ufficiale |
| ZTL stagionale Parco del Mare Nord (1/6–10/9/2026), non in GateLR | https://www.comune.rimini.it/ztl-zona-traffico-limitato-parco-del-mare-nord → `comune-ztl-parco-del-mare-nord.txt` | ufficiale |
| Fase di pre-esercizio 2025 (orari uguali) | comunicato del 18/04/2025 → `comune-comunicato-preesercizio-2025.txt` | ufficiale, storico |

Fonti non ufficiali usate solo per orientarsi (ricerca web): sicurauto.it, automobilista.it, teleromagna.it, vitaromagna.it (host non raggiungibili dal sandbox, nessun dato preso da lì).

## Pending (nella scheda)
Orari tutti i giorni senza eccezioni per i festivi (nessuna menzione nei testi); dettagli del permesso giornaliero; hotel entro 72 ore; ristoranti; elettriche e moto non esenti (tranne itinerario Poste); piazze vietate e multa 83 €; precisione della mappa; Parco del Mare Nord non incluso. Il ticket usa `deadline: nextDayMidnight` (più prudente delle 72 ore del Comune).

## Geometria (ufficiale, agganciata a OpenStreetMap)
- Nessun perimetro in open data (dati.emilia-romagna.it e dati.gov.it: solo «Famiglie per zona ZTL»); in OSM non c'è una relazione della ZTL.
- `Tools/rimini_mappa.py` legge la mappa vettoriale dell'Allegato A (PDF senza coordinate): immagine a 72 dpi senza antialiasing, classi dai colori esatti della legenda; ciascuno dei due riquadri (pianta generale e ingrandimento del Borgo) è agganciato con una similitudine cercata per correlazione (FFT) tra le righe grigie degli edifici della base cartografica e i contorni degli edifici OSM. Risultato: pianta 1,894 px/m, ingrandimento 2,960 px/m, rotazione −1,7° in entrambi (pari alla convergenza del reticolo UTM 33 a Rimini, segno che la base è in UTM/Gauss-Boaga). Controllo incrociato: i settori presenti in tutti e due i riquadri hanno la stessa area entro lo 0,5–1 % e baricentri a meno di 10 m. → `data/raw/rimini/ztl-mappa-ufficiale.geojson`.
- Edifici e strade OSM scaricati il 27/10/2026 con `Tools/fetch_osm_api.py` (riquadro 44.053–44.068 N, 12.553–12.580 E) → `data/raw/geo/rimini-centro.json` (solo edifici, strade, nodi con nome, piazze pedonali; © OpenStreetMap contributors, ODbL 1.0).
- Varchi: incrocio OSM delle due vie dell'elenco ufficiale (nodo in comune; per 04 e 05, dove le vie non si toccano in OSM, il punto medio dei due punti più vicini, a 7 e 6 m), assegnato alla zona più vicina con la stessa fascia oraria.
- Parti più piccole di 500 m² (minuscole aree pedonali e resti di simboli) escluse.
- Controlli nel builder: piazza Tre Martiri, piazza Cavour e il Tempio Malatestiano nell'area pedonale, via Santa Chiara nel settore 9–12/16–19:30, via Forzieri nel Borgo, stazione FS e fermata «Arco d'Augusto» (fuori dalle mura) fuori da tutte le zone, varchi a meno di 60 m dal bordo, settori senza sovrapposizioni.

## Moto e scooter (1.17.1)
Nessuna esenzione: moto e ciclomotori passano senza permesso solo sull'itinerario via Bertani – Largo Giulio Cesare – via dell'Onestà → per la zona «Non entrare».
