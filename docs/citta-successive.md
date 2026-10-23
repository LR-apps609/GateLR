# GateLR – Città successive a Firenze: ricerca verificata sulle fonti ufficiali

**Data di verifica:** 23 ottobre 2026
**Base di partenza:** `docs/ricerca-citta.md` (report precedente, basato solo su estratti di ricerca). Qui ogni dato è stato **riaperto** sulla pagina ufficiale quando la rete lo consentiva.

**Legenda delle fonti**
- *(pagina aperta)*: testo letto da me sulla pagina o sul PDF ufficiale indicato (curl o API del sito).
- **[solo da estratto di ricerca]**: il dominio era bloccato dal proxy ("CONNECT tunnel failed, response 403") o non raggiungibile; il dato viene da un estratto di WebSearch su un dominio ufficiale e va riverificato prima della pubblicazione.
- **[non trovato]** / **[da verificare]**: informazione assente o non confermata. Nessun URL, importo od orario è stato dedotto.

**Raggiungibilità in questa sessione:** aperti senza problemi romamobilita.it, www.comune.bologna.it (contenuti via API `myportal/C_A944/api/content/slug/<slug>`, perché il sito è renderizzato in JavaScript), opendata.comune.bologna.it (connessioni instabili, riuscite dopo più tentativi), www.comune.milano.it e dati.comune.milano.it (con User-Agent da browser), www.comune.verona.it, polizialocale.comune.verona.it, www.comune.siena.it, www.comune.napoli.it. **Non raggiungibili:** www.comune.torino.it e aperto.comune.torino.it (connessione resettata a ogni tentativo), data-rsm.opendata.arcgis.com (hub open data di Roma), areac.atm-mi.it, servizicrm.comune.milano.it, portale.comune.verona.it (503), archive.comune.verona.it, amt3.it, gtt.to.it e tutti i domini di Pisa, Lucca, Bergamo, Genova, Perugia e Palermo (bloccati dal proxy).

---

## 1. Sintesi e ordine consigliato per le prossime 4 città

