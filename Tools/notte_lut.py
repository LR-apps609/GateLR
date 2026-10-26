#!/usr/bin/env python3
# La tabella dei colori (LUT) che porta lo stile Mapbox Standard nei colori «Notte» di GateLR: ogni colore della mappa
# diventa un blu notte della stessa luminosità (scuro → #0B1530, chiaro → gesso #F2F4FA); i rossi e i verdi accesi restano
# com'erano. Mapbox la vuole come PNG 1024×32 (32 fette 32×32, blu = fetta, rosso = x, verde = y) in base64.
# Scrive Sources/Mapbox/NotteLUT.swift. Uso: python3 Tools/notte_lut.py
import base64, colorsys, io
from pathlib import Path
import numpy as np
from PIL import Image

N = 32
RAMP = [(0, "#050A1A"), (0.15, "#0B1530"), (0.3, "#131E44"), (0.5, "#22315A"), (0.68, "#4E5E90"), (0.85, "#A9B3D1"), (1, "#F2F4FA")]

def rgb(h):
    return np.array([int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)])

xs = [x for x, _ in RAMP]
cs = np.array([rgb(c) for _, c in RAMP])
img = np.zeros((N, N * N, 3))
for b in range(N):
    for g in range(N):
        for r in range(N):
            c = np.array([r, g, b]) / (N - 1)
            y = 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
            out = np.array([np.interp(y, xs, cs[:, k]) for k in range(3)])
            h, l, s = colorsys.rgb_to_hls(*c)
            chroma = s * (1 - abs(2 * l - 1))
            hue = h * 360
            red = max(0, 1 - min(abs(hue - 5), abs(hue - 365)) / 30)
            green = max(0, 1 - abs(hue - 140) / 35)
            keep = min(1, max(0, (chroma - 0.25) / 0.35)) * max(red, green)
            img[g, b * N + r] = out * (1 - keep) + c * keep

buf = io.BytesIO()
Image.fromarray((img * 255 + 0.5).clip(0, 255).astype("uint8")).save(buf, "PNG", optimize=True)
data = base64.b64encode(buf.getvalue()).decode()
root = Path(__file__).resolve().parent.parent
out = root / "Sources/Mapbox/NotteLUT.swift"
out.parent.mkdir(parents=True, exist_ok=True)
lines = [data[i:i + 120] for i in range(0, len(data), 120)]
out.write_text(
    "// Generato da Tools/notte_lut.py: la tabella dei colori «Notte» per lo stile Mapbox Standard (PNG 1024×32 in base64)\n"
    "enum NotteLUT {\n    static let base64 = \"\"\"\n" + "\n".join(lines) + "\n\"\"\".filter { !$0.isNewline }\n}\n",
    encoding="utf-8")
print(out.relative_to(root), len(data), "caratteri")
