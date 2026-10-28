#!/usr/bin/env python3
# Costruisce Resources/Cities/firenze.json dai dati aperti del Comune di Firenze (CC-BY 4.0):
#   - perimetri ZTL diurna (settori A, B, O) e notturna estiva (anche F, G)
#   - porte telematiche (si tengono solo quelle dei settori ZTL, non corsie bus o aree pedonali)
# Gli orari vengono dalle pagine del Comune citate qui sotto, riassunti a mano.
#   - Scudo Verde (ZTL ambientale): varchi dai dati aperti del Comune, perimetro dalla relazione OSM 19205738
#     (ricalcata dal dataset PUMS «Scudo verde» della Città Metropolitana), file salvati in data/raw/scudo-verde/.
#     Fonti e verifiche: docs/fonti-scudo-verde.md
# Uso: python3 Tools/build_firenze.py   (serve accesso a datigis.comune.fi.it)
import json, math, re, urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path
from seasons import season

# Il disciplinare e la pagina ZTL di SAS (data/raw/firenze/, letti il 28/10/2026): le frasi usate qui sotto devono esserci
_RAW = Path(__file__).resolve().parent.parent / "data/raw/firenze"
_norm = lambda t: re.sub(r"\s+", " ", t)
for _f, _q in [("disciplinare-ztl.txt", "Nei settori A, B, O, F e G la ZTL avrà validità anche nel periodo dell’anno compreso tra il primo giovedì di aprile e la prima domenica di ottobre"),
               ("disciplinare-ztl.txt", "In deroga ai divieti di cui al punto 3, è consentito il transito su tutti i settori ZTL a:"),
               ("disciplinare-ztl.txt", "Ciclomotori a due ruote (categoria L1) e motocicli (categoria L3)"),
               ("sas-ztl.txt", "Dal primo giovedì di aprile alla prima domenica di ottobre (ZTL NOTTURNA ESTIVA"),
               ("sas-ztl-notturna-2026.txt", "da giovedì 2 aprile è attiva la ZTL notturna estiva che durerà fino a domenica 4 ottobre")]:
    if _norm(_q) not in _norm((_RAW / _f).read_text(encoding="utf-8")):
        raise SystemExit(f"{_f}: frase non trovata, ricontrollare la fonte: {_q!r}")

DIURNA = "https://datigis.comune.fi.it/json/ztl_diurna.json"
NOTTURNA = "https://datigis.comune.fi.it/json/ztl_notturna.json"
PORTE = "https://datigis.comune.fi.it/json/sas_porte_telematiche_od.json"
CHECKED = "2026-10-23T12:00:00Z"

OPEN_DATA = [
    {"title": "Open data: ZTL perimeter (day)", "title_it": "Dati aperti: perimetro ZTL (diurna)", "title_de": "Offene Daten: ZTL-Grenze (Tag)", "url": "https://opendata.comune.fi.it/page_dataset_show?id=9257a75e-3af3-4845-b37d-1540be29115a"},
    {"title": "Open data: ZTL gates (porte telematiche)", "title_it": "Dati aperti: porte telematiche ZTL", "title_de": "Offene Daten: ZTL-Kameratore", "url": "https://opendata.comune.fi.it/page_dataset_show?id=0fe68709-c864-4e21-b18e-07ee3e9328e2"},
]
DAY_HOURS = {
    "title": "City of Florence, 30 Sept 2020: back to the usual hours",
    "title_it": "Comune di Firenze, 30 settembre 2020: tornano gli orari di sempre",
    "title_de": "Stadt Florenz, 30. Sept. 2020: wieder die üblichen Zeiten",
    "url": "https://www.comune.firenze.it/novita/notizie/ztl-dal-1deg-ottobre-torna-lorario-pre-covid-tutte-le-porte-telematiche",
}
DAY_START = {
    "title": "City of Florence, 15 June 2019: ZTL rules revised",
    "title_it": "Comune di Firenze, 15 giugno 2019: revisione della disciplina ZTL",
    "title_de": "Stadt Florenz, 15. Juni 2019: ZTL-Regeln überarbeitet",
    "url": "https://www.comune.firenze.it/istruzione/novita/area-stampa/comunicati-stampa/ztl-da-martedi-entra-vigore-la-revisione-della-disciplina-di",
}
NIGHT_2026 = {
    "title": "City of Florence, 31 March 2026: summer night ZTL",
    "title_it": "Comune di Firenze, 31 marzo 2026: ZTL notturna estiva",
    "title_de": "Stadt Florenz, 31. März 2026: Sommer-Nacht-ZTL",
    "url": "https://www.comune.firenze.it/novita/area-stampa/comunicati-stampa/ztl-estiva-dal-primo-giovedi-di-aprile-torna-lo-stop-serale-2",
}

