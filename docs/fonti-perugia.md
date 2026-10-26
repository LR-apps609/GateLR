# Perugia: fonti della scheda ZTL

Scheda generata da `Tools/build_perugia.py` → `Resources/Cities/perugia.json` (stato **draft**, `reviewedByHuman: false`), nell'app tramite `manifest.json` dal 26/10/2026.
Fonti lette il **26/10/2026** e salvate in `data/raw/perugia/` (testo estratto, con URL e data in testa a ogni file). Lo script si ferma se una frase citata o riassunta non c'è più parola per parola nel testo salvato.

Da qui www.comune.perugia.it, perugiatoday.it, minimetrospa.it, sipaonline.it e tutti i server Overpass non erano raggiungibili (proxy): tutto è stato scaricato con il workflow «Scarica pagine» (rami `pagine-perugia-1` … `pagine-perugia-4`, 26/10/2026). Overpass ha risposto 406 o non ha risposto anche dal workflow; le strade OSM vengono dall'API di OpenStreetMap (`map.json`, 4 riquadri). Il sito di SIPA (parcheggi) non ha risposto nemmeno dal workflow.

## Zone nell'app (5 perimetri, tutte `restricted`, nessun ticket per turisti)

Tutti gli orari vengono dalla pagina ufficiale **«ZTL Zone a Traffico Limitato»** del Comune — https://www.comune.perugia.it/luogo/ztl-zone-a-traffico-limitato/ (ufficiale, «Pagina aggiornata il 09/11/2024», letta il 26/10/2026) → `comune-luogo-ztl-zone-a-traffico-limitato.txt`. In tutte le zone «I titolari di permesso possono accedere in qualsiasi orario».

| Zona (id) | Orario di divieto usato | Testo ufficiale | Varchi |
|---|---|---|---|
| Acropoli · Centro storico (`perugia-centro-storico`) | lun–ven 0–13; sab, dom e festivi 0–7 (`holidaysAsSunday`) | «Centro Storico accessi di via Fanti, via del Parione, Via Bonazzi, Via Baglioni, via della Sposa, via Battisti, via San Sebastiano, via Appia, via Solitaria, via Campo Battaglia Dal lunedì al venerdì – … accesso vietato dalle 00.00 alle 13.00 Sabato e festivi – … accesso vietato dalle 00.00 alle 7.00» | 10, uno per accesso ufficiale |
| Corso Garibaldi · Borgo Sant'Angelo (`perugia-corso-garibaldi`) | lun–sab 0–13; dom e festivi 0–7 | «Corso Garibaldi: Giorni Feriali – … accesso vietato dalle 00.00 alle 13.00 Giorni Festivi – … accesso vietato dalle 00.00 alle 7.00» | 1 |
| Via del Roscetto (`perugia-via-del-roscetto`) | tutti i giorni 20–16 del giorno dopo (aperta solo 16–20) | «tutti i giorni – accesso consentito dalle 16.00 alle 20.00 – accesso vietato dalle 20.00 alle 16.00 del giorno successivo» | 1 |
| Corso Bersaglieri (`perugia-corso-bersaglieri`) | lun–sab 14–21; dom e festivi 0–24 | «Giorni Feriali – accesso consentito dalle 21.00 alle 14.00 del giorno successivo – accesso vietato dalle 14.00 alle 21.00 Giorni Festivi – accesso vietato dalle 00.00 alle 24.00» | 1 |
| Via Bontempi (`perugia-via-bontempi`) | tutti i giorni 0–24 | «Via Bontempi e vie interne ad essa tutti i giorni divieto di transito e sosta dalle 00,00 alle 24,00» | 1 (via Bontempi / piazza Piccinino) |

Festivi: in nessuna zona la ZTL si spegne nei festivi (`freeOnHolidays: false`); per il centro storico la pagina mette insieme «Sabato e festivi», per le altre «Giorni Festivi», quindi i festivi seguono l'orario della domenica.

