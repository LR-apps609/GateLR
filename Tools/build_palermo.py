#!/usr/bin/env python3
# Costruisce Resources/Cities/palermo.json dagli atti e dalle pagine ufficiali del Comune di Palermo e di AMAT Palermo
# salvati in data/raw/palermo/ (fonti e date in docs/fonti-palermo.md).
# Ogni frase citata viene ricontrollata parola per parola sui testi salvati: se il Comune cambia la pagina, lo script si ferma.
#
# Regole: «Disciplinare Tecnico della ZTL Centrale» approvato con D.G.C. n. 122 del 30/05/2024 e applicato dall'O.D. n. 802
# del 27/06/2024 (dal 01/07/2024); tariffe e canali di vendita dalla pagina AMAT «La ZTL, tempi e perimetro» e dalla scheda
# del Comune «Richiedere permesso di accesso ad area ZTL».
# Geometria: perimetro UFFICIALE dal KML della Polizia Municipale (docs.comune.palermo.it/kml/ZTL_2019.kmz, caricato dalla
# pagina «Info e Mappa»), salvato in data/raw/palermo/ZTL_2019.kml: si usa il poligono principale «ZTL» (gli altri sono
# isolati più piccoli fuori dal bordo, separati da strade di libero transito: vedi pending).
# Aree pedonali di via Maqueda e del Cassaro: way OpenStreetMap highway=pedestrian (data/raw/palermo/osm-pedonali-centro.json,
# © OpenStreetMap contributors, ODbL 1.0), trasformate in un'area con osm_geo.street_area.
#
# Uso: python3 Tools/build_palermo.py   (scrive solo palermo.json: non tocca le altre città né manifest.json)
import json, math, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/palermo"
CHECKED = "2026-10-26T09:00:00Z"
AUTHORITY = "City of Palermo"

MON_THU, FRI, SAT = [2, 3, 4, 5], [6], [7]
SUMMER = {"fromMonth": 5, "fromDay": 1, "toMonth": 10, "toDay": 31}
WINTER = {"fromMonth": 11, "fromDay": 1, "toMonth": 4, "toDay": 30}

AMAT_PAGE = "https://www.amat.pa.it/la-ztl-tempi-e-perimetro-2/"
PM_PAGE = "https://repository.comune.palermo.it/polizia-municipale-info.php"
PORTAL = "https://ztl.comune.palermo.it/"
BUY = "https://www.comune.palermo.it/servizio/richiedere-permesso-di-accesso-ad-area-ztl-31/"
DISCIPLINARE = "https://ztl.comune.palermo.it/ztl//docs/news/82053/A2024/M08/G07/disciplinare_tecnico_ztl_maggio_2024.pdf"
OD802 = "https://www.amat.pa.it/documenti/Moduli/2025_03_20/2025_03_20-DISCIPLINARE_TECNICO_ZTL_MAGGIO_2024.pdf"
KMZ = "https://docs.comune.palermo.it/kml/ZTL_2019.kmz"
AMAT_NEWS = "https://www.amat.pa.it/category/ztl/"


def norm(s):
    return re.sub(r"\s+", " ", s).strip()


