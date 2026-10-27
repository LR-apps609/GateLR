#!/usr/bin/env python3
# Ascoli Piceno: perimetri della «ZTL a fascia ampia» (gialla) e della «ZTL a fascia ridotta» (azzurra) ricavati in
# automatico dalla mappa ufficiale del Comune «Mappa cittadina ufficiale dei varchi collegata al regolamento dei varchi»
# (PDF del 16/03/2026, linkato dalla pagina «ZTL e varchi: traffico a misura d'uomo»), salvata in
# data/raw/ascoli-piceno/mappa-ufficiale-varchi-2026.pdf. È l'unica fonte grafica degli ampliamenti del 2024
# (D.G.C. 194/2024, ord. 775/2024: nuova ZTL a fascia ridotta nella zona nord/ovest con i varchi Ventidio Basso,
# Fortezza e Corso di Sotto). Niente è disegnato a mano:
# 1. il PDF è trasformato in immagine (pdftoppm, 100 dpi) e ogni pixel è classificato dal colore della legenda:
#    giallo = ZTL a fascia ampia, azzurro = ZTL a fascia ridotta, verde = APU; tratteggi, contorni degli edifici,
#    scritte e simboli prendono la classe del colore più frequente nell'intorno; la legenda è esclusa;
# 2. la mappa (senza coordinate) è agganciata con una trasformazione affine che sovrappone i fabbricati tratteggiati
#    della base cartografica ai fabbricati di OpenStreetMap (data/raw/geo/ascoli-piceno-centro.json): partenza da
#    11 toponimi della mappa (pdftotext -bbox) e poi ricerca locale della massima sovrapposizione (F1);
# 3. ogni zona colorata diventa un poligono (componenti più grandi, buchi riempiti), semplificato a 3 m.
# Risultato: data/raw/ascoli-piceno/ztl-mappa-ufficiale.geojson (con la trasformazione e il punteggio), letto da
# Tools/build_ascoli_piceno.py. Serve numpy, Pillow e poppler. Uso: python3 Tools/ascoli_mappa.py
import json, math, re, html, subprocess, tempfile
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
PDF = ROOT / "data/raw/ascoli-piceno/mappa-ufficiale-varchi-2026.pdf"
OUT = ROOT / "data/raw/ascoli-piceno/ztl-mappa-ufficiale.geojson"
DPI = 100
K = DPI / 72.0                                   # pixel per punto PDF
LAT0, LON0 = 42.855, 13.575
KX, KY = 111320.0 * math.cos(math.radians(LAT0)), 110574.0
Image.MAX_IMAGE_PIXELS = None
# toponimi della mappa (testo del PDF) ↔ oggetti OSM con lo stesso nome (centroidi)
LABELS = [("POPOLO", (860, 1428), "Piazza del Popolo"), ("ARRINGO", (1065, 1550), "Piazza Arringo"),
          ("NUOVO", (1164, 1075), "Ponte Nuovo"), ("MAGGIORE", (1785, 1517), "Ponte Maggiore"),
          ("TUFILLA", (1144, 1110), "Porta Tufilla"), ("MALASPINA", (1301, 1285), "Palazzo Malaspina"),
          ("SOLESTA'", (589, 934), "Porta Solestà"), ("MALATESTA", (1800, 1627), "Forte Malatesta"),
          ("S.AGOSTINO", (640, 1349), "Piazza Sant'Agostino"), ("TOMMASO", (430, 1269), "Piazza San Tommaso"),
          ("VIOLA", (1120, 1433), "Piazza della Viola")]   # parola della mappa, posizione indicativa (punti PDF), nome OSM


def to_ll(x, y):
    return LON0 + x / KX, LAT0 + y / KY


def to_m(lon, lat):
    return (lon - LON0) * KX, (lat - LAT0) * KY


