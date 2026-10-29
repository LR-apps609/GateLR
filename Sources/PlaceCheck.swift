import SwiftUI

/// La risposta per un posto cercato, calcolata una volta per disegno: in che zone è, se è area pedonale,
/// se adesso si entra. La usano la prima pagina e la mappa, con le stesse regole di Viaggio.
struct PlaceCheck {
    enum Kind { case outside, open, closed, conditional, unsure, pedestrian }

    let place: Place
    let hits: [(city: City, zone: Zone)]
    let pedestrian: PedestrianArea?
    let answer: Answer?

    @MainActor
    init(_ place: Place, store: Store, at date: Date = Date()) {
        self.place = place
        hits = store.zones(at: place.location)
        pedestrian = store.pedestrianArea(at: place.location)
        answer = hits.first.map { store.answer(at: date, zone: $0.zone, hotelInside: false) }
    }

    var zone: Zone? { hits.first?.zone }
    var zoneIds: Set<String> { Set(hits.map(\.zone.id)) }

    var kind: Kind {
        if pedestrian != nil { return .pedestrian }
        guard let answer else { return .outside }
        switch answer.verdict {
        case .yes: return .open
        case .no: return .closed
        case .conditional: return .conditional
        case .unsure: return .unsure
        }
    }

    /// La risposta come in Viaggio: fuori dalle zone si entra, nell'area pedonale mai
    var verdict: Verdict {
        switch kind {
        case .outside: return .yes(reason: L("This address isn't inside any ZTL we know. You can drive there."))
        case .pedestrian: return .no(reason: L("It's a pedestrian area: cars can't drive in at any time, whatever the ZTL hours."))
        default: return answer?.verdict ?? .unsure(reason: "")
        }
    }

    /// Verde si entra, rosso no, ambra con una condizione o se non si sa
    var tint: Color {
        switch kind {
        case .outside, .open: return Theme.green
        case .closed, .pedestrian: return Theme.red
        case .conditional, .unsure: return Color(hex: 0xD99A00)
        }
    }

    /// Lo stesso colore, più acceso, per la mappa scura
    /// Il colore acceso di una zona secondo la SUA risposta (rosso, ambra, verde): lo stesso «neon» del posto
    static func neon(_ access: Access) -> Color {
        switch access {
        case .closed: Color(hex: 0xFF4D4D)
        case .conditional, .check: Color(hex: 0xF2C14E)
        case .open: Color(hex: 0x3DDC74)
        }
    }

    /// Il colore di una zona sulla mappa: acceso (neon) se contiene il posto cercato, quello di sempre se no.
    /// In tutti e due i casi è la risposta della zona, mai quella del posto
    static func zoneTint(_ access: Access, lit: Bool) -> Color {
        lit ? neon(access) : access.color
    }

    /// La striscia di Varco: lo stesso colore per zona, come umore (rosso, ambra, verde)
    static func mood(_ access: Access) -> Home2Answer.Mood {
        switch access {
        case .closed: .red
        case .conditional, .check: .amber
        case .open: .green
        }
    }

    var neon: Color {
        switch kind {
        case .outside, .open: return Color(hex: 0x3DDC74)
        case .closed, .pedestrian: return Color(hex: 0xFF4D4D)
        case .conditional, .unsure: return Color(hex: 0xF2C14E)
        }
    }

    var symbol: String {
        switch kind {
        case .outside, .open: return "checkmark"
        case .closed, .pedestrian: return "xmark"
        case .conditional: return "exclamationmark"
        case .unsure: return "questionmark"
        }
    }

    /// Le regole della zona vengono solo da fonti non ufficiali: la risposta si dice con prudenza
    var unofficial: Bool { pedestrian == nil && zone?.isUnofficial == true }

    /// La scritta del riquadro sulla mappa (in maiuscolo dove si mostra)
    var callout: String {
        if unofficial, kind == .open { return L("Probably yes") }
        if unofficial, kind == .closed { return L("Probably not") }
        switch kind {
        case .outside: return L("Outside the ZTL")
        case .pedestrian: return L("Pedestrian area · don't enter")
        case .closed: return L("ZTL active · don't enter")
        case .open: return answer?.gatesOn == true ? L("You can enter") : L("ZTL off · you can enter")
        case .conditional: return L("On one condition")
        case .unsure: return L("Not sure")
        }
    }

    /// «Attiva fino alle 20:00», «Spenta fino alle 7:30», «Sempre» per le aree pedonali
    var until: String? {
        if pedestrian != nil { return L("At any time") }
        guard let answer, let next = answer.nextChange else { return nil }
        // Ora italiana, come le frasi del motore delle regole (lo stesso testo del widget)
        let time = RuleEngine().clock(next, from: Date())
        return String(format: L(answer.gatesOn ? "Active until %@" : "Off until %@"), time)
    }

    /// «ZTL · Settore A» o «Fuori dalla ZTL»
    var zoneLine: String {
        if let pedestrian { return String(format: L("Pedestrian area · %@"), pedestrian.name) }
        if let zone { return zone.kindLine }
        return L("Outside the ZTL")
    }
}

extension PlaceCheck {
    /// Con la risposta già pronta (test e anteprime)
    init(place: Place, hits: [(city: City, zone: Zone)], pedestrian: PedestrianArea? = nil, answer: Answer?) {
        self.place = place
        self.hits = hits
        self.pedestrian = pedestrian
        self.answer = answer
    }
}
