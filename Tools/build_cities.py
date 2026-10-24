#!/usr/bin/env python3
# Costruisce Resources/Cities/bologna.json e milano.json dai dati aperti salvati in data/raw/
# (scaricati dai portali dei Comuni, CC BY 4.0 / CC BY) e dalle pagine ufficiali citate in docs/citta-successive.md.
# Uso: python3 Tools/build_cities.py
import json, re
from pathlib import Path
from build_firenze import simplify

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw"
CHECKED = "2026-10-23T12:00:00Z"
EVERY_DAY = [1, 2, 3, 4, 5, 6, 7]
MON_FRI = [2, 3, 4, 5, 6]


def ring(geometry, tol=0.00001):
    """Il contorno esterno più grande, semplificato, come lista di {lat, lon}"""
    polys = [geometry["coordinates"]] if geometry["type"] == "Polygon" else geometry["coordinates"]
    outer = max((p[0] for p in polys), key=len)
    return [{"lat": round(p[1], 6), "lon": round(p[0], 6)} for p in simplify(outer, tol)]


def source(page, quote, translation, links, pending, ordinance=None):
    """translation e pending: (inglese, tedesco) e (inglese, italiano, tedesco)"""
    return {"authority": "", "pageURL": page, "ordinance": ordinance, "ordinanceURL": None,
            "quote": quote, "quoteTranslation": translation[0], "quoteTranslation_de": translation[1],
            "checkedOn": CHECKED, "reviewedByHuman": False,
            "pending": [p[0] for p in pending], "pending_it": [p[1] for p in pending], "pending_de": [p[2] for p in pending],
            "links": links}


def ban(fuel, max_euro, since):
    """Divieto ambientale: le auto con questo carburante e classe Euro fino a max_euro non entrano da «since»"""
    return {"fuel": fuel, "maxEuro": max_euro, "since": since}


# Milano, auto per trasporto persone (calendari ufficiali di Area B e Area C, aggiornati al 15/10/2026).
# Le classi Euro 6 diesel si dividono in A-B-C e D-TEMP/D: qui si usa la data più vicina (A-B-C) e si avvisa.
BANS_B = [ban("petrol", 3, "2025-10-01"), ban("petrol", 4, "2028-10-01"),
          ban("diesel", 5, "2019-02-25"), ban("diesel", 6, "2028-10-01")]
BANS_C = [ban("petrol", 3, "2024-10-01"), ban("petrol", 4, "2027-10-01"), ban("petrol", 5, "2030-10-01"),
          ban("diesel", 5, "2019-02-25"), ban("diesel", 6, "2028-10-01")]


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


