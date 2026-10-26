#!/usr/bin/env python3
# Costruisce Resources/Cities/ferrara.json dalle pagine e dagli atti ufficiali del Comune di Ferrara salvati in
# data/raw/ferrara/ (URL e data di lettura in testa a ogni file; fonti e date in docs/fonti-ferrara.md).
#
# Regole: pagine del Comune (permessi ZTL, giornalieri e abbonamenti, casi particolari, sportello) e Regolamento ZTL
# (DCC P.G. 52201/2022). Il Comune non scrive un orario della ZTL: «Per accedere alla ZTL occorre essere preventivamente
# dotati di Permesso ZTL», e il Regolamento divide i permessi in fasce che coprono tutte le 24 ore (F1–F5, anche
# 24.00–06.00): la ZTL è quindi trattata come attiva 0–24 tutti i giorni (scritto nei pending).
#
# Geometria UFFICIALE (mai disegnata a mano): open data del Comune, WFS «Ferrara:ZTL_esistente_preview»
# (sit.comune.fe.it, catalogo dati.gov.it), salvato in data/raw/ferrara/ztl_perimetro.geojson: 11 poligoni (ZTL A,
# A Garibaldi, B, B Medievale, C, D Certosa, Duomo). Ogni poligono è una zona. Varchi: nessun dato con coordinate
# (OpenStreetMap non raggiungibile dal sandbox il 26/10/2026), restano nei pending.
# Uso: python3 Tools/build_ferrara.py   (non tocca le altre città né manifest.json)
import json, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/ferrara"
CHECKED = "2026-10-26T23:45:00Z"
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


SPORTELLO, DAILY, SPECIAL, PERMITS, OFFICE = ("comune-sportello-mimuovoelettrico", "comune-permessi-ztl-giornalieri",
                                              "comune-casi-particolari", "comune-permessi-ztl", "comune-centro-unico-permessi")
RULES = "regolamento-ztl-dcc-52201-2022"
QUOTE = ("Il centro storico di Ferrara è suddiviso in 4 Zone a Traffico Limitato (A, B, C, D) dotate di varchi per il controllo "
         "elettronico dei transiti veicolari e indicate da apposita segnaletica verticale presente in loco. Per accedere alla ZTL "
         "occorre essere preventivamente dotati di Permesso ZTL rilasciato dal Centro Unico Permessi.")
QUOTE_DUOMO = ("L'accesso alla ZTL Duomo è consentito esclusivamente ai veicoli autorizzati da specifico permesso ZTL (rivolgersi "
               "preventivamente al Centro Unico Permessi che rilascerà l'autorizzazione, se sussistono i requisiti).")
check(SPORTELLO, QUOTE)
check(DAILY, "A tutti coloro che debbano accedere alla ZTL saltuariamente", "singolo ingresso (20€/giorno)",
      "Gli accessi giornalieri alla ZTL vanno acquistati prima di effettuare l'accesso",
      "on line attraverso il portale INES Cloud (ESCLUSI : permessi per ZTL Duomo e Veicoli con massa superiore a 3,5 t)",
      QUOTE_DUOMO, "Piazza Trento Trieste (lati sud ed est dalle ore 6:00 alle ore 11:00 come riportato nella O.S. 17153/2016)")
check(SPECIAL, "L’accesso alle strutture ricettive site in ZTL è consentito agli ospiti per effettuare le operazioni di carico e scarico dei bagagli, o per accedere agli eventuali spazi di sosta delle strutture stesse. All’arrivo occorrerà fornire alle reception la targa del veicolo.")
check(RULES, "Approvato con Delibera di Consi", "F5 24.00 – 06.00 (gratuita).",
      "entro 48 (quarantotto) ore dall'arrivo del cliente",
      "Qualora la targa non venga trasmessa al Centro Unico Permessi il cliente sarà sottoposto all’applicazione della prevista sanzione.",
      "I veicoli elettrici che hanno titolo per l’accesso in ZTL possono circolare e sostare, con regolare autorizzazione, senza limitazioni di orario a titolo gratuito.",
      "devono comunicare al Centro Unico Permessi, entro le 48 ore successive al transito, il modello e la targa",
      "potranno essere rilasciati ad utenti che non appartengono a nessuna categoria",
      "compresa tra 20 € e 30 € al giorno")
