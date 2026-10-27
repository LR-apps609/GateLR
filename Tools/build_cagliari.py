#!/usr/bin/env python3
# Costruisce la scheda di Cagliari (bozza) da quanto salvato in data/raw/cagliari/ (fonti e date in docs/fonti-cagliari.md).
#
# Regole ufficiali lette: Regolamento comunale per le ZTL (D.C.C. 42/2012, modificato con D.C.C. 27/2013 e 168 del 02/12/2025;
# testo vigente pubblicato sul portale il 29/12/2025) e pagine dell'Ufficio ZTL (pass, strutture ricettive, dimoranti).
# Il regolamento elenca le ZTL (Marina, Castello, Stampace Alto, Stampace Basso, Villanova, Poetto) ma rimanda gli ORARI
# (art. 31) e la PERIMETRAZIONE (art. 1 c. 2) a delibere di Giunta, non trovate. La pagina ufficiale con gli orari
# (old.comune.cagliari.it) non risponde (502 dal proxy, server irraggiungibile); il Geoportale (geoportale.comune.cagliari.it,
# ArcGIS Hub, ora raggiungibile) ha una pagina e un'app «Zone a traffico limitato» non scaricabili (openData false), i cui dati
# stanno su *.arcgis.com, bloccato dal proxy (403).
# Ricerca del 27/10/2026 nell'albo pretorio (archivio da agosto 2016, tutte le delibere di Giunta 2016–2026, 2.900 titoli):
# nessuna delibera di Giunta su orari o perimetri delle ZTL, né prima né dopo la D.C.C. 168 del 02/12/2025
# (elenco dal 02/12/2025 in data/raw/cagliari/albo-delibere-giunta-dal-02-12-2025.txt); solo aree pedonali stagionali.
# Gli orari qui sotto sono quindi solo da fonti non ufficiali (data/raw/cagliari/websearch-1-orari.txt).
#
# Geometria: OpenStreetMap (© OpenStreetMap contributors, ODbL 1.0; API OSM, data/raw/geo/cagliari-ztl.json): relazioni
# 14402165 «ZTL Castello» e 14402156 «ZTL Marina» e le telecamere «ZTL» del Comune (relazioni enforcement); per Stampace
# Alto, Stampace Basso e Villanova OSM non ha un'area.
#
# Resta in data/drafts/cagliari.json: manca una citazione ufficiale degli orari e manca il perimetro di tre zone.
# Per pubblicarla servono la delibera di Giunta sugli orari (e quella sulla perimetrazione dopo la D.C.C. 168/2025).
# Uso: python3 Tools/build_cagliari.py   (non tocca le altre città né manifest.json)
import json, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/cagliari"
CHECKED = "2026-10-27T12:30:00Z"
ALL, MON_FRI, SAT = [1, 2, 3, 4, 5, 6, 7], [2, 3, 4, 5, 6], [7]

P = "https://www.comune.cagliari.it/portale/page/it"
OFFICE = P + "/ztl_e_zone_pedonali?contentId=ORG9497"
PASSES = P + "/rilascio_pass_zone_a_traffico_limitato_ztl__persone_fisiche_it_1?contentId=SRV10350"
HOTELS = P + "/pass_ztl_per_strutture_ricettive?contentId=SRV10363"
RULES = "https://www.comune.cagliari.it/portale/protected/247459/0/def/ref/DOC77600I/"
UNOFFICIAL = "https://www.sicurauto.it/news/attualita-e-curiosita/ztl-cagliari-orari-mappa-e-pass/"


def flat(s):
    return re.sub(r"\s+", " ", s).strip()


