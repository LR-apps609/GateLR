# Cagliari: fonti della scheda ZTL

Scheda generata da `Tools/build_cagliari.py` → `Resources/Cities/cagliari.json` (stato **draft**), pubblicata come città con **fonti non ufficiali**: ogni zona ha `source.official = false` e `source.unofficialSource` = accessibilitacentristorici.it (app 1.16.2). `Tools/build_manifest.py` la mette in `unofficialCities`, che le app fino alla 1.16.1 non leggono; l'app 1.16.2 e il sito mostrano l'avviso «Fonte non ufficiale».

## Perché fonti non ufficiali (approvato dal titolare)
1. **Orari non ufficiali.** Il regolamento vigente (art. 31) affida gli orari alla Giunta «con apposito atto», non trovato. La pagina del Comune che riportava gli orari (`old.comune.cagliari.it/portale/viabilita/at16_ztl_aree_pedonali_info`) e il Sistema informativo territoriale con «mappa e orari» (`geoportale.comune.cagliari.it`) non sono raggiungibili.
2. **Perimetri.** OpenStreetMap ha solo «ZTL Castello» (relazione 14402165) e «ZTL Marina» (14402156); per Villanova, Stampace Alto e Stampace Basso il perimetro è ricavato dalle strade di confine elencate dal sito non ufficiale (vedi Geometria). Nessun open data.

## Fonte principale (non ufficiale)
| Fatto | URL | Tipo | Letto il |
|---|---|---|---|
| Orari delle sei ZTL (citazioni), strade di confine di ogni ZTL, 13 varchi per nome, tratti senza limitazioni, aree pedonali di Marina e Villanova | https://www.accessibilitacentristorici.it/ztl/sardegna/cagliari.html (dalla mappa https://www.accessibilitacentristorici.it/ztl/Sardinia/cagliari/mappa) → `data/raw/cagliari/accessibilitacentristorici-cagliari.txt`; pagina «Data aggiornamento: 02/05/2020», «Affidabilità: modesta» | **non ufficiale** (sito privato di servizi per i permessi) | 27/10/2026 |

Usati solo il testo (orari, nomi di strade e varchi). **La geometria/mappa KML del sito non è usata.**

Orari (citati nella scheda): Castello 24–9; Marina 21–7 e 15:30–17; Villanova 21–7 e 15:30–17; Stampace Alto 21–9 e 15:30–17; Stampace Basso «i giorni festivi e feriali» 7:30–10:30 e 15:30–17; Poetto 21–6 (non disegnata).

