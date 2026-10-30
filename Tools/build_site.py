#!/usr/bin/env python3
# Costruisce il sito statico in web/ dal modello web/template.html e dai dati delle città:
# - home in tre lingue: web/index.html (EN), web/it/index.html, web/de/index.html
# - una pagina per città e lingua: web/firenze/, web/it/firenze/, web/de/firenze/ … (senza JavaScript)
# - web/sitemap.xml, web/robots.txt, web/icon.png
# Uso: python3 Tools/build_site.py
import html, json, math, re, shutil
from datetime import date
from pathlib import Path
import seasons          # Tools/seasons.py: le date delle stagioni con le regole

SITE = "https://lr-apps609.github.io/GateLR/"          # indirizzo pubblico (con la barra finale): cambiarlo qui col dominio
ROOT = Path(__file__).resolve().parent.parent
WEB = ROOT / "web"
FINE_FILE = ROOT / "Resources/Rules/fine.json"          # importi verificati, con fonte (se manca: «in verifica»)
ICON = ROOT / "Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
LANGS = ["en", "it", "de"]
OG_LOCALE = {"en": "en_GB", "it": "it_IT", "de": "de_DE"}
ORDER = [2, 3, 4, 5, 6, 7, 1]                           # lun … dom (1 = domenica, come l'app)

# le città, nell'ordine del manifest dell'app (Resources/Cities/manifest.json): numero ed elenco del sito vengono da qui
MANIFEST = json.loads((ROOT / "Resources/Cities/manifest.json").read_text(encoding="utf-8"))
# anche le città con zone da fonti non ufficiali («unofficialCities», vedi Tools/build_manifest.py): sul sito con l'avviso
cities = [json.loads((ROOT / "Resources/Cities" / m["file"]).read_text(encoding="utf-8"))
          for m in sorted(MANIFEST["cities"] + MANIFEST.get("unofficialCities", []), key=lambda m: m["file"])]


def unofficial(z):
    """Regole della zona solo da fonti non ufficiali (official assente = ufficiale)"""
    return z["source"].get("official", True) is False
fine = json.loads(FINE_FILE.read_text(encoding="utf-8")) if FINE_FILE.exists() else None
# {{N}} nei testi del modello = numero di città (calcolato qui, mai scritto a mano)
template = (WEB / "template.html").read_text(encoding="utf-8").replace("{{N}}", str(len(cities)))
esc = lambda s: html.escape(str(s), quote=True)
ld = lambda o: '<script type="application/ld+json">' + json.dumps(o, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/") + "</script>"
prefix = lambda l: "" if l == "en" else l + "/"


# ── Testi: le stringhe semplici della tabella T del modello (stessa fonte del JavaScript) ─────────
def strings_of_T(src):
    block = src[src.index("const T = {"):]
    block = block[:block.index("\n};\n")]
    parts = re.split(r"^ (en|it|de):\{", block, flags=re.M)
    out = {}
    for lang, body in zip(parts[1::2], parts[2::2]):
        out[lang] = {k: json.loads('"' + v.replace("\\'", "'") + '"')
                     for k, v in re.findall(r'(?<![\w$.])(\w+):"((?:[^"\\]|\\.)*)"', body)}
    return out


T = strings_of_T(template)


def prerender(page, lang):
    """Mette nel HTML i testi già tradotti, così motori di ricerca e lettori senza JavaScript li vedono"""
    t = T[lang]
    def txt(m):
        k = m.group(3)
        return m.group(1) + (esc(t[k]) if k in t else m.group(4)) + m.group(5)
    page = re.sub(r'(<(\w+)\b[^>]*\sdata-i18n="(\w+)"[^>]*>)(.*?)(</\2>)', txt, page, flags=re.S)
    page = re.sub(r'(<(\w+)\b[^>]*\sdata-i18n-html="(\w+)"[^>]*>)(.*?)(</\2>)',
                  lambda m: m.group(1) + t.get(m.group(3), m.group(4)) + m.group(5), page, flags=re.S)
    page = re.sub(r'placeholder="[^"]*"( data-i18n-ph="(\w+)")', lambda m: f'placeholder="{esc(t.get(m.group(2), ""))}"{m.group(1)}', page)
    for c in cities:
        page = re.sub(rf'(<a data-city="{c["id"]}"[^>]*>)[^<]*', lambda m: m.group(1) + esc(city_name(c, lang)), page)
    return page


def head(lang, title, desc, url, alternates, root, graph):
    """<title>, descrizione, canonical, hreflang, Open Graph, Twitter e JSON-LD"""
    alt = "\n".join(f'<link rel="alternate" hreflang="{l}" href="{u}">' for l, u in alternates.items())
    loc = "\n".join(f'<meta property="og:locale:alternate" content="{OG_LOCALE[l]}">' for l in LANGS if l != lang)
    return f'''<title>{esc(title)}</title>
<meta name="description" content="{esc(desc)}">
<link rel="canonical" href="{url}">
{alt}
<link rel="alternate" hreflang="x-default" href="{alternates["en"]}">
<link rel="icon" type="image/png" href="{root}icon.png">
<link rel="apple-touch-icon" href="{root}icon.png">
<meta name="theme-color" content="#F4EFE6" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#17141E" media="(prefers-color-scheme: dark)">
<meta property="og:type" content="website">
<meta property="og:site_name" content="GateLR">
<meta property="og:title" content="{esc(title)}">
<meta property="og:description" content="{esc(desc)}">
<meta property="og:url" content="{url}">
<meta property="og:image" content="{SITE}icon.png">
<meta property="og:image:alt" content="GateLR">
<meta property="og:locale" content="{OG_LOCALE[lang]}">
{loc}
<meta name="twitter:card" content="summary">
<meta name="twitter:title" content="{esc(title)}">
<meta name="twitter:description" content="{esc(desc)}">
<meta name="twitter:image" content="{SITE}icon.png">
{ld({"@context": "https://schema.org", "@graph": graph})}'''


def faq(qas):
    return {"@type": "FAQPage", "mainEntity": [{"@type": "Question", "name": q, "acceptedAnswer": {"@type": "Answer", "text": a}} for q, a in qas]}


# ── Home in tre lingue ───────────────────────────────────────────────────────
# Le forme disegnate sulla mappa (corridoi delle vie, punto del segno «ZTL», varchi sul bordo): Tools/build_map_shapes.py,
# le stesse dell'app. Una forma nata da un perimetro diverso da quello di oggi (città aggiornata, script non rilanciato) si
# scarta: la mappa usa il perimetro vero e qui si avvisa.
SHAPES_FILE = ROOT / "Resources/Map/zone-shapes.json"
SHAPES = json.loads(SHAPES_FILE.read_text(encoding="utf-8"))["cities"] if SHAPES_FILE.exists() else {}


def map_shapes(c):
    out, stale = {}, []
    for o in c["zones"] + (c.get("pedestrian") or []):
        e = SHAPES.get(c["id"], {}).get(o["id"])
        if not e:
            continue
        p0 = o["perimeter"][0]
        if e["n"] != len(o["perimeter"]) or abs(e["p0"][0] - p0["lat"]) > 1e-6 or abs(e["p0"][1] - p0["lon"]) > 1e-6:
            stale.append(o["id"])
            continue
        out[o["id"]] = {k: v for k, v in e.items() if k in ("corridor", "axis", "label", "ext", "gates")}
    if stale:
        print(f"Avviso: forme della mappa vecchie per {c['id']} ({', '.join(stale)}): rilancia python3 Tools/build_map_shapes.py")
    return out


CITIES_JSON = json.dumps([dict(c, shapes=map_shapes(c)) for c in cities], ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
FINE_JSON = json.dumps(fine, ensure_ascii=False) if fine else "null"
HOME_ALT = {l: SITE + prefix(l) for l in LANGS}


# Schermate vere dell'app (ramo screenshots, ridotte in WebP in web/app/): i due iPhone della vetrina.
# Chiave → testo alternativo per lingua. L'italiano usa le schermate in italiano; il tedesco non ne ha ancora, usa quelle inglesi.
SHOT_ALT = {
 "home-dark": {"en": "GateLR home screen: Duomo di Milano, «Don't enter», pedestrian area at any time", "de": "GateLR-Startbildschirm: Duomo di Milano, «Nicht einfahren», Fußgängerzone zu jeder Zeit"},
 "map-dark": {"en": "GateLR map of Milan by night with the ZTL zone, camera gates and the pedestrian area", "de": "GateLR-Karte von Mailand bei Nacht mit ZTL-Zone, Kamera-Einfahrten und Fußgängerzone"},
 "it-home": {"it": "Schermata iniziale di GateLR: Piazza Maggiore a Bologna, «Non entrare», area pedonale"},
 "it-zone": {"it": "Scheda della ZTL Centro storico di Bologna: orari, parole del Comune e ticket giornaliero"},
}
SHOTS = {"en": {"front": "home-dark", "back": "map-dark"}, "it": {"front": "it-home", "back": "it-zone"}}
SHOTS["de"] = SHOTS["en"]


def shot_img(m, lang, root):
    """L'iPhone della vetrina nella lingua della pagina; data-src-* e data-alt-* servono alla home inglese
    quando il visitatore passa a un'altra lingua (le schermate cambiano con i testi)"""
    slot = m.group(1)
    def src(l): return f"{root}app/{SHOTS[l][slot]}.webp"
    def alt(l):
        a = SHOT_ALT[SHOTS[l][slot]]
        return a.get(l) or a.get("en") or a["it"]
    swap = "".join(f' data-src-{l}="{src(l)}" data-alt-{l}="{esc(alt(l))}"' for l in LANGS)
    lazy = "" if slot == "front" else ' loading="lazy"'
    pri = ' fetchpriority="high"' if slot == "front" else ""
    return f'<img src="{src(lang)}" width="600" height="1304" alt="{esc(alt(lang))}" decoding="async"{lazy}{pri}{swap}>'


def build_home(lang):
    t, root = T[lang], ("" if lang == "en" else "../")
    graph = [
        {"@type": "WebSite", "@id": SITE + "#site", "name": "GateLR", "url": SITE, "inLanguage": LANGS, "description": T["en"]["desc"]},
        {"@type": "SoftwareApplication", "name": "GateLR", "operatingSystem": "iOS, Android", "applicationCategory": "TravelApplication",
         "url": SITE + prefix(lang) + "#app", "description": t["appP"], "inLanguage": lang,
         "featureList": [t[f"f{i}T"].strip("«»") + ": " + t[f"f{i}P"] for i in range(1, 13) if f"f{i}T" in t]},
        faq([(t[f"q{i}"], t[f"a{i}"]) for i in range(1, 10) if f"q{i}" in t]),
    ]
    page = template.replace("<!--HEAD-->", head(lang, t["title"], t["desc"], HOME_ALT[lang], HOME_ALT, root, graph))
    page = (page.replace("{{LANG}}", lang).replace("{{ROOT}}", root).replace("{{LP}}", prefix(lang))
                .replace("{{PAGELANG}}", "" if lang == "en" else lang))
    page = re.sub(r"\{\{SHOT:(\w+)\}\}", lambda m: shot_img(m, lang, root), page)
    page = page.replace("/*CITIES*/", CITIES_JSON).replace("/*FINE*/null", FINE_JSON)
    links = sorted(cities, key=lambda c: city_name(c, lang))
    page = page.replace("<!--CITYLINKS-->", "".join(f'<a data-city="{c["id"]}" href="{root}{prefix(lang)}{c["id"]}/">{esc(city_name(c, lang))}</a>' for c in links))
    page = prerender(page, lang)
    out = WEB / prefix(lang) / "index.html"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(page, encoding="utf-8")
    return out


# ── Pagine delle città (statiche) ─────────────────────────────────────────────
DAYS = {"en": ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
        "it": ["domenica", "lunedì", "martedì", "mercoledì", "giovedì", "venerdì", "sabato"],
        "de": ["Sonntag", "Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag"]}
SHORT = {"en": ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], "it": ["dom", "lun", "mar", "mer", "gio", "ven", "sab"],
         "de": ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]}
