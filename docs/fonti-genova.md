# Genova: fonti della scheda ZTL

Scheda generata da `Tools/build_genova.py` → `Resources/Cities/genova.json` (stato **draft**, `reviewedByHuman: false`), nell'app dal 26/10/2026 (`manifest.json`).
Fonti lette il **26/10/2026** e salvate in `data/raw/genova/` (testo dei PDF estratto con `pdftotext -layout`, pagine web senza tag HTML; in testa a ogni file URL e data). Lo script controlla che ogni frase usata sia presente nei file salvati.
I siti del Comune (`comune.genova.it`, `smart.comune.genova.it`) e `genovaparcheggi.com` non si raggiungono dal sandbox: le pagine sono state scaricate con il workflow «Scarica pagine» (rami `pagine-genova-1`, `pagine-genova-2`). `genovaparcheggi.com` non risponde neanche da GitHub.

## Zone pubblicate

| Zona (id) | Orari | Hotel registra la targa | Perimetro | Varchi |
|---|---|---|---|---|
| Centro Storico · ZTL dei caruggi (`genova-centro`) | sempre, festivi compresi | sì (48 h) | open data, unione dei 5 settori | 11, posizioni OSM |
| Molo · ZTL del Porto Antico (`genova-molo`) | sempre | sì (48 h) | open data | 1, posizione OSM |
| Boccadasse (`genova-boccadasse`) | sempre | sì (48 h) | open data | nessuno noto |
| Vernazzola (`genova-vernazzola`) | sempre | sì (48 h) | open data (pezzo principale) | nessuno |
| Porticciolo di Nervi · Via Gazzolo (`genova-nervi`) | sempre | sì (48 h) | open data | 1, posizione OSM |
| Nervi Centro · Via Oberdan (`genova-nervi-centro`) | sempre | **no** | striscia da OSM | nessuno noto |

Tutte: `windows` 0–24 tutti i giorni, `freeOnHolidays: false`, `exemptFuels: []`, nessun `ticket`. Niente `localHolidays`: il patrono San Giovanni Battista (24 giugno) è festa cittadina a Genova, ma le ZTL valgono anche nei festivi, quindi non cambia niente.

## Fatti → fonte

