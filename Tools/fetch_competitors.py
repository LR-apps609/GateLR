"""Scarica dalle schede dell'App Store le foto e la descrizione delle app concorrenti (solo per confronto interno).
Gira su GitHub Actions (workflow «Concorrenti»): dall'ambiente di lavoro l'App Store non si raggiunge."""
import json, pathlib, urllib.request

APPS = {"zigzag": "6738909628", "ztl": "926415425"}
out = pathlib.Path("out"); out.mkdir(exist_ok=True)

def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    return urllib.request.urlopen(req, timeout=60).read()

for name, id in APPS.items():
    d = out / name; d.mkdir(exist_ok=True)
    for country in ("it", "us"):
        try:
            data = json.loads(get(f"https://itunes.apple.com/lookup?id={id}&country={country}&entity=software"))
        except Exception as e:
            print("FAILED", name, country, e); continue
        if not data.get("results"): continue
        r = data["results"][0]
        (d / f"scheda-{country}.json").write_text(json.dumps(r, ensure_ascii=False, indent=1))
        if country == "it":
            for kind in ("screenshotUrls", "ipadScreenshotUrls"):
                for i, u in enumerate(r.get(kind, [])):
                    (d / f"{kind[:4]}-{i+1:02}.jpg").write_bytes(get(u))
        print("ok", name, country, r.get("version"), len(r.get("screenshotUrls", [])))
