#!/usr/bin/env python3
# Costruisce Resources/Cities/san-gimignano.json dagli atti ufficiali del Comune di San Gimignano salvati in
# data/raw/san-gimignano/ (fonti e date in docs/fonti-san-gimignano.md).
#
# Regole: «Disciplinare per il rilascio delle autorizzazioni di accesso e circolazione nella ZTL del centro storico»
# (DGC n. 42 del 12/03/2026, in vigore dal 1° maggio 2026; ordinanza n. 65/2026 «attivazione dei varchi … avvio fase
# ordinaria»), testo estratto con pdftotext in disciplinare-ztl-dgc-42-2026.txt; brochure di sintesi (aprile 2026) e
# comunicato stampa n. 91 del 27/04/2026.
# Perimetro e varchi: dalla planimetria ufficiale (ztl-planimetria.pdf), agganciata agli edifici OpenStreetMap da
# Tools/sangimignano_mappa.py → data/raw/san-gimignano/ztl-mappa-ufficiale.json (mai disegnati a mano).
# Non aggiorna manifest.json. Uso: python3 Tools/build_san_gimignano.py
import html, json, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/san-gimignano"
CHECKED = "2026-10-26T01:30:00Z"

NEWS = "https://comune.sangimignano.si.it/it/news/ztl-centro-storico-di-san-gimignano"
PORTAL = "https://ztl.comune.sangimignano.si.it/"
RULES_PDF = "https://visualizzatore.comune.sangimignano.si.it/AttiVisualizzatore/download/allegato/1919896?fId=1931869&sbustato=true"
ORD_65 = "https://visualizzatore.comune.sangimignano.si.it/AttiVisualizzatore/visualizza/determina/1946902"
BROCHURE = "https://cloud-ita.municipiumapp.it/s3/6203/allegati/polizia-municipale/nuova-ztl/brochure-ztl_aprile-2026.pdf"
MAP_PDF = "https://cloud-ita.municipiumapp.it/s3/6203/allegati/polizia-municipale/nuova-ztl/ztl-planimetria.pdf"
PRESS = "https://san-gimignano-api.cloud.municipiumapp.it/s3/6203/allegati/ufficio-stampa/cs-nuova-ztl-da-1-maggio.pdf"

MON_SAT_NO_THU, THU, SUN, MON_SAT = [2, 3, 4, 6, 7], [5], [1], [2, 3, 4, 5, 6, 7]


def flat(text):
    return re.sub(r"\s+", " ", text).strip()


def page_text(name):
    t = (RAW / name).read_text(encoding="utf-8")
    t = re.sub(r"<(script|style)[^>]*>.*?</\1>", " ", t, flags=re.S)
    return flat(html.unescape(re.sub(r"<[^>]+>", " ", t)))


TEXT = {"disciplinare": flat((RAW / "disciplinare-ztl-dgc-42-2026.txt").read_text(encoding="utf-8")),
        "brochure": flat((RAW / "brochure-ztl-aprile-2026.txt").read_text(encoding="utf-8")),
        "comunicato": flat((RAW / "comunicato-27-04-2026.txt").read_text(encoding="utf-8")),
        "notizia": page_text("notizia-ztl-centro-storico.html"),
        "ordinanza": page_text("ordinanza-65-2026.html"),
        "citynext": page_text("citynext-2025-06-25.html"),
        "tirreno": flat((RAW / "comunicato-tirreno-adriatico-10-03-2026.txt").read_text(encoding="utf-8")),
        "parcheggi": page_text("parcheggi-abbonamenti-non-residenti.html"),
        "porta": page_text("notizia-restauro-porta-san-giovanni.html")}


def check(doc, *quotes):
    """Ogni frase citata o riassunta deve esserci davvero nel documento salvato"""
    for q in quotes:
        if flat(q) not in TEXT[doc]:
            raise SystemExit(f"{doc}: frase non trovata, ricontrollare il documento: {q!r}")


