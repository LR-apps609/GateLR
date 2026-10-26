#!/usr/bin/env python3
# San Gimignano: perimetro della ZTL e posizione dei 6 varchi ricavati in automatico dalla planimetria ufficiale del Comune
# «Cartografia di inquadramento generale per la realizzazione del sistema di controllo degli accessi alla zona traffico
# limitato» (allegato della pagina «Nuova ZTL Centro Storico», data/raw/san-gimignano/ztl-planimetria.pdf).
#
# La planimetria è un PDF di QGIS (scala 1:2000 su A3, base DBTGR10k della Regione Toscana, EPSG:3003) che contiene
# solo un'immagine (3507×4960 pixel a 300 dpi) e nessuna coordinata. Niente è disegnato a mano:
# 1. l'immagine è estratta dal PDF (pdfimages) e ridotta a ~0,34 m per pixel; i pixel grigi sono gli edifici,
#    quelli blu la linea «ZTL», quelli rossi i cerchi «Varco ZTL» e le frecce «Solo autorizzati» (legenda);
# 2. aggancio: gli edifici della mappa sono sovrapposti agli edifici di OpenStreetMap
#    (data/raw/geo/san-gimignano-buildings.json) con una trasformazione di similitudine (rotazione, scala, traslazione):
#    per ogni rotazione e scala vicine a quelle nominali (1:2000, convergenza del meridiano di Gauss-Boaga ~1,4°) la
#    traslazione migliore viene dalla correlazione (FFT); si tiene la combinazione con la correlazione più alta;
# 3. l'area chiusa dalla linea blu che contiene piazza della Cisterna diventa il perimetro (linea compresa);
# 4. i cerchi «Varco ZTL» diventano coordinate; i nomi (Disciplinare, «Varchi di controllo») sono assegnati con i numeri
#    della mappa, letti dalla posizione: 1 Porta San Giovanni e 2 Bonda/Piandornella (i due a sud, ovest→est),
#    3 Via Santa Caterina, 4 Via di Quercecchio, 5 Porta San Matteo, 6 Via di Bagnaia.
# Risultato: data/raw/san-gimignano/ztl-mappa-ufficiale.json, letto da Tools/build_san_gimignano.py.
#
# Serve numpy, Pillow e pdfimages (poppler). Uso: python3 Tools/sangimignano_mappa.py
import json, math, subprocess, sys, tempfile
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
import osm_geo
from lucca_mappa import dilate, erode, components, fill_holes

ROOT = Path(__file__).resolve().parent.parent
PDF = ROOT / "data/raw/san-gimignano/ztl-planimetria.pdf"
OUT = ROOT / "data/raw/san-gimignano/ztl-mappa-ufficiale.json"
LAT0, LON0 = 43.4670, 11.0430
KX, KY = 111320.0 * math.cos(math.radians(LAT0)), 110574.0
DOWN = 2
M_PER_PX = 2000 * 0.0254 / 300 * DOWN        # 1:2000 a 300 dpi
MAP_ROWS = 4700 // DOWN                         # sotto c'è il riquadro della legenda
CISTERNA = (43.46765, 11.04325)                 # piazza della Cisterna (punto di controllo, dentro)
BBOX = (43.4610, 11.0360, 43.4740, 11.0500)    # edifici OSM usati per l'aggancio (la mappa ne copre una parte)


def to_xy(lat, lon):
    return (lon - LON0) * KX, (lat - LAT0) * KY


def to_latlon(x, y):
    return LAT0 + y / KY, LON0 + x / KX


