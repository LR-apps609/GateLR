#!/usr/bin/env python3
# Solo per la prima pagina della nuova presentazione (Sources/Intro2): scarica percorsi stradali veri a Firenze
# (OSRM, dati © OpenStreetMap) e gli edifici del centro (Overpass), da cui si scelgono i percorsi scritti in
# Sources/Intro2/IntroGeo.swift e si prepara Resources/Intro/firenze-edifici.geojson (Tools/intro_buildings.py).
# Gira su GitHub (workflow intro-routes.yml), il risultato va nel ramo «intro-routes».
#
# La scena (1.15.2): un ristorante DENTRO la ZTL (via Verdi, vicino a Santa Croce) e il Parcheggio Beccaria FUORI.
#  1. «La strada più diretta»: dalla partenza dritto al ristorante, dentro dal varco → verbale
#  2. «Con GateLR»: fino al Parcheggio Beccaria (OSM way/231098032), sempre fuori dalla ZTL
#  3. a piedi dal parcheggio al ristorante
# Si provano più partenze dall'altra parte del centro, per scegliere quella in cui la strada dritta è davvero la più corta.
import json, math, sys, time, urllib.parse, urllib.request
from pathlib import Path

OUT = Path(sys.argv[1] if len(sys.argv) > 1 else "intro-routes.json")
UA = {"User-Agent": "GateLR/1.15 (ZTL checker; intro animation routes; github.com/LR-apps609/GateLR)"}
ROOT = Path(__file__).resolve().parent.parent


def get(url, data=None):
    req = urllib.request.Request(url, data=data, headers=UA)
    with urllib.request.urlopen(req, timeout=240) as r:
        return r.read()


def route(points, profile="driving"):
    coords = ";".join(f"{lon},{lat}" for lat, lon in points)
    hosts = (["https://router.project-osrm.org/route/v1/driving"] if profile == "driving"
             else ["https://routing.openstreetmap.de/routed-foot/route/v1/foot"])
    for host in hosts:
        try:
            j = json.loads(get(f"{host}/{coords}?overview=full&geometries=geojson&steps=true"))
            r = j["routes"][0]
            names = []
            for leg in r["legs"]:
                for s in leg["steps"]:
                    if s.get("name") and (not names or names[-1] != s["name"]):
                        names.append(s["name"])
            return {"distance": r["distance"], "duration": r["duration"],
                    "coords": [[round(c[1], 6), round(c[0], 6)] for c in r["geometry"]["coordinates"]], "streets": names}
        except Exception as e:  # noqa: BLE001
            err = str(e)
        time.sleep(1.1)
    return {"error": err}


# Le ZTL di Firenze (Settori A, B, O, F, G) per controllare quanta strada di ogni percorso ci passa dentro
city = json.loads((ROOT / "Resources/Cities/firenze.json").read_text())
zones = [[(p["lat"], p["lon"]) for p in z["perimeter"]] for z in city["zones"] if z["id"] in
         ("firenze-a", "firenze-b", "firenze-o", "firenze-f", "firenze-g")]
gates = [(g["name"], g["location"]["lat"], g["location"]["lon"]) for z in city["zones"] for g in z["gates"]]


def inside(lat, lon):
    for ring in zones:
        n, c = len(ring), False
        for i in range(n):
            (y1, x1), (y2, x2) = ring[i], ring[(i + 1) % n]
            if (y1 > lat) != (y2 > lat) and lon < (x2 - x1) * (lat - y1) / (y2 - y1) + x1:
                c = not c
        if c:
            return True
    return False


def meters(a, b):
    k = math.cos(math.radians(a[0]))
    return math.hypot((a[0] - b[0]) * 111320, (a[1] - b[1]) * 111320 * k)


def check(r):
    if "coords" not in r:
        return
    pts, ins = r["coords"], 0.0
    for a, b in zip(pts, pts[1:]):
        # metà di ogni tratto: basta per sapere se il percorso entra (i tratti sono corti)
        if inside((a[0] + b[0]) / 2, (a[1] + b[1]) / 2):
            ins += meters(a, b)
    r["inside_m"] = round(ins)
    r["gates"] = sorted({g[0] for g in gates for p in pts if meters(p, (g[1], g[2])) < 25})


starts = {"lavagnini": (43.782961, 11.257894), "strozzi": (43.78345, 11.24960), "prato": (43.77720, 11.23900),
          "belfiore": (43.78100, 11.24200)}
gates_w = {"cavour": (43.78305, 11.262289), "guelfa": (43.777767, 11.254444), "scala": (43.774943, 11.24642),
           "ruote": (43.781448, 11.256587)}
beccaria = (43.769894, 11.270761)    # Parcheggio Beccaria, sotterraneo (OSM way/231098032)
dest = {"verdi": (43.7700, 11.2610), "albizi": (43.7708, 11.2580), "sanpier": (43.7710, 11.2595)}

out = {"direct": {}, "parking": {}, "walk": {}}
for sn, s0 in starts.items():
    for dn, d in dest.items():
        out["direct"][f"{sn}>{dn}"] = route([s0, d]); time.sleep(1.1)
        for gn, g in gates_w.items():
            out["direct"][f"{sn}>{gn}>{dn}"] = route([s0, g, d]); time.sleep(1.1)
    out["parking"][sn] = route([s0, beccaria]); time.sleep(1.1)
for dn, d in dest.items():
    out["walk"][dn] = route([beccaria, d], "foot"); time.sleep(1.1)
for group in out.values():
    for r in group.values():
        check(r)
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(json.dumps(out, indent=0))
for g, rs in out.items():
    for n, r in rs.items():
        print(g, n, round(r.get("distance", 0)), "m", round(r.get("duration", 0)), "s", "dentro", r.get("inside_m"), "m",
              r.get("gates"), r.get("error", ""))

# Gli edifici intorno alla scena (vie e relazioni con building=*), per gli edifici 3D trasparenti della mappa
q = ('[out:json][timeout:240];(way["building"](43.758,11.238,43.794,11.292);'
     'relation["building"](43.758,11.238,43.794,11.292););out geom tags;')
for host in ["https://overpass-api.de/api/interpreter", "https://overpass.kumi.systems/api/interpreter",
             "https://maps.mail.ru/osm/tools/overpass/api/interpreter", "https://overpass.private.coffee/api/interpreter"]:
    try:
        raw = get(host, urllib.parse.urlencode({"data": q}).encode())
        n = len(json.loads(raw)["elements"])
        (OUT.parent / "firenze-buildings-osm.json").write_bytes(raw)
        print("edifici", n, "da", host)
        break
    except Exception as e:  # noqa: BLE001
        print("edifici: errore", host, e)
