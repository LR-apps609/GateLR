#!/usr/bin/env python3
# Rimini: i settori della ZTL del centro storico e del Borgo San Giuliano ricavati in automatico dalla mappa ufficiale
# «Allegato A – Delimitazione delle APU e ZTL del centro storico e localizzazione dei varchi di controllo accesso»
# (delibera di Giunta n. 393 del 28/10/2025), salvata in data/raw/rimini/allegato-a-dgc-393-2025-mappa-ztl.pdf.
#
# La mappa è un PDF vettoriale senza coordinate. Niente è disegnato a mano:
# 1. il PDF è trasformato in immagine a 72 dpi senza antialiasing (pdftoppm -aa no), così ogni campitura ha il suo
#    colore esatto; ogni pixel è classificato secondo la legenda della mappa (giallo chiaro = ZTL 9-12/16-19:30,
#    arancio = ZTL 0-24, azzurro = ZTL 9-12, arancio scuro = ZTL 20:30-7:30, verde = ZTL 22-6, viola = ZTL 7:30-20:30,
#    rosa = area pedonale); le righe grigie della base cartografica (edifici, strade) e le scritte dentro una zona
#    prendono la zona attorno (voto della classe più frequente su una finestra di 5×5 pixel, ripetuto);
# 2. ciascuno dei due riquadri della mappa (la pianta generale a sinistra e l'ingrandimento a destra con il Borgo
#    San Giuliano) è agganciato alle coordinate con una similitudine (scala, rotazione, traslazione) che sovrappone
#    le righe grigie degli edifici della base cartografica ai contorni degli edifici di OpenStreetMap
#    (data/raw/geo/rimini-centro.json): per ogni scala e rotazione di una griglia, la traslazione migliore viene dalla
#    correlazione (FFT) delle due immagini, poi si affina; la trasformazione e il punteggio sono scritti nel file;
# 3. ogni parte separata di ciascuna classe diventa un poligono (contorno esterno), semplificato a 2 m.
# Risultato: data/raw/rimini/ztl-mappa-ufficiale.geojson, letto da Tools/build_rimini.py.
#
# Serve numpy, Pillow e pdftoppm (poppler). Uso: python3 Tools/rimini_mappa.py
import json, math, subprocess, sys, tempfile
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
PDF = ROOT / "data/raw/rimini/allegato-a-dgc-393-2025-mappa-ztl.pdf"
OSM = ROOT / "data/raw/geo/rimini-centro.json"
OUT = ROOT / "data/raw/rimini/ztl-mappa-ufficiale.geojson"
DPI = 72
Image.MAX_IMAGE_PIXELS = None

# legenda della mappa (colori RGB esatti delle campiture nel PDF)
CLASSES = {
    "fasce": ((255, 255, 184), "ZONA TRAFFICO LIMITATO PER FASCE ORARIE 09:00-12:00 / 16:00-19:30"),
    "h24": ((255, 191, 0), "ZONA TRAFFICO LIMITATO 00:00-24:00"),
    "mattina": ((122, 175, 223), "ZONA TRAFFICO LIMITATO 09:00-12:00"),
    "notte2030": ((242, 103, 34), "ZONA TRAFFICO LIMITATO 20:30-07:30"),
    "notte22": ((19, 155, 72), "ZONA TRAFFICO LIMITATO 22:00-06:00"),
    "giorno": ((147, 39, 143), "ZONA TRAFFICO LIMITATO 07:30-20:30"),
    "pedonale": ((255, 194, 173), "AREA PEDONALE"),
}
GRAY = (152, 152, 152)   # righe della base cartografica
# i due riquadri della pagina a 72 dpi (x0, y0, x1, y1) e l'intervallo di scala atteso (pixel per metro)
FRAMES = {"pianta": ((582, 92, 2626, 2352), (1.2, 2.3)), "ingrandimento": ((2668, 92, 4132, 2352), (2.0, 4.2))}


def render():
    with tempfile.TemporaryDirectory() as d:
        subprocess.run(["pdftoppm", "-r", str(DPI), "-aa", "no", "-aaVector", "no", "-png", "-singlefile", str(PDF), d + "/m"], check=True)
        return np.array(Image.open(d + "/m.png").convert("RGB"))


def dilate(m, r):
    for _ in range(r):
        n = m.copy(); n[1:] |= m[:-1]; n[:-1] |= m[1:]; n[:, 1:] |= m[:, :-1]; n[:, :-1] |= m[:, 1:]; m = n
    return m


