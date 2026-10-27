#!/usr/bin/env python3
# Costruisce la scheda di Rimini dalle pagine e dagli atti ufficiali salvati in data/raw/rimini/ (URL e data di lettura in
# testa a ogni file; fonti e date in docs/fonti-rimini.md).
#
# Regole (lette il 27/10/2026): pagina «Varchi ZTL Centro storico e Borgo San Giuliano» (13 varchi e loro orari), notizia
# del 28/01/2026 (sanzioni dal 29/01/2026, permessi), servizio «permesso giornaliero» (5 €, 72 ore), delibere di Giunta
# 161/2024 e 393/2025, Allegato B «Tipologie di permessi ZTL-APU» (strutture ricettive, ristoranti, piazze vietate),
# legenda dell'Allegato A alla delibera 393/2025, volantino di gennaio 2026 (sanzione 83 €).
#
# Geometria (mai disegnata a mano): i settori della ZTL e le aree pedonali vengono dalla mappa ufficiale dell'Allegato A
# alla delibera 393/2025, agganciata alle coordinate da Tools/rimini_mappa.py (data/raw/rimini/ztl-mappa-ufficiale.geojson;
# la mappa ha due riquadri: la pianta generale e l'ingrandimento con il Borgo San Giuliano; dove una parte compare in tutti e
# due si tiene quella più grande, cioè non tagliata dal bordo del riquadro). Ogni settore con un orario diverso è una zona.
# I varchi sono gli incroci dell'elenco ufficiale, presi dalle strade di OpenStreetMap (data/raw/geo/rimini-centro.json,
# © OpenStreetMap contributors, ODbL 1.0). Le piazze vietate anche a chi ha il permesso (piazza Cavour, piazza Tre Martiri,
# piazza Malatesta) sono aree pedonali dalle loro aree in OpenStreetMap.
# Uso: python3 Tools/build_rimini.py   (non tocca le altre città né manifest.json)
import json, math, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/rimini"
CHECKED = "2026-10-27T10:00:00Z"
EVERY_DAY = [1, 2, 3, 4, 5, 6, 7]


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


VARCHI_F, DAY_F, NEWS_F, B_F, LEG_F, D393_F, D161_F, FLY_F, PDM_F = (
    "comune-varchi-ztl-centro-storico-borgo", "comune-permesso-giornaliero-ztl", "comune-notizia-sanzioni-29-gennaio-2026",
    "allegato-b-permessi-ztl-apu-estratto", "allegato-a-dgc-393-2025-legenda", "dgc-393-2025", "dgc-161-2024",
    "volantino-ztl-2026", "comune-ztl-parco-del-mare-nord")
VARCHI, DAY, NEWS, ALL_B, ALL_A, D393, D161, FLYER, PDM = map(url_of, (VARCHI_F, DAY_F, NEWS_F, B_F, LEG_F, D393_F, D161_F, FLY_F, PDM_F))
PORTAL = "https://servizimobilita.comune.rimini.it"

# --- i 13 varchi dell'elenco ufficiale: (numero, testo del Comune, via OSM, via OSM dell'incrocio, classe oraria) ---
GATES = [
    ("01", "Viale Tiberio intersezione con via San Giuliano, funzionamento 0.00 – 24.00", "Viale Tiberio", "Via San Giuliano", "h24"),
    ("02", "Corso d’Augusto intersezione Circonvallazione Occidentale funzionamento 20,30-7,30", "Corso d'Augusto", "Via Circonvallazione Occidentale", "notte2030"),
    ("03", "Corso d’Augusto intersezione con via Ducale funzionamento 7.30 – 20.30", "Corso d'Augusto", "Via Ducale", "giorno"),
    ("04", "Via d’Azeglio intersezione con via Circonvallazione Occidentale funzionamento 22.00-06.00", "Via Massimo D'Azeglio", "Via Circonvallazione Occidentale", "notte22"),
    ("05", "Via Bastioni Meridionali intersezione con Largo Unità d’Italia funzionamento 22.00-06.00", "Via Bastioni Meridionali", "Largo Unità d'Italia", "notte22"),
    ("06", "Via Bertani intersezione via Bastioni Orientali funzionamento 9.00 -12.00 e 16.00-19.30", "Via Agostino Bertani", "Via Bastioni Orientali", "fasce"),
    ("07", "Via Michele Rosa intersezione via Castelfidardo funzionamento 9.00 -12.00", "Via Michele Rosa", "Via Castelfidardo", "mattina"),
    ("08", "Via Castelfidardo intersezione via Clari funzionamento 9.00 -12.00 e 16.00-19.30", "Via Castelfidardo", "Via Arturo Clari", "fasce"),
    ("09", "Via Dante Alighieri intersezione via Aponia funzionamento 9.00 -12.00 e 16.00-19.30", "Via Dante Alighieri", "Via Aponia", "fasce"),
    ("10", "Via XXII Giugno intersezione con via Angherà funzionamento 9.00 -12.00 e 16.00-19.30", "Via 22 giugno 1859", "Via Domenico Angherà", "fasce"),
    ("11", "Corso Papa Giovanni XXIII intersezione piazza Ferrari funzionamento 0.00 – 24.00", "Corso Giovanni ventitreesimo", "Piazza Luigi Ferrari", "h24"),
    ("12", "Via Marecchia intersezione viale Matteotti funzionamento 0.00 – 24.00", "Via Marecchia", "Viale Giacomo Matteotti", "h24"),
    ("13", "Via Trai intersezione via Matteotti funzionamento 0.00 – 24.00", "Via Trai", "Viale Giacomo Matteotti", "h24"),
]
check(VARCHI_F, *[f"{n} - {t}" if n != "01" else f"01- {t}" for n, t, *_ in GATES],
      "Chi è in possesso del permesso per il centro storico potrà transitare attraverso tutti i varchi del centro storico, ma non potrà accedere a quelli di Borgo San Giuliano, e viceversa.",
      "ciclomotori e motoveicoli possono transitare lungo l’itinerario via Agostino Bertani – Largo Giulio Cesare e via Dell’Onestà, anche negli orari di funzionamento della ZTL",
      "09/02/2026")
