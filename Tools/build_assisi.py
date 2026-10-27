#!/usr/bin/env python3
# Costruisce la scheda di Assisi (bozza) da quanto salvato in data/raw/assisi/ (fonti e date in docs/fonti-assisi.md).
#
# Regole: ordinanze della Polizia Locale salvate il 26/10/2026. Ad Assisi gli orari della ZTL NON sono fissi: li stabilisce
# un'ordinanza ogni una-due settimane (n. 355 dal 9 al 21 ottobre, n. 368 dal 22 al 30 ottobre 2026, n. 378 per il solo
# 27 ottobre). Le finestre qui sotto sono quelle dell'ordinanza 368 (uguali alla 355), valide solo fino al 30/10/2026.
# Per questo, e perché manca il perimetro (nessun open data; OpenStreetMap non raggiungibile dal sandbox il 26/10/2026),
# la scheda resta in data/drafts/assisi.json. Per pubblicarla servono il perimetro (data/raw/assisi/ztl_perimetro.geojson,
# WGS84, da OSM: strade raggiungibili solo dai 5 varchi come in build_perugia.py) e un modo di seguire le ordinanze
# periodiche (o la conferma del Comune che lo schema feriali/prefestivi resta stabile).
# Ricontrollo 27/10/2026: nessun elenco ufficiale dei varchi (l'ordinanza cita le DGC 80/2016 e 231/2025 senza nominarli;
# i nomi sono solo nella stampa) e www.comune.assisi.pg.it chiude la connessione: perimetro ancora assente. Le finestre restano
# SENZA season (una season limitata al periodo dell'ordinanza farebbe risultare la zona libera dopo la scadenza).
# Uso: python3 Tools/build_assisi.py   (non tocca le altre città né manifest.json)
import json, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/assisi"
CHECKED = "2026-10-26T23:00:00Z"
MON_FRI, SAT_SUN = [2, 3, 4, 5, 6], [7, 1]



def flat(s):
    return re.sub(r"\s+", " ", s).strip()


