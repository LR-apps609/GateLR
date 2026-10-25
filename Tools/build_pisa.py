#!/usr/bin/env python3
# Costruisce Resources/Cities/pisa.json dalle fonti ufficiali salvate in data/raw/pisa/ (vedi docs/fonti-pisa.md).
# Non ricostruisce le altre città e non tocca manifest.json.
# Uso: python3 Tools/build_pisa.py
#
# Fonti (letture del 24–25/10/2026):
# - Orari, settori e deroghe: ordinanza Dir. 12 n. 2386 del 24/10/2024 «Disciplina per l'accesso e la sosta nelle zone
#   a traffico limitato a partire dal 01/01/2025» (PDF e testo in data/raw/pisa/, scaricati da mobilita.pisamo.it):
#   divieto «nell'orario 0-24 di tutti i giorni» nei due settori Centro Storico Nord e Centro Storico Sud, con
#   l'elenco delle strade e dei varchi di ciascuno. Revoca l'ord. 486/2010 e la 215/2014. Modificata dalle ord.
#   2719/2024 (piazza San Giorgio nella ZTL Nord), 2847/2024 (medici) e 406/2025 (varchi Santo Sepolcro e Cairoli).
# - ZTL dei Lungarni: ordinanza Dir. 12 n. 2845 del 23/12/2024, permanente dal 01/01/2025, ven–sab–dom 22–5.
# - Strutture ricettive: ord. 2386/2024 cap. 5.1, tariffe 2025 (allegato B, Pisamo) e pagine del Comune (API
#   OpenCity, file comune-pisa-content-<id>.json).
# - www.comune.pisa.it e mobilita.pisamo.it sono raggiungibili; pisamo.it, albopretorio e Overpass no (25/10/2026).
#
# Geometria (mai disegnata a mano): OpenStreetMap non ha il contorno della ZTL di Pisa (la relazione 9342809 ha solo
# le 15 telecamere). Il perimetro di ogni settore è l'area coperta dalle strade dell'elenco ufficiale dell'ord.
# 2386/2024 (più piazza San Giorgio, ord. 2719/2024), prese con il loro nome dalle geometrie OSM
# di data/raw/geo/pisa-streets.json (blocco «Pisa» in fondo a Tools/fetch_geo.py, da far girare con il workflow
# «Geometrie città») e unite con osm_geo.street_area; lo stesso per le strade della ZTL dei Lungarni (ord. 2845/2024).
# Finché quel file manca, o se i controlli di plausibilità non passano, Pisa resta in data/drafts/pisa.json.
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
FRI_SAT_SUN = [6, 7, 1]   # 1 = domenica … 7 = sabato
# 0–24 tutti i giorni: testo ufficiale dell'ord. 2386/2024, in vigore dal 01/01/2025. Vedi docs/fonti-pisa.md.
HOURS_OFFICIAL = True
OSM_ZTL = 9342809        # relazione OSM «Zona a Traffico Limitato» (enforcement=access, solo varchi)
PISAMO = "https://mobilita.pisamo.it/download/"
ORD_URL = PISAMO + "ordinanza-n-2386-del-24-ottobre-2024-disciplina-per-laccesso-e-la-sosta-nelle-zone-a-traffico-limitato-a-partire-dal-1-gennaio-2025/"
ORD_2719_URL = PISAMO + "ordinanza-n-02719-del-5-dicembre-2024/"
ORD_406_URL = PISAMO + "ztl-istituzione-di-due-nuovi-varchi-elettronici-per-la-ztl-in-piazza-santo-sepolcro-e-in-piazza-cairoli/"
LUNGARNI_URL = PISAMO + "ztl-lungarni-regolamentazione-della-zona-a-traffico-limitato-dei-lungarni-dal-01-gennaio-2025/"
TARIFFE_URL = PISAMO + "tariffe-diritti-ed-altre-entrate-extra-tributarie-allegato-b-parcheggi-accesso-z-t-l-mobilita/"
ORD_PAGE = "https://mobilita.pisamo.it/download-category/ztl/"   # elenco delle ordinanze ZTL sul sito Pisamo


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
def raw(name):
    return flat((RAW / name).read_text(encoding="utf-8"))


ORD = raw("ordinanza-2386-2024-disciplina-ztl-2025.txt")
ORD_2719 = raw("ordinanza-2719-2024-modifiche-2386.txt")
ORD_406 = raw("ordinanza-406-2025-varchi-santo-sepolcro-cairoli.txt")
LUNG = raw("ordinanza-2845-2024-ztl-lungarni.txt")
TARIFFE = raw("pisamo-tariffe-allegato-b-2025.txt")
QUOTE = ("Nelle zone come definite nella prima parte è istituito il divieto di accesso, transito e sosta di tutti "
         "i veicoli, nell’orario 0-24 di tutti i giorni, fatte salve le deroghe espresse ai punti successivi.")
