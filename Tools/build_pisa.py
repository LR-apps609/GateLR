#!/usr/bin/env python3
# Costruisce Resources/Cities/pisa.json dalle fonti ufficiali salvate in data/raw/pisa/ (vedi docs/fonti-pisa.md).
# Non ricostruisce le altre città e non tocca manifest.json.
# Uso: python3 Tools/build_pisa.py
#
# Stato delle fonti (letture del 24/10/2026):
# - www.comune.pisa.it raggiungibile (contenuti letti via API OpenCity /api/opendata/v2/content/read/<id>);
# - pisamo.it, mobilita.pisamo.it, varchi.pisamo.it, opendata.comune.pisa.it e overpass-api.de NON raggiungibili;
# - dati.gov.it: nessun dataset ZTL del Comune di Pisa.
# Quindi: orari ufficiali, varchi e perimetro restano «da verificare».
# OpenStreetMap (data/raw/geo/pisa-ztl.json e pisa-gates.json, scaricati da Tools/fetch_geo.py, ODbL 1.0):
# la relazione 9342809 «Zona a Traffico Limitato» elenca solo le telecamere (ruolo «device»), senza contorno.
# Lo script prende i varchi da lì; il perimetro solo da una relazione-area chiusa (boundary=limited_traffic_zone),
# se un giorno compare in quei dati, o da data/raw/pisa/osm-ztl.json (way chiusa).
# Finché gli orari non sono ufficiali (HOURS_OFFICIAL = False) Pisa resta in data/drafts, anche con il perimetro.
import html
import json
import re
from pathlib import Path

import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/pisa"
CHECKED = "2026-10-24T12:00:00Z"
EVERY_DAY = [1, 2, 3, 4, 5, 6, 7]
HOURS_OFFICIAL = False   # la fascia 0–24 è prudenziale, non del Comune: finché resta così, la scheda è una bozza
OSM_ZTL = 9342809        # relazione OSM «Zona a Traffico Limitato» (enforcement=access, solo varchi)


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


def content(object_id):
    """Una pagina del sito del Comune salvata dall'API OpenCity"""
    return json.loads((RAW / f"comune-pisa-content-{object_id}.json").read_text(encoding="utf-8"))


def text(object_id, field):
    v = content(object_id)["data"]["ita-IT"][field]
    v = v if isinstance(v, str) else v.get("content", "")
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", v)))


def osm_perimeter():
    """Perimetro da OpenStreetMap, se è stato salvato. Restituisce (punti, id OSM) o ([], None)."""
    for e in osm_geo.load("pisa-ztl"):
        if e["type"] == "relation" and e.get("tags", {}).get("boundary") == "limited_traffic_zone":
            return osm_geo.perimeter(osm_geo.outer_ring(e)), f"relation/{e['id']}"
    f = RAW / "osm-ztl.json"
    if not f.exists():
        return [], None
    from build_firenze import simplify
    data = json.loads(f.read_text(encoding="utf-8"))
    best = None
    for el in data.get("elements", []):
        if el["type"] == "way" and el.get("geometry") and el["geometry"][0] == el["geometry"][-1]:
            pts = [[p["lon"], p["lat"]] for p in el["geometry"]]
            if best is None or len(pts) > len(best[0]):
                best = (pts, f"way/{el['id']}")
    if best is None:
        return [], None
    pts = simplify(best[0], 0.00001)
    return [{"lat": round(p[1], 6), "lon": round(p[0], 6)} for p in pts], best[1]


# Le frasi citate vengono lette dai file salvati: se la pagina cambia, lo script si ferma.
SERVICE = 3404   # Registrazione Targhe per accesso veicoli in ZTL (servizio, modificato il 03/08/2026)
QUOTE = "Solo alle strutture ricettive professionali: Alberghi, B&B e similari"
assert QUOTE in text(SERVICE, "audience"), "La pagina del servizio è cambiata: ricontrollare la citazione"
assert "12 euro per la durata di 24 ore" in text(5972, "body")
assert "10 ore di tempo anziché 6" in text(5674, "body")
assert "due ore prima del fischio d’inizio" in text(30326, "body")

