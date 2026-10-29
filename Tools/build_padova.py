#!/usr/bin/env python3
# Costruisce Resources/Cities/padova.json dalle pagine e dagli atti ufficiali del Comune di Padova
# salvati in data/raw/padova/ (fonti e date in docs/fonti-padova.md).
#
# Il sito del Comune (comune.padova.it, ex padovanet.it) è un'app Angular: il testo delle pagine si legge
# dall'API JSON del sito (https://www.comune.padova.it/api/informations/<id>?include=information_partials),
# salvata così com'è in data/raw/padova/*.json. Gli atti (ordinanze, disciplinare, tariffe) sono PDF:
# in data/raw/padova/*.txt c'è il testo estratto con pdftotext.
#
# Zone:
# - Zona A e Zona B della ZTL (ordinanza 2023/62/0437). Il Comune non pubblica dati aperti sulla ZTL: la mappa
#   ufficiale è un PDF senza coordinate. Zona A = contorno della relazione OSM «ZTL Zona A e B» (data/raw/geo/padova-ztl.json,
#   © OpenStreetMap contributors, ODbL 1.0), che contiene anche la Zona B. Zona B = l'area coperta dalle vie dell'elenco
#   ufficiale (Allegato 1), con le geometrie delle strade OSM di data/raw/padova/osm-strade-centro.json
#   (Tools/fetch_padova_streets.py). Varchi e telecamere: nodi «device» delle relazioni enforcement di OSM.
# - Limitazioni antismog 2026/2027 (ordinanza del Sindaco n. 46/2026): tutto il territorio comunale,
#   confine ISTAT 2026 (openpolis/geojson-italy, CC BY) in data/raw/padova/confine-comunale-padova.geojson.
# - Domeniche ecologiche 2026/2027 (ordinanza del Sindaco n. 47/2026): dentro le mura del Cinquecento,
#   perimetro dalle mura in OpenStreetMap (data/raw/geo/padova-walls.json).
# Una zona senza perimetro non esce; se nessuna ha il perimetro, la città va in data/drafts/.
# Non aggiorna manifest.json. Uso: python3 Tools/build_padova.py
import html, json, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/padova"
CHECKED = "2026-10-25T08:00:00Z"
MON_SAT, SUN, MON_FRI, EVERY_DAY = [2, 3, 4, 5, 6, 7], [1], [2, 3, 4, 5, 6], [1, 2, 3, 4, 5, 6, 7]

SITE = "https://www.comune.padova.it"
ZTL_PAGE = SITE + "/zona-traffico-limitato-ztl-centro-storico"
ZTL_ORD = SITE + "/sites/default/files/attachment/ZTL.pdf"
PED_ORD = SITE + "/sites/default/files/attachment/AreePedonali_0.pdf"
MAP_PDF = SITE + "/sites/default/files/attachment/2023-08-31_ZTL_PadovaNet_Volantino%20A3.pdf"
TEMP_PAGE = SITE + "/titolo-autorizzatorio-temporaneo-ztl-ex-contrassegno"
RULES_PDF = SITE + "/sites/default/files/attachment/Allegato%20A%20Disciplinare%20.pdf"
TARIFFS_PDF = SITE + "/sites/default/files/attachment/Allegato%20B_3.pdf"
FINES_PAGE = SITE + "/multe-e-ricorsi-transiti-abusivi-nella-ztl"
HOTEL_PORTAL = "https://istanzeonline.comune.padova.it/iol_public/ztl/regolarizzazioni-esercenti/transiti-veicoli-clienti-di-strutture-ricettive-con-sede-interna-alla-ztl-regolarizzazione-entro-48-ore"
SMOG_PAGE = SITE + "/limitazioni-del-traffico-stagione-invernale-20262027"
SMOG_ORD = SITE + "/sites/default/files/2026-09/ordinanza_2026_46_firm_dig.pdf"
ECO_PAGE = SITE + "/novita/notizie/domenica-ecologica-del-4-ottobre-2026"
ECO_ORD = SITE + "/sites/default/files/2026-09/ordinanza_2026_47_firm_dig.pdf"
ISTAT_URL = "https://raw.githubusercontent.com/openpolis/geojson-italy/master/geojson/limits_P_28_municipalities.geojson"


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


def source(page, quote, translation, links, pending, ordinance=None, ordinance_url=None):
    """translation e pending: (inglese, tedesco) e (inglese, italiano, tedesco), come in build_siena.py"""
    return {"authority": "City of Padua", "pageURL": page, "ordinance": ordinance, "ordinanceURL": ordinance_url,
            "quote": quote, "quoteTranslation": translation[0], "quoteTranslation_de": translation[1],
            "checkedOn": CHECKED, "reviewedByHuman": False,
            "pending": [p[0] for p in pending], "pending_it": [p[1] for p in pending], "pending_de": [p[2] for p in pending],
            "links": links}


def flat(text):
    return re.sub(r"\s+", " ", text).strip()


def api_text(name):
    """Tutto il testo di una pagina salvata dall'API del sito (stringhe JSON senza tag HTML)"""
    out = []
    def walk(o):
        if isinstance(o, dict):
            for k, v in o.items():
                if k not in ("processed", "summary", "links"):
                    walk(v)
        elif isinstance(o, list):
            for v in o:
                walk(v)
        elif isinstance(o, str):
            out.append(html.unescape(re.sub(r"<[^>]+>", " ", o)))
    walk(json.loads((RAW / f"{name}.json").read_text(encoding="utf-8")))
    return flat(" ".join(out))