for q in [QUOTE, "N. Atto 2386 del 24/10/2024", "La presente ordinanza entra in vigore dal 01/01/2025",
          "Di revocare l’ordinanza n. 486 Dir.22 del 22 dicembre 2010",
          "Le zone a traffico limitato del centro storico sono organizzate in due settori urbani: Centro Storico Nord e Centro Storico Sud",
          "VEICOLI A TRAZIONE ANIMALE, VELOCIPEDI, CICLOMOTORI, QUADRICICLI LEGGERI E MOTOCICLI",
          "L’iscrizione dell’autoveicolo alla Piattaforma nazionale CUDE garantisce l’inscrizione automatica alla lista bianca.",
          "AUTOVEICOLI DI CLIENTI DI STRUTTURE RICETTIVE PROFESSIONALI (ALBERGHI, PENSIONI, B & B, ETC.) CHE SI TROVINO ALL’INTERNO DELLA Z.T.L.",
          "L’inserimento della targa in lista bianca T dovrà avvenire, a cura della struttura ricettiva interessata, entro 10 (dieci) ore dall’ingresso del veicolo del cliente in Z.T.L.",
          "la sosta su di essi è consentita fino ad un massimo di 30 (trenta) minuti",
          "La registrazione delle targhe sul portale potrà avere una durata massima di 3 (tre) giorni rinnovabili",
          "Il numero massimo dei permessi temporanei rilasciabili da parte di ciascuna struttura è pari al numero delle camere della struttura stessa.",
          "autorizzazione al transito in ZTL dei veicoli elettrici"]:
    must_contain(ORD, q, "ord. 2386/2024")
must_contain(ORD_2719, "L’INSERIMENTO DI PIAZZA SAN GIORGIO NELL’ELENCO DELLE VIE O PIAZZE DEL SETTORE DEL CENTRO STORICO NORD (ZTL NORD).", "ord. 2719/2024")
must_contain(ORD_406, "L’ISTITUZIONE DI DUE NUOVI VARCHI ELETTRONICI PER LA ZTL IN PIAZZA SANTO SEPOLCRO E IN PIAZZA CAIROLI", "ord. 406/2025")
QUOTE_LUNG = ("A far data dal 01 Gennaio 2025 nei giorni di Venerdì, Sabato e Domenica, è istituita, dalle ore 22.00 alle "
              "ore 5.00 del giorno successivo, la Zona a Traffico Limitato nelle seguenti strade:")
for q in [QUOTE_LUNG, "N. Atto 2845 del 23/12/2024", "RITENUTO di rendere permanente il provvedimento",
          "i permessi di transito e sosta, già rilasciati per le ZTL Nord e Sud, siano automaticamente validi, con le stesse modalità, anche all’interno della ZTL dei Lungarni.",
          "I permessi temporanei per la ZTL Nord o Sud sono validi anche per la ZTL dei Lungarni se attiva",
          "i veicoli che alle 22:00 si trovino in sosta all’interno della ZTL dei Lungarni possano prolungare la sosta"]:
    must_contain(LUNG, q, "ord. 2845/2024")
for q in ["ABBONAMENTI PER STRUTTURE RICETTIVE PROFESSIONALI IN ZTL", "cap.lo 5 punto 5.1 ordinanza n. 2386",
          "12,00 (validità 24 ore) Sosta nella Z.T.L (esclusi gli stalli riservati ai residenti), Z.S.C e LITORALE"]:
    must_contain(TARIFFE, q, "tariffe Pisamo, allegato B")
SERVICE = 3404   # Registrazione Targhe per accesso veicoli in ZTL (servizio, modificato il 03/08/2026)
assert "Solo alle strutture ricettive professionali: Alberghi, B&B e similari" in text(SERVICE, "audience")
assert "I clienti potranno accedere con il proprio veicolo gratuitamente" in text(5972, "body")
assert "due ore prima del fischio d’inizio" in text(30326, "body")
assert "area pedonale urbana attiva 24 ore su 24" in text(28250, "body")
assert "piattaforma CUDE" in text(28529, "body")

