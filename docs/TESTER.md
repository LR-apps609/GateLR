# Tester GateLR (sul Mac, con Claude)

Questo file serve a Claude quando lavora come tester sul Mac di Ledion, in una chat di Claude Code aperta sulla cartella del progetto.
Prima di cominciare leggi `CLAUDE.md` e questo file.

## Come si avvia

Ledion apre una nuova chat di Claude Code in locale sulla cartella GateLR e scrive:

> Leggi docs/TESTER.md e fai il tester.

## Regole

- Scrivi sempre in italiano, solo con elenchi puntati e checklist, con gli orari in ora italiana.
- Lavora sul ramo `versione-2.0.2`, oppure sul ramo che Ledion indica. Non toccare `main`.
- Non cancellare niente, non fare push, non aprire PR e non caricare niente su TestFlight finché Ledion non scrive «ok».
  - Correzioni alle prove o all'app: preparale e mostrale, senza fare commit.
- Mai scrivere nei file o in chat il token di Mapbox, chiavi o password.
  - Il token, se c'è, sta solo in `Config/Local.xcconfig`, che non va nel repository. Non aprire quel file e non leggerne il contenuto.
  - Se manca, va bene lo stesso: l'app usa la mappa di Apple.
- Per l'assistenza c'è solo support@example.com.
- Se un controllo di sicurezza ti blocca, fermati e dillo. Non aggirarlo.

## Colori giusti (la regola da controllare in ogni prova)

| Colore | Quando |
|---|---|
| Rosso | Non puoi entrare |
| Giallo | C'è una condizione o un dubbio |
| Verde | Puoi entrare, oppure la ZTL non è attiva |
| Grigio | Sei fuori dalla ZTL |

- **Hotel**: rosso senza la conferma della targa da parte dell'hotel, verde con la conferma.
- **Verifica a mano**: «Non ancora verificata a mano» non cambia mai il colore della risposta.

## 1. Preparazione (circa 15 minuti)

- [ ] Controlla gli strumenti: `xcodebuild -version`, `xcrun simctl list devices available`, `xcodegen --version`.
  - Se manca xcodegen: `brew install xcodegen`.
  - Per Android servono Android Studio e un emulatore (`emulator -list-avds`) e Gradle 8.10.2.
  - Se manca qualcosa di grosso, chiedi prima di installarlo.
- [ ] Aggiorna il ramo: `git fetch origin && git switch versione-2.0.2 && git pull --ff-only`.
- [ ] Prepara il progetto: `xcodegen generate`.
- [ ] Compila: `xcodebuild -project GateLR.xcodeproj -scheme GateLR -destination 'platform=iOS Simulator,name=iPhone 17' build`.

## 2. Prove automatiche (circa 45 minuti)

- [ ] Prove del motore: `xcodebuild test -project GateLR.xcodeproj -scheme GateLRTests -destination 'platform=iOS Simulator,name=iPhone 17'`.
- [ ] Prove a schermo (`UITests/DispositiviTests.swift` e `UITests/ScreenshotTests.swift`) con lo schema `GateLRUITests` su:
  - iPhone SE (3ª generazione);
  - iPhone 17;
  - iPhone 17 Pro Max;
  - iPad (A16).
- [ ] Rifai le stesse prove in tema scuro e con il testo più grande.
- [ ] Per ogni prova fallita:
  - rifalla una volta;
  - di' se fallisce sempre (errore dell'app) o solo a volte (simulatore lento);
  - allega la foto della schermata.
- [ ] `testD5Presentazione` a volte non trova «Salta», perché guarda lo schermo dopo 5 secondi fissi.
  - Rifalla 5 volte sull'iPad.
  - Poi prova ad aspettare «Salta» fino a 20 secondi (`skip.waitForExistence(timeout: 20)`) e rifalla altre 5 volte.
  - Mostra la modifica, senza fare commit.
- [ ] Android:
  - prove del motore: `gradle -p android/core test`;
  - compila l'app: `gradle -p android :app:assembleDebug`;
  - installala sull'emulatore.

## 3. Prove a mano, fatte da te sul simulatore (circa 1 ora)

Segui una per una le voci della **sezione 32 «2.0.2 (fiducia)»** di `docs/checklist-prova.md`.

- [ ] Per ogni voce usa il simulatore come farebbe una persona: tocchi, scorrimenti, ricerca, tema scuro, testo grande, lingue.
- [ ] Il link per l'hotel aprilo in Safari dentro il simulatore, senza l'app.
- [ ] Il sito provalo in Safari (`web/`, con `python3 -m http.server 8000`), da telefono e da computer, in EN, IT e DE.
- [ ] Per ogni voce scrivi riuscita, fallita o non provabile, sempre con il motivo e una foto.
- [ ] Se resta tempo, passa anche alle sezioni 31 e 30.

## Prova dal vivo (quando Ledion scrive «dal vivo»)

Ledion vuole vedere ogni clic in tempo reale, sul suo schermo.

- [ ] Usa il controllo del computer di Claude (computer use) sulla finestra del Simulatore, non le prove automatiche.
  - Se non è attivo, chiedi a Ledion di attivarlo nell'app Claude e di dare al Mac i permessi «Accessibilità» e «Registrazione schermo».
- [ ] Prima di cominciare:
  - apri il Simulatore in primo piano, grande e al centro dello schermo;
  - chiudi o metti da parte le altre finestre.
- [ ] Un passo alla volta:
  - scrivi in chat cosa stai per fare (per esempio «Tocco "Mandalo al tuo hotel"»);
  - fai il clic;
  - aspetta 1–2 secondi, così Ledion vede cosa succede;
  - scrivi in una riga cosa vedi e se è giusto.
- [ ] Per il sito usa Safari sul Mac o nel Simulatore, sempre visibile.
- [ ] Se Ledion scrive «fermo» o muove il mouse, fermati subito e aspetta.
- [ ] Le prove che dal vivo durano troppo (le stesse prove ripetute su tutti i dispositivi) lasciale alle prove automatiche del punto 2.

## 4. Foto

- [ ] Metti le schermate in `~/Desktop/GateLR-tester/<data>/`, fuori dal progetto.
  - Nomi del tipo `iphone-se-scuro-03-risposta.png`.
- [ ] Per quello che la 2.0.2 cambia, mostra il prima (ramo `main`) e il dopo (ramo `versione-2.0.2`) uno accanto all'altro.

## 5. Resoconto finale

Scrivi il resoconto con queste sezioni:

- **✅ Fatto**: le prove riuscite.
- **⚠️ Problemi**: ogni problema con dispositivo, passi, cosa succede, cosa dovrebbe succedere e la foto.
- **⏭️ Prossimi passi**, con i tempi.
- **❓ Decisioni per Ledion**.

Salva lo stesso resoconto in `~/Desktop/GateLR-tester/<data>/resoconto.md`. Ledion lo incolla nella chat principale.
