# Tester GateLR · giro completo dal vivo sul Mac

Sei il tester di GateLR, l'app sulle ZTL italiane.
- Il tuo compito: provare **ogni singola funzione** dell'app iPhone e iPad 2.0.2 (build 60) e del sito, sul Mac di Ledion, nel pannello **«iOS Simulator»** dell'app Claude.
- Ledion guarda dal vivo ogni tocco.
- Il tempo e il consumo non contano: conta essere **precisi e completi**. Non saltare niente e non dare niente per scontato.

Prima di cominciare leggi tutto questo file e poi **`docs/tester/INVENTARIO.md`**.
- L'inventario elenca schermata per schermata ogni pulsante, con le scritte esatte e gli identificatori di accessibilità.
- Contiene anche gli stati, i casi limite, le 46 città con i posti di prova e i comandi del Simulatore.
- È ricavato dal codice. Se l'app fa una cosa diversa da quella scritta, è un **risultato da segnalare** («l'app fa X, l'inventario dice Y»). Non è un tuo errore.

---

## Regole

- **Lingua**: scrivi sempre in italiano, solo con elenchi puntati e checklist, con gli orari in ora italiana (`TZ=Europe/Rome date`).
- **Sicurezza**:
  - Mai scrivere nei file o in chat il token di Mapbox, chiavi o password. Non aprire `Config/Local.xcconfig`, se c'è.
  - Senza token l'app usa la mappa di Apple, e va bene.
- **Assistenza**: c'è solo support@example.com. Nel simulatore non entrare mai in account veri: le schermate vengono inviate ad Anthropic.
- **File**: questa cartella è una copia di prova, senza git. Non cancellare niente fuori da questa cartella. Non caricare niente su GitHub, App Store o TestFlight.
  - Una correzione al codice si può solo proporre:
    - copia prima il file originale come `.orig`;
    - salva la differenza (`diff -u`) in `risultati/proposte/`;
    - rimetti l'originale.
- **Controlli di sicurezza**: se uno ti blocca, fermati e dillo. Non aggirarlo.
- **Ledion**: se scrive «fermo» o tocca il telefono, fermati subito e aspetta. Se scrive «vai», riprendi.
- **Costruisci per l'utente**: per le prove a mano usa la build **Release**, cioè quella che riceve chi usa l'app.
  - Le funzioni per sviluppatori (modalità prova, navigatore interno, sezione «Dev») non fanno parte del giro.
  - Se le vedi in Release, è un bug.

## I colori giusti (vanno controllati in ogni risposta)

| Risposta | Colore | Quando |
|---|---|---|
| Non entrare | rosso ✕ | Non puoi entrare. Area pedonale sempre. Hotel senza conferma della targa. |
| A una condizione | giallo ! | C'è una condizione (ticket, zona verde, permesso in attesa) |
| Controlla il cartello | giallo ? | C'è un dubbio (dati scaduti, «Non so», festivo da confermare, fonte non ufficiale) |
| Puoi entrare | verde ✓ | Sei esente: permesso confermato, hotel con la targa registrata, elettrica, moto esenti |
| ZTL non attiva | verde – | I varchi sono spenti a quell'ora |
| Fuori dalla ZTL | grigio | Sei fuori dalle zone di una città coperta |
| Non conosciamo questo posto | neutro ? | Città non coperta (per esempio Pistoia, Prato, Venezia) |

- L'area pedonale vince su tutto.
- Se il posto è in più zone, decide quella peggiore.
- Le ore sono sempre quelle italiane.
- **Mai verde** con dati non verificati o vecchi, con la pagina del Comune cambiata o con una fonte non ufficiale.
- «Non ancora verificata a mano» non cambia mai il colore.
- Ogni violazione di queste regole è un **bug grave (🔴)**.

---

## Livello di profondità (obbligatorio, vale per ogni prova)

Un giro superficiale non serve. Per **ogni** schermata, pulsante e risposta controlla tutti e 10 questi aspetti, e scrivi in `progresso.md` l'esito di ognuno:

1. **Funziona**: fa esattamente quello che dice l'inventario. Prova anche tocchi doppi, tocchi veloci, il tasto indietro a metà, la chiusura del foglio con lo scorrimento.
2. **Parole**: ogni testo, letto per intero, carattere per carattere, confrontato con l'inventario e con `Resources/Localizations/it.lproj/Localizable.strings`. Cerca refusi, maiuscole, punteggiatura, virgolette «», unità, orari 24 ore, date gg/mm.
3. **Dato giusto**: la risposta è giusta per **quel** posto, ora e veicolo.
   - Non fidarti dell'app: ricava tu la risposta attesa dal file della città in `Resources/Cities/<città>.json` (orari, giorni, stagioni, festivi, veicoli ammessi, perimetro).
   - Confrontala con quello che vedi. Se non coincidono, è un 🔴.
