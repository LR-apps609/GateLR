#!/usr/bin/env python3
# Costruisce la scheda di Lucca dalle fonti ufficiali del Comune di Lucca salvate in data/raw/lucca/
# (fonti e date in docs/fonti-lucca.md). Lo script ricontrolla ogni frase usata sui file salvati.
#
# Dentro le Mura ci sono tre zone (Disciplinare permessi, dicembre 2024, § 1.4):
# - ZTL A (zona pedonale e Mura): accesso e sosta «sempre vietati» senza permesso;
# - ZTL B: accesso solo con permesso (nessuna fascia oraria indicata);
# - ZTL C: nessun controllo degli accessi (solo limiti di massa, ingombro e velocità, sosta blu a pagamento).
# Escono le zone A e B; la C non è una zona dell'app (si entra con qualsiasi auto): resta nelle note.
#
# Geometria: il Comune non pubblica coordinate (la mappa «ZTL aggiornamento dicembre 2025» è un PDF AutoCAD
# senza georeferenziazione). Se un giorno c'è un perimetro verificato, si salva come
# data/raw/lucca/ztl_perimetri.geojson (un Polygon per zona, proprietà "gatelr_id" = id della zona qui sotto).
# Finché non c'è, i perimetri vengono da OpenStreetMap (data/raw/geo/lucca-ztl.json, © OpenStreetMap
# contributors, ODbL 1.0): relazioni «ZTL A», «ZTL B» (boundary=limited_traffic_zone), tracciate sul
# disciplinare del 16/04/2024. La ZTL A in OSM ha un buco (dove stanno B, C e le aree fuori ZTL): l'app usa
# un solo anello per zona, quindi il buco è unito al contorno con un taglio di larghezza zero (vedi keyhole()).
#
# Bozza (data/drafts/lucca.json) finché PERIMETER_CURRENT e B_HOURS_OFFICIAL non sono veri:
# - la delibera GC 340/2025 ha spostato pezzi di ZTL C e A nella ZTL B con i nuovi varchi (gennaio 2026),
#   e i perimetri OSM sono ancora quelli del 2024;
# - per la ZTL B le regole non danno un orario esplicito (GateLR la considera sempre attiva, per prudenza).
# Non aggiorna manifest.json. Uso: python3 Tools/build_lucca.py
import json, math, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/lucca"
CHECKED = "2026-10-24T22:00:00Z"
EVERY_DAY = [1, 2, 3, 4, 5, 6, 7]
PERIMETER_CURRENT = False   # i perimetri OSM sono quelli del 2024, prima della delibera GC 340/2025
B_HOURS_OFFICIAL = False    # ZTL B: «l'accesso è consentito ai veicoli muniti di permesso», senza orario

DISCIPLINARE = "https://www.comune.lucca.it/app/uploads/2025/02/Disciplinare2024.pdf"
MAP_PAGE = "https://www.comune.lucca.it/documento_pubblico/planimetria-del-centro-storico-con-varchi-telematici-ztl-e-area-pedonale/"
MAP_PDF = "https://www.comune.lucca.it/app/uploads/2026/03/ZTL-aggiornamento-dicembre-2025.pdf"
DLG_340 = "https://www.comune.lucca.it/app/uploads/2026/01/dlg_00340_12-12-2025.pdf"
NEWS_GATES = "https://www.comune.lucca.it/notizia/ztl-da-oggi-19-gennaio-sono-attivi-i-nuovi-varchi-elettronici/"
NEWS_CONTROLS = "https://www.comune.lucca.it/notizia/ztl-controlli-piu-stringenti-con-nuove-telecamere-e-varchi-in-uscita/"
OSM_ZONES = {"lucca-a": 19549900,   # «ZTL A» (outer = dentro le Mura, inner = B, C e aree libere)
             "lucca-b": 19549370}   # «ZTL B»
OSM_C = 19549417                    # «ZTL C»: non è una zona dell'app, serve solo ai controlli


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


def flat(text):
    return re.sub(r"\s+", " ", text).strip()


