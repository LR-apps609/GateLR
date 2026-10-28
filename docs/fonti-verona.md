# Verona: fonti della scheda ZTL

Scheda generata da `Tools/build_verona.py` → `Resources/Cities/verona.json` (stato **draft**, `reviewedByHuman: false`), con perimetro e varchi da OpenStreetMap.
Fonti lette il **25/10/2026** e salvate in `data/raw/verona/`. Lo script controlla che ogni frase usata sia presente nei file salvati e che alcuni punti noti cadano dentro o fuori.

## Novità rispetto a `citta-successive.md`

- Le pagine del nuovo sito `www.comune.verona.it` (OpenCity) si leggono anche dall'API pubblica `https://www.comune.verona.it/api/opendata/v2/content/search/<query>` e `.../content/read/<id>`: così sono state trovate le schede dei servizi e le notizie del 2026 (copie in `data/raw/verona/api/`, `.json` grezzo e `.txt` estratto).
- **Nuova ZTL Santo Stefano** (Veronetta): varco in pre-esercizio dal 28/09/2026, **sanzioni da lunedì 2 novembre 2026** (Comune). Gli orari sono solo nei giornali locali.
- **Nuove telecamere dal 21/09/2026** su piazza Bra (chiusa h24) e ponte Aleardi (7–18), ponte Navi, via San Paolo, Interrato dell'Acqua Morta e alcune corsie bus.
- **Auto elettriche**: c'è una registrazione online (12 mesi), ma solo con SPID o CIE.
- La licenza del dataset dei varchi è ancora **CC BY-NC 4.0** (ricontrollata via API il 25/10/2026): le coordinate ufficiali non sono nel JSON.

## Fatti → fonte

Tutte le fonti sono state lette il 25/10/2026.