def bologna():
    ztl = json.loads((RAW / "bologna/zona-a-traffico-limitato.geojson").read_text())
    main = next(f for f in ztl["features"] if f["properties"]["codice"] == 40)
    zt = json.loads((RAW / "bologna/zona-t-centro-storico.geojson").read_text())["features"][0]
    varchi = json.loads((RAW / "bologna/varchi-bologna.geojson").read_text())["features"]
    gates = [{"id": f"bo-{v['properties']['identificativo_varco']}",
              "name": v["properties"]["nome_varco"].strip(),
              "location": {"lat": round(v["geometry"]["coordinates"][1], 6), "lon": round(v["geometry"]["coordinates"][0], 6)}}
             for v in varchi if v["properties"].get("tipologia_varco") == "ZTL" and v["geometry"]]
    ztl_page = "https://www.comune.bologna.it/informazioni/zona-traffico-limitato-ztl"
    ticket_page = "https://www.comune.bologna.it/servizi/mobilita-trasporti/ticket-accesso-ztl"
    hotel_page = "https://www.comune.bologna.it/servizi/mobilita-trasporti/accesso-sosta-ztl-clienti-alberghi-autorimesse-autofficine"
    links = [link("City of Bologna: ZTL", "Comune di Bologna: ZTL", "Stadt Bologna: ZTL", ztl_page),
             link("City of Bologna: ZTL day ticket", "Comune di Bologna: ticket giornaliero ZTL", "Stadt Bologna: ZTL-Tagesticket", ticket_page),
             link("City of Bologna: hotel guests", "Comune di Bologna: clienti degli alberghi", "Stadt Bologna: Hotelgäste", hotel_page),
             link("Open data: ZTL perimeter and gates (CC BY 4.0)", "Dati aperti: perimetro e varchi ZTL (CC BY 4.0)",
                  "Offene Daten: ZTL-Grenze und Kameras (CC BY 4.0)", "https://opendata.comune.bologna.it/explore/dataset/zona-a-traffico-limitato/")]
    common = [("Public holidays: the city says \"every day\" without mentioning holidays; written confirmation still to be asked.",
               "Festivi: il Comune scrive «tutti i giorni» senza citare i festivi; conferma scritta da chiedere.",
               "Feiertage: Die Stadt schreibt «täglich», ohne Feiertage zu erwähnen; schriftliche Bestätigung steht aus."),
              ("The perimeter in the open data is from 2021: to compare with the current map.",
               "Il perimetro nei dati aperti è del 2021: da confrontare con la mappa attuale.",
               "Die Grenze in den offenen Daten ist von 2021: mit der aktuellen Karte zu vergleichen.")]
    zones = [
        {"id": "bologna-ztl", "name": "ZTL · Historic Centre", "name_it": "ZTL · Centro storico", "name_de": "ZTL · Altstadt", "kind": "pass",
         "summary": "Every day from 7 am to 8 pm you can't drive in without a permit or a day ticket. Inside, Zona T and the pedestrian areas stay closed around the clock.",
         "summary_it": "Tutti i giorni dalle 7 alle 20 non si entra senza permesso o ticket giornaliero. Dentro, la zona T e le aree pedonali restano chiuse 24 ore su 24.",
         "summary_de": "Täglich von 7 bis 20 Uhr keine Einfahrt ohne Genehmigung oder Tagesticket. Zone T und Fußgängerzonen bleiben rund um die Uhr gesperrt.",
         "perimeter": ring(main["geometry"]), "gates": sorted(gates, key=lambda g: g["name"]),
         "windows": [{"weekdays": EVERY_DAY, "start": 7 * 60, "end": 20 * 60}],
         "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": True,
         "ticket": {"price": 6.0, "howTo": "Buy and activate it on the Sosty website before you drive in, and wait for the confirmation. Max 3 per month per car.",
                    "howTo_it": "Compralo e attivalo sul sito Sosty prima di entrare e attendi la conferma. Massimo 3 al mese per auto.",
                    "howTo_de": "Vor der Einfahrt auf der Sosty-Website kaufen und aktivieren und die Bestätigung abwarten. Höchstens 3 pro Monat und Auto.",
                    "url": ticket_page},
         "source": source(ztl_page, "tutti i giorni, dalle 7 alle 20", ("every day, from 7 am to 8 pm", "täglich von 7 bis 20 Uhr"), links, common)},
        {"id": "bologna-t", "name": "Zona T · Rizzoli · Indipendenza · Ugo Bassi", "kind": "restricted",
         "summary": "Closed to cars around the clock, also with a day ticket. Only authorised vehicles may enter.",
         "summary_it": "Chiusa alle auto 24 ore su 24, anche con il ticket giornaliero. Entrano solo i veicoli autorizzati.",
         "summary_de": "Rund um die Uhr für Autos gesperrt, auch mit Tagesticket. Nur berechtigte Fahrzeuge dürfen hinein.",
         "perimeter": ring(zt["geometry"], 0.00001), "gates": [],
         "windows": [{"weekdays": EVERY_DAY, "start": 0, "end": 24 * 60}],
         "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": False,
         "source": source(ztl_page, "alcune zone limitate 24 ore su 24: le zone pedonali e l'area T",
                          ("some zones are limited 24 hours a day: the pedestrian areas and Zona T",
                           "einige Zonen sind rund um die Uhr beschränkt: die Fußgängerzonen und die Zone T"), links,
                          [("Hotel guests: the hotel shows the allowed route; to be checked with the city.",
                            "Ospiti degli hotel: l'hotel indica il percorso consentito; da verificare con il Comune.",
                            "Hotelgäste: Das Hotel zeigt den erlaubten Weg; mit der Stadt zu klären.")])},
    ]
    for z in zones:
        z["source"]["authority"] = "City of Bologna"
    ped = json.loads((RAW / "bologna/zona-pedonale-centro-storico.geojson").read_text())["features"]
    pedestrian = [{"id": f"bo-ap-{f['properties']['codice']}",
                   "name": (f["properties"].get("nomevia1") or "").strip().title() or "Area pedonale",
                   "perimeter": ring(f["geometry"], 0.000005)} for f in ped if f["geometry"]]
    buses = [{"id": f"bo-c-{v['properties']['identificativo_varco']}", "name": v["properties"]["nome_varco"].strip(),
              "location": {"lat": round(v["geometry"]["coordinates"][1], 6), "lon": round(v["geometry"]["coordinates"][0], 6)},
              "kind": "bus"}
             for v in varchi if v["properties"].get("tipologia_varco") == "corsie" and v["geometry"]]
    return {"id": "bologna", "name": "Bologna", "pedestrian": pedestrian, "cameras": buses, "name_it": "Bologna", "name_de": "Bologna", "center": {"lat": 44.4938, "lon": 11.3430}, "zones": zones, "status": "draft",
            "license": "Perimeters and gates: Comune di Bologna open data, CC BY 4.0"}


