#!/usr/bin/env python3
# Costruisce Resources/Cities/genova.json dagli atti ufficiali del Comune di Genova salvati in data/raw/genova/
# (fonti e date in docs/fonti-genova.md).
#
# Regole: «Disciplina dell'accesso alle Zone a Traffico Limitato», Rev 16/04/2025 (DGC 74/2025): tutte le ZTL
# valgono tutti i giorni dell'anno, 24 ore su 24.
# Perimetri: open data del Comune «Zone a traffico limitato» (dati.comune.genova.it, CC BY 4.0, rilievo del 2018),
# salvati in data/raw/genova/Zone_traffico_limitato.geojson. Il Centro Storico è l'unione dei cinque settori ufficiali
# (fatta su una griglia di 2 m con osm_geo.street_area). La ZTL «Nervi Centro» non è negli open data: il perimetro è la
# striscia di 6 m per lato attorno a Via Oberdan tra Piazza Pittaluga e Viale Franchini (way OSM 23100847, ODbL).
# Varchi: i nomi sono quelli del disciplinare; le coordinate sono le telecamere del traffico mappate in OpenStreetMap
# (data/raw/geo/genova-gates.json, ODbL), abbinate qui sotto a mano per nome e controllate per distanza dal perimetro.
# Non uscite: Castelletto (eliminata dalla DGC 74/2025), Rivarolo, Bolzaneto e Caracciolo (quartieri residenziali,
# perimetri ufficiali a pezzi o assenti), il settore «Fontane Marose» (sospeso nel 2025), l'Area 1 antismog (ORD 256/2025,
# planimetria solo in immagine). Vedi docs/fonti-genova.md.
# Non aggiorna manifest.json. Uso: python3 Tools/build_genova.py
import json, math, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/genova"
CHECKED = "2026-10-26T09:00:00Z"
EVERY_DAY = [1, 2, 3, 4, 5, 6, 7]

RULES_PDF = "https://www.comune.genova.it/sites/default/files/2025-06/Disciplinare%20ZTL%20aggiornato%20da%20DGC%2074-2025.pdf"
PERMIT_PAGE = "https://www.comune.genova.it/servizi/mobilita-e-trasporti/richiedere-permesso-di-accesso-ad-area-ztl"
OPEN_DATA = "https://dati.comune.genova.it/dataset/zone-traffico-limitato"
GENOVA_PARCHEGGI = "https://genovaparcheggi.com/it/"
ANTISMOG_PDF = "https://www.comune.genova.it/sites/default/files/2025-08/ORD_256_2025%20-%20File%20primario%20-%20ORD-256-2025%20-%20Definitiva%20-%20.pdf"
ORDINANCE = "Disciplinare ZTL Rev. 16/04/2025 (Deliberazione GC n. 74 del 10/04/2025)"
OSM_OBERDAN = 23100847   # Via Guglielmo Oberdan tra Piazza Pittaluga e Viale Franchini (motor_vehicle=destination)


def flat(text):
    return re.sub(r"\s+", " ", text).strip()


def must_contain(text, quote, where):
    """Ogni frase citata o riassunta deve esserci davvero nel documento salvato"""
    if flat(quote) not in text:
        raise SystemExit(f"Citazione non trovata in {where}: {quote!r}")


rules = flat((RAW / "disciplinare_ZTL_DGC_74_2025.txt").read_text(encoding="utf-8"))
permit = flat((RAW / "richiedere-permesso-di-accesso-ad-area-ztl.txt").read_text(encoding="utf-8"))
antismog = flat((RAW / "ORD_256_2025_antismog.txt").read_text(encoding="utf-8"))
for q in ["Rev 16/04/2025", "Deliberazione di Giunta Comunale n. 74/2025 del 10/04/2025", "Eliminato paragrafo ZTL Castelletto",
          "la regolarizzazione dell’accesso è consentita anche nelle quarantotto ore successive",
          "Clienti delle strutture ricettive alberghiere ed extra – alberghiere, per carico e scarico di bagagli ingombranti: tutti i giorni in orario 00.00 – 24.00.",
          "Clienti delle autorimesse pubbliche, per ingresso e uscita dall’autorimessa stessa: tutti i giorni in orario 00.00 – 24.00;",
          "entro e non oltre le quarantotto ore dall’accesso stesso",
          "viene rilasciato un unico contrassegno, a titolo gratuito e con validità annuale, valido per l’accesso in tutte le Z.T.L. del territorio cittadino.",
          "con un corrispettivo di Euro 2,50",
          "costituisce violazione all’art. 7 comma 14 del Codice della Strada",
          "Piazza De Ferrari, esclusa", "Via Gramsci (tratto da Piazza Jacopo da Varagine a Piazza della Darsena), esclusa",
          "AUT_02 (par. 2.3.2) limitatamente ai veicoli in disponibilità di residenti e no, che dispongono di aree di sosta private con regolare passo carrabile;"]:
    must_contain(rules, q, "disciplinare ZTL 2025")
