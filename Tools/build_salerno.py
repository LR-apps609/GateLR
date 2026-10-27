#!/usr/bin/env python3
# Costruisce la scheda di Salerno da quanto salvato in data/raw/salerno/ (fonti e date in docs/fonti-salerno.md).
#
# Regole lette sul sito ufficiale (www.comune.salerno.it, 27/10/2026): pagina dell'Ufficio Varchi ZTL (permessi giornalieri,
# transiti trasmessi da autorimesse, B&B, alberghi e pensioni; sistema Sirio Web), servizio «Comunicazione transito
# occasionale ZTL», servizio «Richiesta autorizzazione transito e/o sosta ZTL» (categorie, 10 € con PagoPA, 30 giorni) e il
# modello B1 con le fasce del carico/scarico (6–9:30 e 14–17).
# Orari: NESSUN testo ufficiale letto li indica (ricercati di nuovo il 27/10/2026: pagine ZTL e PGTU sul sito, ricerca web).
#   Si usa, con il permesso del proprietario, accessibilitacentristorici.it (non ufficiale, scheda agg. 07/12/2019):
#   «tutti i giorni 24 ore su 24» → citazione da quella pagina, source.official = false, pending «confermato solo da
#   accessibilitacentristorici.it». Vecchia scheda del Comune (2007, ord. 291/05) su website.comune.salerno.it: irraggiungibile.
# Perimetro e varchi: tavola ufficiale del PGTU «TAVOLA 7.2 Individuazione ZTL» (2019, 14 varchi con nome), fornita dal
#   proprietario, georeferenziata in automatico da Tools/salerno_mappa.py sulle strade OSM → data/raw/salerno/ztl-pgtu-tav7.geojson.
#
# Pubblicata con il meccanismo della 1.16.2 (source.official = false + unofficialSource; il manifest la mette in
# «unofficialCities», nascosta alle app fino alla 1.16.1). Ricontrollo host 27/10/2026: website.comune.salerno.it, albo,
# amministrazionetrasparente, servizionline e servizi.comune.salerno.it chiudono la connessione; /search su www risponde 403.
# Uso: python3 Tools/build_salerno.py   (non tocca le altre città né manifest.json)
import json, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/salerno"
CHECKED = "2026-10-27T12:00:00Z"
ALL = [1, 2, 3, 4, 5, 6, 7]

B = "https://www.comune.salerno.it"
OFFICE = B + "/amministrazione/ufficio/ufficio-varchi-ztl"
OCCASIONAL = B + "/servizi/comunicazione-transito-occasionale-ztl"
PERMITS = B + "/servizi/richiesta-autorizzazione-transito-eo-sosta-ztl-eo-rinnovi"
FORM_B1 = B + "/sites/default/files/documento_pubblico/modello-b1.pdf"
UNOFFICIAL = "https://www.accessibilitacentristorici.it/ztl/campania/salerno.html"
OFFICIAL_RELEASED = True    # su main c'è l'app 1.16.2 (commit 1ca9109): source.official e manifest «unofficialCities»


def flat(s):
    return re.sub(r"\s+", " ", s).strip()


