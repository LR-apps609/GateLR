# Server «targa automatica» (gatelr-targa) — SPENTO

Questo è il piccolo server che un giorno permetterà a GateLR di riempire marca, modello, alimentazione, anno e
classe Euro partendo dalla targa. **Per ora è spento e non è pubblicato da nessuna parte.** Anche se qualcuno lo
pubblicasse così com'è, risponderebbe sempre `503 {"error":"disabled"}` senza chiamare nessun fornitore e senza
spendere nulla. Nell'app il pulsante «Cerca dalla targa» resta bloccato.

## Cosa fa

- Riceve dall'app `POST /v1/plate` con `{"plate":"AB123CD","country":"IT"}` e l'header `X-Device-Id`
  (identificativo casuale dell'installazione).
- Controlla il formato della targa (auto dal 1994 `AB123CD`, moto dal 1999 `AB12345`; ciclomotori e targhe
  vecchie non ancora).
- Chiama InfoTarga (servizi `details` + `emissions`) con la chiave salvata come segreto di Cloudflare.
- Restituisce **solo** `{"make","model","fuel","firstRegistration","euroClass","source"}`.

Risposte di errore: `400 invalid_plate` · `404 plate_not_found` · `429 rate_limited` (troppe ricerche dal
dispositivo o dall'IP) · `429 busy` (InfoTarga accetta 1 richiesta ogni 5 secondi; header `Retry-After`) ·
`503 disabled` (spento) · `503 capped` (tetto giornaliero, mensile o di spesa raggiunto) · `503 unavailable`.

## Protezioni

- **Interruttore principale** `LOOKUP_ENABLED` = `"false"`: tutto spento. Solo il valore esatto `"true"` accende.
- **Interruttore d'emergenza della spesa** `SPEND_STOP` = `"true"`: blocca subito tutto anche se acceso.
- **Tetti globali**: `DAILY_CAP` (120 al giorno, sotto i 150 del piano Flex), `MONTHLY_CAP` (1000 al mese) e
  `MONTHLY_BUDGET_EUR` / `COST_PER_LOOKUP_EUR` (50 € / 0,29 € = massimo 172 ricerche al mese). Vale il più basso.
  Ogni ricerca si conta **prima** di chiamare InfoTarga. Un valore mancante o sbagliato blocca tutto.
- **Per dispositivo e per IP**: `DEVICE_DAILY_CAP` 5, `DEVICE_MONTHLY_CAP` 20, `IP_DAILY_CAP` 10.
- **Apple App Attest**: non ancora fatto (TODO nel codice). Con `REQUIRE_APP_ATTEST = "true"` il server rifiuta
  tutto finché non è implementato.
- **Timeout** di 8 secondi verso InfoTarga (`PROVIDER_TIMEOUT_MS`).
- **Privacy**: la targa non viene mai scritta nei log né salvata (log del Worker disattivati, nessun
  `console.log`, nessuna cache). I contatori contengono solo numeri e codici cifrati (hash) del dispositivo e
  dell'IP, cancellati ogni giorno/mese. Niente CORS: le richieste dai browser vengono rifiutate.

## Cosa fai tu (in quest'ordine, quando decidi di partire)

1. **Scrivi a InfoTarga** (support@infotarga.com) e aspetta il **sì scritto** all'uso in un'app pubblica tramite il
   nostro server (domande complete in `docs/targa-automatica.md`). Senza questo sì non si accende.
2. **Account InfoTarga**, piano **Flex**; nel pannello imposta, se c'è, un avviso/tetto di spesa (es. 30 € / 50 €).
   Copia la chiave API. **Non mandarla in chat né per email e non metterla in nessun file.**
3. **Account Cloudflare** gratuito su dash.cloudflare.com (nessuna carta serve).
4. Dal Mac, in questa cartella (`server/targa`):
   ```sh
   npx wrangler login
   npx wrangler deploy                    # pubblica il server: è ancora SPENTO
   npx wrangler secret put INFOTARGA_KEY  # incolla la chiave quando la chiede: resta cifrata su Cloudflare
   npx wrangler secret put ID_SALT        # facoltativo: una frase casuale lunga, rende gli hash non indovinabili
   ```
   (In alternativa: Cloudflare → «Workers & Pages» → `gatelr-targa` → «Settings» → «Variables and Secrets» →
   «Add» → tipo **Secret**.)
5. **Indirizzo InfoTarga**: in `wrangler.toml` sostituisci `INFOTARGA_BASE_URL` con quello vero della loro
   documentazione e fai controllare allo sviluppatore i campi segnati `TODO(infotarga)` in
   `src/providers/infotarga.js` (prima di accendere, una richiesta di prova con una targa tua).
6. **Budget**: decidi i tetti (`DAILY_CAP`, `MONTHLY_CAP`, `MONTHLY_BUDGET_EUR`) e scrivili in `wrangler.toml`.
7. **Solo ora, e solo dopo il sì scritto di InfoTarga**: metti `LOOKUP_ENABLED = "true"` in `wrangler.toml` e
   ripeti `npx wrangler deploy` (oppure cambialo da «Variables and Secrets» nel pannello).
8. **Per spegnere subito**: `SPEND_STOP = "true"` (o `LOOKUP_ENABLED = "false"`) dal pannello Cloudflare.
9. Aggiorna informativa privacy e scheda «Privacy» dell'App Store come indicato in `docs/targa-automatica.md`.

Nessun `account_id` è scritto qui: wrangler lo prende dal login.

## Come lo chiamerà l'app

```
POST https://gatelr-targa.<tuonome>.workers.dev/v1/plate
Content-Type: application/json
X-Device-Id: <UUID casuale salvato nell'app alla prima ricerca>

{"plate":"AB123CD","country":"IT"}
```
Risposta `200`:
```json
{"make":"FIAT","model":"Panda","fuel":"petrol","firstRegistration":"2019-03-14","euroClass":6,"source":"infotarga"}
```
`fuel` usa gli stessi valori di `Fuel` nell'app (`petrol`, `diesel`, `hybrid`, `electric`, `lpg`) o `null`;
`firstRegistration` è `AAAA-MM-GG` o `AAAA`; `euroClass` è 0…6 o `null`. Nell'app una `ProxyPlateLookup`
trasformerà `404` in `PlateLookupError.notFound`, `503 disabled` in `.notEnabled` e il resto in `.unavailable`.

## Prove (offline, nessuna rete, nessun pacchetto da installare)

```sh
cd server/targa && node --test test/*.test.js
```
Usano un fornitore finto: servizio spento, targhe sbagliate, tetti, limiti, timeout e conversione dei dati.

## Cambiare fornitore

Ogni fornitore è un file in `src/providers/` con lo stesso contratto (`provider.js`). Per Openapi «Italian Car
Check» o RegCheck basta scrivere il file e sceglierlo con `PROVIDER` (punti segnati TODO in `providers/index.js`).
