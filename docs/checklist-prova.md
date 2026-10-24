# GateLR 1.9.0 – Checklist delle prove a mano

Spunta ogni riga. Se qualcosa non va: Account → «Segnala un bug» → Copia, e incollalo in chat.
Le prove marcate 🚗 vanno fatte in auto (meglio con un passeggero che tiene il telefono).

## ★ Prima pagina «Posso entrare?» e mappa scura del posto cercato
- [ ] Apri l'app senza aver cercato niente: in alto il riquadro **grigio** «Scopri se puoi entrare» con il campo «Hotel, indirizzo o piazza» (nessun «Sì, puoi entrare» a caso)
- [ ] Tocca il campo → si apre Viaggio con la tastiera già pronta; cerca «Palazzo Vecchio» → torna su Varco: riquadro **rosso** «Non entrare» (o **verde** «Puoi entrare» a ZTL spenta), zona, «Attiva fino alle …», pulsante **Dettagli** → Viaggio
- [ ] Un indirizzo fuori dalle ZTL (es. «Stazione Termini» a Roma) → verde, «Fuori dalla ZTL»; con una condizione o dubbio → ambra
- [ ] La **✕** del riquadro lo riporta grigio; le ricerche recenti compaiono come scorciatoie sotto il campo
- [ ] Con la posizione attiva: solo una riga piccola **«Vicino a te: Settore A · 400 m · non attiva adesso»**, tocco → scheda della zona
- [ ] Restano: guardiano attivo, prossimo viaggio con «Parti ora», città e zone, «Nuovo alle ZTL?» e «Leggi il cartello» (ora due riquadri affiancati)
- [ ] Mappa con un posto cercato (stile «Mappa»): **mappa scura e smorzata**, la zona che contiene il posto accesa in **rosso** (o verde se si entra) con bagliore, le altre appena accennate; sopra il posto il riquadro **«ZTL ATTIVA · NON ENTRARE»** / «FUORI DALLA ZTL» / «ZTL SPENTA · PUOI ENTRARE» con la linea sottile fino al punto
- [ ] Con un percorso calcolato la linea è **bianca**; nella scheda in basso i riquadri sottili «Orari ZTL» e «Da te»
- [ ] ✕ nella ricerca della mappa → torna la mappa normale (chiara in modalità chiara); Ibrida e Satellite non cambiano

## ★ Novità 1.9 «Navigatore» (prima queste)
- [ ] Mappa → cerca un hotel → nella scheda **«Avvia»** parte subito (navigatore preferito + guardiano), senza passare da Viaggio; «Dettagli del viaggio» porta a Viaggio
- [ ] Senza navigatore preferito: scegli Google Maps dal menu → domanda **«Usare sempre Google Maps?»** → «Sempre» lo salva (Account → Navigatore preferito)
- [ ] Navigatore di GateLR 🚗: pulsante **Vista** in basso → Guida 3D, Classica, Satellite, Notte
- [ ] **Guida 3D** (stile nuovo): percorso verde smeraldo luminoso, camera bassa dietro l'auto, pannello manovra scuro, velocità nel cerchio bianco in alto a sinistra
- [ ] **Semafori** disegnati lungo la strada davanti (Firenze, Bologna, Milano) e il cartellino «semaforo tra … m»
- [ ] **Barra del viaggio** a destra: verde la strada, rossa/gialla dove entri in una ZTL attiva, l'auto che sale
- [ ] Percorso: fascia blu larga con bordo scuro; la **freccia della prossima svolta** disegnata sulla strada; nelle rotonde il blu non diventa grigio prima del tempo
- [ ] Zoom con due dita o inclinazione → compare **«Ricentra»**
- [ ] Account → **Veicolo sulla mappa**: Berlina / SUV / Utilitaria / Moto, scegli il colore → in guida il modellino gira con l'auto
- [ ] Voce: le vie si capiscono (es. «Via Gramsci»). Se no: Account → «Voce migliore» → scarica Alice Premium → riprova
- [ ] Guardiano con **Apple Maps**: nell'isola resta un **pallino con lo scudo** verde (nessuna ZTL attiva davanti) / giallo / rosso; con Google Maps: scudo + distanza
- [ ] **Nuove città (bozza, perimetri da OpenStreetMap)**: in Varco compaiono **Roma** e **Siena**
  - [ ] Viaggio → «Pantheon» → Roma Centro: lun–ven 6:30–18 «Non entrare», sabato dalle 14; di notte ven/sab 23–3
  - [ ] «Piazza di Spagna» → Tridente; «Santa Maria in Trastevere» → Trastevere
  - [ ] «Stazione Termini» → fuori dalla ZTL
  - [ ] «Piazza del Campo» → Siena: sempre «Non entrare» (ZTL 24 ore su 24)
  - [ ] Mappa: i confini di Roma e Siena sono credibili (controlla con i cartelli quando sei lì)
