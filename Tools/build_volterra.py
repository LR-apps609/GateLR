#!/usr/bin/env python3
# Costruisce Resources/Cities/volterra.json dalle pagine ufficiali del Comune di Volterra salvate in data/raw/volterra/
# (fonti e date in docs/fonti-volterra.md). Ogni frase usata viene ricontrollata sul testo salvato.
#
# Regole: pagina ufficiale «Z.T.L. Zona a traffico limitato – informazioni e servizi» (agg. 17/03/2026, citazione):
#   dal 2 novembre al 20 marzo 10:00–17:30, dal 21 marzo al 1 novembre 10:00–20:00; avviso del 18/03/2026 (stesso orario
#   estivo 2026) e avviso del 12/12/2025 (proroga per il festivo del 14/12: la ZTL è attiva anche nei festivi).
#   Accesso temporaneo: e-mail a ztl@comune.volterra.pi.it (al massimo 15 accessi per anno solare).
# Geometria: OpenStreetMap (© OpenStreetMap contributors, ODbL 1.0; API OSM, data/raw/geo/volterra-centro.json).
#   La mappa e la delibera allegate dal Comune sono su static-www.comune.volterra.pi.it, bloccato dal proxy (403): niente
#   perimetro ufficiale. Il Comune nomina come varchi le porte delle mura (Porta San Francesco e Porta a Selci in ingresso;
#   Porta Fiorentina, Piazza Martiri della Libertà e Porta all'Arco in uscita); accessibilitacentristorici.it (non ufficiale)
#   dice che la ZTL «comprende tutta l'area del centro storico compresa dentro le mura».
#   Area = le 5 way OSM delle mura (barrier=city_wall) unite testa-coda; i 2 vuoti della mappatura (279 m lungo la Fortezza
#   / carcere, 47 m in piazza Martiri della Libertà) sono chiusi con un segmento tra le estremità; poi si toglie l'inviluppo
#   convesso del terminal bus, del parcheggio sotterraneo «La Dogana» e della rotatoria di piazza Martiri (strade senza
#   divieti in OSM: il Comune dice che il terminal bus è accessibile H24 e la piazza è un'uscita della ZTL).
#   Varchi: i nodi OSM delle porte (historic=city_gate).
# Uso: python3 Tools/build_volterra.py   (non tocca le altre città né manifest.json)
import json, math, re
from pathlib import Path
from shapely.geometry import Polygon, MultiPoint
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/volterra"
CHECKED = "2026-10-27T16:30:00Z"
ALL = [1, 2, 3, 4, 5, 6, 7]

B = "https://www.comune.volterra.pi.it"
INFO = B + "/articolo_tematico/z-t-l-zona-a-traffico-limitato-informazioni-e-servizi/"
NEWS_2026 = B + "/novita/variazioni-ztl/"
NEWS_XMAS = B + "/novita/divieto-di-transito-e-proroga-orario-ztl/"
NEWS_PERMITS = B + "/novita/rinnovo-permessi-ztl/"
UNOFFICIAL = "https://www.accessibilitacentristorici.it/ztl/toscana/volterra.html"


def flat(s):
    return re.sub(r"\s+", " ", s).strip()


