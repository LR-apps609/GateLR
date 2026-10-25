import MapKit
import Network
import SwiftUI

/// Prima pagina, «il problema e la soluzione»: un'auto entra nella ZTL di Firenze dal varco di via Cavour,
/// il pannello si accende, arriva il verbale. «Evita multe con GateLR»: lo stesso viaggio gira intorno alla zona.
@MainActor final class IntroDrive: ObservableObject {
    enum Phase { case waiting, driving, fined, avoiding, arrived }
    @Published var phase: Phase = .waiting
    /// 1 quando parte il percorso rosso, 2 quando parte quello bianco: fa partire i movimenti della camera
    @Published var leg = 0
    @Published var badOpacity = 1.0
    @Published var panel: LEDState = .idle
    @Published var flash = 0.0
    @Published var showFine = false
    let bad = IntroPath(IntroScene.badRoute)
    let good = IntroPath(IntroScene.goodRoute)
    /// Durate dei due viaggi: l'auto passa il varco entro circa 4 secondi dall'apertura della pagina
    static let badSeconds = 5.0
    static let goodSeconds = 6.0
    /// Il volo della camera dal punto d'arrivo rosso alla partenza del percorso bianco
    static let flyBack = 1.0
    var reduceMotion = false
    private(set) var badStart = Date.distantFuture
    private(set) var goodStart = Date.distantFuture
    private var task: Task<Void, Never>?

    /// L'andatura dell'auto: parte e si ferma morbida. La stessa funzione dà i punti della camera.
    nonisolated static func ease(_ t: Double) -> Double {
        let x = min(max(t, 0), 1)
        return 0.6 * x + 0.4 * x * x * (3 - 2 * x)
    }

    func badFraction(_ d: Date) -> Double {
        if reduceMotion { return phase == .waiting ? 0 : 1 }
        return Self.ease(d.timeIntervalSince(badStart) / Self.badSeconds)
    }
    func goodFraction(_ d: Date) -> Double {
        if reduceMotion { return phase == .arrived ? 1 : 0 }
        return Self.ease(d.timeIntervalSince(goodStart) / Self.goodSeconds)
    }
    var onGoodRoute: Bool { phase == .avoiding || phase == .arrived }

    /// Dove si trova l'auto in quel momento: calcolato a ogni fotogramma dello schermo (TimelineView)
    func car(at d: Date) -> CLLocationCoordinate2D {
        onGoodRoute ? good.point(goodFraction(d)) : bad.point(badFraction(d))
    }

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in await self?.driveIn() }
    }

    func stop() { task?.cancel() }

    private func driveIn() async {
        // Il tempo per le prime mattonelle della mappa
        try? await Task.sleep(for: .milliseconds(1200))
        badStart = Date()
        phase = .driving
        leg = 1
        // Il momento in cui l'auto passa sotto il varco (l'inverso dell'andatura, per bisezione)
        let target = bad.fraction(near: IntroScene.gatePoint)
        var lo = 0.0, hi = 1.0
        for _ in 0..<30 { let m = (lo + hi) / 2; if Self.ease(m) < target { lo = m } else { hi = m } }
        let gateTime = reduceMotion ? 1.2 : lo * Self.badSeconds
        try? await Task.sleep(for: .seconds(gateTime))
        hitGate()
        try? await Task.sleep(for: .seconds((reduceMotion ? 1.5 : Self.badSeconds) - gateTime + 0.35))
        withAnimation(reduceMotion ? .easeInOut(duration: 0.4) : .spring(response: 0.55, dampingFraction: 0.78)) {
            phase = .fined
            showFine = true
        }
        if IntroAutoplay.on {
            try? await Task.sleep(for: .milliseconds(3200))
            avoid()
        }
    }

    private func hitGate() {
        panel = .active
        guard !reduceMotion else { return }
        withAnimation(.easeOut(duration: 0.06)) { flash = 0.85 }
        withAnimation(.easeOut(duration: 0.7).delay(0.08)) { flash = 0 }
    }

    /// «Evita multe con GateLR»
    func avoid() {
        guard phase == .fined else { return }
        withAnimation(.easeInOut(duration: 0.35)) { showFine = false }
        withAnimation(.easeInOut(duration: 0.9)) { badOpacity = 0 }
        panel = .idle
        goodStart = Date().addingTimeInterval(reduceMotion ? 0 : Self.flyBack)
        phase = .avoiding
        leg = 2
        task = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(self.reduceMotion ? 1.5 : Self.flyBack + Self.goodSeconds))
            self.panel = .arrived
            withAnimation(.easeInOut(duration: 0.4)) { self.phase = .arrived }
        }
    }
}

