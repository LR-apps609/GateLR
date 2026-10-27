# Alghero: fonti della scheda ZTL

Scheda generata da `Tools/build_alghero.py` → `Resources/Cities/alghero.json` (stato **draft**, `reviewedByHuman: false`). Dal 27/10/2026 è **nell'app** (`manifest.json`) e sul sito.

## Fonti ufficiali lette (27/10/2026)
| Fatto | URL | Tipo | Letto il |
|---|---|---|---|
| **Citazione**: tutta l'area del centro storico è ZTL, divieto di circolazione e sosta «tutto l'anno» 0–8, 10:30–14:30 e 16:30–24; perimetro (Porta Mare, banchine Dogana e Garibaldi, via Catalogna, largo Larco, via Sassari, piazza Porta Terra, via XX Settembre, piazza Sulis, bastioni Colombo, Marco Polo, Pigafetta, Magellano); varchi via Simon/piazza Porta Terra e piazza Sulis; elettriche ammesse con comunicazione della targa per la «lista bianca»; disabili non residenti: giustificazione entro 72 ore; clienti delle strutture ricettive solo per carico/scarico bagagli, targa comunicata dalla struttura alla Polizia Locale | Ordinanza dirigenziale n. 4 del 07/01/2019, https://comune.alghero.ss.it/.galleries/doc-documenti/ZTL2019_Ordinanza-dirigenziale-n.-4-del-07.01.2019.pdf → `data/raw/alghero/ord-4-2019.txt` | ufficiale | 27/10/2026 |
| Stesso testo (regolamento allegato A, D.G.C. 442 del 27/12/2018) | https://comune.alghero.ss.it/.galleries/doc-documenti/ZTL2019_ALLEGATOA_NUOVOREGOLAMENTO_ZTL2018.pdf → `regolamento-ztl-2018-allegato-a.txt` | ufficiale | 27/10/2026 |
| ZTL ancora in uso nel 2025: accesso e uscita solo da Porta a Mare il 12/10/2025 (Fashion Day) | https://comune.alghero.ss.it/it/novita/notizia/Alghero-Fashion-Day/ → `comune-news-2025-10-09-fashion-day.txt` | ufficiale | 27/10/2026 |
| La ZTL è l'«area perimetrale interna alle mura» | https://comune.alghero.ss.it/it/novita/notizia/Ztl-abbonamento-speciale-per-Piazza-dei-Mercati-00001/ → `comune-news-2014-11-18-abbonamento-ztl.txt` | ufficiale | 27/10/2026 |

Nessun atto ZTL più recente trovato sul sito del Comune. Fonti non ufficiali per incrocio: accessibilitacentristorici.it (stessi orari e varchi), tyremap.com (riporta orari serali estivi diversi, non confermati: nei pending).

## Come sono modellati gli orari
- Tutti i giorni dell'anno 0–8, 10:30–14:30, 16:30–24 (`freeOnHolidays: false`). Nessuna stagione.
- Esenzione elettriche non codificata in `exemptFuels` perché richiede la registrazione della targa: nei pending.

## Geometria
- OpenStreetMap (© OpenStreetMap contributors, ODbL 1.0), scaricato il 27/10/2026 dall'API principale con `Tools/fetch_osm_api.py` e ridotto in `data/raw/geo/alghero-ztl.json`: relazione 14400850 «ZTL Centro Storico» (boundary=limited_traffic_zone, `source:url` = ordinanza 4/2019, check_date 2025-08-26), contorno di mura e bastioni; una way (1466050671) senza ruolo è inclusa nel contorno. 0,139 km².
- Varchi: nodi «device» 9919391555 (via Simon / piazza Porta Terra, relazione enforcement 14400847) e 9919391554 (piazza Sulis, relazione 14400848).
- Controlli: Cattedrale, piazza Civica e chiesa di San Francesco dentro; giardini Manno, porto e piazza Sulis lato sud fuori.

## Host bloccati dal proxy (403, non aggirati)
- `sportellotelematico.comune.alghero.ss.it` (servizi online, permessi ZTL e disabili), `alghero.trasparenza-valutazione-merito.it` (albo pretorio).

## Pending (nella scheda)
Hotel solo carico/scarico bagagli; elettriche con lista bianca e disabili entro 72 ore; ordinanza del 2019 senza atti più recenti trovati, guide con orari estivi diversi; area e varchi da OSM.
