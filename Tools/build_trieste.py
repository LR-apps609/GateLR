#!/usr/bin/env python3
# Costruisce la scheda di Trieste (BOZZA) da quanto salvato in data/raw/trieste/ (fonti e date in docs/fonti-trieste.md).
#
# A Trieste non c'è una grande ZTL con telecamere: l'elenco ufficiale del Comune («Aree Pedonali e Zone a Traffico
# Limitato», 2020/21) conta 97.214 m² di aree pedonali e solo 17.523 m² di ZTL, in tanti pezzi: «tipo A» (Genova, Caboro,
# Beccherie/Ombrelle/Ponte/Pane), «tipo B» (Borgo Teresiano: via Trento, Mercadante, Torre Bianca, Lavatoio, Geppa,
# Galatti), «Elevata/Penetrazione a Valenza Pedonale». Nessuna fonte trovata parla di varchi elettronici.
# La scheda (bozza) contiene le sei ZTL «tipo B» del Borgo Teresiano, le uniche con un orario noto: «riservate dalle 0.00
# alle 24.00 dei giorni feriali prevalentemente alla sosta dei residenti» — frase della FAQ della Polizia Locale, che però
# era bloccata dal proxy del sandbox (403): letta solo nel riassunto della ricerca web, quindi nessuna citazione verificata.
# Per pubblicarla servono il testo della FAQ (o delle ordinanze 26/1990, 60/1990, 24/2016) e una decisione su come trattare
# le ZTL di tipo A e le aree pedonali.
#
# Geometria (mai disegnata a mano): nessun dato del Comune in open data (dati.friuliveneziagiulia.it: niente ZTL di
# Trieste) e nessuna relazione ZTL in OpenStreetMap; ogni ZTL «tipo B» è l'area coperta (osm_geo.street_area) dalle way OSM
# della via omonima segnate motorcar/motor_vehicle=permit, scaricate con Tools/fetch_osm_api.py il 27/10/2026
# (data/raw/geo/trieste-centro.json, © OpenStreetMap contributors, ODbL 1.0).
# Uso: python3 Tools/build_trieste.py   (non tocca le altre città né manifest.json)
import json, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/trieste"
CHECKED = "2026-10-27T11:45:00Z"
MON_SAT = [2, 3, 4, 5, 6, 7]


def flat(s):
    return re.sub(r"\s+", " ", s).strip()


