# Vicenza: fonti della scheda ZTL

Scheda generata da `Tools/vicenza_mappa.py` + `Tools/build_vicenza.py` → `Resources/Cities/vicenza.json` (stato **draft**, `reviewedByHuman: false`), nell'app tramite `manifest.json` dal 27/10/2026. Regole e citazione **verificate** sui testi ufficiali letti il **27/10/2026** e salvati in `data/raw/vicenza/` (URL e data in testa a ogni file; il builder controlla ogni frase usata).

## Zona
**Centro storico · ZTL** (`vicenza-ztl`, `restricted`): 0–24 tutti i giorni (`freeOnHolidays: false`), nessun ticket, `hotelCanRegister: false` (nessuna procedura trovata), nessuna esenzione per le elettriche.

Citazione (pagina «ZTL, zona a traffico limitato: informazioni generali», https://www.comune.vicenza.it/Servizi/ZTL-zona-a-traffico-limitato-informazioni-generali, ufficiale, aggiornata il 17/07/2024): «Le telecamere registrano tutti gli accessi dei veicoli 24 ore su 24, tranne che per il varco di corso Fogazzaro (varco CHIUSO, con rilevazione dei transiti non autorizzati, dalle 20 alle 9 nei giorni feriali e 0-24 nei giorni festivi).»

| Fatto | Fonte (letta il 27/10/2026) | Tipo |
|---|---|---|
| ZTL dal 1996; telecamere (Piazzale de Gasperi–Porta Castello, via Montagna, contrà Pedemuro San Biagio, corso Fogazzaro, contrà Porti, contrà Gazzolle, contrà Carpagnon, stradella Santo Stefano, contrà San Faustino) 24 ore su 24 salvo corso Fogazzaro; sanzione automatica; permesso esposto sul cruscotto; categorie dell'ordinanza 3474/95 | pagina informazioni generali → `comune-ztl-informazioni-generali.txt` | ufficiale |
| Tipi di permesso (residenti, dimoranti, attività, manutentori, posto auto, enti, speciali, nuclei monofamiliari, deroghe), ciascuno con i varchi di entrata e uscita autorizzati; bolli 2×16 € | https://www.comune.vicenza.it/Servizi/Permessi-per-accesso-ZTL-e-AP-tipologie-e-come-ottenerli (agg. 16/10/2026) → `comune-permessi-tipologie.txt` | ufficiale |
| Temporanei solo per merci (tramite Vicenza Logistic City Center / Veloce), cantieri (fino a 48 ore) e mercati; merci max 3,5 t | https://www.comune.vicenza.it/Servizi/Permessi-temporanei-ZTL (agg. 07/06/2024) → `comune-permessi-temporanei.txt` | ufficiale |
| 12 telecamere ai varchi di uscita e 3 sulle corsie riservate entro il 2026, regole invariate | comunicato del 12/12/2025 → `comune-comunicato-telecamere-uscita-2025-12-12.txt` | ufficiale |
| Mappa con perimetro, 10 varchi d'ingresso e 20 d'uscita (legenda trascritta) | «Mappa ZTL con varchi» del 14/11/2023 → `comune-mappa-ztl-con-varchi.txt`, `mappa-ztl-varchi.jpg` | ufficiale |
| Corso Fogazzaro «NOT ACTIVE from 8pm to 9am on weekdays, never on public holidays» (al contrario della pagina italiana) | pagina inglese del Comune https://servizi2.comune.vicenza.it/utilita/restrictedtrafficzone.php, solo dal riassunto della ricerca web (host bloccato dal proxy, 403) | ufficiale, non letta |

Ospiti degli hotel: nessuna procedura nelle pagine del Comune (cercato «alberghi», «strutture ricettive», «ospiti»): pending. Patrono: non serve con 0–24.

## Host bloccati dal proxy (403, non aggirati)
servizi2.comune.vicenza.it (pagina inglese), comune.vicenza.it (senza www), opendata/dati.comune.vicenza.it, www.aimmobilita.it.

## Geometria (dalla mappa ufficiale, non disegnata a mano)
- Open data: nessun dataset ZTL di Vicenza su dati.veneto.it (6757 dataset nell'elenco CKAN, nessuno con «ztl», «traffico» o «vicenza» nel nome) né su dati.gov.it; la pagina «Dataset» del Comune non ne elenca. In OpenStreetMap (API OSM, 27/10/2026, riquadro 45.538–45.557 N, 11.528–11.560 E) nessuna relazione ZTL, nessuna strada `motor_vehicle=permit` del centro, nessuna telecamera.
- `Tools/vicenza_mappa.py`: classifica i colori della mappa ufficiale (giallo = isolati in ZTL, rosso = bordo, azzurro = fiumi, pallini blu/verdi = varchi), la aggancia alle coordinate con una similitudine che sovrappone i fiumi disegnati alle acque OSM (estratto `data/raw/geo/vicenza-centro.json`, © OpenStreetMap contributors, ODbL 1.0): scala 0,843 m/px, rotazione −1,55°, F1 fiumi 0,85; la ZTL è l'unione di isolati gialli e bordo rosso chiusa di 10 px (≈8 m) sulle strade interne; contorno semplificato a 3 m. Risultato in `data/raw/vicenza/ztl-mappa-ufficiale.geojson`. 0,41 km².
- Controllo visivo: il contorno e le strade OSM riportati sulla mappa ufficiale coincidono con il bordo rosso e con le strade disegnate.
- Controlli nel builder: piazza dei Signori e piazza delle Erbe dentro; piazzale della Stazione, viale Roma, viale Eretenio fuori; ognuno dei 10 varchi d'ingresso della legenda ha un pallino blu entro 25 m dalla sua strada OSM (abbinamento automatico) ed entro 30 m dal bordo.
- Varchi d'uscita (20 sulla mappa) non inseriti: telecamere in uscita previste entro il 2026.
