#!/usr/bin/env python3
# Costruisce la scheda di Perugia dalle pagine e dagli atti ufficiali del Comune salvati in data/raw/perugia/
# (testo estratto, con URL e data di lettura in testa a ogni file; fonti e date in docs/fonti-perugia.md).
#
# Orari: pagina ufficiale «ZTL Zone a Traffico Limitato» del Comune (aggiornata il 09/11/2024). Regole dei permessi:
# Regolamento permessi ZTL e settori esterni (DCC 82/2012, ultima modifica DCC 133 del 20/07/2026) e delibera GC 283/2025.
#
# Geometria (mai disegnata a mano): il Comune non pubblica né dati aperti né una mappa con coordinate, e OpenStreetMap non
# ha la ZTL di Perugia. L'unico elenco ufficiale è quello degli ACCESSI (i varchi) di ogni zona. Il perimetro si ricava
# così, dalle strade OSM in data/raw/geo/perugia-centro-strade.json (API OSM, © OpenStreetMap contributors, ODbL 1.0):
#   1. grafo delle strade carrabili, con i sensi unici;
#   2. le strade d'accesso ufficiali di una zona (es. «via Fanti», «via Baglioni»…) sono chiuse a chi arriva da fuori;
#   3. si parte da tutti i nodi lontani dal centro e si segue la rete: le strade che NON si raggiungono senza passare da un
#      accesso ufficiale sono la zona (più le strade d'accesso stesse e le vie pedonali attaccate, come Corso Vannucci);
#   4. osm_geo.street_area disegna l'area coperta da quelle strade.
# Le zone di una sola strada (via del Roscetto, Corso Bersaglieri, via Bontempi) sono l'area della strada stessa.
# Il varco è il primo nodo (nel senso di marcia) della strada d'accesso raggiungibile da fuori.
# Il bordo è quindi approssimato (qualche decina di metri) ed è scritto nei «pending».
#
# Uso: python3 Tools/build_perugia.py   (non tocca le altre città né manifest.json)
import collections, json, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/perugia"
OSM_FILE = ROOT / "data/raw/geo/perugia-centro-strade.json"
CHECKED = "2026-10-26T09:00:00Z"
AUTHORITY = "City of Perugia"

SUN, MON_FRI, MON_SAT, SAT_SUN, EVERY_DAY = [1], [2, 3, 4, 5, 6], [2, 3, 4, 5, 6, 7], [7, 1], [1, 2, 3, 4, 5, 6, 7]


def norm(s):
    return re.sub(r"\s+", " ", s).strip()


