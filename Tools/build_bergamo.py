#!/usr/bin/env python3
# Costruisce la scheda di Bergamo dalle pagine e dagli atti ufficiali del Comune salvati in data/raw/bergamo/
# (testo estratto, con URL e data di lettura in testa a ogni file; fonti e date in docs/fonti-bergamo.md).
#
# Geometria: i perimetri ufficiali sono i dati aperti del Comune su dati.lombardia.it («Comune Bergamo - Zone a Traffico
# Limitato (ZTL)», tkwz-spd9, IODL 2.0; la pagina del Comune dice «Pubblico dominio»), scaricati con il workflow
# «Scarica pagine» in data/raw/bergamo/opendata-tkwz-spd9-zone-traffico-limitato.geojson (anche Tools/fetch_geo.py
# li scarica in data/raw/geo/bergamo-od-tkwz-spd9.geojson). OpenStreetMap non ha le ZTL di Bergamo.
# Ogni zona qui sotto indica le parole che la riconoscono nel campo «nome_ztl» del dataset ufficiale («match»).
# Una zona senza perimetro non esce; se nessuna zona ha il perimetro, la città va in data/drafts/bergamo.json.
#
# Uso: python3 Tools/build_bergamo.py   (non tocca le altre città né manifest.json)
import json, re, unicodedata
from pathlib import Path
import osm_geo
from seasons import season

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/bergamo"
GEO = ROOT / "data/raw/geo"
CHECKED = "2026-10-25T09:00:00Z"
AUTHORITY = "City of Bergamo"

EVERY_DAY, MON_FRI, THU_SAT, SUN = [1, 2, 3, 4, 5, 6, 7], [2, 3, 4, 5, 6], [5, 6, 7], [1]
# «dal giovedì successivo all'entrata in vigore dell'ora legale, al sabato precedente l'entrata in vigore dell'ora solare»:
# l'ora legale comincia l'ultima domenica di marzo e finisce l'ultima domenica di ottobre, quindi dal giovedì dopo
# l'ultima domenica di marzo (offset +4) al sabato prima dell'ultima domenica di ottobre (offset -1): nel 2026 dal 2 aprile
# al 24 ottobre, nel 2027 dal 1° aprile al 30 ottobre. Regola dalla 1.17.1 (Tools/seasons.py); per le app più vecchie
# restano le date più larghe possibili (29 marzo – 30 ottobre): qualche sera in più segnata come accesa, mai una in meno.
DST = season({"month": 3, "weekday": 1, "nth": -1, "offset": 4}, {"month": 10, "weekday": 1, "nth": -1, "offset": -1})

B = "https://www.comune.bergamo.it"
LIST_PAGE = B + "/page:c_a794:zona.traffico.limitata;quali.sono.ztl"
RULES_PAGE = B + "/action:c_a794:zona.traffico.limitato"
PLATES_PAGE = B + "/action:c_a794:zona.traffico.limitato;comunicare;targhe"
PERMITS_PAGE = B + "/action:c_a794:zona.traffico.limitato;rilascio.permesso"
DOC_OP = B + "/uri-res/N2Ls?urn:nir:comune.bergamo:protocollo:2025-01-16;0021613"
NEWS_HOLIDAYS = B + "/notizie/citt%C3%A0-alta-e-colli:-dal-21-giugno-domenica-e-festivi-entra-in-vigore-la-ztl-dalle-ore-10-alle-ore-24"
NEWS_EXIT = B + "/notizie/dal-12-dicembre-2025-attivate-le-telecamere-in-uscita-dalle-ztl-di-citt%C3%A0-alta-valverde-e-tassopignolo"
OPEN_DATA = B + "/node/748000"
OD_ID = "tkwz-spd9"
OD_URL = f"https://www.dati.lombardia.it/d/{OD_ID}"


def norm(s):
    return re.sub(r"\s+", " ", s).strip()


