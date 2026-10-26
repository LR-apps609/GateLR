#!/usr/bin/env python3
# Costruisce Resources/Cities/parma.json dalle pagine e dagli atti ufficiali del Comune di Parma e di Infomobility S.p.A.
# (la società del Comune che gestisce varchi, permessi e sosta) salvati in data/raw/parma/ (fonti e date in docs/fonti-parma.md).
#
# I siti comune.parma.it e infomobility.pr.it non si raggiungono dall'ambiente di lavoro: pagine e PDF sono stati
# scaricati con il workflow «Scarica pagine» (rami pagine-parma-1 e pagine-parma-2). In data/raw/parma/*.txt c'è il testo
# delle pagine (senza HTML) e dei PDF (pdftotext).
#
# Zone:
# - ZTL 1, ZTL 2, ZTL 3 e ZTL Stazione (ordinanza dirigenziale OD-2024-65 del 18/06/2024, tabelle 2.2–2.5): contorni dalle
#   relazioni OpenStreetMap «ZTL Zona 1/2/3» e «ZTL Stazione» (source=Comune di Parma, operator=Polizia Locale di Parma),
#   in data/raw/geo/parma-ztl.json (© OpenStreetMap contributors, ODbL 1.0). Il Comune non pubblica dati aperti sulle ZTL.
# - Isole Ambientali (tabella 2.1 della stessa ordinanza, divieto 0-24): l'area coperta dalle vie dell'elenco ufficiale,
#   con le geometrie delle strade OSM di data/raw/geo/parma-streets.json (Tools/fetch_parma_streets.py), una zona per
#   ciascuno dei tre nuclei (in ZTL 1, ZTL 2 e ZTL 3).
# - Limitazioni PAIR 2030 dei giorni feriali e Domeniche ecologiche (ordinanza sindacale OS-2026-102 del 28/09/2026):
#   «area interna alle tangenziali» (allegato 1), ricavata dalle tangenziali di OSM (data/raw/geo/parma-tangenziali.json):
#   l'area racchiusa dall'anello SS9var / SS9var/A più il raccordo di via Emilio Lepido.
# Varchi: le 5 telecamere elencate da Infomobility; posizione dai nodi OSM «surveillance:type=ALPR» lungo le stesse vie
# (Tommasini-Sauro: l'incrocio delle due vie in OSM).
# Una zona senza perimetro non esce; se nessuna ha il perimetro, la città va in data/drafts/.
# Non aggiorna manifest.json. Uso: python3 Tools/build_parma.py
import json, math, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/parma"
CHECKED = "2026-10-26T08:00:00Z"
EVERY_DAY, MON_FRI, SUN = [1, 2, 3, 4, 5, 6, 7], [2, 3, 4, 5, 6], [1]

IM = "https://www.infomobility.pr.it"
ZTL_PAGE = IM + "/varchi-e-ztl/"
ZTL_PAGE_EN = IM + "/en/electronic-gates-and-ltz/"
ZTL_ORD = IM + "/wp-content/uploads/2024/06/ordinanza_2024_65_18.06.2024.pdf"
TOURIST_CARD = IM + "/wp-content/uploads/2026/08/Cartolina_ZTL_Turisti_2026.pdf"
HOTEL_PAGE = IM + "/permessi-commerciali/"
STREETS_PDF = IM + "/wp-content/uploads/2026/06/VieZTL.pdf"
ROZ_PDF = IM + "/wp-content/uploads/2025/06/ROZ-Ticket-Purchase-Procedure.pdf"
BUS_ORD = IM + "/wp-content/uploads/2024/05/Ordinanza-Varchi-49_2024.pdf"
SAURO_ORD = IM + "/wp-content/uploads/2021/11/Ordinanza-Varco-Sauro-Tommasini.pdf"
BUY_URL = "https://ines.infomobility.pr.it/ar/abb_ar_abbonamenti_acquisto.php?ztl=1"
PAIR_PAGE = IM + "/pair-2030-dal-1-ottobre-2026-in-vigore-le-misure-per-la-qualita-dellaria-previste-dal-piano-aria-integrato-regionale/"
PAIR_ORD = IM + "/wp-content/uploads/2026/10/SU_DET_OS_102_2026.pdf"
PAIR_MAP = IM + "/wp-content/uploads/2026/10/area-soggetta-limitazioni-pair2030.pdf"
ARPAE_PAGE = "https://aggiornati.arpae.it/it/temi-ambientali/aria/liberiamo-laria/limitazioni-per-comune/parma-ordinanze-pair"
EMERG_PAGE = "https://www.comune.parma.it/it/novita/avvisi/misure-emergenziali-per-la-qualita-dellaria"


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


def source(page, quote, translation, links, pending, ordinance=None, ordinance_url=None, authority="City of Parma"):
    """translation e pending: (inglese, tedesco) e (inglese, italiano, tedesco), come in build_padova.py"""
    return {"authority": authority, "pageURL": page, "ordinance": ordinance, "ordinanceURL": ordinance_url,
            "quote": quote, "quoteTranslation": translation[0], "quoteTranslation_de": translation[1],
            "checkedOn": CHECKED, "reviewedByHuman": False,
            "pending": [p[0] for p in pending], "pending_it": [p[1] for p in pending], "pending_de": [p[2] for p in pending],
            "links": links}


def flat(text):
    return re.sub(r"\s+", " ", text).strip()


def raw(name):
    return flat((RAW / name).read_text(encoding="utf-8"))


def must_contain(text, quote, where):
    """Ogni frase citata o riassunta deve esserci davvero nel documento salvato"""
    if flat(quote) not in text:
        raise SystemExit(f"Citazione non trovata in {where}: {quote!r}")


def window(days, start, end, season=None):
    w = {"weekdays": days, "start": start, "end": end}
    if season:
        w["season"] = season
    return w


def season(m1, d1, m2, d2):
    return {"fromMonth": m1, "fromDay": d1, "toMonth": m2, "toDay": d2}


# --- Le frasi su cui si basa la scheda, controllate contro i file in data/raw/parma/ ---
ztl_ord = raw("ordinanza-OD-2024-65-accesso-sosta-ztl.txt")
QUOTE_ZTL = "Il divieto di accesso alle ZTL per i veicoli non autorizzati è vigente nella fascia oraria 7:30-19:30 dei giorni feriali e festivi"
QUOTE_ISOLA = "Il divieto di accesso in Isola Ambientale per i veicoli non autorizzati è vigente nella fascia oraria 0-24 dei giorni feriali e festivi"
for q in ["ORDINANZA DIRIGENZIALE N° OD-2024-65 DEL 18/06/2024", QUOTE_ZTL, QUOTE_ISOLA,
          "orari differenti sono indicati nelle relative tabelle",
          "STR XXII LUGLIO – dalle 7:30 alle 11:30 e dalle 16:00 alle 19:00",
          "VIA CECCHI – dalle 00:00 alle 24:00", "PLE DALLA CHIESA (escluso lato sud) – dalle 00:00 alle 24:00",
          "VIA CORSI – dalle 00:00 alle 24:00", "BGO VALORIO – dalle 00:00 alle 24:00",
          "veicoli di clienti di alberghi e di strutture ricettive ivi ubicati/e esclusivamente per operazioni di trasbordo bagagli",
          "ciclomotori e motocicli;",
          "veicoli a servizio di persone con limitate o impedite capacità motorie muniti del contrassegno di parcheggio per disabili",
          "devono comunque presentare specifica richiesta di accreditamento al Concessionario, individuato in Infomobility SpA"]:
    must_contain(ztl_ord, q, "ordinanza OD-2024-65")
