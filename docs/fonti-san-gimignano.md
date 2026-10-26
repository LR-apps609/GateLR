# San Gimignano: fonti della scheda ZTL

Scheda generata da `Tools/build_san_gimignano.py` → `Resources/Cities/san-gimignano.json` (stato **draft**, `reviewedByHuman: false`).
Fonti lette il **26/10/2026** e salvate in `data/raw/san-gimignano/`. Il builder controlla che ogni frase citata o riassunta ci sia davvero nei file salvati (si ferma se ne manca una) e fa i controlli di plausibilità sul perimetro.

I siti del Comune (`comune.sangimignano.si.it`, `visualizzatore.comune.sangimignano.si.it`, `ztl.comune.sangimignano.si.it`, allegati su `*.municipiumapp.it`) non sono raggiungibili da qui: sono stati scaricati con il workflow «Scarica pagine» (rami `pagine-san-gimignano-1`, `-2`, `-3`). I PDF sono salvati come testo (`pdftotext -layout`); la planimetria e il Disciplinare anche come PDF. Il portale ZTL è un'app Angular senza testo nella pagina.

## Zona

| Zona (id) | Chiusa a chi non è autorizzato | Tipo |
|---|---|---|
| Borgo murato · ZTL Centro storico (`sgm-ztl`): tutto il centro dentro le mura (sito UNESCO), con l'Antiporta di San Giovanni | sempre, tranne lun–sab (feriali) 5:30–9:30; il giovedì (mercato) e nei giorni di fiera 5:30–8:30; domenica e festivi tutto il giorno | restricted |

Fasce nel JSON: domenica 0–24; lun, mar, mer, ven, sab 0:00–5:30 e 9:30–24:00; giovedì 0:00–5:30 e 8:30–24:00; in più 8:30–9:30 lun–sab il 31/1, il 12/3, il 29/8 e il lunedì tra il 2 e l'8 agosto (lunedì dopo la prima domenica di agosto). `freeOnHolidays: false`, `holidaysAsSunday: true`, nessun `localHolidays` (vedi sotto), `hotelCanRegister: true`, `exemptFuels: []`, nessun `ticket`.

## Fatti → fonte

Tutte le fonti sotto sono **ufficiali** (Comune di San Gimignano), lette il 26/10/2026, salvo dove indicato.

