#!/usr/bin/env python3
# Costruisce la scheda di Torino (fonti e date in docs/fonti-torino.md).
#
# Zone nella scheda:
#  - ZTL Centrale: lun–ven 7:30–10:30 («giorni feriali (sabato escluso)»: sabato, domenica e festivi spenta).
#    Perimetro: relazione OSM 19152960 «ZTL Centrale» (contorno «outer»), © OpenStreetMap contributors, ODbL 1.0,
#    controllata sulla mappa ufficiale del Comune (linea verde): i vertici OSM che stanno fuori dalla ZTL della mappa
#    per più di 20 m sono tolti (in pratica un pezzo di piazza della Repubblica, che il Comune esclude).
#    Varchi: i 27 pallini «Porte elettroniche» sul bordo della mappa, ognuno sul nodo OSM più vicino della strada.
#  - Strade riservate al trasporto pubblico: tutti i giorni 7–20, festivi compresi. Geometria: le way OSM con
#    zone:traffic:name=«Strade riservate al Trasporto Pubblico», una zona per gruppo di strade collegate, area coperta
#    dalla strada (osm_geo.street_area con una chiusura minima); varchi: i pallini della mappa sulle strade del gruppo.
#  - ZTL Area Romana: tutti i giorni 21–7:30. Perimetro: il tratteggio della mappa ufficiale (Tools/torino_mappa.py).
#  - Aree pedonali (ZTL Pedonale, h24): le way OSM con zone:traffic:name=«ZTL Pedonale», come «pedestrian» della città.
# Non ancora nella scheda: ZTL Valentino (h24), aree Statuto e Valperga, ZTL notturna Monte dei Cappuccini (23–7),
# Borgo Campidoglio (pedonale h24). Vedi i punti in sospeso.
#
# Testi: le pagine del Comune e di GTT non si raggiungono dall'ambiente di lavoro. Le citazioni sono controllate sul
# testo delle pagine ufficiali copiato dall'utente il 25/10/2026 (data/raw/torino/comune-scheda-ztl-centrale-utente.txt,
# gtt-alberghi-utente.txt, con le schermate) e sulla legenda della mappa ufficiale (mappa-ztl-internet-testo.txt);
# le poche regole che non compaiono lì (10 giorni, parcheggi entro le 11) sono controllate sugli estratti di ricerca
# (ricerca-web-2026-10-25.txt) e dette tali nei punti in sospeso.
# Mappa: data/raw/torino/mappa-ztl-ufficiale.json, prodotto da Tools/torino_mappa.py dal PDF ufficiale.
# Non aggiorna manifest.json. Uso: python3 Tools/build_torino.py
import json, re
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


def must_contain(text, quote, where):
    if norm(quote) not in text:
        raise SystemExit(f"Citazione non trovata in {where}: {quote!r}")


# --- testi ufficiali (copiati dall'utente) e estratti di ricerca ---
def raw(name):
    return norm((RAW / name).read_text(encoding="utf-8"))


comune, gtt, legenda, notes = (raw("comune-scheda-ztl-centrale-utente.txt"), raw("gtt-alberghi-utente.txt"),
                               raw("mappa-ztl-internet-testo.txt"), raw("ricerca-web-2026-10-25.txt"))
MAPPA = json.loads((RAW / "mappa-ztl-ufficiale.json").read_text(encoding="utf-8"))

Q_CENTRALE = "dalle 7.30 alle 10.30 di tutti i giorni feriali (sabato escluso), sono vietate la circolazione e la sosta"
Q_PERIMETRO = ("corso Vittorio Emanuele II, piazza Carlo Felice, corso Re Umberto (tratto corso Vittorio Emanuele II-corso "
               "Matteotti), corso Matteotti (tratto corso Re Umberto-via Vittorio Amedeo II), via Vittorio Amedeo II , corso "
               "Palestro, corso Regina, piazza della Repubblica, viale Primo Maggio, viale Partigiani (tratto corso San "
               "Maurizio-viale Primo Maggio), corso San Maurizio, lungo Po Cadorna, piazza Vittorio Veneto, lungo Po Diaz, "
               "corso Cairoli, esclusi.")
