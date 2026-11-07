import Foundation

// 2.1 «Una risposta, sette stati» (specifica: shared/risposta-finale.md). La sola risposta che le superfici mostrano:
// Varco, mappa, Viaggio, widget, Live Activity, avvisi e notifiche, Siri, CarPlay. Gli stessi stati su Android
// (android/core/.../RispostaFinale.kt) e sul sito (finale() in web/template.html), provati dagli stessi casi
// (shared/engine-cases.json, «stato» e «motivo»). Ognuno ha parola, forma e colore: mai solo colore.
// Compilato anche nel widget (project.yml): solo Foundation, i colori stanno in Theme.swift.

/// Il motivo del «Controlla il cartello», detto nella riga sotto, mai nel titolo
enum Motivo: String, CaseIterable, Equatable {
    case nonSicuro, scaduti, nonUfficiale, festivo
    /// Il veicolo «Non so» (decisione 8, arriva con la 2.2): dove contano i divieti Euro. Oggi nessun veicolo lo produce
    case euroSconosciuto

    /// La chiave (inglese) in Localizable.strings
    var key: String {
        switch self {
        case .nonSicuro: "Not sure"
        case .scaduti: "Data out of date"
        case .nonUfficiale: "Unofficial source"
        case .festivo: "Holiday not confirmed"
        case .euroSconosciuto: "Euro class unknown"
        }
    }
    var label: String { L(key) }
}

/// Il colore semantico di uno stato. «spento» (ZTL non attiva) è UN SOLO token: RispostaFinale.stateOff, oggi verde
enum Tono: String, CaseIterable, Equatable {
    case rosso, giallo, verde, spento, grigio, neutro
}

enum Stato: String, CaseIterable, Equatable {
    case nonEntrare, condizione, entraPure, ztlNonAttiva, controllaCartello, nonCoperto, fuoriZTL

    /// La parola fissa dello stato (le stesse chiavi su Android e sul sito)
    var word: AnswerWord {
        switch self {
        case .nonEntrare: .dontEnter
        case .condizione: .condition
        case .entraPure: .enter
        case .ztlNonAttiva: .notActive
        case .controllaCartello: .checkSign
        case .nonCoperto: .unknownPlace
        case .fuoriZTL: .outside
        }
    }

    /// La forma (simbolo SF dentro il cerchio). «nonCoperto» ha in più il contorno tratteggiato (dashed)
    var symbol: String { word.symbol }

    var tono: Tono {
        switch self {
        case .nonEntrare: .rosso
        case .condizione, .controllaCartello: .giallo
        case .entraPure: .verde
        case .ztlNonAttiva: .spento
        case .nonCoperto: .neutro
        case .fuoriZTL: .grigio
        }
    }

    /// Il colore da disegnare: «spento» diventa RispostaFinale.stateOff
    var color: Tono { tono == .spento ? RispostaFinale.stateOff : tono }

    /// Il contorno tratteggiato del posto che non conosciamo
    var dashed: Bool { self == .nonCoperto }

    /// Solo questi stati fanno scattare un avviso in auto: mai un avviso verde, né per la ZTL non attiva
    var alerts: Bool { self == .nonEntrare || self == .condizione || self == .controllaCartello }
}

struct RispostaFinale: Equatable {
    /// La ZTL non attiva: un solo token per tutta l'app. Oggi verde per regola di Ledion (la bozza proponeva grigio)
    static let stateOff: Tono = .verde

    var stato: Stato
    /// Solo con «controllaCartello»
    var motivo: Motivo? = nil
    /// La zona che decide (nil fuori dalle zone e nelle aree pedonali fuori dalle zone)
    var zoneId: String? = nil
    /// La fonte della zona che decide non è ufficiale (anche per un «Non entrare»: lo dice la riga sotto)
    var unofficial = false
    var gatesOn: Bool? = nil
    var nextChange: Date? = nil
    var pedestrian = false

    var word: AnswerWord { stato.word }
    var title: String { stato.word.title }
    var symbol: String { stato.symbol }
    var color: Tono { stato.color }

    /// La riga sotto il titolo: il motivo del «?»; per la fonte non ufficiale «Probabilmente sì/no · fonte non ufficiale»
    var reasonLine: String? {
        if let motivo, motivo != .nonUfficiale { return motivo.label }
        guard unofficial else { return nil }
        switch stato {
        case .nonEntrare: return L("Probably not · unofficial source")
        case .controllaCartello: return L("Probably yes · unofficial source")
        default: return L("Unofficial source")
        }
    }

    /// La frase breve da dire o scrivere da sola (Siri, CarPlay): la parola e, se c'è, la riga sotto
    var spoken: String { reasonLine.map { title + " · " + $0 } ?? title }

    /// La risposta di una zona come si mostra, nell'ordine della specifica. Area pedonale sempre «Non entrare»; «no» rosso
    /// anche da fonte non ufficiale (Salerno resta rossa); «non sicuro» col suo motivo; «sì» da fonte non ufficiale o da
    /// una città di esempio «Controlla il cartello»; «sì» a varchi accesi «Entra pure», spenti «ZTL non attiva»
    static func of(_ a: Answer, zone: Zone, status: City.Status? = nil, pedestrian: Bool = false) -> RispostaFinale {
        let (s, m) = decide(a, unofficial: zone.isUnofficial, sample: status == .sample, pedestrian: pedestrian)
        return RispostaFinale(stato: s, motivo: m, zoneId: zone.id, unofficial: !pedestrian && zone.isUnofficial, gatesOn: a.gatesOn,
                              nextChange: pedestrian ? nil : a.nextChange, pedestrian: pedestrian)
    }

    /// Il cuore della specifica, senza la zona (pillole e riquadri che hanno solo risposta e fonte)
    static func decide(_ a: Answer, unofficial: Bool, sample: Bool = false, pedestrian: Bool = false) -> (Stato, Motivo?) {
        if pedestrian { return (.nonEntrare, nil) }
        switch a.verdict {
        case .no: return (.nonEntrare, nil)
        case .conditional: return (.condizione, nil)
        case .unsure: return (.controllaCartello, a.doubt ?? (unofficial ? .nonUfficiale : .nonSicuro))
        case .yes:
            if unofficial { return (.controllaCartello, .nonUfficiale) }
            if sample { return (.controllaCartello, .nonSicuro) }
            return (a.gatesOn ? .entraPure : .ztlNonAttiva, nil)
        }
    }
}
