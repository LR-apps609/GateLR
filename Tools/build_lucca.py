#!/usr/bin/env python3
# Costruisce la scheda di Lucca dalle fonti ufficiali del Comune di Lucca salvate in data/raw/lucca/
# (fonti e date in docs/fonti-lucca.md). Lo script ricontrolla ogni frase usata sui file salvati.
#
# Dentro le Mura ci sono tre zone (Disciplinare permessi, febbraio 2026 = allegato 1 alla delibera GC 340/2025, § 1.4):
# - ZTL A (zona pedonale): accesso e sosta «sempre vietati» senza permesso;
# - ZTL B: accesso solo con permesso, senza fasce orarie (quindi sempre);
# - ZTL C: nessun controllo degli accessi (solo limiti di massa, ingombro e velocità, sosta blu a pagamento).
# Escono la ZTL A, la ZTL B e, a parte, il quadrilatero Quarquonia–Bacchettoni–via Elisa–Santa Chiara (ZTL B
# anche lui, ma con i varchi sospesi da gennaio 2026 per il cantiere di Villa Bottini). La C non è una zona
# dell'app (si entra con qualsiasi auto): resta nelle note.
#
# Geometria: data/raw/lucca/ztl-mappa-ufficiale.geojson, ricavato in automatico da Tools/lucca_mappa.py dalla mappa
# ufficiale «ZTL e parcheggi nel Centro Storico aggiornato al 25.11.2025» (Figura 1 del Disciplinare 2026, allegato
# della delibera GC 340/2025): colori della mappa → aree, agganciate alle coordinate sovrapponendo le Mura della mappa
# alle Mura di OpenStreetMap. Le Mura (verdi sulla mappa, dove valgono le norme della ZTL A) non sono nella zona A,
# così le porte che le attraversano non risultano «dentro la ZTL A». Ogni zona è un solo anello: contorni e buchi
# sono uniti da tagli di larghezza zero (join_rings()), che il ray casting pari/dispari dell'app attraversa due volte.
#
# Se manca il file della mappa si torna ai perimetri OSM del 2024 (data/raw/geo/lucca-ztl.json) e la scheda resta
# una bozza in data/drafts/lucca.json. Non aggiorna manifest.json. Uso: python3 Tools/build_lucca.py
import json, math, re
from pathlib import Path
import osm_geo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data/raw/lucca"
CHECKED = "2026-10-25T12:00:00Z"
EVERY_DAY = [1, 2, 3, 4, 5, 6, 7]
# ZTL B: il disciplinare non dà fasce orarie per l'accesso (solo «con permesso»), e i permessi dei residenti
# valgono «Dalle ore 0.00 alle ore 24.00»: la zona è sempre attiva (vedi docs/fonti-lucca.md)
B_HOURS_OFFICIAL = True

DISCIPLINARE = "https://www.comune.lucca.it/app/uploads/2026/03/disciplinare_2026_.pdf"
DISCIPLINARE_2024 = "https://www.comune.lucca.it/app/uploads/2025/02/Disciplinare2024.pdf"
MAP_PAGE = "https://www.comune.lucca.it/documento_pubblico/planimetria-del-centro-storico-con-varchi-telematici-ztl-e-area-pedonale/"
MAP_PDF = "https://www.comune.lucca.it/app/uploads/2026/03/ZTL-aggiornamento-dicembre-2025.pdf"
DLG_340 = "https://www.comune.lucca.it/app/uploads/2026/01/dlg_00340_12-12-2025.pdf"
NEWS_GATES = "https://www.comune.lucca.it/notizia/ztl-da-oggi-19-gennaio-sono-attivi-i-nuovi-varchi-elettronici/"
PRESENTATION = "https://www.comune.lucca.it/app/uploads/2025/03/presentazione-nuova-ZTL.pdf"
ORD_COMICS = "https://www.comune.lucca.it/app/uploads/2026/10/ord_02393_21-10-2026-Accessi-ZTL.pdf"
MAP_FILE = RAW / "ztl-mappa-ufficiale.geojson"
OSM_ZONES = {"lucca-a": 19549900, "lucca-b": 19549370}   # solo se manca la mappa (perimetri del 2024)
OSM_C = 19549417
EAST_POINT = (43.8442, 10.5125)   # un punto dentro il quadrilatero Quarquonia–Bacchettoni–via Elisa–Santa Chiara


def link(en, it, de, url):
    return {"title": en, "title_it": it, "title_de": de, "url": url}


def flat(text):
    return re.sub(r"\s+", " ", text).strip()


def page_text(name):
    import html
    t = (RAW / name).read_text(encoding="utf-8")
    t = re.sub(r"<(script|style)[^>]*>.*?</\1>", " ", t, flags=re.S)
    return flat(html.unescape(re.sub(r"<[^>]+>", " ", t)))


def must_contain(text, quote, where):
    if flat(quote) not in text:
        raise SystemExit(f"Citazione non trovata in {where}: {quote!r}")