# --- Le strade dei due settori, come le scrive l'ord. 2386/2024 (ogni voce è controllata nel testo salvato) ---
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
    "Via Verdi", "Via del Giardino", "Via Toscanelli", "Vicolo Rimediotti", "Piazza San Luca", "Via Sant’Orsola", "Via Rigattieri", "Vicolo del Tinti",
    "Vicolo Roncioni", "Via Vernagalli", "Largo Ciro Menotti", "Piazza del Pozzetto", "Via San Iacopino",
    "Via del Collegio Ricci", "Via della Sapienza", "Via Serafini", "Via San Simone", "Via Notari", "Via delle Donzelle",
    "Via delle Colonne", "Vicolo del Vigna", "Piazza delle Vettovaglie", "Piazza S.Omobono", "Vicolo del Porton Rosso",
    "Vicolo del Tidi", "Via della Croce Rossa", "Via Cavalca", "Vicolo S. Margherita", "Via Tavoleria",
    "Via del Castelletto", "Piazza San Frediano", "Via San Frediano", "Via Consoli del Mare", "Via S. Apollonia", "Piazza Giordano da Rivalto",
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
    "Vicolo Quarantotti", "Via delle sette Volte", "Via P. Paoli", "Piazza Arcivescovado", "Via Camozzo, già via Corta",
    "Via San Ranierino", "Via Cardinale Maffi",
]
NORD_2719 = ["Piazza San Giorgio"]   # aggiunta dall'ord. 2719/2024
# Voci ripetute nell'elenco con un'altra forma (es. «Vicolo S. Margherita» e «Vicolo Margherita»): se non si trovano
# con questo nome non contano come mancanti
REPEATS = {"Vicolo Margherita", "Via del Porton Rosso", "Vicolo delle Donzelle"}
SUD = [
    "Via Mazzini", "Via Garofani", "Via Titta Ruffo", "Piazza dei Grilletti (porzione Lato Sud)", "Via dell’Occhio",
    "Piazza Facchini", "Via Toselli", "Via delle Belle Donne", "Via del Cappello", "Via Sant’Antonio", "Via Alberto Mario",
    "Via San Paolo", "Vicolo del Torzi", "Vicolo Mecherini", "Vicolo dell’Annunziata", "Via Ricciardi", "Via delle Conce",
    "Via del Lante", "Via San Cosimo", "Via del Borgundio", "Via Somari", "Via La Maddalena", "Via Scardigli",
    "Via San Lorenzino", "Via del Cottolengo", "Via Balduinetti", "Via Porta Dolfi", "Via del Galloro",
    "Via della Qualquonia", "Via Carabottaia", "Via D’Azeglio", "Via Manzoni", "Via Zandonai",
    "Piazza Toniolo (porzione fisicamente delimitata)", "Via Bovio", "Via di Fortezza", "Via Ceci", "Via Giordano Bruno", "Via la Nunziatina",
    "Via Sancasciani", "piazza S.Martino", "Via Gori", "Via Turati", "Via del Carmine",
    ("Via San Bernardo (fino a Vicolo dell’Oro)", "fino", "Vicolo dell’Oro"),
    "Via Kinzica de’ Sismondi", "Via San Martino", "Vicolo del Moro", "Via La Foglia", "Vicolo Scaramucci",
    "Vicolo Rosselmini", "Vicolo dell’Oro", "Vicolo Mozzo", "Piazza del Crocifisso", "Via La Tinta", "Via Silvestri",
    "Via Lanfranchi", "Vicolo da Scorno", "Via Flaminio dal Borgo", "Piazza San Sepolcro", "Piazza Maria Clari",
    "Vicolo Mossotti", "Via Franceschi", "Vicolo Borghese", "Piazza C. Gambacorti", "Via La Pera", "Vicolo del Torti",
    "Vicolo degli Albiani", "Via Pascoli", "Corte San Domenico A-B-C-D",
]
for s in NORD + SUD:
    must_contain(ORD, s if isinstance(s, str) else s[0], "ord. 2386/2024 (elenco strade)")
for s in NORD_2719:
    must_contain(ORD_2719.upper(), s.upper(), "ord. 2719/2024")
# ZTL dei Lungarni (ord. 2845/2024, punto 1)
LUNGARNI = ["Lungarno Pacinotti", "Piazza Carrara", "Via San Nicola",
            ("Via Santa Maria (tratto compreso tra Via San Nicola e Lungarno Pacinotti)", "tra", "Via San Nicola", "Lungarno Pacinotti"),
            "Lungarno Mediceo", "Piazza Mazzini", "Lungarno Galileo Galilei", "Lungarno Gambacorti", "Ponte di Mezzo"]
for s in LUNGARNI:
    must_contain(LUNG, s if isinstance(s, str) else s[0], "ord. 2845/2024 (elenco strade)")

