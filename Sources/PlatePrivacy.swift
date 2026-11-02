import Foundation

/// 1.19.4 «Privacy onesta»: la targa resta nel Garage di questo iPhone. Nei testi che escono dall'app o si vedono fuori
/// (condivisioni, appunti, bozza del ricorso, widget e App Group, Siri, Live Activity, notifiche) non c'è mai: si toglie
/// o si copre con «•••». Unica eccezione voluta, detta nella pagina Privacy: il messaggio per l'hotel, che serve proprio
/// a far registrare la targa e che mandi tu. Compilato nell'app e nel widget.
enum PlatePrivacy {
    /// Quello che prende il posto di una targa in un testo
    static let mask = "•••"

    /// Le targhe italiane dal 1994: «AB123CD», «AB 123 CD», «AB-123-CD»
    private static let italian = try! NSRegularExpression(
        pattern: "(?<![A-Z0-9])[A-Z]{2}[ \\-]?[0-9]{3}[ \\-]?[A-Z]{2}(?![A-Z0-9])", options: [.caseInsensitive])

    /// Solo lettere e cifre, in maiuscolo: «ab-123 cd» → «AB123CD»
    static func normalized(_ plate: String) -> String {
        String(plate.uppercased().filter { $0.isLetter || $0.isNumber })
    }

    /// Il testo senza le targhe date (anche scritte con spazi, trattini o punti in mezzo) e senza targhe italiane
    static func scrub(_ text: String, plates: [String] = []) -> String {
        var out = text
        for plate in Set(plates.map(normalized)) where plate.count >= 4 {
            let body = plate.map { NSRegularExpression.escapedPattern(for: String($0)) }.joined(separator: "[\\s\\-.·]?")
            guard let re = try? NSRegularExpression(pattern: "(?<![A-Z0-9])" + body + "(?![A-Z0-9])", options: [.caseInsensitive])
            else { continue }
            out = re.stringByReplacingMatches(in: out, range: NSRange(out.startIndex..., in: out), withTemplate: mask)
        }
        return italian.stringByReplacingMatches(in: out, range: NSRange(out.startIndex..., in: out), withTemplate: mask)
    }

    /// Vero se nel testo c'è una delle targhe (o una targa italiana)
    static func leaks(_ text: String, plates: [String] = []) -> Bool {
        scrub(text, plates: plates) != text
    }

    /// Il nome del veicolo da mostrare fuori dall'app (widget, condivisioni): senza la targa, anche se l'hai scritta nel
    /// nome; se non resta niente, marca e modello o «il tuo veicolo»
    static func displayName(_ v: Vehicle) -> String {
        let name = scrub(v.name, plates: [v.plate]).replacingOccurrences(of: mask, with: "")
            .trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "-·,:()")))
        if !name.isEmpty { return name }
        let model = scrub([v.make ?? "", v.model].filter { !$0.isEmpty }.joined(separator: " "), plates: [v.plate])
            .replacingOccurrences(of: mask, with: "").trimmingCharacters(in: .whitespaces)
        return model.isEmpty ? L("your vehicle") : model
    }

    /// Il veicolo per il widget (App Group): tutto quello che serve alla risposta, ma senza la targa
    static func withoutPlate(_ v: Vehicle) -> Vehicle {
        var copy = v
        copy.plate = ""
        copy.name = displayName(v)
        return copy
    }

    /// Le targhe del Garage
    @MainActor static var knownPlates: [String] { Store.shared.vehicles.map(\.plate).filter { !$0.isEmpty } }

    /// Un testo per notifiche, Siri e Live Activity, senza le targhe del Garage
    @MainActor static func clean(_ text: String) -> String { scrub(text, plates: knownPlates) }
}

extension DriveAttributes.ContentState {
    /// Dynamic Island e schermata di blocco: nessuna targa in nessun testo
    func withoutPlates(_ plates: [String]) -> Self {
        var s = self
        s.distance = PlatePrivacy.scrub(distance, plates: plates)
        s.instruction = PlatePrivacy.scrub(instruction, plates: plates)
        s.warning = warning.map { PlatePrivacy.scrub($0, plates: plates) }
        s.zone = zone.map { PlatePrivacy.scrub($0, plates: plates) }
        return s
    }
}
