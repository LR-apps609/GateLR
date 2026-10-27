# Mantova: fonti della scheda ZTL (bozza)

Scheda generata da `Tools/build_mantova.py` → `data/drafts/mantova.json` (**bozza**, non nell'app né nel sito). Ricerca del **27/10/2026**; testi salvati in `data/raw/mantova/`.

## Perché resta bozza
- **Nessun testo ufficiale delle regole raggiungibile.** Sul sito del Comune (https://www.comune.mantova.it/it/topics/ztl, letto il 27/10/2026) l'argomento «ZTL» elenca solo il servizio dei permessi (rimanda allo sportello www.sut.comune.mantova.it), quello per i pass disabili di altre città e il PUMS/PUT: nessuna pagina con orari, vie o perimetro.
- Host bloccati dal proxy (403, non aggirati): www.sut.comune.mantova.it (sportello permessi), www.aster.mn.it (Aster, società del Comune che gestisce i pass ZTL), pubblicazioni.comune.mantova.it (albo pretorio), nextcloud-municipium.maggiolicloud.it (allegati PUMS/PUT), comune.mantova.gov.it, www.accessibilitacentristorici.it; tyremap.com non raggiungibile (DNS). Il vecchio sito www.comune.mantova.gov.it risponde 502 (non raggiungibile). Il download con il workflow «Scarica pagine» e la copia d'archivio non sono stati consentiti in questa sessione.
- **Nessun perimetro affidabile.** Nessun dataset ZTL di Mantova su www.dati.lombardia.it né su dati.gov.it. In OpenStreetMap (API OSM, 27/10/2026, riquadro 45.150–45.166 N, 10.785–10.805 E) non c'è una relazione della ZTL; c'è una sola relazione `enforcement` «ZTL camera» (6422783, 45.15657 N 10.79120 E) e 99 strade con `motor_vehicle=permit`, che però non comprendono le vie principali del centro: l'area che ne risulta è spezzata in pezzi e non è usabile.

## Cosa dicono le fonti (tutte da confermare)
| Fatto | Fonte | Tipo |
|---|---|---|
| Pass disabili di altre città: prenotazione dell'accesso con modulo a infomulte@comune.mantova.it o al Comando (agg. 03/02/2026) | https://www.comune.mantova.it/it/services/prenotazione-accesso-zona-a-traffico-limitato-ztl-con-pass-disabile-altre-citta → `comune-servizio-pass-disabili-altre-citta.txt` | ufficiale |
| ZTL A e ZTL B; telecamere attive tutti i giorni 24 ore su 24; Corso della Libertà e via Trieste aperti a tutti 7–12 e 18–21; multa circa 83 € | accessibilitacentristorici.it, tyremap.com, milazzo.life (riassunti della ricerca web) → `websearch-27-ottobre-2026.txt` | non ufficiale |
| Pass «Operatore commerciale» per gli alberghi, 0–24 su tutte le ZTL | riassunto della pagina Aster (non letta direttamente) | ufficiale ma non verificato |
| Pass online per gli ospiti di hotel e B&B tramite Aster, strisce blu a tariffa agevolata | Gazzetta di Mantova (circa 2024) | non ufficiale |
| Voucher ZTL 2,60 € per 24 ore | siti di hotel | non ufficiale |
| Telecamere ai varchi con sanzioni automatiche dal 15/09/2025 (bus turistici) | ANAV, elenco ticket bus feb. 2025 | non ufficiale |
| ZTL attiva 7–19 | quotabus.com | non ufficiale, in contrasto con le altre |

## Per pubblicare
Salvare il disciplinare o l'ordinanza ZTL (o la pagina Aster) con gli orari di ZTL A e B e la procedura per gli ospiti degli hotel, e l'elenco ufficiale delle vie, da applicare alle strade OSM come in `Tools/build_como.py`.
