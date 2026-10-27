#!/usr/bin/env python3
# Costruisce la scheda di Trieste da quanto salvato in data/raw/trieste/ (fonti e date in docs/fonti-trieste.md).
#
# A Trieste non c'è una grande ZTL con telecamere: l'elenco ufficiale del Comune («Aree Pedonali e Zone a Traffico
# Limitato», 2020/21) conta 97.214 m² di aree pedonali e solo 17.523 m² di ZTL, in tanti pezzi: «tipo A» (Genova, Caboro,
# Beccherie/Ombrelle/Ponte/Pane), «tipo B» (Borgo Teresiano: via Trento, Mercadante, Torre Bianca, Lavatoio, Geppa,
# Galatti), «Elevata/Penetrazione a Valenza Pedonale». Nessuna fonte parla di varchi elettronici.
# La scheda contiene le sei ZTL «tipo B» del Borgo Teresiano, le uniche con un orario ufficiale: «riservate dalle 0.00 alle
# 24.00 dei giorni feriali prevalentemente alla sosta dei residenti» (FAQ della Polizia Locale, letta il 27/10/2026:
# citazione verificata); la nota informativa 2026 del Comune per le ditte del Borgo Teresiano conferma che le ZTL tipo B
# sono ancora in vigore. ZTL di tipo A e aree pedonali (nessun orario ufficiale) restano nei pending.
#
# Geometria (mai disegnata a mano): nessun dato del Comune in open data e nessuna relazione ZTL in OpenStreetMap; ogni ZTL
# «tipo B» è il tratto della via omonima che OSM segna motorcar/motor_vehicle=permit (data/raw/geo/trieste-centro.json,
# Tools/fetch_osm_api.py, 27/10/2026, © OpenStreetMap contributors, ODbL 1.0), allargato a una striscia la cui superficie
# è quella dell'elenco ufficiale (larghezza = superficie / lunghezza: 9–12 m per tutte e sei, cioè una carreggiata con i
# marciapiedi: è il controllo che il tratto OSM corrisponde alla ZTL ufficiale).
# Uso: python3 Tools/build_trieste.py   (non tocca le altre città né manifest.json)
import json, math, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/trieste"
CHECKED = "2026-10-27T12:40:00Z"
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


LIST_F, PRESC_F, FORM_F, FAQ_F, BT_F = ("comune-elenco-apu-ztl-2020", "comune-prescrizioni-permesso-temporaneo",
                                        "comune-modulo-permessi-ztl-b", "polizialocale-faq-accesso-ztl", "comune-nota-ditte-borgo-teresiano-2026")
LIST, PRESC, FORM, FAQ, BT = map(url_of, (LIST_F, PRESC_F, FORM_F, FAQ_F, BT_F))
QUOTE = "di tipo B (riservate dalle 0.00 alle 24.00 dei giorni feriali prevalentemente alla sosta dei residenti)"
# le sei ZTL «tipo B» dell'elenco ufficiale: (riga dell'elenco, via OSM)
ZTL_B = [("B 24 / 2016 Trento", "Via Trento"), ("B 26 / 1990 Mercadante", "Via Saverio Mercadante"),
         ("B 26 / 1990 Torre Bianca", "Via di Torre Bianca"), ("B 60 / 1990 Lavatoio", "Via del Lavatoio"),
         ("B 60 / 1990 Geppa", "Via della Geppa"), ("B 60 / 1990 Galatti", "Via Giorgio Galatti")]
check(LIST_F, *[r for r, _ in ZTL_B], "ZONE A TRAFFICO LIMITATO (mq): 17523", "AREE PEDONALI (mq): 97214", "lunedì 8 febbraio 2021")
check(FAQ_F, QUOTE, "Possessori di contrassegno disabili non necessitano di autorizzazione",
      "Per ottenere un permesso di accesso alle ZTL è necessario richiedere l’autorizzazione attraverso il portale del Comune di Trieste.")
