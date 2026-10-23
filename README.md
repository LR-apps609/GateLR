# GateLR – ZTL Italy

**Know before the gate.** Ogni ZTL d'Italia spiegata in modo chiaro, nella lingua di chi guida, con il link alla pagina ufficiale del Comune che lo dimostra. App per iPhone (SwiftUI, iOS 17 o successivo), in inglese.

> ⚠️ Versione 0.1: i dati di Firenze dentro l'app sono **di esempio**, non verificati. L'app lo scrive in chiaro.

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
| `docs/ricerca-citta.md` | Ricerca sulle fonti ufficiali delle prime città |

## Compilazione e prove

- **Ogni modifica** → workflow «Compila GateLR» sul Mac di GitHub: genera il progetto con XcodeGen, compila per il simulatore iPhone ed esegue i test.
- **Sul tuo iPhone**: `brew install xcodegen`, poi `xcodegen generate` nella cartella, apri `GateLR.xcodeproj`, scegli il tuo Apple ID in *Signing & Capabilities* e premi ▶︎ con l'iPhone collegato.

## Percorso

1. **Bozza** (0.1): quattro schede, motore delle regole, avvisi, CarPlay di base ← *siamo qui*
2. **Prime città vere**: Firenze, Roma, Bologna, Milano, Verona dai dati aperti ufficiali, con verifica umana
3. **Offline e aggiornamenti**: città scaricabili, controllo automatico delle pagine comunali
4. **CarPlay e App Store**: richiesta dell'autorizzazione CarPlay, Pass viaggio, lingue
5. **Sito** per la pubblicazione
