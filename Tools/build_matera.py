#!/usr/bin/env python3
# Costruisce Resources/Cities/matera.json dagli atti ufficiali del Comune di Matera salvati in data/raw/matera/
# (fonti e date in docs/fonti-matera.md). Ogni frase citata o riassunta viene ricontrollata sul testo salvato.
#
# Regole: tabella ufficiale «ZTL - TELECAMERE» (Ord. Dir. 147 e 148/2025, comune.matera.it, maggio 2025) con gli orari di
# tutte le ZTL; O.D. 147/2025 (ZTL Sassi: 10–24 dal 01/07 al 15/09, 10–20:30 dal 16/09 al 30/06), O.D. 148/2025 (ZTL Piave,
# stessi orari dei Sassi, varchi), O.D. 257/2025 (varchi Piave e Santa Cesarea in esercizio), O.D. 2941/2021 (strade e
# varchi delle ZTL Ridola, Casalnuovo, Stigliani, Prefettura; divieto per i clienti delle strutture ricettive nei Sassi),
# O.D. 270/2022 (elenco dei varchi elettronici), disciplinare ZTL/APU (D.G.C. 152/2016 e modifiche 2019) e procedura per le
# strutture ricettive (portale matera.sismic.it).
#
# Geometria: nessun perimetro ufficiale scaricabile (il GeoJSON open data del 2014 su dati.comune.matera.it è superato e il
# portale non risponde; Planimetria-ZTL.pdf è solo un disegno). Ogni zona è l'area coperta dalle strade dell'elenco
# ufficiale, con le geometrie OpenStreetMap (data/raw/geo/matera-sassi.json, © OpenStreetMap contributors, ODbL 1.0,
# scaricate con Tools/fetch_osm_api.py): i tratti «dall'intersezione con … all'intersezione con …» sono presi come il
# percorso più breve sulle way OSM della strada tra i due incroci. Per i Sassi: le strade carrabili dell'ordinanza più
# ogni strada/scalinata con il punto centrale nelle aree OSM «Sasso Caveoso» e «Sasso Barisano», escluse via Casalnuovo e
# via Santo Stefano (ordinanza del 2014, metadati open data su dati.gov.it). Varchi: il nodo OSM dell'incrocio indicato
# dall'ordinanza («via X angolo via Y»), o il nodo OSM della telecamera quando l'atto dà solo la strada.
# Uso: python3 Tools/build_matera.py   (non tocca le altre città né manifest.json)
import json, re
from collections import deque
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/matera"
CHECKED = "2026-10-26T23:50:00Z"
EVERY_DAY = [1, 2, 3, 4, 5, 6, 7]
WINTER = {"fromMonth": 9, "fromDay": 16, "toMonth": 6, "toDay": 30}
SUMMER = {"fromMonth": 7, "fromDay": 1, "toMonth": 9, "toDay": 15}

ZTL_PAGE = "https://comune.matera.it/ztl-apu/"
HOURS = "https://comune.matera.it/wp-content/uploads/2025/05/ORARI-TELECAMERE-BARRIERE.pdf"
ORD_147 = "https://comune.matera.it/wp-content/uploads/2025/05/Ordinanza_Dirigenziale_147_2025-ZTL-SASSI.pdf"
ORD_148 = "https://comune.matera.it/wp-content/uploads/2025/05/Ordinanza_Dirigenziale_148_2025-ZTL-PIAVE.pdf"
ORD_257 = "https://comune.matera.it/wp-content/uploads/2025/11/Ordinanza_Dirigenziale_257_2025.pdf"
ORD_2941 = "https://www.comune.matera.it/wp-content/uploads/2024/01/Ordinanza-Dirigenziale-n.2941-2021.pdf"
ORD_270 = "https://www.comune.matera.it/wp-content/uploads/2024/01/Ord.Dir_.-n.-270-2022-Attivazione-del-sistema-dei-varchi-elettronici-ZTL-Periodo-di-pre-esercizio.pdf"
RULES = "https://www.comune.matera.it/wp-content/uploads/2024/01/Disciplinare-con-modifiche-D.G.C.-2019.pdf"
HOTELS = "https://comune.matera.it/wp-content/uploads/2024/01/Procedura-per-comunicazione-transiti-da-parte-di-strutture-ricettive-e-autorimesse.pdf"
MAP = "https://www.comune.matera.it/wp-content/uploads/2024/01/Planimetria-ZTL.pdf"


def flat(s):
    return re.sub(r"\s+", " ", s).strip()


