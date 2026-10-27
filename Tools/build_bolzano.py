#!/usr/bin/env python3
# Costruisce la scheda di Bolzano/Bozen da quanto salvato in data/raw/bolzano/ (fonti e date in docs/fonti-bolzano.md).
#
# Regole: pagine ufficiali del Comune lette il 27/10/2026 (guida «Accesso ZTL e sosta nel centro abitato», servizio della
# Polizia Municipale / Stadtpolizei, documento sui varchi, divieti per l'inquinamento) e la delibera di Giunta 518/2022
# (modificata dalla 17/2023) che dal 01/02/2023 elenca le vie e piazze della ZTL e le deroghe. Citazione verificata sulla guida.
#
# Geometria: perimetro dall'ELENCO UFFICIALE DELLE VIE della delibera 518/2022 (punto 1), con le geometrie OpenStreetMap delle
# strade (data/raw/geo/bolzano-ztl.json, scaricato con Tools/fetch_osm_api.py il 27/10/2026, © OpenStreetMap contributors,
# ODbL 1.0); i tratti «compresi tra» due vie sono ritagliati tra i due incroci; l'area è quella coperta dalle strade
# (osm_geo.street_area). Varchi: le telecamere «device» della relazione OSM 19584710 (la mappa ufficiale dei varchi è su
# Google My Maps, non raggiungibile dal sandbox).
# Uso: python3 Tools/build_bolzano.py   (non tocca le altre città né manifest.json)
import json, math, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/bolzano"
CHECKED = "2026-10-27T12:30:00Z"
EVERY_DAY = [1, 2, 3, 4, 5, 6, 7]


def flat(s):
    return re.sub(r"\s+", " ", s).strip()


