#!/usr/bin/env python3
# Salerno: perimetro della ZTL e posizione dei 14 varchi ricavati in automatico dalla tavola ufficiale del PGTU
# «Piano Generale del Traffico Urbano – TAVOLA 7.2 Individuazione ZTL 1:5000» (PDF vettoriale AutoCAD del 25/07/2019,
# coordinatore scientifico Stefano de Luca), fornita dal proprietario del progetto il 27/10/2026. Niente è disegnato a mano.
#
# 1. --pdf <file>: il PDF è convertito in SVG (pdftocairo) e se ne estraggono, in coordinate della pagina (pt), le polilinee
#    per colore della legenda: rosso = «Strade in zona a traffico limitato», giallo = «Passaggio pedonale», verde = «Scale»,
#    blu = «Area pedonale lungomare», e le etichette numeriche dei varchi (pdftotext -bbox); la legenda (x > 1800 pt) è
#    esclusa. Risultato: data/raw/salerno/pgtu-tav7-vettori.json (con il testo della legenda). Senza --pdf si riparte da lì.
# 2. Aggancio alle coordinate: similitudine (scala, rotazione, traslazione) che sovrappone le linee rosse (asse delle strade
#    della ZTL, campionate ogni 2 pt) alle strade OpenStreetMap (data/raw/geo/salerno-centro.json, API OSM, ODbL):
#    ricerca a griglia (tolleranza ~20 m) e poi locale (tolleranza ~8 m e ~4 m) della trasformazione che porta più punti
#    rossi su una strada OSM. Controllo: almeno il 95 % dei punti entro ~4 m.
# 3. Area: unione delle linee rosse allargate di 23 pt e ristrette di 19 pt (chiusura: riempie gli isolati tra le strade
#    della ZTL, vuoti fino a ~80 m, e lascia ~7 m oltre l'asse delle strade di bordo), buchi riempiti, componente maggiore,
#    portata in coordinate e semplificata a 3 m.
# 4. Varchi: per ogni etichetta 1–14 il punto più vicino sulle linee rosse, portato in coordinate e poi agganciato alla
#    strada OSM che porta il nome della legenda, se entro 25 m (altrimenti resta il punto della tavola).
# Risultato: data/raw/salerno/ztl-pgtu-tav7.geojson (con trasformazione e punteggi), letto da Tools/build_salerno.py.
# Serve numpy, Pillow e shapely. Uso: python3 Tools/salerno_mappa.py [--pdf PGTU-Tav7.pdf]
import json, math, re, subprocess, sys, tempfile
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
from shapely.geometry import LineString, Point, Polygon
from shapely.ops import unary_union, nearest_points
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
VEC = ROOT / "data/raw/salerno/pgtu-tav7-vettori.json"
OUT = ROOT / "data/raw/salerno/ztl-pgtu-tav7.geojson"
LEGEND_X = 1800
COLORS = {"rgb(100%, 0%, 0%)": "red", "rgb(100%, 100%, 0%)": "yellow", "rgb(0%, 86.66687%, 0%)": "green",
          "rgb(0%, 72.155762%, 0%)": "green", "rgb(0%, 0%, 100%)": "blue"}
GATE_NAMES = {1: "Varco Antica Corte", 2: "Varco San Michele", 3: "Varco Via Monte Risi", 4: "Varco Via Romualdo II Guarna",
              5: "Varco Via Duomo", 6: "Varco Portanova", 7: "Varco Mazza Antonio", 8: "Varco Via Vigorito",
              9: "Varco Via Portacatena", 10: "Varco Via della Porta", 11: "Varco Piazzetta Elina", 12: "Varco Via dei Principati",
              13: "Varco Via Conforti Raffaele", 14: "Varco Via Porta di Mare"}
OSM_STREET = {1: "Via Antica Corte", 2: "Via San Michele", 3: "Via Nicola Monterisi", 4: "Via Romualdo II Guarna", 5: "Via Duomo",
              6: "Via Portanova", 7: "Via Antonio Mazza", 8: "Via Giuseppe Vigorito", 9: "Via Porta Catena",
              10: "Via Matteo della Porta", 11: None, 12: "Via dei Principati", 13: "Via Raffaele Conforti", 14: "Via Porta di Mare"}


