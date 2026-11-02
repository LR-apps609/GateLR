# GateLR sull'App Store: scheda pronta (bozza)

Da incollare in App Store Connect quando avremo l'Apple Developer Program. Limiti di Apple tra parentesi.

## Identità

| Campo | Testo | Caratteri |
|---|---|---|
| Nome (30) | GateLR – ZTL Italy | 18 |
| Sottotitolo (30) | Know before the gate | 20 |
| Categoria | Navigazione · secondaria: Viaggi | |
| Età | 4+ | |
| Prezzo | Gratis con acquisti in app (Pass viaggio) — da decidere | |

## Testo promozionale (170)

**EN**: Driving to Florence? GateLR tells you if you can enter the ZTL right now or when you arrive, with the city's official source for every rule.

**IT**: Vai a Firenze in auto? GateLR ti dice se puoi entrare nella ZTL adesso o quando arrivi, con la fonte ufficiale del Comune per ogni regola.

**DE**: Mit dem Auto nach Florenz? GateLR sagt dir, ob du jetzt oder bei deiner Ankunft in die ZTL darfst – mit der offiziellen Quelle der Stadt zu jeder Regel.

## Descrizione (4000)

### English
Italy's historic centres are protected by camera gates. Drive through one at the wrong time and a fine reaches you months later, often with a rental-company fee on top.

GateLR gives you one clear answer:
• Yes, you can enter
• No, don't enter
• Yes, on one condition (for example, your hotel registers your plate)
• Not sure — and then we show you the official source

WHAT YOU GET
• Gate: the ZTL near you and the answer right now, the cities with their active zones
• Trip: search your hotel or destination for the answer when you arrive, the ZTLs on your route, the day ticket with a reminder (Milan Area C, Bologna), and a ready-made message asking your hotel to register your plate for every day, in English, Italian or German
• Guardian: start Google Maps, Apple Maps or Waze from GateLR and get warned before every active ZTL, also in the Dynamic Island and on the lock screen
• GateLR navigation: turn-by-turn voice directions with the next ZTL always in view
• Map: every ZTL coloured by type (no entry, pass needed, green zone), pedestrian areas, bus-lane cameras, search your hotel and see if you can drive there
• Read the sign: point the camera at the hours panel and GateLR explains it in your language
• Garage: make, model and Euro class, with advice for low-emission zones like Milan's Area B
• Got a fine? What to expect, how to pay from abroad, how to appeal, and a drive log of the active gates you passed

EVERY RULE HAS ITS SOURCE
Each answer links to the city's official page or ordinance, with the date we read it. Cities still being reviewed are clearly marked as Draft. Road signs on site always win over the app.

Cities: Florence first, more coming.
GateLR is not affiliated with any city or with the police.

### Italiano
I centri storici italiani sono protetti da varchi con telecamere. Passarci all'ora sbagliata significa una multa che arriva mesi dopo, spesso con la commissione del noleggio in più.

