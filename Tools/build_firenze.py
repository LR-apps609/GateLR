#!/usr/bin/env python3
# Costruisce Resources/Cities/firenze.json dai dati aperti del Comune di Firenze (CC-BY 4.0):
#   - perimetri ZTL diurna (settori A, B, O) e notturna estiva (anche F, G)
#   - porte telematiche (si tengono solo quelle dei settori ZTL, non corsie bus o aree pedonali)
# Gli orari vengono dalle pagine del Comune citate qui sotto, riassunti a mano.
# Uso: python3 Tools/build_firenze.py   (serve accesso a datigis.comune.fi.it)
import json, math, re, urllib.request
from pathlib import Path

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
# Estate 2026: dal 2 aprile al primo fine settimana di ottobre compreso (3 ottobre), 23 → 3
NIGHT_WINDOW = {"weekdays": THU_SAT, "start": 23 * 60, "end": 3 * 60,
                "season": {"fromMonth": 4, "fromDay": 2, "toMonth": 10, "toDay": 3}}

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
    for f in fetch(PORTE)["features"]:
        p = f["properties"]
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
            summary = ("Only on summer nights: from early April to the first weekend of October, "
                       "Thursday, Friday and Saturday from 11 pm to 3 am. The rest of the year it's open to all.")
        else:
            summary = ("On weekdays you can't drive in from 7:30 am to 8 pm without a permit, on Saturdays until 4 pm. "
                       "In summer it's also closed on Thursday, Friday and Saturday nights, 11 pm to 3 am.")
        if summary_only := summer_only:
            summary_it = ("Solo nelle notti d'estate: da inizio aprile al primo fine settimana di ottobre, "
                          "giovedì, venerdì e sabato dalle 23 alle 3. Il resto dell'anno è libero.")
            summary_de = ("Nur in Sommernächten: von Anfang April bis zum ersten Oktoberwochenende, "
                          "Donnerstag, Freitag und Samstag von 23 bis 3 Uhr. Den Rest des Jahres frei.")
        else:
            summary_it = ("Nei feriali non si entra dalle 7:30 alle 20 senza permesso, il sabato fino alle 16. "
                          "D'estate è chiusa anche giovedì, venerdì e sabato notte, dalle 23 alle 3.")
            summary_de = ("Werktags keine Einfahrt von 7:30 bis 20 Uhr ohne Genehmigung, samstags bis 16 Uhr. "
                          "Im Sommer auch Donnerstag-, Freitag- und Samstagnacht gesperrt, von 23 bis 3 Uhr.")
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
                "links": ([NIGHT_2026] if summer_only else [DAY_HOURS, DAY_START, NIGHT_2026]) + OPEN_DATA,
            },
        })

    city = {"id": "firenze", "name": "Florence", "name_it": "Firenze", "name_de": "Florenz", "center": {"lat": 43.7712, "lon": 11.2550},
            "zones": zones, "status": "draft",
            "license": "Perimeters and gates: Comune di Firenze open data, CC-BY 4.0"}
    out = Path(__file__).resolve().parent.parent / "Resources/Cities/firenze.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    for z in zones:
        print(f"{z['id']}: {len(z['perimeter'])} punti, {len(z['gates'])} varchi")


if __name__ == "__main__":
    main()
