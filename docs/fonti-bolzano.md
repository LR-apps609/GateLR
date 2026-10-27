# Bolzano/Bozen: fonti della scheda ZTL (bozza)

Scheda generata da `Tools/build_bolzano.py` → `data/drafts/bolzano.json` (stato **draft**, **non** nell'app né nel sito). Città bilingue: nomi e testi in italiano, tedesco e inglese; le vie hanno il nome doppio di OpenStreetMap («Via Museo / Museumstraße»).

## Perché è una bozza
Il 27/10/2026 i siti del Comune erano **bloccati dal proxy del sandbox (403)**: `www.comune.bolzano.bz.it`, `www.gemeinde.bozen.bz.it` (e `www.gemeinde.bozen.it`, che vi rimanda), `opencity.gemeinde.bozen.it`, `opencity.comune.bolzano.it`; anche `www.seab.bz.it`, `www.bolzano-bozen.it`, `www.provincia.bz.it`. Non è stato salvato nessun testo ufficiale, quindi **nessuna citazione verificata** (`quote: null`). Per pubblicarla: salvare in `data/raw/bolzano/` la guida «Accesso ZTL e sosta nel centro abitato» (o la versione tedesca) e il servizio della Stadtpolizei, mettere la frase in `QUOTE` e rilanciare il builder.

## Zona
**Centro storico · ZTL 0–24 / Altstadt · Verkehrsberuhigte Zone rund um die Uhr** (`bolzano-ztl`, `restricted`): 0–24 tutti i giorni, `freeOnHolidays: false`, `hotelCanRegister: true`, nessun ticket, `exemptFuels: []`.

| Fatto | Fonte | Tipo |
|---|---|---|
| ZTL attiva 24 ore su 24, tutti i giorni; telecamere ai varchi | guida https://www.comune.bolzano.bz.it/Vivere-il-Comune/Guide/Accesso-ZTL-e-sosta-nel-centro-abitato, solo dal riassunto della ricerca web del 27/10/2026 → `websearch-1-guida-comune-ztl.txt` | ufficiale, non letto direttamente |
| Albergo in ZTL: contattarlo in anticipo per comunicare la targa e ottenere l'autorizzazione temporanea | stessa guida (riassunto) | ufficiale, non letto direttamente |
| Permessi della Polizia Municipale / Stadtpolizei (via Galilei 23, tel. 0471 997799), da avere prima dell'ingresso; Portale ZTL con SPID/CIE/CNS | https://www.gemeinde.bozen.bz.it/Dienste/Stadtpolizei-Genehmigung-fuer-die-Einfahrt-in-die-verkehrsberuhigte-Zone-VBZ-und-in-die-Fussgaengerzone (riassunto) → `websearch-3-permesso-stadtpolizei.txt` | ufficiale, non letto direttamente |
| Nuove regole dal 01/02/2023: carico/scarico ≤ 3,5 t lun–sab 6–10:30 (non festivi infrasettimanali), elettrici/ibridi/idrogeno anche fino alle 11 e 14:30–16; vie chiuse al transito (Erbsengasse, Waaggasse, Pfarrgasse, parte del Waltherplatz; Obstplatz, Museumstraße e parte della Laubengasse 10:30–20) | comunicato https://opencity.gemeinde.bozen.it/Aktuelles/Pressemitteilungen/Neue-Park-und-Verkehrsregeln-fuer-die-Altstadt (riassunto) → `websearch-2-nuove-regole-2023.txt` | ufficiale, non letto direttamente |
| Comunicazione entro 48 ore (targa, data, ora) per gli ospiti; multa circa 80 € | accessibilitacentristorici.it; fss.bz.it (2014) | non ufficiale (nei pending: «confermato solo da …») |

## Pending (nella scheda, it/de/en)
Regole solo da riassunti della ricerca web; procedura hotel e 48 ore; carico/scarico e veicoli elettrici; vie chiuse anche con permesso; perimetro OSM e multa.

## Geometria (non ufficiale, da OpenStreetMap)
- Nessun perimetro in open data (dati.retecivica.bz.it: nessun dataset ZTL; il geoportale del Comune è bloccato).
- Relazione OSM **19584710** «Zona Traffico Limitato Centro storico / Verkehrsberuhigte Zone Altstadt» (`boundary=limited_traffic_zone`, `type=enforcement`), scaricata il 27/10/2026 con `Tools/fetch_osm_api.py` (riquadro 46.493–46.504 N, 11.347–11.364 E) → `data/raw/geo/bolzano-ztl.json` (© OpenStreetMap contributors, ODbL 1.0).
- Le sue 52 way (33 «outer», 19 senza ruolo) sono le strade della ZTL e non formano un contorno chiuso: il perimetro è l'area coperta da quelle strade (`osm_geo.street_area`, chiusura 60 m, semplificazione 4 m), 0,15 km²; il bordo è approssimato e include brevi tratti delle vie d'accesso.
- Varchi: le 13 telecamere «device» della relazione (9 dopo aver unito le coppie a meno di 15 m), con il nome della via OSM più vicina.
- Controlli: piazza Walther e piazza Erbe dentro, stazione fuori, telecamere entro 80 m dal bordo.