| Fatto | Fonte | File |
|---|---|---|
| "La ZTL ha validità tutti i giorni ad eccezione dei giorni feriali nell'orario 05:30/09:30, salvo il giovedì con orario 05:30/08:30, nei giorni di fiere e per particolari esigenze o per particolari periodi dell'anno." (citazione della scheda) | Disciplinare per il rilascio delle autorizzazioni di accesso e circolazione nella ZTL, ai sensi della DGC n. 42 del 12/03/2026: https://visualizzatore.comune.sangimignano.si.it/AttiVisualizzatore/download/allegato/1919896?fId=1931869&sbustato=true | `disciplinare-ztl-dgc-42-2026.pdf/.txt` |
| Perimetro: area circoscritta da Antiporta San Giovanni (da Viale Roma/Piazzale Martiri Montemaggio), via Santa Caterina e via Quercecchio (da Viale dei Fossi), via di Bagnaia (dalla rotatoria); assetto dall'ordinanza n. 15 del 16/04/1992 | idem | idem |
| 6 varchi: Porta San Giovanni, Bonda/Piandornella, Via Santa Caterina, Via di Quercecchio, Porta San Matteo, Via di Bagnaia | idem; comunicato stampa n. 91 del 27/04/2026; brochure aprile 2026 | idem, `comunicato-27-04-2026.txt`, `brochure-ztl-aprile-2026.txt` |
| Sensi unici: via San Giovanni verso piazza della Cisterna, via San Matteo verso Porta San Matteo, via Santa Caterina verso Viale dei Fossi, via Quercecchio dal Viale dei Fossi, via Bonda a doppio senso | Disciplinare | idem |
| Senso dei varchi: 2 solo entrata (Porta San Giovanni, Via di Quercecchio), 2 solo uscita (Via Santa Caterina, Porta San Matteo), 2 in entrambi (Bonda/Piandornella, Via di Bagnaia) | **non ufficiale**: CityNext, 25/06/2025, https://citynext.it/2025/06/25/toscana-san-gimignano-potenzia-la-ztl-ecco-cosa-cambia/ (coincide con i sensi unici del Disciplinare) | `citynext-2025-06-25.html` |
| Limite 30 km/h; vietati autotreni, autobus, camper e caravan, autocarri oltre 60 q | Disciplinare | idem |
| Videocontrollo "attivo generalmente tutti i giorni dalle 9.30 alle ore 5.30 del giorno dopo, salvo diversa disposizione della Giunta" | Comunicato stampa n. 91 del 27/04/2026: https://san-gimignano-api.cloud.municipiumapp.it/s3/6203/allegati/ufficio-stampa/cs-nuova-ztl-da-1-maggio.pdf | `comunicato-27-04-2026.txt` |
| Brochure: accessi videocontrollati "attivi generalmente tutti i giorni 24 ore su 24, salvo diverse disposizioni previste dal disciplinare" (in contrasto col comunicato → `pending`) | Brochure di sintesi, aprile 2026: https://cloud-ita.municipiumapp.it/s3/6203/allegati/polizia-municipale/nuova-ztl/brochure-ztl_aprile-2026.pdf | `brochure-ztl-aprile-2026.txt` |
| Nuova ZTL a regime dal 1° maggio 2026 (fase transitoria finita il 30/04/2026); link a portale, brochure, Disciplinare, planimetria, ordinanza 65/2026; email ztl@comune.sangimignano.si.it; Polizia Municipale via di Fugnano 20/B, tel. 0577 990346 | Notizia del Comune: https://comune.sangimignano.si.it/it/news/ztl-centro-storico-di-san-gimignano | `notizia-ztl-centro-storico.html` |
| Ordinanza (Determina) n. 65 del 30/04/2026: "Attivazione dei varchi … termine fase di pre-esercizio e avvio fase ordinaria" (il testo è un allegato .p7m firmato, non letto) | https://visualizzatore.comune.sangimignano.si.it/AttiVisualizzatore/visualizza/determina/1946902 | `ordinanza-65-2026.html` |
| Strutture ricettive: obbligo di avvisare gli ospiti e di registrare prima le targhe sul portale della Polizia Locale; ospiti liberi 5:30–9:30; 15:00–20:00 accesso (solo fermata, non sosta) alle vie secondarie, via del Castello e piazza Cisterna con registrazione preventiva; ingressi 20:00–5:30 registrabili nelle 24 ore successive; con almeno 5 notti un ingresso in più al giorno; vie principali chiuse giovedì dopo le 8:30 e nei giorni di fiera fino alle 20 | Disciplinare, «Strutture ricettive turistiche»; brochure p. 15 | idem |
| Disabili (art. 188 CdS, anche di altri comuni): senza limiti di orario, targa da inserire entro 48 ore dall'accesso; adesione alla piattaforma CUDE dal 18/12/2025 | Disciplinare | idem |
| Piazza delle Erbe pedonale nei festivi dal 1/6 al 30/9, ore 9–19 (non nel JSON: manca il perimetro) | Disciplinare | idem |
| Giorni di fiera: 31 gennaio, 12 marzo, lunedì dopo la prima domenica di agosto, 29 agosto (nella parte sugli ospiti una volta «31 MARZO», refuso probabile) | Disciplinare; brochure | idem |
| Sospensione dei varchi decisa dalla Giunta per eventi, lavori, guasti | Disciplinare | idem |
| Parcheggi fuori dalle mura: P1 Giubileo, P2 Montemaggio, P3 e P4 Bagnaia | Comunicato Tirreno-Adriatico (10/03/2026): https://san-gimignano-api.cloud.municipiumapp.it/s3/6203/allegati/ufficio-stampa/comunicato-stampa-con-info-utili-per-arrivo-tappa-tirreno-adriatico_10-marzo-2026.pdf; pagina abbonamenti: https://www.comune.sangimignano.si.it/it/page/parcheggi-auto-abbonamenti-soggetti-non-residenti | `comunicato-tirreno-adriatico-10-03-2026.txt`, `parcheggi-abbonamenti-non-residenti.html` |
| Lavori a Porta San Giovanni: dal 17/8 al 22/11/2026 chiusa parte dell'area pedonale davanti alla porta (ord. 109/2026); 24–27/8 notte divieto di transito (ord. 108/2026, già passata) | https://comune.sangimignano.si.it/it/news/lavori-di-restauro-della-porta-san-giovanni-modifiche-alla-viabilita | `notizia-restauro-porta-san-giovanni.html` |
| Regole del 2025 (fase sperimentale): ZTL "0:00/24:00", ospiti liberi 7:00–9:30 — superate dal Disciplinare 2026 | Disciplinare 2025: https://visualizzatore.comune.sangimignano.si.it/AttiVisualizzatore/download/allegato/1774873?fId=1777485&sbustato=true | `disciplinare-ztl-2025-sperimentale.txt` |
| Riassunto giornalistico della nuova ZTL (orari ospiti 15–20, 5:30–9:30, 5 notti) | **non ufficiale**: CityNext 28/04/2026, Valdelsa.net 27/04/2026 | `citynext-2026-04-28.html`, `valdelsa-2026-04-27.html` |

