# Modena: fonti della scheda ZTL

Scheda generata da `Tools/build_modena.py` → `Resources/Cities/modena.json` (stato **draft**, `reviewedByHuman: false`), nell'app tramite `manifest.json` dal 26/10/2026.
Fonti lette il **26/10/2026** e salvate in `data/raw/modena/` (testo estratto, con URL e data in testa a ogni file). Lo script si ferma se una frase citata o riassunta non c'è più parola per parola nel testo salvato.

## Zona nell'app

**Modena · ZTL Centro storico** (`modena-ztl`, `restricted`): 0–24 tutti i giorni, festivi compresi (`freeOnHolidays: false`), nessun ticket.

Citazione (Testo coordinato Ordinanza ZTL, prot. P.G. 85253 del 01/04/2020, https://www.comune.modena.it/amministrazione/documenti-e-dati/atti-normativi/ordinanze/ordinanze-a-carattere-generale/testo-coordinato-ordinanza-ztl/testo-coordinato-ordinanza-ztl/@@download/file_principale, ufficiale → `ordinanza-ztl-testo-coordinato-pg-85253-2020.txt`): punto «B) ZONA A TRAFFICO LIMITATO (ZTL) Divieto permanente di circolazione (movimento, fermata e sosta)»; «All'interno del perimetro come sopra individuato è permanentemente vietato il transito e la sosta ai veicoli non autorizzati». La DGC 115 del 10/03/2020 ha abrogato la franchigia oraria. Le fasce della sezione B6 valgono solo per carico/scarico e manutenzione autorizzati.

## Regole

| Fatto | Fonte | Tipo |
|---|---|---|
| Perimetro descritto dai viali (Martiri della Libertà, Rimembranze, Vittorio Veneto, Berengario, Fontanelli, Corso Cavour, Corso Canalgrande, Caduti in Guerra, Largo Garibaldi), esclusi; telecontrollo di tutti i varchi di accesso e uscita | ordinanza, punto B | ufficiale |
| Moto e ciclomotori senza autorizzazione (B2.1) | ordinanza | ufficiale |
| Clienti di strutture ricettive in ZTL: transito e sosta con contrassegno dell'albergatore (B2.3); dati comunicati alla Polizia Municipale entro 48 ore dall'accesso dal gestore | ordinanza; https://www.visitmodena.it/it/pianifica-il-viaggio/informazioniztl → `visitmodena-informazioni-ztl.txt` (sito turistico del Comune) | ufficiale |
| Telecamere attive 24 ore su 24 a tutti i varchi | VisitModena | ufficiale |
| Elettriche: solo «PREVIA AUTORIZZAZIONE» (B10) → `exemptFuels: []` | ordinanza | ufficiale |
| Disabili con contrassegno: senza autorizzazione, con comunicazione entro 48 ore (B2.9) | ordinanza | ufficiale |
| Pass giornalieri solo «alle stesse condizioni delle autorizzazioni permanenti» (D.1): nessun ticket per turisti | ordinanza | ufficiale |
| Corsie riservate vietate anche con permesso: via Emilia Centro (vicolo Squallore–via Torre), Corso Duomo, Piazza Roma lato nord; aree pedonali (Piazza Grande …) | ordinanza, punti A e Ater | ufficiale |
| Polizia municipale 059 20314, ztltemporaneo@comune.modena.it; modulo targhe elettriche per residenti | `websearch-2-hotel-elettriche-disabili.txt` | riassunto di ricerca |

Patrono San Geminiano (31 gennaio): con 0–24 non serve in `localHolidays`. Nessuna modifica 2026–2027 trovata.

## Geometria
Perimetro **ufficiale**: open data del Comune di Modena, dataset «Zone a traffico limitato» (catalogo Regione Emilia-Romagna su dati.gov.it, modificato il 24/10/2026), WFS `Modena:Ztl_preview` (https://geonext.comune.modena.it/geoservernext//Modena/Ztl_preview/wfs), un poligono «Centro x 2000», scaricato in GeoJSON WGS84 → `ztl_perimetro.geojson`; semplificazione 2 m, 0,75 km². Controlli: Piazza Grande e Palazzo Ducale dentro, stazione e Parco Novi Sad fuori.

## Pending
Varchi senza coordinate (nessun open data; OpenStreetMap non raggiungibile dal sandbox il 26/10/2026). Corsie riservate e aree pedonali non disegnate a parte. Moto e ciclomotori: dalla 1.17.1 `exemptVehicleTypes: ["motorcycle"]` (deroga B2: *"ai velocipedi, ciclomotori, motocicli nonché ai motoveicoli appartenenti alla categoria internazionale L5e"*).