check(OFFICE, "Via Marconi, 41")


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


WFS = "https://sit.comune.fe.it/geoserverckan/Ferrara/ZTL_esistente_preview/wfs?service=WFS&version=2.0.0&request=GetCapabilities"
LINKS = [link("City of Ferrara: daily ZTL permits and passes (20 € a day, INES Cloud)",
              "Comune di Ferrara: permessi ZTL giornalieri e abbonamenti (20 € al giorno, INES Cloud)",
              "Stadt Ferrara: ZTL-Tagesgenehmigungen und Abos (20 € pro Tag, INES Cloud)", url_of(DAILY)),
         link("City of Ferrara: special cases (hotel guests)", "Comune di Ferrara: casi particolari (ospiti di alberghi)",
              "Stadt Ferrara: Sonderfälle (Hotelgäste)", url_of(SPECIAL)),
         link("City of Ferrara: ZTL, parking and «Mi Muovo Elettrico» desk", "Comune di Ferrara: sportello permessi ZTL, sosta e Mi Muovo Elettrico",
              "Stadt Ferrara: Schalter für ZTL, Parken und «Mi Muovo Elettrico»", url_of(SPORTELLO)),
         link("City of Ferrara: permit office (Via Marconi 41)", "Comune di Ferrara: Centro Unico Permessi (via Marconi 41)",
              "Stadt Ferrara: Genehmigungsbüro (Via Marconi 41)", url_of(OFFICE)),
         link("City of Ferrara: ZTL regulation 2022 (PDF)", "Comune di Ferrara: regolamento ZTL 2022 (PDF)",
              "Stadt Ferrara: ZTL-Regelung 2022 (PDF)", url_of(RULES)),
         link("City of Ferrara: official ZTL perimeters, open data (WFS)", "Comune di Ferrara: perimetri ufficiali ZTL, open data (WFS)",
              "Stadt Ferrara: offizielle ZTL-Grenzen, offene Daten (WFS)", WFS)]

