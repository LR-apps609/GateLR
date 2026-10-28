import MapKit
import Network
import SwiftUI

/// Prima pagina, «il problema e la soluzione», con la stessa inquadratura di Firenze per tutti i passi:
/// 1. Di giorno (martedì 11:30, mappa chiara), «La strada più diretta»: il pannello dice VARCO ATTIVO dal primo
///    fotogramma, la freccia va dritta al ristorante dentro la ZTL dal varco di via Alfieri, lampo e verbale.
///    «Evita multe con GateLR»
/// 2. Ancora di giorno, «Con GateLR»: intorno lungo i viali fino al parcheggio che sceglierebbe l'app, fuori dalla ZTL;
///    «Adesso una passeggiata…» fa comparire le impronte fino al ristorante (stessa pagina), poi «E se entro la sera?»
/// 3. La sera (martedì 21:00, mappa notte): la ZTL diventa verde, il pannello dice VARCO NON ATTIVO, la freccia entra
///    dritta fino al ristorante senza multa; al posto del verbale la scheda «Alle 21:00 il varco è spento…».
/// Giorno e ora sono veri per il Settore A (RuleEngine, Resources/Cities/firenze.json): vedi IntroScene.dayMoment.
@MainActor final class IntroDrive: ObservableObject {
    enum Step: Int { case direct = 1, park, walk, evening }
    enum Phase { case waiting, moving, done }
    @Published private(set) var step: Step = .direct
    @Published private(set) var phase: Phase = .waiting
    /// VARCO ATTIVO fin dal primo fotogramma: di giorno il varco è acceso, prima ancora che la freccia arrivi
    @Published var panel: LEDState = .active
    @Published var flash = 0.0
    @Published var showFine = false
    let direct = IntroPath(IntroScene.direct)
    let toParking = IntroPath(IntroScene.toParking)
    let walk = IntroPath(IntroScene.walk)
    /// Le impronte del tratto a piedi: una ogni 55 m, alternate di 6 m a sinistra e a destra (si vedono anche da lontano)
    let footprints = IntroPath(IntroScene.walk).footprints(every: 55, side: 6)
    /// Il passo 1 (circa 5 s): fino al varco, una breve sosta sotto il pannello, poi dentro fino al ristorante
    static let toGate = 1.7
    static let gatePause = 0.6
    static let afterGate = 2.6
    static let directSeconds = toGate + gatePause + afterGate
    /// Il passo 2, lungo i viali fino al parcheggio
    static let parkSeconds = 4.6
    /// Il passo 3, le impronte
    static let walkSeconds = 3.2
    /// La sera, dritto fino al ristorante senza fermarsi al varco
    static let eveningSeconds = 4.6
    /// Dove sta il varco lungo la strada dritta (frazione)
    let gateAt = IntroPath(IntroScene.direct).fraction(near: IntroScene.gatePoint)
    var reduceMotion = false
    private(set) var stepStart = Date.distantFuture
    private var task: Task<Void, Never>?

    /// L'andatura: parte e si ferma morbida
    nonisolated static func ease(_ t: Double) -> Double {
        let x = min(max(t, 0), 1)
        return 0.35 * x + 0.65 * x * x * (3 - 2 * x)
    }

    /// Di sera: la mappa notte, la ZTL verde
    var evening: Bool { step == .evening }

    /// Il percorso in auto del passo (a piedi l'auto resta al parcheggio)
    var path: IntroPath { step == .direct || step == .evening ? direct : toParking }

    var seconds: Double {
        switch step {
        case .direct: Self.directSeconds
        case .park: Self.parkSeconds
        case .walk: Self.walkSeconds
        case .evening: Self.eveningSeconds
        }
    }

    /// La frazione del passo dopo t secondi (nel passo 1 rallenta fino al varco, si ferma, riparte)
    func fraction(after t: Double) -> Double {
        switch step {
        case .direct:
            if t < Self.toGate { return gateAt * Self.ease(t / Self.toGate) }
            if t < Self.toGate + Self.gatePause { return gateAt }
            return gateAt + (1 - gateAt) * Self.ease((t - Self.toGate - Self.gatePause) / Self.afterGate)
        case .park: return Self.ease(t / Self.parkSeconds)
        case .walk: return min(max(t / Self.walkSeconds, 0), 1)
        case .evening: return Self.ease(t / Self.eveningSeconds)
        }
    }

    func fraction(_ d: Date) -> Double {
        switch phase {
        case .waiting: 0
        case .moving: reduceMotion ? 0 : fraction(after: d.timeIntervalSince(stepStart))
        case .done: 1
        }
    }

