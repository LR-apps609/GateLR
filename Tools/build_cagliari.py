#!/usr/bin/env python3
# Costruisce la scheda di Cagliari (fonti e date in docs/fonti-cagliari.md). Ogni frase citata o riassunta viene
# ricontrollata sul testo salvato in data/raw/cagliari/.
#
# FONTE NON UFFICIALE. Il Comune non pubblica orari né mappe delle ZTL: il regolamento (D.C.C. 42/2012, 27/2013 e 168 del
# 02/12/2025) rimanda orari (art. 31) e perimetri (art. 1 c. 2) a delibere di Giunta che non esistono nell'albo pretorio
# (tutti i titoli 2016–ottobre 2026 controllati); la vecchia pagina degli orari e il Geoportale non sono raggiungibili.
# Con l'approvazione del titolare, orari, nomi delle strade di confine e dei varchi vengono da accessibilitacentristorici.it
# (sito privato di servizi per i permessi; data/raw/cagliari/accessibilitacentristorici-cagliari.txt), incrociati con i tag
# OpenStreetMap vehicle:conditional delle strade e con le altre fonti non ufficiali (websearch-1-orari.txt). Ogni zona ha
# source.official = false e source.unofficialSource (app 1.16.2): il manifest la mette in «unofficialCities», che le app
# fino alla 1.16.1 non leggono. Le regole su hotel, ciclomotori, elettriche e disabili restano dal regolamento ufficiale.
#
# Geometria (© OpenStreetMap contributors, ODbL 1.0; API OSM con Tools/fetch_osm_api.py, ridotto in
# data/raw/geo/cagliari-ztl.json; la mappa del sito non ufficiale NON è usata):
#   Castello, Marina: relazioni OSM 14402165 «ZTL Castello» e 14402156 «ZTL Marina».
#   Villanova, Stampace Alto, Stampace Basso: anello che segue in ordine le strade di confine elencate (ogni strada percorsa
#   sulle sue way OSM tra l'incrocio con la precedente e quello con la successiva), cioè il perimetro sulle mezzerie.
#   Poetto (lungomare, «da piazza Arcipelaghi fino al canale adduttore delle Saline») non è disegnata: resta nei pending.
# Uso: python3 Tools/build_cagliari.py   (non tocca le altre città né manifest.json)
import heapq, json, math, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/cagliari"
CHECKED = "2026-10-27T17:00:00Z"
ALL, MON_FRI, SAT = [1, 2, 3, 4, 5, 6, 7], [2, 3, 4, 5, 6], [7]

P = "https://www.comune.cagliari.it/portale/page/it"
OFFICE = P + "/ztl_e_zone_pedonali?contentId=ORG9497"
PASSES = P + "/rilascio_pass_zone_a_traffico_limitato_ztl__persone_fisiche_it_1?contentId=SRV10350"
HOTELS = P + "/pass_ztl_per_strutture_ricettive?contentId=SRV10363"
RULES = "https://www.comune.cagliari.it/portale/protected/247459/0/def/ref/DOC77600I/"
ACS = "https://www.accessibilitacentristorici.it/ztl/sardegna/cagliari.html"
ACS_MAP = "https://www.accessibilitacentristorici.it/ztl/Sardinia/cagliari/mappa"
UNOFFICIAL = {"name": "accessibilitacentristorici.it", "url": ACS}


def flat(s):
    return re.sub(r"\s+", " ", s).strip()


