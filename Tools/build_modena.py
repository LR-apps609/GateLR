#!/usr/bin/env python3
# Costruisce la scheda di Modena (bozza) da quanto salvato in data/raw/modena/ (fonti e date in docs/fonti-modena.md).
#
# Il 26/10/2026 dal sandbox nessun sito del Comune (comune.modena.it, geonext.comune.modena.it, opendata), di Modena
# Parcheggi, di VisitModena, di OpenStreetMap/Overpass o dell'open data regionale era raggiungibile (il proxy rifiuta la
# connessione, 403): le regole vengono solo dai riassunti della ricerca web (data/raw/modena/websearch-*.txt), che citano
# le pagine ufficiali ma non sono testo letterale. Per questo:
#   - nessuna citazione («quote»: null) finché non si salva il testo del «Testo coordinato Ordinanza ZTL» (sezione B6);
#   - nessun perimetro: esiste un perimetro UFFICIALE in open data (WFS «Modena:Ztl_preview» su geonext.comune.modena.it,
#     catalogato su dati.gov.it), da salvare come data/raw/modena/ztl_perimetro.geojson (WGS84);
#   - la scheda resta in data/drafts/modena.json (vedi «ready»).
# Uso: python3 Tools/build_modena.py   (non tocca le altre città né manifest.json)
import json, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/modena"
CHECKED = "2026-10-26T23:00:00Z"
EVERY_DAY = [1, 2, 3, 4, 5, 6, 7]

ORDINANCE_PAGE = "https://www.comune.modena.it/amministrazione/documenti-e-dati/atti-normativi/ordinanze/ordinanze-a-carattere-generale/testo-coordinato-ordinanza-ztl"
ORDINANCE_PDF = ORDINANCE_PAGE + "/testo-coordinato-ordinanza-ztl/@@download/file_principale"
VISIT = "https://www.visitmodena.it/en/plan-the-trip/lta-limited-traffic-area"
PARKING = "https://www.visitmodena.it/en/plan-the-trip/tourist-services/parking-lots"
ELECTRIC = "https://www.comune.modena.it/amministrazione/documenti-e-dati/modulistica/mobilita-e-trasporti/ztl-e-sosta-a-pagamento-1/veicoli-elettrici/comunicazione-targhe-veicoli-elettrici-per-residenti-a-modena-senza-contrassegno/"
DISABLED = "https://www.comune.modena.it/amministrazione/documenti-e-dati/modulistica/mobilita-e-trasporti/ztl-e-sosta-a-pagamento-1/invalidi-e-persone-con-disabilita/comunicazione-targhe-veicoli-al-servizio-di-persone-con-disabilita-di-altro-comune/"
WFS = "https://geonext.comune.modena.it/geoservernext//Modena/Ztl_preview/wfs?service=WFS&version=2.0.0&request=GetCapabilities"


def flat(s):
    return re.sub(r"\s+", " ", s).strip()


