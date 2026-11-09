# RispostaFinale · specifica del motore (2.1 «Una risposta, sette stati»)

Una sola risposta per «posso entrare qui, a quell'ora, con questo veicolo?», uguale su ogni superficie (Varco/Adesso,
mappa, widget, Live Activity, notifiche e avvisi in auto, Siri, CarPlay, Android, sito). Le tre implementazioni:

| Dove | File |
|---|---|
| iPhone | `Sources/RispostaFinale.swift` (stato, motivo, parola, forma, tono), colori in `Sources/Theme.swift` |
| Android | `android/core/src/main/kotlin/app/gatelr/core/RispostaFinale.kt` |
| Sito | `finale()`, `TONO`, `STATE_OFF` in `web/template.html`; la presentazione (`rispostaFinale()`, `showFinal`, CSS `--state-off`) usa nomi brevi: no, condizione, si, nonAttiva, nonSicuro, fuoriCopertura, fuoriZTL |

I casi di prova comuni (il «vectors.json» delle tavole PL-Prove) sono `shared/engine-cases.json`: ogni caso dice `stato`
(e `motivo` se serve). Li eseguono `Tests/SharedEngineCasesTests.swift` (XCTest, CI «Compila GateLR»),
`android/core/src/test/.../SharedEngineCasesTest.kt` (JUnit, CI «Android») e `Tools/check_engine_cases.mjs` (node).

## Ingressi

1. **Posto**: le zone che lo contengono (tutte, dalla più piccola), l'area pedonale che lo contiene, la copertura
   (`City.covers`: entro 2 km dal riquadro di zone e aree pedonali di una delle città che conosciamo).
2. **Ora**: l'istante scelto (adesso, o l'ora d'arrivo), in ora italiana.
3. **Veicolo**: tipo, alimentazione, classe Euro.
4. **Permessi**: solo quelli della città e della zona, con lo stato (confermato, in attesa).
5. **Qualità della fonte**: fonte ufficiale o no; letto il / verificato il (120 giorni); pagina del Comune cambiata;
   città di esempio.

Per ogni zona il motore delle regole (`RuleEngine.trustedAnswer` / `answer()` del sito) dà una risposta:
`sì | no | condizione | non sicuro`, lo stato dei varchi (`gatesOn`), il prossimo cambio e, da 2.1, il **motivo del
dubbio** (`doubt`) quando la risposta è «non sicuro»:

| Dove nasce il «non sicuro» | `doubt` |
|---|---|
| dati letti/verificati più di 120 giorni fa | `scaduti` |
| festivo dove il Comune non dice se i varchi sono spenti (`freeOnHolidays` assente) | `festivo` |
| giorno in cui la fonte ufficiale non dice se la ZTL è attiva (`uncertainDays` della città, "MM-DD": Firenze e Torino 06-24, Milano 12-07; non sono `localHolidays`) | `festivo` |
| pagina del Comune cambiata dopo la lettura o la verifica | `scaduti` |
| zona ufficiale non verificata o con verifica vecchia (rete di sicurezza della regola A) | `scaduti` |

Decide la zona con la risposta **peggiore** come si mostra (no > condizione > non sicuro > sì; un «sì» da fonte non
ufficiale conta come «non sicuro»); a parità di gravità non verde quella con i varchi accesi (B36), poi la più piccola.

Regole comuni del motore (stesse su iPhone, Android e sito):
- festivi nazionali: 1/1, 6/1, Pasquetta, 25/4, 1/5, 2/6, 15/8, **4/10 dal 2026** (L. 151/2025), 1/11, 8/12, 25/12, 26/12;
- i giorni dall'ultima lettura o verifica si contano a **blocchi di 24 ore** (B33);
- la distanza da una zona si misura dal **lato** più vicino, non dal vertice (B09).

## Gli stati, in quest'ordine

1. Area pedonale → **nonEntrare** (vince su tutto, a ogni ora).
2. Nessuna zona: in una città coperta → **fuoriZTL**; se le città che coprono il posto hanno le zone tutte da fonti non
   ufficiali (anche il confine viene da lì) → **controllaCartello** (`nonUfficiale`, B22); altrimenti → **nonCoperto**.