MON_FRI, SAT, THU_SAT = [2, 3, 4, 5, 6], [7], [5, 6, 7]
DAY_WINDOWS = [
    {"weekdays": MON_FRI, "start": 7 * 60 + 30, "end": 20 * 60},
    {"weekdays": SAT, "start": 7 * 60 + 30, "end": 16 * 60},
]
# Notti d'estate «dal primo giovedì di aprile alla prima domenica di ottobre» (disciplinare, punto 3), 23 → 3:
# nel 2026 dal 2 aprile al 4 ottobre, nel 2027 dal 1° aprile al 3 ottobre, nel 2028 dal 6 aprile al 1° ottobre.
# Regola dalla 1.17.1; per le app più vecchie date fisse larghe 1 aprile – 7 ottobre (Tools/seasons.py)
NIGHT_WINDOW = {"weekdays": THU_SAT, "start": 23 * 60, "end": 3 * 60,
                "season": season({"month": 4, "weekday": 5, "nth": 1}, {"month": 10, "weekday": 1, "nth": 1})}
DISCIPLINARE = {
    "title": "SAS: ZTL rules (disciplinare; summer nights in point 3, exempt two-wheelers in point 17)",
    "title_it": "SAS: disciplinare ZTL (notti d'estate al punto 3, due ruote esenti al punto 17)",
    "title_de": "SAS: ZTL-Regelwerk (Sommernächte in Punkt 3, befreite Zweiräder in Punkt 17)",
    "url": "https://www.serviziallastrada.it/disciplinari/ztl/Disciplinare_ZTL.pdf",
}
# «Veicoli esenti: … Ciclomotori a due ruote (categoria L1) e motocicli (categoria L3)» su tutti i settori (disciplinare, punto 17)
TWO_WHEELS = ["motorcycle"]

NAMES = {
    "A": "Sector A · Historic Centre",
    "B": "Sector B · Historic Centre",
    "O": "Sector O · Oltrarno",
    "F": "Sector F · San Niccolò (summer nights)",
    "G": "Sector G · Piazza Piave – Cavalleggeri (summer nights)",
}

NAMES_IT = {
    "A": "Settore A · Centro storico",
    "B": "Settore B · Centro storico",
    "O": "Settore O · Oltrarno",
    "F": "Settore F · San Niccolò (notti d'estate)",
    "G": "Settore G · Piazza Piave – Cavalleggeri (notti d'estate)",
}
NAMES_DE = {
    "A": "Sektor A · Altstadt",
    "B": "Sektor B · Altstadt",
    "O": "Sektor O · Oltrarno",
    "F": "Sektor F · San Niccolò (Sommernächte)",
    "G": "Sektor G · Piazza Piave – Cavalleggeri (Sommernächte)",
}