# --- OSM: edifici in metri locali (x verso est, y verso nord) ---
ELS = json.loads(OSM.read_text(encoding="utf-8"))["elements"]
LAT0, LON0 = 44.0600, 12.5660
KX, KY = 111320.0 * math.cos(math.radians(LAT0)), 110574.0
def to_m(lon, lat): return ((lon - LON0) * KX, (lat - LAT0) * KY)
def to_ll(x, y): return (LON0 + x / KX, LAT0 + y / KY)
BUILDINGS = [[to_m(p["lon"], p["lat"]) for p in e["geometry"]] for e in ELS if e["type"] == "way" and "building" in e.get("tags", {})]


def osm_canvas(shape, s, th, cx, cy):
    """Contorni degli edifici OSM disegnati con la similitudine (s, th) che porta (0,0) m in (cx, cy) pixel"""
    img = Image.new("L", (shape[1], shape[0]), 0)
    dr = ImageDraw.Draw(img)
    c, sn = math.cos(th), math.sin(th)
    for b in BUILDINGS:
        pts = [(cx + s * (c * x - sn * y), cy - s * (sn * x + c * y)) for x, y in b]
        dr.line(pts, fill=1, width=1)
    return np.array(img, dtype=bool)


def register(gray, srange):
    """Cerca scala, rotazione e traslazione che sovrappongono le righe grigie agli edifici OSM.
    Le righe grigie hanno media zero nel riquadro e le immagini sono raddoppiate con zeri (niente «giro» della correlazione circolare); prima una ricerca grossolana
    a metà risoluzione, poi l'affinamento a piena risoluzione."""
    def prepare(g):
        H, W = g.shape
        d = dilate(g, 1).astype(np.float32)
        pad = np.zeros((2 * H, 2 * W), dtype=np.float32); pad[:H, :W] = d - d.mean()   # media zero: niente premio alle zone fitte
        return H, W, np.fft.rfft2(pad)
    def score(prep, s, th):
        H, W, target = prep
        o = osm_canvas((2 * H, 2 * W), s, th, W, H)
        corr = np.fft.irfft2(target * np.conj(np.fft.rfft2(o.astype(np.float32))), s=(2 * H, 2 * W))
        k = int(np.argmax(corr)); dy, dx = divmod(k, 2 * W)
        dy = dy - 2 * H if dy >= H else dy; dx = dx - 2 * W if dx >= W else dx
        return corr.flat[k] / max(1, o.sum()), W + dx, H + dy
    half = gray[: gray.shape[0] // 2 * 2, : gray.shape[1] // 2 * 2]
    half = half[0::2, 0::2] | half[1::2, 0::2] | half[0::2, 1::2] | half[1::2, 1::2]
    coarse, full = prepare(half), prepare(gray)
    best, s = None, srange[0]
    while s <= srange[1]:
        for th in np.radians(np.arange(-3, 3.01, 0.5)):
            v, cx, cy = score(coarse, s / 2, th)
            if best is None or v > best[0]: best = (v, s, th)
        s *= 1.015
    _, s0, th0 = best
    best = None
    for ds in np.linspace(0.985, 1.015, 13):
        for dth in np.radians(np.linspace(-0.5, 0.5, 11)):
            v, cx, cy = score(full, s0 * ds, th0 + dth)
            if best is None or v > best[0]: best = (v, s0 * ds, th0 + dth, cx, cy)
    v, s, th, cx, cy = best
    return {"score": round(float(v), 4), "pxPerMetre": round(float(s), 5), "rotationDeg": round(math.degrees(th), 3), "cx": float(cx), "cy": float(cy)}


def classify(img):
    """Classe di ogni pixel: indice in CLASSES, -1 = nessuna zona; le righe e le scritte prendono la classe vicina"""
    names = list(CLASSES)
    cls = np.full(img.shape[:2], -1, dtype=np.int8)
    known = np.zeros(img.shape[:2], dtype=bool)
    for i, n in enumerate(names):
        m = np.all(img == CLASSES[n][0], axis=2)
        cls[m] = i; known |= m
    white = np.all(img == 255, axis=2)
    known |= white   # il bianco è «fuori» (-1)
    # i pixel non classificati (righe grigie, scritte, simboli) prendono la classe più frequente attorno
    for _ in range(12):
        todo = ~known
        if not todo.any(): break
        votes = np.zeros((len(names) + 1,) + cls.shape, dtype=np.int16)
        for dy in range(-2, 3):
            for dx in range(-2, 3):
                sh = np.roll(np.roll(cls, dy, 0), dx, 1); kn = np.roll(np.roll(known, dy, 0), dx, 1)
                for i in range(-1, len(names)):
                    votes[i + 1] += (kn & (sh == i))
        tot = votes.sum(0)
        win = votes.argmax(0) - 1
        fill = todo & (tot > 0)
        cls[fill] = win[fill]; known |= fill
    return cls


def loops(mask):
    """Contorni esterni delle parti 4-connesse di una maschera (pixel), come in osm_geo.street_area"""
    H, W = mask.shape
    lab = np.zeros(mask.shape, dtype=np.int32); n = 0; out = []
    for y0, x0 in zip(*np.nonzero(mask)):
        if lab[y0, x0]: continue
        n += 1; lab[y0, x0] = n; st = [(y0, x0)]; comp = set()
        while st:
            y, x = st.pop(); comp.add((x, y))
            for yy, xx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= yy < H and 0 <= xx < W and mask[yy, xx] and not lab[yy, xx]:
                    lab[yy, xx] = n; st.append((yy, xx))
        cells = osm_geo._fill_holes(comp)
        nxt = {}
        for x, y in cells:   # y verso il basso: stessi lati di street_area
            if (x, y - 1) not in cells: nxt.setdefault((x, y), []).append((x + 1, y))
            if (x + 1, y) not in cells: nxt.setdefault((x + 1, y), []).append((x + 1, y + 1))
            if (x, y + 1) not in cells: nxt.setdefault((x + 1, y + 1), []).append((x, y + 1))
            if (x - 1, y) not in cells: nxt.setdefault((x, y + 1), []).append((x, y))
        rings = []
        while nxt:
            start = next(iter(nxt)); ring, cur = [start], start
            while True:
                cur = nxt[cur].pop()
                if not nxt[ring[-1]]: del nxt[ring[-1]]
                if cur == start: break
                ring.append(cur)
            rings.append(ring + [start])
        edge = any(x <= 0 or y <= 0 or x >= W - 1 or y >= H - 1 for x, y in comp)   # tagliata dal bordo del riquadro
        out.append((len(comp), edge, max(rings, key=lambda r: abs(osm_geo._signed_area(r)))))
    return out


def main():
    img = render()
    feats, meta = [], {}
    for frame, (box, srange) in FRAMES.items():
        x0, y0, x1, y1 = box
        sub = img[y0:y1, x0:x1]
        gray = np.all(sub == GRAY, axis=2)
        t = register(gray, srange)
        meta[frame] = t
        print(frame, t, file=sys.stderr)
        s, th = t["pxPerMetre"], math.radians(t["rotationDeg"])
        c, sn = math.cos(th), math.sin(th)
        def px_to_ll(u, v):
            a, b = (u - t["cx"]) / s, -(v - t["cy"]) / s   # = R(th)·(x, y)
            return to_ll(c * a + sn * b, -sn * a + c * b)
        cls = classify(sub)
        for i, name in enumerate(CLASSES):
            for npx, edge, ring in loops(cls == i):
                area_m2 = npx / (s * s)
                if area_m2 < 150: continue   # resti di simboli e scritte
                ll = [px_to_ll(u, v) for u, v in ring]
                ll = [[round(p[0], 7), round(p[1], 7)] for p in osm_geo.simplify_m(ll, 2.0)]
                feats.append({"type": "Feature", "properties": {"class": name, "legend": CLASSES[name][1], "frame": frame, "area_m2": round(area_m2), "cutByFrame": edge},
                              "geometry": {"type": "Polygon", "coordinates": [ll]}})
    OUT.write_text(json.dumps({"type": "FeatureCollection", "source": str(PDF.relative_to(ROOT)), "registration": meta,
                               "features": feats}, ensure_ascii=False) + "\n", encoding="utf-8")
    for f in feats:
        c = f["geometry"]["coordinates"][0]
        print(f["properties"]["frame"], f["properties"]["class"], f["properties"]["area_m2"], f["properties"]["cutByFrame"],
              round(sum(p[1] for p in c) / len(c), 5), round(sum(p[0] for p in c) / len(c), 5), file=sys.stderr)


if __name__ == "__main__":
    main()
