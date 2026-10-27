#!/usr/bin/env python3
# Costruisce la scheda di Taormina (bozza) da quanto salvato in data/raw/taormina/ (fonti e date in docs/fonti-taormina.md).
#
# Regole: l'unico testo ufficiale raggiungibile è la pagina «PASS (Transito e Sosta)» del Comune (ultima revisione
# 27/09/2023): ordinanza n. 177 del 07/07/2009 (criteri dei pass), n. 221 del 04/09/2009 (proroga) e n. 8 del 26/01/2010
# («I soli veicoli che dal 1/01/2010 possono circolare nel centro storico di Taormina sono quelli muniti dei nuovi PASS
# colorati»). I PDF delle ordinanze linkati dalla pagina non esistono più (pagina 404). Non c'è un orario ufficiale: la
# stampa parla di sbarre su via Timeo / via Damiano Rosso aperte in fasce (es. 4–8:15 per il corso), di telecamere mai
# entrate in esercizio e di orari 10:30–13 e 16–20 (più 21–1 d'estate) solo da guide non ufficiali.
#
# Resta in data/drafts/taormina.json perché:
#   1. manca un perimetro: il «centro storico» delle ordinanze 2009–2010 non è delimitato in nessun testo letto, non c'è
#      open data e in OpenStreetMap (API, 27/10/2026) non c'è una relazione ZTL né strade con orari ZTL;
#   2. la regola ufficiale (solo veicoli con pass, a ogni ora) è del 2010 e non è confermata da un atto recente; gli orari
#      delle sbarre del corso sono solo nella stampa (qds.it, taorminanews24.com e l'albo pretorio erano bloccati dal proxy).
# Per pubblicarla servono l'ordinanza vigente sugli accessi al centro storico (albo pretorio) e la delimitazione dell'area.
# Uso: python3 Tools/build_taormina.py   (non tocca le altre città né manifest.json)
import json, re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/taormina"
CHECKED = "2026-10-27T11:00:00Z"
ALL = [1, 2, 3, 4, 5, 6, 7]

PASS_PAGE = "https://www.comune.taormina.me.it/altri-contenuti/pass-transito-e-sosta.aspx"
PASS_GREEN = "https://www.comune.taormina.me.it/amministrazione/documenti-e-dati/default.aspx?documento=364"
PARKING = "https://www.comune.taormina.me.it/altri-contenuti/parcheggi.aspx"
UNOFFICIAL = "https://www.accessibilitacentristorici.it/ztl/sicilia/taormina.html"
NEWS_BARRIERS = "https://taorminanews24.com/taormina-verso-la-ztl-dal-1-dicembre-cambia-laccesso-alle-sbarre-di-via-timeo-via-damiano-rosso/"


def flat(s):
    return re.sub(r"\s+", " ", s).strip()


TEXT = {p.stem: flat(p.read_text(encoding="utf-8")) for p in RAW.glob("*.txt")}


def check(file, *phrases):
    """Ogni frase citata o riassunta deve comparire, parola per parola, nel testo salvato"""
    for q in phrases:
        if flat(q) not in TEXT[file]:
            raise SystemExit(f"{file}: frase non trovata: {q!r}")


QUOTE = ("I soli veicoli che dal 1/01/2010 possono circolare nel centro storico di Taormina sono quelli muniti dei nuovi "
         "PASS colorati (Azzurri, Gialli, Verdi e Rossi), emessi nel 2009.")
check("comune-pass-transito-e-sosta", QUOTE, "Ordinanza n. 8 del 26/01/2010", "Vista l' Ordinanza n. 177 del 07/07/2009",
      "02 Non Residenti Turistico - Pass verde", "27 settembre 2023")
check("comune-modulo-pass-verde", "Cod. 02 Non Residenti operatori turistici – (PASS Verde)",
      "ricevuta di pagamento di € 50,00 per ogni autovettura")
check("comune-parcheggi", "Il parcheggio \"Porta Catania\", si sviluppa su 5 piani", "E' disponibile un servizio navetta dal parcheggio “Lumbi” a \"Porta Messina\".")
check("websearch-1-orari-sbarre", "currently the cameras are not in operation", "from 04:00 to 08:15 for Corso Umberto I",
      "the source itself says this is not a municipal act", "I couldn't find a 2026 ordinance for the Taormina ZTL.")


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


