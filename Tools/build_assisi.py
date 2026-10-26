#!/usr/bin/env python3
# Costruisce la scheda di Assisi (bozza) da quanto salvato in data/raw/assisi/ (fonti e date in docs/fonti-assisi.md).
#
# Il 26/10/2026 dal sandbox né il sito del Comune (comune.assisi.pg.it, albo pretorio) né OpenStreetMap/Overpass erano
# raggiungibili (il proxy rifiuta la connessione, 403): le regole vengono solo dai riassunti della ricerca web
# (data/raw/assisi/websearch-*.txt), che riportano il comunicato del Comune sui varchi elettronici (in funzione con
# multe dal 16/09/2026) come ripreso dalla stampa locale. Per questo nessuna citazione ufficiale («quote»: null) e nessun
# perimetro: su dati.gov.it non c'è un perimetro della ZTL di Assisi, quindi andrà ricavato da OSM (relazione con il nome
# ufficiale, o strade raggiungibili solo dai 5 varchi come in build_perugia.py) e salvato come
# data/raw/assisi/ztl_perimetro.geojson (WGS84). La scheda resta in data/drafts/assisi.json (vedi «ready»).
# Uso: python3 Tools/build_assisi.py   (non tocca le altre città né manifest.json)
import json, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/assisi"
CHECKED = "2026-10-26T23:00:00Z"
MON_FRI, SAT_SUN = [2, 3, 4, 5, 6], [7, 1]

PERMIT = "https://www.comune.assisi.pg.it/servizi/mobilita_e_trasporti/servizio_23.html"
NEWS = "https://www.assisinews.it/cronaca/dal-16-settembre-entrano-in-funzione-i-varchi-elettronici-con-multe-in-caso-di-violazioni/"
VISIT = "https://www.visit-assisi.it/muoversi-in-citta/"
TERRE = "https://terrenostre.info/2026/09/ztlassisi-16092026-in-funzione-varchi-elettronici/"


def flat(s):
    return re.sub(r"\s+", " ", s).strip()


