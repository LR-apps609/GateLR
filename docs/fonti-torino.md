# Torino: fonti della scheda ZTL

Scheda generata da `Tools/build_torino.py` → **`Resources/Cities/torino.json`**, nell'app come bozza (`status: draft`, `reviewedByHuman: false`).
Ricerca del **25/10/2026**. Il materiale è salvato in `data/raw/torino/` e le geometrie OSM in `data/raw/geo/torino-*.json`.

## Testi ufficiali: come sono stati letti

Dall'ambiente di lavoro e da GitHub Actions **nessun sito ufficiale di Torino si raggiunge**. `www.comune.torino.it` chiude la connessione durante l'handshake TLS; `gtt.to.it`, `opendata.5t.torino.it` e `geoportale.comune.torino.it` ricevono 403 dal proxy.
Per questo l'utente ha aperto le pagine e ha inviato schermate e PDF. Per tutti i file qui sotto la provenienza è la stessa: **testo della pagina ufficiale copiato dall'utente il 25/10/2026 (sito irraggiungibile da qui)**.

| File in `data/raw/torino/` | Contenuto |
|---|---|
| `comune-scheda-ztl-centrale-utente.txt` + `schermata-comune-ztl-centrale-9/10/11.png` | Scheda del Comune «ZTL Centrale», sezione «Circolare nella Zona a Traffico Limitato»: https://www.comune.torino.it/schede-informative/ztl-centrale |
| `gtt-alberghi-utente.txt` + `schermata-gtt-alberghi-8.png` | GTT «Utenti che pernottano in strutture alberghiere»: https://www.gtt.to.it/cms/ztl/3681-utenti-che-pernottano-in-strutture-alberghiere |
| `mappa-ztl-internet.pdf` + `mappa-ztl-internet-testo.txt` | La mappa ufficiale «ZTL - Città di Torino», il link «Scarica la mappa della ZTL in formato PDF» della scheda. Il PDF è stato modificato il 15/01/2026 e non ha un livello di testo: la legenda e le scritte sono trascritte dall'immagine. |

La trascrizione delle schermate è stata ricontrollata carattere per carattere sulle immagini. Ho corretto sei apostrofi, che sulla pagina sono tipografici (’) e non diritti: «L’autorizzazione» (2 volte), «all’Albergo», «dell’Euro 0», «L’accesso», «un’apposita». Le citazioni le confronta `build_torino.py`, che tratta i due apostrofi come uguali.
Restano controllate solo sugli **estratti di ricerca** (`ricerca-web-2026-10-25.txt`) le regole che non compaiono in queste pagine: i 10 giorni per l'esenzione a posteriori, le ore 11 per i parcheggi in struttura, «tutti i giorni, festivi compresi» per Area Romana e corsie riservate, le moto Euro 1 a 4 tempi e la sospensione d'agosto. Nella scheda questo è detto nei punti in sospeso.

## Zone nella scheda

| Zona | Orario | Festivi | Geometria | Varchi |
|---|---|---|---|---|
| **ZTL Centrale** (`torino-centrale`) | lun–ven 7:30–10:30 | spenta (`freeOnHolidays: true`) | relazione OSM 19152960, controllata e corretta sulla mappa ufficiale | 27 |
| **ZTL Area Romana** (`torino-area-romana`) | tutti i giorni 21:00–7:30 | attiva | tratteggio della mappa ufficiale | 2 |
| **Strade riservate al trasporto pubblico** (`torino-tp-1…10`) | tutti i giorni 7:00–20:00 | attive | way OSM `zone:traffic:name=Strade riservate al Trasporto Pubblico` | 8 (6 interni + gli accessi di via Milano e via Rossini) |
| **ZTL Pedonale** (`pedestrian`, 8 aree) | h24 | attive | way OSM `zone:traffic:name=ZTL Pedonale` | — |

`localHolidays` è stato tolto: il 24 giugno non è più contato come festivo (vedi sotto).

## Fatti → fonte (letti il 25/10/2026)

