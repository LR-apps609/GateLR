#!/usr/bin/env python3
# Costruisce la scheda di Torino (fonti e date in docs/fonti-torino.md).
#
# Zone nella scheda:
#  - ZTL Centrale: lun–ven 7:30–10:30 (sabato, domenica e festivi spenta). Perimetro: relazione OSM 19152960
#    «ZTL Centrale» (boundary=limited_traffic_zone, contorno «outer»), © OpenStreetMap contributors, ODbL 1.0.
#  - Strade riservate al trasporto pubblico (ZTL Trasporto Pubblico): tutti i giorni 7–20, festivi compresi.
#    Geometria: le way OSM con zone:traffic:name=«Strade riservate al Trasporto Pubblico», una zona per gruppo di
#    strade collegate, area coperta dalla strada (osm_geo.street_area con una chiusura minima).
#  - Aree pedonali (ZTL Pedonale, h24): le way OSM con zone:traffic:name=«ZTL Pedonale», come «pedestrian» della città.
# Non ancora nella scheda (manca il perimetro da qui): ZTL Area Romana (21–7:30), ZTL Valentino (h24), ZTL notturna
# Monte dei Cappuccini (23–7), Borgo Campidoglio (pedonale h24). Vedi i punti in sospeso.
#
# Le pagine del Comune e di GTT non si raggiungono dall'ambiente di lavoro: le frasi citate sono controllate contro
# gli estratti di ricerca salvati in data/raw/torino/ricerca-web-2026-10-25.txt. Quando la scheda ufficiale «ZTL
# Centrale» è salvata (data/raw/torino/scheda-ztl-centrale.html, o data/raw/geo/torino-scheda-ztl-centrale.html
# scaricata da Tools/fetch_geo.py), le citazioni vengono controllate su quella e la città va in Resources/Cities/;
# altrimenti resta in data/drafts/torino.json.
# Non aggiorna manifest.json. Uso: python3 Tools/build_torino.py
import html, json, re, sys
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/torino"
CHECKED = "2026-10-25T09:00:00Z"
EVERY_DAY = [1, 2, 3, 4, 5, 6, 7]

SCHEDA = "https://www.comune.torino.it/schede-informative/ztl-centrale"
PERMESSI = "https://www.comune.torino.it/servizi/richiedere-permesso-accesso-ad-area-ztl"
ELETTRICI = "https://www.comune.torino.it/schede-informative/permessi-circolazione-ztl-per-veicoli-elettrici-puri"
GTT_HOTEL = "https://www.gtt.to.it/cms/ztl/3681-utenti-che-pernottano-in-strutture-alberghiere"
GTT_ESENTI = "https://www.gtt.to.it/cms/ztl/3090-elenco-veicoli-esentati"
GTT_PIATTAFORMA = "https://www.gtt.to.it/cms/ztl/piattaforma-autorizzazioni-online"
AGOSTO = "https://www.comune.torino.it/novita/comunicati/sospensione-estiva-della-ztl-della-sosta-pagamento-0"
OPEN_DATA = "https://aperto.comune.torino.it/dataset/perimetro-varchi-e-orari-ztl"
OSM_CENTRALE = 19152960
TP_NAME, PED_NAME = "Strade riservate al Trasporto Pubblico", "ZTL Pedonale"


def flat(text):
    return re.sub(r"\s+", " ", text).strip()


def norm(text):
    """Per confrontare le citazioni: apostrofi e virgolette tipografiche come quelle semplici"""
    return flat(text).replace("’", "'").replace("“", '"').replace("”", '"').replace("«", '"').replace("»", '"')


def page_text(path):
    t = path.read_text(encoding="utf-8", errors="replace")
    t = re.sub(r"<(script|style)[^>]*>.*?</\1>", " ", t, flags=re.S)
    return norm(html.unescape(re.sub(r"<[^>]+>", " ", t)))


def must_contain(text, quote, where):
    if norm(quote) not in text:
        raise SystemExit(f"Citazione non trovata in {where}: {quote!r}")


# --- testi: la scheda ufficiale se c'è, altrimenti gli estratti di ricerca ---
official = next((p for p in [RAW / "scheda-ztl-centrale.html", ROOT / "data/raw/geo/torino-scheda-ztl-centrale.html"]
                 if p.exists() and p.stat().st_size > 5000), None)
