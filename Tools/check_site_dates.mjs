// 2.0.1: giorni e ore di Roma nel sito, senza browser (bug B04, B18, B19 dei tester; e B21, B20 per il motore).
// Prende il motore dalla home costruita (web/index.html, da `const TZ` a «Mappa disegnata»), come check_site_answers.mjs, e prova:
// - romeInstant: ogni quarto d'ora dei giorni del cambio dell'ora torna lo stesso giorno e minuto a Roma (il 25 ottobre le
//   2:00-2:59 sono la prima volta; l'ultima domenica di marzo le 2:00-2:45 non esistono e diventano le 3:00-3:45);
// - dayRome e when(): «domani» è il giorno dopo nel calendario, non 24 ore dopo, a ogni ora dei giorni del cambio;
// - i veicoli: Diesel Euro 5 e Benzina Euro 4 e 5 ci sono, gli indici di prima non cambiano (link e scelte salvate);
// - la risposta del posto per ogni quarto d'ora (quella della barra dell'ora) dove due zone si sovrappongono.
// Uso: python3 Tools/build_site.py && node Tools/check_site_dates.mjs
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const WEB = path.join(ROOT, "web");
const html = fs.readFileSync(path.join(WEB, "index.html"), "utf8");
const index = JSON.parse(html.match(/<script id="cities" type="application\/json">([\s\S]*?)<\/script>/)[1]);
const a = html.indexOf('const TZ = "Europe/Rome";'), b = html.indexOf("// ── Mappa disegnata");
if (a < 0 || b < a) { console.log("::error::check_site_dates: non trovo il motore in web/index.html"); process.exit(1); }
const fakeFetch = async url => { const f = path.join(WEB, url); const ok = fs.existsSync(f); return {ok, status: ok ? 200 : 404, json: async () => JSON.parse(fs.readFileSync(f, "utf8"))}; };
const e = new Function("CITIES", "ROOT", "PAGE_LANG", "window", "fetch", "localStorage", html.slice(a, b) + `
  return {CLOCK, rome, romeInstant, addDays, dayRome, when, CARS, VKEY, ensureFor, placeAnswer, rispostaFinale, answer, zonesAt, setLang: l => { lang = l; }};`)(JSON.parse(JSON.stringify(index)), "", "it", {}, fakeFetch, undefined);

