#!/usr/bin/env python3
# Costruisce Resources/Cities/siena.json dalle pagine e dagli atti ufficiali del Comune di Siena
# salvati in data/raw/siena/ (fonti e date in docs/fonti-siena.md).
# Siena non pubblica dati aperti sulla ZTL: la mappa ufficiale è un PDF senza coordinate.
# Se un giorno arriva un perimetro verificato, basta salvarlo come data/raw/siena/ztl_perimetro.geojson
# (Polygon o MultiPolygon in WGS84) e i varchi come data/raw/siena/varchi.geojson (Point con "name").
# Finché non c'è, perimetro e varchi vengono da OpenStreetMap (data/raw/geo/siena-ztl.json, © OpenStreetMap
# contributors, ODbL 1.0): la relazione «ZTL Siena» non ha un contorno ma elenca le strade della ZTL (ruolo
# «section») e le telecamere (ruolo «device»); il perimetro è l'area coperta da quelle strade (osm_geo.street_area).
# Non aggiorna manifest.json. Uso: python3 Tools/build_siena.py
import html, json, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/siena"
CHECKED = "2026-10-24T12:00:00Z"
EVERY_DAY = [1, 2, 3, 4, 5, 6, 7]

PERSONS = "https://www.comune.siena.it/servizi/accesso-ztl-persone-fisiche"
HOTELS = "https://www.comune.siena.it/servizi/accesso-ztl-strutture-ricettive"
RULES_PAGE = "https://www.comune.siena.it/documento-pubblico/disciplinare-il-rilascio-dei-permessi-di-accesso-e-circolazione-zona-traffico"
RULES_PDF = "https://www.comune.siena.it/sites/default/files/2026-05/disciplinare__allegato%20A_1_d.pdf"
TARIFFS_PDF = "https://www.comune.siena.it/sites/default/files/2025-09/Tabella%20Tariffe_%20GC_327_2025.pdf"
MAP_PDF = "https://www.comune.siena.it/sites/default/files/2025-06/Mappa%20ZTL%20con%20Varchi.pdf"
OSM_ZTL = 4081506   # relazione OSM «ZTL Siena» (enforcement=access, strade «section» e varchi «device»)
ZONES_AY_PDF = "https://www.comune.siena.it/sites/default/files/2025-03/Planimetria%20Y%20storica%20ampliata%20%281%29.pdf"


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


def source(page, quote, translation, links, pending, ordinance=None, ordinance_url=None):
    """translation e pending: (inglese, tedesco) e (inglese, italiano, tedesco), come in build_cities.py"""
    return {"authority": "City of Siena", "pageURL": page, "ordinance": ordinance, "ordinanceURL": ordinance_url,
            "quote": quote, "quoteTranslation": translation[0], "quoteTranslation_de": translation[1],
            "checkedOn": CHECKED, "reviewedByHuman": False,
            "pending": [p[0] for p in pending], "pending_it": [p[1] for p in pending], "pending_de": [p[2] for p in pending],
            "links": links}


def flat(text):
    """Testo senza a capo e spazi doppi, per cercare le citazioni"""
    return re.sub(r"\s+", " ", text).strip()


def page_text(name):
    t = (RAW / name).read_text(encoding="utf-8")
    t = re.sub(r"<(script|style)[^>]*>.*?</\1>", " ", t, flags=re.S)
    return flat(html.unescape(re.sub(r"<[^>]+>", " ", t)))


def must_contain(text, quote, where):
    """Ogni frase citata o riassunta deve esserci davvero nel documento salvato"""
    if flat(quote) not in text:
        raise SystemExit(f"Citazione non trovata in {where}: {quote!r}")


# Le frasi su cui si basa la scheda, controllate contro i file in data/raw/siena/
rules = flat((RAW / "disciplinare_GC_177_2026.txt").read_text(encoding="utf-8"))
tariffs = flat((RAW / "tariffe_GC_327_2025.txt").read_text(encoding="utf-8"))
persons = page_text("accesso-ztl-persone-fisiche.html")
hotels = page_text("accesso-ztl-strutture-ricettive.html")
QUOTE = "ha validità tutti i giorni nell’orario 0/24 e l’ingresso, la circolazione e la sosta sono vietati ai veicoli non autorizzati"
for q in ["Deliberazione Giunta comunale n. 177 del 19/05/2026", QUOTE,
          "La Zona Y storica è transitabile solo nella fascia oraria 6.00/10.00.",
          "La Zona A è transitabile solo nelle fasce orarie 6.00/10.00 e 15.30/17.00.",
          "I veicoli elettrici non sono autorizzati ad accedere alla Ztl per effettuare la sola ricarica.",
          "É consentito l'inserimento dati per n. 2 soli accessi al giorno con permanenza massima di 45 minuti per ciascun accesso.",
          "non è consentita oltre 2 giorni successivi dalla data del transito."]:
    must_contain(rules, q, "disciplinare GC 177/2026")
