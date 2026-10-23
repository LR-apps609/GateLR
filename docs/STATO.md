# GateLR: a che punto siamo (23 ottobre 2026, sera)

## App iPhone (versione 0.3)

| Cosa | Stato |
|---|---|
| Quattro schede: Now, Map, Trip, Garage | ✅ |
| Firenze dai dati aperti del Comune (settori A, B, O, F, G, 15 varchi) | ✅ bozza, da verificare (`docs/verifica-firenze.md`) |
| Motore delle regole: sì / no / con condizioni / non sicuro, orari notturni e stagionali, festivi | ✅ con test automatici |
| Conto alla rovescia «Off in 21 min», elenco dei settori con la risposta di ciascuno | ✅ |
| Mappa Apple con settori, varchi, tocco per scegliere il settore | ✅ |
| «Park outside»: parcheggi fuori ZTL da Apple Maps, con indicazioni | ✅ (nel simulatore di GitHub a volte non trova risultati) |
| Messaggio per l'hotel in EN / IT / DE con nome dell'hotel e targa | ✅ |
| Riquadro della multa (83–332 € al giorno) | ✅ importi da verificare sul testo ufficiale |
| Modalità scura | ✅ |
| Presentazione al primo avvio; permessi chiesti dopo | ✅ |
| Avvisi vicino ai varchi ad app chiusa | ✅ da provare sull'iPhone |
| Widget Home e schermata di blocco | ✅ (in compilazione) |
| App in italiano e tedesco | ✅ (in compilazione) |
| CarPlay | codice pronto, serve l'autorizzazione Apple |
| Foto automatiche a ogni modifica | ✅ ramo `screenshots` |

## Sito (`web/`)

| Cosa | Stato |
|---|---|
| Cerca hotel o luogo → in ZTL? posso entrare? orari, multa, messaggio per l'hotel | ✅ |
| Adesso o all'ora di arrivo | ✅ |
| Inglese, italiano, tedesco | ✅ |
| Mappa vera MapLibre + OpenFreeMap, con mappa disegnata di riserva | ✅ |
| Pronto per più città | ✅ (oggi solo Firenze) |
| Carattere della famiglia LR: carta chiara, ottone, Titillium Web + Atkinson Hyperlegible Next | ✅ |
| Pagina `/app` (su iPhone porterà all'App Store), Privacy, Supporto | ✅ |
| Pubblicazione su GitHub Pages | workflow pronto, da attivare (Settings → Pages → «GitHub Actions») |

## Documenti

- `docs/verifica-firenze.md` – lista di controllo per segnare Firenze «verificata» (ultima cosa da fare)
- `docs/multe-mappe-caratteri.md` – multe, scelta delle mappe e dei caratteri, con fonti
- `docs/ricerca-citta.md` e `docs/citta-successive.md` – le città dopo Firenze
- `docs/app-store.md` – scheda App Store pronta in tre lingue

## Decisioni prese (si possono cambiare)

- **Mappe**: Apple Maps nell'app (gratis); MapLibre + OpenFreeMap sul sito (gratis, senza chiave).
- **Ricerca sul sito**: Photon (gratis); più avanti Apple MapKit JS.
- **Caratteri**: Titillium Web per titoli (app e sito, carattere di tutta la famiglia LR), Atkinson Hyperlegible Next per i testi del sito, SF Pro nei testi delle app.
- **Lingua**: inglese principale, italiano e tedesco.

## Prossimi passi

1. Il tuo test sull'iPhone (`Installa su iPhone.command`).
2. Seconda città (Bologna o Milano Area C) con i dati aperti già scaricati in `data/raw/`.
3. Pubblicare il sito su GitHub Pages.
4. Verifiche di Firenze (ultime, come deciso).
