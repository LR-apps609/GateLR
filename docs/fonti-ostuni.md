# Ostuni: fonti della scheda ZTL

Scheda generata da `Tools/build_ostuni.py` → `Resources/Cities/ostuni.json` (stato **draft**), pubblicata come città con **fonte non ufficiale** (approvato dal titolare): la zona ha `source.official = false` e `source.unofficialSource` = accessibilitacentristorici.it (app 1.16.2); `Tools/build_manifest.py` la mette in `unofficialCities`, che le app fino alla 1.16.1 non leggono.

## Zona
**Borgo antico · ZTL della Città Bianca**: «attiva tutti i giorni 24 ore su 24» con i varchi di via Cattedrale, via Francesco Cavallo e via Francesco Vitale aperti 7–10 e 14–17 → nella scheda ZTL attiva tutti i giorni 0–7, 10–14, 17–24 (festivi compresi). Il varco di via Montegrappa è aperto 8–13 e 16–19 (nel nome del varco, nel riassunto e nei pending). Elettriche sempre ammesse; hotel nella ZTL danno ai clienti un permesso per i bagagli; disabili in urgenza entro 120 ore.

## Fonti
| Fatto | URL | Tipo | Letto il |
|---|---|---|---|
| Orari e varchi (**citazione**), veicoli ammessi, soggetti autorizzati, carico/scarico 14–17, disabili (120 ore), alberghi, nessuna sanatoria | https://www.accessibilitacentristorici.it/ztl/puglia/ostuni.html (dalla mappa https://www.accessibilitacentristorici.it/ztl/Apulia/ostuni/mappa, che apre la versione inglese) → `data/raw/ostuni/accessibilitacentristorici-ostuni.txt`; «Data aggiornamento: 30/10/2018» | **non ufficiale** (sito privato di servizi per i permessi) | 27/10/2026 |
| Disciplinare ZTL 2018 (D.G.C. 64 del 28/03/2018): art. 5 quattro varchi e orari di apertura, perimetro «come da planimetria allegata»; art. 6 c. 5 elettriche sempre ammesse; art. 7 viale Oronzo Quaranta; art. 21 alberghi | https://www.accessibilitacentristorici.it/ufficiali/regolamenti/Ostuni_regolamento%20ztl%20con%20modifica%20di%20di%20marzo%202018.pdf → `disciplinare-ztl-2018.txt` | atto del Comune, ma **copia ospitata dal sito non ufficiale** (non trovata sul sito del Comune; planimetria non inclusa) | 27/10/2026 |
| Scheda «Richiedere permesso di accesso ad area ZTL» (permessi online con SPID; categorie, fra cui «Albergo e struttura ricettiva per CARICO E SCARICO MERCI»; nessun orario) | https://www.comune.ostuni.br.it/servizio/richiedere-permesso-di-accesso-ad-area-ztl/ → `comune-servizio-permesso-ztl.txt` | ufficiale (senza orari) | 27/10/2026 |

Ricerca sul sito del Comune (API WordPress `wp-json/wp/v2/search`, «ztl» e «traffico limitato»; argomento «ZTL»): solo la scheda del servizio e la notizia «ZTL serale a Villanova dal 4 luglio al 14 settembre» (frazione sul mare, non il centro storico; non modellata).

Incrocio OpenStreetMap: via Cattedrale `motor_vehicle=permit`, `motor_vehicle:conditional = yes @ 07:00-10:00, 14:00-17:00` (stessi orari); telecamera «Varco ztl - Via Cattedrale» (nodo 14092310617).

## Pending
- «confermato solo da accessibilitacentristorici.it» (pagina del 2018; disciplinare 2018 non trovato sul sito del Comune).
- Varco di via Montegrappa con orari diversi (8–13, 16–19).
- OSM segna anche piazza della Libertà, corso Mazzini e corso Vittorio Emanuele come riservati ai permessi fuori da lun–ven 7–10 e 14–17 e sabato 0–10, con due telecamere («Varco ztl - Via Roma» e «Varco ztl»): nessuna fonte lo conferma, non disegnati.

## Geometria
- OpenStreetMap (© OpenStreetMap contributors, ODbL 1.0), API principale con `Tools/fetch_osm_api.py`, 27/10/2026, bbox 40.725–40.735 N, 17.570–17.586 E, ridotto in `data/raw/geo/ostuni-ztl.json`. **La mappa del sito non ufficiale non è usata**; nessuna relazione ZTL in OSM.
- Area (`osm_geo.street_area`, celle 6 m, chiusura 45 m, buchi riempiti; 0,086 km²): il borgo antico racchiuso da viale Oronzo Quaranta (way 81082631, 260475467, 777774751) e via Montegrappa (469078013, 477749231, 477749232), chiuso a sud da via Francesco Tanzarella Vitale (77244730), il primo tratto di via Cattedrale (1098789290), via Anna Carmignano (316414278) e via Francesco Cavallo (471740016).
- Varchi: telecamera OSM di via Cattedrale; inizio di via Francesco Cavallo; estremo sud-ovest di via Montegrappa; punto di via Francesco Vitale più vicino al bordo (incrocio con viale O. Quaranta).
- Controlli: via Cattedrale alta, largo Arcidiacono Teodoro Trinchera, via Petrarolo, via Brancasi dentro; piazza della Libertà, corso Mazzini, via Roma, via Giosuè Pinto (est) fuori.

## Moto e scooter (1.17.1)
Nessuna esenzione: la fonte dice *vietato anche a moto e ciclomotori* (vedi sopra) → con «Moto / scooter» la risposta resta «Non entrare».