def load_image():
    with tempfile.TemporaryDirectory() as d:
        subprocess.run(["pdfimages", "-j", str(PDF), f"{d}/img"], check=True)
        im = Image.open(f"{d}/img-000.jpg").convert("RGB")
        im.load()
    if im.size != (3507, 4960):
        raise SystemExit(f"Immagine inattesa: {im.size}")
    im = im.resize((im.size[0] // DOWN, im.size[1] // DOWN), Image.BILINEAR)
    return np.asarray(im).astype(int)[:MAP_ROWS]


def masks(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    grey = (abs(r - g) < 12) & (abs(g - b) < 12)
    building = grey & (r > 125) & (r < 175)
    blue = (b > 170) & (r < 90) & (g < 90)
    red = (r > 160) & (g < 90) & (b < 90)
    dark = (r < 90) & (g < 90) & (b < 90)    # scritte e frecce nere: dove coprono la linea blu la interrompono
    return building, blue, red, dark


def osm_buildings():
    out = []
    for e in osm_geo.load("san-gimignano-buildings"):
        if e["type"] == "way" and e.get("geometry") and all(
                BBOX[0] <= p["lat"] <= BBOX[2] and BBOX[1] <= p["lon"] <= BBOX[3] for p in e["geometry"]):
            out.append([to_xy(p["lat"], p["lon"]) for p in e["geometry"]])
    return out


def raster_osm(polys, theta, scale, shape):
    """Edifici OSM nel sistema della mappa (u verso destra, v verso il basso) senza traslazione; restituisce
    l'immagine e l'origine (u0, v0) del suo pixel (0, 0)"""
    c, s = math.cos(theta), math.sin(theta)
    pts = [[((c * x + s * y) / scale, -(-s * x + c * y) / scale) for x, y in p] for p in polys]
    u0 = min(u for p in pts for u, _ in p) - 5
    v0 = min(v for p in pts for _, v in p) - 5
    im = Image.new("L", (shape[1], shape[0]), 0)
    dr = ImageDraw.Draw(im)
    for p in pts:
        dr.polygon([(u - u0, v - v0) for u, v in p], fill=1)
    return np.asarray(im).astype(float), u0, v0


def best_shift(A, B):
    """Traslazione (dy, dx) che sovrappone B ad A (correlazione circolare con FFT) e la correlazione normalizzata"""
    A = A - A.mean(); B = B - B.mean()
    F = np.fft.rfft2(A) * np.conj(np.fft.rfft2(B))
    cc = np.fft.irfft2(F, s=A.shape)
    k = int(np.argmax(cc)); dy, dx = divmod(k, A.shape[1])
    return dy, dx, cc.flat[k] / (np.linalg.norm(A) * np.linalg.norm(B))


def georeference(building):
    polys = osm_buildings()
    H, W = building.shape
    shape = (4800, 3900)    # più grande sia della mappa sia degli edifici OSM ruotati e scalati
    A = np.zeros(shape); A[:H, :W] = building
    best = None
    for theta_deg in np.arange(-3.0, 1.01, 0.25):
        for sc in np.arange(0.98, 1.0201, 0.005):
            scale = M_PER_PX * sc
            B, u0, v0 = raster_osm(polys, math.radians(theta_deg), scale, shape)
            dy, dx, score = best_shift(A, B)
            dy = dy - shape[0] if dy > shape[0] / 2 else dy      # traslazione con segno (la correlazione è circolare)
            dx = dx - shape[1] if dx > shape[1] / 2 else dx
            if best is None or score > best[0]:
                best = (score, theta_deg, scale, dx - u0, dy - v0)
    score, theta_deg, scale, uo, vo = best
    # uo, vo: pixel della mappa dove cade l'origine locale (LAT0, LON0)
    return {"score": round(float(score), 4), "theta_deg": float(theta_deg), "m_per_px": round(float(scale), 5),
            "u_origin": round(float(uo), 2), "v_origin": round(float(vo), 2)}


def make_tf(g):
    th, sc = math.radians(g["theta_deg"]), g["m_per_px"]
    c, s = math.cos(th), math.sin(th)
    uo, vo = g["u_origin"], g["v_origin"]

    def px_to_latlon(u, v):
        # pixel (u, v) → coordinate nel sistema ruotato (u - uo, -(v - vo)) · scala → ruoto di +theta
        a, b = (u - uo) * sc, -(v - vo) * sc
        x, y = c * a - s * b, s * a + c * b
        return to_latlon(x, y)

    def latlon_to_px(lat, lon):
        x, y = to_xy(lat, lon)
        a, b = (c * x + s * y) / sc, (-s * x + c * y) / sc
        return a + uo, -b + vo

    return px_to_latlon, latlon_to_px


def zone_polygon(blue, red, dark, latlon_to_px):
    """L'area chiusa dalla linea blu (e dai cerchi dei varchi) che contiene piazza della Cisterna. A est la
    linea (via Bonda) esce dal riquadro della mappa: lì l'area è chiusa dal bordo della mappa. Le scritte nere stampate sopra
    la linea (nomi delle vie, frecce dei varchi) contano come linea, se sono a meno di ~3 m da un tratto blu."""
    line = dilate(blue | red | (dark & dilate(blue, 10)), 2)
    line[0] = line[-1] = True
    line[:, 0] = line[:, -1] = True
    lab, sizes = components(~line)
    u, v = latlon_to_px(*CISTERNA)
    k = lab[int(round(v)), int(round(u))]
    if k == 0:
        raise SystemExit("Piazza della Cisterna cade sulla linea blu: aggancio sbagliato")
    inside = lab == k
    if inside.sum() > 0.5 * inside.size:
        raise SystemExit("L'area della ZTL è più di metà della mappa: la linea blu non si chiude")
    return fill_holes(dilate(inside, 3))      # la linea blu (spessa ~1 m) è dentro


def boundary(mask):
    """Contorno esterno (lati dei pixel) di una maschera, come lista di (u, v)"""
    cells = set(zip(*np.nonzero(mask)))
    nxt = {}
    for y, x in cells:
        if (y - 1, x) not in cells: nxt.setdefault((x, y), []).append((x + 1, y))
        if (y, x + 1) not in cells: nxt.setdefault((x + 1, y), []).append((x + 1, y + 1))
        if (y + 1, x) not in cells: nxt.setdefault((x + 1, y + 1), []).append((x, y + 1))
        if (y, x - 1) not in cells: nxt.setdefault((x, y + 1), []).append((x, y))
    loops = []
    while nxt:
        start = next(iter(nxt)); loop, cur = [start], start
        while True:
            cur = nxt[cur].pop()
            if not nxt[loop[-1]]: del nxt[loop[-1]]
            if cur == start: break
            loop.append(cur)
        loops.append(loop + [start])
    return max(loops, key=len)


def gate_circles(red, a):
    """Cerchi «Varco ZTL»: un disco bianco (~3–5 m) circondato quasi tutto da un anello rosso. Si cerca il disco bianco,
    perché l'anello rosso può toccare le frecce rosse «Solo autorizzati»."""
    white = (a.min(-1) > 225)
    lab, sizes = components(white)
    out = []
    for k in np.nonzero((sizes >= 40) & (sizes <= 400))[0]:
        ys, xs = np.nonzero(lab == k)
        hgt, wid = ys.max() - ys.min() + 1, xs.max() - xs.min() + 1
        if not (7 <= hgt <= 22 and 7 <= wid <= 22 and abs(hgt - wid) <= 3 and sizes[k] > 0.6 * hgt * wid):
            continue
        blob = lab == k
        ring = dilate(blob, 3) & ~blob
        if red[ring].mean() < 0.6:
            continue
        out.append(((xs.max() + xs.min()) / 2, (ys.max() + ys.min()) / 2))
    return out


NAMES = {1: "Porta San Giovanni", 2: "Bonda/Piandornella", 3: "Via Santa Caterina",
         4: "Via di Quercecchio", 5: "Porta San Matteo", 6: "Via di Bagnaia"}


def number_gates(circles):
    if len(circles) != 6:
        raise SystemExit(f"Attesi 6 cerchi «Varco ZTL», trovati {len(circles)}: {circles}")
    by_v = sorted(circles, key=lambda c: c[1])
    south = sorted(by_v[-2:], key=lambda c: c[0])           # 1 e 2, ovest → est
    north = sorted(by_v[:2], key=lambda c: c[0])            # 5 (ovest) e 6 (est)
    west = sorted(by_v[2:4], key=lambda c: c[1])            # 4 (più a nord) e 3
    return {1: south[0], 2: south[1], 3: west[1], 4: west[0], 5: north[0], 6: north[1]}


def main():
    a = load_image()
    building, blue, red, dark = masks(a)
    g = georeference(building)
    print(f"aggancio: correlazione {g['score']:.3f}, rotazione {g['theta_deg']}°, {g['m_per_px']:.4f} m/pixel")
    if g["score"] < 0.5:
        raise SystemExit("Correlazione troppo bassa: la mappa non si sovrappone agli edifici OSM")
    px_to_latlon, latlon_to_px = make_tf(g)
    zone = zone_polygon(blue, red, dark, latlon_to_px)
    ring = [px_to_latlon(u, v) for u, v in boundary(zone)]
    ring_lonlat = [(lon, lat) for lat, lon in ring]
    gates = number_gates(gate_circles(red, a))
    out = {"source": "Comune di San Gimignano, planimetria «ztl-planimetria.pdf» (scala 1:2000)",
           "method": "Tools/sangimignano_mappa.py: aggancio agli edifici OpenStreetMap (© OpenStreetMap contributors, ODbL 1.0)",
           "georeference": g,
           "perimeter": [[round(lon, 7), round(lat, 7)] for lon, lat in osm_geo.simplify_m(ring_lonlat, 1.0)],
           "gates": [{"number": n, "name": NAMES[n], "lat": round(px_to_latlon(*gates[n])[0], 7),
                      "lon": round(px_to_latlon(*gates[n])[1], 7)} for n in sorted(gates)]}
    OUT.write_text(json.dumps(out, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(OUT.name, len(out["perimeter"]), "punti,", f"{osm_geo.area_km2(ring_lonlat):.3f} km²")
    for gt in out["gates"]:
        print(gt)


if __name__ == "__main__":
    main()
