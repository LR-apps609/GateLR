# Parma: fonti della scheda ZTL

Scheda generata da `Tools/build_parma.py` → `Resources/Cities/parma.json` (stato **draft**, `reviewedByHuman: false`).
Fonti lette il **26/10/2026** e salvate in `data/raw/parma/` (testo delle pagine senza HTML, testo dei PDF con `pdftotext`). Lo script controlla che ogni frase citata o riassunta sia presente nei file salvati (si ferma se manca) e fa i controlli di posizione (vedi in fondo).

`www.comune.parma.it` e `www.infomobility.pr.it` non si raggiungono dall'ambiente di lavoro (proxy 403): pagine e PDF sono stati scaricati con il workflow «Scarica pagine» (rami `pagine-parma-1` e `pagine-parma-2`, 26/10/2026). Infomobility S.p.A. è la società a socio unico del Comune di Parma che gestisce varchi, permessi e sosta: le sue pagine sono considerate **ufficiali**.

## Zone

| Zona (id) | Quando | Tipo |
|---|---|---|
| ZTL 1 (`parma-ztl-1`), ZTL 2 (`parma-ztl-2`), ZTL 3 (`parma-ztl-3`) | tutti i giorni, festivi compresi, 7:30–19:30 | pass (ticket GZ 10 € / BZ 5 €) |
| Isole Ambientali (`parma-isola-1`, `-2`, `-3`, `-3i`) | tutti i giorni 0–24 | restricted |
| ZTL Stazione (`parma-ztl-stazione`) | tutti i giorni 0–24 | restricted |
| Limitazioni antismog PAIR (`parma-pair`) | 01/10/2026–31/03/2027, lun–ven 8:30–18:30, esclusi 8/12, 25/12, 1/1, 6/1 | green, divieti per classe Euro |
| Domeniche ecologiche (`parma-domeniche-ecologiche`) | ogni domenica 01/10/2026–31/03/2027 tranne il 01/11/2026, 8:30–18:30 | green, divieti per classe Euro (anche diesel Euro 5) |

Festivi: le ZTL e le Isole valgono "dei giorni feriali e festivi" → `freeOnHolidays: false`. Patrono **Sant'Ilario, 13 gennaio** (festa del Comune, dato noto, non da atto salvato): non cambia nulla, perché le ZTL valgono anche nei festivi e l'ordinanza PAIR esclude solo 8/12, 25/12, 1/1 e 6/1 (il 13/01/2027, mercoledì, e il lunedì di Pasqua 29/03/2027 le limitazioni valgono). Per questo nel JSON non c'è `localHolidays` e i giorni esclusi del PAIR sono tolti con le stagioni (`season`), con `freeOnHolidays: false`.

## Fatti → fonte (ufficiali, lette il 26/10/2026)

