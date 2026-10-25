#!/usr/bin/env python3
# Costruisce Resources/Cities/verona.json dalle pagine ufficiali del Comune di Verona e della Polizia Locale
# salvate in data/raw/verona/ (fonti e date in docs/fonti-verona.md).
# Regola: la ZTL «Città Antica» non ha più fasce di libero accesso dal 28/10/2024 (Ordinanza n. 1486 del 21/10/2024):
# entrano solo le categorie autorizzate (residenti, moto e motorini, ospiti degli alberghi in ZTL registrati
# dall'albergatore, disabili con contrassegno registrato); chi vive a Verona o in provincia può prenotare fino a 4
# ingressi al mese in fasce precise. Per un turista quindi la ZTL è chiusa 24 ore su 24, tutti i giorni.
# Perimetro: il Comune non pubblica un perimetro in open data (il dataset «Mappa della ZTL con varchi» ha solo 11
# punti ed è CC BY-NC 4.0, quindi non lo usiamo nell'app). Si usano le tre way OSM «Zona a Traffico Limitato di
# Verona» (boundary=limited_traffic_zone, © OpenStreetMap contributors, ODbL 1.0), che sono tre anelli chiusi
# separati da strade aperte al traffico; ognuno diventa una zona con le stesse regole. Varchi: le 3 telecamere
# mappate in OSM, con il nome ufficiale del varco. Se arrivano dati ufficiali con licenza compatibile, basta
# salvarli come data/raw/verona/ztl_perimetro.geojson (Polygon/MultiPolygon WGS84) e varchi.geojson (Point con «name»).
# Non aggiorna manifest.json. Uso: python3 Tools/build_verona.py
import html, json, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/verona"
CHECKED = "2026-10-25T09:00:00Z"
EVERY_DAY = [1, 2, 3, 4, 5, 6, 7]

NEWS = "https://www.comune.verona.it/Novita/Notizie/La-Zona-a-Traffico-Limitato-di-Verona"
TOURISTS = "https://polizialocale.comune.verona.it/nqcontent.cfm?a_id=26104"
ZTL_PL = "https://polizialocale.comune.verona.it/nqcontent.cfm?a_id=25496"
DISABLED = "https://polizialocale.comune.verona.it/nqcontent.cfm?a_id=26103"
HOTELS = "https://www.comune.verona.it/Servizi/Citypass-richiesta-di-adesione-al-Protocollo-d-Intesa-per-strutture-ricettive-situate-in-ZTL"
EV = "https://www.comune.verona.it/content/view/full/7434"
CAMERAS_2026 = "https://www.comune.verona.it/content/view/full/23692"
FAQ = "https://polizialocale.comune.verona.it/nqcontent.cfm?a_id=30873"
ORD_1486 = "https://archive.comune.verona.it/media/_ComVR/Cdr2023/ComunicazioneURP/Allegati/Ordinanze/ord_01486_21-10-2024.pdf"
ORD_1545 = "https://archive.comune.verona.it/media/_ComVR/Cdr2023/ComunicazioneURP/Allegati/Ordinanze/ord_01545_31-10-2024.pdf"
OSM_WAYS = {"main": 1346972386, "south": 1346971350, "riva": 1346972708}
# Telecamere OSM (nodi «device» delle relazioni enforcement) → nome del varco nell'elenco ufficiale (pagina «Mappa e orari»)
OSM_GATES = {3067212934: ("main", "Varco 1 · Lungadige Rubele"), 3067070337: ("main", "Varco 2 · Via Leoni"),
             3067055044: ("south", "Varco 8 · Via Dogana")}


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


def flat(text):
    return re.sub(r"\s+", " ", text).strip()


def page_text(name):
    t = (RAW / name).read_text(encoding="utf-8", errors="replace")
    t = re.sub(r"<(script|style)[^>]*>.*?</\1>", " ", t, flags=re.S)
    return flat(html.unescape(re.sub(r"<[^>]+>", " ", t)))


