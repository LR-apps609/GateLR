# Arezzo: fonti della scheda ZTL

Scheda generata da `Tools/build_arezzo.py` → `Resources/Cities/arezzo.json` (stato **draft**, `reviewedByHuman: false`).
Perimetri ricavati da `Tools/arezzo_mappa.py` → `data/raw/arezzo/ztl-mappa-ufficiale.geojson`.
Fonti lette il **26/10/2026** e salvate in `data/raw/arezzo/` (le pagine HTML del Comune così come scaricate, i PDF come testo con `pdftotext -layout`, gli articoli di giornale come testo). Il builder controlla che ogni frase citata o riassunta ci sia davvero nei file salvati e si ferma se ne manca una.

Il sito del Comune (`www.comune.arezzo.it`), il portale `permessiztl.comune.arezzo.it` e l'API di OpenStreetMap non erano raggiungibili da qui (proxy 403): tutto è stato scaricato con il workflow «Scarica pagine» (rami `pagine-arezzo-1` … `pagine-arezzo-5`). Overpass rispondeva 406/502: i dati OSM vengono dall'API 0.6 `/map`.

## Zone

| Zona (id) | Chiusa a chi non ha il permesso | Note |
|---|---|---|
| Corso Italia · ZTL B e piazza Grande (`arezzo-ztl-b`) | tutti i giorni, festivi compresi, 8:00–24:00 | 8 varchi |
| Basso Corso Italia · ZTL B a sud di via Roma (`arezzo-ztl-b-sud`) | come sopra | 2 varchi (da via Spinello) |
| Centro · ZTL A Centro storico (`arezzo-ztl-a`) | lun–sab non festivi 8:30–12:00 e 17:00–20:00 | contiene la ZTL B (nell'app vale la zona più piccola); 11 varchi |
| Via Marconi · ZTL A (`arezzo-ztl-a-marconi`) | come sopra | pezzo staccato a ovest di piazza Guido Monaco (via Marconi, via Testa, via Eritrea, via Cenne della Chitarra) |

Nel JSON: ZTL A `windows` lun–sab (2–7) 510–720 e 1020–1200, `freeOnHolidays: true`; ZTL B tutti i giorni 480–1440, `freeOnHolidays: false`; `localHolidays: ["08-07"]` (San Donato, patrono); `hotelCanRegister: true`; `exemptFuels: []`; nessun `ticket`.
Aree pedonali (`pedestrian`, contorni OSM, allegato 3): piazza Grande, piazza del Duomo, piazza della Badia, piazza della Libertà, piazza San Domenico, piazza San Francesco, piazza San Jacopo, piazza Sant'Agostino, piazza della SS. Annunziata.

## Fatti → fonte (ufficiali, lette il 26/10/2026)

| Fatto | Fonte | File |
|---|---|---|
| ZTL A: «divieto di circolazione e sosta per i veicoli a motore (sprovvisti di regolare autorizzazione) dalle ore 8,30 alle ore 12,00 e dalle ore 17,00 alle ore 20,00 dei giorni feriali» (citazione della scheda ZTL A); esclusi moto e ciclomotori a due ruote e le auto solo elettriche iscritte nella lista bianca | Disciplinare ZTL (delibera GC 124 del 30/03/2023), testo rev. 1.4, art. 3: https://www.comune.arezzo.it/sites/default/files/2025-07/copia_per_revisione_2023_senza_eliminati_rev1.4_definitiva_con_assessore.pdf | `disciplinare-ztl-2023-rev1.4.txt` |
| ZTL B: divieto «tutti i giorni dalle ore 8,00 alle ore 24,00» (citazione della scheda ZTL B) | idem, art. 4 | idem |
| Zona pedonale: circolazione e sosta «permanentemente vietate» (art. 5); elenco delle vie: allegati 1 (ZTL A), 2 (ZTL B), 3 (pedonale), 4 (libera circolazione) | idem | idem |
| Il testo in vigore dal 3/4/2023 è pubblicato con la scritta «IN FASE DI AGGIORNAMENTO» | https://www.comune.arezzo.it/documento-pubblico/ztl-vigore-dal-3-aprile-2023 | `ztl-vigore-dal-3-aprile-2023.html` |
| Varchi: elenco di 25 varchi con via, incrocio e tipo (INGRESSO/USCITA, ZTL A/B) | Disciplinare, art. 9 | `disciplinare-ztl-2023-rev1.4.txt` |
| 24 varchi agli accessi e alle uscite (più 2 sulla corsia preferenziale di viale Piero della Francesca); sistema SART_SMART, pre-esercizio 16–31/12/2024, piena operatività dal 01/01/2025 | Polizia Locale, «Videocontrollo ZTL e corsie preferenziali»: https://www.comune.arezzo.it/documento-pubblico/videocontrollo-ztl-e-corsie-preferenziali | `videocontrollo-ztl.html` |
| Sostituite tutte le 27 telecamere; «Nessuna modifica alle regole di accesso», orari invariati (14/03/2025) | https://www.comune.arezzo.it/novita/varchi-ztl-e-b-lattivazione-delle-nuove-telecamere-lettore-ottico | `novita-nuove-telecamere-2025.html` |
| Auto elettriche: ZTL A transito sempre consentito, ZTL B 8–11, 13–16, 20–24; pass nel portale, 5 € per 3 anni, validato dalla Polizia Municipale | Disciplinare, art. 30 | idem |
| Accesso giornaliero: solo per «effettiva necessità» (soprattutto carico e scarico), dal portale; massimo 20 l'anno per veicolo; contributo 10 € (disciplinare) | Disciplinare, art. 32 | idem |
| Accesso giornaliero: 15 € al giorno (L, M1, N1), 18 € (N2), 10 € per auto elettrica; orari consentiti ZTL A 8:30–12:00, ZTL B 8:00–11:00 e 14:00–16:00; sosta massimo 20 minuti; per ospiti di strutture ricettive (alberghi, b&b), strutture sanitarie e operatori della Fiera Antiquaria l'inserimento online è fatto da operatori abilitati; info permessiztl@comune.arezzo.it | «Accesso temporaneo nella ZTL»: https://www.comune.arezzo.it/documento-pubblico/accesso-temporaneo-nella-ztl-zona-traffico-limitato | `accesso-temporaneo-ztl.html` |
| Alberghi: i clienti con prenotazione «sono autorizzati senza alcuna formalità a raggiungere l'albergo esclusivamente per effettuare le operazioni di carico e scarico dei bagagli»; «il cliente o l'albergatore» inseriscono la targa nel Portale ZTL → `hotelCanRegister: true`. Nessun termine indicato | Disciplinare, art. 38 | idem |
| Disabili: transito senza limiti di orario in ZTL A e B; con un contrassegno di un altro comune comunicazione preventiva (portale, mail, numero verde 800211155) o entro 48 ore | Disciplinare, art. 33; pagina «Accesso temporaneo» | idem |
| Accessi irregolari rilevati dalle telecamere e convalidati dalla Polizia Locale (via Sette Ponti 66); verbale al proprietario | https://www.comune.arezzo.it/accesso-irregolare-ztl-zona-traffico-limitato | `accesso-irregolare-ztl.html` |
| Copia del verbale con i fotogrammi ZTL: 7 € (solo fotogrammi 6 €). Importo della multa non indicato dal Comune | https://www.comune.arezzo.it/procedure-sanzionatorie | `procedure-sanzionatorie.html` |
| Estate 2026: dal 15/05 al 12/09 (esclusi 19–20/06 e 4–5/09, Giostra), venerdì e sabato 19:00–24:00, divieto di transito e sosta anche per gli autorizzati nelle strade evidenziate della ZTL A e B, via Roma, via Crispi (corso Italia–via Margaritone), via San Lorentino (via Garibaldi–via Leone Leoni), via Guido Monaco (varco–piazza San Francesco) | Ordinanza 245 del 06/03/2026 (delibera GC 101/2026): https://www.comune.arezzo.it/sites/default/files/2026-05/ord_pedonalizzazione%20centro%20storico_2026_245.odt.pdf ; notizia https://www.comune.arezzo.it/novita/pedonalizzazione-temporanea-di-alcune-strade-del-centro-storico-2 | `ordinanza-245-2026-pedonalizzazione-estiva.txt`, `novita-pedonalizzazione-estiva.html` |
| Fiera Antiquaria di settembre 2026 (5–6/9, al Prato e viale Buozzi): divieti di sosta e transito da venerdì 4/9 | Ordinanza 1026 del 27/08/2026 | `ordinanza-1026-2026-fiera-antiquaria.txt` |
| Giostra del Saracino 6/9/2026: divieti di sosta e transito in molte strade del centro, chiusura totale 10–12 e 14–17 attorno al corteo, «sospesa la disciplina di Z.T.L. di tipo “B”» 8–24 nelle strade indicate | Ordinanza 1047 del 01/09/2026; allestimento lizza: ordinanza 995/2026 | `ordinanza-1047-2026-giostra.txt`, `ordinanza-995-2026-lizza-giostra.txt` |
| Mappa ufficiale (planimetria aggiornata al 25/09/2025): ZTL A tratteggio giallo (8,30–12 e 17–20 dei giorni feriali), ZTL B rosso (8–24 tutti i giorni), aree pedonali azzurre (0–24), area pedonale a orario stabilito verde (11–01, via Seteria), varchi esistenti e nuovi | https://www.comune.arezzo.it/documento-pubblico/la-planimetria-ztl → https://www.comune.arezzo.it/sites/default/files/2025-09/planimetria%20ztl_aggiornata%20al%2025_09_2025_.pdf | `planimetria-ztl-2025-09-25.pdf`, `planimetria-ztl.html` |
| Storia dei varchi: delibera GC 134 del 04/04/2019 (nuovi varchi, pre-esercizio dal 9/4/2019) | https://www.comune.arezzo.it/documento-pubblico/i-varchi-elettronici-ztl | `varchi-elettronici-ztl.html`, `delibera-gc-134-2019.txt`, `delibera-sostituzione-varchi.txt` |
| Portale permessi (SPID/CIE): permanenti e temporanei | https://permessiztl.comune.arezzo.it/ | `portale-permessiztl.html` |
| Carnet di 12 permessi giornalieri (solo per titolari di permessi di categoria) | https://comune.arezzo.it/caricoscarico-carnet-permessi | `carnet-permessi.html` |
| Permesso residenti ZTL B (fasce 8–10, 13–15, 20–24) | https://www.comune.arezzo.it/node/21573 | `permesso-ztl-b-residenti.html` |
| Elenco degli argomenti ZTL del Comune | https://www.comune.arezzo.it/tutti-gli-argomenti/ztl | `argomento-ztl.html` |

## Geometrie

- Arezzo non pubblica dati aperti sulla ZTL e in OpenStreetMap non ci sono relazioni ZTL per Arezzo (controllato sui dati scaricati). Perimetri **dalla mappa ufficiale** con `Tools/arezzo_mappa.py`:
  1. il PDF è trasformato in immagine (150 dpi) e classificato per colore secondo la legenda (tratteggio giallo = ZTL A, rosso = ZTL B, azzurro/verde = pedonale); legenda ed elenchi dei varchi sono esclusi;
  2. aggancio: prima una similitudine dai centri di piazza Grande, piazza Sant'Agostino e piazza San Domenico (azzurro della mappa → area OSM), poi una trasformazione affine che porta le righe grigie delle strade disegnate sulla mappa sulle strade di OSM (distanza media 5,3 m troncata a 20 m, 50% delle righe entro 3 m, 1,28 m per pixel); i parametri sono scritti nel geojson;
  3. ogni parte separata diventa un poligono (contorno esterno, semplificato a 2 m). La ZTL A contiene la ZTL B; via Roma resta fuori e separa la ZTL B principale dalla parte a sud.
- Controllo incrociato con l'elenco ufficiale delle vie (allegati 1 e 2) sulle geometrie OSM delle strade: il 90% dei tratti delle vie della ZTL A e B cade nella ZTL A della mappa (entro 10 m), il 91% dei tratti della ZTL B nella ZTL B. Le strade di libera circolazione (via Roma, via Crispi, via Petrarca, via Leone Leoni, piazza del Popolo) e via Spinello sono tutte fuori (controllo nel builder).
- Dati OSM: `https://api.openstreetmap.org/api/0.6/map?bbox=11.868,43.456,11.894,43.473` (ramo `pagine-arezzo-4`, 26/10/2026), convertiti in formato «out geom» in `data/raw/geo/arezzo-streets.json` (strade, piazze, mura, stazione). © OpenStreetMap contributors, ODbL 1.0.
- Varchi: i 25 dell'art. 9, messi nel punto della via indicata più vicino all'incrocio indicato (funzione `nearest`); quelli nello stesso punto sono uniti (3–4 via Madonna del Prato, 9–10 viale Buozzi, 15–16 via Isidoro del Lungo, 17–25 via San Lorentino) → 21 varchi. Il 14 («via Guido Monaco altezza Poste Centrali») è messo all'incrocio con via Garibaldi, dove la mappa ufficiale lo disegna. Il 21 (via de' Montetini) è a circa 100 m dal bordo della ZTL B: la striscia rossa di via de' Montetini sulla mappa è troppo sottile per entrare nel contorno.
- Controlli nel builder: il punto 43,4637, 11,8826 (corso Italia sotto piazza Grande) è nella ZTL A; il centro di piazza Grande (OSM, 43,4647, 11,8842) è nella ZTL B; la stazione FS (nodo OSM 8033523306), il piazzale 43,4581, 11,8735 e piazza Guido Monaco sono fuori da ogni zona (stazione a 340 m dal bordo della ZTL A); aree: ZTL A 0,63 km², ZTL B 0,14 km².

