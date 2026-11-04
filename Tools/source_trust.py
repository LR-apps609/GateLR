#!/usr/bin/env python3
# 1.20.1 «Dati»: «letto il» e «verificato il» delle zone, e la pagina del Comune cambiata dopo la verifica.
#
# Nei file delle città (Resources/Cities/<città>.json), per ogni zona, in «source»:
# - checkedOn            «letto il»: quando abbiamo letto le pagine da cui vengono le regole (c'era già)
# - verifiedOn           «verificato il»: quando una persona (o un controllo) ha confermato la regola. Assente = non lo
#                        sappiamo = NON verificata. Non si inventa: la scrive solo «verify» qui sotto, dopo una verifica vera
# - verifiedFingerprints le impronte delle pagine ufficiali della zona (Tools/check_sources.py, data/source-hashes.json)
#                        nel momento della verifica
# - readFingerprints     le impronte delle stesse pagine al momento della lettura («letto il» = checkedOn), con
#   readFingerprintsOf   il checkedOn a cui si riferiscono. Le scrive «mark» dalla storia di data/source-hashes.json (git):
#                        la prima impronta registrata dal controllo giornaliero a partire dal giorno della lettura (la
#                        storia comincia il 24 ottobre 2026: per le letture del 23 vale quella del 24). Niente di inventato
# - pageChanged          true se l'impronta di oggi di una pagina è diversa da quella dell'ultimo evento (la verifica se è
#                        più recente della lettura, altrimenti la lettura). La scrive «mark» ogni mattina («Controllo
#                        pagine dei Comuni»); mai a mano. Un'impronta vuota (pagina non leggibile) non conta come cambiata
#
# Regola A (1.20.1, decisa da Ledion): una zona UFFICIALE dà la risposta normale (anche verde) se è verificata da al più
# 120 giorni, oppure, senza verifica recente, se è stata letta da al più 120 giorni; in tutti e due i casi senza la pagina
# cambiata. Altrimenti giallo con il «?» («Controlla il cartello»); con la pagina cambiata TUTTE le risposte della zona
# sono gialle («La pagina del Comune è cambiata: controlla il cartello»). 120 = VERIFIED_FRESH_DAYS, lo stesso numero di
# RuleEngine.staleAfterDays su iPhone e Android e del sito. Vedi docs/dati-verifica.md.
#
# Uso:
#   python3 Tools/source_trust.py mark                     # pageChanged dalle impronte di data/source-hashes.json
#   python3 Tools/source_trust.py verify <città> [zona…]   # dopo una verifica umana: verifiedOn = adesso + impronte di adesso
#   python3 Tools/source_trust.py --selftest
# Dopo «mark» o «verify», se i file sono cambiati: python3 Tools/build_manifest.py (e la firma, in CI)
import datetime, json, subprocess, sys, tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_sources import zone_pages  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
CITIES = ROOT / "Resources/Cities"
HASHES = ROOT / "data/source-hashes.json"
VERIFIED_FRESH_DAYS = 120


def dump(city):
    # Lo stesso formato degli script che costruiscono le città (indent 1, UTF-8): niente differenze inutili nei file
    return json.dumps(city, indent=1, ensure_ascii=False) + "\n"


def when(iso):
    return datetime.datetime.fromisoformat(iso.replace("Z", "+00:00"))


def history(hashes_path=HASHES):
    """Le impronte registrate nel tempo: [(quando, {url: impronta})], dalla più vecchia; in fondo il file di adesso"""
    out = []
    try:
        rel = hashes_path.resolve().relative_to(ROOT)
        log = subprocess.run(["git", "-C", str(ROOT), "log", "--format=%H %cI", "--", str(rel)], capture_output=True, text=True, check=True).stdout
        for line in log.splitlines():
            sha, t = line.split()
            blob = subprocess.run(["git", "-C", str(ROOT), "show", f"{sha}:{rel}"], capture_output=True, text=True, check=True).stdout
            out.append((when(t), json.loads(blob)))
    except (subprocess.CalledProcessError, ValueError, FileNotFoundError):
        pass
    out.sort(key=lambda x: x[0])
    if hashes_path.exists():
        out.append((datetime.datetime.now(datetime.timezone.utc), json.loads(hashes_path.read_text())))
    return out


