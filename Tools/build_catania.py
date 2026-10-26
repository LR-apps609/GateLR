#!/usr/bin/env python3
# Costruisce la scheda di Catania (bozza) da quanto salvato in data/raw/catania/ e data/raw/geo/catania-ztl.json
# (fonti e date in docs/fonti-catania.md).
#
# Regole e citazione dalle «Disposizioni operative per la gestione degli accessi alle Zone a Traffico Limitato ed Aree
# Pedonali» (Comune di Catania / AMTS, PDF su amts.ct.it), salvate in data/raw/catania/amts-disposizioni-operative-ztl-ap.txt
# e ricontrollate parola per parola. www.comune.catania.it non rispondeva (il comunicato del 2022 è letto solo tramite la
# ricerca web, data/raw/catania/websearch-*.txt).
# Zona: ZTL Centro Storico attorno al Teatro Massimo Bellini (piazza Scammacca, via Pulvirenti, via Mazza, piazza Ogninella,
# via Sant'Orsola, via Euplio Reina, via Maria Callas), attiva dal 28/07/2022, «h 24 tutti i giorni dell'anno»; varchi in
# via Sant'Agata e via Landolina. Aree pedonali di piazza Vincenzo Bellini e di via Etnea/piazza Duomo come «pedestrian».
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
CHECKED = "2026-10-26T23:55:00Z"
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


D = "amts-disposizioni-operative-ztl-ap"
QUOTE = "La zona a traffico limitato e le aree pedonali di cui all’articolo 1 sono in vigore h 24 tutti i giorni dell’anno."
check(D, QUOTE,
      "via Antonino di Sangiuliano, via Antonino Mancini, via Euplio Reina, via della Loggetta, via Santa Maria del Rosario, via Sant’Agata, via Vittorio Emanuele, via Leonardi, via Valle, via Landolina",
      "via Euplio Reina, dopo l’incrocio con via della Loggetta, piazza Ogninella, via Sant’Orsola, via Giuseppe Perrotta, piazza Scammacca, via Pulvirenti, via Sant’Agata, dopo l’incrocio con via Santa Maria del Rosario, via Mazza, via Leonardi, dopo l’incrocio con via Valle, via Birreria",
      "Le vie perimetrali suddette individuano esclusivamente i confini della zona a traffico limitato e/o delle aree pedonali, ma non sono ricomprese all’interno delle stesse.",
      "l’area pedonale di piazza Duomo, via Etnea (da via Cardinale Giuseppe Benedetto Dusmet a piazza Stesicoro",
      "l’area pedonale in via Michele Rapisarda e piazza Vincenzo Bellini",
      "allo scopo di agevolare le operazioni di scarico dei bagagli dei clienti nei giorni di arrivo e di partenza, possono richiedere sull’apposita piattaforma web gestita da AMTS Catania s.p.a. il permesso per le targhe dei veicoli dei clienti interessati",
      "Il permesso avrà durata temporanea e comunque non superiore a 12 h dall’emissione.",
      "Ogni struttura ricettiva può richiedere un numero di permessi non superiore al numero di camere in esercizio.",
      "presentano, entro le 48 ore successive al passaggio, all’indirizzo mail ztl@amts.ct.it",
      "I possessori di veicoli a trazione esclusivamente elettrica possono ottenere il permesso di transito nella sola zona a traffico limitato presentando apposita domanda",
      "I titolari dei contrassegni invalidi che hanno necessità di accesso frequente alla zona a traffico limitato devono richiedere on line apposito permesso",
      "Il carico/scarico merci è consentito esclusivamente dalle ore 06,00 alle 08,00 e dalle ore 14,00 alle 16,00.",
      "Il rilascio dei permessi è gratuito.")
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
# Via Etnea pedonale da via Dusmet a piazza Stesicoro (way OSM highway=pedestrian fino a lat 37,5078) e piazza Duomo
ETNEA = [e for e in GEO if e["type"] == "way" and e.get("tags", {}).get("name") in ("Via Etnea", "Piazza Duomo")
         and max(p["lat"] for p in e["geometry"]) < 37.5078]