| Fatto | Fonte (letta il 26/10/2026) | Ufficiale? | File |
|---|---|---|---|
| Disciplinare in vigore: Rev 16/04/2025, modificato con DGC n. 74/2025 del 10/04/2025; elimina la ZTL Castelletto, cambia Vernazzola, introduce AUT_09d | https://www.comune.genova.it/sites/default/files/2025-06/Disciplinare%20ZTL%20aggiornato%20da%20DGC%2074-2025.pdf, cap. 0 | sì | `disciplinare_ZTL_DGC_74_2025.txt` |
| Centro Storico, Molo, Vernazzola, Nervi, Boccadasse, Nervi Centro (e Rivarolo, Bolzaneto, Caracciolo): «ha validità in tutti i giorni dell’anno e nell’intero arco delle 24 ore» | idem, cap. 3 | sì | idem |
| Perimetro del Centro Storico (Piazza De Ferrari esclusa, Via Gramsci esclusa…), 5 settori, 11 varchi elettronici con il settore | idem, par. 3.1.1–3.1.3.1 | sì | idem |
| Ingresso senza permesso o da varco non assegnato = violazione dell'art. 7 comma 14 del Codice della Strada | idem, par. 1.2 | sì | idem |
| Categorie autorizzate «non ancora registrate»: regolarizzazione entro 48 ore | idem, par. 2.1 c) | sì | idem |
| Ospiti di strutture ricettive: carico e scarico bagagli ingombranti, 0–24; la struttura inserisce le targhe online entro 48 ore; abbonamento annuale della struttura 27/54/100 € secondo le camere; validità «Z.T.L. o Settore di riferimento» | idem, par. 2.4.7 (AUT_09c) | sì | idem |
| Clienti delle autorimesse pubbliche: 0–24, targa inserita dal garage entro 48 ore, 2,50 € al giorno | idem, par. 2.4.7 (AUT_09a) | sì | idem |
| Elettrici (ESE_06): accesso libero 0–24 con contrassegno annuale gratuito valido in tutte le ZTL | idem, par. 2.2.2.3 | sì | idem |
| Disabili con CUDE: accesso libero con registrazione; 3 targhe, altro veicolo comunicato entro 7 giorni | idem, par. 2.1 f) e 2.2.1.3 | sì | idem |
| Nervi Centro = Via Oberdan tra Piazza Pittaluga e Viale Franchini; solo ESE_01–03, ESE_04a/b, ESE_06, AUT_01, AUT_02 con passo carrabile, AUT_06; merci 8–13 | idem, par. 3.9 | sì | idem |
| Nervi = Via Gazzolo (dal 14r a Via Caboto), Via Caboto, Via Ganduccio; Via Provana di Leyni ora solo «area avente diritto»; permessi NER_01 11 €/giorno, 20 €/mese | idem, par. 3.4 | sì | idem |
| Boccadasse = Via Boccadasse (da Via Dodero a Piazza Nettuno), Piazza Nettuno, Via Aurora (tratto), Piazza Bassano, Via della Casa, Via della Scalinata; BOC_01 11 €/giorno solo per attività nautiche | idem, par. 3.5 | sì | idem |
| Vernazzola: nuova disciplina (Via Argonauti, Piazza Vernazzola, tratto di Via Chighizola) solo dopo l'installazione delle telecamere; fino ad allora DGC-2021-29 | idem, par. 3.3 e nota 2 | sì | idem |
| Versione precedente (con Castelletto e la vecchia Vernazzola) | https://www.comune.genova.it/sites/default/files/2024-06/Disciplinare_ZTL_ComGE.pdf (Rev 15/02/2021) | sì | `disciplinare_ZTL_rev2021.txt` |
| Le 9 ZTL: Centro Storico, Boccadasse, Bolzaneto, Molo, Nervi (Gazzolo), Nervi (Oberdan), Rivarolo, Vernazzola, Caracciolo; permessi online con SPID/CIE/CNS, gestiti da Genova Parcheggi (servizioclienti@gepark.com, 010 539871); residenti 27 € | https://www.comune.genova.it/servizi/mobilita-e-trasporti/richiedere-permesso-di-accesso-ad-area-ztl (aggiornata il 24/09/2026) | sì | `richiedere-permesso-di-accesso-ad-area-ztl.txt` |
| Settore «Fontane Marose» (DGC 152/2023): dalle 20 del venerdì alle 24 della domenica, dal 6/10/2023 | ORM 877/2023: https://smart.comune.genova.it/sites/default/files/NOTTURNO%20GALLERIA%20GARIBALDI.OrdinanzeDiMobilita_ORM-877-2023.pdf; comunicato 04/10/2023: https://smart.comune.genova.it/comunicati-stampa-mobilit%C3%A0-articoli/mobilit%C3%A0-da-venerd%C3%AC-attiva-la-ztl-piazza-fontane-marose | sì | `ORM_877_2023.txt`, `comunicato-ztl-fontane-marose-2023.txt` |
| Fontane Marose **sospesa** a febbraio 2025 («nei prossimi giorni sarà firmata un’apposita ordinanza») | https://liguria.bizjournal.it/2025/02/12/genova-ztl-in-piazza-fontane-marose-sospesa/ | **no** (l'ordinanza non è stata trovata; il disciplinare 2025 non nomina il settore) | `bizjournal-fontane-marose-sospesa.txt` |
| Circa 180 nuovi punti di lettura targhe, anche in uscita (Giunta 30/04/2026), nessuna data di accensione | https://www.genovatoday.it/cronaca/ztl-varchi-intelligenti.html; https://www.sbircialanotizia.it/articoli/2026/04/30/ztl-genova-varchi-nzmey/ | **no** | `genovatoday-varchi-intelligenti.txt`, `sbircialanotizia-180-varchi.txt` |
| Antismog ORD 256 del 05/08/2025: lun–ven 7–19; Area 1 (centro) diesel M1/N1 ≤ Euro 4, benzina ≤ Euro 1, moto ≤ Euro 1 (2 tempi ≤ Euro 2); Area 2 (tutto il Comune) diesel M1 ≤ Euro 2, benzina ≤ Euro 1; esenti tra l'altro elettrici, metano/GPL/ibridi e «Veicoli di residenti fuori regione o all’estero muniti di prenotazione alberghiera nel Comune, limitatamente al tragitto di arrivo e partenza» | https://www.comune.genova.it/sites/default/files/2025-08/ORD_256_2025%20-%20File%20primario%20-%20ORD-256-2025%20-%20Definitiva%20-%20.pdf | sì | `ORD_256_2025_antismog.txt`, `comunicato-antismog-2025.txt` |
| Elenco delle vie del perimetro dell'Area 1 | https://www.genovatoday.it/cronaca/ordinanza-antismog-vie-zone-veicoli.html | no (copia del testo comunale) | `genovatoday-antismog-zone.txt` |

## Non pubblicato (e perché)

- **Castelletto**: eliminata dalla DGC 74/2025 (cap. 0 del disciplinare). Negli open data c'è ancora: lo script la ignora.
- **Rivarolo, Bolzaneto, Caracciolo**: ZTL residenziali senza telecamere, poco interessanti per i turisti. Negli open data Rivarolo e Bolzaneto sono a pezzi staccati (10–120 m) e Caracciolo (Pegli) non c'è. Da aggiungere come zone separate se servono.
- **Settore Fontane Marose**: sospeso nel 2025 (solo fonte di stampa), assente dal disciplinare 2025. Resta come nota `pending` sul Centro Storico.
- **Area 1 antismog** (zona a basse emissioni): la planimetria ufficiale è solo un'immagine nel PDF (p. 11); il perimetro è una lunga sequenza di vie (trovata solo su GenovaToday). Non disegnata: le regole sono nelle note `pending` del Centro Storico e del Molo. Dal 2025 la stampa riporta «per ora niente multe» e a settembre 2026 il rinvio sine die del divieto per i diesel Euro 5: non verificato su fonte ufficiale.
- «Blu Area» è la sosta a pagamento (dataset «Soste Blu Area»), non una ZTL.

