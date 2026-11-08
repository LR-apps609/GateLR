#!/usr/bin/env python3
# Costruisce Resources/Cities/bologna.json e milano.json dai dati aperti salvati in data/raw/
# (scaricati dai portali dei Comuni, CC BY 4.0 / CC BY) e dalle pagine ufficiali citate in docs/citta-successive.md.
# Uso: python3 Tools/build_cities.py
import hashlib, json, re
from pathlib import Path
from build_firenze import simplify
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw"
CHECKED = "2026-10-23T12:00:00Z"
EVERY_DAY = [1, 2, 3, 4, 5, 6, 7]
MON_FRI = [2, 3, 4, 5, 6]


def ring(geometry, tol=0.00001):
    """Il contorno esterno più grande, semplificato, come lista di {lat, lon}. Solo per geometrie di una parte sola:
    con più parti si ferma (1.20.4, B01/B05/B06: le parti staccate si perdevano), per quelle c'è rings()"""
    rs = rings(geometry, tol)
    if len(rs) != 1:
        raise SystemExit(f"ring(): {len(rs)} parti, usare rings()")
    return rs[0]


def _shoelace(pts):
    return abs(sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(pts, pts[1:] + pts[:1]))) / 2


def rings(geometry, tol=0.00001):
    """1.20.4: TUTTE le parti di un Polygon o MultiPolygon (contorno esterno di ognuna, semplificato), dalla più grande.
    I buchi interni restano pieni come prima (un punto in un buco risulta dentro: mai un verde in più). Una parte che la
    semplificazione riduce a meno di 4 punti distinti si tiene senza semplificarla"""
    polys = [geometry["coordinates"]] if geometry["type"] == "Polygon" else geometry["coordinates"]
    out = []
    for poly in sorted(polys, key=lambda p: -_shoelace(p[0])):
        pts = simplify(poly[0], tol)
        if len({tuple(p) for p in pts}) < 4:
            pts = poly[0]
        out.append([{"lat": round(p[1], 6), "lon": round(p[0], 6)} for p in pts])
    return out


def _km2(geometry):
    """Area ufficiale (somma dei contorni esterni) in km², per il controllo delle parti esportate"""
    polys = [geometry["coordinates"]] if geometry["type"] == "Polygon" else geometry["coordinates"]
    return sum(osm_geo.area_km2(p[0]) for p in polys)


def check_parts(name, geometry, parts, min_share=0.99):
    """Le parti esportate coprono almeno il 99% dell'area ufficiale (B01: Area B ne perdeva 1,14 km²). Per le aree
    piccole e strette conta la semplificazione: lì si controlla soprattutto che nessuna parte manchi"""
    polys = [geometry["coordinates"]] if geometry["type"] == "Polygon" else geometry["coordinates"]
    if len(parts) < len(polys):
        raise SystemExit(f"{name}: esportate {len(parts)} parti su {len(polys)}")
    official, exported = _km2(geometry), sum(osm_geo.area_km2(r) for r in parts)
    if exported < min_share * official:
        raise SystemExit(f"{name}: esportati {exported:.3f} km² su {official:.3f} ufficiali")


def check_gates(name, gates, perimeters, max_m, allowed=()):
    """Ogni varco dentro una delle parti o a non più di max_m metri dal bordo (salvo gli id in «allowed», lontani già
    nei dati ufficiali)"""
    for g in gates:
        lat, lon = g["location"]["lat"], g["location"]["lon"]
        d = min(0 if osm_geo.contains(r, lat, lon) else osm_geo.distance_m(r, lat, lon) for r in perimeters)
        if d > max_m and g["id"] not in allowed:
            raise SystemExit(f"{name}: il varco {g['id']} {g['name']} è a {d:.0f} m dal perimetro")


def nearest_part(perimeters, loc):
    """L'indice della parte più vicina a un punto (dentro = distanza 0)"""
    return min(range(len(perimeters)), key=lambda i: 0 if osm_geo.contains(perimeters[i], loc["lat"], loc["lon"])
               else osm_geo.distance_m(perimeters[i], loc["lat"], loc["lon"]))


def split_zone(zone, perimeters, name_suffix=None, id_suffix=None):
    """1.20.4: una zona per parte (le app leggono un solo perimetro per zona; così anche le app già installate vedono
    tutte le parti). La prima parte tiene l'id della zona, le altre «<id>-2», «<id>-3»…; i varchi vanno alla parte più
    vicina. name_suffix(i) e id_suffix(i): nome e id delle parti in più, se si vuole qualcosa di meglio di un numero"""
    gates = [[] for _ in perimeters]
    for g in zone["gates"]:
        gates[nearest_part(perimeters, g["location"])].append(g)
    out = []
    for i, per in enumerate(perimeters):
        z = json.loads(json.dumps(zone))
        z["perimeter"], z["gates"] = per, sorted(gates[i], key=lambda g: g["name"])
        if i:
            z["id"] = f"{zone['id']}-{id_suffix(i) if id_suffix else i + 1}"
            if name_suffix:
                for k in ("name", "name_it", "name_de"):
                    if k in z:
                        z[k] = z[k] + name_suffix(i, k)
        out.append(z)
    return out