check(LEG_F, "ZONA TRAFFICO LIMITATO PER FASCE ORARIE 09:00-12:00 / 16:00-19:30", "ZONA TRAFFICO LIMITATO 00:00-24:00",
      "ZONA TRAFFICO LIMITATO 09:00-12:00", "ZONA TRAFFICO LIMITATO 20:30-07:30", "ZONA TRAFFICO LIMITATO 22:00-06:00",
      "ZONA TRAFFICO LIMITATO 07:30-20:30", "AREA PEDONALE")
check(DAY_F, "accesso giornaliero al costo di 5 euro utilizzabile al massimo n.3 volte al mese per ciascuna targa",
      "accesso quadrigiornaliero valido per n.4 giorni consecutivi utilizzabile per ciascuna targa una volta al mese, al costo di 15 euro.",
      "L'accesso alla ZTL/APU si intenderà autorizzato se comunicato entro 72 ore dal transito.",
      "Il transito è senza limitazione di orario per l' area centro storico \"Rimini Centro\" e Borgo San Giuliano",
      "Il permesso non autorizza la sosta, ma esclusivamente brevi soste operative di carico e scarico.",
      "Divieto di circolazione in Piazza Cavour, Piazza Tre Martiri, Via IV Novembre nel tratto compreso tra Piazza Tre Martiri e Via Castelfidardo, Via Garibaldi nel tratto compreso tra Piazza Tre Martiri e Via Sigismondo, Piazza Malatesta.",
      "emergenze.ztl@comune.rimini.it")
check(NEWS_F, "A partire da domani, giovedì 29 gennaio, entra nella fase sanzionatoria la nuova Zona a traffico limitato del centro storico di Rimini e del Borgo San Giuliano",
      "possono abilitare al transito, fino a 5 targhe contemporaneamente per i propri clienti, comunicandole entro 72 ore dal transito",
      "Il pagamento avviene tramite carta di credito, debito o conto corrente")
check(B_F, "La presente regolamentazione riguarda tutti i veicoli a motore: benzina, diesel, elettrici ed ibridi",
      "Art. 4.2 – Strutture ricettive (Alberghi – Affittacamere - Bad & Breakfast - Camping –ecc.)",
      "L’accesso si intenderà autorizzato se comunicato entro 72 ore dal",   # nel PDF «permesso transito» è spezzato dalla colonna
      "Ogni struttura recettiva potrà rilasciare al contemporaneamente un numero di permessi massimo pari al numero di posti letto disponibili.",
      "divieto di circolazione in piazza Cavour; piazza Tre Martiri; via IV Novembre nel tratto compreso tra piazza Tre Martiri e via Castelfidardo esclusa; via Garibaldi nel tratto compreso tra piazza Tre Martiri e via Sigismondo; Piazza Malatesta;",
      "aggiornato con delibera di Giunta 393 del 28/10/2025")
check(D161_F, "sarà attivo solo in orario notturno dalle ore 22.00 alle ore 6.00",
      "il tratto di Corso d’Augusto tra via Ducale e via Santa Maria in Corte sarà attivo formalmente solo tra le 7.30 e le 20.30")
check(D393_F, "DI APPROVARE il perimetro della nuova ZTL e APU del centro storico di Rimini e del Borgo San Giuliano")
check(FLY_F, "la violazione comporta una sanzione ai sensi del Codice della Strada di 83 euro.")
check(PDM_F, "La ZTL DEL PARCO DEL MARE E' ATTIVA TUTTI I GIORNI dal 1 giugno al 10 settembre.")

# --- geometria dalla mappa ufficiale ---
MAP = json.loads((RAW / "ztl-mappa-ufficiale.geojson").read_text(encoding="utf-8"))
MIN_M2 = 500   # sotto: resti di simboli o minuscole aree pedonali (nei pending)


def ring_of(f):
    return [tuple(p) for p in f["geometry"]["coordinates"][0]]


def centroid(r):
    return sum(p[0] for p in r) / len(r), sum(p[1] for p in r) / len(r)


def official_parts():
    """Le parti di ogni classe: dalla pianta generale; dall'ingrandimento quelle che mancano o vi sono più grandi"""
    main = [f for f in MAP["features"] if f["properties"]["frame"] == "pianta"]
    zoom = [f for f in MAP["features"] if f["properties"]["frame"] == "ingrandimento" and not f["properties"]["cutByFrame"]]
    parts = list(main)
    for z in zoom:
        rz = ring_of(z)
        same = [m for m in parts if m["properties"]["class"] == z["properties"]["class"] and
                (osm_geo.inside_lonlat(rz, *centroid(ring_of(m))) or osm_geo.inside_lonlat(ring_of(m), *centroid(rz)))]
        if not same:
            parts.append(z)
        elif all(z["properties"]["area_m2"] > m["properties"]["area_m2"] * 1.05 for m in same):
            parts = [p for p in parts if p not in same] + [z]
    return [p for p in parts if p["properties"]["area_m2"] >= MIN_M2]


