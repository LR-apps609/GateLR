# GateLR – Roadmap «perfezionare l'app» (dal 23 ottobre 2026)

Sito, monetizzazione e pubblicazione vengono dopo. Prima l'app.
Difficoltà: 🟢 facile · 🟡 media · 🔴 difficile. Tempi in **sessioni di lavoro** come quella di oggi.

## Fase 1 – Base solida (1–2 sessioni)

| # | Cosa | Diff. | Note oneste |
|---|---|---|---|
| 1.1 | **Lingua coerente**: tutto italiano (o inglese/tedesco) senza misto. Nomi delle zone, riassunti e fonti tradotti; scelta della lingua dentro l'app | 🟢 | Oggi il misto nasce dai dati delle città (in inglese) e da testi non ancora tradotti |
| 1.2 | **Nuova prima pagina** con nuovo nome: scegli città → (facoltativo) indirizzo. Solo città = panoramica; indirizzo = risposta precisa per quel punto. Niente «puoi entrare» a caso | 🟡 | Ricerca indirizzi con Apple (gratis). Pagina più vuota e pulita |
| 1.3 | **Viaggio**: indirizzo dell'hotel → l'app capisce da sola se è in ZTL e in quale settore. Viaggi salvati (hotel, date, auto) | 🟢 | |
| 1.4 | **Quinta scheda «Account»** (prima versione senza login): impostazioni, lingua, avvisi, città offline, sezione abbonamento (solo grafica), info e fonti | 🟢 | Il login vero è nella fase 5 |

## Fase 2 – Mappa (2 sessioni)

| # | Cosa | Diff. | Note oneste |
|---|---|---|---|
| 2.1 | **Colori per tipo di zona**: rosso «Accesso vietato», giallo «Pass necessario», verde «Zona verde» (accesso per categorie di veicoli) | 🟢 | Va aggiunto il «tipo» a ogni zona nei dati |
| 2.2 | **Scritte grandi** («Accesso vietato», «Pass necessario», «Zona verde») visibili da lontano, che svaniscono avvicinandosi | 🟢 | Si legge lo zoom della mappa e si regola la trasparenza |
| 2.3 | **Stili**: standard, satellite, ibrida, 3D con edifici | 🟢 | Tutto incluso nelle mappe Apple |
| 2.4 | **Vista a livello strada** (Look Around di Apple) dove disponibile | 🟡 | Copre le grandi città italiane, non tutte |
| 2.5 | **Ricalcolo preciso dei perimetri**: meno semplificazione, settori annidati corretti, varchi con direzione, zone pedonali e corsie bus | 🟡 | Lavoro sui dati città per città |
| 2.6 | «Live view» in realtà aumentata stile Google | 🔴 | Le API di Apple non la offrono in Italia; sconsigliata ora |

## Fase 3 – Navigazione (2–3 sessioni)

| # | Cosa | Diff. | Note oneste |
|---|---|---|---|
| 3.1 | **Destinazione → percorso** sulla mappa, con tempo e distanza | 🟡 | Percorsi Apple (gratis) |
| 3.2 | **Controllo ZTL del percorso**: se la destinazione o il tragitto entra in una ZTL attiva all'ora di arrivo → avviso, alternativa «parcheggia fuori + a piedi», messaggio all'hotel | 🟡 | È il vero valore di GateLR |
| 3.3 | **Guida passo-passo nell'app** con istruzioni vocali e avvisi ai varchi | 🔴 | Fattibile in versione base; le mappe Apple non sanno «evitare» una zona, quindi niente ricalcolo automatico che aggira la ZTL |
| 3.4 | Percorsi che **evitano** la ZTL | 🔴 | Serve un motore esterno (GraphHopper o Mapbox), a pagamento oltre una soglia |
| 3.5 | Alternativa consigliata subito: **«Apri in Apple Mappe / Google Maps / Waze»** con il punto di parcheggio fuori ZTL come destinazione, mentre GateLR fa da «guardiano» con gli avvisi | 🟢 | |