def short_hash(perimeter):
    """Un id stabile da un perimetro (B120: aree senza codice nei dati aperti)"""
    return hashlib.sha1(json.dumps(perimeter, separators=(",", ":")).encode()).hexdigest()[:8]


def check_unique_ids(city):
    """B120: id unici per zone, aree pedonali e telecamere della città, e per i varchi di ogni zona (l'iPhone li usa come
    chiavi della mappa)"""
    seen = {}
    items = [("zona", z["id"]) for z in city["zones"]] + [("area pedonale", a["id"]) for a in city.get("pedestrian") or []]
    items += [("telecamera", c["id"]) for c in city.get("cameras") or []]
    # un varco può servire due zone (diurna e notturna): unico dentro la sua zona
    items += [(f"varco di {z['id']}", g["id"]) for z in city["zones"] for g in z["gates"]]
    for kind, i in items:
        if (kind, i) in seen:
            raise SystemExit(f"{city['id']}: {kind} con id doppio {i}")
        seen[(kind, i)] = True


def source(page, quote, translation, links, pending, ordinance=None):
    """translation e pending: (inglese, tedesco) e (inglese, italiano, tedesco)"""
    return {"authority": "", "pageURL": page, "ordinance": ordinance, "ordinanceURL": None,
            "quote": quote, "quoteTranslation": translation[0], "quoteTranslation_de": translation[1],
            "checkedOn": CHECKED, "reviewedByHuman": False,
            "pending": [p[0] for p in pending], "pending_it": [p[1] for p in pending], "pending_de": [p[2] for p in pending],
            "links": links}


def ban(fuel, max_euro, since):
    """Divieto ambientale: le auto con questo carburante e classe Euro fino a max_euro non entrano da «since»"""
    return {"fuel": fuel, "maxEuro": max_euro, "since": since}


# Milano, auto per trasporto persone (calendari ufficiali di Area B e Area C, aggiornati al 15/10/2026).
# Le classi Euro 6 diesel si dividono in A-B-C e D-TEMP/D: qui si usa la data più vicina (A-B-C) e si avvisa.
BANS_B = [ban("petrol", 3, "2025-10-01"), ban("petrol", 4, "2028-10-01"),
          ban("diesel", 5, "2019-02-25"), ban("diesel", 6, "2028-10-01")]
BANS_C = [ban("petrol", 3, "2024-10-01"), ban("petrol", 4, "2027-10-01"), ban("petrol", 5, "2030-10-01"),
          ban("diesel", 5, "2019-02-25"), ban("diesel", 6, "2028-10-01")]


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


