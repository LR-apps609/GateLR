#!/usr/bin/env python3
# Arezzo: i perimetri della ZTL A e della ZTL B ricavati in automatico dalla mappa ufficiale del Comune
# «planimetria ztl aggiornata al 25_09_2025» (pagina «La planimetria ZTL»), salvata in
# data/raw/arezzo/planimetria-ztl-2025-09-25.pdf.
#
# La mappa è un PDF senza coordinate. Niente è disegnato a mano:
# 1. il PDF è trasformato in immagine (pdftoppm, 150 dpi, metà risoluzione dopo) e ogni pixel è classificato dal colore
#    secondo la legenda: tratteggio giallo = ZTL A, rosso = ZTL B, azzurro = aree pedonali, verde = area pedonale a
#    orario stabilito (via Seteria); le scritte e le righe delle strade dentro una zona prendono la zona attorno
#    (voto su una finestra di ~5 m, poi chiusura e riempimento dei buchi);
# 2. la mappa è agganciata alle coordinate con una trasformazione affine: prima tre piazze pedonali riconoscibili
#    (piazza Grande, piazza Sant'Agostino, piazza San Domenico: il centro del loro azzurro sulla mappa → il centro
#    della loro area in OpenStreetMap), poi si cerca la trasformazione con la massima sovrapposizione (IoU) tra
#    l'azzurro della mappa e le aree pedonali dell'allegato 3 del disciplinare mappate in OSM
#    (data/raw/geo/arezzo-streets.json); la trasformazione e l'IoU sono scritte nel file prodotto;
# 3. ogni parte separata della ZTL B (rosso + le piazze pedonali che racchiude) e della ZTL A (tratteggio + rosso +
#    azzurro: la ZTL B è dentro) diventa un poligono (solo il contorno esterno), semplificato a 2 m.
# Risultato: data/raw/arezzo/ztl-mappa-ufficiale.geojson, letto da Tools/build_arezzo.py.
#
# Serve numpy, Pillow e pdftoppm (poppler). Uso: python3 Tools/arezzo_mappa.py
import json, math, subprocess, tempfile
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
PDF = ROOT / "data/raw/arezzo/planimetria-ztl-2025-09-25.pdf"
OUT = ROOT / "data/raw/arezzo/ztl-mappa-ufficiale.geojson"
DPI, DOWN = 150, 2
LAT0, LON0 = 43.4640, 11.8800          # origine del piano locale in metri
# Aree pedonali dell'allegato 3 mappate in OSM come area con lo stesso nome (way id)
PED_OSM = [22720357, 184077925, 22719358, 1346063342, 617671811, 22719184, 22718505, 342536769, 342539250, 342536769,
           617669632]
# Ancore: (centro dell'azzurro sulla mappa in pixel a 150 dpi, way OSM). Il centro sulla mappa si ricalcola dal
# componente azzurro più vicino al punto indicato, quindi basta un punto qualunque della piazza.
ANCHORS = [((1191, 1538), [22720357]),            # piazza Grande
           ((708, 1614), [342536769, 342539250]),  # piazza Sant'Agostino
           ((1490, 886), [617671811])]             # piazza San Domenico
LEGEND = [(0, 0, 470, 720), (0, 1880, 470, 2482), (0, 0, 900, 240)]   # riquadri (x0, y0, x1, y1) a 150 dpi con legenda ed elenchi dei varchi


# --- strumenti raster (solo numpy) ---

def dilate(m, r):
    for _ in range(r):
        n = m.copy(); n[1:] |= m[:-1]; n[:-1] |= m[1:]; n[:, 1:] |= m[:, :-1]; n[:, :-1] |= m[:, 1:]; m = n
    return m


def erode(m, r):
    return ~dilate(~m, r)


def box_sum(m, r):
    c = np.pad(m.astype(np.int32), ((r + 1, r), (r + 1, r))).cumsum(0).cumsum(1)
    return c[2 * r + 1:, 2 * r + 1:] - c[:-2 * r - 1, 2 * r + 1:] - c[2 * r + 1:, :-2 * r - 1] + c[:-2 * r - 1, :-2 * r - 1]


def components(mask):
    """Componenti 4-connesse: (etichette, dimensioni); etichetta 0 = fuori dalla maschera"""
    h, w = mask.shape
    flat, lab, n, sizes = mask.ravel().tolist(), [0] * (h * w), 0, [0]
    for s in range(h * w):
        if flat[s] and not lab[s]:
            n += 1; lab[s] = n; st = [s]; c = 0
            while st:
                p = st.pop(); c += 1; x = p % w
                for q in (p - w, p + w, p - 1 if x else -1, p + 1 if x < w - 1 else -1):
                    if 0 <= q < h * w and flat[q] and not lab[q]:
                        lab[q] = n; st.append(q)
            sizes.append(c)
    return np.array(lab, np.int32).reshape(h, w), np.array(sizes)