TEXT = {p.stem: flat(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def check(file, *phrases):
    """Ogni frase citata o riassunta deve comparire, parola per parola, nel testo salvato"""
    for q in phrases:
        if flat(q) not in TEXT[file]:
            raise SystemExit(f"{file}: frase non trovata: {q!r}")


ORD, ORD27, PERMIT_F, LIST_F = ("ordinanza-368-2026-ztl-22-30-ottobre", "ordinanza-378-2026-ztl-27-ottobre",
                                "comune-permesso-ztl", "comune-regolamentazione-ztl-ordinanze")
PERMIT = "https://www.comune.assisi.pg.it/servizi/mobilita_e_trasporti/servizio_23.html"
ORDERS = "https://www.comune.assisi.pg.it/novita/comunicati_stampa/novita_298.html"
NEWS = "https://www.assisinews.it/cronaca/dal-16-settembre-entrano-in-funzione-i-varchi-elettronici-con-multe-in-caso-di-violazioni/"
QUOTE = "B) DIVIETO DI CIRCOLAZIONE E SOSTA per tutti i veicoli dalle ore 11.00 alle ore 12.30 e dalle 15.30 alle 17.30"
check(ORD, "N. 368", "dal 22 al 30 ottobre 2026", "GIORNI FESTIVI e PREFESTIVI",
      "A) DIVIETO DI CIRCOLAZIONE E SOSTA, all’interno della Z.T.L. per tutti i veicoli dalle ore 11.00 alle ore 20.00",
      "dei turisti con prenotazione alberghiera diretti ad alberghi del centro storico",
      "GIORNI FERIALI ESCLUSO IL SABATO", QUOTE,
      "I veicoli ad alimentazione esclusivamente elettrica hanno titolo ad accedere e sostare all’interno della ZTL",
      "saranno inseriti in apposita lista, presentando richiesta su modulistica predisposta dal Comando della Polizia Locale",
      "è consentito, previa autorizzazione, l'accesso per le sole operazioni di carico scarico bagagli della durata massima di sessanta minuti",
      "effettuare la predetta comunicazione da parte delle strutture entro le 72 ore successive al transito",
      "Deliberazione della Giunta Comunale n. 231 dell’11 dicembre 2025",
      "eccetto: i ciclomotori e motocicli a due ruote")
check(ORD27, "CON RIFERIMEMTO ALLA SOLA GIORTNATA DEL 27 .10. 2026", "per tutti i veicoli dalle ore 11.00 alle alle 20:00")
check(PERMIT_F, "prima dell’accesso, o entro le 72 ore successive", "Ultimo aggiornamento: 14-10-2026")
check(LIST_F, "Regolamentazione ZTL dal 9 al 21 ottobre 2026", "Regolamentazione ZTL dal 22 al 30 ottobre 2026")
check("websearch-1-varchi-orari-hotel", "Porta San Giacomo, Largo Properzio, via Porta Perlici, via Marconi (in prossimità del parcheggio Giovanni Paolo II) e via del Turrione",
      "dal 16 settembre 2026 entreranno pienamente in funzione i varchi elettronici")
check("websearch-3-date-multe", "84 euro, reduced to 58.10 euro")


def hm(h, m=0):
    return h * 60 + m


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


LINKS = [link("City of Assisi: ZTL orders in force (they change every one or two weeks)", "Comune di Assisi: ordinanze ZTL in vigore (cambiano ogni una o due settimane)",
              "Stadt Assisi: geltende ZTL-Anordnungen (sie ändern sich alle ein bis zwei Wochen)", ORDERS),
         link("City of Assisi: ZTL permit (forms for hotels, electric cars, disabled badge)", "Comune di Assisi: permesso per ZTL (moduli per strutture ricettive, auto elettriche, disabili)",
              "Stadt Assisi: ZTL-Genehmigung (Formulare für Hotels, Elektroautos, Behindertenausweis)", PERMIT),
         link("Assisi News: electronic gates with fines from 16 September 2026", "Assisi News: varchi elettronici con multe dal 16 settembre 2026",
              "Assisi News: elektronische Kameras mit Bußgeldern ab 16. September 2026", NEWS)]

PENDING = [
    ("Hours change by order every one or two weeks. These are from order 368 (22–30 October 2026): weekdays except Saturday 11:00–12:30 and 15:30–17:30; Saturdays, Sundays and holidays 11:00–20:00. On 27 October 2026 (order 378) 11:00–20:00. Check the City's current order.",
     "Gli orari cambiano con un'ordinanza ogni una o due settimane. Questi sono dell'ordinanza 368 (22–30 ottobre 2026): feriali escluso il sabato 11–12:30 e 15:30–17:30; prefestivi e festivi 11–20. Il 27 ottobre 2026 (ordinanza 378) 11–20. Controlla l'ordinanza in vigore.",
     "Die Zeiten ändern sich alle ein bis zwei Wochen per Anordnung. Diese stammen aus Anordnung 368 (22.–30. Oktober 2026): werktags außer samstags 11–12:30 und 15:30–17:30; Tage vor Feiertagen und Feiertage 11–20 Uhr. Am 27. Oktober 2026 (Anordnung 378) 11–20 Uhr. Prüfe die geltende Anordnung."),
    ("Map outline and gate positions missing. The five gates are Porta San Giacomo, Largo Properzio, Via Porta Perlici, Via Marconi (near the Giovanni Paolo II car park) and Via del Turrione (local news).",
     "Mancano perimetro e posizione dei varchi. I cinque varchi sono Porta San Giacomo, Largo Properzio, via Porta Perlici, via Marconi (vicino al parcheggio Giovanni Paolo II) e via del Turrione (stampa locale).",
     "Grenze und Kamerastandorte fehlen. Die fünf Kameras stehen an Porta San Giacomo, Largo Properzio, Via Porta Perlici, Via Marconi (beim Parkplatz Giovanni Paolo II) und Via del Turrione (Lokalmedien)."),
    ("Hotels: tourists going to a hotel may enter only to load and unload luggage, max 60 minutes, with the hotel's badge and a parking disc; the hotel enters your plate online, at the latest within 72 hours. Guests of hotels with private parking may drive to it for the whole stay.",
     "Alberghi: i turisti diretti agli alberghi entrano solo per carico e scarico bagagli, massimo 60 minuti, con il contrassegno della struttura e il disco orario; la struttura inserisce la targa online, al più tardi entro 72 ore. Gli ospiti di strutture con parcheggio privato possono raggiungerlo per tutto il soggiorno.",
     "Hotels: Touristen zu einem Hotel dürfen nur zum Be- und Entladen einfahren, höchstens 60 Minuten, mit dem Ausweis der Unterkunft und Parkscheibe; die Unterkunft trägt dein Kennzeichen online ein, spätestens innerhalb von 72 Stunden. Gäste von Unterkünften mit Privatparkplatz dürfen während des ganzen Aufenthalts dorthin fahren."),
    ("Fully electric cars may enter only once their plate is on the City's list (form of the municipal police): GateLR does not exempt them. Two-wheel motorcycles and mopeds are exempt. Disabled badge holders not on the list register the plate before entering or within 72 hours (permessivarchi@comune.assisi.pg.it).",
     "Le auto solo elettriche entrano solo dopo l'inserimento della targa nella lista del Comune (modulo della Polizia Locale): GateLR non le esenta. Moto e ciclomotori a due ruote sono esenti. I titolari di contrassegno disabili non in lista comunicano la targa prima dell'accesso o entro 72 ore (permessivarchi@comune.assisi.pg.it).",
     "Reine Elektroautos dürfen erst einfahren, wenn ihr Kennzeichen auf der Liste der Stadt steht (Formular der Stadtpolizei): GateLR befreit sie nicht. Zweirädrige Motorräder und Mopeds sind befreit. Inhaber eines Behindertenausweises, die nicht auf der Liste stehen, melden das Kennzeichen vor der Einfahrt oder innerhalb von 72 Stunden (permessivarchi@comune.assisi.pg.it)."),
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
        "summary": "Since 16 September 2026 five cameras guard the old town. Under the order in force until 30 October 2026 it is closed to unauthorised vehicles on weekdays 11:00–12:30 and 15:30–17:30, and on Saturdays, Sundays and holidays 11:00–20:00; outside those hours you may drive in. Hotel guests may enter only to unload luggage (max 60 minutes): give your plate to the hotel.",
        "summary_it": "Dal 16 settembre 2026 cinque telecamere controllano il centro storico. Con l'ordinanza in vigore fino al 30 ottobre 2026 è chiuso ai veicoli non autorizzati nei feriali 11–12:30 e 15:30–17:30, e il sabato, la domenica e i festivi 11–20; fuori da questi orari si entra. Gli ospiti degli hotel entrano solo per scaricare i bagagli (massimo 60 minuti): dai la targa all'hotel.",
        "summary_de": "Seit 16. September 2026 überwachen fünf Kameras die Altstadt. Nach der bis 30. Oktober 2026 geltenden Anordnung ist sie für nicht berechtigte Fahrzeuge werktags 11–12:30 und 15:30–17:30 Uhr gesperrt, samstags, sonntags und an Feiertagen 11–20 Uhr; außerhalb dieser Zeiten darf man hinein. Hotelgäste dürfen nur zum Ausladen einfahren (höchstens 60 Minuten): Kennzeichen dem Hotel geben.",
        "perimeter": perimeter(), "gates": [],
        "windows": [{"weekdays": MON_FRI, "start": hm(11), "end": hm(12, 30)},
                    {"weekdays": MON_FRI, "start": hm(15, 30), "end": hm(17, 30)},
                    {"weekdays": SAT_SUN, "start": hm(11), "end": hm(20)}],
        "freeOnHolidays": False, "holidaysAsSunday": True, "exemptFuels": [], "hotelCanRegister": True,
        "source": {"authority": "City of Assisi", "pageURL": ORDERS,
                   "ordinance": "Ordinanza Polizia Locale n. 368/2026 (ZTL dal 22 al 30 ottobre 2026)", "ordinanceURL": ORDERS,
                   "quote": QUOTE,
                   "quoteTranslation": "B) No driving or parking for all vehicles from 11:00 to 12:30 and from 15:30 to 17:30 (weekdays except Saturday)",
                   "quoteTranslation_de": "B) Fahr- und Parkverbot für alle Fahrzeuge von 11:00 bis 12:30 und von 15:30 bis 17:30 Uhr (werktags außer samstags)",
                   "checkedOn": CHECKED, "reviewedByHuman": False,
                   "pending": [p[0] for p in PENDING], "pending_it": [p[1] for p in PENDING], "pending_de": [p[2] for p in PENDING],
                   "links": LINKS}}

city = {"id": "assisi", "name": "Assisi", "name_it": "Assisi", "name_de": "Assisi",
        "center": {"lat": 43.0707, "lon": 12.6171}, "zones": [zone], "status": "draft", "localHolidays": ["10-04"],
        "license": "Rules: Comune di Assisi, Polizia Locale orders. Perimeter: not yet available."}

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
