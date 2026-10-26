#!/usr/bin/env python3
# Gli edifici 3D trasparenti della prima pagina della presentazione (Sources/Intro2/IntroMapboxMap.swift):
# dagli edifici OpenStreetMap del centro di Firenze (scaricati da Tools/intro_routes.py, ramo «intro-routes")
# a Resources/Intro/firenze-edifici.geojson. Gli edifici vicini con la stessa altezza (a gradini di 3 m) diventano un
# solo blocco: meno punti e un aspetto pulito e uniforme. Altezza: «height», altrimenti i piani × 3,2 m, altrimenti 14 m.
# Restano fuori i monumenti che lo stile Standard di Mapbox disegna già in 3D (Duomo, Palazzo Vecchio, …).
# Dati © OpenStreetMap contributors, ODbL 1.0. Uso: python3 Tools/intro_buildings.py firenze-buildings-osm.json
import json, re, sys
from pathlib import Path

from shapely.geometry import Polygon, mapping
from shapely.ops import unary_union

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Resources/Intro/firenze-edifici.geojson"
# Quel che si vede dalla camera della pagina (IntroMapboxMap: zoom 13,95, inclinata di 45°, rivolta a 275°), con 150 m di margine
VIEW = Polygon([(11.2298, 43.7717), (11.2319, 43.7886), (11.2794, 43.7818), (11.2782, 43.7725)]).buffer(0.0018)
# I monumenti con il modello 3D di Mapbox: non si doppiano
LANDMARKS = re.compile(r"Santa Maria del Fiore|Campanile di Giotto|Battistero|Palazzo Vecchio|Santa Croce|"
                       r"Santa Maria Novella|San Lorenzo|Palazzo Pitti|Uffizi|Orsanmichele|Bargello|Ponte Vecchio|"
                       r"Santo Spirito|Tempio Maggiore|Santissima Annunziata|Palazzo Medici", re.I)


def number(v):
    m = re.match(r"\s*([0-9]+(?:[.,][0-9]+)?)", v or "")
    return float(m.group(1).replace(",", ".")) if m else None


def height(t):
    h = number(t.get("height") or t.get("building:height"))
    if h is None and number(t.get("building:levels")) is not None:
        h = number(t["building:levels"]) * 3.2 + 1.5
    if h is None:
        h = 6.0 if t.get("building") in ("garage", "garages", "shed", "kiosk", "roof", "hut") else 14.0
    return min(max(h, 3.0), 60.0)


def rings(e):
    if e["type"] == "way":
        g = e.get("geometry") or []
        return [[(p["lon"], p["lat"]) for p in g]], []
    outer, inner = [], []
    for m in e.get("members", []):
        g = m.get("geometry")
        if not g:
            continue
        (inner if m.get("role") == "inner" else outer).append([(p["lon"], p["lat"]) for p in g])
    return outer, inner


def main(path):
    els = json.loads(Path(path).read_text())["elements"]
    groups = {}
    skipped = 0
    for e in els:
        t = e.get("tags", {})
        if t.get("location") == "underground" or number(t.get("layer")) is not None and t["layer"].startswith("-"):
            continue
        if LANDMARKS.search(t.get("name", "")) or t.get("building") in ("cathedral", "basilica"):
            skipped += 1
            continue
        if number(t.get("min_height")) or number(t.get("building:min_level")):
            continue  # tettoie e passaggi sospesi: fuori, per un aspetto pulito
        outer, inner = rings(e)
        for r in outer:
            if len(r) < 4:
                continue
            p = Polygon(r).buffer(0)
            if p.is_empty:
                continue
            for h in inner:
                if len(h) >= 4:
                    p = p.difference(Polygon(h).buffer(0))
            if not VIEW.contains(p.representative_point()):
                continue
            groups.setdefault(int(round(height(t) / 3.0)) * 3, []).append(p)
    feats = []
    tol = 0.000008   # ~0,7 m
    for h, polys in sorted(groups.items()):
        u = unary_union([p.buffer(0.000002, join_style=2) for p in polys]).buffer(-0.000002, join_style=2)
        u = u.simplify(tol, preserve_topology=True)
        parts = list(u.geoms) if hasattr(u, "geoms") else [u]
        for g in parts:
            if g.geom_type != "Polygon" or g.area * 111320 * 80500 < 15:
                continue
            geo = mapping(g)
            coords = [[[round(x, 5), round(y, 5)] for x, y in ring] for ring in geo["coordinates"]]
            feats.append({"type": "Feature", "properties": {"h": h}, "geometry": {"type": "Polygon", "coordinates": coords}})
    OUT.parent.mkdir(parents=True, exist_ok=True)
    fc = {"type": "FeatureCollection", "attribution": "© OpenStreetMap contributors, ODbL 1.0", "features": feats}
    OUT.write_text(json.dumps(fc, separators=(",", ":")))
    print(f"{len(feats)} blocchi da {sum(len(v) for v in groups.values())} edifici ({skipped} monumenti fuori),",
          f"{OUT.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main(sys.argv[1])
