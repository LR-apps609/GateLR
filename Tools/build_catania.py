#!/usr/bin/env python3
# Costruisce la scheda di Catania (bozza) da quanto salvato in data/raw/catania/ e data/raw/geo/catania-ztl.json
# (fonti e date in docs/fonti-catania.md).
#
# Il 26/10/2026 dal sandbox www.comune.catania.it, www.amts.ct.it e la stampa locale non erano raggiungibili (il proxy
# rifiuta la connessione, 403; WebFetch non risolve gli host). Il workflow «Scarica pagine» non è stato usato per aggirare
# il blocco. Le regole vengono dai riassunti della ricerca web (data/raw/catania/websearch-*.txt), NON testo letterale:
#   - nessuna citazione («quote»: null); la scheda resta in data/drafts/catania.json.
# Zona: ZTL Centro Storico attorno al Teatro Massimo Bellini (piazza Scammacca, via Pulvirenti, via Mazza, piazza Ogninella,
# via Sant'Orsola, via Euplio Reina, via Maria Callas), attiva dal 28/07/2022, 24 ore su 24 tutti i giorni; varchi in via
# Sant'Agata e via Landolina. Area pedonale di piazza Vincenzo Bellini come «pedestrian».
#
# Geometria: OpenStreetMap (© OpenStreetMap contributors, ODbL 1.0), relazione 14421298 «ZTL Centro Storico»
# (boundary=limited_traffic_zone) e relazione 20064601 «Area Pedonale Piazza Vincenzo Bellini»; varchi dalle relazioni
# enforcement 14421292 e 14421293 (nodi device, operator «Comune di Catania»). Scaricata dall'API principale di OSM con
# Tools/fetch_osm_api.py. Le strade dentro il perimetro OSM sono esattamente quelle elencate dal Comune nel 2022.
# Uso: python3 Tools/build_catania.py   (non tocca le altre città né manifest.json)
import json, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/catania"
CHECKED = "2026-10-26T23:45:00Z"
EVERY_DAY = [1, 2, 3, 4, 5, 6, 7]
OSM_ZTL, OSM_AP = 14421298, 20064601

PRESS_2022 = "https://www.comune.catania.it/informazioni/cstampa/default.aspx?cs=84326"
AMTS_RULES = "https://www.amts.ct.it/wp-content/uploads/Sostare/Disposizioni_%20operative_%20accesso_alle_ZTL_e_%20AP.pdf"
AMTS_NEWS = "https://www.amts.ct.it/ztl-e-aree-pedonali-nella-citta-di-catania-un-primo-bilancio-sui-vantaggi-per-la-mobilita"
NEWS_2022 = "https://www.cataniatoday.it/cronaca/ztl-centro-storico-attivazione-comune-catania-1-luglio-2022.html"


def flat(s):
    return re.sub(r"\s+", " ", s).strip()