# --- Nomi delle strade: dall'ordinanza (abbreviati) ai nomi completi di OpenStreetMap ---
TYPES = {"via", "vicolo", "piazza", "piazzetta", "corte", "largo", "lungarno", "borgo", "viale", "ponte"}
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
    for key, entries in (("nord", NORD + NORD_2719), ("sud", SUD), ("lungarni", LUNGARNI)):
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
    if not {"nord", "sud"} <= set(rings):
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
# ZTL dei Lungarni: una striscia lungo l'Arno, con un controllo a parte (non blocca i due settori)
LUNG_OK = False
if "lungarni" in rings:
    a = osm_geo.area_km2(rings["lungarni"])
    print(f"area lungarni: {a:.2f} km²")
    LUNG_OK = 0.02 <= a <= 0.5
    if not LUNG_OK:
        print(f"nota: area della ZTL dei Lungarni poco plausibile ({a:.2f} km²): zona senza perimetro")

# --- Varchi: le 15 telecamere della relazione OSM, assegnate al settore più vicino ---
gate_nodes = osm_geo.load("pisa-ztl") + [e for e in osm_geo.load("pisa-gates") if e["type"] == "node"]
all_gates = sorted((osm_geo.gate_json("pi", g) for g in osm_geo.gates(gate_nodes, {OSM_ZTL}, name_prefix=None)),
                   key=lambda g: (g["name"], g["id"]))


def gates_for(key):
    if not rings or problems:
        return all_gates if key == "nord" else []
    if key == "lungarni":
        return []   # le 15 telecamere di OSM sono quelle dei settori Nord e Sud
    def dist(g, k):
        r = rings[k]
        lat, lon = g["location"]["lat"], g["location"]["lon"]
        return 0 if osm_geo.contains(r, lat, lon) else osm_geo.distance_m(r, lat, lon)
    return [g for g in all_gates if min(("nord", "sud"), key=lambda k: dist(g, k)) == key]


SERVICE_PAGE = "https://www.comune.pisa.it/Servizi/Registrazione-Targhe-per-accesso-veicoli-in-ZTL"
links = [
    link("Pisamo: ordinance 2386/2024, ZTL rules and street list from 1 January 2025 (PDF)",
         "Pisamo: ordinanza 2386/2024, disciplina ZTL ed elenco delle strade dal 1° gennaio 2025 (PDF)",
         "Pisamo: Verordnung 2386/2024, ZTL-Regeln und Straßenliste ab 1. Januar 2025 (PDF)", ORD_URL),
    link("Pisamo: ordinance 2719/2024, changes (piazza San Giorgio added to ZTL Nord)",
         "Pisamo: ordinanza 2719/2024, modifiche (piazza San Giorgio nella ZTL Nord)",
         "Pisamo: Verordnung 2719/2024, Änderungen (Piazza San Giorgio in der ZTL Nord)", ORD_2719_URL),
    link("Pisamo: ordinance 406/2025, new gates in piazza Santo Sepolcro and piazza Cairoli",
         "Pisamo: ordinanza 406/2025, nuovi varchi in piazza Santo Sepolcro e piazza Cairoli",
         "Pisamo: Verordnung 406/2025, neue Kameras an Piazza Santo Sepolcro und Piazza Cairoli", ORD_406_URL),
    link("Pisamo: ordinance 2845/2024, night ZTL on the Lungarni (Fri–Sun 10 pm–5 am)",
         "Pisamo: ordinanza 2845/2024, ZTL notturna dei Lungarni (ven–dom 22–5)",
         "Pisamo: Verordnung 2845/2024, Nacht-ZTL an den Lungarni (Fr–So 22–5 Uhr)", LUNGARNI_URL),
    link("Pisamo: 2025 fees, hotel guests' parking permit €12 for 24 hours (annex B)",
         "Pisamo: tariffe 2025, permesso di sosta per i clienti delle strutture ricettive 12 € per 24 ore (allegato B)",
         "Pisamo: Tarife 2025, Parkgenehmigung für Hotelgäste 12 € für 24 Stunden (Anlage B)", TARIFFE_URL),
    link("City of Pisa: hotels register guests' plates", "Comune di Pisa: registrazione targhe per le strutture ricettive",
         "Stadt Pisa: Kennzeichen-Registrierung durch Unterkünfte", SERVICE_PAGE),
    link("City of Pisa: hotel guests, free access to the hotel (news, Feb 2023)",
         "Comune di Pisa: clienti delle strutture ricettive, accesso gratuito alla struttura (comunicato, feb. 2023)",
         "Stadt Pisa: Hotelgäste, freie Zufahrt zur Unterkunft (Mitteilung, Feb. 2023)",
         "https://www.comune.pisa.it/Novita/Comunicati/Turismo-e-mobilita-in-centro-cambia-la-sosta-per-i-clienti-delle-strutture-ricettive"),
    link("City of Pisa: CUDE disabled badges accepted at the ZTL gates (news, Mar 2026)",
         "Comune di Pisa: contrassegno CUDE ai varchi della ZTL (comunicato, mar. 2026)",
         "Stadt Pisa: CUDE-Behindertenausweis an den ZTL-Kameras (Mitteilung, März 2026)",
         "https://www.comune.pisa.it/Novita/Comunicati/Contrassegno-unificato-disabili-europeo-CUDE-installata-la-nuova-cartellonistica-ai-varchi-della-ZTL"),
    link("City of Pisa: ZTL Stadio on home match days", "Comune di Pisa: ZTL Stadio nelle partite casalinghe",
         "Stadt Pisa: ZTL Stadio an Heimspieltagen",
         "https://www.comune.pisa.it/Novita/Comunicati/Calcio-con-l-avvio-della-nuova-stagione-torna-attiva-la-ZTL-Stadio-in-occasione-delle-partite-casalinghe-del-Pisa-SC"),
]
if all_gates:
    links.append(link(f"OpenStreetMap: relation {OSM_ZTL} (ZTL cameras, ODbL)", f"OpenStreetMap: relazione {OSM_ZTL} (varchi ZTL, ODbL)",
                      f"OpenStreetMap: Relation {OSM_ZTL} (ZTL-Kameras, ODbL)", osm_geo.osm_url("relation", OSM_ZTL)))