def must_contain(text, quote, where):
    """Ogni frase citata o riassunta deve esserci davvero nel documento salvato"""
    if flat(quote) not in text:
        raise SystemExit(f"Citazione non trovata in {where}: {quote!r}")


tourists = page_text("pl-26104-accesso-turisti.html")
news = page_text("notizia-ztl-verona.html")
disabled = page_text("pl-26103-accesso-disabili.html")
faq = page_text("archivio-30873-faq.html")
ev = flat((RAW / "api/ztl-elettriche.txt").read_text(encoding="utf-8"))
hotels = flat((RAW / "api/citypass-protocollo-strutture.txt").read_text(encoding="utf-8"))
cams = flat((RAW / "api/telecamere-2026-09-18.txt").read_text(encoding="utf-8"))
ord1486 = flat((RAW / "ord_01486_21-10-2024.txt").read_text(encoding="utf-8"))
ord1545 = flat((RAW / "ord_01545_31-10-2024.txt").read_text(encoding="utf-8"))
QUOTE = ("Risulta perciò necessario che per entrare in Ztl vi sia un pernottamento presso un albergo sito entro "
         "l'area della ZTL, e non solo disporre genericamente della qualità di turista.")
for q in [QUOTE, "Sarà l'albergatore a comunicare anticipatamente alla Polizia Locale il numero di targa delle auto dei suoi ospiti"]:
    must_contain(tourists, q, "Polizia Locale, Accesso alla ZTL per turisti")
for q in ["Ordinanza n.1486 del 21 ottobre 2024", "max 4 ingressi al mese", "dalle 10 alle 18 (con uscita obbligatoria entro le ore 18)",
          "dalle 20 alle 23 (con uscita obbligatoria entro le ore 24)", "sabato, domenica e festivi:",
          "dalle 10 alle 13.30 (con uscita obbligatoria entro le ore 13.30)", "bici, ciclomotori e motoveicoli a due e tre ruote",
          "non locazioni turistiche", "veicoli degli invalidi muniti del contrassegno (city pass)",
          "Ansa interna dell'Adige compresa fra il Ponte Scaligero di Castelvecchio e Ponte Aleardi (Riva San Lorenzo inclusa)",
          "Ultimo aggiornamento: 24/10/2025"]:
    must_contain(news, q, "Comune, La Zona a Traffico Limitato di Verona")
must_contain(disabled, "entro 72 ore dall'accesso è possibile richiedere l'autorizzazione di un transito", "Polizia Locale, Accesso disabili")
must_contain(faq, "ammonta a euro 98,50", "FAQ ZTL (archivio)")
must_contain(faq, "euro 73,60 se pagati entro 5 giorni", "FAQ ZTL (archivio)")
for q in ["con esclusione di autovetture ibride", "accedendo esclusivamente tramite SPID/CIE", "Resta escluso l'accesso all'Area Pedonale Urbana (APU)"]:
    must_contain(ev, q, "servizio Veicoli elettrici in ZTL")
must_contain(hotels, "Pertanto le Locazioni Turistiche non rientrando tra le strutture ricettive classificate", "servizio Citypass strutture ricettive")
for q in ["piazza Bra: tutti i giorni, compresi i festivi, h24", "Ponte Aleardi: è vietato, dalle ore 7 alle 18 tutti i giorni, festivi compresi",
          "Per il varco ZTL di Santo Stefano è invece previsto un periodo di pre-esercizio di circa 30 giorni a partire dal 28 settembre, prima dell’avvio delle sanzioni che partono da lunedì 2 novembre"]:
    must_contain(cams, q, "notizia telecamere 18/09/2026")