## In sospeso (`pending` nella scheda)

- Orari: Disciplinare (ZTL tranne feriali 5:30–9:30) contro comunicato (telecamere 9:30–5:30 ogni giorno) contro brochure (24 ore su 24). Da chiarire con la Polizia Locale se nella fascia 5:30–9:30 può entrare qualunque visitatore o solo residenti e ospiti delle strutture.
- Patroni: il 31 gennaio (San Gimignano/Geminiano) e il 12 marzo (Santa Fina) nel Disciplinare sono **giorni di fiera**, elencati a parte rispetto ai festivi: non sono in `localHolidays` (sarebbe "chiusa tutto il giorno"); sono modellati come fiere (fascia libera fino alle 8:30). Nessuna fonte ufficiale trovata che li dichiari festa comunale.
- Multa: importo non pubblicato dal Comune (art. 7 CdS). Fonti non ufficiali (tyremap.com) indicano 83–332 €: non usate.
- Tariffe dei parcheggi per i visitatori: solo su siti non ufficiali, non usate.
- Senso dei varchi: confermato solo da CityNext.

## Geometria (planimetria ufficiale + OpenStreetMap, ODbL)

- Il Comune non pubblica dati aperti della ZTL e in OpenStreetMap non c'è una relazione della ZTL di San Gimignano. Il perimetro e i varchi vengono dalla **planimetria ufficiale** «Cartografia di inquadramento generale per la realizzazione del sistema di controllo degli accessi alla zona traffico limitato» (Sismic Sistemi, QGIS, scala 1:2000, base DBTGR10k Regione Toscana, EPSG:3003): https://cloud-ita.municipiumapp.it/s3/6203/allegati/polizia-municipale/nuova-ztl/ztl-planimetria.pdf (`ztl-planimetria.pdf`). Il PDF contiene solo un'immagine, senza coordinate.
- `Tools/sangimignano_mappa.py` (niente disegnato a mano): gli edifici grigi della mappa sono agganciati agli edifici OSM (`data/raw/geo/san-gimignano-buildings.json`, Overpass, 26/10/2026) con rotazione, scala e traslazione (correlazione FFT): risultato correlazione 0,736, rotazione −1,5°, 0,337 m/pixel (scala nominale 0,339). L'area chiusa dalla linea blu «ZTL» che contiene piazza della Cisterna diventa il perimetro (0,218 km²); le scritte nere sopra la linea contano come linea; a est la linea esce dal riquadro all'incrocio via Bonda / via Porta Pisana e lì l'area è chiusa dal bordo della mappa. I 6 cerchi «Varco ZTL» diventano coordinate, numerati come sulla mappa (1 Porta San Giovanni, 2 Bonda/Piandornella, 3 Via Santa Caterina, 4 Via di Quercecchio, 5 Porta San Matteo, 6 Via di Bagnaia). Risultato: `data/raw/san-gimignano/ztl-mappa-ufficiale.json`.
- Verifica dell'aggancio: il varco 1 cade a ~3 m dalla Porta San Giovanni di OSM (way 949363396), il 5 a ~2 m dalla Porta San Matteo (way 949389235), il 4 a ~9 m dalla Porta Quercecchio (way 1203444599).
- Controlli nel builder: piazza della Cisterna (centro OSM 43,4674, 11,0437 e punto 43,4677, 11,0432), via San Matteo e piazza Sant'Agostino dentro; parcheggi P1 Giubileo, P2 Montemaggio, P3 Bagnaia Superiore, P4 Bagnaia Inferiore (OSM) fuori (a 419, 74, 32 e 76 m dal bordo); ogni varco a meno di 15 m dal perimetro; area tra 0,15 e 0,30 km².
- Dati OSM (`data/raw/geo/san-gimignano-osm.json`: strade, mura, porte, parcheggi, telecamere) © OpenStreetMap contributors, ODbL 1.0.
