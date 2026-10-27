#!/usr/bin/env python3
# Costruisce la scheda di Ostuni (fonti e date in docs/fonti-ostuni.md). Ogni frase citata o riassunta viene ricontrollata
# sul testo salvato in data/raw/ostuni/.
#
# FONTE NON UFFICIALE. Il sito del Comune ha solo la scheda del servizio «Richiedere permesso di accesso ad area ZTL»
# (nessun orario, nessuna mappa). Con l'approvazione del titolare, orari, varchi e regole vengono da
# accessibilitacentristorici.it (sito privato di servizi per i permessi), che ospita anche la copia del disciplinare ZTL del
# 2018 (D.G.C. n. 64 del 28/03/2018: art. 5 varchi e orari di apertura, art. 6 elettriche sempre ammesse, art. 21 alberghi).
# La copia non è sul sito del Comune: la zona resta source.official = false con source.unofficialSource (app 1.16.2;
# manifest «unofficialCities», nascosta alle app fino alla 1.16.1).
# Orari: «attiva tutti i giorni 24 ore su 24» con i varchi di via Cattedrale, via Francesco Cavallo e via Francesco Vitale
# aperti 7–10 e 14–17 (ZTL attiva 0–7, 10–14, 17–24); il varco di via Montegrappa è aperto 8–13 e 16–19 (nei pending e nel
# nome del varco). Incrocio: i tag OSM di via Cattedrale dicono «motor_vehicle:conditional = yes @ 07:00-10:00, 14:00-17:00».
#
# Geometria (© OpenStreetMap contributors, ODbL 1.0; API OSM con Tools/fetch_osm_api.py, ridotto in
# data/raw/geo/ostuni-ztl.json; la mappa del sito non ufficiale NON è usata): il disciplinare rimanda a una planimetria
# allegata, non pubblicata; OSM non ha un'area ZTL. L'area è il borgo antico racchiuso dalla strada di circonvallazione
# (viale Oronzo Quaranta), chiusa a sud dalle strade dei quattro varchi e dalle loro congiunzioni (via Montegrappa, via
# Francesco Tanzarella Vitale, il primo tratto di via Cattedrale, via Anna Carmignano, via Francesco Cavallo):
# osm_geo.street_area con i buchi riempiti. Il disciplinare tratta viale Oronzo Quaranta come strada della ZTL (art. 7 c. 6).
# Uso: python3 Tools/build_ostuni.py   (non tocca le altre città né manifest.json)
import json, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/ostuni"
CHECKED = "2026-10-27T17:00:00Z"
ALL = [1, 2, 3, 4, 5, 6, 7]

COMUNE = "https://www.comune.ostuni.br.it/servizio/richiedere-permesso-di-accesso-ad-area-ztl/"
ACS = "https://www.accessibilitacentristorici.it/ztl/puglia/ostuni.html"
DISC = "https://www.accessibilitacentristorici.it/ufficiali/regolamenti/Ostuni_regolamento%20ztl%20con%20modifica%20di%20di%20marzo%202018.pdf"
UNOFFICIAL = {"name": "accessibilitacentristorici.it", "url": ACS}


def flat(s):
    return re.sub(r"\s+", " ", s).strip()


