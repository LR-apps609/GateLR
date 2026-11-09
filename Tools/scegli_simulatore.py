#!/usr/bin/env python3
"""Sceglie un simulatore per il workflow «dispositivi.yml».

Uso: xcrun simctl list devices available -j | python3 Tools/scegli_simulatore.py <tipo>
con <tipo> = piccolo | medio | grande | ipad. Scrive «UDID<TAB>nome<TAB>iOS».

Prima la lista dei nomi, nell'ordine, in ogni runtime (il più recente prima); se nessuno c'è si cade sul più vicino con un'espressione regolare (per esempio qualunque «Pro Max» per il grande).
"""
import json
import re
import sys

PREFERENZE = {
    # Il più piccolo: l'SE da 4,7" se c'è, poi i mini, poi l'iPhone «e» o il più piccolo base
    "piccolo": (["iPhone SE (3rd generation)", "iPhone SE (2nd generation)", "iPhone 13 mini", "iPhone 12 mini",
                 "iPhone 16e", "iPhone 17e"],
                [r"^iPhone SE", r"mini$", r"^iPhone \d+e$", r"^iPhone \d+$"]),
    "medio": (["iPhone 17", "iPhone 16", "iPhone 15"], [r"^iPhone \d+$", r"^iPhone \d+ Pro$"]),
    "grande": (["iPhone 17 Pro Max", "iPhone 16 Pro Max", "iPhone 15 Pro Max"], [r"Pro Max$", r"Plus$", r"^iPhone Air$"]),
    "ipad": (["iPad (A16)", "iPad (10th generation)", "iPad Air 11-inch (M3)", "iPad Air 11-inch (M2)"],
             [r"^iPad \(", r"^iPad Air", r"^iPad Pro", r"^iPad"]),
}


def version(runtime: str) -> tuple:
    m = re.search(r"iOS-(\d+)-(\d+)(?:-(\d+))?", runtime)
    return tuple(int(x or 0) for x in m.groups()) if m else (0,)


def main() -> int:
    tipo = sys.argv[1]
    names, patterns = PREFERENZE[tipo]
    data = json.load(sys.stdin)["devices"]
    runtimes = sorted((r for r in data if "iOS" in r), key=version, reverse=True)
    avail = {r: [d for d in data[r] if d.get("isAvailable", True)] for r in runtimes}

    def show(runtime, d):
        ios = ".".join(str(x) for x in version(runtime))
        print(f"{d['udid']}\t{d['name']}\t{ios}")
        return 0

    # Prima i nomi preferiti, nell'ordine, in qualunque runtime (il più recente prima): l'SE resta il piccolo anche se
    # c'è solo con un iOS più vecchio
    for n in names:
        for runtime in runtimes:
            d = next((d for d in avail[runtime] if d["name"] == n), None)
            if d:
                return show(runtime, d)
    # Poi il più vicino, nel runtime più recente
    for p in patterns:
        for runtime in runtimes:
            d = next((d for d in avail[runtime] if re.search(p, d["name"])), None)
            if d:
                return show(runtime, d)
    print(f"nessun simulatore per «{tipo}»", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
