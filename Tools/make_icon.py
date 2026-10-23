# Disegna l'icona dell'app (1024 px): cartello ZTL con la porta, sul tricolore. Richiede Pillow.
from PIL import Image, ImageDraw

S = 1024
u = S / 100
img = Image.new("RGB", (S, S), "#ffffff")
d = ImageDraw.Draw(img)
d.rectangle([0, 0, 34 * u, S], fill="#1f9d55")
d.rectangle([66 * u, 0, S, S], fill="#d32f2f")
d.ellipse([12 * u, 12 * u, 88 * u, 88 * u], fill="#ffffff")
d.ellipse([15 * u, 15 * u, 85 * u, 85 * u], outline="#d32f2f", width=int(8 * u))
w = int(7 * u)
d.arc([38 * u, 40 * u, 62 * u, 64 * u], 180, 360, fill="#1b2128", width=w)
d.line([38 * u + w / 2, 52 * u, 38 * u + w / 2, 70 * u], fill="#1b2128", width=w)
d.line([62 * u - w / 2, 52 * u, 62 * u - w / 2, 70 * u], fill="#1b2128", width=w)
d.polygon([(45 * u, 72 * u), (55 * u, 72 * u), (52 * u, 56 * u), (48 * u, 56 * u)], fill="#1b2128")
img.save("Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
