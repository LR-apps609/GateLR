# Pisa: fonti e stato delle verifiche

Letture del **24–26/10/2026**. Scheda generata da `Tools/build_pisa.py` a partire dai file in `data/raw/pisa/` e `data/raw/geo/pisa-*.json`. Dal 26/10/2026 è **nell'app** (`Resources/Cities/pisa.json`): ci sono i perimetri ricavati dalle strade OSM (`data/raw/geo/pisa-streets.json`) e i controlli di plausibilità passano. Se un controllo smette di passare, lo script la rimette in `data/drafts/pisa.json`.

**Raggiungibilità:** www.comune.pisa.it funziona (API OpenCity, `/api/opendata/v2/content/read/<id>`, file `comune-pisa-content-<id>.json`; ricerca `q = 'ZTL'` in `comune-pisa-search-ZTL-index.json`). **Dal 25/10/2026 si apre anche mobilita.pisamo.it**: dalla sezione [Download › ZTL](https://mobilita.pisamo.it/download-category/ztl/) sono stati scaricati i PDF dell'ord. 2386/2024 e delle sue modifiche, della ZTL dei Lungarni e delle tariffe 2025. Restano chiusi (CONNECT 403 o reset): www.pisamo.it, albopretorio.comune.pisa.it, overpass-api.de e i mirror, api.openstreetmap.org.

## Zone

| Zona | Orari | Nella scheda |
|---|---|---|
| **ZTL Centro Storico Nord** (a nord dell'Arno: Duomo/Miracoli, Cavalieri, San Francesco, Santa Maria) | **0–24 tutti i giorni**, festivi compresi | Sì (`pisa-ztl-nord`) |
| **ZTL Centro Storico Sud** (a sud dell'Arno: San Martino, Sant'Antonio) | **0–24 tutti i giorni**, festivi compresi | Sì (`pisa-ztl-sud`) |
| **ZTL dei Lungarni** (Lungarno Pacinotti, Mediceo, Galilei, Gambacorti, piazza Carrara, piazza Mazzini, via San Nicola, via Santa Maria tra via San Nicola e Lungarno Pacinotti, Ponte di Mezzo) | **ven, sab, dom 22–5** del giorno dopo, permanente dal 1/1/2025 | Sì (`pisa-ztl-lungarni`), con il perimetro dalle strade dell'ord. 2845/2024 |
| ZTL Stadio (Porta a Lucca) | partite casalinghe del Pisa SC, da due ore prima del fischio d'inizio a fine primo tempo | No: dipende dal calendario delle partite (pending) |
| Aree pedonali dentro la ZTL: via Corsica e piazza Buonamici (24 ore su 24, 2026); via Santa Maria (ord. 531/2015) | — | No: sono già dentro la ZTL Nord 0–24 |

**Festivi e patrono:** la regola vale «tutti i giorni», quindi `freeOnHolidays: false` e nessun `localHolidays` (San Ranieri, 17 giugno, non cambia niente). L'ord. 2845/2024 dei Lungarni non parla di festivi: vale ogni venerdì, sabato e domenica notte.

## Fatti e fonti

| Fatto | Fonte | Stato |
|---|---|---|
| *"Nelle zone come definite nella prima parte è istituito il divieto di accesso, transito e sosta di tutti i veicoli, nell’orario 0-24 di tutti i giorni, fatte salve le deroghe espresse ai punti successivi."* Due settori, Centro Storico Nord e Sud, con l'elenco delle strade e 10 varchi per settore; *"La presente ordinanza entra in vigore dal 01/01/2025"*; revoca l'ord. 486/2010 e la 215/2014 | **Ordinanza Dir. 12 n. 2386 del 24/10/2024**, [Pisamo](https://mobilita.pisamo.it/download/ordinanza-n-2386-del-24-ottobre-2024-disciplina-per-laccesso-e-la-sosta-nelle-zone-a-traffico-limitato-a-partire-dal-1-gennaio-2025/) → `ordinanza-2386-2024-disciplina-ztl-2025.pdf/.txt` | **Ufficiale** → citazione della scheda, `windows` 0–24 tutti i giorni. **Confermato** lo 0–24 che prima veniva dall'ord. 486/2010 |
| Elenco strade 2025 rispetto al 2010: entrano via Sant'Orsola, via Rigattieri, vicolo del Tinti, vicolo Roncioni, via Vernagalli, largo Ciro Menotti, piazza del Pozzetto, via San Iacopino, piazza San Frediano, via San Ranierino, via Cardinale Maffi (Nord) e via la Nunziatina (Sud); escono piazza Mazzini (ora nella ZTL dei Lungarni) e piazza Saffi; «vicolo del Tozzi» è scritto «vicolo del Torzi» | ord. 2386/2024, parte prima | Ufficiale → liste `NORD` e `SUD` di `build_pisa.py` |
| *"L’INSERIMENTO DI PIAZZA SAN GIORGIO NELL’ELENCO DELLE VIE O PIAZZE DEL SETTORE DEL CENTRO STORICO NORD (ZTL NORD)."* | Ord. n. 2719 del 05/12/2024 → `ordinanza-2719-2024-modifiche-2386.*` | Ufficiale → aggiunta al settore Nord |
| *"L’ISTITUZIONE DI DUE NUOVI VARCHI ELETTRONICI PER LA ZTL IN PIAZZA SANTO SEPOLCRO E IN PIAZZA CAIROLI"* | Ord. n. 406 del 26/02/2025 → `ordinanza-406-2025-varchi-santo-sepolcro-cairoli.*` | Ufficiale → pending sui varchi (OSM ne ha 15) |
| Ord. 2847/2024: cambia solo gli orari dei permessi dei medici di base | `ordinanza-2847-2024-medici.*` | Ufficiale, non rilevante per i turisti |
| *"A far data dal 01 Gennaio 2025 nei giorni di Venerdì, Sabato e Domenica, è istituita, dalle ore 22.00 alle ore 5.00 del giorno successivo, la Zona a Traffico Limitato nelle seguenti strade:"*; *"RITENUTO di rendere permanente il provvedimento"*; permessi Nord/Sud, anche temporanei, validi anche qui; chi è in sosta alle 22 può restare e uscire | **Ordinanza Dir. 12 n. 2845 del 23/12/2024**, [Pisamo](https://mobilita.pisamo.it/download/ztl-lungarni-regolamentazione-della-zona-a-traffico-limitato-dei-lungarni-dal-01-gennaio-2025/) → `ordinanza-2845-2024-ztl-lungarni.*` | **Ufficiale** → zona `pisa-ztl-lungarni` (prima: stato ignoto, ultima proroga trovata a gennaio 2023) |
| Ciclomotori, quadricicli leggeri e motocicli entrano liberamente (punto 1.1) | ord. 2386/2024 | Ufficiale |
| Disabili: *"L’iscrizione dell’autoveicolo alla Piattaforma nazionale CUDE garantisce l’inscrizione automatica alla lista bianca."*; cartelli CUDE ai varchi (2026) | ord. 2386/2024, 1.2 c); obj 28529 | Ufficiale |
| Strutture ricettive professionali dentro la ZTL (punto 5.1): *"L’inserimento della targa in lista bianca T dovrà avvenire, a cura della struttura ricettiva interessata, entro 10 (dieci) ore dall’ingresso del veicolo del cliente in Z.T.L."*; sosta negli stalli bagagli *"fino ad un massimo di 30 (trenta) minuti"*; registrazione per *"una durata massima di 3 (tre) giorni rinnovabili"*; permessi non oltre il numero delle camere | ord. 2386/2024 | **Ufficiale 2025** → `hotelCanRegister: true` (prima: dati del 2023) |
| Permesso di sosta per i clienti: *"12,00 (validità 24 ore)"*, sosta in ZTL (esclusi gli stalli dei residenti), ZSC e Litorale | Tariffe 2025, allegato B (DGC 284/2024), [Pisamo](https://mobilita.pisamo.it/download/tariffe-diritti-ed-altre-entrate-extra-tributarie-allegato-b-parcheggi-accesso-z-t-l-mobilita/) → `pisamo-tariffe-allegato-b-2025.*` | **Ufficiale 2025** |
| Accesso alla struttura gratuito: *"I clienti potranno accedere con il proprio veicolo gratuitamente"* | obj 5972 (2023) | Ufficiale; l'ord. 2386/2024 e le tariffe non prevedono un costo per l'accesso (solo per la sosta) |
| Solo strutture professionali: *"Solo alle strutture ricettive professionali: Alberghi, B&B e similari"* | https://www.comune.pisa.it/Servizi/Registrazione-Targhe-per-accesso-veicoli-in-ZTL (obj 3404) | Ufficiale |
| Nessun ticket per turisti: i permessi temporanei del punto 5.6 (6 h 20 €, 12 h 28 €, 24 h 40 €) sono solo per casi elencati (mezzi pesanti, riprese, matrimoni, traslochi, cantieri, taxi/NCC, ecc.) | ord. 2386/2024 5.6; tariffe 2025 | Ufficiale |
| Auto elettriche: le premesse citano la *"autorizzazione al transito in ZTL dei veicoli elettrici"* (DGC 6/2/2013), ma le regole non prevedono esenzioni | ord. 2386/2024 | `exemptFuels: []`, delibera 2013 non letta (pending) |
| Multe: *"saranno applicate le sanzioni previste dal vigente Codice della Strada"* | ord. 2386/2024, cap. 12 | Importo non riportato nella scheda |
| Contatti: Ufficio ZTL Varchi Elettronici, pm.ztl@comune.pisa.it, 050 910828; Pisamo 050 7062, frontoffice@pisamo.it | obj 13525, 14801, 30326 | Ufficiale |
| Storico: ord. 486/2010 (0–24 già dal 2011), 215/2014, orari 2002 | `ordinanza-486-2010-*`, `ordinanza-215-2014-*`, `ordinanza-303-2002-*` | Revocate dall'ord. 2386/2024, tenute come storico |

## Cosa resta da verificare (pending nella scheda)

- Perimetri: approssimati, ricavati dalle strade dell'elenco ufficiale (vedi «Geometria»). Nel settore Sud 4 voci su 70 non hanno una strada OSM con lo stesso nome (via del Cottolengo, via Zandonai, piazza S. Martino, vicolo Mossotti): non entrano nel calcolo del contorno.
- Varchi: le 15 telecamere di OSM più i 2 varchi in uscita dell'ord. 406/2025, contro i 10+10 varchi dell'ord. 2386/2024: alcune telecamere possono mancare.
- Strutture sui Lungarni: l'ord. 2845/2024 non dice se possono registrare gli ospiti (`hotelCanRegister: false` per prudenza).
- Delibera di Giunta del 6/2/2013 sui veicoli elettrici: non letta.

## Geometria

**Perimetri: ZTL Nord, ZTL Sud e Lungarni, dalle strade OSM dell'elenco ufficiale (26/10/2026). Varchi: 15 da OpenStreetMap + 2 dell'ord. 406/2025** (© OpenStreetMap contributors, ODbL 1.0, scritto nel campo `license`).

- OSM non ha il contorno: la relazione [9342809](https://www.openstreetmap.org/relation/9342809) «Zona a Traffico Limitato» contiene **solo le 15 telecamere** (ruolo `device`), come i 15 varchi elencati nel 2010 (l'ord. 2386/2024 ne elenca 20, più 2 dell'ord. 406/2025).
- Il perimetro di ogni settore si ricava **dall'elenco ufficiale delle strade** dell'ord. 2386/2024 (più piazza San Giorgio, ord. 2719/2024; per i Lungarni l'elenco dell'ord. 2845/2024), con la geometria OSM di quelle strade, unite con `osm_geo.street_area` (chiusura morfologica, come per Siena). I tratti parziali dell'ordinanza (anche via Santa Maria tra via San Nicola e Lungarno Pacinotti per i Lungarni) (via San Francesco da via Oberdan a via Buonarroti, via Santa Maria e via Roma da piazza del Duomo a via San Nicola / via Savi, via Mercanti, via Lalli, via San Bernardo fino a vicolo dell'Oro) sono tagliati tra le due strade indicate. Nessun punto è disegnato a mano.
- `data/raw/geo/pisa-streets.json`: strade con nome del centro (`way["highway"]["name"](43.705,10.383,43.729,10.418); out geom;`, la stessa richiesta del blocco «Pisa» di `Tools/fetch_geo.py`), scaricate il 26/10/2026 da overpass-api.de (dato OSM del 26/10/2026, © OpenStreetMap contributors, ODbL). Risultato: Nord 124/124 strade trovate, Sud 66/70, Lungarni 9/9; aree Nord 0,59 km², Sud 0,35 km², Lungarni 0,13 km².
- Nomi: oltre alla corrispondenza normale (abbreviazioni, «S.» = San/Santa, iniziali), se il nome esatto non c'è si accetta la strada OSM con le stesse parole e un tipo vicino (via/vicolo/chiasso, piazza/piazzetta: es. «Vicolo del Torzi» = «Via del Torzi», «Piazza del Crocifisso» = «Piazzetta del Crocifisso», «Vicolo Mozzo» = «Chiasso Mozzo»); le way fuori dalle mura restano escluse.
- `data/raw/geo/pisa-cameras.json` (26/10/2026, overpass-api.de): telecamere (`man_made=surveillance`), semafori, relazioni `enforcement` e oggetti con nome «Sepolcro»/«Cairoli». Nessuna telecamera OSM nelle due piazze dell'ord. 406/2025, che li indica come varchi **in uscita** («piazza Cairoli (uscita)» nella ZTL Nord, «piazza S. Sepolcro (uscita)» nella ZTL Sud): li mettiamo all'ultimo nodo della way OSM a senso unico della piazza (way [1230657390](https://www.openstreetmap.org/way/1230657390) e [26681125](https://www.openstreetmap.org/way/26681125)), cioè dove le auto lasciano la piazza. Posizione approssimata, scritta nel pending.
- Lo script stampa le strade dell'ordinanza non trovate in OSM e scrive la scheda nell'app solo se: ne mancano al massimo il 10% per settore; piazza dei Miracoli e piazza dei Cavalieri cadono nel settore Nord e piazza San Martino nel Sud; la stazione di Pisa Centrale è fuori; le aree sono plausibili (Nord 0,5–2 km²: l'elenco lascia fuori il quadrante di piazza Santa Caterina / San Zeno e la parte a ovest di via Roma, Sud 0,25–1,2 km²; Lungarni 0,02–0,5 km², controllo a parte che non blocca i settori). Altrimenti la scheda resta in `data/drafts/`.
- I varchi vanno al settore più vicino (Nord 8, Sud 9; i due dell'ord. 406/2025 finiscono nel settore indicato dall'ordinanza). Controlli superati il 26/10/2026: piazza dei Miracoli (43.7230, 10.3966) e piazza dei Cavalieri (43.7193, 10.4006) nel Nord, piazza San Martino nel Sud, Pisa Centrale (43.7085, 10.3986) fuori da tutte le zone. La scheda è in `Resources/Cities/pisa.json` (status `draft`, `reviewedByHuman: false`).

## File in data/raw/pisa/

- Ordinanze in vigore (da mobilita.pisamo.it, 25/10/2026): `ordinanza-2386-2024-disciplina-ztl-2025`, `ordinanza-2719-2024-modifiche-2386`, `ordinanza-2847-2024-medici`, `ordinanza-406-2025-varchi-santo-sepolcro-cairoli`, `ordinanza-2845-2024-ztl-lungarni` (`.pdf` e `.txt`); tariffe `pisamo-tariffe-allegato-b-2025.pdf/.txt`.
- Ordinanze storiche: `ordinanza-486-2010-disciplina-ztl.pdf` e `.txt`, `ordinanza-215-2014-san-ranierino-maffi-ztl-nord.txt`, `ordinanza-531-2015-ztl-santa-maria.txt`, `ordinanza-303-2002-riepilogo-ztl.pdf`, `ordinanza-487-2010-veicoli-elettrici.pdf`.
- Pagine del Comune (API OpenCity): `comune-pisa-content-{3404,13536,3414,13525,5972,5674,5893,20500,30326,30591,31288,27780,27924,28250,18556,5445,5498,28529,9436,11691,10354,14179,20262}.json`.
- `comune-pisa-search-ZTL-index.json`: indice dei 227 risultati della ricerca «ZTL» sul sito del Comune.

Licenza dei contenuti del sito: CC BY 4.0, come dichiarato nei metadati dei documenti.

## Moto e scooter (1.17.1)
`exemptVehicleTypes: ["motorcycle"]` su Nord, Sud (*"VEICOLI A TRAZIONE ANIMALE, VELOCIPEDI, CICLOMOTORI, QUADRICICLI LEGGERI E MOTOCICLI"*, ord. 2386/2024 punto 1.1) e Lungarni (*"i veicoli a trazione animale, velocipedi, ciclomotori, quadricicli leggeri e motocicli sia consentito l'accesso, il transito e anche la sosta"*, ord. 2845/2024).
