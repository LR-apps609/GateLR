#!/usr/bin/env python3
# Scrive Resources/Cities/manifest.json: l'elenco delle città con la versione dei dati.
# L'app lo scarica da GitHub e, se la versione è più nuova di quella che ha, scarica le città aggiornate.
# Uso: python3 Tools/build_manifest.py   (dopo build_firenze.py / build_cities.py)
import hashlib, json, datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DIR = ROOT / "Resources/Cities"
cities = []
for f in sorted(DIR.glob("*.json")):
    if f.name == "manifest.json":
        continue
    data = f.read_bytes()
    cities.append({"id": json.loads(data)["id"], "file": f.name, "sha256": hashlib.sha256(data).hexdigest()})
digest = hashlib.sha256("".join(c["sha256"] for c in cities).encode()).hexdigest()[:12]
old = json.loads((DIR / "manifest.json").read_text()) if (DIR / "manifest.json").exists() else {}
version = old.get("version") if old.get("digest") == digest else datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%d%H%M")
(DIR / "manifest.json").write_text(json.dumps({"version": version, "digest": digest, "schema": 1, "cities": cities}, indent=1) + "\n")
print("manifest", version, len(cities), "città")
