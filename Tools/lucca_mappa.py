#!/usr/bin/env python3
# Lucca: i perimetri della ZTL A e della ZTL B ricavati in automatico dalla mappa ufficiale del Comune
# «ZTL e parcheggi nel Centro Storico aggiornato al 25.11.2025» (la stessa della Figura 1 del Disciplinare
# di febbraio 2026 e dell'allegato 4 alla delibera GC 340/2025), salvata in data/raw/lucca/mappa-ztl-dicembre-2025.pdf.
#
# La mappa è un PDF AutoCAD senza coordinate. Niente è disegnato a mano:
# 1. il PDF è trasformato in immagine (pdftoppm, 150 dpi) e ogni pixel è classificato dal suo colore:
#    verde = «ZTL A (Zona Pedonale)», giallo = «ZTL B», bianco = «ZTL C» o fuori ZTL (legenda della mappa);
#    i tratteggi degli edifici, le scritte e i simboli (varchi, frecce, stalli) non votano: prendono la classe vicina;
# 2. la mappa è agganciata alle coordinate con una trasformazione affine che sovrappone il contorno esterno delle
#    Mura disegnato sulla mappa (verde, bastioni compresi) al contorno esterno delle Mura in OpenStreetMap
#    (relazione 19549900, data/raw/geo/lucca-ztl.json): si cerca la trasformazione con la massima
#    sovrapposizione (IoU), che viene scritta nel file prodotto;
# 3. le Mura (verdi sulla mappa: vi valgono le norme della ZTL A, Disciplinare § 7) sono tolte dalla ZTL A, così le
#    porte (Porta Elisa, Porta San Pietro...) che le attraversano non risultano «dentro la ZTL A»: è Mura un pixel verde
#    a meno di WALL_MIN_PX dal bordo esterno, oppure a meno di WALL_PX se la sua striscia verde (bordo esterno → primo
#    pixel non verde verso l'interno) è larga meno di WALL_PX; dei pezzi verdi che restano si tengono il più grande
#    (il centro pedonale) e quelli che non toccano le Mura (es. piazza San Francesco), non i resti dei bastioni;
# 4. le aree verdi e gialle diventano poligoni (con i buchi), semplificati a 2 m.
# Risultato: data/raw/lucca/ztl-mappa-ufficiale.geojson, letto da Tools/build_lucca.py.
#
# Serve numpy, Pillow e pdftoppm (poppler). Uso: python3 Tools/lucca_mappa.py
import json, math, subprocess, sys, tempfile
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
PDF = ROOT / "data/raw/lucca/mappa-ztl-dicembre-2025.pdf"
OUT = ROOT / "data/raw/lucca/ztl-mappa-ufficiale.geojson"
OSM_A = 19549900          # «ZTL A» in OSM: il suo contorno esterno è il bordo esterno delle Mura
WALL_PX = 60             # ~65 m: più larga di così una striscia verde non è Mura
WALL_MIN_PX = 35         # ~38 m: così vicino al bordo esterno è sempre Mura
DPI, DOWN = 150, 2        # pixel della mappa: ~0,55 m a 150 dpi, ~1,1 m dopo il dimezzamento
U, A, B, S, NONE = 0, 1, 2, 3, 9
Image.MAX_IMAGE_PIXELS = None


# --- strumenti raster (solo numpy) ---

def dilate(m, r):
    for _ in range(r):
        n = m.copy(); n[1:] |= m[:-1]; n[:-1] |= m[1:]; n[:, 1:] |= m[:, :-1]; n[:, :-1] |= m[:, 1:]; m = n
    return m


def erode(m, r):
    return ~dilate(~m, r)


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


def nn_fill(lab, allowed):
    """I pixel NONE prendono la classe del vicino (tra quelle permesse), un passo alla volta"""
    lab = lab.copy()
    shifts = [((slice(1, None),), (slice(None, -1),)), ((slice(None, -1),), (slice(1, None),)),
              ((slice(None), slice(1, None)), (slice(None), slice(None, -1))),
              ((slice(None), slice(None, -1)), (slice(None), slice(1, None)))]
    while True:
        before = int((lab == NONE).sum())
        for dst_s, src_s in shifts:
            src, dst = lab[src_s], lab[dst_s]
            m = (dst == NONE) & np.isin(src, allowed)
            dst[m] = src[m]
        after = int((lab == NONE).sum())
        if after == 0 or after == before:
            return lab


