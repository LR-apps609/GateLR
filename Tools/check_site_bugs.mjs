// 2.0.1: i bug del sito trovati dai tester (test20, sito-2.0.json), uno per uno nel browser. Ogni prova riproduce i passi del
// tester (orologio finto, rete lenta o spenta, Photon finto) e controlla il risultato atteso; il nome è il codice del bug.
// Prima della correzione la prova fallisce, dopo passa. Con una cartella salva la foto di ogni prova (<codice>.png).
// Uso: python3 Tools/build_site.py && (cd web && python3 -m http.server 8000 &) && node Tools/check_site_bugs.mjs [url] [cartella] [codici…]
import { chromium } from "playwright";
const base = process.argv[2] || "http://localhost:8000/", out = process.argv[3] && process.argv[3] !== "-" ? process.argv[3] : null;
const only = new Set(process.argv.slice(4));
const b = await chromium.launch();
const results = [];

// ── aiuti ─────────────────────────────────────────────────────────────────────
// Un'ora italiana come istante («2026-11-12T23:50» d'inverno è +01:00, d'estate +02:00: lo dice chi scrive la prova)
async function open(path, {time, w = 390, h = 900, scheme = "light", locale = "it-IT", perms = [], geo, setup} = {}){
  const ctx = await b.newContext({viewport: {width: w, height: h}, colorScheme: scheme, locale, timezoneId: "Europe/Rome", permissions: perms, geolocation: geo});
  const p = await ctx.newPage();
  p.errs = []; p.on("pageerror", e => p.errs.push(e.message));
  if (time) await p.clock.install({time: new Date(time)});
  if (setup) await setup(p, ctx);
  await p.goto(base + path, {waitUntil: "load"});
  return p;
}
const S = p => p.evaluate(() => { const a = document.getElementById("answer"), $ = id => document.getElementById(id);
  return {s: a.dataset.s, title: $("a-title").textContent, where: $("a-where").textContent, why: $("a-why").textContent, until: $("a-until").textContent,
    out: $("hour-out").textContent, led: $("led-t").textContent, dim: $("led").dataset.dim, gates: $("a-gates").textContent, src: $("a-src").textContent,
    since: $("a-since").textContent, bg: getComputedStyle(a).backgroundColor, retry: !!a.querySelector(".retry"), track: $("hour").style.getPropertyValue("--track")}; });
const settle = async p => { await p.waitForFunction(() => { const a = document.getElementById("answer"); return a && a.dataset.s !== "wait"; }, null, {timeout: 30000}); await p.waitForTimeout(250); };
async function choose(p, name, lat, lon){
  await p.evaluate(([n, la, lo]) => window.gatelr.choose({name: n, lat: la, lon: lo}), [name, lat, lon]);
  await p.waitForFunction(n => document.getElementById("a-where").textContent.startsWith(n) && document.getElementById("answer").dataset.s !== "wait", name, {timeout: 30000});
  await p.waitForTimeout(250);
}
const setHour = (p, min) => p.$eval("#hour", (e, v) => { e.value = v; e.dispatchEvent(new Event("input", {bubbles: true})); }, min);
const pickDay = (p, label) => p.selectOption("#day", {label});
const green = c => { const [r, g, bl] = (c.match(/[\d.]+/g) || [0, 0, 0]).map(Number); return g > r + 40 && g > bl + 20; };
const dayShort = (y, m, d, loc) => new Intl.DateTimeFormat(loc, {weekday: "short", day: "numeric", timeZone: "UTC"}).format(new Date(Date.UTC(y, m - 1, d, 12)));
// un punto dentro una zona (la più piccola che lo contiene è quella): una griglia sul suo riquadro
const pointIn = (p, city, zoneId) => p.evaluate(async ([cid, zid]) => { const g = window.gatelr, c = g.cities.find(x => x.id === cid); await g.loadCity(c);
  const z = c.zones.find(x => x.id === zid), la = z.perimeter.map(q => q.lat), lo = z.perimeter.map(q => q.lon);
  for (let n = 4; n <= 40; n += 6) for (let i = 1; i < n; i++) for (let j = 1; j < n; j++){ const lat = Math.min(...la) + (Math.max(...la) - Math.min(...la)) * i / n, lon = Math.min(...lo) + (Math.max(...lo) - Math.min(...lo)) * j / n;
    const hit = g.zoneAt(lat, lon); if (hit && hit.zone.id === zid) return [lat, lon]; }
  return null; }, [city, zoneId]);
// Una rete finta per i file di una città: «hang» non risponde, «fail» cade, «slow» risponde dopo ms, «ok» normale
function cityNet(p, id){
  const ctl = {mode: "ok", ms: 0, held: []};
  ctl.ready = p.route(new RegExp(`/data/${id}\\.[0-9a-f]+\\.json`), async route => {
    if (ctl.mode === "hang") return ctl.held.push(route);
    if (ctl.mode === "fail") return route.abort();
    if (ctl.mode === "slow") await new Promise(z => setTimeout(z, ctl.ms));
    return route.continue();
  });
  ctl.set = async m => { ctl.mode = m; if (m !== "hang"){ const h = ctl.held.splice(0); for (const r of h) await (m === "fail" ? r.abort() : r.continue()).catch(() => {}); } };
  return ctl;
}
// Photon finto: i risultati dati (o la rete che cade)
function photon(p, feats){
  const ctl = {fail: false, feats};
  ctl.ready = p.route(/photon\.komoot\.io/, route => ctl.fail ? route.abort() : route.fulfill({contentType: "application/json", body: JSON.stringify({features: ctl.feats.map(([name, lat, lon, extra]) => ({
    geometry: {coordinates: [lon, lat]}, properties: Object.assign({name, country: "Italy", countrycode: "IT", city: ""}, extra || {})}))})}));
  return ctl;
}
async function shot(p, id, sel = "#check"){ if (!out) return; try { const l = p.locator(sel).first(); await l.screenshot({path: `${out}/${id}.png`, timeout: 5000}); } catch { await p.screenshot({path: `${out}/${id}.png`}).catch(() => {}); } }
// contrasto WCAG tra due colori rgb()/rgba()
const lum = c => { const [r, g, bl] = c.slice(0, 3).map(x => { x /= 255; return x <= .03928 ? x / 12.92 : ((x + .055) / 1.055) ** 2.4; }); return .2126 * r + .7152 * g + .0722 * bl; };
const ratio = (a, b2) => { const [x, y] = [lum(a), lum(b2)].sort((p, q) => q - p); return (x + .05) / (y + .05); };
// Le prove: [codice, funzione che rende un elenco di errori]
const T = [];
const test = (id, f) => T.push([id, f]);