def page_text(name):
    import html
    t = (RAW / name).read_text(encoding="utf-8")
    t = re.sub(r"<(script|style)[^>]*>.*?</\1>", " ", t, flags=re.S)
    return flat(html.unescape(re.sub(r"<[^>]+>", " ", t)))


def must_contain(text, quote, where):
    if flat(quote) not in text:
        raise SystemExit(f"Citazione non trovata in {where}: {quote!r}")


# --- Le frasi su cui si basa la scheda, controllate contro i file in data/raw/lucca/ ---
rules = flat((RAW / "Disciplinare2024.txt").read_text(encoding="utf-8"))
dlg = flat((RAW / "dlg-340-2025.txt").read_text(encoding="utf-8"))
gates_news = page_text("notizia-varchi-attivi.html")
controls_news = page_text("notizia-controlli.html")
QUOTE_A = "ZTL tipo “A” l’accesso e la sosta sono sempre vietati fatti salvi i veicoli autorizzati muniti di permesso."
QUOTE_B = "ZTL tipo “B” oltre alle limitazioni di massa, di dimensione e di velocità di cui al precedente punto a), l’accesso è consentito ai veicoli muniti di permesso e la sosta è consentita negli stalli gialli"
for q in [QUOTE_A, QUOTE_B, "Lucca, Dicembre 2024",
          "ZTL tipo “C” nella quale sono vigenti i limiti relativi alla massa a pieno carico",
          "L’accesso e l’uscita in/dalla ZTL è presidiato da telecamere.",
          "Tutti i veicoli dovranno uscire dalla ZTL B ed A entro 10 minuti dalla scadenza del periodo consentito",
          "nella fascia oraria 10.30 - 14.00 e 18.00 - 21.00 nei seguenti ambiti: via Fillungo",
          "piazza Anfiteatro, piazza San Frediano",
          "sono disciplinate dalle norme stabilite per la ZTL A",
          # Z4 Clienti delle strutture ricettive
          "localizzate nella ZTL B e nella ZTL A",
          "possono essere effettuate entro 5 giorni (120 ore)dall'effettivo passaggio del mezzo dal varco Ztl",
          "per un periodo massimo di 30 minuti con l’obbligo di esporre il disco orario",
          "Trascorso tale periodo il veicolo deve stazionare nelle aree al di fuori della ZTL A e B",
          "La tariffa è gratuita per tutti i tipi di veicoli e per tutta la durata del soggiorno",
          # Permessi giornalieri solo per categorie precise; tariffe anche per le auto elettriche
          "Z12 giornaliero 15 15 15 15 15 15"]:
    must_contain(rules, q, "Disciplinare dicembre 2024")
for q in ["le prescrizioni d'uso previste per la domenica si estendono automaticamente ai giorni festivi",
          "si modifica a “ entro 3 gg o 72 ore”", "decorrenti dal 01/01/2026",
          "passaggio da “ZTL C” a “ZTL B” del quadrilatero compreso tra Via Elisa/Via del Fosso/Via del Giardino Botanico/Via San Micheletto",
          "passaggio da “ZTL A” a “ZTL B” dell’area compresa tra Via del Crocifisso e Via San Paolino"]:
    must_contain(dlg, q, "delibera GC 340/2025")
for q in ["restano temporaneamente sospesi i varchi del quadrilatero Quarquonia–Bacchettoni–via Elisa–Santa Chiara",
          "Continuano come sempre ad essere raggiungibili tutti i parcheggi a stalli blu del centro storico, per consentire la sosta anche ai cittadini non residenti",
          "Varchi in uscita (OUT) Piazza della Caserma"]:
    must_contain(gates_news, q, "notizia del 19 gennaio 2026")
must_contain(controls_news, "Complessivamente sono 14 i nuovi varchi installati", "notizia dell'8 gennaio 2026")


# --- Geometria ---

def _ring(points):
    """Anello [lon, lat] senza il punto di chiusura ripetuto"""
    return points[:-1] if points[0] == points[-1] else list(points)


def _signed(ring):
    return sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(ring, ring[1:] + ring[:1])) / 2


