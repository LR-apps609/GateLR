# Torino: fonti della scheda ZTL

Scheda generata da `Tools/build_torino.py` → per ora **`data/drafts/torino.json`** (bozza, `status: draft`, `reviewedByHuman: false`), **non nell'app**.
Ricerca del **25/10/2026**. Materiale salvato in `data/raw/torino/` e geometrie in `data/raw/geo/torino-*.json`.

## Perché è ancora una bozza

Dall'ambiente di lavoro **nessun sito ufficiale di Torino si raggiunge**:
- `www.comune.torino.it` e `aperto.comune.torino.it`: la connessione si apre e poi il server la chiude durante l'handshake TLS. Ho riprovato per circa un'ora, sempre con lo stesso risultato.
- `gtt.to.it`, `opendata.5t.torino.it`, `geoportale.comune.torino.it`, `comunicatistampa.comune.torino.it`, `decentramento.comune.torino.it`: il proxy risponde 403.
- Anche WebFetch non risolve gli host.

Per questo le frasi citate sono controllate sugli **estratti dei risultati di ricerca** delle pagine ufficiali (`data/raw/torino/ricerca-web-2026-10-25.txt`), e non su copie delle pagine.
Per sbloccare la scheda ho aggiunto un blocco «Torino» in fondo a `Tools/fetch_geo.py`. Scarica i dati aperti ufficiali (5T e geoportale), le schede del Comune, le pagine GTT e una query OSM in più (`torino-extra`).
**Bisogna rilanciare il workflow `geo.yml`.** Quando `data/raw/geo/torino-scheda-ztl-centrale.html` esiste, `build_torino.py` controlla le citazioni su quella pagina e scrive `Resources/Cities/torino.json`. Poi bisogna rilanciare `build_manifest.py` e `build_site.py`.

## Zone nella scheda

| Zona | Orario | Festivi | Geometria |
|---|---|---|---|
| **ZTL Centrale** (`torino-centrale`) | lun–ven 7:30–10:30 | spenta (`freeOnHolidays: true`); 24 giugno trattato come festivo (`localHolidays`) | relazione OSM 19152960 |
| **Strade riservate al trasporto pubblico** (`torino-tp-1…10`) | tutti i giorni 7:00–20:00 | attive (`false`) | way OSM `zone:traffic:name=Strade riservate al Trasporto Pubblico` |
| **ZTL Pedonale** (`pedestrian`, 8 aree) | h24 | attive | way OSM `zone:traffic:name=ZTL Pedonale` |

## Fatti → fonte (letti il 25/10/2026)

