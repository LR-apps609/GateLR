#!/usr/bin/env python3
# Vicenza: perimetro della ZTL e posizione dei varchi ricavati in automatico dalla mappa ufficiale del Comune
# «Mappa ZTL con varchi» (pagina del 14/11/2023, immagine Mappa-Ztl_reference.jpg, 1754×1239 px), salvata in
# data/raw/vicenza/mappa-ztl-varchi.jpg. La mappa non ha coordinate. Niente è disegnato a mano:
# 1. ogni pixel è classificato dal colore: rosso = bordo della ZTL, giallo = isolati in ZTL, azzurro = fiumi,
#    blu pieno = varchi d'ingresso (pallini), verde = varchi d'uscita (pallini); la legenda (x ≥ 1262) è esclusa;
# 2. la mappa è agganciata alle coordinate con una similitudine (scala, rotazione, traslazione) che sovrappone i fiumi
#    disegnati (Bacchiglione, Retrone, Seriola) alle aree d'acqua di OpenStreetMap (data/raw/geo/vicenza-centro.json):
#    ricerca a griglia (tolleranza 30 m) e poi locale (tolleranza 6 m) della trasformazione con la massima sovrapposizione (F1);
# 3. la ZTL è l'insieme degli isolati gialli e del bordo rosso, chiuso morfologicamente (10 px ≈ 8 m) sulle strade interne,
#    con le piazze interne riempite; più grande componente; contorno semplificato a 3 m (il bordo rosso ha interruzioni
#    sotto i simboli dei varchi e le scritte, quindi non si usa da solo come muro);
# 4. i varchi sono i centri dei pallini blu (ingresso) e verdi (uscita) (maschere erose di 3 px: restano i pallini pieni),
#    portati in coordinate.
# Risultato: data/raw/vicenza/ztl-mappa-ufficiale.geojson (con la trasformazione e il punteggio), letto da
# Tools/build_vicenza.py. Serve numpy e Pillow. Uso: python3 Tools/vicenza_mappa.py
import json, math
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
IMG = ROOT / "data/raw/vicenza/mappa-ztl-varchi.jpg"
OUT = ROOT / "data/raw/vicenza/ztl-mappa-ufficiale.geojson"
LEGEND_X = 1262
LAT0, LON0 = 45.5470, 11.5450                       # origine del piano locale in metri
KX, KY = 111320.0 * math.cos(math.radians(LAT0)), 110574.0


def to_m(lon, lat):
    return (lon - LON0) * KX, (lat - LAT0) * KY


def to_ll(x, y):
    return LON0 + x / KX, LAT0 + y / KY


# --- 1. classificazione dei colori ---
im = np.asarray(Image.open(IMG).convert("RGB")).astype(int)
H, Wd = im.shape[:2]
R, G, B = im[..., 0], im[..., 1], im[..., 2]
valid = np.zeros((H, Wd), bool); valid[:, :LEGEND_X] = True
red = (R > 190) & (G < 70) & (B < 70) & valid
river = (abs(R - 120) < 40) & (abs(G - 190) < 30) & (B > 215) & valid
blue = (R < 60) & (G < 60) & (B > 190) & valid
green = (R < 130) & (G > 140) & (B < 60) & valid


def dilate(m, r):
    for _ in range(r):
        n = m.copy(); n[1:] |= m[:-1]; n[:-1] |= m[1:]; n[:, 1:] |= m[:, :-1]; n[:, :-1] |= m[:, 1:]; m = n
    return m


def components(mask):
    """Componenti 4-connesse come liste di (y, x)"""
    seen = np.zeros(mask.shape, bool); out = []
    ys, xs = np.nonzero(mask)
    for y0, x0 in zip(ys.tolist(), xs.tolist()):
        if seen[y0, x0]:
            continue
        st, comp = [(y0, x0)], []
        seen[y0, x0] = True
        while st:
            y, x = st.pop(); comp.append((y, x))
            for yy, xx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= yy < mask.shape[0] and 0 <= xx < mask.shape[1] and mask[yy, xx] and not seen[yy, xx]:
                    seen[yy, xx] = True; st.append((yy, xx))
        out.append(comp)
    return out


# --- 2. aggancio: fiumi della mappa ↔ acque OSM ---
GEO = osm_geo.load("vicenza-centro")
water_polys = []
for e in GEO:
    t = e.get("tags", {})
    if t.get("natural") != "water" and t.get("waterway") != "riverbank":
        continue
    if e["type"] == "way" and len(e.get("geometry", [])) >= 4:
        water_polys.append([to_m(p["lon"], p["lat"]) for p in e["geometry"]])
    elif e["type"] == "relation":
        for m in e["members"]:
            if m["type"] == "way" and m.get("role") == "outer" and len(m.get("geometry", [])) >= 2:
                water_polys.append([to_m(p["lon"], p["lat"]) for p in m["geometry"]])
