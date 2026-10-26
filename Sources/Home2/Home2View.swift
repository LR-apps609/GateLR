import CoreLocation
import CoreMotion
import SwiftUI

/// Prototipo della prima pagina 2.0, «Posso entrare?» con la profondità (Account → «Anteprima prima pagina 2.0»).
/// Dietro, Firenze in 3D al crepuscolo (Mapbox) che si muove piano intorno al posto scelto (di base piazza della Signoria);
/// davanti, su vetro smerigliato, la risposta vera del motore delle regole per quel posto, l'ora e il veicolo scelti
/// («Non entrare.» e l'ora grande in cui cambia). In mezzo il pannello del varco come un oggetto vero: cornice di metallo
/// con le viti, palo, punti luminosi che si accendono riga per riga, riflesso del vetro e la sua luce che si spande
/// sulla scena; quando la risposta cambia gira come una paletta, con un colpo di vibrazione. Map, pannello e testi stanno a
/// profondità diverse e si spostano col telefono (CoreMotion), tranne con «Riduci movimento».
/// «Guarda la mappa» porta la stessa camera giù, sulla mappa intera, senza stacchi.
struct Home2View: View {
    @EnvironmentObject var store: Store
    var done: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var motion = ParallaxMotion()
    @State private var place: Place = Home2View.signoria
    @State private var mapMode = false
    @State private var mapFailed = !NotteMap.hasToken
    /// L'altezza del vetro con la risposta: logo e attribuzione di Mapbox stanno subito sopra (devono restare visibili)
    @State private var cardHeight: CGFloat = 0

    static let signoria = Place(name: "Piazza della Signoria", address: "Firenze",
                                location: Coordinate(lat: 43.76965, lon: 11.25560))
    /// Un posto fuori dalla ZTL a due passi, per vedere il verde
    static let parterre = Place(name: "Parcheggio Parterre", address: "Firenze",
                                location: Coordinate(lat: 43.7855947, lon: 11.2643376))

    var body: some View {
        TimelineView(.everyMinute) { ctx in
            let answer = Home2Answer(PlaceCheck(place, store: store, at: store.moment(ctx.date)), now: ctx.date)
            scene(answer)
        }
        .preferredColorScheme(.dark)
        .environment(\.colorScheme, .dark)
        .onAppear {
            if let p = store.place { place = p }
            if !reduceMotion { motion.start() }
        }
        .onDisappear { motion.stop() }
    }

    private func scene(_ a: Home2Answer) -> some View {
        let depth = reduceMotion ? CGSize.zero : motion.offset
        return ZStack {
            Notte.navy.ignoresSafeArea()
            // Fondo: la città (la più lontana, si sposta al contrario)
            Group {
                if mapFailed {
                    Home2Backdrop(mood: a.mood)
                } else {
                    // Sopra il vetro (+10 di margine sotto, +20 per l'ingrandimento di 1,06 della mappa); sulla mappa intera in basso
                    Home2Map(place: place, zones: zones(for: a), mood: a.mood, mapMode: mapMode,
                             reduceMotion: reduceMotion, ornamentBottom: mapMode ? 8 : cardHeight + 10 + 20,
                             onFail: { mapFailed = true })
                }
            }
            .scaleEffect(mapMode ? 1 : 1.06)
            .offset(x: mapMode ? 0 : -depth.width * 10, y: mapMode ? 0 : -depth.height * 10)
            .ignoresSafeArea()
            .accessibilityHidden(true)

            // La luce della scena: rossa calda o verde fresca, dal pannello verso il basso
            if !mapMode {
                tint(a.mood).allowsHitTesting(false).transition(.opacity)
            }

            VStack(spacing: 0) {
                topBar
                if !mapMode {
                    GatePanelObject(panel: a.panel)
                        .frame(height: 250)
                        .offset(x: depth.width * 6, y: depth.height * 6)
                        .padding(.top, 6)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer(minLength: 0)
                if !mapMode {
                    answerCard(a)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { cardHeight = $0 }
                        .offset(x: depth.width * 14, y: depth.height * 14)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 10)
        }
        .animation(.easeInOut(duration: 0.9), value: mapMode)
        .animation(.easeInOut(duration: 0.6), value: a.mood)
    }

    /// Le zone della città del posto (o di quella scelta), per la velatura sulla mappa
    private func zones(for a: Home2Answer) -> [[CLLocationCoordinate2D]] {
        let city = a.city ?? store.city
        return city.zones.map { $0.perimeter.map(\.cl) }
    }

    private func tint(_ mood: Home2Answer.Mood) -> some View {
        ZStack {
            LinearGradient(colors: [Notte.navy.opacity(0.85), Notte.navy.opacity(0.15), .clear, Notte.navy.opacity(0.55), Notte.navy.opacity(0.92)],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [mood.color.opacity(0.42), mood.color.opacity(0.12), .clear],
                           center: UnitPoint(x: 0.5, y: 0.26), startRadius: 10, endRadius: 420)
            mood.color.opacity(0.07)
        }
        .ignoresSafeArea()
    }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if mapMode {
                    Button { mapMode = false } label: {
                        Label(L("Back to the answer"), systemImage: "chevron.down")
                            .font(Notte.font(16, .semibold)).foregroundStyle(Notte.text)
                            .padding(.horizontal, 14).frame(height: 40)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home2.back")
                } else {
                    Wordmark(size: 20)
                }
                Spacer()
                Button(action: done) {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(Notte.text)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("Done"))
                .accessibilityIdentifier("home2.close")
            }
            if !mapMode {
                ContextChips(material: true)
            }
        }
        .padding(.top, 6)
    }

