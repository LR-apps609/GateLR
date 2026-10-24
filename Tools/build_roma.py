#!/usr/bin/env python3
# Costruisce Resources/Cities/roma.json dalle pagine ufficiali di Roma Servizi per la Mobilità (RSM)
# salvate in data/raw/roma/ (testo estratto, con URL e data di lettura in testa a ogni file).
# Le fonti di ogni regola sono elencate in docs/fonti-roma.md.
#
# Geometria: i dati ufficiali (hub ArcGIS di RSM, CC BY 3.0 IT) da questa rete non si scaricano. Se qualcuno li salva
# in data/raw/roma/perimetri.geojson (un poligono per zona, proprietà "gatelr_id" = id della zona qui sotto)
# e data/raw/roma/varchi.geojson (punti, proprietà "gatelr_id", "id", "nome"), lo script usa quelli.
# Altrimenti usa OpenStreetMap (data/raw/geo/roma-ztl.json e roma-gates.json, scaricati da Tools/fetch_geo.py,
# © OpenStreetMap contributors, ODbL 1.0): una relazione per zona (OSM_ZONES). Una zona senza perimetro non esce.
#
# Uso: python3 Tools/build_roma.py   (scrive solo roma.json: non tocca le altre città né manifest.json)
import json, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/roma"
OUT = ROOT / "Resources/Cities/roma.json"
CHECKED = "2026-10-24T18:00:00Z"
AUTHORITY = "Roma Servizi per la Mobilità"   # agenzia di Roma Capitale che pubblica orari e permessi ZTL

MON_FRI, SAT, FRI_SAT, WED_THU, MON_SAT = [2, 3, 4, 5, 6], [7], [6, 7], [4, 5], [2, 3, 4, 5, 6, 7]
NO_AUGUST = [{"fromMonth": 1, "fromDay": 1, "toMonth": 7, "toDay": 31},
             {"fromMonth": 9, "fromDay": 1, "toMonth": 12, "toDay": 31}]
MAY_OCT_NO_AUGUST = [{"fromMonth": 5, "fromDay": 1, "toMonth": 7, "toDay": 31},
                     {"fromMonth": 9, "fromDay": 1, "toMonth": 10, "toDay": 31}]

PAGE = "https://romamobilita.it/muoversi-a-roma/ztl-in-centro/"
HOURS = "https://romamobilita.it/infomobilita/ztl-tutti-gli-orari/"
PERMIT_X = "https://romamobilita.it/servizi-al-pubblico/permesso-x-circolazione-e-sosta/"
HOTEL_RULES = "https://romamobilita.it/wp-content/uploads/2016/06/ZTL_Regolamento_Alberghi.pdf"
ELECTRIC = "https://romamobilita.it/servizi-al-pubblico/accesso-in-ztl-di-veicoli-elettrici-o-a-idrogeno-novita-dal-1-luglio-2026/"
TEMPORARY = "https://romamobilita.it/servizi-al-pubblico/permessi-temporanei/"
DATASETS = "https://romamobilita.it/sistemi-e-tecnologie/dataset-geografici/"


def norm(s):
    return re.sub(r"\s+", " ", s).strip()