PARTS = official_parts()

GEO = json.loads((ROOT / "data/raw/geo/rimini-centro.json").read_text(encoding="utf-8"))["elements"]
STREETS = [e for e in GEO if e["type"] == "way" and "highway" in e.get("tags", {})]


def gate_point(a, b):
    """L'incrocio tra due strade OSM (nodo in comune, altrimenti i due punti più vicini)"""
    wa = [w for w in STREETS if w["tags"].get("name") == a]
    wb = [w for w in STREETS if w["tags"].get("name") == b]
    assert wa and wb, (a, b)
    pos = {n: (p["lat"], p["lon"]) for w in wa + wb for n, p in zip(w["nodes"], w["geometry"])}
    common = {n for w in wa for n in w["nodes"]} & {n for w in wb for n in w["nodes"]}
    if common:
        n = min(common)
        return pos[n], 0.0
    best = None
    for w in wa:
        for p in w["geometry"]:
            for v in wb:
                for q in v["geometry"]:
                    d = math.hypot((p["lat"] - q["lat"]) * 110574, (p["lon"] - q["lon"]) * 80000)
                    if best is None or d < best[0]:
                        best = (d, ((p["lat"] + q["lat"]) / 2, (p["lon"] + q["lon"]) / 2))
    return best[1], best[0]


def L(p):
    return {"lat": p[0], "lon": p[1]}


# --- testi comuni ---
def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


LINKS = [link("City of Rimini: ZTL gates of the historic centre and Borgo San Giuliano, with hours", "Comune di Rimini: varchi ZTL del centro storico e del Borgo San Giuliano, con gli orari",
              "Stadt Rimini: ZTL-Kameras der Altstadt und des Borgo San Giuliano, mit Zeiten", VARCHI),
         link("City of Rimini: day permit (5 €) for the ZTL and pedestrian area", "Comune di Rimini: permesso giornaliero (5 €) per ZTL e area pedonale",
              "Stadt Rimini: Tagesgenehmigung (5 €) für ZTL und Fußgängerzone", DAY),
         link("City of Rimini: mobility services portal (permits, plate registration)", "Comune di Rimini: portale dei servizi della mobilità (permessi, targhe)",
              "Stadt Rimini: Mobilitätsportal (Genehmigungen, Kennzeichen)", PORTAL),
         link("City of Rimini: fines from 29 January 2026 and who may enter", "Comune di Rimini: sanzioni dal 29 gennaio 2026 e chi può entrare",
              "Stadt Rimini: Bußgelder ab 29. Januar 2026 und wer einfahren darf", NEWS),
         link("Official map (Annex A to Council resolution 393/2025, PDF)", "Mappa ufficiale (Allegato A alla delibera di Giunta 393/2025, PDF)",
              "Offizielle Karte (Anlage A zum Stadtratsbeschluss 393/2025, PDF)", ALL_A),
         link("Permit rules (Annex B, PDF)", "Regole dei permessi (Allegato B, PDF)", "Genehmigungsregeln (Anlage B, PDF)", ALL_B),
         link("City of Rimini: seasonal ZTL Parco del Mare Nord (seafront)", "Comune di Rimini: ZTL stagionale Parco del Mare Nord (lungomare)",
              "Stadt Rimini: saisonale ZTL Parco del Mare Nord (Strandpromenade)", PDM)]

