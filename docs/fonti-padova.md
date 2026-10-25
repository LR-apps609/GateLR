# Padova: fonti della scheda ZTL

Scheda generata da `Tools/build_padova.py` → `Resources/Cities/padova.json` (stato **draft**, `reviewedByHuman: false`).
Fonti lette il **25/10/2026** e salvate in `data/raw/padova/`. Lo script controlla che ogni frase citata o riassunta sia presente nei file salvati (si ferma se manca).

Il sito del Comune (`www.comune.padova.it`; `www.padovanet.it` ora rimanda lì) è un'app Angular che non ha il testo nell'HTML. Il testo delle pagine è stato letto dall'API JSON dello stesso sito (`https://www.comune.padova.it/api/informations/<id>?include=information_partials`, o `api/news/<id>`) e salvato così com'è (`*.json`). I PDF degli atti sono salvati come testo estratto (`*.txt`, con `pdftotext -layout`).

## Zone

| Zona (id) | Quando | Tipo |
|---|---|---|
| Zona A (`padova-a`) | feriali (lun–sab) 8:00–23:30; festivi 14:00–23:30 | restricted |
| Zona B (`padova-b`) | tutti i giorni 0–24 | restricted |
| Limitazioni antismog (`padova-antismog`) | 1/10–11/12/2026 e 7/1–30/4/2027, lun–ven 8:30–19:30, esclusi i festivi infrasettimanali (livello verde) | green, divieti per classe Euro |
| Domeniche ecologiche (`padova-domeniche-ecologiche`) | 8/11/2026, 6/12/2026, 24/1, 28/2, 14/3, 18/4/2027, 8:30–18:30 | restricted (solo elettriche) |

## Fatti → fonte (tutte ufficiali, lette il 25/10/2026)

