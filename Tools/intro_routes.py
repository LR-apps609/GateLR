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

# I percorsi scelti: dal viale Lavagnini (fuori dalla ZTL) dentro dal varco di via Cavour verso il Duomo,
# oppure lungo i viali fino al parcheggio Parterre (OSM node/559981489, fuori dalla ZTL)
start = (43.782961, 11.257894)
cavour = (43.78305, 11.262289)
parterre = (43.7855947, 11.2643376)
out = {"red": {}, "white": {}, "parking": []}
for name, d in {"duomo": (43.7740, 11.2556), "proconsolo": (43.7718, 11.2575), "servi": (43.7745, 11.2575),
                "martelli": (43.7738, 11.2549)}.items():
    out["red"][f"lavagnini>cavour>{name}"] = osrm([start, cavour, d]); time.sleep(1.1)
out["white"]["lavagnini>parterre"] = osrm([start, parterre]); time.sleep(1.1)
out["white"]["lavagnini>liberta>parterre"] = osrm([start, (43.7848, 11.2600), parterre])
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
