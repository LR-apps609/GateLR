#!/usr/bin/env python3
# Costruisce Resources/Cities/arezzo.json dalle pagine e dagli atti ufficiali del Comune di Arezzo salvati in
# data/raw/arezzo/ (fonti e date in docs/fonti-arezzo.md).
# Regole: Disciplinare ZTL (delibera GC 124 del 30/03/2023, testo «in fase di aggiornamento» rev. 1.4 pubblicato dal
# Comune), artt. 3–5 (orari ZTL A e B, zona pedonale), 9 (varchi), 30 (auto elettriche), 32 (accessi giornalieri),
# 33 (disabili), 38 (alberghi) e allegati 1–4 (elenco delle vie); pagina «Accesso temporaneo nella ZTL»;
# ordinanza 245/2026 (area pedonale estiva del venerdì e sabato sera).
# Perimetri: Arezzo non pubblica dati aperti sulla ZTL e in OpenStreetMap non ci sono relazioni ZTL. I contorni vengono
# dalla mappa ufficiale (planimetria aggiornata al 25/09/2025) agganciata in automatico alle strade di OSM da
# Tools/arezzo_mappa.py (data/raw/arezzo/ztl-mappa-ufficiale.geojson; mai disegnati a mano). Qui sono controllati contro
# l'elenco ufficiale delle vie (allegati 1 e 2 del disciplinare) sulle geometrie OSM delle strade, con i tratti
# «da via X a via Y» tagliati tra i due incroci. Dati OSM: data/raw/geo/arezzo-streets.json
# (API OSM 0.6 /map, © OpenStreetMap contributors, ODbL 1.0).
# Varchi: l'elenco dell'art. 9 del disciplinare, messi nel punto della via indicata più vicino all'incrocio indicato.
# Non aggiorna manifest.json. Uso: python3 Tools/build_arezzo.py
import html, json, math, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/arezzo"
CHECKED = "2026-10-26T08:00:00Z"
BASE = "https://www.comune.arezzo.it"
TEMP_PAGE = BASE + "/documento-pubblico/accesso-temporaneo-nella-ztl-zona-traffico-limitato"
IRREG_PAGE = BASE + "/accesso-irregolare-ztl-zona-traffico-limitato"
RULES_PAGE = BASE + "/documento-pubblico/ztl-vigore-dal-3-aprile-2023"
RULES_PDF = BASE + "/sites/default/files/2025-07/copia_per_revisione_2023_senza_eliminati_rev1.4_definitiva_con_assessore.pdf"
MAP_PAGE = BASE + "/documento-pubblico/la-planimetria-ztl"
MAP_PDF = BASE + "/sites/default/files/2025-09/planimetria%20ztl_aggiornata%20al%2025_09_2025_.pdf"
CAMERAS_PAGE = BASE + "/documento-pubblico/videocontrollo-ztl-e-corsie-preferenziali"
PORTAL = "https://permessiztl.comune.arezzo.it/"
SUMMER_PAGE = BASE + "/novita/pedonalizzazione-temporanea-di-alcune-strade-del-centro-storico-2"
SUMMER_PDF = BASE + "/sites/default/files/2026-05/ord_pedonalizzazione%20centro%20storico_2026_245.odt.pdf"
FIERA_PDF = "https://comune.arezzo.it/sites/default/files/2026-08/ORD%201026%20Fiera%20Antiquaria%20edizione%20Settembre%202026.pdf"
GIOSTRA_PDF = BASE + "/sites/default/files/2026-09/ORD%201047%20Giostra%20del%20Saracino%20edizione%20settembre%202026.pdf"
ORDINANCE = "Disciplinare ZTL (Delibera G.C. n. 124 del 30/03/2023), testo rev. 1.4 «in fase di aggiornamento»"
MON_SAT, EVERY_DAY = [2, 3, 4, 5, 6, 7], [1, 2, 3, 4, 5, 6, 7]


def flat(text):
    return re.sub(r"\s+", " ", text).strip()


def page_text(name):
    t = (RAW / name).read_text(encoding="utf-8")
    t = re.sub(r"<(script|style)[^>]*>.*?</\1>", " ", t, flags=re.S)
    return flat(html.unescape(re.sub(r"<[^>]+>", " ", t)))


def must_contain(text, quote, where):
    """Ogni frase citata o riassunta deve esserci davvero nel documento salvato"""
    if flat(quote) not in text:
        raise SystemExit(f"Citazione non trovata in {where}: {quote!r}")


# --- Le frasi su cui si basa la scheda, controllate contro i file in data/raw/arezzo/ ---
rules = flat((RAW / "disciplinare-ztl-2023-rev1.4.txt").read_text(encoding="utf-8"))
temp = page_text("accesso-temporaneo-ztl.html")
irreg = page_text("accesso-irregolare-ztl.html")
summer = flat((RAW / "ordinanza-245-2026-pedonalizzazione-estiva.txt").read_text(encoding="utf-8"))
giostra = flat((RAW / "ordinanza-1047-2026-giostra.txt").read_text(encoding="utf-8"))
cameras = page_text("videocontrollo-ztl.html")
rules_page = page_text("ztl-vigore-dal-3-aprile-2023.html")

QUOTE_A = ("Nella ZTL A vige il divieto di circolazione e sosta per i veicoli a motore (sprovvisti di regolare "
           "autorizzazione) dalle ore 8,30 alle ore 12,00 e dalle ore 17,00 alle ore 20,00 dei giorni feriali.")
QUOTE_B = ("Nella ZTL B vige il divieto di circolazione e sosta per i veicoli a motore (sprovvisti di regolare "
           "autorizzazione) tutti i giorni dalle ore 8,00 alle ore 24,00.")
