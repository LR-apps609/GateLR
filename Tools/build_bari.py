#!/usr/bin/env python3
# Costruisce Resources/Cities/bari.json dagli atti e dalle pagine ufficiali salvati in data/raw/bari/
# (fonti e date in docs/fonti-bari.md).
#
# Zona: ZTL della Città Vecchia (Bari Vecchia), ordinanza dirigenziale 2023/00181 del 18/01/2023 (delibera GC 886/2022),
# con le modifiche della delibera di giunta di novembre 2025 (ganci aboliti) e il varco del Castello acceso dal 1° luglio 2026.
# Nel Murattiano e nella Madonnella non risultano ZTL: via Sparano e via Argiro sono aree pedonali, non modellate.
#
# Il Comune non pubblica dati aperti sulla ZTL (opendata.comune.bari.it: nessun dataset «ztl» o «pedonal»).
# Perimetro e varchi da OpenStreetMap (data/raw/geo/bari-ztl.json, © OpenStreetMap contributors, ODbL 1.0):
# relazione 21044253 «ZTL della Città Vecchia» (boundary=limited_traffic_zone), il cui contorno sono le strade del
# perimetro ufficiale (corso Vittorio Emanuele II, piazza Massari, corso De Tullio, lungomare Imperatore Augusto),
# e i nodi «Varco ZTL Numero 1…7», abbinati per numero ai varchi V1…V7 dell'ordinanza.
# Se arriva un perimetro ufficiale, basta salvarlo come data/raw/bari/ztl_perimetro.geojson (Polygon in WGS84).
# Non aggiorna manifest.json. Uso: python3 Tools/build_bari.py
import json, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/bari"
CHECKED = "2026-10-26T02:00:00Z"
EVERY_DAY = [1, 2, 3, 4, 5, 6, 7]
OSM_ZTL = 21044253

PL_PAGE = "https://www.poliziamunicipalebari.it/home-page/cosa-fare-in-caso-di/rilascio-permessi-ztl/"
ORD_PDF = "https://s93719c543e6e84f7.jimcontent.com/download/version/1423133575/module/11109032222/name/O.D.%20-%20ZTL.pdf"
AMTAB_RULES = "https://www.amtab.it/it/zona-a-traffico-limitato/regolamento-ztl"
AMTAB_PERMITS = "https://www.amtab.it/it/zona-a-traffico-limitato/rilascio-permessi"
NEWS_2025 = "https://www.baritoday.it/cronaca/zrl-bari-vecchia-nuove-regole-parcheggi-transito-strade.html"
NEWS_2026 = "https://www.telebari.it/attualita/255902-ztl-attivo-dal-1-luglio-il-varco-del-castello-scaramuzzi-soluzione-presa-con-residenti-e-commercianti.html"
NEWS_HOTELS = "https://www.lagazzettadelmezzogiorno.it/news/bari/2115194/ztl-a-bari-vecchia-i-turisti-multati-nel-centro-storico-gli-albergatori-scrivono-al-comune-serve-piu-elasticita.amp"


def flat(text):
    return re.sub(r"\s+", " ", text).strip()


