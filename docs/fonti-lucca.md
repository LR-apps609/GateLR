# Lucca: fonti della scheda ZTL

Scheda generata da `Tools/build_lucca.py` → **`Resources/Cities/lucca.json`** (stato `draft`, `reviewedByHuman: false`, come le altre città: dati presi dalle fonti ufficiali, non ancora rivisti da una persona). È nel `manifest.json` e sul sito.
Fonti lette il **24–25/10/2026** e salvate in `data/raw/lucca/`. Lo script si ferma se una delle frasi usate non c'è più, parola per parola, nei file salvati.

## Le zone

Il Disciplinare dei permessi di **febbraio 2026** (versione consolidata, allegato 1 alla delibera GC 340/2025, § 1.4) divide l'area dentro le Mura in tre zone:

| Zona dell'app | Regola (citazione) | Orari |
|---|---|---|
| `lucca-a` **Settore A · ZTL zona pedonale** | «ZTL tipo “A” l'accesso e la sosta sono sempre vietati fatti salvi i veicoli autorizzati muniti di permesso.» | sempre (0–24, tutti i giorni, festivi compresi) |
| `lucca-b` **Settore B · ZTL centro storico** | «ZTL tipo “B” […] l'accesso è consentito ai veicoli muniti di permesso e la sosta è consentita negli stalli gialli» | sempre: la regola non ha fasce orarie; i permessi dei residenti valgono «Dalle ore 0.00 alle ore 24.00» |
| `lucca-b-est` **Settore B · quadrilatero Villa Bottini (varchi sospesi)** | come la B | sempre (per prudenza: vedi sotto) |
| ZTL C (non è una zona dell'app) | solo limiti di massa 3,5 t, ingombro 6,50 × 2,20 m e 30 km/h; sosta blu a pagamento | nessun controllo degli accessi |

Tutte e tre: `kind: restricted`, finestra 0–24 tutti i giorni, `freeOnHolidays: false` (dal 2026 «le prescrizioni d'uso previste per la domenica si estendono automaticamente ai giorni festivi»: nessuna sospensione nei festivi), `exemptFuels: []`, `hotelCanRegister: true`, nessun `ticket`, nessun varco con coordinate.

## Fatti → fonte ufficiale

| Fatto | Fonte | File |
|---|---|---|
| Zone A, B, C e loro regole; Figura 1 = mappa «aggiornato al 25.11.2025»; restrizioni 10.30–14 e 18–21 in via Fillungo, via Roma, piazza San Michele (lato est), piazza Anfiteatro, piazza San Frediano ecc. anche per chi ha il permesso; «L'accesso e l'uscita in/dalla ZTL è presidiato da telecamere» | Disciplinare febbraio 2026, §§ 1.1, 1.4, pp. 4–10: https://www.comune.lucca.it/app/uploads/2026/03/disciplinare_2026_.pdf | `disciplinare-2026.pdf/.txt` |
| Mura: «disciplinate dalle norme stabilite per la ZTL A» e dal Regolamento d'uso delle Mura | Disciplinare 2026, § 7 | idem |
| Hotel (Z4): strutture «localizzate nella ZTL B e nella ZTL A»; targa, arrivo, partenza e camera nel portale «entro 3 giorni (72 ore)» dal passaggio; percorso più breve per tutto il soggiorno, sosta massima 30 minuti con disco orario, poi fuori da A e B o in aree private; niente stalli gialli; **gratuito** | Disciplinare 2026, Z4, pp. 109–111 | idem |
| Nessun permesso per i turisti: giornalieri solo per categorie (B1, B2, C…, Z12 a 15 €/giorno) | Disciplinare 2026, cap. 4 e tabella tariffe | idem |
| Modifiche 2026 (72 ore, festivi come la domenica…), nuova perimetrazione: da A a B l'area tra via del Crocifisso e via San Paolino, il quadrilatero via del Molinetto–via della Dogana, via San Girolamo (corso Garibaldi–via Carrara); da C a B il quadrilatero via Elisa/via del Fosso/via del Giardino Botanico/via San Micheletto e via Carrara (via San Girolamo–Porta San Pietro); la planimetria allegata «rappresenta la configurazione delle perimetrazioni delle ZTL A, ZTL B e ZTL C» | Delibera GC 340 del 12/12/2025: https://www.comune.lucca.it/app/uploads/2026/01/dlg_00340_12-12-2025.pdf | `dlg-340-2025.pdf/.txt/.html` |
| Mappa ufficiale in vigore «ZTL e parcheggi nel Centro Storico aggiornato al 25.11.2025 (prossima attuazione)» | https://www.comune.lucca.it/app/uploads/2026/03/ZTL-aggiornamento-dicembre-2025.pdf (pagina https://www.comune.lucca.it/documento_pubblico/planimetria-del-centro-storico-con-varchi-telematici-ztl-e-area-pedonale/) | `mappa-ztl-dicembre-2025.pdf`, `planimetria-varchi.html` |
| Varchi attivi dal 19/01/2026 (OUT piazza della Caserma, corso Garibaldi/Molinetto, via San Leonardo, via Gallitassi, via San Micheletto, Porta San Pietro, via della Dogana; IN via del Crocefisso, via Elisa; IN/OUT via del Molinetto, via del Fosso); parcheggi blu sempre raggiungibili; «restano temporaneamente sospesi i varchi del quadrilatero Quarquonia–Bacchettoni–via Elisa–Santa Chiara» per la sospensione della ZTL dovuta alla deviazione su via Santa Chiara (cantiere di Villa Bottini) | https://www.comune.lucca.it/notizia/ztl-da-oggi-19-gennaio-sono-attivi-i-nuovi-varchi-elettronici/ | `notizia-varchi-attivi.html` |
| 14 nuovi varchi, 6 riconfigurati IN/OUT dal 08/12/2025 (via del Gonfalone, via della Cavallerizza, Porta San Donato, via Vittorio Emanuele II, via dei Tabacchi, corso Garibaldi/via del Peso) | notizia del 08/01/2026; presentazione «Nuova perimetrazione ZTL» (2025): https://www.comune.lucca.it/app/uploads/2025/03/presentazione-nuova-ZTL.pdf | `notizia-controlli.html`, `presentazione-nuova-ZTL.pdf/.txt` |
| Lucca Comics & Games, 28/10–1/11/2026: dentro le Mura vietato 8–19 ai veicoli senza permesso; Porta Santa Maria e Porta Sant'Anna h24, Porta San Pietro 7–20.30; Z4 solo prima delle 10 e dopo le 19; ZTL A vietata a tutti 9–19 | Ordinanza n. 2393 del 21/10/2026: https://www.comune.lucca.it/app/uploads/2026/10/ord_02393_21-10-2026-Accessi-ZTL.pdf | `ord-2393-2026-accessi-ztl.pdf/.txt` |
| Ufficio permessi: Lucca Plus S.r.l. | Disciplinare 2026, cap. 3; https://www.comune.lucca.it/servizio/permessi-in-deroga-allaccesso/ | `servizio-permessi-deroga.html` |

Il Disciplinare 2024 (`Disciplinare2024.pdf/.txt`) resta salvato per confronto: il testo 2026 ha tolto la regola «uscire dalla ZTL B ed A entro 10 minuti» e porta le 120 ore degli hotel a 72.

## Fatti solo da fonti non ufficiali (nei `pending`)

- **Cantiere di Villa Bottini ancora in corso a ottobre 2026** (quindi varchi del quadrilatero est probabilmente ancora spenti): confermato solo da La Nazione («Villa Bottini, buone notizie. Riapre (parte) dei giardini», https://www.lanazione.it/lucca/cronaca/villa-bottini-buone-notizie-riapre-e0d5a5ba, ottobre 2026 secondo la ricerca web: giardino sud su via Elisa quasi pronto, muro nord su via Santa Chiara in corso, obiettivo fine lavori giugno 2027; il sito non è raggiungibile da qui, data non verificata) e da LuccaInDiretta (16/04/2026: sospensione della ZTL e varchi di via Elisa e corso Garibaldi spenti negli orari scolastici prorogati al 9 giugno 2026; 20/07/2026: Confartigianato chiede a che punto sono i lavori di via Santa Chiara). Nessun atto del Comune dopo gennaio 2026 trovato sull'argomento. I siti di LuccaInDiretta e La Voce di Lucca non sono raggiungibili da qui: gli articoli non sono salvati.
- «Telecamere a vigilare 24 ore su 24» (Il Tirreno, 2026) e «ZTL attiva tutti i giorni 24 ore su 24» (guide turistiche): coerenti con la regola, non usati come fonte.

## Geometria: dalla mappa ufficiale, in automatico

`Tools/lucca_mappa.py` (numpy, Pillow, pdftoppm) legge `mappa-ztl-dicembre-2025.pdf` e scrive `data/raw/lucca/ztl-mappa-ufficiale.geojson`. Niente è disegnato a mano:

1. il PDF (AutoCAD, senza coordinate) è reso a 150 dpi; ogni pixel vota per la sua classe di colore in una finestra di ~5 m: **verde = ZTL A**, **giallo = ZTL B**, **bianco = ZTL C / fuori ZTL** (legenda della mappa). Tratteggi degli edifici, scritte e simboli (cerchi dei varchi, frecce, stalli) non votano e prendono la classe vicina; le piccole sacche bianche chiuse (interno dei cerchi dei varchi) sono riempite, le strade bianche della ZTL C (via Santa Chiara, via della Quarquonia, via dei Bacchettoni, via Elisa verso Porta Elisa…) restano libere;
2. **aggancio alle coordinate**: trasformazione affine che sovrappone il contorno esterno delle Mura disegnato sulla mappa (bastioni compresi) al contorno esterno delle Mura in OpenStreetMap (relazione 19549900, `data/raw/geo/lucca-ztl.json`, © OpenStreetMap contributors, ODbL). Sovrapposizione **IoU 0,980** (scarto medio di pochi metri). Controllo visivo: i confini A/B tracciati in OSM nel 2024 dove non sono cambiati (piazza del Carmine, via della Fratta…) cadono sulle linee della mappa;
3. **Mura tolte dalla ZTL A** (0,21 km²): sulla mappa sono verdi (§ 7: valgono le norme della ZTL A), ma con le Mura dentro la zona chi passa da Porta Elisa, Porta San Pietro, Porta San Donato… per andare nella ZTL C risulterebbe «dentro la ZTL A». È Mura il verde a meno di ~38 m dal bordo esterno, o a meno di ~65 m se la striscia verde è più stretta di ~65 m; restano il centro pedonale e i pezzi di A che non toccano le Mura (piazza San Francesco);
4. poligoni semplificati a 2 m; in `build_lucca.py` ogni zona diventa **un solo anello** (contorni e buchi uniti da tagli di larghezza zero, `join_rings()`), che il ray casting pari/dispari dell'app tratta come poligoni con i buchi.

Risultato: ZTL A 0,374 km² (318 punti), ZTL B 0,494 km² (534 punti, 7 parti), quadrilatero est 0,062 km² (61 punti). Il quadrilatero Quarquonia–Bacchettoni–via Elisa–Santa Chiara è un'isola di B separata dalle strade bianche, quindi è la zona `lucca-b-est`.

Controlli nello script: piazza dell'Anfiteatro (43,8457, 10,5065), piazza Napoleone (43,8410, 10,5020: **verde, ZTL A** sulla mappa ufficiale) e piazza San Michele nella ZTL A; stazione (43,8375, 10,5062), Porta Elisa e piazzale Verdi (ZTL C) fuori da tutte le zone; il quadrilatero est solo in `lucca-b-est`; nessuna sovrapposizione tra zone (griglia 121 × 121, tolleranza 3 m sui bordi); tutto dentro le Mura; aree nei limiti attesi. Le aree passate da C a B (via Elisa/via del Fosso/via del Giardino Botanico/via San Micheletto, via Carrara verso Porta San Pietro) e da A a B (via del Crocifisso–via San Paolino, via del Molinetto–via della Dogana) sono gialle sulla mappa del 25/11/2025 e quindi nella ZTL B.

Se `ztl-mappa-ufficiale.geojson` manca, lo script usa i perimetri OSM del 2024 e la scheda torna bozza in `data/drafts/lucca.json`.

Per rifare: `python3 Tools/lucca_mappa.py` (solo se cambia la mappa), poi `python3 Tools/build_lucca.py`, `python3 Tools/build_manifest.py`, `python3 Tools/build_site.py`.

## Da verificare

- **Quadrilatero est (Villa Bottini)**: sulla mappa è ZTL B, ma la ZTL lì era sospesa a gennaio 2026 e i varchi spenti fino alla fine dei lavori; GateLR lo tratta come B (vietato) per prudenza. Quando il Comune annuncia l'attivazione dei varchi, togliere le note `P_EAST*` (o unire la zona alla B).
- **Varchi**: nomi ufficiali noti, coordinate no. In fondo a `Tools/fetch_geo.py` c'è il blocco «Lucca» che scarica strade con nome e porte (`data/raw/geo/lucca-streets.json`): **va fatto girare il workflow delle geometrie**; poi i varchi si possono mettere dove la strada ufficiale incrocia il bordo della zona.
- **Lucca Comics & Games 2026** (28/10–1/11): è solo una nota; dopo il 1° novembre 2026 togliere `P_COMICS`.
- Mappa e perimetri sono precisi a pochi metri, non sono un file di coordinate del Comune: se il Comune pubblica dati aperti della ZTL, usarli.
- www.metrolucca.it / www.luccaplus.it (gestore permessi e portale hotel) non raggiungibili da qui (403); pagine dei servizi «permesso temporaneo/permanente» su comune.lucca.it in 403.
- Patrono (San Paolino, 12 luglio): non serve, la ZTL vale anche nei festivi.

## Moto e scooter (1.17.1)
`exemptVehicleTypes: ["motorcycle"]` su `lucca-b` e `lucca-b-est`: *"Ciclomotori e motocicli. L'accesso, il transito dei ciclomotori e dei motocicli è consentito nella ZTL B seguendo i normali sensi di marcia"* (disciplinare febbraio 2026). ZTL A no: *"Il transito nella ZTL A è consentito ai mezzi di proprietà dei residenti all'interno di tale zona"* → per le moto «Non entrare».
