#!/usr/bin/env python3
# Le forme DISEGNATE delle zone, calcolate una volta qui e lette dal sito (Tools/build_site.py) e dall'app (ZoneShapes.swift):
# - le zone «a forma di via» (spessore t = 2·area/perimetro < 15 m, es. le vie di Trieste, Torino, Genova, le aree pedonali
#   lungo una via) diventano un corridoio: il poligono allargato di max(7 m, (10 px a z15 − t)/2) per lato, angoli tondi,
#   così da z15 è largo almeno 10 px sullo schermo invece di una striscia di 1–5 px che non si capisce;
# - per ogni zona il punto del segno «ZTL» (dentro la zona; per le zone grandi che ne contengono altre, come le LEZ,
#   lontano da quelle), l'asse della via (per la scritta «ZTL · Via …» lungo la strada) e la misura in metri della forma
#   disegnata (sotto i ~16 px sullo schermo si mostra solo il segno);
# - i varchi delle vie spostati sul bordo del corridoio.
# Solo il disegno: le regole e i controlli «sei dentro?» usano sempre il perimetro vero della città.
# Ogni forma porta «n» e «p0» (numero di punti e primo punto del perimetro da cui è nata): se la città cambia, sito e app
# riconoscono la forma vecchia e tornano al perimetro (e questo script va rilanciato).
# Uso: python3 Tools/build_map_shapes.py   (serve shapely)   →   Resources/Map/zone-shapes.json
import json, math
from pathlib import Path
from shapely.geometry import Polygon, Point, LineString, MultiPolygon
from shapely.geometry.polygon import orient
from shapely.ops import polylabel, unary_union

ROOT = Path(__file__).resolve().parent.parent
CITIES = ROOT / "Resources/Cities"
OUT = ROOT / "Resources/Map/zone-shapes.json"

STREET_M = 15          # sotto questo spessore la zona è una via: corridoio
MIN_BUF_M = 7          # allargamento minimo per lato
MIN_PX, CORRIDOR_Z = 10, 15


def mpp(z, lat):
    """Metri per pixel di MapLibre/Mapbox (tasselli da 512 px) allo zoom z"""
    return 78271.517 * math.cos(math.radians(lat)) / 2 ** z


def r6(x): return round(x, 6)


def shapes_for(city):
    lat0 = city["center"]["lat"]
    kx, ky = 111320 * math.cos(math.radians(lat0)), 110540
    fwd = lambda q: (q["lon"] * kx, q["lat"] * ky)
    ll = lambda x, y: [r6(y / ky), r6(x / kx)]              # [lat, lon]

    def poly(per):
        P = Polygon([fwd(q) for q in per])
        if not P.is_valid:
            P = P.buffer(0)
        if isinstance(P, MultiPolygon):
            P = max(P.geoms, key=lambda g: g.area)
        return P

    items = [("zone", z) for z in city["zones"]] + [("ped", a) for a in city.get("pedestrian") or []]
    polys = {o["id"]: poly(o["perimeter"]) for _, o in items if len(o["perimeter"]) > 2}
    out = {}
    for kind, o in items:
        P = polys.get(o["id"])
        if P is None or P.is_empty or P.area <= 0:
            continue
        t = 2 * P.area / P.length
        e = {"n": len(o["perimeter"]), "p0": [r6(o["perimeter"][0]["lat"]), r6(o["perimeter"][0]["lon"])], "t": round(t, 1)}
        if t < STREET_M:
            buf = max(MIN_BUF_M, (MIN_PX * mpp(CORRIDOR_Z, lat0) - t) / 2)
            D = P.simplify(0.8).buffer(buf, join_style=1, quad_segs=6).simplify(0.4)
            if isinstance(D, MultiPolygon):
                D = max(D.geoms, key=lambda g: g.area)
            D = orient(D, 1.0)
            e["corridor"] = [ll(x, y) for x, y in D.exterior.coords]
            e["buffer"] = round(buf, 1)
            # l'asse della via: i due punti più lontani del perimetro, da sinistra a destra (la scritta si legge dritta)
            pts = list(P.exterior.coords)
            if len(pts) > 160:
                pts = pts[:: math.ceil(len(pts) / 160)]
            a, b = max(((p, q) for p in pts for q in pts), key=lambda pq: math.dist(*pq))
            if a[0] > b[0]:
                a, b = b, a
            e["axis"] = [ll(*a), ll(*b)]
            mid = P.exterior.interpolate(P.exterior.project(LineString([a, b]).interpolate(0.5, normalized=True)))
            m = LineString([a, b]).interpolate(0.5, normalized=True)
            lp = m if D.contains(m) else mid
            shown = D
        else:
            # le zone che ne contengono altre (LEZ, Area B…): il segno lontano da quelle che stanno dentro
            inner = [Q for k2, Q in polys.items() if k2 != o["id"] and Q.area < P.area * 0.6 and P.intersects(Q)]
            free = P.difference(unary_union(inner).buffer(30)) if inner else P
            if free.is_empty or free.area < P.area * 0.05:
                free = P
            if isinstance(free, MultiPolygon):
                free = max(free.geoms, key=lambda g: g.area)
            lp = polylabel(free, 1.0)
            shown = P
        e["label"] = ll(lp.x, lp.y)
        x0, y0, x1, y1 = shown.bounds
        e["ext"] = round(max(x1 - x0, y1 - y0))                 # la misura più lunga della forma disegnata, in metri
        e["ext2"] = round(min(x1 - x0, y1 - y0))
        if "corridor" in e and o.get("gates"):
            ring = shown.exterior
            e["gates"] = []
            for g in o["gates"]:
                p = ring.interpolate(ring.project(Point(fwd(g["location"]))))
                e["gates"].append(ll(p.x, p.y))
        out[o["id"]] = e
    return out


def main():
    manifest = json.loads((CITIES / "manifest.json").read_text(encoding="utf-8"))
    files = sorted({m["file"] for m in manifest["cities"] + manifest.get("unofficialCities", [])})
    data = {"version": 1, "about": "Tools/build_map_shapes.py: corridoi delle vie e punti dei segni, solo per il disegno", "cities": {}}
    streets = 0
    for f in files:
        city = json.loads((CITIES / f).read_text(encoding="utf-8"))
        s = shapes_for(city)
        streets += sum(1 for e in s.values() if "corridor" in e)
        data["cities"][city["id"]] = s
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"{OUT.relative_to(ROOT)}: {len(files)} città, {streets} corridoi, {OUT.stat().st_size // 1024} kB")


if __name__ == "__main__":
    main()
