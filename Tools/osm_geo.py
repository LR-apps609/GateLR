#!/usr/bin/env python3
# Strumenti comuni per usare i dati OpenStreetMap scaricati da Overpass («out geom») in data/raw/geo/.
# Dati © OpenStreetMap contributors, ODbL 1.0 (https://www.openstreetmap.org/copyright).
#
# - outer_ring(rel): il contorno esterno di una relazione-area (way «outer» unite testa-coda, anche se
#   disegnate al contrario); se ci sono più anelli tiene il più grande; se non si chiude, si ferma con un errore.
# - street_area(rel): per le relazioni «enforcement» che elencano le strade della ZTL (ruolo «section») e
#   nessun contorno: l'area coperta da quelle strade (chiusura morfologica su una griglia di qualche metro).
# - gates(...): i varchi con coordinate (nodi «device»/«from»/«to» delle relazioni enforcement, o nodi «Varco ZTL»).
# - simplify_m / perimeter: Douglas-Peucker in metri e conversione nel formato delle città ({lat, lon}).
# - contains / area_km2: per i controlli di plausibilità.
import json, math
from pathlib import Path

GEO = Path(__file__).resolve().parent.parent / "data/raw/geo"
ODBL = "© OpenStreetMap contributors, ODbL 1.0"


def osm_url(kind, osm_id):
    return f"https://www.openstreetmap.org/{kind}/{osm_id}"


def load(name):
    """Gli elementi di un file Overpass in data/raw/geo/ (es. «roma-ztl»)"""
    return json.loads((GEO / f"{name}.json").read_text(encoding="utf-8"))["elements"]


def relation(elements, osm_id):
    for e in elements:
        if e["type"] == "relation" and e["id"] == osm_id:
            return e
    raise SystemExit(f"Relazione OSM {osm_id} non trovata nei dati scaricati")


# --- geometria piana locale (metri), sufficiente per una città ---

def _proj(lat0):
    k = math.cos(math.radians(lat0))
    return (lambda lon, lat: ((lon * k) * 111320.0, lat * 110574.0),
            lambda x, y: (x / (111320.0 * k), y / 110574.0))


def _signed_area(pts):
    return sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(pts, pts[1:] + pts[:1])) / 2


def area_km2(ring):
    """Area di un anello [lon, lat] o [{lat, lon}] in km²"""
    pts = [(p["lon"], p["lat"]) if isinstance(p, dict) else tuple(p) for p in ring]
    fwd, _ = _proj(sum(p[1] for p in pts) / len(pts))
    return abs(_signed_area([fwd(*p) for p in pts])) / 1e6


def contains(ring, lat, lon):
    """Punto nel poligono (ray casting), anello [{lat, lon}] o [lon, lat]"""
    pts = [(p["lon"], p["lat"]) if isinstance(p, dict) else tuple(p) for p in ring]
    inside = False
    for (x1, y1), (x2, y2) in zip(pts, pts[1:] + pts[:1]):
        if (y1 > lat) != (y2 > lat) and lon < (x2 - x1) * (lat - y1) / (y2 - y1) + x1:
            inside = not inside
    return inside


def distance_m(ring, lat, lon):
    """Distanza in metri dal punto al bordo dell'anello"""
    pts = [(p["lon"], p["lat"]) if isinstance(p, dict) else tuple(p) for p in ring]
    fwd, _ = _proj(lat)
    q = fwd(lon, lat)
    best = float("inf")
    for a, b in zip(pts, pts[1:] + pts[:1]):
        (ax, ay), (bx, by) = fwd(*a), fwd(*b)
        dx, dy = bx - ax, by - ay
        t = 0 if dx == dy == 0 else max(0, min(1, ((q[0] - ax) * dx + (q[1] - ay) * dy) / (dx * dx + dy * dy)))
        best = min(best, math.hypot(q[0] - ax - t * dx, q[1] - ay - t * dy))
    return best


