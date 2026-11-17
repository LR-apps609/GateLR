# GateLR iOS 2.0.2 (build 60) · Inventario completo delle funzioni da provare

Fonte: il codice della worktree `wt-fiducia`, ramo `versione-2.0.2` (commit aebdf7f2), letto il 17/11/2026. Non i vecchi documenti.
Le etichette sono quelle italiane di `Resources/Localizations/it.lproj/Localizable.strings` (la chiave inglese nel codice è
tradotta). Tra parentesi quadre l'`accessibilityIdentifier`, quando c'è. «🖥️» = si prova nel Simulatore; «📱» = solo su iPhone vero;
«🚫» = non raggiungibile dall'interfaccia normale.

---

## 0. Prima di cominciare (build, configurazione, cosa cambia tra Debug e Release)

- **Versione**: `MARKETING_VERSION 2.0.2`, `CURRENT_PROJECT_VERSION 60`; iOS minimo 17.0; iPhone e iPad (`TARGETED_DEVICE_FAMILY 1,2`).
- **Bundle id**: app `it.ledion.GateLR`, widget `it.ledion.GateLR.Widget`; App Group `group.it.ledion.GateLR`; entitlement «notifiche
  urgenti» (time-sensitive). **Nessun** entitlement CarPlay, **nessun** `aps-environment` (push remote), nessun acquisto in-app.
- **Schema `GateLR`**: Run in **Release** (con «Simulate location» permesso), test UI in **Debug**.
- **Strumenti di sviluppo** (`AppConfig.devTools`): sempre accesi in **Debug**; in **Release** solo con `GATELR_DEV_TOOLS = YES` in
  `Config/Local.xcconfig`. In questa worktree `Config/Local.xcconfig` **non c'è** (c'è solo `Local.xcconfig.example`): una build Release
  da qui NON mostra modalità prova né navigatore interno. Per vederli: `xcodebuild … -configuration Debug`. Si capisce subito: in
  Impostazioni compare la sezione «Modalità prova» e la sezione «Dev».
- **Mapbox**: il token arriva da `Config/Local.xcconfig` (`MBXAccessToken`). Senza token (`NotteMap.hasToken` falso) la striscia di Adesso
  usa la mappa di Apple, la presentazione usa MapKit; la Mappa è sempre MapKit. Con token: striscia 3D Mapbox (scheletro fermo finché
  non è pronta; dopo 5 s di errore passa a Apple).
- **Recensione**: «Lascia una recensione» compare solo se `APP_STORE_ID` è un numero (oggi vuoto in `Base.xcconfig` → 🚫 nascosto).
- **Email di assistenza**: `support@example.com` (segnaposto).
- **Dati delle città**: 46 città dentro l'app (`Resources/Cities`, manifest `202611110626`), tutte `status: draft` («Bozza»); letture
  (`checkedOn`) tra il 23/10 e il 07/11/2026 → oggi «freschi» (soglia 120 giorni: diventano «Dati scaduti» dal ~20/02/2027).

---

## 1. Avvio

### 1.1 Schermata d'avvio
- Fondo `LaunchBackground` blu e logo al centro (`LaunchSplash`), finché le città non sono lette in sottofondo. VoiceOver: «GateLR».
- Al primo avvio NESSUNA richiesta di permesso (né posizione né notifiche): si chiedono solo quando servono (vedi §14).
- All'avvio vengono chiuse le Live Activity rimaste da un'esecuzione precedente (`Guardian.endOrphanActivities`).
- Controllo dei dati città su GitHub al più ogni 12 ore (§22).

### 1.2 Presentazione 2.0 (`Intro2View`, a tutto schermo, sempre tema scuro)
**Quando compare**: primo avvio (`onboarded` falso) oppure se la versione vista `introVersionSeen` < 2 (anche chi aggiorna da < 2.0, una volta).
Poi mai più da sola. Con `-intro2` sempre; con `-uitest` mai (tranne `-showOnboarding` + `-onboarded NO`). Dall'app: Aiuto → «Rivedi la presentazione».

In alto: barrette di avanzamento (pagine 1–3, durate 28 s / 7 s / 9 s) e **«Salta»** [`intro2.skip`] → va direttamente all'ultima pagina.
Con «Riduci movimento»: dissolvenze, camera ferma, l'auto non corre.

1. **Pagina 1 · «La strada più diretta»** (animazione su Firenze, Settore A+B, varco di via Vittorio Alfieri, viale Gramsci → Mercato
   Centrale). Sequenza con pulsanti:
   - fine del tragitto → riquadro «VERBALE» «Accesso in ZTL senza permesso» «Per ogni giorno in cui entri. Arriva mesi dopo.» +
     **«Evita multe con GateLR»** [`intro2.avoid`]
   - «Con GateLR» / suggerimento «GateLR: parcheggia fuori dalla ZTL» → **«Adesso una passeggiata…»** [`intro2.park`]
   - «Poi due passi a piedi», «N min a piedi, nessuna multa» → **«E se entro la sera?»** [`intro2.evening`]
   - «E la sera?» con orologio [`intro2.clock`], cartello «VARCO SPENTO», «Alle %@ il varco è spento: puoi entrare.» «Ogni ZTL ha i suoi
     orari: GateLR te li dice prima di partire.» [`intro2.evening.card`] → **«Avanti»** [`intro2.next1`]
   - mappa: Mapbox se c'è il token, altrimenti MapKit (`-intro2MapKit`), oppure un disegno senza rete (`-intro2Fallback`); `-intro2Autoplay` la fa andare da sola.
2. **Pagina 2 · stato del varco**: animazione «Telecamera accesa: se entri, è multa.» / «Si accende tra 15 minuti: decidi adesso.» /
   «Telecamera spenta: puoi entrare.», «Varco attivo tra 250 m», «Non sai se puoi entrare?», «Ogni orario viene dall'ordinanza del Comune.»
   - **«Attiva gli avvisi»** [`intro2.alerts`] → richieste REALI di iOS: notifiche + posizione «Sempre» (poi va avanti anche con un «no»).
   - **«Non adesso»** [`intro2.notNow`] → avanti senza richieste.
3. **Pagina 3 · «Impara con GateLR»** «Inquadra il cartello: GateLR te lo spiega.» con i cartelli: «Le auto non possono entrare»,
   «Lun–sab, dalle 7:30 alle 20», «Solo con permesso», «Area pedonale: niente auto, mai.», «Telecamera spenta: puoi entrare.»,
   «Fine della zona: sei fuori.» → **«Continua»** [`intro2.next3`]