PENDING_COMMON_IT = [
    "Festivi: le pagine del Comune che abbiamo letto non dicono se i varchi sono spenti. Nei festivi l'app risponde «Non sicuro».",
    "Gli orari esatti vengono dai comunicati del Comune; da confrontare con il disciplinare in vigore (Provv. Dir. 2011/M/04192 e aggiornamenti).",
]
PENDING_COMMON_DE = [
    "Feiertage: Die gelesenen Seiten der Stadt sagen nicht, ob die Kameras aus sind. An Feiertagen antwortet die App «Nicht sicher».",
    "Die genauen Zeiten stammen aus Pressemitteilungen der Stadt; noch mit der geltenden Regelung abzugleichen (Provv. Dir. 2011/M/04192 und Folgende).",
]
HOTEL_PENDING = "Hotel guests: SAS has a form for hotels to add plates; the current online procedure is still to be confirmed."
HOTEL_PENDING_IT = "Ospiti degli hotel: SAS ha un modulo per comunicare le targhe; la procedura online attuale è da confermare."
HOTEL_PENDING_DE = "Hotelgäste: SAS hat ein Formular, mit dem Hotels Kennzeichen melden; das aktuelle Online-Verfahren ist noch zu bestätigen."

PENDING_COMMON = [
    "Public holidays: the city pages we read don't say whether the gates are off. The app answers \"Not sure\" on holidays.",
    "Exact gate times come from city news releases; still to be checked against the current disciplinare (Provv. Dir. 2011/M/04192 and later updates).",
]


SV_RAW = Path(__file__).resolve().parent.parent / "data/raw/scudo-verde"
SV_CHECKED = "2026-10-24T12:00:00Z"
EVERY_DAY = [1, 2, 3, 4, 5, 6, 7]
SV_LINKS = [
    {"title": "City of Florence, 31 March 2025: Scudo Verde starts (banned vehicles, exemptions)",
     "title_it": "Comune di Firenze, 31 marzo 2025: attivazione dello Scudo Verde (veicoli vietati, deroghe)",
     "title_de": "Stadt Florenz, 31. März 2025: Start des Scudo Verde (verbotene Fahrzeuge, Ausnahmen)",
     "url": "https://www.comune.firenze.it/novita/area-stampa/comunicati-stampa/domani-lattivazione-dello-scudo-verde-pre-esercizio"},
    {"title": "City of Florence, 27 May 2025: fines from 1 July 2025",
     "title_it": "Comune di Firenze, 27 maggio 2025: sanzioni dal 1° luglio 2025",
     "title_de": "Stadt Florenz, 27. Mai 2025: Bußgelder ab 1. Juli 2025",
     "url": "https://www.comune.firenze.it/novita/area-stampa/comunicati-stampa/scudo-verde-rinviata-al-1deg-luglio-lattivazione-del-sistema"},
    {"title": "City of Florence, 21 Aug 2026: second phase from 1 December 2026",
     "title_it": "Comune di Firenze, 21 agosto 2026: seconda fase dal 1° dicembre 2026",
     "title_de": "Stadt Florenz, 21. Aug. 2026: zweite Phase ab 1. Dezember 2026",
     "url": "https://www.comune.firenze.it/novita/area-stampa/comunicati-stampa/scudo-verde-da-dicembre-al-la-seconda-fase"},
    {"title": "Open data: Scudo Verde gates", "title_it": "Dati aperti: varchi Scudo Verde", "title_de": "Offene Daten: Scudo-Verde-Kameratore",
     "url": "https://opendata.comune.fi.it/page_dataset_show?id=varchi-scudo-verde"},
    {"title": "Metropolitan City of Florence, PUMS: Scudo Verde area (dataset)",
     "title_it": "Città Metropolitana di Firenze, PUMS: area Scudo Verde (dataset)",
     "title_de": "Metropolitanstadt Florenz, PUMS: Scudo-Verde-Gebiet (Datensatz)",
     "url": "https://www.dati.gov.it/view-dataset/dataset?id=ee3c2463-5912-4b32-8802-c4966abf901d"},
    {"title": "Exemptions and plate registration: SAS", "title_it": "Deroghe e registrazione targhe: SAS", "title_de": "Ausnahmen und Kennzeichen-Registrierung: SAS",
     "url": "https://www.serviziallastrada.it/"},
]
# Auto (M1). Fase 1: divieti già in vigore nel centro abitato, controllati dai varchi con sanzioni dal 1/7/2025.
# Fase 2 (delibera di giunta dell'11/8/2026): dal 1/12/2026 anche benzina Euro 1 e diesel Euro 2.
SV_BANS = [{"fuel": "petrol", "maxEuro": 0, "since": "2025-07-01"}, {"fuel": "diesel", "maxEuro": 1, "since": "2025-07-01"},
           {"fuel": "petrol", "maxEuro": 1, "since": "2026-12-01"}, {"fuel": "diesel", "maxEuro": 2, "since": "2026-12-01"}]
