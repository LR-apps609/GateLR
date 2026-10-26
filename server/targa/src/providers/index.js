// Scelta del fornitore dalla variabile PROVIDER. Per aggiungerne uno (Openapi «Italian Car Check», RegCheck):
// scrivere providers/<nome>.js con lo stesso contratto di provider.js e aggiungerlo qui.
import { createInfoTarga } from "./infotarga.js";

export function createProvider(env) {
  switch (env.PROVIDER ?? "infotarga") {
    case "infotarga":
      return createInfoTarga({ apiKey: env.INFOTARGA_KEY, baseUrl: env.INFOTARGA_BASE_URL });
    // case "openapi": TODO — GET https://automotive.openapi.com/IT-car/{targa} (CarMake, CarModel, FuelType,
    //   RegistrationYear; classe Euro probabilmente assente)
    // case "regcheck": TODO — servizio SOAP/XML di carregistrationapi.ie
    default:
      return null;
  }
}
