import SwiftUI
import MapKit

/// La schermata di guida: la mappa segue l'auto nella direzione di marcia, manovra in alto,
/// la prossima ZTL sempre in vista, arrivo, velocità e pulsanti in basso.
struct DriveView: View {
    @EnvironmentObject var store: Store
    @ObservedObject var drive = DriveSession.shared
    @Environment(\.dismiss) private var dismiss
    @State private var camera: MapCameraPosition = .userLocation(followsHeading: true, fallback: .automatic)
    @State private var following = true
    @State private var movedByUs = Date.distantPast
    @State private var setDistance: Double = 0            // la distanza della camera decisa da noi
    /// Gradino di zoom (MapDetail): allontanando la mappa con le dita, i perimetri si semplificano
    @State private var bucket = 0
    @AppStorage("driveView") private var view = DriveViewStyle.guide.rawValue
    @AppStorage("vehicleMarker") private var marker = VehicleMarker.arrow.rawValue
    @AppStorage("vehicleColor") private var markerColor = VehicleColor.blue.rawValue

    /// Le viste della guida: 3D da vicino (la più chiara), classica, satellite, notte
    enum DriveViewStyle: String, CaseIterable, Identifiable {
        case guide, classic, satellite, night
        var id: String { rawValue }
        var title: String {
            switch self {
            case .guide: L("3D guide")
            case .classic: L("Classic")
            case .satellite: L("Satellite")
            case .night: L("Night")
            }
        }
        var symbol: String {
            switch self {
            case .guide: "view.3d"
            case .classic: "map"
            case .satellite: "globe.europe.africa.fill"
            case .night: "moon.fill"
            }
        }
    }
    private var style: DriveViewStyle { DriveViewStyle(rawValue: view) ?? .guide }