| Fatto | Fonte | File |
|---|---|---|
| ZTL divisa in Zona A e Zona B (elenco vie nell'Allegato 1). "ZONA “A”: giorni feriali 8:00 – 23:30; festivi: 14:00 – 23:30" e "ZONA “B”: giorni feriali e festivi 00:00 – 24:00"; in vigore dal 29/05/2023 | Ordinanza n. 2023/62/0437 del 23/05/2023, punto 11: https://www.comune.padova.it/sites/default/files/attachment/ZTL.pdf | `ordinanza_2023-62-0437_ztl.txt` |
| Stessi orari nella pagina del Comune (aggiornata il 06/02/2026); 6 varchi di ingresso elencati: Largo Europa e via Busonera 0–24; via del Santo, ponte S. Gregorio Barbarigo, via Vescovado, riviera Mussato con l'orario della Zona A | https://www.comune.padova.it/zona-traffico-limitato-ztl-centro-storico | `ztl-centro-storico.json` |
| Entrano liberamente bici, ciclomotori, moto; le auto elettriche solo dopo aver registrato la targa (email a zonablu@comune.padova.it con modulo e carta di circolazione), anche entro 48 ore dopo il transito → nel JSON `exemptFuels: []` | Ordinanza 437/2023, punti 2–3; pagina Ztl | idem |
| Disabili (art. 188 CdS, anche contrassegni di altri comuni): targa da registrare, anche entro 48 ore dal transito, sul portale Istanze online | Ordinanza 437/2023, punto 3 h; pagina Ztl | idem |
| Varchi anche in uscita; ingresso e uscita nello stesso giorno = una sola multa | Ordinanza 437/2023, punto 21 | `ordinanza_2023-62-0437_ztl.txt` |
| Carico/scarico in Zona A e B: 5:00–11:00 e 15:00–17:00 | Ordinanza 437/2023, punto 11 | idem |
| Hotel (e garage pubblici, officine) con sede in ZTL: registrano targa e fascia oraria dei clienti "entro le 48 ore dal transito", sul portale, "per ogni giorno di transito"; gratis; senza la registrazione il transito è abusivo. Sosta solo operativa per carico/scarico (max 30 min) | Disciplinare (Allegato A DGC 239/2023), art. 12 e 22: https://www.comune.padova.it/sites/default/files/attachment/Allegato%20A%20Disciplinare%20.pdf ; pagina titoli temporanei: https://www.comune.padova.it/titolo-autorizzatorio-temporaneo-ztl-ex-contrassegno ; ordinanza 437/2023 punto 6 i | `disciplinare_GC_239_2023_allegato_A.txt`, `titolo-temporaneo-ztl.json` |
| Nessun ticket per turisti: il "pass temporaneo fino a due ore" (5 €) e i temporanei fino a 48 ore (15 € + bollo) valgono solo per motivi elencati (oggetti pesanti, persone con difficoltà a camminare, cerimonie, clienti di hotel/garage…); online solo con SPID o CIE → nel JSON nessun `ticket` | Pagina titoli temporanei; Allegato B DGC 239/2023: https://www.comune.padova.it/sites/default/files/attachment/Allegato%20B_3.pdf | `titolo-temporaneo-ztl.json`, `tariffe_GC_239_2023_allegato_B.txt` |
| Multa per transito abusivo: 80 € più spese di procedura e notifica | https://www.comune.padova.it/multe-e-ricorsi-transiti-abusivi-nella-ztl | `multe-ricorsi-ztl.json` |
| Aree pedonali dentro la ZTL: 0–24, tranne Contrada Antenore (9:30–24) e Piazze Centrali (lun–ven 21–1, sab 16–1, festivi 9–1); ospiti degli hotel solo con titolo temporaneo | Ordinanza n. 2023/62/0464 del 25/05/2023, punti 5 d8 e 7: https://www.comune.padova.it/sites/default/files/attachment/AreePedonali_0.pdf | `ordinanza_2023-62-0464_aree_pedonali.txt`, `elenco-aree-pedonali.json` |
| Antismog 2026/2027, livello verde: lun–ven esclusi i festivi infrasettimanali, 8:30–19:30, dal 01/10 all'11/12/2026 e dal 07/01 al 30/04/2027, in tutto il comune tranne zona industriale, autostrade, tangenziali e alcune vie elencate. Vietati: benzina Euro 0–1; diesel Euro 0–4; benzina/GPL, benzina/metano, metano, gasolio/GPL, gasolio/metano Euro 0–1; moto Euro 0. Esenti elettriche e ibride. Livelli arancio e rosso (tutti i giorni, festivi compresi): anche benzina/GPL/metano Euro 2 e diesel Euro 5 | Ordinanza del Sindaco n. 46 del 29/09/2026: https://www.comune.padova.it/sites/default/files/2026-09/ordinanza_2026_46_firm_dig.pdf ; pagina https://www.comune.padova.it/limitazioni-del-traffico-stagione-invernale-20262027 | `ordinanza_sindaco_2026_46_limitazioni_traffico.txt`, `limitazioni-2026-2027.json`, `volantino_limitazioni_2026-2027.txt` |
| Diesel Euro 5 al livello verde: rinviato al 1° ottobre 2027 (L.R. Veneto n. 22 del 15/09/2026) | Pagina limitazioni 2026/2027 | `limitazioni-2026-2027.json` |
| Multa antismog: 168 € (117,60 € entro 5 giorni) | idem | idem |
| Domeniche ecologiche 2026/2027: 04/10/2026, 08/11/2026, 06/12/2026, 24/01/2027, 28/02/2027, 14/03/2027, 18/04/2027, 8:30–18:30, "all'interno delle mura del '500" (perimetro: le vie esterne elencate, escluse dal divieto). Vietati tutti i veicoli a combustione e ibridi; esenti le auto solo elettriche; ospiti degli hotel dentro l'area solo per andata e ritorno nel giorno di arrivo e di partenza, con copia della prenotazione; residenti con autodichiarazione. Multa 87 € (60,90 € entro 5 giorni) | Ordinanza del Sindaco n. 47/2026: https://www.comune.padova.it/sites/default/files/2026-09/ordinanza_2026_47_firm_dig.pdf ; https://www.comune.padova.it/novita/notizie/domenica-ecologica-del-4-ottobre-2026 | `ordinanza_sindaco_2026_47_domeniche_ecologiche.txt`, `domenica-ecologica-2026-10-04.json` |
| Mappa ufficiale (Zona A, Zona B, aree pedonali, varchi E/U/R), 31/08/2023 | https://www.comune.padova.it/sites/default/files/attachment/2023-08-31_ZTL_PadovaNet_Volantino%20A3.pdf | `mappa_ztl_2023-08-31_volantino_A3.png` (immagine a 90 dpi) |
| Progetto (non ancora in vigore): via Dante tra le piazze e corso Milano pedonale a fasce orarie, con dissuasori a scomparsa; dettagli da definire | Comunicato del 04/05/2026: https://www.comune.padova.it/novita/comunicati/comunicato-stampa-dante-accolta-la-proposta-di-pedonalizzare-il-primo-tratto | `news-via-dante-2026.json` |
| Contrassegno residenti tipo 2: canone 2026 92,96 € (conferma che il sistema dei titoli del 2023 è ancora quello in uso) | https://www.comune.padova.it/novita/notizie/avviso-importante-indicazioni-il-rinnovo-del-contrassegno-ztl-residenti-0 | `news-rinnovo-residenti-2026.json` |

## Fonti non ufficiali (solo controllo incrociato)

Lette il 25/10/2026 tramite i riassunti della ricerca web (i siti non si aprono da questa rete, quindi non sono salvati): Fleet Magazine ("ZTL Padova: mappa, orari e permessi"), Sicurauto (2020), il blog di Locauto (ottobre 2026), revisioneauto.eu, Il Gazzettino (2023, telecamere in uscita dal 1° agosto 2023). Tutti danno gli stessi orari (Zona A feriali 8–23:30, festivi 14–23:30; Zona B 0–24) e i 7 varchi di ingresso (Largo Europa e via Busonera 0–24). Nessuno segnala modifiche nel 2024–2026. Nessuna regola della scheda si basa solo su fonti non ufficiali.

## Festivi e patrono

- Zona A: la regola dà un orario diverso nei festivi (14:00–23:30). Dalla 1.13.2 la scheda ha `holidaysAsSunday: true`: nei festivi infrasettimanali l'app usa gli orari della domenica.
- Zona B e domeniche ecologiche: `freeOnHolidays: false`.
- Antismog: "esclusi i giorni festivi infrasettimanali" → `freeOnHolidays: true`.
- Sant'Antonio (13 giugno), festa del patrono a Padova: **non** messo in `localHolidays`. La ZTL non esclude i festivi (cambia solo l'orario della Zona A), e il 13 giugno è fuori dal periodo antismog (ottobre–aprile).

