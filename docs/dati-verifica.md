# Dati: letto il, verificato il, pagine cambiate, firma (1.20.1)

## Le due date di ogni zona

Nei file delle città (`Resources/Cities/<città>.json`), in `zones[].source`:

| Campo | Cosa vuol dire | Chi lo scrive |
|---|---|---|
| `checkedOn` | **Letto il**: quando abbiamo letto le pagine da cui vengono le regole | gli script `Tools/build_*.py` (c'era già) |
| `verifiedOn` | **Verificato il**: quando una persona (o un controllo) ha confermato la regola. Assente = non lo sappiamo = **non verificata** | solo `python3 Tools/source_trust.py verify <città> [zona…]`, dopo una verifica vera |
| `verifiedFingerprints` | le impronte delle pagine ufficiali della zona al momento della verifica | `source_trust.py verify` (da `data/source-hashes.json`) |
| `readFingerprints`, `readFingerprintsOf` | le impronte delle stesse pagine al momento della lettura, e il `checkedOn` a cui si riferiscono: la prima registrazione del controllo giornaliero dal giorno della lettura in poi (storia git di `data/source-hashes.json`, che comincia il 24 ottobre 2026: per le letture del 23 vale quella del 24) | `source_trust.py mark` (di nuovo da sé quando `checkedOn` cambia) |
| `pageChanged` | `true` se una di quelle pagine ha oggi un'impronta diversa da quella dell'ultimo evento (la verifica se è più recente della lettura, altrimenti la lettura). Un'impronta vuota (pagina non leggibile) non conta come cambiata | `source_trust.py mark`, ogni mattina nel workflow «Controllo pagine dei Comuni» |

Le date di verifica non si inventano: oggi nessuna zona ha `verifiedOn`.

## La regola A e la soglia: 120 giorni

Decisa da Ledion per la 1.20.1. Una zona **ufficiale** dà la risposta normale (anche verde) se:

- è stata verificata (`verifiedOn`) da al più **120 giorni**, oppure, senza una verifica recente,
- è stata letta (`checkedOn`) da al più **120 giorni**,

e in tutti e due i casi `pageChanged` non è `true`. Una verifica più vecchia di 120 giorni senza una lettura più recente
vale come «non verificata»: conta la lettura. 120 è lo stesso numero di prima per «dati da ricontrollare», del widget e
della verifica dei verbali: `RuleEngine.staleAfterDays` su iPhone e Android, `VERIFIED_DAYS` sul sito, `VERIFIED_FRESH_DAYS`
in `Tools/source_trust.py`. I giorni si contano dalla data a oggi; 120 giorni pieni valgono ancora, dal 121° no.

| Stato (iPhone e Android `DataTrust`, sito `trustOf`) | Cosa cambia nella risposta |
|---|---|
| `verified` (verifica ≤ 120 giorni) | niente |
| `read` (lettura ≤ 120 giorni, senza verifica recente): oggi tutte le zone | niente; sotto la fonte «Non ancora verificato da una persona» |
| `unverified` / `old` (lettura e verifica più vecchie di 120 giorni) | ogni risposta gialla con il «?» (dati da ricontrollare); «Non ancora verificato: controlla il cartello» |
| `pageChanged` | **ogni** risposta della zona, anche il «no», gialla con il «?»: «La pagina del Comune è cambiata: controlla il cartello» |

Le zone da fonti non ufficiali restano come dalla 1.19.0 (il «sì» è sempre giallo). Il verbale («il varco non era attivo»)
è verde solo con una verifica recente.

## I colori (1.20.1)

Rosso = non entrare; giallo = a una condizione o incerto («?»); **verde = puoi entrare, anche a ZTL spenta** (sulla mappa
verde più leggero, senza righe, con il bordo più rado; il pannello dice «ZTL NON ATTIVA»); grigio/neutro = nessuna ZTL nota
lì (fuori copertura: «Non conosciamo questo posto»). Fuori dalle zone di una città che conosciamo: verde «Fuori dalla ZTL».
I casi di prova comuni di iPhone, Android e sito sono in `shared/engine-cases.json`.


## Pagine che cambiano senza che cambino le regole (1.20.4)

`Tools/check_sources.py` prende l'impronta del testo della pagina. Prima toglie script, stili, menu, intestazione, piè di pagina, le date «ultimo aggiornamento», e dalla 1.20.4:

- il nome casuale dei campi antispam (`hnp_name_…`, Sorrento: cambiava a ogni richiesta);
- le sezioni elencate in `DROP` (inizio dell'indirizzo → espressioni regolari dei blocchi HTML da togliere). Oggi solo i comunicati stampa di comune.ravenna.it: `<section id="contenuti-correlati">`, la lista delle ultime notizie del Comune.

Per aggiungere una pagina a `DROP`: scaricarla due volte a distanza di un giorno, trovare il blocco che cambia, controllare che **non contenga regole** (orari, prezzi, eccezioni), aggiungere il prefisso più stretto possibile, ricalcolare la sua impronta in `data/source-hashes.json` e rileggere la città (sotto). Cambiare la pulizia di tutte le pagine insieme cambia tutte le impronte: le zone diventerebbero «pagina cambiata».

## Rileggere una città (togliere «pagina cambiata»)

1. Scaricare di nuovo le pagine citate e confrontarle con i testi in `data/raw/<città>/`; se è cambiato qualcosa di sostanza, aggiornare `Tools/build_<città>.py` e `docs/fonti-<città>.md` con la citazione.
2. Salvare i testi nuovi in `data/raw/<città>/` (stessa intestazione, data nuova) e mettere `CHECKED` in `Tools/build_<città>.py` all'ora della lettura, **dopo** l'ultimo commit che ha cambiato `data/source-hashes.json` (le impronte della lettura sono la prima registrazione da quel momento in poi).
3. `python3 Tools/build_<città>.py && python3 Tools/source_trust.py mark && python3 Tools/build_manifest.py`: le frasi citate devono esserci ancora e la zona non ha più `pageChanged`.

## Dopo una verifica

```sh
python3 Tools/source_trust.py verify firenze firenze-a firenze-b   # o solo «firenze» per tutte le zone
python3 Tools/source_trust.py mark && python3 Tools/build_manifest.py
git commit -am "Firenze: Settori A e B verificati"
```

## Dati firmati

L'iPhone scarica i dati nuovi da GitHub (`Resources/Cities/manifest.json` e le città, `Sources/CityUpdater.swift`). Dalla
1.20.1 li usa solo se sono **firmati**:

- Il workflow «Firma dei dati delle città» (`.github/workflows/cities-sign.yml`) firma `manifest.json` (byte per byte,
  preceduto da `GateLR-cities-v1\n`) con Ed25519 e scrive la firma in `Resources/Cities/manifest.sig`. Il manifest ha la
  versione e l'impronta SHA-256 di ogni città, quindi la firma copre anche ogni file.
- La chiave privata è solo nel segreto `CITY_DATA_SIGNING_KEY` di GitHub. La chiave pubblica è in
  `shared/city-signing-key.txt` e va dentro l'app (e il widget).
- L'app controlla la firma prima di scaricare le città, poi ogni impronta; salva elenco e firma con le città e a ogni
  apertura (app e widget) li ricontrolla. Firma mancante o sbagliata, chiave pubblica assente, file diverso: l'aggiornamento
  si ignora e restano i dati dell'app o l'ultimo aggiornamento firmato. I dati scaricati senza firma dalle versioni fino
  alla 1.20.0 non si usano più.
- Android non scarica dati: usa solo quelli dentro l'app. Il sito si costruisce dal repository.

### Da fare una volta (Ledion, sul Mac)

Finché questi passi non sono fatti, l'app 1.20.1 non accetta nessun aggiornamento scaricato (restano i dati dentro l'app).

1. `python3 -m pip install --user cryptography` (se manca)
2. Nella cartella del repository: `python3 Tools/sign_cities.py new-key`
   - scrive la chiave pubblica in `shared/city-signing-key.txt`
   - scrive la chiave privata in `~/gatelr-city-signing-key.txt` (permessi 600); non la stampa mai
3. `gh secret set CITY_DATA_SIGNING_KEY -R LR-apps609/GateLR < ~/gatelr-city-signing-key.txt`
   (oppure GitHub → Settings → Secrets and variables → Actions → New repository secret, nome `CITY_DATA_SIGNING_KEY`,
   valore: la riga del file)
4. `rm -P ~/gatelr-city-signing-key.txt` (o tienila in un posto sicuro fuori dal repository, es. il Portachiavi)
5. `git add shared/city-signing-key.txt && git commit -m "Chiave pubblica dei dati delle città" && git push`
   - il push fa partire «Firma dei dati delle città», che scrive `manifest.sig`
   - la nuova build dell'iPhone (con la chiave pubblica dentro) accetta da lì in poi gli aggiornamenti firmati

Se la chiave privata si perde o esce: rifare i passi 2–5 (una nuova coppia); le app con la chiave vecchia smettono di
accettare aggiornamenti finché non si aggiornano.
