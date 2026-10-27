#!/usr/bin/env python3
# Costruisce Resources/Cities/cortona.json dalle pagine e dagli atti ufficiali del Comune di Cortona salvati in
# data/raw/cortona/ (fonti e date in docs/fonti-cortona.md). Ogni frase citata o riassunta viene ricontrollata sul testo salvato.
#
# Regole: «Disciplinare zone a traffico limitato Rossa e Gialla del centro storico», testo coordinato con la D.G.C. n. 88
#   del 16/04/2019 (ordinanza n. 110 del 26/04/2019, in vigore dal 01/05/2019), e scheda ufficiale «Accesso ZTL» del Comune
#   (aggiornata il 15/04/2025, citazione). Tutti i giorni, festivi compresi:
#   ZTL Rossa  01/10–30/04 10–20; 01/05–30/09 10–04.
#   ZTL Gialla 01/10–30/04 11–14 e 17–20; 01/05–30/09 10–15 e 16–04.
#   (La ZTL di via Benedetti, piazza Pescheria, vicolo Boni, via Passerini e via dell'Amorino ha gli stessi orari della
#   Rossa ma senza elenco di confini chiaro e con «Viale Passerini» sospesa a calendario: non pubblicata, nei pending.)
# Geometria: elenco ufficiale delle strade (art. 2 del disciplinare) sulle strade OpenStreetMap (© OpenStreetMap
#   contributors, ODbL 1.0; API OSM con Tools/fetch_osm_api.py, ridotto in data/raw/geo/cortona-ztl.json) → osm_geo.street_area.
#   Nessuna relazione ZTL in OSM e nessun open data. Tratti parziali: via Roma (Gialla) solo da piazza della Repubblica
#   all'incrocio con via Ghini e via Zefferini; vicolo Venuti (diviso al civico 13/14) e vicolo della Scala (fino a vicolo
#   dell'Amorino) messi nella Rossa, che ha orari più ampi della Gialla. Varchi: i 3 dell'art. 8 (via Nazionale, via Roma
#   per piazza della Repubblica, via Guelfa a Porta Sant'Agostino) nei nodi OSM indicati.
# Uso: python3 Tools/build_cortona.py   (non tocca le altre città né manifest.json)
import json, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/cortona"
CHECKED = "2026-10-27T14:00:00Z"
ALL = [1, 2, 3, 4, 5, 6, 7]

B = "https://www.comune.cortona.ar.it"
SERVICE = B + "/servizi/autorizzazioni/accesso-ztl"
ACTS = B + "/amministrazione/documenti-e-dati/atto-normativo/atti-normativi-ztl-rossa-ztl-gialla-e-ztl-di-via-benedetti"
DISC = B + "/document/open?id=436"
ORD_110 = B + "/document/open?id=429"
ORD_214 = B + "/document/open?id=430"
SCHEDE = B + "/document/open?id=437"
PASSERINI = B + "/novita/comunicati/viale-passerini-programmazione-trimestrale-della-sospensione-della-ztl-3"
PORTAL = "https://www.sicurnext.it/ZTLgest/public/public_inserisci.php"


def flat(s):
    return re.sub(r"\s+", " ", s).strip()


