# Napoli: fonti dei dati (bozza)

Stato: **draft** (`reviewedByHuman: false`). Fonti lette il **25/10/2026**.
File generato: `Resources/Cities/napoli.json` (o `data/drafts/napoli.json` se manca un perimetro), con lo script `Tools/build_napoli.py`.
Lo script legge i testi salvati in `data/raw/napoli/*.txt` (testo estratto dalle pagine HTML del Comune, con URL e data di lettura in testa) e si ferma se una frase citata non c'è più parola per parola.

Tutte le regole vengono dalle pagine ufficiali del **Comune di Napoli** («ZTL e Aree Pedonali», https://www.comune.napoli.it/articolo_tematico/trasporti-mobilita/ztl-e-aree-pedonali/). I permessi sono gestiti dallo Sportello Unico Permessi presso **ANM** (via Giambattista Marino 1) e dalla piattaforma online Smartmobility (https://smartmobility.anm.it/ar/).

## 0. Cosa non si è potuto leggere

- **I PDF del Comune** (ordinanze, delibere, disciplinare, mappe) stanno su `static-www.comune.napoli.it`: da questa rete il proxy rifiuta la connessione (403) e WebFetch non risolve il nome. Non sono stati letti né salvati. I loro URL sono comunque nei link e nel campo `ordinanceURL`.
- **anm.it**, **smartmobility.anm.it**, **dati.comune.napoli.it** (open data) e i siti non ufficiali (giornali, guide): bloccati allo stesso modo. Le fonti non ufficiali sono state viste solo attraverso i risultati di WebSearch (riassunti, non salvati), quindi servono solo come riscontro.
- Su **dati.gov.it** (CKAN, raggiungibile) il Comune di Napoli non ha dataset su ZTL o varchi (ricerche «napoli ztl», «zona traffico limitato napoli», «varchi napoli», 25/10/2026).

## 1. Fatti e fonti

| Fatto | Fonte (letta il 25/10/2026) | File salvato | Tipo / stato |
|---|---|---|---|
| Elenco: 9 ZTL (Tarsia-Pignasecca-Dante, Centro Antico, Belledonne-Martiri-Poerio, Morelli-Filangieri-Mille, Chiaia, via Ferdinando Russo, Marechiaro, via Padre Gaetano Errico, Bus Turistici), 9 aree pedonali, divieto del Vomero; dal 24/04/2026 i permessi si chiedono online su Smartmobility | https://www.comune.napoli.it/articolo_tematico/trasporti-mobilita/ztl-e-aree-pedonali/ (agg. 10/03/2026) | `indice.txt` | ufficiale |
| Centro Antico, varchi e orari: «via del Sole (dopo l’ingresso dell’Ospedale) – Attivo dal lunedì al giovedì dalle ore 9:00 alle ore 22:00 e venerdì, sabato, domenica, festivi e prefestivi dalle ore 9:00 alle ore 24:00 e fino alle ore 2:00 del giorno successivo; – via Miroballo – Attivo tutti i giorni dalle ore 9:00 alle ore 17:00; – via Duomo … – via Santa Sofia … dalle ore 9:00 alle ore 17:00» | https://www.comune.napoli.it/articolo_tematico/trasporti-mobilita/ztl-e-aree-pedonali/ztl-del-centro-antico/centro-antico/ (agg. 10/03/2026) | `ztl-del-centro-antico_centro-antico.txt` | ufficiale |
| Centro Antico: moto e ciclomotori ammessi; tra gli autorizzati «autoveicoli dei clienti degli alberghi» (contrassegno, O.S. 1609/2011) | come sopra | come sopra | ufficiale |
| Perimetro unico «Centro Antico», «Mezzocannone» e «Piazza del Gesù» (elenco di strade); mappa PDF `ZTL_nuovi_colori.pdf` | https://www.comune.napoli.it/articolo_tematico/trasporti-mobilita/ztl-e-aree-pedonali/ztl-del-centro-antico/ (agg. 23/04/2026) | `ztl-del-centro-antico.txt` | ufficiale (mappa non scaricata) |
| Mezzocannone: «dal lunedì al giovedì dalle ore 9:00 alle ore 22:00 e venerdì, sabato, domenica, festivi e prefestivi dalle ore 9: 00 alle ore 24:00 e fino alle ore 2:00 del giorno successivo»; moto e ciclomotori **non** ammessi; clienti degli alberghi ammessi | https://www.comune.napoli.it/articolo_tematico/trasporti-mobilita/ztl-e-aree-pedonali/ztl-del-centro-antico/mezzocannone/ (agg. 10/03/2026) | `ztl-del-centro-antico_mezzocannone.txt` | ufficiale |
| Tarsia-Pignasecca-Dante: «in vigore tutti i giorni, dalle ore 9:00 alle ore 18:00»; varchi piazza Gesù e Maria e via Domenico Soriano (APU, tutto il giorno); varco interno via Brombeis (area pedonale); moto ammesse tranne via Brombeis | https://www.comune.napoli.it/articolo_tematico/trasporti-mobilita/ztl-e-aree-pedonali/ztl-tarsia-pignasecca-dante/ (agg. 24/08/2026) | `ztl-tarsia-pignasecca-dante.txt` | ufficiale |
| Belledonne-Martiri-Poerio: «attiva dalle ore 19:00 alle ore 7:00 tutti i giorni della settimana»; elenco strade | https://www.comune.napoli.it/articolo_tematico/trasporti-mobilita/ztl-e-aree-pedonali/ztl-belledonne-martiri-poerio-e-contrassegni-per-laccesso/ (agg. 24/08/2026) | `ztl-belledonne-…txt` | ufficiale; Sixt (via WebSearch) dice 24 ore su 24, Parclick/Fleet Magazine dicono 19–7 e varchi in vico Belledonne e via Cavallerizza (non ufficiali) |
| Morelli-Filangieri-Mille: «attiva ogni anno dall’8 dicembre al 6 gennaio tutti i sabati, domeniche, festivi e prefestivi dalle ore 10:00 alle ore 14:00 e dalle ore 16:00 alle ore 20:00»; clienti degli alberghi ammessi; moto ammesse; permessi temporanei a ztlmorelli@anm.it, 4 giorni lavorativi | https://www.comune.napoli.it/articolo_tematico/trasporti-mobilita/ztl-e-aree-pedonali/ztl-morelli-filangieri-mille-e-contrassegni-per-laccesso/ (agg. 10/03/2026) | `ztl-morelli-…txt` | ufficiale |
| Via Ferdinando Russo (Posillipo), dal 10/07/2026: 1/4–30/6 e 1–30/9 ore 8–19 «nei soli giorni festivi e prefestivi»; 1/7–31/8 ore 8–19 tutti i giorni; alberghi/autorimesse registrano le targhe su Smartmobility (O.D. 716/2026 pre-esercizio, O.D. 1219/2026 esercizio; Delibere G.C. 668/2014 e 280/2026) | https://www.comune.napoli.it/articolo_tematico/trasporti-mobilita/ztl-e-aree-pedonali/ztl-di-via-ferdinando-russo/ (agg. 24/08/2026) | `ztl-di-via-ferdinando-russo.txt` | ufficiale; confermato da expartibus.it e napolitoday.it (via WebSearch) |
| Marechiaro: solo per il 2026, dal 16/05 al 27/09/2026 (modulo A H24; moduli B1/C/B2 8–19 in festivi e prefestivi o tutti i giorni dal 29/06 al 13/09) — O.D. Municipalità 1 n. 21 (725) del 30/04/2026 | https://www.comune.napoli.it/articolo_tematico/trasporti-mobilita/ztl-e-aree-pedonali/ztl-marechiaro/ (agg. 24/08/2026) | `ztl-marechiaro.txt` | ufficiale, **scaduta**: non inserita |
| Chiaia: divieto di transito il sabato 10–13:30 e 16–22 in via dei Mille, via Filangieri, via S. Caterina a Chiaia, piazza dei Martiri, via Morelli, via S. Maria a Cappella Vecchia, rampa Caprioli (O.S. 2061/2005, 1202/2008) | https://www.comune.napoli.it/articolo_tematico/trasporti-mobilita/ztl-e-aree-pedonali/ztl-chiaia/ (agg. 23/05/2025) | `ztl-chiaia.txt` | ufficiale ma senza varchi citati; **non inserita** (vedi 3) |
| Via Padre Gaetano Errico: «Attiva nei giorni feriali e festivi, dalle ore 9:00 alle ore 20:00» (O.S. 226) | https://www.comune.napoli.it/articolo_tematico/trasporti-mobilita/ztl-e-aree-pedonali/ztl-in-via-padre-gaetano-errico/ | `ztl-in-via-padre-gaetano-errico.txt` | ufficiale; **non inserita** (strada singola, nessuna geometria) |
| Vomero: divieto lun–sab 16–20 in via Pitloo, Stanzione, Alvino, Merliani, Solimena, Carelli, De Mura, Luca Giordano, Cifariello; ammessi residenti, elettriche, «EURO 4», GPL e metano (O.S. 469/2010) | https://www.comune.napoli.it/articolo_tematico/trasporti-mobilita/ztl-e-aree-pedonali/divieto-di-circolazione-in-alcune-strade-del-vomero/ | `divieto-di-circolazione-in-alcune-strade-del-vomero.txt` | ufficiale; **non inserito** |
| Aree pedonali: piazza del Gesù (H24, varco Calata Trinità Maggiore), via dei Tribunali (varco Tribunali/Nilo dal 2019), Borgo Marinari (tutto il giorno), piazzetta Rodinò (tutto il giorno), via Tito Angelini, Istmo di Nisida (H24), via Luca Giordano, Centro Direzionale, via F. De Sanctis/San Domenico Maggiore (9–19) | pagine «area-pedonale-…» | `area-pedonale-*.txt` | ufficiali; **non inserite** (nessuna geometria) |
| ZTL Bus Turistici (solo bus) | https://www.comune.napoli.it/articolo_tematico/trasporti-mobilita/bus-turistici/ztl-bus-turistici/ | `ztl-bus-turistici.txt` | non riguarda le auto |
| Permessi temporanei solo «per comprovate e straordinarie necessità» (traslochi, manutenzioni, visite mediche per chi ha problemi di deambulazione, manifestazioni), per email a permessitemporanei.ztl@comune.napoli.it | https://www.comune.napoli.it/articolo_tematico/trasporti-mobilita/ztl-e-aree-pedonali/deroghe-e-permessi-di-accesso-temporaneo-alle-ztl-cittadine/ | `deroghe-…txt` | ufficiale → nessun `ticket` |
| Costi dei contrassegni: residenti 10/25/50 €, clienti degli alberghi «operanti all’interno della ZTL» 50 € | https://www.comune.napoli.it/articolo_tematico/trasporti-mobilita/ztl-e-aree-pedonali/ztl-e-aree-pedonali-modulistica/ | `ztl-e-aree-pedonali-modulistica.txt` | ufficiale |
| Disabili (CUDE): fino a due targhe registrate; transito non registrato da comunicare entro 48 ore via PEC ztl@pec.comune.napoli.it | https://www.comune.napoli.it/articolo_tematico/trasporti-mobilita/ztl-e-aree-pedonali/transito-persone-con-disabilita-nelle-ztl-e-ap/ (agg. 24/08/2026) | `transito-persone-con-disabilita-nelle-ztl-e-ap.txt` | ufficiale |
| Disciplinare (Delibera G.C. 1205/2011) e pagamento solo su Smartmobility → PartenoPay | https://www.comune.napoli.it/articolo_tematico/trasporti-mobilita/ztl-e-aree-pedonali/disciplinare-dellaccesso-e-la-circolazione-dei-veicoli-nelle-ztl-e-ap/ | `disciplinare-…txt` | ufficiale (il PDF del disciplinare non è stato letto) |
| Auto elettriche: la pagina «Documentazione» cita un PDF «Accesso e circolazione nelle ZTL del Comune di Napoli per i veicoli elettrici» (O.S. 604 del 12/06/2012); Quattroruote (gen. 2026, via WebSearch) parla di un tagliando annuale di circa 30 € per elettriche e ibride | https://www.comune.napoli.it/articolo_tematico/trasporti-mobilita/ztl-e-aree-pedonali/ztl-del-centro-antico/documentazione/ | `ztl-del-centro-antico_documentazione.txt` | PDF non letto; quindi `exemptFuels: []` |
| Multe: 83–332 € (art. 7 CdS), uguali in tutta Italia (`Resources/Rules/fine.json`); unipolmove.it e altri (via WebSearch) confermano 83–332 € per Napoli | — | — | non ufficiale per Napoli |
| Nuova grande ZTL e isola pedonale (Quartieri Spagnoli/area centrale) annunciate per il 2026 | businessonline.it (via WebSearch) | — | non ufficiale, nessun atto trovato: solo nota qui |

## 2. Come sono state modellate le regole

- **5 zone scritte, 4 nell'app**, tutte `kind: "restricted"`, nessun `ticket`, `exemptFuels: []`: `napoli-centro-antico`, `napoli-tarsia`, `napoli-belledonne`, `napoli-morelli`. La zona `napoli-ferdinando-russo` è nello script ma **esce solo quando c'è un perimetro** (in OSM non c'è): oggi è esclusa. Comunque è spenta fino al 1° aprile 2027.
- **Mezzocannone** non è una zona a parte: il Comune dà un perimetro unico per «Centro Antico», «Mezzocannone» e «Piazza del Gesù» e la relazione OSM «ZTL Centro Antico» li contiene. L'orario del varco di Mezzocannone coincide con quello di via del Sole, già usato per la zona; la differenza sulle moto (vietate a Mezzocannone) è nel riassunto.
- Giorni: 1 = domenica … 7 = sabato. Le fasce che passano la mezzanotte hanno `end < start`.
- **«Festivi e prefestivi»**: il modello conosce solo giorni della settimana e stagioni (senza anno). Per questo i festivi nazionali a data fissa e le loro vigilie sono scritti come finestre di un solo giorno (`season` con inizio = fine). Il **lunedì di Pasqua** (data mobile) non si può scrivere: nota «pending». Il **19 settembre** (San Gennaro, patrono) è contato come festivo (e il 18 come prefestivo), con nota. `localHolidays` **non** è usato: nessuna regola di Napoli esclude i festivi (sono sempre «tutti i giorni» o «anche festivi»), quindi `freeOnHolidays: false` ovunque.
- **Centro Antico**: i varchi hanno orari diversi (tre 9–17, via del Sole 9–22/9–2). La zona è una sola area, quindi GateLR la mostra chiusa finché c'è almeno un varco acceso: lun–gio 9–22, ven–dom 9–2, più 22–2 nei festivi/prefestivi a data fissa. È una scelta prudente (dopo le 17 si potrebbe entrare dai varchi spenti): spiegata nel riassunto e in «pending».
- **Morelli-Filangieri-Mille**: sabato e domenica dall'8/12 al 6/1, più i giorni 8/12, 24–26/12, 31/12, 1/1, 5–6/1 (festivi e prefestivi infrasettimanali), fasce 10–14 e 16–20.
- **Ferdinando Russo**: tutti i giorni 1/7–31/8; sabato e domenica 1/4–30/6 e 1–30/9; più 24–25/4, 30/4–1/5, 1–2/6, 18–19/9.
- **Hotel** (`hotelCanRegister`): `true` dove la pagina della zona elenca i «clienti degli alberghi» (Centro Antico, Mezzocannone, Morelli) o dice che gli alberghi registrano le targhe su Smartmobility (Ferdinando Russo); `false` con nota per Tarsia e Belledonne (la pagina non ne parla). La **scadenza** per la comunicazione della targa non è scritta in nessuna pagina HTML (sarà nel disciplinare PDF non letto): nota «pending».

## 3. Dubbi e punti da verificare

1. PDF non letti (disciplinare, ordinanze, mappe, O.S. 604/2012 sulle elettriche): vanno scaricati da un'altra rete e salvati in `data/raw/napoli/`.
2. Scadenza per gli hotel e modalità (Smartmobility per tutte le ZTL o solo per Russo/Marechiaro?).
3. Belledonne: 19–7 (Comune) o 24 ore (Sixt)?
4. ZTL Chiaia del sabato (2005/2008): la pagina non cita varchi e le strade coincidono in parte con la ZTL Morelli; non sappiamo se sia ancora fatta rispettare. Non inserita.
5. Marechiaro: istituita «per l'anno 2026» e finita il 27/09/2026; se il Comune la rinnova per il 2027, va aggiunta con le nuove date.
6. Lunedì di Pasqua e 19 settembre (vedi sopra).
7. Varchi: le coordinate vengono solo da OpenStreetMap (se ci sono), non da fonti ufficiali.

## 4. Geometria (perimetri e varchi)

**Da OpenStreetMap, non ufficiale** (© OpenStreetMap contributors, ODbL 1.0; dichiarato nel campo `license` e in un link per zona).
Dati scaricati con `Tools/fetch_geo.py` (GitHub Actions, Overpass `out geom`, run del 25/10/2026) in `data/raw/geo/napoli-ztl.json` e `napoli-gates.json`.
Il contorno si ricava con `Tools/osm_geo.py` (`outer_ring`) e si semplifica con Douglas-Peucker a 5 m (2 m per Morelli). Nessun perimetro disegnato a mano.
Il perimetro ufficiale esiste solo come elenco di strade e come mappe PDF non scaricabili da qui.

| Zona GateLR | Relazione OSM | Punti | Area | Varchi OSM |
|---|---|---|---|---|
| `napoli-centro-antico` | [19164566](https://www.openstreetmap.org/relation/19164566) «ZTL Centro Antico» | 51 | 0,96 km² | 6 |
| `napoli-tarsia` | [19164565](https://www.openstreetmap.org/relation/19164565) «ZTL Tarsia - Pignasecca - Dante» | 30 | 0,29 km² | 1 |
| `napoli-belledonne` | [19164564](https://www.openstreetmap.org/relation/19164564) «ZTL Belledonne - Martiri - Poerio» | 25 | 0,09 km² | 0 |
| `napoli-morelli` | [19164567](https://www.openstreetmap.org/relation/19164567) «ZTL Morelli - Filangieri - Mille» (striscia di ~11 m lungo le strade) | 66 | 0,017 km² | 0 |

Varchi: nodi OSM `man_made=surveillance` con nome o `designation` «Varco ZTL», assegnati alla zona con il bordo più vicino (massimo 60 m). Esclusi i «Varco» del porto (sbarre `barrier=*`: Pisacane, Carmine, Immacolatella), un semaforo e un bar chiamati «Varco». I varchi non hanno il nome della strada: l'abbinamento con i varchi ufficiali (via del Sole, via Miroballo, via Duomo, via Santa Sofia, Mezzocannone, piazza Gesù e Maria, via Domenico Soriano, via Brombeis, via Morelli) è da fare.

Controlli (25/10/2026, `python3` con `osm_geo.contains`): San Gregorio Armeno e via Mezzocannone dentro il Centro Antico; il centro dei poligoni Tarsia e Belledonne dentro le rispettive zone; la stazione Napoli Centrale, piazza del Plebiscito e Castel dell'Ovo fuori da tutte le zone. Orari: 18 casi provati con una copia in Python della logica di `RuleEngine` (per esempio Centro Antico lunedì 18:00 chiuso, 23:00 aperto, sabato 1:30 chiuso; Morelli sabato 12/12/2026 ore 11 chiusa, mercoledì 9/12 aperta, 24/12 ore 17 chiusa).

Dati aggiunti a `Tools/fetch_geo.py` (blocco «Napoli», da far girare con il workflow): i PDF ufficiali da `static-www.comune.napoli.it` (disciplinare, O.S. 604/2012 sulle elettriche, mappe) e da OSM la via Ferdinando Russo, la via Padre Gaetano Errico e le aree pedonali del centro.
