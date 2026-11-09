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
  return {CITIES, CLOCK, ensureFor, placeAnswer, nearestZone, trustOf, rispostaFinale, STATI, linkHash, readLink, CARS, tono, TONO, STATE_OFF, MOTIVI, setLang: l => { lang = l; }};`)(JSON.parse(JSON.stringify(index)), "", "it", {}, fakeFetch, undefined);

const file = JSON.parse(fs.readFileSync(path.join(ROOT, "shared/engine-cases.json"), "utf8"));
const VERDICT = {yes: "yes", no: "no", cond: "conditional", unsure: "unsure"};
const errors = [];
if (!index.some(c => c.id === "salerno") || !index.some(c => c.id === "cagliari")) errors.push("mancano le città da fonti non ufficiali (Salerno, Cagliari)");
if (file.cases.length < 30) errors.push(`solo ${file.cases.length} casi`);
// 2.1 «Una risposta, sette stati»: gli stessi stati, motivi e colori semantici del file (shared/risposta-finale.md)
if (JSON.stringify(Object.keys(e.TONO)) !== JSON.stringify(file.stati)) errors.push(`stati del sito ${Object.keys(e.TONO)} diversi da ${file.stati}`);
if (JSON.stringify(e.MOTIVI) !== JSON.stringify(file.motivi)) errors.push(`motivi del sito ${e.MOTIVI} diversi da ${file.motivi}`);
for (const [s, t] of Object.entries(file.toni)) if (e.TONO[s] !== t) errors.push(`tono di ${s}: atteso ${t}, sul sito ${e.TONO[s]}`);
if (e.STATE_OFF !== file.statoSpento) errors.push(`ZTL non attiva: atteso ${file.statoSpento}, sul sito ${e.STATE_OFF}`);
if (file.cases.filter(c => c.expect.stato).length < file.cases.length) errors.push("ogni caso dice lo stato (2.1)");
let passed = 0;
const orig = new Map();
for (const c of file.cases) {
  const now = Date.parse(c.now || file.now), at = new Date(c.at), v = file.vehicles[c.vehicle];
  if (!v || isNaN(now) || isNaN(at)) { errors.push(`${c.id}: caso scritto male`); continue; }
  e.CLOCK.now = () => now;
  await e.ensureFor(c.place.lat, c.place.lon);
  // 1.20.1: «pageChanged» dei file cambia ogni mattina: i casi lo ignorano (false) salvo «source», che può dare anche
  // «verifiedOn» e «checkedOn» a tutte le zone (su una copia dei campi veri)
  const src = c.source || {};
  for (const city of e.CITIES) for (const z of city.zones || []) {
    if (!orig.has(z)) orig.set(z, {verifiedOn: z.source.verifiedOn, checkedOn: z.source.checkedOn});
    const o = orig.get(z);
    z.source.verifiedOn = "verifiedOn" in src ? src.verifiedOn : o.verifiedOn;
    z.source.checkedOn = src.checkedOn || o.checkedOn;
    z.source.pageChanged = "pageChanged" in src ? src.pageChanged : false;
  }
  // 2.3 «hotel»: il posto è il tuo hotel; con «confermato» la conferma segnata per il veicolo «veicolo» e i giorni dal–al
  // (sul sito «chiesto» non c'è: vale come «nonChiesto», senza conferma)
  const h = c.hotel, staying = !h ? false : h.stato === "confermato" ? {reg: {v: file.vehicles[h.veicolo], from: h.dal, to: h.al}} : true;
  if (h && (!["nonChiesto", "chiesto", "confermato"].includes(h.stato) || !file.vehicles[h.veicolo] || !/^\d{4}-\d{2}-\d{2}$/.test(h.dal) || !/^\d{4}-\d{2}-\d{2}$/.test(h.al))) { errors.push(`${c.id}: hotel scritto male`); continue; }
  const p = e.placeAnswer(c.place.lat, c.place.lon, at, staying, v);
  const bad0 = [];
  const got = {colour: p.colour, verdict: VERDICT[p.verdict] || p.verdict, zone: p.zone ? p.zone.id : null,
    gatesOn: p.r ? !!p.r.on : undefined, unofficial: p.unoff, pedestrian: !!p.ped, trust: p.zone ? e.trustOf(p.zone) : undefined,
    stato: p.stato, motivo: p.motivo || undefined, hotel: p.hotel || undefined};
  // 2.3: la riga dell'hotel solo dove il caso la dice (anche nessuna)
  if (!("hotel" in c.expect) && p.hotel) bad0.push(`hotel ${p.hotel} non atteso`);
  if (p.hotel === "registrata" && e.tono(p.stato) !== "verde") bad0.push("hotel registrata senza verde");
  if (p.hotel === "daChiedere" && p.stato !== "nonEntrare") bad0.push("hotel da chiedere senza «Non entrare»");
  // 2.1 (B09): la distanza dal lato della zona più vicina, con 5 m di tolleranza
  if ("nearestMeters" in c.expect) { const n = e.nearestZone(c.place.lat, c.place.lon); got.nearestMeters = Math.abs(n.meters - c.expect.nearestMeters) <= 5 ? c.expect.nearestMeters : Math.round(n.meters); }
  const bad = bad0.concat(Object.entries(c.expect).filter(([k, want]) => got[k] !== want).map(([k, want]) => `${k} atteso ${JSON.stringify(want)}, ottenuto ${JSON.stringify(got[k])}`));
  // Le regole fisse, qualunque cosa dica il file: mai verde fuori copertura o da fonte non ufficiale
  if (!p.covered && p.colour !== "neutral") bad.push("fuori copertura non neutro");
  if (p.unoff && p.colour === "green") bad.push("fonte non ufficiale verde");
  // 1.20.4: fuori dalla ZTL in una città che conosciamo è grigio, mai verde
  if (p.covered && !p.zone && !p.ped && !p.unoff && p.colour !== "grey") bad.push("fuori dalla ZTL non grigio");
  // 2.1: il motivo solo con «Controlla il cartello»; mai verde fuori copertura, da fonte non ufficiale o con dati scaduti
  if ((p.stato === "controllaCartello") !== !!p.motivo) bad.push(`motivo ${p.motivo} con lo stato ${p.stato}`);
  if (e.tono(p.stato) === "verde" && (!p.covered || p.unoff)) bad.push(`stato ${p.stato} verde dove non sappiamo`);
  // 1.20.1 (regola A): mai verde da una zona senza verifica né lettura recente o con la pagina del Comune cambiata
  if (p.zone && !p.ped && !["verified", "read"].includes(e.trustOf(p.zone)) && p.colour === "green") bad.push("zona non sicura verde");
  // 2.0 «Risposta finale» (le sette risposte della pagina): fuori copertura neutro, fuori dalla ZTL grigio, ZTL non attiva
  // solo se i varchi sono spenti, e mai «Entra pure»/«ZTL non attiva» quando il colore non è verde (non ufficiale, non sicuro)
  const f = e.rispostaFinale(p), want = !p.covered ? "fuoriCopertura" : p.ped ? "no" : !p.zone ? (p.unoff ? "nonSicuro" : "fuoriZTL")
    : {red: "no", yellow: p.verdict === "cond" ? "condizione" : "nonSicuro", green: p.r.on ? "si" : "nonAttiva"}[p.colour];
  if (!f || !e.STATI.includes(f.stato)) bad.push(`risposta finale sconosciuta ${JSON.stringify(f)}`);
  else if (f.stato !== want) bad.push(`risposta finale ${f.stato}, attesa ${want}`);
  if (f && ["si", "nonAttiva"].includes(f.stato) && (p.unoff || !p.covered || (p.zone && !["verified", "read"].includes(e.trustOf(p.zone))))) bad.push("risposta finale verde senza fonte sicura");
  if (f && f.stato === "nonSicuro" && !f.motivo) bad.push("«Controlla il cartello» senza motivo");
  // 2.0 «Link di una risposta»: riapre la stessa domanda (posto, giorno e ora, veicolo) e non porta altro
  const la = {y: +c.at.slice(0, 4), m: +c.at.slice(5, 7), d: +c.at.slice(8, 10), min: +c.at.slice(11, 13) * 60 + Math.floor(+c.at.slice(14, 16) / 15) * 15};
  const car = e.CARS.find(x => x.fuel === v.fuel && x.euro === v.euro && (x.type || "car") === (v.type || "car")) || e.CARS[0];
  const hash = e.linkHash({name: c.place.name, lat: c.place.lat, lon: c.place.lon, hotel: !!c.hotel, plate: "AB123CD", hotelName: "Hotel X"}, la, car);
  const keys = [...new URLSearchParams(hash.slice(1)).keys()], back = e.readLink(hash);
  if (keys.some(k => !["p", "n", "t", "v", "h"].includes(k)) || /AB123CD|Hotel X/.test(decodeURIComponent(hash))) bad.push(`link con dati in più: ${hash}`);
  if (!back || Math.abs(back.place.lat - c.place.lat) > 1e-5 || Math.abs(back.place.lon - c.place.lon) > 1e-5 || back.place.name !== c.place.name
      || e.CARS[back.car] !== car || JSON.stringify(back.at) !== JSON.stringify(la) || back.place.hotel !== !!c.hotel) bad.push(`link che non riapre la domanda: ${hash}`);
  if (bad.length) errors.push(`${c.id}: ${bad.join("; ")}`); else passed++;
}
// link scritti male: nessuna risposta inventata
for (const h of ["#firenze", "#p=abc", "#p=91,10", "#p=43.7,11.2,5", "#app"]) if (e.readLink(h)) errors.push(`link scritto male accettato: ${h}`);
for (const x of errors) console.log("::error::check_engine_cases: " + x);
console.log(`${file.cases.length} casi comuni del motore: ${passed} giusti, ${errors.length} errori`);
process.exit(errors.length ? 1 : 0);