for q in ["30 minuti gratuito - max n. 4 al mese", "1 ora 5€", "1 giorno 10 €"]:
    must_contain(tariffs, q, "tariffe GC 327/2025")
for q in ["accompagnamento di anziani ultrasettantenni", "accompagnamento di minori di anni sei",
          "5 € 1 ora 10 € 1 giorno 20 € 2 giorni 20 € 3 giorni", "Pagina aggiornata il 09/10/2026"]:
    must_contain(persons, q, "pagina Persone fisiche")
for q in ["entro 2 giorni lavorativi successivi al transito", "per massimo 2 volte al giorno",
          "Pagina aggiornata il 20/05/2026"]:
    must_contain(hotels, q, "pagina Strutture ricettive")


def perimeter():
    """Da un file di coordinate verificato, se c'è; altrimenti dalle strade della relazione OSM (mai disegnato a mano)"""
    f = RAW / "ztl_perimetro.geojson"
    if not f.exists():
        return osm_geo.perimeter(osm_geo.street_area(osm_geo.relation(osm_geo.load("siena-ztl"), OSM_ZTL)), tol_m=8), True
    g = json.loads(f.read_text())
    g = g["features"][0]["geometry"] if "features" in g else g
    polys = [g["coordinates"]] if g["type"] == "Polygon" else g["coordinates"]
    outer = max((p[0] for p in polys), key=len)
    return [{"lat": round(p[1], 6), "lon": round(p[0], 6)} for p in outer], False


def gates():
    f = RAW / "varchi.geojson"
    if not f.exists():   # le telecamere («device») della relazione OSM, con il loro nome
        return [osm_geo.gate_json("si", g) for g in osm_geo.gates(osm_geo.load("siena-gates"), {OSM_ZTL}, name_prefix=None)]
    return [{"id": f"si-{i}", "name": v["properties"]["name"],
             "location": {"lat": round(v["geometry"]["coordinates"][1], 6), "lon": round(v["geometry"]["coordinates"][0], 6)}}
            for i, v in enumerate(json.loads(f.read_text())["features"], 1) if v.get("geometry")]


links = [link("City of Siena: ZTL access for private persons (permits and prices)",
              "Comune di Siena: accesso ZTL per persone fisiche (permessi e tariffe)",
              "Stadt Siena: ZTL-Zufahrt für Privatpersonen (Genehmigungen und Preise)", PERSONS),
         link("City of Siena: ZTL access for hotel guests", "Comune di Siena: accesso ZTL per strutture ricettive",
              "Stadt Siena: ZTL-Zufahrt für Hotelgäste", HOTELS),
         link("City of Siena: ZTL permit rules (Council decision 177/2026)",
              "Comune di Siena: disciplinare permessi ZTL (delibera GC 177/2026)",
              "Stadt Siena: Regeln für ZTL-Genehmigungen (Beschluss 177/2026)", RULES_PAGE),
         link("City of Siena: ZTL prices", "Comune di Siena: tariffe ZTL", "Stadt Siena: ZTL-Tarife", TARIFFS_PDF),
         link("City of Siena: map of the ZTL with gates (PDF)", "Comune di Siena: mappa ZTL con varchi (PDF)",
              "Stadt Siena: Karte der ZTL mit Kameras (PDF)", MAP_PDF),
         link("City of Siena: map of Zona A and Zona Y storica (PDF)", "Comune di Siena: mappa Zona A e Zona Y storica (PDF)",
              "Stadt Siena: Karte von Zona A und Zona Y storica (PDF)", ZONES_AY_PDF)]

shape, from_osm = perimeter()
pending = []
if from_osm:
    links.append(link(f"OpenStreetMap: relation {OSM_ZTL} (ZTL streets and gates, ODbL)",
                      f"OpenStreetMap: relazione {OSM_ZTL} (strade e varchi della ZTL, ODbL)",
                      f"OpenStreetMap: Relation {OSM_ZTL} (ZTL-Straßen und Kameras, ODbL)", osm_geo.osm_url("relation", OSM_ZTL)))
    pending.append(("Perimeter from OpenStreetMap, to be checked against the official map. It is drawn around the streets mapped as ZTL, so the edge is approximate.",
                    "Perimetro da OpenStreetMap, da verificare con la mappa ufficiale. È tracciato attorno alle strade segnate come ZTL, quindi il bordo è approssimato.",
                    "Grenze aus OpenStreetMap, mit der offiziellen Karte abzugleichen. Sie umfasst die als ZTL erfassten Straßen, der Rand ist daher ungefähr."))
