#!/usr/bin/env python3
# Costruisce la scheda di Matera (bozza) da quanto salvato in data/raw/matera/ e data/raw/geo/matera-sassi.json
# (fonti e date in docs/fonti-matera.md).
#
# Il 26/10/2026 dal sandbox comune.matera.it, dati.comune.matera.it e materawelcome.it non erano raggiungibili (il proxy
# rifiuta la connessione, 403; WebFetch non risolve gli host). Il workflow «Scarica pagine» non è stato usato per aggirare
# il blocco. Le regole 2024–2026 vengono quindi dai riassunti della ricerca web (data/raw/matera/websearch-*.txt), che
# citano le ordinanze del Comune ma NON sono testo letterale; l'unico testo ufficiale letterale è l'estratto
# dell'ordinanza del 2014 nei metadati del dataset «ZTL e APU» su dati.gov.it (orari superati). Per questo:
#   - nessuna citazione («quote»: null); la scheda resta in data/drafts/matera.json.
# Regole: ZTL Sassi da O.D. n. 147/2025 (10–20:30 dal 16/09 al 30/06, 10–24 dal 01/07 al 15/09, tutti i giorni);
# ZTL Centro (con la Civita: vie Scotellaro, Corso, Beccherie, Duomo, Sedile, San Francesco) e ZTL San Giovanni/San Biagio
# 0–24 tutti i giorni (tabella orari dal 09/09/2024, O.D. n. 261/2024). ZTL Prefettura e Ridola (sera) non modellate.
#
# Geometria: OpenStreetMap (© OpenStreetMap contributors, ODbL 1.0), scaricata dall'API principale di OSM con
# Tools/fetch_osm_api.py. In OSM non ci sono aree ZTL a Matera: ogni zona è l'area coperta dalle strade dell'elenco
# ufficiale (osm_geo.street_area). Per i Sassi: le strade carrabili nominate dall'ordinanza («via D'Addozio, Via Fiorentini,
# Via Sant'Antonio Abate, Via Madonna delle Virtù, via Bruno Buozzi, ed ogni altra strada interna ai Rioni Sassi …, con
# esclusione di via Casalnuovo e Via Santo Stefano») più ogni strada o scalinata OSM il cui punto centrale cade nelle aree
# OSM «Sasso Caveoso» e «Sasso Barisano» (place=neighbourhood). Varchi: i nodi OSM con nome «ZTL …» vicini al bordo.
# Esiste un perimetro UFFICIALE (GeoJSON/KML «ZTL_APU_MATERA_AGO2014», dati.comune.matera.it): se viene salvato come
# data/raw/matera/ztl_<zona>.geojson lo script usa quello.
# Uso: python3 Tools/build_matera.py   (non tocca le altre città né manifest.json)
import json, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/matera"
CHECKED = "2026-10-26T23:30:00Z"
EVERY_DAY = [1, 2, 3, 4, 5, 6, 7]
WINTER = {"fromMonth": 9, "fromDay": 16, "toMonth": 6, "toDay": 30}
SUMMER = {"fromMonth": 7, "fromDay": 1, "toMonth": 9, "toDay": 15}

ORD_147 = "https://comune.matera.it/wp-content/uploads/2025/05/Ordinanza_Dirigenziale_147_2025-ZTL-SASSI.pdf"
HOURS_2025 = "https://comune.matera.it/wp-content/uploads/2025/05/ORARI-TELECAMERE-BARRIERE.pdf"
HOURS_2024 = "https://www.comune.matera.it/wp-content/uploads/2025/03/Orari-Telecamere-Barriere-dal-09.09.2024.pdf"
ZTL_PAGE = "https://comune.matera.it/ztl-apu/"
HOTELS = "https://comune.matera.it/wp-content/uploads/2024/01/Procedura-per-comunicazione-transiti-da-parte-di-strutture-ricettive-e-autorimesse.pdf"
OPEN_DATA = "https://www.dati.gov.it/view-dataset/dataset?id=ztl-e-apu"
WELCOME = "https://www.materawelcome.it/it/informazioni-turistiche/prima-di-partire/ztl/"


def flat(s):
    return re.sub(r"\s+", " ", s).strip()


