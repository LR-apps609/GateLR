// GateLR «targa automatica»: piccolo server su Cloudflare Workers.
// POST /v1/plate { plate, country: "IT" } → { make, model, fuel, firstRegistration, euroClass, source }
//
// SPENTO di default (LOOKUP_ENABLED = "false"): risponde 503 { error: "disabled" } senza chiamare nessuno.
// Privacy: la targa non viene mai scritta nei log (niente console.log in questo progetto) né salvata:
// vive solo nella memoria della singola richiesta. CORS disattivato: nessun browser può usarlo.

import { DurableObject } from "cloudflare:workers";
import { handle } from "./handler.js";
import { reserve, readLimits, staleKeys } from "./limits.js";
import { createProvider } from "./providers/index.js";

export default {
  async fetch(request, env) {
    return handle(request, env, {
      provider: () => createProvider(env),
      limiter: {
        async reserve(keys) {
          const stub = env.COUNTERS.get(env.COUNTERS.idFromName("global"));
          return stub.reserve(keys);
        },
      },
      now: () => Date.now(),
    });
  },
};

/** Contatori: un solo oggetto globale, quindi gli aumenti sono atomici. Contiene solo numeri e hash. */
export class Counters extends DurableObject {
  async reserve({ deviceKey, ipKey }) {
    const now = Date.now();
    const storage = this.ctx.storage;
    const result = await reserve(storage, { deviceKey, ipKey, now, limits: readLimits(this.env) });
    // Pulizia dei giorni e mesi passati, una volta all'ora al massimo
    if ((await storage.getAlarm()) == null) await storage.setAlarm(now + 60 * 60 * 1000);
    return result;
  }

  async alarm() {
    const storage = this.ctx.storage;
    const keys = [...(await storage.list()).keys()];
    const stale = staleKeys(keys, Date.now());
    for (let i = 0; i < stale.length; i += 128) await storage.delete(stale.slice(i, i + 128));
  }
}
