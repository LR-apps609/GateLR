#!/usr/bin/env python3
# Costruisce Resources/Cities/alghero.json dagli atti ufficiali del Comune di Alghero salvati in data/raw/alghero/
# (fonti e date in docs/fonti-alghero.md). Ogni frase citata o riassunta viene ricontrollata sul testo salvato.
#
# Regole: ordinanza dirigenziale n. 4 del 07/01/2019 «Disciplina della Zona a Traffico Limitato del centro storico» e
#   regolamento allegato A (D.G.C. n. 442 del 27/12/2018), ancora i documenti ZTL pubblicati dal Comune nel 2026:
#   tutto l'anno, tutti i giorni, divieto di circolazione e sosta 0–8, 10:30–14:30 e 16:30–24 (libero 8–10:30 e 14:30–16:30).
#   Nessun atto più recente trovato sul sito; la città murata come ZTL è confermata dal comunicato del 09/10/2025
#   (accesso alla ZTL solo da Porta a Mare durante l'Alghero Fashion Day).
# Geometria: OpenStreetMap (© OpenStreetMap contributors, ODbL 1.0; API OSM, data/raw/geo/alghero-ztl.json), relazione
#   14400850 «ZTL Centro Storico» (source = ordinanza 4/2019; contorno delle mura e dei bastioni come nel perimetro
#   dell'ordinanza: Porta a Mare, banchine, Largo Larco, via Sassari, piazza Porta Terra, via XX Settembre, piazza Sulis,
#   bastioni Colombo, Marco Polo, Pigafetta, Magellano). Varchi: i due dell'ordinanza (via Simon / piazza Porta Terra e
#   piazza Sulis), nodi «device» delle relazioni enforcement OSM 14400847 e 14400848.
# Uso: python3 Tools/build_alghero.py   (non tocca le altre città né manifest.json)
import json, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/alghero"
CHECKED = "2026-10-27T14:40:00Z"
ALL = [1, 2, 3, 4, 5, 6, 7]
OSM_ZTL = 14400850

B = "https://comune.alghero.ss.it"
ORD_4 = B + "/.galleries/doc-documenti/ZTL2019_Ordinanza-dirigenziale-n.-4-del-07.01.2019.pdf"
REG = B + "/.galleries/doc-documenti/ZTL2019_ALLEGATOA_NUOVOREGOLAMENTO_ZTL2018.pdf"
NEWS_2025 = B + "/it/novita/notizia/Alghero-Fashion-Day/"
NEWS_2014 = B + "/it/novita/notizia/Ztl-abbonamento-speciale-per-Piazza-dei-Mercati-00001/"


def flat(s):
    return re.sub(r"\s+", " ", s).strip()


