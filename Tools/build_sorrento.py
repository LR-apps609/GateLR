#!/usr/bin/env python3
# Costruisce Resources/Cities/sorrento.json dalle pagine e dall'ordinanza ufficiali del Comune di Sorrento salvate in
# data/raw/sorrento/ (fonti e date in docs/fonti-sorrento.md). Ogni frase citata o riassunta viene ricontrollata sul testo salvato.
#
# Regole: ordinanza dirigenziale n. 230 del 16/06/2023 (sostituisce le n. 321/2021 e 139/2023), «ZTL CENTRO»:
#   periodi di vigenza 1 aprile – 25 ottobre e 7 dicembre – 6 gennaio (in questo periodo solo festivi e prefestivi);
#   orari feriali 19:30–4, festivi 10–13 e 19:30–4. Le stesse date e orari sono sulle pagine del Comune (Z.T.L. Centro,
#   servizi per strutture e permessi temporanei, aggiornate nel 2025) e, per il 2026, nella stampa (1 aprile – 25 ottobre).
#   Stagione invernale: i prefestivi sono i sabati e le vigilie delle feste nel periodo (7/12, 24/12, 31/12, 5/1); i festivi
#   (domeniche, 8/12, 25/12, 26/12, 1/1, 6/1) usano gli orari della domenica (holidaysAsSunday).
# Geometria: la ZTL è un elenco di strade (ordinanza 230/2023): viale Caruso, piazza Tasso, via Correale (dal parcheggio
#   «Lauro» verso piazza Tasso), Corso Italia (da piazza Tasso all'incrocio con via Marziale), via L. De Maio, piazza
#   S. Antonino, via S. Francesco, via Vittorio Veneto, piazza della Vittoria, via Marina Grande. L'area è quella coperta da
#   queste strade OpenStreetMap (osm_geo.street_area, © OpenStreetMap contributors, ODbL 1.0; dati scaricati dall'API OSM
#   con Tools/fetch_osm_api.py e ridotti in data/raw/geo/sorrento-ztl.json). Il tratto basso di via Marina Grande (verso la
#   spiaggia) è staccato dal resto da una scalinata e non ha varchi: è escluso. Varchi: i 4 dell'ordinanza, nei nodi OSM degli
#   incroci indicati (Corso Italia: la telecamera OSM davanti al Carmine).
# Uso: python3 Tools/build_sorrento.py   (non tocca le altre città né manifest.json)
import json, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/sorrento"
CHECKED = "2026-10-27T11:30:00Z"
ALL, SAT, SUN = [1, 2, 3, 4, 5, 6, 7], [7], [1]

B = "https://www.comune.sorrento.na.it/it"
ZTL_PAGE = B + "/novita/page/z-t-l-centro"
HOTELS = B + "/servizi/page/richiesta-autorizzazione-ztl-per-strutture"
TEMP = B + "/servizi/page/rilascio-autorizzazioni-ztl"
NEWS_2025 = B + "/novita/page/sorrento-viabilita-ritorna-la-zona-a-traffico-limitato"
ORD_230 = "https://www.comune.sorrento.na.it/download/b81cb24c5b6b4de7a26a24f08057427e/ORD%20N.%20230.pdf"
PRESS_2026 = "https://www.metropolisweb.it/2026/03/30/torna-la-ztl-sorrento-orari-varchi-regole-vigore-dal-1-aprile-al-25-ottobre/"


def flat(s):
    return re.sub(r"\s+", " ", s).strip()