TEXT = {p.stem: flat(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def check(file, *phrases):
    for q in phrases:
        if flat(q) not in TEXT[file]:
            raise SystemExit(f"{file}: frase non trovata, ricontrollare il documento: {q!r}")


QUOTE = ("Orario Z.T.L. INVERNALE: Nel periodo che va dal 2 novembre al 20 marzo, la ZTL sarà attiva dalle ore 10:00 alle ore 17:30. "
         "Orario Z.T.L. ESTIVO: Nel periodo che va dal 21 marzo al 1 novembre, la ZTL sarà attiva dalle ore 10:00 alle ore 20:00.")
check("comune-ztl-informazioni-e-servizi", QUOTE,
      "ztl@comune.volterra.pi.it", "(Si possono richiedere un massimo 15 accessi temporanei ad anno solare)",
      "DATA E ORARIO, NOMINATIVO, TARGA, MOTIVAZIONE, VIA/PIAZZA DI ACCESSO",
      "DATA DI ACCESSO, NOMINATIVO, COMUNE DI RILASCIO DEL TAGLIANDO, NUMERO DEL TAGLIANDO, TARGA.",
      "Varchi di accesso consentiti: Porta San Francesco.", "Porta Fiorentina, Piazza Martiri della Libertà, Porta all’ Arco.",
      "Varchi di accesso consentiti: Porta a Selci.",
      "L’accesso al terminal dei bus turistici che è posto in Piazza Martiri della Libertà è consentito H 24",
      "Ultimo aggiornamento: 17/03/2026")
check("comune-2026-03-18-variazioni-ztl", "a partire da Sabato 21 marzo 2026, fino a Lunedì 1 novembre 2026, la ZTL sarà attiva dalle ore 10:00 alle ore 20:00")
check("comune-2025-12-12-proroga-orario-festivo", "limitatamente al giorno festivo sopra indicato, viene estesa dall’orario attualmente previsto delle ore 17:30 FINO alle ore 20:00")
check("comune-2025-10-30-orario-invernale", "varchi attivi dalle 10:00 alle 17:30")
check("comune-2025-12-04-rinnovo-permessi", "anche i ciclomotori 50cc (cinquantini)")
check("comune-2025-06-06-varchi-elezioni", "ZTL di San Francesco", "Il varco di Porta a Selci")
check("accessibilitacentristorici-volterra", "comprende tutta l'area del centro storico compresa dentro le mura",
      "Porta Fiorentina", "numero verde: 800 865 635")

# --- geometria: mura OSM ---
GEO = osm_geo.load("volterra-centro")
W = {e["id"]: e for e in GEO if e["type"] == "way"}
WALLS = [355037914, 362804601, 372662738, 367415836, 348733219]     # in ordine lungo il circuito
for wid in WALLS:
    if W[wid].get("tags", {}).get("barrier") != "city_wall":
        raise SystemExit(f"La way {wid} non è più un tratto di mura: ricontrollare")
if {e["id"] for e in W.values() if e.get("tags", {}).get("barrier") == "city_wall"} != set(WALLS):
    raise SystemExit("I tratti di mura in OSM sono cambiati: ricontrollare")
KX, KY = 111320 * math.cos(math.radians(43.4)), 110574


def dist(a, b):
    return math.hypot((a[0] - b[0]) * KX, (a[1] - b[1]) * KY)


ring, gaps = [], []
for wid in WALLS:
    seg = [(p["lon"], p["lat"]) for p in W[wid]["geometry"]]
    if ring:
        if dist(ring[-1], seg[-1]) < dist(ring[-1], seg[0]):
            seg = seg[::-1]
        gaps.append(round(dist(ring[-1], seg[0])))
    ring += seg
gaps.append(round(dist(ring[-1], ring[0])))
if sorted(gaps)[-2:] != [47, 279] or sum(gaps) > 330:
    raise SystemExit(f"Vuoti tra i tratti di mura cambiati: {gaps}")
EXCLUDE = [362868720, 336681257, 362813456, 362868718]  # terminal bus, parcheggio «La Dogana», rotatoria e piazza Martiri
pts = [(p["lon"], p["lat"]) for wid in EXCLUDE for p in W[wid]["geometry"]]
area_poly = Polygon(ring + [ring[0]]).difference(MultiPoint(pts).convex_hull)
if area_poly.geom_type != "Polygon":
    raise SystemExit("L'area non è più un solo poligono")
shape = osm_geo.perimeter([list(c) for c in area_poly.exterior.coords], tol_m=3)
area = osm_geo.area_km2(shape)
if not 0.2 < area < 0.3:
    raise SystemExit(f"Area della ZTL non plausibile: {area:.3f} km²")
for name, lat, lon, inside in [("Piazza dei Priori", 43.40115, 10.86035, True), ("Duomo", 43.4006, 10.8597, True),
                               ("Via Matteotti", 43.4019, 10.8618, True),
                               ("Parcheggio La Dogana (sotterraneo)", 43.40067, 10.85923, False),
                               ("Parcheggio La Stazione", 43.39904, 10.86962, False), ("Parcheggio Docciola", 43.40327, 10.86371, False),
                               ("Teatro romano (fuori dalle mura)", 43.4040, 10.8590, False), ("Ospedale", 43.3995, 10.8735, False)]:
    if osm_geo.contains(shape, lat, lon) != inside:
        raise SystemExit(f"Controllo perimetro fallito: {name} dovrebbe essere {'dentro' if inside else 'fuori'}")

nodes = {e["id"]: e for e in GEO if e["type"] == "node"}
GATES = [(937863921, "Porta San Francesco", "Porta San Francesco · entry", "Porta San Francesco · ingresso", "Porta San Francesco · Einfahrt"),
         (471087421, "Porta a Selci", "Porta a Selci · entry", "Porta a Selci · ingresso", "Porta a Selci · Einfahrt"),
         (471087415, "Porta Fiorentina", "Porta Fiorentina · exit", "Porta Fiorentina · uscita", "Porta Fiorentina · Ausfahrt")]
gate_list = []
for nid, osm_name, en, it, de in GATES:
    n = nodes[nid]
    if n.get("tags", {}).get("name") != osm_name:
        raise SystemExit(f"Il nodo {nid} non è più {osm_name}")
    if osm_geo.distance_m(shape, n["lat"], n["lon"]) > 30:
        raise SystemExit(f"Varco lontano dal bordo: {osm_name}")
    g = osm_geo.gate_json("vt", (nid, "Varco " + it, n["lat"], n["lon"]))
    gate_list.append(g)


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


LINKS = [link("City of Volterra: ZTL information and services (hours)", "Comune di Volterra: Z.T.L. informazioni e servizi (orari)", "Stadt Volterra: ZTL-Informationen und Dienste (Zeiten)", INFO),
         link("City of Volterra: summer hours 2026 (notice of 18 March 2026)", "Comune di Volterra: orario estivo 2026 (avviso del 18/03/2026)", "Stadt Volterra: Sommerzeiten 2026 (Mitteilung vom 18.03.2026)", NEWS_2026),
         link("City of Volterra: ZTL also active on public holidays (notice of 12 December 2025)", "Comune di Volterra: ZTL attiva anche nei festivi (avviso del 12/12/2025)", "Stadt Volterra: ZTL auch an Feiertagen aktiv (Mitteilung vom 12.12.2025)", NEWS_XMAS),
         link("City of Volterra: permits 2026, mopeds need a permit from 1 April 2026", "Comune di Volterra: permessi 2026, ciclomotori con permesso dal 1° aprile 2026", "Stadt Volterra: Genehmigungen 2026, Mopeds ab 1. April 2026 mit Genehmigung", NEWS_PERMITS),
         link("Accessibilità Centri Storici: Volterra (unofficial)", "Accessibilità Centri Storici: Volterra (non ufficiale)", "Accessibilità Centri Storici: Volterra (inoffiziell)", UNOFFICIAL),
         link("OpenStreetMap: town walls of Volterra (ODbL)", "OpenStreetMap: mura di Volterra (ODbL)", "OpenStreetMap: Stadtmauer von Volterra (ODbL)", osm_geo.osm_url("way", WALLS[0]))]

PENDING = [
    ("Visitors and hotel guests: the City's page has no hotel procedure. Anyone can ask for a temporary access by e-mail to ztl@comune.volterra.pi.it, giving date and time, name, plate, reason and the gate/street of access (at most 15 temporary accesses per calendar year); the access is valid only once the authorisation is received. Hotels registering plates is confirmed only by tyremap.com: ask your hotel before you arrive.",
     "Visitatori e ospiti degli hotel: la pagina del Comune non indica una procedura per gli alberghi. Chiunque può chiedere un accesso temporaneo per e-mail a ztl@comune.volterra.pi.it indicando data e orario, nominativo, targa, motivazione e via/piazza di accesso (al massimo 15 accessi temporanei per anno solare); l'autorizzazione vale solo da quando è ricevuta. La registrazione della targa da parte degli hotel è confermata solo da tyremap.com: chiedi all'hotel prima di arrivare.",
     "Besucher und Hotelgäste: Die Seite der Stadt nennt kein Verfahren für Hotels. Jeder kann eine befristete Zufahrt per E-Mail an ztl@comune.volterra.pi.it beantragen, mit Datum und Uhrzeit, Name, Kennzeichen, Grund und Zufahrtsstraße (höchstens 15 befristete Zufahrten pro Kalenderjahr); sie gilt erst ab Erhalt der Genehmigung. Dass Hotels Kennzeichen melden, bestätigt nur tyremap.com: frag dein Hotel vor der Anreise."),
    ("Blue Badge holders send date, name, issuing town and number of the badge and plate to ztl@comune.volterra.pi.it. No exemption for electric cars is mentioned; from 1 April 2026 mopeds (50 cc) also need a permit. The free number 800 865 635 shown at the gates is confirmed only by accessibilitacentristorici.it. Fines not stated by the City.",
     "I titolari di contrassegno disabili inviano data, nominativo, comune di rilascio e numero del contrassegno e targa a ztl@comune.volterra.pi.it. Nessuna deroga per le auto elettriche è indicata; dal 1° aprile 2026 anche i ciclomotori 50 cc devono avere il permesso. Il numero verde 800 865 635 ai varchi è confermato solo da accessibilitacentristorici.it. Importo delle multe non indicato dal Comune.",
     "Inhaber eines Behindertenausweises senden Datum, Name, ausstellende Gemeinde und Nummer des Ausweises und Kennzeichen an ztl@comune.volterra.pi.it. Keine Ausnahme für Elektroautos genannt; ab 1. April 2026 brauchen auch Mopeds (50 cm³) eine Genehmigung. Die Gratisnummer 800 865 635 an den Kameras bestätigt nur accessibilitacentristorici.it. Bußgeldhöhe von der Stadt nicht angegeben."),
    ("Hours change by City notice: summer 2025 was 10 am–7 pm (then 10 pm from 15 July to 15 September 2025 on trial, Giunta resolution 162/2025), summer 2026 is 10 am–8 pm; the gates are sometimes switched off (elections, roadworks) or extended (events). A summer night ZTL (Fri–Sun 8:30 pm–1 am, 29 June–31 July 2026) is confirmed only by tyremap.com and is not in GateLR. Check the City's notices.",
     "Gli orari cambiano con gli avvisi del Comune: estate 2025 10–19 (poi fino alle 22 dal 15 luglio al 15 settembre 2025 in via sperimentale, delibera di Giunta 162/2025), estate 2026 10–20; i varchi a volte sono spenti (elezioni, lavori) o prolungati (eventi). Una ZTL notturna estiva (ven–dom 20:30–1, 29 giugno–31 luglio 2026) è confermata solo da tyremap.com e non è in GateLR. Controlla gli avvisi del Comune.",
     "Die Zeiten ändern sich per Mitteilung der Stadt: Sommer 2025 10–19 Uhr (dann versuchsweise bis 22 Uhr vom 15. Juli bis 15. September 2025, Beschluss 162/2025), Sommer 2026 10–20 Uhr; die Kameras sind manchmal aus (Wahlen, Bauarbeiten) oder länger aktiv (Veranstaltungen). Eine nächtliche Sommer-ZTL (Fr–So 20:30–1 Uhr, 29. Juni–31. Juli 2026) bestätigt nur tyremap.com; sie ist nicht in GateLR. Mitteilungen der Stadt prüfen."),
    ("Area drawn from the town walls in OpenStreetMap (two unmapped stretches, along the Fortress/prison and at Piazza Martiri della Libertà, closed with a straight line): the City's map and resolution are on a server not reachable from here. That the ZTL is the whole old town inside the walls is confirmed only by accessibilitacentristorici.it; the City names the gates Porta San Francesco and Porta a Selci (entry) and Porta Fiorentina, Piazza Martiri della Libertà and Porta all'Arco (exit). The bus terminal and the underground car park «La Dogana» at Piazza Martiri are left outside.",
     "Area ricavata dalle mura in OpenStreetMap (due tratti non mappati, lungo la Fortezza/carcere e in piazza Martiri della Libertà, chiusi con un segmento): mappa e delibera del Comune sono su un server non raggiungibile da qui. Che la ZTL sia tutto il centro storico dentro le mura è confermato solo da accessibilitacentristorici.it; il Comune indica come varchi Porta San Francesco e Porta a Selci (ingresso) e Porta Fiorentina, piazza Martiri della Libertà e Porta all'Arco (uscita). Il terminal bus e il parcheggio sotterraneo «La Dogana» in piazza Martiri restano fuori.",
     "Fläche aus der Stadtmauer in OpenStreetMap (zwei nicht kartierte Abschnitte, an der Festung/dem Gefängnis und an der Piazza Martiri della Libertà, mit einer Geraden geschlossen): Karte und Beschluss der Stadt liegen auf einem von hier nicht erreichbaren Server. Dass die ZTL die ganze Altstadt innerhalb der Mauern ist, bestätigt nur accessibilitacentristorici.it; die Stadt nennt als Kameras Porta San Francesco und Porta a Selci (Einfahrt) sowie Porta Fiorentina, Piazza Martiri della Libertà und Porta all'Arco (Ausfahrt). Busterminal und Tiefgarage «La Dogana» an der Piazza Martiri bleiben draußen."),
]

SEASONS = [({"fromMonth": 3, "fromDay": 21, "toMonth": 11, "toDay": 1}, 10 * 60, 20 * 60),
           ({"fromMonth": 11, "fromDay": 2, "toMonth": 3, "toDay": 20}, 10 * 60, 17 * 60 + 30)]

zone = {"id": "volterra-centro", "name": "Old town · ZTL inside the walls", "name_it": "Centro storico · ZTL dentro le mura",
        "name_de": "Altstadt · ZTL innerhalb der Mauern", "kind": "restricted",
        "summary": "Volterra's old town inside the walls (Piazza dei Priori, the Duomo) is closed to cars without a permit every day, holidays included: 10 am–8 pm from 21 March to 1 November, 10 am–5:30 pm from 2 November to 20 March. Cameras at Porta San Francesco and Porta a Selci. Outside those hours you can drive in. Park outside the walls (e.g. La Dogana under Piazza Martiri, Docciola, La Stazione) and walk.",
        "summary_it": "Il centro storico di Volterra dentro le mura (piazza dei Priori, il Duomo) è chiuso alle auto senza permesso tutti i giorni, festivi compresi: 10–20 dal 21 marzo al 1° novembre, 10–17:30 dal 2 novembre al 20 marzo. Telecamere a Porta San Francesco e Porta a Selci. Fuori da questi orari si entra. Parcheggia fuori dalle mura (es. La Dogana sotto piazza Martiri, Docciola, La Stazione) e cammina.",
        "summary_de": "Die Altstadt von Volterra innerhalb der Mauern (Piazza dei Priori, Dom) ist für Autos ohne Genehmigung täglich gesperrt, auch an Feiertagen: 10–20 Uhr vom 21. März bis 1. November, 10–17:30 Uhr vom 2. November bis 20. März. Kameras an der Porta San Francesco und Porta a Selci. Außerhalb dieser Zeiten darfst du hinein. Vor den Mauern parken (z. B. La Dogana unter der Piazza Martiri, Docciola, La Stazione) und laufen.",
        "perimeter": shape, "gates": gate_list,
        "windows": [{"weekdays": ALL, "start": a, "end": b, "season": s} for s, a, b in SEASONS],
        "freeOnHolidays": False, "holidaysAsSunday": False, "exemptFuels": [], "hotelCanRegister": True,
        "source": {"authority": "City of Volterra", "pageURL": INFO, "quote": QUOTE,
                   "quoteTranslation": "Winter ZTL hours: from 2 November to 20 March the ZTL will be active from 10:00 to 17:30. Summer ZTL hours: from 21 March to 1 November the ZTL will be active from 10:00 to 20:00.",
                   "quoteTranslation_de": "Winterzeiten der ZTL: vom 2. November bis 20. März ist die ZTL von 10:00 bis 17:30 Uhr aktiv. Sommerzeiten der ZTL: vom 21. März bis 1. November ist die ZTL von 10:00 bis 20:00 Uhr aktiv.",
                   "checkedOn": CHECKED, "reviewedByHuman": False,
                   "pending": [p[0] for p in PENDING], "pending_it": [p[1] for p in PENDING], "pending_de": [p[2] for p in PENDING],
                   "links": LINKS}}

city = {"id": "volterra", "name": "Volterra", "name_it": "Volterra", "name_de": "Volterra",
        "center": {"lat": 43.4011, "lon": 10.8603}, "zones": [zone], "status": "draft",
        "license": "Rules: Comune di Volterra (official ZTL page and notices). Area and gates: " + osm_geo.ODBL + " (town walls, approximate, not official)."}

ready = all(len(z["perimeter"]) >= 5 and z["source"]["quote"] for z in city["zones"])
out = ROOT / ("Resources/Cities/volterra.json" if ready else "data/drafts/volterra.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/volterra.json" if ready else "Resources/Cities/volterra.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), [(z["id"], len(z["perimeter"]), len(z["gates"])) for z in city["zones"]], f"{area:.3f} km²", "vuoti", gaps)
