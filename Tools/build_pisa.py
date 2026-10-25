#!/usr/bin/env python3
# Costruisce Resources/Cities/pisa.json dalle fonti ufficiali salvate in data/raw/pisa/ (vedi docs/fonti-pisa.md).
# Non ricostruisce le altre città e non tocca manifest.json.
# Uso: python3 Tools/build_pisa.py
#
# Fonti (letture del 24–25/10/2026):
# - Orari, settori e deroghe: ordinanza n. 486 Dir. 22 del 22/12/2010 «disciplina per l'accesso e la sosta nelle zone
#   a traffico limitato a partire dal 01/01/2011» (PDF e testo in data/raw/pisa/): divieto «nell'orario 0-24 di tutti
#   i giorni» nei due settori Centro Storico Nord e Centro Storico Sud, con l'elenco delle strade di ciascuno.
#   Dal 1/1/2025 vale l'ord. n. 2386 del 24/10/2024 (stesso titolo, sul sito Pisamo, da qui non raggiungibile):
#   lo 0-24 è confermato da guide recenti non ufficiali, quindi è dichiarato nei «pending».
# - Strutture ricettive: pagine del Comune (API OpenCity, file comune-pisa-content-<id>.json).
# - www.comune.pisa.it è raggiungibile; pisamo.it, mobilita.pisamo.it/.net, varchi.pisamo.it, albopretorio,
#   opendata.comune.pisa.it e Overpass no.
#
# Geometria (mai disegnata a mano): OpenStreetMap non ha il contorno della ZTL di Pisa (la relazione 9342809 ha solo
# le 15 telecamere). Il perimetro di ogni settore è l'area coperta dalle strade dell'elenco ufficiale dell'ord.
# 486/2010 (più via San Ranierino e via Cardinal Maffi, ord. 215/2014), prese con il loro nome dalle geometrie OSM
# di data/raw/geo/pisa-streets.json (blocco «Pisa» in fondo a Tools/fetch_geo.py, da far girare con il workflow
# «Geometrie città») e unite con osm_geo.street_area. Finché quel file manca, o se i controlli di plausibilità
# non passano, Pisa resta in data/drafts/pisa.json.
import html
import json
import math
import re
import unicodedata
from pathlib import Path

import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/pisa"
CHECKED = "2026-10-25T08:00:00Z"
EVERY_DAY = [1, 2, 3, 4, 5, 6, 7]
# 0–24 tutti i giorni: testo ufficiale dell'ord. 486/2010; per il 2025–2026 (ord. 2386/2024, non leggibile da qui)
# confermato da fonti non ufficiali recenti. Vedi docs/fonti-pisa.md.
HOURS_OFFICIAL = True
OSM_ZTL = 9342809        # relazione OSM «Zona a Traffico Limitato» (enforcement=access, solo varchi)
ORD_URL = "https://www.comune.pisa.it/content/download/9436/249453/1/486_2010.pdf"
ORD_PAGE = "https://www.comune.pisa.it/content/view/full/9958"   # pagina del documento (obj 9436) sul sito del Comune
ORD_2014_URL = "https://www.comune.pisa.it/content/download/11691/344163/1/2014_06_11_12_13_08.pdf"


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


def flat(s):
    return re.sub(r"\s+", " ", s).strip()


def content(object_id):
    """Una pagina del sito del Comune salvata dall'API OpenCity"""
    return json.loads((RAW / f"comune-pisa-content-{object_id}.json").read_text(encoding="utf-8"))


def text(object_id, field):
    v = content(object_id)["data"]["ita-IT"][field]
    v = v if isinstance(v, str) else v.get("content", "")
    return flat(html.unescape(re.sub(r"<[^>]+>", " ", v)))


def must_contain(txt, quote, where):
    if flat(quote) not in txt:
        raise SystemExit(f"Citazione non trovata in {where}: {quote!r}")


# --- Le frasi su cui si basa la scheda, controllate contro i file salvati: se un testo cambia, lo script si ferma ---
ORD = flat((RAW / "ordinanza-486-2010-disciplina-ztl.txt").read_text(encoding="utf-8"))
ORD_2014 = flat((RAW / "ordinanza-215-2014-san-ranierino-maffi-ztl-nord.txt").read_text(encoding="utf-8"))
QUOTE = ("Nelle zone come definite nella prima parte è istituito il divieto di accesso, transito e sosta di tutti "
         "i veicoli, nell’orario 0-24 di tutti i giorni, fatte salve le deroghe espresse ai punti successivi.")
for q in [QUOTE, "ORDINANZA n°486 Direz. 22 del 22 dicembre 2010",
          "Le zone a traffico limitato del centro storico sono organizzate in due settori urbani: Centro Storico Nord e Centro Storico Sud",
          "VEICOLI A TRAZIONE ANIMALE, VELOCIPEDI, CICLOMOTORI, MOTOVEICOLI A DUE RUOTE",
          "Mezzi di abituale utilizzo dei soggetti dotati di contrassegno “Invalidi”",
          "Autoveicoli dei clienti degli alberghi, pensioni e strutture ricettive autorizzate",
          "dalla direzione della struttura stessa"]:
    must_contain(ORD, q, "ord. 486/2010")
