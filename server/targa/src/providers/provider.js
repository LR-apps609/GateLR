// Contratto comune dei fornitori (InfoTarga oggi; Openapi o RegCheck in futuro).
//
// Un fornitore è un oggetto:
//   {
//     name: "infotarga",
//     async lookup(plate, { signal }) -> VehicleData | null   // null = targa non trovata
//   }
// VehicleData = { make, model, fuel, firstRegistration, euroClass } (ogni campo può essere null)
//   fuel: "petrol" | "diesel" | "hybrid" | "electric" | "lpg" | null   (gli stessi valori di `Fuel` nell'app)
//   firstRegistration: "AAAA-MM-GG" oppure "AAAA" | null
//   euroClass: numero 0…6 | null
// In caso di errore il fornitore lancia ProviderError (mai con la targa nel messaggio).

export class ProviderError extends Error {
  constructor(code) {
    super(code); // "unavailable" | "timeout" | "rate_limited" | "auth"
    this.code = code;
  }
}

/** Alimentazione del fornitore → valore dell'app */
export function mapFuel(raw) {
  if (typeof raw !== "string") return null;
  const s = raw.toLowerCase();
  if (/elettric|electric|\bev\b|\bbev\b/.test(s) && !/ibrid|hybrid/.test(s)) return "electric";
  if (/ibrid|hybrid|\bhev\b|\bphev\b/.test(s)) return "hybrid";
  if (/gpl|lpg|metano|cng|methane|natural gas/.test(s)) return "lpg";
  if (/gasolio|diesel/.test(s)) return "diesel";
  if (/benzin|petrol|gasoline/.test(s)) return "petrol";
  return null;
}

/** "EURO 6D-TEMP", "Euro6", "E5", 4 → numero 0…6 */
export function mapEuro(raw) {
  if (typeof raw === "number" && Number.isInteger(raw) && raw >= 0 && raw <= 6) return raw;
  if (typeof raw !== "string") return null;
  const m = /(?:euro|^e)\s*([0-6])/i.exec(raw.trim());
  return m ? Number(m[1]) : null;
}

/** Date di immatricolazione in vari formati → "AAAA-MM-GG" o "AAAA" */
export function mapDate(raw) {
  if (typeof raw === "number" && raw >= 1900 && raw <= 2100) return String(raw);
  if (typeof raw !== "string") return null;
  const s = raw.trim();
  let m = /^(\d{4})-(\d{2})-(\d{2})/.exec(s);
  if (m) return `${m[1]}-${m[2]}-${m[3]}`;
  m = /^(\d{2})[/.-](\d{2})[/.-](\d{4})$/.exec(s); // 26/10/2020
  if (m) return `${m[3]}-${m[2]}-${m[1]}`;
  m = /^(\d{4})$/.exec(s);
  return m ? m[1] : null;
}

/** Testo pulito e corto (niente oggetti strani verso l'app) */
export function cleanText(raw, max = 60) {
  if (typeof raw !== "string") return null;
  const s = raw.trim().replace(/\s+/g, " ");
  return s ? s.slice(0, max) : null;
}