# --- Le frasi su cui si basa la scheda, controllate contro i file in data/raw/lucca/ ---
rules = flat((RAW / "disciplinare-2026.txt").read_text(encoding="utf-8"))
dlg = flat((RAW / "dlg-340-2025.txt").read_text(encoding="utf-8"))
comics = flat((RAW / "ord-2393-2026-accessi-ztl.txt").read_text(encoding="utf-8"))
gates_news = page_text("notizia-varchi-attivi.html")
controls_news = page_text("notizia-controlli.html")
QUOTE_A = "ZTL tipo “A” l’accesso e la sosta sono sempre vietati fatti salvi i veicoli autorizzati muniti di permesso."
QUOTE_B = "ZTL tipo “B” oltre alle limitazioni di massa, di dimensione e di velocità di cui al precedente punto a), l’accesso è consentito ai veicoli muniti di permesso e la sosta è consentita negli stalli gialli"
for q in [QUOTE_A, QUOTE_B, "Lucca, Febbraio 2026", "Figura 1: Zone regolamentate del Centro Storico",
          "ZTL tipo “C” nella quale sono vigenti i limiti relativi alla massa a pieno carico",
          "L’accesso e l’uscita in/dalla ZTL è presidiato da telecamere.",
          "Per tutti i permessi, le prescrizioni d'uso previste per la domenica si estendono automaticamente ai giorni festivi.",
          "nella fascia oraria 10.30 - 14.00 e 18.00 - 21.00 nei seguenti ambiti: via Fillungo",
          "piazza Anfiteatro, piazza San Frediano",
          "Fascia oraria accesso/uscita. Dalle ore 0.00 alle ore 24.00",
          "monumentale delle Mura Urbane sono disciplinate dalle norme stabilite per la ZTL A",
          # Z4 Clienti delle strutture ricettive
          "localizzate nella ZTL B e nella ZTL A",
          "effettuate entro 3 giorni (72 ore)dall'effettivo passaggio del mezzo dal varco Ztl",
          "il numero/denominazione della camera/appartamento",
          "per un periodo massimo di 30 minuti con l’obbligo di esporre il disco orario",
          "Trascorso tale periodo il veicolo deve stazionare nelle aree al di fuori della ZTL A e B",
          "La tariffa è gratuita per tutti i tipi di veicoli e per tutta la durata del soggiorno",
          # Permessi giornalieri solo per categorie precise
          "Z12 giornaliero 15 15 15 15 15 15",
          "Ciclomotori e motocicli. L’accesso, il transito dei ciclomotori e dei motocicli è consentito nella ZTL B"]:
    must_contain(rules, q, "Disciplinare febbraio 2026")
for q in ["si modifica a “ entro 3 gg o 72 ore”", "decorrenti dal 01/01/2026",
          "passaggio da “ZTL C” a “ZTL B” del quadrilatero compreso tra Via Elisa/Via del Fosso/Via del Giardino Botanico/Via San Micheletto",
          "passaggio da “ZTL A” a “ZTL B” dell’area compresa tra Via del Crocifisso e Via San Paolino",
          "nell’allegata planimetria denominata “ZTL Lucca aggiornamento 2025 nuovo varchi” è rappresentata la configurazione delle perimetrazioni delle ZTL A, ZTL B e ZTL C"]:
    must_contain(dlg, q, "delibera GC 340/2025")
for q in ["restano temporaneamente sospesi i varchi del quadrilatero Quarquonia–Bacchettoni–via Elisa–Santa Chiara",
          "Continuano come sempre ad essere raggiungibili tutti i parcheggi a stalli blu del centro storico, per consentire la sosta anche ai cittadini non residenti",
          "Varchi in uscita (OUT) Piazza della Caserma"]:
    must_contain(gates_news, q, "notizia del 19 gennaio 2026")
must_contain(controls_news, "Complessivamente sono 14 i nuovi varchi installati", "notizia dell'8 gennaio 2026")
for q in ["PERIODO: 28 OTTOBRE 2026 - 1 NOVEMBRE 2026",
          "B) ACCESSO E CIRCOLAZIONE VIETATA all’interno del Centro Storico dalle ore 08:00 alle ore 19:00 di ciascun giorno, per • TUTTI I VEICOLI PRIVI DI PERMESSO E AUTORIZZAZIONE",
          "attraverso Porta Santa Maria e Porta Sant'Anna h24, e dalle ore 07:00 alle ore 20:30 attraverso Porta San Pietro",
          "Z4 (CLIENTI DI STRUTTURE RICETTIVE)",
          "G) ACCESSO E CIRCOLAZIONE VIETATA IN ZTL A DALLE ORE 9:00 ALLE ORE 19:00"]:
    must_contain(comics, q, "ordinanza 2393/2026 (Lucca Comics & Games)")


# --- Geometria ---