Q_EURO = ["omologazione categoria EURO 3 o superiore (come riportato sul libretto di circolazione)",
          "omologazione categoria EURO 2 o superiore alimentati a GPL e/o Metano, anche trasformato successivamente all'immatricolazione"]
Q_PUNTI = ["L’accesso in ZTL Centrale è controllato con telecamere in 27 punti della città.",
           "La circolazione all'interno della ZTL Centrale nelle aree dove sono in vigore altre limitazioni è controllata con telecamere in 11 punti della città.",
           "nell'area Statuto, nell'area Valperga e l'accesso all'area Valentino, sono controllati con telecamere in 3 punti della città.",
           "Per sapere quali sono i 41 punti di controllo con telecamera"]
NORMATIVA = ["Deliberazione della Giunta Comunale mecc. 2010 00659 del 12 febbraio 2010",
             "Deliberazione della Giunta Comunale mecc. 2010 02058 del 27 aprile 2010",
             "Ordinanza Dirigenziale num. 2547 del 28 maggio 2010 e s.m.i.",
             "Ordinanza Dirigenziale num. 2455 del 29 maggio 2012"]
Q_HOTEL = ("i fruitori di strutture alberghiere (esclusivamente di quelle accreditate e regolarmente registrate in Piattaforma ZTL). "
           "Al momento del check-in presso l'albergo, gli stessi fruitori dovranno compilare la richiesta di autorizzazione al "
           "transito per il periodo di permanenza presso la struttura")
Q_HOTEL_TP = ("i transiti su Vie e Corsie Riservate esclusivamente il giorno di arrivo in Struttura ed il giorno di partenza dalla "
              "Struttura, per le giornate intermedie bisognerà rivolgersi all’Albergo per conoscere a quali varchi si è abilitati")
Q_HOTEL_EURO = "i veicoli di categoria inferiore all'Euro 3 se non muniti di impianto GPL ad eccezione dell’Euro 0 GPL/Metano non esentabili"
Q_TP = "Strade riservate al Trasporto Pubblico (chiusura al transito e alla sosta: dalle 7:00 alle 20:00"
Q_AR = "ZTL Area Romana (chiusura al transito e alla sosta: dalle 21:00 alle 7:30"
Q_PED = "ZTL Pedonale (chiusura al transito e alla sosta: dalle 0:00 alle 24:00"
for q in [Q_CENTRALE, Q_PERIMETRO, *Q_EURO, *Q_PUNTI, *NORMATIVA, "regolare permesso di circolazione rilasciato dalla Città o dalla soc. GTT spa"]:
    must_contain(comune, q, "comune-scheda-ztl-centrale-utente.txt")
for q in [Q_HOTEL, Q_HOTEL_TP, Q_HOTEL_EURO]:
    must_contain(gtt, q, "gtt-alberghi-utente.txt")
for q in [Q_TP, Q_AR, Q_PED, "ZTL Centrale (chiusura al transito e alla sosta dalle 7:30 alle 10:30 )"]:
    must_contain(legenda, q, "mappa-ztl-internet-testo.txt")
for q in ["sono tassativamente 10 (dieci) - dal primo giorno di transito compreso", "entro e non oltre le ore 11.00",
          "motoveicoli, se Euro 1, a 4 tempi", "dalle 21:00 alle 7:30 del giorno successivo", "tutti i giorni, festivi compresi",
          "La ZTL Trasporto Pubblico è chiusa al transito e alla sosta dalle 7.00 alle 20.00 di tutti i giorni, compresi i festivi.",
          'Restano infatti attive le ZTL "Trasporto Pubblico", "Pedonale", "Area Romana" e "Valentino"',
          "di consueto la ZTL centrale non sarà attiva"]:
    must_contain(notes, q, "ricerca-web-2026-10-25.txt")