// ── B04: il giorno scelto resta quello dopo la mezzanotte ─────────────────────────────
test("B04", async () => {
  const e = [];
  let p = await open("de/#firenze", {time: "2026-11-12T23:50:00+01:00", locale: "de-DE"}); await settle(p);
  await p.clock.runFor(25 * 60000);                                       // mezzanotte con la pagina aperta
  // il sabato 14 nel menu: «Sa., 14.» nel menu di prima della mezzanotte, «Morgen» in quello rifatto
  const has = await p.$$eval("#day option", (o, l) => o.some(x => x.textContent === l), dayShort(2026, 11, 14, "de-DE"));
  await pickDay(p, has ? dayShort(2026, 11, 14, "de-DE") : "Morgen"); await setHour(p, 600);
  let s = await S(p);
  const u0 = decodeURIComponent(await p.evaluate(() => window.gatelr.shareURL()) || "");
  if (!/t=2026-11-14T10:00/.test(u0)) e.push(`scelto sabato 14 alle 10 ma la domanda è ${u0.split("&t=")[1] || u0} («${s.out}»)`);
  if (s.s !== "no") e.push(`Duomo sabato 14 alle 10 (Settore A acceso): ${s.s}, atteso no`);
  const labels = await p.$$eval("#day option", o => o.map(x => x.textContent));
  if (new Set(labels).size !== labels.length) e.push(`giorni doppi nel menu: ${labels.join(", ")}`);
  if (labels[1] !== "Heute" || !labels.includes(dayShort(2026, 11, 15, "de-DE"))) e.push(`menu non rifatto a mezzanotte: ${labels.join(", ")}`);
  await shot(p, "B04"); await p.context().close();
  p = await open("#roma", {time: "2026-12-06T23:50:00+01:00", locale: "en-GB"}); await settle(p);
  await pickDay(p, "Tomorrow"); await setHour(p, 600);
  await p.clock.runFor(25 * 60000);
  s = await S(p);
  const u = decodeURIComponent(await p.evaluate(() => window.gatelr.shareURL()) || "");
  if (!/t=2026-12-07T10/.test(u)) e.push(`«Tomorrow 10:00» di domenica dopo la mezzanotte è ${u}`);
  if (green(s.bg)) e.push(`Pantheon lunedì 7 alle 10: verde (${s.s})`);
  const l2 = await p.$$eval("#day option", o => o.map(x => x.textContent));
  if (new Set(l2).size !== l2.length) e.push(`giorni doppi nel menu: ${l2.join(", ")}`);
  await p.context().close();
  return e;
});

// ── B17, B32: mentre arrivano i dati di un'altra città, nessun verde del posto di prima ──────────────
test("B17", async () => {
  const e = [];
  let net;
  const p = await open("it/#bologna", {time: "2026-11-10T21:00:00+01:00", setup: async pg => { net = cityNet(pg, "pisa"); await net.ready; }});
  await settle(p); await choose(p, "Via Prova, Bologna", 44.4965, 11.345);
  let s = await S(p); if (!green(s.bg)) e.push(`il posto di partenza non è verde (${s.s}): la prova non dice niente`);
  await net.set("hang");
  await p.click('#city-chips [data-city="pisa"]'); await p.waitForTimeout(200);
  await p.selectOption("#car", "3"); await p.waitForTimeout(100);
  s = await S(p);
  if (s.s !== "wait" || green(s.bg)) e.push(`cambiando veicolo mentre carica Pisa: ${s.s} «${s.where}»`);
  if (/Bologna/.test(s.where)) e.push(`mentre carica Pisa la scheda dice «${s.where}»`);
  await shot(p, "B17");
  await net.set("fail");
  await p.waitForFunction(() => !!document.querySelector("#answer .retry"), null, {timeout: 20000}).catch(() => e.push("niente «Riprova» dopo l'errore"));
  await p.clock.runFor(61000); await p.waitForTimeout(200);
  s = await S(p);
  if (!s.retry || s.s !== "wait" || green(s.bg)) e.push(`dopo l'errore e 61 s: ${s.s} «${s.where}» ${s.retry ? "con" : "senza"} «Riprova»`);
  await p.context().close();
  return e;
});
test("B32", async () => {
  const e = [];
  let net;
  const p = await open("it/#bologna", {time: "2026-11-10T21:00:00+01:00", setup: async pg => { net = cityNet(pg, "pisa"); await net.ready; }});
  await settle(p); await choose(p, "Via Prova, Bologna", 44.4965, 11.345);
  await net.set("hang");
  await p.click('#city-chips [data-city="pisa"]'); await p.waitForTimeout(300);
  const g = await p.evaluate(() => ({map: getComputedStyle(document.querySelector(".mapbox")).filter, track: document.getElementById("hour").style.getPropertyValue("--track"),
    label: document.getElementById("h-label").textContent, hours: document.getElementById("hours").textContent, pisa: document.querySelector('[data-city="pisa"]').getAttribute("aria-pressed"),
    bologna: (document.querySelector('[data-city="bologna"]') || {getAttribute: () => null}).getAttribute("aria-pressed"), q: document.getElementById("q").value}));
  if (!/grayscale/.test(g.map)) e.push("la mappa resta a colori mentre carica");
  if (g.track.trim() !== "var(--line)") e.push(`barra dell'ora ${g.track.slice(0, 60)}…`);
  if (/Bologna/.test(g.label) || g.hours.trim()) e.push(`orari di prima: «${g.label}» ${g.hours.slice(0, 40)}`);
  if (g.pisa !== "true" || g.bologna === "true") e.push(`pulsante premuto: pisa ${g.pisa}, bologna ${g.bologna}`);
  if (!/Pisa/.test(g.q)) e.push(`nel campo «${g.q}»`);
  await shot(p, "B32", ".tool");
  await p.context().close();
  return e;
});