MONTHS = {"en": "January February March April May June July August September October November December".split(),
          "it": "gennaio febbraio marzo aprile maggio giugno luglio agosto settembre ottobre novembre dicembre".split(),
          "de": "Januar Februar März April Mai Juni Juli August September Oktober November Dezember".split()}
NAMES = {"firenze": {"en": "Florence", "it": "Firenze", "de": "Florenz"}, "bologna": {"en": "Bologna", "it": "Bologna", "de": "Bologna"},
         "milano": {"en": "Milan", "it": "Milano", "de": "Mailand"}}

P = {
 "en": {"title": "{c} ZTL: hours, gates, day ticket and hotel rules · GateLR",
        "desc": "When the {c} ZTL is on, which zones you can't drive into, the day ticket, the fine and how your hotel can register your plate. From the city's official sources, checked {d}.",
        "kicker": "Driving guide · limited traffic zones", "h1": "{c} <em>ZTL</em>",
        "lead": "Where you can't drive in {c}, when the cameras are on, what a ticket costs and what your hotel can do for you. Taken from the city's official pages.",
        "leadU": "Where you can't drive in {c}, when the cameras are on, what a ticket costs and what your hotel can do for you. Some of these rules come only from non-official sources.",
        "descU": "When the {c} ZTL is on, which zones you can't drive into, the fine and how your hotel can register your plate. Partly from non-official sources: always check the sign at the gate.",
        "cta": "Check your hotel or address", "ctaN": "A live answer for your arrival time, on the map.",
        "kind": {"restricted": "ZTL · no entry without a permit", "pass": "ZTL · entry with a day ticket", "green": "Low-emission zone"},
        "hours": "When it's on", "ticketT": "Day ticket", "buy": "How to buy it ↗", "hotelT": "Staying at a hotel inside",
        "hotelY": "Hotels inside this zone can register your plate with the city, so you can drive to the hotel. Ask them before you arrive.",
        "hotelN": "Hotels can't register your plate for this zone.",
        "rental": "A typical modern rental car (petrol Euro 6, hybrid or electric) can drive in.", "bansT": "Older cars banned while it's on",
        "since": "since {d}", "from": "from {d}", "electric": "Electric cars: always free.", "moto": "Motorbikes and scooters: always free.", "gates": "{n} camera gates",
        "srcT": "Official source", "srcU": "Unofficial source", "dataFrom": "Data from {s} ↗", "checked": "Checked on {d}", "page": "Official page ↗", "pending": "Still being checked",
        "pedT": "Pedestrian areas", "pedP": "{n} pedestrian areas: cars can't drive in at any time, not even with a permit or a ticket. Park outside and walk.",
        "pedAll": "Show all {n}", "fineL": "If you drive in by mistake", "perDay": "per day", "faqT": "Questions",
        "other": "Other cities", "mapL": "Map of the zones in {c}", "home": "Home",
        "qWhen": "When is the {c} ZTL active?", "qFine": "How much is the fine for entering the {c} ZTL?",
        "aFine": "€{a}–{b} per entry and day, sent by post to the car's owner: for a rental car, that's you, plus the rental company's fee.",
        "qHotel": "My hotel is inside the {c} ZTL. Can I drive there?",
        "aHotelY": "Yes, if the hotel registers your plate with the city ({z}). Write to the hotel before you arrive.",
        "aHotelT": "Hotels can't register your plate here, but you can enter with the day ticket.",
        "aHotelN": "Hotels can't register your plate here: park outside the zone and walk.",
        "qTicket": "Is there a day ticket for the {c} ZTL?", "qGreen": "Can I drive a rental car into {z}?",
        "qPed": "Can I drive into the pedestrian areas of {c}?", "aPed": "No. Cars can't drive into pedestrian areas at any time, not even with a permit or a ticket. Park outside and walk."},
 "it": {"title": "ZTL {c}: orari, varchi, ticket e regole per gli hotel · GateLR",
        "desc": "Quando è attiva la ZTL di {c}, dove non si entra in auto, il ticket giornaliero, la multa e come l'hotel può registrare la targa. Dalle fonti ufficiali del Comune, controllate il {d}.",
        "kicker": "Guida per chi guida · zone a traffico limitato", "h1": "ZTL <em>{c}</em>",
        "lead": "Dove non si entra in auto a {c}, quando le telecamere sono accese, quanto costa il ticket e cosa può fare l'hotel per te. Dalle pagine ufficiali del Comune.",
        "leadU": "Dove non si entra in auto a {c}, quando le telecamere sono accese, quanto costa il ticket e cosa può fare l'hotel per te. Alcune di queste regole vengono solo da fonti non ufficiali.",
        "descU": "Quando è attiva la ZTL di {c}, dove non si entra in auto, la multa e come l'hotel può registrare la targa. In parte da fonti non ufficiali: verifica sempre il cartello al varco.",
        "cta": "Controlla il tuo hotel o indirizzo", "ctaN": "La risposta per l'ora di arrivo, sulla mappa.",
        "kind": {"restricted": "ZTL · vietato entrare senza permesso", "pass": "ZTL · si entra con il ticket", "green": "Zona a basse emissioni"},
        "hours": "Quando è attiva", "ticketT": "Ticket giornaliero", "buy": "Come comprarlo ↗", "hotelT": "Se dormi in un hotel dentro",
        "hotelY": "Gli hotel dentro questa zona possono comunicare la tua targa al Comune, così arrivi all'hotel in auto. Chiedilo prima di arrivare.",
        "hotelN": "Gli hotel non possono registrare la tua targa per questa zona.",
        "rental": "Una tipica auto a noleggio recente (benzina Euro 6, ibrida o elettrica) può entrare.", "bansT": "Auto vecchie vietate quando è attiva",
        "since": "dal {d}", "from": "dal {d}", "electric": "Auto elettriche: entrano sempre.", "moto": "Moto e scooter: entrano sempre.", "gates": "{n} varchi con telecamera",
        "srcT": "Fonte ufficiale", "srcU": "Fonte non ufficiale", "dataFrom": "Dati da {s} ↗", "checked": "Controllato il {d}", "page": "Pagina ufficiale ↗", "pending": "Ancora da verificare",
        "pedT": "Aree pedonali", "pedP": "{n} aree pedonali: le auto non entrano mai, neanche con permesso o ticket. Parcheggia fuori e prosegui a piedi.",
        "pedAll": "Mostra tutte ({n})", "fineL": "Se entri per sbaglio", "perDay": "al giorno", "faqT": "Domande",
        "other": "Altre città", "mapL": "Mappa delle zone di {c}", "home": "Home",
        "qWhen": "Quando è attiva la ZTL di {c}?", "qFine": "Quanto è la multa per l'ingresso nella ZTL di {c}?",
        "aFine": "Da {a} a {b} € per ingresso e giorno, inviata per posta al proprietario dell'auto: per un'auto a noleggio sei tu, più la commissione del noleggio.",
        "qHotel": "Il mio hotel è dentro la ZTL di {c}. Posso arrivarci in auto?",
        "aHotelY": "Sì, se l'hotel comunica la tua targa al Comune ({z}). Scrivi all'hotel prima di arrivare.",
        "aHotelT": "Qui gli hotel non possono registrare la targa, ma puoi entrare con il ticket giornaliero.",
        "aHotelN": "Qui gli hotel non possono registrare la targa: parcheggia fuori dalla zona e prosegui a piedi.",
        "qTicket": "C'è un ticket giornaliero per la ZTL di {c}?", "qGreen": "Posso entrare in {z} con un'auto a noleggio?",
        "qPed": "Posso entrare in auto nelle aree pedonali di {c}?", "aPed": "No. Nelle aree pedonali le auto non entrano mai, neanche con permesso o ticket. Parcheggia fuori e prosegui a piedi."},
 "de": {"title": "ZTL {c}: Zeiten, Einfahrten, Tagesticket und Hotel · GateLR",
        "desc": "Wann die ZTL in {c} aktiv ist, wo du nicht hineinfahren darfst, das Tagesticket, das Bußgeld und wie dein Hotel dein Kennzeichen anmeldet. Aus offiziellen Quellen der Stadt, geprüft am {d}.",
        "kicker": "Ratgeber für Autofahrer · verkehrsberuhigte Zonen", "h1": "ZTL <em>{c}</em>",
        "lead": "Wo du in {c} nicht hineinfahren darfst, wann die Kameras aktiv sind, was ein Ticket kostet und was dein Hotel für dich tun kann. Aus den offiziellen Seiten der Stadt.",
        "leadU": "Wo du in {c} nicht hineinfahren darfst, wann die Kameras aktiv sind, was ein Ticket kostet und was dein Hotel für dich tun kann. Einige dieser Regeln stammen nur aus inoffiziellen Quellen.",
        "descU": "Wann die ZTL in {c} aktiv ist, wo du nicht hineinfahren darfst, das Bußgeld und wie dein Hotel dein Kennzeichen anmeldet. Teilweise aus inoffiziellen Quellen: prüfe immer das Schild an der Einfahrt.",
        "cta": "Hotel oder Adresse prüfen", "ctaN": "Die Antwort für deine Ankunftszeit, auf der Karte.",
        "kind": {"restricted": "ZTL · keine Einfahrt ohne Genehmigung", "pass": "ZTL · Einfahrt mit Tagesticket", "green": "Umweltzone"},
        "hours": "Wann sie aktiv ist", "ticketT": "Tagesticket", "buy": "So kaufst du es ↗", "hotelT": "Hotel in der Zone",
        "hotelY": "Hotels in dieser Zone können dein Kennzeichen bei der Stadt anmelden, damit du zum Hotel fahren darfst. Frag vor der Ankunft.",
        "hotelN": "Hotels können dein Kennzeichen für diese Zone nicht anmelden.",
        "rental": "Ein typischer neuerer Mietwagen (Benzin Euro 6, Hybrid oder Elektro) darf hinein.", "bansT": "Ältere Autos verboten, wenn sie aktiv ist",
        "since": "seit {d}", "from": "ab {d}", "electric": "Elektroautos: immer frei.", "moto": "Motorräder und Roller: immer frei.", "gates": "{n} Kamera-Einfahrten",
        "srcT": "Offizielle Quelle", "srcU": "Inoffizielle Quelle", "dataFrom": "Daten von {s} ↗", "checked": "Geprüft am {d}", "page": "Offizielle Seite ↗", "pending": "Wird noch geprüft",
        "pedT": "Fußgängerzonen", "pedP": "{n} Fußgängerzonen: Autos dürfen nie hinein, auch nicht mit Genehmigung oder Ticket. Parke außerhalb und geh zu Fuß.",
        "pedAll": "Alle {n} zeigen", "fineL": "Wenn du aus Versehen hineinfährst", "perDay": "pro Tag", "faqT": "Fragen",
        "other": "Andere Städte", "mapL": "Karte der Zonen in {c}", "home": "Start",
        "qWhen": "Wann ist die ZTL in {c} aktiv?", "qFine": "Wie hoch ist das Bußgeld für die ZTL in {c}?",
        "aFine": "{a}–{b} € pro Einfahrt und Tag, per Post an den Halter: beim Mietwagen also an dich, plus Gebühr der Mietwagenfirma.",
        "qHotel": "Mein Hotel liegt in der ZTL von {c}. Darf ich hinfahren?",
        "aHotelY": "Ja, wenn das Hotel dein Kennzeichen bei der Stadt anmeldet ({z}). Schreib dem Hotel vor der Ankunft.",
        "aHotelT": "Hotels können dein Kennzeichen hier nicht anmelden, aber du darfst mit dem Tagesticket hinein.",
        "aHotelN": "Hotels können dein Kennzeichen hier nicht anmelden: parke außerhalb der Zone und geh zu Fuß.",
        "qTicket": "Gibt es ein Tagesticket für die ZTL in {c}?", "qGreen": "Darf ich mit einem Mietwagen in die {z}?",
        "qPed": "Darf ich in die Fußgängerzonen von {c} fahren?", "aPed": "Nein. In Fußgängerzonen dürfen Autos nie fahren, auch nicht mit Genehmigung oder Ticket. Parke außerhalb und geh zu Fuß."},
}
DL = {"en": {"beforeEntry": "activate it before you drive in", "nextDayMidnight": "pay by midnight of the next day"},
      "it": {"beforeEntry": "da attivare prima di entrare", "nextDayMidnight": "da pagare entro la mezzanotte del giorno dopo"},
      "de": {"beforeEntry": "vor der Einfahrt aktivieren", "nextDayMidnight": "bis Mitternacht des Folgetags bezahlen"}}