def simplify_m(points, tol_m=5.0):
    """Douglas-Peucker con tolleranza in metri su punti [lon, lat] (anello chiuso: primo == ultimo)"""
    if len(points) < 4:
        return points
    fwd, _ = _proj(sum(p[1] for p in points) / len(points))
    xy = [fwd(*p) for p in points]
    keep = [False] * len(points)
    keep[0] = keep[-1] = True
    # un anello chiuso ha primo == ultimo: lo spezzo nel punto più lontano dal primo
    far = max(range(len(xy)), key=lambda i: math.hypot(xy[i][0] - xy[0][0], xy[i][1] - xy[0][1]))
    keep[far] = True
    stack = [(0, far), (far, len(points) - 1)]
    while stack:
        i, j = stack.pop()
        if j <= i + 1:
            continue
        (ax, ay), (bx, by) = xy[i], xy[j]
        dx, dy = bx - ax, by - ay
        best, idx = -1.0, None
        for k in range(i + 1, j):
            px, py = xy[k]
            t = 0 if dx == dy == 0 else max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
            d = math.hypot(px - ax - t * dx, py - ay - t * dy)
            if d > best:
                best, idx = d, k
        if best > tol_m:
            keep[idx] = True
            stack += [(i, idx), (idx, j)]
    return [p for p, k in zip(points, keep) if k]


def perimeter(points, tol_m=5.0):
    """Anello [lon, lat] → lista di {lat, lon} semplificata, chiusa (primo == ultimo), come nelle altre città"""
    pts = simplify_m(points, tol_m)
    out = [{"lat": round(p[1], 6), "lon": round(p[0], 6)} for p in pts]
    if out[0] != out[-1]:
        out.append(dict(out[0]))
    if len(out) < 5:   # almeno 4 punti distinti
        raise SystemExit("Perimetro troppo piccolo dopo la semplificazione")
    return out


# --- contorno di una relazione-area ---

def outer_ring(rel, roles=("outer",)):
    """Le way «outer» (o con i ruoli indicati) unite testa-coda in anelli chiusi; restituisce il più grande come [lon, lat]"""
    key = lambda p: (round(p[0], 7), round(p[1], 7))
    parts = [[(n["lon"], n["lat"]) for n in m["geometry"]]
             for m in rel["members"] if m["type"] == "way" and m.get("role") in roles and m.get("geometry")]
    if not parts:
        raise SystemExit(f"Relazione {rel['id']} ({rel.get('tags', {}).get('name')}): nessuna way outer con geometria")
    rings = []
    while parts:
        cur = parts.pop(0)
        while key(cur[0]) != key(cur[-1]):
            for i, p in enumerate(parts):
                if key(p[0]) == key(cur[-1]):
                    cur += p[1:]
                elif key(p[-1]) == key(cur[-1]):
                    cur += p[::-1][1:]
                elif key(p[-1]) == key(cur[0]):
                    cur = p + cur[1:]
                elif key(p[0]) == key(cur[0]):
                    cur = p[::-1] + cur[1:]
                else:
                    continue
                parts.pop(i)
                break
            else:
                raise SystemExit(f"Relazione {rel['id']} ({rel.get('tags', {}).get('name')}): il contorno non si chiude "
                                 f"(estremo libero a {cur[-1][1]:.6f}, {cur[-1][0]:.6f})")
        if len(cur) >= 4:
            rings.append(cur)
    return max(rings, key=area_km2)


# --- area coperta dalle strade di una relazione enforcement (nessun contorno in OSM) ---

def _fill_holes(cells):
    """Le celle più tutti i buchi che racchiudono (flood fill dall'esterno)"""
    xs, ys = [c[0] for c in cells], [c[1] for c in cells]
    x0, x1, y0, y1 = min(xs) - 1, max(xs) + 1, min(ys) - 1, max(ys) + 1
    outside, todo = {(x0, y0)}, [(x0, y0)]
    while todo:
        x, y = todo.pop()
        for c in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if x0 <= c[0] <= x1 and y0 <= c[1] <= y1 and c not in outside and c not in cells:
                outside.add(c)
                todo.append(c)
    return {(x, y) for x in range(x0, x1 + 1) for y in range(y0, y1 + 1) if (x, y) not in outside}