def bologna():
    ztl = json.loads((RAW / "bologna/zona-a-traffico-limitato.geojson").read_text())
    # 1.20.4 (B05): prima si prendeva solo il poligono «codice 40»; Borgo San Pietro/Mascarella (31), Porta San
    # Felice/Azzarita (30), piazza Carducci (56) e le altre feature attive della stessa ordinanza restavano fuori.
    # Ora tutte le feature attive (stato «A») dell'ordinanza del centro, una zona per parte. Le parti che stanno dentro
    # il contorno del centro (i buchi del poligono 40, come via Ugo Bassi) sono già coperte e non si ripetono
    actives = [f for f in ztl["features"] if f["geometry"] and f["properties"]["stato"] == "A"
               and f["properties"]["ordinanza"] == "4000/343434"]
    main = next(f for f in actives if f["properties"]["codice"] == 40)
    main_parts = rings(main["geometry"])
    centre = main_parts[0]
    extra = []       # (codice, nome della via, perimetro)
    for f in sorted(actives, key=lambda f: f["properties"]["codice"]):
        if f is main:
            continue
        for per in rings(f["geometry"]):
            if all(osm_geo.contains(centre, p["lat"], p["lon"]) for p in per):
                continue
            extra.append((f["properties"]["codice"], (f["properties"].get("nomevia1") or "").strip(), per))
    for per in main_parts[1:]:
        if not all(osm_geo.contains(centre, p["lat"], p["lon"]) for p in per):
            extra.append((40, "", per))
    zt = json.loads((RAW / "bologna/zona-t-centro-storico.geojson").read_text())["features"][0]
    varchi = json.loads((RAW / "bologna/varchi-bologna.geojson").read_text())["features"]
    gates = [{"id": f"bo-{v['properties']['identificativo_varco']}",
              "name": v["properties"]["nome_varco"].strip(),
              "location": {"lat": round(v["geometry"]["coordinates"][1], 6), "lon": round(v["geometry"]["coordinates"][0], 6)}}
             for v in varchi if v["properties"].get("tipologia_varco") == "ZTL" and v["geometry"]]
    ztl_page = "https://www.comune.bologna.it/informazioni/zona-traffico-limitato-ztl"
    ticket_page = "https://www.comune.bologna.it/servizi/mobilita-trasporti/ticket-accesso-ztl"
    hotel_page = "https://www.comune.bologna.it/servizi/mobilita-trasporti/accesso-sosta-ztl-clienti-alberghi-autorimesse-autofficine"
    links = [link("City of Bologna: ZTL", "Comune di Bologna: ZTL", "Stadt Bologna: ZTL", ztl_page),
             link("City of Bologna: ZTL day ticket", "Comune di Bologna: ticket giornaliero ZTL", "Stadt Bologna: ZTL-Tagesticket", ticket_page),
             link("City of Bologna: hotel guests", "Comune di Bologna: clienti degli alberghi", "Stadt Bologna: Hotelgäste", hotel_page),
             link("Open data: ZTL perimeter and gates (CC BY 4.0)", "Dati aperti: perimetro e varchi ZTL (CC BY 4.0)",
                  "Offene Daten: ZTL-Grenze und Kameras (CC BY 4.0)", "https://opendata.comune.bologna.it/explore/dataset/zona-a-traffico-limitato/")]
    common = [("Public holidays: the city says \"every day\" without mentioning holidays; written confirmation still to be asked.",
               "Festivi: il Comune scrive «tutti i giorni» senza citare i festivi; conferma scritta da chiedere.",
               "Feiertage: Die Stadt schreibt «täglich», ohne Feiertage zu erwähnen; schriftliche Bestätigung steht aus."),
              ("The perimeter in the open data is from 2021: to compare with the current map.",
               "Il perimetro nei dati aperti è del 2021: da confrontare con la mappa attuale.",
               "Die Grenze in den offenen Daten ist von 2021: mit der aktuellen Karte zu vergleichen.")]
    zones = [
        {"id": "bologna-ztl", "name": "ZTL · Historic Centre", "name_it": "ZTL · Centro storico", "name_de": "ZTL · Altstadt", "kind": "pass",
         "summary": "Every day from 7 am to 8 pm you can't drive in without a permit or a day ticket. Inside, Zona T and the pedestrian areas stay closed around the clock.",
         "summary_it": "Tutti i giorni dalle 7 alle 20 non si entra senza permesso o ticket giornaliero. Dentro, la zona T e le aree pedonali restano chiuse 24 ore su 24.",
         "summary_de": "Täglich von 7 bis 20 Uhr keine Einfahrt ohne Genehmigung oder Tagesticket. Zone T und Fußgängerzonen bleiben rund um die Uhr gesperrt.",
         "perimeter": centre, "gates": sorted(gates, key=lambda g: g["name"]),
         "windows": [{"weekdays": EVERY_DAY, "start": 7 * 60, "end": 20 * 60}],
         "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": True,
         "ticket": {"price": 6.0, "howTo": "Buy and activate it on the Sosty website before you drive in, and wait for the confirmation. Max 3 per month per car.",
                    "howTo_it": "Compralo e attivalo sul sito Sosty prima di entrare e attendi la conferma. Massimo 3 al mese per auto.",
                    "howTo_de": "Vor der Einfahrt auf der Sosty-Website kaufen und aktivieren und die Bestätigung abwarten. Höchstens 3 pro Monat und Auto.",
                    "deadline": "beforeEntry",
                    "url": ticket_page},
         "source": source(ztl_page, "tutti i giorni, dalle 7 alle 20", ("every day, from 7 am to 8 pm", "täglich von 7 bis 20 Uhr"), links, common)},
        {"id": "bologna-t", "name": "Zona T · Rizzoli · Indipendenza · Ugo Bassi", "kind": "restricted",
         "summary": "Closed to cars around the clock, also with a day ticket. Only authorised vehicles may enter.",
         "summary_it": "Chiusa alle auto 24 ore su 24, anche con il ticket giornaliero. Entrano solo i veicoli autorizzati.",
         "summary_de": "Rund um die Uhr für Autos gesperrt, auch mit Tagesticket. Nur berechtigte Fahrzeuge dürfen hinein.",
         "perimeter": ring(zt["geometry"], 0.00001), "gates": [],
         "windows": [{"weekdays": EVERY_DAY, "start": 0, "end": 24 * 60}],
         "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": False,
         "source": source(ztl_page, "alcune zone limitate 24 ore su 24: le zone pedonali e l'area T",
                          ("some zones are limited 24 hours a day: the pedestrian areas and Zona T",
                           "einige Zonen sind rund um die Uhr beschränkt: die Fußgängerzonen und die Zone T"), links,
                          [("Hotel guests: the hotel shows the allowed route; to be checked with the city.",
                            "Ospiti degli hotel: l'hotel indica il percorso consentito; da verificare con il Comune.",
                            "Hotelgäste: Das Hotel zeigt den erlaubten Weg; mit der Stadt zu klären.")])},
    ]
    for z in zones:
        z["source"]["authority"] = "City of Bologna"
    # Le parti staccate della ZTL: stesse regole del centro (stessa ordinanza, stessi varchi «ZTL» sul bordo)
    zones[0]["source"]["pending"].append("The detached parts (e.g. Borgo San Pietro, Porta San Felice, piazza Carducci) are in the same ZTL ordinance "
                                         "of the open data: that the rules are the same as the centre is deduced from ordinance and gates.")
    zones[0]["source"]["pending_it"].append("Le parti staccate (per esempio Borgo San Pietro, Porta San Felice, piazza Carducci) sono nella stessa ordinanza "
                                            "ZTL dei dati aperti: che le regole siano quelle del centro è dedotto da ordinanza e varchi.")
    zones[0]["source"]["pending_de"].append("Die abgetrennten Teile (z. B. Borgo San Pietro, Porta San Felice, Piazza Carducci) gehören in den offenen Daten "
                                            "zur selben ZTL-Verordnung: dass die Regeln wie im Zentrum gelten, ist aus Verordnung und Kameras abgeleitet.")
    perims = [centre] + [e[2] for e in extra]
    names = [""] + [e[1].title() for e in extra]
    codes = [40] + [e[0] for e in extra]
    seen_codes = {}
    def code_id(i):
        seen_codes[codes[i]] = seen_codes.get(codes[i], 0) + 1
        return f"{codes[i]}" + (f"-{seen_codes[codes[i]]}" if seen_codes[codes[i]] > 1 else "")
    ids = {i: code_id(i) for i in range(1, len(perims))}
    parts = split_zone(zones[0], perims, id_suffix=lambda i: ids[i],
                       name_suffix=lambda i, k: f" · {names[i]}" if names[i] else "")
    # Controllo: le parti esportate coprono il 99% dei poligoni ufficiali che stanno fuori dal contorno del centro
    outside = [p for f in actives for p in ([f["geometry"]["coordinates"]] if f["geometry"]["type"] == "Polygon" else f["geometry"]["coordinates"])
               if not all(osm_geo.contains(centre, q[1], q[0]) for q in p[0])]
    check_parts("bologna-ztl", {"type": "MultiPolygon", "coordinates": outside}, perims)
    check_gates("bologna-ztl", gates, perims, 50)
    zones = parts + zones[1:]
    ped = json.loads((RAW / "bologna/zona-pedonale-centro-storico.geojson").read_text())["features"]
    # 1.20.4 (B120): 21 aree senza codice avevano tutte l'id «bo-ap-None» (e 2 «bo-ap-71»): id dal codice se è unico,
    # altrimenti dal perimetro (stabile finché il Comune non cambia l'area)
    codes_ped = [f["properties"].get("codice") for f in ped if f["geometry"]]
    pedestrian = []
    for f in ped:
        if not f["geometry"]:
            continue
        code = f["properties"].get("codice")
        for j, per in enumerate(rings(f["geometry"], 0.000005)):
            unique = code is not None and codes_ped.count(code) == 1 and j == 0
            pedestrian.append({"id": f"bo-ap-{code}" if unique else f"bo-ap-{code or 'x'}-{short_hash(per)}",
                               "name": (f["properties"].get("nomevia1") or "").strip().title() or "Area pedonale",
                               "perimeter": per})
    buses = [{"id": f"bo-c-{v['properties']['identificativo_varco']}", "name": v["properties"]["nome_varco"].strip(),
              "location": {"lat": round(v["geometry"]["coordinates"][1], 6), "lon": round(v["geometry"]["coordinates"][0], 6)},
              "kind": "bus"}
             for v in varchi if v["properties"].get("tipologia_varco") == "corsie" and v["geometry"]]
    return {"id": "bologna", "name": "Bologna", "pedestrian": pedestrian, "cameras": buses, "name_it": "Bologna", "name_de": "Bologna", "center": {"lat": 44.4938, "lon": 11.3430}, "zones": zones, "status": "draft",
            "license": "Perimeters and gates: Comune di Bologna open data, CC BY 4.0"}