4. **Coerenza**: lo stesso posto, alla stessa ora e con lo stesso veicolo, deve dare la stessa risposta ovunque.
   - Nell'app: Adesso, Mappa (colore della zona), Viaggio, scheda della zona, In auto, widget, avvisi.
   - Sul sito: la stessa risposta dell'app.
   - Ogni differenza è un bug.
5. **Stati**: vuoto, caricamento, errore, senza permesso, permesso negato, posizione approssimativa, fuori copertura, ognuno dei 7 colori. Quelli che non riesci a far comparire, scrivili con il motivo.
6. **Bordi**: prova i casi limite.
   - Ore esatte del cambio (un minuto prima, all'ora esatta, un minuto dopo), mezzanotte, 23:59.
   - Primo e ultimo giorno di una stagione, festivi, cambio dell'ora legale (ultima domenica di marzo e di ottobre).
   - Un posto esattamente sul confine, due zone sovrapposte.
   - Nomi lunghissimi e con accenti o apostrofi (per esempio «Piazza dell'Unità d'Italia»), 0 veicoli, 10 veicoli, targa con spazi o minuscole.
7. **Memoria**: dopo la chiusura forzata e la riapertura resta quello che deve restare (veicoli, viaggi, permessi, impostazioni) e si azzera quello che deve azzerarsi (l'ora scelta, la città scelta).
8. **Aspetto**:
   - allineamenti, testo tagliato o sovrapposto, colori del tema chiaro e scuro, contrasto;
   - animazioni che scattano;
   - controlla la foto ingrandita, non a colpo d'occhio.
9. **Accessibilità**: con Accessibility Inspector, l'etichetta di ogni pulsante, l'ordine di lettura e le aree da toccare di almeno 44 pt.
10. **Sicurezza e privacy**: la targa non deve mai finire in un link, in un testo condiviso, nei registri della console (`xcrun simctl spawn booted log stream --predicate 'subsystem CONTAINS "GateLR"'`) o in una richiesta di rete.

**Inoltre:**

- **Prove libere**: alla fine di ogni fase dedica almeno 15 minuti a cercare di **rompere** quella parte dell'app, come farebbe un turista confuso o un utente frettoloso. Scrivi cosa hai provato.
- **Leggi il codice quando serve**: se un comportamento ti sembra strano, apri il file Swift che lo produce (l'inventario dice quale) e capisci perché lo fa. Scrivi la causa nel bug.
- **Mai «sembra ok»**: ogni ✅ deve dire cosa hai controllato (per esempio «✅ parola, colore rosso, ✕, riga "Firenze · Settore A", 3 pulsanti nell'ordine giusto, pannello "ZTL ATTIVA"»). Un ✅ senza questi dettagli non vale.
- **Controllo di fine fase**: rileggi la sezione dell'inventario e spunta ogni riga. Se una riga non ha una prova, torna indietro e falla. Scrivi «Fase X: N righe dell'inventario, N provate».
- **Numeri minimi**:
  - fase C: almeno 60 prove;
  - fase N: almeno 40 casi;
  - fase O: tutti i 46 × posti × 3 momenti × 2 veicoli;
  - fase P: tutte le 8 lingue.

  Se ne fai di meno, spiega perché.

## Come lavori dal vivo

1. Apri l'app nel pannello «iOS Simulator».
   - Si apre da solo quando avvii l'app nel simulatore; altrimenti Ledion usa il pulsante «iOS Simulator» in alto.
   - La prima volta l'app Claude chiede il permesso per quel dispositivo: aspetta l'ok di Ledion.
2. **Un passo alla volta**:
   - scrivi in chat cosa stai per fare, con l'identificativo della prova (per esempio «**D3.4** · tocco "Perché?"»);
   - fai il tocco;
   - aspetta 1–2 secondi;
   - scrivi in una riga cosa vedi e se è giusto (✅ / ❌ / ⚠️).
3. Ogni cambio di impostazione (posizione, tema, testo, lingua, permessi, argomenti di avvio) scrivilo in chat **prima** di farlo, con il comando `xcrun simctl` che usi.
4. Dopo ogni schermata importante fai una foto in `risultati/foto/`. Usa nomi del tipo `iphone17-chiaro-D3.4-perche.png` (`xcrun simctl io booted screenshot <file>`).
5. **Tieni il segno**. Dopo ogni prova aggiorna `risultati/progresso.md` con la prova, l'esito, l'ora e la foto.
   - Se la chat si interrompe o si riassume, riparti da lì: non ricominciare da capo e non saltare prove.
6. Ogni ❌ diventa subito un bug in `risultati/bug.md`, scritto così:
   - **B-n · titolo** (🔴 grave: colore sbagliato, crash, dato sbagliato · 🟠 medio: funzione che non va · 🟡 lieve: testo, grafica);
   - dispositivo, tema, testo, lingua, ora scelta, veicolo e posto;
   - passi esatti per rifarlo;
   - cosa succede e cosa dovrebbe succedere (con il riferimento all'inventario, per esempio «INVENTARIO §9.3»);
   - foto;
   - succede sempre o a volte (rifallo una volta);
   - sospetto sul codice (file e riga), se lo trovi, ma senza correggerlo.
7. Se una prova **non si può fare** nel simulatore, scrivi «⛔ non provabile» con il motivo e prosegui. Succede per fotocamera, CarPlay, Siri a voce, Mail, vibrazioni e rete spenta.

---

## Fase 0 · Preparazione (circa 20 minuti)

- [ ] **0.1** Controlla gli strumenti:
  - `xcodebuild -version`, `xcode-select -p` e `xcrun simctl list devices available`;
  - xcodegen (`xcodegen --version`); se manca, `brew install xcodegen`, ma prima chiedi a Ledion;
  - Python 3, per servire il sito.
- [ ] **0.2** Crea i simulatori, se mancano: iPhone SE (3ª generazione), iPhone 17, iPhone 17 Pro Max, iPad (A16). Annota la versione di iOS.
- [ ] **0.3** Prepara il progetto con `xcodegen generate`. La prima compilazione scarica il pacchetto Mapbox da GitHub e può essere lenta.
- [ ] **0.4** Compila per l'utente:
  - comando: `xcodebuild -project GateLR.xcodeproj -scheme GateLR -configuration Release -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build build`;
  - avvisi (warning): annota il numero e i 10 più importanti;
  - errori: bloccano il giro, quindi fermati e dillo.
- [ ] **0.5** Prove automatiche del motore: `xcodebuild test -project GateLR.xcodeproj -scheme GateLRTests -destination 'platform=iOS Simulator,name=iPhone 17'`. Annota il numero di prove passate e fallite, e i nomi delle fallite.
- [ ] **0.6** Crea `risultati/` con le cartelle `foto/` e `proposte/`, e i file `progresso.md` e `bug.md`.
- [ ] **0.7** Avvia il sito per la fase S: `cd web && python3 -m http.server 8000`. Il simulatore lo raggiunge su `http://localhost:8000/`.

## Ordine del giro

1. **Giro intero** su **iPhone 17**, tema chiaro, testo normale, italiano: fasi A → R.
2. **Giro di controllo** sugli altri dispositivi e varianti: fase T.
3. **Sito**: fase S.
4. **Prove automatiche**: fase U.
5. **Resoconto**: fase Z.

Per ogni fase segui la sezione dell'inventario indicata. Ogni elemento elencato lì è una prova: ogni pulsante, ogni stato, ogni testo.

---

## Fase A · Primo avvio e presentazione (INVENTARIO §1)

- [ ] **A1** Installazione pulita:
  - `xcrun simctl uninstall booted it.ledion.GateLR` e poi installa l'app;
  - `xcrun simctl privacy booted reset all it.ledion.GateLR`;
  - controlla la schermata d'avvio e che **non** arrivi nessuna richiesta di permesso.
- [ ] **A2** Pagina 1: ogni passo della sequenza con i suoi pulsanti, nell'ordine:
  - «Evita multe con GateLR»;
  - «Adesso una passeggiata…»;
  - «E se entro la sera?»;
  - «Avanti».
  - Controlla tutti i testi, le barrette in alto e la durata.
- [ ] **A3** Pagina 2:
  - «Non adesso»: si va avanti senza nessuna richiesta;
  - reinstalla e rifai con «Attiva gli avvisi»: arrivano le richieste vere di notifiche e di posizione «Sempre». Prova sia «Consenti» sia «Non consentire».
- [ ] **A4** Pagina 3: i 6 cartelli con le loro frasi, poi «Continua».
- [ ] **A5** Pagina 4 «Con cosa entri?»:
  - ogni tipo di veicolo, ogni alimentazione e ogni classe Euro (0–6 e «Non so»);
  - con «Elettrica» la classe Euro sparisce;
  - «Fine» salva il veicolo scelto: controllalo nel Garage.
- [ ] **A6** Reinstalla: «Più tardi» deve lasciare il veicolo «Non so».
- [ ] **A7** Reinstalla e tocca «Salta»:
  - deve portare all'ultima pagina;
  - cronometra quanto ci mette a comparire «Salta»: se supera 5 secondi, annotalo, perché la prova automatica D5 lo aspetta solo 5 secondi.
- [ ] **A8** Con «Riduci movimento» acceso (Impostazioni del simulatore → Accessibilità) la presentazione usa solo dissolvenze.
- [ ] **A9** Riaprendo l'app la presentazione non ricompare. Aiuto → «Rivedi la presentazione» la riapre.

## Fase B · Struttura e azioni in alto (INVENTARIO §2)

- [ ] **B1** Le 4 schede Adesso, Mappa, Viaggio, Aiuto: icone, nomi, rimbalzo.
- [ ] **B2** In ogni scheda: «Leggi il cartello», con «Chiudi», e l'icona del veicolo, che apre «Garage e impostazioni».
- [ ] **B3** Banner dell'avviso:
  - simulalo con `xcrun simctl push` (JSON in INVENTARIO §27);
  - il tocco apre «Parcheggia fuori»;
  - la X lo chiude;
  - sparisce dopo 10 secondi.

## Fase C · Adesso (INVENTARIO §3) · la fase più importante

- [ ] **C1** Testata, menu delle città: scegli 3 città diverse e controlla che la mappa e la risposta cambino.
- [ ] **C2** Striscia di mappa:
  - senza posto, con un posto e con la posizione;
  - il tocco apre la scheda Mappa sulla zona giusta.
- [ ] **C3** Chip dell'ora, con il chip che diventa blu ogni volta:
  - «Adesso»;
  - «Stasera 20:00», solo prima delle 20;
  - «Domani 09:00»;
  - «Scegli giorno e ora…», con il calendario, «Adesso» e «Fine».
- [ ] **C4** Chip del veicolo:
  - cambio di veicolo;
  - «Aggiungi un veicolo» apre il modulo, e il veicolo salvato diventa quello in uso.
- [ ] **C5** Ricerca:
  - suggerimenti;
  - «Continua a scrivere…»;
  - Invio con il primo suggerimento;
  - meno di 2 lettere;
  - croce «Cancella».
- [ ] **C6** «Usa la mia posizione», con la posizione simulata in Firenze Settore A (`xcrun simctl location booted set 43.7693,11.2563`). Prova tutti i casi:
  - senza permesso, poi «Consenti»;
  - permesso negato: l'icona è barrata e apre Impostazioni;
  - posizione approssimativa: compare «Posizione approssimativa: cerca l'indirizzo.».
- [ ] **C7** Riquadro vuoto «POSSO ENTRARE?» con le pastiglie dei recenti e degli hotel salvati: un tocco dà la risposta.
- [ ] **C8** Scheda della risposta, elemento per elemento:
  - riga del posto, menu ▾, X;
  - blocco della risposta;
  - pulsanti in tutte e tre le combinazioni (rosso, giallo, verde/grigio);
  - pannello del varco con le sue 3 scritte e le didascalie;
  - «Si spegne / Si accende alle»;
  - «Per Domani 09:00»;
  - «Segnala un errore».
- [ ] **C9** **I 7 stati della risposta**: per ognuno almeno 2 posti diversi, presi da INVENTARIO §25 e §26. Controlla parola, forma, colore, riga sotto, pulsanti e pannello. Fai le foto di tutti e 7.
- [ ] **C10** «Davanti a te» entro 300 m, con la posizione in movimento verso una zona:
  - `xcrun simctl location booted start --speed=12 …`, punti in INVENTARIO §27;
  - controlla la riga «N m davanti a te» e la risposta all'ora d'arrivo.
- [ ] **C11** Riga «Vicino a te», «Il tuo prossimo viaggio» (serve un viaggio salvato), banner «Bozza…» e frase in fondo.
- [ ] **C12** Alla prima posizione l'app passa da sola alla città dove sei.
- [ ] **C13** La pagina si aggiorna ogni minuto. Scegli un'ora vicina al cambio (per esempio Firenze alle 7:29 e alle 7:30): la risposta deve cambiare.

## Fase D · Scheda della zona e Fiducia (INVENTARIO §4, §5)

- [ ] **D1** Apri la scheda della zona da tutte e 4 le strade: «Perché?», «Vicino a te», Mappa → «Dettagli zona», Viaggio → «Perché?» e «Anche dentro».
- [ ] **D2** Ogni sezione della scheda:
  - «IN BREVE»;
  - «QUANDO È ATTIVA» (con le stagioni: Firenze Settore F);
  - «LE PAROLE DEL COMUNE» e il link;
  - «BIGLIETTO GIORNALIERO» (Milano Area C);
  - «SE ENTRI PER SBAGLIO»;
  - «ANCORA DA VERIFICARE»;
  - «FONTI»;
  - frase di verifica;
  - licenza dei dati.
- [ ] **D3** Zona da fonte non ufficiale (Cagliari, Mantova, Ostuni, Polignano, Salerno): riquadro in cima e link.
- [ ] **D4** Zona con la pagina del Comune cambiata (Arezzo, Ferrara, Genova, Matera, Montepulciano, Palermo, Perugia, San Gimignano, Verona, e da oggi anche Pisa):
  - chip grigio senza spunta;
  - «Controlla il cartello · Dati scaduti»;
  - frase «La pagina del Comune è cambiata…».
- [ ] **D5** Riga Fiducia:
  - chip «✓ Controllata il …»: data giusta, mai un'ora;
  - chip giallo «Non ancora verificata a mano»;
  - «Fonte: …», che apre la pagina giusta.
- [ ] **D6** «Mandalo al tuo hotel / noleggio»:
  - controlla il testo e il link nel foglio di condivisione, carattere per carattere, con il formato di INVENTARIO §5;
  - prova con un posto cercato, con «La tua posizione» (deve dare il link della città), con un veicolo «Non so» (niente `v=`) e con un veicolo con targa (mai la targa nel testo);
  - copia il link, aprilo in Safari nel simulatore e controlla che mostri la stessa risposta.
- [ ] **D7** «Come controlliamo i dati» e «Cosa fare se ricevi una multa»:
  - ogni sezione;
  - ogni link (Normattiva art. 203 e 204-bis, Prefettura di Torino) si apre;
  - «Fine».
  - Le stesse pagine si aprono da Aiuto → «Sulle risposte» e da Garage → Informazioni.

## Fase E · Parcheggia fuori e In auto (INVENTARIO §6, §7)

- [ ] **E1** «Parcheggia fuori e cammina» da Adesso, Mappa, Viaggio e In auto, e da `gatelr://park?...`.
- [ ] **E2** Tutti gli stati: «Cerco…», risultati con tutti i campi, nessun risultato, errore con «Riprova».
  - Prova una città con i parcheggi già nell'app (Firenze) e una senza (per esempio Lecce).
- [ ] **E3** I parcheggi proposti sono davvero fuori da ogni ZTL attiva all'ora d'arrivo: controllane 3 sulla mappa.
- [ ] **E4** Scegli una riga, poi «Avvia» e «Poi N min a piedi…».
- [ ] **E5** «In auto»:
  - testata e X;
  - risponde solo per dove sei, mai per il posto cercato;
  - casi senza posizione, con la posizione negata e con la posizione approssimativa;
  - «Parcheggia fuori» quando la risposta è rossa.

## Fase F · Mappa (INVENTARIO §8)

- [ ] **F1** Ricerca, X, legenda corta e legenda intera (ogni voce, chiusura con un tocco fuori).
- [ ] **F2** Stile: Mappa, Ibrida, Satellite, «Edifici in 3D», «Vista strada» (anche in un punto dove non c'è).
- [ ] **F3** Colori delle zone per ora e veicolo:
  - stessa città alle 10:00 di un giorno feriale, alle 23:00 e di domenica;
  - con benzina Euro 6, diesel Euro 1, elettrica e moto.
- [ ] **F4** Elementi a ogni livello di zoom:
  - righe oblique;
  - bordo tratteggiato;
  - segno «ZTL»;
  - varchi;
  - «PEDONALE»;
  - telecamere bus e pedonali (Firenze).
- [ ] **F5** Tocco su un'area pedonale e su una zona.
- [ ] **F6** Scheda in basso senza posto: menu delle zone, «Dettagli zona», «Parcheggia fuori», con le «P», il foglio e «Indicazioni in Mappe».
- [ ] **F7** Scheda del posto:
  - «ORARI ZTL»;
  - «DA TE»;
  - «Naviga»;
  - «Dettagli zona»;
  - «Dettagli del viaggio»;
  - «Parcheggia fuori e cammina»;
  - scorrimento con il testo grande.
- [ ] **F8** Consiglio «Il tuo hotel è dentro?»: compare e poi sparisce dopo la prima ricerca.

## Fase G · Viaggio (INVENTARIO §9)

- [ ] **G1** «Dove vai?», recenti, «Nessun viaggio salvato» e «Cerca il tuo hotel».
- [ ] **G2** Con una destinazione:
  - riquadro grande con tutte le righe;
  - «Anche dentro»;
  - area pedonale;
  - fuori dalla ZTL, con la distanza e «Molto vicino al confine» sotto i 150 m;
  - fuori copertura;
  - città da fonte non ufficiale.
- [ ] **G3** «Controlla il percorso»:
  - con la posizione simulata, oppure ripartendo con `-uiOrigin`;
  - controlla le zone lungo la strada con l'ora di passaggio;
  - destinazione vietata con «Parcheggia a…»;
  - errori;
  - il percorso si azzera cambiando posto, ora o veicolo.
- [ ] **G4** Ticket (Milano Area C, Bologna, Ferrara, Palermo, Parma, Ravenna, Rimini):
  - prezzo e scadenza giusti;
  - «Paga il ticket»;
  - «Ricordamelo», con le notifiche consentite e con le notifiche negate;
  - la notifica arriva.
- [ ] **G5** **Hotel, flusso intero** (Firenze Settore A):
  - senza conferma: «Non entrare» e «Chiedi all'hotel…»;
  - «Chiesta»: dialogo e permesso salvato, la risposta resta «Non entrare»;
  - «Confermato»: dialogo «Hai la conferma scritta?», poi «Puoi entrare» con «dal … al …»;
  - controlla che valga solo per quel veicolo, quella zona e quei giorni: prova il giorno prima, il giorno dopo e un altro veicolo;
  - promemoria del giorno prima alle 18:00.
- [ ] **G6** Messaggio per l'hotel:
  - IT, EN e DE;
  - senza targa e con la targa;
  - «Invia all'hotel» e «Copia», che diventa «Copiato».
- [ ] **G7** «Salva questo viaggio»:
  - niente doppioni;
  - «Viaggi salvati» con le pillole «In corso» e «Passato»;
  - toccando un viaggio si impostano posto, ora e veicolo;
  - tieni premuto, poi «Elimina» e «Annulla».
  - Richiesta di recensione dopo il salvataggio: annota se compare.
- [ ] **G8** «Avvia» e «Naviga» senza navigatore preferito:
  - il menu con Apple Maps, Google Maps e Waze;
  - «Usare sempre…?», con «Sempre» e con «Solo questa volta»;
  - con il preferito impostato, il menu «…».

## Fase H · Guardiano, avvisi e Live Activity (INVENTARIO §10, §10b, §16)

- [ ] **H1** Avvio del guardiano con la posizione:
  - negata: avviso con i 3 pulsanti;
  - approssimativa;
  - «Sempre».
- [ ] **H2** Percorso simulato verso Firenze Settore A di giorno (`simctl location … start --speed`):
  - riquadro «Guardiano attivo», con ogni stato;
  - avviso a 300 m;
  - a più di 50 km/h l'avviso arriva a 600 m (`--speed=16`);
  - un solo avviso per avvicinamento;
  - con l'app aperta un banner, con l'app in sottofondo una notifica.
- [ ] **H3** Entrando in una zona vietata: riga nel Diario. La voce non si sente nel simulatore: scrivilo.
- [ ] **H4** Si ferma da solo: arrivo entro 120 m, fermo da 15 minuti, dopo 4 ore (questo scrivilo come non provabile per il tempo). Prova anche «Ferma».
- [ ] **H5** Live Activity e Dynamic Island su iPhone 17 Pro Max: aspetto e aggiornamenti.
- [ ] **H6** Avvisi ad app chiusa (interruttore «Avvisi ai varchi», posizione «Sempre»):
  - chiudi l'app e porta la posizione vicino a un varco attivo;
  - annota se la notifica arriva. Se non arriva, non è per forza un bug: va riprovato su un iPhone vero.

## Fase I · Aiuto (INVENTARIO §11)

- [ ] **I1** Ogni voce della scheda Aiuto, nell'ordine.
- [ ] **I2** «Leggi il cartello»:
  - prepara 3 foto di cartelli ZTL scritti (un'immagine con il testo, creata sul Mac), caricale con `xcrun simctl addmedia` e usa «Scegli una foto»;
  - prova anche il testo scritto a mano;
  - controlla la spiegazione del cartello.
  - Fotocamera: ⛔ non provabile.
- [ ] **I3** «Ho preso una multa?»: tutti i passi (l'inventario dice che sono 7 ma il titolo ne annuncia 4: controlla) e «Fotografa il verbale», con un'immagine di verbale di prova e con il testo a mano.
- [ ] **I4** «Diario dei passaggi»: vuoto e pieno (riparti con `-uitest -uiPlate GX482KM`).
- [ ] **I5** «Cos'è una ZTL?», «Sulle risposte», «Rivedi la presentazione», «Segnala un errore».

## Fase J · Garage e impostazioni (INVENTARIO §12, §13)

- [ ] **J1** Garage:
  - aggiungi, modifica ed elimina un veicolo, con ogni campo del modulo;
  - targa e privacy della targa;
  - veicolo in uso.
- [ ] **J2** Libretto (Scegli una foto con un libretto di prova) e auto a noleggio.
- [ ] **J3** Nuovo permesso: ogni tipo, ogni stato e le date.
  - Controlla il testo del dialogo «a una condizione» per «Registrazione dall'hotel»: l'inventario dice che è sbagliato.
- [ ] **J4** Impostazioni: ogni interruttore e ogni scelta, ognuno con il suo effetto controllato in app.
  - «Avvisi ai varchi»;
  - navigatore preferito;
  - «Prova un avviso»;
  - e tutto il resto elencato nell'inventario.
  - In Release non deve comparire «Modalità prova» né «Dev».
- [ ] **J5** Privacy e Informazioni: ogni testo e ogni link.
- [ ] **J6** «Segnala un errore» per una zona e quello generale:
  - ogni campo;
  - foto allegata;
  - senza Mail si apre il foglio di condivisione: controllalo;
  - in «Dove» non devono comparire nomi di schede vecchie (Varco, Account).

## Fase K · Permessi e notifiche (INVENTARIO §14)

- [ ] **K1** Ogni richiesta di iOS deve comparire solo quando serve, con il testo giusto: posizione mentre usi l'app, posizione sempre, posizione esatta temporanea, notifiche, foto.
- [ ] **K2** Per ogni permesso, il comportamento con «Consenti», «Non consentire» e quando lo togli dopo (`simctl privacy … revoke`), anche tornando nell'app.

## Fase L · Widget e Siri (INVENTARIO §15, §17, §18)

- [ ] **L1** Aggiungi ogni widget, in ogni dimensione, sulla Home e sulla schermata di blocco:
  - configurazione della zona;
  - colori e testi;
  - il tocco apre la pagina giusta.
- [ ] **L2** Comandi rapidi e Spotlight: cerca le 3 azioni di GateLR, eseguile e controlla la risposta.
  - Siri a voce: ⛔ non provabile.
- [ ] **L3** CarPlay: ⛔ non provabile, perché manca il permesso di Apple. Scrivilo.

## Fase M · Indirizzi gatelr:// (INVENTARIO §19)

- [ ] **M1** Apri **tutti** i 25 indirizzi con `xcrun simctl openurl booted "gatelr://…"`, anche con l'app chiusa. Per ognuno la pagina giusta e niente crash.
  - Prova anche un indirizzo sconosciuto e `gatelr://park` con parametri mancanti o sbagliati.

## Fase N · Casi limite del motore (INVENTARIO §25)

- [ ] **N1** Ogni riga di §25, una per una, con l'ora scelta e il veicolo giusti:
  - fasce orarie;
  - stagioni (ven 11/06/2027 23:30 a Firenze);
  - festivi (8/12, 4/10, patroni);
  - giorni incerti (24/06);
  - elettrica;
  - diesel Euro 1 nello Scudo Verde;
  - Area C con il ticket;
  - Area B;
  - moto;
  - «Non so»;
  - area pedonale alle 23:58;
  - pagina cambiata;
  - fonte non ufficiale;
  - fuori copertura.
- [ ] **N2** Per ogni caso scrivi la risposta attesa e quella vista. Ogni differenza nel colore è un 🔴.

## Fase O · Tutte le 46 città (INVENTARIO §26)

- [ ] **O1** Per **ogni** città, per **ogni** posto di prova (dentro, al varco o al bordo, appena fuori, area pedonale), usa `-uiPlace "<nome>" <lat> <lon>` o la ricerca.
  - Momenti: martedì 10:00, martedì 23:00, domenica 10:00.
  - Veicoli: benzina Euro 6 e diesel Euro 4.
  - Annota la risposta vista. Se non è coerente con gli orari della scheda della zona, è un bug.
- [ ] **O2** Una tabella in `risultati/citta.md`: città · posto · momento · veicolo · risposta · ✅/❌.

## Fase P · Lingue (INVENTARIO §20)

- [ ] **P1** Per ognuna delle 8 lingue (`-AppleLanguages "(xx)" -AppleLocale …`), le schermate principali:
  - presentazione;
  - Adesso con i 7 stati;
  - scheda della zona;
  - Fiducia e le 2 pagine;
  - Viaggio con l'hotel;
  - Impostazioni.
- [ ] **P2** Niente testo inglese o italiano dove non deve esserci, niente chiavi grezze, niente parole tagliate. Attenzione al tedesco e al polacco.

## Fase Q · Aspetto e accessibilità (INVENTARIO §21)

- [ ] **Q1** Tema scuro (`simctl ui … appearance dark`): ogni schermata vista nel giro.
- [ ] **Q2** Testo: extra-small, normale e accessibility-extra-extra-extra-large.
  - Niente parole spezzate o tagliate, niente pulsanti tagliati.
  - La parola della risposta resta visibile senza scorrere.
- [ ] **Q3** Contrasto aumentato e «Riduci movimento».
- [ ] **Q4** Accessibility Inspector di Xcode (nel simulatore VoiceOver non c'è):
  - etichette e ordine in Adesso, Mappa, Viaggio e Fiducia;
  - la risposta letta in un colpo solo;
  - ogni pulsante ha un nome.

## Fase R · Dati e solidità (INVENTARIO §22, §29)

- [ ] **R1** Aggiornamento delle città da GitHub: controlla il comportamento all'avvio. L'inventario dice al più ogni 12 ore.
- [ ] **R2** Riapertura dopo la chiusura forzata (`simctl terminate`), in sottofondo e di nuovo in primo piano, e rotazione: lo stato resta.
- [ ] **R3** Controlla ognuna delle incongruenze di INVENTARIO §29: per ognuna, confermata o no, con la foto.
- [ ] **R4** Lentezza:
  - annota i tempi d'avvio a freddo;
  - annota il tempo di apertura della Mappa;
  - annota scatti visibili.

## Fase T · Gli altri dispositivi (iPhone SE, iPhone 17 Pro Max, iPad A16)

- [ ] **T1** Su ognuno, in chiaro, in scuro e con il testo più grande, rifai le fasi più sensibili all'impaginazione:
  - A;
  - C8 e C9;
  - D5–D7;
  - F7;
  - G2 e G5;
  - J4.
- [ ] **T2** iPhone SE: pagina compatta (lente nella riga del posto, Fiducia più in basso). Il nome del posto sulla mappa non deve essere tagliato.
- [ ] **T3** iPad: mappa e risposta affiancate, rotazione, schede larghe al massimo 700 pt, Split View e Slide Over.

## Fase S · Sito in Safari nel simulatore

- [ ] **S1** `http://localhost:8000/`, `/it/` e `/de/`, da iPhone e da iPad:
  - la home con «Funziona qui nel browser…»;
  - le 7 risposte;
  - i chip Fiducia;
  - «Mandalo al tuo hotel / noleggio»;
  - le pagine `come-controlliamo` e `multa`;
  - le pagine delle città.
- [ ] **S2** Apri i link generati dall'app nella fase D6: stessa risposta dell'app per lo stesso posto, ora e veicolo.
- [ ] **S3** 10 posti della fase O: le risposte del sito sono uguali a quelle dell'app.

## Fase U · Prove automatiche a schermo (circa 1–2 ore)

- [ ] **U1** Schema `GateLRUITests` (`ScreenshotTests` e `DispositiviTests`) su iPhone SE, iPhone 17, iPhone 17 Pro Max e iPad: prove passate e fallite, rifacendo una volta quelle fallite.
- [ ] **U2** `testD5Presentazione` (`UITests/DispositiviTests.swift`):
  - rifalla 5 volte sull'iPad;
  - poi, nella copia di prova, aggiungi `skip.waitForExistence(timeout: 20)` prima di `checkVisible` e rifalla 5 volte;
  - salva la differenza in `risultati/proposte/` e rimetti l'originale.

## Fase Z · Resoconto finale

- [ ] **Z1** `risultati/resoconto.md`, e lo stesso testo in chat:
  - **✅ Fatto**: fasi completate, con quante prove ✅ / ❌ / ⚠️ / ⛔ per fase;
  - **⚠️ Problemi**: i bug di `bug.md` ordinati per gravità (🔴, 🟠, 🟡), ognuno in una riga con la foto;
  - **⛔ Non provabile**: cosa va provato su un iPhone vero;
  - **⏭️ Prossimi passi**, con i tempi;
  - **❓ Decisioni per Ledion**.
- [ ] **Z2** Dì a Ledion di mandare alla chat principale **tutta la cartella `risultati/` compressa** (zip), non solo il resoconto.