// ── B58, B59, B99: primo caricamento appeso o fallito ───────────────────────────────
test("B58", async () => {
  const e = []; let net;
  const p = await open("it/#pisa", {time: "2026-11-10T12:00:00+01:00", setup: async pg => { net = cityNet(pg, "pisa"); net.mode = "hang"; await net.ready; }});
  await p.waitForTimeout(500); await p.clock.runFor(120000); await p.waitForTimeout(500);
  const s = await S(p);
  if (!s.retry) e.push(`dopo 120 s con la rete appesa: nessun «Riprova» (${s.s})`);
  await shot(p, "B58"); await p.context().close(); return e;
});
test("B59", async () => {
  const e = []; let net;
  const p = await open("it/#pisa", {time: "2026-11-10T12:00:00+01:00", setup: async pg => { net = cityNet(pg, "pisa"); net.mode = "fail"; await net.ready; }});
  await p.waitForFunction(() => !!document.querySelector("#answer .retry"), null, {timeout: 20000}).catch(() => e.push("niente «Riprova»"));
  await p.clock.runFor(61000); await p.waitForTimeout(300);
  const s = await S(p);
  if (!s.retry) e.push(`dopo 61 s il «Riprova» è sparito (${s.s}, «${s.title}»)`);
  await shot(p, "B59"); await p.context().close(); return e;
});
test("B99", async () => {
  const e = []; let net;
  const p = await open("it/#pisa", {setup: async pg => { net = cityNet(pg, "pisa"); net.mode = "fail"; await net.ready; }});
  await p.waitForFunction(() => !!document.querySelector("#answer .retry"), null, {timeout: 20000});
  await net.set("ok");
  await p.focus("#answer .retry"); await p.keyboard.press("Enter"); await settle(p);
  const f = await p.evaluate(() => document.activeElement && (document.activeElement.id || document.activeElement.tagName));
  if (f !== "answer") e.push(`dopo «Riprova» il fuoco è su ${f}`);
  await p.context().close(); return e;
});

// ── B18, B19: i giorni del cambio dell'ora ──────────────────────────────────────
test("B18", async () => {
  const e = [];
  let p = await open("it/#torino", {time: "2026-10-25T00:30:00+02:00"}); await settle(p);
  await pickDay(p, "Domani"); await setHour(p, 540);
  let s = await S(p), u = decodeURIComponent(await p.evaluate(() => window.gatelr.shareURL()) || "");
  if (!/t=2026-10-26T09:00/.test(u)) e.push(`«Domani · 9:00» il 25/10 alle 0:30 è ${u}`);
  if (s.s !== "no") e.push(`Piazza Castello lunedì 26 alle 9: ${s.s} («${s.out}»), atteso no`);
  await shot(p, "B18"); await p.context().close();
  p = await open("#roma", {time: "2027-03-27T23:30:00+01:00", locale: "en-GB"}); await settle(p);
  const labels = await p.$$eval("#day option", o => o.map(x => x.value + "=" + x.textContent));
  await pickDay(p, "Tomorrow"); await setHour(p, 60);
  u = decodeURIComponent(await p.evaluate(() => window.gatelr.shareURL()) || "");
  if (!/t=2027-03-28T01:00/.test(u)) e.push(`«Tomorrow 1:00» il 27/3 alle 23:30 è ${u} (menu: ${labels.join(", ")})`);
  await p.context().close();
  return e;
});
test("B19", async () => {
  const e = [];
  const p = await open("it/#napoli", {time: "2026-10-24T12:00:00+02:00"}); await settle(p);
  await pickDay(p, "Domani");
  for (const [min, txt] of [[60, "1:00"], [90, "1:30"], [150, "2:30"]]){
    await setHour(p, min); const s = await S(p);
    if (!s.out.endsWith(txt)) e.push(`cursore a ${txt}: «${s.out}»`);
    if (min === 90 && s.s !== "no") e.push(`San Gregorio Armeno domenica 25/10 alle 1:30 (acceso fino alle 2): ${s.s}`);
  }
  await setHour(p, 90); await shot(p, "B19"); await p.context().close();
  return e;
});

// ── B20: la barra dell'ora è la risposta del posto (tutte le sue zone) ─────────────────────
test("B20", async () => {
  const e = [];
  const VAR = {no: ["--no"], condizione: ["--cond"], nonSicuro: ["--cond"], si: ["--si"], nonAttiva: ["--si", "--state-off"], fuoriZTL: ["--grey"], fuoriCopertura: ["--line"]};
  const colourAt = (css, i) => { const pos = (i + .5) / 96 * 100; for (const m of css.matchAll(/var\((--[\w-]+)\)\s+([\d.]+)%\s+([\d.]+)%/g)) if (pos >= +m[2] && pos <= +m[3]) return m[1]; return css.trim().startsWith("var(") ? css.trim().slice(4, -1) : null; };
  for (const [name, path, lat, lon, time, day, car] of [
    ["Trastevere", "it/#roma", 41.89171, 12.46659, "2026-11-07T12:00:00+01:00", "Oggi", "0"],
    ["Torino Area Romana", "it/#torino", 45.07485, 7.68048, "2026-11-10T12:00:00+01:00", "Oggi", "0"],
    ["Parma diesel Euro 4", "it/#parma", 44.8015, 10.3280, "2026-11-07T12:00:00+01:00", "Domani", "2"]]){
    const p = await open(path, {time}); await settle(p); await choose(p, name, lat, lon);
    await p.selectOption("#car", car); await pickDay(p, day); await setHour(p, 0);
    const css = (await S(p)).track; let bad = 0, first = "";
    for (let i = 0; i < 96; i += 2){ await setHour(p, i * 15); const s = await S(p), c = colourAt(css, i);
      if (!VAR[s.s] || !VAR[s.s].includes(c)){ bad++; if (!first) first = `${Math.floor(i / 4)}:${String(i % 4 * 15).padStart(2, "0")} risposta ${s.s}, barra ${c}`; } }
    if (bad) e.push(`${name}: ${bad} mezz'ore con la barra diversa dalla risposta (${first})`);
    if (name === "Trastevere"){ await setHour(p, 1320); await shot(p, "B20"); }
    await p.context().close();
  }
  return e;
});

