#!/usr/bin/env python3
# Costruisce la scheda di Siracusa (bozza) da quanto salvato in data/raw/siracusa/ e data/raw/geo/siracusa-ztl.json
# (fonti e date in docs/fonti-siracusa.md).
#
# Il 26/10/2026 dal sandbox www.comune.siracusa.it e la stampa locale non erano raggiungibili (il proxy rifiuta la
# connessione, 403; WebFetch non risolve gli host). Il workflow «Scarica pagine» non è stato usato per aggirare il blocco.
# Le regole vengono dai riassunti della ricerca web (data/raw/siracusa/websearch-*.txt), NON testo letterale:
#   - nessuna citazione («quote»: null); la scheda resta in data/drafts/siracusa.json.
# Zona: ZTL di Ortigia, ordinanza n. 189 del 30/03/2026 (in vigore dal 01/04/2026; modificata dalla n. 292 dell'08/05/2026
# per le merci): lun–sab 11–15:30 e 17–2 del giorno dopo, domenica e festivi 10–2 del giorno dopo. Il regime invernale
# ridotto (2025–26: O.D. 791 del 23/12/2025, dal 24/12 al 31/03) viene riemesso ogni anno: per l'inverno 2026–27 non è
# ancora uscito alla verifica.
#
# Geometria: OpenStreetMap (© OpenStreetMap contributors, ODbL 1.0), relazione 14425414 «ZTL Siracusa»
# (boundary=limited_traffic_zone, con motor_vehicle:conditional uguale agli orari 2026) e i nodi device delle relazioni
# enforcement 14438941/2/3 (operator «Comune di Siracusa»); nomi dei varchi dalla strada OSM più vicina. Scaricata
# dall'API principale di OSM con Tools/fetch_osm_api.py.
# Uso: python3 Tools/build_siracusa.py   (non tocca le altre città né manifest.json)
import json, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/siracusa"
CHECKED = "2026-10-26T23:55:00Z"
MON_SAT, SUN = [2, 3, 4, 5, 6, 7], [1]
OSM_ZTL = 14425414

ZTL_PAGE = "https://www.comune.siracusa.it/area_tematica/ztl-zona-a-traffico-limitato"
NEWS_2026 = "https://www.comune.siracusa.it/novita/ortigia-da-domani-cambiano-gli-orari-della-zona-a-traffico-limitato"
HOTELS = "https://www.comune.siracusa.it/novita/online-listanza-per-la-richiesta-pass-ztl-temporanei-per-alberghi"
PASS = "https://www.comune.siracusa.it/servizio/rilascio-di-pass-di-sosta-transito-nella-ztl-di-ortigia"
PRESS_APRIL = "https://www.siracusaoggi.it/ztl-di-ortigia-nuova-ordinanza-e-nuove-regole-in-vigore-da-aprile/"
TOURISM = "https://www.siracusaturismo.it/servizi/ztl-zona-a-traffico-limitato/"


def flat(s):
    return re.sub(r"\s+", " ", s).strip()


