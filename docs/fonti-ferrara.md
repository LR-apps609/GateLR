# Ferrara: fonti della scheda ZTL (bozza)

Scheda generata da `Tools/build_ferrara.py` → `data/drafts/ferrara.json` (**bozza, non nell'app**: manca il perimetro e nessuna citazione è verificata sul testo ufficiale).

## Perché è una bozza
Il 26/10/2026 dal sandbox tutti i siti utili rispondevano con rifiuto del proxy (403 al CONNECT, host non consentito per la sessione): www.comune.ferrara.it, www.comune.fe.it, sit.comune.fe.it, servizife.comune.ferrara.it, overpass-api.de, overpass.kumi.systems, overpass.private.coffee, api.openstreetmap.org, dati.emilia-romagna.it, geoportale regionale, web.archive.org. Anche WebFetch non risolveva questi host. Il workflow «Scarica pagine» **non** è stato usato: servirebbe ad aggirare il blocco della rete della sessione, e l'incarico vietava di aggirare i controlli di sicurezza. Raggiungibile solo www.dati.gov.it (catalogo CKAN) e la ricerca web.

Quindi ogni regola qui sotto viene dai **riassunti della ricerca web** (salvati in `data/raw/ferrara/websearch-*.txt`, non testo letterale), che indicano le pagine ufficiali da cui provengono. `quote` è `null`. Lo script controlla comunque che ogni fatto usato sia scritto nei file salvati.

## Fatti usati

| Fatto | Pagina indicata dalla ricerca | Tipo | Letto il |
|---|---|---|---|
| ZTL attiva tutti i giorni dell'anno 24 ore su 24 | https://www.accessibilitacentristorici.it/ztl/emilia-romagna/ferrara.html, https://tolltracker.eu/zones/italy/ferrara-ztl | **non ufficiale** (confermato solo da queste guide) | 26/10/2026 |
| Centro storico diviso in comparti A, B, C, D con varchi elettronici; lista bianca delle targhe; Ferrara Pass (contrassegno elettronico) | https://www.comune.ferrara.it/it/b/11833/permessi-ztl, regolamento https://www.comune.ferrara.it/static/d3/13/ea/d36133eac821d78bec5fd1f4d17c5aa3.pdf | ufficiale (via riassunto) | 26/10/2026 |
| Ospiti di alberghi/case vacanza in ZTL: accesso per carico/scarico bagagli o sosta nella struttura; targa alla reception al check-in; nessuna scadenza trovata | https://www.comune.ferrara.it/it/b/57142/casi-particolari | ufficiale (via riassunto) | 26/10/2026 |
| Permesso giornaliero 20 €, pacchetti da 5 o 10 accessi; online su INES Cloud (PERMESSI ZTL → PRENOTA/ACQUISTA) o allo sportello; prima di entrare; non online per ZTL Duomo e veicoli > 3,5 t | https://www.comune.ferrara.it/b/17343/permessi-ztl-giornalieri-e-abbonamenti | ufficiale (via riassunto, pagina di circa 2 anni fa) | 26/10/2026 |
| Centro Unico Permessi, via Marconi 41, lun–ven 7:30–12; tel. 0532 418890; musa@comune.fe.it | https://www.comune.ferrara.it/it/b/25854/centro-unico-permessi | ufficiale (via riassunto) | 26/10/2026 |
| Elettriche: «VEICOLI ELETTRICI ACCESSO GRATUITO IN TUTTE LE FASCE ORARIE» (presentazione 2021); h24 nel progetto regionale 2013 | https://www.cronacacomune.it/media/uploads/allegati/46/nuovo-ztl-_conf_stampa_16_04_2021.pdf | ufficiale ma datato → non esentate (`exemptFuels: []`) | 26/10/2026 |
| Nuovi varchi via Francesco del Cossa e Largo Castello (DD n. 2221 del 17 settembre), fine lavori entro 31/03/2027 | https://www.estense.com/2026/1208535/nuovi-varchi-ztl-in-via-del-cossa-e-largo-castello-intervento-da-95mila-euro/ | non ufficiale | 26/10/2026 |
| Varchi per nome (Porta Reno, via Garibaldi, via De' Romei, via Camaleonte, via della Paglia, via Armari, via Ercole De' Roberti, via Ghisiglieri, vicolo del Chiozzino, via Gusmaria, Corso Ercole I d'Este, piazza T. Tasso) | accessibilitacentristorici.it | non ufficiale, senza coordinate | 26/10/2026 |
| Multe: art. 7 Codice della Strada, 84–335 € (o 83–332 €) | sicurauto.it, autosupermarket.it | non ufficiale | 26/10/2026 |

Festivi: con orario 0–24 tutti i giorni `freeOnHolidays: false`; il patrono (San Giorgio, 23 aprile) non serve in `localHolidays`.

## Pending (anche nella scheda)
Orari solo da guide non ufficiali; comparti A–D e ZTL Duomo non disegnati; scadenza della registrazione hotel ignota; chi può comprare il giornaliero (turisti?) e prezzo attuale; elettriche; nuovi varchi 2027.

## Geometria
Esiste un perimetro **ufficiale** in open data: dataset «Zone a traffico limitato (ZTL esistente)» (Comune di Ferrara, catalogo Regione Emilia-Romagna su dati.gov.it, modificato il 24/10/2026), WFS `Ferrara:ZTL_esistente_preview` su https://sit.comune.fe.it/geoserverckan/Ferrara/ZTL_esistente_preview/wfs (anche shape-zip). Non scaricabile da qui. Per pubblicare: salvarlo in WGS84 come `data/raw/ferrara/ztl_perimetro.geojson`, salvare il testo delle pagine ufficiali in `data/raw/ferrara/`, mettere una citazione verificata e rilanciare lo script (passa da solo in `Resources/Cities/`).