Incroci: i tag OpenStreetMap delle strade (`vehicle:conditional`) danno gli stessi orari per Castello (`yes @ 09:00-24:00`), Marina e Villanova (`yes @ 07:00-15:30,17:00-21:00`), Stampace Alto (`yes @ 09:00-15:30,17:00-21:00`, via Sant'Efisio, Santa Restituta; `access:conditional no @ 21:00-09:00,15:30-17:00` su via Ospedale e Porto Scalas). Per **Stampace Basso** OSM e le fonti in `websearch-1-orari.txt` danno lun–ven 7:30–10:30 e 15:30–17, sabato solo 7:30–10:30, domenica e festivi liberi: la scheda usa gli orari più ampi del sito principale e lo scrive nei pending.

## Pending
- «confermato solo da accessibilitacentristorici.it» (in ogni zona).
- Stampace Basso: sabato pomeriggio, domeniche e festivi discordanti (sopra).
- Tratti mai soggetti a limitazioni (via Porcile, tratti di via Cavour e via Sardegna; via Azuni e via Santa Margherita; viale Trieste) e aree pedonali di Marina e Villanova: solo nei pending.
- Poetto non disegnata.
- Multa 80–335 € solo da tyremap.com.

## Ricerche precedenti sulle fonti ufficiali
3. **Ricerca del 27/10/2026 nell'albo pretorio** (https://www.comune.cagliari.it/portale/page/it/pubblicati_da_agosto_2016, tipo «DELIBERA DI GIUNTA», tutte le pagine degli anni 2016–2026, circa 2.900 titoli; più gli atti in pubblicazione): **nessuna delibera di Giunta che fissi orari o perimetri delle ZTL dopo il 02/12/2025** (e nemmeno prima, dal 2016). Dopo la D.C.C. 168/2025 la Giunta ha deliberato solo aree pedonali stagionali (n. 39 e 40 del 26/02/2026: via Cavour, via dei Mille, via Sant'Eulalia, via Sassari, via Malta, aprile/giugno–31 ottobre 2026; n. 188 dell'08/07/2026: via dei Partigiani). Elenco salvato in `data/raw/cagliari/albo-delibere-giunta-dal-02-12-2025.txt`. Con la parola chiave l'albo trova solo determine e ordinanze (ordinanze di viabilità «comprese le ZTL» per lavori, nessuna sugli orari).
4. **Geoportale** (`geoportale.comune.cagliari.it`, ArcGIS Hub, ora raggiungibile): c'è una pagina «Zone a traffico limitato» («Il tematismo riporta la localizzazione delle zone a traffico limitato e degli accessi pedonali») e un'app con lo stesso nome, ma non sono open data (`openData: false`, `downloadable: false`) e i dati stanno su `*.arcgis.com` (`comunecagliarieu.maps.arcgis.com`, `services*.arcgis.com`), **bloccati dal proxy (403)**. Metadati in `geoportale-ztl-metadati.txt`.

Per passare a fonti ufficiali servono la delibera di Giunta sugli orari (ed eventualmente quella sulla perimetrazione dopo la D.C.C. 168/2025).

## Fonti ufficiali lette (27/10/2026)
| Fatto | URL | Tipo | Letto il |
|---|---|---|---|
| Regolamento ZTL vigente (D.C.C. 42/2012, 27/2013, **168 del 02/12/2025**): sei ZTL; perimetri e orari decisi dalla Giunta; ciclomotori liberi; elettriche con pass di solo transito senza limiti orari; strutture ricettive trasmettono le targhe dei clienti (arrivo/partenza, sosta max 60 minuti, pass ≤10% delle camere) — **citazione** art. 10; CUDE in lista bianca; controllo anche dell'uscita | https://www.comune.cagliari.it/portale/protected/247459/0/def/ref/DOC77600I/ → `data/raw/cagliari/regolamento-ztl-2025.txt` (scheda: `comune-scheda-regolamento.txt`, pubblicata il 29/12/2025) | ufficiale | 27/10/2026 |
| Ufficio ZTL e zone pedonali (contatti, piattaforma online) | https://www.comune.cagliari.it/portale/page/it/ztl_e_zone_pedonali?contentId=ORG9497 → `comune-ufficio-ztl.txt` | ufficiale | 27/10/2026 |
| Sei ZTL; rinvio a «mappa e orari» nel SIT | https://www.comune.cagliari.it/portale/page/it/rilascio_pass_zone_a_traffico_limitato_ztl__persone_fisiche_it_1?contentId=SRV10350 → `comune-rilascio-pass-ztl.txt` | ufficiale | 27/10/2026 |
| Pass dimoranti/studenti h24, 5 € | https://www.comune.cagliari.it/portale/page/it/pass_ztl_per_dimoranti_e_studenti_fuori_sede?contentId=SRV10364 → `comune-pass-dimoranti.txt` | ufficiale | 27/10/2026 |
| Pass per strutture ricettive (bagagli) | scheda SRV10363 letta dall'API del portale → `comune-pass-strutture-ricettive.txt` | ufficiale | 27/10/2026 |

Ricerca nel portale fatta con l'API pubblica di ricerca (`/portale/api/plugins/advcontentsearch/contents.json?text=ztl*`, 104 contenuti, titoli controllati): nessuna delibera o ordinanza sugli orari tra i contenuti; comunicati del 2016 e 2018 su estensioni temporanee degli orari di Castello e Stampace alto per eventi.

## Fonti non ufficiali
`data/raw/cagliari/websearch-1-orari.txt`: Castello 0–9; Marina 21–7 e 15:30–17; Stampace alto 21–9 e 15:30–17 (una fonte 21–10); Stampace basso feriali 7:30–10:30 e 15:30–17, sabato 7:30–10:30 (discordanze); Villanova 21–7 e 15:30–17; Poetto (non modellata: è una ZTL del lungomare, orari discordanti 0–24 / 21–6). Unione Sarda (luglio 2025): telecamere riaccese, 13.920 violazioni in un anno. Multa 80–335 € (tyremap.com).

## Geometria
- OpenStreetMap (© OpenStreetMap contributors, ODbL 1.0), API principale con `Tools/fetch_osm_api.py`, 27/10/2026, bbox 39.208–39.228 N, 9.098–9.132 E, ridotto in `data/raw/geo/cagliari-ztl.json` (relazioni ZTL/enforcement, strade con nome, telecamere).
- Castello e Marina: relazioni 14402165 e 14402156.
- Villanova, Stampace Alto, Stampace Basso: anello che segue in ordine le strade di confine del sito non ufficiale, ciascuna percorsa sulle sue way OSM tra l'incrocio con la precedente e quello con la successiva (mezzeria). Nomi OSM: «Piazza John Fitzgerald Kennedy», «Via Ottone Bacaredda», «Via Porto Scalas» (Portoscalas), «Via Giovanni Maria Angioy» (Angioj), «Corso Vittorio Emanuele Secondo». «Portico Alberti» e «salita Santa Chiara» non hanno nome in OSM: l'anello passa per l'incrocio più vicino. Incroci non condivisi: Villanova viale Regina Elena–via La Vega 107 m, Stampace Alto corso Vittorio Emanuele–piazza Yenne 9 m. Aree: Castello 0,116, Marina 0,134, Villanova 0,345, Stampace Alto 0,066, Stampace Basso 0,184 km².
- Varchi: telecamere OSM (11 relazioni `enforcement`, operator «Comune di Cagliari») a meno di 40 m dal bordo (Castello 2, Marina 4, Villanova 5; nessuna per Stampace).
- Controlli: Cattedrale (Castello), via Sardegna (Marina), piazza San Domenico, via Bosa, piazza San Giacomo (Villanova), via Sant'Efisio, via Santa Restituta (Stampace Alto), via Asproni, via Carloforte (Stampace Basso) dentro la loro zona e fuori dalle altre; stazione, via Sassari lato porto, viale Buoncammino fuori da tutte.

## Host (ricontrollati il 27/10/2026)
- `old.comune.cagliari.it` (pagina orari ZTL): il proxy risponde 502 (server irraggiungibile), quattro tentativi con timeout lunghi.
- `geoportale.comune.cagliari.it`: raggiungibile (vedi sopra); i dati su `comunecagliarieu.maps.arcgis.com`, `www.arcgis.com`, `services1…9.arcgis.com`: **403** dal proxy, non aggirati.
- `servizi.comune.cagliari.it`: 403 dal proxy.

## Moto e scooter (1.17.1)
Nessuna esenzione nel modello: il regolamento lascia entrare i soli *ciclomotori* (non le moto), ma il tipo «Moto / scooter» li comprende entrambi, quindi per prudenza «Non entrare».