### Zone H24 non disegnate (solo nei `pending`)
Dalla stessa pagina ufficiale, sezione «AREE PEDONALI E e ZTL CHIUSE H24» (tutti i giorni 0–24): via dei Priori tra via della Stella e il civ. 82 (Piazzetta Santo Stefano, area pedonale con varco); viale Indipendenza tra via Masi e Corso Cavour e Corso Cavour tra viale Indipendenza e via XIV Settembre (ingresso da via Masi); la strada parallela a viale Sant'Antonio (da viale Sant'Antonio a piazza del Melo). Sono tratti delimitati da numeri civici o senza nome in OSM: non si possono ricavare senza disegnare a mano, quindi non sono sulla mappa. Via dei Priori e viale Indipendenza/Corso Cavour cadono dentro o accanto al centro storico: di pomeriggio GateLR direbbe «aperto» anche lì; è scritto nei `pending` della zona.
Deroghe e data (varchi elettronici al posto dei pilomat, pre-esercizio dall'11/03/2024, multe dall'11/04/2024, ordinanza S.O. Sicurezza n. 297 del 02/03/2024): solo dal comunicato del Comune ripreso dalla stampa — **confermato solo da** Umbria Journal (https://www.umbriajournal.com/inevidenza/nuova-mini-zona-ztl-nel-centro-storico-di-perugia-ora-telecamere-542117/, non ufficiale, letto il 26/10/2026, `nonufficiale-umbriajournal-mini-ztl-2024.txt`) e PerugiaToday (https://www.perugiatoday.it/attualita/ztl-centro-storico-varchi-orari.html, non ufficiale, `nonufficiale-perugiatoday-mini-ztl-varchi-orari.txt`). L'ordinanza 297/2024 non è stata trovata sul sito del Comune.

## Regole (chi entra, hotel, permessi)

| Fatto | Fonte | Tipo | Letta il |
|---|---|---|---|
| Regolamento permessi ZTL e settori esterni, DCC 82/2012, modificato con DCC 51/2013, 149/2021 e **133 del 20/07/2026** (firmato 22/07/2026) | https://www.comune.perugia.it/wp-content/uploads/2024/11/07.01-Regolamento-permessi-ZTL.pdf → `regolamento-permessi-ztl-dcc-133-2026.txt` | ufficiale | 26/10/2026 |
| Hotel (art. 25): i veicoli diretti agli alberghi nella ZTL transitano senza permesso; «Quotidianamente ogni albergo … deve trasmettere … l'elenco delle targhe dei propri clienti»; sosta solo per i bagagli, max 60 minuti (fino alle 10 se si arriva tra le 22 e le 3), con contrassegno dell'albergo e disco orario; esclusi i veicoli di residenti/sedi nel Comune di Perugia | idem | ufficiale | 26/10/2026 |
| Modulo 34 «Domanda permessi per alberghi» (contrassegni per i clienti, numero di camere) | https://www.comune.perugia.it/documento_pubblico/34-domanda-permessi-per-alberghi/ e PDF https://www.comune.perugia.it/wp-content/uploads/2024/09/PermessiZTL-34-Domanda_permessi_per_alberghi.pdf → `comune-documento-34-domanda-permessi-alberghi.txt`, `comune-modulo-34-alberghi.txt` | ufficiale | 26/10/2026 |
| Elettriche: permesso di transito e sosta 24/24 (art. 31), quindi **non** esenti in automatico (`exemptFuels: []`) | Regolamento | ufficiale | 26/10/2026 |
| Moto e ciclomotori: senza permesso solo su itinerari fissi verso i parcheggi moto (art. 30); altrimenti permesso | Regolamento | ufficiale | 26/10/2026 |
| Disabili: contrassegno anche di altri comuni o esteri; targa da comunicare prima o entro 72 ore (art. 19 c. 4, art. 32 c. 6; servizio online o permessiztl@comune.perugia.it) | Regolamento; https://www.comune.perugia.it/servizio/permessi-ztl-comunicazione-accesso-giornaliero-alla-ztl-del-titolare-di-contrassegno-disabili/ → `comune-servizio-ztl-accesso-giornaliero-disabili.txt` | ufficiale | 26/10/2026 |
| Taxi e NCC di altri comuni: transito e sosta, targa da comunicare all'ufficio (art. 21 c. 4) | Regolamento | ufficiale | 26/10/2026 |
| Sanatoria per urgenze: entro 72 ore (art. 32 c. 5) | Regolamento | ufficiale | 26/10/2026 |
| Permessi giornalieri/temporanei: max 15 giorni; solo per categorie previste (categorie dei permessi permanenti, contrassegno invalidi, taxi/NCC non di Perugia, autocarri ≤35 q di ditte, matrimoni in ufficio); online con SPID/CIE, pagamento online («Pagina aggiornata il 21/10/2026») | https://www.comune.perugia.it/pagine/ztl-zona-a-traffico-limitato → `comune-pagine-ztl-permesso-giornaliero-temporaneo.txt` | ufficiale | 26/10/2026 |
| Prezzi dei permessi giornalieri da 2 a 12 € secondo classe Euro e portata, **veicoli stranieri 10 €** (delibera GC 283 del 25/06/2025) | https://www.comune.perugia.it/wp-content/uploads/2025/10/DG-283-2025-PagamentoPermessi.pdf → `delibera-gc-283-2025-pagamento-permessi.txt` | ufficiale | 26/10/2026 |
| Permessi permanenti online dal novembre 2025 (residenti, artigiani, carico/scarico, elettriche, disabili, solo transito) | https://www.comune.perugia.it/servizio/ztl-permesso-permanente/, https://www.comune.perugia.it/novita/permessi-ztl-richiesta-e-gestione-online-estesa-ad-altre-5-tipologie-di-permessi/ | ufficiale | 26/10/2026 |
| Regolamento ZTL «in fase di revisione» (question time, Perugia Comunica) | https://perugiacomunica.comune.perugia.it/digitalizzazione-servizi-ztl-le-novita-emerse-durante-il-question-time | ufficiale (testata del Comune) | 26/10/2026 |
| Minimetrò: parcheggio gratuito a Pian di Massiano (circa 3.000 posti); feriali 7–21:05, festivi 9–20:45, sabati fino all'01:05 dal 6/6 al 26/12/2026 | https://www.minimetrospa.it/ → `minimetro-home.txt` | ufficiale (società del trasporto) | 26/10/2026 |
| Multa: 80 € dall'11/04/2024 per le mini ZTL | titolo di un articolo correlato su PerugiaToday | **non ufficiale**, non usata nella scheda | 26/10/2026 |
| Conferme incrociate degli orari (centro storico 0–13 / 0–7, Roscetto, Bersaglieri, Garibaldi) | SicurAUTO https://www.sicurauto.it/news/attualita-e-curiosita/ztl-perugia-orari-mappa-ed-esenzioni/ ; ztlitaly.com https://ztlitaly.com/ztl/perugia/ ; PerugiaToday guida https://www.perugiatoday.it/guida/viabilita/ztl-nuovi-orari-incentivi-elettrico.html | **non ufficiali**, solo per incrociare | 26/10/2026 |

Patrono: San Costanzo (29 gennaio). Né la pagina ZTL né il regolamento dicono se conti come «festivo» per la ZTL, e non è stato trovato un atto del Comune che ne faccia festa per gli uffici: **non** è in `localHolidays` (scritto nei `pending`).
Agosto / stagioni: nessuna regola stagionale trovata. Modifiche 2026–2027: regolamento appena modificato (DCC 133/2026) e «in fase di revisione» secondo l'assessore; nessun nuovo orario annunciato.

## Pending (mostrati nella scheda)
- Perimetro non ufficiale, ricavato dagli accessi (vedi sotto).
- Zone H24 non disegnate (via dei Priori, viale Indipendenza/Corso Cavour, parallela di viale Sant'Antonio).
- Piazza Italia è disegnata dentro, ma una guida meno recente (PerugiaToday, non ufficiale) dice «Accesso di via Masi libero h24 solo nel corridoio da via Masi a Piazza Italia».
- Corso Garibaldi e Corso Bersaglieri: «giorni feriali» interpretati come lunedì–sabato.
- Via Bontempi: deroghe e vie interne solo dal comunicato del 2024 (non ufficiale); disegnata solo via Bontempi.
- Hotel: la targa va trasmessa ogni giorno dall'albergo, modalità non descritta in pagine pubbliche (procedura con credenziali).
- Elettriche non esenti senza permesso; patrono non confermato come festivo.

## Geometria (provenienza)
Il Comune non pubblica dati aperti né una mappa con coordinate (dati.gov.it: nessun dataset «perugia ztl»), e OpenStreetMap non ha relazioni o varchi ZTL per Perugia (solo telecamere generiche senza nome). Non c'è un elenco ufficiale delle vie, ma c'è quello ufficiale degli **accessi**. Il perimetro è quindi ricavato, mai disegnato a mano:
1. strade OSM carrabili del centro (`data/raw/geo/perugia-centro-strade.json`, API OSM `map.json` del 26/10/2026, © OpenStreetMap contributors, ODbL 1.0), con i sensi unici;
2. le strade d'accesso ufficiali della zona sono chiuse a chi arriva da fuori; si parte da tutti i nodi lontani dal centro e si segue la rete;
3. le strade che non si raggiungono senza passare da un accesso, più le strade d'accesso e le vie pedonali collegate (Corso Vannucci, Piazza IV Novembre), formano la zona; `osm_geo.street_area` ne disegna l'area;
4. le zone di una sola strada (via del Roscetto, Corso Bersaglieri, via Bontempi) sono l'area della strada;
5. il varco è il primo nodo, nel senso di marcia, della strada d'accesso raggiungibile da fuori.
Il fatto che dieci accessi bastino a chiudere un'area unica attorno all'acropoli conferma l'elenco. Controlli nello script: Piazza IV Novembre/Fontana Maggiore, Corso Vannucci e San Francesco al Prato dentro il centro storico; Corso Garibaldi dentro la sua zona e fuori dall'acropoli; stazione di Fontivegge fuori da tutte; area del centro storico tra 0,25 e 0,8 km² (risulta 0,43 km²).
