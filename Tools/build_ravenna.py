#!/usr/bin/env python3
# Costruisce la scheda di Ravenna dalle pagine e dagli atti ufficiali salvati in data/raw/ravenna/ (URL e data di lettura
# in testa a ogni file; fonti e date in docs/fonti-ravenna.md).
#
# Regole (26/10/2026): pagina SIRIO del Comune (varchi e loro orari, contrassegno giornaliero ai parcometri), comunicazione
# targhe (strutture ricettive, disabili), comunicato sul piano sosta 2026 (mezza giornata 8 €), pagina di Azimut
# (giornaliero 15 €, mattiniero e pomeridiano 8 €), determina E 2/4 del 2006 (contrassegni giornalieri degli hotel).
#
# Geometria: il Comune non pubblica un perimetro in open data (niente su dati.gov.it) e la «Piantina stradale con varchi
# Sirio» è un'immagine senza coordinate; OpenStreetMap (Overpass e API) non era raggiungibile dal sandbox il 26/10/2026.
# Senza perimetro la scheda resta in data/drafts/ravenna.json: basta salvare un perimetro verificato (relazione OSM con il
# nome ufficiale, o strade OSM ricavate dai varchi come in build_perugia.py) in data/raw/ravenna/ztl_perimetro.geojson
# (WGS84) e rilanciare lo script (vedi «ready»).
# Uso: python3 Tools/build_ravenna.py   (non tocca le altre città né manifest.json)
import json, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/ravenna"
CHECKED = "2026-10-27T00:10:00Z"
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
            raise SystemExit(f"{file}: frase non trovata, ricontrollare la pagina: {q!r}")


SIRIO_F, PLATES_F, PRESS_F, AZIMUT_F, DET_F = ("comune-sirio-controllo-accessi-ztl", "comune-comunicazione-targhe-sirio",
                                               "comune-comunicato-piano-sosta-2026", "azimut-permessi-giornalieri-ztl",
                                               "determina-e2-4-2006-contrassegni-ztl")
SIRIO, PLATES, PRESS_2026, AZIMUT, DETERMINA = map(url_of, (SIRIO_F, PLATES_F, PRESS_F, AZIMUT_F, DET_F))
TOURISM = "https://www.turismo.ra.it/en/getting-around-ravenna/limited-traffic-zone-ltz/"
DISABLED = "https://comune.ravenna.it/amministrazione/documenti-e-dati/modulistica/modulo-comunicazione-targhe-persone-invalide-accesso-sirio-ztl/"
QUOTE = ("Attraverso una rete di telecamere, le targhe dei veicoli che accedono attraverso i “varchi” vengono riconosciute e "
         "confrontate con la lista delle targhe dei veicoli abilitati al transito")
GATES_24H = ["VIA DI ROMA", "VIA G. GUACCIMANNI", "VIA A. BACCARINI", "VIA N. RONDINELLI", "VIA CAVOUR (ingresso piazzetta Gandhi)", "VIA PONTE MARINO"]
GATES_DAY = ["VIA A. MARIANI", "VIA AR. GUERRINI", "VIA P. MATTEUCCI"]
check(SIRIO_F, QUOTE, *[g + " 24 ORE SU 24" for g in GATES_24H], *[g + " DALLE ORE 07.30 ALLE ORE 20.30" for g in GATES_DAY],
      "Il contrassegno giornaliero per la circolazione e sosta in ZTL viene rilasciato (24 ore su 24) dai parcometri abilitati alla funzione",
      "Pagina aggiornata il 30/07/2025", "possono comunicare alla Polizia Locale di Ravenna le targhe dei veicoli (massimo 2)")
check(PLATES_F, "la trasmissione della modulistica da parte delle strutture ricettive che ospitano clienti con auto",
      "inserimento alla data della comunicazione", "Pagina aggiornata il 15/09/2026")
