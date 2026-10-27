# Salerno: fonti della scheda ZTL

Scheda generata da `Tools/build_salerno.py` → `data/drafts/salerno.json` (stato **draft**, **bozza**: non è nel manifest dell'app né sul sito).

## Perché resta bozza
1. **Nessun orario ufficiale.** Nessuna pagina o documento ufficiale letto indica quando la ZTL è attiva; «24 ore su 24» è solo in guide e siti di motori. La vecchia scheda del Comune (website.comune.salerno.it, 2007, ord. 291/05) è bloccata dal proxy e comunque superata.
2. **Nessun perimetro.** Nessun open data (Comune, dati.regione.campania.it), nessuna relazione ZTL in OpenStreetMap (API, 27/10/2026, bbox 40.672–40.686 N, 14.744–14.772 E): le vie del centro storico hanno solo `access=destination`, che non è una delimitazione ufficiale. I 10 varchi del modello B1 non hanno coordinate.

Per pubblicarla servono l'ordinanza vigente (orari e vie o mappa) e la posizione dei varchi.

## Fonti ufficiali lette (27/10/2026)
| Fatto | URL | Tipo | Letto il |
|---|---|---|---|
| Ufficio Varchi ZTL: permessi giornalieri, transiti trasmessi da autorimesse, B&B, alberghi e pensioni (**citazione**); sistema Sirio Web e Street Controll | https://www.comune.salerno.it/amministrazione/ufficio/ufficio-varchi-ztl → `data/raw/salerno/comune-ufficio-varchi-ztl.txt` | ufficiale | 27/10/2026 |
| Comunicazione transito occasionale (carico/scarico, disabili, medici) con modello B1, gratuita | https://www.comune.salerno.it/servizi/comunicazione-transito-occasionale-ztl → `comune-comunicazione-transito-occasionale.txt` | ufficiale | 27/10/2026 |
| Elenco dei 10 varchi; carico/scarico 6–9:30 e 14–17; veicoli fino a 18 q.li su via Duomo, Portanova, Conforti, Corso V. Emanuele | https://www.comune.salerno.it/sites/default/files/documento_pubblico/modello-b1.pdf → `comune-modello-b1.txt` | ufficiale | 27/10/2026 |
| Permessi: categorie (residenti, domiciliati, disabili, attività, CVE…), 10 € PagoPA, risposta entro 30 giorni | https://www.comune.salerno.it/servizi/richiesta-autorizzazione-transito-eo-sosta-ztl-eo-rinnovi → `comune-richiesta-autorizzazione-ztl.txt` | ufficiale | 27/10/2026 |

| PUMS (Proposta di Piano, 2° Rapporto, p. 180): per tutti i varchi carico/scarico 06.00–09.30 e 14.00–17.00 con autorizzazione annuale, permanenza 15 minuti, portata massima 18 quintali; nessun orario della ZTL | https://www.comune.salerno.it/documento-pubblico/pums-elaborati-progettuali → `comune-pums-2-rapporto-estratto.txt` | ufficiale (pianificazione) | 27/10/2026 |

Ricontrollo del 27/10/2026: pagine «ZTL» del sito (argomento, Ufficio Varchi, servizi «Verifica transiti», «Comunicazione transito occasionale», «Richiesta autorizzazione», moduli) rilette: nessun orario e nessuna ordinanza linkata. I 9 moduli di richiesta (PDF) sono scansioni senza testo. La ricerca interna del sito (`/search`) risponde **403** (non insistito).

## Fonti non ufficiali
`data/raw/salerno/websearch-1-orari.txt`: accessibilitacentristorici.it, sicurauto.it, automobilista.it (24 ore su 24; confini via Roma – via Duomo/San Benedetto/Salvatore Rienzi); stampa 2023 (nuovi varchi Conforti, Corso Garibaldi, Corso V. Emanuele) e delibera per sostituire i 15 varchi.

## Host non raggiungibili (ricontrollati il 27/10/2026)
- `website.comune.salerno.it` (vecchio sito con la scheda orari 2007): il proxy accetta, ma il server chiude la connessione («connection reset»), anche con timeout di 180 s e più tentativi.
- Connessione chiusa allo stesso modo: `amministrazionetrasparente.comune.salerno.it`, `albo.comune.salerno.it`, `servizionline.comune.salerno.it`, `servizi.comune.salerno.it`.
- `www.comune.salerno.it` funziona, tranne `/search` (403 dal sito).

## Geometria
Nessuna. Nessun disegno a mano.