assert MAPPA["points_count"] == {"accesso": 27, "interno": 11, "esterno": 3}, MAPPA["points_count"]   # 27 + 11 + 3 = 41
ORDINANZE = ("DGC mecc. 2010 00659 (12/02/2010) e 2010 02058 (27/04/2010); Ordinanza Dirigenziale n. 2547 del 28/05/2010 "
             "e s.m.i.; Ordinanza Dirigenziale n. 2455 del 29/05/2012")


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
osm_ring = osm_geo.outer_ring(osm_geo.relation(els, OSM_CENTRALE))
map_ring = MAPPA["centrale_map"]                      # [lon, lat], la ZTL Centrale disegnata sulla mappa ufficiale
outside_map = lambda p: not osm_geo.inside_lonlat(map_ring, p[0], p[1]) and osm_geo.distance_m(
    [{"lat": q[1], "lon": q[0]} for q in map_ring], p[1], p[0]) > 20


def spliced(ring, bad):
    """Il contorno OSM in cui ogni tratto di vertici «bad» è sostituito dal tratto corrispondente della mappa ufficiale
    (dal punto della mappa più vicino all'ultimo vertice buono prima del tratto a quello più vicino al primo dopo)"""
    ring = ring[:-1] if ring[0] == ring[-1] else ring
    n = len(ring)
    start = next(i for i in range(n) if not bad(ring[i]))
    ring = ring[start:] + ring[:start]                   # si parte da un vertice buono
    mr = map_ring[:-1]
    near = lambda p: min(range(len(mr)), key=lambda k: (mr[k][0] - p[0]) ** 2 * 0.5 + (mr[k][1] - p[1]) ** 2)
    out, i, cut = [], 0, 0
    while i < n:
        if not bad(ring[i]):
            out.append(ring[i]); i += 1; continue
        j = i
        while j < n and bad(ring[j]):
            j += 1
        a, b = near(out[-1]), near(ring[j % n])
        fwd_ = [mr[k % len(mr)] for k in range(a, b + (len(mr) if b < a else 0) + 1)]
        bwd_ = [mr[k % len(mr)] for k in range(a, b - (len(mr) if b > a else 0) - 1, -1)]
        out += min(fwd_, bwd_, key=len)
        cut += j - i; i = j
    return out + out[:1], cut


osm_fixed, dropped = spliced(osm_ring, outside_map)
centrale = osm_geo.perimeter(osm_fixed, tol_m=5)
print(f"contorno OSM: {dropped} vertici fuori dalla mappa ufficiale di oltre 20 m, sostituiti dal tratto della mappa")


def gate(p, prefix, i):
    return {"id": f"{prefix}-{i}", "name": p["strada"], "location": {"lat": p["node_lat"], "lon": p["node_lon"]}}


ACCESSI = [p for p in MAPPA["points"] if p["kind"] == "accesso"]
INTERNI = [p for p in MAPPA["points"] if p["kind"] == "interno"]


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

MAP_PDF = "https://www.comune.torino.it/schede-informative/ztl-centrale"
MAP_PENDING = ("Outline from OpenStreetMap (relation 19152960 «ZTL Centrale»), checked against the city's official ZTL map (PDF linked from the ZTL Centrale page): they match within a few metres, except a corner of piazza della Repubblica that the city excludes and that has been cut. Camera positions are the 27 «electronic gates» on the edge of that map, placed on the nearest street (the map has no coordinates: about ±30 m).",
               "Perimetro da OpenStreetMap (relazione 19152960 «ZTL Centrale»), controllato sulla mappa ufficiale della ZTL (PDF linkato dalla scheda «ZTL Centrale»): coincidono a pochi metri, tranne un angolo di piazza della Repubblica che il Comune esclude e che è stato tolto. Le telecamere sono le 27 «porte elettroniche» sul bordo di quella mappa, messe sulla strada più vicina (la mappa non ha coordinate: circa ±30 m).",
               "Grenze aus OpenStreetMap (Relation 19152960 «ZTL Centrale»), mit dem offiziellen ZTL-Plan der Stadt (PDF auf der Seite «ZTL Centrale») abgeglichen: Sie stimmen auf wenige Meter überein, bis auf eine Ecke der Piazza della Repubblica, die die Stadt ausnimmt und die entfernt wurde. Die Kameras sind die 27 «elektronischen Tore» am Rand dieses Plans, auf die nächste Straße gesetzt (der Plan hat keine Koordinaten: etwa ±30 m).")
