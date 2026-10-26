import { test } from "node:test";
import assert from "node:assert/strict";
import { handle } from "../src/handler.js";
import { ENABLED_ENV, memoryLimiter, fakeProvider, request } from "./helpers.js";

function setup(envOverrides = {}, provider = fakeProvider(), start = Date.UTC(2026, 9, 26, 10)) {
  const env = { ...ENABLED_ENV, ...envOverrides };
  let t = start;
  const clock = () => t;
  const limiter = memoryLimiter(env, clock);
  const call = (req) => handle(req, env, { provider: () => provider, limiter, now: clock });
  return { env, provider, limiter, call, advance: (ms) => { t += ms; } };
}

test("spento di default: 503 disabled e nessuna chiamata al fornitore né ai contatori", async () => {
  for (const flag of [undefined, "false", "", "TRUE", "1"]) {
    const s = setup({ LOOKUP_ENABLED: flag });
    const res = await s.call(request({ plate: "AB123CD", country: "IT" }));
    assert.equal(res.status, 503);
    assert.deepEqual(await res.json(), { error: "disabled" });
    assert.equal(s.provider.calls, 0);
    assert.equal(s.limiter.storage.map.size, 0);
  }
});

test("interruttore della spesa SPEND_STOP blocca anche con il servizio acceso", async () => {
  const s = setup({ SPEND_STOP: "true" });
  const res = await s.call(request({ plate: "AB123CD" }));
  assert.equal(res.status, 503);
  assert.deepEqual(await res.json(), { error: "disabled" });
  assert.equal(s.provider.calls, 0);
});

test("targa non valida: 400 senza contare né chiamare", async () => {
  const s = setup();
  for (const plate of ["", "ABC", "AB123C", "IO123QU", "MI123456", "AB-123-CD-EF", 12345, null, "A".repeat(40)]) {
    const res = await s.call(request({ plate, country: "IT" }));
    assert.equal(res.status, 400, `targa ${plate}`);
    assert.deepEqual(await res.json(), { error: "invalid_plate" });
  }
  assert.equal(s.provider.calls, 0);
  assert.equal(s.limiter.storage.map.size, 0);
});

test("paese diverso da IT, JSON rotto, header mancanti", async () => {
  const s = setup();
  assert.equal((await s.call(request({ plate: "AB123CD", country: "FR" }))).status, 400);
  assert.equal((await s.call(request("{not json"))).status, 400);
  assert.equal((await s.call(request({ plate: "AB123CD" }, { "X-Device-Id": "" }))).status, 400);
  assert.equal((await s.call(request({ plate: "AB123CD" }, { "Content-Type": "text/plain" }))).status, 415);
  assert.equal((await s.call(request({ plate: "AB123CD", pad: "x".repeat(2000) }))).status, 413);
  assert.equal(s.provider.calls, 0);
});

test("CORS disattivato: richieste da browser rifiutate, nessun header Access-Control", async () => {
  const s = setup();
  const res = await s.call(request({ plate: "AB123CD" }, { Origin: "https://evil.example" }));
  assert.equal(res.status, 403);
  assert.equal(res.headers.get("Access-Control-Allow-Origin"), null);
  const ok = await s.call(request({ plate: "AB123CD" }));
  assert.equal(ok.headers.get("Access-Control-Allow-Origin"), null);
  const pre = await s.call(new Request("https://x.example/v1/plate", { method: "OPTIONS" }));
  assert.equal(pre.status, 405);
});

test("successo: solo i campi previsti, targa normalizzata", async () => {
  let seen;
  const provider = fakeProvider();
  const orig = provider.lookup;
  provider.lookup = async (plate, opts) => { seen = plate; return orig(plate, opts); };
  const s = setup({}, provider);
  const res = await s.call(request({ plate: " ab 123 cd ", country: "IT" }));
  assert.equal(res.status, 200);
  assert.equal(seen, "AB123CD");
  assert.equal(res.headers.get("Cache-Control"), "no-store");
  assert.deepEqual(await res.json(), {
    make: "FIAT", model: "Panda", fuel: "petrol", firstRegistration: "2019-03-14", euroClass: 6, source: "fake",
  });
});

test("targa non trovata: 404", async () => {
  const s = setup({}, fakeProvider(null));
  const res = await s.call(request({ plate: "AB12345" }));
  assert.equal(res.status, 404);
  assert.deepEqual(await res.json(), { error: "plate_not_found" });
});

test("fornitore lento: timeout breve → 503 unavailable", async () => {
  const slow = { name: "slow", lookup: () => new Promise(() => {}) };
  const s = setup({ PROVIDER_TIMEOUT_MS: "50" }, slow);
  const started = Date.now();
  const res = await s.call(request({ plate: "AB123CD" }));
  assert.equal(res.status, 503);
  assert.deepEqual(await res.json(), { error: "unavailable" });
  assert.ok(Date.now() - started < 2000);
});

