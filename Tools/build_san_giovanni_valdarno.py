#!/usr/bin/env python3
# Costruisce Resources/Cities/san-giovanni-valdarno.json dalle pagine e dagli atti ufficiali del Comune di
# San Giovanni Valdarno salvati in data/raw/san-giovanni-valdarno/ (fonti e date in docs/fonti-san-giovanni-valdarno.md).
# Orari: pagina «Mappa ZTL» e schede dei permessi (Polizia Locale, aggiornate il 21/11/2025).
# Perimetri: le due relazioni OSM «boundary=limited_traffic_zone» ricalcate sulla mappa ufficiale (ztl.jpg) e
# controllate il 13/08/2025 (data/raw/geo/san-giovanni-valdarno-ztl.json, © OpenStreetMap contributors, ODbL 1.0).
# Attenzione: in OSM i nomi sono invertiti rispetto alla legenda della mappa ufficiale (in OSM «Area A» è la
# striscia di Corso Italia, che nella mappa del Comune è l'area B in blu); qui vale la legenda del Comune.
# Varchi: i 9 varchi della mappa ufficiale (E1–E4 ingresso, U1–U5 uscita) e del modulo 08/54, messi dove la strada
# OSM indicata attraversa il perimetro (mai disegnati a mano).
# Non aggiorna manifest.json. Uso: python3 Tools/build_san_giovanni_valdarno.py
import html, json, math, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/san-giovanni-valdarno"
CHECKED = "2026-10-25T08:00:00Z"
BASE = "https://www.comune.san-giovanni-valdarno.ar.it"
MAP_PAGE = BASE + "/documenti/2562266/mappa-ztl"
MAP_JPG = "https://mycity.s3.sbg.io.cloud.ovh.net/4260930/ztl.jpg"
PERMIT_YEAR = BASE + "/servizi/servizio-dettaglio/2562040"
PERMIT_TEMP = BASE + "/servizi/servizio-dettaglio/3128251"
RULES_PAGE = BASE + "/documenti/2503961/regolamento-determinazione-aree-pedonali-ztl-zcs"
RULES_PDF = "https://mycity.s3.sbg.io.cloud.ovh.net/3716478/ZTL.pdf"
FORM_48H = BASE + "/modulistica/2562345/modulo-richiesta-autorizzazione-successiva"
OSM_MAIN = 19456994    # il centro (in OSM «ZTL Area B»; nella mappa del Comune è l'area A, in rosa)
OSM_CORSO = 19456993   # Corso Italia (in OSM «ZTL Area A»; nella mappa del Comune è l'area B, in blu)
WEEKDAYS = [2, 3, 4, 5, 6]


def flat(text):
    return re.sub(r"\s+", " ", text).strip()


def page_text(name):
    t = (RAW / name).read_text(encoding="utf-8")
    t = re.sub(r"<(script|style)[^>]*>.*?</\1>", " ", t, flags=re.S)
    return flat(html.unescape(re.sub(r"<[^>]+>", " ", t)))


def must_contain(text, quote, where):
    """Ogni frase citata o riassunta deve esserci davvero nel documento salvato"""
    if flat(quote) not in text:
        raise SystemExit(f"Citazione non trovata in {where}: {quote!r}")


mappa = page_text("mappa-ztl.html")
annual = page_text("permesso-ztl-annuale.html")
temp = page_text("permesso-ztl-temporaneo.html")
rules = flat((RAW / "regolamento-CC-63-2011.txt").read_text(encoding="utf-8"))
form = flat((RAW / "modulo-48-ore.txt").read_text(encoding="utf-8"))

QUOTE = ("La circolazione è consentita a tutti dalle ore 6:00 alle ore 9:00 - escluso sabato, domenica e festivi - "
         "in altri orari potranno entrare SOLO i soggetti autorizzati o provvisti di permesso")