TEXT = {p.stem: flat(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def check(file, *phrases):
    for q in phrases:
        if flat(q) not in TEXT[file]:
            raise SystemExit(f"{file}: frase non trovata: {q!r}")


# --- regole ufficiali (regolamento) ---
check("regolamento-ztl-2025",
      "deliberazione del Consiglio Comunale n.168 del 2 dicembre 2025",
      "a) Marina b) Castello c) Stampace Alto d) Stampace Basso e) Villanova f) Poetto",
      "Le competenze per la determinazione degli orari di limitazione sono attribuite alla Giunta Municipale che vi provvede con apposito atto.",
      "L'accesso e la sosta alle ZTL sono consentiti ai ciclomotori, ai velocipedi, ai veicoli di micromobilità elettrica",
      "I possessori di veicoli a trazione elettrica possono ottenere il pass di solo transito senza limitazione oraria",
      "Ogni struttura ricettiva può rilasciare contemporaneamente un numero di pass non superiore al 10% del numero delle stanze dell'esercizio.",
      "La sosta non può superare i sessanta minuti",
      "validazione permanente dei veicoli nel sistema di controllo, in lista bianca, senza emissione di pass.")
check("comune-pass-strutture-ricettive", "Pass riservato alle strutture ricettive presenti nelle Ztl del centro storico per agevolare le operazioni di carico e scarico dei bagagli dei loro clienti.")
check("comune-rilascio-pass-ztl", "Nel Comune di Cagliari sono presenti sei diverse zone a traffico limitato: Poetto, Castello, Marina, Stampace basso, Stampace alto e Villanova.")
check("albo-delibere-giunta-dal-02-12-2025", "Istituzione Aree pedonali nella via Cavour nel tratto compreso tra la Via Sant'Eulalia e la via Lepanto")
check("geoportale-ztl-metadati", "openData: False")

# --- orari e strade dal sito non ufficiale (citazioni) ---
Q = {"castello": "La z.t.l. Castello è in vigore dal lunedì alla domenica dalle 24.00 alle 9.00",
     "marina": "La z.t.l. Marina è in vigore dal lunedì alla domenica dalle 21.00 alle 07.00 e dalle 15.30 alle 17.00",
     "villanova": "La z.t.l. Villanova è in vigore dal lunedì alla domenica dalle 21.00 alle 07.00 e dalle 15.30 alle 17.00",
     "stampace-alto": "La z.t.l. Stampace Alto è in vigore dal lunedì alla domenica dalle 21.00 alle 9.00 e dalle 15.30 alle 17.00.",
     "stampace-basso": "La z.t.l. Stampace Basso è in vigore i giorni festivi e feriali dalle 7.30 alle 10.30 e dalle 15.30 alle 17.00."}
check("accessibilitacentristorici-cagliari", *Q.values(),
      "Data aggiornamento: 02/05/2020", "Affidabilità: modesta",
      "La ZTL Villanova è costituita da viale Regina Elena - via La Vega - piazza Kennedy - via Marche - via Bacaredda - piazza Garibaldi - via Garibaldi - piazza Costituzione.",
      "La ZTL Stampace alto è costituita da via San Giorgio - via Ospedale - portico Alberti - via Portoscalas - corso Vittorio Emanuele - piazza Yenne - salita Santa Chiara - scalette Santa Chiara - via Cammino Nuovo.",
      "La ZTL Stampace basso è costituita da via Pola - corso Vittorio Emanuele II - via Angioj - via Crispi - piazza del Carmine - via Maddalena - via Roma - viale Trieste",
      "La ZTL Poetto è costituita da piazza Arcipelaghi fino al canale adduttore delle Saline",
      "il tratto di via Porcile, da via Roma a via Cavour, il tratto di via Cavour da viale Regina Margherita a via Porcile e il tratto di via Sardegna da viale Regina Margherita a via Porcile, non sono soggetti a limitazioni orarie del traffico.",
      "All' interno della z.t.l. Stampace Alto la via Azuni e la via Santa Margherita, non sono soggette a limitazioni orarie del traffico.",
      "La z.t.l. Poetto è in vigore nei giorni feriali, prefestivi e festivi dalle 21.00 alle 6.00.",
      "Varco ZTL Castello Via Mazzini", "Varco ZTL Villanova Piazza Marghinotti", "Varco ZTL Marina Via Lepanto")
check("websearch-1-orari", "Castello: 24:00–09:00", "Stampace basso: weekdays 07:30–10:30 and 15:30–17:00; Saturday 07:30–10:30")

# --- geometria ---
GEO = osm_geo.load("cagliari-ztl")
WAYS = {e["id"]: e for e in GEO if e["type"] == "way"}


def _d(a, b):
    k = math.cos(math.radians(a[0]))
    return math.hypot((a[0] - b[0]) * 110574, (a[1] - b[1]) * 111320 * k)


def ring_from_streets(order, bridge_m=60):
    """Anello che segue le strade di confine nell'ordine dato: ogni strada è percorsa (cammino minimo sulle sue way OSM)
    dal punto d'incontro con la precedente a quello con la successiva. Tratti della stessa strada separati da una piazza
    vengono collegati se distano meno di bridge_m. Restituisce l'anello [(lon, lat)] e la distanza degli incroci non
    condivisi (0 = nodo OSM comune)."""
    pos, street_nodes, adj = {}, [], []
    for name in order:
        g, ns = {}, set()
        for w in WAYS.values():
            t = w.get("tags", {})
            if not t.get("highway") or t.get("name") != name or not w.get("geometry"):
                continue
            pts = list(zip(w["nodes"], w["geometry"]))
            for (a, pa), (b, pb) in zip(pts, pts[1:]):
                pos[a], pos[b] = (pa["lat"], pa["lon"]), (pb["lat"], pb["lon"])
                g.setdefault(a, []).append((b, _d(pos[a], pos[b])))
                g.setdefault(b, []).append((a, _d(pos[a], pos[b])))
                ns |= {a, b}
        if not ns:
            raise SystemExit(f"Nessuna strada OSM «{name}»")
        nl = sorted(ns)
        for i in range(len(nl)):
            for j in range(i + 1, len(nl)):
                dd = _d(pos[nl[i]], pos[nl[j]])
                if dd < bridge_m:
                    g.setdefault(nl[i], []).append((nl[j], dd * 3)); g.setdefault(nl[j], []).append((nl[i], dd * 3))
        street_nodes.append(ns); adj.append(g)
    n, junction, gaps = len(order), [], []
    for i in range(n):
        a, b = street_nodes[i], street_nodes[(i + 1) % n]
        shared = sorted(a & b)
        if shared:
            junction.append((shared[0], shared[0])); gaps.append(0.0)
        else:
            best = min((_d(pos[x], pos[y]), x, y) for x in sorted(a) for y in sorted(b))
            junction.append((best[1], best[2])); gaps.append(best[0])
    ring = []
    for i in range(n):
        start, end, g = junction[i - 1][1], junction[i][0], adj[i]
        dist, prev, pq = {start: 0.0}, {}, [(0.0, start)]
        while pq:
            dd, u = heapq.heappop(pq)
            if u == end:
                break
            if dd > dist.get(u, 1e18):
                continue
            for v, w in g.get(u, []):
                if dd + w < dist.get(v, 1e18):
                    dist[v], prev[v] = dd + w, u
                    heapq.heappush(pq, (dd + w, v))
        if end not in dist:
            raise SystemExit(f"{order[i]}: tratto non continuo tra i due incroci")
        path, u = [end], end
        while u != start:
            u = prev[u]; path.append(u)
        ring += [(pos[x][1], pos[x][0]) for x in reversed(path)]
    return ring + ring[:1], gaps


# nomi OSM delle strade di confine (portico Alberti e salita Santa Chiara non hanno un nome in OSM: tra via Ospedale e
# via Porto Scalas, e tra piazza Yenne e le scalette, l'anello passa per l'incrocio più vicino)
BOUNDARY = {
    "villanova": ["Viale Regina Elena", "Via La Vega", "Piazza John Fitzgerald Kennedy", "Via Marche", "Via Ottone Bacaredda",
                  "Piazza Giuseppe Garibaldi", "Via Giuseppe Garibaldi", "Piazza Costituzione"],
    "stampace-alto": ["Via San Giorgio", "Via Ospedale", "Via Porto Scalas", "Corso Vittorio Emanuele Secondo", "Piazza Yenne",
                      "Scalette Santa Chiara", "Via Cammino Nuovo"],
    "stampace-basso": ["Via Pola", "Corso Vittorio Emanuele Secondo", "Via Giovanni Maria Angioy", "Via Francesco Crispi",
                       "Piazza del Carmine", "Via Maddalena", "Via Roma", "Viale Trieste"],
}
SHAPES, GAPS = {}, {}
for key, rid in (("castello", 14402165), ("marina", 14402156)):
    SHAPES[key] = osm_geo.perimeter(osm_geo.outer_ring(osm_geo.relation(GEO, rid)), tol_m=4)
for key, order in BOUNDARY.items():
    ring, gaps = ring_from_streets(order)
    if max(gaps) > 120:
        raise SystemExit(f"{key}: incrocio tra strade di confine troppo lontano ({max(gaps):.0f} m)")
    SHAPES[key], GAPS[key] = osm_geo.perimeter(ring, tol_m=4), gaps
AREAS = {k: osm_geo.area_km2([(p["lon"], p["lat"]) for p in s]) for k, s in SHAPES.items()}
for k, (lo, hi) in {"castello": (0.05, 0.2), "marina": (0.1, 0.4), "villanova": (0.15, 0.5), "stampace-alto": (0.03, 0.15),
                    "stampace-basso": (0.08, 0.3)}.items():
    if not lo < AREAS[k] < hi:
        raise SystemExit(f"Area non plausibile per {k}: {AREAS[k]:.3f} km²")

# Controlli: un luogo dentro ogni zona (coordinate OSM; per Villanova, Stampace le strade con i tag OSM degli stessi orari),
# stazione e porto fuori da tutte
INSIDE = {"castello": [("Cattedrale di Santa Maria", 39.2189, 9.1157)],
          "marina": [("Via Sardegna", 39.21501, 9.11158)],
          "villanova": [("Piazza San Domenico", 39.21937, 9.11971), ("Via Bosa", 39.21978, 9.12076), ("Piazza San Giacomo", 39.21715, 9.11865)],
          "stampace-alto": [("Via Sant'Efisio", 39.22026, 9.11313), ("Via Santa Restituta", 39.21968, 9.11273)],
          "stampace-basso": [("Via Giorgio Asproni", 39.21914, 9.10649), ("Via Carloforte", 39.21991, 9.10588)]}
OUTSIDE = [("Stazione ferroviaria", 39.21633, 9.10766), ("Via Sassari (lato porto)", 39.21409, 9.10765), ("Viale Buoncammino", 39.22373, 9.11539)]
for key, places in INSIDE.items():
    for name, lat, lon in places:
        if not osm_geo.contains(SHAPES[key], lat, lon):
            raise SystemExit(f"Controllo perimetro fallito: {name} dovrebbe essere in {key}")
    for other, places2 in INSIDE.items():
        if other != key:
            for name, lat, lon in places2:
                if osm_geo.contains(SHAPES[key], lat, lon):
                    raise SystemExit(f"Controllo perimetro fallito: {name} ({other}) cade anche in {key}")
    for name, lat, lon in OUTSIDE:
        if osm_geo.contains(SHAPES[key], lat, lon):
            raise SystemExit(f"Controllo perimetro fallito: {name} dovrebbe essere fuori da {key}")

GATES = osm_geo.gates(GEO, name_prefix=None)


def gates_for(key):
    out = [osm_geo.gate_json("ca", (g[0], "Varco ZTL", g[2], g[3])) for g in GATES
           if osm_geo.distance_m(SHAPES[key], g[2], g[3]) < 40]
    return sorted(out, key=lambda g: g["id"])


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


LINKS = [link("accessibilitacentristorici.it: Cagliari ZTL (unofficial, hours and streets)", "accessibilitacentristorici.it: ZTL di Cagliari (non ufficiale, orari e strade)", "accessibilitacentristorici.it: ZTL Cagliari (inoffiziell, Zeiten und Straßen)", ACS),
         link("City of Cagliari: ZTL regulation (text in force, Dec. 2025)", "Comune di Cagliari: regolamento ZTL (testo vigente, dic. 2025)", "Stadt Cagliari: ZTL-Ordnung (geltender Text, Dez. 2025)", RULES),
         link("City of Cagliari: ZTL and pedestrian zones office", "Comune di Cagliari: ufficio ZTL e zone pedonali", "Stadt Cagliari: Büro ZTL und Fußgängerzonen", OFFICE),
         link("City of Cagliari: ZTL passes", "Comune di Cagliari: rilascio pass ZTL", "Stadt Cagliari: ZTL-Pässe", PASSES),
         link("City of Cagliari: ZTL pass for hotels", "Comune di Cagliari: pass ZTL per strutture ricettive", "Stadt Cagliari: ZTL-Pass für Unterkünfte", HOTELS)]

COMMON = [
    ("Confirmed only by accessibilitacentristorici.it (a private permit-service site, page updated 02/05/2020, rated «modest» reliability by the site itself); hours match the OpenStreetMap access tags of the streets and other unofficial sites. The City publishes no hours: its regulation leaves them to an act of the City executive that is not on the online notice board (all titles 2016–October 2026 checked).",
     "Confermato solo da accessibilitacentristorici.it (sito privato di servizi per i permessi, pagina aggiornata il 02/05/2020, affidabilità «modesta» secondo il sito stesso); gli orari coincidono con i tag di accesso delle strade su OpenStreetMap e con altri siti non ufficiali. Il Comune non pubblica gli orari: il regolamento li rimanda a un atto della Giunta che non c'è nell'albo pretorio online (controllati tutti i titoli 2016–ottobre 2026).",
     "Nur von accessibilitacentristorici.it bestätigt (private Website für Genehmigungsdienste, Seite aktualisiert am 02.05.2020, Zuverlässigkeit laut Website selbst «mäßig»); die Zeiten stimmen mit den Zufahrts-Tags der Straßen in OpenStreetMap und anderen inoffiziellen Seiten überein. Die Stadt veröffentlicht keine Zeiten: Ihre Ordnung überlässt sie einem Beschluss des Stadtvorstands, der nicht auf der Online-Amtstafel steht (alle Titel 2016–Oktober 2026 geprüft)."),
    ("Hotels (official, ZTL regulation art. 10): the hotel sends your plate online to the City's ZTL office for arrival and departure days, to unload luggage; stop 60 minutes at most with the hotel's pass. Mopeds (not motorbikes) may enter; electric cars need a free transit pass; Blue Badge plates go on a white list on request. Fine about 80–335 € (confirmed only by tyremap.com).",
     "Hotel (ufficiale, regolamento ZTL art. 10): la struttura trasmette online la targa all'ufficio ZTL per i giorni di arrivo e partenza, per scaricare i bagagli; sosta al massimo 60 minuti con il pass della struttura. I ciclomotori (non le moto) entrano; le auto elettriche hanno bisogno di un pass di solo transito gratuito; le targhe CUDE vanno in lista bianca su richiesta. Multa circa 80–335 € (confermato solo da tyremap.com).",
     "Hotels (offiziell, ZTL-Ordnung Art. 10): Die Unterkunft meldet dein Kennzeichen online an das ZTL-Büro für An- und Abreisetag, zum Ausladen; höchstens 60 Minuten mit dem Pass der Unterkunft. Mopeds (keine Motorräder) dürfen hinein; Elektroautos brauchen einen kostenlosen Durchfahrtspass; Kennzeichen mit Behindertenausweis kommen auf Antrag auf eine weiße Liste. Bußgeld etwa 80–335 € (nur von tyremap.com bestätigt)."),
]
STREET_AREA = ("Area drawn from the boundary streets named by accessibilitacentristorici.it, followed on OpenStreetMap along their centre lines: streets on the edge may be only partly inside.",
               "Area ricavata dalle strade di confine indicate da accessibilitacentristorici.it, seguite su OpenStreetMap lungo la mezzeria: le strade di confine possono essere dentro solo in parte.",
               "Fläche aus den von accessibilitacentristorici.it genannten Grenzstraßen, in OpenStreetMap entlang der Straßenmitte verfolgt: Grenzstraßen liegen eventuell nur teilweise innen.")
OSM_AREA = ("Area from the OpenStreetMap ZTL relation (not an official map).",
            "Area dalla relazione ZTL di OpenStreetMap (non è una mappa ufficiale).",
            "Fläche aus der ZTL-Relation von OpenStreetMap (keine offizielle Karte).")


def zone(key, name, name_it, name_de, summary, summary_it, summary_de, windows, tr, tr_de, extra=()):
    pend = list(extra) + COMMON + [STREET_AREA if key in BOUNDARY else OSM_AREA]
    return {"id": f"cagliari-{key}", "name": name, "name_it": name_it, "name_de": name_de, "kind": "restricted",
            "summary": summary, "summary_it": summary_it, "summary_de": summary_de,
            "perimeter": SHAPES[key], "gates": gates_for(key), "windows": windows,
            "freeOnHolidays": False, "holidaysAsSunday": False, "exemptFuels": [], "hotelCanRegister": True,
            "source": {"authority": "City of Cagliari", "pageURL": OFFICE,
                       "ordinance": "Orari: nessun atto ufficiale pubblicato (regolamento ZTL, D.C.C. n. 42/2012, 27/2013 e 168/2025, art. 31: orari decisi dalla Giunta)",
                       "ordinanceURL": RULES, "quote": Q[key], "quoteTranslation": tr, "quoteTranslation_de": tr_de,
                       "checkedOn": CHECKED, "reviewedByHuman": False,
                       "pending": [p[0] for p in pend], "pending_it": [p[1] for p in pend], "pending_de": [p[2] for p in pend],
                       "links": LINKS, "official": False, "unofficialSource": UNOFFICIAL}}


def w(days, a, b):
    return {"weekdays": days, "start": a, "end": b}


EVE = [w(ALL, 21 * 60, 7 * 60), w(ALL, 15 * 60 + 30, 17 * 60)]
zones = [
    zone("castello", "Castello · hilltop quarter", "Castello · quartiere alto", "Castello · Oberstadt",
         "Castello (the walled hilltop quarter with the Cathedral and Bastione di Saint Remy) is closed to cars and motorbikes without a pass every night from midnight to 9 am. During the day you may drive in. Hours from an unofficial site.",
         "Castello (il quartiere alto murato con la Cattedrale e il Bastione di Saint Remy) è chiuso ad auto e moto senza pass ogni notte da mezzanotte alle 9. Di giorno si entra. Orari da un sito non ufficiale.",
         "Castello (das ummauerte Oberstadtviertel mit Kathedrale und Bastione di Saint Remy) ist für Autos und Motorräder ohne Pass jede Nacht von Mitternacht bis 9 Uhr gesperrt. Tagsüber darfst du hinein. Zeiten von einer inoffiziellen Website.",
         [w(ALL, 0, 9 * 60)],
         "The Castello ZTL is in force Monday to Sunday from 24.00 to 9.00",
         "Die ZTL Castello gilt von Montag bis Sonntag von 24.00 bis 9.00 Uhr"),
    zone("marina", "Marina · harbour quarter", "Marina · quartiere del porto", "Marina · Hafenviertel",
         "Marina (the quarter between Via Roma and Castello) is closed to cars and motorbikes without a pass every day 3:30–5 pm and 9 pm–7 am. Hours from an unofficial site.",
         "Marina (il quartiere tra via Roma e Castello) è chiuso ad auto e moto senza pass ogni giorno 15:30–17 e 21–7. Orari da un sito non ufficiale.",
         "Marina (das Viertel zwischen Via Roma und Castello) ist für Autos und Motorräder ohne Pass täglich 15:30–17 und 21–7 Uhr gesperrt. Zeiten von einer inoffiziellen Website.",
         EVE,
         "The Marina ZTL is in force Monday to Sunday from 21.00 to 07.00 and from 15.30 to 17.00",
         "Die ZTL Marina gilt von Montag bis Sonntag von 21.00 bis 07.00 und von 15.30 bis 17.00 Uhr",
         [("Not restricted at any time (same site): Via Porcile from Via Roma to Via Cavour, Via Cavour and Via Sardegna from Viale Regina Margherita to Via Porcile. Via Sardegna, Via Concezione, Via Barcellona and Via Napoli are also a pedestrian area.",
           "Mai soggetti a limitazioni (stesso sito): via Porcile da via Roma a via Cavour, via Cavour e via Sardegna da viale Regina Margherita a via Porcile. Via Sardegna, via Concezione, via Barcellona e via Napoli sono anche area pedonale.",
           "Nie beschränkt (gleiche Website): Via Porcile von Via Roma bis Via Cavour, Via Cavour und Via Sardegna von Viale Regina Margherita bis Via Porcile. Via Sardegna, Via Concezione, Via Barcellona und Via Napoli sind zudem Fußgängerzone.")]),
    zone("villanova", "Villanova · old quarter", "Villanova · quartiere storico", "Villanova · Altstadtviertel",
         "Villanova (between Viale Regina Elena, Via Garibaldi and Via Bacaredda) is closed to cars and motorbikes without a pass every day 3:30–5 pm and 9 pm–7 am. Hours from an unofficial site.",
         "Villanova (tra viale Regina Elena, via Garibaldi e via Bacaredda) è chiuso ad auto e moto senza pass ogni giorno 15:30–17 e 21–7. Orari da un sito non ufficiale.",
         "Villanova (zwischen Viale Regina Elena, Via Garibaldi und Via Bacaredda) ist für Autos und Motorräder ohne Pass täglich 15:30–17 und 21–7 Uhr gesperrt. Zeiten von einer inoffiziellen Website.",
         EVE,
         "The Villanova ZTL is in force Monday to Sunday from 21.00 to 07.00 and from 15.30 to 17.00",
         "Die ZTL Villanova gilt von Montag bis Sonntag von 21.00 bis 07.00 und von 15.30 bis 17.00 Uhr",
         [("Via Piccioni, Via San Giacomo, Via and Vico Sulis, Piazza San Giacomo, Via San Giovanni and its lanes are also a pedestrian area (same site).",
           "Via Piccioni, via San Giacomo, via e vico Sulis, piazza San Giacomo, via San Giovanni e i suoi vicoli sono anche area pedonale (stesso sito).",
           "Via Piccioni, Via San Giacomo, Via und Vico Sulis, Piazza San Giacomo, Via San Giovanni und ihre Gassen sind zudem Fußgängerzone (gleiche Website).")]),
    zone("stampace-alto", "Stampace Alto · upper Stampace", "Stampace Alto · Stampace alta", "Stampace Alto · oberes Stampace",
         "Upper Stampace (around Sant'Efisio and Via Ospedale) is closed to cars and motorbikes without a pass every day 3:30–5 pm and 9 pm–9 am. Hours from an unofficial site.",
         "Stampace Alto (intorno a Sant'Efisio e via Ospedale) è chiuso ad auto e moto senza pass ogni giorno 15:30–17 e 21–9. Orari da un sito non ufficiale.",
         "Das obere Stampace (um Sant'Efisio und Via Ospedale) ist für Autos und Motorräder ohne Pass täglich 15:30–17 und 21–9 Uhr gesperrt. Zeiten von einer inoffiziellen Website.",
         [w(ALL, 21 * 60, 9 * 60), w(ALL, 15 * 60 + 30, 17 * 60)],
         "The Stampace Alto ZTL is in force Monday to Sunday from 21.00 to 9.00 and from 15.30 to 17.00.",
         "Die ZTL Stampace Alto gilt von Montag bis Sonntag von 21.00 bis 9.00 und von 15.30 bis 17.00 Uhr.",
         [("Via Azuni and Via Santa Margherita are never restricted (same site). One other unofficial source gives 9 pm–10 am.",
           "Via Azuni e via Santa Margherita non sono mai soggette a limitazioni (stesso sito). Un'altra fonte non ufficiale indica 21–10.",
           "Via Azuni und Via Santa Margherita sind nie beschränkt (gleiche Website). Eine andere inoffizielle Quelle nennt 21–10 Uhr.")]),
    zone("stampace-basso", "Stampace Basso · lower Stampace", "Stampace Basso · Stampace bassa", "Stampace Basso · unteres Stampace",
         "Lower Stampace (between Via Roma, Viale Trieste and Corso Vittorio Emanuele) is closed to cars and motorbikes without a pass every day, holidays included, 7:30–10:30 am and 3:30–5 pm. Hours from an unofficial site.",
         "Stampace Basso (tra via Roma, viale Trieste e corso Vittorio Emanuele) è chiuso ad auto e moto senza pass tutti i giorni, festivi compresi, 7:30–10:30 e 15:30–17. Orari da un sito non ufficiale.",
         "Das untere Stampace (zwischen Via Roma, Viale Trieste und Corso Vittorio Emanuele) ist für Autos und Motorräder ohne Pass täglich, auch an Feiertagen, 7:30–10:30 und 15:30–17 Uhr gesperrt. Zeiten von einer inoffiziellen Website.",
         [w(ALL, 7 * 60 + 30, 10 * 60 + 30), w(ALL, 15 * 60 + 30, 17 * 60)],
         "The Stampace Basso ZTL is in force on holidays and weekdays from 7.30 to 10.30 and from 15.30 to 17.00.",
         "Die ZTL Stampace Basso gilt an Feier- und Werktagen von 7.30 bis 10.30 und von 15.30 bis 17.00 Uhr.",
         [("Sources disagree: OpenStreetMap and other unofficial sites give Monday–Friday 7:30–10:30 and 3:30–5 pm, Saturday 7:30–10:30 only, Sundays and holidays free; the app uses the stricter hours of accessibilitacentristorici.it. Viale Trieste is never restricted.",
           "Le fonti non concordano: OpenStreetMap e altri siti non ufficiali indicano lunedì–venerdì 7:30–10:30 e 15:30–17, sabato solo 7:30–10:30, domenica e festivi liberi; l'app usa gli orari più ampi di accessibilitacentristorici.it. Il viale Trieste non è mai soggetto a limitazioni.",
           "Die Quellen sind sich uneinig: OpenStreetMap und andere inoffizielle Seiten nennen Montag–Freitag 7:30–10:30 und 15:30–17, Samstag nur 7:30–10:30, Sonn- und Feiertage frei; die App nimmt die strengeren Zeiten von accessibilitacentristorici.it. Der Viale Trieste ist nie beschränkt.")]),
]
# Poetto (lungomare, 21–6 tutti i giorni secondo lo stesso sito): non disegnata
POETTO = ("The Poetto seafront ZTL (from Piazza Arcipelaghi to the Saline canal, 9 pm–6 am every day according to the same site) is not drawn in the app.",
          "La ZTL del Poetto (da piazza Arcipelaghi al canale adduttore delle Saline, 21–6 tutti i giorni secondo lo stesso sito) non è disegnata nell'app.",
          "Die ZTL am Poetto (von Piazza Arcipelaghi bis zum Saline-Kanal, laut gleicher Website täglich 21–6 Uhr) ist in der App nicht eingezeichnet.")
for z in zones:
    for i, lang in enumerate(("pending", "pending_it", "pending_de")):
        z["source"][lang].append(POETTO[i])

city = {"id": "cagliari", "name": "Cagliari", "name_it": "Cagliari", "name_de": "Cagliari",
        "center": {"lat": 39.2180, "lon": 9.1140}, "zones": zones, "status": "draft",
        "license": "Rules: Comune di Cagliari (ZTL regulation); hours and boundary streets from accessibilitacentristorici.it (unofficial). Perimeters and gates: " + osm_geo.ODBL + " (approximate, not official)."}

# Pubblicata come città con fonti non ufficiali (app 1.16.2: «unofficialCities» nel manifest): ogni zona ha perimetro,
# citazione dal sito non ufficiale e official = false
ready = all(len(z["perimeter"]) >= 5 and z["source"]["quote"] and z["source"]["official"] is False for z in zones)
out = ROOT / ("Resources/Cities/cagliari.json" if ready else "data/drafts/cagliari.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/cagliari.json" if ready else "Resources/Cities/cagliari.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), [(z["id"], len(z["perimeter"]), len(z["gates"]), round(AREAS[z["id"][9:]], 3)) for z in zones],
      {k: [round(x) for x in v] for k, v in GAPS.items()})