TEXT = {p.stem: norm(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def check(file, *quotes):
    """Ogni frase citata deve comparire, parola per parola, nella pagina ufficiale salvata"""
    for q in quotes:
        assert norm(q) in TEXT[file], f"{file}: frase non trovata, ricontrollare la pagina: {q!r}"


def window(days, start, end, season=None):
    w = {"weekdays": days, "start": start, "end": end}
    if season:
        w["season"] = season
    return w


def seasonal(days, start, end, seasons):
    return [window(days, start, end, s) for s in seasons]


def hm(h, m=0):
    return h * 60 + m


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


LINKS = [link("Rome: ZTL in the centre (boundaries and hours)", "Roma: ZTL in centro (confini e orari)",
              "Rom: ZTL im Zentrum (Grenzen und Zeiten)", PAGE),
         link("Rome: all ZTL hours", "Roma: tutti gli orari delle ZTL", "Rom: alle ZTL-Zeiten", HOURS),
         link("Rome: electric cars need a permit from 1 July 2026", "Roma: dal 1° luglio 2026 serve il permesso anche alle elettriche",
              "Rom: ab 1. Juli 2026 brauchen auch Elektroautos eine Genehmigung", ELECTRIC),
         link("Rome: temporary permits (only for some categories)", "Roma: permessi temporanei (solo per alcune categorie)",
              "Rom: befristete Genehmigungen (nur für bestimmte Gruppen)", TEMPORARY)]
HOTEL_LINKS = [link("Rome: permit X (hotels)", "Roma: permesso X (alberghi)", "Rom: Genehmigung X (Hotels)", PERMIT_X),
               link("Rome: hotel plate service rules (PDF)", "Roma: regolamento Servizio Alberghi Web (PDF)",
                    "Rom: Regeln des Hotel-Kennzeichendienstes (PDF)", HOTEL_RULES)]

# Le note «da verificare» comuni (inglese, italiano, tedesco)
P_GEOMETRY = ("Perimeter from OpenStreetMap, to be checked against the official map.",
              "Perimetro da OpenStreetMap, da verificare con la mappa ufficiale.",
              "Grenze aus OpenStreetMap, mit der offiziellen Karte abzugleichen.")
P_NIGHT_AREA = ("At night (Friday and Saturday 11 pm–3 am) the ZTL covers a smaller area than by day; GateLR uses the larger daytime outline at night too.",
                "Di notte (venerdì e sabato 23–3) la ZTL copre un'area più piccola che di giorno; GateLR usa anche di notte il perimetro diurno, più ampio.",
                "Nachts (Freitag und Samstag 23–3 Uhr) ist die ZTL kleiner als tagsüber; GateLR nutzt auch nachts die größere Tagesgrenze.")
P_EVENTS = ("The city can change the hours for events, strikes or New Year's Eve: check the news on romamobilita.it.",
            "Il Comune può cambiare gli orari per eventi, scioperi o Capodanno: controlla le notizie su romamobilita.it.",
            "Die Stadt kann die Zeiten für Veranstaltungen, Streiks oder Silvester ändern: Meldungen auf romamobilita.it prüfen.")
P_ELECTRIC = ("Since 1 July 2026 electric and hydrogen cars also need a permit; for visitors it costs €1,000 a year and needs Italian SPID/CIE login.",
              "Dal 1° luglio 2026 anche le auto elettriche e a idrogeno hanno bisogno del permesso; per chi non ne ha diritto costa 1.000 € all'anno e si chiede con SPID/CIE.",
              "Seit 1. Juli 2026 brauchen auch Elektro- und Wasserstoffautos eine Genehmigung; für Besucher 1.000 € im Jahr, Antrag nur mit italienischem SPID/CIE.")
P_HOLIDAY_NIGHT = ("Holidays: GateLR checks the holiday on the current calendar day; for the part after midnight the city may count the evening's date.",
                   "Festivi: GateLR guarda il festivo del giorno di calendario attuale; per la parte dopo mezzanotte il Comune potrebbe contare la data della sera.",
                   "Feiertage: GateLR prüft den aktuellen Kalendertag; für die Zeit nach Mitternacht könnte die Stadt das Datum des Abends zählen.")
P_PATRON = ("29 June (Saints Peter and Paul, Rome's patron saints): not known whether it counts as a holiday for the ZTL.",
            "29 giugno (Santi Pietro e Paolo, patroni di Roma): non sappiamo se vale come festivo per la ZTL.",
            "29. Juni (Peter und Paul, Roms Schutzpatrone): unklar, ob er für die ZTL als Feiertag gilt.")
P_WEDTHU = ("Wednesday and Thursday: the detail page says May to October only, the city's short guide says Wednesday to Saturday without a season. GateLR follows the detail page.",
            "Mercoledì e giovedì: la pagina di dettaglio dice solo da maggio a ottobre, la mini guida del Comune dice dal mercoledì al sabato senza stagione. GateLR segue la pagina di dettaglio.",
            "Mittwoch und Donnerstag: Die Detailseite sagt nur Mai bis Oktober, der Kurzführer der Stadt Mittwoch bis Samstag ohne Saison. GateLR folgt der Detailseite.")
P_HOTEL_NIGHT = ("Hotel guests: the hotel plate service only lists a night slot from 11 pm to 3 am on Friday and Saturday; not known whether it covers this zone.",
                 "Ospiti degli hotel: il servizio targhe per gli alberghi prevede solo una fascia notturna dalle 23 alle 3 di venerdì e sabato; non sappiamo se vale per questa zona.",
                 "Hotelgäste: Der Kennzeichendienst für Hotels kennt nur ein Nachtfenster von 23 bis 3 Uhr am Freitag und Samstag; unklar, ob er für diese Zone gilt.")


def source(quote, translation, pending, links=LINKS):
    return {"authority": AUTHORITY, "pageURL": PAGE, "ordinance": None, "ordinanceURL": None,
            "quote": quote, "quoteTranslation": translation[0], "quoteTranslation_de": translation[1],
            "checkedOn": CHECKED, "reviewedByHuman": False,
            "pending": [p[0] for p in pending], "pending_it": [p[1] for p in pending], "pending_de": [p[2] for p in pending],
            "links": links}


# Zona → relazione OpenStreetMap (data/raw/geo/roma-ztl.json). Per il Trastevere notturno c'è una relazione apposita.
# La ZTL notturna del Centro Storico (relazione 2573034) è più piccola: la zona roma-centro usa quella diurna.
OSM_ZONES = {"roma-centro": 2459882,            # ZTL Diurna Centro Storico
             "roma-tridente": 2459883,          # ZTL Tridente
             "roma-trastevere": 2572441,        # ZTL Diurna Trastevere
             "roma-trastevere-notte": 2691714,  # ZTL Notturna Trastevere
             "roma-san-lorenzo": 2573006,       # ZTL Notturna San Lorenzo
             "roma-testaccio": 2573007}         # ZTL Notturna Testaccio
OSM_ONLY_NAMED = {"roma-tridente": "Tridente", "roma-san-lorenzo": "San Lorenzo"}   # varchi con il nome della zona
GATE_MAX_M = 50   # un varco OSM appartiene a una zona se sta a meno di 50 m dal suo bordo


def official_geometry():
    """Perimetri e varchi ufficiali, se qualcuno li ha salvati (vedi in testa); altrimenti niente"""
    perims, gates = {}, {}
    pf, vf = RAW / "perimetri.geojson", RAW / "varchi.geojson"
    if pf.exists():
        for f in json.loads(pf.read_text())["features"]:
            g = f["geometry"]
            polys = [g["coordinates"]] if g["type"] == "Polygon" else g["coordinates"]
            outer = max((p[0] for p in polys), key=len)
            perims[f["properties"]["gatelr_id"]] = [{"lat": round(y, 6), "lon": round(x, 6)} for x, y in outer]
    if vf.exists():
        for f in json.loads(vf.read_text())["features"]:
            p, (x, y) = f["properties"], f["geometry"]["coordinates"][:2]
            gates.setdefault(p["gatelr_id"], []).append({"id": f"rm-{p['id']}", "name": p["nome"].strip(),
                                                         "location": {"lat": round(y, 6), "lon": round(x, 6)}})
    return perims, gates


def osm_geometry():
    """Perimetri dalle relazioni OSM_ZONES e varchi «Varco ZTL…» vicini al bordo (telecamere delle corsie preferenziali escluse)"""
    elements = osm_geo.load("roma-ztl")
    perims = {zid: osm_geo.perimeter(osm_geo.outer_ring(osm_geo.relation(elements, rid))) for zid, rid in OSM_ZONES.items()}
    found = osm_geo.gates(osm_geo.load("roma-gates"))
    nodes = {e["id"]: e.get("tags", {}) for e in osm_geo.load("roma-gates") if e["type"] == "node"}
    found = [g for g in found if nodes.get(g[0], {}).get("name", "").startswith("Varco ZTL")]
    gates = {}
    for zid, ring in perims.items():
        for g in found:
            named = [k for k, word in OSM_ONLY_NAMED.items() if word in g[1]]
            if (named and zid not in named) or (zid in OSM_ONLY_NAMED and zid not in named):
                continue
            if osm_geo.distance_m(ring, g[2], g[3]) <= GATE_MAX_M:
                gates.setdefault(zid, []).append(osm_geo.gate_json("rm", g))
    return perims, gates


def osm_link(rid):
    return link(f"OpenStreetMap: relation {rid} (perimeter, ODbL)", f"OpenStreetMap: relazione {rid} (perimetro, ODbL)",
                f"OpenStreetMap: Relation {rid} (Grenze, ODbL)", osm_geo.osm_url("relation", rid))


def zones():
    # Le frasi citate vengono ricontrollate sui testi salvati: se RSM cambia la pagina, lo script si ferma.
    check("ztl-in-centro",
          "La ZTL Centro Storico diurna è interdetta ai veicoli non autorizzati nei seguenti orari: 6.30-18.00 da lunedì a venerdì (esclusi i festivi) 14.00-18.00 il sabato (esclusi i festivi)",
          "La ZTL Centro Storico notturna è interdetta ai veicoli non autorizzati nei seguenti orari: 23.00-3.00 venerdì e sabato (esclusi i festivi) nel mese di agosto la ZTL notturna non è attiva",
          "6.30-19.00 da lunedì a venerdì (esclusi i festivi); 10.00-19.00 il sabato (esclusi i festivi)",
          "diurna Trastevere è interdetta ai veicoli non autorizzati: dalle 6.30 alle 10.00 dal lunedì al sabato (esclusi i festivi)",
          "notturna Trastevere è interdetta ai veicoli non autorizzati ed il limite di velocità è 30 Km/h: dalle 21.30 alle 3.00 venerdì e sabato (anche se festivi) da maggio a ottobre è attiva anche il mercoledì e il giovedì (anche se festivi) con gli stessi orari nel mese di agosto la ZTL notturna non è attiva",
          "notturna San Lorenzo è chiusa alle automobili: dalle 21.30 alle 3.00 venerdì e sabato (anche se festivi) da maggio ad ottobre è attiva anche il mercoledì e il giovedì (anche se festivi) con gli stessi orari nel mese di agosto la ZTL non è attiva",
          "notturna Testaccio è interdetta ai veicoli non autorizzati: dalle 23.00 alle 3.00 venerdì e sabato (esclusi i festivi); nel mese di agosto la ZTL non è attiva")
    check("ztl-tutti-gli-orari", "sono in funzione dal mercoledì al sabato dalle 21.30 alle 3.00")
    check("permesso-x-circolazione-e-sosta", "1 permesso ogni 10 stanze a disposizione degli istituti alberghieri",
          "(ad eccezione della ZTL A1 – Tridente ) e “Trastevere”", "cliccando su “Hotel, autorizzazione per i clienti”")
    check("ZTL_Regolamento_Alberghi", "notturna (dalle 23:00 alle 03:00 – nelle sole giornate del venerdì e sabato)",
          "entro la medesima giornata dell’effettivo accesso nelle Zona a Traffico")
    check("accesso-in-ztl-di-veicoli-elettrici-o-a-idrogeno-novita-dal-1-luglio-2026",
          "Non sarà più possibile accedere gratuitamente solo perché il veicolo è a basse emissioni", "1.000 con validità annuale")

    hotel_it = " Se dormi in un hotel dentro la ZTL e l'hotel è iscritto al servizio del Comune, può registrare la tua targa entro il giorno stesso dell'ingresso."
    hotel_en = " If you sleep in a hotel inside the ZTL and the hotel is signed up to the city's service, it can register your plate by the same day you drive in."
    hotel_de = " Wenn du in einem Hotel in der ZTL übernachtest und das Hotel beim Dienst der Stadt angemeldet ist, kann es dein Kennzeichen bis zum Tag der Einfahrt melden."
    no_ticket_en = " There is no day ticket for visitors, electric cars included."
    no_ticket_it = " Non esiste un biglietto giornaliero per i turisti, nemmeno per le auto elettriche."
    no_ticket_de = " Es gibt kein Tagesticket für Besucher, auch nicht für Elektroautos."

    out = [
        {"id": "roma-centro", "name": "ZTL · Historic Centre", "name_it": "ZTL · Centro Storico", "name_de": "ZTL · Altstadt",
         "kind": "restricted",
         "summary": "Closed without a permit Monday to Friday 6:30 am–6 pm and Saturday 2–6 pm, and on Friday and Saturday nights 11 pm–3 am (not in August). Public holidays are free." + no_ticket_en + hotel_en,
         "summary_it": "Chiusa senza permesso dal lunedì al venerdì 6:30–18 e il sabato 14–18, e nelle notti di venerdì e sabato 23–3 (non ad agosto). Festivi esclusi." + no_ticket_it + hotel_it,
         "summary_de": "Ohne Genehmigung gesperrt Montag bis Freitag 6:30–18 Uhr und Samstag 14–18 Uhr, dazu Freitag- und Samstagnacht 23–3 Uhr (nicht im August). Feiertage frei." + no_ticket_de + hotel_de,
         "windows": [window(MON_FRI, hm(6, 30), hm(18)), window(SAT, hm(14), hm(18))] + seasonal(FRI_SAT, hm(23), hm(3), NO_AUGUST),
         "freeOnHolidays": True, "hotelCanRegister": True,
         "source": source("6.30-18.00 da lunedì a venerdì (esclusi i festivi) 14.00-18.00 il sabato (esclusi i festivi) … notturna … 23.00-3.00 venerdì e sabato (esclusi i festivi) nel mese di agosto la ZTL notturna non è attiva",
                          ("6:30 am–6 pm Monday to Friday (holidays excluded), 2–6 pm on Saturday (holidays excluded) … night … 11 pm–3 am Friday and Saturday (holidays excluded); in August the night ZTL is not active",
                           "6:30–18 Uhr Montag bis Freitag (außer Feiertage), 14–18 Uhr am Samstag (außer Feiertage) … Nacht … 23–3 Uhr Freitag und Samstag (außer Feiertage); im August ist die Nacht-ZTL nicht aktiv"),
                          [P_GEOMETRY, P_NIGHT_AREA, P_ELECTRIC, P_HOLIDAY_NIGHT, P_PATRON, P_EVENTS], LINKS + HOTEL_LINKS)},
        {"id": "roma-tridente", "name": "ZTL · Tridente (A1)", "name_it": "ZTL · Tridente (A1)", "name_de": "ZTL · Tridente (A1)",
         "kind": "restricted",
         "summary": "Closed without a permit Monday to Friday 6:30 am–7 pm and Saturday 10 am–7 pm. Public holidays are free. Motorbikes need a permit here too." + no_ticket_en,
         "summary_it": "Chiusa senza permesso dal lunedì al venerdì 6:30–19 e il sabato 10–19. Festivi esclusi. Qui anche le moto hanno bisogno del permesso." + no_ticket_it,
         "summary_de": "Ohne Genehmigung gesperrt Montag bis Freitag 6:30–19 Uhr und Samstag 10–19 Uhr. Feiertage frei. Hier brauchen auch Motorräder eine Genehmigung." + no_ticket_de,
         "windows": [window(MON_FRI, hm(6, 30), hm(19)), window(SAT, hm(10), hm(19))],
         "freeOnHolidays": True, "hotelCanRegister": False,
         "source": source("6.30-19.00 da lunedì a venerdì (esclusi i festivi); 10.00-19.00 il sabato (esclusi i festivi)",
                          ("6:30 am–7 pm Monday to Friday (holidays excluded); 10 am–7 pm on Saturday (holidays excluded)",
                           "6:30–19 Uhr Montag bis Freitag (außer Feiertage); 10–19 Uhr am Samstag (außer Feiertage)"),
                          [P_GEOMETRY, P_ELECTRIC,
                           ("Hotel guests: the hotel permit (X) is valid in the Historic Centre except the Tridente; whether a hotel inside the Tridente can register guests is not stated.",
                            "Ospiti degli hotel: il permesso X degli alberghi vale nel Centro Storico tranne il Tridente; non è scritto se un hotel dentro il Tridente possa registrare i clienti.",
                            "Hotelgäste: Die Hotelgenehmigung (X) gilt in der Altstadt außer im Tridente; ob ein Hotel im Tridente Gäste melden kann, steht nicht da."),
                           ("Night hours: the page gives no night hours for the Tridente; not known whether the Historic Centre night ZTL applies here.",
                            "Orari notturni: la pagina non dà orari notturni per il Tridente; non sappiamo se qui vale la ZTL notturna del Centro Storico.",
                            "Nachtzeiten: Die Seite nennt keine Nachtzeiten für den Tridente; unklar, ob hier die Nacht-ZTL der Altstadt gilt."),
                           P_PATRON, P_EVENTS], LINKS + HOTEL_LINKS)},
        {"id": "roma-trastevere", "name": "ZTL · Trastevere (day)", "name_it": "ZTL · Trastevere (diurna)", "name_de": "ZTL · Trastevere (Tag)",
         "kind": "restricted",
         "summary": "Closed without a permit Monday to Saturday from 6:30 to 10 am. Public holidays are free. At night a separate ZTL applies, also on holidays." + no_ticket_en + hotel_en,
         "summary_it": "Chiusa senza permesso dal lunedì al sabato dalle 6:30 alle 10. Festivi esclusi. Di notte vale una ZTL a parte, anche nei festivi." + no_ticket_it + hotel_it,
         "summary_de": "Ohne Genehmigung gesperrt Montag bis Samstag von 6:30 bis 10 Uhr. Feiertage frei. Nachts gilt eine eigene ZTL, auch an Feiertagen." + no_ticket_de + hotel_de,
         "windows": [window(MON_SAT, hm(6, 30), hm(10))],
         "freeOnHolidays": True, "hotelCanRegister": True,
         "source": source("dalle 6.30 alle 10.00 dal lunedì al sabato (esclusi i festivi)",
                          ("from 6:30 to 10 am Monday to Saturday (holidays excluded)", "von 6:30 bis 10 Uhr Montag bis Samstag (außer Feiertage)"),
                          [P_GEOMETRY, P_ELECTRIC, P_PATRON, P_EVENTS], LINKS + HOTEL_LINKS)},
        {"id": "roma-trastevere-notte", "name": "ZTL · Trastevere (night)", "name_it": "ZTL · Trastevere (notturna)", "name_de": "ZTL · Trastevere (Nacht)",
         "kind": "restricted",
         "summary": "Closed without a permit on Friday and Saturday nights from 9:30 pm to 3 am, and from May to October also on Wednesday and Thursday nights. Also on public holidays. Not active in August." + no_ticket_en,
         "summary_it": "Chiusa senza permesso nelle notti di venerdì e sabato dalle 21:30 alle 3, e da maggio a ottobre anche il mercoledì e il giovedì. Anche nei festivi. Non attiva ad agosto." + no_ticket_it,
         "summary_de": "Ohne Genehmigung gesperrt Freitag- und Samstagnacht von 21:30 bis 3 Uhr, von Mai bis Oktober auch Mittwoch und Donnerstag. Auch an Feiertagen. Im August nicht aktiv." + no_ticket_de,
         "windows": seasonal(FRI_SAT, hm(21, 30), hm(3), NO_AUGUST) + seasonal(WED_THU, hm(21, 30), hm(3), MAY_OCT_NO_AUGUST),
         "freeOnHolidays": False, "hotelCanRegister": False,
         "source": source("dalle 21.30 alle 3.00 venerdì e sabato (anche se festivi) da maggio a ottobre è attiva anche il mercoledì e il giovedì (anche se festivi) con gli stessi orari nel mese di agosto la ZTL notturna non è attiva",
                          ("from 9:30 pm to 3 am Friday and Saturday (also on holidays); from May to October it is also active on Wednesday and Thursday (also on holidays) with the same hours; in August the night ZTL is not active",
                           "von 21:30 bis 3 Uhr Freitag und Samstag (auch an Feiertagen); von Mai bis Oktober auch Mittwoch und Donnerstag (auch an Feiertagen) zu denselben Zeiten; im August ist die Nacht-ZTL nicht aktiv"),
                          [P_GEOMETRY, P_ELECTRIC, P_WEDTHU, P_HOTEL_NIGHT, P_EVENTS])},
        {"id": "roma-san-lorenzo", "name": "ZTL · San Lorenzo (night)", "name_it": "ZTL · San Lorenzo (notturna)", "name_de": "ZTL · San Lorenzo (Nacht)",
         "kind": "restricted",
         "summary": "Closed to cars on Friday and Saturday nights from 9:30 pm to 3 am, and from May to October also on Wednesday and Thursday nights. Also on public holidays. Not active in August." + no_ticket_en,
         "summary_it": "Chiusa alle auto nelle notti di venerdì e sabato dalle 21:30 alle 3, e da maggio a ottobre anche il mercoledì e il giovedì. Anche nei festivi. Non attiva ad agosto." + no_ticket_it,
         "summary_de": "Für Autos gesperrt Freitag- und Samstagnacht von 21:30 bis 3 Uhr, von Mai bis Oktober auch Mittwoch und Donnerstag. Auch an Feiertagen. Im August nicht aktiv." + no_ticket_de,
         "windows": seasonal(FRI_SAT, hm(21, 30), hm(3), NO_AUGUST) + seasonal(WED_THU, hm(21, 30), hm(3), MAY_OCT_NO_AUGUST),
         "freeOnHolidays": False, "hotelCanRegister": False,
         "source": source("dalle 21.30 alle 3.00 venerdì e sabato (anche se festivi) da maggio ad ottobre è attiva anche il mercoledì e il giovedì (anche se festivi) con gli stessi orari nel mese di agosto la ZTL non è attiva",
                          ("from 9:30 pm to 3 am Friday and Saturday (also on holidays); from May to October it is also active on Wednesday and Thursday (also on holidays) with the same hours; in August the ZTL is not active",
                           "von 21:30 bis 3 Uhr Freitag und Samstag (auch an Feiertagen); von Mai bis Oktober auch Mittwoch und Donnerstag (auch an Feiertagen) zu denselben Zeiten; im August ist die ZTL nicht aktiv"),
                          [P_GEOMETRY, P_ELECTRIC, P_WEDTHU, P_HOTEL_NIGHT, P_EVENTS])},
        {"id": "roma-testaccio", "name": "ZTL · Testaccio (night)", "name_it": "ZTL · Testaccio (notturna)", "name_de": "ZTL · Testaccio (Nacht)",
         "kind": "restricted",
         "summary": "Closed without a permit on Friday and Saturday nights from 11 pm to 3 am. Public holidays are free. Not active in August." + no_ticket_en,
         "summary_it": "Chiusa senza permesso nelle notti di venerdì e sabato dalle 23 alle 3. Festivi esclusi. Non attiva ad agosto." + no_ticket_it,
         "summary_de": "Ohne Genehmigung gesperrt Freitag- und Samstagnacht von 23 bis 3 Uhr. Feiertage frei. Im August nicht aktiv." + no_ticket_de,
         "windows": seasonal(FRI_SAT, hm(23), hm(3), NO_AUGUST),
         "freeOnHolidays": True, "hotelCanRegister": False,
         "source": source("dalle 23.00 alle 3.00 venerdì e sabato (esclusi i festivi); nel mese di agosto la ZTL non è attiva",
                          ("from 11 pm to 3 am Friday and Saturday (holidays excluded); in August the ZTL is not active",
                           "von 23 bis 3 Uhr Freitag und Samstag (außer Feiertage); im August ist die ZTL nicht aktiv"),
                          [P_GEOMETRY, P_ELECTRIC, P_HOLIDAY_NIGHT, P_HOTEL_NIGHT, P_PATRON, P_EVENTS])},
    ]
    perims, gates = official_geometry()
    osm_perims, osm_gates = osm_geometry() if len(perims) < len(out) else ({}, {})
    kept = []
    for z in out:
        official = z["id"] in perims
        z["perimeter"] = perims.get(z["id"]) or osm_perims.get(z["id"], [])
        z["gates"] = sorted(gates.get(z["id"]) if official else osm_gates.get(z["id"], []), key=lambda g: (g["name"], g["id"]))
        z["exemptFuels"] = []          # dal 1/7/2026 nessuna esenzione per le elettriche
        s = z["source"]
        if official:                   # con la geometria ufficiale la nota sul perimetro non serve più
            for key, i in (("pending", 0), ("pending_it", 1), ("pending_de", 2)):
                s[key] = [p for p in s[key] if p != P_GEOMETRY[i]]
        elif z["id"] in OSM_ZONES:
            s["links"] = s["links"] + [osm_link(OSM_ZONES[z["id"]])]
        if len(z["perimeter"]) >= 4:   # una zona senza perimetro non si spedisce (l'app non saprebbe dire se sei dentro)
            kept.append(z)
        else:
            print("zona senza perimetro, esclusa:", z["id"])
    out = kept
    order = ["id", "name", "name_it", "name_de", "kind", "summary", "summary_it", "summary_de", "perimeter", "gates",
             "windows", "freeOnHolidays", "exemptFuels", "hotelCanRegister", "source"]
    return [{k: z[k] for k in order} for z in out]


city = {"id": "roma", "name": "Rome", "name_it": "Roma", "name_de": "Rom", "center": {"lat": 41.8960, "lon": 12.4823},
        "zones": zones(), "status": "draft",
        "license": "Hours and rules: Roma Servizi per la Mobilità (romamobilita.it). Perimeters and gates: " + osm_geo.ODBL
                   + " (approximate, not official; the official RSM open data, CC BY 3.0 IT, are still to be downloaded)"}
# Senza perimetri l'app non può dire se un punto è dentro: finché mancano, Roma resta tra le bozze (data/drafts)
if not city["zones"] or not all(len(z["perimeter"]) >= 4 for z in city["zones"]):
    (ROOT / "Resources/Cities/roma.json").unlink(missing_ok=True)
    OUT = ROOT / "data/drafts/roma.json"
else:
    (ROOT / "data/drafts/roma.json").unlink(missing_ok=True)   # la bozza vecchia non serve più
OUT.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(OUT.name, [(z["id"], len(z["perimeter"]), len(z["gates"]), len(z["windows"])) for z in city["zones"]])