SNIPPET_PENDING = ("The 10-day retroactive exemption and the 11 am deadline for public garages come from search-engine extracts of the official pages, not from the page text itself.",
                   "L'esenzione a posteriori entro 10 giorni e il termine delle 11 per i parcheggi in struttura vengono dagli estratti di ricerca delle pagine ufficiali, non dal testo della pagina.",
                   "Die nachträgliche Befreiung binnen 10 Tagen und die 11-Uhr-Frist für Parkhäuser stammen aus Suchmaschinen-Auszügen der offiziellen Seiten, nicht aus dem Seitentext selbst.")
OTHER_ZONES = ("Not on the map yet: ZTL Valentino (park roads, closed 24 h; the official map shows its entrance camera; extension approved in March 2026), the Statuto and Valperga areas (one camera each on the official map, rules not described on the city page), the night ZTL on the road up to Monte dei Cappuccini (11 pm–7 am every day) and the pedestrian area of Borgo Campidoglio (24 h). Watch the signs at the gates.",
               "Non ancora sulla mappa: ZTL Valentino (viali del parco, chiusa h24; la mappa ufficiale mostra la telecamera all'ingresso; ampliamento approvato a marzo 2026), le aree Statuto e Valperga (una telecamera ciascuna sulla mappa ufficiale, regole non descritte nella scheda), la ZTL notturna della salita al Monte dei Cappuccini (23–7 tutti i giorni) e l'area pedonale di Borgo Campidoglio (h24). Guarda i cartelli ai varchi.",
               "Noch nicht auf der Karte: ZTL Valentino (Parkstraßen, rund um die Uhr gesperrt; der offizielle Plan zeigt die Kamera an der Einfahrt; Erweiterung im März 2026 beschlossen), die Bereiche Statuto und Valperga (je eine Kamera auf dem offiziellen Plan, Regeln auf der Seite nicht beschrieben), die Nacht-ZTL an der Auffahrt zum Monte dei Cappuccini (täglich 23–7 Uhr) und die Fußgängerzone Borgo Campidoglio (rund um die Uhr). Achte auf die Schilder an den Kameras.")
EURO = ("Permits and hotel authorisations are only for cars that are at least Euro 3, or at least Euro 2 running on LPG/methane (city page); GTT: vehicles below Euro 3 without LPG cannot be authorised, nor Euro 0 LPG/methane. Also excluded: vehicles without valid inspection or insurance, or impounded.",
        "Permessi e autorizzazioni degli hotel valgono solo per auto almeno Euro 3, o almeno Euro 2 a GPL/metano (scheda del Comune); per GTT non si autorizzano i veicoli sotto Euro 3 senza GPL, né gli Euro 0 GPL/metano. Esclusi anche i veicoli senza revisione o assicurazione valida, o sotto fermo amministrativo.",
        "Genehmigungen und Hotel-Freigaben gibt es nur für Autos ab Euro 3 oder ab Euro 2 mit LPG/Erdgas (Seite der Stadt); laut GTT werden Fahrzeuge unter Euro 3 ohne LPG nicht freigegeben, auch nicht Euro 0 LPG/Erdgas. Ebenfalls ausgeschlossen: Fahrzeuge ohne gültige Hauptuntersuchung oder Versicherung oder mit Stilllegung.")

links = [link("City of Turin: ZTL Centrale (hours, perimeter, permits, official map)", "Comune di Torino: ZTL Centrale (orari, perimetro, permessi, mappa ufficiale)",
              "Stadt Turin: ZTL Centrale (Zeiten, Grenze, Genehmigungen, offizieller Plan)", SCHEDA),
         link("GTT: hotel guests in the ZTL", "GTT: utenti che pernottano in strutture alberghiere",
              "GTT: Hotelgäste in der ZTL", GTT_HOTEL),
         link("City of Turin: applying for a ZTL permit", "Comune di Torino: richiedere il permesso ZTL",
              "Stadt Turin: ZTL-Genehmigung beantragen", PERMESSI),
         link("City of Turin: ZTL permits for fully electric cars", "Comune di Torino: permessi ZTL per veicoli elettrici puri",
              "Stadt Turin: ZTL-Genehmigungen für reine Elektroautos", ELETTRICI),
         link("GTT: vehicles exempt from the ZTL", "GTT: elenco veicoli esentati", "GTT: von der ZTL befreite Fahrzeuge", GTT_ESENTI),
         link(f"OpenStreetMap: relation {OSM_CENTRALE} «ZTL Centrale» (ODbL)", f"OpenStreetMap: relazione {OSM_CENTRALE} «ZTL Centrale» (ODbL)",
              f"OpenStreetMap: Relation {OSM_CENTRALE} «ZTL Centrale» (ODbL)", osm_geo.osm_url("relation", OSM_CENTRALE))]

