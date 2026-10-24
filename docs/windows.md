# GateLR da Windows (e dal Mac quando viaggi)

Tutto vive su GitHub: io lavoro lì, GitHub compila l'app per iPhone e per Android sui suoi computer.
Sui tuoi PC non devi tenere nulla in pari: scarichi l'ultima versione quando vuoi provarla, da Windows o dal Mac.

## iPhone da Windows (Sideloadly)

### Una volta sola (15 minuti)
1. Installa **Apple Devices** dal Microsoft Store (o iTunes dal sito Apple): serve a Windows per vedere l'iPhone.
2. Installa **Sideloadly** da https://sideloadly.io (gratis).
3. Collega l'iPhone col cavo → sull'iPhone «Autorizza questo computer».
4. Sull'iPhone: Impostazioni → Privacy e sicurezza → **Modalità sviluppatore** → attiva (l'iPhone si riavvia).

### Ogni volta che c'è una versione nuova (3 minuti)
1. GitHub → repository GateLR → **Actions** → «Compila GateLR» → l'ultima esecuzione verde → in fondo, **Artifacts** → **GateLR-iPhone-ipa** → si scarica uno .zip; dentro c'è `GateLR-x.y.z.ipa`.
2. Apri Sideloadly → trascina l'.ipa → **Apple ID**: lo stesso che usi in Xcode sul Mac → **Start** → password dell'ID Apple (ed eventuale codice a due fattori).
3. Solo la prima volta, sull'iPhone: Impostazioni → Generali → **VPN e gestione dispositivi** → il tuo ID Apple → **Autorizza**.

Le auto, i permessi e i viaggi salvati restano: è la stessa app, aggiornata.

### Da sapere (ID Apple gratuito, come col Mac)
- L'app vale **7 giorni**: poi va reinstallata (Sideloadly ha «Auto refresh» se il PC resta acceso sulla stessa Wi-Fi).
- Al massimo **3 app** installate così nello stesso momento.
- Il **widget** potrebbe non comparire con l'ID gratuito; il resto (guardiano, Dynamic Island, notifiche, voce) funziona.
- Con l'**Apple Developer Program** (99 €/anno) si passa a TestFlight: niente cavo, niente 7 giorni, niente computer. Quando lo attivi, preparo io la consegna automatica.

## iPhone dal Mac (in viaggio)
Come sempre, nel Terminale:
```
osascript -e 'quit app "Xcode"'
cd ~/Developer/GateLR && git pull && zsh "Installa su iPhone.command"
```
Poi in Xcode: Team su **GateLR** e **GateLRWidget** (lo stesso ID Apple di Sideloadly) → ▶︎.
Usando lo stesso ID Apple sui due computer, l'una installazione aggiorna l'altra e i dati restano (se Sideloadly chiedesse di cambiare l'identificativo dell'app, rispondi di no).

## Android (da qualsiasi PC, o direttamente dal telefono)
GitHub → **Actions** → «Android» → l'ultima verde → **Artifacts** → **GateLR-android-debug** → apri l'.apk sul telefono.
Puoi anche aprire la pagina di GitHub dal telefono Android e scaricarlo lì.

## Le prove
- iPhone: `docs/checklist-prova.md`
- Android: `docs/checklist-android.md`
- Le foto che GitHub fa a ogni versione: ramo `screenshots` (iPhone) e `screenshots-android`.
