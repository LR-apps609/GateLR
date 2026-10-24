#!/usr/bin/env python3
# Scarica le geometrie che da questo ambiente non si raggiungono (OpenStreetMap/Overpass, mappe ArcGIS di Roma).
# Gira su GitHub Actions (.github/workflows/geo.yml) e salva tutto in data/raw/geo/ per i builder delle città.
import json, sys, time, urllib.parse, urllib.request
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "data/raw/geo"
OUT.mkdir(parents=True, exist_ok=True)
UA = {"User-Agent": "GateLR/1.0 (ZTL checker; github.com/LR-apps609/GateLR)"}

def get(url, data=None, tries=4):
    for i in range(tries):
        try:
            req = urllib.request.Request(url, data=data, headers=UA)
            with urllib.request.urlopen(req, timeout=180) as r:
                return r.read()
        except Exception as e:
            print("  retry", i + 1, url[:90], e); time.sleep(8 * (i + 1))
    return None

def overpass(name, query):
    body = urllib.parse.urlencode({"data": query}).encode()
    for host in ["https://overpass-api.de/api/interpreter", "https://overpass.kumi.systems/api/interpreter",
                 "https://overpass.private.coffee/api/interpreter"]:
        raw = get(host, body, tries=2)
        if raw:
            (OUT / f"{name}.json").write_bytes(raw); print("ok", name, len(raw), host); return
    print("FAILED", name)

# Bounding box per città (sud, ovest, nord, est)
BOX = {"siena": (43.305, 11.315, 43.335, 11.345), "pisa": (43.70, 10.38, 43.73, 10.42),
       "roma": (41.86, 12.44, 41.92, 12.53), "lucca": (43.835, 10.49, 43.85, 10.515)}

for city, (s, w, n, e) in BOX.items():
    bb = f"{s},{w},{n},{e}"
    # Zone ZTL disegnate in OSM, mura storiche, cartelli/varchi e semafori lungo le strade
    overpass(f"{city}-ztl", f"""[out:json][timeout:120];
(
  way["name"~"ZTL|Zona a traffico limitato|Traffico Limitato",i]({bb});
  relation["name"~"ZTL|Zona a traffico limitato|Traffico Limitato",i]({bb});
  way["boundary"~"low_emission_zone|limited_traffic_zone"]({bb});
  relation["boundary"~"low_emission_zone|limited_traffic_zone"]({bb});
  way["zone:traffic"]({bb});
  relation["type"="boundary"]["boundary"="administrative"]["name"~"Centro storico",i]({bb});
);
out geom;""")
    overpass(f"{city}-walls", f"""[out:json][timeout:120];
( way["historic"="citywalls"]({bb}); relation["historic"="citywalls"]({bb}); way["barrier"="city_wall"]({bb}); );
out geom;""")
    overpass(f"{city}-gates", f"""[out:json][timeout:120];
( node["enforcement"]({bb}); node["highway"="speed_camera"]({bb}); node["description"~"ZTL|varco",i]({bb});
  node["name"~"ZTL|varco",i]({bb}); relation["type"="enforcement"]({bb}); );
out geom;""")

# Semafori di Firenze, Bologna, Milano (per mostrarli lungo il percorso)
for city, bb in {"firenze": "43.755,11.235,43.79,11.28", "bologna": "44.48,11.32,44.51,11.365", "milano": "45.44,9.15,45.495,9.225"}.items():
    overpass(f"{city}-signals", f"""[out:json][timeout:120];node["highway"="traffic_signals"]({bb});out;""")

# Roma: ricerca dei dataset ZTL sull'hub ArcGIS di Roma Servizi per la Mobilità (CC BY 3.0 IT)
for q in ["ztl", "varchi", "zona traffico limitato"]:
    raw = get("https://data-rsm.opendata.arcgis.com/api/search/v1/collections/dataset/items?" + urllib.parse.urlencode({"q": q, "limit": 50}))
    if raw: (OUT / f"roma-hub-{q.replace(' ', '_')}.json").write_bytes(raw); print("ok hub", q, len(raw))
    else: print("FAILED hub", q)

print("files:", sorted(p.name for p in OUT.iterdir()))