- [ ] **Firenze · Scudo Verde** (zona a basse emissioni, multe dal 1/7/2025): Viaggio → «Stazione Campo di Marte» → zona verde «Puoi entrare» per un'auto recente; Garage → auto diesel Euro 1 → «Non entrare»; mappa: area verde grande intorno alla città con i 73 varchi
- [ ] **Siri**: «Ehi Siri, ZTL vicine con GateLR» (anche a telefono bloccato) → «Settore A è a 400 metri: Non entrare. I varchi si spengono oggi alle 20:00»

## 0. Installazione (Windows con Sideloadly, oppure Mac: vedi `docs/windows.md`)
- [ ] **Windows**: Actions → «Compila GateLR» → Artifacts → GateLR-iPhone-ipa → Sideloadly → Start
- [ ] **Mac**: Terminale: `osascript -e 'quit app "Xcode"'` poi `cd ~/Developer/GateLR && git pull && zsh "Installa su iPhone.command"`
- [ ] Lo script scrive «Versione: 1.9.0»
- [ ] Xcode: Team su **GateLR** e **GateLRWidget**, iPhone scelto in alto, ▶︎
- [ ] Account → in fondo **Versione 1.9.0**
- [ ] Le auto, i permessi e i viaggi di prima ci sono ancora

## 1. Prima pagina (Varco)
- [ ] In 5 secondi si capisce cosa fa l'app (riquadro blu «Sappilo prima del varco.»)
- [ ] Con la posizione attiva: riquadro colorato con la ZTL vicino a te e la risposta («Non entrare», «Puoi entrare»…); tocco → scheda della zona
- [ ] Senza posizione: «Consenti l'accesso alla posizione…»
- [ ] «Dove vai?» porta a Viaggio
- [ ] Città: Firenze, Bologna, Milano con «Tutto libero» o «N attive»; tocco cambia l'elenco delle zone sotto
- [ ] Tocco su una zona → scheda con orari e fonti
- [ ] «Prima volta con le ZTL?» apre la guida; «Leggi il cartello» apre la lettura del pannello
- [ ] Con un viaggio salvato futuro: riquadro «Il tuo prossimo viaggio»
- [ ] Nessun campo di ricerca nella prima pagina

## 2. Viaggio (l'unica ricerca)
- [ ] Senza destinazione: «Dove vai?» con la spiegazione, viaggi salvati sotto
- [ ] Cerca «Palazzo Vecchio» → risposta per quel punto (Settore A)
- [ ] «Adesso / All'arrivo»: con l'arrivo scelto la risposta cambia
- [ ] Cerca «Duomo di Milano» → Area C con il riquadro **Ticket** (prezzo, «Attivalo entro…», «Paga il ticket», «Ricordamelo»)
- [ ] Cerca «Piazza Maggiore Bologna» → riquadro rosso **Area pedonale** e risposta «No»
- [ ] Cerca un hotel dentro la ZTL di Firenze → riquadro **Registrazione della targa**:
  - [ ] arrivo e partenza; i giorni elencati comprendono quello di partenza
  - [ ] «Da chiedere / Chiesta / Confermato»; con «Confermato» compare nel Garage un permesso e la risposta diventa «Sì»
  - [ ] Con il permesso confermato a Firenze, cerca «Duomo di Milano» o «Castello Sforzesco»: la risposta **non** diventa «Sì» (il permesso vale solo nella sua città)
  - [ ] messaggio per l'hotel con la data di partenza e la richiesta di conferma scritta (IT/EN/DE)