def dilate(m, r):
    for _ in range(r):
        n = m.copy(); n[1:] |= m[:-1]; n[:-1] |= m[1:]; n[:, 1:] |= m[:, :-1]; n[:, :-1] |= m[:, 1:]; m = n
    return m


def box_sum(a, r):
    c = np.pad(a.astype(np.int32), ((r + 1, r), (r + 1, r))).cumsum(0).cumsum(1)
    return c[2 * r + 1:, 2 * r + 1:] - c[:-2 * r - 1, 2 * r + 1:] - c[2 * r + 1:, :-2 * r - 1] + c[:-2 * r - 1, :-2 * r - 1]


def components(mask):
    h, w = mask.shape
    flat = mask.ravel(); lab = np.zeros(h * w, np.int32); n = 0; sizes = [0]
    for s in np.flatnonzero(flat):
        if lab[s]:
            continue
        n += 1; lab[s] = n; st = [s]; c = 0
        while st:
            p = st.pop(); c += 1; x = p % w
            for q in (p - w, p + w, p - 1 if x else -1, p + 1 if x < w - 1 else -1):
                if 0 <= q < h * w and flat[q] and not lab[q]:
                    lab[q] = n; st.append(q)
        sizes.append(c)
    return lab.reshape(h, w), sizes


def fill_holes(m):
    lab, sizes = components(~m)
    border = set(np.unique(np.r_[lab[0], lab[-1], lab[:, 0], lab[:, -1]]).tolist()) - {0}
    return m | ~np.isin(lab, list(border))


def labels_px():
    t = subprocess.run(["pdftotext", "-bbox", str(PDF), "-"], capture_output=True, text=True, check=True).stdout
    words = [(html.unescape(w), float(a), float(b), float(c), float(d)) for a, b, c, d, w in
             re.findall(r'<word xMin="([\d.]+)" yMin="([\d.]+)" xMax="([\d.]+)" yMax="([\d.]+)">([^<]*)</word>', t)]
    out = {}
    for word, (hx, hy), osm_name in LABELS:
        hits = [w for w in words if w[0] == word and abs((w[1] + w[3]) / 2 - hx) < 40 and abs((w[2] + w[4]) / 2 - hy) < 20]
        if len(hits) != 1:
            raise SystemExit(f"toponimo {word}: {len(hits)} occorrenze")
        _, a, b, c, d = hits[0]
        out[osm_name] = ((a + c) / 2 * K, (b + d) / 2 * K)
    return out


def osm_centroids(els):
    pts = {}
    for _, _, osm_name in LABELS:
        xs = []
        for e in els:
            if e.get("tags", {}).get("name") != osm_name:
                continue
            g = e.get("geometry") or [p for m in e.get("members", []) for p in m.get("geometry", [])]
            xs += [to_m(p["lon"], p["lat"]) for p in g]
        if not xs:
            raise SystemExit(f"{osm_name} non trovato in OSM")
        pts[osm_name] = (sum(x for x, _ in xs) / len(xs), sum(y for _, y in xs) / len(xs))
    return pts