P_PERIMETER = ("Perimeter: drawn around the streets that ordinance 2386/2024 lists for each sector (plus piazza San Giorgio, ordinance 2719/2024), using their OpenStreetMap geometry. "
               "The edge is approximate.",
               "Perimetro: tracciato attorno alle strade che l'ordinanza 2386/2024 elenca per ciascun settore (più piazza San Giorgio, ordinanza 2719/2024), con la geometria di OpenStreetMap. "
               "Il bordo è approssimato.",
               "Grenze: um die Straßen gezogen, die die Verordnung 2386/2024 je Sektor aufzählt (plus Piazza San Giorgio, Verordnung 2719/2024), mit der Geometrie aus OpenStreetMap. "
               "Der Rand ist ungefähr.")
P_NO_PERIMETER = ("Perimeter: not drawn yet. OpenStreetMap has the ZTL cameras but no outline; the outline will be built from the official street list of ordinance 2386/2024.",
                  "Perimetro: non ancora disegnato. OpenStreetMap ha le telecamere della ZTL ma non il contorno; il contorno sarà ricavato dall'elenco ufficiale delle strade dell'ordinanza 2386/2024.",
                  "Grenze: noch nicht gezeichnet. OpenStreetMap hat die ZTL-Kameras, aber keinen Umriss; er wird aus der amtlichen Straßenliste der Verordnung 2386/2024 erstellt.")
