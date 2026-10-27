# Cagliari: fonti della scheda ZTL

Scheda generata da `Tools/build_cagliari.py` → `data/drafts/cagliari.json` (stato **draft**, **bozza**: non è nel manifest dell'app né sul sito).

## Perché resta bozza
1. **Orari non ufficiali.** Il regolamento vigente (art. 31) affida gli orari alla Giunta «con apposito atto», non trovato. La pagina del Comune che riportava gli orari (`old.comune.cagliari.it/portale/viabilita/at16_ztl_aree_pedonali_info`) e il Sistema informativo territoriale con «mappa e orari» (`geoportale.comune.cagliari.it`) sono bloccati dal proxy (403). Gli orari della scheda vengono da sicurauto.it, brumbrum.it, accessibilitacentristorici.it (che riprendono la vecchia pagina).
2. **Perimetri mancanti per tre zone.** OpenStreetMap ha solo «ZTL Castello» (relazione 14402165) e «ZTL Marina» (14402156); Stampace Alto, Stampace Basso e Villanova no. La perimetrazione ufficiale è rimessa a una delibera di Giunta (art. 1 c. 2), non trovata; nessun open data (dati.regione.sardegna.it, dati.gov.it: 0 risultati).

3. **Ricerca del 27/10/2026 nell'albo pretorio** (https://www.comune.cagliari.it/portale/page/it/pubblicati_da_agosto_2016, tipo «DELIBERA DI GIUNTA», tutte le pagine degli anni 2016–2026, circa 2.900 titoli; più gli atti in pubblicazione): **nessuna delibera di Giunta che fissi orari o perimetri delle ZTL dopo il 02/12/2025** (e nemmeno prima, dal 2016). Dopo la D.C.C. 168/2025 la Giunta ha deliberato solo aree pedonali stagionali (n. 39 e 40 del 26/02/2026: via Cavour, via dei Mille, via Sant'Eulalia, via Sassari, via Malta, aprile/giugno–31 ottobre 2026; n. 188 dell'08/07/2026: via dei Partigiani). Elenco salvato in `data/raw/cagliari/albo-delibere-giunta-dal-02-12-2025.txt`. Con la parola chiave l'albo trova solo determine e ordinanze (ordinanze di viabilità «comprese le ZTL» per lavori, nessuna sugli orari).
4. **Geoportale** (`geoportale.comune.cagliari.it`, ArcGIS Hub, ora raggiungibile): c'è una pagina «Zone a traffico limitato» («Il tematismo riporta la localizzazione delle zone a traffico limitato e degli accessi pedonali») e un'app con lo stesso nome, ma non sono open data (`openData: false`, `downloadable: false`) e i dati stanno su `*.arcgis.com` (`comunecagliarieu.maps.arcgis.com`, `services*.arcgis.com`), **bloccati dal proxy (403)**. Metadati in `geoportale-ztl-metadati.txt`.

Per pubblicarla servono la delibera di Giunta sugli orari (ed eventualmente quella sulla perimetrazione dopo la D.C.C. 168/2025).

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
- OpenStreetMap (© OpenStreetMap contributors, ODbL 1.0), API principale, 27/10/2026, bbox 39.208–39.228 N, 9.100–9.130 E, ridotto in `data/raw/geo/cagliari-ztl.json`: relazioni 14402165 (Castello) e 14402156 (Marina), 11 relazioni `enforcement` con i nodi delle telecamere (operator «Comune di Cagliari», note «ZTL»). I varchi sono assegnati alla zona se distano meno di 40 m dal bordo (Castello 2, Marina 4; gli altri 5 restano fuori, probabilmente Villanova/Stampace).
- Controlli: Cattedrale dentro Castello, via Sardegna dentro Marina, stazione fuori.

## Host (ricontrollati il 27/10/2026)
- `old.comune.cagliari.it` (pagina orari ZTL): il proxy risponde 502 (server irraggiungibile), quattro tentativi con timeout lunghi.
- `geoportale.comune.cagliari.it`: raggiungibile (vedi sopra); i dati su `comunecagliarieu.maps.arcgis.com`, `www.arcgis.com`, `services1…9.arcgis.com`: **403** dal proxy, non aggirati.
- `servizi.comune.cagliari.it`: 403 dal proxy.
