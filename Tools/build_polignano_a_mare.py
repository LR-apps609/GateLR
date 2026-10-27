#!/usr/bin/env python3
# Costruisce la scheda di Polignano a Mare (fonti e date in docs/fonti-polignano-a-mare.md). Ogni frase citata o riassunta
# viene ricontrollata sul testo salvato in data/raw/polignano-a-mare/.
#
# FONTE NON UFFICIALE. Il sito del Comune ha solo la pagina «ZTL» dell'argomento Trasporto pubblico e l'informativa privacy
# sulla «Gestione ZTL», senza orari né mappa. Con l'approvazione del titolare, orari, varco e confini vengono da
# accessibilitacentristorici.it (sito privato di servizi per i permessi), che riporta e allega l'ordinanza n. 207 del 2018
# (prot. 16681, albo PAP-00966-2018: area pedonale urbana «tra l'Arco Marchesale e Piazza Santa Maria delle Grazie inclusa,
# sino a via Tritone incrocio con via Narciso», permanente, 24 ore; D.G.C. 45/2017 e 56/2018). L'ordinanza non è stata
# trovata sul sito del Comune: la copia è quella del sito non ufficiale, quindi la zona resta source.official = false con
# source.unofficialSource (app 1.16.2; manifest «unofficialCities», nascosta alle app fino alla 1.16.1).
#
# Geometria (© OpenStreetMap contributors, ODbL 1.0; API OSM con Tools/fetch_osm_api.py, ridotto in
# data/raw/geo/polignano-a-mare-ztl.json; la mappa del sito non ufficiale NON è usata): OSM non ha un'area ZTL/APU.
# L'area è quella coperta (osm_geo.street_area) dalle strade OSM del borgo antico comprese tra l'Arco Marchesale e piazza
# Santa Maria delle Grazie (le due estremità nominate dall'ordinanza): tutte le strade a nord della linea che unisce i due
# luoghi (con 33 m di margine verso sud, per comprendere i vicoli sul bordo meridionale del borgo e via Santa Maria delle
# Grazie), tra le loro longitudini; escluse via Muraglia e le strade fuori dal borgo; più via Tritone fino a via Narciso.
# Varco: l'Arco Marchesale.
# Uso: python3 Tools/build_polignano_a_mare.py   (non tocca le altre città né manifest.json)
import json, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/polignano-a-mare"
CHECKED = "2026-10-27T17:00:00Z"
ALL = [1, 2, 3, 4, 5, 6, 7]

COMUNE = "https://www.comune.polignanoamare.ba.it/Argomenti/Trasporto-pubblico/ZTL"
PRIVACY = "https://www.comune.polignanoamare.ba.it/Privacy/Informativa-Privacy-in-materia-di-protezione-dei-dati-personali-per-la-Gestione-ZTL-Zone-a-Traffico-Limitato"
ACS = "https://www.accessibilitacentristorici.it/ztl/puglia/polignano-a-mare.html"
ORD = "https://www.accessibilitacentristorici.it/ufficiali/ordinanze/Polignano_a_mare_ordinanza_PAP-00966-2018.pdf"
UNOFFICIAL = {"name": "accessibilitacentristorici.it", "url": ACS}


def flat(s):
    return re.sub(r"\s+", " ", s).strip()