def box_sum(m, r):
    c = np.pad(m.astype(np.int32), ((r + 1, r), (r + 1, r))).cumsum(0).cumsum(1)
    return c[2 * r + 1:, 2 * r + 1:] - c[:-2 * r - 1, 2 * r + 1:] - c[2 * r + 1:, :-2 * r - 1] + c[:-2 * r - 1, :-2 * r - 1]


# --- 1. classificazione dei colori ---

def classify():
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run(["pdftoppm", "-r", str(DPI), "-png", "-singlefile", str(PDF), f"{tmp}/m"], check=True)
        a = np.asarray(Image.open(f"{tmp}/m.png").convert("RGB")).astype(np.int16)
    R, G, Bl = a[..., 0], a[..., 1], a[..., 2]
    mx, mn = a.max(-1), a.min(-1)
    sym = (((Bl >= R + 60) & (Bl >= 150)) | ((R >= G + 60) & (Bl >= G + 40)) | ((Bl >= G + 50) & (R >= G + 30))
           | ((R >= 170) & (G <= 90) & (Bl <= 90)) | ((R >= 190) & (G * 4 < R * 3) & (Bl < 100) & (G > 60)))
    green = (G >= R + 10) & (G + 5 >= Bl) & (mx - mn > 12) & ~sym            # verde ZTL A (anche sotto il tratteggio)
    yellow = (R >= Bl + 25) & (G >= Bl + 15) & (R + 5 >= G) & ~sym            # giallo ZTL B (non l'arancio degli stalli)
    white = (mn >= 236) & (mx - mn <= 12)                                     # bianco: ZTL C o fuori ZTL
    v = np.stack([box_sum(white, 4), box_sum(green, 4), box_sum(yellow, 4)], -1)   # voto su ~5 m
    lab = v.argmax(-1).astype(np.uint8)
    lab[v.sum(-1) == 0] = NONE
    lab[sym & (v.max(-1) < 20)] = S
    h, w = lab.shape
    return lab[:h // DOWN * DOWN:DOWN, :w // DOWN * DOWN:DOWN].copy()


# --- 2. aggancio alle coordinate ---

def register(lab, lat0):
    big_a = erode(dilate(lab == A, 8), 8)                  # chiude i passaggi stretti (porte) solo per il contorno
    l, s = components(big_a)
    inside = fill_holes(l == (s[1:].argmax() + 1))         # le Mura e tutto ciò che sta dentro
    fwd, _ = osm_geo._proj(lat0); x0, y0 = fwd(10.5, lat0)
    ring = [(fwd(*p)[0] - x0, fwd(*p)[1] - y0) for p in osm_geo.outer_ring(osm_geo.relation(osm_geo.load("lucca-ztl"), OSM_A))]
    xs, ys = [p[0] for p in ring], [p[1] for p in ring]
    ox, oy = min(xs) - 200, max(ys) + 200
    ow, oh = int(max(xs) - min(xs) + 400), int(max(ys) - min(ys) + 400)
    img = Image.new("1", (ow, oh), 0)
    ImageDraw.Draw(img).polygon([(x - ox, oy - y) for x, y in ring], fill=1)
    O = np.asarray(img, bool); o_area = float(O.sum())
    H, W = lab.shape
    gr, gc = np.mgrid[0:H:2, 0:W:2]; gr, gc = gr.ravel(), gc.ravel(); in_m = inside[gr, gc]

    def iou(p):
        x = p[0] * gc + p[1] * gr + p[2]; y = p[3] * gc + p[4] * gr + p[5]
        i, j = (x - ox).astype(int), (oy - y).astype(int)
        ok = (i >= 0) & (i < ow) & (j >= 0) & (j < oh)
        in_o = np.zeros(len(x), bool); in_o[ok] = O[j[ok], i[ok]]
        cell = abs(p[0] * p[4] - p[1] * p[3]) * 4
        inter = (in_m & in_o).sum() * cell
        return inter / (in_m.sum() * cell + o_area - inter)

    rows, cols = np.nonzero(inside)
    sx = (max(xs) - min(xs)) / (cols.max() - cols.min()); sy = (max(ys) - min(ys)) / (rows.max() - rows.min())
    p = np.array([sx, 0.0, min(xs) - sx * cols.min(), 0.0, -sy, max(ys) + sy * rows.min()])
    best = iou(p); steps = np.array([0.01 * sx, 0.01 * sx, 20, 0.01 * sx, 0.01 * sx, 20])
    while steps[2] >= 0.05:                                  # discesa per coordinate, passo dimezzato
        improved = False
        for k in range(6):
            for sgn in (1, -1):
                q = p.copy(); q[k] += sgn * steps[k]; v = iou(q)
                if v > best: best, p, improved = v, q, True
        if not improved:
            steps /= 2
    return inside, p, best


# --- 3. pulizia e poligoni ---

def clean(lab, inside):
    lab = lab.copy()
    lab[~inside] = U
    lab[lab == NONE] = S
    us = (lab == U) | (lab == S)
    l, s = components(us & inside)
    touch = set(np.unique(l[dilate(~inside, 1) & us])) - {0}
    # piccole sacche bianche chiuse dentro le Mura (l'interno dei simboli dei varchi, le scritte): non sono strade
    lab[np.isin(l, [k for k in range(1, len(s)) if s[k] < 2500 and k not in touch])] = NONE
    lab = nn_fill(lab, [A, B])
    lab[lab == S] = NONE
    lab = nn_fill(lab, [U, A, B])
    for k in (A, B):                                           # macchioline (contrassegni, simboli) sotto ~250 m²
        l, s = components(lab == k)
        lab[np.isin(l, [i for i in range(1, len(s)) if s[i] < 200])] = NONE
    lab = nn_fill(lab, [U, A, B])
    lab[~inside] = U
    return lab


def dist_from(seed, limit=250):
    """Distanza in pixel dai pixel «seed» (metrica ottagonale: passi a croce e a quadrato alternati)"""
    d = np.full(seed.shape, limit, np.int32); d[seed] = 0; cur = seed.copy()
    for k in range(1, limit):
        n = cur.copy(); n[1:] |= cur[:-1]; n[:-1] |= cur[1:]; n[:, 1:] |= cur[:, :-1]; n[:, :-1] |= cur[:, 1:]
        if k % 2 == 0:
            n[1:, 1:] |= cur[:-1, :-1]; n[:-1, :-1] |= cur[1:, 1:]; n[1:, :-1] |= cur[:-1, 1:]; n[:-1, 1:] |= cur[1:, :-1]
        d[n & ~cur] = k; cur = n
        if cur.all(): break
    return d


def without_walls(lab, inside):
    """La ZTL A senza le Mura: vedi il punto 3 in cima al file"""
    a = lab == A
    d_out, d_in = dist_from(~inside), dist_from(inside & ~a)
    walls = a & ((d_out <= WALL_MIN_PX) | ((d_out <= WALL_PX) & (d_out + d_in <= WALL_PX)))
    l, s = components(a & ~walls)
    near = set(np.unique(l[dilate(walls, 1)]).tolist()) - {0}
    biggest = int(s[1:].argmax()) + 1
    keep = [k for k in range(1, len(s)) if s[k] >= 200 and (k == biggest or k not in near)]
    core = np.isin(l, keep)
    lab = lab.copy(); lab[a & ~core] = U
    return lab, int((a & ~core).sum())


def loops(mask):
    """Tutti i bordi della maschera (lati dei pixel concatenati), come liste di vertici (col, riga)"""
    nxt = {}
    ys, xs = np.nonzero(mask)
    cells = set(zip(xs.tolist(), ys.tolist()))
    for x, y in cells:
        if (x, y - 1) not in cells: nxt.setdefault((x, y), []).append((x + 1, y))
        if (x + 1, y) not in cells: nxt.setdefault((x + 1, y), []).append((x + 1, y + 1))
        if (x, y + 1) not in cells: nxt.setdefault((x + 1, y + 1), []).append((x, y + 1))
        if (x - 1, y) not in cells: nxt.setdefault((x, y + 1), []).append((x, y))
    out = []
    while nxt:
        start = next(iter(nxt)); loop, cur = [start], start
        while True:
            cur = nxt[loop[-1]].pop()
            if not nxt[loop[-1]]: del nxt[loop[-1]]
            if cur == start: break
            loop.append(cur)
        out.append(loop)
    return out


def main():
    lat0 = 43.842
    lab = classify()
    inside, p, score = register(lab, lat0)
    print(f"aggancio: IoU {score:.4f} con il contorno delle Mura in OSM")
    if score < 0.97:
        raise SystemExit("Aggancio della mappa troppo incerto (IoU < 0,97)")
    lab = clean(lab, inside)
    lab, walls_px = without_walls(lab, inside)
    cell_m2 = abs(p[0] * p[4] - p[1] * p[3])
    print(f"Mura tolte dalla ZTL A: {walls_px * cell_m2 / 1e6:.3f} km²")
    fwd, back = osm_geo._proj(lat0); x0, y0 = fwd(10.5, lat0)

    def lonlat(c, r):
        c, r = c - 0.5, r - 0.5                                   # dal vertice del pixel al centro usato nell'aggancio
        return back(p[0] * c + p[1] * r + p[2] + x0, p[3] * c + p[4] * r + p[5] + y0)

    feats = []
    for k, zid, name in [(A, "lucca-a", "ZTL A (Zona Pedonale)"), (B, "lucca-b", "ZTL B")]:
        rings = []
        for lp in loops(lab == k):
            ring = [lonlat(c, r) for c, r in lp]; ring.append(ring[0])
            ring = osm_geo.simplify_m(ring, 2.0)
            if len(ring) >= 4 and osm_geo.area_km2(ring) * 1e6 >= 150:
                rings.append([[round(x, 6), round(y, 6)] for x, y in ring])
        # il verso dice chi è un contorno esterno e chi un buco (il più grande è sempre esterno)
        rings.sort(key=osm_geo.area_km2, reverse=True)
        sign = _signed(rings[0]) > 0
        polys = [[r] for r in rings if (_signed(r) > 0) == sign]
        for h in (r for r in rings if (_signed(r) > 0) != sign):
            hosts = [pl for pl in polys if osm_geo.contains(pl[0], h[0][1], h[0][0])]
            if not hosts:
                raise SystemExit(f"{zid}: un buco non sta in nessun contorno")
            min(hosts, key=lambda pl: osm_geo.area_km2(pl[0])).append(h)
        feats.append({"type": "Feature", "properties": {
            "gatelr_id": zid, "name": name,
            "source": "Comune di Lucca, «ZTL e parcheggi nel Centro Storico aggiornato al 25.11.2025» (https://www.comune.lucca.it/app/uploads/2026/03/ZTL-aggiornamento-dicembre-2025.pdf)",
            "method": "Tools/lucca_mappa.py: classificazione dei colori della mappa ufficiale, agganciata alle Mura di OSM (trasformazione affine)",
            "registration_iou": round(float(score), 4),
            "area_km2": round(sum(osm_geo.area_km2(pl[0]) - sum(osm_geo.area_km2(h) for h in pl[1:]) for pl in polys), 4)},
            "geometry": {"type": "MultiPolygon", "coordinates": polys}})
        print(zid, len(polys), "poligoni,", sum(len(pl) - 1 for pl in polys), "buchi,", feats[-1]["properties"]["area_km2"], "km²")
    OUT.write_text(json.dumps({"type": "FeatureCollection", "affine_m": [round(float(v), 6) for v in p],
                               "features": feats}, ensure_ascii=False) + "\n", encoding="utf-8")
    print(OUT.relative_to(ROOT))


def _signed(ring):
    return sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(ring, ring[1:]))


if __name__ == "__main__":
    sys.exit(main())