LINKS = [link("City of Taormina: transit and parking passes", "Comune di Taormina: PASS (transito e sosta)", "Stadt Taormina: Durchfahrts- und Parkpässe", PASS_PAGE),
         link("City of Taormina: green pass form (tourism operators)", "Comune di Taormina: modulo pass verde (operatori turistici)", "Stadt Taormina: Formular grüner Pass (Tourismusbetriebe)", PASS_GREEN),
         link("City of Taormina: car parks (Lumbi, Porta Catania)", "Comune di Taormina: parcheggi (Lumbi, Porta Catania)", "Stadt Taormina: Parkhäuser (Lumbi, Porta Catania)", PARKING),
         link("Accessibilità Centri Storici: Taormina (unofficial)", "Accessibilità Centri Storici: Taormina (non ufficiale)", "Accessibilità Centri Storici: Taormina (inoffiziell)", UNOFFICIAL),
         link("TaorminaNews24: barriers of via Timeo / via Damiano Rosso (Dec. 2024)", "TaorminaNews24: sbarre di via Timeo / via Damiano Rosso (dic. 2024)", "TaorminaNews24: Schranken Via Timeo / Via Damiano Rosso (Dez. 2024)", NEWS_BARRIERS)]

PENDING = [
    ("No perimeter: the 2009–2010 ordinances speak of the «centro storico» without listing its streets, there is no open data and OpenStreetMap has no ZTL area for Taormina. Roughly, it is the old town along Corso Umberto between Porta Messina and Porta Catania.",
     "Nessun perimetro: le ordinanze 2009–2010 parlano di «centro storico» senza elencarne le vie, non ci sono open data e OpenStreetMap non ha un'area ZTL per Taormina. Indicativamente è il borgo lungo Corso Umberto tra Porta Messina e Porta Catania.",
     "Keine Grenze: Die Verordnungen von 2009–2010 sprechen vom «centro storico», ohne Straßen aufzuzählen; es gibt keine Open Data und OpenStreetMap hat keine ZTL-Fläche für Taormina. Grob ist es die Altstadt am Corso Umberto zwischen Porta Messina und Porta Catania."),
    ("Hours: the official rule (ordinance 8/2010) admits only vehicles with a coloured pass, at any hour. Press reports describe barriers on via Timeo / via Damiano Rosso that open the Corso in set slots (e.g. 4–8:15 am, confirmed only by taorminanews24.com, Dec. 2024) and cameras never switched on (confirmed only by qds.it and accessibilitacentristorici.it); a travel guide gives 10:30 am–1 pm and 4–8 pm plus 9 pm–1 am in summer (confirmed only by bluekeys.it, which says it is not a municipal act). No 2026 ordinance was found.",
     "Orari: la regola ufficiale (ordinanza 8/2010) ammette solo i veicoli con pass colorato, a ogni ora. La stampa descrive sbarre su via Timeo / via Damiano Rosso che aprono il corso in fasce (es. 4–8:15, confermato solo da taorminanews24.com, dic. 2024) e telecamere mai accese (confermato solo da qds.it e accessibilitacentristorici.it); una guida indica 10:30–13 e 16–20 più 21–1 d'estate (confermato solo da bluekeys.it, che dice che non è un atto comunale). Nessuna ordinanza 2026 trovata.",
     "Zeiten: Die offizielle Regel (Verordnung 8/2010) lässt nur Fahrzeuge mit farbigem Pass zu, zu jeder Stunde. Die Presse beschreibt Schranken an Via Timeo / Via Damiano Rosso, die den Corso zu festen Zeiten öffnen (z. B. 4–8:15 Uhr, nur von taorminanews24.com bestätigt, Dez. 2024), und nie eingeschaltete Kameras (nur von qds.it und accessibilitacentristorici.it bestätigt); ein Reiseführer nennt 10:30–13 und 16–20 Uhr plus 21–1 Uhr im Sommer (nur von bluekeys.it bestätigt, das selbst sagt, es sei kein städtischer Akt). Keine Verordnung für 2026 gefunden."),
    ("Hotels: the «green pass» (50 € per car) is issued to tourism operators (hotels, B&Bs) for their own vehicles; how guests' plates are registered is not in the official texts (a hotel registration is mentioned only by tyremap.com). Ask your hotel before driving up. Tourist buses and most visitors park at Lumbi (shuttle to Porta Messina) or Porta Catania.",
     "Hotel: il «pass verde» (50 € per auto) è rilasciato agli operatori turistici (hotel, B&B) per i propri veicoli; come si registrano le targhe degli ospiti non è nei testi ufficiali (una registrazione dall'hotel è citata solo da tyremap.com). Chiedi all'hotel prima di salire. Bus turistici e quasi tutti i visitatori parcheggiano al Lumbi (navetta per Porta Messina) o a Porta Catania.",
     "Hotels: Der «grüne Pass» (50 € pro Auto) wird an Tourismusbetriebe (Hotels, B&Bs) für eigene Fahrzeuge ausgegeben; wie Gästekennzeichen gemeldet werden, steht nicht in den offiziellen Texten (eine Meldung durch das Hotel nennt nur tyremap.com). Frag dein Hotel, bevor du hinauffährst. Reisebusse und die meisten Besucher parken am Lumbi (Shuttle zur Porta Messina) oder an der Porta Catania."),
    ("Not found: electric cars, motorbikes, Blue Badge rules, fines and summer variations. The ordinance PDFs linked from the City page no longer exist; the online notice board and the permit portal (smart-pass) could not be reached from here.",
     "Non trovati: regole per auto elettriche, moto, contrassegno disabili, multe e variazioni estive. I PDF delle ordinanze linkati dalla pagina del Comune non esistono più; l'albo pretorio online e il portale dei pass (smart-pass) non erano raggiungibili da qui.",
     "Nicht gefunden: Regeln für Elektroautos, Motorräder, Behindertenausweis, Bußgelder und Sommeränderungen. Die von der Stadtseite verlinkten Verordnungs-PDFs gibt es nicht mehr; Online-Amtstafel und Pass-Portal (smart-pass) waren von hier aus nicht erreichbar."),
]

