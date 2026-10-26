# Bari: fonti della scheda ZTL

Scheda generata da `Tools/build_bari.py` → `Resources/Cities/bari.json` (stato **draft**, `reviewedByHuman: false`). Dal 26/10/2026 è **nell'app** (`manifest.json`), con perimetro e varchi da OpenStreetMap.
Fonti lette il **26/10/2026** e salvate in `data/raw/bari/` (testo estratto, con URL e data in testa a ogni file). Lo script controlla che ogni frase usata sia presente nei file salvati.

## Zone

- **ZTL della Città Vecchia (Bari Vecchia)**: unica ZTL della città. Pubblicata come zona `restricted`, 0–24 tutti i giorni.
- **Murattiano**: nessuna ZTL trovata. Via Sparano e via Argiro sono aree pedonali (in OSM `highway=pedestrian`), non modellate: non c'è una fonte ufficiale leggibile (comune.bari.it non risponde) e la scheda lo dice in `pending`.
- **Madonnella / Umbertino**: nessuna ZTL, nemmeno notturna. Si trovano solo articoli sulla movida (PugliaPress 11/05/2026, Gazzetta del Mezzogiorno), nessun provvedimento.
- **ZTL notturne**: nessuna.

## Fatti → fonte

| Fatto | Fonte (letta il 26/10/2026) | Tipo | File |
|---|---|---|---|
| ZTL istituita con ordinanza dirigenziale n. 2023/00181 (2023/185/00102) del 18/01/2023, che recepisce la delibera GC n. 886 del 29/11/2022 | Polizia Locale di Bari, «La nuova ordinanza ZTL – rilascio permessi ed accessi temporanei»: https://www.poliziamunicipalebari.it/home-page/cosa-fare-in-caso-di/rilascio-permessi-ztl/ (copia Wayback del 05/12/2025, il sito non risponde) | ufficiale | `polizia-locale-rilascio-permessi-ztl.txt` |
| Testo dell'ordinanza, con delibera 886/2022 e disciplinare «Criteri di funzionamento» | PDF allegato alla pagina della Polizia Locale: https://s93719c543e6e84f7.jimcontent.com/download/version/1423133575/module/11109032222/name/O.D.%20-%20ZTL.pdf | ufficiale | `ordinanza_2023_00181.txt` (pdftotext; PDF 3,5 MB non salvato) |
| Perimetro: corso Vittorio Emanuele, piazza Massari, piazza Isabella d'Aragona, corso Senatore Antonio De Tullio, lungomare Imperatore Augusto, piazza IV Novembre | Polizia Locale (sopra); AMTAB «La ZTL»: https://www.amtab.it/it/zona-a-traffico-limitato/la-zona-ztl | ufficiale | `polizia-locale-…txt`, `amtab-la-zona-ztl.txt` |
| «Strade azzurre»: transito tutti i giorni 0–24 solo per disabili con contrassegno e residenti/domiciliati/dimoranti con permesso (citazione della scheda) | Polizia Locale (sopra); ordinanza punto 10 | ufficiale | idem |
| Aree pedonali: 0–24 solo emergenze, disabili, passi carrabili, bici; carico/scarico nei giorni lavorativi 9–11 e 16–18 (sosta max 20 min con disco orario) | Ordinanza punti 6–8 e 17; AMTAB «Regolamento ZTL»: https://www.amtab.it/it/zona-a-traffico-limitato/regolamento-ztl | ufficiale | `ordinanza_2023_00181.txt`, `amtab-regolamento-ztl.txt` |
| «Strade verdi»: solo velocipedi, ciclomotori e motocicli | Ordinanza punto 16 | ufficiale | idem |
| Elettriche e ibride: «l'accesso è condizionato dalla detenzione dell'autorizzazione all'accesso alla ZTL» → nessuna esenzione | Ordinanza punto 29 | ufficiale | idem |
| Sette varchi V1–V7 (posizioni nel testo, punto 18.3); V6 e V7 solo per carico/scarico e passi carrabili | Ordinanza; Polizia Locale; AMTAB | ufficiale | idem |
| Sanzioni: art. 7, comma 14, primo periodo del Codice della Strada (importo non indicato) | Ordinanza punto 37 | ufficiale | idem |
| Permessi residenti: 10 € l'anno, uno per nucleo familiare, AMTAB via Trevisani 206 su prenotazione | AMTAB «Rilascio permessi»: https://www.amtab.it/it/zona-a-traffico-limitato/rilascio-permessi; «Modalità di rilascio»: https://www.amtab.it/it/zona-a-traffico-limitato/modalita-di-rilascio | ufficiale | `amtab-rilascio-permessi.txt`, `amtab-modalita-di-rilascio.txt` |
| Permessi provvisori con validità giornaliera «ogni qualvolta si dovessero presentare circostanze particolari e giustificabili», 3 €/giorno | Disciplinare allegato alla delibera 886/2022, par. 11.5 (dentro l'ordinanza) | ufficiale | `ordinanza_2023_00181.txt` |
| Disabili: accesso previa telefonata al numero verde 800 060 780 della Sala Operativa, indicando varco, targa e numero del contrassegno; vale per il singolo accesso | Polizia Locale (sopra) | ufficiale | `polizia-locale-…txt` |
| Ganci (percorsi aperti a tutti nei giorni lavorativi 6–21 verso piazzale Mincuzzi): **aboliti** e convertiti in strade azzurre con la delibera di giunta di novembre 2025 | BariToday 25/11/2025 (riporta il comunicato del Comune): https://www.baritoday.it/cronaca/zrl-bari-vecchia-nuove-regole-parcheggi-transito-strade.html | non ufficiale | `baritoday-2025-11-25-delibera.txt` |
| Varco del Castello (piazza Federico II di Svevia / piazza Massari) attivo dal 1° luglio 2026, con ingressi nei feriali 9–11 e 16–18 solo per carico/scarico di mezzi autorizzati; piazzale Mincuzzi pertinenziale (pass ZTL e ZSR-D) h24; strisce blu sul perimetro esterno, feriali 8:30–20:30; varco di Santa Chiara sempre aperto a tutti per girare attorno al piazzale | Telebari 11/06/2026: https://www.telebari.it/attualita/255902-ztl-attivo-dal-1-luglio-il-varco-del-castello-scaramuzzi-soluzione-presa-con-residenti-e-commercianti.html; Quotidiano di Puglia 12/06/2026; Borderline24 25/06/2026; BariToday 01/07/2026 («È stato attivato il varco in zona Castello») | non ufficiale | `telebari-2026-06-11.txt`, `quotidianodipuglia-2026-06-12.txt`, `borderline24-2026-06-25.txt`, `baritoday-2026-07-01.txt` |
| Hotel: «l'attuale regolamento della Ztl non contempla una specifica deroga per le attività alberghiere»; «per gli utenti non titolari di pass è inoltre previsto un ingresso temporaneo a pagamento, da richiedere e ottenere prima del transito» → `hotelCanRegister: false`, nessun `ticket` | La Gazzetta del Mezzogiorno 02/09/2026 (risposta del Comune a un albergatore): https://www.lagazzettadelmezzogiorno.it/news/bari/2115194/… ; Telenorba 03/09/2026 (intervista all'assessore Petruzzelli) | non ufficiale | `gazzetta-2026-09-02-albergatori.txt`, `telenorba-2026-09-03.txt` |
| Nessun dataset ZTL o aree pedonali negli open data | opendata.comune.bari.it, API CKAN `package_search?q=ztl` e `q=pedonal` (0 risultati); dati.gov.it `q=ztl bari` (0) | ufficiale | `opendata-package_search-*.json` |