FUEL = {"en": {"petrol": "petrol", "diesel": "diesel", "lpg": "LPG", "cng": "CNG"}, "it": {"petrol": "benzina", "diesel": "diesel", "lpg": "GPL", "cng": "metano"},
        "de": {"petrol": "Benzin", "diesel": "Diesel", "lpg": "Autogas", "cng": "Erdgas"}}
UPTO = {"en": "{f} up to Euro {n}", "it": "{f} fino a Euro {n}", "de": "{f} bis Euro {n}"}


def city_name(c, lang): return NAMES.get(c["id"], {}).get(lang) or c.get("name_" + lang) or c["name"]
def kind_of(z): return z.get("kind") or ("pass" if z.get("ticket") else "restricted")
def loc(o, k, lang): return o.get(f"{k}_{lang}") or o.get(k) or ""
def zone_label(z, lang): return loc(z, "name", lang).split("·")[0].strip()
def money(x, lang): return f"€{x:.2f}" if lang == "en" else f"{x:.2f}".replace(".", ",") + " €"


def day(d, lang):
    if isinstance(d, str): d = date.fromisoformat(d[:10])
    m = MONTHS[lang][d.month - 1]
    return f"{d.day}. {m} {d.year}" if lang == "de" else f"{d.day} {m} {d.year}"