QUOTE_HOTEL = ("I clienti diretti agli alberghi situati all’interno della Zona a Traffico Limitato, purché provvisti di "
               "prenotazione, sono autorizzati senza alcuna formalità a raggiungere l’albergo esclusivamente per "
               "effettuare le operazioni di carico e scarico dei bagagli.")
for q in [QUOTE_A, QUOTE_B, QUOTE_HOTEL,
          "Sono esclusi dal divieto i ciclomotori a due ruote, motocicli a due ruote e i veicoli dotati di "
          "motorizzazione solamente elettrica, quest'ultimi previo inserimento della targa nell'apposita lista bianca di cui all'art. 30.",
          "Nella Zona Pedonale la circolazione e sosta dei veicoli a motore sono permanentemente vietate.",
          "Per essere autorizzati all'accesso è necessario che il cliente o l'albergatore provvedano all'inserimento "
          "della targa del veicolo nel Portale ZTL allegando la documentazione richiesta",
          "Il pass avrà validità di 3 anni ed il contributo previsto per il rilascio è di 5 euro.",
          "possono transitare senza limiti di orario all’interno della ZTL A e ZTL B.",
          "il transito è comunque consentito purché si provveda alla comunicazione medesima entro le 48 ore successive.",
          "È richiesto il pagamento di un contributo pari ad € 10,00 giornalieri per i veicoli della categoria L, M1, e N1",
          "Il numero massimo dei permessi giornalieri ottenibili annualmente per il medesimo veicolo è pari a 20.",
          "il termine “USCITA” indica che il controllo del transito è effettuato a monte dell’indicazione di “FINE ZTL”."]:
    must_contain(rules, q, "disciplinare ZTL rev. 1.4")
for q in ["€ 15,00 al giorno, per veicoli della categoria L, M1, N1;", "€ 10,00 al giorno, per auto elettrica.",
          "nella ZTL A: dalle 8,30 alle 12,00;", "nella ZTL B: dalle 8,00 alle 11,00 e dalle 14,00 alle 16,00.",
          "Accesso provvisorio giornaliero riservato a ospiti di strutture ricettive (alberghi, b&b, eccetera), strutture sanitarie, operatori Fiera Antiquaria",
          "permessiztl@comune.arezzo.it", "numero verde 800211155",
          "Tutta la disciplina in materia di autorizzazioni ZTL è compresa nel disciplinare adottato con deliberazione GC n. 124 del 30.3.2023"]:
    must_contain(temp, q, "pagina Accesso temporaneo")
for q in ["Gli accessi irregolari sono rilevati automaticamente e trasmessi alla Polizia Locale"]:
    must_contain(irreg, q, "pagina Accesso irregolare")
for q in ["dal 15/05/2026 al 12/09/2026, ad esclusione dei giorni 19 e 20 giugno 2026 e dei giorni 4 e 5 settembre 2026",
          "dalle ore 19:00 alle ore 24:00, nei giorni di venerdì e sabato, sono istituiti il divieto di transito e di sosta con rimozione dei veicoli",
          "ORDINANZA N. 245"]:
    must_contain(summer, q, "ordinanza 245/2026")
for q in ["Dalle ore 08:00 alle ore 24:00 è sospesa la disciplina di Z.T.L. di tipo “B”"]:
    must_contain(giostra, q, "ordinanza 1047/2026")
for q in ["Il sistema conta n. 24 varchi posizionati agli accessi ed alle uscite della ZTL",
          "dal 01/01/2025 è iniziata la piena operatività"]:
    must_contain(cameras, q, "pagina Videocontrollo ZTL")
must_contain(rules_page, "IN FASE DI AGGIORNAMENTO", "pagina Disciplinare in vigore dal 3 aprile 2023")