check(PRESS_F, "introduzione del contrassegno con validità mezza giornata anziché solo a giornata intera (dalle 00 fino alle 12 oppure dalle 12 alle 24) per accesso e sosta in Ztl a tariffa di 8 euro")
check(AZIMUT_F, "Giornaliero (dalle ore 00.00 alle ore 23:59) al costo di € 15,00;", "Mattiniero (dalle ore 00.00 alle ore 11:59) al costo di € 8,00;",
      "Pomeridiano (dalle ore 12.00 alle ore 23:59) al costo di € 8,00.", "comunque per non più di 90 minuti",
      "ad eccezione di Piazza del Popolo e di tutte le altre aree pedonali",
      "Il pagamento è consentito con monete (la macchina non dà resto) e mediante carta di credito.")
check(DET_F, "CLIENTI CHE SOGGIORNANO PRESSO STRUTTURE RICETTIVE", "Ha validità nella sola giornata di rilascio.")


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


LINKS = [link("City of Ravenna: SIRIO, ZTL gates and hours", "Comune di Ravenna: SIRIO, varchi e orari della ZTL",
              "Stadt Ravenna: SIRIO, ZTL-Kameras und Zeiten", SIRIO),
         link("Azimut: day permits from parking meters (15 €, half day 8 €)", "Azimut: permessi giornalieri ai parcometri (15 €, mezza giornata 8 €)",
              "Azimut: Tagesgenehmigungen am Parkautomaten (15 €, halber Tag 8 €)", AZIMUT),
         link("City of Ravenna: registering plates in the ZTL (hotels, disabled badge)", "Comune di Ravenna: comunicazione targhe in ZTL (strutture ricettive, disabili)",
              "Stadt Ravenna: Kennzeichenmeldung in der ZTL (Hotels, Behindertenausweis)", PLATES),
         link("City of Ravenna: parking and ZTL plan changes from 1 March 2026", "Comune di Ravenna: modifiche al piano sosta e ZTL dal 1° marzo 2026",
              "Stadt Ravenna: Änderungen bei Parken und ZTL ab 1. März 2026", PRESS_2026),
         link("City of Ravenna: form for disabled badge holders", "Comune di Ravenna: modulo targhe per persone invalide",
              "Stadt Ravenna: Formular für Inhaber eines Behindertenausweises", DISABLED),
         link("Ravenna Tourism: limited traffic zone", "Ravenna Turismo: zona a traffico limitato", "Ravenna Tourismus: verkehrsberuhigte Zone", TOURISM)]

