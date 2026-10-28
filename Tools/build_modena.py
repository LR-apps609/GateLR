#!/usr/bin/env python3
# Costruisce Resources/Cities/modena.json dagli atti ufficiali del Comune di Modena salvati in data/raw/modena/
# (URL e data di lettura in testa a ogni file; fonti e date in docs/fonti-modena.md).
#
# Regole: Testo coordinato Ordinanza ZTL (prot. P.G. 85253 del 01/04/2020): punto B) «Divieto permanente di
# circolazione», cioè 0–24 tutti i giorni, con le deroghe B1/B2 (moto e ciclomotori liberi, clienti degli alberghi
# con contrassegno e dati comunicati entro 48 ore), B10 (elettriche solo previa autorizzazione), D) (pass giornalieri
# solo alle condizioni delle autorizzazioni permanenti: nessun ticket per turisti). Pagina ZTL di VisitModena.
#
# Geometria UFFICIALE (mai disegnata a mano): open data del Comune, WFS «Modena:Ztl_preview» (geonext.comune.modena.it,
# catalogo dati.gov.it), salvato in data/raw/modena/ztl_perimetro.geojson (un poligono). Varchi: nessun dato con
# coordinate (OpenStreetMap non raggiungibile dal sandbox il 26/10/2026), restano nei pending.
# Uso: python3 Tools/build_modena.py   (non tocca le altre città né manifest.json)
import json, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/modena"
CHECKED = "2026-10-26T23:55:00Z"
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


ORD, PAGE, VISIT = "ordinanza-ztl-testo-coordinato-pg-85253-2020", "comune-pagina-testo-coordinato", "visitmodena-informazioni-ztl"
QUOTE = "All’interno del perimetro come sopra individuato è permanentemente vietato il transito e la sosta ai veicoli non autorizzati"
check(ORD, "Prot. P.G. 85253 del 01/04/2020", QUOTE,
      "B) ­ ZONA A TRAFFICO LIMITATO (ZTL) ­ Divieto permanente di circolazione",
      "Il perimetro della Zona a Traffico Limitato è soggetto al telecontrollo di tutti i varchi di accesso e di uscita",
      "ai velocipedi, ciclomotori, motocicli nonché ai motoveicoli appartenenti alla categoria internazionale L5e",
      "ai veicoli di clienti delle strutture ricettive con sede in ZTL (alberghi, hotel, bed and breakfast, ostelli, affittacamere)",
      "un contrassegno rilasciato dall'albergatore",
      "gestori delle strutture ricettive o gestori dei parcheggi custoditi l'obbligo di comunicare alla Polizia Municipale i dati identificativi del veicolo ed eventuali altri elementi richiesti entro 48 ore dall'accesso",
      "ai ciclomotori, ai motoveicoli e agli autoveicoli muniti di solo propulsore ad energia elettrica",
      "Il pass è valido solo ed unicamente nell'arco delle 24 ore giornaliere e viene rilasciato alle stesse condizioni delle autorizzazioni permanenti.",
      "abrogazione della franchigia oraria",
      "Corso Duomo, in entrambe le direzioni di marcia")
check(PAGE, "Ultimo aggiornamento : 19-08-2025")
check(VISIT, "Tutti i varchi di accesso al centro storico sono sorvegliati da telecamere, attive 24 ore su 24",
      "I dati per l'autorizzazione ZTL saranno comunicati alla Polizia municipale a cura della struttura ricettiva.")


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


WFS = "https://geonext.comune.modena.it/geoservernext//Modena/Ztl_preview/wfs?service=WFS&version=2.0.0&request=GetCapabilities"
LINKS = [link("City of Modena: consolidated ZTL order (2020, PDF)", "Comune di Modena: testo coordinato ordinanza ZTL (2020, PDF)",
              "Stadt Modena: konsolidierte ZTL-Anordnung (2020, PDF)", url_of(ORD)),
         link("VisitModena: limited traffic area (hotel guests)", "VisitModena: zona a traffico limitato (ospiti degli hotel)",
              "VisitModena: verkehrsberuhigte Zone (Hotelgäste)", url_of(VISIT)),
         link("VisitModena: car parks", "VisitModena: parcheggi", "VisitModena: Parkplätze",
              "https://www.visitmodena.it/en/plan-the-trip/tourist-services/parking-lots"),
         link("City of Modena: official ZTL perimeter, open data (WFS)", "Comune di Modena: perimetro ufficiale ZTL, open data (WFS)",
              "Stadt Modena: offizielle ZTL-Grenze, offene Daten (WFS)", WFS)]

