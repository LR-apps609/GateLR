#!/usr/bin/env python3
# Costruisce la scheda di Trento dalle pagine e dagli atti ufficiali salvati in data/raw/trento/ (URL e data di lettura in
# testa a ogni file; fonti e date in docs/fonti-trento.md).
#
# Regole (lette il 27/10/2026): «Guida alla Ztl» del Comune, servizio «Utenti occasionali in Ztl» (clienti di alberghi e
# B&B), Disciplinare per la circolazione nella ZTL (delibera di Giunta 290/2018, modificato con determinazione 59/33 del
# 06/11/2023: varchi, controllo 24 ore su 24, art. 34 clienti degli alberghi), ordinanza 219/2023 (ZTL-CS, elenco vie),
# elenco vie della ZTL-P, scheda del dataset «Zona a traffico limitato (Open data)» su dati.trentino.it.
#
# Geometria (mai disegnata a mano): il perimetro ufficiale è il dataset open data del Comune (CC0), ma i suoi file sono su
# gis.comune.trento.it, bloccato dal proxy del sandbox (403). Si usa la relazione OpenStreetMap 19186663 «ZTL Centro
# Storico» (boundary=limited_traffic_zone, source=Comune di Trento, creata il 28/05/2025 dal dato del Comune), scaricata con
# Tools/fetch_osm_api.py il 27/10/2026 (data/raw/geo/trento-ztl.json, © OpenStreetMap contributors, ODbL 1.0).
# Controllo: le vie degli elenchi ufficiali della ZTL-CS (ordinanza 219/2023) e della ZTL-P trovate in OSM cadono dentro il
# perimetro (o a meno di 25 m dal bordo), piazza della Mostra (estensione 2023) compresa. Varchi: gli incroci dei 7 varchi
# in entrata del Disciplinare (art. 4), presi dalle strade OSM.
# Uso: python3 Tools/build_trento.py   (non tocca le altre città né manifest.json)
import json, math, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/trento"
CHECKED = "2026-10-27T11:40:00Z"
EVERY_DAY = [1, 2, 3, 4, 5, 6, 7]


def flat(s):
    return re.sub(r"\s+", " ", s).strip()


