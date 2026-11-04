# Dati: letto il, verificato il, pagine cambiate, firma (1.20.1)

## Le due date di ogni zona

Nei file delle città (`Resources/Cities/<città>.json`), in `zones[].source`:

| Campo | Cosa vuol dire | Chi lo scrive |
|---|---|---|
| `checkedOn` | **Letto il**: quando abbiamo letto le pagine da cui vengono le regole | gli script `Tools/build_*.py` (c'era già) |
| `verifiedOn` | **Verificato il**: quando una persona (o un controllo) ha confermato la regola. Assente = non lo sappiamo = **non verificata** | solo `python3 Tools/source_trust.py verify <città> [zona…]`, dopo una verifica vera |
| `verifiedFingerprints` | le impronte delle pagine ufficiali della zona al momento della verifica | `source_trust.py verify` (da `data/source-hashes.json`) |
| `pageChanged` | `true` se una di quelle pagine ha un'impronta diversa da quella della verifica | `source_trust.py mark`, ogni mattina nel workflow «Controllo pagine dei Comuni» |

Le date di verifica non si inventano: oggi nessuna zona ha `verifiedOn`, quindi tutte sono «non verificate».

## La soglia: 120 giorni

Una zona ufficiale è **sicura** solo se `verifiedOn` è al più **120 giorni** prima di adesso e `pageChanged` non è `true`.
È lo stesso numero di prima per «dati da ricontrollare» (`checkedOn` più vecchio di 120 giorni: ogni risposta «non
sicuro»), lo stesso del widget e della verifica dei verbali: `RuleEngine.staleAfterDays` su iPhone e Android, `VERIFIED_DAYS`
sul sito, `VERIFIED_FRESH_DAYS` in `Tools/source_trust.py`. I giorni si contano da `verifiedOn` a oggi; 120 giorni pieni
valgono ancora, dal 121° no.

| Stato (iPhone `DataTrust`, Android `DataTrust`, sito `trustOf`) | Cosa cambia nella risposta |
|---|---|
| verificata (≤ 120 giorni, pagina non cambiata) | niente: verde, grigio, giallo e rosso come dicono le regole |
| non verificata (`verifiedOn` assente) | un «sì» (verde, o grigio a ZTL spenta) diventa giallo con il «?»: «Questa regola non è ancora stata verificata: controlla il cartello». «No» e condizioni restano |
| verifica vecchia (> 120 giorni) | come sopra, con «Verificata l'ultima volta più di 120 giorni fa: controlla il cartello» |
| pagina cambiata (`pageChanged`) | **ogni** risposta della zona, anche il «no», diventa gialla con il «?»: «La pagina del Comune è cambiata: controlla il cartello» |

Le zone da fonti non ufficiali restano come dalla 1.19.0 (il «sì» è sempre giallo). Fuori dalle zone di una città che
conosciamo resta verde «Fuori dalla ZTL»; fuori copertura resta neutro. I casi di prova comuni di iPhone, Android e sito
sono in `shared/engine-cases.json` (campo `trust`).

## Dopo una verifica

```sh
python3 Tools/source_trust.py verify firenze firenze-a firenze-b   # o solo «firenze» per tutte le zone
python3 Tools/build_manifest.py
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