# 1.20.4 (B110): il vecchio indirizzo del dataset (…/ds51_infogeo_aree_pedonali_ztl_localizzazione_) dà 404
OPEN_DATA_AREAS = "https://dati.comune.milano.it/dataset/ds51_trafficotrasporti_aree_pedonali_ztl"
# Data dell'ultimo aggiornamento delle risorse del dataset (API del portale, letta l'8/11/2026)
OPEN_DATA_AREAS_UPDATED = "2023-05-02T09:34:01Z"
# Varchi di Area B lontani dal perimetro già nei dati ufficiali (Comboni 228 m, Assunta 189 m dal bordo più vicino)
FAR_GATES_B = {"mi-b-36", "mi-b-117"}


def local_ztl(f, links):
    """1.20.4 (B07): una ZTL locale del dataset del Comune (zone a traffico limitato di poche vie: Ticinese, Garibaldi,
    Navigli…). Il dataset è del 2023 e gli orari, quando ci sono, stanno solo nelle note: la zona entra con la data dei
    dati («letto il» = ultimo aggiornamento del dataset), quindi la risposta è sempre «Controlla il cartello», mai verde
    né rossa. Gli orari delle note si tengono come fasce, per la mappa e per quando la zona sarà verificata"""
    p = f["properties"]
    name = re.sub(r"^ZTL\s+", "", (p["nome"] or "").strip())
    name = name.title() if name.isupper() else name
    note = (p.get("note") or "").strip()
    windows = LOCAL_WINDOWS.get(p["id_amat"], [{"weekdays": EVERY_DAY, "start": 0, "end": 24 * 60}])
    deroghe = re.sub(r"\s+", " ", p.get("deroghe") or "").strip()
    quote = f"{p['nome'].strip()}: deroghe «{deroghe}»" + (f"; note «{note}»" if note else "")
    zone = {"id": f"milano-ztl-{p['id_amat']}", "name": f"ZTL · {name}", "name_it": f"ZTL · {name}", "name_de": f"ZTL · {name}",
            "kind": "restricted",
            "summary": "Local limited traffic zone of the City of Milan (open data updated in 2023). Only the vehicles listed by the city may enter (often residents, taxis, deliveries at set hours). Hours and exemptions are only in the notes of the data: check the sign.",
            "summary_it": "ZTL locale del Comune di Milano (dati aperti aggiornati nel 2023). Entrano solo i veicoli indicati dal Comune (spesso residenti, taxi, carico e scarico a certe ore). Orari e deroghe sono solo nelle note dei dati: controlla il cartello.",
            "summary_de": "Lokale verkehrsberuhigte Zone der Stadt Mailand (offene Daten von 2023). Nur die von der Stadt genannten Fahrzeuge dürfen hinein (oft Anwohner, Taxis, Lieferverkehr zu bestimmten Zeiten). Zeiten und Ausnahmen stehen nur in den Notizen der Daten: achte auf das Schild.",
            "gates": [], "windows": windows, "freeOnHolidays": None, "exemptFuels": [], "hotelCanRegister": False,
            "source": source(OPEN_DATA_AREAS, quote, (f"{name}: exemptions and notes as written (in Italian) in the city's open data",
                                                     f"{name}: Ausnahmen und Notizen wie in den offenen Daten der Stadt (auf Italienisch)"), links,
                             [("The open data are from 2023 and give the hours only in a note: GateLR always says «check the sign» here.",
                               "I dati aperti sono del 2023 e danno gli orari solo in una nota: qui GateLR dice sempre «controlla il cartello».",
                               "Die offenen Daten sind von 2023 und nennen die Zeiten nur in einer Notiz: GateLR sagt hier immer «achte auf das Schild».")],
                             ordinance=(p.get("ordinanza") or None))}
    zone["source"]["authority"] = "City of Milan"
    zone["source"]["checkedOn"] = OPEN_DATA_AREAS_UPDATED
    return zone