TEXT = {p.stem: flat(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def check(file, *phrases):
    for q in phrases:
        if flat(q) not in TEXT[file]:
            raise SystemExit(f"{file}: frase non trovata: {q!r}")


HOTEL_QUOTE = ("Verifica e ricezione transiti trasmessi da: Autorimesse private; Bed and breakfast; Enti pubblici, Salerno solidale, "
         "Convitto Nazionale, Curia, Ostello, Alberghi e Pensioni .")
check("comune-ufficio-varchi-ztl", HOTEL_QUOTE, "Sirio Web (Sistema di Controllo Accessi della città di Salerno)",
      "Transiti occasionali veicoli ad uso Diversamente Abili;", "ztlsalerno@comune.salerno.it")
GATES = ["Via Antica Corte", "Via San Michele", "Via Monterisi", "Via Romualdo II Guarna", "Via Portanova *", "Via Mazza Antonio",
         "Via Duomo ang. via Roma *", "Via Conforti R. direzione nord (CVE)", "Corso Garibaldi G. interno ang. Via Conforti R.",
         "Corso V. Emanuele ang. Via Dei Principati dir. Ovest"]
check("comune-modello-b1", *["Varco " + g for g in GATES],
      "Le operazioni di carico e scarico sono consentite nella fascia oraria 06.00/09.30 -14.00/17.00",
      "è consentito solo ai veicoli di massa non sup. a 18 q.li")
check("comune-comunicazione-transito-occasionale", "Non sono previsti costi per il procedimento.", "Modello B1 debitamente compilato")
check("comune-richiesta-autorizzazione-ztl", "Pagamento di € 10.00 (Euro dieci/00)", "L’istanza sarà evasa entro 30 giorni dalla data della richiesta",
      "persona diversamente abile", "rilascio o rinnovo autorizzazione al traffico CVE")
check("comune-pums-2-rapporto-estratto", "carico e scarico sono consentiti negli intervalli orari 06.00-09.30 e 14.00-17.00",
      "può transitare all’interno di ZTL e CVE deve avere portata non superiore ai 18 quintali")
check("websearch-1-orari", "the cameras are active every day, 24 hours a day",
      "bounded to the south by Via Roma and to the north by Via Duomo, San Benedetto and Salvatore Rienzi",
      "I couldn't find the current 2026 ZTL hours or the current ordinance.")


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


QUOTE = "La telecamere sono in funzioni tutti i giorni 24 ore su 24 ore"
check("accessibilitacentristorici-salerno", QUOTE, "Data aggiornamento: 07/12/2019",
      "perimetrata a sud da Via Roma, a nord dalle vie Duomo, San Benedetto e Salvatore Rienzi",
      "I dispositivi automatici di controllo dell'accesso alla ZTL di Salerno sono 14",
      "I titolari di contrassegno Handicap possono liberamente transitare, effettuare fermata e sostare all'interno della ZTL di Salerno.")

# --- perimetro e varchi dalla Tavola 7.2 del PGTU (Tools/salerno_mappa.py) ---
TAV = json.loads((RAW / "ztl-pgtu-tav7.geojson").read_text(encoding="utf-8"))
if TAV["transform"]["red_on_osm_4m"] < 0.95:
    raise SystemExit("Georeferenziazione della tavola non affidabile: rilanciare Tools/salerno_mappa.py")
shape = osm_geo.perimeter(TAV["features"][0]["geometry"]["coordinates"][0], tol_m=3)
area = osm_geo.area_km2(shape)
if not 0.15 < area < 0.35:
    raise SystemExit(f"Area della ZTL non plausibile: {area:.3f} km²")
for name, lat, lon, inside in [("Duomo di Salerno", 40.68065, 14.76040, True), ("Via dei Mercanti", 40.67931, 14.75822, True),
                               ("Via Duomo", 40.67996, 14.75942, True), ("Corso Vittorio Emanuele", 40.67654, 14.76720, True),
                               ("Via Roma (Comune)", 40.67710, 14.76070, False), ("Lungomare Trieste", 40.67719, 14.76100, False),
                               ("Stazione FS", 40.67520, 14.77280, False), ("Castello di Arechi", 40.68630, 14.75600, False)]:
    if osm_geo.contains(shape, lat, lon) != inside:
        raise SystemExit(f"Controllo perimetro fallito: {name} dovrebbe essere {'dentro' if inside else 'fuori'}")
gate_list = []
for f in TAV["features"][1:]:
    pr, (lon, lat) = f["properties"], f["geometry"]["coordinates"]
    if not osm_geo.contains(shape, lat, lon) and osm_geo.distance_m(shape, lat, lon) > 25:   # alcuni varchi sono interni
        raise SystemExit(f"Varco fuori dalla ZTL: {pr['name']}")
    gate_list.append({"id": f"sa-tav7-{pr['n']}", "name": pr["name"], "location": {"lat": lat, "lon": lon}})
if len(gate_list) != 14:
    raise SystemExit("La tavola deve avere 14 varchi")


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


LINKS = [link("Accessibilità Centri Storici: Salerno (unofficial, hours)", "Accessibilità Centri Storici: Salerno (non ufficiale, orari)", "Accessibilità Centri Storici: Salerno (inoffiziell, Zeiten)", UNOFFICIAL),
         link("City of Salerno: ZTL gates office", "Comune di Salerno: Ufficio Varchi ZTL", "Stadt Salerno: Büro ZTL-Kameras", OFFICE),
         link("City of Salerno: occasional ZTL transit (form B1)", "Comune di Salerno: comunicazione transito occasionale ZTL (mod. B1)", "Stadt Salerno: gelegentliche ZTL-Durchfahrt (Formular B1)", OCCASIONAL),
         link("City of Salerno: form B1 with the list of gates (PDF)", "Comune di Salerno: modello B1 con l'elenco dei varchi (PDF)", "Stadt Salerno: Formular B1 mit Kameraliste (PDF)", FORM_B1),
         link("City of Salerno: ZTL permits", "Comune di Salerno: richiesta autorizzazione transito e/o sosta ZTL", "Stadt Salerno: ZTL-Genehmigungen", PERMITS)]

PENDING = [
    ("Hours: confirmed only by accessibilitacentristorici.it (every day, 24 hours a day; page updated 7 December 2019). No official text read states them; an old City page from 2007 (ordinance 291/05, not reachable from here) gave different time slots.",
     "Orari: confermato solo da accessibilitacentristorici.it (tutti i giorni 24 ore su 24; scheda aggiornata al 07/12/2019). Nessun testo ufficiale letto li indica; una vecchia pagina del Comune del 2007 (ordinanza 291/05, non raggiungibile da qui) dava fasce diverse.",
     "Zeiten: nur von accessibilitacentristorici.it bestätigt (täglich rund um die Uhr; Seite vom 7. Dezember 2019). Kein gelesener offizieller Text nennt sie; eine alte Stadtseite von 2007 (Verordnung 291/05, von hier nicht erreichbar) nannte andere Zeitfenster."),
    ("Area and the 14 gates from the City's official traffic-plan map (PGTU 2019, table 7.2 «Individuazione ZTL»), matched automatically to OpenStreetMap streets. The City's current form B1 lists 10 gates, including Corso Garibaldi and Corso Vittorio Emanuele (added in 2023), and not Vigorito, Portacatena, Della Porta, Piazzetta Elina or Porta di Mare: some gates may have moved since 2019.",
     "Area e 14 varchi dalla tavola ufficiale del PGTU (2019, tavola 7.2 «Individuazione ZTL»), agganciata in automatico alle strade di OpenStreetMap. L'attuale modello B1 del Comune elenca 10 varchi, tra cui Corso Garibaldi e Corso Vittorio Emanuele (aggiunti nel 2023), e non Vigorito, Portacatena, Della Porta, Piazzetta Elina e Porta di Mare: alcuni varchi potrebbero essere cambiati dal 2019.",
     "Fläche und 14 Kameras aus der amtlichen Karte des Verkehrsplans (PGTU 2019, Tafel 7.2 «Individuazione ZTL»), automatisch an OpenStreetMap-Straßen ausgerichtet. Das aktuelle Formular B1 der Stadt nennt 10 Kameras, darunter Corso Garibaldi und Corso Vittorio Emanuele (2023 ergänzt), nicht aber Vigorito, Portacatena, Della Porta, Piazzetta Elina und Porta di Mare: einige Kameras können sich seit 2019 geändert haben."),
    ("Hotels, guesthouses and B&Bs send their guests' transits to the City's ZTL gates office; the time limit is not stated. Occasional transits (loading, disabled people, doctors) are communicated with form B1, free, by e-mail or certified mail; loading is allowed 6–9:30 am and 2–5 pm.",
     "Alberghi, pensioni e B&B trasmettono i transiti dei loro ospiti all'Ufficio Varchi ZTL del Comune; il termine non è indicato. I transiti occasionali (carico/scarico, disabili, medici) si comunicano con il modello B1, gratis, via e-mail o PEC; il carico/scarico è consentito 6–9:30 e 14–17.",
     "Hotels, Pensionen und B&Bs melden die Durchfahrten ihrer Gäste dem ZTL-Büro der Stadt; eine Frist ist nicht angegeben. Gelegentliche Durchfahrten (Laden, Behinderte, Ärzte) meldet man kostenlos mit Formular B1 per E-Mail oder PEC; Laden ist 6–9:30 und 14–17 Uhr erlaubt."),
    ("Not found: electric cars, motorbikes, fines, summer or Christmas (Luci d'Artista) variations. The old City website (website.comune.salerno.it) could not be reached from here.",
     "Non trovati: auto elettriche, moto, multe, variazioni estive o natalizie (Luci d'Artista). Il vecchio sito del Comune (website.comune.salerno.it) non era raggiungibile da qui.",
     "Nicht gefunden: Elektroautos, Motorräder, Bußgelder, Sommer- oder Weihnachtsänderungen (Luci d'Artista). Die alte Stadtwebsite (website.comune.salerno.it) war von hier nicht erreichbar."),
]

zone = {"id": "salerno-centro-storico", "name": "Old town · ZTL from via Roma to via Duomo", "name_it": "Centro storico · ZTL tra via Roma e via Duomo",
        "name_de": "Altstadt · ZTL zwischen Via Roma und Via Duomo", "kind": "restricted",
        "summary": "Salerno's historic centre (between via Roma and via Duomo / via San Benedetto, plus Corso Vittorio Emanuele) is a camera-controlled ZTL with 14 gates, such as Portanova, via Duomo and via dei Principati, reportedly active 24 hours a day. Without a permit stay out. Staying inside? Your hotel or B&B sends your transit to the City's ZTL office: ask them before you arrive.",
        "summary_it": "Il centro storico di Salerno (tra via Roma e via Duomo / via San Benedetto, più Corso Vittorio Emanuele) è una ZTL con 14 varchi a telecamera, tra cui Portanova, via Duomo e via dei Principati, attiva secondo le guide 24 ore su 24. Senza permesso non entrare. Dormi dentro? L'hotel o il B&B trasmette il tuo transito all'Ufficio Varchi ZTL: chiedi prima di arrivare.",
        "summary_de": "Die Altstadt von Salerno (zwischen Via Roma und Via Duomo / Via San Benedetto, dazu der Corso Vittorio Emanuele) ist eine kameraüberwachte ZTL mit 14 Kameras, u. a. Portanova, Via Duomo und Via dei Principati, laut Reiseführern rund um die Uhr aktiv. Ohne Genehmigung draußen bleiben. Du übernachtest innen? Hotel oder B&B melden deine Durchfahrt dem ZTL-Büro: frag vor der Anreise.",
        "perimeter": shape, "gates": gate_list,
        "windows": [{"weekdays": ALL, "start": 0, "end": 24 * 60}],
        "freeOnHolidays": False, "holidaysAsSunday": False, "exemptFuels": [], "hotelCanRegister": True,
        "source": {"authority": "Accessibilità Centri Storici (unofficial); City of Salerno", "official": False,
                   "unofficialSource": {"name": "Accessibilità Centri Storici", "url": UNOFFICIAL}, "pageURL": UNOFFICIAL, "quote": QUOTE,
                   "quoteTranslation": "The cameras are in operation every day, 24 hours a day.",
                   "quoteTranslation_de": "Die Kameras sind täglich rund um die Uhr in Betrieb.",
                   "checkedOn": CHECKED, "reviewedByHuman": False,
                   "pending": [p[0] for p in PENDING], "pending_it": [p[1] for p in PENDING], "pending_de": [p[2] for p in PENDING],
                   "links": LINKS}}

city = {"id": "salerno", "name": "Salerno", "name_it": "Salerno", "name_de": "Salerno",
        "center": {"lat": 40.6795, "lon": 14.7590}, "zones": [zone], "status": "draft",
        "license": "Hours: accessibilitacentristorici.it (unofficial). Rules: Comune di Salerno (official pages, form B1). Area and gates: Comune di Salerno, PGTU 2019 table 7.2, georeferenced on " + osm_geo.ODBL + "."}

# Pubblicabile con perimetro e citazione (non ufficiale, segnalata all'utente dall'app 1.16.2)
ready = OFFICIAL_RELEASED and all(len(z["perimeter"]) >= 5 and z["source"]["quote"] for z in city["zones"])
out = ROOT / ("Resources/Cities/salerno.json" if ready else "data/drafts/salerno.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/salerno.json" if ready else "Resources/Cities/salerno.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), [(z["id"], len(z["perimeter"]), len(z["gates"])) for z in city["zones"]], f"{area:.3f} km²")