pending_centrale = [MAP_PENDING, (
     "Only the morning hours are enforced here: from 10:30 am on weekdays, and all day on Saturday, Sunday and holidays, the ZTL Centrale is open. Inside it, the bus-only streets (7 am–8 pm), the pedestrian streets (24 h) and, at night, Area Romana stay closed.",
     "Qui valgono solo le ore del mattino: dalle 10:30 nei feriali, e tutto il giorno sabato, domenica e festivi, la ZTL Centrale è aperta. Al suo interno restano chiuse le strade riservate ai mezzi pubblici (7–20), quelle pedonali (h24) e, di notte, l'Area Romana.",
     "Hier gelten nur die Morgenstunden: Ab 10:30 Uhr an Werktagen und ganztags an Samstagen, Sonn- und Feiertagen ist die ZTL Centrale offen. Darin bleiben die Busstraßen (7–20 Uhr), die Fußgängerstraßen (rund um die Uhr) und nachts die Area Romana gesperrt."),
    ("Hotel guests: only hotels registered on GTT's «Piattaforma ZTL» can authorise you; you fill in the request at check-in, for your whole stay. Ask the hotel before arriving whether it is registered.",
     "Ospiti degli hotel: possono autorizzarti solo gli alberghi registrati sulla «Piattaforma ZTL» di GTT; la richiesta si compila al check-in, per tutto il soggiorno. Chiedi all'hotel prima di arrivare se è registrato.",
     "Hotelgäste: Nur Hotels, die auf der «Piattaforma ZTL» von GTT registriert sind, können dich freischalten; den Antrag füllst du beim Check-in aus, für den ganzen Aufenthalt. Frag das Hotel vor der Anreise, ob es registriert ist."),
    EURO, SNIPPET_PENDING,
    ("Summer: in 2026 the city switched the ZTL Centrale off from 10 to 23 August by a council decision; the dates change every year and are announced in June–July. GateLR doesn't model it.",
     "Estate: nel 2026 il Comune ha spento la ZTL Centrale dal 10 al 23 agosto con una delibera di Giunta; le date cambiano ogni anno e sono annunciate a giugno–luglio. GateLR non ne tiene conto.",
     "Sommer: 2026 hat die Stadt die ZTL Centrale vom 10. bis 23. August per Beschluss abgeschaltet; die Daten ändern sich jedes Jahr und werden im Juni–Juli bekannt gegeben. GateLR berücksichtigt das nicht."),
    ("24 June (St John, Turin's patron saint): the city page only says «working days», and only a non-official source (2019) says the ZTL Centrale is usually off that day, so GateLR shows it as active. Check the city's notice for that day.",
     "24 giugno (San Giovanni, patrono di Torino): la scheda del Comune dice solo «giorni feriali» e soltanto una fonte non ufficiale (2019) dice che di consueto quel giorno la ZTL Centrale non è attiva, quindi GateLR la mostra attiva. Controlla l'avviso del Comune per quel giorno.",
     "24. Juni (Johannes der Täufer, Stadtpatron): Die Seite der Stadt spricht nur von «Werktagen», und nur eine inoffizielle Quelle (2019) sagt, dass die ZTL Centrale an dem Tag üblicherweise aus ist; GateLR zeigt sie daher als aktiv. Prüfe die Mitteilung der Stadt für diesen Tag."),
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
    "summary": "Closed to cars without a permit Monday to Friday, 7:30–10:30 am only; open in the afternoon, at weekends and on holidays. There's no day ticket: if your hotel inside the ZTL is registered on GTT's ZTL platform, fill in the request at check-in for your whole stay (cars below Euro 3, unless LPG/methane Euro 2 or newer, can't be authorised); if you park in a public garage inside, give your plate to the attendant by 11 am.",
    "summary_it": "Chiusa alle auto senza permesso dal lunedì al venerdì, solo dalle 7:30 alle 10:30; aperta il pomeriggio, nel fine settimana e nei festivi. Non c'è un ticket giornaliero: se il tuo hotel dentro la ZTL è registrato sulla Piattaforma ZTL di GTT, compila la richiesta al check-in per tutto il soggiorno (le auto sotto Euro 3, salvo GPL/metano da Euro 2, non si possono autorizzare); se parcheggi in un garage pubblico dentro, dai la targa al gestore entro le 11.",
    "summary_de": "Für Autos ohne Genehmigung nur Montag bis Freitag von 7:30 bis 10:30 Uhr gesperrt; nachmittags, am Wochenende und an Feiertagen offen. Ein Tagesticket gibt es nicht: Ist dein Hotel in der ZTL auf der ZTL-Plattform von GTT registriert, füllst du beim Check-in den Antrag für den ganzen Aufenthalt aus (Autos unter Euro 3, außer LPG/Erdgas ab Euro 2, können nicht freigegeben werden); parkst du in einer öffentlichen Garage innen, gib dem Personal bis 11 Uhr dein Kennzeichen.",
    "perimeter": centrale, "gates": [gate(p, "to-c", i) for i, p in enumerate(ACCESSI, 1)],
    "windows": [{"weekdays": [2, 3, 4, 5, 6], "start": 7 * 60 + 30, "end": 10 * 60 + 30}],
    "freeOnHolidays": True, "exemptFuels": [], "hotelCanRegister": True,
    "source": source(Q_CENTRALE, ("from 7:30 to 10:30 am on all working days (Saturday excluded), driving and parking are prohibited",
                                  "von 7:30 bis 10:30 Uhr an allen Werktagen (außer Samstag) sind Fahren und Parken verboten"),
                     links, pending_centrale, ordinance=ORDINANZE)}]

