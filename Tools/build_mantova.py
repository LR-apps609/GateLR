#!/usr/bin/env python3
# Costruisce la scheda di Mantova (BOZZA) da quanto salvato in data/raw/mantova/ (fonti e date in docs/fonti-mantova.md).
#
# Perché è ancora una bozza (27/10/2026): nessun testo ufficiale con gli ORARI della ZTL per le auto e nessun perimetro.
# - Letto ora: le pagine di Aster (aster.mn.it, senza «www»; società del Comune che rilascia i pass ZTL): zone ZTL A, A/RU
#   (area pedonale via Roma, corso Umberto I, via Grazioli), AV (dissuasore di via Verdi), B; varchi n. 9 via Trieste e n. 10
#   corso Libertà; 5 telecamere della «Zona Rossa»; permesso orario per i turisti dall'Area Pass con PagoPA (almeno 5 giorni
#   prima); auto elettriche di altri comuni: pass di solo transito a 100 €; regolamento ZTL DCC 62/2013 (non trovato
#   online). La sola fascia oraria ufficiale è quella della ZTL per gli AUTOBUS turistici (7–19 tutti i giorni), non per le auto.
# - Ancora irraggiungibili: www.aster.mn.it e www.sut.comune.mantova.it (403 dal proxy), nextcloud-municipium.maggiolicloud.it
#   (403), pubblicazioni.comune.mantova.it (albo pretorio: connessione chiusa dal server), comune.mantova.gov.it (502).
# - sut.comune.mantova.it (senza «www») risponde, ma è solo lo sportello telematico (nessun testo sulla ZTL).
# Geometria: nessun open data (dati.lombardia.it, dati.gov.it); in OpenStreetMap (API OSM, 27/10/2026) non c'è una relazione
# della ZTL e le 99 strade con motor_vehicle=permit non coprono le vie principali: nessun perimetro affidabile. Gli elenchi di
# vie di Aster riguardano solo sottozone (A/RU, AV) e i requisiti dei pass, non il confine della ZTL A e B.
# Per pubblicarla servono: l'ordinanza/disciplinare ZTL (o il regolamento DCC 62/2013 con gli atti di Giunta) con orari di ZTL
# A e B, la procedura per gli ospiti degli hotel e l'elenco delle vie o una mappa ufficiale.
# Uso: python3 Tools/build_mantova.py   (non tocca le altre città né manifest.json)
import json, re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/mantova"
CHECKED = "2026-10-27T13:00:00Z"
EVERY_DAY = [1, 2, 3, 4, 5, 6, 7]


def flat(s):
    return re.sub(r"\s+", " ", s).strip()


