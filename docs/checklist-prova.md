# GateLR – Checklist delle prove a mano

Spunta ogni riga. Se qualcosa non va: Account → «Segnala un bug» → Copia, e incollalo in chat.

## 0. Installazione (Mac)
- [ ] `cd ~/Developer/GateLR && git pull` (solo questa volta: da ora lo fa lo script da solo)
- [ ] `zsh "Installa su iPhone.command"` (chiude Xcode da solo e mostra «Versione: 1.1.0»), poi in Xcode: Team impostato su **GateLR** e **GateLRWidget**
- [ ] iPhone collegato e scelto come destinazione, ▶︎ → l'app si apre senza errori
- [ ] Al primo avvio dopo l'aggiornamento: le auto, i permessi e il nome dell'hotel di prima ci sono ancora

## 1. Primo avvio e permessi
- [ ] (Solo se reinstalli da zero) tre pagine di presentazione, «Salta» e «Inizia» funzionano
- [ ] La richiesta della posizione e delle notifiche arriva **dopo** la presentazione

## 2. Varco (prima scheda)
- [ ] La scheda si chiama «Varco» (in inglese «Gate», in tedesco «Einfahrt»)
- [ ] Menu della città: Firenze, Bologna, Milano; cambiando città cambia la panoramica
- [ ] Senza indirizzo: elenco delle zone con colore (rosso/giallo/verde) e risposta; tocco → scheda della zona
- [ ] Cerca «Palazzo Vecchio» → suggerimenti mentre scrivi → tocco → risposta per quel punto (Settore A)
- [ ] Cerca un indirizzo fuori ZTL (es. «Stazione Campo di Marte Firenze») → «Fuori dalla ZTL» con la distanza
- [ ] Icona posizione nella barra di ricerca → «La mia posizione»
- [ ] «Adesso» / «All'arrivo»: con «All'arrivo» si sceglie data e ora e la risposta cambia
- [ ] Milano, «Duomo di Milano» → Area C, e sotto «Anche dentro: Area B»
- [ ] La X svuota la ricerca e torna alla panoramica

## 3. Percorso (dalla pagina Varco, con un indirizzo scelto)
- [ ] «Controlla il percorso» → tempo, km, ora di arrivo
- [ ] Elenco delle ZTL attraversate con l'ora in cui ci passi e la risposta
- [ ] Destinazione in ZTL attiva → «Parcheggia a …» con minuti a piedi, pulsante «Vai al parcheggio»
- [ ] «Naviga» → Apple Maps, Google Maps e Waze si aprono con la meta giusta
- [ ] Icona mappa → la scheda Mappa mostra il percorso in blu e la P del parcheggio

## 3b. Guida dentro l'app (meglio in auto, con un passeggero)
- [ ] Dal percorso, «Avvia» → schermata di guida: freccia, distanza, istruzione, ora di arrivo
- [ ] La voce legge le istruzioni («Tra 300 metri, svolta a destra…»); il pulsante altoparlante la spegne
- [ ] Uscendo dal percorso: «Ricalcolo il percorso» e nuova strada
- [ ] Avvicinandoti a una ZTL attiva: banner rosso e avviso a voce verso i 500 m
- [ ] Vicino a una telecamera di corsia bus: avviso a voce
- [ ] Schermata di blocco e Dynamic Island mostrano manovra, distanza e avviso
- [ ] Con un'altra app aperta o lo schermo spento la voce continua
- [ ] All'arrivo: «Sei arrivato»; «Fine» chiude la guida e la Live Activity

## 4. Mappa
- [ ] Zone colorate: rosso «Accesso vietato» (Firenze, zona T), giallo «Pass necessario» (Bologna ZTL, Area C), verde «Zona verde» (Area B)
- [ ] Da lontano: scritte grandi; avvicinandosi svaniscono e compaiono le lettere dei settori
- [ ] Telecamere rosse (accese) o verdi (spente), ognuna con lo stato della sua zona
- [ ] Pulsante degli stili: Mappa, Ibrida, Satellite; «Edifici in 3D»; «Vista strada» (Look Around) a Firenze o Milano
- [ ] Tocco su una zona → la scheda in basso cambia zona
- [ ] «Parcheggia fuori» → P blu fuori dalle ZTL; tocco su una P → indicazioni
- [ ] La mappa resta fluida muovendola e zoomando (soprattutto su Milano)
- [ ] Da vicino a Bologna o Milano: aree pedonali in rosso chiaro e telecamere delle corsie bus (icona bus blu)
- [ ] Varco: cerca «Piazza Maggiore Bologna» → riquadro rosso «Area pedonale»

## 5. Viaggio
- [ ] Cerca «Hotel Brunelleschi Firenze» → l'app dice da sola «Dentro la ZTL · Settore …»
- [ ] Scelte rapide (Stasera/Domani/Sabato/Domenica) in italiano; la risposta cambia
- [ ] Messaggio per l'hotel in IT/EN/DE con nome dell'hotel e targa; «Invia all'hotel» e «Copia»
- [ ] «Salva questo viaggio» → compare in «Viaggi salvati»; tocco lo ricarica; tieni premuto → Elimina
- [ ] Hotel fuori ZTL → «Il tuo hotel è fuori dalla ZTL»

## 6. Garage
- [ ] «+» → Marca (elenco), Modello (elenco), Anno → la classe Euro si propone da sola
- [ ] Salva senza nome → il nome diventa «Marca Modello»
- [ ] «Usa» cambia l'auto in uso (senza aprire la modifica)
- [ ] Consigli per l'auto: con un diesel Euro 5, Area B e Area C in rosso; con un'elettrica tutto verde
- [ ] Varco a Milano con il diesel Euro 5 → «No» in Area B anche se è una zona verde
- [ ] Permessi: aggiungi, «In attesa» ↔ «Confermato», elimina

## 7. Account
- [ ] «Cos'è una ZTL?» → cartello, pannello «ZTL ATTIVA / NON ATTIVA», multe
- [ ] Avvisi: interruttore, distanza; «Prova un avviso» → notifica dopo 3 secondi
- [ ] Lingua → apre le Impostazioni dell'iPhone
- [ ] Città offline: tre città «bozza»
- [ ] «Segnala un bug» → testo, dove, info tecniche; Invia / Copia
- [ ] Versione **1.1.0** (se vedi 0.3.0 l'aggiornamento non è arrivato)
- [ ] Regole e mappe → «Controlla aggiornamenti» → «Aggiornati»
- [ ] «Cos'è una ZTL?»: anche orari sotto il cartello, aree pedonali, corsie bus, zone a basse emissioni

## 8. Lingue
- [ ] iPhone in italiano: nessuna parola inglese rimasta (schede, risposte, schede delle zone, fonti, widget)
- [ ] (Facoltativo) iPhone in tedesco e in inglese

## 9. Widget e notifiche
- [ ] Aggiungi il widget GateLR alla Home → mostra Firenze B
- [ ] Tieni premuto → Modifica widget → scegli un'altra zona (es. Area C) → cambia
- [ ] Widget sulla schermata di blocco (rettangolare e circolare)
- [ ] Per strada (facoltativo): avvicinandoti a un varco attivo arriva l'avviso, anche ad app chiusa

## 10. Modalità scura
- [ ] Impostazioni → Schermo → Scuro: tutte le schede leggibili, colori corretti
