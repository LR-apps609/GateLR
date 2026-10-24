# Varianti dell'icona per iOS 18 dal disegno principale (Resources/Branding/gatelr-icon.svg → AppIcon.png):
# «scura» uguale (il logo è già su fondo blu notte) e «tinta» in scala di grigi (la colora il sistema). Richiede Pillow.
# Prima: node Tools/render_icon.cjs
from PIL import Image, ImageOps

base = Image.open("Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png").convert("RGB")
base.save("Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-dark.png")
ImageOps.grayscale(base).convert("RGB").save("Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-tinted.png")
print("icone pronte")
