import SwiftUI

// La prima pagina 2.0 («Varco», VarcoView): la risposta del motore delle regole detta come sul pannello del varco
// e il pannello stesso come un oggetto vero. Usati anche dalla striscia di mappa in cima alla pagina (Home2Map).

// MARK: La risposta per la pagina

/// La risposta del motore delle regole detta come sul pannello: colore, frase breve, ora del prossimo cambio
struct Home2Answer: Equatable {
    enum Mood: Hashable, CaseIterable {
        /// «neutral» (1.19.0): fuori copertura, non sappiamo. Né verde né giallo: un contorno grigio-azzurro.
        /// «grey» (1.20.4, decisione di Ledion del 07/11): fuori dalla ZTL in una città che conosciamo, grigio neutro, mai verde
        case red, green, amber, neutral, grey
        /// 2.3: i pieni della risposta (Tokens), uguali di giorno e di notte; il neutro è l'inchiostro secondario
        var color: Color {
            switch self {
            case .neutral: Theme.muted
            default: Color(hex: hex)
            }
        }
        var hex: UInt32 {
            switch self {
            case .red: Tokens.noFill.day
            case .green: Tokens.yesFill.day
            case .amber: Tokens.condFill.day
            case .neutral: Tokens.text2.night
            case .grey: Tokens.greyFill.day
            }
        }
    }

    var mood: Mood
    var headline: String
    /// La frase sotto il titolo: la condizione («a una condizione:») o il motivo del dubbio, sempre in vista, non solo
    /// dietro «Perché?»
    var detail: String?
    var timeLabel: String?
    var time: String?
    /// Il giorno, se il cambio non è oggi
    var day: String?
    var zoneLine: String
    var panel: GatePanelState
    var city: City?
    /// Le regole della zona vengono solo da fonti non ufficiali: il titolo si dice con prudenza e sopra c'è l'avviso
    var unofficial = false
    var unofficialSource: UnofficialSource?
    /// 2.3: lo stato della RispostaFinale (il blocco della risposta: forma, parola, colore)
    var stato: Stato = .controllaCartello
    /// I varchi accesi adesso (il testo del pannello e la riga sotto)
    var gatesOn = false

    static func == (l: Home2Answer, r: Home2Answer) -> Bool {
        l.mood == r.mood && l.headline == r.headline && l.detail == r.detail && l.time == r.time && l.panel == r.panel && l.zoneLine == r.zoneLine
            && l.unofficial == r.unofficial && l.stato == r.stato
    }

    init(_ check: PlaceCheck, now: Date) {
        zoneLine = check.zoneLine
        city = check.city
        unofficial = check.unofficial
        unofficialSource = check.unofficial ? check.zone?.source.unofficialSource : nil
        let gatesOn = check.answer?.gatesOn ?? false
        self.gatesOn = gatesOn
        stato = check.finale.stato
        // Prima in variabili locali: il pannello si fa dal colore. 1.20.3 «Parole»: il titolo è sempre il titolo fisso
        // (AnswerWord: «Non entrare», «Puoi entrare», «A una condizione», «Controlla il cartello», «Non conosciamo questo
        // posto»); «Probabilmente sì», «Area pedonale»… sono la frase sotto. Prima «Entra pure.», «Arrivo sereno.»
        let m: Mood
        switch check.kind {
        case .closed, .pedestrian: m = .red
        // Fonte non ufficiale: mai verde (1.19.0). Giallo con il «?»
        case .open: m = check.hedged ? .amber : .green
        // 1.20.4: grigio (prima verde); 2.1 (B22): confine da fonte non ufficiale, giallo
        case .outside: m = check.hedged ? .amber : .grey
        case .uncovered: m = .neutral
        case .conditional, .unsure: m = .amber
        }
        mood = m; headline = check.word.title
        panel = GatePanelState.make(kind: check.kind, gatesOn: gatesOn, mood: m)
        detail = check.explanation
        if check.kind == .pedestrian {
            timeLabel = L("At any time"); time = nil
        } else if let answer = check.answer, let next = answer.nextChange {
            timeLabel = answer.gatesOn ? L("Gates off at") : L("Gates on at")
            time = RuleEngine.format(next, .init(date: .omitted, time: .shortened))
            day = RuleEngine.rome.isDate(next, inSameDayAs: now) ? nil : RuleEngine.format(next, .dateTime.weekday(.wide))
        }
    }
}

/// Lo stato del pannello: due righe di testo vero (in italiano, come sui cartelli) e la luce
struct GatePanelState: Equatable {
    var lines: [String]
    var mood: Home2Answer.Mood

    /// 1.19.0: il TESTO dice lo stato vero dei varchi (answer.gatesOn), con la dicitura ufficiale dei pannelli
    /// «ZTL ATTIVA» / «ZTL NON ATTIVA» (docs/parole.md); il COLORE dice la risposta. Varchi accesi ma puoi entrare
    /// (elettrica, moto esente, permesso, zona verde ammessa): verde «ZTL ATTIVA · SEI ESENTE». Mai «NON ATTIVA» a
    /// varchi accesi né «ATTIVA» a varchi spenti (prima «VARCO NON ATTIVO» per ogni «sì», «VARCO ATTIVO» per ogni dubbio)
    static func make(kind: PlaceCheck.Kind, gatesOn: Bool, mood: Home2Answer.Mood) -> GatePanelState {
        switch kind {
        case .pedestrian: return GatePanelState(lines: ["AREA", "PEDONALE"], mood: mood)
        case .outside: return GatePanelState(lines: ["FUORI", "ZTL"], mood: mood)
        case .uncovered: return GatePanelState(lines: ["ZONA", "NON COPERTA"], mood: mood)
        case .open where gatesOn: return GatePanelState(lines: ["ZTL ATTIVA", "SEI ESENTE"], mood: mood)
        case .open, .closed, .conditional, .unsure:
            return GatePanelState(lines: gatesOn ? ["ZTL", "ATTIVA"] : ["ZTL", "NON ATTIVA"], mood: mood)
        }
    }
}

extension Home2Answer.Mood {
    /// 2.1: la luce dal colore semantico della RispostaFinale («spento» è già risolto in RispostaFinale.stateOff)
    init(_ t: Tono) {
        switch t {
        case .rosso: self = .red
        case .giallo: self = .amber
        case .verde, .spento: self = .green
        case .grigio: self = .grey
        case .neutro: self = .neutral
        }
    }
}

extension Home2Answer {
    /// 2.3 (S-Risposta, «Regole del pannello LED»): il pannello solo dove c'è un varco vero. Fuori dalla ZTL e fuori
    /// copertura nessun pannello
    var showsPanel: Bool { stato != .fuoriZTL && stato != .nonCoperto }

    /// Il testo del pannello in una riga, dal motore («ZTL ATTIVA», «ZTL NON ATTIVA», «AREA PEDONALE»): mai dalla
    /// risposta (il «SEI ESENTE» del modello si dice nella riga accanto)
    var ledText: String {
        panel.lines == ["ZTL ATTIVA", "SEI ESENTE"] ? "ZTL ATTIVA" : panel.lines.joined(separator: " ")
    }

    /// La riga accanto al pannello: ammesso a ZTL attiva «per te va bene»; non sicuro a ZTL attiva «se dice così, non
    /// entrare»; negli altri casi «così lo vedrai al varco»
    var ledCaption: String {
        switch stato {
        case .entraPure where gatesOn: L("The panel will say ZTL ATTIVA: that's fine for you.")
        case .controllaCartello where gatesOn: L("If the panel says ZTL ATTIVA, don't enter.")
        default: L("This is how you'll see it at the gate.")
        }
    }
}
