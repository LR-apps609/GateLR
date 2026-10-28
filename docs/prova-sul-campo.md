# Prova sul campo senza girare l'Italia (1.17.0)

Due modi per vedere GateLR «in azione» da casa o dal tuo quartiere:

1. **Modalità prova** sull'iPhone: una ZTL finta intorno a dove sei, con varchi sulle strade vere vicine.
2. **Giri finti con Xcode** (file GPX): l'iPhone collegato al Mac «crede» di guidare a Firenze, Pisa, Roma, Bologna o Siena.

E, quando qualcosa non torna sul posto, **«Segnala un errore»**.

---

## 1. Modalità prova

### Accenderla
1. Apri GateLR → scheda **Tu** → **Impostazioni**.
2. Nella sezione **Modalità prova** accendi l'interruttore **Modalità prova**.
   - Serve la posizione: se l'app non l'ha ancora, consenti l'accesso alla posizione quando iOS lo chiede.
   - Per qualche secondo vedi «Cerco le strade intorno a te…»: l'app chiede ad Apple Mappe da dove arrivano le auto e mette
     i varchi dove una strada vera entra nella zona.
3. Sotto compaiono i **Varco di prova 1 · via …** (uno o due) e il **Parcheggio di prova**.

### Cosa succede
- In cima a ogni schermata (Varco, Mappa, Tu, scheda della zona, guida) c'è la striscia viola **«Modalità prova attiva»**
  con lo stato della zona, il menu **⋯** e il pulsante **Spegni**.
- La zona è un cerchio di circa **400 m** intorno a dove eri, chiamata **«ZONA DI PROVA»**. Sulla mappa ha la scritta viola
  «ZONA DI PROVA · attiva» (o «spenta»).
- **Attiva adesso** (di base): la ZTL è accesa tutto il giorno, ogni giorno, anche nei festivi. Varco risponde
  **«Non entrare.»** e il pannello dice VARCO ATTIVO.
- **Spenta** (Impostazioni → «ZTL di prova» → Spenta, o menu ⋯ della striscia → «Spegni la ZTL di prova»): Varco risponde
  **«Entra pure.»**, pannello verde. Così si provano tutti e due gli stati.
- La zona passa da tutto il resto dell'app come una zona vera:
  - **Varco**: la risposta per «La mia posizione» quando sei dentro; «Vicino a te: ZONA DI PROVA · … · attiva adesso».
  - **Mappa**: la zona colorata, i varchi, la scheda in basso, «Parcheggia fuori» (con il Parcheggio di prova per primo).
  - **Avvisi**: con gli avvisi accesi (Tu → Impostazioni → Avvisi dei varchi) la notifica arriva avvicinandoti a un varco di prova.
  - **Guardiano e navigazione di GateLR**: il percorso che entra nella zona di prova viene segnalato (con la
    proposta del Parcheggio di prova se la destinazione è dentro), se esci dal percorso la guida ricalcola, la voce avvisa, Live Activity e Dynamic Island mostrano la zona.
  - **«Parcheggia fuori e cammina»**: propone il Parcheggio di prova, fuori dalla zona, con i minuti a piedi.
- **Sposta la zona qui** (Impostazioni o menu ⋯): rifà la zona intorno a dove sei adesso; la vecchia sparisce.

### Spegnerla
- Tocca **Spegni** sulla striscia viola, oppure spegni l'interruttore in Impostazioni.
- La zona sparisce da mappa, risposte e avvisi.

### Da sapere
- La modalità prova **non è mai accesa da sola**: la accendi solo tu.
- Resta **solo su questo iPhone**: non viene mai sincronizzata né inviata (neanche con «Segnala un bug»).
- Resta accesa anche se chiudi l'app, finché non la spegni (così puoi riaprire l'app da Xcode o dopo una pausa).
- È una zona inventata: **i cartelli veri sul posto valgono sempre**.

---

## 2. Giri finti con Xcode (GPX)

Servono il Mac con Xcode e l'iPhone collegato con il cavo (o in rete con Xcode).

