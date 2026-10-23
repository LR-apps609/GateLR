# Firenze: lista di controllo prima di segnare la città «verificata»

Ogni punto ha il link da aprire, cosa cercare e dove si cambia il dato. Quando un punto è a posto, spunta la casella e annota la data.
Alla fine: in `Tools/build_firenze.py` metti `"reviewedByHuman": True`, togli i punti risolti da `pending`, aggiorna `CHECKED`, poi `status: "verified"`, e rilancia lo script.

Dati preparati il 23 ottobre 2026.

---

## 1. Orari della ZTL di giorno (settori A, B, O)

Nell'app oggi: **lunedì–venerdì 7:30–20:00, sabato 7:30–16:00, domenica libera.**

- [ ] **Fine alle 20 nei feriali e alle 16 il sabato**
  Apri: [Comune di Firenze, 30 settembre 2020](https://www.comune.firenze.it/novita/notizie/ztl-dal-1deg-ottobre-torna-lorario-pre-covid-tutte-le-porte-telematiche)
  Cerca: «apertura al transito alle 20 nei giorni feriali e dalle 16 il sabato». È del 2020: va confermato che valga ancora oggi.
- [ ] **Inizio alle 7:30**
  Apri: [Comune di Firenze, 15 giugno 2019](https://www.comune.firenze.it/istruzione/novita/area-stampa/comunicati-stampa/ztl-da-martedi-entra-vigore-la-revisione-della-disciplina-di)
  Cerca: «no stop dalle 7.30». L'inizio delle 7:30 qui è solo citato di passaggio.
- [ ] **Il disciplinare in vigore** (il documento che fa fede): Provvedimento Dirigenziale 2011/M/04192 e successive modifiche (fra cui 2015/M/02083 e 2019/M/04122, citati nei dati aperti dei perimetri).
  Dove: sito del Comune → Albo / Atti, oppure chiedere a SAS (055 4040202). Cerca la tabella degli orari per settore.
- [ ] **Domenica**: confermare che è libera tutto il giorno.

## 2. Festivi

Nell'app oggi: **non confermato** → nei festivi l'app risponde «Not sure».

- [ ] Trovare la regola ufficiale: la ZTL è spenta nei festivi infrasettimanali (es. 8 dicembre, 25 aprile)?
- [ ] Il **24 giugno** (San Giovanni, patrono di Firenze) conta come festivo per la ZTL?
- Dove: disciplinare (punto 1), oppure FAQ / numero verde SAS.
- Se è confermato «spenta nei festivi»: in `build_firenze.py` metti `"freeOnHolidays": True` e togli la riga sui festivi da `PENDING_COMMON`.

## 3. ZTL notturna estiva 2026

Nell'app oggi: **giovedì, venerdì e sabato dalle 23 alle 3 del giorno dopo, dal 2 aprile al 3 ottobre, settori A, B, O, F, G.**

- [ ] Apri: [Comune di Firenze, 31 marzo 2026](https://www.comune.firenze.it/novita/area-stampa/comunicati-stampa/ztl-estiva-dal-primo-giovedi-di-aprile-torna-lo-stop-serale-2)
  Cerca: «dalle 23 di giovedì, venerdì e sabato alle 3 del giorno successivo» e «fino al 3 ottobre». Questo testo l'ho letto direttamente: è il punto più solido.
- [ ] Per il **2027**: la data di inizio cambia (primo giovedì di aprile). Va aggiornata ogni anno; a marzo cercare il nuovo comunicato.

## 4. Perimetri dei settori

Nell'app oggi: perimetri dai dati aperti, semplificati (meno punti, precisione di circa 3 metri).

- [ ] Apri: [Dati aperti, ZTL diurna](https://opendata.comune.fi.it/page_dataset_show?id=9257a75e-3af3-4845-b37d-1540be29115a)
  Controlla: data dell'ultimo aggiornamento e licenza (CC-BY 4.0).
- [ ] Controllo a occhio nell'app (scheda Map): i settori A, B, O, F, G sono dove ti aspetti? Il settore A è dentro il B?
- [ ] I settori F e G vengono dal file della **ZTL notturna** (`datigis.comune.fi.it/json/ztl_notturna.json`), con atti del 2014: confermare che il perimetro sia ancora quello.

## 5. Varchi (porte telematiche)

Nell'app oggi: **15 varchi** (10 settore B, 4 settore O, 1 settore F). Tolte corsie bus, aree pedonali e telecamere non etichettate con un settore.

- [ ] Apri: [Dati aperti, porte telematiche](https://opendata.comune.fi.it/page_dataset_show?id=0fe68709-c864-4e21-b18e-07ee3e9328e2)
- [ ] Nel file ci sono **61 telecamere**; 42 non hanno «Settore» nel nome (es. Via della Scala n. 75, Piazza della Stazione, Viale dei Mille). Capire cosa sono: varchi ZTL senza etichetta, corsie riservate, o la nuova «Scudo Verde»?
- [ ] Il settore A e il G non hanno varchi propri nel file: confermare che si entri solo passando dai varchi di B (e di F per G).

## 6. Ospiti degli hotel

Nell'app oggi: «l'hotel può registrare la tua targa» per i settori A, B, O (non F, G).

- [ ] Trovare la procedura **attuale** per gli alberghi (portale SAS online? entro quanto tempo dopo il passaggio?).
  Esiste il [modulo SAS per inserire targhe a posteriori](https://www.serviziallastrada.it/Moduli_edit_ZTL/11_2019_modulo_inserimento_targhe_a_posteriori.pdf), ma è del 2019.
- [ ] Il sito di SAS è stato riorganizzato (le vecchie pagine ZTL danno «404»): trovare la pagina nuova.
- [ ] Se c'è un limite di tempo (es. entro 48 ore), aggiungerlo al messaggio per l'hotel.

## 7. Esenzioni

Nell'app oggi: **nessuna esenzione** per tipo di veicolo.

- [ ] Le auto elettriche possono entrare senza permesso? Servono registrazione o contrassegno?
- [ ] Permessi giornalieri a pagamento: esistono per i turisti? (Da mostrare come «Yes, with a day permit».)

## 8. Testi mostrati all'utente

- [ ] Leggi il riassunto «In short» di ogni settore e la frase del Comune con la traduzione: corretti e chiari?
- [ ] Il testo «Road signs on site always win over the app» è sotto ogni scheda.

---

**Siti utili**
- Comune di Firenze: https://www.comune.firenze.it
- Servizi alla Strada (SAS): https://www.serviziallastrada.it · numero 055 4040202
- Dati aperti: https://opendata.comune.fi.it