PENDING = [
    ("Gate hours: Via di Roma, Via Guaccimanni, Via Baccarini, Via Rondinelli, Via Cavour (from Piazzetta Gandhi) and Via Ponte Marino 24 hours a day; Via Mariani, Via Guerrini and Via Matteucci only 7:30–20:30. GateLR uses 24 hours for the whole zone, to be safe.",
     "Orari dei varchi: via di Roma, via Guaccimanni, via Baccarini, via Rondinelli, via Cavour (da piazzetta Gandhi) e via Ponte Marino 24 ore su 24; via Mariani, via Guerrini e via Matteucci solo 7:30–20:30. GateLR usa 0–24 per tutta la zona, per prudenza.",
     "Kamerazeiten: Via di Roma, Via Guaccimanni, Via Baccarini, Via Rondinelli, Via Cavour (von der Piazzetta Gandhi) und Via Ponte Marino rund um die Uhr; Via Mariani, Via Guerrini und Via Matteucci nur 7:30–20:30. GateLR verwendet sicherheitshalber 0–24 für die ganze Zone."),
    ("Map outline and gate positions missing: the City publishes no perimeter as open data (its gate map is a picture without coordinates) and OpenStreetMap could not be downloaded from here.",
     "Mancano perimetro e posizione dei varchi: il Comune non pubblica un perimetro in open data (la mappa dei varchi è un'immagine senza coordinate) e OpenStreetMap non era scaricabile da qui.",
     "Grenze und Kamerastandorte fehlen: Die Stadt veröffentlicht keine Grenze als offene Daten (ihre Kamerakarte ist ein Bild ohne Koordinaten), und OpenStreetMap war von hier nicht ladbar."),
    ("Day permit 15 € (0:00–23:59), morning 8 € (0:00–11:59) or afternoon 8 € (12:00–23:59), from the grey «titanium» parking meters (coins without change or credit card), for vehicles up to 5 t. Display it on the dashboard; it allows parking in ZTL streets for up to 90 minutes with a parking disc, never in Piazza del Popolo or pedestrian areas.",
     "Permesso giornaliero 15 € (0–23:59), mattiniero 8 € (0–11:59) o pomeridiano 8 € (12–23:59), ai parcometri grigi «titanium» (monete senza resto o carta di credito), per veicoli fino a 5 t. Va esposto sul cruscotto; consente la sosta nelle vie della ZTL al massimo 90 minuti con disco orario, mai in Piazza del Popolo né nelle aree pedonali.",
     "Tagesgenehmigung 15 € (0–23:59), Vormittag 8 € (0–11:59) oder Nachmittag 8 € (12–23:59), an den grauen «Titanium»-Parkautomaten (Münzen ohne Wechselgeld oder Kreditkarte), für Fahrzeuge bis 5 t. Sichtbar aufs Armaturenbrett legen; erlaubt Parken in ZTL-Straßen bis 90 Minuten mit Parkscheibe, nie auf der Piazza del Popolo oder in Fußgängerzonen."),
    ("Hotels inside the ZTL send your plate to the City's SIRIO system (it is entered on the day it is sent) and give you a day badge for the windscreen. Ask the hotel to confirm. Disabled badge holders register up to two plates with the City's form.",
     "Gli alberghi dentro la ZTL comunicano la targa al sistema SIRIO del Comune (inserita alla data della comunicazione) e ti danno un contrassegno giornaliero da esporre. Chiedi conferma all'hotel. I titolari di contrassegno disabili registrano fino a due targhe con il modulo del Comune.",
     "Hotels in der ZTL melden dein Kennzeichen dem SIRIO-System der Stadt (es wird am Tag der Meldung eingetragen) und geben dir einen Tagesausweis für die Windschutzscheibe. Lass es dir vom Hotel bestätigen. Inhaber eines Behindertenausweises melden bis zu zwei Kennzeichen mit dem Formular der Stadt."),
    ("Electric and hybrid cars are not exempt (no exemption in the City's pages).",
     "Auto elettriche e ibride non esenti (nessuna esenzione nelle pagine del Comune).",
     "Elektro- und Hybridautos sind nicht befreit (keine Ausnahme auf den Seiten der Stadt)."),
]


def perimeter():
    """Solo da un file verificato salvato (mai disegnato a mano)"""
    f = RAW / "ztl_perimetro.geojson"
    if not f.exists():
        return []
    g = json.loads(f.read_text())
    g = g["features"][0]["geometry"] if "features" in g else g
    polys = [g["coordinates"]] if g["type"] == "Polygon" else g["coordinates"]
    return osm_geo.perimeter(max((p[0] for p in polys), key=osm_geo.area_km2), tol_m=4)