def _open(ring):
    """Anello [lon, lat] senza il punto di chiusura ripetuto"""
    ring = [tuple(p) for p in ring]
    return ring[:-1] if ring[0] == ring[-1] else ring


def _signed(ring):
    return sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(ring, ring[1:] + ring[:1])) / 2


def join_rings(polys):
    """Un anello solo per un insieme di poligoni con buchi ([[contorno, buco, ...], ...], anelli [lon, lat]).
    Contorni antiorari e buchi orari; ogni anello è unito al resto con un taglio di larghezza zero tra i due punti
    più vicini (andata e ritorno sullo stesso segmento). Il ray casting pari/dispari dell'app attraversa il taglio
    due volte, quindi non cambia nulla; anche l'area con il segno resta giusta."""
    loops = []
    for pl in polys:
        for i, r in enumerate(pl):
            r = _open(r)
            if (_signed(r) > 0) != (i == 0):
                r.reverse()
            loops.append(r)
    k = math.cos(math.radians(loops[0][0][1]))
    d2 = lambda a, b: ((a[0] - b[0]) * k) ** 2 + (a[1] - b[1]) ** 2
    loops.sort(key=lambda r: abs(_signed(r)), reverse=True)
    ring, rest = loops[0], loops[1:]
    while rest:
        best = None
        for n, lp in enumerate(rest):
            for j, q in enumerate(lp):
                for i, p in enumerate(ring):
                    d = d2(p, q)
                    if best is None or d < best[0]:
                        best = (d, n, i, j)
        _, n, i, j = best
        lp = rest.pop(n)
        ring = ring[:i + 1] + lp[j:] + lp[:j + 1] + ring[i:]
    ring.append(ring[0])
    return [{"lat": round(p[1], 6), "lon": round(p[0], 6)} for p in ring]


def keyhole(outer, inner, tol_m=5.0):
    """Solo per i perimetri OSM del 2024: «outer meno inner», semplificati a tol_m"""
    return join_rings([[osm_geo.simplify_m(outer, tol_m), osm_geo.simplify_m(inner, tol_m)]])


def map_perimeters():
    """Dalla mappa ufficiale: ZTL A, ZTL B senza il quadrilatero est, il quadrilatero est"""
    if not MAP_FILE.exists():
        return {}, None
    g = json.loads(MAP_FILE.read_text(encoding="utf-8"))
    feats = {f["properties"]["gatelr_id"]: f for f in g["features"]}
    a = feats["lucca-a"]["geometry"]["coordinates"]
    b = feats["lucca-b"]["geometry"]["coordinates"]
    east = [pl for pl in b if osm_geo.contains(pl[0], *EAST_POINT)]
    if len(east) != 1 or not 0.04 < osm_geo.area_km2(east[0][0]) < 0.09:
        raise SystemExit("Il quadrilatero Quarquonia–Bacchettoni–via Elisa–Santa Chiara non è un poligono a sé nella ZTL B")
    iou = min(f["properties"]["registration_iou"] for f in g["features"])
    return ({"lucca-a": join_rings(a), "lucca-b": join_rings([pl for pl in b if pl is not east[0]]),
             "lucca-b-est": join_rings(east)}, iou)


def osm_perimeters():
    el = osm_geo.load("lucca-ztl")
    a = osm_geo.relation(el, OSM_ZONES["lucca-a"])
    return {"lucca-a": keyhole(osm_geo.outer_ring(a), osm_geo.outer_ring(a, roles=("inner",))),
            "lucca-b": osm_geo.perimeter(osm_geo.outer_ring(osm_geo.relation(el, OSM_ZONES["lucca-b"])))}


perims, map_iou = map_perimeters()
from_map = bool(perims)
if not from_map:
    perims = osm_perimeters()
PERIMETER_CURRENT = from_map and map_iou >= 0.97   # la mappa del 25/11/2025 è quella in vigore (Disciplinare 2026)

