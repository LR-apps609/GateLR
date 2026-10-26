#!/usr/bin/env python3
# Scarica dati OSM dall'API principale (www.openstreetmap.org/api/0.6/map) a tasselli, più le relazioni ZTL complete,
# e li converte nel formato Overpass «out geom» usato da Tools/osm_geo.py (quando Overpass non risponde).
# Dati © OpenStreetMap contributors, ODbL 1.0. Uso: python3 Tools/fetch_osm_api.py out.json sud ovest nord est [passo_gradi]
import sys, json, time, urllib.request, xml.etree.ElementTree as ET
out, s, w, n, e = sys.argv[1], *map(float, sys.argv[2:6])
step = float(sys.argv[6]) if len(sys.argv) > 6 else 0.004
API = "https://www.openstreetmap.org/api/0.6"
UA = {"User-Agent": "GateLR-data-research/1.0 (github.com/LR-apps609/GateLR)"}
def get(url):
    for i in range(4):
        try:
            return ET.fromstring(urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=120).read())
        except Exception as ex:
            print("retry", url, ex, file=sys.stderr); time.sleep(3 + 5 * i)
    raise SystemExit("failed " + url)
nodes, ways, rels = {}, {}, {}
def ingest(root):
    for el in root:
        tags = {t.get("k"): t.get("v") for t in el.findall("tag")}
        if el.tag == "node":
            nodes[int(el.get("id"))] = {"type": "node", "id": int(el.get("id")), "lat": float(el.get("lat")), "lon": float(el.get("lon")), **({"tags": tags} if tags else {})}
        elif el.tag == "way":
            ways[int(el.get("id"))] = {"type": "way", "id": int(el.get("id")), "nodes": [int(x.get("ref")) for x in el.findall("nd")], **({"tags": tags} if tags else {})}
        elif el.tag == "relation":
            rels[int(el.get("id"))] = {"type": "relation", "id": int(el.get("id")), "members": [{"type": m.get("type"), "ref": int(m.get("ref")), "role": m.get("role")} for m in el.findall("member")], "tags": tags}
lat = s
while lat < n:
    lon = w
    while lon < e:
        ingest(get(f"{API}/map?bbox={lon:.5f},{lat:.5f},{min(lon+step,e):.5f},{min(lat+step,n):.5f}")); time.sleep(1)
        lon += step
    lat += step
# relazioni interessanti: scarica complete (membri fuori dai tasselli)
want = lambda t: t.get("boundary") == "limited_traffic_zone" or t.get("type") == "enforcement" or "ZTL" in t.get("name", "") or "traffico limitato" in t.get("name", "").lower() or t.get("highway") == "pedestrian"
for rid in [r for r, v in rels.items() if want(v["tags"])]:
    ingest(get(f"{API}/relation/{rid}/full")); time.sleep(1)
def geom(wid):
    return [{"lat": nodes[x]["lat"], "lon": nodes[x]["lon"]} for x in ways[wid]["nodes"] if x in nodes]
els = list(nodes.values())
for wd in ways.values():
    els.append({**wd, "geometry": geom(wd["id"])})
for r in rels.values():
    ms = []
    for m in r["members"]:
        mm = dict(m)
        if m["type"] == "way" and m["ref"] in ways: mm["geometry"] = geom(m["ref"])
        if m["type"] == "node" and m["ref"] in nodes: mm["lat"], mm["lon"] = nodes[m["ref"]]["lat"], nodes[m["ref"]]["lon"]
        ms.append(mm)
    els.append({**r, "members": ms})
json.dump({"generator": "osmapi.py da www.openstreetmap.org/api/0.6 (ODbL)", "bbox": [s, w, n, e], "fetched": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "elements": els}, open(out, "w"))
print(len(nodes), "nodi", len(ways), "way", len(rels), "relazioni")
for r in rels.values():
    if want(r["tags"]): print("REL", r["id"], r["tags"])
for x in nodes.values():
    t = x.get("tags", {})
    if t.get("man_made") == "surveillance" or "arco" in t.get("name", "") or t.get("barrier"):
        print("NODE", x["id"], x["lat"], x["lon"], t)