| Fatto | Fonte | Tipo |
|---|---|---|
| ZTL Centrale: «dalle 7.30 alle 10.30 di tutti i giorni feriali (sabato escluso)», vietate circolazione e sosta ai non autorizzati | https://www.comune.torino.it/schede-informative/ztl-centrale (estratto di ricerca; la ricerca con la frase esatta trova la pagina) | ufficiale, non scaricata |
| Serve un permesso della Città o di GTT, oppure un'autorizzazione senza permesso; per un accesso occasionale si può chiedere l'esenzione a posteriori, «tassativamente 10 (dieci)» giorni dal primo transito | idem | ufficiale, non scaricata |
| Parcheggi pubblici in struttura dentro la ZTL: targa al gestore «entro e non oltre le ore 11.00» | idem; https://www.gtt.to.it/cms/ztl/3680-utenti-parcheggio-struttura | ufficiale, non scaricata |
| Hotel: solo strutture «accreditate e regolarmente registrate in Piattaforma ZTL»; l'ospite compila la richiesta al check-in per tutto il soggiorno; transito libero in tutte le vie riservate solo il giorno di arrivo e quello di partenza; per i giorni intermedi vale solo per i varchi indicati dall'albergo; nessuna esenzione per chi non pernotta | https://www.gtt.to.it/cms/ztl/3681-utenti-che-pernottano-in-strutture-alberghiere ; modulo GTT nella copia di https://hotelanticadogana.it/pdf/MODULO-RICHIESTA-ESENZIONE.pdf | ufficiale (GTT), non scaricata |
| Non esiste un ticket di accesso per turisti. Il «Giornaliero tariffa ZTL centrale» GTT (11,50 €) è un titolo di **sosta** | ricerca su gtt.to.it | ufficiale, non scaricata |
| Moto e ciclomotori esenti nella ZTL Centrale «se Euro 1, a 4 tempi»; esenzioni nella ZTL TP «escluse le vie P. Micca e Rossini» | https://www.gtt.to.it/cms/ztl/3090-elenco-veicoli-esentati | ufficiale, non scaricata |
| Elettrici puri: permesso gratuito (prorogato al 31/12/2026 secondo assi-ge-co.com); senza permesso, esenzione a posteriori al massimo 12 volte l'anno (MOD.ES.20, entro 10 giorni) | https://www.comune.torino.it/schede-informative/permessi-circolazione-ztl-per-veicoli-elettrici-puri ; https://www.gtt.to.it/cms/risorse/ztl/20_esenzione_veicolo_elettrico_puro.pdf | ufficiale, non scaricata; proroga 2026 solo non ufficiale |
| ZTL Trasporto Pubblico: «chiusa al transito e alla sosta dalle 7.00 alle 20.00 di tutti i giorni, compresi i festivi» (ord. n. 2455 del 29/05/2012) | scheda ZTL Centrale (estratto); conferme: autovia.it, visitturin.com, revisioneauto.eu. Solo tolltracker.eu dice 7–21 | ufficiale, non scaricata |
| ZTL Pedonale: «chiusa al transito e alla sosta dei veicoli tutti i giorni, feriali e festivi, H24» | idem | ufficiale, non scaricata |
| Agosto 2026: ZTL Centrale e strisce blu sospese dal 10 al 23/08; «Restano infatti attive le ZTL "Trasporto Pubblico", "Pedonale", "Area Romana" e "Valentino"» | https://www.comune.torino.it/novita/comunicati/sospensione-estiva-della-ztl-della-sosta-pagamento-0 ; torinotoday.it, ecodallecitta.it | ufficiale, non scaricata |
| 24 giugno (San Giovanni): «di consueto la ZTL centrale non sarà attiva» | https://www.quotidianopiemontese.it/2019/06/23/san-giovanni-a-torino-uffici-pubblici-chiusi-ztl-centrale-non-attiva-e-parcheggi-gratuiti/ | **solo non ufficiale** (2019) |
| Multa: 83–332 € (art. 7 c. 14 CdS), −30% entro 5 giorni | autosupermarket.it, kivo-app.it | non ufficiale |
| Contatti: infoztl@comune.torino.it, numero verde 800 450 900 | scheda ZTL Centrale (estratto) | ufficiale, non scaricata |

Dati aperti ufficiali, trovati ma non scaricabili da qui (metadati salvati in `data/raw/torino/dati.gov.it_*.json`, CC BY 4.0):
- «Perimetro, varchi e orari ZTL» (aperTO, fonte 5T): http://opendata.5t.torino.it/get_access_control
- «Zone Traffico Limitato» (geoportale): http://geoportale.comune.torino.it/geodati/zip/ztl_geo.zip e `ztl_csv.zip`

## Zone trovate ma non ancora sulla mappa (solo nei punti in sospeso)