def fill_holes(m):
    l, _ = components(~m)
    border = set(np.unique(np.concatenate([l[0], l[-1], l[:, 0], l[:, -1]]))) - {0}
    return ~np.isin(l, sorted(border))


def outline(mask):
    """Contorno esterno (lati dei pixel) di una maschera connessa, come lista di (colonna, riga)"""
    best = {(x, y) for y, x in zip(*np.nonzero(mask))}
    nxt = {}
    for x, y in best:
        if (x, y - 1) not in best: nxt.setdefault((x, y), []).append((x + 1, y))
        if (x + 1, y) not in best: nxt.setdefault((x + 1, y), []).append((x + 1, y + 1))
        if (x, y + 1) not in best: nxt.setdefault((x + 1, y + 1), []).append((x, y + 1))
        if (x - 1, y) not in best: nxt.setdefault((x, y + 1), []).append((x, y))
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
    area = lambda l: abs(sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(l, l[1:])))
    return max(loops, key=area)


# --- 1. classificazione ---

def classify():
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run(["pdftoppm", "-r", str(DPI), "-png", "-singlefile", str(PDF), f"{tmp}/m"], check=True)
        a = np.asarray(Image.open(f"{tmp}/m.png").convert("RGB")).astype(np.int16)
    for x0, y0, x1, y1 in LEGEND:
        a[y0:y1, x0:x1] = 255
    R, G, B = a[..., 0], a[..., 1], a[..., 2]
    gate = (R >= 220) & (G >= 220) & (B <= 60)                          # i quadrati gialli dei varchi
    yellow = (R >= 200) & (G >= 150) & (R - B >= 40) & (G - B >= 30) & ~gate
    red = (R >= 200) & (G <= 130) & (B <= 100)
    blue = (B >= 200) & (R <= 80) & (G >= 140) & (G <= 220)
    green = (G >= 200) & (R <= 80) & (B <= 80)
    a_m = box_sum(yellow, 4) >= 12                                     # il tratteggio: almeno 12 pixel gialli su 81
    b_m = box_sum(red, 3) >= 12
    p_m = box_sum(blue | green, 2) >= 8
    h, w = a_m.shape
    down = lambda m: m[:h // DOWN * DOWN:DOWN, :w // DOWN * DOWN:DOWN].copy()
    lines_px = (a.max(-1) - a.min(-1) < 30) & (a.max(-1) < 190)          # righe grigie e nere (strade, scritte)
    return down(a_m), down(b_m), down(p_m), down(blue), down(lines_px)


# --- 2. aggancio ---

def local(lon, lat):
    fwd, _ = osm_geo._proj(LAT0)
    x, y = fwd(lon, lat); x0, y0 = fwd(LON0, LAT0)
    return x - x0, y - y0


def to_lonlat(x, y):
    fwd, back = osm_geo._proj(LAT0)
    x0, y0 = fwd(LON0, LAT0)
    return back(x + x0, y + y0)


def register(blue, lines_px):
    """Prima le tre piazze (similitudine ai minimi quadrati), poi la trasformazione affine che porta le righe grigie
    delle strade disegnate sulla mappa più vicino alle strade di OSM (distanza media, troncata a D metri)"""
    elements = osm_geo.load("arezzo-streets")
    ways = {e["id"]: e for e in elements if e["type"] == "way"}
    lab, _ = components(blue)
    A, b = [], []
    for (cx, cy), ids in ANCHORS:
        cx, cy = cx // DOWN, cy // DOWN
        ys, xs = np.nonzero(lab)
        k = np.argmin((xs - cx) ** 2 + (ys - cy) ** 2)
        yy, xx = np.nonzero(lab == lab[ys[k], xs[k]])
        c, r = xx.mean(), yy.mean()
        pts = [local(n["lon"], n["lat"]) for i in ids for n in ways[i]["geometry"]]
        X, Y = sum(q[0] for q in pts) / len(pts), sum(q[1] for q in pts) / len(pts)
        A += [[c, r, 1, 0], [-r, c, 0, 1]]; b += [X, Y]       # similitudine (l'asse delle righe va verso il basso)
    aa, bb, tx, ty = np.linalg.lstsq(np.array(A, float), np.array(b, float), rcond=None)[0]
    p = [aa, bb, tx, bb, -aa, ty]

    streets = [[local(n["lon"], n["lat"]) for n in e["geometry"]] for e in elements if e["type"] == "way" and "highway" in e["tags"]]
    allx = [q[0] for l in streets for q in l]; ally = [q[1] for l in streets for q in l]
    ox, oy = min(allx), max(ally)
    W, H = int(max(allx) - ox) + 1, int(oy - min(ally)) + 1
    img = Image.new("L", (W, H), 0)
    for l in streets:
        ImageDraw.Draw(img).line([(x - ox, oy - y) for x, y in l], fill=1, width=2)
    D = 20
    dist, cur = np.full((H, W), D, np.float32), np.asarray(img, bool)
    for r in range(D):
        dist[cur & (dist == D)] = r
        cur = dilate(cur, 1)
    ys, xs = np.nonzero(lines_px)
    k = np.random.default_rng(0).choice(len(xs), min(60000, len(xs)), replace=False)
    xs, ys = xs[k].astype(float), ys[k].astype(float)

    def cost(p):
        x = p[0] * xs + p[1] * ys + p[2]; y = p[3] * xs + p[4] * ys + p[5]
        i, j = (x - ox).astype(int), (oy - y).astype(int)
        ok = (i >= 0) & (i < W) & (j >= 0) & (j < H)
        v = np.full(len(x), D, np.float32); v[ok] = dist[j[ok], i[ok]]
        return float(v.mean()), float((v <= 3).mean())

    best = cost(p)[0]
    steps = [0.01, 0.01, 4.0, 0.01, 0.01, 4.0]
    for _ in range(8):
        improved = True
        while improved:
            improved = False
            for k in range(6):
                for s in (1, -1):
                    q = list(p); q[k] += s * steps[k]
                    v = cost(q)[0]
                    if v < best - 1e-5:
                        p, best, improved = q, v, True
        steps = [s / 2 for s in steps]
    return p, cost(p)


def ring_lonlat(mask, p):
    pts = outline(mask)
    ring = [to_lonlat(p[0] * x + p[1] * y + p[2], p[3] * x + p[4] * y + p[5]) for x, y in pts]
    return [[round(q[0], 7), round(q[1], 7)] for q in osm_geo.simplify_m(ring, 2.0)]


def main():
    a_m, b_m, p_m, blue, lines_px = classify()
    p, (mean_d, near) = register(blue, lines_px)
    scale = math.sqrt(abs(p[0] * p[4] - p[1] * p[3]))
    print(f"aggancio: distanza media righe della mappa → strade OSM {mean_d:.2f} m (troncata a 20), {near:.0%} entro 3 m, {scale:.2f} m per pixel")
    min_px = int(2500 / scale ** 2)                       # parti più piccole di 2500 m² (simboli, scritte) scartate
    b_all = fill_holes(erode(dilate(b_m, 2), 2))
    b_all = fill_holes(b_all | (p_m & dilate(b_all, 3)))   # le piazze pedonali dentro la ZTL B
    a_all = fill_holes(erode(dilate(a_m, 3), 3) | b_all | p_m)   # chiusura solo sul tratteggio: via Roma resta fuori
    feats = []
    for zone, mask in (("B", b_all), ("A", a_all)):
        lab, sizes = components(mask)
        for n in np.argsort(-sizes):
            if n == 0 or sizes[n] < min_px:
                continue
            part = lab == n
            if zone == "A" and (a_m & part).sum() < 0.2 * part.sum():   # solo rosso: è la ZTL B a sud di via Roma
                continue
            ring = ring_lonlat(part, p)
            feats.append({"type": "Feature", "properties": {"zone": zone, "area_m2": round(float(part.sum()) * scale ** 2)},
                          "geometry": {"type": "Polygon", "coordinates": [ring]}})
    out = {"type": "FeatureCollection",
           "source": "Comune di Arezzo, planimetria ztl aggiornata al 25_09_2025 (" + PDF.name + "), agganciata con Tools/arezzo_mappa.py",
           "registration": {"affine_pixel_to_local_m": [round(v, 6) for v in p], "pixel_dpi": DPI / DOWN,
                            "origin_lonlat": [LON0, LAT0], "mean_distance_m": round(mean_d, 2), "share_within_3m": round(near, 3)},
           "features": feats}
    OUT.write_text(json.dumps(out, ensure_ascii=False) + "\n", encoding="utf-8")
    print(OUT.name, [(f["properties"]["zone"], f["properties"]["area_m2"], len(f["geometry"]["coordinates"][0])) for f in feats])


if __name__ == "__main__":
    main()
