# GateLR 1.13.1 – Checklist delle prove a mano

Spunta ogni riga. Se qualcosa non va: Tu → Impostazioni → «Segnala un bug» → Copia, e incollalo in chat.
Le prove marcate 🚗 vanno fatte in auto (meglio con un passeggero che tiene il telefono).

## ★ Il posto come titolo della risposta (1.17.3)
- [ ] Cerca «Hotel Cavour»: in cima alla scheda il nome grande, nel carattere dei titoli, con ▾; sotto, piccolo, «Firenze · Settore A»; poi il pannello più piccolo, «Non entrare.» e i pulsanti
- [ ] Un nome lungo va su due righe senza tagliarsi; il ▾ apre ancora gli hotel salvati e i posti recenti
- [ ] Dentro una ZTL senza cercare nulla: il titolo è «La tua posizione» con sotto città e zona
- [ ] iPhone Pro Max: «Guarda la mappa», «Perché?» e «Dettagli del viaggio» si vedono senza scorrere
- [ ] VoiceOver: il titolo si legge come intestazione, con città e zona

## ★ Presentazione a tutto schermo e striscia di Varco (1.17.2)
- [ ] Presentazione con Mapbox su un iPhone con Dynamic Island: la mappa arriva fino al bordo in basso; sotto il blu notte del pannello non resta nessuna striscia di mappa (né sopra la barra di Home né sotto)
- [ ] In alto il blu notte copre la Dynamic Island e l'ora; logo Mapbox e «ⓘ» visibili sopra il pannello in basso, dentro lo schermo, e la «ⓘ» si tocca
- [ ] Lo stesso con la mappa di Apple (avvio con -intro2MapKit) e con il disegno senza rete (modalità aereo o -intro2Fallback)
- [ ] Varco senza un posto cercato: al centro della zona il cartello della ZTL (cerchio rosso su bianco, su un palo) con il nome corto («Centro»), non più il pallino rosso/bianco
- [ ] Con il permesso della posizione e a meno di 5 km dalla zona (es. 550 m fuori dal Centro di San Giovanni Valdarno): il pallino blu di iOS dove sei, e la ripresa tiene dentro sia te sia la zona, così si vede che sei fuori
- [ ] Oltre 5 km (o senza permesso): solo la zona, come prima, nessun pallino blu fuori posto
- [ ] Cerca un hotel: sulla striscia lo spillo della destinazione con il nome dell'hotel, del colore della risposta
- [ ] Lo stesso senza Mapbox (mappa di Apple): cartello, spillo, pallino blu e ripresa uguali
- [ ] VoiceOver sulla striscia: «Guarda la mappa», poi «Zona ZTL: Centro» (o «Destinazione: …») e «La tua posizione» quando sei nella ripresa

## ★ «Entri a una condizione:», colori delle zone e limiti delle moto (1.17.2)
- [ ] Varco con una risposta «a una condizione» (es. una moto in Area B a Milano, o un hotel che può registrare la targa): il titolo è «Entri a una condizione:» e sotto, subito, la condizione in testo normale; «Non entrare.» ed «Entra pure.» come prima
- [ ] Una risposta «non sicuro» (es. un festivo incerto): sotto il titolo il motivo
- [ ] iPhone Pro Max: con una risposta a una condizione «Guarda la mappa», «Perché?» e «Dettagli del viaggio» si vedono senza scorrere
- [ ] Mappa: cerca Hotel Helvetia & Bristol con un diesel Euro 5 in un giorno feriale: il Settore A è rosso, lo Scudo Verde intorno resta VERDE (prima tutta Firenze era rossa)
- [ ] La striscia in cima a Varco: anche lì ogni zona ha il suo colore (Settore A rosso, Scudo Verde verde)
- [ ] Garage → nuova moto: sotto «Euro» compaiono «Due ruote» (ciclomotore / motociclo) e «Motore» (4 tempi / 2 tempi), con la spiegazione; di serie motociclo e 4 tempi
- [ ] Scudo Verde con una moto Euro 5: «Entra pure.»; con un ciclomotore 2 tempi Euro 1: «Non entrare.»; dal 1° dicembre 2026 (scegli la data) una moto Euro 1 4 tempi: «Non entrare.»
- [ ] Milano Area B con una moto: ancora «Entri a una condizione:» con sotto «Qui le moto hanno limiti Euro loro…»

## ★ GateLR 2.0: tre schede (1.16.0)
- [ ] In basso solo tre schede: «Varco», «Mappa» al centro con il simbolo più grande, «Tu»; VoiceOver legge i tre nomi
- [ ] Varco su fondo blu notte anche con l'iPhone in modalità chiara; la barra delle schede resta quella di iOS
- [ ] In cima a Varco la striscia di mappa dal vivo (con Mapbox: città 3D che gira piano; senza rete o token: mappa di Apple scura) con logo e «i» di Mapbox visibili e toccabili
- [ ] Un tocco sulla striscia o su «Guarda la mappa» → scheda Mappa sulla zona della risposta (es. Palazzo Vecchio → Settore A di Firenze)
- [ ] Cerca «Palazzo Vecchio» dalla ricerca di Varco: compare il pannello del varco, la frase grande («Non entrare.» di giorno feriale, «Entra pure.» di notte), l'ora del cambio, la zona
- [ ] Un posto fuori dalle ZTL (es. Parcheggio Parterre) → «Arrivo sereno.» e pannello «FUORI ZTL» verde
- [ ] Il pannello del varco si accende sempre per intero, anche cercando subito un altro posto (1.16.1)
- [ ] Cambia «Adesso ▾» (es. Stasera 21:00) e il veicolo: la risposta e il pannello cambiano (il pannello gira con un colpo di vibrazione)
- [ ] Rosso o ambra: «Parcheggia fuori e cammina» apre i parcheggi; «Perché?» apre la scheda della zona; «Dettagli del viaggio» apre Tu → Viaggio e hotel
- [ ] Senza posto cercato ma dentro una ZTL con la posizione attiva: la risposta è per «La mia posizione»
- [ ] Mappa a tutto schermo: sotto i chip la legenda corta con i quattro colori (un tocco apre quella intera), ricerca, «Naviga» e «Parcheggia fuori e cammina» sulla scheda del posto; la guida con GateLR funziona come prima
- [ ] Tu: Garage, Viaggio e hotel, Multe e passaggi (Diario dei passaggi, Ho preso una multa?, Fotografa il verbale), Cosa sono le ZTL (Impara, Leggi il cartello, Rivedi la presentazione), Impostazioni, Abbonamento (solo «Presto», nessun acquisto)
- [ ] Garage → «+»: subito sotto la targa la riga «Cerca dalla targa» con il lucchetto, grigia, con «In arrivo» (1.16.1); toccandolo non succede niente; «Fotografa il libretto» e «Auto a noleggio» come prima
- [ ] Primo avvio (cancella e reinstalla): parte la presentazione 2.0, una volta; alla fine (o «Più tardi») la richiesta della posizione di iOS; riaprendo l'app non ricompare
- [ ] Tu → Cosa sono le ZTL → «Rivedi la presentazione»: la presentazione riparte e si chiude tornando a Tu
- [ ] Widget: un tocco apre Varco (o Tu → Viaggio e hotel per il widget del viaggio); gatelr://map dal sito apre la Mappa
- [ ] Aggiornando da una versione precedente: «Novità della 1.16.0» una volta, con le tre schede
- [ ] Testo più grande (Impostazioni → Accessibilità → Testo più grande, quasi al massimo): in Varco e Tu le scritte crescono e niente si sovrappone