QUOTE_CORSO = "Corso Italia: 9:00–11:00 (dalle 11:00 transito vietato, salvo particolari categorie di utenti autorizzati)"
for q in [QUOTE, QUOTE_CORSO, "In tutta l’area Z.T.L. vige il limite di velocità massima di 30km/h.",
          "altre vie: nelle fasce orarie 9:00–11:00 / 12:30–16:00/ 19:00–6:00",
          "è possibile giustificare l’ingresso in Z.T.L. nelle 48 ore successive",
          "ad esclusione dell’area pedonale di Piazza Masaccio, Piazza Cavour e Piazza Sant’Antonio",
          "inviando un messaggio WhatsApp al numero 347 2588693",
          "I veicoli a propulsione elettrica sono assimilati agli altri veicoli a motore.",
          "giorno antecedente al mercato settimanale del sabato", "Pagina aggiornata il 21/11/2025"]:
    must_contain(mappa, q, "pagina Mappa ZTL")
for q in ["Giornaliero (previsto una volta al mese di calendario per ogni utente) gratuito", "Temporaneo 1 - 3 gg €6,00",
          "La richiesta deve essere presentata presso il Punto Amico di via Rosai 1", "Il rilascio del permesso effettuato al Punto Amico è immediato."]:
    must_contain(temp, q, "pagina Permesso temporaneo")
for q in ["La circolazione è consentita a tutti dalle ore 6:00 alle ore 9:00 escluso il sabato, la domenica e i festivi."]:
    must_contain(annual, q, "pagina Permesso annuale")
for q in ["Approvato con deliberazione consiliare n. 63 del 26/07/2011",
          "sarà garantito da un sistema elettronico automatizzato rappresentato da varchi elettronici"]:
    must_contain(rules, q, "regolamento CC 63/2011")
for q in ["varco di ingresso [_] Corso Italia [_] Via Giovanni da San Giovanni [_] Via G. Mazzini [_] Via della Madonna",
          "varco di uscita [_] Corso Italia [_] Via Alberti [_] Via Rosai [_] Largo Ceramica [_] Via S. Lorenzo"]:
    must_contain(form, q, "modulo 08/54")

ztl = osm_geo.load("san-giovanni-valdarno-ztl")
streets = {e["id"]: e for e in osm_geo.load("san-giovanni-valdarno-streets") if e["type"] == "way"}
ring_main = osm_geo.outer_ring(osm_geo.relation(ztl, OSM_MAIN))
ring_corso = osm_geo.outer_ring(osm_geo.relation(ztl, OSM_CORSO))


def crossing(ring, way_id):
    """Il punto in cui la strada OSM attraversa il perimetro (il primo, se più d'uno)"""
    g = [(p["lon"], p["lat"]) for p in streets[way_id]["geometry"]]
    for a, b in zip(g, g[1:]):
        for c, d in zip(ring, ring[1:]):
            den = (a[0] - b[0]) * (c[1] - d[1]) - (a[1] - b[1]) * (c[0] - d[0])
            if den == 0:
                continue
            t = ((a[0] - c[0]) * (c[1] - d[1]) - (a[1] - c[1]) * (c[0] - d[0])) / den
            u = -((a[0] - b[0]) * (a[1] - c[1]) - (a[1] - b[1]) * (a[0] - c[0])) / den
            if 0 <= t <= 1 and 0 <= u <= 1:
                return a[1] + t * (b[1] - a[1]), a[0] + t * (b[0] - a[0])
    raise SystemExit(f"La way {way_id} ({streets[way_id]['tags'].get('name')}) non attraversa il perimetro")


def first_node(way_id):
    p = streets[way_id]["geometry"][0]
    return p["lat"], p["lon"]


# (codice sulla mappa, nome, posizione) — nomi dal modulo 08/54 e dalla mappa ufficiale
GATES_MAIN = [
    ("E2", "E2 · Via Giovanni da San Giovanni (entry)", crossing(ring_main, 24949539)),
    ("E3", "E3 · Via G. Mazzini (entry)", crossing(ring_main, 108247333)),
    ("E4", "E4 · Via della Madonna (entry)", crossing(ring_main, 977003259)),
    ("U1", "U1 · Via Alberti (exit)", crossing(ring_main, 617205626)),
    # Via San Lorenzo sbocca in via Oberdan dove inizia via Oberdan: lì il perimetro non taglia una strada
    ("U3", "U3 · Via S. Lorenzo (exit)", first_node(163822983)),
    # U4 e U5: il modulo nomina «Via Rosai» e «Largo Ceramica» senza dire quale è quale (vedi pending)
    ("U4", "U4 · towards Via Mannozzi (exit)", crossing(ring_main, 976995969)),
    ("U5", "U5 · Via Rosai, north side (exit)", crossing(ring_main, 108247329)),
]
GATES_CORSO = [
    ("E1", "E1 · Corso Italia, Via Oberdan side (entry)", crossing(ring_corso, 183897476)),
    ("U2", "U2 · Corso Italia, Via Piave side (exit)", crossing(ring_corso, 1341447903)),
]


