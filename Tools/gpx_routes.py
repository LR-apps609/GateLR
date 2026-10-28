#!/usr/bin/env python3
# I giri finti per la prova sul campo (docs/prova-sul-campo.md): percorsi stradali veri (OSRM, dati © OpenStreetMap)
# scritti come file GPX con orari realistici (25–35 km/h in città, più piano nelle curve), da scegliere in Xcode con
# Debug → Simulate Location mentre l'app gira sull'iPhone collegato.
#
# Due passi:
#   1. python3 Tools/gpx_routes.py fetch out/gpx-routes.json
#      scarica tutte le varianti di ogni giro da OSRM. Dal computer di casa i server di percorso possono essere
#      bloccati: gira anche su GitHub dentro Tools/intro_routes.py (workflow «Percorsi della presentazione»,
#      il risultato va nel ramo «intro-routes» accanto a intro-routes.json)
#   2. python3 Tools/gpx_routes.py build gpx-routes.json Resources/GPX
#      sceglie per ogni giro la variante che fa davvero quello che deve (passa dal varco giusto, resta fuori dalla ZTL…,
#      controllato con i perimetri e i varchi di Resources/Cities) e scrive i file .gpx
import json, math, sys, time, urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
UA = {"User-Agent": "GateLR/1.17 (ZTL checker; GPX test drives; github.com/LR-apps609/GateLR)"}

# Ogni giro: città, cosa deve succedere e le varianti di punti di passaggio (lat, lon), dalla partenza all'arrivo.
# «goal»: enter = entra nella zona «zone» passando a meno di 35 m dal varco «gate» · outside = mai dentro le zone
# «zones» · approach = mai dentro le zone, ma a meno di «near» metri da un varco di «zone»
ROUTES = {
    "firenze-viale-cavour-settore-a": {
        "city": "firenze", "goal": "enter", "zone": "firenze-a", "gate": "Via Cavour",
        "title": "Firenze: dal viale in Settore A dal varco di via Cavour",
        "variants": [
            [(43.78360, 11.25300), (43.78380, 11.26170), (43.77900, 11.25920), (43.77520, 11.25690)],
            [(43.78360, 11.25300), (43.78330, 11.26250), (43.77520, 11.25690)],
            [(43.78120, 11.26680), (43.78330, 11.26250), (43.77520, 11.25690)],
            [(43.78600, 11.26000), (43.78305, 11.26229), (43.77450, 11.25650)],
            [(43.78360, 11.25300), (43.78305, 11.26229), (43.77700, 11.25800), (43.77380, 11.25560)],
            # Il Settore A comincia a sud di via de' Pucci: arrivo verso il Duomo
            [(43.78360, 11.25300), (43.78305, 11.26229), (43.77410, 11.25610)],
            [(43.78360, 11.25300), (43.78305, 11.26229), (43.77310, 11.25690)],
            [(43.78360, 11.25300), (43.78305, 11.26229), (43.77220, 11.25800)],
            [(43.78360, 11.25300), (43.78305, 11.26229), (43.77780, 11.25930), (43.77350, 11.25750)],
            [(43.78120, 11.26680), (43.78305, 11.26229), (43.77220, 11.25800)],
        ],
    },
    "firenze-viali-parcheggio-beccaria": {
        "city": "firenze", "goal": "outside", "zones": ["firenze-a", "firenze-b", "firenze-o"],
        "title": "Firenze: intorno alla ZTL lungo i viali fino al Parcheggio Beccaria", "prefer": 1,
        "variants": [
            [(43.77950, 11.23950), (43.78380, 11.25600), (43.78000, 11.26850), (43.769894, 11.270761)],
            [(43.77950, 11.23950), (43.78200, 11.24700), (43.78380, 11.26170), (43.77650, 11.27050), (43.769894, 11.270761)],
            [(43.78150, 11.24600), (43.78380, 11.25600), (43.78000, 11.26850), (43.769894, 11.270761)],
            [(43.78600, 11.24700), (43.78000, 11.26850), (43.769894, 11.270761)],
        ],
    },
    "pisa-intorno-alla-ztl": {
        "city": "pisa", "goal": "outside", "zones": ["pisa-ztl-nord", "pisa-ztl-sud"],
        "title": "Pisa: il giro intorno alla ZTL",
        "variants": [
            [(43.71380, 10.39050), (43.72550, 10.39650), (43.72350, 10.41050), (43.71550, 10.41300)],
            [(43.70950, 10.39300), (43.71400, 10.39000), (43.72550, 10.39650), (43.72400, 10.41200), (43.71350, 10.41350)],
            [(43.71500, 10.38900), (43.72800, 10.39900), (43.72150, 10.41300), (43.71500, 10.41200)],
            [(43.72340, 10.38990), (43.72860, 10.39200), (43.72407, 10.41233), (43.71945, 10.42749)],
        ],
    },
    "roma-tridente-avvicinamento": {
        "city": "roma", "goal": "approach", "zone": "roma-tridente", "zones": ["roma-tridente", "roma-centro"], "near": 450,
        "title": "Roma: verso la ZTL Tridente e poi via, senza entrare",
        "variants": [
            [(41.92000, 12.47100), (41.91180, 12.47620), (41.90970, 12.47180), (41.90750, 12.46800)],
            [(41.91300, 12.47200), (41.91000, 12.47350), (41.90600, 12.47380), (41.90540, 12.47050)],
            [(41.92000, 12.47100), (41.91180, 12.47620), (41.910129, 12.473069)],
            [(41.91800, 12.47300), (41.91200, 12.47500), (41.90900, 12.46900)],
        ],
    },
    "bologna-in-centro-dal-varco": {
        "city": "bologna", "goal": "enter", "zone": "bologna-ztl", "gate": None,
        "title": "Bologna: in centro da un varco", "prefer": 0,
        "variants": [
            [(44.49920, 11.32400), (44.498921, 11.327967), (44.49750, 11.33300)],
            [(44.49450, 11.32500), (44.494527, 11.329338), (44.49400, 11.33400)],
            [(44.48950, 11.32600), (44.49028, 11.330778), (44.49150, 11.33550)],
            [(44.50400, 11.33850), (44.499447, 11.338636), (44.49600, 11.33900)],
            [(44.50380, 11.34700), (44.4994, 11.346812), (44.49700, 11.34650)],
        ],
    },
    "siena-avvicinamento-varco": {
        "city": "siena", "goal": "approach", "zone": "siena-ztl", "zones": ["siena-ztl"], "near": 200,
        "title": "Siena: fino a un varco e poi al parcheggio fuori",
        "variants": [
            [(43.33600, 11.31900), (43.32920, 11.32460), (43.327056, 11.32288)],
            [(43.34100, 11.32700), (43.32920, 11.32480), (43.325348, 11.32189)],
            [(43.30850, 11.31700), (43.31150, 11.32350), (43.314286, 11.323743)],
            [(43.33123, 11.323059), (43.32900, 11.32470), (43.322193, 11.32478)],
        ],
    },
}