ztl_page = raw("infomobility-varchi-e-ztl.txt")
QUOTE_GATES = ("Viale Toscanini tutti i giorni 7:30 - 19:30 Viale Mariotti (corsia nord - sud) tutti i giorni 7:30 - 19:30 "
               "Piazzale Salvo D’Acquisto tutti i giorni 7:30 - 19:30 Via XXII Luglio tutti i giorni 7:30 - 11:30 / 16:00 - 19:00 "
               "Isola Ambientale Tommasini-Sauro (Borgo G. Tommasini angolo Via N. Sauro) tutti i giorni 24h")
for q in [QUOTE_GATES,
          "Indipendentemente dalla categoria, tutti possono accedere alle ZTL tramite l’acquisto di Titoli di sosta Giornalieri e Bi-orari da attivarsi prima dell'utilizzo.",
          "Biorario (BZ) € 5 2 ore Giornaliero (GZ) € 10 Tutto il giorno",
          "entro le ore 23.59 del giorno successivo a quello dell’accesso non precedentemente autorizzato, alla tariffa di 15 euro",
          "Utenti occasionali, muniti di titolo biorario o giornaliero di accesso alla ZTL, possono richiedere anche l’accesso all’isola ambientale, negli orari 9:00 - 10:30 o 15:00 - 15:30",
          "Veicoli di clienti di alberghi (esclusivamente per le operazioni di trasbordo bagagli)",
          "Strada Garibaldi, Strada Repubblica, Strada Bixio, Via D’Azeglio, Viale Falcone - sottopasso Stazione Ferroviaria e Via Montebello"]:
    must_contain(ztl_page, q, "pagina Infomobility Varchi e ZTL")
card = raw("cartolina-ztl-turisti-2026.txt")
for q in ["BZ – 2 ore a soli 5 € (sosta inclusa!)", "GZ – Giornaliero a 10 € (sosta inclusa!)",
          "acquistando un ticket ROZ (15€, sosta esclusa) entro le 23:59 del giorno successivo all'ingresso",
          "ISOLE AMBIENTALI E AREE PEDONALI: Tutti i giorni h. 24"]:
    must_contain(card, q, "guida ZTL per turisti 2026")
hotel = raw("infomobility-permessi-commerciali.txt")
for q in ["Le strutture ricettive situate nelle ZTL possono autorizzare i veicoli dei loro clienti ad accedere alla struttura e sostare per le sole operazioni di carico e scarico",
          "per autorizzare l’accesso è necessario fornire la targa del veicolo del cliente, data di arrivo e di partenza",
          "la struttura ricettiva dovrà dare comunicazione all’Ufficio Varchi della targa del veicolo del cliente entro la giornata di arrivo del cliente"]:
    must_contain(hotel, q, "pagina Infomobility Permessi commerciali")
bus_ord = raw("ordinanza-OD-2024-49-corsie-preferenziali.txt")
must_contain(bus_ord, "Ai veicoli dei clienti diretti agli alberghi è consentito il transito nella corsia preferenziale di str. Garibaldi, nel tratto compreso tra via Bodoni e via Pisacane, e nella corsia preferenziale di v.le Toscanini.", "ordinanza OD-2024-49")
must_contain(bus_ord, "i veicoli elettrici (compresi ibridi e plug-in) non potranno più utilizzare le corsie preferenziali", "ordinanza OD-2024-49")
pair = raw("ordinanza-OS-2026-102-pair.txt")
QUOTE_PAIR = ("Dal 01/10/2026 al 31/03/2027, dal lunedì al venerdì, dalle 08.30 alle 18.30, eccetto che nelle giornate festive del "
              "08/12/2026, 25/12/2026, 01/01/2027, 06/01/2027")
QUOTE_SUN = "Nelle domeniche ecologiche previste ogni domenica dal 01/10/2026 al 31/03/2027, dalle 08.30 alle 18.30, ad eccezione del 01/11/2026"
for q in ["ORDINANZA SINDACALE N° OS-2026-102 DEL 28/09/2026", QUOTE_PAIR, QUOTE_SUN,
          "nei giorni di indizione di scioperi che riguardano il Trasporto Pubblico Locale, in tutta l’area interna alle tangenziali",
          "veicoli alimentati a benzina EURO 0, EURO 1 ed EURO 2",
          "veicoli alimentati a GPL/benzina o metano/benzina EURO 0, EURO 1 ed EURO 2",
          "veicoli diesel EURO 0, EURO 1, EURO 2, EURO 3 ed EURO 4 non conformi",
          "veicoli diesel EURO 0, EURO 1, EURO 2, EURO 3, EURO 4 ed EURO 5 non conformi",
          "autoveicoli elettrici o ibridi dotati di motore elettrico",
          "si istituisce dalle 8:00 alle 19:00 il divieto di totale di circolazione",
          "veicoli a servizio di persone soggiornanti presso le strutture di tipo alberghiero site nelle aree delimitate, esclusivamente per arrivare/partire dalla struttura medesima, dotati di prenotazione",
          "prevista la sanzione amministrativa pecuniaria da € 168,00 a € 679,00",
          "Area delle Scienze (Campus Universitario)"]:
    must_contain(pair, q, "ordinanza sindacale OS-2026-102")
pair_page = raw("infomobility-pair-2030-dal-1-ottobre-2026.txt")
for q in ["non viene introdotto il blocco strutturale dei veicoli diesel Euro 5",
          "Il blocco dei diesel Euro 5 resta invece previsto durante le Domeniche Ecologiche e in caso di attivazione delle misure emergenziali."]:
    must_contain(pair_page, q, "pagina Infomobility PAIR 2030")
must_contain(raw("arpae-parma-ordinanze-pair.txt"), "Ordinanza del Comune di Parma n. 102 del 28/09/2026", "pagina Arpae Parma ordinanze PAIR")