# Ordinanze 1486 e 1545/2024 (PDF dell'archivio del Comune, letti il 25/10/2026)
for q in ["Ordinanza Dirigenziale n. 1486 del 21/10/2024", "ZTL – ELIMINAZIONE DELLE FASCE ORARIE DI LIBERO ACCESSO",
          "viene revocato il punto 4 dell’ordinanza del 14 aprile 2005 n. 35",
          "Autovetture a servizio dei clienti diretti ad Attività ricettive alberghiere e complementari situate in ZTL",
          "con possibilità di sola fermata nei limiti consentiti dal vigente Codice della Strada",
          "previa registrazione della targa entro le ventiquattro ore precedenti la data del transito",
          "con un limite di n. 4 (quattro) registrazioni nell’arco di un mese",
          "dalle ore 10.00 alle ore 18.00 (con uscita obbligatoria alle ore 18.00)",
          "dalle ore 20.00 alle ore 23.00 (con uscita obbligatoria alle ore 24.00)",
          "il sabato, la domenica e festivi:", "dalle ore 10.00 alle ore 13.30 (con uscita obbligatoria alle ore 13.30)"]:
    must_contain(ord1486, q, "ordinanza 1486/2024")
for q in ["Ordinanza Dirigenziale n. 1545 del 31/10/2024",
          "è consentito l’accesso e il transito libero in ZTL ai ciclomotori e motoveicoli a due e tre ruote",
          "titolari di attività ricettive ubicate in ZTL"]:
    must_contain(ord1545, q, "ordinanza 1545/2024")


def rings():
    """Gli anelli del perimetro: da un file ufficiale, se c'è; altrimenti le tre way OSM (mai disegnati a mano)"""
    f = RAW / "ztl_perimetro.geojson"
    if f.exists():
        g = json.loads(f.read_text())
        g = g["features"][0]["geometry"] if "features" in g else g
        polys = [g["coordinates"]] if g["type"] == "Polygon" else g["coordinates"]
        return {"main": osm_geo.perimeter([tuple(p) for p in max((p[0] for p in polys), key=len)], tol_m=3)}, False
    ways = {e["id"]: e for e in osm_geo.load("verona-ztl") if e["type"] == "way"}
    out = {}
    for key, wid in OSM_WAYS.items():
        w = ways.get(wid)
        if not w or w.get("tags", {}).get("boundary") != "limited_traffic_zone":
            raise SystemExit(f"Way OSM {wid} mancante o cambiata")
        pts = [(n["lon"], n["lat"]) for n in w["geometry"]]
        if pts[0] != pts[-1]:
            raise SystemExit(f"Way OSM {wid} non chiusa")
        out[key] = osm_geo.perimeter(pts, tol_m=3)
    return out, True


def gates():
    f = RAW / "varchi.geojson"
    if f.exists():
        return {"main": [{"id": f"vr-{i}", "name": v["properties"]["name"],
                          "location": {"lat": round(v["geometry"]["coordinates"][1], 6), "lon": round(v["geometry"]["coordinates"][0], 6)}}
                         for i, v in enumerate(json.loads(f.read_text())["features"], 1) if v.get("geometry")]}
    out = {}
    for g in osm_geo.gates(osm_geo.load("verona-gates"), name_prefix=None):
        if g[0] in OSM_GATES:
            zone, name = OSM_GATES[g[0]]
            out.setdefault(zone, []).append(osm_geo.gate_json("vr", (g[0], name, g[2], g[3])))
    if sum(map(len, out.values())) != len(OSM_GATES):
        raise SystemExit(f"Varchi OSM attesi {len(OSM_GATES)}, trovati {out}")
    return out


shapes, from_osm = rings()
gate_map = gates()

