# Bologna e Milano: lista di controllo prima di segnarle «verificate»

Come per Firenze (`docs/verifica-firenze.md`): ogni punto ha il link, cosa cercare e dove si cambia il dato (`Tools/build_cities.py`, poi `python3 Tools/build_cities.py`). Dati preparati il 23 ottobre 2026.

---

## Bologna

Nell'app oggi: **ZTL tutti i giorni 7–20**, festivi compresi; **zona T chiusa 24 ore su 24**; **ticket giornaliero 6 €** (4 giorni 15 €); l'hotel comunica la targa.

- [ ] **Orari**: [scheda ZTL del Comune](https://www.comune.bologna.it/informazioni/zona-traffico-limitato-ztl). Cerca: «tutti i giorni, dalle 7 alle 20».
- [ ] **Festivi**: la pagina dice «tutti i giorni» ma non nomina i festivi. Chiedere conferma: numero verde 800 108 088 o [Sosty](https://solweb.sostyscarl.it/). Se i festivi fossero liberi: `"freeOnHolidays": True`.
- [ ] **Ticket**: [pagina del ticket](https://www.comune.bologna.it/servizi/mobilita-trasporti/ticket-accesso-ztl). Cerca: «Il ticket giornaliero costa 6 euro», «Devi attivare il titolo prima dell'accesso», limite di 3 al mese.
- [ ] **Hotel**: [clienti di alberghi](https://www.comune.bologna.it/servizi/mobilita-trasporti/accesso-sosta-ztl-clienti-alberghi-autorimesse-autofficine). Cerca: «puoi farlo direttamente al tuo arrivo presso la struttura». Da aggiungere nel messaggio: abbonamento hotel 9 € con sosta sulle strisce blu.
- [ ] **Perimetro**: i dati aperti sono del 2021 (`codice = 40`). Confrontarlo con la mappa attuale del Comune.
- [ ] **Zona T e cantieri**: dal 15/07/2024 l'ordinanza P.G.n. 466849/2024 (Garisenda, tram) cambia gli accessi a zona T. Controllare se è ancora in vigore.
- [ ] **Varchi**: 22 varchi «ZTL» presi; esclusi 33 corsie bus, 10 aree pedonali, 6 «ZTLS» (università), 2 «ZTL speciale». Valutare se mostrare anche questi come zone 24 ore su 24.
- [ ] **Elettrici**: contrassegno gratuito anche per i non residenti, da chiedere prima. Oggi l'app non lo considera: aggiungere «Electric» in `exemptFuels` solo con il contrassegno.

## Milano (Area C)

Nell'app oggi: **lun–ven 7:30–19:30, festivi esclusi**; **ticket 7,50 €** da attivare entro la mezzanotte del giorno dopo (22,50 € fino al 7° giorno, 4,50 € in autorimessa convenzionata); nessuna procedura hotel.

- [ ] **Orari**: [pagina Area C](https://www.comune.milano.it/argomenti/mobilita/area-c). Cerca: «dal lunedì al venerdì, dalle 7:30 alle 19:30 (festivi esclusi)».
- [ ] **Prezzi**: [PDF tariffe](https://www.comune.milano.it/documents/20118/35188/Area+C+nuove+tariffe+dal+2023+Area+C.pdf/5ee21a73-7301-60c7-d2fe-5e2f77e8a158?version=1.0&t=1746021538283&download=true) e [acquisto del ticket](https://www.comune.milano.it/servizi/mobilita/area-c-acquista-il-ticket).
- [ ] **7 dicembre** (Sant'Ambrogio): Area C è attiva? Oggi l'app lo tratta come giorno normale.
- [x] **Elettrici**: esenti dal ticket, senza alcun adempimento (riconosciuti dalle telecamere), senza scadenza. Fonte: [Determinazione Dirigenziale n. 1856 del 13/03/2026](https://www.comune.milano.it/documents/d/guest/determina-dirigenziale-n-1856-del-13-03-2026-pdf?download=true), Disciplinare Area C, cap. 6 «Esenzioni dal pagamento della somma di accesso» (rif. punto 3.1 dell'ordinanza n. 693/2019): «Sono esentati dal pagamento della somma di accesso e transito, senza alcun adempimento […]: veicoli elettrici; autoveicoli, classe M1, ibridi con contributo emissivo di CO2 ≤ 100 g/km». Letta il 26/10/2026 (è il disciplinare in vigore, sostituisce la DD 6517/2025). Nell'app: `"exemptFuels": ["electric"]`. Le pagine HTML di comune.milano.it e le FAQ di servizicrm.comune.milano.it non erano raggiungibili da qui; nessuna fonte trovata su una fine dell'esenzione (solo proposte di stampa, non approvate).
- [ ] **Ibride**: gratis solo le auto (M1) con CO2 ≤ 100 g/km (campo V.7 della carta di circolazione); le ibride con CO2 > 100 g/km pagano dal 1° ottobre 2022 (stessa DD, cap. 7). L'app non conosce la CO2: per prudenza le ibride hanno la risposta «ticket», con nota nella scheda. Si potrà aggiungere la CO2 al veicolo.
- [ ] **Perimetro**: dal dataset DS51 (2023). Confrontarlo con il [geoportale](https://geoportale.comune.milano.it/portal/apps/webappviewer/index.html?id=bab7a4fea79f4e8bb0ab01e203168995).
- [ ] **Varchi**: 42 varchi di Area C (aggiornati il 14/10/2026).
- [ ] **Area B**: non è in GateLR (dipende dalla classe Euro del veicolo). Decidere se aggiungerla.
- [ ] **Veicoli lunghi e merci**: divieti dalle 8 alle 10 per veicoli > 7,50 m (DD 1856/2026). Non riguarda le auto dei turisti, ma va scritto nella scheda.

## Aggiunte dopo la 1.0 (da verificare anche queste)

### Milano – divieti per classe Euro (auto per trasporto persone)
- [ ] Area B: benzina Euro 0–3 vietate (Euro 3 dal 1/10/2025), Euro 4 dal 1/10/2028; diesel Euro 0–5 vietate, Euro 6 A-B-C dal 1/10/2028, D-TEMP/D dal 1/10/2030 — [calendario Area B](https://www.comune.milano.it/argomenti/mobilita/area-b-calendario-dei-divieti)
- [ ] Area C: benzina Euro 0–3 vietate (Euro 3 dal 1/10/2024), Euro 4 dal 1/10/2027, Euro 5 dal 1/10/2030; diesel come sopra — [calendario Area C](https://www.comune.milano.it/argomenti/mobilita/area-c-calendario-dei-divieti)
- [ ] GPL e metano: GateLR li tratta come benzina della stessa classe (da confermare)
- [ ] Ibride: trattate come benzina (da confermare)
- [ ] Giornate libere in Area B: 5 all'anno senza registrazione dal 1/10/2026, dal secondo anno di divieto
- [ ] Area B: elettriche sempre ammesse

### Aree pedonali e corsie bus
- [ ] Bologna: 62 aree pedonali dai dati aperti (zona pedonale centro storico), 33 telecamere «corsie»
- [ ] Milano: 110 aree pedonali (tipo «AP» nei dati DS51)
- [ ] Firenze: telecamere di corsie bus e area pedonale prese dalle porte telematiche con «Corsia», «TPL», «Pedonale» nel nome
- [ ] Nelle aree pedonali GateLR risponde sempre «No»: controllare che nessuna area pedonale abbia orari in cui le auto entrano

### Ticket
- [ ] Bologna: ticket da attivare prima di entrare (Sosty)
- [ ] Milano Area C: entro la mezzanotte del giorno dopo; dopo, fino al 7° giorno, 22,50 €