const errors = [];
const key = r => `${r.y}-${String(r.m).padStart(2, "0")}-${String(r.d).padStart(2, "0")}`;
// ── romeInstant ────────────────────────────────────────────────────────────
const SPRING = ["2026-03-29", "2027-03-28", "2028-03-26"], AUTUMN = ["2026-10-25", "2027-10-31"], PLAIN = ["2026-11-14", "2027-07-17", "2026-03-28", "2026-10-24"];
let n = 0;
for (const day of [...SPRING, ...AUTUMN, ...PLAIN]){
  const [y, m, d] = day.split("-").map(Number); let prev = -Infinity;
  for (let min = 0; min < 1440; min += 15){
    const t = e.romeInstant(y, m, d, min), r = e.rome(t), gap = SPRING.includes(day) && min >= 120 && min < 180;
    const want = gap ? min + 60 : min;
    if (key(r) !== day || r.min !== want) errors.push(`romeInstant ${day} ${Math.floor(min / 60)}:${String(min % 60).padStart(2, "0")} → ${key(r)} ${Math.floor(r.min / 60)}:${String(r.min % 60).padStart(2, "0")}`);
    if (t.getTime() <= prev && !gap) errors.push(`romeInstant ${day}: ${min} non dopo il quarto d'ora prima`);
    if (!gap) prev = t.getTime(); n++;
  }
}
// ── dayRome e when: il calendario, a ogni ora dei giorni del cambio ────────────────────────
for (const day of [...SPRING, ...AUTUMN, "2026-12-06", "2026-11-12"]){
  const [y, m, d] = day.split("-").map(Number);
  for (let h = 0; h < 24; h++){
    const now = e.romeInstant(y, m, d, h * 60); e.CLOCK.now = () => now.getTime();
    const days = [0, 1, 2, 3, 4, 5, 6, 7].map(e.dayRome);
    if (key(days[0]) !== day) errors.push(`dayRome(0) il ${day} alle ${h}: ${key(days[0])}`);
    for (let i = 1; i < days.length; i++){ const want = new Date(Date.UTC(y, m - 1, d + i)); if (key(days[i]) !== want.toISOString().slice(0, 10)) errors.push(`dayRome(${i}) il ${day} alle ${h}: ${key(days[i])}`); }
    const tom = days[1], t = e.romeInstant(tom.y, tom.m, tom.d, 540);
    e.setLang("it"); const w = e.when(t, now);
    if (!w.startsWith("domani alle")) errors.push(`when() il ${day} alle ${h} per domani alle 9: «${w}»`);
    n++;
  }
}
e.CLOCK.now = () => Date.now();
// ── i veicoli ──────────────────────────────────────────────────────────────
const KEYS = e.CARS.map(e.VKEY);
const BEFORE = ["petrol-6", "petrol-3", "diesel-4", "diesel-6", "hybrid-6", "electric-6", "moto-5"];
BEFORE.forEach((k, i) => { if (KEYS[i] !== k) errors.push(`veicolo ${i} è ${KEYS[i]}, era ${k} (link e scelte salvate cambierebbero)`); });
for (const k of ["diesel-5", "petrol-4", "petrol-5"]) if (!KEYS.includes(k)) errors.push(`manca il veicolo ${k}`);
if (new Set(KEYS).size !== KEYS.length) errors.push(`veicoli doppi: ${KEYS.join(", ")}`);
// ── la risposta del posto per ogni quarto d'ora: dove due zone si sovrappongono vale la peggiore ─────────
// (la barra dell'ora della pagina usa questa; prima era la sola zona che decideva all'ora scelta)
const SEV = {no: 4, condizione: 3, nonSicuro: 2, si: 1, nonAttiva: 1, fuoriZTL: 0, fuoriCopertura: 0};
for (const [name, lat, lon, day, car] of [["Trastevere", 41.89171, 12.46659, "2026-11-07", 0], ["Torino Area Romana", 45.07485, 7.68048, "2026-11-10", 0],
  ["Parma, diesel Euro 4", 44.8015, 10.3280, "2026-11-08", 2], ["Duomo di Firenze", 43.7731, 11.2560, "2026-11-14", 0]]){
  await e.ensureFor(lat, lon);
  const [y, m, d] = day.split("-").map(Number), hits = e.zonesAt(lat, lon);
  if (hits.length < 2) errors.push(`${name}: ${hits.length} zone, la prova vuole un posto con due zone`);
  for (let i = 0; i < 96; i++){
    const t = e.romeInstant(y, m, d, i * 15), st = e.rispostaFinale(e.placeAnswer(lat, lon, t, false, e.CARS[car], true)).stato;
    // nessuna zona del posto, da sola, dà una risposta peggiore di quella del posto
    for (const h of hits){ const r = e.answer(h.zone, t, false, e.CARS[car], true), one = r.v === "no" ? "no" : r.v === "cond" ? "condizione" : r.v === "unsure" ? "nonSicuro" : "si";
      if (SEV[one] > SEV[st]){ errors.push(`${name} ${day} ${Math.floor(i / 4)}:${String(i % 4 * 15).padStart(2, "0")}: il posto è «${st}» ma ${h.zone.id} da sola è «${one}»`); break; } }
    n++;
  }
}
for (const x of errors.slice(0, 30)) console.log("::error::check_site_dates: " + x);
console.log(`${n} prove di giorni, ore e veicoli: ${errors.length} errori`);
process.exit(errors.length ? 1 : 0);