// ── B21: Diesel Euro 5 e Benzina Euro 4/5 ───────────────────────────────────
test("B21", async () => {
  const e = [];
  const p = await open("de/#milano", {time: "2026-11-11T10:00:00+01:00", locale: "de-DE"}); await settle(p);
  await choose(p, "Milano Centrale", 45.4860, 9.2040);
  const opts = await p.$$eval("#car option", o => o.map(x => [x.value, x.textContent]));
  for (const want of ["Diesel Euro 5", "Benzin Euro 4", "Benzin Euro 5"]) if (!opts.some(([, t]) => t === want)) e.push(`manca «${want}»`);
  const d5 = opts.find(([, t]) => t === "Diesel Euro 5");
  if (d5){ await p.selectOption("#car", d5[0]); const s = await S(p); if (s.s !== "no") e.push(`Diesel Euro 5 in Area B mercoledì 10:00: ${s.s}, atteso no`); }
  await shot(p, "B21"); await p.context().close(); return e;
});

// ── B46: pannello «ZTL ATTIVA · SEI ESENTE»; zona ambientale senza «ZTL» ─────────────────────
test("B46", async () => {
  const e = [];
  const p = await open("it/#milano", {time: "2026-11-10T10:00:00+01:00"}); await settle(p);
  await choose(p, "Navigli", 45.4515, 9.1745);
  let s = await S(p);
  if (["si", "nonAttiva"].includes(s.s) && !/ESENTE/.test(s.led)) e.push(`Area B, auto ammessa: pannello «${s.led}» sopra «${s.title}»`);
  if (/^ZTL/.test(s.led)) e.push(`Area B (zona ambientale) chiamata «${s.led}»`);
  await shot(p, "B46");
  await choose(p, "Piazzale Michelangelo", 43.7629, 11.2650);
  s = await S(p);
  if (/^ZTL/.test(s.led)) e.push(`Scudo Verde chiamato «${s.led}»`);
  await p.context().close(); return e;
});
// ── B47: il messaggio per l'hotel solo dove l'hotel può registrare la targa ───────────────
test("B47", async () => {
  const e = [];
  const p = await open("it/#milano", {time: "2026-11-10T10:00:00+01:00"}); await settle(p);
  await choose(p, "Duomo di Milano", 45.4642, 9.1900);
  const vis = () => p.evaluate(() => { const h = document.getElementById("copy").closest(".panel"), n = [...h.querySelectorAll(".note")].find(x => /Firenze|Florence|Florenz/.test(x.textContent));
    return {panel: h.offsetParent !== null && !/Qui gli hotel non possono/.test(h.textContent), note: !!n && n.offsetParent !== null}; });
  let v = await vis();
  if (v.panel) e.push("a Milano (Area C, hotel che non registrano la targa) c'è il messaggio per l'hotel");
  if (v.note) e.push("a Milano c'è la nota sulla procedura di Firenze");
  await choose(p, "Hotel de Russie", 41.9105, 12.4766);
  v = await vis(); if (v.panel) e.push("nel Tridente di Roma c'è il messaggio per l'hotel");
  // 1.20.4 (B08): piazza del Duomo è area pedonale (dati aperti del Comune): l'hotel in via de' Martelli, nel Settore A
  await choose(p, "Via de' Martelli", 43.7745, 11.2545);
  v = await vis(); if (!v.panel) e.push("a Firenze manca il messaggio per l'hotel");
  await p.context().close(); return e;
});

