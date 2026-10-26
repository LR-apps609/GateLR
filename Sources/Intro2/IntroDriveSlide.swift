import MapKit
import Network
import SwiftUI

/// Prima pagina, «il problema e la soluzione», in tre passi con la stessa inquadratura di Firenze, per confrontarli:
/// 1. «La strada più diretta»: la freccia entra nella ZTL dal varco di via Cavour, la attraversa ed esce a piazza Beccaria,
///    verso il ristorante; il pannello si accende, arriva il verbale. «Evita multe con GateLR»
/// 2. «Con GateLR»: lo stesso viaggio intorno alla zona, lungo i viali (e 4 minuti prima); il pannello dice NESSUNA MULTA
/// 3. «Oppure parcheggia vicino»: fino al Parcheggio Beccaria, poi a piedi fino al ristorante
@MainActor final class IntroDrive: ObservableObject {
    enum Step: Int { case direct = 1, around, park }
    enum Phase { case waiting, driving, walking, done }
    @Published private(set) var step: Step = .direct
    @Published private(set) var phase: Phase = .waiting
    @Published var panel: LEDState = .idle
    @Published var flash = 0.0
    @Published var showFine = false
    let direct = IntroPath(IntroScene.direct)
    let around = IntroPath(IntroScene.around)
    let toParking = IntroPath(IntroScene.toParking)
    let walk = IntroPath(IntroScene.walk)
    /// Il passo 1 (circa 5 s): fino al varco, una breve sosta sotto il pannello, poi dentro e fuori dall'altra parte
    static let toGate = 1.1
    static let gatePause = 0.6
    static let afterGate = 3.2
    static let directSeconds = toGate + gatePause + afterGate
    /// Il passo 2, intorno lungo i viali
    static let aroundSeconds = 4.6
    /// Il passo 3: in auto fino al parcheggio, poi a piedi
    static let parkSeconds = 3.6
    static let walkSeconds = 1.5
    /// Dove sta il varco lungo il percorso dentro la ZTL (frazione)
    let gateAt = IntroPath(IntroScene.direct).fraction(near: IntroScene.gatePoint)
    var reduceMotion = false
    private(set) var stepStart = Date.distantFuture
    private(set) var walkStart = Date.distantFuture
    private var task: Task<Void, Never>?

    /// L'andatura: parte e si ferma morbida
    nonisolated static func ease(_ t: Double) -> Double {
        let x = min(max(t, 0), 1)
        return 0.35 * x + 0.65 * x * x * (3 - 2 * x)
    }

    /// Il percorso in auto del passo
    var path: IntroPath {
        switch step {
        case .direct: direct
        case .around: around
        case .park: toParking
        }
    }

    var driveSeconds: Double {
        switch step {
        case .direct: Self.directSeconds
        case .around: Self.aroundSeconds
        case .park: Self.parkSeconds
        }
    }

    /// La frazione del percorso del passo dopo t secondi (nel passo 1 rallenta fino al varco, si ferma, riparte)
    func fraction(after t: Double) -> Double {
        guard step == .direct else { return Self.ease(t / driveSeconds) }
        if t < Self.toGate { return gateAt * Self.ease(t / Self.toGate) }
        if t < Self.toGate + Self.gatePause { return gateAt }
        return gateAt + (1 - gateAt) * Self.ease((t - Self.toGate - Self.gatePause) / Self.afterGate)
    }

    func fraction(_ d: Date) -> Double {
        switch phase {
        case .waiting: 0
        case .driving: reduceMotion ? 0 : fraction(after: d.timeIntervalSince(stepStart))
        case .walking, .done: 1
        }
    }

    /// Quanto del tratto a piedi si vede (passo 3)
    func walkFraction(_ d: Date) -> Double {
        guard step == .park else { return 0 }
        switch phase {
        case .waiting, .driving: return 0
        case .walking: return reduceMotion ? 1 : Self.ease(d.timeIntervalSince(walkStart) / Self.walkSeconds)
        case .done: return 1
        }
    }

    /// Dove si trova la freccia in quel momento: calcolato a ogni fotogramma dello schermo
    func car(at d: Date) -> CLLocationCoordinate2D { path.point(fraction(d)) }

    /// Dove guarda la freccia (gradi da nord)
    func heading(at d: Date) -> Double {
        let f = fraction(d), p = path
        let delta = 12 / max(p.length, 1)
        return p.point(max(f - delta, 0)).notteBearing(to: p.point(min(f + delta, 1)))
    }

    /// Una linea sulla mappa: quanto se ne vede (0…1) e con che opacità
    struct Line { var progress: Double; var opacity: Double }
    struct Lines { var direct: Line; var around: Line; var park: Line; var walk: Double }

