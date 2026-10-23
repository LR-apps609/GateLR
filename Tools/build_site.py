#!/usr/bin/env python3
# Costruisce web/index.html dal modello web/template.html, con dentro i dati delle città e le multe.
# Uso: python3 Tools/build_site.py
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FINE_FILE = ROOT / "Resources/Rules/fine.json"          # importi verificati, con fonte (se manca: «in verifica»)

cities = [json.loads(f.read_text(encoding="utf-8")) for f in sorted((ROOT / "Resources/Cities").glob("*.json"))]
fine = json.loads(FINE_FILE.read_text(encoding="utf-8")) if FINE_FILE.exists() else None
html = (ROOT / "web/template.html").read_text(encoding="utf-8")
html = html.replace("/*CITIES*/", json.dumps(cities, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/"))
html = html.replace("/*FINE*/null", json.dumps(fine, ensure_ascii=False) if fine else "null")
(ROOT / "web/index.html").write_text(html, encoding="utf-8")
print("web/index.html", len(html), "byte ·", len(cities), "città · multe:", "sì" if fine else "in verifica")