| Fatto | Fonte | File |
|---|---|---|
| ZTL 1, 2, 3, Stazione e Isole Ambientali, con l'elenco delle vie (tabelle 2.1–2.5). "Il divieto di accesso in Isola Ambientale per i veicoli non autorizzati è vigente nella fascia oraria 0-24 dei giorni feriali e festivi"; "Il divieto di accesso alle ZTL per i veicoli non autorizzati è vigente nella fascia oraria 7:30-19:30 dei giorni feriali e festivi […]; orari differenti sono indicati nelle relative tabelle" | Ordinanza dirigenziale OD-2024-65 del 18/06/2024: https://www.infomobility.pr.it/wp-content/uploads/2024/06/ordinanza_2024_65_18.06.2024.pdf | `ordinanza-OD-2024-65-accesso-sosta-ztl.txt` |
| Orari diversi: via Corsi, via Dalmazia (s.lo S. Girolamo–v.le Mentana), v.lo Mauroner, b.go Valorio 0–24 (ZTL 1); via XXII Luglio, b.go Felino, strada Nuova, b.go Groppi, b.go Lalatta, via Linati, via Madre Adorni, b.go Padre Onorio, b.go Regale, via Gnocchi, v.lo dei Mulini, str. Farini (b.go Felino–v.le Berenini) 7:30–11:30 e 16:00–19:00 (ZTL 2); ZTL Stazione (via Cecchi, p.le Dalla Chiesa escluso lato sud) 0–24 → nel JSON tutta la ZTL con 7:30–19:30, eccezioni nei `pending` | idem, tabelle 2.2, 2.3, 2.5 | idem |
| Chi entra senza permesso (previo accreditamento presso Infomobility): soccorso, polizia, disabili con contrassegno, taxi/NCC, car sharing, TPL, ciclomotori e motocicli (non nelle Isole), "veicoli di clienti di alberghi e di strutture ricettive ivi ubicati/e esclusivamente per operazioni di trasbordo bagagli". Nessuna esenzione per elettriche/ibride → `exemptFuels: []` | idem, punti 3–4 | idem |
| 5 varchi: "Viale Toscanini tutti i giorni 7:30 - 19:30 Viale Mariotti (corsia nord - sud) tutti i giorni 7:30 - 19:30 Piazzale Salvo D'Acquisto tutti i giorni 7:30 - 19:30 Via XXII Luglio tutti i giorni 7:30 - 11:30 / 16:00 - 19:00 Isola Ambientale Tommasini-Sauro (Borgo G. Tommasini angolo Via N. Sauro) tutti i giorni 24h" | Infomobility, Varchi e ZTL: https://www.infomobility.pr.it/varchi-e-ztl/ (anche in inglese: https://www.infomobility.pr.it/en/electronic-gates-and-ltz/) | `infomobility-varchi-e-ztl.txt`, `infomobility-electronic-gates-and-ltz-en.txt` |
| Ticket per tutti: "tutti possono accedere alle ZTL tramite l'acquisto di Titoli di sosta Giornalieri e Bi-orari da attivarsi prima dell'utilizzo": BZ 5 € (2 ore), GZ 10 € (tutto il giorno), sosta inclusa; parcometri vicino ai varchi, app Tap&Park, area riservata online, sportello di viale Mentana 29/A, tabaccherie ed edicole convenzionate (elenco nella pagina) → `ticket` con `deadline: beforeEntry` | idem; guida per turisti 2026: https://www.infomobility.pr.it/wp-content/uploads/2026/08/Cartolina_ZTL_Turisti_2026.pdf | `infomobility-varchi-e-ztl.txt`, `cartolina-ztl-turisti-2026.txt` |
| Ingresso senza ticket: ROZ (ravvedimento operoso) 15 €, sosta esclusa, "entro le ore 23.59 del giorno successivo a quello dell'accesso"; online (anche senza codice fiscale italiano, registrandosi), Tap&Park o sportello | idem; procedura ROZ: https://www.infomobility.pr.it/wp-content/uploads/2025/06/ROZ-Ticket-Purchase-Procedure.pdf | idem, `roz-ticket-purchase-procedure.txt` |
| Isole Ambientali: il ticket non basta; gli utenti occasionali con BZ/GZ possono chiedere l'accesso allo sportello Infomobility 9:00–10:30 o 15:00–15:30; per altri orari permesso in deroga della Polizia Locale (frontoffice.pm@comune.parma.it) | Infomobility, Varchi e ZTL | `infomobility-varchi-e-ztl.txt` |
| "ISOLE AMBIENTALI E AREE PEDONALI: Tutti i giorni h. 24" | Guida per turisti 2026 | `cartolina-ztl-turisti-2026.txt` |
| Hotel e B&B nelle ZTL: "possono autorizzare i veicoli dei loro clienti ad accedere alla struttura e sostare per le sole operazioni di carico e scarico […] fornire la targa del veicolo del cliente, data di arrivo e di partenza" all'Ufficio Varchi; con il permesso MA/A (abbonamento 25 €/mese o 250 €/anno) "la struttura ricettiva dovrà dare comunicazione all'Ufficio Varchi della targa del veicolo del cliente entro la giornata di arrivo del cliente" → `hotelCanRegister: true`, termine nel `pending` | Infomobility, Permessi commerciali: https://www.infomobility.pr.it/permessi-commerciali/ | `infomobility-permessi-commerciali.txt` |
| Clienti diretti agli alberghi: transito consentito nella corsia preferenziale di str. Garibaldi (via Bodoni–via Pisacane) e di v.le Toscanini; le auto elettriche e ibride non possono più usare le corsie preferenziali (DGC 125/2024) | Ordinanza OD-2024-49 del 22/05/2024: https://www.infomobility.pr.it/wp-content/uploads/2024/05/Ordinanza-Varchi-49_2024.pdf | `ordinanza-OD-2024-49-corsie-preferenziali.txt` |
| 8 corsie preferenziali con varchi: Toscanini, Mariotti, Zarotto 7:30–19:30; Garibaldi, Repubblica, Bixio, D'Azeglio, viale Falcone (sottopasso stazione) e via Montebello 24 ore. Non modellate come telecamere (mancano le posizioni ufficiali) | Infomobility, Varchi e ZTL | `infomobility-varchi-e-ztl.txt` |
| Varco Isola Tommasini-Sauro attivo dal 2019 | Ordinanza OVD/2019/25: https://www.infomobility.pr.it/wp-content/uploads/2021/11/Ordinanza-Varco-Sauro-Tommasini.pdf | `ordinanza-varco-sauro-tommasini.txt` |
| Elenco vie ZTL aggiornato a giugno 2026 (ZTL01/02/03/Stazione), coerente con l'ordinanza | https://www.infomobility.pr.it/wp-content/uploads/2026/06/VieZTL.pdf (linkato dalla pagina del Comune sui permessi residenti: https://www.comune.parma.it/it/servizi/mobilita-e-trasporti/permessi-residenti-ztl) | `vie-ztl-2026-06.txt`, `comune-permessi-residenti-ztl.txt` |
| Regolamento sosta (B/Z 5 €, G/Z 10 € 7:30–19:30, E/Z eventi 3 €; MA/A per strutture ricettive), versione 2023 | Allegato 5 Piano Sosta: https://www.infomobility.pr.it/wp-content/uploads/2023/02/All.5_Sistema-tariffario.pdf | `piano-sosta-all5-sistema-tariffario-2023.txt` |
| PAIR 2030: "Dal 01/10/2026 al 31/03/2027, dal lunedì al venerdì, dalle 08.30 alle 18.30, eccetto che nelle giornate festive del 08/12/2026, 25/12/2026, 01/01/2027, 06/01/2027 e nei giorni di indizione di scioperi che riguardano il Trasporto Pubblico Locale, in tutta l'area interna alle tangenziali […] e nel parco Area delle Scienze (Campus Universitario)": vietati benzina Euro 0–2, GPL/benzina e metano/benzina Euro 0–2, diesel Euro 0–4, ciclomotori e moto Euro 0–2. Esenti elettriche e ibride, car pooling (3+ persone), Move-In (solo feriali), disabili, ospiti di hotel nell'area per arrivo/partenza con prenotazione (o attestazione alla Polizia Locale entro 10 giorni). Strade escluse elencate al punto 9. Multa 168–679 € | Ordinanza sindacale OS-2026-102 del 28/09/2026: https://www.infomobility.pr.it/wp-content/uploads/2026/10/SU_DET_OS_102_2026.pdf ; Arpae: https://aggiornati.arpae.it/it/temi-ambientali/aria/liberiamo-laria/limitazioni-per-comune/parma-ordinanze-pair | `ordinanza-OS-2026-102-pair.txt`, `arpae-parma-ordinanze-pair.txt` |
| Domeniche ecologiche: ogni domenica dal 01/10/2026 al 31/03/2027, 8:30–18:30, tranne il 01/11/2026; stesse categorie più diesel Euro 5 | idem, punto 2 | idem |
| Misure emergenziali (bollettino Arpae lun/mer/ven, dal giorno dopo al controllo successivo): divieto 8:00–19:00, anche diesel Euro 5 → non modellate (pending) | idem, punto 7; Comune: https://www.comune.parma.it/it/novita/avvisi/misure-emergenziali-per-la-qualita-dellaria | idem, `comune-misure-emergenziali-qualita-aria.txt` |
| Nessun blocco strutturale dei diesel Euro 5 nei feriali (misure compensative regionali, DGR 1505/2026, L.R. 9/2026) | Infomobility, notizia PAIR 2030 (01/10/2026): https://www.infomobility.pr.it/pair-2030-dal-1-ottobre-2026-in-vigore-le-misure-per-la-qualita-dellaria-previste-dal-piano-aria-integrato-regionale/ | `infomobility-pair-2030-dal-1-ottobre-2026.txt` |
| Area interna alle tangenziali (planimetria allegato 1) | https://www.infomobility.pr.it/wp-content/uploads/2026/10/area-soggetta-limitazioni-pair2030.pdf | `ordinanza-OS-2026-102-allegato1-planimetria.txt` (solo testo; la mappa è stata guardata come immagine) |