struct IntroDriveSlide: View {
    @EnvironmentObject var store: Store
    var next: () -> Void
    @StateObject private var drive = IntroDrive()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scene: IntroScene?
    /// Senza rete (o con -intro2Fallback) la mappa diventa un disegno sullo stesso fondo blu notte
    @State private var offline = ProcessInfo.processInfo.arguments.contains("-intro2Fallback")

    var body: some View {
        ZStack {
            Notte.navy.ignoresSafeArea()
            if let scene {
                if offline {
                    IntroFallbackMap(scene: scene, drive: drive)
                } else {
                    IntroLiveMap(scene: scene, drive: drive)
                }
            }
            // Il blu notte sopra e sotto, perché il testo resti leggibile sulla mappa
            VStack(spacing: 0) {
                LinearGradient(colors: [Notte.navy, Notte.navy.opacity(0.85), .clear], startPoint: .top, endPoint: .bottom).frame(height: 230)
                Spacer()
                LinearGradient(colors: [.clear, Notte.navy.opacity(0.9), Notte.navy], startPoint: .top, endPoint: .bottom).frame(height: 300)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            Color.white.opacity(drive.flash).ignoresSafeArea().allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                caption.padding(.top, 64)
                Spacer()
                bottom
            }
            .padding(.horizontal, 20).padding(.bottom, 12)
        }
        .sensoryFeedback(.warning, trigger: drive.panel == .active)
        .sensoryFeedback(.success, trigger: drive.phase == .arrived)
        .task {
            if scene == nil { scene = IntroScene.load(store) }
            drive.reduceMotion = reduceMotion
            if !offline { offline = await IntroNetwork.isOffline() }
            drive.start()
        }
        .onChange(of: drive.phase) { _, phase in
            guard IntroAutoplay.on, phase == .arrived else { return }
            Task { try? await Task.sleep(for: .milliseconds(2200)); next() }
        }
        .onDisappear { drive.stop() }
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 6) {
            IntroTitle(text: drive.phase == .arrived ? L("Same trip, no fine.") : L("One wrong turn."))
                .id(drive.phase == .arrived)
                .transition(.opacity)
            if let scene {
                Text(verbatim: "\(scene.cityName) · \(scene.zoneName)")
                    .font(Notte.font(15, .semibold)).foregroundStyle(Notte.muted)
            }
        }
    }

    @ViewBuilder private var bottom: some View {
        VStack(spacing: 14) {
            if drive.showFine, let scene {
                FineNotice(scene: scene)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                IntroButton(title: L("Avoid fines with GateLR"), systemImage: "arrow.triangle.turn.up.right.diamond.fill",
                            identifier: "intro2.avoid") { drive.avoid() }
                    .transition(.opacity)
            } else if drive.phase == .arrived {
                IntroButton(title: L("Next"), identifier: "intro2.next1", action: next)
                    .transition(.opacity)
            }
        }
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

// MARK: La mappa vera (MapKit 3D)

private struct IntroLiveMap: View {
    var scene: IntroScene
    @ObservedObject var drive: IntroDrive
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var position: MapCameraPosition = .camera(IntroCamera.start(reduceMotion: false))
    /// -intro2Standard: la mappa normale con gli edifici 3D invece del satellite 3D (Flyover)
    private let standard = ProcessInfo.processInfo.arguments.contains("-intro2Standard")

    /// Le linee si ridisegnano a scatti di 1/30 del percorso; l'auto invece si muove a ogni fotogramma
    private func step(_ f: Double) -> Double { f >= 1 ? 1 : (f * 30).rounded(.up) / 30 }

    private var paused: Bool {
        reduceMotion || drive.phase == .waiting || drive.phase == .fined || drive.phase == .arrived
    }

    var body: some View {
        TimelineView(.animation(paused: paused)) { tl in
            map(at: tl.date)
        }
        .onAppear { if reduceMotion { position = .camera(IntroCamera.start(reduceMotion: true)) } }
        .accessibilityHidden(true)
    }

    private func map(at now: Date) -> some View {
        let badF = drive.badFraction(now), goodF = drive.goodFraction(now)
        return Map(position: $position, interactionModes: []) {
            // Il Settore A: una velatura rossa e un bordo acceso con l'alone
            ForEach(scene.zones.indices, id: \.self) { i in
                MapPolygon(coordinates: scene.zones[i])
                    .foregroundStyle(Notte.ledRed.opacity(0.12))
                MapPolyline(coordinates: scene.zones[i] + scene.zones[i].prefix(1))
                    .stroke(Notte.ledRed.opacity(0.3), style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
                MapPolyline(coordinates: scene.zones[i] + scene.zones[i].prefix(1))
                    .stroke(Notte.ledRed, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
            }

            if drive.badOpacity > 0.01 && badF > 0 {
                MapPolyline(coordinates: drive.bad.prefix(step(badF)))
                    .stroke(Notte.action.opacity(drive.badOpacity * 0.35), style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round))
                MapPolyline(coordinates: drive.bad.prefix(step(badF)))
                    .stroke(Notte.action.opacity(drive.badOpacity), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            }
            if drive.onGoodRoute && goodF > 0 {
                MapPolyline(coordinates: drive.good.prefix(step(goodF)))
                    .stroke(Notte.chalk.opacity(0.35), style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round))
                MapPolyline(coordinates: drive.good.prefix(step(goodF)))
                    .stroke(Notte.chalk, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            }

            Annotation("", coordinate: IntroScene.goodRoute.last!, anchor: .center) {
                ParkingPin(lit: drive.phase == .arrived)
            }
            .annotationTitles(.hidden)
            Annotation("", coordinate: scene.gate, anchor: .bottom) {
                GateSign(state: drive.panel)
            }
            .annotationTitles(.hidden)
            Annotation("", coordinate: drive.car(at: now), anchor: .center) {
                CarPuck(good: drive.onGoodRoute)
            }
            .annotationTitles(.hidden)
        }
        .mapStyle(standard ? .standard(elevation: .realistic, emphasis: .muted, pointsOfInterest: .excludingAll)
                           : .hybrid(elevation: .realistic, pointsOfInterest: .excludingAll))
        .environment(\.colorScheme, .dark)
        .mapControlVisibility(.hidden)
        // La camera segue l'auto con le animazioni di MapKit: una sola partenza per tratto, niente aggiornamenti continui
        .mapCameraKeyframeAnimator(trigger: drive.leg) { camera in
            let k = IntroCamera.keys(leg: drive.leg, from: camera, drive: drive, still: reduceMotion)
            KeyframeTrack(\MapCamera.centerCoordinate) {
                CubicKeyframe(k.centers[0], duration: k.times[0])
                CubicKeyframe(k.centers[1], duration: k.times[1])
                CubicKeyframe(k.centers[2], duration: k.times[2])
                CubicKeyframe(k.centers[3], duration: k.times[3])
                CubicKeyframe(k.centers[4], duration: k.times[4])
                CubicKeyframe(k.centers[5], duration: k.times[5])
                CubicKeyframe(k.centers[6], duration: k.times[6])
            }
            KeyframeTrack(\MapCamera.heading) {
                CubicKeyframe(k.heading, duration: k.times[0])
                LinearKeyframe(k.heading + k.orbit, duration: k.total - k.times[0])
            }
            KeyframeTrack(\MapCamera.distance) {
                CubicKeyframe(k.distance, duration: k.times[0])
                LinearKeyframe(k.distance * 0.9, duration: k.total - k.times[0])
            }
            KeyframeTrack(\MapCamera.pitch) {
                CubicKeyframe(k.pitch, duration: k.total)
            }
        }
        // Un velo blu notte sopra il satellite, per la palette «Notte»
        .overlay(Notte.navy.opacity(standard ? 0 : 0.22).allowsHitTesting(false))
        .ignoresSafeArea()
    }
}

/// Le inquadrature della prima pagina: inclinata (60°), a circa 900 m, rivolta dove va l'auto
enum IntroCamera {
    static let pitch = 60.0
    static let distance = 900.0
    /// Quanto la camera resta indietro rispetto all'auto: così l'auto sta sopra il centro, visibile sopra il verbale
    static let lag = 120.0

    static func start(reduceMotion: Bool) -> MapCamera {
        if reduceMotion {
            return MapCamera(centerCoordinate: IntroScene.center, distance: 2600, heading: 0, pitch: 45)
        }
        let p = IntroPath(IntroScene.badRoute)
        return MapCamera(centerCoordinate: p.points[0], distance: distance * 1.15, heading: p.bearing, pitch: pitch)
    }

    struct Keys {
        var centers: [CLLocationCoordinate2D]
        var times: [Double]
        var heading: Double
        var orbit: Double
        var distance: Double
        var pitch: Double
        var total: Double { times.reduce(0, +) }
    }

    /// Sette punti per la camera lungo il tratto, con la stessa andatura dell'auto
    @MainActor static func keys(leg: Int, from camera: MapCamera, drive: IntroDrive, still: Bool) -> Keys {
        guard !still, leg > 0 else {
            return Keys(centers: Array(repeating: camera.centerCoordinate, count: 7), times: Array(repeating: 0.01, count: 7),
                        heading: camera.heading, orbit: 0, distance: camera.distance, pitch: camera.pitch)
        }
        let path = leg == 1 ? drive.bad : drive.good
        let seconds = leg == 1 ? IntroDrive.badSeconds : IntroDrive.goodSeconds
        let first = leg == 1 ? 0.05 : IntroDrive.flyBack
        var centers: [CLLocationCoordinate2D] = []
        for i in 0..<7 {
            let f = IntroDrive.ease(Double(i) / 6)
            let back = max(0, f * path.length - lag) / max(path.length, 1)
            centers.append(path.point(back))
        }
        let times = [first] + Array(repeating: seconds / 6, count: 6)
        // La direzione: quella del tratto, girata verso il primo e unico movimento lento
        var heading = path.bearing
        // Al massimo 70° di rotazione per tratto: niente giri vorticosi della camera
        let delta = (heading - camera.heading + 540).truncatingRemainder(dividingBy: 360) - 180
        heading = camera.heading + min(max(delta, -70), 70)
        return Keys(centers: centers, times: times, heading: heading, orbit: leg == 1 ? 12 : -12,
                    distance: distance, pitch: pitch)
    }
}

// MARK: Il disegno di riserva (senza rete)

/// Lo stesso Settore A e gli stessi percorsi, proiettati a mano con la stessa inclinazione della mappa
private struct IntroFallbackMap: View {
    var scene: IntroScene
    @ObservedObject var drive: IntroDrive
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    /// L'Arno nel centro, a grandi linee: basta per riconoscere Firenze
    private static let arno: [CLLocationCoordinate2D] = IntroScene.coords([
        (43.7748, 11.2380), (43.7718, 11.2448), (43.7693, 11.2497), (43.7680, 11.2531),
        (43.7672, 11.2566), (43.7660, 11.2612), (43.7641, 11.2662), (43.7622, 11.2722),
    ])
    private static let duomo = CLLocationCoordinate2D(latitude: 43.77310, longitude: 11.25600)
    private static let signoria = CLLocationCoordinate2D(latitude: 43.76965, longitude: 11.25560)

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { tl in
            let t = tl.date.timeIntervalSince(start)
            GeometryReader { g in
                // Vista d'insieme verso nord: Duomo in basso, viali e Parterre in alto, con una rotazione lenta
                let pr = IntroProjector(center: CLLocationCoordinate2D(latitude: 43.7768, longitude: 11.2600),
                                        heading: reduceMotion ? 0 : -10 + min(t, 26) * 20 / 26,
                                        pitch: 58, distance: reduceMotion ? 2400 : 2600 - min(t, 26) * 300 / 26,
                                        size: g.size)
                ZStack {
                    Canvas { ctx, _ in draw(ctx, pr, tl.date) }
                    landmark("Duomo", pr.point(Self.duomo))
                    landmark("Signoria", pr.point(Self.signoria))
                    ParkingPin(lit: drive.phase == .arrived).position(pr.point(IntroScene.goodRoute.last!))
                    GateSign(state: drive.panel)
                        .position(pr.point(scene.gate)).offset(y: -30)
                    CarPuck(good: drive.onGoodRoute).position(pr.point(drive.car(at: tl.date)))
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
        let k = cos(IntroScene.center.latitude * .pi / 180)
        for i in -14...14 {
            let lat = IntroScene.center.latitude + Double(i) * step
            grid.move(to: pr.point(.init(latitude: lat, longitude: IntroScene.center.longitude - 14 * step / k)))
            grid.addLine(to: pr.point(.init(latitude: lat, longitude: IntroScene.center.longitude + 14 * step / k)))
            let lon = IntroScene.center.longitude + Double(i) * step / k
            grid.move(to: pr.point(.init(latitude: IntroScene.center.latitude - 14 * step, longitude: lon)))
            grid.addLine(to: pr.point(.init(latitude: IntroScene.center.latitude + 14 * step, longitude: lon)))
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
        if drive.badOpacity > 0.01 {
            let p = pr.path(drive.bad.prefix(drive.badFraction(now)))
            glow.stroke(p, with: .color(Notte.action.opacity(drive.badOpacity)), lineWidth: 10)
            ctx.stroke(p, with: .color(Notte.action.opacity(drive.badOpacity)), style: round)
        }
        if drive.onGoodRoute && drive.goodFraction(now) > 0 {
            let p = pr.path(drive.good.prefix(drive.goodFraction(now)))
            glow.stroke(p, with: .color(Notte.chalk.opacity(0.6)), lineWidth: 10)
            ctx.stroke(p, with: .color(Notte.chalk), style: round)
        }
    }
}

// MARK: Segni sulla mappa

/// Il pannello del varco su un palo sottile
private struct GateSign: View {
    var state: LEDState
    var body: some View {
        VStack(spacing: 0) {
            LEDPanel(state: state, size: 18)
            Rectangle().fill(Color(hex: 0x6A7290)).frame(width: 2, height: 16)
            Circle().fill(state.dim ? Notte.muted : state.color).frame(width: 7, height: 7)
                .shadow(color: state.dim ? .clear : state.color, radius: 5)
        }
        .fixedSize()
    }
}

private struct CarPuck: View {
    var good: Bool
    var body: some View {
        Image(systemName: "car.fill")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(good ? Notte.navy : .white)
            .frame(width: 30, height: 30)
            .background(good ? Notte.chalk : Notte.action, in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .shadow(color: (good ? Notte.chalk : Notte.action).opacity(0.8), radius: 10)
    }
}

private struct ParkingPin: View {
    var lit: Bool
    var body: some View {
        Text(verbatim: "P")
            .font(Notte.font(17, .black))
            .foregroundStyle(lit ? Notte.navy : Notte.chalk)
            .frame(width: 30, height: 30)
            .background(lit ? Notte.ledGreen : Notte.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Notte.chalk.opacity(0.8), lineWidth: 1.5))
            .shadow(color: lit ? Notte.ledGreen.opacity(0.8) : .clear, radius: 10)
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
