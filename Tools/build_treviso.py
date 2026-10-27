#!/usr/bin/env python3
# Costruisce Resources/Cities/treviso.json dalle fonti ufficiali del Comune di Treviso salvate in data/raw/treviso/
# (fonti e date in docs/fonti-treviso.md). Ogni frase citata o riassunta viene ricontrollata sul testo salvato.
#
# Regole: portale ufficiale «ZTL nel Centro di Treviso» (www.ztltreviso.it, pagina «La ZTL ed i varchi»: 8 varchi, sei
#   «attivo H24», Ponte San Francesco 22–6 dal lunedì al venerdì e tutto il giorno sabato, domenica e festivi, via Manin
#   22–6 tutti i giorni) e disciplinari della Polizia Locale: 2014 (allegato A alla DGC: regime «tutti i giorni della
#   settimana e permanentemente, dalle ore 00:00 alle 24:00»), vers. 4 del 21/02/2017 e «Nuovo disciplinare ZTL novembre
#   2017» (quello linkato dal portale: clienti di alberghi e strutture ricettive in ZTL per la durata del soggiorno,
#   comunicazione anche entro cinque giorni dal primo transito).
# Geometria: la mappa ufficiale del portale (data/raw/treviso/mappa-ztl-varchi.png: area blu con i varchi H24 e striscia
#   verde di via Manin 22–6) non è georeferenziata; l'area viene da OpenStreetMap (© OpenStreetMap contributors, ODbL 1.0;
#   API OSM con Tools/fetch_osm_api.py, ridotto in data/raw/geo/treviso-ztl.json): relazione 19430980
#   (boundary=limited_traffic_zone), che coincide con l'unione blu+verde della mappa ufficiale (controlli qui sotto).
#   La striscia di via Manin (orari diversi) è la parte della relazione entro 35 m dall'asse di via Daniele Manin (OSM);
#   il resto è la zona H24. Varchi: le telecamere OSM dove ci sono (Cornarotta, Ponte San Francesco, San Leonardo,
#   via Manin), altrimenti il punto della strada del varco più vicino al bordo della zona.
# Uso: python3 Tools/build_treviso.py   (non tocca le altre città né manifest.json)
import json, math, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/treviso"
CHECKED = "2026-10-27T16:30:00Z"
ALL = [1, 2, 3, 4, 5, 6, 7]

PORTAL = "https://www.ztltreviso.it/myportal/C_L407_ZTL"
GATES_PAGE = PORTAL + "/varchi"
DISC = PORTAL + "/api/content/download?id=6377665b8dee9000a28f07f2"
PASS_PORTAL = "https://portaleztl.comune.treviso.it/cittadino/"
OCCASIONAL = PORTAL + "/occasionale"


def flat(s):
    return re.sub(r"\s+", " ", s).strip()


