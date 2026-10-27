#!/usr/bin/env python3
# Costruisce la scheda di Vicenza dalle pagine ufficiali salvate in data/raw/vicenza/ (URL e data di lettura in testa a ogni
# file; fonti e date in docs/fonti-vicenza.md).
#
# Regole (27/10/2026): pagina «ZTL, zona a traffico limitato: informazioni generali» (telecamere ai varchi 24 ore su 24,
# tranne corso Fogazzaro; accesso solo con permesso o per le categorie dell'ordinanza 3474/95), pagine dei permessi
# (tipologie, temporanei: nessun permesso per i visitatori), comunicato del 12/12/2025 (12 telecamere ai varchi di uscita
# entro il 2026, regole invariate), mappa ufficiale «Mappa ZTL con varchi» (14/11/2023).
#
# Geometria (mai disegnata a mano): nessun open data (dati.veneto.it e dati.gov.it non hanno la ZTL; in OpenStreetMap non
# c'è né una relazione né strade segnate). Perimetro e varchi vengono dalla mappa ufficiale agganciata alle coordinate da
# Tools/vicenza_mappa.py (fiumi della mappa sovrapposti alle acque OSM) → data/raw/vicenza/ztl-mappa-ufficiale.geojson.
# I nomi dei varchi sono quelli della legenda della mappa; ogni pallino è abbinato alla strada OSM più vicina, che deve
# essere quella del varco ufficiale.
# Uso: python3 Tools/vicenza_mappa.py && python3 Tools/build_vicenza.py   (non tocca le altre città né manifest.json)
import json, math, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/vicenza"
CHECKED = "2026-10-27T14:00:00Z"
EVERY_DAY = [1, 2, 3, 4, 5, 6, 7]


def flat(s):
    return re.sub(r"\s+([,.;:)])", r"\1", re.sub(r"\s+", " ", s)).strip()