## Fonti non ufficiali (solo controllo incrociato, lette il 26/10/2026)

| Fonte | Uso | File |
|---|---|---|
| Autovia, «ZTL Parma 2026» https://www.autovia.it/ztl-parma-guida-completa/ | conferma zone, varchi, ticket, ROZ, ordinanza OD-2024-65 "in vigore al 19 ottobre 2026" | `nonufficiale-autovia-guida-ztl-parma.txt` |
| UnipolMove https://www.unipolmove.it/blog/ztl-a-parma-mappa-orari-e-multe/ | multa "da 80 a 355 euro" (non usata: nessuna fonte ufficiale salvata con l'importo); attribuisce per errore la fascia spezzata a p.le D'Acquisto | `nonufficiale-unipolmove-ztl-parma.txt` |
| explore.parma.it https://explore.parma.it/it/area/centro-storico/ | conferma 7:30–19:30 festivi compresi, isole 24 ore | `nonufficiale-explore-parma-centro-storico.txt` |
| ParmaToday https://www.parmatoday.it/attualita/misure-qualita-aria-1-ottobre-2026.html | conferma PAIR 2026/2027 | `nonufficiale-parmatoday-qualita-aria-2026.txt` |
| accessibilitacentristorici.it https://www.accessibilitacentristorici.it/ztl/emilia-romagna/parma.html | controllo incrociato | `nonufficiale-accessibilitacentristorici-parma.txt` |