SV_PENDING = [
    ("Perimeter: from OpenStreetMap (relation 19205738), traced from the Metropolitan City's PUMS «Scudo verde» dataset. 75 of the 77 official gates are within 35 m of it; Via della Pietra and Via Etruria are 240–270 m away. Near the edge, look at the signs.",
     "Perimetro: da OpenStreetMap (relazione 19205738), ricalcato dal dataset PUMS «Scudo verde» della Città Metropolitana. 75 dei 77 varchi ufficiali sono entro 35 m dal confine; via della Pietra e via Etruria sono a 240–270 m. Vicino al bordo guarda i cartelli.",
     "Grenze: aus OpenStreetMap (Relation 19205738), nachgezeichnet nach dem PUMS-Datensatz «Scudo verde» der Metropolitanstadt. 75 der 77 offiziellen Tore liegen höchstens 35 m davon entfernt; Via della Pietra und Via Etruria 240–270 m. In Randnähe auf die Schilder achten."),
    ("Foreign and rental cars: the city pages don't make an exception for them, and don't say how foreign plates are checked. A car of a banned class should not drive in.",
     "Auto straniere e a noleggio: le pagine del Comune non le escludono e non dicono come si controllano le targhe estere. Un'auto di una classe vietata non deve entrare.",
     "Ausländische und Mietwagen: Die Seiten der Stadt nehmen sie nicht aus und sagen nicht, wie ausländische Kennzeichen geprüft werden. Ein Auto einer verbotenen Klasse sollte nicht hineinfahren."),
    ("From 1 Dec 2026: one-off bonus of 3 days (also not consecutive) for any banned vehicle, without registration; 25 days a year for residents of the Metropolitan City, 50 for Florence residents, after registering with SAS. How the 3 days are counted is to be confirmed.",
     "Dal 1° dicembre 2026: bonus una tantum di 3 giorni (anche non consecutivi) per qualsiasi veicolo vietato, senza registrazione; 25 giorni l'anno per i residenti della Città Metropolitana, 50 per i residenti a Firenze, con registrazione su SAS. Come si contano i 3 giorni è da confermare.",
     "Ab 1. Dez. 2026: einmaliger Bonus von 3 Tagen (auch nicht aufeinanderfolgend) für jedes verbotene Fahrzeug, ohne Registrierung; 25 Tage im Jahr für Einwohner der Metropolitanstadt, 50 für Einwohner von Florenz, nach Registrierung bei SAS. Wie die 3 Tage gezählt werden, ist noch zu bestätigen."),
    ("LPG, methane and bifuel cars are exempt only after registering the plate with SAS: without registration GateLR treats them like petrol cars of the same class.",
     "Le auto a GPL, metano e bifuel sono esenti solo registrando la targa su SAS: senza registrazione GateLR le tratta come le benzina della stessa classe.",
     "Autogas-, Erdgas- und Bifuel-Autos sind nur nach Registrierung des Kennzeichens bei SAS befreit: ohne Registrierung behandelt GateLR sie wie Benziner derselben Klasse."),
    ("Other exemptions (disabled badge CUDE with the holder on board, historic vehicles with CRS, a valid ZTL permit until it expires…) need registration with SAS: see the city's page.",
     "Altre deroghe (contrassegno disabili CUDE con il titolare a bordo, veicoli storici con CRS, permesso ZTL valido fino alla scadenza…) richiedono la registrazione su SAS: vedi la pagina del Comune.",
     "Weitere Ausnahmen (Behindertenausweis CUDE mit Inhaber an Bord, historische Fahrzeuge mit CRS, gültige ZTL-Genehmigung bis zum Ablauf…) erfordern die Registrierung bei SAS: siehe Seite der Stadt."),
    ("Fine: the city mentions €83 per violation (stated for tourist coaches); the amount for cars is to be confirmed. The rules for vans, motorbikes and coaches are different and not covered here.",
     "Multa: il Comune cita 83 € a violazione (detto per i bus turistici); l'importo per le auto è da confermare. Le regole per furgoni, moto e bus sono diverse e qui non sono considerate.",
     "Bußgeld: Die Stadt nennt 83 € pro Verstoß (für Reisebusse); der Betrag für Autos ist noch zu bestätigen. Für Lieferwagen, Motorräder und Busse gelten andere Regeln, hier nicht berücksichtigt."),
]