TEXT = {p.stem: flat(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def check(file, *phrases):
    for q in phrases:
        if flat(q) not in TEXT[file]:
            raise SystemExit(f"{file}: frase non trovata, ricontrollare il documento: {q!r}")


QUOTE = ("Periodi di vigenza della ZTL: • dal 1 aprile al 25 ottobre; dal 7 dicembre al 6 gennaio (limitatamente ai festivi "
         "ed ai prefestivi).")
QUOTE2 = "• giorni feriali: dalle ore 19:30 alle ore 04:00 giorni festivi: dalle ore 10:00 alle ore 13:00 e dalle ore 19:30 alle ore 04:00."
check("ord-230-2023", QUOTE, "Orari di vigenza della ZTL:", QUOTE2, "N° 230 del 16/06/2023", "A decorrere dal 19 giugno 2023:",
      "viale Caruso, piazza Tasso, via Correale (dal parcheggio “Lauro” verso piazza Tasso), Corso Italia (da Piazza Tasso sino all’incrocio con via Marziale), Via L. De Maio, Piazza S. Antonino, Via S. Francesco, Via Vittorio Veneto, Piazza della Vittoria, Via Marina Grande;",
      "Varco n. 1 Via Fuorimura/ inizio Viale Caruso;", "Varco n. 2 Corso Italia (altezza chiesa del Carmine) incrocio Piazza Tasso;",
      "Varco n. 3 Via Correale altezza parcheggio comunale “A. Lauro”;", "Varco n. 4 Via San Francesco incrocio via L. De Maio;",
      "Regolamento approvato con D.C. n. 7 del 16.3.2023 modificato con D.C. n. 28 del 26.5.2023",
      "Non è concessa la sosta al di fuori degli appositi spazi.")
for f in ("comune-ztl-centro", "comune-ztl-strutture", "comune-ztl-temporanea"):
    check(f, "dal 1 aprile al 25 ottobre;", "dal 7 dicembre al 6 gennaio (limitatamente ai festivi ed ai prefestivi).",
          "giorni feriali: dalle ore 19:30 alle ore 04:00", "giorni festivi: dalle ore 10:00 alle ore 13:00 e dalle ore 19:30 alle ore 04:00")
check("comune-ztl-centro", "Ordinanza N° 230 del 16/06/2023",
      "Tali permessi possono essere richiesti preventivamente tramite il portale online del Comune di Sorrento disponibile dal 1 aprile o previa comunicazione al momento del passaggio al numero verde 800 477 311",
      "Tali permessi avranno scadenza il 31 dicembre", "18/08/2025, 15:28")
check("comune-ztl-strutture", "Portale per richiesta permesso di transito in ZTL per strutture", "A chi è rivolto Strutture",
      "PERMESSO DI TRANSITO temporaneo.", "da immediato a 30 gg", "Numero Verde Ztl")
check("comune-news-2025-03-28-ritorna-ztl",
      "La Ztl sarà in vigore tutti i giorni, dalle ore 19.30 alle 4 del giorno seguente e, nei giorni festivi, anche nella fascia compresa tra le ore 10 e le 13.",
      "in via Fuorimura all’inizio di viale Caruso, sul corso Italia, all’altezza della chiesa del Carmine, in via Correale, nei pressi del parcheggio comunale Achille Lauro ed in via San Francesco, all’intersezione con via Luigi De Maio.")
check("websearch-1-stagione-2026", "The ZTL is in force from Wednesday April 1 through October 25",
      "I didn't find a 2026 ordinance number", "roughly EUR 83–332")

# --- geometria: le strade dell'ordinanza ---
GEO = osm_geo.load("sorrento-ztl")
ways = {e["id"]: e for e in GEO if e["type"] == "way"}
WHOLE = {"Viale Enrico Caruso", "Piazza Tasso", "Via Luigi de Maio", "Piazza Sant'Antonino", "Via San Francesco",
         "Via Vittorio Veneto", "Piazza della Vittoria"}
PARTS = {220483717: "Corso Italia", 766566070: "Corso Italia",   # da piazza Tasso all'incrocio con via Marziale
         1127707893: "Via Correale",                             # dal nodo davanti al parcheggio Lauro a piazza Tasso
         657729900: "Via Marina Grande"}                         # il tratto carrabile da piazza della Vittoria
ids = sorted(w for w, e in ways.items() if e["tags"].get("name") in WHOLE) + sorted(PARTS)
for w, name in PARTS.items():
    if ways[w]["tags"].get("name") != name:
        raise SystemExit(f"Way {w} non è più {name}")
if 766566070 not in ways or ways[766566070]["nodes"][-1] not in {n for w in ways.values() if w["tags"].get("name") == "Via Marziale" for n in w["nodes"]}:
    raise SystemExit("Corso Italia non finisce più all'incrocio con via Marziale")
rel = {"id": 0, "members": [{"type": "way", "role": "section", "geometry": ways[w]["geometry"]} for w in ids]}
shape = osm_geo.perimeter(osm_geo.street_area(rel), tol_m=4)


def node_at(way_id, node_id):
    w = ways[way_id]
    p = w["geometry"][w["nodes"].index(node_id)]
    return p["lat"], p["lon"]


cam = next(e for e in GEO if e["type"] == "node" and e["id"] == 10907830588)
GATES = [(679052212, "Varco 1 · Via Fuorimura / Viale Caruso", *node_at(220483714, 679052212)),
         (10907830588, "Varco 2 · Corso Italia (Carmine) / Piazza Tasso", cam["lat"], cam["lon"]),
         (10006422062, "Varco 3 · Via Correale (parcheggio Lauro)", *node_at(1127707893, 10006422062)),
         (1622123958, "Varco 4 · Via San Francesco / Via De Maio", *node_at(443366374, 1622123958))]
gate_list = [osm_geo.gate_json("so", g) for g in GATES]
for g in gate_list:
    if osm_geo.distance_m(shape, g["location"]["lat"], g["location"]["lon"]) > 40 and not osm_geo.contains(shape, g["location"]["lat"], g["location"]["lon"]):
        raise SystemExit(f"Varco lontano dalla zona: {g['name']}")
# Controlli: piazza Tasso e piazza Sant'Antonino (municipio) dentro; stazione Circumvesuviana, Corso Italia pedonale (via
# San Cesareo) e parcheggio Lauro fuori
for name, lat, lon, inside in [("Piazza Tasso", 40.6263, 14.3759, True), ("Piazza Sant'Antonino", 40.62707, 14.37491, True),
                               ("Stazione", 40.62585, 14.37979, False), ("Corso Italia pedonale", 40.6253, 14.3723, False),
                               ("Parcheggio Achille Lauro", 40.62783, 14.37841, False)]:
    if osm_geo.contains(shape, lat, lon) != inside:
        raise SystemExit(f"Controllo perimetro fallito: {name} dovrebbe essere {'dentro' if inside else 'fuori'}")
area = osm_geo.area_km2(shape)
if not 0.02 < area < 0.1:
    raise SystemExit(f"Area della ZTL non plausibile: {area:.3f} km²")


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


LINKS = [link("City of Sorrento: ZTL Centro (periods and hours)", "Comune di Sorrento: Z.T.L. Centro (periodi e orari)", "Stadt Sorrent: ZTL Centro (Zeiträume und Zeiten)", ZTL_PAGE),
         link("City of Sorrento: ordinance no. 230 of 16/06/2023 (PDF)", "Comune di Sorrento: ordinanza n. 230 del 16/06/2023 (PDF)", "Stadt Sorrent: Verordnung Nr. 230 vom 16.06.2023 (PDF)", ORD_230),
         link("City of Sorrento: ZTL permits for hotels and accommodation", "Comune di Sorrento: permessi ZTL per strutture", "Stadt Sorrent: ZTL-Genehmigungen für Unterkünfte", HOTELS),
         link("City of Sorrento: temporary ZTL permit", "Comune di Sorrento: permesso ZTL temporaneo", "Stadt Sorrent: befristete ZTL-Genehmigung", TEMP),
         link("City of Sorrento: the ZTL returns (gates)", "Comune di Sorrento: ritorna la ZTL (varchi)", "Stadt Sorrent: die ZTL kehrt zurück (Kameras)", NEWS_2025),
         link("Metropolis: ZTL from 1 April to 25 October 2026", "Metropolis: ZTL dal 1° aprile al 25 ottobre 2026", "Metropolis: ZTL vom 1. April bis 25. Oktober 2026", PRESS_2026),
         link("OpenStreetMap: streets of the ordinance (ODbL)", "OpenStreetMap: strade dell'ordinanza (ODbL)", "OpenStreetMap: Straßen der Verordnung (ODbL)", osm_geo.osm_url("way", 220483714))]

PENDING = [
    ("Winter (7 December – 6 January) the ZTL works only on holidays and on the days before them: GateLR counts as such the Saturdays and 7, 24 and 31 December and 5 January (weekday hours 7:30 pm–4 am), and Sundays plus 8, 25, 26 December, 1 and 6 January (10 am–1 pm and 7:30 pm–4 am). This reading of «prefestivi» is ours.",
     "D'inverno (7 dicembre – 6 gennaio) la ZTL vale solo nei festivi e prefestivi: GateLR conta come prefestivi i sabati e il 7, 24 e 31 dicembre e il 5 gennaio (orario feriale 19:30–4), come festivi le domeniche e l'8, 25, 26 dicembre, 1 e 6 gennaio (10–13 e 19:30–4). Questa lettura di «prefestivi» è nostra.",
     "Im Winter (7. Dezember – 6. Januar) gilt die ZTL nur an Feiertagen und an deren Vortagen: GateLR zählt dazu die Samstage sowie 7., 24. und 31. Dezember und 5. Januar (Werktagszeiten 19:30–4 Uhr) und als Feiertage Sonntage sowie 8., 25., 26. Dezember, 1. und 6. Januar (10–13 und 19:30–4 Uhr). Diese Auslegung von «prefestivi» ist unsere."),
    ("Dates for 2026 (1 April – 25 October) are those of ordinance 230/2023 and the City's pages; the 2026 season is confirmed only by the press (Metropolis, ANSA, March 2026). No newer ordinance was found.",
     "Le date 2026 (1 aprile – 25 ottobre) sono quelle dell'ordinanza 230/2023 e delle pagine del Comune; la stagione 2026 è confermata solo dalla stampa (Metropolis, ANSA, marzo 2026). Nessuna ordinanza più recente trovata.",
     "Die Daten für 2026 (1. April – 25. Oktober) sind die der Verordnung 230/2023 und der Stadtseiten; die Saison 2026 bestätigt nur die Presse (Metropolis, ANSA, März 2026). Keine neuere Verordnung gefunden."),
    ("Hotels and other accommodation request a temporary transit permit for their guests on the City's «ZTL per strutture» portal (issued from immediately up to 30 days); the time limit for sending your plate is not stated: ask your hotel before you arrive. Others with a documented need can ask for a temporary permit online or by calling the free number 800 477 311 when passing the gate.",
     "Hotel e strutture ricettive chiedono un permesso di transito temporaneo per gli ospiti sul portale «ZTL per strutture» del Comune (rilascio da immediato a 30 giorni); il termine per comunicare la targa non è indicato: chiedi all'hotel prima di arrivare. Chi ha un'esigenza documentata può chiedere un permesso temporaneo online o chiamando il numero verde 800 477 311 al momento del passaggio.",
     "Hotels und Unterkünfte beantragen für ihre Gäste eine befristete Durchfahrtsgenehmigung im Portal «ZTL per strutture» der Stadt (Ausstellung sofort bis 30 Tage); eine Frist für die Kennzeichenmeldung ist nicht angegeben: frag dein Hotel vor der Anreise. Wer einen belegten Bedarf hat, kann online oder über die Gratisnummer 800 477 311 beim Passieren eine befristete Genehmigung erbitten."),
    ("Electric cars, motorbikes and Blue Badge holders: the permit regulation (council resolutions 7 and 28/2023) is a scanned PDF that could not be read here, so GateLR exempts nobody. Fine 83–332 € (Highway Code; confirmed only by tyremap.com). The permit portals (sorrento.domosweb.it) could not be reached from here.",
     "Auto elettriche, moto e contrassegno disabili: il regolamento dei permessi (delibere di Consiglio 7 e 28/2023) è un PDF scansionato non leggibile da qui, quindi GateLR non esenta nessuno. Multa 83–332 € (Codice della Strada; confermato solo da tyremap.com). I portali dei permessi (sorrento.domosweb.it) non erano raggiungibili da qui.",
     "Elektroautos, Motorräder und Behindertenausweis: Die Genehmigungsordnung (Ratsbeschlüsse 7 und 28/2023) ist ein gescanntes PDF, das hier nicht lesbar war, daher befreit GateLR niemanden. Bußgeld 83–332 € (Straßenverkehrsordnung; nur von tyremap.com bestätigt). Die Genehmigungsportale (sorrento.domosweb.it) waren von hier aus nicht erreichbar."),
    ("Area drawn from the OpenStreetMap streets listed in the ordinance (not an official map). The pedestrian Corso Italia west of piazza Tasso and the old-town lanes are outside this ZTL; the lower part of via Marina Grande (beach side, no gate) is left out.",
     "Area ricavata dalle strade OpenStreetMap elencate nell'ordinanza (non è una mappa ufficiale). Il Corso Italia pedonale a ovest di piazza Tasso e i vicoli del centro antico sono fuori da questa ZTL; il tratto basso di via Marina Grande (verso la spiaggia, senza varco) è escluso.",
     "Fläche aus den in der Verordnung genannten OpenStreetMap-Straßen (keine amtliche Karte). Der Fußgänger-Corso Italia westlich der Piazza Tasso und die Gassen der Altstadt liegen außerhalb dieser ZTL; der untere Teil der Via Marina Grande (Strandseite, ohne Kamera) ist ausgelassen."),
]

SUMMER = {"fromMonth": 4, "fromDay": 1, "toMonth": 10, "toDay": 25}
WINTER = {"fromMonth": 12, "fromDay": 7, "toMonth": 1, "toDay": 6}
NIGHT = {"start": 19 * 60 + 30, "end": 4 * 60}
EVES = [(12, 7), (12, 24), (12, 31), (1, 5)]   # prefestivi che non sono sabati: vigilie di 8/12, 25/12, 1/1, 6/1
windows = [{"weekdays": ALL, **NIGHT, "season": SUMMER},
           {"weekdays": SUN, "start": 10 * 60, "end": 13 * 60, "season": SUMMER},
           {"weekdays": SAT + SUN, **NIGHT, "season": WINTER},
           {"weekdays": SUN, "start": 10 * 60, "end": 13 * 60, "season": WINTER}]
windows += [{"weekdays": ALL, **NIGHT, "season": {"fromMonth": m, "fromDay": d, "toMonth": m, "toDay": d}} for m, d in EVES]

zone = {"id": "sorrento-centro", "name": "Piazza Tasso · ZTL Centro", "name_it": "Piazza Tasso · ZTL Centro", "name_de": "Piazza Tasso · ZTL Centro",
        "kind": "restricted",
        "summary": "From 1 April to 25 October the streets around piazza Tasso (viale Caruso, Corso Italia to via Marziale, via Correale from the Lauro car park, via De Maio, piazza Sant'Antonino, via San Francesco down to piazza della Vittoria) are closed to cars without a permit every evening 7:30 pm–4 am, and on holidays also 10 am–1 pm. From 7 December to 6 January only on holidays and the evenings before them. Staying in town? Your hotel asks the City for your permit. Park at the Lauro or Fuorimura car parks.",
        "summary_it": "Dal 1° aprile al 25 ottobre le strade intorno a piazza Tasso (viale Caruso, Corso Italia fino a via Marziale, via Correale dal parcheggio Lauro, via De Maio, piazza Sant'Antonino, via San Francesco fino a piazza della Vittoria) sono chiuse alle auto senza permesso ogni sera 19:30–4, e nei festivi anche 10–13. Dal 7 dicembre al 6 gennaio solo nei festivi e prefestivi. Dormi in centro? L'hotel chiede al Comune il permesso per te. Parcheggia al Lauro o al Fuorimura.",
        "summary_de": "Vom 1. April bis 25. Oktober sind die Straßen um die Piazza Tasso (Viale Caruso, Corso Italia bis Via Marziale, Via Correale ab Parkplatz Lauro, Via De Maio, Piazza Sant'Antonino, Via San Francesco bis Piazza della Vittoria) für Autos ohne Genehmigung jeden Abend 19:30–4 Uhr gesperrt, an Feiertagen auch 10–13 Uhr. Vom 7. Dezember bis 6. Januar nur an Feiertagen und deren Vortagen. Du übernachtest im Zentrum? Dein Hotel beantragt die Genehmigung bei der Stadt. Am Parkplatz Lauro oder Fuorimura parken.",
        "perimeter": shape, "gates": gate_list, "windows": windows,
        "freeOnHolidays": False, "holidaysAsSunday": True, "exemptFuels": [], "hotelCanRegister": True,
        "source": {"authority": "City of Sorrento", "pageURL": ZTL_PAGE,
                   "ordinance": "Ordinanza n. 230 del 16/06/2023 (sostituisce le n. 321/2021 e 139/2023); regolamento permessi D.C.C. n. 7 del 16/03/2023 e n. 28 del 26/05/2023",
                   "ordinanceURL": ORD_230, "quote": QUOTE + " Orari di vigenza della ZTL: " + QUOTE2,
                   "quoteTranslation": "ZTL periods: from 1 April to 25 October; from 7 December to 6 January (only on holidays and the days before holidays). ZTL hours: weekdays from 19:30 to 04:00; holidays from 10:00 to 13:00 and from 19:30 to 04:00.",
                   "quoteTranslation_de": "Geltungszeiträume der ZTL: vom 1. April bis 25. Oktober; vom 7. Dezember bis 6. Januar (nur an Feiertagen und deren Vortagen). Zeiten der ZTL: werktags 19:30 bis 04:00 Uhr; feiertags 10:00 bis 13:00 und 19:30 bis 04:00 Uhr.",
                   "checkedOn": CHECKED, "reviewedByHuman": False,
                   "pending": [p[0] for p in PENDING], "pending_it": [p[1] for p in PENDING], "pending_de": [p[2] for p in PENDING],
                   "links": LINKS}}

city = {"id": "sorrento", "name": "Sorrento", "name_it": "Sorrento", "name_de": "Sorrent",
        "center": {"lat": 40.6263, "lon": 14.3759}, "zones": [zone], "status": "draft",
        "license": "Rules: Comune di Sorrento (ordinance 230/2023 and official pages). Area and gates: " + osm_geo.ODBL + " (streets of the ordinance, approximate)."}

ready = all(len(z["perimeter"]) >= 5 and z["source"]["quote"] for z in city["zones"])
out = ROOT / ("Resources/Cities/sorrento.json" if ready else "data/drafts/sorrento.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/sorrento.json" if ready else "Resources/Cities/sorrento.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), [(z["id"], len(z["perimeter"]), len(z["gates"])) for z in city["zones"]], f"{area:.3f} km²")