zone = {"id": "taormina-centro", "name": "Taormina old town · pass-only centre", "name_it": "Centro storico di Taormina · solo con pass",
        "name_de": "Altstadt Taormina · nur mit Pass",
        "kind": "restricted",
        "summary": "Taormina's old town (Corso Umberto between Porta Messina and Porta Catania) is open only to vehicles with a City pass (residents, owners, businesses, public services, tourism operators). Park at Lumbi (shuttle to Porta Messina) or Porta Catania and walk. Staying inside? Ask your hotel how it gets you in.",
        "summary_it": "Il centro storico di Taormina (Corso Umberto tra Porta Messina e Porta Catania) è aperto solo ai veicoli con un pass del Comune (residenti, proprietari, attività, servizi pubblici, operatori turistici). Parcheggia al Lumbi (navetta per Porta Messina) o a Porta Catania e cammina. Dormi dentro? Chiedi all'hotel come farti entrare.",
        "summary_de": "Die Altstadt von Taormina (Corso Umberto zwischen Porta Messina und Porta Catania) ist nur für Fahrzeuge mit städtischem Pass offen (Anwohner, Eigentümer, Betriebe, öffentliche Dienste, Tourismusbetriebe). Am Lumbi (Shuttle zur Porta Messina) oder an der Porta Catania parken und laufen. Du übernachtest innen? Frag dein Hotel, wie du hineinkommst.",
        "perimeter": [], "gates": [],
        "windows": [{"weekdays": ALL, "start": 0, "end": 24 * 60}],
        "freeOnHolidays": False, "holidaysAsSunday": False, "exemptFuels": [], "hotelCanRegister": False,
        "source": {"authority": "City of Taormina", "pageURL": PASS_PAGE,
                   "ordinance": "Ordinanza n. 8 del 26/01/2010 (criteri dei pass: ordinanza n. 177 del 07/07/2009)",
                   "quote": QUOTE,
                   "quoteTranslation": "From 1/01/2010 the only vehicles allowed to drive in the historic centre of Taormina are those with the new coloured PASSES (blue, yellow, green and red) issued in 2009.",
                   "quoteTranslation_de": "Ab dem 1.1.2010 dürfen im historischen Zentrum von Taormina nur Fahrzeuge mit den neuen farbigen PÄSSEN (blau, gelb, grün und rot) fahren, die 2009 ausgegeben wurden.",
                   "checkedOn": CHECKED, "reviewedByHuman": False,
                   "pending": [p[0] for p in PENDING], "pending_it": [p[1] for p in PENDING], "pending_de": [p[2] for p in PENDING],
                   "links": LINKS}}

city = {"id": "taormina", "name": "Taormina", "name_it": "Taormina", "name_de": "Taormina",
        "center": {"lat": 37.8525, "lon": 15.2870}, "zones": [zone], "status": "draft",
        "license": "Rules: Comune di Taormina (official PASS page). No perimeter yet."}

# Pubblicabile solo con perimetro e citazione verificata; qui manca il perimetro → bozza
ready = all(len(z["perimeter"]) >= 5 and z["source"]["quote"] for z in city["zones"])
out = ROOT / ("Resources/Cities/taormina.json" if ready else "data/drafts/taormina.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/taormina.json" if ready else "Resources/Cities/taormina.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), [(z["id"], len(z["perimeter"]), len(z["gates"])) for z in city["zones"]])