PENDING = [
    ("Hours are the same every day: the City's gate list and map give no exception for Sundays or public holidays.",
     "Gli orari valgono tutti i giorni: l'elenco dei varchi e la mappa del Comune non prevedono eccezioni per domeniche e festivi.",
     "Die Zeiten gelten jeden Tag: Kameraliste und Karte der Stadt sehen keine Ausnahme für Sonn- und Feiertage vor."),
    ("Day permit 5 € (whole day, at most 3 times a month per plate) or 4-day permit 15 € (once a month; not both in the same month), only online on the City's mobility portal, paid by card through PagoPA; it can be registered up to 72 hours after you pass the camera. It allows driving, not parking (only short loading stops). GateLR tells you to register by the next midnight, to be safe.",
     "Permesso giornaliero 5 € (tutto il giorno, al massimo 3 volte al mese per targa) o quadrigiornaliero 15 € (una volta al mese; non insieme nello stesso mese), solo online sul portale della mobilità del Comune, pagamento con carta tramite PagoPA; si può registrare fino a 72 ore dopo il passaggio. Consente il transito, non la sosta (solo brevi soste di carico e scarico). GateLR consiglia di registrarlo entro la mezzanotte del giorno dopo, per prudenza.",
     "Tagesgenehmigung 5 € (ganzer Tag, höchstens 3-mal im Monat pro Kennzeichen) oder 4-Tage-Genehmigung 15 € (einmal im Monat; nicht beide im selben Monat), nur online im Mobilitätsportal der Stadt, Zahlung per Karte über PagoPA; Registrierung bis 72 Stunden nach der Durchfahrt möglich. Erlaubt das Fahren, nicht das Parken (nur kurzes Be- und Entladen). GateLR empfiehlt sicherheitshalber die Registrierung bis Mitternacht des Folgetags."),
    ("Hotels, B&Bs and campsites inside the zone register your plate on the City's portal within 72 hours of your passage (as many cars as they have beds). Parking in the ZTL is not allowed. Ask the hotel to confirm.",
     "Alberghi, B&B e campeggi dentro la zona registrano la tua targa sul portale del Comune entro 72 ore dal passaggio (tante auto quanti posti letto). La sosta in ZTL non è consentita. Chiedi conferma all'hotel.",
     "Hotels, B&Bs und Campingplätze in der Zone melden dein Kennzeichen innerhalb von 72 Stunden nach der Durchfahrt im Portal der Stadt (so viele Autos wie Betten). Parken in der ZTL ist nicht erlaubt. Lass es dir vom Hotel bestätigen."),
    ("Restaurants in the 24-hour sectors and pedestrian areas can register up to 5 customer plates at a time, within 72 hours (drop-off only, no parking).",
     "I ristoranti dei settori 0–24 e delle aree pedonali possono registrare fino a 5 targhe di clienti alla volta, entro 72 ore (solo accompagnamento, niente sosta).",
     "Restaurants in den 24-Stunden-Bereichen und Fußgängerzonen können bis zu 5 Kundenkennzeichen gleichzeitig melden, innerhalb von 72 Stunden (nur Bringen und Abholen, kein Parken)."),
    ("Electric and hybrid cars are not exempt; motorcycles need a permit too, except on the route Via Bertani – Largo Giulio Cesare – Via dell'Onestà (post office). Disabled badge holders not registered in Rimini e-mail emergenze.ztl@comune.rimini.it before or within 72 hours.",
     "Auto elettriche e ibride non esenti; anche moto e ciclomotori servono il permesso, tranne sull'itinerario via Bertani – Largo Giulio Cesare – via dell'Onestà (Poste). I titolari di contrassegno disabili non registrato a Rimini scrivono a emergenze.ztl@comune.rimini.it prima o entro 72 ore.",
     "Elektro- und Hybridautos sind nicht befreit; auch Motorräder brauchen eine Genehmigung, außer auf der Strecke Via Bertani – Largo Giulio Cesare – Via dell'Onestà (Post). Inhaber eines nicht in Rimini registrierten Behindertenausweises schreiben vorher oder innerhalb von 72 Stunden an emergenze.ztl@comune.rimini.it."),
    ("Piazza Cavour, Piazza Tre Martiri, Piazza Malatesta, Via IV Novembre (Piazza Tre Martiri – Via Castelfidardo) and Via Garibaldi (Piazza Tre Martiri – Via Sigismondo) are closed to traffic even with a permit. Fine for entering without a permit: 83 €.",
     "Piazza Cavour, piazza Tre Martiri, piazza Malatesta, via IV Novembre (piazza Tre Martiri – via Castelfidardo) e via Garibaldi (piazza Tre Martiri – via Sigismondo) sono vietate anche con il permesso. Multa per l'accesso senza permesso: 83 €.",
     "Piazza Cavour, Piazza Tre Martiri, Piazza Malatesta, Via IV Novembre (Piazza Tre Martiri – Via Castelfidardo) und Via Garibaldi (Piazza Tre Martiri – Via Sigismondo) sind auch mit Genehmigung gesperrt. Bußgeld bei Einfahrt ohne Genehmigung: 83 €."),
    ("Zone edges come from the City's official map (Annex A, resolution 393/2025) fitted to OpenStreetMap buildings: accurate to a few metres. Very small pedestrian spots are not shown.",
     "I bordi vengono dalla mappa ufficiale del Comune (Allegato A, delibera 393/2025) agganciata agli edifici di OpenStreetMap: precisi a pochi metri. Le aree pedonali molto piccole non sono disegnate.",
     "Die Grenzen stammen aus der offiziellen Karte der Stadt (Anlage A, Beschluss 393/2025), an die Gebäude von OpenStreetMap angepasst: auf wenige Meter genau. Sehr kleine Fußgängerbereiche sind nicht eingezeichnet."),
    ("Not in GateLR yet: the seasonal seafront ZTL «Parco del Mare Nord» (Torre Pedrera, Viserbella, Viserba, Rivabella, Via Boito), active every day from 1 June to 10 September in 2026.",
     "Non ancora in GateLR: la ZTL stagionale del lungomare «Parco del Mare Nord» (Torre Pedrera, Viserbella, Viserba, Rivabella, via Boito), attiva tutti i giorni dal 1° giugno al 10 settembre nel 2026.",
     "Noch nicht in GateLR: die saisonale ZTL an der Strandpromenade «Parco del Mare Nord» (Torre Pedrera, Viserbella, Viserba, Rivabella, Via Boito), 2026 täglich vom 1. Juni bis 10. September aktiv."),
]

TICKET = {"price": 5.0,
          "howTo": "Day permit 5 € (valid all day, at most 3 times a month per plate; 4 days 15 €), only online on the City's mobility portal servizimobilita.comune.rimini.it (SPID or registration, «permessi ZTL», add date and plate, pay with PagoPA). It may be registered up to 72 hours after your passage; GateLR suggests doing it by the next midnight. It does not allow parking.",
          "howTo_it": "Permesso giornaliero 5 € (valido tutto il giorno, al massimo 3 volte al mese per targa; 4 giorni 15 €), solo online sul portale della mobilità del Comune servizimobilita.comune.rimini.it (SPID o registrazione, «permessi ZTL», data e targa, pagamento PagoPA). Si può registrare fino a 72 ore dopo il passaggio; GateLR consiglia entro la mezzanotte del giorno dopo. Non consente la sosta.",
          "howTo_de": "Tagesgenehmigung 5 € (ganzer Tag, höchstens 3-mal im Monat pro Kennzeichen; 4 Tage 15 €), nur online im Mobilitätsportal der Stadt servizimobilita.comune.rimini.it (SPID oder Registrierung, «permessi ZTL», Datum und Kennzeichen, Zahlung über PagoPA). Registrierung bis 72 Stunden nach der Durchfahrt möglich; GateLR empfiehlt bis Mitternacht des Folgetags. Parken ist nicht erlaubt.",
          "url": DAY, "deadline": "nextDayMidnight"}

