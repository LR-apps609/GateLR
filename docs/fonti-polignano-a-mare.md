# Polignano a Mare: fonti della scheda ZTL

Scheda generata da `Tools/build_polignano_a_mare.py` → `Resources/Cities/polignano-a-mare.json` (stato **draft**), pubblicata come città con **fonte non ufficiale** (approvato dal titolare): la zona ha `source.official = false` e `source.unofficialSource` = accessibilitacentristorici.it (app 1.16.2); `Tools/build_manifest.py` la mette in `unofficialCities`, che le app fino alla 1.16.1 non leggono.

## Zona
**Borgo antico · area pedonale** (APU): tutti i giorni, 0–24, festivi compresi. Varco: Arco Marchesale. Hotel: nessun accesso previsto per i clienti. Disabili: solo feriali, previo accreditamento. Moto e ciclomotori vietati. Nessuna sanatoria a posteriori.

## Fonti
| Fatto | URL | Tipo | Letto il |
|---|---|---|---|
| APU «tra l'Arco Marchesale e Piazza Santa Maria delle Grazie inclusa, sino a via Tritone incrocio con via Narciso»; «attiva tutti i giorni 24 ore su 24» (**citazione**); varco all'Arco Marchesale; veicoli e soggetti ammessi; hotel; disabili; nessuna sanatoria | https://www.accessibilitacentristorici.it/ztl/puglia/polignano-a-mare.html (dalla mappa https://www.accessibilitacentristorici.it/ztl/puglia/polignano-a-mare/mappa) → `data/raw/polignano-a-mare/accessibilitacentristorici-polignano.txt`; «Data aggiornamento: 04/10/2018» | **non ufficiale** (sito privato di servizi per i permessi) | 27/10/2026 |
| Ordinanza n. 207/2018 (prot. 16681, albo PAP-00966-2018, 14–29/05/2018): APU permanente 1/1–31/12, 24 ore (D.G.C. 45/2017 e 56/2018); deroghe; carico/scarico feriali 8–10; residenti 9–10 (e 16–17 d'inverno); disabili solo feriali | https://www.accessibilitacentristorici.it/ufficiali/ordinanze/Polignano_a_mare_ordinanza_PAP-00966-2018.pdf → `ordinanza-207-2018.txt` | atto del Comune, ma **copia ospitata dal sito non ufficiale** (non trovata sul sito del Comune) | 27/10/2026 |
| Pagina «ZTL» dell'argomento Trasporto pubblico (nessun contenuto sugli orari) e informativa privacy «Gestione ZTL» | https://www.comune.polignanoamare.ba.it/Argomenti/Trasporto-pubblico/ZTL ; https://www.comune.polignanoamare.ba.it/Privacy/Informativa-Privacy-in-materia-di-protezione-dei-dati-personali-per-la-Gestione-ZTL-Zone-a-Traffico-Limitato | ufficiale (senza orari) | 27/10/2026 |
| Incrocio: guida tyremap.com (accesso limitato quasi 24 ore; dice che gli ospiti degli hotel si registrano al check-in, in contrasto con il sito principale) | https://tyremap.com/it/emission-zones/polignano-a-mare/ (risultato di ricerca) | non ufficiale | 27/10/2026 |

OpenStreetMap: nessuna relazione ZTL/APU, nessun tag `*:conditional` nel borgo antico.

## Pending
- «confermato solo da accessibilitacentristorici.it» (pagina del 2018; ordinanza del 2018 non trovata sul sito del Comune; possibili modifiche successive non verificate).
- Ospiti degli hotel: il sito principale dice nessun accesso; tyremap.com dice registrazione al check-in → `hotelCanRegister: false`.

## Geometria
- OpenStreetMap (© OpenStreetMap contributors, ODbL 1.0), API principale con `Tools/fetch_osm_api.py`, 27/10/2026, bbox 40.992–41.000 N, 17.213–17.226 E, ridotto in `data/raw/geo/polignano-a-mare-ztl.json`. **La mappa del sito non ufficiale non è usata.**
- Area (`osm_geo.street_area`, celle 5 m, chiusura 25 m, 0,020 km²): le strade OSM con nome del borgo antico comprese tra l'Arco Marchesale (way 166622037) e piazza Santa Maria delle Grazie (way 103204028), cioè a nord della linea che unisce i due luoghi (33 m di margine verso sud) e tra le loro longitudini, escluse via Muraglia, piazza Garibaldi e le strade fuori dal borgo; più via Tritone (way 58523641) fino a via Narciso.
- Varco: centro della way «Arco Marchesale».
- Controlli: piazza Vittorio Emanuele II, Chiesa Matrice, Torre dell'Orologio, piazza Santa Maria delle Grazie dentro; piazza Garibaldi, piazza Aldo Moro, Lama Monachile, via Narciso (tratto sud) fuori.

## Moto e scooter (1.17.1)
Nessuna esenzione: *"Il divieto al transito nella APU di Polignano a Mare è valido per ogni tipologia di veicolo e pertanto ciclomotori e motoveicoli non possono eccedere se non espressamente autorizzati."* → «Non entrare».