check(BT_F, "all’accesso nelle Zone a Traffico Limitato di tipo B", "rev.2026", "Via della Geppa", "Via del Lavatoio", "Via Mercadante",
      "Via di Torrebianca", "Via Trento", "plts.permessi@comune.trieste.it")
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
              "Stadt Triest: Antrag ZTL-B-Genehmigung für Firmen (PDF)", FORM),
         link("City of Trieste: Borgo Teresiano ZTL B permits for businesses, 2026 (PDF)", "Comune di Trieste: nota informativa ditte Borgo Teresiano, 2026 (PDF)",
              "Stadt Triest: ZTL-B-Genehmigungen Borgo Teresiano für Firmen, 2026 (PDF)", BT)]

PENDING = [
    ("«Type B» ZTLs are reserved 0:00–24:00 on working days, mainly for residents' parking (municipal police FAQ). GateLR treats Monday–Saturday as working days and Sundays and public holidays as free; the City does not spell out whether Saturday counts.",
     "Le ZTL «tipo B» sono riservate dalle 0 alle 24 dei giorni feriali, soprattutto alla sosta dei residenti (FAQ della Polizia Locale). GateLR considera feriali lunedì–sabato e liberi domeniche e festivi; il Comune non precisa se il sabato conti come feriale.",
     "ZTL «Typ B» sind an Werktagen von 0 bis 24 Uhr vorbehalten, vor allem zum Parken für Anwohner (FAQ der Ortspolizei). GateLR behandelt Montag–Samstag als Werktage, Sonn- und Feiertage als frei; ob der Samstag zählt, sagt die Stadt nicht ausdrücklich."),
    ("No cameras are known in Trieste: checks are made by municipal police officers. Not in GateLR yet: the small «type A» ZTLs (Via Genova, Caboro, Beccherie/Ombrelle/Ponte/Pane, reserved mainly for pedestrians, no official hours) and the many pedestrian areas (e.g. Piazza Unità d'Italia, Cavana).",
     "Non risultano telecamere a Trieste: i controlli sono degli agenti della Polizia Locale. Non ancora in GateLR: le piccole ZTL «tipo A» (via Genova, Caboro, Beccherie/Ombrelle/Ponte/Pane, riservate soprattutto ai pedoni, senza orari ufficiali) e le molte aree pedonali (es. piazza Unità d'Italia, Cavana).",
     "In Triest sind keine Kameras bekannt: kontrolliert wird von Beamten der Ortspolizei. Noch nicht in GateLR: die kleinen ZTL «Typ A» (Via Genova, Caboro, Beccherie/Ombrelle/Ponte/Pane, vor allem für Fußgänger, ohne offizielle Zeiten) und die vielen Fußgängerzonen (z. B. Piazza Unità d'Italia, Cavana)."),
    ("No visitor or hotel permit: permits are for residents, businesses and sales agents, through the City's portal or the municipal police permits office (Via Revoltella 35, by appointment, tel. 040 6757706). Disabled badge holders need no authorisation.",
     "Nessun permesso per visitatori o ospiti degli hotel: i permessi sono per residenti, ditte e agenti di commercio, dal portale del Comune o all'Ufficio Permessi della Polizia Locale (via Revoltella 35, su appuntamento, tel. 040 6757706). I titolari di contrassegno disabili non hanno bisogno di autorizzazione.",
     "Keine Genehmigung für Besucher oder Hotelgäste: Genehmigungen gibt es für Anwohner, Firmen und Handelsvertreter über das Portal der Stadt oder beim Genehmigungsbüro der Ortspolizei (Via Revoltella 35, nach Termin, Tel. 040 6757706). Inhaber eines Behindertenausweises brauchen keine Genehmigung."),
    ("Street sections from OpenStreetMap (marked «permit only»), widened to the surface given in the City's list of ZTLs (2021); not an official map.",
     "Tratti delle vie da OpenStreetMap (segnati «solo autorizzati»), allargati alla superficie indicata nell'elenco delle ZTL del Comune (2021); non è una mappa ufficiale.",
     "Straßenabschnitte aus OpenStreetMap (als «nur mit Genehmigung» markiert), auf die Fläche aus der ZTL-Liste der Stadt (2021) verbreitert; keine offizielle Karte."),
]

