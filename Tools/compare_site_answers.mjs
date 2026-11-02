// Confronta le risposte di due versioni del sito nel browser, prima e dopo una modifica (es. 1.19.4 → 1.19.5).
// Per ogni luogo d'esempio (punto di partenza e centro di ogni città, metà delle zone, aree pedonali, appena fuori, lontano)
// e alcune combinazioni di veicolo, giorno e ora sceglie il luogo con window.gatelr.choose e legge tutto quello che la
// pagina scrive: colore della risposta, luogo, varchi, titolo, «fino a», perché, segno, conto alla rovescia, orari, pannello.
// Uso (Playwright e Chromium già installati):
//   python3 -m http.server -d <sito prima> 8101 & python3 -m http.server -d web 8102 &
//   node Tools/compare_site_answers.mjs http://localhost:8101/ http://localhost:8102/ [lingua]
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
let pw;
try { pw = require("playwright"); } catch { pw = require("/opt/node22/lib/node_modules/playwright"); }
const exe = fs.existsSync("/opt/pw-browsers/chromium") ? {executablePath: "/opt/pw-browsers/chromium"} : {};
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const [A, B, lang = "en"] = process.argv.slice(2);
if (!A || !B) { console.log("uso: node Tools/compare_site_answers.mjs <url prima> <url dopo> [en|it|de]"); process.exit(2); }

// i luoghi, dai dati delle città dell'app
const man = JSON.parse(fs.readFileSync(path.join(ROOT, "Resources/Cities/manifest.json"), "utf8"));
const pts = [];
for (const m of [...man.cities, ...(man.unofficialCities || [])]) {
  const c = JSON.parse(fs.readFileSync(path.join(ROOT, "Resources/Cities", m.file), "utf8"));
  pts.push({name: `${c.id} centro`, lat: c.center.lat, lon: c.center.lon});
  for (const z of c.zones.slice(0, 3)) {
    const la = z.perimeter.map(q => q.lat), lo = z.perimeter.map(q => q.lon), mid = [(Math.min(...la) + Math.max(...la)) / 2, (Math.min(...lo) + Math.max(...lo)) / 2];
    pts.push({name: `${z.id} metà`, lat: mid[0], lon: mid[1]}, {name: `${z.id} fuori`, lat: Math.max(...la) + 0.0036, lon: mid[1]});
  }
  const ped = (c.pedestrian || [])[0];
  if (ped) pts.push({name: `${ped.id} pedonale`, lat: ped.perimeter.reduce((s, q) => s + q.lat, 0) / ped.perimeter.length, lon: ped.perimeter.reduce((s, q) => s + q.lon, 0) / ped.perimeter.length});
  pts.push({name: `${c.id} hotel`, lat: c.center.lat, lon: c.center.lon, hotel: true});
}
pts.push({name: "Venezia", lat: 45.4380, lon: 12.3358}, {name: "Parigi", lat: 48.8566, lon: 2.3522}, {name: "Prato", lat: 43.8777, lon: 11.1022});
// veicolo (indice), giorno (0 oggi … 6), ora in minuti
const SETS = [[0, 1, 10 * 60], [2, 2, 23 * 60 + 30], [6, 5, 3 * 60], [1, 0, 17 * 60 + 45]];

async function run(url) {
  const b = await pw.chromium.launch(exe);
  const p = await b.newPage({viewport: {width: 1280, height: 900}});
  await p.addInitScript(l => { try { localStorage.setItem("gatelr.lang", l); } catch {} }, lang);
  await p.route(/photon\.komoot|openfreemap|cartocdn|unpkg\.com/, r => r.abort());   // niente rete esterna: solo le risposte
  await p.goto(url, {waitUntil: "load"});
  await p.waitForFunction(() => window.gatelr && document.getElementById("a-where").textContent.includes(" · "), null, {timeout: 30000});
  const out = {};
  for (const [car, day, min] of SETS) {
    await p.evaluate(([car, day, min]) => {
      const set = (id, v, ev) => { const e = document.getElementById(id); e.value = String(v); e.dispatchEvent(new Event(ev)); };
      set("car", car, "change"); set("day", day, "change"); set("hour", min, "input");
    }, [car, day, min]);
    for (const q of pts) {
      const r = await p.evaluate(async q => {
        await window.gatelr.choose({name: q.hotel ? "Hotel Prova" : "Prova", lat: q.lat, lon: q.lon, hotel: !!q.hotel});
        for (let i = 0; i < 300 && (document.getElementById("answer").dataset.v === "wait" && document.getElementById("a-title").textContent.trim() === "" || !document.getElementById("a-where").textContent.includes(" · ")); i++)
          await new Promise(z => setTimeout(z, 20));
        const $ = id => document.getElementById(id), tx = id => $(id).textContent.trim();
        return {v: $("answer").dataset.v, where: tx("a-where"), gates: tx("a-gates"), title: tx("a-title"), until: tx("a-until"), why: tx("a-why"),
          mark: $("a-mark").innerHTML, count: $("a-count").hidden ? "" : tx("a-since") + " | " + tx("a-next") + " | " + $("a-bar").style.width,
          unoff: $("a-unoff").hidden, draft: $("a-draft").hidden, src: tx("a-src"), hours: tx("hours"), hlabel: tx("h-label"), note: tx("h-note"), led: tx("led-t"),
          track: $("hour").style.getPropertyValue("--track")};
      }, q);
      out[`${q.name} · veicolo ${car} · giorno ${day} · ${min}`] = r;
    }
  }
  await b.close();
  return out;
}
const before = await run(A), after = await run(B);
let diff = 0;
if (process.env.DUMP) for (const k of Object.keys(after).slice(0, +process.env.DUMP)) console.log(k, JSON.stringify(after[k]).slice(0, 400));
const vs = {}; for (const r of Object.values(after)) vs[r.v] = (vs[r.v] || 0) + 1;
console.log("risposte per colore (dopo):", JSON.stringify(vs));
for (const k of Object.keys(before)) {
  const x = JSON.stringify(before[k]), y = JSON.stringify(after[k]);
  if (x !== y) { diff++; if (diff <= 20) console.log("DIVERSO", k, "\n  prima:", x, "\n  dopo: ", y); }
}
console.log(`${Object.keys(before).length} risposte confrontate (${pts.length} luoghi × ${SETS.length} impostazioni, lingua ${lang}), ${diff} diverse`);
process.exit(diff ? 1 : 0);
