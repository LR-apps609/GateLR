# GateLR Android: come pubblicarlo sugli store

Tutto è già pronto nel codice. Servono solo i tuoi account e una chiave di firma.

## 1. La chiave di firma (una volta sola, 5 minuti)
Sul Mac, nel Terminale:
```
keytool -genkeypair -v -keystore ~/gatelr.jks -alias gatelr -keyalg RSA -keysize 4096 -validity 10000
base64 -i ~/gatelr.jks | pbcopy
```
(ti chiede una password e nome/città: scegli tu). **Conserva `gatelr.jks` e la password: se li perdi non puoi più aggiornare l'app.**

Poi su GitHub: repository → Settings → Secrets and variables → Actions → New repository secret:
- `GATELR_KEYSTORE_B64` = incolla (quello copiato da `pbcopy`)
- `GATELR_KEYSTORE_PASSWORD` = la password
- `GATELR_KEY_PASSWORD` = la stessa password

Da lì in poi ogni compilazione (Actions → Android) produce **GateLR-android-release** con l'`.apk` e l'`.aab` firmati.

## 2. Gli store

| Store | Telefoni | Account | Costo | File |
|---|---|---|---|---|
| **Google Play** | Samsung, Xiaomi, Nothing, Pixel, Motorola, OnePlus… | play.google.com/console | 25 $ una volta | `.aab` |
| **Huawei AppGallery** | Huawei, Honor vecchi (senza Google) | developer.huawei.com | gratis | `.apk` o `.aab` |
| **Samsung Galaxy Store** | Samsung | seller.samsungapps.com | gratis | `.apk` |
| **Xiaomi GetApps** | Xiaomi, Redmi, POCO | global.developer.mi.com | gratis | `.apk` |
| **Honor App Market** | Honor nuovi | developer.honor.com | gratis | `.apk` |
| **Amazon Appstore** | tablet Fire | developer.amazon.com | gratis | `.apk` |

Ordine consigliato: Google Play → AppGallery → Galaxy Store → GetApps.

## 3. Google Play: le cose che chiede
- **Account personale nuovo**: prima della pubblicazione serve un **test chiuso con almeno 12 tester per 14 giorni** (amici con Android: basta la loro email Gmail).
- **Posizione in background / servizio in primo piano**: GateLR usa il servizio in primo piano «location» avviato da te (non chiede «posizione sempre»). Nel modulo «Foreground service» scegli *Navigation* e allega un video di 30 s: Viaggio → Avvia → Google Maps si apre → notifica GateLR con la distanza.
- **Sicurezza dei dati**: nessun dato raccolto né condiviso; la posizione resta sul telefono; nessun account.
- **Classificazione dei contenuti**: tutti; nessuna pubblicità.
- **Privacy policy**: https://lr-apps609.github.io/GateLR/privacy/ (poi il tuo dominio).
- **Mostra sopra altre app** (la bolla): è facoltativa e la attiva l'utente; non serve dichiararla.

## 4. Testi per la scheda (pronti)
**Nome**: GateLR – ZTL checker
**Breve (80)**: Can you drive into the ZTL? Clear answer, official sources, gate alerts.
**Breve IT**: Puoi entrare nella ZTL? Risposta chiara, fonti ufficiali, avvisi ai varchi.
**Breve DE**: Darfst du in die ZTL? Klare Antwort, offizielle Quellen, Hinweise vor Toren.

**Descrizione (EN)**:
Driving to Florence, Bologna or Milan? GateLR tells you in one second if you can drive into the limited traffic zone (ZTL) — now or when you arrive — with the official source of the city.
• Search your hotel: see if it's inside a ZTL, when the cameras are on, and send the hotel a ready message to register your plate (EN/IT/DE)
• Drive with Google Maps, Waze or Petal Maps: GateLR stays on with a notification and a small bubble, and warns you by voice before every active gate
• Milan Area B and Area C: Euro class bans for your car, day ticket and deadline
• Pedestrian areas, holidays, hours explained in your language
• Read the sign: take a photo of the panel and GateLR explains it
• Works without Google services (Huawei, Honor), no account, no ads, no tracking
Road signs on site always win over the app.

## 5. Foto per la scheda
Le foto dell'app si rifanno da sole a ogni compilazione nel ramo `screenshots-android` (telefono Pixel 6, Android 14).
