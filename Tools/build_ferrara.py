#!/usr/bin/env python3
# Costruisce la scheda di Ferrara (bozza) da quanto salvato in data/raw/ferrara/ (fonti e date in docs/fonti-ferrara.md).
#
# Il 26/10/2026 dal sandbox nessun sito del Comune (comune.ferrara.it, comune.fe.it, sit.comune.fe.it), di Ferrara Tua,
# di OpenStreetMap/Overpass o dell'open data regionale era raggiungibile (il proxy rifiuta la connessione, 403): le regole
# vengono solo dai riassunti della ricerca web (data/raw/ferrara/websearch-*.txt), che citano le pagine ufficiali ma non
# sono testo letterale. Per questo:
#   - nessuna citazione («quote»: null) finché non si salva il testo ufficiale;
#   - nessun perimetro: esiste un perimetro UFFICIALE in open data (WFS «Ferrara:ZTL_esistente_preview» su
#     sit.comune.fe.it, catalogato su dati.gov.it), da salvare come data/raw/ferrara/ztl_perimetro.geojson (WGS84);
#   - la scheda resta in data/drafts/ferrara.json.
# Con il file del perimetro e le citazioni verificate la scheda può passare in Resources/Cities (vedi «ready»).
# Uso: python3 Tools/build_ferrara.py   (non tocca le altre città né manifest.json)
import json, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/ferrara"
CHECKED = "2026-10-26T23:00:00Z"
EVERY_DAY = [1, 2, 3, 4, 5, 6, 7]

PERMITS = "https://www.comune.ferrara.it/it/b/11833/permessi-ztl"
SPECIAL = "https://www.comune.ferrara.it/it/b/57142/casi-particolari"
DAILY = "https://www.comune.ferrara.it/b/17343/permessi-ztl-giornalieri-e-abbonamenti"
OFFICE = "https://www.comune.ferrara.it/it/b/25854/centro-unico-permessi"
RULES_PDF = "https://www.comune.ferrara.it/static/d3/13/ea/d36133eac821d78bec5fd1f4d17c5aa3.pdf"
WFS = "https://sit.comune.fe.it/geoserverckan/Ferrara/ZTL_esistente_preview/wfs?service=WFS&version=2.0.0&request=GetCapabilities"


def flat(s):
    return re.sub(r"\s+", " ", s).strip()


