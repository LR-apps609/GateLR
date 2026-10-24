# Siena: fonti della scheda ZTL

Scheda generata da `Tools/build_siena.py` → `Resources/Cities/siena.json` (stato **draft**, `reviewedByHuman: false`, non inserita in `manifest.json`).
Fonti lette il **24/10/2026** e salvate in `data/raw/siena/`. Lo script controlla che ogni frase usata sia presente nei file salvati.

## Novità rispetto a `citta-successive.md`

Il disciplinare citato prima (GC n. 327 del 02/09/2025) è stato **sostituito** dalla **Deliberazione GC n. 177 del 19/05/2026** (PDF del 20/05/2026). Cambiano soprattutto le regole per gli hotel: ora sono **2 accessi al giorno da 45 minuti**, e non più un solo accesso da 2 ore. Orari della ZTL, Zona A e Zona Y storica, elettrici e permessi temporanei restano invariati.

## Fatti → fonte

| Fatto | Fonte (letta il 24/10/2026) | File |
|---|---|---|
| ZTL "ha validità tutti i giorni nell'orario 0/24 e l'ingresso, la circolazione e la sosta sono vietati ai veicoli non autorizzati" | Disciplinare GC 177/2026, p. 2: https://www.comune.siena.it/sites/default/files/2026-05/disciplinare__allegato%20A_1_d.pdf (pagina: https://www.comune.siena.it/documento-pubblico/disciplinare-il-rilascio-dei-permessi-di-accesso-e-circolazione-zona-traffico) | `disciplinare_GC_177_2026.pdf/.txt`, `documento-disciplinare.html` |
| Zona Y storica 6.00/10.00; Zona A 6.00/10.00 e 15.30/17.00 (anche per chi ha il permesso) | Disciplinare GC 177/2026, p. 12; elenco vie nella pagina Persone fisiche | idem |
| Perimetro = mappa allegata alla delibera GC n. 102 del 25/03/2025; 6 settori | Disciplinare, p. 2 | idem |
| Elettrici: "non sono autorizzati ad accedere alla Ztl per effettuare la sola ricarica" → nessuna esenzione | Disciplinare, p. 4 | idem |
| Permessi temporanei solo per motivi precisi (oggetti pesanti, ultrasettantenni, minori di 6 anni, persone temporaneamente inabili, animali dal veterinario); 30 min gratis (max 4 al mese), 1 h 5 €, 1 giorno 10 €, 2 o 3 giorni 20 €; +30 € per la Zona Y storica | https://www.comune.siena.it/servizi/accesso-ztl-persone-fisiche (aggiornata il 09/10/2026); Allegato B GC 327/2025: https://www.comune.siena.it/sites/default/files/2025-09/Tabella%20Tariffe_%20GC_327_2025.pdf | `accesso-ztl-persone-fisiche.html`, `tariffe_GC_327_2025.pdf/.txt` |
| Hotel con sede in ZTL: targa registrata "per massimo 2 volte al giorno", solo carico/scarico bagagli, sosta max 45 minuti, divieto di transito nella Zona Y storica (salvo hotel che sono dentro), servizio gratuito | https://www.comune.siena.it/servizi/accesso-ztl-strutture-ricettive (aggiornata il 20/05/2026); Disciplinare, pp. 8–9 | `accesso-ztl-strutture-ricettive.html` |
| Il permesso va esposto sul cruscotto al passaggio sotto il varco | Comunicato del 24/09/2025: https://www.comune.siena.it/novita/ztl-polizia-locale-al-lavoro-sui-varchi-di-accesso | `notizia-varchi.html` |
| Nomi dei 27 varchi (14 di ingresso, 13 di uscita) | "Mappa ZTL con Varchi" (giugno 2025): https://www.comune.siena.it/sites/default/files/2025-06/Mappa%20ZTL%20con%20Varchi.pdf | `mappa_ztl_varchi_2025-06.pdf` |

Varchi di ingresso secondo la tabella della mappa: 01 Mattioli (Tufi), 03 Fontanella, 04 Romana, 08 Ovile, 10 Matteotti, 12 San Domenico, 14 Fontebranda, 16 Bastianini, 17 Sperandie, 18 Mascagni, 21 Garibaldi, 24 Gazzani, 26 Fontegiusta, 28 Sasso S. Bernardino. Varchi di uscita: 02, 05, 07, 09, 11, 13, 15, 19, 20, 22, 23, 25, 27. Il n. 06 non compare. **Nel JSON non ci sono, perché non abbiamo le coordinate.**

Il centro della città (43.3184, 11.3316, cioè piazza del Campo) serve solo a inquadrare la mappa: non è un dato della ZTL.

## Geometria: provenienza e licenza

**Nessuna geometria nel JSON** (perimetro e varchi vuoti):
- Il Comune non pubblica dati aperti sulla ZTL: su dati.gov.it non c'è niente per Siena. Il Comune pubblica altri strati (es. "Aree di circolazione veicolare") su `siena.ldpgis.it`, ma il proxy blocca quel dominio, quindi non è stato possibile verificare se c'è un attributo ZTL.
- La mappa ufficiale è un PDF vettoriale A0 (scala 1:2000) **senza georeferenziazione** e senza testo estraibile. Ricavarne le coordinate vorrebbe dire ricalcarla a mano, e questo è escluso.
- Il proxy blocca OpenStreetMap/Overpass (overpass-api.de e i mirror, osm.org), che si poteva usare come fallback (ODbL).
- La licenza della mappa sul sito del Comune è indicata come "licenza aperta", senza dire quale.

Per aggiungere la geometria basta salvare `data/raw/siena/ztl_perimetro.geojson` (e `varchi.geojson` con `name`) e rilanciare lo script. Poi vanno aggiornati qui la provenienza e la licenza, e tolto il punto in sospeso sul perimetro.

## Da verificare

- **Perimetro e varchi** (vedi sopra). Senza perimetro l'app non può dire se un punto è nella ZTL.
- **Zona A / Zona Y storica**: non sono disegnate. Nella scheda compaiono solo nei punti in sospeso.
- **Scadenza hotel**: la pagina dice "entro 2 giorni lavorativi successivi al transito", il disciplinare 2026 "non oltre 2 giorni successivi". Chiedere a permessiztl@comune.siena.it (0577 292531).
- **Permessi temporanei per turisti stranieri**: il permesso da 1 a 3 giorni rimanda alle "motivazioni indicate nelle singole categorie". Non esiste un ticket turistico generico, e per questo la zona è `restricted` e senza `ticket`.
- **Tariffe**: la tabella è ancora l'Allegato B della GC 327/2025. Non è stata trovata una tabella nuova legata alla GC 177/2026, ma la pagina del 09/10/2026 riporta gli stessi prezzi.
- **CUDE** (disabili con contrassegno di altri comuni): registrazione online gratuita della targa, al più tardi 2 giorni dopo il transito (disciplinare, p. 8). Non è nel JSON.
- Nota: le pagine di comune.siena.it contengono link di spam ("SLOT GACOR…") iniettati nel footer. Non li abbiamo usati, ma vale la pena segnalarlo al Comune.