    /// Le linee di tutte le mappe: quella del passo si disegna dietro la freccia; la strada dentro la ZTL resta
    /// più tenue nei passi 2 e 3, per il confronto
    func lines(at d: Date) -> Lines {
        let f = fraction(d)
        return Lines(direct: Line(progress: step == .direct ? f : 1, opacity: step == .direct ? 1 : 0.32),
                     around: Line(progress: step == .around ? f : 0, opacity: 1),
                     park: Line(progress: step == .park ? f : 0, opacity: 1),
                     walk: walkFraction(d))
    }

    /// Il parcheggio si accende quando la freccia ci arriva
    var parked: Bool { step == .park && (phase == .walking || phase == .done) }

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            // Il tempo per le prime mattonelle della mappa
            try? await Task.sleep(for: .milliseconds(1200))
            await self?.run(.direct)
        }
    }

    func stop() { task?.cancel() }

    /// Il pulsante del passo: «Evita multe con GateLR» dopo il verbale, «Avanti» dopo il giro intorno
    func advance() {
        guard phase == .done else { return }
        switch step {
        case .direct: task = Task { [weak self] in await self?.run(.around) }
        case .around: task = Task { [weak self] in await self?.run(.park) }
        case .park: break
        }
    }

    private func run(_ next: Step) async {
        withAnimation(.easeInOut(duration: 0.35)) {
            showFine = false
            step = next
        }
        panel = .idle
        stepStart = Date()
        phase = .driving
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
        case .around:
            try? await Task.sleep(for: .seconds(reduceMotion ? quick : Self.aroundSeconds))
            guard !Task.isCancelled else { return }
            panel = .noFine
            withAnimation(.easeInOut(duration: 0.4)) { phase = .done }
            await autoplay(after: 1.8)
        case .park:
            try? await Task.sleep(for: .seconds(reduceMotion ? quick : Self.parkSeconds))
            guard !Task.isCancelled else { return }
            panel = .noFine
            walkStart = Date()
            withAnimation(.easeInOut(duration: 0.3)) { phase = .walking }
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.3 : Self.walkSeconds))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.4)) { phase = .done }
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
        panel = .active
        guard !reduceMotion else { return }
        withAnimation(.easeOut(duration: 0.06)) { flash = 0.85 }
        withAnimation(.easeOut(duration: 0.7).delay(0.08)) { flash = 0 }
    }
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
                LinearGradient(colors: [Notte.navy, Notte.navy.opacity(0.8), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 170)
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
        .sensoryFeedback(.warning, trigger: drive.panel == .active)
        .sensoryFeedback(.success, trigger: drive.panel == .noFine)
        .task {
            if scene == nil { scene = IntroScene.load(store) }
            drive.reduceMotion = reduceMotion
            if engine != .drawing, await IntroNetwork.isOffline() { engine = .drawing }
            // Mapbox fa partire la freccia quando lo stile è pronto (o passa alla mappa di Apple se non arriva)
            if engine != .mapbox { drive.start() }
        }
        .onChange(of: drive.phase) { _, phase in
            guard IntroAutoplay.on, phase == .done, drive.step == .park else { return }
            Task { try? await Task.sleep(for: .milliseconds(1800)); next() }
        }
        .onDisappear { drive.stop() }
    }

    private var title: String {
        switch drive.step {
        case .direct: L("The most direct route")
        case .around: L("With GateLR")
        case .park: L("Or park nearby")
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
            case .around:
                IntroHint(systemImage: "arrow.triangle.turn.up.right.diamond.fill",
                          text: String(format: L("GateLR: around the ZTL, %lld min faster"), IntroScene.minutesSaved))
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                if drive.phase == .done {
                    IntroButton(title: L("Next"), identifier: "intro2.around") { drive.advance() }
                        .transition(.opacity)
                }
            case .park:
                if drive.phase == .walking || drive.phase == .done {
                    IntroHint(systemImage: "figure.walk",
                              text: String(format: L("Car park outside the ZTL, then %lld min on foot"), IntroScene.walkMinutes))
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                if drive.phase == .done {
                    IntroButton(title: L("Next"), identifier: "intro2.next1", action: next)
                        .transition(.opacity)
                }
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.3) : .spring(response: 0.5, dampingFraction: 0.85), value: drive.phase)
        .animation(.easeInOut(duration: 0.35), value: drive.step)
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
                Text(verbatim: "\(scene.gateName) · 08:47").font(Notte.font(14, .semibold)).foregroundStyle(Color(hex: 0x5A5F70))
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
            // Fuori dalla ZTL: un velo grigio-blu che spegne i colori; dentro resta il rosso
            MapPolygon(IntroScene.outside(scene))
                .foregroundStyle(Color(hex: 0x1B2236).opacity(0.5))
            ForEach(scene.zones.indices, id: \.self) { i in
                MapPolygon(coordinates: scene.zones[i])
                    .foregroundStyle(Notte.ledRed.opacity(0.2))
                MapPolyline(coordinates: scene.zones[i] + scene.zones[i].prefix(1))
                    .stroke(Notte.ledRed.opacity(0.3), style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
                MapPolyline(coordinates: scene.zones[i] + scene.zones[i].prefix(1))
                    .stroke(Notte.ledRed, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
            }
            route(drive.direct, lines.direct, glow: Notte.action, core: Color(hex: 0xFF6A5C))
            route(drive.around, lines.around, glow: Notte.chalk, core: Notte.chalk)
            route(drive.toParking, lines.park, glow: Notte.chalk, core: Notte.chalk)
            if lines.walk > 0 {
                MapPolyline(coordinates: drive.walk.prefix(lines.walk))
                    .stroke(Notte.chalk, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round, dash: [0.1, 10]))
                    .mapOverlayLevel(level: .aboveLabels)
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
                IntroArrow(glow: drive.step == .direct ? Notte.action : Notte.chalk)
                    .rotationEffect(.degrees(drive.heading(at: now) - IntroCamera.heading))
            }
            .annotationTitles(.hidden)
        }
        .mapStyle(standard ? .standard(elevation: .realistic, emphasis: .muted, pointsOfInterest: .excludingAll)
                           : .hybrid(elevation: .realistic, pointsOfInterest: .excludingAll))
        .environment(\.colorScheme, .dark)
        .mapControlVisibility(.hidden)
        // Un velo blu notte sopra il satellite, per la palette «Notte»
        .overlay(Notte.navy.opacity(standard ? 0 : 0.22).allowsHitTesting(false))
        .ignoresSafeArea()
    }

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