TEXT = {p.stem: flat(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def check(file, *phrases):
    for q in phrases:
        if flat(q) not in TEXT[file]:
            raise SystemExit(f"{file}: frase non trovata: {q!r}")


TOPIC = "https://www.comune.mantova.it/it/topics/ztl"
DISABLED = "https://www.comune.mantova.it/it/services/prenotazione-accesso-zona-a-traffico-limitato-ztl-con-pass-disabile-altre-citta"
ASTER, ASTER_TOUR, ASTER_BUS = "https://aster.mn.it/cittadini/ztl", "https://aster.mn.it/turisti/permesso-orario-ztl", "https://aster.mn.it/turisti/bus-turistici"
check("comune-servizio-pass-disabili-altre-citta",
      "I possessori di pass disabile residenti fuori Comune che necessitano di circolare nelle zone a traffico limitato (ZTL) e sostare nei parcheggi riservati possono prenotare l'accesso.",
      "infomulte@comune.mantova.it")
check("aster-pass-ztl-persone-fisiche", "PASS PER CITTADINI CHE ABITANO NEL COMUNE DI MANTOVA", "ZTL A/RU - Area Pedonale",
      "Transito in ZTL A su percorso obbligato e vincolato alle sole 5 telecamere presenti nelle seguenti vie")
check("aster-pass-ztl-aziende", "Valido anche per il transito dai varchi n. 9 via Trieste e n. 10 corso Libertà")
check("aster-permesso-orario-ztl-turisti", "Per richiedere un permesso orario di accesso alle ZTL di Mantova", "consigliamo un anticipo di almeno 5 giorni")
check("aster-pass-auto-elettriche", "RESIDENTI O DITTE CON SEDE IN ALTRI COMUNI", "Solo Transito 100,00 €")
check("aster-bus-turistici", "regolamentato da ZTL attiva tutti i giorni dalle 7:00 alle 19:00")
check("websearch-27-ottobre-2026", "telecamere attive tutti i giorni 24 ore su 24", "Corso della Libertà e via Trieste aperti a tutti 7–12 e 18–21",
      "voucher ZTL 2,60 € per 24 ore")


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


PENDING = [
    ("Hours for cars confirmed only by unofficial guides (accessibilitacentristorici.it, tyremap.com): ZTL A and B cameras active 24 hours a day, every day; Corso della Libertà (gate 10) and Via Trieste (gate 9) open to all 7–12 and 18–21. The official 7–19 schedule on Aster's site is the tour-bus ZTL, not the car ZTL.",
     "Orari per le auto confermati solo da guide non ufficiali (accessibilitacentristorici.it, tyremap.com): telecamere di ZTL A e B attive 24 ore su 24 tutti i giorni; corso della Libertà (varco 10) e via Trieste (varco 9) aperti a tutti 7–12 e 18–21. La fascia ufficiale 7–19 sul sito di Aster è quella della ZTL per i bus turistici, non per le auto.",
     "Zeiten für Autos nur von inoffiziellen Führern bestätigt (accessibilitacentristorici.it, tyremap.com): Kameras der ZTL A und B täglich rund um die Uhr aktiv; Corso della Libertà (Zufahrt 10) und Via Trieste (Zufahrt 9) 7–12 und 18–21 für alle offen. Die offizielle Zeit 7–19 auf der Aster-Seite gilt für die Reisebus-ZTL, nicht für Autos."),
    ("Visitors can buy an hourly ZTL permit online in Aster's «Area Pass» (register, «Permessi ZTL» → «Prenota/Acquista», pay with PagoPA; Aster advises at least 5 days ahead). Price not shown on the page; hotels mention 2.60 € for 24 hours (unofficial). Hotel guests: plate registered online through Aster according to the Gazzetta di Mantova and hotel sites (unofficial).",
     "I visitatori possono comprare un permesso orario ZTL online nell'«Area Pass» di Aster (registrazione, «Permessi ZTL» → «Prenota/Acquista», pagamento PagoPA; Aster consiglia almeno 5 giorni di anticipo). Prezzo non indicato sulla pagina; alcuni hotel indicano 2,60 € per 24 ore (non ufficiale). Ospiti degli hotel: targa registrata online tramite Aster secondo la Gazzetta di Mantova e siti di hotel (non ufficiale).",
     "Besucher können online im «Area Pass» von Aster eine stundenweise ZTL-Genehmigung kaufen (registrieren, «Permessi ZTL» → «Prenota/Acquista», Zahlung über PagoPA; Aster empfiehlt mindestens 5 Tage Vorlauf). Preis nicht auf der Seite; Hotels nennen 2,60 € für 24 Stunden (inoffiziell). Hotelgäste: Kennzeichen laut Gazzetta di Mantova und Hotelseiten online über Aster gemeldet (inoffiziell)."),
    ("Electric cars are not exempt: drivers from other municipalities need a transit-only pass (100 €/year). Inside ZTL A there are further pedestrian sub-zones (A/RU: Via Roma, Corso Umberto I, Via Grazioli; AV: Via Verdi, Piazza Erbe, Piazza Broletto with a retractable bollard).",
     "Le auto elettriche non sono esenti: chi viene da altri comuni ha bisogno di un pass di solo transito (100 € l'anno). Dentro la ZTL A ci sono altre sottozone pedonali (A/RU: via Roma, corso Umberto I, via Grazioli; AV: via Verdi, piazza Erbe, piazza Broletto con dissuasore mobile).",
     "Elektroautos sind nicht befreit: Fahrer aus anderen Gemeinden brauchen einen Durchfahrtsausweis (100 € pro Jahr). In der ZTL A gibt es weitere Fußgänger-Teilzonen (A/RU: Via Roma, Corso Umberto I, Via Grazioli; AV: Via Verdi, Piazza Erbe, Piazza Broletto mit versenkbarem Poller)."),
    ("No official map: the perimeter is not drawn.",
     "Nessuna mappa ufficiale: il perimetro non è disegnato.",
     "Keine offizielle Karte: die Grenze ist nicht eingezeichnet."),
]

zone = {"id": "mantova-ztl", "name": "Mantova · Historic centre ZTL (A and B)", "name_it": "Mantova · ZTL centro storico (A e B)",
        "name_de": "Mantova · ZTL Altstadt (A und B)", "kind": "restricted",
        "summary": "Draft: the historic centre is split into ZTL A and B with cameras reported active 24 hours a day. Rules not yet confirmed on official pages.",
        "summary_it": "Bozza: il centro storico è diviso in ZTL A e B con telecamere indicate attive 24 ore su 24. Regole non ancora confermate su pagine ufficiali.",
        "summary_de": "Entwurf: Die Altstadt ist in ZTL A und B geteilt, Kameras laut Berichten rund um die Uhr aktiv. Regeln noch nicht auf offiziellen Seiten bestätigt.",
        "perimeter": [], "gates": [],
        "windows": [{"weekdays": EVERY_DAY, "start": 0, "end": 24 * 60}],
        "freeOnHolidays": None, "exemptFuels": [], "hotelCanRegister": True,
        "source": {"authority": "City of Mantua", "pageURL": TOPIC, "ordinance": "Regolamento ZTL (D.C.C. n. 62/2013), citato da Aster; testo non trovato", "ordinanceURL": None, "quote": None,
                   "checkedOn": CHECKED, "reviewedByHuman": False,
                   "pending": [p[0] for p in PENDING], "pending_it": [p[1] for p in PENDING], "pending_de": [p[2] for p in PENDING],
                   "links": [link("City of Mantua: ZTL topic", "Comune di Mantova: argomento ZTL", "Stadt Mantua: Thema ZTL", TOPIC),
                             link("Aster: access to the ZTL (passes)", "Aster: accesso alle ZTL (pass)", "Aster: Zufahrt zur ZTL (Ausweise)", ASTER),
                             link("Aster: hourly ZTL permit for visitors", "Aster: permesso orario ZTL per i turisti", "Aster: stundenweise ZTL-Genehmigung für Besucher", ASTER_TOUR),
                             link("Aster: tour buses (bus ZTL 7–19)", "Aster: bus turistici (ZTL bus 7–19)", "Aster: Reisebusse (Bus-ZTL 7–19)", ASTER_BUS),
                             link("City of Mantua: disabled badge holders from other cities", "Comune di Mantova: pass disabili di altre città",
                                  "Stadt Mantua: Behindertenausweise aus anderen Städten", DISABLED)]}}

city = {"id": "mantova", "name": "Mantua", "name_it": "Mantova", "name_de": "Mantua",
        "center": {"lat": 45.1597, "lon": 10.7967}, "zones": [zone], "status": "draft",
        "license": "Rules: Aster (City of Mantua company) pages for permits; hours from unofficial sources only (draft)."}

ready = all(len(z["perimeter"]) >= 5 and z["source"]["quote"] for z in city["zones"])
out = ROOT / ("Resources/Cities/mantova.json" if ready else "data/drafts/mantova.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/mantova.json" if ready else "Resources/Cities/mantova.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), "bozza" if not ready else "pubblicata")