def pdf_text(name):
    return flat((RAW / f"{name}.txt").read_text(encoding="utf-8"))


def must_contain(text, quote, where):
    """Ogni frase citata o riassunta deve esserci davvero nel documento salvato"""
    if flat(quote) not in text:
        raise SystemExit(f"Citazione non trovata in {where}: {quote!r}")


def window(days, start, end, season=None):
    w = {"weekdays": days, "start": start, "end": end}
    if season:
        w["season"] = season
    return w


def day(m, d):
    return {"fromMonth": m, "fromDay": d, "toMonth": m, "toDay": d}


# --- Le frasi su cui si basa la scheda, controllate contro i file in data/raw/padova/ ---
ztl_ord = pdf_text("ordinanza_2023-62-0437_ztl")
QUOTE_A = "ZONA “A”: giorni feriali 8:00 – 23:30; festivi: 14:00 – 23:30"
QUOTE_B = "ZONA “B”: giorni feriali e festivi 00:00 – 24:00"
for q in ["Ordinanza n. 2023/62/0437 del 23/05/2023", QUOTE_A, QUOTE_B,
          "La circolazione all’interno di tale area è consentita esclusivamente ai velocipedi, ciclomotori, motoveicoli a due e tre ruote, nonché ai veicoli autorizzati",
          "veicoli ad esclusiva trazione elettrica",
          "anche a posteriori entro le 48 (quarantotto) ore successive al transito",
          "veicoli al servizio di persone con disabilità di cui all’art. 188 del C.d.S.",
          "STRUTTURE RICETTIVE (Alberghi, Hotel, B&B, ecc.) CON SEDE IN ZONA A TRAFFICO LIMITATO",
          "il passaggio non autorizzato rilevato ad uno dei varchi in uscita dalla ZTL costituisca ulteriore infrazione solo se avvenga in giornate successive",
          "CARICO SCARICO ZONA “A” e “ZONA B” : 5:00 – 11:00, 15:00 – 17:00"]:
    must_contain(ztl_ord, q, "ordinanza 2023/62/0437")
ztl_page = api_text("ztl-centro-storico")
for q in ["ZONA A vedere mappa sotto allegata, con divieto di circolazione nei giorni feriali dalle ore 8:00 alle 23:30 e nei giorni festivi dalle ore 14:00 alle 23:30",
          "ZONA B vedere mappa sotto allegata, con divieto di circolazione tutti i giorni 24 ore su 24",
          "1 LARGO EUROPA tutti i giorni sia feriali che festivi, dalle 00:00 alle 24:00",
          "2 VIA BUSONERA tutti i giorni sia feriali che festivi, dalle 00:00 alle 24:00",
          "3 VIA DEL SANTO giorni feriali dalle 8:00 alle 23:30 e nei giorni festivi dalle 14:00 alle 23:30",
          "Questi ultimi devono comunicare la targa via email a zonablu@comune.padova.it",
          "permessi temporanei Ztl per un massimo di 2 ore (no autocarri)"]:
    must_contain(ztl_page, q, "pagina Ztl in centro storico")
temp = api_text("titolo-temporaneo-ztl")
for q in ["i gestori delle strutture possono regolarizzare, entro le 48 ore successive al passaggio attraverso i varchi, i transiti effettuati dalle auto dei clienti",
          "è necessario accedere tramite SPID o CIE",
          "clienti di autorimesse, autofficine, strutture ricettive e pubblici esercizi site all'interno della Ztl o aree pedonali"]:
    must_contain(temp, q, "pagina Titolo autorizzatorio temporaneo")
rules = pdf_text("disciplinare_GC_239_2023_allegato_A")
for q in ["Ogni garage ad uso pubblico, autofficina e struttura ricettiva provvede a dichiarare entro le 48 ore dal transito",
          "Le registrazioni tramite portale sono da effettuarsi per ogni giorno di transito.",
          "Senza la dichiarazione, il transito dei clienti in ZTL risulta abusivo."]:
    must_contain(rules, q, "disciplinare (Allegato A GC 239/2023)")
tariffs = pdf_text("tariffe_GC_239_2023_allegato_B")
for q in ["Pass temporaneo fino a due ore Euro 5,00", "Temporaneo fino a 48 ore Euro 15.00"]:
    must_contain(tariffs, q, "tariffe (Allegato B GC 239/2023)")
fines = api_text("multe-ricorsi-ztl")
must_contain(fines, "è prevista la sanzione di 80 euro più spese procedurali e di notifica", "pagina Multe Ztl")
smog_ord = pdf_text("ordinanza_sindaco_2026_46_limitazioni_traffico")
QUOTE_SMOG = "livello nessuna allerta – colore verde: dal lunedì al venerdì, esclusi i giorni festivi infrasettimanali, dalle ore 8.30 alle ore 19.30"
for q in ["N. 46 DEL 29/09/2026", QUOTE_SMOG,
          "dall’01/10/2026 all’11/12/2026 e dal 07/01/2027 al 30/04/2027",
          "alimentati a benzina e omologati ai sensi delle direttive rispondenti alle diciture EURO 0, EURO 1;",
          "alimentati a gasolio e omologati ai sensi delle direttive rispondenti alle diciture EURO 0, EURO 1, EURO 2, EURO 3, EURO 4;",
          "gasolio/GPL, gasolio/metano e omologati ai sensi delle direttive rispondenti alle diciture EURO 0, EURO 1;",
          "veicoli provvisti di motori elettrici o ibridi (motore termico/elettrico)",
          "anello delle tangenziali"]:
    must_contain(smog_ord, q, "ordinanza del Sindaco 46/2026")