zone = {"id": "ravenna-ztl", "name": "Ravenna · Historic centre ZTL", "name_it": "Ravenna · ZTL Centro storico",
        "name_de": "Ravenna · ZTL Altstadt", "kind": "pass",
        "summary": "The historic centre (Piazza del Popolo, San Vitale) is watched by SIRIO cameras: most gates are on 24 hours a day, three only 7:30–20:30. Without a permit, buy a day permit (15 €, or 8 € for the morning or afternoon) at the grey parking meters before entering. If your hotel is inside, it registers your plate.",
        "summary_it": "Il centro storico (Piazza del Popolo, San Vitale) è controllato dalle telecamere SIRIO: la maggior parte dei varchi è accesa 24 ore su 24, tre solo 7:30–20:30. Senza permesso compra il giornaliero (15 €, o 8 € per mattina o pomeriggio) ai parcometri grigi prima di entrare. Se l'hotel è dentro, registra la tua targa.",
        "summary_de": "Die Altstadt (Piazza del Popolo, San Vitale) wird von SIRIO-Kameras überwacht: die meisten sind rund um die Uhr aktiv, drei nur 7:30–20:30. Ohne Genehmigung vor der Einfahrt an den grauen Parkautomaten eine Tagesgenehmigung kaufen (15 €, oder 8 € für Vormittag oder Nachmittag). Liegt dein Hotel innen, meldet es dein Kennzeichen.",
        "perimeter": perimeter(), "gates": [],
        "windows": [{"weekdays": EVERY_DAY, "start": 0, "end": 24 * 60}],
        "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": True,
        "ticket": {"price": 15.0,
                   "howTo": "Day permit 15 € (0:00–23:59), or 8 € for the morning (0:00–11:59) or afternoon (12:00–23:59), from the grey «titanium» parking meters, 24 hours a day, for vehicles up to 5 t: coins (no change) or credit card. Buy it before you pass the camera and display it on the dashboard.",
                   "howTo_it": "Permesso giornaliero 15 € (0–23:59), o 8 € per la mattina (0–11:59) o il pomeriggio (12–23:59), ai parcometri grigi «titanium», 24 ore su 24, per veicoli fino a 5 t: monete (senza resto) o carta di credito. Compralo prima di passare dal varco ed esponilo sul cruscotto.",
                   "howTo_de": "Tagesgenehmigung 15 € (0–23:59) oder 8 € für den Vormittag (0–11:59) bzw. Nachmittag (12–23:59), an den grauen «Titanium»-Parkautomaten, rund um die Uhr, für Fahrzeuge bis 5 t: Münzen (ohne Wechselgeld) oder Kreditkarte. Vor der Kamera kaufen und aufs Armaturenbrett legen.",
                   "url": AZIMUT, "deadline": "beforeEntry"},
        "source": {"authority": "City of Ravenna", "pageURL": SIRIO,
                   "ordinance": "Determinazione dirigenziale E 2/4 del 13/03/2006 (contrassegni ZTL); piano sosta e ZTL modificato dal 01/03/2026",
                   "ordinanceURL": DETERMINA,
                   "quote": QUOTE,
                   "quoteTranslation": "Through a network of cameras, the plates of vehicles entering through the «gates» are recognised and checked against the list of plates of vehicles allowed through",
                   "quoteTranslation_de": "Über ein Kameranetz werden die Kennzeichen der Fahrzeuge, die durch die «Tore» einfahren, erkannt und mit der Liste der zugelassenen Kennzeichen abgeglichen",
                   "checkedOn": CHECKED, "reviewedByHuman": False,
                   "pending": [p[0] for p in PENDING], "pending_it": [p[1] for p in PENDING], "pending_de": [p[2] for p in PENDING],
                   "links": LINKS}}

city = {"id": "ravenna", "name": "Ravenna", "name_it": "Ravenna", "name_de": "Ravenna",
        "center": {"lat": 44.4175, "lon": 12.1990}, "zones": [zone], "status": "draft",
        "license": "Rules: Comune di Ravenna and Azimut official pages. Perimeter: not yet available."}

# Controlli di plausibilità, quando c'è il perimetro: Piazza del Popolo dentro, la stazione fuori
if zone["perimeter"]:
    assert osm_geo.contains(zone["perimeter"], 44.4175, 12.1990), "Piazza del Popolo fuori dal perimetro"
    assert not osm_geo.contains(zone["perimeter"], 44.4182, 12.2088), "stazione di Ravenna dentro il perimetro"

ready = all(len(z["perimeter"]) >= 5 and z["source"]["quote"] for z in city["zones"])
out = ROOT / ("Resources/Cities/ravenna.json" if ready else "data/drafts/ravenna.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/ravenna.json" if ready else "Resources/Cities/ravenna.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), [(z["id"], len(z["perimeter"]), len(z["gates"])) for z in city["zones"]])
