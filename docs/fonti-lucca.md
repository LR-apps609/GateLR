# Lucca: fonti della scheda ZTL

Scheda generata da `Tools/build_lucca.py` → **`data/drafts/lucca.json`** (stato **draft**, `reviewedByHuman: false`). **Non è nell'app** (non è in `manifest.json`, niente pagine sul sito): resta una bozza per i due motivi spiegati sotto («Perché è una bozza»).
Fonti lette il **24/10/2026** e salvate in `data/raw/lucca/`. Lo script si ferma se una delle frasi usate non c'è più, parola per parola, nei file salvati.

## Le tre zone dentro le Mura

Il disciplinare (§ 1.4) divide l'area dentro le Mura in tre zone:

- **ZTL A** (sulla mappa ufficiale «ZTL A (Zona Pedonale)», comprese le Mura, § 4.48): «l'accesso e la sosta sono sempre vietati fatti salvi i veicoli autorizzati muniti di permesso». → zona `lucca-a`, **Settore A · ZTL zona pedonale**.
- **ZTL B**: «l'accesso è consentito ai veicoli muniti di permesso e la sosta è consentita negli stalli gialli». → zona `lucca-b`, **Settore B · ZTL centro storico**.
- **ZTL C**: valgono solo i limiti di massa (3,5 t), di ingombro (6,50 × 2,20 m) e di velocità (30 km/h); la sosta è a pagamento sugli stalli blu. Non c'è controllo degli accessi, quindi **non è una zona dell'app**: se fosse disegnata, la mappa la mostrerebbe in rosso. Compare solo nelle note «pending».

## Fatti → fonte