TEXT = {p.stem: flat(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def check(file, *phrases):
    for q in phrases:
        if flat(q) not in TEXT[file]:
            raise SystemExit(f"{file}: frase non trovata, ricontrollare il documento: {q!r}")


Q_RED = ("Z.T.L. ROSSA Periodo Invernale (dal 01 ottobre al 30 aprile, tutti i giorni, festivi compresi) La Z.T.L. è attiva: "
         "dalle ore 10.00 alle ore 20.00. Periodo Estivo (dal 01 maggio al 30 settembre, tutti i giorni, festivi compresi) "
         "La Z.T.L. è attiva: dalle ore 10.00 alle ore 04.00.")
Q_YEL = ("Z.T.L. GIALLA Periodo Invernale (dal 01 ottobre al 30 aprile, tutti i giorni, festivi compresi) La Z.T.L. è attiva: "
         "dalle ore 11.00 alle ore 14.00; dalle ore 17.00 alle ore 20.00. Periodo Estivo (dal 01 maggio al giorno 30 settembre, "
         "tutti i giorni, festivi compresi) La Z.T.L. è attiva: dalle ore 10.00 alle ore 15.00; dalle ore 16.00 alle ore 04.00.")
check("comune-servizio-accesso-ztl", Q_RED, Q_YEL,
      "all’interno della Z.T.L. sono vietati il transito e la sosta a tutti i veicoli (compresi ciclomotori e motocicli), eccetto quelli che sono stati preventivamente autorizzati.",
      "Per i permessi temporanei risposta immediata se possibile, altrimenti procrastinabile fino a 7 giorni dalla richiesta.",
      "Nessun costo previsto a carico del richiedente.", "Modello 12 – Richiesta password per strutture ricettive",
      "Pagina aggiornata il 15/04/2025")
check("disciplinare-ztl-rossa-gialla-2019", "TESTO COORDINATO CON LA DELIBERAZIONE DI GIUNTA COMUNALE N. 88 DEL 16/04/2019",
      "La ZTL ha validità tutti i giorni della settimana con il seguente orario",
      "dal giorno 01 ottobre al giorno 30 aprile", "dal giorno 01 maggio al giorno 30 settembre",
      "ZTL attiva dalle ore 10:00 alle ore 04:00", "dalle ore 16:00 alle ore 04:00",
      "per il transito richiesto dalle strutture ricettive abilitate all’utilizzo dello specifico portale a loro riservato, per la circolazione dei veicoli dei propri clienti;",
      "devono essere effettuate prima dell’eventuale circolazione nelle ZTL Rossa e ZTL Gialla, eccetto che nei seguenti casi nei quali la comunicazione può essere effettuata entro le 48 ore successive:",
      "Piazzale del Mercato, per il con controllo di Via Guelfa (Porta S. Agostino);",
      "Via Roma, per il controllo di Piazza Repubblica;", "Via Nazionale, per il controllo della stessa Via Nazionale.",
      "La semplice richiesta non abilita alla circolazione.",
      # elenco delle strade (art. 2), le voci leggibili nonostante le due colonne
      "- Via Nazionale;", "- Vicolo Amandoli;", "- Vicolo dell’Aurora;", "- Vicolo della Notte;", "- Vicolo del Precipizio;",
      "- Piazza Signorelli", "- Via Casali", "- Via Guelfa;", "- Via S. Sebastiano;", "- Via Roma, fino all’altezza dell’intersezione con via",
      "- Via Ghibellina;", "- Via Ghini;", "- Via Coppi;", "- Vicolo Petrella;", "- Vicolo della Vigna;", "- Via Mura del Mercato;",
      "- Via S. Benedetto;", "- Vicolo del Forno di Sasso;", "- Vicolo Quintani;", "- Via della Campana;", "- Vicolo Fierli;",
      "- Via Vagnucci;", "- Vicolo Corazzi.")
check("ord-110-2019", "ORDINANZA n° 110 del 26/04/2019", "a decorrere dalla data del 01.05.2019:",
      "ZTL comprendente via Benedetti, piazza Pescheria, v.lo Boni, via Passerini e via dell’Amorino")
check("ord-214-2018", "ORDINANZA n° 214 del 28/09/2018", "inserimento nella sezione “ZTL Rossa” dell’intera piazza Signorelli")
check("schede-tecniche-2016", "Strutture ricettive come definite dalla Legge Regionale Toscana 42/2000",
      "Per i clienti delle strutture ricettive, transito consentito nelle ZTL Rossa o ZTL Gialla, sulla base della sede della struttura",
      "limitatamente al periodo di permanenza nella stessa struttura")
check("comune-2026-06-10-passerini-sospensione", "ordina la temporanea sospensione della ZTL di Viale Passerini in Cortona")

# --- geometria: le strade del disciplinare ---
GEO = osm_geo.load("cortona-ztl")
ways = {e["id"]: e for e in GEO if e["type"] == "way"}
RED_NAMES = {"Via Nazionale", "Vicolo Amandoli", "Vicolo Aurora", "Vicolo della Notte", "Vicolo Precipizio",
             "Piazza della Repubblica", "Piazza Baldelli", "Piazza Luca Signorelli", "Via Casali"}
RED_PARTS = {244588314: "Vicolo Venuti", 577435811: "Vicolo Venuti", 712709164: "Vicolo Venuti", 712709163: "Vicolo Venuti",
             350368078: "Vicolo della Scala", 712588314: "Vicolo della Scala", 350368077: "Vicolo della Scala"}
# nomi OSM per le voci del disciplinare (Sernini→«Vicolo Semini», Fabbrucci→«Vicolo Fabrucci», Corazzi→«Vicolo Corazzio»,
# Vagnucci, Armaioli, Beato Guido, del Giardino, della Fogna con via/vicolo scambiati; Vicolo S. Agostino→«Via Sant 'Agostino»)
YEL_NAMES = {"Via Guelfa", "Via San Sebastiano", "Via Ghibellina", "Via Ghini", "Via Coppi", "Vicolo del Moro", "Vicolo della Rosa",
             "Vicolo della Pergola", "Vicolo Semini", "Via Beato Guido", "Via del Giardino", "Vicolo Petrella", "Vicolo della Vigna",
             "Via Armaioli", "Via delle Mura del Mercato", "Vicolo del Marzocco", "Vicolo Orselli", "Via San Benedetto",
             "Vicolo del Forno di Sasso", "Vicolo Bacarelli", "Vicolo del Fosso", "Vicolo Quintani", "Vicolo del Molino",
             "Vicolo della Fogna", "Via della Campana", "Vicolo del Loreto", "Vicolo Fabrucci", "Vicolo Fierli", "Vicolo Vagnucci",
             "Vicolo Corazzio", "Via Sant 'Agostino"}
YEL_PARTS = {106400220: "Via Roma", 577429372: "Via Roma", 577429371: "Via Roma",   # da piazza della Repubblica a via Ghini/Zefferini
             577435812: "Vicolo Venuti"}                                             # verso via San Sebastiano
for w, name in {**RED_PARTS, **YEL_PARTS}.items():
    if ways[w]["tags"].get("name") != name:
        raise SystemExit(f"Way {w} non è più {name}")
if 1376098527 not in ways[577429371]["nodes"] or 1376098527 not in ways[123454352]["nodes"]:
    raise SystemExit("Via Roma non finisce più all'incrocio con via Zefferini")


def area(names, parts):
    sel = sorted(w for w, e in ways.items() if e["tags"].get("name") in names) + sorted(parts)
    rel = {"id": 0, "members": [{"type": "way", "role": "section", "geometry": ways[w]["geometry"]} for w in sel]}
    return osm_geo.perimeter(osm_geo.street_area(rel), tol_m=4)


red, yellow = area(RED_NAMES, RED_PARTS), area(YEL_NAMES, YEL_PARTS)


def node(way_id, node_id):
    w = ways[way_id]
    p = w["geometry"][w["nodes"].index(node_id)]
    return p["lat"], p["lon"]


RED_GATES = [(4581048295, "Varco Via Nazionale (Piazzale Garibaldi)", *node(577434546, 4581048295)),
             (702185098, "Varco Via Roma / Piazza della Repubblica", *node(106400220, 702185098))]
YEL_GATES = [(5535568192, "Varco Via Guelfa (Porta Sant'Agostino)", *node(577427978, 5535568192))]
for shape, gl in ((red, RED_GATES), (yellow, YEL_GATES)):
    for g in gl:
        if osm_geo.distance_m(shape, g[2], g[3]) > 40 and not osm_geo.contains(shape, g[2], g[3]):
            raise SystemExit(f"Varco lontano dalla zona: {g[1]}")
# Controlli: piazza Signorelli e piazza della Repubblica nella Rossa, via Guelfa nella Gialla; Duomo, piazzale Garibaldi,
# piazzale del Mercato (parcheggio), Santa Margherita e Porta Colonia fuori da entrambe
for name, lat, lon, shape, inside in [("Piazza Signorelli", 43.27543, 11.98509, red, True),
                                      ("Piazza della Repubblica", 43.27504, 11.98544, red, True),
                                      ("Via Guelfa", 43.2740, 11.9848, yellow, True), ("Via Ghibellina", 43.2749, 11.9842, yellow, True)] + \
        [(n, la, lo, s, False) for n, la, lo in [("Piazza del Duomo", 43.2764, 11.98397), ("Piazzale Garibaldi", 43.27387, 11.98784),
                                                  ("Piazzale del Mercato", 43.27391, 11.98317), ("Santuario di Santa Margherita", 43.27765, 11.99245),
                                                  ("Porta Colonia", 43.27698, 11.9865)] for s in (red, yellow)]:
    if osm_geo.contains(shape, lat, lon) != inside:
        raise SystemExit(f"Controllo perimetro fallito: {name} dovrebbe essere {'dentro' if inside else 'fuori'}")
a_red, a_yel = osm_geo.area_km2(red), osm_geo.area_km2(yellow)
if not (0.005 < a_red < 0.04 and 0.02 < a_yel < 0.1):
    raise SystemExit(f"Aree non plausibili: {a_red:.3f} {a_yel:.3f} km²")


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


LINKS = [link("City of Cortona: ZTL access (hours, permits)", "Comune di Cortona: accesso ZTL (orari, permessi)", "Stadt Cortona: ZTL-Zufahrt (Zeiten, Genehmigungen)", SERVICE),
         link("City of Cortona: ZTL Rossa and Gialla regulations (coordinated text 2019, PDF)", "Comune di Cortona: disciplinare ZTL Rossa e Gialla (testo coordinato 2019, PDF)", "Stadt Cortona: Regelung ZTL Rossa und Gialla (konsolidierte Fassung 2019, PDF)", DISC),
         link("City of Cortona: ordinance no. 110 of 26/04/2019 (PDF)", "Comune di Cortona: ordinanza n. 110 del 26/04/2019 (PDF)", "Stadt Cortona: Verordnung Nr. 110 vom 26.04.2019 (PDF)", ORD_110),
         link("City of Cortona: all ZTL acts", "Comune di Cortona: tutti gli atti sulle ZTL", "Stadt Cortona: alle ZTL-Rechtsakte", ACTS),
         link("City of Cortona: online temporary permit request", "Comune di Cortona: richiesta online di transito temporaneo", "Stadt Cortona: Online-Antrag auf befristete Durchfahrt", PORTAL),
         link("OpenStreetMap: streets of the regulations (ODbL)", "OpenStreetMap: strade del disciplinare (ODbL)", "OpenStreetMap: Straßen der Regelung (ODbL)", osm_geo.osm_url("way", 462978262))]

P_COMMON = [
    ("Hotels and holiday lets inside the ZTL register their guests' plates on the City's portal for hotels, valid for the stay and only for the zone where the property is; they may do it up to 48 hours after you drive in. Blue Badge holders not living here may also be registered within 48 hours. Anyone else needs a permit before entering (online form, free; reply immediately or within 7 days): the request alone does not authorise you.",
     "Hotel e affitti turistici dentro la ZTL registrano la targa dei clienti sul portale del Comune riservato alle strutture, valida per il soggiorno e solo per la zona della struttura; possono farlo fino a 48 ore dopo l'ingresso. Anche i titolari di contrassegno disabili non residenti possono essere registrati entro 48 ore. Tutti gli altri devono avere il permesso prima di entrare (modulo online, gratuito; risposta immediata o entro 7 giorni): la sola richiesta non abilita al transito.",
     "Hotels und Ferienwohnungen in der ZTL melden die Kennzeichen ihrer Gäste im Portal der Stadt für Unterkünfte an, gültig für den Aufenthalt und nur für die Zone der Unterkunft; das geht bis 48 Stunden nach der Einfahrt. Auch Inhaber eines Behindertenausweises ohne Wohnsitz hier können binnen 48 Stunden gemeldet werden. Alle anderen brauchen die Genehmigung vor der Einfahrt (Online-Formular, kostenlos; Antwort sofort oder binnen 7 Tagen): der Antrag allein berechtigt nicht."),
    ("Motorbikes and mopeds are banned too; only bicycles and handcarts are always allowed. No exemption for electric cars is written in the regulations. Hours from the 2019 regulations, confirmed by the City's ZTL page (updated 15/04/2025); during events the City can change the rules with temporary ordinances.",
     "Vietato anche a moto e ciclomotori; sono sempre ammessi solo biciclette e veicoli a braccia. Il disciplinare non prevede esenzioni per auto elettriche. Orari del disciplinare 2019, confermati dalla pagina ZTL del Comune (aggiornata il 15/04/2025); durante gli eventi il Comune può cambiare le regole con ordinanze temporanee.",
     "Auch Motorräder und Mopeds sind verboten; immer erlaubt sind nur Fahrräder und Handkarren. Eine Ausnahme für Elektroautos sieht die Regelung nicht vor. Zeiten aus der Regelung von 2019, bestätigt durch die ZTL-Seite der Stadt (aktualisiert 15.04.2025); bei Veranstaltungen kann die Stadt die Regeln mit befristeten Verordnungen ändern."),
    ("Area drawn from the official list of streets on OpenStreetMap (no official map is published). Vicolo Venuti (split between the zones at house no. 13/14) and Vicolo della Scala are drawn in the Red zone, the one with longer hours. A few small lanes in the list are not in OpenStreetMap. The separate ZTL of via Benedetti, piazza Pescheria, vicolo Boni, via Passerini and via dell'Amorino has the Red zone's hours but is not drawn.",
     "Area ricavata dall'elenco ufficiale delle strade su OpenStreetMap (nessuna mappa ufficiale pubblicata). Vicolo Venuti (diviso tra le zone al civico 13/14) e vicolo della Scala sono disegnati nella Rossa, quella con gli orari più ampi. Alcuni piccoli vicoli dell'elenco non sono in OpenStreetMap. La ZTL separata di via Benedetti, piazza Pescheria, vicolo Boni, via Passerini e via dell'Amorino ha gli orari della Rossa ma non è disegnata.",
     "Fläche aus der amtlichen Straßenliste auf OpenStreetMap (keine amtliche Karte veröffentlicht). Vicolo Venuti (zwischen den Zonen bei Hausnummer 13/14 geteilt) und Vicolo della Scala sind in der Roten Zone eingezeichnet, der mit längeren Zeiten. Einige kleine Gassen der Liste fehlen in OpenStreetMap. Die eigene ZTL von Via Benedetti, Piazza Pescheria, Vicolo Boni, Via Passerini und Via dell'Amorino hat die Zeiten der Roten Zone, ist aber nicht eingezeichnet."),
]


def source(quote, tr, tr_de):
    return {"authority": "City of Cortona", "pageURL": SERVICE,
            "ordinance": "Disciplinare ZTL Rossa e Gialla, testo coordinato con D.G.C. n. 88 del 16/04/2019 (ordinanza n. 110 del 26/04/2019; prima ord. n. 41/2016 e n. 214/2018)",
            "ordinanceURL": DISC, "quote": quote, "quoteTranslation": tr, "quoteTranslation_de": tr_de,
            "checkedOn": CHECKED, "reviewedByHuman": False,
            "pending": [p[0] for p in P_COMMON], "pending_it": [p[1] for p in P_COMMON], "pending_de": [p[2] for p in P_COMMON],
            "links": LINKS}


SUMMER = {"fromMonth": 5, "fromDay": 1, "toMonth": 9, "toDay": 30}
WINTER = {"fromMonth": 10, "fromDay": 1, "toMonth": 4, "toDay": 30}


def win(season, *spans):
    return [{"weekdays": ALL, "start": a * 60, "end": b * 60, "season": season} for a, b in spans]


zones = [
    {"id": "cortona-rossa", "name": "Via Nazionale · Red ZTL", "name_it": "Via Nazionale · ZTL Rossa", "name_de": "Via Nazionale · Rote ZTL",
     "kind": "restricted",
     "summary": "The heart of Cortona (Via Nazionale from Piazzale Garibaldi, Piazza della Repubblica, Piazza Signorelli, Via Casali and the lanes off Via Nazionale) is closed to cars and motorbikes without a permit every day, holidays included: 10 am–4 am from 1 May to 30 September, 10 am–8 pm from 1 October to 30 April. Cameras at Via Nazionale and Via Roma. Staying inside? Your hotel registers your plate. Otherwise park outside the walls (Piazzale Garibaldi, Piazzale del Mercato) and walk.",
     "summary_it": "Il cuore di Cortona (via Nazionale da piazzale Garibaldi, piazza della Repubblica, piazza Signorelli, via Casali e i vicoli di via Nazionale) è chiuso ad auto e moto senza permesso tutti i giorni, festivi compresi: 10–4 dal 1° maggio al 30 settembre, 10–20 dal 1° ottobre al 30 aprile. Telecamere in via Nazionale e via Roma. Dormi dentro? L'hotel registra la targa. Altrimenti parcheggia fuori dalle mura (piazzale Garibaldi, piazzale del Mercato) e cammina.",
     "summary_de": "Das Herz von Cortona (Via Nazionale ab Piazzale Garibaldi, Piazza della Repubblica, Piazza Signorelli, Via Casali und die Gassen der Via Nazionale) ist für Autos und Motorräder ohne Genehmigung täglich gesperrt, auch an Feiertagen: 10–4 Uhr vom 1. Mai bis 30. September, 10–20 Uhr vom 1. Oktober bis 30. April. Kameras in der Via Nazionale und Via Roma. Du übernachtest innen? Dein Hotel meldet dein Kennzeichen an. Sonst außerhalb der Mauern parken (Piazzale Garibaldi, Piazzale del Mercato) und laufen.",
     "perimeter": red, "gates": [osm_geo.gate_json("cor", g) for g in RED_GATES],
     "windows": win(SUMMER, (10, 4)) + win(WINTER, (10, 20)),
     "freeOnHolidays": False, "holidaysAsSunday": False, "exemptFuels": [], "hotelCanRegister": True,
     "source": source(Q_RED,
                      "Red ZTL. Winter period (1 October to 30 April, every day, holidays included): the ZTL is active from 10.00 to 20.00. Summer period (1 May to 30 September, every day, holidays included): the ZTL is active from 10.00 to 04.00.",
                      "Rote ZTL. Winterzeit (1. Oktober bis 30. April, täglich, auch an Feiertagen): die ZTL ist von 10.00 bis 20.00 Uhr aktiv. Sommerzeit (1. Mai bis 30. September, täglich, auch an Feiertagen): die ZTL ist von 10.00 bis 04.00 Uhr aktiv.")},
    {"id": "cortona-gialla", "name": "Via Guelfa · Yellow ZTL", "name_it": "Via Guelfa · ZTL Gialla", "name_de": "Via Guelfa · Gelbe ZTL",
     "kind": "restricted",
     "summary": "The south-west part of the old town (Via Guelfa from Porta Sant'Agostino, Via Ghibellina, Via Ghini, Via San Sebastiano, Via Roma up to Via Zefferini and the lanes between them) is closed to cars and motorbikes without a permit every day, holidays included: 10 am–3 pm and 4 pm–4 am from 1 May to 30 September, 11 am–2 pm and 5–8 pm from 1 October to 30 April. Camera at Porta Sant'Agostino. Staying inside? Your hotel registers your plate. Park at Piazzale del Mercato and walk.",
     "summary_it": "La parte sud-ovest del centro (via Guelfa da Porta Sant'Agostino, via Ghibellina, via Ghini, via San Sebastiano, via Roma fino a via Zefferini e i vicoli in mezzo) è chiusa ad auto e moto senza permesso tutti i giorni, festivi compresi: 10–15 e 16–4 dal 1° maggio al 30 settembre, 11–14 e 17–20 dal 1° ottobre al 30 aprile. Telecamera a Porta Sant'Agostino. Dormi dentro? L'hotel registra la targa. Parcheggia in piazzale del Mercato e cammina.",
     "summary_de": "Der Südwesten der Altstadt (Via Guelfa ab Porta Sant'Agostino, Via Ghibellina, Via Ghini, Via San Sebastiano, Via Roma bis Via Zefferini und die Gassen dazwischen) ist für Autos und Motorräder ohne Genehmigung täglich gesperrt, auch an Feiertagen: 10–15 und 16–4 Uhr vom 1. Mai bis 30. September, 11–14 und 17–20 Uhr vom 1. Oktober bis 30. April. Kamera an der Porta Sant'Agostino. Du übernachtest innen? Dein Hotel meldet dein Kennzeichen an. Auf dem Piazzale del Mercato parken und laufen.",
     "perimeter": yellow, "gates": [osm_geo.gate_json("cor", g) for g in YEL_GATES],
     "windows": win(SUMMER, (10, 15), (16, 4)) + win(WINTER, (11, 14), (17, 20)),
     "freeOnHolidays": False, "holidaysAsSunday": False, "exemptFuels": [], "hotelCanRegister": True,
     "source": source(Q_YEL,
                      "Yellow ZTL. Winter period (1 October to 30 April, every day, holidays included): the ZTL is active from 11.00 to 14.00 and from 17.00 to 20.00. Summer period (1 May to 30 September, every day, holidays included): the ZTL is active from 10.00 to 15.00 and from 16.00 to 04.00.",
                      "Gelbe ZTL. Winterzeit (1. Oktober bis 30. April, täglich, auch an Feiertagen): die ZTL ist von 11.00 bis 14.00 und von 17.00 bis 20.00 Uhr aktiv. Sommerzeit (1. Mai bis 30. September, täglich, auch an Feiertagen): die ZTL ist von 10.00 bis 15.00 und von 16.00 bis 04.00 Uhr aktiv.")},
]

city = {"id": "cortona", "name": "Cortona", "name_it": "Cortona", "name_de": "Cortona",
        "center": {"lat": 43.2750, "lon": 11.9854}, "zones": zones, "status": "draft",
        "license": "Rules: Comune di Cortona (ZTL regulations 2019 and official page). Areas and gates: " + osm_geo.ODBL + " (streets of the regulations, approximate)."}

ready = all(len(z["perimeter"]) >= 5 and z["source"]["quote"] for z in city["zones"])
out = ROOT / ("Resources/Cities/cortona.json" if ready else "data/drafts/cortona.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/cortona.json" if ready else "Resources/Cities/cortona.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), [(z["id"], len(z["perimeter"]), len(z["gates"])) for z in city["zones"]], f"{a_red:.3f} + {a_yel:.3f} km²")