# superficie ufficiale (m²) di ogni ZTL tipo B, dall'elenco del Comune
OFFICIAL_SQM = {r: int(re.search(re.escape(r) + r" (\d+)", TEXT[LIST_F]).group(1)) for r, _ in ZTL_B}


def strip(ways, sqm):
    """Le way OSM allargate a una striscia della superficie ufficiale: larghezza = superficie / lunghezza (deve stare tra
    8 e 13 m, una carreggiata con i marciapiedi, altrimenti il tratto OSM non è la ZTL dell'elenco)"""
    from shapely.geometry import LineString
    from shapely.ops import unary_union
    lat0 = sum(p["lat"] for w in ways for p in w["geometry"]) / sum(len(w["geometry"]) for w in ways)
    k = math.cos(math.radians(lat0))
    fwd = lambda p: (p["lon"] * k * 111320.0, p["lat"] * 110574.0)
    lines = [LineString([fwd(p) for p in w["geometry"]]) for w in ways]
    length = sum(l.length for l in lines)
    width = sqm / length
    assert 8 <= width <= 13, (ways[0]["tags"]["name"], sqm, round(length), round(width, 1))
    poly = unary_union([l.buffer(width / 2, cap_style=2, join_style=2) for l in lines])
    poly = max(getattr(poly, "geoms", [poly]), key=lambda g: g.area)
    ring = [(x / (k * 111320.0), y / 110574.0) for x, y in poly.exterior.coords]
    return osm_geo.perimeter(ring, tol_m=0.5)


zones = []
for row, street in ZTL_B:
    ways = [w for w in GEO if w["type"] == "way" and w.get("tags", {}).get("name") == street and permit_way(w["tags"])]
    assert ways, street
    sqm = OFFICIAL_SQM[row]
    perim = strip(ways, sqm)
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
                   "ordinanceURL": LIST, "quote": QUOTE,
                   "quoteTranslation": "type B (reserved from 0:00 to 24:00 on working days, mainly for residents' parking)",
                   "quoteTranslation_de": "Typ B (an Werktagen von 0:00 bis 24:00 Uhr vorbehalten, vorwiegend zum Parken für Anwohner)",
                   "checkedOn": CHECKED, "reviewedByHuman": False,
                   "pending": [p[0] for p in PENDING], "pending_it": [p[1] for p in PENDING], "pending_de": [p[2] for p in PENDING],
                   "links": LINKS}})

city = {"id": "trieste", "name": "Trieste", "name_it": "Trieste", "name_de": "Triest",
        "center": {"lat": 45.6503, "lon": 13.7681}, "zones": zones, "status": "draft",
        "license": "Rules: Comune di Trieste and Polizia Locale di Trieste official documents. Street sections: " + osm_geo.ODBL + ", widened to the official surfaces."}

for z in zones:
    a = osm_geo.area_km2(z["perimeter"]) * 1e6
    assert 300 < a < 4000, (z["id"], a)
assert not any(osm_geo.contains(z["perimeter"], 45.6508, 13.7663) for z in zones), "piazza Unità dentro una ZTL B"
assert not any(osm_geo.contains(z["perimeter"], 45.6575, 13.7720) for z in zones), "stazione centrale dentro una ZTL B"
for (row, street), z in zip(ZTL_B, zones):   # il punto centrale di ogni tratto OSM della via cade nella sua zona
    for w in GEO:
        if w["type"] == "way" and w.get("tags", {}).get("name") == street and permit_way(w["tags"]):
            m = w["geometry"][len(w["geometry"]) // 2]
            assert osm_geo.contains(z["perimeter"], m["lat"], m["lon"]) or osm_geo.distance_m(z["perimeter"], m["lat"], m["lon"]) < 1, (street, w["id"])

ready = all(len(z["perimeter"]) >= 5 and z["source"]["quote"] for z in city["zones"])
out = ROOT / ("Resources/Cities/trieste.json" if ready else "data/drafts/trieste.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/trieste.json" if ready else "Resources/Cities/trieste.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), [(z["id"], z["source"]["ordinance"], len(z["perimeter"]), round(osm_geo.area_km2(z["perimeter"]) * 1e6)) for z in zones])