CELL = 2.0
GX0, GY0, GN = -2000.0, -2000.0, 2000                # griglia 4 km × 4 km, celle di 2 m
grid_img = Image.new("1", (GN, GN), 0)
dr = ImageDraw.Draw(grid_img)
for poly in water_polys:
    dr.polygon([((x - GX0) / CELL, (GN - 1) - (y - GY0) / CELL) for x, y in poly], fill=1)
water = np.asarray(grid_img, bool)
TOL = {"coarse": (dilate(water, 15), None), "fine": (dilate(water, 3), None)}   # tolleranza 30 m, poi 6 m
ry, rx = np.nonzero(river)
rng = np.random.default_rng(0)
pick = rng.choice(len(rx), size=min(4000, len(rx)), replace=False)
PX, PY = rx[pick].astype(float), ry[pick].astype(float)
TOL["coarse"] = (TOL["coarse"][0], dilate(river, 20)); TOL["fine"] = (TOL["fine"][0], dilate(river, 4))


def transform(params, x, y):
    s, th, tx, ty = params
    c, sn = math.cos(th), math.sin(th)
    X, Y = x - Wd / 2, (H / 2) - y                   # y dell'immagine verso il basso
    return tx + s * (c * X - sn * Y), ty + s * (sn * X + c * Y)


def inverse(params, mx, my):
    s, th, tx, ty = params
    c, sn = math.cos(th), math.sin(th)
    X, Y = (mx - tx) / s, (my - ty) / s
    x, y = c * X + sn * Y, -sn * X + c * Y
    return x + Wd / 2, (H / 2) - y


def cells(mx, my):
    i = ((GN - 1) - (my - GY0) / CELL).astype(int); j = ((mx - GX0) / CELL).astype(int)
    ok = (i >= 0) & (i < GN) & (j >= 0) & (j < GN)
    return i, j, ok


wy, wx = np.nonzero(water)
WMX, WMY = GX0 + wx * CELL, GY0 + ((GN - 1) - wy) * CELL
wpick = rng.choice(len(WMX), size=min(6000, len(WMX)), replace=False)
WMX, WMY = WMX[wpick], WMY[wpick]


def score(params, level="fine"):
    water_tol, river_tol = TOL[level]
    mx, my = transform(params, PX, PY)
    i, j, ok = cells(mx, my)
    prec = (water_tol[i[ok], j[ok]].sum() / len(PX)) if ok.any() else 0.0
    # richiamo: le acque OSM che cadono dentro la mappa devono essere fiume anche sulla mappa
    x, y = inverse(params, WMX, WMY)
    inside = (x >= 0) & (x < LEGEND_X) & (y >= 0) & (y < H)
    if inside.sum() < 200:
        return 0.0
    rec = river_tol[y[inside].astype(int), x[inside].astype(int)].mean()
    return 2 * prec * rec / (prec + rec + 1e-9)


best = (0, None)
for s in np.arange(0.6, 1.81, 0.04):                  # mappa orientata a nord: la rotazione si cerca dopo, localmente
    for tx in np.arange(-900, 901, 20):
        for ty in np.arange(-900, 901, 20):
            f = score((s, 0.0, tx, ty), "coarse")
            if f > best[0]:
                best = (f, (s, 0.0, tx, ty))
p = tuple(float(v) for v in best[1])
f = score(p)
step = [0.02, math.radians(1.0), 10.0, 10.0]
for _ in range(7):
    improved = True
    while improved:
        improved = False
        for k in range(4):
            for d in (-1, 1):
                q = list(p); q[k] += d * step[k]
                g = score(tuple(q))
                if g > f:
                    f, p, improved = g, tuple(q), True
    step = [x / 2 for x in step]
print(f"aggancio: scala {p[0]:.3f} m/px, rotazione {math.degrees(p[1]):.2f}°, traslazione {p[2]:.0f} m, {p[3]:.0f} m, F1 fiumi {f:.3f}")
if f < 0.75:
    raise SystemExit("La mappa non si aggancia bene ai fiumi di OSM: ricontrollare")