GateLR ti dà una risposta chiara:
• Sì, puoi entrare
• No, non entrare
• Sì, a una condizione (per esempio, l'hotel comunica la tua targa)
• Non sicuro — e allora ti mostriamo la fonte ufficiale

COSA TROVI
• Adesso: la risposta per la tua auto, ora, con il conto alla rovescia fino a quando i varchi si accendono o si spengono
• Viaggio: la risposta per il giorno e l'ora del tuo arrivo, e il messaggio pronto per chiedere all'hotel di comunicare la targa, in italiano, inglese o tedesco
• Mappa: tutti i settori ZTL e i varchi, e i parcheggi appena fuori dalla zona con le indicazioni
• Avvisi prima di un varco acceso, anche ad app chiusa
• Garage: auto e permessi in un posto solo

OGNI REGOLA HA LA SUA FONTE
Ogni risposta porta alla pagina ufficiale o all'ordinanza del Comune, con la data in cui l'abbiamo letta. Le città ancora in revisione sono segnate come Bozza. Vale sempre la segnaletica sul posto.

Città: prima Firenze, poi le altre.
GateLR non è collegata ad alcun Comune né alla polizia.

### Deutsch
Italiens Altstädte sind durch Kamera-Einfahrten geschützt. Wer zur falschen Zeit durchfährt, bekommt Monate später ein Bußgeld – oft mit einer Gebühr der Mietwagenfirma obendrauf.

GateLR gibt dir eine klare Antwort:
• Ja, du darfst rein
• Nein, nicht hineinfahren
• Ja, unter einer Bedingung (zum Beispiel meldet dein Hotel dein Kennzeichen an)
• Nicht sicher – dann zeigen wir dir die offizielle Quelle

DAS BEKOMMST DU
• Jetzt: die Antwort für dein Auto, sofort, mit Countdown bis die Kameras an- oder ausgehen
• Reise: die Antwort für Tag und Uhrzeit deiner Ankunft und eine fertige Nachricht an dein Hotel, auf Deutsch, Englisch oder Italienisch
• Karte: alle ZTL-Sektoren und Kamera-Einfahrten, dazu Parkplätze direkt außerhalb der Zone mit Route
• Warnungen vor einer aktiven Einfahrt, auch wenn die App geschlossen ist
• Garage: deine Autos und Genehmigungen an einem Ort

JEDE REGEL HAT IHRE QUELLE
Jede Antwort verlinkt die offizielle Seite oder Verordnung der Stadt, mit dem Datum, an dem wir sie gelesen haben. Städte in Prüfung sind als Entwurf markiert. Es gelten immer die Schilder vor Ort.

Städte: zuerst Florenz, weitere folgen.
GateLR ist mit keiner Stadt und nicht mit der Polizei verbunden.

## Parole chiave (100)

- **EN**: ztl,italy,florence,firenze,traffic zone,fine,rental car,driving,gate,camera,hotel,parking,tuscany
- **IT**: ztl,firenze,varchi,multa,zona traffico limitato,telecamere,permessi,hotel,parcheggio,toscana
- **DE**: ztl,italien,florenz,bußgeld,verkehrszone,mietwagen,kamera,hotel,parken,toskana,urlaub

## Privacy (etichette dell'App Store)

1.19.4 «Privacy onesta», controllato sulle richieste in rete del codice (`URLSession`, MapKit, Mapbox):

- **Etichetta**: «Dati non raccolti» per GateLR. Garage (auto, targhe, permessi), viaggi e diario restano sull'iPhone; la
  posizione è usata sull'iPhone (risposta, avvisi, guardiano).
- **Cosa esce, senza dati dell'utente verso di noi**: Apple MapKit (mappa, ricerca, percorsi: testo cercato, partenza e
  arrivo); Mapbox (mappe 3D con il token: richieste delle mattonelle e il conteggio d'uso per la fatturazione; telemetria
  spenta di serie con `MGLMapboxMetricsEnabled`, si accende in Tu → Privacy o dalla (i) della mappa); GitHub
  (`raw.githubusercontent.com`, dati delle città); Overpass/OpenStreetMap (parcheggi: il rettangolo delle zone della città,
  solo se mancano nell'app).
- **Manifesti**: `Privacy/App/PrivacyInfo.xcprivacy` e `Privacy/Widget/PrivacyInfo.xcprivacy` (tracciamento no, dati
  raccolti nessuno; UserDefaults CA92.1 e 1C8F.1 per l'App Group, data dei file C617.1 per i parcheggi salvati, tempo
  dall'accensione 35F9.1 per CACurrentMediaTime). Mapbox Maps ha il suo manifesto (posizione e identificativo per la sua
  telemetria e l'analisi): Xcode lo unisce nel rapporto della privacy; nell'etichetta dell'App Store va considerato quello
  che dichiara Mapbox. Con la telemetria spenta Mapbox riceve comunque le richieste della mappa e il conteggio d'uso:
  rileggere la guida di Mapbox per l'App Store al momento dell'invio.
- **Segnalazioni** (errore di una zona, bug): partono dall'app Mail dell'utente solo se le scrive e le invia lui, verso
  l'indirizzo del supporto (`AppConfig.supportEmail`, ancora un segnaposto). Raccolta facoltativa e rara: secondo le regole
  Apple non va dichiarata, ma è scritta nella privacy policy.
- **Targa**: mai nei testi condivisi, nelle copie, nel widget (né nell'App Group), in Siri, nelle notifiche o nella Live
  Activity (`Sources/PlatePrivacy.swift`); unica eccezione il messaggio per l'hotel.
- Nessun account, nessun tracciamento, nessuna pubblicità. Privacy policy: https://lr-apps609.github.io/GateLR/privacy/

## Schermate richieste

iPhone 6,9" (1320 × 2868) e 6,5" (1284 × 2778). Le foto del ramo `screenshots` sono a 1206 × 2622 (iPhone 16 Pro): per l'App Store le rifaremo con il simulatore giusto e con testi sopra ogni foto:
1. «Can I drive in? One clear answer.» (Now)
2. «Every rule has its official source.» (scheda zona)
3. «Arriving later? Check your time.» (Trip)
4. «Every sector and gate on the map.» (Map)
5. «Alerts before the gate, app closed.» (avviso)

## Da preparare prima dell'invio

- [ ] Apple Developer Program (99 USD/anno)
- [ ] Città «verified» (almeno Firenze) — vedi `docs/verifica-firenze.md`
- [x] Privacy policy e pagina di supporto sul sito (privacy riscritta nella 1.19.4)
- [ ] Richiesta CarPlay «Driving Task» (dopo la prima pubblicazione)
- [ ] Decidere il prezzo (Pass viaggio 7/30 giorni?)
