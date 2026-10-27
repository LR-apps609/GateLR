#!/usr/bin/env python3
# Costruisce la scheda di Como dalle pagine e dagli atti ufficiali salvati in data/raw/como/ (URL e data di lettura in testa
# a ogni file; fonti e date in docs/fonti-como.md).
#
# Regole (27/10/2026): ordinanza dirigenziale n. 11 del 13/01/2017 della Polizia Locale, testo coordinato con le ordinanze
# n. 248/2019 e n. 105/2023 (ZTL «Città Murata» 0–24 ogni giorno, APU «Alessandro Volta» 0–24, APU «Duomo» 10:30–14:30 e
# 15–6, clienti delle strutture ricettive in sanatoria tramite la struttura, moto verso i parcheggi a loro riservati),
# pagina del servizio «Accesso alla ZTL» (perimetro descritto, varchi in ingresso e in uscita), tabella «Permessi, orari,
# ingresso, tempi sosta e limitazioni», elenco ufficiale delle vie.
#
# Geometria (mai disegnata a mano): nessun perimetro in open data (dati.lombardia.it e dati.gov.it non hanno la ZTL di Como;
# la planimetria ufficiale è un PDF senza coordinate). Si usa la relazione OSM 21710224 (boundary=limited_traffic_zone,
# «Zona a Traffico Limitato»), che segue le mura e il confine del quartiere «Città murata», scaricata con l'API OSM il
# 27/10/2026 (data/raw/geo/como-centro.json, © OpenStreetMap contributors, ODbL 1.0). Controllo: ogni strada dell'elenco
# ufficiale ha almeno un tratto dentro il perimetro, l'area coperta dalle strade dell'elenco (osm_geo.street_area, vie intere:
# via Garibaldi e via Grassi proseguono oltre i varchi) cade per
# oltre il 92% dentro il perimetro, e il perimetro (che segue le mura) è meno di 1,4 volte quell'area.
# Varchi: il nodo OSM della via indicata dal Comune più vicino al bordo (entro 70 m).
# Uso: python3 Tools/build_como.py   (non tocca le altre città né manifest.json)
import json, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/como"
CHECKED = "2026-10-27T11:00:00Z"
EVERY_DAY = [1, 2, 3, 4, 5, 6, 7]
OSM_ZTL = 21710224


def flat(s):
    return re.sub(r"\s+", " ", s).strip()


