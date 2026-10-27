# Montepulciano: fonti della scheda ZTL

Scheda generata da `Tools/build_montepulciano.py` → `Resources/Cities/montepulciano.json` (stato **draft**, `reviewedByHuman: false`). Dal 27/10/2026 è **nell'app** (`manifest.json`) e sul sito.

## Fonti ufficiali lette (27/10/2026)
| Fatto | URL | Tipo | Letto il |
|---|---|---|---|
| **Citazione**: calendario 1/5–30/9 0–24, aprile e ottobre 8–20, 1/11–31/3 8–17; nessuna deroga per elettriche/ibride; carico/scarico merci 7–11 tutti i giorni; sosta dei non autorizzati sempre vietata; categorie autorizzabili (tra cui «Turisti e visitatori, clienti delle strutture ricettive»); permessi temporanei online o numero verde 800669945 | https://www.comune.montepulciano.si.it/istruzioni-ztl/ → `data/raw/montepulciano/comune-istruzioni-ztl.txt` | ufficiale | 27/10/2026 |
| Stesso calendario («ZTL chiusa»); varchi d'uscita (Ciliano, Gozzano/Borgo Buio, Opio/via del Teatro, Grassi) attivi dal 20/01/2025; zone A–D con ingressi e uscite; B&B: transito e sosta max 2 ore e mezza | https://www.comune.montepulciano.si.it/novita/da-lunedi-20-gennaio-entrano-in-funzione-i-varchi-in-uscita-per-il-controllo-della-ztl-nel-centro-storico/ (15/01/2025) → `comune-news-2025-01-15-varchi-uscita.txt` | ufficiale | 27/10/2026 |
| Ordinanza n. 9 del 14/01/2025: attivazione varchi d'uscita, tabella zone/ingressi/uscite, richiamo ord. 77/2022, 114/2022, 32/2023 e DGC 75/2022 | https://www.comune.montepulciano.si.it/wp-content/uploads/2025/01/OrdinanzadelResponsabile_Copia_9_2025-ztl-varchi-uscita.pdf → `ord-9-2025.txt` | ufficiale | 27/10/2026 |
| Ordinanza n. 77 dell'11/05/2022 (traduzione inglese pubblicata dal Comune): orari, «l'intera area del centro storico» è ZTL, 4 varchi d'ingresso (Porta al Prato con due telecamere, Collazzi, San Donato, Fiorenzuola Vecchia), strutture ricettive con targa degli ospiti nella white list temporanea per il soggiorno (solo percorso più breve, sosta max 20 minuti, mai parcheggio), disabili in white list anche entro il giorno lavorativo successivo | https://www.comune.montepulciano.si.it/wp-content/uploads/2024/11/DEF_ordinanza_ZTL_77_2022_EN.pdf → `ord-77-2022-en.txt` | ufficiale (traduzione) | 27/10/2026 |
| Servizio «Accesso temporaneo»: richieste fino a 7 giorni; calendario con aprile/ottobre «dalle ore 8.00 alle ore 00» (in contrasto con le altre fonti) | https://www.comune.montepulciano.si.it/servizio/richiesta-permesso-di-accesso-temporaneo-alla-ztl/ (agg. 19/03/2025) → `comune-accesso-temporaneo-ztl.txt` | ufficiale | 27/10/2026 |

Il testo italiano dell'ordinanza 77/2022 e l'ordinanza 32/2023 non sono stati trovati sul sito (ricerca WordPress del Comune).

## Orari nella scheda
Quattro finestre stagionali, tutti i giorni, festivi compresi (`freeOnHolidays: false`): 1/5–30/9 0–24; 1/4–30/4 8–20; 1/10–31/10 8–20; 1/11–31/3 8–17. Discordanza della scheda «accesso temporaneo» (aprile/ottobre fino alle 24) nei pending.

## Geometria
- OpenStreetMap (© OpenStreetMap contributors, ODbL 1.0), API principale, 27/10/2026, ridotto in `data/raw/geo/montepulciano-ztl.json`: relazione `enforcement` 18111528 «ZTL Montepulciano» con 81 strade (`section`) → `osm_geo.street_area` (parametri di default), 0,133 km². Nessun open data né mappa ufficiale (l'allegato A dell'ordinanza 77 non è pubblicato).
- Varchi: gli 8 dei testi ufficiali, nel nodo OSM dove la strada indicata esce dalla ZTL: Porta al Prato (nodo 305521951, inizio di via di Gracciano nel Corso), via di Ciliano (2198093415), via di Collazzi (1776199386), via di San Donato (787024727), via Fiorenzuola Vecchia (787008407), Porta di Gozzano/Borgo Buio (264347932), Porta delle Farine/via del Teatro (787008514), Porta dei Grassi (2972092117). Le telecamere OSM con `surveillance:zone=traffic` sono tutte fuori dalla ZTL e non sono state usate.
- Controlli: Piazza Grande e il Corso dentro; Tempio di San Biagio, Fortezza, Parcheggio 1 e Piazza Moulins fuori.

## Sito
In `Tools/build_site.py` e `web/template.html` la riga «tutto il giorno chiuso» ora vale solo per fasce 0–24 senza stagione (prima una fascia estiva 0–24 faceva dire «sempre chiusa» anche d'inverno); nessun'altra città ha fasce stagionali 0–24, quindi le altre pagine non cambiano.

## Host bloccati
Nessuno.
