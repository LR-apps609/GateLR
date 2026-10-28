#!/usr/bin/env python3
# Costruisce la scheda di Ascoli Piceno dai testi ufficiali salvati in data/raw/ascoli-piceno/ (URL e data di lettura in
# testa a ogni file; fonti e date in docs/fonti-ascoli-piceno.md).
#
# Regole in vigore al 27/10/2026:
# - ZTL a fascia ampia (D.G.C. 37/2023, ord. 220/2023): transito solo autorizzati 9:00–12:45 e 15:30–5:00, tutti i giorni
#   (pagina del Comune «ZTL e varchi», scheda «ZTL (fascia oraria ampia)», legenda della mappa ufficiale 2026);
# - ZTL a fascia ridotta (D.G.C. 37/2023 per via XX Settembre e corso Trento e Trieste; D.G.C. 194/2024 e ord. 775/2024
#   per la nuova zona nord/ovest con i varchi Ventidio Basso, Fortezza e Corso di Sotto): ord. 713 del 30/10/2025, in via
#   sperimentale dal 03/11/2025, feriali 20:30–5:00 e festivi 0–24. La deroga dell'ord. 781/2025 è finita il 06/01/2026,
#   la sospensione dell'ord. 524/2026 (varchi Carmine e Mercantini) l'11/09/2026; nessuna ordinanza più recente sulla ZTL
#   tra le pagine pubblicate dal Comune fino al 27/10/2026 (data/raw/ascoli-piceno/elenco-pagine-ztl-2023-2026.txt);
#   la pagina «ZTL e varchi» riporta già gli orari dell'ord. 713/2025;
# - APU 0–24 (D.G.C. 37/2023): aree pedonali, chiuse sempre.
#
# Geometria (mai disegnata a mano): nessun open data e nessuna relazione ZTL in OpenStreetMap. Le zone vengono dalla
# mappa ufficiale dei varchi (PDF del 16/03/2026, l'unica che mostra gli ampliamenti 2024) agganciata ai fabbricati OSM
# da Tools/ascoli_mappa.py → data/raw/ascoli-piceno/ztl-mappa-ufficiale.geojson. Qui ogni zona è controllata con gli
# elenchi ufficiali delle vie: le vie dei varchi (pagina «ZTL e varchi»), la fascia ridotta e l'APU della D.G.C. 37/2023
# devono cadere, con le loro geometrie OSM, nelle zone giuste della mappa, e ogni zona della mappa deve stare entro 30 m da
# vie che gli elenchi mettono in ZTL. Le vie della fascia ampia 2023 fuori dalle zone con varchi (a sud di piazza Arringo,
# senza telecamere e fuori dalla mappa) non sono disegnate: sono nei pending. I varchi sono gli incroci indicati dalla
# pagina «ZTL e varchi» (geometrie OSM).
# Uso: python3 Tools/ascoli_mappa.py && python3 Tools/build_ascoli_piceno.py   (non tocca le altre città né manifest.json)
import json, math, re, unicodedata
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/ascoli-piceno"
CHECKED = "2026-10-27T16:00:00Z"
EVERY_DAY = [1, 2, 3, 4, 5, 6, 7]


def flat(s):
    return re.sub(r"\s+([,.;:)])", r"\1", re.sub(r"\s+", " ", s)).strip()