TEXT = {p.stem: norm(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}
TEXT["ZTL_2019"] = norm((RAW / "ZTL_2019.kml").read_text(encoding="utf-8"))


def check(file, *quotes):
    """Ogni frase citata deve comparire, parola per parola, nel documento ufficiale salvato"""
    for q in quotes:
        assert norm(q) in TEXT[file], f"{file}: frase non trovata, ricontrollare il documento: {q!r}"


def hm(h, m=0):
    return h * 60 + m


def window(days, start, end, season=None):
    w = {"weekdays": days, "start": start, "end": end}
    if season:
        w["season"] = season
    return w


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


Q_HOURS = ("La “ZTL Centrale” ha validità esclusivamente nei giorni della settimana, secondo le seguenti modalità: "
           "▪ dal lunedì al giovedì nella fascia oraria 8,00-20,00; ✓ dall’1 maggio al 31 ottobre: ▪ il venerdì nelle fasce orarie 08,00-24,00; "
           "▪ il sabato nelle fasce orarie 0,00-06,00 e 20.00-24.00; ▪ la domenica nella fascia oraria 0,00-06,00; "
           "✓ dall’1 novembre al 30 aprile: ▪ il venerdì nelle fasce orarie 08,00-20,00 e 23,00-24,00; "
           "▪ il sabato nelle fasce orarie 0,00-06,00 e 23.00-24.00; ▪ la domenica nella fascia oraria 0,00-06,00;")
Q_HOURS_EN = ("The 'ZTL Centrale' applies only on the days of the week, as follows: ▪ Monday to Thursday 8:00–20:00; "
              "✓ from 1 May to 31 October: ▪ Friday 08:00–24:00; ▪ Saturday 0:00–06:00 and 20:00–24:00; ▪ Sunday 0:00–06:00; "
              "✓ from 1 November to 30 April: ▪ Friday 08:00–20:00 and 23:00–24:00; ▪ Saturday 0:00–06:00 and 23:00–24:00; ▪ Sunday 0:00–06:00;")
Q_HOURS_DE = ("Die „ZTL Centrale“ gilt ausschließlich an den Wochentagen, wie folgt: ▪ Montag bis Donnerstag 8–20 Uhr; "
              "✓ vom 1. Mai bis 31. Oktober: ▪ Freitag 8–24 Uhr; ▪ Samstag 0–6 und 20–24 Uhr; ▪ Sonntag 0–6 Uhr; "
              "✓ vom 1. November bis 30. April: ▪ Freitag 8–20 und 23–24 Uhr; ▪ Samstag 0–6 und 23–24 Uhr; ▪ Sonntag 0–6 Uhr;")


def checks():
    D = "disciplinare-tecnico-ztl-maggio-2024"
    check(D, Q_HOURS,
          "Autorizzazione interdetta ai veicoli “inquinanti” - motori a benzina: categoria euro 0, 1, 2 - motori diesel: categoria euro 0, 1, 2,3;",
          "Autorizzazione permessa ai veicoli “meno inquinanti” - motori a benzina: categoria euro 3 o superiore - motori diesel: categoria euro 4 o superiore;",
          "I permessi giornalieri potranno essere convalidati anche a posteriori con le seguenti modalità: − dal lunedì al giovedì entro le ore 24,00 del giorno in cui è stato effettuato il transito; − dal venerdì alla domenica entro le ore 6,00 del periodo per cui è stato effettuato il transito notturno;",
          "devono essere attivati dopo le ore 06:00 del sabato.",
          "Gli attraversamenti multipli dei varchi attivi eseguiti nell’arco temporale di 15 minuti saranno considerati come un unico ingresso.",
          "e) velocipedi, ciclomotori e motocicli, inclusi i quadricicli;",
          "La registrazione avverrà a cura dell’AMAT a seguito della richiesta di accreditamento da parte della direzione della struttura ricettiva",
          "Il primo accesso per carico e scarico bagagli e l’uscita a conclusione del soggiorno sono gratuiti.",
          "Contrassegno: mensile € 30,00 - Settimanale € 15,00 -giornaliero € 5,00",
          "È possibile richiedere un numero di inserimenti in lista bianca non superiore alla capienza della struttura ricettiva",
          "Contrassegno: annuale € 50,00 - semestrale € 25,00 - mensile € 10,00 - giornaliero € 2,50",
          "Inserimento in “Lista bianca” e rilascio del contrassegno gratuiti",
          "fermo restando che la viabilità perimetrale è esterna alla Zona a Traffico Limitato (e quindi a libero transito)")
    check("amat-ztl-tempi-e-perimetro", "Non saranno attive limitazioni nei giorni di domenica e festivi.",
          "Per tutti, con vetture a benzina (da Euro 3 a Euro 6) e a diesel (da Euro 4 a Euro 6) – 5 euro, di colore azzurro",
          "Per tutti, con vetture ibride benzina/elettrico, benzina/metano e benzina/gpl – 2,50 euro, di colore verde",
          "Il pass per le auto elettriche è sempre gratuito.",
          "Si ricorda che il pass giornaliero deve essere attivato PRIMA DI ENTRARE nella ZTL",
          "L’attivazione tramite SMS avviene inviando un messaggio al numero 339.9942927 scrivendo ZTL (spazio) targa (spazio) codice segreto univoco.",
          "Le istruzioni sono riportate in italiano e inglese sul retro dei tagliandi.",
          "Rivendite autorizzate AMAT")
    check("ZTL_2019", "Giorni feriali dal lunedi al venerdì frascia oraria 08:00 - 20:00", "Libero Transito")
    check("pm-info-e-mappa", "https://docs.comune.palermo.it/kml/ZTL_2019.kmz", "Il pass per le auto elettriche è sempre gratuito.",
          "I pass giornalieri possono essere Acquistati On-Line, presso le rivendite autorizzate o tramite. l’App PalerMobilità")
    check("comune-richiedere-permesso-ztl", "non è possibile consumare un pass a posteriori rispetto alla data di accesso alla ZTL;",
          "con vetture a benzina (da Euro 3 a Euro 6) e a diesel (da Euro 4 a Euro 6) – 5 euro",
          "L'ingresso in ZTL è gratuito per auto elettriche e per i cittadini con limitata o impedita capacità.")
    check("portale-orari-ztl", "il venerdì nelle fasce orarie 08.00-20.00 e 23.00-24.00")
    check("portale-cellulare-estero", "utilizzare l'APP palermobilita o il canale WEB")
    check("amat-festino-2026", "la sospensione temporanea della ZTL fino alle ore 8 di giovedì 16 luglio")
    check("comune-festino-2025", "ha disposto la sospensione della ZTL diurna e notturna del 14 luglio e del 15 luglio 2025")
    check("amat-notizie-ztl", "la ZTL CENTRALE – PALERMO sarà temporaneamente sospesa",
          "la ZTL viene sospesa dal 22 dicembre a tutto il 1 gennaio 2026")
    check("amat-cude-non-residenti", "preventivamente o entro quindici (15) giorni dal momento in cui è stato effettuato il transito")
    check("comune-telepass-2026", "A partire dal 4 maggio sarà possibile accedere alle Zone a Traffico Limitato pagando automaticamente tramite app Telepass.")
    check("od-1080-2026-carico-scarico", "con deliberazione n. 22 del 06/02/2026 la Giunta Comunale, ha esteso i tratti stradali di libero transito e pedonalizzazione di nuovi tratti stradali all’interno della ZTL Centrale;")
    check("od-15-2026-mondello", "Istituzione di un’area pedonale e di una ZTL nella borgata marinara di Mondello")


LINKS = [link("Palermo: ZTL hours, map and passes (AMAT)", "Palermo: ZTL, orari, perimetro e pass (AMAT)", "Palermo: ZTL, Zeiten, Grenze und Pässe (AMAT)", AMAT_PAGE),
         link("Palermo: buy a day pass online (City of Palermo, SPID/CIE)", "Palermo: comprare il pass giornaliero online (Comune, SPID/CIE)",
              "Palermo: Tagespass online kaufen (Stadt, SPID/CIE)", BUY),
         link("Palermo: ZTL portal (passes, activation, notices)", "Palermo: portale ZTL (pass, attivazione, avvisi)", "Palermo: ZTL-Portal (Pässe, Aktivierung, Hinweise)", PORTAL),
         link("Palermo: official ZTL map (Municipal Police)", "Palermo: mappa ufficiale della ZTL (Polizia Municipale)", "Palermo: offizielle ZTL-Karte (Stadtpolizei)", PM_PAGE),
         link("Palermo: ZTL Centrale rules (Disciplinare Tecnico 2024, PDF)", "Palermo: Disciplinare Tecnico della ZTL Centrale 2024 (PDF)",
              "Palermo: Regeln der ZTL Centrale (Disciplinare Tecnico 2024, PDF)", DISCIPLINARE),
         link("Palermo: ZTL suspensions and news (AMAT)", "Palermo: sospensioni e notizie sulla ZTL (AMAT)", "Palermo: Aussetzungen und Neuigkeiten zur ZTL (AMAT)", AMAT_NEWS)]

PENDING = [
    ("Perimeter from the city's official map (Municipal Police KML «ZTL_2019», still the map on its «Info e Mappa» page). GateLR uses its main outline; about 24 small blocks just outside it (along the southern edge near Corso Tukory, near Porta Nuova and near via Cavour) are also marked ZTL on that map and are not shown. The perimeter streets themselves are free. In February 2026 the city (Giunta resolution 22/2026) extended the free-transit streets (e.g. around piazza Verdi and via Cadorna–via del Bastione) and moved some gates: the official map does not show this yet.",
     "Perimetro dalla mappa ufficiale del Comune (KML «ZTL_2019» della Polizia Municipale, ancora quella della pagina «Info e Mappa»). GateLR usa il contorno principale; una ventina di piccoli isolati appena fuori (sul bordo sud verso corso Tukory, presso Porta Nuova e presso via Cavour) sono segnati come ZTL sulla stessa mappa e non sono mostrati. Le strade del perimetro sono libere. Con la delibera di Giunta 22 del 06/02/2026 il Comune ha esteso i tratti di libero transito (per esempio attorno a piazza Verdi e via Cadorna–via del Bastione) e spostato alcuni varchi: la mappa ufficiale non lo mostra ancora.",
     "Grenze aus der offiziellen Karte der Stadt (KML «ZTL_2019» der Stadtpolizei, noch die Karte der Seite «Info e Mappa»). GateLR nutzt die Hauptgrenze; etwa 24 kleine Blöcke knapp außerhalb (am Südrand bei Corso Tukory, bei Porta Nuova und bei via Cavour) sind auf derselben Karte als ZTL markiert und hier nicht gezeigt. Die Randstraßen selbst sind frei. Mit Beschluss 22/2026 (Februar 2026) hat die Stadt freie Durchfahrtsstrecken erweitert (z. B. um die Piazza Verdi und via Cadorna–via del Bastione) und Kameras versetzt: die offizielle Karte zeigt das noch nicht."),
    ("Gate cameras: the city doesn't publish their positions, so GateLR shows none. Crossing live gates several times within 15 minutes counts as one entry.",
     "Varchi: il Comune non pubblica dove sono, quindi GateLR non li mostra. Più passaggi dai varchi attivi entro 15 minuti contano come un solo ingresso.",
     "Kameras: die Stadt veröffentlicht ihre Standorte nicht, daher zeigt GateLR keine. Mehrere Durchfahrten durch aktive Kameras innerhalb von 15 Minuten zählen als eine Einfahrt."),
    ("Public holidays: AMAT says there are no restrictions on Sundays and holidays, and the official map says «working days». Neither says whether the Friday/Saturday night band applies when that evening is a holiday; GateLR treats a night that starts on a holiday as free.",
     "Festivi: AMAT scrive che non ci sono limitazioni la domenica e nei festivi, e la mappa ufficiale dice «giorni feriali». Nessuno dei due dice se la fascia notturna del venerdì o del sabato vale quando quella sera è festiva; GateLR considera libera una notte che inizia in un giorno festivo.",
     "Feiertage: Laut AMAT gibt es sonntags und an Feiertagen keine Beschränkungen, die offizielle Karte sagt «Werktage». Keiner sagt, ob das Nachtband am Freitag oder Samstag gilt, wenn dieser Abend ein Feiertag ist; GateLR behandelt eine Nacht, die an einem Feiertag beginnt, als frei."),
    ("15 July (Santa Rosalia, patron saint): GateLR does not count it as a holiday, because the city switches the ZTL off with a separate order each year (14–15 July in 2023, 2024 and 2025; in 2026 until 8 am on 16 July). It does the same for Holy Week and Christmas (22 December–1 January in 2025/26): check AMAT's news before you drive in.",
     "15 luglio (Santa Rosalia, patrona): GateLR non lo conta come festivo, perché il Comune spegne la ZTL con un'ordinanza apposita ogni anno (14–15 luglio nel 2023, 2024 e 2025; nel 2026 fino alle 8 del 16 luglio). Lo stesso fa per la Settimana Santa e per Natale (dal 22 dicembre al 1° gennaio nel 2025/26): controlla le notizie di AMAT prima di entrare.",
     "15. Juli (Santa Rosalia, Schutzpatronin): GateLR zählt ihn nicht als Feiertag, weil die Stadt die ZTL jedes Jahr mit einer eigenen Verordnung abschaltet (14.–15. Juli 2023, 2024 und 2025; 2026 bis 8 Uhr am 16. Juli). Ebenso in der Karwoche und zu Weihnachten (22. Dezember–1. Januar 2025/26): vor der Einfahrt die AMAT-Meldungen prüfen."),
    ("Day-pass deadline: AMAT and the city portal say to activate the pass before entering, and the city's service page says it can't be used for an earlier date. The 2024 rules (and the police page) allow activation afterwards: Monday–Thursday by midnight of the day of entry, Friday–Sunday nights by 6 am. A pass for the Saturday-night band must be activated after 6 am on Saturday. With a foreign mobile number use the PalerMobilità app or the web portal, not SMS. GateLR says: before you enter.",
     "Scadenza del pass giornaliero: AMAT e il portale dicono di attivarlo prima di entrare, e la scheda del Comune dice che non si può usare per una data precedente. Il disciplinare 2024 (e la pagina della Polizia Municipale) ammettono l'attivazione dopo: dal lunedì al giovedì entro le 24 del giorno di ingresso, nelle notti da venerdì a domenica entro le 6. Il pass per la notte del sabato va attivato dopo le 6 del sabato. Con un cellulare straniero usa l'app PalerMobilità o il portale web, non l'SMS. GateLR dice: prima di entrare.",
     "Frist für den Tagespass: AMAT und das Portal sagen, ihn vor der Einfahrt zu aktivieren, die Seite der Stadt sagt, er gilt nicht rückwirkend für einen früheren Tag. Die Regeln von 2024 (und die Seite der Stadtpolizei) erlauben die Aktivierung danach: Montag–Donnerstag bis Mitternacht des Einfahrtstags, in den Nächten Freitag–Sonntag bis 6 Uhr. Ein Pass für die Samstagnacht muss nach 6 Uhr am Samstag aktiviert werden. Mit ausländischer Handynummer die App PalerMobilità oder das Webportal nutzen, nicht SMS. GateLR sagt: vor der Einfahrt."),
    ("Engines: petrol Euro 0–2 and diesel Euro 0–3 cars can't get any pass (only residents may enter with them). Hybrids and petrol/LPG or petrol/methane cars pay €2.50 a day whatever their Euro class (GateLR checks them like petrol cars). Fully electric cars: free pass, but the car must first be registered with AMAT; without it, treat it like any other car. Motorbikes and mopeds may enter freely.",
     "Motori: le auto a benzina Euro 0–2 e diesel Euro 0–3 non possono avere nessun pass (entrano solo i residenti). Ibride e auto benzina/GPL o benzina/metano pagano 2,50 € al giorno qualunque sia la classe Euro (GateLR le controlla come le auto a benzina). Auto solo elettriche: pass gratuito, ma l'auto va prima registrata presso AMAT; senza registrazione considerala come le altre. Moto e ciclomotori entrano liberamente.",
     "Motoren: Benziner Euro 0–2 und Diesel Euro 0–3 bekommen keinen Pass (nur Anwohner dürfen damit hinein). Hybride und Benzin/LPG- oder Benzin/Methan-Autos zahlen 2,50 € pro Tag, unabhängig von der Euroklasse (GateLR prüft sie wie Benziner). Reine Elektroautos: Pass kostenlos, aber das Auto muss zuerst bei AMAT registriert sein; ohne Registrierung wie andere Autos. Motorräder und Mopeds dürfen frei hinein."),
    ("Hotel guests (hotels, B&Bs and holiday homes inside the ZTL): the property asks AMAT to put your plate on the white list, even afterwards (Monday–Thursday by midnight of the day, Friday–Sunday nights by 6 am). The first entry to unload luggage and the final exit are free; for the days in between you need a pass (hotel-guest rates: €5 a day, €15 a week, €30 a month). The number of plates is limited to the property's capacity; show your booking if stopped.",
     "Ospiti delle strutture ricettive (alberghi, B&B, case vacanze dentro la ZTL): la struttura chiede ad AMAT di inserire la targa nella lista bianca, anche dopo (dal lunedì al giovedì entro le 24 del giorno, nelle notti da venerdì a domenica entro le 6). Il primo accesso per scaricare i bagagli e l'uscita a fine soggiorno sono gratuiti; per i giorni in mezzo serve un pass (tariffe clienti: 5 € al giorno, 15 € a settimana, 30 € al mese). Le targhe non possono superare la capienza della struttura; in caso di controllo mostra la prenotazione.",
     "Hotelgäste (Hotels, B&Bs und Ferienwohnungen in der ZTL): Die Unterkunft lässt dein Kennzeichen von AMAT auf die weiße Liste setzen, auch nachträglich (Montag–Donnerstag bis Mitternacht des Tages, Nächte Freitag–Sonntag bis 6 Uhr). Die erste Einfahrt zum Ausladen und die Abfahrt am Ende sind frei; für die Tage dazwischen brauchst du einen Pass (Gästetarife: 5 € pro Tag, 15 € pro Woche, 30 € pro Monat). Die Zahl der Kennzeichen ist auf die Kapazität der Unterkunft begrenzt; bei Kontrollen die Buchung zeigen."),
    ("Disabled badge holders (CUDE) from outside Palermo: e-mail the badge and the car's registration to ztlcentrale@amat.pa.it before or within 15 days of the transit, or register on the ZTL portal.",
     "Titolari di contrassegno disabili (CUDE) non residenti a Palermo: inviare contrassegno e carta di circolazione a ztlcentrale@amat.pa.it prima o entro 15 giorni dal transito, oppure registrarsi sul portale ZTL.",
     "Inhaber eines Behindertenausweises (CUDE) von außerhalb Palermos: Ausweis und Fahrzeugschein vor der Durchfahrt oder binnen 15 Tagen an ztlcentrale@amat.pa.it mailen oder sich im ZTL-Portal registrieren."),
    ("Since May 2026 the pass can also be paid automatically through the Telepass app (service active from midnight after you switch it on).",
     "Da maggio 2026 il pass si può pagare anche in automatico con l'app Telepass (il servizio parte dalla mezzanotte dopo l'attivazione).",
     "Seit Mai 2026 lässt sich der Pass auch automatisch über die Telepass-App bezahlen (aktiv ab Mitternacht nach dem Einschalten)."),
    ("Not on the map: Mondello's summer evening ZTL by the beach (8 May–30 September 2026, 8 pm–midnight, until 1 am on Saturdays and the eves of holidays; set again each year), the evening pedestrian area of via del Celso–Salita Castellana (8 pm–1 am) and many small pedestrian streets inside the centre (Vucciria, Ballarò, piazza Caracciolo and others, made permanent in 2026).",
     "Non sulla mappa: la ZTL serale estiva di Mondello (dall'8 maggio al 30 settembre 2026, 20–24, fino all'1 il sabato e nei prefestivi; rinnovata ogni anno), l'area pedonale serale di via del Celso–Salita Castellana (20–1) e molte piccole aree pedonali interne (Vucciria, Ballarò, piazza Caracciolo e altre, rese permanenti nel 2026).",
     "Nicht auf der Karte: die abendliche Sommer-ZTL von Mondello am Strand (8. Mai–30. September 2026, 20–24 Uhr, samstags und vor Feiertagen bis 1 Uhr; jedes Jahr neu), die abendliche Fußgängerzone via del Celso–Salita Castellana (20–1 Uhr) und viele kleine Fußgängerstraßen im Zentrum (Vucciria, Ballarò, piazza Caracciolo u. a., 2026 dauerhaft)."),
]

SUMMARY = ("The old centre (from the station to via Cavour, from Porta Nuova to the sea) is closed without a pass Monday to Friday 8 am–8 pm, "
           "and on Friday and Saturday nights until 6 am: from 8 pm in May–October, from 11 pm in November–April. Sundays and public holidays have no daytime restriction. "
           "Anyone can drive in with a day pass (€5; €2.50 hybrids and LPG/methane; free for registered electric cars) if the car is at least petrol Euro 3 or diesel Euro 4. "
           "Motorbikes are free. Via Maqueda and the Cassaro (corso Vittorio Emanuele) are pedestrian areas: no cars even with a pass. If your hotel is inside, it can have your plate registered for arrival and departure.")
SUMMARY_IT = ("Il centro storico (dalla stazione a via Cavour, da Porta Nuova al mare) è chiuso senza pass dal lunedì al venerdì dalle 8 alle 20, "
              "e il venerdì e il sabato notte fino alle 6: dalle 20 da maggio a ottobre, dalle 23 da novembre ad aprile. La domenica e nei festivi non c'è la fascia diurna. "
              "Chiunque può entrare con il pass giornaliero (5 €; 2,50 € ibride e GPL/metano; gratis per le elettriche registrate) se l'auto è almeno benzina Euro 3 o diesel Euro 4. "
              "Le moto entrano gratis. Via Maqueda e il Cassaro (corso Vittorio Emanuele) sono aree pedonali: niente auto, neanche con il pass. Se l'hotel è dentro, può far registrare la targa per l'arrivo e la partenza.")
SUMMARY_DE = ("Die Altstadt (vom Bahnhof bis via Cavour, von Porta Nuova bis zum Meer) ist ohne Pass Montag bis Freitag 8–20 Uhr gesperrt, "
              "dazu Freitag- und Samstagnacht bis 6 Uhr: ab 20 Uhr von Mai bis Oktober, ab 23 Uhr von November bis April. Sonntags und an Feiertagen gibt es kein Tagesband. "
              "Jeder darf mit Tagespass hinein (5 €; 2,50 € Hybride und LPG/Methan; gratis für registrierte Elektroautos), wenn das Auto mindestens Benzin Euro 3 oder Diesel Euro 4 ist. "
              "Motorräder frei. Via Maqueda und der Cassaro (corso Vittorio Emanuele) sind Fußgängerzonen: keine Autos, auch nicht mit Pass. Liegt dein Hotel innen, kann es dein Kennzeichen für An- und Abreise melden lassen.")

TICKET = {"price": 5.0,
          "howTo": "Buy it online on the city's ZTL portal or in the PalerMobilità app, at AMAT offices (e.g. Stazione Centrale, Politeama, Piazzale Ungheria car park) or authorised resellers, then activate it with your plate before you drive in (app, portal or SMS to 339 9942927 with «ZTL plate code»; with a foreign number use the app or portal). €2.50 for hybrids and LPG/methane cars. Not for petrol Euro 0–2 or diesel Euro 0–3.",
          "howTo_it": "Compralo online sul portale ZTL del Comune o nell'app PalerMobilità, negli uffici AMAT (per esempio Stazione Centrale, Politeama, parcheggio di piazzale Ungheria) o nelle rivendite autorizzate, poi attivalo con la targa prima di entrare (app, portale o SMS al 339 9942927 con «ZTL targa codice»; con un numero straniero usa l'app o il portale). 2,50 € per ibride e auto GPL/metano. Non per benzina Euro 0–2 o diesel Euro 0–3.",
          "howTo_de": "Online im ZTL-Portal der Stadt oder in der App PalerMobilità kaufen, in AMAT-Büros (z. B. Stazione Centrale, Politeama, Parkplatz Piazzale Ungheria) oder bei Verkaufsstellen, dann vor der Einfahrt mit dem Kennzeichen aktivieren (App, Portal oder SMS an 339 9942927 mit «ZTL Kennzeichen Code»; mit ausländischer Nummer App oder Portal). 2,50 € für Hybride und LPG-/Methan-Autos. Nicht für Benzin Euro 0–2 oder Diesel Euro 0–3.",
          "url": BUY, "deadline": "beforeEntry"}


def zone():
    w = [window(MON_THU + FRI, hm(8), hm(20)),
         window(FRI + SAT, hm(20), hm(6), SUMMER),
         window(FRI + SAT, hm(23), hm(6), WINTER)]
    return {"id": "palermo-centrale", "name": "Centro Storico · ZTL Centrale", "name_it": "Centro Storico · ZTL Centrale",
            "name_de": "Centro Storico · ZTL Centrale (Altstadt)", "kind": "pass",
            "summary": SUMMARY, "summary_it": SUMMARY_IT, "summary_de": SUMMARY_DE,
            "windows": w, "freeOnHolidays": True, "exemptFuels": [], "hotelCanRegister": True, "ticket": TICKET,
            "bans": [{"fuel": "petrol", "maxEuro": 2, "since": "2024-07-01"}, {"fuel": "diesel", "maxEuro": 3, "since": "2024-07-01"}],
            "source": {"authority": AUTHORITY, "pageURL": AMAT_PAGE,
                       "ordinance": "O.D. n. 802 del 27/06/2024 (Disciplinare Tecnico della ZTL Centrale, D.G.C. n. 122 del 30/05/2024)",
                       "ordinanceURL": OD802, "quote": Q_HOURS, "quoteTranslation": Q_HOURS_EN, "quoteTranslation_de": Q_HOURS_DE,
                       "checkedOn": CHECKED, "reviewedByHuman": False,
                       "pending": [p[0] for p in PENDING], "pending_it": [p[1] for p in PENDING], "pending_de": [p[2] for p in PENDING],
                       "links": LINKS + [link("Official ZTL map file (KMZ, City of Palermo)", "File della mappa ufficiale della ZTL (KMZ, Comune di Palermo)",
                                              "Offizielle ZTL-Kartendatei (KMZ, Stadt Palermo)", KMZ)]}}


def official_perimeter():
    """Il poligono «ZTL» più grande del KML ufficiale (anello [lon, lat])"""
    kml = (RAW / "ZTL_2019.kml").read_text(encoding="utf-8")
    best = []
    for pm in re.findall(r"<Placemark.*?</Placemark>", kml, re.S):
        amb = re.search(r"Ambito Territoriale</td>\s*<td>([^<]*)", pm).group(1)
        if amb != "ZTL":
            continue
        for c in re.findall(r"<outerBoundaryIs>.*?<coordinates>(.*?)</coordinates>", pm, re.S):
            ring = [tuple(map(float, p.split(",")[:2])) for p in c.split()]
            if osm_geo.area_km2(ring) > osm_geo.area_km2(best or [(0, 0), (0, 0), (0, 0)]):
                best = ring
    return best


PED = {"pa-ap-maqueda": ("Via Maqueda", ["Via Maqueda"]),
       "pa-ap-cassaro": ("Corso Vittorio Emanuele (Cassaro)", ["Via Vittorio Emanuele", "Corso Vittorio Emanuele"])}


def chain(ways):
    """Le way unite testa-coda in un'unica linea [lon, lat] (via Maqueda e il Cassaro sono strade senza diramazioni)"""
    key = lambda p: (round(p[0], 7), round(p[1], 7))
    parts = [[(n["lon"], n["lat"]) for n in w["geometry"]] for w in ways]
    line = parts.pop(0)
    while parts:
        for i, q in enumerate(parts):
            if key(q[0]) == key(line[-1]): line += q[1:]
            elif key(q[-1]) == key(line[-1]): line += q[-2::-1]
            elif key(q[-1]) == key(line[0]): line = q[:-1] + line
            elif key(q[0]) == key(line[0]): line = q[:0:-1] + line
            else: continue
            parts.pop(i)
            break
        else:
            raise SystemExit("Le way pedonali non formano una linea unica")
    return line


def band(line, half_m=6.0):
    """Striscia larga 2·half_m attorno alla linea (lati sfalsati con angoli smussati), anello [lon, lat] chiuso"""
    fwd, back = osm_geo._proj(sum(p[1] for p in line) / len(line))
    xy = [fwd(*p) for p in line]
    def normal(a, b):
        dx, dy = b[0] - a[0], b[1] - a[1]
        n = math.hypot(dx, dy) or 1
        return (-dy / n, dx / n)
    left, right = [], []
    for i, p in enumerate(xy):
        ns = [normal(xy[i - 1], p)] if i > 0 else []
        ns += [normal(p, xy[i + 1])] if i < len(xy) - 1 else []
        nx, ny = sum(n[0] for n in ns) / len(ns), sum(n[1] for n in ns) / len(ns)
        k = math.hypot(nx, ny) or 1
        left.append((p[0] + nx / k * half_m, p[1] + ny / k * half_m))
        right.append((p[0] - nx / k * half_m, p[1] - ny / k * half_m))
    ring = left + right[::-1]
    return [back(*q) for q in ring + ring[:1]]


def pedestrian():
    els = json.loads((RAW / "osm-pedonali-centro.json").read_text(encoding="utf-8"))["elements"]
    out = []
    for pid, (name, names) in PED.items():
        ways = [e for e in els if e["type"] == "way" and e["tags"].get("highway") == "pedestrian" and e["tags"].get("name") in names]
        out.append({"id": pid, "name": name, "perimeter": osm_geo.perimeter(band(chain(ways)), tol_m=1)})
    return out


checks()
z = zone()
ring = official_perimeter()
z["perimeter"] = osm_geo.perimeter(ring, tol_m=3)
z["gates"] = []
order = ["id", "name", "name_it", "name_de", "kind", "summary", "summary_it", "summary_de", "perimeter", "gates",
         "windows", "freeOnHolidays", "exemptFuels", "hotelCanRegister", "ticket", "bans", "source"]
z = {k: z[k] for k in order if k in z}
peds = pedestrian()

# Controlli: un luogo famoso dentro, la stazione e un punto lontano fuori
P = z["perimeter"]
assert osm_geo.contains(P, 38.1157, 13.3618), "Quattro Canti deve stare dentro la ZTL"
assert osm_geo.contains(P, 38.1144, 13.3561), "Cattedrale deve stare dentro"
assert not osm_geo.contains(P, 38.1094, 13.3666), "Palermo Centrale (stazione) deve stare fuori"
assert not osm_geo.contains(P, 38.1250, 13.3590), "Politeama deve stare fuori"
assert 1.5 < osm_geo.area_km2(P) < 2.6, osm_geo.area_km2(P)
assert any(osm_geo.contains(a["perimeter"], 38.11912, 13.35924) for a in peds if a["id"] == "pa-ap-maqueda"), "via Maqueda (Teatro Massimo-Quattro Canti) deve essere pedonale"
assert any(osm_geo.contains(a["perimeter"], 38.11402, 13.35738) for a in peds if a["id"] == "pa-ap-cassaro"), "il Cassaro davanti alla Cattedrale deve essere pedonale"
assert not any(osm_geo.contains(a["perimeter"], 38.1170, 13.3640) for a in peds if a["id"] == "pa-ap-maqueda")

city = {"id": "palermo", "name": "Palermo", "name_it": "Palermo", "name_de": "Palermo", "center": {"lat": 38.1157, "lon": 13.3618},
        "pedestrian": peds, "zones": [z], "status": "draft",
        "license": "Hours, rules and ZTL perimeter: Comune di Palermo and AMAT Palermo (official map ZTL_2019.kmz). Pedestrian areas: " + osm_geo.ODBL + " (approximate, not official)."}
out = ROOT / "Resources/Cities/palermo.json"
(ROOT / "data/drafts/palermo.json").unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), z["id"], len(P), "punti", round(osm_geo.area_km2(P), 2), "km²", [(a["id"], len(a["perimeter"])) for a in peds])