TEXT = {p.stem: flat(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def url_of(file):
    return TEXT[file].split(" ", 2)[1]


def check(file, *phrases):
    """Ogni frase citata o riassunta deve comparire, parola per parola, nel testo salvato"""
    for q in phrases:
        if flat(q) not in TEXT[file]:
            raise SystemExit(f"{file}: frase non trovata, ricontrollare il testo: {q!r}")


INFO_F, TYPES_F, TEMP_F, NEWS_F, MAP_F = ("comune-ztl-informazioni-generali", "comune-permessi-tipologie", "comune-permessi-temporanei",
                                          "comune-comunicato-telecamere-uscita-2025-12-12", "comune-mappa-ztl-con-varchi")
INFO, TYPES, TEMP, NEWS, MAP = map(url_of, (INFO_F, TYPES_F, TEMP_F, NEWS_F, MAP_F))

QUOTE = ("Le telecamere registrano tutti gli accessi dei veicoli 24 ore su 24, tranne che per il varco di corso Fogazzaro (varco "
         "CHIUSO, con rilevazione dei transiti non autorizzati, dalle 20 alle 9 nei giorni feriali e 0-24 nei giorni festivi).")
CAMERAS = ["Piazzale de Gasperi - Porta Castello", "Via Montagna", "Contra' Pedemuro San Biagio", "Corso Fogazzaro", "Contra' Porti",
           "Contra' Gazzolle", "Contra' Carpagnon", "Stradella Santo Stefano", "Contra' San Faustino"]
check(INFO_F, QUOTE, "Se i veicoli fotografati non sono autorizzati, scatta automaticamente la sanzione.",
      "Per accedere in ZTL è necessario che l'originale del permesso sia esposto sul cruscotto.",
      "ordinanza n. 3474/95", "La ZTL esiste a Vicenza dal 1996", "Ultimo aggiornamento: 17/07/2024", *CAMERAS)
check(TYPES_F, "Permesso per residenti (colore rosa)", "Il permesso riporta l’indicazione dei varchi ZTL autorizzati per l’entrata e per l’uscita dalla ZTL/AP.")
check(TEMP_F, "Vicenza Logistic City Center Srl", "i veicoli per trasporto di cose e merci non devono superare la massa complessiva a pieno carico di 3.500 kilogrammi")
check(NEWS_F, "12 telecamere ai varchi di uscita", "si prevede che le telecamere saranno installate entro il 2026",
      "senza modificare le norme di accesso già in vigore", "Ultimo aggiornamento: 12/12/2025")
OFFICIAL_ENTRY = {1: "PIAZZALE DE GASPERI", 2: "VIA MONTAGNA", 3: "CORSO FOGAZZARO", 4: "CONTRA' PEDEMURO S. BIAGIO", 5: "CONTRA' PORTI",
                  6: "STRADELLA S. STEFANO", 7: "CONTRA' SAN FAUSTINO", 8: "CONTRA' GAZZOLLE", 9: "CONTRA' CARPAGNON", 10: "CONTRA' MURE CARMINI"}
check(MAP_F, "Mappa ZTL con varchi Data: 14/11/2023", "; ".join(f"{k} {v}" for k, v in OFFICIAL_ENTRY.items()))
# strada OSM su cui sta ciascun varco d'ingresso (Piazzale De Gasperi è all'imbocco di Corso Palladio, Via Montagna di
# contrà Bartolomeo Montagna)
OSM_OF = {1: ("Piazzale Alcide De Gasperi", "Corso Andrea Palladio"), 2: ("Via Bartolomeo Montagna", "Contra' Bartolomeo Montagna"),
          3: ("Corso Antonio Fogazzaro",), 4: ("Contra' Pedemuro San Biagio",), 5: ("Contra' Porti",), 6: ("Stradella Santo Stefano",),
          7: ("Contra' San Faustino",), 8: ("Contra' delle Gazzolle",), 9: ("Contra' Carpagnon",), 10: ("Contra' Mure Carmini",)}

GEO = osm_geo.load("vicenza-centro")
STREETS = [e for e in GEO if e["type"] == "way" and "highway" in e.get("tags", {}) and e.get("geometry")]
MAPPED = json.loads((RAW / "ztl-mappa-ufficiale.geojson").read_text(encoding="utf-8"))
assert MAPPED["transform"]["rivers_f1"] >= 0.8, MAPPED["transform"]


def seg_dist(lat, lon, a, b):
    k = math.cos(math.radians(lat))
    ax, ay = (a["lon"] - lon) * 111320 * k, (a["lat"] - lat) * 110574
    bx, by = (b["lon"] - lon) * 111320 * k, (b["lat"] - lat) * 110574
    dx, dy = bx - ax, by - ay
    t = 0 if dx == dy == 0 else max(0, min(1, -(ax * dx + ay * dy) / (dx * dx + dy * dy)))
    return math.hypot(ax + t * dx, ay + t * dy)


def street_dist(lat, lon, names):
    ds = [seg_dist(lat, lon, a, b) for w in STREETS if w["tags"]["name"] in names for a, b in zip(w["geometry"], w["geometry"][1:])]
    return min(ds) if ds else float("inf")


ring = MAPPED["features"][0]["geometry"]["coordinates"][0]
shape = osm_geo.perimeter([tuple(p) for p in ring], tol_m=3)
dots = [f for f in MAPPED["features"][1:] if "entry" in f["properties"]["kinds"]]
gates = []
for n, label in OFFICIAL_ENTRY.items():
    best = min(dots, key=lambda f: street_dist(f["geometry"]["coordinates"][1], f["geometry"]["coordinates"][0], OSM_OF[n]))
    lon, lat = best["geometry"]["coordinates"]
    d = street_dist(lat, lon, OSM_OF[n])
    if d > 25:
        raise SystemExit(f"varco {n} {label}: nessun pallino d'ingresso entro 25 m dalla strada ({d:.0f} m)")
    name = label.title().replace("Contra'", "Contrà")
    gates.append({"id": f"vi-varco-{n:02d}", "name": f"Varco {n} · {name}" + (" (20–9; festivi 0–24)" if n == 3 else ""),
                  "location": {"lat": round(lat, 6), "lon": round(lon, 6)}})


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


LINKS = [link("City of Vicenza: ZTL general information (cameras, hours)", "Comune di Vicenza: ZTL, informazioni generali (telecamere, orari)",
              "Stadt Vicenza: ZTL, allgemeine Informationen (Kameras, Zeiten)", INFO),
         link("Official map of the ZTL and its gates", "Mappa ufficiale della ZTL con i varchi", "Offizielle Karte der ZTL mit den Kameras", MAP),
         link("City of Vicenza: ZTL permit types", "Comune di Vicenza: tipologie di permessi ZTL", "Stadt Vicenza: Arten von ZTL-Genehmigungen", TYPES),
         link("City of Vicenza: temporary ZTL permits", "Comune di Vicenza: permessi temporanei ZTL", "Stadt Vicenza: befristete ZTL-Genehmigungen", TEMP),
         link("City of Vicenza: exit cameras by 2026 (press release, 12/12/2025)", "Comune di Vicenza: telecamere ai varchi di uscita entro il 2026 (comunicato del 12/12/2025)",
              "Stadt Vicenza: Ausfahrtkameras bis 2026 (Pressemitteilung, 12.12.2025)", NEWS)]

PENDING = [
    ("Corso Fogazzaro gate: the City's Italian page says it is closed and enforced 20:00–9:00 on weekdays and all day on holidays (open to all 9:00–20:00 on weekdays); GateLR still treats the whole zone as closed 0–24. The City's English page, not reachable from here, is reported to describe it the other way round.",
     "Varco di corso Fogazzaro: la pagina del Comune lo dà chiuso e controllato 20–9 nei feriali e 0–24 nei festivi (aperto a tutti 9–20 nei feriali); GateLR tratta comunque tutta la zona come chiusa 0–24. La pagina inglese del Comune, non raggiungibile da qui, lo descriverebbe al contrario.",
     "Kamera Corso Fogazzaro: Laut der italienischen Seite der Stadt ist sie werktags 20–9 Uhr und an Feiertagen ganztägig geschlossen und überwacht (werktags 9–20 Uhr frei); GateLR behandelt die ganze Zone trotzdem als 0–24 gesperrt. Die englische Seite der Stadt (hier nicht erreichbar) soll es umgekehrt beschreiben."),
    ("Hotel guests: the City's pages describe no procedure for hotels to register guests' plates and no visitor permit (temporary permits are only for goods, building sites and markets). Ask your hotel before driving in; otherwise park outside.",
     "Ospiti degli hotel: le pagine del Comune non descrivono una procedura per far registrare la targa dall'hotel né un permesso per visitatori (i temporanei sono solo per merci, cantieri e mercati). Chiedi all'hotel prima di entrare; altrimenti parcheggia fuori.",
     "Hotelgäste: Die Seiten der Stadt beschreiben weder eine Kennzeichenmeldung durch Hotels noch eine Besuchergenehmigung (befristete Genehmigungen nur für Waren, Baustellen und Märkte). Frag dein Hotel vor der Einfahrt; sonst außerhalb parken."),
    ("Exit gates: the official map shows 20 exit points; permits list the allowed entry and exit gates. 12 exit cameras are due by the end of 2026 (City press release, 12/12/2025). The City's page lists 9 entry cameras; the map shows a 10th entry at Contrà Mure Carmini.",
     "Varchi di uscita: la mappa ufficiale ne indica 20; i permessi riportano i varchi di entrata e di uscita consentiti. 12 telecamere in uscita sono previste entro il 2026 (comunicato del 12/12/2025). La pagina del Comune elenca 9 telecamere d'ingresso; la mappa indica un 10° ingresso in contrà Mure Carmini.",
     "Ausfahrten: Die offizielle Karte zeigt 20 Ausfahrtpunkte; Genehmigungen nennen die erlaubten Ein- und Ausfahrten. 12 Ausfahrtkameras sollen bis Ende 2026 kommen (Pressemitteilung vom 12.12.2025). Die Seite der Stadt nennt 9 Einfahrtkameras; die Karte zeigt eine 10. Einfahrt an der Contrà Mure Carmini."),
    ("Perimeter traced automatically from the official map (2023), georeferenced on the OpenStreetMap rivers: accurate to roughly 10–20 m. Pedestrian areas (AP) inside the ZTL are not drawn. Electric cars are not exempt; disabled badge holders need the City's permit.",
     "Perimetro ricavato in automatico dalla mappa ufficiale (2023), agganciata ai fiumi di OpenStreetMap: precisione di circa 10–20 m. Le aree pedonali (AP) dentro la ZTL non sono disegnate. Auto elettriche non esenti; i titolari di contrassegno disabili seguono le regole del Comune.",
     "Grenze automatisch aus der offiziellen Karte (2023) abgeleitet und an den OpenStreetMap-Flüssen ausgerichtet: Genauigkeit etwa 10–20 m. Fußgängerzonen (AP) in der ZTL sind nicht eingezeichnet. Elektroautos sind nicht befreit; Inhaber eines Behindertenausweises folgen den Regeln der Stadt."),
]

zone = {"id": "vicenza-ztl", "name": "Centro storico · Old town ZTL", "name_it": "Centro storico · ZTL", "name_de": "Centro storico · ZTL Altstadt",
        "kind": "restricted",
        "summary": "The old town (Piazza dei Signori, Basilica Palladiana, Corso Palladio) is a limited traffic zone: cameras at the entry gates record every car 24 hours a day and fine those without a permit automatically. There is no permit for visitors: park outside the zone and walk in.",
        "summary_it": "Il centro storico (piazza dei Signori, Basilica Palladiana, corso Palladio) è ZTL: le telecamere ai varchi d'ingresso registrano ogni auto 24 ore su 24 e multano in automatico chi non ha il permesso. Non c'è un permesso per i visitatori: parcheggia fuori e prosegui a piedi.",
        "summary_de": "Die Altstadt (Piazza dei Signori, Basilica Palladiana, Corso Palladio) ist eine ZTL: Kameras an den Einfahrten erfassen jedes Auto rund um die Uhr und verhängen ohne Genehmigung automatisch ein Bußgeld. Eine Besuchergenehmigung gibt es nicht: außerhalb parken und zu Fuß gehen.",
        "perimeter": shape, "gates": gates,
        "windows": [{"weekdays": EVERY_DAY, "start": 0, "end": 24 * 60}],
        "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": False,
        "source": {"authority": "City of Vicenza", "pageURL": INFO,
                   "ordinance": "Ordinanza PGN 3474/95 e successive integrazioni",
                   "ordinanceURL": None,
                   "quote": QUOTE,
                   "quoteTranslation": "The cameras record every vehicle entering 24 hours a day, except at the Corso Fogazzaro gate (gate CLOSED, with detection of unauthorised transits, from 8 pm to 9 am on weekdays and all day on holidays).",
                   "quoteTranslation_de": "Die Kameras erfassen alle einfahrenden Fahrzeuge rund um die Uhr, außer an der Einfahrt Corso Fogazzaro (Einfahrt GESCHLOSSEN, mit Erfassung unerlaubter Durchfahrten, werktags von 20 bis 9 Uhr und an Feiertagen ganztägig).",
                   "checkedOn": CHECKED, "reviewedByHuman": False,
                   "pending": [p[0] for p in PENDING], "pending_it": [p[1] for p in PENDING], "pending_de": [p[2] for p in PENDING],
                   "links": LINKS}}
zone["source"] = {k: v for k, v in zone["source"].items() if v is not None}

city = {"id": "vicenza", "name": "Vicenza", "name_it": "Vicenza", "name_de": "Vicenza",
        "center": {"lat": 45.5473, "lon": 11.5465}, "zones": [zone], "status": "draft",
        "license": "Rules and perimeter: Comune di Vicenza official pages and ZTL map (georeferenced on " + osm_geo.ODBL + "; approximate)."}

# Controlli di plausibilità (coordinate dalle strade OSM): piazza dei Signori e piazza delle Erbe dentro;
# piazzale della Stazione, viale Roma e viale Eretenio fuori; i varchi entro 30 m dal bordo
for n, lat, lon in [("Piazza dei Signori", 45.54729, 11.54648), ("Piazza delle Erbe", 45.54667, 11.54699)]:
    assert osm_geo.contains(shape, lat, lon), f"{n} fuori dal perimetro"
for n, lat, lon in [("Piazzale della Stazione", 45.54191, 11.54048), ("Viale Roma", 45.5433, 11.54054), ("Viale Eretenio", 45.54185, 11.54584)]:
    assert not osm_geo.contains(shape, lat, lon), f"{n} dentro il perimetro"
for g in gates:
    assert osm_geo.distance_m(shape, g["location"]["lat"], g["location"]["lon"]) < 30, g
assert 0.3 < osm_geo.area_km2(shape) < 0.5, osm_geo.area_km2(shape)

ready = all(len(z["perimeter"]) >= 5 and z["source"].get("quote") for z in city["zones"])
out = ROOT / ("Resources/Cities/vicenza.json" if ready else "data/drafts/vicenza.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/vicenza.json" if ready else "Resources/Cities/vicenza.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), [(z["id"], len(z["perimeter"]), len(z["gates"])) for z in city["zones"]], f"area {osm_geo.area_km2(shape):.2f} km²")