PENDING = [
    ("Hotels inside the ZTL: you may drive in and park nearby with the hotel's badge on the windscreen; the hotel sends your plate to the municipal police within 48 hours of your entry. Rental cars have no permit of their own.",
     "Alberghi dentro la ZTL: entri e sosti vicino con il contrassegno della struttura sul parabrezza; la struttura comunica la targa alla Polizia municipale entro 48 ore dall'accesso. Le auto a noleggio non hanno un permesso proprio.",
     "Hotels in der ZTL: Du darfst mit dem Ausweis der Unterkunft hinter der Windschutzscheibe einfahren und in der Nähe parken; die Unterkunft meldet dein Kennzeichen innerhalb von 48 Stunden der Stadtpolizei. Mietwagen haben keine eigene Genehmigung."),
    ("Motorcycles and mopeds may enter without a permit (order, point B2). Fully electric cars need an authorisation first: they are not exempt automatically.",
     "Moto e ciclomotori entrano senza autorizzazione (ordinanza, punto B2). Le auto solo elettriche hanno bisogno prima di un'autorizzazione: non sono esenti in automatico.",
     "Motorräder und Mopeds dürfen ohne Genehmigung einfahren (Anordnung, Punkt B2). Reine Elektroautos brauchen vorher eine Genehmigung: sie sind nicht automatisch befreit."),
    ("No ticket for tourists: daily passes are issued only on the same conditions as permanent permits. Some streets inside (Via Emilia Centro between Vicolo Squallore and Via Torre, Corso Duomo, north side of Piazza Roma) are reserved lanes closed even with a ZTL permit, and the pedestrian areas (Piazza Grande …) are not drawn separately.",
     "Nessun ticket per turisti: i pass giornalieri si rilasciano solo alle condizioni delle autorizzazioni permanenti. Alcune vie interne (via Emilia Centro tra vicolo Squallore e via Torre, Corso Duomo, lato nord di Piazza Roma) sono corsie riservate vietate anche con permesso ZTL, e le aree pedonali (Piazza Grande …) non sono disegnate a parte.",
     "Kein Touristenticket: Tagespässe gibt es nur zu den Bedingungen der Dauergenehmigungen. Einige Straßen innen (Via Emilia Centro zwischen Vicolo Squallore und Via Torre, Corso Duomo, Nordseite der Piazza Roma) sind Sonderspuren, die auch mit ZTL-Genehmigung gesperrt sind; die Fußgängerzonen (Piazza Grande …) sind nicht eigens eingezeichnet."),
    ("Gate positions are not on the map yet (no open data with coordinates): every entry and exit of the perimeter is camera-controlled.",
     "La posizione dei varchi non è ancora sulla mappa (nessun open data con coordinate): tutti gli accessi e le uscite del perimetro sono controllati da telecamere.",
     "Die Kamerastandorte sind noch nicht auf der Karte (keine offenen Daten mit Koordinaten): alle Ein- und Ausfahrten der Zone werden per Kamera überwacht."),
]


def perimeter():
    g = json.loads((RAW / "ztl_perimetro.geojson").read_text(encoding="utf-8"))["features"][0]["geometry"]
    polys = [g["coordinates"]] if g["type"] == "Polygon" else g["coordinates"]
    return osm_geo.perimeter(max((p[0] for p in polys), key=osm_geo.area_km2), tol_m=2)


