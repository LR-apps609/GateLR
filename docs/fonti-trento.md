# Trento: fonti della scheda ZTL

Scheda generata da `Tools/build_trento.py` → `Resources/Cities/trento.json` (stato **draft**, `reviewedByHuman: false`), nell'app tramite `manifest.json` dal 27/10/2026. Regole e citazione **verificate** sui testi ufficiali letti il **27/10/2026** e salvati in `data/raw/trento/` (URL e data in testa a ogni file).

## Zona
**Centro storico · ZTL 0–24** (`trento-ztl`, `restricted`): 0–24 tutti i giorni, `freeOnHolidays: false`, `hotelCanRegister: true`, nessun ticket, `exemptFuels: []`. La ZTL-P (pedonale, interna) e la ZTL-CS sono mostrate come un'unica zona (per un'auto senza permesso sono chiuse entrambe).

Citazione (Disciplinare ZTL 2023, art. 4, ufficiale): «Tutti gli accessi irregolari sono rilevati automaticamente, 24 ore su 24».

| Fatto | Fonte (letta il 27/10/2026) | Tipo |
|---|---|---|
| ZTL = ZTL-P + ZTL-CS; telecamere che leggono le targhe; permessi tramite Trentino Mobilità Spa | «Guida alla Ztl» https://www.comune.trento.it/Vivere-il-Comune/Guide/Guida-alla-Ztl (aggiornata 02/09/2026) → `comune-guida-ztl.txt` | ufficiale |
| Clienti di alberghi e B&B in ZTL: targa alla reception al check-in e al check-out, permesso temporaneo con entrata, uscita e sosta di 30 minuti; sosta lunga al parcheggio Ex-SIT di via Canestrini; permessi temporanei richiesti almeno 2 giorni lavorativi prima, urgenze alla Polizia Locale | https://www.comune.trento.it/Servizi/Utenti-occasionali-in-Ztl-richiesta-permessi (aggiornata 03/11/2025) → `comune-utenti-occasionali-ztl.txt` | ufficiale |
| 18 varchi (7 in entrata, 11 in uscita) con gli incroci; controllo 24 ore su 24; targa registrata obbligatoria; art. 34 clienti alberghi (accesso senza autorizzazione, targa inserita dalla reception, sosta operativa 30 minuti, via più breve); moto: niente contrassegno esposto ma serve l'autorizzazione; elettriche/ibride solo riduzioni tariffarie | Disciplinare https://www.comune.trento.it/content/download/2623/41796/file/Disciplinare_Ztl_2023_det.59-33.pdf → `disciplinare-ztl-2023-estratto.txt` (estratto) | ufficiale |
| Estensione della ZTL-CS a piazza della Mostra (dal 28/02/2023); circolazione fuori dalle fasce orarie punita come l'accesso senza autorizzazione | ordinanza 219/2023 → `ordinanza-219-2023.txt` | ufficiale |
| Elenchi delle vie della ZTL-CS e della ZTL-P | `elenco-vie-ztl-cs.txt`, `elenco-vie-ztl-p.txt` | ufficiale |
| Dataset del perimetro (CC0) | https://dati.trentino.it/dataset/zona-a-traffico-limitato-open-data → `dati-trentino-dataset-ztl.txt` | ufficiale (file non scaricabili) |

Fonti non ufficiali consultate solo per orientarsi (ricerca web): accessibilitacentristorici.it, trentotoday.it, comesiparte.it, tolltracker.eu (tutte: ZTL attiva 24 ore su 24, tutti i giorni).

## Pending (nella scheda)
Procedura hotel/B&B e parcheggio Ex-SIT; nessun ticket per visitatori; elettriche e moto non esenti; ZTL-P e ZTL-CS unite in una zona; provenienza del perimetro e dei varchi.

## Geometria
- Il perimetro ufficiale è il dataset open data del Comune (GeoJSON/SHP/KML su `gis.comune.trento.it`), ma quell'host è **bloccato dal proxy del sandbox (403)**.
- Si usa la relazione OSM **19186663** «ZTL Centro Storico» (`boundary=limited_traffic_zone`, `source=Comune di Trento`, `source:website` = pagina di download del Comune; versione 1 del 28/05/2025), scaricata il 27/10/2026 con `Tools/fetch_osm_api.py` (riquadro 46.062–46.076 N, 11.113–11.131 E) → `data/raw/geo/trento-ztl.json` (© OpenStreetMap contributors, ODbL 1.0). 0,33 km².
- Controllo con gli elenchi ufficiali: 87 vie della ZTL-CS e della ZTL-P trovate in OSM (stesso tipo e stessa ultima parola del nome), nessuna fuori dal perimetro (tolleranza 25 m); piazza della Mostra (estensione 2023) e piazza Duomo dentro; stazione FS e piazza Dante fuori.
- Varchi: i 7 varchi in entrata dell'art. 4 del Disciplinare, all'incrocio OSM delle due vie indicate (nodo in comune, altrimenti punto medio dei punti più vicini), entro 40 m dal bordo.

## Moto e scooter (1.17.1)
Nessuna esenzione: per moto e ciclomotori cambia solo l'esposizione del permesso (*"Da tale obbligo sono esclusi motocicli e ciclomotori, che devono dimostrare di essere in possesso dell'autorizzazione"*) → «Non entrare».
