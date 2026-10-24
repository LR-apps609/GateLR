# GateLR – Roadmap 3: la migliore app per le ZTL, su iPhone e Android (dal 24 ottobre 2026)

Obiettivo finale: **l'app di riferimento per chiunque guidi in una città italiana**, turista o italiano, su qualsiasi telefono.
Difficoltà: 🟢 facile · 🟡 media · 🔴 difficile. Tempi in **sessioni** (qualche ora di lavoro).

---

## 1. Dove siamo rispetto agli altri

| | **GateLR** (1.8) | **ZigZag** | **ZTL Italia** (Android) | **«ZTL»** (iOS) | Google Maps / Waze |
|---|---|---|---|---|---|
| Città | 3, da fonti ufficiali | «tutta Italia» | 5 gratis, 220–390 a pagamento | 470+ (dati collaborativi) | poche, inaffidabile |
| Orari con fonte e data | ✅ ogni regola | ? | in parte («dove confermati») | grigio = sconosciuto | ❌ |
| Avviso ad app chiusa | ✅ | ❌ (lo dicono loro) | ✅ | ✅ | Waze in poche città |
| Guardiano accanto al navigatore, Dynamic Island | ✅ | ❌ | notifiche | ❌ | – |
| Navigatore interno | ✅ base | ✅ Pro | ❌ | ❌ | ✅ |
| Parcheggi fuori ZTL | ✅ base (Apple Maps) | ✅ forte, prezzi | ✅ | ❌ | ✅ |
| Hotel: registrazione targa, messaggio, conferma scritta | ✅ unico | ❌ | ❌ | ❌ | ❌ |
| Ticket a pagamento con promemoria | ✅ unico | ? | ❌ | ❌ | ❌ |
| Divieti per classe Euro (Area B/C) | ✅ | ✅ (veicolo) | ❌ | ❌ | ❌ |
| Leggi il cartello con la fotocamera | ✅ unico | ❌ | ❌ | ❌ | ❌ |
| Multe: diario, guida, ricorso | ✅ unico | ❌ | ❌ | ❌ | ❌ |
| Lingue | IT, EN, DE | IT | EN, IT | EN | tutte |
| Android | ⏳ (questa roadmap) | ✅ | ✅ | ❌ | ✅ |
| Prezzo | gratis per ora | 34,99 €/anno, 149,99 € a vita | 9,99 € una tantum | 2,99 € | gratis |