# Controlli di plausibilità (punti presi a mano, solo per controllo)
ANFITEATRO, NAPOLEONE, SAN_MICHELE = (43.8457, 10.5065), (43.8410, 10.5020), (43.8430, 10.5048)
STAZIONE, PORTA_ELISA, PIAZZALE_VERDI = (43.8375, 10.5062), (43.8414, 10.5165), (43.8405, 10.4945)
inside = lambda zid, pt: osm_geo.contains(perims[zid], *pt)
assert inside("lucca-a", ANFITEATRO) and not inside("lucca-b", ANFITEATRO), "Piazza dell'Anfiteatro deve stare nella ZTL A"
assert not any(inside(z, STAZIONE) for z in perims), "La stazione deve stare fuori"
if from_map:
    assert inside("lucca-a", NAPOLEONE), "Piazza Napoleone è verde (ZTL A) sulla mappa ufficiale"
    assert inside("lucca-a", SAN_MICHELE), "Piazza San Michele è nella ZTL A"
    assert inside("lucca-b-est", EAST_POINT) and not inside("lucca-b", EAST_POINT)
    assert not any(inside(z, PORTA_ELISA) for z in perims), "Porta Elisa (Mura) non è in nessuna zona"
    assert not any(inside(z, PIAZZALE_VERDI) for z in perims), "Piazzale Verdi è ZTL C (libera)"
    # le zone non si sovrappongono, e stanno dentro le Mura (contorno esterno della ZTL A in OSM)
    walls = osm_geo.outer_ring(osm_geo.relation(osm_geo.load("lucca-ztl"), OSM_ZONES["lucca-a"]))
    lat0, lat1, lon0, lon1 = 43.836, 43.849, 10.490, 10.518
    grid = [(lat0 + (lat1 - lat0) * i / 120, lon0 + (lon1 - lon0) * j / 120) for i in range(121) for j in range(121)]
    hits = {z: [p for p in grid if inside(z, p)] for z in perims}
    both = [p for p in hits["lucca-a"] if inside("lucca-b", p) or inside("lucca-b-est", p)] + \
           [p for p in hits["lucca-b"] if inside("lucca-b-est", p)]
    # i bordi di A e B sono semplificati ognuno per conto suo: possono accavallarsi di un paio di metri
    both = [p for p in both if min(osm_geo.distance_m(perims[z], *p) for z in perims) > 3]
    assert not both, f"Zone sovrapposte in {len(both)} punti"
    out = [p for z in perims for p in hits[z] if not osm_geo.contains(walls, *p)]
    assert not out, f"{len(out)} punti delle zone fuori dalle Mura"
    for z, lo, hi in [("lucca-a", 0.33, 0.45), ("lucca-b", 0.42, 0.56), ("lucca-b-est", 0.04, 0.09)]:
        assert lo < osm_geo.area_km2(perims[z]) < hi, f"{z}: area {osm_geo.area_km2(perims[z]):.3f} km² fuori dall'atteso"

# --- Note «da verificare» (inglese, italiano, tedesco) ---
P_GEOMETRY = ("Map outline derived automatically from the colours of the official city map (25 November 2025, the one in the February 2026 rules), aligned on the city walls: accurate to a few metres, not an official coordinate file. "
              "The walls themselves follow sector A rules but are not drawn, so driving through the gates in the walls does not show as sector A.",
              "Perimetro ricavato in automatico dai colori della mappa ufficiale del Comune (25 novembre 2025, la stessa del disciplinare di febbraio 2026), agganciata alle Mura: preciso a pochi metri, non è un file di coordinate ufficiale. "
              "Le Mura seguono le regole della ZTL A ma non sono disegnate, così passare dalle porte delle Mura non risulta ZTL A.",
              "Grenze automatisch aus den Farben der offiziellen Stadtkarte abgeleitet (25. November 2025, dieselbe wie in den Regeln vom Februar 2026) und an der Stadtmauer ausgerichtet: auf wenige Meter genau, keine amtliche Koordinatendatei. "
              "Die Mauer selbst folgt den Regeln von Sektor A, ist aber nicht eingezeichnet; die Durchfahrt durch die Stadttore zählt daher nicht als Sektor A.")
P_GEOMETRY_OSM = ("Map outline from OpenStreetMap, drawn on the 2024 rules and not official: the January 2026 changes (areas moved from sector C and A into sector B) are missing. Check the official map.",
                  "Perimetro da OpenStreetMap, tracciato sulle regole del 2024 e non ufficiale: mancano le modifiche di gennaio 2026 (aree passate dalla ZTL C e A alla ZTL B). Guarda la mappa ufficiale.",
                  "Grenze aus OpenStreetMap, nach den Regeln von 2024 gezeichnet und nicht amtlich: Die Änderungen vom Januar 2026 (Bereiche von Sektor C und A zu B) fehlen. Siehe offizielle Karte.")
P_EAST = ("On 19 January 2026 the city said the cameras of this block stay temporarily switched off because the ZTL here is suspended while traffic is diverted for the Villa Bottini wall works; it will switch them on when the works end. "
          "Press reports (October 2026) say the works are still going on. GateLR still treats the block as sector B, to be safe.",
          "Il 19 gennaio 2026 il Comune ha comunicato che i varchi di questo quadrilatero restano temporaneamente sospesi, perché qui la ZTL è sospesa per la deviazione del traffico dovuta al cantiere del muro di Villa Bottini; li accenderà a lavori finiti. "
          "Secondo la stampa (ottobre 2026) i lavori sono ancora in corso. GateLR la considera comunque ZTL B, per prudenza.",
          "Am 19. Januar 2026 teilte die Stadt mit, dass die Kameras dieses Blocks vorübergehend abgeschaltet bleiben, weil die ZTL hier wegen der Umleitung für die Arbeiten an der Mauer der Villa Bottini ausgesetzt ist; sie werden nach den Arbeiten eingeschaltet. "
          "Laut Presse (Oktober 2026) laufen die Arbeiten noch. GateLR behandelt den Block vorsichtshalber trotzdem als Sektor B.")