links = [link("City of Verona: the ZTL (hours, who may enter, map)", "Comune di Verona: la ZTL (orari, accessi, mappa)",
              "Stadt Verona: die ZTL (Zeiten, Zufahrt, Karte)", NEWS),
         link("Verona Local Police: ZTL access for tourists", "Polizia Locale di Verona: accesso alla ZTL per turisti",
              "Stadtpolizei Verona: ZTL-Zufahrt für Touristen", TOURISTS),
         link("Verona Local Police: disabled badge holders", "Polizia Locale di Verona: accesso disabili",
              "Stadtpolizei Verona: Inhaber eines Behindertenausweises", DISABLED),
         link("City of Verona: hotels inside the ZTL (Citypass)", "Comune di Verona: strutture ricettive in ZTL (Citypass)",
              "Stadt Verona: Hotels in der ZTL (Citypass)", HOTELS),
         link("City of Verona: full-electric cars in the ZTL", "Comune di Verona: auto elettriche in ZTL",
              "Stadt Verona: reine Elektroautos in der ZTL", EV),
         link("City of Verona: ordinance 1486/2024, end of free-entry hours (PDF)", "Comune di Verona: ordinanza 1486/2024, fine delle fasce di libero accesso (PDF)",
              "Stadt Verona: Verordnung 1486/2024, Ende der freien Einfahrtszeiten (PDF)", ORD_1486),
         link("City of Verona: ordinance 1545/2024, mopeds and motorbikes free, new permits (PDF)", "Comune di Verona: ordinanza 1545/2024, moto e ciclomotori liberi, nuovi permessi (PDF)",
              "Stadt Verona: Verordnung 1545/2024, Mopeds und Motorräder frei, neue Genehmigungen (PDF)", ORD_1545),
         link("City of Verona: new cameras from 21 September 2026", "Comune di Verona: nuove telecamere dal 21 settembre 2026",
              "Stadt Verona: neue Kameras ab 21. September 2026", CAMERAS_2026)]
if from_osm:
    for key, wid in OSM_WAYS.items():
        links.append(link(f"OpenStreetMap: way {wid} (ZTL outline, ODbL)", f"OpenStreetMap: way {wid} (perimetro ZTL, ODbL)",
                          f"OpenStreetMap: Weg {wid} (ZTL-Grenze, ODbL)", osm_geo.osm_url("way", wid)))

P_OSM = ("Perimeter from OpenStreetMap (three outlines tagged as Verona's ZTL), to be checked against the official map. Corso Cavour and the street from Ponte Navi towards Largo Divisione Pasubio lie between the outlines and are treated as outside the ZTL.",
         "Perimetro da OpenStreetMap (tre contorni segnati come ZTL di Verona), da verificare con la mappa ufficiale. Corso Cavour e la strada da ponte Navi verso largo Divisione Pasubio stanno tra i contorni e sono considerate fuori dalla ZTL.",
         "Grenze aus OpenStreetMap (drei als ZTL Verona erfasste Umrisse), mit der offiziellen Karte abzugleichen. Corso Cavour und die Straße von Ponte Navi Richtung Largo Divisione Pasubio liegen zwischen den Umrissen und gelten als außerhalb der ZTL.")
P_GATES = ("Only 3 of the 11 official gates (Lungadige Rubele, Via Leoni, Via Malenza, Ponte Garibaldi, Lungadige Panvinio, Riva San Lorenzo, Via Cantore, Via Dogana, Via Fratta, Via Nizza, Piazzetta Municipio) have a position on the map: the city's gate coordinates are licensed for non-commercial use only.",
           "Solo 3 degli 11 varchi ufficiali (lungadige Rubele, via Leoni, via Malenza, ponte Garibaldi, lungadige Panvinio, riva San Lorenzo, via Cantore, via Dogana, via Fratta, via Nizza, piazzetta Municipio) hanno una posizione sulla mappa: le coordinate del Comune hanno una licenza solo non commerciale.",
           "Nur 3 der 11 offiziellen Kameras (Lungadige Rubele, Via Leoni, Via Malenza, Ponte Garibaldi, Lungadige Panvinio, Riva San Lorenzo, Via Cantore, Via Dogana, Via Fratta, Via Nizza, Piazzetta Municipio) haben eine Position auf der Karte: die Koordinaten der Stadt sind nur für nicht-kommerzielle Nutzung freigegeben.")
P_ORD = ("Ordinance no. 1486 of 21/10/2024 ended the free-entry hours of 2005. Hotel guests' cars heading to accommodation inside the ZTL may pass freely but may only stop, not park (art. 29 u). "
         "The ordinance takes effect once the signs are installed (in force since 28/10/2024, city page).",
         "L'Ordinanza n. 1486 del 21/10/2024 ha eliminato le fasce di libero accesso del 2005. Le auto dei clienti diretti a strutture ricettive in ZTL transitano liberamente ma con «possibilità di sola fermata», non di sosta (art. 29 u). "
         "L'ordinanza vale dall'installazione dei cartelli (in vigore dal 28/10/2024, pagina del Comune).",
         "Die Verordnung Nr. 1486 vom 21.10.2024 hat die freien Einfahrtszeiten von 2005 abgeschafft. Autos von Gästen, die zu Unterkünften in der ZTL fahren, dürfen frei durchfahren, aber nur halten, nicht parken (Art. 29 u). "
         "Die Verordnung gilt ab Aufstellung der Schilder (seit 28.10.2024 in Kraft, Seite der Stadt).")
