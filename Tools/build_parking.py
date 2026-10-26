#!/usr/bin/env python3
# Costruisce Resources/Parking/<città>.json dai parcheggi di OpenStreetMap scaricati da Tools/fetch_parking.py
# (data/raw/geo/<città>-parking.json, nel ramo «geo-data»). Tiene solo i parcheggi aperti a tutti e facili da trovare,
# con le stesse regole dell'app (ParkingData.keep in Sources/ParkOutside.swift). Dati © OpenStreetMap contributors, ODbL.
# Uso: python3 Tools/build_parking.py [cartella dei grezzi]   (di serie data/raw/geo)
import json, sys, datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "data/raw/geo"
OUT = ROOT / "Resources/Parking"

CLOSED = {"private", "no", "customers", "residents", "delivery", "permit", "employees", "agricultural", "forestry", "military"}
STREET = {"street_side", "lane", "on_kerb", "half_on_kerb", "layby", "sheds", "carports", "garage_boxes", "garages"}


def capacity(tags):
    try:
        return int(str(tags.get("capacity", "")).strip())
    except ValueError:
        return None


def keep(tags):
    if tags.get("amenity", "parking") != "parking":
        return False
    if tags.get("access") in CLOSED or tags.get("parking") in STREET:
        return False
    cap = capacity(tags)
    if tags.get("name") or tags.get("name:it"):
        return True
    if tags.get("parking") in ("multi-storey", "underground", "rooftop"):
        return True
    if tags.get("park_ride", "no") != "no":
        return True
    return (cap or 0) >= 30 or ("fee" in tags and (cap if cap is not None else 30) >= 30)


def spot(e):
    tags = e.get("tags") or {}
    lat = e.get("lat", (e.get("center") or {}).get("lat"))
    lon = e.get("lon", (e.get("center") or {}).get("lon"))
    if lat is None or lon is None or not keep(tags):
        return None
    out = {"id": {"way": "w", "relation": "r"}.get(e["type"], "n") + str(e["id"]),
           "name": tags.get("name") or tags.get("name:it"), "lat": round(lat, 6), "lon": round(lon, 6),
           "kind": tags.get("parking"), "fee": tags.get("fee"), "charge": tags.get("charge"),
           "hours": tags.get("opening_hours"), "capacity": capacity(tags)}
    return {k: v for k, v in out.items() if v is not None}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    files = sorted(RAW.glob("*-parking.json"))
    if not files:
        raise SystemExit(f"nessun file *-parking.json in {RAW}: prima Tools/fetch_parking.py (GitHub, geo.yml)")
    for f in files:
        city = f.name[: -len("-parking.json")]
        if not (ROOT / "Resources/Cities" / f"{city}.json").exists():
            continue
        data = json.loads(f.read_text(encoding="utf-8"))
        spots, seen = [], set()
        for e in data.get("elements", []):
            s = spot(e)
            if s and s["id"] not in seen:
                seen.add(s["id"]); spots.append(s)
        spots.sort(key=lambda s: s["id"])
        if not spots:
            print("vuoto", city); continue
        stamp = (data.get("osm3s") or {}).get("timestamp_osm_base") or datetime.date.today().isoformat()
        doc = {"city": city, "generated": stamp, "license": "© OpenStreetMap contributors, ODbL 1.0", "spots": spots}
        (OUT / f"{city}.json").write_text(json.dumps(doc, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
        named = sum(1 for s in spots if "name" in s)
        hours = sum(1 for s in spots if "hours" in s)
        print(f"{city}: {len(spots)} parcheggi ({named} con nome, {hours} con orari)")


if __name__ == "__main__":
    main()
