# GateLR – ZTL Italy

**Know before the gate.** Ogni ZTL d'Italia spiegata in modo chiaro, nella lingua di chi guida, con il link alla pagina ufficiale del Comune che lo dimostra. App per iPhone (SwiftUI, iOS 17 o successivo), in inglese.

> ⚠️ Versione 0.3: Firenze, Bologna e Milano (Area C) sono prese dai dati aperti e dalle pagine ufficiali dei Comuni, ma sono ancora **bozze** non riviste da una persona. L'app lo scrive in chiaro e mostra cosa resta da verificare.

Riepilogo completo: [`docs/STATO.md`](docs/STATO.md).

## Come è fatto

| File | Cosa fa |
|---|---|
| `Sources/Models.swift` | Città, zone, varchi, fasce orarie, fonte ufficiale, veicoli, permessi |
| `Sources/RuleEngine.swift` | «Posso entrare?»: sì / no / con condizioni / non sicuro; orari anche notturni e stagionali, festività italiane, prossimo cambio di stato |
| `Sources/Store.swift` | Stato dell'app; il garage resta salvato sul telefono |
| `Sources/NowView.swift` | Scheda **Now**: la risposta adesso, il veicolo, i varchi vicini |
| `Sources/MapScreen.swift` | Scheda **Map**: perimetro ZTL, varchi accesi/spenti, hotel |
| `Sources/ZoneDetailView.swift` | Scheda zona: riassunto, orari, frase del Comune, fonte, data del controllo |
| `Sources/TripView.swift` | Scheda **Trip**: risposta per l'ora di arrivo, messaggio per l'hotel (EN/IT/DE) |
| `Sources/GarageView.swift` | Scheda **Garage**: veicoli, permessi, città offline |
| `Sources/GateMonitor.swift` | Avvisi vicino ai varchi anche ad app chiusa (CLMonitor) |
| `Sources/CarPlaySceneDelegate.swift` | Schermata CarPlay (serve l'autorizzazione Apple «Driving Task») |
| `Sources/Theme.swift`, `Components.swift` | Colori della segnaletica, logo, riquadro della risposta |
| `Tests/RuleEngineTests.swift` | Test del motore delle regole |
| `Tools/make_icon.py` | Ridisegna l'icona (Pillow) |
| `Tools/build_firenze.py` | Scarica i dati aperti di Firenze e costruisce `Resources/Cities/firenze.json` |
| `Tools/build_cities.py` | Costruisce Bologna e Milano da `data/raw/` |
| `Tools/translations.py` | Traduzioni italiano e tedesco dell'app |
| `Tools/build_site.py` | Costruisce il sito `web/index.html` con tutte le città |
| `Widget/` | Widget per Home e schermata di blocco |
| `web/` | Il sito (vedi `web/README.md`) |
| `Resources/Fonts` | Titillium Web (SIL Open Font License) |
| `docs/ricerca-citta.md` | Ricerca sulle fonti ufficiali delle prime città |

## Compilazione e prove

- **Ogni modifica** → workflow «Compila GateLR» sul Mac di GitHub: genera il progetto con XcodeGen, compila per il simulatore iPhone ed esegue i test.
- **Foto dell'app** → lo stesso workflow fa il giro delle schermate nel simulatore e pubblica le foto nel ramo `screenshots`.
- **Sul tuo iPhone**: doppio clic su `Installa su iPhone.command`; poi in Xcode scegli il tuo Apple ID in *Signing & Capabilities* e premi ▶︎ con l'iPhone collegato.

## Percorso

1. **Bozza** (0.1): quattro schede, motore delle regole, avvisi, CarPlay di base
2. **Prime città vere**: Firenze (0.2, bozza da rivedere) ← *siamo qui*; poi Roma, Bologna, Milano, Verona, con verifica umana
3. **Offline e aggiornamenti**: città scaricabili, controllo automatico delle pagine comunali
4. **CarPlay e App Store**: richiesta dell'autorizzazione CarPlay, Pass viaggio, lingue
5. **Sito** per la pubblicazione
