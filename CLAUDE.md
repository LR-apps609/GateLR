# GateLR · regole per Claude

**Documento della verità:** https://claude.ai/artifact/6uh4DcwBaoWLMPG5FBW1r8 («GateLR · Documento della verità», pagina privata su claude.ai con le schede)

- Pagina e dati sono separati: i dati stanno nel database della pagina (collezioni `meta`, `attese`, `passi`, `test`, `diario`, `link`, `stato`, `decisioni`, `guida`, `archivio`, `cambiamenti`). Si aggiorna scrivendo righe (strumento ArtifactData); la pagina si ripubblica solo se cambia l'aspetto.
- Prima di ogni aggiornamento rileggi le righe dal database, mai dalla memoria. Se una scrittura non riesce, dillo a Ledion.
- Date sempre «04/11/2026 · 13:45», ora italiana, dall'orologio (`TZ=Europe/Rome date`) o dai commit. Ogni riga ha `creato` e `modificato`; a ogni scrittura aggiungi una riga in `cambiamenti`.
- Ogni cambiamento da verificare crea il suo test (`test`) insieme alla voce del Diario; un test fallito diventa un bug in `stato`.
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