TEXT = {p.stem: flat(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def check(file, *phrases):
    """Ogni fatto usato deve comparire, parola per parola, nel testo salvato (qui: riassunti della ricerca)"""
    for q in phrases:
        if flat(q) not in TEXT[file]:
            raise SystemExit(f"{file}: frase non trovata: {q!r}")


check("websearch-1-orari-2026",
      "a new Mobility and Transport ordinance took effect on 1 April 2026",
      "Monday to Saturday, access to the island is banned from 11:00 to 15:30 and from 17:00 to 02:00 the next day. On Sundays and holidays, the ban starts at 10:00 and runs without a break until 02:00 the next day.",
      "The Comune's own ZTL page lists the same weekday and Sunday windows.",
      "ordinance n. 189 dated 30/03/2026", "n. 292 of 08/05/2026",
      "Ordinance 791 of 23/12/2025 set reduced hours from 24 December 2025 to 31 March 2026",
      "I couldn't find an ordinance for the October 2026 winter schedule.")
check("websearch-2-hotel",
      "the new Connect Pass platform has been officially active on an experimental basis since Thursday 11 June 2026",
      "operators must send the vehicle plate and length of stay to the Police Command within 48 hours of the guests' transit",
      "The temporary permits can cover only access to the ZTL, not parking.")
check("websearch-3-moto-elettriche-multe", "the Ortigia rules weren't found", "The fine ranges from 84 to 335 euros",
      "scooter and motorbike riders to slip past the ZTL")

GEO = osm_geo.load("siracusa-ztl")
rel = osm_geo.relation(GEO, OSM_ZTL)
if rel["tags"].get("motor_vehicle:conditional") != "permit @ (Mo-Sa 00:00-02:00, 11:00-15:30, 17:00-24:00; Su, PH 00:00-02:00,10:00-24:00)":
    raise SystemExit("Gli orari nella relazione OSM sono cambiati: ricontrollare")
shape = osm_geo.perimeter(osm_geo.outer_ring(rel), tol_m=4)
GATE_NAMES = {5072039713: "Varco · Via Vittorio Veneto", 9939529191: "Varco · Via Malta / Riva della Darsena",
              1839386615: "Varco · Via dei Mille / Corso Umberto I"}
gate_list = sorted((osm_geo.gate_json("sr", (g[0], GATE_NAMES[g[0]], g[2], g[3]))
                    for g in osm_geo.gates(GEO, relation_ids={14438941, 14438942, 14438943}, name_prefix=None)), key=lambda g: g["name"])
if len(gate_list) != 3:
    raise SystemExit(f"Attesi 3 varchi, trovati {len(gate_list)}")
for g in gate_list:
    if osm_geo.distance_m(shape, g["location"]["lat"], g["location"]["lon"]) > 40:
        raise SystemExit(f"Varco lontano dal bordo: {g['name']}")
# Controlli (coordinate dagli stessi dati OSM): piazza Duomo dentro; Tempio di Apollo, parcheggio Talete e Molo
# Sant'Antonio (fuori dall'isola) fuori
for name, lat, lon, inside in [("Piazza Duomo", 37.05939, 15.29318, True), ("Ipogeo di piazza Duomo", 37.05922, 15.29317, True),
                               ("Tempio di Apollo", 37.06402, 15.29300, False), ("Parcheggio Talete", 37.06586, 15.29459, False),
                               ("Molo Sant'Antonio", 37.06308, 15.28475, False)]:
    if osm_geo.contains(shape, lat, lon) != inside:
        raise SystemExit(f"Controllo perimetro fallito: {name} dovrebbe essere {'dentro' if inside else 'fuori'}")
area = osm_geo.area_km2(shape)
if not 0.2 < area < 0.6:
    raise SystemExit(f"Area della ZTL non plausibile: {area:.2f} km²")


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


LINKS = [link("City of Syracuse: Ortigia ZTL (hours and ordinances)", "Comune di Siracusa: ZTL di Ortigia (orari e ordinanze)",
              "Stadt Syrakus: ZTL Ortigia (Zeiten und Verordnungen)", ZTL_PAGE),
         link("City of Syracuse: new ZTL hours", "Comune di Siracusa: Ortigia, cambiano gli orari della ZTL", "Stadt Syrakus: neue ZTL-Zeiten", NEWS_2026),
         link("City of Syracuse: temporary ZTL passes for hotels", "Comune di Siracusa: pass ZTL temporanei per alberghi",
              "Stadt Syrakus: befristete ZTL-Pässe für Hotels", HOTELS),
         link("City of Syracuse: ZTL permits", "Comune di Siracusa: rilascio pass di sosta/transito nella ZTL", "Stadt Syrakus: ZTL-Genehmigungen", PASS),
         link("SiracusaOggi: new ordinance from April 2026", "SiracusaOggi: nuova ordinanza in vigore da aprile 2026",
              "SiracusaOggi: neue Verordnung ab April 2026", PRESS_APRIL),
         link("Siracusa Turismo: Connect Pass for hotels", "Siracusa Turismo: piattaforma Connect Pass per le strutture", "Siracusa Turismo: Connect Pass für Hotels", TOURISM),
         link(f"OpenStreetMap: relation {OSM_ZTL} «ZTL Siracusa» (ODbL)", f"OpenStreetMap: relazione {OSM_ZTL} «ZTL Siracusa» (ODbL)",
              f"OpenStreetMap: Relation {OSM_ZTL} «ZTL Siracusa» (ODbL)", osm_geo.osm_url("relation", OSM_ZTL))]

PENDING = [
    ("Draft: the City's website could not be read from here (connection refused). The hours come from web-search summaries of the City's ZTL page and local press, not from the text of ordinance 189/2026: to be checked word for word.",
     "Bozza: il sito del Comune non era leggibile da qui (connessione rifiutata). Gli orari vengono dai riassunti della ricerca web sulla pagina ZTL del Comune e sulla stampa locale, non dal testo dell'ordinanza 189/2026: da verificare parola per parola.",
     "Entwurf: Die Website der Stadt war von hier aus nicht lesbar (Verbindung abgelehnt). Die Zeiten stammen aus Zusammenfassungen der Websuche zur ZTL-Seite der Stadt und der Lokalpresse, nicht aus dem Text der Verordnung 189/2026: Wort für Wort zu prüfen."),
    ("Winter hours: last winter a lighter regime ran from 24 December 2025 to 31 March 2026 (Fridays and eves of holidays 8 pm–midnight, Saturdays 5 pm–midnight, Sundays and holidays 11 am–midnight; ordinance 791/2025). The 2026–27 winter ordinance had not been found when checked: GateLR shows the stricter 2026 hours until it is out.",
     "Orario invernale: l'inverno scorso valeva un regime ridotto dal 24 dicembre 2025 al 31 marzo 2026 (venerdì e prefestivi 20–24, sabato 17–24, domenica e festivi 11–24; ordinanza 791/2025). L'ordinanza per l'inverno 2026–27 non era ancora stata trovata alla verifica: GateLR mostra gli orari 2026, più restrittivi, finché non esce.",
     "Winterzeiten: Im letzten Winter galt vom 24. Dezember 2025 bis 31. März 2026 eine leichtere Regelung (Freitag und Vorabend von Feiertagen 20–24, Samstag 17–24, Sonn- und Feiertage 11–24 Uhr; Verordnung 791/2025). Die Verordnung für den Winter 2026–27 wurde bei der Prüfung noch nicht gefunden: GateLR zeigt bis dahin die strengeren Zeiten von 2026."),
    ("Hotels, B&Bs and holiday rentals in Ortigia register your plate on the City's Connect Pass platform (since 11 June 2026) within 48 hours of your passage; the pass is for driving in to unload luggage only, not for parking inside.",
     "Alberghi, B&B e case vacanza di Ortigia registrano la targa sulla piattaforma Connect Pass del Comune (dall'11 giugno 2026) entro 48 ore dal passaggio; il pass vale solo per entrare a scaricare i bagagli, non per sostare dentro.",
     "Hotels, B&Bs und Ferienwohnungen in Ortigia melden dein Kennzeichen auf der Plattform Connect Pass der Stadt (seit 11. Juni 2026) innerhalb von 48 Stunden nach der Durchfahrt; der Pass gilt nur zum Ausladen, nicht zum Parken innen."),
    ("Electric cars, motorbikes and Blue Badge holders: Ortigia's rules were not found (motorbikes are stopped like cars at the gates), so GateLR does not exempt them. Fine 84–335 € (Highway Code, unofficial source). Not shown: feast closures (Santa Lucia, 13 December and May; New Year's Eve), set each year by ordinance.",
     "Auto elettriche, moto e contrassegno disabili: le regole di Ortigia non sono state trovate (ai varchi le moto vengono fermate come le auto), quindi GateLR non le esenta. Multa 84–335 € (Codice della Strada, fonte non ufficiale). Non mostrate: le variazioni per le feste (Santa Lucia, 13 dicembre e maggio; Capodanno), decise ogni anno con ordinanza.",
     "Elektroautos, Motorräder und Behindertenausweis: Die Regeln für Ortigia wurden nicht gefunden (Motorräder werden an den Kameras wie Autos behandelt), daher befreit GateLR sie nicht. Bußgeld 84–335 € (Straßenverkehrsordnung, inoffizielle Quelle). Nicht gezeigt: Änderungen zu Festen (Santa Lucia, 13. Dezember und Mai; Silvester), jährlich per Verordnung."),
    ("Perimeter and 3 cameras from OpenStreetMap (its hours match the 2026 ordinance): the north tip of the island (piazza Pancali, Tempio di Apollo, Talete car park) is outside. To be checked against the official map.",
     "Perimetro e 3 varchi da OpenStreetMap (con gli stessi orari dell'ordinanza 2026): la punta nord dell'isola (piazza Pancali, Tempio di Apollo, parcheggio Talete) è fuori. Da confrontare con la mappa ufficiale.",
     "Grenze und 3 Kameras aus OpenStreetMap (mit denselben Zeiten wie die Verordnung 2026): Die Nordspitze der Insel (Piazza Pancali, Apollotempel, Parkhaus Talete) liegt außerhalb. Mit der offiziellen Karte abzugleichen."),
]

zone = {"id": "siracusa-ortigia", "name": "Ortigia · island ZTL", "name_it": "Ortigia · ZTL dell'isola", "name_de": "Ortigia · ZTL der Insel",
        "kind": "restricted",
        "summary": "Ortigia (south of piazza Pancali and the Temple of Apollo) is closed to cars without a permit Monday–Saturday 11 am–3:30 pm and 5 pm–2 am, and on Sundays and holidays from 10 am to 2 am. Mornings until 11 and 3:30–5 pm on weekdays you may drive in. Staying in Ortigia? Your hotel or B&B registers your plate within 48 hours, only to unload. Park at Talete (north tip) or Molo Sant'Antonio and walk.",
        "summary_it": "Ortigia (a sud di piazza Pancali e del Tempio di Apollo) è chiusa alle auto senza permesso dal lunedì al sabato 11–15:30 e 17–2, la domenica e nei festivi dalle 10 alle 2. Nei feriali fino alle 11 e dalle 15:30 alle 17 si entra. Dormi in Ortigia? L'hotel o il B&B registra la targa entro 48 ore, solo per scaricare. Parcheggia al Talete (punta nord) o al Molo Sant'Antonio e cammina.",
        "summary_de": "Ortigia (südlich der Piazza Pancali und des Apollotempels) ist für Autos ohne Genehmigung Montag–Samstag 11–15:30 und 17–2 Uhr gesperrt, sonn- und feiertags von 10 bis 2 Uhr. Werktags bis 11 Uhr und 15:30–17 Uhr darfst du hinein. Du übernachtest in Ortigia? Hotel oder B&B melden dein Kennzeichen binnen 48 Stunden, nur zum Ausladen. Am Talete (Nordspitze) oder am Molo Sant'Antonio parken und laufen.",
        "perimeter": shape, "gates": gate_list,
        "windows": [{"weekdays": MON_SAT, "start": 0, "end": 2 * 60},
                    {"weekdays": MON_SAT, "start": 11 * 60, "end": 15 * 60 + 30},
                    {"weekdays": MON_SAT, "start": 17 * 60, "end": 24 * 60},
                    {"weekdays": SUN, "start": 0, "end": 2 * 60},
                    {"weekdays": SUN, "start": 10 * 60, "end": 24 * 60}],
        "freeOnHolidays": False, "holidaysAsSunday": True, "exemptFuels": [], "hotelCanRegister": True,
        "source": {"authority": "City of Syracuse", "pageURL": ZTL_PAGE,
                   "ordinance": "Ordinanza n. 189 del 30/03/2026 (in vigore dal 01/04/2026), modificata dalla n. 292 dell'08/05/2026",
                   "ordinanceURL": ZTL_PAGE, "quote": None, "quoteTranslation": None, "quoteTranslation_de": None,
                   "checkedOn": CHECKED, "reviewedByHuman": False,
                   "pending": [p[0] for p in PENDING], "pending_it": [p[1] for p in PENDING], "pending_de": [p[2] for p in PENDING],
                   "links": LINKS}}

city = {"id": "siracusa", "name": "Syracuse", "name_it": "Siracusa", "name_de": "Syrakus",
        "center": {"lat": 37.0600, "lon": 15.2930}, "zones": [zone], "status": "draft",
        "license": "Rules: Comune di Siracusa (read through web-search summaries). Perimeter and gates: " + osm_geo.ODBL + " (approximate, not official)."}

# Pubblicabile solo con una citazione verificata sul testo ufficiale; altrimenti bozza
ready = all(len(z["perimeter"]) >= 5 and z["source"]["quote"] for z in city["zones"])
out = ROOT / ("Resources/Cities/siracusa.json" if ready else "data/drafts/siracusa.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/siracusa.json" if ready else "Resources/Cities/siracusa.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), [(z["id"], len(z["perimeter"]), len(z["gates"])) for z in city["zones"]], f"{area:.2f} km²")