W_FASCE = [{"weekdays": EVERY_DAY, "start": 9 * 60, "end": 12 * 60}, {"weekdays": EVERY_DAY, "start": 16 * 60, "end": 19 * 60 + 30}]
W_H24 = [{"weekdays": EVERY_DAY, "start": 0, "end": 24 * 60}]
WINDOWS = {"fasce": W_FASCE, "h24": W_H24, "pedonale": W_H24,
           "mattina": [{"weekdays": EVERY_DAY, "start": 9 * 60, "end": 12 * 60}],
           "notte2030": [{"weekdays": EVERY_DAY, "start": 20 * 60 + 30, "end": 7 * 60 + 30}],
           "notte22": [{"weekdays": EVERY_DAY, "start": 22 * 60, "end": 6 * 60}],
           "giorno": [{"weekdays": EVERY_DAY, "start": 7 * 60 + 30, "end": 20 * 60 + 30}]}
HOURS = {"fasce": ("9–12 and 16–19:30", "9–12 e 16–19:30", "9–12 und 16–19:30"), "h24": ("24 hours", "0–24", "rund um die Uhr"),
         "pedonale": ("pedestrian area", "area pedonale", "Fußgängerzone"), "mattina": ("9–12", "9–12", "9–12"),
         "notte2030": ("20:30–7:30", "20:30–7:30", "20:30–7:30"), "notte22": ("22–6", "22–6", "22–6"),
         "giorno": ("7:30–20:30", "7:30–20:30", "7:30–20:30")}
LEGEND = {"fasce": "ZONA TRAFFICO LIMITATO PER FASCE ORARIE 09:00-12:00 / 16:00-19:30", "h24": "ZONA TRAFFICO LIMITATO 00:00-24:00",
          "mattina": "ZONA TRAFFICO LIMITATO 09:00-12:00", "notte2030": "ZONA TRAFFICO LIMITATO 20:30-07:30",
          "notte22": "ZONA TRAFFICO LIMITATO 22:00-06:00", "giorno": "ZONA TRAFFICO LIMITATO 07:30-20:30"}
LEGEND_EN = {"fasce": ("Limited traffic zone, time bands 09:00-12:00 / 16:00-19:30", "Verkehrsbeschränkte Zone, Zeitfenster 09:00-12:00 / 16:00-19:30"),
             "h24": ("Limited traffic zone 00:00-24:00", "Verkehrsbeschränkte Zone 00:00-24:00"),
             "mattina": ("Limited traffic zone 09:00-12:00", "Verkehrsbeschränkte Zone 09:00-12:00"),
             "notte2030": ("Limited traffic zone 20:30-07:30", "Verkehrsbeschränkte Zone 20:30-07:30"),
             "notte22": ("Limited traffic zone 22:00-06:00", "Verkehrsbeschränkte Zone 22:00-06:00"),
             "giorno": ("Limited traffic zone 07:30-20:30", "Verkehrsbeschränkte Zone 07:30-20:30")}

# ogni parte della mappa → zona: (id, nome breve en/it/de, un punto dentro per riconoscerla, borgo?)
# il punto (il baricentro dei vertici della parte, entro 30 m) serve solo a dare il nome alla parte giusta (la geometria viene tutta dalla mappa)
NAMED = [
    ("fasce", "centro", ("Historic centre", "Centro storico", "Altstadt"), (44.05955, 12.57061), False),
    ("fasce", "servi", ("Piazzetta dei Servi", "Piazzetta dei Servi", "Piazzetta dei Servi"), None, False),
    ("fasce", "sferisterio", ("Sferisterio", "Sferisterio", "Sferisterio"), None, False),
    ("h24", "borgo", ("Borgo San Giuliano", "Borgo San Giuliano", "Borgo San Giuliano"), (44.06546, 12.56398), True),
    ("h24", "corso-xxiii", ("Corso Giovanni XXIII", "Corso Giovanni XXIII", "Corso Giovanni XXIII"), (44.06282, 12.56604), False),
    ("h24", "teatini", ("Piazzetta Teatini", "Piazzetta Teatini", "Piazzetta Teatini"), (44.05980, 12.57012), False),
    ("h24", "garibaldi", ("Via Garibaldi – Via Cairoli", "Via Garibaldi – via Cairoli", "Via Garibaldi – Via Cairoli"), (44.05888, 12.56601), False),
    ("mattina", "michele-rosa", ("Via Michele Rosa", "Via Michele Rosa", "Via Michele Rosa"), None, False),
    ("notte2030", "ducale", ("Via Ducale", "Via Ducale", "Via Ducale"), None, False),
    ("notte22", "azeglio", ("Via d'Azeglio", "Via d'Azeglio", "Via d'Azeglio"), (44.06180, 12.56413), False),
    ("notte22", "bastioni", ("Bastioni Meridionali", "Bastioni Meridionali", "Bastioni Meridionali"), (44.05692, 12.56737), False),
    ("giorno", "corso-augusto-nord", ("Corso d'Augusto north", "Corso d'Augusto nord", "Corso d'Augusto Nord"), None, False),
    ("pedonale", "apu-centro", ("Historic centre", "Centro storico", "Altstadt"), (44.06013, 12.56606), False),
    ("pedonale", "apu-borgo", ("Viale Tiberio", "Viale Tiberio", "Viale Tiberio"), (44.06443, 12.56385), True),
]
# per le classi con una sola parte (il punto è None) non serve riconoscerla; per «fasce» le due piccole sono riconosciute
# da via Ducale (Servi, a nord) e dallo Sferisterio (a sud): il punto più a nord è Servi
SMALL_FASCE = sorted([p for p in PARTS if p["properties"]["class"] == "fasce" and p["properties"]["area_m2"] < 50000],
                     key=lambda p: -centroid(ring_of(p))[1])


