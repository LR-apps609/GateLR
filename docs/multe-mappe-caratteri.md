# GateLR – Multe ZTL, tecnologia mappe e carattere tipografico

**Data di verifica:** 23 ottobre 2026
**Scopo:** (1) dati per il riquadro "multa potenziale" del sito e dell'app; (2) scelta della tecnologia mappe e della ricerca indirizzi per app iOS e sito; (3) sistema tipografico per GateLR e per la famiglia "LR" (AudioLR, OrbitLR, GateLR, WebcamLR).

> **Nota sul metodo (importante):** anche in questa sessione il proxy di rete ha bloccato quasi tutte le pagine (normattiva.it, brocardi.it, comune.milano.it, sicurauto.it, mapbox.com, docs.mapbox.com, stadiamaps.com, protomaps.com, maptiler.com, geoapify.com, locationiq.com, operations.osmfoundation.org, fonts.google.com, developers.google.com). Erano raggiungibili soltanto **developer.apple.com** (letto direttamente) e **raw.githubusercontent.com** (README di OpenFreeMap e Photon e metadati ufficiali del repository `google/fonts`, letti direttamente). Tutto il resto viene da **estratti dei motori di ricerca**: gli URL sono quelli che la ricerca ha restituito, non sono stati aperti per intero. Le cifre trovate solo su siti secondari sono indicate come tali; quelle contraddittorie o non confermate sono marcate **[non verificato]**. Non ho inventato importi: dove una fonte non c'era, lo dico.

---

## Sintesi delle raccomandazioni

