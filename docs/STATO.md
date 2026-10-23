# GateLR: a che punto siamo (24 ottobre 2026, notte)
## App iPhone (versione 0.5)

| Cosa | Stato |
|---|---|
| Cinque schede: Varco, Mappa, Viaggio, Garage, Account | ✅ |
| Varco: città → indirizzo o hotel (ricerca Apple), risposta per quel punto adesso o all'arrivo; «Fuori dalla ZTL» con distanza | ✅ |
| Viaggio: indirizzo dell'hotel → zona trovata da sola; viaggi salvati; messaggio per l'hotel EN/IT/DE | ✅ |
| Account: avvisi (con prova), lingua, città offline, abbonamento (grafica), «Cos'è una ZTL?» | ✅ prima versione |
| Mappa: colori per tipo (vietato / pass / verde), scritte grandi che svaniscono, stili satellite e 3D, Look Around | ✅ |
| Firenze (A, B, O, F, G), Bologna (ZTL + T), Milano (Area C + Area B verde) | ✅ bozza, da verificare |
| Lingua coerente IT/DE anche nei dati delle città (controllo automatico: `Tools/check_strings.py`) | ✅ |
| Motore delle regole con zona verde; test automatici su indirizzi e città | ✅ |
| Widget configurabile per zona | ✅ da provare sull'iPhone |
| Avvisi ai varchi più vicini (limite iOS di 20) | ✅ da provare sull'iPhone |
| CarPlay | codice pronto, serve l'autorizzazione Apple |


## Sito (`web/`)

| Cosa | Stato |
|---|---|
| Cerca hotel o luogo → in ZTL? posso entrare? orari, prezzi, multa, messaggio per l'hotel (con nome e targa) | ✅ |
| «Usa la mia posizione», link diretti `#firenze`, `#bologna`, `#milano`, domande frequenti | ✅ |
| Adesso o all'ora di arrivo | ✅ |
| Inglese, italiano, tedesco | ✅ |
| Mappa vera MapLibre + OpenFreeMap, con mappa disegnata di riserva | ✅ |
| Più città | ✅ Firenze, Bologna, Milano |
| Carattere della famiglia LR: carta chiara, ottone, Titillium Web + Atkinson Hyperlegible Next | ✅ |
| Pagina `/app` (su iPhone porterà all'App Store), Privacy, Supporto | ✅ |
| Pubblicazione su GitHub Pages | workflow pronto, da attivare (Settings → Pages → «GitHub Actions») |

## Documenti

- `docs/verifica-firenze.md` e `docs/verifica-bologna-milano.md` – liste di controllo per segnare le città «verificate» (ultima cosa da fare)
- `docs/multe-mappe-caratteri.md` – multe, scelta delle mappe e dei caratteri, con fonti
- `docs/ricerca-citta.md` e `docs/citta-successive.md` – le città dopo Firenze
- `docs/app-store.md` – scheda App Store pronta in tre lingue

## Decisioni prese (si possono cambiare)

- **Mappe**: Apple Maps nell'app (gratis); MapLibre + OpenFreeMap sul sito (gratis, senza chiave).
- **Ricerca sul sito**: Photon (gratis); più avanti Apple MapKit JS.
- **Caratteri**: Titillium Web per titoli (app e sito, carattere di tutta la famiglia LR), Atkinson Hyperlegible Next per i testi del sito, SF Pro nei testi delle app.
- **Lingua**: inglese principale, italiano e tedesco.

## Prossimi passi

1. Il tuo test della 0.5 sull'iPhone (`git pull` + `Installa su iPhone.command` + ▶︎).
2. 0.6 Navigazione (percorso, controllo ZTL del percorso, «apri nel navigatore»), poi Garage 4.1–4.2.
2. Roma (orari pronti, servono le geometrie dall'hub RSM) e Siena (perimetro da digitalizzare dal PDF).
3. Pubblicare il sito su GitHub Pages.
4. Verifiche di Firenze (ultime, come deciso).