/// L'inquadratura della mappa di Apple e del disegno di riserva: la stessa di Mapbox (ferma, rivolta a 152°, inclinata di 45°)
enum IntroCamera {
    /// Un centinaio di metri più avanti del centro di Mapbox: le etichette alte del ristorante e del parcheggio restano
    /// sotto il titolo (con MapKit e con il disegno la scena sta un po' più in alto)
    static let frame = CLLocationCoordinate2D(latitude: 43.7749, longitude: 11.2669)
    static let heading = IntroMapboxMap.bearing
    static let pitch = IntroMapboxMap.pitch
    /// MapKit misura la distanza della camera, non lo zoom: circa la stessa porzione di città dello zoom 14 di Mapbox
    static let distance = 5200.0

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
    private static let duomo = CLLocationCoordinate2D(latitude: 43.77310, longitude: 11.25600)
    private static let santaCroce = CLLocationCoordinate2D(latitude: 43.76858, longitude: 11.26225)

    var body: some View {
        TimelineView(.animation(paused: reduceMotion || drive.phase == .waiting || drive.phase == .done)) { tl in
            GeometryReader { g in
                let pr = IntroProjector(center: IntroCamera.frame, heading: IntroCamera.heading, pitch: IntroCamera.pitch,
                                        distance: 3100, size: g.size)
                ZStack {
                    Canvas { ctx, _ in draw(ctx, pr, tl.date) }
                    landmark("Duomo", pr.point(Self.duomo))
                    landmark("Santa Croce", pr.point(Self.santaCroce))
                    GateSign(state: drive.panel)
                        .position(pr.point(scene.gate)).offset(y: -30)
                    IntroPlacePin(kind: .restaurant)
                        .position(pr.point(IntroScene.restaurant)).offset(y: -IntroPlacePin.size.height / 2)
                    IntroPlacePin(kind: .parking, lit: drive.parked)
                        .position(pr.point(IntroScene.parking)).offset(y: -IntroPlacePin.size.height / 2)
                    IntroArrow(glow: drive.step == .direct ? Notte.action : Notte.chalk)
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
            Text(verbatim: name).font(Notte.font(11, .semibold)).foregroundStyle(Notte.muted.opacity(0.8))
        }
        .position(x: p.x, y: p.y + 8)
    }

    private func draw(_ ctx: GraphicsContext, _ pr: IntroProjector, _ now: Date) {
        // Una trama di isolati ogni 110 m, che si perde verso l'orizzonte
        var grid = Path()
        let step = 110.0 / 111_320
        let c = IntroCamera.frame
        let k = cos(c.latitude * .pi / 180)
        for i in -16...16 {
            let lat = c.latitude + Double(i) * step
            grid.move(to: pr.point(.init(latitude: lat, longitude: c.longitude - 16 * step / k)))
            grid.addLine(to: pr.point(.init(latitude: lat, longitude: c.longitude + 16 * step / k)))
            let lon = c.longitude + Double(i) * step / k
            grid.move(to: pr.point(.init(latitude: c.latitude - 16 * step, longitude: lon)))
            grid.addLine(to: pr.point(.init(latitude: c.latitude + 16 * step, longitude: lon)))
        }
        ctx.stroke(grid, with: .color(Notte.line.opacity(0.7)), lineWidth: 1)
        ctx.stroke(pr.path(Self.arno), with: .color(Color(hex: 0x1C3A6E)), style: StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round))

        for perimeter in scene.zones { drawZone(ctx, pr.path(perimeter, closed: true)) }
        drawRoutes(ctx, pr, now)
    }

    private func drawZone(_ ctx: GraphicsContext, _ zone: Path) {
        ctx.fill(zone, with: .color(Notte.ledRed.opacity(0.14)))
        var glow = ctx
        glow.addFilter(.blur(radius: 8))
        glow.stroke(zone, with: .color(Notte.ledRed.opacity(0.7)), lineWidth: 8)
        ctx.stroke(zone, with: .color(Notte.ledRed), lineWidth: 2.5)
    }

    private func drawRoutes(_ ctx: GraphicsContext, _ pr: IntroProjector, _ now: Date) {
        var glow = ctx
        glow.addFilter(.blur(radius: 8))
        let round = StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
        let lines = drive.lines(at: now)
        for (path, line, color) in [(drive.direct, lines.direct, Notte.action), (drive.around, lines.around, Notte.chalk),
                                    (drive.toParking, lines.park, Notte.chalk)] where line.progress > 0.001 {
            let p = pr.path(path.prefix(line.progress))
            glow.stroke(p, with: .color(color.opacity(line.opacity * 0.7)), lineWidth: 10)
            ctx.stroke(p, with: .color(color.opacity(line.opacity)), style: round)
        }
        if lines.walk > 0 {
            ctx.stroke(pr.path(drive.walk.prefix(lines.walk)), with: .color(Notte.chalk),
                       style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round, dash: [0.1, 9]))
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

/// I due posti della scena, più evidenti di tutto il resto: il ristorante (generico, nessun locale vero) e il parcheggio.
/// L'etichetta sta di lato (il ristorante a sinistra, il parcheggio a destra, così non si coprono) e il punto esatto è
/// in fondo al gambo, al centro della vista: si ancora in basso al centro.
struct IntroPlacePin: View {
    enum Kind { case restaurant, parking }
    var kind: Kind
    /// Il parcheggio diventa verde quando la freccia ci arriva
    var lit = false
    static let size = CGSize(width: 380, height: 84)

    private var color: Color {
        switch kind {
        case .restaurant: Color(hex: 0xFF8A00)
        case .parking: lit ? Notte.ledGreen : Color(hex: 0x2F6FE4)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: Self.size.width / 2)
                .overlay(alignment: .bottomTrailing) {
                    if kind == .restaurant { label.padding(.trailing, -30).padding(.bottom, 30) }
                }
            Color.clear.frame(width: Self.size.width / 2)
                .overlay(alignment: .bottomLeading) {
                    if kind == .parking { label.padding(.leading, -30).padding(.bottom, 30) }
                }
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 0) {
                Rectangle().fill(kind == .restaurant ? Notte.chalk : color).frame(width: 3, height: 18)
                Circle().fill(color).frame(width: 13, height: 13)
                    .overlay(Circle().stroke(.white, lineWidth: 2.5))
                    .shadow(color: color, radius: 6)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .animation(.easeInOut(duration: 0.4), value: lit)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var label: some View {
        HStack(spacing: 8) {
            Group {
                switch kind {
                case .restaurant:
                    Image(systemName: "fork.knife").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                case .parking:
                    Text(verbatim: "P").font(Notte.font(20, .black)).foregroundStyle(color)
                }
            }
            .frame(width: 30, height: 30)
            .background(kind == .restaurant ? color : .white, in: kind == .restaurant ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 8)))
            Text(kind == .restaurant ? L("Restaurant") : L("Car park"))
                .font(Notte.font(17, .bold))
                .foregroundStyle(kind == .restaurant ? Notte.navy : .white)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.leading, 6).padding(.trailing, 14).padding(.vertical, 6)
        .background(kind == .restaurant ? Notte.chalk : color, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(kind == .restaurant ? 0 : 0.35), lineWidth: 1))
        .shadow(color: color.opacity(0.55), radius: 14)
        .shadow(color: .black.opacity(0.45), radius: 10, y: 4)
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
