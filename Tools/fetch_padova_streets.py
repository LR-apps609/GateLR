#!/usr/bin/env python3
# Padova: scarica dall API OpenStreetMap 0.6 (/api/0.6/map, riquadri di ~0,005°) le strade con nome del centro e le salva
# in data/raw/padova/osm-strade-centro.json (formato Overpass «out geom», © OpenStreetMap contributors, ODbL 1.0).
# Servono a Tools/build_padova.py per il contorno della Zona B. Uso: python3 Tools/fetch_padova_streets.py <cartella temporanea>
import subprocess, sys, json, xml.etree.ElementTree as ET
S, W, N, E = 45.398, 11.866, 45.4125, 11.8855
step = 0.0049
out_dir = sys.argv[1]
dest = __import__("pathlib").Path(__file__).resolve().parent.parent / "data/raw/padova/osm-strade-centro.json"
ways, rels, nodes = {}, {}, {}
lat = S
i = 0
while lat < N:
    lon = W
    while lon < E:
        bb = f"{lon:.4f},{lat:.4f},{min(lon+step,E):.4f},{min(lat+step,N):.4f}"
        f = f"{out_dir}/t{i}.osm"; i += 1
        subprocess.run(["curl", "-sS", "-m", "180", "--retry", "3", "-A", "GateLR/1.0 (ZTL checker)", "-o", f,
                        f"https://www.openstreetmap.org/api/0.6/map?bbox={bb}"], check=True)
        root = ET.parse(f).getroot()
        for n in root.findall("node"):
            nodes[int(n.get("id"))] = (float(n.get("lat")), float(n.get("lon")))
        for w in root.findall("way"):
            tg = {t.get("k"): t.get("v") for t in w.findall("tag")}
            if "highway" in tg and "name" in tg:
                ways[int(w.get("id"))] = (tg, [int(nd.get("ref")) for nd in w.findall("nd")])
        for r in root.findall("relation"):
            tg = {t.get("k"): t.get("v") for t in r.findall("tag")}
            rels[int(r.get("id"))] = (tg, [(m.get("type"), int(m.get("ref")), m.get("role")) for m in r.findall("member")])
        print(bb, len(ways), file=sys.stderr)
        lon += step
    lat += step
els = []
for wid, (tg, nds) in ways.items():
    if all(n in nodes for n in nds):
        els.append({"type": "way", "id": wid, "tags": tg, "geometry": [{"lat": round(nodes[n][0], 7), "lon": round(nodes[n][1], 7)} for n in nds]})
json.dump({"source": "https://www.openstreetmap.org/api/0.6/map (riquadri del centro di Padova), letto il 2026-10-25",
           "license": "© OpenStreetMap contributors, ODbL 1.0", "elements": els}, open(dest, "w"), ensure_ascii=False, separators=(",", ":"))
print(len(els), "elementi", file=sys.stderr)