def part_for(cls, key, point):
    cands = [p for p in PARTS if p["properties"]["class"] == cls]
    if cls == "fasce" and key == "servi": return SMALL_FASCE[0]
    if cls == "fasce" and key == "sferisterio": return SMALL_FASCE[1]
    if point is None:
        assert len(cands) == 1, (cls, len(cands))
        return cands[0]
    d = sorted((math.hypot((centroid(ring_of(p))[1] - point[0]) * 110574, (centroid(ring_of(p))[0] - point[1]) * 80000), i) for i, p in enumerate(cands))
    assert d[0][0] < 30 and (len(d) == 1 or d[1][0] > 150), (cls, key, d)   # la parte è riconosciuta senza ambiguità
    return cands[d[0][1]]


assert len(SMALL_FASCE) == 2, SMALL_FASCE
used = set()
GATE_POINTS = []
for n, text, a, b, cls in GATES:
    (lat, lon), gap = gate_point(a, b)
    assert gap < 40, (n, a, b, gap)   # le due strade si toccano (o quasi)
    GATE_POINTS.append((n, text, cls, round(lat, 6), round(lon, 6)))

# ogni varco va alla zona più vicina con la stessa fascia oraria (0–24: anche le aree pedonali), entro 60 m dal bordo
PERIMS = {key: osm_geo.perimeter([list(p) for p in ring_of(part_for(cls, key, point))], tol_m=2) for cls, key, _, point, _ in NAMED}
CLS = {key: cls for cls, key, *_ in NAMED}
GATE_ZONE = {}
for n, text, gcls, lat, lon in GATE_POINTS:
    d, key = min((osm_geo.distance_m(PERIMS[k], lat, lon), k) for k in PERIMS if CLS[k] == gcls or (gcls == "h24" and CLS[k] == "pedonale"))
    assert d < 60, (n, key, d)
    GATE_ZONE[n] = key

