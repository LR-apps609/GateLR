# Modena: fonti della scheda ZTL (bozza)

Scheda generata da `Tools/build_modena.py` → `data/drafts/modena.json` (**bozza, non nell'app**: manca il perimetro, gli orari non sono confermati dal testo ufficiale e nessuna citazione è verificata).

## Perché è una bozza
Il 26/10/2026 dal sandbox www.comune.modena.it, geonext.comune.modena.it, opendata.comune.modena.it, visitmodena.it, i server Overpass, api.openstreetmap.org e i portali regionali erano rifiutati dal proxy (403, host non consentito per la sessione); WebFetch non li risolveva. Il workflow «Scarica pagine» **non** è stato usato perché aggirerebbe il blocco di rete della sessione (vietato dall'incarico). Raggiungibili solo www.dati.gov.it (CKAN) e la ricerca web.

Ogni regola viene dai **riassunti della ricerca web** salvati in `data/raw/modena/websearch-*.txt` (non testo letterale). `quote` è `null`; lo script controlla che ogni fatto usato sia nei file salvati.

## Fatti usati

| Fatto | Pagina indicata dalla ricerca | Tipo | Letto il |
|---|---|---|---|
| Testo coordinato Ordinanza ZTL, prot. 85253 del 01/04/2020; DGC 115 del 10/03/2020 «ha eliminato la franchigia oraria»; fasce nella sezione «B6) Fasce orarie per la circolazione all'interno della ZTL» (non letta) | https://www.comune.modena.it/amministrazione/documenti-e-dati/atti-normativi/ordinanze/ordinanze-a-carattere-generale/testo-coordinato-ordinanza-ztl | ufficiale (via riassunto, incompleto) | 26/10/2026 |
| Via Emilia Centro e Corso Duomo con fasce proprie | idem | ufficiale (via riassunto) | 26/10/2026 |
| ZTL attiva tutti i giorni 24 ore su 24, nessuna franchigia; in alternativa «7:30–20:30» | sicurauto.it, modenamoments.it, locautorent.com, autovia.it | **non ufficiale, in contrasto** | 26/10/2026 |
| Telecamere attive 24 ore su 24 ai varchi | idem | non ufficiale | 26/10/2026 |
| Ospiti di strutture ricettive in ZTL: transito e sosta con contrassegno della struttura sul parabrezza; comunicazione alla Polizia municipale prima o entro 48 ore; le auto a noleggio non hanno permesso | https://www.visitmodena.it/en/plan-the-trip/lta-limited-traffic-area (sito turistico del Comune); autovia.it | ufficiale/turistico (via riassunto) | 26/10/2026 |
| Accessi 20–6: comunicazione prima o entro 48 ore (ordinanza) | testo coordinato | ufficiale (via riassunto) | 26/10/2026 |
| Elettriche: modulo per far riconoscere un'auto esclusivamente elettrica «senza limiti di orario», per residenti senza contrassegno (infoztl@modenaparcheggi.it) → `exemptFuels: []` | https://www.comune.modena.it/amministrazione/documenti-e-dati/modulistica/mobilita-e-trasporti/ztl-e-sosta-a-pagamento-1/veicoli-elettrici/comunicazione-targhe-veicoli-elettrici-per-residenti-a-modena-senza-contrassegno/ | ufficiale (via riassunto) | 26/10/2026 |
| Disabili di altro comune: modulo comunicazione targhe (ztlpermanente@comune.modena.it) | https://www.comune.modena.it/amministrazione/documenti-e-dati/modulistica/mobilita-e-trasporti/ztl-e-sosta-a-pagamento-1/invalidi-e-persone-con-disabilita/comunicazione-targhe-veicoli-al-servizio-di-persone-con-disabilita-di-altro-comune/ | ufficiale (via riassunto) | 26/10/2026 |
| Permessi temporanei solo online (SPID/CIE/CNS), 4 € (guida di circa 867 giorni fa); Polizia municipale 059 20314, ztltemporaneo@comune.modena.it | mo.cna.it, modenamoments.it, sito di un hotel | non ufficiale | 26/10/2026 |
| Multe art. 7 CdS 83–332 € | sicurauto.it | non ufficiale | 26/10/2026 |
| Nessuna novità 2026–2027 trovata | ricerca | — | 26/10/2026 |

Scelte: `kind: restricted`, 0–24 tutti i giorni (prudenziale), `freeOnHolidays: false`. Patrono San Geminiano (31 gennaio): non serve in `localHolidays` con la regola 0–24.

## Geometria
Perimetro **ufficiale** in open data: dataset «Zone a traffico limitato» (Comune di Modena, catalogo Regione Emilia-Romagna su dati.gov.it, modificato il 24/10/2026), WFS `Modena:Ztl_preview` su https://geonext.comune.modena.it/geoservernext//Modena/Ztl_preview/wfs. Non scaricabile da qui. Per pubblicare: salvarlo in WGS84 come `data/raw/modena/ztl_perimetro.geojson`, salvare il testo coordinato (sezione B6) in `data/raw/modena/`, aggiornare le finestre orarie, mettere una citazione verificata e rilanciare lo script.