def keyhole(outer, inner, tol_m=5.0):
    """Un anello solo per «outer meno inner»: il buco è unito al contorno con un taglio di larghezza zero
    tra i due punti più vicini. Il ray casting dell'app (pari/dispari) lo tratta come un poligono con il buco:
    il taglio viene attraversato due volte. Contorno antiorario, buco orario, così anche l'area esce giusta."""
    o = _ring(osm_geo.simplify_m(outer, tol_m))
    h = _ring(osm_geo.simplify_m(inner, tol_m))
    if _signed(o) < 0: o.reverse()
    if _signed(h) > 0: h.reverse()
    k = math.cos(math.radians(o[0][1]))
    d = lambda a, b: math.hypot((a[0] - b[0]) * k, a[1] - b[1])
    i, j = min(((i, j) for i in range(len(o)) for j in range(len(h))), key=lambda ij: d(o[ij[0]], h[ij[1]]))
    ring = o[:i + 1] + h[j:] + h[:j + 1] + o[i:] + [o[0]]
    return [{"lat": round(p[1], 6), "lon": round(p[0], 6)} for p in ring]


def official_perimeters():
    f = RAW / "ztl_perimetri.geojson"
    if not f.exists():
        return {}
    out = {}
    for feat in json.loads(f.read_text())["features"]:
        g = feat["geometry"]
        polys = [g["coordinates"]] if g["type"] == "Polygon" else g["coordinates"]
        poly = max(polys, key=lambda p: len(p[0]))
        out[feat["properties"]["gatelr_id"]] = (keyhole(poly[0], poly[1]) if len(poly) == 2 else
                                                [{"lat": round(y, 6), "lon": round(x, 6)} for x, y in poly[0]])
    return out


def osm_perimeters():
    el = osm_geo.load("lucca-ztl")
    a = osm_geo.relation(el, OSM_ZONES["lucca-a"])
    return {"lucca-a": keyhole(osm_geo.outer_ring(a), osm_geo.outer_ring(a, roles=("inner",))),
            "lucca-b": osm_geo.perimeter(osm_geo.outer_ring(osm_geo.relation(el, OSM_ZONES["lucca-b"])))}


official = official_perimeters()
perims = official or osm_perimeters()
from_osm = not official

# Controlli di plausibilità: Piazza dell'Anfiteatro nella ZTL A, la stazione fuori da tutto,
# nessun punto della ZTL C (che è libera) dentro A o B.
ANFITEATRO, STAZIONE = (43.8457, 10.5065), (43.8375, 10.5062)
assert osm_geo.contains(perims["lucca-a"], *ANFITEATRO), "Piazza dell'Anfiteatro deve stare nella ZTL A"
assert not osm_geo.contains(perims["lucca-b"], *ANFITEATRO)
assert not any(osm_geo.contains(p, *STAZIONE) for p in perims.values()), "La stazione deve stare fuori"
if from_osm:
    c_ring = osm_geo.outer_ring(osm_geo.relation(osm_geo.load("lucca-ztl"), OSM_C))
    b_ring = [(p["lon"], p["lat"]) for p in perims["lucca-b"]]
    lat0, lat1 = min(p[1] for p in c_ring), max(p[1] for p in c_ring)
    lon0, lon1 = min(p[0] for p in c_ring), max(p[0] for p in c_ring)
    grid = [(lat0 + (lat1 - lat0) * i / 40, lon0 + (lon1 - lon0) * j / 40) for i in range(41) for j in range(41)]
    in_c = [(la, lo) for la, lo in grid if osm_geo.contains(c_ring, la, lo) and not osm_geo.contains(b_ring, la, lo)]
    leaks = [p for p in in_c if osm_geo.contains(perims["lucca-a"], *p) and osm_geo.distance_m(perims["lucca-a"], *p) > 15]
    assert len(in_c) > 50 and len(leaks) <= len(in_c) // 50, f"La ZTL C finisce dentro la ZTL A: {len(leaks)} punti su {len(in_c)}"
    walls = [(n["lon"], n["lat"]) for e in osm_geo.load("lucca-walls") if e["type"] == "relation"
             for m in e.get("members", []) for n in (m.get("geometry") or [])]
    hull = osm_geo.convex_hull(walls)
    for zid, ring in perims.items():   # tutto dentro (o quasi) l'inviluppo delle Mura
        out = [p for p in ring if not osm_geo.inside_lonlat(hull, p["lon"], p["lat"])]
        assert len(out) <= len(ring) // 20, f"{zid}: {len(out)} punti fuori dalle Mura"