TEXT = {p.stem: flat(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def check(file, *phrases):
    """Ogni fatto usato deve comparire, parola per parola, nel testo salvato (qui: riassunti della ricerca)"""
    for q in phrases:
        if flat(q) not in TEXT[file]:
            raise SystemExit(f"{file}: frase non trovata: {q!r}")


check("websearch-1-orari-permessi", "la ZTL di Ferrara è attiva tutti i giorni dell'anno 24 ore su 24",
      "Il centro storico è diviso in quattro zone (A, B, C, D) con varchi elettronici",
      "Al check-in bisogna fornire alle reception la targa del veicolo.")
check("websearch-2-hotel", "None of the results gives a deadline for reporting a guest's plate.")
check("websearch-3-permesso-giornaliero", "lists a single entry at €20 per day",
      "Online purchase is not available for the ZTL Duomo zone", "Daily passes must be bought before entering the zone.")
check("websearch-4-elettriche", "VEICOLI ELETTRICI ACCESSO GRATUITO IN TUTTE LE FASCE ORARIE")
check("websearch-5-varchi-novita", "La ZTL di Ferrara è attiva tutti i giorni dell'anno 24 ore su 24.",
      "via Francesco del Cossa e Largo Castello", "entro il 31 marzo 2027", "No 2026 confirmation of the hours found.")
check("websearch-6-multe-disabili", "between 84 and 335 euros")


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


LINKS = [link("City of Ferrara: ZTL permits", "Comune di Ferrara: permessi ZTL", "Stadt Ferrara: ZTL-Genehmigungen", PERMITS),
         link("City of Ferrara: special cases (hotel guests)", "Comune di Ferrara: casi particolari (ospiti di alberghi)",
              "Stadt Ferrara: Sonderfälle (Hotelgäste)", SPECIAL),
         link("City of Ferrara: daily ZTL permits and passes (INES Cloud)", "Comune di Ferrara: permessi ZTL giornalieri e abbonamenti (INES Cloud)",
              "Stadt Ferrara: ZTL-Tagesgenehmigungen und Abos (INES Cloud)", DAILY),
         link("City of Ferrara: permit office (Centro Unico Permessi)", "Comune di Ferrara: Centro Unico Permessi",
              "Stadt Ferrara: Genehmigungsbüro (Centro Unico Permessi)", OFFICE),
         link("City of Ferrara: ZTL regulation (PDF)", "Comune di Ferrara: regolamento ZTL (PDF)", "Stadt Ferrara: ZTL-Regelung (PDF)", RULES_PDF),
         link("City of Ferrara: official ZTL perimeter, open data (WFS)", "Comune di Ferrara: perimetro ufficiale ZTL, open data (WFS)",
              "Stadt Ferrara: offizielle ZTL-Grenze, offene Daten (WFS)", WFS)]

PENDING = [
    ("Draft: the City's websites could not be read from here (connection refused). Every rule below is taken from web-search summaries of the official pages, not from their text: to be checked word for word.",
     "Bozza: i siti del Comune non erano leggibili da qui (connessione rifiutata). Ogni regola viene dai riassunti della ricerca web sulle pagine ufficiali, non dal loro testo: da verificare parola per parola.",
     "Entwurf: Die Websites der Stadt waren von hier aus nicht lesbar (Verbindung abgelehnt). Alle Regeln stammen aus Zusammenfassungen der Websuche zu den offiziellen Seiten, nicht aus deren Text: Wort für Wort zu prüfen."),
    ("Hours 24 hours a day, every day: confirmed only by accessibilitacentristorici.it and tolltracker.eu (unofficial guides).",
     "Orario 0–24 tutti i giorni: confermato solo da accessibilitacentristorici.it e tolltracker.eu (guide non ufficiali).",
     "Zeiten rund um die Uhr, täglich: nur von accessibilitacentristorici.it und tolltracker.eu bestätigt (inoffizielle Ratgeber)."),
    ("Map outline missing: the City publishes an official perimeter as open data (WFS «ZTL_esistente_preview»), which could not be downloaded from here. Gates known only by name (Porta Reno, Via Garibaldi, Corso Ercole I d'Este, …, unofficial list).",
     "Manca il perimetro: il Comune pubblica un perimetro ufficiale in open data (WFS «ZTL_esistente_preview»), non scaricabile da qui. Varchi noti solo per nome (Porta Reno, via Garibaldi, Corso Ercole I d'Este, …, elenco non ufficiale).",
     "Grenze fehlt: Die Stadt veröffentlicht eine offizielle Grenze als offene Daten (WFS «ZTL_esistente_preview»), die von hier nicht geladen werden konnte. Kameras nur dem Namen nach bekannt (Porta Reno, Via Garibaldi, Corso Ercole I d'Este, …, inoffizielle Liste)."),
    ("The centre is split into sectors A, B, C and D (including the stricter ZTL Duomo, open only with a documented need): not drawn separately.",
     "Il centro è diviso nei comparti A, B, C e D (compresa la ZTL Duomo, più restrittiva, solo per esigenze documentate): non disegnati separatamente.",
     "Das Zentrum ist in die Sektoren A, B, C und D geteilt (darunter die strengere ZTL Duomo, nur mit nachgewiesenem Bedarf): nicht einzeln eingezeichnet."),
    ("Hotels: guests of hotels and holiday homes inside the ZTL may enter to unload luggage or reach the property's parking; give your plate at reception on check-in. No deadline for the hotel found.",
     "Alberghi: gli ospiti di alberghi e case vacanza dentro la ZTL entrano per scaricare i bagagli o raggiungere il parcheggio della struttura; la targa va data alla reception al check-in. Nessuna scadenza per l'hotel trovata.",
     "Hotels: Gäste von Hotels und Ferienwohnungen in der ZTL dürfen zum Ausladen oder zum Hotelparkplatz einfahren; das Kennzeichen beim Check-in an der Rezeption angeben. Keine Frist für das Hotel gefunden."),
    ("Daily permit 20 € (also packs of 5 or 10 days), bought before entering at the permit office or online on INES Cloud (not for ZTL Duomo or vehicles over 3.5 t). Not confirmed who may buy it (tourists?) or whether the price is current.",
     "Permesso giornaliero 20 € (anche pacchetti da 5 o 10 giorni), da comprare prima di entrare allo sportello o online su INES Cloud (non per la ZTL Duomo né per veicoli oltre 3,5 t). Non è confermato chi possa comprarlo (turisti?) né che il prezzo sia attuale.",
     "Tagesgenehmigung 20 € (auch 5er- oder 10er-Pakete), vor der Einfahrt am Schalter oder online bei INES Cloud zu kaufen (nicht für die ZTL Duomo oder Fahrzeuge über 3,5 t). Nicht bestätigt, wer sie kaufen darf (Touristen?) und ob der Preis aktuell ist."),
    ("Electric cars: a 2021 City presentation promised free access at all hours; whether they still need to register is not confirmed, so GateLR does not exempt them.",
     "Auto elettriche: una presentazione del Comune del 2021 annunciava accesso gratuito in tutte le fasce orarie; non è confermato se serva ancora una registrazione, quindi GateLR non le esenta.",
     "Elektroautos: Eine Präsentation der Stadt von 2021 kündigte freie Zufahrt zu jeder Zeit an; ob sie sich noch registrieren müssen, ist nicht bestätigt, daher befreit GateLR sie nicht."),
    ("New gates planned in Via Francesco del Cossa and Largo Castello (works to finish by 31 March 2027, Estense news site).",
     "Nuovi varchi previsti in via Francesco del Cossa e Largo Castello (lavori entro il 31 marzo 2027, notizia di Estense).",
     "Neue Kameras geplant in Via Francesco del Cossa und Largo Castello (Arbeiten bis 31. März 2027, Nachrichtenseite Estense)."),
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


zone = {"id": "ferrara-ztl", "name": "Ferrara · Historic centre ZTL", "name_it": "Ferrara · ZTL Centro storico",
        "name_de": "Ferrara · ZTL Altstadt", "kind": "restricted",
        "summary": "The historic centre (sectors A–D around the Castle and the Cathedral) is closed to unauthorised vehicles 24 hours a day, every day. Hotels inside let you in to unload: give your plate at reception. A daily permit (about 20 €) must be bought before entering.",
        "summary_it": "Il centro storico (comparti A–D attorno al Castello e al Duomo) è chiuso ai veicoli non autorizzati 24 ore su 24, tutti i giorni. Gli hotel dentro ti fanno entrare per scaricare: dai la targa alla reception. Il permesso giornaliero (circa 20 €) va comprato prima di entrare.",
        "summary_de": "Die Altstadt (Sektoren A–D rund um Burg und Dom) ist für nicht berechtigte Fahrzeuge rund um die Uhr, jeden Tag gesperrt. Hotels in der Zone lassen dich zum Ausladen hinein: Kennzeichen an der Rezeption angeben. Eine Tagesgenehmigung (etwa 20 €) muss vor der Einfahrt gekauft werden.",
        "perimeter": perimeter(), "gates": [],
        "windows": [{"weekdays": EVERY_DAY, "start": 0, "end": 24 * 60}],
        "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": True,
        "source": {"authority": "City of Ferrara", "pageURL": PERMITS, "ordinance": "Regolamento ZTL del Comune di Ferrara",
                   "ordinanceURL": RULES_PDF, "quote": None, "quoteTranslation": None, "quoteTranslation_de": None,
                   "checkedOn": CHECKED, "reviewedByHuman": False,
                   "pending": [p[0] for p in PENDING], "pending_it": [p[1] for p in PENDING], "pending_de": [p[2] for p in PENDING],
                   "links": LINKS}}

city = {"id": "ferrara", "name": "Ferrara", "name_it": "Ferrara", "name_de": "Ferrara",
        "center": {"lat": 44.8377, "lon": 11.6188}, "zones": [zone], "status": "draft",
        "license": "Rules: Comune di Ferrara official pages (read through web-search summaries). Perimeter: not yet available."}

# Controlli di plausibilità, quando c'è il perimetro: il Castello Estense dentro, la stazione fuori
if zone["perimeter"]:
    assert osm_geo.contains(zone["perimeter"], 44.8377, 11.6188), "Castello Estense fuori dal perimetro"
    assert not osm_geo.contains(zone["perimeter"], 44.8433, 11.6066), "stazione di Ferrara dentro il perimetro"

# Pubblicabile solo con perimetro ufficiale e citazione verificata; altrimenti bozza
ready = all(len(z["perimeter"]) >= 5 and z["source"]["quote"] for z in city["zones"])
out = ROOT / ("Resources/Cities/ferrara.json" if ready else "data/drafts/ferrara.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/ferrara.json" if ready else "Resources/Cities/ferrara.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), [(z["id"], len(z["perimeter"]), len(z["gates"])) for z in city["zones"]])
