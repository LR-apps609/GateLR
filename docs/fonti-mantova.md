# Mantova: fonti della scheda ZTL (bozza)

Scheda generata da `Tools/build_mantova.py` → `data/drafts/mantova.json` (**bozza**, non nell'app né nel sito). Ricerca del **27/10/2026**; testi salvati in `data/raw/mantova/`.

## Perché resta bozza
- **Nessun testo ufficiale con gli orari della ZTL per le auto, quindi nessuna citazione.** Sul sito del Comune (https://www.comune.mantova.it/it/topics/ztl, letto il 27/10/2026) l'argomento «ZTL» elenca solo il servizio dei permessi, quello per i pass disabili di altre città e il PUMS/PUT. Le pagine di **Aster** (ora lette su `aster.mn.it`, senza `www`) descrivono i pass e le sottozone ma non gli orari della ZTL A e B; l'unica fascia oraria ufficiale (7–19 tutti i giorni) è quella della ZTL per gli **autobus turistici**. Il regolamento ZTL (D.C.C. 62/2013) è citato da Aster ma non è stato trovato online.
- **Nessun perimetro affidabile.** Nessun dataset ZTL di Mantova su www.dati.lombardia.it né su dati.gov.it. In OpenStreetMap (API OSM, 27/10/2026, riquadro 45.150–45.166 N, 10.785–10.805 E) non c'è una relazione della ZTL; c'è una sola relazione `enforcement` «ZTL camera» (6422783) e 99 strade con `motor_vehicle=permit`, che però non comprendono le vie principali del centro. Gli elenchi di vie di Aster riguardano solo le sottozone A/RU e AV e i requisiti dei pass, non il confine di ZTL A e B.
- Host (27/10/2026, con nuovi tentativi e timeout lunghi): `aster.mn.it` e `sut.comune.mantova.it` raggiungibili (il secondo è solo lo sportello telematico, senza testi sulla ZTL); `www.aster.mn.it`, `www.sut.comune.mantova.it` e `nextcloud-municipium.maggiolicloud.it` **403** dal proxy (non aggirati); `pubblicazioni.comune.mantova.it` (albo pretorio) **connessione chiusa dal server** (reset) a ogni tentativo; `comune.mantova.gov.it` / `www.comune.mantova.gov.it` **502**; overpass-api.de reset. Il workflow «Scarica pagine» e archive.org non sono stati usati.

## Cosa dicono le fonti (tutte da confermare)
| Fatto | Fonte | Tipo |
|---|---|---|
| Pass disabili di altre città: prenotazione dell'accesso con modulo a infomulte@comune.mantova.it o al Comando (agg. 03/02/2026) | https://www.comune.mantova.it/it/services/prenotazione-accesso-zona-a-traffico-limitato-ztl-con-pass-disabile-altre-citta → `comune-servizio-pass-disabili-altre-citta.txt` | ufficiale |
| ZTL A e ZTL B; telecamere attive tutti i giorni 24 ore su 24; Corso della Libertà e via Trieste aperti a tutti 7–12 e 18–21; multa circa 83 € | accessibilitacentristorici.it, tyremap.com, milazzo.life (riassunti della ricerca web) → `websearch-27-ottobre-2026.txt` | non ufficiale |
| Zone ZTL A, A/RU (area pedonale via Roma, corso Umberto I, via Grazioli), AV (dissuasore di via Verdi; piazza Erbe, piazza Broletto…), B; «Zona Rossa» con 5 telecamere (via Accademia, Cavour, Trieste, corso della Libertà, …); pass e tariffe per residenti e domiciliati | https://aster.mn.it/cittadini/ztl → `aster-pass-ztl-persone-fisiche.txt` | ufficiale (Aster, società del Comune) |
| Varchi n. 9 via Trieste e n. 10 corso Libertà; pass operatori commerciali 6–21; regolamento DCC 62/2013 citato nella news «sanatoria 2026» | https://aster.mn.it/cittadini/ztl-aziende → `aster-pass-ztl-aziende.txt` | ufficiale |
| Permesso orario ZTL per turisti dall'«Area Pass» con PagoPA, consigliati almeno 5 giorni di anticipo (prezzo non indicato) | https://aster.mn.it/turisti/permesso-orario-ztl → `aster-permesso-orario-ztl-turisti.txt` | ufficiale |
| Auto/moto elettriche di altri comuni: pass di solo transito 100 € / 50 € | https://aster.mn.it/cittadini/pass-auto-elettriche → `aster-pass-auto-elettriche.txt` | ufficiale |
| ZTL per autobus turistici attiva tutti i giorni 7–19 (PASS BUS 24 ore) | https://aster.mn.it/turisti/bus-turistici → `aster-bus-turistici.txt` | ufficiale (solo bus) |
| Pass online per gli ospiti di hotel e B&B tramite Aster, strisce blu a tariffa agevolata | Gazzetta di Mantova (circa 2024) | non ufficiale |
| Voucher ZTL 2,60 € per 24 ore | siti di hotel | non ufficiale |
| Telecamere ai varchi con sanzioni automatiche dal 15/09/2025 (bus turistici) | ANAV, elenco ticket bus feb. 2025 | non ufficiale |
| ZTL attiva 7–19 | quotabus.com | non ufficiale: è la ZTL per i bus (vedi Aster) |

## Per pubblicare
Salvare il disciplinare o l'ordinanza ZTL (o la pagina Aster) con gli orari di ZTL A e B e la procedura per gli ospiti degli hotel, e l'elenco ufficiale delle vie, da applicare alle strade OSM come in `Tools/build_como.py`.