# --- Note «da verificare» (inglese, italiano, tedesco) ---
P_GEOMETRY = ("Map outline from OpenStreetMap, drawn on the 2024 rules and not official. With the new cameras (January 2026) the city moved some streets from sector C and A into sector B "
              "(east: between via Elisa, via del Fosso, via del Giardino Botanico and via San Micheletto; south: via Carrara to Porta San Pietro), and these changes are not on this map yet. Check the official map.",
              "Perimetro da OpenStreetMap, tracciato sulle regole del 2024 e non ufficiale. Con i nuovi varchi (gennaio 2026) il Comune ha spostato alcune strade dalla ZTL C e dalla ZTL A alla ZTL B "
              "(a est: tra via Elisa, via del Fosso, via del Giardino Botanico e via San Micheletto; a sud: via Carrara fino a Porta San Pietro), e queste modifiche non sono ancora sulla mappa. Guarda la mappa ufficiale.",
              "Grenze aus OpenStreetMap, nach den Regeln von 2024 gezeichnet und nicht amtlich. Mit den neuen Kameras (Januar 2026) hat die Stadt einige Straßen aus Sektor C und A in Sektor B verlegt "
              "(Osten: zwischen Via Elisa, Via del Fosso, Via del Giardino Botanico und Via San Micheletto; Süden: Via Carrara bis Porta San Pietro); diese Änderungen fehlen auf der Karte noch. Siehe offizielle Karte.")
P_EAST = ("In January 2026 the city said the ZTL in the east block between via Quarquonia, via dei Bacchettoni, via Elisa and via Santa Chiara was temporarily suspended for building works at Villa Bottini. Current status unknown.",
          "A gennaio 2026 il Comune ha comunicato che la ZTL nel quadrilatero Quarquonia–Bacchettoni–via Elisa–Santa Chiara era temporaneamente sospesa per il cantiere di Villa Bottini. Stato attuale non noto.",
          "Im Januar 2026 meldete die Stadt, dass die ZTL im östlichen Block zwischen Via Quarquonia, Via dei Bacchettoni, Via Elisa und Via Santa Chiara wegen der Bauarbeiten an der Villa Bottini vorübergehend ausgesetzt war. Aktueller Stand unbekannt.")
P_C = ("Sector C (a few areas inside the walls) has no entry control: any car under 3.5 t may drive in (30 km/h), with paid blue-line parking. It is not drawn as a zone.",
       "La ZTL C (alcune aree dentro le Mura) non ha controllo degli accessi: può entrare qualsiasi auto sotto le 3,5 tonnellate (30 km/h), con sosta a pagamento sulle strisce blu. Non è disegnata come zona.",
       "Sektor C (einige Bereiche innerhalb der Mauern) hat keine Zufahrtskontrolle: Jedes Auto unter 3,5 t darf hinein (30 km/h), Parken auf blauen Linien gegen Gebühr. Er ist nicht als Zone eingezeichnet.")
P_NO_TICKET = ("No day permit for visitors: daily permits exist only for specific categories such as trades, deliveries or people with a temporary disability (€15 a day), and are issued by Lucca Plus.",
               "Nessun permesso giornaliero per i turisti: i permessi giornalieri esistono solo per categorie precise come artigiani, merci o persone con disabilità temporanea (15 € al giorno), e li rilascia Lucca Plus.",
               "Keine Tagesgenehmigung für Besucher: Tagesgenehmigungen gibt es nur für bestimmte Gruppen wie Handwerker, Lieferungen oder Menschen mit vorübergehender Behinderung (15 € pro Tag), ausgestellt von Lucca Plus.")
