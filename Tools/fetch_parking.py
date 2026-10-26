#!/usr/bin/env python3
# Scarica da OpenStreetMap (Overpass, ODbL) i parcheggi intorno alle ZTL di ogni città: amenity=parking con nome,
# tariffa (fee, charge), orari (opening_hours), posti (capacity) e tipo (multi-storey, underground, surface).
# Da qui Overpass non si raggiunge: gira su GitHub Actions (geo.yml, script=Tools/fetch_parking.py) e salva
# data/raw/geo/<città>-parking.json nel ramo «geo-data». Poi: python3 Tools/build_parking.py <cartella dei grezzi>
# Uso: python3 Tools/fetch_parking.py [città ...]
import json, sys, time, urllib.parse, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "data/raw/geo"
OUT.mkdir(parents=True, exist_ok=True)
UA = {"User-Agent": "GateLR/1.15 (ZTL checker; parking outside the ZTL; github.com/LR-apps609/GateLR)"}
HOSTS = ["https://overpass-api.de/api/interpreter", "https://overpass.kumi.systems/api/interpreter",
         "https://maps.mail.ru/osm/tools/overpass/api/interpreter", "https://overpass.private.coffee/api/interpreter"]
MARGIN_M = 2_500          # quanto fuori dal rettangolo delle ZTL si cercano i parcheggi


def box(city):
    """Il rettangolo delle zone vietate o a pagamento (le verdi, grandi come la città, solo se non c'è altro), più il margine"""
    zones = [z for z in city["zones"] if z.get("perimeter")]
    strict = [z for z in zones if (z.get("kind") or "restricted") != "green"] or zones
    lats = [p["lat"] for z in strict for p in z["perimeter"]]
    lons = [p["lon"] for z in strict for p in z["perimeter"]]
    import math
    dlat = MARGIN_M / 111_000
    dlon = MARGIN_M / (111_000 * math.cos(math.radians(sum(lats) / len(lats))))
    return min(lats) - dlat, min(lons) - dlon, max(lats) + dlat, max(lons) + dlon


def overpass(query):
    body = urllib.parse.urlencode({"data": query}).encode()
    for host in HOSTS:
        for i in range(2):
            try:
                req = urllib.request.Request(host, data=body, headers=UA)
                with urllib.request.urlopen(req, timeout=240) as r:
                    raw = r.read()
                if raw.lstrip().startswith(b"{"):
                    return raw, host
            except Exception as e:
                print("  retry", host, e)
            time.sleep(10 * (i + 1))
    return None, None


def main(only):
    for f in sorted((ROOT / "Resources/Cities").glob("*.json")):
        if f.name == "manifest.json":
            continue
        city = json.loads(f.read_text())
        if only and city["id"] not in only:
            continue
        s, w, n, e = box(city)
        bb = f"{s:.5f},{w:.5f},{n:.5f},{e:.5f}"
        q = f'[out:json][timeout:180];( nwr["amenity"="parking"]({bb}); );out center tags;'
        raw, host = overpass(q)
        if raw:
            (OUT / f"{city['id']}-parking.json").write_bytes(raw)
            print("ok", city["id"], len(raw), host)
        else:
            print("FAILED", city["id"])
        time.sleep(5)          # gentile con i server di Overpass


if __name__ == "__main__":
    main(set(sys.argv[1:]))