TEXT = {p.stem: flat(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def check(file, *phrases):
    for q in phrases:
        if flat(q) not in TEXT[file]:
            raise SystemExit(f"{file}: frase non trovata, ricontrollare il documento: {q!r}")


Q_MAIN = ("Gli accessi sono 8 controllati da sistemi elettronici in grado di rilevare i numeri delle targhe dei veicoli in transito. "
          "Dove si trovano 1) Via XX Settembre - attivo H24 2) Via Martiri della Libertà - attivo H24 3) Via San Leonardo - attivo H24")
Q_SANFR = ("4) Ponte San Francesco - Orari di attività dalle 22:00 alle 06:00 nei giorni dal lunedì al venerdì dalle 00:00 alle 24:00 "
           "nei giorni di sabato, domenica e nelle festività del 1 gennaio, 6 gennaio, Lunedì di Pasquetta, 25 aprile, 1 maggio, "
           "2 giugno, 15 agosto, 1 novembre, 8 dicembre, 25 dicembre, 26 dicembre")
Q_MANIN = "8) Via Manin - Orari di attività dalle 22:00 alle 6:00 tutti i giorni"
check("ztltreviso-varchi", Q_MAIN, Q_SANFR, Q_MANIN, "5) Vicolo Buranelli - attivo H24", "6) Via Cornarotta - attivo H24",
      "7) Calmaggiore - attivo H24",
      "Possono circolare in ZTL senza alcuna limitazione le biciclette e i veicoli ibridi/elettrici, ma per questi ultimi è obbligatoria la comunicazione del numero di targa per l’inserimento negli elenchi della Polizia Locale.",
      "Taxi e NCC in servizio")
check("disciplinare-ztl-2014", "Il prescritto regime di circolazione nelle ZTL resta in vigore tutti i giorni della settimana e permanentemente, dalle ore 00:00 alle 24:00.")
check("disciplinare-ztl-novembre-2017", "Nuovo Disciplinare ZTL _novembre 2017_",
      "Per circolare nella ZTL, è necessario avere un pass o contrassegno ottenibile mediante una specifica dichiarazione da inoltrare alla Polizia Locale di Treviso.",
      "Tale comunicazione deve pervenire alla Polizia Locale di Treviso entro cinque giorni dal primo transito.",
      "c) ospiti di strutture ricettive e alberghiere in ZTL;",
      "Veicoli a trazione esclusivamente elettrica",
      "Il portale è disponibile 24 ore su 24.")
check("disciplinare-ztl-v4-2017", "Clienti di alberghi e strutture ricettive in ZTL", "soggiorno")

# --- geometria ---
GEO = osm_geo.load("treviso-ztl")
ways = {e["id"]: e for e in GEO if e["type"] == "way"}
nodes = {e["id"]: e for e in GEO if e["type"] == "node"}
union = osm_geo.outer_ring(osm_geo.relation(GEO, 19430980))   # [(lon, lat)]
MANIN = [(p["lon"], p["lat"]) for w in (107739894, 1168227718) for p in ways[w]["geometry"]]
for w in (107739894, 1168227718):
    if ways[w]["tags"].get("name") != "Via Daniele Manin":
        raise SystemExit(f"Way {w} non è più via Daniele Manin")

LAT0 = 45.666
K = math.cos(math.radians(LAT0))
fwd = lambda lon, lat: (lon * K * 111320.0, lat * 110574.0)
back = lambda x, y: (x / (111320.0 * K), y / 110574.0)


def seg_dist(p, a, b):
    (px, py), (ax, ay), (bx, by) = p, a, b
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy or 1)))
    return math.hypot(px - ax - t * dx, py - ay - t * dy)