P_EAST_UNOFFICIAL = ("Works still in progress in October 2026: confirmed only by La Nazione (October 2026), which reports a target of June 2027 for the end of all works.",
                     "Lavori ancora in corso a ottobre 2026: confermato solo da La Nazione (ottobre 2026), che indica giugno 2027 come obiettivo per la fine di tutti i lavori.",
                     "Arbeiten im Oktober 2026 noch im Gang: nur von La Nazione (Oktober 2026) bestätigt, die Juni 2027 als Ziel für das Ende aller Arbeiten nennt.")
P_COMICS = ("Lucca Comics & Games, 28 October – 1 November 2026: no entry inside the walls (sector C included) 8 am–7 pm for vehicles without a permit; Porta Santa Maria and Porta Sant'Anna closed to them all day, Porta San Pietro 7 am–8:30 pm. "
            "Hotel guests may drive in only before 10 am or after 7 pm, with the hotel's authorisation. Sector A is closed to all vehicles 9 am–7 pm.",
            "Lucca Comics & Games, 28 ottobre – 1 novembre 2026: vietato entrare dentro le Mura (ZTL C compresa) dalle 8 alle 19 senza permesso; Porta Santa Maria e Porta Sant'Anna chiuse tutto il giorno ai veicoli senza permesso, Porta San Pietro dalle 7 alle 20:30. "
            "I clienti degli hotel possono entrare solo prima delle 10 o dopo le 19, con l'autorizzazione della struttura. La ZTL A è chiusa a tutti i veicoli dalle 9 alle 19.",
            "Lucca Comics & Games, 28. Oktober – 1. November 2026: Einfahrt innerhalb der Mauern (auch Sektor C) 8–19 Uhr ohne Genehmigung verboten; Porta Santa Maria und Porta Sant'Anna ganztägig für diese Fahrzeuge gesperrt, Porta San Pietro 7–20:30 Uhr. "
            "Hotelgäste dürfen nur vor 10 oder nach 19 Uhr mit Genehmigung der Unterkunft hineinfahren. Sektor A ist 9–19 Uhr für alle Fahrzeuge gesperrt.")
P_C = ("Sector C (Piazzale Verdi, Piazza Santa Maria, Corso Garibaldi by Porta San Pietro, the streets to the car parks of Piazza San Ponziano and via dei Bacchettoni, and a few others) has no entry control: any car under 3.5 t may drive in (30 km/h), with paid blue-line parking. It is not drawn as a zone.",
       "La ZTL C (piazzale Verdi, piazza Santa Maria, corso Garibaldi verso Porta San Pietro, le strade per i parcheggi di piazza San Ponziano e via dei Bacchettoni e poche altre aree) non ha controllo degli accessi: può entrare qualsiasi auto sotto le 3,5 tonnellate (30 km/h), con sosta a pagamento sulle strisce blu. Non è disegnata come zona.",
       "Sektor C (Piazzale Verdi, Piazza Santa Maria, Corso Garibaldi bei der Porta San Pietro, die Straßen zu den Parkplätzen Piazza San Ponziano und Via dei Bacchettoni und einige weitere) hat keine Zufahrtskontrolle: Jedes Auto unter 3,5 t darf hinein (30 km/h), Parken auf blauen Linien gegen Gebühr. Er ist nicht als Zone eingezeichnet.")
P_NO_TICKET = ("No day permit for visitors: daily permits exist only for specific categories such as trades, deliveries or people with a temporary disability (€15 a day), and are issued by Lucca Plus.",
               "Nessun permesso giornaliero per i turisti: i permessi giornalieri esistono solo per categorie precise come artigiani, merci o persone con disabilità temporanea (15 € al giorno), e li rilascia Lucca Plus.",
               "Keine Tagesgenehmigung für Besucher: Tagesgenehmigungen gibt es nur für bestimmte Gruppen wie Handwerker, Lieferungen oder Menschen mit vorübergehender Behinderung (15 € pro Tag), ausgestellt von Lucca Plus.")
P_ELECTRIC = ("Electric cars: no free entry; the rules only list lower permit prices for them.",
              "Auto elettriche: nessun accesso libero; il disciplinare prevede per loro solo tariffe più basse dei permessi.",
              "Elektroautos: keine freie Einfahrt; die Regeln sehen für sie nur günstigere Genehmigungen vor.")
P_GATES = ("Cameras: the city lists the gate names (14 new ones active since 19 January 2026, which also read plates on the way out) but publishes no coordinates, so they are not on the map.",
           "Varchi: il Comune elenca i nomi (14 nuovi, attivi dal 19 gennaio 2026, che leggono le targhe anche in uscita) ma non pubblica le coordinate, quindi non sono sulla mappa.",
           "Kameras: Die Stadt nennt die Namen (14 neue, aktiv seit 19. Januar 2026, die Kennzeichen auch bei der Ausfahrt lesen), veröffentlicht aber keine Koordinaten; daher fehlen sie auf der Karte.")