- [ ] «Salva questo viaggio» → compare nei viaggi salvati; tocco lo riapre; tieni premuto → Elimina
- [ ] Fuori ZTL (es. «Stazione Campo di Marte Firenze») → nessun Settore, ma dentro lo **Scudo Verde** (verde, puoi entrare con un'auto recente)

## 3. Percorso e partenza
- [ ] «Controlla il percorso» → tempo, km, ZTL attraversate con l'ora e la risposta
- [ ] «Avvia» apre un menu: Apple Maps / Google Maps / Waze (con avvisi GateLR) e «Navigatore di GateLR»

## 3b. Comodità
- [ ] Account → Impostazioni → **Navigatore preferito** (es. Google Maps) → in Viaggio il pulsante diventa «Avvia · Google Maps» e parte con un tocco; «…» accanto per gli altri
- [ ] Viaggio senza destinazione: **Recenti** con gli ultimi posti cercati
- [ ] Auto «a noleggio» senza targa: nella registrazione dell'hotel compare il promemoria per la targa al ritiro
- [ ] Viaggio salvato per oggi: nella prima pagina «Parti ora per …» avvia il guardiano
- [ ] Richieste di permesso di iOS (posizione, fotocamera) in italiano

## 4. Guardiano 🚗
- [ ] «Avvia» → Google Maps (o Apple Maps / Waze) si apre con la meta giusta
- [ ] Dynamic Island (iPhone 14 Pro e successivi) e schermata di blocco: ZTL più vicina con la distanza, o «Nessuna ZTL attiva davanti»
- [ ] Verso i 500 m da una ZTL attiva: notifica a tendina e voce, sopra Google Maps
- [ ] Verso i 150 m: «Varco davanti»
- [ ] Riaprendo GateLR: banner «Guardiano attivo» nella prima pagina con «Ferma»
- [ ] Arrivati a destinazione si ferma da solo (notifica «Sei arrivato»)
- [ ] Da fermo per 15 minuti si ferma da solo
- [ ] Entrando in una ZTL dove non potevi: «Sei dentro … Esci dal punto più vicino e non girare dentro» (solo dove la risposta è «No», non nelle zone verdi o a pagamento)

## 5. Navigatore di GateLR 🚗
- [ ] La mappa segue l'auto, girata nella direzione di marcia, inclinata
- [ ] Freccia dell'auto; percorso già fatto in grigio, quello da fare in blu
- [ ] In alto: distanza e manovra, sotto «Poi …» quando due svolte sono vicine
- [ ] Barra della prossima ZTL sempre visibile (colore della risposta) o «Nessuna ZTL lungo la strada»
- [ ] Voce: «Tra 300 metri, svolta a destra…»; altoparlante per spegnerla
- [ ] Spostando la mappa col dito compare «Ricentra»; «Panoramica» mostra tutto il percorso
- [ ] Velocità in km/h; ora d'arrivo, tempo e km che mancano
- [ ] Uscendo dal percorso: «Ricalcolo il percorso»
- [ ] Live Activity con la manovra; «Fine» chiude tutto

## 6. Mappa
- [ ] Zone verdi (Area B) ben visibili, piene e con il bordo spesso
- [ ] Niente scritte grandi: un cerchio piccolo colorato con la lettera per zona
- [ ] Pulsante (i): legenda con i colori
- [ ] Ricerca in alto: cerca il tuo hotel → spillo **verde** (entri), **rosso** (no) o **giallo** (con condizioni) e scheda in basso con la risposta
- [ ] X nella ricerca: torna alla zona
- [ ] Stili (Mappa, Ibrida, Satellite), edifici 3D, vista strada
- [ ] Da vicino: aree pedonali e telecamere delle corsie bus
- [ ] Fluida anche su Milano zoomando e spostando

## 7. Garage
- [ ] Marca, modello, anno → classe Euro proposta; consigli per l'auto (diesel Euro 5: Area B e C in rosso)
- [ ] Permesso creato dalla registrazione dell'hotel presente

## 8. Account
- [ ] Multe → **Diario dei passaggi** (vuoto o con le voci; condividi; cancella)
- [ ] Multe → **Ho preso una multa?**: 7 punti leggibili
- [ ] Impara → «Cos'è una ZTL?» e «Leggi il cartello»
- [ ] Avvisi: interruttore, distanza, «Prova un avviso»
- [ ] Regole e mappe → «Controlla aggiornamenti»
- [ ] «Segnala un bug»

## 9. Leggi il cartello
- [ ] Fotocamera: inquadra un pannello (anche una foto sul Mac) → «Usa questo testo»
- [ ] «Scegli una foto» con una foto di un pannello
- [ ] Scrivi «7.30-20.00 feriali» → spiegazione e «Attiva adesso / Non attiva adesso»
- [ ] Testo senza orari → «Non trovo giorni e orari»

## 10. Ticket e promemoria
- [ ] «Ricordamelo» → notifica all'ora giusta (Area C: sera dell'ingresso; Bologna: un'ora prima)
- [ ] Hotel: notifica il giorno prima dell'arrivo alle 18 se non confermato

## 11. Lingue, scuro, widget
- [ ] iPhone in italiano: nessuna parola inglese
- [ ] Modalità scura: tutto leggibile
- [ ] Widget: si sceglie la zona (tieni premuto → Modifica widget)
