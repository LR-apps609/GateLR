# Cortona: fonti della scheda ZTL

Scheda generata da `Tools/build_cortona.py` → `Resources/Cities/cortona.json` (stato **draft**, `reviewedByHuman: false`). Dal 27/10/2026 è **nell'app** (`manifest.json`) e sul sito, con due zone (ZTL Rossa e ZTL Gialla), aree ricavate dall'elenco ufficiale delle strade su OpenStreetMap.

## Fonti ufficiali lette (27/10/2026)
| Fatto | URL | Tipo | Letto il |
|---|---|---|---|
| **Citazioni**: ZTL Rossa 1/10–30/4 10–20, 1/5–30/9 10–4; ZTL Gialla 1/10–30/4 11–14 e 17–20, 1/5–30/9 10–15 e 16–4; «tutti i giorni, festivi compresi»; vietati transito e sosta anche a ciclomotori e motocicli; permessi temporanei gratuiti, risposta immediata o entro 7 giorni; modulo per la password delle strutture ricettive | https://www.comune.cortona.ar.it/servizi/autorizzazioni/accesso-ztl (agg. 15/04/2025) → `data/raw/cortona/comune-servizio-accesso-ztl.txt` | ufficiale | 27/10/2026 |
| Stessi orari; elenco delle strade di Rossa e Gialla (art. 2); strutture ricettive e disabili possono registrare la targa entro 48 ore; tre varchi (piazzale del Mercato per via Guelfa/Porta S. Agostino, via Roma per piazza Repubblica, via Nazionale); sempre ammessi velocipedi e veicoli a braccia; «La semplice richiesta non abilita alla circolazione» | Disciplinare ZTL Rossa e Gialla, testo coordinato D.G.C. 88/2019, https://www.comune.cortona.ar.it/document/open?id=436 → `disciplinare-ztl-rossa-gialla-2019.txt` | ufficiale | 27/10/2026 |
| Ordinanza n. 110 del 26/04/2019 (dal 01/05/2019): orario estivo della Rossa e della ZTL via Benedetti 10–4 | https://www.comune.cortona.ar.it/document/open?id=429 → `ord-110-2019.txt` | ufficiale | 27/10/2026 |
| Ordinanza n. 214 del 28/09/2018: intera piazza Signorelli, Croce del Travaglio e via Casali nella Rossa; ZTL via Benedetti | https://www.comune.cortona.ar.it/document/open?id=430 → `ord-214-2018.txt` | ufficiale | 27/10/2026 |
| Schede tecniche (D.G.C. 27/2016): permesso per i clienti delle strutture ricettive per la durata del soggiorno, solo nella zona della struttura | https://www.comune.cortona.ar.it/document/open?id=437 → `schede-tecniche-2016.txt` | ufficiale | 27/10/2026 |
| Elenco degli atti sulle ZTL | https://www.comune.cortona.ar.it/amministrazione/documenti-e-dati/atto-normativo/atti-normativi-ztl-rossa-ztl-gialla-e-ztl-di-via-benedetti → `comune-atti-normativi-ztl.txt` | ufficiale | 27/10/2026 |
| Sospensioni a calendario della ZTL di Viale Passerini (giugno–settembre 2026) | https://www.comune.cortona.ar.it/novita/comunicati/viale-passerini-programmazione-trimestrale-della-sospensione-della-ztl-3 → `comune-2026-06-10-passerini-sospensione.txt` | ufficiale | 27/10/2026 |

Fonti non ufficiali: tyremap.com (orari uguali, «circa»), solo per incrocio. Nessun open data (dati.toscana.it ha solo Firenze).

## Come sono modellati gli orari
- Due stagioni, tutti i giorni (`freeOnHolidays: false`): estate 1/5–30/9, inverno 1/10–30/4. Le fasce fino alle 4 appartengono al giorno d'inizio.
- Patrono: la ZTL vale anche nei festivi, quindi `localHolidays` non serve.

## Geometria
- OpenStreetMap (© OpenStreetMap contributors, ODbL 1.0), scaricato il 27/10/2026 dall'API principale con `Tools/fetch_osm_api.py` e ridotto in `data/raw/geo/cortona-ztl.json` (strade con nome del centro e porte). Nessuna relazione ZTL in OSM.
- Area = `osm_geo.street_area` sulle strade dell'art. 2. Nomi OSM diversi dal disciplinare: Vicolo Aurora, Vicolo Precipizio, Piazza Luca Signorelli, Vicolo Semini (Sernini), Via Beato Guido, Via del Giardino, Via Armaioli, Via delle Mura del Mercato, Via San Benedetto, Vicolo della Fogna, Vicolo Fabrucci, Vicolo Vagnucci, Vicolo Corazzio, «Via Sant 'Agostino» (vicolo S. Agostino). Mancano in OSM: vicolo Alticozzi, vicolo Baldacchini, vicolo e piazza Alfieri, vicolo Baldelli, Croce del Travaglio (Rossa); vicolo del Cipresso, piazza Diligenti, vicolo della Luna, vicolo Cattani (Gialla).
- Tratti parziali: via Roma (Gialla) solo way 106400220, 577429372, 577429371, da piazza della Repubblica al nodo 1376098527 (incrocio via Ghini/via Zefferini); vicolo Venuti (diviso al civico 13/14, posizione non nota) way 244588314, 577435811, 712709164, 712709163 nella Rossa e 577435812 nella Gialla; vicolo della Scala (fino a vicolo dell'Amorino) nella Rossa. Le zone si sovrappongono un poco attorno a piazza della Repubblica.
- Varchi: nodo 4581048295 (via Nazionale a piazzale Garibaldi), nodo 702185098 (via Roma a piazza della Repubblica), nodo 5535568192 (via Guelfa a Porta Sant'Agostino). Posizioni esatte delle telecamere non pubblicate.
- Controlli: piazza Signorelli e piazza della Repubblica nella Rossa; via Guelfa e via Ghibellina nella Gialla; piazza del Duomo, piazzale Garibaldi, piazzale del Mercato, Santuario di Santa Margherita e Porta Colonia fuori da entrambe. Aree 0,015 e 0,053 km².

## Pending (nella scheda)
Registrazione hotel entro 48 ore e permessi temporanei; nessuna esenzione per elettriche; area non ufficiale; ZTL via Benedetti / Viale Passerini (stessi orari della Rossa) non disegnata.

## Moto e scooter (1.17.1)
Nessuna esenzione: *"all'interno della Z.T.L. sono vietati il transito e la sosta a tutti i veicoli (compresi ciclomotori e motocicli)"* → «Non entrare».
