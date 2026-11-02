// Le risposte del sito non cambiano con i dati delle città scaricati a richiesta (1.19.5).
// Prende il motore e la geometria dalla home costruita (web/index.html, da `const TZ` a «Mappa disegnata») e risponde sugli
// stessi punti, ore, veicoli e lingue in due modi:
//   «tutte»: tutte le città caricate prima, come quando la home conteneva tutti i dati (fino alla 1.19.4);
//   «a richiesta»: solo l'indice, e per ogni punto ensureFor(), come fa la pagina.
// Luogo trovato (città, zona, area pedonale, zona più vicina e distanza) e risposta (verdetto, titolo, perché, orari) devono
// essere identici. Controlla anche che l'indice (riquadri, centro, nomi) corrisponda ai file delle città.
// Uso: python3 Tools/build_site.py && node Tools/check_site_answers.mjs
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const WEB = path.join(ROOT, "web");
const html = fs.readFileSync(path.join(WEB, "index.html"), "utf8");
const index = JSON.parse(html.match(/<script id="cities" type="application\/json">([\s\S]*?)<\/script>/)[1]);
const a = html.indexOf('const TZ = "Europe/Rome";'), b = html.indexOf("// ── Mappa disegnata");
if (a < 0 || b < a) { console.log("::error::check_site_answers: non trovo il motore in web/index.html"); process.exit(1); }
const code = html.slice(a, b);

const errors = [];
let loads = 0;
const fakeFetch = async url => {
  loads++;
  const f = path.join(WEB, url);
  if (!fs.existsSync(f)) return {ok: false, status: 404, json: async () => null};
  const text = fs.readFileSync(f, "utf8");
  return {ok: true, status: 200, json: async () => JSON.parse(text)};
};
function engine() {
  const cities = JSON.parse(JSON.stringify(index));
  const api = new Function("CITIES", "ROOT", "PAGE_LANG", "window", "fetch", "localStorage", code + `
    return {CITIES, CARS, PLACES, START, SAMPLES, zoneAt, pedAt, nearestZone, answer, ensureFor, loadCity, setLang: l => { lang = l; }};`);
  return api(cities, "", "", {}, fakeFetch, undefined);
}

const man = JSON.parse(fs.readFileSync(path.join(ROOT, "Resources/Cities/manifest.json"), "utf8"));
const FILE = Object.fromEntries([...man.cities, ...(man.unofficialCities || [])].map(m => [m.file.replace(/\.json$/, ""), m.file]));
// ── l'indice corrisponde ai file ─────────────────────────────────────────────
const box = pers => { const p = pers.flat(); return [Math.min(...p.map(q => q.lat)), Math.min(...p.map(q => q.lon)), Math.max(...p.map(q => q.lat)), Math.max(...p.map(q => q.lon))]; };
for (const c of index) {
  const f = path.join(WEB, c.f);
  if (!fs.existsSync(f)) { errors.push(`${c.id}: manca ${c.f}`); continue; }
  const d = JSON.parse(fs.readFileSync(f, "utf8"));
  const ab = box([...d.zones, ...(d.pedestrian || [])].map(z => z.perimeter)), zb = box(d.zones.map(z => z.perimeter));
  if (JSON.stringify(ab) !== JSON.stringify(c.ab) || JSON.stringify(zb) !== JSON.stringify(c.zb)) errors.push(`${c.id}: riquadri dell'indice diversi dai dati`);
  for (const k of ["id", "name", "center", "status"]) if (JSON.stringify(d[k]) !== JSON.stringify(c[k])) errors.push(`${c.id}: «${k}» dell'indice diverso dai dati`);
  // gli stessi dati dell'app (Resources/Cities), più le forme della mappa
  const src = JSON.parse(fs.readFileSync(path.join(ROOT, "Resources/Cities", FILE[c.id]), "utf8"));
  const { shapes, ...rest } = d;
  if (JSON.stringify(rest) !== JSON.stringify(src)) errors.push(`${c.id}: il file del sito non è uguale a Resources/Cities/${c.id}.json`);
}

