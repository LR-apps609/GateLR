#!/usr/bin/env python3
# Costruisce la scheda di Bolzano/Bozen (BOZZA) da quanto salvato in data/raw/bolzano/ (fonti e date in docs/fonti-bolzano.md).
#
# Regole: il 27/10/2026 i siti del Comune (www.comune.bolzano.bz.it, www.gemeinde.bozen.bz.it, opencity.gemeinde.bozen.it)
# erano bloccati dal proxy del sandbox (403): niente testo ufficiale salvato, quindi NESSUNA citazione verificata. Le regole
# vengono dai riassunti della ricerca web delle pagine ufficiali (guida «Accesso ZTL e sosta nel centro abitato», comunicato
# «Neue Park- und Verkehrsregeln für die Altstadt» del 2023, servizio della Stadtpolizei), salvati in data/raw/bolzano/
# websearch-*.txt. Per questo la scheda resta in data/drafts/bolzano.json: per pubblicarla serve il testo delle pagine del
# Comune (salvarlo in data/raw/bolzano/ e mettere la citazione in QUOTE).
#
# Geometria: relazione OpenStreetMap 19584710 «Zona Traffico Limitato Centro storico / Verkehrsberuhigte Zone Altstadt»
# (boundary=limited_traffic_zone; le sue 52 way sono le strade della ZTL, non un contorno chiuso: il perimetro è l'area
# coperta da quelle strade; 13 telecamere «device»), scaricata con Tools/fetch_osm_api.py il
# 27/10/2026 (data/raw/geo/bolzano-ztl.json, © OpenStreetMap contributors, ODbL 1.0). Il Comune non pubblica il perimetro
# in open data (dati.retecivica.bz.it: nessun dataset ZTL).
# Uso: python3 Tools/build_bolzano.py   (non tocca le altre città né manifest.json)
import json, math, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/bolzano"
CHECKED = "2026-10-27T11:30:00Z"
EVERY_DAY = [1, 2, 3, 4, 5, 6, 7]


def flat(s):
    return re.sub(r"\s+", " ", s).strip()