def clock(m, lang):
    h, mm = (m // 60) % 24, m % 60
    if lang != "en": return f"{h}:{mm:02d}"
    return f"{h % 12 or 12}{':%02d' % mm if mm else ''} {'am' if h < 12 else 'pm'}"


def hour_rows(z, lang):
    """Le stesse righe della tabella degli orari della home, in testo"""
    t, rows = T[lang], []
    for w in z["windows"]:
        days = [d for d in ORDER if d in w["weekdays"]]
        contiguous = len(days) > 2 and all(i == 0 or ORDER.index(d) == ORDER.index(days[i - 1]) + 1 for i, d in enumerate(days))
        label = f"{SHORT[lang][days[0] - 1]} – {SHORT[lang][days[-1] - 1]}" if contiguous else ", ".join(SHORT[lang][d - 1] for d in days)
        if w.get("season"):
            # Le date della stagione in corso o della prossima: con le regole («primo giovedì di aprile») cambiano ogni anno
            a, b = seasons.shown(w["season"], date.today())
            label += f" {t['nights']} ({a.day} {MONTHS[lang][a.month - 1][:3]} – {b.day} {MONTHS[lang][b.month - 1][:3]})"
        rows.append((label, f"{clock(w['start'], lang)} – {clock(w['end'], lang)}", ""))
    covered = {d for w in z["windows"] if not w.get("season") for d in w["weekdays"]}
    free = [DAYS[lang][d - 1] for d in ORDER if d not in covered]
    if free: rows.append((", ".join(free), t["open"], "free"))
    if z.get("freeOnHolidays") is None: rows.append((t["hol"], t["notConf"], ""))
    elif z.get("freeOnHolidays") is True: rows.append((t["hol"], t["open"], "free"))
    elif z.get("holidaysAsSunday") is True: rows.append((t["hol"], t["asSun"], ""))
    if any(w["start"] == 0 and w["end"] == 1440 and not w.get("season") for w in z["windows"]): rows = [(t["always"], t["closed"], "")]
    return rows


def ban_lines(z, lang, today):
    """Divieti per classe Euro: quelli in vigore oggi (classe più alta per carburante) e quelli in arrivo"""
    now, later = {}, []
    for b in sorted(z.get("bans") or [], key=lambda b: b["since"]):
        if b["since"] <= today: now[b["fuel"]] = b
        else: later.append(b)
    f = lambda b: UPTO[lang].format(f=FUEL[lang].get(b["fuel"], b["fuel"]), n=b["maxEuro"])
    return ([(f(b), P[lang]["since"].format(d=day(b["since"], lang))) for b in now.values()] +
            [(f(b), P[lang]["from"].format(d=day(b["since"], lang))) for b in later])


def join_and(parts, lang):
    a = {"en": "and", "it": "e", "de": "und"}[lang]
    return parts[0] if len(parts) == 1 else ", ".join(parts[:-1]) + f" {a} " + parts[-1]


MAP_COLORS = {"restricted": "#E0312F", "pass": "#E5A100", "green": "#12A150"}

def map_script(c, lang):
    """La mappa vera (strade, nomi, zone colorate) sopra quella disegnata: MapLibre + OpenFreeMap,
    con una mappa di riserva (CARTO) se la prima non risponde. Si carica quando arriva sullo schermo."""
    feats = []
    for z in c["zones"]:
        k = kind_of(z)
        ring = [[q["lon"], q["lat"]] for q in z["perimeter"]] + [[z["perimeter"][0]["lon"], z["perimeter"][0]["lat"]]]
        feats.append({"type": "Feature", "properties": {"name": zone_label(z, lang), "kind": k, "color": MAP_COLORS.get(k, "#E0312F")},
                      "geometry": {"type": "Polygon", "coordinates": [ring]}})
    for a in c.get("pedestrian") or []:
        ring = [[q["lon"], q["lat"]] for q in a["perimeter"]] + [[a["perimeter"][0]["lon"], a["perimeter"][0]["lat"]]]
        feats.append({"type": "Feature", "properties": {"name": "", "kind": "ped", "color": "#8E2A6E"}, "geometry": {"type": "Polygon", "coordinates": [ring]}})
    gates = [{"type": "Feature", "properties": {"name": g.get("name", "")}, "geometry": {"type": "Point", "coordinates": [g["location"]["lon"], g["location"]["lat"]]}}
             for z in c["zones"] for g in z["gates"]]
    pts = [q for z in c["zones"] for q in z["perimeter"]]
    bounds = [[min(q["lon"] for q in pts), min(q["lat"] for q in pts)], [max(q["lon"] for q in pts), max(q["lat"] for q in pts)]]
    data = json.dumps({"zones": {"type": "FeatureCollection", "features": feats}, "gates": {"type": "FeatureCollection", "features": gates}, "bounds": bounds},
                      ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
    return """<script>
(function(){
const D=%s, wrap=document.getElementById("mapwrap"), V="https://unpkg.com/maplibre-gl@4.7.1/dist/maplibre-gl";
const RASTER={version:8,sources:{c:{type:"raster",tileSize:256,attribution:"© OpenStreetMap contributors © CARTO",
  tiles:["a","b","c"].map(s=>"https://"+s+".basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png")}},layers:[{id:"c",type:"raster",source:"c"}]};
function layers(m){
  m.addSource("z",{type:"geojson",data:D.zones});
  m.addLayer({id:"zf",type:"fill",source:"z",paint:{"fill-color":["get","color"],"fill-opacity":["case",["==",["get","kind"],"green"],0.22,["==",["get","kind"],"ped"],0.45,0.18]}});
  m.addLayer({id:"zl",type:"line",source:"z",paint:{"line-color":["get","color"],"line-width":["case",["==",["get","kind"],"ped"],1,3.5]}});
  m.addSource("g",{type:"geojson",data:D.gates});
  m.addLayer({id:"gc",type:"circle",source:"g",paint:{"circle-radius":["interpolate",["linear"],["zoom"],10,1.5,13,3,15,5,17,7],"circle-color":"#1B2128","circle-stroke-color":"#fff","circle-stroke-width":["interpolate",["linear"],["zoom"],10,0.5,14,1.5,16,2]}});
  try{ m.addLayer({id:"zt",type:"symbol",source:"z",filter:["!=",["get","kind"],"ped"],layout:{"text-field":["get","name"],"text-size":14,"text-font":["Noto Sans Bold"],"symbol-placement":"point"},
    paint:{"text-color":["get","color"],"text-halo-color":"#fff","text-halo-width":2}}); }catch(e){}
  const pop=new maplibregl.Popup({closeButton:false});
  m.on("mousemove","gc",e=>{const n=e.features[0].properties.name; if(n){pop.setLngLat(e.lngLat).setText(n).addTo(m);}});
  m.on("mouseleave","gc",()=>pop.remove());
}
function start(style,fallback){
  const m=new maplibregl.Map({container:"realmap",style:style,bounds:D.bounds,fitBoundsOptions:{padding:30},attributionControl:{compact:true},cooperativeGestures:true});
  m.addControl(new maplibregl.NavigationControl({showCompass:false}),"top-right");
  let ok=false;
  const t=setTimeout(()=>{ if(!ok&&fallback){ m.remove(); start(RASTER,false);} },7000);
  // l'attribuzione compatta parte aperta e copre la mappa: chiusa nella «i» (si apre con un tocco)
  const fold=()=>{ const a=m.getContainer().querySelector(".maplibregl-ctrl-attrib"); if(a) a.classList.remove("maplibregl-compact-show"); };
  m.on("load",()=>{ ok=true; clearTimeout(t); layers(m); wrap.classList.add("on"); fold(); setTimeout(fold,0); });
  m.on("error",e=>{ if(!ok&&fallback&&String(e&&e.error&&e.error.message||"").match(/style|fetch|load/i)){ clearTimeout(t); try{m.remove();}catch(_){} start(RASTER,false);} });
}
function load(){
  const l=document.createElement("link"); l.rel="stylesheet"; l.href=V+".css"; document.head.appendChild(l);
  const s=document.createElement("script"); s.src=V+".js"; s.onload=()=>start("https://tiles.openfreemap.org/styles/liberty",true); document.head.appendChild(s);
}
if("IntersectionObserver" in window){ const io=new IntersectionObserver(es=>{ if(es.some(e=>e.isIntersecting)){ io.disconnect(); load(); } },{rootMargin:"300px"}); io.observe(wrap); } else load();
})();
</script>""" % data

def svg_map(c, lang):
    """Mappa disegnata dai perimetri ufficiali, come quella della home (colori per tipo di zona)"""
    pts = [p for z in c["zones"] for p in z["perimeter"]]
    box = dict(minLat=min(p["lat"] for p in pts) - .004, maxLat=max(p["lat"] for p in pts) + .004,
               minLon=min(p["lon"] for p in pts) - .006, maxLon=max(p["lon"] for p in pts) + .006)
    W = 1000
    kx = math.cos((box["minLat"] + box["maxLat"]) / 2 * math.pi / 180)
    H = round(W * (box["maxLat"] - box["minLat"]) / ((box["maxLon"] - box["minLon"]) * kx))
    X = lambda lon: round((lon - box["minLon"]) / (box["maxLon"] - box["minLon"]) * W)
    Y = lambda lat: round((box["maxLat"] - lat) / (box["maxLat"] - box["minLat"]) * H)
    d = lambda per: "M" + "L".join(f"{X(p['lon'])} {Y(p['lat'])}" for p in per) + "Z"
    area = lambda z: abs(sum((z["perimeter"][j]["lon"] + p["lon"]) * (z["perimeter"][j]["lat"] - p["lat"]) for j, p in zip(range(-1, len(z["perimeter"]) - 1), z["perimeter"])))
    out = [f'<svg viewBox="0 0 {W} {H}" role="img" aria-label="{esc(P[lang]["mapL"].format(c=city_name(c, lang)))}">']
    if c["id"] == "firenze":
        out.append(f'<path class="river" d="M0 {Y(43.7712)} C {X(11.240)} {Y(43.7705)}, {X(11.2470)} {Y(43.7700)}, {X(11.2531)} {Y(43.7679)} S {X(11.2620)} {Y(43.7655)}, {X(11.2720)} {Y(43.7640)} L {W} {Y(43.7625)}"/>')
    labels = []
    for z in sorted(c["zones"], key=area, reverse=True):
        k = kind_of(z)
        out.append(f'<path class="z {k}" d="{d(z["perimeter"])}"><title>{esc(loc(z, "name", lang))}</title></path>')
        lats, lons = [p["lat"] for p in z["perimeter"]], [p["lon"] for p in z["perimeter"]]
        cx = X((min(lons) + max(lons)) / 2)
        cy = Y(max(lats)) + 46 if k == "green" else Y((min(lats) + max(lats)) / 2)
        labels.append(f'<g class="lb {k}"><circle cx="{cx}" cy="{cy}" r="22"/><text x="{cx}" y="{cy + 8}">{esc(z["name"].split("·")[0].strip().split(" ")[-1])}</text></g>')
    for a in c.get("pedestrian") or []:
        out.append(f'<path class="ped" d="{d(a["perimeter"])}"><title>{esc(a["name"])}</title></path>')
    r = 4 if sum(len(z["gates"]) for z in c["zones"]) > 80 else 6
    for z in c["zones"]:
        for g in z["gates"]:
            out.append(f'<circle class="gate" cx="{X(g["location"]["lon"])}" cy="{Y(g["location"]["lat"])}" r="{r}"/>')
    return "".join(out + labels) + "</svg>"


CITY_CSS = """:root{--paper:#F4EFE6;--sheet:#FFFCF6;--well:#EEE7DA;--ink:#2B2433;--muted:#6B6372;--line:#DDD3C3;--brass:#A97E3F;--red:#C1272D;--blue:#1F4E9E;--green:#2B7A47;--amber-soft:#FBECC8;--map-land:#EAE3D5;--map-water:#C9DCE8;--pass:#D99A00;--lez:#0FA34A;--ped:#7A1F5C;
--display:"Titillium Web","Segoe UI",system-ui,sans-serif;--text:"Atkinson Hyperlegible Next",system-ui,-apple-system,"Segoe UI",sans-serif}
@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){--paper:#17141E;--sheet:#221E2B;--well:#1B1823;--ink:#EDE6F2;--muted:#ADA4B6;--line:#3A3445;--brass:#D6AA62;--red:#EF5B55;--blue:#8CB0EE;--green:#3E9A61;--amber-soft:#3A2C0E;--map-land:#211D29;--map-water:#1F3140;color-scheme:dark}}
:root[data-theme="dark"]{--paper:#17141E;--sheet:#221E2B;--well:#1B1823;--ink:#EDE6F2;--muted:#ADA4B6;--line:#3A3445;--brass:#D6AA62;--red:#EF5B55;--blue:#8CB0EE;--green:#3E9A61;--amber-soft:#3A2C0E;--map-land:#211D29;--map-water:#1F3140;color-scheme:dark}
*{box-sizing:border-box}
body{margin:0;background:var(--paper);color:var(--ink);font:17px/1.55 var(--text);padding:0 max(16px,env(safe-area-inset-right,0px)) 0 max(16px,env(safe-area-inset-left,0px))}
.wrap{max-width:860px;margin:0 auto}
a{color:var(--blue)}
:focus-visible{outline:3px solid var(--blue);outline-offset:2px;border-radius:6px}
h1,h2,h3{font-family:var(--display);line-height:1.08;margin:0;text-wrap:balance}
p{margin:0}
.label{font-family:var(--display);font-weight:600;font-size:13px;letter-spacing:.09em;text-transform:uppercase;color:var(--muted)}
.top{display:flex;align-items:center;justify-content:space-between;gap:12px;padding-block:18px;flex-wrap:wrap}
.brand{display:flex;align-items:center;gap:10px;text-decoration:none;color:var(--ink)}
.brand svg{width:36px;height:36px;border-radius:9px}
.brand b{font-family:var(--display);font-weight:700;font-size:24px}
.brand b span{color:var(--red)}
.langs{display:flex;background:var(--well);border-radius:10px;padding:3px}
.langs a{font:600 13px var(--display);letter-spacing:.03em;color:var(--muted);padding:5px 9px;border-radius:8px;text-decoration:none}
.langs a[aria-current]{background:var(--sheet);color:var(--ink)}
.hero{padding-block:18px 22px;display:grid;gap:14px}
.hero h1{font-size:clamp(42px,8vw,72px);font-weight:700;letter-spacing:-.02em}
.hero h1 em{font-style:normal;color:var(--red)}
.lead{font-size:19px;color:var(--muted);max-width:60ch}
.cta{display:inline-flex;align-items:center;gap:10px;justify-self:start;background:var(--blue);color:var(--sheet);border-radius:14px;padding:13px 20px;font:700 18px var(--display);text-decoration:none}
.draft{background:var(--amber-soft);border-radius:12px;padding:8px 12px;font-size:14px;font-weight:400}
.unoff{background:#FFB21E;color:#2B1A00;border-radius:12px;padding:10px 12px;font-size:16px;font-weight:700;line-height:1.35}
.unoff a{color:inherit}
.card{background:var(--sheet);border:1px solid var(--line);border-radius:18px;padding:20px;display:grid;gap:12px;margin-bottom:18px;min-width:0}
.card h2{font-size:28px;font-weight:700}
.card h3{font-size:19px;font-weight:700;margin-top:4px}
.kind{display:inline-flex;align-items:center;gap:8px;font:600 13px var(--display);letter-spacing:.08em;text-transform:uppercase;color:var(--muted)}
.sw{width:18px;height:12px;border-radius:3px;display:inline-block;border:2px dashed var(--c);background:color-mix(in srgb,var(--c) 22%,transparent);flex:none}
.sw.restricted{--c:var(--red)}.sw.pass{--c:var(--pass)}.sw.green{--c:var(--lez);border:3px solid var(--lez);background:color-mix(in srgb,var(--lez) 30%,transparent)}.sw.ped{--c:var(--ped);border-style:solid;background:var(--ped)}
table{border-collapse:collapse;width:100%;font-size:16px}
td{padding:8px 0;border-bottom:1px solid var(--line);vertical-align:top}
tr:last-child td{border-bottom:0}
td+td{text-align:right;font-weight:600;padding-left:12px}
td.free{color:var(--green)}
.price{font:700 34px/1 var(--display)}
ul{margin:0;padding-left:20px;display:grid;gap:6px}
.muted{color:var(--muted);font-size:15px}
blockquote{margin:0;border-left:3px solid var(--brass);padding:2px 0 2px 12px;font-size:15px}
blockquote p+p{color:var(--muted)}
.map{padding:12px}
.map svg{width:100%;height:auto;display:block;border-radius:14px;background:var(--map-land)}
.mapwrap{position:relative;min-height:340px}
.mapwrap .real{position:absolute;inset:0;border-radius:14px;overflow:hidden;opacity:0;transition:opacity .3s}
.mapwrap.on .real{opacity:1}.mapwrap.on svg{visibility:hidden}
.mapwrap svg{min-height:340px;object-fit:cover}
.maplibregl-ctrl-attrib{font-size:11px}
.z{stroke-linejoin:round}.z.restricted{fill:var(--red);fill-opacity:.1;stroke:var(--red);stroke-width:2;stroke-dasharray:9 6}
.z.pass{fill:var(--pass);fill-opacity:.12;stroke:var(--pass);stroke-width:2.5;stroke-dasharray:9 6}.z.green{fill:var(--lez);fill-opacity:.16;stroke:var(--lez);stroke-width:5}
.ped{fill:var(--ped);fill-opacity:.65;stroke:var(--ped);stroke-width:1}.gate{fill:var(--ink);stroke:var(--sheet);stroke-width:2}.river{fill:none;stroke:var(--map-water);stroke-width:22;stroke-linecap:round}
.lb circle{fill:var(--sheet);stroke-width:2.5}.lb text{font:700 25px var(--display);text-anchor:middle}
.lb.restricted circle{stroke:var(--red)}.lb.restricted text{fill:var(--red)}.lb.pass circle{stroke:var(--pass)}.lb.pass text{fill:var(--pass)}.lb.green circle{stroke:var(--lez);stroke-width:4}.lb.green text{fill:var(--lez)}
.legend{display:flex;gap:14px;flex-wrap:wrap;font-size:14px;color:var(--muted);padding-inline:6px}
.legend span{display:inline-flex;align-items:center;gap:6px}
.dot{width:11px;height:11px;border-radius:50%;background:var(--ink)}
details summary{cursor:pointer;font-weight:600}
.faq details{border-top:1px solid var(--line);padding-block:10px}
.faq details:first-of-type{border-top:0}
.faq details p{margin-top:8px}
.cities{display:flex;gap:10px;flex-wrap:wrap}
.cities a{font:400 15px var(--text);letter-spacing:.01em;color:var(--ink);background:var(--sheet);border:1px solid var(--line);border-radius:999px;padding:7px 14px;text-decoration:none}
footer{border-top:1px solid var(--line);margin-top:24px;padding-block:22px 40px;display:grid;gap:10px;color:var(--muted);font-size:14px}.maplibregl-ctrl-group button{width:40px;height:40px}
"""
LOGO = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="10 4 468 468" aria-hidden="true"><defs> <linearGradient id="lg-bg" gradientUnits="userSpaceOnUse" x1="244" y1="4" x2="244" y2="472"><stop offset="0" stop-color="#1D2948"/><stop offset=".55" stop-color="#101A30"/><stop offset="1" stop-color="#060D1A"/></linearGradient> <radialGradient id="lg-red" cx=".35" cy=".25" r=".9"><stop offset="0" stop-color="#FF5A50"/><stop offset=".6" stop-color="#F0302A"/><stop offset="1" stop-color="#C81E1C"/></radialGradient> <linearGradient id="lg-band" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#0E1A33"/><stop offset=".55" stop-color="#26355A"/><stop offset="1" stop-color="#5B6B8C"/></linearGradient> <linearGradient id="lg-white" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#E9ECF2"/></linearGradient> <filter id="lg-sh" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="4" stdDeviation="5" flood-color="#000" flood-opacity=".35"/></filter></defs><rect x="10" y="4" width="468" height="468" fill="url(#lg-bg)"/><path d="M244 432 L125.2 274.8 A137 137 0 1 1 355.5 267.5 Z" fill="url(#lg-red)" filter="url(#lg-sh)"/><circle cx="240" cy="187" r="80" fill="#FFFFFF"/><rect x="180" y="168" width="118" height="44" rx="10" fill="#F2302B"/><text x="239" y="191" text-anchor="middle" dominant-baseline="central" font-family="Inter Display, Inter, Helvetica Neue, Arial" font-weight="800" font-size="34" fill="#FFFFFF" letter-spacing="1">ZTL</text><path d="M359 250 C300 258 205 280 168 312 C138 338 140 372 168 392 L236 420 L190 472 L478 472 L478 236 Z" fill="url(#lg-bg)"/><path d="M359 250 C300 258 205 280 168 312 C138 338 140 372 168 392 L236 420 L254 408 C226 392 200 366 202 343 C205 314 268 280 352 254 Z" fill="url(#lg-band)"/><path d="M359 250 C300 258 205 280 168 312 C138 338 140 372 168 392 L236 420" fill="none" stroke="url(#lg-white)" stroke-width="14" stroke-linecap="round" stroke-linejoin="round"/><path d="M352 254 C268 280 205 314 202 343 C200 366 226 392 254 408" fill="none" stroke="url(#lg-white)" stroke-width="11" stroke-linecap="round"/></svg>'
FONTS = '<link rel="preconnect" href="https://fonts.googleapis.com">\n<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>\n<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Titillium+Web:wght@600;700&family=Atkinson+Hyperlegible+Next:wght@400;500;600;700&display=swap">'


CUR = ' aria-current="page"'


def city_url(c, lang): return SITE + prefix(lang) + c["id"] + "/"


def build_city(c, lang):
    p, t, cn = P[lang], T[lang], city_name(c, lang)
    root = "../" if lang == "en" else "../../"
    today = date.today().isoformat()
    zones = sorted(c["zones"], key=lambda z: ["pass", "restricted", "green"].index(kind_of(z)) if kind_of(z) in ("pass", "restricted", "green") else 9)
    checked = max(z["source"]["checkedOn"] for z in c["zones"])
    peds = c.get("pedestrian") or []
    # FAQ (anche come JSON-LD)
    qas = [(p["qWhen"].format(c=cn), " ".join(f"{zone_label(z, lang)}: {loc(z, 'summary', lang)}" for z in zones))]
    if fine:
        qas.append((p["qFine"].format(c=cn), p["aFine"].format(a=fine["min"], b=fine["max"]) + " " + (fine.get("notes_" + lang) or fine["notes"])[0]))
    hz = [zone_label(z, lang) for z in zones if z.get("hotelCanRegister")]
    qas.append((p["qHotel"].format(c=cn), p["aHotelY"].format(z=join_and(hz, lang)) if hz else p["aHotelT"] if any(z.get("ticket") for z in zones) else p["aHotelN"]))
    for z in zones:
        if z.get("ticket"):
            tk = z["ticket"]
            qas.append((p["qTicket"].format(c=cn), f"{zone_label(z, lang)}: {money(tk['price'], lang)}, {DL[lang].get(tk.get('deadline'), '')}. {loc(tk, 'howTo', lang)}"))
        if kind_of(z) == "green":
            bl = ban_lines(z, lang, today)
            qas.append((p["qGreen"].format(z=zone_label(z, lang)), p["rental"] + (" " + p["bansT"] + ": " + "; ".join(f"{a} ({b})" for a, b in bl) + "." if bl else "")
                        + (" " + p["electric"] if "electric" in (z.get("exemptFuels") or []) else "")))
    if peds: qas.append((p["qPed"].format(c=cn), p["aPed"]))

    alts = {l: city_url(c, l) for l in LANGS}
    graph = [faq(qas), {"@type": "WebPage", "name": p["title"].format(c=cn), "url": city_url(c, lang), "inLanguage": lang,
             "dateModified": checked[:10], "isPartOf": {"@id": SITE + "#site"},
             "breadcrumb": {"@type": "BreadcrumbList", "itemListElement": [
                 {"@type": "ListItem", "position": 1, "name": "GateLR", "item": SITE + prefix(lang)},
                 {"@type": "ListItem", "position": 2, "name": f"ZTL {cn}", "item": city_url(c, lang)}]}}]
    unoff = any(unofficial(z) for z in c["zones"])
    hd = head(lang, p["title"].format(c=cn), p["descU" if unoff else "desc"].format(c=cn, d=day(checked, lang)), city_url(c, lang), alts, root, graph)
    home = root + prefix(lang)
    B = []
    B.append(f'<header class="top"><a class="brand" href="{home}" aria-label="GateLR {p["home"]}">{LOGO}<b>Gate<span>LR</span></b></a>'
             '<nav class="langs" aria-label="Language">' + "".join(
                 f'<a href="{root}{prefix(l)}{c["id"]}/" hreflang="{l}" lang="{l}"{CUR if l == lang else ""}>{l.upper()}</a>' for l in LANGS) + "</nav></header>")
    B.append(f'<main><section class="hero"><span class="label">{esc(p["kicker"])}</span><h1>{p["h1"].format(c=esc(cn))}</h1>'
             f'<p class="lead">{esc(p["leadU" if unoff else "lead"].format(c=cn))}</p><a class="cta" href="{home}#{c["id"]}">{esc(p["cta"])} →</a>'
             f'<p class="muted">{esc(p["ctaN"])}</p>'
             # Zone da fonti non ufficiali: l'avviso al posto di «Bozza: dalle fonti ufficiali…»
             + (f'<p class="unoff" role="note">⚠ {esc(t["unoff"])}</p>' if unoff
                else f'<p class="draft">{esc(t["draft"])}</p>' if c.get("status") != "verified" else "") + "</section>")
    # mappa e legenda
    kinds = [k for k in ("restricted", "pass", "green") if any(kind_of(z) == k for z in zones)]
    leg = "".join(f'<span><i class="sw {k}"></i>{esc(t[{"restricted": "lsector", "pass": "lpass", "green": "lgreen"}[k]])}</span>' for k in kinds)
    if peds: leg += f'<span><i class="sw ped"></i>{esc(t["lped"])}</span>'
    leg += f'<span><i class="dot"></i>{esc(t["lgate"])}</span>'
    B.append(f'<section class="card map"><div class="mapwrap" id="mapwrap"><div class="real" id="realmap"></div>{svg_map(c, lang)}</div><div class="legend">{leg}</div></section>')
    B.append(map_script(c, lang))
    for z in zones:
        k, s = kind_of(z), z["source"]
        rows = "".join(f'<tr><td>{esc(a)}</td><td class="{cl}">{esc(b)}</td></tr>' for a, b, cl in hour_rows(z, lang))
        h = [f'<section class="card" id="{z["id"]}"><span class="kind"><i class="sw {k}"></i>{esc(p["kind"][k])}</span>',
             f'<h2>{esc(loc(z, "name", lang))}</h2>' + (f'<p class="unoff" role="note">⚠ {esc(t["unoff"])}</p>' if unofficial(z) else "")
             + f'<p>{esc(loc(z, "summary", lang))}</p>',
             f'<h3>{esc(p["hours"])}</h3><table>{rows}</table>']
        if z.get("ticket"):
            tk = z["ticket"]
            h.append(f'<h3>{esc(p["ticketT"])}</h3><p class="price">{money(tk["price"], lang)}</p>'
                     f'<p><b>{esc(DL[lang].get(tk.get("deadline"), "").capitalize())}.</b> {esc(loc(tk, "howTo", lang))}</p>'
                     + (f'<p><a href="{esc(tk["url"])}" rel="noopener">{esc(p["buy"])}</a></p>' if tk.get("url") else ""))
        if k == "green" or z.get("bans"):
            bl = ban_lines(z, lang, today)
            h.append(f'<h3>{esc(p["bansT"])}</h3>' + (f'<p>{esc(p["rental"])}</p>' if k == "green" else "")
                     + ("<ul>" + "".join(f'<li>{esc(a)} <span class="muted">· {esc(b)}</span></li>' for a, b in bl) + "</ul>" if bl else "")
                     + (f'<p class="muted">{esc(p["electric"])}</p>' if "electric" in (z.get("exemptFuels") or []) else ""))
        if k != "green":
            h.append(f'<h3>{esc(p["hotelT"])}</h3><p>{esc(p["hotelY"] if z.get("hotelCanRegister") else p["hotelN"])}</p>')
        if "motorcycle" in (z.get("exemptVehicleTypes") or []): h.append(f'<p class="muted">{esc(p["moto"])}</p>')
        if z["gates"]: h.append(f'<p class="muted">{esc(p["gates"].format(n=len(z["gates"])))}</p>')
        quote = f'<p>“{esc(s["quote"])}”</p>' if s.get("quote") else ""
        tr = s.get("quoteTranslation_" + lang) if lang != "en" else s.get("quoteTranslation")
        if quote and lang != "it" and tr: quote += f"<p>{esc(tr)}</p>"
        links = [l for l in s.get("links") or [] if l.get("url") and l["url"] != s.get("pageURL")]
        pend = s.get("pending_" + lang) or s.get("pending") or []
        u = s.get("unofficialSource") if unofficial(z) else None
        h.append(f'<h3>{esc(p["srcU" if unofficial(z) else "srcT"])}</h3>'
                 + (f'<p><a href="{esc(u["url"])}" rel="noopener">{esc(p["dataFrom"].format(s=u["name"]))}</a></p>' if u and u.get("url") else "")
                 + f'<p>{esc(s.get("authority") or "")} · <a href="{esc(s["pageURL"])}" rel="noopener">{esc(p["page"])}</a></p>'
                 + (f"<blockquote>{quote}</blockquote>" if quote else "")
                 + (f'<ul>' + "".join(f'<li><a href="{esc(l["url"])}" rel="noopener">{esc(loc(l, "title", lang) or l["url"])}</a></li>' for l in links) + "</ul>" if links else "")
                 + f'<p class="muted">{esc(p["checked"].format(d=day(s["checkedOn"], lang)))}</p>'
                 + (f'<details><summary class="muted">{esc(p["pending"])}</summary><ul class="muted">' + "".join(f"<li>{esc(x)}</li>" for x in pend) + "</ul></details>" if pend else ""))
        B.append("".join(h) + "</section>")
    if peds:
        names = sorted({a["name"] for a in peds})
        B.append(f'<section class="card" id="pedestrian"><span class="kind"><i class="sw ped"></i>{esc(p["pedT"])}</span><h2>{esc(p["pedT"])}</h2>'
                 f'<p>{esc(p["pedP"].format(n=len(peds)))}</p><details><summary>{esc(p["pedAll"].format(n=len(names)))}</summary>'
                 f'<p class="muted" style="margin-top:8px">{esc(", ".join(names))}</p></details></section>')
    if fine:
        notes = fine.get("notes_" + lang) or fine["notes"]
        B.append(f'<section class="card"><span class="label">{esc(p["fineL"])}</span><h2>{esc(t["fineT"])}</h2>'
                 f'<p class="price" style="color:var(--red)">€{fine["min"]}–{fine["max"]} <span class="muted">{esc(p["perDay"])}</span></p>'
                 "<ul>" + "".join(f"<li>{esc(n)}</li>" for n in notes) + f'</ul><p class="muted">{esc(t["stillChecking"])}</p></section>')
    B.append(f'<section class="card faq"><h2>{esc(p["faqT"])}</h2>' + "".join(f"<details><summary>{esc(q)}</summary><p>{esc(a)}</p></details>" for q, a in qas) + "</section>")
    B.append(f'<p><a class="cta" href="{home}#{c["id"]}">{esc(p["cta"])} →</a></p>')
    B.append(f'<nav class="cities" aria-label="{esc(p["other"])}" style="margin-top:22px"><span class="label" style="align-self:center">{esc(p["other"])}</span>'
             + "".join(f'<a href="{root}{prefix(lang)}{o["id"]}/">ZTL {esc(city_name(o, lang))}</a>' for o in cities if o is not c) + "</nav></main>")
    B.append(f'<footer><p><a href="{home}">GateLR</a> · <a href="{root}privacy/">Privacy</a> · <a href="{root}support/">Support</a> · '
             f'<a href="mailto:support@example.com">support@example.com</a></p><p>{esc(c.get("license", ""))}. {esc(t["foot"])}</p></footer>')
    page = (f'<!doctype html>\n<html lang="{lang}">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">\n'
            f'{hd}\n{FONTS}\n<style>\n{CITY_CSS}\n</style>\n</head>\n<body>\n<div class="wrap">\n' + "\n".join(B) + "\n</div>\n</body>\n</html>\n")
    out = WEB / prefix(lang) / c["id"] / "index.html"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(page, encoding="utf-8")
    return out


# ── Sitemap, robots e icona ───────────────────────────────────────────────────
def sitemap():
    groups = [HOME_ALT] + [{l: city_url(c, l) for l in LANGS} for c in cities]
    lastmod = max(z["source"]["checkedOn"] for c in cities for z in c["zones"])[:10]
    urls = []
    for g in groups:
        alt = "".join(f'<xhtml:link rel="alternate" hreflang="{l}" href="{u}"/>' for l, u in g.items()) + f'<xhtml:link rel="alternate" hreflang="x-default" href="{g["en"]}"/>'
        urls += [f"<url><loc>{u}</loc><lastmod>{lastmod}</lastmod>{alt}</url>" for u in g.values()]
    (WEB / "sitemap.xml").write_text('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">\n'
                                     + "\n".join(urls) + "\n</urlset>\n", encoding="utf-8")
    (WEB / "robots.txt").write_text(f"User-agent: *\nAllow: /\n\nSitemap: {SITE}sitemap.xml\n", encoding="utf-8")


if __name__ == "__main__":
    made = [build_home(l) for l in LANGS] + [build_city(c, l) for c in cities for l in LANGS]
    sitemap()
    if ICON.exists(): shutil.copyfile(ICON, WEB / "icon.png")
    for f in made: print(f.relative_to(ROOT), f.stat().st_size, "byte")
    print("web/sitemap.xml, web/robots.txt ·", len(cities), "città · multe:", "sì" if fine else "in verifica")