    /// Dove si trova la freccia in quel momento: calcolato a ogni fotogramma dello schermo
    func car(at d: Date) -> CLLocationCoordinate2D {
        step == .walk ? IntroScene.toParking[IntroScene.toParking.count - 1] : path.point(fraction(d))
    }

    /// Dove guarda la freccia (gradi da nord)
    func heading(at d: Date) -> Double {
        let p = path, f = step == .walk ? 1 : fraction(d)
        let delta = 12 / max(p.length, 1)
        return p.point(max(f - delta, 0)).notteBearing(to: p.point(min(f + delta, 1)))
    }

    /// Una linea sulla mappa: quanto se ne vede (0…1) e con che opacità
    struct Line { var progress: Double; var opacity: Double }
    struct Lines { var direct: Line; var park: Line; var footprints: Int }

    /// Le linee di tutte le mappe: quella del passo si disegna dietro la freccia; la strada dritta resta più tenue
    /// nei passi 2 e 3, per il confronto; a piedi compaiono le impronte una dopo l'altra; la sera c'è solo la strada dritta
    func lines(at d: Date) -> Lines {
        let f = fraction(d)
        switch step {
        case .evening:
            return Lines(direct: Line(progress: f, opacity: 1), park: Line(progress: 0, opacity: 0), footprints: 0)
        default:
            let shown = step == .walk ? Int((Double(footprints.count) * f).rounded(.up)) : 0
            return Lines(direct: Line(progress: step == .direct ? f : 1, opacity: step == .direct ? 1 : 0.3),
                         park: Line(progress: step == .direct ? 0 : step == .park ? f : 1, opacity: 1),
                         footprints: min(shown, footprints.count))
        }
    }

    /// Il parcheggio si accende quando la freccia ci arriva
    var parked: Bool { step == .walk || (step == .park && phase == .done) }

    /// La scheda della sera al posto del verbale
    var showEvening: Bool { step == .evening && phase == .done }

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            // Il tempo per le prime mattonelle della mappa
            try? await Task.sleep(for: .milliseconds(1200))
            await self?.run(.direct)
        }
    }

    func stop() { task?.cancel() }

    /// Il pulsante del passo: «Evita multe con GateLR» dopo il verbale, «Adesso una passeggiata…» al parcheggio,
    /// «E se entro la sera?» dopo le impronte
    func advance() {
        guard phase == .done else { return }
        switch step {
        case .direct: task = Task { [weak self] in await self?.run(.park) }
        case .park: task = Task { [weak self] in await self?.run(.walk) }
        case .walk: task = Task { [weak self] in await self?.run(.evening) }
        case .evening: break
        }
    }

    private func run(_ next: Step) async {
        withAnimation(.easeInOut(duration: 0.35)) {
            showFine = false
            step = next
        }
        // Di giorno il varco resta acceso (anche mentre si gira intorno); la sera è spento fin dall'inizio
        switch next {
        case .direct, .park: panel = .active
        case .walk: break
        case .evening: panel = .off
        }
        stepStart = Date()
        phase = .moving
        let quick = 1.4
        switch next {
        case .direct:
            // Il pannello si accende alla fine della sosta sotto il varco, quando la freccia riparte
            let gateTime = reduceMotion ? 1.0 : Self.toGate + Self.gatePause
            try? await Task.sleep(for: .seconds(gateTime))
            guard !Task.isCancelled else { return }
            hitGate()
            try? await Task.sleep(for: .seconds((reduceMotion ? quick : Self.directSeconds) - gateTime + 0.35))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? .easeInOut(duration: 0.4) : .spring(response: 0.55, dampingFraction: 0.78)) {
                phase = .done
                showFine = true
            }
            await autoplay(after: 2.6)
        case .park:
            try? await Task.sleep(for: .seconds(reduceMotion ? quick : Self.parkSeconds))
            guard !Task.isCancelled else { return }
            panel = .noFine
            withAnimation(.easeInOut(duration: 0.4)) { phase = .done }
            await autoplay(after: 1.8)
        case .walk:
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.3 : Self.walkSeconds))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.4)) { phase = .done }
            await autoplay(after: 1.8)
        case .evening:
            try? await Task.sleep(for: .seconds(reduceMotion ? quick : Self.eveningSeconds))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? .easeInOut(duration: 0.4) : .spring(response: 0.55, dampingFraction: 0.78)) {
                phase = .done
            }
        }
    }

    /// Nel video (-intro2Autoplay) si va avanti da soli con i tempi di una persona
    private func autoplay(after seconds: Double) async {
        guard IntroAutoplay.on else { return }
        try? await Task.sleep(for: .seconds(seconds))
        guard !Task.isCancelled else { return }
        advance()
    }

    private func hitGate() {
        guard !reduceMotion else { return }
        withAnimation(.easeOut(duration: 0.06)) { flash = 0.85 }
        withAnimation(.easeOut(duration: 0.7).delay(0.08)) { flash = 0 }
    }
}

