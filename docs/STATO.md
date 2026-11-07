# GateLR: a che punto siamo

Lo stato vero, le decisioni, i test da fare e la cronologia stanno nel **Documento della verità**:
https://claude.ai/artifact/6uh4DcwBaoWLMPG5FBW1r8 (pagina privata su claude.ai). Se questo file e il documento dicono
cose diverse, vale il documento. Questo file non si aggiorna più a ogni versione: è solo un riassunto.

## In breve (07/11/2026 · 20:30)

- **Versione pronta:** 1.20.3 «Parole» su iPhone e Android (ramo `versione-1.20.3`), da provare sul telefono; il sito è
  pubblicato alla 1.20.3.
- **In lavorazione:** 1.20.4 «Solidità» (dati delle città riletti, memoria del Guardiano con un controllo in CI, foto 39 e
  11, «Fuori dalla ZTL» grigio) e, in parallelo, la 2.0 (le tavole delle bozze approvate).
- **Copertura:** 46 città italiane, 8 lingue, stesse risposte su iPhone, Android e sito (casi comuni in
  `shared/engine-cases.json`).
- **Colori delle risposte:** rosso non entrare, giallo a una condizione o «controlla il cartello», verde puoi entrare
  (anche a ZTL non attiva), grigio fuori dalla ZTL in una città che conosciamo, neutro con il «?» fuori copertura.
- **Ancora aperto:** nessuna città verificata da una persona; la chiave della firma dei dati delle città da creare;
  account sviluppatore Apple (TestFlight) e token Mapbox nei segreti di GitHub.

## Dove guardare

- Compilazioni e foto: GitHub Actions («Compila GateLR», «Android»), rami `screenshots` e `screenshots-android`.
- Misure delle prestazioni dell'iPhone: `.github/workflows/misure.yml` (rami `prestazioni-*` o a mano).
- Installare sul telefono: «Installa su iPhone.command» (Mac) o l'.apk da Actions → Android; `docs/windows.md`.