smog_page = api_text("limitazioni-2026-2027")
for q in ["sanzione amministrativa pari ad euro 168,00", "differito al 1° ottobre 2027"]:
    must_contain(smog_page, q, "pagina Limitazioni del traffico 2026/2027")
eco_ord = pdf_text("ordinanza_sindaco_2026_47_domeniche_ecologiche")
QUOTE_ECO = "nella fascia oraria 8.30 - 18.30, nelle domeniche: 04/10/2026, 08/11/2026, 06/12/2026, 24/01/2027, 28/02/2027, 14/03/2027, 18/04/2027"
for q in [QUOTE_ECO, "veicoli provvisti di motore esclusivamente elettrico",
          "veicoli in uso agli ospiti di strutture ricettive situate nell’area interdetta, limitatamente al percorso necessario all’andata e al ritorno dagli stessi, il giorno dell’arrivo e della partenza, in possesso della copia della prenotazione",
          "barriera Saracinesca, via Cernaia, porta San Giovanni"]:
    must_contain(eco_ord, q, "ordinanza del Sindaco 47/2026")
eco_page = api_text("domenica-ecologica-2026-10-04")
must_contain(eco_page, "all'interno delle mura del '500", "pagina Domenica ecologica 4 ottobre 2026")
must_contain(eco_page, "è prevista una sanzione di 87 euro", "pagina Domenica ecologica 4 ottobre 2026")


# --- Link comuni ---
ZTL_LINKS = [
    link("City of Padua: ZTL in the historic centre (map, hours, gates)", "Comune di Padova: Ztl in centro storico (mappa, orari, varchi)",
         "Stadt Padua: ZTL in der Altstadt (Karte, Zeiten, Kameras)", ZTL_PAGE),
    link("City of Padua: ZTL ordinance 2023/62/0437 (PDF)", "Comune di Padova: ordinanza Ztl 2023/62/0437 (PDF)",
         "Stadt Padua: ZTL-Verordnung 2023/62/0437 (PDF)", ZTL_ORD),
    link("City of Padua: map of Zona A and Zona B with gates (PDF)", "Comune di Padova: mappa Zona A e Zona B con varchi (PDF)",
         "Stadt Padua: Karte von Zona A und Zona B mit Kameras (PDF)", MAP_PDF),
    link("City of Padua: temporary ZTL permits and hotel registration", "Comune di Padova: titoli temporanei Ztl e regolarizzazione hotel",
         "Stadt Padua: befristete ZTL-Genehmigungen und Hotel-Meldung", TEMP_PAGE),
    link("City of Padua: ZTL permit rules (Annex A, Council decision 239/2023, PDF)", "Comune di Padova: disciplinare titoli Ztl (Allegato A, DGC 239/2023, PDF)",
         "Stadt Padua: Regeln für ZTL-Genehmigungen (Anlage A, Beschluss 239/2023, PDF)", RULES_PDF),
    link("City of Padua: ZTL fees (Annex B, PDF)", "Comune di Padova: tariffe Ztl (Allegato B, PDF)", "Stadt Padua: ZTL-Gebühren (Anlage B, PDF)", TARIFFS_PDF),
    link("City of Padua: ZTL fines and appeals", "Comune di Padova: multe e ricorsi Ztl", "Stadt Padua: ZTL-Bußgelder und Einsprüche", FINES_PAGE),
    link("City of Padua: pedestrian areas ordinance 2023/62/0464 (PDF)", "Comune di Padova: ordinanza aree pedonali 2023/62/0464 (PDF)",
         "Stadt Padua: Verordnung Fußgängerzonen 2023/62/0464 (PDF)", PED_ORD),
]
SMOG_LINKS = [
    link("City of Padua: winter traffic limits 2026/2027", "Comune di Padova: limitazioni del traffico 2026/2027",
         "Stadt Padua: Winter-Fahrverbote 2026/2027", SMOG_PAGE),
    link("City of Padua: Mayor's ordinance 46/2026 (PDF)", "Comune di Padova: ordinanza del Sindaco 46/2026 (PDF)",
         "Stadt Padua: Verordnung des Bürgermeisters 46/2026 (PDF)", SMOG_ORD),
    link("ARPAV: PM10 alert levels in Veneto", "ARPAV: livelli di allerta PM10 in Veneto", "ARPAV: PM10-Warnstufen in Venetien",
         "https://www.arpa.veneto.it/dati-ambientali/bollettini/aria/bollettino-livelli-di-allerta-pm10"),
    link("Italian Motorist Portal: check your car's Euro class", "Portale dell'Automobilista: verifica la classe Euro",
         "Italienisches Fahrerportal: Euro-Klasse prüfen", "https://www.ilportaledellautomobilista.it/web/portale-automobilista/ext/verifica-classe-ambientale-veicolo"),
    link("ISTAT municipal boundary (via openpolis/geojson-italy, CC BY)", "Confine comunale ISTAT (da openpolis/geojson-italy, CC BY)",
         "ISTAT-Gemeindegrenze (über openpolis/geojson-italy, CC BY)", ISTAT_URL),
]
ECO_LINKS = [
    link("City of Padua: car-free Sunday, 4 October 2026 (area and exemptions)", "Comune di Padova: domenica ecologica del 4 ottobre 2026 (area e deroghe)",
         "Stadt Padua: autofreier Sonntag, 4. Oktober 2026 (Gebiet und Ausnahmen)", ECO_PAGE),
    link("City of Padua: Mayor's ordinance 47/2026, car-free Sundays (PDF)", "Comune di Padova: ordinanza del Sindaco 47/2026, domeniche ecologiche (PDF)",
         "Stadt Padua: Verordnung 47/2026, autofreie Sonntage (PDF)", ECO_ORD),
]