# Le fasce scritte nelle note del dataset (id_amat → fasce); le altre ZTL locali: tutto il giorno
NIGHT_20_7 = [{"weekdays": EVERY_DAY, "start": 20 * 60, "end": 7 * 60}]
LOCAL_WINDOWS = {
    210: NIGHT_20_7, 212: NIGHT_20_7, 213: NIGHT_20_7, 214: NIGHT_20_7,          # Navigli notturna: «dalle 20:00 alle 07:00»
    224: [{"weekdays": EVERY_DAY, "start": 22 * 60, "end": 6 * 60}],                 # Arco della Pace: «dalle 22:00 alle 6:00»
    # Ascanio Sforza: «dalle 19:00 alle 6:00 del giorno successivo: lunedì-giovedì; dalle 19:00 del venerdì alle 6:00 del lunedì»
    1102: [{"weekdays": [2, 3, 4, 5, 6], "start": 19 * 60, "end": 6 * 60},
           {"weekdays": [7, 1], "start": 0, "end": 24 * 60}],
}
# ZTL locali del dataset che non si importano: Via Lagrange (val_fine 30/09/2017, scaduta); Cavalcavia Monte Ceneri
# (le deroghe ammettono autovetture e autocarri sotto 3,5 t: per un'auto non è una ZTL)
LOCAL_SKIP = {209, 203}