P_MORE = [
    ("Residents of Verona and its province can book up to 4 entries a month, at least 24 hours ahead (Mon–Fri 10–18 and 20–23, weekends and holidays 10–13:30; ordinance 1486/2024). This is not open to other visitors.",
     "Chi vive a Verona o in provincia può prenotare fino a 4 ingressi al mese, entro le 24 ore precedenti (lun–ven 10–18 e 20–23, sabato, domenica e festivi 10–13:30; ordinanza 1486/2024). Non vale per gli altri visitatori.",
     "Wer in Verona oder der Provinz wohnt, kann bis zu 4 Einfahrten im Monat buchen, spätestens 24 Stunden vorher (Mo–Fr 10–18 und 20–23 Uhr, Wochenende und Feiertage 10–13:30; Verordnung 1486/2024). Für andere Besucher gilt das nicht."),
    ("Hotel guests: only hotels and other classified accommodation inside the ZTL can register your plate, in advance; holiday rentals (locazioni turistiche) cannot. No deadline after entry was found.",
     "Ospiti degli alberghi: solo gli alberghi e le altre strutture ricettive classificate dentro la ZTL possono registrare la targa, in anticipo; le locazioni turistiche no. Non è stato trovato un termine dopo l'ingresso.",
     "Hotelgäste: nur Hotels und andere klassifizierte Unterkünfte in der ZTL können dein Kennzeichen vorab melden; Ferienwohnungen (locazioni turistiche) nicht. Eine Frist nach der Einfahrt wurde nicht gefunden."),
    ("Full-electric cars (not hybrids) may enter after registering online for 12 months, but the portal requires an Italian SPID or CIE digital identity.",
     "Le auto solo elettriche (non le ibride) possono entrare dopo la registrazione online, valida 12 mesi, ma il portale richiede SPID o CIE.",
     "Reine Elektroautos (keine Hybride) dürfen nach Online-Registrierung für 12 Monate einfahren, das Portal verlangt aber eine italienische SPID- oder CIE-Identität."),
    ("Disabled badge holders: the plate must be registered; for an occasional entry, within 72 hours on accessiztl.comune.verona.it.",
     "Contrassegno disabili: la targa va registrata; per un transito occasionale, entro 72 ore su accessiztl.comune.verona.it.",
     "Behindertenausweis: das Kennzeichen muss gemeldet werden; bei einer einmaligen Einfahrt innerhalb von 72 Stunden auf accessiztl.comune.verona.it."),
    ("New ZTL Santo Stefano (Veronetta, across the river): fines from Monday 2 November 2026 (city). Hours every day 9–12:30, 14–17:30 and 20–7, confirmed only by local newspapers (Verona Tomorrow, L'Arena): the ordinance that creates it is not among the city's published documents (searched 25/10/2026). Not on the map yet.",
     "Nuova ZTL Santo Stefano (Veronetta, oltre l'Adige): sanzioni da lunedì 2 novembre 2026 (Comune). Orari tutti i giorni 9–12:30, 14–17:30 e 20–7, confermati solo da giornali locali (Verona Tomorrow, L'Arena): l'ordinanza istitutiva non è tra i documenti pubblicati dal Comune (cercata il 25/10/2026). Non è ancora sulla mappa.",
     "Neue ZTL Santo Stefano (Veronetta, jenseits der Etsch): Bußgelder ab Montag, 2. November 2026 (Stadt). Zeiten täglich 9–12:30, 14–17:30 und 20–7 Uhr, nur von Lokalzeitungen bestätigt (Verona Tomorrow, L'Arena): die einrichtende Verordnung ist nicht unter den veröffentlichten Dokumenten der Stadt (gesucht am 25.10.2026). Noch nicht auf der Karte."),
    ("Cameras since 21/09/2026: Piazza Bra is closed to cars 24 hours a day, holidays included; the reserved lane on Ponte Aleardi is closed 7–18 every day. Not on the map yet.",
     "Telecamere dal 21/09/2026: piazza Bra è chiusa alle auto 24 ore su 24, festivi compresi; la corsia riservata di ponte Aleardi è vietata dalle 7 alle 18 tutti i giorni. Non sono ancora sulla mappa.",
     "Kameras seit 21.09.2026: die Piazza Bra ist rund um die Uhr, auch an Feiertagen, für Autos gesperrt; die reservierte Spur auf dem Ponte Aleardi täglich 7–18 Uhr. Noch nicht auf der Karte."),
    ("Fine: €98.50, or €73.60 if paid within 5 days, according to an older Local Police FAQ page (archive, based on the old €82 minimum); the city's current «Pay a fine» page gives no amount, and the current amount may be higher.",
     "Multa: 98,50 €, oppure 73,60 € se pagata entro 5 giorni, secondo una vecchia pagina FAQ della Polizia Locale (archivio, sul vecchio minimo di 82 €); la pagina attuale «Pagare una sanzione» del Comune non indica importi, e l'importo attuale può essere più alto.",
     "Bußgeld: 98,50 €, oder 73,60 € bei Zahlung innerhalb von 5 Tagen, laut einer älteren FAQ-Seite der Stadtpolizei (Archiv, auf Basis des alten Mindestbetrags von 82 €); die aktuelle Seite «Pagare una sanzione» der Stadt nennt keinen Betrag, der aktuelle Betrag kann höher sein."),
    ("Not modelled: the pedestrian area of Piazza Erbe (closed even with most permits), the stadium ZTL on match days, and the winter anti-smog bans (1 Oct–30 Apr) for older vehicles across the whole city.",
     "Non inclusi: l'area pedonale di piazza Erbe (chiusa anche con quasi tutti i permessi), la ZTL dello stadio nei giorni delle partite e i divieti antismog invernali (1 ottobre–30 aprile) per i veicoli più vecchi in tutta la città.",
     "Nicht enthalten: die Fußgängerzone Piazza Erbe (auch mit den meisten Genehmigungen gesperrt), die Stadion-ZTL an Spieltagen und die winterlichen Smog-Fahrverbote (1. Okt.–30. Apr.) für ältere Fahrzeuge im ganzen Stadtgebiet."),
]


