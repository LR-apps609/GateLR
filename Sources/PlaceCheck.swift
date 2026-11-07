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

    /// La risposta come in Viaggio: fuori dalle zone di una città che conosciamo si entra (grigio, 1.20.4), nell'area pedonale mai
    var verdict: Verdict {
        switch kind {
        case .uncovered: return .unsure(reason: L("We don't know the ZTLs of this place. Check the signs at the entrance."))
        case .outside: return .yes(reason: L("This address isn't inside any ZTL we know. You can drive there."))
        case .pedestrian: return .no(reason: L("It's a pedestrian area: cars can't drive in at any time, whatever the ZTL hours."))
        default: return answer?.verdict ?? .unsure(reason: "")
        }
    }

    /// Verde si entra, rosso no, ambra con una condizione o se non si sa; neutro se non conosciamo il posto.
    /// 1.20.4: fuori dalle zone di una città che conosciamo grigio (Theme.outside), mai verde
    var tint: Color {
        if hedged { return Color(hex: 0xD99A00) }
        switch kind {
        case .uncovered: return Theme.muted
        case .outside: return Theme.outside
        case .open: return Theme.green
        case .closed, .pedestrian: return Theme.red
        case .conditional, .unsure: return Color(hex: 0xD99A00)
        }
    }

    /// 1.20.0 «Motore unico»: il colore della risposta per il posto, come sulla mappa. Area pedonale rossa, la zona che
    /// decide con i colori della mappa (fonte non ufficiale mai verde); nil = nessuna zona: fuori dalla ZTL in una città che
    /// conosciamo (grigio, 1.20.4) o un posto che non conosciamo (neutro). Mai verde senza una zona
    var access: Access? {
        if pedestrian != nil { return .closed }
        guard let answer, let hit else { return nil }
        return Access.of(answer, zone: hit.zone, status: hit.city.status)
    }

    /// 1.20.4: il nome del colore come nei casi di prova comuni (shared/engine-cases.json), lo stesso su Android
    /// (PlaceCheck.color) e sul sito (placeAnswer): red, yellow, green, grey (fuori dalla ZTL in una città coperta),
    /// neutral (un posto che non conosciamo)
    var colourName: String {
        if kind == .outside { return "grey" }
        switch access {
        case nil: return "neutral"
        case .closed?: return "red"
        case .conditional?, .check?: return "yellow"
        case .open?, .off?: return "green"          // 1.20.1: ZTL spenta = verde
        }
    }

    /// Il colore di una zona sulla mappa (MapTheme): il bordo nel colore della SUA risposta, mai quella del posto
    static func zoneTint(_ access: Access, lit: Bool) -> Color { MapTheme.tone(access).line }

    var neon: Color {
        if hedged { return Color(hex: 0xF2C14E) }
        switch kind {
        case .uncovered: return Color(hex: 0xA9B3D1)
        case .outside: return Color(hex: 0xAEB4BC)       // 1.20.4: grigio, mai verde
        case .open: return Color(hex: 0x3DDC74)
        case .closed, .pedestrian: return Color(hex: 0xFF4D4D)
        case .conditional, .unsure: return Color(hex: 0xF2C14E)
        }
    }

    var symbol: String {
        if hedged { return "questionmark" }
        switch kind {
        case .uncovered: return "questionmark"
        // 1.20.4: fuori dalla ZTL una forma neutra (il trattino), non la spunta del «sì» di una zona
        case .outside: return "minus"
        case .open: return "checkmark"
        case .closed, .pedestrian: return "xmark"
        case .conditional: return "exclamationmark"
        case .unsure: return "questionmark"
        }
    }

    /// 1.19.1 «l'area pedonale vince»: la risposta da mostrare in Viaggio. Nell'area pedonale sempre «no», ma con lo
    /// stato VERO dei varchi della zona all'ora scelta (prima «ZTL attiva» era scritto fisso, anche alle 23:58 con la
    /// ZTL 7–20); fuori dalle aree pedonali la risposta della zona che decide
    var shownAnswer: Answer? {
        guard pedestrian != nil else { return answer }
        return Answer(verdict: verdict, gatesOn: answer?.gatesOn ?? false, nextChange: nil)
    }

    /// La scheda verde «Fuori dalla ZTL. Puoi andarci»: solo fuori da ogni zona E da ogni area pedonale, in una città
    /// che conosciamo (1.19.1: in via Galliera a Bologna, fuori dalle zone, c'era il riquadro rosso e sotto il verde)
    var showsOutside: Bool { hits.isEmpty && pedestrian == nil && covered }

    /// La risposta è «no» (rosso): «Parcheggia fuori e cammina» diventa l'azione principale (1.19.1)
    var parkingFirst: Bool { kind == .closed || kind == .pedestrian }

    /// Le regole della zona vengono solo da fonti non ufficiali: la risposta si dice con prudenza
    var unofficial: Bool { pedestrian == nil && zone?.isUnofficial == true }

    /// 1.20.3 «Parole»: il titolo fisso della risposta per il posto (lo stesso in Varco, Mappa e Viaggio). Area pedonale
    /// «Non entrare», fuori dalle zone di una città che conosciamo «Puoi entrare», fuori copertura «Non conosciamo questo
    /// posto», un «sì» da fonte non ufficiale «Controlla il cartello»
    var word: AnswerWord {
        switch kind {
        case .uncovered: return .unknownPlace
        case .outside: return .enter
        case .closed, .pedestrian: return .dontEnter
        case .open: return hedged ? .checkSign : .enter
        case .conditional: return .condition
        case .unsure: return .checkSign
        }
    }

    /// La frase sotto il titolo (mai titolo): la condizione, il motivo del dubbio, «Probabilmente sì · fonte non ufficiale»
    var explanation: String? {
        switch kind {
        case .uncovered: return L("We don't know the ZTLs of this place. Check the signs at the entrance.")
        case .conditional:
            if case .conditional(_, let condition)? = answer?.verdict { return condition }
            return nil
        case .unsure:
            if case .unsure(let reason)? = answer?.verdict { return reason }
            return nil
        case .open, .closed: return unofficial ? answer?.verdict.unofficialNote(unofficial: true) : nil
        case .outside, .pedestrian: return nil
        }
    }

    /// La scritta del riquadro sulla mappa (in maiuscolo dove si mostra): il titolo fisso (1.20.3; prima «ZTL attiva ·
    /// non entrare», «Probabilmente sì»…). Lo stato dei varchi è nella riga sotto («Attiva fino alle 20:00»)
    var callout: String { word.title }

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