COMMON_PENDING = [
    ("Hours: the City writes no timetable, only that a permit is needed to enter; the 2022 rules split permits into time bands covering all 24 hours (including midnight–6 am). GateLR treats the ZTL as active 24 hours a day, every day, as unofficial guides also say.",
     "Orari: il Comune non scrive un orario, solo che per entrare serve il permesso; il regolamento 2022 divide i permessi in fasce che coprono tutte le 24 ore (anche 24–6). GateLR tratta la ZTL come attiva 0–24 tutti i giorni, come dicono anche le guide non ufficiali.",
     "Zeiten: Die Stadt nennt keine Uhrzeiten, nur dass zur Einfahrt eine Genehmigung nötig ist; die Regelung von 2022 teilt die Genehmigungen in Zeitbänder über alle 24 Stunden (auch 0–6 Uhr). GateLR behandelt die ZTL als täglich rund um die Uhr aktiv, wie auch inoffizielle Ratgeber sagen."),
    ("Hotels inside the ZTL: guests may enter to unload luggage (max 30 minutes on the street) or reach the hotel's parking; give your plate at reception. The hotel must register it within 48 hours of your arrival, otherwise you are fined.",
     "Alberghi dentro la ZTL: gli ospiti entrano per scaricare i bagagli (sosta su strada massimo 30 minuti) o raggiungere il parcheggio della struttura; dai la targa alla reception. L'hotel deve registrarla entro 48 ore dall'arrivo, altrimenti scatta la multa.",
     "Hotels in der ZTL: Gäste dürfen zum Ausladen (höchstens 30 Minuten auf der Straße) oder zum Hotelparkplatz einfahren; Kennzeichen an der Rezeption angeben. Das Hotel muss es innerhalb von 48 Stunden nach der Ankunft melden, sonst gibt es ein Bußgeld."),
    ("Electric cars still need a permit (free, at all hours): they are not exempt automatically. Disabled badge holders entering occasionally must send plate and gates used to the permit office within 48 hours.",
     "Le auto elettriche hanno comunque bisogno del permesso (gratuito, a ogni ora): non sono esenti in automatico. I titolari di contrassegno disabili che entrano saltuariamente devono comunicare targa e varchi usati al Centro Unico Permessi entro 48 ore.",
     "Elektroautos brauchen trotzdem eine Genehmigung (kostenlos, zu jeder Zeit): sie sind nicht automatisch befreit. Inhaber eines Behindertenausweises, die gelegentlich einfahren, müssen Kennzeichen und benutzte Kameras innerhalb von 48 Stunden dem Genehmigungsbüro melden."),
    ("Gate positions are not on the map yet (no open data with coordinates). New gates are planned in Via Francesco del Cossa and Largo Castello, works due by 31 March 2027 (Estense news site).",
     "La posizione dei varchi non è ancora sulla mappa (nessun open data con coordinate). Sono previsti nuovi varchi in via Francesco del Cossa e Largo Castello, lavori entro il 31 marzo 2027 (notizia di Estense).",
     "Die Kamerastandorte sind noch nicht auf der Karte (keine offenen Daten mit Koordinaten). Neue Kameras sind in Via Francesco del Cossa und Largo Castello geplant, Arbeiten bis 31. März 2027 (Nachrichtenseite Estense)."),
]
DUOMO_PENDING = [
    ("In Piazza Trento Trieste (south and east sides), Piazzetta Gramsci and part of Via San Romano the Duomo rules apply only 6–11 am (order 17153/2016); GateLR applies them all day to the whole zone.",
     "In Piazza Trento Trieste (lati sud ed est), Piazzetta Gramsci e in parte di via San Romano le regole della ZTL Duomo valgono solo dalle 6 alle 11 (O.S. 17153/2016); GateLR le applica tutto il giorno a tutta la zona.",
     "Auf der Piazza Trento Trieste (Süd- und Ostseite), der Piazzetta Gramsci und einem Teil der Via San Romano gelten die Regeln der ZTL Duomo nur 6–11 Uhr (Anordnung 17153/2016); GateLR wendet sie ganztägig auf die ganze Zone an."),
]

TICKET = {"price": 20.0,
          "howTo": "Single-day permit 20 €, for anyone who needs to enter occasionally. Buy it before you enter: online on the INES Cloud portal (PERMESSI ZTL → PRENOTA/ACQUISTA, with SPID/CIE/CNS) or at the permit office, Via Marconi 41 (Mon–Fri 7:30–12). Not valid for the ZTL Duomo.",
          "howTo_it": "Permesso giornaliero 20 €, per chiunque debba entrare saltuariamente. Va comprato prima di entrare: online sul portale INES Cloud (PERMESSI ZTL → PRENOTA/ACQUISTA, con SPID/CIE/CNS) o allo sportello del Centro Unico Permessi, via Marconi 41 (lun–ven 7:30–12). Non vale per la ZTL Duomo.",
          "howTo_de": "Tagesgenehmigung 20 €, für alle, die gelegentlich einfahren müssen. Vor der Einfahrt kaufen: online im Portal INES Cloud (PERMESSI ZTL → PRENOTA/ACQUISTA, mit SPID/CIE/CNS) oder am Genehmigungsbüro, Via Marconi 41 (Mo–Fr 7:30–12). Gilt nicht für die ZTL Duomo.",
          "url": url_of(DAILY), "deadline": "beforeEntry"}

