// 2.0.2 «Fiducia»: i casi comuni della riga sotto la risposta e del link per l'hotel o il noleggio (shared/fiducia-cases.json),
// gli stessi dell'iPhone (Tests/FiduciaTests.swift) e di Android (android/core/.../FiduciaTest.kt), con le funzioni del sito
// (fiduciaControl, fiduciaVehicleKey, fiduciaShareURL nel motore di web/index.html). Poi le pagine costruite: la riga e il
// pulsante nella home, «funziona nel browser», le due pagine («Come controlliamo i dati», «Cosa fare se ricevi una multa») in
// tre lingue, con «GateLR non rimborsa multe» e le fonti ufficiali dei ricorsi.
// Uso: python3 Tools/build_site.py && node Tools/check_fiducia.mjs
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const WEB = path.join(ROOT, "web");
const read = f => fs.readFileSync(path.join(WEB, f), "utf8");
const html = read("index.html");
const errors = [];
const a = html.indexOf('const TZ = "Europe/Rome";'), b = html.indexOf("// ── Mappa disegnata");
if (a < 0 || b < a) { console.log("::error::check_fiducia: non trovo il motore in web/index.html"); process.exit(1); }
const index = JSON.parse(html.match(/<script id="cities" type="application\/json">([\s\S]*?)<\/script>/)[1]);
const e = new Function("CITIES", "ROOT", "PAGE_LANG", "window", "fetch", "localStorage", html.slice(a, b) + `
  return {CLOCK, fiduciaControl, fiduciaVehicleKey, fiduciaShareURL, FID_SITE, FID_VEHICLES, CARS, VKEY, trustOf, T};`)(index, "", "it", {}, async () => ({ok: false}), undefined);

const file = JSON.parse(fs.readFileSync(path.join(ROOT, "shared/fiducia-cases.json"), "utf8"));
if (e.FID_SITE !== file.site) errors.push(`indirizzo del sito ${e.FID_SITE} diverso da ${file.site}`);
if (JSON.stringify(e.FID_VEHICLES) !== JSON.stringify(file.siteVehicles)) errors.push("i veicoli del sito nei casi comuni non sono quelli del codice");
// I veicoli del menu del sito sono proprio quelli dei link (VKEY di CARS)
const keys = e.CARS.map(e.VKEY);
if (JSON.stringify([...keys].sort()) !== JSON.stringify([...file.siteVehicles].sort())) errors.push(`CARS del sito (${keys}) diversi da siteVehicles`);
let passed = 0;
for (const c of file.control) {
  e.CLOCK.now = () => Date.parse(c.now);
  const got = e.fiduciaControl(c.source), x = c.expect;
  const bad = ["when", "label", "fresh", "byHand"].filter(k => got[k] !== x[k]);
  if (bad.length) errors.push(`${c.id}: ${bad.map(k => `${k} ${JSON.stringify(got[k])} invece di ${JSON.stringify(x[k])}`).join(", ")}`); else passed++;
}
for (const c of file.share) {
  const url = e.fiduciaShareURL(c.lang, c.city, c.place, e.fiduciaVehicleKey(c.vehicle));
  if (url !== c.expect) errors.push(`${c.id}: ${url} invece di ${c.expect}`); else passed++;
}
// Il colore della risposta non dipende dalla verifica a mano (trustOf non guarda reviewedByHuman)
e.CLOCK.now = () => Date.parse("2026-11-12T10:00:00+01:00");
if (e.trustOf({source: {checkedOn: "2026-10-23T12:00:00Z", reviewedByHuman: false}}) !== e.trustOf({source: {checkedOn: "2026-10-23T12:00:00Z", reviewedByHuman: true}}))
  errors.push("la verifica a mano cambia la fiducia della risposta (non deciso)");
for (const l of ["en", "it", "de"]) {
  const t = e.T[l];
  for (const k of ["fidToday", "fidYesterday", "fidHand", "fidSend", "fidNoInst", "fidChecks", "fidFine", "sendOk", "sendSel", "noInst"])
    if (typeof t[k] !== "string" || !t[k]) errors.push(`sito ${l}: manca ${k}`);
  if (!/install/i.test(t.sendText("X")) || !t.sendText("Hotel Y").includes("Hotel Y")) errors.push(`sito ${l}: il testo da mandare non dice che non serve installare`);
}

// Le pagine costruite
const home = {en: html, it: read("it/index.html"), de: read("de/index.html")};
const LP = {en: "", it: "it/", de: "de/"};
const REFUND = {en: "refund fines", it: "non può rimborsare le multe", de: "keine Bußgelder erstatten"};
for (const l of ["en", "it", "de"]) {
  for (const id of ['id="fid"', 'id="fid-chk"', 'id="fid-hand"', 'id="send"', 'id="fid-checks"', 'id="fid-fine"', 'class="noinst"'])
    if (!home[l].includes(id)) errors.push(`home ${l}: manca ${id}`);
  if (!home[l].includes(`href="${l === "en" ? "" : "../"}${LP[l]}come-controlliamo/"`)) errors.push(`home ${l}: il link a «Come controlliamo i dati» non va alla pagina della lingua`);
  const checks = read(`${LP[l]}come-controlliamo/index.html`), fine = read(`${LP[l]}multa/index.html`);
  if ((checks.match(/<section class="card">/g) || []).length !== 5) errors.push(`come-controlliamo ${l}: attese 5 sezioni`);
  if (!fine.includes('id="no-refund"') || !fine.includes(REFUND[l])) errors.push(`multa ${l}: manca «GateLR non rimborsa multe»`);
  for (const u of ["normattiva.it/uri-res/N2Ls?urn:nir:stato:decreto.legislativo:1992-04-30;285~art203", "~art204bis", "prefettura.interno.gov.it"])
    if (!fine.includes(u)) errors.push(`multa ${l}: manca la fonte ${u}`);
  if (!/\b60\b/.test(fine) || !/\b30\b/.test(fine)) errors.push(`multa ${l}: mancano i termini dei ricorsi`);
}
const sitemap = read("sitemap.xml");
for (const u of ["come-controlliamo/", "it/multa/", "de/come-controlliamo/"]) if (!sitemap.includes(file.site + u)) errors.push(`sitemap: manca ${u}`);

if (errors.length) { for (const x of errors) console.log("::error::" + x); console.log(`check_fiducia: ${errors.length} errori`); process.exit(1); }
console.log(`check_fiducia: ${passed} casi comuni e le pagine, tutto a posto`);