def read_baseline(z, hist):
    """Le impronte delle pagine della zona al momento della lettura: la prima registrazione dal giorno della lettura in
    poi (o la più recente, se la lettura è dopo l'ultima). Solo le impronte non vuote"""
    if not hist:
        return {}
    read = when(z["source"]["checkedOn"])
    snap = next((d for t, d in hist if t >= read), hist[-1][1])
    return {u: snap[u] for u in zone_pages(z) if snap.get(u)}


def baseline(source):
    """Le impronte dell'ultimo evento: la verifica se è più recente (o uguale) della lettura, altrimenti la lettura"""
    v = source.get("verifiedOn")
    if v and source.get("verifiedFingerprints") is not None and when(v) >= when(source["checkedOn"]):
        return source["verifiedFingerprints"]
    return source.get("readFingerprints") or {}


def changed_pages(source, hashes):
    """Le pagine la cui impronta di oggi è diversa da quella dell'ultimo evento (verifica o lettura). Un'impronta vuota
    (pagina non letta) o mancante non dice niente: non conta come cambiata"""
    return sorted(u for u, h in baseline(source).items() if h and hashes.get(u) and hashes[u] != h)


def mark_city(city, hashes, hist=None):
    """Scrive le impronte della lettura dove mancano (o la lettura è cambiata) e scrive o toglie «pageChanged» in ogni
    zona. Vero se qualcosa è cambiato"""
    touched = False
    for z in city.get("zones", []):
        s = z["source"]
        if hist is not None and s.get("readFingerprintsOf") != s["checkedOn"]:
            s["readFingerprints"] = read_baseline(z, hist)
            s["readFingerprintsOf"] = s["checkedOn"]
            touched = True
        want = bool(changed_pages(s, hashes))
        if want and s.get("pageChanged") is not True:
            s["pageChanged"] = True
            touched = True
        elif not want and "pageChanged" in s:
            del s["pageChanged"]
            touched = True
    return touched


def mark(cities_dir=CITIES, hashes_path=HASHES, out=print, hist=None):
    hashes = json.loads(hashes_path.read_text()) if hashes_path.exists() else {}
    hist = history(hashes_path) if hist is None else hist
    changed = []
    for f in sorted(p for p in cities_dir.glob("*.json") if p.name != "manifest.json"):
        city = json.loads(f.read_text(encoding="utf-8"))
        if mark_city(city, hashes, hist):
            f.write_text(dump(city), encoding="utf-8")
            changed.append(f.name)
        for z in city.get("zones", []):
            for u in changed_pages(z["source"], hashes):
                out(f"PAGINA CAMBIATA DOPO LA LETTURA O LA VERIFICA {city['id']} {z['id']} {u}")
    out(f"{len(changed)} file delle città aggiornati" + (": " + ", ".join(changed) if changed else ""))
    return changed


def verify(city_id, zone_ids, now=None, cities_dir=CITIES, hashes_path=HASHES):
    f = cities_dir / f"{city_id}.json"
    city = json.loads(f.read_text(encoding="utf-8"))
    hashes = json.loads(hashes_path.read_text())
    when = (now or datetime.datetime.now(datetime.timezone.utc)).strftime("%Y-%m-%dT%H:%M:%SZ")
    done = []
    for z in city["zones"]:
        if zone_ids and z["id"] not in zone_ids:
            continue
        s = z["source"]
        s["verifiedOn"] = when
        s["verifiedFingerprints"] = {u: hashes.get(u, "") for u in zone_pages(z)}
        s.pop("pageChanged", None)
        s["reviewedByHuman"] = True
        done.append(z["id"])
    missing = set(zone_ids) - set(done)
    if missing:
        raise SystemExit(f"zone sconosciute in {city_id}: {', '.join(sorted(missing))}")
    f.write_text(dump(city), encoding="utf-8")
    print(f"{city_id}: verificate il {when}: {', '.join(done)}")


