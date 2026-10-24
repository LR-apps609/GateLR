#!/usr/bin/env python3
# Controllo delle pagine dei Comuni: scarica le pagine citate nei file delle città, ne calcola
# un'impronta del testo e la confronta con data/source-hashes.json. Stampa le pagine cambiate.
# Uso: python3 Tools/check_sources.py [--update]
import hashlib, html, json, re, sys, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STORE = ROOT / "data/source-hashes.json"
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"


def pages():
    urls = set()
    for f in sorted((ROOT / "Resources/Cities").glob("*.json")):
        for z in json.loads(f.read_text())["zones"]:
            s = z["source"]
            urls.add(s["pageURL"])
            urls.update(l["url"] for l in s["links"] if "comune." in l["url"] and "opendata" not in l["url"] and "dati." not in l["url"])
    return sorted(urls)


def fingerprint(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        t = r.read().decode("utf-8", "ignore")
    t = re.sub(r"(?is)<(script|style|nav|header|footer)\b.*?</\1>", " ", t)
    t = html.unescape(re.sub(r"<[^>]+>", " ", t))
    t = re.sub(r"\s+", " ", t)
    # Le date di «ultimo aggiornamento» e i contatori cambiano senza che cambino le regole
    t = re.sub(r"(?i)ultimo aggiornamento:?\s*[\d/.-]+", "", t)
    if len(t) < 1500:
        raise ValueError("pagina disegnata dal browser, testo non leggibile")    # es. il sito del Comune di Bologna
    return hashlib.sha256(t.encode()).hexdigest()[:16]


def main():
    old = json.loads(STORE.read_text()) if STORE.exists() else {}
    new, changed, failed = {}, [], []
    for url in pages():
        try:
            new[url] = fingerprint(url)
        except Exception as e:
            failed.append(f"{url} ({e})")
            new[url] = old.get(url, "")
            continue
        if url in old and old[url] != new[url]:
            changed.append(url)
    # Stessa impronta per pagine diverse = il sito manda solo la cornice (contenuto caricato dal browser)
    seen = {}
    for u, h in new.items():
        seen.setdefault(h, []).append(u)
    for h, us in seen.items():
        if h and len(us) > 1:
            for u in us:
                failed.append(f"{u} (contenuto caricato dal browser, da controllare a mano)")
                new[u] = ""
                if u in changed:
                    changed.remove(u)
    for u in changed:
        print("CAMBIATA", u)
    for u in failed:
        print("NON LETTA", u)
    if "--update" in sys.argv or not old:
        STORE.parent.mkdir(parents=True, exist_ok=True)
        STORE.write_text(json.dumps(new, indent=1, sort_keys=True) + "\n")
    print(f"{len(new)} pagine, {len(changed)} cambiate, {len(failed)} non lette", file=sys.stderr)


if __name__ == "__main__":
    main()
