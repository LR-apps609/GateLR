#!/usr/bin/env python3
# Costruisce Resources/Cities/lecce.json dagli atti e dalle pagine ufficiali del Comune di Lecce salvati in data/raw/lecce/
# (fonti e date in docs/fonti-lecce.md). Ogni frase citata o riassunta viene ricontrollata sul testo salvato.
#
# Regole: delibera GC n. 280 del 10/07/2025 attuata con le ordinanze dirigenziali n. 1679 del 16/07/2025 (fasce d'accesso:
# feriali 10–13 e 16:30–20, festivi accesso non consentito; varco d'ingresso di Porta Napoli 0–24) e n. 1689 del 17/07/2025
# (carico/scarico), in vigore dal 01/08/2025; ordinanza n. 2069 del 09/09/2025 con i 18 varchi e il tipo di controllo
# (variabile o H24); regolamento ZTL/AP (D.C.C. 92/2020 e 117/2023) per hotel (HTL), moto, elettriche, CUDE; pagina
# «Permesso di transito e sosta nelle ZTL del centro storico»; comunicati del 03/04/2025 (perimetro) e del 12/03/2026
# (nuovi varchi h24 decisi dalla giunta, non ancora tra le ordinanze pubblicate).
#
# Geometria: OpenStreetMap (data/raw/geo/lecce-ztl.json, © OpenStreetMap contributors, ODbL 1.0, scaricato con
# Tools/fetch_osm_api.py): relazione 20670025 «ZTL Lecce» (boundary=limited_traffic_zone, source «Città di Lecce», orari
# conditional uguali all'ordinanza 1679/2025, creata il 10/05/2026, dopo la delibera di perimetro del 03/04/2025).
# L'open data ufficiale (dati.comune.lecce.it, CC BY 4.0) è del 2014 e non si usa come perimetro.
# Varchi: i 18 dell'ordinanza 2069/2025, ciascuno nel nodo OSM dell'incrocio indicato («via X/via Y»); dove OSM non ha un
# nodo in comune, il punto della prima strada più vicino alla seconda (vedi FALLBACK).
# Se arriva un perimetro ufficiale aggiornato, basta salvarlo come data/raw/lecce/ztl_perimetro.geojson.
# Non aggiorna manifest.json. Uso: python3 Tools/build_lecce.py
import json, math, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/lecce"
CHECKED = "2026-10-27T10:00:00Z"
OSM_ZTL = 20670025
MON_SAT, SUN = [2, 3, 4, 5, 6, 7], [1]

B = "https://www.comune.lecce.it"
NEWS_2025 = B + "/news/dettaglio/2025/07/17/modifiche-ztl-nuove-ordinanze"
ORD_1679 = B + "/docs/default-source/altri-documenti/ord_01679_16-07-2025.pdf"
ORD_1689 = B + "/docs/default-source/altri-documenti/ztl_carico_scarico_ord_01689_17-07-2025.pdf"
ORD_2069 = B + "/docs/default-source/altri-documenti/ordinanza-n-2069-del-09-09-2025.pdf"
PERMITS = B + "/aree-tematiche/imprese/servizi-comunali/permesso-di-transito-e-sosta-nelle-ztl-del-centro-storico"
RULES_PDF = B + "/docs/default-source/regolamenti-comunali/polizia-locale/regolamento-per-l-accesso-e-la-circolazione-dei-veicoli-nelle-zone-a-traffico-limitato-e-nelle-aree-pedonali-del-comune-di-lecce.pdf"
NEWS_2026 = B + "/news/dettaglio/2026/03/12/ztl-nuovi-provvedimenti-che-interessando-il-centro-storico"
NEWS_PERIM = B + "/news/dettaglio/2025/04/03/centro-storico-aggiornamento-del-perimetro-della-ztl"
NEWS_JUL_2026 = "https://www.corrieresalentino.it/2026/07/centro-storico-cambia-la-mappa-della-viabilita-sensi-di-marcia-invertiti-nuove-ztl-e-percorsi-ridisegnati/"


def flat(s):
    return re.sub(r"\s+", " ", s).strip()