TEXT = {p.stem: flat(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def check(file, *phrases):
    """Ogni fatto usato deve comparire, parola per parola, nel testo salvato"""
    for q in phrases:
        if flat(q) not in TEXT[file]:
            raise SystemExit(f"{file}: frase non trovata: {q!r}")


check("websearch-1-sassi-orari",
      "Periodo estivo compreso dal 01 luglio al 15 settembre, di ogni anno, dalle ore 10.00 alle ore 24:00; periodo invernale compreso dal 16 settembre al 30 giugno, di ogni anno, dalle ore 10.00 alle ore 20:30",
      "The Sassi gates on Via Buozzi, Via Madonna delle Virtù and Via D'Addozio",
      "between 19 January and 15 March 2026", "I found no ordinance changing the ZTL for June–October 2026.")
check("websearch-2-centro-orari",
      "ZTL CENTRO (Vie Scotellaro, Corso, Beccherie, Duomo, Sedile, S. Francesco) 00:00 - 24:00, and the San Giovanni/San Biagio zone is also 00:00–24:00",
      "ZTL PREFETTURA (Via Roma Via XX Settembre) 20:30 - 24:00", "Civita and San Biagio: Tolltracker says these are from 01/01 to 31/12, from 00:00 to 24:00.")
check("websearch-3-hotel-permessi",
      "plate communications from lodging facilities go through its online portal", "The portal is reached at matera.sismic.it",
      "covers only the ZTLs where guests may be allowed in for luggage loading and unloading",
      "Electric cars: I found no evidence that Matera grants electric cars the same access.")
check("dati-gov-ztl-e-apu-estratto-ordinanza-2014",   # elenco ufficiale delle strade (2014) usato per la geometria
      "ZTL Sassi: (area che comprende via D’Addozio, Via Fiorentini, Via Sant’Antonio Abate, Via Madonna delle Virtù, via Bruno Buozzi, ed ogni altra strada interna ai Rioni Sassi limitrofa alle anzidette strade, con esclusione di via Casalnuovo e Via Santo Stefano)",
      "ZTL Centro: (via A. Volta, via D. Ridola", "ZTL Civita: ( via e piazza Duomo",
      "ZTL San Biagio: (via T. Stigliani", "nonché i veicoli a completa trazione elettrica")

GEO = osm_geo.load("matera-sassi")
WAYS = [e for e in GEO if e["type"] == "way"]
HW = {"residential", "service", "living_street", "pedestrian", "unclassified", "footway", "steps", "path", "track"}
NEIGHBOURHOODS = [[(p["lon"], p["lat"]) for p in w["geometry"]] for w in WAYS if w["tags"].get("name") in ("Sasso Caveoso", "Sasso Barisano")
                  and w["tags"].get("place") == "neighbourhood"]
assert len(NEIGHBOURHOODS) == 2, "aree OSM Sasso Caveoso / Sasso Barisano non trovate"

SASSI_ROADS = {"Via d'Addozio", "Via Fiorentini", "Via Sant'Antonio Abate", "Via Madonna delle Virtù", "Via Bruno Buozzi",
               "Recinto primo D'Addozio", "Recinto secondo d'Addozio", "Slargo Via Madonna delle Virtù"}
CENTRO_STREETS = {"Via Rocco Scotellaro", "Via del Corso", "Via delle Beccherie", "Via Duomo", "Piazza Duomo", "Piazza del Duomo",
                  "Piazza del Sedile", "Arco del Sedile", "Piazza San Francesco", "Via San Francesco", "Piazzetta Eleonora Bracco",
                  "Piazzetta Sant'Eligio", "Gradoni Duomo"}   # i Gradoni Duomo uniscono piazza del Sedile alla Civita
SAN_BIAGIO_STREETS = {"Via Tommaso Stigliani", "Via Stigliani", "Via San Biagio", "Piazza San Biagio", "Piazzetta San Biagio"}
NOT_SASSI = {"Via Casalnuovo", "Via Santo Stefano", "Vico I. Casalnuovo", "Vico II Casalnuovo", "Vico III Casalnuovo",
             "Recinto del Sedile", "Via Domenico Ridola", "Calata Domenico Ridola"} | CENTRO_STREETS


def area_of(lines, close_m):
    rel = {"id": 0, "members": [{"type": "way", "role": "section", "geometry": w["geometry"]} for w in lines]}
    return osm_geo.perimeter(osm_geo.street_area(rel, cell_m=5, close_m=close_m), tol_m=4)


def official(name):
    f = RAW / f"ztl_{name}.geojson"
    if not f.exists():
        return None
    g = json.loads(f.read_text())
    g = g["features"][0]["geometry"] if "features" in g else g
    polys = [g["coordinates"]] if g["type"] == "Polygon" else g["coordinates"]
    return osm_geo.perimeter(max((p[0] for p in polys), key=osm_geo.area_km2), tol_m=4)


def sassi():
    lines = []
    for w in WAYS:
        n, mid = w["tags"].get("name", ""), w["geometry"][len(w["geometry"]) // 2]
        if w["tags"].get("highway") in HW and n not in NOT_SASSI and \
                (n in SASSI_ROADS or any(osm_geo.inside_lonlat(r, mid["lon"], mid["lat"]) for r in NEIGHBOURHOODS)):
            lines.append(w)
    return area_of(lines, 40)


def named(streets, close_m=40):
    return area_of([w for w in WAYS if w["tags"].get("name") in streets and w["tags"].get("highway")], close_m)


SHAPES = {"sassi": official("sassi") or sassi(), "centro": official("centro") or named(CENTRO_STREETS, 60),
          "san-biagio": official("san-biagio") or named(SAN_BIAGIO_STREETS, 60)}
FROM_OSM = not any((RAW / f"ztl_{k}.geojson").exists() for k in SHAPES)

# Controlli (coordinate dagli stessi dati OSM): dentro e fuori
CHECKS = {"sassi": [("San Pietro Barisano", 40.66872, 16.60924, True), ("Casa Grotta nei Sassi", 40.66386, 16.61232, True),
                    ("Piazza Vittorio Veneto (Palombaro Lungo)", 40.66690, 16.60650, False), ("Stazione Matera Centrale", 40.66627, 16.60122, False)],
          "centro": [("Piazza del Sedile", 40.66564, 16.60975, True), ("Piazza Duomo", 40.66667, 16.61093, True), ("Piazza Vittorio Veneto", 40.66690, 16.60650, False),
                     ("Stazione Matera Centrale", 40.66627, 16.60122, False)],
          "san-biagio": [("Via San Biagio", 40.66818, 16.60856, True), ("Stazione Matera Centrale", 40.66627, 16.60122, False), ("Piazza del Sedile", 40.66564, 16.60975, False)]}
AREA = {"sassi": (0.15, 0.4), "centro": (0.005, 0.1), "san-biagio": (0.001, 0.05)}
for k, shape in SHAPES.items():
    for name, lat, lon, inside in CHECKS[k]:
        if osm_geo.contains(shape, lat, lon) != inside:
            raise SystemExit(f"{k}: controllo fallito, {name} dovrebbe essere {'dentro' if inside else 'fuori'}")
    a = osm_geo.area_km2(shape)
    if not AREA[k][0] < a < AREA[k][1]:
        raise SystemExit(f"{k}: area non plausibile {a:.3f} km²")

# Varchi: nodi OSM con nome «ZTL …» (man_made=surveillance) della zona, a meno di 60 m dal bordo
CAMS = [e for e in GEO if e["type"] == "node" and re.search(r"ZTL|Traffico Limitato", e.get("tags", {}).get("name", ""))]


GATE_NAMES = {"sassi": r"Sassi|Addozio|Buozzi|Virt", "centro": r"Centro", "san-biagio": r"Biagio|Stigliani"}


def gates(k):
    out = []
    for c in CAMS:
        if not re.search(GATE_NAMES[k], c["tags"]["name"], re.I):
            continue
        if osm_geo.distance_m(SHAPES[k], c["lat"], c["lon"]) < 60 or osm_geo.contains(SHAPES[k], c["lat"], c["lon"]):
            nm = c["tags"]["name"].replace('Zona Traffico Limitato ', 'ZTL ').replace('"', '')
            out.append(osm_geo.gate_json("mt", (c["id"], "Varco · " + nm, c["lat"], c["lon"])))
    return sorted(out, key=lambda g: g["name"])


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


LINKS = [link("City of Matera: ordinance 147/2025, Sassi ZTL hours (PDF)", "Comune di Matera: ordinanza 147/2025, orari ZTL Sassi (PDF)",
              "Stadt Matera: Verordnung 147/2025, Zeiten der ZTL Sassi (PDF)", ORD_147),
         link("City of Matera: camera hours of every ZTL (PDF, 2025)", "Comune di Matera: orari delle telecamere di tutte le ZTL (PDF, 2025)",
              "Stadt Matera: Kamerazeiten aller ZTL (PDF, 2025)", HOURS_2025),
         link("City of Matera: camera hours from 9 Sep 2024 (PDF)", "Comune di Matera: orari telecamere dal 09/09/2024 (PDF)",
              "Stadt Matera: Kamerazeiten ab 9.9.2024 (PDF)", HOURS_2024),
         link("City of Matera: ZTL and pedestrian areas", "Comune di Matera: ZTL/APU", "Stadt Matera: ZTL und Fußgängerzonen", ZTL_PAGE),
         link("City of Matera: how hotels register guests' plates (PDF)", "Comune di Matera: procedura per le strutture ricettive (PDF)",
              "Stadt Matera: so melden Hotels die Kennzeichen (PDF)", HOTELS),
         link("City of Matera: ZTL map, open data (2014)", "Comune di Matera: ZTL e APU, open data (2014)", "Stadt Matera: ZTL-Karte, offene Daten (2014)", OPEN_DATA),
         link("Matera Welcome (city tourist site): ZTL", "Matera Welcome: ZTL", "Matera Welcome (Tourismusseite der Stadt): ZTL", WELCOME)]
if FROM_OSM:
    LINKS.append(link("OpenStreetMap: streets and neighbourhoods of Matera (ODbL)", "OpenStreetMap: strade e rioni di Matera (ODbL)",
                      "OpenStreetMap: Straßen und Viertel von Matera (ODbL)", "https://www.openstreetmap.org/#map=17/40.6660/16.6100"))

COMMON = [
    ("Draft: the City's websites could not be read from here (connection refused). The 2024–2026 hours come from web-search summaries of the City's ordinances, not from their text: to be checked word for word.",
     "Bozza: i siti del Comune non erano leggibili da qui (connessione rifiutata). Gli orari 2024–2026 vengono dai riassunti della ricerca web sulle ordinanze del Comune, non dal loro testo: da verificare parola per parola.",
     "Entwurf: Die Websites der Stadt waren von hier aus nicht lesbar (Verbindung abgelehnt). Die Zeiten 2024–2026 stammen aus Zusammenfassungen der Websuche zu den Verordnungen der Stadt, nicht aus deren Text: Wort für Wort zu prüfen."),
    ("Map outline built from the OpenStreetMap streets named in the City's list (2014), not from an official map: approximate. The City's 2014 open-data map could not be downloaded from here.",
     "Perimetro ricavato dalle strade OpenStreetMap dell'elenco del Comune (2014), non da una mappa ufficiale: approssimativo. La mappa open data del Comune (2014) non era scaricabile da qui.",
     "Grenze aus den OpenStreetMap-Straßen der städtischen Liste (2014) abgeleitet, nicht aus einer offiziellen Karte: ungefähr. Die offene Karte der Stadt (2014) konnte von hier nicht geladen werden."),
    ("Hotels: the hotel or B&B registers your plate on the City's portal (matera.sismic.it), only for the zones where guests may drive in to unload luggage; deadline not found. Electric cars: exempt in the 2014 ordinance, not confirmed today, so GateLR does not exempt them. Motorbikes: allowed to pass but not to park (2014), not confirmed. Blue Badge: call 800 091 980 before or e-mail ztl@comune.mt.it within 48 hours (only from OpenStreetMap notes).",
     "Alberghi: l'hotel o il B&B registra la targa sul portale del Comune (matera.sismic.it), solo per le zone dove gli ospiti possono entrare a scaricare i bagagli; scadenza non trovata. Auto elettriche: esenti nell'ordinanza del 2014, non confermato oggi, quindi GateLR non le esenta. Moto: solo transito, senza sosta (2014), non confermato. Contrassegno disabili: chiamare l'800 091 980 prima o scrivere a ztl@comune.mt.it entro 48 ore (solo da note di OpenStreetMap).",
     "Hotels: Hotel oder B&B melden dein Kennzeichen im Portal der Stadt (matera.sismic.it), nur für die Zonen, in die Gäste zum Ausladen fahren dürfen; Frist nicht gefunden. Elektroautos: in der Verordnung von 2014 befreit, heute nicht bestätigt, daher befreit GateLR sie nicht. Motorräder: nur Durchfahrt, kein Parken (2014), nicht bestätigt. Behindertenausweis: vorher 800 091 980 anrufen oder binnen 48 Stunden an ztl@comune.mt.it schreiben (nur aus OpenStreetMap-Notizen)."),
]
SASSI_PENDING = [
    ("Hours: 10 am–8:30 pm from 16 September to 30 June and 10 am–midnight from 1 July to 15 September, every day (ordinance 147/2025). No 2026 change found; a lunchtime opening 1–3:30 pm ran only from 19 January to 15 March 2026. Unofficial sites give other hours.",
     "Orari: 10–20:30 dal 16 settembre al 30 giugno e 10–24 dal 1° luglio al 15 settembre, tutti i giorni (ordinanza 147/2025). Nessuna modifica 2026 trovata; l'apertura 13–15:30 a pranzo è valsa solo dal 19 gennaio al 15 marzo 2026. Siti non ufficiali danno altri orari.",
     "Zeiten: 10–20:30 Uhr vom 16. September bis 30. Juni und 10–24 Uhr vom 1. Juli bis 15. September, täglich (Verordnung 147/2025). Keine Änderung 2026 gefunden; eine Mittagsöffnung 13–15:30 Uhr galt nur vom 19. Januar bis 15. März 2026. Inoffizielle Seiten nennen andere Zeiten."),
]
CENTRO_PENDING = [
    ("Closed 24 hours a day, every day (City camera timetable from 9 September 2024). Not shown: ZTL Prefettura (via Roma, via XX Settembre) and ZTL Ridola (via Ridola, vico Duni), closed in the evening from 8:30 pm to midnight, and the pedestrian areas (piazza Vittorio Veneto, via del Corso, via Ridola): GateLR does not draw them.",
     "Chiusa 24 ore su 24, tutti i giorni (tabella orari delle telecamere del Comune dal 09/09/2024). Non mostrate: ZTL Prefettura (via Roma, via XX Settembre) e ZTL Ridola (via Ridola, vico Duni), chiuse la sera dalle 20:30 alle 24, e le aree pedonali (piazza Vittorio Veneto, via del Corso, via Ridola): GateLR non le disegna.",
     "Rund um die Uhr, täglich gesperrt (Kamerazeiten der Stadt ab 9.9.2024). Nicht gezeigt: ZTL Prefettura (Via Roma, Via XX Settembre) und ZTL Ridola (Via Ridola, Vico Duni), abends 20:30–24 Uhr gesperrt, und die Fußgängerzonen (Piazza Vittorio Veneto, Via del Corso, Via Ridola): GateLR zeichnet sie nicht."),
]


def zone(zid, names, summary, windows, pending):
    return {"id": zid, "name": names[0], "name_it": names[1], "name_de": names[2], "kind": "restricted",
            "summary": summary[0], "summary_it": summary[1], "summary_de": summary[2],
            "perimeter": SHAPES[zid.removeprefix("matera-")], "gates": gates(zid.removeprefix("matera-")),
            "windows": windows, "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": True,
            "source": {"authority": "City of Matera", "pageURL": ZTL_PAGE,
                       "ordinance": "Ordinanza dirigenziale n. 147/2025 (ZTL Rioni Sassi); O.D. n. 261/2024 e tabella orari telecamere dal 09/09/2024",
                       "ordinanceURL": ORD_147 if zid == "matera-sassi" else HOURS_2024,
                       "quote": None, "quoteTranslation": None, "quoteTranslation_de": None,
                       "checkedOn": CHECKED, "reviewedByHuman": False,
                       "pending": [p[0] for p in pending + COMMON], "pending_it": [p[1] for p in pending + COMMON],
                       "pending_de": [p[2] for p in pending + COMMON], "links": LINKS}}


H24 = [{"weekdays": EVERY_DAY, "start": 0, "end": 24 * 60}]
zones = [
    zone("matera-sassi", ("Sassi · Sasso Barisano and Sasso Caveoso", "Sassi · Sasso Barisano e Sasso Caveoso", "Sassi · Sasso Barisano und Sasso Caveoso"),
         ("The road through the Sassi (via D'Addozio, via Madonna delle Virtù, via Buozzi) is closed to cars without a permit every day from 10 am: until 8:30 pm from mid-September to June, until midnight from July to mid-September. Early morning and late evening it is open. Staying in the Sassi? The hotel or B&B registers your plate. Otherwise park above (piazza della Visitazione, via Saragat) and walk down.",
          "La strada dei Sassi (via D'Addozio, via Madonna delle Virtù, via Buozzi) è chiusa alle auto senza permesso tutti i giorni dalle 10: fino alle 20:30 da metà settembre a giugno, fino a mezzanotte da luglio a metà settembre. Al mattino presto e a tarda sera è aperta. Dormi nei Sassi? L'hotel o il B&B registra la targa. Altrimenti parcheggia sopra (piazza della Visitazione, via Saragat) e scendi a piedi.",
          "Die Straße durch die Sassi (Via D'Addozio, Via Madonna delle Virtù, Via Buozzi) ist für Autos ohne Genehmigung täglich ab 10 Uhr gesperrt: bis 20:30 Uhr von Mitte September bis Juni, bis Mitternacht von Juli bis Mitte September. Frühmorgens und spätabends ist sie offen. Du übernachtest in den Sassi? Hotel oder B&B melden dein Kennzeichen. Sonst oben parken (Piazza della Visitazione, Via Saragat) und zu Fuß hinunter."),
         [{"weekdays": EVERY_DAY, "start": 10 * 60, "end": 20 * 60 + 30, "season": WINTER},
          {"weekdays": EVERY_DAY, "start": 10 * 60, "end": 24 * 60, "season": SUMMER}], SASSI_PENDING),
    zone("matera-centro", ("Centro & Civita · Duomo, Sedile, via del Corso", "Centro e Civita · Duomo, Sedile, via del Corso", "Zentrum & Civita · Dom, Sedile, Via del Corso"),
         ("The streets around piazza del Sedile, via del Corso, piazza San Francesco and up to the Cathedral (Civita) are closed to cars without a permit 24 hours a day, every day. Deliveries only 7–10:30 am and 3–5 pm. Park outside and walk.",
          "Le strade attorno a piazza del Sedile, via del Corso, piazza San Francesco e fino al Duomo (Civita) sono chiuse alle auto senza permesso 24 ore su 24, tutti i giorni. Carico e scarico solo 7–10:30 e 15–17. Parcheggia fuori e cammina.",
          "Die Straßen um Piazza del Sedile, Via del Corso, Piazza San Francesco bis hinauf zum Dom (Civita) sind für Autos ohne Genehmigung rund um die Uhr, täglich gesperrt. Lieferungen nur 7–10:30 und 15–17 Uhr. Draußen parken und laufen."),
         H24, CENTRO_PENDING),
    zone("matera-san-biagio", ("San Biagio · via San Biagio and via Stigliani", "San Biagio · via San Biagio e via Stigliani", "San Biagio · Via San Biagio und Via Stigliani"),
         ("Via San Biagio and via Tommaso Stigliani (San Giovanni/San Biagio ZTL) are closed to cars without a permit 24 hours a day, every day.",
          "Via San Biagio e via Tommaso Stigliani (ZTL San Giovanni/San Biagio) sono chiuse alle auto senza permesso 24 ore su 24, tutti i giorni.",
          "Via San Biagio und Via Tommaso Stigliani (ZTL San Giovanni/San Biagio) sind für Autos ohne Genehmigung rund um die Uhr, täglich gesperrt."),
         H24, CENTRO_PENDING),
]

city = {"id": "matera", "name": "Matera", "name_it": "Matera", "name_de": "Matera",
        "center": {"lat": 40.6660, "lon": 16.6090}, "zones": zones, "status": "draft",
        "license": "Rules: Comune di Matera ordinances (read through web-search summaries). "
                   + ("Perimeters and gates: " + osm_geo.ODBL + " (built from the streets in the City's list, approximate)." if FROM_OSM else "Perimeters: Comune di Matera open data.")}

# Pubblicabile solo con una citazione verificata sul testo ufficiale; altrimenti bozza
ready = all(len(z["perimeter"]) >= 5 and z["source"]["quote"] for z in city["zones"])
out = ROOT / ("Resources/Cities/matera.json" if ready else "data/drafts/matera.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/matera.json" if ready else "Resources/Cities/matera.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), [(z["id"], len(z["perimeter"]), len(z["gates"]), round(osm_geo.area_km2(z["perimeter"]), 3)) for z in zones])