| Fatto | Fonte (letta il 24/10/2026) | File |
|---|---|---|
| ZTL A: accesso e sosta «sempre vietati» senza permesso; ZTL B: accesso solo con permesso; ZTL C: solo limiti di massa, ingombro e velocità | Disciplinare per il rilascio dei permessi (dicembre 2024), § 1.4, p. 9: https://www.comune.lucca.it/app/uploads/2025/02/Disciplinare2024.pdf | `Disciplinare2024.pdf/.txt` |
| «L'accesso e l'uscita in/dalla ZTL è presidiato da telecamere»; si deve uscire da B e A «entro 10 minuti dalla scadenza del periodo consentito» | Disciplinare, p. 10 | idem |
| ZTL A: in via Fillungo, via Roma, via Beccheria, via San Paolino, via Santa Croce (tratto), via Cenami, via Buia, via Santa Lucia, piazza San Michele (lato est), piazza Anfiteatro, piazza San Frediano, ulteriori restrizioni 10.30–14.00 e 18.00–21.00 (anche per i clienti degli hotel, p. 104) | Disciplinare, p. 10 e p. 104 | idem |
| Mura urbane: valgono le norme della ZTL A | Disciplinare, § 4.48, p. 125 | idem |
| Hotel (permesso Z4): strutture ricettive (hotel, B&B, extralberghiere con SCIA) «localizzate nella ZTL B e nella ZTL A»; la struttura inserisce sul portale targa, arrivo e partenza; accesso «seguendo il percorso più breve, per tutta la durata del soggiorno», sosta massima 30 minuti con disco orario, poi fuori da A e B o in aree private della struttura; niente stalli gialli; **gratuito** | Disciplinare, Z4, pp. 103–104; tabella tariffe p. 128 | idem |
| Scadenza per l'hotel: «entro 5 giorni (120 ore)» nel testo 2024; dal 01/01/2026 «entro 3 gg o 72 ore»; nel portale va indicata anche la camera | Disciplinare p. 103; delibera GC n. 340 del 12/12/2025: https://www.comune.lucca.it/app/uploads/2026/01/dlg_00340_12-12-2025.pdf | `dlg-340-2025.pdf/.txt`, `dlg-340-2025.html` |
| Festivi: dal 2026 «le prescrizioni d'uso previste per la domenica si estendono automaticamente ai giorni festivi» (nessuna sospensione della ZTL nei festivi) → `freeOnHolidays: false` | Delibera GC 340/2025 | idem |
| Permessi giornalieri solo per categorie precise (artigiani B1, imprese di pulizia B2, merci C1–C6, persone con disabilità temporanea Z12 a 15 € al giorno, ecc.); nessuna categoria per i turisti | Disciplinare, cap. 4 e tabella tariffe pp. 126–129 | idem |
| Auto elettriche: hanno tariffe ridotte dei permessi, ma nessun accesso libero (il solo C1e, merci, ha una fascia in più) → `exemptFuels: []` | Disciplinare, tabelle tariffe; comunicato del 13/01/2025: https://www.comune.lucca.it/notizia/entrano-in-vigore-le-modifiche-al-piano-della-mobilita-nel-centro-storico/ | `notizia-modifiche-piano.html` |
| Nuovi varchi attivi dal 19/01/2026: OUT piazza della Caserma, corso Garibaldi 2 (Molinetto), via San Leonardo, via Gallitassi, via San Micheletto, Porta San Pietro, via della Dogana; IN via del Crocefisso, via Elisa; IN/OUT via del Molinetto, via del Fosso. «Continuano come sempre ad essere raggiungibili tutti i parcheggi a stalli blu del centro storico» (piazza Santa Maria, corso Garibaldi, Cittadella, caserma Mazzini, piazza San Ponziano, piazzale Verdi, via del Pallone, piazza della Caserma, via Elisa, via beato Luca Passi). Sospesi temporaneamente i varchi del quadrilatero Quarquonia–Bacchettoni–via Elisa–Santa Chiara (cantiere di Villa Bottini) | https://www.comune.lucca.it/notizia/ztl-da-oggi-19-gennaio-sono-attivi-i-nuovi-varchi-elettronici/ (pubblicata il 03/03/2026) | `notizia-varchi-attivi.html` |
| Varchi riconfigurati (IN/OUT dal 08/12/2025): via del Gonfalone, via della Cavallerizza, Porta San Donato, via Vittorio Emanuele (piazza della Magione), via dei Tabacchi, corso Garibaldi (via del Peso); 14 nuovi varchi in tutto | https://www.comune.lucca.it/notizia/ztl-controlli-piu-stringenti-con-nuove-telecamere-e-varchi-in-uscita/ (08/01/2026); progetto: https://www.comune.lucca.it/notizia/mobilita-ztl-presentati-in-assemblea-pubblica-i-14-nuovi-varchi-di-uscita-dal-centro-storico/ | `notizia-controlli.html`, `notizia-14-varchi-uscita.html`, `notizia-nuovi-varchi.html` |
| Nuovo perimetro: da ZTL A a ZTL B l'area tra via del Crocifisso e via San Paolino, il quadrilatero via del Molinetto–via della Dogana e via San Girolamo (corso Garibaldi–via Carrara); da ZTL C a ZTL B il quadrilatero via Elisa/via del Fosso/via del Giardino Botanico/via San Micheletto e via Carrara (via San Girolamo–Porta San Pietro) | Delibera GC 340/2025; mappa «ZTL e parcheggi nel Centro Storico aggiornato al 25.11.2025 (prossima attuazione)»: https://www.comune.lucca.it/app/uploads/2026/03/ZTL-aggiornamento-dicembre-2025.pdf, dalla pagina https://www.comune.lucca.it/documento_pubblico/planimetria-del-centro-storico-con-varchi-telematici-ztl-e-area-pedonale/ | `mappa-ztl-dicembre-2025.pdf`, `planimetria-varchi.html` |
| Ufficio permessi: Lucca Plus S.r.l. (prima Metro S.r.l.) | Disciplinare cap. 3; pagina «Permessi in deroga all'accesso»: https://www.comune.lucca.it/servizio/permessi-in-deroga-allaccesso/ | `servizio-permessi-deroga.html` |

`notizia-elettrici.html` (2023) parla solo di sosta gratuita delle elettriche sulle strisce blu fino al 31/12/2023: non riguarda l'accesso alla ZTL e non è usata.

## Come sono state modellate le regole

- Due zone, `kind: "restricted"`, finestra unica **0–24 tutti i giorni**, `freeOnHolidays: false`, `exemptFuels: []`, `hotelCanRegister: true` (Z4 vale per strutture in A e in B), nessun `ticket`.
- La ZTL A ha la citazione «sempre vietati». Per la ZTL B il disciplinare non dà una fascia oraria: l'accesso è legato al permesso e i permessi dei residenti hanno «Fascia oraria accesso/uscita dalle ore 0.00 alle ore 24.00». GateLR la considera sempre attiva, **per prudenza**, con una nota «da confermare» (`B_HOURS_OFFICIAL = False`).
- Le restrizioni 10.30–14 e 18–21 di alcune vie della ZTL A riguardano chi ha già un permesso: sono solo una nota.
- Il centro della città (`center`) è il centro del riquadro della ZTL A, calcolato dallo script: serve solo a inquadrare la mappa. Sul sito (`web/template.html`) il punto di partenza è piazza dell'Anfiteatro (43,8457, 10,5065).

