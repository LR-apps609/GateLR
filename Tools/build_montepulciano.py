#!/usr/bin/env python3
# Costruisce Resources/Cities/montepulciano.json dalle pagine e ordinanze ufficiali del Comune di Montepulciano salvate in
# data/raw/montepulciano/ (fonti e date in docs/fonti-montepulciano.md). Ogni frase usata viene ricontrollata sul testo salvato.
#
# Regole: ordinanza n. 77 dell'11/05/2022 (in vigore dal 01/06/2022, modificata dalle n. 114/2022 e 32/2023; letta nella
# traduzione inglese pubblicata dal Comune), pagina ufficiale «Istruzioni ZTL» (citazione) e comunicato del 15/01/2025 con
# l'ordinanza n. 9/2025 (varchi d'uscita attivi dal 20/01/2025). Calendario tutti i giorni, festivi compresi:
#   1 maggio – 30 settembre 0–24; aprile e ottobre 8–20; 1 novembre – 31 marzo 8–17.
#   (La scheda del servizio «Accesso temporaneo» scrive «dalle ore 8.00 alle ore 00» per aprile e ottobre: in contrasto con
#   ordinanza, istruzioni e comunicato 2025, che dicono 8–20; segnalato nei pending.)
# Geometria: OpenStreetMap (© OpenStreetMap contributors, ODbL 1.0; API OSM, data/raw/geo/montepulciano-ztl.json),
#   relazione enforcement 18111528 «ZTL Montepulciano» con 81 strade (ruolo section) → osm_geo.street_area.
#   L'ordinanza dice che «l'intera area del centro storico» è ZTL (allegato A non pubblicato). Varchi: gli 8 dell'ordinanza
#   e della 9/2025 (ingressi Porta al Prato, Via di Ciliano, Via di Collazzi, Via di San Donato, Via Fiorenzuola Vecchia;
#   uscite Via di Ciliano, Porta di Gozzano/Borgo Buio, Porta delle Farine/Via del Teatro, Porta dei Grassi), ciascuno nel
#   nodo OSM dove la strada indicata esce dalla ZTL.
# Uso: python3 Tools/build_montepulciano.py   (non tocca le altre città né manifest.json)
import json, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/montepulciano"
CHECKED = "2026-10-27T13:00:00Z"
ALL = [1, 2, 3, 4, 5, 6, 7]
OSM_ZTL = 18111528

B = "https://www.comune.montepulciano.si.it"
INSTR = B + "/istruzioni-ztl/"
NEWS_2025 = B + "/novita/da-lunedi-20-gennaio-entrano-in-funzione-i-varchi-in-uscita-per-il-controllo-della-ztl-nel-centro-storico/"
TEMP = B + "/servizio/richiesta-permesso-di-accesso-temporaneo-alla-ztl/"
ORD_9 = B + "/wp-content/uploads/2025/01/OrdinanzadelResponsabile_Copia_9_2025-ztl-varchi-uscita.pdf"
ORD_77_EN = B + "/wp-content/uploads/2024/11/DEF_ordinanza_ZTL_77_2022_EN.pdf"


def flat(s):
    return re.sub(r"\s+", " ", s).strip()


