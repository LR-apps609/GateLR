# Lecce: fonti della scheda ZTL

Scheda generata da `Tools/build_lecce.py` → `Resources/Cities/lecce.json` (stato **draft**, `reviewedByHuman: false`). Dal 27/10/2026 è **nell'app** (`manifest.json`), con perimetro da OpenStreetMap e varchi dell'ordinanza 2069/2025.

## Accesso ai siti
www.comune.lecce.it invia il proprio certificato senza l'intermedio «Telecom Italia Trust Technologies RSA OV SSL CA 2». L'intermedio (SKI D2:2C:F4:5D:87:F3:25:90:5C:E5:B7:99:17:B4:D5:D1:40:10:E5:39, emesso da Sectigo Public Server Authentication Root R46) è stato scaricato da crt.sh (id 22292849054), verificato con `openssl verify` contro le radici di sistema (OK, e OK anche il certificato del sito) e aggiunto in un file CA nella scratchpad: la verifica TLS non è mai stata disattivata. Testi letti il 27/10/2026 e salvati in `data/raw/lecce/` (pdftotext per i PDF); lo script ricontrolla ogni frase usata.

## Zona
**ZTL del centro storico** (dentro le mura), una zona `restricted` a orario variabile. Le aree pedonali interne (piazza Sant'Oronzo ecc.) non sono disegnate a parte.

## Fatti → fonte (tutte ufficiali tranne dove indicato)

| Fatto | Fonte | File |
|---|---|---|
| **Citazione**: varchi spenti 10–13 e 16:30–20 nei giorni feriali, area inaccessibile la domenica e nei festivi, varco di Porta Napoli vietato H24 tutti i giorni (dal 01/08/2025, delibera GC 280 del 10/07/2025) | comunicato 17/07/2025, https://www.comune.lecce.it/news/dettaglio/2025/07/17/modifiche-ztl-nuove-ordinanze | `comune-news-2025-07-17-modifiche-ztl.txt` |
| Feriali = lunedì–sabato («nei giorni feriali - dal lunedì al sabato -», carico/scarico 5:30–9:30 e 15–16; festivi 6–9:30) | idem; ordinanza 1689/2025 | idem, `ord-1689-2025.txt` |
| Ordinanza 1679 del 16/07/2025: «lato destro di Porta Napoli varco di ingresso … ZTL 0 – 24»; fasce d'accesso feriali 10–13 e 16:30–20, festivi «Accesso non consentito» | PDF ordinanza | `ord-1679-2025.txt` |
| **Varchi H24 (dubbio risolto)**: ordinanza 2069 del 09/09/2025, tabella di 18 varchi: H24 = via Trinchese/viale XXV Luglio (ingresso/uscita), via dei Mocenigo/viale XXV Luglio (uscita), via Biccari/viale XXV Luglio (ingresso/uscita), Porta Napoli/piazza Rizzo (ingresso); tutti gli altri a orario variabile | PDF ordinanza | `ord-2069-2025.txt` |
| Delibera del 11/03/2026: ingresso h24 via Bernardini, via Cairoli, uscita Porta Rudiae; via Brancaccio h24; via Marco Aurelio fuori dalla ZTL. La pagina ufficiale dei permessi elenca come ordinanze vigenti solo 1679/2025, 2069/2025, 2070/2023, 65/2021 e 1689/2025: **nessuna ordinanza attuativa** pubblicata → in pending | comunicato 12/03/2026; pagina permessi | `comune-news-2026-03-12-…`, `comune-permessi-ztl.txt` |
| Via Palumbo h24 (delibera di luglio 2026) | Corriere Salentino, Gazzetta (riassunto ricerca web) | `websearch-3-luglio-2026.txt` (non ufficiale) |
| Perimetro ridefinito con delibera del 03/04/2025 («abroga tutti gli atti precedenti») | comunicato 03/04/2025 | `comune-news-2025-04-03-perimetro.txt` |
| Hotel/B&B (HTL, art. 9 del regolamento): accesso dei clienti solo nei giorni di check-in e check-out, sosta max 20 minuti con disco orario, targa comunicata «preferibilmente prima dell'arrivo del cliente e comunque al massimo entro 48 ore dall'accesso» → `hotelCanRegister: true` | regolamento ZTL e AP | `regolamento-ztl-ap.txt` |
| Moto e ciclomotori (L1e, L3e): circolazione «sempre consentita nelle Z.T.L.»; elettriche e ibride «dovrà essere espressamente normata» → non esentate | regolamento art. 2 | idem |
| CUDE: ammessi senza autorizzazione ma, negli orari dei varchi, solo se in lista; ingresso accidentale da dichiarare entro 48 ore (PEC) | pagina permessi | `comune-permessi-ztl.txt` |
| Permesso giornaliero temporaneo 5 € (OCC, su richiesta all'ufficio) → nessun `ticket` | nuove tariffe ZTL | `tariffe-ztl.txt` |
| Open data «ZTL APU CENTRO STORICO LECCE» (CC BY 4.0) del 2014, superato | dati.comune.lecce.it | `ztlapucomunedilecce-2014.geojson` |

Festivi: domenica e festivi accesso non consentito → `freeOnHolidays: false`, `holidaysAsSunday: true`. Sant'Oronzo (26 agosto) non in `localHolidays` (non indicato dagli atti).

## Geometria
**Perimetro da OpenStreetMap, non ufficiale** (© OpenStreetMap contributors, ODbL 1.0): relazione [20670025](https://www.openstreetmap.org/relation/20670025) «ZTL Lecce» (`source=Città di Lecce`, creata il 10/05/2026, `vehicle:conditional=yes @ (Mo-Sa 10:00-13:00,16:30-20:00)` uguale all'ordinanza: lo script si ferma se cambia), semplificata a 4 m: 54 punti, 0,74 km². Dati in `data/raw/geo/lecce-ztl.json` (API OSM, `Tools/fetch_osm_api.py`, 26–27/10/2026), con le strade dei varchi.
**Varchi**: i 18 dell'ordinanza 2069/2025 (17 punti: righe 2 e 3 sono lo stesso incrocio), nel nodo OSM comune alle due strade indicate; per via Maremonti/viale Marconi, via Cairoli/via Duca degli Abruzzi e Porta Rudiae/via Adua il punto più vicino (OSM non ha un nodo in comune; Porta Rudiae = centro della porta). Nome con «(exit)» per i varchi in uscita e «— 24 h» per quelli H24. I 7 nodi OSM «Varco ZTL» e gli 8 varchi dell'open data 2014 coincidono con questi incroci.
Controlli: Duomo, Sant'Oronzo, Santa Croce, Teatro Romano dentro; stazione, Castello Carlo V, mercato di Porta Rudiae fuori; varchi a meno di 60 m dal bordo.

## Da verificare (`pending`)
Varchi H24 dentro una zona a orario variabile (GateLR mostra l'orario della zona); attuazione delle delibere 2026; perimetro OSM; elettriche; 26 agosto.