P_HOTEL = ("Hotel deadline: the 2024 rules give 5 days (120 hours) after passing the camera; from 1 January 2026 the city cut this to 3 days (72 hours). The updated rules text was not found online.",
           "Scadenza per l'hotel: il disciplinare 2024 dà 5 giorni (120 ore) dal passaggio sotto il varco; dal 1° gennaio 2026 il Comune li ha ridotti a 3 giorni (72 ore). Il testo aggiornato del disciplinare non è stato trovato online.",
           "Frist für das Hotel: Die Regeln von 2024 nennen 5 Tage (120 Stunden) nach der Kamera; seit 1. Januar 2026 sind es laut Stadt 3 Tage (72 Stunden). Der aktualisierte Regeltext wurde online nicht gefunden.")
P_ELECTRIC = ("Electric cars: no free entry; the rules only list lower permit prices for them.",
              "Auto elettriche: nessun accesso libero; il disciplinare prevede per loro solo tariffe più basse dei permessi.",
              "Elektroautos: keine freie Einfahrt; die Regeln sehen für sie nur günstigere Genehmigungen vor.")
P_GATES = ("Cameras: the city lists the gate names (14 new ones active since 19 January 2026) but publishes no coordinates, and OpenStreetMap has none, so they are not on the map.",
           "Varchi: il Comune elenca i nomi (14 nuovi, attivi dal 19 gennaio 2026) ma non pubblica le coordinate, e OpenStreetMap non le ha, quindi non sono sulla mappa.",
           "Kameras: Die Stadt nennt die Namen (14 neue, aktiv seit 19. Januar 2026), veröffentlicht aber keine Koordinaten, und OpenStreetMap hat keine; daher fehlen sie auf der Karte.")
P_EXIT = ("Cameras also check exits: vehicles must leave sectors A and B within 10 minutes after their permitted time ends.",
          "I varchi controllano anche le uscite: si deve uscire dalle ZTL A e B entro 10 minuti dalla fine del periodo consentito.",
          "Die Kameras prüfen auch die Ausfahrt: Sektor A und B müssen spätestens 10 Minuten nach Ende der erlaubten Zeit verlassen werden.")
P_B_HOURS = ("Hours: the rules say entry to sector B is allowed only with a permit and give no time limit, so GateLR treats it as always active. To be confirmed with the city.",
             "Orari: il disciplinare dice che nella ZTL B si entra solo con il permesso e non indica fasce orarie, quindi GateLR la considera sempre attiva. Da confermare con il Comune.",
             "Zeiten: Laut den Regeln darf man in Sektor B nur mit Genehmigung und ohne Zeitangabe einfahren; GateLR behandelt ihn daher als immer aktiv. Mit der Stadt zu bestätigen.")
P_A_STREETS = ("Even with a permit (hotel guests included), via Fillungo, via Roma, piazza San Michele (east side), piazza Anfiteatro, piazza San Frediano and a few other streets are closed 10:30 am–2 pm and 6–9 pm.",
               "Anche con il permesso (ospiti degli hotel compresi), via Fillungo, via Roma, piazza San Michele (lato est), piazza Anfiteatro, piazza San Frediano e poche altre vie sono chiuse 10:30–14 e 18–21.",
               "Auch mit Genehmigung (Hotelgäste eingeschlossen) sind Via Fillungo, Via Roma, Piazza San Michele (Ostseite), Piazza Anfiteatro, Piazza San Frediano und einige weitere Straßen 10:30–14 und 18–21 Uhr gesperrt.")