# --- Link comuni ---
ZTL_LINKS = [
    link("Infomobility (City of Parma): gates and ZTL, hours and tickets", "Infomobility (Comune di Parma): varchi e ZTL, orari e titoli",
         "Infomobility (Stadt Parma): Kameras und ZTL, Zeiten und Tickets", ZTL_PAGE),
    link("Infomobility: ZTL guide for tourists 2026 (PDF)", "Infomobility: guida ZTL per turisti 2026 (PDF)",
         "Infomobility: ZTL-Leitfaden für Touristen 2026 (PDF)", TOURIST_CARD),
    link("City of Parma: ZTL access ordinance OD-2024-65 (street lists, PDF)", "Comune di Parma: ordinanza OD-2024-65 accesso e sosta ZTL (elenchi delle vie, PDF)",
         "Stadt Parma: ZTL-Verordnung OD-2024-65 (Straßenlisten, PDF)", ZTL_ORD),
    link("Infomobility: ZTL streets list (June 2026, PDF)", "Infomobility: elenco vie ZTL (giugno 2026, PDF)",
         "Infomobility: ZTL-Straßenliste (Juni 2026, PDF)", STREETS_PDF),
    link("Infomobility: hotels and B&Bs (guest plates)", "Infomobility: alberghi e B&B (targhe dei clienti)",
         "Infomobility: Hotels und B&Bs (Kennzeichen der Gäste)", HOTEL_PAGE),
    link("Infomobility: how to buy the ROZ ticket online (PDF)", "Infomobility: come acquistare online il titolo ROZ (PDF)",
         "Infomobility: ROZ-Ticket online kaufen (PDF)", ROZ_PDF),
]
PAIR_LINKS = [
    link("Infomobility: PAIR 2030 air-quality measures from 1 October 2026", "Infomobility: misure PAIR 2030 per la qualità dell'aria dal 1° ottobre 2026",
         "Infomobility: Luftreinhaltemaßnahmen PAIR 2030 ab 1. Oktober 2026", PAIR_PAGE),
    link("City of Parma: Mayor's ordinance OS-2026-102 (PDF)", "Comune di Parma: ordinanza sindacale OS-2026-102 (PDF)",
         "Stadt Parma: Verordnung des Bürgermeisters OS-2026-102 (PDF)", PAIR_ORD),
    link("City of Parma: map of the area inside the ring roads (Annex 1, PDF)", "Comune di Parma: mappa dell'area interna alle tangenziali (allegato 1, PDF)",
         "Stadt Parma: Karte des Gebiets innerhalb der Ringstraßen (Anlage 1, PDF)", PAIR_MAP),
    link("Arpae Emilia-Romagna: emergency measures bulletin", "Arpae Emilia-Romagna: bollettino misure emergenziali",
         "Arpae Emilia-Romagna: Bulletin der Notfallmaßnahmen",
         "https://www.arpae.it/it/temi-ambientali/aria/liberiamo-laria/bollettino-misure-emergenziali/bollettino-misure-emergenziali"),
    link("Arpae Emilia-Romagna: Parma PAIR ordinances", "Arpae Emilia-Romagna: ordinanze PAIR di Parma", "Arpae Emilia-Romagna: PAIR-Verordnungen Parma", ARPAE_PAGE),
    link("Italian Motorist Portal: check your car's Euro class", "Portale dell'Automobilista: verifica la classe Euro",
         "Italienisches Fahrerportal: Euro-Klasse prüfen", "https://www.ilportaledellautomobilista.it/web/portale-automobilista/ext/verifica-classe-ambientale-veicolo"),
]


# --- Geometria ---
OSM_ZTL = {"1": 19457676, "2": 19457325, "3": 19457327, "S": 19457326}   # relazioni OSM «ZTL Zona 1/2/3», «ZTL Stazione»
ztl_els = osm_geo.load("parma-ztl")
RINGS = {k: osm_geo.outer_ring(osm_geo.relation(ztl_els, v)) for k, v in OSM_ZTL.items()}

streets = osm_geo.load("parma-streets")
BY_NAME = {}
for w in streets:
    BY_NAME.setdefault(w["tags"]["name"], []).append([(n["lon"], n["lat"]) for n in w["geometry"]])

# Tabella 2.1 dell'ordinanza OD-2024-65 (vie in Isola Ambientale), con i nomi di OpenStreetMap; (nome, da, a) = solo quel tratto
ISOLA = {
    "1": [("Strada al Duomo",), ("Piazzale Antonio Barezzi",), ("Borgo Basinio Basini",), ("Piazzale del Battistero",), ("Vicolo al Battistero",),
          ("Piazza Cesare Battisti",), ("Via Cardinal Andrea Carlo Ferrari",), ("Strada Cavour",),
          ("Strada Eugenio Copelli", "Borgo Paggeria", "Piazza Ghiaia"), ("Via Dante Alighieri",), ("Strada del Consorzio",),
          ("Borgo del Gallo",), ("Vicolo del Medioevo",), ("Vicolo del Vescovado",), ("Vicolo dell'Assistenza",), ("Piazzale della Macina",),
          ("Piazza della Steccata",), ("Piazza Duomo",), ("Strada Giuseppe Garibaldi", "Strada Giuseppe Mazzini", "Strada Macedonio Melloni"),
          ("Borgo Carlo Goldoni",), ("Borgo Leon D'oro",), ("Borgo Bruno Longhi",), ("Borgo Goffredo Mameli",), ("Borgo Angelo Mazza",),
          ("Via Vincenzo Mistrali",), ("Piazzale Ferdinando Paer",), ("Borgo Paggeria", "Piazza Ghiaia", "Strada Eugenio Copelli"),
          ("Borgo Pipa", "Piazzale San Giovanni", "Strada del Consorzio"), ("Strada Carlo Pisacane",), ("Borgo Amadio Ronchini",),
          ("Vicolo Sant'Alessandro",), ("Borgo Sant'Ambrogio",), ("Borgo San Antonio",), ("Piazzale San Bartolomeo",), ("Borgo San Biagio",),
          ("Borgo Santa Brigida",), ("Piazzale San Giovanni",), ("Vicolo San Moderanno",), ("Vicolo San Simone",), ("Borgo Serena",),
          ("Borgo Venti Marzo",), ("Borgo Zaccagni Bernardino e Gian Francesco",)],
    "2": [("Volta Antini",), ("Borgo Bianchi",), ("Vicolo delle Caligarie",), ("Vicolo Fratelli Cervi",), ("Vicolo delle Cinque Piaghe",),
          ("Borgo del Carbone",), ("Piazzale della Rosa",), ("Borgo della Salina",),
          ("Strada dell'Università", "Strada Giordano Cavestro", "Piazza Giuseppe Garibaldi"),
          ("Strada Luigi Carlo Farini", "Piazza Giuseppe Garibaldi", "Borgo Antini"), ("Via Ferdinando Maestri",), ("Via Nazario Sauro",),
          ("Borgo Palmia",), ("Vicolo Politi",), ("Borgo Gian Domenico Romagnosi",), ("Piazzale Sant'Apollonia",), ("Vicolo Sant'Apollonia",),
          ("Borgo Santa Chiara d'Assisi",), ("Vicolo San Tiburzio",), ("Borgo San Silvestro", "Borgo del Canale", "Via Nazario Sauro"),
          ("Borgo Schizzati", "Vicolo Vallaria", "Via Nazario Sauro"), ("Borgo Tasso",),
          ("Borgo Giacomo Tommasini", "Strada della Repubblica", "Borgo Schizzati"), ("Via Piero Torrigiani",), ("Vicolo Vallaria",)],
    "3": [("Strada Matteo Renato Imbriani", "Borgo Marodolo", "Piazza delle Barricate"), ("Piazza delle Barricate",)],
    "3i": [("Strada Giovanni Inzani", "Borgo Marodolo", "Strada Massimo D'Azeglio")],   # nuova isola (delibera GC 125/2024)
}


