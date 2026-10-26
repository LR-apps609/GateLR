import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import { parseItalianPlate } from "../src/plate.js";
import { mapFuel, mapEuro, mapDate } from "../src/providers/provider.js";
import { createInfoTarga, mapInfoTarga } from "../src/providers/infotarga.js";
import { staleKeys } from "../src/limits.js";

test("formati di targa italiani", () => {
  assert.deepEqual(parseItalianPlate("AB123CD"), { plate: "AB123CD", kind: "car" });
  assert.deepEqual(parseItalianPlate("gh 456 jk"), { plate: "GH456JK", kind: "car" });
  assert.deepEqual(parseItalianPlate("AB-12345"), { plate: "AB12345", kind: "motorcycle" });
  for (const bad of ["AI123CD", "AB123CO", "QU123AA", "A1234BC", "ROMA12345", "", undefined]) {
    assert.equal(parseItalianPlate(bad), null, String(bad));
  }
});

test("conversioni dei campi", () => {
  assert.equal(mapFuel("BENZINA"), "petrol");
  assert.equal(mapFuel("Gasolio"), "diesel");
  assert.equal(mapFuel("Ibrido benzina/elettrico"), "hybrid");
  assert.equal(mapFuel("ELETTRICO"), "electric");
  assert.equal(mapFuel("Benzina/GPL"), "lpg");
  assert.equal(mapFuel("Metano"), "lpg");
  assert.equal(mapFuel("idrogeno"), null);
  assert.equal(mapEuro("EURO 6D-TEMP"), 6);
  assert.equal(mapEuro("Euro4"), 4);
  assert.equal(mapEuro(5), 5);
  assert.equal(mapEuro("non disponibile"), null);
  assert.equal(mapDate("14/03/2019"), "2019-03-14");
  assert.equal(mapDate("2019-03-14T00:00:00Z"), "2019-03-14");
  assert.equal(mapDate(2019), "2019");
  assert.equal(mapDate("ieri"), null);
});

test("InfoTarga (ipotesi da verificare): risposta finta → campi dell'app", () => {
  const out = mapInfoTarga({
    data: {
      details: { make: "FIAT", model: "Panda 1.2", fuel: "BENZINA", registrationDate: "14/03/2019" },
      emissions: { euroClass: "EURO 6" },
    },
  });
  assert.deepEqual(out, { make: "FIAT", model: "Panda 1.2", fuel: "petrol", firstRegistration: "2019-03-14", euroClass: 6 });
  assert.equal(mapInfoTarga({ data: {} }), null);
});

test("InfoTarga senza chiave o con l'indirizzo segnaposto: non chiama la rete", async () => {
  let fetched = 0;
  const fetchImpl = async () => { fetched += 1; };
  for (const cfg of [{ apiKey: "", baseUrl: "https://api.example" }, { apiKey: "k", baseUrl: "https://REPLACE-ME.infotarga.example/v3" }]) {
    const p = createInfoTarga({ ...cfg, fetchImpl });
    await assert.rejects(p.lookup("AB123CD"), (e) => e.code === "unavailable");
  }
  assert.equal(fetched, 0);
});

test("InfoTarga: stati HTTP del fornitore", async () => {
  const make = (status, body) => createInfoTarga({
    apiKey: "test-key", baseUrl: "https://api.example/v3",
    fetchImpl: async () => new Response(body ? JSON.stringify(body) : null, { status }),
  });
  assert.equal(await make(404).lookup("AB123CD"), null);
  await assert.rejects(make(429).lookup("AB123CD"), (e) => e.code === "rate_limited");
  await assert.rejects(make(401).lookup("AB123CD"), (e) => e.code === "auth");
  await assert.rejects(make(500).lookup("AB123CD"), (e) => e.code === "unavailable");
  const ok = await make(200, { details: { make: "VW", model: "Golf", fuel: "Diesel" }, emissions: { euroClass: "Euro 5" } })
    .lookup("AB123CD");
  assert.deepEqual(ok, { make: "VW", model: "Golf", fuel: "diesel", firstRegistration: null, euroClass: 5 });
});

test("pulizia dei contatori: restano solo oggi e il mese corrente", () => {
  const now = Date.UTC(2026, 9, 26, 10);
  const keys = ["g:d:2026-10-26", "g:d:2026-10-25", "g:m:2026-10", "g:m:2026-09", "dv:d:2026-10-25:abc", "ip:d:2026-10-26:x", "g:last"];
  assert.deepEqual(staleKeys(keys, now), ["g:d:2026-10-25", "g:m:2026-09", "dv:d:2026-10-25:abc"]);
});

test("nessun console.* nel codice del server (le targhe non vanno nei log)", () => {
  const dir = new URL("../src/", import.meta.url);
  const files = [];
  const walk = (u) => {
    for (const e of readdirSync(u, { withFileTypes: true })) {
      if (e.isDirectory()) walk(new URL(`${e.name}/`, u));
      else if (e.name.endsWith(".js")) files.push(new URL(e.name, u));
    }
  };
  walk(dir);
  for (const f of files) {
    const code = readFileSync(f, "utf8").replace(/\/\/.*$/gm, "");
    assert.ok(!/\bconsole\s*\./.test(code), f.pathname);
  }
});