- **ZTL Area Romana** (Quadrilatero): «chiusa al transito e alla sosta dei veicoli dalle 21:00 alle 7:30 del giorno successivo», tutti i giorni, festivi compresi. In piazza Emanuele Filiberto il divieto parte dalle 19:30. Carico e scarico 10:30–16:00. Manca il perimetro: in OSM non è segnata, e la cosa giusta è prenderlo dal dataset 5T.
- **ZTL Valentino**: chiusa h24 tutti i giorni, festivi compresi. La Giunta ha approvato l'**ampliamento il 24/03/2026**: viale Medaglie d'Oro e il tratto nord di viale Ceppi, con nuovi varchi alla rotatoria Tesla, all'imbocco dei viali Medaglie d'Oro e Boiardo (piazza Levi Montalcini) e in viale Turr. L'avvio dipende dall'autorizzazione del MIT e da un pre-esercizio. **Non ho trovato una data di attivazione.** Fonte: comunicato https://www.comune.torino.it/novita/comunicati/ztl-valentino-citta-amplia-larea-traffico-limitato-per-valorizzare-parco ; ANSA 24/03/2026, sicurauto.it. Manca il perimetro: la query `torino-extra` scarica il parco da OSM.
- **ZTL notturna Monte dei Cappuccini** (Salita al CAI → piazzale): tutti i giorni 23:00–7:00. Pre-esercizio dal 13/10/2025, multe dal 15/11/2025 secondo Torino Cronaca. Fonte: https://www.comune.torino.it/novita/comunicati/zona-traffico-limitato-notturna-salita-cai-monte-dei-cappuccini-lunedi-13
- **Borgo Campidoglio**: area pedonale h24 dal 01/12/2025 (via Cibrario, via San Rocchetto, via Balme, via Ceres), con 5 telecamere. In OSM ci sono 5 nodi ALPR «ZTL Campidoglio». Pre-esercizio fino al 02/02/2026. Fonte: https://www.comune.torino.it/novita/comunicati/borgo-campidoglio-dall1-dicembre-via-alla-pedonalizzazione-ce-tempo-fino-al-2 ; torinoggi.it 27/11/2025.
- **Limitazioni antismog** (tutto il territorio comunale, non una ZTL): dal 15/09/2026 al 15/04/2027 i diesel Euro 3–4 sono fermi lun–ven 8–19. Benzina e diesel fino a Euro 2 sono fermi sempre. Il blocco strutturale dei diesel Euro 5 non è stato introdotto: si fermano solo nei giorni di semaforo antismog. Fonti solo non ufficiali (citynext.it 16/09/2026, mole24.it, torinocronaca.it). Non è nella scheda perché manca sia il perimetro comunale sia l'ordinanza.

## Geometria: provenienza e licenza

**OpenStreetMap, non ufficiale** (© OpenStreetMap contributors, ODbL 1.0, scritto in `license`). File: `data/raw/geo/torino-ztl.json` e `torino-gates.json` (workflow `geo.yml`, run del 25/10/2026).
- **ZTL Centrale**: contorno «outer» della relazione [19152960](https://www.openstreetmap.org/relation/19152960) «ZTL Centrale» (`boundary=limited_traffic_zone`, `motor_vehicle:conditional=yes @ (Mo-Fr 00:00-07:30,10:30-24:00; Sa-Su,PH 00:00-24:00)`, cioè lo stesso orario della scheda). Semplificato a 5 m: 47 punti, 2,72 km².
  Controlli: piazza Castello e piazza San Carlo sono dentro; Porta Nuova, Porta Susa, la Gran Madre e il Valentino sono fuori.
- **Strade riservate al TP**: 23 way con `zone:traffic:name=Strade riservate al Trasporto Pubblico` (via Milano, via San Francesco d'Assisi, via San Tommaso, via XX Settembre, via dell'Arsenale, via Accademia Albertina, via Rossini). Sono raggruppate se distano meno di 45 m. Per ogni gruppo l'area è calcolata con `osm_geo.street_area` (griglia di 6 m, chiusura di 24 m, via ispessita di ±4 m), e ne escono 10 zone. Tutte le way sono coperte e tutte stanno dentro la ZTL Centrale. **Via Pietro Micca**, citata da GTT, in OSM non ha il tag: l'elenco può essere incompleto.
- **Aree pedonali**: 75 way `ZTL Pedonale` (via Garibaldi, via Carlo Alberto, via Lagrange, via Roma nel tratto pedonale, ecc.), calcolate allo stesso modo (chiusura di 18 m). Ne escono 8 aree, che coprono tutte le way; via Garibaldi è dentro.
- Varchi: in OSM non c'è nessun varco della ZTL Centrale (`gates: []`). Le coordinate ufficiali sono nel dataset 5T.

## Da verificare

- Rileggere sulla pagina ufficiale scaricata le frasi citate (orari Centrale, TP, Pedonale, 10 giorni) e la regola per gli hotel.
- Sostituire perimetri e strade OSM con i dati 5T/geoportale (CC BY 4.0) e aggiungere Area Romana, Valentino (con l'ampliamento 2026, se attivo), Monte dei Cappuccini e Borgo Campidoglio.
- 24 giugno: confermarlo con un avviso ufficiale recente.
- Sospensione d'agosto: cambia ogni anno, e GateLR non ne tiene conto.