for name in ["Centro Storico", "Molo", "Vernazzola", "Nervi", "Boccadasse", "Nervi Centro"]:
    must_contain(rules, f"La Z.T.L. “{name}” ha validità in tutti i giorni dell’anno e nell’intero arco delle 24 ore.", "disciplinare ZTL 2025")
for q in ["Centro Storico Boccadasse Bolzaneto Molo Nervi (Gazzolo) Nervi (Oberdan) Rivarolo Vernazzola Caracciolo",
          "Sistema Pubblico di Identità Digitale (SPID)", "Ultimo aggiornamento 24 Settembre 2026"]:
    must_contain(permit, q, "pagina permessi ZTL")
for q in ["ATTO N. ORD 256 DEL 05/08/2025", "nella fascia oraria dalle 07.00 alle 19.00 di tutti i giorni feriali dal lunedì al venerdì",
          "Veicoli di residenti fuori regione o all’estero muniti di prenotazione alberghiera nel Comune, limitatamente al tragitto di arrivo e partenza."]:
    must_contain(antismog, q, "ordinanza antismog 256/2025")


def quote(name):
    return f"La Z.T.L. “{name}” ha validità in tutti i giorni dell’anno e nell’intero arco delle 24 ore."


TRANSLATION = ("The “{}” ZTL is in force every day of the year, 24 hours a day.",
               "Die ZTL „{}“ gilt an allen Tagen des Jahres rund um die Uhr.")


# --- geometria ---

def official_zones():
    """{(NOME_ZONA, settore): [anelli [lon, lat]]} dagli open data, senza i doppioni (il file ripete le stesse aree)"""
    out = {}
    for f in json.loads((RAW / "Zone_traffico_limitato.geojson").read_text(encoding="utf-8"))["features"]:
        p, g = f["properties"], f["geometry"]
        polys = [g["coordinates"]] if g["type"] == "Polygon" else g["coordinates"]
        rings = out.setdefault((p["NOME_ZONA"], int(p["NR_SOTTOZONA"])), [])
        for poly in polys:
            ring = [tuple(c[:2]) for c in poly[0]]
            if ring not in rings:
                rings.append(ring)
    return out


def union(rings, cell_m=2.0, close_m=3.0):
    """Unione di aree confinanti (es. i settori del Centro Storico): i bordi vanno su una griglia di cell_m metri,
    si chiudono le fessure fino a ~2·close_m e si prende il contorno esterno (osm_geo.street_area)"""
    rel = {"id": 0, "members": [{"type": "way", "role": "section", "geometry": [{"lon": x, "lat": y} for x, y in r]} for r in rings]}
    return osm_geo.street_area(rel, cell_m=cell_m, close_m=close_m)


def largest(rings):
    return max(rings, key=osm_geo.area_km2)