P_B_HOURS = ("Hours: the rules say entry to sector B is allowed only with a permit and give no time limit, so GateLR treats it as always active. To be confirmed with the city.",
             "Orari: il disciplinare dice che nella ZTL B si entra solo con il permesso e non indica fasce orarie, quindi GateLR la considera sempre attiva. Da confermare con il Comune.",
             "Zeiten: Laut den Regeln darf man in Sektor B nur mit Genehmigung und ohne Zeitangabe einfahren; GateLR behandelt ihn daher als immer aktiv. Mit der Stadt zu bestätigen.")
P_A_STREETS = ("Even with a permit (hotel guests included), via Fillungo, via Roma, piazza San Michele (east side), piazza Anfiteatro, piazza San Frediano and a few other streets are closed 10:30 am–2 pm and 6–9 pm.",
               "Anche con il permesso (ospiti degli hotel compresi), via Fillungo, via Roma, piazza San Michele (lato est), piazza Anfiteatro, piazza San Frediano e poche altre vie sono chiuse 10:30–14 e 18–21.",
               "Auch mit Genehmigung (Hotelgäste eingeschlossen) sind Via Fillungo, Via Roma, Piazza San Michele (Ostseite), Piazza Anfiteatro, Piazza San Frediano und einige weitere Straßen 10:30–14 und 18–21 Uhr gesperrt.")

links = [link("City of Lucca: map of the ZTL sectors and gates (page)", "Comune di Lucca: planimetria con ZTL, varchi e area pedonale",
              "Stadt Lucca: Karte der ZTL-Sektoren und Kameras", MAP_PAGE),
         link("City of Lucca: ZTL map, 25 November 2025 (PDF)", "Comune di Lucca: mappa ZTL aggiornata al 25.11.2025 (PDF)",
              "Stadt Lucca: ZTL-Karte, Stand 25. November 2025 (PDF)", MAP_PDF),
         link("City of Lucca: permit rules for the historic centre (Feb 2026, PDF)", "Comune di Lucca: disciplinare dei permessi del centro storico (feb. 2026, PDF)",
              "Stadt Lucca: Genehmigungsregeln für die Altstadt (Feb. 2026, PDF)", DISCIPLINARE),
         link("City of Lucca: Council decision 340/2025 (rule changes, new perimeter)", "Comune di Lucca: delibera GC 340/2025 (modifiche al disciplinare, nuovo perimetro)",
              "Stadt Lucca: Beschluss 340/2025 (Regeländerungen, neue Grenze)", DLG_340),
         link("City of Lucca: new ZTL cameras active from 19 January 2026", "Comune di Lucca: nuovi varchi ZTL attivi dal 19 gennaio 2026",
              "Stadt Lucca: neue ZTL-Kameras ab 19. Januar 2026", NEWS_GATES),
         link("City of Lucca: Lucca Comics & Games 2026 access rules (order 2393/2026, PDF)", "Comune di Lucca: accessi durante Lucca Comics & Games 2026 (ord. 2393/2026, PDF)",
              "Stadt Lucca: Zufahrtsregeln Lucca Comics & Games 2026 (Anordnung 2393/2026, PDF)", ORD_COMICS)]


def osm_link(rid):
    return link(f"OpenStreetMap: relation {rid} (perimeter, ODbL)", f"OpenStreetMap: relazione {rid} (perimetro, ODbL)",
                f"OpenStreetMap: Relation {rid} (Grenze, ODbL)", osm_geo.osm_url("relation", rid))


def source(zid, quote, translation, pending):
    pending = ([P_GEOMETRY] if from_map else [P_GEOMETRY_OSM]) + [P_COMICS] + pending
    return {"authority": "City of Lucca", "pageURL": MAP_PAGE,
            "ordinance": "Disciplinare per il rilascio dei permessi del centro storico (febbraio 2026), allegato 1 alla delibera GC n. 340 del 12/12/2025",
            "ordinanceURL": DISCIPLINARE,
            "quote": quote, "quoteTranslation": translation[0], "quoteTranslation_de": translation[1],
            "checkedOn": CHECKED, "reviewedByHuman": False,
            "pending": [p[0] for p in pending], "pending_it": [p[1] for p in pending], "pending_de": [p[2] for p in pending],
            "links": links + ([] if from_map else [osm_link(OSM_ZONES.get(zid, OSM_ZONES["lucca-b"]))])}