Festivi e patrono: la ZTL vale 0–24 tutti i giorni, festivi compresi (`freeOnHolidays: false`), quindi `localHolidays` non serve. San Nicola è patrono (6 dicembre, festa cittadina; festa della Traslazione 7–9 maggio): in quei giorni il Comune emette ogni anno ordinanze con limitazioni in più nella città vecchia (es. comunicato «Celebrazioni di San Nicola 2021»), non modellate.

Il centro della città nel JSON (41,1285, 16,8695) serve solo a inquadrare la mappa. Sul sito il punto di partenza è la Basilica di San Nicola (41,1305, 16,8701).

## Geometria: provenienza e licenza

**Da OpenStreetMap, non ufficiale** (© OpenStreetMap contributors, ODbL 1.0; scritto nel campo `license`, con link alla relazione e nota in `pending`).

- Dati: `data/raw/geo/bari-ztl.json`, estratto da una richiesta Overpass (istanza maps.mail.ru, bbox 41,118–41,136 / 16,855–16,880) scaricata il 26/10/2026 con il workflow «Scarica pagine» (`pagine-bari-3`). Gli altri server Overpass (overpass-api.de: 406, kumi, private.coffee) non hanno risposto.
- **Perimetro**: relazione [21044253](https://www.openstreetmap.org/relation/21044253) «ZTL della Città Vecchia» (`boundary=limited_traffic_zone`, `motorcar=permit`, `goods:conditional=destination @ (09:00-11:00,16:00-18:00)`). I 20 membri sono le way delle strade di confine (corso Vittorio Emanuele II, piazza Massari, piazza Federico II di Svevia, corso De Tullio, piazzale Cristoforo Colombo, lungomare Imperatore Augusto), unite testa-coda con `osm_geo.outer_ring` e semplificate a 4 m: 32 punti, 0,34 km². Corrisponde all'elenco ufficiale delle vie di perimetro; il contorno passa sulla mezzeria di quelle strade.
- **Varchi**: i 7 nodi «Varco ZTL Numero 1…7» (membri della relazione), abbinati per numero ai varchi V1–V7 dell'ordinanza, con i nomi ufficiali. Le posizioni corrispondono alle vie dell'ordinanza (Numero 1 su strada Porto Nuovo, 3 su piazza Federico II di Svevia/piazza Massari, 4 su via Benedetto Petrone, 5 su corso Vittorio Emanuele II a 23 m da strada San Benedetto, 6 su via Michele Genovese, 7 sul lungomare vicino a largo Urbano II), tranne il **Numero 2**, che è su corso De Tullio a circa 110 m da via Ruggiero il Normanno. Tutti sono a meno di 16 m dal bordo.
- Controlli nello script: Basilica di San Nicola e Cattedrale dentro; stazione Bari Centrale, via Sparano e Teatro Petruzzelli fuori; area tra 0,2 e 0,6 km²; varchi a meno di 40 m dal bordo.
- Se arriva un perimetro ufficiale, si salva `data/raw/bari/ztl_perimetro.geojson`: lo script usa quello.

## Rete

comune.bari.it e poliziamunicipalebari.it non rispondono né dal sandbox né da GitHub Actions; la pagina della Polizia Locale è letta dalla copia Wayback del 05/12/2025, il PDF dell'ordinanza dal suo host (jimcontent.com). amtab.it risponde. I comunicati del Comune (es. «Zona a Traffico Limitato di Bari Vecchia: giunta approva l'aggiornamento degli elaborati tecnici…») non hanno copie Wayback: i loro contenuti sono presi dagli articoli che li riportano.