pending = [
    P_PERIMETER if rings and not problems else P_NO_PERIMETER,
    ("Hotel guests: if the hotel is inside the ZTL, it enters your plate and arrival time on the portal within 10 hours of your entry (ordinance 2386/2024, 5.1), for up to 3 days at a time, renewable; "
     "you may stop up to 30 minutes in the hotel's luggage bays. The city's 2023 notice says access to reach the hotel is free. To also park in the ZTL (not in residents' bays) and on blue lines, "
     "the hotel can sell a €12, 24-hour permit (2025 fees, one per room).",
     "Ospiti delle strutture ricettive: se la struttura è dentro la ZTL, inserisce sul portale targa e ora di arrivo entro 10 ore dal tuo ingresso (ordinanza 2386/2024, punto 5.1), per al massimo 3 giorni rinnovabili; "
     "puoi sostare fino a 30 minuti negli stalli per il carico/scarico bagagli. Il comunicato del Comune del 2023 dice che l'accesso per raggiungere la struttura è gratuito. Per sostare anche in ZTL (non negli stalli dei residenti) e sulle strisce blu, "
     "la struttura può rilasciare un permesso da 12 € per 24 ore (tariffe 2025, uno per camera).",
     "Hotelgäste: Liegt die Unterkunft in der ZTL, trägt sie Kennzeichen und Ankunftszeit binnen 10 Stunden nach deiner Einfahrt im Portal ein (Verordnung 2386/2024, Punkt 5.1), jeweils bis zu 3 Tage, verlängerbar; "
     "Halten bis 30 Minuten auf den Gepäck-Ladeplätzen. Laut Mitteilung der Stadt von 2023 ist die Zufahrt zur Unterkunft frei. Zum Parken auch in der ZTL (nicht auf Anwohnerplätzen) und auf blauen Linien "
     "kann die Unterkunft eine Genehmigung für 12 € / 24 Stunden ausstellen (Tarife 2025, eine pro Zimmer)."),
    ("Only professional accommodation (hotels, guesthouses, B&Bs and similar) can register plates; holiday flats are not mentioned.",
     "Solo le strutture ricettive professionali (alberghi, pensioni, B&B e similari) possono registrare le targhe; gli affitti brevi non sono citati.",
     "Nur gewerbliche Unterkünfte (Hotels, Pensionen, B&Bs u. ä.) können Kennzeichen registrieren; Ferienwohnungen werden nicht erwähnt."),
    ("No day ticket for tourists: the temporary permits of ordinance 2386/2024 are only for specific cases (weddings, removals, works, taxis…). Mopeds, light quadricycles and motorcycles may enter freely. "
     "Disabled badge holders registered on the national CUDE platform are added to the white list automatically.",
     "Nessun permesso giornaliero per turisti: i permessi temporanei dell'ordinanza 2386/2024 valgono solo per casi precisi (matrimoni, traslochi, cantieri, taxi…). Ciclomotori, quadricicli leggeri e moto entrano liberamente. "
     "I titolari di contrassegno disabili iscritti alla piattaforma nazionale CUDE entrano in lista bianca automaticamente.",
     "Kein Tagesticket für Touristen: Die befristeten Genehmigungen der Verordnung 2386/2024 gelten nur für bestimmte Fälle (Hochzeiten, Umzüge, Baustellen, Taxis…). Mopeds, Leichtkraftfahrzeuge und Motorräder dürfen frei einfahren. "
     "Inhaber eines Behindertenausweises, die in der nationalen CUDE-Plattform eingetragen sind, kommen automatisch auf die weiße Liste."),
    ("Electric cars: no exemption in the rules of ordinance 2386/2024 (its preamble only cites a 2013 council resolution on electric vehicles in the ZTL, which we have not read).",
     "Auto elettriche: nessuna esenzione nelle regole dell'ordinanza 2386/2024 (le premesse citano solo una delibera di Giunta del 2013 sui veicoli elettrici in ZTL, che non abbiamo letto).",
     "Elektroautos: keine Ausnahme in den Regeln der Verordnung 2386/2024 (die Präambel nennt nur einen Stadtratsbeschluss von 2013 zu Elektrofahrzeugen in der ZTL, den wir nicht gelesen haben)."),
    ("Gates: camera positions from OpenStreetMap (15). Ordinance 2386/2024 lists 10 gates per sector, and ordinance 406/2025 added two in piazza Santo Sepolcro and piazza Cairoli: some cameras may be missing from the map.",
     "Varchi: posizioni delle telecamere da OpenStreetMap (15). L'ordinanza 2386/2024 elenca 10 varchi per settore e l'ordinanza 406/2025 ne ha aggiunti due in piazza Santo Sepolcro e piazza Cairoli: alcune telecamere possono mancare sulla mappa.",
     "Kameras: Standorte aus OpenStreetMap (15). Die Verordnung 2386/2024 nennt 10 Kameras je Sektor, die Verordnung 406/2025 hat zwei an Piazza Santo Sepolcro und Piazza Cairoli ergänzt: einige Kameras können auf der Karte fehlen."),
    ("Not shown: the ZTL Stadio at Porta a Lucca (home matches of Pisa SC, from 2 hours before kick-off to the end of the first half) and the pedestrian areas inside the ZTL (via Corsica and piazza Buonamici, via Santa Maria)."
     + ("" if LUNG_OK else " The weekend night ZTL on the Lungarni (Fri–Sun 10 pm–5 am, ordinance 2845/2024) is not on the map yet."),
     "Non mostrate: la ZTL Stadio a Porta a Lucca (partite casalinghe del Pisa SC, da due ore prima del fischio d'inizio al termine del primo tempo) e le aree pedonali dentro la ZTL (via Corsica e piazza Buonamici, via Santa Maria)."
     + ("" if LUNG_OK else " La ZTL notturna dei Lungarni (ven–dom 22–5, ordinanza 2845/2024) non è ancora sulla mappa."),
     "Nicht angezeigt: die ZTL Stadio in Porta a Lucca (Heimspiele von Pisa SC, ab 2 Stunden vor Anpfiff bis Ende der ersten Halbzeit) und die Fußgängerzonen in der ZTL (Via Corsica / Piazza Buonamici, Via Santa Maria)."
     + ("" if LUNG_OK else " Die Nacht-ZTL an den Lungarni (Fr–So 22–5 Uhr, Verordnung 2845/2024) ist noch nicht auf der Karte.")),
]
LUNG_PERIMETER = ("Perimeter: drawn around the streets listed in ordinance 2845/2024 (the four Lungarni, piazza Carrara, piazza Mazzini, via San Nicola, the end of via Santa Maria and Ponte di Mezzo), using their OpenStreetMap geometry; approximate.",
                  "Perimetro: tracciato attorno alle strade elencate dall'ordinanza 2845/2024 (i quattro Lungarni, piazza Carrara, piazza Mazzini, via San Nicola, l'ultimo tratto di via Santa Maria e il Ponte di Mezzo), con la geometria di OpenStreetMap; approssimato.",
                  "Grenze: um die in der Verordnung 2845/2024 genannten Straßen gezogen (die vier Lungarni, Piazza Carrara, Piazza Mazzini, Via San Nicola, das letzte Stück der Via Santa Maria und Ponte di Mezzo), mit der Geometrie aus OpenStreetMap; ungefähr.")