TEXT = {p.stem: flat(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def check(file, *phrases):
    """Ogni fatto usato deve comparire, parola per parola, nel testo salvato (qui: riassunti della ricerca)"""
    for q in phrases:
        if flat(q) not in TEXT[file]:
            raise SystemExit(f"{file}: frase non trovata: {q!r}")


check("websearch-1-varchi-orari-hotel", "Giorni feriali: dalle 11.00 alle 12.30 e dalle 15.30 alle 17.30.",
      "Giorni prefestivi e festivi: dalle 11.00 alle 20.00.",
      "dal 16 settembre 2026 entreranno pienamente in funzione i varchi elettronici",
      "Porta San Giacomo, Largo Properzio, via Porta Perlici, via Marconi (in prossimità del parcheggio Giovanni Paolo II) e via del Turrione",
      "per le sole operazioni di carico e scarico bagagli della durata massima di 60 minuti",
      "I veicoli ad alimentazione esclusivamente elettrica possono accedere e sostare all'interno della ZTL")
check("websearch-2-hotel-disabili", "prima dell'accesso, o entro le 72 ore successive", "ha annunciato un ricorso al TAR",
      "Porta Nuova non è tra questi.")
check("websearch-3-date-multe", "No source in this search confirms the hours", "84 euro, reduced to 58.10 euro")


def hm(h, m=0):
    return h * 60 + m


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


LINKS = [link("City of Assisi: ZTL permit", "Comune di Assisi: permesso per ZTL", "Stadt Assisi: ZTL-Genehmigung", PERMIT),
         link("Assisi News: electronic gates with fines from 16 September 2026", "Assisi News: varchi elettronici con multe dal 16 settembre 2026",
              "Assisi News: elektronische Kameras mit Bußgeldern ab 16. September 2026", NEWS),
         link("Terrenostre: ZTL gates in operation from 16 September 2026", "Terrenostre: varchi ZTL in funzione dal 16 settembre 2026",
              "Terrenostre: ZTL-Kameras ab 16. September 2026 in Betrieb", TERRE),
         link("Visit Assisi: getting around (hotel guests)", "Visit Assisi: muoversi in città (ospiti degli hotel)",
              "Visit Assisi: unterwegs in der Stadt (Hotelgäste)", VISIT)]

PENDING = [
    ("Draft: the City's website could not be read from here (connection refused). Hours and rules come from the City's announcement of the electronic gates as reported by local news (Assisi News, Vivo Umbria), read through web-search summaries: to be checked against the City's order.",
     "Bozza: il sito del Comune non era leggibile da qui (connessione rifiutata). Orari e regole vengono dal comunicato del Comune sui varchi elettronici ripreso dalla stampa locale (Assisi News, Vivo Umbria), letto tramite i riassunti della ricerca web: da verificare sull'ordinanza del Comune.",
     "Entwurf: Die Website der Stadt war von hier aus nicht lesbar (Verbindung abgelehnt). Zeiten und Regeln stammen aus der Mitteilung der Stadt zu den elektronischen Kameras, berichtet von Lokalmedien (Assisi News, Vivo Umbria), gelesen über Zusammenfassungen der Websuche: mit der Anordnung der Stadt abzugleichen."),
    ("Closed hours: weekdays 11:00–12:30 and 15:30–17:30; days before holidays and holidays 11:00–20:00 (confirmed only by Assisi News). GateLR treats every Saturday as a day before a holiday; other days before a holiday (e.g. 24 December) use the weekday hours.",
     "Orari di chiusura: feriali 11–12:30 e 15:30–17:30; prefestivi e festivi 11–20 (confermato solo da Assisi News). GateLR tratta ogni sabato come prefestivo; gli altri prefestivi (es. 24 dicembre) usano l'orario feriale.",
     "Sperrzeiten: werktags 11–12:30 und 15:30–17:30; Tage vor Feiertagen und Feiertage 11–20 Uhr (nur von Assisi News bestätigt). GateLR behandelt jeden Samstag als Vortag eines Feiertags; andere Vortage (z. B. 24. Dezember) haben die Werktagszeiten."),
    ("Map outline and gate positions missing. The five gates are Porta San Giacomo, Largo Properzio, Via Porta Perlici, Via Marconi (near the Giovanni Paolo II car park) and Via del Turrione.",
     "Mancano perimetro e posizione dei varchi. I cinque varchi sono Porta San Giacomo, Largo Properzio, via Porta Perlici, via Marconi (vicino al parcheggio Giovanni Paolo II) e via del Turrione.",
     "Grenze und Kamerastandorte fehlen. Die fünf Kameras stehen an Porta San Giacomo, Largo Properzio, Via Porta Perlici, Via Marconi (beim Parkplatz Giovanni Paolo II) und Via del Turrione."),
    ("Hotels: cars going to a hotel may enter only to load and unload luggage, max 60 minutes; give the hotel your plate and arrival/departure dates and display its note on the windscreen. Holiday-rental owners (Altea) say their guests are no longer covered and announced an appeal to the regional court.",
     "Alberghi: le auto dirette agli alberghi entrano solo per carico e scarico bagagli, massimo 60 minuti; dai all'hotel targa e giorni di arrivo e partenza ed esponi la sua comunicazione sul parabrezza. I gestori di locazioni turistiche (Altea) dicono che i loro ospiti non sono più coperti e hanno annunciato ricorso al TAR.",
     "Hotels: Autos zu Hotels dürfen nur zum Be- und Entladen des Gepäcks einfahren, höchstens 60 Minuten; gib dem Hotel Kennzeichen sowie An- und Abreisetag und lege seine Bescheinigung hinter die Windschutzscheibe. Vermieter von Ferienwohnungen (Altea) sagen, ihre Gäste seien nicht mehr erfasst, und kündigten eine Klage an."),
    ("Fully electric cars may enter and park (except in reserved spaces), but it is not confirmed whether a foreign plate is recognised without registering it: GateLR does not exempt them. Disabled badge holders register up to two plates, before entering or within 72 hours (permessivarchi@comune.assisi.pg.it).",
     "Le auto solo elettriche possono entrare e sostare (salvo gli stalli riservati), ma non è confermato che una targa estera sia riconosciuta senza registrarla: GateLR non le esenta. I titolari di contrassegno disabili comunicano fino a due targhe, prima dell'accesso o entro 72 ore (permessivarchi@comune.assisi.pg.it).",
     "Reine Elektroautos dürfen einfahren und parken (außer auf reservierten Plätzen), ob ein ausländisches Kennzeichen ohne Anmeldung erkannt wird, ist aber nicht bestätigt: GateLR befreit sie nicht. Inhaber eines Behindertenausweises melden bis zu zwei Kennzeichen, vor der Einfahrt oder innerhalb von 72 Stunden (permessivarchi@comune.assisi.pg.it)."),
    ("4 October (Saint Francis, patron of Assisi) is treated as a holiday (11:00–20:00).",
     "Il 4 ottobre (San Francesco, patrono di Assisi) è trattato come festivo (11–20).",
     "Der 4. Oktober (Franz von Assisi, Stadtpatron) wird als Feiertag behandelt (11–20 Uhr)."),
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


zone = {"id": "assisi-ztl", "name": "Assisi · Historic centre ZTL", "name_it": "Assisi · ZTL Centro storico",
        "name_de": "Assisi · ZTL Altstadt", "kind": "restricted",
        "summary": "Since 16 September 2026 five cameras guard the old town. It is closed to unauthorised vehicles on weekdays 11:00–12:30 and 15:30–17:30, and on Saturdays, Sundays and holidays 11:00–20:00; outside those hours you may drive in. Hotel guests may enter only to unload luggage (max 60 minutes): give your plate to the hotel.",
        "summary_it": "Dal 16 settembre 2026 cinque telecamere controllano il centro storico. È chiuso ai veicoli non autorizzati nei feriali 11–12:30 e 15:30–17:30, e il sabato, la domenica e i festivi 11–20; fuori da questi orari si entra. Gli ospiti degli hotel entrano solo per scaricare i bagagli (massimo 60 minuti): dai la targa all'hotel.",
        "summary_de": "Seit 16. September 2026 überwachen fünf Kameras die Altstadt. Sie ist für nicht berechtigte Fahrzeuge werktags 11–12:30 und 15:30–17:30 Uhr gesperrt, samstags, sonntags und an Feiertagen 11–20 Uhr; außerhalb dieser Zeiten darf man hinein. Hotelgäste dürfen nur zum Ausladen einfahren (höchstens 60 Minuten): Kennzeichen dem Hotel geben.",
        "perimeter": perimeter(), "gates": [],
        "windows": [{"weekdays": MON_FRI, "start": hm(11), "end": hm(12, 30)},
                    {"weekdays": MON_FRI, "start": hm(15, 30), "end": hm(17, 30)},
                    {"weekdays": SAT_SUN, "start": hm(11), "end": hm(20)}],
        "freeOnHolidays": False, "holidaysAsSunday": True, "exemptFuels": [], "hotelCanRegister": True,
        "source": {"authority": "City of Assisi", "pageURL": PERMIT, "ordinance": None, "ordinanceURL": None,
                   "quote": None, "quoteTranslation": None, "quoteTranslation_de": None,
                   "checkedOn": CHECKED, "reviewedByHuman": False,
                   "pending": [p[0] for p in PENDING], "pending_it": [p[1] for p in PENDING], "pending_de": [p[2] for p in PENDING],
                   "links": LINKS}}

city = {"id": "assisi", "name": "Assisi", "name_it": "Assisi", "name_de": "Assisi",
        "center": {"lat": 43.0707, "lon": 12.6171}, "zones": [zone], "status": "draft", "localHolidays": ["10-04"],
        "license": "Rules: Comune di Assisi announcement as reported by local news (read through web-search summaries). Perimeter: not yet available."}

# Controlli di plausibilità, quando c'è il perimetro: Piazza del Comune dentro, la stazione (Santa Maria degli Angeli) fuori
if zone["perimeter"]:
    assert osm_geo.contains(zone["perimeter"], 43.0707, 12.6171), "Piazza del Comune fuori dal perimetro"
    assert not osm_geo.contains(zone["perimeter"], 43.0585, 12.5835), "stazione di Assisi dentro il perimetro"

ready = all(len(z["perimeter"]) >= 5 and z["source"]["quote"] for z in city["zones"])
out = ROOT / ("Resources/Cities/assisi.json" if ready else "data/drafts/assisi.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/assisi.json" if ready else "Resources/Cities/assisi.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), [(z["id"], len(z["perimeter"]), len(z["gates"])) for z in city["zones"]])