notes = norm((RAW / "ricerca-web-2026-10-25.txt").read_text(encoding="utf-8"))
text, where = (page_text(official), official.name) if official else (notes, "ricerca-web-2026-10-25.txt")

Q_CENTRALE = "dalle 7.30 alle 10.30 di tutti i giorni feriali (sabato escluso)"
Q_TP = "La ZTL Trasporto Pubblico è chiusa al transito e alla sosta dalle 7.00 alle 20.00 di tutti i giorni, compresi i festivi."
Q_PED = "chiusa al transito e alla sosta dei veicoli tutti i giorni, feriali e festivi, H24"
Q_10 = "sono tassativamente 10 (dieci) - dal primo giorno di transito compreso"
for q in [Q_CENTRALE, Q_TP, Q_PED, Q_10]:
    must_contain(text, q, where)
for q in ["accreditate e regolarmente registrate in Piattaforma ZTL",
          "Al momento del check-in presso l'albergo, gli stessi fruitori dovranno compilare la richiesta di autorizzazione al transito per il periodo di permanenza presso la struttura",
          "entro e non oltre le ore 11.00", "motoveicoli, se Euro 1, a 4 tempi",
          'Restano infatti attive le ZTL "Trasporto Pubblico", "Pedonale", "Area Romana" e "Valentino"',
          "di consueto la ZTL centrale non sarà attiva"]:
    must_contain(notes, q, "ricerca-web-2026-10-25.txt")


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


def source(quote, translation, links, pending, page=SCHEDA, ordinance=None, ordinance_url=None):
    return {"authority": "City of Turin", "pageURL": page, "ordinance": ordinance, "ordinanceURL": ordinance_url,
            "quote": quote, "quoteTranslation": translation[0], "quoteTranslation_de": translation[1],
            "checkedOn": CHECKED, "reviewedByHuman": False,
            "pending": [p[0] for p in pending], "pending_it": [p[1] for p in pending], "pending_de": [p[2] for p in pending],
            "links": links}


# --- geometria (OpenStreetMap, ODbL) ---
els = osm_geo.load("torino-ztl")
centrale = osm_geo.perimeter(osm_geo.outer_ring(osm_geo.relation(els, OSM_CENTRALE)), tol_m=5)


def thick(w, d_m=4.0):
    """La way e quattro copie spostate di d_m metri: sulla griglia di street_area la strada diventa una striscia
    continua anche in diagonale (le vie di Torino sono inclinate rispetto ai meridiani), larga circa quanto la carreggiata"""
    dlat, dlon = d_m / 110574, d_m / 78700
    return [[{"lat": n["lat"] + a, "lon": n["lon"] + b} for n in w["geometry"]]
            for a, b in [(0, 0), (dlat, 0), (-dlat, 0), (0, dlon), (0, -dlon)]]


def street_groups(name, join_m=15, close_m=12):
    """Le way con zone:traffic:name=name, raggruppate se si toccano (estremi o nodi a meno di join_m metri)"""
    ways = [e for e in els if e["type"] == "way" and e.get("tags", {}).get("zone:traffic:name") == name and e.get("geometry")]
    parent = list(range(len(ways)))
    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]; i = parent[i]
        return i
    pts = [[(n["lon"], n["lat"]) for n in w["geometry"]] for w in ways]
    near = lambda a, b: abs(a[1] - b[1]) * 110574 < join_m and abs(a[0] - b[0]) * 78700 < join_m
    for i in range(len(ways)):
        for j in range(i + 1, len(ways)):
            if any(near(a, b) for a in (pts[i][0], pts[i][-1]) for b in pts[j]) or \
               any(near(a, b) for a in (pts[j][0], pts[j][-1]) for b in pts[i]):
                parent[find(i)] = find(j)
    groups = {}
    for i, w in enumerate(ways):
        groups.setdefault(find(i), []).append(w)
    out, skipped = [], []
    covers = lambda ring, w: all(osm_geo.contains(ring, n["lat"], n["lon"]) or osm_geo.distance_m(ring, n["lat"], n["lon"]) < 6
                                 for n in w["geometry"])
    for ws in groups.values():
        todo = list(ws)
        while todo:   # street_area dà la parte connessa più grande: si ripete sulle strade rimaste fuori
            rel = {"id": todo[0]["id"], "members": [{"type": "way", "role": "section", "geometry": g} for w in todo for g in thick(w)]}
            ring = osm_geo.street_area(rel, cell_m=6, close_m=close_m)
            done = [w for w in todo if covers(ring, w)] or [todo[0]]
            todo = [w for w in todo if w not in done]
            names = sorted({w["tags"].get("name") for w in done if w["tags"].get("name")},
                           key=lambda n: -sum(len(w["geometry"]) for w in done if w["tags"].get("name") == n))
            try:
                out.append({"names": names, "ways": [w["id"] for w in done], "perimeter": osm_geo.perimeter(ring, tol_m=3)})
            except SystemExit:
                skipped += [w["id"] for w in done]   # un pezzetto di pochi metri: troppo piccolo per un poligono
    if skipped:
        print(name, "way troppo corte, saltate:", skipped)
    return sorted(out, key=lambda g: -osm_geo.area_km2(g["perimeter"]))


