import { reserve, readLimits } from "../src/limits.js";

export const ENABLED_ENV = {
  LOOKUP_ENABLED: "true",
  SPEND_STOP: "false",
  DAILY_CAP: "120",
  MONTHLY_CAP: "1000",
  MONTHLY_BUDGET_EUR: "50",
  COST_PER_LOOKUP_EUR: "0.29",
  DEVICE_DAILY_CAP: "5",
  DEVICE_MONTHLY_CAP: "20",
  IP_DAILY_CAP: "10",
  PROVIDER_MIN_INTERVAL_MS: "0",
  PROVIDER_TIMEOUT_MS: "200",
};

/** Una mappa in memoria con la stessa forma minima dello storage del Durable Object */
export function memoryStorage() {
  const map = new Map();
  return {
    map,
    async get(k) { return map.get(k); },
    async put(entries) { for (const [k, v] of Object.entries(entries)) map.set(k, v); },
  };
}

export function memoryLimiter(env, clock) {
  const storage = memoryStorage();
  return {
    storage,
    reserve: (keys) => reserve(storage, { ...keys, now: clock(), limits: readLimits(env) }),
  };
}

/** Fornitore finto: conta le chiamate */
export function fakeProvider(result = {
  make: "FIAT", model: "Panda", fuel: "petrol", firstRegistration: "2019-03-14", euroClass: 6,
}) {
  const p = {
    name: "fake",
    calls: 0,
    async lookup() { p.calls += 1; return typeof result === "function" ? result() : result; },
  };
  return p;
}

export function request(body, headers = {}) {
  return new Request("https://gatelr-targa.example.workers.dev/v1/plate", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Device-Id": "3F2504E0-4F89-11D3-9A0C-0305E82C3301",
      "CF-Connecting-IP": "203.0.113.7",
      ...headers,
    },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}