## Geometria: provenienza e licenza

- **Perimetri ufficiali**: dataset «Zone a traffico limitato» del Comune di Genova, Direzione Mobilità e Trasporti (https://dati.comune.genova.it/dataset/zone-traffico-limitato, trovato tramite dati.gov.it CKAN), **CC BY 4.0**, pubblicato e modificato il 01/03/2018. File: `data/raw/genova/Zone_traffico_limitato.geojson` (scaricato da https://opendatacomunegenova.s3.eu-south-1.amazonaws.com/risorse/Zone_traffico_limitato.geojson; metadati in `Zone_traffico_limitato.meta.json`). Il file ripete le stesse aree più volte: lo script toglie i doppioni.
  - **Centro Storico**: unione dei 5 settori (`NR_SOTTOZONA` 1–5) su una griglia di 2 m con chiusura di 3 m (`osm_geo.street_area`), semplificata a 2 m: 242 punti, 0,458 km². Il bordo coincide con quello ufficiale entro ~2 m.
  - Molo, Boccadasse, Nervi: il poligono ufficiale, semplificato a 1 m. Boccadasse e Nervi sono disegnati come strade (larghe pochi metri).
  - Vernazzola: il pezzo principale (il secondo pezzo, circa 100 m², è a 11 m e non è incluso).
  - Il rilievo è del 2018: può non seguire le modifiche del 2023–2025 (Vernazzola, Via Provana di Leyni a Nervi, strade dei soli «aventi diritto» a Boccadasse). Scritto nelle note `pending`.
- **Nervi Centro** non è negli open data: striscia di 6 m per lato attorno alla way OSM [23100847](https://www.openstreetmap.org/way/23100847) (Via Guglielmo Oberdan da Piazza Pittaluga a Viale Franchini, `motor_vehicle=destination`), calcolata dallo script (© OpenStreetMap contributors, ODbL 1.0).
- **Varchi**: il disciplinare dà solo i nomi. Le coordinate sono le telecamere del traffico (`man_made=surveillance`, `surveillance:zone=traffic`) di OpenStreetMap, estratte in `data/raw/geo/genova-gates.json` (Overpass, 26/10/2026, ODbL). Abbinamento per nome, fissato nello script (`GATES`), con controllo che ogni telecamera stia entro 40 m dal perimetro ufficiale:
  - con nome in OSM: Varco Cairoli (2579946021), varco del Campo (5592753730), Varco Raibetta (5592753726), Varco San Giorgio (5592753732), Varco Cavour (5594220117 → «Vico delle Camelie», la rampa da Piazza Cavour), Varco Grazie (5592753731), Varco Lomellini (8116477688);
  - senza nome, a 1–2 m dalla via del varco: Via di Porta Soprana (5594220118), Vico Giannini (5592753728), Via Eugenia Ravasco (2829907843), Via Garibaldi verso Piazza Fontane Marose (5592753727), Via del Molo (5592753729), Via Felice Gazzolo a Nervi (5592753725).
  - Boccadasse, Vernazzola e Nervi Centro: nessun varco noto.

## Controlli fatti dallo script

- Dentro: Cattedrale di San Lorenzo, Via Garibaldi (Palazzo Tursi), Piazza Banchi, Via San Lorenzo (Centro Storico); Via del Molo; Piazza Nettuno (Boccadasse); Via Argonauti (Vernazzola); Via Caboto (Nervi); Via Oberdan (Nervi Centro).
- Fuori da tutte le zone: stazione Genova Piazza Principe (44.4176, 8.9213), **Piazza De Ferrari** (esclusa dal disciplinare), stazione Brignole, Acquario.
- Area del Centro Storico tra 0,4 e 0,5 km².
- Centro mappa e punto di partenza del sito: Piazza De Ferrari (44.4072, 8.9339), appena fuori dalla ZTL.

## Da verificare (pending)

- Perimetri 2018 rispetto al disciplinare 2025; posizione dei varchi (OSM).
- Se un'auto elettrica con targa estera può avere il contrassegno annuale gratuito.
- Data di accensione dei ~180 nuovi varchi (anche in uscita) — solo stampa.
- Ordinanza di sospensione del settore Fontane Marose — solo stampa.
- Importo delle multe: il disciplinare cita l'art. 7 c. 14 CdS senza importo; le guide non ufficiali indicano da circa 83–84 €.
- Area 1 antismog: perimetro ed effettiva applicazione delle multe.