_dlat, _dlon = 3 / 110574.0, 3 / (111320.0 * 0.7934)
etnea = osm_geo.perimeter(osm_geo.street_area({"id": 0, "members": [
    {"type": "way", "role": "section", "geometry": [{"lat": q["lat"] + a, "lon": q["lon"] + b} for q in w["geometry"]]}
    for w in ETNEA for a, b in ((0, 0), (_dlat, 0), (-_dlat, 0), (0, _dlon), (0, -_dlon))]}, cell_m=5, close_m=25), tol_m=3)
for name, lat, lon in [("Via Etnea", 37.50354, 15.08718), ("Piazza Duomo", 37.50222, 15.08708)]:
    if not osm_geo.contains(etnea, lat, lon):
        raise SystemExit(f"Area pedonale via Etnea: {name} dovrebbe essere dentro")

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
    ("Hotels and B&Bs inside: they request a free temporary permit for your car on the AMTS website (for unloading luggage on arrival and departure, at most 12 hours, no more permits than rooms). No deadline set for the request; other entitled drivers who were not registered can justify a passage within 48 hours (ztl@amts.ct.it).",
     "Alberghi e B&B dentro: chiedono per la tua auto un permesso temporaneo gratuito sul sito AMTS (per scaricare i bagagli all'arrivo e alla partenza, al massimo 12 ore, non più permessi delle camere). Nessuna scadenza indicata per la richiesta; gli altri aventi diritto non registrati possono giustificare il passaggio entro 48 ore (ztl@amts.ct.it).",
     "Hotels und B&Bs innen: Sie beantragen für dein Auto eine kostenlose befristete Genehmigung auf der AMTS-Website (zum Ausladen bei An- und Abreise, höchstens 12 Stunden, nicht mehr Genehmigungen als Zimmer). Keine Frist für den Antrag genannt; andere Berechtigte ohne Registrierung können eine Durchfahrt binnen 48 Stunden begründen (ztl@amts.ct.it)."),
    ("Electric cars need a (free) transit permit requested from AMTS, so GateLR does not exempt them. Motorbikes are not mentioned: only bicycles enter freely. Blue Badge holders who drive in often must register the plate and badge number online with AMTS. Fine 84–335 € (Highway Code, unofficial source). Info: ztl@amts.ct.it.",
     "Le auto elettriche devono chiedere ad AMTS un permesso di transito (gratuito), quindi GateLR non le esenta. Le moto non sono citate: entrano liberamente solo le biciclette. Con il contrassegno disabili, chi entra spesso registra online su AMTS targa e numero del contrassegno. Multa 84–335 € (Codice della Strada, fonte non ufficiale). Info: ztl@amts.ct.it.",
     "Elektroautos brauchen eine (kostenlose) Durchfahrtsgenehmigung von AMTS, daher befreit GateLR sie nicht. Motorräder werden nicht erwähnt: frei einfahren dürfen nur Fahrräder. Wer mit Behindertenausweis oft einfährt, meldet Kennzeichen und Ausweisnummer online bei AMTS. Bußgeld 84–335 € (Straßenverkehrsordnung, inoffizielle Quelle). Info: ztl@amts.ct.it."),
    ("Perimeter and the two cameras from OpenStreetMap: the streets inside match the City's 2022 list (piazza Scammacca, via Pulvirenti, via Mazza, piazza Ogninella, via Sant'Orsola, via Euplio Reina, via Maria Callas). Pedestrian areas drawn: piazza Bellini/via Rapisarda and via Etnea (via Dusmet–piazza Stesicoro) with piazza Duomo; not drawn: San Giovanni li Cuti.",
     "Perimetro e i due varchi da OpenStreetMap: le strade dentro coincidono con l'elenco del Comune del 2022 (piazza Scammacca, via Pulvirenti, via Mazza, piazza Ogninella, via Sant'Orsola, via Euplio Reina, via Maria Callas). Aree pedonali disegnate: piazza Bellini/via Rapisarda e via Etnea (da via Dusmet a piazza Stesicoro) con piazza Duomo; non disegnata: San Giovanni li Cuti.",
     "Grenze und die zwei Kameras aus OpenStreetMap: Die Straßen innen entsprechen der Liste der Stadt von 2022 (Piazza Scammacca, Via Pulvirenti, Via Mazza, Piazza Ogninella, Via Sant'Orsola, Via Euplio Reina, Via Maria Callas). Eingezeichnete Fußgängerzonen: Piazza Bellini/Via Rapisarda und Via Etnea (Via Dusmet–Piazza Stesicoro) mit Piazza Duomo; nicht eingezeichnet: San Giovanni li Cuti."),
]