/// Il colore della strada percorsa dalla freccia, in tutti e tre i passi: azzurro acceso (il rosso è della ZTL)
enum IntroRouteColor {
    /// Il cuore più scuro della 1.15: si vede anche sulla mappa chiara del giorno
    static let glowHex: UInt32 = 0x2FD3FF
    static let coreHex: UInt32 = 0x1E86FF
    static let glow = Color(hex: 0x2FD3FF)
    static let core = Color(hex: 0x1E86FF)
}

struct IntroDriveSlide: View {
    @EnvironmentObject var store: Store
    var next: () -> Void
    @StateObject private var drive = IntroDrive()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scene: IntroScene?
    /// L'altezza di quello che c'è in basso (verbale, suggerimento, pulsante): il velo e il logo di Mapbox stanno sopra
    @State private var bottomHeight: CGFloat = 0
    /// Quale mappa: Mapbox 3D (la nuova), la mappa di Apple se Mapbox non si carica (-intro2MapKit per provarla),
    /// il disegno sullo stesso fondo blu notte senza rete (o con -intro2Fallback)
    enum Engine { case mapbox, mapkit, drawing }
    @State private var engine: Engine = {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("-intro2Fallback") ? .drawing : args.contains("-intro2MapKit") || !NotteMap.hasToken ? .mapkit : .mapbox
    }()

    var body: some View {
        ZStack {
            Notte.navy.ignoresSafeArea()
            if let scene {
                switch engine {
                case .drawing: IntroFallbackMap(scene: scene, drive: drive)
                case .mapkit: IntroLiveMap(scene: scene, drive: drive)
                case .mapbox:
                    // Logo e attribuzione di Mapbox sopra il pannello in basso e sopra il velo (che sfuma in 90 punti)
                    IntroMapboxMap(scene: scene, drive: drive, reduceMotion: reduceMotion, ornamentBottom: bottomHeight + 12 + 64,
                                   onReady: { drive.start() },
                                   onFail: { engine = .mapkit; drive.start() })
                        .ignoresSafeArea()
                        .accessibilityHidden(true)
                }
            }
            // Il blu notte sopra il titolo e sotto il pannello in basso, perché il testo resti leggibile sulla mappa
            VStack(spacing: 0) {
                // Più pieno di giorno: sulla mappa chiara il titolo bianco altrimenti si legge poco
                LinearGradient(stops: [.init(color: Notte.navy, location: 0), .init(color: Notte.navy.opacity(0.92), location: 0.55),
                                       .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 200)
                    .ignoresSafeArea(edges: .top)
                Spacer()
                LinearGradient(colors: [.clear, Notte.navy.opacity(0.85), Notte.navy], startPoint: .top, endPoint: .bottom)
                    .frame(height: bottomHeight + 12 + 90)
                    .ignoresSafeArea(edges: .bottom)
            }
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.4), value: bottomHeight)

            Color.white.opacity(drive.flash).ignoresSafeArea().allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                caption.padding(.top, 64)
                Spacer()
                bottom
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { bottomHeight = $0 }
            }
            .padding(.horizontal, 20).padding(.bottom, 12)
        }
        .sensoryFeedback(.warning, trigger: drive.flash > 0.5)
        .sensoryFeedback(.success, trigger: drive.panel == .noFine || drive.showEvening)
        .task {
            if scene == nil { scene = IntroScene.load(store) }
            drive.reduceMotion = reduceMotion
            if engine != .drawing, await IntroNetwork.isOffline() { engine = .drawing }
            // Mapbox fa partire la freccia quando lo stile è pronto (o passa alla mappa di Apple se non arriva)
            if engine != .mapbox { drive.start() }
        }
        .onChange(of: drive.phase) { _, phase in
            guard IntroAutoplay.on, phase == .done, drive.step == .evening else { return }
            Task { try? await Task.sleep(for: .milliseconds(2600)); next() }
        }
        .onDisappear { drive.stop() }
    }

    private var title: String {
        switch drive.step {
        case .direct: L("The most direct route")
        case .park: L("With GateLR")
        case .walk: L("Then a short walk")
        case .evening: L("And in the evening?")
        }
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 6) {
            IntroTitle(text: title)
                .id(drive.step)
                .transition(.opacity)
            if let scene {
                Text(verbatim: "\(scene.cityName) · \(scene.zoneName)")
                    .font(Notte.font(15, .semibold)).foregroundStyle(Notte.muted)
            }
            IntroClock(evening: drive.evening)
        }
    }

    @ViewBuilder private var bottom: some View {
        VStack(spacing: 14) {
            switch drive.step {
            case .direct:
                if drive.showFine, let scene {
                    FineNotice(scene: scene)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    IntroButton(title: L("Avoid fines with GateLR"), systemImage: "arrow.triangle.turn.up.right.diamond.fill",
                                identifier: "intro2.avoid") { drive.advance() }
                        .transition(.opacity)
                }
            case .park:
                IntroHint(systemImage: "parkingsign", text: L("GateLR: park outside the ZTL"))
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                if drive.phase == .done {
                    IntroButton(title: L("Now a short walk…"), systemImage: "figure.walk",
                                identifier: "intro2.park") { drive.advance() }
                        .transition(.opacity)
                }
            case .walk:
                IntroHint(systemImage: "figure.walk",
                          text: String(format: L("%lld min on foot, no fine"), IntroScene.walkMinutes))
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                if drive.phase == .done {
                    IntroButton(title: L("What if I drive in this evening?"), systemImage: "moon.fill",
                                identifier: "intro2.evening") { drive.advance() }
                        .transition(.opacity)
                }
            case .evening:
                if drive.showEvening {
                    EveningNotice()
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    IntroButton(title: L("Next"), identifier: "intro2.next1", action: next)
                        .transition(.opacity)
                }
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.3) : .spring(response: 0.5, dampingFraction: 0.85), value: drive.phase)
        .animation(.easeInOut(duration: 0.35), value: drive.step)
    }
}

