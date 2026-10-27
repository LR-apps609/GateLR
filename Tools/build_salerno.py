#!/usr/bin/env python3
# Costruisce la scheda di Salerno (bozza) da quanto salvato in data/raw/salerno/ (fonti e date in docs/fonti-salerno.md).
#
# Regole lette sul sito ufficiale (www.comune.salerno.it, 27/10/2026): pagina dell'Ufficio Varchi ZTL (permessi giornalieri,
# transiti trasmessi da autorimesse, B&B, alberghi e pensioni; sistema Sirio Web), servizio «Comunicazione transito
# occasionale ZTL», servizio «Richiesta autorizzazione transito e/o sosta ZTL» (categorie, 10 € con PagoPA, 30 giorni) e il
# modello B1 con l'elenco ufficiale dei 10 varchi e le fasce del carico/scarico (6–9:30 e 14–17).
# NESSUN testo ufficiale letto indica gli orari della ZTL: guide e stampa dicono «24 ore su 24»; una vecchia pagina del
# Comune (2007, ord. 291/05) dava fasce diverse ed è su website.comune.salerno.it, bloccato dal proxy (403).
#
# Resta in data/drafts/salerno.json perché:
#   1. manca un orario ufficiale (le finestre 0–24 qui sotto sono confermate solo da fonti non ufficiali);
#   2. manca il perimetro: nessun open data, nessuna relazione ZTL in OpenStreetMap (le vie del centro storico hanno
#      solo access=destination, che non è una delimitazione ufficiale) e i varchi del modello B1 non hanno coordinate.
# Per pubblicarla servono l'ordinanza vigente (orari, perimetro o elenco delle vie) e la posizione dei 10 varchi.
# Uso: python3 Tools/build_salerno.py   (non tocca le altre città né manifest.json)
import json, re
from pathlib import Path

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


def flat(s):
    return re.sub(r"\s+", " ", s).strip()


