#!/usr/bin/env python3
# Parma: scarica dall'API OpenStreetMap 0.6 (/api/0.6/map, riquadri di ~0,005°) le strade con nome del centro storico
# e le salva in data/raw/geo/parma-streets.json (formato Overpass «out geom», © OpenStreetMap contributors, ODbL 1.0).
# Servono a Tools/build_parma.py per il contorno delle Isole Ambientali (dall'elenco ufficiale delle vie) e per
# la posizione dei varchi. Uso: python3 Tools/fetch_parma_streets.py <cartella temporanea>
import json, subprocess, sys, xml.etree.ElementTree as ET
from pathlib import Path

S, W, N, E = 44.7935, 10.3165, 44.8105, 10.3420
step = 0.0049
out_dir = sys.argv[1]
dest = Path(__file__).resolve().parent.parent / "data/raw/geo/parma-streets.json"
ways, nodes = {}, {}
lat, i = S, 0
while lat < N:
    lon = W
    while lon < E:
        bb = f"{lon:.4f},{lat:.4f},{min(lon + step, E):.4f},{min(lat + step, N):.4f}"
        f = f"{out_dir}/t{i}.osm"
        i += 1
        subprocess.run(["curl", "-sS", "-m", "180", "--retry", "3", "-A", "GateLR/1.0 (ZTL checker)", "-o", f,
                        f"https://www.openstreetmap.org/api/0.6/map?bbox={bb}"], check=True)
        root = ET.parse(f).getroot()
        for n in root.findall("node"):
            nodes[int(n.get("id"))] = (float(n.get("lat")), float(n.get("lon")))
        for w in root.findall("way"):
            tg = {t.get("k"): t.get("v") for t in w.findall("tag")}
            if "highway" in tg and "name" in tg:
                ways[int(w.get("id"))] = (tg, [int(nd.get("ref")) for nd in w.findall("nd")])
        print(bb, len(ways), file=sys.stderr)
        lon += step
    lat += step
els = []
for wid, (tg, nds) in sorted(ways.items()):
    if all(n in nodes for n in nds):
        els.append({"type": "way", "id": wid, "tags": {k: tg[k] for k in ("name", "highway", "oneway", "area") if k in tg},
                    "geometry": [{"lat": round(nodes[n][0], 7), "lon": round(nodes[n][1], 7)} for n in nds]})
json.dump({"source": "https://www.openstreetmap.org/api/0.6/map (riquadri del centro di Parma), letto il 2026-10-26",
           "license": "© OpenStreetMap contributors, ODbL 1.0", "elements": els}, open(dest, "w"), ensure_ascii=False, separators=(",", ":"))
print(len(els), "elementi", file=sys.stderr)
