// Foto del sito con la mappa vera (gira su GitHub Actions, dove le mappe si caricano)
import { chromium } from "playwright";
const base = process.argv[2] || "http://localhost:8000/";
const pages = [["home", ""], ["siena", "siena/"], ["roma", "it/roma/"], ["milano", "milano/"], ["firenze", "firenze/"]];
const b = await chromium.launch();
for (const [w, h, tag] of [[1280, 900, "desktop"], [390, 844, "phone"]]) {
  const p = await b.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 1 });
  p.on("console", m => { if (m.type() === "error") console.log("console:", tag, m.text().slice(0, 200)); });
  for (const [name, path] of pages) {
    await p.goto(base + path, { waitUntil: "load" });
    const map = await p.$("#mapwrap, #mapbox");
    if (map) await map.scrollIntoViewIfNeeded();
    await p.waitForTimeout(9000);
    const on = await p.evaluate(() => !!document.querySelector(".mapwrap.on, .mapbox.real"));
    console.log(tag, name, "mappa vera:", on);
    if (map) await map.screenshot({ path: `shots/${tag}-${name}-map.png` });
    await p.screenshot({ path: `shots/${tag}-${name}.png`, fullPage: false });
  }
}
await b.close();
