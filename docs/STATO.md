# GateLR: a che punto siamo (24 ottobre 2026, mattina## App iPhone (versione 1.0)

| Cosa | Stato |
|---|---|
| Cinque schede: Varco, Mappa, Viaggio, Garage, Account | ✅ |
| Varco: città → indirizzo o hotel, risposta adesso o all'arrivo; «Fuori dalla ZTL» con distanza | ✅ |
| Percorso: tempo, km, ZTL attraversate all'ora del passaggio, parcheggio fuori zona, Apple Maps / Google Maps / Waze | ✅ (guida passo-passo dentro l'app: non ancora) |
| Viaggio: hotel cercato → zona trovata da sola; viaggi salvati; messaggio per l'hotel EN/IT/DE | ✅ |
| Garage: marca, modello, anno → classe Euro; consigli per l'auto; permessi | ✅ |
| Milano: Area C (pass) e Area B (verde) con i divieti per classe Euro | ✅ dai calendari ufficiali del 15/10/2026 |
| Mappa: colori per tipo, scritte grandi che svaniscono, satellite, 3D, Look Around, percorso | ✅ |
| Account: avvisi (con prova), lingua, città offline, abbonamento (grafica), «Cos'è una ZTL?», «Segnala un bug» | ✅ (email di supporto: segnaposto) |
| Avvisi ai varchi più vicini mentre ti sposti, senza doppioni | ✅ da provare per strada |
| Widget configurabile per zona | ✅ da provare sull'iPhone |
| Italiano e tedesco completi, parole dei pannelli ufficiali («ZTL attiva») | ✅ controllo automatico `Tools/check_strings.py` |
| Controllo giornaliero delle pagine dei Comuni (segnalazione se cambiano) | ✅ `.github/workflows/sources.yml` |
| Test automatici: motore, città, indirizzi, percorso, divieti Euro, velocità | ✅ |
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

1. Le tue prove a mano: `docs/checklist-prova.md`.
2. Verifiche delle città (ultime, come deciso): `docs/verifica-firenze.md`, `docs/verifica-bologna-milano.md`.
3. Dopo l'Apple Developer Program: account vero, abbonamento, CarPlay, pubblicazione; poi il sito.
4. Più avanti: guida passo-passo con voce nell'app, percorsi che evitano la ZTL, Roma e Siena.
