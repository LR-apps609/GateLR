#!/usr/bin/env python3
# 1.20.1 «Dati»: la firma dei dati delle città che l'app iPhone scarica da GitHub (Sources/CitySignature.swift).
#
# Cosa si firma: Resources/Cities/manifest.json così com'è (byte per byte), preceduto da «GateLR-cities-v1\n». Il manifest
# ha la versione dei dati e l'impronta SHA-256 di ogni città, quindi la firma copre anche ogni file. La firma (Ed25519,
# 64 byte in base64) sta in Resources/Cities/manifest.sig. L'app accetta un aggiornamento solo se la firma è giusta con la
# chiave pubblica che porta dentro (shared/city-signing-key.txt) e se ogni file ha l'impronta del manifest; altrimenti
# lo ignora e resta con i dati che ha (quelli dentro l'app o l'ultimo aggiornamento firmato).
#
# La chiave privata NON sta mai nel repository: è il segreto CITY_DATA_SIGNING_KEY di GitHub (Settings → Secrets and
# variables → Actions), letto solo dal workflow «Firma dei dati delle città». Vedi docs/dati-verifica.md.
#
# Uso:
#   python3 Tools/sign_cities.py new-key [file]   # una volta, sul Mac: nuova coppia di chiavi. La pubblica va in
#                                                 # shared/city-signing-key.txt, la privata nel file indicato (di serie
#                                                 # ~/gatelr-city-signing-key.txt), da mettere nel segreto e poi cancellare
#   python3 Tools/sign_cities.py sign             # in CI: firma con $CITY_DATA_SIGNING_KEY e ricontrolla
#   python3 Tools/sign_cities.py verify           # controlla manifest.sig e le impronte dei file
# Serve il pacchetto «cryptography» (pip install cryptography).
import base64, hashlib, json, os, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CITIES = ROOT / "Resources/Cities"
MANIFEST = CITIES / "manifest.json"
SIGNATURE = CITIES / "manifest.sig"
PUBLIC_KEY = ROOT / "shared/city-signing-key.txt"
CONTEXT = b"GateLR-cities-v1\n"


def crypto():
    try:
        from cryptography.hazmat.primitives.asymmetric import ed25519
        return ed25519
    except ImportError:
        raise SystemExit("Manca il pacchetto «cryptography»: pip install cryptography")


def public_key_text(path=None):
    """La chiave pubblica: la prima riga che non è vuota né un commento (#). None se non c'è ancora"""
    path = path or PUBLIC_KEY
    if not path.exists():
        return None
    for line in path.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            return line
    return None


def check_hashes(manifest_bytes, cities_dir=CITIES):
    """Ogni file del manifest esiste, è nella cartella delle città e ha la sua impronta"""
    m = json.loads(manifest_bytes)
    bad = []
    for e in m.get("cities", []) + m.get("unofficialCities", []):
        name = e["file"]
        f = cities_dir / name
        if "/" in name or "\\" in name or name.startswith(".") or not f.exists():
            bad.append(f"{name}: file mancante o nome non valido")
        elif hashlib.sha256(f.read_bytes()).hexdigest() != e["sha256"]:
            bad.append(f"{name}: impronta diversa dal manifest (rifare Tools/build_manifest.py)")
    return bad


def verify(manifest_bytes, signature_text, key_text):
    ed = crypto()
    from cryptography.exceptions import InvalidSignature
    try:
        key = ed.Ed25519PublicKey.from_public_bytes(base64.b64decode(key_text))
        key.verify(base64.b64decode(signature_text.strip()), CONTEXT + manifest_bytes)
        return True
    except (InvalidSignature, ValueError):
        return False


def new_key(out):
    ed = crypto()
    from cryptography.hazmat.primitives import serialization as ser
    out = Path(out).expanduser()
    if out.exists():
        raise SystemExit(f"{out} c'è già: non lo sovrascrivo")
    priv = ed.Ed25519PrivateKey.generate()
    seed = priv.private_bytes(ser.Encoding.Raw, ser.PrivateFormat.Raw, ser.NoEncryption())
    pub = priv.public_key().public_bytes(ser.Encoding.Raw, ser.PublicFormat.Raw)
    fd = os.open(out, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w") as f:
        f.write(base64.b64encode(seed).decode() + "\n")
    PUBLIC_KEY.write_text(
        "# Chiave pubblica Ed25519 dei dati delle città (base64, 32 byte), dentro l'app iPhone: Sources/CitySignature.swift.\n"
        "# La privata è il segreto CITY_DATA_SIGNING_KEY di GitHub, mai nel repository. Vedi docs/dati-verifica.md\n"
        + base64.b64encode(pub).decode() + "\n")
    # Mai la chiave privata sullo schermo
    print(f"Chiave pubblica scritta in {PUBLIC_KEY} (da fare commit).")
    print(f"Chiave privata in {out} (solo per te). Adesso:")
    print(f"  gh secret set CITY_DATA_SIGNING_KEY -R LR-apps609/GateLR < {out}")
    print(f"  rm -P {out}    # dopo averla messa nel segreto (o conservala in un posto sicuro, fuori dal repository)")


def sign():
    ed = crypto()
    seed_text = os.environ.get("CITY_DATA_SIGNING_KEY", "").strip()
    if not seed_text:
        raise SystemExit("CITY_DATA_SIGNING_KEY vuoto: niente firma")
    key_text = public_key_text()
    if not key_text:
        raise SystemExit("shared/city-signing-key.txt senza chiave pubblica: l'app non saprebbe controllare la firma")
    data = MANIFEST.read_bytes()
    bad = check_hashes(data)
    if bad:
        raise SystemExit("Non firmo un manifest che non torna:\n" + "\n".join(bad))
    priv = ed.Ed25519PrivateKey.from_private_bytes(base64.b64decode(seed_text))
    sig = base64.b64encode(priv.sign(CONTEXT + data)).decode()
    if not verify(data, sig, key_text):
        raise SystemExit("La chiave del segreto non è quella di shared/city-signing-key.txt: firma non scritta")
    SIGNATURE.write_text(sig + "\n")
    print(f"manifest {json.loads(data)['version']} firmato")


def verify_cmd():
    key_text = public_key_text()
    data = MANIFEST.read_bytes()
    bad = check_hashes(data)
    for b in bad:
        print("::error::" + b)
    if not key_text:
        print("::warning::Nessuna chiave pubblica in shared/city-signing-key.txt: l'app ignora tutti gli aggiornamenti scaricati")
    elif not SIGNATURE.exists():
        print("::warning::Manca Resources/Cities/manifest.sig: l'app ignora l'aggiornamento finché il workflow non lo firma")
    elif not verify(data, SIGNATURE.read_text(), key_text):
        print("::warning::manifest.sig non vale per questo manifest: l'app ignora l'aggiornamento finché il workflow non lo firma di nuovo")
    else:
        print("firma del manifest valida")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["new-key"]:
        new_key(a[1] if len(a) > 1 else "~/gatelr-city-signing-key.txt")
    elif a == ["sign"]:
        sign()
    elif a == ["verify"]:
        verify_cmd()
    else:
        raise SystemExit("uso: new-key [file] | sign | verify")
