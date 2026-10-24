# GateLR per Android

App nativa (Kotlin + Jetpack Compose), Android 8 e successivi. Funziona anche **senza servizi Google** (Huawei, Honor): mappe MapLibre + OpenFreeMap, ricerca Photon, percorso OSRM, posizione dal GPS del telefono, lettura del cartello con ML Kit incluso nell'app.

- `core/` — il motore delle regole e i modelli (stesse regole dell'iPhone), con i test: `gradle -p android/core test`
- `app/` — l'app; usa i sorgenti di `core/` e i file delle città in `Resources/Cities` (copiati alla compilazione)
- `ci/tour.sh` — giro di prova sull'emulatore (foto nel ramo `screenshots-android`)

## Provarla sul telefono, senza computer
GitHub → Actions → **Android** → ultima esecuzione verde → Artifacts → **GateLR-android-debug** → apri l'.apk sul telefono.

## Con Android Studio (facoltativo)
1. Installa Android Studio (gratis) → Open → cartella `android/`
2. Aspetta la sincronizzazione di Gradle → telefono collegato con «Debug USB» attivo → ▶︎

## Versione per gli store
Vedi `docs/android-store.md` (chiave di firma nei segreti di GitHub → `.aab` firmato a ogni compilazione).
