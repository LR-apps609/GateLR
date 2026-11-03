// 1.20.0 «Motore unico»: i casi di prova comuni (shared/engine-cases.json) con il motore del sito, gli stessi che provano
// l'iPhone (Tests/SharedEngineCasesTests.swift) e Android (android/core/.../SharedEngineCasesTest.kt).
// Prende motore e geometria dalla home costruita (web/index.html, da `const TZ` a «Mappa disegnata»), scarica le città come
// fa la pagina (ensureFor) e confronta colore, risposta come si mostra e zona che decide (placeAnswer).
// Uso: python3 Tools/build_site.py && node Tools/check_engine_cases.mjs
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const WEB = path.join(ROOT, "web");
const html = fs.readFileSync(path.join(WEB, "index.html"), "utf8");
const index = JSON.parse(html.match(/<script id="cities" type="application\/json">([\s\S]*?)<\/script>/)[1]);
const a = html.indexOf('const TZ = "Europe/Rome";'), b = html.indexOf("// ── Mappa disegnata");
if (a < 0 || b < a) { console.log("::error::check_engine_cases: non trovo il motore in web/index.html"); process.exit(1); }
const code = html.slice(a, b);

const fakeFetch = async url => {
  const f = path.join(WEB, url);
  if (!fs.existsSync(f)) return {ok: false, status: 404, json: async () => null};
  const text = fs.readFileSync(f, "utf8");
  return {ok: true, status: 200, json: async () => JSON.parse(text)};
};
const e = new Function("CITIES", "ROOT", "PAGE_LANG", "window", "fetch", "localStorage", code + `
  return {CITIES, CLOCK, ensureFor, placeAnswer, setLang: l => { lang = l; }};`)(JSON.parse(JSON.stringify(index)), "", "it", {}, fakeFetch, undefined);

const file = JSON.parse(fs.readFileSync(path.join(ROOT, "shared/engine-cases.json"), "utf8"));
const VERDICT = {yes: "yes", no: "no", cond: "conditional", unsure: "unsure"};
const errors = [];
if (!index.some(c => c.id === "salerno") || !index.some(c => c.id === "cagliari")) errors.push("mancano le città da fonti non ufficiali (Salerno, Cagliari)");
if (file.cases.length < 30) errors.push(`solo ${file.cases.length} casi`);
let passed = 0;
for (const c of file.cases) {
  const now = Date.parse(c.now || file.now), at = new Date(c.at), v = file.vehicles[c.vehicle];
  if (!v || isNaN(now) || isNaN(at)) { errors.push(`${c.id}: caso scritto male`); continue; }
  e.CLOCK.now = () => now;
  await e.ensureFor(c.place.lat, c.place.lon);
  const p = e.placeAnswer(c.place.lat, c.place.lon, at, !!c.hotel, v);
  const got = {colour: p.colour, verdict: VERDICT[p.verdict] || p.verdict, zone: p.zone ? p.zone.id : null,
    gatesOn: p.r ? !!p.r.on : undefined, unofficial: p.unoff, pedestrian: !!p.ped};
  const bad = Object.entries(c.expect).filter(([k, want]) => got[k] !== want).map(([k, want]) => `${k} atteso ${JSON.stringify(want)}, ottenuto ${JSON.stringify(got[k])}`);
  // Le regole fisse, qualunque cosa dica il file: mai verde fuori copertura o da fonte non ufficiale
  if (!p.covered && p.colour !== "neutral") bad.push("fuori copertura non neutro");
  if (p.unoff && p.colour === "green") bad.push("fonte non ufficiale verde");
  if (bad.length) errors.push(`${c.id}: ${bad.join("; ")}`); else passed++;
}
for (const x of errors) console.log("::error::check_engine_cases: " + x);
console.log(`${file.cases.length} casi comuni del motore: ${passed} giusti, ${errors.length} errori`);
process.exit(errors.length ? 1 : 0);
