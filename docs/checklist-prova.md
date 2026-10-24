# GateLR 1.8 – Checklist delle prove a mano

Spunta ogni riga. Se qualcosa non va: Account → «Segnala un bug» → Copia, e incollalo in chat.
Le prove marcate 🚗 vanno fatte in auto (meglio con un passeggero che tiene il telefono).

## 0. Installazione (Mac)
- [ ] Terminale: `osascript -e 'quit app "Xcode"'` poi `cd ~/Developer/GateLR && git pull && zsh "Installa su iPhone.command"`
- [ ] Lo script scrive «Versione: 1.8.0»
- [ ] Xcode: Team su **GateLR** e **GateLRWidget**, iPhone scelto in alto, ▶︎
- [ ] Account → in fondo **Versione 1.8.0**
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
  - [ ] messaggio per l'hotel con la data di partenza e la richiesta di conferma scritta (IT/EN/DE)
- [ ] «Salva questo viaggio» → compare nei viaggi salvati; tocco lo riapre; tieni premuto → Elimina
- [ ] Fuori ZTL (es. «Stazione Campo di Marte Firenze») → «Fuori dalla ZTL» con la distanza

## 3. Percorso e partenza
- [ ] «Controlla il percorso» → tempo, km, ZTL attraversate con l'ora e la risposta
- [ ] «Avvia» apre un menu: Apple Maps / Google Maps / Waze (con avvisi GateLR) e «Navigatore di GateLR»

## 4. Guardiano 🚗
- [ ] «Avvia» → Google Maps (o Apple Maps / Waze) si apre con la meta giusta
- [ ] Dynamic Island (iPhone 14 Pro e successivi) e schermata di blocco: ZTL più vicina con la distanza, o «Nessuna ZTL attiva davanti»
- [ ] Verso i 500 m da una ZTL attiva: notifica a tendina e voce, sopra Google Maps
- [ ] Verso i 150 m: «Varco davanti»
- [ ] Riaprendo GateLR: banner «Guardiano attivo» nella prima pagina con «Ferma»
- [ ] Arrivati a destinazione si ferma da solo (notifica «Sei arrivato»)
- [ ] Da fermo per 15 minuti si ferma da solo

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