must_contain(ORD_2014, "di inserire in zona a traffico limitato Nord la via San Ranierino e la via Cardinal Maffi", "ord. 215/2014")
SERVICE = 3404   # Registrazione Targhe per accesso veicoli in ZTL (servizio, modificato il 03/08/2026)
assert "Solo alle strutture ricettive professionali: Alberghi, B&B e similari" in text(SERVICE, "audience")
assert "pagando una tariffa di 12 euro per la durata di 24 ore" in text(5972, "body")
assert "I clienti potranno accedere con il proprio veicolo gratuitamente" in text(5972, "body")
assert "fino a un massimo di 30 minuti" in text(5972, "body")
assert "10 ore di tempo anziché 6" in text(5674, "body")
assert "due ore prima del fischio d’inizio" in text(30326, "body")
assert "area pedonale urbana attiva 24 ore su 24" in text(28250, "body")
assert "veicoli autorizzati ZTL NORD secondo la vigente normativa" in text(18556, "body")
assert "piattaforma CUDE" in text(28529, "body")

# --- Le strade dei due settori, come le scrive l'ord. 486/2010 (ogni voce è controllata nel testo salvato) ---
# Una voce: testo dell'ordinanza, eventualmente con il tratto: ("tra", via A, via B) o ("fino", via B).
NORD = [
    "Via Carmignani", "Piazza San Francesco", "Vicolo del Poschi", "Via degli Orafi", "Via Cavour", "Via Case Dipinte",
    "Via Santa Cecilia", "Via Battichiodi", "Via Calafati", "Via Guido da Pisa", "Via Palestro", "Via Beccaria",
    "Via Fucini", "Piazza S. Paolo all’Orto", "Via Vernaccini", "Via Coccapani", "Via Sant’Andrea", "Piazza D’Ancona",
    ("Via San Francesco (da Via Oberdan a Via Buonarroti)", "tra", "Via Oberdan", "Via Buonarroti"),
    "Vicolo del Ruschi", "Via V. Berlinghieri", "Via delle Belle Torri", "Piazza Cairoli", "Via San Pierino",
    "Via del Teatro", "Via Traversa", "Via della Scuola", "Via del Cuore", "Via della Palla a Corda", "Via San Lorenzo",
    "Via Carducci", "Via E. Sighieri", "via Di Simone (porzione fisicamente delimitata)",
    ("Via M. Lalli (tratto Via Di Simone/Via Sighieri)", "tra", "Via Di Simone", "Via E. Sighieri"),
    "Via G. Giusti", "Via S. Bibbiana", "Via delle Maioliche", "Piazza della Repubblica", "Via Gereschi",
    "Via del Buschetto", "Piazza Martiri della Libertà",
    ("Via Mercanti (da Via Case Dipinte a Piazza S. Paolo all’Orto)", "tra", "Via Case Dipinte", "Piazza S. Paolo all’Orto"),
    "Via Verdi", "Via del Giardino", "Via Toscanelli", "Vicolo Rimediotti", "Piazza San Luca", "Piazza Mazzini",
    "Via del Collegio Ricci", "Via della Sapienza", "Via Serafini", "Via San Simone", "Via Notari", "Via delle Donzelle",
    "Via delle Colonne", "Vicolo del Vigna", "Piazza delle Vettovaglie", "Piazza S.Omobono", "Vicolo del Porton Rosso",
    "Vicolo del Tidi", "Via della Croce Rossa", "Via Cavalca", "Vicolo S. Margherita", "Via Tavoleria",
    "Via del Castelletto", "Via San Frediano", "Via Consoli del Mare", "Via S. Apollonia", "Piazza Giordano da Rivalto",
    "Via San Giuseppe", "Via San Tommaso", "Via Martiri", "Via Capponi", "Via Dalmazia", "Via della Faggiola",
    "Via Leopardi", "Via Don G. Boschi", "Piazza Cavallotti", "Via Risorti", "Via Collegio Ferdinando", "Via Galvani",
    "Piazza Torricelli",
    ("Via Santa Maria (da piazza del Duomo a Via S.Nicola)", "tra", "Piazza del Duomo", "Via S.Nicola"),
    "Piazza del Duomo",
    ("Via Roma (da piazza del Duomo a Via Savi)", "tra", "Piazza del Duomo", "Via Savi"),
    "Via Porta Buozzi", "Via Luca Ghini", "Via della Pergola", "Via Trento", "Via Volta", "Via Santa Lucia",
    "Piazza Locchi", "Via Ricucchi", "Via Buongusto", "Via Canto del Nicchio", "Via Galli Tassi", "Via dei Mille",
    "Piazza Buonamici", "Via Corsica", "Piazza dei Cavalieri", "Via U. Dini", "Piazza San Felice", "Piazza Donati",
    "Via Oberdan", "Via Curtatone e Montanara", "Via del Porton Rosso", "Vicolo delle Donzelle", "Vicolo Margherita",
    "Vicolo Quarantotti", "Via delle 7 Volte", "Via P. Paoli", "Piazza Arcivescovado", "Via Camozzo, già via Corta",
]
NORD_2014 = ["via San Ranierino", "via Cardinal Maffi"]   # ord. 215/2014
# Voci ripetute nell'elenco con un'altra forma (es. «Vicolo S. Margherita» e «Vicolo Margherita»): se non si trovano
# con questo nome non contano come mancanti
REPEATS = {"Vicolo Margherita", "Via del Porton Rosso", "Vicolo delle Donzelle"}
SUD = [
    "Via Mazzini", "Via Garofani", "Via Titta Ruffo", "Piazza dei Grilletti (porzione Lato Sud)", "Via dell’Occhio",
    "Piazza Facchini", "Via Toselli", "Via delle Belle Donne", "Via del Cappello", "Via Sant’Antonio", "Via Alberto Mario",
    "Via San Paolo", "Vicolo del Tozzi", "Vicolo Mecherini", "Vicolo dell’Annunziata", "Via Ricciardi", "Via delle Conce",
    "Via del Lante", "Via San Cosimo", "Via del Borgundio", "Via Somari", "Via La Maddalena", "Via Scardigli",
    "Via San Lorenzino", "Via del Cottolengo", "Via Balduinetti", "Via Porta Dolfi", "Via del Galloro",
    "Via della Qualquonia", "Via Carabottaia", "Via D’Azeglio", "Via Manzoni", "Via Zandonai", "Piazza Saffi",
    "Piazza Toniolo (porzione fisicamente delimitata)", "Via Bovio", "Via di Fortezza", "Via Ceci", "Via Giordano Bruno",
    "Via Sancasciani", "piazza S.Martino", "Via Gori", "Via Turati", "Via del Carmine",
    ("Via San Bernardo (fino a Vicolo dell’Oro)", "fino", "Vicolo dell’Oro"),
    "Via Kinzica de’ Sismondi", "Via San Martino", "Vicolo del Moro", "Via La Foglia", "Vicolo Scaramucci",
    "Vicolo Rosselmini", "Vicolo dell’Oro", "Vicolo Mozzo", "Piazza del Crocifisso", "Via La Tinta", "Via Silvestri",
    "Via Lanfranchi", "Vicolo da Scorno", "Via Flaminio dal Borgo", "Piazza San Sepolcro", "Piazza Maria Clari",
    "Vicolo Mossotti", "Via Franceschi", "Vicolo Borghese", "Piazza C. Gambacorti", "Via La Pera", "Vicolo del Torti",
    "Vicolo degli Albiani", "Via Pascoli", "Corte San Domenico A-B-C-D",
]
for s in NORD + SUD:
    must_contain(ORD, s if isinstance(s, str) else s[0], "ord. 486/2010 (elenco strade)")

