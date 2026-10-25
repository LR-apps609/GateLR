#!/usr/bin/env python3
# Costruisce Resources/Cities/napoli.json dalle pagine ufficiali del Comune di Napoli
# (www.comune.napoli.it, «ZTL e Aree Pedonali») salvate come testo in data/raw/napoli/ (fonti e date in docs/fonti-napoli.md).
# Ogni frase citata viene ricontrollata parola per parola sui testi salvati: se il Comune cambia la pagina, lo script si ferma.
#
# PDF del Comune (static-www.comune.napoli.it, raggiungibile dal 25/10/2026) salvati con il testo in data/raw/napoli/:
# disciplinare dei contrassegni (D.G.C. 1205/2011), moduli 2026 per alberghi (006) e aree private (010), O.D. 716 e 1219/2026
# (via Ferdinando Russo), O.S. 604/2012 (veicoli elettrici), D.G.C. 867/2014 (Centro Antico).
#
# Geometria: il Comune non pubblica perimetri o varchi in dati aperti (le mappe sono PDF di immagini). Se qualcuno salva un perimetro verificato in data/raw/napoli/perimetri.geojson
# (un poligono per zona, proprietà "gatelr_id" = id della zona) lo script usa quello.
# Altrimenti usa OpenStreetMap (data/raw/geo/napoli-ztl.json e napoli-gates.json, scaricati da Tools/fetch_geo.py,
# © OpenStreetMap contributors, ODbL 1.0): una relazione per zona (OSM_ZONES). Una zona senza perimetro non esce.
#
# Uso: python3 Tools/build_napoli.py   (scrive solo napoli.json: non tocca le altre città né manifest.json)
import json, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/napoli"
CHECKED = "2026-10-25T09:00:00Z"
AUTHORITY = "City of Naples"

ALL = [1, 2, 3, 4, 5, 6, 7]
MON_THU, FRI_SUN, SAT_SUN = [2, 3, 4, 5], [6, 7, 1], [1, 7]

BASE = "https://www.comune.napoli.it/articolo_tematico/trasporti-mobilita/ztl-e-aree-pedonali/"
INDEX = BASE
CENTRO = BASE + "ztl-del-centro-antico/"
CENTRO_AREA = BASE + "ztl-del-centro-antico/centro-antico/"
MEZZO = BASE + "ztl-del-centro-antico/mezzocannone/"
TARSIA = BASE + "ztl-tarsia-pignasecca-dante/"
BELLE = BASE + "ztl-belledonne-martiri-poerio-e-contrassegni-per-laccesso/"
MORELLI = BASE + "ztl-morelli-filangieri-mille-e-contrassegni-per-laccesso/"
RUSSO = BASE + "ztl-di-via-ferdinando-russo/"
FORMS = BASE + "ztl-e-aree-pedonali-modulistica/"
TEMPORARY = BASE + "deroghe-e-permessi-di-accesso-temporaneo-alle-ztl-cittadine/"
DISABLED = BASE + "transito-persone-con-disabilita-nelle-ztl-e-ap/"
RUSSO_OD = "https://static-www.comune.napoli.it/wp-content/uploads/2026/04/OD_1219_030726_ZTL-Ferdinando-Russo.pdf"


def norm(s):
    return re.sub(r"\s+", " ", s).strip()