zones = []
for cls, key, (en, it, de), point, borgo in NAMED:
    part = part_for(cls, key, point)
    assert id(part) not in used, key
    used.add(id(part))
    perim = osm_geo.perimeter([list(p) for p in ring_of(part)], tol_m=2)
    # varchi della stessa fascia oraria entro 60 m dal bordo (01 Viale Tiberio: area pedonale del Borgo)
    gates = [{"id": f"rn-varco{n}", "name": f"{n} · " + text.split(" funzionamento")[0].rstrip(","), "location": {"lat": lat, "lon": lon}}
             for n, text, gcls, lat, lon in GATE_POINTS if GATE_ZONE[n] == key]
    he, hi, hd = HOURS[cls]
    if cls == "pedonale":
        name = (f"{en} · Pedestrian area", f"{it} · Area pedonale", f"{de} · Fußgängerzone")
    else:
        name = (f"{en} · ZTL {he}", f"{it} · ZTL {hi}", f"{de} · ZTL {hd}")
    area = "Borgo San Giuliano" if borgo else "centro storico"
    if gates:
        g = next(x for x in GATES if f"rn-varco{x[0]}" == gates[0]["id"])
        quote = (f"01- {g[1]}" if g[0] == "01" else f"{g[0]} - {g[1]}")
        qtr = {"01": ("Gate 01 – Viale Tiberio at Via San Giuliano, active 0:00–24:00", "Kamera 01 – Viale Tiberio, Kreuzung Via San Giuliano, aktiv 0:00–24:00"),
               "02": ("Gate 02 – Corso d'Augusto at Circonvallazione Occidentale, active 20:30–7:30", "Kamera 02 – Corso d'Augusto, Kreuzung Circonvallazione Occidentale, aktiv 20:30–7:30"),
               "03": ("Gate 03 – Corso d'Augusto at Via Ducale, active 7:30–20:30", "Kamera 03 – Corso d'Augusto, Kreuzung Via Ducale, aktiv 7:30–20:30"),
               "04": ("Gate 04 – Via d'Azeglio at Via Circonvallazione Occidentale, active 22:00–06:00", "Kamera 04 – Via d'Azeglio, Kreuzung Via Circonvallazione Occidentale, aktiv 22:00–06:00"),
               "05": ("Gate 05 – Via Bastioni Meridionali at Largo Unità d'Italia, active 22:00–06:00", "Kamera 05 – Via Bastioni Meridionali, Kreuzung Largo Unità d'Italia, aktiv 22:00–06:00"),
               "06": ("Gate 06 – Via Bertani at Via Bastioni Orientali, active 9:00–12:00 and 16:00–19:30", "Kamera 06 – Via Bertani, Kreuzung Via Bastioni Orientali, aktiv 9:00–12:00 und 16:00–19:30"),
               "07": ("Gate 07 – Via Michele Rosa at Via Castelfidardo, active 9:00–12:00", "Kamera 07 – Via Michele Rosa, Kreuzung Via Castelfidardo, aktiv 9:00–12:00"),
               "11": ("Gate 11 – Corso Papa Giovanni XXIII at Piazza Ferrari, active 0:00–24:00", "Kamera 11 – Corso Papa Giovanni XXIII, Kreuzung Piazza Ferrari, aktiv 0:00–24:00"),
               "12": ("Gate 12 – Via Marecchia at Viale Matteotti, active 0:00–24:00", "Kamera 12 – Via Marecchia, Kreuzung Viale Matteotti, aktiv 0:00–24:00")}
        src_page, (qt_en, qt_de) = VARCHI, qtr[g[0]] if g[0] in qtr else (None, None)
        if g[0] in ("08", "09", "10"):
            qt_en, qt_de = qtr["06"]
    elif cls == "pedonale":
        quote = "divieto di circolazione in piazza Cavour; piazza Tre Martiri; via IV Novembre nel tratto compreso tra piazza Tre Martiri e via Castelfidardo esclusa; via Garibaldi nel tratto compreso tra piazza Tre Martiri e via Sigismondo; Piazza Malatesta;"
        qt_en = "no driving in Piazza Cavour; Piazza Tre Martiri; Via IV Novembre between Piazza Tre Martiri and Via Castelfidardo (excluded); Via Garibaldi between Piazza Tre Martiri and Via Sigismondo; Piazza Malatesta"
        qt_de = "Fahrverbot auf der Piazza Cavour, der Piazza Tre Martiri, in der Via IV Novembre zwischen Piazza Tre Martiri und Via Castelfidardo (ausgenommen), in der Via Garibaldi zwischen Piazza Tre Martiri und Via Sigismondo und auf der Piazza Malatesta"
        src_page = ALL_B
    else:
        quote, (qt_en, qt_de), src_page = LEGEND[cls], LEGEND_EN[cls], ALL_A
    if cls == "pedonale" and borgo:
        summ = ("Pedestrian area of the Borgo San Giuliano (Viale Tiberio, towards the Tiberius Bridge), closed to cars 24 hours a day. Hotel guests and day-permit holders (5 € online, up to 72 hours later) may drive through.",
                "Area pedonale del Borgo San Giuliano (viale Tiberio, verso il Ponte di Tiberio), chiusa alle auto 24 ore su 24. Ospiti degli hotel e chi ha il permesso giornaliero (5 € online, anche entro 72 ore) possono transitare.",
                "Fußgängerzone des Borgo San Giuliano (Viale Tiberio, Richtung Tiberiusbrücke), rund um die Uhr für Autos gesperrt. Hotelgäste und Inhaber einer Tagesgenehmigung (5 € online, auch bis 72 Stunden danach) dürfen durchfahren.")
    elif cls == "pedonale":
        summ = (f"Pedestrian area of the {'Borgo San Giuliano' if borgo else 'historic centre'}, closed to cars 24 hours a day. Hotel guests and day-permit holders (5 € online, up to 72 hours later) may drive through, but never into Piazza Cavour, Piazza Tre Martiri or Piazza Malatesta.",
                f"Area pedonale {'del Borgo San Giuliano' if borgo else 'del centro storico'}, chiusa alle auto 24 ore su 24. Ospiti degli hotel e chi ha il permesso giornaliero (5 € online, anche entro 72 ore) possono transitare, mai però in piazza Cavour, piazza Tre Martiri e piazza Malatesta.",
                f"Fußgängerzone {'des Borgo San Giuliano' if borgo else 'der Altstadt'}, rund um die Uhr für Autos gesperrt. Hotelgäste und Inhaber einer Tagesgenehmigung (5 € online, auch bis 72 Stunden danach) dürfen durchfahren, aber nie auf die Piazza Cavour, Piazza Tre Martiri oder Piazza Malatesta.")
    else:
        when = {"fasce": ("9:00–12:00 and 16:00–19:30", "dalle 9 alle 12 e dalle 16 alle 19:30", "9–12 und 16–19:30 Uhr"),
                "h24": ("24 hours a day", "24 ore su 24", "rund um die Uhr"), "mattina": ("9:00–12:00", "dalle 9 alle 12", "9–12 Uhr"),
                "notte2030": ("20:30–7:30 (night)", "dalle 20:30 alle 7:30", "20:30–7:30 Uhr (nachts)"),
                "notte22": ("22:00–6:00 (night)", "dalle 22 alle 6", "22–6 Uhr (nachts)"),
                "giorno": ("7:30–20:30", "dalle 7:30 alle 20:30", "7:30–20:30 Uhr")}[cls]
        free = cls != "h24"
        summ = (f"Sector of the {'Borgo San Giuliano' if borgo else 'historic centre'} ZTL: cameras check plates {when[0]}, every day." + (" Outside these hours you can drive in freely." if free else "") +
                " Without a permit, buy the 5 € day permit online (possible up to 72 hours later); if your hotel is inside, it registers your plate.",
                f"Settore della ZTL {'del Borgo San Giuliano' if borgo else 'del centro storico'}: telecamere accese {when[1]}, tutti i giorni." + (" Fuori orario si entra liberamente." if free else "") +
                " Senza permesso compra online il giornaliero da 5 € (anche entro 72 ore); se l'hotel è dentro, registra la tua targa.",
                f"Bereich der ZTL {'des Borgo San Giuliano' if borgo else 'der Altstadt'}: Kameras prüfen die Kennzeichen {when[2]}, jeden Tag." + (" Außerhalb dieser Zeiten ist die Einfahrt frei." if free else "") +
                " Ohne Genehmigung online die Tagesgenehmigung für 5 € kaufen (auch bis 72 Stunden danach); liegt dein Hotel innen, meldet es dein Kennzeichen.")
    zones.append({
        "id": f"rimini-{key}", "name": name[0], "name_it": name[1], "name_de": name[2], "kind": "pass",
        "summary": summ[0], "summary_it": summ[1], "summary_de": summ[2],
        "perimeter": perim, "gates": sorted(gates, key=lambda g: g["id"]),
        "windows": WINDOWS[cls], "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": True, "ticket": TICKET,
        "source": {"authority": "City of Rimini", "pageURL": src_page,
                   "ordinance": "Delibera di Giunta n. 393 del 28/10/2025 (Allegato A: mappa ZTL e APU; Allegato B: permessi); delibera n. 161 del 14/05/2024",
                   "ordinanceURL": D393,
                   "quote": quote, "quoteTranslation": qt_en, "quoteTranslation_de": qt_de,
                   "checkedOn": CHECKED, "reviewedByHuman": False,
                   "pending": [p[0] for p in PENDING], "pending_it": [p[1] for p in PENDING], "pending_de": [p[2] for p in PENDING],
                   "links": LINKS}})