service_page = "https://www.comune.pisa.it/Servizi/Registrazione-Targhe-per-accesso-veicoli-in-ZTL"
links = [
    link("City of Pisa: hotels register guests' plates", "Comune di Pisa: registrazione targhe per le strutture ricettive",
         "Stadt Pisa: Kennzeichen-Registrierung durch Unterkünfte", service_page),
    link("City of Pisa: hotel guests, €12 for 24 hours (news, Feb 2023)",
         "Comune di Pisa: clienti delle strutture ricettive, 12 € per 24 ore (comunicato, feb. 2023)",
         "Stadt Pisa: Hotelgäste, 12 € für 24 Stunden (Mitteilung, Feb. 2023)",
         "https://www.comune.pisa.it/Novita/Comunicati/Turismo-e-mobilita-in-centro-cambia-la-sosta-per-i-clienti-delle-strutture-ricettive"),
    link("City of Pisa: 10 hours to register the plate (news, Feb 2023)",
         "Comune di Pisa: 10 ore per caricare la targa (comunicato, feb. 2023)",
         "Stadt Pisa: 10 Stunden für die Registrierung (Mitteilung, Feb. 2023)",
         "https://www.comune.pisa.it/Novita/Comunicati/Rinviate-al-6-marzo-le-nuove-modalita-di-sosta-e-accesso-alla-Ztl-per-le-strutture-ricettive"),
    link("City of Pisa: ZTL Stadio on home match days", "Comune di Pisa: ZTL Stadio nelle partite casalinghe",
         "Stadt Pisa: ZTL Stadio an Heimspieltagen",
         "https://www.comune.pisa.it/Novita/Comunicati/Calcio-con-l-avvio-della-nuova-stagione-torna-attiva-la-ZTL-Stadio-in-occasione-delle-partite-casalinghe-del-Pisa-SC"),
    link("Pisamo: ZTL permits", "Pisamo: permessi ZTL", "Pisamo: ZTL-Genehmigungen", "https://mobilita.pisamo.net/"),
]

perimeter, osm_id = osm_perimeter()
# I varchi (telecamere) della relazione OSM, con coordinate; i nomi dai nodi di pisa-gates.json
gate_nodes = osm_geo.load("pisa-ztl") + [e for e in osm_geo.load("pisa-gates") if e["type"] == "node"]
gates = sorted((osm_geo.gate_json("pi", g) for g in osm_geo.gates(gate_nodes, {OSM_ZTL}, name_prefix=None)),
               key=lambda g: (g["name"], g["id"]))
if gates:
    links.append(link(f"OpenStreetMap: relation {OSM_ZTL} (ZTL gates, ODbL)", f"OpenStreetMap: relazione {OSM_ZTL} (varchi ZTL, ODbL)",
                      f"OpenStreetMap: Relation {OSM_ZTL} (ZTL-Kameras, ODbL)", osm_geo.osm_url("relation", OSM_ZTL)))

pending = [
    ("Hours: no official page with the current hours could be opened (the Pisamo sites were unreachable). "
     "GateLR treats the ZTL as always active, to be safe; travel guides say 24 hours a day, every day.",
     "Orari: nessuna pagina ufficiale con gli orari attuali è stata raggiungibile (siti Pisamo irraggiungibili). "
     "GateLR considera la ZTL sempre attiva, per prudenza; le guide non ufficiali indicano 24 ore su 24, tutti i giorni.",
     "Zeiten: Keine offizielle Seite mit den aktuellen Zeiten war erreichbar (Pisamo-Seiten nicht erreichbar). "
     "GateLR behandelt die ZTL vorsichtshalber als immer aktiv; Reiseführer nennen rund um die Uhr, täglich."),
    ("Public holidays: no official rule found.",
     "Festivi: nessuna regola ufficiale trovata.",
     "Feiertage: keine offizielle Regel gefunden."),
    ("Hotel guests: in 2023 the city announced €12 for 24 hours (ZTL access and blue-line parking), "
     "with the plate uploaded by the accommodation within 10 hours of entry and permits limited to the number of rooms. Current price and deadline to be confirmed with Pisamo.",
     "Ospiti delle strutture ricettive: nel 2023 il Comune ha annunciato 12 € per 24 ore (accesso ZTL e sosta sulle strisce blu), "
     "targa caricata dalla struttura entro 10 ore dall'ingresso, permessi non oltre il numero di camere. Prezzo e scadenza attuali da confermare con Pisamo.",
     "Hotelgäste: 2023 kündigte die Stadt 12 € für 24 Stunden an (ZTL-Zufahrt und Parken auf blauen Linien), "
     "Kennzeichen von der Unterkunft binnen 10 Stunden nach der Einfahrt eingetragen, höchstens so viele Genehmigungen wie Zimmer. Aktueller Preis und Frist bei Pisamo zu bestätigen."),
    ("Only professional accommodation (hotels, B&Bs and similar) can register plates; holiday flats are not mentioned.",
     "Solo le strutture ricettive professionali (alberghi, B&B e similari) possono registrare le targhe; gli affitti brevi non sono citati.",
     "Nur gewerbliche Unterkünfte (Hotels, B&Bs u. ä.) können Kennzeichen registrieren; Ferienwohnungen werden nicht erwähnt."),
    ("No day ticket for tourists found.",
     "Nessun permesso giornaliero per turisti trovato.",
     "Kein Tagesticket für Touristen gefunden."),
    ("Gates: camera positions from OpenStreetMap, to be checked against the official list (not published in the sources we could open)."
     if gates else "Gates: list and positions not published in the sources we could open.",
     "Varchi: posizioni delle telecamere da OpenStreetMap, da verificare con l'elenco ufficiale (non pubblicato nelle fonti raggiungibili)."
     if gates else "Varchi: elenco e posizioni non pubblicati nelle fonti raggiungibili.",
     "Kameras: Standorte aus OpenStreetMap, mit der offiziellen Liste abzugleichen (in den erreichbaren Quellen nicht veröffentlicht)."
     if gates else "Kameras: Liste und Standorte in den erreichbaren Quellen nicht veröffentlicht."),
    ("Electric cars: a 2010 ordinance let them in for 2011 only; the current rule is unknown, so GateLR does not exempt them.",
     "Auto elettriche: un'ordinanza del 2010 le ammetteva solo per il 2011; la regola attuale non è nota, quindi GateLR non le esenta.",
     "Elektroautos: Eine Verordnung von 2010 ließ sie nur für 2011 zu; die aktuelle Regel ist unbekannt, daher keine Ausnahme."),
    ("Not shown yet: the ZTL Stadio at Porta a Lucca (home matches of Pisa SC, from 2 hours before kick-off to the end of the first half), "
     "the summer night ZTL on the Lungarni and the pedestrian area of via Corsica and piazza Buonamici.",
     "Non ancora mostrate: la ZTL Stadio a Porta a Lucca (partite casalinghe del Pisa SC, da due ore prima del fischio d'inizio al termine del primo tempo), "
     "la ZTL notturna estiva dei Lungarni e l'area pedonale di via Corsica e piazza Buonamici.",
     "Noch nicht angezeigt: die ZTL Stadio in Porta a Lucca (Heimspiele von Pisa SC, ab 2 Stunden vor Anpfiff bis Ende der ersten Halbzeit), "
     "die sommerliche Nacht-ZTL an den Lungarni und die Fußgängerzone Via Corsica / Piazza Buonamici."),
]
if osm_id:
    pending.insert(1, (f"Perimeter approximated from OpenStreetMap ({osm_id}), not official.",
                       f"Perimetro approssimato da OpenStreetMap ({osm_id}), non ufficiale.",
                       f"Grenze aus OpenStreetMap angenähert ({osm_id}), nicht amtlich."))