    // MARK: La risposta, sul vetro

    private func answerCard(_ a: Home2Answer) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            placeMenu
            Text(a.headline)
                .font(Notte.font(46, .black)).foregroundStyle(Notte.text)
                .lineLimit(2).minimumScaleFactor(0.6)
                .accessibilityAddTraits(.isHeader)
                .id(a.headline)
                .transition(.opacity.combined(with: .offset(y: 8)))
            if let label = a.timeLabel, let time = a.time {
                VStack(alignment: .leading, spacing: -6) {
                    Text(label.uppercased()).font(Notte.font(13, .bold)).kerning(1.4).foregroundStyle(Notte.muted)
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(verbatim: time)
                            .font(Notte.font(96, .black)).monospacedDigit()
                            .foregroundStyle(Notte.text)
                            .shadow(color: a.mood.color.opacity(0.55), radius: 24)
                            .lineLimit(1).minimumScaleFactor(0.5)
                            .contentTransition(.numericText())
                        if let day = a.day {
                            Text(verbatim: day).font(Notte.font(18, .semibold)).foregroundStyle(Notte.muted)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            }
            Text(verbatim: a.zoneLine).font(Notte.font(15, .semibold)).foregroundStyle(Notte.muted)
            Button { mapMode = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "map.fill")
                    Text(L("See the map"))
                }
                .font(Notte.font(18, .bold)).foregroundStyle(Notte.navy)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Notte.text, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            .accessibilityIdentifier("home2.map")
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        // La luce del pannello che cade sul vetro, dall'alto
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(LinearGradient(colors: [a.mood.color.opacity(0.22), .clear], startPoint: .top, endPoint: .center))
                .allowsHitTesting(false)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(LinearGradient(colors: [a.mood.color.opacity(0.75), Color.white.opacity(0.12), Color.white.opacity(0.05)],
                                       startPoint: .top, endPoint: .bottom), lineWidth: 1)
        }
        .shadow(color: a.mood.color.opacity(0.25), radius: 30, y: -6)
        .shadow(color: .black.opacity(0.45), radius: 24, y: 12)
    }

    /// Il posto: un tocco per cambiarlo (piazza della Signoria, il Parterre fuori dalla ZTL, il posto cercato, i recenti)
    private var placeMenu: some View {
        Menu {
            Button(Home2View.signoria.name) { place = Home2View.signoria }
            Button(Home2View.parterre.name) { place = Home2View.parterre }
            if let p = store.place { Button(p.name) { place = p } }
            ForEach(store.recent.prefix(4)) { p in Button(p.name) { place = p } }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "mappin.and.ellipse")
                Text(verbatim: place.name).lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold)).opacity(0.7)
            }
            .font(Notte.font(16, .semibold)).foregroundStyle(Notte.text)
        }
        .accessibilityIdentifier("home2.place")
    }
}

// MARK: La risposta per la pagina

/// La risposta del motore delle regole detta come sul pannello: colore, frase breve, ora del prossimo cambio
struct Home2Answer: Equatable {
    enum Mood: Equatable {
        case red, green, amber
        var color: Color {
            switch self {
            case .red: Notte.ledRed
            case .green: Notte.ledGreen
            case .amber: Notte.ledAmber
            }
        }
        var hex: UInt32 {
            switch self {
            case .red: 0xFF4D3D
            case .green: 0x3BE07A
            case .amber: 0xFFB21E
            }
        }
    }