# --- 3. area della ZTL: isolati gialli e bordo rosso, chiusi sulle strade interne ---
yellow = (R > 215) & (abs(G - 212) < 22) & (B > 70) & (B < 175) & valid
CLOSE = 10                                            # ~8 m: chiude le strade interne (larghe fino a ~17 m)
mass = ~dilate(~dilate(yellow | red, CLOSE), CLOSE)   # chiusura morfologica
outside = np.zeros((H, Wd), bool)
st = [(0, 0)]; outside[0, 0] = True
while st:
    y, x = st.pop()
    for yy, xx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
        if 0 <= yy < H and 0 <= xx < Wd and not outside[yy, xx] and not mass[yy, xx]:
            outside[yy, xx] = True; st.append((yy, xx))
inner = ~outside & valid                              # con i buchi riempiti (piazze interne)
comps = sorted(components(inner), key=len, reverse=True)
zone = np.zeros((H, Wd), bool)
for y, x in comps[0]:
    zone[y, x] = True
print("componenti interne:", [len(c) for c in comps[:5]])

# contorno: lati dei pixel verso l'esterno, concatenati
nxt = {}
ys, xs = np.nonzero(zone)
Z = set(zip(xs.tolist(), ys.tolist()))
for x, y in Z:
    if (x, y - 1) not in Z: nxt.setdefault((x, y), []).append((x + 1, y))
    if (x + 1, y) not in Z: nxt.setdefault((x + 1, y), []).append((x + 1, y + 1))
    if (x, y + 1) not in Z: nxt.setdefault((x + 1, y + 1), []).append((x, y + 1))
    if (x - 1, y) not in Z: nxt.setdefault((x, y + 1), []).append((x, y))
loops = []
while nxt:
    start = next(iter(nxt)); loop, cur = [start], start
    while True:
        cur = nxt[cur].pop()
        if not nxt[loop[-1]]:
            del nxt[loop[-1]]
        if cur == start:
            break
        loop.append(cur)
    loops.append(loop + [start])
outer = max(loops, key=len)
ring = []
for x, y in outer:
    mx, my = transform(p, np.array([float(x)]), np.array([float(y)]))
    ring.append(to_ll(float(mx[0]), float(my[0])))
ring = osm_geo.simplify_m(ring, 3.0)


# --- 4. varchi: pallini pieni blu (ingresso) e verdi (uscita) ---
def erode(m, r):
    return ~dilate(~m, r)


def dots():
    """Pallini pieni (nuclei che restano dopo l'erosione di 3 px): ingresso se contengono blu, uscita se verde
    (i varchi di ingresso e uscita nello stesso punto hanno il pallino metà blu e metà verde)"""
    out = []
    for c in components(erode(blue | green, 3)):
        if not 8 <= len(c) <= 600:
            continue
        cy = sum(y for y, _ in c) / len(c); cx = sum(x for _, x in c) / len(c)
        h = max(y for y, _ in c) - min(y for y, _ in c) + 1; w = max(x for _, x in c) - min(x for _, x in c) + 1
        if not (len(c) / (h * w) > 0.5 and 0.4 < h / w < 2.5):    # pieno e compatto
            continue
        kinds = [k for k, m in (("entry", blue), ("exit", green)) if any(m[y, x] for y, x in c)]
        mx, my = transform(p, np.array([cx]), np.array([cy]))
        lon, lat = to_ll(float(mx[0]), float(my[0]))
        out.append({"px": [round(float(cx), 1), round(float(cy), 1)], "lat": round(lat, 6), "lon": round(lon, 6), "kinds": kinds})
    return out


found = dots()
entries = [d for d in found if "entry" in d["kinds"]]; exits = [d for d in found if "exit" in d["kinds"]]
print("varchi d'ingresso:", len(entries), "d'uscita:", len(exits), "area km²:", round(osm_geo.area_km2(ring), 3))
OUT.write_text(json.dumps({
    "type": "FeatureCollection",
    "source": "Comune di Vicenza, «Mappa ZTL con varchi» (Mappa-Ztl_reference.jpg), georeferenziata sui fiumi OSM",
    "transform": {"scale_m_per_px": round(p[0], 4), "rotation_deg": round(math.degrees(p[1]), 3), "tx_m": round(p[2], 1),
                  "ty_m": round(p[3], 1), "origin": [LAT0, LON0], "rivers_f1": round(f, 3)},
    "features": [{"type": "Feature", "properties": {"name": "ZTL Vicenza"},
                  "geometry": {"type": "Polygon", "coordinates": [[[round(a, 6), round(b, 6)] for a, b in ring]]}}]
                + [{"type": "Feature", "properties": {"kinds": d["kinds"], "px": d["px"]}, "geometry": {"type": "Point", "coordinates": [d["lon"], d["lat"]]}}
                   for d in found]}, ensure_ascii=False) + "\n", encoding="utf-8")
print(OUT.relative_to(ROOT))