# --- Le zone ---
ZTL_PENDING = [
    ("Perimeter from OpenStreetMap, to be checked against the official map (31/08/2023).",
     "Perimetro da OpenStreetMap, da verificare con la mappa ufficiale (31/08/2023).",
     "Grenze aus OpenStreetMap, mit der offiziellen Karte (31.08.2023) abzugleichen."),
    ("The hotel registers your plate for each day you drive in, at the latest 48 hours afterwards; it only covers loading and unloading (max 30 minutes' parking). Pedestrian areas need a separate temporary permit.",
     "L'hotel registra la targa per ogni giorno di transito, al più tardi entro 48 ore; vale solo per carico e scarico (sosta massima 30 minuti). Per le aree pedonali serve un titolo temporaneo a parte.",
     "Das Hotel meldet dein Kennzeichen für jeden Tag der Einfahrt, spätestens 48 Stunden danach; das gilt nur zum Be- und Entladen (höchstens 30 Minuten Parken). Für Fußgängerzonen braucht es eine eigene befristete Genehmigung."),
    ("Electric cars may enter only once their plate is registered with the city (email to zonablu@comune.padova.it, also up to 48 hours after entering): GateLR treats them like any other car.",
     "Le auto elettriche entrano solo con la targa registrata dal Comune (email a zonablu@comune.padova.it, anche entro 48 ore dal transito): GateLR le tratta come le altre auto.",
     "Elektroautos dürfen nur mit beim Amt gemeldetem Kennzeichen einfahren (E-Mail an zonablu@comune.padova.it, auch bis 48 Stunden danach): GateLR behandelt sie wie andere Autos."),
]
A_PENDING = []   # i festivi infrasettimanali seguono gli orari della domenica (holidaysAsSunday)
SUMMARY_A = ("Monday to Saturday 8 am–11:30 pm, Sundays and holidays 2 pm–11:30 pm: no entry without a permit (cameras also on the way out; €80 fine). Motorbikes and mopeds may enter. There is no day ticket for tourists. If your hotel is inside, it can register your plate within 48 hours, for loading and unloading only. Zona B, the squares around Palazzo della Ragione and the riverside streets, is closed around the clock.",
             "Dal lunedì al sabato 8:00–23:30, domenica e festivi 14:00–23:30: vietato entrare senza permesso (telecamere anche in uscita; multa 80 €). Moto e ciclomotori entrano. Non c'è un ticket per i turisti. Se l'hotel è dentro, può registrare la targa entro 48 ore, solo per carico e scarico. La Zona B, le piazze attorno al Palazzo della Ragione e le riviere, è chiusa 24 ore su 24.",
             "Montag bis Samstag 8–23:30 Uhr, sonntags und feiertags 14–23:30 Uhr: keine Einfahrt ohne Genehmigung (Kameras auch an der Ausfahrt; 80 € Bußgeld). Motorräder und Mofas dürfen hinein. Ein Tagesticket für Touristen gibt es nicht. Liegt dein Hotel innen, kann es dein Kennzeichen binnen 48 Stunden melden, nur zum Be- und Entladen. Die Zona B, die Plätze um den Palazzo della Ragione und die Uferstraßen, ist rund um die Uhr gesperrt.")
SUMMARY_B = ("Closed to unauthorised cars 24 hours a day, every day, holidays included (€80 fine). Motorbikes and mopeds may enter. There is no day ticket for tourists. If your hotel is inside, it can register your plate within 48 hours, for loading and unloading only. Many streets here are also pedestrian areas, closed even with a ZTL permit.",
             "Chiusa alle auto non autorizzate 24 ore su 24, tutti i giorni, festivi compresi (multa 80 €). Moto e ciclomotori entrano. Non c'è un ticket per i turisti. Se l'hotel è dentro, può registrare la targa entro 48 ore, solo per carico e scarico. Molte vie sono anche aree pedonali, chiuse pure a chi ha il permesso ZTL.",
             "Rund um die Uhr, täglich und auch an Feiertagen für nicht berechtigte Autos gesperrt (80 € Bußgeld). Motorräder und Mofas dürfen hinein. Ein Tagesticket für Touristen gibt es nicht. Liegt dein Hotel innen, kann es dein Kennzeichen binnen 48 Stunden melden, nur zum Be- und Entladen. Viele Straßen sind zudem Fußgängerzonen, gesperrt auch mit ZTL-Genehmigung.")