QUOTE = ("La ZTL ha validità tutti i giorni ad eccezione dei giorni feriali nell’orario 05:30/09:30, salvo il giovedì "
         "con orario 05:30/08:30, nei giorni di fiere e per particolari esigenze o per particolari periodi dell’anno.")
check("disciplinare", QUOTE,
      "Antiporta San Giovanni (dall’intersezione stradale tra Viale Roma e Piazzale Martiri Montemaggio)",
      "1) Porta San Giovanni 2) Bonda/Piandornella 3) Via Santa Caterina 4) Via di Quercecchio 5) Porta San Matteo 6) Via di Bagnaia",
      "All’interno della ZTL è istituito il limite massimo di velocità in 30 km/h.",
      "autocaravan, caravan",
      "Gli ospiti delle strutture ricettive turistiche ai sensi della LR n. 61/2024 hanno libero accesso alla ZTL nell’orario 5:30 – 9:30.",
      "Le citate strutture ricettive turistiche hanno l’obbligo di registrazione preventiva delle targhe dei loro ospiti per "
      "l’accesso in ZTL tramite portale della Polizia Locale",
      "Dalle ore 15:00 alle ore 20:00 è sempre consentito l’accesso degli ospiti di strutture ricettive turistiche in ZTL nelle "
      "Vie Secondarie del Centro Storico, in Via del Castello e Piazza Cisterna con obbligo di registrazione preventiva tramite portale della Polizia Locale.",
      "L’accesso è consentito per la sola fermata (non sosta).",
      "Per ingressi in ZTL dopo le ore 20:00 e fino alle ore 05:30 del giorno dopo, possibilità di registrare l’ingresso in ZTL "
      "degli ospiti anche nelle 24 ore successive da parte delle strutture ricettive turistiche.",
      "Per gli ospiti di strutture ricettive turistiche che pernottano per almeno 5 notti è consentito un solo ingresso al giorno, "
      "oltre quello di arrivo e partenza, anche oltre l’orario 09:30",
      "31 GENNAIO, 12 MARZO, LUNEDÌ dopo la PRIMA DOMENICA DI AGOSTO, 29 AGOSTO fino alle 20:00",
      "31 GENNAIO, 31 MARZO, LUNEDI’ dopo la PRIMA DOMENICA DI AGOSTO, 29 AGOSTO",
      # tabella «da richiedere anche successivamente al transito» (in pdftotext le colonne si mescolano)
      "titolari di tagliando senza limitazioni orarie", "del veicolo almeno entro le", "48 ore successive all’accesso",
      "Dal 1 giugno al 30 settembre di ogni anno nei giorni festivi la Piazza è zona pedonale con orario 9-19",
      "San Giovanni (Via) Senso unico di marcia verso Piazza della Cisterna",
      "San Matteo (Via) Senso unico di marcia verso Porta S.Matteo",
      "Santa Caterina (Via) Senso unico di marcia verso il Viale dei Fossi",
      "Quercecchio (Via) Senso unico di marcia dal Viale dei Fossi all’intersezione con Via Berignano",
      "Bonda (Via) Doppio senso di marcia",
      "La Giunta Comunale si riserva di sospendere temporaneamente l'efficacia del controllo elettronico degli accessi in ztl")
check("comunicato", "videocontrollo degli accessi, attivo generalmente tutti i giorni dalle 9.30 alle ore 5.30 del giorno dopo, "
      "salvo diversa disposizione della Giunta comunale per particolari eventi o periodi dell’anno")
check("brochure", "tutti i giorni 24 ore su", "Dalle ore 5.30 alle 9.30 gli ospiti delle strutture ricettive turistiche in",
      "registrare preventivamente", "l’accesso degli ospiti alla ZTL,", "utilizzando il Portale ZTL del")
check("notizia", "Ordinanza n. 65/2026 , Attivazione dei varchi della nuova ZTL",
      "ai sensi della DGC n.42 del 12.03.2026", "ztl@comune.sangimignano.si.it")