TEXT = {p.stem: flat(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def check(file, *phrases):
    for q in phrases:
        if flat(q) not in TEXT[file]:
            raise SystemExit(f"{file}: frase non trovata, ricontrollare il documento: {q!r}")


T = "orari-telecamere-barriere-2025"
ROWS = {"prefettura": "ZTL PREFETTURA (Via Roma Via XX Settembre) 20:30 - 24:00 20:30 - 24:00",
        "centro": "ZTL CENTRO (Vie Scotellaro, Corso, Beccherie, Duomo, Sedile, S. Francesco) 00:00 - 24:00 00:00 - 24:00",
        "san-biagio": "ZTL SAN GIOVANNI/SAN BIAGIO (Via Stigliani, San Biagio) 00:00 - 24:00 00:00 - 24:00",
        "ridola": "ZTL RIDOLA (Via e Vico Duni, Via Ridola) 20:30 - 24:00 20:30 - 24:00",
        "casalnuovo": "ZTL CASALNUOVO (Via Casalnuovo) 20:30 - 24:00 20:30 - 24:00",
        "stigliani": "ZTL STIGLIANI (Via Stigliani, Vico XX Settembre) 20:30 - 24:00 20:30 - 24:00",
        "santa-cesarea": "ZTL SANTA CESAREA (Via S. Cesarea, Vico Piave) 00:00 - 24:00 00:00 - 24:00"}
check(T, "Ord. Dir. N° 147 e 148/2025", *ROWS.values(),
      "10:00 - 20:30 dal 16/09 al 30/06 10:00 - 20:30 dal 16/09 al 30/06 ZTL PIAVE (Via Piave, R.to I Piave, Via F.P. Festa, Vico I e II F.P. Festa, Via O. Tataranni)",
      "ZTL SASSI (Via Buozzi, Via Madonna Delle Virtù, Via D'Addozio)", "ZTL ATTIVA: ACCESSO NON CONSENTITO")
SASSI_QUOTE = ("- periodo estivo compreso dal 01 luglio al 15 settembre, di ogni anno, dalle ore 10.00 alle ore 24:00; "
               "- periodo invernale compreso dal 16 settembre al 30 giugno, di ogni anno, dalle ore 10.00 alle ore 20:30.")
check("od-147-2025-ztl-sassi", SASSI_QUOTE, "ORDINANZA DIRIGENZIALE N°: 147/2025", "Matera, 27/05/2025")
PIAVE_QUOTE = ("il divieto di transito veicolare tutti i giorni della settimana dalle ore 10:00 alle ore 24:00, nel periodo estivo "
               "compreso dal 01 luglio al 15 settembre, di ogni anno")
check("od-148-2025-ztl-piave", PIAVE_QUOTE,
      "Z.T.L. PIAVE comprendente via Piave, vico I F. P. Festa, vico II F. P. Festa, via F. P. Festa, recinto I Piave e via O. Tataranni, nel tratto compreso tra via F. Volpe e via Piave;",
      "via Piave, all’intersezione con via Stigliani;", "vico II F. P. Festa, all’intersezione con Via G. B. Pentasuglia;",
      "via O. Tataranni, all’intersezione con via F. Volpe;",
      "dalle ore 10:00 alle ore 20:30, nel periodo invernale compreso dal 16 settembre al 30 giugno, di ogni anno")
check("od-257-2025-varchi-piave-cesarea", "via Santa Cesarea intersezione via Piave.")
check("od-2941-2021-ztl",
      "Ridola, tratto compreso fra l’intersezione con Via Lucana e l’intersezione con Via E. Duni, Via E. Duni, Recinto E. Duni, Vico I E. Duni e Vico II E. Duni;",
      "Z.T.L. CASALNUOVO (varco entrata Via Casalnuovo) comprendente l’omonima via;",
      "Z.T.L. STIGLIANI (varco entrata Via Stigliani angolo Via G. Amendola) comprendente",
      "vico XX Settembre e l’intersezione con Via Lucana;",
      "il divieto di transito veicolare tutti i giorni della settimana dalle ore 20.30 alle ore 02.00 del",
      "l’accesso sarà consentito attraverso il varco di Via E. Duni angolo Via Lucana",
      "il divieto di transito ai clienti delle strutture ricettive per le operazioni di carico e scarico bagagli, negli orari di attivazione della ZTL Sassi",
      "Sassi che usufruiscono della sosta in arre private e/o rimesse pertinenziali alle medesime strutture;")
check("od-270-2022-varchi", "- Via Scotellaro (ingresso / uscita);", "- Via Roma Sud;", "- Via Stigliani angolo Vico XX Settembre;",
      "- Via Casalnuovo angolo via Cappuccini;", "- Via Duni angolo via Lucana;", "- Via XX Settembre angolo vico XX Settembre (uscita)")
check("disciplinare-2019",
      "I veicoli a completa trazione elettrica potranno accedere alla Z.T.L., senza alcun limite di fascia oraria, purché preventivamente autorizzati.",
      "potranno accedere alla Z.T.L., senza alcun limite di fascia oraria e senza autorizzazione preventiva, al solo fine di raggiungere le aree di sosta a loro riservate, i seguenti mezzi:",
      "Per i clienti delle predette strutture ricettive, che non dispongano di garage o posti auto riservati, al solo fine del carico e scarico bagagli, sarà consentito il solo transito dal varco/dai varchi di pertinenza e la fermata")
check("procedura-strutture-ricettive", "https://matera.sismic.it", "che non potrà avvenire trascorso il giorno solare successivo al transito.")
check("comune-ztl-apu", "telefonare, preventivamente all’accesso in ZTL, al numero verde: 800 091 980", "Email: ztl@comune.mt.it")
check("dati-gov-ztl-e-apu-estratto-ordinanza-2014",
      "ZTL Sassi: (area che comprende via D’Addozio, Via Fiorentini, Via Sant’Antonio Abate, Via Madonna delle Virtù, via Bruno Buozzi, ed ogni altra strada interna ai Rioni Sassi limitrofa alle anzidette strade, con esclusione di via Casalnuovo e Via Santo Stefano)",
      "6. Via Bruno Buozzi, intersezione Via Casalnuovo", "7. Via D’Addozio, intersezione Via Santo Stefano.")

# --- dati OSM ---
GEO = osm_geo.load("matera-sassi")
WAYS = [e for e in GEO if e["type"] == "way"]
NODE = {}
for w in WAYS:
    for nid, p in zip(w["nodes"], w["geometry"]):
        NODE[nid] = (p["lon"], p["lat"])
HW = {"residential", "service", "living_street", "pedestrian", "unclassified", "footway", "steps", "path", "track", "tertiary"}


def named(*names):
    out = [w for w in WAYS if w["tags"].get("name") in names and w["tags"].get("highway")]
    missing = set(names) - {w["tags"]["name"] for w in out}
    if missing:
        raise SystemExit(f"Strade non trovate in OSM: {missing}")
    return out


def junctions(a, b):
    common = {n for w in named(a) for n in w["nodes"]} & {n for w in named(b) for n in w["nodes"]}
    if not common:
        raise SystemExit(f"Incrocio non trovato in OSM: {a} / {b}")
    return sorted(common)


def junction(a, b):
    return junctions(a, b)[0]


def tract(names, a, b):
    """Il tratto delle strade «names» dall'incrocio con «a» all'incrocio con «b» (percorso più breve sulle way OSM)"""
    ws = [w for n in names for w in named(n)]
    adj = {}
    for w in ws:
        for x, y in zip(w["nodes"], w["nodes"][1:]):
            adj.setdefault(x, set()).add(y); adj.setdefault(y, set()).add(x)
    best = None
    for start in junctions(names[0], a):
        prev, todo = {start: None}, deque([start])
        while todo:
            x = todo.popleft()
            for y in adj.get(x, ()):
                if y not in prev:
                    prev[y] = x; todo.append(y)
        for goal in junctions(names[-1], b):
            if goal in prev:
                path, x = [], goal
                while x is not None:
                    path.append(x); x = prev[x]
                if best is None or len(path) < len(best):
                    best = path
    if not best:
        raise SystemExit(f"Tratto non collegato in OSM: {names} da {a} a {b}")
    return {"geometry": [{"lon": NODE[n][0], "lat": NODE[n][1]} for n in best]}


def area(lines, close_m=25):
    # ogni strada anche spostata di ±3 m: le celle della griglia restano unite anche sulle strade in diagonale
    dlat, dlon = 3 / 110574.0, 3 / (111320.0 * 0.7587)
    geoms = [[{"lat": q["lat"] + a, "lon": q["lon"] + b} for q in l["geometry"]]
             for l in lines for a, b in ((0, 0), (dlat, 0), (-dlat, 0), (0, dlon), (0, -dlon))]
    rel = {"id": 0, "members": [{"type": "way", "role": "section", "geometry": g} for g in geoms]}
    return osm_geo.perimeter(osm_geo.street_area(rel, cell_m=5, close_m=close_m), tol_m=4)


NEIGHBOURHOODS = [[(p["lon"], p["lat"]) for p in w["geometry"]] for w in WAYS
                  if w["tags"].get("place") == "neighbourhood" and w["tags"].get("name") in ("Sasso Caveoso", "Sasso Barisano")]
assert len(NEIGHBOURHOODS) == 2, "aree OSM Sasso Caveoso / Sasso Barisano non trovate"
SASSI_ROADS = {"Via d'Addozio", "Via Fiorentini", "Via Sant'Antonio Abate", "Via Madonna delle Virtù", "Via Bruno Buozzi",
               "Recinto primo D'Addozio", "Recinto secondo d'Addozio", "Slargo Via Madonna delle Virtù"}
CENTRO = ("Via Rocco Scotellaro", "Via del Corso", "Via delle Beccherie", "Via Duomo", "Piazza Duomo", "Piazza del Duomo",
          "Piazza del Sedile", "Arco del Sedile", "Piazza San Francesco", "Via San Francesco", "Gradoni Duomo")
OTHER_ZTL = set(CENTRO) | {"Via Casalnuovo", "Via Santo Stefano", "Vico I. Casalnuovo", "Vico II Casalnuovo", "Vico III Casalnuovo",
                           "Recinto del Sedile", "Via Domenico Ridola", "Calata Domenico Ridola", "Via Emanuele Duni"}


def sassi_lines():
    out = []
    for w in WAYS:
        n, mid = w["tags"].get("name", ""), w["geometry"][len(w["geometry"]) // 2]
        if w["tags"].get("highway") in HW and n not in OTHER_ZTL and \
                (n in SASSI_ROADS or any(osm_geo.inside_lonlat(r, mid["lon"], mid["lat"]) for r in NEIGHBOURHOODS)):
            out.append(w)
    return out


SHAPES = {
    "sassi": area(sassi_lines(), 40),
    "piave": area(named("Via Piave", "Vico I Francesco Paolo Festa", "Vico II Francesco Paolo Festa", "Via Francesco Paolo Festa",
                        "Recinto I Piave") + [tract(["Via Onofrio Tataranni"], "Via Francesco Paolo Volpe", "Via Piave")]),
    "centro": area(named(*CENTRO), 80),
    "san-biagio": area([tract(["Via Stigliani"], "Vico Venti Settembre", "Via San Biagio")] + named("Via San Biagio", "Piazza San Biagio")),
    "santa-cesarea": area([tract(["Via Santa Cesarea"], "Via Piave", "Vico Piave")] + named("Vico Piave")),
    "prefettura": area([tract(["Via Roma"], "Via Lucana", "Via Venti Settembre"), tract(["Via Venti Settembre"], "Via Roma", "Via Lucana")]),
    "ridola": area([tract(["Via Domenico Ridola"], "Via Lucana", "Via Emanuele Duni")] +
                   named("Via Emanuele Duni", "Recinto Emanuele Duni", "Vico Primo Emanuele Duni", "Vico Secondo Emanuele Duni")),
    "casalnuovo": area(named("Via Casalnuovo")),
    "stigliani": area([tract(["Via Tommaso Stigliani"], "Via Giovanni Amendola", "Vico Venti Settembre")] + named("Vico Venti Settembre")),
}

CAM = {e["tags"]["name"]: e for e in GEO if e["type"] == "node"}


def gate_at(name, a, b):
    lon, lat = NODE[junction(a, b)]
    return {"id": f"mt-{re.sub(r'[^a-z]+', '-', name.lower()).strip('-')}", "name": name, "location": {"lat": round(lat, 6), "lon": round(lon, 6)}}


def gate_cam(name, cam):
    c = CAM[cam]
    return {"id": f"mt-osm{c['id']}", "name": name, "location": {"lat": round(c["lat"], 6), "lon": round(c["lon"], 6)}}


GATES = {
    "sassi": [gate_at("Varco · Via Bruno Buozzi / Via Casalnuovo", "Via Bruno Buozzi", "Via Casalnuovo"),
              gate_at("Varco · Via D'Addozio / Via Santo Stefano", "Via d'Addozio", "Via Santo Stefano")],
    "piave": [gate_at("Varco · Via Piave / Via Stigliani", "Via Piave", "Via Tommaso Stigliani"),
              gate_at("Varco · Vico II F. P. Festa / Via Pentasuglia", "Vico II Francesco Paolo Festa", "Via Giambattista Pentasuglia"),
              gate_at("Varco · Via Tataranni / Via Volpe", "Via Onofrio Tataranni", "Via Francesco Paolo Volpe")],
    "centro": [gate_cam("Varco · Via Scotellaro", "ZTL Centro")],
    "san-biagio": [gate_at("Varco · Via Stigliani / Vico XX Settembre", "Via Stigliani", "Vico Venti Settembre")],
    "santa-cesarea": [gate_at("Varco · Via Santa Cesarea / Via Piave", "Via Santa Cesarea", "Via Piave")],
    "prefettura": [gate_cam("Varco · Via Roma Sud", "ZTL Prefettura"),
                   gate_at("Varco · Via XX Settembre / Vico XX Settembre (exit)", "Via Venti Settembre", "Vico Venti Settembre")],
    "ridola": [gate_at("Varco · Via Duni / Via Lucana", "Via Emanuele Duni", "Via Lucana")],
    "casalnuovo": [gate_at("Varco · Via Casalnuovo / Via Cappuccini", "Via Casalnuovo", "Via Cappuccini")],
    "stigliani": [gate_at("Varco · Via Stigliani / Via Amendola", "Via Tommaso Stigliani", "Via Giovanni Amendola")],
}

# Controlli: un punto dentro ogni zona (sulle strade dell'elenco, coordinate dai dati OSM), la stazione e piazza V. Veneto fuori
OUT = [("Stazione Matera Centrale", 40.66627, 16.60122), ("Piazza Vittorio Veneto (Palombaro Lungo)", 40.66690, 16.60650)]
IN = {"sassi": [("San Pietro Barisano", 40.66872, 16.60924), ("Casa Grotta nei Sassi", 40.66386, 16.61232)],
      "centro": [("Piazza del Sedile", 40.66564, 16.60975), ("Piazza Duomo", 40.66667, 16.61093)]}
for k, shape in SHAPES.items():
    for name, lat, lon in IN.get(k, []):
        if not osm_geo.contains(shape, lat, lon):
            raise SystemExit(f"{k}: {name} dovrebbe essere dentro")
    for name, lat, lon in OUT:
        if osm_geo.contains(shape, lat, lon):
            raise SystemExit(f"{k}: {name} dovrebbe essere fuori")
    for g in GATES[k]:
        if osm_geo.distance_m(shape, g["location"]["lat"], g["location"]["lon"]) > 40 and not osm_geo.contains(shape, g["location"]["lat"], g["location"]["lon"]):
            raise SystemExit(f"{k}: varco lontano dalla zona: {g['name']}")
a = osm_geo.area_km2(SHAPES["sassi"])
if not 0.15 < a < 0.4:
    raise SystemExit(f"Sassi: area non plausibile {a:.3f} km²")


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


LINKS = [link("City of Matera: ZTL and pedestrian areas", "Comune di Matera: ZTL/APU", "Stadt Matera: ZTL und Fußgängerzonen", ZTL_PAGE),
         link("City of Matera: camera hours of every ZTL (PDF, 2025)", "Comune di Matera: orari delle telecamere di tutte le ZTL (PDF, 2025)",
              "Stadt Matera: Kamerazeiten aller ZTL (PDF, 2025)", HOURS),
         link("Ordinance 147/2025: Sassi ZTL hours (PDF)", "Ordinanza 147/2025: orari ZTL Sassi (PDF)", "Verordnung 147/2025: Zeiten der ZTL Sassi (PDF)", ORD_147),
         link("Ordinance 148/2025: Piave ZTL (PDF)", "Ordinanza 148/2025: ZTL Piave (PDF)", "Verordnung 148/2025: ZTL Piave (PDF)", ORD_148),
         link("Ordinance 2941/2021: Ridola, Casalnuovo, Stigliani and Prefettura ZTLs (PDF)", "Ordinanza 2941/2021: ZTL Ridola, Casalnuovo, Stigliani e Prefettura (PDF)",
              "Verordnung 2941/2021: ZTL Ridola, Casalnuovo, Stigliani und Prefettura (PDF)", ORD_2941),
         link("Ordinance 270/2022: list of the cameras (PDF)", "Ordinanza 270/2022: elenco dei varchi elettronici (PDF)", "Verordnung 270/2022: Liste der Kameras (PDF)", ORD_270),
         link("ZTL rules (disciplinare, PDF)", "Disciplinare ZTL/APU (PDF)", "ZTL-Regeln (Disciplinare, PDF)", RULES),
         link("How hotels register guests' plates (PDF)", "Procedura per le strutture ricettive (PDF)", "So melden Hotels die Kennzeichen (PDF)", HOTELS),
         link("Official ZTL map (PDF)", "Planimetria ZTL (PDF)", "Offizielle ZTL-Karte (PDF)", MAP),
         link("OpenStreetMap: streets of Matera (ODbL)", "OpenStreetMap: strade di Matera (ODbL)", "OpenStreetMap: Straßen von Matera (ODbL)",
              "https://www.openstreetmap.org/#map=17/40.6660/16.6090")]

COMMON = [
    ("Map outline: the area of the streets named in the City's ordinances, drawn on OpenStreetMap streets (approximate); camera positions at the junctions the ordinances name.",
     "Perimetro: l'area delle strade elencate nelle ordinanze del Comune, sulle strade OpenStreetMap (approssimativo); varchi agli incroci indicati dalle ordinanze.",
     "Grenze: die Fläche der in den Verordnungen genannten Straßen, auf OpenStreetMap-Straßen (ungefähr); Kameras an den in den Verordnungen genannten Kreuzungen."),
    ("Electric cars may enter at any time only with a permit issued beforehand (free), so GateLR does not exempt them. Motorbikes and mopeds may enter without a permit only to reach the parking bays reserved for them. Blue Badge holders not on the permit list must call 800 091 980 before entering.",
     "Le auto elettriche entrano a ogni ora solo con un permesso rilasciato prima (gratuito), quindi GateLR non le esenta. Moto e ciclomotori entrano senza permesso solo per raggiungere gli stalli a loro riservati. Con il contrassegno disabili, se non si è nella lista permessi, chiamare prima l'800 091 980.",
     "Elektroautos dürfen jederzeit einfahren, aber nur mit vorher ausgestellter (kostenloser) Genehmigung, daher befreit GateLR sie nicht. Motorräder und Mopeds dürfen ohne Genehmigung nur zu den für sie reservierten Stellplätzen fahren. Mit Behindertenausweis, wenn nicht auf der Liste: vorher 800 091 980 anrufen."),
]
EVENING_PENDING = [("Hours 8:30 pm–midnight from the City's 2025 camera timetable; ordinance 2941/2021 had set 8:30 pm–2 am. GateLR follows the newer timetable.",
                    "Orario 20:30–24 dalla tabella delle telecamere del Comune (2025); l'ordinanza 2941/2021 indicava 20:30–2. GateLR segue la tabella più recente.",
                    "Zeiten 20:30–24 Uhr laut Kameratabelle der Stadt (2025); die Verordnung 2941/2021 nannte 20:30–2 Uhr. GateLR folgt der neueren Tabelle.")]
HOTEL_OK = ("Hotels and B&Bs inside register your plate on the City's portal (matera.sismic.it), at the latest by the end of the day after you drive in; only to unload luggage.",
            "Hotel e B&B dentro registrano la targa sul portale del Comune (matera.sismic.it), al più tardi entro il giorno dopo il transito; solo per scaricare i bagagli.",
            "Hotels und B&Bs innen melden dein Kennzeichen im Portal der Stadt (matera.sismic.it), spätestens bis zum Ende des Tages nach der Einfahrt; nur zum Ausladen.")


def zone(k, names, summary, windows, quote, quote_en, quote_de, ordinance, url, hotel=True, extra=()):
    pend = list(extra) + ([HOTEL_OK] if hotel else []) + COMMON
    return {"id": f"matera-{k}", "name": names[0], "name_it": names[1], "name_de": names[2], "kind": "restricted",
            "summary": summary[0], "summary_it": summary[1], "summary_de": summary[2],
            "perimeter": SHAPES[k], "gates": GATES[k], "windows": windows,
            "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": hotel,
            "source": {"authority": "City of Matera", "pageURL": ZTL_PAGE, "ordinance": ordinance, "ordinanceURL": url,
                       "quote": quote, "quoteTranslation": quote_en, "quoteTranslation_de": quote_de,
                       "checkedOn": CHECKED, "reviewedByHuman": False,
                       "pending": [p[0] for p in pend], "pending_it": [p[1] for p in pend], "pending_de": [p[2] for p in pend],
                       "links": LINKS}}


SEASONAL = [{"weekdays": EVERY_DAY, "start": 10 * 60, "end": 20 * 60 + 30, "season": WINTER},
            {"weekdays": EVERY_DAY, "start": 10 * 60, "end": 24 * 60, "season": SUMMER}]
H24 = [{"weekdays": EVERY_DAY, "start": 0, "end": 24 * 60}]
EVENING = [{"weekdays": EVERY_DAY, "start": 20 * 60 + 30, "end": 24 * 60}]
TABLE = "Ord. Dir. n. 147 e 148/2025, tabella «ZTL - Telecamere» del Comune"


def row(k):
    return ROWS[k]


def tr_h24(what):
    return (f"{what}: weekdays 00:00–24:00, holidays 00:00–24:00.", f"{what}: werktags 0–24 Uhr, feiertags 0–24 Uhr.")


def tr_eve(what):
    return (f"{what}: weekdays 20:30–24:00, holidays 20:30–24:00.", f"{what}: werktags 20:30–24 Uhr, feiertags 20:30–24 Uhr.")


zones = [
    zone("sassi", ("Sassi · Sasso Barisano and Sasso Caveoso", "Sassi · Sasso Barisano e Sasso Caveoso", "Sassi · Sasso Barisano und Sasso Caveoso"),
         ("The road through the Sassi (via D'Addozio, via Madonna delle Virtù, via Buozzi) is closed to cars without a permit every day from 10 am: until 8:30 pm from 16 September to 30 June, until midnight from 1 July to 15 September. Early morning and at night it is open. During those hours hotel guests may not drive in to unload, unless the hotel in the Sassi has its own parking: park above (piazza della Visitazione, via Saragat) and walk down.",
          "La strada dei Sassi (via D'Addozio, via Madonna delle Virtù, via Buozzi) è chiusa alle auto senza permesso tutti i giorni dalle 10: fino alle 20:30 dal 16 settembre al 30 giugno, fino a mezzanotte dal 1° luglio al 15 settembre. Al mattino presto e di notte è aperta. In quegli orari gli ospiti degli hotel non possono entrare a scaricare, salvo che la struttura nei Sassi abbia un parcheggio proprio: parcheggia sopra (piazza della Visitazione, via Saragat) e scendi a piedi.",
          "Die Straße durch die Sassi (Via D'Addozio, Via Madonna delle Virtù, Via Buozzi) ist für Autos ohne Genehmigung täglich ab 10 Uhr gesperrt: bis 20:30 Uhr vom 16. September bis 30. Juni, bis Mitternacht vom 1. Juli bis 15. September. Frühmorgens und nachts ist sie offen. In dieser Zeit dürfen Hotelgäste nicht zum Ausladen hinein, außer das Hotel in den Sassi hat einen eigenen Parkplatz: oben parken (Piazza della Visitazione, Via Saragat) und zu Fuß hinunter."),
         SEASONAL, SASSI_QUOTE,
         "Summer period from 1 July to 15 September each year, from 10:00 to 24:00; winter period from 16 September to 30 June each year, from 10:00 to 20:30.",
         "Sommerzeit vom 1. Juli bis 15. September jedes Jahres, von 10:00 bis 24:00 Uhr; Winterzeit vom 16. September bis 30. Juni jedes Jahres, von 10:00 bis 20:30 Uhr.",
         "Ordinanza dirigenziale n. 147/2025 del 27/05/2025 (ZTL Rioni Sassi)", ORD_147, hotel=False,
         extra=[("Hotel guests may not drive into the Sassi to unload while the ZTL is on, except guests of Sassi hotels with their own parking or garage (ordinance 2941/2021): GateLR does not let the hotel register you here.",
                 "Gli ospiti degli hotel non possono entrare nei Sassi a scaricare mentre la ZTL è attiva, salvo i clienti delle strutture nei Sassi con parcheggio o rimessa propri (ordinanza 2941/2021): qui GateLR non prevede la registrazione dell'hotel.",
                 "Hotelgäste dürfen während der ZTL-Zeiten nicht zum Ausladen in die Sassi fahren, außer Gäste von Sassi-Hotels mit eigenem Parkplatz oder Garage (Verordnung 2941/2021): GateLR sieht hier keine Meldung durch das Hotel vor."),
                ("Map outline: the streets of the Sassi neighbourhoods in OpenStreetMap; it includes the Civita around the Cathedral, which is also in the Centro ZTL (closed 24 hours).",
                 "Perimetro: le strade dei rioni Sassi in OpenStreetMap; comprende la Civita attorno al Duomo, che è anche nella ZTL Centro (chiusa 24 ore).",
                 "Grenze: die Straßen der Sassi-Viertel in OpenStreetMap; sie umfasst die Civita um den Dom, die auch zur ZTL Centro gehört (24 Stunden gesperrt).")]),
    zone("piave", ("Piave · via Piave and via F. P. Festa", "Piave · via Piave e via F. P. Festa", "Piave · Via Piave und Via F. P. Festa"),
         ("Via Piave, via F. P. Festa and via Tataranni (above the Sasso Barisano) follow the Sassi hours: closed to cars without a permit every day from 10 am to 8:30 pm (16 September–30 June) or to midnight (1 July–15 September).",
          "Via Piave, via F. P. Festa e via Tataranni (sopra il Sasso Barisano) seguono gli orari dei Sassi: chiuse alle auto senza permesso tutti i giorni dalle 10 alle 20:30 (16 settembre–30 giugno) o fino a mezzanotte (1° luglio–15 settembre).",
          "Via Piave, Via F. P. Festa und Via Tataranni (oberhalb des Sasso Barisano) folgen den Zeiten der Sassi: für Autos ohne Genehmigung täglich von 10 bis 20:30 Uhr (16. September–30. Juni) bzw. bis Mitternacht (1. Juli–15. September) gesperrt."),
         SEASONAL, PIAVE_QUOTE,
         "No vehicles every day of the week from 10:00 to 24:00 in the summer period from 1 July to 15 September each year.",
         "Durchfahrtsverbot an allen Wochentagen von 10:00 bis 24:00 Uhr in der Sommerzeit vom 1. Juli bis 15. September jedes Jahres.",
         "Ordinanza dirigenziale n. 148/2025 (ZTL Piave); varchi in esercizio con O.D. n. 257/2025", ORD_148),
    zone("centro", ("Centro & Civita · Duomo, Sedile, via del Corso", "Centro e Civita · Duomo, Sedile, via del Corso", "Zentrum & Civita · Dom, Sedile, Via del Corso"),
         ("The streets around piazza del Sedile, via del Corso, via Scotellaro, piazza San Francesco and up to the Cathedral (Civita) are closed to cars without a permit 24 hours a day, every day. Deliveries only 7–10:30 am and 3–5 pm.",
          "Le strade attorno a piazza del Sedile, via del Corso, via Scotellaro, piazza San Francesco e fino al Duomo (Civita) sono chiuse alle auto senza permesso 24 ore su 24, tutti i giorni. Carico e scarico solo 7–10:30 e 15–17.",
          "Die Straßen um Piazza del Sedile, Via del Corso, Via Scotellaro, Piazza San Francesco bis hinauf zum Dom (Civita) sind für Autos ohne Genehmigung rund um die Uhr, täglich gesperrt. Lieferungen nur 7–10:30 und 15–17 Uhr."),
         H24, row("centro"), *tr_h24("Centro ZTL (via Scotellaro, via del Corso, via Beccherie, via Duomo, Sedile, San Francesco)"), TABLE, HOURS),
    zone("san-biagio", ("San Biagio · via San Biagio and via Stigliani", "San Biagio · via San Biagio e via Stigliani", "San Biagio · Via San Biagio und Via Stigliani"),
         ("Via San Biagio and the end of via Stigliani (San Giovanni/San Biagio ZTL) are closed to cars without a permit 24 hours a day, every day.",
          "Via San Biagio e l'ultimo tratto di via Stigliani (ZTL San Giovanni/San Biagio) sono chiusi alle auto senza permesso 24 ore su 24, tutti i giorni.",
          "Via San Biagio und das Ende der Via Stigliani (ZTL San Giovanni/San Biagio) sind für Autos ohne Genehmigung rund um die Uhr, täglich gesperrt."),
         H24, row("san-biagio"), *tr_h24("San Giovanni/San Biagio ZTL (via Stigliani, San Biagio)"), TABLE, HOURS),
    zone("santa-cesarea", ("Santa Cesarea · via Santa Cesarea and vico Piave", "Santa Cesarea · via Santa Cesarea e vico Piave", "Santa Cesarea · Via Santa Cesarea und Vico Piave"),
         ("Via Santa Cesarea (from via Piave to vico Piave) and vico Piave are closed to cars without a permit 24 hours a day, every day.",
          "Via Santa Cesarea (da via Piave a vico Piave) e vico Piave sono chiusi alle auto senza permesso 24 ore su 24, tutti i giorni.",
          "Via Santa Cesarea (von Via Piave bis Vico Piave) und Vico Piave sind für Autos ohne Genehmigung rund um die Uhr, täglich gesperrt."),
         H24, row("santa-cesarea"), *tr_h24("Santa Cesarea ZTL (via S. Cesarea, vico Piave)"), TABLE, HOURS),
    zone("prefettura", ("Prefettura · via Roma and via XX Settembre", "Prefettura · via Roma e via XX Settembre", "Prefettura · Via Roma und Via XX Settembre"),
         ("Via Roma and via XX Settembre (by the Prefecture) are closed to cars without a permit every evening from 8:30 pm to midnight. During the day they are open.",
          "Via Roma e via XX Settembre (presso la Prefettura) sono chiuse alle auto senza permesso ogni sera dalle 20:30 a mezzanotte. Di giorno sono aperte.",
          "Via Roma und Via XX Settembre (an der Präfektur) sind für Autos ohne Genehmigung jeden Abend von 20:30 Uhr bis Mitternacht gesperrt. Tagsüber sind sie offen."),
         EVENING, row("prefettura"), *tr_eve("Prefettura ZTL (via Roma, via XX Settembre)"), TABLE, HOURS, extra=EVENING_PENDING),
    zone("ridola", ("Ridola · via Ridola and via Duni", "Ridola · via Ridola e via Duni", "Ridola · Via Ridola und Via Duni"),
         ("Via Ridola (from via Lucana to via Duni) and via Duni are closed to cars without a permit every evening from 8:30 pm to midnight.",
          "Via Ridola (da via Lucana a via Duni) e via Duni sono chiuse alle auto senza permesso ogni sera dalle 20:30 a mezzanotte.",
          "Via Ridola (von Via Lucana bis Via Duni) und Via Duni sind für Autos ohne Genehmigung jeden Abend von 20:30 Uhr bis Mitternacht gesperrt."),
         EVENING, row("ridola"), *tr_eve("Ridola ZTL (via and vico Duni, via Ridola)"), TABLE, HOURS, extra=EVENING_PENDING),
    zone("casalnuovo", ("Casalnuovo · via Casalnuovo", "Casalnuovo · via Casalnuovo", "Casalnuovo · Via Casalnuovo"),
         ("Via Casalnuovo (below the Sasso Caveoso) is closed to cars without a permit every evening from 8:30 pm to midnight.",
          "Via Casalnuovo (sotto il Sasso Caveoso) è chiusa alle auto senza permesso ogni sera dalle 20:30 a mezzanotte.",
          "Die Via Casalnuovo (unterhalb des Sasso Caveoso) ist für Autos ohne Genehmigung jeden Abend von 20:30 Uhr bis Mitternacht gesperrt."),
         EVENING, row("casalnuovo"), *tr_eve("Casalnuovo ZTL (via Casalnuovo)"), TABLE, HOURS, extra=EVENING_PENDING),
    zone("stigliani", ("Stigliani · via Stigliani and vico XX Settembre", "Stigliani · via Stigliani e vico XX Settembre", "Stigliani · Via Stigliani und Vico XX Settembre"),
         ("Via Tommaso Stigliani (from via Amendola to vico XX Settembre) and vico XX Settembre are closed to cars without a permit every evening from 8:30 pm to midnight.",
          "Via Tommaso Stigliani (da via Amendola a vico XX Settembre) e vico XX Settembre sono chiusi alle auto senza permesso ogni sera dalle 20:30 a mezzanotte.",
          "Via Tommaso Stigliani (von Via Amendola bis Vico XX Settembre) und Vico XX Settembre sind für Autos ohne Genehmigung jeden Abend von 20:30 Uhr bis Mitternacht gesperrt."),
         EVENING, row("stigliani"), *tr_eve("Stigliani ZTL (via Stigliani, vico XX Settembre)"), TABLE, HOURS, extra=EVENING_PENDING),
]

city = {"id": "matera", "name": "Matera", "name_it": "Matera", "name_de": "Matera",
        "center": {"lat": 40.6660, "lon": 16.6090}, "zones": zones, "status": "draft",
        "license": "Rules: Comune di Matera ordinances and camera timetable. Perimeters and gates: " + osm_geo.ODBL
                   + " (areas of the streets in the City's list, approximate)."}

ready = all(len(z["perimeter"]) >= 5 and z["source"]["quote"] for z in city["zones"])
out = ROOT / ("Resources/Cities/matera.json" if ready else "data/drafts/matera.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/matera.json" if ready else "Resources/Cities/matera.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), [(z["id"], len(z["perimeter"]), len(z["gates"]), round(osm_geo.area_km2(z["perimeter"]), 4)) for z in zones])
