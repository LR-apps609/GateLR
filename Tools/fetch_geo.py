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
       "roma": (41.86, 12.44, 41.92, 12.53), "lucca": (43.835, 10.49, 43.85, 10.515),
       "napoli": (40.82, 14.20, 40.87, 14.29), "verona": (45.425, 10.97, 45.455, 11.02), "torino": (45.04, 7.64, 45.10, 7.72),
       "padova": (45.38, 11.85, 45.425, 11.90), "bergamo": (45.68, 9.64, 45.715, 9.69)}

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

# Roma: i layer ufficiali di RSM trovati sull'hub (vedi docs/fonti-roma.md), in GeoJSON WGS84, un file per layer
RSM = "https://services2.arcgis.com/NZMqCJwY3kMjFOqf/arcgis/rest/services/{}/FeatureServer"
for svc in ["confini_ZTL_centro_diurna", "settori_ZTL_centro", "varchi_ZTL_centro_diurna", "ZTL_Centro_notturna",
            "ZTL_Tridente", "ZTL_Trastevere", "San_Lorenzo", "Testaccio", "ZTL_Fascia_Verde"]:
    meta = get(RSM.format(svc) + "?f=json", tries=2)
    layers = [l["id"] for l in json.loads(meta).get("layers", [])] if meta else []
    for lid in layers:
        raw = get(RSM.format(svc) + f"/{lid}/query?" + urllib.parse.urlencode({"where": "1=1", "outFields": "*", "outSR": 4326, "f": "geojson"}), tries=2)
        if raw: (OUT / f"roma-rsm-{svc}-{lid}.geojson").write_bytes(raw); print("ok rsm", svc, lid, len(raw))
        else: print("FAILED rsm", svc, lid)
    if not layers: print("FAILED rsm", svc)

# Firenze, Scudo Verde (vedi docs/fonti-scudo-verde.md): la relazione OSM usata dall'app, per vedere se cambia,
# e l'area ufficiale del PUMS della Città Metropolitana (CC BY 4.0), che da qui non si raggiunge
overpass("firenze-scudo-verde-osm", "[out:json][timeout:120];relation(19205738);out geom;")
PUMS = "http://pubblicazioni.cittametropolitana.fi.it/geoserver/pian_pums_2021"
caps = get(PUMS + "/wfs?service=WFS&version=2.0.0&request=GetCapabilities", tries=2)
if caps: (OUT / "firenze-scudo-verde-pums-wfs-caps.xml").write_bytes(caps); print("ok pums caps", len(caps))
for name in ["pian_pums_2021:pums_progetto_scudo-verde_area", "pums_progetto_scudo-verde_area"]:
    raw = get(PUMS + "/wfs?" + urllib.parse.urlencode({"service": "WFS", "version": "2.0.0", "request": "GetFeature", "typeNames": name,
                                                        "outputFormat": "application/json", "srsName": "EPSG:4326"}), tries=2)
    if raw and raw.lstrip().startswith(b"{"):
        (OUT / "firenze-scudo-verde-pums.geojson").write_bytes(raw); print("ok pums", name, len(raw)); break
else:
    print("FAILED pums scudo verde")

print("files:", sorted(p.name for p in OUT.iterdir()))

# --- Bergamo (sessione Bergamo, vedi docs/fonti-bergamo.md) ---
# Dati aperti ufficiali del Comune di Bergamo su dati.lombardia.it (pubblico dominio), che da qui non si raggiungono:
# «Mappa Zone a Traffico Limitato» (jhcz-yki3, perimetri) e «Zone a Traffico Limitato» (tkwz-spd9, tabella con geometrie)
for ds in ["jhcz-yki3", "tkwz-spd9"]:
    meta = get(f"https://www.dati.lombardia.it/api/views/{ds}.json", tries=3)
    if meta: (OUT / f"bergamo-od-{ds}-meta.json").write_bytes(meta); print("ok bergamo meta", ds, len(meta))
    raw = get(f"https://www.dati.lombardia.it/api/geospatial/{ds}?method=export&format=GeoJSON", tries=3)
    if not raw or not raw.lstrip().startswith(b"{"):
        raw = get(f"https://www.dati.lombardia.it/resource/{ds}.geojson?$limit=5000", tries=3)
    if raw and raw.lstrip().startswith(b"{"): (OUT / f"bergamo-od-{ds}.geojson").write_bytes(raw); print("ok bergamo od", ds, len(raw))
    else: print("FAILED bergamo od", ds)
    csv = get(f"https://www.dati.lombardia.it/api/views/{ds}/rows.csv?accessType=DOWNLOAD", tries=2)
    if csv: (OUT / f"bergamo-od-{ds}.csv").write_bytes(csv); print("ok bergamo csv", ds, len(csv))
# --- fine Bergamo ---