| # | Città | Perché adesso |
|---|---|---|
| 1 | **Bologna** | La regola più semplice d'Italia (ZTL 7–20 "tutti i giorni"), ticket per turisti **6 €/giorno** e **15 €/4 giorni** acquistabile online con carta, procedura hotel chiara, **open data CC BY 4.0 già scaricati** (perimetro ZTL, Zona T, zone pedonali, 79 varchi con tipologia). Resta da fare: filtrare i varchi ZTL dai varchi per corsie bus, e chiedere conferma esplicita sui festivi. |
| 2 | **Milano (Area C + Area B)** | Orari espliciti con **"festivi esclusi"**, prezzi ufficiali in PDF (7,50 €; 4,50 € in autorimessa convenzionata; 22,50 € se si paga tra il 2° e il 7° giorno), regole di attivazione del ticket precise. **Dataset CC BY scaricati:** 42 varchi Area C (aggiornati il 14/10/2026), 188 varchi Area B e i **poligoni di Area C e Area B** (dataset "Aree pedonali e ZTL"). Logica diversa dalle altre città: "puoi entrare pagando" (Area C), "entrano tutti tranne i veicoli più inquinanti" (Area B). |
| 3 | **Roma** | La pagina ufficiale più completa: orari per ogni ZTL, con le frasi "esclusi i festivi" / "anche se festivi", la sospensione delle notturne ad agosto e la nuova ZTL Appia Antica (dal 19/09/2026). Procedura hotel dettagliata (targa inseribile **entro la giornata stessa** dell'accesso). Novità critica: **dal 1/7/2026 anche le auto elettriche hanno bisogno del permesso**. Manca solo la geometria: l'hub ArcGIS di RSM (licenza CC BY 3.0 IT) è bloccato dal proxy, quindi va scaricato da un'altra rete. |
| 4 | **Siena** | Regola ufficiale semplice e recente (Deliberazione GC n. 327 del 02/09/2025): ZTL valida **"tutti i giorni nell'orario 0/24"**, e quindi niente problema festivi. Tariffe ufficiali dei permessi temporanei (gratis 30 min fino a 4 volte al mese, poi 5 € per 1 h, 10 € per 1 giorno, 20 € per 2–3 giorni) e procedura hotel online. Città molto visitata in auto dai turisti. Punto debole: **nessun open data**, quindi perimetro e varchi vanno digitalizzati dal PDF "Mappa ZTL con Varchi" (2025-06). |

**Subito dopo:** **Verona** (regola chiara per chi non è della provincia, cioè nessun accesso senza hotel in ZTL; CSV ufficiale con 11 varchi e coordinate). Due ostacoli: la **licenza CC BY-NC 4.0** (non commerciale, e il report precedente diceva per errore CC0) e alcune pagine marcate come "archivio non più aggiornato". Poi **Napoli** (orari ufficiali chiari, ma per singolo varco e con molte ZTL stagionali, senza open data raggiungibili). **Torino** non è stato verificabile (sito irraggiungibile).
**Da rimandare:** Pisa, Lucca, Bergamo, Genova, Perugia, Palermo: domini bloccati, orari frammentati e/o legati a eventi, nessun dataset verificato.

**Lacuna "festivi" (punto noto), stato attuale:**
- **Esplicito sulla pagina ufficiale:** Roma ("esclusi i festivi" per Centro diurna e notturna, Tridente, Trastevere diurna e Testaccio; "anche se festivi" per le notturne di Trastevere e San Lorenzo), Milano Area C e Area B ("festivi esclusi"), Napoli (via del Sole e Mezzocannone: "venerdì, sabato, domenica, festivi e prefestivi"), Siena ("tutti i giorni nell'orario 0/24").
- **Implicito:** Bologna dice "tutti i giorni, dalle 7 alle 20", ma la parola "festivi" non compare in nessuna delle pagine aperte. L'unica conferma è un estratto di ricerca che riprende la stessa frase **[da confermare con il Comune]**.
- **Da verificare:** il calendario dei festivi di Milano. Non è chiaro se Sant'Ambrogio (7 dicembre, patrono) conti come "festivo" per Area C **[non trovato]**.

---

## 2. Tabella comparativa

| Città | Orari ZTL principali (fonte aperta) | Festivi | Prezzo per il turista | Hotel | Open data scaricati | Licenza | Punteggio |
|---|---|---|---|---|---|---|---|
| **Bologna** | 7–20 tutti i giorni (Sirio); Zona T, pedonali, Università, S. Francesco-Pratello, Moline: 24/24 | "tutti i giorni", senza la parola "festivi" | Ticket 6 € (1 giorno), 15 € (4 giorni consecutivi), da attivare prima dell'ingresso | Targa comunicata al gestore, anche all'arrivo; abbonamento di sosta 9 € | Sì: ZTL (14 poligoni), Zona T, zone pedonali (62), varchi (79 punti) | CC BY 4.0 | **5** |
| **Milano** | Area C e Area B: lun–ven 7:30–19:30 | Esplicito: "festivi esclusi" | Area C 7,50 €; 4,50 € in autorimessa convenzionata; 22,50 € se pagato tra il 2° e il 7° giorno; Area B gratis per i veicoli ammessi | Nessuna procedura hotel per Area C (si usa ticket o autorimessa) | Sì: varchi Area C (42), varchi Area B (188), poligoni Area C/B + 23 ZTL locali | CC BY (CKAN `cc-by`) | **5** |
| **Roma** | Centro: lun–ven 6:30–18, sab 14–18; Tridente: lun–ven 6:30–19, sab 10–19; Trastevere diurna: lun–sab 6:30–10; notturne; Appia Antica: sab–dom 7–19 | Esplicito per ogni ZTL | Nessun permesso giornaliero per i turisti; temporanei solo per categorie (10 €/giorno + 92 € di bolli e diritti) | Albergo registrato al "Servizio Alberghi Web"; targa inserita **entro la giornata dell'accesso** | No (hub ArcGIS bloccato) | CC BY 3.0 IT (dichiarata da RSM) | **4** |
| **Siena** | ZTL 0/24 tutti i giorni; Zona Y storica 6–10; Zona A 6–10 e 15:30–17 | Implicito (0/24 ogni giorno) | Temporanei per motivi specifici: gratis 30 min (max 4/mese), poi 5 € per 1 h, 10 € per 1 giorno, 20 € per 2 o 3 giorni | Online; entro 2 giorni lavorativi (pagina) / non oltre 3 giorni (disciplinare) | No (solo PDF) | – | **3** |
| **Verona** | Per i non autorizzati senza hotel: nessun accesso. Per residenti a Verona e provincia: lun–ven 10–18 e 20–23, sab/dom/festivi 10–13:30, solo su prenotazione | Esplicito solo per la fascia dei residenti in provincia | Nessun ticket per i turisti di fuori provincia [non trovato] | L'albergatore comunica la targa in anticipo; vale solo per hotel dentro la ZTL e non per le locazioni turistiche | CSV con 11 varchi (lat,lon), senza perimetro | **CC BY-NC 4.0** | **3** |
| **Napoli** | Per varco: via del Sole lun–gio 9–22, ven/sab/dom/festivi/prefestivi 9–24 e fino alle 2; Miroballo, Duomo, S. Sofia 9–17; Tarsia 9–18; più ZTL stagionali | Esplicito per alcuni varchi | Solo deroghe per necessità straordinarie | Alberghi in ZTL F. Russo e Marechiaro: registrazione su Smartmobility ANM | No (dominio open data bloccato) | – | **3** |
| **Torino** | ZTL Centrale 7:30–10:30 feriali, sabato escluso [estratto]; Area Romana 21–7:30 [estratto] | [estratto] | – | Esenzione a posteriori tramite GTT entro 10 giorni [estratto] | No (sito irraggiungibile) | CC BY o IODL 2.0 (fonti discordanti) [estratto] | **2** |
| Genova | Centro Storico 0–24 tutti i giorni [estratto] | [estratto] | Autorizzazione giornaliera 11 € (categorie) [estratto] | Clienti per bagagli: richiesta entro 48 h [estratto] | SHP 2018 (non scaricato) | CC BY 4.0 [rep. prec.] | 2 |
| Pisa | Orari del centro [non trovati] | – | – | Portale per le strutture ricettive [estratto] | No | – | 2 |
| Lucca | 8–19 secondo l'ordinanza Comics 2025 [estratto, non generalizzabile] | – | – | Permessi giornalieri ≤ n. camere [estratto] | No | – | 2 |
| Bergamo | Città Alta: domenica e festivi 10–24 dal 21/6/2026 [estratto] | [estratto] | – | [non trovato] | No | – | 2 |
| Perugia | Orari per varco (es. via del Roscetto 16–20) [estratto] | – | Giornaliero online, prezzo calcolato in procedura [estratto] | Contrassegno rilasciato dall'albergo, da rinnovare ogni giorno [estratto] | No | – | 2 |
| Palermo | Estiva e invernale, cambio il 1/11 [estratto] | – | Pass giornaliero 5 € / 2,50 € ibride / gratis elettriche [estratto] | Lista bianca [rep. prec.] | No | – | 2 |

---

## 3. Schede per città

### 3.1 Bologna — punteggio 5

**Pagine ufficiali aperte**
- ZTL (scheda informativa): https://www.comune.bologna.it/informazioni/zona-traffico-limitato-ztl. Contenuto letto via API: https://www.comune.bologna.it/myportal/C_A944/api/content/slug/zona-traffico-limitato-ztl (modificata il 03/08/2026)
- Ticket: https://www.comune.bologna.it/servizi/mobilita-trasporti/ticket-accesso-ztl (API slug `ticket-accesso-ztl`, modificata il 07/10/2026)
- Clienti di alberghi, autorimesse e autofficine: https://www.comune.bologna.it/servizi/mobilita-trasporti/accesso-sosta-ztl-clienti-alberghi-autorimesse-autofficine (modificata l'11/02/2026)
- Veicoli elettrici: slug `accesso-sosta-veicoli-elettrici` (modificata il 06/10/2026)
- Sirio, vigile elettronico: slug `sirio-vigile-elettronico-ztl` (modificata il 05/06/2025)

**1. Orari** *(pagina aperta, scheda ZTL)*
> "Le limitazioni previste nella zona a traffico limitato (ztl) regolano gli accessi, tramite il sistema di videosorveglianza Sirio - Vigile elettronico, tutti i giorni, dalle 7 alle 20. All'interno della ztl ci sono, inoltre, alcune zone limitate 24 ore su 24: le zone pedonali e l'area T."

Dalla pagina del ticket: *"Puoi utilizzare il ticket tutti i giorni dalle 7 alle 20. Dopo le 20 non puoi più convalidarlo, perché il sistema di telecontrollo Sirio non è attivo."* Zone 24/24 escluse dal ticket: zona T, Azzo Gardino, ZTL speciali Università, San Francesco-Pratello e Moline-Capo di Lucca, Archiginnasio, corsie bus, aree pedonali. Nessuna variante stagionale né sospensione di agosto trovata.
Cantieri: dal 15/07/2024 è in vigore l'ordinanza P.G.n. 466849/2024 (Garisenda e cantieri del tram), che restringe gli autorizzati in zona T (via Ugo Bassi in entrata, via Rizzoli in uscita).

**2. Festivi:** la formula ufficiale è "tutti i giorni"; la parola "festivi" non compare nelle pagine aperte. Per il modello dati: attiva 365 giorni. **[Chiedere conferma scritta: 800108088 o https://solweb.sostyscarl.it/]**

**3. Prezzi e acquisto** *(pagina aperta, ticket)*
> "Il ticket giornaliero costa 6 euro, mentre il ticket quadrigiornaliero (per quattro giorni consecutivi) costa 15 euro."

> "Devi attivare il titolo prima dell'accesso alla ztl e attendere sempre il messaggio di convalida del ticket. Il ticket giornaliero scade alle 24 del giorno in cui è stato convalidato, mentre il ticket quadrigiornaliero scade alle 24 del terzo giorno successivo…"

Limiti: *"Per ogni mese solare puoi utilizzare per lo stesso veicolo tre titoli giornalieri, oppure un solo titolo quadrigiornaliero"* (i due tipi non sono cumulabili). Acquisto online sul sito del gestore Sosty, https://www.sostyscarl.it/e-commerce/ (servono targa, generalità e carta di credito), oppure agli sportelli Sosty Azzarita e Gobetti. Per le targhe estere: *"togli il segno di spunta dalla casella 'targa italiana'"*. Vale solo per veicoli sotto gli 80 quintali; *"La sosta è a pagamento."*

**4. Hotel** *(pagina aperta)*
> "Prima di raggiungere con la tua auto l'attività prenotata nella ztl, devi rivolgerti al gestore e fornire i dati del veicolo per consentirne l'accesso. Se non hai fornito i dati del veicolo prima di giungere all'esercizio, puoi farlo direttamente al tuo arrivo presso la struttura o l'attività che provvede a comunicare la tua targa al Comune con le modalità e le procedure concordate."

Nessuna scadenza in ore indicata dal Comune (la procedura è "concordata" con le strutture). Costo: *"L'abbonamento per gli alberghi è disponibile presso la struttura ricettiva al costo di 9 euro e include un abbonamento giornaliero Tper"* (sosta sulle strisce blu, 24 h dalla validazione). Restano vietate per tutti zona T, zone pedonali, Università, S. Francesco-Pratello e Moline, salvo il percorso indicato dalla struttura convenzionata.

**5. Open data** *(API Opendatasoft aperta; file salvati in `data/raw/bologna/`)*

| Dataset | Pagina | Download GeoJSON | Licenza | Ultimo agg. dati | Feature | Proprietà |
|---|---|---|---|---|---|---|
| Zona a traffico limitato (ZTL) | https://opendata.comune.bologna.it/explore/dataset/zona-a-traffico-limitato/ | https://opendata.comune.bologna.it/api/explore/v2.1/catalog/datasets/zona-a-traffico-limitato/exports/geojson | CC BY 4.0 | 26/08/2021 | 14 (13 Polygon + 1 MultiPolygon) | `geo_point_2d, ente, codice, ordinanza, stato, area, codarco1..7, nomevia1..7, _errors, layer, path` |
| Elenco varchi Bologna | https://opendata.comune.bologna.it/explore/dataset/varchi-bologna/ | …/datasets/varchi-bologna/exports/geojson | CC BY 4.0 | 11/12/2024 | 79 Point | `identificativo_varco, attivo, nome_varco, descrizione, direzione, tipologia_varco, inizio_attivita, dati_totali, dati_2019..2022` |
| Zona T centro storico | https://opendata.comune.bologna.it/explore/dataset/zona-t-centro-storico/ | …/datasets/zona-t-centro-storico/exports/geojson | [licenza non letta: metadati non scaricati] | – | 1 Polygon | come ZTL + `iidd, tipoztl` |
| Zona pedonale centro storico | https://opendata.comune.bologna.it/explore/dataset/zona-pedonale-centro-storico/ | …/datasets/zona-pedonale-centro-storico/exports/geojson | CC BY 4.0 | 28/05/2026 | 62 MultiPolygon | come Zona T |

Note per il converter:
- La ZTL principale è la feature con `codice = 40` (area 2.852.781 m²); le altre 13 sono sottozone più piccole.
- `ordinanza` vale sempre "4000/343434", quindi non è un riferimento utile.
- Nel file varchi, `tipologia_varco` distingue `ZTL` (22 varchi), `ZTLS` (6), `ZTL speciale` (2), `APU` (10), `DT` (5), `corsie` (33) e 1 `null`. Per GateLR servono `ZTL` (+ `ZTLS` / `ZTL speciale` / `APU` come zone 24/24). Tutti hanno `attivo = "S"`.
- Coordinate WGS84 (GeoJSON RFC 7946).

**6. Elettrici** *(pagina aperta)*: contrassegno gratuito, *"Puoi richiedere il contrassegno se hai un veicolo elettrico, anche se non risiedi a Bologna"*, da chiedere **prima** dell'accesso (di persona si ottiene subito; online entro 5 giorni). Consente ZTL, zona T e zone speciali. Le ibride di non residenti: nessun nuovo permesso dal 1/1/2026.

**7. Punteggio 5.** Manca la conferma esplicita sui festivi, e il perimetro ZTL è del 2021 (da confrontare con la delibera PG 169974/2004).

---

### 3.2 Milano (Area C e Area B) — punteggio 5

**Pagine ufficiali aperte**
- Area C: https://www.comune.milano.it/argomenti/mobilita/area-c (ultimo aggiornamento 15/10/2026; versione EN https://www.comune.milano.it/en/argomenti/mobilita/area-c)
- Acquisto ticket: https://www.comune.milano.it/servizi/mobilita/area-c-acquista-il-ticket (16/06/2026)
- Attivazione ticket: https://www.comune.milano.it/servizi/mobilita/area-c-attiva-il-ticket (16/06/2026)
- Tariffe (PDF): https://www.comune.milano.it/documents/20118/35188/Area+C+nuove+tariffe+dal+2023+Area+C.pdf/5ee21a73-7301-60c7-d2fe-5e2f77e8a158?version=1.0&t=1746021538283&download=true
- Area B: https://www.comune.milano.it/argomenti/mobilita/area-b (15/10/2026)
- Disciplinare dei pagamenti di Area C, DD 1856 del 13/03/2026: https://www.comune.milano.it/documents/d/guest/determina-dirigenziale-n-1856-del-13-03-2026-pdf?download=true

**1. Orari** *(pagine aperte)*
> Area C: "Area C è attiva tutto l'anno dal lunedì al venerdì, dalle 7:30 alle 19:30 (festivi esclusi)."

> Area B: "Area B è attiva dal lunedì al venerdì dalle 7:30 alle 19:30, festivi esclusi."

Nessuna sospensione di agosto indicata ("tutto l'anno"). Area B non prevede pagamento (*"Ai veicoli ammessi non è richiesto alcun pagamento"*), ma vieta l'ingresso ai veicoli più inquinanti secondo il calendario dei divieti. Novità dal 1/10/2026: *"5 giornate di libero accesso assegnate automaticamente ad ogni veicolo, a partire dal secondo anno di divieto, senza obbligo di registrazione della targa"*. Per Area C c'è anche il divieto per i veicoli lunghi più di 7,50 m e per il trasporto merci dalle 8 alle 10 (DD 1856/2026).

**2. Festivi:** esplicito, "festivi esclusi" sia per Area C sia per Area B. Da verificare se il 7 dicembre (Sant'Ambrogio) rientri tra i festivi **[non trovato]**.

**3. Prezzi** *(PDF tariffe aperto, "Area C: ticket in vigore dal 30 ottobre 2023")*
- "Tutti i veicoli: € 7,50"
- "Veicoli in sosta presso autorimesse site in Area C: € 4,50" (la pagina di acquisto aggiunge: "ingresso in Area C: 4,50 euro se la sosta in autorimessa dura più di un'ora")
- "Tutti i veicoli, ad eccezione degli NCC, che hanno effettuato il pagamento della rispettiva somma di accesso oltre le ore 24:00 del giorno successivo all'accesso ed entro il termine delle ore 24:00 del settimo giorno successivo a quello in cui è avvenuto l'accesso: € 22,50"
- Residenti: 3,00 € dal 51° accesso; veicoli di servizio: 4,50 €.

Durata: *"con un ticket puoi entrare e uscire da Area C con uno stesso veicolo tutte le volte che vuoi nella stessa giornata."*
Attivazione *(pagina aperta)*: per i ticket di autorimessa *"Entro la mezzanotte dello stesso giorno in cui è avvenuto l'accesso"*; per le altre modalità *"Dal giorno in cui è avvenuto l'accesso, entro la mezzanotte del giorno successivo"*; e ancora *"Le attivazioni effettuate il giorno prima dell'accesso o oltre le ore 24 del giorno successivo a quello previsto non coprono l'ingresso"*.
Canali di acquisto: online su https://areac.atm-mi.it/Areac/iweb/Acquisto.aspx (attivazione senza registrazione: https://areac.atm-mi.it/Areac/iweb/Attivazione.aspx); bancomat abilitati Intesa Sanpaolo; parcometri; SISAL, tabaccherie PUNTOLIS, edicole o bar LIS Pay; Telepass (*"solo per i veicoli immatricolati in Italia"*); UnipolMove; PayPal; autorimesse convenzionate; telefono 02 4868 4001 (tutti i giorni 7–24).

**4. Hotel:** per Area C **nessuna procedura hotel** sulle pagine aperte; per i clienti l'opzione ufficiale è il ticket in autorimessa convenzionata (4,50 €). Per la ZTL Quadrilatero della Moda il report precedente citava una procedura FAQ su servizicrm.comune.milano.it (dominio bloccato, **[non riverificato]**).

**5. Open data** *(API CKAN aperta; file in `data/raw/milano/`)*

| Dataset | Pagina | Download | Licenza | Ultimo agg. | Feature | Proprietà |
|---|---|---|---|---|---|---|
| Varchi Area C (DS82) | https://dati.comune.milano.it/dataset/ds82_infogeo_varchi_elettronici_localizzazione_ | GeoJSON: https://dati.comune.milano.it/dataset/4cad1605-8225-4ecd-9b82-868b3af453e5/resource/fa8fcc31-1722-4a50-a0ae-ce7b9c0d0361/download/ingressi_areac_varchi.geojson · CSV: …/resource/d0283c73-135a-4077-b66b-1e2d5479aecd/download/ingressi_areac_varchi.csv | `cc-by` "Creative Commons Attribution" | 14/10/2026 | 42 Point (CRS84) | `id_amat, label` (CSV: `id_amat;label;LONG_X_4326;LAT_Y_4326;Location`, separatore `;`) |
| Varchi Area B (DS959) | https://dati.comune.milano.it/dataset/ds959-varchi-areab | GeoJSON: https://dati.comune.milano.it/dataset/cebfe28e-a50e-4b81-9d14-7b0d37170f0d/resource/c3439df3-673d-45e7-b151-c6d8d70ba0e4/download/areab_varchi.geojson | `cc-by` | file 07/11/2023 | 188 Point | `id_amat, nome, autorizzaz, stato` (149 "ATTIVI E SANZIONANTI", 22 "IN PRE-ESERCIZIO", 17 "DA PROGRAMMARE PRE-ESERCIZIO") |
| Aree pedonali e ZTL (DS51) | https://dati.comune.milano.it/dataset/ds51_trafficotrasporti_aree_pedonali_ztl | GeoJSON: https://dati.comune.milano.it/dataset/d7d9179a-8228-427f-9c86-1e30154be4fe/resource/d788b26b-31b4-4e57-992d-276a1280c8c2/download/disciplina_aree.geojson | `cc-by` | file 02/05/2023 | 217 MultiPolygon: `AP` 110, `DT` 76, `ZTL` 23, `DA` 6, **`AREA_C` 1, `AREA_B` 1** | `id_amat, tipo, nome, gruppo_id, ordinanza, deroghe, val_inizio, val_fine, delibera, tratto, note, cartello, dissuasori` |

Note per il converter: perimetro di Area C = feature `tipo == "AREA_C"` (id_amat 276); Area B = `tipo == "AREA_B"` (id_amat 277). Le 23 ZTL locali (es. "Navigli notturna", "San Siro Eventi", "Corso Como") non hanno orari nel dataset, quindi vanno documentate a parte. Il file DS51 è del 2023: confrontarlo con la mappa ufficiale del geoportale (https://geoportale.comune.milano.it/portal/apps/webappviewer/index.html?id=bab7a4fea79f4e8bb0ab01e203168995).

**6. Elettrici / esenzioni:** sulle pagine aperte non c'è una frase esplicita. Le FAQ comunali (servizicrm.comune.milano.it/centro-supporto/KA-01161, dominio bloccato) riportano che i veicoli elettrici e alcuni ibridi sono esentati dal ticket **[solo da estratto di ricerca]**. La pagina Area C offre una verifica per targa e nazionalità: https://areac.atm-mi.it/Areac/iweb/CercaClasse.aspx.

**7. Punteggio 5.** Restano da fare: la conferma dell'esenzione per gli elettrici dalla fonte primaria, il calendario dei festivi (7 dicembre) e gli orari delle 23 ZTL locali.

---

### 3.3 Roma — punteggio 4

**Pagine ufficiali aperte (Roma Servizi per la Mobilità)**
- ZTL in centro, confini e orari: https://romamobilita.it/muoversi-a-roma/ztl-in-centro/ (aggiornata il 28/07/2026)
- "Ztl, tutti gli orari": https://romamobilita.it/infomobilita/ztl-tutti-gli-orari/ (aggiornata il 21/10/2026)
- Permesso ZTL Appia Antica: https://romamobilita.it/servizi-al-pubblico/permesso-ztl-appia-antica/
- Permessi temporanei: https://romamobilita.it/servizi-al-pubblico/permessi-temporanei/ (07/05/2026)
- Permesso X (alberghi): https://romamobilita.it/servizi-al-pubblico/permesso-x-circolazione-e-sosta/
- Regolamento "Servizio Alberghi Web" (PDF): https://romamobilita.it/wp-content/uploads/2016/06/ZTL_Regolamento_Alberghi.pdf
- Elettrici dal 1/7/2026: https://romamobilita.it/servizi-al-pubblico/accesso-in-ztl-di-veicoli-elettrici-o-a-idrogeno-novita-dal-1-luglio-2026/
- Dataset geografici: https://romamobilita.it/sistemi-e-tecnologie/dataset-geografici/

**1. Orari** *(pagina aperta "ztl-in-centro")*
> "La ZTL Centro Storico diurna è interdetta ai veicoli non autorizzati nei seguenti orari: 6.30-18.00 da lunedì a venerdì (esclusi i festivi) 14.00-18.00 il sabato (esclusi i festivi)"

> "La ZTL Centro Storico notturna è interdetta ai veicoli non autorizzati nei seguenti orari: 23.00-3.00 venerdì e sabato (esclusi i festivi) nel mese di agosto la ZTL notturna non è attiva"

> "La ZTL Tridente (A1) è interdetta ai veicoli non autorizzati (automobili, ciclomotori e motocicli) nei seguenti orari: 6.30-19.00 da lunedì a venerdì (esclusi i festivi); 10.00-19.00 il sabato (esclusi i festivi)"

> "La Zona a Traffico Limitato (ZTL) diurna Trastevere è interdetta ai veicoli non autorizzati: dalle 6.30 alle 10.00 dal lunedì al sabato (esclusi i festivi)"

> "La Zona a Traffico Limitato (ZTL) notturna Trastevere è interdetta … dalle 21.30 alle 3.00 venerdì e sabato (anche se festivi) da maggio a ottobre è attiva anche il mercoledì e il giovedì (anche se festivi) con gli stessi orari nel mese di agosto la ZTL notturna non è attiva"

> San Lorenzo notturna: "dalle 21.30 alle 3.00 venerdì e sabato (anche se festivi) da maggio ad ottobre è attiva anche il mercoledì e il giovedì (anche se festivi) con gli stessi orari nel mese di agosto la ZTL non è attiva."

> Testaccio notturna: "dalle 23.00 alle 3.00 venerdì e sabato (esclusi i festivi); nel mese di agosto la ZTL non è attiva."

> Appia Antica (pagina permesso): "A partire dal 19 settembre 2026 è operativa, nei giorni di sabato e domenica dalle 7.00 alle 19.00 – tutto l'anno, ad eccezione del mese di agosto – la ZTL Appia Antica" (tratti: via Appia Antica nn. 1–114, via Ardeatina nn. 108–172 solo pari).

⚠️ **Incoerenza tra due pagine RSM:** la mini-guida "tutti gli orari" dice che le notturne di Trastevere e San Lorenzo *"sono in funzione dal mercoledì al sabato dalle 21.30 alle 3.00"* senza indicare la stagione, mentre la pagina di dettaglio dice mercoledì e giovedì solo da maggio a ottobre. Il modello deve seguire la **pagina di dettaglio** (più specifica). Non ho trovato una regola per il "mese di Monti" o per Villa Borghese.
Moto: libero accesso tranne Tridente A1. Fascia Verde (veicoli inquinanti): pagina separata, non analizzata.

**2. Festivi:** esplicito, ZTL per ZTL (vedi sopra). È il caso migliore trovato.

**3. Prezzi:** **nessun permesso giornaliero per i turisti.** I "permessi temporanei" sono riservati a categorie (impedimenti fisici, merci, servizi tecnologici, eventi, funebri). Costo *(pagina aperta)*: "Costo onere concessorio per ogni giorno di autorizzazione per il singolo veicolo: € 10,00" + "€ 16,00 … imposta di bollo virtuale per la richiesta + € 16,00 … del permesso + € 60,00 … diritti di istruttoria". Le "Autorizzazioni giornaliere" gratuite (https://romamobilita.it/servizi-al-pubblico/autorizzazioni-giornaliere/) valgono solo per figure istituzionali, medici, persone con disabilità di altri Comuni, taxi di altri Comuni e carri attrezzi. Per l'app la risposta è quindi: **"non puoi entrare senza permesso; parcheggia fuori ZTL"**.

**4. Hotel** *(pagina Permesso X + PDF regolamento aperti)*
> "Per le attività alberghiere, è necessario preventivamente registrarsi compilando l'apposito modulo e sottoscrivere il relativo regolamento da inviare via PEC a permessistica@PEC.romamobilita.it … sportello online cliccando su 'Hotel, autorizzazione per i clienti'."

Dal regolamento "Servizio Alberghi Web", art. 5:
> "per ciascun contrassegno è possibile abbinare una sola targa al giorno per ogni fascia oraria; le fasce orarie di accesso sono quattro: mattutina (dalle 06:30 alle 14:00), pomeridiana (dalle 14.01 alle 18:00), giornaliera (dalle 06:30 alle 18:00), notturna (dalle 23:00 alle 03:00 – nelle sole giornate del venerdì e sabato); è possibile richiedere l'autorizzazione per il veicolo ad uso del cliente entro la medesima giornata dell'effettivo accesso nelle Zona a Traffico Limitato di Roma in cui ha sede la struttura alberghiera."

Limite: "1 permesso ogni 10 stanze a disposizione degli istituti alberghieri" (pagina Permesso X). Vale solo per la ZTL in cui ha sede l'albergo.

**5. Open data** *(pagina aperta)*
> "In questa pagina trovate i dataset messi a disposizione da Roma Servizi per la Mobilità in formato GeoServices REST. Per utilizzarli non è necessaria alcuna registrazione, ma si deve accettare la licenza d'uso" (il link punta a https://creativecommons.org/licenses/by/3.0/it/, cioè **CC BY 3.0 IT**). La pagina è aggiornata al 27/11/2023 e rimanda all'hub https://data-rsm.opendata.arcgis.com, **bloccato dal proxy (connect_rejected) e quindi non scaricato**. Nessun URL FeatureServer è stato verificato, per cui non ne cito. La pagina open-data di RSM conferma che ci sono "i confini e i varchi delle ZTL" e cita anche https://www.comune.roma.it/TERRITORIO/nic-gwt/.

**6. Elettrici** *(pagina aperta)*: con la Deliberazione della Giunta Capitolina n. 63 del 27 febbraio 2026, *"Dal 1° luglio 2026, anche i veicoli 100% elettrici e a idrogeno dovranno essere dotati di un permesso per accedere e circolare nelle ZTL di Roma Capitale"*, con la precisazione *"Non sarà più possibile accedere gratuitamente solo perché il veicolo è a basse emissioni"*. Per i non aventi diritto il costo è *"€ 1.000 con validità annuale"*, e la richiesta si fa con SPID o CIE, quindi è di fatto impraticabile per un turista straniero. Esenti: taxi, NCC, CUDE (con targa segnalata), car sharing, moto, ciclomotori e quadricicli (tranne Tridente A1).

**7. Punteggio 4.** Manca la geometria (scaricare l'hub ArcGIS da un'altra rete e verificare la licenza CC BY 3.0 IT sulla scheda di ogni layer) e va risolta l'incoerenza sulle notturne del mercoledì e giovedì.

---

### 3.4 Siena — punteggio 3

**Pagine/atti aperti**
- Accesso ZTL – Strutture ricettive: https://www.comune.siena.it/servizi/accesso-ztl-strutture-ricettive (aggiornata il 20/05/2026)
- Accesso ZTL – Persone fisiche: https://www.comune.siena.it/servizi/accesso-ztl-persone-fisiche (09/10/2026)
- Disciplinare (Deliberazione GC n. 327 del 02/09/2025): https://www.comune.siena.it/sites/default/files/2025-09/disciplinare_GC_327_2_9_2025.pdf
- Tariffe (Allegato B GC 327/2025): https://www.comune.siena.it/sites/default/files/2025-09/Tabella%20Tariffe_%20GC_327_2025.pdf
- Mappa ZTL con varchi (PDF): https://www.comune.siena.it/sites/default/files/2025-06/Mappa%20ZTL%20con%20Varchi.pdf · Zona A / Y storica: https://www.comune.siena.it/sites/default/files/2025-03/Planimetria%20Y%20storica%20ampliata%20%281%29.pdf

**1. Orari** *(disciplinare aperto)*
> "La ZTL: … ha validità tutti i giorni nell'orario 0/24 e l'ingresso, la circolazione e la sosta sono vietati ai veicoli non autorizzati"

> "La Zona Y storica è transitabile solo nella fascia oraria 6.00/10.00. La Zona A è transitabile solo nelle fasce orarie 6.00/10.00 e 15.30/17.00."

Il perimetro è definito dalla mappa allegata alla deliberazione GC n. 102 del 25/03/2025; la ZTL è divisa in 6 settori con ingresso e uscita distinti. Nessuna variante stagionale trovata (il Palio ha permessi propri, gratuiti).

**2. Festivi:** "tutti i giorni nell'orario 0/24", quindi nessuna eccezione.

**3. Prezzi** *(tariffe aperte)*: permessi temporanei "da 30 minuti a 3 giorni": "30 minuti: gratuito – max n. 4 al mese"; "1 ora: 5€"; "1 giorno: 10 €"; "2 giorni: 20 €"; "3 giorni: 20 €"; supplemento "Tariffa aggiuntiva di 30 € per: transito nella Zona Y storica". Attenzione: per le persone fisiche il permesso è rilasciato **solo per motivi specifici** (*"trasporto o ritiro di oggetti pesanti o voluminosi … accompagnamento di anziani ultrasettantenni … minori di anni sei … persone temporaneamente inabili … animali"*); non è un ticket turistico generico. La richiesta si fa online (https://portaleztl.comune.siena.it/?c=site&a=formnologin&modalita=persona) con evasione entro 2 ore negli orari di servizio (lun–ven 8:15–12:45 e 14:00–16:30, "escluso domenica e festivi").

**4. Hotel:** ci sono due testi ufficiali **non coerenti tra loro**:
- Pagina servizio: *"Il servizio permette alle strutture ricettive di registrare, per massimo 2 volte al giorno, le targhe dei clienti…"* e *"Attenzione: la comunicazione dei dati cliente deve essere inviata entro 2 giorni lavorativi successivi al transito."* Servizio gratuito: https://portaleztl.comune.siena.it/?c=login&a=base&tipologia=hotel
- Disciplinare: *"É consentito l'inserimento dati per un solo accesso al giorno per massimo 2 ore"*; *"La compilazione dei dati richiesti è obbligatoria e non è consentita oltre 3 giorni dalla data del transito."*; sosta *"per le sole operazioni di carico e scarico bagagli … per massimo 2 ore con obbligo di esposizione del foglio di prenotazione e disco orario"*; solo autovetture, solo strutture "gestite in forma imprenditoriale" con sede in ZTL, solo il percorso più breve.

→ Per l'app: "solo per carico e scarico bagagli; l'hotel deve registrarti (entro 2 giorni lavorativi / max 3 giorni)". Chiedere al Comune quale testo prevale (permessiztl@comune.siena.it, 0577 292531).

**5. Open data:** **nessuno**. Solo i PDF sopra: va digitalizzato il perimetro e i varchi dalla "Mappa ZTL con Varchi" (2025-06).

**6. Elettrici** *(disciplinare)*: *"I veicoli elettrici non sono autorizzati ad accedere alla Ztl per effettuare la sola ricarica."* Permessi temporanei da 4 giorni a 6 mesi: "15 € intero periodo per veicoli ad esclusiva trazione elettrica". Nessuna esenzione per i turisti.

**7. Punteggio 3.** Manca la geometria (digitalizzazione manuale) e va chiarita l'incoerenza nelle regole hotel.

---

### 3.5 Verona — punteggio 3

**Pagine aperte**
- Notizia ufficiale "La Zona a Traffico Limitato di Verona" (01/07/2025): https://www.comune.verona.it/Novita/Notizie/La-Zona-a-Traffico-Limitato-di-Verona (letta tramite il redirect da https://polizialocale.comune.verona.it/nqcontent.cfm?a_id=86233)
- Mappa e orari: https://polizialocale.comune.verona.it/nqcontent.cfm?a_id=30870 (aggiornata il 03/09/2025; lo stesso a_id su portale.comune.verona.it rispondeva 503)
- Transito: https://polizialocale.comune.verona.it/nqcontent.cfm?a_id=30871 (la pagina porta l'avviso "Questo è un archivio non più aggiornato")
- Accesso alla ZTL per turisti: https://polizialocale.comune.verona.it/nqcontent.cfm?a_id=26104
- Dataset: https://www.comune.verona.it/Amministrazione/Documenti-e-dati/Dataset/Mappa-della-ZTL-con-varchi

**1. Orari** *(notizia ufficiale)*
> "Per chi vive a Verona e provincia, gli orari d'accesso in ZTL, per l'autovettura sono solo su prenotazione (max 4 ingressi al mese) sono: dal lunedì al venerdì: - dalle 10 alle 18 (con uscita obbligatoria entro le ore 18) - dalle 20 alle 23 (con uscita obbligatoria entro le ore 24) sabato, domenica e festivi: - dalle 10 alle 13.30 (con uscita obbligatoria entro le ore 13.30)"

(Novità in vigore dal 28 ottobre 2024, Ordinanza n. 1486 del 21/10/2024; categorie autorizzate con Ordinanza n. 1545 del 31/10/2024. I PDF sono su archive.comune.verona.it, non raggiungibile: **[non riletti]**.)
Per un turista che non è della provincia, nessuna fascia di libero accesso è indicata. La pagina "Transito" (archivio) dice che l'accesso è libero "sempre (dalle 00 alle 24)" solo per le categorie elencate, tra cui *"clienti degli alberghi che si trovano nella ZTL (previa comunicazione della targa all'albergatore)"*. Per l'app: **turista senza hotel in ZTL → non entrare, a qualsiasi ora** (da confermare: **[ordinanza 1486/2024 non riletta]**).

**2. Festivi:** esplicito solo per la fascia di prenotazione dei residenti in provincia ("sabato, domenica e festivi").

**3. Prezzi:** nessun ticket per i turisti di fuori provincia **[non trovato]**. Sanzione citata nelle FAQ (archivio): "euro 98,50 … euro 73,60 se pagati entro 5 giorni" (https://polizialocale.comune.verona.it/nqcontent.cfm?a_id=30873).

**4. Hotel** *(pagina aperta)*
> "turisti possono entrare nella Zona a Traffico Limitato se alloggiano presso gli alberghi che si trovano nella suddetta zona. Sarà l'albergatore a comunicare anticipatamente alla Polizia Locale il numero di targa delle auto dei suoi ospiti, attraverso gli accrediti che gli sono stati forniti dall'U.O. Traffico e Mobilità del Comune."

La notizia ufficiale aggiunge "*non locazioni turistiche*". C'è anche un modulo "ZTL: Istanza per comunicazione di targhe errate (RISERVATO Albergatori)" (a_id=27281). Scadenza in ore: **"anticipatamente"**; nessun termine a posteriori trovato per gli hotel (le 72 ore valgono per le emergenze).

**5. Open data** *(pagina aperta; file in `data/raw/verona/`)*
- "Mappa della ZTL con varchi", licenza **"Creative Commons Attribution–NonCommercial 4.0 International (CC BY-NC 4.0)"** (il report precedente diceva CC0 per errore), ultimo aggiornamento 30/06/2025 (scheda 01/07/2025), frequenza "Costantemente aggiornato".
- Download CSV: https://www.comune.verona.it/customexport/dataset-csv_resource-10484. **11 righe** (varchi 1–11), colonne `Varco, numero, Indirizzo, "Latitudine e longitudine"`; le coordinate sono in un solo campo `"lat,lon"` (es. `"45.4428487,11.0008579"`).
- **Nessun perimetro**: va disegnato dalla descrizione ufficiale (*"Ansa interna dell'Adige compresa fra il Ponte Scaligero di Castelvecchio e Ponte Aleardi (Riva San Lorenzo inclusa), Via Ponte Aleardi, Via Pallone, Largo Divisione Pasubio, Via degli Alpini, Piazza Bra, Via Roma, Via Daniele Manin, Vicolo San Silvestro, Corso Castelvecchio"*).
- ⚠️ Con la licenza **NC**, l'uso in un'app commerciale va chiesto al Comune (Ufficio Comunicazione). In alternativa si possono digitalizzare i varchi dagli indirizzi pubblicati nel testo, che non sono il dataset.

**6. Elettrici:** nessuna esenzione per i turisti trovata.

**7. Punteggio 3.** Manca: rilettura delle ordinanze 1486/2024 e 1545/2024, chiarimento della licenza, perimetro.

---

### 3.6 Napoli — punteggio 3

**Pagine aperte** (indice: https://www.comune.napoli.it/articolo_tematico/trasporti-mobilita/ztl-e-aree-pedonali/, aggiornata il 10/03/2026)
- ZTL Centro Antico (23/04/2026): https://www.comune.napoli.it/articolo_tematico/trasporti-mobilita/ztl-e-aree-pedonali/ztl-del-centro-antico/
- ZTL Tarsia, Pignasecca, Dante (24/08/2026): https://www.comune.napoli.it/articolo_tematico/trasporti-mobilita/ztl-e-aree-pedonali/ztl-tarsia-pignasecca-dante/
- ZTL Belledonne, Martiri, Poerio (24/08/2026): https://www.comune.napoli.it/articolo_tematico/trasporti-mobilita/ztl-e-aree-pedonali/ztl-belledonne-martiri-poerio-e-contrassegni-per-laccesso/
- ZTL Morelli, Filangieri, Mille (10/03/2026): https://www.comune.napoli.it/articolo_tematico/trasporti-mobilita/ztl-e-aree-pedonali/ztl-morelli-filangieri-mille-e-contrassegni-per-laccesso/
- ZTL Chiaia (23/05/2025): https://www.comune.napoli.it/articolo_tematico/trasporti-mobilita/ztl-e-aree-pedonali/ztl-chiaia/
- ZTL via Ferdinando Russo (24/08/2026): https://www.comune.napoli.it/articolo_tematico/trasporti-mobilita/ztl-e-aree-pedonali/ztl-di-via-ferdinando-russo/
- ZTL Marechiaro (24/08/2026): https://www.comune.napoli.it/articolo_tematico/trasporti-mobilita/ztl-e-aree-pedonali/ztl-marechiaro/
- Deroghe e permessi temporanei: https://www.comune.napoli.it/articolo_tematico/trasporti-mobilita/ztl-e-aree-pedonali/deroghe-e-permessi-di-accesso-temporaneo-alle-ztl-cittadine/

**1. Orari** *(pagine aperte)*
> Centro Antico: "via del Sole (dopo l'ingresso dell'Ospedale) – Attivo dal lunedì al giovedì dalle ore 9:00 alle ore 22:00 e venerdì, sabato, domenica, festivi e prefestivi dalle ore 9:00 alle ore 24:00 e fino alle ore 2.00 del giorno successivo; – via Miroballo – Attivo tutti i giorni dalle ore 9:00 alle ore 17:00; – via Duomo (altezza piazza Museo Filangieri) – Attivo tutti i giorni dalle ore 9:00 alle ore 17:00; – via Santa Sofia (altezza via Oronzio Costa) – Attivo tutti i giorni dalle 9:00 alle ore 17:00."

Varco Mezzocannone: stessi orari di via del Sole. Piazza del Gesù (area pedonale): "attivo dalle ore 0:00 alle ore 24:00 di tutti i giorni dell'anno".
> Tarsia-Pignasecca-Dante: "La ZTL 'Tarsia-Pignasecca-Dante' è in vigore tutti i giorni, dalle ore 9:00 alle ore 18:00" (varco di Piazza Gesù e Maria; via Domenico Soriano è un'APU attiva tutto il giorno).

> Belledonne, Martiri, Poerio: "La ZTL è attiva dalle ore 19:00 alle ore 7:00 tutti i giorni della settimana."

> Morelli, Filangieri, Mille: "La ZTL è attiva ogni anno dall'8 dicembre al 6 gennaio tutti i sabati, domeniche, festivi e prefestivi dalle ore 10:00 alle ore 14:00 e dalle ore 16:00 alle ore 20:00."

> Chiaia: "divieto di transito veicolare nelle giornate di sabato, dalle ore 10:00 alle ore 13:30 e dalle ore 16:00 alle ore 22:00" (O.S. 1202/2008, pagina del 2025).

> Ferdinando Russo (dal 10/07/2026): "dal 1°aprile al 30 giugno, dalle ore 8:00 alle ore 19:00, nei soli giorni festivi e prefestivi; dal 1°luglio al 31 agosto, dalle ore 8:00 alle ore 19:00, tutti i giorni; dall'1 al 30 settembre, dalle ore 8:00 alle ore 19:00, nei soli giorni festivi e prefestivi."

Marechiaro: ZTL 2026 dal 16/05 al 27/09, articolata in moduli (Modulo A H24; B1 e C 8–19 con calendari diversi). **Chiusa in questo momento** (23/10).

**2. Festivi:** esplicito per via del Sole e Mezzocannone ("festivi e prefestivi"), Morelli e F. Russo; "tutti i giorni" per gli altri varchi. Serve un calendario dei **prefestivi**.

**3. Prezzi:** nessun ticket per i turisti; *"Possono essere richiesti permessi di accesso temporaneo … per comprovate e straordinarie necessità"* (traslochi, manutenzioni, visite cliniche, manifestazioni), via permessitemporanei.ztl@comune.napoli.it.

**4. Hotel:** Centro Antico e Morelli elencano "Albergatori/autorimesse/autofficine, per i veicoli dei clienti" tra le categorie con contrassegno, senza una procedura online descritta **[procedura non trovata]**. Per F. Russo e Marechiaro: *"è fatto obbligo ai titolari delle autofficine/autorimesse/alberghi di registrare direttamente nel sistema informatico Smartmobility"* (https://smartmobility.anm.it/ar/) **[scadenza non letta]**.

**5. Open data:** opendata.comune.napoli.it e trasparenza.comune.napoli.it sono **bloccati dal proxy**, quindi niente da scaricare. Le pagine riportano solo i nomi delle strade del perimetro e le ordinanze in PDF (static-www.comune.napoli.it).

**6. Elettrici:** nessuna esenzione trovata.

**7. Punteggio 3.** Manca la geometria. La logica è per varco e stagionale; servono i prefestivi.

---

### 3.7 Torino — punteggio 2 (non verificabile in questa sessione)

www.comune.torino.it e aperto.comune.torino.it hanno resettato la connessione a ogni tentativo (7 prove per dominio); gtt.to.it è bloccato. **Tutto quanto segue è [solo da estratto di ricerca].**
- Pagina: https://www.comune.torino.it/schede-informative/ztl-centrale. Estratto: *"dalle 7.30 alle 10.30 di tutti i giorni feriali (sabato escluso), sono vietate la circolazione e la sosta all'interno della ZTL Centrale."* L'Area Romana sarebbe attiva dalle 21:00 alle 7:30 tutti i giorni (estratto da fonte non ufficiale: **non usare** finché non è verificato).
- Hotel (GTT): https://www.gtt.to.it/cms/ztl/3681-utenti-che-pernottano-in-strutture-alberghiere. Estratto: solo strutture "accreditate e regolarmente registrate in Piattaforma ZTL"; esenzione a posteriori con *"giorni utili … tassativamente 10 (dieci), contando dal primo giorno di transito"* (https://gtt.to.it/cms/ztl/3702-categorie-e-attivita-che-hanno-diritto-all-esenzione-a-posteriori).
- Elettrici: https://www.comune.torino.it/schede-informative/permessi-circolazione-ztl-per-veicoli-elettrici-puri. Estratto: permesso gratuito "Blu A" fino al 31/12/2026, con 16 € di bollo; per transiti occasionali, esenzione a posteriori fino a 12 all'anno.
- Open data: https://aperto.comune.torino.it/dataset/perimetro-varchi-e-orari-ztl (5T S.r.l., XML, ultimo aggiornamento maggio 2021; licenza "Creative Commons Attribution" sulla scheda, "IODL v2.0" su muoversiatorino.it: **discordanti**). **Non scaricato.**

---

### 3.8 Città brevi (tutte [solo da estratto di ricerca]: domini bloccati dal proxy)

**Pisa (2).** Registrazione targhe per le strutture ricettive: https://www.comune.pisa.it/Servizi/Registrazione-Targhe-per-accesso-veicoli-in-ZTL (*"Solo alle strutture ricettive professionali: Alberghi, B&B e similari"*; la scadenza generale non risulta). Per le strutture che ospitano eventi, Pisamo indica *"entro 4 ore dall'ingresso del veicolo in Z.T.L."* (https://mobilita.pisamo.it/permesso-ztl-partecipanti-ad-eventi-ospitati-in-strutture-ricettive/, pagina datata). **Orari del centro storico non trovati.** ZTL Stadio (Porta a Lucca): attiva solo nelle partite casalinghe, *"due ore prima del fischio d'inizio … fino al termine del primo tempo"*. Open data: nessuno.

**Lucca (2).** Ordinanza Comics 2025 (https://www.comune.lucca.it/app/uploads/2025/10/ord_02702_20-10-2025-Disciplinare-Centro-Storico-ZTL-COMICS-2025.pdf): l'estratto riporta un divieto 8–19 per i non autorizzati e 9–19 per la ZTL A, **ma vale per l'evento**; l'orario ordinario non è confermato. Hotel: regola "permessi giornalieri ≤ numero di camere" (estratto non datato). Varchi in uscita nuovi: https://www.comune.lucca.it/notizia/ztl-controlli-piu-stringenti-con-nuove-telecamere-e-varchi-in-uscita/. Open data: nessuno.

**Bergamo (2).** Città Alta e Colli: *"dal 21 giugno, domenica e festivi, entra in vigore la ZTL dalle ore 10 alle ore 24"* (https://www.comune.bergamo.it/notizie/citt%C3%A0-alta-e-colli:-dal-21-giugno-domenica-e-festivi-entra-in-vigore-la-ztl-dalle-ore-10-alle-ore-24). Orari feriali discordanti tra pagine ATB (https://www.atb.bergamo.it/ztl/ztl-di-bergamo). Varchi in uscita dal 12/12/2025. Hotel: **[non trovato]**.

**Genova (2).** Disciplinare rev. 16/04/2025 (https://www.comune.genova.it/sites/default/files/2025-06/Disciplinare%20ZTL%20aggiornato%20da%20DGC%2074-2025.pdf). Estratto: il Centro Storico *"ha validità in tutti i giorni dell'anno e nell'intero arco delle 24 ore"*. Clienti delle strutture ricettive per carico e scarico bagagli *"tutti i giorni in orario 00.00 – 24.00"*, con richiesta del titolare entro 48 h; "autorizzazione giornaliera, per un corrispettivo di Euro 11,00" (non chiaro se valga per i turisti). Perimetri SHP CC BY 4.0 del 2018 (dati.comune.genova.it, bloccato).

**Perugia (2).** https://www.comune.perugia.it/luogo/ztl-zone-a-traffico-limitato/ (estratto: via del Roscetto accessibile 16–20; corso Garibaldi lun–ven 13–24, sabato e festivi dalle 7). Permessi giornalieri online, fino a 15 giorni, costo calcolato in procedura: https://www.comune.perugia.it/servizio/permessi-ztl-richiesta-autorizzazione-accesso-giornaliero-o-temporaneo/. Hotel: *"Il contrassegno per la sosta viene fornito dall'albergo: da rinnovarsi ogni giorno"* (https://turismo.comune.perugia.it/pagine/varchi-ztl, pagina di circa 5 anni fa).

**Palermo (2).** Cambio stagionale: https://www.comune.palermo.it/novita/ztl-dall1-novembre-in-vigore-orario-invernale/ (l'orario invernale 2026/27 non è confermato). Pass giornaliero: https://www.comune.palermo.it/servizio/consumo-pass-giornaliero-elettronico/. Estratto: *"5 euro per vetture a benzina (da Euro 3 a Euro 6) e diesel (da Euro 4 a Euro 6)"*, 2,50 € per le ibride, gratis per le elettriche. Acquisto su https://ztl.comune.palermo.it e via app (PalerMobilita, MyAMAT, Telepass Pay). Open data: nessuno.

---

## 4. Cosa scaricare / convertire

**Già scaricati (in `data/raw/`, solo file dati):**
1. `bologna/zona-a-traffico-limitato.geojson`: 14 poligoni, la ZTL principale è `codice=40`. Licenza CC BY 4.0. Attribuzione: "Comune di Bologna – opendata.comune.bologna.it".
2. `bologna/varchi-bologna.geojson`: 79 punti; filtrare `tipologia_varco ∈ {ZTL, ZTLS, ZTL speciale, APU}` e scartare `corsie` e `DT`. CC BY 4.0.
3. `bologna/zona-t-centro-storico.geojson` (1 poligono) e `bologna/zona-pedonale-centro-storico.geojson` (62 multipoligoni, CC BY 4.0): zone 24/24 escluse dal ticket.
4. `milano/aree_pedonali_ztl.geojson`: DS51, 217 multipoligoni; estrarre `tipo=AREA_C` e `tipo=AREA_B` per i perimetri, più le 23 `tipo=ZTL` (orari da documentare). CC BY.
5. `milano/areac_varchi.geojson` (+ `.csv`): 42 varchi Area C, CC BY, aggiornato il 14/10/2026.
6. `milano/areab_varchi.geojson`: 188 varchi Area B; tenere `stato` per distinguere quelli sanzionanti da quelli in pre-esercizio.
7. `verona/mappa-ztl-varchi.csv`: 11 varchi; separare il campo `"Latitudine e longitudine"` su `,`. **Licenza CC BY-NC 4.0: chiedere l'autorizzazione prima dell'uso commerciale.**

**Da scaricare da un'altra rete (bloccati qui):**
8. **Roma**: layer confini e varchi delle ZTL dall'hub https://data-rsm.opendata.arcgis.com (GeoServices REST, CC BY 3.0 IT dichiarata). Esportare in GeoJSON con `?where=1=1&outFields=*&f=geojson` sui FeatureServer, dopo averne trovato gli URL nell'hub.
9. **Torino**: https://aperto.comune.torino.it/dataset/perimetro-varchi-e-orari-ztl (XML, 2021) e il dataset "Zone Traffico Limitato" (CSV/SHP) citato negli estratti; chiarire se la licenza è CC BY o IODL 2.0.
10. **Genova**: SHP dei perimetri ZTL (Gauss-Boaga, va riproiettato in EPSG:4326), CC BY 4.0, file del 2018.
11. **Napoli**: verificare su opendata.comune.napoli.it il dataset "ZTL e aree pedonali".

**Da digitalizzare a mano (solo PDF o testo):**
12. **Siena**: perimetro, 6 settori e varchi da "Mappa ZTL con Varchi" (2025-06) e dalla planimetria Zona A / Y storica (2025-03).
13. **Verona**: perimetro dalla descrizione delle strade nella notizia ufficiale del 01/07/2025.
14. **Napoli**: perimetri dagli elenchi di strade sulle pagine ZTL e dalle mappe PDF delle ordinanze.

**Regole da codificare nel modello dati (nuove rispetto a Firenze):**
- Festivo per ZTL: `excluded` (Roma Centro e Tridente, Milano), `included` (Roma notturne Trastevere e San Lorenzo, Napoli via del Sole), `every_day` (Bologna, Siena 0/24).
- Stagionalità: sospensione di agosto (Roma notturne e Appia Antica), mercoledì e giovedì da maggio a ottobre (Roma notturne Trastevere e San Lorenzo), finestre a date fisse (Napoli Morelli 8/12–6/1, F. Russo, Marechiaro).
- Prefestivi (Napoli): serve un calendario.
- ZTL a pagamento con finestra di pagamento a posteriori (Milano: entro la mezzanotte del giorno dopo, poi 22,50 € fino al 7° giorno) e ticket da attivare **prima** (Bologna).
- Hotel: "entro la giornata stessa" (Roma), "in anticipo" (Verona), "anche all'arrivo" (Bologna), "entro 2 giorni lavorativi / 3 giorni" (Siena), "solo carico e scarico" (Siena).
- Elettrici: Roma (permesso obbligatorio dal 1/7/2026, 1.000 €/anno per i non aventi diritto), Bologna (contrassegno gratuito anche per i non residenti, da chiedere prima), Siena (nessuna esenzione).