TEXT = {p.stem: norm(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def check(file, *quotes):
    """Ogni frase citata o riassunta deve comparire, parola per parola, nel testo ufficiale salvato"""
    for q in quotes:
        if norm(q) not in TEXT[file]:
            raise SystemExit(f"{file}: frase non trovata, ricontrollare la pagina: {q!r}")


def url_of(file):
    return TEXT[file].split(" ", 2)[1]


def hm(h, m=0):
    return h * 60 + m


def window(days, start, end, season=None):
    w = {"weekdays": days, "start": start, "end": end}
    if season:
        w["season"] = season
    return w


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


# Regole comuni a tutte le ZTL (documento operativo approvato con la delibera GC 798/2024, ord. 3/2025; pagine del Comune)
check("documento_operativo_GC_798_2024",
      "La registrazione dei dati dei veicoli utilizzati dagli opsiti deve essere effettuata entro un termine massimo di 72 ore dal momento dell’effettivo accesso del mezzo nella ZTL.",
      "contrassegni di transito in quantità pari al numero di camere disponibili",
      "e, per quanto riguarda alberghi e assimilabili, è comunque limitato ad un massimo di 30 gg.",
      "h) Veicoli a propulsione totalmente elettrica;",
      "j) Ciclomotori e motocicli esclusivamente per la ZTL festiva e serale di Città Alta Colli.",
      "devono segnalarne le targhe con le modalità di cui al punto 22;",
      "ATTIVITA' RICETTIVE/RISTORANTI 1,00 €")
check("comune-servizio-circolare-ztl",
      "I veicoli che non necessitano del permesso di ZTL ma devono comunque comunicare il loro passaggio sono: veicoli a servizio di disabili, muniti del prescritto contrassegno (con disabili a bordo)",
      "veicoli a propulsione totalmente elettrica.")
check("comune-servizio-comunicare-targhe",
      "accessi.ztl@atb.bergamo.it", "Nella richiesta deve essere specificata la data del primo transito, purché non superiore a 120 ore da questo.")
check("comune-notizia-varchi-uscita-2025-12", "prevista per il 12 gennaio 2026")
check("atb-ztl-di-bergamo", "ad eccezione dei motoveicoli (motocicli e ciclomotori), cui è consentito l'accesso per i varchi della sola ZTL Festiva e serale dei Colli",
      "AL MASSIMO ENTRO 120 ORE DAL PASSAGGIO disabili")
check("atb-permessi-temporanei", "VEICOLI TOTALMENTE ELETTRICI (Permesso di transito)")
check("atb-news-2024-08-31-permessi-citta-alta",
      "le persone prive di permesso, dal 4 maggio, possono raggiungere solo i tre parcheggi pubblici (via Tre Armi, Porta Sant’Alessandro e via Fara), transitando unicamente dal varco di viale Vittorio Emanuele")
check("atb-faq-ztl-colli", "Nelle domeniche e nei giorni festivi la ZTL è attiva dalle ore 10:00 alle ore 24:00.")
check("nonufficiale-visitbergamo-infografica-ztl-2026-06", "with the obligation to park within 30 minutes of entry")

LINKS = [link("City of Bergamo: list of all ZTLs and hours", "Comune di Bergamo: elenco e orari di tutte le ZTL",
              "Stadt Bergamo: Liste und Zeiten aller ZTL", LIST_PAGE),
         link("City of Bergamo: who may drive in the ZTLs", "Comune di Bergamo: chi può circolare nelle ZTL",
              "Stadt Bergamo: Wer in die ZTL fahren darf", RULES_PAGE),
         link("City of Bergamo: registering a plate (disabled badge, fully electric cars)",
              "Comune di Bergamo: comunicare la targa (contrassegno disabili, auto elettriche)",
              "Stadt Bergamo: Kennzeichen melden (Behindertenausweis, reine Elektroautos)", PLATES_PAGE),
         link("City of Bergamo: ZTL permit rules and prices (Council decision 798/2024)",
              "Comune di Bergamo: disciplina e tariffe dei contrassegni (delibera GC 798/2024)",
              "Stadt Bergamo: Regeln und Preise der ZTL-Genehmigungen (Beschluss 798/2024)", DOC_OP)]
GEO_LINK = link("City of Bergamo: ZTL map, open data", "Comune di Bergamo: mappa delle ZTL, dati aperti",
                "Stadt Bergamo: ZTL-Karte, offene Daten", OPEN_DATA)

COMMON_PENDING = [
    ("Map outline: official open data of the City of Bergamo, last updated 4 October 2024. The city redrew the Città Alta, Colli and Valverde zones in 2025 (decisions 398 and 560/2025): edges to be checked. No gate positions are published.",
     "Perimetro: dati aperti ufficiali del Comune di Bergamo, aggiornati il 4 ottobre 2024. Il Comune ha ridisegnato le ZTL di Città Alta, Colli e Valverde nel 2025 (delibere 398 e 560/2025): confini da verificare. Le posizioni dei varchi non sono pubblicate.",
     "Grenze: offizielle offene Daten der Stadt Bergamo, zuletzt aktualisiert am 4. Oktober 2024. Die Stadt hat Città Alta, Colli und Valverde 2025 neu abgegrenzt (Beschlüsse 398 und 560/2025): Ränder zu prüfen. Kamerastandorte sind nicht veröffentlicht."),
    ("Fully electric cars and cars carrying a disabled badge holder don't need a permit, but the plate must be registered with ATB (accessi.ztl@atb.bergamo.it) no later than 120 hours after the first entry: GateLR does not count them as exempt.",
     "Auto totalmente elettriche e veicoli al servizio di disabili con contrassegno non hanno bisogno del permesso, ma la targa va comunicata ad ATB (accessi.ztl@atb.bergamo.it) entro 120 ore dal primo transito: GateLR non le conta come esenti.",
     "Reine Elektroautos und Fahrzeuge mit Behindertenausweis brauchen keine Genehmigung, das Kennzeichen muss aber spätestens 120 Stunden nach der ersten Einfahrt bei ATB (accessi.ztl@atb.bergamo.it) gemeldet werden: GateLR zählt sie nicht als befreit."),
    ("Hotels inside a ZTL register guests' plates online with ATB within 72 hours of entry (max 30 days, 1 € per day per plate). The ATB pages could not be read from here: rules taken from the city's 2024 permit rules.",
     "Gli hotel dentro una ZTL registrano online con ATB la targa degli ospiti entro 72 ore dall'ingresso (massimo 30 giorni, 1 € al giorno per targa). Le pagine di ATB non erano leggibili da qui: regole prese dal documento operativo del Comune (2024).",
     "Hotels in einer ZTL melden das Kennzeichen der Gäste online bei ATB innerhalb von 72 Stunden nach der Einfahrt (höchstens 30 Tage, 1 € pro Tag und Kennzeichen). Die ATB-Seiten waren von hier nicht lesbar: Regeln aus den städtischen Genehmigungsregeln von 2024."),
]


# Le zone. «file»: la pagina ufficiale salvata; «quote»: la riga dell'orario, parola per parola.
# «match»: parole (minuscole, senza accenti) che riconoscono la zona nel dataset ufficiale.
def zone(zid, name, file, windows, quote, translation, summary, match, holidays=False, extra_pending=(), extra_links=()):
    return dict(zid=zid, name=name, file=file, windows=windows, quote=quote, translation=translation,
                summary=summary, match=match, holidays=holidays, extra_pending=list(extra_pending), extra_links=list(extra_links))


# Nei festivi infrasettimanali Colli e Valverde seguono l'orario della domenica (holidaysAsSunday). La festa del patrono
# (Sant'Alessandro, 26 agosto) non è in localHolidays: le pagine non dicono se per le ZTL conta come «festivo».
HOLIDAY_NOTE = ("Public holidays follow the Sunday hours. Not confirmed whether the patron saint's day (Sant'Alessandro, 26 August) counts as a holiday for the ZTL: GateLR treats it as a normal day.",
                "I festivi seguono l'orario della domenica. Non è confermato se la festa del patrono (Sant'Alessandro, 26 agosto) conti come festivo per la ZTL: GateLR la tratta come un giorno normale.",
                "Feiertage folgen den Sonntagszeiten. Ob der Tag des Stadtpatrons (Sant'Alessandro, 26. August) für die ZTL als Feiertag gilt, ist nicht bestätigt: GateLR behandelt ihn als normalen Tag.")

ALL_DAY = window(EVERY_DAY, 0, hm(24))
NIGHT_23_7 = window(EVERY_DAY, hm(23), hm(7))

ZONES = [
    zone("bergamo-citta-alta", ("Città Alta · Historic centre", "Città Alta · Centro storico", "Città Alta · Altstadt"),
         "ztl-centro-storico-citta-alta", [ALL_DAY],
         "centro storico tra largo Colle Aperto, viale delle Mura, via San Lorenzo e via Fara tutti i giorni 00:00 24:00",
         ("historic centre between Largo Colle Aperto, Viale delle Mura, Via San Lorenzo and Via Fara, every day 00:00–24:00",
          "Altstadt zwischen Largo Colle Aperto, Viale delle Mura, Via San Lorenzo und Via Fara, täglich 00:00–24:00"),
         ("The walled upper town is closed to unauthorised vehicles 24 hours a day, every day, holidays included. There is no ticket for visitors: park outside (e.g. at the walls) or take the funicular. If your hotel is inside, it can register your plate within 72 hours.",
          "La Città Alta dentro le mura è chiusa ai veicoli non autorizzati 24 ore su 24, tutti i giorni, festivi compresi. Non c'è un ticket per i visitatori: parcheggia fuori (per esempio lungo le mura) o prendi la funicolare. Se l'hotel è dentro, può registrare la tua targa entro 72 ore.",
          "Die Oberstadt innerhalb der Mauern ist rund um die Uhr, täglich und auch an Feiertagen für nicht berechtigte Fahrzeuge gesperrt. Ein Ticket für Besucher gibt es nicht: außerhalb parken (z. B. an den Mauern) oder die Standseilbahn nehmen. Liegt dein Hotel innen, kann es dein Kennzeichen innerhalb von 72 Stunden melden."),
         ["centro storico"],
         extra_pending=[("Exit cameras (since 12 January 2026 with fines) also check the exit times of permit holders.",
                         "Le telecamere in uscita (con multe dal 12 gennaio 2026) controllano anche l'orario di uscita di chi ha il permesso.",
                         "Ausfahrtskameras (seit 12. Januar 2026 mit Bußgeld) prüfen auch die Ausfahrtszeiten von Genehmigungsinhabern.")],
         extra_links=[link("City of Bergamo: exit cameras from 12 Dec 2025", "Comune di Bergamo: telecamere in uscita dal 12/12/2025",
                           "Stadt Bergamo: Ausfahrtskameras ab 12.12.2025", NEWS_EXIT)]),
    zone("bergamo-colli", ("Città Alta & Colli · Sundays, holidays, summer nights", "Città Alta e Colli · domeniche, festivi, sere d'estate",
                           "Città Alta & Colli · Sonn- und Feiertage, Sommernächte"),
         "ztl-citta-alta-colli",
         [window(SUN, hm(10), hm(24)), window(THU_SAT, hm(21), hm(1), DST)],
         "Città Alta e Colli in tutta la ZTL tutti i giorni festivi dell'anno 10:00 24:00 in tutta la ZTL giovedì, venerdì e sabato* 21:00 01:00",
         ("Città Alta and Colli, the whole ZTL: all public holidays of the year 10:00–24:00; the whole ZTL: Thursday, Friday and Saturday* 21:00–01:00 (*from the Thursday after the start of summer time to the Saturday before it ends)",
          "Città Alta und Colli, ganze ZTL: alle Feiertage des Jahres 10:00–24:00; ganze ZTL: Donnerstag, Freitag und Samstag* 21:00–01:00 (*vom Donnerstag nach Beginn der Sommerzeit bis zum Samstag vor ihrem Ende)"),
         ("The roads up to Città Alta and the hills (Colli) are closed on Sundays and public holidays from 10 am to midnight, and during summer time on Thursday, Friday and Saturday nights from 9 pm to 1 am. Otherwise you can drive up freely (the walled centre stays closed). While it is closed you may still drive to the Fara, Tre Armi and Porta Sant'Alessandro car parks, but only through the gate on Viale Vittorio Emanuele (Conca d'Oro roundabout). Motorbikes may enter.",
          "Le strade per Città Alta e i Colli sono chiuse la domenica e i festivi dalle 10 a mezzanotte e, con l'ora legale, il giovedì, venerdì e sabato sera dalle 21 all'1. Negli altri orari si sale liberamente (il centro storico dentro le mura resta chiuso). Anche a ZTL attiva si possono raggiungere i parcheggi di via Fara, Tre Armi e Porta Sant'Alessandro, ma solo dal varco di viale Vittorio Emanuele (rotonda Conca d'Oro). Le moto possono entrare.",
          "Die Straßen nach Città Alta und in die Hügel (Colli) sind sonn- und feiertags von 10 bis 24 Uhr gesperrt und während der Sommerzeit donnerstags, freitags und samstags von 21 bis 1 Uhr. Sonst frei befahrbar (die Altstadt innerhalb der Mauern bleibt gesperrt). Auch während der Sperre darf man zu den Parkplätzen Fara, Tre Armi und Porta Sant'Alessandro fahren, aber nur über die Kamera am Viale Vittorio Emanuele (Kreisverkehr Conca d'Oro). Motorräder dürfen hinein."),
         ["colli"], holidays=True,
         extra_pending=[("Summer-time nights: from the Thursday after the clocks go forward (last Sunday of March) to the Saturday before they go back (last Sunday of October): 2 April–24 October in 2026, 1 April–30 October in 2027. Older versions of the app use 29 March–30 October, so they may show a few extra nights as active.",
                         "Sere con l'ora legale: dal giovedì dopo il passaggio all'ora legale (ultima domenica di marzo) al sabato prima del ritorno all'ora solare (ultima domenica di ottobre): nel 2026 dal 2 aprile al 24 ottobre, nel 2027 dal 1° aprile al 30 ottobre. Le versioni più vecchie dell'app usano 29 marzo–30 ottobre, quindi qualche sera in più può risultare attiva.",
                         "Sommerzeit-Nächte: vom Donnerstag nach der Zeitumstellung im Frühjahr (letzter Sonntag im März) bis zum Samstag vor der im Herbst (letzter Sonntag im Oktober): 2. April–24. Oktober 2026, 1. April–30. Oktober 2027. Ältere App-Versionen nehmen 29. März–30. Oktober und zeigen daher einige Nächte zu viel als aktiv."),
                        ("Since 21 June 2026 Sundays and holidays are closed continuously 10–24 (the free 12–14 and 19–24 slots were removed). Older guides still show the old hours.",
                         "Dal 21 giugno 2026 domeniche e festivi sono chiusi senza interruzioni 10–24 (eliminate le fasce libere 12–14 e 19–24). Le guide più vecchie riportano ancora l'orario precedente.",
                         "Seit 21. Juni 2026 sind Sonn- und Feiertage durchgehend 10–24 Uhr gesperrt (die freien Zeiten 12–14 und 19–24 Uhr entfallen). Ältere Reiseführer zeigen noch die alten Zeiten."),
                        ("Car parks: drivers without a permit may reach only the three public car parks (Via Fara, Tre Armi, Porta Sant'Alessandro), entering only from the Viale Vittorio Emanuele gate (ATB, 31 Aug 2024). VisitBergamo (June 2026) adds that you must park within 30 minutes: confirmed only by VisitBergamo. GateLR still shows the zone as closed.",
                         "Parcheggi: chi non ha il permesso può raggiungere solo i tre parcheggi pubblici (via Fara, Tre Armi, Porta Sant'Alessandro), entrando solo dal varco di viale Vittorio Emanuele (ATB, 31/08/2024). VisitBergamo (giugno 2026) aggiunge l'obbligo di parcheggiare entro 30 minuti: confermato solo da VisitBergamo. GateLR mostra comunque la zona come chiusa.",
                         "Parkplätze: Ohne Genehmigung erreicht man nur die drei öffentlichen Parkplätze (Via Fara, Tre Armi, Porta Sant'Alessandro), Einfahrt nur über die Kamera am Viale Vittorio Emanuele (ATB, 31.08.2024). VisitBergamo (Juni 2026) nennt zusätzlich: innerhalb von 30 Minuten parken – nur von VisitBergamo bestätigt. GateLR zeigt die Zone trotzdem als gesperrt."),
                        ("Motorbikes and mopeds may enter this zone without a permit (city permit rules, point 13 j; ATB): with «Motorbike / scooter» in Garage GateLR answers yes. In the other ZTLs of Bergamo they need a permit.",
                         "Moto e ciclomotori possono entrare in questa zona senza permesso (documento operativo del Comune, punto 13 j; ATB): con «Moto / scooter» nel Garage GateLR risponde sì. Nelle altre ZTL di Bergamo serve il permesso.",
                         "Motorräder und Mopeds dürfen ohne Genehmigung in diese Zone (städtische Regeln, Punkt 13 j; ATB): mit «Motorrad / Roller» in der Garage antwortet GateLR mit Ja. In den anderen ZTL von Bergamo brauchen sie eine Genehmigung.")],
         extra_links=[link("City of Bergamo: from 21 June 2026 ZTL 10–24 on Sundays and holidays", "Comune di Bergamo: dal 21 giugno 2026 ZTL 10–24 domenica e festivi",
                           "Stadt Bergamo: ab 21. Juni 2026 ZTL 10–24 Uhr an Sonn- und Feiertagen", NEWS_HOLIDAYS)]),
    zone("bergamo-valverde", ("Valverde · below Porta San Lorenzo", "Valverde · sotto porta San Lorenzo", "Valverde · unterhalb der Porta San Lorenzo"),
         "ztl-valverde",
         [window(MON_FRI, 0, hm(7)), window(MON_FRI, hm(9, 30), hm(15, 45)), window(MON_FRI, hm(19, 30), hm(24)),
          window([7, 1], 0, hm(24))],
         "via Mairone da Ponte tra via Valverde e porta S. Lorenzo tutti i giorni feriali da lunedì a venerdì 00:00 07:00 09:30 15:45 19:30 24:00 sabato e festivi 00:00 24:00",
         ("Via Maironi da Ponte between Via Valverde and Porta S. Lorenzo: working days Monday to Friday 00:00–07:00, 09:30–15:45, 19:30–24:00; Saturdays and holidays 00:00–24:00",
          "Via Maironi da Ponte zwischen Via Valverde und Porta S. Lorenzo: Werktage Montag bis Freitag 00:00–07:00, 09:30–15:45, 19:30–24:00; Samstag und Feiertage 00:00–24:00"),
         ("The road from Valverde up to Porta San Lorenzo is open to everyone only Monday to Friday 7–9:30 am and 3:45–7:30 pm; the rest of the time, and all day on Saturdays, Sundays and holidays, it is closed to unauthorised vehicles.",
          "La strada da Valverde a porta San Lorenzo è aperta a tutti solo dal lunedì al venerdì 7–9:30 e 15:45–19:30; nel resto del tempo, e tutto il giorno il sabato, la domenica e i festivi, è chiusa ai veicoli non autorizzati.",
          "Die Straße von Valverde zur Porta San Lorenzo ist nur Montag bis Freitag 7–9:30 und 15:45–19:30 Uhr für alle offen; sonst und ganztägig an Samstagen, Sonn- und Feiertagen für nicht berechtigte Fahrzeuge gesperrt."),
         ["valverde"], holidays=True),
    zone("bergamo-xx-settembre", ("Via XX Settembre · Sant'Alessandro, Piazza Pontida", "Via XX Settembre · Sant'Alessandro, piazza Pontida",
                                  "Via XX Settembre · Sant'Alessandro, Piazza Pontida"),
         "ztl-xx-settembre-pontida", [ALL_DAY],
         "via XX Settembre tutta tutti i giorni 00:00 24:00",
         ("Via XX Settembre, the whole street, every day 00:00–24:00", "Via XX Settembre, die ganze Straße, täglich 00:00–24:00"),
         ("The shopping streets of the lower town (Via XX Settembre, Via Sant'Alessandro, Piazza Pontida and nearby) are closed to unauthorised vehicles 24 hours a day.",
          "Le vie dello shopping della Città Bassa (via XX Settembre, via Sant'Alessandro, piazza Pontida e vicine) sono chiuse ai veicoli non autorizzati 24 ore su 24.",
          "Die Einkaufsstraßen der Unterstadt (Via XX Settembre, Via Sant'Alessandro, Piazza Pontida und Umgebung) sind rund um die Uhr für nicht berechtigte Fahrzeuge gesperrt."),
         ["settembre", "pontida"]),
    zone("bergamo-tasso-pignolo", ("Via Tasso · Via Pignolo", "Via Tasso · via Pignolo", "Via Tasso · Via Pignolo"),
         "ztl-tasso-pignolo", [ALL_DAY],
         "via Tasso da Contrada dei Tre Passi a piazzetta Santo Spirito tutti i giorni 00:00 24:00",
         ("Via Tasso from Contrada dei Tre Passi to Piazzetta Santo Spirito, every day 00:00–24:00",
          "Via Tasso von der Contrada dei Tre Passi bis zur Piazzetta Santo Spirito, täglich 00:00–24:00"),
         ("Via Tasso, Piazzetta Santo Spirito and Via Pignolo between Via Verdi and Via Camozzi are closed to unauthorised vehicles 24 hours a day.",
          "Via Tasso, piazzetta Santo Spirito e via Pignolo tra via Verdi e via Camozzi sono chiuse ai veicoli non autorizzati 24 ore su 24.",
          "Via Tasso, Piazzetta Santo Spirito und Via Pignolo zwischen Via Verdi und Via Camozzi sind rund um die Uhr für nicht berechtigte Fahrzeuge gesperrt."),
         ["tasso"]),
    zone("bergamo-donizetti", ("Teatro Donizetti · Largo Gavazzeni, Piazza Matteotti", "Teatro Donizetti · largo Gavazzeni, piazza Matteotti",
                               "Teatro Donizetti · Largo Gavazzeni, Piazza Matteotti"),
         "ztl-gavazzeni-donizetti", [ALL_DAY],
         "largo Gavazzeni davanti al Donizetti tutti i giorni 00:00 24:00",
         ("Largo Gavazzeni in front of the Donizetti theatre, every day 00:00–24:00", "Largo Gavazzeni vor dem Teatro Donizetti, täglich 00:00–24:00"),
         ("The square in front of the Donizetti theatre (Largo Gavazzeni, Largo Belotti, Piazza Cavour and Piazza Matteotti between Via Roma and Via Tasso) is closed to unauthorised vehicles 24 hours a day.",
          "La piazza davanti al teatro Donizetti (largo Gavazzeni, largo Belotti, piazza Cavour e piazza Matteotti tra via Roma e via Tasso) è chiusa ai veicoli non autorizzati 24 ore su 24.",
          "Der Platz vor dem Teatro Donizetti (Largo Gavazzeni, Largo Belotti, Piazza Cavour und Piazza Matteotti zwischen Via Roma und Via Tasso) ist rund um die Uhr für nicht berechtigte Fahrzeuge gesperrt."),
         ["donizetti"]),
    zone("bergamo-matteotti", ("Piazza Matteotti · Via Borfuro, Via Crispi", "Piazza Matteotti · via Borfuro, via Crispi", "Piazza Matteotti · Via Borfuro, Via Crispi"),
         "ztl-matteotti-borfuro", [ALL_DAY],
         "piazza Matteotti tutta tutti i giorni 00:00 24:00",
         ("Piazza Matteotti, the whole square, every day 00:00–24:00", "Piazza Matteotti, der ganze Platz, täglich 00:00–24:00"),
         ("Piazza Matteotti (City Hall), Via Borfuro, Via Crispi and Passaggio Zeduri are closed to unauthorised vehicles 24 hours a day.",
          "Piazza Matteotti (Municipio), via Borfuro, via Crispi e passaggio Zeduri sono chiusi ai veicoli non autorizzati 24 ore su 24.",
          "Piazza Matteotti (Rathaus), Via Borfuro, Via Crispi und Passaggio Zeduri sind rund um die Uhr für nicht berechtigte Fahrzeuge gesperrt."),
         ["borfuro"]),
    zone("bergamo-pelabrocco", ("Via Pelabrocco · Città Alta", "Via Pelabrocco · Città Alta", "Via Pelabrocco · Città Alta"),
         "ztl-pelabrocco", [ALL_DAY],
         "via Pelabrocco in tutta la ZTL tutti i giorni 00:00 24:00",
         ("Via Pelabrocco, the whole ZTL, every day 00:00–24:00", "Via Pelabrocco, die ganze ZTL, täglich 00:00–24:00"),
         ("Via Pelabrocco is closed to unauthorised vehicles 24 hours a day.", "Via Pelabrocco è chiusa ai veicoli non autorizzati 24 ore su 24.",
          "Die Via Pelabrocco ist rund um die Uhr für nicht berechtigte Fahrzeuge gesperrt."),
         ["pelabrocco"]),
    zone("bergamo-piazza-dante", ("Piazza Dante · pedestrian area", "Piazza Dante · area pedonale", "Piazza Dante · Fußgängerzone"),
         "ztl-piazza-dante", [ALL_DAY],
         "piazza Dante area pedonalizzata tutti i giorni 00:00 24:00",
         ("Piazza Dante, pedestrianised area, every day 00:00–24:00", "Piazza Dante, Fußgängerbereich, täglich 00:00–24:00"),
         ("Piazza Dante is a pedestrian area, closed to vehicles 24 hours a day.", "Piazza Dante è area pedonale, chiusa ai veicoli 24 ore su 24.",
          "Die Piazza Dante ist Fußgängerzone und rund um die Uhr für Fahrzeuge gesperrt."),
         ["dante"]),
    zone("bergamo-marconi", ("Piazzale Marconi · station taxi and bus lanes", "Piazzale Marconi · corsie taxi e bus della stazione",
                             "Piazzale Marconi · Taxi- und Busspuren am Bahnhof"),
         "ztl-piazzale-marconi", [ALL_DAY],
         "piazzale Marconi (corsie taxi/bus) in tutta la ZTL tutti i giorni 00:00 24:00",
         ("Piazzale Marconi (taxi/bus lanes), the whole ZTL, every day 00:00–24:00", "Piazzale Marconi (Taxi-/Busspuren), die ganze ZTL, täglich 00:00–24:00"),
         ("The taxi and bus lanes in front of the railway station are camera-controlled 24 hours a day: don't drive into them to drop someone off.",
          "Le corsie taxi e bus davanti alla stazione sono controllate dalle telecamere 24 ore su 24: non entrarci per accompagnare qualcuno.",
          "Die Taxi- und Busspuren vor dem Bahnhof werden rund um die Uhr per Kamera überwacht: nicht hineinfahren, um jemanden abzusetzen."),
         ["marconi"]),
    zone("bergamo-pignolo-alta", ("Via Pignolo Alta · San Tomaso, night", "Via Pignolo Alta · San Tomaso, notte", "Via Pignolo Alta · San Tomaso, nachts"),
         "ztl-pignolo-alta", [NIGHT_23_7],
         "via Pignolo Alta in tutta la ZTL tutti i giorni 23:00 07:00",
         ("Via Pignolo Alta, the whole ZTL, every day 23:00–07:00", "Via Pignolo Alta, die ganze ZTL, täglich 23:00–07:00"),
         ("Upper Via Pignolo, Via San Tomaso and nearby streets are closed to unauthorised vehicles every night from 11 pm to 7 am.",
          "Via Pignolo alta, via San Tomaso e le vie vicine sono chiuse ai veicoli non autorizzati ogni notte dalle 23 alle 7.",
          "Obere Via Pignolo, Via San Tomaso und Nachbarstraßen sind jede Nacht von 23 bis 7 Uhr für nicht berechtigte Fahrzeuge gesperrt."),
         ["tommaso"]),
    zone("bergamo-san-bernardino", ("Borgo San Leonardo · Via San Bernardino, night", "Borgo San Leonardo · via San Bernardino, notte",
                                    "Borgo San Leonardo · Via San Bernardino, nachts"),
         "ztl-san-bernardino", [NIGHT_23_7],
         "largo Cinque Vie tutto tutti i giorni 23:00 07:00",
         ("Largo Cinque Vie, all of it, every day 23:00–07:00", "Largo Cinque Vie, ganz, täglich 23:00–07:00"),
         ("Largo Cinque Vie, Via San Bernardino, Via Quarenghi and nearby streets of Borgo San Leonardo are closed to unauthorised vehicles every night from 11 pm to 7 am.",
          "Largo Cinque Vie, via San Bernardino, via Quarenghi e le vie vicine di Borgo San Leonardo sono chiuse ai veicoli non autorizzati ogni notte dalle 23 alle 7.",
          "Largo Cinque Vie, Via San Bernardino, Via Quarenghi und Nachbarstraßen im Borgo San Leonardo sind jede Nacht von 23 bis 7 Uhr für nicht berechtigte Fahrzeuge gesperrt."),
         ["bernardino"]),
    zone("bergamo-borgo-palazzo", ("Via Borgo Palazzo · night", "Via Borgo Palazzo · notte", "Via Borgo Palazzo · nachts"),
         "ztl-borgo-palazzo", [NIGHT_23_7],
         "via Borgo Palazzo tra via Madonna della Neve e via Frizzoni tutti i giorni 23:00 07:00",
         ("Via Borgo Palazzo between Via Madonna della Neve and Via Frizzoni, every day 23:00–07:00",
          "Via Borgo Palazzo zwischen Via Madonna della Neve und Via Frizzoni, täglich 23:00–07:00"),
         ("Via Borgo Palazzo between Via Madonna della Neve and Via Frizzoni is closed to unauthorised vehicles every night from 11 pm to 7 am (no cameras).",
          "Via Borgo Palazzo tra via Madonna della Neve e via Frizzoni è chiusa ai veicoli non autorizzati ogni notte dalle 23 alle 7 (senza telecamere).",
          "Die Via Borgo Palazzo zwischen Via Madonna della Neve und Via Frizzoni ist jede Nacht von 23 bis 7 Uhr für nicht berechtigte Fahrzeuge gesperrt (ohne Kameras)."),
         ["borgo palazzo"]),
    zone("bergamo-san-francesco", ("Via San Francesco d'Assisi · night", "Via San Francesco d'Assisi · notte", "Via San Francesco d'Assisi · nachts"),
         "ztl-san-francesco", [window(EVERY_DAY, hm(22), hm(7))],
         "via San Francesco d'Assisi tutta tutti i giorni 22:00 07:00",
         ("Via San Francesco d'Assisi, the whole street, every day 22:00–07:00", "Via San Francesco d'Assisi, die ganze Straße, täglich 22:00–07:00"),
         ("Via San Francesco d'Assisi is closed to unauthorised vehicles every night from 10 pm to 7 am (no cameras).",
          "Via San Francesco d'Assisi è chiusa ai veicoli non autorizzati ogni notte dalle 22 alle 7 (senza telecamere).",
          "Die Via San Francesco d'Assisi ist jede Nacht von 22 bis 7 Uhr für nicht berechtigte Fahrzeuge gesperrt (ohne Kameras)."),
         ["francesco"]),
    zone("bergamo-raboni", ("Via Raboni · evening", "Via Raboni · sera", "Via Raboni · abends"),
         "ztl-raboni", [window(EVERY_DAY, hm(17, 30), hm(19, 30))],
         "via Raboni tra via Bassani e via Boves tutti i giorni 17:30 19:30",
         ("Via Raboni between Via Bassani and Via Boves, every day 17:30–19:30", "Via Raboni zwischen Via Bassani und Via Boves, täglich 17:30–19:30"),
         ("Via Raboni between Via Bassani and Via Boves is closed to unauthorised vehicles every day from 5:30 to 7:30 pm (no cameras).",
          "Via Raboni tra via Bassani e via Boves è chiusa ai veicoli non autorizzati tutti i giorni dalle 17:30 alle 19:30 (senza telecamere).",
          "Die Via Raboni zwischen Via Bassani und Via Boves ist täglich von 17:30 bis 19:30 Uhr für nicht berechtigte Fahrzeuge gesperrt (ohne Kameras)."),
         ["raboni"]),
    zone("bergamo-orio", ("Via Orio · near the airport", "Via Orio · vicino all'aeroporto", "Via Orio · beim Flughafen"),
         "ztl-orio", [window(MON_FRI, 0, hm(7)), window(MON_FRI, hm(9, 30), hm(24)), window([7, 1], 0, hm(24))],
         "via Orio tra l’ingresso dall’asse interurbano e l’ingresso dei civici 21-33 dal lunedì al venerdì 00:00 07:00 09:30 24:00 sabato e domenica 00:00 24:00",
         ("Via Orio between the access from the Asse interurbano and the entrance of nos. 21–33: Monday to Friday 00:00–07:00 and 09:30–24:00; Saturday and Sunday 00:00–24:00",
          "Via Orio zwischen der Zufahrt von der Asse interurbano und der Einfahrt der Hausnummern 21–33: Montag bis Freitag 00:00–07:00 und 09:30–24:00; Samstag und Sonntag 00:00–24:00"),
         ("A stretch of Via Orio is open to traffic only Monday to Friday 7–9:30 am; the rest of the time it is closed to unauthorised vehicles (no cameras).",
          "Un tratto di via Orio è aperto al traffico solo dal lunedì al venerdì 7–9:30; nel resto del tempo è chiuso ai veicoli non autorizzati (senza telecamere).",
          "Ein Abschnitt der Via Orio ist nur Montag bis Freitag 7–9:30 Uhr befahrbar; sonst für nicht berechtigte Fahrzeuge gesperrt (ohne Kameras)."),
         ["orio"]),
]


# --- geometria ufficiale (dati aperti del Comune) ---

def plain(s):
    return unicodedata.normalize("NFKD", str(s)).encode("ascii", "ignore").decode().lower()


def od_features():
    for f in (RAW / f"opendata-{OD_ID}-zone-traffico-limitato.geojson", GEO / f"bergamo-od-{OD_ID}.geojson"):
        if f.exists():
            return json.loads(f.read_text(encoding="utf-8"))["features"]
    return []


def rings(geom):
    if not geom:
        return []
    if geom["type"] == "Polygon":
        return [geom["coordinates"][0]]
    if geom["type"] == "MultiPolygon":
        return [p[0] for p in geom["coordinates"]]
    return []


def od_shapes(feats, words, taken):
    """I poligoni (anello esterno di ogni parte) delle feature ufficiali il cui «nome_ztl» contiene una delle parole,
    dal più grande al più piccolo: una zona fatta di più pezzi (Città Alta e Colli) diventa più zone con le stesse regole"""
    hits = [f for f in feats if id(f) not in taken and rings(f.get("geometry"))
            and any(re.search(r"\b" + re.escape(w) + r"\b", plain(f["properties"].get("nome_ztl", ""))) for w in words)]
    out = []
    for f in hits:
        taken.add(id(f))
        out += [(osm_geo.perimeter([tuple(p[:2]) for p in r], tol_m=2), f["properties"]) for r in rings(f["geometry"])]
    return sorted(out, key=lambda x: -osm_geo.area_km2(x[0]))


def source(z):
    check(z["file"], z["quote"])
    pending = list(COMMON_PENDING) + z["extra_pending"] + ([HOLIDAY_NOTE] if z["holidays"] else [])
    return {"authority": AUTHORITY, "pageURL": url_of(z["file"]),
            "ordinance": "Delibera GC n. 798 del 30/12/2024 e ordinanza n. 3 del 03/01/2025 (contrassegni ZTL)", "ordinanceURL": DOC_OP,
            "quote": z["quote"], "quoteTranslation": z["translation"][0], "quoteTranslation_de": z["translation"][1],
            "checkedOn": CHECKED, "reviewedByHuman": False,
            "pending": [p[0] for p in pending], "pending_it": [p[1] for p in pending], "pending_de": [p[2] for p in pending],
            "links": [link("City of Bergamo: this ZTL (hours and gates)", "Comune di Bergamo: questa ZTL (orari e varchi)",
                           "Stadt Bergamo: diese ZTL (Zeiten und Kameras)", url_of(z["file"]))] + LINKS + z["extra_links"] + [GEO_LINK]}


feats = od_features()
taken, zones, skipped = set(), [], []
for z in ZONES:
    shapes = od_shapes(feats, z["match"], taken) or [([], None)]
    for i, (shape, props) in enumerate(shapes):
        out = {"id": z["zid"] + (f"-{i + 1}" if i else ""), "name": z["name"][0], "name_it": z["name"][1], "name_de": z["name"][2],
               "kind": "restricted", "summary": z["summary"][0], "summary_it": z["summary"][1], "summary_de": z["summary"][2],
               "perimeter": shape, "gates": [], "windows": z["windows"],
               "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": True, "source": source(z)}
        # «j) Ciclomotori e motocicli esclusivamente per la ZTL festiva e serale di Città Alta Colli» (documento operativo)
        if z["zid"] == "bergamo-colli":
            out["exemptVehicleTypes"] = ["motorcycle"]
        if z["holidays"]:
            out["holidaysAsSunday"] = True
        (zones if shape else skipped).append(out)
        print(f"{out['id']:26s}", f"{len(shape)} punti, {osm_geo.area_km2(shape):.4f} km²" if shape else "nessun perimetro ufficiale",
              (props or {}).get("nome_ztl", ""))
assert not [f["properties"]["nome_ztl"] for f in feats if id(f) not in taken and f["properties"]["periodo"] in ("Permanente", "Notturna", "Annuale", "Pedonale")], \
    "zona ufficiale permanente/notturna/annuale/pedonale non usata"

# Controlli di plausibilità: un punto famoso dentro, la stazione fuori
POINTS = {"bergamo-citta-alta": ("Piazza Vecchia", 45.7037, 9.6625), "bergamo-xx-settembre": ("Via XX Settembre", 45.6935, 9.6680),
          "bergamo-colli": ("Via San Vigilio", 45.7055, 9.6505)}
STATION = (45.6905, 9.6755)
for z in zones:
    if z["id"] in POINTS:
        n, lat, lon = POINTS[z["id"]]
        assert osm_geo.contains(z["perimeter"], lat, lon), f"{z['id']}: {n} non è dentro il perimetro"
    if z["id"] != "bergamo-marconi":
        assert not osm_geo.contains(z["perimeter"], *STATION), f"{z['id']}: la stazione risulta dentro"

city = {"id": "bergamo", "name": "Bergamo", "name_it": "Bergamo", "name_de": "Bergamo",
        "center": {"lat": 45.7037, "lon": 9.6625}, "zones": zones or skipped, "status": "draft",
        "license": "Rules: Comune di Bergamo and ATB Mobilità official pages and documents. Perimeters: Comune di Bergamo open data (dati.lombardia.it dataset tkwz-spd9, Italian Open Data License 2.0; listed as public domain on comune.bergamo.it)."}

ready = bool(zones)
out = ROOT / ("Resources/Cities/bergamo.json" if ready else "data/drafts/bergamo.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/bergamo.json" if ready else "Resources/Cities/bergamo.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), len(zones), "zone con perimetro;", len(skipped), "senza:", [z["id"] for z in skipped])
