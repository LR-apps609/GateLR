# Taormina: fonti della scheda ZTL

Scheda generata da `Tools/build_taormina.py` → `data/drafts/taormina.json` (stato **draft**, **bozza**: non è nel manifest dell'app né sul sito).

## Perché resta bozza
1. **Nessun perimetro.** Le ordinanze 2009–2010 parlano di «centro storico» senza elencarne le vie; non ci sono open data del Comune né della Regione Siciliana; in OpenStreetMap (API principale, scaricata il 27/10/2026 con `Tools/fetch_osm_api.py`, bbox 37.845–37.858 N, 15.278–15.298 E) non c'è una relazione `boundary=limited_traffic_zone`, né strade con orari ZTL, né nodi «Varco». Corso Umberto è `pedestrian`/`living_street`, via Timeo ha `motor_vehicle=permit` senza orari.
2. **Regola ufficiale vecchia e orari non ufficiali.** L'unico testo ufficiale leggibile è la pagina dei pass (ordinanza 8/2010: solo veicoli con pass colorato). Gli orari delle sbarre di via Timeo / via Damiano Rosso e lo stato delle telecamere sono solo nella stampa e in guide.

Per pubblicarla servono l'ordinanza vigente sugli accessi al centro storico (albo pretorio) e la delimitazione dell'area (o una mappa ufficiale dei varchi).

## Fonti ufficiali lette (27/10/2026)
| Fatto | URL | Tipo | Letto il |
|---|---|---|---|
| «I soli veicoli che dal 1/01/2010 possono circolare nel centro storico di Taormina sono quelli muniti dei nuovi PASS colorati (Azzurri, Gialli, Verdi e Rossi), emessi nel 2009» (ord. 8 del 26/01/2010); criteri: ord. 177 del 07/07/2009; proroga: ord. 221 del 04/09/2009; categorie dei pass (azzurro residenti, giallo proprietari/attività, rosso servizio pubblico, verde turistico) | https://www.comune.taormina.me.it/altri-contenuti/pass-transito-e-sosta.aspx → `data/raw/taormina/comune-pass-transito-e-sosta.txt` | ufficiale | 27/10/2026 |
| Pass verde: per «operatori turistici» (hotel, B&B), 50 € per autovettura | https://www.comune.taormina.me.it/contents/2023/9/27/richiesta-pass-02-turistico-verde.pdf → `comune-modulo-pass-verde.txt` | ufficiale | 27/10/2026 |
| Parcheggi Porta Catania (650 posti) e Lumbi (850 posti, navetta per Porta Messina) | https://www.comune.taormina.me.it/altri-contenuti/parcheggi.aspx → `comune-parcheggi.txt` | ufficiale | 27/10/2026 |

I PDF delle ordinanze 177/2009, 221/2009 e 8/2010 linkati dalla pagina restituiscono una pagina «Risorsa non trovata» (anche nel percorso `/contents/2023/9/27/`).

## Fonti non ufficiali (solo per trovare e incrociare)
Riassunto in `data/raw/taormina/websearch-1-orari-sbarre.txt`:
- accessibilitacentristorici.it: ZTL «24 ore su 24», telecamere non in funzione, carico/scarico feriali 6–9:30.
- taorminanews24.com (dic. 2024): sbarre di via Timeo / via Damiano Rosso, es. 4–8:15 per Corso Umberto; registro autorizzazioni presso la Polizia Locale.
- qds.it: telecamere mai uscite dal pre-esercizio; carico/scarico 5–9.
- bluekeys.it (guida 2026): 10:30–13 e 16–20, d'estate anche 21–1, «non è un atto comunale».
- tyremap.com: ospiti degli hotel esenti con registrazione della targa, multe 83–160 € (non confermato).

## Host bloccati dal proxy (403, non aggirati)
- `qds.it`, `taorminanews24.com` (stampa), `albopretorio.comune.taormina.me.it`, `taormina.trasparenza-valutazione-merito.it` (albo pretorio / trasparenza), `smart-pass.comune.taormina.me.it` (portale dei pass).

## Pending (nella scheda)
- Perimetro mancante; orari reali delle sbarre e stato delle telecamere; registrazione delle targhe degli ospiti; elettriche, moto, disabili, multe, variazioni estive.

## Geometria
Nessuna. Nessun disegno a mano.
