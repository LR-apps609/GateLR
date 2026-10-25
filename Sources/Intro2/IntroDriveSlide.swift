import MapKit
import Network
import SwiftUI

/// Prima pagina, «il problema e la soluzione»: un'auto entra nel Settore A di Firenze dal varco di via Guelfa,
/// il pannello si accende, arriva il verbale. «Evita multe con GateLR»: lo stesso viaggio gira intorno alla zona.
@MainActor final class IntroDrive: ObservableObject {
    enum Phase { case driving, fined, avoiding, arrived }
    @Published var phase: Phase = .driving
    @Published var badProgress = 0.0
    @Published var goodProgress = 0.0
    @Published var badOpacity = 1.0
    @Published var panel: LEDState = .idle
    @Published var flash = 0.0
    @Published var showFine = false
    let bad = IntroPath(IntroScene.badRoute)
    let good = IntroPath(IntroScene.goodRoute)
    var reduceMotion = false
    private var task: Task<Void, Never>?

    var car: CLLocationCoordinate2D {
        phase == .avoiding || phase == .arrived ? good.point(goodProgress) : bad.point(badProgress)
    }

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in await self?.driveIn() }
    }

    func stop() { task?.cancel() }

    private func driveIn() async {
        try? await Task.sleep(for: .milliseconds(900))
        let gateAt = bad.fraction(at: IntroScene.gateIndex)
        await run(seconds: 4.2) { f in
            self.badProgress = f
            if f >= gateAt && self.panel != .active { self.hitGate() }
        }
        try? await Task.sleep(for: .milliseconds(350))
        withAnimation(reduceMotion ? .easeInOut(duration: 0.4) : .spring(response: 0.55, dampingFraction: 0.78)) {
            phase = .fined
            showFine = true
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
        phase = .avoiding
        task = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(500))
            await self.run(seconds: 5.0) { f in self.goodProgress = f }
            self.panel = .arrived
            withAnimation(.easeInOut(duration: 0.4)) { self.phase = .arrived }
        }
    }

    /// Fa avanzare f da 0 a 1 in «seconds» secondi, 30 volte al secondo. Con «Riduci movimento» salta alla fine
    /// in dissolvenza dopo una breve pausa.
    private func run(seconds: Double, _ step: @escaping (Double) -> Void) async {
        if reduceMotion {
            try? await Task.sleep(for: .seconds(min(seconds, 1.5)))
            withAnimation(.easeInOut(duration: 0.6)) { step(1) }
            return
        }
        let start = Date()
        while !Task.isCancelled {
            let f = min(Date().timeIntervalSince(start) / seconds, 1)
            step(f)
            if f >= 1 { break }
            try? await Task.sleep(for: .milliseconds(33))
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
    @State private var position: MapCameraPosition = .camera(
        MapCamera(centerCoordinate: IntroScene.center, distance: 1900, heading: 20, pitch: 60))
    @State private var orbit = false

    var body: some View {
        Map(position: $position, interactionModes: []) {
            // Il perimetro vero del Settore A, rosso con un alone
            MapPolygon(coordinates: scene.perimeter)
                .foregroundStyle(Notte.ledRed.opacity(0.16))
                .stroke(Notte.ledRed.opacity(0.3), lineWidth: 16)
            MapPolygon(coordinates: scene.perimeter)
                .foregroundStyle(.clear)
                .stroke(Notte.ledRed, lineWidth: 3)

            if drive.badOpacity > 0.01 {
                MapPolyline(coordinates: drive.bad.prefix(drive.badProgress))
                    .stroke(Notte.action.opacity(drive.badOpacity * 0.35), style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round))
                MapPolyline(coordinates: drive.bad.prefix(drive.badProgress))
                    .stroke(Notte.action.opacity(drive.badOpacity), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            }
            if drive.goodProgress > 0 {
                MapPolyline(coordinates: drive.good.prefix(drive.goodProgress))
                    .stroke(Notte.chalk.opacity(0.3), style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round))
                MapPolyline(coordinates: drive.good.prefix(drive.goodProgress))
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
            Annotation("", coordinate: drive.car, anchor: .center) {
                CarPuck(good: drive.phase == .avoiding || drive.phase == .arrived)
            }
            .annotationTitles(.hidden)
        }
        .mapStyle(.standard(elevation: .realistic, emphasis: .muted, pointsOfInterest: .excludingAll))
        .environment(\.colorScheme, .dark)
        .mapControlVisibility(.hidden)
        .mapCameraKeyframeAnimator(trigger: orbit) { camera in
            KeyframeTrack(\MapCamera.heading) { LinearKeyframe(camera.heading + 55, duration: 26) }
            KeyframeTrack(\MapCamera.distance) { LinearKeyframe(1500, duration: 26) }
        }
        .ignoresSafeArea()
        .task {
            guard !reduceMotion else { return }
            try? await Task.sleep(for: .milliseconds(300))
            orbit.toggle()
        }
        .accessibilityHidden(true)
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
                let pr = IntroProjector(center: IntroScene.center,
                                        heading: reduceMotion ? 20 : 20 + min(t, 26) * 55 / 26,
                                        pitch: 58, distance: reduceMotion ? 1700 : 1900 - min(t, 26) * 400 / 26,
                                        size: g.size)
                ZStack {
                    Canvas { ctx, _ in draw(ctx, pr) }
                    landmark("Duomo", pr.point(Self.duomo))
                    landmark("Signoria", pr.point(Self.signoria))
                    ParkingPin(lit: drive.phase == .arrived).position(pr.point(IntroScene.goodRoute.last!))
                    GateSign(state: drive.panel)
                        .position(pr.point(scene.gate)).offset(y: -24)
                    CarPuck(good: drive.phase == .avoiding || drive.phase == .arrived).position(pr.point(drive.car))
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

    private func draw(_ ctx: GraphicsContext, _ pr: IntroProjector) {
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

        let zone = pr.path(scene.perimeter, closed: true)
        ctx.fill(zone, with: .color(Notte.ledRed.opacity(0.14)))
        var glow = ctx
        glow.addFilter(.blur(radius: 8))
        glow.stroke(zone, with: .color(Notte.ledRed.opacity(0.7)), lineWidth: 8)
        ctx.stroke(zone, with: .color(Notte.ledRed), lineWidth: 2.5)

        let round = StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
        if drive.badOpacity > 0.01 {
            let p = pr.path(drive.bad.prefix(drive.badProgress))
            glow.stroke(p, with: .color(Notte.action.opacity(drive.badOpacity)), lineWidth: 10)
            ctx.stroke(p, with: .color(Notte.action.opacity(drive.badOpacity)), style: round)
        }
        if drive.goodProgress > 0 {
            let p = pr.path(drive.good.prefix(drive.goodProgress))
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
            LEDPanel(state: state, size: 13)
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
