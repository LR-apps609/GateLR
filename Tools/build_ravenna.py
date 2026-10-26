#!/usr/bin/env python3
# Costruisce la scheda di Ravenna (bozza) da quanto salvato in data/raw/ravenna/ (fonti e date in docs/fonti-ravenna.md).
#
# Il 26/10/2026 dal sandbox nessun sito del Comune (comune.ravenna.it, comune.ra.it), di Azimut (sosta e permessi),
# di OpenStreetMap/Overpass o dell'open data regionale era raggiungibile (il proxy rifiuta la connessione, 403): le regole
# vengono solo dai riassunti della ricerca web (data/raw/ravenna/websearch-*.txt), che citano le pagine ufficiali ma non
# sono testo letterale. Per questo nessuna citazione («quote»: null) e nessun perimetro: su dati.gov.it non c'è un
# perimetro ufficiale della ZTL di Ravenna, quindi andrà ricavato da OSM (relazione con il nome ufficiale, o strade
# dell'elenco ufficiale con osm_geo.street_area) e salvato come data/raw/ravenna/ztl_perimetro.geojson (WGS84).
# La scheda resta in data/drafts/ravenna.json finché perimetro e citazione non ci sono (vedi «ready»).
# Uso: python3 Tools/build_ravenna.py   (non tocca le altre città né manifest.json)
import json, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/ravenna"
CHECKED = "2026-10-26T23:00:00Z"
EVERY_DAY = [1, 2, 3, 4, 5, 6, 7]

SIRIO = "https://comune.ravenna.it/altro-contenuto/sirio-controllo-accessi-in-ztl/"
PLATES = "https://comune.ravenna.it/servizi/autorizzazioni/comunicazione-targhe-di-veicoli-abilitati-a-circolare-in-zona-a-traffico-limitato-di-ravenna-sirio/"
PRESS_2026 = "https://comune.ravenna.it/novita/comunicato-stampa/in-seguito-agli-incontri-pubblici-approvata-la-modifica-alla-delibera-del-piano-che-disciplina-circolazione-e-sosta-nel-comune-di-ravenna/"
AZIMUT = "https://www.azimut-spa.it/ita/Servizi/Sosta/Permessi-giornalieri-ZTL"
TOURISM = "https://www.turismo.ra.it/en/getting-around-ravenna/limited-traffic-zone-ltz/"
DISABLED = "https://comune.ravenna.it/amministrazione/documenti-e-dati/modulistica/modulo-comunicazione-targhe-persone-invalide-accesso-sirio-ztl/"


def flat(s):
    return re.sub(r"\s+", " ", s).strip()


