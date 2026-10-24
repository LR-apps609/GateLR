# Firenze, Scudo Verde: fonti della scheda

Zona `firenze-scudo-verde` (kind `green`), generata da `Tools/build_firenze.py` → `Resources/Cities/firenze.json` (città in stato **draft**, `reviewedByHuman: false`). I settori A, B, O, F, G non sono cambiati.
Fonti lette il **24/10/2026** e salvate in `data/raw/scudo-verde/`.

## Stato: attivo, con multe dal 1° luglio 2025

- 13/12/2024: firmata l'ordinanza che fissa l'attivazione al 1° aprile 2025.
- 1/4/2025: varchi accesi in **pre-esercizio** (senza multe).
- Il pre-esercizio è stato prorogato due volte: prima a fine maggio (sanzioni dal 1° giugno), poi al 30 giugno.
- **Dal 1/7/2025 si prendono multe.** A metà settembre 2025 il Comune contava 1.572 violazioni.
- **Seconda fase dal 1/12/2026**: approvata dalla giunta l'11/8/2026 e confermata in Consiglio il 14/9/2026.

## Fatti → fonte

| Fatto | Fonte (letta il 24/10/2026) | File | Stato |
|---|---|---|---|
| "ZTL ambientale" protetta da varchi telematici: circa 38 km² (66% del centro abitato, 37% del comune), perimetro di 50 km, 77 porte telematiche "intorno alla città" | Comunicato del 31/03/2025: https://www.comune.firenze.it/novita/area-stampa/comunicati-stampa/domani-lattivazione-dello-scudo-verde-pre-esercizio (anche quello del 14/12/2024) | `comunicato-2025-03-31-attivazione-pre-esercizio.html`, `comunicato-2024-12-14-ordinanza-1-aprile.html` | verificato |
| Fuori dal perimetro: polo ospedaliero di Careggi, aeroporto Vespucci, grandi zone produttive e centri commerciali, direttrice Viadotto Marco Polo–Fiesole, capolinea della tramvia e parcheggi scambiatori | idem | idem | verificato |
| "in vigore h24 tutti i giorni dell'anno", "nessun pedaggio" | idem; ripetuto il 27/05/2025 | idem | verificato |
| Auto (M1) vietate in fase 1: **benzina Euro 0, diesel Euro 0–1** | Comunicato del 31/03/2025 (elenco "I veicoli interessati dal divieto") | idem | verificato |
| Sanzioni dal **1° luglio 2025** | Comunicato del 27/05/2025: https://www.comune.firenze.it/novita/area-stampa/comunicati-stampa/scudo-verde-rinviata-al-1deg-luglio-lattivazione-del-sistema ; anche la descrizione del dataset dei varchi | `comunicato-2025-05-27-sanzioni-dal-1-luglio.html`, `datigov-varchi-scudo-verde.json` | verificato |
| Fase 2 dal **1/12/2026**: auto **benzina Euro 1 e diesel Euro 2** (immatricolate prima del 1997 / del 2001); per due ruote, bus e merci regole diverse | Comunicato del 21/08/2026: https://www.comune.firenze.it/novita/area-stampa/comunicati-stampa/scudo-verde-da-dicembre-al-la-seconda-fase ; question time del 14/09/2026: https://www.comune.firenze.it/novita/area-stampa/comunicati-stampa/graziani-avs-ecolo-scudo-verde-avanzamento-e-nuove | `comunicato-2026-08-21-seconda-fase.html`, `comunicato-2026-09-14-question-time.html` | verificato (comunicati; il testo della delibera non l'abbiamo letto) |
| Esenti senza registrazione: forze armate e di polizia, Polizia Locale, CRI, Vigili del Fuoco, protezione civile con targa speciale, biciclette, ecc. | Comunicato del 31/03/2025 | idem | verificato |
| In deroga **con registrazione della targa su SAS** (https://www.serviziallastrada.it/): veicoli a **metano, GPL, bifuel**, veicoli storici con CRS, contrassegno disabili CUDE con il titolare a bordo, volontariato, servizi essenziali… | idem | idem | verificato; nell'app sono note `pending` (non c'è `exemptFuels`) |
| Chi ha un permesso ZTL del centro storico può circolare fino alla scadenza del permesso | idem | idem | verificato; nota `pending` |
| Dal 1/12/2026 "carnet" di ingressi: **3 giorni una tantum, senza registrazione, per tutti** ("rivolta principalmente a chi arriva da fuori"); 25 giorni l'anno per i residenti della Città Metropolitana e altri 25 per i residenti a Firenze, con registrazione su SAS, per tre anni; deroga per gli over 75 residenti con ISEE sotto 16.500 € | Comunicati del 21/08/2026 e del 14/09/2026 | idem | verificato; come si contano i 3 giorni → `pending` |
| Multa: "sanzione da 83 euro" | Comunicato del 20/10/2025: https://www.comune.firenze.it/novita/area-stampa/comunicati-stampa/scudo-verde-da-inizio-luglio-1572-violazioni-e-piu-della-meta (la frase riguarda i bus turistici) | `comunicato-2025-10-20-1572-violazioni.html` | **pending** per le auto |
| Auto straniere, a noleggio, di non residenti: nessuna eccezione nei testi. Non sappiamo come si controllano le targhe estere | tutti i comunicati sopra | — | **pending** |
| Festivi: nessuna pausa (h24 tutti i giorni) → `freeOnHolidays: false` | Comunicato del 31/03/2025 | — | verificato |

Le pagine `ambiente.comune.fi.it/dalle-redazioni/attivazione-scudo-verde` e il portale SAS non si raggiungono da qui (proxy). Nemmeno la delibera DG/2023/00607 e la delibera di giunta dell'11/8/2026 sono state lette.

## Come è modellato

- `windows`: tutti i giorni, 0–24. `freeOnHolidays: false`, `exemptFuels: []`, `hotelCanRegister: false`.
- `bans`:
  - benzina ≤ Euro 0 e diesel ≤ Euro 1 dal `2025-07-01`, data di inizio delle multe. Il divieto nel centro abitato è più vecchio, ma prima non c'erano varchi.
  - benzina ≤ Euro 1 e diesel ≤ Euro 2 dal `2026-12-01`.
- Il motore conta ibride e GPL come benzina. Per GPL e metano è il caso giusto quando la targa non è registrata su SAS; con la targa registrata quelle auto sono esenti, e lo dice una nota `pending`.
- Elettriche: non sono in nessun divieto, quindi entrano.
- Le regole valgono solo per le auto (M1). Moto, furgoni e bus non sono considerati.

## Geometria

**Varchi (ufficiali)**: dataset "Varchi Scudo Verde" del Comune di Firenze, CC BY 4.0.
- Pagina: https://opendata.comune.fi.it/page_dataset_show?id=varchi-scudo-verde
- GeoJSON: https://datigis.comune.fi.it/json/varchi_scudoverde.json (`varchi_scudoverde.json`)
- Il dataset ha 77 punti, tutti con `data_ini` 2025-07-01 e atto "Deliberazione n. DG/2023/00607": 73 sono `IN` e 4 sono `OUT` (096C, 095B, 079B, 071C).
- Nel JSON vanno solo i **73 varchi di ingresso**, con id `sv-<num_varco>`.

**Perimetro: c'è un dato ufficiale, ma non lo raggiungiamo da qui.**
- È il dataset "PUMS - Progetto - Scudo verde - Città Metropolitana di Firenze" (CC BY 4.0, del 21/04/2021). La descrizione dice: «Lo Scudo verde di Firenze interessa l'area racchiusa nel perimetro oggetto del presente dataset».
- Scheda: https://www.dati.gov.it/view-dataset/dataset?id=ee3c2463-5912-4b32-8802-c4966abf901d (`datigov-pums-progetto-scudo-verde.json`)
- Il dato si scarica solo come WMS/WFS da `pubblicazioni.cittametropolitana.fi.it`, che il proxy blocca. Il WMS di `tms.comune.fi.it` è bloccato anche lui.
- Il catalogo opendata del Comune non ha un dataset del perimetro (abbiamo cercato "scudo", "perimetro", "emissioni", "ambientale", "ztl", "varchi").

Per ora il perimetro viene da **OpenStreetMap**, relazione [19205738](https://www.openstreetmap.org/relation/19205738) «ZTL Scudo Verde» (`boundary=low_emission_zone`, versione 3 del 17/09/2025). Il file è `osm-relation-19205738-full.xml`, scaricato da `www.openstreetmap.org/api/0.6/relation/19205738/full`.
- Licenza: © OpenStreetMap contributors, ODbL 1.0, scritto nel campo `license` della città.
- Nel `source:url` la relazione rimanda al dataset PUMS. Nella `note` c'è scritto: «Tracciato sulla base del dataset PUMS convertito da Monte Mario; corretto percorso originario passante su edifici».
- È quindi una copia del perimetro ufficiale corretta a mano, non un poligono costruito da noi unendo i varchi.

Controlli fatti sul poligono OSM (1314 punti, semplificato a 838 con tolleranza ~8 m):
- Area: **39,0 km²**. Il Comune dice "circa 38 km²". Il bordo misura 70 km contro i 50 dichiarati, perché OSM segue le strade punto per punto.
- Varchi ufficiali: **75 su 77 stanno entro 35 m dal bordo** (mediana 6 m). Fanno eccezione 078A via della Pietra (236 m) e 039A via Etruria (268 m). Su via della Pietra nel 2026 c'è stato un «ripristino del pannello». Da verificare: nota `pending`.
- Duomo (43.7731, 11.2560): **dentro**. Santa Maria Novella e piazzale Michelangelo: dentro.
- Aeroporto di Peretola (43.8100, 11.2051): **fuori**. Careggi (43.8040, 11.2490): **fuori**. Torna con il comunicato del Comune.

`Tools/fetch_geo.py` (GitHub Actions, non lanciato da qui) ora prova a scaricare:
- il dato ufficiale PUMS via WFS → `data/raw/geo/firenze-scudo-verde-pums.geojson`;
- la relazione OSM via Overpass → `firenze-scudo-verde-osm.json`.

Se il file PUMS arriva, si confronta con OSM e, se coincide, lo si usa al posto di OSM nel builder (`scudo_verde()` in `build_firenze.py`).

## Da fare

- [ ] Leggere la delibera DG/2023/00607 (disciplinare) e la delibera di giunta dell'11/8/2026. Servono a confermare le classi Euro e a capire se le regole cambiano per le targhe estere.
- [ ] Importo della multa per le auto (art. 7 CdS) e come si usa il bonus dei 3 giorni senza registrazione.
- [ ] Perimetro ufficiale PUMS (via `fetch_geo.py`) e i due varchi lontani dal bordo (via della Pietra, via Etruria).
