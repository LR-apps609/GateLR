import Foundation

/// 2.0.2 «Fiducia»: la riga sotto ogni risposta e il link da mandare all'hotel o al noleggio. Gli stessi casi di Android
/// (core/Fiducia.kt) e del sito (fiducia* in web/template.html): shared/fiducia-cases.json.
///
/// - La data mostrata è la più recente tra «letto il» (source.checkedOn: quando abbiamo letto le pagine ufficiali) e
///   «verificato il» (source.verifiedOn), in giorni di calendario di Roma. Mai un'ora: quella di checkedOn non è affidabile.
/// - «Non ancora verificata a mano»: source.reviewedByHuman falso. Un'etichetta gialla accanto alla data: il colore della
///   risposta NON cambia (la regola «mai verde se non verificata» non è stata decisa).
/// - Il link porta alla risposta sul sito, senza installare nulla: #p=lat,lon&n=nome&v=veicolo (linkHash del sito).
enum Fiducia {
    static let site = "https://lr-apps609.github.io/GateLR/"

    /// I veicoli del menu del sito (CARS in web/template.html): solo questi vanno nel link
    static let siteVehicles = ["petrol-6", "petrol-3", "diesel-4", "diesel-6", "hybrid-6", "electric-6", "moto-5", "diesel-5", "petrol-4", "petrol-5"]

    enum When: String { case today, yesterday, date }

    struct Control: Equatable {
        var when: When
        /// «23/10», con l'anno se non è quello di adesso: «23/10/2026»
        var label: String
        /// Verificata o letta da al più 120 giorni, pagina del Comune non cambiata: la spunta
        var fresh: Bool
        /// Verificata da una persona (source.reviewedByHuman)
        var byHand: Bool

        /// «Controllata oggi», «Controllata ieri», «Controllata il 23/10»
        var text: String {
            switch when {
            case .today: L("Last checked today")
            case .yesterday: L("Last checked yesterday")
            case .date: String(format: L("Last checked %@"), label)
            }
        }
    }

    static func control(_ source: Source, now: Date, staleAfterDays: Int = 120) -> Control {
        let cal = RuleEngine.rome
        let at = RuleEngine.freshest(source)
        let d = cal.dateComponents([.year, .month, .day], from: at)
        let year = cal.component(.year, from: now)
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: at), to: cal.startOfDay(for: now)).day ?? Int.max
        let when: When = days == 0 ? .today : days == 1 ? .yesterday : .date
        var label = String(format: "%02d/%02d", d.day ?? 0, d.month ?? 0)
        if let y = d.year, y != year { label += "/\(y)" }
        var engine = RuleEngine()
        engine.now = { now }
        engine.staleAfterDays = staleAfterDays
        let trust = engine.trust(source)
        return Control(when: when, label: label, fresh: trust == .verified || trust == .read, byHand: source.reviewedByHuman)
    }

    /// «diesel-4», «moto-5»: solo se il sito conosce quel veicolo; mai per un veicolo «Non so»
    static func vehicleKey(fuel: String, euro: Int, motorcycle: Bool, unknown: Bool = false) -> String? {
        if unknown { return nil }
        // Le moto sul sito sono «moto-<euro>», le auto «<carburante>-<euro>» (VKEY in web/template.html)
        let k = (motorcycle ? "moto" : fuel) + "-" + String(euro)
        return siteVehicles.contains(k) ? k : nil
    }

    static func vehicleKey(_ v: Vehicle) -> String? {
        vehicleKey(fuel: v.fuel.rawValue, euro: v.euro, motorcycle: v.kind == .motorcycle,
                   unknown: (v.fuelUnknown ?? false) || (v.euroUnknown ?? false))
    }

    /// La pagina del sito nella lingua: it/, de/; le altre lingue la pagina inglese
    static func sitePrefix(_ lang: String) -> String {
        let code = lang.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map({ String($0) }) ?? lang
        switch code {
        case "it": return "it/"
        case "de": return "de/"
        default: return ""
        }
    }

    /// La lingua dell'app (la stessa dei testi): «it», «de», «zh-Hans»…
    static var appLanguage: String { Bundle.main.preferredLocalizations.first ?? "en" }

    /// Come URLSearchParams del browser (application/x-www-form-urlencoded, UTF-8): lo stesso link su ogni superficie
    static func formEncode(_ s: String) -> String {
        var out = ""
        for b in s.utf8 {
            switch b {
            case 0x30...0x39, 0x41...0x5A, 0x61...0x7A, 0x2A, 0x2D, 0x2E, 0x5F: out.append(Character(UnicodeScalar(b)))
            case 0x20: out.append("+")
            default: out += String(format: "%%%02X", b)
            }
        }
        return out
    }

    /// Il link da condividere. Con un posto: la risposta per quel posto (la home del sito con #p=…); senza (o con la
    /// posizione del telefono, che non si condivide): la pagina della città
    static func shareURL(lang: String, cityId: String?, placeName: String?, lat: Double?, lon: Double?, vehicleKey: String?) -> String {
        let base = site + sitePrefix(lang)
        guard let placeName, let lat, let lon else { return base + (cityId.map { "\($0)/" } ?? "") }
        let p = String(format: "%.5f,%.5f", locale: Locale(identifier: "en_US_POSIX"), lat, lon)
        var parts = [("p", p), ("n", String(placeName.trimmingCharacters(in: .whitespaces).prefix(120)))]
        if let vehicleKey { parts.append(("v", vehicleKey)) }
        return base + "#" + parts.map { $0.0 + "=" + formEncode($0.1) }.joined(separator: "&")
    }

    /// Il testo da mandare: chi lo riceve apre la risposta nel browser, senza installare nulla. Mai la targa
    static func shareText(name: String, url: String) -> String {
        String(format: L("I'm arriving by car: %@. Here GateLR shows if a car can enter the ZTL. It opens in the browser, nothing to install:"), name)
            + "\n" + url
    }

    /// Le fonti ufficiali dei termini dei ricorsi (gli stessi link di Android e del sito)
    static let fineSources: [(title: String, url: URL)] = [
        ("Highway Code, art. 203 (appeal to the Prefetto)",
         URL(string: "https://www.normattiva.it/uri-res/N2Ls?urn:nir:stato:decreto.legislativo:1992-04-30;285~art203")!),
        ("Highway Code, art. 204-bis (Giudice di Pace)",
         URL(string: "https://www.normattiva.it/uri-res/N2Ls?urn:nir:stato:decreto.legislativo:1992-04-30;285~art204bis")!),
        ("Example: Prefecture of Turin, appeals against traffic fines",
         URL(string: "https://prefettura.interno.gov.it/it/prefetture/torino/ricorso-violazioni-codice-strada")!),
    ]
}
