# Ascoli Piceno: fonti della scheda ZTL

Scheda generata da `Tools/ascoli_mappa.py` + `Tools/build_ascoli_piceno.py` → `Resources/Cities/ascoli-piceno.json` (stato **draft**, `reviewedByHuman: false`), nell'app tramite `manifest.json` dal 27/10/2026. Regole e citazioni **verificate** sui testi ufficiali letti il **27/10/2026** e salvati in `data/raw/ascoli-piceno/` (URL e data in testa a ogni file; il builder controlla ogni frase usata). Tutte le fonti sono su www.comune.ap.it (raggiungibile; nessun host bloccato, nessun archivio usato).

## Zone
| Zona | Orari (finestre) | Fonte della citazione |
|---|---|---|
| **Corso Mazzini est · ZTL a fascia ampia** (`ap-ztl-ampia-est`, varchi Carmine e Mercantini) | tutti i giorni 9:00–12:45 e 15:30–5:00 (`freeOnHolidays: false`) | pagina «ZTL e varchi» |
| **Canterine · ZTL a fascia ampia** (`ap-ztl-ampia-nord`, varchi Afranio e Tessitori) | idem | idem |
| **Vidacilio · ZTL a fascia ampia** (`ap-ztl-ampia-ovest`, varco Cairoli) | idem | idem |
| **Ventidio Basso · ZTL a fascia ridotta** (`ap-ztl-ridotta-ovest`, varchi Ventidio Basso, Fortezza, Corso di Sotto; ampliamento D.G.C. 194/2024) | feriali 20:30–5:00, domenica e festivi 0–24 (`holidaysAsSunday: true`; la notte dopo una domenica/festivo è tenuta chiusa fino alle 5) | ord. 713/2025 |
| **Corso Trento e Trieste · ZTL a fascia ridotta** (`ap-ztl-ridotta-trento`, varco XX Settembre) | idem | ord. 713/2025 |
| APU piazza del Popolo e piazza Arringo (`pedestrian`) | chiuse sempre (legenda «AREA PEDONALE URBANA 00:00 - 24:00») | mappa ufficiale, D.G.C. 37/2023 |

