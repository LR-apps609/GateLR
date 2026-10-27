#!/usr/bin/env python3
# Costruisce la scheda di Sirmione dalle pagine e dagli atti ufficiali salvati in data/raw/sirmione/ (URL e data di lettura
# in testa a ogni file; fonti e date in docs/fonti-sirmione.md).
#
# Regole (27/10/2026): ordinanza n. 30 del 06/03/2026 della Polizia Locale (ZTL del centro storico dalle Grotte di Catullo a
# largo Goethe/viale Marconi, divieto di circolazione per tutti i veicoli non autorizzati, senza limiti di orario), allegato C
# (orari per categoria: periodo estivo 2026 dal 23/03 al 13/10, «soggiornanti» con due accessi al giorno, 31 giornate di
# pedonalizzazione 14–19), pagina «Regolamentazione della ZTL» (unico varco «K53700/SA», permessi, multe 83–333 €), FAQ del
# Welcome Point (targhe degli ospiti inserite dalle strutture ricettive nel portale), notizia «Stagione turistica 2026».
#
# Geometria (mai disegnata a mano): nessun open data; si usa la relazione OSM 19456915 «ZTL Sirmione»
# (boundary=limited_traffic_zone, operator Polizia Locale di Sirmione, source Comune di Sirmione, check_date 2025-08-13): il
# contorno della penisola chiuso al fossato del castello, scaricato con l'API OSM il 27/10/2026
# (data/raw/geo/sirmione-centro.json, © OpenStreetMap contributors, ODbL 1.0). Controllo: ogni via dell'ordinanza presente
# in OSM sta dentro il perimetro (almeno l'80% dei punti: restano fuori il ponte del castello e un pontile); Grotte di Catullo, Santa Maria Maggiore dentro, piazzale Porto e Grifo Parking fuori.
# Varco: la sbarra OSM (barrier=lift_gate, nodo 10041235164) su largo Goethe a pochi metri da via Marconi, cioè il punto
# d'ingresso indicato dall'ordinanza; sta circa 50 m a sud del bordo disegnato (il fossato).
# Uso: python3 Tools/build_sirmione.py   (non tocca le altre città né manifest.json)
import json, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/sirmione"
CHECKED = "2026-10-27T12:00:00Z"
EVERY_DAY = [1, 2, 3, 4, 5, 6, 7]
OSM_ZTL, OSM_GATE = 19456915, 10041235164


def flat(s):
    return re.sub(r"\s+", " ", s).strip()


