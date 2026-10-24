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

    var body: some View {
        ZStack(alignment: .top) {
            map
            VStack(spacing: 8) {
                maneuver
                ztlBar
                Spacer()
                if !following {
                    HStack {
                        Spacer()
                        Button { following = true; follow(animated: true) } label: {
                            Label("Recenter", systemImage: "location.north.line.fill")
                                .font(.system(size: 15, weight: .semibold))
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
                MapPolygon(coordinates: c.zone.perimeter.map(\.cl))
                    .foregroundStyle(c.zone.type.color.opacity(c.zone.type == .green ? 0.18 : 0.14))
                    .stroke(c.zone.type.color, style: StrokeStyle(lineWidth: c.zone.type == .green ? 4 : 2.5, dash: c.zone.type == .green ? [] : [8, 5]))
            }
            // Il percorso: già fatto in grigio, davanti in blu con il bordo bianco
            if drive.travelled.count > 1 {
                MapPolyline(coordinates: drive.travelled.map(\.cl))
                    .stroke(Color.gray.opacity(0.7), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
            }
            if drive.ahead.count > 1 {
                MapPolyline(coordinates: drive.ahead.map(\.cl))
                    .stroke(.white, style: StrokeStyle(lineWidth: 13, lineCap: .round, lineJoin: .round))
                MapPolyline(coordinates: drive.ahead.map(\.cl))
                    .stroke(Color(hex: 0x2F6FE4), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
            }
            // Dove si entra in ogni ZTL
            ForEach(drive.crossings) { c in
                if let e = c.entry {
                    Annotation("", coordinate: e.cl) {
                        Image(systemName: c.zone.type.symbol).font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
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
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 22, weight: .bold)).foregroundStyle(Color(hex: 0x2F6FE4))
                        .rotationEffect(.degrees(drive.course - currentHeading))
                        .frame(width: 44, height: 44)
                        .background(.white, in: Circle())
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll, showsTraffic: true))
        .mapControls { MapCompass(); MapScaleView() }
        // Il dito sposta la mappa: si smette di seguire finché non tocchi «Ricentra»
        .simultaneousGesture(DragGesture(minimumDistance: 10).onChanged { _ in following = false })
        .ignoresSafeArea()
    }

    @State private var currentHeading: Double = 0

    /// La camera dietro l'auto: più lontana quando vai veloce, inclinata come un navigatore
    private func follow(animated: Bool) {
        guard let h = drive.here else { return }
        let distance = min(1_100, max(450, 380 + drive.speed * 9))
        let cam = MapCamera(centerCoordinate: h.cl, distance: distance, heading: drive.course, pitch: 55)
        movedByUs = Date()
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

    // MARK: Pannelli

    private var maneuver: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: Self.symbol(for: drive.arrived ? "" : (drive.nextInstruction ?? "")))
                    .font(.system(size: 36, weight: .bold))
                    .frame(width: 58)
                VStack(alignment: .leading, spacing: 2) {
                    if drive.arrived {
                        Text("You have arrived").font(Theme.display(28))
                    } else if drive.rerouting {
                        Text("Recalculating…").font(Theme.display(26))
                    } else {
                        Text(DriveSession.distanceText(drive.toNext)).font(Theme.display(32)).monospacedDigit()
                        Text(drive.nextInstruction ?? drive.destination?.name ?? "")
                            .font(.system(size: 18, weight: .semibold)).lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            if let then = drive.thenInstruction, !drive.arrived {
                HStack(spacing: 8) {
                    Text("Then").font(.system(size: 14, weight: .semibold)).opacity(0.8)
                    Image(systemName: Self.symbol(for: then)).font(.system(size: 15, weight: .bold))
                    Text(then).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 9)
                .background(.black.opacity(0.18))
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .background(drive.arrived ? Theme.green : Color(hex: 0x1D4FA8))
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
                Image(systemName: n.crossing.zone.type.symbol).font(.system(size: 15, weight: .bold))
                    .frame(width: 30, height: 30).background(.white.opacity(0.25), in: Circle())
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(n.crossing.zone.shortName) · \(DriveSession.distanceText(n.meters))").font(.system(size: 16, weight: .bold))
                    Text(v.short + (n.answer.gatesOn ? " · " + L("ZTL active") : " · " + L("ZTL not active")))
                        .font(.system(size: 13, weight: .medium)).opacity(0.92)
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
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.green, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(drive.eta.map { $0.formatted(date: .omitted, time: .shortened) } ?? "–")
                    .font(Theme.display(28)).monospacedDigit()
                Text(remainingText)
                    .font(.system(size: 14)).foregroundStyle(Theme.muted)
            }
            Spacer()
            VStack(spacing: 0) {
                Text("\(Int(drive.speed.rounded()))").font(Theme.display(20)).monospacedDigit()
                Text("km/h").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.muted)
            }
            .frame(width: 52, height: 52).background(Theme.raised, in: Circle())
            .accessibilityElement(children: .combine)
            roundButton(drive.muted ? "speaker.slash.fill" : "speaker.wave.2.fill", L(drive.muted ? "Voice off" : "Voice on")) { drive.muted.toggle() }
            roundButton("point.topleft.down.to.point.bottomright.curvepath", L("Overview")) { overview() }
            Button {
                drive.stop()
                dismiss()
            } label: {
                Text("End").font(.system(size: 17, weight: .bold))
                    .padding(.horizontal, 18).frame(height: 52)
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
            Image(systemName: symbol).font(.system(size: 17, weight: .semibold))
                .frame(width: 48, height: 48).background(Theme.raised, in: Circle()).foregroundStyle(Theme.ink)
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
