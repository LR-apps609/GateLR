# Targa automatica (NON attiva)

Idea: l'utente scrive la targa italiana e GateLR riempie da solo marca, modello, alimentazione, anno e classe Euro.
**Non è approvata**: nell'app c'è solo il contratto `PlateLookup` con un sostituto spento
(`DisabledPlateLookup` in `Sources/PlateLookup.swift`). Nessuna richiesta in rete, nessuna chiave, nessun pulsante.
Oggi le stesse informazioni arrivano gratis e sul telefono da **«Fotografa il libretto»** e da **«Auto a noleggio»**.

> **Il piccolo server è pronto ma BLOCCATO**: `server/targa/` (Cloudflare Worker, istruzioni in
> [`server/targa/LEGGIMI.md`](../server/targa/LEGGIMI.md)). Non è pubblicato; anche pubblicato risponde
> `503 disabled` finché `LOOKUP_ENABLED` non è `"true"`, cosa da fare solo dopo il sì scritto di InfoTarga.
> Nell'app l'opzione «Cerca dalla targa» resta bloccata.

## Da dove possono venire i dati

| Opzione | Cosa dà | Costo indicativo | Note |
|---|---|---|---|
| Portale dell'Automobilista (Ministero dei Trasporti) | classe ambientale, revisione, copertura RC da targa | gratis sul sito | nessuna API pubblica; non si può automatizzare (termini d'uso, captcha) |
| Visura PRA (ACI) | proprietà, dati tecnici di base | qualche euro a visura | pensata per persone e agenzie, non per un'app; dati personali del proprietario |
| API commerciali «dati veicolo da targa» (aggregatori italiani ed europei, es. servizi tipo Openapi, RegCheck/CarRegistrationAPI, banche dati per assicurazioni e ricambi) | marca, modello, versione, alimentazione, cilindrata, a volte classe Euro e data di immatricolazione | da pochi centesimi a circa 0,50 € a richiesta, spesso a pacchetti o con canone | prezzi e copertura da verificare con un preventivo: la classe Euro non c'è sempre |

I costi sono stime da verificare prima di decidere. Con 1 000 utenti che aggiungono in media 2 auto all'anno
servono circa 2 000 ricerche: da qualche decina a circa 1 000 € l'anno a seconda del fornitore.

## Perché serve un piccolo server (proxy)

- La chiave a pagamento **non può stare nell'app**: chiunque la estrarrebbe dal pacchetto e la userebbe a nostre spese.
- Il server (es. una funzione su Cloudflare Workers, Vercel o Firebase) tiene la chiave, riceve solo la targa e
  restituisce marca, modello, alimentazione, anno e classe Euro.
- Limiti contro l'abuso: poche ricerche al giorno per dispositivo (Apple App Attest / DeviceCheck), tetti globali
  giornaliero e mensile sul server, tetto di spesa mensile presso il fornitore.
- Privacy: la targa è un dato personale. Il server non salva né registra targhe (niente log, niente cache); l'informativa privacy e la scheda «Privacy» dell'App Store vanno aggiornate («dati inviati a un servizio
  esterno per cercare il veicolo»). Oggi l'app non invia nulla e lo dice.

## Come si attiverebbe

1. Scegliere il fornitore (preventivo, copertura della classe Euro, contratto per uso in un'app).
2. ~~Scrivere il proxy~~ **fatto**: `server/targa/` — `POST /v1/plate {plate, country:"IT"}` →
   `{make, model, fuel, firstRegistration, euroClass, source}`; fornitore InfoTarga (campi da verificare, segnati
   `TODO(infotarga)`), interruttori `LOOKUP_ENABLED` (spento) e `SPEND_STOP`, tetti giornaliero/mensile/di spesa,
   limiti per dispositivo e IP, timeout 8 s, nessun log né salvataggio delle targhe, niente CORS. App Attest: TODO.
3. Nell'app (non ancora fatto): una `ProxyPlateLookup: PlateLookup` che chiama solo il nostro server (HTTPS,
   timeout 10 s, header `X-Device-Id` con un UUID casuale salvato sul telefono) e traduce le risposte:
   `200` → `PlateLookupResult` (`fuel` ha già i valori di `Fuel`, `euroClass` → `euro`, l'anno da
   `firstRegistration` → `firstRegistrationYear`), `404` → `.notFound`, `503 disabled` → `.notEnabled`,
   altro → `.unavailable`. Poi `PlateLookupService.current` restituisce `ProxyPlateLookup()`.
4. Nel modulo del veicolo: un pulsante «Cerca dalla targa» accanto alla targa, visibile solo se
   `PlateLookupService.current.isAvailable`; i dati trovati passano dallo stesso controllo di «Fotografa il libretto»
   prima di salvare (la classe Euro del libretto, campo V.9, resta quella che conta).
5. Test con un `PlateLookup` finto (nessuna rete nei test).