# --- ZTL Area Romana (perimetro dalla mappa ufficiale) ---
area_romana = osm_geo.perimeter(MAPPA["area_romana"], tol_m=4)
ar_gates = [p for p in INTERNI if osm_geo.distance_m(MAPPA["area_romana"], p["lat"], p["lon"]) < 45]   # il pallino copre il tratteggio
zones.append({
    "id": "torino-area-romana", "name": "Area Romana · Quadrilatero night ZTL", "name_it": "Area Romana · ZTL notturna del Quadrilatero",
    "name_de": "Area Romana · Nacht-ZTL Quadrilatero", "kind": "restricted",
    "summary": "The Roman quarter (Quadrilatero) is closed to traffic and parking every night from 9 pm to 7:30 am, holidays included; only authorised vehicles may enter. In the daytime it follows the ZTL Centrale.",
    "summary_it": "Il Quadrilatero romano è chiuso al transito e alla sosta tutte le notti dalle 21 alle 7:30, festivi compresi; entrano solo i veicoli autorizzati. Di giorno vale la ZTL Centrale.",
    "summary_de": "Das römische Viertel (Quadrilatero) ist jede Nacht von 21 bis 7:30 Uhr für Verkehr und Parken gesperrt, auch an Feiertagen; nur berechtigte Fahrzeuge dürfen hinein. Tagsüber gilt die ZTL Centrale.",
    "perimeter": area_romana, "gates": [gate(p, "to-ar", i) for i, p in enumerate(ar_gates, 1)],
    "windows": [{"weekdays": EVERY_DAY, "start": 21 * 60, "end": 7 * 60 + 30}],
    "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": False,
    "source": source(Q_AR.split("(")[1], ("closed to traffic and parking: from 9 pm to 7:30 am",
                                          "Verkehrs- und Parkverbot: von 21:00 bis 7:30 Uhr"),
                     links[:2] + links[4:5], [
        ("Outline traced automatically from the dashed line on the city's official ZTL map (no coordinates; about ±20 m, a little less around the two cameras). Cameras: the two «electronic gates» of the map on its edge.",
         "Perimetro ricavato in automatico dal tratteggio della mappa ufficiale della ZTL (senza coordinate; circa ±20 m, un po' meno attorno alle due telecamere). Telecamere: le due «porte elettroniche» della mappa sul suo bordo.",
         "Grenze automatisch aus der gestrichelten Linie des offiziellen ZTL-Plans gewonnen (ohne Koordinaten; etwa ±20 m, an den zwei Kameras etwas weniger). Kameras: die zwei «elektronischen Tore» des Plans an ihrem Rand."),
        ("The map gives only the hours; «every day, holidays included» and the earlier start (7:30 pm) in piazza Emanuele Filiberto come from search-engine extracts of the city page. Loading and unloading: 10:30 am–4 pm.",
         "La mappa dà solo l'orario; «tutti i giorni, festivi compresi» e l'inizio anticipato (19:30) in piazza Emanuele Filiberto vengono dagli estratti di ricerca della scheda del Comune. Carico e scarico: 10:30–16.",
         "Der Plan nennt nur die Uhrzeit; «täglich, auch an Feiertagen» und der frühere Beginn (19:30 Uhr) auf der Piazza Emanuele Filiberto stammen aus Suchmaschinen-Auszügen der Seite der Stadt. Be- und Entladen: 10:30–16 Uhr."),
        ("Hotel guests: GTT's hotel page doesn't say whether the hotel authorisation covers the Area Romana at night: ask your hotel.",
         "Ospiti degli hotel: la pagina GTT sugli alberghi non dice se l'autorizzazione dell'hotel vale anche per l'Area Romana di notte: chiedi all'albergo.",
         "Hotelgäste: Die GTT-Seite zu Hotels sagt nicht, ob die Hotel-Freigabe nachts auch für die Area Romana gilt: frag dein Hotel.")],
                     page=SCHEDA, ordinance=ORDINANZE)})