TEXT = {p.stem: flat(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def check(file, *phrases):
    for q in phrases:
        if flat(q) not in TEXT[file]:
            raise SystemExit(f"{file}: frase non trovata, ricontrollare il documento: {q!r}")


QUOTE = ("Dal 1 maggio al 30 settembre, ZTL attiva 24 ore (dalle ore 00.00 alle ore 24.00) Nei mesi di aprile ed ottobre, ZTL "
         "attiva dalle 8.00 alle 20.00 Dal 1 novembre al 31 marzo, ZTL attiva dalle 8.00 alle 17.00")
check("comune-istruzioni-ztl", QUOTE,
      "Non sono previste deroghe per veicoli con motore elettrico e/o ibrido.",
      "L’ingresso e la circolazione per operazioni di carico e scarico merci sono consentite dalle 7.00 alle 11.00 di tutti i giorni, compresi i festivi.",
      "Turisti e visitatori, clienti delle strutture ricettive, per raggiungere le strutture stesse, con posteggio esclusivamente negli stalli indicati",
      "chiamando il numero verde 800669945", "In ogni caso gli utenti devono rigorosamente rispettare il percorso assegnato")
check("comune-news-2025-01-15-varchi-uscita",
      "dal 1° maggio al 30 settembre, ZTL chiusa 24 ore (dalle ore 00.00 alle ore 24.00); nei mesi di aprile ed ottobre, ZTL chiusa dalle 8.00 alle 20.00; dal 1° novembre al 31 marzo, ZTL chiusa dalle 8.00 alle 17.00.",
      "Dal 20 gennaio 2025 entreranno in funzione i nuovi varchi elettronici in uscita",
      "Via di Ciliano , Via di Gozzano (Borgo Buio) , Via dell’Opio (via del Teatro) e Via dei Grassi")
check("ord-77-2022-en", "The Limited Traffic Zone is effective every day (weekdays and holidays) in the following hours:",
      "1 May to 30 September, for 24 hours per day;", "In the months of April and October, from 8 a.m. to 8 p.m.;",
      "the rest of the year, from 8:00 a.m. to 5:00 p.m.", "No exemptions are provided for vehicles with electric and/or hybrid engines.",
      "entering the guest’s vehicle license number in the temporary \"White List\", using the relative Internet service.",
      "Short-term guests are never permitted to park within the ZTL.", "Stopping is permitted for a maximum of 20 minutes",
      "the gates “Porta al Prato”, with two video cameras, and “Collazzi”, “San Donato” and “Fiorenzuola Vecchia”",
      "That the entire area of the historic centre of Montepulciano is defined, for the purposes of mobility, as a Limited Traffic Zone (ZTL).",
      "including retrospectively within the working day following the access")
check("ord-9-2025", "a far data dal 20/01/2025", "N. 32 del 17/02/2023", "Via di Ciliano, Via di Gozzano (Borgo Buio), Via dell’Opio (via del Teatro) e via dei Grassi")
check("comune-accesso-temporaneo-ztl", "nei mesi di aprile e ottobre - dalle ore 8.00 alle ore 00",
      "le richieste che dalla data di inizio alla data di fine vanno oltre i 7 giorni, non verranno prese in considerazione.")

GEO = osm_geo.load("montepulciano-ztl")
rel = osm_geo.relation(GEO, OSM_ZTL)
if rel["tags"].get("name") != "ZTL Montepulciano" or len(rel["members"]) < 70:
    raise SystemExit("La relazione OSM della ZTL è cambiata: ricontrollare")
shape = osm_geo.perimeter(osm_geo.street_area(rel), tol_m=4)
ways = {e["id"]: e for e in GEO if e["type"] == "way"}
coord = {n: (p["lat"], p["lon"]) for w in ways.values() for n, p in zip(w["nodes"], w["geometry"])}
streets = {n: {w["tags"].get("name") for w in ways.values() if n in w["nodes"]} for n in coord}
GATES = [(305521951, "Porta al Prato · ingresso", "Via di Gracciano nel Corso"),
         (2198093415, "Via di Ciliano · ingresso e uscita", "Via di Ciliano"),
         (1776199386, "Via di Collazzi · ingresso", "Via di Collazzi"),
         (787024727, "Via di San Donato · ingresso", "Via San Donato"),
         (787008407, "Via Fiorenzuola Vecchia · ingresso", "Via Fiorenzuola Vecchia"),
         (264347932, "Porta di Gozzano (Borgo Buio) · uscita", "Via di Gozzano"),
         (787008514, "Porta delle Farine (Via del Teatro) · uscita", "Via delle Farine"),
         (2972092117, "Porta dei Grassi · uscita", "Via dei Grassi")]
gate_list = []
for nid, name, street in GATES:
    if street not in streets.get(nid, set()):
        raise SystemExit(f"Il nodo {nid} non è più su {street}")
    lat, lon = coord[nid]
    if osm_geo.distance_m(shape, lat, lon) > 40:
        raise SystemExit(f"Varco lontano dal bordo: {name}")
    gate_list.append(osm_geo.gate_json("mp", (nid, "Varco " + name, lat, lon)))
# Controlli: Piazza Grande e il Corso dentro; San Biagio, Fortezza, parcheggi 1 e Piazza Moulins fuori
for name, lat, lon, inside in [("Piazza Grande", 43.09271, 11.78098, True), ("Via di Gracciano nel Corso", 43.0966, 11.7851, True),
                               ("Tempio di San Biagio", 43.09068, 11.77463, False), ("Fortezza Medicea", 43.09078, 11.77969, False),
                               ("Parcheggio 1", 43.09784, 11.785, False), ("Parcheggio Piazza Moulins", 43.09853, 11.78651, False)]:
    if osm_geo.contains(shape, lat, lon) != inside:
        raise SystemExit(f"Controllo perimetro fallito: {name} dovrebbe essere {'dentro' if inside else 'fuori'}")
area = osm_geo.area_km2(shape)
if not 0.08 < area < 0.25:
    raise SystemExit(f"Area della ZTL non plausibile: {area:.3f} km²")


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


LINKS = [link("City of Montepulciano: ZTL instructions (hours)", "Comune di Montepulciano: istruzioni ZTL (orari)", "Stadt Montepulciano: ZTL-Anleitung (Zeiten)", INSTR),
         link("City of Montepulciano: ordinance no. 77/2022 (official English translation, PDF)", "Comune di Montepulciano: ordinanza n. 77/2022 (traduzione inglese ufficiale, PDF)", "Stadt Montepulciano: Verordnung Nr. 77/2022 (offizielle englische Übersetzung, PDF)", ORD_77_EN),
         link("City of Montepulciano: exit gates active from 20 January 2025", "Comune di Montepulciano: varchi in uscita dal 20 gennaio 2025", "Stadt Montepulciano: Ausfahrtskameras ab 20. Januar 2025", NEWS_2025),
         link("City of Montepulciano: ordinance no. 9/2025 (PDF)", "Comune di Montepulciano: ordinanza n. 9/2025 (PDF)", "Stadt Montepulciano: Verordnung Nr. 9/2025 (PDF)", ORD_9),
         link("City of Montepulciano: temporary ZTL access", "Comune di Montepulciano: accesso temporaneo alla ZTL", "Stadt Montepulciano: befristete ZTL-Zufahrt", TEMP),
         link(f"OpenStreetMap: relation {OSM_ZTL} «ZTL Montepulciano» (ODbL)", f"OpenStreetMap: relazione {OSM_ZTL} «ZTL Montepulciano» (ODbL)", f"OpenStreetMap: Relation {OSM_ZTL} «ZTL Montepulciano» (ODbL)", osm_geo.osm_url("relation", OSM_ZTL))]

PENDING = [
    ("Hotels inside the walls put your plate on the City's temporary white list for the length of your stay: you may drive only by the shortest route to the hotel, stop at most 20 minutes to unload, never park inside. Each permit also fixes the exit gate: since 20 January 2025 cameras check the exits too.",
     "Gli hotel dentro le mura inseriscono la targa nella «white list» temporanea del Comune per la durata del soggiorno: si va solo per il percorso più breve fino alla struttura, sosta al massimo 20 minuti per scaricare, mai parcheggio dentro. Ogni permesso fissa anche l'uscita: dal 20 gennaio 2025 le telecamere controllano anche le uscite.",
     "Hotels innerhalb der Mauern setzen dein Kennzeichen für die Dauer des Aufenthalts auf die befristete weiße Liste der Stadt: Fahrt nur auf dem kürzesten Weg zur Unterkunft, höchstens 20 Minuten Halt zum Ausladen, nie innen parken. Jede Genehmigung legt auch die Ausfahrt fest: Seit 20. Januar 2025 überwachen Kameras auch die Ausfahrten."),
    ("No exemption for electric or hybrid cars. Loading and unloading of goods is allowed 7–11 am every day (for deliveries, not for visitors). Blue Badge holders can have their plate added to the white list, even by the working day after the access. Temporary permits: online with SPID/CIE (max 7 days) or, in exceptional cases, the free number 800 669 945.",
     "Nessuna deroga per auto elettriche o ibride. Carico e scarico merci consentito 7–11 tutti i giorni (per le consegne, non per i visitatori). I titolari di contrassegno disabili possono far inserire la targa nella white list, anche entro il giorno lavorativo successivo all'accesso. Permessi temporanei: online con SPID/CIE (massimo 7 giorni) o, in casi eccezionali, al numero verde 800 669 945.",
     "Keine Ausnahme für Elektro- oder Hybridautos. Be- und Entladen von Waren ist täglich 7–11 Uhr erlaubt (für Lieferungen, nicht für Besucher). Inhaber eines Behindertenausweises können ihr Kennzeichen auf die weiße Liste setzen lassen, auch bis zum Werktag nach der Einfahrt. Befristete Genehmigungen: online mit SPID/CIE (höchstens 7 Tage) oder in Ausnahmefällen über die Gratisnummer 800 669 945."),
    ("The City's «temporary access» service page gives April and October as 8 am–midnight, while the ordinance, the ZTL instructions page and the January 2025 notice say 8 am–8 pm: GateLR follows the latter.",
     "La scheda del servizio «accesso temporaneo» del Comune indica per aprile e ottobre 8–24, mentre ordinanza, pagina delle istruzioni ZTL e comunicato di gennaio 2025 dicono 8–20: GateLR segue questi ultimi.",
     "Die Serviceseite «befristete Zufahrt» der Stadt nennt für April und Oktober 8–24 Uhr, Verordnung, ZTL-Anleitung und Mitteilung vom Januar 2025 dagegen 8–20 Uhr: GateLR folgt Letzteren."),
    ("Area drawn from the streets of the OpenStreetMap ZTL relation (the ordinance's map, annex A, is not published): the whole old town inside the walls. Gates placed where the streets named by the City leave the ZTL. Ordinance 32/2023 (amendments) was not read.",
     "Area ricavata dalle strade della relazione ZTL di OpenStreetMap (la planimetria dell'ordinanza, allegato A, non è pubblicata): tutto il centro storico dentro le mura. Varchi nei punti in cui le strade indicate dal Comune escono dalla ZTL. L'ordinanza 32/2023 (modifiche) non è stata letta.",
     "Fläche aus den Straßen der OpenStreetMap-ZTL-Relation (der Plan der Verordnung, Anlage A, ist nicht veröffentlicht): die ganze Altstadt innerhalb der Mauern. Kameras dort, wo die von der Stadt genannten Straßen die ZTL verlassen. Verordnung 32/2023 (Änderungen) wurde nicht gelesen."),
]

SEASONS = [({"fromMonth": 5, "fromDay": 1, "toMonth": 9, "toDay": 30}, 0, 24 * 60),
           ({"fromMonth": 4, "fromDay": 1, "toMonth": 4, "toDay": 30}, 8 * 60, 20 * 60),
           ({"fromMonth": 10, "fromDay": 1, "toMonth": 10, "toDay": 31}, 8 * 60, 20 * 60),
           ({"fromMonth": 11, "fromDay": 1, "toMonth": 3, "toDay": 31}, 8 * 60, 17 * 60)]

zone = {"id": "montepulciano-centro", "name": "Old town · ZTL inside the walls", "name_it": "Centro storico · ZTL dentro le mura",
        "name_de": "Altstadt · ZTL innerhalb der Mauern", "kind": "restricted",
        "summary": "The whole old town of Montepulciano inside the walls (the Corso, Piazza Grande) is closed to cars without a permit every day: 24 hours a day from 1 May to 30 September, 8 am–8 pm in April and October, 8 am–5 pm from November to March. Cameras check entries and exits. Staying inside? Your hotel puts your plate on the white list, only to unload. Park at the car parks outside the gates (e.g. P1 near Porta al Prato) and walk.",
        "summary_it": "Tutto il centro storico di Montepulciano dentro le mura (il Corso, Piazza Grande) è chiuso alle auto senza permesso tutti i giorni: 24 ore su 24 dal 1° maggio al 30 settembre, 8–20 ad aprile e ottobre, 8–17 da novembre a marzo. Le telecamere controllano ingressi e uscite. Dormi dentro? L'hotel inserisce la targa nella white list, solo per scaricare. Parcheggia nei parcheggi fuori dalle porte (es. P1 vicino a Porta al Prato) e cammina.",
        "summary_de": "Die ganze Altstadt von Montepulciano innerhalb der Mauern (der Corso, Piazza Grande) ist für Autos ohne Genehmigung täglich gesperrt: rund um die Uhr vom 1. Mai bis 30. September, 8–20 Uhr im April und Oktober, 8–17 Uhr von November bis März. Kameras überwachen Ein- und Ausfahrten. Du übernachtest innen? Dein Hotel setzt dein Kennzeichen auf die weiße Liste, nur zum Ausladen. Auf den Parkplätzen vor den Toren parken (z. B. P1 bei der Porta al Prato) und laufen.",
        "perimeter": shape, "gates": gate_list,
        "windows": [{"weekdays": ALL, "start": a, "end": b, "season": s} for s, a, b in SEASONS],
        "freeOnHolidays": False, "holidaysAsSunday": False, "exemptFuels": [], "hotelCanRegister": True,
        "source": {"authority": "City of Montepulciano", "pageURL": INSTR,
                   "ordinance": "Ordinanza n. 77 dell'11/05/2022 (modificata dalle n. 114/2022 e 32/2023); varchi d'uscita: ordinanza n. 9 del 14/01/2025",
                   "ordinanceURL": ORD_77_EN, "quote": QUOTE,
                   "quoteTranslation": "From 1 May to 30 September, ZTL active 24 hours (from 00.00 to 24.00). In April and October, ZTL active from 8.00 to 20.00. From 1 November to 31 March, ZTL active from 8.00 to 17.00.",
                   "quoteTranslation_de": "Vom 1. Mai bis 30. September ZTL 24 Stunden aktiv (von 00.00 bis 24.00 Uhr). Im April und Oktober ZTL aktiv von 8.00 bis 20.00 Uhr. Vom 1. November bis 31. März ZTL aktiv von 8.00 bis 17.00 Uhr.",
                   "checkedOn": CHECKED, "reviewedByHuman": False,
                   "pending": [p[0] for p in PENDING], "pending_it": [p[1] for p in PENDING], "pending_de": [p[2] for p in PENDING],
                   "links": LINKS}}

city = {"id": "montepulciano", "name": "Montepulciano", "name_it": "Montepulciano", "name_de": "Montepulciano",
        "center": {"lat": 43.0927, "lon": 11.7810}, "zones": [zone], "status": "draft",
        "license": "Rules: Comune di Montepulciano (ordinances 77/2022 and 9/2025, official pages). Area and gates: " + osm_geo.ODBL + " (approximate, not official)."}

ready = all(len(z["perimeter"]) >= 5 and z["source"]["quote"] for z in city["zones"])
out = ROOT / ("Resources/Cities/montepulciano.json" if ready else "data/drafts/montepulciano.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/montepulciano.json" if ready else "Resources/Cities/montepulciano.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), [(z["id"], len(z["perimeter"]), len(z["gates"])) for z in city["zones"]], f"{area:.3f} km²")
