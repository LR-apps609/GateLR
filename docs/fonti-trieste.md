# Trieste: fonti della scheda ZTL (bozza)

Scheda generata da `Tools/build_trieste.py` → `data/drafts/trieste.json` (stato **draft**, **non** nell'app né nel sito).

## Perché è una bozza
- A Trieste non c'è una ZTL unica con varchi elettronici: secondo l'elenco ufficiale del Comune (stampato l'8/2/2021) ci sono 97.214 m² di aree pedonali e 17.523 m² di ZTL in tanti pezzi (tipo A, tipo B, «Elevata/Penetrazione a Valenza Pedonale»). Nessuna fonte trovata parla di telecamere: i controlli sono degli agenti.
- L'unico orario noto (ZTL tipo B «riservate dalle 0.00 alle 24.00 dei giorni feriali prevalentemente alla sosta dei residenti») è nella FAQ della Polizia Locale su `polizialocaletrieste.it`, **bloccato dal proxy (403)**: letto solo nel riassunto della ricerca web → nessuna citazione verificata (`quote: null`). Bloccato anche `backoffice-comuni.regione.fvg.it` (documenti del Comune, es. nota informativa Borgo Teresiano 2026). `www.comune.trieste.it` risponde ma è un'app Angular: i suoi PDF in `/media/files/032006/attachment/` sono scaricabili.
- Per pubblicarla: testo della FAQ o delle ordinanze 26/1990, 60/1990, 24/2016; decidere come trattare ZTL tipo A e aree pedonali (es. piazza Unità d'Italia, Cavana); geometrie migliori.

## Zone (sei ZTL «tipo B» del Borgo Teresiano)
via Trento (ord. 24/2016), via Mercadante e via Torre Bianca (26/1990), via del Lavatoio, via della Geppa, via Galatti (60/1990): `restricted`, lunedì–sabato 0–24, `freeOnHolidays: true` (feriali = lun–sab: interpretazione nei pending), `hotelCanRegister: false`, nessun varco.

| Fatto | Fonte (letta il 27/10/2026) | Tipo |
|---|---|---|
| Elenco aree pedonali e ZTL con ordinanze e superfici (tipo B: Trento 905 m², Mercadante 464, Torre Bianca 1743, Lavatoio 1078, Geppa 3044, Galatti 2418) | https://www.comune.trieste.it/media/files/032006/attachment/TRIESTE_APU_ZTL_2020.pdf → `comune-elenco-apu-ztl-2020.txt` | ufficiale, datato (2021) |
| ZTL tipo B: 0–24 nei giorni feriali, soprattutto sosta residenti; tipo A soprattutto pedoni; disabili esentati | FAQ Polizia Locale (riassunto della ricerca web) → `websearch-1-ztl-trieste.txt` | ufficiale, non letto direttamente |
| Permessi ZTL B per ditte (Borgo Teresiano e ZTL A), Ufficio Permessi via Revoltella 35 | https://www.comune.trieste.it/media/files/032006/attachment/Mod_Ditte.pdf → `comune-modulo-permessi-ztl-b.txt` | ufficiale |
| Permessi temporanei APU e ZTL non tipo B: 10 km/h, precedenza ai pedoni, itinerario più breve | https://www.comune.trieste.it/media/files/032006/attachment/APU_ZTL_Prescrizioni_wgvhn75.pdf → `comune-prescrizioni-permesso-temporaneo.txt` | ufficiale |
| Borgo Teresiano ZTL feriale 24 ore; Cavana lun–sab 7–20 con permessi per hotel | triesteprima.it; guida inglese poco affidabile | non ufficiale (non usato per le zone) |

## Geometria (non ufficiale)
- Nessun dato ZTL del Comune in open data (dati.friuliveneziagiulia.it) e nessuna relazione ZTL in OpenStreetMap.
- Strade con nome scaricate il 27/10/2026 con `Tools/fetch_osm_api.py` (riquadro 45.644–45.658 N, 13.764–13.786 E) → `data/raw/geo/trieste-centro.json` (© OpenStreetMap contributors, ODbL 1.0).
- Ogni zona è l'area coperta (`osm_geo.street_area`, celle 3 m, chiusura 8 m) dalle way della via omonima segnate `motorcar`/`motor_vehicle=permit`: strisce lungo le vie di 200–350 m², più strette delle superfici dell'elenco ufficiale (la carreggiata e i marciapiedi non ci sono).