    var mood: Mood
    var headline: String
    var timeLabel: String?
    var time: String?
    /// Il giorno, se il cambio non è oggi
    var day: String?
    var zoneLine: String
    var panel: GatePanelState
    var city: City?

    static func == (l: Home2Answer, r: Home2Answer) -> Bool {
        l.mood == r.mood && l.headline == r.headline && l.time == r.time && l.panel == r.panel && l.zoneLine == r.zoneLine
    }

    init(_ check: PlaceCheck, now: Date) {
        zoneLine = check.zoneLine
        city = check.hits.first?.city
        switch check.kind {
        case .closed:
            mood = .red; headline = L("Don't enter."); panel = GatePanelState(lines: ["VARCO", "ATTIVO"], mood: .red)
        case .open:
            mood = .green; headline = L("Drive in."); panel = GatePanelState(lines: ["VARCO", "NON ATTIVO"], mood: .green)
        case .outside:
            mood = .green; headline = L("Outside the ZTL."); panel = GatePanelState(lines: ["FUORI", "ZTL"], mood: .green)
        case .conditional:
            mood = .amber; headline = L("On one condition."); panel = GatePanelState(lines: ["VARCO", "ATTIVO"], mood: .amber)
        case .unsure:
            mood = .amber; headline = L("Check the sign."); panel = GatePanelState(lines: ["VARCO", "ATTIVO"], mood: .amber)
        case .pedestrian:
            mood = .red; headline = L("Pedestrian area."); panel = GatePanelState(lines: ["AREA", "PEDONALE"], mood: .red)
        }
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
}

// MARK: Il pannello come oggetto

/// Il pannello del varco come un oggetto vero: cornice di metallo spazzolato con quattro viti, schermo nero a punti
/// che si accendono riga per riga, riflesso del vetro, palo corto e la luce che si spande intorno.
/// Quando lo stato cambia lo schermo gira come una paletta (con un colpo di vibrazione).
struct GatePanelObject: View {
    var panel: GatePanelState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: GatePanelState?
    @State private var angle = 0.0
    /// Quante righe di punti sono accese (da 0 a rows)
    @State private var lit = 0
    private static let rows = 16

    var body: some View {
        let s = shown ?? panel
        VStack(spacing: 0) {
            ZStack {
                // La luce che si spande sulla scena dietro
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(s.mood.color)
                    .frame(width: 300, height: 150)
                    .blur(radius: 50)
                    .opacity(0.45 * Double(lit) / Double(Self.rows))
                bezel(s)
            }
            pole(s)
        }
        .sensoryFeedback(.impact(weight: .heavy, intensity: 0.9), trigger: panel)
        .onAppear {
            shown = panel
            light()
        }
        .onChange(of: panel) { _, new in flip(to: new) }
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: s.lines.joined(separator: " ")))
    }

    private func bezel(_ s: GatePanelState) -> some View {
        ZStack {
            // Metallo spazzolato con luce dall'alto
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x8A93A8), Color(hex: 0x4A5266), Color(hex: 0x2A3042), Color(hex: 0x5A6378)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(LinearGradient(colors: [.white.opacity(0.65), .white.opacity(0.08), .black.opacity(0.5)],
                                               startPoint: .top, endPoint: .bottom), lineWidth: 1.5))
            screws
            screen(s)
                .padding(16)
                .rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0), anchor: .center, perspective: 0.5)
        }
        .frame(width: 270, height: 140)
        .shadow(color: .black.opacity(0.55), radius: 18, y: 14)
        .shadow(color: s.mood.color.opacity(0.35 * Double(lit) / Double(Self.rows)), radius: 26)
    }

    private var screws: some View {
        GeometryReader { g in
            ForEach(0..<4, id: \.self) { i in
                Screw(angle: Double(i) * 37 + 20)
                    .position(x: i % 2 == 0 ? 9 : g.size.width - 9, y: i < 2 ? 9 : g.size.height - 9)
            }
        }
    }

    private func screen(_ s: GatePanelState) -> some View {
        let color = s.mood.color
        return ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color(hex: 0x05070C))
            DotGrid(pitch: 4).opacity(0.9)
            VStack(spacing: 2) {
                ForEach(s.lines, id: \.self) { line in
                    Text(verbatim: line)
                        .font(Notte.dots(30))
                        .foregroundStyle(color)
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .shadow(color: color.opacity(0.9), radius: 3)
                        .shadow(color: color.opacity(0.6), radius: 10)
                }
            }
            .padding(.horizontal, 8)
            // I punti si accendono a righe, dall'alto in basso
            .mask(alignment: .top) {
                GeometryReader { g in
                    Rectangle().frame(height: g.size.height * Double(lit) / Double(Self.rows))
                }
            }
            // La trama a punti sopra il testo: sembra fatto di LED
            DotGrid(pitch: 3).opacity(0.35).blendMode(.multiply)
            // Il vetro: riflesso in diagonale e un filo di luce in alto
            LinearGradient(stops: [.init(color: .white.opacity(0.16), location: 0), .init(color: .white.opacity(0.04), location: 0.45),
                                   .init(color: .clear, location: 0.46), .init(color: .clear, location: 1)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .allowsHitTesting(false)
            // La fessura della paletta
            Rectangle().fill(Color.black.opacity(0.7)).frame(height: 1.5)
        }
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.black.opacity(0.8), lineWidth: 2))
    }

    private func pole(_ s: GatePanelState) -> some View {
        ZStack(alignment: .bottom) {
            // L'ombra a terra e la luce che ci cade sopra
            Ellipse().fill(s.mood.color.opacity(0.35 * Double(lit) / Double(Self.rows))).frame(width: 160, height: 26).blur(radius: 14)
            Ellipse().fill(Color.black.opacity(0.45)).frame(width: 60, height: 10).blur(radius: 4)
            Rectangle()
                .fill(LinearGradient(colors: [Color(hex: 0x3A4256), Color(hex: 0x9AA3B8), Color(hex: 0x4A5266), Color(hex: 0x262B3A)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 12, height: 74)
                .padding(.bottom, 4)
        }
        .frame(height: 84)
    }

    /// Le righe di punti che si accendono una dopo l'altra (tutte insieme con «Riduci movimento»)
    private func light() {
        if reduceMotion { lit = Self.rows; return }
        lit = 0
        Task { @MainActor in
            for i in 1...Self.rows {
                try? await Task.sleep(for: .milliseconds(28))
                lit = i
            }
        }
    }

    /// La paletta: metà giro, cambia la faccia, l'altra metà con un piccolo rimbalzo; poi i punti si riaccendono
    private func flip(to new: GatePanelState) {
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.35)) { shown = new }
            return
        }
        withAnimation(.easeIn(duration: 0.18)) { angle = 90 } completion: {
            shown = new
            angle = -90
            lit = 0
            withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { angle = 0 }
            light()
        }
    }
}

