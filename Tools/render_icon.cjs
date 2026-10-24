// Disegna tutte le icone di GateLR dal logo vettoriale Resources/Branding/gatelr-icon.svg (Playwright/Chromium).
// Uso: node Tools/render_icon.cjs   (poi python3 Tools/make_icon.py per le varianti)
const { chromium } = require("playwright");
const { readFileSync } = require("fs");
const svg = readFileSync("Resources/Branding/gatelr-icon.svg", "utf8");
(async () => {
const b = await chromium.launch();
async function shot(size, rounded, out) {
  const p = await b.newPage({ viewport: { width: size, height: size } });
  const r = rounded ? Math.round(size * 0.2237) : 0;
  await p.setContent(`<html><body style="margin:0;background:transparent"><div style="width:${size}px;height:${size}px;border-radius:${r}px;overflow:hidden">${svg.replace(/width="1024" height="1024"/, `width="${size}" height="${size}"`)}</div></body></html>`);
  await p.screenshot({ path: out, omitBackground: true });
  await p.close();
}
await shot(1024, false, "Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png");
await shot(240, true, "Resources/Assets.xcassets/LaunchLogo.imageset/LaunchLogo@2x.png");
await shot(360, true, "Resources/Assets.xcassets/LaunchLogo.imageset/LaunchLogo@3x.png");
await shot(512, true, "web/icon.png");
for (const [d, s] of [["mdpi", 48], ["hdpi", 72], ["xhdpi", 96], ["xxhdpi", 144], ["xxxhdpi", 192]])
  await shot(s, true, `android/app/src/main/res/mipmap-${d}/ic_launcher.png`);
await b.close();
})();