# --- Nomi delle strade: dall'ordinanza (abbreviati) ai nomi completi di OpenStreetMap ---
TYPES = {"via", "vicolo", "piazza", "piazzetta", "corte", "largo", "lungarno", "borgo", "viale"}
STOP = {"di", "de", "del", "della", "dei", "delle", "degli", "dello", "d", "da", "dal", "al", "all", "alla", "e",
        "la", "il", "lo", "l", "gia", "corta"}
SAINT = {"s", "san", "santa", "sant", "santo"}
ALIAS = {"7": "sette", "cardinal": "cardinale"}


def tokens(name):
    s = re.sub(r"[’‘'`]", " ", name)                  # apostrofi prima di togliere gli accenti
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode().lower()
    s = re.sub(r"\(.*?\)", " ", s)
    s = re.sub(r"\b[a-d](-[a-d])+\b", " ", s)        # «Corte San Domenico A-B-C-D»
    s = re.sub(r"[’'`.,/\-]", " ", s)
    words = [ALIAS.get(w, w) for w in s.split()]
    if not words or words[0] not in TYPES:
        return None, []
    kind, rest = words[0], words[1:]
    if "gia" in rest:                                  # «Via Camozzo, già via Corta»
        rest = rest[:rest.index("gia")]
    sig = ["s" if w in SAINT else w for w in rest if w not in STOP]
    sig = [w for w in sig if len(w) > 1 or w == "s"]   # iniziali dei nomi propri (U., G., V. …)
    return kind, sig


