#!/usr/bin/env python3
# Costruisce la scheda di Lecce (bozza) da quanto salvato in data/raw/lecce/ e data/raw/geo/lecce-ztl.json
# (fonti e date in docs/fonti-lecce.md).
#
# Il 26/10/2026 dal sandbox i siti del Comune di Lecce (www.comune.lecce.it, comune.lecce.it, dati.comune.lecce.it) e
# quasi tutta la stampa locale non erano raggiungibili (il proxy rifiuta la connessione, 403; WebFetch non risolve gli host).
# Il workflow «Scarica pagine» non è stato usato per aggirare il blocco. Le regole vengono quindi dai riassunti della
# ricerca web (data/raw/lecce/websearch-*.txt), che citano le pagine ufficiali ma NON sono testo letterale:
#   - nessuna citazione («quote»: null) finché non si salva il testo ufficiale;
#   - la scheda resta in data/drafts/lecce.json.
# Regole: delibera GC n. 280 del 10/07/2025, ordinanze dirigenziali n. 1679 (16/07/2025) e n. 1689 (17/07/2025), in
# vigore dal 01/08/2025 (varchi spenti nei feriali 10–13 e 16:30–20; domenica e festivi attivi tutto il giorno; Porta
# Napoli h24); ordinanza n. 2069 del 09/09/2025 (altri varchi h24); delibere di giunta dell'11/03/2026 e di luglio 2026
# (altri varchi h24, via Marco Aurelio fuori dalla ZTL), in attuazione.
#
# Geometria: OpenStreetMap (© OpenStreetMap contributors, ODbL 1.0), relazione 20670025 «ZTL Lecce»
# (boundary=limited_traffic_zone, source «Città di Lecce», orari conditional uguali a quelli del Comune), scaricata
# dall'API principale di OSM con Tools/fetch_osm_api.py (Overpass non rispondeva). Varchi: i 7 nodi «Varco ZTL»
# (man_made=surveillance) presenti in OSM, su 17 varchi indicati dalla stampa; nomi dalla strada OSM più vicina.
# Open data ufficiale (dataset «ZTL APU CENTRO STORICO LECCE», CC BY 4.0, dati.comune.lecce.it, scaricato il 26/10/2026 in
# data/raw/lecce/ztlapucomunedilecce-2014.geojson): risale al 2014 (strade ZTL «H24 domenica e festivi, 21–6 nei feriali»,
# perimetro poi ridefinito con la delibera del 03/04/2025), quindi NON si usa come perimetro; i suoi 8 punti «Varchi» danno
# le posizioni ufficiali dei varchi: 7 coincidono (≤ 9 m) con i nodi OSM «Varco ZTL», l'ottavo è in via Casale Fornello.
# Se arriva un perimetro ufficiale aggiornato, basta salvarlo come data/raw/lecce/ztl_perimetro.geojson.
# Uso: python3 Tools/build_lecce.py   (non tocca le altre città né manifest.json)
import json, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/lecce"
CHECKED = "2026-10-26T23:00:00Z"
OSM_ZTL = 20670025
MON_SAT, SUN = [2, 3, 4, 5, 6, 7], [1]

NEWS_2025 = "https://www.comune.lecce.it/news/dettaglio/2025/07/17/modifiche-ztl-nuove-ordinanze"
ORD_1689 = "https://comune.lecce.it/docs/default-source/altri-documenti/ztl_carico_scarico_ord_01689_17-07-2025.pdf?sfvrsn=cf14c427_6"
NEWS_2026 = "https://www.comune.lecce.it/news/dettaglio/2026/03/12/ztl-nuovi-provvedimenti-che-interessando-il-centro-storico"
PERMITS = "https://www.comune.lecce.it/aree-tematiche/imprese/servizi-comunali/permesso-di-transito-e-sosta-nelle-ztl-del-centro-storico"
RULES_PDF = ("https://www.comune.lecce.it/docs/default-source/regolamenti-comunali/polizia-locale/"
             "regolamento-per-l-accesso-e-la-circolazione-dei-veicoli-nelle-zone-a-traffico-limitato-e-nelle-aree-pedonali-del-comune-di-lecce.pdf?sfvrsn=3c272fa5_10")
