# Como: fonti della scheda ZTL

Scheda generata da `Tools/build_como.py` → `Resources/Cities/como.json` (stato **draft**, `reviewedByHuman: false`), nell'app tramite `manifest.json` dal 27/10/2026. Regole e citazione **verificate** sui testi ufficiali letti il **27/10/2026** e salvati in `data/raw/como/` (URL e data in testa a ogni file; il builder controlla che ogni frase usata compaia parola per parola).

## Zona
**Città Murata · ZTL centro storico** (`como-ztl`, `restricted`): 0–24 tutti i giorni, festivi compresi (`freeOnHolidays: false`), nessun ticket, `hotelCanRegister: true`, nessuna esenzione per le elettriche.

Citazione (ordinanza dirigenziale n. 11 del 13/01/2017, art. 1 c. 2, testo coordinato con le ord. 248/2019 e 105/2023, https://www.comune.como.it/export/sites/comune-di-como/.galleries/PLocale-PrCivile/ord_ztl_11-2017.pdf, ufficiale): «Nella zona a traffico limitato “Città Murata”, dalle ore 00:00 alle ore 24:00, di ogni giorno, è vietata la circolazione (transito e sosta) di tutti i veicoli a motore ad eccezione di quanto previsto al capo II della presente ordinanza.»

| Fatto | Fonte (letta il 27/10/2026) | Tipo |
|---|---|---|
| Area: tutta la «Città murata», piazza Roma/piazza Verdi (via Rodari, piazza Roma, via Bianchi Giovini, Caio Plinio II, piazza Grimoldi, via Macchi, via Pretorio), piazza Volta, via Grassi, via Garibaldi; limitazione «durante tutto l'anno»; controllo elettronico degli ingressi | https://www.comune.como.it/servizi/Accesso-alla-ZTL-Zona-a-Traffico-Limitato/ (aggiornata il 27/10/2026) → `comune-servizio-accesso-ztl.txt` | ufficiale |
| Varchi in ingresso: via Cinque Giornate, via Diaz, via Carducci, via Indipendenza, via Rodari, via Grassi, via Cairoli; in uscita: via dell'Annunciata, via Indipendenza, via Rodari, via Cairoli, via Garibaldi | pagina del servizio | ufficiale |
| Permessi solo online (SPID/CIE), bollo 16 €, spese 5–20 €, gratis per persone con disabilità | pagina del servizio | ufficiale |
| ZTL 0–24 ogni giorno (art. 1); APU «Alessandro Volta» 0–24 anche per i contrassegni disabili (art. 2, mod. ord. 248/2019); APU «Duomo» 10:30–14:30 e 15:00–06:00, nelle altre ore vale la ZTL (art. 3) | ordinanza 11/2017 → `ord-11-2017-testo-coordinato.txt` | ufficiale |
| Divieto oltre 3,5 t o 7 m (art. 4 c. 2); 10 km/h; sosta vietata 0–24 salvo eccezioni | ordinanza 11/2017 | ufficiale |
| Clienti delle strutture ricettive in ZTL: autorizzazione in sanatoria dando la targa alla struttura, che la comunica alla Polizia Locale «nei termini di cui al regolamento»; un accesso al check-in e uno al check-out, max 45 minuti; con posti privati della struttura accesso per tutto il soggiorno (art. 7 c. 1 lett. b) | ordinanza 11/2017 | ufficiale |
| Disabili: targa comunicata entro 48 ore dall'accesso (art. 7 lett. a) | ordinanza 11/2017 | ufficiale |
| Esigenze specifiche non continuative: domanda almeno 2 giorni lavorativi prima, durata max 2 giorni; urgenze: fino a 3 ore dalla Polizia Locale (art. 8) | ordinanza 11/2017 e tabella permessi → `permessi-orari-sosta.txt` | ufficiale |
| Moto e ciclomotori senza formalità solo verso i parcheggi a loro riservati, per la via più breve; veicoli diretti al parcheggio «Arena» se il pannello all'ingresso indica posti liberi (art. 9) | ordinanza 11/2017 | ufficiale |
| Merci: veicoli elettrici senza limiti orari (solo autocarri per consegne, non le auto) | ordinanza 11/2017, art. 6 lett. b | ufficiale |
| Bus turistici solo per i clienti degli hotel in ZTL, percorso fisso (ord. 105/2023) | https://www.comune.como.it/servizi/Bus-turistici-Accesso-alla-ZTL/ → `comune-bus-turistici-ztl.txt` | ufficiale |
| Elenco delle vie in ZTL | https://www.comune.como.it/export/sites/comune-di-como/.galleries/PLocale-PrCivile/Elenco_delle_vie_inserite_nella_Zona_a_Traffico_Limitato.pdf → `elenco-vie-ztl.txt` | ufficiale |
| Sanzioni: «vigente codice della strada» (art. 10), importi non indicati | ordinanza 11/2017 | ufficiale |
| Parcheggio «Arena» in via Bellini 21 | blog JoyDellaVita (ricerca web) | non ufficiale |

Fonti non ufficiali scartate: una guida in rete riporta «feriali 10–18, weekend liberi» per la ZTL di Como: contraddetta dall'ordinanza (0–24 ogni giorno).
Patrono (Sant'Abbondio, 31 agosto): non serve con 0–24 tutti i giorni.

## Pending (mostrati nella scheda)
- Termine per la comunicazione della targa da parte dell'hotel: rinviato al «regolamento» comunale, non trovato sul sito.
- Parcheggio Arena ancora in funzione: confermato solo da fonti non ufficiali.
- Multe: importi del Codice della strada, non nell'ordinanza. Nessuna modifica 2026–2027 trovata sul sito del Comune (pagina del servizio aggiornata il 27/10/2026).
- Perimetro e varchi non ufficiali (vedi sotto); APU disegnate solo in parte (piazza Volta, piazza Cavour, piazza Grimoldi, piazza Duomo).

## Geometria (non ufficiale, da OpenStreetMap)
- Open data: nessun dataset ZTL di Como su www.dati.lombardia.it (ci sono Bergamo, Pavia, Cremona, Rho) né su dati.gov.it; la planimetria ufficiale (https://www.comune.como.it/export/sites/comune-di-como/.galleries/PLocale-PrCivile/Allegato-planimetrico.pdf, allegati A–D) è un disegno CAD senza coordinate. opendata.comune.como.it e dati.comune.como.it: proxy 403 (non verificabili).
- Dati OSM scaricati il 27/10/2026 con l'API OSM (`Tools/fetch_osm_api.py`, riquadro 45.804–45.817 N, 9.074–9.093 E) → estratto in `data/raw/geo/como-centro.json` (strade, parcheggi, aree pedonali, relazioni ZTL, nodi con tag; © OpenStreetMap contributors, ODbL 1.0).
- Perimetro: relazione OSM 21710224 (`boundary=limited_traffic_zone`, «Zona a Traffico Limitato», versione 1 del 18/10/2026), che segue le mura e il confine del quartiere «Città murata»; 0,44 km², semplificazione 4 m.
- Controlli nel builder: tutte le 60 vie dell'elenco ufficiale trovate in OSM (tranne «via Ballerini», assente, e viale Battisti, in ZTL solo per il viale alberato del mercato) hanno almeno un tratto dentro il perimetro; l'area coperta da quelle vie (osm_geo.street_area) cade per il 95% dentro il perimetro (via Garibaldi e via Grassi proseguono oltre i varchi) e il perimetro è 1,29 volte quell'area; confronto visivo con la planimetria ufficiale. Duomo, San Fedele, piazza Cavour e parcheggio Arena dentro; stazione San Giovanni, Tempio Voltiano, Novosilo di via Sirtori fuori.
- Varchi: per ogni via dell'elenco ufficiale dei varchi, il nodo OSM di quella via più vicino al bordo (tutti entro 7 m, via Rodari 67 m: il varco è all'imbocco da piazza Verdi); non sono posizioni rilevate delle telecamere (in OSM non ci sono telecamere ZTL etichettate).
- Aree pedonali: contorni OSM di piazza Volta (way 547472905), piazza Cavour (relazione 7819572), piazza Grimoldi (way 429693158), piazza Duomo (relazione 10961938).

## Moto e scooter (1.17.1)
Nessuna esenzione: moto e ciclomotori entrano senza formalità solo per raggiungere i parcheggi a loro riservati, per la via più breve → «Non entrare» (nota nel riassunto).