TEXT = {p.stem: flat(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def check(file, *phrases):
    for q in phrases:
        if flat(q) not in TEXT[file]:
            raise SystemExit(f"{file}: frase non trovata: {q!r}")


def url_of(file):
    return TEXT[file].split(" ", 2)[1]


LIST_F, PRESC_F, FORM_F, FAQ_F = ("comune-elenco-apu-ztl-2020", "comune-prescrizioni-permesso-temporaneo",
                                  "comune-modulo-permessi-ztl-b", "websearch-1-ztl-trieste")
LIST, PRESC, FORM, FAQ = map(url_of, (LIST_F, PRESC_F, FORM_F, FAQ_F))
# le sei ZTL «tipo B» dell'elenco ufficiale: (riga dell'elenco, via OSM)
ZTL_B = [("B 24 / 2016 Trento", "Via Trento"), ("B 26 / 1990 Mercadante", "Via Saverio Mercadante"),
         ("B 26 / 1990 Torre Bianca", "Via di Torre Bianca"), ("B 60 / 1990 Lavatoio", "Via del Lavatoio"),
         ("B 60 / 1990 Geppa", "Via della Geppa"), ("B 60 / 1990 Galatti", "Via Giorgio Galatti")]
check(LIST_F, *[r for r, _ in ZTL_B], "ZONE A TRAFFICO LIMITATO (mq): 17523", "AREE PEDONALI (mq): 97214", "lunedì 8 febbraio 2021")
check(FAQ_F, "di tipo B (riservate dalle 0.00 alle 24.00 dei giorni feriali prevalentemente alla sosta dei residenti)",
      "Le persone con contrassegno disabili sono esentate dall'autorizzazione.", "NON verificato")
check(FORM_F, "Domanda permessi per aree a traffico limitato (ZTL B)", "Borgo Teresiano")
check(PRESC_F, "rispettare il limite di velocità di 10 km/h con l'obbligo di dare precedenza ai pedoni")

GEO = json.loads((ROOT / "data/raw/geo/trieste-centro.json").read_text(encoding="utf-8"))["elements"]


def permit_way(t):
    return t.get("motorcar") == "permit" or t.get("motor_vehicle") == "permit"


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


LINKS = [link("Municipal police: how to enter a ZTL in Trieste", "Polizia Locale: come accedere a una ZTL di Trieste",
              "Ortspolizei: Zufahrt zu einer ZTL in Triest", FAQ),
         link("City of Trieste: list of pedestrian areas and ZTLs (PDF)", "Comune di Trieste: elenco aree pedonali e ZTL (PDF)",
              "Stadt Triest: Liste der Fußgängerzonen und ZTL (PDF)", LIST),
         link("City of Trieste: ZTL B permit form for businesses (PDF)", "Comune di Trieste: modulo permessi ZTL B per le ditte (PDF)",
              "Stadt Triest: Antrag ZTL-B-Genehmigung für Firmen (PDF)", FORM)]

PENDING = [
    ("Hours confirmed only by a web-search summary of the municipal police FAQ: «type B» ZTLs are reserved 0:00–24:00 on working days, mainly for residents' parking. GateLR treats Monday–Saturday as working days and Sundays and public holidays as free.",
     "Orari confermati solo dal riassunto della ricerca web della FAQ della Polizia Locale: le ZTL «tipo B» sono riservate dalle 0 alle 24 dei giorni feriali, soprattutto per la sosta dei residenti. GateLR considera feriali lunedì–sabato e liberi domeniche e festivi.",
     "Zeiten nur durch eine Websuche-Zusammenfassung der FAQ der Ortspolizei bestätigt: ZTL «Typ B» sind an Werktagen von 0 bis 24 Uhr vorbehalten, vor allem zum Parken für Anwohner. GateLR behandelt Montag–Samstag als Werktage, Sonn- und Feiertage als frei."),
    ("No cameras are known in Trieste: checks are made by municipal police officers. Not in GateLR yet: the small «type A» ZTLs (Via Genova, Caboro, Beccherie/Ombrelle/Ponte/Pane) and the many pedestrian areas (e.g. Piazza Unità d'Italia, Cavana).",
     "Non risultano telecamere a Trieste: i controlli sono degli agenti della Polizia Locale. Non ancora in GateLR: le piccole ZTL «tipo A» (via Genova, Caboro, Beccherie/Ombrelle/Ponte/Pane) e le molte aree pedonali (es. piazza Unità d'Italia, Cavana).",
     "In Triest sind keine Kameras bekannt: kontrolliert wird von Beamten der Ortspolizei. Noch nicht in GateLR: die kleinen ZTL «Typ A» (Via Genova, Caboro, Beccherie/Ombrelle/Ponte/Pane) und die vielen Fußgängerzonen (z. B. Piazza Unità d'Italia, Cavana)."),
    ("Disabled badge holders are exempt. Permits from the municipal police permits office (Via Revoltella 35, by appointment).",
     "I titolari di contrassegno disabili sono esentati. Permessi all'Ufficio Permessi della Polizia Locale (via Revoltella 35, su appuntamento).",
     "Inhaber eines Behindertenausweises sind befreit. Genehmigungen beim Genehmigungsbüro der Ortspolizei (Via Revoltella 35, nach Termin)."),
    ("Street outlines from OpenStreetMap (not official); the City's list of ZTLs dates from 2021.",
     "Tracciati delle vie da OpenStreetMap (non ufficiali); l'elenco delle ZTL del Comune è del 2021.",
     "Straßenverläufe aus OpenStreetMap (nicht offiziell); die ZTL-Liste der Stadt stammt von 2021."),
]

zones = []
for row, street in ZTL_B:
    ways = [w for w in GEO if w["type"] == "way" and w.get("tags", {}).get("name") == street and permit_way(w["tags"])]
    assert ways, street
    rel = {"id": 0, "members": [{"type": "way", "role": "section", "geometry": w["geometry"]} for w in ways]}
    perim = osm_geo.perimeter(osm_geo.street_area(rel, cell_m=3, close_m=8), tol_m=1.5)
    short = row.split(" ", 4)[-1]
    key = re.sub(r"\W+", "-", short.lower())
    zones.append({
        "id": f"trieste-ztl-b-{key}", "name": f"{street} · Borgo Teresiano ZTL B", "name_it": f"{street} · ZTL B Borgo Teresiano",
        "name_de": f"{street} · ZTL B Borgo Teresiano", "kind": "restricted",
        "summary": f"{street} in the Borgo Teresiano is a «type B» ZTL: reserved 0:00–24:00 on working days, mainly for residents' parking. No cameras: police checks.",
        "summary_it": f"{street} nel Borgo Teresiano è una ZTL «tipo B»: riservata dalle 0 alle 24 dei giorni feriali, soprattutto alla sosta dei residenti. Niente telecamere: controlli della Polizia Locale.",
        "summary_de": f"Die {street} im Borgo Teresiano ist eine ZTL «Typ B»: an Werktagen von 0 bis 24 Uhr vorbehalten, vor allem zum Parken für Anwohner. Keine Kameras: Polizeikontrollen.",
        "perimeter": perim, "gates": [],
        "windows": [{"weekdays": MON_SAT, "start": 0, "end": 24 * 60}],
        "freeOnHolidays": True, "exemptFuels": [], "hotelCanRegister": False,
        "source": {"authority": "City of Trieste", "pageURL": FAQ, "ordinance": "Ordinanza n. {1}/{3} (elenco aree pedonali e ZTL del Comune)".format(*row.split()),
                   "ordinanceURL": LIST, "quote": None, "quoteTranslation": None, "quoteTranslation_de": None,
                   "checkedOn": CHECKED, "reviewedByHuman": False,
                   "pending": [p[0] for p in PENDING], "pending_it": [p[1] for p in PENDING], "pending_de": [p[2] for p in PENDING],
                   "links": LINKS}})

city = {"id": "trieste", "name": "Trieste", "name_it": "Trieste", "name_de": "Triest",
        "center": {"lat": 45.6503, "lon": 13.7681}, "zones": zones, "status": "draft",
        "license": "Rules: Comune di Trieste documents and a web-search summary of the municipal police FAQ (not verified). Street outlines: " + osm_geo.ODBL + "."}

for z in zones:
    a = osm_geo.area_km2(z["perimeter"]) * 1e6
    assert 100 < a < 8000, (z["id"], a)
assert not any(osm_geo.contains(z["perimeter"], 45.6508, 13.7663) for z in zones), "piazza Unità dentro una ZTL B"

ready = all(len(z["perimeter"]) >= 5 and z["source"]["quote"] for z in city["zones"])
out = ROOT / ("Resources/Cities/trieste.json" if ready else "data/drafts/trieste.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/trieste.json" if ready else "Resources/Cities/trieste.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), [(z["id"], z["source"]["ordinance"], len(z["perimeter"]), round(osm_geo.area_km2(z["perimeter"]) * 1e6)) for z in zones])