SUMMARY_SMOG = ("From 1 October to 11 December 2026 and from 7 January to 30 April 2027, Monday to Friday 8:30 am–7:30 pm (not on public holidays), the oldest cars can't drive anywhere in Padua: diesel up to Euro 4, petrol, LPG and methane up to Euro 1. Electric and hybrid cars are exempt. The ring roads and motorways are excluded. On PM10 alert days (orange or red) the ban is stricter and also applies at weekends. €168 fine.",
                "Dal 1° ottobre all'11 dicembre 2026 e dal 7 gennaio al 30 aprile 2027, dal lunedì al venerdì 8:30–19:30 (festivi esclusi), le auto più vecchie non possono circolare in tutto il comune: diesel fino a Euro 4, benzina, GPL e metano fino a Euro 1. Elettriche e ibride sono esenti. Tangenziali e autostrade sono escluse. Nei giorni di allerta PM10 (arancio o rosso) il divieto è più ampio e vale anche nel fine settimana. Multa 168 €.",
                "Vom 1. Oktober bis 11. Dezember 2026 und vom 7. Januar bis 30. April 2027, montags bis freitags 8:30–19:30 Uhr (nicht an Feiertagen), dürfen die ältesten Autos im ganzen Stadtgebiet nicht fahren: Diesel bis Euro 4, Benzin, Autogas und Erdgas bis Euro 1. Elektro- und Hybridautos sind ausgenommen. Ringstraßen und Autobahnen sind ausgenommen. An PM10-Alarmtagen (orange oder rot) ist das Verbot strenger und gilt auch am Wochenende. 168 € Bußgeld.")
SUMMARY_ECO = ("Car-free Sundays inside the 16th-century walls: 8 November and 6 December 2026, 24 January, 28 February, 14 March and 18 April 2027, 8:30 am–6:30 pm. Only fully electric cars may drive; petrol, diesel and hybrid cars may not. Hotel guests inside may drive to and from the hotel on the day they arrive or leave, carrying a copy of the booking. €87 fine.",
               "Domeniche ecologiche dentro le mura del Cinquecento: 8 novembre e 6 dicembre 2026, 24 gennaio, 28 febbraio, 14 marzo e 18 aprile 2027, 8:30–18:30. Circolano solo le auto totalmente elettriche; benzina, diesel e ibride no. Gli ospiti degli hotel dentro l'area possono andare e tornare dall'hotel il giorno dell'arrivo e della partenza, con la copia della prenotazione. Multa 87 €.",
               "Autofreie Sonntage innerhalb der Stadtmauern aus dem 16. Jahrhundert: 8. November und 6. Dezember 2026, 24. Januar, 28. Februar, 14. März und 18. April 2027, 8:30–18:30 Uhr. Nur reine Elektroautos dürfen fahren, Benziner, Diesel und Hybride nicht. Hotelgäste innerhalb dürfen am An- und Abreisetag zum Hotel und zurück fahren, mit einer Kopie der Buchung. 87 € Bußgeld.")


# --- Geometria ---
OSM_ZTL = 19152919   # relazione OSM «ZTL Zona A e B» (boundary=limited_traffic_zone, author Comune di Padova - Settore Mobilità)
# Zona B: le vie dell'Allegato 1 dell'ordinanza 437/2023 (Zona B), con i nomi di OpenStreetMap.
# (nome OSM, via di inizio, via di fine): solo il tratto tra le due vie indicate nell'elenco ufficiale.
ZONE_B_STREETS = [
    ("Via Altinate", "Piazza Giuseppe Garibaldi", "Riviera dei Ponti Romani"),
    ("Piazza Antenore",), ("Via Aquileia",),
    ("Via Cesare Battisti", "Via Otto Febbraio", "Via degli Zabarella"),
    ("Via Bartolomeo Bellano",), ("Via Belle Parti",), ("Via Boccalerie",), ("Via Vincenzo Stefano Breda",),
    ("Via Flavio Busonera",), ("Riviera del Businello",), ("Via Pietro Fortunato Calvi",), ("Via Cappelli",),
    ("Piazza Capitaniato",), ("Via dei Da Carrara",),
    ("Via Dante Alighieri", "Piazza dei Signori", "Via Giuseppe Verdi"),
    ("Via dei Fabbri",), ("Piazza dei Frutti",), ("Via del Municipio",), ("Via del Padovanino",),
    ("Via del Risorgimento",), ("Via dell'Arco",), ("Piazza delle Erbe",), ("Via delle Piazze",), ("Piazza dei Signori",),
    ("Via San Clemente",), ("Corte San Clemente",), ("Via Cavour",), ("Piazza Cavour",),
    ("Largo Europa",), ("Via Fiume",), ("Via Gorizia",), ("Via Andrea Gritti",), ("Via Antonio Locatelli",),
    ("Via Daniele Manin",), ("Via Marsala", "Via Rialto", "Via Roma"),
    ("Via Marsilio da Padova",), ("Via Martiri d'Ungheria",), ("Via Monte di Pietà",), ("Via Guglielmo Oberdan",),
    ("Via Otto Febbraio",), ("Piazzetta Giovanni Palatucci",), ("Piazzetta Cappellato Pedrocchi",), ("Via Pietro D'Abano",),
    ("Riviera dei Ponti Romani",), ("Via Rudena",), ("Riviera Ruzante",), ("Via Santa Chiara",), ("Via Pier Andrea Saccardo",),
    ("Via San Canziano",), ("Via San Francesco", "Via Roma", "Riviera Tito Livio"),
    ("Via San Martino e Solferino", "Via Giovanni Prati", "Via Roma"),
    ("Via San Nicolò",), ("Piazzetta San Nicolò",), ("Selciato San Nicolò",), ("Via Sant'Andrea",), ("Via Santa Lucia",),
    ("Via Nazario Sauro",), ("Via Francesco Squarcione",), ("Via Gaspara Stampa",), ("Riviera Tito Livio",),
]
# Varchi: i nodi «device» delle relazioni OSM «Accesso ZTL …», con il nome ufficiale (pagina Ztl del Comune, ordinanza 437/2023)
GATES_A = {897223392: "Ponte S. Gregorio Barbarigo", 897222500: "Via Vescovado", 790501211: "Riviera Mussato", 298468358: "Via del Santo"}
GATES_B = {897227594: "Largo Europa", 897227588: "Via Busonera", 897222391: "Riviera Businello (bus lane)"}
# Telecamere delle corsie riservate (nodi «device» delle relazioni enforcement=check di OSM)
BUS_CAMERAS = {1451949434: "Via Dante", 1452342450: "Via Emanuele Filiberto", 1452144210: "Riviera dei Ponti Romani"}