tp_groups, ped_groups = street_groups(TP_NAME, join_m=45, close_m=24), street_groups(PED_NAME, join_m=30, close_m=18)

ODBL_PENDING = ("Map outline from OpenStreetMap (relation 19152960 «ZTL Centrale»), to be checked against the city's official open data (5T «Perimetro, varchi e orari ZTL»), which can't be downloaded from here. Gate positions are not in the map yet.",
                "Perimetro da OpenStreetMap (relazione 19152960 «ZTL Centrale»), da verificare con i dati aperti ufficiali (5T «Perimetro, varchi e orari ZTL»), che da qui non si scaricano. Le posizioni dei varchi non sono ancora sulla mappa.",
                "Grenze aus OpenStreetMap (Relation 19152960 «ZTL Centrale»), mit den offiziellen offenen Daten (5T «Perimetro, varchi e orari ZTL») abzugleichen, die sich von hier nicht laden lassen. Die Kamerastandorte fehlen noch auf der Karte.")
TEXT_PENDING = ("The city's and GTT's pages could not be downloaded from here: the quoted wording comes from search-engine extracts of the official page, cross-checked with several guides. To be re-read on the page itself.",
                "Le pagine del Comune e di GTT da qui non si scaricano: la frase citata viene dagli estratti di ricerca della pagina ufficiale, confrontati con diverse guide. Da rileggere sulla pagina stessa.",
                "Die Seiten der Stadt und von GTT ließen sich von hier nicht laden: Der zitierte Wortlaut stammt aus Suchmaschinen-Auszügen der offiziellen Seite, mit mehreren Ratgebern abgeglichen. Auf der Seite selbst nachzulesen.")
OTHER_ZONES = ("Not on the map yet: ZTL Area Romana (Quadrilatero, closed 9 pm–7:30 am every day, from 7:30 pm in piazza Emanuele Filiberto), ZTL Valentino (park roads, closed 24 h, extension approved in March 2026), the night ZTL on the road up to Monte dei Cappuccini (11 pm–7 am every day) and the pedestrian area of Borgo Campidoglio (24 h). Watch the signs at the gates.",
               "Non ancora sulla mappa: ZTL Area Romana (Quadrilatero, chiusa 21–7:30 tutti i giorni, dalle 19:30 in piazza Emanuele Filiberto), ZTL Valentino (viali del parco, chiusa h24, ampliamento approvato a marzo 2026), la ZTL notturna della salita al Monte dei Cappuccini (23–7 tutti i giorni) e l'area pedonale di Borgo Campidoglio (h24). Guarda i cartelli ai varchi.",
               "Noch nicht auf der Karte: ZTL Area Romana (Quadrilatero, täglich 21–7:30 Uhr gesperrt, auf der Piazza Emanuele Filiberto ab 19:30), ZTL Valentino (Parkstraßen, rund um die Uhr gesperrt, Erweiterung im März 2026 beschlossen), die Nacht-ZTL an der Auffahrt zum Monte dei Cappuccini (täglich 23–7 Uhr) und die Fußgängerzone Borgo Campidoglio (rund um die Uhr). Achte auf die Schilder an den Kameras.")