**Multe (riquadro "multa potenziale")**
- Testo consigliato: **"Multa da 83 € a 332 € (art. 7 c. 9 e 14 Codice della Strada); 58,10 € se paghi entro 5 giorni; più spese di notifica. Nessun punto sulla patente."** Fonti: [calcolomulta.it](https://www.calcolomulta.it/multa/accesso-ztl), [autosupermarket.it](https://autosupermarket.it/magazine/normative-auto/multa-ztl), [cercassicurazioni.it](https://www.cercassicurazioni.it/news-assicurazioni/sanzione-in-ztl-a-quanto-ammonta-00043015.html).
- **Nel 2026 non ci sono aumenti ISTAT:** l'aggiornamento biennale (art. 195 c. 3 CdS) è sospeso anche per il 2026 (Milleproroghe convertito, G.U. n. 49 del 28/02/2026). Il prossimo adeguamento potrebbe valere dal **1° gennaio 2027**. Fonti: [polizialocale.com](https://www.polizialocale.com/decreto-milleproroghe-pubblicato-in-gazzetta-ufficiale-la-legge-di-conversione-codice-della-strada-cosa-cambia/), [quattroruote.it](https://www.quattroruote.it/news/multe/2025/12/11/codice_della_strada_governo_blocca_aumento_multe.html), [automobile360.it](https://www.automobile360.it/multe-stradali-2026-importi-congelati-no-aumenti-eccesso-velocita-da-42-845-e-cellulare-422-1-697-e-con-sospensione-patente-come-contestare-ricorso/). **Da ricontrollare a gennaio 2027.**
- **Più passaggi nello stesso giorno:** dal 14/12/2024 (L. 177/2024) l'art. 198 c. 2-bis prevede **una sola sanzione per giorno di calendario** per le violazioni rilevate da remoto nella **stessa ZTL**. Un'app per turisti deve però dire che alcuni comuni possono comunque notificare più verbali, e che in quel caso si chiede l'unificazione.
- **Turisti stranieri:** il comune ha **360 giorni** per notificare a chi risiede all'estero (90 in Italia). Chi noleggia un'auto paga in più una **commissione dell'autonoleggio, di solito tra 25 e 60 € per verbale** (fonti secondarie e forum). L'Antitrust ha multato Sicily by Car (fee di 50 € + IVA) per questa pratica.
- **Milano Area C:** è una ZTL **a pagamento** (ticket 7,50 €, fonte ufficiale del Comune). Si può pagare in ritardo, entro 7 giorni, con il ticket da 22,50 €. Se non si paga, la multa è nella fascia ZTL (le fonti indicano 80/83–332/335 €).

**Mappe**
- **App iOS: Apple MapKit for SwiftUI.** Costo zero oltre ai 99 USD/anno dell'Apple Developer Program, `MapPolygon` e `Annotation` nativi da iOS 17, ricerca con `MKLocalSearchCompleter`. Limite: **niente offline ufficiale**, quindi i poligoni ZTL e le regole vanno salvati in bundle o in cache (l'app sa dire "sei dentro o fuori" anche senza mappa di fondo).
- **Sito: MapLibre GL JS + OpenFreeMap.** Gratis, senza chiave e senza limiti dichiarati. Obbligatoria l'attribuzione "© OpenMapTiles, Data from OpenStreetMap". Piano B se il servizio pubblico (senza SLA) cade: **Protomaps PMTiles dell'Italia in self-hosting** su Cloudflare R2. Alternativa sullo stesso stack Apple: MapKit JS (250.000 visualizzazioni/giorno gratis).
- **Ricerca destinazione o hotel:** nell'app **Apple (MKLocalSearchCompleter)**, gratis; sul sito **ricerca di MapKit JS** (25.000 chiamate/giorno gratis tra MapKit JS e Maps Server API). Alternativa open: **Photon/komoot**, sul server demo solo per un volume modesto oppure in self-hosting. **Non usare** Nominatim pubblico per l'autocompletamento.
- **Costo stimato a 0 / 10k / 100k utenti al mese** con lo stack consigliato: circa **0 €** di servizi mappe (resta solo l'Apple Developer Program, eventualmente qualche euro di R2 per il piano B). Il calcolo è nella sezione 2.5.

**Carattere**
- **Titillium Web va tenuto** come carattere display: è OFL, nato all'Accademia di Belle Arti di Urbino, ha un tono tecnico e "da cartello". Ha però pochi pesi (200–900), non è variabile e non ha cirillico né greco, quindi non va usato come testo corrente.
- **Sistema per la famiglia LR:** **Titillium Web** (display, comune a tutte le app LR) + **Atkinson Hyperlegible Next** (testo sul sito, OFL, variabile 200–800, pensato per la leggibilità). Nelle app il testo corrente resta **SF Pro di sistema** (Dynamic Type), e sul sito Atkinson Next fa da equivalente.
- Tre abbinamenti alternativi: **Barlow Condensed + Barlow** (segnaletica autostradale), **Overpass + Public Sans** (Highway Gothic), **Saira Condensed + Archivo** (tecnico, variabile). Nessun font libero riproduce l'Alfabeto Normale dei cartelli italiani: non ne ho trovato uno con licenza OFL.

---

## 1. Multe ZTL in Italia

### 1.1 Norma e importi (ottobre 2026)

| Voce | Valore | Fonte |
|---|---|---|
| Norma violata | Art. 7, comma 9 (le ZTL sono istituite dai comuni con ordinanza) e comma 14 (sanzione) del D.Lgs. 285/1992 | [claudioiodice.it](https://www.claudioiodice.it/guide_esami_concorsi/ztl-zone-traffico-limitato-art-7-cds.html), [calcolomulta.it](https://www.calcolomulta.it/multa/accesso-ztl) |
| Sanzione per ingresso non autorizzato | **da 83 € a 332 €** | [calcolomulta.it](https://www.calcolomulta.it/multa/accesso-ztl), [autosupermarket.it](https://autosupermarket.it/magazine/normative-auto/multa-ztl), [laleggepertutti.it](https://www.laleggepertutti.it/716284_multe-ztl-quante-se-ne-possono-prendere) |
| Pagamento entro 5 giorni (art. 202) | **−30%: minimo ridotto a 58,10 €** (più spese) | [cercassicurazioni.it](https://www.cercassicurazioni.it/news-assicurazioni/sanzione-in-ztl-a-quanto-ammonta-00043015.html), [laleggepertutti.it](https://www.laleggepertutti.it/716284_multe-ztl-quante-se-ne-possono-prendere) |
| Pagamento entro 60 giorni | minimo edittale, 83 € (più spese) | stesse fonti |
| Spese di accertamento e notifica | variano da comune a comune; esempi: **14,20 €** e circa **14 €** (totale minimo citato: 94 €); un esempio di verbale riporta **98,90 €** (74,00 € entro 5 giorni) | [autosupermarket.it](https://autosupermarket.it/magazine/normative-auto/multa-ztl), [in3giorni.com](https://in3giorni.com/faq/quanto-si-paga-la-multa-per-ztl) **[fonti secondarie]** |
| Punti patente | **nessuna decurtazione** | [autosupermarket.it](https://autosupermarket.it/magazine/normative-auto/multa-ztl), [consulenzalegaleitalia.it](https://consulenzalegaleitalia.it/?p=91) |
| Ricorso | Prefetto entro 60 giorni, Giudice di Pace entro 30 giorni dalla notifica | [discovercars.com](https://www.discovercars.com/it/help/articles/during-your-rental/driving-rules-zones/can-i-drive-into-low-emission-zones-lez-or-restricted-traffic-zones-ztl), [autosupermarket.it](https://autosupermarket.it/magazine/normative-auto/multa-ztl) |

**Aggiornamento ISTAT.** L'art. 195 c. 3 CdS prevede un aggiornamento ogni due anni in base all'indice FOI. È stato sospeso per il 2025 dal D.L. 27/12/2024 n. 202 (G.U. n. 302 del 27/12/2024) e poi **anche per il 2026** dal Milleproroghe (legge di conversione in G.U. n. 49 del 28/02/2026, art. 9 c. 1). Il decreto ministeriale con i nuovi importi andrebbe adottato entro il 1° dicembre 2026, con effetto dal 1° gennaio 2027. Fonti: [polizialocale.com](https://www.polizialocale.com/decreto-milleproroghe-pubblicato-in-gazzetta-ufficiale-la-legge-di-conversione-codice-della-strada-cosa-cambia/), [assimpredilance.it](https://portale.assimpredilance.it/articoli/sanzioni-codice-della-strada-sospeso-aggiornamento-per-l-anno-2025), [quattroruote.it](https://www.quattroruote.it/news/multe/2025/12/11/codice_della_strada_governo_blocca_aumento_multe.html), [asaps.it](https://www.asaps.it/80885-_news_decreto_milleproroghe__aumento_biennale_delle_sanzioni_al_codice_della_str.html). Non ho potuto leggere il testo in Gazzetta (normattiva.it e gazzettaufficiale.it bloccati). **[testo ufficiale non verificato]**

**Cifre in conflitto.** Alcune guide in inglese per turisti (es. [italyplanner.ai](https://italyplanner.ai/italy-ztl-fine-what-to-do.html), [travelinformation.eu](https://travelinformation.eu/italy/traffic-fines/)) parlano di 87 € di base (61 € con lo sconto) per Roma e Firenze, e una fonte prevede 93–95 €. Queste cifre non tornano con il blocco degli aggiornamenti né con la fascia 83–332 € riportata dalle fonti italiane. **Non usarle.**

**Consiglio per il riquadro:** mostrare "83–332 €, 58,10 € se paghi entro 5 giorni (+ spese di notifica, tipicamente 10–20 €*)", con l'asterisco "*varia per comune". Precisare che il conto può includere anche la commissione dell'autonoleggio (vedi 1.3).

### 1.2 Riforma L. 177/2024 ("nuovo codice della strada", in vigore dal 14/12/2024)

| Novità | Contenuto | Fonte |
|---|---|---|
| **Art. 198 c. 2-bis: una multa al giorno** | Se più violazioni degli artt. 6 e 7 sono accertate **da remoto** (varchi, art. 201), senza contestazione immediata, nella **stessa ZTL**, area pedonale o tratto con la stessa limitazione, si applica **una sola sanzione per giorno di calendario**. Il principio vale anche quando il divieto ha più fasce orarie. | [sicurauto.it](https://www.sicurauto.it/news/codice-della-strada/multe-ztl-il-codice-della-strada-2025-limita-le-sanzioni-ecco-come/), [automobilista.it](https://www.automobilista.it/come-cambiano-davvero-le-multe-ztl-nel-2026-tra-tolleranza-cumulo-e-ticket-non-pagato/), [mioppongo.it](https://www.mioppongo.it/circolazione-stradale/piu-multe-ztl-nella-stessa-giornata-sono-contestabili/), [lautomobile.aci.it](https://www.lautomobile.aci.it/?p=19760) |
| **Art. 198 c. 2-ter: tolleranza del 10%** | Chi supera il tempo di permanenza autorizzato (es. ticket o permesso orario) ha una tolleranza del 10%: con un permesso da 60 minuti, fino a 6 minuti. I controlli da remoto valgono solo in condizioni di traffico normale. | [sicurauto.it](https://www.sicurauto.it/news/codice-della-strada/multe-ztl-il-codice-della-strada-2025-limita-le-sanzioni-ecco-come/), [motorimagazine.it](https://www.motorimagazine.it/zone-a-traffico-limitato-regole-sanzioni-e-novita-del-codice-della-strada/) |
| Importi ZTL | Nessuna modifica della fascia 83–332 € trovata | stesse fonti |

Una fonte segnala "eccezioni importanti" alla regola della multa unica, ma non le specifica ([automobilista.it](https://www.automobilista.it/come-cambiano-davvero-le-multe-ztl-nel-2026-tra-tolleranza-cumulo-e-ticket-non-pagato/)). **[non verificato: serve il testo vigente su Normattiva]**

### 1.3 Notifica, turisti stranieri e auto a noleggio

| Voce | Valore | Fonte |
|---|---|---|
| Termine di notifica, residenti in Italia | **90 giorni** dall'accertamento (o dall'identificazione del trasgressore); termine perentorio | [diritto.it](https://www.diritto.it/notificazione-violazioni-codice-della-strada/), [sicurauto.it](https://www.sicurauto.it/news/codice-della-strada/multa-notificata-dopo-90-giorni-quando-e-valida/) |
| Termine di notifica, residenti all'estero | **360 giorni** (art. 201 c. 1) | [diritto.it](https://www.diritto.it/notificazione-violazioni-codice-della-strada/), [businessonline.it](https://www.businessonline.it/articoli/multa-autovelox-entro-quanti-giorni-arriva-tempi-medi-notifica.html), [Corte cost. ord. 149/2000](https://www.cortecostituzionale.it/scheda-pronuncia/2000/149) |
| Commissione dell'autonoleggio per gestire il verbale | intervalli citati: **25–45 €** ([autoeurope.eu](https://www.autoeurope.eu/travel-blog/what-are-ztl-zones-in-italy/)), **25–40 €** ([italyplanner.ai](https://italyplanner.ai/italy-ztl-fine-what-to-do.html)), **40–60 €** a verbale ([forum Rick Steves](https://community.ricksteves.com/travel-forum/italy/traffic-violation)); caso Avis riferito da un utente: 41 €. Si aggiunge alla multa, che arriva separatamente | **[fonti secondarie/forum]** |
| Casi documentati dall'Antitrust | **Sicily by Car**: 50 € + IVA a notifica, sanzione AGCM di 8 milioni €, pagata e impugnata al TAR ([teleborsa.it](https://www.teleborsa.it/AMP/News/2026/03/24/sicily-by-car-paga-sanzione-da-8-milioni-di-euro-all-antitrust-in-attesa-del-tar-253.html), [sicurauto.it](https://www.sicurauto.it/news/attualita-e-curiosita/locauto-e-sicily-by-car-multa-per-clausole-vessatorie/)); **Locauto**: fee di 20 € poi 25 € ([lavocedinewyork.com](https://lavocedinewyork.com/mediterraneo/2025/01/26/ztl-autovelox-e-le-multe-trappola-per-i-turisti-stranieri)); totale citato per le due società: 8,4 milioni € | AGCM via stampa |

Testo consigliato per i turisti: *"Con un'auto a noleggio la multa può arrivarti fino a 12 mesi dopo il viaggio. Il noleggiatore di solito addebita in più sulla carta una commissione amministrativa (spesso 25–60 €)."*

### 1.4 Più passaggi nella stessa giornata: giurisprudenza e prassi locali

| Fonte / periodo | Orientamento |
|---|---|
| Art. 198 c. 2 CdS (testo storico) | Per le ZTL niente cumulo giuridico: si paga **una sanzione per ogni violazione** ([studiocataldi.it](https://www.studiocataldi.it/articoli/20975-ztl-in-caso-di-violazioni-plurime-e-possibile-pagare-solo-la-prima-contravvenzione.asp)) |
| Cass. ord. 26434/2014; Cass. 19754/2009 | Cumulo materiale: una multa per ogni passaggio, anche nello stesso giorno ([businessonline.it](https://www.businessonline.it/articoli/due-multe-nello-stesso-giorno-per-la-stessa-infrazione-si-devono-pagare-o-no-tutti-i-casi-nel.html), [brocardi.it](https://brocardi.it/notizie-giuridiche/multe-uguali-stesso-giorno-stessa-infrazione-dobbiamo-pagarle-entrambe/3314.html)) |
| Cass. 22028/2018 (citata da fonte secondaria) | Stesso percorso e breve lasso di tempo: si può configurare una violazione unica ([studiocataldi.it](https://www.studiocataldi.it/articoli/33878-ztl-violazioni-plurime-quando-si-paga-solo-la-prima-contravvenzione.asp)) |
| **Cass. civ. ord. 19680/2024** (Comune di Terni) | Violazioni ZTL ravvicinate e riconducibili a un'unica programmazione: **un'unica infrazione reiterata**, una sola sanzione ([lentepubblica.it, PDF](https://lentepubblica.it/wp-content/uploads/2024/07/Cassazione-civile-19680-2024.pdf), [lexced.com](https://www.lexced.com/giurisprudenza-civile/violazioni-ztl-come-si-applicano-le-multe-multiple/)) |
| **Dal 14/12/2024: art. 198 c. 2-bis** | **Una sanzione per giorno di calendario** nella stessa ZTL, se la rilevazione è da remoto (vedi 1.2) |
| Firenze (prassi riportata nel 2026) | Una guida sostiene che **ogni varco diverso** attraversato genera un verbale distinto e che entrare e uscire subito non annulla la multa ([autovia.it](https://www.autovia.it/ztl-firenze-guida-completa/)). La guida contrasta con il c. 2-bis se i varchi sono della stessa ZTL. **[non verificato sul sito del Comune]** |
| Milano | Nessuna regola locale trovata sui passaggi multipli |

**Per l'app:** "Per legge (art. 198 c. 2-bis CdS) più passaggi nella stessa ZTL nello stesso giorno valgono **una sola multa**. Se ti arrivano più verbali, puoi chiedere al comando di Polizia Locale di unificarli allegando tutte le notifiche ([laleggepertutti.it](https://www.laleggepertutti.it/716284_multe-ztl-quante-se-ne-possono-prendere))." Non promettere però che "è sempre una sola multa": ZTL diverse nella stessa città (es. ZTL diurna e Scudo Verde a Firenze) restano violazioni distinte.

### 1.5 Milano Area C

| Voce | Valore | Fonte |
|---|---|---|
| Natura | ZTL **a pagamento** (congestion charge) | — |
| Ticket ordinario | **7,50 €** (in vigore dal 30/10/2023) | [Comune di Milano, PDF tariffe 2023](https://www.comune.milano.it/documents/20126/526561/nuove+tariffe+2023+Area+C.pdf) (estratto ufficiale) |
| Pagamento tardivo | **22,50 €** entro 7 giorni dall'accesso (un'altra fonte dice 15 €, in contrasto con il PDF ufficiale) | [Comune di Milano, PDF](https://www.comune.milano.it/documents/20126/526561/nuove+tariffe+2023+Area+C.pdf); [parclick](https://help.parclick.com/en/kb/italy-milan-ztl-area-c) |
| Residenti / veicoli di servizio | 3,00 € / 4,50 € (oltre agli ingressi gratuiti) | [Comune di Milano, PDF](https://www.comune.milano.it/documents/20126/526561/nuove+tariffe+2023+Area+C.pdf) |
| Sanzione senza ticket valido o attivato | fascia ZTL, citata come **80–335 €** o 83–332 € | [alvolante.it](https://www.alvolante.it/da_sapere/legge-e-burocrazia/area-c-milano-mappa-orari-e-regole-379981), [affaritaliani.it](https://www.affaritaliani.it/cronache/area-c-milano-2026-orari-ticket-e-chi-rischia-la-multa.html) **[non verificato su fonte ufficiale]** |
| Orari | Lun–ven 7:30–19:30. Una fonte sostiene un'estensione a sabato e domenica dal 1/1/2026 **[non verificato, probabilmente errato: da confermare sul Comune]** | [milanofree.it](https://www.milanofree.it/milano/trasporti/ztl-milano-2026-guida-ad-area-b-e-area-c-orari-prezzi-e-divieti.html), [automobilista.it](https://www.automobilista.it/ecopass-area-c-e-area-b-nel-2026-cosa-e-cambiato-davvero-per-chi-entra-a-milano/) |
| Termine di attivazione del ticket | Fonti in conflitto (entro la mezzanotte dello stesso giorno o del giorno dopo) **[non verificato]** | [affaritaliani.it](https://www.affaritaliani.it/cronache/area-c-milano-2026-orari-ticket-e-chi-rischia-la-multa.html) |

Per l'app: in Area C lo stato giusto è "**Puoi entrare pagando 7,50 €** (o 22,50 € entro 7 giorni)", non "vietato". Area C ha anche divieti per classe ambientale e lunghezza del veicolo, da trattare in un modulo a parte.

### 1.6 Punti patente

Le violazioni ZTL (art. 7 c. 9 e 14) **non comportano decurtazione di punti** ([autosupermarket.it](https://autosupermarket.it/magazine/normative-auto/multa-ztl), [consulenzalegaleitalia.it](https://consulenzalegaleitalia.it/?p=91)). Non ho trovato modifiche introdotte dalla L. 177/2024 su questo punto.

---

## 2. Mappe

### 2.1 App iOS

| Opzione | Costo | Limiti | Offline | Poligoni / annotazioni | Licenza / attribuzione | Fonte |
|---|---|---|---|---|---|---|
| **Apple MapKit for SwiftUI** | Nessuna tariffa d'uso pubblicata. Richiede l'Apple Developer Program a **99 USD/anno** (già necessario per pubblicare) | Nessun limite pubblicato per le mappe. `MKLocalSearch` ha un limite non documentato: uno sviluppatore riporta circa 50 ricerche al minuto. `MKLocalSearchCompleter` è adatto all'autocompletamento | **Nessuna API offline ufficiale** trovata: senza rete la mappa resta vuota | `MapPolygon`, `MapPolyline`, `Annotation`, `Marker` nativi da **iOS 17** | Logo Apple Maps e "Legale" mostrati automaticamente | [developer.apple.com/programs](https://developer.apple.com/programs/whats-included/), [MapPolygon](https://developer.apple.com/documentation/mapkit/mappolygon), [Annotation](https://developer.apple.com/documentation/mapkit/annotation), [MKLocalSearchCompleter](https://developer.apple.com/documentation/mapkit/mklocalsearchcompleter), [forum Apple](https://developer.apple.com/forums/thread/760867), [technetexperts.com](https://www.technetexperts.com/swiftui-map-view-freeze-no-network/amp/) |
| **Mapbox Maps SDK iOS** | Fatturazione a MAU: **25.000 MAU gratis**, poi **4,00 $ per 1.000 MAU** | Per i tile offline il limite predefinito è 6.000 tile per utente, fatturati a parte (dalla v5.3.0) | Sì (tile pack) | Completo (layer, GeoJSON) | Proprietaria, token obbligatorio, logo Mapbox e attribuzione | [docs.mapbox.com pricing iOS](https://docs.mapbox.com/ios/legacy/maps/guides/pricing/), [apis.io](https://apis.io/plans/mapbox/mapbox-plans-pricing/), [storerocket.io](https://storerocket.io/learn/mapbox-pricing) **[cifre da fonti secondarie]** |
| **MapLibre Native iOS + tile OSM** | SDK gratuito (BSD); il costo dipende da chi fornisce i tile | Dipende dal fornitore | Sì (offline pack: `MLNOfflineStorage`/`MLNOfflinePack`, prima `MGL…`) | Completo (stile JSON, GeoJSON) | BSD + "© OpenStreetMap contributors" + attribuzione del fornitore | [docs.maptiler.com](https://docs.maptiler.com/maplibre-gl-native-ios/Offline%20Maps) |
| – con **OpenFreeMap** | **Gratis**, senza chiave e senza limiti dichiarati; il servizio vive di donazioni | Nessuna SLA; non offre ricerca, routing o raster | Il servizio pubblico non lo prevede esplicitamente; i file planet (`.pmtiles`/`.mbtiles`) sono scaricabili | — | "OpenFreeMap © OpenMapTiles Data from OpenStreetMap" (in MapLibre compare in automatico) | [README OpenFreeMap](https://github.com/hyperknot/openfreemap) (letto) |
| – con **Protomaps** (PMTiles) | Self-hosting: costo di storage e richieste (R2 non fa pagare la banda). API ospitata **gratis solo per uso non commerciale** | Planet circa 106–120 GB; estratto regionale molto più piccolo (circa 200 MB in un esempio italiano) | Sì (un unico file) | — | ODbL/OSM | [protomaps.com/faq](https://protomaps.com/faq), [docs.protomaps.com](https://docs.protomaps.com/pmtiles/cloud-storage), [blog.pinballmap.com](https://blog.pinballmap.com/2024/11/05/protomaps-tile-hosting/) |
| – con **Stadia Maps** | Free: 200.000 crediti/mese, **uso commerciale non consentito**; a pagamento da 20 $/mese | Oltre la soglia restituisce errori, nessun addebito | — | — | Attribuzione Stadia + OSM | [stadiamaps.com](https://stadiamaps.com/learn/what-does-a-free-map-api-cost/), [docs.stadiamaps.com/limits](https://docs.stadiamaps.com/limits/) |
| – con **MapTiler Cloud** | Piano free **solo non commerciale** e R&D; limiti numerici non trovati | Sospensione temporanea oltre i limiti | Sì (SDK) | — | Attribuzione MapTiler + OSM | [maptiler.com/terms/cloud](https://www.maptiler.com/terms/cloud/) |

### 2.2 Sito web

| Opzione | Free tier / prezzo | Chiave | Note | Fonte |
|---|---|---|---|---|
| **MapKit JS** | **250.000 visualizzazioni di mappa/giorno e 25.000 chiamate di servizio/giorno** per membership; Snapshots 25.000/giorno | Token JWT (serve un endpoint che lo firmi) | Stesso aspetto dell'app; annotazioni, overlay e GeoJSON | [developer.apple.com/maps/web](https://developer.apple.com/maps/web/) (letto) |
| **Google Maps JS** | Dal 1/3/2025 ogni SKU Essentials ha **10.000 eventi gratis al mese**. Dynamic Maps: **7,00 $/1.000** fino a 100k, 5,60 $ fino a 500k. Piani in abbonamento Starter 100 $/mese (50k chiamate) ed Essentials 275 $/mese (100k) | Sì, con fatturazione attiva | Costoso oltre la soglia gratuita | [developers.google.com pricing](https://developers.google.com/maps/billing-and-pricing/pricing), [woosmap.com](https://www.woosmap.com/blog/google-maps-api-pricing-breakdown) |
| **Mapbox GL JS** | **50.000 caricamenti/mese gratis**, poi **5,00 $/1.000** | Token obbligatorio | Licenza proprietaria dalla v2 (dic. 2020) | [apis.io](https://apis.io/plans/mapbox/mapbox-plans-pricing/), [wptavern.com](https://wptavern.com/mapbox-gl-js-is-no-longer-open-source) **[cifre secondarie]** |
| **MapLibre GL JS + OpenFreeMap** | **Gratis, nessun limite dichiarato** | **Nessuna** | Fork BSD-3 di Mapbox GL v1.13; stile `https://tiles.openfreemap.org/styles/liberty`; nessuna SLA | [README OpenFreeMap](https://github.com/hyperknot/openfreemap), [osgeo discourse](https://discourse.osgeo.org/t/gfoss-osgeo-discuss-maplibre/19839) |
| **MapLibre GL JS + Protomaps PMTiles self-hosted** | Costo di storage e richieste (R2 senza costi di banda) | Nessuna | Massimo controllo; un file per l'Italia | [docs.protomaps.com](https://docs.protomaps.com/pmtiles/cloud-storage) |
| **Leaflet + tile.openstreetmap.org** | Gratis ma **non adatto**: la policy OSMF vieta senza permesso l'uso intensivo e le app distribuite ad alto traffico, blocca prefetch e offline senza preavviso, nessuna SLA | No | Va bene solo per prototipi | [OSMF tile policy](https://operations.osmfoundation.org/policies/tiles/) (estratto) |

### 2.3 Geocoding: "cerca una destinazione o un hotel"

| Servizio | Free tier | Autocompletamento | Uso commerciale / attribuzione | Fonte |
|---|---|---|---|---|
| **Apple MKLocalSearchCompleter / MKLocalSearch (app)** | Nessun costo pubblicato; limite non documentato (circa 50 ricerche/min riportate) | Sì (Completer) | Incluso in MapKit; buoni risultati sui POI (hotel) | [forum Apple](https://developer.apple.com/forums/thread/760867) |
| **MapKit JS Search / Apple Maps Server API (sito)** | **25.000 chiamate/giorno per team**, condivise tra MapKit JS e Server API; oltre la soglia risponde HTTP 429 | Sì | Incluso nell'Apple Developer Program | [Apple Maps Server API doc](https://developer.apple.com/documentation/applemapsserverapi) (letto) |
| **Nominatim (OSMF pubblico)** | **Massimo 1 richiesta/s**; User-Agent identificativo obbligatorio; cache consigliata; richieste periodiche dalle app "fortemente sconsigliate" | Indicato come vietato (fonte non ufficiale) | Attribuzione OSM | [OSMF Nominatim policy](https://operations.osmfoundation.org/policies/nominatim/) (estratto), [drupal.org](https://www.drupal.org/i/3081749) |
| **Photon (komoot, server demo)** | "Volume ragionevole"; uso eccessivo rallentato o bloccato; nessuna garanzia di disponibilità | Sì (nato per questo) | Software open source, self-hostabile | [README Photon](https://github.com/komoot/photon) (letto) |
| **Google Places Autocomplete** | Autocomplete Requests: 10.000 gratis/mese, poi 2,83 $/1.000; le "Autocomplete Sessions" sono uno SKU separato senza costo (si paga il Place Details successivo) | Sì | Logo Google obbligatorio | [developers.google.com pricing](https://developers.google.com/maps/billing-and-pricing/pricing) (estratto) |
| **Mapbox Geocoding / Search** | Temporary Geocoding: 100.000/mese gratis, poi 0,75 $/1.000 (un'altra fonte dice 5 $) | Sì (Search Box: free tier non trovato) | Logo Mapbox | [storerocket.io](https://storerocket.io/learn/mapbox-pricing), [woosmap.com](https://www.woosmap.com/blog/mapbox-pricing) **[in conflitto]** |
| **Geoapify** | **3.000 crediti/giorno** (circa 90k/mese), 5 richieste/s | Sì | Commerciale consentito con attribuzione e link a Geoapify | [geoapify.com/pricing](https://geoapify.com/pricing) (estratto), [frontdeskreview.com](https://frontdeskreview.com/software/maps-api/geoapify/) |
| **LocationIQ** | **5.000 richieste/giorno**, 2 richieste/s | Sì | Commerciale consentito con link di attribuzione | [locationiq.com/pricing](https://web.locationiq.com/pricing) (estratto) |
| **Stadia Geocoding** | Rientra nei 200k crediti free, ma **non commerciale** | Sì, anche nel piano free | Salvare i risultati richiede un piano a pagamento | [stadiamaps.com/pricing](https://stadiamaps.com/pricing/) |
| **MapTiler Geocoding** | Free solo non commerciale; limiti non trovati | Sì | — | [maptiler.com/terms/cloud](https://www.maptiler.com/terms/cloud/) |

**Raccomandazione per il lancio:** **Apple** in entrambi i casi (Completer nell'app, MapKit JS Search sul sito, entro le 25k chiamate/giorno). Usare il debounce sui tasti (300 ms) e limitare la ricerca al riquadro dell'Italia. Fallback open: **Photon** limitato all'Italia, prima sul server demo con un volume modesto, poi self-hosted (estratto Italia) se il traffico cresce. Se serve un servizio commerciale non Apple: **LocationIQ** o **Geoapify**, con il loro free tier e l'attribuzione.

Nota: se il sito usa le tile OpenFreeMap e la ricerca Apple, va verificato nei termini MapKit JS che i risultati Apple si possano mostrare su una mappa non Apple. Non ho potuto leggere i termini. **[non verificato]** Se non è consentito, sul sito si usa Photon o LocationIQ, oppure si passa tutto a MapKit JS.

### 2.4 Raccomandazione

- **App iOS: MapKit for SwiftUI.** Motivi: zero costi aggiuntivi, nessuna chiave, aspetto nativo, `MapPolygon` per i perimetri ZTL, `Annotation` per i varchi, privacy Apple, dark mode e localizzazione automatiche. Il limite dell'offline si aggira così: la logica "sei dentro o fuori dalla ZTL, varco attivo o no" lavora su GeoJSON in bundle o in cache e funziona anche senza tile. Se in futuro l'offline completo diventa un requisito (turisti senza roaming), si passa a **MapLibre Native + estratto PMTiles dell'Italia** (Protomaps o OpenFreeMap), che costa poco e non ha costi per utente.
- **Sito: MapLibre GL JS + OpenFreeMap**, con lo stesso GeoJSON ZTL dell'app. Zero chiavi, zero costi e un codice indipendente dal fornitore. Piano B già pronto: stesso codice puntato su un PMTiles self-hosted. Alternativa da valutare: **MapKit JS**, se la coerenza visiva con l'app conta più dell'indipendenza; 250k visualizzazioni/giorno bastano ampiamente.
- **Da evitare al lancio:** Google Maps (costi variabili e carta di credito), Mapbox (token e costi oltre la soglia, licenza proprietaria), tile.openstreetmap.org (vietato per uso intensivo).

### 2.5 Costi stimati (ipotesi dichiarate)

Ipotesi: ogni utente apre **3 mappe** e fa **5 ricerche** al mese (con l'autocompletamento circa 5 richieste per ricerca, quindi 25 richieste). Le stime usano solo i prezzi citati sopra.

| Stack | 0 utenti | 10k utenti/mese | 100k utenti/mese |
|---|---|---|---|
| **Consigliato:** MapKit (app) + MapLibre/OpenFreeMap (sito) + ricerca Apple | 99 USD/anno (Developer Program) | 99 USD/anno. Ricerca sito: circa 250k richieste/mese ≈ 8,3k/giorno, sotto le 25k/giorno | 99 USD/anno. Ricerca sito: circa 2,5M/mese ≈ 83k/giorno, **sopra le 25k/giorno**: servono debounce o cache, oppure Photon self-hosted (costo di un piccolo server, non quantificato) o un contatto con Apple |
| Mapbox (app SDK + GL JS) | 0 | App: 10k MAU < 25k gratis. Web: 30k caricamenti < 50k gratis → **0 $** | App: 75k MAU × 4 $/1k = **circa 300 $/mese**. Web: 250k caricamenti oltre soglia × 5 $/1k = **circa 1.250 $/mese** (secondo listino secondario) |
| Google Maps JS (solo sito) | 0 | 30k caricamenti: 20k × 7 $/1k = **circa 140 $/mese**, più l'autocompletamento oltre i 10k gratis | 300k caricamenti: 90k × 7 $ + 200k × 5,60 $ = **circa 1.750 $/mese**, più la ricerca |

Le stime per Mapbox e Google vanno ricalcolate sui listini ufficiali, che non ho potuto aprire.

---

## 3. Carattere (typeface e brand)

### 3.1 Titillium Web (attuale)

| Aspetto | Valutazione | Fonte |
|---|---|---|
| Origine | Progetto didattico dell'**Accademia di Belle Arti di Urbino** (master Campi Visivi), carattere "collettivo" | [google/fonts DESCRIPTION](https://github.com/google/fonts/tree/main/ofl/titilliumweb) (letto) |
| Licenza | **OFL**: incorporabile nell'app e usabile come webfont (già in `Resources/Fonts/OFL.txt`) | METADATA.pb (letto) |
| Pesi | 200, 300, 400, 600, 700, 900 + corsivi (5); **non variabile** | METADATA.pb |
| Script | solo latin e latin-ext (niente cirillico e greco) | METADATA.pb |
| Carattere | Squadrato e tecnico, aperture ampie: richiama la segnaletica e il motorsport. Ha una forte identità italiana, e questo è un vantaggio per il racconto di "Know before the gate" | — |
| Leggibilità a piccoli corpi | Discreta in SemiBold e Bold per le etichette. Sotto i 13 pt e nei testi lunghi è meno leggibile di un grottesco umanista (occhio medio, forme strette) | valutazione editoriale |
| Google Fonts | Sì | — |

**Verdetto:** tenerlo come **display e etichette** (lo usa già `Theme.swift`) e affiancargli un carattere per il testo corrente.

### 3.2 Tre abbinamenti alternativi (tutti OFL e su Google Fonts)

Dati di licenza, pesi e designer presi da `METADATA.pb` e `DESCRIPTION.en_us.html` del repository ufficiale [github.com/google/fonts](https://github.com/google/fonts) (letti direttamente).

| # | Display | Testo | Licenza | Pesi | Perché si addice | Piccoli corpi |
|---|---|---|---|---|---|---|
| A | **Barlow Condensed** (Jeremy Tribby) | **Barlow** | OFL | 100–900 + corsivi, in tre larghezze (Normal, Semi Condensed, Condensed), 18 file per famiglia | Ispirato dichiaratamente a targhe, **cartelli autostradali**, bus e treni della California: ha il "sapore da cartello", ma non è italiano | Buona: grottesco poco contrastato e leggermente arrotondato; il Condensed va usato solo per i titoli |
| B | **Overpass** (Delve Fonts) | **Public Sans** (USWDS, basato su Libre Franklin) | OFL | Entrambi variabili 100–900 + corsivo | Overpass interpreta l'**Highway Gothic** (FHWA): è il riferimento più diretto alla segnaletica. Public Sans è neutro e istituzionale | Buona. Overpass è ottimizzato per lo schermo; Public Sans è pensato per le interfacce |
| C | **Saira Condensed / Saira** (Omnibus-Type) | **Archivo** (Omnibus-Type) | OFL | Saira variabile, larghezza 50–125 e peso 100–900; Archivo variabile, larghezza 62–125 e peso 100–900 | Tecnico e squadrato come Titillium, con l'asse larghezza per adattare i nomi lunghi dei varchi (come fa l'"Alfabeto stretto" dei cartelli) | Buona per Archivo; Saira va usato per titoli ed etichette |

Altri valutati:
- **Inter** (OFL, peso 100–900, asse opsz 14–32): ottimo per il testo ma senza carattere.
- **Atkinson Hyperlegible Next** (OFL, 2025, peso 200–800): è la scelta migliore per l'accessibilità, vedi 3.3.
- **IBM Plex Sans** (OFL, peso 100–700, larghezza 75–100): solido ma "corporate".
- **Exo 2** (OFL, peso 100–900): troppo "futuristico".
- **Alfa Slab One** (OFL, un solo peso): solo per manifesti, inadatto a una UI.

**Segnaletica italiana vera:** l'Alfabeto Normale e l'Alfabeto Stretto (art. 125 del Regolamento del CdS, derivati dal britannico Transport) non hanno, per quanto ho trovato, versioni OFL o libere. Le versioni digitali note (es. "LLM Normal/Narrow") hanno una licenza non chiarita ([wikipedia: Road signs in Italy](https://en.wikipedia.org/wiki/Road_signs_in_Italy), [typography.guru](https://typography.guru/journal/traffic-sign-typefaces-italy-r28/), [Wikipedia: LLM Lettering](https://en.wikipedia.org/wiki/LLM_Lettering)). Sconsigliato usarle. **[licenza non verificata]**

### 3.3 Sistema tipografico per la famiglia "LR"

| Ruolo | Font | Uso |
|---|---|---|
| **Display di famiglia** (titoli, wordmark "…LR", numeri grandi, etichette) | **Titillium Web** Bold, Black e SemiBold | Uguale in AudioLR, OrbitLR, GateLR e WebcamLR: è la firma della famiglia, italiana (Urbino) e OFL |
| **Testo** sul sito (paragrafi, tabelle, form) | **Atkinson Hyperlegible Next** (variabile 200–800 + corsivo) | Pensato dal Braille Institute per distinguere i caratteri ambigui (l/I/1, 0/O): utile a turisti che leggono in una seconda lingua e a codici, targhe e orari. È OFL e su Google Fonts |
| **Testo nelle app iOS** | **SF Pro di sistema** (Dynamic Type) | Accessibilità e scalatura automatiche; nessun file da incorporare. Sul web si usa Atkinson Next (SF non si può distribuire come webfont) |

Motivi della scelta:
1. Un solo carattere "di marca" condiviso tiene la famiglia riconoscibile anche se le singole app hanno colori diversi.
2. Titillium funziona bene in grande, Atkinson Next a corpi piccoli: i ruoli si completano senza sovrapporsi.
3. Entrambi sono OFL e su Google Fonts: si possono ospitare sul sito (self-hosting dei WOFF2 consigliato per la privacy GDPR) e incorporare nelle app.
4. Limite noto: nessuno dei due ha il cirillico (Atkinson Next copre latin e latin-ext). Se in futuro servono russo o greco, si sostituisce il testo con **Inter** o **IBM Plex Sans**, che coprono cirillico e greco.

Se si preferisce un'alternativa più "stradale" per la sola GateLR, si usa **Barlow Semi Condensed** per i nomi dei varchi e i badge di stato, mantenendo Titillium come display di famiglia.

---

## Fonti lette direttamente (non solo estratti)
- https://developer.apple.com/maps/web/ (limiti MapKit JS)
- https://developer.apple.com/programs/whats-included/ (99 USD/anno)
- Documentazione Apple (JSON) per MapPolygon, Annotation, MKLocalSearchCompleter, Apple Maps Server API (25.000 chiamate/giorno per team, HTTP 429)
- https://github.com/hyperknot/openfreemap (README: gratuito, senza limiti, attribuzione, nessun geocoding)
- https://github.com/komoot/photon (README: termini del server demo)
- https://github.com/google/fonts (METADATA.pb e DESCRIPTION di Titillium Web, Barlow, Overpass, Public Sans, Inter, Atkinson Hyperlegible/Next, IBM Plex Sans, Exo 2, Saira, Archivo, Alfa Slab One)

Tutte le altre fonti citate sono state consultate tramite estratti dei motori di ricerca, perché i domini erano bloccati dal proxy.