## Zone non incluse

- **ZTL notturne** (via Anelli e vie vicine 22–7; Pescarotto e via Mortise 22–5; Arcella tra via J. d'Avanzo e via G. de' Menabuoi 22–4:30; multa 71 €): pagine del Comune dal 2006 al 2015 (`ztln-*.json`, `elenco-ztl-notturno.json`), senza varchi elettronici (controlli della polizia), in quartieri residenziali lontani dal centro. Non sappiamo se siano ancora tutte in vigore (il complesso di via Anelli è stato demolito) e non c'è un perimetro: restano fuori. Da chiedere alla Polizia Locale (049 8205101).
- **Aree pedonali**: sono tutte dentro la ZTL e chiuse anche a chi ha il permesso ZTL; non sono disegnate (non c'è un perimetro scaricabile).
- **Corsie riservate** con telecamere (via E. Filiberto, via Dante, corso Garibaldi, riviera Ponti Romani, Stazione nord-ovest e sud-est, Prato della Valle nord, via Beato Pellegrino, via Cavazzana, via Tommaseo, via Leopardi, riviera Businello; Cavazzana, Leopardi, Stazione nord-ovest e Tommaseo aperte 21:00–7:00): elencate nella pagina Ztl, ma senza coordinate ufficiali.

## Geometria: provenienza e licenza

Il Comune non pubblica dati aperti sulla ZTL (niente su dati.gov.it; `opendata.comune.padova.it` e i geoportali comunali e regionali non si raggiungono da questa rete). La mappa ufficiale è un PDF senza coordinate: serve solo per il confronto a vista. Niente è disegnato a mano.

- **Zona A** (57 punti, 0,84 km²): contorno esterno della relazione OSM [19152919](https://www.openstreetmap.org/relation/19152919) «ZTL Zona A e B» (`boundary=limited_traffic_zone`, `author=Comune di Padova - Settore Mobilità`), due way `outer` unite da `osm_geo.outer_ring`, semplificate a 4 m. Comprende anche la Zona B: l'app, dentro due zone, risponde per la più piccola (come Area C dentro Area B a Milano). File `data/raw/geo/padova-ztl.json` (GitHub Actions, Overpass, 25/10/2026).
- **Zona B** (292 punti, 0,27 km²): in OSM non c'è. È ricavata dall'**elenco ufficiale delle vie della Zona B** (Allegato 1 dell'ordinanza 437/2023): le strade OSM con quei nomi (per le vie "tratto compreso tra…" solo il pezzo tra i due incroci indicati), dentro il contorno della relazione 19152919, unite con `osm_geo.street_area` (griglia di 6 m, chiusura di 45 m). Le strade vengono dall'API OSM 0.6 (`/api/0.6/map`, riquadri del centro) scaricate il 25/10/2026 con `Tools/fetch_padova_streets.py` → `data/raw/padova/osm-strade-centro.json` (solo le way `highway` con nome). Controllo: tutte le vie B provate (Riviera Ruzante, via Rudena, via Santa Chiara, via Cappelli, riviera Tito Livio, via Stampa, via Fiume, piazza Capitaniato, via Locatelli) cadono dentro; le vie A provate (via del Vescovado, via Dottori, via Santa Rosa, via San Girolamo, via Rialto, via XX Settembre, via Galilei, via Accademia, via San Biagio, via Vandelli, via Prati, via degli Obizzi) restano fuori; un tratto di via dei Soncin (vicino alle piazze) cade dentro. Il tratto B di Largo Europa (dal civ. 12 a corso Garibaldi) è quasi tutto fuori.
- **Varchi**: i nodi `device` delle relazioni OSM `enforcement=access` «Accesso ZTL …» (data/raw/geo/padova-gates.json), con il nome ufficiale della pagina del Comune: Zona A Ponte S. Gregorio Barbarigo (897223392), via Vescovado (897222500), riviera Mussato (790501211), via del Santo (298468358); Zona B Largo Europa (897227594), via Busonera (897227588), riviera Businello, corsia riservata (897222391). Distanza dal bordo 1–42 m. I 13 varchi di uscita non sono in OSM.
- **Telecamere delle corsie riservate** (`cameras`, tipo bus): nodi `device` delle relazioni `enforcement=check` in via Dante (1451949434), via E. Filiberto (1452342450), riviera dei Ponti Romani (1452144210).
- **Domeniche ecologiche** (45 punti, 4,64 km²): dalle mura del Cinquecento in OSM (`data/raw/geo/padova-walls.json`, way `historic=citywalls` / `barrier=city_wall`). Le mura sono a pezzi, quindi `walls_ring()` prende, per ogni settore di 3° attorno al centro, il punto delle mura più lontano. Il confine ufficiale è l'anello di vie appena fuori dalle mura. Controllo: dentro Palazzo della Ragione, Basilica del Santo, Prato della Valle, Specola, Cappella degli Scrovegni; fuori la stazione FS e la Fiera.
- **Antismog** (128 punti, 92,2 km²): confine comunale ISTAT al 1/1/2026 da [openpolis/geojson-italy](https://github.com/openpolis/geojson-italy) (`limits_P_28_municipalities.geojson`, dati ISTAT, CC BY), salvato in `data/raw/padova/confine-comunale-padova.geojson`, semplificato a 20 m. Le vie escluse (tangenziali, autostrade, zona industriale…) non sono tolte.
- Licenza nel campo `license`: regole dal Comune; perimetri, varchi, telecamere e mura © OpenStreetMap contributors, ODbL 1.0 (approssimati, non ufficiali); confine comunale ISTAT via openpolis (CC BY).

Controlli di `build_padova.py` e a mano (25/10/2026): Palazzo della Ragione, piazza dei Signori e Caffè Pedrocchi in Zona B (e quindi anche in A); Duomo in Zona A e non in B; Basilica del Santo, Prato della Valle e stazione FS fuori dalla ZTL; la stazione è dentro solo la zona antismog.

Nota: `Tools/check_sources.py` confronta l'HTML delle pagine, ma per Padova l'HTML è lo stesso guscio Angular per tutte: per accorgersi dei cambiamenti bisogna rileggere l'API (`api/informations/…`).

## Da verificare

- Perimetri di Zona A e Zona B: da OpenStreetMap, da confrontare con la mappa ufficiale del 31/08/2023.
- Antismog: livelli arancio e rosso (decisi da ARPAV lunedì, mercoledì e venerdì) non sono nella scheda; vie escluse (tangenziali, zona industriale…) non sono tolte dal perimetro; la stagione 2027/2028 avrà date nuove (e forse il diesel Euro 5).
- Domeniche ecologiche: le date valgono solo per la stagione 2026/2027; il perimetro è approssimato.
- Hotel: la registrazione è "per ogni giorno di transito"; non è chiaro se vale anche per la Zona B e le aree pedonali delle Piazze (il disciplinare parla di ZTL o aree pedonali): chiedere a zonablu@comune.padova.it (049 2010066).