# --- Geometria: le vie degli allegati 1 (ZTL A) e 2 (ZTL B), con i nomi di OpenStreetMap ---
# (nomi OSM, incrocio di inizio, incrocio di fine): solo il tratto tra i due incroci dell'elenco ufficiale.
ZTL_A_STREETS = [
    (["Via Borgo Santa Croce"],), (["Piaggia di Murello"],), (["Piaggia San Bartolomeo"],), (["Piaggia San Lorenzo"],),
    (["Piazzetta dei Bacci"],), (["Piazzetta dietro il Duomo"],), (["Piazzetta Faenzi"],),
    (["Piazzetta di Sant'Agnese", "Piazzetta di S.Agnese"],), (["Piazza di Murello"],), (["Piazza della Fioraia"],),
    (["Piazza Madonna del Conforto"],), (["Piazza San Gemignano"],), (["Piazza San Lorenzo", "Piazzetta di San Lorenzo"],),
    (["Piazza San Niccolò"],), (["Piazza Santa Maria in Gradi"],), (["Piazza Santa Maria Maddalena"],),
    (["Piazza Lando Landucci"],), (["Vicolo Appuntellato"],), (["Via Fanale"],), (["Vicolo del Marcianello"],),
    (["Vicolo dell'Orto"],), (["Vicolo della Minerva"],),
    (["Vicolo delle Terme"], "Via Borgo Santa Croce", "Viale Bruno Buozzi"),
    (["Via Sotto la Volta"],), (["Via Adua"],), (["Via Aliotti"],),
    (["Via Andrea Sansovino"],),
    (["Via Antonio Guadagnoli"], "Via Macallè", "Via delle Gagliarde"),
    (["Via Arrigo Testa"],), (["Via Asmara"],), (["Via Aurelio Saffi"],), (["Via del Balilla"],),
    (["Via Bartolomeo di Ser Gorello"],),
    (["Via Borgunto", "Borg'Unto"], "Via Pescioni", "Piaggia San Bartolomeo"),
    (["Viale Bruno Buozzi"], "Via Ricasoli", "Vicolo delle Terme"),
    (["Via Cavour"], "Via Guido Monaco", "Piaggia di Murello"),
    (["Via Cenne della Chitarra"],), (["Via Colcitrone"],), (["Via de' Pecori"],), (["Via dei Palagi"],),
    (["Via del Saracino"],), (["Via dell'Agania"],), (["Via della Chiassaia"],),
    (["Via della Fioraia"], "Via Giosuè Carducci", "Piazza della Fioraia"),
    (["Via della Madonna"],), (["Via della Minerva"],), (["Via delle Fosse"],), (["Via delle Gagliarde"],),
    (["Via delle Mura"],), (["Via delle Paniere"],), (["Via Dietro le Campane"],),
    (["Via Eritrea"], "Via Fra' Guittone", "Via Guglielmo di Marcillat"),
    (["Via Fontanella"],), (["Via fra le Torri"],), (["Via Giosuè Carducci"],),
    (["Via Giuseppe Garibaldi"], "Via Trento e Trieste", "Piazza Sant'Agostino"),
    (["Via Giuseppe Mazzini"], "Via Pescioni", "Via dell'Agania"),
    (["Via Guglielmo Marconi"], "Via Guglielmo di Marcillat", "Via Cenne della Chitarra"),
    (["Via Guglielmo Oberdan"], "Via dell'Agania", "Piazza San Gemignano"),
    (["Via Guido Monaco"], "Via Giuseppe Garibaldi", "Via Cavour"),   # «da varco elettronico a via Cavour»: vedi pending
    (["Via Isidoro Del Lungo"], "Piazzetta Logge del Grano", "Via Cavour"),
    (["Via Licio Nencetti"],), (["Via Madonna Laura"],), (["Via Modesta Rossi"],), (["Via Padre Caprara"],),
    (["Via Pellicceria"],), (["Via Pescaiolina"],), (["Via Pescioni"],), (["Via Piana"],), (["Via Ricasoli"],),
    (["Via San Clemente"], "Via Giuseppe Garibaldi", "Via San Domenico"),
    (["Via San Domenico"],), (["Via San Lorentino"],), (["Via San Lorenzo"],), (["Via San Niccolò"],),
    (["Via Santa Maria Maddalena"],), (["Via Sante Tani"],), (["Via di Sasso Verde"],), (["Via Venti Settembre"],),
]
ZTL_B_STREETS = [
    (["Corso Italia"], "Via Spinello", "Via de' Pileati"),
    (["Piaggia San Martino"], "Via Pellicceria", "Piazzetta del Praticino"),
    (["Piazzetta del Praticino"],), (["Piazza del Commissario"],), (["Piazza Grande"],), (["Piazza San Michele"],),
    (["Via Andrea Cesalpino"],), (["Via della Bicchieraia"],),
    (["Via Borgunto", "Borg'Unto"], "Piaggia San Bartolomeo", "Piazza Grande"),
    (["Via Cavour"], "Corso Italia", "Via Andrea Cesalpino"),
    (["Via degli Albergotti"],), (["Via de' Pileati"],), (["Via dell'Orto"],),
    (["Via della Fioraia"], "Via Giosuè Carducci", "Via Andrea Cesalpino"),
    (["Via Seteria"],),
    (["Via Giuseppe Garibaldi"], "Via Guido Monaco", "Corso Italia"),   # «da via G. Monaco a Galleria B. Cairoli»
    (["Via Giuseppe Mazzini"], "Via dell'Agania", "Corso Italia"),
    (["Via Lorentino D'Arezzo"],),
    (["Via Madonna del Prato"],),   # due tratti nell'elenco (via Roma–via Beccheria, via Spinello–vicolo dei Cavallanti)
    (["Via Mannini"],), (["Via de' Montetini"],),
    (["Via Guglielmo Oberdan"], "Piazza San Michele", "Via dell'Agania"),
    (["Via Pescaia"],), (["Via San Francesco"],), (["Via Tolletta"],),
    (["Vicolo del capitano Ardelli"],), (["Vicolo dei Cavallanti"],), (["Vicolo della Dea"],),
]
# Vie dell'elenco ufficiale che in OSM non hanno un nome riconoscibile (o sono aree di parcheggio): restano fuori
MISSING = ["Largo Benadir", "Piazza di Porta Crucifera", "Piazza San Giusto", "Piazzale delle Bandiere",
           "Vicolo della Palestra (parcheggio)", "Via Brava", "Via Ghibellina", "Via Pio Borri", "Via Rodi (parcheggio)",
           "Via Santi di Tito"]
# Aree pedonali dell'allegato 3 che in OSM sono un'area con lo stesso nome
PEDESTRIAN = {22720357: "Piazza Grande", 184077925: "Piazza del Duomo", 22719358: "Piazza della Badia",
              1346063342: "Piazza della Libertà", 617671811: "Piazza San Domenico", 22719184: "Piazza San Francesco",
              22718505: "Piazza San Jacopo", 342536769: "Piazza Sant'Agostino",
              617669632: "Piazza della Santissima Annunziata"}

ELEMENTS = osm_geo.load("arezzo-streets")
WAYS = [e for e in ELEMENTS if e["type"] == "way" and ("highway" in e["tags"] or e["tags"].get("place") == "square")]
BY_NAME = {}
for w in WAYS:
    if w["tags"].get("name"):
        BY_NAME.setdefault(w["tags"]["name"], []).append([(n["lon"], n["lat"]) for n in w["geometry"]])


def lines_of(names):
    out = [l for n in names for l in BY_NAME.get(n, [])]
    if not out:
        raise SystemExit(f"Via non trovata in OSM: {names}")
    return out


def nearest(names, other):
    """Il punto della via più vicino alla via «other» (l'incrocio)"""
    pts = [p for l in lines_of(names) for p in l]
    opts = [p for l in lines_of([other]) for p in l]
    return min(pts, key=lambda p: min((p[0] - q[0]) ** 2 * 0.53 + (p[1] - q[1]) ** 2 for q in opts))


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