def street_strip(points, half_m):
    """Striscia larga 2·half_m attorno a una linea [lon, lat] (per una ZTL fatta di una sola strada)"""
    lat0 = sum(p[1] for p in points) / len(points)
    k = math.cos(math.radians(lat0))
    fwd = lambda lon, lat: (lon * k * 111320.0, lat * 110574.0)
    back = lambda x, y: (x / (111320.0 * k), y / 110574.0)
    xy = [fwd(*p) for p in points]
    left, right = [], []
    for i, (x, y) in enumerate(xy):
        a, b = xy[max(i - 1, 0)], xy[min(i + 1, len(xy) - 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        n = math.hypot(dx, dy) or 1
        nx, ny = -dy / n * half_m, dx / n * half_m
        left.append(back(x + nx, y + ny))
        right.append(back(x - nx, y - ny))
    ring = left + right[::-1]
    return ring + [ring[0]]


OFFICIAL = official_zones()
CENTRO = osm_geo.perimeter(union([r for s in range(1, 6) for r in OFFICIAL[("CENTRO STORICO", s)]]), tol_m=2)
MOLO = osm_geo.perimeter(largest(OFFICIAL[("MOLO", 0)]), tol_m=1)
BOCCADASSE = osm_geo.perimeter(largest(OFFICIAL[("BOCCADASSE", 0)]), tol_m=1)
VERNAZZOLA = osm_geo.perimeter(largest(OFFICIAL[("BORGO MARINARO VERNAZZOLA", 0)]), tol_m=1)
NERVI = osm_geo.perimeter(largest(OFFICIAL[("NERVI", 0)]), tol_m=1)
OSM = osm_geo.load("genova-gates")
oberdan = next(e for e in OSM if e["type"] == "way" and e["id"] == OSM_OBERDAN)
assert oberdan["tags"]["name"] == "Via Guglielmo Oberdan"
NERVI_CENTRO = osm_geo.perimeter(street_strip([(n["lon"], n["lat"]) for n in oberdan["geometry"]], 6), tol_m=1)

# Varchi: nome ufficiale (disciplinare 3.1.3.1) → telecamera del traffico in OSM (surveillance:zone=traffic).
# Quelle con un nome in OSM («Varco Cairoli», «varco del Campo», …) coincidono; le altre sono la telecamera sulla via.
GATES = {
    "genova-centro": [("Via di Porta Soprana (settore 1)", 5594220118), ("Via del Campo (settore 1)", 5592753730),
                      ("Vico Giannini (settore 1)", 5592753728), ("Piazza della Raibetta (settore 1)", 5592753726),
                      ("Via San Giorgio (settore 2)", 5592753732), ("Vico delle Camelie (settore 2)", 5594220117),
                      ("Mura delle Grazie (settore 2)", 5592753731), ("Via Ravasco (settore 2)", 2829907843),
                      ("Via Lomellini (settore 3)", 8116477688), ("Via Cairoli (settore 4)", 2579946021),
                      ("Via Garibaldi (settore 5)", 5592753727)],
    "genova-molo": [("Via del Molo", 5592753729)],
    "genova-nervi": [("Via Gazzolo", 5592753725)],
}
GATE_MAX_M = 40   # una telecamera più lontana di così dal perimetro ufficiale vuol dire che l'abbinamento è sbagliato


def gates(zone_id, ring):
    nodes = {e["id"]: e for e in OSM if e["type"] == "node"}
    out = []
    for name, nid in GATES.get(zone_id, []):
        n = nodes[nid]
        assert n["tags"].get("surveillance:zone") == "traffic", (nid, n["tags"])
        d = 0 if osm_geo.contains(ring, n["lat"], n["lon"]) else osm_geo.distance_m(ring, n["lat"], n["lon"])
        if d > GATE_MAX_M:
            raise SystemExit(f"Varco {name}: la telecamera OSM {nid} è a {d:.0f} m dal perimetro")
        out.append({"id": f"ge-osm{nid}", "name": name, "location": {"lat": round(n["lat"], 6), "lon": round(n["lon"], 6)}})
    return out


# --- testi ---

def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


LINKS = [link("City of Genoa: ZTL access rules 2025 (PDF)", "Comune di Genova: disciplinare di accesso alle ZTL 2025 (PDF)",
              "Stadt Genua: Zufahrtsregeln der ZTL 2025 (PDF)", RULES_PDF),
         link("City of Genoa: applying for a ZTL permit (Genova Parcheggi)", "Comune di Genova: richiedere il permesso ZTL (Genova Parcheggi)",
              "Stadt Genua: ZTL-Genehmigung beantragen (Genova Parcheggi)", PERMIT_PAGE),
         link("City of Genoa open data: ZTL boundaries (CC BY 4.0)", "Open data del Comune di Genova: perimetri ZTL (CC BY 4.0)",
              "Offene Daten der Stadt Genua: ZTL-Grenzen (CC BY 4.0)", OPEN_DATA),
         link("City of Genoa: anti-smog order 256/2025 (PDF)", "Comune di Genova: ordinanza antismog 256/2025 (PDF)",
              "Stadt Genua: Anti-Smog-Verordnung 256/2025 (PDF)", ANTISMOG_PDF)]
OSM_GATES_LINK = link("OpenStreetMap: traffic cameras used as gate positions (ODbL)", "OpenStreetMap: telecamere usate come posizione dei varchi (ODbL)",
                      "OpenStreetMap: Verkehrskameras als Kamerastandorte (ODbL)", "https://www.openstreetmap.org/node/2579946021")

P_GEOMETRY = ("Boundary from the City's open data, surveyed in 2018 (before the 2025 rules): check the signs at the entrance.",
              "Perimetro dagli open data del Comune, rilevato nel 2018 (prima del disciplinare 2025): controlla i cartelli all'ingresso.",
              "Grenze aus den offenen Daten der Stadt, erfasst 2018 (vor den Regeln von 2025): Schilder an der Einfahrt beachten.")
P_GATES = ("Gate names are official; their positions are the traffic cameras mapped in OpenStreetMap, not an official list.",
           "I nomi dei varchi sono ufficiali; le posizioni sono le telecamere del traffico mappate in OpenStreetMap, non un elenco ufficiale.",
           "Die Namen der Kameras sind offiziell; ihre Standorte sind die in OpenStreetMap erfassten Verkehrskameras, keine offizielle Liste.")
P_ELECTRIC = ("Electric vehicles may enter all ZTLs but need a free yearly permit from Genova Parcheggi first; whether a foreign-registered car can get one is not stated.",
              "I veicoli elettrici possono entrare in tutte le ZTL ma serve prima un contrassegno annuale gratuito di Genova Parcheggi; non è detto se lo possa avere un'auto con targa estera.",
              "Elektrofahrzeuge dürfen in alle ZTL, brauchen aber vorher eine kostenlose Jahresgenehmigung von Genova Parcheggi; ob ein Auto mit ausländischem Kennzeichen sie bekommt, steht nicht da.")
P_NEW_CAMERAS = ("In April 2026 the city approved about 180 new plate-reading points, also checking exits and time spent inside; no switch-on date yet (confirmed only by GenovaToday and other press).",
                 "Ad aprile 2026 il Comune ha approvato circa 180 nuovi punti di lettura targhe, che controllano anche le uscite e il tempo di permanenza; non c'è ancora una data di accensione (confermato solo da GenovaToday e altra stampa).",
                 "Im April 2026 hat die Stadt rund 180 neue Kennzeichenleser beschlossen, die auch Ausfahrten und Aufenthaltsdauer prüfen; noch kein Starttermin (bestätigt nur von GenovaToday und anderer Presse).")
P_ANTISMOG = ("Separate anti-smog rules (order 256/2025): Monday to Friday 7 am–7 pm, older cars may not drive in the central Area 1 (diesel up to Euro 4, petrol up to Euro 1) or anywhere in the city (diesel up to Euro 2, petrol up to Euro 1). Cars from outside Liguria or abroad with a hotel booking in Genoa are exempt on the way to and from it. Area 1 is not drawn in GateLR.",
              "Regole antismog a parte (ordinanza 256/2025): dal lunedì al venerdì 7–19 le auto più vecchie non possono circolare nell'Area 1 centrale (diesel fino a Euro 4, benzina fino a Euro 1) né nel resto della città (diesel fino a Euro 2, benzina fino a Euro 1). Chi arriva da fuori Liguria o dall'estero con una prenotazione alberghiera a Genova è esentato nel tragitto di arrivo e partenza. L'Area 1 non è disegnata in GateLR.",
              "Eigene Anti-Smog-Regeln (Verordnung 256/2025): Montag bis Freitag 7–19 Uhr dürfen ältere Autos nicht in die zentrale Area 1 (Diesel bis Euro 4, Benzin bis Euro 1) und nirgends in der Stadt fahren (Diesel bis Euro 2, Benzin bis Euro 1). Wer von außerhalb Liguriens oder aus dem Ausland mit Hotelbuchung in Genua kommt, ist auf der An- und Abreise ausgenommen. Area 1 ist in GateLR nicht eingezeichnet.")
P_FONTANE = ("The weekend ZTL in Piazza Fontane Marose (Friday 8 pm–Sunday midnight, from 2023) was suspended in February 2025 and is not in the 2025 rules (suspension confirmed only by Liguria Business Journal).",
             "La ZTL del fine settimana in piazza Fontane Marose (dalle 20 del venerdì alla mezzanotte della domenica, dal 2023) è stata sospesa a febbraio 2025 e non è nel disciplinare 2025 (sospensione confermata solo da Liguria Business Journal).",
             "Die Wochenend-ZTL an der Piazza Fontane Marose (Freitag 20 Uhr bis Sonntag Mitternacht, seit 2023) wurde im Februar 2025 ausgesetzt und steht nicht in den Regeln von 2025 (Aussetzung nur von Liguria Business Journal bestätigt).")
P_SECTORS = ("The Historic Centre is split into five sectors: a hotel or garage permit is valid only for its own sector, so use the gate of that sector.",
             "Il Centro Storico è diviso in cinque settori: il permesso dell'hotel o del garage vale solo per il suo settore, quindi entra dal varco di quel settore.",
             "Die Altstadt ist in fünf Sektoren geteilt: Die Genehmigung von Hotel oder Garage gilt nur für deren Sektor, also durch die Kamera dieses Sektors einfahren.")
P_VERNAZZOLA = ("The 2025 rules shrink this ZTL to Via Argonauti, Piazza Vernazzola and part of Via Chighizola once cameras are installed; until then the 2021 rules apply. The map shows the older, larger area.",
                "Il disciplinare 2025 riduce questa ZTL a Via Argonauti, Piazza Vernazzola e un tratto di Via Chighizola dopo l'installazione delle telecamere; fino ad allora valgono le regole del 2021. La mappa mostra l'area più ampia di prima.",
                "Die Regeln von 2025 verkleinern diese ZTL auf Via Argonauti, Piazza Vernazzola und einen Teil der Via Chighizola, sobald Kameras stehen; bis dahin gelten die Regeln von 2021. Die Karte zeigt die ältere, größere Fläche.")
P_BOCCADASSE = ("The 2018 map may also include nearby streets whose residents can only apply for a permit (e.g. Via al Capo di Santa Chiara); no gate positions are known.",
                "La mappa del 2018 può includere anche strade vicine i cui residenti possono solo chiedere il permesso (es. Via al Capo di Santa Chiara); non conosciamo la posizione dei varchi.",
                "Die Karte von 2018 kann auch Nachbarstraßen enthalten, deren Anwohner nur eine Genehmigung beantragen dürfen (z. B. Via al Capo di Santa Chiara); Kamerastandorte sind unbekannt.")
P_NERVI = ("Since 2025 Via Provana di Leyni is no longer in this ZTL (its residents can still get a permit); the 2018 map may still include its last stretch.",
           "Dal 2025 Via Provana di Leyni non è più nella ZTL (i residenti possono comunque avere il permesso); la mappa del 2018 può comprenderne ancora l'ultimo tratto.",
           "Seit 2025 gehört Via Provana di Leyni nicht mehr zur ZTL (Anwohner bekommen weiterhin eine Genehmigung); die Karte von 2018 kann ihr letztes Stück noch enthalten.")
P_NERVI_CENTRO = ("Not in the City's open data: the boundary is a 12 m strip along Via Oberdan from OpenStreetMap, between Piazza Pittaluga and Viale Franchini as the rules say. No gate positions are known.",
                  "Non è negli open data del Comune: il perimetro è una striscia di 12 m lungo Via Oberdan da OpenStreetMap, tra Piazza Pittaluga e Viale Franchini come dice il disciplinare. Non conosciamo la posizione dei varchi.",
                  "Nicht in den offenen Daten der Stadt: Die Grenze ist ein 12 m breiter Streifen entlang der Via Oberdan aus OpenStreetMap, zwischen Piazza Pittaluga und Viale Franchini wie in den Regeln. Kamerastandorte sind unbekannt.")


def source(name, pending, links=LINKS):
    return {"authority": "City of Genoa", "pageURL": PERMIT_PAGE, "ordinance": ORDINANCE, "ordinanceURL": RULES_PDF,
            "quote": quote(name), "quoteTranslation": TRANSLATION[0].format(name), "quoteTranslation_de": TRANSLATION[1].format(name),
            "checkedOn": CHECKED, "reviewedByHuman": False,
            "pending": [p[0] for p in pending], "pending_it": [p[1] for p in pending], "pending_de": [p[2] for p in pending],
            "links": links}


CLOSED = ("Closed to unauthorised vehicles 24 hours a day, every day, holidays included. There is no day ticket for visitors.",
          "Chiusa ai veicoli non autorizzati 24 ore su 24, tutti i giorni, festivi compresi. Non c'è un biglietto giornaliero per i turisti.",
          "Rund um die Uhr, täglich und auch an Feiertagen für nicht berechtigte Fahrzeuge gesperrt. Es gibt kein Tagesticket für Besucher.")
HOTEL = (" If your hotel or a public garage is inside, it can register your plate online up to 48 hours after you drive in (hotels: to load and unload luggage; garages: €2.50 a day).",
         " Se l'hotel o un'autorimessa pubblica è dentro, può registrare la tua targa online entro 48 ore dall'ingresso (hotel: per carico e scarico bagagli; garage: 2,50 € al giorno).",
         " Liegt dein Hotel oder ein öffentliches Parkhaus innen, kann es dein Kennzeichen bis 48 Stunden nach der Einfahrt online melden (Hotels: zum Be- und Entladen des Gepäcks; Parkhäuser: 2,50 € pro Tag).")
EV = (" Electric vehicles need a free yearly permit.", " Le elettriche hanno bisogno di un contrassegno annuale gratuito.",
      " Elektroautos brauchen eine kostenlose Jahresgenehmigung.")


def text(*parts):
    return tuple("".join(p[i] for p in parts) for i in range(3))


def zone(zid, names, summary, name, perimeter, pending, hotel=True, links=LINKS):
    return {"id": zid, "name": names[0], "name_it": names[1], "name_de": names[2], "kind": "restricted",
            "summary": summary[0], "summary_it": summary[1], "summary_de": summary[2],
            "perimeter": perimeter, "gates": gates(zid, perimeter),
            "windows": [{"weekdays": EVERY_DAY, "start": 0, "end": 24 * 60}],
            "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": hotel,
            "source": source(name, pending, links)}


GATE_LINKS = LINKS + [OSM_GATES_LINK]
zones = [
    zone("genova-centro", ("Historic Centre · Caruggi ZTL", "Centro Storico · ZTL dei caruggi", "Altstadt · ZTL der Caruggi"),
         text(CLOSED, HOTEL, EV, (" Piazza De Ferrari and Via Gramsci are outside.",
                                  " Piazza De Ferrari e Via Gramsci sono fuori.",
                                  " Piazza De Ferrari und Via Gramsci liegen außerhalb.")),
         "Centro Storico", CENTRO, [P_GEOMETRY, P_GATES, P_SECTORS, P_ELECTRIC, P_NEW_CAMERAS, P_FONTANE, P_ANTISMOG], links=GATE_LINKS),
    zone("genova-molo", ("Molo · Old Port ZTL", "Molo · ZTL del Porto Antico", "Molo · ZTL am Alten Hafen"),
         text(CLOSED, HOTEL, EV), "Molo", MOLO, [P_GEOMETRY, P_GATES, P_ELECTRIC, P_NEW_CAMERAS, P_ANTISMOG], links=GATE_LINKS),
    zone("genova-boccadasse", ("Boccadasse · fishing village ZTL", "Boccadasse · ZTL del borgo", "Boccadasse · ZTL im Fischerdorf"),
         text(CLOSED, HOTEL, EV), "Boccadasse", BOCCADASSE, [P_GEOMETRY, P_BOCCADASSE, P_ELECTRIC, P_NEW_CAMERAS]),
    zone("genova-vernazzola", ("Vernazzola · fishing village ZTL", "Vernazzola · ZTL del borgo marinaro", "Vernazzola · ZTL im Fischerdorf"),
         text(CLOSED, HOTEL, EV), "Vernazzola", VERNAZZOLA, [P_GEOMETRY, P_VERNAZZOLA, P_ELECTRIC]),
    zone("genova-nervi", ("Nervi harbour · Via Gazzolo ZTL", "Porticciolo di Nervi · ZTL Via Gazzolo", "Hafen Nervi · ZTL Via Gazzolo"),
         text(CLOSED, HOTEL, EV), "Nervi", NERVI, [P_GEOMETRY, P_NERVI, P_GATES, P_ELECTRIC, P_NEW_CAMERAS], links=GATE_LINKS),
    zone("genova-nervi-centro", ("Nervi Centro · Via Oberdan ZTL", "Nervi Centro · ZTL Via Oberdan", "Nervi Centro · ZTL Via Oberdan"),
         text(("Closed to unauthorised vehicles 24 hours a day, every day, holidays included. Stricter than the other ZTLs: only residents, people with a private parking space, disabled badge holders, taxis and electric vehicles with the free yearly permit. Hotel and garage guests can't be registered. Deliveries 8 am–1 pm.",
               "Chiusa ai veicoli non autorizzati 24 ore su 24, tutti i giorni, festivi compresi. Più severa delle altre ZTL: entrano solo residenti, chi ha un posto auto privato, disabili con contrassegno, taxi ed elettriche con il contrassegno annuale gratuito. Gli ospiti di hotel e garage non possono essere registrati. Consegne 8–13.",
               "Rund um die Uhr, täglich und auch an Feiertagen für nicht berechtigte Fahrzeuge gesperrt. Strenger als die anderen ZTL: nur Anwohner, Inhaber eines privaten Stellplatzes, Behindertenausweis, Taxis und Elektroautos mit der kostenlosen Jahresgenehmigung. Hotel- und Parkhausgäste können nicht gemeldet werden. Lieferungen 8–13 Uhr."),),
         "Nervi Centro", NERVI_CENTRO, [P_NERVI_CENTRO, P_ELECTRIC], hotel=False,
         links=LINKS + [link(f"OpenStreetMap: way {OSM_OBERDAN} (Via Oberdan, ODbL)", f"OpenStreetMap: way {OSM_OBERDAN} (Via Oberdan, ODbL)",
                             f"OpenStreetMap: Weg {OSM_OBERDAN} (Via Oberdan, ODbL)", osm_geo.osm_url("way", OSM_OBERDAN))]),
]
must_contain(rules, "dalle 08.00 alle 13.00", "disciplinare ZTL 2025 (Nervi Centro, merci)")

# --- controlli: un luogo noto dentro ogni zona (punti delle strade in OSM), la stazione e piazza De Ferrari fuori ---
by_id = {z["id"]: z["perimeter"] for z in zones}
INSIDE = {"genova-centro": [("Cattedrale di San Lorenzo", 44.4079, 8.9310), ("Via Garibaldi (Palazzo Tursi)", 44.41115, 8.93318),
                            ("Piazza Banchi", 44.4098, 8.9288), ("Via San Lorenzo", 44.40795, 8.93245)],
          "genova-molo": [("Via del Molo", 44.40664, 8.92722)],
          "genova-boccadasse": [("Piazza Nettuno", 44.39024, 8.97457)],
          "genova-vernazzola": [("Via Argonauti", 44.39141, 8.97931)],
          "genova-nervi": [("Via Caboto", 44.38341, 9.03137)],
          "genova-nervi-centro": [("Via Oberdan", 44.38373, 9.03806)]}
OUTSIDE = [("Genova Piazza Principe", 44.4176, 8.9213), ("Piazza De Ferrari (esclusa)", 44.40715, 8.93395),
           ("Genova Brignole", 44.4067, 8.9467), ("Acquario", 44.4103, 8.9268)]
for zid, places in INSIDE.items():
    for name, lat, lon in places:
        assert osm_geo.contains(by_id[zid], lat, lon), f"{name} dovrebbe essere dentro {zid}"
for name, lat, lon in OUTSIDE:
    for zid, ring in by_id.items():
        assert not osm_geo.contains(ring, lat, lon), f"{name} non dovrebbe essere dentro {zid}"
area = osm_geo.area_km2(CENTRO)
assert 0.4 < area < 0.5, f"Centro Storico: area strana {area:.3f} km²"

city = {"id": "genova", "name": "Genoa", "name_it": "Genova", "name_de": "Genua",
        "center": {"lat": 44.4072, "lon": 8.9339}, "zones": zones, "status": "draft",
        "license": "Rules: Comune di Genova (Disciplinare ZTL 2025). Perimeters: Comune di Genova open data «Zone a traffico limitato» "
                   "(CC BY 4.0, 2018). Gate positions and the Nervi Centro perimeter: " + osm_geo.ODBL + " (approximate, not official)."}

ready = all(len(z["perimeter"]) >= 4 for z in city["zones"])
out = ROOT / ("Resources/Cities/genova.json" if ready else "data/drafts/genova.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("Resources/Cities/genova.json" if not ready else "data/drafts/genova.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.name, [(z["id"], len(z["perimeter"]), len(z["gates"]), round(osm_geo.area_km2(z["perimeter"]), 4)) for z in city["zones"]])
