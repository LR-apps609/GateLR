#!/usr/bin/env python3
# Solo per il prototipo della nuova presentazione (Sources/Intro2): scarica percorsi stradali veri a Firenze
# (OSRM, dati © OpenStreetMap) e i parcheggi vicini ai viali (Overpass), da cui si scelgono a mano i percorsi
# scritti in Sources/Intro2/IntroGeo.swift. Gira su GitHub (workflow intro-routes.yml), il risultato va nel ramo «intro-routes».
import json, urllib.request, urllib.parse, sys, time
OUT = sys.argv[1] if len(sys.argv) > 1 else "intro-routes.json"

def get(url, data=None):
    req = urllib.request.Request(url, data=data, headers={"User-Agent": "GateLR-intro-prototype/1.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)

def osrm(points):
    coords = ";".join(f"{lon},{lat}" for lat, lon in points)
    url = f"https://router.project-osrm.org/route/v1/driving/{coords}?overview=full&geometries=geojson&steps=true"
    try:
        j = get(url)
        r = j["routes"][0]
        names = [s.get("name", "") for leg in r["legs"] for s in leg["steps"]]
        return {"distance": r["distance"], "duration": r["duration"],
                "coords": [[c[1], c[0]] for c in r["geometry"]["coordinates"]], "streets": names}
    except Exception as e:
        return {"error": str(e)}

gates = {"guelfa": (43.777767, 11.254444), "ruote": (43.781448, 11.256587), "scala": (43.774943, 11.24642),
         "cavour": (43.78305, 11.262289), "agnolo": (43.769769, 11.266759), "tintori": (43.766932, 11.261933)}
starts = {"lavagnini": (43.7838, 11.2545), "liberta": (43.7853, 11.2588), "indipendenza": (43.7792, 11.2525),
          "strozzi": (43.7800, 11.2470), "beccaria": (43.7695, 11.2680), "sangallo": (43.7820, 11.2575)}
dests = {"duomo": (43.7740, 11.2556), "signoria": (43.7697, 11.2563)}
parks = {"parterre": (43.7866, 11.2603), "fortezza": (43.7808, 11.2462), "beccaria": (43.7690, 11.2693),
         "stazione": (43.7767, 11.2472)}
out = {"red": {}, "white": {}, "parking": []}
for gname, g in gates.items():
    for sname, s in starts.items():
        for dname, d in dests.items():
            out["red"][f"{sname}>{gname}>{dname}"] = osrm([s, g, d]); time.sleep(1.1)
for sname, s in starts.items():
    for pname, p in parks.items():
        out["white"][f"{sname}>{pname}"] = osrm([s, p]); time.sleep(1.1)
q = '[out:json][timeout:60];nwr["amenity"="parking"](43.762,11.238,43.790,11.275);out center tags;'
try:
    j = get("https://overpass-api.de/api/interpreter", urllib.parse.urlencode({"data": q}).encode())
    for e in j["elements"]:
        c = e.get("center") or {"lat": e.get("lat"), "lon": e.get("lon")}
        t = e.get("tags", {})
        out["parking"].append({"name": t.get("name", ""), "lat": c["lat"], "lon": c["lon"], "access": t.get("access", ""),
                               "parking": t.get("parking", ""), "fee": t.get("fee", ""), "id": f"{e['type']}/{e['id']}"})
except Exception as e:
    out["parking_error"] = str(e)
json.dump(out, open(OUT, "w"), indent=0)
print("rossi", sum("coords" in v for v in out["red"].values()), "bianchi", sum("coords" in v for v in out["white"].values()), "parcheggi", len(out["parking"]))