TEXT = {p.stem: flat(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def check(file, *phrases):
    """Ogni regola deve comparire, parola per parola, nel testo ufficiale salvato"""
    for q in phrases:
        if flat(q) not in TEXT[file]:
            raise SystemExit(f"{file}: frase non trovata: {q!r}")


def url_of(file):
    return TEXT[file].split(" ", 2)[1]


GUIDE_F, SERV_F, DIENST_F, GATES_F = "comune-guida-accesso-ztl", "comune-servizio-permessi-ztl", "gemeinde-dienst-genehmigung-vbz", "comune-varchi-telecamere-ztl"
DEL_F, DEL17_F, AIR_F = "delibera-gc-518-2022-ztl", "delibera-gc-17-2023-ztl", "comune-divieti-inquinamento"
GUIDE, SERV, GATES_PAGE, DELIB, AIR = map(url_of, (GUIDE_F, SERV_F, GATES_F, DEL_F, AIR_F))
DELIB_PAGE = "https://www.comune.bolzano.bz.it/Amministrazione/Documenti-e-dati/Documenti-tecnici-di-supporto/Delibere-della-Giunta-Comunale-n.-518-2022-e-n.-17-2023"
QUOTE = "La ZTL del centro storico di Bolzano è attiva 24 ore su 24, tutti i giorni"
check(GUIDE_F, QUOTE, "L'accesso è controllato da telecamere ai varchi",
      "Se il vostro albergo si trova nella ZTL, contattatelo in anticipo per comunicare la vostra targa e ottenere l'autorizzazione temporanea al passaggio.",
      "Divieto: L'accesso con veicoli privati è vietato",
      "Veicoli fino a 3,5 tonnellate possono accedere alla ZTL per carico e scarico dal lunedì al sabato dalle 6:00 alle 10:30 (esclusi i festivi infrasettimanali).",
      "Euro 0, Euro 1, Euro 2 Diesel ed Euro 3 Diesel , dal lunedì al venerdì (esclusi i festivi), dalle 7:00 alle 10:00 e dalle 16:00 alle 19:00")
check(DEL_F, "a far data dal 01.02.2023 la Zona a Traffico Limitato del centro di Bolzano",
      "agli ospiti autorizzati degli esercizi ricettivi", "è consentito accedere e sostare per il tempo strettamente necessario alle sole operazioni di carico e scarico dei bagagli",
      "via Alto Adige nel tratto compreso tra", "via Laurin nel tratto compreso tra via Sciliar e via Grappoli",
      "via Leonardo da Vinci nel tratto compreso tra via Goethe e via Cassa di Risparmio", "Conciapelli, nel tratto compreso tra via Laurin e via Molini",
      "via Museo nel tratto compreso tra piazza Erbe e via Cassa di Risparmio", "via Dr. Streiter, piazza Walther.")
check(DEL17_F, "portandolo a 4,25 tonnellate per i soli veicoli con alimentazione elettrica, ibrida e a idrogeno")
check(SERV_F, "0471 997799")
check(DIENST_F, "Die Genehmigung muss vor der Einfahrt in eine verkehrsberuhigte Zone oder in die Fußgängerzone von der Stadtpolizei ausgestellt werden.",
      "Stempelmarke 16,00 Euro")
check(GATES_F, "Tutti gli accessi ai “varchi” sono controllati.")
check(AIR_F, "Ciclomotori e motoveicoli", "nel centro abitato di Bolzano")


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


LINKS = [link("City of Bolzano: ZTL access and parking guide", "Comune di Bolzano: guida accesso ZTL e sosta nel centro abitato",
              "Stadt Bozen: Leitfaden Zufahrt verkehrsberuhigte Zone und Parken", GUIDE),
         link("City of Bolzano (municipal police): ZTL and pedestrian-zone permits", "Comune di Bolzano (Polizia Municipale): permessi varchi elettronici ZTL e aree pedonali",
              "Stadt Bozen (Stadtpolizei): Genehmigung für die Einfahrt in die VBZ und die Fußgängerzone", SERV),
         link("Council resolutions 518/2022 and 17/2023: ZTL streets and rules from 1 February 2023", "Delibere di Giunta 518/2022 e 17/2023: vie e regole della ZTL dal 1° febbraio 2023",
              "Beschlüsse des Gemeindeausschusses 518/2022 und 17/2023: Straßen und Regeln der VBZ ab 1. Februar 2023", DELIB_PAGE),
         link("City of Bolzano: ZTL entry cameras (with link to the official gate map)", "Comune di Bolzano: i varchi con le telecamere della ZTL (con la mappa ufficiale dei varchi)",
              "Stadt Bozen: die Zufahrtskameras der VBZ (mit Link zur offiziellen Karte)", GATES_PAGE),
         link("City of Bolzano: weekday bans on older Euro classes (whole built-up area)", "Comune di Bolzano: divieti di circolazione per l'inquinamento dell'aria (tutto il centro abitato)",
              "Stadt Bozen: Fahrverbote für ältere Euro-Klassen an Werktagen (ganzes Ortsgebiet)", AIR),
         link("OpenStreetMap: ZTL relation (cameras on the map)", "OpenStreetMap: relazione della ZTL (telecamere sulla mappa)",
              "OpenStreetMap: ZTL-Relation (Kameras auf der Karte)", osm_geo.osm_url("relation", 19584710))]

PENDING = [
    ("Hotel inside the zone: contact it before arriving and give your plate; it obtains the temporary authorisation. The rules let authorised hotel guests drive in and stop only for the time needed to load and unload luggage; the City's pages give no deadline for the hotel to register the plate, so ask the hotel.",
     "Albergo dentro la zona: contattalo prima di arrivare e comunica la targa; ottiene lui l'autorizzazione temporanea. Le regole consentono agli ospiti autorizzati di entrare e sostare solo per il tempo necessario a caricare e scaricare i bagagli; le pagine del Comune non indicano entro quando l'albergo registra la targa: chiedilo all'albergo.",
     "Hotel in der Zone: vor der Ankunft kontaktieren und das Kennzeichen mitteilen; das Hotel besorgt die vorübergehende Genehmigung. Die Regeln erlauben berechtigten Hotelgästen nur Einfahrt und Halt zum Be- und Entladen des Gepäcks; eine Frist für die Meldung des Kennzeichens nennen die Seiten der Stadt nicht, also beim Hotel nachfragen."),
    ("No day ticket for visitors: park outside (e.g. Mayr-Nusser car park or Piazza Walther underground car park). Other temporary permits only for special reasons, from the municipal police (tel. 0471 997799, revenue stamp 16 €). Electric and hybrid cars are not exempt; the rules name no exemption for motorcycles either.",
     "Nessun biglietto giornaliero per i visitatori: parcheggia fuori (es. parcheggio Mayr Nusser o garage di piazza Walther). Altri permessi temporanei solo per motivi particolari, dalla Polizia Municipale (tel. 0471 997799, marca da bollo 16 €). Auto elettriche e ibride non esenti; le regole non prevedono esenzioni neanche per le moto.",
     "Kein Tagesticket für Besucher: außerhalb parken (z. B. Parkplatz Mayr-Nusser oder Tiefgarage Waltherplatz). Andere befristete Genehmigungen nur aus besonderen Gründen bei der Stadtpolizei (Tel. 0471 997799, Stempelmarke 16 €). Elektro- und Hybridautos sind nicht befreit; auch für Motorräder sehen die Regeln keine Befreiung vor."),
    ("Deliveries up to 3.5 t Monday–Saturday 6:00–10:30 (not on holidays); electric, hybrid and hydrogen vans up to 4.25 t with a permit also 10:30–11:00 and, at some gates, 14:30–16:00. Piazza Walther is a pedestrian area.",
     "Carico e scarico fino a 3,5 t lunedì–sabato 6–10:30 (non nei festivi); furgoni elettrici, ibridi e a idrogeno fino a 4,25 t con permesso anche 10:30–11 e, per alcuni varchi, 14:30–16. Piazza Walther è area pedonale.",
     "Lieferverkehr bis 3,5 t Montag–Samstag 6–10:30 Uhr (nicht an Feiertagen); Elektro-, Hybrid- und Wasserstoff-Lieferwagen bis 4,25 t mit Genehmigung auch 10:30–11 Uhr und an einigen Zufahrten 14:30–16 Uhr. Der Waltherplatz ist Fußgängerzone."),
    ("Across the whole built-up area of Bolzano, Monday–Friday (not on holidays) 7:00–10:00 and 16:00–19:00: no Euro 0–1 petrol cars and no Euro 0–3 diesel cars. LPG, methane, electric, hybrid cars and motorcycles may always drive. GateLR does not show this area on the map.",
     "In tutto il centro abitato di Bolzano, lunedì–venerdì (festivi esclusi) 7–10 e 16–19: vietate le auto a benzina Euro 0–1 e diesel Euro 0–3. GPL, metano, elettriche, ibride e moto circolano sempre. GateLR non mostra quest'area sulla mappa.",
     "Im ganzen Ortsgebiet von Bozen, Montag–Freitag (außer Feiertagen) 7–10 und 16–19 Uhr: Fahrverbot für Benziner Euro 0–1 und Diesel Euro 0–3. Flüssiggas, Methan, Elektro, Hybrid und Motorräder dürfen immer fahren. GateLR zeigt dieses Gebiet nicht auf der Karte."),
    ("Perimeter traced from the official list of ZTL streets (resolution 518/2022) on OpenStreetMap streets; the short stretches of Viale Stazione and Via Piave are approximate. Cameras from OpenStreetMap: the City's gate map (Google My Maps) could not be read. The fine amount is not on the City's pages (about 80 € according to unofficial guides).",
     "Perimetro tracciato dall'elenco ufficiale delle vie della ZTL (delibera 518/2022) sulle strade di OpenStreetMap; i brevi tratti di viale Stazione e via Piave sono approssimati. Telecamere da OpenStreetMap: la mappa dei varchi del Comune (Google My Maps) non era leggibile. L'importo della multa non è sulle pagine del Comune (circa 80 € secondo guide non ufficiali).",
     "Grenze aus der offiziellen Straßenliste der VBZ (Beschluss 518/2022) auf OpenStreetMap-Straßen gezeichnet; die kurzen Abschnitte der Bahnhofsallee und der Piavestraße sind angenähert. Kameras aus OpenStreetMap: die Zufahrtskarte der Stadt (Google My Maps) war nicht lesbar. Die Höhe des Bußgelds steht nicht auf den Seiten der Stadt (laut inoffiziellen Ratgebern etwa 80 €)."),
]

GEO = json.loads((ROOT / "data/raw/geo/bolzano-ztl.json").read_text(encoding="utf-8"))["elements"]
STREETS = [e for e in GEO if e["type"] == "way" and e.get("tags", {}).get("name") and e.get("geometry")]


def xy(p):
    return (p["lon"] * 76500, p["lat"] * 111000)


def ways(name):
    """Le way OSM con il nome italiano indicato (a Bolzano i nomi OSM sono «italiano - deutsch»)"""
    r = [w for w in STREETS if w["tags"]["name"].split(" - ")[0].strip() == name]
    if not r:
        raise SystemExit(f"via non trovata in OSM: {name}")
    return r


def junction(a, b):
    """Il punto della via a più vicino alla via b (l'incrocio)"""
    d, p = min((math.dist(xy(p), xy(q)), p) for w in ways(a) for p in w["geometry"] for wb in ways(b) for q in wb["geometry"])
    assert d < 40, (a, b, d)
    return p


def clip(a, b, c):
    """I pezzi della via a compresi tra gli incroci con b e con c (proiezione sul segmento tra i due incroci)"""
    A, B = xy(junction(a, b)), xy(junction(a, c))
    dx, dy = B[0] - A[0], B[1] - A[1]
    out = []
    for w in ways(a):
        seg = []
        for p in w["geometry"] + [None]:
            if p is not None and -0.02 <= ((xy(p)[0] - A[0]) * dx + (xy(p)[1] - A[1]) * dy) / (dx * dx + dy * dy) <= 1.02:
                seg.append(p)
                continue
            if len(seg) > 1:
                out.append(seg)
            seg = []
    return out


# Delibera 518/2022, punto 1: le vie e piazze della ZTL (nomi italiani come in OSM). Vie intere:
FULL = ["Via Dr. Julius Perathoner", "Via dei Cappuccini", "Piazza Domenicani", "Vicolo delle Erbe", "Via Johann Wolfgang Von Goethe",
        "Via dell'Isarco", "Largo Adolph Kolping", "Via della Mostra", "Piazza della Mostra", "Piazza della Parrocchia", "Vicolo della Parrocchia",
        "Via della Posta", "Via della Rena", "Via Raffaello Sernesi", "Piazza Università", "Via Wolkenstein", "Via Argentieri", "Via dei Bottai",
        "Piazza delle Erbe", "Via dei Francescani", "Piazza del Grano", "Via dei Grappoli", "Vicolo Gumer", "Piazza del Municipio", "Vicolo della Pesa",
        "Via dei Portici", "Via della Roggia", "Via Dr. Josef Streiter", "Piazza Walther"]
# tratti «compresi tra» due vie
PART = [("Via Alto Adige", "Piazza Giuseppe Verdi", "Viale della Stazione"), ("Via Laurin", "Via Sciliar", "Via dei Grappoli"),
        ("Via Leonardo da Vinci", "Via Johann Wolfgang Von Goethe", "Via Cassa di Risparmio"), ("Via dei Conciapelli", "Via Laurin", "Via Molini"),
        ("Via Museo", "Piazza delle Erbe", "Via Cassa di Risparmio")]
lines = [w["geometry"] for n in FULL for w in ways(n)]
for a, b, c in PART:
    lines += clip(a, b, c)
# viale Stazione «tra accesso Parking Walther e piazza Walther»: il primo tratto dalla piazza (100 m, approssimato);
# via Piave «da piazza Municipio fino al civ. 5»: pochi metri, già coperti dalla piazza
WALTHER = [xy(p) for w in ways("Piazza Walther") for p in w["geometry"]]
lines.append([p for w in ways("Viale della Stazione") for p in w["geometry"] if min(math.dist(xy(p), q) for q in WALTHER) < 100])
SECTIONS = {"id": 0, "members": [{"type": "way", "role": "section", "geometry": l} for l in lines]}
perimeter = osm_geo.perimeter(osm_geo.street_area(SECTIONS, close_m=60), tol_m=4)


def street_of(lat, lon):
    """La strada OSM con nome più vicina alla telecamera (nome bilingue «italiano / deutsch»)"""
    best = min((math.hypot((p["lat"] - lat) * 111000, (p["lon"] - lon) * 76500), w["tags"]["name"]) for w in STREETS for p in w["geometry"])
    return best[1].replace(" - ", " / ")


gates = []
for osm_id, _, lat, lon in osm_geo.gates(GEO, relation_ids={19584710}, name_prefix=None):
    gates.append({"id": f"bz-osm{osm_id}", "name": street_of(lat, lon), "location": {"lat": round(lat, 6), "lon": round(lon, 6)}})
gates.sort(key=lambda g: g["name"])

zone = {"id": "bolzano-ztl", "name": "Old town · ZTL 24 hours", "name_it": "Centro storico · ZTL 0–24",
        "name_de": "Altstadt · Verkehrsberuhigte Zone rund um die Uhr", "kind": "restricted",
        "summary": "The old town of Bolzano (Piazza Walther, Via Portici, Piazza Erbe) is closed to cars without authorisation 24 hours a day, every day; cameras at the entrances read plates. There is no day ticket: if your hotel is inside, contact it before arriving and give your plate. Otherwise park outside (e.g. Mayr-Nusser car park, Piazza Walther underground car park).",
        "summary_it": "Il centro storico di Bolzano (piazza Walther, via Portici, piazza Erbe) è chiuso alle auto senza autorizzazione 24 ore su 24, tutti i giorni; le telecamere ai varchi leggono le targhe. Non c'è un biglietto giornaliero: se l'albergo è dentro, contattalo prima di arrivare e comunica la targa. Altrimenti parcheggia fuori (es. parcheggio Mayr Nusser, garage di piazza Walther).",
        "summary_de": "Die Bozner Altstadt (Waltherplatz, Laubengasse, Obstplatz) ist rund um die Uhr, jeden Tag, für Autos ohne Genehmigung gesperrt; Kameras an den Zufahrten lesen die Kennzeichen. Ein Tagesticket gibt es nicht: Liegt dein Hotel in der Zone, kontaktiere es vor der Ankunft und teile dein Kennzeichen mit. Sonst außerhalb parken (z. B. Parkplatz Mayr-Nusser, Tiefgarage Waltherplatz).",
        "perimeter": perimeter, "gates": gates,
        "windows": [{"weekdays": EVERY_DAY, "start": 0, "end": 24 * 60}],
        "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": True,
        "source": {"authority": "City of Bolzano", "pageURL": GUIDE,
                   "ordinance": "Delibere della Giunta comunale n. 518/2022 e n. 17/2023, ordinanze sindacali n. 709/2022 e n. 51/2023 (ZTL dal 01/02/2023)",
                   "ordinanceURL": DELIB,
                   "quote": QUOTE, "quoteTranslation": "The ZTL of Bolzano's historic centre is active 24 hours a day, every day",
                   "quoteTranslation_de": "Die verkehrsberuhigte Zone der Bozner Altstadt ist rund um die Uhr, jeden Tag, aktiv",
                   "checkedOn": CHECKED, "reviewedByHuman": False,
                   "pending": [p[0] for p in PENDING], "pending_it": [p[1] for p in PENDING], "pending_de": [p[2] for p in PENDING],
                   "links": LINKS}}

city = {"id": "bolzano", "name": "Bolzano", "name_it": "Bolzano", "name_de": "Bozen",
        "center": {"lat": 46.4983, "lon": 11.3548}, "zones": [zone], "status": "draft",
        "license": "Rules: Comune di Bolzano / Stadtgemeinde Bozen official pages and acts (CC BY 4.0). Perimeter: official street list (resolution 518/2022) traced on " + osm_geo.ODBL + "; cameras from OSM relation 19584710 (not official)."}

# Controlli: piazza Walther, piazza Erbe e via Portici dentro; stazione, piazza Verdi a sud e via Molini fuori; ogni via intera
# dell'elenco dentro; le telecamere OSM vicino al bordo
for n, lat, lon in [("Piazza Walther / Waltherplatz", 46.4983, 11.3548), ("Piazza Erbe / Obstplatz", 46.4998, 11.3527),
                    ("Via Portici / Laubengasse", 46.4995, 11.3545)]:
    assert osm_geo.contains(perimeter, lat, lon), f"{n} fuori dal perimetro"
for n, lat, lon in [("stazione di Bolzano", 46.4967, 11.3580), ("piazza Verdi (sud)", 46.4945, 11.3560), ("Museion", 46.4990, 11.3480)]:
    assert not osm_geo.contains(perimeter, lat, lon), f"{n} dentro il perimetro"
for n in FULL:
    for w in ways(n):
        p = w["geometry"][len(w["geometry"]) // 2]
        assert osm_geo.contains(perimeter, p["lat"], p["lon"]) or osm_geo.distance_m(perimeter, p["lat"], p["lon"]) < 10, n
for g in gates:
    assert osm_geo.distance_m(perimeter, g["location"]["lat"], g["location"]["lon"]) < 80, g
assert 0.15 < osm_geo.area_km2(perimeter) < 0.35, osm_geo.area_km2(perimeter)

ready = all(len(z["perimeter"]) >= 5 and z["source"]["quote"] for z in city["zones"])
out = ROOT / ("Resources/Cities/bolzano.json" if ready else "data/drafts/bolzano.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/bolzano.json" if ready else "Resources/Cities/bolzano.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), len(perimeter), [g["name"] for g in gates], round(osm_geo.area_km2(perimeter), 3))