def same_street(official, osm_name):
    k1, a = tokens(official)
    k2, b = tokens(osm_name)
    if not a or k1 != k2 or not b:
        return False
    names_b = [w for w in b if w != "s"]
    names_a = [w for w in a if w != "s"]
    # «Via Di Simone» non è «Via San Simone»: il santo deve esserci in tutti e due i nomi o in nessuno
    return bool(names_a) and names_a[-1] == names_b[-1] and set(a) <= set(b) and ("s" in a) == ("s" in b)


def street_lines(elements, official):
    """Le linee [(lon, lat)] delle way OSM con lo stesso nome della strada dell'ordinanza"""
    hits = [e for e in elements if e["type"] == "way" and e.get("geometry") and same_street(official, e["tags"]["name"])]
    return [[(n["lon"], n["lat"]) for n in e["geometry"]] for e in hits], sorted({e["tags"]["name"] for e in hits})


def clip(lines, a, b):
    """Il tratto tra i punti a e b (lon, lat): tiene i punti la cui proiezione sul segmento a→b cade tra i due"""
    fwd, _ = osm_geo._proj(a[1])
    (ax, ay), (bx, by) = fwd(*a), fwd(*b)
    dx, dy = bx - ax, by - ay
    L2 = dx * dx + dy * dy or 1.0
    out = []
    for line in lines:
        run = []
        for p in line:
            x, y = fwd(*p)
            t = ((x - ax) * dx + (y - ay) * dy) / L2
            if -0.03 <= t <= 1.03:
                run.append(p)
            else:
                if len(run) >= 2: out.append(run)
                run = []
        if len(run) >= 2: out.append(run)
    return out


def nearest(points, to):
    fwd, _ = osm_geo._proj(to[0][1])
    best = None
    for p in points:
        for q in to:
            d = math.hypot(*(u - v for u, v in zip(fwd(*p), fwd(*q))))
            if best is None or d < best[0]:
                best = (d, p)
    return best[1] if best else None


def sector_lines(elements, entries, warnings):
    """Tutte le linee delle strade di un settore, con i tratti tagliati come nell'ordinanza"""
    plain = [e for e in entries if isinstance(e, str)]
    lines, found = [], {}
    for name in plain:
        ls, osm_names = street_lines(elements, name)
        if not ls and name not in REPEATS:
            warnings.append(name)
        lines += ls
        found[name] = osm_names
    pts = [p for l in lines for p in l]
    centroid = (sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts)) if pts else None
    for e in entries:
        if isinstance(e, str):
            continue
        ls, osm_names = street_lines(elements, e[0])
        found[e[0]] = osm_names
        street_pts = [p for l in ls for p in l]
        if not ls:
            warnings.append(e[0]); continue
        if e[1] == "tra":
            ends = [street_lines(elements, x)[0] for x in e[2:]]
        else:   # «fino a X»: dal capo della strada verso il centro del settore fino a X
            ends = [[[nearest(street_pts, [centroid])]], street_lines(elements, e[2])[0]]
        if not all(ends):
            warnings.append(e[0] + " (tratto)"); continue
        a, b = (nearest([p for l in end for p in l], street_pts) for end in ends)
        a, b = nearest(street_pts, [a]), nearest(street_pts, [b])
        lines += clip(ls, a, b)
    return lines, found


