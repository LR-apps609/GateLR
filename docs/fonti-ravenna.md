# Ravenna: fonti della scheda ZTL (bozza)

Scheda generata da `Tools/build_ravenna.py` → `data/drafts/ravenna.json` (**bozza, non nell'app**). Regole e citazione **verificate** sui testi ufficiali letti il **26/10/2026** e salvati in `data/raw/ravenna/` (URL e data in testa a ogni file). **Manca solo il perimetro** (sotto).

## Zona (bozza)
**Ravenna · ZTL Centro storico** (`ravenna-ztl`, `pass`): 0–24 tutti i giorni per tutta la zona (prudenziale), ticket 15 € `beforeEntry`.

Citazione (pagina «SIRIO – Controllo accessi in ZTL», https://comune.ravenna.it/altro-contenuto/sirio-controllo-accessi-in-ztl/, ufficiale, «Pagina aggiornata il 30/07/2025»): «Attraverso una rete di telecamere, le targhe dei veicoli che accedono attraverso i “varchi” vengono riconosciute e confrontate con la lista delle targhe dei veicoli abilitati al transito».

| Fatto | Fonte | Tipo |
|---|---|---|
| Varchi 24 ore su 24: via di Roma, via G. Guaccimanni, via A. Baccarini, via N. Rondinelli, via Cavour (ingresso piazzetta Gandhi), via Ponte Marino; dalle 07.30 alle 20.30: via A. Mariani, via Ar. Guerrini, via P. Matteucci | pagina SIRIO → `comune-sirio-controllo-accessi-ztl.txt` | ufficiale |
| Contrassegno giornaliero rilasciato 24 ore su 24 dai parcometri abilitati, veicoli ≤ 5 t; valido 00.00–23.59; ufficio via D'Alaggio 3, lun–ven 9–12:30 | pagina SIRIO | ufficiale |
| Mezza giornata 8 € (0–12 o 12–24), dal 1° marzo 2026 | https://comune.ravenna.it/novita/comunicato-stampa/in-seguito-agli-incontri-pubblici-approvata-la-modifica-alla-delibera-del-piano-che-disciplina-circolazione-e-sosta-nel-comune-di-ravenna/ → `comune-comunicato-piano-sosta-2026.txt` | ufficiale |
| Giornaliero 15 €, mattiniero 8 €, pomeridiano 8 €; 12 parcometri (elenco); monete senza resto o carta; sosta max 90 minuti con disco, mai in Piazza del Popolo e aree pedonali; esporre sul cruscotto | https://www.azimut-spa.it/ita/Servizi/Sosta/Permessi-giornalieri-ZTL → `azimut-permessi-giornalieri-ztl.txt` | ufficiale (gestore della sosta) |
| Strutture ricettive: trasmissione della modulistica per i clienti con auto, «inserimento alla data della comunicazione», gratis; disabili: modulo targhe (max 2) | https://comune.ravenna.it/servizi/autorizzazioni/comunicazione-targhe-di-veicoli-abilitati-a-circolare-in-zona-a-traffico-limitato-di-ravenna-sirio/ (aggiornata il 15/09/2026) | ufficiale |
| Contrassegni giornalieri per i clienti delle strutture in ZTL (blocchi da 50), validi nel solo giorno di rilascio | Determina E 2/4 del 13/03/2006 → `determina-e2-4-2006-contrassegni-ztl.txt` | ufficiale, datata |

La regola dei «cinque giorni» della vecchia pagina Rapida non è più citata (non c'è nelle pagine attuali). Elettriche: nessuna esenzione nelle pagine ufficiali → `exemptFuels: []`. Patrono Sant'Apollinare (23 luglio): non serve con 0–24.

## Perché resta bozza: geometria
- Nessun perimetro ufficiale in open data (dati.gov.it: nessun dataset ZTL per Ravenna).
- La «Piantina stradale con varchi Sirio» (https://comune.ravenna.it/wp-content/uploads/2025/07/Piantina-stradale-con-varchi-Sirio.pdf) è un'immagine senza coordinate.
- OpenStreetMap non raggiungibile dal sandbox il 26/10/2026 (overpass-api.de, mirror e kumi: connessione chiusa; api.openstreetmap.org: rifiutato dal proxy).

Per pubblicare: scaricare da OSM la relazione della ZTL o le strade del centro, ricavare il perimetro dai 9 varchi ufficiali (metodo di `Tools/build_perugia.py`) o dalla relazione con il nome ufficiale, salvarlo in `data/raw/ravenna/ztl_perimetro.geojson` e rilanciare lo script: passa da solo in `Resources/Cities/`.