check("ordinanza", "Determina N. 65 di Registro per le Ordinanze del 30/04/2026", "TERMINE FASE DI PRE-ESERCIZIO E AVVIO FASE ORDINARIA")
check("tirreno", "Parcheggio P1 Giubileo", "Parcheggi P3 e P4 Bagnaia", "Parcheggio P2 Montemaggio")
check("parcheggi", "P1 Giubileo", "Parcheggi di Bagnaia P3 e P4")
check("porta", "Dalle ore 8.00 di lunedì 17 agosto 2026 fino alle ore 20.00 di domenica 22 novembre 2026",
      "chiusura di parte dell’area pedonale antistante Porta San Giovanni")
check("citynext", "2 per sola entrata (Porta San Giovanni, Via di Quercecchio), 2 per sola uscita (Via Santa Caterina, Porta San Matteo) "
      "e 2 per entrambe (Bonda/Piandornella e Via di Bagnaia)")


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


LINKS = [
    link("City of San Gimignano: new ZTL with camera gates, in force from 1 May 2026", "Comune di San Gimignano: nuova ZTL con varchi videocontrollati, a regime dal 1° maggio 2026",
         "Stadt San Gimignano: neue ZTL mit Kameras, gültig ab 1. Mai 2026", NEWS),
    link("ZTL rules (Disciplinare, Town Council decision 42 of 12/03/2026, PDF)", "Disciplinare ZTL (DGC n. 42 del 12/03/2026, PDF)",
         "ZTL-Regeln (Disciplinare, Beschluss 42 vom 12.03.2026, PDF)", RULES_PDF),
    link("Summary brochure, April 2026 (PDF)", "Brochure di sintesi, aprile 2026 (PDF)", "Kurzbroschüre, April 2026 (PDF)", BROCHURE),
    link("Official map of the ZTL and its 6 gates (PDF)", "Planimetria ufficiale della ZTL e dei 6 varchi (PDF)",
         "Offizielle Karte der ZTL und der 6 Kameras (PDF)", MAP_PDF),
    link("ZTL portal of the Local Police (permits, hotel registration)", "Portale ZTL della Polizia Locale (autorizzazioni, registrazione degli ospiti)",
         "ZTL-Portal der Ortspolizei (Genehmigungen, Hotelmeldung)", PORTAL),
    link("Ordinance 65/2026: gates switched to normal operation", "Ordinanza 65/2026: attivazione dei varchi, avvio della fase ordinaria",
         "Anordnung 65/2026: Kameras im Regelbetrieb", ORD_65),
    link("City press release no. 91 of 27/04/2026 (PDF)", "Comunicato stampa del Comune n. 91 del 27/04/2026 (PDF)",
         "Pressemitteilung der Stadt Nr. 91 vom 27.04.2026 (PDF)", PRESS),
]

