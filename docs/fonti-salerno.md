# Salerno: fonti della scheda ZTL

Scheda generata da `Tools/build_salerno.py` → `Resources/Cities/salerno.json`, pubblicata come **città con fonte non ufficiale** (app 1.16.2: `source.official: false`, `unofficialSource` = accessibilitacentristorici.it; nel manifest sta in `unofficialCities`, nascosta alle app fino alla 1.16.1; avviso «Fonte non ufficiale» in app e sito).

## Perché la fonte è «non ufficiale»
1. **Nessun orario ufficiale.** Nessuna pagina o documento ufficiale letto indica quando la ZTL è attiva (ricercato di nuovo il 27/10/2026: pagine ZTL e PGTU di www.comune.salerno.it, ricerca web). Con il permesso del proprietario la scheda usa **accessibilitacentristorici.it** (non ufficiale, scheda agg. 07/12/2019): «La telecamere sono in funzioni tutti i giorni 24 ore su 24 ore» → `quote` da quella pagina, `source.official: false`, pending «confermato solo da accessibilitacentristorici.it».
2. Perimetro e varchi invece sono **ufficiali** (tavola del PGTU 2019, vedi Geometria).

## Fonti ufficiali lette (27/10/2026)
| Fatto | URL | Tipo | Letto il |
|---|---|---|---|
| Ufficio Varchi ZTL: permessi giornalieri, transiti trasmessi da autorimesse, B&B, alberghi e pensioni (**citazione**); sistema Sirio Web e Street Controll | https://www.comune.salerno.it/amministrazione/ufficio/ufficio-varchi-ztl → `data/raw/salerno/comune-ufficio-varchi-ztl.txt` | ufficiale | 27/10/2026 |
| Comunicazione transito occasionale (carico/scarico, disabili, medici) con modello B1, gratuita | https://www.comune.salerno.it/servizi/comunicazione-transito-occasionale-ztl → `comune-comunicazione-transito-occasionale.txt` | ufficiale | 27/10/2026 |
| Elenco dei 10 varchi; carico/scarico 6–9:30 e 14–17; veicoli fino a 18 q.li su via Duomo, Portanova, Conforti, Corso V. Emanuele | https://www.comune.salerno.it/sites/default/files/documento_pubblico/modello-b1.pdf → `comune-modello-b1.txt` | ufficiale | 27/10/2026 |
| Permessi: categorie (residenti, domiciliati, disabili, attività, CVE…), 10 € PagoPA, risposta entro 30 giorni | https://www.comune.salerno.it/servizi/richiesta-autorizzazione-transito-eo-sosta-ztl-eo-rinnovi → `comune-richiesta-autorizzazione-ztl.txt` | ufficiale | 27/10/2026 |

| PUMS (Proposta di Piano, 2° Rapporto, p. 180): per tutti i varchi carico/scarico 06.00–09.30 e 14.00–17.00 con autorizzazione annuale, permanenza 15 minuti, portata massima 18 quintali; nessun orario della ZTL | https://www.comune.salerno.it/documento-pubblico/pums-elaborati-progettuali → `comune-pums-2-rapporto-estratto.txt` | ufficiale (pianificazione) | 27/10/2026 |

Ricontrollo del 27/10/2026: pagine «ZTL» del sito (argomento, Ufficio Varchi, servizi «Verifica transiti», «Comunicazione transito occasionale», «Richiesta autorizzazione», moduli) rilette: nessun orario e nessuna ordinanza linkata. I 9 moduli di richiesta (PDF) sono scansioni senza testo. La ricerca interna del sito (`/search`) risponde **403** (non insistito).