TEXT = {p.stem: flat(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def check(file, *phrases):
    for q in phrases:
        if flat(q) not in TEXT[file]:
            raise SystemExit(f"{file}: frase non trovata: {q!r}")


QUOTE = ("La ZTL di Ostuni è attiva tutti i giorni 24 ore su 24 ore con le seguenti eccezioni: Via Cattedrale (varco aperto dalle "
         "ore 07:00 alle ore 10:00 e dalle ore 14:00 alle ore 17:00 ) Via Francesco Cavallo (varco aperto dalle ore 07:00 alle ore "
         "10:00 e dalle ore 14:00 alle ore 17:00 ) Via Montegrappa (varco aperto dalle 8.00 alle 13.00 e dalle ore 16.00 alle 19.00 ) "
         "Via Francesco Vitale (varco aperto dalle ore 07:00 alle ore 10:00. e dalle ore 14:00 alle ore 17:00 )")
check("accessibilitacentristorici-ostuni", QUOTE,
      "La ZTL di Ostuni riguarda una importante parte del centro storico.",
      "I veicoli elettrici possono essere autorizzati ad entrare nella ZTL di Ostuni.",
      "I titolari di alberghi e strutture ricettive aventi sede all'interno della ZTL di Ostuni possono ottenere l'autorizzazione per il rilascio ai propri clienti di permessi utili per l'accesso e la sosta limitata al tempo strettamente necessario al carico/scarico bagagli, nelle immediate vicinanze del proprio esercizio.",
      "entro le successive 120 ore all'accesso (pari a 5 giorni)",
      "Data aggiornamento: 30/10/2018")
check("disciplinare-ztl-2018", "D e l i b e r a d i G i u n t a C o m u n a l e n . 64 d e l 28/03/2018",
      "I varchi di accesso e di uscita della Z.T.L. del Centro Storico sono quattro:",
      "La zona a traffico limitato è delimitata come da planimetria allegata, approvata dal Ministero delle Infrastrutture e dei Trasporti.",
      "In ogni caso, il transito di veicoli a trazione esclusivamente elettrica è sempre consentito.",
      "Ai residenti di Via Anna Carmignano e Largo Lanza è consentito il transito dai due varchi di accesso alla ZTL di Via F.sco Vitale e di Via F.sco Cavallo e la sosta in Viale Oronzo Quaranta",
      "ACCESSI CONSENTITI NELLA Z.T.L. - ALBERGHI E STRUTTURE RICETTIVE")
check("comune-servizio-permesso-ztl", "Albergo e struttura ricettiva per CARICO E SCARICO MERCI",
      "Per richiedere, modificare o rinnovare il permesso è possibile utilizzare il servizio online, accedendo con Spid.")

# --- geometria ---
GEO = osm_geo.load("ostuni-ztl")
ways = {e["id"]: e for e in GEO if e["type"] == "way"}
nodes = {e["id"]: e for e in GEO if e["type"] == "node"}
RING = {77244730: "Via Francesco Tanzarella Vitale", 260475467: "Viale O. Quaranta", 777774751: "Viale O. Quaranta",
        81082631: "Viale Oronzo Quaranta", 469078013: "Via Montegrappa", 477749231: "Via Montegrappa", 477749232: "Via Montegrappa",
        471740016: "Via Francesco Cavallo", 1098789290: "Via Cattedrale", 316414278: "Via Anna Carmignano"}
for wid, name in RING.items():
    if ways[wid]["tags"].get("name") != name:
        raise SystemExit(f"Way {wid} non è più {name}")
rel = {"id": 0, "members": [{"type": "way", "role": "section", "geometry": ways[w]["geometry"]} for w in RING]}
shape = osm_geo.perimeter(osm_geo.street_area(rel, cell_m=6, close_m=45), tol_m=4)
area = osm_geo.area_km2([(p["lon"], p["lat"]) for p in shape])
if not 0.05 < area < 0.15:
    raise SystemExit(f"Area non plausibile: {area:.3f} km²")
# Controlli: Cattedrale, piazzetta Cattedrale/via Cattedrale alta, largo Arcidiacono Teodoro Trinchera, via Petrarolo dentro;
# piazza della Libertà, corso Mazzini, via Roma, corso Vittorio Emanuele fuori
for name, lat, lon, inside in [("Via Cattedrale (alta)", 40.73388, 17.57897, True), ("Largo Arcidiacono Teodoro Trinchera", 40.73416, 17.5785, True),
                               ("Via Gaspare Petrarolo", 40.7337, 17.5770, True), ("Via Clemente Brancasi", 40.7346, 17.5775, True),
                               ("Piazza della Libertà", 40.7318, 17.5787, False), ("Corso Mazzini", 40.7320, 17.5765, False),
                               ("Via Roma", 40.72969, 17.57716, False), ("Via Giosuè Pinto (est)", 40.7330, 17.5822, False)]:
    if osm_geo.contains(shape, lat, lon) != inside:
        raise SystemExit(f"Controllo perimetro fallito: {name} dovrebbe essere {'dentro' if inside else 'fuori'}")


def near_boundary(way_ids):
    pts = [(p["lat"], p["lon"], w) for w in way_ids for p in ways[w]["geometry"]]
    return min(pts, key=lambda p: osm_geo.distance_m(shape, p[0], p[1]))


cam = nodes[14092310617]
if cam.get("tags", {}).get("name") != "Varco ztl - Via Cattedrale":
    raise SystemExit("Telecamera di via Cattedrale cambiata in OSM")
mg = min(((p["lat"], p["lon"]) for w in (469078013, 477749231, 477749232) for p in ways[w]["geometry"]))   # estremo sud-ovest
cv = ways[471740016]["geometry"][0]
vi = near_boundary([w for w, e in ways.items() if e["tags"].get("name") in ("Via Francesco Vitale", "Via F. Vitale")])
GATES = [{"id": "os-osm14092310617", "name": "Varco Via Cattedrale", "location": {"lat": round(cam["lat"], 6), "lon": round(cam["lon"], 6)}},
         {"id": "os-osm-way471740016", "name": "Varco Via Francesco Cavallo", "location": {"lat": round(cv["lat"], 6), "lon": round(cv["lon"], 6)}},
         {"id": "os-osm-way469078013", "name": "Varco Via Montegrappa (open 8–13, 16–19)", "location": {"lat": round(mg[0], 6), "lon": round(mg[1], 6)}},
         {"id": f"os-osm-way{vi[2]}", "name": "Varco Via Francesco Vitale", "location": {"lat": round(vi[0], 6), "lon": round(vi[1], 6)}}]
for g in GATES:
    if osm_geo.distance_m(shape, g["location"]["lat"], g["location"]["lon"]) > 40 and not osm_geo.contains(shape, g["location"]["lat"], g["location"]["lon"]):
        raise SystemExit(f"Varco lontano dalla zona: {g['name']}")


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


LINKS = [link("accessibilitacentristorici.it: Ostuni ZTL (unofficial)", "accessibilitacentristorici.it: ZTL di Ostuni (non ufficiale)", "accessibilitacentristorici.it: ZTL Ostuni (inoffiziell)", ACS),
         link("Ostuni ZTL regulations 2018 (copy on accessibilitacentristorici.it, PDF)", "Disciplinare ZTL di Ostuni 2018 (copia su accessibilitacentristorici.it, PDF)", "ZTL-Regelung Ostuni 2018 (Kopie auf accessibilitacentristorici.it, PDF)", DISC),
         link("City of Ostuni: ZTL permit request", "Comune di Ostuni: richiesta permesso ZTL", "Stadt Ostuni: ZTL-Genehmigung beantragen", COMUNE),
         link("OpenStreetMap: Via Cattedrale camera (ODbL)", "OpenStreetMap: telecamera di via Cattedrale (ODbL)", "OpenStreetMap: Kamera Via Cattedrale (ODbL)", osm_geo.osm_url("node", 14092310617))]

PEND = [
    ("Confirmed only by accessibilitacentristorici.it (a private permit-service site, page updated 30/10/2018), which also hosts a copy of the City's 2018 ZTL regulations (Giunta resolution 64 of 28/03/2018). The City's website has only the permit-request page, with no hours or map. OpenStreetMap tags Via Cattedrale with the same open hours (7–10, 14–17).",
     "Confermato solo da accessibilitacentristorici.it (sito privato di servizi per i permessi, pagina aggiornata il 30/10/2018), che ospita anche una copia del disciplinare ZTL del Comune del 2018 (D.G.C. 64 del 28/03/2018). Il sito del Comune ha solo la scheda per chiedere il permesso, senza orari né mappa. OpenStreetMap dà a via Cattedrale gli stessi orari di apertura (7–10, 14–17).",
     "Nur von accessibilitacentristorici.it bestätigt (private Website für Genehmigungsdienste, Seite aktualisiert am 30.10.2018), die auch eine Kopie der städtischen ZTL-Regelung von 2018 bereitstellt (Beschluss 64 vom 28.03.2018). Die Website der Stadt hat nur die Antragsseite, ohne Zeiten oder Karte. OpenStreetMap gibt der Via Cattedrale die gleichen Öffnungszeiten (7–10, 14–17)."),
    ("The Via Montegrappa gate (Porta Nova side) has different open hours: 8 am–1 pm and 4–7 pm. The app shows the hours of the other three gates.",
     "Il varco di via Montegrappa (lato Porta Nova) ha altri orari di apertura: 8–13 e 16–19. L'app mostra gli orari degli altri tre varchi.",
     "Die Kamera in der Via Montegrappa (Seite Porta Nova) hat andere Öffnungszeiten: 8–13 und 16–19 Uhr. Die App zeigt die Zeiten der anderen drei Einfahrten."),
    ("Hotels inside the ZTL can give guests a permit to stop for luggage near the hotel; ask before arriving. Fully electric cars may always drive in. Blue Badge holders may enter in an emergency and send the papers to the Municipal Police within 120 hours (5 days); nobody else can regularise afterwards. Motorbikes and mopeds banned too.",
     "Gli hotel dentro la ZTL possono dare ai clienti un permesso per fermarsi a scaricare i bagagli vicino alla struttura; chiedi prima di arrivare. Le auto solo elettriche entrano sempre. I disabili possono entrare in urgenza e mandare i documenti alla Polizia Locale entro 120 ore (5 giorni); gli altri non possono sanare dopo. Vietato anche a moto e ciclomotori.",
     "Hotels in der ZTL können Gästen eine Genehmigung zum Halten für das Gepäck in Hotelnähe geben; frag vor der Ankunft. Reine Elektroautos dürfen immer hinein. Inhaber eines Behindertenausweises dürfen im Notfall hinein und die Unterlagen binnen 120 Stunden (5 Tage) der Stadtpolizei schicken; alle anderen können nachträglich nichts regeln. Auch Motorräder und Mopeds verboten."),
    ("Area drawn on OpenStreetMap as the old town inside the ring road (Viale Oronzo Quaranta), closed to the south by the four gate streets: the official map attached to the regulations is not published. OpenStreetMap also marks Piazza della Libertà, Corso Mazzini and Corso Vittorio Emanuele below the old town as permit-only outside Mon–Fri 7–10 and 14–17 and Saturday 0–10, with two more cameras: not confirmed by any source, not drawn.",
     "Area disegnata su OpenStreetMap come il borgo antico dentro la circonvallazione (viale Oronzo Quaranta), chiuso a sud dalle strade dei quattro varchi: la planimetria allegata al disciplinare non è pubblicata. OpenStreetMap segna anche piazza della Libertà, corso Mazzini e corso Vittorio Emanuele, sotto il borgo, come riservati ai permessi fuori da lun–ven 7–10 e 14–17 e sabato 0–10, con altre due telecamere: nessuna fonte lo conferma, non disegnati.",
     "Fläche in OpenStreetMap als Altstadt innerhalb der Ringstraße (Viale Oronzo Quaranta), im Süden durch die vier Kamerastraßen begrenzt: Die der Regelung beigefügte Karte ist nicht veröffentlicht. OpenStreetMap markiert außerdem Piazza della Libertà, Corso Mazzini und Corso Vittorio Emanuele unterhalb der Altstadt als nur mit Genehmigung außerhalb Mo–Fr 7–10 und 14–17 sowie Sa 0–10, mit zwei weiteren Kameras: von keiner Quelle bestätigt, nicht eingezeichnet."),
]

zones = [{
    "id": "ostuni-centro", "name": "Old town · Città Bianca ZTL", "name_it": "Borgo antico · ZTL della Città Bianca", "name_de": "Altstadt · ZTL der Città Bianca",
    "kind": "restricted",
    "summary": "The old town of Ostuni (the white hilltop town with the Cathedral, inside Viale Oronzo Quaranta) is closed to cars and motorbikes without a permit every day except 7–10 am and 2–5 pm, when the gates of Via Cattedrale, Via Francesco Cavallo and Via Francesco Vitale are open. The Via Montegrappa gate is open 8 am–1 pm and 4–7 pm instead. Rules from an unofficial site.",
    "summary_it": "Il borgo antico di Ostuni (la città bianca sul colle con la Cattedrale, dentro viale Oronzo Quaranta) è chiuso ad auto e moto senza permesso tutti i giorni tranne 7–10 e 14–17, quando i varchi di via Cattedrale, via Francesco Cavallo e via Francesco Vitale sono aperti. Il varco di via Montegrappa invece è aperto 8–13 e 16–19. Regole da un sito non ufficiale.",
    "summary_de": "Die Altstadt von Ostuni (die weiße Stadt auf dem Hügel mit der Kathedrale, innerhalb des Viale Oronzo Quaranta) ist für Autos und Motorräder ohne Genehmigung täglich gesperrt, außer 7–10 und 14–17 Uhr, wenn die Einfahrten Via Cattedrale, Via Francesco Cavallo und Via Francesco Vitale offen sind. Die Einfahrt Via Montegrappa ist dagegen 8–13 und 16–19 Uhr offen. Regeln von einer inoffiziellen Website.",
    "perimeter": shape, "gates": GATES,
    "windows": [{"weekdays": ALL, "start": 0, "end": 7 * 60}, {"weekdays": ALL, "start": 10 * 60, "end": 14 * 60},
                {"weekdays": ALL, "start": 17 * 60, "end": 1440}],
    "freeOnHolidays": False, "holidaysAsSunday": False, "exemptFuels": ["electric"], "hotelCanRegister": True,
    "source": {"authority": "City of Ostuni", "pageURL": COMUNE,
               "ordinance": "Disciplina dell'accesso, circolazione e sosta nella ZTL del centro storico, D.G.C. n. 64 del 28/03/2018 — copia sul sito non ufficiale",
               "ordinanceURL": DISC, "quote": QUOTE,
               "quoteTranslation": "The Ostuni ZTL is active every day, 24 hours a day, with these exceptions: Via Cattedrale (gate open from 07:00 to 10:00 and from 14:00 to 17:00), Via Francesco Cavallo (gate open from 07:00 to 10:00 and from 14:00 to 17:00), Via Montegrappa (gate open from 8.00 to 13.00 and from 16.00 to 19.00), Via Francesco Vitale (gate open from 07:00 to 10:00 and from 14:00 to 17:00)",
               "quoteTranslation_de": "Die ZTL Ostuni ist täglich rund um die Uhr aktiv, mit diesen Ausnahmen: Via Cattedrale (Einfahrt offen von 07:00 bis 10:00 und von 14:00 bis 17:00), Via Francesco Cavallo (offen von 07:00 bis 10:00 und von 14:00 bis 17:00), Via Montegrappa (offen von 8.00 bis 13.00 und von 16.00 bis 19.00), Via Francesco Vitale (offen von 07:00 bis 10:00 und von 14:00 bis 17:00)",
               "checkedOn": CHECKED, "reviewedByHuman": False,
               "pending": [p[0] for p in PEND], "pending_it": [p[1] for p in PEND], "pending_de": [p[2] for p in PEND],
               "links": LINKS, "official": False, "unofficialSource": UNOFFICIAL}}]

city = {"id": "ostuni", "name": "Ostuni", "name_it": "Ostuni", "name_de": "Ostuni",
        "center": {"lat": 40.7333, "lon": 17.5785}, "zones": zones, "status": "draft",
        "license": "Rules: accessibilitacentristorici.it (unofficial) and its copy of the City's 2018 ZTL regulations. Area and gates: " + osm_geo.ODBL + " (approximate, not official)."}

ready = all(len(z["perimeter"]) >= 5 and z["source"]["quote"] and z["source"]["official"] is False for z in zones)
out = ROOT / ("Resources/Cities/ostuni.json" if ready else "data/drafts/ostuni.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/ostuni.json" if ready else "Resources/Cities/ostuni.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), len(shape), f"{area:.3f} km²", [(g["name"], g["location"]) for g in GATES])