def extract(pdf):
    with tempfile.TemporaryDirectory() as tmp:
        svg_path, bbox_path = Path(tmp) / "t.svg", Path(tmp) / "b.html"
        subprocess.run(["pdftocairo", "-svg", pdf, str(svg_path)], check=True)
        subprocess.run(["pdftotext", "-bbox", pdf, str(bbox_path)], check=True)
        legend = subprocess.run(["pdftotext", "-layout", pdf, "-"], check=True, capture_output=True, text=True).stdout
        svg, bbox = svg_path.read_text(), bbox_path.read_text()
    lines = {}
    for m in re.finditer(r"<path ([^>]*)/>", svg):
        a = m.group(1)
        s = re.search(r'stroke="([^"]+)"', a)
        if not s or s.group(1) not in COLORS:
            continue
        M = [float(x) for x in re.search(r'transform="matrix\(([^)]+)\)"', a).group(1).split(",")]
        toks = re.findall(r"[MLCZ]|-?[\d.]+", re.search(r' d="([^"]+)"', a).group(1))
        polys, cur, i, cmd = [], [], 0, None
        while i < len(toks):
            if toks[i] in "MLCZ":
                cmd = toks[i]; i += 1
                if cmd == "M" and cur:
                    polys.append(cur); cur = []
                if cmd == "Z":
                    if cur: cur.append(cur[0])
                    continue
            n = {"M": 2, "L": 2, "C": 6}[cmd]
            x, y = (float(v) for v in toks[i + n - 2:i + n]); i += n
            cur.append([round(M[0] * x + M[2] * y + M[4], 3), round(M[1] * x + M[3] * y + M[5], 3)])
        if cur:
            polys.append(cur)
        lines.setdefault(COLORS[s.group(1)], []).extend(p for p in polys if len(p) > 1 and max(q[0] for q in p) < LEGEND_X)
    labels = {}
    for m in re.finditer(r'<word xMin="([\d.]+)" yMin="([\d.]+)" xMax="([\d.]+)" yMax="([\d.]+)">(\d+)</word>', bbox):
        xa, ya, xb, yb = map(float, m.group(1, 2, 3, 4))
        if xa < LEGEND_X and 1 <= int(m.group(5)) <= 14:
            labels[m.group(5)] = [round((xa + xb) / 2, 2), round((ya + yb) / 2, 2)]
    VEC.write_text(json.dumps({"source": "Comune di Salerno, PGTU, Tavola 7.2 «Individuazione ZTL» 1:5000 (PDF AutoCAD, 25/07/2019)",
                               "units": "pt della pagina (2551 x 1843), y verso il basso", "legend_text": legend.strip(),
                               "lines": lines, "gate_labels": labels}, ensure_ascii=False) + "\n", encoding="utf-8")
    print("estratte:", {k: len(v) for k, v in lines.items()}, "etichette:", len(labels))


if "--pdf" in sys.argv:
    extract(sys.argv[sys.argv.index("--pdf") + 1])
V = json.loads(VEC.read_text(encoding="utf-8"))
for n, name in GATE_NAMES.items():
    if f"{n} - {name}" not in V["legend_text"]:
        raise SystemExit(f"Legenda: varco non trovato: {n} - {name}")
red = V["lines"]["red"]

# --- 2. aggancio alle strade OSM ---
GEO = osm_geo.load("salerno-centro")
LAT0, LON0 = 40.6790, 14.7560
KX, KY = 111320.0 * math.cos(math.radians(LAT0)), 110574.0
CELL, G0, GN = 2.0, -2500.0, 2500
img = Image.new("L", (GN, GN), 0); dr = ImageDraw.Draw(img)
skip = {"motorway", "motorway_link", "proposed", "construction"}
for e in GEO:
    if e["type"] == "way" and e.get("tags", {}).get("highway") not in (None, *skip) and len(e["geometry"]) > 1:
        dr.line([(((p["lon"] - LON0) * KX - G0) / CELL, (GN - 1) - ((p["lat"] - LAT0) * KY - G0) / CELL) for p in e["geometry"]], fill=255)
base = np.asarray(img) > 0


def dilate(m, r):
    for _ in range(r):
        n = m.copy(); n[1:] |= m[:-1]; n[:-1] |= m[1:]; n[:, 1:] |= m[:, :-1]; n[:, :-1] |= m[:, 1:]; m = n
    return m


TOL = {"coarse": dilate(base, 10), "mid": dilate(base, 4), "fine": dilate(base, 2)}
P = []
for pts in red:
    for (x1, y1), (x2, y2) in zip(pts, pts[1:]):
        n = max(1, int(math.hypot(x2 - x1, y2 - y1) / 2))
        P += [(x1 + (x2 - x1) * i / n, y1 + (y2 - y1) * i / n) for i in range(n)]
P = np.array(P); CX, CY = P[:, 0].mean(), P[:, 1].mean()
PX, PY = P[:, 0] - CX, -(P[:, 1] - CY)


def transform(p, x, y):
    s, th, tx, ty = p
    c, sn = math.cos(th), math.sin(th)
    return tx + s * (c * x - sn * y), ty + s * (sn * x + c * y)


def to_ll(p, px, py):
    mx, my = transform(p, px - CX, -(py - CY))
    return LON0 + mx / KX, LAT0 + my / KY


def score(p, level):
    mx, my = transform(p, PX, PY)
    i = ((GN - 1) - (my - G0) / CELL).astype(int); j = ((mx - G0) / CELL).astype(int)
    ok = (i >= 0) & (i < GN) & (j >= 0) & (j < GN)
    return TOL[level][i[ok], j[ok]].sum() / len(PX)