def nearest(name, other):
    """Il punto della via «name» più vicino alla via «other» (l'incrocio)"""
    if other not in BY_NAME:
        raise SystemExit(f"Via non trovata in OSM: {other}")
    pts = [p for l in BY_NAME[name] for p in l]
    opts = [p for l in BY_NAME[other] for p in l]
    return min(pts, key=lambda p: min((p[0] - q[0]) ** 2 * 0.51 + (p[1] - q[1]) ** 2 for q in opts))


def clip(line, a, b):
    """Il tratto della via tra i punti a e b (proiezione sul segmento a–b, con 12 m di margine)"""
    fwd, _ = osm_geo._proj(a[1])
    (ax, ay), (bx, by) = fwd(*a), fwd(*b)
    L = math.hypot(bx - ax, by - ay) or 1
    parts, cur = [], []
    for p in line:
        x, y = fwd(*p)
        t = ((x - ax) * (bx - ax) + (y - ay) * (by - ay)) / (L * L)
        if -12 / L <= t <= 1 + 12 / L:
            cur.append(p)
        else:
            if len(cur) >= 2:
                parts.append(cur)
            cur = []
    if len(cur) >= 2:
        parts.append(cur)
    return parts


SMALL = ("3", "3i")


def isola_ring(z):
    ring = RINGS[z[0]]
    inside = lambda p: osm_geo.inside_lonlat(ring, *p) or osm_geo.distance_m(ring, p[1], p[0]) < 15
    lines = []
    for s in ISOLA[z]:
        if s[0] not in BY_NAME:
            raise SystemExit(f"Via dell'Isola Ambientale non trovata in OSM: {s[0]}")
        for l in BY_NAME[s[0]]:
            for part in (clip(l, nearest(s[0], s[1]), nearest(s[0], s[2])) if len(s) == 3 else [l]):
                part = [p for p in part if inside(p)]
                if len(part) >= 2:
                    lines.append(part)
        if len(s) == 3:   # il tratto arriva fino alle vie di inizio e fine (piazze comprese)
            for other in s[1:]:
                lines.append([nearest(s[0], other), nearest(other, s[0])])
    if z in SMALL:   # nuclei piccoli (una piazza e una via, o una via sola): inviluppo convesso delle vie allargate di 8 m
        fwd, back = osm_geo._proj(lines[0][0][1])
        pts = [back(x + 8 * math.cos(k * math.pi / 4), y + 8 * math.sin(k * math.pi / 4))
               for l in lines for p in l for x, y in [fwd(*p)] for k in range(8)]
        hull = osm_geo.convex_hull(pts)
        return hull + [hull[0]]
    rel = {"id": f"isola-{z}", "members": [{"type": "way", "role": "section", "geometry": [{"lon": p[0], "lat": p[1]} for p in l]} for l in lines]}
    out = osm_geo.street_area(rel, cell_m=5, close_m=40)
    # controllo: quasi tutte le vie dell'elenco devono stare nel contorno (un nucleo staccato non deve sparire)
    mids = [l[len(l) // 2] for l in lines]
    miss = [m for m in mids if not osm_geo.inside_lonlat(out, *m) and osm_geo.distance_m(out, m[1], m[0]) > 8]
    if len(miss) > 0.12 * len(mids):
        raise SystemExit(f"Isola Ambientale ZTL {z}: {len(miss)} vie su {len(mids)} fuori dal contorno")
    return out


def ring_area():
    """L'area interna alle tangenziali: le tangenziali di OSM su una griglia di 25 m, i buchi racchiusi dall'anello riempiti"""
    lines = [[(n["lon"], n["lat"]) for n in e["geometry"]] for e in osm_geo.load("parma-tangenziali")]
    fwd, back = osm_geo._proj(44.80)
    cell = 25.0
    cells = set()
    for l in lines:
        xy = [fwd(*p) for p in l]
        for (ax, ay), (bx, by) in zip(xy, xy[1:]):
            n = max(1, int(math.hypot(bx - ax, by - ay) / (cell / 3)))
            for s in range(n + 1):
                cells.add((math.floor((ax + (bx - ax) * s / n) / cell), math.floor((ay + (by - ay) * s / n) / cell)))
    grown = {(x + dx, y + dy) for x, y in cells for dx in (-1, 0, 1) for dy in (-1, 0, 1)}
    holes = osm_geo._fill_holes(grown) - grown
    if not holes:
        raise SystemExit("L'anello delle tangenziali non si chiude")
    # il buco più grande è l'area interna; il contorno passa a metà della carreggiata (si aggiunge l'anello di celle)
    seen, best = set(), set()
    for c in holes:
        if c in seen:
            continue
        comp, todo = {c}, [c]
        seen.add(c)
        while todo:
            x, y = todo.pop()
            for d in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if d in holes and d not in seen:
                    seen.add(d); comp.add(d); todo.append(d)
        if len(comp) > len(best):
            best = comp
    area = best | {(x + dx, y + dy) for x, y in best for dx in (-1, 0, 1) for dy in (-1, 0, 1)}
    # contorno con street_area su una «via» fittizia fatta dei centri delle celle
    rel = {"id": "pair", "members": [{"type": "way", "role": "section", "geometry": [
        {"lon": back((x + 0.5) * cell, (y + 0.5) * cell)[0], "lat": back((x + 0.5) * cell, (y + 0.5) * cell)[1]},
        {"lon": back((x + 0.6) * cell, (y + 0.5) * cell)[0], "lat": back((x + 0.6) * cell, (y + 0.5) * cell)[1]}]} for x, y in area]}
    return osm_geo.street_area(rel, cell_m=cell, close_m=cell)


def alpr(node_id):
    for e in osm_geo.load("parma-cameras"):
        if e["type"] == "node" and e["id"] == node_id:
            return round(e["lat"], 6), round(e["lon"], 6)
    raise SystemExit(f"Nodo OSM {node_id} non trovato")


def crossing(a, b):
    p = nearest(a, b)
    return round(p[1], 6), round(p[0], 6)


# I 5 varchi di Infomobility; posizione: nodi OSM surveillance:type=ALPR sulla stessa via, o l'incrocio indicato
GATES = {
    "1": [("pr-1-mariotti", "Viale Mariotti (north–south lane)", alpr(7173204180)),
          ("pr-1-dacquisto", "Piazzale Salvo D'Acquisto", alpr(14131154046))],
    "2": [("pr-2-toscanini", "Viale Toscanini", alpr(4718425106)),
          ("pr-2-xxii-luglio", "Via XXII Luglio (7:30–11:30, 16:00–19:00)", alpr(7179007287))],
    "isola2": [("pr-ia-tommasini-sauro", "Borgo Tommasini / Via Sauro", crossing("Borgo Giacomo Tommasini", "Via Nazario Sauro"))],
}


def gates(key):
    return [{"id": i, "name": n, "location": {"lat": p[0], "lon": p[1]}} for i, n, p in GATES.get(key, [])]


OSM_LINKS = {k: link(f"OpenStreetMap: relation {v} (ODbL)", f"OpenStreetMap: relazione {v} (ODbL)", f"OpenStreetMap: Relation {v} (ODbL)",
                     osm_geo.osm_url("relation", v)) for k, v in OSM_ZTL.items()}

# --- Testi ---
GEO_PENDING = ("Outline from OpenStreetMap (relation tagged source=Comune di Parma), to be checked against the official street list of ordinance OD-2024-65 and the Infomobility map.",
               "Contorno da OpenStreetMap (relazione con source=Comune di Parma), da verificare con l'elenco ufficiale delle vie dell'ordinanza OD-2024-65 e con la mappa di Infomobility.",
               "Umriss aus OpenStreetMap (Relation mit source=Comune di Parma), mit der offiziellen Straßenliste der Verordnung OD-2024-65 und der Infomobility-Karte abzugleichen.")
GATE_PENDING = ("Camera positions: OpenStreetMap ALPR cameras on the streets named by Infomobility, matched by GateLR (approximate). Streets without a camera are still part of the ZTL and are checked by the local police.",
                "Posizione dei varchi: telecamere ALPR di OpenStreetMap sulle vie indicate da Infomobility, abbinate da GateLR (approssimate). Le vie senza telecamera fanno comunque parte della ZTL e sono controllate dalla Polizia Locale.",
                "Kamerastandorte: ALPR-Kameras aus OpenStreetMap an den von Infomobility genannten Straßen, von GateLR zugeordnet (ungefähr). Straßen ohne Kamera gehören trotzdem zur ZTL und werden von der Stadtpolizei kontrolliert.")
HOTEL_PENDING = ("If your hotel is inside, it gives Infomobility's gate office your plate and your arrival and departure dates, at the latest on the day you arrive: you may then drive to the hotel to load and unload luggage only. Ask the hotel before you come.",
                 "Se l'hotel è dentro, comunica all'Ufficio Varchi di Infomobility la targa e le date di arrivo e partenza, al più tardi il giorno dell'arrivo: puoi allora arrivare all'hotel solo per caricare e scaricare i bagagli. Chiedi all'hotel prima di partire.",
                 "Liegt dein Hotel innen, meldet es dem Kamerabüro von Infomobility dein Kennzeichen sowie An- und Abreisedatum, spätestens am Anreisetag: dann darfst du nur zum Be- und Entladen des Gepäcks zum Hotel fahren. Frag vorher im Hotel nach.")
EV_PENDING = ("Electric and hybrid cars have no exemption: they need a ticket or a permit like any other car.",
              "Le auto elettriche e ibride non sono esenti: serve il ticket o un permesso come per le altre auto.",
              "Elektro- und Hybridautos sind nicht ausgenommen: sie brauchen ein Ticket oder eine Genehmigung wie jedes andere Auto.")
FINE_PENDING = ("The fine for driving in without a ticket is not stated on the city's pages; if you forgot the ticket, the €15 ROZ (by 23:59 the next day) regularises the entry.",
                "L'importo della multa per l'ingresso senza titolo non è indicato nelle pagine del Comune; se hai dimenticato il ticket, il ROZ da 15 € (entro le 23:59 del giorno dopo) regolarizza l'ingresso.",
                "Die Höhe des Bußgelds für die Einfahrt ohne Ticket steht nicht auf den Seiten der Stadt; hast du das Ticket vergessen, legalisiert das ROZ für 15 € (bis 23:59 Uhr am Folgetag) die Einfahrt.")

TICKET = {"price": 10.0,
          "howTo": "GZ day ticket €10, or BZ €5 for 2 hours; parking in the ZTL's paid spaces included. Buy and activate it before you pass the camera: Tap&Park app, the Infomobility website, the parking meters next to the gates, Infomobility's desk (Viale Mentana 29/A) or partner tobacconists. Forgot? A €15 ROZ ticket bought by 23:59 the next day regularises the entry (parking not included). It does not open the Isole Ambientali.",
          "howTo_it": "Ticket giornaliero GZ 10 €, oppure BZ 5 € per 2 ore; sosta inclusa negli stalli a pagamento della ZTL. Compralo e attivalo prima di passare dal varco: app Tap&Park, sito di Infomobility, parcometri vicino ai varchi, sportello Infomobility (viale Mentana 29/A) o tabaccherie convenzionate. Dimenticato? Il ROZ da 15 € comprato entro le 23:59 del giorno dopo regolarizza l'ingresso (sosta esclusa). Non vale per le Isole Ambientali.",
          "howTo_de": "Tagesticket GZ 10 € oder BZ 5 € für 2 Stunden; Parken auf den gebührenpflichtigen Plätzen der ZTL inklusive. Vor der Kamera kaufen und aktivieren: App Tap&Park, Website von Infomobility, Parkautomaten neben den Kameras, Infomobility-Schalter (Viale Mentana 29/A) oder Partner-Tabakläden. Vergessen? Ein ROZ-Ticket für 15 €, gekauft bis 23:59 Uhr am Folgetag, legalisiert die Einfahrt (ohne Parken). Gilt nicht für die Isole Ambientali.",
          "url": BUY_URL, "deadline": "beforeEntry"}

ZTL_TXT = {
    "1": (("ZTL 1 · Duomo, Pilotta and Via Garibaldi", "ZTL 1 · Duomo, Pilotta e strada Garibaldi", "ZTL 1 · Dom, Pilotta und Via Garibaldi"),
          "Cameras at Viale Mariotti and Piazzale Salvo D'Acquisto."),
    "2": (("ZTL 2 · Strada Farini and Via XXII Luglio", "ZTL 2 · Strada Farini e via XXII Luglio", "ZTL 2 · Strada Farini und Via XXII Luglio"),
          "Cameras at Viale Toscanini and Via XXII Luglio."),
    "3": (("ZTL 3 · Oltretorrente (Piazzale Corridoni)", "ZTL 3 · Oltretorrente (piazzale Corridoni)", "ZTL 3 · Oltretorrente (Piazzale Corridoni)"),
          None),
}
SUMMARY_ZTL = ("Every day from 7:30 am to 7:30 pm, holidays included, you can't drive in without a permit or a ticket: GZ day ticket €10 or BZ €5 for 2 hours, bought and activated before the camera (parking included). Forgot? Buy a €15 ROZ by 23:59 the next day. Motorbikes may enter; electric cars may not. If your hotel is inside, it registers your plate by the day you arrive, for luggage only. The Isole Ambientali inside are closed around the clock.",
               "Tutti i giorni dalle 7:30 alle 19:30, festivi compresi, non si entra senza permesso o ticket: giornaliero GZ 10 € o BZ 5 € per 2 ore, comprato e attivato prima del varco (sosta inclusa). Dimenticato? Compra il ROZ da 15 € entro le 23:59 del giorno dopo. Le moto entrano, le auto elettriche no. Se l'hotel è dentro, registra la targa entro il giorno dell'arrivo, solo per i bagagli. Le Isole Ambientali all'interno sono chiuse 24 ore su 24.",
               "Täglich von 7:30 bis 19:30 Uhr, auch an Feiertagen, keine Einfahrt ohne Genehmigung oder Ticket: Tagesticket GZ 10 € oder BZ 5 € für 2 Stunden, vor der Kamera gekauft und aktiviert (Parken inklusive). Vergessen? Kauf bis 23:59 Uhr am Folgetag ein ROZ für 15 €. Motorräder dürfen hinein, Elektroautos nicht. Liegt dein Hotel innen, meldet es dein Kennzeichen bis zum Anreisetag, nur fürs Gepäck. Die Isole Ambientali im Inneren sind rund um die Uhr gesperrt.")
SUMMARY_STAZ = ("The small ZTL in the station square (Via Cecchi and Piazzale Dalla Chiesa, except the south side) is closed to unauthorised cars 24 hours a day, every day. Use the station car parks instead.",
                "La piccola ZTL della piazza della stazione (via Cecchi e piazzale Dalla Chiesa, escluso il lato sud) è chiusa alle auto non autorizzate 24 ore su 24, tutti i giorni. Usa i parcheggi della stazione.",
                "Die kleine ZTL am Bahnhofsplatz (Via Cecchi und Piazzale Dalla Chiesa, außer der Südseite) ist rund um die Uhr, täglich für nicht berechtigte Autos gesperrt. Nutze die Bahnhofsparkplätze.")
SUMMARY_ISOLA = ("Closed to unauthorised cars 24 hours a day, every day, holidays included; the ZTL ticket is not enough. Hotel guests may drive in only to load and unload luggage, once the hotel has registered the plate. With a ZTL ticket you can ask Infomobility's desk for access 9–10:30 am or 3–3:30 pm. Park outside and walk.",
                 "Chiusa alle auto non autorizzate 24 ore su 24, tutti i giorni, festivi compresi; il ticket ZTL non basta. Gli ospiti degli hotel entrano solo per caricare e scaricare i bagagli, dopo che l'hotel ha registrato la targa. Con il ticket ZTL si può chiedere allo sportello Infomobility l'accesso 9–10:30 o 15–15:30. Parcheggia fuori e prosegui a piedi.",
                 "Rund um die Uhr, täglich und auch an Feiertagen für nicht berechtigte Autos gesperrt; das ZTL-Ticket reicht nicht. Hotelgäste dürfen nur zum Be- und Entladen des Gepäcks hinein, nachdem das Hotel das Kennzeichen gemeldet hat. Mit ZTL-Ticket kann man am Infomobility-Schalter Zufahrt 9–10:30 oder 15–15:30 Uhr beantragen. Draußen parken und zu Fuß gehen.")
ISOLA_NAMES = {"1": ("Isola Ambientale · Duomo and Steccata", "Isola Ambientale · Duomo e Steccata", "Isola Ambientale · Dom und Steccata"),
               "2": ("Isola Ambientale · Strada Farini and Via Sauro", "Isola Ambientale · strada Farini e via Sauro", "Isola Ambientale · Strada Farini und Via Sauro"),
               "3": ("Isola Ambientale · Piazza delle Barricate", "Isola Ambientale · piazza delle Barricate", "Isola Ambientale · Piazza delle Barricate"),
               "3i": ("Isola Ambientale · Strada Inzani", "Isola Ambientale · strada Inzani", "Isola Ambientale · Strada Inzani")}
ISOLA_PENDING = ("Outline computed from the official street list (table 2.1 of ordinance OD-2024-65) on OpenStreetMap streets: approximate, to be checked against the Infomobility map.",
                 "Contorno ricavato dall'elenco ufficiale delle vie (tabella 2.1 dell'ordinanza OD-2024-65) sulle strade di OpenStreetMap: approssimato, da verificare con la mappa di Infomobility.",
                 "Umriss aus der offiziellen Straßenliste (Tabelle 2.1 der Verordnung OD-2024-65) auf OpenStreetMap-Straßen berechnet: ungefähr, mit der Infomobility-Karte abzugleichen.")
ZTL2_PENDING = ("On Via XXII Luglio, Borgo Felino, Strada Nuova and a few nearby streets the ZTL applies only 7:30–11:30 and 16:00–19:00; GateLR shows the whole ZTL 2 with 7:30–19:30.",
                "In via XXII Luglio, borgo Felino, strada Nuova e poche vie vicine la ZTL vale solo 7:30–11:30 e 16:00–19:00; GateLR mostra tutta la ZTL 2 con 7:30–19:30.",
                "In der Via XXII Luglio, im Borgo Felino, in der Strada Nuova und einigen Nachbarstraßen gilt die ZTL nur 7:30–11:30 und 16:00–19:00 Uhr; GateLR zeigt die ganze ZTL 2 mit 7:30–19:30 Uhr.")
ZTL1_PENDING = ("Via Corsi, Via Dalmazia (Stradello S. Girolamo–Viale Mentana), Vicolo Mauroner and Borgo Valorio are closed 24 hours a day; GateLR shows the whole ZTL 1 with 7:30–19:30.",
                "Via Corsi, via Dalmazia (da stradello S. Girolamo a viale Mentana), vicolo Mauroner e borgo Valorio sono chiusi 24 ore su 24; GateLR mostra tutta la ZTL 1 con 7:30–19:30.",
                "Via Corsi, Via Dalmazia (Stradello S. Girolamo–Viale Mentana), Vicolo Mauroner und Borgo Valorio sind rund um die Uhr gesperrt; GateLR zeigt die ganze ZTL 1 mit 7:30–19:30 Uhr.")

zones = []
for z in ["1", "2", "3"]:
    (en, it, de), _ = ZTL_TXT[z]
    pend = [GEO_PENDING, HOTEL_PENDING, EV_PENDING, FINE_PENDING] + ([GATE_PENDING] if z in GATES else []) \
        + ([ZTL1_PENDING] if z == "1" else []) + ([ZTL2_PENDING] if z == "2" else []) \
        + ([("ZTL 3 has no camera: the rules apply all the same and are enforced by the local police.",
             "La ZTL 3 non ha varchi elettronici: le regole valgono lo stesso e le controlla la Polizia Locale.",
             "Die ZTL 3 hat keine Kamera: die Regeln gelten trotzdem und werden von der Stadtpolizei kontrolliert.")] if z == "3" else [])
    zones.append({"id": f"parma-ztl-{z}", "name": en, "name_it": it, "name_de": de, "kind": "pass",
                  "summary": SUMMARY_ZTL[0], "summary_it": SUMMARY_ZTL[1], "summary_de": SUMMARY_ZTL[2],
                  "perimeter": osm_geo.perimeter(RINGS[z], tol_m=3), "gates": gates(z),
                  "windows": [window(EVERY_DAY, 7 * 60 + 30, 19 * 60 + 30)],
                  "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": True, "ticket": TICKET,
                  "source": source(ZTL_PAGE, QUOTE_ZTL,
                                   ("The ban on unauthorised vehicles entering the ZTLs applies from 7:30 to 19:30 on working days and holidays",
                                    "Das Einfahrverbot für nicht berechtigte Fahrzeuge in die ZTL gilt von 7:30 bis 19:30 Uhr an Werk- und Feiertagen"),
                                   ZTL_LINKS + [OSM_LINKS[z]], pend,
                                   "Ordinanza dirigenziale OD-2024-65 del 18/06/2024 (Aggiornamento delle modalità di accesso e sosta in ZTL)", ZTL_ORD)})

for z in ["1", "2", "3", "3i"]:
    en, it, de = ISOLA_NAMES[z]
    zones.append({"id": f"parma-isola-{z}", "name": en, "name_it": it, "name_de": de, "kind": "restricted",
                  "summary": SUMMARY_ISOLA[0], "summary_it": SUMMARY_ISOLA[1], "summary_de": SUMMARY_ISOLA[2],
                  "perimeter": osm_geo.perimeter(isola_ring(z), tol_m=3), "gates": gates("isola2") if z == "2" else [],
                  "windows": [window(EVERY_DAY, 0, 24 * 60)],
                  "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": True,
                  "source": source(ZTL_PAGE, QUOTE_ISOLA,
                                   ("The ban on unauthorised vehicles entering an Isola Ambientale applies 0–24 on working days and holidays",
                                    "Das Einfahrverbot für nicht berechtigte Fahrzeuge in eine Isola Ambientale gilt 0–24 Uhr an Werk- und Feiertagen"),
                                   ZTL_LINKS, [ISOLA_PENDING, HOTEL_PENDING] + ([GATE_PENDING] if z == "2" else [
                                       ("No camera here: the ban applies all the same and is enforced by the local police.",
                                        "Qui non ci sono varchi elettronici: il divieto vale lo stesso e lo controlla la Polizia Locale.",
                                        "Hier gibt es keine Kamera: das Verbot gilt trotzdem und wird von der Stadtpolizei kontrolliert.")]),
                                   "Ordinanza dirigenziale OD-2024-65 del 18/06/2024, tabella 2.1", ZTL_ORD)})

zones.append({"id": "parma-ztl-stazione", "name": "ZTL Stazione · Station square", "name_it": "ZTL Stazione · Piazzale della stazione",
              "name_de": "ZTL Stazione · Bahnhofsplatz", "kind": "restricted",
              "summary": SUMMARY_STAZ[0], "summary_it": SUMMARY_STAZ[1], "summary_de": SUMMARY_STAZ[2],
              "perimeter": osm_geo.perimeter(RINGS["S"], tol_m=2), "gates": [],
              "windows": [window(EVERY_DAY, 0, 24 * 60)], "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": False,
              "source": source(ZTL_PAGE, "PLE DALLA CHIESA (escluso lato sud) – dalle 00:00 alle 24:00",
                               ("Piazzale Dalla Chiesa (except the south side): from 00:00 to 24:00", "Piazzale Dalla Chiesa (außer Südseite): von 00:00 bis 24:00 Uhr"),
                               ZTL_LINKS + [OSM_LINKS["S"]],
                               [GEO_PENDING,
                                ("Whether the GZ/BZ ticket also opens this ZTL is not stated: GateLR treats it as closed.",
                                 "Non è indicato se il ticket GZ/BZ valga anche per questa ZTL: GateLR la considera chiusa.",
                                 "Ob das GZ/BZ-Ticket auch für diese ZTL gilt, ist nicht angegeben: GateLR behandelt sie als gesperrt.")],
                               "Ordinanza dirigenziale OD-2024-65 del 18/06/2024, tabella 2.5", ZTL_ORD)})

RING = ring_area()
PAIR_RING = osm_geo.perimeter(RING, tol_m=25)
PAIR_PENDING = [
    ("On emergency days (Arpae bulletin on Monday, Wednesday and Friday, valid from the next day) the ban runs 8 am–7 pm and also covers diesel Euro 5: GateLR doesn't know when they are on, check Arpae's bulletin.",
     "Nei giorni di misure emergenziali (bollettino Arpae di lunedì, mercoledì e venerdì, valido dal giorno dopo) il divieto vale 8–19 e anche per i diesel Euro 5: GateLR non sa quando sono attive, guarda il bollettino Arpae.",
     "An Tagen mit Notfallmaßnahmen (Arpae-Bulletin montags, mittwochs und freitags, gültig ab dem Folgetag) gilt das Verbot 8–19 Uhr und auch für Diesel Euro 5: GateLR weiß nicht, wann sie gelten, siehe Arpae-Bulletin."),
    ("Some access roads to the park-and-ride car parks, hospitals and station stay open (list in the ordinance); the Area delle Scienze campus south of the ring road is also included. GateLR shows only the area inside the ring roads, outline from OpenStreetMap.",
     "Alcune vie d'accesso a parcheggi scambiatori, ospedali e stazione restano percorribili (elenco nell'ordinanza); è compreso anche il Campus dell'Area delle Scienze a sud della tangenziale. GateLR mostra solo l'area interna alle tangenziali, contorno da OpenStreetMap.",
     "Einige Zufahrten zu Park-and-Ride-Plätzen, Krankenhäusern und Bahnhof bleiben offen (Liste in der Verordnung); auch der Campus Area delle Scienze südlich der Ringstraße gehört dazu. GateLR zeigt nur das Gebiet innerhalb der Ringstraßen, Umriss aus OpenStreetMap."),
    ("Hotel guests inside the area may drive to and from the hotel with the booking (or send the hotel's stamped statement to the local police within 10 days); cars with at least three people aboard are also exempt. GateLR doesn't check this.",
     "Gli ospiti degli hotel nell'area possono arrivare e partire dall'hotel con la prenotazione (o inviando alla Polizia Locale entro 10 giorni l'attestazione vistata dall'hotel); esenti anche le auto con almeno tre persone a bordo. GateLR non lo verifica.",
     "Hotelgäste im Gebiet dürfen mit der Buchung zum Hotel und zurück fahren (oder binnen 10 Tagen die abgestempelte Bestätigung des Hotels an die Stadtpolizei schicken); ausgenommen sind auch Autos mit mindestens drei Personen. GateLR prüft das nicht."),
    ("Dates valid for the 2026/2027 season only. No ban on days of local public transport strikes.",
     "Date valide solo per la stagione 2026/2027. Nessun divieto nei giorni di sciopero del trasporto pubblico locale.",
     "Daten nur für die Saison 2026/2027. Kein Verbot an Streiktagen im öffentlichen Nahverkehr."),
]
WEEKDAY_SEASONS = [season(10, 1, 12, 7), season(12, 9, 12, 24), season(12, 26, 12, 31), season(1, 2, 1, 5), season(1, 7, 3, 31)]
SUMMARY_PAIR = ("From 1 October 2026 to 31 March 2027, Monday to Friday 8:30 am–6:30 pm, the oldest cars can't drive inside the ring roads: petrol, LPG and methane up to Euro 2, diesel up to Euro 4. Electric and hybrid cars are exempt. Not on 8 and 25 December, 1 and 6 January. On emergency days it runs 8 am–7 pm and includes diesel Euro 5. Fine €168–679.",
                "Dal 1° ottobre 2026 al 31 marzo 2027, dal lunedì al venerdì 8:30–18:30, le auto più vecchie non possono circolare dentro le tangenziali: benzina, GPL e metano fino a Euro 2, diesel fino a Euro 4. Elettriche e ibride sono esenti. Non l'8 e il 25 dicembre, l'1 e il 6 gennaio. Nei giorni di misure emergenziali vale 8–19 e anche per i diesel Euro 5. Multa 168–679 €.",
                "Vom 1. Oktober 2026 bis 31. März 2027, montags bis freitags 8:30–18:30 Uhr, dürfen die ältesten Autos innerhalb der Ringstraßen nicht fahren: Benzin, Autogas und Erdgas bis Euro 2, Diesel bis Euro 4. Elektro- und Hybridautos sind ausgenommen. Nicht am 8. und 25. Dezember, 1. und 6. Januar. An Notfalltagen gilt es 8–19 Uhr und auch für Diesel Euro 5. Bußgeld 168–679 €.")
SUMMARY_SUN = ("Every Sunday from 4 October 2026 to 28 March 2027 (except 1 November), 8:30 am–6:30 pm, inside the ring roads: no petrol, LPG or methane cars up to Euro 2 and no diesel up to Euro 5. Electric and hybrid cars are exempt. Fine €168–679.",
               "Ogni domenica dal 4 ottobre 2026 al 28 marzo 2027 (tranne il 1° novembre), 8:30–18:30, dentro le tangenziali: vietate le auto a benzina, GPL e metano fino a Euro 2 e i diesel fino a Euro 5. Elettriche e ibride sono esenti. Multa 168–679 €.",
               "Jeden Sonntag vom 4. Oktober 2026 bis 28. März 2027 (außer 1. November), 8:30–18:30 Uhr, innerhalb der Ringstraßen: keine Benzin-, Autogas- und Erdgasautos bis Euro 2 und keine Diesel bis Euro 5. Elektro- und Hybridautos sind ausgenommen. Bußgeld 168–679 €.")
zones.append({"id": "parma-pair", "name": "Smog limits · Inside the ring roads", "name_it": "Limitazioni antismog · Dentro le tangenziali",
              "name_de": "Smog-Fahrverbot · Innerhalb der Ringstraßen", "kind": "green",
              "summary": SUMMARY_PAIR[0], "summary_it": SUMMARY_PAIR[1], "summary_de": SUMMARY_PAIR[2],
              "perimeter": PAIR_RING, "gates": [],
              "windows": [window(MON_FRI, 8 * 60 + 30, 18 * 60 + 30, s) for s in WEEKDAY_SEASONS],
              "freeOnHolidays": False, "exemptFuels": ["electric", "hybrid"], "hotelCanRegister": False,
              "bans": [{"fuel": "petrol", "maxEuro": 2, "since": "2026-10-01"}, {"fuel": "lpg", "maxEuro": 2, "since": "2026-10-01"},
                       {"fuel": "diesel", "maxEuro": 4, "since": "2026-10-01"}],
              "source": source(PAIR_PAGE, QUOTE_PAIR,
                               ("From 01/10/2026 to 31/03/2027, Monday to Friday, from 8:30 to 18:30, except on the holidays of 08/12/2026, 25/12/2026, 01/01/2027, 06/01/2027",
                                "Vom 01.10.2026 bis 31.03.2027, Montag bis Freitag, von 8:30 bis 18:30 Uhr, außer an den Feiertagen 08.12.2026, 25.12.2026, 01.01.2027, 06.01.2027"),
                               PAIR_LINKS, PAIR_PENDING, "Ordinanza sindacale OS-2026-102 del 28/09/2026 (PAIR 2030)", PAIR_ORD)})
zones.append({"id": "parma-domeniche-ecologiche", "name": "Eco Sundays · Inside the ring roads", "name_it": "Domeniche ecologiche · Dentro le tangenziali",
              "name_de": "Öko-Sonntage · Innerhalb der Ringstraßen", "kind": "green",
              "summary": SUMMARY_SUN[0], "summary_it": SUMMARY_SUN[1], "summary_de": SUMMARY_SUN[2],
              "perimeter": PAIR_RING, "gates": [],
              "windows": [window(SUN, 8 * 60 + 30, 18 * 60 + 30, s) for s in (season(10, 1, 10, 31), season(11, 2, 3, 31))],
              "freeOnHolidays": False, "exemptFuels": ["electric", "hybrid"], "hotelCanRegister": False,
              "bans": [{"fuel": "petrol", "maxEuro": 2, "since": "2026-10-01"}, {"fuel": "lpg", "maxEuro": 2, "since": "2026-10-01"},
                       {"fuel": "diesel", "maxEuro": 5, "since": "2026-10-01"}],
              "source": source(PAIR_PAGE, QUOTE_SUN,
                               ("On the eco Sundays, every Sunday from 01/10/2026 to 31/03/2027, from 8:30 to 18:30, except 01/11/2026",
                                "An den Öko-Sonntagen, jeden Sonntag vom 01.10.2026 bis 31.03.2027, von 8:30 bis 18:30 Uhr, außer am 01.11.2026"),
                               PAIR_LINKS, PAIR_PENDING[1:], "Ordinanza sindacale OS-2026-102 del 28/09/2026 (PAIR 2030)", PAIR_ORD)})

# --- Controlli: un luogo famoso dentro, la stazione fuori ---
GARIBALDI, DUOMO, STATION = (44.8015, 10.3280), (44.8030, 10.3306), (44.8096, 10.3283)
Z = {z["id"]: z for z in zones}
inside = lambda zid, p: osm_geo.contains(Z[zid]["perimeter"], *p)
assert inside("parma-ztl-1", GARIBALDI) and inside("parma-ztl-1", DUOMO), "Piazza Garibaldi e Duomo devono stare nella ZTL 1"
assert inside("parma-isola-1", DUOMO), "Il Duomo deve stare nell'Isola Ambientale"
assert inside("parma-ztl-2", (44.7995, 10.3290)), "Strada Farini deve stare nella ZTL 2"
assert inside("parma-ztl-3", (44.8025, 10.3227)), "Piazzale Corridoni deve stare nella ZTL 3"
assert inside("parma-isola-3i", (44.8029, 10.31877)), "Strada Inzani deve stare nella sua Isola Ambientale"
assert inside("parma-isola-2", (44.8002, 10.3290)), "Via Nazario Sauro deve stare nell'Isola Ambientale 2"
assert inside("parma-isola-3", (44.8026, 10.3212)), "Piazza delle Barricate deve stare nell'Isola Ambientale 3"
for zid in Z:
    if zid not in ("parma-pair", "parma-domeniche-ecologiche"):
        assert not inside(zid, STATION), f"La stazione non deve stare in {zid}"
assert inside("parma-pair", STATION) and inside("parma-pair", DUOMO), "Stazione e Duomo sono dentro le tangenziali"
assert not inside("parma-pair", (44.7700, 10.3150)), "Il Campus (fuori dall'anello) non è nel contorno"

city = {"id": "parma", "name": "Parma", "name_it": "Parma", "name_de": "Parma",
        "center": {"lat": 44.8015, "lon": 10.3280}, "zones": zones, "status": "draft",
        "license": "Rules: Comune di Parma and Infomobility S.p.A. official pages and documents. ZTL perimeters, streets, cameras and ring roads: "
                   + osm_geo.ODBL + " (approximate, not official)."}

ready = all(len(z["perimeter"]) >= 4 for z in city["zones"])
out = ROOT / ("Resources/Cities/parma.json" if ready else "data/drafts/parma.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/parma.json" if ready else "Resources/Cities/parma.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.name, [(z["id"], len(z["perimeter"]), len(z["gates"]), round(osm_geo.area_km2(z["perimeter"]), 3)) for z in city["zones"]])
