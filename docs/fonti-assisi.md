# Assisi: fonti della scheda ZTL (bozza)

Scheda generata da `Tools/build_assisi.py` → `data/drafts/assisi.json` (**bozza, non nell'app**). Regole e citazione **verificate** sulle ordinanze ufficiali lette il **26/10/2026** e salvate in `data/raw/assisi/` (URL e data in testa a ogni file).

## Perché resta bozza
1. **Orari non fissi**: ad Assisi la ZTL è regolata da ordinanze della Polizia Locale che durano una o due settimane (elenco: https://www.comune.assisi.pg.it/novita/comunicati_stampa/novita_298.html, aggiornato il 26/10/2026: n. 355 dal 9 al 21 ottobre, n. 368 dal 22 al 30 ottobre, n. 378 per il solo 27 ottobre 2026). Una scheda con orari fissi sarebbe giusta solo fino al 30/10/2026.
2. **Nessun perimetro**: nessun open data (dati.gov.it: nessun dataset ZTL per Assisi); OpenStreetMap non raggiungibile dal sandbox il 26/10/2026.

Per pubblicare: perimetro da OSM (strade raggiungibili solo dai 5 varchi, come `Tools/build_perugia.py`) in `data/raw/assisi/ztl_perimetro.geojson`, e conferma dal Comune che lo schema feriali/prefestivi è stabile (oppure aggiornamento della scheda a ogni ordinanza).

## Orari usati (ordinanza n. 368/2026, 22–30 ottobre 2026, uguali alla n. 355)
- «GIORNI FESTIVI e PREFESTIVI» — «A) DIVIETO DI CIRCOLAZIONE E SOSTA, all'interno della Z.T.L. per tutti i veicoli dalle ore 11.00 alle ore 20.00», eccetto tra gli altri residenti autorizzati, «turisti con prenotazione alberghiera diretti ad alberghi del centro storico», veicoli elettrici, moto e ciclomotori a due ruote.
- «GIORNI FERIALI ESCLUSO IL SABATO» — «B) DIVIETO DI CIRCOLAZIONE E SOSTA per tutti i veicoli dalle ore 11.00 alle ore 12.30 e dalle 15.30 alle 17.30» (citazione della scheda).
- Ordinanza n. 378 del 26/10/2026: il solo 27/10/2026 11–20 (incontro della Comunità di Sant'Egidio). Nei pending.
- Modello: lun–ven 11–12:30 e 15:30–17:30; sab–dom 11–20; `holidaysAsSunday: true`, `freeOnHolidays: false`; `localHolidays: ["10-04"]` (San Francesco, patrono). Altri prefestivi non modellati.

## Regole (ordinanza 368/2026, ufficiale)
| Fatto | Fonte |
|---|---|
| DGC n. 231 dell'11/12/2025: cinque varchi elettronici, pre-esercizio dal 15/01 al 15/07/2026; DGC 173 del 01/10/2026 disciplinare deroghe | ordinanza 368 |
| Turisti diretti ad alberghi/extra-alberghieri: «previa autorizzazione, l'accesso per le sole operazioni di carico scarico bagagli della durata massima di sessanta minuti»; la struttura inserisce targa e giorno sull'interfaccia web, o «entro le 72 ore successive al transito»; contrassegno e disco orario; con parcheggio privato transito per tutto il soggiorno | ordinanza 368 |
| Elettriche: «hanno titolo ad accedere e sostare», ma vanno inserite nella lista del varco con modulo → `exemptFuels: []` | ordinanza 368 |
| Disabili non in lista: targa prima dell'accesso o entro 72 ore a permessivarchi@comune.assisi.pg.it | https://www.comune.assisi.pg.it/servizi/mobilita_e_trasporti/servizio_23.html (aggiornata il 14/10/2026) |
| Varchi: Porta San Giacomo, Largo Properzio, via Porta Perlici, via Marconi, via del Turrione; multe dal 16/09/2026; multa 84 € (58,10 € entro 5 giorni) | Assisi News e altre testate (`websearch-1`, `websearch-3`), **non ufficiale** |

Nota: il 4 ottobre non è nell'elenco dei festivi nazionali dell'app (`ItalianHolidays`), codice non toccato.