LUNG_NO_PERIMETER = ("Perimeter: not drawn yet; it will be built from the street list of ordinance 2845/2024 with OpenStreetMap street geometry.",
                     "Perimetro: non ancora disegnato; sarà ricavato dall'elenco delle strade dell'ordinanza 2845/2024 con la geometria delle strade di OpenStreetMap.",
                     "Grenze: noch nicht gezeichnet; sie wird aus der Straßenliste der Verordnung 2845/2024 mit der Straßengeometrie aus OpenStreetMap erstellt.")
pending_lung = [
    LUNG_PERIMETER if LUNG_OK else LUNG_NO_PERIMETER,
    ("Permits for ZTL Nord and Sud, temporary ones included, are also valid here; the ordinance does not say whether hotels on the Lungarni can register guests, so GateLR does not assume it.",
     "I permessi per le ZTL Nord e Sud, compresi quelli temporanei, valgono anche qui; l'ordinanza non dice se le strutture sui Lungarni possano registrare gli ospiti, quindi GateLR non lo dà per scontato.",
     "Genehmigungen für die ZTL Nord und Sud, auch befristete, gelten auch hier; ob Unterkünfte an den Lungarni Gäste registrieren können, sagt die Verordnung nicht, daher nimmt GateLR es nicht an."),
    ("Cars already parked here at 10 pm may stay and drive out before 5 am. Mopeds and motorcycles may enter. Holidays are not mentioned: the ZTL applies every Friday, Saturday and Sunday night.",
     "Le auto già in sosta qui alle 22 possono restare e uscire anche prima delle 5. Ciclomotori e moto possono entrare. I festivi non sono citati: la ZTL vale ogni venerdì, sabato e domenica notte.",
     "Autos, die um 22 Uhr hier schon parken, dürfen bleiben und auch vor 5 Uhr ausfahren. Mopeds und Motorräder dürfen einfahren. Feiertage werden nicht erwähnt: Die ZTL gilt jede Freitag-, Samstag- und Sonntagnacht."),
]

TRANSLATION = ("In the zones defined in part one, access, transit and parking are forbidden to all vehicles, 0–24 every day, except for the exemptions in the following points.",
               "In den im ersten Teil festgelegten Zonen sind Zufahrt, Durchfahrt und Parken für alle Fahrzeuge verboten, 0–24 Uhr an allen Tagen, vorbehaltlich der folgenden Ausnahmen.")
TRANSLATION_LUNG = ("From 1 January 2025, on Fridays, Saturdays and Sundays, from 10 pm to 5 am the following day, the Limited Traffic Zone is established in the following streets:",
                    "Ab 1. Januar 2025 gilt freitags, samstags und sonntags von 22 Uhr bis 5 Uhr des Folgetags die Zone mit beschränktem Verkehr in folgenden Straßen:")
SUMMARY = ("Closed to unauthorised cars 24 hours a day, every day, holidays included. There is no day ticket for tourists. Mopeds and motorcycles may enter. "
           "If you sleep in a hotel or B&B inside the ZTL, it can register your plate so you can drive there.",
           "Chiusa alle auto non autorizzate 24 ore su 24, tutti i giorni, festivi compresi. Non c'è un ticket giornaliero per i turisti. Ciclomotori e moto possono entrare. "
           "Se dormi in un hotel o B&B dentro la ZTL, la struttura può registrare la tua targa per arrivarci.",
           "Rund um die Uhr, täglich und auch an Feiertagen für nicht berechtigte Autos gesperrt. Es gibt kein Tagesticket für Touristen. Mopeds und Motorräder dürfen einfahren. "
           "Übernachtest du in einem Hotel oder B&B in der ZTL, kann es dein Kennzeichen registrieren, damit du hinfahren darfst.")


