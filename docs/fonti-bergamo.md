# Bergamo: fonti della scheda ZTL

Scheda generata da `Tools/build_bergamo.py` → `Resources/Cities/bergamo.json` (stato **draft**, `reviewedByHuman: false`), nell'app tramite `manifest.json` dal 25/10/2026.
Fonti lette il **25/10/2026** e salvate in `data/raw/bergamo/` (testo estratto, con URL e data in testa a ogni file). Lo script si ferma se una frase citata o riassunta non c'è più parola per parola nel testo salvato.

Le pagine del Comune (www.comune.bergamo.it) si sono scaricate direttamente, a volte dopo più tentativi. Le pagine di **ATB Mobilità** (la società in house del Comune che rilascia i permessi e gestisce i varchi), i dati aperti su **dati.lombardia.it**, la stampa locale e VisitBergamo non erano raggiungibili da qui: sono stati scaricati con il workflow «Scarica pagine» (ramo `pagine-bergamo` e `pagine-bergamo2`, 25/10/2026). Le pagine dei servizi online del Comune per gli albergatori richiedono SPID e non sono leggibili.

## Zone nell'app (17 perimetri, tutte `restricted`, nessun ticket per turisti)

| Zona (id) | Orario usato | Fonte ufficiale (letta il 25/10/2026) | File |
|---|---|---|---|
| Città Alta · Centro storico (`bergamo-citta-alta`) | tutti i giorni 0–24 | «centro storico tra largo Colle Aperto, viale delle Mura, via San Lorenzo e via Fara tutti i giorni 00:00 24:00» — https://www.comune.bergamo.it/node/25672/ | `ztl-centro-storico-citta-alta.txt` |
| Città Alta e Colli (`bergamo-colli`, più il pezzo staccato `bergamo-colli-2` sul viale Vittorio Emanuele) | domenica 10–24; giovedì, venerdì, sabato 21–01 con l'ora legale (stagione 29/3–30/10) | «tutti i giorni festivi dell'anno 10:00 24:00 … giovedì, venerdì e sabato* 21:00 01:00 *dal giovedì successivo all'entrata in vigore dell'ora legale, al sabato precedente l'entrata in vigore dell'ora solare» — https://www.comune.bergamo.it/node/741058/ ; comunicati del 10/06 e 19/06/2026 (10–24 dal 21/06/2026, eliminate le fasce libere 12–14 e 19–24); FAQ ATB https://www.atb.bergamo.it/public/atb/ZTL/faq_ztlcolli.pdf | `ztl-citta-alta-colli.txt`, `comune-notizia-*-festivi.txt`, `atb-faq-ztl-colli.txt` |
| Valverde (`bergamo-valverde`) | lun–ven 0–7, 9:30–15:45, 19:30–24; sabato e domenica 0–24 | https://www.comune.bergamo.it/node/25671/ ; uscite libere confermate dal comunicato del 02/12/2025 | `ztl-valverde.txt` |
| Via XX Settembre · Sant'Alessandro, piazza Pontida | 0–24 | https://www.comune.bergamo.it/node/25691/ | `ztl-xx-settembre-pontida.txt` |
| Via Tasso · via Pignolo | 0–24 | https://www.comune.bergamo.it/node/25695/ | `ztl-tasso-pignolo.txt` |
| Teatro Donizetti · largo Gavazzeni, piazza Matteotti | 0–24 | https://www.comune.bergamo.it/page:c_a794:zona.traffico.limitata;quali.sono.ztl;largo.gavazzeni.piazza.matteotti.teatro.donizzetti.largo.belotti | `ztl-gavazzeni-donizetti.txt` |
| Piazza Matteotti · via Borfuro, via Crispi | 0–24 | https://www.comune.bergamo.it/node/25706/ | `ztl-matteotti-borfuro.txt` |
| Via Pelabrocco | 0–24 | https://www.comune.bergamo.it/node/728994/ | `ztl-pelabrocco.txt` |
| Piazza Dante (area pedonale) | 0–24 | https://www.comune.bergamo.it/node/25709/ | `ztl-piazza-dante.txt` |
| Piazzale Marconi (corsie taxi/bus della stazione) | 0–24 | https://www.comune.bergamo.it/page:c_a794:zona.traffico.limitata;quali.sono.ztl;piazzale.marconi | `ztl-piazzale-marconi.txt` |
| Via Pignolo Alta · San Tomaso | 23–07 | https://www.comune.bergamo.it/node/25689/ | `ztl-pignolo-alta.txt` |
| Borgo San Leonardo · via San Bernardino | 23–07 | https://www.comune.bergamo.it/node/25692/ | `ztl-san-bernardino.txt` |
| Via Borgo Palazzo (senza telecamere) | 23–07 | https://www.comune.bergamo.it/node/741072/ | `ztl-borgo-palazzo.txt` |
| Via San Francesco d'Assisi (senza telecamere) | 22–07 | https://www.comune.bergamo.it/node/25694/ | `ztl-san-francesco.txt` |
| Via Raboni (senza telecamere) | 17:30–19:30 | https://www.comune.bergamo.it/page:c_a794:zona.traffico.limitata;quali.sono.ztl;raboni | `ztl-raboni.txt` |
| Via Orio (senza telecamere) | lun–ven 0–7 e 9:30–24; sabato e domenica 0–24 | https://www.comune.bergamo.it/node/25704/ | `ztl-orio.txt` |

