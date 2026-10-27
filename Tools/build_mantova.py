#!/usr/bin/env python3
# Costruisce la scheda di Mantova da quanto salvato in data/raw/mantova/ (fonti e date in docs/fonti-mantova.md).
#
# Fonte NON ufficiale per orari, vie e telecamere (permesso del proprietario, 27/10/2026): accessibilitacentristorici.it
#   «Le telecamere a protezione della ZTL A e B di Mantova sono attive tutti i giorni 24 su 24 ore» → quote,
#   source.official = false, unofficialSource; pubblicata con il meccanismo della 1.16.2 (manifest «unofficialCities»).
#   Concordano: copia del regolamento pass ZTL del Comune del 2002 («uniformità del divieto di accesso per tutte le ZTL dalle
#   ore 0.00 alle ore 24.00», superato dalla D.C.C. 62/2013 non trovata) e la pagina ufficiale di Aster sul trasporto merci
#   (senza pass nelle ZTL A e B solo 6–10 e 15–16:30).
# Fonti ufficiali (Aster, società del Comune, aster.mn.it; Comune): pass, permesso orario per i turisti dall'Area Pass, pass
#   elettriche di altri comuni 100 €, ZTL bus 7–19, disabili di altre città. Nessun orario ufficiale per le auto.
# Geometria: elenchi delle vie di accessibilitacentristorici.it (ZTL A e U → zona «centro storico»; ZTL B; ZTL N) applicati alle
#   strade OpenStreetMap (API OSM, data/raw/geo/mantova-centro.json, ODbL) → osm_geo.street_area (celle 8 m, chiusura 40 m).
#   N e U non esistono più nei moduli Aster (zone A, AC, ARU, AV, B) e le loro telecamere (Cavriani, Montanari, Accademia) sono
#   nell'elenco delle telecamere «a protezione della ZTL A e B»: U (contigua) unita alla A, N (staccata, ~220 m) zona a parte. Escluse le voci ambigue «Commercio» e «Martiri»
#   e via Accademia (orario a parte); vie con soli alcuni civici (Bertani, Calvi, Fernelli) prese intere. Varchi: le 13
#   telecamere dell'elenco, nel vertice della via indicata più vicino al bordo della zona.
# Uso: python3 Tools/build_mantova.py   (non tocca le altre città né manifest.json)
import json, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/mantova"
CHECKED = "2026-10-27T13:00:00Z"
EVERY_DAY = [1, 2, 3, 4, 5, 6, 7]


def flat(s):
    return re.sub(r"\s+", " ", s).strip()