def milano():
    areas = json.loads((RAW / "milano/aree_pedonali_ztl.geojson").read_text())["features"]
    area_c = next(f for f in areas if f["properties"]["tipo"] == "AREA_C")
    area_b = next(f for f in areas if f["properties"]["tipo"] == "AREA_B")
    varchi = json.loads((RAW / "milano/areac_varchi.geojson").read_text())["features"]
    gates = [{"id": f"mi-c-{v['properties']['id_amat']}", "name": v["properties"]["label"].strip().title(),
              "location": {"lat": round(v["geometry"]["coordinates"][1], 6), "lon": round(v["geometry"]["coordinates"][0], 6)}}
             for v in varchi if v["geometry"]]
    varchi_b = json.loads((RAW / "milano/areab_varchi.geojson").read_text())["features"]
    gates_b = [{"id": f"mi-b-{v['properties']['id_amat']}",
                "name": re.sub(r"^\d+\s*-\s*", "", v["properties"]["nome"]).strip().title(),
                "location": {"lat": round(v["geometry"]["coordinates"][1], 6), "lon": round(v["geometry"]["coordinates"][0], 6)}}
               for v in varchi_b if v["geometry"]]
    page = "https://www.comune.milano.it/argomenti/mobilita/area-c"
    page_b = "https://www.comune.milano.it/argomenti/mobilita/area-b"
    buy = "https://www.comune.milano.it/servizi/mobilita/area-c-acquista-il-ticket"
    links = [link("City of Milan: Area C", "Comune di Milano: Area C", "Stadt Mailand: Area C", page),
             link("City of Milan: buy the Area C ticket", "Comune di Milano: acquista il ticket Area C", "Stadt Mailand: Area-C-Ticket kaufen", buy),
             link("City of Milan: activate the ticket", "Comune di Milano: attiva il ticket", "Stadt Mailand: Ticket aktivieren",
                  "https://www.comune.milano.it/servizi/mobilita/area-c-attiva-il-ticket"),
             link("City of Milan: Area C ban calendar", "Comune di Milano: calendario dei divieti di Area C", "Stadt Mailand: Verbotskalender Area C",
                  "https://www.comune.milano.it/argomenti/mobilita/area-c-calendario-dei-divieti"),
             link("Open data: Area C gates (CC BY)", "Dati aperti: varchi Area C (CC BY)", "Offene Daten: Area-C-Kameras (CC BY)",
                  "https://dati.comune.milano.it/dataset/ds82_infogeo_varchi_elettronici_localizzazione_")]
    links_b = [link("City of Milan: Area B", "Comune di Milano: Area B", "Stadt Mailand: Area B", page_b),
               link("City of Milan: Area B ban calendar", "Comune di Milano: calendario dei divieti di Area B", "Stadt Mailand: Verbotskalender Area B",
                    "https://www.comune.milano.it/argomenti/mobilita/area-b-calendario-dei-divieti"),
               link("Open data: ZTL and Area B perimeters (CC BY)", "Dati aperti: perimetri ZTL e Area B (CC BY)",
                    "Offene Daten: Grenzen von ZTL und Area B (CC BY)", OPEN_DATA_AREAS)]
    zone_c = {"id": "milano-c", "name": "Area C · City Centre", "name_it": "Area C · Centro", "name_de": "Area C · Innenstadt", "kind": "pass",
            "summary": "A paid zone: from Monday to Friday, 7:30 am to 7:30 pm, you can drive in with a €7.50 ticket, activated by midnight of the next day. Public holidays are free. Electric cars enter free.",
            "summary_it": "Zona a pagamento: dal lunedì al venerdì, dalle 7:30 alle 19:30, si entra con il ticket da 7,50 €, da attivare entro la mezzanotte del giorno dopo. Festivi esclusi. Le auto elettriche entrano gratis.",
            "summary_de": "Gebührenpflichtige Zone: Montag bis Freitag, 7:30 bis 19:30 Uhr, Einfahrt mit dem 7,50-€-Ticket, das bis Mitternacht des Folgetags aktiviert werden muss. Feiertage frei. Elektroautos fahren kostenlos ein.",
            "perimeter": ring(area_c["geometry"], 0.00002), "gates": sorted(gates, key=lambda g: g["name"]),
            "windows": [{"weekdays": MON_FRI, "start": 7 * 60 + 30, "end": 19 * 60 + 30}],
            # elettrici esenti senza adempimenti: DD 1856 del 13/03/2026, cap. 6 (letta il 26/10/2026, vedi docs/verifica-bologna-milano.md)
            "freeOnHolidays": True, "exemptFuels": ["electric"], "hotelCanRegister": False, "bans": BANS_C,
            "ticket": {"price": 7.5, "howTo": "Pay and activate it by midnight of the next day (online, at newsagents or by phone). Later, up to the 7th day, it costs €22.50. Parked in a partner garage: €4.50.",
                       "howTo_it": "Paga e attivalo entro la mezzanotte del giorno dopo (online, in edicola o per telefono). Più tardi, fino al 7° giorno, costa 22,50 €. Con sosta in un garage convenzionato: 4,50 €.",
                       "howTo_de": "Bis Mitternacht des Folgetags bezahlen und aktivieren (online, am Kiosk oder per Telefon). Später, bis zum 7. Tag, kostet es 22,50 €. Mit Parken in einer Partnergarage: 4,50 €.",
                       "deadline": "nextDayMidnight", "url": buy},
            "source": source(page, "Area C è attiva tutto l'anno dal lunedì al venerdì, dalle 7:30 alle 19:30 (festivi esclusi).",
                             ("Area C is active all year from Monday to Friday, 7:30 am to 7:30 pm (public holidays excluded).",
                              "Area C ist das ganze Jahr von Montag bis Freitag, 7:30 bis 19:30 Uhr, aktiv (Feiertage ausgenommen)."), links,
                             [("Hybrid cars enter free only with CO2 emissions up to 100 g/km (field V.7 of the registration document). GateLR doesn't know your car's CO2, so it shows the ticket.",
                               "Le auto ibride entrano gratis solo con emissioni di CO2 fino a 100 g/km (campo V.7 della carta di circolazione). GateLR non conosce la CO2 della tua auto, quindi indica il ticket.",
                               "Hybridautos fahren nur mit CO2-Emissionen bis 100 g/km (Feld V.7 der Zulassungsbescheinigung) kostenlos ein. GateLR kennt den CO2-Wert deines Autos nicht und zeigt daher das Ticket."),
                              ("7 December (Sant'Ambrogio, Milan's patron saint): not known whether it counts as a holiday.",
                               "7 dicembre (Sant'Ambrogio, patrono di Milano): non sappiamo se vale come festivo.",
                               "7. Dezember (Sant'Ambrogio, Mailands Schutzpatron): unklar, ob er als Feiertag gilt.")])}
    zone_b = {"id": "milano-b", "name": "Area B · Low-emission zone", "name_it": "Area B · Zona a basse emissioni",
              "name_de": "Area B · Umweltzone", "kind": "green",
              "summary": "Almost the whole city. From Monday to Friday, 7:30 am to 7:30 pm (holidays excluded), the most polluting vehicles can't drive in. Cleaner cars enter free, no ticket.",
              "summary_it": "Quasi tutta la città. Dal lunedì al venerdì, dalle 7:30 alle 19:30 (festivi esclusi), non entrano i veicoli più inquinanti. Le auto più pulite entrano gratis, senza ticket.",
              "summary_de": "Fast die ganze Stadt. Montag bis Freitag, 7:30 bis 19:30 Uhr (außer Feiertage), dürfen die umweltschädlichsten Fahrzeuge nicht hinein. Sauberere Autos fahren kostenlos ein, ohne Ticket.",
              "perimeter": None, "gates": gates_b,
              "windows": [{"weekdays": MON_FRI, "start": 7 * 60 + 30, "end": 19 * 60 + 30}],
              "freeOnHolidays": True, "exemptFuels": ["electric"], "hotelCanRegister": False, "bans": BANS_B,
              "source": source(page_b, "Area B è attiva dal lunedì al venerdì dalle 7:30 alle 19:30, festivi esclusi",
                               ("Area B is active from Monday to Friday, 7:30 am to 7:30 pm, public holidays excluded",
                                "Area B ist Montag bis Freitag von 7:30 bis 19:30 Uhr aktiv, Feiertage ausgenommen"), links_b,
                               [("Euro 6 diesel: classes A-B-C are banned from 1 Oct 2028, D-TEMP and D from 1 Oct 2030. GateLR uses the earlier date.",
                                 "Diesel Euro 6: le classi A-B-C sono vietate dal 1° ottobre 2028, D-TEMP e D dal 1° ottobre 2030. GateLR usa la data più vicina.",
                                 "Diesel Euro 6: Klassen A-B-C sind ab 1. Okt. 2028 gesperrt, D-TEMP und D ab 1. Okt. 2030. GateLR nimmt das frühere Datum."),
                                ("Free days: from 1 Oct 2026 every vehicle gets 5 days a year without registration, from the second year of its ban.",
                                 "Giornate libere: dal 1° ottobre 2026 ogni veicolo ha 5 giornate all'anno senza registrazione, dal secondo anno di divieto.",
                                 "Freie Tage: Ab 1. Okt. 2026 hat jedes Fahrzeug 5 Tage im Jahr ohne Registrierung, ab dem zweiten Jahr des Verbots."),
                                ("LPG and methane cars are treated like petrol cars of the same class: to be confirmed.",
                                 "Le auto a GPL e metano sono trattate come le benzina della stessa classe: da confermare.",
                                 "Autogas- und Erdgasautos werden wie Benziner derselben Klasse behandelt: noch zu bestätigen."),
                                ("Foreign cars: registration rules for non-Italian plates to be checked.",
                                 "Auto straniere: regole di registrazione per targhe non italiane da verificare.",
                                 "Ausländische Autos: Registrierungsregeln für nicht-italienische Kennzeichen noch zu prüfen.")])}
    for z in (zone_c, zone_b):
        z["source"]["authority"] = "City of Milan"
    # 1.20.4 (B01): Area B è un MultiPolygon di 7 parti; prima si teneva solo la più grande e Muggiano, Baggio/Salici,
    # Parea/Camaldoli, Achille Papa, San Bernardo restavano «fuori dalla ZTL» (verde a un diesel Euro 4 vietato).
    # Ora una zona per parte («milano-b», «milano-b-2»…), con i varchi della parte più vicina
    parts_b = rings(area_b["geometry"], 0.00008)
    check_parts("milano-b", area_b["geometry"], parts_b)
    check_gates("milano-b", gates_b, parts_b, 150, FAR_GATES_B)
    # Stesso nome per tutte le parti: è la stessa zona (Consigli per l'auto in Garage ne mostra una riga sola)
    zones_b = split_zone(zone_b, parts_b)
    # 1.20.4 (B06): le aree pedonali di più parti (Alzaia Naviglio Pavese, Navigli A e C, Sarpi C, XXIV Maggio,
    # Spallanzani) perdevano le parti minori: un'area per parte, «mi-ap-<id>», «mi-ap-<id>-2»…
    pedestrian = []
    for f in areas:
        if f["properties"]["tipo"] != "AP" or not f["geometry"]:
            continue
        parts = rings(f["geometry"], 0.000005)
        check_parts(f"mi-ap-{f['properties']['id_amat']}", f["geometry"], parts, 0.9)
        for j, per in enumerate(parts):
            pedestrian.append({"id": f"mi-ap-{f['properties']['id_amat']}" + (f"-{j + 1}" if j else ""),
                               "name": (f["properties"].get("nome") or "Area pedonale").strip(), "perimeter": per})
    # 1.20.4 (B07): le ZTL locali del dataset (prima ignorate: verde senza avvisi a Ticinese, Garibaldi, Navigli)
    local = []
    for f in areas:
        if f["properties"]["tipo"] != "ZTL" or not f["geometry"] or f["properties"]["id_amat"] in LOCAL_SKIP:
            continue
        parts = rings(f["geometry"], 0.000005)
        check_parts(f"milano-ztl-{f['properties']['id_amat']}", f["geometry"], parts, 0.9)
        local += split_zone(local_ztl(f, [links_b[-1]]), parts)
    return {"id": "milano", "name": "Milan", "pedestrian": pedestrian, "name_it": "Milano", "name_de": "Mailand", "center": {"lat": 45.4642, "lon": 9.1900},
            "zones": [zone_c] + zones_b + local, "status": "draft",
            "license": "Perimeters and gates: Comune di Milano open data, CC BY"}


for city in (bologna(), milano()):
    check_unique_ids(city)
    out = ROOT / f"Resources/Cities/{city['id']}.json"
    out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(out.name, [(z["id"], len(z["perimeter"]), len(z["gates"])) for z in city["zones"]])

# L'elenco per gli aggiornamenti dell'app (Resources/Cities/manifest.json)
import runpy
runpy.run_path(str(ROOT / "Tools/build_manifest.py"))
