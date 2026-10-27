# Mantova: fonti della scheda ZTL

Scheda generata da `Tools/build_mantova.py` → `Resources/Cities/mantova.json`, pubblicata come **città con fonte non ufficiale** (app 1.16.2: `source.official: false`, `unofficialSource` = accessibilitacentristorici.it; nel manifest sta in `unofficialCities`, nascosta alle app fino alla 1.16.1; avviso «Fonte non ufficiale» in app e sito). Ricerca del **27/10/2026**; testi salvati in `data/raw/mantova/`.

## Perché la fonte è «non ufficiale»
Nessun testo ufficiale raggiungibile dà gli orari della ZTL per le auto né l'elenco delle vie o una mappa. Il proprietario ha autorizzato l'uso di accessibilitacentristorici.it con l'etichetta «fonte non ufficiale». Ogni regola presa da lì ha nei pending «confermato solo da accessibilitacentristorici.it».

Citazione (non ufficiale): «Le telecamere a protezione della ZTL A e B di Mantova sono attive tutti i giorni 24 su 24 ore».

## Zone
| Zona | Vie (elenco non ufficiale) | Orario | Area |
|---|---|---|---|
| Centro storico · ZTL A | elenco «ZTL A» + «ZTL U» (piazza Sordello, Palazzo Ducale) | tutti i giorni 0–24 | 0,395 km² |
| Via Carducci e via Speri · ZTL B | elenco «ZTL B» | tutti i giorni 0–24 | 0,074 km² |
| San Leonardo · ZTL N | elenco «ZTL N» (via Cavriani, piazza San Leonardo) | tutti i giorni 0–24 | 0,039 km² |

## Fonti ufficiali (lette il 27/10/2026)
| Fatto | URL | File |
|---|---|---|
| Merci fino a 7,5 t senza pass nelle **ZTL A e B** solo 6–10 e 15–16:30; fuori da questi orari serve permesso orario o pass annuale (indizio che la ZTL è attiva tutto il giorno) | https://aster.mn.it/cittadini/trasporto-merci | `aster-trasporto-merci.txt` (nuovo) |
| Zone ZTL A, A/RU, AV, B; «Zona Rossa» con 5 telecamere; pass per residenti | https://aster.mn.it/cittadini/ztl | `aster-pass-ztl-persone-fisiche.txt` |
| Varchi n. 9 via Trieste e n. 10 corso Libertà; regolamento D.C.C. 62/2013 citato | https://aster.mn.it/cittadini/ztl-aziende | `aster-pass-ztl-aziende.txt` |
| Permesso orario ZTL per turisti dall'«Area Pass» con PagoPA (5 giorni di anticipo consigliati; prezzo non indicato) | https://aster.mn.it/turisti/permesso-orario-ztl | `aster-permesso-orario-ztl-turisti.txt` |
| Elettriche di altri comuni: pass di solo transito 100 € | https://aster.mn.it/cittadini/pass-auto-elettriche | `aster-pass-auto-elettriche.txt` |
| ZTL per autobus turistici 7–19 (solo bus) | https://aster.mn.it/turisti/bus-turistici | `aster-bus-turistici.txt` |
| Disabili di altre città: prenotazione dell'accesso | https://www.comune.mantova.it/it/services/prenotazione-accesso-zona-a-traffico-limitato-ztl-con-pass-disabile-altre-citta | `comune-servizio-pass-disabili-altre-citta.txt` |
| Moduli Aster (`ZTL_residenti.pdf`, `ZTL_varchi.pdf`, `RICOVERO_E_TRANSITI.pdf`…): zone A, AC, ARU, AV, B, «limitrofe ZTL A», zona Trento con varco di via Tassoni, zona Lunetta; **nessun orario** | https://aster.mn.it/images/documenti/ | (solo letti) |
| Copia del «Regolamento generale rilascio pass ZTL» del Comune (2002): «uniformità del divieto di accesso per tutte le ZTL dalle ore 0.00 alle ore 24.00» (superato dalla D.C.C. 62/2013) | https://www.accessibilitacentristorici.it/ufficiali/regolamenti/regolamento-mantova.pdf | `regolamento-pass-ztl-2002-copia-acs.txt` |

## Fonti non ufficiali
- https://www.accessibilitacentristorici.it/ztl/lombardia/mantova.html → `accessibilitacentristorici-mantova.txt` (27/10/2026): **orari (citazione)**; elenchi delle vie di ZTL A, B, N, U, Libertà, Trieste-Garibaldi; 13 telecamere; corso della Libertà e via Trieste aperti a tutti 7–12 e 18–21; vecchie regole per gli hotel (permesso compilato dall'albergo con la targa, 24 ore, 2,60 €, A.S.Ci.). Non usata la sua mappa.
- La «mappa ufficiale» in copia sullo stesso sito (`/ufficiali/mappe/mappa_ztl_mantova.pdf`, immagine del 2012) è stata solo scaricata, non usata (vecchia e senza garanzia di essere vigente).
- Ricerca web (`websearch-27-ottobre-2026.txt`): tyremap.com, Gazzetta di Mantova, siti di hotel.

## Pending (nella scheda)
- Orari solo da accessibilitacentristorici.it; corso della Libertà e via Trieste 7–12 e 18–21 aperti a tutti (via Trieste è dentro la zona A in GateLR, quindi l'app è prudente in quelle ore).
- Hotel: procedura attuale non confermata da fonti ufficiali; turisti: permesso orario Aster, prezzo ignoto.
- Elettriche non esenti (Aster, ufficiale; accessibilitacentristorici.it diceva il contrario, superato).

## Geometria
- Elenchi delle vie di accessibilitacentristorici.it applicati alle strade OpenStreetMap (API OSM, `data/raw/geo/mantova-centro.json`, solo strade, © OpenStreetMap contributors, ODbL 1.0) → `osm_geo.street_area` (celle 8 m, chiusura 40 m), semplificata a 4 m. Nessun disegno a mano.
- Abbinamento per nome (la voce dell'elenco è la fine del nome OSM, es. «Fernelli» → «Via Domenico Fernelli»). Escluse le voci ambigue «Commercio» e «Martiri» e via Accademia (orario a parte); non trovate in OSM: Bertazzolo, Canonica, Paradiso, San Paolo, Galleria San Maurizio, San Crispino. Vie con soli alcuni civici (Bertani, Calvi, Fernelli) prese intere.
- U (contigua) unita alla A; N (staccata di ~220 m) zona a parte. Le sottozone N e U non compaiono più nei moduli Aster.
- Varchi: le 13 telecamere dell'elenco, nel vertice della via indicata più vicino al bordo della zona (via Speri: i due incroci con corso Vittorio Emanuele e via Chiassi).
- Controlli: piazza delle Erbe, piazza Sordello, Sant'Andrea dentro la A; via Tito Speri dentro la B; piazza San Leonardo dentro la N; Palazzo Te e stazione fuori.

## Host
- `aster.mn.it` (senza www) raggiungibile; `www.aster.mn.it` 403 dal proxy (non aggirato).
- `pubblicazioni.comune.mantova.it` (albo) connessione chiusa, `comune.mantova.gov.it` 502 (verifiche precedenti, 27/10/2026).
- Overpass non usato (reset/timeout): API OSM principale.
