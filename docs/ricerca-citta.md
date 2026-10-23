# GateLR – Ricerca fonti ufficiali ZTL per città

**Data di verifica:** 23 ottobre 2026
**Scopo:** scegliere le prime città per GateLR ("ZTL Italy · Know before the gate") in base a qualità e riutilizzabilità delle fonti ufficiali.

> **Nota sul metodo (importante):** in questa sessione l'accesso diretto alle pagine web era bloccato dalla policy di rete dell'ambiente (WebFetch e curl verso comune.*.it, romamobilita.it, dati.comune.milano.it, opendata.comune.bologna.it ecc. sono stati rifiutati dal proxy). Tutte le informazioni qui sotto vengono da **estratti dei motori di ricerca su pagine ufficiali** (domini comunali, agenzie della mobilità, portali open data), non da pagine aperte e lette per intero. Gli URL sono quelli restituiti dalla ricerca, non inventati, ma **ogni record va riverificato aprendo la pagina** prima della pubblicazione nell'app. Ciò che non risultava neanche dagli estratti è marcato **[non verificato]**.

---

## Sintesi e raccomandazione

**Prime 5 città consigliate:**

1. **Firenze** – il miglior caso in assoluto: perimetri ZTL diurna e notturna + "Porte telematiche" (varchi ZTL) in SHP/GeoJSON/KML, licenza **CC-BY 4.0**, aggiornati nel 2026; orari pubblicati da Servizi alla Strada (SAS) e ZTL notturna estiva approvata ogni anno con delibera; piattaforma online per gli alberghi.
2. **Roma** – orari di tutte le ZTL (diurne, notturne, sospensione di agosto) pubblicati chiaramente da Roma Servizi per la Mobilità; confini e varchi di tutte le ZTL come dataset geografici (GeoServices REST); procedura hotel online documentata. Punto debole: licenza dei dataset da accettare e da leggere.
3. **Bologna** – regola semplicissima (7–20 tutti i giorni, festivi compresi) e portale open data (Opendatasoft) con dataset "Zona a traffico limitato" ed "Elenco varchi Bologna", licenza CC BY 4.0 sulla serie varchi. Procedura hotel esistente ma pagina datata.
4. **Milano (Area C)** – dataset varchi Area C (DS82) in GeoJSON/SHP/CSV, WGS84, **CC BY 4.0**, più Varchi Area B (DS959); orari semplici (lun–ven 7:30–19:30). Attenzione: Area C è una ZTL **a pagamento** (ticket 7,50 €), quindi la logica dell'app è "puoi entrare pagando", non "vietato".
5. **Verona** – dataset ufficiale "Mappa della ZTL con varchi" con licenza **CC0 1.0**, ordinanza orari citata (n. 1545 del 31/10/2024), procedura white list per gli hotel tramite Polizia Locale. Città molto visitata in auto.

**Subito dopo:** Siena (regole chiare e servizio online hotel, ZTL 0–24, ma solo mappe PDF), Torino (dataset aperTO con perimetro+varchi+orari ma fermo a maggio 2021), Napoli (orari per singolo varco molto chiari, ma open data vecchi).
**Da rimandare:** Pisa, Lucca, Perugia, Palermo, Bergamo, Genova, Venezia-Mestre: niente open data utilizzabili trovati e/o orari frammentati tra comunicati ed eventi.

**Stato in tempo reale:** in nessuna città ho trovato una pagina o API pubblica "varco attivo/non attivo" in tempo reale. Roma indica solo i pannelli a messaggio variabile sul posto; Palermo ha un portale permessi senza feed di stato. GateLR dovrà quindi calcolare lo stato dagli orari e dalle ordinanze, mostrando sempre "verifica il pannello al varco".

---

## Tabella comparativa