def street_lines(streets):
    lines = []
    for s in streets:
        for l in lines_of(s[0]):
            lines += clip(l, nearest(s[0], s[1]), nearest(s[0], s[2])) if len(s) == 3 else [l]
    return lines


# --- Perimetri dalla mappa ufficiale agganciata (Tools/arezzo_mappa.py) ---
MAP = json.loads((RAW / "ztl-mappa-ufficiale.geojson").read_text(encoding="utf-8"))
RINGS = {"A": [], "B": []}
for f in MAP["features"]:
    RINGS[f["properties"]["zone"]].append([tuple(p) for p in f["geometry"]["coordinates"][0]])
inside_any = lambda rings, p: any(osm_geo.inside_lonlat(r, *p) for r in rings)
near_any = lambda rings, p, m: inside_any(rings, p) or min(osm_geo.distance_m(r, p[1], p[0]) for r in rings) < m

# Controllo incrociato tra le due fonti ufficiali: le vie degli allegati 1 e 2 devono cadere nelle zone della mappa
lines_a, lines_b = street_lines(ZTL_A_STREETS), street_lines(ZTL_B_STREETS)
mid = lambda l: l[len(l) // 2]
share_a = sum(near_any(RINGS["A"], mid(l), 10) for l in lines_a + lines_b) / len(lines_a + lines_b)
share_b = sum(near_any(RINGS["B"], mid(l), 10) for l in lines_b) / len(lines_b)
assert share_a >= 0.9 and share_b >= 0.85, (share_a, share_b)

# --- Varchi: art. 9 del disciplinare (via, incrocio di riferimento, nome) ---
GATES = [
    (["Corso Italia"], "Via Roma", "1 · Corso Italia, north of Via Roma (entry)"),
    (["Corso Italia"], "Via Spinello", "2 · Corso Italia, from Via Spinello (entry)"),
    (["Via Madonna del Prato"], "Via Roma", "3–4 · Via Madonna del Prato at Via Roma (entry)"),
    (["Via Madonna del Prato"], "Via Spinello", "5 · Via Madonna del Prato, from Via Spinello (entry)"),
    (["Via Giuseppe Mazzini"], "Via dell'Agania", "6 · Via Mazzini after Via dell'Agania (entry)"),
    (["Via Borgunto", "Borg'Unto"], "Piaggia San Bartolomeo", "7 · Via Borgunto after Piaggia San Bartolomeo (entry)"),
    (["Piaggia San Martino"], "Via Pellicceria", "8 · Piaggia San Martino, from Via Pellicceria (entry)"),
    (["Viale Bruno Buozzi"], "Vicolo delle Terme", "9–10 · Viale Buozzi at Vicolo delle Terme (entry and exit)"),
    (["Via Giuseppe Garibaldi"], "Via Trento e Trieste", "11 · Via Garibaldi, from Porta Trento e Trieste (entry)"),
    (["Via Licio Nencetti"], "Via Rodi", "12 · Via Nencetti, from Via Rodi (entry)"),
    (["Via Antonio Guadagnoli"], "Via Macallè", "13 · Via Guadagnoli after Via Macallè (entry)"),
    (["Via Guido Monaco"], "Via Giuseppe Garibaldi", "14 · Via Guido Monaco near the main post office (entry)"),
    (["Via Isidoro Del Lungo"], "Via Giuseppe Garibaldi", "15–16 · Via Isidoro del Lungo at Via Garibaldi (entry and exit)"),
    (["Via San Lorentino"], "Via Giuseppe Garibaldi", "17–25 · Via San Lorentino at Via Garibaldi (exit)"),
    (["Via Fanale"], "Via Giuseppe Garibaldi", "18 · Vicolo del Fanale, from Via Garibaldi (entry)"),
    (["Via San Domenico"], "Via San Clemente", "19 · Via San Domenico, from Via San Clemente (entry)"),
    (["Via della Fioraia"], "Via Giosuè Carducci", "20 · Via della Fioraia, from Via Carducci (entry)"),
    (["Via de' Montetini"], "Piazza di Murello", "21 · Via de' Montetini, from Piazza di Murello (entry)"),
    (["Via de' Pileati"], "Piazza Madonna del Conforto", "22 · Via dei Pileati into Piazza Madonna del Conforto (exit)"),
    (["Via Borgo Santa Croce"], "Viale Giacomo Matteotti", "23 · Borgo Santa Croce at the traffic lights (exit)"),
    (["Via Padre Caprara"], "Via San Clemente", "24 · Via Padre Caprara into Via San Clemente (exit)"),
]
gates = []
for names, other, label in GATES:
    lon, lat = nearest(names, other)
    gates.append({"id": "ar-" + label.split(" ·")[0].replace("–", "-"), "name": label,
                  "location": {"lat": round(lat, 6), "lon": round(lon, 6)}})


def nearest_ring(g, rings):
    lat, lon = g["location"]["lat"], g["location"]["lon"]
    return min(range(len(rings)), key=lambda i: 0 if osm_geo.inside_lonlat(rings[i], lon, lat) else osm_geo.distance_m(rings[i], lat, lon))


B_GATES = {"1", "2", "3-4", "5", "6", "7", "8", "20", "21", "22"}
B_NORTH = {"1", "3-4"}   # all'incrocio con via Roma: il varco è sul lato nord (ZTL B principale)
gates_by_ring = {("A", i): [] for i in range(len(RINGS["A"]))} | {("B", i): [] for i in range(len(RINGS["B"]))}
for g in gates:
    z = "B" if g["id"][3:] in B_GATES else "A"
    gates_by_ring[(z, 0 if g["id"][3:] in B_NORTH else nearest_ring(g, RINGS[z]))].append(g)
for (z, i), lst in gates_by_ring.items():   # ogni varco vicino al bordo della sua zona
    for g in lst:
        d = osm_geo.distance_m(RINGS[z][i], g["location"]["lat"], g["location"]["lon"])
        assert d < 120, (g["name"], round(d))   # via de' Montetini: la striscia rossa che arriva al varco è troppo sottile per la mappa


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


LINKS = [
    link("City of Arezzo: temporary access to the ZTL (hours, prices, hotel guests)", "Comune di Arezzo: accesso temporaneo nella ZTL (orari, contributi, ospiti degli hotel)",
         "Stadt Arezzo: befristete Zufahrt in die ZTL (Zeiten, Preise, Hotelgäste)", TEMP_PAGE),
    link("City of Arezzo: ZTL rules (Disciplinare, Council decision 124/2023, text being updated)", "Comune di Arezzo: disciplinare ZTL (delibera GC 124/2023, testo in aggiornamento)",
         "Stadt Arezzo: ZTL-Regeln (Beschluss 124/2023, Text wird überarbeitet)", RULES_PDF),
    link("City of Arezzo: official ZTL map with gates (PDF, 25/09/2025)", "Comune di Arezzo: planimetria ufficiale della ZTL con i varchi (PDF, 25/09/2025)",
         "Stadt Arezzo: offizielle ZTL-Karte mit Kameras (PDF, 25.09.2025)", MAP_PDF),
    link("City of Arezzo: ZTL permit portal (SPID/CIE)", "Comune di Arezzo: portale permessi ZTL (SPID/CIE)",
         "Stadt Arezzo: Portal für ZTL-Genehmigungen (SPID/CIE)", PORTAL),
    link("City of Arezzo: unauthorised entry into the ZTL (fines, Polizia Locale)", "Comune di Arezzo: accesso irregolare in ZTL (verbali, Polizia Locale)",
         "Stadt Arezzo: unerlaubte Einfahrt in die ZTL (Bußgelder, Polizia Locale)", IRREG_PAGE),
    link("City of Arezzo: ZTL camera system (24 gates since 1/1/2025)", "Comune di Arezzo: videocontrollo ZTL (24 varchi dal 1/1/2025)",
         "Stadt Arezzo: ZTL-Kameras (24 Kameras seit 1.1.2025)", CAMERAS_PAGE),
    link("City of Arezzo: summer pedestrian area, Fri and Sat 7 pm–midnight (ordinance 245/2026)", "Comune di Arezzo: area pedonale estiva, venerdì e sabato 19–24 (ordinanza 245/2026)",
         "Stadt Arezzo: Sommer-Fußgängerzone, Fr und Sa 19–24 Uhr (Anordnung 245/2026)", SUMMER_PAGE),
    link("City of Arezzo: traffic rules for the Fiera Antiquaria, September 2026 (ordinance 1026/2026)", "Comune di Arezzo: viabilità per la Fiera Antiquaria di settembre 2026 (ordinanza 1026/2026)",
         "Stadt Arezzo: Verkehrsregeln zur Fiera Antiquaria, September 2026 (Anordnung 1026/2026)", FIERA_PDF),
    link("City of Arezzo: traffic rules for the Giostra del Saracino, 6 September 2026 (ordinance 1047/2026)", "Comune di Arezzo: viabilità per la Giostra del Saracino del 6 settembre 2026 (ordinanza 1047/2026)",
         "Stadt Arezzo: Verkehrsregeln zur Giostra del Saracino am 6. September 2026 (Anordnung 1047/2026)", GIOSTRA_PDF),
    link("OpenStreetMap: streets and squares used to place the map and the gates (ODbL)", "OpenStreetMap: strade e piazze usate per agganciare la mappa e i varchi (ODbL)",
         "OpenStreetMap: Straßen und Plätze zum Verorten der Karte und der Kameras (ODbL)", "https://www.openstreetmap.org/#map=16/43.4640/11.8810"),
]

PENDING_COMMON = [
    ("The city's rules text (Disciplinare 2023) is published as \"being updated\": hours or permits may change in 2026–2027.",
     "Il disciplinare 2023 è pubblicato con la scritta «in fase di aggiornamento»: orari o permessi potrebbero cambiare nel 2026–2027.",
     "Die Regeln von 2023 sind als »in Überarbeitung« veröffentlicht: Zeiten oder Genehmigungen können sich 2026–2027 ändern."),
    ("Outlines taken from the city's official map (25/09/2025), which has no coordinates: it was placed on OpenStreetMap automatically (average gap between the map's streets and OSM about 5 m), so edges are approximate. Gates are placed at the junction named in the rules (art. 9); the city now counts 24 gates, the rules list 25.",
     "Perimetri presi dalla mappa ufficiale del Comune (25/09/2025), che non ha coordinate: è stata agganciata a OpenStreetMap in automatico (scarto medio tra le strade della mappa e quelle di OSM circa 5 m), quindi i bordi sono approssimati. I varchi sono messi all'incrocio indicato dal disciplinare (art. 9); il Comune oggi conta 24 varchi, il disciplinare ne elenca 25.",
     "Grenzen aus der offiziellen Karte der Stadt (25.09.2025) ohne Koordinaten: Sie wurde automatisch auf OpenStreetMap gelegt (mittlere Abweichung der Straßen etwa 5 m), die Ränder sind daher ungefähr. Die Kameras liegen an der in den Regeln (Art. 9) genannten Kreuzung; die Stadt zählt heute 24 Kameras, die Regeln nennen 25."),
    ("Hotel guests: the rules say you or the hotel must enter the plate on the city's ZTL portal, but give no deadline (before or after entering). Ask your hotel; information: permessiztl@comune.arezzo.it.",
     "Ospiti degli hotel: il disciplinare dice che il cliente o l'albergatore devono inserire la targa nel portale ZTL, ma non indica un termine (prima o dopo l'ingresso). Chiedi all'hotel; informazioni: permessiztl@comune.arezzo.it.",
     "Hotelgäste: Laut den Regeln müssen du oder das Hotel das Kennzeichen im ZTL-Portal der Stadt eintragen, eine Frist (vor oder nach der Einfahrt) wird nicht genannt. Frag dein Hotel; Auskunft: permessiztl@comune.arezzo.it."),
    ("Daily pass price: the city's page says €15 a day (€10 for electric cars), the 2023 rules text says €10. Up to 20 a year per vehicle, only for real needs such as loading.",
     "Prezzo dell'accesso giornaliero: la pagina del Comune dice 15 € al giorno (10 € per le auto elettriche), il disciplinare 2023 dice 10 €. Al massimo 20 l'anno per veicolo, solo per necessità effettive come il carico e scarico.",
     "Preis des Tagespasses: Die Seite der Stadt nennt 15 € pro Tag (10 € für Elektroautos), die Regeln von 2023 nennen 10 €. Höchstens 20 pro Jahr und Fahrzeug, nur bei echtem Bedarf wie Be- und Entladen."),
    ("Events: on Fiera Antiquaria weekends (first Sunday of the month and the Saturday before) and on Giostra del Saracino days (June and the first Sunday of September) extra bans and closures apply, set each time by ordinance.",
     "Eventi: nei fine settimana della Fiera Antiquaria (prima domenica del mese e sabato precedente) e nei giorni della Giostra del Saracino (giugno e prima domenica di settembre) valgono divieti e chiusure in più, fissati ogni volta con un'ordinanza.",
     "Veranstaltungen: An Wochenenden der Fiera Antiquaria (erster Sonntag im Monat und Samstag davor) und an Tagen der Giostra del Saracino (Juni und erster Sonntag im September) gelten zusätzliche Verbote und Sperrungen, jeweils per Anordnung."),
    ("Summer: from 15 May to 12 September 2026, Fridays and Saturdays 7 pm–midnight, a larger pedestrian area (ordinance 245/2026) closes several streets of ZTL A and B and Via Roma even to permit holders. Not drawn on the map; the 2027 dates are not out yet.",
     "Estate: dal 15 maggio al 12 settembre 2026, venerdì e sabato dalle 19 alle 24, un'area pedonale più ampia (ordinanza 245/2026) chiude varie strade della ZTL A e B e via Roma anche a chi ha il permesso. Non è disegnata sulla mappa; le date del 2027 non sono ancora uscite.",
     "Sommer: Vom 15. Mai bis 12. September 2026, freitags und samstags 19–24 Uhr, sperrt eine größere Fußgängerzone (Anordnung 245/2026) mehrere Straßen der ZTL A und B sowie die Via Roma auch für Genehmigungsinhaber. Nicht auf der Karte eingezeichnet; die Termine für 2027 stehen noch nicht fest."),
]
PENDING_A = [
    ("\"Giorni feriali\" (working days) is read as Monday to Saturday, as usual in Italy; whether Saturday counts is to be confirmed with the city. 7 August (San Donato, patron saint) is counted as a holiday: to be confirmed.",
     "«Giorni feriali» è letto come dal lunedì al sabato, come d'uso; se il sabato conti è da confermare con il Comune. Il 7 agosto (San Donato, patrono) è contato come festivo: da confermare.",
     "»Giorni feriali« (Werktage) wird wie in Italien üblich als Montag bis Samstag gelesen; ob der Samstag zählt, ist mit der Stadt zu klären. Der 7. August (San Donato, Stadtpatron) gilt als Feiertag: zu bestätigen."),
    ("Exit cameras also check the way out during the banned hours; the press (ArezzoNotizie) reports a 20-minute tolerance for cars that entered just before 8:30 am: confirmed only by ArezzoNotizie.",
     "Le telecamere in uscita controllano anche chi esce negli orari vietati; la stampa (ArezzoNotizie) riporta una tolleranza di 20 minuti per chi è entrato poco prima delle 8:30: confermato solo da ArezzoNotizie.",
     "Ausfahrtskameras prüfen auch das Hinausfahren in den Sperrzeiten; die Presse (ArezzoNotizie) berichtet von 20 Minuten Toleranz für Autos, die kurz vor 8:30 Uhr hineingefahren sind: nur von ArezzoNotizie bestätigt."),
    ("Electric cars may enter ZTL A at any time only once their plate is on the city's list (portal, €5 for 3 years): GateLR treats them like any other car. Motorbikes and mopeds may enter ZTL A freely.",
     "Le auto elettriche entrano nella ZTL A a ogni ora solo dopo l'inserimento della targa nella lista del Comune (portale, 5 € per 3 anni): GateLR le tratta come le altre auto. Moto e ciclomotori entrano liberamente nella ZTL A.",
     "Elektroautos dürfen jederzeit in die ZTL A, aber erst nach Eintrag des Kennzeichens in die Liste der Stadt (Portal, 5 € für 3 Jahre): GateLR behandelt sie wie andere Autos. Motorräder und Mofas dürfen frei in die ZTL A."),
]
PENDING_B = [
    ("Inside ZTL B, Piazza Grande, Via Vasari, Via Beccheria and other squares are pedestrian at all times; Via Seteria is pedestrian 11 am–1 am (map legend).",
     "Dentro la ZTL B, piazza Grande, via Vasari, via Beccheria e altre piazze sono pedonali sempre; via Seteria è pedonale dalle 11 all'1 (legenda della mappa).",
     "In der ZTL B sind die Piazza Grande, Via Vasari, Via Beccheria und weitere Plätze immer Fußgängerzone; die Via Seteria von 11 bis 1 Uhr (Kartenlegende)."),
    ("Electric cars registered with the city may drive in ZTL B only 8–11 am, 1–4 pm and 8 pm–midnight: GateLR treats them like any other car.",
     "Le auto elettriche registrate presso il Comune possono circolare nella ZTL B solo 8–11, 13–16 e 20–24: GateLR le tratta come le altre auto.",
     "Bei der Stadt registrierte Elektroautos dürfen in der ZTL B nur 8–11, 13–16 und 20–24 Uhr fahren: GateLR behandelt sie wie andere Autos."),
]


def source(quote, translation, pending):
    return {"authority": "City of Arezzo", "pageURL": TEMP_PAGE, "ordinance": ORDINANCE, "ordinanceURL": RULES_PDF,
            "quote": quote, "quoteTranslation": translation[0], "quoteTranslation_de": translation[1],
            "checkedOn": CHECKED, "reviewedByHuman": False,
            "pending": [p[0] for p in pending], "pending_it": [p[1] for p in pending], "pending_de": [p[2] for p in pending],
            "links": LINKS}


TR_A = ("In ZTL A, driving and parking are forbidden to motor vehicles (without a valid authorisation) from 8:30 to 12:00 and from 17:00 to 20:00 on working days.",
        "In der ZTL A sind Fahren und Parken für Kraftfahrzeuge (ohne gültige Genehmigung) an Werktagen von 8:30 bis 12:00 und von 17:00 bis 20:00 Uhr verboten.")
TR_B = ("In ZTL B, driving and parking are forbidden to motor vehicles (without a valid authorisation) every day from 8:00 to 24:00.",
        "In der ZTL B sind Fahren und Parken für Kraftfahrzeuge (ohne gültige Genehmigung) täglich von 8:00 bis 24:00 Uhr verboten.")

SUMMARY_A = ("Monday to Saturday (not on public holidays), 8:30 am–12 noon and 5–8 pm: no entry without a permit, and cameras also check the way out, so leave outside those hours too. Open at all other times and all day on Sundays and holidays. "
             "Motorbikes and mopeds may enter. Hotel guests with a booking may drive to the hotel only to unload luggage: you or the hotel must enter the plate on the city's ZTL portal. "
             "There is no tourist ticket: the paid day pass is for real needs such as loading (8:30 am–12 noon). The core around Corso Italia and Piazza Grande is ZTL B, closed 8 am–midnight every day.")
SUMMARY_A_IT = ("Dal lunedì al sabato (festivi esclusi), 8:30–12 e 17–20: vietato entrare senza permesso, e le telecamere controllano anche l'uscita, quindi esci fuori da quegli orari. Aperta negli altri orari e tutto il giorno la domenica e nei festivi. "
                "Moto e ciclomotori entrano. Gli ospiti degli hotel con prenotazione possono arrivare all'hotel solo per scaricare i bagagli: tu o l'hotel dovete inserire la targa nel portale ZTL del Comune. "
                "Non c'è un ticket per i turisti: l'accesso giornaliero a pagamento è per necessità effettive come il carico e scarico (8:30–12). Il cuore attorno a corso Italia e piazza Grande è ZTL B, chiusa 8–24 tutti i giorni.")
SUMMARY_A_DE = ("Montag bis Samstag (nicht an Feiertagen) 8:30–12 und 17–20 Uhr: keine Einfahrt ohne Genehmigung, und Kameras prüfen auch die Ausfahrt, also auch außerhalb dieser Zeiten hinausfahren. Sonst offen, sonntags und feiertags ganztägig. "
                "Motorräder und Mofas dürfen hinein. Hotelgäste mit Buchung dürfen nur zum Ausladen des Gepäcks zum Hotel fahren: du oder das Hotel müsst das Kennzeichen im ZTL-Portal der Stadt eintragen. "
                "Ein Touristenticket gibt es nicht: Der kostenpflichtige Tagespass ist für echten Bedarf wie Be- und Entladen (8:30–12 Uhr). Der Kern um Corso Italia und Piazza Grande ist ZTL B, täglich 8–24 Uhr gesperrt.")
SUMMARY_B = ("Closed to unauthorised vehicles every day, holidays included, from 8 am to midnight; open from midnight to 8 am. Motorbikes need a permit too. "
             "Hotel guests with a booking may drive to the hotel only to unload luggage: you or the hotel must enter the plate on the city's ZTL portal. "
             "There is no tourist ticket: the paid day pass (only for real needs such as loading) allows 8–11 am and 2–4 pm, stopping 20 minutes at most. Piazza Grande and the other pedestrian squares are closed to cars at all times.")
SUMMARY_B_IT = ("Chiusa ai veicoli non autorizzati tutti i giorni, festivi compresi, dalle 8 alle 24; aperta da mezzanotte alle 8. Anche le moto devono avere il permesso. "
                "Gli ospiti degli hotel con prenotazione possono arrivare all'hotel solo per scaricare i bagagli: tu o l'hotel dovete inserire la targa nel portale ZTL del Comune. "
                "Non c'è un ticket per i turisti: l'accesso giornaliero a pagamento (solo per necessità effettive come il carico e scarico) vale 8–11 e 14–16, con sosta di 20 minuti al massimo. Piazza Grande e le altre piazze pedonali sono sempre chiuse alle auto.")
SUMMARY_B_DE = ("Täglich, auch an Feiertagen, von 8 bis 24 Uhr für nicht berechtigte Fahrzeuge gesperrt; von Mitternacht bis 8 Uhr offen. Auch Motorräder brauchen eine Genehmigung. "
                "Hotelgäste mit Buchung dürfen nur zum Ausladen des Gepäcks zum Hotel fahren: du oder das Hotel müsst das Kennzeichen im ZTL-Portal der Stadt eintragen. "
                "Ein Touristenticket gibt es nicht: Der kostenpflichtige Tagespass (nur bei echtem Bedarf wie Be- und Entladen) gilt 8–11 und 14–16 Uhr, Halten höchstens 20 Minuten. Die Piazza Grande und die anderen Fußgängerplätze sind immer für Autos gesperrt.")

WINDOWS_A = [{"weekdays": MON_SAT, "start": 8 * 60 + 30, "end": 12 * 60}, {"weekdays": MON_SAT, "start": 17 * 60, "end": 20 * 60}]
WINDOWS_B = [{"weekdays": EVERY_DAY, "start": 8 * 60, "end": 24 * 60}]
NAMES_A = [("Centro · Historic Centre ZTL A", "Centro · ZTL A Centro storico", "Centro · ZTL A Altstadt"),
           ("Via Marconi · ZTL A", "Via Marconi · ZTL A", "Via Marconi · ZTL A")]
NAMES_B = [("Corso Italia · ZTL B and Piazza Grande", "Corso Italia · ZTL B e piazza Grande", "Corso Italia · ZTL B und Piazza Grande"),
           ("Lower Corso Italia · ZTL B south of Via Roma", "Basso Corso Italia · ZTL B a sud di via Roma", "Unterer Corso Italia · ZTL B südlich der Via Roma")]
assert len(RINGS["A"]) == len(NAMES_A) and len(RINGS["B"]) == len(NAMES_B), (len(RINGS["A"]), len(RINGS["B"]))

zones = []
for i, ring in enumerate(RINGS["B"]):
    zones.append({"id": f"arezzo-ztl-b{'' if i == 0 else '-sud'}", "name": NAMES_B[i][0], "name_it": NAMES_B[i][1], "name_de": NAMES_B[i][2],
                  "kind": "restricted", "summary": SUMMARY_B, "summary_it": SUMMARY_B_IT, "summary_de": SUMMARY_B_DE,
                  "perimeter": osm_geo.perimeter(ring, tol_m=2), "gates": gates_by_ring[("B", i)],
                  "windows": WINDOWS_B, "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": True,
                  "source": source(QUOTE_B, TR_B, PENDING_B + PENDING_COMMON)})
for i, ring in enumerate(RINGS["A"]):
    zones.append({"id": f"arezzo-ztl-a{'' if i == 0 else '-marconi'}", "name": NAMES_A[i][0], "name_it": NAMES_A[i][1], "name_de": NAMES_A[i][2],
                  "kind": "restricted", "summary": SUMMARY_A, "summary_it": SUMMARY_A_IT, "summary_de": SUMMARY_A_DE,
                  "perimeter": osm_geo.perimeter(ring, tol_m=2), "gates": gates_by_ring[("A", i)],
                  "windows": WINDOWS_A, "freeOnHolidays": True, "exemptFuels": [], "hotelCanRegister": True,
                  "source": source(QUOTE_A, TR_A, PENDING_A + PENDING_COMMON)})

ped_ways = {e["id"]: e for e in ELEMENTS if e["type"] == "way"}
pedestrian = [{"id": f"ar-ap-{wid}", "name": name,
               "perimeter": osm_geo.perimeter([(n["lon"], n["lat"]) for n in ped_ways[wid]["geometry"]], tol_m=1)}
              for wid, name in PEDESTRIAN.items()]

city = {"id": "arezzo", "name": "Arezzo", "name_it": "Arezzo", "name_de": "Arezzo",
        "center": {"lat": 43.4647, "lon": 11.8842}, "zones": zones, "pedestrian": pedestrian,
        "localHolidays": ["08-07"], "status": "draft",
        "license": "Rules: Comune di Arezzo official pages and documents. Perimeters: Comune di Arezzo official ZTL map (25/09/2025), "
                   "georeferenced on OpenStreetMap streets; gates and pedestrian squares: " + osm_geo.ODBL + " (approximate, not official)."}

# --- Controlli di plausibilità ---
zb, za = zones[0]["perimeter"], next(z for z in zones if z["id"] == "arezzo-ztl-a")["perimeter"]
PIAZZA_GRANDE = (43.4637, 11.8826)                     # punto di controllo (corso Italia sotto piazza Grande)
pg = ped_ways[22720357]["geometry"]
pg_c = (sum(n["lat"] for n in pg) / len(pg), sum(n["lon"] for n in pg) / len(pg))
assert osm_geo.contains(za, *PIAZZA_GRANDE), "punto di piazza Grande fuori dalla ZTL A"
assert osm_geo.contains(zb, *pg_c), "piazza Grande (OSM) fuori dalla ZTL B"
station = next(e for e in ELEMENTS if e["type"] == "node" and e["tags"].get("railway") == "station")
for lat, lon in [(station["lat"], station["lon"]), (43.4581, 11.8735), (43.46278, 11.87829)]:   # stazione, piazzale, piazza Guido Monaco
    assert not any(osm_geo.contains(z["perimeter"], lat, lon) for z in zones), ("dentro una ZTL", lat, lon)
# Strade di libera circolazione dell'allegato 4 (e via Spinello, fuori dalle mura): nessun nodo dentro una ZTL
for name in ["Via Roma", "Via Francesco Crispi", "Via Francesco Petrarca", "Via Leone Leoni", "Via Spinello", "Piazza del Popolo"]:
    for l in lines_of([name]):
        assert not any(osm_geo.contains(z["perimeter"], p[1], p[0]) for z in zones for p in l), ("strada libera dentro una ZTL", name)
area_a, area_b = osm_geo.area_km2(za), osm_geo.area_km2(zb)
assert 0.4 < area_a < 0.9 and 0.08 < area_b < 0.25, (area_a, area_b)

out = ROOT / "Resources/Cities/arezzo.json"
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.name, [(z["id"], len(z["perimeter"]), len(z["gates"]), round(osm_geo.area_km2(z["perimeter"]), 3)) for z in zones],
      f"vie A+B nella ZTL A {share_a:.0%}, vie B nella ZTL B {share_b:.0%}",
      "stazione a", round(osm_geo.distance_m(za, station["lat"], station["lon"])), "m dal bordo della ZTL A")