TEXT = {p.stem: flat(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def check(file, *phrases):
    for q in phrases:
        if flat(q) not in TEXT[file]:
            raise SystemExit(f"{file}: frase non trovata, ricontrollare il documento: {q!r}")


QUOTE = ("I varchi elettronici di controllo degli ingressi nel centro storico della città saranno spenti dalle ore 10:00 alle ore "
         "13:00 e dalle ore 16:30 alle ore 20:00 nei giorni feriali mentre l’area rimane inaccessibile nei giorni festivi e di "
         "domenica, così come sarà vietato transitare dal varco di Porta Napoli H24 tutti i giorni della settimana .")
check("comune-news-2025-07-17-modifiche-ztl", QUOTE,
      "in virtù di quanto previsto dalla Delibera di Giunta Comunale n. 280 del 10/07/2025",
      "nei giorni feriali - dal lunedì al sabato - dalle ore 05:30 alle ore 09:30 e dalle ore 15:00 alle ore 16:00")
check("ord-1679-2025", "lato destro di Porta Napoli varco di ingresso per ZONA TRAFFICO LIMITATO (ZTL) 0 – 24;",
      "Delibera di Giunta Comunale n. 280 del 10/07/2025", "con efficacia dal 01 agosto 2025",
      "Giorni feriali • Dalle ore 10:00 alle ore 13:00 • Dalle ore 16:30 alle ore 20:00 Giorni festivi Accesso non consentito")
check("ord-1689-2025", "Ordinanza N. 1689")
check("ord-2069-2025",
      "Aggiornamento dell’orario di controllo variabile dei varchi dalle ore 10:00 alle ore 13:00 e dalle ore 16:30 alle ore 20:00 dei giorni Feriali e dalle ore 0:00 alle ore 24:00 dei giorni Festivi e dei varchi H/24")
check("regolamento-ztl-ap",
      "nonché dei veicoli rientranti nelle categorie L1e L3e di cui all’art. 47 del Codice della Strada è sempre consentita nelle Z.T.L. mentre dovrà essere espressamente normata con apposita modifica a questo regolamento, quella relativa alla circolazione dei veicoli elettrici e ibridi.",
      "per consentire l’accesso dei propri clienti per i soli giorni di check-in e check-out al fine di effettuare le operazioni di carico-scarico bagagli nelle immediate vicinanze della struttura.",
      "La sosta è autorizzata per la durata massima di minuti 20 con esposizione del disco orario.",
      "preferibilmente prima dell’arrivo del cliente e comunque al massimo entro 48 ore dall’accesso in Z.T.L.")
check("comune-permessi-ztl",
      "dovrà essere comunicato entro le successive 48 ore utilizzando il relativo modulo - denominato “Dichiarazione di Transito in ZTL”",
      "le auto a servizio di persone munite di contrassegno CUDE possono transitare nella ZTL senza la necessità di alcuna autorizzazione; tuttavia, durante gli orari di rilevazione elettronica degli accessi, possono transitare solo se inserite nella lista degli autoveicoli autorizzati.",
      "Ordinanza n.2069 del 09.09.2025", "ZTL carico/scarico Ordinanza n.1689 del 17.07.2025")
check("tariffe-ztl", "Permesso giornaliero temporaneo € 5,00")
check("comune-news-2026-03-12-nuovi-provvedimenti",
      "l'istituzione dell'ingresso in ztl h24 in via Mario Bernardini (tra via Duca degli Abruzzi e piazzetta della Luce); in via Benedetto Cairoli (in entrata tra via Duca degli Abruzzi e via Carlo Russi); a Porta Rudiae-via Adua (in uscita dal centro storico).",
      "l'esclusione di via Marco Aurelio dalla zona a traffico limitato")
check("comune-news-2025-04-03-perimetro", "La delibera abroga tutti gli atti precedenti")
check("websearch-3-luglio-2026", "The gate at via Pietro Palumbo will be converted into a 24-hour ZTL", "keeps via delle Bombarde as a 24-hour ZTL")

# I 18 varchi dell'ordinanza 2069/2025: (riga dell'ordinanza, nome, strada, incrocio, direzione, controllo)
XXV = ("Viale Venticinque Luglio", "Viale venticinque luglio")
GATES = [
    ("1 Via Casale Fornello/V.le M. De Pietro ingresso/uscita Variabile", "Via Casale Fornello / Viale De Pietro", ("Via Casale Fornello",), ("Viale Michele De Pietro",), "", False),
    ("2 Via Marco Aurelio/Vico Mondo Nuovo uscita Variabile", "Via Marco Aurelio / Vico Mondo Nuovo", ("Via Marco Aurelio",), ("Vico Mondo Nuovo",), "exit", False),
    ("4 Vico dei Fieschi/Via XXV Luglio uscita Variabile", "Vico dei Fieschi / Viale XXV Luglio", ("Vico dei Fieschi",), XXV, "exit", False),
    ("5 Via Trinchese/Via XXV Luglio ingresso/uscita H24", "Via Trinchese / Viale XXV Luglio", ("Via Salvatore Trinchese",), XXV, "", True),
    ("6 Via dei Mocenigo/Via XXV Luglio uscita H24", "Via dei Mocenigo / Viale XXV Luglio", ("Via dei Mocenigo",), XXV, "exit", True),
    ("7 Via Biccari/Via XXV Luglio ingresso/uscita H24", "Via Biccari / Viale XXV Luglio", ("Via Roberto Di Biccari",), XXV, "", True),
    ("8 Via Fazzi/Via XXV Luglio ingresso/uscita Variabile", "Via Fazzi / Viale XXV Luglio", ("Via Vito Fazzi",), XXV, "", False),
    ("6 Via Maremonti/Viale G. Marconi uscita Variabile", "Via Maremonti / Viale Marconi", ("Via Ludovico Maremonti",), ("Viale Guglielmo Marconi",), "exit", False),
    ("10 Vico dei Verardi/viale F. Lo Re ingresso/uscita Variabile", "Vico dei Verardi / Viale Lo Re", ("Via dei Verardi",), ("Viale Francesco Lo Re",), "", False),
    ("11 Via M. Bernardini/Via Duca degli Abruzzi ingresso/uscita Variabile", "Via Bernardini / Via Duca degli Abruzzi", ("Via Mario Bernardini",), ("Via Duca degli Abruzzi",), "", False),
    ("12 Vico De Argenteris/Via Duca degli Abruzzi uscita Variabile", "Vico De Argenteris / Via Duca degli Abruzzi", ("Via De Argenteris",), ("Via Duca degli Abruzzi",), "exit", False),
    ("13 Via Benedetto Cairoli/Via Duca degli Abruzzi ingresso/uscita Variabile", "Via Cairoli / Via Duca degli Abruzzi", ("Via Benedetto Cairoli",), ("Via Duca degli Abruzzi",), "", False),
    ("14 Via Giuseppe Cino/Via Manifattura Tabacchi ingresso Variabile", "Via Cino / Via Manifattura Tabacchi", ("Via Giuseppe Cino",), ("Via Manifattura Tabacchi",), "entry", False),
    ("15 Porta Rudiae/Via Adua uscita Variabile", "Porta Rudiae / Via Adua", None, ("Via Adua",), "exit", False),
    ("16 Via Pietro Palumbo/Via Adua ingresso Variabile", "Via Palumbo / Via Adua", ("Via Pietro Palumbo",), ("Via Adua",), "entry", False),
    ("17 Porta Napoli/P.zza A. Rizzo ingresso H24", "Porta Napoli / Piazza Rizzo", ("Piazza Angelo Rizzo",), ("Via Adua",), "entry", True),
    ("18 Porta Napoli/Corte V. Licci uscita Variabile", "Porta Napoli / Corte Licci", ("Corte Vincenzo Licci",), ("Via Adua", "Piazza Angelo Rizzo"), "exit", False),
]
check("ord-2069-2025", *[g[0] for g in GATES], "3 Vico Mondo Nuovo/Via Marco Aurelio ingresso Variabile")

GEO = osm_geo.load("lecce-ztl")
WAYS = [e for e in GEO if e["type"] == "way"]
NODE = {n: (p["lat"], p["lon"]) for w in WAYS for n, p in zip(w["nodes"], w["geometry"])}


def pts(names):
    return [(n, NODE[n]) for w in WAYS if w["tags"].get("name") in names for n in w["nodes"]]


def dist(a, b):
    return math.hypot((a[0] - b[0]) * 110574, (a[1] - b[1]) * 111320 * math.cos(math.radians(a[0])))


def gate_point(a, b):
    """Nodo OSM comune alle due strade; altrimenti il punto della prima più vicino alla seconda (entro 60 m)"""
    if a is None:   # Porta Rudiae: il centro della porta (way OSM historic=city_gate «Porta Rudiae»)
        g = next(w for w in WAYS if w["tags"].get("name") == "Porta Rudiae")["geometry"]
        return (sum(p["lat"] for p in g) / len(g), sum(p["lon"] for p in g) / len(g)), "fallback"
    A, Bs = pts(a), pts(b)
    common = sorted({n for n, _ in A} & {n for n, _ in Bs})
    if common:
        return NODE[common[0]], "node"
    d, p = min((dist(p, q), p) for _, p in A for _, q in Bs)
    if d > 60:
        raise SystemExit(f"Varco: {a} e {b} lontani {d:.0f} m in OSM")
    return p, "fallback"


def perimeter():
    f = RAW / "ztl_perimetro.geojson"
    if f.exists():
        g = json.loads(f.read_text())
        g = g["features"][0]["geometry"] if "features" in g else g
        polys = [g["coordinates"]] if g["type"] == "Polygon" else g["coordinates"]
        return osm_geo.perimeter(max((p[0] for p in polys), key=osm_geo.area_km2), tol_m=4), False
    rel = osm_geo.relation(GEO, OSM_ZTL)
    if rel["tags"].get("vehicle:conditional") != "yes @ (Mo-Sa 10:00-13:00,16:30-20:00)":
        raise SystemExit("Gli orari nella relazione OSM sono cambiati: ricontrollare")
    return osm_geo.perimeter(osm_geo.outer_ring(rel, roles=("outer", "")), tol_m=4), True


shape, from_osm = perimeter()
for name, lat, lon, inside in [("Duomo di Lecce", 40.35175, 18.16933, True), ("Colonna di Sant'Oronzo", 40.35291, 18.17276, True),
                               ("Basilica di Santa Croce", 40.35467, 18.17324, True), ("Teatro Romano", 40.35134, 18.17053, True),
                               ("Stazione di Lecce", 40.34575, 18.16601, False), ("Castello Carlo V", 40.35245, 18.17446, False),
                               ("Mercato di Porta Rudiae", 40.35112, 18.16410, False)]:
    if osm_geo.contains(shape, lat, lon) != inside:
        raise SystemExit(f"Controllo perimetro fallito: {name} dovrebbe essere {'dentro' if inside else 'fuori'}")
area = osm_geo.area_km2(shape)
if not 0.4 < area < 1.1:
    raise SystemExit(f"Area della ZTL non plausibile: {area:.2f} km²")

gate_list, FALLBACK = [], []
for row, name, a, b, direction, h24 in GATES:
    (lat, lon), how = gate_point(a, b)
    if how == "fallback":
        FALLBACK.append(name)
    label = "Varco · " + name + (" (exit)" if direction == "exit" else "") + (" — 24 h" if h24 else "")
    if osm_geo.distance_m(shape, lat, lon) > 60:
        raise SystemExit(f"Varco lontano dal bordo: {name}")
    gate_list.append({"id": "le-" + re.sub(r"[^a-z]+", "-", name.lower()).strip("-"), "name": label,
                      "location": {"lat": round(lat, 6), "lon": round(lon, 6)}})


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


LINKS = [link("City of Lecce (17 Jul 2025): new ZTL hours from 1 August 2025", "Comune di Lecce (17/07/2025): modifiche ZTL, nuove ordinanze",
              "Stadt Lecce (17.07.2025): neue ZTL-Zeiten ab 1. August 2025", NEWS_2025),
         link("Ordinance 1679/2025: access hours and Porta Napoli 0–24 (PDF)", "Ordinanza 1679/2025: fasce d'accesso e Porta Napoli 0–24 (PDF)",
              "Verordnung 1679/2025: Zufahrtszeiten und Porta Napoli 0–24 (PDF)", ORD_1679),
         link("Ordinance 2069/2025: the 18 cameras, variable or 24 h (PDF)", "Ordinanza 2069/2025: i 18 varchi, variabili o H24 (PDF)",
              "Verordnung 2069/2025: die 18 Kameras, variabel oder 24 h (PDF)", ORD_2069),
         link("Ordinance 1689/2025: deliveries (PDF)", "Ordinanza 1689/2025: carico e scarico (PDF)", "Verordnung 1689/2025: Lieferungen (PDF)", ORD_1689),
         link("City of Lecce: ZTL permits", "Comune di Lecce: permesso di transito e sosta nelle ZTL", "Stadt Lecce: ZTL-Genehmigungen", PERMITS),
         link("ZTL and pedestrian area regulation (PDF)", "Regolamento ZTL e aree pedonali (PDF)", "Regelung für ZTL und Fußgängerzonen (PDF)", RULES_PDF),
         link("City of Lecce (12 Mar 2026): more 24-hour gates decided", "Comune di Lecce (12/03/2026): nuovi provvedimenti ZTL, varchi h24",
              "Stadt Lecce (12.03.2026): weitere 24-Stunden-Kameras beschlossen", NEWS_2026),
         link("City of Lecce (3 Apr 2025): new ZTL perimeter", "Comune di Lecce (03/04/2025): aggiornamento del perimetro della ZTL",
              "Stadt Lecce (3.4.2025): neue ZTL-Grenze", NEWS_PERIM),
         link("Corriere Salentino (Jul 2026): via Palumbo to become 24 h", "Corriere Salentino (07/2026): via Palumbo diventa h24",
              "Corriere Salentino (07.2026): Via Palumbo soll 24 h werden", NEWS_JUL_2026)]
if from_osm:
    LINKS.append(link(f"OpenStreetMap: relation {OSM_ZTL} «ZTL Lecce» (ODbL)", f"OpenStreetMap: relazione {OSM_ZTL} «ZTL Lecce» (ODbL)",
                      f"OpenStreetMap: Relation {OSM_ZTL} «ZTL Lecce» (ODbL)", osm_geo.osm_url("relation", OSM_ZTL)))

PENDING = [
    ("Four entrances are closed 24 hours a day even when the others are off (ordinance 2069/2025): Porta Napoli from piazza Rizzo, via Trinchese, via Biccari (both ways) and the via dei Mocenigo exit on viale XXV Luglio. GateLR shows the hours of the whole zone: in the free hours enter only through the other gates.",
     "Quattro varchi sono chiusi 24 ore su 24 anche quando gli altri sono spenti (ordinanza 2069/2025): Porta Napoli da piazza Rizzo, via Trinchese, via Biccari (in entrata e uscita) e l'uscita di via dei Mocenigo su viale XXV Luglio. GateLR mostra gli orari di tutta la zona: nelle ore libere entra solo dagli altri varchi.",
     "Vier Zufahrten sind rund um die Uhr gesperrt, auch wenn die anderen aus sind (Verordnung 2069/2025): Porta Napoli von der Piazza Rizzo, Via Trinchese, Via Biccari (beide Richtungen) und die Ausfahrt Via dei Mocenigo am Viale XXV Luglio. GateLR zeigt die Zeiten der ganzen Zone: in den freien Stunden nur über die anderen Zufahrten einfahren."),
    ("Coming changes: on 11 March 2026 the council decided 24-hour entry at via Bernardini, via Cairoli and the Porta Rudiae exit, a 24-hour ban in via Brancaccio and taking via Marco Aurelio out of the ZTL; in July 2026 also via Palumbo (press). No ordinance putting them in force was among the City's published acts when checked: follow the signs at those gates.",
     "Modifiche in arrivo: l'11/03/2026 la giunta ha deciso l'ingresso h24 in via Bernardini, via Cairoli e l'uscita di Porta Rudiae, il divieto h24 in via Brancaccio e l'esclusione di via Marco Aurelio dalla ZTL; a luglio 2026 anche via Palumbo (stampa). Alla verifica nessuna ordinanza attuativa era tra gli atti pubblicati dal Comune: seguire i cartelli a quei varchi.",
     "Geplante Änderungen: Am 11.03.2026 beschloss der Stadtrat 24-Stunden-Einfahrt an Via Bernardini, Via Cairoli und der Ausfahrt Porta Rudiae, ein 24-Stunden-Verbot in Via Brancaccio und die Herausnahme der Via Marco Aurelio; im Juli 2026 auch Via Palumbo (Presse). Bei der Prüfung war noch keine Umsetzungsverordnung veröffentlicht: an diesen Zufahrten den Schildern folgen."),
    ("Map outline from OpenStreetMap (relation «ZTL Lecce», 2026, hours as the ordinance), not an official map; the City's open-data map is from 2014. Gate positions at the junctions named in ordinance 2069/2025"
     + (f"; approximate for {', '.join(FALLBACK)}." if FALLBACK else "."),
     "Perimetro da OpenStreetMap (relazione «ZTL Lecce», 2026, con gli orari dell'ordinanza), non da una mappa ufficiale; la mappa open data del Comune è del 2014. Varchi agli incroci indicati dall'ordinanza 2069/2025"
     + (f"; approssimati per {', '.join(FALLBACK)}." if FALLBACK else "."),
     "Grenze aus OpenStreetMap (Relation «ZTL Lecce», 2026, mit den Zeiten der Verordnung), keine offizielle Karte; die offene Karte der Stadt ist von 2014. Kameras an den in der Verordnung 2069/2025 genannten Kreuzungen"
     + (f"; ungefähr für {', '.join(FALLBACK)}." if FALLBACK else ".")),
    ("Electric and hybrid cars: the rules say their access is still to be regulated, so GateLR does not exempt them. Blue Badge: allowed, but during camera hours only if the plate is on the authorised list; an accidental entry must be declared within 48 hours (form «Dichiarazione di Transito in ZTL» by PEC). Occasional permits (OCC) must be requested from the ZTL office; a one-day permit costs 5 €.",
     "Auto elettriche e ibride: il regolamento dice che il loro accesso è ancora da normare, quindi GateLR non le esenta. Contrassegno CUDE: ammessi, ma negli orari dei varchi solo se la targa è nella lista degli autorizzati; un ingresso accidentale va dichiarato entro 48 ore (modulo «Dichiarazione di Transito in ZTL» via PEC). I permessi occasionali (OCC) si chiedono all'ufficio ZTL; il giornaliero costa 5 €.",
     "Elektro- und Hybridautos: Laut Regelung ist ihre Zufahrt noch zu regeln, daher befreit GateLR sie nicht. Behindertenausweis (CUDE): erlaubt, während der Kamerazeiten aber nur, wenn das Kennzeichen auf der Liste steht; eine versehentliche Einfahrt binnen 48 Stunden melden (Formular «Dichiarazione di Transito in ZTL» per PEC). Gelegenheitsgenehmigungen (OCC) beim ZTL-Büro beantragen; ein Tag kostet 5 €."),
    ("Feast of Sant'Oronzo (24–26 August): whether 26 August counts as a holiday for the ZTL is not stated, so it is not treated as one.",
     "Festa di Sant'Oronzo (24–26 agosto): non è indicato se il 26 agosto valga come festivo per la ZTL, quindi non è trattato come tale.",
     "Fest des hl. Oronzo (24.–26. August): Ob der 26. August für die ZTL als Feiertag gilt, ist nicht angegeben, daher wird er nicht so behandelt."),
]

SUMMARY = ("The old town inside the walls is closed to cars without a permit on Monday–Saturday from 1 pm to 4:30 pm and from 8 pm to 10 am, and all day on Sundays and holidays; on Monday–Saturday 10 am–1 pm and 4:30–8 pm the cameras are off. "
           "Porta Napoli, via Trinchese and via Biccari stay closed around the clock. Motorbikes and mopeds may always enter. Staying inside? The hotel or B&B registers your plate (before arrival or within 48 hours) for check-in and check-out only, with 20 minutes to unload.")
SUMMARY_IT = ("Il centro storico dentro le mura è chiuso alle auto senza permesso dal lunedì al sabato dalle 13 alle 16:30 e dalle 20 alle 10, e tutto il giorno la domenica e nei festivi; dal lunedì al sabato 10–13 e 16:30–20 i varchi sono spenti. "
              "Porta Napoli, via Trinchese e via Biccari restano chiusi a tutte le ore. Moto e ciclomotori entrano sempre. Dormi dentro? L'hotel o il B&B registra la targa (prima dell'arrivo o entro 48 ore) solo per arrivo e partenza, con 20 minuti per scaricare.")
SUMMARY_DE = ("Die Altstadt innerhalb der Mauern ist für Autos ohne Genehmigung Montag–Samstag von 13 bis 16:30 Uhr und von 20 bis 10 Uhr gesperrt, sonntags und an Feiertagen den ganzen Tag; Montag–Samstag 10–13 und 16:30–20 Uhr sind die Kameras aus. "
              "Porta Napoli, Via Trinchese und Via Biccari bleiben rund um die Uhr gesperrt. Motorräder und Mopeds dürfen immer hinein. Du übernachtest innen? Hotel oder B&B melden dein Kennzeichen (vor der Ankunft oder binnen 48 Stunden) nur für An- und Abreise, mit 20 Minuten zum Ausladen.")

zone = {"id": "lecce-centro-storico", "name": "Lecce old town · ZTL inside the walls", "name_it": "Lecce centro storico · ZTL dentro le mura",
        "name_de": "Lecce Altstadt · ZTL innerhalb der Mauern", "kind": "restricted",
        "summary": SUMMARY, "summary_it": SUMMARY_IT, "summary_de": SUMMARY_DE,
        "perimeter": shape, "gates": sorted(gate_list, key=lambda g: g["name"]),
        "windows": [{"weekdays": MON_SAT, "start": 0, "end": 10 * 60},
                    {"weekdays": MON_SAT, "start": 13 * 60, "end": 16 * 60 + 30},
                    {"weekdays": MON_SAT, "start": 20 * 60, "end": 24 * 60},
                    {"weekdays": SUN, "start": 0, "end": 24 * 60}],
        "freeOnHolidays": False, "holidaysAsSunday": True, "exemptFuels": [], "hotelCanRegister": True,
        "source": {"authority": "City of Lecce", "pageURL": NEWS_2025,
                   "ordinance": "Delibera GC n. 280 del 10/07/2025; ordinanze dirigenziali n. 1679 del 16/07/2025, n. 1689 del 17/07/2025 e n. 2069 del 09/09/2025",
                   "ordinanceURL": ORD_2069, "quote": QUOTE,
                   "quoteTranslation": "The electronic gates into the old town will be switched off from 10:00 to 13:00 and from 16:30 to 20:00 on working days, while the area stays closed on holidays and Sundays; driving through the Porta Napoli gate will be banned 24 hours a day, every day of the week.",
                   "quoteTranslation_de": "Die elektronischen Kameras an den Zufahrten zur Altstadt werden an Werktagen von 10:00 bis 13:00 und von 16:30 bis 20:00 Uhr ausgeschaltet, an Feiertagen und Sonntagen bleibt das Gebiet gesperrt; die Durchfahrt durch die Kamera Porta Napoli ist rund um die Uhr, an allen Wochentagen verboten.",
                   "checkedOn": CHECKED, "reviewedByHuman": False,
                   "pending": [p[0] for p in PENDING], "pending_it": [p[1] for p in PENDING], "pending_de": [p[2] for p in PENDING],
                   "links": LINKS}}

city = {"id": "lecce", "name": "Lecce", "name_it": "Lecce", "name_de": "Lecce",
        "center": {"lat": 40.3524, "lon": 18.1705}, "zones": [zone], "status": "draft",
        "license": "Rules: Comune di Lecce (ordinances 1679, 1689 and 2069/2025, ZTL regulation). "
                   + ("Perimeter and gate positions: " + osm_geo.ODBL + " (approximate, not official)." if from_osm else "Perimeter: Comune di Lecce.")}

ready = all(len(z["perimeter"]) >= 5 and z["source"]["quote"] for z in city["zones"])
out = ROOT / ("Resources/Cities/lecce.json" if ready else "data/drafts/lecce.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/lecce.json" if ready else "Resources/Cities/lecce.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), [(z["id"], len(z["perimeter"]), len(z["gates"])) for z in city["zones"]], f"{area:.2f} km²", "approssimati:", FALLBACK)
