#!/usr/bin/env python3
# Controlla gli script delle pagine costruite in web/ (dopo Tools/build_site.py): ogni <script> scritto nella pagina
# passa da `node --check`, ogni <script type="application/json"> o JSON-LD da json.loads. Un errore di sintassi
# (come le due parentesi di troppo dell'ottobre 2026) fermava tutta la pagina senza che nessuno se ne accorgesse:
# qui fa fallire la pubblicazione e la compilazione. Uso: python3 Tools/check_site_js.py   (serve node)
import json, re, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = re.compile(r"<script\b([^>]*)>(.*?)</script>", re.S | re.I)

pages = sorted(p for p in (ROOT / "web").rglob("*.html") if p.name != "template.html")
bad, checked = [], 0
with tempfile.TemporaryDirectory() as tmp:
    for page in pages:
        for i, m in enumerate(SCRIPT.finditer(page.read_text(encoding="utf-8"))):
            attrs, body = m.group(1), m.group(2)
            if re.search(r"\bsrc\s*=", attrs) or not body.strip():
                continue
            name = f"{page.relative_to(ROOT)} (script {i + 1})"
            kind = re.search(r'type\s*=\s*"([^"]+)"', attrs)
            kind = kind.group(1).lower() if kind else "text/javascript"
            checked += 1
            if "json" in kind:
                try:
                    json.loads(body)
                except ValueError as e:
                    bad.append(f"{name}: JSON non valido: {e}")
                continue
            if kind not in ("text/javascript", "module", "application/javascript"):
                checked -= 1
                continue
            f = Path(tmp) / ("s.mjs" if kind == "module" else "s.js")
            f.write_text(body, encoding="utf-8")
            r = subprocess.run(["node", "--check", str(f)], capture_output=True, text=True)
            if r.returncode != 0:
                err = r.stderr.splitlines()
                where = next((l.rsplit(":", 1)[-1] for l in err if l.startswith(str(f) + ":")), "?")
                what = next((l for l in err if "Error" in l and not l.lstrip().startswith("at ")), err[-1] if err else "")
                bad.append(f"{name}, riga {where}: {what[:300]}")

for b in bad:
    print(f"::error::{b}")
print(f"{len(pages)} pagine, {checked} script controllati, {len(bad)} con errori")
sys.exit(1 if bad or checked == 0 else 0)