/// Il momento della scena sotto il titolo: il sole e «martedì 11:30» di giorno, la luna e «martedì 21:00» la sera
struct IntroClock: View {
    var evening: Bool
    static func symbol(evening: Bool) -> String { evening ? "moon" + ".fill" : "sun.max" + ".fill" }
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: Self.symbol(evening: evening))
                .foregroundStyle(evening ? Color(hex: 0xC9D3FF) : Color(hex: 0xFFC83D))
                .symbolRenderingMode(.hierarchical)
            Text(verbatim: IntroScene.clock(evening ? IntroScene.nightMoment : IntroScene.dayMoment))
                .foregroundStyle(Notte.text)
                .contentTransition(.numericText())
        }
        .font(Notte.font(15, .bold))
        .padding(.horizontal, 11).frame(height: 30)
        .background(Notte.surface.opacity(0.85), in: Capsule())
        .overlay(Capsule().stroke(Notte.line, lineWidth: 1))
        .padding(.top, 4)
        .animation(.easeInOut(duration: 0.4), value: evening)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("intro2.clock")
    }
}

/// La sera, al posto del verbale: il varco è spento, si entra; e ogni ZTL ha i suoi orari
struct EveningNotice: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L("GATE OFF")).font(Notte.font(13, .bold)).kerning(1.5).foregroundStyle(Color(hex: 0x1E8A4C))
                Spacer()
                Image(systemName: "moon.fill").foregroundStyle(Color(hex: 0x5A5F70))
            }
            Text(String(format: L("At %@ the gate is off: you can drive in."), IntroScene.time(IntroScene.nightMoment)))
                .font(Notte.font(22, .bold)).foregroundStyle(Color(hex: 0x1B2033))
                .fixedSize(horizontal: false, vertical: true)
            Rectangle().fill(Color(hex: 0xD8D3C4)).frame(height: 1)
            Text(L("Every ZTL has its own hours: GateLR tells you before you set off."))
                .font(Notte.font(15)).foregroundStyle(Color(hex: 0x5A5F70))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(Notte.chalk, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 14).fill(Notte.ledGreen).frame(width: 6)
        }
        .shadow(color: .black.opacity(0.45), radius: 24, y: 10)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("intro2.evening.card")
    }
}

/// Il suggerimento di GateLR in basso: chiaro su blu notte, con l'icona nel cerchio rosso del marchio
struct IntroHint: View {
    var systemImage: String
    var text: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Notte.action, in: Circle())
            Text(text).font(Notte.font(17, .bold)).foregroundStyle(Notte.navy)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Notte.chalk, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 18, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("intro2.hint")
    }
}