TEXT = {p.stem: flat(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def check(file, *phrases):
    for q in phrases:
        if flat(q) not in TEXT[file]:
            raise SystemExit(f"{file}: frase non trovata: {q!r}")


QUOTE = ("Verifica e ricezione transiti trasmessi da: Autorimesse private; Bed and breakfast; Enti pubblici, Salerno solidale, "
         "Convitto Nazionale, Curia, Ostello, Alberghi e Pensioni .")
check("comune-ufficio-varchi-ztl", QUOTE, "Sirio Web (Sistema di Controllo Accessi della città di Salerno)",
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
check("websearch-1-orari", "the cameras are active every day, 24 hours a day",
      "bounded to the south by Via Roma and to the north by Via Duomo, San Benedetto and Salvatore Rienzi",
      "I couldn't find the current 2026 ZTL hours or the current ordinance.")


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


LINKS = [link("City of Salerno: ZTL gates office", "Comune di Salerno: Ufficio Varchi ZTL", "Stadt Salerno: Büro ZTL-Kameras", OFFICE),
         link("City of Salerno: occasional ZTL transit (form B1)", "Comune di Salerno: comunicazione transito occasionale ZTL (mod. B1)", "Stadt Salerno: gelegentliche ZTL-Durchfahrt (Formular B1)", OCCASIONAL),
         link("City of Salerno: form B1 with the list of gates (PDF)", "Comune di Salerno: modello B1 con l'elenco dei varchi (PDF)", "Stadt Salerno: Formular B1 mit Kameraliste (PDF)", FORM_B1),
         link("City of Salerno: ZTL permits", "Comune di Salerno: richiesta autorizzazione transito e/o sosta ZTL", "Stadt Salerno: ZTL-Genehmigungen", PERMITS),
         link("Accessibilità Centri Storici: Salerno (unofficial)", "Accessibilità Centri Storici: Salerno (non ufficiale)", "Accessibilità Centri Storici: Salerno (inoffiziell)", UNOFFICIAL)]

PENDING = [
    ("Hours: no official text read states them. Guides say the cameras work every day, 24 hours a day (confirmed only by accessibilitacentristorici.it and car-news sites); an old City page from 2007 (ordinance 291/05, not reachable from here) gave different time slots. GateLR shows the ZTL as always on until the ordinance is found.",
     "Orari: nessun testo ufficiale letto li indica. Le guide dicono che le telecamere funzionano tutti i giorni 24 ore su 24 (confermato solo da accessibilitacentristorici.it e siti di motori); una vecchia pagina del Comune del 2007 (ordinanza 291/05, non raggiungibile da qui) dava fasce diverse. GateLR mostra la ZTL sempre attiva finché non si trova l'ordinanza.",
     "Zeiten: Kein gelesener offizieller Text nennt sie. Reiseführer sagen, die Kameras laufen täglich rund um die Uhr (nur von accessibilitacentristorici.it und Autoportalen bestätigt); eine alte Stadtseite von 2007 (Verordnung 291/05, von hier nicht erreichbar) nannte andere Zeitfenster. GateLR zeigt die ZTL als immer aktiv, bis die Verordnung gefunden ist."),
    ("No perimeter: the historic centre between via Roma (south) and via Duomo / via San Benedetto / via Salvatore Rienzi (north), with 10 gates listed on the City's form B1 (Antica Corte, San Michele, Monterisi, Romualdo II Guarna, Portanova, Antonio Mazza, Duomo/via Roma, Conforti, Corso Garibaldi, Corso Vittorio Emanuele), but no official map or open data, and OpenStreetMap has no ZTL area.",
     "Nessun perimetro: il centro storico tra via Roma (sud) e via Duomo / via San Benedetto / via Salvatore Rienzi (nord), con 10 varchi elencati nel modello B1 del Comune (Antica Corte, San Michele, Monterisi, Romualdo II Guarna, Portanova, Antonio Mazza, Duomo/via Roma, Conforti, Corso Garibaldi, Corso Vittorio Emanuele), ma senza mappa ufficiale né open data, e OpenStreetMap non ha un'area ZTL.",
     "Keine Grenze: die Altstadt zwischen Via Roma (Süden) und Via Duomo / Via San Benedetto / Via Salvatore Rienzi (Norden), mit 10 Kameras im städtischen Formular B1 (Antica Corte, San Michele, Monterisi, Romualdo II Guarna, Portanova, Antonio Mazza, Duomo/Via Roma, Conforti, Corso Garibaldi, Corso Vittorio Emanuele), aber ohne amtliche Karte oder Open Data; OpenStreetMap hat keine ZTL-Fläche."),
    ("Hotels, guesthouses and B&Bs send their guests' transits to the City's ZTL gates office; the time limit is not stated. Occasional transits (loading, disabled people, doctors) are communicated with form B1, free, by e-mail or certified mail; loading is allowed 6–9:30 am and 2–5 pm.",
     "Alberghi, pensioni e B&B trasmettono i transiti dei loro ospiti all'Ufficio Varchi ZTL del Comune; il termine non è indicato. I transiti occasionali (carico/scarico, disabili, medici) si comunicano con il modello B1, gratis, via e-mail o PEC; il carico/scarico è consentito 6–9:30 e 14–17.",
     "Hotels, Pensionen und B&Bs melden die Durchfahrten ihrer Gäste dem ZTL-Büro der Stadt; eine Frist ist nicht angegeben. Gelegentliche Durchfahrten (Laden, Behinderte, Ärzte) meldet man kostenlos mit Formular B1 per E-Mail oder PEC; Laden ist 6–9:30 und 14–17 Uhr erlaubt."),
    ("Not found: electric cars, motorbikes, fines, summer or Christmas (Luci d'Artista) variations. The old City website (website.comune.salerno.it) could not be reached from here.",
     "Non trovati: auto elettriche, moto, multe, variazioni estive o natalizie (Luci d'Artista). Il vecchio sito del Comune (website.comune.salerno.it) non era raggiungibile da qui.",
     "Nicht gefunden: Elektroautos, Motorräder, Bußgelder, Sommer- oder Weihnachtsänderungen (Luci d'Artista). Die alte Stadtwebsite (website.comune.salerno.it) war von hier nicht erreichbar."),
]

zone = {"id": "salerno-centro-storico", "name": "Salerno old town · ZTL", "name_it": "Centro storico di Salerno · ZTL",
        "name_de": "Altstadt Salerno · ZTL", "kind": "restricted",
        "summary": "Salerno's historic centre (between via Roma and via Duomo / via San Benedetto) is a camera-controlled ZTL with 10 gates, including Portanova, via Duomo and Corso Vittorio Emanuele. Without a permit stay out. Staying inside? Your hotel or B&B sends your transit to the City's ZTL office: ask them before you arrive.",
        "summary_it": "Il centro storico di Salerno (tra via Roma e via Duomo / via San Benedetto) è una ZTL con 10 varchi a telecamera, tra cui Portanova, via Duomo e Corso Vittorio Emanuele. Senza permesso non entrare. Dormi dentro? L'hotel o il B&B trasmette il tuo transito all'Ufficio Varchi ZTL: chiedi prima di arrivare.",
        "summary_de": "Die Altstadt von Salerno (zwischen Via Roma und Via Duomo / Via San Benedetto) ist eine kameraüberwachte ZTL mit 10 Kameras, u. a. Portanova, Via Duomo und Corso Vittorio Emanuele. Ohne Genehmigung draußen bleiben. Du übernachtest innen? Hotel oder B&B melden deine Durchfahrt dem ZTL-Büro: frag vor der Anreise.",
        "perimeter": [], "gates": [],
        "windows": [{"weekdays": ALL, "start": 0, "end": 24 * 60}],
        "freeOnHolidays": False, "holidaysAsSunday": False, "exemptFuels": [], "hotelCanRegister": True,
        "source": {"authority": "City of Salerno", "pageURL": OFFICE, "quote": QUOTE,
                   "quoteTranslation": "Checking and receiving transits sent by: private garages; bed and breakfasts; public bodies, Salerno Solidale, Convitto Nazionale, the Curia, the hostel, hotels and guesthouses.",
                   "quoteTranslation_de": "Prüfung und Empfang der Durchfahrten, die gemeldet werden von: privaten Garagen; Bed and Breakfasts; öffentlichen Stellen, Salerno Solidale, Convitto Nazionale, Kurie, Hostel, Hotels und Pensionen.",
                   "checkedOn": CHECKED, "reviewedByHuman": False,
                   "pending": [p[0] for p in PENDING], "pending_it": [p[1] for p in PENDING], "pending_de": [p[2] for p in PENDING],
                   "links": LINKS}}

city = {"id": "salerno", "name": "Salerno", "name_it": "Salerno", "name_de": "Salerno",
        "center": {"lat": 40.6800, "lon": 14.7580}, "zones": [zone], "status": "draft",
        "license": "Rules: Comune di Salerno (official pages and form B1). No perimeter yet."}

# Pubblicabile solo con perimetro e citazione degli orari verificata; qui mancano entrambi → bozza
ready = False
out = ROOT / ("Resources/Cities/salerno.json" if ready else "data/drafts/salerno.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/salerno.json" if ready else "Resources/Cities/salerno.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), [(z["id"], len(z["perimeter"]), len(z["gates"])) for z in city["zones"]])