TEXT = {p.stem: flat(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def check(file, *phrases):
    """Ogni fatto usato deve comparire, parola per parola, nel testo salvato (qui: riassunti della ricerca)"""
    for q in phrases:
        if flat(q) not in TEXT[file]:
            raise SystemExit(f"{file}: frase non trovata: {q!r}")


check("websearch-1-varchi-orari", "six active around the clock: via di Roma, via Guaccimanni, via Baccarini, via Rondinelli, via Cavour (entrance from piazzetta Gandhi), and via Ponte Marino",
      "Three run 7:30–20:30: via Mariani, via Guerrini, and via Matteucci.",
      "Accessibilitacentristorici lists via Ponte Marino as 7:30–20:30, not 24 hours",
      "The daily ZTL permit is issued 24 hours a day from ticket machines (parcometri) for vehicles up to 5 tonnes.")
check("websearch-2-hotel-permesso", "Chi alloggia in albergo può invece far comunicare la targa dalla struttura.",
      "l'alimentazione ibrida o elettrica non è un lasciapassare (guida non ufficiale)")
check("websearch-3-tariffe-2026", "il permesso mezza giornata come valido dalle 00 fino alle 12 oppure dalle 12 alle 24, a 8 euro",
      "il giornaliero resta a 15 euro per la giornata intera", "Novità in vigore dal 1° marzo 2026")
check("websearch-4-sirio-targhe", "entro cinque giorni successivi dall’accesso in ZTL", "No source mentions a 48-hour deadline.",
      "Modulo comunicazione targhe persone invalide")


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


LINKS = [link("City of Ravenna: SIRIO, ZTL gates and hours", "Comune di Ravenna: SIRIO, varchi e orari della ZTL",
              "Stadt Ravenna: SIRIO, ZTL-Kameras und Zeiten", SIRIO),
         link("City of Ravenna: registering plates allowed in the ZTL (hotels)", "Comune di Ravenna: comunicazione targhe abilitate in ZTL (strutture ricettive)",
              "Stadt Ravenna: Meldung berechtigter Kennzeichen in der ZTL (Hotels)", PLATES),
         link("City of Ravenna: changes to parking and ZTL rules from 1 March 2026", "Comune di Ravenna: modifiche al piano sosta e ZTL dal 1° marzo 2026",
              "Stadt Ravenna: Änderungen bei Parken und ZTL ab 1. März 2026", PRESS_2026),
         link("Azimut: daily ZTL permits from parking meters", "Azimut: permessi giornalieri ZTL ai parcometri",
              "Azimut: ZTL-Tagesgenehmigungen am Parkautomaten", AZIMUT),
         link("City of Ravenna: form for disabled badge holders", "Comune di Ravenna: modulo targhe per persone invalide",
              "Stadt Ravenna: Formular für Inhaber eines Behindertenausweises", DISABLED),
         link("Ravenna Tourism: limited traffic zone", "Ravenna Turismo: zona a traffico limitato", "Ravenna Tourismus: verkehrsberuhigte Zone", TOURISM)]

PENDING = [
    ("Draft: the City's websites could not be read from here (connection refused). Every rule below is taken from web-search summaries of the official pages, not from their text: to be checked word for word.",
     "Bozza: i siti del Comune non erano leggibili da qui (connessione rifiutata). Ogni regola viene dai riassunti della ricerca web sulle pagine ufficiali, non dal loro testo: da verificare parola per parola.",
     "Entwurf: Die Websites der Stadt waren von hier aus nicht lesbar (Verbindung abgelehnt). Alle Regeln stammen aus Zusammenfassungen der Websuche zu den offiziellen Seiten, nicht aus deren Text: Wort für Wort zu prüfen."),
    ("Gate hours: via di Roma, via Guaccimanni, via Baccarini, via Rondinelli, via Cavour (from piazzetta Gandhi) and via Ponte Marino 24 hours; via Mariani, via Guerrini and via Matteucci only 7:30–20:30 (via Ponte Marino also 7:30–20:30 in an unofficial guide). GateLR uses 24 hours for the whole zone, to be safe.",
     "Orari dei varchi: via di Roma, via Guaccimanni, via Baccarini, via Rondinelli, via Cavour (da piazzetta Gandhi) e via Ponte Marino 24 ore su 24; via Mariani, via Guerrini e via Matteucci solo 7:30–20:30 (via Ponte Marino 7:30–20:30 secondo una guida non ufficiale). GateLR usa 0–24 per tutta la zona, per prudenza.",
     "Kamerazeiten: Via di Roma, Via Guaccimanni, Via Baccarini, Via Rondinelli, Via Cavour (von der Piazzetta Gandhi) und Via Ponte Marino rund um die Uhr; Via Mariani, Via Guerrini und Via Matteucci nur 7:30–20:30 (Via Ponte Marino laut einem inoffiziellen Ratgeber ebenfalls 7:30–20:30). GateLR verwendet sicherheitshalber 0–24 für die ganze Zone."),
    ("Map outline and gate positions missing: no official open data found, OpenStreetMap could not be downloaded from here.",
     "Mancano perimetro e posizione dei varchi: nessun open data ufficiale trovato, OpenStreetMap non scaricabile da qui.",
     "Grenze und Kamerastandorte fehlen: keine offiziellen offenen Daten gefunden, OpenStreetMap von hier nicht ladbar."),
    ("Hotels: the hotel sends your plate to the City (SIRIO, form for accommodation); an older City page allows sending it within five days after entering. Ask the hotel to confirm.",
     "Alberghi: l'hotel comunica la targa al Comune (SIRIO, contrassegno per strutture ricettive); una pagina meno recente del Comune consente l'invio entro cinque giorni dall'accesso. Chiedi conferma all'hotel.",
     "Hotels: Das Hotel meldet dein Kennzeichen der Stadt (SIRIO, Formular für Unterkünfte); eine ältere Seite der Stadt erlaubt die Meldung bis fünf Tage nach der Einfahrt. Lass es dir vom Hotel bestätigen."),
    ("Day permit 15 €, half day 8 € (0–12 or 12–24) since 1 March 2026, from enabled parking meters (vehicles up to 5 t). Price and the half-day option come from the City's February 2026 press release as reported by local news.",
     "Permesso giornaliero 15 €, mezza giornata 8 € (0–12 o 12–24) dal 1° marzo 2026, ai parcometri abilitati (veicoli fino a 5 t). Prezzo e mezza giornata vengono dal comunicato del Comune di febbraio 2026 ripreso dalla stampa locale.",
     "Tagesgenehmigung 15 €, halber Tag 8 € (0–12 oder 12–24) seit 1. März 2026, an freigeschalteten Parkautomaten (Fahrzeuge bis 5 t). Preis und Halbtagesoption stammen aus der Pressemitteilung der Stadt vom Februar 2026, berichtet von Lokalmedien."),
    ("Electric and hybrid cars are not exempt (confirmed only by an unofficial guide). Disabled badge holders register the plate with the City's form.",
     "Auto elettriche e ibride non esenti (confermato solo da una guida non ufficiale). I titolari di contrassegno disabili comunicano la targa con il modulo del Comune.",
     "Elektro- und Hybridautos sind nicht befreit (nur von einem inoffiziellen Ratgeber bestätigt). Inhaber eines Behindertenausweises melden das Kennzeichen mit dem Formular der Stadt."),
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
        "summary": "The historic centre (Piazza del Popolo, San Vitale) is watched by SIRIO cameras: most gates are on 24 hours a day, a few only 7:30–20:30. Without a permit you can buy a day permit (15 €, or 8 € for half a day) at the enabled parking meters before entering. If your hotel is inside, it registers your plate.",
        "summary_it": "Il centro storico (Piazza del Popolo, San Vitale) è controllato dalle telecamere SIRIO: la maggior parte dei varchi è accesa 24 ore su 24, alcuni solo 7:30–20:30. Senza permesso puoi comprare un permesso giornaliero (15 €, o 8 € per mezza giornata) ai parcometri abilitati prima di entrare. Se l'hotel è dentro, registra la tua targa.",
        "summary_de": "Die Altstadt (Piazza del Popolo, San Vitale) wird von SIRIO-Kameras überwacht: die meisten Kameras sind rund um die Uhr aktiv, einige nur 7:30–20:30. Ohne Genehmigung kannst du vor der Einfahrt an freigeschalteten Parkautomaten eine Tagesgenehmigung kaufen (15 €, halber Tag 8 €). Liegt dein Hotel in der Zone, meldet es dein Kennzeichen.",
        "perimeter": perimeter(), "gates": [],
        "windows": [{"weekdays": EVERY_DAY, "start": 0, "end": 24 * 60}],
        "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": True,
        "ticket": {"price": 15.0,
                   "howTo": "Day permit 15 € (half day 8 €: 0–12 or 12–24), from the enabled parking meters, 24 hours a day, for vehicles up to 5 t. Buy it before you pass the camera.",
                   "howTo_it": "Permesso giornaliero 15 € (mezza giornata 8 €: 0–12 o 12–24), ai parcometri abilitati, 24 ore su 24, per veicoli fino a 5 t. Compralo prima di passare dal varco.",
                   "howTo_de": "Tagesgenehmigung 15 € (halber Tag 8 €: 0–12 oder 12–24), an freigeschalteten Parkautomaten, rund um die Uhr, für Fahrzeuge bis 5 t. Vor der Kamera kaufen.",
                   "url": AZIMUT, "deadline": "beforeEntry"},
        "source": {"authority": "City of Ravenna", "pageURL": SIRIO, "ordinance": None, "ordinanceURL": None,
                   "quote": None, "quoteTranslation": None, "quoteTranslation_de": None,
                   "checkedOn": CHECKED, "reviewedByHuman": False,
                   "pending": [p[0] for p in PENDING], "pending_it": [p[1] for p in PENDING], "pending_de": [p[2] for p in PENDING],
                   "links": LINKS}}

city = {"id": "ravenna", "name": "Ravenna", "name_it": "Ravenna", "name_de": "Ravenna",
        "center": {"lat": 44.4175, "lon": 12.1990}, "zones": [zone], "status": "draft",
        "license": "Rules: Comune di Ravenna and Azimut official pages (read through web-search summaries). Perimeter: not yet available."}

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