TEXT = {p.stem: flat(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def check(file, *phrases):
    for q in phrases:
        if flat(q) not in TEXT[file]:
            raise SystemExit(f"{file}: frase non trovata: {q!r}")


QUOTE = "L'APU di Polignano a Mare è attiva tutti i giorni 24 ore su 24 ore ."
check("accessibilitacentristorici-polignano", QUOTE,
      "E' stata istituita a Polignano a Mare un'area Pedonale (APU) nell'area compresa tra l'Arco Marchesale e Piazza Santa Maria delle Grazie inclusa, sino a via Tritone incrocio con via Narciso.",
      "posto in corrispondenza dell' Arco Marchesale",
      "Il divieto al transito nella APU di Polignano a Mare è valido per ogni tipologia di veicolo e pertanto ciclomotori e motoveicoli non possono eccedere se non espressamente autorizzati.",
      "Non risulta la possibilità di autorizzare l'accesso all'APU ai clienti di strutture recettive poste all'interno dell' area pedonale di Polignano a Mare per effettuare le operazioni di carico e scarico.",
      "Se sei entrato nella APU di Polignano a Mare senza autorizzazione non risulta la possibilità di sanare la propria posizione.",
      "Data aggiornamento: 04/10/2018")
check("ordinanza-207-2018", "ORDINANZA N° 207", "DISCIPLINA DELL’AREA PEDONALE URBANA CENTRO STORICO- ACCESSO VARCO ELETTRONICO",
      "CHE detta area pedonale è di durata permanente ovvero dal 1° gennaio al 31 dicembre di ogni anno per l’intero arco delle 24 ore giornaliere;",
      "Sono ammesse alla circolazione all’interno dell’APU delimitata tra l’Arco Marchesale fino a Piazza Santa Maria delle Grazie, incluso il tratto di via Tritone fino all’intersezione di Via Narciso i seguenti veicoli",
      "Sarà consentito il transito solo nei giorni feriali, fatta salva diversa disciplina in occasione di manifestazioni e/o eventi, comunque previo accreditamento dell’utente presso il Comando di Polizia Locale.",
      "affisso all'Albo Pretorio on-line dal 14/05/2018 al 29/05/2018")

# --- geometria ---
GEO = osm_geo.load("polignano-a-mare-ztl")
ways = {e["id"]: e for e in GEO if e["type"] == "way"}
for wid, name in ((166622037, "Arco Marchesale"), (103204028, "Piazza Santa Maria delle Grazie"), (58523641, "Via Tritone")):
    if ways[wid]["tags"].get("name") != name:
        raise SystemExit(f"Way {wid} non è più {name}")


def centroid(wid):
    g = ways[wid]["geometry"]
    return sum(p["lat"] for p in g) / len(g), sum(p["lon"] for p in g) / len(g)


ARCO, GRAZIE = centroid(166622037), centroid(103204028)
MARGIN = 0.00030     # ~33 m verso sud
EXCLUDE = {"Via Muraglia", "Piazza Giuseppe Garibaldi", "Via Martiri di Dogali", "Lama Monachile", "Ponte Lama Monachile",
           "Via Ranuncolo", "Via Roma", "Via Narciso"}


def in_old_town(p):
    t = (p["lon"] - ARCO[1]) / (GRAZIE[1] - ARCO[1])
    return (p["lat"] > ARCO[0] + t * (GRAZIE[0] - ARCO[0]) - MARGIN and ARCO[1] - 0.0002 <= p["lon"] <= GRAZIE[1] + 0.0001
            and p["lat"] < 40.9985)


sel = sorted(w for w, e in ways.items() if e["tags"].get("highway") and e["tags"].get("name") not in EXCLUDE
             and all(in_old_town(p) for p in e["geometry"])) + [58523641]
rel = {"id": 0, "members": [{"type": "way", "role": "section", "geometry": ways[w]["geometry"]} for w in sel]}
shape = osm_geo.perimeter(osm_geo.street_area(rel, cell_m=5, close_m=25), tol_m=3)
area = osm_geo.area_km2([(p["lon"], p["lat"]) for p in shape])
if not 0.012 < area < 0.04:
    raise SystemExit(f"Area non plausibile: {area:.3f} km²")
# Controlli: piazza Vittorio Emanuele II, Chiesa Matrice, Torre dell'Orologio, piazza Santa Maria delle Grazie dentro;
# piazza Garibaldi, piazza Aldo Moro, Lama Monachile, via Narciso più a sud fuori
for name, lat, lon, inside in [("Piazza Vittorio Emanuele II", 40.99628, 17.21935, True), ("Chiesa Matrice", 40.99629, 17.21954, True),
                               ("Torre dell'Orologio", 40.99634, 17.21892, True), ("Piazza Santa Maria delle Grazie", 40.99587, 17.22079, True),
                               ("Piazza Garibaldi", 40.99531, 17.21898, False), ("Piazza Aldo Moro", 40.99456, 17.21942, False),
                               ("Lama Monachile", 40.9951, 17.2175, False), ("Via Narciso (sud)", 40.99405, 17.22146, False)]:
    if osm_geo.contains(shape, lat, lon) != inside:
        raise SystemExit(f"Controllo perimetro fallito: {name} dovrebbe essere {'dentro' if inside else 'fuori'}")
GATE = {"id": "pm-osm-way166622037", "name": "Varco Arco Marchesale", "location": {"lat": round(ARCO[0], 6), "lon": round(ARCO[1], 6)}}
if osm_geo.distance_m(shape, ARCO[0], ARCO[1]) > 40 and not osm_geo.contains(shape, ARCO[0], ARCO[1]):
    raise SystemExit("Varco lontano dalla zona")


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


LINKS = [link("accessibilitacentristorici.it: Polignano a Mare ZTL (unofficial)", "accessibilitacentristorici.it: ZTL di Polignano a Mare (non ufficiale)", "accessibilitacentristorici.it: ZTL Polignano a Mare (inoffiziell)", ACS),
         link("Ordinance no. 207/2018 on the pedestrian area (copy on accessibilitacentristorici.it, PDF)", "Ordinanza n. 207/2018 sull'area pedonale (copia su accessibilitacentristorici.it, PDF)", "Verordnung Nr. 207/2018 zur Fußgängerzone (Kopie auf accessibilitacentristorici.it, PDF)", ORD),
         link("City of Polignano a Mare: ZTL page", "Comune di Polignano a Mare: pagina ZTL", "Stadt Polignano a Mare: ZTL-Seite", COMUNE),
         link("OpenStreetMap: Arco Marchesale (ODbL)", "OpenStreetMap: Arco Marchesale (ODbL)", "OpenStreetMap: Arco Marchesale (ODbL)", osm_geo.osm_url("way", 166622037))]

PEND = [
    ("Confirmed only by accessibilitacentristorici.it (a private permit-service site, page updated 04/10/2018), which also hosts a copy of the City's ordinance no. 207 of 2018 (pedestrian area 24 hours a day, all year). The City's website has a ZTL page and a privacy notice for the ZTL cameras, but no hours, map or current ordinance.",
     "Confermato solo da accessibilitacentristorici.it (sito privato di servizi per i permessi, pagina aggiornata il 04/10/2018), che ospita anche una copia dell'ordinanza del Comune n. 207 del 2018 (area pedonale 24 ore su 24, tutto l'anno). Il sito del Comune ha una pagina ZTL e l'informativa privacy sulle telecamere, ma né orari né mappa né ordinanza vigente.",
     "Nur von accessibilitacentristorici.it bestätigt (private Website für Genehmigungsdienste, Seite aktualisiert am 04.10.2018), die auch eine Kopie der städtischen Verordnung Nr. 207 von 2018 bereitstellt (Fußgängerzone rund um die Uhr, ganzjährig). Die Website der Stadt hat eine ZTL-Seite und einen Datenschutzhinweis zu den Kameras, aber weder Zeiten noch Karte noch geltende Verordnung."),
    ("Hotel guests: no access for hotels inside the pedestrian area according to the same site; ask your accommodation or the Municipal Police before driving in. Blue Badge holders: weekdays only, after registering plate and badge with the Municipal Police. Motorbikes and mopeds banned too. Entering without a permit cannot be regularised afterwards.",
     "Ospiti degli hotel: secondo lo stesso sito le strutture dentro l'area pedonale non possono far entrare i clienti; chiedi alla struttura o alla Polizia Locale prima di entrare. Disabili: solo nei giorni feriali, dopo aver registrato targa e contrassegno alla Polizia Locale. Vietato anche a moto e ciclomotori. Chi entra senza permesso non può sanare dopo.",
     "Hotelgäste: laut gleicher Website keine Zufahrt für Unterkünfte in der Fußgängerzone; frag vor der Einfahrt deine Unterkunft oder die Stadtpolizei. Inhaber eines Behindertenausweises: nur werktags, nach Registrierung von Kennzeichen und Ausweis bei der Stadtpolizei. Auch Motorräder und Mopeds verboten. Unerlaubte Einfahrt lässt sich nachträglich nicht regeln."),
    ("Area drawn from the OpenStreetMap streets of the old town between Arco Marchesale and Piazza Santa Maria delle Grazie, plus Via Tritone up to Via Narciso (the limits named in the ordinance); no official map is published.",
     "Area ricavata dalle strade OpenStreetMap del borgo antico tra l'Arco Marchesale e piazza Santa Maria delle Grazie, più via Tritone fino a via Narciso (i limiti dell'ordinanza); nessuna mappa ufficiale pubblicata.",
     "Fläche aus den OpenStreetMap-Straßen der Altstadt zwischen Arco Marchesale und Piazza Santa Maria delle Grazie, plus Via Tritone bis Via Narciso (die Grenzen der Verordnung); keine offizielle Karte veröffentlicht."),
]

zones = [{
    "id": "polignano-a-mare-centro", "name": "Old town · pedestrian area", "name_it": "Borgo antico · area pedonale", "name_de": "Altstadt · Fußgängerzone",
    "kind": "restricted",
    "summary": "The old town of Polignano a Mare (through the Arco Marchesale gate, from Piazza Vittorio Emanuele to Piazza Santa Maria delle Grazie and Via Tritone up to Via Narciso) is a pedestrian area closed to cars and motorbikes 24 hours a day, every day. Camera at the Arco Marchesale. Park outside and walk in. Rules from an unofficial site.",
    "summary_it": "Il borgo antico di Polignano a Mare (dall'Arco Marchesale, da piazza Vittorio Emanuele a piazza Santa Maria delle Grazie e via Tritone fino a via Narciso) è area pedonale chiusa ad auto e moto 24 ore su 24, tutti i giorni. Telecamera all'Arco Marchesale. Parcheggia fuori ed entra a piedi. Regole da un sito non ufficiale.",
    "summary_de": "Die Altstadt von Polignano a Mare (durch das Arco Marchesale, von der Piazza Vittorio Emanuele bis zur Piazza Santa Maria delle Grazie und Via Tritone bis Via Narciso) ist eine Fußgängerzone, rund um die Uhr und täglich für Autos und Motorräder gesperrt. Kamera am Arco Marchesale. Draußen parken und zu Fuß hinein. Regeln von einer inoffiziellen Website.",
    "perimeter": shape, "gates": [GATE],
    "windows": [{"weekdays": ALL, "start": 0, "end": 1440}],
    "freeOnHolidays": False, "holidaysAsSunday": False, "exemptFuels": [], "hotelCanRegister": False,
    "source": {"authority": "City of Polignano a Mare", "pageURL": COMUNE,
               "ordinance": "Ordinanza n. 207 del 2018 (prot. 16681), D.G.C. n. 45/2017 e n. 56/2018 — copia sul sito non ufficiale",
               "ordinanceURL": ORD, "quote": QUOTE,
               "quoteTranslation": "The pedestrian area of Polignano a Mare is active every day, 24 hours a day.",
               "quoteTranslation_de": "Die Fußgängerzone von Polignano a Mare ist täglich rund um die Uhr aktiv.",
               "checkedOn": CHECKED, "reviewedByHuman": False,
               "pending": [p[0] for p in PEND], "pending_it": [p[1] for p in PEND], "pending_de": [p[2] for p in PEND],
               "links": LINKS, "official": False, "unofficialSource": UNOFFICIAL}}]

city = {"id": "polignano-a-mare", "name": "Polignano a Mare", "name_it": "Polignano a Mare", "name_de": "Polignano a Mare",
        "center": {"lat": 40.9960, "lon": 17.2195}, "zones": zones, "status": "draft",
        "license": "Rules: accessibilitacentristorici.it (unofficial) and its copy of the City's ordinance 207/2018. Area and gate: " + osm_geo.ODBL + " (approximate, not official)."}

ready = all(len(z["perimeter"]) >= 5 and z["source"]["quote"] and z["source"]["official"] is False for z in zones)
out = ROOT / ("Resources/Cities/polignano-a-mare.json" if ready else "data/drafts/polignano-a-mare.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/polignano-a-mare.json" if ready else "Resources/Cities/polignano-a-mare.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), len(shape), f"{area:.3f} km²", len(sel), "strade")