def milano():
    areas = json.loads((RAW / "milano/aree_pedonali_ztl.geojson").read_text())["features"]
    area_c = next(f for f in areas if f["properties"]["tipo"] == "AREA_C")
    area_b = next(f for f in areas if f["properties"]["tipo"] == "AREA_B")
    varchi = json.loads((RAW / "milano/areac_varchi.geojson").read_text())["features"]
    gates = [{"id": f"mi-c-{v['properties']['id_amat']}", "name": v["properties"]["label"].strip().title(),
              "location": {"lat": round(v["geometry"]["coordinates"][1], 6), "lon": round(v["geometry"]["coordinates"][0], 6)}}
             for v in varchi if v["geometry"]]
    varchi_b = json.loads((RAW / "milano/areab_varchi.geojson").read_text())["features"]
    gates_b = [{"id": f"mi-b-{v['properties']['id_amat']}",
                "name": re.sub(r"^\d+\s*-\s*", "", v["properties"]["nome"]).strip().title(),
                "location": {"lat": round(v["geometry"]["coordinates"][1], 6), "lon": round(v["geometry"]["coordinates"][0], 6)}}
               for v in varchi_b if v["geometry"]]
    page = "https://www.comune.milano.it/argomenti/mobilita/area-c"
    page_b = "https://www.comune.milano.it/argomenti/mobilita/area-b"
    buy = "https://www.comune.milano.it/servizi/mobilita/area-c-acquista-il-ticket"
    links = [link("City of Milan: Area C", "Comune di Milano: Area C", "Stadt Mailand: Area C", page),
             link("City of Milan: buy the Area C ticket", "Comune di Milano: acquista il ticket Area C", "Stadt Mailand: Area-C-Ticket kaufen", buy),
             link("City of Milan: activate the ticket", "Comune di Milano: attiva il ticket", "Stadt Mailand: Ticket aktivieren",
                  "https://www.comune.milano.it/servizi/mobilita/area-c-attiva-il-ticket"),
             link("City of Milan: Area C ban calendar", "Comune di Milano: calendario dei divieti di Area C", "Stadt Mailand: Verbotskalender Area C",
                  "https://www.comune.milano.it/argomenti/mobilita/area-c-calendario-dei-divieti"),
             link("Open data: Area C gates (CC BY)", "Dati aperti: varchi Area C (CC BY)", "Offene Daten: Area-C-Kameras (CC BY)",
                  "https://dati.comune.milano.it/dataset/ds82_infogeo_varchi_elettronici_localizzazione_")]
    links_b = [link("City of Milan: Area B", "Comune di Milano: Area B", "Stadt Mailand: Area B", page_b),
               link("City of Milan: Area B ban calendar", "Comune di Milano: calendario dei divieti di Area B", "Stadt Mailand: Verbotskalender Area B",
                    "https://www.comune.milano.it/argomenti/mobilita/area-b-calendario-dei-divieti"),
               link("Open data: ZTL and Area B perimeters (CC BY)", "Dati aperti: perimetri ZTL e Area B (CC BY)",
                    "Offene Daten: Grenzen von ZTL und Area B (CC BY)", "https://dati.comune.milano.it/dataset/ds51_infogeo_aree_pedonali_ztl_localizzazione_")]
    zone_c = {"id": "milano-c", "name": "Area C · City Centre", "name_it": "Area C · Centro", "name_de": "Area C · Innenstadt", "kind": "pass",
            "summary": "A paid zone: from Monday to Friday, 7:30 am to 7:30 pm, you can drive in with a €7.50 ticket, activated by midnight of the next day. Public holidays are free.",
            "summary_it": "Zona a pagamento: dal lunedì al venerdì, dalle 7:30 alle 19:30, si entra con il ticket da 7,50 €, da attivare entro la mezzanotte del giorno dopo. Festivi esclusi.",
            "summary_de": "Gebührenpflichtige Zone: Montag bis Freitag, 7:30 bis 19:30 Uhr, Einfahrt mit dem 7,50-€-Ticket, das bis Mitternacht des Folgetags aktiviert werden muss. Feiertage frei.",
            "perimeter": ring(area_c["geometry"], 0.00002), "gates": sorted(gates, key=lambda g: g["name"]),
            "windows": [{"weekdays": MON_FRI, "start": 7 * 60 + 30, "end": 19 * 60 + 30}],
            "freeOnHolidays": True, "exemptFuels": [], "hotelCanRegister": False, "bans": BANS_C,
            "ticket": {"price": 7.5, "howTo": "Pay and activate it by midnight of the next day (online, at newsagents or by phone). Later, up to the 7th day, it costs €22.50. Parked in a partner garage: €4.50.",
                       "howTo_it": "Paga e attivalo entro la mezzanotte del giorno dopo (online, in edicola o per telefono). Più tardi, fino al 7° giorno, costa 22,50 €. Con sosta in un garage convenzionato: 4,50 €.",
                       "howTo_de": "Bis Mitternacht des Folgetags bezahlen und aktivieren (online, am Kiosk oder per Telefon). Später, bis zum 7. Tag, kostet es 22,50 €. Mit Parken in einer Partnergarage: 4,50 €.",
                       "url": buy},
            "source": source(page, "Area C è attiva tutto l'anno dal lunedì al venerdì, dalle 7:30 alle 19:30 (festivi esclusi).",
                             ("Area C is active all year from Monday to Friday, 7:30 am to 7:30 pm (public holidays excluded).",
                              "Area C ist das ganze Jahr von Montag bis Freitag, 7:30 bis 19:30 Uhr, aktiv (Feiertage ausgenommen)."), links,
                             [("Electric cars: exemption found only in a search extract, to be confirmed.",
                               "Auto elettriche: esenzione trovata solo in un estratto di ricerca, da confermare.",
                               "Elektroautos: Befreiung nur in einem Suchauszug gefunden, noch zu bestätigen."),
                              ("7 December (Sant'Ambrogio, Milan's patron saint): not known whether it counts as a holiday.",
                               "7 dicembre (Sant'Ambrogio, patrono di Milano): non sappiamo se vale come festivo.",
                               "7. Dezember (Sant'Ambrogio, Mailands Schutzpatron): unklar, ob er als Feiertag gilt.")])}
    zone_b = {"id": "milano-b", "name": "Area B · Low-emission zone", "name_it": "Area B · Zona a basse emissioni",
              "name_de": "Area B · Umweltzone", "kind": "green",
              "summary": "Almost the whole city. From Monday to Friday, 7:30 am to 7:30 pm (holidays excluded), the most polluting vehicles can't drive in. Cleaner cars enter free, no ticket.",
              "summary_it": "Quasi tutta la città. Dal lunedì al venerdì, dalle 7:30 alle 19:30 (festivi esclusi), non entrano i veicoli più inquinanti. Le auto più pulite entrano gratis, senza ticket.",
              "summary_de": "Fast die ganze Stadt. Montag bis Freitag, 7:30 bis 19:30 Uhr (außer Feiertage), dürfen die umweltschädlichsten Fahrzeuge nicht hinein. Sauberere Autos fahren kostenlos ein, ohne Ticket.",
              "perimeter": ring(area_b["geometry"], 0.00008), "gates": sorted(gates_b, key=lambda g: g["name"]),
              "windows": [{"weekdays": MON_FRI, "start": 7 * 60 + 30, "end": 19 * 60 + 30}],
              "freeOnHolidays": True, "exemptFuels": ["electric"], "hotelCanRegister": False, "bans": BANS_B,
              "source": source(page_b, "Area B è attiva dal lunedì al venerdì dalle 7:30 alle 19:30, festivi esclusi",
                               ("Area B is active from Monday to Friday, 7:30 am to 7:30 pm, public holidays excluded",
                                "Area B ist Montag bis Freitag von 7:30 bis 19:30 Uhr aktiv, Feiertage ausgenommen"), links_b,
                               [("Euro 6 diesel: classes A-B-C are banned from 1 Oct 2028, D-TEMP and D from 1 Oct 2030. GateLR uses the earlier date.",
                                 "Diesel Euro 6: le classi A-B-C sono vietate dal 1° ottobre 2028, D-TEMP e D dal 1° ottobre 2030. GateLR usa la data più vicina.",
                                 "Diesel Euro 6: Klassen A-B-C sind ab 1. Okt. 2028 gesperrt, D-TEMP und D ab 1. Okt. 2030. GateLR nimmt das frühere Datum."),
                                ("Free days: from 1 Oct 2026 every vehicle gets 5 days a year without registration, from the second year of its ban.",
                                 "Giornate libere: dal 1° ottobre 2026 ogni veicolo ha 5 giornate all'anno senza registrazione, dal secondo anno di divieto.",
                                 "Freie Tage: Ab 1. Okt. 2026 hat jedes Fahrzeug 5 Tage im Jahr ohne Registrierung, ab dem zweiten Jahr des Verbots."),
                                ("LPG and methane cars are treated like petrol cars of the same class: to be confirmed.",
                                 "Le auto a GPL e metano sono trattate come le benzina della stessa classe: da confermare.",
                                 "Autogas- und Erdgasautos werden wie Benziner derselben Klasse behandelt: noch zu bestätigen."),
                                ("Foreign cars: registration rules for non-Italian plates to be checked.",
                                 "Auto straniere: regole di registrazione per targhe non italiane da verificare.",
                                 "Ausländische Autos: Registrierungsregeln für nicht-italienische Kennzeichen noch zu prüfen.")])}
    for z in (zone_c, zone_b):
        z["source"]["authority"] = "City of Milan"
    pedestrian = [{"id": f"mi-ap-{f['properties']['id_amat']}", "name": (f["properties"].get("nome") or "Area pedonale").strip(),
                   "perimeter": ring(f["geometry"], 0.000005)}
                  for f in areas if f["properties"]["tipo"] == "AP" and f["geometry"]]
    return {"id": "milano", "name": "Milan", "pedestrian": pedestrian, "name_it": "Milano", "name_de": "Mailand", "center": {"lat": 45.4642, "lon": 9.1900},
            "zones": [zone_c, zone_b], "status": "draft",
            "license": "Perimeters and gates: Comune di Milano open data, CC BY"}


for city in (bologna(), milano()):
    out = ROOT / f"Resources/Cities/{city['id']}.json"
    out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(out.name, [(z["id"], len(z["perimeter"]), len(z["gates"])) for z in city["zones"]])

# L'elenco per gli aggiornamenti dell'app (Resources/Cities/manifest.json)
import runpy
runpy.run_path(str(ROOT / "Tools/build_manifest.py"))