TEXT = {p.stem: flat(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def check(file, *phrases):
    """Ogni fatto usato deve comparire, parola per parola, nel testo salvato (qui: riassunti della ricerca)"""
    for q in phrases:
        if flat(q) not in TEXT[file]:
            raise SystemExit(f"{file}: frase non trovata: {q!r}")


check("websearch-1-orari-permessi", "One guide says the ZTL is active every day, 24 hours a day, with no free time band.",
      "lists separate bands for specific streets, such as Via Emilia Centro and Corso Duomo",
      "for entry between 20:00 and 06:00, notice must reach the Polizia Municipale before or within 48 hours after access")
check("websearch-2-hotel-elettriche-disabili", "prima dell'ingresso oppure entro 48 ore dall'accesso",
      "L'ospite non deve fare la comunicazione. La struttura espone poi un contrassegno sul parabrezza.",
      "riguarda i residenti senza contrassegno")
check("websearch-3-ordinanza", "delibera di Giunta n. 115 del 10/03/2020, che ha eliminato la franchigia oraria",
      "B6) Fasce orarie per la circolazione all'interno della ZTL", "Protocollo n. 85253 del 01 aprile 2020")
check("websearch-4-visitmodena", "The notification must be made within 48 hours of access.",
      "Rental companies don't hold a permit for these areas.", "nothing found on new gates or ordinances for 2026")


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


LINKS = [link("City of Modena: consolidated ZTL order", "Comune di Modena: testo coordinato ordinanza ZTL",
              "Stadt Modena: konsolidierte ZTL-Anordnung", ORDINANCE_PAGE),
         link("VisitModena: limited traffic area (hotel guests)", "VisitModena: zona a traffico limitato (ospiti degli hotel)",
              "VisitModena: verkehrsberuhigte Zone (Hotelgäste)", VISIT),
         link("VisitModena: car parks", "VisitModena: parcheggi", "VisitModena: Parkplätze", PARKING),
         link("City of Modena: electric vehicles, plate registration", "Comune di Modena: veicoli elettrici, comunicazione targhe",
              "Stadt Modena: Elektrofahrzeuge, Kennzeichenmeldung", ELECTRIC),
         link("City of Modena: disabled badge from another town, plate registration",
              "Comune di Modena: contrassegno disabili di altro comune, comunicazione targhe",
              "Stadt Modena: Behindertenausweis aus einer anderen Gemeinde, Kennzeichenmeldung", DISABLED),
         link("City of Modena: official ZTL perimeter, open data (WFS)", "Comune di Modena: perimetro ufficiale ZTL, open data (WFS)",
              "Stadt Modena: offizielle ZTL-Grenze, offene Daten (WFS)", WFS)]

PENDING = [
    ("Draft: the City's websites could not be read from here (connection refused). Every rule below is taken from web-search summaries of the official pages, not from their text: to be checked word for word.",
     "Bozza: i siti del Comune non erano leggibili da qui (connessione rifiutata). Ogni regola viene dai riassunti della ricerca web sulle pagine ufficiali, non dal loro testo: da verificare parola per parola.",
     "Entwurf: Die Websites der Stadt waren von hier aus nicht lesbar (Verbindung abgelehnt). Alle Regeln stammen aus Zusammenfassungen der Websuche zu den offiziellen Seiten, nicht aus deren Text: Wort für Wort zu prüfen."),
    ("Hours not confirmed: the 2020 consolidated order (Council decision 115/2020 removed the free time band) has its timetable in section B6, not read. Unofficial guides say 24 hours every day, others 7:30–20:30; Via Emilia Centro and Corso Duomo have their own bands. GateLR uses 24 hours, to be safe.",
     "Orari non confermati: il testo coordinato del 2020 (la delibera GC 115/2020 ha eliminato la franchigia oraria) ha le fasce nella sezione B6, non letta. Guide non ufficiali dicono 0–24 tutti i giorni, altre 7:30–20:30; via Emilia Centro e Corso Duomo hanno fasce proprie. GateLR usa 0–24, per prudenza.",
     "Zeiten nicht bestätigt: Die konsolidierte Anordnung von 2020 (Beschluss 115/2020 hob das zeitliche Freifenster auf) hat die Zeiten in Abschnitt B6, nicht gelesen. Inoffizielle Ratgeber nennen rund um die Uhr, andere 7:30–20:30; Via Emilia Centro und Corso Duomo haben eigene Zeiten. GateLR verwendet sicherheitshalber 0–24."),
    ("Map outline missing: the City publishes an official perimeter as open data (WFS «Ztl_preview»), which could not be downloaded from here. Gate positions unknown.",
     "Manca il perimetro: il Comune pubblica un perimetro ufficiale in open data (WFS «Ztl_preview»), non scaricabile da qui. Posizione dei varchi sconosciuta.",
     "Grenze fehlt: Die Stadt veröffentlicht eine offizielle Grenze als offene Daten (WFS «Ztl_preview»), die von hier nicht geladen werden konnte. Kamerastandorte unbekannt."),
    ("Hotels: guests of hotels, B&Bs and guest houses inside the ZTL may enter and park nearby with the hotel's badge on the windscreen; the hotel sends your plate to the municipal police before you enter or within 48 hours. Rental cars have no permit of their own.",
     "Alberghi: gli ospiti di alberghi, B&B e affittacamere dentro la ZTL entrano e sostano vicino con il contrassegno della struttura sul parabrezza; la struttura invia la targa alla Polizia municipale prima dell'ingresso o entro 48 ore. Le auto a noleggio non hanno un permesso proprio.",
     "Hotels: Gäste von Hotels, B&Bs und Pensionen in der ZTL dürfen mit dem Ausweis der Unterkunft hinter der Windschutzscheibe einfahren und in der Nähe parken; die Unterkunft meldet dein Kennzeichen vor der Einfahrt oder innerhalb von 48 Stunden der Stadtpolizei. Mietwagen haben keine eigene Genehmigung."),
    ("No tourist ticket found: temporary permits (one guide says 4 €) are for listed categories, online with SPID/CIE/CNS. Fully electric cars can be registered to drive at any hour, but the City's form found is for Modena residents.",
     "Nessun ticket per turisti trovato: i permessi temporanei (4 € secondo una guida) sono per categorie previste, online con SPID/CIE/CNS. Le auto solo elettriche possono essere registrate per circolare senza limiti di orario, ma il modulo trovato è per i residenti a Modena.",
     "Kein Touristenticket gefunden: befristete Genehmigungen (laut einem Ratgeber 4 €) gibt es für bestimmte Gruppen, online mit SPID/CIE/CNS. Reine Elektroautos können für die Zufahrt zu jeder Zeit gemeldet werden, das gefundene Formular gilt aber für Einwohner von Modena."),
]


def perimeter():
    """Solo da un file ufficiale salvato (mai disegnato a mano)"""
    f = RAW / "ztl_perimetro.geojson"
    if not f.exists():
        return []
    g = json.loads(f.read_text())
    g = g["features"][0]["geometry"] if "features" in g else g
    polys = [g["coordinates"]] if g["type"] == "Polygon" else g["coordinates"]
    return osm_geo.perimeter(max((p[0] for p in polys), key=osm_geo.area_km2), tol_m=4)


zone = {"id": "modena-ztl", "name": "Modena · Historic centre ZTL", "name_it": "Modena · ZTL Centro storico",
        "name_de": "Modena · ZTL Altstadt", "kind": "restricted",
        "summary": "The historic centre inside the ring boulevards (Duomo, Piazza Grande) is watched by cameras around the clock: without an authorisation you may not drive in. If your hotel is inside, it registers your plate (before you arrive or within 48 hours) and gives you a badge for the windscreen. Otherwise park outside and walk.",
        "summary_it": "Il centro storico dentro i viali (Duomo, Piazza Grande) è controllato dalle telecamere 24 ore su 24: senza autorizzazione non si entra. Se l'hotel è dentro, registra la tua targa (prima dell'arrivo o entro 48 ore) e ti dà un contrassegno per il parabrezza. Altrimenti parcheggia fuori e vai a piedi.",
        "summary_de": "Die Altstadt innerhalb der Ringstraßen (Dom, Piazza Grande) wird rund um die Uhr von Kameras überwacht: ohne Genehmigung darfst du nicht hineinfahren. Liegt dein Hotel innen, meldet es dein Kennzeichen (vorher oder innerhalb von 48 Stunden) und gibt dir einen Ausweis für die Windschutzscheibe. Sonst draußen parken und zu Fuß gehen.",
        "perimeter": perimeter(), "gates": [],
        "windows": [{"weekdays": EVERY_DAY, "start": 0, "end": 24 * 60}],
        "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": True,
        "source": {"authority": "City of Modena", "pageURL": ORDINANCE_PAGE,
                   "ordinance": "Testo coordinato Ordinanza ZTL (prot. 85253 del 01/04/2020; DGC 115 del 10/03/2020)",
                   "ordinanceURL": ORDINANCE_PDF, "quote": None, "quoteTranslation": None, "quoteTranslation_de": None,
                   "checkedOn": CHECKED, "reviewedByHuman": False,
                   "pending": [p[0] for p in PENDING], "pending_it": [p[1] for p in PENDING], "pending_de": [p[2] for p in PENDING],
                   "links": LINKS}}

city = {"id": "modena", "name": "Modena", "name_it": "Modena", "name_de": "Modena",
        "center": {"lat": 44.6464, "lon": 10.9255}, "zones": [zone], "status": "draft",
        "license": "Rules: Comune di Modena official pages (read through web-search summaries). Perimeter: not yet available."}

# Controlli di plausibilità, quando c'è il perimetro: Piazza Grande dentro, la stazione fuori
if zone["perimeter"]:
    assert osm_geo.contains(zone["perimeter"], 44.6464, 10.9255), "Piazza Grande fuori dal perimetro"
    assert not osm_geo.contains(zone["perimeter"], 44.6545, 10.9270), "stazione di Modena dentro il perimetro"

ready = all(len(z["perimeter"]) >= 5 and z["source"]["quote"] for z in city["zones"])
out = ROOT / ("Resources/Cities/modena.json" if ready else "data/drafts/modena.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/modena.json" if ready else "Resources/Cities/modena.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), [(z["id"], len(z["perimeter"]), len(z["gates"])) for z in city["zones"]])