| Città | Pagina ufficiale | Open data perimetro / varchi + licenza | Stato in tempo reale | Procedura hotel | Punteggio (1–5) |
|---|---|---|---|---|---|
| **Firenze** | [SAS – ZTL](https://www.serviziallastrada.it/servizi-al-cittadino/autorizzazioni-circolazione-ztl-e-sosta-zcs-dei-veicoli/ztl) | Sì: [ZTL diurna](https://opendata.comune.fi.it/page_dataset_show?id=9257a75e-3af3-4845-b37d-1540be29115a), [ZTL notturna](https://www.dati.toscana.it/dataset/3d586fa5-7367-42c5-b5f2-d8348a5da431), [Porte telematiche](https://opendata.comune.fi.it/page_dataset_show?id=0fe68709-c864-4e21-b18e-07ee3e9328e2) – CC-BY 4.0 | No (non trovato) | Sì, piattaforma online SAS ([news](https://www.serviziallastrada.it/le-news-di-firenzesas/ztl-6)) | **5** |
| **Roma** | [RSM – ZTL](https://romamobilita.it/servizi-al-pubblico/ztl/), [orari](https://romamobilita.it/infomobilita/ztl-tutti-gli-orari/) | Sì: [Dataset geografici RSM](https://romamobilita.it/sistemi-e-tecnologie/dataset-geografici/) (confini + varchi, GeoServices REST) – licenza d'uso da accettare [testo non verificato] | No (solo pannelli sul posto) | Sì, registrazione via PEC + sportello online ([Transito in ZTL](https://romamobilita.it/servizi-al-pubblico/transito-in-ztl/)) | **4** |
| **Bologna** | [Ticket ZTL](https://www.comune.bologna.it/servizi/mobilita-trasporti/ticket-accesso-ztl), [Zone con limitazioni](http://www.comune.bologna.it/trasporti/servizi/2:3023/) | Sì: [ZTL](https://opendata.comune.bologna.it/explore/dataset/zona-a-traffico-limitato/), [Elenco varchi](https://opendata.comune.bologna.it/explore/dataset/varchi-bologna/table/) – CC BY 4.0 sui dataset varchi (licenza del dataset ZTL [non verificata]) | No | Sì, ma pagina datata ([accesso clienti alberghi](http://www.comune.bologna.it/trasporti/servizi/2:4321/3274/)) | **4** |
| **Milano** | [Area C](https://www.comune.milano.it/en/argomenti/mobilita/area-c) | Sì: [Varchi Area C DS82](https://dati.comune.milano.it/dataset/ds82_infogeo_varchi_elettronici_localizzazione_) GeoJSON/SHP/CSV – CC BY 4.0; [Varchi Area B DS959](https://dati.comune.milano.it/dataset/ds959-varchi-areab) – CC BY (versione [non verificata]) | No | Area C: nessuna procedura hotel trovata (ticket o tariffa garage convenzionato); ZTL Quadrilatero: sì ([FAQ](https://servizicrm.comune.milano.it/centro-supporto/KA-03675/ZTL-Quadrilatero-moda-accesso-clienti-attivita)) | **5** (dati) / attenzione al modello a pagamento |
| **Verona** | [ZTL Comune di Verona](https://www.comune.verona.it/Novita/Notizie/La-Zona-a-Traffico-Limitato-di-Verona), [Mappa e orari](https://portale.comune.verona.it/nqcontent.cfm?a_id=30870) | Sì: [Mappa della ZTL con varchi](https://www.comune.verona.it/Amministrazione/Documenti-e-dati/Dataset/Mappa-della-ZTL-con-varchi) – CC0 1.0 (formato: CSV/Google Drive, da verificare) | No | Sì, white list tramite albergatore ([Accesso ZTL per turisti](https://polizialocale.comune.verona.it/nqcontent.cfm?a_id=26104)) | **3** |
| **Siena** | [Accesso ZTL – strutture ricettive](https://www.comune.siena.it/servizi/accesso-ztl-strutture-ricettive), [Mappa ZTL](https://www.comune.siena.it/documento-pubblico/mappa-ztl) | No: solo [PDF mappa varchi](https://www.comune.siena.it/sites/default/files/2024-04/mappa%20varchi%20ZTL.pdf) | No | Sì, servizio online gratuito | **3** |
| **Torino** | [ZTL Centrale](https://www.comune.torino.it/schede-informative/ztl-centrale) | Sì: [Perimetro, varchi e orari ZTL (aperTO)](https://aperto.comune.torino.it/dataset/perimetro-varchi-e-orari-ztl) – CC BY, XML, ultimo agg. maggio 2021 | No | Sì, esenzione a posteriori via GTT entro 10 giorni | **3** |
| **Napoli** | [ZTL e Aree Pedonali](https://www.comune.napoli.it/articolo_tematico/trasporti-mobilita/ztl-e-aree-pedonali/) | Elencato "ZTL e aree pedonali del Comune di Napoli" nel catalogo open data, file e licenza [non verificati], probabilmente datato (2015–2017) | No | Solo per ZTL via F. Russo (Smartmobility/ANM) | **3** |
| **Genova** | [Disciplinare ZTL rev. 16/04/2025](https://www.comune.genova.it/sites/default/files/2025-06/Disciplinare%20ZTL%20aggiornato%20da%20DGC%2074-2025.pdf) | Perimetri: [ZTL SHP](https://dati.comune.genova.it/en/dataset/zone-a-traffico-limitato/resource/4243f13a-d325-40d4-bfcc-db474035bbb1) – CC BY 4.0, Gauss-Boaga, 2018; varchi: no | No | [non verificato] | **3** |
| **Pisa** | [Registrazione targhe ZTL](https://www.comune.pisa.it/Servizi/Registrazione-Targhe-per-accesso-veicoli-in-ZTL), [Pisamo – Regolamento ZTL](https://pisamo.it/regolamento-ztl/) | No (nessun dataset ZTL trovato su opendata.comune.pisa.it) | No | Sì, portale per strutture ricettive | **2** |
| **Lucca** | [Planimetria varchi/ZTL](https://www.comune.lucca.it/documento_pubblico/planimetria-del-centro-storico-con-varchi-telematici-ztl-e-area-pedonale/) | No: solo PDF (dic. 2025) | No | Permessi giornalieri ≤ n. camere (regola in modifica) | **2** |
| **Perugia** | [ZTL – Comune di Perugia](https://www.comune.perugia.it/luogo/ztl-zone-a-traffico-limitato/), [Varchi ZTL (turismo)](https://turismo.comune.perugia.it/pagine/varchi-ztl) | No | No | Sì da regolamento (elenco targhe giornaliero) | **2** |
| **Palermo** | [AMAT – La ZTL, tempi e perimetro](https://www.amat.pa.it/la-ztl-tempi-e-perimetro-2/), [Portale ZTL](https://ztl.comune.palermo.it/ztl/jsp/home.jsp?modo=tabella) | No | No (portale permessi, non stato) | Sì, "lista bianca" (anche a posteriori) | **2** |
| **Bergamo** | [ATB – ZTL di Bergamo](https://www.atb.bergamo.it/ztl/ztl-di-bergamo) | No (non trovato) | No | Non trovata per Città Alta | **2** |
| **Venezia (Mestre)** | [AVM – ZTL centro di Mestre](https://avm.avmspa.it/it/content/le-zone-traffico-limitato-del-centro-di-mestre-0) | No (non trovato) | No | [non verificato] | **2** |

---

## Schede per città

### Firenze — punteggio 5
*Il migliore: open data completi e aperti, aggiornati nel 2026, orari chiari.*

- **Pagine ufficiali:**
  - Servizi alla Strada (SAS), ZTL: https://www.serviziallastrada.it/servizi-al-cittadino/autorizzazioni-circolazione-ztl-e-sosta-zcs-dei-veicoli/ztl
  - ZTL notturna estiva 2026 (SAS): https://www.serviziallastrada.it/node/1023
  - Comune, ZTL notturna estiva 2025: https://www.comune.firenze.it/contributobuonoscuola/novita/notizie/ztl-notturna-estiva-2025
  - Disciplinare ZTL (Provv. Dir. 2011/M/04192, aggiornato): https://www.serviziallastrada.it/Schede_ZTL/Disciplinare_ZTL.pdf
- **Regole/orari:** ZTL diurna (settori A, B, O) lun–ven 7:30–20:00, sab 7:30–16:00 (dal disciplinare). ZTL notturna estiva dal primo giovedì di aprile alla prima domenica di ottobre; per il 2026 dal 2 aprile al 4 ottobre, approvata con **deliberazione di Giunta n. 2026/0099 del 27/03/2026**. Gli orari 2026 non comparivano negli estratti; quelli del 2025 erano gio/ven/sab 23:00–3:00 sui settori A, B, O + F, G. **Gli orari 2026 sono da verificare.**
- **Open data (CC-BY 4.0):**
  - ZTL diurna (poligoni, SHP/KML): https://opendata.comune.fi.it/page_dataset_show?id=9257a75e-3af3-4845-b37d-1540be29115a (copia regionale: https://dati.toscana.it/dataset/9257a75e-3af3-4845-b37d-1540be29115a, modificato il 23/03/2026)
  - ZTL notturna (SHP/KML/WMS): https://www.dati.toscana.it/dataset/3d586fa5-7367-42c5-b5f2-d8348a5da431 (modificato l'08/12/2025)
  - **Porte telematiche** (punti, compresi i varchi ZTL; SHP `sas_porte_telematiche_od.zip` + GeoJSON; ultima modifica 07/09/2026): https://opendata.comune.fi.it/page_dataset_show?id=0fe68709-c864-4e21-b18e-07ee3e9328e2
  - Varchi Scudo Verde (annuncio del dataset): https://opendata.comune.fi.it/content/pubblicato-il-nuovo-dataset-varchi-scudo-verde-relativo-alla-localizzazione-dei-varchi-del
  - Da evitare: dataset "Gara 6 – Varchi" del 2013 (Mondiali di ciclismo, CC-BY 3.0 IT, legato all'evento).
- **Tempo reale:** nessuna pagina di stato trovata.
- **Hotel:** dal 6/10/2021 le strutture ricettive inseriscono le targhe solo online sulla piattaforma SAS (al posto di "Benvenuto in ZTL"): https://www.serviziallastrada.it/le-news-di-firenzesas/ztl-6 ; modulo inserimento a posteriori: https://www.serviziallastrada.it/Moduli_edit_ZTL/11_2019_modulo_inserimento_targhe_a_posteriori.pdf
- **Nota prodotto:** lo Scudo Verde (77 varchi, 24/7, dal 1/4/2025) è una zona ambientale distinta dalla ZTL: valutare se mostrarla.

### Roma — punteggio 4
*Orari completi e procedura hotel chiara; dataset di confini e varchi per tutte le ZTL, ma licenza da leggere e formato GeoServices.*

- **Pagine ufficiali (Roma Servizi per la Mobilità):**
  - ZTL: https://romamobilita.it/servizi-al-pubblico/ztl/
  - Tutti gli orari: https://romamobilita.it/infomobilita/ztl-tutti-gli-orari/
  - Guida orari diurne/notturne: https://romamobilita.it/infomobilita/ztl-orari-citta/
  - ZTL Tridente (A1): https://romamobilita.it/servizi-al-pubblico/ztl-tridente-a1/
- **Regole/orari (dagli estratti):** Centro Storico lun–ven 6:30–18:00, sab 14:00–18:00, festivi esclusi; Tridente lun–ven 6:30–19:00, sab 10:00–19:00; Trastevere diurna lun–sab 6:30–10:00; notturne Trastevere e San Lorenzo mer–sab 21:30–3:00 (mer e gio solo da maggio a ottobre); notturne Centro e Testaccio ven–sab 23:00–3:00; **tutte le notturne sospese ad agosto**; Appia Antica sab–dom 7:00–19:00 tranne agosto (varchi in pre-esercizio). **Novità:** dal 1/7/2026 anche le auto 100% elettriche e a idrogeno devono avere un permesso; dal 2027 previsti varchi anche in uscita (progetto SISVU). Il numero dell'ordinanza non compariva negli estratti [non verificato].
- **Open data:** "Dataset geografici" RSM: confini e posizione dei varchi di Centro Storico (diurna e notturna), Trastevere, San Lorenzo, Testaccio, Monti, Tridente, Villa Borghese, in formato GeoServices REST, senza registrazione ma con **licenza d'uso da accettare (tipo di licenza non verificato)**: https://romamobilita.it/sistemi-e-tecnologie/dataset-geografici/ (vedi anche https://romamobilita.it/sistemi-e-tecnologie/open-data/). Il portale di Roma Capitale (https://dati.comune.roma.it/od/it/home.page) rimanda in generale alla CC BY 4.0, ma la scheda ZTL specifica non è stata trovata.
- **Tempo reale:** nessun feed pubblico; RSM rimanda ai pannelli a messaggio variabile vicino ai varchi.
- **Hotel:** registrazione della struttura via PEC (permessistica@pec.romamobilita.it), poi inserimento autonomo delle targhe dallo sportello online ("Hotel, autorizzazione per i clienti"): https://romamobilita.it/servizi-al-pubblico/transito-in-ztl/ ; vedi anche https://romamobilita.it/servizi-al-pubblico/permessi-temporanei/

### Bologna — punteggio 4
*Regola semplice e dataset ufficiali in API Opendatasoft; procedura hotel da riconfermare.*

- **Pagine ufficiali:**
  - Ticket giornalieri/quadrigiornalieri: https://www.comune.bologna.it/servizi/mobilita-trasporti/ticket-accesso-ztl
  - Zone con limitazioni: http://www.comune.bologna.it/trasporti/servizi/2:3023/
  - ZTL Ambientale: http://www.comune.bologna.it/ztl-ambientale
  - Tabella fasce orarie zone speciali (PDF): https://www.comune.bologna.it/myportal/C_A944/api/content/download?id=60f1647c1412d50059a53ac1
- **Regole/orari:** ZTL centro storico 7:00–20:00 tutti i giorni, festivi compresi (sistema Sirio); dopo le 20 Sirio non è attivo. Zona T, zone universitaria, San Francesco, Pratello: 24/7. ZTL ambientale dal 1/1/2020 (criteri Euro). Ticket (delibera DG/PRO/2020/7): giornaliero 6 €, quadrigiornaliero 15 €, da comprare **prima** dell'accesso.
- **Open data:**
  - Zona a traffico limitato: https://opendata.comune.bologna.it/explore/dataset/zona-a-traffico-limitato/ (licenza [non verificata] negli estratti)
  - Elenco varchi Bologna: https://opendata.comune.bologna.it/explore/dataset/varchi-bologna/table/ (con link ai conteggi passaggi ogni 15 min; ultimo aggiornamento circa 681 giorni fa)
  - I dataset dei singoli varchi (es. https://opendata.comune.bologna.it/explore/dataset/varco-n-80/) riportano **CC BY 4.0**.
  - **Attenzione:** "varchi" su questo portale comprende anche spire/varchi di conteggio del traffico; filtrare i varchi Sirio della ZTL.
- **Tempo reale:** no.
- **Hotel:** i gestori comunicano le targhe al Comune (inserimento in lista Sirio) e consegnano al cliente un permesso per il soggiorno: http://www.comune.bologna.it/trasporti/servizi/2:4321/3274/ (pagina datata; portale attuale [non verificato]).

### Milano (Area C / Area B) — punteggio 5 sui dati
*Il dataset più pulito (CSV con lat/lon WGS84, GeoJSON, CC BY 4.0), ma Area C è a pagamento: l'app deve dire "ticket necessario", non "vietato".*

- **Pagine ufficiali:**
  - Area C: https://www.comune.milano.it/en/argomenti/mobilita/area-c
  - Orari Area C (FAQ): https://servizicrm.comune.milano.it/centro-supporto/KA-01151/Orari-di-attivazione-Area-C
  - Acquisto ticket: https://www.comune.milano.it/en/servizi/mobilita/area-c-acquista-il-ticket
  - ZTL Quadrilatero della Moda: https://www.comune.milano.it/en/servizi/mobilita/ztl-quadrilatero-della-moda
- **Regole/orari:** Area C lun–ven 7:30–19:30, non attiva sabato, domenica e festivi; ticket 7,50 €; regolarizzazione entro 7 giorni a 22,50 €; 4,50 € nei garage convenzionati (sosta > 1 h). Numero della delibera [non verificato].
- **Open data:**
  - Varchi Area C (DS82): https://dati.comune.milano.it/dataset/ds82_infogeo_varchi_elettronici_localizzazione_ — CSV: https://dati.comune.milano.it/dataset/ds82_infogeo_varchi_elettronici_localizzazione_/resource/d0283c73-135a-4077-b66b-1e2d5479aecd ; ZIP/SHP: https://dati.comune.milano.it/dataset/ds82_infogeo_varchi_elettronici_localizzazione_/resource/87908ed9-9640-43c3-9678-cecf6cf1773f — **CC BY 4.0**, con campi ID AMAT, label, LONG/LAT EPSG:4326; frequenza di aggiornamento "irregolare".
  - Varchi Area B (DS959): https://dati.comune.milano.it/dataset/ds959-varchi-areab — "Creative Commons Attribution" (versione [non verificata]); ultima modifica 07/11/2023.
  - Mappa varchi Area C e B: https://dati.comune.milano.it/en/web/portale-del-dato/w/mappa-dei-varchi-di-area-c-e-area-b-a-milano
- **Tempo reale:** no.
- **Hotel:** per Area C nessuna procedura hotel trovata (solo ticket/garage). Per la ZTL Quadrilatero il gestore si registra online e invia ogni giorno un CSV con targhe e orari entro 24 h: https://servizicrm.comune.milano.it/centro-supporto/KA-03675/ZTL-Quadrilatero-moda-accesso-clienti-attivita

### Verona — punteggio 3
*Dataset con varchi in CC0, ordinanza citata; pagine sparse fra domini vecchi e nuovi.*

- **Pagine ufficiali:**
  - ZTL di Verona: https://www.comune.verona.it/Novita/Notizie/La-Zona-a-Traffico-Limitato-di-Verona
  - Mappa e orari: https://portale.comune.verona.it/nqcontent.cfm?a_id=30870
  - Accesso alla ZTL per turisti (Polizia Locale): https://polizialocale.comune.verona.it/nqcontent.cfm?a_id=26104
  - Portale accessi straordinari (targhe entro 72 h): https://polizialocale.comune.verona.it/nqcontent.cfm?a_id=86233
- **Regole/orari:** la pagina "Mappa e orari" cita l'**Ordinanza n. 1545 del 31/10/2024**; per i non autorizzati di Verona e provincia accesso solo su prenotazione (max 4 ingressi al mese, piattaforma Citypass) lun–ven 10–18 e 20–23, sab/dom/festivi 10–13:30. Fasce di libero accesso eliminate. Orari validi per i turisti non residenti in provincia: [da verificare].
- **Open data:** "Mappa della ZTL con varchi", **CC0 1.0**, ultimo aggiornamento 30/06/2025: https://www.comune.verona.it/Amministrazione/Documenti-e-dati/Dataset/Mappa-della-ZTL-con-varchi (formato indicato come CSV / Google Drive: verificare se contiene coordinate).
- **Tempo reale:** no.
- **Hotel:** l'albergatore comunica in anticipo la targa alla Polizia Locale (white list) con le credenziali fornite dall'U.O. Traffico e Mobilità; gli alberghi in ZTL danno accesso a qualsiasi ora; le locazioni turistiche seguono regole diverse.

### Siena — punteggio 3
*Regole chiare (ZTL 0–24) e servizio hotel ben documentato; nessun dato vettoriale.*

- **Pagine ufficiali:**
  - Accesso ZTL – Strutture ricettive: https://www.comune.siena.it/servizi/accesso-ztl-strutture-ricettive
  - Accesso ZTL – Persone fisiche: https://www.comune.siena.it/servizi/accesso-ztl-persone-fisiche
  - Disciplinare (GC 327 del 2/9/2025): https://www.comune.siena.it/sites/default/files/2025-09/disciplinare_GC_327_2_9_2025.pdf
  - Mappa ZTL: https://www.comune.siena.it/documento-pubblico/mappa-ztl ; PDF varchi: https://www.comune.siena.it/sites/default/files/2024-04/mappa%20varchi%20ZTL.pdf
- **Regole/orari:** ZTL valida 0–24 tutti i giorni; Zona Y storica accessibile solo 6:00–10:00; Zona A 6:00–10:00 e 15:30–17:00. Permesso temporaneo per persone fisiche (il primo gratis, max 4/mese; 5 € 1 h, 10 € 1 giorno).
- **Open data:** nessun dataset trovato; perimetro e varchi andrebbero digitalizzati dal PDF.
- **Tempo reale:** no.
- **Hotel:** servizio online gratuito per le strutture in ZTL (visura camerale, targa, orari, n. scheda TULPS), max 2 inserimenti/giorno per targa, solo percorso più breve; sosta solo per carico/scarico (45 minuti secondo la notizia del disciplinare aggiornato).

### Torino — punteggio 3
*Unico dataset con perimetro + varchi + orari insieme, ma fermo al 2021.*

- **Pagine ufficiali:** ZTL Centrale: https://www.comune.torino.it/schede-informative/ztl-centrale ; argomento ZTL: https://www.comune.torino.it/argomenti/mobilita-urbana/ztl ; permessi: https://www.comune.torino.it/servizi/richiedere-permesso-accesso-ad-area-ztl
- **Regole/orari:** ZTL Centrale lun–ven (sabato escluso) 7:30–10:30; ZTL Area Romana 21:00–7:30 tutti i giorni.
- **Open data:** "Perimetro, varchi e orari ZTL" (5T S.r.l.), CC BY, XML, ultimo aggiornamento maggio 2021, frequenza irregolare: https://aperto.comune.torino.it/dataset/perimetro-varchi-e-orari-ztl ; scheda: https://www.muoversiatorino.it/wp-content/uploads/2021/12/scheda_ztl.pdf ; altro dataset su https://www.muoversiatorino.it/it/open-data/
- **Tempo reale:** no.
- **Hotel:** gli albergatori in ZTL chiedono l'esenzione a posteriori per i clienti, da inviare a GTT entro 10 giorni dal primo transito; contatti infoztl@comune.torino.it, 800 450 900.

### Napoli — punteggio 3
*Orari per singolo varco molto chiari sul sito comunale; open data probabilmente vecchi.*

- **Pagine ufficiali:**
  - ZTL e Aree Pedonali: https://www.comune.napoli.it/articolo_tematico/trasporti-mobilita/ztl-e-aree-pedonali/
  - ZTL Centro Antico: https://www.comune.napoli.it/articolo_tematico/trasporti-mobilita/ztl-e-aree-pedonali/ztl-del-centro-antico/
  - ZTL Tarsia, Pignasecca, Dante: https://www.comune.napoli.it/articolo_tematico/trasporti-mobilita/ztl-e-aree-pedonali/ztl-tarsia-pignasecca-dante/
  - ZTL via Ferdinando Russo: https://www.comune.napoli.it/articolo_tematico/trasporti-mobilita/ztl-e-aree-pedonali/ztl-di-via-ferdinando-russo/
- **Regole/orari:** Centro Antico, 4 varchi: via del Sole lun–gio 9–22, ven/sab/dom/festivi/prefestivi 9–24 e fino alle 2; via Miroballo, via Duomo, via Santa Sofia 9–17 tutti i giorni. Tarsia-Pignasecca-Dante 9–18 tutti i giorni (pagina che cita ordinanze 2013–2020). Morelli-Filangieri-Mille stagionale (8 dic – 6 gen). Ordinanza Municipalità 1 n. 21 del 30/04/2026: https://static-www.comune.napoli.it/wp-content/uploads/2025/05/allegato1777550695.pdf. ZTL Morghen: non trovata.
- **Open data:** il catalogo elenca "ZTL e aree pedonali del Comune di Napoli" (Dati geografici); scheda, formato e licenza [non verificati]; gli altri shapefile del portale sono del 2015–2017. Catalogo: https://trasparenza.comune.napoli.it/flex/cm/pages/ServeBLOB.php/L/IT/IDPagina/22712
- **Tempo reale:** no.
- **Hotel:** solo per via F. Russo (ZTL stagionale dal 10/7/2026): gli alberghi inseriscono le targhe in Smartmobility con credenziali ANM.

### Genova — punteggio 3
- **Pagina/atto:** Disciplinare ZTL rev. 16/04/2025 (DGC 74-2025): https://www.comune.genova.it/sites/default/files/2025-06/Disciplinare%20ZTL%20aggiornato%20da%20DGC%2074-2025.pdf
- **Regole:** ZTL Centro Storico valida tutti i giorni 0–24; ZTL con telecontrollo: Centro Storico, Molo, Porticciolo di Nervi, Boccadasse, Vernazzola.
- **Open data:** perimetri ZTL in SHP, **CC BY 4.0**, coordinate Gauss-Boaga, file del 2018: https://dati.comune.genova.it/en/dataset/zone-a-traffico-limitato/resource/4243f13a-d325-40d4-bfcc-db474035bbb1 ; metadati: https://mappe.comune.genova.it/geonetwork/srv/api/records/c_d969:d7e99280-3fa0-4636-a326-9ccf199eecf1 . Varchi: non trovati.
- **Tempo reale / hotel:** no / [non verificato].

### Pisa — punteggio 2
- **Pagine ufficiali:** Registrazione targhe: https://www.comune.pisa.it/Servizi/Registrazione-Targhe-per-accesso-veicoli-in-ZTL ; Richieste accesso: https://www.comune.pisa.it/Servizi/ZTL-Richieste-Accesso-e-Archiviazione-Sanzioni ; Pisamo regolamento: https://pisamo.it/regolamento-ztl/ e https://pisamo.it/regolamento-ztl/ztl-2025/ ; indice ZTL: https://mobilita.pisamo.it/indice-ztl/ ; nuovo regolamento dal 1/1/2025: https://www.comune.pisa.it/Novita/Notizie/Ztl-e-Zsc-in-vigore-dal-1-gennaio-2025-il-nuovo-regolamento-per-il-transito-e-per-il-parcheggio
- **Regole:** settori Centro Storico Nord e Sud + aree particolari; **orari generali dei varchi non trovati** negli estratti. ZTL Stadio (Porta a Lucca) attiva solo nelle partite casalinghe (da 2 h prima del fischio d'inizio). Dal 2025 il PISAPASS cartaceo non serve più.
- **Open data:** nessun dataset ZTL trovato su https://opendata.comune.pisa.it/
- **Hotel:** registrazione gratuita delle targhe dei clienti sul portale (scadenza 6 h o 24 h: le fonti non concordano); contatti pm.ztl@comune.pisa.it, 050 910828.

### Lucca — punteggio 2
- **Pagine/atti:** Planimetria varchi/ZTL (PDF, dic. 2025): https://www.comune.lucca.it/documento_pubblico/planimetria-del-centro-storico-con-varchi-telematici-ztl-e-area-pedonale/ ; Disciplinare PAMS 2024: https://www.comune.lucca.it/app/uploads/2025/02/Disciplinare2024.pdf ; presentazione nuova ZTL: https://www.comune.lucca.it/app/uploads/2025/03/presentazione-nuova-ZTL.pdf ; varchi in uscita: https://www.comune.lucca.it/notizia/ztl-controlli-piu-stringenti-con-nuove-telecamere-e-varchi-in-uscita/
- **Regole:** nessun orario unico trovato; ZTL A con restrizioni extra 10:30–14:00 e 18:00–21:00 (PAMS); regole speciali per Lucca Comics (es. ord. 2702 del 20/10/2025: https://www.comune.lucca.it/app/uploads/2025/10/ord_02702_20-10-2025-Disciplinare-Centro-Storico-ZTL-COMICS-2025.pdf). Alcune telecamere della zona est sospese per cantiere.
- **Open data:** no (solo PDF). **Hotel:** permessi giornalieri ≤ numero di camere (regola in via di ripristino, data [non verificata]); gestione Lucca Plus (varchi@luccaplus.it).

### Perugia — punteggio 2
- **Pagine ufficiali:** https://www.comune.perugia.it/luogo/ztl-zone-a-traffico-limitato/ ; varchi: https://turismo.comune.perugia.it/pagine/varchi-ztl ; permessi giornalieri: https://www.comune.perugia.it/servizio/permessi-ztl-richiesta-autorizzazione-accesso-giornaliero-o-temporaneo/ ; Regolamento permessi ZTL: https://www.comune.perugia.it/wp-content/uploads/2024/11/07.01-Regolamento-permessi-ZTL.pdf
- **Regole:** orari diversi per varco (es. via del Roscetto 16–20; corso Bersaglieri feriali 21–14); pagina di circa 2 anni fa.
- **Open data:** no. **Hotel:** i veicoli diretti agli alberghi in ZTL entrano senza permesso; l'albergo invia ogni giorno l'elenco targhe (modalità attuale [non verificata]).

### Palermo — punteggio 2
- **Pagine ufficiali:** AMAT: https://www.amat.pa.it/la-ztl-tempi-e-perimetro-2/ ; Comune orari estivi: https://www.comune.palermo.it/novita/ztl-dal-2-maggio-orario-estivo/ ; portale ZTL: https://ztl.comune.palermo.it/ztl/jsp/home.jsp?modo=tabella ; disciplinare tecnico (ago. 2022): https://ztl.comune.palermo.it/ztl//docs/news/82053/A2022/M09/G17/all_01_disciplinare_ztl_agosto_2022.pdf
- **Regole:** orario estivo fino al 31/10/2026 (diurna lun–gio 8–20; ven dalle 8 alle 6 del sabato; sab notturna 20–6); dal 1/11 orario invernale → **alta stagionalità, cambi frequenti**.
- **Open data:** no (il disciplinare rimanda alle ordinanze per il perimetro). **Tempo reale:** no. **Hotel:** "lista bianca" gratuita, anche a posteriori (lun–gio entro le 24, ven–dom entro le 6), limite di capienza; AMAT riprende la gestione diretta (data [non verificata]): https://www.comune.palermo.it/novita/lista-bianca-ztl-dichiarazione-del-sindaco/

### Bergamo — punteggio 2
- **Pagine ufficiali:** https://www.atb.bergamo.it/ztl/ztl-di-bergamo ; Città Alta: https://www.comune.bergamo.it/page:c_a794:zona.traffico.limitata;quali.sono.ztl;centro.storico.citta.alta ; varchi in uscita dal 12/12/2025: https://www.atb.bergamo.it/avvisi/ztl-attivazione-varchi-in-uscita-dal-12-dicembre-2025
- **Regole:** centro storico di Città Alta 0–24; Città Alta e Colli domenica e festivi 10–24 dal 21/6/2026.
- **Open data / hotel:** non trovati (esiste solo lo "smarcamento" ospiti dei residenti dei Colli e la ZTL Valverde).

### Venezia (terraferma, Mestre) — punteggio 2
- **Pagina:** AVM: https://avm.avmspa.it/it/content/le-zone-traffico-limitato-del-centro-di-mestre-0 (pagina di circa 3,5 anni fa: divieto 0–24, 4 varchi elettronici).
- **Open data / tempo reale / hotel:** non trovati. Interesse limitato per i turisti (il centro storico di Venezia non è percorribile in auto; la ZTL Bus è un altro tema).

---

## Dataset più utili (riepilogo)

| Città | Dataset | Contenuto | Licenza |
|---|---|---|---|
| Firenze | https://opendata.comune.fi.it/page_dataset_show?id=0fe68709-c864-4e21-b18e-07ee3e9328e2 | Porte telematiche (varchi) SHP + GeoJSON | CC-BY 4.0 |
| Firenze | https://opendata.comune.fi.it/page_dataset_show?id=9257a75e-3af3-4845-b37d-1540be29115a | Perimetro ZTL diurna | CC-BY 4.0 |
| Firenze | https://www.dati.toscana.it/dataset/3d586fa5-7367-42c5-b5f2-d8348a5da431 | Perimetro ZTL notturna | CC-BY 4.0 |
| Milano | https://dati.comune.milano.it/dataset/ds82_infogeo_varchi_elettronici_localizzazione_ | Varchi Area C (CSV lat/lon, GeoJSON, SHP) | CC BY 4.0 |
| Milano | https://dati.comune.milano.it/dataset/ds959-varchi-areab | Varchi Area B | CC BY (versione da verificare) |
| Bologna | https://opendata.comune.bologna.it/explore/dataset/zona-a-traffico-limitato/ | Perimetro ZTL | da verificare |
| Bologna | https://opendata.comune.bologna.it/explore/dataset/varchi-bologna/table/ | Elenco varchi | CC BY 4.0 (sulla serie dei singoli varchi) |
| Roma | https://romamobilita.it/sistemi-e-tecnologie/dataset-geografici/ | Confini + varchi di tutte le ZTL (GeoServices REST) | licenza d'uso da accettare (da leggere) |
| Verona | https://www.comune.verona.it/Amministrazione/Documenti-e-dati/Dataset/Mappa-della-ZTL-con-varchi | ZTL con varchi | CC0 1.0 |
| Torino | https://aperto.comune.torino.it/dataset/perimetro-varchi-e-orari-ztl | Perimetro, varchi, orari (XML, 2021) | CC BY |
| Genova | https://dati.comune.genova.it/en/dataset/zone-a-traffico-limitato/resource/4243f13a-d325-40d4-bfcc-db474035bbb1 | Perimetri ZTL (SHP, 2018) | CC BY 4.0 |

## Prossimi passi consigliati
1. Abilitare nell'ambiente l'accesso di rete ai domini comunali (o fare la verifica da un browser) e **riaprire ogni URL** qui sopra per confermare orari, numeri di ordinanza e licenze; salvare la data di verifica per ogni record.
2. Scaricare i dataset di Firenze, Milano, Bologna e Verona e controllare che le coordinate dei varchi corrispondano ai varchi ZTL (non ai sensori di traffico).
3. Per Roma, leggere il testo della licenza d'uso dei dataset geografici RSM prima di redistribuirli nell'app.
4. Prevedere nel modello dati: ZTL a pagamento (Milano), ZTL stagionali/notturne (Firenze, Roma, Palermo), regole per evento (Lucca Comics, ZTL Stadio Pisa), varchi in uscita (Roma 2027, Lucca, Bergamo).