def scudo_verde():
    root = ET.parse(SV_RAW / "osm-relation-19205738-full.xml").getroot()
    nodes = {n.get("id"): [float(n.get("lon")), float(n.get("lat"))] for n in root.iter("node")}
    outer = next(m.get("ref") for m in root.iter("member") if m.get("type") == "way" and m.get("role") == "outer")
    way = next(w for w in root.iter("way") if w.get("id") == outer)
    pts = simplify([nodes[nd.get("ref")] for nd in way.iter("nd")], 0.00008)
    gates = []
    for f in json.loads((SV_RAW / "varchi_scudoverde.json").read_text())["features"]:
        p = f["properties"]
        if p["tipo_varco"] != "IN":
            continue          # le 4 telecamere «OUT» controllano chi esce
        lon, lat = f["geometry"]["coordinates"]
        gates.append({"id": f"sv-{p['num_varco']}", "name": p["nome_varco"].strip(),
                      "location": {"lat": round(lat, 6), "lon": round(lon, 6)}})
    return {
        "id": "firenze-scudo-verde",
        "name": "Scudo Verde · Low-emission zone",
        "name_it": "Scudo Verde · Zona a basse emissioni",
        "name_de": "Scudo Verde · Umweltzone",
        "kind": "green",
        "summary": ("Most of the city, inside a ring of 77 cameras (the airport and Careggi hospital are outside). Active 24 hours a day, every day. "
                    "Petrol Euro 0 and diesel Euro 0–1 cars can't drive in; from 1 December 2026 also petrol Euro 1 and diesel Euro 2. Other cars enter free, no ticket."),
        "summary_it": ("Gran parte della città, dentro un anello di 77 telecamere (aeroporto e ospedale di Careggi restano fuori). Attivo 24 ore su 24, tutti i giorni. "
                       "Non entrano le auto benzina Euro 0 e diesel Euro 0–1; dal 1° dicembre 2026 anche benzina Euro 1 e diesel Euro 2. Le altre auto entrano gratis, senza ticket."),
        "summary_de": ("Der größte Teil der Stadt, innerhalb eines Rings aus 77 Kameras (Flughafen und Klinikum Careggi liegen außerhalb). Rund um die Uhr, jeden Tag aktiv. "
                       "Benziner Euro 0 und Diesel Euro 0–1 dürfen nicht hinein; ab 1. Dezember 2026 auch Benziner Euro 1 und Diesel Euro 2. Andere Autos fahren kostenlos ein, ohne Ticket."),
        "perimeter": [{"lat": round(p[1], 6), "lon": round(p[0], 6)} for p in pts],
        "gates": sorted(gates, key=lambda g: g["name"]),
        "windows": [{"weekdays": EVERY_DAY, "start": 0, "end": 24 * 60}],
        "freeOnHolidays": False,
        "exemptFuels": [],
        "hotelCanRegister": False,
        "bans": SV_BANS,
        "source": {
            "authority": "City of Florence",
            "pageURL": SV_LINKS[0]["url"],
            "ordinance": "Deliberazione DG/2023/00607 (gates); Giunta decision of 11 Aug 2026 (second phase)",
            "ordinanceURL": None,
            "quote": "sarà in vigore h24 tutti i giorni dell'anno",
            "quoteTranslation": "it will be in force 24 hours a day, every day of the year",
            "quoteTranslation_de": "es gilt rund um die Uhr, an jedem Tag des Jahres",
            "checkedOn": SV_CHECKED,
            "reviewedByHuman": False,
            "pending": [p[0] for p in SV_PENDING],
            "pending_it": [p[1] for p in SV_PENDING],
            "pending_de": [p[2] for p in SV_PENDING],
            "links": SV_LINKS,
        },
    }