4. **Pagina 4 · «Con cosa entri?»** «La risposta cambia col veicolo: nello stesso posto un'elettrica entra, un diesel Euro 2 no.»
   - VEICOLO: «Auto» [`intro2.type.car`] / «Moto / scooter» [`intro2.type.motorcycle`]
   - ALIMENTAZIONE: Benzina/Diesel/Ibrida/Elettrica/GPL / metano [`intro2.fuel.petrol|diesel|hybrid|electric|lpg`], «Non so» [`intro2.fuel.unknown`] (di serie: Non so)
   - CLASSE EURO (SUL LIBRETTO, RIGA V.9): 0…6 [`intro2.euro.0…6`], «Non so» [`intro2.euro.unknown`] — **nascosta se Elettrica**
   - testo: «Auto a noleggio? La classe Euro è sul libretto nel cruscotto. Con «Non so» ti diciamo «Controlla il cartello» dove contano i divieti Euro, mai «Puoi entrare».»
   - **«Fine»** [`intro2.done`] → salva il veicolo scelto (sostituisce l'auto di esempio se mai toccata) e chiude.
   - **«Più tardi»** [`intro2.later`] → se l'auto di esempio non è mai stata toccata diventa il veicolo «Non so» (Auto · alimentazione non nota).
   - Alla chiusura: `onboarded = true`, `introVersionSeen = 2`, partono gli avvisi SOLO se i permessi ci sono già.
- Veicolo di serie prima della presentazione: «Auto a noleggio» Fiat 500, benzina Euro 6, senza targa.

### 1.3 «Novità» (`WhatsNewView`) — 🚫 in 2.0.2
Compare una volta dopo un aggiornamento solo se per la versione esistono note; le note esistono solo per 1.16.0, 1.13.0, 1.12.0.
Per 2.0.2 non compare mai (nessun foglio vuoto). Pulsante «Continua», titolo «Novità di GateLR %@».

---

## 2. Struttura dell'app

- **Quattro schede** (barra di iOS, rimbalzo dell'icona e vibrazione di selezione al cambio):
  **Adesso** (cerchio pieno) · **Mappa** (icona più grande) · **Viaggio** (valigia) · **Aiuto** (punto interrogativo).
- **In alto in ogni scheda** (`TopActions`): fotocamera **«Leggi il cartello»** [`top.sign`] (apre un foglio con il lettore del cartello e
  «Chiudi» [`sign.close`]) e l'icona del veicolo **«Garage e impostazioni»** [`top.vehicle`] (valore VoiceOver: il veicolo, es. «Auto a
  noleggio · benzina Euro 6»; l'icona è auto o scooter).
- **Sopra a tutto**:
  - banner dell'avviso (guardiano/avviso con l'app aperta): colore della risposta, titolo «Non entrare · Firenze Settore A», tocco =
    «Parcheggia fuori», X «Chiudi»; sparisce dopo 10 s (non con VoiceOver); con Riduci movimento solo dissolvenza.
  - foglio «Parcheggia fuori» aperto da un avviso/notifica/`gatelr://park` (§6).
  - avviso «Serve la posizione esatta per i varchi» con «Apri Impostazioni», «Naviga comunque» (solo se il viaggio non era partito), «Annulla» (§10).
  - striscia viola «Modalità prova attiva» (solo strumenti di sviluppo, §23).
- Al ritorno in primo piano si rileggono i permessi (posizione, notifiche).
- Tinta dei pulsanti = colore del testo (chiaro di notte, scuro di giorno); il rosso solo nel logo e per «Non entrare».

---

## 3. Scheda «Adesso» (`VarcoView`)

### 3.1 Come si arriva
Scheda «Adesso» (prima scheda, si apre all'avvio). Deep link `gatelr://adesso`, `gatelr://varco`, `gatelr://now` o qualsiasi host sconosciuto.
Si ridisegna ogni minuto (`TimelineView.everyMinute`).

### 3.2 Elementi dall'alto
1. **Testata**: logo «GateLR»; menu **città** (capsula con l'edificio, VoiceOver «Città: Firenze») con le 46 città in elenco → sceglie la
   città (toglie il posto cercato; vale fino al prossimo avvio, la posizione non la cambia più); fotocamera e veicolo (§2).
2. **Striscia di mappa** [`varco.mapstrip`] (VoiceOver «Guarda la mappa», valore «Zona ZTL: Centro» / «Destinazione: …» / «La tua posizione»):
   - senza posto: la zona scelta col cartello ZTL al centro e il nome corto, altezza 168; con risposta 112 (72 in pagina compatta,
     nascosta in «tight»).
   - ogni zona con il colore della SUA risposta per il tuo veicolo; pallino blu solo col permesso, ripresa che include te se sei entro 5 km.
   - etichetta «Guarda la mappa»; tocco ovunque tranne il fondo → **scheda Mappa** sulla zona della risposta.
   - fonte non ufficiale: piccolo avviso giallo in alto.
3. **Chip del contesto** (`ContextChips`, uguali in Mappa e Viaggio):
   - **Ora** [`context.time`] (VoiceOver «Ora: Adesso»): menu «Adesso» (spunta), «Stasera 20:00» (solo se non sono ancora le 20 a
     Roma), «Domani 09:00», «Scegli giorno e ora…» → foglio «Quando?» con calendario grafico in ora di Roma («Ora italiana, come sui
     cartelli ai varchi.»), «Adesso» (azzera) e «Fine». Il chip diventa blu con l'ora scelta: «Oggi 15:00», «Stasera 21:00», «Domani 09:00»,
     «mar 27 ott, 18:30». L'ora scelta torna «Adesso» a ogni avvio o quando passa.
   - **Veicolo** [`context.vehicle`] (VoiceOver «Veicolo: …»): elenco dei veicoli (spunta su quello in uso), «Aggiungi un veicolo» →
     modulo veicolo (§12.3); se salvato diventa quello in uso. Testo corto: «Fiat 500 · E6», «Auto · ?», «… · Elettrica», «… · E?».
4. **Riquadro del guardiano** [`guardian.banner`] solo se il guardiano è acceso (§10): «Guardiano attivo · verso %@» + riga + «Ferma».
5. **Ricerca** [`varco.search`] «Hotel, indirizzo o piazza»: suggerimenti di Apple (dalla città scelta) [`varco.result.N`]; «Continua a
   scrivere…» senza risultati; senza rete «La ricerca non funziona adesso. Controlla la connessione.» + «Riprova» [`search.retry`];
   Invio sceglie il primo suggerimento (o aspetta/riprova; niente con < 2 lettere). Croce «Cancella». Con il campo vuoto, icona
   **«Usa la mia posizione»** [`varco.locate`] (freccia; barrata se la posizione è negata → apre Impostazioni di iOS):
   - senza permesso: primo tocco → richiesta iOS «Mentre usi l'app», la risposta arriva appena c'è la posizione;
   - posizione approssimativa → richiesta di precisione temporanea; se resta approssimativa: «Posizione approssimativa: cerca l'indirizzo.» [`varco.approximate`] e si apre la tastiera.
   - Pagina compatta (iPhone SE o testo grande): la ricerca è una lente nella riga del posto [`varco.searchOpen`].
6. **Senza posto e senza posizione utile → riquadro vuoto**: «POSSO ENTRARE?», «Scopri se / puoi entrare», «Cerca un hotel, un indirizzo
   o una piazza: GateLR ti dice subito se la tua auto può arrivarci.» + pastiglie: fino a 2 hotel dei viaggi salvati «Il tuo hotel · …»
   [`varco.hotel`] e posti recenti (max 4 in tutto) → un tocco dà la risposta.
7. **Scheda della risposta** [`varco.answerCard`]:
   - **Riga del posto** [`varco.place`] (intestazione): titolo = nome del posto (o «La tua posizione»), sotto «Firenze · Settore A»
     (o area pedonale, «Fuori dalla ZTL», «Non conosciamo le ZTL di questo posto»; per la zona davanti «120 m davanti a te · …»). Il ▾ apre
     menu con hotel salvati e ultimi 5 recenti. **X «Cancella»** [`varco.clear`] torna alla domanda.
   - avviso «Fonte non ufficiale» se serve.
   - **Blocco della risposta** [`varco.answer`] (forma + parola + colore, un solo elemento VoiceOver che dice anche «Per <veicolo>, adesso»).
   - **Pulsanti**:
     - risposta rossa (Non entrare / area pedonale): **«Parcheggia fuori e cammina»** grande per primo [`varco.park`], poi icona mappa
       «Guarda la mappa» [`varco.map`], **«Perché?»** [`varco.why`] e **«Dettagli del viaggio»** [`varco.details`];
     - altrimenti: **«Guarda la mappa»** grande [`varco.map`], «Perché?» e «Dettagli del viaggio»; se giallo «A una condizione» →
       anche «Parcheggia fuori e cammina» (secondario).
     - «Perché?» c'è solo se il posto è in una zona → scheda della zona (§4). «Dettagli del viaggio» → scheda Viaggio con il posto.
     - con testo grande i pulsanti secondari vanno uno sotto l'altro.
   - **Fiducia** (§5) sotto i pulsanti (in pagina compatta più in basso).
   - **Pannello del varco** (LED, [`gate.panel`]) solo dove c'è un varco vero (non fuori ZTL né fuori copertura): «ZTL ATTIVA», «ZTL NON
     ATTIVA», «AREA PEDONALE»; didascalia «Il pannello dirà ZTL ATTIVA: per te va bene.» (ammesso a ZTL attiva) / «Se il pannello dice ZTL
     ATTIVA, non entrare.» (non sicuro a ZTL attiva) / «Così lo vedrai al varco.»
   - **Ora del cambio**: «SI SPEGNE ALLE» / «SI ACCENDE ALLE» + ora grande (+ giorno se non è oggi); area pedonale «SEMPRE, A OGNI ORA».
   - «Per Domani 09:00» se è scelta un'ora.
   - **«Segnala un errore»** [`varco.report`/`zone.report`] per la zona che decide (§13).
8. **«In auto»** [`varco.incar`] (suggerimento VoiceOver «La risposta dove sei, a caratteri grandi») → §7.
9. **«Vicino a te: Settore A · 400 m · attiva adesso / non attiva adesso»** (o «ci sei dentro»), solo con posizione precisa e una zona
   entro 30 km; tocco → scheda della zona.
10. **«Il tuo prossimo viaggio»** (il viaggio salvato con arrivo futuro più vicino) → tocco: seleziona l'hotel e apre Viaggio.
11. **Banner di stato della città**: «Bozza: dalle fonti ufficiali, non ancora rivista da una persona» (tutte le città oggi), «Dati di esempio, non reali», o «Fonte non ufficiale: verifica sempre il cartello al varco» + «Dati da …».
12. In fondo: «Vale sempre la segnaletica sul posto, non l'app.»

### 3.3 Per quale posto risponde (Adesso)
1. Il posto cercato (in Adesso, Mappa o Viaggio: è uno solo per tutta l'app).
2. Senza posto: la posizione **precisa** (≤ 150 m) e **recente** (≤ 10 min):
   - dentro una zona o un'area pedonale → «La tua posizione»;
   - fuori: la zona/area pedonale più vicina **entro 300 m e davanti** (direzione di marcia se > 2 m/s e rotta precisa ≤ 45°; senza
     direzione la più vicina) → titolo = varco entro 150 m dal bordo, o nome della zona; riga «120 m davanti a te»; risposta all'ora
     d'arrivo stimata;
   - altrimenti «La tua posizione» fuori dalle zone (grigio) o fuori copertura (neutro).
3. Senza posizione utile: riquadro vuoto.
4. Alla prima posizione dopo l'avvio la pagina passa da sola alla città dove sei (se non hai scelto città/posto e non c'è la modalità prova).

### 3.4 I sette stati della risposta (uguali in Adesso, Mappa, Viaggio, In auto, widget, Live Activity, avvisi, Siri, CarPlay)
| Stato | Parola | Forma | Colore | Quando |
|---|---|---|---|---|
| nonEntrare | **Non entrare** | ✕ | rosso | «no» del motore; area pedonale sempre; hotel senza conferma («Chiedi all'hotel di registrare la targa»); «no» anche da fonte non ufficiale («Probabilmente no · fonte non ufficiale») |
| condizione | **A una condizione** | ! | giallo | ticket giornaliero; zona verde (Area B) senza divieti noti; moto dove ci sono divieti Euro senza `motoBans` («Qui le moto hanno limiti Euro loro…»); permesso non-hotel «In attesa» |
| controllaCartello | **Controlla il cartello** | ? | giallo | «non sicuro»: motivo nella riga sotto: «Non sicuro», «Dati scaduti» (>120 giorni o pagina cambiata), «Fonte non ufficiale» («Probabilmente sì · fonte non ufficiale»), «Festivo da confermare», «Classe Euro da sapere» (veicolo «Non so»); anche il «sì» di una città di esempio |
| entraPure | **Puoi entrare** | ✓ | verde | ZTL attiva ma sei esente (permesso confermato, hotel con targa registrata «L'hotel ha registrato la targa · dal … al …», moto esenti, elettrica esente, auto ammessa nella zona verde); pannello «ZTL ATTIVA» con «per te va bene» |
| ztlNonAttiva | **ZTL non attiva** | – | verde (token «spento») | varchi spenti a quell'ora |
| fuoriZTL | **Fuori dalla ZTL** | spillo | grigio | fuori dalle zone di una città coperta (entro 2 km dal rettangolo delle sue zone); niente pannello; in Viaggio «La zona più vicina, X, è a N m.» e sotto 150 m «Molto vicino al confine…»; se la città è tutta da fonti non ufficiali → giallo «Controlla il cartello» |
| nonCoperto | **Non conosciamo questo posto** | ? tratteggiato | neutro | fuori da tutte le città (es. Pistoia); niente pannello, riga «Non conosciamo le ZTL di questo posto» |
Regole importanti:
- **L'area pedonale vince** su tutto (anche a ZTL spenta) e l'ora del cambio dice «Sempre, a ogni ora».
- **La zona peggiore decide** quando il posto è in più zone (no > condizione > non sicuro > sì; a parità quella con i varchi accesi, poi la più piccola): Palazzo Vecchio di notte con diesel Euro 1 → «Non entrare» per lo Scudo Verde anche se il Settore A è spento.
- Tutte le risposte sono in **ora italiana** (Europe/Rome), anche con il telefono in un altro fuso.
- **Mai verde** per dati non verificati/vecchi (>120 giorni dall'ultima lettura o verifica), pagina del Comune cambiata (`pageChanged`), fonte non ufficiale, città di esempio. Oggi i dati sono freschi: per vedere «Dati scaduti» servono le città con `pageChanged` (§26: Arezzo, Ferrara, Genova, Matera, Montepulciano, Palermo, Perugia, San Gimignano, Verona) → ogni risposta in quelle zone diventa «Controlla il cartello · Dati scaduti», anche il «no».
- «Non ancora verificata a mano» NON cambia il colore (solo l'etichetta gialla della fiducia).

---

## 4. Scheda della zona (`ZoneDetailView`)
**Come si arriva**: Adesso → «Perché?»; Adesso → riga «Vicino a te»; Mappa → «Dettagli zona»; Viaggio → «Perché?» nel riquadro grande o una riga di «Anche dentro». Foglio con «Fine» in alto a destra.
- Titolo (nome della zona), pillola del tipo («ZTL», «ZTL con pass», «Zona verde»), pillola dello stato dei varchi [`zone.state`] «ZTL attiva»/«ZTL non attiva» (+ «· gio 22:00» con un'ora scelta), nome della città, banner «Bozza…».
- Zona da fonte non ufficiale: riquadro in cima «Queste regole vengono da un sito non ufficiale, non dal Comune: possono essere sbagliate o non aggiornate.» + link al sito [`zone.unofficialSource`] «Dati da …».
- **Fiducia** (§5) con condivisione della pagina della città.
- «IN BREVE» (riassunto nella lingua; in fr/es/nl/pl/zh l'italiano con l'inglese sotto).
- «QUANDO È ATTIVA»: righe giorni/orari, «tutto il giorno», «Festivi: libero/da confermare/come la domenica», stagioni (es. Firenze Settore F «gio – sab (1 apr – 3 ott)»).
- «Segnala un errore» (§13).
- «LE PAROLE DEL COMUNE» / «COSA DICE LA FONTE»: citazione italiana + traduzione, «Leggilo sulla pagina del Comune» (link).
- «BIGLIETTO GIORNALIERO» con «Come pagare» (link) per le zone con ticket.
- «SE ENTRI PER SBAGLIO»: «83–332 €» (da `Rules/fine.json`) «al giorno», note, «Importi ancora da verificare sul testo ufficiale.»
- «ANCORA DA VERIFICARE» (giallo) con i punti in sospeso della fonte.
- «FONTI» (link).
- «Letto dalle fonti ufficiali il 23 ottobre 2026.» / «Letto da una fonte non ufficiale il …»; frase di verifica [`zone.verified`]: «Non ancora verificato da una persona.» / «Non ancora verificato: controlla il cartello.» / «La pagina del Comune è cambiata da quando l'abbiamo letta o verificata: controlla il cartello.» / «Verificato da una persona il …»; licenza dei dati.

---

## 5. Riga «Fiducia» (2.0.2, `FiduciaFooter`) e le due pagine
**Dove**: sotto ogni risposta di Adesso (per la zona che decide) e nella scheda della zona.
- Chip [`fiducia.checked`] «✓ Controllata oggi» / «Controllata ieri» / «Controllata il 23/10» (anno se diverso: «23/10/2025»); la spunta solo con dati freschi (verificati o letti ≤ 120 giorni e pagina non cambiata), altrimenti orologio grigio. Data = la più recente tra lettura e verifica, in giorni di Roma.
- Chip giallo [`fiducia.byHand`] **«Non ancora verificata a mano»** quando `reviewedByHuman` è falso (oggi: tutte le zone). Il colore della risposta non cambia.
- Link [`fiducia.source`] «Fonte: Comune di Firenze ›» (o il sito non ufficiale).
- **«Mandalo al tuo hotel / noleggio»** [`fiducia.share`] «Si apre nel browser, senza installare nulla» → foglio di condivisione di iOS con:
  `Arrivo in auto: <posto>. Qui GateLR mostra se un'auto può entrare nella ZTL. Si apre nel browser, senza installare nulla:` + a capo + link.
  - **Formato del link**: `https://lr-apps609.github.io/GateLR/` + `it/` (lingua it) o `de/` (de), nessun prefisso per le altre lingue;
    con un posto cercato `#p=<lat 5 decimali>,<lon 5 decimali>&n=<nome codificato form-urlencoded, spazi = +, max 120 car.>&v=<veicolo>`;
    `v` solo se il sito conosce il veicolo (petrol-6, petrol-3, petrol-4, petrol-5, diesel-4, diesel-5, diesel-6, hybrid-6, electric-6,
    moto-5) e mai per un veicolo «Non so». Con «La tua posizione» (o nessun posto, o scheda della zona): la pagina della città `…/it/firenze/` e nel testo il nome della città. **Mai la targa.**
  - Esempio: Palazzo Vecchio con l'auto di serie in italiano → `https://lr-apps609.github.io/GateLR/it/#p=43.76930,11.25630&n=Palazzo+Vecchio&v=petrol-6`.
- Link [`fiducia.checks`] **«Come controlliamo i dati ›»** e [`fiducia.fine`] **«Cosa fare se ricevi una multa ›»** (affiancati; con testo grande uno sotto l'altro) → foglio con «Fine».
  - «Come controlliamo i dati»: «Da dove vengono i dati», «Controllo automatico ogni mattina», «Data e fonte su ogni risposta», «Verifica a mano: ancora in corso», «Quando non siamo sicuri: giallo».
  - «Cosa fare se ricevi una multa»: avvertenza «GateLR non può rimborsare le multe…», «Controlla il verbale», «Confronta con la pagina del Comune», «Auto a noleggio o hotel?», «I ricorsi in Italia», «FONTI UFFICIALI» (3 link: Normattiva art. 203, art. 204-bis, Prefettura di Torino), link a «Ho preso una multa?», «Per un consiglio sul tuo caso, chiedi a un avvocato o a un'associazione dei consumatori.»
- Le stesse due pagine: Aiuto → «Sulle risposte» e Garage e impostazioni → Informazioni.

---

## 6. «Parcheggia fuori e cammina» (`ParkOutsideCard`)
**Come si arriva**: Adesso → «Parcheggia fuori e cammina» (foglio a metà/intero); Mappa → scheda del posto → «Parcheggia fuori e cammina» [`map.park`] (foglio; mette anche le «P» con l'omino sulla mappa); Viaggio (riquadro dentro la pagina, prima del percorso se «no», dopo se giallo, sempre per l'area pedonale); In auto → «Parcheggia fuori»; tocco su un avviso/notifica; `gatelr://park?zone=…&lat=…&lon=…&name=…`.
- Titolo «Parcheggia fuori e cammina», «Parcheggi fuori da ogni ZTL attiva al tuo arrivo.»
- Stati: «Cerco…» [`park.searching`] con tre righe grigie ferme; «Nessun parcheggio trovato appena fuori dalla zona.» [`park.empty`]; «Non riesco a cercare i parcheggi adesso. Controlla la connessione.» [`park.failed`] + «Riprova» [`park.retry`]; risultati [`park.option.0…2`] (max 3): nome, tipo (Multipiano/Sotterraneo/All'aperto), «N min a piedi»/«circa N min a piedi», prezzo («Gratis», «Prezzo: …», «A pagamento», «Prezzo non indicato»), «Aperto adesso»/«Aperto al tuo arrivo»/«Chiuso»/«Orari non indicati», «N posti», «Strada fin lì senza ZTL attive» o «Strada non controllata: consenti l'accesso alla posizione».
- Un tocco su una riga la sceglie; sotto **«Avvia»** [`park.start`] (§9.6) e «Poi N min a piedi fino a <posto>».
- Fonte: dati OpenStreetMap dentro l'app per 20 città (`Resources/Parking`: Arezzo, Bari, Bergamo, Bologna, Firenze, Genova, Lucca, Milano, Napoli, Padova, Palermo, Parma, Perugia, Pisa, Roma, San Gimignano, San Giovanni Valdarno, Siena, Torino, Verona) → funziona offline; per le altre città Overpass (rete, copia 30 giorni) o la ricerca di Apple («Prezzi e orari: controlla il parcheggio prima di andare.»). Nota: «Parcheggi, prezzi e orari: © contributori di OpenStreetMap. Controlla i cartelli sul posto.»
- Solo parcheggi fuori da ogni ZTL attiva all'ora d'arrivo per quel veicolo (e da ogni area pedonale); i chiusi all'arrivo esclusi.

---

## 7. Modalità «In auto» (`InCarView`)
**Come si arriva**: Adesso → **«In auto»** [`varco.incar`]. A tutto schermo; lo schermo resta acceso finché è aperta.
- Testata «IN AUTO» (o «IN AUTO · GUARDIANO» col guardiano acceso) e **X «Chiudi»** [`incar.close`].
- Risponde SOLO per dove sei (mai il posto cercato), con le regole di §3.3: blocco grande [`incar.answer`] (riga «Firenze · Settore B · Attiva fino alle 20:00»), «120 m davanti a te» grande, nome del posto.
- Senza posizione: «Aspetto la tua posizione…» + «Usa la mia posizione» (chiede il permesso) / «Apri Impostazioni» (negata) / «Posizione approssimativa: cerca l'indirizzo.».
- Risposta rossa → grande **«Parcheggia fuori»** [`incar.park`] → foglio parcheggi (lì «Avvia» con un navigatore avvia il guardiano).

---

## 8. Scheda «Mappa» (`MapScreen`)
**Come si arriva**: scheda «Mappa»; striscia o «Guarda la mappa» in Adesso; icona mappa in Viaggio; `gatelr://map` / `gatelr://mappa`.
- **Barra in alto**: ricerca [`map.search`] «Indirizzo o hotel a <città>» (suggerimenti [`map.result.N`], «Continua a scrivere…», errore + «Riprova»), X «Cancella» (toglie anche il posto); **«i» Legenda** [`map.legend.info`, o `map.legend` con un posto]; menu **«Stile della mappa»**: Mappa / Ibrida / Satellite, interruttore «Edifici in 3D», **«Vista strada»** (Look Around di Apple; se non c'è: «Qui non c'è la vista strada. Prova un altro punto.»); fotocamera e veicolo.
- Chip ora/veicolo (spariscono mentre scrivi).
- **Legenda corta** [`map.legend`] (solo senza posto): quattro campioni «Non entrare», «A una condizione», «Puoi entrare», «ZTL non attiva»; un tocco apre la **legenda intera** [`map.legend.full`]: «Colori per <ora> · <veicolo>», le quattro voci con spiegazione, «Righe oblique: la ZTL è attiva a quell'ora. Bordo tratteggiato: una ZTL.», «PEDONALE · Area pedonale», «ZTL · Zona piccola: solo il segno», «Varco con telecamera», «Telecamera corsia bus», «Telecamera dell'area pedonale». Si chiude con un tocco (anche fuori) o con l'azione VoiceOver «Chiudi».
- **Consiglio** (TipKit) «Il tuo hotel è dentro? · Cerca il tuo hotel per vedere se è dentro» sotto la barra; sparisce dopo la prima ricerca.
- **Disegno delle zone**: colore = risposta per ora+veicolo (rosso/giallo/verde/verde chiaro «spento»; giallo «?» per dati incerti); bordo tratteggiato (più rado a ZTL spenta); righe a 45° se attiva (da zoom ~15); segno «ZTL» con nome da vicino; scritte lungo le vie da z17; varchi da z16; aree pedonali rosse con «PEDONALE» da z13; telecamere bus (blu) e pedonali (Firenze); zona di prova con «ZONA DI PROVA · attiva/spenta». Si aggiorna ogni minuto se una risposta cambia (es. Firenze 7:29 → 7:30 diventa rosso).
- Controlli di MapKit: posizione, bussola, inclinazione, scala.
- **Tocco sulla mappa**: su un'area pedonale → posto «Non entrare»; su una zona → la sceglie (scheda zona).
- **Scheda in basso senza posto** (zona scelta): menu col nome della zona (tutte le zone della città), «ZTL · N varchi · accesi ora / spenti ora» (o «accesi · Domani 09:00»), pillola della risposta; **«Dettagli zona»** → §4; **«Parcheggia fuori»** (ricerca parcheggi di Apple intorno alla zona: «Cerco…», «N parcheggi fuori dalla ZTL. Tocca una P per le indicazioni.», «Nessun parcheggio trovato…», errore + «Riprova» [`map.parkRetry`]) → «P» blu sulla mappa → tocco → foglio «Parcheggio» / «Fuori dalla ZTL» / **«Indicazioni in Mappe»**.
- **Scheda del posto** (con un posto cercato; la mappa diventa scura e smorzata, la zona del posto accesa, riquadro sul posto con la parola della risposta e «Attiva fino alle …»): nome, riga zona, chip della risposta, avviso non ufficiale, riquadri «ORARI ZTL» («Attiva fino alle 20:00», «Spenta fino alle …», «Sempre») e «DA TE» (distanza, solo con posizione e < 200 km), frase del motore, **«Naviga»** [`map.start`] (§9.6), **«Dettagli zona»**, **«Dettagli del viaggio»** (→ Viaggio), «Parcheggia fuori e cammina» [`map.park`] se rosso/giallo. Con testo grande la scheda scorre.
- iPad: mappa a tutto schermo, barra e scheda larghe al massimo 700 pt.

---

## 9. Scheda «Viaggio» (`TripView`)
**Come si arriva**: scheda «Viaggio»; Adesso → «Dettagli del viaggio» o «Il tuo prossimo viaggio»; Mappa → «Dettagli del viaggio»; `gatelr://trip`, `viaggio`, `guardian`, `guardiano`; widget «Guardiano».

### 9.1 Testata e ricerca
«Il tuo viaggio», menu città (spillo), fotocamera, veicolo. Ricerca [`trip.search`] «Destinazione o hotel a <città>» (risultati [`trip.result.N`]); X; icona «Usa la mia posizione» solo con posizione precisa. Chip ora/veicolo.

### 9.2 Senza destinazione
«Dove vai?» + spiegazione; «Cerca la tua destinazione per una risposta precisa.» (apre la tastiera); «RECENTI» (ultimi 6 posti); se nessun viaggio: «Nessun viaggio salvato» «Cerca il tuo hotel e tocca «Salva questo viaggio»: resta qui e sulla prima pagina.» + «Cerca il tuo hotel»; altrimenti **«VIAGGI SALVATI»**: nome, «12 nov, 15:00 · Settore A», pillola «In corso» / «Passato»; tocco → posto + ora d'arrivo (se futura) + veicolo del viaggio; **tieni premuto → «Elimina»** → «Eliminare questo viaggio?» «Non si può annullare.» «Elimina»/«Annulla». «Tieni premuto un viaggio per eliminarlo.»

### 9.3 Con una destinazione (all'ora dei chip, per il veicolo dei chip)
- Riga del posto (icona della zona/pedone/trattino/?, nome, riga zona, pulsante mappa «Mostra sulla mappa»).
- Area pedonale: riquadro rosso [`trip.pedestrian`] «Area pedonale · …» «Qui le auto non possono entrare mai, salvo i veicoli autorizzati. Parcheggia fuori e prosegui a piedi.»
- In zona: **riquadro grande della risposta** (`VerdictCard`) con titolo «Settore A · adesso 15:00» (o «Settore A · gio 22:00» con l'ora scelta), «Attiva dalle / Non attiva dalle», «Finisce tra / Inizia tra», «Letto il …», «Perché?» → scheda zona.
- «no»: subito «Parcheggia fuori e cammina».
- «ANCHE DENTRO»: le altre zone che contengono il posto con la loro pillola (tocco → scheda zona).
- **Percorso**: «Controlla il percorso» [`trip.route`] («Calcolo…»; «GateLR controlla ogni ZTL lungo la strada, all'ora in cui ci passi.»; errori: «Nessun percorso trovato.», «Non trovo la tua posizione. Consenti l'accesso alla posizione per calcolare il percorso.», «Non riesco a calcolare il percorso adesso. Controlla la connessione.») → riepilogo: tempo, km, «Arrivo …», zone attraversate «Destinazione · alle …» / «Lungo la strada · alle …» con la risposta all'ora di passaggio, «Nessuna ZTL lungo la strada.» / «Nessuna ZTL conosciuta sul percorso: fuori dalle città coperte controlla i cartelli.», avviso giallo «Una zona lungo la strada è attiva…», destinazione vietata: «Parcheggia a <P>» «Fuori dalla ZTL · circa N min a piedi…» (pulsante «Vai al parcheggio») o «A quell'ora non puoi entrare nella zona della destinazione…»; **Avvia** (§9.6) + mappa; nota «Parti con il tuo navigatore: GateLR resta in sottofondo…». Il percorso si azzera cambiando posto, ora o veicolo. Partenza: la tua posizione (o `-uiOrigin`).
- Giallo: «Parcheggia fuori e cammina» dopo il percorso.
- **Ticket** (`TicketCard`, se la zona più piccola ha un ticket ed è attiva a quell'ora; Milano Area C, Bologna ZTL, Ferrara, Palermo, Parma, Ravenna, Rimini): «Biglietto giornaliero», prezzo, «Attivalo entro <giorno ora>.» (Area C: mezzanotte del giorno dopo) o «Compralo e attivalo prima di entrare.», **«Paga il ticket»** (link al Comune), **«Ricordamelo»** → chiede le notifiche → «Promemoria impostato»; notifica «Area C: ticket» alle 20:00 del giorno d'ingresso (Area C) o un'ora prima (Bologna e «beforeEntry»), o dopo 5 s se l'ora è già passata. Notifiche negate: «Le notifiche sono spente: attivale nelle Impostazioni» (tocco → Impostazioni).
- **Registrazione della targa** (`HotelStayCard`, se una zona del posto ha `hotelCanRegister`): «Arrivo» e «Partenza» (DatePicker), giorni in fila, «N giorni da registrare, compreso quello di partenza.», **Stato** (segmentato) «Da chiedere / Chiesta / Confermato», pulsante «L'hotel ha registrato la targa» (se non confermato), consigli: «Prima aggiungi la targa nel Garage.», «Auto a noleggio: la targa la sai solo al ritiro…», «Un permesso di parcheggio sul cruscotto non è una registrazione ZTL.», «Chiedi una conferma scritta con la tua targa e tutte le date.», «Di solito vale un ingresso e un'uscita…», «Auto a noleggio? Usa la targa dell'auto che ti consegnano davvero.»
  - «Chiesta» → dialogo «Salvare questo permesso?» «Finché l'hotel non conferma per iscritto, GateLR in <zona> continua a rispondere «Non entrare».» → «Salva il permesso» / «Annulla».
  - «Confermato» → dialogo «Hai la conferma scritta?» «Conferma solo se l'hotel ti ha confermato per iscritto…» → «Sì, ce l'ho per iscritto» → permesso confermato nel Garage, «Salvato come permesso nel Garage: per questi giorni GateLR risponde «sì».» e la risposta diventa «Puoi entrare» con «L'hotel ha registrato la targa · dal … al …» (solo per quel veicolo, quella zona, quei giorni).
  - Con la registrazione fatta per un altro veicolo: «L'hotel registra la targa di <veicolo>. Per questo veicolo chiedilo di nuovo all'hotel.»
  - Promemoria automatico: il giorno prima dell'arrivo alle 18:00 (Roma) «Domani: <hotel>» «L'hotel ti ha confermato per iscritto che la targa è registrata per tutti i giorni? Senza, i varchi ti multano.» (se non confermato). Notifiche spente → nota.
  - Il posto conta come «il tuo hotel» solo se lo stato non è «Da chiedere» (o è un viaggio salvato come hotel) e solo da un giorno prima dell'arrivo a un giorno dopo la partenza → risposta «Non entrare» + «Chiedi all'hotel di registrare la targa».
- **Messaggio per l'hotel**: segmentato **IT / EN / DE** («Lingua del messaggio», di serie la lingua dell'app, altrimenti EN), testo con arrivo (giorno e ora del chip) e partenza, targa o segnaposto «[TARGA]/[PLATE]/[KENNZEICHEN]»; «Aggiungi la targa nel Garage per completarlo.» oppure «Questo messaggio contiene la tua targa: all'hotel serve per registrarti al Comune.»; **«Invia all'hotel»** (condivisione) e **«Copia»** → «Copiato» (appunti solo locali, scadono dopo 10 minuti). Il testo non è selezionabile.
- Fuori dalle zone: riquadro grigio [`trip.outside`] «Fuori / dalla ZTL», «Questo indirizzo non è dentro nessuna ZTL che conosciamo. Puoi arrivarci in auto.», «La zona più vicina, X, è a N m.» (< 3 km), «Molto vicino al confine: segui i cartelli e non passare un varco.» (< 150 m). Città da fonte non ufficiale: [`trip.unofficialOutside`] giallo. Fuori copertura: [`trip.uncovered`] «Non conosciamo questo posto.».
- **«Salva questo viaggio»** → «Viaggio salvato» (vibrazione); un viaggio per posto e arrivo (niente doppioni); poi, 2 s dopo, la **richiesta di recensione** di iOS se: mai chiesta, oppure versione diversa E almeno 120 giorni dall'ultima; mai durante guida/guardiano né con `-uitest`.
- In fondo banner di stato e «Vale sempre la segnaletica sul posto, non l'app.»

### 9.4 Consiglio
Nessun TipKit visibile in Viaggio nel codice attuale (solo `MapSearchTip` in Mappa e `BetterVoiceTip` nella sezione dev).

### 9.5 Ora / veicolo
Stessi chip di §3.2.3; un viaggio salvato toccato imposta ora e veicolo per tutta l'app.

### 9.6 «Avvia» / «Naviga» (`StartControls`) — comune a Mappa, Viaggio, parcheggi
- Senza navigatore preferito: il pulsante apre il menu **«Il tuo navigatore + avvisi GateLR»**: Apple Maps / Google Maps / Waze. Scelto uno la prima volta → dialogo **«Usare sempre <nav>?»** «Puoi cambiarlo in Impostazioni → Navigatore preferito.» → «Sempre <nav>» / «Solo questa volta» → avvia il **guardiano** (§10) e apre il navigatore (Apple Maps app; Google/Waze via link https).
- Con navigatore preferito: «Avvia · Google Maps» parte subito + pulsante «…» «Altri navigatori».
- 🚫 «Navigatore di GateLR» nel menu solo con strumenti di sviluppo + flag «devInternalNavigator» (§23).

---

## 10. Guardiano (`Guardian`)
**Come si parte**: ogni «Avvia»/«Naviga» con un navigatore esterno (Mappa, Viaggio, percorso, parcheggi, foglio da avviso, In auto→parcheggi). Nessun interruttore a sé.
- Prima: se la posizione è **negata** → avviso «Serve la posizione esatta per i varchi» + testo «La posizione è spenta per GateLR: il guardiano non può avvisarti prima di un varco. Attivala in Impostazioni → GateLR → Posizione.» con «Apri Impostazioni», «Naviga comunque», «Annulla». **Approssimativa** → richiesta di precisione temporanea; se resta approssimativa → stesso avviso con «Con la posizione approssimativa il guardiano non sa quale varco hai davanti…». Se diventa negata/approssimativa durante il viaggio si ferma e lo dice.
- Avvio: chiede posizione «Sempre» e notifiche; aggiornamenti in sottofondo con l'indicatore blu; Live Activity (§16); apre il navigatore. Ferma la guida interna se accesa (un solo viaggio).
- In Adesso: riquadro [`guardian.banner`] «Guardiano attivo · verso <meta>» con: «In attesa del GPS…» (neutro) / «Settore A · 250 m · Non entrare» (rosso, scudo !) / giallo per condizione o «?» / grigio «Nessuna ZTL attiva davanti» / neutro «Non conosciamo le ZTL di questo posto»; **«Ferma»**.
- **Avvisi**: per la zona/area pedonale davanti (cono 70°, entro 3 km di lookahead), quando è a meno di **300 m** (sopra 50 km/h **600 m**) e la risposta all'ora d'arrivo NON è verde: notifica (app chiusa) o banner (app aperta) «Non entrare · Firenze Settore A» + «Tra 300 m. … Tocca per i parcheggi fuori.» + voce «Attenzione: tra 300 m entri in …». Una volta per avvicinamento. Entrando in una zona «no»: voce «Sei dentro <zona>. Esci dal punto più vicino e non girare dentro: ogni varco può voler dire un'altra multa.» e riga nel Diario.
- **Si ferma da solo**: a meno di 120 m dalla meta (notifica «Sei arrivato» «GateLR ha smesso di controllare i varchi.»), fermo da 15 minuti o acceso da più di 4 ore (notifica «Guardiano fermato.»). «Ferma» in Adesso, Siri «Ferma il guardiano», o chiusura.
- CarPlay e Siri «ZTL vicine» usano la sua posizione mentre è acceso.

## 10b. Avvisi ad app chiusa (`GateMonitor`, interruttore «Avvisi ai varchi»)
- Attivi se: «Avvisi ai varchi» acceso (di serie), notifiche permesse e posizione **«Sempre»**. Cerchi da 300 m attorno ai 20 varchi (e telecamere di aree pedonali) più vicini, rinnovati ogni 1,5 km. Quando entri in un cerchio, se il varco è davanti, sei fuori dalla zona e la risposta non è verde → notifica come sopra + riga «Vicino a un varco attivo» nel Diario. Non avvisano mentre il guardiano (o la guida interna non ancora arrivata) è acceso. iOS rilancia l'app in sottofondo per l'evento.
- Tocco sulla notifica → foglio «Parcheggia fuori» per quella zona (`userInfo.url = gatelr://park?...`).

---

## 11. Scheda «Aiuto» (`HelpView`)
**Come si arriva**: scheda «Aiuto»; `gatelr://help`/`aiuto`. Titolo «Aiuto», in alto fotocamera e veicolo.
1. **«Leggi il cartello»** [`learn.sign`] «Inquadra il cartello: giorni e ore» → §11.1. Se la posizione è negata: riga gialla **«Posizione negata: gli avvisi in auto sono spenti.»** [`help.locationDenied`] → Impostazioni di iOS.
2. **MULTE**: **«Ho preso una multa?»** [`help.fine`] «Cosa fare, in 4 passi» (la pagina ne ha 7) → §11.2; **«Fotografa il verbale»** [`fines.scan`] «Controlliamo data, ora e varco» → §11.3; **«Diario dei passaggi»** [`fines.log`] con il numero delle righe → §11.4.
3. **SULLE RISPOSTE**: **«Come controlliamo i dati»** [`help.checks`] «Fonti, controllo quotidiano, cosa non sappiamo ancora»; **«Cosa fare se ricevi una multa»** [`help.fineHelp`] «Controlla il verbale, i ricorsi, a chi chiedere» (§5).
4. **IMPARA E SEGNALA**: **«Cosa sono le ZTL»** [`help.learn`] «I cartelli e la dicitura «ZTL attiva»» → §11.5; **«Rivedi la presentazione»** [`learn.intro`] → §1.2 (a tutto schermo; alla fine torna dove eri); **«Segnala un errore»** [`help.report`] «Orari, varchi o zone sbagliati» → §11.6. Piè: «Vale sempre la segnaletica sul posto, non l'app.»

### 11.1 «Leggi il cartello» (`SignReaderView`)
Anche dalla fotocamera in alto (foglio con «Chiudi») e da `gatelr://cartello` / `sign` (pagina dentro Aiuto).
- Pannello disegnato «7.30 – 20.00 FERIALI»; «Inquadra il pannello bianco sotto il cartello ZTL, oppure scegli una sua foto.»
- **«Usa la fotocamera»** (solo se c'è una fotocamera: testo dal vivo `DataScanner` con «Usa questo testo», o fotocamera classica). Permesso: richiesta iOS; negato → riquadro «Consenti la fotocamera» + «Apri Impostazioni» [`sign.openSettings`] (tornando col permesso la fotocamera si apre da sola); fotocamera non disponibile → «La fotocamera ora non è disponibile. Scegli invece una foto del pannello.»
- **«Scegli una foto»** (selettore Foto di iOS, nessun permesso Foto richiesto) → riconoscimento del testo sul telefono («Leggo…»).
- **«TESTO DEL CARTELLO»** campo [`sign.text`] «es. 7.30-20.00 feriali» (si può scrivere a mano).
- Esito (mai verde): rosso **«Attiva adesso, secondo il cartello: non entrare»** [`sign.verdict.active`]; giallo **«Secondo il cartello la ZTL sembra spenta adesso: controlla che non ci siano altri divieti»** [`sign.verdict.seemsOff`]; giallo **«Non riesco a leggerlo»** [`sign.verdict.unreadable`]. «COSA VUOL DIRE»: righe giorni/orari («Tutti i giorni», «tutto il giorno»), «Festivi: non attiva.», «Anche nei festivi.», «Controlla che giorni e orari qui sopra siano quelli del pannello…». Piè: «GateLR legge il pannello per te, ma può sbagliare una foto: nel dubbio vale il cartello.» Usa l'ora vera (non il chip).

### 11.2 «Ho preso una multa?» (`FineGuideView`, anche `gatelr://multe`/`fines`)
In cima riquadro **«Fotografa il verbale»** [`fine.scan`] → §11.3; poi 7 passi numerati: «Quando arriva», «La commissione del noleggio», «Quanto» («Da 83 a 332 € per ingresso…»), «Come pagare», «Non sei d'accordo? Ricorso», «Cosa conservare», «Non ignorarla»; piè «Informazioni generali, non consulenza legale…».

### 11.3 «Fotografa il verbale» (`FineScanView`)
- «Fotografa la prima pagina del verbale…»; «Usa la fotocamera» [`document.camera`] (se c'è) / «Scegli una foto» [`document.photo`]; permesso negato → «Apri Impostazioni» [`document.openSettings`]; «Nessun testo in questa foto…».
- **«TESTO DEL VERBALE»** [`fine.text`] «Oppure scrivi le righe principali del verbale» + **«Leggi questo testo»** [`fine.read`] → si prova SENZA foto.
- «COSA ABBIAMO LETTO»: «Violazione» data/ora (ora italiana; «Ora non trovata: impostala come scritta sul verbale.» / «Aggiungi data e ora della violazione»), «Varco o via» («es. Via Cavour»), «Città», «Zona» (proposte e modificabili), «Importo», «Entro 5 giorni», «Articolo», «Numero del verbale», «Targa». Testo illeggibile: «In questo testo non trovo i dati di una multa ZTL…».
- **«Il varco era attivo?»** [`fine.verdict`]: rosso «Secondo le regole che conosciamo, il varco era attivo» / verde «…non era attivo» (o giallo «Secondo i dati disponibili il varco non risulterebbe attivo. I dati non sono ancora stati controllati da una persona…») / giallo «I nostri dati per questa zona sono vecchi o non ufficiali…» / giallo festivo «Non possiamo dirlo: era festivo…»; nota «Controllato al giorno e all'ora del verbale, con gli orari letti il …», «Fonte ufficiale: …»; mancano città/zona o data → istruzioni.
- **«SCADENZE»**: «Notificato il» (DatePicker; «Data di notifica non trovata…»), «Paga con lo sconto del 30%» (5 gg), «Ricorso al Giudice di Pace» (30), «Paga senza sconto» e «Ricorso al Prefetto» (60); date passate barrate; nota art. 201 (90/360 giorni).
- **«RICORSO»**: «Una bozza in italiano…», **«Copia un testo per il ricorso»** [`fine.copyAppeal`] → «Copiato» (appunti locali 10 min; inizia con «BOZZA», targa del verbale mostrata come «•••»… vedi Privacy), «Mostra la bozza».
- «RIFERIMENTI UFFICIALI» (link Normattiva). Piè: «Informazioni generali, non consulenza legale: non siamo avvocati…».
- Testo d'esempio da incollare: `Comune di Firenze … il giorno 12/03/2026 alle ore 10:32 … varco … Via Cavour … Notificato il 02/04/2026`.

### 11.4 «Diario dei passaggi» (`DriveLogView`, anche `gatelr://diario`/`log`)
- «GateLR scrive qui quando passi vicino a un varco attivo o entri in una zona dove non potevi. Solo su questo iPhone.»
- Vuoto: «Ancora nessun varco sul tuo percorso» «Quando il guardiano o un avviso vede un varco attivo, qui compaiono l'ora e il posto.» + **«Prova un avviso»** (manda l'avviso di prova, §12.4).
- Righe: zona, «gio 12 nov, 15:00 (ora italiana) · varco · targa», «Entrato nella zona · Non entrare» / «Vicino a un varco attivo · …»; scorri → elimina con conferma «Eliminare questa riga del diario?».
- «Una riga qui non vuol dire che arriverà una multa…»; **«Condividi il diario»** [`log.share`]; **«Cancella il diario»** → «Cancellare tutto il diario?»; anteprima «Cosa viene condiviso» [`log.sharePreview`] «Il testo condiviso non contiene mai la tua targa.»
- Per riempirlo nel simulatore senza guidare: `-uitest -uiPlate GX482KM` crea due righe finte.

### 11.5 «Cos'è una ZTL?» (`LearnZTLView`, anche `gatelr://impara`/`learn`)
Lezioni con disegni: «Cos'è una ZTL?», «Come riconoscere il varco», ««ZTL attiva» o «non attiva»» (pannello disegnato; VoiceOver «ZTL attiva/non attiva»), «Leggi gli orari sotto il cartello», «Aree pedonali», «Corsie bus», «Zone a basse emissioni», «Entrato per sbaglio?», «Quanto costa la multa?».

### 11.6 «Segnala un errore» da Aiuto / Garage = modulo «Segnala un bug» (`BugReportView`)
Foglio «Segnala un bug»: «DESCRIVI IL PROBLEMA» (editor «Cosa è successo? Cosa ti aspettavi?»), **«Dove»** (Varco, Mappa, Viaggio, Garage, Account, Widget, Avvisi ai varchi, Altro — nota: etichette vecchie), interruttore **«Aggiungi info tecniche»** (acceso: versione, iOS, modello, lingua, città/zona, data; «Niente posizione, niente targa.»), **«Invia per email»** (mailto support@example.com), **«Invia»** (condivisione), **«Copia»** → «Copiato». Pulsanti disattivati finché il testo è vuoto. «Annulla».

---

## 12. Foglio «Garage e impostazioni» (`AccountView`)
**Come si arriva**: icona del veicolo in alto [`top.vehicle`] in ogni scheda; `gatelr://account` (`you`, `tu`); pagine dirette `gatelr://garage`, `gatelr://impostazioni`/`settings`, `gatelr://privacy`. Titolo «Garage e impostazioni», **«Fine»** [`account.done`].
- **«LE RISPOSTE SONO PER»**: elenco dei veicoli, tocco = veicolo in uso (spunta).
- **«Garage»** [`account.garage`] «Le tue auto e i permessi» → §12.1
- **«Impostazioni»** [`account.settings`] «Avvisi, navigatore, lingua e dati delle città» → §12.4
- **«Privacy»** [`account.privacy`] «Cosa resta su questo iPhone e cosa esce» → §12.5
- **«Informazioni»** [`account.about`] «Fonti, licenze e avvertenze» → §12.6
- **«Segnala un errore»** [`account.report`] «Orari, varchi o zone sbagliati» → modulo «Segnala un bug» (§11.6)
- piè: «Nessun account necessario: auto, permessi e viaggi restano su questo iPhone.»
- 🚫 «Lascia una recensione» [`account.review`] solo con `APP_STORE_ID`.

### 12.1 Garage (`GarageView`)
- «VEICOLI»: vuoto → «Ancora nessuna auto» «Aggiungi la tua auto o quella a noleggio…» + «Aggiungi un veicolo»; righe con icona, nome, «Moto / scooter · marca modello · Benzina · Euro 6 · TARGA», pillola «In uso» o pulsante «Usa»; tocco (o azione VoiceOver «Modifica <nome>») → modulo; scorri → Elimina → «Eliminare questo veicolo?» «Vengono eliminati anche i suoi permessi. Non si può annullare.»
- «+» in alto «Aggiungi un veicolo».
- «PERMESSI»: tipo, «Firenze · Settore A» (o «nessuna zona: non vale» per i vecchi), date, pillola [`garage.permit.status`] «Confermato» / «In attesa» / «Scegli la zona»: In attesa → «Hai la conferma scritta?» → «Sì, ce l'ho per iscritto» [`permit.confirm.yes`]; Confermato → torna «In attesa» subito; Scegli la zona → modulo. Scorri → Elimina (conferma). **«Aggiungi un permesso»** [`garage.addPermit`]. «Un permesso vale solo nella sua zona, per il veicolo e i giorni scelti.»
- **«CONSIGLI PER <veicolo>»**: per ogni zona: «Moto e scooter possono entrare», «Le auto elettrica possono entrare», «La tua auto non può entrare quando è attiva» (rosso), «Può entrare fino al 30 set 2027», «La classe della tua auto è ammessa»; veicolo «Non so» → «Aggiungi alimentazione e classe Euro per vedere dove può entrare la tua auto.»; nessuna → «Nessuna regola sulle emissioni…». Piè «Dai calendari delle emissioni dei Comuni…».

### 12.2 Nuovo permesso (`PermitForm`)
«Tipo» (Registrazione dall'hotel / Permesso residenti / Contrassegno disabili / Altro permesso), «Dal», «Al»; «DOVE VALE»: «Città», «Zona» [`permit.zone`] obbligatoria; piè «Per <veicolo>. Il permesso vale solo in questa zona…». «Salva» [`permit.save`] (disattivo senza zona) → «Salvare questo permesso?» → «Salva il permesso» [`permit.save.confirm`]. Nasce «In attesa».
- Effetto: residenti/disabili/altro **In attesa** → «A una condizione» «Il tuo permesso aspetta ancora la conferma…»; **Confermato** → «Puoi entrare» «…il tuo permesso copre questo veicolo». **Registrazione dall'hotel** in attesa → resta «Non entrare» + «Chiedi all'hotel…» (vale solo se la zona ha `hotelCanRegister`); confermata → «Puoi entrare» + «L'hotel ha registrato la targa · dal … al …».
- ⚠️ Incongruenza: il testo del dialogo dice sempre «Finché è in attesa, lì GateLR risponde «a una condizione»», anche per «Registrazione dall'hotel» (che è il tipo di serie) dove invece resta «Non entrare».

### 12.3 Modulo veicolo (`VehicleForm`, da Garage, «+», chip «Aggiungi un veicolo»)
- Solo per un veicolo nuovo: «AUTO IN 10 SECONDI» → **«Fotografa il libretto»** [`vehicle.scan`] (§12.3.1) e **«Auto a noleggio: scegli il modello»** [`vehicle.rental`] (elenco modelli tipici del noleggio + scooter; per i modelli con più versioni «Quale alimentazione?»; accende «Auto a noleggio»).
- «Tipo di veicolo» segmentato Auto / Moto / scooter [`vehicle.type`]; «Nome (es. Auto a noleggio)»; «Targa» (maiuscole); **«Cerca dalla targa» con lucchetto e «In arrivo»** [`vehicle.plateLookup`] disattivato (VoiceOver «Cerca dalla targa, In arrivo»); interruttore «Auto a noleggio».
- AUTO: «Marca» (elenco), «Modello» (elenco o testo), «Anno» (1990–oggi, propone la classe Euro). MOTO / SCOOTER: marca e modello a mano.
- «EMISSIONI»: «Alimentazione» [`vehicle.fuel`] con **«Non so»**; interruttore **«Classe Euro da sapere»** [`vehicle.euroUnknown`]; stepper «Euro N» (0–7); per le moto «Due ruote» [`vehicle.motoClass`] Ciclomotore (fino a 50 cc) / Motociclo (oltre 50 cc) e «Motore» [`vehicle.stroke`] 4 tempi / 2 tempi; piè «La classe Euro è sul libretto, campo V.9.» / «Classe Euro proposta dall'anno…».
- «Annulla» / «Salva» (disattivo senza nome né marca; nome vuoto = marca + modello).

#### 12.3.1 Libretto (`RegistrationScanView`)
Foglio «Libretto»: «Fotografa il fronte della carta di circolazione…» + fotocamera/foto (`DocumentCapture`); «In questa foto non riesco a leggere un libretto…»; «CONTROLLA PRIMA DI SALVARE»: Targa, Marca, Modello, Anno, Alimentazione, Classe Euro (nota «Classe Euro dal libretto: «…».» / giallo «Campo V.9 non trovato: classe Euro proposta dall'anno…» / «Classe Euro non trovata…»), «TESTO LETTO DALLA FOTO», **«Usa questi dati»** [`registration.use`] → riempie il modulo (non salva). Legge anche libretti esteri (DE/FR/ES/NL). Serve un'immagine (nessun campo testo).

### 12.4 Impostazioni (`SettingsView`)
- **AVVISI**: interruttore **«Avvisi ai varchi»** (acceso di serie); se acceso ma senza permessi → **«Consenti gli avvisi»** [`settings.allowAlerts`] (richieste iOS notifiche + «Sempre»; se iOS non chiede più → Impostazioni); riga fissa «Avvisi 300 m prima di una ZTL, 600 m sopra i 50 km/h»; **«Prova un avviso»** → notifica di prova dopo 3 s «Non entrare · <zona scelta>» «Tra 300 m. <varco>. Tocca per i parcheggi fuori.» (tocco → parcheggi) → etichetta «Inviato: guarda le notifiche»; notifiche negate → «Le notifiche sono spente: attivale nelle Impostazioni» (tocco successivo → Impostazioni). Piè: «Gli avvisi funzionano ad app chiusa per le città salvate. Serve l'accesso alla posizione «Sempre».»
- 🚫/dev **«Modalità prova»** e **«Dev» → «Navigatore di GateLR»** [`settings.devNavigator`] solo con strumenti di sviluppo (§23).
- **IMPOSTAZIONI**: «Navigatore preferito» (Chiedi ogni volta / Apple Maps / Google Maps / Waze; + «Navigatore di GateLR» solo dev); **«Lingua»** (mostra la lingua, tocco → Impostazioni di iOS dell'app). Piè: «GateLR parla inglese, italiano, tedesco, francese, spagnolo, olandese, polacco e cinese. La lingua si sceglie nelle Impostazioni dell'iPhone.»
- 🚫/dev «Navigatore di GateLR»: «Veicolo sulla mappa» (modellini e colori), consiglio «Scarica una voce migliore», «Voce migliore: scarica una voce Premium o Avanzata».
- **REGOLE E MAPPE**: «Dati delle città» (data della versione, es. «11 nov 2026, 06:26»); **«Controlla aggiornamenti»** → rotella, «Aggiornati» / «Aggiornati ora» / «Non disponibile ora» / «Non firmati: restano i tuoi dati». Piè sulla firma.
- **CITTÀ OFFLINE**: elenco delle 46 città con «bozza · N zone» (o «verificata», «dati di esempio»).
- **INFORMAZIONI SU GATELR**: «Fonti, licenze e avvertenze» → §12.6; «Versione 2.0.2».

### 12.5 Privacy (`PrivacyView`)
«Nessun account, nessuna pubblicità, nessun tracciamento.»; «RESTA SU QUESTO IPHONE» (veicoli e targhe, permessi, viaggi e diario; posizione; foto lette sul telefono); «COSA ESCE» (Apple Mappe, Mapbox, GitHub, OpenStreetMap/Overpass, quello che mandi tu; IP); «LA TUA TARGA» (mai in testi condivisi, copie, widget, Siri, notifiche, Live Activity; eccezione il messaggio per l'hotel); interruttore **«Telemetria di Mapbox»** [`privacy.mapboxTelemetry`] (spento di serie) «Puoi cambiarla anche dalla (i) sulla mappa 3D.»

### 12.6 Informazioni (`AboutView`)
«Sappilo prima del varco.», descrizione; «DA SAPERE» (cartelli valgono più dell'app; città «Bozza»; non collegata a Comuni o polizia); **«Come controlliamo i dati»**, **«Cosa fare se ricevi una multa»** (§5); «CARATTERE E MAPPE» (Titillium Web OFL; Apple Mappe e Mapbox; OSM ODbL); link della famiglia LR («AudioLR, OrbitLR, WebcamLR, GateLR»).

---

## 13. «Segnala un errore» per una zona (`ZoneReportView`)
**Come si arriva**: Adesso → «Segnala un errore» sotto la risposta [`varco.report`]; scheda della zona [`zone.report`] (suggerimento VoiceOver «Dicci cosa non va negli orari, nei confini o nei varchi di questa zona»).
- «COSA NON VA?» Orari / Confini / Varco / Altro; «NOTA» «es. il pannello dice 7.30–19.30, l'app dice 20.00»; «FOTO (FACOLTATIVA)» «Scatta una foto» (solo con fotocamera) / «Scegli una foto», anteprima «Foto allegata» + «Togli la foto»; interruttore **«Allega posizione»** (spento di serie); «AGGIUNTO PER TE» (Cosa, Città, Zona, Data e ora «(ora italiana) · adesso / ora scelta», Veicolo senza targa, Rif.; con la zona di prova «Zona di prova (modalità prova)»); piè «Niente targa…»; **«Invia la segnalazione»** → Mail (se configurata) a support@example.com con oggetto «GateLR – Segnala un errore · Città · Zona», altrimenti foglio Condividi (testo + foto); «Grazie!». «Si invia per email a support@example.com. Senza Mail, puoi condividerla con un'altra app.»

---

## 14. Permessi e notifiche (quando compaiono le richieste di iOS)
| Momento | Posizione | Notifiche |
|---|---|---|
| Avvio dell'app / fine presentazione | — | — |
| «Usa la mia posizione» (Adesso, In auto) | Mentre usi l'app | — |
| «Attiva gli avvisi» (presentazione), «Consenti gli avvisi» (Impostazioni) | Sempre | sì |
| Avvio del guardiano | Sempre (+ precisione temporanea se approssimativa) | sì |
| «Ricordamelo» (ticket), stato hotel, «Prova un avviso» | — | sì |
| «Usa la fotocamera» | — (fotocamera) | — |
Testi di iOS (inglese nel plist, tradotti in `InfoPlist.strings`): fotocamera, posizione in uso, «Sempre», precisione temporanea `GateLRGates`.

**Notifiche locali dell'app**: avviso varco (guardiano / app chiusa, «Non entrare · …», tocco → parcheggi); «Sei arrivato»; «Guardiano fermato.»; avviso di prova (id `test`); promemoria ticket (`ticket|<zona>`); promemoria hotel (`stay|<posto>`). Con l'app aperta la notifica si vede comunque come banner (avviso di prova) o come banner interno (avvisi veri). Nessuna notifica push remota.

---

## 15. Widget (`GateLRWidgets`)
Aggiunta: Home → tieni premuto → «+» → GateLR. Configurazione: tieni premuto → «Modifica widget» → **«Zona»** (tutte le zone delle città; di serie quella scelta nell'app, poi Firenze Settore B).
1. **«Varchi ZTL»** (`GateLRWidget`) — «Se il tuo veicolo può entrare nella tua zona adesso, e quando cambia.» Famiglie: piccolo Home, schermata di blocco circolare, rettangolare, in linea. Mostra la parola della risposta per il veicolo in uso (dall'App Group), lettera della zona, «Finisce alle %@» / «Inizia alle %@» (ora italiana), «ZTL attiva/non attiva», «Dati da ricontrollare», «⚠︎ Fonte non ufficiale»; mai la targa (nome «Panda GX482KM» → «Panda»). Tocco → `gatelr://varco` (Adesso). Si aggiorna a ogni cambio nelle 24 ore (zone sempre attive: ogni 6 ore).
2. **«Guardiano»** (`GuardianWidget`) — «La tua zona adesso e un tocco per avviare il guardiano da Viaggio.» Famiglie: piccolo, circolare, rettangolare; «Guardiano», «Avvia il guardiano». Tocco → `gatelr://trip` (scheda Viaggio; il guardiano NON parte da solo).
3. Zona scelta che non esiste più (es. zona di prova) → Firenze Settore B.

## 16. Live Activity / Dynamic Island (`DriveLiveActivity`)
- Del **guardiano** (e della guida interna dev). Schermata di blocco e Dynamic Island (iPhone 14 Pro e successivi): livelli «no» rosso (Non entrare + zona + distanza), «cond» giallo, «clear» grigio «Nessuna ZTL attiva davanti», «none» neutro «Non conosciamo le ZTL di questo posto», «In attesa del GPS…»; mai verde; senza aggiornamenti da 3 minuti grigia «Non aggiornato: apri GateLR». Mai la targa. Tocco → Adesso. Si chiude allo stop; quelle orfane si chiudono all'avvio dell'app o con Siri «Ferma il guardiano».

## 17. Siri / Comandi rapidi (`GateLRShortcuts`)
Frasi italiane (`AppShortcuts.strings`):
- **«ZTL vicine»** (NearbyZTLIntent): «ZTL vicine con GateLR», «Ci sono ZTL vicine in GateLR», «GateLR ZTL», «Chiedi a GateLR delle ZTL». Risposte: «Sei dentro Settore A: Non entrare. I varchi si spengono oggi alle 20:00.»; area pedonale «Sei dentro Area pedonale · …: Non entrare.»; fuori «Settore A è a 400 m: …»; «Nessuna ZTL nel raggio di 5 km.» (città coperta); «Non conosciamo le ZTL di questo posto.»; senza posizione precisa (approssimativa = niente) «Non trovo la tua posizione. Apri GateLR e consenti l'accesso alla posizione.» (attende fino a 8 s). Non apre l'app.
- **«Posso entrare?»** (CanIDriveIntoIntent, parametri «Zona» e «Arrivo alle»): «Posso entrare a ${zona} con GateLR», «Posso entrare in ${zona} con GateLR», «GateLR ${zona}», «Posso entrare con GateLR» (chiede «Quale zona ZTL?»). Zone dette «Firenze Settore A», «Milano Area C»… (nomi doppi numerati). Risposta «Firenze Settore A: Non entrare. I varchi si spengono oggi alle 20:00.» (+ condizione/motivo, + «Dentro ci sono aree pedonali: lì le auto non entrano mai.»); con l'arrivo: «Firenze Settore A, domani alle 09:00: …»; ora passata = la prossima volta a quell'ora. «Non trovo questa zona in GateLR.»
- **«Ferma il guardiano»** (StopGuardianIntent): «Ferma il guardiano di GateLR», «Ferma il guardiano GateLR», «GateLR ferma il guardiano» → «Guardiano fermato.» / «Il guardiano non è attivo.»
- Le frasi non contengono mai la targa. I nomi delle zone si aggiornano dopo il caricamento delle città.

## 18. CarPlay (`CarPlaySceneDelegate`) — 🚫 non provabile
Un solo schermo `CPInformationTemplate` «GateLR»: (col guardiano) la ZTL davanti con distanza o «Nessuna ZTL attiva davanti»/«Non conosciamo…»; risposta della zona scelta; nome zona + «ZTL attiva/non attiva»; «Fonte · Letto il … · Non verificato»; pulsante «Aggiorna». Si aggiorna ogni 3 s col guardiano. Manca l'entitlement CarPlay nell'app (`GateLR.entitlements`): non compare né in auto né nel simulatore CarPlay.

## 19. Indirizzi `gatelr://` (`AppRouter.destination`)
| URL | Dove porta |
|---|---|
| `gatelr://adesso`, `varco`, `now`, host sconosciuto | scheda Adesso |
| `gatelr://map`, `mappa` | scheda Mappa |
| `gatelr://trip`, `viaggio`, `guardian`, `guardiano` | scheda Viaggio |
| `gatelr://help`, `aiuto` | scheda Aiuto (radice) |
| `gatelr://fines`, `multe` | Aiuto → Ho preso una multa? |
| `gatelr://log`, `diario` | Aiuto → Diario dei passaggi |
| `gatelr://learn`, `impara` | Aiuto → Cos'è una ZTL? |
| `gatelr://cartello`, `sign` | Aiuto → Leggi il cartello (pagina, non il foglio) |
| `gatelr://garage` | foglio Garage e impostazioni → Garage |
| `gatelr://settings`, `impostazioni` | → Impostazioni |
| `gatelr://privacy` | → Privacy |
| `gatelr://account`, `you`, `tu` | foglio Garage e impostazioni (elenco) |
| `gatelr://park?zone=<id>&lat=<lat>&lon=<lon>&name=<nome>` | foglio «Parcheggia fuori» per quel punto |
Nessun indirizzo per Informazioni, «Fotografa il verbale», le pagine Fiducia, In auto o un posto/ricerca.

## 20. Lingue
8 lingue: inglese (sviluppo), **italiano**, tedesco, francese, spagnolo, olandese, polacco, cinese semplificato (`CFBundleLocalizations`; `Localizable.strings` 1024 righe ciascuna, `AppShortcuts.strings`, `InfoPlist.strings`). Lingua = quella dell'iPhone o quella scelta per l'app in Impostazioni → GateLR → Lingua (Impostazioni → «Lingua» nell'app apre lì). Testi delle città: italiano/inglese/tedesco (le altre lingue vedono l'inglese, con la citazione italiana). I pannelli restano in italiano («ZTL ATTIVA»). Messaggio hotel solo IT/EN/DE. Link del sito: it/, de/, altrimenti inglese. Le date sono nella lingua, ma sempre ora di Roma.

## 21. Aspetto e accessibilità
- **Tema**: Giorno/Notte automatici dal telefono (2.3 «direzione C»); la presentazione è sempre scura; `-uiDark` forza lo scuro. Il blocco della risposta è identico nei due temi.
- **Dynamic Type**: carattere Titillium Web che cresce fino a un tetto; `AdessoLayout`: schermo ≤ 700 pt (iPhone SE) o testo «accessibilità» → pagina compatta (striscia 72 pt, ricerca a lente, titolo su 1 riga); entrambe → «tight» senza striscia; pulsanti secondari uno sotto l'altro; pillola sotto il nome nella scheda posto della Mappa; scheda posto che scorre; link Fiducia uno sotto l'altro; pulsanti della presentazione fissi in basso.
- **VoiceOver**: risposta letta per prima in un colpo solo (intestazione) con «Per <veicolo>, adesso»; riga del posto come intestazione; «Città: …», «Ora: …», «Veicolo: …», «Leggi il cartello», «Garage e impostazioni» (+ valore), «Guarda la mappa» + valore, «Legenda: Non entrare, A una condizione, Puoi entrare, ZTL non attiva», segni delle zone sulla mappa «<zona>, ZTL, <risposta>», telecamere «Telecamera corsia bus, <nome>», «Cerca dalla targa, In arrivo», azione «Modifica <veicolo>», «Chiudi» sulla legenda, banner dell'avviso che non sparisce con VoiceOver. Varchi e aree pedonali sulla mappa sono nascosti a VoiceOver (troppi).
- **Riduci movimento**: dissolvenze al posto degli spostamenti (risposta, banner, presentazione, legenda).
- Bersagli ≥ 44 pt; «In auto» ≥ 76 pt.
- **iPad**: tutte le orientazioni (iPhone solo verticale); Adesso con mappa (alta) e risposta affiancate (colonna 440 pt); Viaggio/Garage/Impostazioni/fogli a larghezza leggibile; Mappa a tutto schermo con barra e scheda ≤ 700 pt; più finestre (scene multiple).

## 22. Dati delle città e aggiornamento (`CityUpdater`)
- All'avvio, al più ogni 12 ore, e con «Controlla aggiornamenti»: legge `https://raw.githubusercontent.com/LR-apps609/GateLR/main/Resources/Cities/manifest.json` (+ `manifest.sig`), ETag, timeout 20 s; usa solo aggiornamenti **firmati** (chiave `shared/city-signing-key.txt`); scarica le città con impronta diversa; i dati nuovi si usano alla prossima apertura. Senza firma: «Non firmati: restano i tuoi dati».
- Il widget usa le città scaricate solo se firmate (App Group).
- Regole di fiducia: >120 giorni dalla data più recente tra lettura e verifica → «Controlla il cartello · Dati scaduti»; `pageChanged` → ogni risposta «?» «La pagina del Comune è cambiata: controlla il cartello.»

## 23. Strumenti di sviluppo (solo Debug o `GATELR_DEV_TOOLS=YES`) — 🚫 per l'utente
- **Modalità prova** (Impostazioni → «Modalità prova»): «Crea una ZTL finta larga circa 400 m intorno a te, con 1–2 varchi sulle strade vicine e un parcheggio fuori…»; serve la posizione («Cerco le strade intorno a te…» / «La tua posizione non è disponibile…»); «Varco di prova N», «Parcheggio di prova», «ZTL di prova attiva adesso / spenta», «Sposta la zona qui»; striscia viola «Modalità prova attiva» in cima a schede e fogli con «Spegni» e menu «Opzioni della modalità prova» (Spegni/Accendi la ZTL di prova, Sposta la zona qui, Spegni la modalità prova). Senza dev tools la sezione non c'è (ma uno stato già salvato resterebbe visibile).
- **Navigatore di GateLR** (guida interna `DriveView`/`DriveSession`, voce turn-by-turn, viste, ricalcolo, Live Activity con manovre): solo con Dev → «Navigatore di GateLR» acceso (o `-devInternalNavigator YES`), poi compare nei menu «Avvia» e come navigatore preferito «gatelr»; impostazioni «Veicolo sulla mappa» e voce.
- **GPX** (`Resources/GPX`, non nell'app): `bologna-in-centro-dal-varco`, `firenze-viale-cavour-settore-a`, `firenze-viali-parcheggio-beccaria`, `pisa-intorno-alla-ztl`, `roma-tridente-avvicinamento`, `siena-avvicinamento-varco` → Xcode › Debug › Simulate Location (anche su iPhone collegato).

## 24. Argomenti di avvio (`launchArguments`, utili nel simulatore)
Valgono solo con `-uitest`, salvo dove indicato. **Attenzione: `-uitest` spegne presentazione, Novità, consigli TipKit, richieste di permesso, recensione e avvisi all'avvio.**
| Argomento | Effetto |
|---|---|
| `-uitest` | modalità test (vedi sopra) |
| `-uiPlace "<nome>" <lat> <lon>` | **anche senza -uitest**: sceglie quel posto all'avvio |
| `-uiAt HH:MM` | sceglie quell'ora (Roma) del prossimo mar/mer/gio non festivo |
| `-uiVehicle <fuel> <euro>` | garage = un solo veicolo «Prova» (fuel: petrol, diesel, hybrid, electric, lpg) |
| `-uiPlate GX482KM` | targa al veicolo + 2 righe finte nel Diario (Firenze) |
| `-uiUnofficial <cityId>` | segna le zone di quella città come fonte non ufficiale (example.org) |
| `-uiTestMode <lat> <lon>` | modalità prova in quel punto |
| `-uiGuardian <lat> <lon> <rotta>` | guardiano dimostrativo acceso lì (senza GPS, navigatore, voce, Live Activity) |
| `-uiGuardianDrive <secondi> <m/s>` | dopo -uiGuardian: posizioni simulate in linea retta |
| `-uiOrigin <lat> <lon>` | partenza del percorso/parcheggi senza GPS |
| `-uiDark` | tema scuro forzato (anche senza -uitest) |
| `-showOnboarding` + `-onboarded NO` | presentazione anche in -uitest |
| `-intro2` | presentazione a ogni avvio (anche senza -uitest) |
| `-intro2MapKit`, `-intro2Fallback`, `-intro2Autoplay`, `-intro2Standard` | varianti della presentazione |
| `-uiFps`, `-uiMemory`, `-uiLive`, `-uiNoParkingCache`, `-uiNoStrip` | misure |
| `-AppleLanguages "(it)" -AppleLocale it_IT` | lingua/regione |
| `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL` | testo grandissimo |
| `-<chiave UserDefaults> <valore>` | qualsiasi `@AppStorage`: `-onboarded YES`, `-introVersionSeen 2` (servono ENTRAMBI per saltare la presentazione senza -uitest), `-navigator google`, `-devInternalNavigator YES` (solo con dev tools) |
Posti usati dai test: Palazzo Vecchio 43.7693 11.2563; Duomo di Milano 45.4641 9.1919; Corso Magenta 45.4658 9.1780; Via degli Abeti 45.4524 9.0849; Piazza Maggiore 44.4939 11.3426; Via Galliera 44.50337 11.34431; Piazza dei Signori (Treviso) 45.6664 12.2430; Piazza del Duomo Pistoia 43.9333 10.9167; Zona di prova 43.7765 11.2830.

## 25. Casi limite del motore da provare (con «Scegli giorno e ora…» e il veicolo)
- **Ora del giorno**: Firenze Settore A lun–ven 7:30–20:00, sab 7:30–16:00 → Palazzo Vecchio mar 10:00 «Non entrare», mar 23:00 «ZTL non attiva» (se nessuna fascia estiva), sab 17:00 spenta. «Stasera 20:00» compare solo prima delle 20.
- **Stagioni**: Firenze A/B/O/F/G notti gio–ven–sab 23:00–3:00 dal primo giovedì di aprile alla prima domenica di ottobre (es. ven 11/06/2027 23:30 «Non entrare»; mezzanotte = fascia del giorno prima); anche Bergamo, Cortona, Matera, Montepulciano, Napoli (ZTL natalizia Morelli), Palermo, Padova, Parma, Roma (notturne), San Gimignano, Sorrento, Volterra.
- **Festivi**: nazionali (1/1, 6/1, Pasquetta, 25/4, 1/5, 2/6, 15/8, 1/11, 8/12, 25–26/12, **4/10 dal 2026**) e patroni (`localHolidays`); zone con `freeOnHolidays` non indicato → «Controlla il cartello · Festivo da confermare» (Firenze settori l'8/12/2026 alle 10:00); `uncertainDays` → «In questo giorno il Comune non dice se la ZTL è attiva…» (Firenze e Torino 24/06, Milano 07/12); «festivi come la domenica».
- **Veicolo**: elettrica esente a Milano Area C/B, Ostuni, Treviso, Padova/Parma (anche ibride) → «Puoi entrare»; **diesel Euro 1** nello Scudo Verde di Firenze → «Non entrare» (anche di notte, anche a Settore A spento); divieti futuri «Può entrare fino al …» nei Consigli; Milano Area C benzina Euro 6 feriale 11:00 → «A una condizione» (ticket 7,50 €); Area B auto ammessa → «Puoi entrare»; zona verde senza divieti → «A una condizione».
- **Moto/scooter**: settori di Firenze, Roma (tranne Tridente), Lecce, Pisa, Verona, Modena, Lucca B, Arezzo A, Ascoli, Napoli Tarsia/Morelli, Bergamo Colli, Palermo, Padova, Parma → «Puoi entrare» «…moto e scooter possono entrare.»; Scudo Verde con `motoBans`: moto Euro 5 «Puoi entrare… zona a basse emissioni», ciclomotore 2 tempi Euro 1 «Non entrare»; zone con divieti Euro solo per auto (Milano Area B) → «A una condizione» «Qui le moto hanno limiti Euro loro…».
- **«Non so»** (alimentazione o classe Euro) dove contano (zone verdi, divieti Euro, carburanti esenti) → «Controlla il cartello · Classe Euro da sapere»; dove non contano risposta normale; chip «Auto · ?».
- **Hotel**: §9.3 (Non entrare + «Chiedi all'hotel…» → Puoi entrare con le date).
- **Area pedonale vince**: Piazza Maggiore Bologna (in ZTL) e Via Galliera (fuori dalle zone) → «Non entrare», «Sempre, a ogni ora», anche alle 23:58.
- **300 m davanti**: solo con posizione in movimento; simulare con `simctl location … start --speed` verso una zona.
- **pageChanged**: zone di Arezzo, Ferrara, Genova, Matera, Montepulciano, Palermo, Perugia, San Gimignano, Verona → «Controlla il cartello · Dati scaduti» anche dove sarebbe «Non entrare».
- **Fonte non ufficiale**: Cagliari, Mantova, Ostuni, Polignano a Mare, Salerno → «sì» diventa «Controlla il cartello» «Probabilmente sì · fonte non ufficiale»; «no» resta rosso con «Probabilmente no · fonte non ufficiale»; fuori dalle loro zone (entro 2 km) giallo, non grigio.
- **Fuori copertura**: Pistoia, Prato, Venezia → «Non conosciamo questo posto».
- «Non ancora verificata a mano»: oggi su ogni zona (nessuna `reviewedByHuman`), mai cambia il colore.

## 26. Città (46) e posti di prova (lat, lon)
Formato: città · zone/aree pedonali · punto DENTRO · VARCO/bordo · APPENA FUORI · PEDONALE · note. Tutte «Bozza».
- **Alghero** · 1 zona · dentro 40.55883, 8.31276 · varco Via Simon/P.zza Porta Terra 40.55872, 8.31523 · fuori 40.56058, 8.31010 · hotel
- **Arezzo** · 4 zone, 9 ped · ZTL B sud 43.46166, 11.87818 · varco Corso Italia 43.46097, 11.87800 · fuori 43.46057, 11.88065 · ped Piazza Grande 43.46467, 11.88438 · pageChanged, moto esenti in A
- **Ascoli Piceno** · 5 zone, 2 ped · Corso Trento e Trieste 42.85483, 13.57624 · varco XX Settembre 42.85357, 13.57559 · fuori 42.85324, 13.57663 · ped Piazza del Popolo 42.85462, 13.57473
- **Bari** · Bari Vecchia 41.12945, 16.87018 · varco V1 41.13309, 16.86997 · fuori 41.12554, 16.87292
- **Bergamo** · 17 zone · Piazzale Marconi (corsie stazione) 45.69108, 9.67509 · bordo 45.69104, 9.67474 · fuori 45.69093, 9.67360 · stagionali (Città Alta/Colli: ven 30/10 21:30 vs sab 23:00)
- **Bologna** · 2 zone (ZTL a pagamento con ticket 6 €, Zona T sempre) · Via Indipendenza 44.4980, 11.3433 · Zona T 44.49579, 11.34293 · fuori: Stazione Centrale 44.5058, 11.3426 (grigio) · ped Piazza Maggiore 44.4939, 11.3426 (in ZTL) e Via Galliera 44.50337, 11.34431 (fuori zone) · 62 ped, 33 telecamere
- **Bolzano** · ZTL 0–24 46.49863, 11.35352 · varco Largo Kolping 46.49758, 11.35040 · fuori 46.49553, 11.35198
- **Cagliari** (fonte NON ufficiale) · 5 zone · Stampace Alto 39.21896, 9.11366 · bordo 39.22071, 9.11349 · fuori (giallo) 39.22150, 9.11341
- **Catania** · Teatro Massimo 37.50411, 15.08953 · varco Via Leonardi 37.50355, 15.09013 · fuori 37.50390, 15.08658 · ped Via Etnea/P.zza Duomo 37.50419, 15.08699
- **Como** · Città Murata 45.81130, 9.08270 · varco Via Cinque Giornate 45.80914, 9.07883 · fuori 45.81039, 9.07622 · ped P.zza Cavour 45.81300, 9.08089
- **Cortona** · 2 zone · Via Nazionale 43.27482, 11.98628 · varco P.le Garibaldi 43.27410, 11.98794 · fuori 43.27374, 11.98729 · stagionali
- **Ferrara** · 11 zone a pagamento (ticket), pageChanged · ZTL C nord Castello 44.84070, 11.62378 · bordo 44.84040, 11.62464 · fuori 44.84004, 11.62566
- **Firenze** · 6 zone (A, B, O, F, G stagionali + Scudo Verde 24h con divieti Euro e motoBans), 420 ped, 10 telecamere · Palazzo Vecchio 43.7693, 11.2563 (A + Scudo) · Stazione SMN 43.7764, 11.2480 (B) · Pitti 43.7652, 11.2500 (O) · Viale Gramsci 43.7762, 11.2693 (solo Scudo Verde) · ped Piazza del Duomo 43.7731, 11.2560, Piazzale Michelangelo 43.7629, 11.2650 · fuori dalle zone: Bagno a Ripoli 43.7590, 11.3200 (grigio «Fuori dalla ZTL») · uncertainDays 24/06
- **Genova** · 6 zone, pageChanged · Nervi Via Gazzolo 44.38347, 9.03181 · varco 44.38418, 9.03254 · fuori 44.38202, 9.03025
- **Lecce** · 40.35367, 18.17030 · varco Porta Napoli 40.35668, 18.16853 · fuori 40.35252, 18.16467 · moto esenti
- **Lucca** · 3 zone · San Michele (A) 43.8430, 10.5040 · Settore B Villa Bottini 43.84416, 10.51249 · fuori 43.84243, 10.51220
- **Mantova** (NON ufficiale) · 3 zone · ZTL N 45.16383, 10.79278 · varco Cavriani 45.16319, 10.79159 · fuori 45.16420, 10.79026
- **Matera** · 9 zone, pageChanged · San Biagio 40.66815, 16.60843 · varco Stigliani 40.66867, 16.60827 · fuori 40.66927, 16.60848
- **Milano** · 25 zone (Area C a pagamento 7,50 € con divieti Euro, Area B verde, ZTL locali), 121 ped · Corso Magenta 45.4658, 9.1780 (C+B) · Navigli 45.4520, 9.1760 (solo B) · fuori: Via degli Abeti 45.4524, 9.0849, Linate 45.4490, 9.2770 · ped Piazza del Duomo 45.4641, 9.1919 · uncertainDays 07/12, elettriche esenti
- **Modena** · 44.64649, 10.92555 · bordo 44.64920, 10.92970 · fuori 44.64974, 10.93053 · moto esenti
- **Montepulciano** · pageChanged, stagionale · 43.09390, 11.78211 · varco Porta al Prato 43.09701, 11.78504 · fuori 43.09740, 11.78617
- **Napoli** · 4 zone · Spaccanapoli 40.8492, 14.2550 · Morelli (natalizia) 40.83555, 14.24288 · fuori 40.83690, 14.23727
- **Ostuni** (NON ufficiale, elettriche esenti) · 40.73372, 17.57822 · varco Via Cattedrale 40.73248, 17.57811 · fuori 40.73519, 17.57606
- **Padova** · 4 zone (B, A, domeniche ecologiche, antismog verde con divieti), 3 telecamere · Zona B 45.40563, 11.87641 · varco Largo Europa 45.41063, 11.87796
- **Palermo** · ZTL centrale con ticket e divieti Euro, pageChanged · 38.11520, 13.36106 · bordo 38.11442, 13.37449 · fuori 38.11436, 13.37550 · ped Cassaro 38.11464, 13.35885
- **Parma** · 10 zone (ticket, PAIR verde, domeniche ecologiche) · Stazione 44.80936, 10.32777 · bordo 44.80973, 10.32626
- **Perugia** · 5 zone, pageChanged · Via del Roscetto (solo 16–20) 43.11340, 12.39290 · varco 43.11392, 12.39328 · fuori 43.11444, 12.39286
- **Pisa** · 3 zone, moto esenti · Torre 43.7230, 10.3966 (nord) · Lungarni notturna 43.71549, 10.40221 · fuori 43.71690, 10.39734
- **Polignano a Mare** (NON ufficiale) · 40.99615, 17.21953 · varco Arco Marchesale 40.99559, 17.21877 · fuori 40.99800, 17.21863
- **Ravenna** · ticket · 44.41708, 12.19976 · varco Via Baccarini 44.41507, 12.19981 · fuori 44.41267, 12.19712
- **Rimini** · 14 zone con ticket, 3 ped · Corso d'Augusto nord 44.06276, 12.56446 · varco 44.06303, 12.56439 · fuori 44.06173, 12.56399 · ped Piazza Malatesta 44.05968, 12.56433
- **Roma** · 6 zone (Centro, Tridente, Trastevere, Trastevere notte, San Lorenzo, Testaccio), moto esenti tranne Tridente · Pantheon 41.8986, 12.4769 · Piazza di Spagna 41.9057, 12.4823 (Centro+Tridente) · S. Maria in Trastevere 41.8894, 12.4700 · Colosseo 41.8902, 12.4922 · fuori: Termini 41.9010, 12.5010, Vaticano 41.9029, 12.4534 · patrono 29/06
- **Salerno** (NON ufficiale) · Duomo 40.6807, 14.7598 · varco Antica Corte 40.67870, 14.75758 · fuori (giallo) 40.67960, 14.74888
- **San Gimignano** · pageChanged, stagionale · 43.46788, 11.04354 · varco Porta San Giovanni 43.46471, 11.04261 · fuori 43.46407, 11.04167
- **San Giovanni Valdarno** · 2 zone, 2 ped · Corso Italia 43.56510, 11.53009 · varco 43.56309, 11.53189 · fuori 43.56741, 11.52813 · ped Piazza Cavour 43.56500, 11.53083
- **Siena** · ZTL 24h · Piazza del Campo 43.3184, 11.3316 · varco Bastianini 43.31466, 11.32611 · fuori 43.31529, 11.33215
- **Siracusa** · Ortigia 37.06086, 15.29439 · varco Via Malta 37.06440, 15.29000 · fuori 37.06534, 15.29656
- **Sirmione** · 45.49565, 10.60599 · varco Largo Goethe 45.49154, 10.60836 · fuori 45.49508, 10.60948
- **Sorrento** · stagionale · Piazza Tasso 40.62724, 14.37437 · varco Fuorimura 40.62541, 14.37631 · fuori 40.62930, 14.37424
- **Torino** · 12 zone, 8 ped · Castello 45.0710, 7.6860 (centrale) · Via San Francesco d'Assisi (riservata bus) 45.07040, 7.67921 · varco Pietro Micca 45.07033, 7.67847 · ped Via Garibaldi 45.07302, 7.67929 · uncertainDays 24/06
- **Trento** · 46.06900, 11.12315 · varco via Pozzo 46.07008, 11.11972 · fuori 46.06518, 11.12083
- **Treviso** · 2 zone (centro, Manin 22–6), elettriche esenti · Piazza dei Signori 45.6664, 12.2430 · Via Manin 45.66482, 12.24372 · fuori 45.66607, 12.24070 · senza parcheggi dentro l'app (Overpass)
- **Trieste** · 6 zone B · Via Mercadante 45.65300, 13.77565 · bordo 45.65281, 13.77559 · fuori 45.65203, 13.77536
- **Verona** · 3 zone, pageChanged, moto esenti · Arena 45.4390, 10.9944 · Riva San Lorenzo 45.44115, 10.99055 · fuori 45.43980, 10.98768
- **Vicenza** · 45.54826, 11.54521 · varco P.le De Gasperi 45.54587, 11.54040 · fuori 45.54333, 11.54227
- **Volterra** · stagionale · 43.40217, 10.86073 · varco Porta San Francesco 43.40420, 10.85512 · fuori 43.40025, 10.85811
- **Fuori copertura**: Pistoia 43.9333, 10.9167; Prato; Venezia.
(I punti «fuori» sono 80–90 m oltre un vertice del perimetro, controllati fuori da ogni zona e area pedonale; i punti «dentro» sono controllati dentro la zona e fuori dalle aree pedonali.)

## 27. Nel Simulatore: cosa si può pilotare e cosa no

### Si può pilotare 🖥️
- **Posizione** — `xcrun simctl location booted set 43.7693,11.2563` (dentro Settore A); `xcrun simctl location booted start --speed=12 43.7762,11.2693 43.7745,11.2680 43.7731,11.2560` (verso una zona: «N m davanti a te», guardiano, avvisi); `xcrun simctl location booted clear`. Oppure i GPX da Xcode › Debug › Simulate Location (solo da Xcode). Permessi: `xcrun simctl privacy booted grant location-always it.ledion.GateLR` (o `location`), `… revoke location …` per «negata», `xcrun simctl privacy booted reset all it.ledion.GateLR` per riavere le richieste. Posizione approssimativa: Impostazioni del simulatore → GateLR → Posizione → «Posizione esatta» spento.
- **Tema** — `xcrun simctl ui booted appearance dark|light`.
- **Testo grande** — `xcrun simctl ui booted content_size accessibility-extra-extra-extra-large` (o `extra-small`… `accessibility-medium`); contrasto `xcrun simctl ui booted increase_contrast enabled`.
- **Deep link** — `xcrun simctl openurl booted "gatelr://map"`, `"gatelr://garage"`, `"gatelr://park?zone=firenze-a&lat=43.7693&lon=11.2563&name=Palazzo%20Vecchio"`.
- **Notifiche simulate** — `xcrun simctl push booted it.ledion.GateLR avviso.apns` con un JSON tipo `{"Simulator Target Bundle":"it.ledion.GateLR","aps":{"alert":{"title":"Non entrare · Firenze Settore A","body":"Tra 300 m. Tocca per i parcheggi fuori."},"sound":"default"},"url":"gatelr://park?zone=firenze-a&lat=43.7693&lon=11.2563&name=Palazzo%20Vecchio"}` → banner; il tocco apre «Parcheggia fuori» (lo stesso codice delle notifiche vere). Le notifiche locali vere (Prova un avviso, Ricordamelo, hotel) funzionano nel simulatore dopo aver concesso le notifiche.
- **Foto** — `xcrun simctl addmedia booted cartello.jpg libretto.jpg verbale.jpg` → poi «Scegli una foto» in Leggi il cartello, Libretto, Verbale, Segnala un errore. Il riconoscimento del testo (Vision) funziona anche nel simulatore. In alternativa: scrivere il testo a mano (cartello e verbale; il libretto no).
- **Ora** — non si cambia l'orologio del simulatore da `simctl`: usare il chip «Adesso ▾» → «Scegli giorno e ora…», oppure `-uitest -uiAt 22:00`. `xcrun simctl status_bar booted override --time 9:41` cambia SOLO la scritta nella barra di stato, non l'ora usata dall'app.
- **Lingua** — argomenti `-AppleLanguages "(fr)" -AppleLocale fr_FR`, o Impostazioni del simulatore → GateLR → Lingua.
- **Argomenti di avvio** — `xcrun simctl launch booted it.ledion.GateLR -uiPlace "Palazzo Vecchio" 43.7693 11.2563 -onboarded YES -introVersionSeen 2` (o `--terminate-running-process`).
- **Ripartire da zero** — `xcrun simctl uninstall booted it.ledion.GateLR` e reinstallare (presentazione, permessi, auto di esempio).
- **Widget e schermata di blocco** — aggiunta manuale nel simulatore (Home e Lock Screen), configurazione della zona; il tap apre gli URL.
- **Live Activity / Dynamic Island** — compaiono nel simulatore (iPhone 15/16/17 Pro per l'isola) avviando il guardiano con una posizione simulata; il navigatore esterno: Apple Maps c'è; Google Maps/Waze si aprono nel browser (link https).
- **Recensione** — `requestReview` nel simulatore mostra il dialogo di prova (dopo «Salva questo viaggio», non con -uitest).
- **Ricerca indirizzi, percorsi, Look Around, parcheggi Apple/Overpass, aggiornamento città** — servono la rete del Mac. Senza rete (Network Link Conditioner o rete spenta) si vedono gli stati d'errore.
- **iPad** — simulatori iPad per il layout affiancato e le rotazioni.
- **VoiceOver** — non c'è VoiceOver nel simulatore: si verifica con Accessibility Inspector di Xcode (etichette, ordine, identificatori).

### Non si può provare (o non del tutto) nel Simulatore
- **Fotocamera** (Usa la fotocamera, testo dal vivo, Scatta una foto): il simulatore non ha fotocamera → i pulsanti non compaiono (`CameraPicker.isAvailable` falso); restano «Scegli una foto» e il testo a mano. Anche il riquadro «Consenti la fotocamera» non si vede.
- **CarPlay**: manca l'entitlement → l'app non compare (né nel simulatore CarPlay di Xcode né in auto).
- **Siri vocale**: non disponibile nel simulatore; le App Intents si possono al più provare dall'app Comandi rapidi / Spotlight se presenti nel runtime (da verificare) — la voce va provata su iPhone.
- **Avvisi ad app chiusa con rilancio in sottofondo** (`CLMonitor`, app terminata da iOS) e **«Sempre» reale in auto**: nel simulatore gli eventi di regione con la posizione simulata possono arrivare, ma il comportamento energetico/rilancio va provato su iPhone 📱.
- **Voce del guardiano** con altre app audio (ducking), **schermo sempre acceso** in «In auto», vibrazioni (`sensoryFeedback`): solo su iPhone 📱.
- **Mail** (`MFMailComposeViewController`): nel simulatore non c'è Mail → «Segnala un errore» passa al foglio Condividi; «Invia per email» (mailto) non apre niente.
- **Google Maps / Waze come app**: non installabili → si aprono nel browser.
- **Notifiche push remote**: l'app non le usa (solo locali); `simctl push` serve solo a simulare la presentazione/tocco.
- **Mapbox 3D** senza `Config/Local.xcconfig`: si vede la mappa di Apple; con il token funziona anche nel simulatore (più lenta).
- **Navigatore interno, modalità prova**: solo con strumenti di sviluppo (Debug) — non sono funzioni dell'utente.
- **«Lascia una recensione»**: nascosto finché non c'è `APP_STORE_ID`.
- **«Cerca dalla targa»**: sempre disattivato («In arrivo»).
- **Dati scaduti per età** (>120 giorni): non raggiungibili oggi senza cambiare l'orologio del Mac (si vedono solo con `pageChanged`).

## 28. Funzioni dei vecchi documenti (checklist-prova.md) NON più raggiungibili nella UI 2.0.2
1. Le **tre schede «Varco / Mappa / Tu»** e la scheda **«Tu»/«Account»** (e prima ancora le cinque schede): ora Adesso/Mappa/Viaggio/Aiuto + foglio «Garage e impostazioni». I vecchi URL `you`/`tu`/`account` aprono il foglio.
2. **Abbonamento** («Presto», nessun acquisto): rimosso, nessun codice StoreKit d'acquisto.
3. **Navigatore di GateLR** (guida interna con voce turn-by-turn, Guida 3D/Classica/Satellite/Notte, semafori, barra del viaggio, Ricentra, Panoramica, ricalcolo, Live Activity con manovre, «Fine»): solo dietro il flag di sviluppo.
4. **Veicolo sulla mappa** (Berlina/SUV/Utilitaria/Moto e colori) e **«Voce migliore»**: solo con il navigatore interno di sviluppo.
5. **Modalità prova** (ZTL finta, striscia viola, «Sposta la zona qui»): solo strumenti di sviluppo (Debug / GATELR_DEV_TOOLS).
6. **Presentazione con «Dove vai?»** (Firenze, Bologna, Milano, Roma, Siena) e pagina «Per avvisarti prima dei varchi / Consenti la posizione»: sostituite da «Con cosa entri?» (veicolo) e «Attiva gli avvisi» a pagina 2.
7. **Foglio «Novità»**: per la 2.0.2 non compare mai (note solo per 1.12/1.13/1.16).
8. **Interruttore della distanza degli avvisi** (200–1000 m) e avviso «Varco davanti» a 150 m: ora una distanza fissa 300 m / 600 m.
9. **Prima pagina vecchia**: riquadro «Sappilo prima del varco.», elenco città con «Tutto libero / N attive», «Prima volta con le ZTL?», «Nuovo alle ZTL?», riquadri «Leggi il cartello» affiancati, «Dove vai?» → Viaggio, «Nessun campo di ricerca»; ora c'è la ricerca e la fotocamera in alto.
10. **«Parti ora per …»** (avvio del guardiano dal prossimo viaggio in Adesso): ora «Il tuo prossimo viaggio» apre solo Viaggio.
11. **Interruttore «Adesso / All'arrivo»** in Viaggio: sostituito dai chip ora/veicolo condivisi.
12. **Titoli parlati** «Entra pure.», «Arrivo sereno.», «Entri a una condizione:», «Probabilmente sì./no.», pannello «FUORI ZTL» verde, «VARCO ATTIVO»: sostituiti dalle sette parole fisse e dal grigio «Fuori dalla ZTL».
13. **«Segnala un bug» in Impostazioni**: ora «Segnala un errore» in Aiuto e nel foglio Garage (apre lo stesso modulo, titolo ancora «Segnala un bug»).
14. **Consigli TipKit** in Viaggio («Tocca Avvia…») e in Account: rimasti solo «Il tuo hotel è dentro?» in Mappa (e quello della voce, solo dev).
15. **Widget del guardiano che avvia il guardiano**: apre solo la scheda Viaggio (come già nella 1.11, ma il testo «Avvia il guardiano» resta).
16. **«Lascia una recensione»** e richiesta di recensione dopo la prima risposta: il link è nascosto (APP_STORE_ID vuoto); la richiesta arriva solo dopo «Salva questo viaggio».
17. **Pastiglia «Il tuo hotel» che apre Viaggio con la tastiera** (1.12): ora la risposta compare in Adesso.

## 29. Incongruenze notate leggendo il codice (da segnalare, non corrette)
- Aiuto → «Ho preso una multa?» dice «Cosa fare, in 4 passi» ma la pagina ha 7 passi.
- Il dialogo del nuovo permesso dice «Finché è in attesa… «a una condizione»» anche per «Registrazione dall'hotel», che invece resta «Non entrare».
- Il modulo «Segnala un bug» elenca ancora le schede vecchie in «Dove» (Varco, Account) e si apre da voci che si chiamano «Segnala un errore».
- Il testo della zona di prova dice «spegnila in Tu → Impostazioni» (la scheda Tu non esiste più).
- Le note «Novità» parlano di «Tu → Cosa sono le ZTL → Rivedi la presentazione» (non visibili in 2.0.2).
- `gatelr://cartello` apre la pagina dentro Aiuto, non il foglio della fotocamera in alto (il commento nel codice parla di cartello «da ogni scheda»).
- In «In auto» → «Parcheggia fuori» → «Avvia» con il navigatore interno non fa nulla (onStart chiude solo il foglio); con un navigatore esterno avvia il guardiano.