def source(pending):
    return {"authority": "City of Verona", "pageURL": TOURISTS,
            "ordinance": "Ordinanza dirigenziale n. 1486 del 21/10/2024 (ZTL, fine delle fasce di libero accesso) e n. 1545 del 31/10/2024; Ordinanza dirigenziale n. 1365/2014 (disciplina ZTL)",
            "ordinanceURL": ORD_1486, "quote": QUOTE,
            "quoteTranslation": "It is therefore necessary, in order to enter the ZTL, to stay overnight at a hotel located inside the ZTL area; simply being a tourist is not enough.",
            "quoteTranslation_de": "Um in die ZTL einzufahren, ist daher eine Übernachtung in einem Hotel innerhalb der ZTL nötig; nur Tourist zu sein, genügt nicht.",
            "checkedOn": CHECKED, "reviewedByHuman": False,
            "pending": [p[0] for p in pending], "pending_it": [p[1] for p in pending], "pending_de": [p[2] for p in pending],
            "links": links}


SUMMARY = ("Closed to unauthorised cars 24 hours a day, every day, holidays included: since 28 October 2024 there are no free-entry hours. "
           "There is no day pass for visitors. If your hotel is inside the ZTL, it must register your plate before you drive in; holiday rentals can't. "
           "Motorbikes and scooters may enter.")
