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


def ring(geometry, tol=0.00003):
    """Il contorno esterno più grande, semplificato, come lista di {lat, lon}"""
    polys = [geometry["coordinates"]] if geometry["type"] == "Polygon" else geometry["coordinates"]
    outer = max((p[0] for p in polys), key=len)
    return [{"lat": round(p[1], 6), "lon": round(p[0], 6)} for p in simplify(outer, tol)]


def source(page, quote, translation, links, pending, ordinance=None):
    return {"authority": "", "pageURL": page, "ordinance": ordinance, "ordinanceURL": None,
            "quote": quote, "quoteTranslation": translation, "checkedOn": CHECKED,
            "reviewedByHuman": False, "pending": pending, "links": links}


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
    links = [{"title": "City of Bologna: ZTL", "url": ztl_page},
             {"title": "City of Bologna: ZTL day ticket", "url": ticket_page},
             {"title": "City of Bologna: hotel guests", "url": hotel_page},
             {"title": "Open data: ZTL perimeter and gates (CC BY 4.0)", "url": "https://opendata.comune.bologna.it/explore/dataset/zona-a-traffico-limitato/"}]
    common = ["Public holidays: the city says \"every day\" without mentioning holidays; written confirmation still to be asked.",
              "The perimeter in the open data is from 2021: to compare with the current map."]
    zones = [
        {"id": "bologna-ztl", "name": "ZTL · Historic Centre",
         "summary": "Every day from 7 am to 8 pm you can't drive in without a permit or a day ticket. Inside, Zona T and the pedestrian areas stay closed around the clock.",
         "summary_it": "Tutti i giorni dalle 7 alle 20 non si entra senza permesso o ticket giornaliero. Dentro, la zona T e le aree pedonali restano chiuse 24 ore su 24.",
         "summary_de": "Täglich von 7 bis 20 Uhr keine Einfahrt ohne Genehmigung oder Tagesticket. Zone T und Fußgängerzonen bleiben rund um die Uhr gesperrt.",
         "perimeter": ring(main["geometry"]), "gates": sorted(gates, key=lambda g: g["name"]),
         "windows": [{"weekdays": EVERY_DAY, "start": 7 * 60, "end": 20 * 60}],
         "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": True,
         "ticket": {"price": 6.0, "howTo": "Buy and activate it on the Sosty website before you drive in, and wait for the confirmation. Max 3 per month per car.",
                    "url": ticket_page},
         "source": source(ztl_page, "tutti i giorni, dalle 7 alle 20", "every day, from 7 am to 8 pm", links, common)},
        {"id": "bologna-t", "name": "Zona T · Rizzoli · Indipendenza · Ugo Bassi",
         "summary": "Closed to cars around the clock, also with a day ticket. Only authorised vehicles may enter.",
         "summary_it": "Chiusa alle auto 24 ore su 24, anche con il ticket giornaliero. Entrano solo i veicoli autorizzati.",
         "summary_de": "Rund um die Uhr für Autos gesperrt, auch mit Tagesticket. Nur berechtigte Fahrzeuge dürfen hinein.",
         "perimeter": ring(zt["geometry"], 0.00001), "gates": [],
         "windows": [{"weekdays": EVERY_DAY, "start": 0, "end": 24 * 60}],
         "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": False,
         "source": source(ztl_page, "alcune zone limitate 24 ore su 24: le zone pedonali e l'area T",
                          "some zones are limited 24 hours a day: the pedestrian areas and Zona T", links,
                          ["Hotel guests: the hotel shows the allowed route; to be checked with the city."])},
    ]
    for z in zones:
        z["source"]["authority"] = "City of Bologna"
    return {"id": "bologna", "name": "Bologna", "center": {"lat": 44.4938, "lon": 11.3430}, "zones": zones, "status": "draft",
            "license": "Perimeters and gates: Comune di Bologna open data, CC BY 4.0"}


def milano():
    areas = json.loads((RAW / "milano/aree_pedonali_ztl.geojson").read_text())["features"]
    area_c = next(f for f in areas if f["properties"]["tipo"] == "AREA_C")
    varchi = json.loads((RAW / "milano/areac_varchi.geojson").read_text())["features"]
    gates = [{"id": f"mi-c-{v['properties']['id_amat']}", "name": v["properties"]["label"].strip().title(),
              "location": {"lat": round(v["geometry"]["coordinates"][1], 6), "lon": round(v["geometry"]["coordinates"][0], 6)}}
             for v in varchi if v["geometry"]]
    page = "https://www.comune.milano.it/argomenti/mobilita/area-c"
    buy = "https://www.comune.milano.it/servizi/mobilita/area-c-acquista-il-ticket"
    links = [{"title": "City of Milan: Area C", "url": page},
             {"title": "City of Milan: buy the Area C ticket", "url": buy},
             {"title": "City of Milan: activate the ticket", "url": "https://www.comune.milano.it/servizi/mobilita/area-c-attiva-il-ticket"},
             {"title": "Open data: Area C gates (CC BY)", "url": "https://dati.comune.milano.it/dataset/ds82_infogeo_varchi_elettronici_localizzazione_"}]
    zone = {"id": "milano-c", "name": "Area C · City Centre",
            "summary": "A paid zone: from Monday to Friday, 7:30 am to 7:30 pm, you can drive in with a €7.50 ticket, activated by midnight of the next day. Public holidays are free.",
            "summary_it": "Zona a pagamento: dal lunedì al venerdì, dalle 7:30 alle 19:30, si entra con il ticket da 7,50 €, da attivare entro la mezzanotte del giorno dopo. Festivi esclusi.",
            "summary_de": "Gebührenpflichtige Zone: Montag bis Freitag, 7:30 bis 19:30 Uhr, Einfahrt mit dem 7,50-€-Ticket, das bis Mitternacht des Folgetags aktiviert werden muss. Feiertage frei.",
            "perimeter": ring(area_c["geometry"], 0.00005), "gates": sorted(gates, key=lambda g: g["name"]),
            "windows": [{"weekdays": MON_FRI, "start": 7 * 60 + 30, "end": 19 * 60 + 30}],
            "freeOnHolidays": True, "exemptFuels": [], "hotelCanRegister": False,
            "ticket": {"price": 7.5, "howTo": "Pay and activate it by midnight of the next day (online, at newsagents or by phone). Later, up to the 7th day, it costs €22.50. Parked in a partner garage: €4.50.",
                       "url": buy},
            "source": source(page, "Area C è attiva tutto l'anno dal lunedì al venerdì, dalle 7:30 alle 19:30 (festivi esclusi).",
                             "Area C is active all year from Monday to Friday, 7:30 am to 7:30 pm (public holidays excluded).", links,
                             ["Electric cars: exemption found only in a search extract, to be confirmed.",
                              "7 December (Sant'Ambrogio, Milan's patron saint): not known whether it counts as a holiday.",
                              "Area B (low-emission zone for the whole city) is not in GateLR yet."])}
    zone["source"]["authority"] = "City of Milan"
    return {"id": "milano", "name": "Milan", "center": {"lat": 45.4642, "lon": 9.1900}, "zones": [zone], "status": "draft",
            "license": "Perimeter and gates: Comune di Milano open data, CC BY"}


for city in (bologna(), milano()):
    out = ROOT / f"Resources/Cities/{city['id']}.json"
    out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(out.name, [(z["id"], len(z["perimeter"]), len(z["gates"])) for z in city["zones"]])