zone = {"id": "modena-ztl", "name": "Modena · Historic centre ZTL", "name_it": "Modena · ZTL Centro storico",
        "name_de": "Modena · ZTL Altstadt", "kind": "restricted",
        "summary": "The historic centre inside the ring boulevards (Duomo, Piazza Grande) is closed to unauthorised cars 24 hours a day, every day; cameras check every entry. There is no tourist ticket. If your hotel is inside, it gives you a windscreen badge and registers your plate within 48 hours. Motorcycles and mopeds may enter.",
        "summary_it": "Il centro storico dentro i viali (Duomo, Piazza Grande) è chiuso alle auto non autorizzate 24 ore su 24, tutti i giorni; le telecamere controllano ogni accesso. Non c'è un ticket per turisti. Se l'hotel è dentro, ti dà un contrassegno per il parabrezza e registra la targa entro 48 ore. Moto e ciclomotori possono entrare.",
        "summary_de": "Die Altstadt innerhalb der Ringstraßen (Dom, Piazza Grande) ist für nicht berechtigte Autos rund um die Uhr, jeden Tag gesperrt; Kameras prüfen jede Zufahrt. Ein Touristenticket gibt es nicht. Liegt dein Hotel innen, gibt es dir einen Ausweis für die Windschutzscheibe und meldet dein Kennzeichen innerhalb von 48 Stunden. Motorräder und Mopeds dürfen hinein.",
        "perimeter": perimeter(), "gates": [],
        "windows": [{"weekdays": EVERY_DAY, "start": 0, "end": 24 * 60}],
        # Deroga B2: «ai velocipedi, ciclomotori, motocicli…» (testo coordinato dell'ordinanza ZTL)
        "freeOnHolidays": False, "exemptFuels": [], "exemptVehicleTypes": ["motorcycle"], "hotelCanRegister": True,
        "source": {"authority": "City of Modena", "pageURL": url_of(PAGE),
                   "ordinance": "Testo coordinato Ordinanza ZTL (prot. P.G. 85253 del 01/04/2020)", "ordinanceURL": url_of(ORD),
                   "quote": QUOTE,
                   "quoteTranslation": "Inside the perimeter defined above, driving and parking are permanently forbidden to unauthorised vehicles",
                   "quoteTranslation_de": "Innerhalb der oben festgelegten Grenze sind Fahren und Parken für nicht berechtigte Fahrzeuge dauerhaft verboten",
                   "checkedOn": CHECKED, "reviewedByHuman": False,
                   "pending": [p[0] for p in PENDING], "pending_it": [p[1] for p in PENDING], "pending_de": [p[2] for p in PENDING],
                   "links": LINKS}}

city = {"id": "modena", "name": "Modena", "name_it": "Modena", "name_de": "Modena",
        "center": {"lat": 44.6464, "lon": 10.9255}, "zones": [zone], "status": "draft",
        "license": "Rules and perimeter: Comune di Modena official order and open data (WFS Ztl_preview)."}

# Controlli di plausibilità: Piazza Grande e Palazzo Ducale dentro, la stazione e il Parco Novi Sad fuori
for n, lat, lon in [("Piazza Grande", 44.6464, 10.9255), ("Palazzo Ducale", 44.6481, 10.9282)]:
    assert osm_geo.contains(zone["perimeter"], lat, lon), f"{n} non è dentro il perimetro"
for n, lat, lon in [("stazione di Modena", 44.6545, 10.9270), ("Parco Novi Sad", 44.6497, 10.9161)]:
    assert not osm_geo.contains(zone["perimeter"], lat, lon), f"{n} risulta dentro"
assert 0.5 < osm_geo.area_km2(zone["perimeter"]) < 1.2
print("modena-ztl", len(zone["perimeter"]), "punti", round(osm_geo.area_km2(zone["perimeter"]), 3), "km²")

ready = all(len(z["perimeter"]) >= 5 and z["source"]["quote"] for z in city["zones"])
out = ROOT / ("Resources/Cities/modena.json" if ready else "data/drafts/modena.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/modena.json" if ready else "Resources/Cities/modena.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT))