TEXT = {p.stem: flat(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}
RAWTEXT = {p.stem: p.read_text(encoding="utf-8") for p in RAW.glob("*.txt")}


def url_of(file):
    return TEXT[file].split(" ", 2)[1]


def check(file, *phrases):
    """Ogni frase citata o riassunta deve comparire, parola per parola, nel testo salvato"""
    for q in phrases:
        if flat(q) not in TEXT[file]:
            raise SystemExit(f"{file}: frase non trovata, ricontrollare il testo: {q!r}")


GUIDE_F, HOTEL_F, DISC_F, ORD_F, CS_F, P_F, DATA_F = ("comune-guida-ztl", "comune-utenti-occasionali-ztl", "disciplinare-ztl-2023-estratto",
                                                      "ordinanza-219-2023", "elenco-vie-ztl-cs", "elenco-vie-ztl-p", "dati-trentino-dataset-ztl")
GUIDE, HOTEL, DISC, ORD, CS_URL, P_URL, DATASET = map(url_of, (GUIDE_F, HOTEL_F, DISC_F, ORD_F, CS_F, P_F, DATA_F))
QUOTE = "Tutti gli accessi irregolari sono rilevati automaticamente, 24 ore su 24"
GATES = [("via Pozzo – via Torre Vanga", "Via Andrea Pozzo", "Via Torre Vanga"),
         ("via Suffragio - piazza Sanzio", "Via del Suffragio", "Piazza Raffaello Sanzio"),
         ("piazza della Mostra – piazza Sanzio", "Piazza della Mostra", "Piazza Raffaello Sanzio"),
         ("via Marchetti – via dei Ventuno", "Via Livio Marchetti", "Via dei Ventuno"),
         ("via Galilei - largo Porta Nuova", "Via Galileo Galilei", "Largo Porta Nuova"),
         ("piazza Garzetti – largo Pigarelli", "Piazza Giovanni Battista Garzetti", "Largo Luigi Pigarelli"),
         ("via Verdi – via Rosmini", "Via Giuseppe Verdi", "Via Antonio Rosmini")]
check(DISC_F, QUOTE, "I varchi della ZTL complessivamente sono 18, di cui 7 in entrata e 11 in uscita",
      *[g[0] for g in GATES],
      "Tutti i veicoli a motore, per circolare all'interno della ZTL, al fine di evitare l'avvio del procedimento sanzionatorio, devono avere la propria targa registrata",
      "La ZTL del Comune di Trento è suddivisa in due aree distinte, ZTL-Pedonale e ZTL-Centro Storico.",
      "I clienti possono accedere alla ZTL privi di autorizzazione ed al momento del check-in e del check- out devono comunicare la targa del proprio veicolo alla reception dell'attività ricettiva",
      "sosta operativa di 30 minuti nelle immediate vicinanze dell'attività ricettiva",
      "Da tale obbligo sono esclusi motocicli e ciclomotori",
      "Sono previste riduzioni tariffarie per i veicoli a basso impatto ambientale",
      "modificato con determinazione dirigenziale n. 59/33 del 06.11.2023")
check(HOTEL_F, "Al check-in e check-out dovranno comunicare la targa del veicolo alla reception dell'attività ricettiva, che rilascerà il permesso temporaneo.",
      "Questo consente l'entrata e l'uscita dalla Ztl, compresa una sosta di 30 minuti vicino alla struttura.",
      "parcheggio \"Ex-Sit\" di via Canestrini", "Le richieste andranno inviate almeno 2 giorni lavorativi prima dell'accesso.",
      "Ultimo aggiornamento: 03/11/2025")
check(GUIDE_F, "È costituita dalla Ztl-P (zona a traffico limitato pedonale) e dalla Ztl-CS (zona a traffico limitato centro storico).",
      "Per i permessi di sosta e transito in Ztl nel Comune di Trento occorre rivolgersi alla società Trentino mobilità Spa.",
      "Ultimo aggiornamento: 02/09/2026")
check(ORD_F, "Ordinanza n. 219/2023/27", "piazza della Mostra nel tratto compreso tra il numero civico 15 e l’intersezione con piazza Sanzio",
      "la circolazione (transito e sosta) al di fuori delle fasce orarie previste dal disciplinare vengono punite con la stessa sanzione per chi accede senza autorizzazione alla ZTL")
check(DATA_F, "La Zona a Traffico Limitato - ZTL (costituita dalla ZTL-P più centrale e dalla ZTL-CS che la circonda)", "Creative Commons CCZero 1.0")

# --- geometria ---
GEO = json.loads((ROOT / "data/raw/geo/trento-ztl.json").read_text(encoding="utf-8"))["elements"]
REL = osm_geo.relation(GEO, 19186663)
assert REL["tags"].get("source") == "Comune di Trento" and REL["tags"].get("boundary") == "limited_traffic_zone"
ring = osm_geo.outer_ring(REL)
perimeter = osm_geo.perimeter(ring, tol_m=2)
STREETS = [e for e in GEO if e["type"] == "way"]


def official_streets(file):
    """Le vie degli elenchi ufficiali, una per riga o per colonna: (tipo, ultima parola del nome)"""
    out = []
    for line in RAWTEXT[file].splitlines()[3:]:
        for part in re.split(r"\s{3,}", line.strip()):
            m = re.match(r"(?i)(via|vicolo|piazza|piazzetta|largo|galleria|passaggio|sottoportico|parco)\s+(.+)", part.strip())
            if m:
                name = re.sub(r"\(.*", "", m.group(2)).strip()
                name = re.sub(r"[“”\"]\w+[“”\"]|\b(fra|tra)\b.*", "", name).strip()
                if name:
                    out.append((m.group(1).lower(), name.split()[-1].lower().strip("’'")))
    return out


def osm_matches(kind, last):
    return [w for w in STREETS if w["tags"]["name"].lower().startswith(kind + " ") and w["tags"]["name"].lower().rstrip().split()[-1].strip("’'") == last]


found = outside = 0
for f in (CS_F, P_F):
    for kind, last in official_streets(f):
        ws = osm_matches(kind, last)
        if not ws:
            continue
        found += 1
        pts = [p for w in ws for p in w["geometry"]]
        mid = pts[len(pts) // 2]
        if not (osm_geo.contains(perimeter, mid["lat"], mid["lon"]) or any(osm_geo.distance_m(perimeter, p["lat"], p["lon"]) < 25 or osm_geo.contains(perimeter, p["lat"], p["lon"]) for p in pts)):
            outside += 1
            print("fuori dal perimetro:", kind, last, [w["tags"]["name"] for w in ws][:1])
assert found >= 60 and outside <= 2, (found, outside)


def gate_point(a, b):
    wa = [w for w in STREETS if w["tags"]["name"] == a]
    wb = [w for w in STREETS if w["tags"]["name"] == b]
    assert wa and wb, (a, b)
    pos = {n: (p["lat"], p["lon"]) for w in wa + wb for n, p in zip(w["nodes"], w["geometry"])}
    common = {n for w in wa for n in w["nodes"]} & {n for w in wb for n in w["nodes"]}
    if common:
        return pos[min(common)], 0.0
    best = min((math.hypot((p["lat"] - q["lat"]) * 111000, (p["lon"] - q["lon"]) * 77000), ((p["lat"] + q["lat"]) / 2, (p["lon"] + q["lon"]) / 2))
               for w in wa for p in w["geometry"] for v in wb for q in v["geometry"])
    return best[1], best[0]


gates = []
for i, (label, a, b) in enumerate(GATES, 1):
    (lat, lon), gap = gate_point(a, b)
    assert gap < 40, (label, gap)
    gates.append({"id": f"tn-varco{i}", "name": label, "location": {"lat": round(lat, 6), "lon": round(lon, 6)}})


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


LINKS = [link("City of Trento: ZTL guide", "Comune di Trento: guida alla ZTL", "Stadt Trient: Leitfaden zur ZTL", GUIDE),
         link("City of Trento: hotel and B&B guests, temporary permits", "Comune di Trento: clienti di alberghi e B&B, permessi temporanei",
              "Stadt Trient: Hotel- und B&B-Gäste, befristete Genehmigungen", HOTEL),
         link("ZTL rules (Disciplinare 2023, PDF)", "Disciplinare della ZTL (2023, PDF)", "ZTL-Regelwerk (Disciplinare 2023, PDF)", DISC),
         link("Ordinance 219/2023 (ZTL boundary, PDF)", "Ordinanza 219/2023 (delimitazione della ZTL, PDF)", "Verordnung 219/2023 (ZTL-Grenze, PDF)", ORD),
         link("Official ZTL map data (open data, Trentino portal)", "Perimetro ufficiale della ZTL (open data, portale del Trentino)",
              "Offizielle ZTL-Kartendaten (Open Data, Trentiner Portal)", DATASET),
         link("Trentino Mobilità: permits office", "Trentino Mobilità: ufficio permessi", "Trentino Mobilità: Genehmigungsbüro", "https://www.trentinomobilita.it/")]

PENDING = [
    ("Hotel and B&B guests inside the ZTL may drive in without a permit: at check-in and check-out give your plate to the reception, which enters it online and issues a temporary permit (entry, exit and a 30-minute stop near the hotel, by the shortest route). Ask the hotel to confirm; longer parking only in the Ex-SIT car park in Via Canestrini with the hotel's pass.",
     "Gli ospiti di alberghi e B&B dentro la ZTL possono entrare senza permesso: al check-in e al check-out comunicano la targa alla reception, che la inserisce online e rilascia un permesso temporaneo (entrata, uscita e sosta di 30 minuti vicino alla struttura, per la via più breve). Chiedi conferma all'hotel; la sosta lunga solo nel parcheggio Ex-SIT di via Canestrini con il contrassegno dell'hotel.",
     "Gäste von Hotels und B&Bs in der ZTL dürfen ohne Genehmigung einfahren: beim Check-in und Check-out das Kennzeichen an der Rezeption angeben, die es online einträgt und eine befristete Genehmigung ausstellt (Ein- und Ausfahrt und 30 Minuten Halt beim Hotel, auf kürzestem Weg). Vom Hotel bestätigen lassen; längeres Parken nur im Parkplatz Ex-SIT in der Via Canestrini mit dem Ausweis des Hotels."),
    ("No day ticket for visitors: other temporary permits only for special needs, from Trentino Mobilità (at least 2 working days before) or the municipal police for urgent cases.",
     "Nessun biglietto giornaliero per i visitatori: altri permessi temporanei solo per esigenze particolari, da Trentino Mobilità (almeno 2 giorni lavorativi prima) o dalla Polizia Locale per i casi urgenti.",
     "Kein Tagesticket für Besucher: andere befristete Genehmigungen nur für besondere Fälle, bei Trentino Mobilità (mindestens 2 Werktage vorher) oder bei der Ortspolizei in dringenden Fällen."),
    ("Electric and hybrid cars are not exempt (only reduced permit fees for residents); motorcycles need a permit too.",
     "Auto elettriche e ibride non esenti (solo tariffe ridotte per i permessi dei residenti); anche le moto servono il permesso.",
     "Elektro- und Hybridautos sind nicht befreit (nur ermäßigte Gebühren für Anwohnergenehmigungen); auch Motorräder brauchen eine Genehmigung."),
    ("The ZTL has two parts: the inner pedestrian ZTL-P (Piazza Battisti, Via Oss Mazzurana, Via Diaz…) and the ZTL-CS around it; GateLR shows them as one zone, closed 24 hours a day to cars without a permit.",
     "La ZTL ha due parti: la ZTL-P pedonale più interna (piazza Battisti, via Oss Mazzurana, via Diaz…) e la ZTL-CS che la circonda; GateLR le mostra come un'unica zona, chiusa 24 ore su 24 alle auto senza permesso.",
     "Die ZTL hat zwei Teile: die innere Fußgänger-ZTL-P (Piazza Battisti, Via Oss Mazzurana, Via Diaz…) und die umgebende ZTL-CS; GateLR zeigt sie als eine Zone, rund um die Uhr für Autos ohne Genehmigung gesperrt."),
    ("Perimeter: the City's open-data boundary as copied into OpenStreetMap (2025); the City's own file server could not be reached. Gates on the map are the 7 entry cameras listed in the rules, placed at the street junctions.",
     "Perimetro: il confine open data del Comune come riportato in OpenStreetMap (2025); il server dei file del Comune non era raggiungibile. I varchi sulla mappa sono i 7 varchi in entrata del Disciplinare, agli incroci indicati.",
     "Grenze: die Open-Data-Grenze der Stadt, wie sie in OpenStreetMap übernommen wurde (2025); der Dateiserver der Stadt war nicht erreichbar. Die Kameras auf der Karte sind die 7 Einfahrtskameras des Regelwerks an den genannten Kreuzungen."),
]

zone = {"id": "trento-ztl", "name": "Historic centre · ZTL 24 hours", "name_it": "Centro storico · ZTL 0–24",
        "name_de": "Altstadt · ZTL rund um die Uhr", "kind": "restricted",
        "summary": "Trento's historic centre (Piazza Duomo, Via Belenzani, Piazza Battisti) is closed to cars without a permit 24 hours a day, every day; 7 cameras at the entrances read plates. There is no day ticket. If your hotel or B&B is inside, you may drive in: give your plate at check-in and check-out and the reception issues a permit with a 30-minute stop.",
        "summary_it": "Il centro storico di Trento (piazza Duomo, via Belenzani, piazza Battisti) è chiuso alle auto senza permesso 24 ore su 24, tutti i giorni; 7 telecamere agli ingressi leggono le targhe. Non c'è un biglietto giornaliero. Se l'albergo o il B&B è dentro puoi entrare: comunica la targa al check-in e al check-out e la reception rilascia un permesso con sosta di 30 minuti.",
        "summary_de": "Die Altstadt von Trient (Domplatz, Via Belenzani, Piazza Battisti) ist rund um die Uhr, jeden Tag, für Autos ohne Genehmigung gesperrt; 7 Kameras an den Einfahrten lesen die Kennzeichen. Ein Tagesticket gibt es nicht. Liegt dein Hotel oder B&B innen, darfst du einfahren: Kennzeichen beim Check-in und Check-out angeben, die Rezeption stellt eine Genehmigung mit 30 Minuten Halt aus.",
        "perimeter": perimeter, "gates": gates,
        "windows": [{"weekdays": EVERY_DAY, "start": 0, "end": 24 * 60}],
        "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": True,
        "source": {"authority": "City of Trento", "pageURL": GUIDE,
                   "ordinance": "Disciplinare per la circolazione veicolare nella ZTL (delibera di Giunta 290/2018, determinazione 59/33 del 06/11/2023); ordinanze 30/2016 e 219/2023",
                   "ordinanceURL": DISC,
                   "quote": QUOTE,
                   "quoteTranslation": "All unauthorised entries are detected automatically, 24 hours a day",
                   "quoteTranslation_de": "Alle unerlaubten Einfahrten werden automatisch erfasst, rund um die Uhr",
                   "checkedOn": CHECKED, "reviewedByHuman": False,
                   "pending": [p[0] for p in PENDING], "pending_it": [p[1] for p in PENDING], "pending_de": [p[2] for p in PENDING],
                   "links": LINKS}}

city = {"id": "trento", "name": "Trento", "name_it": "Trento", "name_de": "Trient",
        "center": {"lat": 46.0670, "lon": 11.1213}, "zones": [zone], "status": "draft",
        "license": "Rules: Comune di Trento official pages and acts. Perimeter: Comune di Trento open data (CC0) via " + osm_geo.ODBL + " (relation 19186663); gates at OSM street junctions."}

# Controlli: piazza Duomo e piazza della Mostra (estensione 2023) dentro, la stazione e piazza Dante fuori, varchi sul bordo
for n, lat, lon in [("Piazza Duomo", 46.06752, 11.12139), ("Piazza della Mostra", 46.07142, 11.12583)]:
    assert osm_geo.contains(perimeter, lat, lon), f"{n} fuori dal perimetro"
for n, lat, lon in [("stazione FS", 46.07224, 11.11932), ("piazza Dante", 46.07152, 11.12013)]:
    assert not osm_geo.contains(perimeter, lat, lon), f"{n} dentro il perimetro"
for g in gates:
    assert osm_geo.distance_m(perimeter, g["location"]["lat"], g["location"]["lon"]) < 40, g
assert 0.2 < osm_geo.area_km2(perimeter) < 0.8, osm_geo.area_km2(perimeter)

ready = all(len(z["perimeter"]) >= 5 and z["source"]["quote"] for z in city["zones"])
out = ROOT / ("Resources/Cities/trento.json" if ready else "data/drafts/trento.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/trento.json" if ready else "Resources/Cities/trento.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), len(perimeter), len(gates), round(osm_geo.area_km2(perimeter), 3), "vie ufficiali trovate in OSM:", found, "fuori:", outside)