links = [link("City of Turin: ZTL Centrale (hours, exemptions)", "Comune di Torino: ZTL Centrale (orari, esenzioni)",
              "Stadt Turin: ZTL Centrale (Zeiten, Ausnahmen)", SCHEDA),
         link("City of Turin: applying for a ZTL permit", "Comune di Torino: richiedere il permesso ZTL",
              "Stadt Turin: ZTL-Genehmigung beantragen", PERMESSI),
         link("City of Turin: ZTL permits for fully electric cars", "Comune di Torino: permessi ZTL per veicoli elettrici puri",
              "Stadt Turin: ZTL-Genehmigungen für reine Elektroautos", ELETTRICI),
         link("GTT: hotel guests in the ZTL", "GTT: utenti che pernottano in strutture alberghiere",
              "GTT: Hotelgäste in der ZTL", GTT_HOTEL),
         link("GTT: vehicles exempt from the ZTL", "GTT: elenco veicoli esentati", "GTT: von der ZTL befreite Fahrzeuge", GTT_ESENTI),
         link("City of Turin open data: ZTL perimeter, gates and hours (5T, CC BY 4.0)",
              "aperTO, dati aperti: perimetro, varchi e orari ZTL (5T, CC BY 4.0)",
              "Offene Daten der Stadt Turin: ZTL-Grenze, Kameras und Zeiten (5T, CC BY 4.0)", OPEN_DATA),
         link(f"OpenStreetMap: relation {OSM_CENTRALE} «ZTL Centrale» (ODbL)", f"OpenStreetMap: relazione {OSM_CENTRALE} «ZTL Centrale» (ODbL)",
              f"OpenStreetMap: Relation {OSM_CENTRALE} «ZTL Centrale» (ODbL)", osm_geo.osm_url("relation", OSM_CENTRALE))]

pending_centrale = [ODBL_PENDING] + ([] if official else [TEXT_PENDING]) + [
    ("Only the morning hours are enforced here: from 10:30 am on weekdays, and all day on Saturday, Sunday and holidays, the ZTL Centrale is open. Inside it, the bus-only streets (7 am–8 pm), the pedestrian streets (24 h) and, at night, Area Romana stay closed.",
     "Qui valgono solo le ore del mattino: dalle 10:30 nei feriali, e tutto il giorno sabato, domenica e festivi, la ZTL Centrale è aperta. Al suo interno restano chiuse le strade riservate ai mezzi pubblici (7–20), quelle pedonali (h24) e, di notte, l'Area Romana.",
     "Hier gelten nur die Morgenstunden: Ab 10:30 Uhr an Werktagen und ganztags an Samstagen, Sonn- und Feiertagen ist die ZTL Centrale offen. Darin bleiben die Busstraßen (7–20 Uhr), die Fußgängerstraßen (rund um die Uhr) und nachts die Area Romana gesperrt."),
    ("Summer: in 2026 the city switched the ZTL Centrale off from 10 to 23 August by a council decision; the dates change every year and are announced in June–July. GateLR doesn't model it.",
     "Estate: nel 2026 il Comune ha spento la ZTL Centrale dal 10 al 23 agosto con una delibera di Giunta; le date cambiano ogni anno e sono annunciate a giugno–luglio. GateLR non ne tiene conto.",
     "Sommer: 2026 hat die Stadt die ZTL Centrale vom 10. bis 23. August per Beschluss abgeschaltet; die Daten ändern sich jedes Jahr und werden im Juni–Juli bekannt gegeben. GateLR berücksichtigt das nicht."),
    ("24 June (St John, Turin's patron saint): GateLR counts it as a holiday, so the ZTL Centrale is off. Confirmed only by quotidianopiemontese.it (2019: «di consueto la ZTL centrale non sarà attiva»), not by a current official notice.",
     "24 giugno (San Giovanni, patrono di Torino): GateLR lo conta come festivo, quindi la ZTL Centrale è spenta. Confermato solo da quotidianopiemontese.it (2019: «di consueto la ZTL centrale non sarà attiva»), non da un avviso ufficiale recente.",
     "24. Juni (Johannes der Täufer, Stadtpatron): GateLR zählt ihn als Feiertag, die ZTL Centrale ist also aus. Nur von quotidianopiemontese.it bestätigt (2019), nicht von einer aktuellen amtlichen Mitteilung."),
    ("Electric cars are not exempt automatically: they need a free permit (Italian owners) or a retroactive exemption sent to GTT within 10 days, at most 12 a year.",
     "Le auto elettriche non sono esenti in automatico: serve il permesso gratuito (per i proprietari italiani) o un'esenzione a posteriori inviata a GTT entro 10 giorni, al massimo 12 all'anno.",
     "Elektroautos sind nicht automatisch befreit: Sie brauchen die kostenlose Genehmigung (für italienische Halter) oder eine nachträgliche Befreiung, binnen 10 Tagen bei GTT, höchstens 12 pro Jahr."),
    ("Motorbikes and mopeds may enter without a permit if at least Euro 1 and four-stroke (GTT list of exempt vehicles), but not the bus-only streets or pedestrian areas.",
     "Moto e ciclomotori entrano senza permesso se almeno Euro 1 e a 4 tempi (elenco GTT dei veicoli esentati), ma non nelle strade riservate ai mezzi pubblici né nelle aree pedonali.",
     "Motorräder und Mopeds dürfen ohne Genehmigung hinein, wenn mindestens Euro 1 und Viertakter (GTT-Liste), aber nicht in die Busstraßen oder Fußgängerzonen."),
    OTHER_ZONES,
    ("Fine for entering without authorisation: €83–332 under art. 7 of the Highway Code (30% less if paid within 5 days); figure from non-official guides.",
     "Multa per l'ingresso senza autorizzazione: 83–332 € (art. 7 del Codice della strada; 30% in meno se pagata entro 5 giorni); cifra da guide non ufficiali.",
     "Bußgeld für die Einfahrt ohne Berechtigung: 83–332 € (Art. 7 StVO; 30 % weniger bei Zahlung binnen 5 Tagen); Angabe aus inoffiziellen Ratgebern."),
]