PENDING = [
    ("Hours: the rules (Disciplinare) say the ZTL applies every day except on working days (Monday–Saturday) from 5:30 to 9:30 am "
     "(Thursday, market day, and fair days only until 8:30). The city's press release of 27/04/2026 says the cameras are on \"generally every day "
     "from 9:30 am to 5:30 am the next day\", while the April 2026 brochure says \"24 hours a day\". So on Sundays and holidays the ZTL applies all day, "
     "but early in the morning there may be no camera. The brochure presents the 5:30–9:30 window mainly for residents and hotel guests: "
     "to be confirmed with the Local Police whether every visitor may drive in then.",
     "Orari: il Disciplinare dice che la ZTL vale tutti i giorni tranne nei giorni feriali (lunedì–sabato) dalle 5:30 alle 9:30 "
     "(il giovedì, giorno di mercato, e nei giorni di fiera solo fino alle 8:30). Il comunicato del Comune del 27/04/2026 dice che il videocontrollo è attivo "
     "«generalmente tutti i giorni dalle 9.30 alle ore 5.30 del giorno dopo», la brochure di aprile 2026 «24 ore su 24». Quindi domenica e festivi la ZTL vale "
     "tutto il giorno, ma la mattina presto la telecamera potrebbe essere spenta. La brochure presenta la fascia 5:30–9:30 soprattutto per residenti e ospiti "
     "delle strutture ricettive: da confermare con la Polizia Locale se in quella fascia può entrare qualunque visitatore.",
     "Zeiten: Laut Regelwerk (Disciplinare) gilt die ZTL täglich außer an Werktagen (Montag–Samstag) von 5:30 bis 9:30 Uhr "
     "(donnerstags, am Markttag, und an Messetagen nur bis 8:30). Laut Pressemitteilung vom 27.04.2026 sind die Kameras »in der Regel täglich von 9:30 bis "
     "5:30 Uhr des Folgetags« aktiv, laut Broschüre vom April 2026 »rund um die Uhr«. Sonntags und an Feiertagen gilt die ZTL also ganztägig, frühmorgens "
     "ist aber eventuell keine Kamera aktiv. Die Broschüre nennt das Fenster 5:30–9:30 vor allem für Anwohner und Hotelgäste: ob dann jeder Besucher "
     "einfahren darf, ist mit der Ortspolizei zu klären."),
    ("Fair days (31 January, feast of St Gimignano; 12 March, St Fina; the Monday after the first Sunday of August; 29 August): the free morning ends at 8:30 "
     "and the main streets are closed to hotel guests until 8 pm. They are treated as fair days, not as public holidays (the rules list them separately from "
     "holidays); the hotel section once writes \"31 MARZO\" instead of 12 March, probably a typo.",
     "Giorni di fiera (31 gennaio, San Gimignano; 12 marzo, Santa Fina; lunedì dopo la prima domenica di agosto; 29 agosto): la fascia libera del mattino "
     "finisce alle 8:30 e le vie principali sono chiuse agli ospiti delle strutture fino alle 20. Sono trattati come giorni di fiera, non come festivi "
     "(il Disciplinare li elenca a parte rispetto ai festivi); nella parte sulle strutture ricettive compare una volta «31 MARZO» al posto del 12 marzo, "
     "probabilmente un refuso.",
     "Messetage (31. Januar, Fest des hl. Geminianus; 12. März, hl. Fina; Montag nach dem ersten Augustsonntag; 29. August): Das freie Morgenfenster endet "
     "um 8:30 und die Hauptstraßen sind für Hotelgäste bis 20 Uhr gesperrt. Sie gelten als Messetage, nicht als Feiertage (das Regelwerk nennt sie getrennt "
     "von den Feiertagen); im Hotelabschnitt steht einmal »31 MARZO« statt 12. März, vermutlich ein Tippfehler."),
    ("Fine amount: not published by the city; ZTL violations fall under art. 7 of the Italian Highway Code.",
     "Importo della multa: il Comune non lo pubblica; l'ingresso non autorizzato è sanzionato dall'art. 7 del Codice della Strada.",
     "Bußgeld: von der Stadt nicht veröffentlicht; unerlaubte Einfahrt fällt unter Art. 7 der italienischen Straßenverkehrsordnung."),
    ("Perimeter and gates: taken automatically from the city's official map (PDF image, 1:2000), aligned to OpenStreetMap buildings; accuracy a few metres. "
     "To the east the map's blue line leaves the frame where Via Bonda meets Via Porta Pisana: the zone is cut there at the edge of the map (a few metres). "
     "Gate directions (2 entry-only, 2 exit-only, 2 both ways) are confirmed only by CityNext (25/06/2025); they match the one-way streets in the rules.",
     "Perimetro e varchi: ricavati in automatico dalla planimetria ufficiale del Comune (immagine in PDF, 1:2000), agganciata agli edifici di OpenStreetMap; "
     "precisione di qualche metro. A est la linea blu esce dal riquadro della mappa all'incrocio tra via Bonda e via Porta Pisana: lì la zona è tagliata al bordo della mappa (pochi metri). "
     "Il senso dei varchi (2 solo entrata, 2 solo uscita, 2 in entrambi i sensi) è confermato solo da CityNext (25/06/2025); coincide con i sensi unici del Disciplinare.",
     "Grenze und Kameras: automatisch aus der offiziellen Karte der Stadt (Bild im PDF, 1:2000) gewonnen und an den OpenStreetMap-Gebäuden ausgerichtet; "
     "Genauigkeit einige Meter. Im Osten verlässt die blaue Linie den Kartenrahmen an der Kreuzung Via Bonda/Via Porta Pisana: Dort endet die Zone am Kartenrand (wenige Meter). "
     "Die Fahrtrichtungen der Kameras (2 nur Einfahrt, 2 nur Ausfahrt, 2 beide) bestätigt nur CityNext (25.06.2025); sie passen zu den Einbahnstraßen im Regelwerk."),
    ("Car parks outside the walls: P1 Giubileo, P2 Montemaggio, P3 and P4 Bagnaia (names from the city's press release of March 2026 and its parking page); "
     "visitor prices are not on an official page we could read. Until 22 November 2026 part of the pedestrian area in front of Porta San Giovanni is "
     "closed for restoration works (ordinance 109/2026); the ZTL rules do not change.",
     "Parcheggi fuori dalle mura: P1 Giubileo, P2 Montemaggio, P3 e P4 Bagnaia (nomi dal comunicato del Comune di marzo 2026 e dalla pagina sui parcheggi); "
     "le tariffe per i visitatori non sono su una pagina ufficiale che abbiamo potuto leggere. Fino al 22 novembre 2026 parte dell'area pedonale davanti a "
     "Porta San Giovanni è chiusa per i lavori di restauro (ordinanza 109/2026); le regole della ZTL non cambiano.",
     "Parkplätze außerhalb der Mauern: P1 Giubileo, P2 Montemaggio, P3 und P4 Bagnaia (Namen aus der Pressemitteilung der Stadt vom März 2026 und ihrer "
     "Parkplatzseite); Besucherpreise stehen auf keiner offiziellen Seite, die wir lesen konnten. Bis 22. November 2026 ist ein Teil der Fußgängerzone vor "
     "der Porta San Giovanni wegen Restaurierung gesperrt (Anordnung 109/2026); die ZTL-Regeln ändern sich nicht."),
]

