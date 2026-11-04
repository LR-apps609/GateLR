#!/usr/bin/env python3
# 1.20.1 «Dati»: «letto il» e «verificato il» delle zone, e la pagina del Comune cambiata dopo la verifica.
#
# Nei file delle città (Resources/Cities/<città>.json), per ogni zona, in «source»:
# - checkedOn            «letto il»: quando abbiamo letto le pagine da cui vengono le regole (c'era già)
# - verifiedOn           «verificato il»: quando una persona (o un controllo) ha confermato la regola. Assente = non lo
#                        sappiamo = NON verificata. Non si inventa: la scrive solo «verify» qui sotto, dopo una verifica vera
# - verifiedFingerprints le impronte delle pagine ufficiali della zona (Tools/check_sources.py, data/source-hashes.json)
#                        nel momento della verifica
# - pageChanged          true se l'impronta di oggi di una di quelle pagine è diversa da quella della verifica. La scrive
#                        «mark» dalle impronte del controllo giornaliero («Controllo pagine dei Comuni»); mai a mano
#
# Le app e il sito: una zona ufficiale è «sicura» solo se verificata da al più 120 giorni (VERIFIED_FRESH_DAYS, lo stesso
# numero di RuleEngine.staleAfterDays su iPhone e Android e del sito) e senza pagina cambiata. Altrimenti un «sì» (verde o
# grigio) diventa giallo con il «?» «Controlla il cartello»; con la pagina cambiata TUTTE le risposte della zona diventano
# gialle («La pagina del Comune è cambiata: controlla il cartello»). Vedi docs/dati-verifica.md.
#
# Uso:
#   python3 Tools/source_trust.py mark                     # pageChanged dalle impronte di data/source-hashes.json
#   python3 Tools/source_trust.py verify <città> [zona…]   # dopo una verifica umana: verifiedOn = adesso + impronte di adesso
#   python3 Tools/source_trust.py --selftest
# Dopo «mark» o «verify», se i file sono cambiati: python3 Tools/build_manifest.py (e la firma, in CI)
import datetime, json, sys, tempfile
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


def changed_pages(source, hashes):
    """Le pagine la cui impronta di oggi è diversa da quella della verifica. Un'impronta vuota (pagina non letta) o
    mancante non dice niente: non conta come cambiata"""
    vf = source.get("verifiedFingerprints") or {}
    return sorted(u for u, h in vf.items() if h and hashes.get(u) and hashes[u] != h)


def mark_city(city, hashes):
    """Scrive o toglie «pageChanged» in ogni zona. Vero se qualcosa è cambiato"""
    touched = False
    for z in city.get("zones", []):
        s = z["source"]
        want = bool(changed_pages(s, hashes))
        if want and s.get("pageChanged") is not True:
            s["pageChanged"] = True
            touched = True
        elif not want and "pageChanged" in s:
            del s["pageChanged"]
            touched = True
    return touched


def mark(cities_dir=CITIES, hashes_path=HASHES, out=print):
    hashes = json.loads(hashes_path.read_text()) if hashes_path.exists() else {}
    changed = []
    for f in sorted(p for p in cities_dir.glob("*.json") if p.name != "manifest.json"):
        city = json.loads(f.read_text(encoding="utf-8"))
        if mark_city(city, hashes):
            f.write_text(dump(city), encoding="utf-8")
            changed.append(f.name)
        for z in city.get("zones", []):
            for u in changed_pages(z["source"], hashes):
                out(f"PAGINA CAMBIATA DOPO LA VERIFICA {city['id']} {z['id']} {u}")
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
    city = {"id": "prova", "zones": [{"id": "prova-a", "source": {"pageURL": url, "links": [], "checkedOn": "2026-10-01T00:00:00Z"}}]}
    with tempfile.TemporaryDirectory() as d:
        d = Path(d)
        (d / "prova.json").write_text(dump(city), encoding="utf-8")
        hp = d / "hashes.json"
        hp.write_text(json.dumps({url: "aaaa"}))
        # Non verificata: nessuna impronta della verifica, nessun «pageChanged»
        assert mark(d, hp, out=lambda *_: None) == []
        verify("prova", [], now=datetime.datetime(2026, 11, 1, tzinfo=datetime.timezone.utc), cities_dir=d, hashes_path=hp)
        s = json.loads((d / "prova.json").read_text())["zones"][0]["source"]
        assert s["verifiedOn"] == "2026-11-01T00:00:00Z" and s["verifiedFingerprints"] == {url: "aaaa"} and "pageChanged" not in s
        # Stessa impronta: niente
        assert mark(d, hp, out=lambda *_: None) == []
        # Pagina non letta oggi (impronta vuota): non è «cambiata»
        hp.write_text(json.dumps({url: ""}))
        assert mark(d, hp, out=lambda *_: None) == []
        # Impronta diversa: pageChanged
        hp.write_text(json.dumps({url: "bbbb"}))
        assert mark(d, hp, out=lambda *_: None) == ["prova.json"]
        assert json.loads((d / "prova.json").read_text())["zones"][0]["source"]["pageChanged"] is True
        # Nuova verifica: via il segno
        verify("prova", ["prova-a"], cities_dir=d, hashes_path=hp)
        s = json.loads((d / "prova.json").read_text())["zones"][0]["source"]
        assert "pageChanged" not in s and s["verifiedFingerprints"] == {url: "bbbb"}
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