HOTEL_EN = " If your hotel or B&B is inside sector A or B, it can register your plate for free (within 72 hours of your passing the camera): during your stay you may drive in by the shortest route and stop for check-in and luggage for up to 30 minutes with a parking disc; then park outside sectors A and B or in the hotel's own parking."
HOTEL_IT = " Se il tuo hotel o B&B è nella ZTL A o B, può registrare la tua targa gratis (entro 72 ore dal passaggio sotto il varco): per tutto il soggiorno puoi entrare per la via più breve e fermarti per registrazione e bagagli al massimo 30 minuti con il disco orario; poi devi parcheggiare fuori dalle ZTL A e B o nel parcheggio della struttura."
HOTEL_DE = " Liegt dein Hotel oder B&B in Sektor A oder B, kann es dein Kennzeichen kostenlos melden (bis 72 Stunden nach der Kamera): Während des Aufenthalts darfst du auf dem kürzesten Weg hineinfahren und zum Einchecken und für das Gepäck höchstens 30 Minuten mit Parkscheibe halten; danach außerhalb von A und B oder auf dem Parkplatz der Unterkunft parken."
NO_TICKET_EN, NO_TICKET_IT, NO_TICKET_DE = (" There is no day permit for visitors, electric cars included.",
                                            " Non c'è un permesso giornaliero per i turisti, nemmeno per le auto elettriche.",
                                            " Es gibt keine Tagesgenehmigung für Besucher, auch nicht für Elektroautos.")
B_HOURS_EN = (" The rules give no time window for sector B, so it applies 24 hours a day, every day, holidays included." if B_HOURS_OFFICIAL else
              " The rules give no hours, so GateLR treats it as always active, holidays included.")
B_HOURS_IT = (" Il disciplinare non prevede fasce orarie per la ZTL B: vale 24 ore su 24, tutti i giorni, festivi compresi." if B_HOURS_OFFICIAL else
              " Il disciplinare non indica orari, quindi GateLR la considera sempre attiva, festivi compresi.")
B_HOURS_DE = (" Die Regeln sehen für Sektor B keine Zeitfenster vor: Er gilt rund um die Uhr, täglich, auch an Feiertagen." if B_HOURS_OFFICIAL else
              " Die Regeln nennen keine Zeiten, daher behandelt GateLR ihn als immer aktiv, auch an Feiertagen.")
QUOTE_B_TR = ("Sector “B”: besides the weight, size and speed limits of point a), entry is allowed to vehicles with a permit and parking is allowed in the yellow bays",
              "Sektor „B“: Neben den Gewichts-, Größen- und Tempolimits von Punkt a) ist die Einfahrt Fahrzeugen mit Genehmigung erlaubt, Parken auf den gelben Plätzen")
B_NOTES = ([] if B_HOURS_OFFICIAL else [P_B_HOURS]) + [P_NO_TICKET, P_ELECTRIC, P_C, P_GATES]