source = {"authority": "City of San Gimignano", "pageURL": NEWS,
          "ordinance": "Disciplinare ZTL (DGC n. 42 del 12/03/2026); Ordinanza n. 65 del 30/04/2026", "ordinanceURL": RULES_PDF,
          "quote": QUOTE,
          "quoteTranslation": "The ZTL applies every day except on working days from 05:30 to 09:30 – on Thursdays 05:30 to 08:30 – on fair days and for special needs or particular periods of the year.",
          "quoteTranslation_de": "Die ZTL gilt täglich außer an Werktagen von 05:30 bis 09:30 Uhr – donnerstags von 05:30 bis 08:30 Uhr –, an Messetagen und bei besonderen Anlässen oder Zeiten des Jahres.",
          "checkedOn": CHECKED, "reviewedByHuman": False,
          "pending": [p[0] for p in PENDING], "pending_it": [p[1] for p in PENDING], "pending_de": [p[2] for p in PENDING],
          "links": LINKS}


def window(days, start, end, season=None):
    w = {"weekdays": days, "start": start, "end": end}
    if season:
        w["season"] = season
    return w


def day(m, d, m2=None, d2=None):
    return {"fromMonth": m, "fromDay": d, "toMonth": m2 or m, "toDay": d2 or d}


# Quando la ZTL vale (chi non è autorizzato non entra): sempre, tranne i feriali 5:30–9:30 (giovedì e giorni di fiera 5:30–8:30)
WINDOWS = [
    window(SUN, 0, 1440),
    window(MON_SAT_NO_THU, 0, 330), window(MON_SAT_NO_THU, 570, 1440),
    window(THU, 0, 330), window(THU, 510, 1440),
    # giorni di fiera: la fascia libera finisce alle 8:30
    window(MON_SAT, 510, 570, day(1, 31)), window(MON_SAT, 510, 570, day(3, 12)), window(MON_SAT, 510, 570, day(8, 29)),
    window([2], 510, 570, day(8, 2, 8, 8)),     # il lunedì dopo la prima domenica di agosto cade tra il 2 e l'8
]

