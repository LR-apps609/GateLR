# GateLR · regole per Claude

**Documento della verità:** https://claude.ai/artifact/NfrS9di6BxP53DjyWQ4h3V («GateLR · Documento della verità», Claude Docs)

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
