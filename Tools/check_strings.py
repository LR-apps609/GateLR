#!/usr/bin/env python3
# Trova i testi dell'app che non hanno traduzione in Tools/translations.py.
# Uso: python3 Tools/check_strings.py   (esce con 1 se ne trova: la CI «Compila GateLR» si ferma)
# 1.20.3: niente falsi positivi. Non sono testi da tradurre: i nomi dei simboli SF («checkmark», «bus.fill»: argomenti di
# systemName:/systemImage:/Image(), anche nei «? :»), i nomi dei caratteri («TitilliumWeb-Bold»), i testi «verbatim:»
# (scritti apposta così, es. il pannello «ZTL ATTIVA» in italiano come sulla strada), le sigle («LEZ») e i testi fatti
# solo di segnaposto e punteggiatura («\(a) – \(b)»).
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
# Sigle, marchi e parole dei cartelli (uguali in ogni lingua)
skip = re.compile(r'^[\W\d_]*$|^(GateLR|GateLR Plus|ZTL|LEZ|VARCO|ATTIVO|NON ATTIVO|ATTIVA|NON ATTIVA|ZONA|TRAFFICO|LIMITATO|Euro|PDF|EN|IT|DE)$')
# Un nome di simbolo SF: parole minuscole separate da punti («map.legend.info», «speaker.wave.2.fill»); una parola sola
# («checkmark») solo sulle righe con systemName/systemImage/symbol/Image(, così «now» resta da tradurre
SYMBOL = re.compile(r'^[a-z][a-z0-9]*(\.[a-z0-9]+)*$')
# Un nome di carattere: «TitilliumWeb-Bold», «AtkinsonHyperlegibleNext-Regular»
FONT = re.compile(r'^[A-Z][A-Za-z]+-[A-Z][A-Za-z]+$')
# Gli argomenti che non sono testo: si tolgono dalla riga prima di cercare (anche con un «? :» dentro)
NOT_TEXT = re.compile(r'(?:systemName|systemImage|verbatim|forResource|withExtension|named|accessibilityIdentifier\(|subdirectory)\s*:?\s*'
                      r'(?:"(?:[^"\\]|\\.)*"|[^,()"]*\?\s*"(?:[^"\\]|\\.)*"\s*:\s*"(?:[^"\\]|\\.)*")')
FONT_CALL = re.compile(r'(?:Font\.custom|\.custom|UIFont\(name:)\s*\(?\s*"(?:[^"\\]|\\.)*"')


def interpolations(s):
    """Le interpolazioni Swift «\\(…)» con le parentesi annidate → %lld (numeri) o %@, come i formati di NSLocalizedString"""
    out, i = [], 0
    while i < len(s):
        if s.startswith("\\(", i):
            depth, j = 1, i + 2
            while j < len(s) and depth:
                depth += {"(": 1, ")": -1}.get(s[j], 0)
                j += 1
            inner = s[i + 2:j - 1]
            out.append("%lld" if re.match(r'(?:Int\b|[^()]*count\b|[a-z.]*euro\b)', inner) else "%@")
            i = j
        else:
            out.append(s[i])
            i += 1
    return "".join(out)


def norm(s):
    return interpolations(s).replace('\\"', '"')


def is_text(k):
    bare = re.sub(r'%(?:lld|@)', '', k)
    return not (skip.match(k) or skip.match(bare) or FONT.match(k) or k in keys
                or k.startswith(("gatelr:", "http", "mailto")) or len(k) < 2)


missing = {}
for f in sorted((ROOT / "Sources").rglob("*.swift")) + sorted((ROOT / "Widget").glob("*.swift")):
    if f.name in ("SampleData.swift",):
        continue
    for n, line in enumerate(f.read_text().splitlines(), 1):
        if line.strip().startswith("//"):
            continue
        code = FONT_CALL.sub("", NOT_TEXT.sub("", line))
        found = [m.group(1) for m in lit.finditer(code)] + [g for m in tern.finditer(code) for g in m.groups()]
        symbols = re.search(r'systemName|systemImage|symbol|Image\(', line) is not None
        for s in found:
            k = norm(s)
            if SYMBOL.match(k) and ("." in k or symbols):
                continue
            if is_text(k):
                missing.setdefault(k, f"{f.relative_to(ROOT)}:{n}")
for k, w in sorted(missing.items(), key=lambda x: x[1]):
    print(f"{w}\t{k}")
print(len(missing), "da tradurre", file=sys.stderr)
sys.exit(1 if missing else 0)
