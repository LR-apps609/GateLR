#!/usr/bin/env python3
# Controlla le traduzioni generate in Resources/Localizations: per ogni lingua le stesse chiavi di Tools/translations.py,
# gli stessi segnaposto (%@, %lld, %1$@…, %%) dello stesso tipo e nello stesso ordine, le stesse «|» (a capo),
# InfoPlist.strings e AppShortcuts.strings completi con ${applicationName}. Uso: python3 Tools/check_translations.py
import re, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
LOC = ROOT / "Resources/Localizations"
src = (ROOT / "Tools/translations.py").read_text()
ns = {}
exec(src.split("def esc")[0], {}, ns)
KEYS = list(ns["T"])
INFO_KEYS = ["NSLocationWhenInUseUsageDescription", "NSLocationAlwaysAndWhenInUseUsageDescription", "NSCameraUsageDescription"]
# Le frasi di tutte le AppShortcut: «\(.applicationName)» → ${applicationName}, «\(\.$zone)» → ${zone}
SHORTCUT_KEYS = [re.sub(r"\\\(\\\.\$(\w+)\)", r"${\1}", m.group(1).replace("\\(.applicationName)", "${applicationName}"))
                 for block in re.finditer(r"phrases:\s*\[(.*?)\]", (ROOT / "Sources/NearbyZTLIntent.swift").read_text(), re.S)
                 for m in re.finditer(r'"((?:[^"\\]|\\.)*)"', block.group(1))]
PARAM = re.compile(r"\$\{(\w+)\}")
LANGS = ["it", "de", "fr", "es", "nl", "pl", "zh-Hans"]
LINE = re.compile(r'^"((?:[^"\\]|\\.)*)" = "((?:[^"\\]|\\.)*)";$')
SPEC = re.compile(r"%(?:(\d+)\$)?(lld|ld|d|@|%)")

def parse(path):
    out, bad = {}, []
    for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip() or line.startswith("/*"):
            continue
        m = LINE.match(line)
        if not m:
            bad.append(f"{path.relative_to(ROOT)}:{n}: riga non valida")
            continue
        k = m.group(1)
        if k in out:
            bad.append(f"{path.relative_to(ROOT)}:{n}: chiave doppia")
        out[k] = m.group(2)
    return out, bad

def unesc(s):
    return s.replace('\\"', '"').replace("\\n", "\n").replace("\\\\", "\\")

def specs(s):
    """I segnaposto come lista di tipi nell'ordine degli argomenti (%2$@ conta come secondo), più quanti %% letterali"""
    pos, pct, n = {}, 0, 0
    for m in SPEC.finditer(s):
        if m.group(2) == "%":
            pct += 1
            continue
        n += 1
        pos[int(m.group(1)) if m.group(1) else n] = "int" if m.group(2) in ("lld", "ld", "d") else "obj"
    return [pos[i] for i in sorted(pos)], pct

errors = []
for code in LANGS:
    d = LOC / f"{code}.lproj"
    strings, bad = parse(d / "Localizable.strings")
    errors += bad
    keys = {unesc(k): unesc(v) for k, v in strings.items()}
    for k in KEYS:
        if k not in keys:
            errors.append(f"{code}: manca «{k}»")
            continue
        v = keys[k]
        if not v.strip():
            errors.append(f"{code}: vuota «{k}»")
        if specs(k) != specs(v):
            errors.append(f"{code}: segnaposto diversi in «{k}» → «{v}»")
        if k.count("|") != v.count("|"):
            errors.append(f"{code}: «|» diverse in «{k}»")
    for k in keys:
        if k not in KEYS:
            errors.append(f"{code}: chiave in più «{k}»")
    info, bad = parse(d / "InfoPlist.strings")
    errors += bad
    for k in INFO_KEYS:
        if not info.get(k, "").strip():
            errors.append(f"{code}: InfoPlist senza {k}")
    sc, bad = parse(d / "AppShortcuts.strings")
    errors += bad
    for k in SHORTCUT_KEYS:
        v = sc.get(k)
        if v is None:
            errors.append(f"{code}: AppShortcuts senza «{k}»")
        elif v.count("${applicationName}") != 1:
            errors.append(f"{code}: AppShortcuts «{k}» senza ${{applicationName}}")
        elif sorted(PARAM.findall(v)) != sorted(PARAM.findall(k)):
            errors.append(f"{code}: AppShortcuts «{k}» con parametri diversi → «{v}»")
    for k in sc:
        if k not in SHORTCUT_KEYS:
            errors.append(f"{code}: AppShortcuts in più «{k}»")

for e in errors:
    print(e)
print(f"{len(LANGS)} lingue, {len(KEYS)} testi: " + ("tutto a posto" if not errors else f"{len(errors)} errori"), file=sys.stderr)
sys.exit(1 if errors else 0)
