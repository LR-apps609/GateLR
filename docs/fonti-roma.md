# Roma: fonti dei dati (bozza)

Stato: **draft**, ma dal 24/10/2026 **nell'app** (`Resources/Cities/roma.json`, in `manifest.json`) con perimetri e varchi da OpenStreetMap (vedi sezione 4). Fonti lette il **24/10/2026**. Nessuna verifica umana (`reviewedByHuman: false`).
File generato: `Resources/Cities/roma.json`, con lo script `Tools/build_roma.py`. Lo script legge i testi salvati in `data/raw/roma/` e si ferma se una delle frasi citate non c'è più parola per parola.
Tutte le pagine sono di **Roma Servizi per la Mobilità (RSM)**, l'agenzia di Roma Capitale che gestisce le ZTL e i permessi.

## 1. Fatti e fonti

| Fatto | Fonte (letta il 24/10/2026) | File salvato | Stato |
|---|---|---|---|
| Centro Storico diurna: «6.30-18.00 da lunedì a venerdì (esclusi i festivi) 14.00-18.00 il sabato (esclusi i festivi)» | https://romamobilita.it/muoversi-a-roma/ztl-in-centro/ (aggiornata il 28/07/2026) | `ztl-in-centro.txt` | verificato |
| Centro Storico notturna: «23.00-3.00 venerdì e sabato (esclusi i festivi) nel mese di agosto la ZTL notturna non è attiva» | come sopra | `ztl-in-centro.txt` | verificato |
| Tridente (A1): «6.30-19.00 da lunedì a venerdì (esclusi i festivi); 10.00-19.00 il sabato (esclusi i festivi)»; qui anche moto e ciclomotori hanno bisogno del permesso | come sopra | `ztl-in-centro.txt` | verificato |
| Trastevere diurna: «dalle 6.30 alle 10.00 dal lunedì al sabato (esclusi i festivi)» | come sopra | `ztl-in-centro.txt` | verificato |
| Trastevere notturna: «dalle 21.30 alle 3.00 venerdì e sabato (anche se festivi) da maggio a ottobre è attiva anche il mercoledì e il giovedì (anche se festivi) … nel mese di agosto la ZTL notturna non è attiva» | come sopra | `ztl-in-centro.txt` | verificato (ma vedi 3.1) |
| San Lorenzo notturna: stesso orario di Trastevere notturna, «è chiusa alle automobili», «anche se festivi», agosto non attiva | come sopra | `ztl-in-centro.txt` | verificato (ma vedi 3.1) |
| Testaccio notturna: «dalle 23.00 alle 3.00 venerdì e sabato (esclusi i festivi); nel mese di agosto la ZTL non è attiva» | come sopra | `ztl-in-centro.txt` | verificato |
| Mini guida agli orari (Trastevere e San Lorenzo notturne «dal mercoledì al sabato», senza stagione) | https://romamobilita.it/infomobilita/ztl-tutti-gli-orari/ (aggiornata il 21/10/2026) | `ztl-tutti-gli-orari.txt` | in contrasto con la pagina di dettaglio |
| Le diurne restano attive ad agosto; le notturne tornano a settembre (Trastevere e San Lorenzo dal mercoledì 3/9/2025) | https://romamobilita.it/infomobilita/sono-di-nuovo-in-vigore-tutte-le-ztl-notturne/ (09/09/2025) | `sono-di-nuovo-in-vigore-tutte-le-ztl-notturne.txt` | verificato (notizia del 2025) |
| Nessun permesso giornaliero per i turisti: i permessi temporanei sono solo per alcune categorie (impedimenti fisici, merci, servizi tecnologici, trasporto funebre, eventi); costo 10 € al giorno + 16 € + 16 € di bollo + 60 € di diritti | https://romamobilita.it/servizi-al-pubblico/permessi-temporanei/ (aggiornata il 07/05/2026) | `permessi-temporanei.txt` | verificato |
| Autorizzazioni giornaliere gratuite solo per figure istituzionali, medici, persone con disabilità di altri Comuni, taxi di altri Comuni, carri attrezzi | https://romamobilita.it/servizi-al-pubblico/autorizzazioni-giornaliere/ | `autorizzazioni-giornaliere.txt` | verificato |
| Alberghi: permesso X valido nelle ZTL diurne «Centro Storico» (tranne A1 Tridente) e «Trastevere»; «1 permesso ogni 10 stanze»; le targhe si inseriscono sullo sportello online «Hotel, autorizzazione per i clienti» | https://romamobilita.it/servizi-al-pubblico/permesso-x-circolazione-e-sosta/ (aggiornata il 07/05/2026) | `permesso-x-circolazione-e-sosta.txt` | verificato |
| Alberghi: fasce mattutina 6:30–14, pomeridiana 14:01–18, giornaliera 6:30–18, notturna 23–3 (solo venerdì e sabato); la targa si comunica «entro la medesima giornata dell'effettivo accesso» nella ZTL dove ha sede l'albergo | https://romamobilita.it/wp-content/uploads/2016/06/ZTL_Regolamento_Alberghi.pdf (PDF del 21/08/2018) | `ZTL_Regolamento_Alberghi.pdf` e `.txt` | verificato |
| Elettriche e idrogeno: dal 1/7/2026 serve il permesso; «Non sarà più possibile accedere gratuitamente solo perché il veicolo è a basse emissioni»; per chi non ha diritto al permesso ordinario «€ 1.000 con validità annuale», richiesta con SPID o CIE (Deliberazione G.C. n. 63 del 27/02/2026) | https://romamobilita.it/servizi-al-pubblico/accesso-in-ztl-di-veicoli-elettrici-o-a-idrogeno-novita-dal-1-luglio-2026/ (aggiornata il 08/06/2026) | `accesso-in-ztl-…-1-luglio-2026.txt` | verificato, quindi `exemptFuels: []` |
| ZTL Appia Antica: dal 19/09/2026, sabato e domenica 7–19, escluso agosto; si può entrare solo se si esce dallo stesso varco nello stesso giorno (vietato l'attraversamento) | https://romamobilita.it/muoversi-a-roma/ztl-appia-antica/ (08/09/2026) e https://romamobilita.it/servizi-al-pubblico/permesso-ztl-appia-antica/ | `ztl-appia-antica.txt`, `permesso-ztl-appia-antica.txt` | verificato, ma **non inserita** (vedi 3.4) |
| Orari speciali di Capodanno (esempio 2022/23) | https://romamobilita.it/comunicato/ztl-orari-capodanno-centro-varchi-attivi-630-31-dicembre-20-primo-gennaio/ | `ztl-orari-capodanno-2022.txt` | solo come esempio di eccezione (nota «pending») |
| Dati geografici: «dataset … in formato GeoServices REST», licenza CC BY 3.0 IT (link a https://creativecommons.org/licenses/by/3.0/it/), hub https://data-rsm.opendata.arcgis.com; la pagina open data cita «i confini e i varchi delle ZTL» | https://romamobilita.it/sistemi-e-tecnologie/dataset-geografici/ (27/11/2023), https://romamobilita.it/sistemi-e-tecnologie/open-data/ | `dataset-geografici.txt`, `open-data.txt` | licenza dichiarata dalla pagina; dati **non scaricati** |

## 2. Come sono state modellate le regole

- **6 zone**, tutte `kind: "restricted"` (nessun biglietto per i turisti): `roma-centro`, `roma-tridente`, `roma-trastevere` (diurna), `roma-trastevere-notte`, `roma-san-lorenzo`, `roma-testaccio`.
- **Centro Storico**: diurna e notturna sono finestre della stessa zona, perché la pagina parla della stessa ZTL ed entrambe dicono «esclusi i festivi» (`freeOnHolidays: true`).
- **Trastevere**: diurna e notturna sono **zone separate**, perché la regola sui festivi è diversa («esclusi i festivi» di giorno, «anche se festivi» di notte) e `freeOnHolidays` vale per zona.
- **Agosto**: `season` dice quando la finestra vale, quindi ogni finestra notturna è divisa in due (1/1–31/7 e 1/9–31/12). Mercoledì e giovedì di Trastevere e San Lorenzo: 1/5–31/7 e 1/9–31/10.
- Giorni: 1 = domenica … 7 = sabato. Le finestre notturne hanno `end < start` (finiscono il giorno dopo); il motore usa la stagione del giorno in cui la finestra comincia.
- **Hotel** (`hotelCanRegister`): `true` per Centro Storico (fasce diurne e fascia notturna 23–3 del regolamento) e Trastevere diurna; `false` con nota «pending» per Tridente (il permesso X lo esclude), Trastevere notturna, San Lorenzo e Testaccio (le fonti non dicono che l'albergo possa registrare i clienti in queste ZTL).
- **Elettriche**: nessuna esenzione dal 1/7/2026.
- Moto e ciclomotori (liberi tranne Tridente) sono solo nel riassunto: il modello è per le auto.

## 3. Dubbi e punti da verificare

1. **Mercoledì e giovedì delle notturne**: la pagina di dettaglio dice «da maggio a ottobre», la mini guida (aggiornata il 21/10/2026) dice «dal mercoledì al sabato» senza stagione. Il file segue la pagina di dettaglio. Dal 1° novembre le due fonti danno risposte diverse: va chiesto a RSM.
2. **Festivi e ore dopo mezzanotte**: il motore controlla il festivo sul giorno di calendario attuale, non su quello in cui la notte è cominciata. Per esempio, la notte di sabato 26/12/2026 (Santo Stefano) nel Centro: fino a mezzanotte GateLR dice «libero» (festivo), dopo mezzanotte (domenica 27/12, che per il motore non è festivo) dice «chiuso», anche se la finestra 23–3 è cominciata il sabato festivo. È un limite del motore, non dei dati.
3. **29 giugno** (Santi Pietro e Paolo, patroni di Roma): non è nella lista dei festivi del motore (`ItalianHolidays`) e non sappiamo se RSM lo considera «festivo».
4. **ZTL Appia Antica non inserita**: la regola (si entra ma si deve uscire dallo stesso varco lo stesso giorno) non si può rappresentare con il modello attuale, e la zona è un tratto di strada (via Appia Antica nn. 1–114, via Ardeatina nn. 108–172 pari) senza geometria ufficiale scaricata. Non è nemmeno scritto se valga nei festivi infrasettimanali.
5. **Tridente e notte**: non è scritto se la ZTL notturna del Centro Storico valga anche nel Tridente (che geograficamente dovrebbe stare dentro il Centro: da verificare con i perimetri).
6. **Orari speciali** (Capodanno, scioperi, eventi): il Comune li cambia con avvisi puntuali; nota «pending» su ogni zona.
7. **Agosto e prima notte**: una notte cominciata il 31 luglio finisce l'1 agosto alle 3; il file la considera attiva (la finestra comincia a luglio).

## 4. Geometria (perimetri e varchi)

**Da OpenStreetMap, non ufficiale** (© OpenStreetMap contributors, ODbL 1.0; dichiarato nel campo `license` e in un link per zona).
Dati scaricati con `Tools/fetch_geo.py` (GitHub Actions, Overpass `out geom`) in `data/raw/geo/roma-ztl.json` e `roma-gates.json`.
Il contorno si ricava con `Tools/osm_geo.py` (`outer_ring`: way «outer» unite testa-coda, anello più grande) e si semplifica con Douglas-Peucker a 5 m.
Ogni zona ha la nota «Perimetro da OpenStreetMap, da verificare con la mappa ufficiale».

| Zona GateLR | Relazione OSM | Punti | Area | Varchi |
|---|---|---|---|---|
| `roma-centro` | [2459882](https://www.openstreetmap.org/relation/2459882) «ZTL Diurna Centro Storico» | 99 | 4,25 km² | 13 |
| `roma-tridente` | [2459883](https://www.openstreetmap.org/relation/2459883) «ZTL Tridente» | 36 | 0,48 km² | 5 |
| `roma-trastevere` | [2572441](https://www.openstreetmap.org/relation/2572441) «ZTL Diurna Trastevere» | 54 | 0,81 km² | 7 |
| `roma-trastevere-notte` | [2691714](https://www.openstreetmap.org/relation/2691714) «ZTL Notturna Trastevere» | 55 | 0,81 km² | 7 |
| `roma-san-lorenzo` | [2573006](https://www.openstreetmap.org/relation/2573006) «ZTL Notturna San Lorenzo» | 16 | 0,26 km² | 7 |
| `roma-testaccio` | [2573007](https://www.openstreetmap.org/relation/2573007) «ZTL Notturna Testaccio» | 16 | 0,27 km² | 10 |

Note:
- **Centro notturna**: in OSM c'è anche la [2573034](https://www.openstreetmap.org/relation/2573034) «ZTL Notturna Centro Storico», più piccola (2,29 km²). Siccome `roma-centro` ha nella stessa zona le finestre diurne e notturne, si usa il perimetro diurno, più ampio. Di notte quindi GateLR può avvisare anche in strade fuori dalla notturna (nota «pending» apposita). Per correggere bisognerebbe dividere la zona in due.
- **Trastevere**: la relazione notturna esiste e si usa per `roma-trastevere-notte`. In OSM ha in pratica lo stesso contorno della diurna.
- **Tridente**: sta dentro il Centro (piazza di Spagna risulta in tutte e due le zone). Questo risponde al punto 3.5 sulla geometria, non sulla regola notturna.
- **Varchi**: sono i nodi `man_made=surveillance` con nome «Varco ZTL…» (nodi «device» delle relazioni `type=enforcement` oppure nodi sciolti), tenuti se stanno a meno di 50 m dal bordo della zona. I varchi chiamati «Tridente» o «San Lorenzo» vanno solo a quelle zone. Sono esclusi le telecamere delle corsie preferenziali, gli autovelox, i nodi senza tag e i varchi lontani dal bordo (diversi «Varco ZTL» interni al Centro, a 60–300 m dal perimetro OSM). I doppioni a meno di 15 m sono tolti. Gli id sono `rm-osm<id nodo>`. In OSM quasi tutti si chiamano solo «Varco ZTL», senza la via.
- In `roma-ztl.json` ci sono anche «ZTL Anello Ferroviario» (2459896, 43 km²) e «Fascia Verde» (2461289, ZTL ambientale, 156 km²). **Non sono usate**: le regole non sono state verificate. L'Anello serve solo come controllo (il Centro gli sta dentro).
- **Controlli fatti il 24/10/2026** (`Tools/osm_geo.py`): anelli chiusi; coordinate dentro 41,85–41,93 / 12,43–12,54; Pantheon (41,8986, 12,4769) nel Centro; piazza di Spagna (41,9058, 12,4823) nel Tridente; S. Maria in Trastevere (41,8895, 12,4699) in Trastevere di giorno e di notte; Termini (41,9009, 12,5016) e piazza della Repubblica (41,9028, 12,4964) fuori da tutte le zone.

**Dati ufficiali, ancora da scaricare.** La ricerca sull'hub RSM (`data/raw/geo/roma-hub-ztl.json`, `roma-hub-varchi.json`) elenca questi layer FeatureServer (`https://services2.arcgis.com/NZMqCJwY3kMjFOqf/arcgis/rest/services/<nome>/FeatureServer`). La licenza dichiarata sulle schede è **CC-BY-4.0** (non CC BY 3.0 IT come dice la pagina di RSM); alcune schede non ne indicano nessuna:

| Layer | Nome servizio | Licenza in scheda |
|---|---|---|
| ZTL centro diurna (ZTL C bus turistici) | `confini_ZTL_centro_diurna` | CC-BY-4.0 |
| ZTL centro diurna - settori | `settori_ZTL_centro` | CC-BY-4.0 |
| varchi ZTL centro diurna | `varchi_ZTL_centro_diurna` | CC-BY-4.0 |
| ZTL Centro notturna | `ZTL_Centro_notturna` | CC-BY-4.0 |
| ZTL Tridente (settore A1) | `ZTL_Tridente` | nessuna |
| ZTL Trastevere diurna e notturna | `ZTL_Trastevere` | CC-BY-4.0 |
| ZTL San Lorenzo notturna | `San_Lorenzo` | CC-BY-4.0 |
| ZTL Testaccio notturna | `Testaccio` | nessuna |
| ZTL Fascia Verde | `ZTL_Fascia_Verde` | CC-BY-4.0 |
| (altri: ZTL Bus turistici, ZTL AF1 VAM, Merci) | `ZTL_Bus_turistici`, `ZTL1_AF1_VAM`, `Merci` | nessuna / CC-BY-SA-4.0 / nessuna |

`Tools/fetch_geo.py` ora scarica anche questi layer in GeoJSON (`data/raw/geo/roma-rsm-<servizio>-<layer>.geojson`) al prossimo giro del workflow «Geometrie città». Una volta scaricati, si convertono in `data/raw/roma/perimetri.geojson` (proprietà `gatelr_id`) e `varchi.geojson` (`gatelr_id`, `id`, `nome`). Lo script li preferisce a OSM e toglie la nota sul perimetro. Poi va aggiornato `license` (attribuzione «Roma Servizi per la Mobilità»).

Tentativi precedenti, dalla rete di lavoro (24/10/2026): hub ArcGIS, CKAN di Roma Capitale e CKAN nazionale non danno niente o sono bloccati; Overpass/OSM non era raggiungibile. Le mappe incorporate nella pagina ZTL sono app ArcGIS (appid in `iframes-ztl-in-centro.txt`).

## 5. Altro da sapere prima di pubblicare

- `authority` è «Roma Servizi per la Mobilità» (nome proprio, non serve tradurlo).
- Test `testZoneAtAddress` (Swift) e `addressLookup` (Kotlin): il punto 41,9028, 12,4964 (piazza della Repubblica) resta fuori da tutte le zone anche con i perimetri OSM. Commento aggiornato, e aggiunto il controllo che il Pantheon sia in `roma-centro`.
- `manifest.json` aggiornato con `Tools/build_manifest.py` il 24/10/2026: Roma è nell'app.