MANIN_XY = [fwd(*p) for p in MANIN]
manin_segs = [(MANIN_XY[i], MANIN_XY[i + 1]) for i in range(len(MANIN_XY) - 1)]
CELL, STRIP = 5.0, 35.0
xs, ys = zip(*[fwd(*p) for p in union])
blue_cells, green_cells = set(), set()
for i in range(int(min(xs) // CELL) - 1, int(max(xs) // CELL) + 2):
    for j in range(int(min(ys) // CELL) - 1, int(max(ys) // CELL) + 2):
        cx, cy = (i + 0.5) * CELL, (j + 0.5) * CELL
        lon, lat = back(cx, cy)
        if not osm_geo.inside_lonlat(union, lon, lat):
            continue
        near = min(seg_dist((cx, cy), a, b) for a, b in manin_segs) < STRIP
        (green_cells if near else blue_cells).add((i, j))


def largest(cells):
    seen, best = set(), set()
    for c in cells:
        if c in seen:
            continue
        comp, todo = {c}, [c]
        seen.add(c)
        while todo:
            x, y = todo.pop()
            for d in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if d in cells and d not in seen:
                    seen.add(d); comp.add(d); todo.append(d)
        if len(comp) > len(best):
            best = comp
    return best


def trace(cells):
    """Contorno esterno di un insieme di celle (come osm_geo.street_area) → [(lon, lat)]"""
    best = osm_geo._fill_holes(largest(cells))
    nxt = {}
    for x, y in best:
        if (x, y - 1) not in best: nxt.setdefault((x, y), []).append((x + 1, y))
        if (x + 1, y) not in best: nxt.setdefault((x + 1, y), []).append((x + 1, y + 1))
        if (x, y + 1) not in best: nxt.setdefault((x + 1, y + 1), []).append((x, y + 1))
        if (x - 1, y) not in best: nxt.setdefault((x, y + 1), []).append((x, y))
    loops = []
    while nxt:
        start = next(iter(nxt))
        loop, cur = [start], start
        while True:
            cur = nxt[cur].pop()
            if not nxt[loop[-1]]:
                del nxt[loop[-1]]
            if cur == start:
                break
            loop.append(cur)
        loops.append(loop + [start])
    outer = max(loops, key=lambda l: abs(osm_geo._signed_area(l)))
    return [back(x * CELL, y * CELL) for x, y in outer]


blue = osm_geo.perimeter(trace(blue_cells), tol_m=4)
green = osm_geo.perimeter(trace(green_cells), tol_m=4)
a_blue, a_green = osm_geo.area_km2([(p["lon"], p["lat"]) for p in blue]), osm_geo.area_km2([(p["lon"], p["lat"]) for p in green])
if not (0.10 < a_blue < 0.20 and 0.01 < a_green < 0.04):
    raise SystemExit(f"Aree non plausibili: {a_blue:.3f} {a_green:.3f} km²")


def street_gate(name, way_ids, shape):
    """Il punto della strada del varco più vicino al bordo della zona"""
    pts = [(p["lat"], p["lon"]) for w in way_ids for p in ways[w]["geometry"]]
    for w in way_ids:
        if ways[w]["tags"].get("name") != name:
            raise SystemExit(f"Way {w} non è più {name}")
    lat, lon = min(pts, key=lambda p: osm_geo.distance_m(shape, *p))
    return (way_ids[0], lat, lon)


def cam(node_id):
    n = nodes[node_id]
    if n.get("tags", {}).get("man_made") != "surveillance":
        raise SystemExit(f"Nodo {node_id} non è più una telecamera")
    return n["lat"], n["lon"]


B_GATES = [(f"w{w}", "Varco 1 · Via XX Settembre", la, lo) for w, la, lo in [street_gate("Via Venti Settembre", [w for w, e in ways.items() if e["tags"].get("name") == "Via Venti Settembre"], blue)]] + \
          [(f"w{w}", "Varco 2 · Via Martiri della Libertà", la, lo) for w, la, lo in [street_gate("Via Martiri della Libertà", [51980502, 1222312969, 585625945, 51980503], blue)]] + \
          [(8180786497, "Varco 3 · Via San Leonardo", *cam(8180786497)),
           (8176957946, "Varco 4 · Ponte San Francesco (22–6 Mon–Fri; all day Sat, Sun, holidays)", *cam(8176957946))] + \
          [(f"w{w}", "Varco 5 · Vicolo Buranelli", la, lo) for w, la, lo in [street_gate("Vicolo Buranelli", [457233030, 107737565, 980258218], blue)]] + \
          [(8176957944, "Varco 6 · Via Cornarotta", *cam(8176957944))] + \
          [(f"w{w}", "Varco 7 · Calmaggiore", la, lo) for w, la, lo in [street_gate("Via Calmaggiore", [25554725, 1168227721, 252962298], blue)]]
G_GATES = [(8180571113, "Varco 8 · Via Manin (22–6)", *cam(8180571113))]
for shape, gl in ((blue, B_GATES), (green, G_GATES)):
    for g in gl:
        if osm_geo.distance_m(shape, g[2], g[3]) > 40 and not osm_geo.contains(shape, g[2], g[3]):
            raise SystemExit(f"Varco lontano dalla zona: {g[1]}")


def gate_json(g):
    gid = f"osm{g[0]}" if isinstance(g[0], int) else f"osm-way{g[0][1:]}"
    return {"id": f"tv-{gid}", "name": g[1], "location": {"lat": round(g[2], 6), "lon": round(g[3], 6)}}


# Controlli (coordinate dei luoghi da OSM): dentro la zona H24 piazza dei Signori, Loggia dei Cavalieri, piazza Rinaldi,
# Calmaggiore, Isola della Pescheria; via Manin nella striscia verde; stazione, Corso del Popolo, piazza Filodrammatici,
# via San Parisio e piazza Vittoria fuori da entrambe
for name, lat, lon, shape, inside in [("Piazza dei Signori", 45.66561, 12.24559, blue, True), ("Loggia dei Cavalieri", 45.66545, 12.24696, blue, True),
                                      ("Piazza Rinaldi", 45.66778, 12.2465, blue, True), ("Via Calmaggiore", 45.66623, 12.2444, blue, True),
                                      ("Isola della Pescheria", 45.66667, 12.24829, blue, True), ("Via Manin", 45.6650, 12.2435, green, True),
                                      ("Via Manin", 45.6650, 12.2435, blue, False), ("Piazza dei Signori", 45.66561, 12.24559, green, False)] + \
        [(n, la, lo, s, False) for n, la, lo in [("Stazione FS", 45.6597, 12.2427), ("Corso del Popolo", 45.6630, 12.2447),
                                                  ("Piazza Filodrammatici", 45.66497, 12.24759), ("Via San Parisio", 45.6672, 12.2481),
                                                  ("Piazza della Vittoria", 45.6635, 12.2425)] for s in (blue, green)]:
    if osm_geo.contains(shape, lat, lon) != inside:
        raise SystemExit(f"Controllo perimetro fallito: {name} dovrebbe essere {'dentro' if inside else 'fuori'}")


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


LINKS = [link("City of Treviso: the ZTL and its gates (official portal)", "Comune di Treviso: la ZTL e i varchi (portale ufficiale)", "Stadt Treviso: die ZTL und ihre Kameras (offizielles Portal)", GATES_PAGE),
         link("City of Treviso: ZTL regulations (November 2017, PDF)", "Comune di Treviso: disciplinare ZTL (novembre 2017, PDF)", "Stadt Treviso: ZTL-Regelung (November 2017, PDF)", DISC),
         link("City of Treviso: occasional access", "Comune di Treviso: accesso occasionale", "Stadt Treviso: gelegentliche Zufahrt", OCCASIONAL),
         link("City of Treviso: ZTL pass portal", "Comune di Treviso: portale dei pass ZTL", "Stadt Treviso: ZTL-Pass-Portal", PASS_PORTAL),
         link("OpenStreetMap: ZTL area (ODbL)", "OpenStreetMap: area ZTL (ODbL)", "OpenStreetMap: ZTL-Fläche (ODbL)", osm_geo.osm_url("relation", 19430980))]

P_COMMON = [
    ("Hotels: guests of hotels and other accommodation inside the ZTL may drive in for the length of their stay (stop at most 20 minutes); the hotel or you must report the plate to the Municipal Police, also afterwards, within five days of the first entry. Everyone else needs a pass or an occasional-access notice before driving in (online portal, 24 hours a day).",
     "Hotel: gli ospiti di alberghi e altre strutture ricettive in ZTL possono entrare per la durata del soggiorno (sosta al massimo 20 minuti); la targa va comunicata alla Polizia Locale, anche dopo, entro cinque giorni dal primo transito. Tutti gli altri devono avere un pass o comunicare l'accesso occasionale prima di entrare (portale online, 24 ore su 24).",
     "Hotels: Gäste von Hotels und anderen Unterkünften in der ZTL dürfen für die Dauer des Aufenthalts einfahren (höchstens 20 Minuten halten); das Kennzeichen muss der Stadtpolizei gemeldet werden, auch nachträglich, binnen fünf Tagen nach der ersten Einfahrt. Alle anderen brauchen vor der Einfahrt einen Pass oder eine Meldung der gelegentlichen Zufahrt (Online-Portal, rund um die Uhr)."),
    ("Electric cars may drive in but their plate must be registered with the Municipal Police first. The official ZTL page says the same for hybrids; the 2017 regulations name only fully electric vehicles, so hybrids are not marked as exempt here. Blue Badge holders may drive in and report the plate within five days. Bicycles always allowed. Fine amount not published on the official pages.",
     "Le auto elettriche entrano ma la targa va prima comunicata alla Polizia Locale. La pagina ufficiale della ZTL dice lo stesso per le ibride; il disciplinare 2017 nomina solo i veicoli a trazione esclusivamente elettrica, quindi qui le ibride non sono segnate come esenti. I titolari di contrassegno disabili entrano e comunicano la targa entro cinque giorni. Biciclette sempre ammesse. Importo della multa non pubblicato nelle pagine ufficiali.",
     "Elektroautos dürfen einfahren, das Kennzeichen muss aber vorher bei der Stadtpolizei registriert sein. Die offizielle ZTL-Seite sagt dasselbe für Hybride; die Regelung von 2017 nennt nur reine Elektrofahrzeuge, daher sind Hybride hier nicht als befreit markiert. Inhaber eines Behindertenausweises dürfen einfahren und melden das Kennzeichen binnen fünf Tagen. Fahrräder immer erlaubt. Bußgeldhöhe auf den offiziellen Seiten nicht veröffentlicht."),
    ("Area from OpenStreetMap (relation 19430980), checked against the official map on the City's ZTL portal (the official map is an image, not open data). The Via Manin strip is drawn as the part within 35 m of the street.",
     "Area da OpenStreetMap (relazione 19430980), confrontata con la mappa ufficiale del portale ZTL del Comune (la mappa ufficiale è un'immagine, non open data). La striscia di via Manin è la parte entro 35 m dalla strada.",
     "Fläche aus OpenStreetMap (Relation 19430980), abgeglichen mit der offiziellen Karte im ZTL-Portal der Stadt (die offizielle Karte ist ein Bild, keine offenen Daten). Der Streifen der Via Manin ist der Teil bis 35 m von der Straße."),
]
P_SANFR = ("The ZTL rules apply 24 hours a day, every day (regulations); the camera at Ponte San Francesco only records 10 pm–6 am Monday to Friday and all day on Saturdays, Sundays and public holidays. Entering there on weekday daytime is still not allowed without a pass.",
           "Le regole della ZTL valgono 24 ore su 24, tutti i giorni (disciplinare); la telecamera di Ponte San Francesco è attiva solo 22–6 dal lunedì al venerdì e tutto il giorno sabato, domenica e festivi. Entrare da lì di giorno nei feriali senza pass resta comunque non consentito.",
           "Die ZTL-Regeln gelten rund um die Uhr, täglich (Regelung); die Kamera an der Ponte San Francesco zeichnet nur Montag–Freitag 22–6 Uhr und samstags, sonntags und feiertags ganztägig auf. Werktags tagsüber ohne Pass einzufahren ist trotzdem nicht erlaubt.")
P_MANIN = ("The 2014 regulations put all ZTL rules 0–24 every day; the official ZTL page gives the Via Manin camera only 10 pm–6 am. The app follows the official ZTL page for this street.",
           "Il disciplinare 2014 mette tutte le regole della ZTL 0–24 tutti i giorni; la pagina ufficiale della ZTL indica per la telecamera di via Manin solo 22–6. Per questa via l'app segue la pagina ufficiale della ZTL.",
           "Die Regelung von 2014 setzt alle ZTL-Regeln täglich 0–24 Uhr; die offizielle ZTL-Seite nennt für die Kamera der Via Manin nur 22–6 Uhr. Für diese Straße folgt die App der offiziellen ZTL-Seite.")


def source(quote, tr, tr_de, extra):
    pend = [extra] + P_COMMON
    return {"authority": "City of Treviso", "pageURL": GATES_PAGE,
            "ordinance": "Disciplinare per la circolazione stradale nella ZTL (Polizia Locale, novembre 2017); disciplinare allegato A alla DGC (2014)",
            "ordinanceURL": DISC, "quote": quote, "quoteTranslation": tr, "quoteTranslation_de": tr_de,
            "checkedOn": CHECKED, "reviewedByHuman": False,
            "pending": [p[0] for p in pend], "pending_it": [p[1] for p in pend], "pending_de": [p[2] for p in pend],
            "links": LINKS}


zones = [
    {"id": "treviso-centro", "name": "Piazza dei Signori · old-town ZTL", "name_it": "Piazza dei Signori · ZTL del centro", "name_de": "Piazza dei Signori · Altstadt-ZTL",
     "kind": "restricted",
     "summary": "The heart of Treviso (Piazza dei Signori, Calmaggiore, Loggia dei Cavalieri, Piazza Rinaldi, the Buranelli canal) is closed to cars and motorbikes without a pass 24 hours a day, every day. Seven cameras: Via XX Settembre, Via Martiri della Libertà, Via San Leonardo, Vicolo Buranelli, Via Cornarotta, Calmaggiore (always on) and Ponte San Francesco (nights on weekdays, all day at weekends and holidays). Staying at a hotel inside? Your plate can be reported within five days. Otherwise park outside and walk.",
     "summary_it": "Il cuore di Treviso (piazza dei Signori, Calmaggiore, Loggia dei Cavalieri, piazza Rinaldi, canale dei Buranelli) è chiuso ad auto e moto senza pass 24 ore su 24, tutti i giorni. Sette telecamere: via XX Settembre, via Martiri della Libertà, via San Leonardo, vicolo Buranelli, via Cornarotta, Calmaggiore (sempre attive) e Ponte San Francesco (di notte nei feriali, tutto il giorno nel fine settimana e nei festivi). Dormi in un hotel dentro? La targa si può comunicare entro cinque giorni. Altrimenti parcheggia fuori e cammina.",
     "summary_de": "Das Herz von Treviso (Piazza dei Signori, Calmaggiore, Loggia dei Cavalieri, Piazza Rinaldi, Buranelli-Kanal) ist für Autos und Motorräder ohne Pass rund um die Uhr gesperrt, jeden Tag. Sieben Kameras: Via XX Settembre, Via Martiri della Libertà, Via San Leonardo, Vicolo Buranelli, Via Cornarotta, Calmaggiore (immer aktiv) und Ponte San Francesco (werktags nachts, am Wochenende und an Feiertagen ganztägig). Du übernachtest in einem Hotel innen? Dein Kennzeichen kann binnen fünf Tagen gemeldet werden. Sonst draußen parken und laufen.",
     "perimeter": blue, "gates": [gate_json(g) for g in B_GATES],
     "windows": [{"weekdays": ALL, "start": 0, "end": 1440}],
     "freeOnHolidays": False, "holidaysAsSunday": False, "exemptFuels": ["electric"], "hotelCanRegister": True,
     "source": source(Q_MAIN,
                      "There are 8 entrances, watched by electronic systems that read the number plates of passing vehicles. Where they are: 1) Via XX Settembre – active 24h; 2) Via Martiri della Libertà – active 24h; 3) Via San Leonardo – active 24h",
                      "Es gibt 8 Zufahrten, überwacht von elektronischen Systemen, die die Kennzeichen der durchfahrenden Fahrzeuge erfassen. Wo sie sind: 1) Via XX Settembre – 24 h aktiv; 2) Via Martiri della Libertà – 24 h aktiv; 3) Via San Leonardo – 24 h aktiv",
                      P_SANFR)},
    {"id": "treviso-manin", "name": "Via Manin · night ZTL", "name_it": "Via Manin · ZTL notturna", "name_de": "Via Manin · Nacht-ZTL",
     "kind": "restricted",
     "summary": "Via Daniele Manin (from Corso del Popolo to Piazza Duomo) is closed to cars and motorbikes without a pass every night from 10 pm to 6 am. During the day you may drive through.",
     "summary_it": "Via Daniele Manin (da Corso del Popolo a piazza Duomo) è chiusa ad auto e moto senza pass ogni notte dalle 22 alle 6. Di giorno si passa.",
     "summary_de": "Die Via Daniele Manin (vom Corso del Popolo bis zur Piazza Duomo) ist für Autos und Motorräder ohne Pass jede Nacht von 22 bis 6 Uhr gesperrt. Tagsüber darfst du durchfahren.",
     "perimeter": green, "gates": [gate_json(g) for g in G_GATES],
     "windows": [{"weekdays": ALL, "start": 22 * 60, "end": 6 * 60}],
     "freeOnHolidays": False, "holidaysAsSunday": False, "exemptFuels": ["electric"], "hotelCanRegister": True,
     "source": source(Q_MANIN, "8) Via Manin – hours of operation from 22:00 to 6:00 every day",
                      "8) Via Manin – Betriebszeiten von 22:00 bis 6:00 Uhr, täglich", P_MANIN)},
]

city = {"id": "treviso", "name": "Treviso", "name_it": "Treviso", "name_de": "Treviso",
        "center": {"lat": 45.6664, "lon": 12.2445}, "zones": zones, "status": "draft",
        "license": "Rules: Comune di Treviso (official ZTL portal and regulations). Areas and gates: " + osm_geo.ODBL + " (approximate, not official)."}

ready = all(len(z["perimeter"]) >= 5 and z["source"]["quote"] for z in city["zones"])
out = ROOT / ("Resources/Cities/treviso.json" if ready else "data/drafts/treviso.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/treviso.json" if ready else "Resources/Cities/treviso.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), [(z["id"], len(z["perimeter"]), len(z["gates"])) for z in city["zones"]], f"{a_blue:.3f} + {a_green:.3f} km²")