OPEN_DATA = "https://www.dati.gov.it/view-dataset/dataset?id=ztl-apu-centro-storico-lecce"
NEWS_JUL_2026 = "https://www.corrieresalentino.it/2026/07/centro-storico-cambia-la-mappa-della-viabilita-sensi-di-marcia-invertiti-nuove-ztl-e-percorsi-ridisegnati/"


def flat(s):
    return re.sub(r"\s+", " ", s).strip()


TEXT = {p.stem: flat(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def check(file, *phrases):
    """Ogni fatto usato deve comparire, parola per parola, nel testo salvato (qui: riassunti della ricerca)"""
    for q in phrases:
        if flat(q) not in TEXT[file]:
            raise SystemExit(f"{file}: frase non trovata: {q!r}")


check("websearch-1-orari-2025",
      "The changes took effect on 1 August 2025, under Giunta resolution n. 280 of 10 July 2025 and dirigential ordinances n. 1679 and n. 1689",
      "the electronic gates in the historic centre are switched off on weekdays from 10:00 to 13:00 and from 16:30 to 20:00, and the area is closed on Sundays and holidays",
      "It also bars passage through the Porta Napoli gate at all hours, every day of the week.",
      "Weekdays allow 5:30–9:30 and 15:00–16:00. Sundays and holidays allow 6:00–9:30")
check("websearch-2-varchi-2026",
      "la delibera introduce l'accesso ZTL h24 in via Mario Bernardini",
      "Via Marco Aurelio: viene esclusa dalla zona a traffico limitato",
      "Il provvedimento è un atto di indirizzo",
      "l'ordinanza 2069 del 9 settembre 2025 aggiorna la lista dei varchi ed estende l'H24 a quelli di viale XXV Luglio/via Trinchese e via dei Mocenigo",
      "That made 17 electronic eyes in total.")
check("websearch-3-luglio-2026",
      "The gate at via Pietro Palumbo will be converted into a 24-hour ZTL",
      "keeps via delle Bombarde as a 24-hour ZTL",
      "feriali con varchi spenti 10:00-13:00 e 16:30-20:00, e attivi nelle restanti ore; domeniche e festivi attivi 24 ore su 24")
check("websearch-4-hotel-permessi",
      "The hotel, not the guest, requests the HTL pass, which covers only check-in and check-out with a 20-minute maximum stop for luggage.",
      "Preferibilmente prima dell'arrivo e comunque al massimo entro 48 ore dall'accesso in ZTL.",
      "If a guest enters without a prior registration, the Comune's form must be filed within 48 hours",
      "Un permesso occasionale costa 5 euro",
      "Auto elettriche e ibride: Non ho trovato nulla sulle regole di Lecce.",
      "tra 83 e 332 euro")

# Varchi OSM (man_made=surveillance, name «Varco ZTL») → strada OSM più vicina (calcolata sui dati del 26/10/2026)
GATES = {3248620173: "Varco · Viale Oronzo Quarta / Via Duca degli Abruzzi",
         3248620174: "Varco · Via Giuseppe Cino",
         3248620177: "Varco · Via Pietro Palumbo / Via Adua (Porta Rudiae)",
         3248620176: "Varco · Via Vito Fazzi / Viale XXV Luglio",
         3248620175: "Varco · Via dei Verardi",
         3248620179: "Varco · Piazza Vittorio Aymone / Via Adua (Porta Napoli)",
         3248620178: "Varco · Via Marco Aurelio / Vico dei Fieschi"}


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


def perimeter():
    f = RAW / "ztl_perimetro.geojson"
    if f.exists():   # perimetro ufficiale (open data del Comune), se salvato
        g = json.loads(f.read_text())
        g = g["features"][0]["geometry"] if "features" in g else g
        polys = [g["coordinates"]] if g["type"] == "Polygon" else g["coordinates"]
        return osm_geo.perimeter(max((p[0] for p in polys), key=osm_geo.area_km2), tol_m=4), False
    rel = osm_geo.relation(osm_geo.load("lecce-ztl"), OSM_ZTL)
    return osm_geo.perimeter(osm_geo.outer_ring(rel, roles=("outer", "")), tol_m=4), True


def gates():
    """Posizioni ufficiali (punti «Varchi» dell'open data del Comune); nome dalla strada del nodo OSM coincidente"""
    osm = {e["id"]: e for e in osm_geo.load("lecce-ztl") if e["type"] == "node" and e["id"] in GATES}
    off = json.loads((RAW / "ztlapucomunedilecce-2014.geojson").read_text())
    pts = [f["geometry"]["coordinates"] for f in off["features"] if f["geometry"]["type"] == "Point"]
    if len(pts) != 8:
        raise SystemExit(f"Attesi 8 varchi nell'open data, trovati {len(pts)}")
    out = []
    for i, (lon, lat) in enumerate(pts):
        near = min(osm.values(), key=lambda e: osm_geo.distance_m([(e["lon"], e["lat"]), (e["lon"], e["lat"])], lat, lon))
        if osm_geo.distance_m([(near["lon"], near["lat"]), (near["lon"], near["lat"])], lat, lon) < 15:
            name = GATES[near["id"]]
        else:
            name = "Varco · Via Casale Fornello / Viale De Pietro"
        out.append({"id": f"le-od{i + 1}", "name": name, "location": {"lat": round(lat, 6), "lon": round(lon, 6)}})
    if len({g["name"] for g in out}) != 8:
        raise SystemExit("Varchi ufficiali e nodi OSM non si abbinano uno a uno")
    return sorted(out, key=lambda g: g["name"])


shape, from_osm = perimeter()
# Controlli: Duomo, piazza Sant'Oronzo, basilica di Santa Croce e Teatro Romano dentro; stazione, Castello Carlo V e
# mercato di Porta Rudiae fuori (coordinate dagli stessi dati OSM)
for name, lat, lon, inside in [("Duomo di Lecce", 40.35175, 18.16933, True), ("Colonna di Sant'Oronzo", 40.35291, 18.17276, True),
                               ("Basilica di Santa Croce", 40.35467, 18.17324, True), ("Teatro Romano", 40.35134, 18.17053, True),
                               ("Stazione di Lecce", 40.34575, 18.16601, False), ("Castello Carlo V", 40.35245, 18.17446, False),
                               ("Mercato di Porta Rudiae", 40.35112, 18.16410, False)]:
    if osm_geo.contains(shape, lat, lon) != inside:
        raise SystemExit(f"Controllo perimetro fallito: {name} dovrebbe essere {'dentro' if inside else 'fuori'}")
area = osm_geo.area_km2(shape)
if not 0.4 < area < 1.1:
    raise SystemExit(f"Area della ZTL non plausibile: {area:.2f} km²")
gate_list = gates()
for g in gate_list:
    if osm_geo.distance_m(shape, g["location"]["lat"], g["location"]["lon"]) > 40:
        raise SystemExit(f"Varco lontano dal bordo: {g['name']}")

LINKS = [link("City of Lecce (17 Jul 2025): new ZTL hours from 1 August 2025", "Comune di Lecce (17/07/2025): modifiche ZTL, nuove ordinanze",
              "Stadt Lecce (17.07.2025): neue ZTL-Zeiten ab 1. August 2025", NEWS_2025),
         link("City of Lecce: ordinance 1689/2025 on deliveries (PDF)", "Comune di Lecce: ordinanza 1689/2025 sul carico e scarico (PDF)",
              "Stadt Lecce: Verordnung 1689/2025 zu Lieferungen (PDF)", ORD_1689),
         link("City of Lecce (12 Mar 2026): more 24-hour gates", "Comune di Lecce (12/03/2026): nuovi provvedimenti ZTL, varchi h24",
              "Stadt Lecce (12.03.2026): weitere 24-Stunden-Kameras", NEWS_2026),
         link("City of Lecce: ZTL permits", "Comune di Lecce: permesso di transito e sosta nelle ZTL", "Stadt Lecce: ZTL-Genehmigungen", PERMITS),
         link("City of Lecce: ZTL and pedestrian area regulation (PDF)", "Comune di Lecce: regolamento ZTL e aree pedonali (PDF)",
              "Stadt Lecce: Regelung für ZTL und Fußgängerzonen (PDF)", RULES_PDF),
         link("Official ZTL map, open data (dati.gov.it)", "Perimetro ufficiale ZTL e aree pedonali, open data (dati.gov.it)",
              "Offizielle ZTL-Karte, offene Daten (dati.gov.it)", OPEN_DATA),
         link("Corriere Salentino (Jul 2026): new traffic plan for the old town", "Corriere Salentino (07/2026): nuova viabilità nel centro storico",
              "Corriere Salentino (07.2026): neuer Verkehrsplan für die Altstadt", NEWS_JUL_2026)]
if from_osm:
    LINKS.append(link(f"OpenStreetMap: relation {OSM_ZTL} «ZTL Lecce» (ODbL)", f"OpenStreetMap: relazione {OSM_ZTL} «ZTL Lecce» (ODbL)",
                      f"OpenStreetMap: Relation {OSM_ZTL} «ZTL Lecce» (ODbL)", osm_geo.osm_url("relation", OSM_ZTL)))

PENDING = [
    ("Draft: the City's websites could not be read from here (connection refused). Every rule below comes from web-search summaries of the official pages and local press, not from their text: to be checked word for word.",
     "Bozza: i siti del Comune non erano leggibili da qui (connessione rifiutata). Ogni regola viene dai riassunti della ricerca web sulle pagine ufficiali e sulla stampa locale, non dal loro testo: da verificare parola per parola.",
     "Entwurf: Die Websites der Stadt waren von hier aus nicht lesbar (Verbindung abgelehnt). Alle Regeln stammen aus Zusammenfassungen der Websuche zu den offiziellen Seiten und der Lokalpresse, nicht aus deren Text: Wort für Wort zu prüfen."),
    ("Some entrances are closed 24 hours a day even when the others are off: Porta Napoli (since August 2025), via Trinchese and via dei Mocenigo on viale XXV Luglio (ordinance 2069/2025), via delle Bombarde. GateLR shows the hours of the whole zone: in the free hours, enter only through the other gates.",
     "Alcuni ingressi sono chiusi 24 ore su 24 anche quando gli altri sono spenti: Porta Napoli (da agosto 2025), via Trinchese e via dei Mocenigo su viale XXV Luglio (ordinanza 2069/2025), via delle Bombarde. GateLR mostra gli orari di tutta la zona: nelle ore libere entra solo dagli altri varchi.",
     "Einige Zufahrten sind rund um die Uhr gesperrt, auch wenn die anderen aus sind: Porta Napoli (seit August 2025), Via Trinchese und Via dei Mocenigo am Viale XXV Luglio (Verordnung 2069/2025), Via delle Bombarde. GateLR zeigt die Zeiten der ganzen Zone: in den freien Stunden nur über die anderen Zufahrten einfahren."),
    ("Coming changes, not yet in force when checked: the council decided on 11 March 2026 to make via Mario Bernardini, via Benedetto Cairoli (entry), the Porta Rudiae–via Adua exit and via Marino Brancaccio 24-hour gates and to take via Marco Aurelio out of the ZTL (its gate moves to vico Mondo Nuovo); in July 2026 also via Pietro Palumbo. They need a Polizia Locale ordinance first.",
     "Modifiche in arrivo, non ancora in vigore alla verifica: la giunta l'11/03/2026 ha deciso varchi h24 in via Mario Bernardini, via Benedetto Cairoli (in entrata), Porta Rudiae–via Adua in uscita e via Marino Brancaccio, e l'uscita di via Marco Aurelio dalla ZTL (varco spostato su vico Mondo Nuovo); a luglio 2026 anche via Pietro Palumbo h24. Serve prima un'ordinanza della Polizia Locale.",
     "Geplante Änderungen, bei der Prüfung noch nicht in Kraft: Der Stadtrat beschloss am 11.03.2026 24-Stunden-Kameras in Via Mario Bernardini, Via Benedetto Cairoli (Einfahrt), an der Ausfahrt Porta Rudiae–Via Adua und in Via Marino Brancaccio sowie die Herausnahme der Via Marco Aurelio aus der ZTL (Kamera zieht nach Vico Mondo Nuovo); im Juli 2026 auch Via Pietro Palumbo. Zuerst ist eine Verordnung der Polizia Locale nötig."),
    ("Map outline from OpenStreetMap (relation «ZTL Lecce», 2026): the City's open-data map dates from 2014, before the perimeter was redefined in April 2025. Camera positions: the 8 in the City's open data (2014), 7 of which match OpenStreetMap; the press counts about 17 cameras today.",
     "Perimetro da OpenStreetMap (relazione «ZTL Lecce», 2026): la mappa open data del Comune è del 2014, prima della ridefinizione del perimetro di aprile 2025. Varchi: gli 8 dell'open data del Comune (2014), 7 dei quali coincidono con OpenStreetMap; secondo la stampa oggi i varchi sono circa 17.",
     "Grenze aus OpenStreetMap (Relation «ZTL Lecce», 2026): Die offene Karte der Stadt stammt von 2014, vor der Neufestlegung der Grenze im April 2025. Kameras: die 8 aus den offenen Daten der Stadt (2014), davon 7 deckungsgleich mit OpenStreetMap; laut Presse gibt es heute etwa 17."),
    ("Hotels: the hotel or B&B inside the ZTL sends your plate (HTL permit, only to check in and out, 20 minutes' stop for luggage), best before arrival and at the latest 48 hours after you drive in. Confirmed only by web-search summaries (City permit page, Gazzetta del Mezzogiorno, autovia.it).",
     "Alberghi: l'hotel o il B&B dentro la ZTL comunica la targa (permesso HTL, solo per arrivo e partenza, sosta di 20 minuti per i bagagli), meglio prima dell'arrivo e al massimo entro 48 ore dall'ingresso. Confermato solo dai riassunti della ricerca (pagina permessi del Comune, Gazzetta del Mezzogiorno, autovia.it).",
     "Hotels: Das Hotel oder B&B in der ZTL meldet dein Kennzeichen (HTL-Genehmigung, nur für An- und Abreise, 20 Minuten Halt fürs Gepäck), am besten vor der Ankunft und spätestens 48 Stunden nach der Einfahrt. Nur von Zusammenfassungen der Websuche bestätigt (Genehmigungsseite der Stadt, Gazzetta del Mezzogiorno, autovia.it)."),
    ("No pass for tourists: an occasional permit (OCC, about 5 €) exists but must be requested from the ZTL permit office (viale Rossini 110, online with SPID or by PEC), with about 7 working days' processing. Electric and hybrid cars: no exemption found, so GateLR does not exempt them. Motorbikes: not covered by the sources.",
     "Nessun pass per turisti: esiste un permesso occasionale (OCC, circa 5 €) da chiedere all'Ufficio Permessi ZTL (viale Rossini 110, online con SPID o via PEC), con circa 7 giorni lavorativi. Auto elettriche e ibride: nessuna esenzione trovata, quindi GateLR non le esenta. Moto: le fonti non ne parlano.",
     "Kein Touristenpass: Eine Gelegenheitsgenehmigung (OCC, etwa 5 €) gibt es, sie muss beim ZTL-Genehmigungsbüro beantragt werden (Viale Rossini 110, online mit SPID oder per PEC), Bearbeitung etwa 7 Werktage. Elektro- und Hybridautos: keine Ausnahme gefunden, daher befreit GateLR sie nicht. Motorräder: in den Quellen nicht behandelt."),
    ("Fine: 83–332 € (article 7 of the Highway Code), confirmed only by an unofficial guide. Feast of Sant'Oronzo (24–26 August): whether 26 August counts as a holiday for the ZTL is not confirmed, so it is not treated as one.",
     "Multa: 83–332 € (art. 7 del Codice della Strada), confermato solo da una guida non ufficiale. Festa di Sant'Oronzo (24–26 agosto): non è confermato che il 26 agosto valga come festivo per la ZTL, quindi non è trattato come tale.",
     "Bußgeld: 83–332 € (Art. 7 der Straßenverkehrsordnung), nur von einem inoffiziellen Ratgeber bestätigt. Fest des hl. Oronzo (24.–26. August): Ob der 26. August für die ZTL als Feiertag gilt, ist nicht bestätigt, daher wird er nicht so behandelt."),
]

SUMMARY = ("The old town inside the walls is closed to cars without a permit on Monday–Saturday from 1 pm to 4:30 pm and from 8 pm to 10 am, and all day on Sundays and holidays; on Monday–Saturday 10 am–1 pm and 4:30–8 pm the cameras are off. "
           "Porta Napoli and a few other entrances are closed around the clock. Staying inside? The hotel or B&B registers your plate (best before arrival, at the latest 48 hours after). There is no tourist pass: park outside the walls and walk in.")
SUMMARY_IT = ("Il centro storico dentro le mura è chiuso alle auto senza permesso dal lunedì al sabato dalle 13 alle 16:30 e dalle 20 alle 10, e tutto il giorno la domenica e nei festivi; dal lunedì al sabato 10–13 e 16:30–20 i varchi sono spenti. "
              "Porta Napoli e pochi altri ingressi sono chiusi a tutte le ore. Dormi dentro? L'hotel o il B&B registra la targa (meglio prima dell'arrivo, al massimo entro 48 ore). Non c'è un pass per turisti: parcheggia fuori dalle mura e entra a piedi.")
SUMMARY_DE = ("Die Altstadt innerhalb der Mauern ist für Autos ohne Genehmigung Montag–Samstag von 13 bis 16:30 Uhr und von 20 bis 10 Uhr gesperrt, sonntags und an Feiertagen den ganzen Tag; Montag–Samstag 10–13 und 16:30–20 Uhr sind die Kameras aus. "
              "Porta Napoli und einige andere Zufahrten sind rund um die Uhr gesperrt. Du übernachtest innen? Hotel oder B&B melden dein Kennzeichen (am besten vor der Ankunft, spätestens 48 Stunden danach). Einen Touristenpass gibt es nicht: außerhalb der Mauern parken und zu Fuß hinein.")

zone = {"id": "lecce-centro-storico", "name": "Lecce old town · ZTL inside the walls", "name_it": "Lecce centro storico · ZTL dentro le mura",
        "name_de": "Lecce Altstadt · ZTL innerhalb der Mauern", "kind": "restricted",
        "summary": SUMMARY, "summary_it": SUMMARY_IT, "summary_de": SUMMARY_DE,
        "perimeter": shape, "gates": gate_list,
        "windows": [{"weekdays": MON_SAT, "start": 0, "end": 10 * 60},
                    {"weekdays": MON_SAT, "start": 13 * 60, "end": 16 * 60 + 30},
                    {"weekdays": MON_SAT, "start": 20 * 60, "end": 24 * 60},
                    {"weekdays": SUN, "start": 0, "end": 24 * 60}],
        "freeOnHolidays": False, "holidaysAsSunday": True, "exemptFuels": [], "hotelCanRegister": True,
        "source": {"authority": "City of Lecce", "pageURL": NEWS_2025,
                   "ordinance": "Delibera GC n. 280 del 10/07/2025; ordinanze dirigenziali n. 1679 del 16/07/2025, n. 1689 del 17/07/2025 e n. 2069 del 09/09/2025",
                   "ordinanceURL": ORD_1689, "quote": None, "quoteTranslation": None, "quoteTranslation_de": None,
                   "checkedOn": CHECKED, "reviewedByHuman": False,
                   "pending": [p[0] for p in PENDING], "pending_it": [p[1] for p in PENDING], "pending_de": [p[2] for p in PENDING],
                   "links": LINKS}}

city = {"id": "lecce", "name": "Lecce", "name_it": "Lecce", "name_de": "Lecce",
        "center": {"lat": 40.3524, "lon": 18.1705}, "zones": [zone], "status": "draft",
        "license": "Rules: Comune di Lecce official pages (read through web-search summaries). "
                   + ("Perimeter: " + osm_geo.ODBL + " (approximate, not official). Gates: Comune di Lecce open data (CC BY 4.0)." if from_osm else "Perimeter and gates: Comune di Lecce open data (CC BY 4.0).")}

# Pubblicabile solo con una citazione verificata sul testo ufficiale; altrimenti bozza
ready = all(len(z["perimeter"]) >= 5 and z["source"]["quote"] for z in city["zones"])
out = ROOT / ("Resources/Cities/lecce.json" if ready else "data/drafts/lecce.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/lecce.json" if ready else "Resources/Cities/lecce.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), [(z["id"], len(z["perimeter"]), len(z["gates"])) for z in city["zones"]], f"{area:.2f} km²")
