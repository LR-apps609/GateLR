// La logica della richiesta, senza dipendenze da Cloudflare (così i test girano con node --test).
// IMPORTANTE: non aggiungere console.log / console.error con dati della richiesta (targa, IP, dispositivo).

import { parseItalianPlate } from "./plate.js";
import { hashId } from "./limits.js";
import { ProviderError } from "./providers/provider.js";

const MAX_BODY_BYTES = 1024;
const DEVICE_ID_RE = /^[A-Za-z0-9-]{16,64}$/;

function json(status, body, extraHeaders = {}) {
  // Nessun header Access-Control-*: CORS disattivato
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
      ...extraHeaders,
    },
  });
}
const error = (status, code, extra) => json(status, { error: code }, extra);

/**
 * TODO(app-attest): verificare l'asserzione Apple App Attest (header X-App-Attest) con la chiave registrata del
 * dispositivo: https://developer.apple.com/documentation/devicecheck/validating_apps_that_connect_to_your_server
 * Finché non è implementata: con REQUIRE_APP_ATTEST = "true" il server rifiuta tutto (fail closed);
 * con "false" (prima versione) si usa solo l'identificativo casuale dell'installazione + il limite per IP.
 */
async function verifyDevice(request, env) {
  if (env.REQUIRE_APP_ATTEST === "true") return false;
  return true;
}

/**
 * deps = {
 *   provider: () => fornitore | null   (creato solo quando serve: con il servizio spento non si crea nemmeno)
 *   limiter: { reserve({ deviceKey, ipKey }) → { ok, reason, retryAfter? } }
 *   now: () => millisecondi
 * }
 */
export async function handle(request, env, deps) {
  const url = new URL(request.url);
  if (url.pathname !== "/v1/plate") return error(404, "not_found");
  if (request.method !== "POST") return error(405, "method_not_allowed", { Allow: "POST" });
  // Le richieste dai browser hanno l'header Origin; l'app iOS no. Niente CORS, niente browser.
  if (request.headers.has("Origin")) return error(403, "forbidden");

  // 1. Interruttori: prima di leggere qualunque cosa e senza chiamare nessuno
  if (env.LOOKUP_ENABLED !== "true") return error(503, "disabled");
  if (env.SPEND_STOP === "true") return error(503, "disabled");

  // 2. Dispositivo
  const deviceId = request.headers.get("X-Device-Id") ?? "";
  if (!DEVICE_ID_RE.test(deviceId)) return error(400, "missing_device");
  if (!(await verifyDevice(request, env))) return error(403, "device_not_verified");

  // 3. Corpo della richiesta
  if (!(request.headers.get("Content-Type") ?? "").toLowerCase().startsWith("application/json")) {
    return error(415, "unsupported_media_type");
  }
  const declared = Number(request.headers.get("Content-Length") ?? "0");
  if (declared > MAX_BODY_BYTES) return error(413, "too_large");
  let body;
  try {
    const text = await request.text();
    if (text.length > MAX_BODY_BYTES) return error(413, "too_large");
    body = JSON.parse(text);
  } catch {
    return error(400, "bad_request");
  }
  if (body === null || typeof body !== "object") return error(400, "bad_request");
  if ((body.country ?? "IT") !== "IT") return error(400, "unsupported_country");
  const parsed = parseItalianPlate(body.plate);
  if (!parsed) return error(400, "invalid_plate");

  // 4. Tetti e limiti (contati prima di spendere)
  const ip = request.headers.get("CF-Connecting-IP") ?? "unknown";
  const salt = env.ID_SALT ?? "";
  const verdict = await deps.limiter.reserve({
    deviceKey: await hashId(`dev:${deviceId}`, salt),
    ipKey: await hashId(`ip:${ip}`, salt),
  });
  if (!verdict.ok) {
    if (verdict.reason === "capped") return error(503, "capped");
    if (verdict.reason === "busy") return error(429, "busy", { "Retry-After": String(verdict.retryAfter ?? 5) });
    return error(429, "rate_limited");
  }

  // 5. Fornitore, con timeout breve
  const provider = deps.provider();
  if (!provider) return error(503, "unavailable");
  const timeoutMs = Number.parseInt(env.PROVIDER_TIMEOUT_MS ?? "8000", 10) || 8000;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  let data;
  try {
    data = await Promise.race([
      provider.lookup(parsed.plate, { signal: controller.signal }),
      new Promise((_, reject) => controller.signal.addEventListener("abort", () => reject(new ProviderError("timeout")))),
    ]);
  } catch (e) {
    if (e instanceof ProviderError && e.code === "rate_limited") return error(429, "busy", { "Retry-After": "5" });
    return error(503, "unavailable");
  } finally {
    clearTimeout(timer);
  }
  if (!data) return error(404, "plate_not_found");

  // 6. Solo i 5 campi utili + la fonte (le condizioni di InfoTarga vietano di esporre la loro API)
  return json(200, {
    make: data.make ?? null,
    model: data.model ?? null,
    fuel: data.fuel ?? null,
    firstRegistration: data.firstRegistration ?? null,
    euroClass: data.euroClass ?? null,
    source: provider.name,
  });
}