SUMMARY = ("The whole walled town (UNESCO site) is a ZTL with 6 camera gates. Closed to unauthorised cars all day on Sundays and holidays, and on "
           "Monday–Saturday except 5:30–9:30 am (Thursdays, market day, until 8:30). Park outside the walls (P1 Giubileo, P2 Montemaggio, P3/P4 Bagnaia) and walk. "
           "If your hotel is inside, it must register your plate on the Local Police portal beforehand: guests may then drive in from 3 to 8 pm to stop (not park) "
           "in the side streets, Via del Castello and Piazza della Cisterna; at night (8 pm–5:30 am) the hotel can register you within 24 hours. "
           "Disabled badge holders: plate to be registered within 48 hours. Campers and coaches are banned; speed limit 30 km/h.")
SUMMARY_IT = ("Tutto il borgo dentro le mura (sito UNESCO) è ZTL, con 6 varchi videocontrollati. Chiusa ai veicoli non autorizzati tutto il giorno la domenica e "
              "nei festivi, e dal lunedì al sabato tranne dalle 5:30 alle 9:30 (il giovedì, giorno di mercato, fino alle 8:30). Parcheggia fuori dalle mura "
              "(P1 Giubileo, P2 Montemaggio, P3/P4 Bagnaia) e prosegui a piedi. Se l'hotel è dentro, deve registrare prima la tua targa sul portale della Polizia "
              "Locale: così dalle 15 alle 20 puoi entrare per una fermata (non sosta) nelle vie secondarie, in via del Castello e in piazza della Cisterna; di notte "
              "(20–5:30) l'hotel può registrarti entro 24 ore. Contrassegno disabili: targa da registrare entro 48 ore. Vietato a camper e autobus; limite 30 km/h.")
SUMMARY_DE = ("Die ganze ummauerte Stadt (UNESCO-Welterbe) ist ZTL mit 6 Kameras. Für nicht berechtigte Fahrzeuge gesperrt: sonntags und an Feiertagen ganztägig, "
              "Montag bis Samstag außer 5:30–9:30 Uhr (donnerstags, am Markttag, bis 8:30). Parke außerhalb der Mauern (P1 Giubileo, P2 Montemaggio, P3/P4 Bagnaia) "
              "und geh zu Fuß. Liegt dein Hotel innen, muss es dein Kennzeichen vorher im Portal der Ortspolizei melden: Dann darfst du von 15 bis 20 Uhr zum Halten "
              "(nicht Parken) in die Nebenstraßen, die Via del Castello und die Piazza della Cisterna; nachts (20–5:30 Uhr) kann das Hotel dich binnen 24 Stunden melden. "
              "Behindertenausweis: Kennzeichen binnen 48 Stunden melden. Wohnmobile und Busse verboten; Tempo 30.")

GATE_NAMES = {
    1: ("Porta San Giovanni (entry only)", "Porta San Giovanni (solo entrata)", "Porta San Giovanni (nur Einfahrt)"),
    2: ("Via Bonda / Piandornella (entry and exit)", "Via Bonda / Piandornella (entrata e uscita)", "Via Bonda / Piandornella (Ein- und Ausfahrt)"),
    3: ("Via Santa Caterina (exit only)", "Via Santa Caterina (solo uscita)", "Via Santa Caterina (nur Ausfahrt)"),
    4: ("Via di Quercecchio (entry only)", "Via di Quercecchio (solo entrata)", "Via di Quercecchio (nur Einfahrt)"),
    5: ("Porta San Matteo (exit only)", "Porta San Matteo (solo uscita)", "Porta San Matteo (nur Ausfahrt)"),
    6: ("Via di Bagnaia (entry and exit)", "Via di Bagnaia (entrata e uscita)", "Via di Bagnaia (Ein- und Ausfahrt)"),
}