TEXT = {p.stem: flat(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def url_of(file):
    return TEXT[file].split(" ", 2)[1]


def check(file, *phrases):
    """Ogni frase citata o riassunta deve comparire, parola per parola, nel testo salvato"""
    for q in phrases:
        if flat(q) not in TEXT[file]:
            raise SystemExit(f"{file}: frase non trovata, ricontrollare il testo: {q!r}")


PAGE_F, ORD_F, ALLC_F, FAQ_F, NEWS_F, FLY_F = ("comune-regolamentazione-ztl", "ord-30-2026", "ord-30-2026-allegato-c",
                                               "faq-ztl-welcome-point", "comune-news-stagione-turistica-2026",
                                               "volantino-pedonalizzazione-2026")
PAGE, ORDINANCE, ANNEX_C, FAQ, NEWS = map(url_of, (PAGE_F, ORD_F, ALLC_F, FAQ_F, NEWS_F))
FORM = "https://municipium-images-production.s3-eu-west-1.amazonaws.com/s3/6918/allegati/ztl/mod-05-permesso-giornaliero-e-temporaneo.pdf"

QUOTE = ("È istituito il divieto, nella Z.T.L. come sopra definita, di circolazione dinamica e statica per tutte le categorie "
         "di veicoli non compresi e/o autorizzati ai sensi del predetto Disciplinare di Gestione della Z.T.L.")
STREETS = ["Via Catullo", "Via Arici", "V.le Gennari", "Via S. Pietro in Mavino", "Via Faustina", "Via Punta Staffalo", "P.zza Piatti",
           "Via Piana", "Via Vittorio Emanuele", "V.le Re Desiderio", "Via Porto Bianchi", "V.lo Carpentini", "Piazza Porto Valentino",
           "Piazza San Salvatore", "Via Antiche Mura", "Via Ansa dei Longobardi", "Piazza Flaminia", "Via S. Maria Maggiore",
           "Vicolo Romagnoli", "Via Casello", "Piazza Carducci", "Piazza Castello", "Piazzetta Mosaici", "Via Campane", "Via Dante",
           "Via Bocchio", "V.lo Bisse", "passaggio Broli"]
check(ORD_F, QUOTE, "ORDINANZA N. 30 DEL 06/03/2026",
      "nell’area compresa tra le Grotte di Catullo, a nord, e l’intersezione di L.go Goethe con viale Marconi (altezza civico 5/7), a sud",
      *[s + "," for s in STREETS],
      "servizio di gestione delle aree di sosta finalizzate ad ospitare i veicoli dei clienti delle strutture ricettive del centro storico",
      "È ammessa una tolleranza massima sugli orari di ingresso previsti nella presente ordinanza di 10 (dieci) minuti.",
      "il sistema automatizzato è entrato definitivamente in funzione il giorno 17 febbraio 2020")
check(PAGE_F, "La Z.T.L. di Sirmione ha un unico punto di ingresso dotato di impianto per la rilevazione elettronica degli accessi",
      "Per accedere alla ZTL è necessario che il veicolo sia preventivamente autorizzato e che i dati della targa siano inseriti nel sistema di controllo.",
      "I permessi giornalieri e/o temporanei sono rilasciati entro gg. 7 dal ricevimento dell’apposito modulo",
      "sanzione amministrativa del pagamento di una somma da Euro 83,00 ad Euro 333,00 ai sensi dell’art. 7, comma 14 del Codice della Strada",
      "Dal 23 marzo al 13 ottobre 2026 verrà applicata la regolamentazione estiva della ZTL", "Ultimo aggiornamento : 26 marzo 2026")
check(ALLC_F, "SOGGIORNANTI", "due accessi", "2 accessi/giorno", "PERIODO ESTIVO 2026: DAL 23 MARZO AL 13 OTTOBRE COMPRESI",
      "DIVIETO DI ACCESSO E CIRCOLAZIONE NELLA ZTL PER TUTTE LE CATEGORIE DI UTENTI DALLE 14:00 ALLE",
      "eccetto veicoli Grifoparking, mezzi di soccorso, veicoli residenti in uscita per emergenze",
      "TAXI E NCC - INGRESSO CONSENTITO SOLO PER TRASORTO RESIDENTI, DIMORANTI E SOGGIORNANTI")
check(FAQ_F, "Le targhe autorizzate verranno riconosciute dal sistema di lettura che alzerà automaticamente la barriera.",
      "la quale potrà verificare l’errore ed inserire la targa corretta tramite il portale già attualmente utilizzato.")
check(NEWS_F, "31 giornate di pedonalizzazione", "Durante queste fasce orarie il transito è vietato a tutte le categorie, anche in uscita",
      "servizi di trasporto con golf car elettriche per ospiti e bagagli")


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


LINKS = [link("City of Sirmione: ZTL rules, permits and fines", "Comune di Sirmione: regolamentazione della ZTL, permessi e multe",
              "Gemeinde Sirmione: ZTL-Regeln, Genehmigungen und Bußgelder", PAGE),
         link("Ordinance 30/2026 (ZTL area and ban)", "Ordinanza 30/2026 (area e divieto della ZTL)", "Verordnung 30/2026 (ZTL-Gebiet und Verbot)", ORDINANCE),
         link("Annex C: hours by category, summer period and pedestrian days 2026", "Allegato C: orari per categoria, periodo estivo e giornate di pedonalizzazione 2026",
              "Anlage C: Zeiten je Kategorie, Sommerzeitraum und Fußgängertage 2026", ANNEX_C),
         link("FAQ: Welcome Point barrier and plates registered by hotels", "FAQ: barriera del Welcome Point e targhe inserite dalle strutture",
              "FAQ: Schranke am Welcome Point und von Hotels gemeldete Kennzeichen", FAQ),
         link("Tourist season 2026: what changes", "Stagione turistica 2026: cosa cambia", "Tourismussaison 2026: was sich ändert", NEWS),
         link("Form for daily or temporary permits (PDF)", "Modulo per permessi giornalieri o temporanei (PDF)", "Formular für Tages- oder Kurzzeitgenehmigungen (PDF)", FORM)]

PENDING = [
    ("Hotel guests («soggiornanti»): the hotel enters your plate in the City's portal before you arrive, and the barrier opens by itself. You get two entries a day. Annex C limits the hours: in the off-season (from 14 October) weekdays 0–24 and holidays 0–9 and 19–24; in summer (23 March–13 October 2026) weekdays 0–24, days before holidays 0–10, 12–14, 19–21, 22:30–24, holidays 0–10, 19–21, 22:30–24. GateLR does not model these windows: check with the hotel.",
     "Ospiti delle strutture («soggiornanti»): la struttura inserisce la targa nel portale del Comune prima dell'arrivo e la barriera si alza da sola. Due accessi al giorno. L'allegato C limita gli orari: fuori stagione (dal 14 ottobre) feriali 0–24, festivi 0–9 e 19–24; in estate (23 marzo–13 ottobre 2026) feriali 0–24, prefestivi 0–10, 12–14, 19–21, 22:30–24, festivi 0–10, 19–21, 22:30–24. GateLR non modella queste fasce: chiedi all'hotel.",
     "Hotelgäste («soggiornanti»): Das Hotel trägt dein Kennzeichen vor der Ankunft im Portal der Gemeinde ein, die Schranke öffnet sich dann von selbst. Zwei Einfahrten pro Tag. Anlage C begrenzt die Zeiten: außerhalb der Saison (ab 14. Oktober) werktags 0–24, feiertags 0–9 und 19–24; im Sommer (23. März–13. Oktober 2026) werktags 0–24, vor Feiertagen 0–10, 12–14, 19–21, 22:30–24, feiertags 0–10, 19–21, 22:30–24. GateLR bildet diese Zeiten nicht ab: frag das Hotel."),
    ("On the 31 pedestrian days of 2026 (April to September, 14:00–19:00) nobody may drive in or out, hotel guests included; only the Grifo Parking shuttle, emergency vehicles and residents leaving for emergencies. Hotels without their own parking send guests' cars to the Grifo Parking outside the centre (the City's car park service for hotel guests).",
     "Nelle 31 giornate di pedonalizzazione 2026 (da aprile a settembre, 14–19) nessuno può entrare né uscire in auto, ospiti degli hotel compresi; solo i veicoli Grifoparking, i soccorsi e i residenti in uscita per emergenze. Le strutture senza parcheggio mandano le auto degli ospiti al Grifo Parking fuori dal centro (servizio comunale di sosta per i clienti delle strutture ricettive).",
     "An den 31 Fußgängertagen 2026 (April bis September, 14–19 Uhr) darf niemand ein- oder ausfahren, auch Hotelgäste nicht; nur Grifoparking-Fahrzeuge, Rettungsdienste und Anwohner in Notfällen. Hotels ohne eigene Parkplätze schicken die Autos der Gäste zum Grifo Parking außerhalb des Zentrums (städtischer Parkdienst für Hotelgäste)."),
    ("No ticket for visitors. A daily or temporary permit (e.g. guests of private homes: one access to unload luggage) is requested with the City's form at least 7 days before; it lasts at most 3 days. Fines 83–333 € (Highway Code art. 7 c. 14).",
     "Nessun ticket per i visitatori. Il permesso giornaliero o temporaneo (es. ospiti presso privati: un solo accesso per scaricare i bagagli) si chiede con il modulo del Comune almeno 7 giorni prima e dura al massimo 3 giorni. Multe da 83 a 333 € (art. 7 c. 14 del Codice della strada).",
     "Kein Ticket für Besucher. Eine Tages- oder Kurzzeitgenehmigung (z. B. Gäste in Privatunterkünften: eine Einfahrt zum Ausladen) wird mit dem Formular der Gemeinde mindestens 7 Tage vorher beantragt und gilt höchstens 3 Tage. Bußgelder 83–333 € (Art. 7 Abs. 14 StVO)."),
    ("Perimeter: OpenStreetMap area «ZTL Sirmione» (the peninsula north of the castle moat), not an official map. The single camera gate is the barrier on Largo Goethe by Via Marconi, about 50 m before the castle bridge; Piazzale Porto is outside the ZTL but a «Welcome Point» barrier further south may stop unregistered cars.",
     "Perimetro: area OpenStreetMap «ZTL Sirmione» (la penisola a nord del fossato del castello), non una mappa ufficiale. L'unico varco è la sbarra su largo Goethe all'altezza di via Marconi, circa 50 m prima del ponte del castello; piazzale Porto è fuori dalla ZTL, ma il «Welcome Point» più a sud può fermare le auto non registrate.",
     "Grenze: OpenStreetMap-Fläche «ZTL Sirmione» (die Halbinsel nördlich des Burggrabens), keine offizielle Karte. Die einzige Kamera ist die Schranke am Largo Goethe bei der Via Marconi, etwa 50 m vor der Burgbrücke; der Piazzale Porto liegt außerhalb der ZTL, doch der «Welcome Point» weiter südlich kann nicht registrierte Autos stoppen."),
    ("The management rules (Annex A of ordinance 30/2026) are not published on the City's site; the deadline for hotels to register plates and the off-season dates for 2026–27 are therefore not confirmed. Electric cars are not exempt (only listed service vehicles with a special permit).",
     "Il disciplinare di gestione (allegato A dell'ordinanza 30/2026) non è pubblicato sul sito del Comune: non sono confermati il termine per la registrazione delle targhe da parte degli hotel né le date invernali 2026–27. Auto elettriche non esenti (solo veicoli di servizio elencati con permesso in deroga).",
     "Die Verwaltungsregeln (Anlage A der Verordnung 30/2026) sind auf der Website der Gemeinde nicht veröffentlicht; die Frist für die Kennzeichenmeldung durch Hotels und die Wintertermine 2026–27 sind daher nicht bestätigt. Elektroautos sind nicht befreit (nur aufgeführte Dienstfahrzeuge mit Sondergenehmigung)."),
]

GEO = osm_geo.load("sirmione-centro")
WAYS = [e for e in GEO if e["type"] == "way" and "highway" in e.get("tags", {})]
# Le vie dell'ordinanza con il nome OSM (le altre non sono in OSM con un nome riconoscibile)
OSM_STREETS = ["Via Catullo", "Via Cesare Arici", "Viale Gennari", "Via Punta Staffalo", "Piazza Don Angelo Piatti", "Via Vittorio Emanuele",
               "Viale Re Desiderio", "Via Porto Bianchi", "Vicolo Carpentini", "Piazza Porto Valentino", "Via San Salvatore", "Via Antiche Mura",
               "Viale Anna dei Longobardi", "Via Santa Maria Maggiore", "Via Romagnoli", "Via Casello", "Piazza Giosuè Carducci", "Via Dante",
               "Via Gateano Bocchio", "Vicolo Bisse", "Passaggio Broli"]


def perimeter():
    rel = osm_geo.relation(GEO, OSM_ZTL)
    t = rel["tags"]
    if t.get("boundary") != "limited_traffic_zone" or t.get("name") != "ZTL Sirmione":
        raise SystemExit("La relazione OSM della ZTL è cambiata: ricontrollare")
    ring = osm_geo.outer_ring(rel)
    for name in OSM_STREETS:
        pts = [p for w in WAYS if w["tags"].get("name") == name for p in w["geometry"]]
        assert pts, f"via {name} non trovata in OSM"
        out = [p for p in pts if not osm_geo.inside_lonlat(ring, p["lon"], p["lat"]) and osm_geo.distance_m(ring, p["lat"], p["lon"]) > 10]
        if len(out) > 0.2 * len(pts):   # fuori solo il ponte del castello (via V. Emanuele) e il pontile di legno di piazza Carducci
            raise SystemExit(f"via dell'ordinanza {name} fuori dal perimetro OSM")
    return osm_geo.perimeter(ring, tol_m=4)


shape = perimeter()
node = next(e for e in GEO if e["type"] == "node" and e["id"] == OSM_GATE)
assert node.get("tags", {}).get("barrier") == "lift_gate"
assert any(OSM_GATE in w["nodes"] and w["tags"].get("name") == "Largo Goethe" for w in WAYS), "la sbarra non è più su largo Goethe"
gates = [{"id": "sirmione-largo-goethe", "name": "Varco · Largo Goethe / Via Marconi (castle)",
          "location": {"lat": round(node["lat"], 6), "lon": round(node["lon"], 6)}}]

zone = {"id": "sirmione-ztl", "name": "Sirmione · Old town ZTL", "name_it": "Sirmione · ZTL centro storico", "name_de": "Sirmione · ZTL Altstadt",
        "kind": "restricted",
        "summary": "The old town beyond the Scaliger Castle, up to the Grottoes of Catullus, is closed to all unauthorised vehicles at any hour, all year. The only entrance is the camera-controlled barrier at Largo Goethe by the castle. There is no ticket for visitors: park outside. If your hotel is inside, it registers your plate (two entries a day, with set hours).",
        "summary_it": "Il centro storico oltre il Castello Scaligero, fino alle Grotte di Catullo, è chiuso a tutti i veicoli non autorizzati a ogni ora, tutto l'anno. L'unico ingresso è la sbarra con telecamera di largo Goethe, davanti al castello. Non c'è un ticket per i visitatori: parcheggia fuori. Se l'hotel è dentro, registra la tua targa (due accessi al giorno, con orari fissati).",
        "summary_de": "Die Altstadt hinter der Skaligerburg bis zu den Grotten des Catull ist für alle nicht berechtigten Fahrzeuge jederzeit und das ganze Jahr gesperrt. Einzige Zufahrt ist die kameraüberwachte Schranke am Largo Goethe vor der Burg. Ein Ticket für Besucher gibt es nicht: außerhalb parken. Liegt dein Hotel innen, meldet es dein Kennzeichen (zwei Einfahrten pro Tag, zu festen Zeiten).",
        "perimeter": shape, "gates": gates,
        "windows": [{"weekdays": EVERY_DAY, "start": 0, "end": 24 * 60}],
        "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": True,
        "source": {"authority": "City of Sirmione", "pageURL": PAGE,
                   "ordinance": "Ordinanza n. 30 del 06/03/2026 (Polizia Locale), allegato C",
                   "ordinanceURL": ORDINANCE,
                   "quote": QUOTE,
                   "quoteTranslation": "In the ZTL defined above, driving and parking are prohibited for all categories of vehicles not included in and/or authorised under the said ZTL Management Rules.",
                   "quoteTranslation_de": "In der oben bestimmten ZTL ist das Fahren und Parken für alle Fahrzeugkategorien verboten, die nicht nach der genannten ZTL-Verwaltungsregelung erfasst und/oder zugelassen sind.",
                   "checkedOn": CHECKED, "reviewedByHuman": False,
                   "pending": [p[0] for p in PENDING], "pending_it": [p[1] for p in PENDING], "pending_de": [p[2] for p in PENDING],
                   "links": LINKS}}

city = {"id": "sirmione", "name": "Sirmione", "name_it": "Sirmione", "name_de": "Sirmione",
        "center": {"lat": 45.4935, "lon": 10.6075}, "zones": [zone], "status": "draft",
        "license": "Rules: Comune di Sirmione official pages and ordinance 30/2026. Perimeter and gate: " + osm_geo.ODBL + " (approximate, not official)."}

# Controlli di plausibilità (coordinate dai contorni OSM): Grotte di Catullo e Santa Maria Maggiore dentro;
# piazzale Porto, Grifo Parking e piazzale Europa fuori; il varco a meno di 60 m dal bordo
for n, lat, lon in [("Grotte di Catullo", 45.5017, 10.60648), ("Santa Maria Maggiore", 45.4933, 10.60823)]:
    assert osm_geo.contains(shape, lat, lon), f"{n} fuori dal perimetro"
for n, lat, lon in [("Piazzale Porto", 45.49147, 10.60795), ("Grifo Parking", 45.48889, 10.6103), ("Piazzale Europa", 45.48906, 10.60865)]:
    assert not osm_geo.contains(shape, lat, lon), f"{n} dentro il perimetro"
assert osm_geo.distance_m(shape, node["lat"], node["lon"]) < 60
assert 0.3 < osm_geo.area_km2(shape) < 0.5, osm_geo.area_km2(shape)

ready = all(len(z["perimeter"]) >= 5 and z["source"]["quote"] for z in city["zones"])
out = ROOT / ("Resources/Cities/sirmione.json" if ready else "data/drafts/sirmione.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/sirmione.json" if ready else "Resources/Cities/sirmione.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), [(z["id"], len(z["perimeter"]), len(z["gates"])) for z in city["zones"]], f"area {osm_geo.area_km2(shape):.2f} km²")