| Fatto | Fonte | Tipo |
|---|---|---|
| «dalle 7.30 alle 10.30 di tutti i giorni feriali (sabato escluso), sono vietate la circolazione e la sosta» (art. 158 CdS) nella ZTL Centrale. Durante il divieto circolano solo i veicoli autorizzati. | scheda «ZTL Centrale» | ufficiale, copiata dall'utente |
| Perimetro: «corso Vittorio Emanuele II, piazza Carlo Felice, corso Re Umberto (tratto …), corso Matteotti (tratto …), via Vittorio Amedeo II, corso Palestro, corso Regina, piazza della Repubblica, viale Primo Maggio, viale Partigiani (tratto …), corso San Maurizio, lungo Po Cadorna, piazza Vittorio Veneto, lungo Po Diaz, corso Cairoli, esclusi». Le strade di confine sono fuori dalla ZTL. | idem | ufficiale, copiata dall'utente |
| Telecamere: «27 punti» per l'accesso, «11 punti» per la circolazione interna nelle aree con altre limitazioni, «3 punti» fuori (aree Statuto e Valperga, accesso all'area Valentino). In tutto «41 punti di controllo». | idem; i 41 pallini della mappa ufficiale | ufficiale |
| Si circola con un permesso della Città o di GTT, oppure con un'«autorizzazione alla circolazione senza permesso». Il permesso richiede un veicolo «EURO 3 o superiore», oppure «EURO 2 o superiore alimentati a GPL e/o Metano». | idem | ufficiale, copiata dall'utente |
| Normativa: DGC mecc. 2010 00659 del 12/02/2010; DGC mecc. 2010 02058 del 27/04/2010; Ordinanza Dirigenziale n. 2547 del 28/05/2010 e s.m.i.; Ordinanza Dirigenziale n. 2455 del 29/05/2012. Il campo `ordinance` della scheda le riporta. | idem | ufficiale, copiata dall'utente |
| Hotel: l'autorizzazione vale solo per le strutture «accreditate e regolarmente registrate in Piattaforma ZTL». «Al momento del check-in» l'ospite compila la richiesta «per il periodo di permanenza». Le vie e corsie riservate sono aperte all'ospite solo «il giorno di arrivo» e «il giorno di partenza»; per i giorni intermedi si chiede all'albergo quali varchi sono abilitati. Niente autorizzazione per i veicoli sotto fermo amministrativo o senza revisione o assicurazione, né per quelli «inferiore all'Euro 3 se non muniti di impianto GPL», con l'eccezione degli «Euro 0 GPL/Metano non esentabili». | GTT, pagina alberghi | ufficiale (GTT), copiata dall'utente |
| Legenda della mappa: ZTL Centrale «dalle 7:30 alle 10:30»; Area Romana «dalle 21:00 alle 7:30», carico e scarico 10:30–16:00; ZTL Pedonale «dalle 0:00 alle 24:00»; Strade riservate al Trasporto Pubblico «dalle 7:00 alle 20:00», carico e scarico 10:30–12:30 | mappa ufficiale (PDF) | ufficiale, inviata dall'utente |
| Area Romana e Trasporto Pubblico attive «tutti i giorni, festivi compresi». In piazza Emanuele Filiberto il divieto inizia alle 19:30. | estratti di ricerca della scheda | ufficiale, solo estratto |
| Esenzione a posteriori «tassativamente 10 (dieci)» giorni; parcheggi in struttura: targa al gestore «entro e non oltre le ore 11.00» | estratti di ricerca | ufficiale, solo estratto |
| Moto e ciclomotori esenti «se Euro 1, a 4 tempi» | GTT «Elenco veicoli esentati» (estratto) | ufficiale, solo estratto |
| Agosto 2026: ZTL Centrale sospesa dal 10 al 23/08 | comunicato del Comune (estratto) | ufficiale, solo estratto |
| 24 giugno: «di consueto la ZTL centrale non sarà attiva» | quotidianopiemontese.it (2019) | **solo non ufficiale** |
| Multa: 83–332 € (art. 7 CdS) | guide non ufficiali | non ufficiale |

### Festivi e 24 giugno

La scheda dice «giorni feriali (sabato escluso)», quindi nei festivi infrasettimanali la ZTL Centrale è spenta (`freeOnHolidays: true`).
San Giovanni, il 24 giugno, è la festa del patrono di Torino. Però nessun testo ufficiale salvato dice che quel giorno la ZTL è spenta: lo dice solo un articolo del 2019. Per questo `localHolidays: ["06-24"]` è stato **tolto** e il caso è tra i punti in sospeso. Quel giorno GateLR mostra la ZTL attiva, che è la scelta prudente.

## Mappa ufficiale → geometria (`Tools/torino_mappa.py`)