# Nomi delle parti: dal campo NOME del dato ufficiale; descrizione con parole nostre
NAMES = {"ZTL A": ("ZTL A · west of Corso Ercole I d'Este", "ZTL A · a ovest di Corso Ercole I d'Este", "ZTL A · westlich des Corso Ercole I d'Este"),
         "ZTL A Garibaldi": ("ZTL A Garibaldi · Via Garibaldi area", "ZTL A Garibaldi · zona di via Garibaldi", "ZTL A Garibaldi · Gegend Via Garibaldi"),
         "ZTL B": ("ZTL B · southern centre", "ZTL B · centro sud", "ZTL B · südliche Altstadt"),
         "ZTL B Medievale": ("ZTL B Medievale · medieval quarter", "ZTL B Medievale · quartiere medievale", "ZTL B Medievale · mittelalterliches Viertel"),
         "ZTL C": ("ZTL C · north of the Castle", "ZTL C · a nord del Castello", "ZTL C · nördlich der Burg"),
         "ZTL D CERTOSA": ("ZTL D Certosa · Certosa area, north-east", "ZTL D Certosa · zona della Certosa, nord-est", "ZTL D Certosa · Gegend der Certosa, Nordosten"),
         "ZTL DUOMO": ("ZTL Duomo · Cathedral and Corso Martiri", "ZTL Duomo · Cattedrale e Corso Martiri", "ZTL Duomo · Dom und Corso Martiri")}
SUMMARY = ("Closed to vehicles without a permit 24 hours a day, every day. Anyone can buy a 20 € day permit, before entering (INES Cloud online or the permit office). Hotels inside let you in to unload: give your plate at reception, the hotel registers it within 48 hours.",
           "Chiusa ai veicoli senza permesso 24 ore su 24, tutti i giorni. Chiunque può comprare un permesso giornaliero da 20 €, prima di entrare (online su INES Cloud o allo sportello). Gli hotel dentro ti fanno entrare per scaricare: dai la targa alla reception, l'hotel la registra entro 48 ore.",
           "Rund um die Uhr, jeden Tag für Fahrzeuge ohne Genehmigung gesperrt. Jeder kann vor der Einfahrt eine Tagesgenehmigung für 20 € kaufen (online bei INES Cloud oder am Schalter). Hotels in der Zone lassen dich zum Ausladen hinein: Kennzeichen an der Rezeption angeben, das Hotel meldet es innerhalb von 48 Stunden.")
SUMMARY_DUOMO = ("The area around the Cathedral is open only to vehicles with a specific permit, issued by the permit office for documented needs. The 20 € day permit does not cover it.",
                 "L'area della Cattedrale è aperta solo ai veicoli con un permesso specifico, rilasciato dal Centro Unico Permessi per esigenze documentate. Il permesso giornaliero da 20 € non vale.",
                 "Der Bereich um den Dom ist nur für Fahrzeuge mit einer eigenen Genehmigung offen, die das Genehmigungsbüro bei nachgewiesenem Bedarf ausstellt. Die Tagesgenehmigung für 20 € gilt hier nicht.")


def source(quote, translation, extra=()):
    pending = list(extra) + COMMON_PENDING
    return {"authority": "City of Ferrara", "pageURL": url_of(SPORTELLO),
            "ordinance": "Regolamento ZTL, aree pedonali e settori (DCC P.G. 52201/2022 del 16/05/2022)", "ordinanceURL": url_of(RULES),
            "quote": quote, "quoteTranslation": translation[0], "quoteTranslation_de": translation[1],
            "checkedOn": CHECKED, "reviewedByHuman": False,
            "pending": [p[0] for p in pending], "pending_it": [p[1] for p in pending], "pending_de": [p[2] for p in pending],
            "links": LINKS}