## Fonti non ufficiali (solo controllo incrociato)

- ArezzoNotizie (2019, varchi in uscita; «comporto di 20 minuti» per chi entra poco prima delle 8:30; ZTL A «dalle 8,30 alle 12 e dalle 17 alle 20»): https://www.arezzonotizie.it/motori/news/ztl-chiusa-uscita-cosa-cambia-residenti.html e https://www.arezzonotizie.it/attualita/telecamere-ztl-chiusa-varchi-orari-accesso.html → `arezzonotizie-varchi-uscita.txt`. La tolleranza di 20 minuti è **confermata solo da ArezzoNotizie** (in `pending`).
- accessibilitacentristorici.it (orari ZTL A e B uguali al disciplinare; moto ammesse in ZTL A, non in ZTL B): https://www.accessibilitacentristorici.it/ztl/toscana/arezzo.html → `accessibilitacentristorici-arezzo.txt`.
- ASC Hotel (settembre 2026, stessi orari; Fiera Antiquaria la prima domenica del mese e il sabato precedente; parcheggi Pietri, Baldaccio, Mecenate): https://www.aschotel.com/blog/dove-parcheggiare-ad-arezzo/ → `aschotel-parcheggi.txt`.
- Arezzo24 (area pedonale estiva 2026): https://www.arezzo24.net/notizie/mobilita/estate-in-centro-ad-arezzo-torna-la-maxi-area-pedonale-del-weekend-cambia-anche-il-percorso-degli-autobus/ → `arezzo24-pedonale-estate-2026.txt`.
- Patrono San Donato, 7 agosto: La Nazione, https://www.lanazione.it/arezzo/cronaca/giovedi-6-agosto-i-festeggiamenti-in-onore-di-san-donato-con-lofferta-del-cero-e-i-fuochi-abf5cdrp (non salvato).