zones = [{
    "id": "torino-centrale", "name": "Centrale · City Centre ZTL", "name_it": "Centrale · ZTL del centro", "name_de": "Centrale · ZTL Innenstadt",
    "kind": "restricted",
    "summary": "Closed to cars without a permit Monday to Friday, 7:30–10:30 am only; open in the afternoon, at weekends and on holidays. There's no day ticket: if your hotel inside the ZTL is registered with GTT, fill in the request at check-in; if you park in a public garage inside, give your plate to the attendant by 11 am.",
    "summary_it": "Chiusa alle auto senza permesso dal lunedì al venerdì, solo dalle 7:30 alle 10:30; aperta il pomeriggio, nel fine settimana e nei festivi. Non c'è un ticket giornaliero: se il tuo hotel dentro la ZTL è registrato presso GTT, compila la richiesta al check-in; se parcheggi in un garage pubblico dentro, dai la targa al gestore entro le 11.",
    "summary_de": "Für Autos ohne Genehmigung nur Montag bis Freitag von 7:30 bis 10:30 Uhr gesperrt; nachmittags, am Wochenende und an Feiertagen offen. Ein Tagesticket gibt es nicht: Ist dein Hotel in der ZTL bei GTT registriert, füllst du den Antrag beim Check-in aus; parkst du in einer öffentlichen Garage innen, gib dem Personal bis 11 Uhr dein Kennzeichen.",
    "perimeter": centrale, "gates": [],
    "windows": [{"weekdays": [2, 3, 4, 5, 6], "start": 7 * 60 + 30, "end": 10 * 60 + 30}],
    "freeOnHolidays": True, "exemptFuels": [], "hotelCanRegister": True,
    "source": source(Q_CENTRALE, ("from 7:30 to 10:30 am on all working days (Saturday excluded)",
                                  "von 7:30 bis 10:30 Uhr an allen Werktagen (außer Samstag)"), links, pending_centrale)}]

tp_pending = [("Streets from OpenStreetMap (zone:traffic:name «Strade riservate al Trasporto Pubblico»); the list may be incomplete: GTT also names via Pietro Micca among the reserved streets. Bus lanes on other streets are not on the map.",
               "Strade da OpenStreetMap (zone:traffic:name «Strade riservate al Trasporto Pubblico»); l'elenco può essere incompleto: GTT cita anche via Pietro Micca tra le vie riservate. Le corsie bus sulle altre strade non sono sulla mappa.",
               "Straßen aus OpenStreetMap (zone:traffic:name «Strade riservate al Trasporto Pubblico»); die Liste kann unvollständig sein: GTT nennt auch die Via Pietro Micca. Busspuren auf anderen Straßen sind nicht auf der Karte.")] + \
             ([] if official else [TEXT_PENDING]) + [
              ("Hotel guests: free passage through the reserved streets only on the day of arrival and departure (GTT).",
               "Ospiti degli hotel: transito libero nelle vie riservate solo il giorno di arrivo e di partenza (GTT).",
               "Hotelgäste: freie Durchfahrt durch die Busstraßen nur am An- und Abreisetag (GTT).")]