def gates(lst):
    return [{"id": f"sgv-{code.lower()}", "name": name, "location": {"lat": round(lat, 6), "lon": round(lon, 6)}}
            for code, name, (lat, lon) in lst]


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


LINKS = [
    link("City of San Giovanni Valdarno: ZTL map and rules", "Comune di San Giovanni Valdarno: mappa e regole della ZTL",
         "Stadt San Giovanni Valdarno: ZTL-Karte und Regeln", MAP_PAGE),
    link("City of San Giovanni Valdarno: official ZTL map with gates (image)", "Comune di San Giovanni Valdarno: mappa ufficiale della ZTL con i varchi (immagine)",
         "Stadt San Giovanni Valdarno: offizielle ZTL-Karte mit Kameras (Bild)", MAP_JPG),
    link("City of San Giovanni Valdarno: temporary ZTL permits (Punto Amico)", "Comune di San Giovanni Valdarno: permessi ZTL temporanei (Punto Amico)",
         "Stadt San Giovanni Valdarno: befristete ZTL-Genehmigungen (Punto Amico)", PERMIT_TEMP),
    link("City of San Giovanni Valdarno: annual ZTL permits", "Comune di San Giovanni Valdarno: permessi ZTL annuali",
         "Stadt San Giovanni Valdarno: ZTL-Jahresgenehmigungen", PERMIT_YEAR),
    link("City of San Giovanni Valdarno: form to justify an entry within 48 hours", "Comune di San Giovanni Valdarno: modulo per giustificare l'ingresso entro 48 ore",
         "Stadt San Giovanni Valdarno: Formular, um eine Einfahrt binnen 48 Stunden zu begründen", FORM_48H),
    link("City of San Giovanni Valdarno: pedestrian area, ZTL and ZCS rules (Council decision 63/2011)",
         "Comune di San Giovanni Valdarno: regolamento area pedonale, ZTL e ZCS (delibera CC 63/2011)",
         "Stadt San Giovanni Valdarno: Regeln für Fußgängerzone, ZTL und ZCS (Beschluss 63/2011)", RULES_PAGE),
    link(f"OpenStreetMap: relations {OSM_MAIN} and {OSM_CORSO} (ZTL outlines, ODbL)",
         f"OpenStreetMap: relazioni {OSM_MAIN} e {OSM_CORSO} (perimetri della ZTL, ODbL)",
         f"OpenStreetMap: Relationen {OSM_MAIN} und {OSM_CORSO} (ZTL-Grenzen, ODbL)", osm_geo.osm_url("relation", OSM_MAIN)),
]