def source(ordinance, url, quote, tr, pend):
    return {"authority": "City of Pisa", "pageURL": ORD_PAGE, "ordinance": ordinance, "ordinanceURL": url,
            "quote": quote, "quoteTranslation": tr[0], "quoteTranslation_de": tr[1],
            "checkedOn": CHECKED, "reviewedByHuman": False,
            "pending": [p[0] for p in pend], "pending_it": [p[1] for p in pend], "pending_de": [p[2] for p in pend],
            "links": links}


def zone(key, en, it, de, where_en, where_it, where_de):
    return {
        "id": f"pisa-ztl-{key}", "name": f"{en}", "name_it": f"{it}", "name_de": f"{de}",
        "kind": "restricted",
        "summary": f"{where_en} {SUMMARY[0]}", "summary_it": f"{where_it} {SUMMARY[1]}", "summary_de": f"{where_de} {SUMMARY[2]}",
        "perimeter": rings.get(key, []) if not problems else [], "gates": gates_for(key),
        "windows": [{"weekdays": EVERY_DAY, "start": 0, "end": 24 * 60}],
        "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": True,
        "source": source("Ordinanza Dir. 12 n. 2386 del 24/10/2024 (disciplina ZTL dal 01/01/2025)", ORD_URL, QUOTE, TRANSLATION, pending),
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
    {"id": "pisa-ztl-lungarni", "name": "Lungarni · Weekend night ZTL", "name_it": "Lungarni · ZTL notturna del fine settimana",
     "name_de": "Lungarni · Nacht-ZTL am Wochenende", "kind": "restricted",
     "summary": "The riverside Lungarni (Pacinotti, Mediceo, Galilei, Gambacorti), Ponte di Mezzo, piazza Mazzini, piazza Carrara and via San Nicola: "
                "closed to unauthorised cars on Friday, Saturday and Sunday nights from 10 pm to 5 am. ZTL Nord and Sud permits are valid here.",
     "summary_it": "I Lungarni (Pacinotti, Mediceo, Galilei, Gambacorti), il Ponte di Mezzo, piazza Mazzini, piazza Carrara e via San Nicola: "
                   "chiusi alle auto non autorizzate il venerdì, il sabato e la domenica notte dalle 22 alle 5. I permessi delle ZTL Nord e Sud valgono anche qui.",
     "summary_de": "Die Lungarni am Arno (Pacinotti, Mediceo, Galilei, Gambacorti), Ponte di Mezzo, Piazza Mazzini, Piazza Carrara und Via San Nicola: "
                   "freitags, samstags und sonntags nachts von 22 bis 5 Uhr für nicht berechtigte Autos gesperrt. Genehmigungen der ZTL Nord und Sud gelten auch hier.",
     "perimeter": rings.get("lungarni", []) if LUNG_OK else [], "gates": [],
     "windows": [{"weekdays": FRI_SAT_SUN, "start": 22 * 60, "end": 5 * 60}],
     "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": False,
     "source": source("Ordinanza Dir. 12 n. 2845 del 23/12/2024 (ZTL dei Lungarni dal 01/01/2025)", LUNGARNI_URL, QUOTE_LUNG, TRANSLATION_LUNG, pending_lung)},
]

city = {"id": "pisa", "name": "Pisa", "name_it": "Pisa", "name_de": "Pisa",
        "center": {"lat": 43.7167, "lon": 10.4017}, "zones": zones, "status": "draft",
        "license": "Rules: Comune di Pisa official pages and ordinances. Perimeters (from the official street list) and gates: "
                   + osm_geo.ODBL + " (approximate, not official)"}

# In app solo con orari verificati e il perimetro di entrambi i settori, superati i controlli; altrimenti bozza
ready = HOURS_OFFICIAL and not problems and all(len(z["perimeter"]) >= 4 for z in zones[:2])
if ready and not LUNG_OK:
    zones.pop()   # nell'app solo con un perimetro: senza, la ZTL dei Lungarni resta descritta nella bozza
out = ROOT / ("Resources/Cities/pisa.json" if ready else "data/drafts/pisa.json")
(ROOT / ("data/drafts/pisa.json" if ready else "Resources/Cities/pisa.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
for n in geo_notes + ([] if ready else problems):
    print("nota:", n)
print(out.relative_to(ROOT), [(z["id"], len(z["perimeter"]), len(z["gates"])) for z in zones])