### I giri
I file sono in `Resources/GPX/` (nel progetto, ma **non** dentro l'app installata):

| File | Cosa fa | Cosa deve succedere |
|---|---|---|
| `firenze-viale-cavour-settore-a.gpx` | dal viale entra in Settore A dal varco di via Cavour | di giorno feriale: avviso prima del varco, «Non entrare.», poi «sei dentro» |
| `firenze-viali-parcheggio-beccaria.gpx` | intorno alla ZTL lungo i viali fino al Parcheggio Beccaria | varchi vicini segnalati ma nessuna entrata; arrivo al parcheggio fuori |
| `pisa-intorno-alla-ztl.gpx` | il giro intorno alla ZTL di Pisa | avvisi dei varchi vicini, nessuna entrata |
| `roma-tridente-avvicinamento.gpx` | verso la ZTL Tridente e poi via, senza entrare | di giorno feriale l'avviso del Tridente, che poi sparisce quando ti allontani |
| `bologna-in-centro-dal-varco.gpx` | dai viali in centro da un varco (San Felice) | tra le 7 e le 20: avviso, «Non entrare.», poi «sei dentro» |
| `siena-avvicinamento-varco.gpx` | fino a Porta Camollia e poi al parcheggio fuori | avviso del varco Camollia (la ZTL di Siena è sempre attiva), nessuna entrata |

Gli orari dei punti sono realistici: **25–35 km/h** in città, più piano nelle curve, partenza e arrivo da fermi, così
la velocità e la direzione di marcia dell'app funzionano come in auto. I giri durano dai 2 ai 15 minuti.

### Passo passo
1. Sul Mac: `xcodegen generate` nella cartella del progetto, poi apri `GateLR.xcodeproj`.
2. Collega l'iPhone, sceglilo in alto come destinazione e premi **▶︎** (Run). Aspetta che l'app sia aperta sull'iPhone.
3. Nell'app: consenti la posizione **Sempre** (per gli avvisi con l'app chiusa) e, se vuoi, scegli un'ora: con
   «Adesso ▾» la risposta è per l'ora vera, quindi fai i giri di giorno feriale per vedere le ZTL accese.
4. In Xcode, menu **Debug → Simulate Location** (oppure il pulsante con la freccia nella barra del debug, in basso):
   compare l'elenco con i sei giri. Scegline uno, per esempio **firenze-viale-cavour-settore-a**.
5. L'iPhone si «sposta» sulla partenza e comincia a muoversi lungo la strada.
6. Cosa guardare sullo schermo:
   - **Varco**: «Vicino a te: Settore B · 300 m · attiva adesso», poi, una volta dentro, la risposta per «La mia posizione».
   - **Mappa**: il pallino blu si muove lungo la strada.
   - **Navigazione di GateLR** (cerca la destinazione e «Avvia» con «Navigazione di GateLR»): la barra della prossima ZTL
     in alto, la voce, la velocità.
   - **Guardiano** (con un altro navigatore): la striscia rossa in Varco, la Live Activity sulla schermata di blocco e
     nella Dynamic Island, la notifica prima del varco.
7. Per fermarti: **Debug → Simulate Location → Don't Simulate Location** (o ferma l'app con ■). Alla fine del giro
   Xcode resta sull'ultimo punto.

Si possono usare i GPX anche con la **Modalità prova**: la zona di prova si fa dove sei davvero (o dove Xcode dice che
sei), quindi accendi la modalità prova dopo aver scelto il giro e poi usa «Sposta la zona qui».

### Rifare i giri
I percorsi vengono da OSRM (dati © OpenStreetMap, ODbL) con `Tools/gpx_routes.py`:
1. Su GitHub: Actions → «Percorsi della presentazione» → Run workflow (scarica anche i giri: `gpx-routes.json` nel ramo
   `intro-routes`).
2. Sul computer: `python3 Tools/gpx_routes.py build gpx-routes.json Resources/GPX` sceglie per ogni giro la variante che
   fa davvero quello che deve (passa dal varco giusto, resta fuori dalla ZTL…) e scrive i file.

---

## 3. «Segnala un errore»

Quando sul posto qualcosa non torna (orari diversi sul cartello, un varco che non c'è, un confine sbagliato):

1. Apri la zona: **Varco** → «Perché?» oppure **Mappa** → «Dettagli zona», e tocca **Segnala un errore**
   (c'è anche in fondo alla risposta di Varco).
2. Scegli cosa non va: **Orari**, **Confini**, **Varco** o **Altro**.
3. Scrivi una nota (es. «il pannello dice 7.30–19.30, l'app dice 20.00»).
4. Facoltativo: **Scatta una foto** del cartello o **Scegli una foto**.
5. Facoltativo: **Allega posizione** (spenta di base: senza, le coordinate non partono).
6. Sotto vedi **«Aggiunto per te»**: città, zona, data e ora scelte, veicolo (senza targa), versione dell'app.
7. **Invia la segnalazione**: si apre Mail con tutto pronto. Se Mail non è configurata, si apre Condividi con testo e foto
   (WhatsApp, Messaggi, Note…).

L'indirizzo di arrivo è uno solo, in `Sources/AppConfig.swift` (`AppConfig.supportEmail`): per ora è il segnaposto
`support@example.com`, da sostituire con l'indirizzo di assistenza vero prima della pubblicazione. Nessun server: parte
tutto da Mail o da Condividi.
