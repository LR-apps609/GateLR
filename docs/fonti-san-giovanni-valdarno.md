# San Giovanni Valdarno: fonti della scheda ZTL

Scheda generata da `Tools/build_san_giovanni_valdarno.py` → `Resources/Cities/san-giovanni-valdarno.json` (stato **draft**, `reviewedByHuman: false`).
Fonti lette il **25/10/2026** e salvate in `data/raw/san-giovanni-valdarno/` (elenco e indirizzi in `README.txt`). Lo script controlla che ogni frase citata o riassunta ci sia davvero nei file salvati (si ferma se ne manca una) e fa i controlli di plausibilità sul perimetro.

Il sito del Comune (`www.comune.san-giovanni-valdarno.ar.it`, piattaforma MyCity) e i file allegati (`mycity.s3.sbg.io.cloud.ovh.net`) all'inizio non erano raggiungibili da qui: sono stati scaricati con il workflow «Scarica pagine» (rami `pagine-sgv2`, `pagine-sgv4`, `pagine-sgv5`). I PDF sono salvati anche come testo (`pdftotext -layout`).

## Zone

| Zona (id) | Chiusa a chi non ha il permesso | Tipo |
|---|---|---|
| Centro · ZTL Centro storico (`sgv-centro`): area A (rosa) della mappa del Comune | sempre, tranne lun–ven 6:00–9:00 non festivi (sabato, domenica e festivi tutto il giorno) | restricted |
| Centro · Corso Italia (`sgv-corso-italia`): area B (blu) della mappa | uguale; per chi ha il permesso solo 9:00–11:00 | restricted |

Fasce nel JSON: lun–ven 0:00–6:00 e 9:00–24:00, sabato e domenica 0:00–24:00; `freeOnHolidays: false`; `localHolidays: ["06-24"]` (San Giovanni Battista, patrono).
Aree pedonali nel JSON (`pedestrian`): piazza Cavour e piazza Masaccio (contorni OSM). Nessun `ticket`, `hotelCanRegister: false`, `exemptFuels: []`.

## Fatti → fonte (tutte ufficiali, lette il 25/10/2026)

| Fatto | Fonte | File |
|---|---|---|
| "La circolazione è consentita a tutti dalle ore 6:00 alle ore 9:00 - escluso sabato, domenica e festivi - in altri orari potranno entrare SOLO i soggetti autorizzati o provvisti di permesso" (citazione della scheda) | Pagina «Mappa ZTL» (Polizia Locale, aggiornata il 21/11/2025): https://www.comune.san-giovanni-valdarno.ar.it/documenti/2562266/mappa-ztl | `mappa-ztl.html`, `mappa-ztl.txt` |
| Fasce per gli autorizzati: Corso Italia 9:00–11:00 ("dalle 11:00 transito vietato, salvo particolari categorie"); altre vie 9:00–11:00 / 12:30–16:00 / 19:00–6:00 | idem | idem |
| Residenti del Corso senza garage: anche 21–6 (1/11–31/3) o 23–6 (1/4–31/10), il venerdì fino alle 5 ("giorno antecedente al mercato settimanale del sabato"); solo transito e fermata | idem | idem |
| Limite 30 km/h in tutta la ZTL; elettriche "assimilate agli altri veicoli a motore" (nessuna esenzione); bici libere | idem | idem |
| Non autorizzati: in caso di "provata e documentata urgenza o necessità improvvisa" si giustifica l'ingresso entro 48 ore con il modulo; decide la Polizia Locale | idem; modulo 08/54: https://www.comune.san-giovanni-valdarno.ar.it/modulistica/2562345/modulo-richiesta-autorizzazione-successiva | `modulo-48-ore.pdf/.txt` |
| Disabili con contrassegno (anche di altri comuni): transito e sosta senza limiti di orario, tranne l'area pedonale di piazza Masaccio, piazza Cavour e piazza Sant'Antonio; prima di entrare WhatsApp al Punto Amico 347 2588693 con targa, numero del contrassegno e comune che l'ha rilasciato | idem; scheda permesso annuale | `mappa-ztl.txt`, `permesso-ztl-annuale.txt` |
| Mappa ufficiale: ZTL area A (rosa), ZTL area B (blu, Corso Italia), varchi in entrata E1–E4 e in uscita U1–U5 | Galleria della pagina: https://mycity.s3.sbg.io.cloud.ovh.net/4260930/ztl.jpg | `mappa-ztl.jpg` |
| Nomi dei varchi. Ingresso: Corso Italia, via Giovanni da San Giovanni, via G. Mazzini, via della Madonna. Uscita: Corso Italia, via Alberti, via Rosai, Largo Ceramica, via S. Lorenzo | Modulo 08/54 (Rev. 1 – 01/2023) | `modulo-48-ore.txt` |
| Permessi brevi solo di persona al Punto Amico (via Rosai 1), rilascio immediato: giornaliero gratuito una volta al mese, 1–3 giorni 6 €, 4–7 giorni 10 €, 8 giorni–1 mese 30 €. Sono per carico/scarico: non sono un ticket per turisti → nessun `ticket` | https://www.comune.san-giovanni-valdarno.ar.it/servizi/servizio-dettaglio/3128251 | `permesso-ztl-temporaneo.*` |
| Permessi annuali (residenti, garage, commercianti, medici…), 5–50 € più bollo | https://www.comune.san-giovanni-valdarno.ar.it/servizi/servizio-dettaglio/2562040 | `permesso-ztl-annuale.*` |
| Regolamento: area pedonale (Corso Italia, p.zza Cavour, p.zza Masaccio, largo Arnolfo di Cambio, largo Masolino da Panicale, p.zza S. Antonio, via Battisti tra via Garibaldi e p.zza della Libertà), ZTL (elenco delle vie) e ZCS; orari rimandati a "apposita ordinanza sindacale"; controllo con "varchi elettronici"; sanzioni per le sole norme comunali 25–75 € (art. 7 bis TUEL) | Delibera C.C. n. 63 del 26/07/2011: https://mycity.s3.sbg.io.cloud.ovh.net/3716478/ZTL.pdf (pagina https://www.comune.san-giovanni-valdarno.ar.it/documenti/2503961/regolamento-determinazione-aree-pedonali-ztl-zcs) | `regolamento-CC-63-2011.*`, `regolamento.html` |
| Hotel: nessuna pagina del Comune parla di strutture ricettive che comunicano la targa → `hotelCanRegister: false` (in sospeso nella scheda) | ricerca sul sito (`/search?q=ZTL`, `varchi`, `ordinanza ztl`): nessun risultato utile | — |