zone = {"id": "catania-centro-storico", "name": "Teatro Massimo · historic-centre ZTL", "name_it": "Teatro Massimo · ZTL Centro Storico",
        "name_de": "Teatro Massimo · ZTL Altstadt", "kind": "restricted",
        "summary": "The small ZTL around the Teatro Massimo Bellini (piazza Scammacca, via Pulvirenti, piazza Ogninella) is closed to cars without a permit 24 hours a day, every day; cameras at the via Sant'Agata and via Landolina entrances off via Vittorio Emanuele II. Staying inside? Your hotel or B&B can get a free 12-hour permit for your car on the AMTS website. Via Etnea and piazza Bellini are pedestrian.",
        "summary_it": "La piccola ZTL attorno al Teatro Massimo Bellini (piazza Scammacca, via Pulvirenti, piazza Ogninella) è chiusa alle auto senza permesso 24 ore su 24, tutti i giorni; telecamere agli ingressi di via Sant'Agata e via Landolina da via Vittorio Emanuele II. Dormi dentro? L'hotel o il B&B può chiedere per la tua auto un permesso gratuito di 12 ore sul sito AMTS. Via Etnea e piazza Bellini sono pedonali.",
        "summary_de": "Die kleine ZTL rund um das Teatro Massimo Bellini (Piazza Scammacca, Via Pulvirenti, Piazza Ogninella) ist für Autos ohne Genehmigung rund um die Uhr, täglich gesperrt; Kameras an den Zufahrten Via Sant'Agata und Via Landolina von der Via Vittorio Emanuele II. Du übernachtest innen? Hotel oder B&B können auf der AMTS-Website eine kostenlose 12-Stunden-Genehmigung für dein Auto beantragen. Via Etnea und Piazza Bellini sind Fußgängerzonen.",
        "perimeter": shape, "gates": gate_list,
        "windows": [{"weekdays": EVERY_DAY, "start": 0, "end": 24 * 60}],
        "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": True,
        "source": {"authority": "City of Catania", "pageURL": AMTS_RULES, "ordinance": "Disposizioni operative per la gestione degli accessi alle ZTL ed Aree Pedonali (Comune di Catania / AMTS); ZTL attiva dal 28/07/2022",
                   "ordinanceURL": AMTS_RULES, "quote": QUOTE,
                   "quoteTranslation": "The limited traffic zone and the pedestrian areas in article 1 are in force 24 hours a day, every day of the year.",
                   "quoteTranslation_de": "Die verkehrsberuhigte Zone und die Fußgängerzonen nach Artikel 1 gelten rund um die Uhr, an allen Tagen des Jahres.",
                   "checkedOn": CHECKED, "reviewedByHuman": False,
                   "pending": [p[0] for p in PENDING], "pending_it": [p[1] for p in PENDING], "pending_de": [p[2] for p in PENDING],
                   "links": LINKS}}

city = {"id": "catania", "name": "Catania", "name_it": "Catania", "name_de": "Catania",
        "center": {"lat": 37.5030, "lon": 15.0880}, "zones": [zone], "status": "draft",
        "pedestrian": [{"id": "ct-ap-piazza-bellini", "name": "Piazza Vincenzo Bellini", "perimeter": ap},
                       {"id": "ct-ap-via-etnea", "name": "Via Etnea · Piazza Duomo", "perimeter": etnea}],
        "license": "Rules: Comune di Catania and AMTS (operative rules for the ZTL and pedestrian areas). Perimeter, gates and pedestrian area: " + osm_geo.ODBL + " (approximate, not official)."}

# Pubblicabile solo con una citazione verificata sul testo ufficiale; altrimenti bozza
ready = all(len(z["perimeter"]) >= 5 and z["source"]["quote"] for z in city["zones"])
out = ROOT / ("Resources/Cities/catania.json" if ready else "data/drafts/catania.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/catania.json" if ready else "Resources/Cities/catania.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), [(z["id"], len(z["perimeter"]), len(z["gates"])) for z in city["zones"]], f"{area:.3f} km²", "AP", len(ap))
