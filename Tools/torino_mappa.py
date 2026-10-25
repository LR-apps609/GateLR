#!/usr/bin/env python3
# Torino: cosa si ricava dalla mappa ufficiale «ZTL - Città di Torino» (data/raw/torino/mappa-ztl-internet.pdf,
# il PDF «Scarica la mappa della ZTL in formato PDF» della scheda «ZTL Centrale», inviato dall'utente il 25/10/2026).
#
# La mappa è un PDF a una pagina senza testo né coordinate. Niente è disegnato a mano:
# 1. il PDF diventa un'immagine (pdftoppm, 150 dpi, ~1,8 m per pixel);
# 2. aggancio: la linea verde «ZTL Centrale» della mappa è sovrapposta al contorno della relazione OSM 19152960
#    «ZTL Centrale» (data/raw/geo/torino-ztl.json) con una trasformazione affine (ICP: punto verde → punto più vicino
#    del contorno OSM, minimi quadrati, ripetuto; si tengono le coppie più vicine del 60° percentile, minimo 15 m);
# 3. i 41 pallini rossi «Porte elettroniche Esistenti» (legenda) diventano coordinate; due pallini che si toccano
#    vengono separati. Ognuno è classificato: «accesso» se sta a meno di 55 m dal contorno della ZTL Centrale,
#    «interno» se è dentro, «esterno» se è fuori (la scheda del Comune: 27 + 11 + 3 = 41). Ogni varco è agganciato al
#    nodo più vicino della strada OSM più vicina tra quelle della ZTL (nome e id nel file prodotto);
# 4. la ZTL Centrale della mappa (linea verde chiusa, pallini compresi) diventa un poligono, usato da build_torino.py
#    per controllare (e correggere dove si scosta di oltre 20 m) il contorno OSM;
# 5. la ZTL Area Romana (tratteggio marrone): l'area chiusa da tratteggio, linea verde e pallini che contiene
#    l'incrocio via Sant'Agostino–via San Domenico diventa un poligono.
# Risultato: data/raw/torino/mappa-ztl-ufficiale.json, letto da Tools/build_torino.py.
#
# Serve numpy, Pillow e pdftoppm (poppler). Uso: python3 Tools/torino_mappa.py
import json, subprocess, sys, tempfile
from pathlib import Path
import numpy as np
from PIL import Image
import osm_geo
from lucca_mappa import dilate, erode, components, fill_holes, loops, _signed

ROOT = Path(__file__).resolve().parent.parent
PDF = ROOT / "data/raw/torino/mappa-ztl-internet.pdf"
OUT = ROOT / "data/raw/torino/mappa-ztl-ufficiale.json"
OSM_CENTRALE = 19152960
DPI = 150
LAT0, LON0 = 45.07, 7.68
LEGEND = (1575, 0, 99999, 680)        # riquadro della legenda (x0, y0, x1, y1 in pixel a 150 dpi): ignorato
SEED_AR = (583, 357)                   # incrocio via Sant'Agostino – via San Domenico (dentro l'Area Romana)
ACCESS_M = 55
START = [((880, 430), (45.0712, 7.6857)),    # piazza Castello
         ((874, 1100), (45.0622, 7.6785)),   # stazione Porta Nuova
         ((120, 860), (45.0717, 7.6650))]    # stazione Porta Susa


def image():
    with tempfile.TemporaryDirectory() as d:
        subprocess.run(["pdftoppm", "-r", str(DPI), "-png", "-singlefile", str(PDF), f"{d}/m"], check=True)
        return np.asarray(Image.open(f"{d}/m.png").convert("RGB")).astype(int)


def color(im, rgb, tol):
    return (np.abs(im - np.array(rgb)).max(axis=2) <= tol)


def no_legend(m):
    m = m.copy(); x0, y0, x1, y1 = LEGEND; m[y0:y1, x0:x1] = False
    return m


fwd, back = osm_geo._proj(LAT0)
X0, Y0 = fwd(LON0, LAT0)


def to_m(lon, lat):
    x, y = fwd(lon, lat); return x - X0, y - Y0


def to_ll(px, A):
    """pixel (colonna, riga) → (lon, lat)"""
    x, y = np.array([px[0], px[1], 1.0]) @ A
    return back(x + X0, y + Y0)


def nearest(P, Q):
    """Per ogni punto di P: distanza e indice del punto più vicino di Q (a blocchi, solo numpy)"""
    d, i = np.empty(len(P)), np.empty(len(P), int)
    for s in range(0, len(P), 2000):
        dd = ((P[s:s + 2000, None, :] - Q[None, :, :]) ** 2).sum(-1)
        i[s:s + 2000] = dd.argmin(1); d[s:s + 2000] = np.sqrt(dd[np.arange(len(dd)), i[s:s + 2000]])
    return d, i


def register(green, ring):
    R = np.array([to_m(*p) for p in ring])
    D = np.concatenate([a + (b - a) * t[:, None] for a, b in zip(R, np.roll(R, -1, 0))
                        for t in [np.linspace(0, 1, max(1, int(np.linalg.norm(b - a) / 3)), endpoint=False)]])
    ys, xs = np.nonzero(green); G = np.c_[xs, ys].astype(float)[::2]
    Gh = np.c_[G, np.ones(len(G))]
    # partenza: tre punti riconoscibili sulla mappa (la mappa è ruotata rispetto al nord)
    src = np.array([[px[0], px[1], 1.0] for px, _ in START])
    dst = np.array([to_m(lon, lat) for _, (lat, lon) in START])
    A = np.linalg.lstsq(src, dst, rcond=None)[0]
    for _ in range(60):
        d, i = nearest(Gh @ A, D)
        k = d < max(15, np.percentile(d, 60))
        A = np.linalg.lstsq(Gh[k], D[i[k]], rcond=None)[0]
    d_map, _ = nearest(D, Gh @ A)       # contorno OSM → linea verde
    return A, float(np.median(d_map)), float(np.percentile(d_map, 90))