TEXT = {p.stem: flat(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def check(file, *phrases):
    """Ogni regola riassunta deve comparire, parola per parola, nel testo salvato"""
    for q in phrases:
        if flat(q) not in TEXT[file]:
            raise SystemExit(f"{file}: frase non trovata: {q!r}")


def url_of(file):
    return TEXT[file].split(" ", 2)[1]


GUIDE_F, PRESS_F, PERMIT_F = "websearch-1-guida-comune-ztl", "websearch-2-nuove-regole-2023", "websearch-3-permesso-stadtpolizei"
GUIDE, PRESS, PERMIT = map(url_of, (GUIDE_F, PRESS_F, PERMIT_F))
check(GUIDE_F, "La ZTL del centro storico di Bolzano è attiva 24 ore su 24, tutti i giorni.",
      "Se il vostro albergo si trova nella ZTL, contattatelo in anticipo per comunicare la vostra targa e ottenere l'autorizzazione temporanea al passaggio.",
      "dal lunedì al sabato, dalle 6:00 alle 10:30, esclusi i festivi infrasettimanali", "NON è il testo verificato della pagina")
check(PRESS_F, "Am 1. Februar 2023 tritt eine neue Park- und Verkehrsregelung für die verkehrsberuhigte Zone in Kraft.",
      "Erbsengasse, Waaggasse, Pfarrgasse", "Obstplatz, Museumstraße und ein Teil der Laubengasse von 10.30 bis 20 Uhr")
check(PERMIT_F, "Die Genehmigung muss vor der Einfahrt in die verkehrsberuhigte Zone (VBZ) oder in die Fußgängerzone von der Stadtpolizei ausgestellt werden.")
QUOTE = None   # nessun testo ufficiale salvato (sito del Comune bloccato dal proxy)


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


LINKS = [link("City of Bolzano: ZTL access and parking guide", "Comune di Bolzano: guida accesso ZTL e sosta nel centro abitato",
              "Stadt Bozen: Leitfaden Zufahrt verkehrsberuhigte Zone und Parken", GUIDE),
         link("City of Bolzano (municipal police): permit to enter the ZTL and pedestrian zone", "Comune di Bolzano (Polizia Municipale): permesso di accesso a ZTL e area pedonale",
              "Stadt Bozen (Stadtpolizei): Genehmigung für die Einfahrt in die VBZ und die Fußgängerzone", PERMIT),
         link("City of Bolzano: new old-town traffic rules from 1 February 2023", "Comune di Bolzano: nuove regole per il centro storico dal 1° febbraio 2023",
              "Stadt Bozen: neue Park- und Verkehrsregeln für die Altstadt ab 1. Februar 2023", PRESS),
         link("OpenStreetMap: ZTL relation used for the map", "OpenStreetMap: relazione della ZTL usata per la mappa",
              "OpenStreetMap: ZTL-Relation für die Karte", osm_geo.osm_url("relation", 19584710))]

PENDING = [
    ("Rules confirmed only by web-search summaries of the City's pages (24 hours a day, every day; hotel registers your plate in advance): the City's website could not be read directly. Check before you go.",
     "Regole confermate solo dai riassunti della ricerca web delle pagine del Comune (24 ore su 24, tutti i giorni; l'albergo registra la targa in anticipo): il sito del Comune non era leggibile direttamente. Verifica prima di partire.",
     "Regeln nur durch Zusammenfassungen einer Websuche zu den Seiten der Stadt bestätigt (rund um die Uhr, jeden Tag; das Hotel meldet dein Kennzeichen vorab): die Website der Stadt war nicht direkt lesbar. Vor der Fahrt prüfen."),
    ("Hotel inside the zone: contact it before arriving and give your plate; it obtains the temporary authorisation. Older guides mention reporting plate, date and time to the municipal police within 48 hours: confirmed only by accessibilitacentristorici.it and a 2014 article (fss.bz.it).",
     "Albergo dentro la zona: contattalo prima di arrivare e comunica la targa; ottiene lui l'autorizzazione temporanea. Guide più vecchie parlano di comunicare targa, data e ora alla Polizia Municipale entro 48 ore: confermato solo da accessibilitacentristorici.it e da un articolo del 2014 (fss.bz.it).",
     "Hotel in der Zone: vor der Ankunft kontaktieren und das Kennzeichen mitteilen; das Hotel besorgt die vorübergehende Genehmigung. Ältere Ratgeber nennen eine Meldung von Kennzeichen, Datum und Uhrzeit an die Stadtpolizei innerhalb von 48 Stunden: nur durch accessibilitacentristorici.it und einen Artikel von 2014 (fss.bz.it) bestätigt."),
    ("No day ticket for visitors. Deliveries up to 3.5 t Monday–Saturday 6:00–10:30 (not on weekday holidays); electric, hybrid and hydrogen delivery vans also until 11:00 and 14:30–16:00. Private electric cars are not exempt.",
     "Nessun biglietto giornaliero per i visitatori. Carico e scarico fino a 3,5 t lunedì–sabato 6–10:30 (non nei festivi infrasettimanali); furgoni elettrici, ibridi e a idrogeno anche fino alle 11 e 14:30–16. Le auto elettriche private non sono esenti.",
     "Kein Tagesticket für Besucher. Lieferverkehr bis 3,5 t Montag–Samstag 6–10:30 Uhr (nicht an Wochenfeiertagen); Elektro-, Hybrid- und Wasserstoff-Lieferwagen zusätzlich bis 11 Uhr und 14:30–16 Uhr. Private Elektroautos sind nicht befreit."),
    ("Even with a permit: no through traffic in Erbsengasse/Via Argentieri, Waaggasse/Via della Pesa, Pfarrgasse/Via della Parrocchia and part of Waltherplatz/Piazza Walther; Obstplatz/Piazza Erbe, Museumstraße/Via Museo and part of Laubengasse/Via Portici closed 10:30–20:00.",
     "Anche con permesso: niente transito in via Argentieri/Erbsengasse, via della Pesa/Waaggasse, via della Parrocchia/Pfarrgasse e parte di piazza Walther/Waltherplatz; piazza Erbe/Obstplatz, via Museo/Museumstraße e parte di via Portici/Laubengasse chiuse 10:30–20.",
     "Auch mit Genehmigung: kein Durchgangsverkehr in Erbsengasse/Via Argentieri, Waaggasse/Via della Pesa, Pfarrgasse/Via della Parrocchia und einem Teil des Waltherplatzes/Piazza Walther; Obstplatz/Piazza Erbe, Museumstraße/Via Museo und ein Teil der Laubengasse/Via Portici 10:30–20 Uhr gesperrt."),
    ("Perimeter and cameras from OpenStreetMap (not official). Fine for entering without authorisation: about 80 € according to unofficial guides.",
     "Perimetro e telecamere da OpenStreetMap (non ufficiali). Multa per l'accesso senza autorizzazione: circa 80 € secondo guide non ufficiali.",
     "Grenze und Kameras aus OpenStreetMap (nicht offiziell). Bußgeld bei Einfahrt ohne Genehmigung: laut inoffiziellen Ratgebern etwa 80 €."),
]

GEO = json.loads((ROOT / "data/raw/geo/bolzano-ztl.json").read_text(encoding="utf-8"))["elements"]
REL = osm_geo.relation(GEO, 19584710)
STREETS = [e for e in GEO if e["type"] == "way" and e.get("tags", {}).get("name")]
# le way della relazione (33 «outer» e 19 senza ruolo) sono le strade della ZTL, non un contorno chiuso: il perimetro è
# l'area coperta da quelle strade (osm_geo.street_area, chiusura 60 m), come per le relazioni «enforcement» di altre città
SECTIONS = {"id": REL["id"], "members": [{"type": "way", "role": "section", "geometry": m["geometry"]} for m in REL["members"] if m["type"] == "way" and m.get("geometry")]}
perimeter = osm_geo.perimeter(osm_geo.street_area(SECTIONS, close_m=60), tol_m=4)


def street_of(lat, lon):
    """La strada OSM con nome più vicina alla telecamera (nome bilingue «italiano - deutsch» come a Bolzano)"""
    best = min((math.hypot((p["lat"] - lat) * 111000, (p["lon"] - lon) * 76500), w["tags"]["name"]) for w in STREETS for p in w["geometry"])
    return best[1].replace(" - ", " / ")


gates = []
for osm_id, _, lat, lon in osm_geo.gates(GEO, relation_ids={19584710}, name_prefix=None):
    gates.append({"id": f"bz-osm{osm_id}", "name": street_of(lat, lon), "location": {"lat": round(lat, 6), "lon": round(lon, 6)}})
gates.sort(key=lambda g: g["name"])

zone = {"id": "bolzano-ztl", "name": "Old town · ZTL 24 hours", "name_it": "Centro storico · ZTL 0–24",
        "name_de": "Altstadt · Verkehrsberuhigte Zone rund um die Uhr", "kind": "restricted",
        "summary": "The old town of Bolzano (Piazza Walther, Via Portici, Piazza Erbe) is closed to cars without authorisation 24 hours a day, every day; cameras at the entrances read plates. There is no day ticket: if your hotel is inside, contact it before arriving and give your plate. Otherwise park outside (e.g. Parkhaus Bozen Mitte, Piazza Walther underground car park).",
        "summary_it": "Il centro storico di Bolzano (piazza Walther, via Portici, piazza Erbe) è chiuso alle auto senza autorizzazione 24 ore su 24, tutti i giorni; le telecamere agli accessi leggono le targhe. Non c'è un biglietto giornaliero: se l'albergo è dentro, contattalo prima di arrivare e comunica la targa. Altrimenti parcheggia fuori (es. garage Bolzano Centro, parcheggio interrato di piazza Walther).",
        "summary_de": "Die Bozner Altstadt (Waltherplatz, Laubengasse, Obstplatz) ist rund um die Uhr, jeden Tag, für Autos ohne Genehmigung gesperrt; Kameras an den Zufahrten lesen die Kennzeichen. Ein Tagesticket gibt es nicht: Liegt dein Hotel in der Zone, kontaktiere es vor der Ankunft und teile dein Kennzeichen mit. Sonst außerhalb parken (z. B. Parkhaus Bozen Mitte, Tiefgarage Waltherplatz).",
        "perimeter": perimeter, "gates": gates,
        "windows": [{"weekdays": EVERY_DAY, "start": 0, "end": 24 * 60}],
        "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": True,
        "source": {"authority": "City of Bolzano", "pageURL": GUIDE,
                   "ordinance": "Regolamentazione della ZTL del centro storico in vigore dal 01/02/2023 (testo non letto: sito del Comune non raggiungibile)",
                   "ordinanceURL": PRESS,
                   "quote": QUOTE, "quoteTranslation": None, "quoteTranslation_de": None,
                   "checkedOn": CHECKED, "reviewedByHuman": False,
                   "pending": [p[0] for p in PENDING], "pending_it": [p[1] for p in PENDING], "pending_de": [p[2] for p in PENDING],
                   "links": LINKS}}

city = {"id": "bolzano", "name": "Bolzano", "name_it": "Bolzano", "name_de": "Bozen",
        "center": {"lat": 46.4983, "lon": 11.3548}, "zones": [zone], "status": "draft",
        "license": "Rules: summaries of Comune di Bolzano / Stadtgemeinde Bozen pages (not verified). Perimeter and cameras: " + osm_geo.ODBL + " (relation 19584710, not official)."}

# Controlli: piazza Walther e piazza Erbe dentro, la stazione fuori, le telecamere vicino al bordo
for n, lat, lon in [("Piazza Walther / Waltherplatz", 46.4983, 11.3548), ("Piazza Erbe / Obstplatz", 46.4998, 11.3527)]:
    assert osm_geo.contains(perimeter, lat, lon), f"{n} fuori dal perimetro"
assert not osm_geo.contains(perimeter, 46.4967, 11.3580), "stazione di Bolzano dentro il perimetro"
for g in gates:
    assert osm_geo.distance_m(perimeter, g["location"]["lat"], g["location"]["lon"]) < 80, g
assert 0.1 < osm_geo.area_km2(perimeter) < 0.6, osm_geo.area_km2(perimeter)

ready = all(len(z["perimeter"]) >= 5 and z["source"]["quote"] for z in city["zones"])
out = ROOT / ("Resources/Cities/bolzano.json" if ready else "data/drafts/bolzano.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/bolzano.json" if ready else "Resources/Cities/bolzano.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), len(perimeter), [g["name"] for g in gates], round(osm_geo.area_km2(perimeter), 3))