tp_pending = [("Streets from OpenStreetMap (zone:traffic:name «Strade riservate al Trasporto Pubblico»), the same as the purple streets of the city's official map; bus lanes on other streets are not on the map. Cameras: the official map's «electronic gates» on these streets; three cameras inside the ZTL on the official map (near via Verdi, via Gramsci and via San Quintino) are not on any street shown here.",
               "Strade da OpenStreetMap (zone:traffic:name «Strade riservate al Trasporto Pubblico»), le stesse in viola sulla mappa ufficiale del Comune; le corsie bus sulle altre strade non sono sulla mappa. Telecamere: le «porte elettroniche» della mappa ufficiale su queste strade; tre telecamere interne della mappa ufficiale (vicino a via Verdi, via Gramsci e via San Quintino) non stanno su nessuna delle strade mostrate qui.",
               "Straßen aus OpenStreetMap (zone:traffic:name «Strade riservate al Trasporto Pubblico»), dieselben wie die violetten Straßen des offiziellen Plans; Busspuren auf anderen Straßen sind nicht auf der Karte. Kameras: die «elektronischen Tore» des offiziellen Plans auf diesen Straßen; drei Kameras innerhalb der ZTL auf dem offiziellen Plan (bei Via Verdi, Via Gramsci und Via San Quintino) liegen auf keiner der hier gezeigten Straßen."),
              ("The map legend gives only the hours; «every day, holidays included» comes from search-engine extracts of the city page.",
               "La legenda della mappa dà solo l'orario; «tutti i giorni, compresi i festivi» viene dagli estratti di ricerca della scheda del Comune.",
               "Die Legende des Plans nennt nur die Uhrzeit; «täglich, auch an Feiertagen» stammt aus Suchmaschinen-Auszügen der Seite der Stadt."),
              ("Hotel guests (GTT): passage through the reserved streets only on the day of arrival and the day of departure; on the days in between, ask the hotel which cameras you are enabled for.",
               "Ospiti degli hotel (GTT): transito nelle vie riservate solo il giorno di arrivo e quello di partenza; per i giorni intermedi chiedi all'albergo a quali varchi sei abilitato.",
               "Hotelgäste (GTT): Durchfahrt durch die Busstraßen nur am An- und am Abreisetag; für die Tage dazwischen frag das Hotel, für welche Kameras du freigeschaltet bist.")]