    var body: some View {
        ZStack(alignment: .top) {
            map
            VStack(spacing: 8) {
                maneuver
                ztlBar
                // Guida 3D: velocità e prossimo semaforo a sinistra, barra del viaggio a destra, sotto i pannelli
                if style == .guide { guideOverlay }
                Spacer()
                if !following {
                    HStack {
                        Spacer()
                        Button { following = true; follow(animated: true) } label: {
                            Label("Recenter", systemImage: "location.north.line.fill")
                                .font(.app(size: 15, weight: .semibold))
                                .padding(.horizontal, 16).frame(height: 44)
                                .background(.regularMaterial, in: Capsule())
                                .foregroundStyle(Theme.ink)
                        }
                    }
                    .transition(.opacity)
                }
                bottomBar
            }
            .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 12)
            .animation(.snappy, value: following)
        }
        .onAppear { follow(animated: false) }
        .onChange(of: drive.here) { if following { follow(animated: true) } }
        .statusBarHidden(false)
    }

    // MARK: Mappa

    private var map: some View {
        Map(position: $camera) {
            ForEach(drive.crossings) { c in
                MapPolygon(coordinates: MapShapes.coords(c.zone, store, bucket: bucket))   // già convertito, non a ogni posizione
                    .foregroundStyle(c.zone.type.color.opacity(c.zone.type == .green ? 0.18 : 0.14))
                    .stroke(c.zone.type.color, style: StrokeStyle(lineWidth: c.zone.type == .green ? 4 : 2.5, dash: c.zone.type == .green ? [] : [8, 5]))
            }
            // Il percorso: già fatto sottile e chiaro; davanti una fascia larga con bordo scuro, blu acceso e riflesso
            if drive.travelled.count > 1 {
                MapPolyline(coordinates: drive.travelled.map(\.cl))
                    .stroke(Color(hex: 0x9AA3AE).opacity(0.75), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
            }
            if drive.ahead.count > 1 {
                let line = drive.ahead.map(\.cl)
                MapPolyline(coordinates: line)
                    .stroke(routeEdge.opacity(0.95), style: StrokeStyle(lineWidth: wide + 6, lineCap: .round, lineJoin: .round))
                MapPolyline(coordinates: line)
                    .stroke(routeFill, style: StrokeStyle(lineWidth: wide, lineCap: .round, lineJoin: .round))
                MapPolyline(coordinates: line)
                    .stroke(routeShine.opacity(0.6), style: StrokeStyle(lineWidth: max(2, wide * 0.22), lineCap: .round, lineJoin: .round))
            }
            // La prossima manovra disegnata sulla strada
            if let m = drive.nextManeuverPoint, !drive.arrived {
                Annotation("", coordinate: m.cl, anchor: .center) {
                    Image(systemName: Self.symbol(for: drive.nextInstruction ?? ""))
                        .font(.app(size: 16, weight: .heavy)).foregroundStyle(Color(hex: 0x1D4FA8))
                        .frame(width: 34, height: 34).background(.white, in: Circle())
                        .overlay(Circle().stroke(Color(hex: 0x2F7BFF), lineWidth: 3))
                        .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                }
            }
            // I semafori lungo la strada davanti (OpenStreetMap): il disegno, senza tempi
            ForEach(Array(drive.signalsAhead.enumerated()), id: \.offset) { _, sgn in
                Annotation("", coordinate: sgn.cl, anchor: .bottom) { TrafficLightView(compact: style != .guide) }
            }
            // Dove si entra in ogni ZTL
            ForEach(drive.crossings) { c in
                if let e = c.entry {
                    Annotation("", coordinate: e.cl) {
                        Image(systemName: c.zone.type.symbol).font(.app(size: 11, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 26, height: 26).background(c.zone.type.color, in: Circle())
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                    }
                }
            }
            if let d = drive.destination {
                Marker(d.name, systemImage: "flag.checkered", coordinate: d.location.cl).tint(Theme.red)
            }
            if let h = drive.here {
                // La freccia dell'auto, girata nella direzione di marcia
                Annotation("", coordinate: h.cl, anchor: .center) {
                    VehicleMarkerView(marker: VehicleMarker(rawValue: marker) ?? .arrow,
                                      tint: VehicleColor(rawValue: markerColor) ?? .blue,
                                      heading: drive.course - currentHeading)
                }
            }
        }
        .mapStyle(mapStyle)
        .environment(\.colorScheme, style == .night ? .dark : colorScheme)
        .mapControls { MapCompass(); MapScaleView() }
        // Il dito sposta la mappa: si smette di seguire finché non tocchi «Ricentra»
        .simultaneousGesture(DragGesture(minimumDistance: 10).onChanged { _ in following = false })
        // Anche zoom e inclinazione fatti con le dita: se la camera non è più quella decisa da noi, compare «Ricentra»
        .onMapCameraChange(frequency: .onEnd) { ctx in
            let b = MapDetail.bucket(for: ctx.camera.distance)
            if b != bucket { bucket = b }
            guard following, setDistance > 0, Date().timeIntervalSince(movedByUs) > 0.3 else { return }
            if abs(ctx.camera.distance - setDistance) / setDistance > 0.25 { following = false }
        }
        .ignoresSafeArea()
    }

    @State private var currentHeading: Double = 0
    @Environment(\.colorScheme) private var colorScheme

    private var mapStyle: MapStyle {
        switch style {
        case .guide: .standard(elevation: .realistic, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false)
        case .classic: .standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: true)
        case .satellite: .hybrid(elevation: .realistic, pointsOfInterest: .excludingAll, showsTraffic: true)
        case .night: .standard(elevation: .realistic, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: true)
        }
    }

    /// Larghezza della fascia del percorso: più larga nella vista 3D da vicino
    private var wide: CGFloat { style == .guide ? 18 : 10 }
    /// Colori del percorso: nella Guida 3D una fascia verde smeraldo luminosa, nelle altre blu
    private var routeFill: Color { style == .guide ? Color(hex: 0x1ED67F) : Color(hex: 0x2F7BFF) }
    private var routeEdge: Color { style == .guide ? Color(hex: 0x0A7A44) : Color(hex: 0x0B2F73) }
    private var routeShine: Color { style == .guide ? Color(hex: 0xC8FFE2) : Color(hex: 0x9CCBFF) }

    /// La camera dietro l'auto: più lontana quando vai veloce, inclinata come un navigatore
    private func follow(animated: Bool) {
        guard let h = drive.here else { return }
        // 3D da vicino: camera bassa dietro l'auto; le altre viste un po' più alte
        let (base, pitch): (Double, Double) = switch style {
        case .guide: (240, 68)
        case .classic: (420, 45)
        case .satellite, .night: (380, 55)
        }
        let distance = min(1_100, max(base, base * 0.85 + drive.speed * 8))
        // La camera guarda un po' più avanti dell'auto, così si vede la strada che arriva
        let ahead = PathMath.offset(h, meters: distance * 0.18, bearing: drive.course)
        let cam = MapCamera(centerCoordinate: ahead.cl, distance: distance, heading: drive.course, pitch: pitch)
        movedByUs = Date()
        setDistance = distance
        currentHeading = drive.course
        if animated { withAnimation(.linear(duration: 0.9)) { camera = .camera(cam) } } else { camera = .camera(cam) }
    }

    private func overview() {
        guard let r = MapScreen.region(drive.path) else { return }
        following = false
        movedByUs = Date()
        currentHeading = 0
        withAnimation { camera = .region(r) }
    }

    // MARK: Guida 3D: velocità, prossimo semaforo, barra del percorso con le ZTL

    private var guideOverlay: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 10) {
                // La velocità in un cerchio bianco, numeri blu
                VStack(spacing: -2) {
                    Text("\(Int(drive.speed.rounded()))").font(.system(size: 26, weight: .heavy, design: .rounded)).monospacedDigit()
                        .foregroundStyle(Color(hex: 0x2F6FE4))
                    Text("km/h").font(.system(size: 10, weight: .semibold)).foregroundStyle(Color(hex: 0x5D6670))
                }
                .frame(width: 66, height: 66)
                .background(.white, in: Circle())
                .overlay(Circle().stroke(Color(hex: 0x2F6FE4).opacity(0.25), lineWidth: 3))
                .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
                // Il prossimo semaforo
                if let d = drive.nextSignal, d < 900 {
                    HStack(spacing: 6) {
                        TrafficLightView(compact: true)
                        Text(DriveSession.distanceText(d)).font(.system(size: 15, weight: .bold, design: .rounded)).monospacedDigit()
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color(hex: 0x2A323D).opacity(0.92), in: Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(String(format: L("Traffic light in %@"), DriveSession.distanceText(d)))
                }
            }
            Spacer()
            routeProgressBar
        }
        .padding(.top, 4)
        .allowsHitTesting(false)
    }

    /// La barra verticale del viaggio: verde la strada libera, rossa/gialla dove passi in una ZTL attiva, l'auto dove sei
    private var routeProgressBar: some View {
        let total = max(drive.routeLength, 1)
        let height: CGFloat = 240
        let segments: [(from: Double, to: Double, color: Color)] = drive.crossings.compactMap { c in
            guard let e = c.entry else { return nil }
            let start = max(0, total - PathMath.remaining(from: e, along: drive.path))
            let color: Color = switch c.answer.verdict {
            case .no: Color(hex: 0xFF3B30)
            case .yes: Color(hex: 0x1ED67F)
            default: Color(hex: 0xFFB800)
            }
            return (start, min(total, start + 600), color)
        }
        return ZStack(alignment: .bottom) {
            Capsule().fill(Color(hex: 0x1ED67F)).frame(width: 8, height: height)
            ForEach(Array(segments.enumerated()), id: \.offset) { _, s in
                Capsule().fill(s.color)
                    .frame(width: 8, height: max(8, height * CGFloat((s.to - s.from) / total)))
                    .offset(y: -height * CGFloat(s.from / total))
            }
            // il tratto già fatto, grigio, dal basso
            Capsule().fill(Color(hex: 0xB9C0C8)).frame(width: 8, height: height * CGFloat(min(1, drive.done / total)))
            Image(systemName: "location.north.circle.fill")
                .font(.system(size: 18)).foregroundStyle(.white, Color(hex: 0x2F6FE4))
                .offset(y: -height * CGFloat(min(1, drive.done / total)) + 9)
        }
        .frame(width: 22, height: height, alignment: .bottom)
        .padding(.vertical, 6)
        .background(.white.opacity(0.75), in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 4, y: 1)
        .accessibilityHidden(true)
    }

    // MARK: Pannelli

    private var maneuver: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: Self.symbol(for: drive.arrived ? "" : (drive.nextInstruction ?? "")))
                    .font(.app(size: 36, weight: .bold))
                    .frame(width: 58)
                VStack(alignment: .leading, spacing: 2) {
                    if drive.arrived {
                        Text("You have arrived").font(Theme.display(28))
                    } else if drive.rerouting {
                        Text("Recalculating…").font(Theme.display(26))
                    } else {
                        Text(DriveSession.distanceText(drive.toNext)).font(Theme.display(32)).monospacedDigit()
                        Text(drive.nextInstruction ?? drive.destination?.name ?? "")
                            .font(.app(size: 18, weight: .semibold)).lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            if let then = drive.thenInstruction, !drive.arrived {
                HStack(spacing: 8) {
                    Text("Then").font(.app(size: 14, weight: .semibold)).opacity(0.8)
                    Image(systemName: Self.symbol(for: then)).font(.app(size: 15, weight: .bold))
                    Text(then).font(.app(size: 14, weight: .semibold)).lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 9)
                .background(.black.opacity(0.18))
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .background(drive.arrived ? Theme.green : (style == .guide ? Color(hex: 0x2A323D) : Color(hex: 0x1D4FA8)))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        .accessibilityElement(children: .combine)
    }

    /// La prossima ZTL sul percorso, sempre in vista: rossa se non si entra, verde se è libera
    @ViewBuilder
    private var ztlBar: some View {
        if let n = drive.nextZTL {
            let v = n.answer.verdict
            HStack(spacing: 10) {
                Image(systemName: n.crossing.zone.type.symbol).font(.app(size: 15, weight: .bold))
                    .frame(width: 30, height: 30).background(.white.opacity(0.25), in: Circle())
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(n.crossing.zone.shortName) · \(DriveSession.distanceText(n.meters))").font(.app(size: 16, weight: .bold))
                    Text(v.short + (n.answer.gatesOn ? " · " + L("ZTL active") : " · " + L("ZTL not active")))
                        .font(.app(size: 13, weight: .medium)).opacity(0.92)
                }
                Spacer()
            }
            .foregroundStyle(v.onFill)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(v.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
            .animation(.snappy, value: n.meters)
        } else if !drive.path.isEmpty {
            Label("No ZTL on the way.", systemImage: "checkmark.circle.fill")
                .font(.app(size: 15, weight: .semibold)).foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.green, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(drive.eta.map { RuleEngine.format($0, .init(date: .omitted, time: .shortened)) } ?? "–")
                    .font(Theme.display(28)).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text(remainingText)
                    .font(.app(size: 14)).foregroundStyle(Theme.muted)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .layoutPriority(1)
            Spacer()
            if style != .guide {
                VStack(spacing: 0) {
                    Text("\(Int(drive.speed.rounded()))").font(Theme.display(20)).monospacedDigit()
                    Text("km/h").font(.app(size: 10, weight: .semibold)).foregroundStyle(Theme.muted)
                }
                .frame(width: 52, height: 52).background(Theme.raised, in: Circle())
                .accessibilityElement(children: .combine)
            }
            roundButton(drive.muted ? "speaker.slash.fill" : "speaker.wave.2.fill", L(drive.muted ? "Voice off" : "Voice on")) { drive.muted.toggle() }
            roundButton("point.topleft.down.to.point.bottomright.curvepath", L("Overview")) { overview() }
            Menu {
                Picker(L("View"), selection: $view) {
                    ForEach(DriveViewStyle.allCases) { v in Label(v.title, systemImage: v.symbol).tag(v.rawValue) }
                }
            } label: {
                Image(systemName: style.symbol).font(.app(size: 17, weight: .semibold))
                    .frame(width: 44, height: 44).background(Theme.raised, in: Circle()).foregroundStyle(Theme.ink)
            }
            .accessibilityLabel(L("View"))
            .onChange(of: view) { if following { follow(animated: true) } }
            Button {
                drive.stop()
                dismiss()
            } label: {
                Text("End").font(.app(size: 17, weight: .bold))
                    .lineLimit(1).fixedSize()
                    .padding(.horizontal, 16).frame(height: 52)
                    .background(Theme.red, in: Capsule()).foregroundStyle(.white)
            }
            .accessibilityIdentifier("drive.end")
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 10, y: -2)
    }

    private var remainingText: String {
        let left: TimeInterval = drive.eta.map { max(0, $0.timeIntervalSinceNow) } ?? 0
        let km: String = Measurement(value: drive.remaining, unit: UnitLength.meters).formatted(.measurement(width: .abbreviated, usage: .road))
        return VerdictCard.duration(left) + " · " + km
    }

    private func roundButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.app(size: 17, weight: .semibold))
                .frame(width: 44, height: 44).background(Theme.raised, in: Circle()).foregroundStyle(Theme.ink)
        }
        .accessibilityLabel(label)
    }

    /// Il simbolo della manovra, dalle parole dell'istruzione (in inglese, italiano e tedesco)
    nonisolated static func symbol(for instruction: String) -> String {
        let s = instruction.lowercased()
        func has(_ words: String...) -> Bool { words.contains { s.contains($0) } }
        if s.isEmpty { return "flag.checkered" }
        if has("roundabout", "rotonda", "rotatoria", "kreisverkehr") { return "arrow.triangle.turn.up.right.circle" }
        if has("u-turn", "inversione", "wenden") { return "arrow.uturn.left" }
        if has("slight left", "leggermente a sinistra", "leicht links") { return "arrow.up.left" }
        if has("slight right", "leggermente a destra", "leicht rechts") { return "arrow.up.right" }
        if has("left", "sinistra", "links") { return "arrow.turn.up.left" }
        if has("right", "destra", "rechts") { return "arrow.turn.up.right" }
        if has("arrive", "destinazione", "ziel") { return "flag.checkered" }
        return "arrow.up"
    }
}