/// Il verbale che arriva a casa: importo vero della multa per l'ingresso in ZTL (Resources/Rules/fine.json)
struct FineNotice: View {
    var scene: IntroScene
    private var amount: String {
        guard let f = FineInfo.bundled else { return "[importo]" }
        func euro(_ n: Int) -> String { n.formatted(.currency(code: "EUR").precision(.fractionLength(0))) }
        return "\(euro(f.min)) – \(euro(f.max))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L("FINE NOTICE")).font(Notte.font(13, .bold)).kerning(1.5).foregroundStyle(Color(hex: 0xB3261E))
                Spacer()
                Text(verbatim: "Art. 7 C.d.S.").font(Notte.font(13, .semibold)).foregroundStyle(Color(hex: 0x5A5F70))
            }
            Text(L("Entering a ZTL without a permit")).font(Notte.font(17, .semibold)).foregroundStyle(Color(hex: 0x1B2033))
            Text(verbatim: amount).font(Notte.font(40, .black)).foregroundStyle(Color(hex: 0x1B2033))
                .minimumScaleFactor(0.6).lineLimit(1)
            Rectangle().fill(Color(hex: 0xD8D3C4)).frame(height: 1)
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: "\(scene.gateName) · \(IntroScene.time(IntroScene.dayMoment))").font(Notte.font(14, .semibold)).foregroundStyle(Color(hex: 0x5A5F70))
                Spacer()
            }
            Text(L("For each day you drive in. It reaches you months later."))
                .font(Notte.font(14)).foregroundStyle(Color(hex: 0x5A5F70))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(Notte.chalk, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 14).fill(Notte.action).frame(width: 6)
        }
        .rotationEffect(.degrees(-1.5))
        .shadow(color: .black.opacity(0.45), radius: 24, y: 10)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("intro2.fine")
    }
}


// MARK: La mappa di Apple (MapKit 3D), se Mapbox non c'è

private struct IntroLiveMap: View {
    var scene: IntroScene
    @ObservedObject var drive: IntroDrive
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var position: MapCameraPosition = .camera(IntroCamera.camera)
    /// -intro2Standard: la mappa normale con gli edifici 3D invece del satellite 3D (Flyover)
    private let standard = ProcessInfo.processInfo.arguments.contains("-intro2Standard")

    /// Le linee si ridisegnano a scatti di 1/30 del percorso; la freccia invece si muove a ogni fotogramma
    private func step(_ f: Double) -> Double { f >= 1 ? 1 : (f * 30).rounded(.up) / 30 }

    private var paused: Bool { reduceMotion || drive.phase == .waiting || drive.phase == .done }

    var body: some View {
        TimelineView(.animation(paused: paused)) { tl in
            map(at: tl.date)
        }
        .accessibilityHidden(true)
    }