// ── 2.3 (decisione di Ledion del 09/11): l'hotel nella ZTL ─────────────────────────────
// Senza conferma rosso «Non entrare» con «Chiedi all'hotel di registrare la targa»; il pulsante «L'hotel ha registrato la
// targa» (giorni che coprono l'arrivo, veicolo scelto) dà «Puoi entrare» con «dal … al …»; con un altro veicolo torna rosso
test("HOTEL", async () => {
  const e = [];
  const p = await open("it/#firenze", {time: "2026-11-10T10:00:00+01:00"}); await settle(p);
  // 1.20.4 (B08): piazza del Duomo è area pedonale (dati aperti del Comune): l'hotel in via de' Martelli, nel Settore A
  await choose(p, "Hotel in via de' Martelli", 43.7745, 11.2545);
  const m = () => p.evaluate(() => ({s: document.getElementById("answer").dataset.s, motive: document.getElementById("a-motive").textContent,
    pressed: document.getElementById("h-reg").getAttribute("aria-pressed")}));
  let v = await m();
  if (v.s !== "no" || !/Chiedi all'hotel di registrare la targa/.test(v.motive)) e.push(`senza conferma: ${v.s} «${v.motive}»`);
  await p.click("#h-reg"); await p.waitForTimeout(300);
  v = await m();
  if (v.s !== "si" || !/L'hotel ha registrato la targa · dal 10 nov al 12 nov/.test(v.motive) || v.pressed !== "true") e.push(`con la conferma: ${v.s} «${v.motive}» ${v.pressed}`);
  // un altro veicolo: la conferma non vale
  await p.evaluate(() => { const s = document.getElementById("car"); if (s) { s.value = "2"; s.dispatchEvent(new Event("change", {bubbles: true})); } });
  await p.waitForTimeout(300);
  v = await m();
  if (v.s !== "no") e.push(`con un altro veicolo: ${v.s} «${v.motive}»`);
  if (p.errs.length) e.push("errori: " + p.errs.join("; "));
  await p.context().close(); return e;
});

// ── B48, B49, B50: contrasti nel tema scuro e chiaro ─────────────────────────────
test("B48", async () => {
  const e = [];
  for (const scheme of ["dark", "light"]){
    const p = await open("it/#milano", {time: "2026-11-10T10:00:00+01:00", scheme}); await settle(p);
    for (const [name, la, lo] of [["Navigli", 45.4515, 9.1745], ["Duomo di Firenze", 43.7731, 11.2560], ["Duomo di Milano", 45.4642, 9.1900]]){
      await choose(p, name, la, lo);
      const got = await p.evaluate(() => { const bgOf = el => { for (let x = el; x; x = x.parentElement){ const c = getComputedStyle(x).backgroundColor; if (c && !/rgba\(.*,\s*0\)$/.test(c) && c !== "transparent") return c; } return "rgb(255,255,255)"; };
        const sel = ["#a-title", "#a-motive", "#a-where", "#a-until", "#a-why", "#a-gates", "#a-since", "#a-next", "#copy", "#share", ".label", ".app .label", ".chip", "#hour-out", "#a-src", "footer"];
        const out = []; for (const s of sel) for (const x of document.querySelectorAll(s)){ if (!x.offsetParent || !x.textContent.trim()) continue; out.push([s, getComputedStyle(x).color, bgOf(x), getComputedStyle(x).opacity]); }
        return out; });
      for (const [sel, fg, bg, op] of got){ const n = c => (c.match(/[\d.]+/g) || []).map(Number); const r = ratio(n(fg), n(bg));
        if (r < 4.5 || +op < 1) e.push(`${scheme} ${name} ${sel}: ${r.toFixed(2)}:1${+op < 1 ? " (opacità " + op + ")" : ""}`); }
    }
    if (scheme === "dark") await shot(p, "B48");
    await p.context().close();
  }
  return [...new Set(e)].slice(0, 12);
});

// ── B51, B100, B115, B52: suggerimenti ──────────────────────────────────────
test("B51", async () => {
  const e = []; let ph;
  const p = await open("de/", {locale: "de-DE", setup: async pg => { ph = photon(pg, [["Hotel Mannelli", 43.7790, 11.2740, {osm_value: "hotel", city: "Florenz"}]]); await ph.ready; }}); await settle(p);
  await p.fill("#q", "hotel mannelli"); await p.waitForSelector("#suggest button[role=option] small:not(.skel)", {timeout: 10000}).catch(() => {});
  await p.waitForTimeout(1200);
  const lab = await p.$$eval("#suggest button[role=option]", o => o.map(x => x.textContent));
  const h = lab.find(x => /Mannelli/.test(x));
  if (!h) e.push("nessun suggerimento"); else if (/in der ZTL/.test(h)) e.push(`posto solo nello Scudo Verde segnato «${h}»`);
  await shot(p, "B51", ".card"); await p.context().close(); return e;
});
test("B100", async () => {
  const e = []; let ph, net;
  const p = await open("it/", {setup: async pg => { ph = photon(pg, [["Grand Hotel Duomo", 43.7230, 10.3966, {osm_value: "hotel", city: "Pisa"}]]); net = cityNet(pg, "pisa"); net.mode = "fail"; await ph.ready; await net.ready; }}); await settle(p);
  await p.fill("#q", "grand hotel"); await p.waitForTimeout(4500);
  const lab = await p.$$eval("#suggest button[role=option] small", o => o.map(x => x.textContent.trim()));
  if (!lab.length) e.push("nessun suggerimento"); else if (!lab[0] || lab[0] === " ") e.push("etichetta vuota con i dati della città che non arrivano");
  await p.context().close(); return e;
});
test("B115", async () => {
  const e = [];
  const p = await open("it/#firenze"); await settle(p);
  await p.fill("#q", "Duomo"); await p.waitForTimeout(300);
  const lab = await p.$$eval("#suggest button[role=option] span", o => o.map(x => x.textContent));
  if (lab.some(x => /Cathedral|station|airport/i.test(x))) e.push(`nomi inglesi su /it/: ${lab.join(" | ")}`);
  await p.fill("#q", "stazione"); await p.waitForTimeout(300);
  const l2 = await p.$$eval("#suggest button[role=option] span", o => o.map(x => x.textContent));
  if (!l2.some(x => /Stazione di Santa Maria Novella/.test(x))) e.push(`«stazione» non trova la Stazione di Santa Maria Novella: ${l2.join(" | ")}`);
  await shot(p, "B115", ".card"); await p.context().close(); return e;
});
test("B52", async () => {
  const e = []; let ph;
  const p = await open("it/#milano", {setup: async pg => { ph = photon(pg, []); ph.fail = true; await ph.ready; }}); await settle(p);
  await p.fill("#q", "Duomo"); await p.press("#q", "Enter"); await p.waitForTimeout(800); await settle(p);
  const s = await S(p);
  if (!/Milano|Milan/.test(s.where)) e.push(`a Milano «Duomo» + Invio porta a «${s.where}»`);
  await p.context().close(); return e;
});

// ── B53: la tabella degli orari ──────────────────────────────────────────────
test("B53", async () => {
  const e = [];
  const p = await open("it/#roma", {time: "2026-12-13T12:00:00+01:00"}); await settle(p);
  for (const [city, zone] of [["matera", "matera-sassi"], ["roma", "roma-trastevere-notte"], ["napoli", "napoli-morelli"], ["palermo", "palermo-centrale"]]){
    const pt = await pointIn(p, city, zone); if (!pt){ e.push(`nessun punto in ${zone}`); continue; }
    await choose(p, zone, pt[0], pt[1]);
    const rows = await p.$$eval("#hours tr", t => t.map(r => [...r.children].map(c => c.textContent)));
    const data = await p.evaluate(([c, z]) => window.gatelr.cities.find(x => x.id === c).zones.find(x => x.id === z), [city, zone]);
    const allDays = new Set(data.windows.flatMap(w => w.end <= w.start ? w.weekdays.flatMap(d => [d, d % 7 + 1]) : w.weekdays));
    const label = await p.$eval("#h-label", x => x.textContent);
    if (!label.includes((data.name_it || data.name).split("·")[0].trim())){ e.push(`${zone}: la scheda è «${label}»`); continue; }
    const NAMES = ["domenica", "lunedì", "martedì", "mercoledì", "giovedì", "venerdì", "sabato"];
    for (const [a, v] of rows){
      if (v === "libero" && a !== "Festivi"){ const d = a.split(", ").map(x => NAMES.indexOf(x) + 1).filter(x => x > 0 && allDays.has(x)); if (d.length) e.push(`${zone}: «${a} · libero» ma ci sono fasce in ${d.map(x => NAMES[x - 1]).join(", ")}`); }
      if (/notti/.test(a)){ const w = data.windows.find(x => x.end > x.start && a.includes(x.start === 600 ? "10:00" : "")); if (data.windows.every(x => x.end > x.start)) e.push(`${zone}: «${a}» ma nessuna fascia passa la mezzanotte`); }
    }
    if (zone === "matera-sassi") await shot(p, "B53", "#hours-p, .details .panel");
  }
  await p.context().close(); return e;
});

// ── B54, B55, B56, B106: accessibilità del modulo ─────────────────────────────────
test("B54", async () => {
  const e = [];
  const bad = /^(Language|Details|Destination or hotel|Time|Time of arrival|City|The LR family|GateLR home|City guides|Answers)$|^Map of/;
  for (const [path, locale] of [["it/", "it-IT"], ["de/", "de-DE"]]){
    const p = await open(path, {locale}); await settle(p);
    const names = await p.evaluate(() => [...document.querySelectorAll("[aria-label]")].map(x => x.getAttribute("aria-label")));
    const en = names.filter(n => bad.test(n));
    if (en.length) e.push(`${path}: nomi in inglese: ${en.join(" | ")}`);
    await p.context().close();
  }
  return e;
});
test("B55", async () => {
  const e = [];
  const p = await open("it/#firenze"); await settle(p);
  await p.focus("#hour"); await p.keyboard.press("ArrowRight");
  const g = await p.evaluate(() => ({vt: document.getElementById("hour").getAttribute("aria-valuetext"), out: document.getElementById("hour-out").textContent}));
  if (g.vt !== g.out) e.push(`aria-valuetext «${g.vt}», etichetta «${g.out}»`);
  await choose(p, "Piazza delle Erbe, Mantova", 45.1597, 10.7967);
  const live = await p.evaluate(() => document.querySelector("[aria-live]").textContent);
  if (!/non ufficiale/i.test(live)) e.push(`l'annuncio non dice «fonte non ufficiale»: «${live.trim()}»`);
  await p.context().close(); return e;
});
test("B56", async () => {
  const e = [];
  const p = await open("it/#firenze"); await settle(p);
  if (await p.getAttribute("#q", "role") !== "combobox") e.push("il campo non è un combobox");
  await p.fill("#q", "Piazza"); await p.waitForTimeout(200); await p.press("#q", "ArrowDown"); await p.press("#q", "ArrowDown"); await p.press("#q", "Escape");
  const ad = await p.getAttribute("#q", "aria-activedescendant");
  if (ad) e.push(`dopo Esc aria-activedescendant="${ad}"`);
  await p.context().close(); return e;
});
test("B106", async () => {
  const e = [];
  const p = await open("it/#firenze"); await settle(p);
  const g = await p.evaluate(() => ({map: document.getElementById("map").getAttribute("aria-label"), mark: document.getElementById("a-mark").getAttribute("aria-hidden")}));
  if (/Tocca|Tap|Tippe/.test(g.map)) e.push(`la mappa invita al tocco: «${g.map}»`);
  if (g.mark !== "true") e.push("l'icona della risposta non è nascosta");
  await p.context().close(); return e;
});

// ── B57, B113: la mia posizione ─────────────────────────────────────────────
test("B57", async () => {
  const e = [];
  const p = await open("it/#salerno"); await settle(p);
  const before = await S(p);
  await p.click("#locate"); await p.waitForTimeout(1500);
  const after = await S(p), msg = await p.evaluate(() => (document.querySelector("[role=status]#loc-msg") || {}).textContent || "");
  if (after.why !== before.why) e.push(`la spiegazione della risposta è cambiata: «${after.why}»`);
  if (!/Posizione non disponibile/.test(msg)) e.push("nessun messaggio annunciato (role=status) per la posizione negata");
  await shot(p, "B57", ".card"); await p.context().close(); return e;
});
test("B113", async () => {
  const e = [];
  const p = await open("it/#firenze", {perms: ["geolocation"], geo: {latitude: 43.8066, longitude: 11.2932}}); await settle(p);
  await p.click("#locate"); await p.waitForTimeout(1500); await settle(p);
  const s = await S(p);
  if (/Usa la mia posizione/.test(s.where)) e.push(`il posto si chiama «${s.where}»`);
  const p2 = await open("#p=43.933,10.917&n=Pistoia", {locale: "en-GB"}); await settle(p2);
  const l = await S(p2); if (/ZONA NON COPERTA/.test(l.led) && !(await p2.$eval("#ledbox", x => x.hidden))) e.push("«ZONA NON COPERTA» in italiano sulla pagina inglese");
  await p.context().close(); await p2.context().close(); return e;
});

// ── B60: la ricerca dopo un errore ──────────────────────────────────────────
test("B60", async () => {
  const e = []; let ph;
  const p = await open("it/#bologna", {setup: async pg => { ph = photon(pg, [["Grand Hotel Majestic", 44.4970, 11.3420, {osm_value: "hotel", city: "Bologna"}]]); ph.fail = true; await ph.ready; }}); await settle(p);
  await p.fill("#q", "hotel bologna"); await p.waitForTimeout(1500);
  if (!(await p.$("#suggest .fail"))) e.push("nessun «Riprova» con la rete giù");
  ph.fail = false;
  await p.fill("#q", "grand hotel"); await p.waitForTimeout(1500);
  const g = await p.evaluate(() => ({open: !document.getElementById("suggest").hidden, n: document.querySelectorAll("#suggest button[role=option]").length, fail: !!document.querySelector("#suggest .fail")}));
  if (!g.open || (!g.n && !g.fail)) e.push("con la rete tornata la ricerca resta muta (né risultati né «Riprova»)");
  await p.context().close(); return e;
});

// ── B61: il pannello del varco dopo un cambio veloce di città ───────────────────────
test("B61", async () => {
  const e = []; let net;
  const p = await open("it/#firenze", {time: "2026-11-10T22:00:00+01:00", setup: async pg => { net = cityNet(pg, "bologna"); net.mode = "slow"; net.ms = 60; await net.ready; }}); await settle(p);
  await choose(p, "Palazzo Vecchio", 43.7693, 11.2563);
  await choose(p, "Via Rizzoli, Bologna", 44.4940, 11.3450); await p.waitForTimeout(1500);
  const s = await S(p);
  if (s.led === "VARCO" || s.dim === "true") e.push(`pannello «${s.led}» spento sotto «${s.title}»`);
  await p.context().close(); return e;
});

// ── B62: la fonte non ufficiale ─────────────────────────────────────────────
test("B62", async () => {
  const e = [];
  const p = await open("it/#salerno"); await settle(p);
  const s = await S(p), href = await p.$$eval("#a-src a", a => a.map(x => x.textContent + "=" + x.href));
  if (/Comune di Salerno/.test(s.src) || href.some(h => /ufficiale/.test(h) && /accessibilitacentristorici/.test(h))) e.push(`«${s.src}» → ${href.join(" ")}`);
  await shot(p, "B62", ".after"); await p.context().close(); return e;
});

// ── B89, B90, B96, B114, B111, B112: testi e schede ───────────────────────────────
test("B89", async () => {
  const e = [];
  const p = await open("de/#firenze", {locale: "de-DE"}); await settle(p);
  await p.click("#q"); await p.keyboard.type("Hotel Brunel");
  const v = await p.inputValue("#q");
  if (v !== "Hotel Brunel") e.push(`nel campo «${v}»`);
  await p.context().close(); return e;
});
test("B90", async () => {
  const e = [];
  const p = await open("de/#firenze", {time: "2026-12-04T12:00:00+01:00", locale: "de-DE"}); await settle(p);
  await pickDay(p, dayShort(2026, 12, 8, "de-DE")); await setHour(p, 600);
  const s = await S(p);
  if (/Heute ist Feiertag/.test(s.why)) e.push(`per l'8 dicembre: «${s.why.slice(0, 60)}…»`);
  await p.context().close(); return e;
});
test("B96", async () => {
  const e = [];
  const p = await open("it/#milano", {time: "2026-11-10T10:00:00+01:00"}); await settle(p);
  await choose(p, "Via Manzoni", 45.47, 9.1925);
  const s = await S(p); if (/Attivo|Non attivo/.test(s.until) || !/Attiva fino/.test(s.until)) e.push(`«${s.until}»`);
  await p.context().close(); return e;
});
test("B114", async () => {
  const e = [];
  const p = await open("it/#torino", {time: "2026-11-08T11:00:00+01:00"}); await settle(p);
  const s = await S(p);
  if (/^Spenti dalle/.test(s.since)) e.push(`domenica: «${s.since}»`);
  await shot(p, "B114", "#answer"); await p.context().close(); return e;
});
test("B111", async () => {
  const e = [];
  for (const [n, la, lo] of [["Mestre", 45.4906, 12.2422], ["Pistoia", 43.933, 10.917]]){
    const p = await open(`it/#p=${la},${lo}&n=${n}`); await settle(p);
    const g = await p.evaluate(() => ({src: document.getElementById("a-src").textContent, draft: !document.getElementById("a-draft").hidden,
      hours: document.getElementById("hours").offsetParent !== null && document.getElementById("hours").textContent.trim() !== "", hotel: document.getElementById("copy").offsetParent !== null}));
    const s = await S(p);
    if (s.s !== "fuoriCopertura") e.push(`${n}: ${s.s}`);
    if (g.src.trim() || g.draft || g.hours || g.hotel) e.push(`${n}: ${[g.src.trim() && "fonte «" + g.src.slice(0, 40) + "»", g.draft && "bozza", g.hours && "orari", g.hotel && "hotel"].filter(Boolean).join(", ")}`);
    if (n === "Pistoia") await shot(p, "B111", "main");
    await p.context().close();
  }
  return e;
});
test("B112", async () => {
  const e = [];
  const p = await open("it/#p=44.50337,11.34431&n=Via%20Galliera"); await settle(p);
  const h = await p.$eval("#hours", x => x.textContent);
  if (/€/.test(h) || !/chiusa/.test(h)) e.push(`orari dell'area pedonale: «${h}»`);
  await p.context().close(); return e;
});

// ── B91, B101, B102, B103, B104: disposizione e fuoco ──────────────────────────────
test("B91", async () => {
  const e = [];
  for (const path of ["", "it/", "de/"]){ const p = await open(path, {w: 320}); await settle(p);
    const sw = await p.evaluate(() => document.documentElement.scrollWidth); if (sw > 320) e.push(`${path || "/"}: larga ${sw} px`); await p.context().close(); }
  return e;
});
test("B101", async () => {
  const e = [];
  const p = await open("it/#salerno"); await settle(p);
  const g = await p.evaluate(() => { const a = document.querySelector("#answer a"); if (!a) return null; a.focus(); const cs = getComputedStyle(a), bg = getComputedStyle(document.getElementById("answer")).backgroundColor; return {oc: cs.outlineColor, bg}; });
  if (g){ const n = c => (c.match(/[\d.]+/g) || []).map(Number); const r = ratio(n(g.oc), n(g.bg)); if (r < 3) e.push(`anello del fuoco ${r.toFixed(2)}:1 sul blocco`); }
  await p.context().close(); return e;
});
test("B102", async () => {
  const e = [];
  const p = await open("it/#firenze"); await settle(p);
  await p.focus("#q");
  const g = await p.evaluate(() => { const s = getComputedStyle(document.getElementById("search")); return s.outlineStyle + " " + s.boxShadow; });
  if (/^none none$/.test(g)) e.push("il campo con il fuoco non mostra un indicatore");
  await p.context().close(); return e;
});
test("B103", async () => {
  const e = [];
  const p = await open("#firenze", {w: 640, h: 400, locale: "en-GB"}); await settle(p);
  const chips = await p.$$("#tries .chip");
  await chips[0].focus();
  for (let i = 0; i < chips.length - 1; i++) await p.keyboard.press("Tab");
  const g = await p.evaluate(() => { const a = document.activeElement, r = a.getBoundingClientRect(), c = a.closest(".cscroll").getBoundingClientRect(); return {id: a.id || a.textContent, l: r.left, r: r.right, cl: c.left, cr: c.right}; });
  if (g.r > g.cr + 1 || g.l < g.cl - 1) e.push(`«${g.id}» con il fuoco tagliato (${Math.round(g.l)}–${Math.round(g.r)} in ${Math.round(g.cl)}–${Math.round(g.cr)})`);
  await shot(p, "B103", "#tries"); await p.context().close(); return e;
});
test("B104", async () => {
  const e = [];
  for (const path of ["", "it/", "de/"]){ const p = await open(path); const g = await p.evaluate(() => ({main: document.querySelectorAll("main").length, skip: !!document.querySelector("a.skip[href]")}));
    if (g.main !== 1 || !g.skip) e.push(`${path || "/"}: main ${g.main}, skip ${g.skip}`); await p.context().close(); }
  return e;
});

// ── B92: il tasto della lingua ────────────────────────────────────────────────
test("B92", async () => {
  const e = [];
  const p = await open("de/#firenze", {locale: "de-DE"}); await settle(p);
  await p.click('.langs button[data-lang="en"]'); await p.waitForTimeout(800); await p.reload(); await settle(p);
  const g = await p.evaluate(() => ({lang: document.documentElement.lang, path: location.pathname}));
  if (g.lang !== "en") e.push(`dopo EN e ricarica la pagina è in «${g.lang}» (${g.path})`);
  await p.context().close(); return e;
});

// ── B107: le etichette della mappa disegnata ───────────────────────────────────────
test("B107", async () => {
  const e = [];
  for (const c of ["salerno", "mantova", "cagliari", "firenze"]){
    const p = await open(`it/#${c}`, {setup: async pg => { await pg.route(/unpkg\.com/, r => r.abort()); }}); await settle(p);
    const t = await p.$$eval("#map text", x => x.map(y => y.textContent));
    const bad = t.filter(x => /^(town|centre|center|Sundays|Speri|Alto|Basso|nights?)$/i.test(x));
    if (bad.length) e.push(`${c}: ${bad.join(", ")}`);
    if (c === "salerno") await shot(p, "B107", "#mapbox");
    await p.context().close();
  }
  return e;
});

// ── B93, B94, B95, B97, B105, B109: pagine e testi (senza browser) ────────────────────
const get = async u => { const r = await fetch(base + u); return r.ok ? r.text() : ""; };
test("B93", async () => {
  const e = [], de = await get("de/firenze/");
  if (/\b1 Kamera-Einfahrten/.test(de)) e.push("«1 Kamera-Einfahrten» su /de/firenze/");
  const p = await open("de/#salerno", {locale: "de-DE"}); await settle(p);
  const s = await S(p); if (/rund um die Uhr/.test(s.until) && /komm später/.test(s.why)) e.push(`zona sempre attiva: «${s.why}»`);
  await p.context().close(); return e;
});
test("B94", async () => {
  const e = [];
  for (const u of ["it/milano/", "de/firenze/", "it/arezzo/"]){ const h = await get(u);
    if (/City of (Milan|Florence|Arezzo)/.test(h)) e.push(`${u}: «City of …»`);
    if (/\.\.\s/.test(h.replace(/<[^>]+>/g, ""))) e.push(`${u}: doppio punto «..»`); }
  return e;
});
test("B95", async () => {
  const e = [];
  for (const u of ["it/milano/", "de/milano/"]){ const h = (await get(u)).replace(/<[^>]+>/g, " "); if (/€\s?\d/.test(h)) e.push(`${u}: prezzi «€7.50» (${(h.match(/€\s?[\d.,–-]+/) || [""])[0]})`); }
  const p = await open("it/#milano", {time: "2026-11-10T10:00:00+01:00"}); await settle(p);
  const g = await p.evaluate(() => document.getElementById("hours").textContent + " " + document.getElementById("fine").textContent);
  if (/€\s?\d/.test(g)) e.push(`/it/: «${(g.match(/€\s?[\d.,–-]+/) || [""])[0]}»`);
  await p.context().close(); return e;
});
test("B97", async () => {
  const h = await get("it/milano/");
  return /puoi entrare con il ticket giornaliero\.(?! Le auto)/.test(h) ? ["FAQ dell'hotel a Milano senza i divieti Euro"] : [];
});
test("B105", async () => {
  const h = await get("privacy/"), e = [];
  if (!/<section id="en" lang="en"/.test(h)) e.push("parte inglese senza lang=en");
  if (!/unpkg/.test(h)) e.push("unpkg.com non citato");
  if (/1\.19\.4/.test(h)) e.push("versione 1.19.4");
  return e;
});
test("B109", async () => {
  const e = [], sm = await get("sitemap.xml");
  for (const u of ["support/", "app/", "privacy/"]){ const h = await get(u);
    if (!/name="description"/.test(h)) e.push(`${u}: niente description`);
    if (!/rel="canonical"/.test(h)) e.push(`${u}: niente canonical`); }
  for (const u of ["privacy/", "support/"]) if (!sm.includes(u)) e.push(`${u} fuori dalla sitemap`);
  return e;
});

// ── esecuzione ───────────────────────────────────────────────────────────────
for (const [id, f] of T){
  if (only.size && !only.has(id)) continue;
  let e;
  try { e = await f(); } catch (x) { e = ["la prova non è andata a fine: " + String(x.message || x).split("\n")[0]]; }
  results.push([id, e]);
  console.log(`${e.length ? "✗" : "✓"} ${id}${e.length ? ": " + e.join("; ") : ""}`);
}
await b.close();
const bad = results.filter(([, e]) => e.length);
for (const [id, e] of bad) console.log(`::error::check_site_bugs ${id}: ${e.join("; ").slice(0, 400)}`);
console.log(`${results.length} prove dei bug del sito: ${results.length - bad.length} passate, ${bad.length} no`);
process.exit(bad.length ? 1 : 0);