for i, g in enumerate(tp_groups, 1):
    main = g["names"][0] if g["names"] else "Bus street"
    other = [n for n in g["names"][1:]][:2]
    label = main + (" and nearby" if other else "")
    label_it = main + (" e vie vicine" if other else "")
    label_de = main + (" und Umgebung" if other else "")
    zones.append({
        "id": f"torino-tp-{i}", "name": f"{label} · bus-only street", "name_it": f"{label_it} · strada riservata ai mezzi pubblici",
        "name_de": f"{label_de} · Busstraße", "kind": "restricted",
        "summary": "Reserved for buses and trams every day from 7 am to 8 pm, holidays included; taxis may use it. Outside those hours it follows the ZTL Centrale.",
        "summary_it": "Riservata a bus e tram tutti i giorni dalle 7 alle 20, festivi compresi; i taxi possono passare. Fuori orario vale la ZTL Centrale.",
        "summary_de": "Täglich von 7 bis 20 Uhr Bussen und Straßenbahnen vorbehalten, auch an Feiertagen; Taxis dürfen durch. Außerhalb dieser Zeit gilt die ZTL Centrale.",
        "perimeter": g["perimeter"], "gates": [],
        "windows": [{"weekdays": EVERY_DAY, "start": 7 * 60, "end": 20 * 60}],
        "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": True,
        "source": source(Q_TP, ("The public transport ZTL is closed to traffic and parking from 7 am to 8 pm every day, holidays included.",
                                "Die ZTL Trasporto Pubblico ist täglich von 7 bis 20 Uhr für Verkehr und Parken gesperrt, auch an Feiertagen."),
                         links[:1] + links[3:5] + [link("OpenStreetMap ways: " + ", ".join(g["names"][:3]), "Way OpenStreetMap: " + ", ".join(g["names"][:3]),
                                                       "OpenStreetMap-Wege: " + ", ".join(g["names"][:3]), osm_geo.osm_url("way", g["ways"][0]))],
                         tp_pending, ordinance="Ordinanza n. 2455 del 29/05/2012 (orario ZTL Trasporto Pubblico)")})

pedestrian = [{"id": f"to-ap-{i}", "name": (g["names"][0] if g["names"] else "Area pedonale"), "perimeter": g["perimeter"]}
              for i, g in enumerate(ped_groups, 1)]

city = {"id": "torino", "name": "Turin", "name_it": "Torino", "name_de": "Turin",
        "center": {"lat": 45.0712, "lon": 7.6857}, "localHolidays": ["06-24"],
        "pedestrian": pedestrian, "zones": zones, "status": "draft",
        "license": "Hours and rules: Comune di Torino and GTT pages. Perimeters and streets: " + osm_geo.ODBL
                   + " (approximate, not official; the official open data of the City of Turin/5T, CC BY 4.0, are still to be downloaded)."}

# Controlli: un punto famoso dentro, la stazione fuori
assert osm_geo.contains(centrale, 45.0712, 7.6857), "Piazza Castello deve essere nella ZTL Centrale"
assert osm_geo.contains(centrale, 45.0677, 7.6826), "Piazza San Carlo deve essere nella ZTL Centrale"
assert not osm_geo.contains(centrale, 45.0622, 7.6785), "Porta Nuova (stazione) deve essere fuori"
assert not osm_geo.contains(centrale, 45.0717, 7.6650), "Porta Susa (stazione) deve essere fuori"
assert 1.5 < osm_geo.area_km2(centrale) < 4, osm_geo.area_km2(centrale)
for z in zones[1:]:
    assert all(osm_geo.contains(centrale, p["lat"], p["lon"]) or osm_geo.distance_m(centrale, p["lat"], p["lon"]) < 60
               for p in z["perimeter"]), z["id"] + " fuori dalla ZTL Centrale"
assert any(osm_geo.contains(a["perimeter"], 45.07369, 7.67804) or osm_geo.distance_m(a["perimeter"], 45.07369, 7.67804) < 8
           for a in pedestrian), "via Garibaldi deve essere pedonale"

ready = official is not None and all(len(z["perimeter"]) >= 4 for z in zones)
out = ROOT / ("Resources/Cities/torino.json" if ready else "data/drafts/torino.json")
(ROOT / ("data/drafts/torino.json" if ready else "Resources/Cities/torino.json")).unlink(missing_ok=True)
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), "testi:", where, [(z["id"], len(z["perimeter"])) for z in zones], "pedonali:", len(pedestrian))