    private func map(at now: Date) -> some View {
        let lines = drive.lines(at: now)
        return Map(position: $position, interactionModes: []) {
            // Fuori dalla ZTL: un velo che spegne i colori (chiaro di giorno, grigio-blu la sera); dentro resta il colore
            // della zona: rosso di giorno (attiva), verde la sera (spenta)
            MapPolygon(IntroScene.outside(scene))
                .foregroundStyle(drive.evening ? Color(hex: 0x1B2236).opacity(0.5) : Color.white.opacity(0.25))
            ForEach(scene.zones.indices, id: \.self) { i in
                MapPolygon(coordinates: scene.zones[i])
                    .foregroundStyle(zoneColor.opacity(0.2))
                MapPolyline(coordinates: scene.zones[i] + scene.zones[i].prefix(1))
                    .stroke(zoneColor.opacity(0.3), style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
                MapPolyline(coordinates: scene.zones[i] + scene.zones[i].prefix(1))
                    .stroke(zoneColor, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
            }
            route(drive.direct, lines.direct, glow: IntroRouteColor.glow, core: IntroRouteColor.core)
            route(drive.toParking, lines.park, glow: IntroRouteColor.glow, core: IntroRouteColor.core)
            ForEach(0..<lines.footprints, id: \.self) { i in
                let fp = drive.footprints[i]
                Annotation("", coordinate: fp.coordinate, anchor: .center) {
                    IntroFootprintMark(left: fp.left)
                        .rotationEffect(.degrees(fp.bearing - IntroCamera.heading))
                        .transition(.scale.combined(with: .opacity))
                }
                .annotationTitles(.hidden)
            }

            Annotation("", coordinate: scene.gate, anchor: .bottom) {
                GateSign(state: drive.panel)
            }
            .annotationTitles(.hidden)
            Annotation("", coordinate: IntroScene.restaurant, anchor: .bottom) {
                IntroPlacePin(kind: .restaurant)
            }
            .annotationTitles(.hidden)
            Annotation("", coordinate: IntroScene.parking, anchor: .bottom) {
                IntroPlacePin(kind: .parking, lit: drive.parked)
            }
            .annotationTitles(.hidden)
            Annotation("", coordinate: drive.car(at: now), anchor: .center) {
                IntroArrow(glow: IntroRouteColor.glow)
                    .rotationEffect(.degrees(drive.heading(at: now) - IntroCamera.heading))
            }
            .annotationTitles(.hidden)
        }
        // Di giorno la mappa chiara; la sera il satellite 3D scuro con il velo blu notte (o la mappa normale con -intro2Standard)
        .mapStyle(!drive.evening || standard ? .standard(elevation: .realistic, emphasis: .muted, pointsOfInterest: .excludingAll)
                                             : .hybrid(elevation: .realistic, pointsOfInterest: .excludingAll))
        .environment(\.colorScheme, drive.evening ? .dark : .light)
        .mapControlVisibility(.hidden)
        .overlay(Notte.navy.opacity(drive.evening && !standard ? 0.22 : 0).allowsHitTesting(false))
        .ignoresSafeArea()
    }

    private var zoneColor: Color { drive.evening ? Notte.ledGreen : Notte.ledRed }

    /// Un percorso con l'alone, sopra gli edifici e le scritte (si deve vedere anche sul 3D)
    @MapContentBuilder
    private func route(_ path: IntroPath, _ line: IntroDrive.Line, glow: Color, core: Color) -> some MapContent {
        if line.progress > 0.001 && line.opacity > 0.01 {
            MapPolyline(coordinates: path.prefix(step(line.progress)))
                .stroke(glow.opacity(line.opacity * 0.4), style: StrokeStyle(lineWidth: 20, lineCap: .round, lineJoin: .round))
                .mapOverlayLevel(level: .aboveLabels)
            MapPolyline(coordinates: path.prefix(step(line.progress)))
                .stroke(core.opacity(line.opacity), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                .mapOverlayLevel(level: .aboveLabels)
        }
    }
}

/// L'inquadratura della mappa di Apple e del disegno di riserva: la stessa di Mapbox (ferma, stessa direzione e inclinazione)
enum IntroCamera {
    /// 150 m più avanti del centro di Mapbox: le etichette alte del ristorante e del parcheggio restano
    /// sotto il titolo (con MapKit e con il disegno la scena sta un po' più in alto)
    static let frame = CLLocationCoordinate2D(latitude: 43.7785, longitude: 11.2571)
    static let heading = IntroMapboxMap.bearing
    static let pitch = IntroMapboxMap.pitch
    /// MapKit misura la distanza della camera, non lo zoom: circa la stessa porzione di città dello zoom 13,95 di Mapbox
    static let distance = 5400.0

    static var camera: MapCamera {
        MapCamera(centerCoordinate: frame, distance: distance, heading: heading, pitch: pitch)
    }
}

// MARK: Il disegno di riserva (senza rete)

/// La stessa ZTL e gli stessi percorsi, proiettati a mano con la stessa inquadratura della mappa
private struct IntroFallbackMap: View {
    var scene: IntroScene
    @ObservedObject var drive: IntroDrive
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// L'Arno nel centro, a grandi linee: basta per riconoscere Firenze
    private static let arno: [CLLocationCoordinate2D] = IntroScene.coords([
        (43.7748, 11.2380), (43.7718, 11.2448), (43.7693, 11.2497), (43.7680, 11.2531),
        (43.7672, 11.2566), (43.7660, 11.2612), (43.7641, 11.2662), (43.7622, 11.2722), (43.7605, 11.2790),
    ])
    /// La proiezione a mano è più larga di quella vera: un centro e una distanza propri, per avere tutta la scena
    private static let center = CLLocationCoordinate2D(latitude: 43.7786, longitude: 11.2575)
    private static let duomo = CLLocationCoordinate2D(latitude: 43.77310, longitude: 11.25600)
    private static let santaCroce = CLLocationCoordinate2D(latitude: 43.76858, longitude: 11.26225)

    var body: some View {
        TimelineView(.animation(paused: reduceMotion || drive.phase == .waiting || drive.phase == .done)) { tl in
            GeometryReader { g in
                let pr = IntroProjector(center: Self.center, heading: IntroCamera.heading, pitch: IntroCamera.pitch,
                                        distance: 3800, size: g.size)
                ZStack {
                    // Di giorno un fondo chiaro come la carta di una mappa; la sera il blu notte della pagina
                    if !drive.evening { Color(hex: 0xE9EDF3) }
                    Canvas { ctx, _ in draw(ctx, pr, tl.date) }
                    landmark("Duomo", pr.point(Self.duomo))
                    landmark("Santa Croce", pr.point(Self.santaCroce))
                    GateSign(state: drive.panel)
                        .position(pr.point(scene.gate)).offset(y: -30)
                    IntroPlacePin(kind: .restaurant)
                        .position(pr.point(IntroScene.restaurant)).offset(y: -IntroPlacePin.size.height / 2)
                    IntroPlacePin(kind: .parking, lit: drive.parked)
                        .position(pr.point(IntroScene.parking)).offset(y: -IntroPlacePin.size.height / 2)
                    IntroArrow(glow: IntroRouteColor.glow)
                        .rotationEffect(.degrees(drive.heading(at: tl.date) - IntroCamera.heading))
                        .position(pr.point(drive.car(at: tl.date)))
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func landmark(_ name: String, _ p: CGPoint) -> some View {
        VStack(spacing: 3) {
            Circle().fill(Notte.muted).frame(width: 5, height: 5)
            Text(verbatim: name).font(Notte.font(11, .semibold))
                .foregroundStyle(drive.evening ? Notte.muted.opacity(0.8) : Color(hex: 0x5A6378))
        }
        .position(x: p.x, y: p.y + 8)
    }

    private func draw(_ ctx: GraphicsContext, _ pr: IntroProjector, _ now: Date) {
        // Una trama di isolati ogni 110 m, che si perde verso l'orizzonte
        var grid = Path()
        let step = 110.0 / 111_320
        let c = Self.center
        let k = cos(c.latitude * .pi / 180)
        for i in -16...16 {
            let lat = c.latitude + Double(i) * step
            grid.move(to: pr.point(.init(latitude: lat, longitude: c.longitude - 16 * step / k)))
            grid.addLine(to: pr.point(.init(latitude: lat, longitude: c.longitude + 16 * step / k)))
            let lon = c.longitude + Double(i) * step / k
            grid.move(to: pr.point(.init(latitude: c.latitude - 16 * step, longitude: lon)))
            grid.addLine(to: pr.point(.init(latitude: c.latitude + 16 * step, longitude: lon)))
        }
        let day = !drive.evening
        ctx.stroke(grid, with: .color(day ? Color(hex: 0xC6CDDA) : Notte.line.opacity(0.7)), lineWidth: 1)
        ctx.stroke(pr.path(Self.arno), with: .color(day ? Color(hex: 0x9EC4EA) : Color(hex: 0x1C3A6E)),
                   style: StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round))

        for perimeter in scene.zones { drawZone(ctx, pr.path(perimeter, closed: true)) }
        drawRoutes(ctx, pr, now)
    }

    /// Rossa di giorno (attiva), verde la sera (spenta)
    private func drawZone(_ ctx: GraphicsContext, _ zone: Path) {
        let color = drive.evening ? Notte.ledGreen : Notte.ledRed
        ctx.fill(zone, with: .color(color.opacity(0.14)))
        var glow = ctx
        glow.addFilter(.blur(radius: 8))
        glow.stroke(zone, with: .color(color.opacity(0.7)), lineWidth: 8)
        ctx.stroke(zone, with: .color(color), lineWidth: 2.5)
    }

    private func drawRoutes(_ ctx: GraphicsContext, _ pr: IntroProjector, _ now: Date) {
        var glow = ctx
        glow.addFilter(.blur(radius: 8))
        let round = StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
        let lines = drive.lines(at: now)
        for (path, line) in [(drive.direct, lines.direct), (drive.toParking, lines.park)] where line.progress > 0.001 {
            let p = pr.path(path.prefix(line.progress))
            glow.stroke(p, with: .color(IntroRouteColor.glow.opacity(line.opacity * 0.7)), lineWidth: 10)
            ctx.stroke(p, with: .color(IntroRouteColor.core.opacity(line.opacity)), style: round)
        }
        // Le impronte, girate verso dove si cammina
        for fp in drive.footprints.prefix(lines.footprints) {
            let c = pr.point(fp.coordinate)
            var foot = ctx
            foot.translateBy(x: c.x, y: c.y)
            foot.rotate(by: .degrees(fp.bearing - IntroCamera.heading))
            foot.fill(IntroFootprintShape(left: fp.left).path(in: CGRect(x: -5, y: -8, width: 10, height: 16)), with: .color(.white))
        }
    }
}

// MARK: Segni sulla mappa

/// Il pannello del varco su un palo sottile
struct GateSign: View {
    var state: LEDState
    var size: CGFloat = 18
    var body: some View {
        VStack(spacing: 0) {
            LEDPanel(state: state, size: size)
            Rectangle().fill(Color(hex: 0x6A7290)).frame(width: 2, height: 16)
            Circle().fill(state.dim ? Notte.muted : state.color).frame(width: 7, height: 7)
                .shadow(color: state.dim ? .clear : state.color, radius: 5)
        }
        .fixedSize()
    }
}

/// La freccia di navigazione (il segno «Freccia» di Account, nel colore scelto), muso in alto, con la luce sotto
struct IntroArrow: View {
    var glow: Color
    @AppStorage("vehicleColor") private var tint = VehicleColor.blue.rawValue
    var body: some View {
        ZStack {
            Circle().fill(glow.opacity(0.55)).frame(width: 34, height: 34).blur(radius: 9)
            VehicleMarkerView(marker: .arrow, tint: VehicleColor(rawValue: tint) ?? .blue, heading: 0)
                .scaleEffect(0.78)
        }
        .frame(width: 56, height: 56)
        .animation(.easeInOut(duration: 0.4), value: glow)
    }
}

/// Un'impronta di scarpa vista dall'alto, punta in alto: pianta, tallone e cinque dita (il destro è lo specchio del sinistro)
struct IntroFootprintShape: Shape {
    var left: Bool
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        func x(_ v: CGFloat) -> CGFloat { r.minX + (left ? v : 1 - v) * w }
        p.addEllipse(in: CGRect(x: x(0.5) - 0.3 * w, y: r.minY + 0.22 * h, width: 0.6 * w, height: 0.45 * h))
        p.addEllipse(in: CGRect(x: x(0.5) - 0.22 * w, y: r.minY + 0.7 * h, width: 0.44 * w, height: 0.28 * h))
        for (cx, cy, d) in [(0.3, 0.1, 0.24), (0.5, 0.06, 0.2), (0.66, 0.08, 0.17), (0.79, 0.13, 0.14), (0.88, 0.2, 0.12)] as [(CGFloat, CGFloat, CGFloat)] {
            p.addEllipse(in: CGRect(x: x(cx) - d * w / 2, y: r.minY + cy * h - d * w / 2 + 0.04 * h, width: d * w, height: d * w))
        }
        return p
    }
}

/// L'impronta sulla mappa: bianca con un filo d'ombra, così si vede sugli edifici e sulla zona rossa
struct IntroFootprintMark: View {
    var left: Bool
    var body: some View {
        IntroFootprintShape(left: left).fill(.white)
            .frame(width: 10, height: 16)
            .shadow(color: .black.opacity(0.7), radius: 1.5)
            .accessibilityHidden(true)
    }
}

/// I due posti della scena, più evidenti di tutto il resto: il ristorante (generico, nessun locale vero) e il parcheggio.
/// Solo il segno, senza scritte (1.16.4): forchetta e coltello nel cerchio arancione, la «P» nel quadrato blu (verde
/// quando la freccia arriva al parcheggio), grandi e con il bordo bianco e l'alone. Il punto esatto è in fondo al gambo,
/// al centro della vista: si ancora in basso al centro. VoiceOver legge «Ristorante» e «Parcheggio».
struct IntroPlacePin: View {
    enum Kind { case restaurant, parking }
    var kind: Kind
    /// Il parcheggio diventa verde quando la freccia ci arriva
    var lit = false
    static let size = CGSize(width: 64, height: 84)

    private var color: Color {
        switch kind {
        case .restaurant: Color(hex: 0xFF8A00)
        case .parking: lit ? Notte.ledGreen : Color(hex: 0x2F6FE4)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            badge
            Rectangle().fill(Notte.chalk).frame(width: 3, height: 14)
            Circle().fill(color).frame(width: 12, height: 12)
                .overlay(Circle().stroke(.white, lineWidth: 2.5))
                .shadow(color: color, radius: 6)
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .bottom)
        .animation(.easeInOut(duration: 0.4), value: lit)
        .accessibilityElement()
        .accessibilityLabel(Text(kind == .restaurant ? L("Restaurant") : L("Car park")))
        .accessibilityIdentifier("intro2.pin." + String(describing: kind))
    }

    /// Il segno grande: 46 punti, bordo bianco, alone del suo colore
    @ViewBuilder private var badge: some View {
        Group {
            switch kind {
            case .restaurant:
                Image(systemName: "fork.knife").font(.system(size: 21, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(color, in: Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 3))
            case .parking:
                Text(verbatim: "P").font(Notte.font(30, .black)).foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(color, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.white, lineWidth: 3))
            }
        }
        .shadow(color: color.opacity(0.7), radius: 14)
        .shadow(color: .black.opacity(0.45), radius: 8, y: 4)
    }
}

/// Controlla una volta se c'è rete: senza, le mattonelle della mappa non arrivano e si usa il disegno di riserva
enum IntroNetwork {
    static func isOffline() async -> Bool {
        final class Once: @unchecked Sendable { var done = false }
        return await withCheckedContinuation { cont in
            let monitor = NWPathMonitor()
            let once = Once()
            // Gli aggiornamenti arrivano tutti sulla stessa coda seriale: basta un segno per rispondere una volta sola
            monitor.pathUpdateHandler = { path in
                guard !once.done else { return }
                once.done = true
                monitor.cancel()
                cont.resume(returning: path.status != .satisfied)
            }
            monitor.start(queue: DispatchQueue(label: "intro2.network"))
        }
    }
}
