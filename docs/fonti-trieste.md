# Trieste: fonti della scheda ZTL

Scheda generata da `Tools/build_trieste.py` → `Resources/Cities/trieste.json` (nell'app e nel sito, `reviewedByHuman: false`).

A Trieste non c'è una ZTL unica con varchi elettronici: secondo l'elenco ufficiale del Comune (stampato l'8/2/2021) ci sono 97.214 m² di aree pedonali e 17.523 m² di ZTL in tanti pezzi (tipo A, tipo B, «Elevata/Penetrazione a Valenza Pedonale»). Nessuna fonte parla di telecamere: i controlli sono degli agenti. GateLR pubblica le sei ZTL **tipo B** del Borgo Teresiano, le uniche con un orario ufficiale.

Il 27/10/2026 `polizialocaletrieste.it` (senza `www`) e `backoffice-comuni.regione.fvg.it` erano raggiungibili; `www.polizialocaletrieste.it` dà ancora 403 dal proxy. `www.comune.trieste.it` è un'app Angular: la pagina «ZTL e Aree Pedonali» non ha testo leggibile senza JavaScript (non letta).

## Zone (sei ZTL «tipo B» del Borgo Teresiano)
via Trento (ord. 24/2016), via Mercadante e via Torre Bianca (26/1990), via del Lavatoio, via della Geppa, via Galatti (60/1990): `restricted`, lunedì–sabato 0–24, `freeOnHolidays: true` (feriali = lun–sab: interpretazione nei pending), `hotelCanRegister: false`, nessun varco, nessun ticket.

Citazione verificata (FAQ della Polizia Locale): «di tipo B (riservate dalle 0.00 alle 24.00 dei giorni feriali prevalentemente alla sosta dei residenti)».

| Fatto | Fonte (letta il 27/10/2026) | Tipo |
|---|---|---|
| ZTL tipo A riservate prevalentemente ai pedoni; tipo B riservate 0–24 nei giorni feriali prevalentemente alla sosta dei residenti; permesso dal portale del Comune; contrassegno disabili: nessuna autorizzazione | FAQ «Come posso accedere a una ZTL» (agg. 9/4/2024) https://polizialocaletrieste.it/domande_frequenti/come-posso-accedere-a-una-ztl-zona-a-traffico-limitato-del-comune-di-trieste/ → `polizialocale-faq-accesso-ztl.txt` | ufficiale |
| ZTL tipo B del Borgo Teresiano in vigore nel 2026 (ord. 6°-90-17/183 del 04/10/1990, elenco vie al punto A.8); permessi ditte 42 € + bolli, Ufficio Permessi via Revoltella 35, tel. 040 6757706 | «Nota informativa ditte/imprese Borgo Teresiano» rev. 2026 https://backoffice-comuni.regione.fvg.it/media/files/md/032006/informativa_ditte_BT_2026.pdf → `comune-nota-ditte-borgo-teresiano-2026.txt` | ufficiale |
| Elenco aree pedonali e ZTL con ordinanze e superfici (tipo B: Trento 905 m², Mercadante 464, Torre Bianca 1743, Lavatoio 1078, Geppa 3044, Galatti 2418) | https://www.comune.trieste.it/media/files/032006/attachment/TRIESTE_APU_ZTL_2020.pdf → `comune-elenco-apu-ztl-2020.txt` | ufficiale, datato (2021) |
| Permessi ZTL B per ditte (Borgo Teresiano e ZTL A) | https://www.comune.trieste.it/media/files/032006/attachment/Mod_Ditte.pdf → `comune-modulo-permessi-ztl-b.txt` | ufficiale |
| Permessi temporanei APU e ZTL non tipo B: 10 km/h, precedenza ai pedoni, itinerario più breve | https://www.comune.trieste.it/media/files/032006/attachment/APU_ZTL_Prescrizioni_wgvhn75.pdf → `comune-prescrizioni-permesso-temporaneo.txt` | ufficiale |
| Borgo Teresiano ZTL feriale 24 ore; Cavana lun–sab 7–20 con permessi per hotel | triesteprima.it; guida inglese poco affidabile | non ufficiale (non usato) |

## Pending (nella scheda, it/de/en)
Sabato considerato feriale (il Comune non lo precisa); nessuna telecamera nota; ZTL tipo A e aree pedonali non in GateLR (nessun orario ufficiale); nessun permesso per visitatori o hotel; geometria da OSM allargata alle superfici ufficiali.

## Geometria (OSM controllata con le superfici ufficiali)
- Nessun dato ZTL del Comune in open data (dati.friuliveneziagiulia.it) e nessuna relazione ZTL in OpenStreetMap.
- Strade scaricate il 27/10/2026 con `Tools/fetch_osm_api.py` (riquadro 45.644–45.658 N, 13.764–13.786 E) → `data/raw/geo/trieste-centro.json` (© OpenStreetMap contributors, ODbL 1.0).
- Ogni zona è il tratto della via omonima segnato in OSM `motorcar`/`motor_vehicle=permit`, allargato (shapely, estremità piatte) a una striscia con la **superficie dell'elenco ufficiale**: larghezza = superficie / lunghezza. Le larghezze risultano 9,0–12,0 m per tutte e sei (Trento 9,4; Mercadante 9,0; Torre Bianca 9,8; Lavatoio 12,0; Geppa 9,9; Galatti 9,7), cioè carreggiata più marciapiedi: è il controllo che i tratti OSM corrispondono alle ZTL ufficiali (il builder si ferma se una larghezza esce da 8–13 m).
- Controlli nel builder: il punto centrale di ogni tratto OSM dentro la sua zona; piazza Unità d'Italia e stazione centrale fuori da tutte le zone.