TEXT = {p.stem: flat(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def check(file, *phrases):
    for q in phrases:
        if flat(q) not in TEXT[file]:
            raise SystemExit(f"{file}: frase non trovata: {q!r}")


QUOTE = ("Le strutture ricettive alberghiere ed extralberghiere di cui alla L.R. 14 maggio 1984, n.22 e alla L.R. 12 agosto "
         "1998, n. 27 e loro ss. mm. e ii., allo scopo di agevolare le operazioni di scarico dei bagagli dei clienti nei giorni "
         "di arrivo e di partenza, possono trasmettere per via telematica all'ufficio ZTL del Servizio Viabilità e Mobilità e al "
         "Servizio di Polizia Municipale le targhe dei veicoli dei clienti interessati, per consentirne il riconoscimento ai "
         "varchi di accesso. La sosta non può superare i sessanta minuti")
check("regolamento-ztl-2025", QUOTE,
      "deliberazione del Consiglio Comunale n.168 del 2 dicembre 2025",
      "a) Marina b) Castello c) Stampace Alto d) Stampace Basso e) Villanova f) Poetto",
      "L’esatta perimetrazione delle sopra elencate Zone a Traffico Limitato è definita con Deliberazione delle Giunta Comunale",
      "Le competenze per la determinazione degli orari di limitazione sono attribuite alla Giunta Municipale che vi provvede con apposito atto.",
      "L'accesso e la sosta alle ZTL sono consentiti ai ciclomotori, ai velocipedi, ai veicoli di micromobilità elettrica",
      "I possessori di veicoli a trazione elettrica possono ottenere il pass di solo transito senza limitazione oraria",
      "L’accesso nelle fasce orarie non interessate dalla ZTL resta libero per tutte le categorie di veicoli,",
      "L’ingresso, la sosta e l’uscita nelle fasce orarie in cui entra in vigore la ZTL sono controllati da apparecchiature elettroniche",
      "Ogni struttura ricettiva può rilasciare contemporaneamente un numero di pass non superiore al 10% del numero delle stanze dell'esercizio.",
      "validazione permanente dei veicoli nel sistema di controllo, in lista bianca, senza emissione di pass.")
check("comune-pass-strutture-ricettive", "Pass riservato alle strutture ricettive presenti nelle Ztl del centro storico per agevolare le operazioni di carico e scarico dei bagagli dei loro clienti.")
check("comune-rilascio-pass-ztl", "Nel Comune di Cagliari sono presenti sei diverse zone a traffico limitato: Poetto, Castello, Marina, Stampace basso, Stampace alto e Villanova.",
      "Consulta mappa e orari delle zone a traffico limitato nel Sistema informativo territoriale del Comune")
check("comune-pass-dimoranti", "L'autorizzazione consente di transitare e sostare h 24 nelle zone a traffico limitato Castello, Marina, Stampace alto, Stampace basso e Villanova.",
      "Il costo del pass è di 5,00 euro")
check("albo-delibere-giunta-dal-02-12-2025", "Istituzione Aree pedonali nella via Cavour nel tratto compreso tra la Via Sant'Eulalia e la via Lepanto")
check("geoportale-ztl-metadati", "Il tematismo riporta la localizzazione delle zone a traffico limitato e degli accessi pedonali", "openData: False")
check("websearch-1-orari", "Castello: 24:00–09:00", "Marina: 21:00–07:00 and 15:30–17:00", "Stampace alto: 21:00–09:00 and 15:30–17:00",
      "Stampace basso: weekdays 07:30–10:30 and 15:30–17:00; Saturday 07:30–10:30", "Villanova: 21:00–07:00 and 15:30–17:00",
      "I found no 2025 or 2026 ordinance changing the Cagliari ZTL hours.")

GEO = osm_geo.load("cagliari-ztl")
SHAPES = {k: osm_geo.perimeter(osm_geo.outer_ring(osm_geo.relation(GEO, rid)), tol_m=4) for k, rid in (("castello", 14402165), ("marina", 14402156))}
GATES = osm_geo.gates(GEO, name_prefix=None)
# Controlli: Cattedrale e Bastione di Saint Remy (Castello), via Sardegna (Marina) dentro; stazione e piazza Yenne fuori
for key, name, lat, lon, inside in [("castello", "Cattedrale di Santa Maria", 39.2189, 9.1157, True),
                                    ("marina", "Via Sardegna", 39.2153, 9.1125, True),
                                    ("castello", "Stazione ferroviaria", 39.2163, 9.1066, False),
                                    ("marina", "Stazione ferroviaria", 39.2163, 9.1066, False)]:
    if osm_geo.contains(SHAPES[key], lat, lon) != inside:
        raise SystemExit(f"Controllo perimetro fallito: {name} ({key})")


def gates_for(key):
    out = [osm_geo.gate_json("ca", (g[0], "Varco ZTL", g[2], g[3])) for g in GATES
           if osm_geo.distance_m(SHAPES[key], g[2], g[3]) < 40]
    return sorted(out, key=lambda g: g["id"])


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


LINKS = [link("City of Cagliari: ZTL regulation (text in force, Dec. 2025)", "Comune di Cagliari: regolamento ZTL (testo vigente, dic. 2025)", "Stadt Cagliari: ZTL-Ordnung (geltender Text, Dez. 2025)", RULES),
         link("City of Cagliari: ZTL and pedestrian zones office", "Comune di Cagliari: ufficio ZTL e zone pedonali", "Stadt Cagliari: Büro ZTL und Fußgängerzonen", OFFICE),
         link("City of Cagliari: ZTL passes", "Comune di Cagliari: rilascio pass ZTL", "Stadt Cagliari: ZTL-Pässe", PASSES),
         link("City of Cagliari: ZTL pass for hotels", "Comune di Cagliari: pass ZTL per strutture ricettive", "Stadt Cagliari: ZTL-Pass für Unterkünfte", HOTELS),
         link("SicurAUTO: Cagliari ZTL hours (unofficial)", "SicurAUTO: orari ZTL Cagliari (non ufficiale)", "SicurAUTO: ZTL-Zeiten Cagliari (inoffiziell)", UNOFFICIAL)]

COMMON = [
    ("Hours confirmed only by unofficial sources (sicurauto.it, brumbrum.it, accessibilitacentristorici.it, quoting an older City page): the regulation leaves the hours to a City executive (Giunta) act, and no such act appears among the Giunta resolutions on the City's online notice board (all titles 2016–October 2026 checked); the City's old page with hours could not be reached from here and its ZTL map is not downloadable.",
     "Orari confermati solo da fonti non ufficiali (sicurauto.it, brumbrum.it, accessibilitacentristorici.it, che riprendono una vecchia pagina del Comune): il regolamento rimanda gli orari a un atto della Giunta, e nessun atto del genere compare tra le delibere di Giunta dell'albo pretorio online (controllati tutti i titoli 2016–ottobre 2026); la vecchia pagina del Comune con gli orari non era raggiungibile da qui e la mappa ZTL del Geoportale non è scaricabile.",
     "Zeiten nur von inoffiziellen Quellen bestätigt (sicurauto.it, brumbrum.it, accessibilitacentristorici.it, nach einer älteren Stadtseite): Die Ordnung überlässt die Zeiten einem Beschluss des Stadtvorstands (Giunta), und kein solcher Beschluss steht unter den Giunta-Beschlüssen der Online-Amtstafel (alle Titel 2016–Oktober 2026 geprüft); die alte Stadtseite mit den Zeiten war von hier nicht erreichbar und die ZTL-Karte des Geoportals ist nicht herunterladbar."),
    ("Hotels (official, ZTL regulation art. 10): the hotel sends your plate online to the City's ZTL office for arrival and departure days, to unload luggage; stop 60 minutes at most with parking disc and the hotel's pass. Mopeds (not motorbikes) may enter; electric cars need a free-hours transit pass; Blue Badge plates go on a white list on request. Fine about 80–335 € (confirmed only by tyremap.com).",
     "Hotel (ufficiale, regolamento ZTL art. 10): la struttura trasmette online la targa all'ufficio ZTL per i giorni di arrivo e partenza, per scaricare i bagagli; sosta al massimo 60 minuti con disco orario e pass della struttura. I ciclomotori (non le moto) entrano; le auto elettriche hanno bisogno di un pass di solo transito senza limiti orari; le targhe CUDE vanno in lista bianca su richiesta. Multa circa 80–335 € (confermato solo da tyremap.com).",
     "Hotels (offiziell, ZTL-Ordnung Art. 10): Die Unterkunft meldet dein Kennzeichen online an das ZTL-Büro für An- und Abreisetag, zum Ausladen; höchstens 60 Minuten mit Parkscheibe und Pass der Unterkunft. Mopeds (keine Motorräder) dürfen hinein; Elektroautos brauchen einen Durchfahrtspass ohne Zeitbegrenzung; Kennzeichen mit Behindertenausweis kommen auf Antrag auf eine weiße Liste. Bußgeld etwa 80–335 € (nur von tyremap.com bestätigt)."),
]


def zone(key, name, name_it, name_de, summary, summary_it, summary_de, windows, extra=()):
    shape = SHAPES.get(key, [])
    pend = list(extra) + COMMON
    if not shape:
        pend.append(("No perimeter: OpenStreetMap has no area for this ZTL and the City's map could not be read.",
                     "Nessun perimetro: OpenStreetMap non ha un'area per questa ZTL e la mappa del Comune non era leggibile.",
                     "Keine Grenze: OpenStreetMap hat keine Fläche für diese ZTL, und die Stadtkarte war nicht lesbar."))
    return {"id": f"cagliari-{key}", "name": name, "name_it": name_it, "name_de": name_de, "kind": "restricted",
            "summary": summary, "summary_it": summary_it, "summary_de": summary_de,
            "perimeter": shape, "gates": gates_for(key) if shape else [], "windows": windows,
            "freeOnHolidays": False, "holidaysAsSunday": False, "exemptFuels": [], "hotelCanRegister": True,
            "source": {"authority": "City of Cagliari", "pageURL": RULES,
                       "ordinance": "Regolamento comunale per le ZTL (D.C.C. n. 42/2012, modificato con D.C.C. n. 27/2013 e n. 168 del 02/12/2025)",
                       "ordinanceURL": RULES, "quote": QUOTE,
                       "quoteTranslation": "Hotels and other accommodation, to make unloading their guests' luggage easier on arrival and departure days, may send online to the ZTL office and to the Municipal Police the plates of their guests' vehicles, so they are recognised at the gates. Parking may not exceed sixty minutes",
                       "quoteTranslation_de": "Hotels und andere Unterkünfte können, um das Ausladen des Gepäcks ihrer Gäste am An- und Abreisetag zu erleichtern, die Kennzeichen der Gästefahrzeuge online an das ZTL-Büro und die Stadtpolizei übermitteln, damit sie an den Kameras erkannt werden. Das Parken darf sechzig Minuten nicht überschreiten",
                       "checkedOn": CHECKED, "reviewedByHuman": False,
                       "pending": [p[0] for p in pend], "pending_it": [p[1] for p in pend], "pending_de": [p[2] for p in pend],
                       "links": LINKS}}


def w(days, a, b):
    return {"weekdays": days, "start": a, "end": b}


EVE = [w(ALL, 21 * 60, 7 * 60), w(ALL, 15 * 60 + 30, 17 * 60)]
zones = [
    zone("castello", "Castello · hilltop quarter", "Castello · quartiere alto", "Castello · Oberstadt",
         "Castello (the walled hilltop quarter with the Cathedral and Bastione di Saint Remy) is closed to cars without a pass every night from midnight to 9 am. During the day you may drive in.",
         "Castello (il quartiere alto murato con la Cattedrale e il Bastione di Saint Remy) è chiuso alle auto senza pass ogni notte da mezzanotte alle 9. Di giorno si entra.",
         "Castello (das ummauerte Oberstadtviertel mit Kathedrale und Bastione di Saint Remy) ist für Autos ohne Pass jede Nacht von Mitternacht bis 9 Uhr gesperrt. Tagsüber darfst du hinein.",
         [w(ALL, 0, 9 * 60)]),
    zone("marina", "Marina · harbour quarter", "Marina · quartiere del porto", "Marina · Hafenviertel",
         "Marina (the quarter between via Roma and Castello) is closed to cars without a pass every day 3:30–5 pm and 9 pm–7 am.",
         "Marina (il quartiere tra via Roma e Castello) è chiuso alle auto senza pass ogni giorno 15:30–17 e 21–7.",
         "Marina (das Viertel zwischen Via Roma und Castello) ist für Autos ohne Pass täglich 15:30–17 und 21–7 Uhr gesperrt.", EVE),
    zone("stampace-alto", "Stampace Alto · upper Stampace", "Stampace Alto · Stampace alta", "Stampace Alto · oberes Stampace",
         "Upper Stampace is closed to cars without a pass every day 3:30–5 pm and 9 pm–9 am.",
         "Stampace Alto è chiuso alle auto senza pass ogni giorno 15:30–17 e 21–9.",
         "Das obere Stampace ist für Autos ohne Pass täglich 15:30–17 und 21–9 Uhr gesperrt.",
         [w(ALL, 21 * 60, 9 * 60), w(ALL, 15 * 60 + 30, 17 * 60)],
         [("One unofficial source gives 9 pm–10 am instead of 9 pm–9 am.", "Una fonte non ufficiale indica 21–10 invece di 21–9.", "Eine inoffizielle Quelle nennt 21–10 statt 21–9 Uhr.")]),
    zone("stampace-basso", "Stampace Basso · lower Stampace", "Stampace Basso · Stampace bassa", "Stampace Basso · unteres Stampace",
         "Lower Stampace is closed to cars without a pass Monday–Friday 7:30–10:30 am and 3:30–5 pm, Saturday 7:30–10:30 am.",
         "Stampace Basso è chiuso alle auto senza pass dal lunedì al venerdì 7:30–10:30 e 15:30–17, il sabato 7:30–10:30.",
         "Das untere Stampace ist für Autos ohne Pass Montag–Freitag 7:30–10:30 und 15:30–17 Uhr, samstags 7:30–10:30 Uhr gesperrt.",
         [w(MON_FRI + SAT, 7 * 60 + 30, 10 * 60 + 30), w(MON_FRI, 15 * 60 + 30, 17 * 60)],
         [("Sources disagree on Saturdays (afternoon window or not) and on whether this ZTL still exists (an older City press note proposed removing it).",
           "Le fonti non concordano sul sabato (fascia pomeridiana o no) e sul fatto che questa ZTL esista ancora (un vecchio comunicato del Comune ne proponeva l'abolizione).",
           "Die Quellen sind sich uneinig über den Samstag (Nachmittag oder nicht) und darüber, ob diese ZTL noch besteht (eine ältere Pressemitteilung der Stadt schlug ihre Abschaffung vor).")]),
    zone("villanova", "Villanova · old quarter", "Villanova · quartiere storico", "Villanova · Altstadtviertel",
         "Villanova is closed to cars without a pass every day 3:30–5 pm and 9 pm–7 am.",
         "Villanova è chiuso alle auto senza pass ogni giorno 15:30–17 e 21–7.",
         "Villanova ist für Autos ohne Pass täglich 15:30–17 und 21–7 Uhr gesperrt.", EVE),
]

city = {"id": "cagliari", "name": "Cagliari", "name_it": "Cagliari", "name_de": "Cagliari",
        "center": {"lat": 39.2180, "lon": 9.1140}, "zones": zones, "status": "draft",
        "license": "Rules: Comune di Cagliari (ZTL regulation and official pages); hours from unofficial sources. Perimeters and gates: " + osm_geo.ODBL + " (approximate, not official)."}

# Pubblicabile solo con orari citati da un testo ufficiale e perimetri per ogni zona: qui mancano → bozza
ready = False
out = ROOT / ("Resources/Cities/cagliari.json" if ready else "data/drafts/cagliari.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/cagliari.json" if ready else "Resources/Cities/cagliari.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), [(z["id"], len(z["perimeter"]), len(z["gates"])) for z in city["zones"]])