def get(url):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()


def osrm(points):
    coords = ";".join(f"{lon},{lat}" for lat, lon in points)
    err = ""
    for host in ["https://router.project-osrm.org/route/v1/driving",
                 "https://routing.openstreetmap.de/routed-car/route/v1/driving"]:
        try:
            j = json.loads(get(f"{host}/{coords}?overview=full&geometries=geojson&steps=true"))
            r = j["routes"][0]
            names = []
            for leg in r["legs"]:
                for s in leg["steps"]:
                    if s.get("name") and (not names or names[-1] != s["name"]):
                        names.append(s["name"])
            return {"distance": r["distance"], "duration": r["duration"], "streets": names,
                    "coords": [[round(c[1], 6), round(c[0], 6)] for c in r["geometry"]["coordinates"]]}
        except Exception as e:  # noqa: BLE001
            err = str(e)
        time.sleep(1.1)
    return {"error": err}


def fetch(out):
    res = {}
    for name, r in ROUTES.items():
        res[name] = []
        for v in r["variants"]:
            res[name].append(osrm(v))
            time.sleep(1.1)
    out = Path(out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(res, indent=0))
    for name, vs in res.items():
        print("gpx", name, [round(v.get("distance", -1)) for v in vs], [v.get("error", "")[:60] for v in vs if "error" in v])


# MARK: Controllo e scrittura

def meters(a, b):
    k = math.cos(math.radians((a[0] + b[0]) / 2))
    return math.hypot((a[0] - b[0]) * 111_320, (a[1] - b[1]) * 111_320 * k)