/// Una vite a croce nella cornice
private struct Screw: View {
    var angle: Double
    var body: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [Color(hex: 0xC9CFDC), Color(hex: 0x5A6276)], center: .topLeading, startRadius: 0, endRadius: 8))
            Circle().stroke(Color.black.opacity(0.5), lineWidth: 0.5)
            Rectangle().fill(Color.black.opacity(0.55)).frame(width: 6, height: 1.2).rotationEffect(.degrees(angle))
            Rectangle().fill(Color.black.opacity(0.55)).frame(width: 6, height: 1.2).rotationEffect(.degrees(angle + 90))
        }
        .frame(width: 9, height: 9)
    }
}

/// Senza Mapbox (niente rete): un fondo blu notte con la luce dello stato
private struct Home2Backdrop: View {
    var mood: Home2Answer.Mood
    var body: some View {
        ZStack {
            Notte.navy
            DotGrid(pitch: 22).opacity(0.5)
            RadialGradient(colors: [mood.color.opacity(0.25), .clear], center: .center, startRadius: 10, endRadius: 400)
        }
    }
}

// MARK: Parallasse

/// L'inclinazione del telefono (CoreMotion), smorzata: sposta mappa, pannello e testi di pochi punti, ognuno alla sua profondità
@MainActor final class ParallaxMotion: ObservableObject {
    @Published var offset: CGSize = .zero
    private let manager = CMMotionManager()
    private var reference: (roll: Double, pitch: Double)?

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30
        manager.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let data else { return }
            MainActor.assumeIsolated { self?.update(data.attitude.roll, data.attitude.pitch) }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        reference = nil
        offset = .zero
    }

    private func update(_ roll: Double, _ pitch: Double) {
        if reference == nil { reference = (roll, pitch) }
        guard let ref = reference else { return }
        // Al massimo ±1 (circa 25° di inclinazione), con un filtro che toglie il tremolio
        let x = max(-1, min(1, (roll - ref.roll) / 0.45))
        let y = max(-1, min(1, (pitch - ref.pitch) / 0.45))
        offset = CGSize(width: offset.width * 0.85 + x * 0.15, height: offset.height * 0.85 + y * 0.15)
    }
}
