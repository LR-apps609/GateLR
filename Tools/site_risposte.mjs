// 2.0: le sette risposte del sito nel browser, aperte dal «link di una risposta» (tavola X-SitoLink). Per ogni stato controlla
// forma + parola + colore (data-s, titolo, forma disegnata, fondo del blocco), che il blocco non sia mai verde fuori dai casi
// verdi, che il contrasto del titolo sia almeno 4,5:1 e che il link copiato riapra la stessa domanda senza la targa.
// Chiaro e scuro, 390 e 1280 px; con una cartella salva le foto del blocco.
// Uso: python3 Tools/build_site.py && (cd web && python3 -m http.server 8000 &) && node Tools/site_risposte.mjs [url] [cartella]
import { chromium } from "playwright";
const base = process.argv[2] || "http://localhost:8000/", out = process.argv[3];
const CASI = [  // stato atteso, posto, ora italiana, veicolo (come nel link)
  ["no", "Palazzo Vecchio", 43.7693, 11.2563, "2026-11-10T10:00", "petrol-6"],
  ["si", "Via Manzoni", 45.47, 9.1925, "2026-11-10T10:00", "electric-6"],
  ["nonAttiva", "Palazzo Vecchio", 43.7693, 11.2563, "2026-11-10T23:00", "petrol-6"],
  ["condizione", "Via Manzoni", 45.47, 9.1925, "2026-11-10T10:00", "petrol-6"],
  ["nonSicuro", "Bastione di Saint Remy", 39.216, 9.1163, "2026-11-10T12:00", "petrol-6"],
  ["fuoriZTL", "Bologna Centrale", 44.5058, 11.3427, "2026-11-10T10:00", "petrol-6"],
  ["fuoriCopertura", "Pistoia", 43.933, 10.917, "2026-11-10T23:00", "electric-6"],
  ["no", "Via Galliera", 44.50337, 11.34431, "2026-11-10T23:00", "electric-6"],   // area pedonale
];
const VERDE = new Set(["si", "nonAttiva"]);   // «ZTL non attiva» è verde oggi (token --state-off)
const lum = c => { const [r, g, b] = c.match(/[\d.]+/g).slice(0, 3).map(x => { x /= 255; return x <= .03928 ? x / 12.92 : ((x + .055) / 1.055) ** 2.4; }); return .2126 * r + .7152 * g + .0722 * b; };
const ratio = (a, b) => { const [x, y] = [lum(a), lum(b)].sort((p, q) => q - p); return (x + .05) / (y + .05); };
const green = c => { const [r, g, b] = c.match(/[\d.]+/g).map(Number); return g > r + 40 && g > b + 20; };
const errors = [];
const b = await chromium.launch();
for (const scheme of ["light", "dark"]) for (const w of [390, 1280]) {
  const ctx = await b.newContext({viewport: {width: w, height: 900}, colorScheme: scheme, locale: "it-IT", timezoneId: "Europe/Rome", permissions: ["clipboard-read", "clipboard-write"]});
  const p = await ctx.newPage();
  p.on("pageerror", e => errors.push(`errore nella pagina: ${e.message}`));
  // 2.0.1: l'orologio fisso (venerdì 6 novembre 2026), così le date dei casi restano «martedì 10» qualunque giorno giri la prova
  await p.clock.install({time: new Date("2026-11-06T12:00:00+01:00")});
  for (const [want, name, lat, lon, t, v] of CASI) {
    const hash = "#" + new URLSearchParams([["p", `${lat},${lon}`], ["n", name], ["t", t], ["v", v]]).toString();
    await p.goto(base + "it/" + hash, {waitUntil: "load"});
    await p.waitForFunction(() => { const a = document.getElementById("answer"); return a && a.dataset.s !== "wait"; }, null, {timeout: 30000});
    await p.waitForTimeout(700);   // la fine del passaggio di colore del blocco
    const got = await p.evaluate(() => { const a = document.getElementById("answer"), h = document.getElementById("a-title"), cs = getComputedStyle(a);
      return {s: a.dataset.s, title: h.textContent, shape: document.getElementById("a-mark").innerHTML.length, bg: cs.backgroundColor, fg: getComputedStyle(h).color,
        border: cs.borderTopStyle, shared: !document.getElementById("shared").hidden, out: document.getElementById("hour-out").textContent, car: document.getElementById("car").selectedOptions[0].textContent}; });
    const tag = `${scheme} ${w}px ${name} ${t}`;
    if (got.s !== want) errors.push(`${tag}: stato ${got.s}, atteso ${want}`);
    if (!got.title.trim() || !got.shape) errors.push(`${tag}: manca la parola o la forma`);
    if (!VERDE.has(got.s) && green(got.bg)) errors.push(`${tag}: ${got.s} verde`);
    if (got.s === "fuoriCopertura" && got.border !== "dashed") errors.push(`${tag}: fuori copertura senza contorno tratteggiato`);
    const bg = got.bg === "rgba(0, 0, 0, 0)" ? await p.evaluate(() => getComputedStyle(document.querySelector(".card")).backgroundColor) : got.bg;
    if (ratio(got.fg, bg) < 4.5) errors.push(`${tag}: contrasto del titolo ${ratio(got.fg, bg).toFixed(2)}:1`);
    if (!got.shared) errors.push(`${tag}: manca la nota «Risposta condivisa»`);
    if (!/10|mar/.test(got.out) || !got.out.includes(t.slice(11))) errors.push(`${tag}: ora del link non ripresa (${got.out})`);
    if (out) await p.locator("#answer").screenshot({path: `${out}/risposta-${want}-${name.replace(/\W+/g, "-")}-${w}-${scheme}.png`});
  }
  // il link copiato: stessa domanda, niente targa (anche se scritta nel messaggio per l'hotel)
  // (il riquadro dell'hotel è nascosto dove l'hotel non può registrare la targa, come nell'area pedonale: si scrive lo stesso)
  await p.evaluate(() => { for (const [id, v] of [["h-plate", "AB123CD"], ["h-name", "Hotel Prova"]]){ const x = document.getElementById(id); x.value = v; x.dispatchEvent(new Event("input", {bubbles: true})); } });
  await p.click("#share");
  const url = await p.inputValue("#share-url");
  if (/AB123CD|Hotel%20Prova|Hotel\+Prova/i.test(url)) errors.push(`${scheme} ${w}px: il link porta la targa o l'hotel: ${url}`);
  const [, , lat, lon, t, v] = CASI[CASI.length - 1];
  const q = new URLSearchParams(url.split("#")[1]);
  if (q.get("p") !== `${lat.toFixed(5)},${lon.toFixed(5)}` || q.get("t") !== t || q.get("v") !== v) errors.push(`${scheme} ${w}px: link copiato diverso dalla domanda: ${url}`);
  await ctx.close();
}
await b.close();
for (const x of errors) console.log("::error::site_risposte: " + x);
console.log(`${CASI.length} risposte × 4 viste: ${errors.length} errori`);
process.exit(errors.length ? 1 : 0);