TEXT = {p.stem: flat(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def url_of(file):
    return TEXT[file].split(" ", 2)[1]


def check(file, *phrases):
    """Ogni frase citata o riassunta deve comparire, parola per parola, nel testo salvato"""
    for q in phrases:
        if flat(q) not in TEXT[file]:
            raise SystemExit(f"{file}: frase non trovata, ricontrollare il testo: {q!r}")


SERV_F, ORD_F, TAB_F, VIE_F, BUS_F = ("comune-servizio-accesso-ztl", "ord-11-2017-testo-coordinato", "permessi-orari-sosta",
                                      "elenco-vie-ztl", "comune-bus-turistici-ztl")
SERVICE, ORDINANCE, TABLE, STREETS_URL, BUS = map(url_of, (SERV_F, ORD_F, TAB_F, VIE_F, BUS_F))
MAP_PDF = "https://www.comune.como.it/export/sites/comune-di-como/.galleries/PLocale-PrCivile/Allegato-planimetrico.pdf"

QUOTE = ("Nella zona a traffico limitato “Città Murata”, dalle ore 00:00 alle ore 24:00, di ogni giorno, è vietata la "
         "circolazione (transito e sosta) di tutti i veicoli a motore ad eccezione di quanto previsto al capo II della presente ordinanza.")
check(ORD_F, QUOTE,
      "Nell’area pedonale urbana “Alessandro Volta” è vietata la circolazione (transito e sosta) di tutti i veicoli a motore",
      "dalle ore 10:30 alle ore 14:30 e dalle 15:00 alle ore 06:00, di ogni giorno",
      "I clienti delle strutture ricettive ubicate all’interno della ZTL ottengono l’autorizzazione in sanatoria fornendo alla struttura la targa del veicolo impiegato.",
      "Essa consente un accesso nel giorno di “check-in” e un accesso nel giorno di “check-out” per un tempo massimo di minuti 45.",
      "Qualora le strutture alberghiere abbiano a disposizione posti privati l’accesso ai clienti, limitato ai posti disponibili, è concesso per tutto il periodo del soggiorno.",
      "I conducenti di motocicli e ciclomotori sono autorizzati, senza alcuna formalità, ad accedere alla ZTL per raggiungere i parcheggi pubblici a loro riservati",
      "I veicoli diretti al parcheggi \"Arena” potranno accedere compatibilmente con la disponibilità di posti all'interno della struttura indicata dal pannello posto all'ingresso della Z.T.L.",
      "comunicando la targa del veicolo da loro utilizzato entro e non oltre 48 ore dall’accesso",
      "almeno 2 giorno lavorativi prima", "Tale autorizzazione ha durata massima di 2 giorni continuativi.",
      "E’ in ogni caso vietato l'accesso a tutti i veicoli con peso a pieno carico superiore a 3,5 t o una lunghezza superiore a 7,00 m",
      "I veicoli immatricolati per trasporto cose a trazione elettrica non hanno limitazione orarie.",
      "Per le violazioni della presente ordinanza trovano applicazione le disposizioni di cui al vigente codice della strada.")
ENTRY = ["via Cinque Giornate", "via Diaz", "via Carducci", "via Indipendenza", "via Rodari", "via Grassi", "via Cairoli"]
EXIT = ["via dell’Annunciata", "via Indipendenza", "via Rodari", "via Cairoli", "via Garibaldi"]
check(SERV_F, "La Zona a Traffico Limitato (ZTL) comprende tutta la zona della “Città murata”",
      "In tutta quest’area della città vige, durante tutto l’anno, una limitazione del traffico cittadino",
      "Varchi in ingresso: " + " ".join(ENTRY) + " Varchi in uscita: " + " ".join(EXIT),
      "Le richieste di accesso possono essere presentate ESCLUSIVAMENTE online", "marca da bollo da 16€",
      "da un minimo di 5€ ad un massimo di 20€", "Pagina aggiornata il 27/10/2026")
check(TAB_F, "RESIDENTI SENZA POSTO", "ALTRO ( AUTORIZZAZIONI")
check(BUS_F, "solo per trasportare i clienti degli hotel ubicati in ZTL")


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


LINKS = [link("City of Como: access to the ZTL (area, gates, permits)", "Comune di Como: accesso alla ZTL (area, varchi, permessi)",
              "Stadt Como: Zufahrt zur ZTL (Gebiet, Kameras, Genehmigungen)", SERVICE),
         link("Ordinance 11/2017 (consolidated text): ZTL «Città Murata» and pedestrian areas", "Ordinanza 11/2017 (testo coordinato): ZTL «Città Murata» e aree pedonali",
              "Verordnung 11/2017 (konsolidierter Text): ZTL «Città Murata» und Fußgängerzonen", ORDINANCE),
         link("Official map of the ZTL and pedestrian areas (PDF)", "Planimetria ufficiale della ZTL e delle aree pedonali (PDF)",
              "Offizieller Plan der ZTL und der Fußgängerzonen (PDF)", MAP_PDF),
         link("Official list of ZTL streets (PDF)", "Elenco ufficiale delle vie in ZTL (PDF)", "Offizielle Liste der ZTL-Straßen (PDF)", STREETS_URL),
         link("Permit categories, hours and parking limits (PDF)", "Permessi, orari, tempi di sosta e limitazioni (PDF)",
              "Genehmigungsarten, Zeiten und Parkdauer (PDF)", TABLE),
         link("City of Como: tourist coaches to hotels in the ZTL", "Comune di Como: bus turistici per gli hotel in ZTL",
              "Stadt Como: Reisebusse zu Hotels in der ZTL", BUS)]

PENDING = [
    ("Hotel guests: give your plate to the hotel inside the ZTL; it reports it to the Local Police and you are cleared afterwards, but only for one trip on check-in day and one on check-out day, 45 minutes each (to load and unload). If the hotel has private parking, access is allowed for the whole stay, within its spaces. The deadline for the hotel's report is set by a City regulation we have not found: ask the hotel.",
     "Ospiti degli hotel: dai la targa alla struttura dentro la ZTL; la comunica alla Polizia Locale e il transito viene autorizzato in sanatoria, ma solo un accesso il giorno del check-in e uno il giorno del check-out, 45 minuti ciascuno (carico e scarico). Se la struttura ha posti privati, l'accesso vale per tutto il soggiorno, nei limiti dei posti. Il termine per la comunicazione è nel regolamento comunale, che non abbiamo trovato: chiedi all'hotel.",
     "Hotelgäste: Gib dem Hotel in der ZTL dein Kennzeichen; es meldet es der Ortspolizei und die Fahrt wird nachträglich genehmigt, aber nur eine Einfahrt am Anreisetag und eine am Abreisetag, je 45 Minuten (Be- und Entladen). Hat das Hotel eigene Stellplätze, gilt die Zufahrt für den ganzen Aufenthalt, im Rahmen der Plätze. Die Meldefrist steht in einer städtischen Regelung, die wir nicht gefunden haben: frag das Hotel."),
    ("No tourist ticket. A temporary permit for specific, documented needs must be requested online (SPID/CIE, 16 € stamp plus 5–20 € fees) at least 2 working days before and lasts at most 2 days.",
     "Nessun ticket per turisti. Il permesso per esigenze specifiche e documentate si chiede online (SPID/CIE, bollo 16 € più 5–20 € di spese) almeno 2 giorni lavorativi prima e dura al massimo 2 giorni.",
     "Kein Touristenticket. Eine befristete Genehmigung für konkrete, belegte Gründe wird online beantragt (SPID/CIE, 16 € Stempelmarke plus 5–20 € Gebühren), mindestens 2 Werktage vorher, und gilt höchstens 2 Tage."),
    ("Cars heading to the «Arena» car park (near Via Indipendenza) may enter when the panel at the ZTL entrance shows free spaces (ordinance 11/2017, art. 9). That the car park is still open is confirmed only by unofficial sites.",
     "Le auto dirette al parcheggio «Arena» (vicino a via Indipendenza) possono entrare se il pannello all'ingresso della ZTL indica posti liberi (ordinanza 11/2017, art. 9). Che il parcheggio sia ancora in funzione è confermato solo da siti non ufficiali.",
     "Autos zum Parkplatz «Arena» (bei der Via Indipendenza) dürfen einfahren, wenn die Anzeige an der ZTL-Einfahrt freie Plätze zeigt (Verordnung 11/2017, Art. 9). Dass der Parkplatz noch betrieben wird, bestätigen nur inoffizielle Seiten."),
    ("Motorcycles and mopeds may enter without formalities only to reach the public motorcycle parking inside the ZTL, by the shortest route. Electric and hybrid cars are not exempt. Vehicles over 3.5 t or 7 m need a separate authorisation.",
     "Moto e ciclomotori possono entrare senza formalità solo per raggiungere i parcheggi pubblici a loro riservati dentro la ZTL, per la via più breve. Auto elettriche e ibride non esenti. Veicoli oltre 3,5 t o 7 m serve un'autorizzazione a parte.",
     "Motorräder und Mopeds dürfen ohne Formalitäten nur zu den öffentlichen Motorradparkplätzen in der ZTL fahren, auf dem kürzesten Weg. Elektro- und Hybridautos sind nicht befreit. Fahrzeuge über 3,5 t oder 7 m brauchen eine eigene Genehmigung."),
    ("Pedestrian areas inside the ZTL: «Alessandro Volta» (Piazza Volta, Piazza Cavour, Piazza Grimoldi, Via Pretorio, Piazza Verdi and others) closed 0–24 even to disabled badge holders; «Duomo» (Piazza Duomo, Via Plinio, part of Via Vittorio Emanuele II) closed 10:30–14:30 and 15:00–6:00. Only some squares are drawn on the map.",
     "Aree pedonali dentro la ZTL: «Alessandro Volta» (piazza Volta, piazza Cavour, piazza Grimoldi, via Pretorio, piazza Verdi e altre) chiusa 0–24 anche ai titolari di contrassegno disabili; «Duomo» (piazza Duomo, via Plinio, parte di via Vittorio Emanuele II) chiusa 10:30–14:30 e 15:00–6:00. Sulla mappa sono disegnate solo alcune piazze.",
     "Fußgängerzonen in der ZTL: «Alessandro Volta» (Piazza Volta, Piazza Cavour, Piazza Grimoldi, Via Pretorio, Piazza Verdi u. a.) 0–24 gesperrt, auch für Behindertenausweise; «Duomo» (Piazza Duomo, Via Plinio, Teil der Via Vittorio Emanuele II) 10:30–14:30 und 15:00–6:00 gesperrt. Auf der Karte sind nur einige Plätze eingezeichnet."),
    ("Perimeter not official: drawn from an OpenStreetMap area (October 2026) along the city walls, checked against the City's street list; near Piazza Verdi and Piazza Volta the edge is approximate. Gates on the map are placed on the streets named by the City (entry: Cinque Giornate, Diaz, Carducci, Indipendenza, Rodari, Grassi, Cairoli; exit only: Annunciata, Garibaldi), not at surveyed camera positions.",
     "Perimetro non ufficiale: area OpenStreetMap (ottobre 2026) lungo le mura, controllata con l'elenco delle vie del Comune; vicino a piazza Verdi e piazza Volta il bordo è approssimato. I varchi sulla mappa sono posti sulle vie indicate dal Comune (ingresso: Cinque Giornate, Diaz, Carducci, Indipendenza, Rodari, Grassi, Cairoli; solo uscita: Annunciata, Garibaldi), non nelle posizioni rilevate delle telecamere.",
     "Grenze nicht offiziell: OpenStreetMap-Fläche (Oktober 2026) entlang der Stadtmauer, mit der Straßenliste der Stadt abgeglichen; bei Piazza Verdi und Piazza Volta ist der Rand ungefähr. Die Kameras auf der Karte liegen auf den von der Stadt genannten Straßen (Einfahrt: Cinque Giornate, Diaz, Carducci, Indipendenza, Rodari, Grassi, Cairoli; nur Ausfahrt: Annunciata, Garibaldi), nicht an vermessenen Kamerastandorten."),
    ("Fines follow the Highway Code (art. 7); the ordinance gives no amount. No changes for 2026–2027 found on the City's site.",
     "Le multe seguono il Codice della strada (art. 7); l'ordinanza non indica importi. Nessuna modifica 2026–2027 trovata sul sito del Comune.",
     "Bußgelder nach der Straßenverkehrsordnung (Art. 7); die Verordnung nennt keine Beträge. Keine Änderungen für 2026–2027 auf der Website der Stadt gefunden."),
]

GEO = osm_geo.load("como-centro")
WAYS = [e for e in GEO if e["type"] == "way" and "highway" in e.get("tags", {})]

# L'elenco ufficiale delle vie (data/raw/como/elenco-vie-ztl.txt) con i nomi OSM; mancano «via Ballerini» (non in OSM)
# e viale Battisti, di cui è in ZTL solo il viale alberato del mercato (non separabile in OSM).
OFFICIAL_STREETS = {
    "via Adamo del Pero": "Via Adamo del Pero", "via Albertolli": "Via Giocondo Albertolli", "via Balestra": "Via Serafino Balestra",
    "via Bernardino Luini": "Via Bernardino Luini", "via Bellini": "Via Vincenzo Bellini", "via Bianchi Giovini": "Via Bianchi Giovini",
    "piazza Boldoni": "Via Pietro Boldoni", "via Bonanomi": "Via Bonanomi", "via Cairoli": "Via Fratelli Cairoli",
    "via Caio Plinio Secondo": "Via Caio Plinio Secondo", "via Carcano": "Via Paolo Carcano", "via Carducci": "Via Giosuè Carducci",
    "piazza Cavour": "Piazza Cavour", "via Cesare Cantù": "Via Cesare Cantù", "via V Giornate": "Via Cinque Giornate",
    "via Collegio dei Dottori": "Via Collegio dei Dottori", "via dell’Annunciata": "Via dell'Annunciata", "via Diaz": "Via Armando Diaz",
    "piazza Duomo": "Piazza del Duomo", "via Florio da Bontà": "Via Florio da Bontà", "via Fontana": "Via Domenico Fontana",
    "via Garibaldi": "Via Giuseppe Garibaldi", "via Giovio": "Via Giovio", "via Gobetti": "Via Piero Gobetti",
    "via Grassi": "Via Giovan Battista Grassi", "via Grimoldi": "Via Guido Grimoldi", "piazza Grimoldi": "Piazza Guido Grimoldi",
    "via Indipendenza": "Via Indipendenza", "via Juvara": "Via Filippo Juvara", "via Lambertenghi": "Via Lambertenghi",
    "via Macchi": "Via Alessandro Macchi", "via Maestri Cumacini": "Via Maestri Comacini", "piazza Mazzini": "Piazza Giuseppe Mazzini",
    "piazza Medaglie d’Oro": "Piazza Medaglie d'Oro", "via Muralto": "Via Francesco Muralto", "via Natta": "Via Natta",
    "via Odescalchi": "Via Odescalchi", "via Olginati": "Via Olginati", "via Pantero Pantera": "Via Pantero Pantera",
    "via Parini": "Via Giuseppe Parini", "piazza Perretta": "Piazza Pietro Amato Perretta", "via Perti": "Via Tomaso Perti",
    "piazza Pinchetti": "Piazzetta Pietro Pinchetti", "via Porta": "Via Porta", "via Pretorio": "Via Pretorio",
    "via Primo Tatti": "Via Primo Tatti", "via Raimondi": "Via Raimondi", "via Rodari": "Via Rodari", "piazza Roma": "Piazza Roma",
    "via Rovelli": "Via Giuseppe Rovelli", "via Rubini": "Via Giulio Rubini", "via Rusconi": "Via Rusconi",
    "piazza San Fedele": "Piazza San Fedele", "via Tridi": "Via Tridi", "piazza Verdi": "Piazza Giuseppe Verdi", "via Vitani": "Via Vitani",
    "via Vittorio Emanuele": "Via Vittorio Emanuele Secondo", "via Volpi": "Via Volpi", "piazza Volta": "Piazza Alessandro Volta",
    "via Volta": "Via Alessandro Volta"}
check(VIE_F, *OFFICIAL_STREETS, "via Ballerini", "viale Battisti (Viale alberato)")


def perimeter():
    rel = osm_geo.relation(GEO, OSM_ZTL)
    if rel["tags"].get("boundary") != "limited_traffic_zone":
        raise SystemExit("La relazione OSM della ZTL è cambiata: ricontrollare")
    ring = osm_geo.outer_ring(rel, roles=("outer", ""))
    official = [w for w in WAYS if w["tags"].get("name") in OFFICIAL_STREETS.values()]
    for osm_name in OFFICIAL_STREETS.values():
        ws = [w for w in official if w["tags"]["name"] == osm_name]
        assert ws, f"via ufficiale {osm_name} non trovata in OSM"
        if not any(osm_geo.inside_lonlat(ring, p["lon"], p["lat"]) or osm_geo.distance_m(ring, p["lat"], p["lon"]) < 15
                   for w in ws for p in w["geometry"]):
            raise SystemExit(f"via ufficiale {osm_name} fuori dal perimetro OSM")
    area = osm_geo.street_area({"id": 0, "members": [{"type": "way", "role": "section", "geometry": w["geometry"]} for w in official]}, close_m=60)
    # sovrapposizione stimata su una griglia di punti
    lons, lats = [p[0] for p in ring], [p[1] for p in ring]
    grid = [(x, y) for i in range(80) for j in range(80)
            for x, y in [(min(lons) + (max(lons) - min(lons)) * i / 79, min(lats) + (max(lats) - min(lats)) * j / 79)]]
    a = {g for g in grid if osm_geo.inside_lonlat(ring, *g)}
    b = {g for g in grid if osm_geo.inside_lonlat(area, *g)}
    inside, ratio = len(a & b) / len(b), len(a) / len(b)
    assert inside > 0.92 and ratio < 1.4, f"perimetro OSM e area delle vie ufficiali troppo diversi ({inside:.2f}, {ratio:.2f})"
    return osm_geo.perimeter(ring, tol_m=4), (inside, ratio)


def gate(street_official, osm_name, shape, direction):
    best = min((osm_geo.distance_m(shape, p["lat"], p["lon"]), p["lat"], p["lon"])
               for w in WAYS if w["tags"].get("name") == osm_name for p in w["geometry"])
    if best[0] > 70:
        raise SystemExit(f"varco {street_official}: nessun nodo OSM entro 70 m dal bordo")
    label = "Varco · " + street_official[0].upper() + street_official[1:] + (" (exit)" if direction == "exit" else "")
    slug = re.sub(r"[^a-z]+", "-", street_official.lower().replace("’", "")).strip("-")
    return {"id": f"co-{slug}{'-exit' if direction == 'exit' else ''}", "name": label,
            "location": {"lat": round(best[1], 6), "lon": round(best[2], 6)}}


shape, IOU = perimeter()
GATE_OSM = {"via Cinque Giornate": "Via Cinque Giornate", "via Diaz": "Via Armando Diaz", "via Carducci": "Via Giosuè Carducci",
            "via Indipendenza": "Via Indipendenza", "via Rodari": "Via Rodari", "via Grassi": "Via Giovan Battista Grassi",
            "via Cairoli": "Via Fratelli Cairoli", "via dell’Annunciata": "Via dell'Annunciata", "via Garibaldi": "Via Giuseppe Garibaldi"}
gates = [gate(s, GATE_OSM[s], shape, "entry") for s in ENTRY] + [gate(s, GATE_OSM[s], shape, "exit") for s in EXIT if s not in ENTRY]

# Aree pedonali disegnate: le piazze OSM delle APU dell'ordinanza (contorni OSM)
PED = {("way", 547472905): "APU Alessandro Volta · Piazza Volta", ("relation", 7819572): "APU Alessandro Volta · Piazza Cavour",
       ("way", 429693158): "APU Alessandro Volta · Piazza Grimoldi", ("relation", 10961938): "APU Duomo · Piazza Duomo (10:30–14:30, 15–6)"}
pedestrian = []
for (kind, oid), name in PED.items():
    el = next(e for e in GEO if e["type"] == kind and e["id"] == oid)
    ring = osm_geo.outer_ring(el, roles=("outer", "")) if kind == "relation" else [(p["lon"], p["lat"]) for p in el["geometry"]]
    pedestrian.append({"id": f"co-apu-{oid}", "name": name, "perimeter": osm_geo.perimeter(ring, tol_m=1)})

zone = {"id": "como-ztl", "name": "Città Murata · Walled town ZTL", "name_it": "Città Murata · ZTL centro storico",
        "name_de": "Città Murata · ZTL Altstadt", "kind": "restricted",
        "summary": "The whole walled town (Duomo, Piazza Cavour, Piazza Volta, San Fedele) plus Piazza Roma and Via Garibaldi is closed to cars 24 hours a day, every day, with cameras at the gates. There is no ticket for visitors. If your hotel is inside, give it your plate: it allows one trip in on arrival day and one on departure day (45 minutes each).",
        "summary_it": "Tutta la città murata (Duomo, piazza Cavour, piazza Volta, San Fedele) più piazza Roma e via Garibaldi è chiusa alle auto 24 ore su 24, tutti i giorni, con telecamere ai varchi. Non c'è un ticket per i visitatori. Se l'hotel è dentro, dagli la targa: vale un ingresso il giorno di arrivo e uno il giorno di partenza (45 minuti ciascuno).",
        "summary_de": "Die ganze ummauerte Altstadt (Dom, Piazza Cavour, Piazza Volta, San Fedele) plus Piazza Roma und Via Garibaldi ist rund um die Uhr, jeden Tag für Autos gesperrt, mit Kameras an den Einfahrten. Ein Ticket für Besucher gibt es nicht. Liegt dein Hotel innen, gib ihm dein Kennzeichen: erlaubt ist eine Einfahrt am Anreise- und eine am Abreisetag (je 45 Minuten).",
        "perimeter": shape, "gates": gates,
        "windows": [{"weekdays": EVERY_DAY, "start": 0, "end": 24 * 60}],
        "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": True,
        "source": {"authority": "City of Como", "pageURL": SERVICE,
                   "ordinance": "Ordinanza dirigenziale n. 11 del 13/01/2017 (testo coordinato con le ordinanze n. 248/2019 e n. 105/2023)",
                   "ordinanceURL": ORDINANCE,
                   "quote": QUOTE,
                   "quoteTranslation": "In the limited traffic zone «Città Murata», from 00:00 to 24:00 every day, traffic (driving and parking) of all motor vehicles is prohibited, except as provided in chapter II of this ordinance.",
                   "quoteTranslation_de": "In der verkehrsberuhigten Zone «Città Murata» ist von 00:00 bis 24:00 Uhr an jedem Tag der Verkehr (Fahren und Parken) aller Kraftfahrzeuge verboten, außer in den in Kapitel II dieser Verordnung vorgesehenen Fällen.",
                   "checkedOn": CHECKED, "reviewedByHuman": False,
                   "pending": [p[0] for p in PENDING], "pending_it": [p[1] for p in PENDING], "pending_de": [p[2] for p in PENDING],
                   "links": LINKS}}

city = {"id": "como", "name": "Como", "name_it": "Como", "name_de": "Como",
        "center": {"lat": 45.8114, "lon": 9.0832}, "zones": [zone], "pedestrian": pedestrian, "status": "draft",
        "license": "Rules: Comune di Como official pages and ordinance 11/2017. Perimeter, gates and pedestrian squares: " + osm_geo.ODBL + " (approximate, not official)."}

# Controlli di plausibilità: Duomo, San Fedele, piazza Cavour e parcheggio Arena dentro; stazione San Giovanni, Tempio Voltiano e Novosilo fuori
# (coordinate dai contorni OSM degli stessi luoghi)
for n, lat, lon in [("Duomo di Como", 45.81179, 9.08371), ("Basilica di San Fedele", 45.8097, 9.08462),
                    ("Piazza Cavour", 45.81302, 9.08087), ("Parcheggio Arena", 45.81086, 9.08538)]:
    assert osm_geo.contains(shape, lat, lon), f"{n} fuori dal perimetro"
for n, lat, lon in [("Stazione Como San Giovanni", 45.80882, 9.07265), ("Tempio Voltiano", 45.81478, 9.07527),
                    ("Novosilo via Sirtori", 45.80643, 9.08896)]:
    assert not osm_geo.contains(shape, lat, lon), f"{n} dentro il perimetro"
for g in gates:
    assert osm_geo.distance_m(shape, g["location"]["lat"], g["location"]["lon"]) < 70, g
assert 0.3 < osm_geo.area_km2(shape) < 0.6, osm_geo.area_km2(shape)

ready = all(len(z["perimeter"]) >= 5 and z["source"]["quote"] for z in city["zones"])
out = ROOT / ("Resources/Cities/como.json" if ready else "data/drafts/como.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/como.json" if ready else "Resources/Cities/como.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), [(z["id"], len(z["perimeter"]), len(z["gates"])) for z in city["zones"]],
      f"area {osm_geo.area_km2(shape):.2f} km², vie ufficiali dentro {IOU[0]:.2f}, rapporto {IOU[1]:.2f}")
