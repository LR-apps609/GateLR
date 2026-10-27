#!/usr/bin/env python3
# Scrive Resources/Cities/manifest.json: l'elenco delle città con la versione dei dati.
# L'app lo scarica da GitHub e, se la versione è più nuova di quella che ha, scarica le città aggiornate.
#
# Le città con almeno una zona da fonti non ufficiali («source": {"official": false}) vanno in «unofficialCities»,
# non in «cities»: le app fino alla 1.16.1 leggono solo «cities», scaricano solo quelle, cancellano le città scaricate
# prima e non conoscono l'avviso «Fonte non ufficiale», quindi non devono mai vederle. Dalla 1.16.2 l'app legge
# entrambe le liste (CityLoader.Manifest.allCities) e mostra l'avviso. «schema» resta 1, se no le app vecchie
# smetterebbero di aggiornare anche le città ufficiali.
# Uso: python3 Tools/build_manifest.py   (dopo build_firenze.py / build_cities.py)
import hashlib, json, datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DIR = ROOT / "Resources/Cities"


def unofficial(city):
    """Vero se almeno una zona ha regole solo da fonti non ufficiali (official assente = ufficiale)"""
    return any(z.get("source", {}).get("official", True) is False for z in city.get("zones", []))


official_list, unofficial_list = [], []
for f in sorted(DIR.glob("*.json")):
    if f.name == "manifest.json":
        continue
    data = f.read_bytes()
    city = json.loads(data)
    entry = {"id": city["id"], "file": f.name, "sha256": hashlib.sha256(data).hexdigest()}
    (unofficial_list if unofficial(city) else official_list).append(entry)
everything = sorted(official_list + unofficial_list, key=lambda c: c["file"])
digest = hashlib.sha256("".join(c["sha256"] for c in everything).encode()).hexdigest()[:12]
old = json.loads((DIR / "manifest.json").read_text()) if (DIR / "manifest.json").exists() else {}
version = old.get("version") if old.get("digest") == digest else datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%d%H%M")
manifest = {"version": version, "digest": digest, "schema": 1, "cities": official_list}
if unofficial_list:
    manifest["unofficialCities"] = unofficial_list      # solo dalla 1.16.2 in poi
(DIR / "manifest.json").write_text(json.dumps(manifest, indent=1) + "\n")
print("manifest", version, len(official_list), "città ufficiali,", len(unofficial_list), "con fonti non ufficiali")