feats = json.loads((RAW / "ztl_perimetro.geojson").read_text(encoding="utf-8"))["features"]
count, zones = {}, []
for f in sorted(feats, key=lambda f: (f["properties"]["NOME"], -f["properties"]["AREA_KMQ"])):
    nome = f["properties"]["NOME"]
    polys = f["geometry"]["coordinates"] if f["geometry"]["type"] == "MultiPolygon" else [f["geometry"]["coordinates"]]
    ring = max((p[0] for p in polys), key=osm_geo.area_km2)
    count[nome] = count.get(nome, 0) + 1
    duomo = nome == "ZTL DUOMO"
    en, it, de = NAMES[nome]
    same = sum(1 for g in feats if g["properties"]["NOME"] == nome)
    if same > 1:
        n = count[nome]
        en, it, de = en + f" ({n}/{same})", it + f" ({n}/{same})", de + f" ({n}/{same})"
    zid = "ferrara-" + re.sub(r"[^a-z]+", "-", nome.lower()).strip("-") + (f"-{count[nome]}" if same > 1 else "")
    s = SUMMARY_DUOMO if duomo else SUMMARY
    z = {"id": zid, "name": en, "name_it": it, "name_de": de, "kind": "restricted" if duomo else "pass",
         "summary": s[0], "summary_it": s[1], "summary_de": s[2],
         "perimeter": osm_geo.perimeter(ring, tol_m=2), "gates": [],
         "windows": [{"weekdays": EVERY_DAY, "start": 0, "end": 24 * 60}],
         "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": True}
    if not duomo:
        z["ticket"] = TICKET
    z["source"] = (source(QUOTE_DUOMO, ("Access to the ZTL Duomo is allowed only to vehicles authorised by a specific ZTL permit (ask the permit office in advance, which issues it if the requirements are met).",
                                        "Die Zufahrt zur ZTL Duomo ist nur Fahrzeugen mit einer eigenen ZTL-Genehmigung erlaubt (vorher beim Genehmigungsbüro anfragen, das sie bei erfüllten Voraussetzungen ausstellt)."), DUOMO_PENDING)
                   if duomo else
                   source(QUOTE, ("Ferrara's historic centre is divided into 4 limited traffic zones (A, B, C, D) with gates for electronic checks of vehicles, marked by road signs on site. To enter the ZTL you must first have a ZTL permit issued by the permit office.",
                                  "Die Altstadt von Ferrara ist in 4 verkehrsberuhigte Zonen (A, B, C, D) geteilt, mit Kameras zur elektronischen Kontrolle und Schildern vor Ort. Für die Einfahrt braucht man vorher eine ZTL-Genehmigung des Genehmigungsbüros.")))
    zones.append(z)
    print(f"{zid:28s} {len(z['perimeter']):4d} punti {osm_geo.area_km2(z['perimeter']):.4f} km²")

# Controlli di plausibilità: un luogo famoso dentro, la stazione e il Castello (fossato, strade corridoio) fuori
by = {z["id"]: z for z in zones}
INSIDE = {"ferrara-ztl-duomo": ("Piazza Cattedrale", 44.8358, 11.6205), "ferrara-ztl-d-certosa": ("Certosa di Ferrara", 44.8452, 11.6295),
          "ferrara-ztl-b-medievale": ("Via delle Volte", 44.8330, 11.6210), "ferrara-ztl-a": ("Casa dell'Ariosto", 44.8391, 11.6125)}
for zid, (n, lat, lon) in INSIDE.items():
    assert osm_geo.contains(by[zid]["perimeter"], lat, lon), f"{zid}: {n} non è dentro il perimetro"
for z in zones:
    for n, lat, lon in [("stazione di Ferrara", 44.8433, 11.6066), ("Castello Estense", 44.8377, 11.6188)]:
        assert not osm_geo.contains(z["perimeter"], lat, lon), f"{z['id']}: {n} risulta dentro"
assert 0.9 < sum(osm_geo.area_km2(z["perimeter"]) for z in zones) < 1.6

city = {"id": "ferrara", "name": "Ferrara", "name_it": "Ferrara", "name_de": "Ferrara",
        "center": {"lat": 44.8377, "lon": 11.6188}, "zones": zones, "status": "draft",
        "license": "Rules and perimeters: Comune di Ferrara official pages, regulation and open data (WFS ZTL_esistente_preview)."}

ready = all(len(z["perimeter"]) >= 5 and z["source"]["quote"] for z in zones)
out = ROOT / ("Resources/Cities/ferrara.json" if ready else "data/drafts/ferrara.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/ferrara.json" if ready else "Resources/Cities/ferrara.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), len(zones), "zone")