## ★ Ora, veicolo, legenda e parcheggi fuori dalla ZTL
- [ ] Prima pagina, Mappa e Viaggio: sotto il titolo i due chip «Adesso ▾» e «<auto> · benzina Euro 6 ▾»; cambiando uno dei due in una pagina cambia anche nelle altre
- [ ] «Adesso ▾» → «Stasera 20:00» (solo prima delle 20), «Domani 09:00», «Scegli giorno e ora…» (calendario in ora italiana, «Adesso» lo azzera); il chip diventa blu con l'ora scelta
- [ ] Con un'ora scelta: riquadro della prima pagina («Per stasera 20:00»), colori delle zone in Mappa, scheda del posto e risposta in Viaggio cambiano insieme (es. Firenze settore A: 18:00 rosso, 21:00 verde)
- [ ] Chiudi l'app dal multitasking e riaprila: l'ora torna «Adesso», il veicolo scelto resta
- [ ] Chip del veicolo → un altro veicolo del Garage: la risposta cambia (es. Milano Area B con un diesel Euro 5); «Aggiungi un veicolo» → salva → diventa quello in uso
- [ ] Mappa senza posto cercato: zone rosse «Non puoi entrare» (bordo pieno, ✕), ambra «Puoi entrare se…» (tratteggio, !), grigio-blu «Da verificare» (puntini, ?), verdi «Puoi entrare» (✓); il simbolo è anche sulla lettera della zona
- [ ] Pulsante «i» della Mappa: la legenda spiega le quattro risposte e dice per quale ora e veicolo valgono
- [ ] Un giorno festivo non confermato (es. 8 dicembre con l'ora scelta) → zone «Da verificare»
- [ ] Posto rosso o ambra (es. Duomo di Firenze alle 18 di un giorno feriale, Duomo di Milano in Area C): in Viaggio il riquadro «Parcheggia fuori e cammina» con 3 parcheggi, minuti a piedi, prezzo, «Aperto adesso» / orari, posti; in Mappa il pulsante «Parcheggia fuori e cammina» apre lo stesso elenco e mette le P sulla mappa; nella prima pagina il pulsante porta a Viaggio
- [ ] I parcheggi proposti sono FUORI dalla ZTL attiva all'ora scelta (controlla sulla mappa); con la posizione attiva compare «Strada fin lì senza ZTL attive»
- [ ] Tocca un parcheggio → «Avvia» porta lì (navigatore preferito o GateLR) e sotto c'è «Poi N min a piedi fino a …»
- [ ] 🚗 Arrivato al parcheggio: prezzo e orari corrispondono al cartello (se no, segnalalo: i dati sono di OpenStreetMap)
- [ ] Modalità aereo con una città mai aperta prima: i parcheggi arrivano dai dati dentro l'app (nessuna attesa)

## ★ Fotocamera (1.13.1)
- [ ] «Leggi il cartello» → «Usa la fotocamera»: la prima volta compare la richiesta di iOS dentro l'app
- [ ] Se la fotocamera era negata: riquadro «Consenti la fotocamera» → «Apri Impostazioni» apre la pagina di GateLR → attiva Fotocamera → torna nell'app: la fotocamera si apre da sola

## ★ UX (1.13.0)
- [ ] Prima pagina con un viaggio salvato: pastiglia azzurra «Il tuo hotel · …» → un tocco e il riquadro diventa verde/rosso/ambra, senza cambiare pagina
- [ ] Pastiglie dei posti recenti: stessa cosa, la risposta nel riquadro; la X la toglie
- [ ] Primo avvio (cancella l'app e reinstalla): tre pagine, poi «Dove vai?» con Firenze, Bologna, Milano, Roma, Siena; toccando una città la prima pagina si apre lì
- [ ] Poi «Per avvisarti prima dei varchi»: «Consenti la posizione» → solo allora la richiesta di iOS; «Non adesso» → nessuna richiesta
- [ ] «Salta» nelle prime pagine porta a «Dove vai?»; «Salta» lì porta alla posizione
- [ ] Consigli: in Viaggio dopo la prima risposta («Tocca Avvia…»), in Mappa sotto la ricerca («Cerca il tuo hotel…»), in Account solo se c'è solo la voce di base; si chiudono con la X e non tornano; non coprono pulsanti
- [ ] Pagine vuote: Garage senza veicoli («Aggiungi un veicolo»), Account → Diario dei passaggi vuoto («Prova un avviso»), Viaggio senza viaggi salvati («Cerca il tuo hotel»)
- [ ] iPhone con fuso di New York (Impostazioni → Generali → Data e ora): giorni del soggiorno, arrivo, orari del percorso e messaggio per l'hotel in ora italiana
- [ ] Account → modellino → VoiceOver legge i colori in italiano («Blu», «Argento»…)
- [ ] «Novità della 1.13.0» dopo l'aggiornamento, una volta

## ★ Velocità e iPad (1.12.0)
- [ ] Mappa su **Milano**: allarga fino a vedere tutta l’Area B e stringi fino al Duomo, più volte e in fretta → niente scatti; con tutta l’Area B sullo schermo i 188 varchi spariscono, avvicinandoti tornano
- [ ] Mappa su **Firenze** (Scudo Verde) e **Roma**: stesso zoom avanti e indietro, fluido; da vicino confini e lettere identici a prima (nessun angolo «tagliato»)
- [ ] Spostando la mappa da una città all'altra le zone compaiono appena ti fermi; tocco dentro una zona → la sceglie come prima
- [ ] Varco e Viaggio: la risposta per un indirizzo arriva subito; avvio dell'app senza schermo nero
- [ ] **iPad**: l'app si installa, gira in verticale e in orizzontale (anche Split View); Varco, Viaggio, Garage e Account con il contenuto al centro, non stirato; Mappa e navigatore a tutto schermo con barra e scheda centrate
- [ ] iPad: «Dettagli zona», «Novità», «Leggi il cartello», menu «Avvia» e «Usare sempre…?» si aprono e si chiudono senza problemi

## ★ Siri (1.11.0)
- [ ] «Ehi Siri, posso entrare a Firenze Settore A con GateLR» → «Firenze Settore A: Non entrare. I varchi si spengono oggi alle 20:00.» (o «Puoi entrare… si accendono…»)
- [ ] «Ehi Siri, posso entrare in Milano Area C con GateLR» e «Ehi Siri, GateLR Firenze»: se la città ha più zone Siri chiede quale
- [ ] «Ehi Siri, posso entrare con GateLR» → Siri chiede «Quale zona ZTL?», rispondi «Firenze Settore B»
- [ ] Subito dopo aver chiuso l'app dal multitasking: la risposta arriva lo stesso (le città si leggono in sottofondo)
- [ ] Comandi rapidi → GateLR → «Posso entrare?»: scegli zona e «Arrivo alle» domani alle 9 → la risposta è per domani
- [ ] Con il guardiano acceso: «Ehi Siri, ferma il guardiano di GateLR» → «Guardiano fermato.», sparisce dalla Dynamic Island; a guardiano spento → «Il guardiano non è attivo.»
- [ ] Widget «Guardiano» (Home, piccolo, e schermata di blocco): zona scelta, «ZTL attiva / non attiva», tocco → si apre Viaggio

## ★ Lingue (1.10.0)
- [ ] Impostazioni → GateLR → Lingua → **Français**: schede «Maintenant / Carte / Voyage / Garage», prima pagina «Puis-je entrer ?», nessun testo inglese rimasto
- [ ] Prova anche **Español**, **Nederlands**, **Polski** e **中文（简体）**: le date, «%» e i numeri nelle frasi sono giusti (es. «Fin dans 2 h 10 min»), niente «%@» o «%lld» a vista
- [ ] I cartelli restano in italiano tra virgolette («Varco attivo», «ZTL attiva»), «ZTL» non tradotto
- [ ] Il permesso della posizione e della fotocamera è chiesto nella lingua scelta; in Account la riga «Lingua» dice la lingua giusta
- [ ] Navigatore di GateLR in francese 🚗: la voce parla francese (non inglese)
- [ ] Siri in francese: «Dis Siri, ZTL près de moi avec GateLR»
- [ ] Novità 1.10.0 (dopo l'aggiornamento): sei righe tradotte, «Continuer» in fondo

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
- [ ] Lo script scrive «Versione: 1.10.0»
- [ ] Xcode: Team su **GateLR** e **GateLRWidget**, iPhone scelto in alto, ▶︎
- [ ] Account → in fondo **Versione 1.10.0** (build 21)
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

### 5b. Navigatore in macchina (1.14.1): fluido e ricalcolo
Da provare guidando davvero (con qualcuno che guarda il telefono, o col telefono sul supporto):
- [ ] L'auto scorre **liscia** sulla mappa come in Apple/Google Maps, senza salti una volta al secondo; la mappa gira morbida nelle curve
- [ ] Sulla strada l'auto è **sulla linea del percorso** (non a lato); nelle curve segue la curva
- [ ] Nessun rallentamento dopo 10–15 minuti di guida (pulsanti e mappa rispondono subito)
- [ ] Il percorso già fatto diventa grigio dietro l'auto, quello davanti resta colorato
- [ ] **Svolta sbagliata** apposta (anche in una via parallela vicina, in centro): entro 3–5 secondi la voce dice «Ricalcolo il percorso», in alto «Ricalcolo…», poi le istruzioni nuove da dove sei
- [ ] **Inversione a U** (o strada fatta al contrario): dopo pochi secondi ricalcola, e se possibile ti fa proseguire nel verso in cui vai
- [ ] Fermo al semaforo o in coda con il GPS che «balla»: **non** ricalcola
- [ ] Senza rete durante il ricalcolo: resta «Ricalcolo…» e riprova da solo (ogni ~8 secondi); tornando sul percorso di prima riprende quello
- [ ] Dopo il ricalcolo: barra della ZTL e avvisi a voce giusti per il percorso nuovo
- [ ] Ricentra, Panoramica e le quattro viste (Guida 3D, Classica, Satellite, Notte) come prima

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

## 12. Auto in 10 secondi e «Ho preso una multa?» (lettura di libretto e verbale)
- [ ] Garage → + : in cima «Auto in 10 secondi» con «Fotografa il libretto» e «Auto a noleggio: scegli il modello» (solo per un veicolo nuovo, non quando ne modifichi uno)
- [ ] «Fotografa il libretto» → «Usa la fotocamera»: foto del fronte del libretto vero → scheda «Controlla prima di salvare» con targa (A), marca (D.1), modello (D.3), anno (B), alimentazione (P.3), classe Euro (V.9)
- [ ] La nota sotto la classe Euro: «dal libretto: …» se ha letto il V.9; in giallo «proposta dall'anno» se il V.9 non c'è
- [ ] Correggi un campo, «Usa questi dati» → il modulo è compilato, il modello non si cancella e la classe Euro resta quella del libretto; «Salva»
- [ ] «Scegli una foto» con una foto del libretto (anche storta o con riflessi): legge qualcosa o dice di riprovare
- [ ] Se c'è, un libretto estero (tedesco, francese, spagnolo, olandese): targa come stampata, carburante giusto
- [ ] Fotocamera negata (Impostazioni → GateLR → Fotocamera spenta): riquadro «Consenti la fotocamera» con «Apri Impostazioni»; riaccesa e tornando nell'app la fotocamera si apre da sola
- [ ] «Auto a noleggio»: elenco (Panda, 500, Ypsilon, Polo, Golf, T-Roc, 208, 2008, Clio, Captur, Yaris, Yaris Cross, Renegade, Compass, C3, Corsa, Sandero…) → per i modelli con più versioni chiede il carburante → modulo con «Auto a noleggio» acceso, Euro 6
- [ ] Account → «Ho preso una multa?» → in cima «Fotografa il verbale»
- [ ] Foto di un verbale ZTL (o scrivi a mano: «Comune di Firenze … il giorno 12/03/2026 alle ore 10:32 … varco … Via Cavour … Notificato il 02/04/2026»)
- [ ] «Cosa abbiamo letto»: data e ora (in ora italiana), varco o via, città e zona proposte e modificabili, importo, articolo, numero, targa
- [ ] «Il varco era attivo?»: rosso «era attivo» / verde «non era attivo» / giallo nei festivi non confermati, con la nota che gli orari sono quelli di oggi e il link alla fonte del Comune
- [ ] «Scadenze» dalla data di notifica (modificabile): −30% entro 5 giorni, Giudice di Pace 30, pagamento e Prefetto 60; le date passate barrate in rosso; la nota 90/360 giorni (art. 201)
- [ ] «Copia un testo per il ricorso» → «Copiato»; incollato in Note: inizia con «BOZZA», ha i dati letti e i segnaposto tra [ ]
- [ ] «Riferimenti ufficiali»: i link a Normattiva si aprono
- [ ] In italiano e in modalità scura: niente inglese, tutto leggibile

## 13. Fonti non ufficiali (1.16.2)
Le zone con `"official": false` nella fonte (per ora Cagliari, Polignano a Mare, Ostuni, quando arrivano i dati).
- [ ] Varco: cerca un indirizzo dentro una di queste ZTL → riquadro ambra «Fonte non ufficiale: verifica sempre il cartello al varco» sopra il pannello, con «Dati da …»; il titolo è «Probabilmente no.» / «Probabilmente sì.», ma colore e pannello sono quelli di sempre
- [ ] Nella striscia di mappa in cima a Varco la stessa scritta, piccola
- [ ] In fondo a Varco l'avviso al posto di «Bozza: dalle fonti ufficiali…»
- [ ] «Perché?» → scheda della zona: in cima l'avviso, la frase «Queste regole vengono da un sito non ufficiale…» e il link al sito; «Cosa dice la fonte» al posto di «Le parole del Comune»; in fondo «Letto da una fonte non ufficiale il …»
- [ ] Mappa: il riquadro sul posto cercato ha «FONTE NON UFFICIALE» in ambra; la scheda in basso ha l'avviso e la pillola «Probabilmente no/sì»
- [ ] Viaggio e percorso: le pillole dicono «Probabilmente no/sì»
- [ ] Guardiano o navigatore verso una di queste zone: Live Activity e Dynamic Island con «… · Probabilmente no · Fonte non ufficiale»
- [ ] Widget della zona: «⚠ Fonte non ufficiale» al posto del tipo di zona; sulla schermata di blocco «⚠︎» davanti
- [ ] Una zona ufficiale (es. Firenze Settore A): nessun avviso, «Non entrare.» / «Entra pure.» come prima
- [ ] Sotto la risposta la riga della zona si legge bene: «ZTL · Settore A» (non più «Accesso vietato · Settore A» sotto «Entra pure.»)
- [ ] Un iPhone con la 1.16.1 o prima: dopo l'aggiornamento dei dati (Tu → Impostazioni → dati delle città) Cagliari, Polignano e Ostuni non compaiono

## 14. Presentazione 2.0 dopo l'aggiornamento (1.16.2)
- [ ] iPhone con una versione precedente già configurata: dopo l'aggiornamento alla 1.16.2 parte la presentazione 2.0, una volta
- [ ] Chiudi e riapri l'app: la presentazione non ricompare (e al posto suo nessun foglio «Novità» vuoto)
- [ ] Tu → Cosa sono le ZTL → «Rivedi la presentazione» funziona ancora

## 15. Prova sul campo: modalità prova, giri GPX, «Segnala un errore» (1.17.0)
Istruzioni passo passo in docs/prova-sul-campo.md.
- [ ] Appena installata: la modalità prova è spenta, nessuna striscia viola
- [ ] Tu → Impostazioni → «Modalità prova» accesa: dopo qualche secondo («Cerco le strade intorno a te…») compaiono 1–2 «Varco di prova» con il nome della via e il «Parcheggio di prova»
- [ ] La striscia viola «Modalità prova attiva» in cima a Varco, Mappa, Tu, nella scheda della zona e nella guida, con «Spegni» e il menu (Spegni/Accendi la ZTL di prova, «Sposta la zona qui»)
- [ ] Varco senza posto cercato, dentro la zona: «Non entrare.» per «La mia posizione», riga «ZTL · ZONA DI PROVA»; con «Spenta» diventa «Entra pure.»
- [ ] Mappa: il cerchio di circa 400 m con la scritta viola «ZONA DI PROVA · attiva/spenta», i varchi sulle strade vere (non in mezzo alle case)
- [ ] «Parcheggia fuori e cammina» propone il «Parcheggio di prova» fuori dalla zona; «Avvia» porta lì
- [ ] 🚗 A piedi o in auto verso un varco di prova con gli avvisi accesi: notifica «Varco ZTL a … m · ZTL attiva»
- [ ] 🚗 Navigazione di GateLR verso un punto dentro la zona: il percorso la segnala; la voce avvisa; Live Activity e Dynamic Island con «ZONA DI PROVA»
- [ ] Guardiano verso un punto dentro la zona: striscia rossa in Varco, Live Activity
- [ ] «Sposta la zona qui» da un altro posto: la zona si sposta, la vecchia sparisce
- [ ] «Spegni»: la striscia sparisce, la zona sparisce da mappa e risposte; chiudi e riapri l'app: resta spenta
- [ ] Con l'iPhone collegato al Mac: Xcode → Debug → Simulate Location elenca i sei giri; «firenze-viale-cavour-settore-a» passa dal varco di via Cavour e Varco/guida dicono «Non entrare» prima del varco (di giorno feriale)
- [ ] «Segnala un errore» in fondo alla risposta di Varco e nella scheda di ogni zona: Orari / Confini / Varco / Altro, nota, «Scatta una foto» o «Scegli una foto», «Allega posizione» spenta di base
- [ ] Il riquadro «Aggiunto per te» mostra città, zona, data e ora scelte («Adesso ▾»), veicolo senza targa, versione; le coordinate solo con «Allega posizione»
- [ ] «Invia la segnalazione» con Mail configurata: si apre Mail con destinatario support@example.com, oggetto, testo e la foto allegata
- [ ] Senza Mail configurata: si apre il foglio Condividi con testo e foto
- [ ] VoiceOver legge «Segnala un errore», «Foto allegata», «Allega posizione», «Spegni la modalità prova»

## 16. Stagioni con le regole e moto / scooter (1.17.1)
- [ ] Garage → «+»: in cima «Tipo di veicolo» con Auto / Moto / scooter; con Moto / scooter marca e modello si scrivono a mano, l'anno propone la classe Euro delle moto (2022 → Euro 5)
- [ ] «Auto a noleggio: scegli il modello»: in fondo gli scooter (Piaggio Liberty 125, Honda SH 125, Vespa Primavera 125, Kymco Agility 125) con l'icona dello scooter; scelto uno, il tipo diventa Moto / scooter
- [ ] Nel Garage la moto ha l'icona dello scooter e la riga «Moto / scooter · …»; il chip del veicolo in Varco e sulla mappa mostra lo scooter
- [ ] Varco con la moto in uso, Firenze Duomo un giorno feriale alle 11: «Entra pure.», «La ZTL è attiva, ma moto e scooter possono entrare.»; con l'auto a noleggio «Non entrare.»
- [ ] Moto in uso: Roma Pantheon feriale alle 11 → «Entra pure.»; Roma piazza di Spagna (Tridente) → «Non entrare.»; Ostuni Cattedrale alle 20 → «Non entrare.»
- [ ] Moto in uso, Firenze, una zona dello Scudo Verde fuori dai settori (es. Campo di Marte): «A una condizione»: «Qui le moto hanno limiti Euro loro…»
- [ ] Garage → «Consigli per …» con la moto: «Moto e scooter possono entrare» per i settori di Firenze, nessuna riga rossa sui divieti delle auto
- [ ] Scheda del Settore F di Firenze: «gio – sab (1 apr – 3 ott)» (la stagione 2027, perché quella del 2026 è finita); il riassunto dice «dal primo giovedì di aprile alla prima domenica di ottobre»
- [ ] Scegli giovedì 7 ottobre 2027 alle 23:30 («Adesso ▾»), Firenze Settore F: «Entra pure.» (la stagione 2027 finisce il 3 ottobre)
- [ ] Bergamo, Città Alta e Colli: venerdì 30 ottobre 2026 alle 21:30 «Entra pure.»; sabato 24 ottobre alle 23 «Non entrare.»
- [ ] Un iPhone con la 1.17.0: dopo l'aggiornamento dei dati Firenze si apre come prima, il Settore F mostra «1 apr – 7 ott» e nessun errore
- [ ] Il sito (Firenze): nel menu del veicolo «Moto / scooter · benzina Euro 5»; con la moto, Duomo di giorno → «Puoi entrare»

## 17. Nuovo stile delle zone sulla mappa (1.18.0)
- [ ] Mappa, Firenze, un giorno feriale alle 11 con l'auto a noleggio (benzina Euro 6): il Settore A è rosso, con il bordo tratteggiato e, avvicinando la mappa (z15, un quartiere sullo schermo), le righe a 45°; il segno «ZTL» è rosso
- [ ] Stessa ora, lo Scudo Verde (fuori dai settori) è verde con le righe (attivo, ma la tua auto entra); con un diesel Euro 2 dal 1° dicembre 2026 diventa rosso
- [ ] «Adesso ▾» → stasera alle 22: i settori A, B e O diventano grigi (nessuna ZTL attiva), bordo tratteggiato più rado, niente righe, segno «ZTL» grigio
- [ ] Milano Area C un giorno feriale alle 10 con l'auto benzina Euro 6: gialla (si entra col ticket), segno «ZTL» giallo con la scritta scura; il giallo si distingue bene dal rosso e dal verde anche al sole
- [ ] Una zona «da verificare» (es. un festivo non confermato): gialla con il segno «ZTL ?», mai grigia; in legenda la voce gialla dice «Con «?» non siamo sicuri: controlla il cartello»
- [ ] Trieste, Borgo Teresiano: da lontano (meno di z15) le vie (via Trento, via della Geppa…) sono solo il segno «ZTL»; avvicinando diventano corridoi larghi circa 15–20 punti con angoli tondi; ancora più vicino (z17) la scritta «ZTL · Via Trento» corre lungo la strada
- [ ] Bologna o Milano da vicino: le aree pedonali sono rosse, tratteggiate, senza righe, con il segno «PEDONALE» grigio scuro; i segni non si coprono (quelli che non stanno spariscono, le zone attive restano)
- [ ] I varchi compaiono solo da vicino (z16, poche vie sullo schermo): cerchio nel colore della risposta della zona con la telecamera bianca
- [ ] Cerca un hotel dentro una zona: quella zona ha il bordo pieno più spesso con l'alone, le altre si attenuano (40%); senza un posto cercato la zona della scheda ha il bordo pieno e le altre restano piene
- [ ] La striscia legenda sotto i chip ha quattro voci (rosso, giallo, verde, grigio) con i campioni tratteggiati e righe; la legenda intera spiega righe e tratteggio, «PEDONALE», «Zona piccola: solo il segno», «Varco con telecamera»
- [ ] Varco, la striscia di mappa in cima (Mapbox): le zone hanno gli stessi colori, il bordo tratteggiato e le righe se attive; senza Mapbox (mappa di Apple) lo stesso disegno
- [ ] La mappa resta fluida spostandola e zoomando a Firenze e a Milano (molte zone e aree pedonali); niente scatti quando compaiono le righe
- [ ] Modalità scura: colori più chiari sui bordi, segni leggibili, il giallo resta giallo

## 18. Mai un verde che non sappiamo (1.19.0)
- [ ] Garage: un diesel Euro 1. Varco, «Adesso ▾» stasera alle 22 (non giovedì–sabato dopo le 23), cerca «Palazzo Vecchio»: «Non entrare.», sotto «Firenze · Scudo Verde», pannello rosso «ZTL ATTIVA» (il Settore A è spento, ma lo Scudo Verde è sempre acceso). Con l'auto a noleggio benzina Euro 6 alla stessa ora: «Entra pure.», «ZTL NON ATTIVA» verde
- [ ] Milano, Corso Magenta, un giorno feriale alle 11 con la benzina Euro 6: «A una condizione» (ticket dell'Area C), anche se l'Area B da sola direbbe sì; in Viaggio «Anche dentro» elenca l'Area B
- [ ] Cerca un posto fuori dalle città di GateLR (es. Piazza del Duomo a Pistoia, Prato centro): «Non conosciamo questo posto.», contorno grigio-azzurro, pannello «ZONA NON COPERTA», mai verde né «Arrivo sereno»; in Viaggio la scheda con il «?» e il bordo grigio; sulla mappa il segno «Non conosciamo questo posto»
- [ ] Un indirizzo a meno di 2 km dalle zone di una città che c'è (es. Lucca appena fuori dalle mura): «Arrivo sereno.», «FUORI ZTL» verde, come prima
- [ ] Siri «ZTL vicine con GateLR» lontano da tutte le città: «Non conosciamo ancora le ZTL di questa zona.» (non più «Nessuna ZTL entro 5 km»)
- [ ] Una città con fonte non ufficiale (Cagliari, Mantova, Ostuni, Polignano, Salerno) a varchi spenti: «Probabilmente sì.» con «Fonte non ufficiale: controlla il cartello.», tutto giallo con il «?» (pannello, pillola, spillo e riquadro sulla mappa, zona sulla mappa, widget), mai verde; il guardiano avvisa «Probabilmente sì · fonte non ufficiale: controlla il cartello» e la Live Activity è gialla
- [ ] Pannello di Varco: con un'auto elettrica nell'Area C attiva (feriale alle 11) «ZTL ATTIVA · SEI ESENTE» verde; con dati da controllare o un festivo non confermato di notte il pannello dice «ZTL NON ATTIVA» in giallo, mai «ATTIVA» a varchi spenti
- [ ] «Non sicuro» è giallo con il «?» anche nella scheda grande di Viaggio e nelle pillole, mai grigio
- [ ] Scheda della zona, scheda della mappa, CarPlay e avvisi ad app chiusa per il Settore A di giorno con l'auto a noleggio: «Non entrare» (prima «A una condizione: l'hotel registra la targa»). Solo cercando l'hotel di un viaggio salvato dentro la ZTL la risposta è «A una condizione»
- [ ] Dopo l'aggiornamento il garage, i viaggi e i permessi ci sono ancora (il vecchio valore nascosto «hotel dentro la ZTL» si scarta)

## 19. L'area pedonale vince, Viaggio all'ora scelta (1.19.1)
- [ ] Viaggio (Tu → Viaggio e hotel), Bologna, cerca «Via Galliera»: in alto l'icona rossa con il pedone e «Area pedonale · Via Galliera» (non la spunta verde «Fuori dalla ZTL»); solo il riquadro rosso «Area pedonale · Via Galliera» e sotto «Parcheggia fuori e cammina»; NON c'è più la scheda verde «Fuori dalla ZTL. Puoi andarci»
- [ ] Viaggio, «Adesso ▾» stasera alle 23:58, cerca «Piazza Maggiore» (Bologna): «No, non entrare» (area pedonale) con la pillola «ZTL non attiva» (ZTL 7–20) e il titolo «ZTL · … 23:58»; prima diceva «ZTL attiva» a qualsiasi ora. Tocca «Perché?»: la scheda della zona dice «ZTL non attiva · <giorno> 23:58» in grigio, senza «puoi entrare»; con «Adesso» di giorno dice «ZTL attiva» in giallo
- [ ] Garage: diesel Euro 1. Varco, stasera alle 22, «Palazzo Vecchio»: «Non entrare.» e subito sotto il grande pulsante rosso «Parcheggia fuori e cammina»; la mappa è il pulsante piccolo accanto a «Perché?» e «Dettagli del viaggio» (tutti nello schermo senza scorrere). Con una risposta gialla (es. Area C col ticket) l'ordine resta quello di prima («Guarda la mappa» in alto)
- [ ] Stesso caso in Viaggio: dopo la scheda rossa viene «Parcheggia fuori e cammina», poi «Controlla il percorso» in azzurro chiaro (non più il pulsante blu pieno)
- [ ] Viaggio verso un posto in un'area pedonale (es. Via Galliera a Bologna, Alzaia Naviglio Pavese a Milano) → «Controlla il percorso»: nella lista c'è «Area pedonale · …» con «Non entrare» come destinazione, e il riepilogo propone il parcheggio fuori («Vai al parcheggio»); in navigazione l'avviso dice «Area pedonale»
- [ ] Mappa con un posto cercato (es. Palazzo Vecchio): l'etichetta sopra il punto («ZTL ATTIVA · NON ENTRARE» o «PROBABILMENTE SÌ») non è mai coperta: la riga «Legenda» sparisce finché c'è un posto, il punto sta più in basso; il pulsante «i» apre ancora la legenda intera. Togli il posto (✕): la riga «Legenda» torna

## 20. Fiducia: cartello, verbale, permessi (1.19.2)
- [ ] Tu → Cosa sono le ZTL → Leggi il cartello, scrivi «7.30-20.00 FERIALI» di sera dopo le 20 (o di domenica): riquadro GIALLO con il «?» «Secondo il cartello la ZTL sembra spenta adesso: controlla che non ci siano altri divieti», mai verde. Di giorno in settimana: rosso «Attiva adesso, secondo il cartello: non entrare». Scrivi «Benvenuti a Firenze»: giallo «Non riesco a leggerlo»
- [ ] Stessa schermata: «FESTIVI 10-18» il martedì 8 dicembre alle 12 (o una domenica) → rosso; «CARICO E SCARICO MERCI 6-10» la mattina → rosso tutti i giorni (prima solo il mercoledì); «0-24 FERIALI E FESTIVI» una domenica → rosso
- [ ] Fotografa con la fotocamera un pannello vero (o una foto): i giorni e gli orari sotto «Cosa vuol dire» sono quelli del pannello; la risposta è rossa o gialla, mai verde
- [ ] Tu → Multe → Fotografa il verbale, scrivi un verbale del Settore B di Firenze alle 21:32 di un giovedì: «Il varco era attivo?» è giallo con il «?» («Secondo i dati disponibili il varco non risulterebbe attivo… verifica la fonte ufficiale»), non verde. «Mostra la bozza»: «non risulterebbe attiva», «Secondo i dati disponibili», la data «consultati il …»; mai «non risultava attiva»
- [ ] «Copia un testo per il ricorso», poi su un Mac o iPad con lo stesso Apple ID prova a incollare: NON deve arrivare (Appunti universali). Sull'iPhone si incolla subito; dopo 10 minuti gli appunti sono vuoti
- [ ] Garage → Aggiungi un permesso: «Salva» è spento finché non scegli la zona (non c'è «tutta la città»). Salva → dialogo «Salvare questo permesso?» con zona e giorni; dopo la riga mostra «Firenze · Settore A» e «In attesa». Tocca «In attesa»: dialogo «Hai la conferma scritta?»; con «Annulla» resta «In attesa», con «Sì, ce l'ho per iscritto» diventa «Confermato». «Confermato» → un tocco lo riporta subito a «In attesa» (senza dialogo)
- [ ] Con un permesso confermato per il Settore A: Varco su un posto del Settore A di giorno → «Entra pure»; su un posto del Settore B alla stessa ora → «Non entrare» (il permesso non vale fuori dalla sua zona)
- [ ] Se avevi un permesso salvato prima della 1.19.2: nel Garage la riga dice «nessuna zona: non vale» e la pillola «Scegli la zona»; scelta la zona torna «In attesa» e va riconfermato
- [ ] Viaggio con un hotel dentro la ZTL: nella registrazione della targa tocca «Chiesto» o «Confermato» → prima compare il dialogo; con «Annulla» lo stato non cambia
- [ ] Varco su Palazzo Vecchio (anche con l'ora cambiata più volte di seguito): il pannello LED finisce sempre acceso con la scritta, mai nero
- [ ] Verbale del Settore F di Firenze (notti d'estate) un venerdì di luglio alle 23:30: «Il varco era attivo?» è rosso; cambia la data a un venerdì di novembre alle 23:30: giallo (spento secondo gli orari, dati non rivisti). Una data di più di 4 mesi prima della lettura dei dati: giallo «dati vecchi o non ufficiali»
- [ ] Viaggio → Messaggio per l'hotel → «Copia»: si incolla sull'iPhone, NON su Mac/iPad (Appunti universali); dopo 10 minuti gli appunti sono vuoti

## 21. Un solo avviso, widget con il tuo veicolo (1.19.3)
- [ ] Modalità prova (Tu → Impostazioni) con la zona «attiva adesso», poi Viaggio → Avvia → Guardiano verso un posto oltre la zona: avvicinandoti a piedi o in auto arriva UN solo avviso per la zona (voce + banner rosso «Non entrare · … Zona di prova» se l'app è aperta, notifica se è chiusa), mai due (guardiano + avviso ad app chiusa). Allontanati di oltre 1 km e torna: l'avviso arriva di nuovo
- [ ] Stessa prova camminando nella direzione OPPOSTA alla zona (zona alle spalle) o lungo una via parallela: nessun avviso. Fermo con il GPS senza direzione: al più un avviso, non uno ogni pochi metri
- [ ] Notifica ad app chiusa (Guardiano spento, avvisi accesi, app chiusa dal multitasking) passando vicino a un varco acceso: il titolo dice la risposta («Non entrare · Firenze Settore A», «Entri a una condizione: …», «? Controlla il cartello · …»), mai «ZTL attiva» se puoi entrare; con un'auto esente o di sera a varchi spenti NON arriva. Tocca la notifica: si apre «Parcheggia fuori e cammina» per quella zona (prima apriva solo l'app). Impostazioni → «Prova un avviso»: titolo «Non entrare · …», tocco = parcheggi fuori
- [ ] Guardiano acceso fuori dalle città che GateLR conosce (es. Pistoia, Prato, un'autostrada): riquadro in Varco, Dynamic Island e schermata di blocco NEUTRI con lo scudo vuoto e «Non conosciamo le ZTL di questo posto» (prima scudo verde con la spunta); in città senza ZTL davanti: grigio «Nessuna ZTL attiva davanti»; verso un'area pedonale (es. via Galliera a Bologna): rosso «Area pedonale · … · Non entrare»
- [ ] Siri «ZTL vicine con GateLR» fuori città: «Non conosciamo le ZTL di questo posto.» (non «Nessuna ZTL entro 5 km»); dentro un'area pedonale: «Sei dentro Area pedonale · …: Non entrare.»; in una zona da fonte non ufficiale: «Probabilmente sì · fonte non ufficiale: controlla il cartello». «Posso entrare a Bologna ZTL?»: aggiunge che dentro ci sono aree pedonali
- [ ] Widget «Varchi ZTL» (Home e schermata di blocco): Garage → scegli un diesel Euro 1: il widget con la zona Scudo Verde di Firenze (tieni premuto → Modifica widget) è rosso «Non entrare» anche di sera, quello del Settore A di sera è grigio «ZTL non attiva» (il widget è per una zona); con un'elettrica nell'Area C attiva: verde «Puoi entrare» e sotto il nome del veicolo; con un permesso confermato per il Settore A di giorno: verde. Una città aggiornata da Account → «Aggiorna i dati» si vede anche nel widget
- [ ] Prima installazione da Xcode: se la firma rifiuta l'App Group («group.it.ledion.GateLR»), scrivilo: l'app funziona lo stesso ma il widget torna ai dati dentro l'app e all'auto a noleggio. Con la .ipa di Sideloadly l'App Group di solito NON c'è (stesso effetto)

## 22. Privacy onesta (1.19.4)
- [ ] Tu → Privacy: «Nessun account, nessuna pubblicità, nessun tracciamento.», poi «Resta su questo iPhone», «Cosa esce» (Apple Mappe, Mapbox, GitHub, OpenStreetMap per i parcheggi), «La tua targa» con l'eccezione del messaggio per l'hotel; i testi si leggono interi, senza tagli, anche con il testo grande (Impostazioni → Schermo → Dimensioni testo)
- [ ] Privacy → «Telemetria di Mapbox» è SPENTA dopo l'aggiornamento (anche se prima non avevi mai toccato niente). Apri una mappa 3D (Varco con la striscia 3D, o Tu → Cosa sono le ZTL → Rivedi la presentazione), tocca la (i) in basso a destra → «Telemetria Mapbox»: dice che è spenta e propone di accenderla. Accendila lì: in Privacy l'interruttore è acceso; spegnilo in Privacy e la (i) dice di nuovo spenta. Chiudi e riapri l'app: la scelta resta
- [ ] Garage: un veicolo con targa (es. GX482KM) e con la targa scritta anche nel nome (es. «Panda GX482KM»). Tu → Multe e passaggi → Diario dei passaggi (dopo un avviso di prova o un passaggio vero): la riga nell'app mostra la targa; sotto, «Cosa viene condiviso» NON la mostra; «Condividi il diario» → in Note o Messaggi il testo è senza targa
- [ ] Tu → Multe → Fotografa il verbale, con un verbale che ha la targa: «Mostra la bozza» dice «veicolo targato [targa]»; «Copia un testo per il ricorso» e incolla in Note: nessuna targa
- [ ] Widget «Varchi ZTL» sulla schermata di blocco con il veicolo «Panda GX482KM»: sotto la risposta c'è «Panda», mai la targa
- [ ] Siri «Posso entrare a Firenze Settore A con GateLR?» e «ZTL vicine con GateLR»: nessuna targa nella risposta. Guardiano acceso verso una zona: notifica, Dynamic Island e schermata di blocco senza targa
- [ ] Viaggio → Messaggio per l'hotel con la targa nel Garage: sotto il testo c'è «Questo messaggio contiene la tua targa: all'hotel serve per registrarti al Comune»; il messaggio la contiene (è l'unica eccezione)
- [ ] Segnala un errore (scheda della zona): nelle righe aggiunte «Vehicle:» dice modello o nome senza targa
- [ ] Prima autorizzazione della posizione e della fotocamera (app appena installata, o Impostazioni → Generali → Trasferisci o inizializza → Inizializza posizione e privacy): i testi dicono che la posizione è usata sull'iPhone e che GateLR non la raccoglie, e che le foto non vengono caricate
- [ ] Xcode → Product → Archive → Generate Privacy Report (o il rapporto dell'archivio): c'è il manifesto di GateLR, quello del widget e quello di Mapbox; nessun avviso di «API con motivo richiesto» mancante
- [ ] Android: Account → Privacy (nessun account; cosa resta; cosa esce: OpenFreeMap, Photon con la posizione per ordinare i risultati, OSRM; ML Kit; targa) e il link «Informativa sulla privacy»; Diario → Condividi il diario: nessuna targa
- [ ] Sito: https://lr-apps609.github.io/GateLR/privacy/ in italiano con l'inglese sotto, gli stessi servizi dell'app

## 23. Più veloce (1.19.5)
- [ ] Varco → cerca «Piazza dei Signori Treviso» (città senza parcheggi dentro l'app) → «Parcheggia fuori e cammina»: subito tre righe grigie ferme (nessun colore, nessun verde), poi i parcheggi in pochi secondi (prima anche 1–2 minuti di «Cerco…»). Con la modalità aereo: dopo al più ~30 secondi «Nessun parcheggio…» e il pulsante «Riprova»; togli la modalità aereo, «Riprova» → arrivano i parcheggi
- [ ] Varco a freddo (app chiusa dal multitasking, poi riaperta) con un posto già scelto: la risposta compare senza attese visibili; la striscia di mappa in alto è blu notte con qualche via grigia finché la mappa 3D non è pronta, mai nera o vuota, e mai del colore della risposta prima che la mappa ci sia
- [ ] Ricerca: scrivi «Palazzo Vecchio» lettera per lettera: i suggerimenti arrivano mentre scrivi, come prima; scegli il suggerimento, poi la croce e scegli di nuovo lo stesso: la risposta arriva subito. In Mappa cambia città dal menu: i suggerimenti sono della città nuova
- [ ] Guardiano acceso (Viaggio → Avvia → un navigatore) per 10–15 minuti in città: la pagina Varco scorre fluida, il riquadro del guardiano cambia distanza; l'iPhone non scalda più del solito. Guida di GateLR: fermo a un semaforo la mappa resta ferma e liscia, alla ripartenza auto e camera riprendono subito senza scatti
- [ ] iPhone più vecchio che hai (o Impostazioni → Accessibilità → Movimento → Riduci movimento) e rete lenta (Impostazioni sviluppatore → Network Link Conditioner «3G», se c'è): Varco, Mappa su Milano Area B (sposta e ingrandisci fino ai varchi) e «Parcheggia fuori» restano usabili; Account → «Aggiorna i dati» finisce entro circa 20 secondi o dice che non è riuscito

## 24. Più veloce: sito e Android (1.19.5)
- [ ] Sito sul telefono (https://lr-apps609.github.io/GateLR/), meglio con la rete lenta (Wi-Fi debole o 3G): mentre carica, la risposta è un riquadro grigio che «respira», MAI verde; poi compare la risposta per Firenze. Con il link …/#roma la prima risposta è per Roma
- [ ] Tocca «Milano», poi subito «Roma»: resta la risposta dell'ultima città toccata (Roma), mai quella di Milano dopo
- [ ] Cerca «via tornabuoni» con Firenze mostrata: i primi risultati sono a Firenze; mostra Roma (tocca «Roma») e cerca «via del corso»: i primi sono a Roma. Cancella e riscrivi la stessa parola: i risultati tornano subito, senza attesa
- [ ] Accanto a un risultato di un'altra città: «in ZTL» / «fuori» arriva dopo un attimo (prima un trattino grigio), mai un'etichetta sbagliata
- [ ] Modalità aereo dopo aver aperto la pagina, poi tocca una città mai aperta (es. «Lecce»): dopo qualche secondo «Non riesco a caricare le regole di questa città…» con «Riprova»; riaccendi la rete, «Riprova»: arriva la risposta
- [ ] La mappa vera (strade) arriva dopo la risposta, non prima; i caratteri sono quelli di sempre (titoli Titillium, testo Atkinson, pannello del varco a puntini); le due schermate dell'iPhone nella vetrina sono nitide
- [ ] Pagina di una città (es. …/firenze/): si legge subito, la mappa vera arriva dopo; Privacy e Supporto con gli stessi caratteri
- [ ] Android → Mappa o Viaggio: cerca un hotel di Firenze mentre sei in un'altra città: i risultati sono a Firenze (la città scelta); vicino a casa vincono i posti vicino a te
- [ ] Android in modalità aereo → cerca «duomo»: «La ricerca non funziona adesso. Controlla la connessione.» con «Riprova» (prima: «Nessun risultato»); riaccendi la rete e tocca «Riprova»: arrivano i risultati

## 25. Motore unico (1.20.0)
Le stesse risposte su iPhone, Android e sito: i casi di prova comuni sono in shared/engine-cases.json (li provano i test di tutte e tre a ogni modifica). Sul telefono basta controllare che si vedano come qui sotto.
- [ ] iPhone, Android e sito, veicolo «Auto a noleggio» (benzina Euro 6), ora scelta martedì 8 dicembre alle 12:00, posto «Colli di Bergamo» (o un punto dentro la ZTL Colli): rosso «Non entrare» su tutti e tre, mai verde né «ZTL non attiva». Martedì 15 dicembre alle 12:00 lo stesso posto: grigio, ZTL non attiva
- [ ] Android → Mappa e Viaggio: cerca «Duomo di Salerno»: in alto l'avviso giallo «Fonte non ufficiale: verifica sempre il cartello al varco» con «Dati da …»; la risposta dice «Probabilmente no». Cerca «Bastione di Saint Remy» (Cagliari) alle 12:00: giallo con il «?», «Probabilmente sì · fonte non ufficiale: controlla il cartello», mai verde né grigio. Le stesse risposte sull'iPhone
- [ ] Android, veicolo diesel Euro 1, Palazzo Vecchio alle 23:00 di un martedì: «Non entrare» con lo Scudo Verde come zona che decide (prima Android: «sì» dal Settore A spento)
- [ ] Android → Viaggio o Mappa: cerca «Prato» o «Venezia»: «Non conosciamo questo posto», neutro, mai «Fuori dalla ZTL» né verde. Cerca «Bologna Centrale»: «Fuori dalla ZTL», verde
- [ ] Android: una zona con dati da ricontrollare o un festivo non confermato (es. Firenze Settore A l'8 dicembre alle 10): la risposta «Non sicuro» è gialla con il «?», non più grigio chiaro. Widget Android a ZTL spenta: grigio «ZTL non attiva»
- [ ] Android → Viaggio con un hotel dentro una ZTL → «Chiesto» o «Confermato»: la risposta cambia solo per la zona dell'hotel (il permesso salvato prima della 1.20.0 senza zona non vale finché non lo tocchi di nuovo)
- [ ] Sito: Pantheon, Roma, martedì 29 giugno 2027 alle 10:00: «ZTL non attiva» (festa del patrono); martedì 22 giugno alle 10:00: «No, non entrare». Cerca «Prato»: «Non conosciamo questo posto», riquadro neutro con il «?», pannello «ZONA NON COPERTA», mai verde
- [ ] Sito: Cagliari, Bastione di Saint Remy alle 12:00: «Probabilmente sì» giallo con il «?» e l'avviso «Fonte non ufficiale»; sulla mappa la zona è gialla, mai verde né grigia
- [ ] Sito: Palazzo Vecchio di notte con «Diesel Euro 4» e poi con «Auto a noleggio»: le risposte sono quelle della zona più severa (la zona scritta sotto la risposta è quella che decide)

## 26. Dati (1.20.1)
«Letto il» e «verificato il» separati, regola A (lettura o verifica entro 120 giorni e pagina del Comune uguale), ZTL spenta verde, dati scaricati solo se firmati. Regole e soglia: docs/dati-verifica.md.
- [ ] iPhone → Varco: Palazzo Vecchio alle 23:00 di un martedì con «Auto a noleggio»: VERDE «Entra pure.», il pannello dice «ZTL NON ATTIVA». Alle 10:00 dello stesso giorno: rosso «Non entrare»
- [ ] iPhone → Mappa a ZTL spenta (sera, Firenze): le zone sono verdi chiare, senza righe, con il bordo più rado (non più grigie); legenda: «ZTL non attiva» in verde. Bologna Centrale: verde «Fuori dalla ZTL»; Prato: neutro «Non conosciamo questo posto»
- [ ] iPhone → Varco: Colosseo (Roma) di sera: giallo con il «?», «La pagina del Comune è cambiata: controlla il cartello…» (la pagina di Roma Mobilità è cambiata dopo la lettura); anche di giorno, al posto del rosso
- [ ] iPhone → «Perché?» / scheda della zona di Firenze, in fondo: «Letto dalle fonti ufficiali il 23 ottobre 2026.» e «Non ancora verificato da una persona.» (grigio, non giallo); nel riquadro della risposta (Viaggio) «Letto il …» e sotto «Non verificato». Per una zona di Roma: «La pagina del Comune è cambiata dall'ultima lettura o verifica: controlla il cartello.» in giallo
- [ ] iPhone → widget a ZTL spenta: verde con la luna, «ZTL non attiva». Guida o guardiano senza ZTL attiva davanti (in città): Live Activity verde «Nessuna ZTL attiva davanti»; fuori dalle città che conosciamo: neutro
- [ ] iPhone → Tu → Impostazioni → «Controlla aggiornamenti»: finché la chiave di firma non è configurata (docs/dati-verifica.md) dice «Non firmati: restano i tuoi dati» e la versione dei dati resta quella dell'app; con la firma configurata e dati nuovi: «Aggiornati»
- [ ] iPhone con dati scaricati da una versione precedente: dopo l'aggiornamento alla 1.20.1 la versione dei dati in Impostazioni è quella dell'app (i dati senza firma non si usano più); il widget mostra le stesse risposte dell'app
- [ ] Android → Palazzo Vecchio alle 23:00: verde «ZTL non attiva». Widget Android a ZTL spenta: verde con «ZTL non attiva» (prima grigio). Scheda della zona → Fonti ufficiali: «Letto il …» e «Non ancora verificato da una persona.»; Account → Regole e mappe: per ogni città «Letto il … · Non ancora verificato da una persona.». Una zona di Roma: «La pagina del Comune è cambiata: controlla il cartello.», risposta gialla
- [ ] Sito: Palazzo Vecchio alle 23:00: verde, sulla mappa le zone spente sono verdi chiare; legenda «ZTL non attiva: puoi entrare». Sotto la risposta «Letto il … dal sito del Comune di Firenze: pagina ufficiale ↗» e «Non ancora verificato da una persona.». Colosseo: giallo «?» con «La pagina del Comune è cambiata». Pagina di una città (es. /it/firenze/): sotto ogni fonte «Letto il … · Non ancora verificato da una persona»

## 27. Comodità (1.20.2)
Permessi quando servono, Invio e «Riprova» nella ricerca, conferma prima di cancellare, città dalla posizione.
- [ ] iPhone appena installato: presentazione → «Più tardi»: nessuna richiesta di iOS (né posizione né notifiche). Varco → tocca l'icona della posizione nel campo di ricerca: solo adesso iOS chiede la posizione; con «Consenti» la pagina va sulla città dove sei e mostra «La tua posizione»
- [ ] iPhone → Tu → Impostazioni con gli avvisi accesi ma senza permessi: c'è «Consenti gli avvisi»; il tocco chiede notifiche e posizione, poi la riga sparisce
- [ ] iPhone → Varco: scrivi «Palazzo Vecchio» e premi «Cerca» sulla tastiera: si apre la risposta del primo suggerimento. In modalità aereo: «La ricerca non funziona adesso…» con «Riprova»; tolta la modalità aereo, «Riprova» mostra i suggerimenti. Lo stesso in Mappa e in Viaggio
- [ ] iPhone → Garage: scorri a sinistra su un veicolo → Elimina: compare «Eliminare questo veicolo?» con «Vengono eliminati anche i suoi permessi»; «Annulla» lo lascia. Lo stesso per un permesso, un viaggio salvato (tieni premuto → Elimina) e una riga del diario dei passaggi
- [ ] iPhone → Viaggio con un diesel Euro 1 alle 22 a Palazzo Vecchio, senza rete: «Parcheggia fuori e cammina» dice «Non riesco a cercare i parcheggi adesso…» con «Riprova» sulla stessa riga, tutto sopra la barra delle schede quando scorri
- [ ] Android appena installato: benvenuto → nessuna richiesta. Prima pagina → tocca «Consenti l'accesso alla posizione…»: Android chiede la posizione. «Avvia» su una meta: chiede posizione (se manca) e notifiche
- [ ] Android → Viaggio: scrivi un hotel e premi il tasto di ricerca della tastiera: si apre il primo risultato. Garage → elimina un permesso o un veicolo: prima il dialogo «Eliminare…?»
- [ ] Sito: scrivi «Palazzo Vecchio» e premi Invio subito: la risposta del primo risultato. Senza rete: «Non riesco a cercare adesso…» con «Riprova»


## 28. Parole (1.20.3)
Una sola forma della risposta per lingua: «Non entrare», «Puoi entrare», «A una condizione», «Controlla il cartello» (e «Non conosciamo questo posto» fuori copertura). Le altre forme sono la frase sotto, mai il titolo. Nessuna risposta né colore cambia.
- [ ] iPhone → Varco: Palazzo Vecchio alle 10:00 di un martedì con «Auto a noleggio»: rosso «Non entrare» (senza punto); alle 23:00 verde «Puoi entrare» (prima «Entra pure.») con il pannello «ZTL NON ATTIVA»
- [ ] iPhone → Varco: Bologna Centrale (fuori dalle zone): verde «Puoi entrare» (prima «Arrivo sereno.»), sotto «Fuori dalla ZTL»; Prato: neutro «Non conosciamo questo posto»
- [ ] iPhone → Varco: Cagliari, Bastione di Saint Remy alle 12:00: giallo «Controlla il cartello» (prima «Probabilmente sì.»), sotto «Probabilmente sì · fonte non ufficiale»; Salerno di giorno: rosso «Non entrare» (prima «Probabilmente no.»), sotto «Probabilmente no · fonte non ufficiale»
- [ ] iPhone → Varco con una condizione (Milano Area C, benzina, mercoledì alle 11): «A una condizione» e sotto la condizione; un festivo incerto: «Controlla il cartello» e sotto il motivo
- [ ] iPhone → Mappa: il riquadro sopra il posto dice le stesse parole («NON ENTRARE», «PUOI ENTRARE», «CONTROLLA IL CARTELLO»), sotto «Attiva fino alle …»; la pillola nella scheda del posto uguale; la legenda «Non entrare / A una condizione / Puoi entrare / ZTL non attiva»
- [ ] iPhone → Viaggio: il riquadro grande dice «Non|entrare», «Puoi|entrare», «A una|condizione» o «Controlla il|cartello» su due righe; fuori dalle zone «Puoi entrare» (prima «Fuori dalla ZTL» come titolo)
- [ ] Pillole del tipo di zona (Mappa, scheda della zona, widget, elenco «Anche dentro»): «ZTL», «ZTL con pass», «Zona verde»; mai più «Accesso vietato» o «Pass necessario» accanto a «Puoi entrare»
- [ ] Widget a ZTL spenta: verde «Puoi entrare» con la luna, sotto «ZTL non attiva · Inizia alle …». Dati vecchi: «Controlla il cartello», sotto «Dati da ricontrollare»
- [ ] 🚗 Guardiano o guida verso una ZTL attiva: la notifica dice «Non entrare · Firenze Settore A» (o «A una condizione · …», «Controlla il cartello · …»); nella Dynamic Island compatta accanto allo scudo «✕», «!», «✓», «–» o «?», mai «OK»
- [ ] 🚗 Guida con il telefono in inglese (Stati Uniti): la velocità in «mph»; in italiano «km/h». In francese o polacco le frecce delle svolte sono giuste (destra, sinistra, inversione), non sempre dritte
- [ ] iPhone → Tu → Impostazioni → «Impara la ZTL»: il pannello disegnato dice «ZTL ATTIVA / NON ATTIVA»; la riga «Varco attivo» spiega che è la dicitura vecchia. Presentazione: i pannelli dicono «ZTL ATTIVA», «ATTIVA TRA 15'», «ZTL NON ATTIVA» (prima «VARCO …»)
- [ ] iPhone → «Segnala un errore» su una zona: sotto «Aggiunto per te» righe in italiano («Cosa: Orari», «Città: …», «Zona: …», «Data e ora: … (ora italiana) · adesso», «Veicolo: …») e in fondo «Rif.: hours · firenze · firenze-a · 1.20.3 (56) · iOS … · it»; niente più «What:», «Date/time:»
- [ ] iPhone → Tu → Impostazioni → Modalità prova: la spiegazione non dice più «Vedi docs/prova-sul-campo.md»
- [ ] iPhone in francese (o spagnolo, olandese, polacco, cinese) → scheda della zona di Firenze Settore A: «In breve» in italiano e sotto in inglese; il nome «Settore A · Centro storico (Sector A · Historic Centre)»; il ticket di Milano Area C con «Come pagare» in italiano e inglese. In tedesco e italiano come prima
- [ ] iPhone in tedesco e in polacco: le pillole («Nicht einfahren», «Achte auf das Schild», «Pod jednym warunkiem») non vanno a capo; il chip del veicolo in alto è corto, «Fiat 500 · E6» o «Golf · E6», non più «Auto a noleggio · benzina E…» troncato
- [ ] Android in francese, spagnolo, olandese, polacco e cinese (Impostazioni → App → GateLR → Lingua): l'app è tradotta (prima solo inglese); le schede sono «Varco, Mappa, Viaggio, Garage, Tu» (prima «Account»); in cima alla prima pagina «Varco» (prima «Sappilo prima del varco.»)
- [ ] Android → Palazzo Vecchio di sera: «Puoi entrare»; il widget a ZTL spenta «Puoi entrare» con sotto «ZTL non attiva · …»; Cagliari: «Controlla il cartello», sotto «Probabilmente sì · fonte non ufficiale»; fuori dalle zone la pillola «Puoi entrare» e sotto «Fuori dalla ZTL»
- [ ] Sito (EN, IT, DE): Palazzo Vecchio di giorno «Non entrare», di sera «Puoi entrare», il pannello «ZTL ATTIVA / ZTL NON ATTIVA» (prima «VARCO ATTIVO»); Cagliari «Controlla il cartello» con «Probabilmente sì · fonte non ufficiale.» all'inizio della spiegazione; legenda dei tipi «ZTL», «ZTL con pass», «Zona verde»; FAQ «Come capisco se un varco è acceso?» con «ZTL attiva» e la dicitura vecchia


## 29. Solidità (1.20.4)
«Fuori dalla ZTL» grigio, memoria di Varco, bug dei tester. Le regole delle città non cambiano.
- [ ] iPhone → Varco: Bologna Centrale (fuori dalle zone): grigio «Fuori dalla ZTL» con il trattino, mai verde; Mappa, Viaggio e foglio del parcheggio uguali
- [ ] iPhone → Varco senza un posto, 10 minuti con il guardiano acceso in città: tutto fluido, il telefono non scalda più del solito
- [ ] iPhone → Mappa al buio (Milano): nessuna riga scura lungo i bordi delle zone
- [ ] iPhone → Viaggio con un «no» (Palazzo Vecchio, diesel Euro 1, martedì 10:00): il riquadro dei parcheggi e «Riprova» sopra la barra delle schede
- [ ] iPhone → Garage, hotel dentro la ZTL non ancora chiesto: «Non entrare»; dopo «Ho chiesto all'hotel» con targa e date giuste: giallo «A una condizione», mai verde
- [ ] iPhone → posizione «Approssimativa», poi guardiano: «Serve la posizione esatta per i varchi» con «Impostazioni», mai un'icona di protezione
- [ ] iPhone → Mappa alle 7:29 a Firenze, poi attendi le 7:30: il Settore A diventa rosso senza toccare niente
- [ ] iPhone con testo grandissimo (Accessibilità): Varco, presentazione e pannello leggibili, niente parole tagliate
- [ ] Siri: «Posso entrare in Area C con GateLR?»: risponde per Milano Area C, non per un'altra zona simile
- [ ] Android: quattro schede Adesso · Mappa · Viaggio · Aiuto; Garage e Impostazioni dall'icona del veicolo; Indietro torna ad Adesso; widget con «Aggiornato alle»


## 30. 2.0 (una risposta, struttura, grafica)
- [ ] Prima apertura: presentazione in 3 pagine, poi «Con cosa entri?» con «Non so»; una sola barretta rossa in alto
- [ ] Quattro schede in basso: Adesso, Mappa, Viaggio, Aiuto; in alto la fotocamera («Leggi il cartello») e l'icona del veicolo, che apre Garage, Impostazioni, Privacy, Fonti
- [ ] Adesso con la posizione, in città: risposta per la zona in cui sei o per quella davanti a te entro 300 m («… m davanti a te»); fuori dalle zone grigio «Fuori dalla ZTL»
- [ ] Tema del telefono chiaro e scuro: l'app cambia da sola; il blocco della risposta è uguale nei due temi
- [ ] Firenze di sera: piazza della Signoria e Ponte Vecchio «Non entrare» (aree pedonali), Palazzo Vecchio (il palazzo) «ZTL non attiva» verde
- [ ] Milano, Navigli o Ticinese: «Controlla il cartello» (ZTL locali, dati del 2023)
- [ ] Hotel in Firenze Settore A senza conferma: «Non entrare»; dopo «L'hotel ha registrato la targa» con l'auto e le date del viaggio: «Puoi entrare» con «L'hotel ha registrato la targa · dal … al …»
- [ ] Garage con alimentazione «Non so»: a Milano Area B «Controlla il cartello», mai «Puoi entrare»
- [ ] «In auto» da Adesso: schermo intero, parole grandi, «Parcheggia fuori» quando è no
- [ ] Testo grandissimo (Impostazioni → Accessibilità): le parole della risposta vanno a capo intere, niente pulsanti tagliati
- [ ] VoiceOver su Adesso: legge la risposta in un colpo solo
- [ ] Mappa: le righe delle zone si leggono bene di giorno e di sera
- [ ] iPad: in Adesso mappa e risposta affiancate
- [ ] Sito: «Puoi entrare» e «A una condizione» come nell'app

## 31. 2.0.1 (schermi piccoli)
- [ ] iPhone SE (o testo grande): scegli un posto in Adesso; la parola della risposta si vede intera sopra la barra delle schede, senza scorrere
- [ ] Con un posto scelto la ricerca si apre dalla lente accanto al nome del posto
- [ ] Testo grandissimo su iPhone SE: niente striscia di mappa, c'è «Guarda la mappa» che apre la Mappa
- [ ] iPhone grandi e iPad: Adesso uguale alla 2.0