// ── i punti di prova ─────────────────────────────────────────────────────────
const all = engine(), lazy = engine();
for (const c of all.CITIES) await all.loadCity(c);
const pts = [];
const add = (name, lat, lon) => pts.push({name, lat, lon});
for (const c of all.CITIES) {
  add(`${c.id} centro`, c.center.lat, c.center.lon);
  if (all.START[c.id]) add(`${c.id} partenza`, all.START[c.id][1], all.START[c.id][2]);
  for (const z of c.zones) {
    const p = z.perimeter, la = p.map(q => q.lat), lo = p.map(q => q.lon);
    const mid = [(Math.min(...la) + Math.max(...la)) / 2, (Math.min(...lo) + Math.max(...lo)) / 2];
    add(`${z.id} metà`, ...mid);
    add(`${z.id} vertice`, p[0].lat, p[0].lon);
    add(`${z.id} fuori 400 m`, Math.max(...la) + 0.0036, mid[1]);
    add(`${z.id} fuori 3 km`, mid[0], Math.min(...lo) - 0.037);
    add(`${z.id} fuori 20 km`, Math.min(...la) - 0.18, mid[1]);
  }
  for (const ped of (c.pedestrian || []).slice(0, 4)) {
    const p = ped.perimeter; add(`${ped.id} pedonale`, p.reduce((s, q) => s + q.lat, 0) / p.length, p.reduce((s, q) => s + q.lon, 0) / p.length);
  }
}
for (const [n, la, lo] of all.PLACES) add(n, la, lo);
for (const [n, la, lo] of all.SAMPLES) add(n.en, la, lo);
for (const [n, la, lo] of [["Venezia", 45.4380, 12.3358], ["Parigi", 48.8566, 2.3522], ["Mar Tirreno", 40.5, 11.5], ["Brennero", 47.0, 11.5],
  ["Lampedusa", 35.51, 12.60], ["Prato", 43.8777, 11.1022], ["Monza", 45.5845, 9.2744], ["Fiumicino", 41.7999, 12.2462], ["Aosta", 45.7372, 7.3206]]) add(n, la, lo);

// ore (di Roma, in UTC qui sotto): un lunedì mattina, sabato notte, domenica, Natale, una notte d'estate, adesso
const T = [new Date(), new Date(Date.UTC(2026, 10, 9, 9, 0)), new Date(Date.UTC(2026, 10, 14, 22, 30)), new Date(Date.UTC(2026, 10, 15, 2, 0)),
  new Date(Date.UTC(2026, 11, 25, 11, 0)), new Date(Date.UTC(2027, 6, 17, 21, 30)), new Date(Date.UTC(2027, 2, 1, 6, 45))];
const pick = r => r && {v: r.v, title: r.title, why: r.why, on: r.on, next: r.next && +r.next, since: r.since && +r.since};
function where(e, p) {
  const hit = e.zoneAt(p.lat, p.lon), ped = e.pedAt(p.lat, p.lon), near = hit ? null : e.nearestZone(p.lat, p.lon);
  return {hit, ped, near, key: JSON.stringify({city: hit && hit.city.id, zone: hit && hit.zone.id, ped: ped && ped.area.id,
    near: near && [near.city.id, near.zone.id, Math.round(near.meters / 50) * 50, near.meters > 15000]})};
}
let n = 0;
const loads0 = loads;
for (const p of pts) {
  await lazy.ensureFor(p.lat, p.lon);
  const A = where(all, p), B = where(lazy, p);
  if (A.key !== B.key) { errors.push(`${p.name}: luogo diverso ${A.key} ≠ ${B.key}`); continue; }
  const z = A.hit ? A.hit.zone : null, zB = B.hit ? B.hit.zone : null;
  if (!z) { n++; continue; }
  // stessi dati della zona trovata, poi la risposta per alcune combinazioni (a rotazione: lingua, ora, veicolo, hotel;
  // ogni risposta guarda 8 giorni avanti e indietro, tutte le combinazioni sarebbero troppo lente)
  if (JSON.stringify(z) !== JSON.stringify(zB)) { errors.push(`${p.name}: dati della zona ${z.id} diversi`); continue; }
  for (let k = 0; k < 3; k++) {
    const j = pts.indexOf(p) + k, lang = ["en", "it", "de"][j % 3], t = T[(j * 2 + k) % T.length], i = (j + k * 3) % all.CARS.length, staying = (j + k) % 2 === 1;
    all.setLang(lang); lazy.setLang(lang);
    const x = JSON.stringify(pick(all.answer(z, t, staying, all.CARS[i]))), y = JSON.stringify(pick(lazy.answer(zB, t, staying, lazy.CARS[i])));
    n++;
    if (x !== y) errors.push(`${p.name} ${lang} ${t.toISOString()} veicolo ${i}${staying ? " hotel" : ""}: ${x} ≠ ${y}`);
  }
}
const loaded = lazy.CITIES.filter(c => c.zones).length;
// e senza scaricare più del necessario: un luogo in città porta una città sola, uno lontano poche
for (const [name, lat, lon, max] of [["Duomo di Firenze", 43.7731, 11.2560, 1], ["Colosseo", 41.8902, 12.4922, 1], ["Duomo di Milano", 45.4642, 9.1900, 1],
  ["Venezia", 45.4380, 12.3358, 3], ["Parigi", 48.8566, 2.3522, 3]]) {
  const e = engine(); await e.ensureFor(lat, lon);
  const k = e.CITIES.filter(c => c.zones).length;
  if (k > max) errors.push(`${name}: scaricate ${k} città (al massimo ${max})`);
  else console.log(`${name}: ${k} città scaricate`);
}
for (const e of errors.slice(0, 30)) console.log("::error::" + e);
console.log(`${pts.length} punti, ${n} risposte confrontate, ${errors.length} differenze; a richiesta: ${loaded}/${index.length} città scaricate in tutto (${loads - loads0} richieste)`);
process.exit(errors.length ? 1 : 0);
