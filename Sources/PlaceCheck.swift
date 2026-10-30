import SwiftUI

/// La risposta per un posto cercato, calcolata una volta per disegno: in che zone è, se è area pedonale,
/// se adesso si entra. La usano la prima pagina e la mappa, con le stesse regole di Viaggio.
struct PlaceCheck {
    /// 1.19.0: «uncovered» = il posto non è in nessuna città che conosciamo (City.coverage): non diciamo «fuori dalla ZTL»
    enum Kind { case uncovered, outside, open, closed, conditional, unsure, pedestrian }

    let place: Place
    /// Le zone che contengono il posto, dalla più piccola
    let hits: [(city: City, zone: Zone)]
    let pedestrian: PedestrianArea?
    /// La risposta della zona che decide (la peggiore tra tutte, vedi `decider`)
    let answer: Answer?
    /// La risposta di ogni zona in `hits`, nello stesso ordine
    let answers: [Answer]
    /// L'indice in `hits` della zona che decide: la risposta peggiore (no > condizione > non sicuro > sì), a parità la
    /// più piccola. Prima contava solo la più piccola: a Palazzo Vecchio di notte un diesel Euro 1 riceveva «Entra pure.»
    /// dal Settore A spento, mentre lo Scudo Verde (sempre attivo) lo vieta
    let decider: Int?
    /// Il posto è in una città che conosciamo
    let covered: Bool

    @MainActor
    init(_ place: Place, store: Store, at date: Date = Date()) {
        let hits = store.zones(at: place.location)
        let pedestrian = store.pedestrianArea(at: place.location)
        // L'hotel registra la targa solo se il posto è il tuo hotel (1.19.0, niente più «hotelInside» nascosto)
        let hotel = store.isHotel(place)
        self.init(place: place, hits: hits, pedestrian: pedestrian,
                  answers: hits.map { store.answer(at: date, zone: $0.zone, hotelInside: hotel) },
                  covered: !hits.isEmpty || pedestrian != nil || store.covers(place.location))
    }

    /// Con le risposte già pronte (test e anteprime): una per zona di `hits`
    init(place: Place, hits: [(city: City, zone: Zone)], pedestrian: PedestrianArea? = nil, answers: [Answer], covered: Bool = true) {
        self.place = place
        self.hits = hits
        self.pedestrian = pedestrian
        self.answers = answers
        self.covered = covered || !hits.isEmpty || pedestrian != nil
        let d = Self.worst(hits.map(\.zone), answers)
        decider = d
        answer = d.map { answers[$0] }
    }

    /// La zona la cui risposta è la peggiore (come si mostra: un «sì» da fonte non ufficiale conta come «non sicuro»);
    /// a parità vince la prima, cioè la più piccola
    static func worst(_ zones: [Zone], _ answers: [Answer]) -> Int? {
        var best: Int?
        for i in answers.indices where i < zones.count {
            let s = answers[i].verdict.shown(unofficial: zones[i].isUnofficial).severity
            if best.map({ s > answers[$0].verdict.shown(unofficial: zones[$0].isUnofficial).severity }) ?? true { best = i }
        }
        return best
    }

    /// La zona che decide la risposta, con la sua città (per il nome, la fonte, «Perché?» e l'avviso «non ufficiale»)
    var hit: (city: City, zone: Zone)? { decider.map { hits[$0] } ?? hits.first }
    var zone: Zone? { hit?.zone }
    var city: City? { hit?.city }
    var zoneIds: Set<String> { Set(hits.map(\.zone.id)) }

    var kind: Kind {
        if pedestrian != nil { return .pedestrian }
        guard let answer else { return covered ? .outside : .uncovered }
        switch answer.verdict {
        case .yes: return .open
        case .no: return .closed
        case .conditional: return .conditional
        case .unsure: return .unsure
        }
    }

    /// Un «sì» da fonte non ufficiale: si mostra giallo con il «?» (1.19.0, mai un verde che non sappiamo)
    var hedged: Bool { unofficial && kind == .open }

    /// La risposta come in Viaggio: fuori dalle zone di una città che conosciamo si entra, nell'area pedonale mai
    var verdict: Verdict {
        switch kind {
        case .uncovered: return .unsure(reason: L("We don't know the ZTLs of this place. Check the signs at the entrance."))
        case .outside: return .yes(reason: L("This address isn't inside any ZTL we know. You can drive there."))
        case .pedestrian: return .no(reason: L("It's a pedestrian area: cars can't drive in at any time, whatever the ZTL hours."))
        default: return answer?.verdict ?? .unsure(reason: "")
        }
    }

    /// Verde si entra, rosso no, ambra con una condizione o se non si sa; neutro se non conosciamo il posto
    var tint: Color {
        if hedged { return Color(hex: 0xD99A00) }
        switch kind {
        case .uncovered: return Theme.muted
        case .outside, .open: return Theme.green
        case .closed, .pedestrian: return Theme.red
        case .conditional, .unsure: return Color(hex: 0xD99A00)
        }
    }

    /// Il colore di una zona sulla mappa (MapTheme): il bordo nel colore della SUA risposta, mai quella del posto
    static func zoneTint(_ access: Access, lit: Bool) -> Color { MapTheme.tone(access).line }

    var neon: Color {
        if hedged { return Color(hex: 0xF2C14E) }
        switch kind {
        case .uncovered: return Color(hex: 0xA9B3D1)
        case .outside, .open: return Color(hex: 0x3DDC74)
        case .closed, .pedestrian: return Color(hex: 0xFF4D4D)
        case .conditional, .unsure: return Color(hex: 0xF2C14E)
        }
    }

    var symbol: String {
        if hedged { return "questionmark" }
        switch kind {
        case .uncovered: return "questionmark"
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
        case .uncovered: return L("We don't know this place")
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

    /// «ZTL · Settore A» (la zona che decide), «Fuori dalla ZTL» o «Non conosciamo le ZTL di questo posto»
    var zoneLine: String {
        if let pedestrian { return String(format: L("Pedestrian area · %@"), pedestrian.name) }
        if let zone { return zone.kindLine }
        return covered ? L("Outside the ZTL") : L("We don't know the ZTLs of this place")
    }
}

extension PlaceCheck {
    /// Con la risposta già pronta (test e anteprime): la stessa risposta per tutte le zone
    init(place: Place, hits: [(city: City, zone: Zone)], pedestrian: PedestrianArea? = nil, answer: Answer?, covered: Bool = true) {
        self.init(place: place, hits: hits, pedestrian: pedestrian,
                  answers: answer.map { a in hits.map { _ in a } } ?? [], covered: covered)
    }
}
