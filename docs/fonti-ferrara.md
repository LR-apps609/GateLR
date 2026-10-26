# Ferrara: fonti della scheda ZTL

Scheda generata da `Tools/build_ferrara.py` → `Resources/Cities/ferrara.json` (stato **draft**, `reviewedByHuman: false`), nell'app tramite `manifest.json` dal 26/10/2026.
Fonti lette il **26/10/2026** e salvate in `data/raw/ferrara/` (testo estratto, con URL e data in testa a ogni file). Lo script si ferma se una frase citata o riassunta non c'è più parola per parola nel testo salvato.

## Zone nell'app (11 perimetri ufficiali)

Perimetri: open data del Comune di Ferrara, dataset «Zone a traffico limitato (ZTL esistente)» (catalogo Regione Emilia-Romagna su dati.gov.it, modificato il 24/10/2026), WFS `Ferrara:ZTL_esistente_preview` su https://sit.comune.fe.it/geoserverckan/Ferrara/ZTL_esistente_preview/wfs, scaricato in GeoJSON WGS84 → `ztl_perimetro.geojson` (ufficiale). 11 poligoni con campo `NOME`: ZTL A, ZTL A Garibaldi (2), ZTL B (3), ZTL B Medievale, ZTL C (2, uno di 500 m²), ZTL D CERTOSA, ZTL DUOMO. Ogni poligono è una zona; le descrizioni dopo «·» sono nostre. Semplificazione 2 m.

| Zone | Tipo | Orario usato | Ticket |
|---|---|---|---|
| A, A Garibaldi, B, B Medievale, C, D Certosa | `pass` | 0–24 tutti i giorni, festivi compresi | 20 € al giorno, prima di entrare (`beforeEntry`) |
| Duomo | `restricted` | 0–24 tutti i giorni | nessuno: solo permesso specifico |

Citazione delle zone A–D (pagina «Sportello permessi ZTL, sosta e Mi Muovo Elettrico», https://www.comune.ferrara.it/it/b/58980/sportello-permessi-ztl-permessi-sosta-mimuovoelettrico, ufficiale): «Il centro storico di Ferrara è suddiviso in 4 Zone a Traffico Limitato (A, B, C, D) dotate di varchi per il controllo elettronico dei transiti veicolari e indicate da apposita segnaletica verticale presente in loco. Per accedere alla ZTL occorre essere preventivamente dotati di Permesso ZTL rilasciato dal Centro Unico Permessi.»

Citazione della ZTL Duomo (pagina «Permessi ZTL Giornalieri e Abbonamenti», https://www.comune.ferrara.it/b/17343/permessi-ztl-giornalieri-e-abbonamenti, ufficiale): «L'accesso alla ZTL Duomo è consentito esclusivamente ai veicoli autorizzati da specifico permesso ZTL (rivolgersi preventivamente al Centro Unico Permessi che rilascerà l'autorizzazione, se sussistono i requisiti).» La stessa pagina elenca le vie della ZTL Duomo; Piazza Trento Trieste (lati sud ed est), Piazzetta Gramsci e un tratto di via San Romano solo 6–11 (O.S. 17153/2016): nei pending.

**Orario 0–24**: nessuna pagina del Comune scrive un orario. Si deduce da: (1) «Per accedere alla ZTL occorre essere preventivamente dotati di Permesso ZTL» senza limiti di orario; (2) il Regolamento divide i permessi degli operatori in fasce F1 06–11, F2 11–15, F3 15–19, F4 19–24, «F5 24.00 – 06.00 (gratuita)» (art. 11), cioè serve un'autorizzazione anche di notte; (3) le guide non ufficiali (accessibilitacentristorici.it, tolltracker.eu: «attiva tutti i giorni dell'anno 24 ore su 24», `websearch-1`/`websearch-5`). Scritto nei pending.

## Regole

| Fatto | Fonte | Tipo |
|---|---|---|
| Regolamento ZTL, aree pedonali e settori, DCC P.G. 52201/2022 del 16/05/2022 | https://www.comune.ferrara.it/static/d3/13/ea/d36133eac821d78bec5fd1f4d17c5aa3.pdf → `regolamento-ztl-dcc-52201-2022.txt` | ufficiale |
| Permesso giornaliero «A tutti coloro che debbano accedere alla ZTL saltuariamente», «singolo ingresso (20€/giorno)», «Gli accessi giornalieri alla ZTL vanno acquistati prima di effettuare l'accesso», online su INES Cloud (esclusi ZTL Duomo e veicoli > 3,5 t) o allo sportello | pagina giornalieri → `comune-permessi-ztl-giornalieri.txt` | ufficiale |
| Titoli giornalieri per «utenti che non appartengono a nessuna categoria», tariffa «compresa tra 20 € e 30 € al giorno» | Regolamento art. 18 | ufficiale |
| Ospiti di strutture in ZTL: carico/scarico bagagli o sosta nella struttura, targa alla reception; l'hotel inserisce i dati «entro 48 (quarantotto) ore dall'arrivo del cliente», altrimenti multa al cliente; sosta su strada max 30 minuti | https://www.comune.ferrara.it/it/b/57142/casi-particolari → `comune-casi-particolari.txt`; Regolamento art. 13 punto 9 | ufficiale |
| Elettriche: «che hanno titolo per l'accesso» circolano gratis senza limiti di orario «con regolare autorizzazione» → non esenti (`exemptFuels: []`) | Regolamento art. 5.2 | ufficiale |
| Disabili saltuari: targa e varchi al Centro Unico Permessi entro 48 ore | Regolamento art. 16 | ufficiale |
| Centro Unico Permessi via Marconi 41, lun–ven 7:30–12, tel. 0532 418890 (11–13) | `comune-centro-unico-permessi.txt` | ufficiale |
| Nuovi varchi via F. del Cossa e Largo Castello, fine lavori entro 31/03/2027 | Estense (`websearch-5`) | non ufficiale |

Festivi: con 0–24 `freeOnHolidays: false`; il patrono (San Giorgio, 23 aprile) non serve in `localHolidays`.

## Controlli
Piazza Cattedrale dentro la ZTL Duomo, Certosa dentro la ZTL D, via delle Volte dentro la B Medievale, Casa dell'Ariosto dentro la A; stazione e Castello Estense (strade corridoio) fuori da tutte. Superficie totale 1,27 km².

## Pending
Varchi senza coordinate: OpenStreetMap (Overpass e API) non era raggiungibile dal sandbox il 26/10/2026 e il Comune non pubblica i varchi in open data. Orario 0–24 dedotto (sopra). Fasce 6–11 di parte della ZTL Duomo non modellate.