Fonti: [ZigZag su App Store](https://apps.apple.com/it/app/zigzag-navigatore-ztl/id6738909628), [ZTL Italia su Google Play](https://play.google.com/store/apps/details?id=com.andrejalferov.ztlItalia&hl=en_US), [«ZTL» su App Store](https://apps.apple.com/us/app/ztl/id926415425), [Rick Steves: migliore app](https://community.ricksteves.com/travel-forum/italy/best-driving-app-to-avoid-ztl-zones), [travelinformation.eu](https://travelinformation.eu/italy/low-emission-zones/). Dati dei concorrenti presi dalle loro schede: possono essere cambiati.

**Cosa ci manca davvero rispetto a loro:** numero di città (il punto più grosso), parcheggi con prezzi e orari, Android, Android Auto / CarPlay.
**Cosa abbiamo solo noi:** fonti ufficiali con data, hotel sicuro, ticket, multe e diario, cartello con la fotocamera, guardiano nella Dynamic Island, tre lingue.

---

## 2. Cosa rende GateLR unica (la promessa)

1. **«Mai inventato»**: ogni risposta ha la fonte del Comune e la data; quando non sappiamo, lo diciamo.
2. **Dal piano alla multa**: prima del viaggio (hotel, ticket), durante (guardiano), dopo (diario, multa, ricorso). Nessun altro copre tutto.
3. **Per gli stranieri**: tre lingue subito, poi FR, ES, NL, PL; spiegazioni semplici, niente gergo.
4. **Funziona con il navigatore che già usi**: non chiede di cambiare abitudini.

---

## 3. Android: come lo facciamo

**Scelta:** app Android nativa (Kotlin + Jetpack Compose) che usa **gli stessi dati delle città** e **lo stesso motore delle regole**, riscritto in Kotlin e provato con gli stessi casi dei test iPhone.

| Requisito | Soluzione | Perché |
|---|---|---|
| Tutti i telefoni (Samsung, Xiaomi, Honor, Nothing, Oppo, Motorola, **Huawei senza Google**) | **Niente Google Play Services**: posizione con `LocationManager` di Android, mappe **MapLibre + OpenFreeMap**, ricerca indirizzi **Photon (OpenStreetMap)** | Huawei e alcuni telefoni non hanno i servizi Google |
| Android dalla versione 8 (2017) in su | `minSdk 26` | copre circa il 97% dei telefoni in uso |
| Guardiano accanto a Google Maps / Waze / Petal Maps | **servizio in primo piano** con notifica fissa (distanza dalla ZTL) + voce | non serve il permesso «posizione sempre», più facile da far approvare su Google Play |
| **Finestrella sopra Google Maps** (quello che volevi su iPhone!) | su Android si può: **bolla sovrapposta** («mostra sopra altre app») con la distanza e il colore della ZTL | iOS non lo permette, Android sì |
| Avvisi ad app chiusa (senza guardiano) | in un secondo momento: geofence di sistema dove ci sono i servizi Google, servizio leggero sugli altri | |
| Lingue | stessi testi dell'iPhone (IT, EN, DE), generati dallo stesso file | coerenza |
| Negozi | **Google Play**, **Huawei AppGallery**, **Samsung Galaxy Store**, **Xiaomi GetApps**, **Honor App Market**, **Amazon Appstore**, APK sul sito | |
| Android Auto | come CarPlay: categoria «navigazione/avvisi» con approvazione Google | più avanti |

**Costi:** Google Play 25 $ una volta sola; AppGallery, Galaxy Store, GetApps gratis.

---

## 4. Versioni (piccole, una alla volta)

Legenda: **F** = funzioni nuove, **R** = rifinitura (velocità, interfaccia UI, esperienza UX).

### iPhone

| Ver. | Tipo | Cosa | Diff. | Tempo |
|---|---|---|---|---|
| 1.9 | F | **Più città** (Lucca, Pisa, Siena, Roma, Torino, Napoli, Verona, Bergamo, Padova, Venezia-Mestre…), una per volta, con fonte | 🔴 | ½–1 per città |
| 1.10 | R | **Velocità**: avvio < 1 s, mappa a 60 fps su Milano (zone semplificate per livello di zoom), calcoli fuori dal thread principale, misure con Instruments | 🟡 | 1 |
| 1.11 | R | **UI**: sistema di design LR (spaziature, raggi, tipografia, icone personalizzate), animazioni di transizione, schermate vuote curate, iPad | 🟡 | 2 |
| 1.12 | R | **UX**: percorsi più corti (3 tocchi da apertura a «posso entrare?»), suggerimenti contestuali, prima apertura con richiesta della città, test con 5 persone vere | 🟡 | 1–2 |
| 1.13 | F | **Parcheggi veri**: prezzi, orari, posti, garage convenzionati (Area C 4,50 €), prenotazione dove possibile | 🔴 | 2 + accordi |
| 1.14 | F | **Lingue**: francese, spagnolo, olandese, polacco, cinese | 🟢 | 1 |
| 1.15 | F | **Siri e Comandi rapidi**: «Posso entrare in centro a Firenze?»; widget interattivi; Apple Watch (avviso al polso) | 🟡 | 2 |
| 2.0 | F | **Pubblicazione**: Apple Developer, account (Accedi con Apple), sincronizzazione iCloud, abbonamento, CarPlay, TestFlight, App Store | 🟡 | 2–3 + attese |

### Android

| Ver. | Tipo | Cosa | Diff. | Tempo |
|---|---|---|---|---|
| A0.1 | F | **Motore e dati** in Kotlin con test (stessi casi dell'iPhone) | 🟡 | 1 |
| A0.2 | F | **App base**: 5 schede, prima pagina, città e zone con risposta, scheda zona con fonti | 🟡 | 1–2 |
| A0.3 | F | **Mappa** MapLibre con zone colorate, ricerca indirizzi, spillo con risposta | 🟡 | 1 |
| A0.4 | F | **Viaggio**: risposta all'arrivo, hotel sicuro, messaggio, ticket, viaggi salvati | 🟡 | 1 |
| A0.5 | F | **Guardiano**: servizio in primo piano, notifica fissa, voce, **bolla sopra Google Maps**, Google Maps / Waze / Petal Maps | 🔴 | 2 |
| A0.6 | F | Garage, Account, diario, guida multe, «Leggi il cartello» (ML Kit su telefoni Google, testo manuale sugli altri) | 🟡 | 1–2 |
| A0.7 | R | Prove su tanti telefoni (Firebase Test Lab o telefoni reali), risparmio batteria dei produttori (Xiaomi, Huawei, Samsung chiudono le app in sottofondo: guida passo-passo) | 🔴 | 1–2 |
| A1.0 | F | Pubblicazione su Google Play, AppGallery, Galaxy Store, GetApps, Honor, Amazon | 🟡 | 1 + attese |

### Sito (per gli stranieri, con dominio proprio)

| Ver. | Tipo | Cosa | Diff. | Tempo |
|---|---|---|---|---|
| W1 | R | Stessi colori e tipi di zona dell'app, aree pedonali, ticket, hotel sicuro, guida multe, pulsanti App Store / Google Play | 🟢 | 1 |
| W2 | R | **SEO**: una pagina per città e per lingua (`/en/florence-ztl`), dati strutturati, velocità (Lighthouse 95+), condivisione | 🟡 | 1 |
| W3 | F | Dominio (es. `gatelr.app`), privacy, cookie zero, pubblicazione | 🟢 | ½ |
| W4 | F | Pagina per hotel e noleggi: link da mandare ai clienti con la risposta già pronta per il loro indirizzo | 🟡 | 1 |

---

## 5. Cosa manca ancora (lista onesta)

- **Città**: è il limite più grande. Senza Roma, Pisa, Siena, Lucca, Napoli, Torino l'app è utile solo a una parte dei turisti.
- **Parcheggi con prezzo**: i turisti vogliono sapere «dove lascio l'auto e quanto pago».
- **Verifica umana dei dati**: le città sono «bozza» finché qualcuno non controlla (lista pronta in `docs/verifica-*.md`).
- **Prova sul campo**: guardiano e avvisi vanno provati in auto, in città vere.
- **Android**: metà dei telefoni in Italia (e la maggioranza dei turisti da molti Paesi) usa Android.
- **Accessibilità completa**: VoiceOver/TalkBack su tutte le schermate, contrasto, testo grande (iniziato).
- **Privacy**: tutto resta sul telefono; da scrivere chiaramente nella scheda dei negozi.

---

## 6. Collaborazioni possibili

| Con chi | Cosa ci guadagnano | Cosa ci guadagniamo |
|---|---|---|
| **Noleggi auto** (Hertz, Europcar, Sixt, Avis, Locauto, Maggiore, DiscoverCars, Rentalcars) | meno multe da gestire e meno clienti arrabbiati | GateLR consigliata al ritiro dell'auto, QR code sul cruscotto |
| **Hotel dentro le ZTL** e associazioni (Federalberghi, Booking, Airbnb host) | meno telefonate e reclami, registrazione targa ordinata | link «come arrivare in auto» con GateLR; in futuro registrazione targa direttamente dall'app |
| **Comuni** e aziende di mobilità (SAS Firenze, TPER/Bologna, AMAT/Milano, Pisamo, Roma Servizi per la Mobilità) | meno multe contestate ai turisti, immagine migliore | dati ufficiali aggiornati in automatico (API), bollino «fonte verificata» |
| **Parcheggi** (Saba, Interparking, EasyPark, Telepass, MyCicero) | clienti in più | prezzi e posti nell'app, pagamento della sosta |
| **Enti del turismo** (ENIT, regioni, uffici turistici) | turisti più sereni | GateLR nelle guide ufficiali |
| **Assicurazioni e ACI**, club auto stranieri (ADAC, ANWB, AA, TCS) | servizio ai soci in viaggio | distribuzione verso milioni di automobilisti europei |
| **Navigatori** (Waze, TomTom, HERE, Petal Maps) | dati ZTL affidabili | licenza dei dati come fonte di entrate |

---

## 7. I sogni (top di gamma)

1. **Registrazione della targa dall'app**: l'hotel o il Comune ricevono la targa con un tocco, e arriva la conferma ufficiale. Nessuna multa per i turisti con hotel in centro.
2. **Pagare tutto in un posto**: ticket Area C, ticket di Bologna, sosta, permessi giornalieri, con Apple Pay / Google Pay.
3. **Tutta Italia, sempre aggiornata**: 400+ città con orari ufficiali, aggiornati ogni giorno dalle pagine dei Comuni (il controllo automatico c'è già).
4. **Percorsi che evitano le ZTL attive** con un motore di navigazione nostro (GraphHopper o OSRM): «portami all'hotel senza passare dai varchi».
5. **Europa**: zone a basse emissioni di Francia (Crit'Air), Germania (Umweltzone), Spagna (ZBE), Londra (ULEZ), Belgio, Olanda: la stessa promessa, un'app per tutto il continente.
6. **CarPlay, Android Auto e auto connesse**: avviso sul cruscotto, anche nelle auto con Android Automotive (Volvo, Polestar, Renault).
7. **Assistente vocale**: «Ehi Siri, posso entrare a Siena adesso?».
8. **Statistiche anonime per i Comuni**: dove i turisti sbagliano di più, per migliorare la segnaletica (solo con consenso, mai la targa).

---

## 8. Ordine consigliato

1. iPhone 1.10–1.12 (velocità, UI, UX) **insieme** ad Android A0.1–A0.3
2. Città (1.9), una per settimana, in parallelo
3. Android A0.4–A0.7
4. Sito W1–W3
5. Pubblicazione (2.0 e A1.0)
6. Parcheggi (1.13), lingue (1.14), Siri e Watch (1.15)
7. Sogni, uno alla volta