mappa = json.loads((RAW / "ztl-mappa-ufficiale.json").read_text(encoding="utf-8"))
ring = [tuple(p) for p in mappa["perimeter"]]
gates = [{"id": f"sgm-varco-{g['number']}", "name": f"{g['number']} · {GATE_NAMES[g['number']][0]}",
          "location": {"lat": round(g["lat"], 6), "lon": round(g["lon"], 6)}} for g in mappa["gates"]]

zone = {"id": "sgm-ztl", "name": "Walled town · Historic Centre ZTL", "name_it": "Borgo murato · ZTL Centro storico",
        "name_de": "Ummauerte Altstadt · ZTL Centro storico", "kind": "restricted",
        "summary": SUMMARY, "summary_it": SUMMARY_IT, "summary_de": SUMMARY_DE,
        "perimeter": osm_geo.perimeter(ring, tol_m=1.5), "gates": gates, "windows": WINDOWS,
        "freeOnHolidays": False, "holidaysAsSunday": True, "exemptFuels": [], "hotelCanRegister": True, "source": source}

city = {"id": "san-gimignano", "name": "San Gimignano", "name_it": "San Gimignano", "name_de": "San Gimignano",
        "center": {"lat": 43.4677, "lon": 11.0432}, "zones": [zone], "status": "draft",
        "license": "Rules: Comune di San Gimignano official documents. Perimeter and gates: traced automatically from the city's official ZTL map, "
                   "aligned to OpenStreetMap buildings (" + osm_geo.ODBL + "); approximate, not official coordinates."}

# --- controlli ---
per = zone["perimeter"]
osm = {e.get("tags", {}).get("name"): e for e in osm_geo.load("san-gimignano-osm")}


def centre(name):
    e = osm[name]
    g = e.get("geometry") or [e]
    return sum(p["lat"] for p in g) / len(g), sum(p["lon"] for p in g) / len(g)


inside = {"Piazza della Cisterna": centre("Piazza della Cisterna"), "Piazza della Cisterna (brief)": (43.4677, 11.0432),
          "Via San Matteo": centre("Via San Matteo"), "Piazza Sant'Agostino": centre("Piazza Sant'Agostino")}
outside = {n: centre(n) for n in ["P1 - Parcheggio Giubileo", "P2 - Parcheggio Montemaggio", "P3 - Parcheggio Bagnaia Superiore",
                                  "P4 - Parcheggio Bagnaia Inferiore"]}
for n, (lat, lon) in inside.items():
    assert osm_geo.contains(per, lat, lon), f"{n} fuori dalla ZTL"
for n, (lat, lon) in outside.items():
    assert not osm_geo.contains(per, lat, lon), f"{n} dentro la ZTL"
# ogni varco della mappa è vicino al bordo e alla porta OSM omonima
for g in gates:
    d = osm_geo.distance_m(per, g["location"]["lat"], g["location"]["lon"])
    assert d < 15, (g["name"], d)
for n, gate in [(1, "Porta San Giovanni"), (5, "Porta San Matteo"), (4, "Porta Quercecchio")]:
    lat, lon = centre(gate)
    g = gates[n - 1]["location"]
    dd = osm_geo.distance_m([{"lat": g["lat"], "lon": g["lon"]}] * 2, lat, lon)
    assert dd < 25, (gate, dd)
area = osm_geo.area_km2(per)
assert 0.15 < area < 0.30, area

out = ROOT / "Resources/Cities/san-gimignano.json"
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.name, len(per), "punti,", len(gates), "varchi,", f"{area:.3f} km²",
      {n: round(osm_geo.distance_m(per, *p)) for n, p in outside.items()})