test("limite per dispositivo: oltre 5 al giorno → 429", async () => {
  const s = setup();
  for (let i = 0; i < 5; i++) assert.equal((await s.call(request({ plate: "AB123CD" }))).status, 200);
  const res = await s.call(request({ plate: "AB123CD" }));
  assert.equal(res.status, 429);
  assert.deepEqual(await res.json(), { error: "rate_limited" });
  // Un altro dispositivo dallo stesso IP passa (fino al limite per IP)
  const other = await s.call(request({ plate: "AB123CD" }, { "X-Device-Id": "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE" }));
  assert.equal(other.status, 200);
  assert.equal(s.provider.calls, 6);
});

test("limite per IP: dispositivi diversi dallo stesso IP, oltre 10 al giorno → 429", async () => {
  const s = setup({ DEVICE_DAILY_CAP: "100", DEVICE_MONTHLY_CAP: "100" });
  for (let i = 0; i < 10; i++) {
    const r = await s.call(request({ plate: "AB123CD" }, { "X-Device-Id": `device-${String(i).padStart(12, "0")}` }));
    assert.equal(r.status, 200);
  }
  const r = await s.call(request({ plate: "AB123CD" }, { "X-Device-Id": "device-999999999999" }));
  assert.equal(r.status, 429);
});

test("tetto globale giornaliero: 503 capped senza chiamare, si riapre il giorno dopo", async () => {
  const s = setup({ DAILY_CAP: "3", DEVICE_DAILY_CAP: "100", IP_DAILY_CAP: "100" });
  for (let i = 0; i < 3; i++) assert.equal((await s.call(request({ plate: "AB123CD" }))).status, 200);
  const res = await s.call(request({ plate: "AB123CD" }));
  assert.equal(res.status, 503);
  assert.deepEqual(await res.json(), { error: "capped" });
  assert.equal(s.provider.calls, 3);
  s.advance(24 * 60 * 60 * 1000);
  assert.equal((await s.call(request({ plate: "AB123CD" }))).status, 200);
});

test("tetto mensile dal budget: 1 € a 0,29 € = 3 ricerche al mese", async () => {
  const s = setup({
    MONTHLY_BUDGET_EUR: "1", DAILY_CAP: "100", DEVICE_DAILY_CAP: "100", DEVICE_MONTHLY_CAP: "100", IP_DAILY_CAP: "100",
  });
  for (let i = 0; i < 3; i++) {
    assert.equal((await s.call(request({ plate: "AB123CD" }))).status, 200);
    s.advance(24 * 60 * 60 * 1000); // giorni diversi, stesso mese (26, 27, 28 ottobre)
  }
  const res = await s.call(request({ plate: "AB123CD" }));
  assert.equal(res.status, 503);
  assert.deepEqual(await res.json(), { error: "capped" });
});

test("tetti mancanti o sbagliati = tutto bloccato (fail closed)", async () => {
  for (const o of [{ DAILY_CAP: undefined }, { MONTHLY_CAP: "abc" }, { COST_PER_LOOKUP_EUR: "0" }, { MONTHLY_BUDGET_EUR: "" }]) {
    const s = setup(o);
    const res = await s.call(request({ plate: "AB123CD" }));
    assert.equal(res.status, 503, JSON.stringify(o));
    assert.equal(s.provider.calls, 0);
  }
});

test("1 richiesta ogni 5 secondi verso il fornitore: 429 busy con Retry-After", async () => {
  const s = setup({ PROVIDER_MIN_INTERVAL_MS: "5000" });
  assert.equal((await s.call(request({ plate: "AB123CD" }))).status, 200);
  s.advance(2000);
  const res = await s.call(request({ plate: "AB123CD" }));
  assert.equal(res.status, 429);
  assert.equal(res.headers.get("Retry-After"), "3");
  s.advance(3000);
  assert.equal((await s.call(request({ plate: "AB123CD" }))).status, 200);
});

test("App Attest richiesto ma non ancora implementato: rifiuta (fail closed)", async () => {
  const s = setup({ REQUIRE_APP_ATTEST: "true" });
  const res = await s.call(request({ plate: "AB123CD" }));
  assert.equal(res.status, 403);
  assert.equal(s.provider.calls, 0);
});

test("i contatori non contengono mai la targa", async () => {
  const s = setup();
  await s.call(request({ plate: "AB123CD" }));
  const dump = JSON.stringify([...s.limiter.storage.map.entries()]);
  assert.ok(!dump.includes("AB123CD"));
  assert.ok(!dump.includes("203.0.113.7"));
  assert.ok(!dump.includes("3F2504E0"));
});