TEXT = {p.stem: flat(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def url_of(file):
    return TEXT[file].split(" ", 2)[1]


def check(file, *phrases):
    """Ogni frase citata o riassunta deve comparire, parola per parola, nel testo salvato"""
    for q in phrases:
        if flat(q) not in TEXT[file]:
            raise SystemExit(f"{file}: frase non trovata, ricontrollare il testo: {q!r}")


PAGE_F, AMPIA_F, RIDOTTA_F, FAQ_F, O713_F, O781_F, O630_F, O524_F, D37_F, D194_F, MAP_F, NEWS_F, LIST_F = (
    "comune-ztl-e-varchi", "comune-ztl-fascia-ampia", "comune-ztl-fascia-ridotta", "comune-domande-risposte-varchi",
    "ordinanza-713-2025", "ordinanza-781-2025", "ordinanza-630-2025", "ordinanza-524-2026", "dgc-37-2023", "dgc-194-2024",
    "mappa-ufficiale-varchi-2026", "comune-comunicato-varchi-fascia-ridotta-2025", "elenco-pagine-ztl-2023-2026")
PAGE, AMPIA_URL, O713, O781, O524, D37, D194, MAP = map(url_of, (PAGE_F, AMPIA_F, O713_F, O781_F, O524_F, D37_F, D194_F, MAP_F))
O713_PAGE = "https://www.comune.ap.it/flex/cm/pages/ServeBLOB.php/L/IT/IDPagina/26886"

Q_AMPIA = ("Per le zone a traffico limitato esistenti, perimetrate con Deliberazione n. 123/2015 e successiva modifica con "
           "Deliberazione n. 37/2023 il transito veicolare è limitato ai soli autorizzati dalle ore 9:00 alle ore 12:45 e dalle ore 15:30 alle ore 05:00")
Q_RIDOTTA = ("La modifica del regime orario di limitazione al traffico veicolare nelle ZTL “a fascia ridotta” con orario di validità "
             "20:30–05:00 nei giorni feriali e 0-24 nei giorni festivi.")
check(PAGE_F, Q_AMPIA, "I Varchi sono DISATTIVATI e pertanto accessibili a tutti (anche ai non autorizzati) nelle fasce orarie dalle 05:00 alle 09:00 e dalle 12:45 alle 15:30.",
      "giorni feriali dalle 20:30 alle 5:0; giorni festivi dalle 00:00 alle 24:00.",
      "I motoveicoli e i ciclomotori sono sempre autorizzati a transitare nelle sole Zone a Traffico Limitato, anche con varchi attivi.",
      "la targa dei veicoli da autorizzare dovrà essere comunicata alla struttura stessa che provvederà a far inserire la stessa nella lista di quelli autorizzati.",
      "è vietato dalle 0:00 alle 24:00 a tutti i veicoli aventi massa superiore a 3500 chilogrammi.",
      "preventivamente al transito o al massimo nelle 48 ore successive al allo stesso.",
      "dalle 20:30 della sera alle 5:30 del mattino", "nella fascia oraria 7:30 – 20:30",
      "Scarica la mappa ufficiale allegata al regolamento in formato pdf")
check(AMPIA_F, "Dalle 09:00 alle 12:45 Dalle 15:30 alle 5:00")
check(RIDOTTA_F, "via XX Settembre, corso Trento e Trieste, piazza S.Maria Intervineas, piazza F. Simonetti", "Dalle 20:30 alle 07:30")
check(FAQ_F, "ZTL Fascia ridotta dalle ore 7:30 alle ore 20:30")
check(O713_F, Q_RIDOTTA, "in via sperimentale, a far data dal 03/11/2025", "per poi esser resa definitiva attraverso il previsto iter amministrativo",
      "l’ordinanza dirigenziale n.775 del 06/12/2024")
check(O781_F, "dal 28/11/2025 al 06/01/2026")
check(O630_F, "estensione oraria dei varchi esistenti all’intera fascia oraria delle giornate festive",
      "esclusivamente per quanto concerne la modifica nella fascia oraria festiva")
check(O524_F, "Dal 24 agosto 2026 all’11 settembre 2026 la sospensione temporanea della disciplina ZTL")
check(D37_F, "dalle ore 9:00 alle 12:45 e dalle 15:30 alle 5:00.",
      "Le strutture ricettive site all’interno della ZTL e dell’APU dovranno fornire al competente Ufficio del Comando di Polizia Locale entro 48 ore l’elenco dei veicoli",
      "dei veicoli elettrici “puri” a prescindere dalla residenza in ZTL del proprietario.")
check(D194_F, "estendere all’intero periodo festivo della settimana la limitazione oraria all’interno di tutte le ZTL")
check(MAP_F, "ZTL A FASCIA AMPIA PRESIDIATA DA VARCHI ELETTRONICI", "ZTL A FASCIA RIDOTTA PRESIDIATA DA VARCHI ELETTRONICI",
      "AREA PEDONALE URBANA 00:00 - 24:00", "PERCORSI AUTORIZZATI DAI VARCHI 09:00-12:45 / 15:30-05:00")
check(LIST_F, "Ordinanza dirigenziale n. 524 del 25/08/2026")

# --- elenchi ufficiali delle vie (D.G.C. 37/2023, allegato 1) ---


def bullets(text, start, end):
    i = TEXT[D37_F].index(flat(start)); j = TEXT[D37_F].index(flat(end), i)
    out = []
    for b in TEXT[D37_F][i:j].split("•")[1:]:
        b = re.sub(r"\s+\d+(\s+ALLEGATO\s+1)?\s*$", "", b).strip()          # numeri di pagina e intestazioni
        b = re.sub(r"\s*\([^)]*\)", "", b).strip()
        if b:
            out.append(b)
    return out


APU_STREETS = bullets(D37_F, "Nella porzione dell’Area Pedonale Urbana costituita da:", "è istituito il divieto di circolazione")
AMPIA_STREETS = bullets(D37_F, "Nella porzione di ZTL (fascia oraria ampia) costituita da:", "Il transito e la permanenza dei veicoli è limitato")
RIDOTTA_STREETS = bullets(D37_F, "Nella porzione di ZTL (fascia oraria ridotta) costituita da:", "Il transito e la permanenza dei veicoli")
assert len(APU_STREETS) == 46 and len(RIDOTTA_STREETS) == 4 and len(AMPIA_STREETS) > 200, (len(APU_STREETS), len(AMPIA_STREETS), len(RIDOTTA_STREETS))
# vie presidiate dai nuovi varchi della fascia ridotta (pagina «ZTL e varchi»)
NEW_RIDOTTA = ["Via Marucci", "Via delle Torri", "P.zza Sant’Agostino", "Via dei Templari", "Via della Fortezza", "Via Pacifico",
               "P.zza Bonfine", "Via Orsini", "Via Dari", "Corso di Sotto", "Via T. Lazzari", "Piazza San Tommaso"]
check(PAGE_F, *NEW_RIDOTTA)

GEO = osm_geo.load("ascoli-piceno-centro")
STREETS = [e for e in GEO if e["type"] == "way" and "highway" in e.get("tags", {}) and e.get("tags", {}).get("name") and e.get("geometry")]
CENTRE = (42.8545, 13.5755)                                   # piazza del Popolo: le vie dei regolamenti stanno entro 1,3 km


def near_centre(w):
    p = w["geometry"][len(w["geometry"]) // 2]
    return math.hypot((p["lat"] - CENTRE[0]) * 110574, (p["lon"] - CENTRE[1]) * 81600) < 1300
GENERIC = {"via", "vai", "rua", "piazza", "pzza", "largo", "lgo", "corso", "cso", "scalinata", "slargo", "dei", "del", "della", "delle",
           "degli", "di", "d", "de", "da", "dell", "l", "s", "san", "sant", "santa", "e", "c", "so", "p", "zza", "go"}
NUM = {"xx": "venti", "xix": "diciannove", "iv": "quarto"}


def tokens(name):
    s = unicodedata.normalize("NFKD", name.lower().replace("’", " ").replace("'", " ")).encode("ascii", "ignore").decode()
    out = []
    for w in re.split(r"[^a-z]+", s):
        w = NUM.get(w, w)
        if len(w) > 1 and w not in GENERIC:
            out.append(w)
    return out


def close(a, b):
    if a == b:
        return True
    if min(len(a), len(b)) < 5 or abs(len(a) - len(b)) > 1:
        return False
    # distanza di modifica ≤ 1 (refusi della delibera: «Bonfine», «Medaluso»)
    if len(a) == len(b):
        return sum(x != y for x, y in zip(a, b)) <= 1
    s, l = sorted((a, b), key=len)
    return any(l[:i] + l[i + 1:] == s for i in range(len(l)))


def osm_ways(official):
    want = tokens(official)
    if not want:
        return []
    hits = [w for w in STREETS if near_centre(w) and all(any(close(t, o) for o in tokens(w["tags"]["name"])) for t in want)]
    same = [w for w in hits if sorted(tokens(w["tags"]["name"])) == sorted(want)]
    exact = [w for w in hits if all(t in tokens(w["tags"]["name"]) for t in want)]
    return same or exact or hits


def inside_share(ways, rings, tol_m=12.0):
    pts = [(p["lat"], p["lon"]) for w in ways for p in w["geometry"]]
    ok = sum(1 for lat, lon in pts if any(osm_geo.contains(r, lat, lon) or osm_geo.distance_m(r, lat, lon) < tol_m for r in rings))
    return ok / len(pts)


MAPPED = json.loads((RAW / "ztl-mappa-ufficiale.geojson").read_text(encoding="utf-8"))
assert MAPPED["transform"]["buildings_f1"] >= 0.65, MAPPED["transform"]
POLYS = {}
for f in MAPPED["features"]:
    POLYS.setdefault(f["properties"]["name"], []).append([tuple(p) for p in f["geometry"]["coordinates"][0]])
AMPIA, RIDOTTA, APU = POLYS["ZTL fascia ampia"], POLYS["ZTL fascia ridotta"], POLYS["APU"]
assert len(AMPIA) == 3 and len(RIDOTTA) == 2 and len(APU) == 2, {k: len(v) for k, v in POLYS.items()}
ALL = AMPIA + RIDOTTA + APU


def verify(label, streets, rings, need=0.8):
    found, missing, bad = 0, [], []
    for s in streets:
        ws = osm_ways(s)
        if not ws:
            missing.append(s); continue
        found += 1
        share = inside_share(ws, rings)
        if share < need:
            bad.append(f"{s} ({share:.0%})")
    print(f"{label}: {found}/{len(streets)} vie trovate in OSM; fuori dalle zone della mappa: {bad or 'nessuna'}")
    return found, missing, bad


# 1. le vie che la pagina «ZTL e varchi» assegna ai varchi stanno nella zona giusta della mappa
AMPIA_GATE_STREETS = ["Via Crispi", "Via della Tribù Fabia", "via delle Canterine", "via Sangallo", "Via Cairoli", "Corso Mazzini"]
check(PAGE_F, "interessando anche Via Crispi, Via della Tribù Fabia", "in via delle Canterine via Sangallo via Crispi e vie limitrofe")
f_ag, _, bad_ag = verify("Pagina «ZTL e varchi», vie dei varchi della fascia ampia → fascia ampia della mappa", AMPIA_GATE_STREETS, AMPIA, need=0.3)
f_rid, _, bad_rid = verify("D.G.C. 37/2023, fascia ridotta → fascia ridotta della mappa", RIDOTTA_STREETS, RIDOTTA, need=0.5)
f_new, _, bad_new = verify("Pagina «ZTL e varchi», vie dei nuovi varchi → fascia ridotta della mappa", NEW_RIDOTTA, RIDOTTA, need=0.5)
assert f_ag == len(AMPIA_GATE_STREETS) and not bad_ag, bad_ag
assert f_rid >= 3 and not bad_rid and f_new >= 10 and len(bad_new) <= 1, (bad_rid, bad_new)
f_apu, _, bad_apu = verify("D.G.C. 37/2023, APU → APU della mappa", APU_STREETS, APU, need=0.5)
f_apu2, _, bad_apu2 = verify("D.G.C. 37/2023, APU → zone colorate della mappa (tratti: le vie citate solo in parte escono)", APU_STREETS, ALL, need=0.3)
assert f_apu >= 30 and len(bad_apu) <= 8 and len(bad_apu2) <= 2, (bad_apu, bad_apu2)

# 2. ogni parte di ogni zona della mappa sta a meno di 30 m da una via che gli elenchi ufficiali mettono in ZTL
#    (ampia: D.G.C. 37/2023; ridotta ovest: vie della D.G.C. 37/2023 passate alla fascia ridotta nel 2024 e vie dei nuovi
#    varchi; corso Trento e Trieste: fascia ridotta della D.G.C. 37/2023)
import numpy as np


def segs(streets):
    out = [(a["lon"], a["lat"], b["lon"], b["lat"]) for s in streets for w in osm_ways(s) for a, b in zip(w["geometry"], w["geometry"][1:])]
    return np.array(out)


def coverage(ring, S, step=5.0, tol=30.0):
    lat0 = sum(p[1] for p in ring) / len(ring); k = 111320 * math.cos(math.radians(lat0)); ky = 110574
    lo0, lo1 = min(p[0] for p in ring), max(p[0] for p in ring); la0, la1 = min(p[1] for p in ring), max(p[1] for p in ring)
    pts = [(lo, la) for la in np.arange(la0, la1, step / ky) for lo in np.arange(lo0, lo1, step / k) if osm_geo.inside_lonlat(ring, lo, la)]
    P = np.array(pts); X, Y = (P[:, 0] - lo0) * k, (P[:, 1] - la0) * ky
    ax, ay, bx, by = (S[:, 0] - lo0) * k, (S[:, 1] - la0) * ky, (S[:, 2] - lo0) * k, (S[:, 3] - la0) * ky
    dx, dy = bx - ax, by - ay; L = np.maximum(dx * dx + dy * dy, 1e-9)
    best = np.full(len(P), np.inf)
    for i in range(0, len(ax), 400):
        sl = slice(i, i + 400)
        t = np.clip(((X[:, None] - ax[None, sl]) * dx[None, sl] + (Y[:, None] - ay[None, sl]) * dy[None, sl]) / L[None, sl], 0, 1)
        d = np.hypot(X[:, None] - ax[None, sl] - t * dx[None, sl], Y[:, None] - ay[None, sl] - t * dy[None, sl])
        best = np.minimum(best, d.min(1))
    return float((best < tol).mean())


# confronto con tutte le strade OSM con nome (i grandi isolati e giardini restano lontani da ogni strada)
ANY = np.array([(a["lon"], a["lat"], b["lon"], b["lat"]) for w in STREETS for a, b in zip(w["geometry"], w["geometry"][1:])])
COVER = {}
for nm, rings, streets in (("fascia ampia", AMPIA, AMPIA_STREETS), ("fascia ridotta", RIDOTTA, AMPIA_STREETS + NEW_RIDOTTA + RIDOTTA_STREETS)):
    S = segs(streets)
    for r in rings:
        c, base = coverage(r, S), coverage(r, ANY)
        COVER[(nm, round(osm_geo.area_km2(r), 4))] = (c, base)
        print(f"{nm} {osm_geo.area_km2(r):.3f} km²: {c:.0%} dell'area entro 30 m da una via degli elenchi ufficiali "
              f"(da una strada OSM qualsiasi: {base:.0%})")
        assert c >= 0.9 * base, (nm, c, base)

# 3. vie della fascia ampia della D.G.C. 37/2023 fuori dalle zone con varchi della mappa (senza telecamere): solo pending
OUTSIDE = []
for s in AMPIA_STREETS:
    ws = [w for w in osm_ways(s) if set(tokens(w["tags"]["name"])) >= set(tokens(s))]
    if ws and inside_share(ws, ALL) < 0.3:
        OUTSIDE.append(s)
print("vie della fascia ampia (D.G.C. 37/2023) fuori dalle zone con varchi:", OUTSIDE)

# --- varchi: incroci indicati dalla pagina «ZTL e varchi» (punto più vicino tra le due strade OSM) ---


def pts_of(names):
    return [(p["lat"], p["lon"]) for w in STREETS if w["tags"]["name"] in names for p in w["geometry"]]


def crossing(a_names, b_names):
    A, B = pts_of(a_names), pts_of(b_names)
    assert A and B, (a_names, b_names)
    k = math.cos(math.radians(A[0][0]))
    best = min(((math.hypot((a[0] - b[0]) * 110574, (a[1] - b[1]) * 111320 * k), a, b) for a in A for b in B))
    assert best[0] < 15, (a_names, b_names, best[0])
    return round((best[1][0] + best[2][0]) / 2, 6), round((best[1][1] + best[2][1]) / 2, 6)


GATES = [  # (id, nome, zona, strade del varco, strade dell'incrocio, frase della pagina)
    ("carmine", "Varco Carmine · Corso Mazzini / Rua dell'Orso", "ampia", ("Corso Giuseppe Mazzini",), ("Rua dell'Orso",),
     "all'intersezione tra Rua dell'Orso e Corso Mazzini"),
    ("mercantini", "Varco Mercantini · Via Mercantini / Via Palestro", "ampia", ("Via Luigi Mercantini",), ("Via Palestro",), "Via Mercantini (con accesso da Piazza Viola)"),
    ("afranio", "Varco Afranio · Via Tito Afranio / Corso Mazzini", "ampia", ("Via Tito Afranio",), ("Corso Giuseppe Mazzini",),
     "E' collocato in via Tito Afranio all’intersezione con c.so Mazzini"),
    ("tessitori", "Varco Tessitori · Via dei Tessitori / Lungotronto", "ampia", ("Via dei Tessitori",), ("Lungotronto Emidio Bartolomei",),
     "E' collocato in via dei Tessitori, all'intersezione con via Lungotronto Bartolomei"),
    ("cairoli", "Varco Cairoli · Via Cairoli / Via Marucci", "ampia", ("Via Benedetto Cairoli",), ("Via Pietro Marucci",),
     "all'intersezione con Via Marucci e Via Cairoli"),
    ("xx-settembre", "Varco XX Settembre · Piazza Roma", "ridotta", ("Via Venti Settembre",), ("Piazza Roma",),
     "all’incrocio di piazza Roma con via XX Settembre"),
    ("ventidio-basso", "Varco Ventidio Basso · Via dei Tamburini", "ridotta", ("Piazza Ventidio Basso",), ("Via Francesco Tamburini",),
     "all'intersezione con Via dei Tamburini"),
    ("fortezza", "Varco Fortezza · Via della Fortezza / Via Angelini", "ridotta", ("Via della Fortezza",), ("Via Dino Angelini",),
     "E' collocato all’incrocio di via della Fortezza con via D. Angelini"),
    ("corso-di-sotto", "Varco Corso di Sotto · Piazza Cecco d'Ascoli", "ridotta", ("Corso di Sotto",), ("Piazza Cecco d'Ascoli",),
     "E' collocato all’incrocio di via corso di Sotto con piazza di Cecco"),
]
for g in GATES:
    check(PAGE_F, g[5])
GATE_PTS = {g[0]: crossing(g[3], g[4]) for g in GATES}

# --- zone ---


def near(rings, lat, lon):
    return min(range(len(rings)), key=lambda i: 0 if osm_geo.contains(rings[i], lat, lon) else osm_geo.distance_m(rings[i], lat, lon))


def ring_with(rings, lat, lon):
    hits = [r for r in rings if osm_geo.contains(r, lat, lon)]
    assert len(hits) == 1, (lat, lon, len(hits))
    return hits[0]


# luoghi noti (coordinate OSM) che identificano ogni pezzo della mappa
PALAZZO_MALASPINA = (42.855529, 13.580069)
VIA_CANTERINE = [(p[0], p[1]) for p in pts_of(("Via delle Canterine",))]
VIA_VIDACILIO = [(p[0], p[1]) for p in pts_of(("Via Vidacilio",))]
PIAZZA_SAN_TOMMASO = (42.855668, 13.570922)
CORSO_TRENTO = [(p[0], p[1]) for p in pts_of(("Corso Trento e Trieste",))]
PIAZZA_POPOLO, PIAZZA_ARRINGO = (42.854216, 13.575336), (42.853601, 13.577685)


def ring_most(rings, pts):
    return max(rings, key=lambda r: sum(osm_geo.contains(r, la, lo) for la, lo in pts))


RING = {"ampia-est": ring_with(AMPIA, *PALAZZO_MALASPINA), "ampia-nord": ring_most(AMPIA, VIA_CANTERINE),
        "ampia-ovest": ring_most(AMPIA, VIA_VIDACILIO), "ridotta-ovest": ring_with(RIDOTTA, *PIAZZA_SAN_TOMMASO),
        "ridotta-trento": ring_most(RIDOTTA, CORSO_TRENTO)}
assert len({id(r) for r in RING.values()}) == 5, "pezzi della mappa non distinti"
APU_RING = {"popolo": ring_with(APU, *PIAZZA_POPOLO), "arringo": ring_with(APU, *PIAZZA_ARRINGO)}


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


LINKS = [link("City of Ascoli Piceno: ZTL and gates (hours, gates, hotels, disabled badge holders)", "Comune di Ascoli Piceno: ZTL e varchi (orari, varchi, alberghi, disabili)",
              "Stadt Ascoli Piceno: ZTL und Kameras (Zeiten, Kameras, Hotels, Behindertenausweis)", PAGE),
         link("Ordinance 713 of 30/10/2025: reduced-hours ZTL weekdays 8:30 pm–5 am, holidays all day (experimental, from 3/11/2025)",
              "Ordinanza 713 del 30/10/2025: ZTL a fascia ridotta feriali 20:30–5, festivi 0–24 (sperimentale, dal 3/11/2025)",
              "Verordnung 713 vom 30.10.2025: ZTL mit verkürzten Zeiten werktags 20:30–5 Uhr, Feiertage ganztägig (Versuch, ab 3.11.2025)", O713_PAGE),
         link("Official map of the ZTLs, pedestrian areas and gates (March 2026, PDF)", "Mappa ufficiale di ZTL, APU e varchi (marzo 2026, PDF)",
              "Offizielle Karte der ZTL, Fußgängerzonen und Kameras (März 2026, PDF)", MAP),
         link("Council resolution 37/2023: ZTL and pedestrian-area rules with the street lists (PDF)", "Delibera di Giunta 37/2023: regolamento ZTL e APU con gli elenchi delle vie (PDF)",
              "Stadtratsbeschluss 37/2023: ZTL- und Fußgängerzonenregeln mit Straßenlisten (PDF)", D37),
         link("Council resolution 194/2024: ZTL extension with three new gates (PDF)", "Delibera di Giunta 194/2024: ampliamento della ZTL con tre nuovi varchi (PDF)",
              "Stadtratsbeschluss 194/2024: Erweiterung der ZTL mit drei neuen Kameras (PDF)", D194)]

COMMON_PENDING = [
    ("Hotels: a guest of a hotel inside the ZTL gives the plate to the hotel, which has it added to the authorised list (City page). The 2023 rules say the hotel sends the list to the Local Police within 48 hours; without private parking you may only stop 30 minutes to unload, with a parking disc and a copy of the hotel's notice on the windscreen.",
     "Alberghi: chi alloggia in una struttura dentro la ZTL comunica la targa alla struttura, che la fa inserire nella lista degli autorizzati (pagina del Comune). Il regolamento 2023 dice che la struttura invia l'elenco alla Polizia Locale entro 48 ore; senza parcheggio privato si sosta al massimo 30 minuti per i bagagli, con disco orario e copia della comunicazione sul parabrezza.",
     "Hotels: Gäste eines Hotels in der ZTL geben das Kennzeichen dem Hotel, das es in die Liste der Berechtigten eintragen lässt (Seite der Stadt). Laut Regeln von 2023 schickt das Hotel die Liste innerhalb von 48 Stunden an die Ortspolizei; ohne eigenen Parkplatz höchstens 30 Minuten zum Ausladen, mit Parkscheibe und Kopie der Meldung hinter der Windschutzscheibe."),
    ("Motorcycles and mopeds may always enter the ZTLs (not the pedestrian areas). Vehicles over 3.5 t are banned 0–24. Pure electric cars need a Local Police permit. Disabled badge holders from other towns send the form to varchi@comune.ap.it before or within 48 hours of entering. There is no visitor ticket.",
     "Moto e ciclomotori entrano sempre nelle ZTL (non nelle APU). Veicoli oltre 3,5 t vietati 0–24. Le auto elettriche «pure» hanno bisogno dell'autorizzazione della Polizia Locale. I disabili con contrassegno di altri Comuni mandano il modulo a varchi@comune.ap.it prima del transito o entro 48 ore. Non c'è un permesso per i visitatori.",
     "Motorräder und Mopeds dürfen immer in die ZTL (nicht in die Fußgängerzonen). Fahrzeuge über 3,5 t sind rund um die Uhr verboten. Reine Elektroautos brauchen eine Genehmigung der Ortspolizei. Inhaber eines Behindertenausweises anderer Gemeinden schicken das Formular vor der Einfahrt oder binnen 48 Stunden an varchi@comune.ap.it. Ein Besucherticket gibt es nicht."),
    ("Perimeter traced automatically from the City's official gate map (March 2026), georeferenced on OpenStreetMap buildings (accurate to about 5–10 m) and checked against the street lists of resolution 37/2023 and of the City's gate page. Piazza del Popolo, Piazza Arringo and the streets around them are pedestrian areas, closed to cars at all times.",
     "Perimetro ricavato in automatico dalla mappa ufficiale dei varchi del Comune (marzo 2026), agganciata ai fabbricati di OpenStreetMap (precisione di circa 5–10 m) e controllato con gli elenchi delle vie della delibera 37/2023 e della pagina dei varchi. Piazza del Popolo, piazza Arringo e le vie intorno sono APU, chiuse alle auto sempre.",
     "Grenze automatisch aus der offiziellen Kamerakarte der Stadt (März 2026) abgeleitet, an OpenStreetMap-Gebäuden ausgerichtet (Genauigkeit etwa 5–10 m) und mit den Straßenlisten des Beschlusses 37/2023 und der Kameraseite geprüft. Piazza del Popolo, Piazza Arringo und die Straßen ringsum sind Fußgängerzonen, für Autos immer gesperrt."),
]
assert {"piazza san Gregorio", "via dei Marsi", "via di Vesta", "via Capitolina", "rua della Musica", "rua Salvioni"} <= set(OUTSIDE), OUTSIDE
AMPIA_PENDING = [
    ("Not drawn: resolution 37/2023 also lists as wide-hours ZTL some streets that the official gate map leaves uncoloured and no camera watches, mainly south of Piazza Arringo (Piazza San Gregorio, Via dei Marsi, Via di Vesta, Via Capitolina, Via della Piazzarola and nearby rue) and a few near Porta Solestà (Rua della Musica, Rua dei Salvioni). The same hours apply there and the police can fine, but GateLR does not show them.",
     "Non disegnate: la delibera 37/2023 elenca come ZTL a fascia ampia anche vie che la mappa ufficiale dei varchi non colora e che nessuna telecamera controlla, soprattutto a sud di piazza Arringo (piazza San Gregorio, via dei Marsi, via di Vesta, via Capitolina, via della Piazzarola e rue vicine) e alcune vicino a Porta Solestà (rua della Musica, rua dei Salvioni). Valgono gli stessi orari e la Polizia Locale può multare, ma GateLR non le mostra.",
     "Nicht eingezeichnet: Beschluss 37/2023 nennt als ZTL mit langen Zeiten auch Straßen, die die offizielle Kamerakarte nicht färbt und keine Kamera überwacht, vor allem südlich der Piazza Arringo (Piazza San Gregorio, Via dei Marsi, Via di Vesta, Via Capitolina, Via della Piazzarola und Gassen ringsum) und einige bei der Porta Solestà (Rua della Musica, Rua dei Salvioni). Dort gelten dieselben Zeiten und die Polizei kann Bußgelder verhängen, GateLR zeigt sie aber nicht."),
    ("Holidays: resolution 194/2024 planned to extend the existing gates to the whole of Sundays and holidays, but the only ordinance found applies this to the Via XX Settembre gate (ordinance 630/2025); the City's ZTL page (2026) still gives these hours every day. Ordinance 775/2024, which put resolution 194/2024 into effect, is not published online.",
     "Festivi: la delibera 194/2024 prevedeva di estendere i varchi esistenti all'intera giornata festiva, ma l'unica ordinanza trovata lo applica al varco di via XX Settembre (ord. 630/2025); la pagina ZTL del Comune (2026) dà ancora questi orari tutti i giorni. L'ordinanza 775/2024 che attua la delibera 194/2024 non è pubblicata online.",
     "Feiertage: Beschluss 194/2024 sah vor, die bestehenden Kameras an Sonn- und Feiertagen ganztägig zu aktivieren; die einzige gefundene Verordnung wendet das nur auf die Kamera Via XX Settembre an (Verordnung 630/2025); die ZTL-Seite der Stadt (2026) nennt weiterhin diese Zeiten für alle Tage. Verordnung 775/2024 zur Umsetzung von Beschluss 194/2024 ist nicht online."),
]
RIDOTTA_PENDING = [
    ("These hours are experimental (ordinance 713/2025, from 3 November 2025, to be made permanent later); no later ordinance was found up to 27/10/2026. Older City pages (FAQ, zone sheet) still say 8:30 pm–7:30 am; on the City's gate page the Via XX Settembre gate text says until 5:30 am and the Corso di Sotto text says open to all 7:30 am–8:30 pm on weekdays. GateLR uses the ordinance; the night after a Sunday or holiday is treated as closed until 5 am.",
     "Orari sperimentali (ord. 713/2025, dal 3 novembre 2025, da rendere definitivi con un atto successivo); nessuna ordinanza più recente trovata fino al 27/10/2026. Pagine più vecchie del Comune (FAQ, scheda della zona) dicono ancora 20:30–7:30; nella pagina dei varchi il testo del varco di via XX Settembre dice fino alle 5:30 e quello di corso di Sotto aperto a tutti 7:30–20:30 nei feriali. GateLR segue l'ordinanza; la notte dopo una domenica o un festivo è considerata chiusa fino alle 5.",
     "Versuchszeiten (Verordnung 713/2025, ab 3. November 2025, später endgültig zu regeln); bis 27.10.2026 keine neuere Verordnung gefunden. Ältere Seiten der Stadt (FAQ, Zonenblatt) nennen noch 20:30–7:30 Uhr; auf der Kameraseite steht beim Varco Via XX Settembre bis 5:30 Uhr und beim Varco Corso di Sotto werktags 7:30–20:30 Uhr für alle frei. GateLR folgt der Verordnung; die Nacht nach einem Sonn- oder Feiertag gilt bis 5 Uhr als gesperrt."),
    ("Events: ordinances can change the rules for single days (e.g. Christmas 2025, ordinance 781/2025, ended 6 January 2026).",
     "Eventi: ordinanze possono cambiare le regole per singoli giorni (es. Natale 2025, ord. 781/2025, finita il 6 gennaio 2026).",
     "Veranstaltungen: Verordnungen können die Regeln an einzelnen Tagen ändern (z. B. Weihnachten 2025, Verordnung 781/2025, endete am 6. Januar 2026)."),
]


def source(quote, tr, tr_de, ordinance, ordinance_url, page, pending):
    return {"authority": "City of Ascoli Piceno", "pageURL": page, "ordinance": ordinance, "ordinanceURL": ordinance_url,
            "quote": quote, "quoteTranslation": tr, "quoteTranslation_de": tr_de, "checkedOn": CHECKED, "reviewedByHuman": False,
            "pending": [p[0] for p in pending], "pending_it": [p[1] for p in pending], "pending_de": [p[2] for p in pending], "links": LINKS}


AMPIA_WINDOWS = [{"weekdays": EVERY_DAY, "start": 9 * 60, "end": 12 * 60 + 45}, {"weekdays": EVERY_DAY, "start": 15 * 60 + 30, "end": 5 * 60}]
RIDOTTA_WINDOWS = [{"weekdays": [2, 3, 4, 5, 6, 7], "start": 20 * 60 + 30, "end": 5 * 60},
                   {"weekdays": [1], "start": 0, "end": 24 * 60}, {"weekdays": [1], "start": 20 * 60 + 30, "end": 5 * 60}]
AMPIA_SUMMARY = ("Limited traffic zone with cameras: closed without a permit 9:00–12:45 and 15:30–5:00 every day; open to everyone 5:00–9:00 and 12:45–15:30. "
                 "The screen at each gate shows «ZTL Attiva» (red) or «ZTL non Attiva» (green).",
                 "ZTL con telecamere: vietata senza permesso 9:00–12:45 e 15:30–5:00 tutti i giorni; aperta a tutti 5:00–9:00 e 12:45–15:30. "
                 "Il pannello al varco indica «ZTL Attiva» (rosso) o «ZTL non Attiva» (verde).",
                 "ZTL mit Kameras: ohne Genehmigung täglich 9:00–12:45 und 15:30–5:00 Uhr gesperrt; frei für alle 5:00–9:00 und 12:45–15:30 Uhr. "
                 "Die Anzeige am Varco zeigt «ZTL Attiva» (rot) oder «ZTL non Attiva» (grün).")
RIDOTTA_SUMMARY = ("Limited traffic zone with cameras: closed without a permit on weekdays 20:30–5:00 and all day on Sundays and holidays; open to everyone on weekdays 5:00–20:30.",
                   "ZTL con telecamere: vietata senza permesso nei feriali 20:30–5:00 e tutto il giorno la domenica e nei festivi; aperta a tutti nei feriali 5:00–20:30.",
                   "ZTL mit Kameras: ohne Genehmigung werktags 20:30–5:00 Uhr und an Sonn- und Feiertagen ganztägig gesperrt; werktags 5:00–20:30 Uhr frei für alle.")
TR_AMPIA = ("For the existing limited traffic zones, defined by resolution 123/2015 as amended by resolution 37/2023, traffic is limited to authorised vehicles only from 9:00 to 12:45 and from 15:30 to 05:00",
            "In den bestehenden verkehrsberuhigten Zonen, festgelegt mit Beschluss 123/2015 und geändert mit Beschluss 37/2023, ist die Durchfahrt von 9:00 bis 12:45 und von 15:30 bis 05:00 Uhr nur Berechtigten erlaubt")
TR_RIDOTTA = ("The change of the hours of the traffic restriction in the “reduced-hours” ZTLs, valid 20:30–05:00 on weekdays and 0–24 on holidays.",
              "Die Änderung der Zeiten der Verkehrsbeschränkung in den ZTL „mit verkürzten Zeiten“: gültig werktags 20:30–05:00 Uhr und an Feiertagen 0–24 Uhr.")

ZDEF = [  # chiave, id, nome en/it/de, luoghi
    ("ampia-est", "ap-ztl-ampia-est", ("Corso Mazzini east · wide-hours ZTL", "Corso Mazzini est · ZTL a fascia ampia", "Corso Mazzini Ost · ZTL mit langen Zeiten"),
     "Palazzo Malaspina, Corso Mazzini (east end), Via Palestro, Via dei Centini Piccolomini"),
    ("ampia-nord", "ap-ztl-ampia-nord", ("Canterine · wide-hours ZTL", "Canterine · ZTL a fascia ampia", "Canterine · ZTL mit langen Zeiten"),
     "Via delle Canterine, Via dei Tessitori, Via Francesco Crispi"),
    ("ampia-ovest", "ap-ztl-ampia-ovest", ("Vidacilio · wide-hours ZTL", "Vidacilio · ZTL a fascia ampia", "Vidacilio · ZTL mit langen Zeiten"),
     "Via Vidacilio, Via Antonio Ceci, Via Benedetto Cairoli"),
    ("ridotta-ovest", "ap-ztl-ridotta-ovest", ("Ventidio Basso · night and holiday ZTL", "Ventidio Basso · ZTL a fascia ridotta", "Ventidio Basso · ZTL nachts und feiertags"),
     "Piazza San Tommaso, Piazza Sant'Agostino, Corso di Sotto, Via della Fortezza"),
    ("ridotta-trento", "ap-ztl-ridotta-trento", ("Corso Trento e Trieste · night and holiday ZTL", "Corso Trento e Trieste · ZTL a fascia ridotta",
                                                 "Corso Trento e Trieste · ZTL nachts und feiertags"), "Corso Trento e Trieste, Piazza Santa Maria Intervineas"),
]
zones = []
for key, zid, (en, it, de), places in ZDEF:
    ring = RING[key]
    shape = osm_geo.perimeter(ring, tol_m=3)
    kind = key.split("-")[0]
    rings_of_kind = [RING[k] for k in RING if k.startswith(kind)]
    gates = [{"id": f"ap-varco-{g[0]}", "name": g[1], "location": {"lat": GATE_PTS[g[0]][0], "lon": GATE_PTS[g[0]][1]}}
             for g in GATES if g[2] == kind and rings_of_kind[near(rings_of_kind, *GATE_PTS[g[0]])] is ring]
    s = AMPIA_SUMMARY if kind == "ampia" else RIDOTTA_SUMMARY
    lead = (f"{places}. ", f"{places.replace('(east end)', '(tratto est)')}. ", f"{places.replace('(east end)', '(Ostteil)')}. ")
    z = {"id": zid, "name": en, "name_it": it, "name_de": de, "kind": "restricted",
         "summary": lead[0] + s[0], "summary_it": lead[1] + s[1], "summary_de": lead[2] + s[2],
         "perimeter": shape, "gates": gates,
         "windows": AMPIA_WINDOWS if kind == "ampia" else RIDOTTA_WINDOWS,
         "freeOnHolidays": False, "holidaysAsSunday": kind == "ridotta", "exemptFuels": [],
         # «I motoveicoli e i ciclomotori sono sempre autorizzati a transitare nelle sole Zone a Traffico Limitato» (regolamento)
         "exemptVehicleTypes": ["motorcycle"], "hotelCanRegister": True,
         "source": source(Q_AMPIA, *TR_AMPIA, "Deliberazione di Giunta n. 37/2023 (regolamento ZTL e APU) e ordinanza dirigenziale n. 220/2023", D37, PAGE,
                          AMPIA_PENDING + COMMON_PENDING) if kind == "ampia" else
         source(Q_RIDOTTA, *TR_RIDOTTA, "Ordinanza dirigenziale n. 713 del 30/10/2025", O713, O713_PAGE, RIDOTTA_PENDING + COMMON_PENDING)}
    for nm in places.split(", "):
        osm = nm.replace(" (east end)", "").replace("Corso Mazzini", "Corso Giuseppe Mazzini")
        pp = [(q["lat"], q["lon"]) for e in GEO if e.get("tags", {}).get("name") == osm for q in (e.get("geometry") or [])]
        assert pp and any(osm_geo.contains(ring, la, lo) for la, lo in pp), (zid, nm)
    zones.append(z)

pedestrian = [{"id": "ap-apu-popolo", "name": "APU · Piazza del Popolo", "perimeter": osm_geo.perimeter(APU_RING["popolo"], tol_m=3)},
              {"id": "ap-apu-arringo", "name": "APU · Piazza Arringo", "perimeter": osm_geo.perimeter(APU_RING["arringo"], tol_m=3)}]

city = {"id": "ascoli-piceno", "name": "Ascoli Piceno", "name_it": "Ascoli Piceno", "name_de": "Ascoli Piceno",
        "center": {"lat": 42.8542, "lon": 13.5754}, "zones": zones, "pedestrian": pedestrian, "status": "draft",
        "license": "Rules: Comune di Ascoli Piceno official pages, resolutions and ordinances. Perimeters: the City's official gate map, georeferenced on "
                   + osm_geo.ODBL + "; approximate."}

# --- controlli di plausibilità (coordinate OSM) ---
Z = {z["id"]: z for z in zones}


def inside(zid, lat, lon):
    return osm_geo.contains(Z[zid]["perimeter"], lat, lon)


assert inside("ap-ztl-ampia-est", *PALAZZO_MALASPINA)
assert inside("ap-ztl-ridotta-ovest", *PIAZZA_SAN_TOMMASO)
assert inside("ap-ztl-ridotta-ovest", 42.855141, 13.573021)            # piazza Sant'Agostino
assert inside("ap-ztl-ridotta-trento", 42.8556, 13.5764) or any(inside("ap-ztl-ridotta-trento", la, lo) for la, lo in CORSO_TRENTO)
for n, (lat, lon) in {"Piazza del Popolo": PIAZZA_POPOLO, "Piazza Arringo": PIAZZA_ARRINGO}.items():
    assert not any(inside(z, lat, lon) for z in Z), f"{n} in una ZTL"
    assert any(osm_geo.contains(p["perimeter"], lat, lon) for p in pedestrian), f"{n} fuori dall'APU"
for n, lat, lon in [("Piazzale della Stazione", 42.85513, 13.587854), ("Piazza Matteotti", 42.853997, 13.584399),
                    ("Largo Porta Romana", 42.853937, 13.566507), ("Viale Marcello Federici", 42.860312, 13.57627)]:
    assert not any(inside(z, lat, lon) for z in Z), f"{n} dentro una ZTL"
for z in zones:
    for g in z["gates"]:
        d = osm_geo.distance_m(z["perimeter"], g["location"]["lat"], g["location"]["lon"])
        assert d < 40, (z["id"], g, d)
assert sum(len(z["gates"]) for z in zones) == len(GATES), [(z["id"], len(z["gates"])) for z in zones]
for z in zones:
    a = osm_geo.area_km2(z["perimeter"])
    assert 0.003 < a < 0.25, (z["id"], a)

ready = all(len(z["perimeter"]) >= 5 and z["source"].get("quote") for z in city["zones"])
out = ROOT / ("Resources/Cities/ascoli-piceno.json" if ready else "data/drafts/ascoli-piceno.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/ascoli-piceno.json" if ready else "Resources/Cities/ascoli-piceno.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), [(z["id"], len(z["perimeter"]), len(z["gates"]), round(osm_geo.area_km2(z["perimeter"]), 3)) for z in zones])