## In sospeso (anche nella scheda, `pending`)

- «Giorni feriali» letto come lunedì–sabato; da confermare che il sabato conti. Il 7 agosto (San Donato) contato come festivo: da confermare.
- Prezzo dell'accesso giornaliero: 15 € sulla pagina del Comune, 10 € nel disciplinare.
- Ospiti degli hotel: il disciplinare non indica entro quando va inserita la targa (prima o dopo l'ingresso).
- Il disciplinare è «in fase di aggiornamento»: possibili modifiche 2026–2027.
- Area pedonale estiva (ordinanza 245/2026) non disegnata: la planimetria allegata (`planimetria_ord_pedonalizzazione.pdf`) non è stata salvata; date 2027 non ancora pubblicate.
- Fiera Antiquaria e Giostra del Saracino: divieti in più, fissati ogni volta con un'ordinanza.
- Auto elettriche: entrano solo dopo l'iscrizione alla lista bianca, quindi `exemptFuels: []`.

## Da fare

- Chiedere all'Ufficio Mobilità / Polizia Locale (permessiztl@comune.arezzo.it, numero verde 800211155): sabato nella ZTL A, 7 agosto, prezzo dell'accesso giornaliero, termine per gli hotel, coordinate dei varchi.
- Quando esce il nuovo disciplinare, rifare la scheda.

## Moto e scooter (1.17.1)
`exemptVehicleTypes: ["motorcycle"]` su `arezzo-ztl-a` e `arezzo-ztl-a-marconi`: *"Sono esclusi dal divieto i ciclomotori a due ruote, motocicli a due ruote e i veicoli dotati di motorizzazione solamente elettrica…"* (disciplinare ZTL, scheda ZTL A, controllata da `Tools/build_arezzo.py`). ZTL B no: *"Nel divieto sono inclusi tutti i mezzi a motore"* (accessibilitacentristorici, uguale al disciplinare) → per le moto «Non entrare».