else:
    pending.insert(1, ("Perimeter: no official geometry, and OpenStreetMap has the ZTL cameras but no outline, so the zone is not drawn on the map.",
                       "Perimetro: nessuna geometria ufficiale, e OpenStreetMap ha le telecamere della ZTL ma non il contorno, quindi la zona non è disegnata sulla mappa.",
                       "Grenze: keine amtliche Geometrie, und OpenStreetMap hat die ZTL-Kameras, aber keinen Umriss; daher wird die Zone nicht auf der Karte gezeigt."))

zone = {
    "id": "pisa-ztl", "name": "ZTL · Historic Centre", "name_it": "ZTL · Centro storico", "name_de": "ZTL · Altstadt",
    "kind": "restricted",
    "summary": "Pisa's historic centre is a camera-controlled ZTL. We haven't confirmed the hours from an official source, so GateLR treats it as always active. If you sleep in a hotel or B&B, it can register your plate.",
    "summary_it": "Il centro storico di Pisa è una ZTL controllata da telecamere. Non abbiamo confermato gli orari da una fonte ufficiale, quindi GateLR la considera sempre attiva. Se dormi in un hotel o B&B, la struttura può registrare la tua targa.",
    "summary_de": "Pisas Altstadt ist eine kameraüberwachte ZTL. Die Zeiten sind nicht amtlich bestätigt, daher behandelt GateLR sie als immer aktiv. Wenn du im Hotel oder B&B übernachtest, kann die Unterkunft dein Kennzeichen registrieren.",
    "perimeter": perimeter, "gates": gates,
    # Fascia prudenziale, NON ufficiale: vedi il primo punto «pending»
    "windows": [{"weekdays": EVERY_DAY, "start": 0, "end": 24 * 60}],
    "freeOnHolidays": None, "exemptFuels": [], "hotelCanRegister": True,
    "source": {"authority": "City of Pisa", "pageURL": service_page, "ordinance": None, "ordinanceURL": None,
               "quote": QUOTE,
               "quoteTranslation": "Only for professional accommodation: hotels, B&Bs and similar",
               "quoteTranslation_de": "Nur für gewerbliche Unterkünfte: Hotels, B&Bs und Ähnliches",
               "checkedOn": CHECKED, "reviewedByHuman": False,
               "pending": [p[0] for p in pending], "pending_it": [p[1] for p in pending], "pending_de": [p[2] for p in pending],
               "links": links},
}

city = {"id": "pisa", "name": "Pisa", "name_it": "Pisa", "name_de": "Pisa",
        "center": {"lat": 43.7167, "lon": 10.4017}, "zones": [zone], "status": "draft"}
if osm_id or gates:
    city["license"] = ("Rules: Comune di Pisa official pages. " + ("Perimeter and gates" if osm_id else "Gates") + ": "
                       + osm_geo.ODBL + " (approximate, not official)")

# Senza perimetro, o con orari non ancora confermati, Pisa resta tra le bozze (data/drafts)
ready = HOURS_OFFICIAL and all(len(z["perimeter"]) >= 4 for z in city["zones"])
out = ROOT / ("Resources/Cities/pisa.json" if ready else "data/drafts/pisa.json")
if not ready: (ROOT / "Resources/Cities/pisa.json").unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.name, [(z["id"], len(z["perimeter"]), len(z["gates"])) for z in city["zones"]])