for z in zones:
    assert TEXT[{VARCHI: VARCHI_F, ALL_B: B_F, ALL_A: LEG_F}[z["source"]["pageURL"]]].find(flat(z["source"]["quote"])) >= 0, z["id"]
assert len(used) == len(PARTS), f"parti della mappa senza zona: {len(PARTS) - len(used)}"
assigned = {g["id"] for z in zones for g in z["gates"]}
assert assigned == {f"rn-varco{n}" for n, *_ in GATES}, sorted({f"rn-varco{n}" for n, *_ in GATES} - assigned)


# --- piazze vietate anche con il permesso: aree OSM ---
def osm_area(name):
    for e in GEO:
        t = e.get("tags", {})
        if t.get("name") != name or t.get("highway") != "pedestrian":
            continue
        if e["type"] == "relation":
            return osm_geo.outer_ring(e)
        if e["type"] == "way" and t.get("area") == "yes" and e["nodes"][0] == e["nodes"][-1]:
            return [(p["lon"], p["lat"]) for p in e["geometry"]]
    raise SystemExit(f"area OSM {name} non trovata")


pedestrian = []
for pid, name in [("rn-ap-piazza-cavour", "Piazza Cavour"), ("rn-ap-piazza-tre-martiri", "Piazza Tre Martiri"), ("rn-ap-piazza-malatesta", "Piazza Malatesta")]:
    ring = osm_area(name)
    pedestrian.append({"id": pid, "name": name, "perimeter": osm_geo.perimeter(ring, tol_m=1)})

city = {"id": "rimini", "name": "Rimini", "name_it": "Rimini", "name_de": "Rimini",
        "center": {"lat": 44.0594, "lon": 12.5683}, "zones": zones, "pedestrian": pedestrian, "status": "draft",
        "license": "Rules and zone map: Comune di Rimini (official pages, Giunta resolutions 161/2024 and 393/2025 with Annexes A and B; the map is CC BY 4.0 as stated on the City's pages). Map fitted to and gates/squares from " + osm_geo.ODBL + "."}

# --- controlli di plausibilità ---
def zone_at(lat, lon):
    return [z["id"] for z in zones if osm_geo.contains(z["perimeter"], lat, lon)]


assert zone_at(44.0594, 12.5683) == ["rimini-apu-centro"], zone_at(44.0594, 12.5683)        # piazza Tre Martiri
assert zone_at(44.0611, 12.5658) == ["rimini-apu-centro"], zone_at(44.0611, 12.5658)        # piazza Cavour
assert zone_at(44.0598, 12.5694) == ["rimini-apu-centro"], zone_at(44.0598, 12.5694)        # Tempio Malatestiano (via IV Novembre)
sc = [p for w in STREETS if w["tags"].get("name") == "Via Santa Chiara" for p in w["geometry"]]
sc = sc[len(sc) // 2]
assert zone_at(sc["lat"], sc["lon"]) == ["rimini-centro"], zone_at(sc["lat"], sc["lon"])    # via Santa Chiara
assert zone_at(44.0640, 12.5738) == [], zone_at(44.0640, 12.5738)                            # stazione FS
assert zone_at(44.05621, 12.57080) == [], zone_at(44.05621, 12.57080)                        # fermata bus «Arco d'Augusto», fuori dalle mura
assert zone_at(44.0657, 12.5630) == ["rimini-borgo"], zone_at(44.0657, 12.5630)              # Borgo San Giuliano, via Forzieri
for z in zones:
    for g in z["gates"]:
        assert osm_geo.distance_m(z["perimeter"], g["location"]["lat"], g["location"]["lon"]) < 60, g
for a in zones:   # i settori non si sovrappongono (al massimo pochi metri di bordo)
    for b in zones:
        if a is not b:
            inside = sum(osm_geo.contains(b["perimeter"], p["lat"], p["lon"]) and osm_geo.distance_m(b["perimeter"], p["lat"], p["lon"]) > 8 for p in a["perimeter"])
            assert inside == 0, (a["id"], b["id"], inside)

ready = all(len(z["perimeter"]) >= 5 and z["source"]["quote"] for z in city["zones"])
out = ROOT / ("Resources/Cities/rimini.json" if ready else "data/drafts/rimini.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/rimini.json" if ready else "Resources/Cities/rimini.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), [(z["id"], len(z["perimeter"]), len(z["gates"]), round(osm_geo.area_km2(z["perimeter"]), 4)) for z in city["zones"]])
