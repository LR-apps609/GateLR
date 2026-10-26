// Controllo del formato della targa italiana. Nessun log, nessun salvataggio.

// Lettere usate nelle targhe italiane dal 1994: niente I, O, Q, U
const L = "[A-HJ-NPR-TV-Z]";

const FORMATS = [
  // Autoveicoli dal 1994: AB123CD
  { kind: "car", re: new RegExp(`^${L}{2}[0-9]{3}${L}{2}$`) },
  // Motoveicoli dal 1999: AB12345
  { kind: "motorcycle", re: new RegExp(`^${L}{2}[0-9]{5}$`) },
];
// Non accettati per ora: ciclomotori (6 caratteri, dal 2006), targhe provinciali prima del 1994 (es. MI 123456),
// rimorchi, targhe speciali (EI, CD, prova). InfoTarga copre gli autoveicoli; si possono aggiungere dopo.

/** Toglie spazi e trattini e mette in maiuscolo. Restituisce null se non è un testo ragionevole. */
export function normalizePlate(input) {
  if (typeof input !== "string" || input.length > 16) return null;
  const p = input.toUpperCase().replace(/[\s-]/g, "");
  return p.length > 0 ? p : null;
}

/** Restituisce { plate, kind } se il formato è valido, altrimenti null */
export function parseItalianPlate(input) {
  const plate = normalizePlate(input);
  if (!plate) return null;
  for (const f of FORMATS) if (f.re.test(plate)) return { plate, kind: f.kind };
  return null;
}