TEXT = {p.stem: norm(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def check(file, *quotes):
    """Ogni frase citata o riassunta deve comparire, parola per parola, nel testo salvato"""
    for q in quotes:
        if norm(q) not in TEXT[file]:
            raise SystemExit(f"{file}: frase non trovata, ricontrollare la pagina: {q!r}")


def url_of(file):
    return TEXT[file].split(" ", 2)[1]


def hm(h, m=0):
    return h * 60 + m


def window(days, start, end):
    return {"weekdays": days, "start": start, "end": end}


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


ZTL_PAGE = "comune-luogo-ztl-zone-a-traffico-limitato"
RULES = "regolamento-permessi-ztl-dcc-133-2026"
DG283 = "delibera-gc-283-2025-pagamento-permessi"
DISABLED = "comune-servizio-ztl-accesso-giornaliero-disabili"
HOTEL_FORM = "comune-documento-34-domanda-permessi-alberghi"
PERMANENT = "comune-servizio-ztl-permesso-permanente"
MINI_2024 = "nonufficiale-umbriajournal-mini-ztl-2024"
DAILY = "comune-pagine-ztl-permesso-giornaliero-temporaneo"
MINIMETRO = "minimetro-home"

# Le frasi su cui si basa la scheda
check(ZTL_PAGE, "Pagina aggiornata il 09/11/2024",
      "Centro Storico accessi di via Fanti, via del Parione, Via Bonazzi, Via Baglioni, via della Sposa, via Battisti, via San Sebastiano, via Appia, via Solitaria, via Campo Battaglia",
      "I titolari di permesso possono accedere in qualsiasi orario.")
check(RULES, "Modificato con Deliberazione del Consiglio Comunale n. 133 del 20.07.2026",
      "I veicoli diretti agli alberghi ubicati all’interno della Z.T.L sono autorizzati a transitare senza rilascio di permesso. Quotidianamente ogni albergo ubicato nella Z.T.L. deve trasmettere, con le modalità specificate dall’Amministrazione Comunale, l’elenco delle targhe dei propri clienti all’Ufficio preposto.",
      "e comunque non oltre 60 minuti",
      "Alle auto ed ai ciclomotori a propulsione elettrica, sono rilasciati permessi di transito e sosta per ogni veicolo, validi 24/24h.",
      "improrogabilmente, entro 72 ore dallo stesso",
      "improrogabilmente entro 72 ore dal passaggio")
check(DG283, "da € 2,00 per i veicoli stranieri a 10,00 €;")
check(DISABLED, "entro 72 ore dall'accesso")
check(DAILY, "Pagina aggiornata il 21/10/2026", "Durata massima 15 giorni consecutivi", "taxi e NCC che non sono di Perugia",
      "I permessi giornalieri per l'accesso alla ZTL possono essere richiesti on line")
check(MINIMETRO, "Parcheggia gratuitamente a Pian di Massiano")
check(HOTEL_FORM, "Richiesta di autorizzazioni al transito e alla sosta nella Z.T.L. e settori limitrofi effettuata dalle strutture ricettive per i propri clienti")
check(MINI_2024, "ordinanza della Struttura organizzativa Sicurezza (n. 297 del 2 marzo 2024)",
      "ZTL 2 – In via Bontempi e nelle vie interne ad essa altra zona a traffico limitato con divieto di transito e sosta h24, controllata da un varco elettronico posto tra via Bontempi e piazza Piccinino.")

LINKS = [link("City of Perugia: ZTL zones and hours", "Comune di Perugia: ZTL, zone e orari", "Stadt Perugia: ZTL-Zonen und Zeiten",
              url_of(ZTL_PAGE)),
         link("City of Perugia: ZTL permit rules (amended July 2026, PDF)", "Comune di Perugia: Regolamento permessi ZTL (modificato a luglio 2026, PDF)",
              "Stadt Perugia: Regeln für ZTL-Genehmigungen (geändert im Juli 2026, PDF)", url_of(RULES)),
         link("City of Perugia: daily or temporary permits (who may apply, online)", "Comune di Perugia: permessi giornalieri o temporanei (chi può chiederli, online)",
              "Stadt Perugia: Tages- oder befristete Genehmigungen (wer sie beantragen kann, online)", url_of(DAILY)),
         link("Minimetrò: free car park at Pian di Massiano and timetable", "Minimetrò: parcheggio gratuito a Pian di Massiano e orari",
              "Minimetrò: kostenloser Parkplatz Pian di Massiano und Fahrplan", url_of(MINIMETRO)),
         link("City of Perugia: hotels, form to request access for guests", "Comune di Perugia: modulo 34, permessi per alberghi",
              "Stadt Perugia: Hotels, Antrag auf Zufahrt für Gäste", url_of(HOTEL_FORM)),
         link("City of Perugia: disabled badge holders, register the entry (72 hours)",
              "Comune di Perugia: titolari di contrassegno disabili, comunicazione dell'accesso (72 ore)",
              "Stadt Perugia: Behindertenausweis, Einfahrt melden (72 Stunden)", url_of(DISABLED)),
         link("City of Perugia: daily permit prices (Council decision 283/2025, PDF)",
              "Comune di Perugia: tariffe dei permessi giornalieri (delibera GC 283/2025, PDF)",
              "Stadt Perugia: Preise der Tagesgenehmigungen (Beschluss 283/2025, PDF)", url_of(DG283))]
OSM_LINK = link("OpenStreetMap: streets used to draw the zones (ODbL)", "OpenStreetMap: strade usate per disegnare le zone (ODbL)",
                "OpenStreetMap: für die Zonen verwendete Straßen (ODbL)", "https://www.openstreetmap.org/#map=16/43.1115/12.3890")

COMMON_PENDING = [
    ("Map outline not official: the City publishes only the list of entry gates. GateLR draws each zone from the streets you can't reach without passing one of those gates (OpenStreetMap streets), so the edge is approximate.",
     "Perimetro non ufficiale: il Comune pubblica solo l'elenco degli accessi. GateLR disegna ogni zona dalle strade che non si raggiungono senza passare da uno di quegli accessi (strade di OpenStreetMap), quindi il bordo è approssimato.",
     "Grenze nicht offiziell: Die Stadt veröffentlicht nur die Liste der Zufahrten. GateLR zeichnet jede Zone aus den Straßen, die man nur über eine dieser Zufahrten erreicht (Straßen aus OpenStreetMap), der Rand ist daher ungefähr."),
    ("Hotels: cars going to a hotel inside the ZTL may enter without a permit, but the hotel must send the plate to the City every day (Regulation art. 25). Ask the hotel to confirm it has registered yours. Parking only to unload luggage, max 60 minutes.",
     "Alberghi: le auto dirette a un albergo dentro la ZTL possono entrare senza permesso, ma l'albergo deve trasmettere ogni giorno la targa al Comune (Regolamento, art. 25). Chiedi all'hotel conferma che abbia registrato la tua. Sosta solo per scaricare i bagagli, massimo 60 minuti.",
     "Hotels: Autos zu einem Hotel in der ZTL dürfen ohne Genehmigung einfahren, das Hotel muss das Kennzeichen aber täglich an die Stadt melden (Regelung, Art. 25). Lass dir vom Hotel bestätigen, dass es deines gemeldet hat. Parken nur zum Ausladen, höchstens 60 Minuten."),
    ("Electric cars are not exempt automatically: they need a permit valid 24 hours (art. 31). A disabled badge holder on board must register the plate before entering or within 72 hours.",
     "Le auto elettriche non sono esenti in automatico: serve un permesso valido 24 ore su 24 (art. 31). Con a bordo il titolare di un contrassegno disabili, la targa va comunicata prima di entrare o entro 72 ore.",
     "Elektroautos sind nicht automatisch befreit: Sie brauchen eine Genehmigung, gültig rund um die Uhr (Art. 31). Mit einem Inhaber eines Behindertenausweises an Bord muss das Kennzeichen vor der Einfahrt oder innerhalb von 72 Stunden gemeldet werden."),
    ("No tourist ticket: daily permits (2–12 €, foreign vehicles 10 €, bought online) are only for the categories listed by the City (e.g. disabled badge, taxis from other towns, weddings). Not confirmed whether the patron saint's day (San Costanzo, 29 January) counts as a holiday for the ZTL: GateLR treats it as a normal day.",
     "Nessun ticket per turisti: i permessi giornalieri (2–12 €, veicoli stranieri 10 €, online) valgono solo per le categorie indicate dal Comune (es. contrassegno disabili, taxi di altri comuni, matrimoni). Non è confermato se la festa del patrono (San Costanzo, 29 gennaio) conti come festivo per la ZTL: GateLR la tratta come un giorno normale.",
     "Kein Touristenticket: Tagesgenehmigungen (2–12 €, ausländische Fahrzeuge 10 €, online) gibt es nur für die von der Stadt genannten Gruppen (z. B. Behindertenausweis, Taxis aus anderen Orten, Hochzeiten). Ob der Tag des Stadtpatrons (San Costanzo, 29. Januar) für die ZTL als Feiertag gilt, ist nicht bestätigt: GateLR behandelt ihn als normalen Tag."),
]


# --- geometria: strade OSM e accessi ufficiali ---

DRIVE = {"motorway", "trunk", "primary", "secondary", "tertiary", "unclassified", "residential", "living_street", "service",
         "trunk_link", "primary_link", "secondary_link", "tertiary_link", "road"}
PED = {"pedestrian", "living_street", "footway", "steps"}
ELEMENTS = json.loads(OSM_FILE.read_text(encoding="utf-8"))["elements"]
NODE = {e["id"]: (e["lat"], e["lon"]) for e in ELEMENTS if e["type"] == "node"}
WAYS = [e for e in ELEMENTS if e["type"] == "way"]
DRIVABLE = [w for w in WAYS if w["tags"].get("highway") in DRIVE and w["tags"].get("area") != "yes"
            and w["tags"].get("access") not in ("no", "private") and w["tags"].get("motor_vehicle") not in ("no", "private")]
# I nodi «da fuori»: tutto ciò che sta lontano dal centro storico
CORE = (43.1035, 43.1205, 12.3815, 12.3985)


def is_gate_way(w, words):
    name = w["tags"].get("name", "").lower()
    return any(x in name for x in words)


def unreachable(words):
    """Le strade carrabili che da fuori non si raggiungono senza passare da una strada d'accesso (words)"""
    adj = collections.defaultdict(set)
    for w in DRIVABLE:
        if is_gate_way(w, words):
            continue
        ow, ns = w["tags"].get("oneway"), w["nodes"]
        for a, b in zip(ns, ns[1:]):
            if ow in ("yes", "1", "true"):
                adj[a].add(b)
            elif ow == "-1":
                adj[b].add(a)
            else:
                adj[a].add(b); adj[b].add(a)
    nodes = {n for w in DRIVABLE for n in w["nodes"] if n in NODE}
    seen = {n for n in nodes if not (CORE[0] < NODE[n][0] < CORE[1] and CORE[2] < NODE[n][1] < CORE[3])}
    todo = list(seen)
    while todo:
        for y in adj[todo.pop()]:
            if y not in seen:
                seen.add(y); todo.append(y)
    inside = [w for w in DRIVABLE if not is_gate_way(w, words)
              and not any(n in seen for n in w["nodes"][1:-1]) and any(n not in seen for n in w["nodes"])]
    return seen, inside


def geom(w):
    return [{"lat": NODE[n][0], "lon": NODE[n][1]} for n in w["nodes"] if n in NODE]


def area(ways, tol_m=6, **kw):
    rel = {"id": 0, "members": [{"type": "way", "role": "section", "geometry": geom(w)} for w in ways]}
    return osm_geo.perimeter(osm_geo.street_area(rel, **kw), tol_m=tol_m)


def gate_points(words, seen, prefix, labels):
    """Per ogni accesso: il primo nodo (nel senso di marcia) della strada d'accesso che si raggiunge da fuori"""
    out = []
    for word, label in zip(words, labels):
        ws = [w for w in DRIVABLE if is_gate_way(w, [word])]
        cands = []
        for w in ws:
            ns = w["nodes"] if w["tags"].get("oneway") != "-1" else w["nodes"][::-1]
            ends = [ns[0]] if w["tags"].get("oneway") in ("yes", "1", "true", "-1") else [ns[0], ns[-1]]
            cands += [n for n in ends if n in seen and n in NODE]
        if not cands:
            raise SystemExit(f"Nessun punto d'accesso trovato per {word!r}")
        n = cands[0]
        out.append({"id": f"{prefix}-osm{n}", "name": label, "location": {"lat": round(NODE[n][0], 6), "lon": round(NODE[n][1], 6)}})
    return out


def street_zone(word, prefix, label, close_m=15):
    ws = [w for w in DRIVABLE if is_gate_way(w, [word])]
    if not ws:
        raise SystemExit(f"Strada {word!r} non trovata nei dati OSM")
    seen, _ = unreachable([word])
    return area(ws, tol_m=2, cell_m=8, close_m=close_m), gate_points([word], seen, prefix, [label])


# Centro storico: i dieci accessi della pagina ufficiale
MAIN_WORDS = ["fanti", "parione", "bonazzi", "baglioni", "della sposa", "battisti", "san sebastiano", "appia", "solitaria", "campo di battaglia"]
MAIN_LABELS = ["Via Fanti", "Via del Parione", "Via Bonazzi", "Via Baglioni", "Via della Sposa", "Via Battisti", "Via San Sebastiano",
               "Via Appia", "Via Solitaria", "Via Campo Battaglia"]
seen, inside = unreachable(MAIN_WORDS)
in_nodes = {n for w in inside for n in w["nodes"] if n not in seen}
main_ways = inside + [w for w in DRIVABLE if is_gate_way(w, MAIN_WORDS)] + \
            [w for w in WAYS if w["tags"].get("highway") in PED and any(n in in_nodes for n in w["nodes"])]
main_shape = area(main_ways, close_m=60)
main_gates = gate_points(MAIN_WORDS, seen, "pg", MAIN_LABELS)

seen_g, inside_g = unreachable(["garibaldi"])
in_g = {n for w in inside_g for n in w["nodes"] if n not in seen_g}
gar_ways = [w for w in inside_g if any(43.1150 < NODE[n][0] for n in w["nodes"] if n in NODE)] + \
           [w for w in DRIVABLE if is_gate_way(w, ["garibaldi"])]
gar_shape = area(gar_ways, close_m=40)
gar_gates = gate_points(["garibaldi"], seen_g, "pg", ["Corso Garibaldi"])

ros_shape, ros_gates = street_zone("roscetto", "pg", "Via del Roscetto")
ber_shape, ber_gates = street_zone("bersaglieri", "pg", "Corso Bersaglieri")
bon_shape, bon_gates = street_zone("bontempi", "pg", "Via Bontempi / Piazza Piccinino", close_m=40)


def source(quote, translation, extra_pending=(), ordinance=None):
    check(ZTL_PAGE, quote)
    pending = list(extra_pending) + COMMON_PENDING
    return {"authority": AUTHORITY, "pageURL": url_of(ZTL_PAGE),
            "ordinance": ordinance or "Regolamento permessi ZTL e settori esterni (DCC 82/2012, modificato con DCC 133 del 20/07/2026)",
            "ordinanceURL": url_of(RULES),
            "quote": quote, "quoteTranslation": translation[0], "quoteTranslation_de": translation[1],
            "checkedOn": CHECKED, "reviewedByHuman": False,
            "pending": [p[0] for p in pending], "pending_it": [p[1] for p in pending], "pending_de": [p[2] for p in pending],
            "links": LINKS + [OSM_LINK]}


SATURDAY_NOTE = ("The City's page splits this zone's hours into weekdays («feriali») and holidays («festivi»); GateLR treats Saturday as a weekday, as usual in Italy. To be confirmed with the City.",
                 "La pagina del Comune divide gli orari di questa zona in «giorni feriali» e «festivi»; GateLR tratta il sabato come feriale, come d'uso. Da confermare con il Comune.",
                 "Die Seite der Stadt teilt die Zeiten dieser Zone in Werktage («feriali») und Feiertage («festivi»); GateLR behandelt den Samstag wie üblich als Werktag. Mit der Stadt zu klären.")

zones = [
    {"id": "perugia-centro-storico",
     "name": "Acropolis · Historic centre", "name_it": "Acropoli · Centro storico", "name_de": "Akropolis · Altstadt",
     "summary": "The hilltop centre (Corso Vannucci, Piazza IV Novembre) is closed to unauthorised vehicles from midnight to 1 pm Monday to Friday, and from midnight to 7 am on Saturdays, Sundays and holidays. In the afternoon and evening you may drive in. There is no tourist ticket: park below (Piazza Partigiani, escalators) or take the Minimetrò. Hotels inside register your plate.",
     "summary_it": "Il centro in cima al colle (Corso Vannucci, Piazza IV Novembre) è chiuso ai veicoli non autorizzati da mezzanotte alle 13 dal lunedì al venerdì, e da mezzanotte alle 7 il sabato, la domenica e i festivi. Di pomeriggio e di sera si entra. Non c'è un ticket per turisti: parcheggia sotto (Piazza Partigiani, scale mobili) o prendi il Minimetrò. Gli hotel dentro registrano la tua targa.",
     "summary_de": "Die Altstadt auf dem Hügel (Corso Vannucci, Piazza IV Novembre) ist für nicht berechtigte Fahrzeuge Montag bis Freitag von Mitternacht bis 13 Uhr gesperrt, samstags, sonntags und an Feiertagen von Mitternacht bis 7 Uhr. Nachmittags und abends darf man hinein. Ein Touristenticket gibt es nicht: unten parken (Piazza Partigiani, Rolltreppen) oder den Minimetrò nehmen. Hotels in der Zone melden dein Kennzeichen.",
     "perimeter": main_shape, "gates": main_gates,
     "windows": [window(MON_FRI, 0, hm(13)), window(SAT_SUN, 0, hm(7))],
     "source": source("Dal lunedì al venerdì – accesso consentito dalle 13.00 alle 24.00 – accesso vietato dalle 00.00 alle 13.00 Sabato e festivi – accesso consentito dalle 7.00 alle 24.00 – accesso vietato dalle 00.00 alle 7.00",
                      ("Monday to Friday – entry allowed 13:00–24:00 – entry forbidden 00:00–13:00. Saturday and holidays – entry allowed 7:00–24:00 – entry forbidden 00:00–7:00",
                       "Montag bis Freitag – Einfahrt erlaubt 13–24 Uhr – verboten 0–13 Uhr. Samstag und Feiertage – Einfahrt erlaubt 7–24 Uhr – verboten 0–7 Uhr"),
                      [("Inside this zone some streets are closed 24 hours a day even in the afternoon: Via dei Priori between Via della Stella and Piazzetta Santo Stefano (pedestrian area, camera) and Via Bontempi. Viale Indipendenza (Via Masi–Corso Cavour) and Corso Cavour up to Via XIV Settembre are also closed 24 hours. Only Via Bontempi is drawn on the map.",
                        "Dentro questa zona alcune vie sono chiuse 24 ore su 24 anche di pomeriggio: via dei Priori tra via della Stella e Piazzetta Santo Stefano (area pedonale, telecamera) e via Bontempi. Sono chiusi h24 anche viale Indipendenza (via Masi–Corso Cavour) e Corso Cavour fino a via XIV Settembre. Sulla mappa è disegnata solo via Bontempi.",
                        "Innerhalb dieser Zone sind manche Straßen auch nachmittags rund um die Uhr gesperrt: Via dei Priori zwischen Via della Stella und Piazzetta Santo Stefano (Fußgängerzone, Kamera) und Via Bontempi. Auch Viale Indipendenza (Via Masi–Corso Cavour) und Corso Cavour bis Via XIV Settembre sind rund um die Uhr gesperrt. Nur Via Bontempi ist auf der Karte eingezeichnet."),
                       ("Piazza Italia is drawn inside the zone, but an older guide says the way from Via Masi to Piazza Italia is free 24 hours. To be checked.",
                        "Piazza Italia è disegnata dentro la zona, ma una guida meno recente dice che il percorso da via Masi a Piazza Italia è libero h24. Da verificare.",
                        "Die Piazza Italia ist innerhalb der Zone eingezeichnet, ein älterer Ratgeber sagt aber, dass der Weg von Via Masi zur Piazza Italia rund um die Uhr frei ist. Zu prüfen.")])},
    {"id": "perugia-corso-garibaldi",
     "name": "Corso Garibaldi · Borgo Sant'Angelo", "name_it": "Corso Garibaldi · Borgo Sant'Angelo", "name_de": "Corso Garibaldi · Borgo Sant'Angelo",
     "summary": "Corso Garibaldi and the streets around it are closed to unauthorised vehicles from midnight to 1 pm on weekdays and from midnight to 7 am on Sundays and holidays. In the afternoon and evening you may drive in.",
     "summary_it": "Corso Garibaldi e le vie intorno sono chiusi ai veicoli non autorizzati da mezzanotte alle 13 nei giorni feriali e da mezzanotte alle 7 la domenica e i festivi. Di pomeriggio e di sera si entra.",
     "summary_de": "Corso Garibaldi und die Straßen ringsum sind für nicht berechtigte Fahrzeuge werktags von Mitternacht bis 13 Uhr gesperrt, sonntags und an Feiertagen von Mitternacht bis 7 Uhr. Nachmittags und abends darf man hinein.",
     "perimeter": gar_shape, "gates": gar_gates,
     "windows": [window(MON_SAT, 0, hm(13)), window(SUN, 0, hm(7))],
     "source": source("Corso Garibaldi: Giorni Ferial i – accesso consentito dalle 13.00 alle 24.00 – accesso vietato dalle 00.00 alle 13.00 Giorni Festivi – accesso consentito dalle 7.00 alle 24.00 – accesso vietato dalle 00.00 alle 7.00",
                      ("Corso Garibaldi: weekdays – entry allowed 13:00–24:00 – entry forbidden 00:00–13:00. Holidays – entry allowed 7:00–24:00 – entry forbidden 00:00–7:00",
                       "Corso Garibaldi: werktags – Einfahrt erlaubt 13–24 Uhr – verboten 0–13 Uhr. Feiertage – Einfahrt erlaubt 7–24 Uhr – verboten 0–7 Uhr"), [SATURDAY_NOTE])},
    {"id": "perugia-via-del-roscetto",
     "name": "Via del Roscetto · evening access only", "name_it": "Via del Roscetto · accesso solo 16–20", "name_de": "Via del Roscetto · Zufahrt nur 16–20 Uhr",
     "summary": "Via del Roscetto is open to traffic only from 4 pm to 8 pm, every day. From 8 pm to 4 pm the next day it is closed to unauthorised vehicles.",
     "summary_it": "Via del Roscetto è aperta al traffico solo dalle 16 alle 20, tutti i giorni. Dalle 20 alle 16 del giorno dopo è chiusa ai veicoli non autorizzati.",
     "summary_de": "Die Via del Roscetto ist nur von 16 bis 20 Uhr befahrbar, jeden Tag. Von 20 Uhr bis 16 Uhr am nächsten Tag ist sie für nicht berechtigte Fahrzeuge gesperrt.",
     "perimeter": ros_shape, "gates": ros_gates,
     "windows": [window(EVERY_DAY, hm(20), hm(16))],
     "source": source("Via del Roscetto: tutti i giorni – accesso consentito dalle 16.00 alle 20.00 – accesso vietato dalle 20.00 alle 16.00 del giorno successivo",
                      ("Via del Roscetto: every day – entry allowed 16:00–20:00 – entry forbidden from 20:00 to 16:00 the next day",
                       "Via del Roscetto: täglich – Einfahrt erlaubt 16–20 Uhr – verboten von 20 Uhr bis 16 Uhr am Folgetag"))},
    {"id": "perugia-corso-bersaglieri",
     "name": "Corso Bersaglieri · Borgo Sant'Antonio", "name_it": "Corso Bersaglieri · Borgo Sant'Antonio", "name_de": "Corso Bersaglieri · Borgo Sant'Antonio",
     "summary": "Corso Bersaglieri is closed to unauthorised vehicles from 2 pm to 9 pm on weekdays and all day on Sundays and holidays.",
     "summary_it": "Corso Bersaglieri è chiuso ai veicoli non autorizzati dalle 14 alle 21 nei giorni feriali e tutto il giorno la domenica e i festivi.",
     "summary_de": "Der Corso Bersaglieri ist für nicht berechtigte Fahrzeuge werktags von 14 bis 21 Uhr gesperrt, sonntags und an Feiertagen den ganzen Tag.",
     "perimeter": ber_shape, "gates": ber_gates,
     "windows": [window(MON_SAT, hm(14), hm(21)), window(SUN, 0, hm(24))],
     "source": source("Corso Bersaglieri Giorni Feriali – accesso consentito dalle 21.00 alle 14.00 del giorno successivo – accesso vietato dalle 14.00 alle 21.00 Giorni Festivi – accesso vietato dalle 00.00 alle 24.00",
                      ("Corso Bersaglieri. Weekdays – entry allowed from 21:00 to 14:00 the next day – entry forbidden 14:00–21:00. Holidays – entry forbidden 00:00–24:00",
                       "Corso Bersaglieri. Werktags – Einfahrt erlaubt von 21 bis 14 Uhr am Folgetag – verboten 14–21 Uhr. Feiertage – verboten 0–24 Uhr"), [SATURDAY_NOTE])},
    {"id": "perugia-via-bontempi",
     "name": "Via Bontempi · residents only, 24 h", "name_it": "Via Bontempi · solo residenti, h24", "name_de": "Via Bontempi · nur Anwohner, 24 h",
     "summary": "Via Bontempi and the streets off it are closed to traffic and parking 24 hours a day, every day (camera at Piazza Piccinino). Only residents with their permit, loading vehicles with authorisation (weekdays 7–10 am) and emergency or disabled-badge vehicles may enter.",
     "summary_it": "Via Bontempi e le vie interne sono chiuse a transito e sosta 24 ore su 24, tutti i giorni (telecamera in Piazza Piccinino). Entrano solo i residenti con il loro permesso, il carico e scarico autorizzato (feriali 7–10) e i mezzi di soccorso o con contrassegno disabili.",
     "summary_de": "Via Bontempi und die Nebenstraßen sind rund um die Uhr, jeden Tag für Verkehr und Parken gesperrt (Kamera an der Piazza Piccinino). Nur Anwohner mit Genehmigung, Lieferverkehr mit Erlaubnis (werktags 7–10 Uhr) sowie Rettungs- und Fahrzeuge mit Behindertenausweis.",
     "perimeter": bon_shape, "gates": bon_gates,
     "windows": [window(EVERY_DAY, 0, hm(24))],
     "source": source("Via Bontempi e vie interne ad essa tutti i giorni divieto di transito e sosta dalle 00,00 alle 24,00",
                      ("Via Bontempi and the streets off it: every day, no driving or parking from 00:00 to 24:00",
                       "Via Bontempi und die Nebenstraßen: täglich Fahr- und Parkverbot von 0 bis 24 Uhr"),
                      [("Exemptions (residents of Via Bontempi, loading weekdays 7–10 am with authorisation, emergency services, disabled badge) are from the City's March 2024 press release on order no. 297/2024, read in a local newspaper. The side streets are not listed: only Via Bontempi is drawn.",
                        "Le deroghe (residenti di via Bontempi, carico e scarico feriali 7–10 con autorizzazione, soccorso, contrassegno disabili) vengono dal comunicato del Comune di marzo 2024 sull'ordinanza n. 297/2024, letto su un giornale locale. Le vie interne non sono elencate: è disegnata solo via Bontempi.",
                        "Die Ausnahmen (Anwohner der Via Bontempi, Lieferverkehr werktags 7–10 Uhr mit Erlaubnis, Rettungsdienste, Behindertenausweis) stammen aus der Pressemitteilung der Stadt vom März 2024 zur Anordnung Nr. 297/2024, gelesen in einer Lokalzeitung. Die Nebenstraßen sind nicht aufgelistet: nur die Via Bontempi ist eingezeichnet.")],
                      ordinance="Ordinanza S.O. Sicurezza n. 297 del 02/03/2024 (mini ZTL, varchi elettronici dall'11/04/2024)")},
]
for z in zones:
    z.update({"kind": "restricted", "freeOnHolidays": False, "holidaysAsSunday": True, "exemptFuels": [],
              "hotelCanRegister": z["id"] != "perugia-via-bontempi"})
    # ordine dei campi come nelle altre città
    for k in ("perimeter", "gates", "windows", "freeOnHolidays", "holidaysAsSunday", "exemptFuels", "hotelCanRegister", "source"):
        z[k] = z.pop(k)
    print(f"{z['id']:28s} {len(z['perimeter']):4d} punti {osm_geo.area_km2(z['perimeter']):.4f} km²  varchi: {[g['name'] for g in z['gates']]}")

# Controlli di plausibilità: un luogo famoso dentro, la stazione fuori
by_id = {z["id"]: z for z in zones}
INSIDE = {"perugia-centro-storico": [("Piazza IV Novembre / Fontana Maggiore", 43.1122, 12.3888), ("Corso Vannucci", 43.1106, 12.3891),
                                     ("San Francesco al Prato", 43.1124, 12.3836)],
          "perugia-corso-garibaldi": [("Corso Garibaldi", 43.1175, 12.3875)]}
STATION = ("Perugia Fontivegge", 43.1050, 12.3726)
for zid, pts in INSIDE.items():
    for n, lat, lon in pts:
        assert osm_geo.contains(by_id[zid]["perimeter"], lat, lon), f"{zid}: {n} non è dentro il perimetro"
for z in zones:
    assert not osm_geo.contains(z["perimeter"], STATION[1], STATION[2]), f"{z['id']}: la stazione risulta dentro"
    assert z["gates"], z["id"]
assert 0.25 < osm_geo.area_km2(by_id["perugia-centro-storico"]["perimeter"]) < 0.8
assert not osm_geo.contains(by_id["perugia-centro-storico"]["perimeter"], 43.1175, 12.3875), "Corso Garibaldi dentro l'acropoli"

city = {"id": "perugia", "name": "Perugia", "name_it": "Perugia", "name_de": "Perugia",
        "center": {"lat": 43.1122, "lon": 12.3888}, "zones": zones, "status": "draft",
        "license": "Rules: Comune di Perugia official pages and documents. Perimeters and gates: derived from the official list of entry gates "
                   "with street data " + osm_geo.ODBL + " (approximate, not official)."}

ready = all(len(z["perimeter"]) >= 5 for z in zones)
out = ROOT / ("Resources/Cities/perugia.json" if ready else "data/drafts/perugia.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/perugia.json" if ready else "Resources/Cities/perugia.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), len(zones), "zone")
