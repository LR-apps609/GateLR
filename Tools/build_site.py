#!/usr/bin/env python3
# Costruisce web/index.html dal modello web/template.html, con dentro i dati delle città e le multe.
# Uso: python3 Tools/build_site.py
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FINE_FILE = ROOT / "web/fine.json"          # importi verificati, con fonte (se manca: «in verifica»)

city = json.loads((ROOT / "Resources/Cities/firenze.json").read_text(encoding="utf-8"))
fine = json.loads(FINE_FILE.read_text(encoding="utf-8")) if FINE_FILE.exists() else None
html = (ROOT / "web/template.html").read_text(encoding="utf-8")
html = html.replace("/*CITY*/", json.dumps(city, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/"))
html = html.replace("/*FINE*/null", json.dumps(fine, ensure_ascii=False) if fine else "null")
(ROOT / "web/index.html").write_text(html, encoding="utf-8")
print("web/index.html", len(html), "byte", "· multe:", "sì" if fine else "in verifica")
