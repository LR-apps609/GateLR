#!/usr/bin/env python3
# Costruisce la scheda di Mantova (BOZZA) da quanto salvato in data/raw/mantova/ (fonti e date in docs/fonti-mantova.md).
#
# Perché è una bozza (27/10/2026): sul sito del Comune (www.comune.mantova.it) l'argomento «ZTL» non ha una pagina con
# orari, vie o perimetro; il servizio dei permessi rimanda allo sportello www.sut.comune.mantova.it e le regole dei pass sono
# su www.aster.mn.it: entrambi bloccati dal proxy (403), come l'albo pretorio (pubblicazioni.comune.mantova.it) e gli
# allegati del PUMS/PUT (nextcloud-municipium.maggiolicloud.it); il vecchio sito www.comune.mantova.gov.it non risponde
# (502). Le regole qui sotto vengono quindi solo da fonti non ufficiali (riassunti della ricerca web), senza citazione.
# Geometria: nessun open data (dati.lombardia.it, dati.gov.it); in OpenStreetMap (API OSM, 27/10/2026) non c'è una relazione
# della ZTL e le 99 strade con motor_vehicle=permit non coprono le vie principali (l'area che ne risulta è a pezzi): nessun
# perimetro affidabile.
# Per pubblicarla servono: il disciplinare/ordinanza ZTL o la pagina Aster salvati (con orari di ZTL A e B e la procedura
# per gli ospiti degli hotel) e un perimetro (elenco ufficiale delle vie, da applicare alle strade OSM come in build_como.py).
# Uso: python3 Tools/build_mantova.py   (non tocca le altre città né manifest.json)
import json, re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/mantova"
CHECKED = "2026-10-27T13:00:00Z"
EVERY_DAY = [1, 2, 3, 4, 5, 6, 7]


def flat(s):
    return re.sub(r"\s+", " ", s).strip()


TEXT = {p.stem: flat(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def check(file, *phrases):
    for q in phrases:
        if flat(q) not in TEXT[file]:
            raise SystemExit(f"{file}: frase non trovata: {q!r}")


TOPIC = "https://www.comune.mantova.it/it/topics/ztl"
DISABLED = "https://www.comune.mantova.it/it/services/prenotazione-accesso-zona-a-traffico-limitato-ztl-con-pass-disabile-altre-citta"
ASTER = "https://www.aster.mn.it/cittadini/ztl"
check("comune-servizio-pass-disabili-altre-citta",
      "I possessori di pass disabile residenti fuori Comune che necessitano di circolare nelle zone a traffico limitato (ZTL) e sostare nei parcheggi riservati possono prenotare l'accesso.",
      "infomulte@comune.mantova.it")
check("websearch-27-ottobre-2026", "telecamere attive tutti i giorni 24 ore su 24", "Corso della Libertà e via Trieste aperti a tutti 7–12 e 18–21",
      "voucher ZTL 2,60 € per 24 ore")


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


PENDING = [
    ("Hours confirmed only by unofficial guides (accessibilitacentristorici.it, tyremap.com): ZTL A and B cameras active 24 hours a day, every day; Corso della Libertà and Via Trieste open to all 7–12 and 18–21. One tour-bus site says 7–19.",
     "Orari confermati solo da guide non ufficiali (accessibilitacentristorici.it, tyremap.com): telecamere di ZTL A e B attive 24 ore su 24 tutti i giorni; Corso della Libertà e via Trieste aperti a tutti 7–12 e 18–21. Un sito per bus turistici indica 7–19.",
     "Zeiten nur von inoffiziellen Führern bestätigt (accessibilitacentristorici.it, tyremap.com): Kameras der ZTL A und B täglich rund um die Uhr aktiv; Corso della Libertà und Via Trieste 7–12 und 18–21 für alle offen. Eine Reisebus-Seite nennt 7–19."),
    ("Hotel guests: the hotel registers the plate online through Aster (the City's company); hotels mention a 24-hour ZTL voucher of 2.60 € — confirmed only by a newspaper (Gazzetta di Mantova) and hotel sites.",
     "Ospiti degli hotel: la struttura registra la targa online tramite Aster (società del Comune); alcuni hotel indicano un voucher ZTL di 2,60 € per 24 ore — confermato solo dalla Gazzetta di Mantova e da siti di hotel.",
     "Hotelgäste: Das Hotel meldet das Kennzeichen online über Aster (Gesellschaft der Stadt); Hotels nennen einen ZTL-Gutschein von 2,60 € für 24 Stunden — nur von der Gazzetta di Mantova und Hotelseiten bestätigt."),
    ("No official map: the perimeter is not drawn.",
     "Nessuna mappa ufficiale: il perimetro non è disegnato.",
     "Keine offizielle Karte: die Grenze ist nicht eingezeichnet."),
]

zone = {"id": "mantova-ztl", "name": "Mantova · Historic centre ZTL (A and B)", "name_it": "Mantova · ZTL centro storico (A e B)",
        "name_de": "Mantova · ZTL Altstadt (A und B)", "kind": "restricted",
        "summary": "Draft: the historic centre is split into ZTL A and B with cameras reported active 24 hours a day. Rules not yet confirmed on official pages.",
        "summary_it": "Bozza: il centro storico è diviso in ZTL A e B con telecamere indicate attive 24 ore su 24. Regole non ancora confermate su pagine ufficiali.",
        "summary_de": "Entwurf: Die Altstadt ist in ZTL A und B geteilt, Kameras laut Berichten rund um die Uhr aktiv. Regeln noch nicht auf offiziellen Seiten bestätigt.",
        "perimeter": [], "gates": [],
        "windows": [{"weekdays": EVERY_DAY, "start": 0, "end": 24 * 60}],
        "freeOnHolidays": None, "exemptFuels": [], "hotelCanRegister": True,
        "source": {"authority": "City of Mantua", "pageURL": TOPIC, "ordinance": None, "ordinanceURL": None, "quote": None,
                   "checkedOn": CHECKED, "reviewedByHuman": False,
                   "pending": [p[0] for p in PENDING], "pending_it": [p[1] for p in PENDING], "pending_de": [p[2] for p in PENDING],
                   "links": [link("City of Mantua: ZTL topic", "Comune di Mantova: argomento ZTL", "Stadt Mantua: Thema ZTL", TOPIC),
                             link("Aster: access to the ZTL (passes)", "Aster: accesso alle ZTL (pass)", "Aster: Zufahrt zur ZTL (Ausweise)", ASTER),
                             link("City of Mantua: disabled badge holders from other cities", "Comune di Mantova: pass disabili di altre città",
                                  "Stadt Mantua: Behindertenausweise aus anderen Städten", DISABLED)]}}

city = {"id": "mantova", "name": "Mantua", "name_it": "Mantova", "name_de": "Mantua",
        "center": {"lat": 45.1597, "lon": 10.7967}, "zones": [zone], "status": "draft",
        "license": "Rules: unofficial sources only (draft)."}

ready = all(len(z["perimeter"]) >= 5 and z["source"]["quote"] for z in city["zones"])
out = ROOT / ("Resources/Cities/mantova.json" if ready else "data/drafts/mantova.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/mantova.json" if ready else "Resources/Cities/mantova.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), "bozza" if not ready else "pubblicata")