for i, g in enumerate(tp_groups, 1):
    main = g["names"][0] if g["names"] else "Bus street"
    other = [n for n in g["names"][1:]][:2]
    label = main + (" and nearby" if other else "")
    label_it = main + (" e vie vicine" if other else "")
    label_de = main + (" und Umgebung" if other else "")
    near = lambda p: osm_geo.contains(g["perimeter"], p["lat"], p["lon"]) or osm_geo.distance_m(g["perimeter"], p["lat"], p["lon"]) < 35
    tp_gates = [gate(p, f"to-tp{i}", k) for k, p in enumerate([p for p in ACCESSI + INTERNI if near(p)], 1)]
    zones.append({
        "id": f"torino-tp-{i}", "name": f"{label} · bus-only street", "name_it": f"{label_it} · strada riservata ai mezzi pubblici",
        "name_de": f"{label_de} · Busstraße", "kind": "restricted",
        "summary": "Reserved for buses and trams every day from 7 am to 8 pm, holidays included; taxis may use it. Outside those hours it follows the ZTL Centrale.",
        "summary_it": "Riservata a bus e tram tutti i giorni dalle 7 alle 20, festivi compresi; i taxi possono passare. Fuori orario vale la ZTL Centrale.",
        "summary_de": "Täglich von 7 bis 20 Uhr Bussen und Straßenbahnen vorbehalten, auch an Feiertagen; Taxis dürfen durch. Außerhalb dieser Zeit gilt die ZTL Centrale.",
        "perimeter": g["perimeter"], "gates": tp_gates,
        "windows": [{"weekdays": EVERY_DAY, "start": 7 * 60, "end": 20 * 60}],
        "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": True,
        "source": source(Q_TP.split("(")[1], ("closed to traffic and parking: from 7 am to 8 pm",
                                              "Verkehrs- und Parkverbot: von 7:00 bis 20:00 Uhr"),
                         links[:2] + links[4:5] + [link("OpenStreetMap ways: " + ", ".join(g["names"][:3]), "Way OpenStreetMap: " + ", ".join(g["names"][:3]),
                                                       "OpenStreetMap-Wege: " + ", ".join(g["names"][:3]), osm_geo.osm_url("way", g["ways"][0]))],
                         tp_pending, ordinance="Ordinanza Dirigenziale n. 2455 del 29/05/2012")})

pedestrian = [{"id": f"to-ap-{i}", "name": (g["names"][0] if g["names"] else "Area pedonale"), "perimeter": g["perimeter"]}
              for i, g in enumerate(ped_groups, 1)]

city = {"id": "torino", "name": "Turin", "name_it": "Torino", "name_de": "Turin",
        "center": {"lat": 45.0712, "lon": 7.6857},
        "pedestrian": pedestrian, "zones": zones, "status": "draft",
        "license": "Hours and rules: Comune di Torino and GTT pages and the city's official ZTL map. Perimeters and streets: " + osm_geo.ODBL
                   + " (checked against the official map; Area Romana and camera positions traced from that map; approximate, not official)."}

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

# varchi: tutti i 27 accessi sulla ZTL Centrale, a meno di 60 m dal suo bordo
assert len(zones[0]["gates"]) == 27
assert all(osm_geo.distance_m(centrale, g["location"]["lat"], g["location"]["lon"]) < 60 for g in zones[0]["gates"])
assert osm_geo.contains(area_romana, 45.0760, 7.6800), "via Sant'Agostino deve essere nell'Area Romana"
assert 0.04 < osm_geo.area_km2(area_romana) < 0.12, osm_geo.area_km2(area_romana)

out = ROOT / "Resources/Cities/torino.json"
(ROOT / "data/drafts/torino.json").unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), [(z["id"], len(z["perimeter"]), len(z["gates"])) for z in zones], "pedonali:", len(pedestrian),
      f"Centrale {osm_geo.area_km2(centrale):.2f} km², Area Romana {osm_geo.area_km2(area_romana) * 1e6:.0f} m²")