def inside(ring, lat, lon):
    c, n = False, len(ring)
    for i in range(n):
        (y1, x1), (y2, x2) = ring[i], ring[(i + 1) % n]
        if (y1 > lat) != (y2 > lat) and lon < (x2 - x1) * (lat - y1) / (y2 - y1) + x1:
            c = not c
    return c


def densify(pts, step=10.0):
    out = [pts[0]]
    for a, b in zip(pts, pts[1:]):
        d = meters(a, b)
        n = max(1, int(d // step))
        for i in range(1, n + 1):
            t = i / n
            out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    return out


def city_data(cid):
    j = json.loads((ROOT / f"Resources/Cities/{cid}.json").read_text())
    zones = {z["id"]: ([(p["lat"], p["lon"]) for p in z["perimeter"]], z["gates"]) for z in j["zones"]}
    return zones


def judge(spec, route):
    """(va bene, punteggio più basso = meglio, note)"""
    if "coords" not in route:
        return False, 1e9, route.get("error", "")
    zones = city_data(spec["city"])
    pts = densify([tuple(c) for c in route["coords"]])
    if spec["goal"] == "enter":
        ring, gates = zones[spec["zone"]]
        # Il varco: quello con il nome dato, o un varco qualsiasi della zona
        if spec.get("gate"):
            gates = [g for z in zones.values() for g in z[1] if g["name"] == spec["gate"]]
        best = min(((min(meters(p, (g["location"]["lat"], g["location"]["lon"])) for p in pts), g["name"]) for g in gates),
                   default=(1e9, ""))
        end_in = inside(ring, *pts[-1])
        ins = [inside(ring, *p) for p in pts]
        # Entra una volta sola e resta dentro fino alla fine
        changes = sum(1 for a, b in zip(ins, ins[1:]) if a != b)
        ok = best[0] < 35 and end_in and changes == 1
        return ok, route["distance"] + (0 if ok else 1e6), f"varco {best[1]} a {best[0]:.0f} m, fine dentro {end_in}, entrate {changes}"
    rings = [zones[z][0] for z in spec["zones"]]
    inside_m = sum(1 for p in pts if any(inside(r, *p) for r in rings)) * 10
    if spec["goal"] == "outside":
        ok = inside_m == 0
        return ok, route["distance"] + inside_m * 1000, f"dentro {inside_m} m"
    # approach
    _, gates = zones[spec["zone"]]
    near = min(meters(p, (g["location"]["lat"], g["location"]["lon"])) for p in pts for g in gates)
    ok = inside_m == 0 and near < spec["near"]
    return ok, near + inside_m * 1000 + (0 if ok else 1e6), f"dentro {inside_m} m, varco più vicino a {near:.0f} m"


def bearing(a, b):
    y = math.sin(math.radians(b[1] - a[1])) * math.cos(math.radians(b[0]))
    x = math.cos(math.radians(a[0])) * math.sin(math.radians(b[0])) - \
        math.sin(math.radians(a[0])) * math.cos(math.radians(b[0])) * math.cos(math.radians(b[1] - a[1]))
    return (math.degrees(math.atan2(y, x)) + 360) % 360


def timed(coords, cruise=31.0):
    """I punti ogni 10 m circa con l'ora di passaggio: velocità di crociera ~31 km/h (tra 28 e 34 lungo la strada),
    14 km/h nelle curve strette, 20 in quelle larghe, accelerazione e frenata morbide, partenza e arrivo da fermi"""
    pts = densify([tuple(c) for c in coords], 10.0)
    # via i doppioni
    clean = [pts[0]]
    for p in pts[1:]:
        if meters(clean[-1], p) > 0.5:
            clean.append(p)
    pts = clean
    n = len(pts)
    v = []
    for i in range(n):
        # un'onda lenta tra 28 e 34 km/h, così la velocità non è sempre la stessa
        s = cruise + 3 * math.sin(i / 37.0)
        if 0 < i < n - 1:
            turn = abs((bearing(pts[i], pts[i + 1]) - bearing(pts[i - 1], pts[i]) + 180) % 360 - 180)
            # la curva si guarda su una finestra di 30 m, non solo sul punto
            j0, j1 = max(0, i - 3), min(n - 1, i + 3)
            if j1 > i and i > j0:
                turn = max(turn, abs((bearing(pts[i], pts[j1]) - bearing(pts[j0], pts[i]) + 180) % 360 - 180))
            if turn > 55:
                s = 14
            elif turn > 25:
                s = 20
        v.append(s / 3.6)
    v[0] = 0.0
    v[-1] = 0.0
    acc = 1.2   # m/s²
    for i in range(1, n):
        d = meters(pts[i - 1], pts[i])
        v[i] = min(v[i], math.sqrt(v[i - 1] ** 2 + 2 * acc * d))
    for i in range(n - 2, -1, -1):
        d = meters(pts[i], pts[i + 1])
        v[i] = min(v[i], math.sqrt(v[i + 1] ** 2 + 2 * acc * d))
    t = 0.0
    out = [(pts[0], 0.0)]
    for i in range(1, n):
        d = meters(pts[i - 1], pts[i])
        mean = max((v[i - 1] + v[i]) / 2, 0.8)
        t += d / mean
        out.append((pts[i], t))
    return out


def per_second(points):
    """La posizione a ogni secondo intero, interpolata tra i punti con l'ora di passaggio"""
    out, j = [], 0
    total = points[-1][1]
    for sec in range(int(math.ceil(total)) + 1):
        t = min(sec, total)
        while j < len(points) - 2 and points[j + 1][1] < t:
            j += 1
        (a, ta), (b, tb) = points[j], points[j + 1]
        f = 0 if tb <= ta else max(0.0, min(1.0, (t - ta) / (tb - ta)))
        out.append((a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f))
    return out


def gpx(name, title, points, start=datetime(2026, 10, 28, 9, 0, 0, tzinfo=timezone.utc)):
    lines = ['<?xml version="1.0" encoding="UTF-8"?>',
             '<gpx version="1.1" creator="GateLR Tools/gpx_routes.py" xmlns="http://www.topografix.com/GPX/1/1">',
             f'  <metadata><name>{title}</name><desc>Percorso OSRM, dati © OpenStreetMap contributors (ODbL). '
             f'Solo per la prova sul campo con Xcode (Debug → Simulate Location).</desc></metadata>']
    # Tre secondi fermi alla partenza: l'app trova la posizione prima che l'auto si muova
    first = points[0][0]
    for k in range(3):
        lines.append(f'  <wpt lat="{first[0]:.6f}" lon="{first[1]:.6f}"><time>{(start + timedelta(seconds=k)).strftime("%Y-%m-%dT%H:%M:%SZ")}</time></wpt>')
    # Un punto al secondo, come un GPS vero (e orari a secondi interi, che Xcode legge di sicuro)
    for k, (lat, lon) in enumerate(per_second(points)):
        when = start + timedelta(seconds=3 + k)
        lines.append(f'  <wpt lat="{lat:.6f}" lon="{lon:.6f}"><time>{when.strftime("%Y-%m-%dT%H:%M:%SZ")}</time></wpt>')
    lines.append("</gpx>")
    return "\n".join(lines) + "\n"


def build(src, outdir):
    data = json.loads(Path(src).read_text())
    outdir = Path(outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    for name, spec in ROUTES.items():
        best = None
        for i, r in enumerate(data.get(name, [])):
            ok, score, note = judge(spec, r)
            print(f"{name} variante {i}: {'OK' if ok else '--'} {round(r.get('distance', 0))} m · {note}")
            # «prefer»: la variante scelta a mano (la più adatta alla prova), se va bene
            if ok and spec.get("prefer") == i:
                score = -1
            if ok and (best is None or score < best[0]):
                best = (score, i, r)
        if best is None:
            print(f"!! {name}: nessuna variante va bene")
            continue
        pts = timed(best[2]["coords"])
        km = best[2]["distance"] / 1000
        mins = pts[-1][1] / 60
        print(f"   → variante {best[1]}: {km:.2f} km in {mins:.1f} min ({km / (pts[-1][1] / 3600):.0f} km/h di media) · "
              f"{' → '.join(best[2]['streets'][:8])}")
        (outdir / f"{name}.gpx").write_text(gpx(name, spec["title"], pts), encoding="utf-8")


if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == "fetch":
        fetch(sys.argv[2])
    elif len(sys.argv) >= 4 and sys.argv[1] == "build":
        build(sys.argv[2], sys.argv[3])
    else:
        print(__doc__ or "uso: gpx_routes.py fetch OUT.json | build IN.json CARTELLA")