def polygon(mask, A, min_m2=2000):
    rings = []
    for lp in loops(mask):
        ring = [to_ll((c - 0.5, r - 0.5), A) for c, r in lp]; ring.append(ring[0])
        ring = osm_geo.simplify_m(ring, 2.0)
        if len(ring) >= 4 and osm_geo.area_km2(ring) * 1e6 >= min_m2:
            rings.append([[round(x, 6), round(y, 6)] for x, y in ring])
    rings.sort(key=osm_geo.area_km2, reverse=True)
    return rings[0]


def main():
    im = image()
    green = no_legend(color(im, (0, 184, 0), 40))
    red = no_legend(color(im, (255, 0, 0), 60))
    dash = no_legend(color(im, (184, 46, 0), 30))
    els = osm_geo.load("torino-ztl")
    ring = osm_geo.outer_ring(osm_geo.relation(els, OSM_CENTRALE))
    A, med, p90 = register(green, ring)
    m_px = float(np.sqrt(abs(np.linalg.det(A[:2]))))
    print(f"aggancio: {m_px:.2f} m per pixel; contorno OSM → linea verde: mediana {med:.1f} m, 90% {p90:.1f} m")
    if med > 3:
        raise SystemExit("Aggancio della mappa troppo incerto")

    # --- pallini rossi ---
    lab, sizes = components(red)
    one = np.median(sizes[1:][sizes[1:] > 200])
    dots = []
    for k in np.nonzero(sizes > one * 0.5)[0]:
        ys, xs = np.nonzero(lab == k); pts = np.c_[xs, ys].astype(float)
        n = int(round(sizes[k] / one))
        c = pts[np.linspace(0, len(pts) - 1, n).astype(int)] if n > 1 else pts.mean(0, keepdims=True)
        for _ in range(30):            # k-means per i pallini che si toccano
            j = ((pts[:, None] - c[None]) ** 2).sum(-1).argmin(1); c = np.array([pts[j == q].mean(0) for q in range(n)])
        dots += c.tolist()
    ways = [e for e in els if e["type"] == "way" and e.get("geometry") and e.get("tags", {}).get("highway") and e["tags"].get("name")]
    points = []
    for x, y in sorted(dots, key=lambda p: (round(p[1] / 40), p[0])):
        lon, lat = to_ll((x, y), A)
        d_ring = osm_geo.distance_m(ring, lat, lon)
        inside = osm_geo.inside_lonlat(ring, lon, lat)
        kind = "accesso" if d_ring < ACCESS_M else ("interno" if inside else "esterno")
        p = {"px": [round(x), round(y)], "lat": round(lat, 6), "lon": round(lon, 6), "kind": kind, "dist_contorno_m": round(d_ring)}
        if kind != "esterno":
            mx, my = to_m(lon, lat)
            best = min(((np.hypot(*(np.array(to_m(n["lon"], n["lat"])) - [mx, my])), w, i)
                        for w in ways for i, n in enumerate(w["geometry"])), key=lambda t: t[0])
            d, w, i = best
            p.update({"strada": w["tags"]["name"], "zona_osm": w["tags"].get("zone:traffic:name"), "way": w["id"],
                      "node": w["nodes"][i], "node_lat": w["geometry"][i]["lat"], "node_lon": w["geometry"][i]["lon"],
                      "dist_strada_m": round(float(d))})
        points.append(p)
    count = {k: sum(p["kind"] == k for p in points) for k in ("accesso", "interno", "esterno")}
    print("pallini:", len(points), count)

    # --- ZTL Centrale sulla mappa (linea verde e pallini, chiusa e riempita) ---
    band = dilate(green | red, 2)
    l, s = components(band)
    filled = fill_holes(l == (s[1:].argmax() + 1))
    centrale = polygon(filled, A)

    # --- ZTL Area Romana ---
    barrier = dilate(dash | green | red, 3)
    l, s = components(~barrier)
    seed = l[SEED_AR[1], SEED_AR[0]]
    if not seed:
        raise SystemExit("Il punto di partenza dell'Area Romana cade su una linea")
    area_romana = polygon(fill_holes(dilate(l == seed, 4)), A)   # fino a metà del tratteggio
    print(f"Centrale (mappa) {osm_geo.area_km2(centrale):.3f} km², Area Romana {osm_geo.area_km2(area_romana) * 1e6:.0f} m²")

    OUT.write_text(json.dumps({
        "source": "Città di Torino, Divisione Infrastrutture e Mobilità, «ZTL - Città di Torino» (mappa-ztl-internet.pdf, "
                  "linkata dalla scheda https://www.comune.torino.it/schede-informative/ztl-centrale; PDF modificato il 15/01/2026)",
        "method": "Tools/torino_mappa.py: colori della mappa ufficiale, agganciata alla relazione OSM 19152960 (trasformazione affine)",
        "affine_m": [[round(float(v), 6) for v in r] for r in A], "proj_origin": [LON0, LAT0], "dpi": DPI,
        "fit_osm_to_map_m": {"median": round(med, 1), "p90": round(p90, 1)},
        "points_count": count, "points": points,
        "centrale_map": centrale, "area_romana": area_romana}, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(OUT.relative_to(ROOT))


if __name__ == "__main__":
    sys.exit(main())
