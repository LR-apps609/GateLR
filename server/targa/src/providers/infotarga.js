// Adattatore InfoTarga (https://www.infotarga.com/docs/v3/services), servizi «details» + «emissions».
//
// ⚠️ NON VERIFICATO: la documentazione non era leggibile da qui. L'indirizzo, l'autenticazione e TUTTI i nomi
// dei campi qui sotto sono ipotesi, segnate con TODO(infotarga). Vanno controllati sulla documentazione ufficiale
// (o con una richiesta di prova) prima di attivare il servizio. Finché LOOKUP_ENABLED non è "true" questo
// codice non viene mai eseguito.

import { ProviderError, mapFuel, mapEuro, mapDate, cleanText } from "./provider.js";

export function createInfoTarga({ apiKey, baseUrl, fetchImpl = fetch }) {
  if (!apiKey || !baseUrl || baseUrl.includes("REPLACE-ME")) {
    // Configurazione assente: si comporta come «servizio non disponibile», senza chiamare nessuno
    return { name: "infotarga", async lookup() { throw new ProviderError("unavailable"); } };
  }
  return {
    name: "infotarga",
    async lookup(plate, { signal } = {}) {
      // TODO(infotarga): percorso e parametri reali. Ipotesi: GET /vehicles/{targa}?services=details,emissions
      const url = `${baseUrl.replace(/\/$/, "")}/vehicles/${encodeURIComponent(plate)}?services=details,emissions`;
      let res;
      try {
        res = await fetchImpl(url, {
          method: "GET",
          // TODO(infotarga): schema di autenticazione reale (Bearer? header «X-Api-Key»?)
          headers: { Authorization: `Bearer ${apiKey}`, Accept: "application/json" },
          signal,
        });
      } catch (e) {
        throw new ProviderError(e?.name === "AbortError" || e?.name === "TimeoutError" ? "timeout" : "unavailable");
      }
      if (res.status === 404) return null;
      if (res.status === 429) throw new ProviderError("rate_limited");
      if (res.status === 401 || res.status === 403) throw new ProviderError("auth");
      if (!res.ok) throw new ProviderError("unavailable");

      let body;
      try { body = await res.json(); } catch { throw new ProviderError("unavailable"); }
      return mapInfoTarga(body);
    },
  };
}

/** Risposta InfoTarga → VehicleData. Esportata per i test. */
export function mapInfoTarga(body) {
  // TODO(infotarga): struttura reale. Ipotesi: { data: { details: {...}, emissions: {...} } } oppure senza «data»
  const root = body?.data ?? body ?? {};
  const details = root.details ?? {};
  const emissions = root.emissions ?? {};
  if (root.found === false) return null; // TODO(infotarga): come segnala «targa non trovata»?

  const result = {
    make: cleanText(details.make ?? details.brand ?? details.marca), // TODO(infotarga): nome del campo marca
    model: cleanText(details.model ?? details.modello), // TODO(infotarga): nome del campo modello
    fuel: mapFuel(details.fuel ?? details.fuelType ?? details.alimentazione), // TODO(infotarga): alimentazione
    firstRegistration: mapDate(
      details.registrationDate ?? details.firstRegistration ?? details.dataImmatricolazione, // TODO(infotarga)
    ),
    euroClass: mapEuro(
      emissions.euroClass ?? emissions.environmentalClass ?? emissions.classeAmbientale, // TODO(infotarga)
    ),
  };
  const empty = Object.values(result).every((v) => v === null);
  return empty ? null : result;
}