def sector_perimeter(elements, entries, keep):
    warnings = []
    lines, found = sector_lines(elements, entries, warnings)
    lines = [l for l in lines if keep(*l[len(l) // 2])]
    if not lines:
        return [], warnings, found
    rel = {"id": "pisa",
           "members": [{"type": "way", "role": "section", "geometry": [{"lon": p[0], "lat": p[1]} for p in l]} for l in lines]}
    return osm_geo.perimeter(osm_geo.street_area(rel, close_m=60), tol_m=6), warnings, found


def perimeters():
    """{"nord": [...], "sud": [...]} dalle strade OSM, o {} se le geometrie delle strade non sono ancora scaricate"""
    if not (osm_geo.GEO / "pisa-streets.json").exists():
        return {}, ["data/raw/geo/pisa-streets.json mancante: far girare Tools/fetch_geo.py (workflow «Geometrie città»)"]
    elements = [e for e in osm_geo.load("pisa-streets") if e.get("tags", {}).get("name")]
    walls = [(n["lon"], n["lat"]) for e in osm_geo.load("pisa-walls") for n in (e.get("geometry") or [])
             if isinstance(n, dict) and "lat" in n]
    hull = osm_geo.convex_hull(walls)
    keep = (lambda lon, lat: osm_geo.inside_lonlat(hull, lon, lat)) if len(hull) >= 3 else (lambda lon, lat: True)
    out, notes = {}, []
    for key, entries in (("nord", NORD + NORD_2014), ("sud", SUD)):
        ring, missing, found = sector_perimeter(elements, entries, keep)
        print(f"settore {key}: {len(entries) - len(missing)}/{len(entries)} strade trovate in OSM")
        for name, osm_names in found.items():
            if len(osm_names) > 1: print(f"  {name!r} → {osm_names}")
        if missing:
            notes.append(f"{key}: strade non trovate in OSM: " + ", ".join(missing))
            print("  NON TROVATE:", missing)
        # Un elenco troppo incompleto non dà un perimetro credibile
        if ring and len(missing) <= 0.1 * len(entries):
            out[key] = ring
    return out, notes


# --- Controlli di plausibilità del perimetro ---
INSIDE = {"Piazza dei Miracoli": (43.7230, 10.3966, "nord"), "Piazza dei Cavalieri": (43.7193, 10.4006, "nord"),
          "Piazza San Martino": (43.7135, 10.4045, "sud")}
OUTSIDE = {"Pisa Centrale station": (43.7085, 10.3986)}


def plausible(rings):
    problems = []
    if set(rings) != {"nord", "sud"}:
        return ["manca il perimetro di almeno un settore"]
    for name, (lat, lon, key) in INSIDE.items():
        if not osm_geo.contains(rings[key], lat, lon):
            problems.append(f"{name} non è dentro il settore {key}")
    for name, (lat, lon) in OUTSIDE.items():
        if any(osm_geo.contains(r, lat, lon) for r in rings.values()):
            problems.append(f"{name} è dentro la ZTL")
    for key, (lo, hi) in {"nord": (0.6, 2.0), "sud": (0.25, 1.2)}.items():
        a = osm_geo.area_km2(rings[key])
        print(f"area {key}: {a:.2f} km²")
        if not lo <= a <= hi:
            problems.append(f"area del settore {key} poco plausibile: {a:.2f} km²")
    return problems


rings, geo_notes = perimeters()
problems = plausible(rings) if rings else ["nessun perimetro"]
if rings and problems:
    print("Controlli non superati:", problems)

# --- Varchi: le 15 telecamere della relazione OSM, assegnate al settore più vicino ---
gate_nodes = osm_geo.load("pisa-ztl") + [e for e in osm_geo.load("pisa-gates") if e["type"] == "node"]
all_gates = sorted((osm_geo.gate_json("pi", g) for g in osm_geo.gates(gate_nodes, {OSM_ZTL}, name_prefix=None)),
                   key=lambda g: (g["name"], g["id"]))


def gates_for(key):
    if not rings or problems:
        return all_gates if key == "nord" else []
    def dist(g, k):
        r = rings[k]
        lat, lon = g["location"]["lat"], g["location"]["lon"]
        return 0 if osm_geo.contains(r, lat, lon) else osm_geo.distance_m(r, lat, lon)
    return [g for g in all_gates if min(rings, key=lambda k: dist(g, k)) == key]


SERVICE_PAGE = "https://www.comune.pisa.it/Servizi/Registrazione-Targhe-per-accesso-veicoli-in-ZTL"
links = [
    link("City of Pisa: ordinance 486/2010, ZTL rules and street list (PDF)",
         "Comune di Pisa: ordinanza 486/2010, disciplina ZTL ed elenco delle strade (PDF)",
         "Stadt Pisa: Verordnung 486/2010, ZTL-Regeln und Straßenliste (PDF)", ORD_URL),
    link("City of Pisa: ordinance 215/2014, via San Ranierino and via Cardinal Maffi added to ZTL Nord (PDF)",
         "Comune di Pisa: ordinanza 215/2014, via San Ranierino e via Cardinal Maffi nella ZTL Nord (PDF)",
         "Stadt Pisa: Verordnung 215/2014, Via San Ranierino und Via Cardinal Maffi in der ZTL Nord (PDF)", ORD_2014_URL),
    link("City of Pisa: hotels register guests' plates", "Comune di Pisa: registrazione targhe per le strutture ricettive",
         "Stadt Pisa: Kennzeichen-Registrierung durch Unterkünfte", SERVICE_PAGE),
    link("City of Pisa: hotel guests, free access to the hotel, €12 for 24 hours with parking (news, Feb 2023)",
         "Comune di Pisa: clienti delle strutture ricettive, accesso gratuito alla struttura, 12 € per 24 ore con la sosta (comunicato, feb. 2023)",
         "Stadt Pisa: Hotelgäste, freie Zufahrt zur Unterkunft, 12 € für 24 Stunden mit Parken (Mitteilung, Feb. 2023)",
         "https://www.comune.pisa.it/Novita/Comunicati/Turismo-e-mobilita-in-centro-cambia-la-sosta-per-i-clienti-delle-strutture-ricettive"),
    link("City of Pisa: 10 hours to register the plate (news, Feb 2023)",
         "Comune di Pisa: 10 ore per caricare la targa (comunicato, feb. 2023)",
         "Stadt Pisa: 10 Stunden für die Registrierung (Mitteilung, Feb. 2023)",
         "https://www.comune.pisa.it/Novita/Comunicati/Rinviate-al-6-marzo-le-nuove-modalita-di-sosta-e-accesso-alla-Ztl-per-le-strutture-ricettive"),
    link("City of Pisa: CUDE disabled badges accepted at the ZTL gates (news, Mar 2026)",
         "Comune di Pisa: contrassegno CUDE ai varchi della ZTL (comunicato, mar. 2026)",
         "Stadt Pisa: CUDE-Behindertenausweis an den ZTL-Kameras (Mitteilung, März 2026)",
         "https://www.comune.pisa.it/Novita/Comunicati/Contrassegno-unificato-disabili-europeo-CUDE-installata-la-nuova-cartellonistica-ai-varchi-della-ZTL"),
    link("City of Pisa: ZTL Stadio on home match days", "Comune di Pisa: ZTL Stadio nelle partite casalinghe",
         "Stadt Pisa: ZTL Stadio an Heimspieltagen",
         "https://www.comune.pisa.it/Novita/Comunicati/Calcio-con-l-avvio-della-nuova-stagione-torna-attiva-la-ZTL-Stadio-in-occasione-delle-partite-casalinghe-del-Pisa-SC"),
    link("Pisamo: ZTL permits and ordinance 2386/2024", "Pisamo: permessi ZTL e ordinanza 2386/2024",
         "Pisamo: ZTL-Genehmigungen und Verordnung 2386/2024", "https://mobilita.pisamo.it/download-category/ztl/"),
]
if all_gates:
    links.append(link(f"OpenStreetMap: relation {OSM_ZTL} (ZTL cameras, ODbL)", f"OpenStreetMap: relazione {OSM_ZTL} (varchi ZTL, ODbL)",
                      f"OpenStreetMap: Relation {OSM_ZTL} (ZTL-Kameras, ODbL)", osm_geo.osm_url("relation", OSM_ZTL)))

pending = [
    ("Hours: ordinance 486/2010 says 0–24 every day. Since 1 January 2025 the rules are in ordinance 2386/2024, published only on the Pisamo site, which we could not open; "
     "0–24 every day is confirmed only by recent unofficial guides (viviamopisa.it, 2026).",
     "Orari: l'ordinanza 486/2010 dice 0–24 tutti i giorni. Dal 1° gennaio 2025 la disciplina è nell'ordinanza 2386/2024, pubblicata solo sul sito Pisamo, che non siamo riusciti ad aprire; "
     "lo 0–24 tutti i giorni è confermato solo da guide recenti non ufficiali (viviamopisa.it, 2026).",
     "Zeiten: Die Verordnung 486/2010 nennt 0–24 Uhr, täglich. Seit 1. Januar 2025 gilt die Verordnung 2386/2024, nur auf der Pisamo-Website veröffentlicht, die wir nicht öffnen konnten; "
     "0–24 Uhr täglich bestätigen nur neuere inoffizielle Reiseführer (viviamopisa.it, 2026)."),
    ("Perimeter: drawn around the streets that ordinance 486/2010 lists for each sector (plus via San Ranierino and via Cardinal Maffi, 2014), using their OpenStreetMap geometry. "
     "The edge is approximate; streets added or removed after 2014 may be missing.",
     "Perimetro: tracciato attorno alle strade che l'ordinanza 486/2010 elenca per ciascun settore (più via San Ranierino e via Cardinal Maffi, 2014), con la geometria di OpenStreetMap. "
     "Il bordo è approssimato; strade aggiunte o tolte dopo il 2014 possono mancare.",
     "Grenze: um die Straßen gezogen, die die Verordnung 486/2010 je Sektor aufzählt (plus Via San Ranierino und Via Cardinal Maffi, 2014), mit der Geometrie aus OpenStreetMap. "
     "Der Rand ist ungefähr; nach 2014 hinzugefügte oder entfernte Straßen können fehlen."),
    ("Hotel guests: if the hotel is inside the ZTL, access to reach it is free; the hotel enters plate and arrival time on the portal within 10 hours (2023 rules), and you may stop 30 minutes to unload. "
     "To also park on blue lines and in the ZTL, accommodation in Pisa can sell a €12, 24-hour permit (one per room). Figures from 2023; Pisamo's site (seen only in search results) still shows €12 for 24 hours under ordinance 2386/2024.",
     "Ospiti delle strutture ricettive: se la struttura è dentro la ZTL, l'accesso per raggiungerla è gratuito; la struttura inserisce targa e ora di arrivo sul portale entro 10 ore (regole 2023), e si può sostare 30 minuti per scaricare. "
     "Per sostare anche sulle strisce blu e in ZTL, le strutture di Pisa possono rilasciare un permesso da 12 € per 24 ore (uno per camera). Dati del 2023; il sito Pisamo (visto solo nei risultati di ricerca) indica ancora 12 € per 24 ore con l'ordinanza 2386/2024.",
     "Hotelgäste: Liegt die Unterkunft in der ZTL, ist die Zufahrt dorthin frei; die Unterkunft trägt Kennzeichen und Ankunftszeit binnen 10 Stunden im Portal ein (Regeln von 2023), Halten zum Ausladen 30 Minuten. "
     "Zum Parken auch auf blauen Linien und in der ZTL können Unterkünfte in Pisa eine Genehmigung für 12 € / 24 Stunden ausstellen (eine pro Zimmer). Angaben von 2023; die Pisamo-Website (nur in Suchergebnissen gesehen) nennt weiter 12 € für 24 Stunden nach Verordnung 2386/2024."),
    ("Only professional accommodation (hotels, B&Bs and similar) can register plates; holiday flats are not mentioned.",
     "Solo le strutture ricettive professionali (alberghi, B&B e similari) possono registrare le targhe; gli affitti brevi non sono citati.",
     "Nur gewerbliche Unterkünfte (Hotels, B&Bs u. ä.) können Kennzeichen registrieren; Ferienwohnungen werden nicht erwähnt."),
    ("No day ticket for tourists. Mopeds and two-wheel motorcycles may enter freely (ordinance 486/2010). Disabled badge holders registered on the national CUDE platform may enter without notice.",
     "Nessun permesso giornaliero per turisti. Ciclomotori e moto a due ruote entrano liberamente (ordinanza 486/2010). I titolari di contrassegno disabili iscritti alla piattaforma nazionale CUDE entrano senza comunicazione.",
     "Kein Tagesticket für Touristen. Mopeds und zweirädrige Motorräder dürfen frei einfahren (Verordnung 486/2010). Inhaber eines Behindertenausweises, die in der nationalen CUDE-Plattform eingetragen sind, fahren ohne Meldung ein."),
    ("Electric cars: no general exemption; a 2010 ordinance let them in for 2011 only, after registration.",
     "Auto elettriche: nessuna esenzione generale; un'ordinanza del 2010 le ammetteva solo per il 2011, previa iscrizione.",
     "Elektroautos: keine allgemeine Ausnahme; eine Verordnung von 2010 ließ sie nur 2011 nach Registrierung zu."),
    ("Gates: camera positions from OpenStreetMap (15, like the 15 gates listed in 2010), to be checked against the official list; two gates were moved in 2014 (via Camozzo → via San Ranierino, via Carducci → via San Lorenzo).",
     "Varchi: posizioni delle telecamere da OpenStreetMap (15, come i 15 varchi elencati nel 2010), da verificare con l'elenco ufficiale; due varchi sono stati spostati nel 2014 (via Camozzo → via San Ranierino, via Carducci → via San Lorenzo).",
     "Kameras: Standorte aus OpenStreetMap (15, wie die 15 im Jahr 2010 aufgeführten), mit der offiziellen Liste abzugleichen; zwei wurden 2014 verlegt (Via Camozzo → Via San Ranierino, Via Carducci → Via San Lorenzo)."),
    ("Not shown: the ZTL Stadio at Porta a Lucca (home matches of Pisa SC, from 2 hours before kick-off to the end of the first half), "
     "the weekend night ZTL on the Lungarni (Fri–Sun 10 pm–5 am, last extended by the city to January 2023; current status unknown) and the pedestrian areas inside the ZTL (via Corsica and piazza Buonamici, via Santa Maria).",
     "Non mostrate: la ZTL Stadio a Porta a Lucca (partite casalinghe del Pisa SC, da due ore prima del fischio d'inizio al termine del primo tempo), "
     "la ZTL notturna dei Lungarni nel fine settimana (ven–dom 22–5, prorogata dal Comune fino a gennaio 2023; stato attuale ignoto) e le aree pedonali dentro la ZTL (via Corsica e piazza Buonamici, via Santa Maria).",
     "Nicht angezeigt: die ZTL Stadio in Porta a Lucca (Heimspiele von Pisa SC, ab 2 Stunden vor Anpfiff bis Ende der ersten Halbzeit), "
     "die Wochenend-Nacht-ZTL an den Lungarni (Fr–So 22–5 Uhr, zuletzt bis Januar 2023 verlängert; aktueller Stand unbekannt) und die Fußgängerzonen in der ZTL (Via Corsica / Piazza Buonamici, Via Santa Maria)."),
]
if not rings or problems:
    pending[1] = ("Perimeter: not drawn yet. OpenStreetMap has the ZTL cameras but no outline; the outline will be built from the official street list of ordinance 486/2010.",
                  "Perimetro: non ancora disegnato. OpenStreetMap ha le telecamere della ZTL ma non il contorno; il contorno sarà ricavato dall'elenco ufficiale delle strade dell'ordinanza 486/2010.",
                  "Grenze: noch nicht gezeichnet. OpenStreetMap hat die ZTL-Kameras, aber keinen Umriss; er wird aus der amtlichen Straßenliste der Verordnung 486/2010 erstellt.")

TRANSLATION = ("In the zones defined in part one, access, transit and parking are forbidden to all vehicles, 0–24 every day, except for the exemptions in the following points.",
               "In den im ersten Teil festgelegten Zonen sind Zufahrt, Durchfahrt und Parken für alle Fahrzeuge verboten, 0–24 Uhr an allen Tagen, vorbehaltlich der folgenden Ausnahmen.")
SUMMARY = ("Closed to unauthorised cars 24 hours a day, every day, holidays included. There is no day ticket for tourists. Mopeds and motorcycles may enter. "
           "If you sleep in a hotel or B&B inside the ZTL, it can register your plate so you can drive there.",
           "Chiusa alle auto non autorizzate 24 ore su 24, tutti i giorni, festivi compresi. Non c'è un ticket giornaliero per i turisti. Ciclomotori e moto possono entrare. "
           "Se dormi in un hotel o B&B dentro la ZTL, la struttura può registrare la tua targa per arrivarci.",
           "Rund um die Uhr, täglich und auch an Feiertagen für nicht berechtigte Autos gesperrt. Es gibt kein Tagesticket für Touristen. Mopeds und Motorräder dürfen einfahren. "
           "Übernachtest du in einem Hotel oder B&B in der ZTL, kann es dein Kennzeichen registrieren, damit du hinfahren darfst.")


def zone(key, en, it, de, where_en, where_it, where_de):
    return {
        "id": f"pisa-ztl-{key}", "name": f"{en}", "name_it": f"{it}", "name_de": f"{de}",
        "kind": "restricted",
        "summary": f"{where_en} {SUMMARY[0]}", "summary_it": f"{where_it} {SUMMARY[1]}", "summary_de": f"{where_de} {SUMMARY[2]}",
        "perimeter": rings.get(key, []) if not problems else [], "gates": gates_for(key),
        "windows": [{"weekdays": EVERY_DAY, "start": 0, "end": 24 * 60}],
        "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": True,
        "source": {"authority": "City of Pisa", "pageURL": ORD_PAGE,
                   "ordinance": "Ordinanza n. 486 Dir. 22 del 22/12/2010 (disciplina ZTL dal 01/01/2011)", "ordinanceURL": ORD_URL,
                   "quote": QUOTE, "quoteTranslation": TRANSLATION[0], "quoteTranslation_de": TRANSLATION[1],
                   "checkedOn": CHECKED, "reviewedByHuman": False,
                   "pending": [p[0] for p in pending], "pending_it": [p[1] for p in pending], "pending_de": [p[2] for p in pending],
                   "links": links},
    }


zones = [
    zone("nord", "ZTL Nord · Historic Centre north of the Arno", "ZTL Nord · Centro storico a nord dell'Arno",
         "ZTL Nord · Altstadt nördlich des Arno",
         "The north sector of Pisa's ZTL: Piazza dei Miracoli, Piazza dei Cavalieri and the streets around them.",
         "Il settore nord della ZTL di Pisa: piazza dei Miracoli, piazza dei Cavalieri e le strade intorno.",
         "Der Nordsektor der ZTL von Pisa: Piazza dei Miracoli, Piazza dei Cavalieri und die Straßen ringsum."),
    zone("sud", "ZTL Sud · Historic Centre south of the Arno", "ZTL Sud · Centro storico a sud dell'Arno",
         "ZTL Sud · Altstadt südlich des Arno",
         "The south sector of Pisa's ZTL: the San Martino and Sant'Antonio quarters (the riverside Lungarni are outside).",
         "Il settore sud della ZTL di Pisa: i quartieri di San Martino e Sant'Antonio (i Lungarni sono fuori).",
         "Der Südsektor der ZTL von Pisa: die Viertel San Martino und Sant'Antonio (die Lungarni am Fluss liegen außerhalb)."),
]

city = {"id": "pisa", "name": "Pisa", "name_it": "Pisa", "name_de": "Pisa",
        "center": {"lat": 43.7167, "lon": 10.4017}, "zones": zones, "status": "draft",
        "license": "Rules: Comune di Pisa official pages and ordinances. Perimeters (from the official street list) and gates: "
                   + osm_geo.ODBL + " (approximate, not official)"}

# In app solo con orari verificati e il perimetro di entrambi i settori, superati i controlli; altrimenti bozza
ready = HOURS_OFFICIAL and not problems and all(len(z["perimeter"]) >= 4 for z in zones)
out = ROOT / ("Resources/Cities/pisa.json" if ready else "data/drafts/pisa.json")
(ROOT / ("data/drafts/pisa.json" if ready else "Resources/Cities/pisa.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
for n in geo_notes + ([] if ready else problems):
    print("nota:", n)
print(out.relative_to(ROOT), [(z["id"], len(z["perimeter"]), len(z["gates"])) for z in zones])
