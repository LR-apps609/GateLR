# Bolzano/Bozen: fonti della scheda ZTL

Scheda generata da `Tools/build_bolzano.py` → `Resources/Cities/bolzano.json` (nell'app e nel sito, `reviewedByHuman: false`). Città bilingue: nomi e testi in italiano, tedesco e inglese; le vie hanno il nome doppio di OpenStreetMap («Via Museo / Museumstraße»).

Tutte le pagine sono state lette il **27/10/2026** dal sandbox (i siti del Comune, prima bloccati dal proxy, ora sono raggiungibili). I testi sono salvati in `data/raw/bolzano/` e il builder controlla, parola per parola, ogni frase usata.

## Zona
**Centro storico · ZTL 0–24 / Altstadt · Verkehrsberuhigte Zone rund um die Uhr** (`bolzano-ztl`, `restricted`): 0–24 tutti i giorni, `freeOnHolidays: false`, `hotelCanRegister: true`, nessun ticket, `exemptFuels: []`.

Citazione verificata (guida del Comune): «La ZTL del centro storico di Bolzano è attiva 24 ore su 24, tutti i giorni».

| Fatto | Fonte | Tipo |
|---|---|---|
| ZTL attiva 24 ore su 24, tutti i giorni; telecamere ai varchi; ingresso senza autorizzazione sanzionato | guida «Accesso ZTL e sosta nel centro abitato» (agg. 30/07/2026) https://www.comune.bolzano.bz.it/Vivere-il-Comune/Guide/Accesso-ZTL-e-sosta-nel-centro-abitato → `comune-guida-accesso-ztl.txt` | ufficiale |
| Turisti: accesso con veicoli privati vietato; se l'albergo è in ZTL contattarlo in anticipo per comunicare la targa e ottenere l'autorizzazione temporanea; parcheggi Mayr Nusser o Centro/piazza Walther | stessa guida | ufficiale |
| Carico/scarico ≤ 3,5 t lun–sab 6–10:30 (esclusi festivi infrasettimanali); elettrici/ibridi/idrogeno fino a 4,25 t con permesso anche fino alle 11 e, per alcuni varchi, 14:30–16 | stessa guida; delibera 518/2022 punti 4 e 6a; delibera 17/2023 punto 1 | ufficiale |
| Elenco delle vie e piazze della ZTL dal 01/02/2023 (punto 1); ospiti autorizzati degli esercizi ricettivi in ZTL: accesso e sosta solo per carico/scarico bagagli (punto 5); disabili con comunicazione della targa (punto 9) | delibera di Giunta n. 518 del 10/10/2022, PDF https://www.comune.bolzano.bz.it/ocmultibinary/download/10136/271413/5/90e4623ba8f7fbcae1eaa5d8bfb5e0f5.pdf/file/cd6fd97163c172f472707f9e682ad037.pdf (pagina: …/Delibere-della-Giunta-Comunale-n.-518-2022-e-n.-17-2023) → `delibera-gc-518-2022-ztl.txt` (colonna italiana) | ufficiale |
| Modifiche: 4,25 t per elettrici/ibridi/idrogeno, parcheggi privati 48 ore, bici libere in via Portici | delibera di Giunta n. 17 del 30/01/2023 → `delibera-gc-17-2023-ztl.txt` | ufficiale |
| Permessi della Polizia Municipale (tel. 0471 997799, A.3.P@comune.bolzano.it, Portale ZTL con SPID/CIE/CNS per alcune categorie); marca da bollo 16 € | servizio https://www.comune.bolzano.bz.it/Servizi/Polizia-Municipale-Permessi-varchi-elettronici-ZTL-ed-aree-pedonali → `comune-servizio-permessi-ztl.txt`; versione tedesca https://www.gemeinde.bozen.bz.it/Dienste/Stadtpolizei-Genehmigung-fuer-die-Einfahrt-in-die-verkehrsberuhigte-Zone-VBZ-und-in-die-Fussgaengerzone → `gemeinde-dienst-genehmigung-vbz.txt` | ufficiale |
| Tutti gli accessi ai varchi controllati (whitelist/blacklist), sistema SART_SMART omologato (decreto MIT 359/2019); mappa dei varchi su Google My Maps | https://www.comune.bolzano.bz.it/Amministrazione/Documenti-e-dati/Documenti-tecnici-di-supporto/Polizia-Municipale-I-varchi-gates-con-le-telecamere-di-controllo-della-ZTL-in-centro-storico → `comune-varchi-telecamere-ztl.txt` | ufficiale |
| In tutto il centro abitato, lun–ven non festivi 7–10 e 16–19: vietati benzina Euro 0–1 e diesel Euro 0–3; moto, GPL, metano, elettrici, ibridi sempre ammessi | https://www.comune.bolzano.bz.it/Amministrazione/Documenti-e-dati/Documenti-tecnici-di-supporto/Divieti-di-circolazione-per-limitare-l-inquinamento-dell-aria → `comune-divieti-inquinamento.txt` | ufficiale (nei pending: nessun perimetro del centro abitato in formato utilizzabile, solo un PDF di 25 MB) |
| Multa circa 80 € | accessibilitacentristorici.it (ricerca del 27/10/2026) | non ufficiale (nei pending) |

Il comunicato del 2023 «Neue Park- und Verkehrsregeln für die Altstadt» usato nella bozza ora risponde **410 Gone**: le regole vengono dalla delibera.

## Pending (nella scheda, it/de/en)
Procedura albergo (nessun termine ufficiale per la registrazione della targa); nessun biglietto per visitatori, elettriche e moto non esenti; carico/scarico; divieti Euro nel centro abitato (non sulla mappa); perimetro e telecamere, multa.

## Geometria
- **Perimetro dall'elenco ufficiale delle vie** (delibera 518/2022, punto 1) con le geometrie OpenStreetMap delle strade (`data/raw/geo/bolzano-ztl.json`, scaricato il 27/10/2026 con `Tools/fetch_osm_api.py`, © OpenStreetMap contributors, ODbL 1.0): 29 vie/piazze intere più 5 tratti «compresi tra» due vie (via Alto Adige piazza Verdi–viale Stazione, via Laurin via Sciliar–via Grappoli, via Leonardo da Vinci via Goethe–via Cassa di Risparmio, via Conciapelli via Laurin–via Molini, via Museo piazza Erbe–via Cassa di Risparmio), ritagliati tra i due incroci; area coperta dalle strade con `osm_geo.street_area` (chiusura 60 m, semplificazione 4 m), 0,225 km².
- Approssimazioni: viale Stazione «tra accesso Parking Walther e piazza Walther» = primi 100 m dalla piazza; via Piave «fino al civ. 5» non tracciata (pochi metri accanto a piazza Municipio); via della Roggia intera.
- La relazione OSM 19584710 (usata nella bozza) non contiene diverse vie ufficiali (via Cappuccini, via Isarco, piazza Università, piazza del Grano, vicolo Wolkenstein, via Perathoner…): non è più usata per il perimetro.
- Varchi: le 13 telecamere «device» della relazione OSM 19584710 (9 dopo aver unito le coppie a meno di 15 m), con il nome della via OSM più vicina; non ufficiali, perché la mappa ufficiale (Google My Maps `mid=1n6yKwLwGM9aBtfaLJTzddB6JmDcRIkE`) dà 403 dal proxy.
- Controlli nel builder: piazza Walther, piazza Erbe e via Portici dentro; stazione, piazza Verdi sud e Museion fuori; il punto centrale di ogni via intera dell'elenco dentro; telecamere entro 80 m dal bordo.