TEXT = {p.stem: norm(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def check(file, *quotes):
    """Ogni frase citata deve comparire, parola per parola, nella pagina ufficiale salvata"""
    for q in quotes:
        assert norm(q) in TEXT[file], f"{file}: frase non trovata, ricontrollare la pagina: {q!r}"


def hm(h, m=0):
    return h * 60 + m


def window(days, start, end, season=None):
    w = {"weekdays": days, "start": start, "end": end}
    if season:
        w["season"] = season
    return w


def season(fm, fd, tm, td):
    return {"fromMonth": fm, "fromDay": fd, "toMonth": tm, "toDay": td}


def on_dates(dates, start, end):
    """Una fascia tutti i giorni della settimana, solo nelle date indicate ("MM-DD" o ("MM-DD", "MM-DD") per un intervallo)"""
    out = []
    for d in dates:
        a, b = (d, d) if isinstance(d, str) else d
        out.append(window(ALL, start, end, season(int(a[:2]), int(a[3:]), int(b[:2]), int(b[3:]))))
    return out


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


# Festivi: le zone con orari «festivi e prefestivi» hanno holidaysAsSunday (un festivo infrasettimanale, Pasquetta e il
# 19 settembre compresi, prende l'orario della domenica) e la città ha localHolidays ["09-19"] (San Gennaro, patrono).
# I prefestivi non hanno un campo: le vigilie dei festivi a data fissa si scrivono come date (EVES). Le fasce sulle date
# dei festivi fissi (FIXED_HOLIDAYS) restano per le versioni dell'app che non conoscono holidaysAsSunday.
FIXED_HOLIDAYS = ["01-01", "01-06", "04-25", "05-01", "06-02", "08-15", "09-19", "11-01", "12-08", "12-25", "12-26"]
EVES = ["12-31", "01-05", "04-24", "04-30", "06-01", "08-14", "09-18", "10-31", "12-07", "12-24"]

LINKS = [link("Naples: ZTLs and pedestrian areas (all zones)", "Napoli: ZTL e aree pedonali (tutte le zone)",
              "Neapel: ZTL und Fußgängerzonen (alle Zonen)", INDEX),
         link("Naples: permit forms and prices", "Napoli: modulistica e costi dei permessi", "Neapel: Formulare und Preise der Genehmigungen", FORMS),
         link("Naples: temporary permits (only for proven needs)", "Napoli: permessi temporanei (solo per necessità documentate)",
              "Neapel: befristete Genehmigungen (nur bei nachgewiesenem Bedarf)", TEMPORARY),
         link("Naples: disabled badge holders in ZTLs", "Napoli: persone con disabilità nelle ZTL",
              "Neapel: Inhaber eines Behindertenausweises in ZTL", DISABLED)]

# Le note «da verificare» comuni (inglese, italiano, tedesco)
P_GEOMETRY = ("Perimeter from OpenStreetMap, to be checked against the official map (a PDF on the city's site).",
              "Perimetro da OpenStreetMap, da verificare con la mappa ufficiale (un PDF sul sito del Comune).",
              "Grenze aus OpenStreetMap, mit der offiziellen Karte abzugleichen (ein PDF auf der Seite der Stadt).")
P_ELECTRIC = ("Electric cars: no free entry. Under a 2012 mayor's order, fully electric vehicles may apply for a paid annual permit (at the non-residents' rate); hybrids are not included. Without that permit, treat them like any other car.",
              "Auto elettriche: niente accesso libero. Con un'ordinanza sindacale del 2012 i veicoli solo elettrici possono chiedere un'autorizzazione annuale a pagamento (con la tariffa dei non residenti); le ibride no. Senza quel permesso, considerale come le altre auto.",
              "Elektroautos: keine freie Einfahrt. Nach einer Verordnung des Bürgermeisters von 2012 können reine Elektrofahrzeuge eine kostenpflichtige Jahresgenehmigung beantragen (zum Tarif für Nichtansässige); Hybride nicht. Ohne diese Genehmigung wie andere Autos behandeln.")
P_HOTEL = ("Hotel guests: the hotel registers your plate itself in the city's online system (Smartmobility) for the length of your stay, but it gets only as many permits as it has parking spaces of its own or in an agreed garage. "
           "Neither the rules (2011) nor the 2026 forms give a deadline after entry: have the plate registered before you drive in.",
           "Ospiti degli hotel: l'albergo registra la targa da sé nel sistema online del Comune (Smartmobility) per la durata del soggiorno, ma ha tanti permessi quanti sono i suoi posti auto, propri o in convenzione con un'autorimessa. "
           "Né il disciplinare (2011) né i moduli del 2026 danno un termine dopo l'ingresso: fai registrare la targa prima di entrare.",
           "Hotelgäste: Das Hotel meldet dein Kennzeichen selbst im Online-System der Stadt (Smartmobility) für die Dauer des Aufenthalts, hat aber nur so viele Genehmigungen wie eigene oder vertraglich gebundene Garagenplätze. "
           "Weder die Regeln (2011) noch die Formulare von 2026 nennen eine Frist nach der Einfahrt: Lass das Kennzeichen vor der Einfahrt melden.")
P_HOTEL_FORM = ("This zone's page doesn't mention hotels, but the city's 2026 permit form for hotels lists it among the zones where hotels register guests' plates in Smartmobility.",
                "La pagina di questa zona non parla di alberghi, ma il modulo 2026 del Comune per gli alberghi la elenca tra le ZTL in cui gli alberghi registrano le targhe dei clienti su Smartmobility.",
                "Die Seite dieser Zone erwähnt keine Hotels, aber das Formular der Stadt für Hotels (2026) führt sie unter den Zonen, in denen Hotels Kennzeichen der Gäste in Smartmobility melden.")
P_EASTER = ("Weekday public holidays, Easter Monday included, follow the Sunday hours. The eves of holidays are counted only for holidays on a fixed date (Easter Monday's eve is a Sunday anyway). The city's acts don't define «festivi e prefestivi».",
            "I festivi infrasettimanali, lunedì di Pasqua compreso, seguono l'orario della domenica. I prefestivi sono contati solo per i festivi a data fissa (la vigilia di Pasquetta è comunque domenica). Gli atti del Comune non definiscono «festivi e prefestivi».",
            "Feiertage unter der Woche, Ostermontag eingeschlossen, haben die Sonntagszeiten. Vortage zählen nur bei Feiertagen mit festem Datum (der Vortag des Ostermontags ist ohnehin ein Sonntag). Die Akte der Stadt definieren «festivi e prefestivi» nicht.")
P_PATRON = ("19 September (San Gennaro, patron saint of Naples): GateLR counts it as a holiday (Sunday hours, 18 September as its eve); the city's pages and ordinances don't say so explicitly.",
            "19 settembre (San Gennaro, patrono di Napoli): GateLR lo conta come festivo (orario della domenica, il 18 come prefestivo); le pagine e le ordinanze del Comune non lo dicono in modo esplicito.",
            "19. September (San Gennaro, Schutzpatron Neapels): GateLR zählt ihn als Feiertag (Sonntagszeiten, der 18. als Vortag); Seiten und Verordnungen der Stadt sagen das nicht ausdrücklich.")
P_EVENTS = ("The city changes traffic rules for events and works with short-notice orders: check the news on comune.napoli.it.",
            "Il Comune cambia la viabilità per eventi e lavori con ordinanze a breve preavviso: controlla le notizie su comune.napoli.it.",
            "Die Stadt ändert den Verkehr bei Veranstaltungen und Bauarbeiten kurzfristig: Meldungen auf comune.napoli.it prüfen.")
P_GATES_SOLE = ("The four gates don't all keep the same hours: from 5 pm only the via del Sole gate stays on (until 10 pm Monday to Thursday, until 2 am Friday to Sunday and on holidays and the eves of holidays). GateLR shows the zone closed for as long as any gate is on.",
                "I quattro varchi non hanno lo stesso orario: dalle 17 resta acceso solo quello di via del Sole (fino alle 22 dal lunedì al giovedì, fino alle 2 da venerdì a domenica e nei festivi e prefestivi). GateLR mostra la zona chiusa finché è acceso almeno un varco.",
                "Die vier Kameras haben nicht dieselben Zeiten: Ab 17 Uhr ist nur die in der via del Sole an (bis 22 Uhr Montag bis Donnerstag, bis 2 Uhr Freitag bis Sonntag sowie an Feiertagen und deren Vortagen). GateLR zeigt die Zone gesperrt, solange irgendeine Kamera an ist.")

NO_TICKET_EN = " There is no day ticket for visitors: temporary permits are only for documented needs (moving house, works, medical visits for people with walking problems), requested by email."
NO_TICKET_IT = " Non c'è un biglietto giornaliero per i turisti: i permessi temporanei sono solo per necessità documentate (traslochi, lavori, visite mediche per chi ha problemi a camminare) e si chiedono per email."
NO_TICKET_DE = " Es gibt kein Tagesticket für Besucher: befristete Genehmigungen nur bei nachgewiesenem Bedarf (Umzug, Arbeiten, Arztbesuche bei Gehbehinderung), per E-Mail zu beantragen."
HOTEL_EN = " If your hotel is inside and has parking spaces, it can register your plate before you arrive."
HOTEL_IT = " Se l'hotel è dentro e ha posti auto, può registrare la tua targa prima che arrivi."
HOTEL_DE = " Liegt dein Hotel innen und hat Parkplätze, kann es dein Kennzeichen vor der Ankunft melden."
DISABLED_EN = " Disabled badge holders must have the plate registered first (or report the transit within 48 hours)."
DISABLED_IT = " Chi ha il contrassegno disabili deve far registrare prima la targa (o comunicare il transito entro 48 ore)."
DISABLED_DE = " Inhaber eines Behindertenausweises müssen das Kennzeichen vorher registrieren lassen (oder die Durchfahrt binnen 48 Stunden melden)."


def source(page, quote, translation, pending, links, ordinance=None, ordinance_url=None):
    return {"authority": AUTHORITY, "pageURL": page, "ordinance": ordinance, "ordinanceURL": ordinance_url,
            "quote": quote, "quoteTranslation": translation[0], "quoteTranslation_de": translation[1],
            "checkedOn": CHECKED, "reviewedByHuman": False,
            "pending": [p[0] for p in pending], "pending_it": [p[1] for p in pending], "pending_de": [p[2] for p in pending],
            "links": links}


def zones():
    Q_CENTRO = ("via del Sole (dopo l’ingresso dell’Ospedale) – Attivo dal lunedì al giovedì dalle ore 9:00 alle ore 22:00 e venerdì, sabato, domenica, festivi e prefestivi dalle ore 9:00 alle ore 24:00 e fino alle ore 2:00 del giorno successivo; "
                "– via Miroballo – Attivo tutti i giorni dalle ore 9:00 alle ore 17:00; "
                "– via Duomo (altezza piazza Museo Filangieri) – Attivo tutti i giorni dalle ore 9:00 alle 17:00; "
                "– via Santa Sofia (altezza via Oronzio Costa) – Attivo tutti i giorni dalle ore 9:00 alle ore 17:00.")
    check("ztl-del-centro-antico_centro-antico", Q_CENTRO, "È consentito l’accesso a motoveicoli e ciclomotori.",
          "autoveicoli dei clienti degli alberghi;", "Ultimo aggiornamento: 10/03/2026")
    Q_MEZZO = "Il varco è attivo dal lunedì al giovedì dalle ore 9:00 alle ore 22:00 e venerdì, sabato, domenica, festivi e prefestivi dalle ore 9: 00 alle ore 24:00 e fino alle ore 2:00 del giorno successivo."
    check("ztl-del-centro-antico_mezzocannone", Q_MEZZO, "veicoli dei clienti degli alberghi;",
          "Non possono circolare i ciclomotori e i motoveicoli, con esclusione di quelli autorizzati.")
    check("ztl-del-centro-antico", "L’area della ZTL “Centro Antico”, “Mezzocannone” e “Piazza del Gesù” è delimitata dalle seguenti Vie/Piazze:",
          "Ultimo aggiornamento: 23/04/2026")
    Q_TARSIA = "La ZTL “Tarsia-Pignasecca-Dante” è in vigore tutti i giorni, dalle ore 9:00 alle ore 18:00 e vi possono accedere tutti i veicoli autorizzati e che espongono l’apposito contrassegno."
    check("ztl-tarsia-pignasecca-dante", Q_TARSIA, "Nella ZTL “Tarsia-Pignasecca-Dante” è consentito l’accesso a tutti i ciclomotori e ai motoveicoli (con esclusione di Via Brombeis).",
          "Ultimo aggiornamento: 24/08/2026")
    Q_BELLE = "La ZTL è attiva dalle ore 19:00 alle ore 7:00 tutti i giorni della settimana"
    check("ztl-belledonne-martiri-poerio-e-contrassegni-per-laccesso", Q_BELLE, "Ultimo aggiornamento: 24/08/2026")
    Q_MORELLI = "La ZTL è attiva ogni anno dall’8 dicembre al 6 gennaio tutti i sabati, domeniche, festivi e prefestivi dalle ore 10:00 alle ore 14:00 e dalle ore 16:00 alle ore 20:00."
    check("ztl-morelli-filangieri-mille-e-contrassegni-per-laccesso", Q_MORELLI, "I) veicoli dei clienti degli alberghi;", "C1) motoveicoli e ciclomotori.")
    Q_RUSSO = ("dal 1°aprile al 30 giugno , dalle ore 8:00 alle ore 19:00, nei soli giorni festivi e prefestivi; "
               "• dal 1°luglio al 31 agosto , dalle ore 8:00 alle ore 19:00, tutti i giorni; "
               "• dal 1°settembre al 30 settembre , dalle ore 8:00 alle ore 19:00, nei soli giorni festivi e prefestivi.")
    check("ztl-di-via-ferdinando-russo", Q_RUSSO, "Istituzione – dal 10 luglio 2026 – della ZTL di Via Ferdinando Russo",
          "è fatto obbligo ai titolari delle autofficine/autorimesse/alberghi di registrare direttamente nel sistema informatico [https://smartmobility.anm.it/ar/] Smartmobility le targhe dei veicoli autorizzati al transito")
    check("deroghe-e-permessi-di-accesso-temporaneo-alle-ztl-cittadine", "per comprovate e straordinarie necessità", "traslochi;")
    check("transito-persone-con-disabilita-nelle-ztl-e-ap", "possono registrare fino a due targhe",
          "possono comunicare l’avvenuto transito entro 48 ore")
    check("ztl-e-aree-pedonali-modulistica", "Dei clienti degli alberghi, delle autorimesse (per abbonamenti mensili/plurimensili) e delle autofficine operanti all’interno della ZTL.")
    # PDF ufficiali (static-www.comune.napoli.it, 25/10/2026)
    check("disciplinare-rilascio-contrassegni",
          "Per consentire l'accesso alle strutture alberghiere della Zona a Traffico Limitato, i gestori delle strutture devono provvedere a comunicare le targhe dei propri clienti.",
          "Ai gestori degli alberghi potranno essere rilasciati un numero di contrassegni pari al numero di posti auto della struttura e/o convenzionati con autorimesse",
          "periodo di validità che dovrà necessariamente corrispondere con la durata del soggiorno del cliente")
    check("006-ZTL-ALBERGHI-AUTORIMESSE-AUTOFFICINE-V_03",
          "registrazione in autonomia, nel sistema Smartmobility, delle targhe dei veicoli dei propri clienti",
          "(Il numero dei permessi non può superare il numero dei posti auto e/o moto dichiarati)",
          "Centro Antico;", "Tarsia - Pignasecca – Dante;", "Belledonne – Cavallerizza;", "Mezzocannone;", "Ferdinando Russo.")
    check("os_120612_0604", "su cui sia installato esclusivamente un motore elettrico", "le relative autorizzazioni, avranno validità annuale",
          "saranno soggette a pagamento secondo la tariffa")
    check("OD_1219_030726_ZTL-Ferdinando-Russo", "dal 1° aprile al 30 giugno, dalle ore 08:00 alle ore 19:00, nei soli giorni festivi e prefestivi;",
          "dal 1° luglio al 31 agosto, dalle ore 08:00 alle ore 19:00, tutti i giorni;", "B) ATTIVARE in ESERCIZIO il varco telematico di via Ferdinando Russo",
          "registrare direttamente nel sistema informatico smartmobility.anm.it le targhe dei veicoli autorizzati al transito")

    centro_links = LINKS[:1] + [link("Naples: Centro Antico ZTL (gates and hours)", "Napoli: ZTL del Centro Antico (varchi e orari)",
                                     "Neapel: ZTL Centro Antico (Kameras und Zeiten)", CENTRO_AREA)] + LINKS[1:]
    # Fascia serale dei festivi e prefestivi infrasettimanali (via del Sole e Mezzocannone fino alle 2)
    late_holidays = on_dates(FIXED_HOLIDAYS + EVES, hm(22), hm(2))
    late_week = [window(MON_THU, hm(9), hm(22)), window(FRI_SUN, hm(9), hm(2))]

    morelli_days = [("12-08", "12-08"), ("12-24", "12-26"), ("12-31", "12-31"), ("01-01", "01-01"), ("01-05", "01-06")]
    morelli = []
    for a, b in ((hm(10), hm(14)), (hm(16), hm(20))):
        morelli += [window(SAT_SUN, a, b, season(12, 8, 12, 31)), window(SAT_SUN, a, b, season(1, 1, 1, 6))]
        morelli += on_dates(morelli_days, a, b)

    spring_autumn = [season(4, 1, 6, 30), season(9, 1, 9, 30)]
    russo_dates = ["04-24", "04-25", "04-30", "05-01", "06-01", "06-02", "09-18", "09-19"]
    russo = [window(ALL, hm(8), hm(19), season(7, 1, 8, 31))] + [window(SAT_SUN, hm(8), hm(19), s) for s in spring_autumn] \
        + on_dates(russo_dates, hm(8), hm(19))

    return [
        {"id": "napoli-centro-antico", "name": "Centro Antico · Historic Centre ZTL", "name_it": "Centro Antico · ZTL Centro Antico",
         "name_de": "Centro Antico · ZTL Altstadt", "kind": "restricted",
         "summary": "Closed without a permit every day from 9 am, public holidays included. Three gates switch off at 5 pm; the via del Sole gate and the Mezzocannone gate stay on until 10 pm Monday to Thursday and until 2 am Friday to Sunday. Motorbikes and scooters may enter (not in via Mezzocannone). Piazza del Gesù inside is a pedestrian area, closed day and night." + NO_TICKET_EN + " If your hotel is inside, it can apply for a permit for its guests' cars: ask it before arriving." + DISABLED_EN,
         "summary_it": "Chiusa senza permesso tutti i giorni dalle 9, festivi compresi. Tre varchi si spengono alle 17; quelli di via del Sole e di Mezzocannone restano accesi fino alle 22 dal lunedì al giovedì e fino alle 2 da venerdì a domenica. Moto e scooter possono entrare (non in via Mezzocannone). Piazza del Gesù, all'interno, è area pedonale chiusa giorno e notte." + NO_TICKET_IT + " Se l'hotel è dentro, può chiedere il permesso per le auto dei clienti: chiedilo prima di arrivare." + DISABLED_IT,
         "summary_de": "Ohne Genehmigung täglich ab 9 Uhr gesperrt, auch an Feiertagen. Drei Kameras schalten um 17 Uhr ab; die in der via del Sole und die am Mezzocannone bleiben Montag bis Donnerstag bis 22 Uhr und Freitag bis Sonntag bis 2 Uhr an. Motorräder und Roller dürfen hinein (nicht in die via Mezzocannone). Die Piazza del Gesù im Inneren ist Fußgängerzone, Tag und Nacht gesperrt." + NO_TICKET_DE + " Liegt dein Hotel innen, kann es eine Genehmigung für die Autos seiner Gäste beantragen: vorher nachfragen." + DISABLED_DE,
         "windows": late_week + late_holidays, "freeOnHolidays": False, "holidaysAsSunday": True, "hotelCanRegister": True,
         "source": source(CENTRO_AREA, Q_CENTRO,
                          ("via del Sole (after the hospital entrance) – on Monday to Thursday from 9 am to 10 pm and Friday, Saturday, Sunday, holidays and the eves of holidays from 9 am to midnight and until 2 am the next day; – via Miroballo – on every day from 9 am to 5 pm; – via Duomo (at piazza Museo Filangieri) – on every day from 9 am to 5 pm; – via Santa Sofia (at via Oronzio Costa) – on every day from 9 am to 5 pm.",
                           "via del Sole (nach der Krankenhauseinfahrt) – an Montag bis Donnerstag von 9 bis 22 Uhr und Freitag, Samstag, Sonntag, Feiertage und deren Vortage von 9 bis 24 Uhr und bis 2 Uhr am Folgetag; – via Miroballo – täglich von 9 bis 17 Uhr; – via Duomo (Höhe piazza Museo Filangieri) – täglich von 9 bis 17 Uhr; – via Santa Sofia (Höhe via Oronzio Costa) – täglich von 9 bis 17 Uhr."),
                          [P_GEOMETRY, P_GATES_SOLE,
                           ("Mezzocannone (its own gate, same hours as via del Sole) and the pedestrian area of piazza del Gesù (closed 24 hours) lie inside this outline, as on the city's single perimeter; GateLR doesn't show them separately.",
                            "Mezzocannone (varco proprio, stesso orario di via del Sole) e l'area pedonale di piazza del Gesù (chiusa 24 ore su 24) stanno dentro questo perimetro, come nel perimetro unico del Comune; GateLR non le mostra a parte.",
                            "Mezzocannone (eigene Kamera, gleiche Zeiten wie via del Sole) und die Fußgängerzone Piazza del Gesù (rund um die Uhr gesperrt) liegen in dieser Grenze, wie im einzigen Perimeter der Stadt; GateLR zeigt sie nicht getrennt."),
                           P_HOTEL, P_ELECTRIC, P_EASTER, P_PATRON, P_EVENTS], centro_links,
                          "Delibera di G.C. n. 867 del 04/12/2014 (unificazione ZTL Centro Antico e Mezzocannone e modifica degli orari)",
                          "https://static-www.comune.napoli.it/wp-content/uploads/2025/05/dgc_041214_0867.pdf")},
        {"id": "napoli-tarsia", "name": "Tarsia · Pignasecca–Dante ZTL", "name_it": "Tarsia · ZTL Tarsia-Pignasecca-Dante",
         "name_de": "Tarsia · ZTL Tarsia-Pignasecca-Dante", "kind": "restricted",
         "summary": "Closed without a permit every day from 9 am to 6 pm, public holidays included. Via Domenico Soriano and via Brombeis inside are pedestrian areas, closed all day. Motorbikes and scooters may enter (not via Brombeis)." + NO_TICKET_EN + HOTEL_EN + DISABLED_EN,
         "summary_it": "Chiusa senza permesso tutti i giorni dalle 9 alle 18, festivi compresi. Via Domenico Soriano e via Brombeis, all'interno, sono aree pedonali chiuse tutto il giorno. Moto e scooter possono entrare (non in via Brombeis)." + NO_TICKET_IT + HOTEL_IT + DISABLED_IT,
         "summary_de": "Ohne Genehmigung täglich von 9 bis 18 Uhr gesperrt, auch an Feiertagen. Via Domenico Soriano und via Brombeis im Inneren sind ganztägig Fußgängerzonen. Motorräder und Roller dürfen hinein (nicht in die via Brombeis)." + NO_TICKET_DE + HOTEL_DE + DISABLED_DE,
         "windows": [window(ALL, hm(9), hm(18))], "freeOnHolidays": False, "hotelCanRegister": True,
         "source": source(TARSIA, Q_TARSIA,
                          ("The 'Tarsia-Pignasecca-Dante' ZTL is in force every day from 9 am to 6 pm, and all authorised vehicles displaying the permit may enter.",
                           "Die ZTL „Tarsia-Pignasecca-Dante“ gilt täglich von 9 bis 18 Uhr; alle berechtigten Fahrzeuge mit Ausweis dürfen hinein."),
                          [P_GEOMETRY, P_HOTEL_FORM, P_HOTEL, P_ELECTRIC, P_EVENTS], LINKS, "Delibera di G.C. n. 472 del 30/11/2022",
                          "https://static-www.comune.napoli.it/wp-content/uploads/2025/05/dgc_472_301122.pdf")},
        {"id": "napoli-belledonne", "name": "Belledonne · Martiri–Poerio night ZTL", "name_it": "Belledonne · ZTL Belledonne-Martiri-Poerio",
         "name_de": "Belledonne · Nacht-ZTL Martiri-Poerio", "kind": "restricted",
         "summary": "Closed without a permit every day from 7 pm to 7 am (the nightlife streets around piazza dei Martiri in Chiaia), public holidays included." + NO_TICKET_EN + HOTEL_EN + DISABLED_EN,
         "summary_it": "Chiusa senza permesso tutti i giorni dalle 19 alle 7 (le strade della movida intorno a piazza dei Martiri, a Chiaia), festivi compresi." + NO_TICKET_IT + HOTEL_IT + DISABLED_IT,
         "summary_de": "Ohne Genehmigung täglich von 19 bis 7 Uhr gesperrt (die Ausgehstraßen um die piazza dei Martiri in Chiaia), auch an Feiertagen." + NO_TICKET_DE + HOTEL_DE + DISABLED_DE,
         "windows": [window(ALL, hm(19), hm(7))], "freeOnHolidays": False, "hotelCanRegister": True,
         "source": source(BELLE, Q_BELLE,
                          ("The ZTL is active from 7 pm to 7 am every day of the week", "Die ZTL ist an allen Wochentagen von 19 bis 7 Uhr aktiv"),
                          [P_GEOMETRY, P_HOTEL_FORM, P_HOTEL, P_ELECTRIC,
                           ("A rental-car guide says this ZTL is active 24 hours a day; the city's page (updated 24/08/2026) says 7 pm–7 am. GateLR follows the city.",
                            "Una guida di autonoleggio dice che questa ZTL è attiva 24 ore su 24; la pagina del Comune (aggiornata il 24/08/2026) dice 19–7. GateLR segue il Comune.",
                            "Ein Mietwagen-Ratgeber nennt diese ZTL rund um die Uhr aktiv; die Seite der Stadt (Stand 24.08.2026) sagt 19–7 Uhr. GateLR folgt der Stadt."),
                           P_EVENTS], LINKS, "O.S. n. 315 dell’11/03/2013 (attivazione varchi telematici)",
                          "https://static-www.comune.napoli.it/wp-content/uploads/2025/05/os_110313_0315.pdf")},
        {"id": "napoli-morelli", "name": "Morelli · Christmas ZTL Filangieri–Mille", "name_it": "Morelli · ZTL natalizia Filangieri-Mille",
         "name_de": "Morelli · Weihnachts-ZTL Filangieri-Mille", "kind": "restricted",
         "summary": "Only in the Christmas season, 8 December to 6 January: closed without a permit on Saturdays, Sundays, public holidays and the eves of holidays from 10 am to 2 pm and 4 to 8 pm. The rest of the year it is open. Motorbikes and scooters may enter." + NO_TICKET_EN + " If your hotel is inside, it can apply for a permit for its guests' cars.",
         "summary_it": "Solo nel periodo natalizio, dall'8 dicembre al 6 gennaio: chiusa senza permesso il sabato, la domenica, nei festivi e prefestivi dalle 10 alle 14 e dalle 16 alle 20. Il resto dell'anno è aperta. Moto e scooter possono entrare." + NO_TICKET_IT + " Se l'hotel è dentro, può chiedere il permesso per le auto dei clienti.",
         "summary_de": "Nur in der Weihnachtszeit, 8. Dezember bis 6. Januar: ohne Genehmigung gesperrt an Samstagen, Sonntagen, Feiertagen und deren Vortagen von 10 bis 14 und 16 bis 20 Uhr. Den Rest des Jahres offen. Motorräder und Roller dürfen hinein." + NO_TICKET_DE + " Liegt dein Hotel innen, kann es eine Genehmigung für die Autos seiner Gäste beantragen.",
         "windows": morelli, "freeOnHolidays": False, "holidaysAsSunday": True, "hotelCanRegister": True,
         "source": source(MORELLI, Q_MORELLI,
                          ("The ZTL is active every year from 8 December to 6 January on all Saturdays, Sundays, holidays and the eves of holidays from 10 am to 2 pm and from 4 pm to 8 pm.",
                           "Die ZTL ist jedes Jahr vom 8. Dezember bis 6. Januar an allen Samstagen, Sonntagen, Feiertagen und deren Vortagen von 10 bis 14 und von 16 bis 20 Uhr aktiv."),
                          [P_GEOMETRY,
                           ("In OpenStreetMap this ZTL is a narrow strip along the streets themselves (about 11 m wide): with a weak GPS signal GateLR may place you just outside it.",
                            "In OpenStreetMap questa ZTL è una striscia stretta lungo le strade (circa 11 m): con un segnale GPS debole GateLR può collocarti appena fuori.",
                            "In OpenStreetMap ist diese ZTL ein schmaler Streifen entlang der Straßen (etwa 11 m): Bei schwachem GPS kann GateLR dich knapp außerhalb verorten."),
                           P_HOTEL, P_ELECTRIC,
                           ("Eves of holidays: GateLR counts 24 and 31 December and 5 January (Saturdays already count).",
                            "Prefestivi: GateLR conta il 24 e il 31 dicembre e il 5 gennaio (i sabati sono già compresi).",
                            "Vortage von Feiertagen: GateLR zählt den 24. und 31. Dezember und den 5. Januar (Samstage sind schon dabei)."),
                           P_EVENTS], LINKS, "O.D. n. 711 del 12/11/2014 (istituzione della ZTL e varco di via Morelli)",
                          "https://static-www.comune.napoli.it/wp-content/uploads/2025/05/od_121114_711.pdf")},
        {"id": "napoli-ferdinando-russo", "name": "Posillipo · via Ferdinando Russo ZTL", "name_it": "Posillipo · ZTL via Ferdinando Russo",
         "name_de": "Posillipo · ZTL via Ferdinando Russo", "kind": "restricted",
         "summary": "The road down to the sea at Posillipo, from 8 am to 7 pm: every day in July and August; on Saturdays, Sundays, public holidays and the eves of holidays from April to June and in September. Open from October to March. If your hotel is on the street, it registers your plate itself in the city's online system." + NO_TICKET_EN,
         "summary_it": "La strada che scende al mare a Posillipo, dalle 8 alle 19: tutti i giorni a luglio e agosto; il sabato, la domenica, nei festivi e prefestivi da aprile a giugno e a settembre. Aperta da ottobre a marzo. Se l'hotel è sulla strada, registra lui la tua targa nel sistema online del Comune." + NO_TICKET_IT,
         "summary_de": "Die Straße hinunter zum Meer in Posillipo, 8 bis 19 Uhr: täglich im Juli und August; samstags, sonntags, an Feiertagen und deren Vortagen von April bis Juni und im September. Oktober bis März offen. Liegt dein Hotel an der Straße, meldet es dein Kennzeichen selbst im Online-System der Stadt." + NO_TICKET_DE,
         "windows": russo, "freeOnHolidays": False, "holidaysAsSunday": True, "hotelCanRegister": True,
         "source": source(RUSSO, Q_RUSSO,
                          ("from 1 April to 30 June, 8 am to 7 pm, on holidays and the eves of holidays only; • from 1 July to 31 August, 8 am to 7 pm, every day; • from 1 to 30 September, 8 am to 7 pm, on holidays and the eves of holidays only.",
                           "vom 1. April bis 30. Juni, 8 bis 19 Uhr, nur an Feiertagen und deren Vortagen; • vom 1. Juli bis 31. August, 8 bis 19 Uhr, täglich; • vom 1. bis 30. September, 8 bis 19 Uhr, nur an Feiertagen und deren Vortagen."),
                          [P_GEOMETRY, P_HOTEL,
                           ("Holidays and their eves: GateLR counts Saturdays and Sundays, Easter Monday, the fixed holidays in the period (25 April, 1 May, 2 June, 19 September) and the day before each fixed holiday.",
                            "Festivi e prefestivi: GateLR conta sabati e domeniche, il lunedì di Pasqua, i festivi fissi del periodo (25 aprile, 1° maggio, 2 giugno, 19 settembre) e il giorno prima di ciascun festivo fisso.",
                            "Feiertage und Vortage: GateLR zählt Samstage, Sonntage, den Ostermontag, die festen Feiertage im Zeitraum (25. April, 1. Mai, 2. Juni, 19. September) und den Tag vor jedem festen Feiertag."),
                           P_EASTER, P_PATRON, P_ELECTRIC, P_EVENTS], LINKS,
                          "O.D. n. 1219 del 03/07/2026 (attivazione in esercizio ZTL di via Ferdinando Russo)", RUSSO_OD)},
    ]


# Zona → relazione OpenStreetMap (data/raw/geo/napoli-ztl.json), riempito dopo aver guardato i dati
# Mezzocannone e piazza del Gesù stanno dentro la relazione «ZTL Centro Antico» (come nel perimetro ufficiale unico):
# niente zona a parte per Mezzocannone (stessi orari di via del Sole). Via Ferdinando Russo non è in OSM: esclusa finché manca.
OSM_ZONES = {"napoli-centro-antico": 19164566,     # ZTL Centro Antico
             "napoli-tarsia": 19164565,            # ZTL Tarsia - Pignasecca - Dante
             "napoli-belledonne": 19164564,        # ZTL Belledonne - Martiri - Poerio
             "napoli-morelli": 19164567}           # ZTL Morelli - Filangieri - Mille (striscia lungo le strade)
GATE_MAX_M = 60   # un varco OSM va alla zona col bordo più vicino, se è a meno di 60 m


def official_geometry():
    perims = {}
    pf = RAW / "perimetri.geojson"
    if pf.exists():
        for f in json.loads(pf.read_text())["features"]:
            g = f["geometry"]
            polys = [g["coordinates"]] if g["type"] == "Polygon" else g["coordinates"]
            outer = max((p[0] for p in polys), key=len)
            perims[f["properties"]["gatelr_id"]] = [{"lat": round(y, 6), "lon": round(x, 6)} for x, y in outer]
    return perims


def osm_link(rid):
    return link(f"OpenStreetMap: relation {rid} (perimeter, ODbL)", f"OpenStreetMap: relazione {rid} (perimetro, ODbL)",
                f"OpenStreetMap: Relation {rid} (Grenze, ODbL)", osm_geo.osm_url("relation", rid))


def osm_geometry():
    elements = osm_geo.load("napoli-ztl")
    perims = {}
    for zid, rid in OSM_ZONES.items():
        rel = osm_geo.relation(elements, rid)
        # la ZTL Morelli in OSM è una striscia di ~11 m lungo le strade: semplificata a 2 m per non perderla
        perims[zid] = osm_geo.perimeter(osm_geo.outer_ring(rel), tol_m=2 if zid == "napoli-morelli" else 5)
    # Telecamere (man_made=surveillance) chiamate «Varco…» o con designation «Varco ZTL»; i «Varco» del porto sono sbarre, esclusi
    found = [(e["id"], e["tags"].get("name") or e["tags"].get("designation"), e["lat"], e["lon"]) for e in osm_geo.load("napoli-gates")
             if e["type"] == "node" and e.get("tags", {}).get("man_made") == "surveillance"
             and (e["tags"].get("name") or e["tags"].get("designation") or "").startswith("Varco")]
    gates = {}
    for g in found:
        d, zid = min((osm_geo.distance_m(ring, g[2], g[3]), zid) for zid, ring in perims.items())
        if d <= GATE_MAX_M:
            gates.setdefault(zid, []).append(osm_geo.gate_json("na", g))
    return perims, gates


def build():
    out = zones()
    official = official_geometry()
    osm_perims, osm_gates = osm_geometry()
    kept = []
    for z in out:
        is_official = z["id"] in official
        z["perimeter"] = official.get(z["id"]) or osm_perims.get(z["id"], [])
        z["gates"] = sorted(osm_gates.get(z["id"], []), key=lambda g: (g["name"], g["id"]))
        z["exemptFuels"] = []
        s = z["source"]
        if is_official:
            for key, i in (("pending", 0), ("pending_it", 1), ("pending_de", 2)):
                s[key] = [p for p in s[key] if p != P_GEOMETRY[i]]
        elif z["id"] in OSM_ZONES:
            s["links"] = s["links"] + [osm_link(OSM_ZONES[z["id"]])]
        if len(z["perimeter"]) >= 4:
            kept.append(z)
        else:
            print("zona senza perimetro, esclusa:", z["id"])
    order = ["id", "name", "name_it", "name_de", "kind", "summary", "summary_it", "summary_de", "perimeter", "gates",
             "windows", "freeOnHolidays", "holidaysAsSunday", "exemptFuels", "hotelCanRegister", "source"]
    return [{k: z[k] for k in order if k in z} for z in kept], len(out)


zs, total = build()
city = {"id": "napoli", "name": "Naples", "name_it": "Napoli", "name_de": "Neapel", "center": {"lat": 40.8484, "lon": 14.2560},
        "localHolidays": ["09-19"], "zones": zs, "status": "draft",
        "license": "Hours and rules: Comune di Napoli (comune.napoli.it). Perimeters and gates: " + osm_geo.ODBL + " (approximate, not official)."}
# Una città esce nell'app solo se ogni zona ha il suo perimetro; altrimenti resta tra le bozze (data/drafts)
ready = bool(zs)
out = ROOT / ("Resources/Cities/napoli.json" if ready else "data/drafts/napoli.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/napoli.json" if ready else "Resources/Cities/napoli.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), f"{len(zs)}/{total} zone", [(z["id"], len(z["perimeter"]), len(z["gates"]), len(z["windows"])) for z in zs])
