#!/usr/bin/env python3
# Trova i testi dell'app che non hanno traduzione in Tools/translations.py.
# Uso: python3 Tools/check_strings.py
import re, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "Tools"))
src = (ROOT / "Tools/translations.py").read_text()
T = {}
exec(src.split("def esc")[0], {}, T)
keys = set(T["T"])

# Testi passati a viste che li traducono da sole (LocalizedStringKey) o a L()
CALLS = r'(?:\bL|Text|Label|Button|Toggle|Section|navigationTitle|SectionLabel|WideButton\(title:|TextField|Picker|LabeledContent|Stepper|DatePicker|Link|ShareLink|chip|lesson|hint|legendItem|configurationDisplayName|description|IntentDescription|Parameter\(title:|title:)'
lit = re.compile(CALLS + r'\(?\s*"((?:[^"\\]|\\.)*)"')
tern = re.compile(r'\?\s*"((?:[^"\\]|\\.)+)"\s*:\s*"((?:[^"\\]|\\.)+)"')
skip = re.compile(r'^[\W\d_]*$|^(GateLR|ZTL|VARCO|ATTIVO|NON ATTIVO|ZONA|TRAFFICO|LIMITATO|Euro|PDF|EN|IT|DE)$')

def norm(s):
    # interpolazioni Swift → formati di NSLocalizedString
    s = re.sub(r'\\\((?:Int|[^()]*count|[a-z.]*euro)[^)]*\)', '%lld', s)
    s = re.sub(r'\\\([^)]*(\([^)]*\))?[^)]*\)', '%@', s)
    return s.replace('\\"', '"')

missing = {}
for f in sorted((ROOT / "Sources").rglob("*.swift")) + sorted((ROOT / "Widget").glob("*.swift")):
    if f.name in ("SampleData.swift",):
        continue
    for n, line in enumerate(f.read_text().splitlines(), 1):
        if line.strip().startswith("//") or "accessibilityIdentifier" in line or "forResource" in line or "systemName:" in line and not re.search(CALLS + r'\(\s*"', line):
            pass
        found = [m.group(1) for m in lit.finditer(line)] + [g for m in tern.finditer(line) for g in m.groups()]
        for s in found:
            k = norm(s)
            if skip.match(k) or k in keys or k.startswith(("gatelr:", "http", "mailto")) or len(k) < 2:
                continue
            missing.setdefault(k, f"{f.name}:{n}")
for k, w in sorted(missing.items(), key=lambda x: x[1]):
    print(f"{w}\t{k}")
print(len(missing), "da tradurre", file=sys.stderr)