Citazione fascia ampia (https://www.comune.ap.it/flex/cm/pages/ServeBLOB.php/L/IT/IDPagina/11478, ufficiale): «Per le zone a traffico limitato esistenti, perimetrate con Deliberazione n. 123/2015 e successiva modifica con Deliberazione n. 37/2023 il transito veicolare è limitato ai soli autorizzati dalle ore 9:00 alle ore 12:45 e dalle ore 15:30 alle ore 05:00».

Citazione fascia ridotta (ordinanza dirigenziale 713 del 30/10/2025, https://www.comune.ap.it/flex/cm/pages/ServeBLOB.php/L/IT/IDPagina/26886, ufficiale): «La modifica del regime orario di limitazione al traffico veicolare nelle ZTL “a fascia ridotta” con orario di validità 20:30–05:00 nei giorni feriali e 0-24 nei giorni festivi.»

| Fatto | Fonte (letta il 27/10/2026) | Tipo |
|---|---|---|
| Orari attuali di fascia ampia (9–12:45, 15:30–5; varchi spenti 5–9 e 12:45–15:30) e fascia ridotta (feriali 20:30–5, festivi 0–24); elenco e posizione dei 9 varchi; moto e ciclomotori sempre ammessi; >3,5 t vietati; alberghi comunicano la targa alla struttura che la fa inserire in lista bianca; disabili di altri Comuni entro 48 ore; mappa ufficiale | pagina «ZTL e varchi: traffico a misura d'uomo» → `comune-ztl-e-varchi.txt` | ufficiale |
| Fascia ridotta 20:30–5 feriali, 0–24 festivi, in via sperimentale dal 03/11/2025, «per poi esser resa definitiva»; richiama l'ord. 775/2024 | ord. 713/2025 → `ordinanza-713-2025.txt`, comunicato → `comune-comunicato-ordinanza-713-2025.txt` | ufficiale |
| Deroga 28/11/2025–06/01/2026 (20:30–5 anche nei festivi): scaduta | ord. 781/2025 → `ordinanza-781-2025.txt`, `comune-comunicato-ordinanza-781-2025.txt` | ufficiale |
| Pre-esercizio dei nuovi varchi dall'1/10/2025, multe dall'1/11/2025; estensione festiva 0–24 solo per il varco XX Settembre | ord. 630/2025 → `ordinanza-630-2025.txt`; comunicato → `comune-comunicato-varchi-fascia-ridotta-2025.txt` | ufficiale |
| Sospensione temporanea varchi Carmine e Mercantini 24/08–11/09/2026: scaduta | ord. 524/2026 → `ordinanza-524-2026.txt`, `comune-ordinanza-524-2026-pagina.txt` | ufficiale |
| Nessuna ordinanza più recente su ZTL/varchi: titoli di tutte le pagine pubblicate (IDPagina 23000–28700, fine 2023 → 27/10/2026) | `elenco-pagine-ztl-2023-2026.txt` | ufficiale (elenco ricavato) |
| Regolamento ZTL/APU con gli elenchi delle vie (APU, fascia ampia ~210 vie, fascia ridotta 4 vie, solo sosta), alberghi entro 48 ore, elettriche pure con autorizzazione | D.G.C. 37/2023 → `dgc-37-2023.txt` | ufficiale |
| Ampliamento nord/ovest con i varchi Ventidio Basso, Fortezza, Corso di Sotto; intenzione di estendere a tutto il festivo «la limitazione oraria all'interno di tutte le ZTL» (documento istruttorio e regolamento non pubblicati) | D.G.C. 194/2024 → `dgc-194-2024.txt` | ufficiale |
| Schede «ZTL (fascia oraria ampia)» e «ZTL (fascia ridotta)» (quest'ultima con il vecchio 20:30–7:30), FAQ (vecchio 7:30–20:30), pagina regolamentazione accesso | `comune-ztl-fascia-ampia.txt`, `comune-ztl-fascia-ridotta.txt`, `comune-domande-risposte-varchi.txt`, `comune-regolamentazione-accesso.txt` | ufficiale, in parte superata |
| Mappa ufficiale dei varchi (PDF modificato il 16/03/2026) con legenda | `mappa-ufficiale-varchi-2026.pdf`, `mappa-ufficiale-varchi-2026.txt` | ufficiale |

Contraddizioni (nei pending): la pagina dei varchi dice per il varco XX Settembre «dalle 20:30 della sera alle 5:30 del mattino» e per Corso di Sotto aperto 7:30–20:30; scheda fascia ridotta e FAQ hanno ancora 20:30–7:30. Si segue l'ord. 713/2025 (più recente) e il riepilogo in testa alla stessa pagina. Fascia ampia nei festivi: la D.G.C. 194/2024 prevedeva l'estensione a tutto il festivo, ma l'unico atto attuativo trovato (ord. 630/2025) la applica solo al varco XX Settembre e la pagina 2026 dà gli stessi orari tutti i giorni; l'ord. 775/2024 non è pubblicata. Patrono (Sant'Emidio, 5 agosto): non inserito in `localHolidays`, nessuna fonte che lo tratti come festivo per la ZTL. Nessun permesso per turisti; multe non indicate.

## Geometria (dalla mappa ufficiale, non disegnata a mano)
- Open data: nessuno; OpenStreetMap (API OSM, 27/10/2026, riquadro 42.846–42.862 N, 13.560–13.596 E; estratto in `data/raw/geo/ascoli-piceno-centro.json`, © OpenStreetMap contributors, ODbL 1.0) non ha relazioni ZTL né telecamere.
- `Tools/ascoli_mappa.py`: rasterizza la mappa ufficiale 2026 a 100 dpi, classifica i colori della legenda (giallo fascia ampia, azzurro fascia ridotta, verde APU; tratteggi e simboli prendono il colore prevalente nel raggio di 6 px), aggancia la mappa con un'affine: partenza da 11 toponimi del PDF (pdftotext -bbox) abbinati a oggetti OSM omonimi, poi ricerca della massima sovrapposizione tra fabbricati tratteggiati della mappa e fabbricati OSM: 0,641 × 0,624 m/px, rotazione 0,6°, F1 fabbricati 0,67 (limitato da fabbricati mancanti in OSM). Controllo visivo dei fabbricati OSM sovrapposti alla mappa: scarti di pochi metri. Contorni semplificati a 3 m. Risultato `data/raw/ascoli-piceno/ztl-mappa-ufficiale.geojson`.
- Controlli nel builder con gli elenchi ufficiali: le vie dei varchi della fascia ampia (pagina «ZTL e varchi»: via Crispi, via della Tribù Fabia, via delle Canterine, via Sangallo, via Cairoli, corso Mazzini) cadono nelle zone gialle; le 12 vie dei nuovi varchi e 3/4 vie della fascia ridotta 2023 (piazza Simonetti non ha nome in OSM) nella zona azzurra; le vie APU nella zona verde o, per i tratti, nelle zone colorate; ogni zona sta per ≥ 90% (in proporzione alle strade OSM) entro 30 m da vie che gli elenchi mettono in ZTL; luoghi noti dentro ogni zona; piazza del Popolo e piazza Arringo solo APU; piazzale della Stazione, piazza Matteotti, largo Porta Romana e viale Federici fuori.
- Varchi: gli incroci descritti dalla pagina «ZTL e varchi» (punto più vicino tra le due strade OSM); controllati a vista sui simboli dei varchi della mappa.
- **Non disegnato (pending)**: vie della fascia ampia della D.G.C. 37/2023 fuori dalle zone con varchi e senza telecamere, soprattutto a sud di piazza Arringo (piazza San Gregorio, via dei Marsi, via di Vesta, via Capitolina, via della Piazzarola…) e vicino a Porta Solestà (rua della Musica, rua dei Salvioni): la mappa ufficiale non le copre e un perimetro dalle sole vie sarebbe incerto (vie lunghe elencate per intero, rue mancanti in OSM).

## Moto e scooter (1.17.1)
`exemptVehicleTypes: ["motorcycle"]` su tutte e cinque le zone (sono tutte ZTL, non APU): *"I motoveicoli e i ciclomotori sono sempre autorizzati a transitare nelle sole Zone a Traffico Limitato, anche con varchi attivi."* (regolamento ZTL e APU, D.G.C. 37/2023).