3. La zona che decide:
   - `no` → **nonEntrare**. Anche da fonte non ufficiale: regola di Ledion «Salerno resta rossa». La fonte non ufficiale
     va nella riga sotto («Probabilmente no · fonte non ufficiale»), il titolo resta «Non entrare».
   - `condizione` → **condizione** (ticket, hotel, permesso in attesa, zona verde senza classe nota). I ticket e gli
     hotel confermati restano qui: mai verde da un tocco.
   - `non sicuro` → **controllaCartello**, motivo = `doubt`, altrimenti `nonUfficiale` se la fonte non è ufficiale,
     altrimenti `nonSicuro`.
   - `sì` da fonte non ufficiale → **controllaCartello** (`nonUfficiale`).
   - `sì` in una città di esempio (solo app, modalità prova) → **controllaCartello** (`nonSicuro`).
   - `sì` a varchi accesi → **entraPure** (esente, permesso confermato, classe ammessa).
   - `sì` a varchi spenti → **ztlNonAttiva**.

`euroSconosciuto` è riservato al veicolo «Non so» (decisione 8, arriva con la presentazione e il veicolo della 2.2):
dove contano i divieti Euro la risposta sarà **controllaCartello** (`euroSconosciuto`). Oggi nessun veicolo lo produce.

## Parola, forma, colore (mai solo colore)

| Stato | Parola (chiave inglese di `Tools/translations.py`) | Forma | Tono |
|---|---|---|---|
| nonEntrare | «Don't enter» · Non entrare | disco con barra (`xmark` nel cerchio) | rosso |
| condizione | «On one condition» · A una condizione | rombo con «!» (`exclamationmark`) | giallo |
| entraPure | «You can enter» · Puoi entrare | spunta (`checkmark`) | verde |
| ztlNonAttiva | «ZTL not active» · ZTL non attiva | cerchio con linea (`minus`) | **spento** = token unico, oggi verde |
| controllaCartello | «Check the sign» · Controlla il cartello | rombo con «?» (`questionmark`) | giallo |
| nonCoperto | «We don't know this place» · Non conosciamo questo posto | «?» nel cerchio tratteggiato | neutro, contorno tratteggiato |
| fuoriZTL | «Outside the ZTL» · Fuori dalla ZTL | spillo (`mappin.and.ellipse`) | grigio |

- Il colore della «ZTL non attiva» è UN SOLO token (`Theme.stateOff`, `RispostaFinale.STATE_OFF`, `STATE_OFF`): oggi
  verde per regola di Ledion; la bozza proponeva grigio. Il cambio sta in una riga per piattaforma.
- Mai verde per: fuori copertura, fonte non ufficiale, dati scaduti, cartello letto da foto, condizioni segnate a mano.
- Il motivo del giallo va nella riga sotto, mai nel titolo: «Non sicuro», «Dati scaduti», «Fonte non ufficiale»,
  «Festivo da confermare», «Classe Euro da sapere».
- Il pannello LED dice lo stato dei varchi dal motore («ZTL ATTIVA / ZTL NON ATTIVA»), mai la risposta.

## Avvisi in auto (un solo valutatore)

`ThreatEvaluator` (iPhone) e `ThreatScan` (Android) per guida, guardiano e avvisi ad app chiusa:

- candidati: zone **e** aree pedonali entro 3 km;
- dentro una zona dove non si entra liberamente la minaccia resta, a 0 m, finché ci sei (B10): «Sei dentro … · Non entrare»;
  a riposo grigio in una città coperta, neutro fuori copertura, mai verde;
- risposta all'**istante d'arrivo** stimato (velocità vera sopra 3 m/s, altrimenti 9 m/s);
- solo **davanti** nel verso di marcia (±70°; senza direzione: se ti avvicini, o prudente);
- distanza d'avviso: **300 m, 600 m sopra 50 km/h** (`ThreatEvaluator.alertDistance(speed:)`);
- avvisa solo per `nonEntrare`, `condizione`, `controllaCartello` (mai un avviso verde, né per ZTL non attiva);
- **un solo avviso** per avvicinamento (`ThreatDeduper`: di nuovo oltre 900 m o dopo 30 minuti);
- titolo «<parola della RispostaFinale> · <zona>», tocco che apre «Parcheggia fuori» (`gatelr://park?…`).
