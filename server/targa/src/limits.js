// Tetti globali e limiti per dispositivo / indirizzo IP.
// Le chiavi contengono solo date, numeri e hash: MAI la targa.

const intVar = (v, fallback = 0) => {
  const n = Number.parseInt(v ?? "", 10);
  return Number.isFinite(n) && n >= 0 ? n : fallback;
};
const floatVar = (v) => {
  const n = Number.parseFloat(v ?? "");
  return Number.isFinite(n) && n >= 0 ? n : 0;
};

/** Legge i limiti dalle variabili. Valori mancanti o sbagliati = 0 = tutto bloccato (fail closed). */
export function readLimits(env) {
  const monthlyCap = intVar(env.MONTHLY_CAP);
  const budget = floatVar(env.MONTHLY_BUDGET_EUR);
  const cost = floatVar(env.COST_PER_LOOKUP_EUR);
  // Il tetto di spesa diventa un tetto di ricerche: floor(budget / costo). Costo 0 o mancante = bloccato.
  const budgetCap = cost > 0 ? Math.floor(budget / cost + 1e-9) : 0;
  return {
    daily: intVar(env.DAILY_CAP),
    monthly: Math.min(monthlyCap, budgetCap),
    deviceDaily: intVar(env.DEVICE_DAILY_CAP),
    deviceMonthly: intVar(env.DEVICE_MONTHLY_CAP),
    ipDaily: intVar(env.IP_DAILY_CAP),
    minIntervalMs: intVar(env.PROVIDER_MIN_INTERVAL_MS, 5000),
  };
}

/** Giorno e mese nel fuso italiano (InfoTarga e il budget ragionano in giorni e mesi italiani) */
export function periodKeys(now) {
  const d = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/Rome", year: "numeric", month: "2-digit", day: "2-digit",
  }).format(new Date(now)); // "2026-10-26"
  return { day: d, month: d.slice(0, 7) };
}

/**
 * Prenota una ricerca, in modo atomico (chiamata dentro il Durable Object, che serializza le richieste).
 * storage: { get(key), put(entries) } asincroni. Restituisce { ok: true } o { ok: false, reason, retryAfter? }.
 * La ricerca si conta PRIMA di chiamare il fornitore: una richiesta finita male conta comunque (prudenza sulla spesa).
 */
export async function reserve(storage, { deviceKey, ipKey, now, limits }) {
  const { day, month } = periodKeys(now);
  const keys = {
    gDay: `g:d:${day}`,
    gMonth: `g:m:${month}`,
    dDay: `dv:d:${day}:${deviceKey}`,
    dMonth: `dv:m:${month}:${deviceKey}`,
    ipDay: `ip:d:${day}:${ipKey}`,
    last: "g:last",
  };
  const values = {};
  for (const [name, key] of Object.entries(keys)) values[name] = (await storage.get(key)) ?? 0;

  // Prima i tetti globali (proteggono il portafoglio), poi i limiti personali
  if (values.gDay >= limits.daily || values.gMonth >= limits.monthly) return { ok: false, reason: "capped" };
  if (values.dDay >= limits.deviceDaily || values.dMonth >= limits.deviceMonthly || values.ipDay >= limits.ipDaily) {
    return { ok: false, reason: "rate_limited" };
  }
  const wait = values.last + limits.minIntervalMs - now;
  if (wait > 0) return { ok: false, reason: "busy", retryAfter: Math.ceil(wait / 1000) };

  await storage.put({
    [keys.gDay]: values.gDay + 1,
    [keys.gMonth]: values.gMonth + 1,
    [keys.dDay]: values.dDay + 1,
    [keys.dMonth]: values.dMonth + 1,
    [keys.ipDay]: values.ipDay + 1,
    [keys.last]: now,
  });
  return { ok: true };
}

/** Chiavi dei periodi passati da cancellare (pulizia giornaliera): resta solo oggi e il mese corrente */
export function staleKeys(allKeys, now) {
  const { day, month } = periodKeys(now);
  return allKeys.filter((k) => {
    const m = /^(?:g|dv|ip):(d|m):([0-9-]+)/.exec(k);
    if (!m) return false;
    return m[1] === "d" ? m[2] !== day : m[2] !== month;
  });
}

/** Hash SHA-256 (esadecimale, troncato) di un identificativo, con un sale segreto facoltativo */
export async function hashId(value, salt = "") {
  const data = new TextEncoder().encode(`${salt}|${value}`);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return [...new Uint8Array(digest)].slice(0, 16).map((b) => b.toString(16).padStart(2, "0")).join("");
}