def ztl_ring():
    return osm_geo.outer_ring(osm_geo.relation(osm_geo.load("padova-ztl"), OSM_ZTL))


def clip(line, a, b):
    """Il tratto della via tra i punti a e b (proiezione sul segmento a–b, con 15 m di margine)"""
    fwd, _ = osm_geo._proj(a[1])
    (ax, ay), (bx, by) = fwd(*a), fwd(*b)
    L = ((bx - ax) ** 2 + (by - ay) ** 2) ** 0.5 or 1
    parts, cur = [], []
    for p in line:
        x, y = fwd(*p)
        t = ((x - ax) * (bx - ax) + (y - ay) * (by - ay)) / (L * L)
        if -15 / L <= t <= 1 + 15 / L:
            cur.append(p)
        else:
            if len(cur) >= 2: parts.append(cur)
            cur = []
    if len(cur) >= 2: parts.append(cur)
    return parts


def zone_b_ring(ring):
    ways = [e for e in json.loads((RAW / "osm-strade-centro.json").read_text(encoding="utf-8"))["elements"] if e["type"] == "way"]
    by_name = {}
    for w in ways:
        by_name.setdefault(w["tags"]["name"], []).append([(n["lon"], n["lat"]) for n in w["geometry"]])
    inside = lambda p: osm_geo.inside_lonlat(ring, *p) or osm_geo.distance_m(ring, p[1], p[0]) < 12
    def nearest(name, other):
        """Il punto della via «name» più vicino alla via «other» (l'incrocio)"""
        pts = [p for l in by_name[name] for p in l]
        opts = [p for l in by_name[other] for p in l]
        return min(pts, key=lambda p: min((p[0] - q[0]) ** 2 * 0.49 + (p[1] - q[1]) ** 2 for q in opts))
    lines = []
    for s in ZONE_B_STREETS:
        if s[0] not in by_name:
            raise SystemExit(f"Via della Zona B non trovata in OSM: {s[0]}")
        for l in by_name[s[0]]:
            for part in (clip(l, nearest(s[0], s[1]), nearest(s[0], s[2])) if len(s) == 3 else [l]):
                part = [p for p in part if inside(p)]
                if len(part) >= 2:
                    lines.append(part)
    rel = {"id": "zona-b", "members": [{"type": "way", "role": "section", "geometry": [{"lon": p[0], "lat": p[1]} for p in l]} for l in lines]}
    return osm_geo.street_area(rel, cell_m=6, close_m=45)


