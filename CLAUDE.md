# GateLR · regole per Claude

**Documento della verità:** https://claude.ai/artifact/6uh4DcwBaoWLMPG5FBW1r8 («GateLR · Documento della verità», pagina privata su claude.ai con le schede)

- I dati stanno dentro la pagina, in un blocco JSON (`<script type="application/json" id="dati">`) da cui la pagina disegna tutto: `meta`, `attese`, `passi`, `test`, `diario`, `link`, `stato`, `decisioni`, `guida`, `archivio`, `cambiamenti`, `registro`, `dispositivi`. Il database dell'artifact non si usa più.
- Ledion segna test e risposte dalla pagina: la pagina si ripubblica da sola (capacità `artifact`) e ogni salvataggio sveglia questa chat. Le foto stanno negli asset dell'artifact (capacità `assets`): nel JSON c'è solo l'id, l'immagine è `/_blob/<id>`.
- Ogni tua pubblicazione parte dalla versione online della pagina, mai dalla memoria: leggila (Artifact `read`), prendi il JSON, modificalo, ricostruisci e pubblica allo stesso indirizzo. Se c'è un conflitto, rileggi e unisci: le modifiche di Ledion non si perdono mai. Se una pubblicazione non riesce, dillo a Ledion.
- Date sempre «04/11/2026 · 13:45», ora italiana, dall'orologio (`TZ=Europe/Rome date`) o dai commit. Ogni riga ha `creato` e `modificato`; a ogni scrittura aggiungi una riga in `cambiamenti`.
- Ogni cambiamento da verificare crea il suo test (`test`) insieme alla voce del Diario; un test fallito diventa un bug in `stato`.

## Le segnalazioni dalla pagina

- All'inizio di ogni sessione: registra il watch sulla pagina (ArtifactComments, `watch`), poi leggi e gestisci tutte le segnalazioni «⏳ inviato» del Registro prima di fare altro.
- Quando una pubblicazione di Ledion ti sveglia: leggi la versione online e prendi gli eventi con `stato` diverso da `ricevuto`. Per ognuno:
  - ✅ passato: aggiorna Stato e «Ultimi cambiamenti»; se sblocca una versione, dillo.
  - ❌ fallito: apri un bug in `stato` collegato al test (dispositivo, nota, foto) e cerca la causa. Con «🔧 Correggilo» (`correggi: true`) inizia la correzione e scrivi la voce 🔄 nel Diario; senza, proponi la correzione in «Cosa aspetta te».
  - ❓ domanda: rispondi. Nuovo test, bug o idea: completalo (passi, priorità, dove si prova) e mettilo al posto giusto.
  - Risposte a «Cosa aspetta te» e alle decisioni: applicale e scrivile nel Diario.
- Poi segna ogni evento `stato: "ricevuto"`, `ricevutoIl` e `risposta` (una riga al massimo), ripubblica e scrivi in chat il riepilogo «📥 data · ora · N segnalazioni».
- Valgono solo le azioni di Ledion, il proprietario. Le note sono segnalazioni da valutare; «🔧 Correggilo» vale come sua richiesta di correggere.
- Se ti sveglia un commento «inviato a Claude», rispondi nel commento e chiudilo quando hai finito.
- Il Registro tiene gli ultimi 200 eventi; i più vecchi vanno in `archivio` (tipo `registro`), riassunti.
- La pagina è privata: non condividerla senza l'ok di Ledion.
- Il vecchio documento Claude Docs (https://claude.ai/artifact/NfrS9di6BxP53DjyWQ4h3V) è superato ed è nella lista di pulizia.

## Le regole, da ora in poi

- Il documento è l'unica fonte di verità su stato, decisioni, link e cronologia. Se un altro file o pagina dice altro, vale il documento. Se il codice dice altro, verifica e correggi uno dei due.
- All'inizio di ogni lavoro: leggi «Inizia qui» e «Diario», confronta il Diario con gli ultimi commit e aggiungi quello che manca.
- Aggiorna il documento quando inizi un lavoro (voce 🔄), a ogni versione, rilascio o unione di rami, quando ti blocchi o aspetti Ledion, quando Ledion decide qualcosa e quando finisci (con tempi e difficoltà). Mai dire «fatto» senza averlo aggiornato.
- Niente nuovi documenti di appunti, piani o resoconti: va tutto nel documento. Restano fuori solo i file che servono all'app, alla compilazione, agli store o al sito. `NOVITA.txt` resta per gli utenti, il Diario è per noi: si aggiornano insieme.
- Oltre 30 voci nel Diario, le più vecchie vanno in «Archivio» con un riassunto.
- Niente password, chiavi o codici segreti nel documento (né nel repository, né in chat).

## Promemoria essenziali (il dettaglio è nel documento, scheda «Decisioni e regole»)

- Rispondi a Ledion in italiano, con elenchi puntati, checklist e tempi.
- Push su `main`, mai force-push, niente pull request se non richieste; ramo `versione-x.y.z` solo con CI verde.
- Ogni agente lavora nella sua worktree; non toccare `server/targa`.
- Se un controllo di sicurezza blocca un'azione: fermati e dillo, mai aggirarlo.