TEXT = {p.stem: flat(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def check(file, *phrases):
    for q in phrases:
        if flat(q) not in TEXT[file]:
            raise SystemExit(f"{file}: frase non trovata, ricontrollare il documento: {q!r}")


QUOTE = ("Tutta l’area del centro storico cittadino come sopra perimetrata è connotata come Zona a Traffico Limitato con "
         "conseguente divieto di circolazione e sosta per tutte le categorie di veicoli fatte salve le deroghe esplicitamente "
         "previste – tutto l’anno - dalle ore 00:00 alle ore 08:00, dalle ore 10:30 alle ore 14:30 e dalle ore 16:30 alle ore 24:00")
PERIM = ("PORTA MARE; BANCHINA DOGANA; BANCHINA GARIBALDI; VIA CATALOGNA (prolungamento); LARGO CONTE GIUSEPPE ALBERTO LARCO; "
         "VIA SASSARI, tratto compreso tra Largo Conte Giuseppe Alberto Larco e Piazza Porta Terra")
for f in ("ord-4-2019", "regolamento-ztl-2018-allegato-a"):
    check(f, QUOTE, PERIM, "PIAZZA SULIS (lato destro verso la città murata); BASTIONI CRISTOFORO COLOMBO (intera carreggiata); "
          "BASTIONI MARCO POLO (intera carreggiata); BASTIONI PIGAFETTA; BASTIONI MAGELLANO.",
          "1) Via Simon intersezione Piazza Porta Terra;", "2) Piazza Sulis.",
          "o) veicoli con trazione esclusivamente elettrica.",
          "con l’obbligo di comunicazione scritta (allegando i documenti necessari) per la registrazione del numero di targa in apposita “lista bianca”",
          "Potranno accedere all’interno della Zona a Traffico Limitato i clienti al solo fine di poter effettuare le operazioni di carico/scarico dei bagagli.",
          "Il responsabile della struttura dovrà comunicare al Comando di Polizia Locale la targa del veicolo utilizzato dai clienti per il raggiungimento della struttura.",
          "entro 72 ore dal transito in ZtL")
check("ord-4-2019", "N. 4 del 07/01/2019", "OGGETTO: DISCIPLINA DELLA ZONA A TRAFFICO LIMITATO DEL CENTRO STORICO.")
check("comune-news-2025-10-09-fashion-day",
      "dalle ore 13:00 alle ore 23:00, l’ingresso e l’uscita dalla ZTL saranno consentiti esclusivamente da Porta a Mare",
      "Bastioni Cristoforo Colombo: chiusura del tratto tra Via Carlo Alberto e Piazza Sulis (uscita ZTL).")
check("comune-news-2014-11-18-abbonamento-ztl", "Zona a Traffico Limitato (area perimetrale interna alle mura)")

# --- geometria ---
GEO = osm_geo.load("alghero-ztl")
rel = osm_geo.relation(GEO, OSM_ZTL)
t = rel["tags"]
if t.get("name") != "ZTL Centro Storico" or t.get("boundary") != "limited_traffic_zone" or "Ordinanza-dirigenziale-n.-4" not in t.get("source:url", ""):
    raise SystemExit("La relazione OSM della ZTL è cambiata: ricontrollare")
shape = osm_geo.perimeter(osm_geo.outer_ring(rel, roles=("outer", "")), tol_m=3)
GATES = []
for rid, name in ((14400847, "Varco Via Simon / Piazza Porta Terra"), (14400848, "Varco Piazza Sulis")):
    dev = next(m for m in osm_geo.relation(GEO, rid)["members"] if m["role"] == "device")
    GATES.append((dev["ref"], name, dev["lat"], dev["lon"]))
gate_list = [osm_geo.gate_json("al", g) for g in GATES]
for g in gate_list:
    if osm_geo.distance_m(shape, g["location"]["lat"], g["location"]["lon"]) > 40 and not osm_geo.contains(shape, g["location"]["lat"], g["location"]["lon"]):
        raise SystemExit(f"Varco lontano dalla zona: {g['name']}")
# Controlli: Cattedrale, piazza Civica, chiesa di San Francesco dentro; giardini Manno, porto (banchina) e piazza Sulis lato sud fuori
for name, lat, lon, inside in [("Cattedrale di Santa Maria", 40.55899, 8.31262, True), ("Piazza Civica", 40.55934, 8.31345, True),
                               ("Chiesa di San Francesco", 40.55822, 8.31397, True), ("Giardini Manno", 40.55984, 8.31622, False),
                               ("Porto, banchina", 40.5612, 8.3150, False), ("Piazza Sulis sud", 40.5555, 8.3165, False)]:
    if osm_geo.contains(shape, lat, lon) != inside:
        raise SystemExit(f"Controllo perimetro fallito: {name} dovrebbe essere {'dentro' if inside else 'fuori'}")
area = osm_geo.area_km2(shape)
if not 0.08 < area < 0.25:
    raise SystemExit(f"Area della ZTL non plausibile: {area:.3f} km²")


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


LINKS = [link("City of Alghero: ordinance no. 4 of 07/01/2019, old-town ZTL (PDF)", "Comune di Alghero: ordinanza n. 4 del 07/01/2019, ZTL del centro storico (PDF)", "Stadt Alghero: Verordnung Nr. 4 vom 07.01.2019, ZTL der Altstadt (PDF)", ORD_4),
         link("City of Alghero: ZTL permit regulations (annex A, PDF)", "Comune di Alghero: regolamento per le autorizzazioni ZTL (allegato A, PDF)", "Stadt Alghero: ZTL-Genehmigungsordnung (Anlage A, PDF)", REG),
         link("City of Alghero: traffic changes for the Alghero Fashion Day 2025 (ZTL access)", "Comune di Alghero: modifiche alla viabilità per l'Alghero Fashion Day 2025 (accesso ZTL)", "Stadt Alghero: Verkehrsänderungen zum Alghero Fashion Day 2025 (ZTL-Zufahrt)", NEWS_2025),
         link(f"OpenStreetMap: relation {OSM_ZTL} «ZTL Centro Storico» (ODbL)", f"OpenStreetMap: relazione {OSM_ZTL} «ZTL Centro Storico» (ODbL)", f"OpenStreetMap: Relation {OSM_ZTL} «ZTL Centro Storico» (ODbL)", osm_geo.osm_url("relation", OSM_ZTL))]

PENDING = [
    ("Hotels and B&Bs inside the walls tell the Local Police the plate of the car you use to reach them: you may then drive in only to load and unload luggage, not to park. Ask your hotel before you arrive.",
     "Hotel e strutture extralberghiere dentro le mura comunicano alla Polizia Locale la targa dell'auto con cui arrivi: puoi entrare solo per caricare e scaricare i bagagli, non per sostare. Chiedi alla struttura prima di arrivare.",
     "Hotels und Unterkünfte innerhalb der Mauern melden der Ortspolizei das Kennzeichen deines Autos: du darfst dann nur zum Be- und Entladen des Gepäcks hinein, nicht parken. Frag dein Hotel vor der Anreise."),
    ("Fully electric cars may enter, but only after their plate has been registered in writing on the City's white list. Blue Badge holders not resident in Alghero who enter in an emergency must send the Local Police the plate, date, time and a copy of the badge within 72 hours.",
     "Le auto solo elettriche possono entrare, ma solo dopo aver comunicato per iscritto la targa per la «lista bianca» del Comune. I titolari di contrassegno disabili non residenti ad Alghero che entrano per urgenza devono inviare alla Polizia Locale targa, data, ora e copia del contrassegno entro 72 ore.",
     "Reine Elektroautos dürfen hinein, aber erst nachdem das Kennzeichen schriftlich für die weiße Liste der Stadt gemeldet wurde. Inhaber eines Behindertenausweises ohne Wohnsitz in Alghero, die im Notfall einfahren, müssen der Ortspolizei Kennzeichen, Datum, Uhrzeit und eine Kopie des Ausweises binnen 72 Stunden schicken."),
    ("Hours from ordinance 4/2019, still the ZTL document published by the City in 2026; no newer ordinance was found (the City's online services and the official notice board could not be reached from here). Some unofficial guides give different summer evening hours. The ZTL is also closed to vehicles over 2.5 t; pedestrian areas inside have their own rules.",
     "Orari dell'ordinanza 4/2019, ancora il documento ZTL pubblicato dal Comune nel 2026; nessuna ordinanza più recente trovata (i servizi online del Comune e l'albo pretorio non erano raggiungibili da qui). Alcune guide non ufficiali riportano orari serali estivi diversi. La ZTL è vietata anche ai veicoli oltre 2,5 t; le aree pedonali interne hanno regole proprie.",
     "Zeiten aus der Verordnung 4/2019, die 2026 weiterhin das von der Stadt veröffentlichte ZTL-Dokument ist; keine neuere Verordnung gefunden (Onlinedienste und Amtstafel der Stadt waren von hier aus nicht erreichbar). Einige inoffizielle Führer nennen andere Sommerabendzeiten. Die ZTL ist außerdem für Fahrzeuge über 2,5 t gesperrt; Fußgängerzonen innen haben eigene Regeln."),
    ("Area: the OpenStreetMap ZTL relation drawn on the walls and bastions after the ordinance's perimeter (not an official map). Gates: the two cameras named in the ordinance, positions from OpenStreetMap.",
     "Area: la relazione ZTL di OpenStreetMap disegnata su mura e bastioni seguendo il perimetro dell'ordinanza (non è una mappa ufficiale). Varchi: le due telecamere indicate dall'ordinanza, posizioni da OpenStreetMap.",
     "Fläche: die OpenStreetMap-ZTL-Relation, entlang Mauern und Bastionen nach dem Perimeter der Verordnung gezeichnet (keine amtliche Karte). Kameras: die beiden in der Verordnung genannten, Positionen aus OpenStreetMap."),
]

zone = {"id": "alghero-centro", "name": "Walled city · ZTL Centro Storico", "name_it": "Città murata · ZTL Centro Storico",
        "name_de": "Altstadt in den Mauern · ZTL Centro Storico", "kind": "restricted",
        "summary": "The whole walled old town of Alghero (inside the bastions, from Porta a Mare and Porta Terra to Piazza Sulis) is closed to vehicles without a permit all year, every day: midnight–8 am, 10:30 am–2:30 pm and 4:30 pm–midnight. Open to all only 8–10:30 am and 2:30–4:30 pm. Cameras at Via Simon/Piazza Porta Terra and Piazza Sulis. Staying inside? Your hotel gives your plate to the Local Police, only to unload luggage. Park outside the walls and walk.",
        "summary_it": "Tutta la città murata di Alghero (dentro i bastioni, da Porta a Mare e Porta Terra a piazza Sulis) è chiusa ai veicoli senza permesso tutto l'anno, tutti i giorni: 0–8, 10:30–14:30 e 16:30–24. Aperta a tutti solo 8–10:30 e 14:30–16:30. Telecamere in via Simon/piazza Porta Terra e in piazza Sulis. Dormi dentro? La struttura comunica la targa alla Polizia Locale, solo per scaricare i bagagli. Parcheggia fuori dalle mura e cammina.",
        "summary_de": "Die ganze ummauerte Altstadt von Alghero (innerhalb der Bastionen, von Porta a Mare und Porta Terra bis Piazza Sulis) ist für Fahrzeuge ohne Genehmigung ganzjährig täglich gesperrt: 0–8, 10:30–14:30 und 16:30–24 Uhr. Für alle offen nur 8–10:30 und 14:30–16:30 Uhr. Kameras an Via Simon/Piazza Porta Terra und Piazza Sulis. Du übernachtest innen? Dein Hotel meldet das Kennzeichen der Ortspolizei, nur zum Gepäckausladen. Außerhalb der Mauern parken und laufen.",
        "perimeter": shape, "gates": gate_list,
        "windows": [{"weekdays": ALL, "start": a, "end": b} for a, b in ((0, 8 * 60), (10 * 60 + 30, 14 * 60 + 30), (16 * 60 + 30, 24 * 60))],
        "freeOnHolidays": False, "holidaysAsSunday": False, "exemptFuels": [], "hotelCanRegister": True,
        "source": {"authority": "City of Alghero", "pageURL": ORD_4,
                   "ordinance": "Ordinanza dirigenziale n. 4 del 07/01/2019; regolamento allegato A (D.G.C. n. 442 del 27/12/2018)",
                   "ordinanceURL": ORD_4, "quote": QUOTE,
                   "quoteTranslation": "The whole area of the historic town centre, bounded as above, is a Limited Traffic Zone, with a consequent ban on driving and parking for all categories of vehicles, except for the exemptions expressly provided, all year round, from 00:00 to 08:00, from 10:30 to 14:30 and from 16:30 to 24:00.",
                   "quoteTranslation_de": "Das gesamte wie oben abgegrenzte Gebiet der historischen Altstadt ist Zone mit beschränktem Verkehr, mit Fahr- und Parkverbot für alle Fahrzeugarten, vorbehaltlich der ausdrücklich vorgesehenen Ausnahmen, ganzjährig von 00:00 bis 08:00, von 10:30 bis 14:30 und von 16:30 bis 24:00 Uhr.",
                   "checkedOn": CHECKED, "reviewedByHuman": False,
                   "pending": [p[0] for p in PENDING], "pending_it": [p[1] for p in PENDING], "pending_de": [p[2] for p in PENDING],
                   "links": LINKS}}

city = {"id": "alghero", "name": "Alghero", "name_it": "Alghero", "name_de": "Alghero",
        "center": {"lat": 40.5593, "lon": 8.3135}, "zones": [zone], "status": "draft",
        "license": "Rules: Comune di Alghero (ordinance 4/2019). Area and gates: " + osm_geo.ODBL + " (approximate, not official)."}

ready = all(len(z["perimeter"]) >= 5 and z["source"]["quote"] for z in city["zones"])
out = ROOT / ("Resources/Cities/alghero.json" if ready else "data/drafts/alghero.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/alghero.json" if ready else "Resources/Cities/alghero.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), [(z["id"], len(z["perimeter"]), len(z["gates"])) for z in city["zones"]], f"{area:.3f} km²")