SUMMARY_IT = ("Chiusa alle auto non autorizzate 24 ore su 24, tutti i giorni, festivi compresi: dal 28 ottobre 2024 non ci sono più fasce di libero accesso. "
              "Non esiste un permesso giornaliero per i visitatori. Se il tuo albergo è dentro la ZTL, deve registrare la targa prima che tu entri; le locazioni turistiche no. "
              "Moto e scooter possono entrare.")
SUMMARY_DE = ("Rund um die Uhr, täglich und auch an Feiertagen für nicht berechtigte Autos gesperrt: seit dem 28. Oktober 2024 gibt es keine freien Einfahrtszeiten mehr. "
              "Ein Tagesticket für Besucher gibt es nicht. Liegt dein Hotel in der ZTL, muss es dein Kennzeichen vor der Einfahrt melden; Ferienwohnungen können das nicht. "
              "Motorräder und Roller dürfen einfahren.")

NAMES = {"main": ("Città Antica · Historic Centre ZTL", "Città Antica · ZTL Centro storico", "Città Antica · ZTL Altstadt"),
         "south": ("Città Antica · ZTL by Ponte Aleardi", "Città Antica · ZTL verso ponte Aleardi", "Città Antica · ZTL beim Ponte Aleardi"),
         "riva": ("Riva San Lorenzo · ZTL by Castelvecchio", "Riva San Lorenzo · ZTL presso Castelvecchio", "Riva San Lorenzo · ZTL bei Castelvecchio")}
IDS = {"main": "verona-ztl", "south": "verona-ztl-aleardi", "riva": "verona-ztl-riva-san-lorenzo"}

zones = []
for key, shape in shapes.items():
    pending = ([P_OSM] if from_osm else []) + [P_GATES, P_ORD] + (P_MORE if key == "main" else [])
    en, it, de = NAMES[key]
    zones.append({"id": IDS[key], "name": en, "name_it": it, "name_de": de, "kind": "restricted",
                  "summary": SUMMARY, "summary_it": SUMMARY_IT, "summary_de": SUMMARY_DE,
                  "perimeter": shape, "gates": sorted(gate_map.get(key, []), key=lambda g: g["name"]),
                  "windows": [{"weekdays": EVERY_DAY, "start": 0, "end": 24 * 60}],
                  "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": True,
                  "source": source(pending)})

city = {"id": "verona", "name": "Verona", "name_it": "Verona", "name_de": "Verona",
        "center": {"lat": 45.4390, "lon": 10.9944}, "zones": zones, "status": "draft",
        "license": "Rules: Comune di Verona and Polizia Locale di Verona official pages. "
                   + ("Perimeter and gates: " + osm_geo.ODBL + " (approximate, not official)." if from_osm else "Perimeter and gates: Comune di Verona.")}

# Controlli di plausibilità: punti noti dentro e fuori
main = shapes["main"]
for name, lat, lon in [("Arena", 45.4390, 10.9944), ("Piazza Erbe", 45.4430, 10.9976), ("Casa di Giulietta", 45.4419, 10.9988),
                       ("Duomo", 45.4470, 10.9971)]:
    if not osm_geo.contains(main, lat, lon):
        raise SystemExit(f"{name} dovrebbe essere dentro la ZTL")
for name, lat, lon in [("Stazione Porta Nuova", 45.4290, 10.9825), ("San Zeno", 45.4425, 10.9795), ("Castelvecchio", 45.4400, 10.9875),
                       ("Santo Stefano (Veronetta)", 45.4485, 11.0010), ("Castel San Pietro", 45.4485, 11.0030)]:
    if any(osm_geo.contains(z["perimeter"], lat, lon) for z in zones):
        raise SystemExit(f"{name} dovrebbe essere fuori dalla ZTL")

ready = all(len(z["perimeter"]) >= 4 for z in zones)
out = ROOT / ("Resources/Cities/verona.json" if ready else "data/drafts/verona.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("Resources/Cities/verona.json" if not ready else "data/drafts/verona.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.name, [(z["id"], len(z["perimeter"]), len(z["gates"]), round(osm_geo.area_km2(z["perimeter"]), 3)) for z in zones])