PENDING_COMMON = [
    ("Public holidays: the free 6–9 am window does not apply on holidays, so the ZTL is closed to you all day. GateLR cannot yet show this: on a weekday holiday between 6 and 9 am it may wrongly say the ZTL is off. Don't drive in on holidays.",
     "Festivi: la fascia libera 6–9 non vale nei festivi, quindi la ZTL ti è chiusa tutto il giorno. GateLR non sa ancora mostrarlo: in un festivo infrasettimanale tra le 6 e le 9 potrebbe dire per errore che la ZTL è spenta. Nei festivi non entrare.",
     "Feiertage: Das freie Zeitfenster 6–9 Uhr gilt an Feiertagen nicht, die ZTL ist dann den ganzen Tag gesperrt. GateLR kann das noch nicht abbilden: An einem Feiertag unter der Woche zwischen 6 und 9 Uhr könnte es fälschlich »nicht aktiv« anzeigen. An Feiertagen nicht einfahren."),
    ("24 June (St John the Baptist, the town's patron saint) is counted as a holiday; to be confirmed with the city.",
     "Il 24 giugno (San Giovanni Battista, patrono) è contato come festivo; da confermare con il Comune.",
     "Der 24. Juni (Johannes der Täufer, Stadtpatron) gilt als Feiertag; mit der Stadt zu bestätigen."),
    ("Hotel guests: the city's pages say nothing about hotels registering plates. Short permits (a free one-day permit once a month, 1–3 days €6) are issued in person at the Punto Amico, Via Rosai 1.",
     "Ospiti degli hotel: le pagine del Comune non parlano di hotel che comunicano la targa. I permessi brevi (uno giornaliero gratuito al mese, 1–3 giorni 6 €) si chiedono di persona al Punto Amico, via Rosai 1.",
     "Hotelgäste: Die Seiten der Stadt sagen nichts über eine Kennzeichenmeldung durch Hotels. Kurze Genehmigungen (einmal im Monat ein kostenloser Tag, 1–3 Tage 6 €) gibt es persönlich am Punto Amico, Via Rosai 1."),
    ("Perimeter from OpenStreetMap, traced from the city's map image (which has no coordinates); the edge is approximate. The gates are placed where the named street crosses that outline. The exit gate form lists Via Rosai and Largo Ceramica: which of U4 and U5 is which is still to be confirmed.",
     "Perimetro da OpenStreetMap, ricalcato sull'immagine della mappa del Comune (che non ha coordinate); il bordo è approssimato. I varchi sono messi dove la strada indicata taglia quel perimetro. Il modulo elenca tra i varchi di uscita via Rosai e Largo Ceramica: quale sia U4 e quale U5 è da confermare.",
     "Grenze aus OpenStreetMap, nach dem Kartenbild der Stadt (ohne Koordinaten) gezeichnet; der Rand ist ungefähr. Die Kameras liegen dort, wo die genannte Straße diese Grenze kreuzt. Das Formular nennt als Ausfahrtskameras Via Rosai und Largo Ceramica: welche U4 und welche U5 ist, ist noch zu klären."),
    ("No ordinance number is published with the hours: the 2011 rules (Council decision 63/2011) leave them to a mayor's ordinance we haven't found.",
     "Gli orari non riportano il numero di un'ordinanza: il regolamento del 2011 (delibera CC 63/2011) li rimanda a un'ordinanza del Sindaco che non abbiamo trovato.",
     "Zu den Zeiten ist keine Anordnungsnummer veröffentlicht: Die Regeln von 2011 (Beschluss 63/2011) verweisen auf eine Anordnung des Bürgermeisters, die wir nicht gefunden haben."),
]


def source(quote, translation, extra_pending=()):
    pending = list(extra_pending) + PENDING_COMMON
    return {"authority": "City of San Giovanni Valdarno", "pageURL": MAP_PAGE,
            "ordinance": "Regolamento Aree Pedonali, ZTL e ZCS (Delibera C.C. n. 63 del 26/07/2011)", "ordinanceURL": RULES_PDF,
            "quote": quote, "quoteTranslation": translation[0], "quoteTranslation_de": translation[1],
            "checkedOn": CHECKED, "reviewedByHuman": False,
            "pending": [p[0] for p in pending], "pending_it": [p[1] for p in pending], "pending_de": [p[2] for p in pending],
            "links": LINKS}


# Fasce in cui la ZTL è chiusa a chi non ha il permesso: tutto il giorno, salvo lun–ven 6–9 (non festivi)
WINDOWS = [{"weekdays": WEEKDAYS, "start": 0, "end": 6 * 60},
           {"weekdays": WEEKDAYS, "start": 9 * 60, "end": 24 * 60},
           {"weekdays": [1, 7], "start": 0, "end": 24 * 60}]

