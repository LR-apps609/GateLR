# Taormina: fonti della scheda ZTL

Scheda generata da `Tools/build_taormina.py` → `data/drafts/taormina.json` (stato **draft**, **bozza**: non è nel manifest dell'app né sul sito).

## Perché resta bozza
1. **Nessun perimetro.** Le ordinanze 2009–2010 parlano di «centro storico» senza elencarne le vie; non ci sono open data del Comune né della Regione Siciliana; in OpenStreetMap (API principale, scaricata il 27/10/2026 con `Tools/fetch_osm_api.py`, bbox 37.845–37.858 N, 15.278–15.298 E) non c'è una relazione `boundary=limited_traffic_zone`, né strade con orari ZTL, né nodi «Varco». Corso Umberto è `pedestrian`/`living_street`, via Timeo ha `motor_vehicle=permit` senza orari.
2. **Regola ufficiale vecchia e orari non ufficiali.** L'unico testo ufficiale leggibile è la pagina dei pass (ordinanza 8/2010: solo veicoli con pass colorato). Gli orari delle sbarre di via Timeo / via Damiano Rosso e lo stato delle telecamere sono solo nella stampa e in guide.

3. **Aggiornamento 27/10/2026 (albo pretorio ora raggiungibile).** L'albo online (taormina.trasparenza-valutazione-merito.it, atti dal 25/11/2024) è stato cercato per oggetto («ZTL», «traffico limitato», «Damiano Rosso», «barriere», «Corso Umberto», «pass», «accesso»): **nessuna ordinanza permanente su orari o perimetro della ZTL** dopo il 25/11/2024. La regola vigente risulta dalle **Ordinanze Dirigenziali n. 105 del 13/06/2023 e n. 141 del 28/08/2023** («disciplinato l'accesso nell'asse commerciale di corso Umberto I da Porta Catania a Porta Messina con installazione di barriere mobili a comando remoto», citate dalla Determina 1569/2025), che stanno nel vecchio albo `albostorico.comune.taormina.me.it`, **bloccato dal proxy (403)**. Senza quel testo non ci sono orari ufficiali, e «da Porta Catania a Porta Messina» non basta come perimetro (non dice quali traverse e piazze sono dentro).

Per pubblicarla servono il testo delle Ordinanze 105/2023 e 141/2023 (orari delle sbarre, eventuale elenco delle vie) e una delimitazione dell'area.

## Fonti ufficiali lette (27/10/2026)
| Fatto | URL | Tipo | Letto il |
|---|---|---|---|
| «I soli veicoli che dal 1/01/2010 possono circolare nel centro storico di Taormina sono quelli muniti dei nuovi PASS colorati (Azzurri, Gialli, Verdi e Rossi), emessi nel 2009» (ord. 8 del 26/01/2010); criteri: ord. 177 del 07/07/2009; proroga: ord. 221 del 04/09/2009; categorie dei pass (azzurro residenti, giallo proprietari/attività, rosso servizio pubblico, verde turistico) | https://www.comune.taormina.me.it/altri-contenuti/pass-transito-e-sosta.aspx → `data/raw/taormina/comune-pass-transito-e-sosta.txt` | ufficiale | 27/10/2026 |
| Pass verde: per «operatori turistici» (hotel, B&B), 50 € per autovettura | https://www.comune.taormina.me.it/contents/2023/9/27/richiesta-pass-02-turistico-verde.pdf → `comune-modulo-pass-verde.txt` | ufficiale | 27/10/2026 |
| Parcheggi Porta Catania (650 posti) e Lumbi (850 posti, navetta per Porta Messina) | https://www.comune.taormina.me.it/altri-contenuti/parcheggi.aspx → `comune-parcheggi.txt` | ufficiale | 27/10/2026 |

| Ordinanze dirigenziali 105 del 13/06/2023 e 141 del 28/08/2023: accesso all'«asse commerciale di corso Umberto I da Porta Catania a Porta Messina» con barriere mobili a comando remoto; due barriere gestite dalla Polizia Locale (app «1control») ai varchi di via Damiano Rosso e via Timeo; contratto di gestione rinnovato per 12 mesi | Determina n. 1569 del 02/09/2025, https://taormina.trasparenza-valutazione-merito.it/web/trasparenza/papca-sa-siciliana/-/papca/display/1393288?p_p_state=pop_up → `albo-determina-1569-2025-barriere-mobili.txt` | ufficiale | 27/10/2026 |
| «Via Damiano Rosso costituisce una delle principali vie di accesso al Corso Umberto, ricadente in ambito ZTL»; sbarra spostata all'imbocco della via (GC 138/2025) | Determina n. 1773 del 06/10/2025, …/display/1435121 → `albo-determina-1773-2025-sbarra-damiano-rosso.txt` | ufficiale | 27/10/2026 |
| «varco di Via Timeo» della ZTL; accessi in deroga con comunicazione delle targhe (evento 4–20 luglio 2026) | Ordinanza Polizia Locale n. 145 del 24/06/2026, …/display/1705490 → `albo-ordinanza-145-2026-ztl-eventi-luglio.txt` | ufficiale | 27/10/2026 |
| Sistema integrato di controllo automatizzato «ZTL e PASS» (Link Space srl), rinnovato 01/01–30/06/2026 | Determina n. 1447 del 26/08/2026, …/display/1755115 → `albo-determina-1447-2026-sistema-ztl-pass.txt` | ufficiale | 27/10/2026 |
| Elenco degli atti con «ZTL» nell'oggetto (storico atti dal 25/11/2024) | https://taormina.trasparenza-valutazione-merito.it/web/trasparenza/papca-sa/-/papca/igrid/27606 → `albo-ricerca-ztl.txt` | ufficiale | 27/10/2026 |
| Portale «Taormina ZTL» (pass e accessi): le organizzazioni gestiscono «Ospiti, Impiegati, richieste di accesso ZTL» (solo testi dell'interfaccia, nessuna regola) | https://smart-pass.comune.taormina.me.it/ → `smart-pass-portale.txt` | ufficiale | 27/10/2026 |

I documenti dell'albo si scaricano dalla sezione «Atti Amministrativi (L.R. Siciliana 22/2008)» (`papca-sa-siciliana`); nella sezione «storico atti» il download è disabilitato. Le ordinanze 105/2023 e 141/2023 non compaiono nelle ricerche (l'albo online parte dal 25/11/2024). Pagine «documenti e dati» del sito del Comune (documento=1…700) controllate: solo i moduli dei pass.

I PDF delle ordinanze 177/2009, 221/2009 e 8/2010 linkati dalla pagina restituiscono una pagina «Risorsa non trovata» (anche nel percorso `/contents/2023/9/27/`).

## Fonti non ufficiali (solo per trovare e incrociare)
Riassunto in `data/raw/taormina/websearch-1-orari-sbarre.txt`:
- accessibilitacentristorici.it: ZTL «24 ore su 24», telecamere non in funzione, carico/scarico feriali 6–9:30.
- taorminanews24.com (dic. 2024): sbarre di via Timeo / via Damiano Rosso, es. 4–8:15 per Corso Umberto; registro autorizzazioni presso la Polizia Locale.
- qds.it: telecamere mai uscite dal pre-esercizio; carico/scarico 5–9.
- bluekeys.it (guida 2026): 10:30–13 e 16–20, d'estate anche 21–1, «non è un atto comunale».
- tyremap.com: ospiti degli hotel esenti con registrazione della targa, multe 83–160 € (non confermato).

## Host
- Ora raggiungibili (27/10/2026): `albopretorio.comune.taormina.me.it` (rimanda a `taormina.trasparenza-valutazione-merito.it`), `taormina.trasparenza-valutazione-merito.it`, `smart-pass.comune.taormina.me.it` (a volte la connessione cade: riprovato).
- Bloccati dal proxy (403, non aggirati): `albostorico.comune.taormina.me.it` (albo fino al 25/11/2024, dove stanno le ordinanze 105 e 141 del 2023), `l190.comune.taormina.me.it` (trasparenza storica), `qds.it`, `taorminanews24.com` (stampa).

## Pending (nella scheda)
- Perimetro mancante; orari reali delle sbarre e stato delle telecamere; registrazione delle targhe degli ospiti; elettriche, moto, disabili, multe, variazioni estive.

## Geometria
Nessuna. Nessun disegno a mano.