TEXT = {p.stem: flat(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def check(file, *quotes):
    """Ogni frase citata o riassunta deve esserci davvero nel documento salvato"""
    for q in quotes:
        if flat(q) not in TEXT[file]:
            raise SystemExit(f"{file}: frase non trovata, ricontrollare il documento: {q!r}")


QUOTE = ("Sulle “STRADE AZZURRE” il transito è consentito tutti i giorni dalle ore 0,00 alle ore 24,00 : "
         "- ai veicoli al servizio di persone con capacità di deambulazione sensibilmente ridotta dotati dell’apposito tagliando per disabili; "
         "- ai veicoli dei residenti, domiciliati o dimoranti nella Città Vecchia, dotati di apposito permesso.")
check("polizia-locale-rilascio-permessi-ztl", QUOTE,
      "Con l' Ordinanza N. 2023/00181 (2023/185/00102) del 18/01/2023",
      "previa comunicazione telefonica al numero verde 800 060 780 della Sala Operativa della Polizia Municipale , indicando il varco dal quale si intende accedere, il numero di targa del veicolo e il numero del contrassegno disabili in possesso",
      "C.so Vittorio Emanuele - P.zza Massari - P.zza Isabella d’Aragona - Corso Senatore Antonio De Tullio - Lungomare Imperatore Augusto - P.zza IV Novembre")
check("ordinanza_2023_00181",
      "10.1.2. ai veicoli dei residenti, domiciliati o dimoranti nella Città Vecchia, dotati di apposito permesso.",
      "29.1. l’accesso è condizionato dalla detenzione dell’autorizzazione all’accesso alla ZTL.",   # elettriche e ibride
      "17.1. nei giorni lavorativi dalle ore 9,00 alle 11,00 e dalle ore 16,00 alle ore 18,00:",       # carico e scarico
      "applicare le sanzioni amministrative previste dall’art. 7, comma 14 primo periodo del Codice della Strada",
      "potranno essere rilasciati permessi provvisori con validità giornaliera. Il costo del contrassegno è fissato in € 3,00/giorno.",
      "16.1. il transito è consentito ai velocipedi, ciclomotori e motocicli;")
check("amtab-rilascio-permessi", "Il costo per il rilascio ed il rinnovo annuale del contrassegno è di € 10,00.")
check("baritoday-2025-11-25-delibera",
      "vengono, inoltre, abrogati i cosiddetti ‘ganci’, ossia i percorsi individuati all’interno del perimetro della Ztl, in cui era precedentemente consentito il transito a tutti i veicoli in alcune fasce orarie.")
check("telebari-2026-06-11",
      "Diventa operativo il varco situato in piazza Federico II di Svevia, all’angolo con piazza Massari.",
      "L’ingresso dal varco di Santa Chiara, infatti, resterà sempre disponibile per tutti per consentire alle auto di ‘circumnavigare’ piazzale Mincuzzi.")
check("baritoday-2026-07-01", "E stato attivato il varco n zona Castello (piazza Federico II di Svevia ad angolo con piazza Massari).")
check("gazzetta-2026-09-02-albergatori",
      "l’attuale regolamento della Ztl non contempla una specifica deroga per le attività alberghiere",
      "Per gli utenti non titolari di pass è inoltre previsto un ingresso temporaneo a pagamento, da richiedere e ottenere prima del transito.")

# Varchi dell'ordinanza (punto 18.3) → numero del nodo OSM «Varco ZTL Numero n»
GATES = {1: "V1 · Strada Porto Nuovo / Corso De Tullio",
         2: "V2 · Via Ruggiero il Normanno / Corso De Tullio",
         3: "V3 · Piazza Federico II di Svevia / Piazza Massari (Castle)",
         4: "V4 · Via Benedetto Petrone / Corso Vittorio Emanuele II",
         5: "V5 · Strada San Benedetto / Corso Vittorio Emanuele II",
         6: "V6 · Via Michele Genovese / Lungomare Imperatore Augusto",
         7: "V7 · Arco Largo Urbano II / Lungomare Imperatore Augusto"}
check("ordinanza_2023_00181", "V1 – Strada Porto Nuovo, all’intersezione con Corso Antonio De Tullio;",
      "V2 – Via Ruggiero il Normanno, all’intersezione con Corso Antonio De Tullio;",
      "V3 – Piazza Federico II di Svevia, all’intersezione con Piazza Giuseppe Massari;",
      "V4 – Via Benedetto Petrone, all’intersezione con Corso Vittorio Emanuele II;",
      "V5 – Strada San Benedetto, all’intersezione con Corso Vittorio Emanuele II;",
      "V6 – Via Michele Genovese, all’intersezione con lungomare Imperatore Augusto;",
      "V7 – Arco Largo Urbano II, all’intersezione con lungomare Imperatore Augusto.")


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


def perimeter():
    f = RAW / "ztl_perimetro.geojson"
    if f.exists():
        g = json.loads(f.read_text())
        g = g["features"][0]["geometry"] if "features" in g else g
        polys = [g["coordinates"]] if g["type"] == "Polygon" else g["coordinates"]
        return [{"lat": round(p[1], 6), "lon": round(p[0], 6)} for p in max((p[0] for p in polys), key=len)], False
    # i membri della relazione non hanno ruolo («»): sono le strade del perimetro, unite testa-coda
    rel = osm_geo.relation(osm_geo.load("bari-ztl"), OSM_ZTL)
    return osm_geo.perimeter(osm_geo.outer_ring(rel, roles=("", "outer")), tol_m=4), True


def gates():
    out = []
    for e in osm_geo.load("bari-ztl"):
        m = re.fullmatch(r"Varco ZTL Numero (\d)", e.get("tags", {}).get("name", "")) if e["type"] == "node" else None
        if m:
            out.append({"id": f"ba-osm{e['id']}", "name": GATES[int(m.group(1))],
                        "location": {"lat": round(e["lat"], 6), "lon": round(e["lon"], 6)}})
    if len(out) != 7:
        raise SystemExit(f"Attesi 7 varchi OSM, trovati {len(out)}")
    return sorted(out, key=lambda g: g["name"])


shape, from_osm = perimeter()
ring = [(p["lon"], p["lat"]) for p in shape]
# Controlli: la Basilica di San Nicola e la Cattedrale dentro; la stazione Centrale e via Sparano (Murattiano) fuori
for name, lat, lon, inside in [("Basilica di San Nicola", 41.1305, 16.8701, True), ("Cattedrale di San Sabino", 41.1284, 16.8697, True),
                               ("Stazione Bari Centrale", 41.1179, 16.8697, False), ("Via Sparano", 41.1222, 16.8700, False),
                               ("Teatro Petruzzelli", 41.1236, 16.8735, False)]:
    if osm_geo.contains(ring, lat, lon) != inside:
        raise SystemExit(f"Controllo perimetro fallito: {name} dovrebbe essere {'dentro' if inside else 'fuori'}")
area = osm_geo.area_km2(ring)
if not 0.2 < area < 0.6:
    raise SystemExit(f"Area della ZTL non plausibile: {area:.2f} km²")
gate_list = gates()
for g in gate_list:
    if osm_geo.distance_m(ring, g["location"]["lat"], g["location"]["lon"]) > 40:
        raise SystemExit(f"Varco lontano dal bordo: {g['name']}")

links = [link("Bari Local Police: the old town ZTL rules, permits and temporary access",
              "Polizia Locale di Bari: regole della ZTL della Città Vecchia, permessi e accessi temporanei",
              "Lokalpolizei Bari: Regeln der ZTL der Altstadt, Genehmigungen und befristete Zufahrt", PL_PAGE),
         link("City of Bari: ZTL ordinance 2023/00181 with the rules (PDF)", "Comune di Bari: ordinanza ZTL 2023/00181 con il disciplinare (PDF)",
              "Stadt Bari: ZTL-Verordnung 2023/00181 mit den Regeln (PDF)", ORD_PDF),
         link("AMTAB (city mobility company): ZTL rules", "AMTAB: regolamento ZTL", "AMTAB (städtische Mobilitätsgesellschaft): ZTL-Regeln", AMTAB_RULES),
         link("AMTAB: permits for residents", "AMTAB: rilascio permessi per i residenti", "AMTAB: Genehmigungen für Anwohner", AMTAB_PERMITS),
         link("BariToday (25 Nov 2025): the city abolishes the free-access routes", "BariToday (25/11/2025): il Comune abolisce i «ganci»",
              "BariToday (25.11.2025): Die Stadt schafft die freien Durchfahrten ab", NEWS_2025),
         link("Telebari (11 Jun 2026): Castle gate on from 1 July 2026", "Telebari (11/06/2026): varco del Castello attivo dal 1° luglio 2026",
              "Telebari (11.06.2026): Kamera am Kastell ab 1. Juli 2026 aktiv", NEWS_2026),
         link("Gazzetta del Mezzogiorno (2 Sep 2026): no hotel exemption", "Gazzetta del Mezzogiorno (02/09/2026): nessuna deroga per gli alberghi",
              "Gazzetta del Mezzogiorno (02.09.2026): keine Ausnahme für Hotels", NEWS_HOTELS)]
if from_osm:
    links.append(link(f"OpenStreetMap: relation {OSM_ZTL} «ZTL della Città Vecchia» (ODbL)",
                      f"OpenStreetMap: relazione {OSM_ZTL} «ZTL della Città Vecchia» (ODbL)",
                      f"OpenStreetMap: Relation {OSM_ZTL} «ZTL della Città Vecchia» (ODbL)", osm_geo.osm_url("relation", OSM_ZTL)))

pending = []
if from_osm:
    pending.append(("Perimeter and camera positions from OpenStreetMap, to be checked against the official map. The outline runs along the boundary roads (corso Vittorio Emanuele II, corso De Tullio, the seafront), which are outside the ZTL.",
                    "Perimetro e posizione dei varchi da OpenStreetMap, da verificare con la planimetria ufficiale. Il contorno passa sulle strade di confine (corso Vittorio Emanuele II, corso De Tullio, lungomare), che sono fuori dalla ZTL.",
                    "Grenze und Kamerapositionen aus OpenStreetMap, mit der offiziellen Karte abzugleichen. Die Linie folgt den Grenzstraßen (Corso Vittorio Emanuele II, Corso De Tullio, Uferstraße), die außerhalb der ZTL liegen."))
pending += [
    ("The 2023 ordinance still let all cars use two short routes by the Castle on working days 6 am–9 pm. The city abolished them (council decision, November 2025) and switched on the Castle camera on 1 July 2026: confirmed only by the local press quoting the city (BariToday, Telebari); the new decision itself was not found, and AMTAB's page still describes the old routes.",
     "L'ordinanza del 2023 consentiva ancora a tutti i veicoli due «ganci» vicino al Castello nei giorni lavorativi 6–21. Il Comune li ha aboliti (delibera di giunta, novembre 2025) e ha acceso il varco del Castello il 1° luglio 2026: confermato solo da stampa locale che riporta il Comune (BariToday, Telebari); il testo della nuova delibera non è stato trovato e la pagina AMTAB descrive ancora i ganci.",
     "Die Verordnung von 2023 erlaubte allen Autos noch zwei kurze Strecken am Kastell an Werktagen 6–21 Uhr. Die Stadt hat sie abgeschafft (Ratsbeschluss November 2025) und die Kamera am Kastell am 1. Juli 2026 eingeschaltet: nur von der Lokalpresse mit Zitaten der Stadt bestätigt (BariToday, Telebari); der neue Beschluss selbst wurde nicht gefunden, die AMTAB-Seite beschreibt noch die alten Strecken."),
    ("Piazzale Mincuzzi by the Castle: the city says the Santa Chiara entrance stays open to everyone to drive round the square (paid bays on its outer edge, working days 8:30 am–8:30 pm). GateLR shows the whole old town as closed. Confirmed only by Telebari (11 June 2026).",
     "Piazzale Mincuzzi, vicino al Castello: secondo il Comune l'ingresso dal varco di Santa Chiara resta aperto a tutti per girare attorno al piazzale (strisce blu sul perimetro esterno, giorni lavorativi 8:30–20:30). GateLR mostra chiusa tutta la città vecchia. Confermato solo da Telebari (11/06/2026).",
     "Piazzale Mincuzzi am Kastell: Laut Stadt bleibt die Zufahrt Santa Chiara für alle offen, um den Platz zu umfahren (gebührenpflichtige Plätze am Außenrand, Werktage 8:30–20:30 Uhr). GateLR zeigt die ganze Altstadt als gesperrt. Nur von Telebari (11.06.2026) bestätigt."),
    ("Temporary entry for visitors: the 2022 rules allow one-day permits only in 'particular and justifiable circumstances' (€3 a day); the city told hotels (Gazzetta del Mezzogiorno, 2 Sep 2026) that a paid temporary entry must be requested and granted before driving in. How to apply and today's price are not published: ask the Polizia Locale.",
     "Accesso temporaneo per chi non ha il permesso: il disciplinare 2022 prevede permessi giornalieri solo per «circostanze particolari e giustificabili» (3 € al giorno); il Comune ha risposto agli albergatori (Gazzetta del Mezzogiorno, 02/09/2026) che l'ingresso temporaneo a pagamento va chiesto e ottenuto prima del transito. Modalità e prezzo attuale non sono pubblicati: chiedere alla Polizia Locale.",
     "Befristete Zufahrt für Besucher: Die Regeln von 2022 erlauben Tagesgenehmigungen nur in 'besonderen, begründeten Fällen' (3 € pro Tag); die Stadt sagte den Hotels (Gazzetta del Mezzogiorno, 2.9.2026), dass eine kostenpflichtige Zufahrt vor der Einfahrt beantragt und genehmigt sein muss. Antragsweg und aktueller Preis sind nicht veröffentlicht: bei der Polizia Locale fragen."),
    ("Motorbikes and mopeds may use the old town's 'green streets'; the ordinance doesn't say clearly whether they need a permit at the cameras. GateLR answers as for cars.",
     "Moto e ciclomotori possono percorrere le «strade verdi» della città vecchia; l'ordinanza non dice chiaramente se ai varchi serve il permesso. GateLR risponde come per le auto.",
     "Motorräder und Mopeds dürfen die 'grünen Straßen' der Altstadt befahren; die Verordnung sagt nicht klar, ob sie an den Kameras eine Genehmigung brauchen. GateLR antwortet wie für Autos."),
    ("Fine: the ordinance applies article 7(14) of the Highway Code (nationally about €83–332 plus costs); Bari's sources don't state the amount.",
     "Multa: l'ordinanza applica l'art. 7, comma 14 del Codice della Strada (a livello nazionale circa 83–332 € più spese); le fonti del Comune non indicano l'importo.",
     "Bußgeld: Die Verordnung wendet Art. 7 Abs. 14 der Straßenverkehrsordnung an (landesweit etwa 83–332 € plus Kosten); die Quellen der Stadt nennen den Betrag nicht."),
    ("Not shown: extra closures in the old town for the feast of St Nicholas (7–9 May and 6 December, set by yearly ordinances), and the pedestrian streets of the Murattiano (via Sparano, via Argiro), closed to cars. No ZTL was found in the Murattiano or the Madonnella.",
     "Non mostrati: le chiusure in più nella città vecchia per la festa di San Nicola (7–9 maggio e 6 dicembre, decise ogni anno con ordinanza) e le strade pedonali del Murattiano (via Sparano, via Argiro), chiuse alle auto. Nel Murattiano e nella Madonnella non risultano ZTL.",
     "Nicht gezeigt: zusätzliche Sperrungen in der Altstadt zum Fest des hl. Nikolaus (7.–9. Mai und 6. Dezember, jährlich per Verordnung) und die Fußgängerstraßen des Murattiano (Via Sparano, Via Argiro), für Autos gesperrt. Im Murattiano und in der Madonnella wurde keine ZTL gefunden."),
]

SUMMARY = ("Closed to cars without a permit 24 hours a day, every day, holidays included; seven cameras watch the entrances. Permits are only for old-town residents and a few trades, and electric and hybrid cars need one too. There is no tourist pass and hotels inside can't register your plate: park outside (blue bays on the seafront and corso De Tullio) and walk in. Blue Badge holders: call the Polizia Locale on 800 060 780 before entering, giving the gate, plate and badge number.")
SUMMARY_IT = ("Chiusa alle auto senza permesso 24 ore su 24, tutti i giorni, festivi compresi; sette varchi con telecamera. Il permesso è solo per i residenti della città vecchia e poche categorie, e serve anche alle auto elettriche e ibride. Non c'è un pass per turisti e gli hotel dentro non possono registrare la targa: parcheggia fuori (strisce blu sul lungomare e su corso De Tullio) e entra a piedi. Con il contrassegno disabili: chiama la Polizia Locale al numero verde 800 060 780 prima di entrare, indicando varco, targa e numero del contrassegno.")
SUMMARY_DE = ("Rund um die Uhr, täglich und auch an Feiertagen für Autos ohne Genehmigung gesperrt; sieben Kameras überwachen die Zufahrten. Genehmigungen gibt es nur für Anwohner der Altstadt und wenige Gruppen, auch Elektro- und Hybridautos brauchen eine. Es gibt keinen Touristenpass, und Hotels innen können dein Kennzeichen nicht melden: draußen parken (blaue Plätze an der Uferstraße und am Corso De Tullio) und zu Fuß hinein. Mit Behindertenausweis: vor der Einfahrt die Polizia Locale unter 800 060 780 anrufen und Zufahrt, Kennzeichen und Ausweisnummer angeben.")

zone = {"id": "bari-vecchia", "name": "Bari Vecchia · Old Town ZTL", "name_it": "Bari Vecchia · ZTL Città Vecchia",
        "name_de": "Bari Vecchia · ZTL Altstadt", "kind": "restricted",
        "summary": SUMMARY, "summary_it": SUMMARY_IT, "summary_de": SUMMARY_DE,
        "perimeter": shape, "gates": gate_list,
        "windows": [{"weekdays": EVERY_DAY, "start": 0, "end": 24 * 60}],
        "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": False,
        "source": {"authority": "City of Bari", "pageURL": PL_PAGE,
                   "ordinance": "Ordinanza dirigenziale n. 2023/00181 (2023/185/00102) del 18/01/2023 (delibera GC n. 886 del 29/11/2022)",
                   "ordinanceURL": ORD_PDF, "quote": QUOTE,
                   "quoteTranslation": "On the 'blue streets' driving is allowed every day from 0:00 to 24:00 only to vehicles serving people with seriously reduced mobility that show the disabled badge, and to vehicles of residents of the Old Town with a permit.",
                   "quoteTranslation_de": "Auf den 'blauen Straßen' ist die Durchfahrt täglich von 0 bis 24 Uhr nur Fahrzeugen von Menschen mit stark eingeschränkter Gehfähigkeit mit Behindertenausweis und Fahrzeugen von Anwohnern der Altstadt mit Genehmigung erlaubt.",
                   "checkedOn": CHECKED, "reviewedByHuman": False,
                   "pending": [p[0] for p in pending], "pending_it": [p[1] for p in pending], "pending_de": [p[2] for p in pending],
                   "links": links}}

city = {"id": "bari", "name": "Bari", "name_it": "Bari", "name_de": "Bari",
        "center": {"lat": 41.1285, "lon": 16.8695}, "zones": [zone], "status": "draft",
        "license": "Rules: Comune di Bari (ordinance 2023/00181), Polizia Locale di Bari and AMTAB. "
                   + ("Perimeter and gates: " + osm_geo.ODBL + " (approximate, not official)." if from_osm else "Perimeter and gates: Comune di Bari.")}

ready = all(len(z["perimeter"]) >= 4 for z in city["zones"])
out = ROOT / ("Resources/Cities/bari.json" if ready else "data/drafts/bari.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/bari.json" if ready else "Resources/Cities/bari.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.name, [(z["id"], len(z["perimeter"]), len(z["gates"])) for z in city["zones"]], f"{area:.2f} km²")