SUMMARY = ("Open to everyone only Monday to Friday from 6 to 9 am (not on public holidays). At all other times, "
           "Saturdays, Sundays and holidays included, only vehicles with a permit may enter; electric cars too. Speed limit 30 km/h. "
           "There is no ticket for tourists, and the city mentions no hotel registration. If you had to enter for a proven emergency, "
           "you can justify it with the city's form within 48 hours. Disabled badge holders may enter at any time but must first "
           "send plate and badge number by WhatsApp to the Punto Amico (+39 347 2588693).")
SUMMARY_IT = ("Aperta a tutti solo dal lunedì al venerdì dalle 6 alle 9 (festivi esclusi). In tutti gli altri orari, sabato, "
              "domenica e festivi compresi, entrano solo i veicoli con permesso, elettriche comprese. Limite 30 km/h. "
              "Non c'è un ticket per i turisti e il Comune non prevede la registrazione dall'hotel. Se sei dovuto entrare per un'urgenza documentata, "
              "puoi giustificarlo con il modulo del Comune entro 48 ore. I titolari di contrassegno disabili entrano senza limiti di orario, "
              "ma prima devono mandare targa e numero del contrassegno via WhatsApp al Punto Amico (347 2588693).")
SUMMARY_DE = ("Für alle offen nur Montag bis Freitag von 6 bis 9 Uhr (nicht an Feiertagen). Zu allen anderen Zeiten, auch samstags, "
              "sonntags und an Feiertagen, nur Fahrzeuge mit Genehmigung, auch Elektroautos. Tempo 30. "
              "Es gibt kein Touristenticket, und die Stadt erwähnt keine Kennzeichenmeldung durch Hotels. Musstest du wegen eines belegten Notfalls hinein, "
              "kannst du das binnen 48 Stunden mit dem Formular der Stadt begründen. Inhaber eines Behindertenausweises dürfen jederzeit hinein, "
              "müssen aber vorher Kennzeichen und Ausweisnummer per WhatsApp an den Punto Amico (+39 347 2588693) schicken.")

zone_main = {
    "id": "sgv-centro", "name": "Centro · Historic Centre ZTL", "name_it": "Centro · ZTL Centro storico", "name_de": "Centro · ZTL Altstadt",
    "kind": "restricted", "summary": SUMMARY, "summary_it": SUMMARY_IT, "summary_de": SUMMARY_DE,
    "perimeter": osm_geo.perimeter(ring_main, tol_m=2), "gates": gates(GATES_MAIN),
    "windows": WINDOWS, "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": False,
    "source": source(QUOTE, ("Everyone may drive in from 6:00 to 9:00 – except Saturday, Sunday and public holidays – at other times ONLY authorised vehicles or vehicles with a permit may enter",
                             "Von 6:00 bis 9:00 Uhr dürfen alle hineinfahren – außer samstags, sonntags und an Feiertagen –, zu anderen Zeiten NUR berechtigte Fahrzeuge oder solche mit Genehmigung")),
}
zone_corso = {
    "id": "sgv-corso-italia", "name": "Centro · Corso Italia", "name_it": "Centro · Corso Italia", "name_de": "Centro · Corso Italia",
    "kind": "restricted",
    "summary": "The main street (area B on the city's map), stricter than the rest of the ZTL: even permit holders may drive here only 9–11 am. "
               "For you the rule is the same: open only Monday to Friday 6–9 am (not on holidays); closed at all other times. The squares beside it (Piazza Cavour, Piazza Masaccio) are pedestrian.",
    "summary_it": "La via principale (area B sulla mappa del Comune), più restrittiva del resto della ZTL: anche chi ha il permesso può passarci solo dalle 9 alle 11. "
                  "Per te la regola è la stessa: aperta solo dal lunedì al venerdì dalle 6 alle 9 (festivi esclusi); chiusa in tutti gli altri orari. Le piazze accanto (piazza Cavour, piazza Masaccio) sono pedonali.",
    "summary_de": "Die Hauptstraße (Bereich B auf der Karte der Stadt), strenger als der Rest der ZTL: Selbst mit Genehmigung darf man hier nur von 9 bis 11 Uhr fahren. "
                  "Für dich gilt dasselbe: offen nur Montag bis Freitag 6–9 Uhr (nicht an Feiertagen), sonst gesperrt. Die Plätze daneben (Piazza Cavour, Piazza Masaccio) sind Fußgängerzone.",
    "perimeter": osm_geo.perimeter(ring_corso, tol_m=2), "gates": gates(GATES_CORSO),
    "windows": WINDOWS, "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": False,
    "source": source(QUOTE, ("Everyone may drive in from 6:00 to 9:00 – except Saturday, Sunday and public holidays – at other times ONLY authorised vehicles or vehicles with a permit may enter",
                             "Von 6:00 bis 9:00 Uhr dürfen alle hineinfahren – außer samstags, sonntags und an Feiertagen –, zu anderen Zeiten NUR berechtigte Fahrzeuge oder solche mit Genehmigung"),
                     [("Permit holders: Corso Italia only 9–11 am (\"" + QUOTE_CORSO + "\"); residents of the Corso also at night, and on Fridays only until 5 am because of the Saturday market.",
                       "Chi ha il permesso: Corso Italia solo 9–11 («" + QUOTE_CORSO + "»); i residenti del Corso anche di notte, il venerdì solo fino alle 5 per il mercato del sabato.",
                       "Mit Genehmigung: Corso Italia nur 9–11 Uhr (»" + QUOTE_CORSO + "«); Anwohner des Corso auch nachts, freitags wegen des Samstagsmarkts nur bis 5 Uhr.")]),
}

