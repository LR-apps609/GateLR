# Volterra: fonti della scheda ZTL

Scheda generata da `Tools/build_volterra.py` → `Resources/Cities/volterra.json` (nell'app). Ricerca del **27/10/2026**; testi salvati in `data/raw/volterra/`. Ogni frase usata è ricontrollata dal builder sul testo salvato.

## Zona e orari
Una zona: **centro storico dentro le mura**, tutti i giorni, festivi compresi:
- dal 21 marzo al 1° novembre: 10:00–20:00;
- dal 2 novembre al 20 marzo: 10:00–17:30.

Citazione (pagina ufficiale): «Orario Z.T.L. INVERNALE: Nel periodo che va dal 2 novembre al 20 marzo, la ZTL sarà attiva dalle ore 10:00 alle ore 17:30. Orario Z.T.L. ESTIVO: Nel periodo che va dal 21 marzo al 1 novembre, la ZTL sarà attiva dalle ore 10:00 alle ore 20:00.»

## Fonti ufficiali (Comune di Volterra, lette il 27/10/2026)
| Fatto | URL | File |
|---|---|---|
| Orari invernale/estivo (**citazione**), accesso temporaneo via e-mail (max 15 l'anno), disabili via e-mail, varchi per settore (ingresso Porta San Francesco, Porta a Selci; uscita Porta Fiorentina, piazza Martiri della Libertà, Porta all'Arco), terminal bus H24 in piazza Martiri, tipi di permesso e costi; agg. 17/03/2026 | https://www.comune.volterra.pi.it/articolo_tematico/z-t-l-zona-a-traffico-limitato-informazioni-e-servizi/ | `comune-ztl-informazioni-e-servizi.txt` |
| Estate 2026: dal 21/03 al 01/11/2026 10–20; varchi spenti 22–23/03/2026 (referendum) | https://www.comune.volterra.pi.it/novita/variazioni-ztl/ (18/03/2026) | `comune-2026-03-18-variazioni-ztl.txt` |
| ZTL attiva nel festivo del 14/12/2025, prorogata dalle 17:30 alle 20 (quindi attiva anche nei festivi) | https://www.comune.volterra.pi.it/novita/divieto-di-transito-e-proroga-orario-ztl/ (12/12/2025) | `comune-2025-12-12-proroga-orario-festivo.txt` |
| Inverno 2025/26: varchi attivi 10–17:30 | https://www.comune.volterra.pi.it/novita/nuovo-orario-ztl/ (30/10/2025) | `comune-2025-10-30-orario-invernale.txt` |
| Estate 2025 sperimentale fino alle 22 (15/07–15/09/2025, D.G.C. 162/2025) | https://www.comune.volterra.pi.it/novita/estensione-dellorario-della-zona-a-traffico-limitato-ztl/ | `comune-2025-07-10-estensione-orario.txt` |
| Dal 01/04/2026 anche i ciclomotori 50 cc senza permesso non entrano | https://www.comune.volterra.pi.it/novita/rinnovo-permessi-ztl/ (04/12/2025) | `comune-2025-12-04-rinnovo-permessi.txt` |
| Nomi dei varchi «ZTL di San Francesco» e «Porta a Selci» | https://www.comune.volterra.pi.it/novita/disattivazione-varchi-ztl-per-elezioni/ (06/06/2025) | `comune-2025-06-06-varchi-elezioni.txt` |

## Fonti non ufficiali
- https://www.accessibilitacentristorici.it/ztl/toscana/volterra.html → `accessibilitacentristorici-volterra.txt` (27/10/2026): la ZTL «comprende tutta l'area del centro storico compresa dentro le mura»; 3 telecamere (Porta San Francesco e Porta a Selci in entrata, Porta Fiorentina in uscita); numero verde 800 865 635. Orario estivo 10–19 superato (il Comune dice 10–20 per il 2026).
- tyremap.com (ricerca web, 27/10/2026): ospiti degli hotel con targa registrata; ZTL notturna estiva ven–dom 20:30–1 (29/06–31/07/2026), multa 83–160 €. Non confermati dal Comune: solo nei pending.

## Pending
- Hotel: nessuna procedura ufficiale; `hotelCanRegister: true` perché il Comune rilascia accessi temporanei su richiesta e-mail con targa (l'app dice «solo se l'hotel registra la targa»); conferma per gli hotel solo da tyremap.com.
- ZTL notturna estiva: confermata solo da tyremap.com, non inserita.
- Multe, auto elettriche: non indicate dal Comune.

## Geometria
- Mappa e delibera allegate dal Comune (`123.png`, `ztl.png`, `DELIBERA-ZTL.pdf`, ordinanza 105/2025) sono su **static-www.comune.volterra.pi.it**, che il proxy blocca (**403**, non aggirato): nessun perimetro ufficiale.
- Area: le 5 way OpenStreetMap delle mura (`barrier=city_wall`: 355037914, 362804601, 372662738, 367415836, 348733219; API OSM, `data/raw/geo/volterra-centro.json`, © OpenStreetMap contributors, ODbL 1.0) unite testa-coda; i due vuoti della mappatura (279 m lungo la Fortezza/carcere, 47 m in piazza Martiri della Libertà) chiusi con un segmento; tolto l'inviluppo convesso di terminal bus (way 362868720), parcheggio sotterraneo «La Dogana» (336681257) e rotatoria/strada di piazza Martiri (362813456, 362868718), che in OSM non hanno divieti e dove il Comune indica il terminal bus H24 e un'uscita della ZTL. 0,264 km². Nessun disegno a mano.
- Varchi: nodi OSM delle porte Porta San Francesco (937863921), Porta a Selci (471087421), Porta Fiorentina (471087415).
- Controlli: piazza dei Priori, Duomo, via Matteotti dentro; parcheggi La Dogana, La Stazione, Docciola, Teatro romano, ospedale fuori.

## Host bloccati
- `static-www.comune.volterra.pi.it` (allegati e immagini del sito comunale): 403 dal proxy.
- Overpass (overpass-api.de reset, overpass.kumi.systems timeout): usata l'API OSM principale.