def main():
    with tempfile.TemporaryDirectory() as td:
        subprocess.run(["pdftoppm", "-r", str(DPI), "-png", "-singlefile", str(PDF), f"{td}/m"], check=True)
        im = np.asarray(Image.open(f"{td}/m.png").convert("RGB")).astype(int)
    H, W = im.shape[:2]
    R, G, B = im[..., 0], im[..., 1], im[..., 2]
    lab_px = labels_px()
    # cornice della mappa e legenda (dalle scritte della legenda)
    valid = np.zeros((H, W), bool)
    y0 = int(min(v[1] for v in lab_px.values()) - 120)
    valid[max(y0, 0):, :] = True
    leg_x = 1570 * K; leg_y = 1200 * K
    valid[: int(leg_y), int(leg_x):] = False

    # --- 1. colori ---
    yellow = (R > 225) & (G > 225) & (B > 120) & (B < 200) & valid
    blue = (R > 130) & (R < 200) & (G > 200) & (B > 225) & valid
    green = (R > 185) & (R < 230) & (G > 225) & (B > 150) & (B < 205) & valid
    white = (R > 235) & (G > 235) & (B > 235) & valid
    ink = (np.max(im, 2) - np.min(im, 2) < 30) & (R < 190) & valid
    # ogni pixel prende il colore più frequente nel raggio di 6 px (~4 m): tratteggi e simboli spariscono
    r = 6
    votes = np.stack([box_sum(m, r) for m in (white, yellow, blue, green)])
    cls = np.argmax(votes, 0); cls[votes.max(0) == 0] = 0
    cls[~valid] = 0

    # --- 2. aggancio ai fabbricati OSM ---
    els = osm_geo.load("ascoli-piceno-centro")
    osm_pts = osm_centroids(els)
    P = np.array([lab_px[o] for _, _, o in LABELS]); M = np.array([osm_pts[o] for _, _, o in LABELS])
    A0 = np.linalg.lstsq(np.c_[P, np.ones(len(P))], M, rcond=None)[0]       # 3×2: [x y 1] → metri
    res0 = np.hypot(*(np.c_[P, np.ones(len(P))] @ A0 - M).T)
    print("toponimi: scarti iniziali (m)", np.round(res0, 0).tolist())
    CELL, GX0, GY0, GN = 1.0, -1500.0, -1000.0, 3000
    gimg = Image.new("1", (GN, GN), 0); dr = ImageDraw.Draw(gimg)
    for e in els:
        t = e.get("tags", {})
        if "building" not in t:
            continue
        rings = [e["geometry"]] if e["type"] == "way" else [m["geometry"] for m in e["members"] if m.get("role") == "outer" and m.get("geometry")]
        for g in rings:
            if len(g) >= 3:
                dr.polygon([((x - GX0) / CELL, (GN - 1) - (y - GY0) / CELL) for x, y in (to_m(p["lon"], p["lat"]) for p in g)], fill=1)
    bld = np.asarray(gimg, bool)
    dens = box_sum(ink, 3) / 49.0
    mbld = (dens > 0.18) & valid                  # fabbricati tratteggiati della mappa
    rng = np.random.default_rng(0)
    yy, xx = np.nonzero(mbld); pick = rng.choice(len(xx), size=min(20000, len(xx)), replace=False)
    PX, PY = xx[pick].astype(float), yy[pick].astype(float)
    by, bx = np.nonzero(bld); pick = rng.choice(len(bx), size=min(20000, len(bx)), replace=False)
    BMX, BMY = GX0 + bx[pick] * CELL, GY0 + ((GN - 1) - by[pick]) * CELL
    bld_tol = dilate(bld, 2); mb_tol = dilate(mbld, 2)

    def score(a):
        a = a.reshape(3, 2)
        mx = PX * a[0, 0] + PY * a[1, 0] + a[2, 0]; my = PX * a[0, 1] + PY * a[1, 1] + a[2, 1]
        i = ((GN - 1) - (my - GY0) / CELL).astype(int); j = ((mx - GX0) / CELL).astype(int)
        ok = (i >= 0) & (i < GN) & (j >= 0) & (j < GN)
        prec = bld_tol[i[ok], j[ok]].sum() / len(PX)
        L = a[:2]; inv = np.linalg.inv(L)
        q = np.c_[BMX - a[2, 0], BMY - a[2, 1]] @ inv
        x, y = q[:, 0], q[:, 1]
        ins = (x >= 0) & (x < W) & (y >= 0) & (y < H)
        ins &= valid[np.clip(y, 0, H - 1).astype(int), np.clip(x, 0, W - 1).astype(int)]
        if ins.sum() < 1000:
            return 0.0
        rec = mb_tol[y[ins].astype(int), x[ins].astype(int)].mean()
        return 2 * prec * rec / (prec + rec + 1e-9)

    p = A0.ravel().copy(); f = score(p)
    print(f"F1 iniziale {f:.3f}")
    # ricerca grossolana della traslazione (gli scarti dei toponimi arrivano a decine di metri)
    best = (f, p)
    for dx in range(-60, 61, 4):
        for dy in range(-60, 61, 4):
            q = p.copy(); q[4] += dx; q[5] += dy
            g = score(q)
            if g > best[0]:
                best = (g, q)
    f, p = best
    step = np.array([0.01, 0.01, 0.01, 0.01, 2.0, 2.0])
    for _ in range(8):
        improved = True
        while improved:
            improved = False
            for k in range(6):
                for d in (-1, 1):
                    q = p.copy(); q[k] += d * step[k]
                    g = score(q)
                    if g > f:
                        f, p, improved = g, q, True
        step /= 2
    a = p.reshape(3, 2)
    sx, sy = math.hypot(a[0, 0], a[0, 1]), math.hypot(a[1, 0], a[1, 1])
    rot = math.degrees(math.atan2(a[0, 1], a[0, 0]))
    resid = np.hypot(*(np.c_[P, np.ones(len(P))] @ a - M).T)
    print(f"aggancio: {sx:.4f} × {sy:.4f} m/px, rotazione {rot:.2f}°, F1 fabbricati {f:.3f}; scarti toponimi (m)", np.round(resid, 0).tolist())
    if f < 0.65:   # i fabbricati OSM non sono completi: 0,67 con scarti di pochi metri (controllo visivo dei sovrapposti)
        raise SystemExit("La mappa non si aggancia bene ai fabbricati OSM: ricontrollare")

    def ll(x, y):
        return to_ll(x * a[0, 0] + y * a[1, 0] + a[2, 0], x * a[0, 1] + y * a[1, 1] + a[2, 1])

    # --- 3. poligoni delle zone ---
    feats = []
    for name, c, minpx in (("ZTL fascia ampia", 1, 4000), ("ZTL fascia ridotta", 2, 4000), ("APU", 3, 4000)):
        m = cls == c
        labc, sizes = components(m)
        keep = [i for i, s in enumerate(sizes) if i and s >= minpx]
        print(name, "componenti tenute (px):", sorted([sizes[i] for i in keep], reverse=True), "scartate:", sum(1 for i, s in enumerate(sizes) if i and s < minpx))
        for i in keep:
            comp = fill_holes(labc == i)
            ring = [ll(x, y) for x, y in outline(comp)]
            ring = osm_geo.simplify_m(ring, 3.0)
            feats.append({"type": "Feature", "properties": {"name": name, "px": int(comp.sum()), "area_km2": round(osm_geo.area_km2(ring), 4)},
                          "geometry": {"type": "Polygon", "coordinates": [[[round(x, 6), round(y, 6)] for x, y in ring]]}})
    OUT.write_text(json.dumps({
        "type": "FeatureCollection",
        "source": "Comune di Ascoli Piceno, mappa ufficiale dei varchi collegata al regolamento (PDF 16/03/2026), georeferenziata sui fabbricati OSM",
        "transform": {"affine_px_to_m": [[round(v, 6) for v in row] for row in a.tolist()], "dpi": DPI, "origin": [LAT0, LON0],
                      "scale_m_per_px": [round(sx, 4), round(sy, 4)], "rotation_deg": round(rot, 3), "buildings_f1": round(f, 3),
                      "label_residuals_m": [round(float(v), 1) for v in resid]},
        "features": feats}, ensure_ascii=False) + "\n", encoding="utf-8")
    print(OUT.relative_to(ROOT))


def outline(zone):
    """Contorno esterno (lati dei pixel) della maschera, come lista di vertici (x, y) in pixel"""
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
    return max(loops, key=len)


if __name__ == "__main__":
    main()