| Fatto | Fonte | Tipo | File |
|---|---|---|---|
| Perimetro descritto a parole ("Ansa interna dell'Adige compresa fra il Ponte Scaligero di Castelvecchio e Ponte Aleardi (Riva San Lorenzo inclusa), Via Ponte Aleardi, Via Pallone, Largo Divisione Pasubio, Via degli Alpini, Piazza Bra, Via Roma, Via Daniele Manin, Vicolo San Silvestro, Corso Castelvecchio"); 11 varchi per nome | https://www.comune.verona.it/Novita/Notizie/La-Zona-a-Traffico-Limitato-di-Verona (01/07/2025, ultimo aggiornamento 24/10/2025) | ufficiale | `notizia-ztl-verona.html` |
| Dal 28/10/2024 (Ordinanza n. 1486 del 21/10/2024) chi vive a Verona e provincia entra "solo su prenotazione" (max 4 ingressi al mese): lun–ven 10–18 e 20–23, "sabato, domenica e festivi" 10–13.30 | idem; anche https://polizialocale.comune.verona.it/nqcontent.cfm?a_id=30870 (archivio, 03/09/2025) | ufficiale | idem, `archivio-30870-mappa-orari.html` |
| Circolano sempre liberamente: residenti/dimoranti con permesso, "bici, ciclomotori e motoveicoli a due e tre ruote", clienti delle strutture ricettive in ZTL "previa comunicazione targa all'albergatore" (*non locazioni turistiche*), invalidi con contrassegno, altre categorie registrate | idem | ufficiale | idem |
| *"ZTL – ELIMINAZIONE DELLE FASCE ORARIE DI LIBERO ACCESSO"*: revoca il punto 4 dell'ord. sindacale 35/2005 (fasce libere lun–ven 10–13.30, 16–18, 20–22; sab/dom/festivi 10–13.30) e l'ord. 1500/2015; residenti a Verona e provincia *"previa registrazione della targa entro le ventiquattro ore precedenti la data del transito"*, *"con un limite di n. 4 (quattro) registrazioni nell’arco di un mese"*, lun–ven 10–18 e 20–23, *"il sabato, la domenica e festivi"* 10–13.30; art. 29 u) *"Autovetture a servizio dei clienti diretti ad Attività ricettive alberghiere e complementari situate in ZTL"* in transito libero *"con possibilità di sola fermata"* | **Ordinanza dirigenziale n. 1486 del 21/10/2024**, https://archive.comune.verona.it/media/_ComVR/Cdr2023/ComunicazioneURP/Allegati/Ordinanze/ord_01486_21-10-2024.pdf (letta il 25/10/2026) | ufficiale | `ord_01486_21-10-2024.pdf/.txt` |
| *"è consentito l’accesso e il transito libero in ZTL ai ciclomotori e motoveicoli a due e tre ruote"*; nuovi permessi annuali (famiglie con figli under 14, assistenza domiciliare, titolari di strutture ricettive 10–15, accompagnatori di ragazzi) | **Ordinanza dirigenziale n. 1545 del 31/10/2024**, https://archive.comune.verona.it/media/_ComVR/Cdr2023/ComunicazioneURP/Allegati/Ordinanze/ord_01545_31-10-2024.pdf | ufficiale | `ord_01545_31-10-2024.pdf/.txt` |
| Divieto di accesso, di norma, ai mezzi oltre 5,5 t | idem | ufficiale | idem |
| Turisti: "Risulta perciò necessario che per entrare in Ztl vi sia un pernottamento presso un albergo sito entro l'area della ZTL…"; l'albergatore comunica la targa "anticipatamente" con le credenziali del Comune (**citazione della scheda**) | https://polizialocale.comune.verona.it/nqcontent.cfm?a_id=26104 | ufficiale | `pl-26104-accesso-turisti.html` |
| Nessuna fascia di libero accesso per i non autorizzati → finestra 0–24 tutti i giorni, festivi compresi (`freeOnHolidays: false`) | deduzione dalle due pagine sopra; conferme non ufficiali: Autovia ("non ha più fasce di accesso libero… non esiste l'ora in cui i varchi si spengono") | ufficiale + incrocio non ufficiale | `unofficial/estratti-ricerca-2026-10-25.txt` |
| Strutture ricettive: adesione al Protocollo d'Intesa CityPASS (via PEC, 45 giorni), poi inserimento delle targhe ospiti in white-list; le locazioni turistiche sono escluse e le loro credenziali disabilitate | https://www.comune.verona.it/Servizi/Citypass-richiesta-di-adesione-al-Protocollo-d-Intesa-per-strutture-ricettive-situate-in-ZTL (mod. 28/11/2025) | ufficiale | `api/citypass-protocollo-strutture.txt` |
| Targhe sbagliate dell'hotel → modulo riservato agli albergatori; una targa errata fa partire la sanzione | https://polizialocale.comune.verona.it/nqcontent.cfm?a_id=27281 | ufficiale | `pl-27281-targhe-errate-albergatori.html` |
| Disabili: targa da inserire negli elenchi; transito occasionale "entro 72 ore dall'accesso" su https://accessiztl.comune.verona.it | https://polizialocale.comune.verona.it/nqcontent.cfm?a_id=26103 | ufficiale | `pl-26103-accesso-disabili.html` |
| Accessi straordinari (emergenze): max 3 giorni, una volta ogni 3 mesi, entro 72 ore (art. 17–18 Ord. Dir. n. 1365/2014) | https://www.comune.verona.it/content/view/full/7463 (mod. 25/11/2025) | ufficiale | `api/accesso-straordinario-ztl.txt` |
| Prenotazione per chi vive a Verona o provincia: portale https://citypass.veronamobile.it/ar/ | https://www.comune.verona.it/content/view/full/5114 | ufficiale | `api/prenotazione-accessi-ztl.txt` |
| Auto "full electric" (escluse ibride): registrazione solo con SPID/CIE su https://permessi.mobilita.comune.verona.it, durata 12 mesi; escluso l'accesso all'APU → `exemptFuels: []` | https://www.comune.verona.it/content/view/full/7434 (mod. 19/10/2026) | ufficiale | `api/ztl-elettriche.txt` |
| Sanzione: 98,50 €, 73,60 € entro 5 giorni (minimo 82 €, metà del massimo 165 €: valori del vecchio art. 7 CdS) | https://polizialocale.comune.verona.it/nqcontent.cfm?a_id=30873 (archivio "non più aggiornato", riletta il 25/10/2026); la scheda attuale «Pagare una sanzione» (https://www.comune.verona.it/api/opendata/v2/content/read/7363, mod. 25/06/2026) spiega termini e riduzioni ma **non dà importi** | ufficiale ma datata; UnipolMove indica 83–332 € (non ufficiale) | `archivio-30873-faq.html` |
| Piazza Bra chiusa "tutti i giorni, compresi i festivi, h24" (Ord. n. 564 del 20/04/2026, corsie riservate Ord. n. 1249 e 1284/2026, deroghe Ord. n. 1502 del 21/10/2026); ponte Aleardi vietato 7–18 tutti i giorni (Ord. n. 1253 del 01/09/2026); telecamere dal 21/09/2026 | https://www.comune.verona.it/content/view/full/23692 (18/09/2026, mod. 22/10/2026) | ufficiale | `api/telecamere-2026-09-18.txt`, `ord_01249_01-09-2026.pdf/.txt` |
| ZTL Santo Stefano: "pre-esercizio di circa 30 giorni a partire dal 28 settembre, prima dell'avvio delle sanzioni che partono da lunedì 2 novembre" (il comunicato del 03/09/2026 diceva 19 ottobre: superato) | idem; https://www.comune.verona.it/content/view/full/23392 | ufficiale | idem, `api/veronetta-2026-09-03.txt` |
| ZTL Santo Stefano: divieto tutti i giorni 9–12.30, 14–17.30, 20–7; moto e scooter ammessi; perimetro = Veronetta entro le mura (via Santo Stefano, via Fontanelle S. Stefano, via San Carlo) | Verona Tomorrow 25/09/2026; L'Arena; Autovia. Il 25/10/2026 l'ordinanza istitutiva **non risulta** tra i documenti del Comune (API OpenCity: ricerche «Santo Stefano», «ZTL», classe `document`; allegati delle notizie 23692 e 23392: solo ord. 564, 1249, 1253, 1284, 1502/2026); `albo-on-line.comune.verona.it` resta irraggiungibile e l'indice delle ordinanze su `archive.comune.verona.it` dà 403 | **solo non ufficiale** | `unofficial/estratti-ricerca-2026-10-25.txt` |
| Area pedonale piazza Erbe: telecamere di corso Porta Borsari e via Cairoli dal 01/02/2025 (oltre a via Sant'Anastasia); varco ex via Adua spostato in via Santo Stefano | https://www.comune.verona.it/content/view/full/7924 | ufficiale | `api/varchi-piazza-erbe-2025-01-21.txt` |
| Divieti antismog 01/10/2026–30/04/2027 (Ord. sindacale n. 56 e 59/2026), lun–ven 8.30–19.30 per benzina Euro 0–1, diesel Euro 0–4…, su tutto il territorio comunale | https://www.comune.verona.it/content/view/full/13311 | ufficiale | `api/antismog-2026-2027.txt` |
| ZTL Stadio (Bentegodi), 18 varchi, solo nei grandi eventi | veronatomorrow.it, mattinodiverona.it, veronasera.it | solo non ufficiale | `unofficial/estratti-ricerca-2026-10-25.txt` |
| Nessuna sospensione estiva o d'agosto | nessuna fonte la cita | – | – |

Il centro della città (45.4390, 10.9944, l'Arena) serve solo a inquadrare la mappa.

**Festivi e patrono:** la ZTL vale 0–24 anche nei festivi, quindi San Zeno (12 aprile) non cambia nulla e `localHolidays` non serve.

## Geometria: provenienza e licenza

**Da OpenStreetMap, non ufficiale** (© OpenStreetMap contributors, ODbL 1.0; scritto nel campo `license`, con i link alle way e la nota «Perimetro da OpenStreetMap»).

- Dati: `data/raw/geo/verona-ztl.json` e `verona-gates.json` (GitHub Actions, `Tools/fetch_geo.py`, Overpass `out geom`, 25/10/2026).
- In OSM la ZTL è fatta di **tre way chiuse** `boundary=limited_traffic_zone`, `name=Zona a Traffico Limitato di Verona`, `source=Comune di Verona`, `website=` la pagina ufficiale. Non si toccano: sono separate da 13–18 m, cioè dalle strade aperte al traffico (corso Cavour; la strada tra ponte Navi e largo Divisione Pasubio). Ognuna diventa una zona con le stesse regole:
  - `verona-ztl` «Città Antica · ZTL Centro storico»: [way 1346972386](https://www.openstreetmap.org/way/1346972386), 0,70 km², 36 punti dopo la semplificazione a 3 m;
  - `verona-ztl-aleardi` «Città Antica · ZTL verso ponte Aleardi»: [way 1346971350](https://www.openstreetmap.org/way/1346971350), 0,10 km²;
  - `verona-ztl-riva-san-lorenzo` «Riva San Lorenzo · ZTL presso Castelvecchio»: [way 1346972708](https://www.openstreetmap.org/way/1346972708), 0,03 km².
- **Controllo con i dati ufficiali (solo per verifica, non pubblicati):** gli 11 varchi del CSV del Comune (`mappa-ztl-varchi.csv`, CC BY-NC 4.0) stanno tutti entro ~90 m dal bordo dei contorni OSM, la maggior parte entro 20 m (Riva San Lorenzo a 8 m dalla way piccola, via Dogana dentro la way di ponte Aleardi).
- Controlli nello script: Arena, piazza Erbe, Casa di Giulietta e Duomo dentro la zona principale; stazione Porta Nuova, San Zeno, Castelvecchio, Santo Stefano e Castel San Pietro (Veronetta) fuori da tutte.
- **Varchi**: solo 3 telecamere sono in OSM (nodi `device` delle relazioni enforcement 4022484, 4022490, 4022627, nome «telecamera ZTL»). Il nome mostrato è quello del varco ufficiale più vicino (elenco della pagina «Mappa e orari»): 1 Lungadige Rubele, 2 Via Leoni, 8 Via Dogana. Gli altri 8 varchi non hanno posizione.
- Perché non le coordinate ufficiali: il dataset «Mappa della ZTL con varchi» (https://www.comune.verona.it/Amministrazione/Documenti-e-dati/Dataset/Mappa-della-ZTL-con-varchi) è **CC BY-NC 4.0**, incompatibile con un'app con acquisti in app finché il Comune non dà un permesso. Su dati.gov.it e sul catalogo della Regione Veneto non c'è un perimetro ZTL di Verona (cercato il 25/10/2026). Se arriva, si salva `data/raw/verona/ztl_perimetro.geojson` / `varchi.geojson` e lo script li usa al posto di OSM.
- Per Santo Stefano, piazza Bra e ponte Aleardi non c'è geometria in OSM nei dati scaricati. Serve una query Overpass in più (per esempio le strade `motor_vehicle=permit` / `access` attorno a via Santo Stefano e i nodi `highway=speed_camera`/`enforcement` vicino a piazza Bra): **non** aggiunta a `Tools/fetch_geo.py` in questa sessione.

## Da verificare (`pending` della scheda)

- Perimetro OSM da confrontare con la mappa ufficiale; varchi mancanti (8 su 11).
- ~~Ordinanze 1486 e 1545/2024~~: **lette il 25/10/2026** (i PDF su `archive.comune.verona.it` ora si aprono) e citate nello script; confermano orari delle prenotazioni, moto libere e transito libero dei clienti degli alberghi in ZTL, che però hanno solo la «sola fermata». Restano irraggiungibili `albo-on-line.comune.verona.it`, `amt3.it`, `ufficiostampa.comune.verona.it`, `accessiztl.comune.verona.it` e Overpass.
- Hotel: la targa va comunicata "anticipatamente"; nessun termine dopo l'ingresso trovato. Chiedere al Re.Ve.C. (800 517001, sanzioni.pmvr@comune.verona.it).
- **ZTL Santo Stefano**: orari (9–12.30, 14–17.30, 20–7) **confermati solo da Verona Tomorrow / L'Arena**; ordinanza istitutiva non trovata nemmeno il 25/10/2026 (vedi tabella); nessun perimetro (Overpass non raggiungibile da qui, nessun elenco ufficiale delle strade per `street_area`). Dal 2/11/2026 multa: aggiungere la zona appena ci sono testo e geometria.
- Piazza Bra (h24, ord. 564/2026) e ponte Aleardi (7–18, ord. 1253/2026): sono corsie riservate con telecamere, non ZTL, e non entrano nello schema delle zone; mancano le coordinate per metterle tra le `cameras` (Overpass non raggiungibile il 25/10/2026).
- Area pedonale urbana di piazza Erbe (Ordinanze n. 1504/2024, 1512 e 1513/2024, solo da estratti di giornali): è dentro la ZTL, non disegnata.
- Importo della multa: la pagina FAQ è nell'archivio "non più aggiornato" e nessuna pagina attuale del Comune dà un importo (cercato il 25/10/2026).
- Antismog e ZTL Stadio: non modellati (la prima vale su tutto il comune e dipende dal bollettino Arpav; la seconda solo nei giorni di partita).

## Moto e scooter (1.17.1)
`exemptVehicleTypes: ["motorcycle"]` sulle tre zone della ZTL: *"è consentito l'accesso e il transito libero in ZTL ai ciclomotori e motoveicoli a due e tre ruote"* (ordinanza 1545/2024).