if not shape:
    pending.append(("Map outline and cameras still missing: Siena publishes no open data and its official map is a PDF without coordinates. Until they are added, GateLR can't tell whether a point is inside the ZTL: check the official map.",
                    "Mancano ancora perimetro e varchi: Siena non pubblica dati aperti e la mappa ufficiale è un PDF senza coordinate. Finché non ci sono, GateLR non sa dire se un punto è dentro la ZTL: guarda la mappa ufficiale.",
                    "Grenze und Kameras fehlen noch: Siena veröffentlicht keine offenen Daten, und die offizielle Karte ist ein PDF ohne Koordinaten. Bis dahin kann GateLR nicht sagen, ob ein Punkt in der ZTL liegt: siehe offizielle Karte."))
pending += [
    ("Inside the ZTL, Zona Y storica (open only 6–10 am) and Zona A (6–10 am and 3:30–5 pm) are stricter even with a permit; they are not drawn on the map yet.",
     "Dentro la ZTL, la Zona Y storica (solo 6–10) e la Zona A (6–10 e 15:30–17) sono più restrittive anche con il permesso; non sono ancora disegnate sulla mappa.",
     "Innerhalb der ZTL sind Zona Y storica (nur 6–10 Uhr) und Zona A (6–10 und 15:30–17 Uhr) auch mit Genehmigung strenger; sie sind noch nicht auf der Karte eingezeichnet."),
    ("Hotel deadline: the city's page says within 2 working days after entry, the 2026 rules say no later than 2 days after. To be confirmed with the city.",
     "Scadenza per l'hotel: la pagina del Comune dice entro 2 giorni lavorativi dal transito, il disciplinare 2026 non oltre 2 giorni successivi. Da confermare con il Comune.",
     "Frist für das Hotel: Die Seite der Stadt nennt 2 Werktage nach der Einfahrt, die Regeln von 2026 höchstens 2 Tage danach. Mit der Stadt zu klären."),
]

zone = {"id": "siena-ztl", "name": "ZTL · Historic Centre", "name_it": "ZTL · Centro storico", "name_de": "ZTL · Altstadt",
        "kind": "restricted",
        "summary": "Closed to unauthorised vehicles 24 hours a day, every day, holidays included. There is no tourist day pass: short permits are only for specific needs (heavy items, passengers over 70 or under 6, pets to the vet). If your hotel is inside, it can register your plate for luggage only: max 45 minutes, twice a day.",
        "summary_it": "Chiusa ai veicoli non autorizzati 24 ore su 24, tutti i giorni, festivi compresi. Non c'è un ticket per i turisti: i permessi brevi valgono solo per motivi precisi (oggetti pesanti, passeggeri sopra i 70 o sotto i 6 anni, animali dal veterinario). Se l'hotel è dentro, può registrare la targa solo per i bagagli: massimo 45 minuti, due volte al giorno.",
        "summary_de": "Rund um die Uhr, täglich und auch an Feiertagen für nicht berechtigte Fahrzeuge gesperrt. Es gibt kein Tagesticket für Touristen: kurze Genehmigungen nur für bestimmte Zwecke (schwere Gegenstände, Mitfahrer über 70 oder unter 6, Tiere zum Tierarzt). Liegt dein Hotel innen, kann es dein Kennzeichen nur fürs Gepäck melden: höchstens 45 Minuten, zweimal am Tag.",
        "perimeter": shape, "gates": sorted(gates(), key=lambda g: g["name"]),
        "windows": [{"weekdays": EVERY_DAY, "start": 0, "end": 24 * 60}],
        "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": True,
        "source": source(RULES_PAGE, QUOTE,
                         ("valid every day, 0–24, and entry, driving and parking are forbidden to unauthorised vehicles",
                          "gilt täglich von 0 bis 24 Uhr; Einfahrt, Fahren und Parken sind für nicht berechtigte Fahrzeuge verboten"),
                         links, pending, "Deliberazione GC n. 177 del 19/05/2026 (Disciplinare ZTL)", RULES_PDF)}

city = {"id": "siena", "name": "Siena", "name_it": "Siena", "name_de": "Siena",
        "center": {"lat": 43.3184, "lon": 11.3316}, "zones": [zone], "status": "draft",
        "license": "Rules: Comune di Siena official pages and documents. "
                   + ("Perimeter and gates: " + osm_geo.ODBL + " (approximate, not official)." if from_osm else "Perimeter and gates: Comune di Siena.")}

# Senza perimetro l'app non può dire se un punto è dentro: finché manca, la città resta tra le bozze (data/drafts)
ready = all(len(z["perimeter"]) >= 4 for z in city["zones"])
out = ROOT / ("Resources/Cities/siena.json" if ready else "data/drafts/siena.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("Resources/Cities/siena.json" if not ready else "data/drafts/siena.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.name, [(z["id"], len(z["perimeter"]), len(z["gates"])) for z in city["zones"]])