## Fase 4 – Garage (1–2 sessioni)

| # | Cosa | Diff. | Note oneste |
|---|---|---|---|
| 4.1 | **Marca e modello da elenco**, con anno, carburante e classe Euro proposta | 🟡 | La lista di AutoScout24 non è pubblica né libera: uso un elenco aperto di marche e modelli |
| 4.2 | **Raccomandazioni per la tua auto** (es. «Area B: la tua diesel Euro 4 non può entrare dal…», «elettrica: contrassegno gratuito a Bologna») | 🟡 | Servono le regole per classe Euro nei dati delle città |
| 4.3 | **Dalla targa ai dati dell'auto** | 🔴 | Solo con servizi a pagamento per singola ricerca (targhe italiane), privacy (GDPR) da gestire; per targhe estere e noleggi quasi impossibile. Rimandata |

## Fase 5 – Account e guida ZTL (2 sessioni)

| # | Cosa | Diff. | Note oneste |
|---|---|---|---|
| 5.1 | **Impara la ZTL**: cos'è, i cartelli (disegnati da noi), il pannello «Varco attivo / non attivo», cosa fare se entri per sbaglio | 🟢 | Disegni vettoriali nostri: niente problemi di diritti |
| 5.2 | **Account vero** (Accedi con Apple) + sincronizzazione tra dispositivi (iCloud) | 🟡 | Richiede l'Apple Developer Program a pagamento |
| 5.3 | **Abbonamento** (StoreKit) | 🟡 | Richiede l'Apple Developer Program; si decide il prezzo più avanti |

## Ordine consigliato

1. Fase 1 (base, lingua, prima pagina, viaggio, Account)
2. Fase 2 (mappa: colori, scritte, stili, perimetri)
3. Fase 3.1, 3.2, 3.5 (percorso + controllo ZTL + passaggio al navigatore)
4. Fase 4.1–4.2 (garage)
5. Fase 5.1 (impara la ZTL)
6. Dopo l'Apple Developer Program: 5.2, 5.3, poi 3.3
7. Molto più avanti, se serve: 3.4, 4.3, 2.6

Tempo totale stimato per le fasi 1–5 senza parti a pagamento: **8–11 sessioni**.

---

## Decisione: la prima pagina si chiama «Varco» (EN «Gate», DE «Einfahrt»)

## Cose difficili ma fattibili

| Cosa | Come | Tempo | Costo |
|---|---|---|---|
| Guida passo-passo con voce nell'app | Percorso Apple + istruzioni lette dal telefono + ricalcolo se esci dal percorso | 2–3 sessioni | gratis |
| Percorsi che evitano la ZTL | Motore GraphHopper (aree vietate) su un piccolo server o via API | 2 sessioni | API: piano gratuito limitato, poi a pagamento |
| Avvisi affidabili ad app chiusa oltre il limite di 20 varchi | Ricarica dei varchi più vicini mentre ti sposti (cambio di zona significativo) | 1 sessione | gratis |
| Aggiornamento dei dati senza nuova versione dell'app | File delle città scaricati da GitHub, firmati e con data | 1 sessione | gratis |
| Controllo automatico delle pagine dei Comuni | Workflow giornaliero che segnala le pagine cambiate | 1 sessione | gratis |
| Live Activity / Dynamic Island durante il viaggio | «Varco tra 400 m · acceso» sulla schermata di blocco | 1–2 sessioni | gratis |
| CarPlay | Codice pronto; serve l'autorizzazione di Apple | 1 sessione + attesa Apple | Developer Program |
| Account e sincronizzazione | Accedi con Apple + iCloud | 1–2 sessioni | Developer Program |
| Abbonamento / Pass viaggio | StoreKit 2 | 1–2 sessioni | Developer Program |