## Geometrie (OpenStreetMap, ODbL)

- Overpass non era raggiungibile (né da qui né dal workflow: risposte 406/504). I dati sono stati presi dall'API di OSM, `https://api.openstreetmap.org/api/0.6/map?bbox=11.518,43.557,11.540,43.570` (workflow, ramo `pagine-sgv4`), e convertiti nel formato «out geom» in `data/raw/geo/san-giovanni-valdarno-ztl.json` (le due relazioni) e `san-giovanni-valdarno-streets.json` (strade, stazione, Palazzo Pretorio).
- Perimetri: relazioni OSM `boundary=limited_traffic_zone` [19456994](https://www.openstreetmap.org/relation/19456994) (centro) e [19456993](https://www.openstreetmap.org/relation/19456993) (Corso Italia), con `source:image` = la mappa del Comune e `check_date=2025-08-13`. **In OSM le lettere sono invertite** rispetto alla legenda del Comune (OSM chiama «Area A» la striscia di Corso Italia): nella scheda valgono la legenda e i colori della mappa ufficiale. La forma (rientranze su via Rosai, sulla chiesa e su via Battisti) corrisponde a quella della mappa ufficiale.
- Varchi: messi dove la strada OSM indicata taglia il perimetro (funzione `crossing` nel builder). E1 Corso Italia lato via Oberdan, E2 via Giovanni da San Giovanni, E3 via Mazzini, E4 via della Madonna, U1 via Alberti, U2 Corso Italia lato via Piave, U3 via S. Lorenzo (inizio di via Oberdan, dove il perimetro non taglia una strada), U4 vicolo verso via Mannozzi, U5 via Rosai lato nord. Il modulo nomina tra le uscite «via Rosai» e «Largo Ceramica» senza indicarne la posizione: quale sia U4 e quale U5 resta da confermare (nella scheda U4 ha un nome neutro).
- Controlli nel builder: Palazzo d'Arnolfo (Palazzo Pretorio, way OSM 183897543) e piazza Masaccio (43,5646, 11,5297) dentro; stazione FS (nodo OSM 8033523310, 43,5660, 11,5270) fuori, a circa 74 m dal bordo; ogni varco a meno di 15 m dal perimetro; area del centro 0,066 km².
- Piazza Sant'Antonio non è mappata in OSM come area pedonale: non è tra le aree pedonali del JSON (è comunque dentro la ZTL).

## Limite noto dell'app

La fascia libera (6–9) esclude i festivi, quindi nei festivi la ZTL è chiusa tutto il giorno. Il modello dell'app sa solo «spenta nei festivi» (`freeOnHolidays: true`) o «festivi come gli altri giorni» (`false`): con `false`, in un festivo infrasettimanale tra le 6 e le 9 l'app direbbe per errore che la ZTL è spenta. Il caso è scritto nei punti in sospeso della scheda e nel riassunto; per risolverlo serve una modifica al motore delle regole (fasce attive solo nei festivi), non ai dati. Il 24 giugno (patrono) è in `localHolidays` per quando il motore lo userà.

## Fonti non ufficiali (solo controllo incrociato)

- Patrono San Giovanni Battista, 24 giugno: https://www.tuttitalia.it/toscana/22-san-giovanni-valdarno/ ; la sera del 24 giugno c'è la Notte Bianca in centro (https://it.wikivoyage.org/wiki/San_Giovanni_Valdarno).
- La Nazione Arezzo, 23/04/2026 (lavori tra via Giovanni da San Giovanni e corso Italia, accessi dedicati per i titolari ZTL, temporanei): https://www.lanazione.it/arezzo/cronaca/lavori-in-via-xx-settembre-le-modifiche-alla-viabilita-pa35e7no
- Elenco MIT dei comuni autorizzati al controllo elettronico dei varchi (gennaio 2026), che secondo la ricerca comprende San Giovanni Valdarno: https://mit.gov.it/nfsmitgov/files/media/normativa/2026-01/elencovarchi_27_01_2026.pdf (non scaricato: sito irraggiungibile).

## Da fare

- Trovare l'ordinanza del Sindaco con gli orari attuali e l'importo della multa (Albo Pretorio `servizi.comunesgv.it/openweb/albo/`, che dal workflow risponde 403).
- Chiedere alla Polizia Locale (polizialocale@comunesgv.it, 055 9126237): ospiti degli hotel, posizione di Largo Ceramica, se il 24 giugno vale come festivo per la ZTL.
