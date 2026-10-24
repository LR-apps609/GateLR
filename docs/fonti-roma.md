# Roma: fonti dei dati (bozza)

Stato: **draft**. Fonti lette il **24/10/2026**. Nessuna verifica umana (`reviewedByHuman: false`).
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

**Non caricata.** Tutte le zone hanno `perimeter: []` e `gates: []` e la nota «Perimetro e varchi non ancora caricati». Nessuna coordinata è stata inventata o ricavata da immagini.

Tentativi del 24/10/2026, tutti senza risultato:
- Hub ArcGIS di RSM (`data-rsm.opendata.arcgis.com`), `rsm.maps.arcgis.com`, `www.arcgis.com`, `services.arcgis.com`: connessione rifiutata dal proxy (403). Le mappe incorporate nella pagina ZTL sono app ArcGIS con appid `72c114415d1f49128e62930e2be55b63`, `0cbf623c1ed247fcaf7ffa2b818b0747`, `1394918957014555b48c6a721d590c7c`, `ef29aaa027d5432cae2388e5b863ae36`, `a23d86e53291453fb5e45ad4681e1304` (salvate in `iframes-ztl-in-centro.txt`): da lì si risale ai layer FeatureServer.
- CKAN di Roma Capitale (`dati.comune.roma.it`, 365 dataset): nessun dataset per «ztl», «varchi», «zona traffico limitato», «perimetro», «confini».
- CKAN nazionale (`www.dati.gov.it`): nessun dataset ZTL di Roma (solo altri Comuni).
- `https://www.comune.roma.it/TERRITORIO/nic-gwt/` (citato da RSM): ora rimanda alla home del Comune.
- Overpass/OSM (`overpass-api.de` e mirror): connessione chiusa o rifiutata a ogni tentativo (oltre 25 tentativi in circa 20 minuti).

**Da fare:** scaricare da un'altra rete i layer «confini» e «varchi» ZTL dall'hub RSM (licenza CC BY 3.0 IT, da ricontrollare sulla scheda di ogni layer; attribuzione «Roma Servizi per la Mobilità»), semplificarli e salvarli come `data/raw/roma/perimetri.geojson` (un poligono per zona, proprietà `gatelr_id` = id della zona) e `data/raw/roma/varchi.geojson` (punti con `gatelr_id`, `id`, `nome`). Rilanciando `Tools/build_roma.py` i dati vengono usati e la nota sul perimetro sparisce. Poi aggiornare il campo `license` di `roma.json`. In alternativa, OSM con gli ID degli oggetti e attribuzione ODbL, segnando la provenienza come «non ufficiale».

## 5. Altro da sapere prima di pubblicare

- `authority` è «Roma Servizi per la Mobilità» (nome proprio, non serve tradurlo).
- Il test `testZoneAtAddress` contiene `XCTAssertTrue(zones(41.9028, 12.4964).isEmpty) // Roma: non ancora nell'app`: oggi passa (perimetri vuoti), ma con i perimetri va ricontrollato.
- `manifest.json` non è stato aggiornato: va rilanciato `Tools/build_manifest.py` quando Roma entra nell'app.