def fetch(url):
    with urllib.request.urlopen(url, timeout=60) as r:
        return json.load(r)


def simplify(points, tol):
    """Douglas-Peucker su coordinate [lon, lat]; tol in gradi (~1e-5 ≈ 1 m)."""
    if len(points) < 3:
        return points
    a, b = points[0], points[-1]
    def dist(p):
        dx, dy = b[0] - a[0], b[1] - a[1]
        if dx == dy == 0:
            return math.hypot(p[0] - a[0], p[1] - a[1])
        t = max(0, min(1, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / (dx * dx + dy * dy)))
        return math.hypot(p[0] - a[0] - t * dx, p[1] - a[1] - t * dy)
    i, d = max(((i, dist(p)) for i, p in enumerate(points[1:-1], 1)), key=lambda x: x[1])
    if d <= tol:
        return [a, b]
    return simplify(points[: i + 1], tol)[:-1] + simplify(points[i:], tol)


def ring(feature):
    pts = simplify(feature["geometry"]["coordinates"][0], 0.000008)
    return [{"lat": round(p[1], 6), "lon": round(p[0], 6)} for p in pts]


def main():
    day = {f["properties"]["tipologia"]: f for f in fetch(DIURNA)["features"]}
    night = {f["properties"]["tipologia"]: f for f in fetch(NOTTURNA)["features"]}
    gates = {}
    cameras = []
    for f in fetch(PORTE)["features"]:
        p = f["properties"]
        title = p["titolo"].strip()
        if re.search(r"(?i)corsia|TPL|pedonale", title):
            lon, lat = f["geometry"]["coordinates"]
            cameras.append({"id": f"ptm-{p['numero ptm']}", "name": re.sub(r"\s*\(.*\)", "", title).strip(),
                            "location": {"lat": round(lat, 6), "lon": round(lon, 6)},
                            "kind": "pedestrian" if "edonale" in title else "bus"})
        m = re.search(r"\(Settore ([A-Z])\)", p["titolo"])
        if not m or "Corsia" in p["titolo"]:
            continue          # corsie bus, aree pedonali, altre telecamere: non sono varchi ZTL
        lon, lat = f["geometry"]["coordinates"]
        name = re.sub(r"\s*\(Settore [A-Z]\)", "", p["titolo"]).strip()
        gates.setdefault(m.group(1), []).append({
            "id": f"ptm-{p['numero ptm']}", "name": name,
            "location": {"lat": round(lat, 6), "lon": round(lon, 6)}})

    zones = []
    for s in ["A", "B", "O", "F", "G"]:
        summer_only = s in ("F", "G")
        feature = night[s] if summer_only else day[s]
        windows = ([] if summer_only else DAY_WINDOWS) + [NIGHT_WINDOW]
        if summer_only:
            summary = ("Only on summer nights: from the first Thursday of April to the first Sunday of October, "
                       "Thursday, Friday and Saturday from 11 pm to 3 am. The rest of the year it's open to all. Motorbikes and scooters may enter.")
        else:
            summary = ("On weekdays you can't drive in from 7:30 am to 8 pm without a permit, on Saturdays until 4 pm. "
                       "In summer it's also closed on Thursday, Friday and Saturday nights, 11 pm to 3 am. Motorbikes and scooters may enter.")
        if summer_only:
            summary_it = ("Solo nelle notti d'estate: dal primo giovedì di aprile alla prima domenica di ottobre, "
                          "giovedì, venerdì e sabato dalle 23 alle 3. Il resto dell'anno è libero. Moto e scooter possono entrare.")
            summary_de = ("Nur in Sommernächten: vom ersten Donnerstag im April bis zum ersten Sonntag im Oktober, "
                          "Donnerstag, Freitag und Samstag von 23 bis 3 Uhr. Den Rest des Jahres frei. Motorräder und Roller dürfen hinein.")
        else:
            summary_it = ("Nei feriali non si entra dalle 7:30 alle 20 senza permesso, il sabato fino alle 16. "
                          "D'estate è chiusa anche giovedì, venerdì e sabato notte, dalle 23 alle 3. Moto e scooter possono entrare.")
            summary_de = ("Werktags keine Einfahrt von 7:30 bis 20 Uhr ohne Genehmigung, samstags bis 16 Uhr. "
                          "Im Sommer auch Donnerstag-, Freitag- und Samstagnacht gesperrt, von 23 bis 3 Uhr. Motorräder und Roller dürfen hinein.")
        zones.append({
            "id": f"firenze-{s.lower()}",
            "name": NAMES[s],
            "name_it": NAMES_IT[s],
            "name_de": NAMES_DE[s],
            "kind": "restricted",
            "summary": summary,
            "summary_it": summary_it,
            "summary_de": summary_de,
            "perimeter": ring(feature),
            "gates": sorted(gates.get(s, []), key=lambda g: g["name"]),
            "windows": windows,
            "freeOnHolidays": None,
            "exemptFuels": [],
            "exemptVehicleTypes": TWO_WHEELS,
            "hotelCanRegister": not summer_only,
            "source": {
                "authority": "City of Florence",
                "pageURL": (NIGHT_2026 if summer_only else DAY_HOURS)["url"],
                "ordinance": "Perimeter act " + feature["properties"]["atto_iniz"].strip().split(",")[-1].strip(),
                "ordinanceURL": None,
                "quote": ("dalle 23 di giovedì, venerdì e sabato alle 3 del giorno successivo" if summer_only
                          else "apertura al transito alle 20 nei giorni feriali e dalle 16 il sabato"),
                "quoteTranslation": ("from 11 pm on Thursday, Friday and Saturday to 3 am the next day" if summer_only
                                     else "open to traffic from 8 pm on weekdays and from 4 pm on Saturdays"),
                "quoteTranslation_de": ("von 23 Uhr am Donnerstag, Freitag und Samstag bis 3 Uhr am nächsten Tag" if summer_only
                                        else "Durchfahrt frei ab 20 Uhr an Werktagen und ab 16 Uhr am Samstag"),
                "checkedOn": CHECKED,
                "reviewedByHuman": False,
                "pending": PENDING_COMMON + ([] if summer_only else [HOTEL_PENDING]),
                "pending_it": PENDING_COMMON_IT + ([] if summer_only else [HOTEL_PENDING_IT]),
                "pending_de": PENDING_COMMON_DE + ([] if summer_only else [HOTEL_PENDING_DE]),
                "links": ([NIGHT_2026] if summer_only else [DAY_HOURS, DAY_START, NIGHT_2026]) + [DISCIPLINARE] + OPEN_DATA,
            },
        })

    zones.append(scudo_verde())
    city = {"id": "firenze", "name": "Florence", "name_it": "Firenze", "name_de": "Florenz", "center": {"lat": 43.7712, "lon": 11.2550},
            "zones": zones, "cameras": sorted(cameras, key=lambda c: c["name"]), "status": "draft",
            "license": ("Perimeters and gates: Comune di Firenze open data, CC-BY 4.0. Scudo Verde perimeter: © OpenStreetMap contributors, ODbL 1.0 "
                        "(traced from the Città Metropolitana di Firenze PUMS dataset, CC BY 4.0)")}
    out = Path(__file__).resolve().parent.parent / "Resources/Cities/firenze.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    for z in zones:
        print(f"{z['id']}: {len(z['perimeter'])} punti, {len(z['gates'])} varchi")


if __name__ == "__main__":
    main()
    import runpy   # l'elenco per gli aggiornamenti dell'app
    runpy.run_path(str(Path(__file__).resolve().parent / "build_manifest.py"))