best = (0, None)
for s in (1.70, 1.764, 1.83):                          # 1:5000 su una pagina di 900 mm ≈ 1,76 m/pt
    for th in np.radians(np.arange(-6, 6.1, 2)):
        for tx in np.arange(-1500, 1501, 15):
            for ty in np.arange(-1500, 1501, 15):
                f = score((s, th, tx, ty), "coarse")
                if f > best[0]:
                    best = (f, (s, th, tx, ty))
p = tuple(float(v) for v in best[1])
for level, step in (("mid", [0.02, math.radians(0.5), 5.0, 5.0]), ("fine", [0.005, math.radians(0.2), 2.0, 2.0])):
    f = score(p, level)
    for _ in range(6):
        improved = True
        while improved:
            improved = False
            for k in range(4):
                for d in (-1, 1):
                    q = list(p); q[k] += d * step[k]
                    g = score(tuple(q), level)
                    if g > f:
                        f, p, improved = g, tuple(q), True
        step = [x / 2 for x in step]
f_mid, f_fine = score(p, "mid"), score(p, "fine")
print(f"aggancio: {p[0]:.4f} m/pt, rotazione {math.degrees(p[1]):.2f}°, traslazione {p[2]:.1f} m, {p[3]:.1f} m; "
      f"punti rossi su strade OSM: {f_mid:.3f} entro ~8 m, {f_fine:.3f} entro ~4 m")
if f_fine < 0.95:
    raise SystemExit("La tavola non si aggancia bene alle strade OSM: ricontrollare")

# --- 3. area ---
U = unary_union([LineString(pts) for pts in red])
a = U.buffer(23).buffer(-19)
parts = sorted(list(a.geoms) if a.geom_type == "MultiPolygon" else [a], key=lambda g: -g.area)
zone = Polygon(parts[0].exterior)
ring = osm_geo.simplify_m([list(to_ll(p, x, y)) for x, y in zone.exterior.coords], 3.0)
print("area km²:", round(osm_geo.area_km2(ring), 3), "componenti:", [round(g.area / zone.area, 3) for g in parts[:3]])

# --- 4. varchi ---
streets = {}
for e in GEO:
    t = e.get("tags", {})
    if e["type"] == "way" and t.get("name") and len(e["geometry"]) > 1:
        streets.setdefault(t["name"], []).append(LineString([((q["lon"] - LON0) * KX, (q["lat"] - LAT0) * KY) for q in e["geometry"]]))
gates = []
for n in range(1, 15):
    lab = V["gate_labels"][str(n)]
    q = nearest_points(U, Point(lab))[0]
    lon, lat = to_ll(p, q.x, q.y)
    pt, snapped, d_snap = Point((lon - LON0) * KX, (lat - LAT0) * KY), None, None
    if OSM_STREET[n] in streets:
        s = unary_union(streets[OSM_STREET[n]])
        d_snap = s.distance(pt)
        if d_snap <= 25:
            r = nearest_points(s, pt)[0]
            lon, lat, snapped = LON0 + r.x / KX, LAT0 + r.y / KY, OSM_STREET[n]
    gates.append({"n": n, "name": GATE_NAMES[n], "lat": round(lat, 6), "lon": round(lon, 6), "label_to_line_pt": round(q.distance(Point(lab)), 1),
                  "osm_street": snapped, "snap_m": None if d_snap is None else round(d_snap, 1)})
    print(n, GATE_NAMES[n], "→", snapped or "punto della tavola", "" if d_snap is None else f"{d_snap:.1f} m")
OUT.write_text(json.dumps({
    "type": "FeatureCollection",
    "source": "Comune di Salerno, PGTU, Tavola 7.2 «Individuazione ZTL» (2019), georeferenziata sulle strade OSM",
    "transform": {"scale_m_per_pt": round(p[0], 5), "rotation_deg": round(math.degrees(p[1]), 3), "tx_m": round(p[2], 2), "ty_m": round(p[3], 2),
                  "page_centre_pt": [round(CX, 3), round(CY, 3)], "origin": [LAT0, LON0], "red_on_osm_8m": round(f_mid, 3), "red_on_osm_4m": round(f_fine, 3)},
    "features": [{"type": "Feature", "properties": {"name": "ZTL Salerno (PGTU Tav. 7.2)"},
                  "geometry": {"type": "Polygon", "coordinates": [[[round(x, 6), round(y, 6)] for x, y in ring]]}}]
               + [{"type": "Feature", "properties": {k: v for k, v in g.items() if k not in ("lat", "lon")},
                   "geometry": {"type": "Point", "coordinates": [g["lon"], g["lat"]]}} for g in gates]}, ensure_ascii=False) + "\n", encoding="utf-8")
print(OUT.relative_to(ROOT))