Elenco completo e colonne (permanente / periodo scolastico / periodica / videosorvegliata): https://www.comune.bergamo.it/page:c_a794:zona.traffico.limitata;quali.sono.ztl → `comune-quali-sono-ztl-tabella.txt`.

### Zone studiate ma non nell'app

- **ZTL scolastiche** (via Cappuccini, via Don Bepo Vavassori, via Pradello, via Cadorna, via Fornoni — Zona Scolastica Urbana sperimentale dal 14/09 al 31/12/2026, ord. 328 del 14/07/2026 —, via Sylva/Bixio/Venanzio/Arcangeli, via Vacha, via Edison e via Righi): pochi minuti all'entrata e all'uscita da scuola, «nel periodo scolastico»; l'app non conosce il calendario scolastico e non ci sono telecamere. Orari nei file `ztl-*.txt`.
- **Stadio** (Gewiss Stadium / New Balance Arena) e **quartiere Finardi**: solo nei giorni delle partite (da 2–3 ore prima del calcio d'inizio). Non modellabili.
- **Limitazioni antismog della Regione Lombardia** (valgono in tutta la città, anche per le auto straniere): Euro 0 e 1 di ogni alimentazione, diesel Euro 2, 3 e 4, «Lunedì–venerdì, esclusi i festivi infrasettimanali, 7:30–19:30»; il blocco dei diesel Euro 5 è rinviato al 1° ottobre 2027 (D.G.R. XII/6846 del 28/09/2026). Fonte: https://www.comune.bergamo.it/node/299394 e https://www.comune.bergamo.it/notizie/veicoli-diesel-euro-5:-rinviato-al-1%C2%B0-ottobre-2027-il-blocco-della-circolazione (`comune-bergamorespira.txt`, `comune-notizia-euro5-rinvio.txt`). Non è nell'app: servirebbe il perimetro delle «aree urbane» (in `Tools/fetch_geo.py` è stato aggiunto il confine comunale da OSM, `bergamo-confine`) e le classi Euro andrebbero inserite come `bans`.

## Regole comuni → fonte

| Fatto | Fonte | File | Stato |
|---|---|---|---|
| Hotel dentro una ZTL: contrassegni di transito pari al numero di camere, procedura online dopo l'accreditamento, validità massima 30 giorni, «La registrazione dei dati dei veicoli utilizzati dagli opsiti deve essere effettuata entro un termine massimo di 72 ore dal momento dell’effettivo accesso del mezzo nella ZTL» | Documento operativo, Punto 17, allegato alla delibera GC n. 798 del 30/12/2024, approvato con ord. n. 3 del 03/01/2025: https://www.comune.bergamo.it/uri-res/N2Ls?urn:nir:comune.bergamo:protocollo:2025-01-16;0021613 | `documento_operativo_GC_798_2024.pdf/.txt`, `ord_3_2025-01-03.txt` | ufficiale → `hotelCanRegister: true` in tutte le zone |
| Tariffa per attività ricettive/ristoranti: 1,00 € al giorno per targa (transito), 5,00 € con sosta (solo alberghi) | Documento operativo, tabella tariffe | idem | ufficiale |
| Moto e ciclomotori ammessi solo nella ZTL festiva e serale di Città Alta e Colli | Documento operativo, Punto 13 j; ATB https://www.atb.bergamo.it/ztl/ztl-di-bergamo | `atb-ztl-di-bergamo.txt` | ufficiale (nell'app solo come testo) |
| Auto totalmente elettriche e veicoli al servizio di disabili: niente permesso, ma la targa va comunicata (entro 120 ore, accessi.ztl@atb.bergamo.it; per le elettriche «accredito ZTL - 1 anno») | https://www.comune.bergamo.it/action:c_a794:zona.traffico.limitato , https://www.comune.bergamo.it/action:c_a794:zona.traffico.limitato;comunicare;targhe , https://www.atb.bergamo.it/ztl/permessi-temporanei | `comune-servizio-circolare-ztl.txt`, `comune-servizio-comunicare-targhe.txt`, `atb-permessi-temporanei.txt` | ufficiale → `exemptFuels: []` (senza registrazione si prende la multa) |
| Nessun ticket o permesso giornaliero per turisti: i permessi temporanei sono solo per categorie precise (disabili, taxi/NCC, installatori, traslochi, cerimonie, …) | https://www.atb.bergamo.it/ztl/permessi-temporanei ; https://www.comune.bergamo.it/action:c_a794:zona.traffico.limitato;rilascio.permesso | `atb-permessi-temporanei.txt`, `comune-servizio-permesso-ztl.txt` | ufficiale → niente `ticket` |
| Ospiti dei residenti dei Colli: accredito gratuito via mail a residentiospiti@atb.bergamo.it solo per le fasce 12–14 e 19–24 di domeniche e festivi, entro 72 ore, solo da certi varchi | FAQ ATB | `atb-faq-ztl-colli.txt` | ufficiale (solo per chi è ospite di un residente) |
| A ZTL Colli attiva chi non ha il permesso può raggiungere «solo i tre parcheggi pubblici (via Tre Armi, Porta Sant’Alessandro e via Fara), transitando unicamente dal varco di viale Vittorio Emanuele» | Comunicato ATB del 31/08/2024: https://atb.bergamo.it/news/permessi-di-transito-in-citta-alta | `atb-news-2024-08-31-permessi-citta-alta.txt` | ufficiale ma del 2024; obbligo di parcheggiare entro 30 minuti confermato solo da VisitBergamo (infografica del 18/06/2026) |
| Telecamere in uscita da Centro storico, Tasso/Pignolo e Valverde dal 12/12/2025, multe dal 12/01/2026 | https://www.comune.bergamo.it/notizie/dal-12-dicembre-2025-attivate-le-telecamere-in-uscita-dalle-ztl-di-citt%C3%A0-alta-valverde-e-tassopignolo ; https://www.atb.bergamo.it/avvisi/ztl-attivazione-varchi-in-uscita-dal-12-dicembre-2025 | `comune-notizia-varchi-uscita-2025-12.txt`, `atb-avviso-varchi-uscita-2025-12.txt` | ufficiale |
| Consegne merci in Centro storico: lun–ven 7–7:45 e 9–11 dal 03/08/2026 | Ord. n. 344 del 29/07/2026 | `ord_344_2026-07-29.txt` | ufficiale (non riguarda i turisti) |
| Lavoratori serali di Città Alta: nuove regole per la sosta (comunicato del 13/07/2026: dal 1° settembre; Bergamonews: dal 19 ottobre) | https://www.comune.bergamo.it/notizie/ztl-citt%C3%A0-alta-dal-1%C2%B0-settembre-nuove-regole-per-la-sosta-dei-lavoratori-serali | `comune-notizia-lavoratori-serali.txt`, `nonufficiale-bergamonews-2026-10-12-lavoratori-serali.txt` | non riguarda i turisti |

Multe: le pagine non indicano l'importo; si applica l'art. 7 del Codice della Strada (non riportato nella scheda).

**Festivi e patrono.** Le ZTL di Bergamo non sono mai «libere nei festivi»: Città Alta e Colli e Valverde, al contrario, nei festivi si **chiudono** (10–24 e 0–24). Tutte le zone hanno quindi `freeOnHolidays: false` e la città non ha `localHolidays` (Sant'Alessandro, 26 agosto, conterebbe solo per regole che escludono i festivi). Limite dell'app: un festivo infrasettimanale (per esempio 8 dicembre, 15 agosto, e forse il 26 agosto) non accende le finestre della domenica, quindi GateLR direbbe «libero» dove la zona è chiusa; è scritto nel riassunto e nei punti in sospeso di Colli e Valverde. Servirebbe nel modello una finestra «solo festivi».

**Ora legale.** La stagione delle sere di giovedì–sabato cambia ogni anno; l'app ha date fisse, quindi è usato il periodo più largo possibile (29 marzo–30 ottobre).

## Geometria: provenienza e licenza

- **Ufficiale.** Dataset «Comune Bergamo - Zone a Traffico Limitato (ZTL)» su dati.lombardia.it (id `tkwz-spd9`, 27 poligoni con `nome_ztl`, `periodo`, `dettagli`; ultimo aggiornamento delle righe 04/10/2024; licenza dichiarata **IODL 2.0**, mentre la pagina del Comune https://www.comune.bergamo.it/node/748000 dice «Pubblico dominio»). Elencato anche su dati.gov.it. File: `data/raw/bergamo/opendata-tkwz-spd9-zone-traffico-limitato.geojson` e `opendata-tkwz-spd9-meta.json`. L'altro dataset («Mappa…», `jhcz-yki3`) è una mappa che esporta un GeoJSON vuoto.
- Ogni zona prende i poligoni il cui `nome_ztl` contiene la parola indicata nello script; nessun disegno a mano, solo semplificazione a 2 m. «CITTA' ALTA COLLI» ha due poligoni: il grande (3,99 km²) e un pezzo vicino alla rotonda Conca d'Oro (0,03 km²), che diventa la zona `bergamo-colli-2` con le stesse regole. Lo script si ferma se resta fuori una zona permanente, notturna, annuale o pedonale del dataset.
- Controlli nello script: piazza Vecchia dentro il Centro storico, via XX Settembre dentro la sua ZTL, San Vigilio dentro i Colli, la stazione fuori da tutte (tranne piazzale Marconi). Controllato a parte: piazza Vecchia non è nei Colli; porta San Lorenzo e la rotonda di Valverde sono nella ZTL Valverde.
- **Da verificare:** il dataset è del 2024, ma le delibere GC 398 del 10/07/2025 e 560 del 10/10/2025 hanno ridefinito i confini del Centro storico e dei Colli e istituito la ZTL Valverde (citate nell'ord. 344/2026). Nel dataset la riga «VALVERDE» ha ancora il testo degli orari dei Colli, mentre il poligono corrisponde alla zona di porta San Lorenzo–via Maironi da Ponte.
- **Varchi**: il Comune pubblica solo i nomi (ingressi del Centro storico: piazza Cittadella, via Arena, via San Giacomo, via San Lorenzo, via Osmano, prato della Fara, via Boccola/porta San Lorenzo; Colli: 11 varchi elencati nella pagina; uscite: varchi 40–49 del comunicato del 02/12/2025). Non ci sono coordinate né nei dati aperti né in OSM (`data/raw/geo/bergamo-gates.json` non ha varchi ZTL): `gates` è vuoto.
- OpenStreetMap (`bergamo-ztl.json`, `bergamo-walls.json`, `bergamo-gates.json`, 25/10/2026) non ha aree ZTL per Bergamo: non è usato.

## Fonti non ufficiali usate solo per incrociare i dati

Elenco con URL in `data/raw/bergamo/nonufficiale-ricerche-web.txt`; testi salvati: `nonufficiale-visitbergamo-infografica-ztl-2026-06.txt` (VisitBergamo, 18/06/2026: orari 10–24 dei festivi, accesso ai parcheggi da viale Vittorio Emanuele entro 30 minuti, Valverde chiusa sabato e festivi, moto ammesse anche a Valverde — quest'ultimo punto è in contrasto con ATB), `nonufficiale-bergamonews-*.txt`, `nonufficiale-primabergamo-elettrico-disabili.txt` (ottobre 2026: auto elettrica con contrassegno disabili multata in via San Bernardino perché la targa non era comunicata), `nonufficiale-autovia-guida.txt` (guida che riporta ancora i vecchi orari festivi 10–12 e 14–19: superata).

## Punti in sospeso

- Confini del 2024 da confrontare con le delibere 398 e 560/2025 e con la mappa del Comune (territorio.comune.bergamo.it, mappa «ZoneTL», non raggiungibile da qui).
- Festivi infrasettimanali non modellabili (Colli, Valverde).
- Accesso ai parcheggi di Città Alta con la ZTL Colli attiva: regola del 2024 di ATB, i 30 minuti solo da VisitBergamo.
- Pagine dei servizi online per albergatori (SPID): procedura e scadenza prese dal documento operativo e dagli estratti ATB.
- Varco allo studio da porta San Lorenzo (L'Eco di Bergamo, marzo 2026): nessuna conferma.