## Da verificare (`pending`)

- **Perimetro e varchi** da OpenStreetMap, da confrontare con la planimetria ufficiale (allegata all'ordinanza, senza coordinate). Varco 2 da riposizionare.
- **Ganci aboliti / varco del Castello**: confermati solo dalla stampa che riporta il Comune; manca il testo della delibera di novembre 2025 e dell'ordinanza attuativa. La pagina AMTAB «Regolamento ZTL» descrive ancora i ganci del 2023.
- **Varco di Santa Chiara / piazzale Mincuzzi**: secondo il Comune (Telebari) resta aperto a tutti per girare attorno al piazzale; GateLR segna chiusa tutta l'area. Confermato solo da Telebari.
- **Accesso temporaneo a pagamento** per chi non ha il pass: esiste (disciplinare 2022, 3 €/giorno, «circostanze particolari e giustificabili»; Gazzetta 02/09/2026), ma modalità e prezzo attuali non sono pubblicati. Per questo la zona non ha `ticket`.
- **Hotel**: nessuna deroga, confermato solo dalla Gazzetta del Mezzogiorno (02/09/2026). Gli albergatori hanno chiesto un ingresso di 15–30 minuti con comunicazione della targa: possibile modifica futura.
- **Moto e ciclomotori**: ammessi sulle strade verdi; non è chiaro se ai varchi serva il permesso (OSM indica `motorcycle=yes`).
- **Importo della multa**: non indicato dalle fonti del Comune (art. 7 c. 14 CdS, a livello nazionale circa 83–332 €).
- **San Nicola** (7–9 maggio, 6 dicembre) e **aree pedonali del Murattiano** (via Sparano, via Argiro): non modellate.
- Il Comune ha detto che monitorerà la ZTL «per tutta l'estate» 2026 con «eventuali correttivi»: ricontrollare dopo l'autunno 2026.
