# GateLR – Roadmap 2 (dal 24 ottobre 2026, versione attuale 1.1.0)

Difficoltà: 🟢 facile · 🟡 media · 🔴 difficile. Tempi in **sessioni di lavoro** (una sessione ≈ quella di stanotte, qualche ora).
Ogni aggiornamento è piccolo, si compila e si prova da solo, con la sua checklist (in fondo).

---

## 1. Cosa dice la gente (ricerca online, 24 ottobre 2026)

| Problema | Cosa raccontano | Cosa ne ricaviamo |
|---|---|---|
| **La multa arriva mesi dopo** | 3–6 mesi, a volte fino a un anno (360 giorni per chi abita all'estero), spesso tramite il noleggio | Un **diario dei passaggi**: se sei passato da un varco attivo, lo sai subito, non dopo un anno |
| **Il noleggio aggiunge una commissione** | 30–90 € di «spese di gestione» addebitate sulla carta prima ancora della multa | Spiegarlo prima, e nella guida «Ho preso una multa?» |
| **Una multa per ogni passaggio** | Chi gira dentro cercando l'uscita prende più multe (caso di Imperia: 17 multe, 3.970 €) | Avviso forte «non girare dentro, esci dal punto più vicino»; a Firenze dal 2024 una al giorno per la stessa ZTL |
| **L'hotel «registra» ma la multa arriva lo stesso** | L'hotel deve mettere la targa nella «lista bianca» per **ogni giorno**, compreso quello di partenza; un permesso di parcheggio sul cruscotto non vale per la ZTL; spesso vale un solo ingresso e una sola uscita | Un **tracker dell'hotel**: date di arrivo e partenza, messaggio che chiede **conferma scritta**, promemoria |
| **Cartelli poco chiari e solo in italiano** | Pannelli piccoli, «Varco attivo» frainteso (ora per legge «ZTL attiva»), orari scritti in abbreviazioni | **Leggi il cartello**: inquadri il pannello degli orari e l'app te lo spiega nella tua lingua |
| **Google Maps e Waze non bastano** | Google non avvisa delle ZTL; Waze solo in poche città (Roma, Milano, Firenze) e non le evita in modo affidabile | Il ruolo di GateLR: **guardiano accanto al navigatore** che già usi |
| **Pagare dall'estero è complicato** | Bonifico con IBAN, carte straniere a volte rifiutate, sconto del 30% entro 5 giorni, scadenza 60 giorni, ricorso online | Guida passo-passo «Ho preso una multa?» |
| **Ticket da attivare (Milano Area C, Bologna)** | Ci si dimentica di attivarlo entro la scadenza | **Promemoria del ticket** con il link per pagare |
| **Poche città nelle app** | Le app concorrenti dicono 470+ città, ma con orari spesso presi da dati collaborativi | Più città, ma sempre con fonte ufficiale; dove non sappiamo, «non sicuro» (mai inventato) |
| **Ricorsi** | Multe annullate per pannello spento, cartello vecchio («Varco attivo»), segnaletica senza orari | Una checklist di ricorso con le prove da raccogliere |

Fonti: [Florence-trip (storia vera)](https://www.florence-trip.com/blog/ztl-florence-rental-car-story/), [TripAdvisor](https://www.tripadvisor.com/ShowTopic-g187768-i20-k14589312-Zona_Traffico_Limitato-Italy.html), [Rick Steves: lettera di multa](https://community.ricksteves.com/travel-forum/tourist-scams/italian-traffic-violation-you-get-in-the-mail-very-alarming), [Rick Steves: Waze e ZTL](https://community.ricksteves.com/travel-forum/italy/waze-in-italy-for-ztl), [Discover Tuscany: hotel](https://ask.discovertuscany.com/threads/ztl-exempt-for-tourists-living-in-a-hotel-within-the-ztl-zones.8706/), [Europe Consommateurs](https://www.europe-consommateurs.eu/en/topics/vehicles/fines/ztl-italy/), [The Local: pagare dall'estero](https://www.thelocal.it/20221012/explained-how-to-pay-italian-traffic-fines-from-abroad), [Autoblog: 17 multe](https://www.autoblog.it/post/multata-17-volte-per-passaggio-in-ztl-ma-il-varco-era-fuori-servizio), [Sicurauto: «ZTL attiva»](https://www.sicurauto.it/news/codice-della-strada/ztl-la-scritta-varco-attivo-diventa-illegittima-multe-annullabili/), [Waze Discuss](https://www.waze.com/discuss/t/ztl-istruzioni-per-luso/210601), [Tyremap](https://tyremap.com/guides/italy-ztl-fines/), [EVZ](https://www.evz.de/en/topics/transport/car/fines-abroad/ztl-italy/).
Sono in gran parte blog e forum: le cifre vanno prese come indicazioni, non come norme.

---

## 2. Le decisioni

1. **Prima pagina e Viaggio non si ripetono più.**
   - **Varco** diventa la pagina d'impatto: cosa fa l'app in un colpo d'occhio, la situazione intorno a te adesso, il pulsante «Parti» e le città con il loro stato.
   - **Viaggio** diventa «Pianifica»: è l'unico posto dove si cerca una destinazione o un hotel, si sceglie l'ora, si controlla il percorso e si prepara il messaggio all'hotel.
2. **Niente più finta navigazione dentro l'app.** Al suo posto la **modalità Guardiano**:
   - scegli la meta e GateLR apre Apple Maps, Google Maps o Waze;
   - intanto resta attivo in sottofondo e ti segue con il GPS;
   - mostra la distanza dalla prossima ZTL attiva nella **Dynamic Island** e sulla schermata di blocco;
   - avvisa con notifica e voce verso i 500 m.

### Cosa iOS permette davvero (onesto)
- **GPS in sottofondo:** GateLR può leggere la posizione mentre usi Google Maps, perché l'hai avviato tu. Si ferma da solo all'arrivo o dopo un periodo da fermo.
- **«Finestrella» sopra Google Maps:** iOS non permette di disegnare sopra le altre app. Si usano:
  - la **Dynamic Island** (iPhone 14 Pro e successivi), sempre visibile in alto anche dentro Google Maps;
  - la **schermata di blocco** (Live Activity);
  - le **notifiche a tendina** con la voce, che abbassa la musica e il navigatore.
- **Cosa non si può fare:**
  - non possiamo leggere il percorso scelto da Google Maps: calcoliamo il nostro verso la stessa meta e controlliamo la posizione reale;
  - in **CarPlay** le notifiche delle app non autorizzate da Apple non compaiono: serve l'autorizzazione CarPlay, che arriva con l'Apple Developer Program.

---

## 3. Gli aggiornamenti, piccoli e in ordine

| Ver. | Nome | Cosa | Diff. | Tempo |
|---|---|---|---|---|
| **1.2** | **Prima pagina** | Nuovo Varco d'impatto (stato intorno a te, «Parti», città, cos'è GateLR in 3 righe); la ricerca si sposta tutta in Viaggio («Pianifica»); scheda Viaggio riordinata; correzione del giro foto che a volte si blocca | 🟡 | 1 sessione |
| **1.3** | **Guardiano** | «Parti» → scegli il navigatore → GateLR in sottofondo; Dynamic Island / blocco schermo con «ZTL tra 400 m · attiva»; notifiche e voce; arresto automatico; tolta la guida interna | 🟡/🔴 | 1–2 sessioni |
| **1.4** | **Hotel sicuro** | Tracker della registrazione: arrivo, partenza, giorni coperti; messaggio che chiede conferma scritta di tutti i giorni; «il permesso di parcheggio non vale per la ZTL»; promemoria il giorno prima | 🟢 | 1 sessione |
| **1.5** | **Diario e multe** | Diario dei passaggi dai varchi attivi (solo sul telefono); guida «Ho preso una multa?»: tempi, commissione del noleggio, sconto 30% in 5 giorni, pagare dall'estero, ricorso e prove | 🟡 | 1 sessione |
| **1.6** | **Ticket** | Promemoria per attivare il ticket di Area C (entro mezzanotte del giorno dopo) e di Bologna (prima di entrare), con il link per pagare | 🟢 | ½ sessione |
| **1.7** | **Leggi il cartello** | Fotocamera con testo dal vivo: inquadri il pannello degli orari, l'app lo spiega in IT/EN/DE e dice se adesso è attiva | 🟡/🔴 | 1–2 sessioni |
| **1.8** | **Polish** | Grafica (tipografia, spazi, icone, animazioni, carattere della famiglia LR), velocità (mappa, avvio, liste), accessibilità, modalità scura, rifiniture di tutte le schede | 🟡 | 2 sessioni |
| **1.9** | **Più città** | Pisa, Siena, Lucca, Roma (geometrie dall'hub), Torino, Napoli: una città per volta, sempre dalle fonti ufficiali | 🔴 | ½–1 sessione per città, più la verifica |
| **2.0** | **Pubblicazione** | Apple Developer Program: account, abbonamento, CarPlay, TestFlight, App Store, sito | 🟡 | 2–3 sessioni + attese Apple |

Totale fino alla 1.8: **circa 8–10 sessioni**. Le città (1.9) dipendono da quante ne vogliamo.

### Da sistemare comunque (dentro gli aggiornamenti sopra)
- Il giro automatico delle foto a volte va in «tempo scaduto»: capire se è lentezza vera (1.2).
- La mappa con molti varchi (Milano) va alleggerita: si disegnano solo quelli vicini e senza testo per l'accessibilità (1.8).
- L'email di «Segnala un bug» è un segnaposto (2.0).
- Il repository privato blocca l'aggiornamento dei dati dalle città: si sposteranno su un repository pubblico solo-dati, o sul sito (2.0).

---

## 4. Checklist di prova per ogni aggiornamento

### 1.2 Prima pagina
- [ ] Varco: in 5 secondi si capisce cosa fa l'app (titolo, 3 righe, pulsante «Parti»)
- [ ] Con la posizione: «Sei a 1,2 km dalla ZTL … attiva fino alle 20:00» o «Nessuna ZTL vicina»
- [ ] Senza posizione: messaggio chiaro e pulsante per attivarla
- [ ] Città: Firenze, Bologna, Milano con lo stato adesso; tocco → panoramica delle zone
- [ ] Nessun campo di ricerca nel Varco; in Viaggio sì (destinazione o hotel)
- [ ] Viaggio: destinazione → risposta all'ora di arrivo → percorso → messaggio all'hotel
- [ ] Viaggi salvati funzionano come prima

### 1.3 Guardiano
- [ ] «Parti» → scelta del navigatore → si apre Google Maps / Apple Maps / Waze con la meta giusta
- [ ] Dynamic Island: «ZTL tra … m» che si aggiorna mentre guidi
- [ ] Schermata di blocco: la stessa informazione
- [ ] Verso i 500 m da una ZTL attiva: notifica e voce, anche con Google Maps davanti
- [ ] ZTL non attiva: nessun avviso (o solo informativo, senza voce)
- [ ] Arrivo o 15 minuti da fermo: il guardiano si ferma da solo
- [ ] «Ferma» dalla Live Activity o dall'app
- [ ] Batteria: un'ora di guida, consumo ragionevole

### 1.4 Hotel sicuro
- [ ] Hotel in ZTL → riquadro «Registrazione»: arrivo, partenza, giorni coperti
- [ ] Il messaggio chiede la conferma scritta per tutti i giorni, compresa la partenza
- [ ] Spunta «Confermato per iscritto»; promemoria il giorno prima dell'arrivo
- [ ] Hotel fuori ZTL: nessun riquadro

### 1.5 Diario e multe
- [ ] Passando (anche a piedi, per prova) vicino a un varco attivo → voce nel diario con ora e varco
- [ ] Diario solo sul telefono, cancellabile
- [ ] «Ho preso una multa?»: tempi, commissione del noleggio, sconto, pagamento dall'estero, ricorso

### 1.6 Ticket
- [ ] Area C attiva oggi → «Attiva il ticket entro mezzanotte di domani» con il link
- [ ] Notifica di promemoria alla sera

### 1.7 Leggi il cartello
- [ ] Inquadrando un pannello (anche una foto sullo schermo del Mac) l'app riconosce giorni e orari
- [ ] Spiegazione in italiano, inglese e tedesco; «adesso è attiva / non attiva»
- [ ] Se non capisce: lo dice, non inventa

### 1.8 Polish
- [ ] Ogni scheda: niente testi tagliati, spazi regolari, stessi colori e caratteri
- [ ] Modalità scura e testo grande (Impostazioni → Accessibilità) leggibili
- [ ] Mappa fluida anche su Milano; avvio dell'app sotto i 2 secondi
- [ ] VoiceOver legge le risposte in modo sensato