links = [link("City of Lucca: map of the ZTL sectors and gates (page)", "Comune di Lucca: planimetria con ZTL, varchi e area pedonale",
              "Stadt Lucca: Karte der ZTL-Sektoren und Kameras", MAP_PAGE),
         link("City of Lucca: ZTL map, December 2025 update (PDF)", "Comune di Lucca: mappa ZTL aggiornamento dicembre 2025 (PDF)",
              "Stadt Lucca: ZTL-Karte, Stand Dezember 2025 (PDF)", MAP_PDF),
         link("City of Lucca: permit rules for the historic centre (Dec 2024, PDF)", "Comune di Lucca: disciplinare dei permessi del centro storico (dic. 2024, PDF)",
              "Stadt Lucca: Genehmigungsregeln für die Altstadt (Dez. 2024, PDF)", DISCIPLINARE),
         link("City of Lucca: Council decision 340/2025 (rule changes, new perimeter)", "Comune di Lucca: delibera GC 340/2025 (modifiche al disciplinare, nuovo perimetro)",
              "Stadt Lucca: Beschluss 340/2025 (Regeländerungen, neue Grenze)", DLG_340),
         link("City of Lucca: new ZTL cameras active from 19 January 2026", "Comune di Lucca: nuovi varchi ZTL attivi dal 19 gennaio 2026",
              "Stadt Lucca: neue ZTL-Kameras ab 19. Januar 2026", NEWS_GATES)]


def osm_link(rid):
    return link(f"OpenStreetMap: relation {rid} (perimeter, ODbL)", f"OpenStreetMap: relazione {rid} (perimetro, ODbL)",
                f"OpenStreetMap: Relation {rid} (Grenze, ODbL)", osm_geo.osm_url("relation", rid))


def source(zid, quote, translation, pending):
    pending = ([P_GEOMETRY, P_EAST] if from_osm else []) + pending
    return {"authority": "City of Lucca", "pageURL": MAP_PAGE,
            "ordinance": "Disciplinare permessi centro storico (dicembre 2024), modificato dalla delibera GC n. 340 del 12/12/2025",
            "ordinanceURL": DISCIPLINARE,
            "quote": quote, "quoteTranslation": translation[0], "quoteTranslation_de": translation[1],
            "checkedOn": CHECKED, "reviewedByHuman": False,
            "pending": [p[0] for p in pending], "pending_it": [p[1] for p in pending], "pending_de": [p[2] for p in pending],
            "links": links + ([osm_link(OSM_ZONES[zid])] if from_osm else [])}


HOTEL_EN = " If your hotel or B&B is inside sector A or B, it can register your plate for free: during your stay you may drive in by the shortest route and stop for check-in and luggage for up to 30 minutes with a parking disc; then park outside sectors A and B or in the hotel's own parking."
HOTEL_IT = " Se il tuo hotel o B&B è nella ZTL A o B, può registrare la tua targa gratis: per tutto il soggiorno puoi entrare per la via più breve e fermarti per registrazione e bagagli al massimo 30 minuti con il disco orario; poi devi parcheggiare fuori dalle ZTL A e B o nel parcheggio della struttura."
HOTEL_DE = " Liegt dein Hotel oder B&B in Sektor A oder B, kann es dein Kennzeichen kostenlos melden: Während des Aufenthalts darfst du auf dem kürzesten Weg hineinfahren und zum Einchecken und für das Gepäck höchstens 30 Minuten mit Parkscheibe halten; danach außerhalb von A und B oder auf dem Parkplatz der Unterkunft parken."
NO_TICKET_EN, NO_TICKET_IT, NO_TICKET_DE = (" There is no day permit for visitors, electric cars included.",
                                            " Non c'è un permesso giornaliero per i turisti, nemmeno per le auto elettriche.",
                                            " Es gibt keine Tagesgenehmigung für Besucher, auch nicht für Elektroautos.")