Lo script usa numpy, Pillow e pdftoppm, e i suoi strumenti raster sono quelli di `lucca_mappa.py`. Legge `mappa-ztl-internet.pdf` e scrive `data/raw/torino/mappa-ztl-ufficiale.json`. Niente è disegnato a mano:
1. **Aggancio.** La linea verde «ZTL Centrale» della mappa viene sovrapposta al contorno della relazione OSM 19152960 con una trasformazione affine (ICP), a 1,84 m per pixel. Risultato: il contorno OSM sta dalla linea verde a una distanza mediana di 1,3 m e, per il 90% della lunghezza, entro 11,5 m. Gli scarti più grandi sono sotto i pallini dei varchi, che coprono la linea.
2. **Pallini «Porte elettroniche Esistenti».** Lo script ne trova 41: 27 sul bordo (meno di 55 m dal contorno), 11 dentro e 3 fuori. Sono esattamente i numeri della scheda del Comune, e `build_torino.py` lo controlla. Ogni varco è messo sul nodo più vicino della strada OSM più vicina; la mappa non dà nomi ai varchi.
   - **Accessi (27)**: via C. I. Giulio, via Milano, via P. Egidi (piazza della Repubblica), viale Primo Maggio, via Rossini, via San Domenico, via G. Ferrari, via Bertrandi, via Juvarra, via Po, via Principe Amedeo e via Plana (piazza Vittorio Veneto), via Cernaia, via Valfrè, via Giolitti, via De Sonnaz, via Donati, via Avogadro, corso Galileo Ferraris, corso Re Umberto, via dei Mille, corso Matteotti, via Melchiorre Gioia, via Carlo Alberto, via Accademia Albertina, via San Massimo, via della Rocca.
   - **Interni (11)**: 2 sul bordo dell'Area Romana (via Bonelli e via Santa Chiara, assegnati a quella zona); 6 su strade riservate (via Milano, via XX Settembre ×2, via Pietro Micca / San Francesco d'Assisi, via Accademia Albertina ×2, assegnati alle zone `torino-tp-*`); 3 non assegnati, vicino a via Verdi (via Rossini), via Gramsci e via San Quintino (via dell'Arsenale). Su quei tre punti il viola della mappa continua un po' oltre le way OSM.
   - **Esterni (3)**: piazza Statuto, Valentino e via Valperga Caluso. Non sono nella scheda.
3. **Controllo del perimetro.** La ZTL Centrale della mappa (linea verde chiusa) diventa un poligono. In `build_torino.py` i vertici OSM che cadono fuori da quel poligono per più di 20 m vengono sostituiti dal tratto corrispondente della mappa. È successo solo in un punto: **piazza della Repubblica**, dove OSM includeva un angolo della piazza (circa 40 m) che il Comune esclude, perché la piazza è una strada di confine «esclusa». Il resto del perimetro OSM coincide con la mappa. Controlli: piazza Castello e piazza San Carlo sono dentro; Porta Nuova e Porta Susa sono fuori. Superficie 2,72 km².
4. **Area Romana.** Il tratteggio marrone, chiuso dalla linea verde e dai pallini, diventa un poligono di circa 0,07 km² (il Quadrilatero, a ovest di via Milano). La precisione è di circa ±20 m, e attorno ai due pallini il bordo rientra un po'.

Le **strade riservate** OSM coincidono con le strade viola della mappa. Le **aree pedonali** OSM sono quelle arancioni della mappa dentro la ZTL.

Per rifare: `python3 Tools/torino_mappa.py` (solo se cambia la mappa, ~4 minuti), poi `python3 Tools/build_torino.py`, `python3 Tools/build_manifest.py`, `python3 Tools/build_site.py`.

## Geometria: provenienza e licenza

I perimetri e le strade vengono da **OpenStreetMap** (© OpenStreetMap contributors, ODbL 1.0, scritto in `license`). I file sono `data/raw/geo/torino-ztl.json` e `torino-gates.json`, presi dal ramo `geo-data`.
L'Area Romana e la posizione dei varchi sono ricavate dalla mappa ufficiale del Comune. È un'approssimazione: la mappa non ha coordinate.
I dati aperti ufficiali (5T «Perimetro, varchi e orari ZTL», geoportale «Zone Traffico Limitato», CC BY 4.0) restano non scaricabili da qui. I metadati sono in `data/raw/torino/dati.gov.it_*.json`.

## Zone trovate ma non ancora sulla mappa (solo nei punti in sospeso)

- **ZTL Valentino**: viali del parco, chiusa h24 (estratto della scheda). Sulla mappa ufficiale c'è il pallino dell'accesso, «VALENTINO». La Giunta ha approvato l'ampliamento il 24/03/2026 (viale Medaglie d'Oro, tratto nord di viale Ceppi), ma non ho trovato una data di attivazione. Manca il perimetro.
- **Aree Statuto e Valperga**: hanno una telecamera ciascuna fuori dalla ZTL Centrale, secondo la scheda e la mappa. Le regole non sono descritte.
- **ZTL notturna Monte dei Cappuccini** (tutti i giorni 23:00–7:00, dal 2025) e **Borgo Campidoglio** (pedonale h24 dal 01/12/2025): vengono dai comunicati del Comune (estratti) e non sono sulla mappa ufficiale, che è precedente.
- **Limitazioni antismog** su tutto il territorio comunale: fonti solo non ufficiali, non sono nella scheda.

## Da verificare

- La revisione umana (`reviewedByHuman: false`).
- Rileggere sulle pagine ufficiali le regole viste solo negli estratti: 10 giorni, ore 11, «tutti i giorni, festivi compresi» per Area Romana e corsie riservate.
- Il 24 giugno, con un avviso ufficiale.
- Sostituire perimetri e varchi con i dati 5T/geoportale (CC BY 4.0) quando si potranno scaricare.
- Aggiungere Valentino, Monte dei Cappuccini e Borgo Campidoglio.
- `Tools/fetch_geo.py` (blocco «Torino») scarica ancora le pagine del Comune e di GTT, ma `build_torino.py` non le usa più. Se un giorno arrivano, conviene confrontarle con le trascrizioni.

## Moto e scooter (1.17.1)
Nessuna esenzione nel modello: GTT esenta moto e ciclomotori solo *"se Euro 1, a 4 tempi"* (e non nell'Area Romana); GateLR non conosce il tipo di motore, quindi la risposta resta quella delle auto («Non entrare» a ZTL attiva). Da rivedere se arriva un campo per le condizioni.