def walls_ring():
    """Il contorno delle mura del Cinquecento: per ogni settore di 3° attorno al centro, il punto delle mura
    in OSM più lontano dal centro (i tratti di mura sono spezzati, l'area dentro è «stellata» rispetto al centro)"""
    import math
    pts = [(n["lon"], n["lat"]) for e in osm_geo.load("padova-walls") if e["type"] == "way" for n in e["geometry"]]
    cx, cy = sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts)
    k = math.cos(math.radians(cy))
    best = {}
    for p in pts:
        dx, dy = (p[0] - cx) * k, p[1] - cy
        b = int(math.degrees(math.atan2(dy, dx)) // 3)
        if b not in best or dx * dx + dy * dy > best[b][0]:
            best[b] = (dx * dx + dy * dy, p)
    ring = [best[b][1] for b in sorted(best)]
    return ring + [ring[0]]


def comune_ring():
    g = json.loads((RAW / "confine-comunale-padova.geojson").read_text(encoding="utf-8"))["features"][0]["geometry"]
    polys = [g["coordinates"]] if g["type"] == "Polygon" else g["coordinates"]
    return [tuple(p) for p in max((p[0] for p in polys), key=len)]


def gate_list(prefix, names):
    nodes = {}
    for e in osm_geo.load("padova-gates"):
        for m in e.get("members", []):
            if m["type"] == "node" and m["ref"] in names:
                nodes[m["ref"]] = (m["lat"], m["lon"])
    missing = set(names) - set(nodes)
    if missing:
        raise SystemExit(f"Varchi OSM non trovati: {missing}")
    return [{"id": f"{prefix}-osm{i}", "name": names[i], "location": {"lat": round(nodes[i][0], 6), "lon": round(nodes[i][1], 6)}}
            for i in names]


ring_ztl = ztl_ring()
ring_b = zone_b_ring(ring_ztl)
OSM_LINK = link(f"OpenStreetMap: relation {OSM_ZTL} «ZTL Zona A e B» (ODbL)", f"OpenStreetMap: relazione {OSM_ZTL} «ZTL Zona A e B» (ODbL)",
                f"OpenStreetMap: Relation {OSM_ZTL} «ZTL Zona A e B» (ODbL)", osm_geo.osm_url("relation", OSM_ZTL))
B_PENDING = [("Zona B outline computed from the official street list (Annex 1 of ordinance 437/2023) on OpenStreetMap streets: approximate, to be checked against the official map.",
              "Contorno della Zona B ricavato dall'elenco ufficiale delle vie (Allegato 1 dell'ordinanza 437/2023) sulle strade di OpenStreetMap: approssimato, da verificare con la mappa ufficiale.",
              "Umriss der Zona B aus der offiziellen Straßenliste (Anlage 1 der Verordnung 437/2023) auf OpenStreetMap-Straßen berechnet: ungefähr, mit der offiziellen Karte abzugleichen.")]

zone_a = {"id": "padova-a", "name": "Zona A · Historic Centre", "name_it": "Zona A · Centro storico", "name_de": "Zona A · Altstadt",
          "kind": "restricted", "summary": SUMMARY_A[0], "summary_it": SUMMARY_A[1], "summary_de": SUMMARY_A[2],
          "perimeter": osm_geo.perimeter(ring_ztl, tol_m=4), "gates": gate_list("pd-a", GATES_A),
          "windows": [window(MON_SAT, 8 * 60, 23 * 60 + 30), window(SUN, 14 * 60, 23 * 60 + 30)],
          # «…consentita esclusivamente ai velocipedi, ciclomotori, motoveicoli a due e tre ruote…» (ordinanza 2023/62/0437)
          "freeOnHolidays": False, "holidaysAsSunday": True, "exemptFuels": [], "exemptVehicleTypes": ["motorcycle"], "hotelCanRegister": True,
          "source": source(ZTL_PAGE, QUOTE_A, ("ZONE A: working days 8:00–23:30; holidays: 14:00–23:30",
                                               "ZONE A: Werktage 8:00–23:30; Feiertage: 14:00–23:30"),
                           ZTL_LINKS + [OSM_LINK], ZTL_PENDING + A_PENDING,
                           "Ordinanza n. 2023/62/0437 del 23/05/2023 (Disciplina della ZTL del centro storico)", ZTL_ORD)}
zone_b = {"id": "padova-b", "name": "Zona B · Squares and Riverside", "name_it": "Zona B · Piazze e Riviere", "name_de": "Zona B · Plätze und Uferstraßen",
          "kind": "restricted", "summary": SUMMARY_B[0], "summary_it": SUMMARY_B[1], "summary_de": SUMMARY_B[2],
          "perimeter": osm_geo.perimeter(ring_b, tol_m=4), "gates": gate_list("pd-b", GATES_B),
          "windows": [window(EVERY_DAY, 0, 24 * 60)],
          "freeOnHolidays": False, "exemptFuels": [], "exemptVehicleTypes": ["motorcycle"], "hotelCanRegister": True,
          "source": source(ZTL_PAGE, QUOTE_B, ("ZONE B: working days and holidays 00:00–24:00",
                                               "ZONE B: Werktage und Feiertage 00:00–24:00"),
                           ZTL_LINKS + [OSM_LINK], B_PENDING + ZTL_PENDING,
                           "Ordinanza n. 2023/62/0437 del 23/05/2023 (Disciplina della ZTL del centro storico)", ZTL_ORD)}
SMOG_SEASONS = [{"fromMonth": 10, "fromDay": 1, "toMonth": 12, "toDay": 11}, {"fromMonth": 1, "fromDay": 7, "toMonth": 4, "toDay": 30}]
zone_smog = {"id": "padova-antismog", "name": "Padua · Winter smog limits", "name_it": "Padova · Limitazioni antismog invernali",
             "name_de": "Padua · Winter-Fahrverbote gegen Smog",
             "kind": "green", "summary": SUMMARY_SMOG[0], "summary_it": SUMMARY_SMOG[1], "summary_de": SUMMARY_SMOG[2],
             "perimeter": osm_geo.perimeter(comune_ring(), tol_m=20), "gates": [],
             "windows": [window(MON_FRI, 8 * 60 + 30, 19 * 60 + 30, s) for s in SMOG_SEASONS],
             "freeOnHolidays": True, "exemptFuels": ["electric", "hybrid"], "hotelCanRegister": False,
             "bans": [{"fuel": "petrol", "maxEuro": 1, "since": "2026-10-01"}, {"fuel": "lpg", "maxEuro": 1, "since": "2026-10-01"},
                      {"fuel": "diesel", "maxEuro": 4, "since": "2026-10-01"}],
             # Moto e scooter (categoria L): ordinanza 46/2026, livello verde, lettera d) «non omologati ai sensi delle
             # direttive rispondenti alla dicitura EURO 1 e successive» = Euro 0 (MotoBan nell'app, 1.17.2)
             "motoBans": [{"maxEuro": 0, "since": "2026-10-01"}],
             "source": source(SMOG_PAGE, QUOTE_SMOG,
                              ("no alert level – green: Monday to Friday, excluding public holidays on weekdays, from 8:30 am to 7:30 pm",
                               "keine Warnstufe – grün: Montag bis Freitag, ausgenommen Feiertage unter der Woche, von 8:30 bis 19:30 Uhr"),
                              SMOG_LINKS,
                              [("On PM10 alert days (orange or red, announced by ARPAV on Monday, Wednesday and Friday) the ban also covers diesel Euro 5 and petrol/LPG/methane Euro 2, every day including holidays and also 12 December–6 January: GateLR doesn't know the alert level, check the city's page.",
                                "Nei giorni di allerta PM10 (arancio o rosso, comunicati da ARPAV lunedì, mercoledì e venerdì) il divieto vale anche per diesel Euro 5 e benzina/GPL/metano Euro 2, tutti i giorni festivi compresi e anche dal 12 dicembre al 6 gennaio: GateLR non conosce il livello di allerta, guarda la pagina del Comune.",
                                "An PM10-Alarmtagen (orange oder rot, von ARPAV montags, mittwochs und freitags angekündigt) gilt das Verbot auch für Diesel Euro 5 und Benzin/Autogas/Erdgas Euro 2, täglich auch an Feiertagen und auch vom 12. Dezember bis 6. Januar: GateLR kennt die Warnstufe nicht, siehe Seite der Stadt."),
                               ("The ring roads, motorways, industrial area and some park-and-ride access roads are excluded, but the map shows the whole municipality (ISTAT boundary).",
                                "Tangenziali, autostrade, zona industriale e alcune vie d'accesso ai parcheggi scambiatori sono escluse, ma la mappa mostra tutto il territorio comunale (confine ISTAT).",
                                "Ringstraßen, Autobahnen, Industriegebiet und einige Zufahrten zu Park-and-Ride-Plätzen sind ausgenommen, die Karte zeigt aber das ganze Gemeindegebiet (ISTAT-Grenze)."),
                               ("Dates are for the 2026/2027 season only; diesel Euro 5 is postponed to 1 October 2027.",
                                "Le date valgono solo per la stagione 2026/2027; il divieto per i diesel Euro 5 è rinviato al 1° ottobre 2027.",
                                "Die Daten gelten nur für die Saison 2026/2027; Diesel Euro 5 ist auf den 1. Oktober 2027 verschoben.")],
                              "Ordinanza del Sindaco n. 46 del 29/09/2026", SMOG_ORD)}
ECO_DAYS = [(11, 8), (12, 6), (1, 24), (2, 28), (3, 14), (4, 18)]   # 04/10/2026 è già passata
zone_eco = {"id": "padova-domeniche-ecologiche", "name": "Car-free Sundays · Inside the walls", "name_it": "Domeniche ecologiche · Dentro le mura",
            "name_de": "Autofreie Sonntage · Innerhalb der Mauern",
            "kind": "restricted", "summary": SUMMARY_ECO[0], "summary_it": SUMMARY_ECO[1], "summary_de": SUMMARY_ECO[2],
            "perimeter": osm_geo.perimeter(walls_ring(), tol_m=15), "gates": [],
            "windows": [window(SUN, 8 * 60 + 30, 18 * 60 + 30, day(m, d)) for m, d in ECO_DAYS],
            "freeOnHolidays": False, "exemptFuels": ["electric"], "hotelCanRegister": False,
            "source": source(ECO_PAGE, QUOTE_ECO,
                             ("from 8:30 am to 6:30 pm on the Sundays 04/10/2026, 08/11/2026, 06/12/2026, 24/01/2027, 28/02/2027, 14/03/2027, 18/04/2027",
                              "von 8:30 bis 18:30 Uhr an den Sonntagen 04.10.2026, 08.11.2026, 06.12.2026, 24.01.2027, 28.02.2027, 14.03.2027, 18.04.2027"),
                             ECO_LINKS,
                             [("Outline from the 16th-century walls in OpenStreetMap: the official boundary is the ring of streets just outside the walls (excluded from the ban), as are the roads through Prato della Valle and to the Rabin car park.",
                               "Contorno dalle mura del Cinquecento in OpenStreetMap: il confine ufficiale è l'anello di vie appena fuori dalle mura (escluse dal divieto), come le vie che attraversano Prato della Valle e quella per il parcheggio Rabin.",
                               "Umriss aus der Stadtmauer des 16. Jahrhunderts in OpenStreetMap: die offizielle Grenze ist der Straßenring direkt außerhalb der Mauern (vom Verbot ausgenommen), ebenso die Straßen durch Prato della Valle und zum Parkplatz Rabin."),
                              ("Residents and hotel guests (arrival and departure day, with the booking) may drive with a self-declaration; GateLR doesn't check this. Dates valid for 2026/2027 only.",
                               "Residenti e ospiti degli hotel (giorno di arrivo e di partenza, con la prenotazione) circolano con un'autodichiarazione; GateLR non lo verifica. Date valide solo per il 2026/2027.",
                               "Anwohner und Hotelgäste (An- und Abreisetag, mit Buchung) dürfen mit einer Eigenerklärung fahren; GateLR prüft das nicht. Daten nur für 2026/2027.")],
                             "Ordinanza del Sindaco n. 47/2026 (domeniche ecologiche 2026/2027)", ECO_ORD)}

cameras = [{"id": g["id"].replace("pd-cam", "pd-bus"), "name": g["name"], "location": g["location"], "kind": "bus"}
           for g in gate_list("pd-cam", BUS_CAMERAS)]
city = {"id": "padova", "name": "Padua", "name_it": "Padova", "name_de": "Padua",
        "center": {"lat": 45.4077, "lon": 11.8735}, "zones": [zone_b, zone_a, zone_eco, zone_smog], "cameras": cameras,
        "status": "draft",
        "license": "Rules: Comune di Padova official pages and documents. ZTL perimeters, gates, cameras and walls: "
                   + osm_geo.ODBL + " (approximate, not official). Municipal boundary: ISTAT 2026 via openpolis/geojson-italy (CC BY)."}

ready = all(len(z["perimeter"]) >= 4 for z in city["zones"])
out = ROOT / ("Resources/Cities/padova.json" if ready else "data/drafts/padova.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/padova.json" if ready else "Resources/Cities/padova.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.name, [(z["id"], len(z["perimeter"]), len(z["gates"]), round(osm_geo.area_km2(z["perimeter"]), 3)) for z in city["zones"]])