zones = [
    {"id": "lucca-a", "name": "Sector A · Pedestrian centre ZTL", "name_it": "Settore A · ZTL zona pedonale", "name_de": "Sektor A · ZTL Fußgängerzone",
     "kind": "restricted",
     "summary": "The pedestrian heart of the old town and the walls: closed to unauthorised vehicles at all times, every day, holidays included." + NO_TICKET_EN + HOTEL_EN,
     "summary_it": "Il cuore pedonale del centro storico e le Mura: chiusa ai veicoli non autorizzati sempre, tutti i giorni, festivi compresi." + NO_TICKET_IT + HOTEL_IT,
     "summary_de": "Das Fußgängerherz der Altstadt und die Stadtmauer: für nicht berechtigte Fahrzeuge immer gesperrt, täglich, auch an Feiertagen." + NO_TICKET_DE + HOTEL_DE,
     "source": source("lucca-a", QUOTE_A, ("Sector “A”: entry and parking are always forbidden, except for authorised vehicles with a permit.",
                                           "Sektor „A“: Einfahrt und Parken sind immer verboten, außer für berechtigte Fahrzeuge mit Genehmigung."),
                      [P_A_STREETS, P_NO_TICKET, P_HOTEL, P_ELECTRIC, P_C, P_GATES, P_EXIT])},
    {"id": "lucca-b", "name": "Sector B · Historic centre ZTL", "name_it": "Settore B · ZTL centro storico", "name_de": "Sektor B · ZTL Altstadt",
     "kind": "restricted",
     "summary": "The ring of the old town around sector A: you may enter only with a permit. The rules give no hours, so GateLR treats it as always active, holidays included. The blue-line car parks inside the walls stay reachable for visitors." + NO_TICKET_EN + HOTEL_EN,
     "summary_it": "L'anello del centro storico attorno alla ZTL A: si entra solo con il permesso. Il disciplinare non indica orari, quindi GateLR la considera sempre attiva, festivi compresi. I parcheggi a strisce blu dentro le Mura restano raggiungibili anche per chi non è residente." + NO_TICKET_IT + HOTEL_IT,
     "summary_de": "Der Ring der Altstadt um Sektor A: Einfahrt nur mit Genehmigung. Die Regeln nennen keine Zeiten, daher behandelt GateLR ihn als immer aktiv, auch an Feiertagen. Die Parkplätze mit blauen Linien innerhalb der Mauern bleiben für Besucher erreichbar." + NO_TICKET_DE + HOTEL_DE,
     "source": source("lucca-b", QUOTE_B, ("Sector “B”: besides the weight, size and speed limits of point a), entry is allowed to vehicles with a permit and parking is allowed in the yellow bays",
                                           "Sektor „B“: Neben den Gewichts-, Größen- und Tempolimits von Punkt a) ist die Einfahrt Fahrzeugen mit Genehmigung erlaubt, Parken auf den gelben Plätzen"),
                      ([] if B_HOURS_OFFICIAL else [P_B_HOURS]) + [P_NO_TICKET, P_HOTEL, P_ELECTRIC, P_C, P_GATES, P_EXIT])},
]
order = ["id", "name", "name_it", "name_de", "kind", "summary", "summary_it", "summary_de", "perimeter", "gates",
         "windows", "freeOnHolidays", "exemptFuels", "hotelCanRegister", "source"]
for z in zones:
    z.update({"perimeter": perims.get(z["id"], []), "gates": [],   # nessuna coordinata dei varchi né ufficiale né in OSM
              "windows": [{"weekdays": EVERY_DAY, "start": 0, "end": 24 * 60}],
              "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": True})
zones = [{k: z[k] for k in order} for z in zones]

# Centro della mappa: il centro del riquadro della ZTL A (dentro le Mura); serve solo a inquadrare
a = perims["lucca-a"]
center = {"lat": round((min(p["lat"] for p in a) + max(p["lat"] for p in a)) / 2, 4),
          "lon": round((min(p["lon"] for p in a) + max(p["lon"] for p in a)) / 2, 4)}
city = {"id": "lucca", "name": "Lucca", "name_it": "Lucca", "name_de": "Lucca", "center": center,
        "zones": zones, "status": "draft",
        "license": "Rules: Comune di Lucca official documents. "
                   + ("Perimeters: " + osm_geo.ODBL + " (approximate, not official, 2024 layout)." if from_osm else "Perimeters: Comune di Lucca.")}

# Senza perimetri aggiornati e orari ufficiali per ogni zona la città resta tra le bozze (data/drafts)
ready = (PERIMETER_CURRENT or not from_osm) and B_HOURS_OFFICIAL and all(len(z["perimeter"]) >= 4 for z in zones)
out = ROOT / ("Resources/Cities/lucca.json" if ready else "data/drafts/lucca.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/lucca.json" if ready else "Resources/Cities/lucca.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), [(z["id"], len(z["perimeter"]), round(osm_geo.area_km2(z["perimeter"]), 3)) for z in zones])