## Geometria: provenienza e licenza

**Da OpenStreetMap, non ufficiale** (© OpenStreetMap contributors, ODbL 1.0; scritto nel campo `license`, con un link alla relazione in ogni zona).

- Dati: `data/raw/geo/lucca-ztl.json` (Overpass `out geom`). Relazioni `boundary=limited_traffic_zone` «ZTL A» [19549900](https://www.openstreetmap.org/relation/19549900), «ZTL B» [19549370](https://www.openstreetmap.org/relation/19549370), «ZTL C» [19549417](https://www.openstreetmap.org/relation/19549417), con `source:url` = il Disciplinare 2024 e la nota «tracciata secondo la revisione del Disciplinare ZTL del 16/04/2024».
- **ZTL A**: in OSM il contorno esterno (1,30 km²) segue le Mura; un anello `inner` (0,72 km²) esclude B, C e le aree fuori ZTL (per esempio verso Porta Sant'Anna). L'app usa un solo anello per zona, quindi lo script unisce il buco al contorno con un taglio di larghezza zero tra i due punti più vicini (`keyhole()`). Il ray casting dell'app lo tratta come un poligono con il buco. Area risultante 0,58 km², 301 punti (semplificazione Douglas-Peucker a 5 m).
- **ZTL B**: contorno esterno della relazione, 0,44 km², 149 punti.
- **Varchi**: nessuno. Il Comune pubblica solo i nomi, e la mappa PDF non ha coordinate. In `lucca-gates.json` ci sono solo due autovelox (`highway=speed_camera`, 50 km/h), che non sono varchi ZTL.
- Controlli nello script: piazza dell'Anfiteatro (43,8457, 10,5065) è nella ZTL A e non nella B; la stazione (43,8375, 10,5062) è fuori da tutte e due; i punti della ZTL C non finiscono nella ZTL A; i perimetri stanno dentro l'inviluppo delle Mura (`lucca-walls.json`, relazione 9385404).
- Se arriva un perimetro ufficiale, si salva `data/raw/lucca/ztl_perimetri.geojson` (un Polygon per zona, proprietà `gatelr_id` = `lucca-a` / `lucca-b`): lo script usa quello al posto di OSM.

Perché non c'è una fonte ufficiale: la mappa «ZTL aggiornamento dicembre 2025» è un PDF AutoCAD (A2) **senza georeferenziazione**, che si potrebbe solo ricalcare a mano, e questo è escluso. Non abbiamo trovato dati aperti del Comune.

## Perché è una bozza

1. **Perimetro superato.** I perimetri OSM seguono il disciplinare 2024. Con la delibera GC 340/2025 e i nuovi varchi (attivi dal 19/01/2026) alcune aree sono passate dalla ZTL C e dalla ZTL A alla ZTL B (vedi tabella). Il passaggio C → B conta: nel quadrilatero via Elisa/via del Fosso/via del Giardino Botanico/via San Micheletto e in via Carrara verso Porta San Pietro la mappa OSM direbbe «fuori dalla ZTL» dove ora serve il permesso. Confrontando la mappa ufficiale con OSM, la fascia est che OSM segna come C è in gran parte gialla (B). In più, nel quadrilatero Quarquonia–Bacchettoni–via Elisa–Santa Chiara la ZTL era sospesa a gennaio 2026, e non sappiamo se lo è ancora. (`PERIMETER_CURRENT = False`)
2. **Orari della ZTL B** non scritti in modo esplicito (`B_HOURS_OFFICIAL = False`).

Per pubblicarla servono: un perimetro aggiornato (OSM corretto sulla mappa del 25/11/2025, o dati del Comune) e una conferma degli orari della ZTL B. Poi si mettono a `True` le due costanti, si rilancia `build_lucca.py`, `build_manifest.py` e `build_site.py`.

## Da verificare

- **Disciplinare consolidato 2026** (Allegato 1 alla GC 340/2025): non è pubblicato tra i file della delibera. Le modifiche sono note solo dal riassunto della delibera (hotel 72 ore, festivi come domenica, ecc.).
- **Pagine dei servizi** «rilascio del permesso temporaneo / permanente» su comune.lucca.it: rispondono 403 dal proxy, e la loro versione via API WordPress è vuota.
- **www.metrolucca.it / www.luccaplus.it** (gestore dei permessi e del portale hotel): non raggiungibili (502/403).
- **Varchi**: nomi noti, coordinate no.
- **Patrono** (San Paolino, 12 luglio): non serve, perché la ZTL vale anche nei festivi.