def selftest():
    url = "https://www.comune.example.it/ztl"
    t = lambda d: datetime.datetime(2026, 10, d, 6, tzinfo=datetime.timezone.utc)
    city = {"id": "prova", "zones": [{"id": "prova-a", "source": {"pageURL": url, "links": [], "checkedOn": "2026-10-25T12:00:00Z"}}]}
    with tempfile.TemporaryDirectory() as d:
        d = Path(d)
        f = d / "prova.json"
        f.write_text(dump(city), encoding="utf-8")
        hp = d / "hashes.json"
        src = lambda: json.loads(f.read_text())["zones"][0]["source"]
        quiet = lambda *_: None
        # Lettura del 25: vale la prima impronta dal 25 in poi (quella del 26), non quella del 24
        hist = [(t(24), {url: "old"}), (t(26), {url: "aaaa"}), (t(28), {url: "aaaa"})]
        hp.write_text(json.dumps({url: "aaaa"}))
        assert mark(d, hp, out=quiet, hist=hist) == ["prova.json"]
        s = src()
        assert s["readFingerprints"] == {url: "aaaa"} and s["readFingerprintsOf"] == "2026-10-25T12:00:00Z" and "pageChanged" not in s
        assert mark(d, hp, out=quiet, hist=hist) == []                      # niente di nuovo
        hp.write_text(json.dumps({url: ""}))                                 # pagina non letta oggi: non è «cambiata»
        assert mark(d, hp, out=quiet, hist=hist) == []
        hp.write_text(json.dumps({url: "bbbb"}))                             # cambiata dopo la lettura
        assert mark(d, hp, out=quiet, hist=hist) == ["prova.json"] and src()["pageChanged"] is True
        # Una verifica dopo il cambio: conta la verifica, non la lettura
        verify("prova", [], now=datetime.datetime(2026, 11, 1, tzinfo=datetime.timezone.utc), cities_dir=d, hashes_path=hp)
        s = src()
        assert s["verifiedOn"] == "2026-11-01T00:00:00Z" and s["verifiedFingerprints"] == {url: "bbbb"} and "pageChanged" not in s
        assert mark(d, hp, out=quiet, hist=hist) == []
        hp.write_text(json.dumps({url: "cccc"}))                             # cambiata dopo la verifica
        assert mark(d, hp, out=quiet, hist=hist) == ["prova.json"] and src()["pageChanged"] is True
        # Una nuova lettura (checkedOn nuovo) più recente della verifica: nuove impronte della lettura, si riparte da lì
        c = json.loads(f.read_text()); c["zones"][0]["source"]["checkedOn"] = "2026-11-03T00:00:00Z"; f.write_text(dump(c))
        hist2 = hist + [(datetime.datetime(2026, 11, 3, 6, tzinfo=datetime.timezone.utc), {url: "cccc"})]
        assert mark(d, hp, out=quiet, hist=hist2) == ["prova.json"]
        s = src()
        assert s["readFingerprints"] == {url: "cccc"} and "pageChanged" not in s
    # I file veri si riscrivono identici (nessuna differenza di formato)
    for f in sorted(p for p in CITIES.glob("*.json") if p.name != "manifest.json"):
        t = f.read_text(encoding="utf-8")
        assert dump(json.loads(t)) == t, f"{f.name}: formato diverso da quello degli script"
    print("source_trust: prove passate")


if __name__ == "__main__":
    args = sys.argv[1:]
    if args == ["--selftest"]:
        selftest()
    elif args[:1] == ["mark"]:
        mark()
    elif args[:1] == ["verify"] and len(args) >= 2:
        verify(args[1], args[2:])
    else:
        raise SystemExit(__doc__ or "uso: mark | verify <città> [zona…] | --selftest")