def street_area(rel, cell_m=8.0, close_m=70.0, keep=None):
    """Unisce le way «section» su una griglia (celle di cell_m), chiude i vuoti fino a ~2·close_m tra le strade,
    riempie i buchi e restituisce il contorno esterno della parte più grande come anello [lon, lat].
    Le strade più esterne restano dentro (al massimo mezza cella oltre la mezzeria)."""
    lines = [[(n["lon"], n["lat"]) for n in m["geometry"]]
             for m in rel["members"] if m["type"] == "way" and m.get("role") == "section" and m.get("geometry")]
    if keep:   # solo le strade il cui punto centrale è nell'area indicata (es. dentro le mura)
        lines = [l for l in lines if keep(*l[len(l) // 2])]
    if not lines:
        raise SystemExit(f"Relazione {rel['id']}: nessuna way section con geometria")
    lat0 = sum(p[1] for l in lines for p in l) / sum(len(l) for l in lines)
    fwd, back = _proj(lat0)
    cells = set()
    for l in lines:
        xy = [fwd(*p) for p in l]
        for (ax, ay), (bx, by) in zip(xy, xy[1:]):
            n = max(1, int(math.hypot(bx - ax, by - ay) / (cell_m / 3)))
            for s in range(n + 1):
                cells.add((math.floor((ax + (bx - ax) * s / n) / cell_m), math.floor((ay + (by - ay) * s / n) / cell_m)))
    r = int(round(close_m / cell_m))
    disk = [(dx, dy) for dx in range(-r, r + 1) for dy in range(-r, r + 1) if dx * dx + dy * dy <= r * r]
    grown = {(x + dx, y + dy) for x, y in cells for dx, dy in disk}
    filled = _fill_holes(grown)   # i buchi interni (cortili, giardini) diventano pieni
    area = {c for c in filled if all((c[0] + dx, c[1] + dy) in filled for dx, dy in disk)} | cells
    # la parte connessa più grande
    seen, best = set(), set()
    for c in area:
        if c in seen:
            continue
        comp, todo = {c}, [c]
        seen.add(c)
        while todo:
            x, y = todo.pop()
            for d in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if d in area and d not in seen:
                    seen.add(d); comp.add(d); todo.append(d)
        if len(comp) > len(best):
            best = comp
    best = _fill_holes(best)
    # bordo: lati delle celle verso l'esterno, concatenati (senso antiorario, celle a sinistra)
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
    outer = max(loops, key=lambda l: abs(_signed_area(l)))
    return [back(x * cell_m, y * cell_m) for x, y in outer]


# --- varchi ---

def gates(elements, relation_ids=None, name_prefix="Varco", roles=("device", "from", "to"), skip=(), default_name="Varco ZTL"):
    """Varchi con coordinate. Dalle relazioni enforcement indicate (o da tutte) prende i nodi «device»
    (se manca, «from»/«to»); aggiunge i nodi sciolti con nome che inizia per name_prefix e
    man_made=surveillance. «skip»: id di relazioni/nodi da ignorare. Restituisce [(osm_id, name, lat, lon)]
    senza doppioni a meno di 15 m."""
    nodes = {e["id"]: e for e in elements if e["type"] == "node"}
    out = []
    for e in elements:
        if e["type"] != "relation" or e.get("tags", {}).get("type") != "enforcement" or e["id"] in skip:
            continue
        if relation_ids is not None and e["id"] not in relation_ids:
            continue
        ms = [m for m in e["members"] if m["type"] == "node" and m["role"] == "device"] or \
             [m for m in e["members"] if m["type"] == "node" and m["role"] in roles][:1]
        for m in ms:
            tags = nodes.get(m["ref"], {}).get("tags", {})
            name = tags.get("name") or default_name
            out.append((m["ref"], name, m["lat"], m["lon"]))
    if name_prefix:
        for n in nodes.values():
            t = n.get("tags", {})
            if n["id"] not in skip and t.get("man_made") == "surveillance" and t.get("name", "").startswith(name_prefix):
                out.append((n["id"], t["name"], n["lat"], n["lon"]))
    uniq = []
    for g in out:
        fwd, _ = _proj(g[2])
        if all(math.hypot(*(a - b for a, b in zip(fwd(g[3], g[2]), fwd(u[3], u[2])))) > 15 for u in uniq):
            uniq.append(g)
    return uniq


def gate_json(prefix, g):
    osm_id, name, lat, lon = g
    return {"id": f"{prefix}-osm{osm_id}", "name": name.strip(), "location": {"lat": round(lat, 6), "lon": round(lon, 6)}}


def convex_hull(points):
    """Inviluppo convesso (lon, lat) con il metodo della catena monotona"""
    pts = sorted(set(points))
    if len(pts) < 3:
        return pts
    def cross(o, a, b): return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0: lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0: upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def inside_lonlat(ring, lon, lat):
    inside = False
    for (x1, y1), (x2, y2) in zip(ring, ring[1:] + ring[:1]):
        if (y1 > lat) != (y2 > lat) and lon < (x2 - x1) * (lat - y1) / (y2 - y1) + x1:
            inside = not inside
    return inside