TEXT = {p.stem: flat(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def check(file, *phrases):
    for q in phrases:
        if flat(q) not in TEXT[file]:
            raise SystemExit(f"{file}: frase non trovata: {q!r}")


TOPIC = "https://www.comune.mantova.it/it/topics/ztl"
DISABLED = "https://www.comune.mantova.it/it/services/prenotazione-accesso-zona-a-traffico-limitato-ztl-con-pass-disabile-altre-citta"
ASTER, ASTER_TOUR, ASTER_BUS = "https://aster.mn.it/cittadini/ztl", "https://aster.mn.it/turisti/permesso-orario-ztl", "https://aster.mn.it/turisti/bus-turistici"
check("comune-servizio-pass-disabili-altre-citta",
      "I possessori di pass disabile residenti fuori Comune che necessitano di circolare nelle zone a traffico limitato (ZTL) e sostare nei parcheggi riservati possono prenotare l'accesso.",
      "infomulte@comune.mantova.it")
check("aster-pass-ztl-persone-fisiche", "PASS PER CITTADINI CHE ABITANO NEL COMUNE DI MANTOVA", "ZTL A/RU - Area Pedonale",
      "Transito in ZTL A su percorso obbligato e vincolato alle sole 5 telecamere presenti nelle seguenti vie")
check("aster-pass-ztl-aziende", "Valido anche per il transito dai varchi n. 9 via Trieste e n. 10 corso Libertà")
check("aster-permesso-orario-ztl-turisti", "Per richiedere un permesso orario di accesso alle ZTL di Mantova", "consigliamo un anticipo di almeno 5 giorni")
check("aster-pass-auto-elettriche", "RESIDENTI O DITTE CON SEDE IN ALTRI COMUNI", "Solo Transito 100,00 €")
check("aster-bus-turistici", "regolamentato da ZTL attiva tutti i giorni dalle 7:00 alle 19:00")
check("websearch-27-ottobre-2026", "telecamere attive tutti i giorni 24 ore su 24", "Corso della Libertà e via Trieste aperti a tutti 7–12 e 18–21",
      "voucher ZTL 2,60 € per 24 ore")


UNOFFICIAL = "https://www.accessibilitacentristorici.it/ztl/lombardia/mantova.html"
ASTER_GOODS = "https://aster.mn.it/cittadini/trasporto-merci"
QUOTE = "Le telecamere a protezione della ZTL A e B di Mantova sono attive tutti i giorni 24 su 24 ore"
check("accessibilitacentristorici-mantova", QUOTE, "La ZTL di Mantova è controllata da 13 telecamere",
      "queste saranno definitivamente aperte al traffico dalle 7 alle 12 e dalle 18 alle 21 (per tutti)",
      "Il permesso avrà validità di 24 ore dall'ora trascritta dal titolare dell'albergo, che annoterà anche la targa del veicolo.")
check("aster-trasporto-merci", "nelle ZTL A e B nei seguenti orari: mattino dalle 6.00 alle 10.00",
      "pomeriggio dalle 15.00 alle 16.30, eccetto nelle aree controllate dai dissuasori mobili di transito",
      "Per accessi al di fuori degli orari indicati, è necessario munirsi di permesso orario o di Pass annuale.")
check("regolamento-pass-ztl-2002-copia-acs", "uniformità del divieto di accesso per tutte le ZTL dalle ore 0.00 alle ore 24.00")

# --- vie delle zone (elenchi di accessibilitacentristorici.it) sulle strade OSM ---
GEO = osm_geo.load("mantova-centro")
WAYS = [e for e in GEO if e["type"] == "way" and "highway" in e.get("tags", {}) and "name" in e["tags"]]
NAMES = sorted({e["tags"]["name"] for e in WAYS})
SKIP = {"Commercio", "Martiri", "Accademia"}


def norm(s):
    return re.sub(r"[^a-z0-9 ]", "", s.lower().replace("'", " ").replace("°", "").replace("à", "a").replace("è", "e").replace("ò", "o"))


def listed(label, nxt):
    found = re.search(rf"ZTL {label} costituita dalle vie (.*?)\.? {nxt}", TEXT["accessibilitacentristorici-mantova"]).group(1)
    out, missing = set(), []
    for item in (re.sub(r"\(.*?\)", "", x).strip() for x in re.split(r"\s+-\s*|\s*-\s+|-(?=[A-Z])", found)):
        if not item or item in SKIP:
            continue
        m = {n for n in NAMES if norm(n).endswith(" " + norm(item)) or norm(n) == norm(item)}
        out |= m
        if not m:
            missing.append(item)
    return out, missing


A, miss_a = listed("A", "AREE PEDONALI")
N, miss_n = listed("N", "ZTL U")
U, miss_u = listed("U", "ZTL Libertà")
B, miss_b = listed("B", "ZTL N")
MISSING = miss_a + miss_n + miss_u + miss_b
if len(A) < 75 or len(B) < 15 or len(MISSING) > 8:
    raise SystemExit(f"Corrispondenza vie/OSM cambiata: A {len(A)}, B {len(B)}, mancanti {MISSING}")


def area(streets):
    rel = {"id": "mantova", "members": [{"type": "way", "role": "section", "geometry": e["geometry"]} for e in WAYS if e["tags"]["name"] in streets]}
    return osm_geo.perimeter(osm_geo.street_area(rel, cell_m=8, close_m=40), tol_m=4)


shape_a, shape_b, shape_n = area(A | U), area(B), area(N)      # N è un quartiere a parte, ~220 m a nord della A
area_a, area_b, area_n = (osm_geo.area_km2(s) for s in (shape_a, shape_b, shape_n))
if not (0.3 < area_a < 0.5 and 0.07 < area_b < 0.16 and 0.02 < area_n < 0.07):
    raise SystemExit(f"Aree non plausibili: {area_a:.3f}, {area_b:.3f}, {area_n:.3f} km²")
PSL = next(((e["geometry"][0]["lat"], e["geometry"][0]["lon"]) for e in WAYS if e["tags"]["name"] == "Piazza San Leonardo"))
if not osm_geo.contains(shape_n, *PSL):
    raise SystemExit("Piazza San Leonardo non è nella ZTL N")
for name, lat, lon, za, zb in [("Piazza delle Erbe", 45.1597, 10.7967, True, False), ("Piazza Sordello", 45.1610, 10.7985, True, False),
                               ("Sant'Andrea", 45.1589, 10.7952, True, False), ("Via Tito Speri", 45.15581, 10.78708, False, True),
                               ("Palazzo Te", 45.1484, 10.7867, False, False), ("Piazza San Leonardo (ZTL N)", PSL[0], PSL[1], False, False), ("Stazione FS", 45.1557, 10.7810, False, False)]:
    if osm_geo.contains(shape_a, lat, lon) != za or osm_geo.contains(shape_b, lat, lon) != zb:
        raise SystemExit(f"Controllo perimetro fallito: {name}")

# --- varchi: le 13 telecamere dell'elenco ---
CAMERAS = [("A", "Via Dario Tassoni", "Varco via Tassoni"), ("N", "Via Alessandro Cavriani", "Varco via Cavriani"),
           ("A", "Via Domenico Fernelli", "Varco via Fernelli / via Arrivabene"), ("A", "Via Carlo Montanari", "Varco via Carlo Montanari"),
           ("A", "Via dell'Accademia", "Varco via Accademia"), ("A", "Via Pietro Fortunato Calvi", "Varco via Pietro Fortunato Calvi"),
           ("A", "Via Trieste", "Varco via Trieste"), ("A", "Piazza Martiri di Belfiore", "Varco piazza Martiri"),
           ("A", "Corso della Libertà", "Varco corso della Libertà"),
           ("B", "Via Bellalancia", "Varco via Bellalancia"), ("B", "Piazza Felice Cavallotti", "Varco piazza Cavallotti"),
           ("B", "Via Giosuè Carducci", "Varco via Carducci")]
gates = {"A": [], "B": [], "N": []}
for z, street, label in CAMERAS:
    shape = {"A": shape_a, "B": shape_b, "N": shape_n}[z]
    pts = [(n, q) for e in WAYS if e["tags"]["name"] == street for n, q in zip(e.get("nodes", [None] * len(e["geometry"])), e["geometry"])]
    if not pts:
        raise SystemExit(f"Via della telecamera non trovata in OSM: {street}")
    _, q = min(pts, key=lambda nq: osm_geo.distance_m(shape, nq[1]["lat"], nq[1]["lon"]))
    d = 0 if osm_geo.contains(shape, q["lat"], q["lon"]) else osm_geo.distance_m(shape, q["lat"], q["lon"])
    print(f"  {label}: {d:.0f} m fuori dalla zona" if d else f"  {label}: sul bordo/dentro")
    if d > 60:
        raise SystemExit(f"Telecamera lontana dalla zona: {label}")
    gates[z].append({"id": f"mn-{norm(label).replace(' ', '-')}", "name": label, "location": {"lat": round(q["lat"], 6), "lon": round(q["lon"], 6)}})
speri = [q for e in WAYS if e["tags"]["name"] == "Via Tito Speri" for q in e["geometry"]]
for other, label in (("Corso Vittorio Emanuele", "Varco via Speri / corso Vittorio Emanuele II"), ("Via Giovanni Chiassi", "Varco via Speri / via Chiassi")):
    oth = [q for e in WAYS if e["tags"]["name"] == other for q in e["geometry"]]
    if not oth:
        raise SystemExit(f"Via non trovata in OSM: {other}")
    q = min(speri, key=lambda s: min((s["lat"] - o["lat"]) ** 2 + (s["lon"] - o["lon"]) ** 2 for o in oth))
    gates["B"].append({"id": f"mn-{norm(label).replace(' ', '-')}", "name": label, "location": {"lat": round(q["lat"], 6), "lon": round(q["lon"], 6)}})


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


PENDING = [
    ("Hours confirmed only by accessibilitacentristorici.it: ZTL A and B cameras active every day, 24 hours a day. No official page gives the car hours; an old City regulation (2002, copy on the same site) says the ban applies 0–24 in all ZTLs, and Aster's official goods page lets delivery vans in without a pass only 6–10 am and 3–4:30 pm. The official 7 am–7 pm schedule on Aster's site is the tour-bus ZTL, not the car ZTL.",
     "Orari confermati solo da accessibilitacentristorici.it: telecamere di ZTL A e B attive tutti i giorni 24 ore su 24. Nessuna pagina ufficiale indica gli orari per le auto; un vecchio regolamento del Comune (2002, copia sullo stesso sito) dice divieto 0–24 in tutte le ZTL, e la pagina ufficiale di Aster sulle merci fa entrare i furgoni senza pass solo 6–10 e 15–16:30. La fascia ufficiale 7–19 sul sito di Aster è quella della ZTL per i bus turistici, non per le auto.",
     "Zeiten nur von accessibilitacentristorici.it bestätigt: Kameras der ZTL A und B täglich rund um die Uhr aktiv. Keine offizielle Seite nennt die Zeiten für Autos; eine alte Verordnung der Stadt (2002, Kopie auf derselben Seite) nennt ein Verbot 0–24 in allen ZTL, und Asters offizielle Warenseite lässt Lieferwagen ohne Ausweis nur 6–10 und 15–16:30 Uhr hinein. Die offizielle Zeit 7–19 auf der Aster-Seite gilt für die Reisebus-ZTL, nicht für Autos."),
    ("Corso della Libertà and Via Trieste (gates 10 and 9) are open to everyone 7 am–12 noon and 6–9 pm, confirmed only by accessibilitacentristorici.it; GateLR shows Via Trieste inside the ZTL at all times.",
     "Corso della Libertà e via Trieste (varchi 10 e 9) sono aperti a tutti 7–12 e 18–21, confermato solo da accessibilitacentristorici.it; GateLR mostra via Trieste dentro la ZTL a ogni ora.",
     "Corso della Libertà und Via Trieste (Kameras 10 und 9) sind 7–12 und 18–21 Uhr für alle offen, nur von accessibilitacentristorici.it bestätigt; GateLR zeigt die Via Trieste immer innerhalb der ZTL."),
    ("Visitors can buy an hourly ZTL permit online in Aster's «Area Pass» (register, «Permessi ZTL» → «Prenota/Acquista», pay with PagoPA; Aster advises at least 5 days ahead); price not shown. Hotel guests: the hotel records your plate on a permit for loading and unloading luggage, valid 24 hours, parking at most 60 minutes (confirmed only by accessibilitacentristorici.it, old rules); hotels and the Gazzetta di Mantova mention online registration through Aster.",
     "I visitatori possono comprare un permesso orario ZTL online nell'«Area Pass» di Aster (registrazione, «Permessi ZTL» → «Prenota/Acquista», pagamento PagoPA; Aster consiglia almeno 5 giorni di anticipo); prezzo non indicato. Ospiti degli hotel: l'albergo annota la targa su un permesso per carico e scarico bagagli valido 24 ore, sosta al massimo 60 minuti (confermato solo da accessibilitacentristorici.it, regole vecchie); hotel e Gazzetta di Mantova parlano di registrazione online tramite Aster.",
     "Besucher können online im «Area Pass» von Aster eine stundenweise ZTL-Genehmigung kaufen (registrieren, «Permessi ZTL» → «Prenota/Acquista», Zahlung über PagoPA; Aster empfiehlt mindestens 5 Tage Vorlauf); Preis nicht angegeben. Hotelgäste: Das Hotel trägt dein Kennzeichen auf eine Genehmigung zum Be- und Entladen des Gepäcks ein, 24 Stunden gültig, höchstens 60 Minuten Parken (nur von accessibilitacentristorici.it bestätigt, alte Regeln); Hotels und die Gazzetta di Mantova nennen eine Online-Meldung über Aster."),
    ("Electric cars are not exempt: drivers from other municipalities need a transit-only pass (100 €/year, Aster). Blue Badge holders from other cities book their access with the City (form to infomulte@comune.mantova.it). Pedestrian sub-zones inside ZTL A: Via Roma, Corso Umberto I, Via Grazioli, Piazza Erbe, Piazza Broletto, Via Verdi (bollard).",
     "Le auto elettriche non sono esenti: chi viene da altri comuni ha bisogno di un pass di solo transito (100 € l'anno, Aster). I disabili con contrassegno di altre città prenotano l'accesso presso il Comune (modulo a infomulte@comune.mantova.it). Sottozone pedonali dentro la ZTL A: via Roma, corso Umberto I, via Grazioli, piazza Erbe, piazza Broletto, via Verdi (dissuasore).",
     "Elektroautos sind nicht befreit: Fahrer aus anderen Gemeinden brauchen einen Durchfahrtsausweis (100 € pro Jahr, Aster). Inhaber eines Behindertenausweises aus anderen Städten melden ihre Zufahrt bei der Stadt an (Formular an infomulte@comune.mantova.it). Fußgänger-Teilzonen in der ZTL A: Via Roma, Corso Umberto I, Via Grazioli, Piazza Erbe, Piazza Broletto, Via Verdi (Poller)."),
    ("Areas drawn from the street lists of accessibilitacentristorici.it (ZTL A and U as one zone, ZTL B, ZTL N) applied to OpenStreetMap streets; streets listed only for some house numbers are taken whole, «Commercio», «Martiri», Bertazzolo, Galleria San Maurizio, San Crispino, Canonica, Paradiso and San Paolo are not matched. No official map or street list was found (the regulation D.C.C. 62/2013 is not online). Gates are the 13 cameras in the same list, placed where each named street meets the zone.",
     "Aree ricavate dagli elenchi delle vie di accessibilitacentristorici.it (ZTL A e U come una sola zona, ZTL B, ZTL N) sulle strade di OpenStreetMap; le vie elencate solo per alcuni civici sono prese intere, «Commercio», «Martiri», Bertazzolo, Galleria San Maurizio, San Crispino, Canonica, Paradiso e San Paolo non sono abbinate. Nessuna mappa o elenco ufficiale trovato (il regolamento D.C.C. 62/2013 non è online). I varchi sono le 13 telecamere dello stesso elenco, dove ogni via indicata incontra la zona.",
     "Flächen aus den Straßenlisten von accessibilitacentristorici.it (ZTL A und U als eine Zone, ZTL B, ZTL N) auf OpenStreetMap-Straßen; nur für einige Hausnummern gelistete Straßen sind ganz übernommen, «Commercio», «Martiri», Bertazzolo, Galleria San Maurizio, San Crispino, Canonica, Paradiso und San Paolo nicht zugeordnet. Keine offizielle Karte oder Straßenliste gefunden (die Verordnung D.C.C. 62/2013 ist nicht online). Kameras: die 13 der gleichen Liste, dort, wo jede genannte Straße die Zone trifft."),
]


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


LINKS = [link("Accessibilità Centri Storici: Mantua (unofficial, hours and streets)", "Accessibilità Centri Storici: Mantova (non ufficiale, orari e vie)", "Accessibilità Centri Storici: Mantua (inoffiziell, Zeiten und Straßen)", UNOFFICIAL),
         link("Aster: access to the ZTL (passes)", "Aster: accesso alle ZTL (pass)", "Aster: Zufahrt zur ZTL (Ausweise)", ASTER),
         link("Aster: hourly ZTL permit for visitors", "Aster: permesso orario ZTL per i turisti", "Aster: stundenweise ZTL-Genehmigung für Besucher", ASTER_TOUR),
         link("Aster: goods vehicles in ZTL A and B (6–10, 15–16:30)", "Aster: trasporto merci nelle ZTL A e B (6–10, 15–16:30)", "Aster: Lieferverkehr in ZTL A und B (6–10, 15–16:30)", ASTER_GOODS),
         link("City of Mantua: disabled badge holders from other cities", "Comune di Mantova: pass disabili di altre città", "Stadt Mantua: Behindertenausweise aus anderen Städten", DISABLED),
         link("City of Mantua: ZTL topic", "Comune di Mantova: argomento ZTL", "Stadt Mantua: Thema ZTL", TOPIC)]


def source():
    return {"authority": "Accessibilità Centri Storici (unofficial); Aster / City of Mantua", "official": False,
            "unofficialSource": {"name": "Accessibilità Centri Storici", "url": UNOFFICIAL}, "pageURL": UNOFFICIAL, "quote": QUOTE,
            "quoteTranslation": "The cameras protecting ZTL A and B in Mantua are active every day, 24 hours a day.",
            "quoteTranslation_de": "Die Kameras der ZTL A und B in Mantua sind täglich rund um die Uhr aktiv.",
            "checkedOn": CHECKED, "reviewedByHuman": False,
            "pending": [p[0] for p in PENDING], "pending_it": [p[1] for p in PENDING], "pending_de": [p[2] for p in PENDING], "links": LINKS}


def zone(zid, name, name_it, name_de, s, s_it, s_de, shape, gate_list):
    return {"id": zid, "name": name, "name_it": name_it, "name_de": name_de, "kind": "restricted",
            "summary": s, "summary_it": s_it, "summary_de": s_de, "perimeter": shape, "gates": gate_list,
            "windows": [{"weekdays": EVERY_DAY, "start": 0, "end": 24 * 60}],
            "freeOnHolidays": False, "holidaysAsSunday": False, "exemptFuels": [], "hotelCanRegister": True, "source": source()}


zones = [zone("mantova-ztl-a", "Historic centre · ZTL A", "Centro storico · ZTL A", "Altstadt · ZTL A",
              "Mantua's historic centre (Piazza delle Erbe, Sant'Andrea, Piazza Sordello and the Ducal Palace area) is ZTL A, reportedly camera-controlled every day, 24 hours a day. Without a permit stay out: park outside (e.g. Campo Canoa, Piazza Virgiliana) and walk. Staying inside? Ask your hotel to register your plate; visitors can buy an hourly permit online from Aster.",
              "Il centro storico di Mantova (piazza delle Erbe, Sant'Andrea, piazza Sordello e la zona di Palazzo Ducale) è la ZTL A, con telecamere attive secondo le guide tutti i giorni 24 ore su 24. Senza permesso non entrare: parcheggia fuori (es. Campo Canoa, piazza Virgiliana) e cammina. Dormi dentro? Chiedi all'hotel di registrare la targa; i visitatori possono comprare un permesso orario online da Aster.",
              "Die Altstadt von Mantua (Piazza delle Erbe, Sant'Andrea, Piazza Sordello und das Gebiet des Herzogspalasts) ist die ZTL A, laut Reiseführern täglich rund um die Uhr kameraüberwacht. Ohne Genehmigung draußen bleiben: außerhalb parken (z. B. Campo Canoa, Piazza Virgiliana) und laufen. Du übernachtest innen? Bitte das Hotel, dein Kennzeichen zu melden; Besucher können online bei Aster eine stundenweise Genehmigung kaufen.",
              shape_a, gates["A"]),
         zone("mantova-ztl-b", "Via Carducci and Via Speri · ZTL B", "Via Carducci e via Speri · ZTL B", "Via Carducci und Via Speri · ZTL B",
              "ZTL B covers the streets west of Corso della Libertà around Via Carducci, Via Tito Speri and Via Frutta, reportedly camera-controlled every day, 24 hours a day. Without a permit stay out.",
              "La ZTL B comprende le vie a ovest di corso della Libertà intorno a via Carducci, via Tito Speri e via Frutta, con telecamere attive secondo le guide tutti i giorni 24 ore su 24. Senza permesso non entrare.",
              "Die ZTL B umfasst die Straßen westlich des Corso della Libertà um Via Carducci, Via Tito Speri und Via Frutta, laut Reiseführern täglich rund um die Uhr kameraüberwacht. Ohne Genehmigung draußen bleiben.",
              shape_b, gates["B"]),
         zone("mantova-ztl-n", "San Leonardo · ZTL N", "San Leonardo · ZTL N", "San Leonardo · ZTL N",
              "ZTL N is the small quarter around Piazza San Leonardo and Via Cavriani, north-west of the centre, reportedly camera-controlled every day, 24 hours a day. Without a permit stay out.",
              "La ZTL N è il piccolo quartiere intorno a piazza San Leonardo e via Cavriani, a nord-ovest del centro, con telecamere attive secondo le guide tutti i giorni 24 ore su 24. Senza permesso non entrare.",
              "Die ZTL N ist das kleine Viertel um die Piazza San Leonardo und die Via Cavriani nordwestlich des Zentrums, laut Reiseführern täglich rund um die Uhr kameraüberwacht. Ohne Genehmigung draußen bleiben.",
              shape_n, gates["N"])]

city = {"id": "mantova", "name": "Mantua", "name_it": "Mantova", "name_de": "Mantua",
        "center": {"lat": 45.1597, "lon": 10.7967}, "zones": zones, "status": "draft",
        "license": "Hours and streets: accessibilitacentristorici.it (unofficial). Permits: Aster (City of Mantua company). Areas and gates: " + osm_geo.ODBL + " (approximate, not official)."}

# Pubblicabile come città con fonte non ufficiale (app 1.16.2, manifest «unofficialCities»)
ready = all(len(z["perimeter"]) >= 5 and z["source"]["quote"] for z in city["zones"])
out = ROOT / ("Resources/Cities/mantova.json" if ready else "data/drafts/mantova.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/mantova.json" if ready else "Resources/Cities/mantova.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), [(z["id"], len(z["perimeter"]), len(z["gates"])) for z in zones], f"{area_a:.3f} + {area_b:.3f} + {area_n:.3f} km²", "non abbinate:", MISSING)
