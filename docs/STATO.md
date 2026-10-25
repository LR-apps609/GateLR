# GateLR: a che punto siamo (25 ottobre 2026, mattina) — iPhone 1.13.0

## Notte 24→25 ottobre (iPhone)
- 1.9: Avvia dalla mappa, Guida 3D con semafori, viste, modellini, voce migliore, Siri «ZTL vicine», Roma e Siena, Scudo Verde di Firenze
- 1.10: prima pagina «Posso entrare?», mappa scura dentro/fuori, nuovo logo, schermata di avvio, «Novità», correzioni avvio nero / blocco / fotocamera, festivi notturni e 29 giugno a Roma, 5 nuove lingue (fr, es, nl, pl, zh)
- 1.11: Siri «Posso entrare in <zona>?», «Ferma il guardiano», widget Guardiano
- 1.12: mappa più fluida (zone semplificate da lontano), ricerca zone più rapida, iPad; 1.12.1: 13 bug corretti (orari in ora italiana ovunque, Live Activity bloccata, ecc.)
- 1.13: benvenuto con scelta della città e spiegazione della posizione, suggerimenti, posti recenti e hotel che rispondono subito in prima pagina, schermate vuote curate
- Bozze non nell'app: Pisa (orari ufficiali mancanti), Lucca (perimetri da aggiornare alla delibera 2025)
- Android: fermo alla 0.2.0 (da riprendere)


## Novità dalla 1.2 alla 1.8 (in prova)
- Prima pagina d'impatto; ricerca solo in Viaggio
- Mappa: verde più visibile, segni piccoli al posto delle scritte, ricerca con spillo colorato
- Guardiano con Apple Maps, Google Maps, Waze; navigatore di GateLR rifinito
- Hotel sicuro, diario dei passaggi, guida alle multe, ticket con promemoria, lettura del cartello
- Testi che seguono «Testo più grande»
- Checklist: `docs/checklist-prova.md`

## Dove lavorare
- **Mac (principale)**: `git pull` + `zsh "Installa su iPhone.command"` → Xcode ▶︎. Android: APK da Actions.
- **Windows (quando serve)**: iPhone con Sideloadly e l'.ipa da Actions, Android con l'APK da Actions → `docs/windows.md`.
- Con l'Apple Developer Program: TestFlight, e il computer non conta più.

## Android 0.1 (nuovo, 24 ottobre)
- Stesse regole dell'iPhone (motore in Kotlin, 12 test verdi), stesse città
- Cinque schede: Varco, Mappa (MapLibre + OpenFreeMap, va anche su Huawei/Honor senza Google), Viaggio, Garage, Account
- Guardiano: notifica fissa, voce, bolla sopra Google Maps / Waze / Petal Maps; si ferma all'arrivo
- Compilato su GitHub (Actions → Android) con giro di prova sull'emulatore Android 14: nessun crash
- Anche: benvenuto che spiega la posizione (richiesto da Google Play), controllo del tragitto (ZTL attraversate e ora), widget per la schermata Home, «Leggi il cartello» (foto letta sul telefono), «Ho preso una multa?», diario dei passaggi
- Revisione del codice fatta: 10 correzioni (tra cui: il permesso dell'hotel vale solo nella sua città, anche su iPhone)
- Versione per gli store pronta: basta la chiave di firma nei segreti di GitHub (`docs/android-store.md`)
- Checklist: `docs/checklist-android.md`

## Sito (W1–W2)
- Stesse regole dell'app: zone verdi con i divieti Euro, aree pedonali, ticket con scadenza
- Pagine per città in 3 lingue (`/firenze/`, `/it/milano/`, `/de/bologna/`), sitemap, dati strutturati
- Mappa vera caricata solo quando serve; pulsanti App Store / Google Play «In arrivo»
- Si pubblica a mano: Actions → «Pubblica il sito» → Run workflow

## App iPhone (fino alla 1.1)

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
- **Festivi di notte**: per la parte dopo mezzanotte di una fascia notturna il festivo si guarda sul giorno in cui la fascia è iniziata (sabato festivo 23 → domenica 3 libera; venerdì feriale → sabato festivo attiva). Vale anche per il «non sicuro» dei festivi sconosciuti.
- **Feste del patrono**: campo facoltativo `localHolidays` (`"MM-DD"`) sulla città, copiato sulle zone quando si legge il file. Per ora solo Roma, 29 giugno (Santi Pietro e Paolo).

### Da verificare: feste del patrono
- **Firenze**, 24 giugno (San Giovanni): festa cittadina; capire se per la ZTL vale come festivo (oggi `freeOnHolidays` è sconosciuto).
- **Bologna**, 4 ottobre (San Petronio): festa cittadina; capire se la ZTL si spegne.
- **Milano**, 7 dicembre (Sant'Ambrogio): l'Area C dice «festivi esclusi», non è chiaro se Sant'Ambrogio conta.
- **Siena**: non serve (ZTL attiva 0–24).

## Prossimi passi

1. Le tue prove a mano: `docs/checklist-prova.md`.
2. Verifiche delle città (ultime, come deciso): `docs/verifica-firenze.md`, `docs/verifica-bologna-milano.md`.
3. Dopo l'Apple Developer Program: account vero, abbonamento, CarPlay, pubblicazione; poi il sito.
4. Più avanti: guida passo-passo con voce nell'app, percorsi che evitano la ZTL, Roma e Siena.