## Pending (anche nel JSON)

- Contorni delle ZTL 1/2/3/Stazione da OpenStreetMap (relazioni 19457676, 19457325, 19457327, 19457326, `source=Comune di Parma`, `operator=Polizia Locale di Parma`, `check_date=2025-08-13`): da verificare con l'elenco delle vie dell'ordinanza e con la mappa di Infomobility.
- Isole Ambientali: contorno ricavato dall'elenco ufficiale (tabella 2.1) sulle strade OSM; i nuclei piccoli (piazza delle Barricate con str. Imbriani; str. Inzani, nuova isola della DGC 125/2024) come inviluppo delle vie allargate di 8 m. Approssimato.
- Fasce orarie diverse dentro ZTL 1 (vie 0–24) e ZTL 2 (vie 7:30–11:30 / 16:00–19:00) non separate nella mappa.
- ZTL 3 e Isole 1 e 3 senza varchi elettronici: regole valide, controllo della Polizia Locale.
- Hotel: registrazione all'Ufficio Varchi entro il giorno di arrivo, solo carico/scarico bagagli.
- ZTL Stazione: non è detto se il ticket GZ/BZ la apra → trattata come chiusa.
- Importo della multa ZTL: non trovato nelle fonti ufficiali (UnipolMove: 80–355 €, non usato).
- PAIR: misure emergenziali e giorni di sciopero TPL non modellati; Campus Area delle Scienze e strade escluse non rappresentati; date valide solo per la stagione 2026/2027.
- Aree pedonali: nessun elenco ufficiale trovato; la guida per turisti dice solo che sono chiuse 24 ore come le Isole. Non pubblicate come `pedestrian` (le piazze `highway=pedestrian` di OSM, come piazza Garibaldi, sono nelle tabelle della ZTL e non sono aree pedonali ufficiali).
- Modifiche 2026–2027: nessuna modifica alla ZTL annunciata nelle fonti lette; il blocco strutturale dei diesel Euro 5 nei feriali non è introdotto nella stagione 2026/2027.

## Geometria (provenienza)

- `data/raw/geo/parma-ztl.json`: relazioni OSM delle ZTL (Overpass, 26/10/2026), © OpenStreetMap contributors, ODbL 1.0.
- `data/raw/geo/parma-streets.json`: strade con nome del centro, API OpenStreetMap 0.6 (`Tools/fetch_parma_streets.py`, 26/10/2026), ODbL.
- `data/raw/geo/parma-cameras.json`: nodi OSM `surveillance:type=ALPR`; i varchi di Infomobility sono stati abbinati ai nodi sulla stessa via: Mariotti 7173204180, D'Acquisto 14131154046, Toscanini 4718425106, XXII Luglio 7179007287; Tommasini-Sauro = incrocio delle due vie in OSM. Posizioni approssimate.
- `data/raw/geo/parma-tangenziali.json`: tangenziali SS9var e SS9var/A (Overpass) più il raccordo di via Emilio Lepido (API OSM 0.6), che chiude l'anello come nella planimetria ufficiale. L'area del PAIR è quella racchiusa dall'anello (griglia di 25 m), 30,4 km².

## Controlli fatti dallo script

- Piazza Garibaldi (44.8015, 10.3280) e Duomo (44.8030, 10.3306) dentro la ZTL 1; Duomo dentro l'Isola Ambientale 1; strada Farini nella ZTL 2; piazzale Corridoni nella ZTL 3; via Sauro nell'Isola 2; piazza delle Barricate nell'Isola 3; str. Inzani nella sua Isola.
- Stazione (44.8096, 10.3283) fuori da tutte le ZTL e le Isole (è al bordo della piccola ZTL Stazione) e dentro l'area PAIR; il Campus (44.7700, 10.3150) fuori dal contorno PAIR.
- Ogni citazione presente nei file salvati; almeno l'88% delle vie di ciascuna Isola dentro il contorno calcolato.