# Aree pedonali nominate dalla pagina (piazza Sant'Antonio non è in OSM: vedi docs)
PED = {183897472: "Piazza Cavour", 190425367: "Piazza Masaccio"}
pedestrian = [{"id": f"sgv-ap-{wid}", "name": name,
               "perimeter": osm_geo.perimeter([(p["lon"], p["lat"]) for p in streets[wid]["geometry"]], tol_m=1)}
              for wid, name in PED.items()]

city = {"id": "san-giovanni-valdarno", "name": "San Giovanni Valdarno", "name_it": "San Giovanni Valdarno", "name_de": "San Giovanni Valdarno",
        "center": {"lat": 43.5648, "lon": 11.5303}, "zones": [zone_main, zone_corso], "pedestrian": pedestrian,
        "localHolidays": ["06-24"], "status": "draft",
        "license": "Rules: Comune di San Giovanni Valdarno official pages and documents. Perimeters, gates and pedestrian squares: "
                   + osm_geo.ODBL + " (approximate, not official; gates as on the city's map)."}

# Controlli di plausibilità: Palazzo d'Arnolfo e piazza Masaccio dentro, stazione e piazza della Libertà fuori
pois = {e["tags"].get("name"): e for e in osm_geo.load("san-giovanni-valdarno-streets") if e["type"] != "way" or "highway" not in e["tags"]}
station = next(e for e in pois.values() if e.get("tags", {}).get("railway") == "station")
palazzo = pois["Palazzo Pretorio"]["geometry"]
pal = (sum(p["lat"] for p in palazzo) / len(palazzo), sum(p["lon"] for p in palazzo) / len(palazzo))
main = zone_main["perimeter"]
assert osm_geo.contains(main, *pal) or osm_geo.contains(zone_corso["perimeter"], *pal), "Palazzo d'Arnolfo fuori"
assert osm_geo.contains(main, 43.5646, 11.5297), "Piazza Masaccio fuori"
assert not osm_geo.contains(main, station["lat"], station["lon"]) and not osm_geo.contains(zone_corso["perimeter"], station["lat"], station["lon"]), "Stazione dentro"
for z in city["zones"]:
    for g in z["gates"]:
        d = osm_geo.distance_m(z["perimeter"], g["location"]["lat"], g["location"]["lon"])
        assert d < 15, (g["name"], d)
area = osm_geo.area_km2(main)
assert 0.03 < area < 0.15, area

out = ROOT / "Resources/Cities/san-giovanni-valdarno.json"
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.name, [(z["id"], len(z["perimeter"]), len(z["gates"])) for z in city["zones"]], f"{area:.3f} km²",
      "stazione a", round(osm_geo.distance_m(main, station["lat"], station["lon"])), "m dal bordo")