TEXT = {p.stem: flat(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def check(file, *phrases):
    """Ogni fatto usato deve comparire, parola per parola, nel testo salvato (qui: riassunti della ricerca)"""
    for q in phrases:
        if flat(q) not in TEXT[file]:
            raise SystemExit(f"{file}: frase non trovata: {q!r}")


check("websearch-1-orari-varchi",
      "La ZTL di Catania non prevede fasce orarie. È attiva ventiquattro ore su ventiquattro, tutti i giorni dell'anno.",
      "Le telecamere a protezione della ZTL di Catania sono in funzione tutti i giorni 24 ore su 24.",
      "Operating hours: Mon-Fri 8am-8pm",
      "I due punti di controllo principali si trovano in via Sant'Agata e via Landolina",
      "describes the zone as covering piazza Scammacca, via Pulvirenti, via Mazza, piazza Ogninella, and via Sant'Orsola",
      "when fines through the access-point cameras were to begin", "ztl@amts.ct.it")
check("websearch-2-hotel-permessi",
      "The AMTS regulations let accommodation providers request temporary permits for guests' vehicles",
      "lasts no more than 12 hours from issue", "Providers submit requests through the AMTS online platform.",
      "Electric cars: Results indicate that electric cars are not automatically exempt.",
      "between 84 and 335 euros", "the disabled person is on board", "None of the results addressed motorcycles in the ZTL.")

GEO = osm_geo.load("catania-ztl")
GATE_NAMES = {14421293: "Varco · Via Sant'Agata / Via Vittorio Emanuele II", 14421292: "Varco · Via Landolina / Via Vittorio Emanuele II"}


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


ring = osm_geo.outer_ring(osm_geo.relation(GEO, OSM_ZTL))
shape = osm_geo.perimeter(ring, tol_m=3)
gate_list = sorted((osm_geo.gate_json("ct", (g[0], GATE_NAMES[rid], g[2], g[3]))
                    for rid in GATE_NAMES for g in osm_geo.gates(GEO, relation_ids={rid}, name_prefix=None)), key=lambda g: g["name"])
if len(gate_list) != 2:
    raise SystemExit(f"Attesi 2 varchi, trovati {len(gate_list)}")
for g in gate_list:
    if osm_geo.distance_m(shape, g["location"]["lat"], g["location"]["lon"]) > 40:
        raise SystemExit(f"Varco lontano dal bordo: {g['name']}")
# Controlli (coordinate dagli stessi dati OSM): Teatro Massimo Bellini dentro; Duomo, via Etnea, stazione fuori
for name, lat, lon, inside in [("Teatro Massimo Bellini", 37.50418, 15.08989, True), ("Cattedrale di Sant'Agata", 37.50251, 15.08853, False),
                               ("Via Etnea", 37.50354, 15.08718, False), ("Stazione Catania Centrale", 37.5065, 15.0995, False)]:
    if osm_geo.contains(shape, lat, lon) != inside:
        raise SystemExit(f"Controllo perimetro fallito: {name} dovrebbe essere {'dentro' if inside else 'fuori'}")
area = osm_geo.area_km2(shape)
if not 0.01 < area < 0.1:
    raise SystemExit(f"Area della ZTL non plausibile: {area:.3f} km²")
ap = osm_geo.perimeter(osm_geo.outer_ring(osm_geo.relation(GEO, OSM_AP), roles=("", "outer")), tol_m=2)

LINKS = [link("City of Catania (2022): historic-centre ZTL cameras on", "Comune di Catania (2022): ZTL Centro Storico, telecamere attive",
              "Stadt Catania (2022): Kameras der ZTL Centro Storico aktiv", PRESS_2022),
         link("AMTS (city mobility company): rules for entering the ZTL and pedestrian areas (PDF)", "AMTS: disposizioni operative per l'accesso alle ZTL e AP (PDF)",
              "AMTS (städtische Mobilitätsgesellschaft): Regeln für die Zufahrt zu ZTL und Fußgängerzonen (PDF)", AMTS_RULES),
         link("AMTS: ZTL and pedestrian areas in Catania", "AMTS: «ZTL e Aree pedonali» nella città di Catania", "AMTS: ZTL und Fußgängerzonen in Catania", AMTS_NEWS),
         link("CataniaToday (2022): the ZTL starts, fines from 28 July", "CataniaToday (2022): attiva la ZTL, sanzioni dal 28 luglio",
              "CataniaToday (2022): ZTL startet, Bußgelder ab 28. Juli", NEWS_2022),
         link(f"OpenStreetMap: relation {OSM_ZTL} «ZTL Centro Storico» (ODbL)", f"OpenStreetMap: relazione {OSM_ZTL} «ZTL Centro Storico» (ODbL)",
              f"OpenStreetMap: Relation {OSM_ZTL} «ZTL Centro Storico» (ODbL)", osm_geo.osm_url("relation", OSM_ZTL))]

PENDING = [
    ("Draft: the City's and AMTS websites could not be read from here (connection refused). Every rule comes from web-search summaries of the official pages and press, not from their text: to be checked word for word.",
     "Bozza: i siti del Comune e di AMTS non erano leggibili da qui (connessione rifiutata). Ogni regola viene dai riassunti della ricerca web sulle pagine ufficiali e sulla stampa, non dal loro testo: da verificare parola per parola.",
     "Entwurf: Die Websites der Stadt und der AMTS waren von hier aus nicht lesbar (Verbindung abgelehnt). Alle Regeln stammen aus Zusammenfassungen der Websuche zu offiziellen Seiten und Presse, nicht aus deren Text: Wort für Wort zu prüfen."),
    ("Hours 24 hours a day, every day: confirmed only by unofficial guides (autovia.it, sicurauto.it); one site says Monday–Friday 8 am–8 pm. GateLR uses 24 hours as the safer answer. The ordinance number was not found.",
     "Orario 0–24 tutti i giorni: confermato solo da guide non ufficiali (autovia.it, sicurauto.it); un sito indica lun–ven 8–20. GateLR usa 0–24, la risposta più prudente. Il numero dell'ordinanza non è stato trovato.",
     "Zeiten rund um die Uhr, täglich: nur von inoffiziellen Ratgebern bestätigt (autovia.it, sicurauto.it); eine Seite nennt Mo–Fr 8–20 Uhr. GateLR nimmt 24 Stunden als sicherere Antwort. Die Nummer der Verordnung wurde nicht gefunden."),
    ("Hotels and B&Bs inside: they request a free temporary permit for your car on the AMTS website (for unloading luggage on arrival and departure, at most 12 hours, no more permits than rooms). Deadline for the request not found.",
     "Alberghi e B&B dentro: chiedono per la tua auto un permesso temporaneo gratuito sul sito AMTS (per scaricare i bagagli all'arrivo e alla partenza, al massimo 12 ore, non più permessi delle camere). Scadenza della richiesta non trovata.",
     "Hotels und B&Bs innen: Sie beantragen für dein Auto eine kostenlose befristete Genehmigung auf der AMTS-Website (zum Ausladen bei An- und Abreise, höchstens 12 Stunden, nicht mehr Genehmigungen als Zimmer). Frist für den Antrag nicht gefunden."),
    ("Electric cars: not automatically exempt, so GateLR does not exempt them. Motorbikes: not covered by the sources. Blue Badge: allowed with the person on board; how to register the plate not found. Fine 84–335 € (Highway Code). Info: ztl@amts.ct.it, 095 7519367.",
     "Auto elettriche: non esenti in automatico, quindi GateLR non le esenta. Moto: le fonti non ne parlano. Contrassegno disabili: ammessi con la persona a bordo; non trovato come registrare la targa. Multa 84–335 € (Codice della Strada). Info: ztl@amts.ct.it, 095 7519367.",
     "Elektroautos: nicht automatisch befreit, daher befreit GateLR sie nicht. Motorräder: in den Quellen nicht behandelt. Behindertenausweis: erlaubt mit der Person an Bord; wie das Kennzeichen gemeldet wird, nicht gefunden. Bußgeld 84–335 € (Straßenverkehrsordnung). Info: ztl@amts.ct.it, 095 7519367."),
    ("Perimeter and the two cameras from OpenStreetMap: the streets inside match the City's 2022 list (piazza Scammacca, via Pulvirenti, via Mazza, piazza Ogninella, via Sant'Orsola, via Euplio Reina, via Maria Callas). Not shown: the camera-watched pedestrian streets (via Etnea, via Crociferi, via Sciuti, via Mazzini, San Giovanni li Cuti seafront); only piazza Bellini is drawn as a pedestrian area.",
     "Perimetro e i due varchi da OpenStreetMap: le strade dentro coincidono con l'elenco del Comune del 2022 (piazza Scammacca, via Pulvirenti, via Mazza, piazza Ogninella, via Sant'Orsola, via Euplio Reina, via Maria Callas). Non mostrate: le aree pedonali con telecamera (via Etnea, via Crociferi, via Sciuti, via Mazzini, lungomare di San Giovanni li Cuti); solo piazza Bellini è disegnata come area pedonale.",
     "Grenze und die zwei Kameras aus OpenStreetMap: Die Straßen innen entsprechen der Liste der Stadt von 2022 (Piazza Scammacca, Via Pulvirenti, Via Mazza, Piazza Ogninella, Via Sant'Orsola, Via Euplio Reina, Via Maria Callas). Nicht gezeigt: die kameraüberwachten Fußgängerstraßen (Via Etnea, Via Crociferi, Via Sciuti, Via Mazzini, Uferstraße San Giovanni li Cuti); nur die Piazza Bellini ist als Fußgängerzone eingezeichnet."),
]

zone = {"id": "catania-centro-storico", "name": "Teatro Massimo · historic-centre ZTL", "name_it": "Teatro Massimo · ZTL Centro Storico",
        "name_de": "Teatro Massimo · ZTL Altstadt", "kind": "restricted",
        "summary": "The small ZTL around the Teatro Massimo Bellini (piazza Scammacca, via Pulvirenti, piazza Ogninella) is closed to cars without a permit 24 hours a day, every day; cameras at the via Sant'Agata and via Landolina entrances off via Vittorio Emanuele II. Staying inside? Your hotel or B&B can get a free 12-hour permit for your car on the AMTS website. Via Etnea and piazza Bellini are pedestrian.",
        "summary_it": "La piccola ZTL attorno al Teatro Massimo Bellini (piazza Scammacca, via Pulvirenti, piazza Ogninella) è chiusa alle auto senza permesso 24 ore su 24, tutti i giorni; telecamere agli ingressi di via Sant'Agata e via Landolina da via Vittorio Emanuele II. Dormi dentro? L'hotel o il B&B può chiedere per la tua auto un permesso gratuito di 12 ore sul sito AMTS. Via Etnea e piazza Bellini sono pedonali.",
        "summary_de": "Die kleine ZTL rund um das Teatro Massimo Bellini (Piazza Scammacca, Via Pulvirenti, Piazza Ogninella) ist für Autos ohne Genehmigung rund um die Uhr, täglich gesperrt; Kameras an den Zufahrten Via Sant'Agata und Via Landolina von der Via Vittorio Emanuele II. Du übernachtest innen? Hotel oder B&B können auf der AMTS-Website eine kostenlose 12-Stunden-Genehmigung für dein Auto beantragen. Via Etnea und Piazza Bellini sind Fußgängerzonen.",
        "perimeter": shape, "gates": gate_list,
        "windows": [{"weekdays": EVERY_DAY, "start": 0, "end": 24 * 60}],
        "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": True,
        "source": {"authority": "City of Catania", "pageURL": PRESS_2022, "ordinance": "ZTL Centro Storico (attiva dal 28/07/2022); disposizioni operative AMTS",
                   "ordinanceURL": AMTS_RULES, "quote": None, "quoteTranslation": None, "quoteTranslation_de": None,
                   "checkedOn": CHECKED, "reviewedByHuman": False,
                   "pending": [p[0] for p in PENDING], "pending_it": [p[1] for p in PENDING], "pending_de": [p[2] for p in PENDING],
                   "links": LINKS}}

city = {"id": "catania", "name": "Catania", "name_it": "Catania", "name_de": "Catania",
        "center": {"lat": 37.5030, "lon": 15.0880}, "zones": [zone], "status": "draft",
        "pedestrian": [{"id": "ct-ap-piazza-bellini", "name": "Piazza Vincenzo Bellini", "perimeter": ap}],
        "license": "Rules: Comune di Catania and AMTS (read through web-search summaries). Perimeter, gates and pedestrian area: " + osm_geo.ODBL + " (approximate, not official)."}

# Pubblicabile solo con una citazione verificata sul testo ufficiale; altrimenti bozza
ready = all(len(z["perimeter"]) >= 5 and z["source"]["quote"] for z in city["zones"])
out = ROOT / ("Resources/Cities/catania.json" if ready else "data/drafts/catania.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/catania.json" if ready else "Resources/Cities/catania.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), [(z["id"], len(z["perimeter"]), len(z["gates"])) for z in city["zones"]], f"{area:.3f} km²", "AP", len(ap))