**Tavola ufficiale del PGTU (perimetro e varchi):** PGTU, «TAVOLA 7.2 Individuazione ZTL» 1:5000 (PDF vettoriale AutoCAD del 25/07/2019, coordinatore scientifico Stefano de Luca): strade in ZTL (rosso), passaggi pedonali, scale, area pedonale lungomare; varchi 1 Antica Corte, 2 San Michele, 3 Via Monte Risi, 4 Via Romualdo II Guarna, 5 Via Duomo, 6 Portanova, 7 Mazza Antonio, 8 Via Vigorito, 9 Via Portacatena, 10 Via della Porta, 11 Piazzetta Elina, 12 Via dei Principati, 13 Via Conforti Raffaele, 14 Via Porta di Mare — file caricato dal proprietario il 27/10/2026 (copia del documento ufficiale del Comune; nessun URL pubblico raggiungibile) → vettori e legenda estratti in `data/raw/salerno/pgtu-tav7-vettori.json` (ufficiale (pianificazione 2019), letta il 27/10/2026).

## Fonti non ufficiali
- https://www.accessibilitacentristorici.it/ztl/campania/salerno.html → `data/raw/salerno/accessibilitacentristorici-salerno.txt` (27/10/2026; scheda agg. 07/12/2019): **orari (citazione)** «tutti i giorni 24 ore su 24», confini via Roma – via Duomo/San Benedetto/Salvatore Rienzi, 14 telecamere (stessi nomi della Tav. 7.2), disabili con contrassegno liberi di transitare, carico/scarico 6–9:30 e 14–17. Usata solo per gli orari (non la sua mappa).
`data/raw/salerno/websearch-1-orari.txt`: accessibilitacentristorici.it, sicurauto.it, automobilista.it (24 ore su 24; confini via Roma – via Duomo/San Benedetto/Salvatore Rienzi); stampa 2023 (nuovi varchi Conforti, Corso Garibaldi, Corso V. Emanuele) e delibera per sostituire i 15 varchi.

## Host non raggiungibili (ricontrollati il 27/10/2026)
- `website.comune.salerno.it` (vecchio sito con la scheda orari 2007): il proxy accetta, ma il server chiude la connessione («connection reset»), anche con timeout di 180 s e più tentativi.
- Connessione chiusa allo stesso modo: `amministrazionetrasparente.comune.salerno.it`, `albo.comune.salerno.it`, `servizionline.comune.salerno.it`, `servizi.comune.salerno.it`.
- `www.comune.salerno.it` funziona, tranne `/search` (403 dal sito).

## Geometria
- Fonte: Tav. 7.2 del PGTU (sopra). `Tools/salerno_mappa.py --pdf <PDF>` estrae dal PDF le polilinee per colore e le etichette dei varchi (`data/raw/salerno/pgtu-tav7-vettori.json`), poi aggancia le linee rosse (assi delle strade in ZTL) alle strade OpenStreetMap (API OSM, `data/raw/geo/salerno-centro.json`, solo strade, © OpenStreetMap contributors, ODbL 1.0) con una similitudine: scala 1,719 m/pt (≈ 1:4875), rotazione 0,15°; **98,6 % dei punti rossi entro ~4 m** da una strada OSM. Risultato in `data/raw/salerno/ztl-pgtu-tav7.geojson`.
- Area: linee rosse allargate di 23 pt e ristrette di 19 pt (chiude gli isolati tra le strade della ZTL), buchi riempiti, semplificata a 3 m: **0,239 km²**. La mappa non ha un bordo disegnato: l'area è quella coperta dalle strade in ZTL.
- Varchi: punto della linea rossa più vicino a ogni etichetta, agganciato alla via OSM del nome in legenda se entro 25 m (13 su 14; «Piazzetta Elina» resta sul punto della tavola). Alcuni varchi (3, 4, 11) sono interni all'area.
- Controlli: Duomo, via dei Mercanti, via Duomo, Corso Vittorio Emanuele dentro; via Roma (Comune), lungomare Trieste, stazione FS, castello di Arechi fuori.
- Dubbi: la tavola è del 2019; il modello B1 attuale elenca 10 varchi (con Corso Garibaldi e Corso Vittorio Emanuele del 2023) e non Vigorito, Portacatena, Della Porta, Piazzetta Elina, Porta di Mare. Nessun disegno a mano.