zones = [
    {"id": "lucca-a", "name": "Sector A · Pedestrian centre ZTL", "name_it": "Settore A · ZTL zona pedonale", "name_de": "Sektor A · ZTL Fußgängerzone",
     "kind": "restricted",
     "summary": "The pedestrian heart of the old town (Piazza San Michele, Piazza Napoleone, Piazza dell'Anfiteatro, via Fillungo): closed to unauthorised vehicles at all times, every day, holidays included." + NO_TICKET_EN + HOTEL_EN,
     "summary_it": "Il cuore pedonale del centro storico (piazza San Michele, piazza Napoleone, piazza dell'Anfiteatro, via Fillungo): chiusa ai veicoli non autorizzati sempre, tutti i giorni, festivi compresi." + NO_TICKET_IT + HOTEL_IT,
     "summary_de": "Das Fußgängerherz der Altstadt (Piazza San Michele, Piazza Napoleone, Piazza dell'Anfiteatro, Via Fillungo): für nicht berechtigte Fahrzeuge immer gesperrt, täglich, auch an Feiertagen." + NO_TICKET_DE + HOTEL_DE,
     "source": source("lucca-a", QUOTE_A, ("Sector “A”: entry and parking are always forbidden, except for authorised vehicles with a permit.",
                                           "Sektor „A“: Einfahrt und Parken sind immer verboten, außer für berechtigte Fahrzeuge mit Genehmigung."),
                      [P_A_STREETS, P_NO_TICKET, P_ELECTRIC, P_C, P_GATES])},
    {"id": "lucca-b", "name": "Sector B · Historic centre ZTL", "name_it": "Settore B · ZTL centro storico", "name_de": "Sektor B · ZTL Altstadt",
     "kind": "restricted",
     "summary": "Most of the old town around sector A: you may enter only with a permit." + B_HOURS_EN + " The blue-line car parks inside the walls (sector C) stay reachable for visitors." + NO_TICKET_EN + HOTEL_EN,
     "summary_it": "Gran parte del centro storico attorno alla ZTL A: si entra solo con il permesso." + B_HOURS_IT + " I parcheggi a strisce blu dentro le Mura (ZTL C) restano raggiungibili anche per chi non è residente." + NO_TICKET_IT + HOTEL_IT,
     "summary_de": "Der größte Teil der Altstadt um Sektor A: Einfahrt nur mit Genehmigung." + B_HOURS_DE + " Die Parkplätze mit blauen Linien innerhalb der Mauern (Sektor C) bleiben für Besucher erreichbar." + NO_TICKET_DE + HOTEL_DE,
     "source": source("lucca-b", QUOTE_B, QUOTE_B_TR, B_NOTES)},
]
if from_map:
    zones.append(
        {"id": "lucca-b-est", "name": "Sector B · Villa Bottini block (cameras suspended)", "name_it": "Settore B · quadrilatero Villa Bottini (varchi sospesi)",
         "name_de": "Sektor B · Block Villa Bottini (Kameras ausgesetzt)",
         "kind": "restricted",
         "summary": "The block between via della Quarquonia, via dei Bacchettoni, via Elisa and via Santa Chiara is sector B on the official map: entry only with a permit. Its cameras have been switched off since January 2026 because of the Villa Bottini works, and the city has not said when they come back: GateLR treats it as closed, to be safe. The streets around it lead freely to the Piazza San Ponziano and via dei Bacchettoni car parks." + HOTEL_EN,
         "summary_it": "Il quadrilatero tra via della Quarquonia, via dei Bacchettoni, via Elisa e via Santa Chiara è ZTL B sulla mappa ufficiale: si entra solo con il permesso. I suoi varchi sono spenti da gennaio 2026 per il cantiere di Villa Bottini e il Comune non ha detto quando tornano attivi: GateLR la considera chiusa, per prudenza. Le strade attorno portano liberamente ai parcheggi di piazza San Ponziano e via dei Bacchettoni." + HOTEL_IT,
         "summary_de": "Der Block zwischen Via della Quarquonia, Via dei Bacchettoni, Via Elisa und Via Santa Chiara ist auf der offiziellen Karte Sektor B: Einfahrt nur mit Genehmigung. Seine Kameras sind seit Januar 2026 wegen der Arbeiten an der Villa Bottini abgeschaltet, und die Stadt hat nicht gesagt, wann sie wieder laufen: GateLR behandelt ihn vorsichtshalber als gesperrt. Die Straßen ringsum führen frei zu den Parkplätzen Piazza San Ponziano und Via dei Bacchettoni." + HOTEL_DE,
         "source": source("lucca-b-est", QUOTE_B, QUOTE_B_TR, [P_EAST, P_EAST_UNOFFICIAL] + B_NOTES)})
order = ["id", "name", "name_it", "name_de", "kind", "summary", "summary_it", "summary_de", "perimeter", "gates",
         "windows", "freeOnHolidays", "exemptFuels", "exemptVehicleTypes", "hotelCanRegister", "source"]
for z in zones:
    z.update({"perimeter": perims.get(z["id"], []), "gates": [],   # il Comune non pubblica le coordinate dei varchi
              "windows": [{"weekdays": EVERY_DAY, "start": 0, "end": 24 * 60}],
              "freeOnHolidays": False, "exemptFuels": [], "hotelCanRegister": True})
    # «L’accesso, il transito dei ciclomotori e dei motocicli è consentito nella ZTL B»; nella ZTL A solo per i residenti
    if z["id"] != "lucca-a":
        z["exemptVehicleTypes"] = ["motorcycle"]
zones = [{k: z[k] for k in order if k in z} for z in zones]

# Centro della mappa: il centro del riquadro della ZTL A; serve solo a inquadrare
a = perims["lucca-a"]
center = {"lat": round((min(p["lat"] for p in a) + max(p["lat"] for p in a)) / 2, 4),
          "lon": round((min(p["lon"] for p in a) + max(p["lon"] for p in a)) / 2, 4)}
city = {"id": "lucca", "name": "Lucca", "name_it": "Lucca", "name_de": "Lucca", "center": center,
        "zones": zones, "status": "draft",
        "license": "Rules and zone map: Comune di Lucca official documents. "
                   + ("Perimeters derived from the official Comune di Lucca map (25.11.2025), aligned on the city walls from " + osm_geo.ODBL + "."
                      if from_map else "Perimeters: " + osm_geo.ODBL + " (approximate, not official, 2024 layout).")}

# Senza perimetri aggiornati e orari ufficiali per ogni zona la città resta tra le bozze (data/drafts)
ready = PERIMETER_CURRENT and B_HOURS_OFFICIAL and all(len(z["perimeter"]) >= 4 for z in zones)
out = ROOT / ("Resources/Cities/lucca.json" if ready else "data/drafts/lucca.json")
out.parent.mkdir(parents=True, exist_ok=True)
(ROOT / ("data/drafts/lucca.json" if ready else "Resources/Cities/lucca.json")).unlink(missing_ok=True)
out.write_text(json.dumps(city, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print(out.relative_to(ROOT), [(z["id"], len(z["perimeter"]), round(osm_geo.area_km2(z["perimeter"]), 3)) for z in zones])
