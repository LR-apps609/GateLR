import SwiftUI
import MapKit

/// La schermata di guida: manovra in alto, mappa che segue l'auto, avviso ZTL, arrivo e tempo in basso
struct DriveView: View {
    @EnvironmentObject var store: Store
    @ObservedObject var drive = DriveSession.shared
    @Environment(\.dismiss) private var dismiss
    @State private var camera: MapCameraPosition = .userLocation(followsHeading: true, fallback: .automatic)

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $camera) {
                ForEach(drive.crossings) { c in
                    MapPolygon(coordinates: c.zone.perimeter.map(\.cl))
                        .foregroundStyle(c.zone.type.color.opacity(0.14))
                        .stroke(c.zone.type.color, style: StrokeStyle(lineWidth: 2, dash: [8, 5]))
                }
                if !drive.path.isEmpty {
                    MapPolyline(coordinates: drive.path.map(\.cl))
                        .stroke(Theme.blueFill, style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                }
                if let d = drive.destination {
                    Marker(d.name, systemImage: "flag.checkered", coordinate: d.location.cl).tint(Theme.red)
                }
                if let h = drive.here, RoutePlanner.testOrigin != nil {
                    // Solo nelle foto automatiche (nel simulatore non c'è il GPS)
                    Annotation("", coordinate: h.cl) { Circle().fill(Theme.blueFill).frame(width: 18, height: 18).overlay(Circle().stroke(.white, lineWidth: 3)) }
                }
                UserAnnotation()
            }
            .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
            .mapControls { MapCompass() }
            .ignoresSafeArea()

            VStack(spacing: 10) {
                maneuver
                if let w = drive.warning {
                    Label(w, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.red, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
                bottomBar
            }
            .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 12)
            .animation(.snappy, value: drive.warning)
        }
        .onAppear {
            if let h = drive.here, RoutePlanner.testOrigin != nil {
                camera = .camera(MapCamera(centerCoordinate: h.cl, distance: 900, heading: 0, pitch: 50))
            }
        }
    }

    private var maneuver: some View {
        HStack(spacing: 14) {
            Image(systemName: Self.symbol(for: drive.arrived ? "" : (drive.nextInstruction ?? "")))
                .font(.system(size: 34, weight: .bold))
                .frame(width: 56)
            VStack(alignment: .leading, spacing: 2) {
                if drive.arrived {
                    Text("You have arrived").font(Theme.display(28))
                } else if drive.rerouting {
                    Text("Recalculating…").font(Theme.display(26))
                } else {
                    Text(DriveSession.distanceText(drive.toNext)).font(Theme.display(30)).monospacedDigit()
                    Text(drive.nextInstruction ?? drive.destination?.name ?? "")
                        .font(.system(size: 17, weight: .semibold)).lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(drive.arrived ? Theme.green : Theme.blueFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
        .accessibilityElement(children: .combine)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(drive.eta.map { $0.formatted(date: .omitted, time: .shortened) } ?? "–")
                    .font(Theme.display(26)).monospacedDigit()
                Text("\(VerdictCard.duration(drive.eta.map { max(0, $0.timeIntervalSinceNow) } ?? 0)) · \(Measurement(value: drive.remaining, unit: UnitLength.meters).formatted(.measurement(width: .abbreviated, usage: .road)))")
                    .font(.system(size: 14)).foregroundStyle(Theme.muted)
            }
            Spacer()
            Button { drive.muted.toggle() } label: {
                Image(systemName: drive.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 50, height: 50).background(Theme.raised, in: Circle()).foregroundStyle(Theme.ink)
            }
            .accessibilityLabel(L(drive.muted ? "Voice off" : "Voice on"))
            Button {
                drive.stop()
                dismiss()
            } label: {
                Text("End").font(.system(size: 17, weight: .bold))
                    .padding(.horizontal, 22).frame(height: 50)
                    .background(Theme.red, in: Capsule()).foregroundStyle(.white)
            }
            .accessibilityIdentifier("drive.end")
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 10, y: -2)
    }

    /// Il simbolo della manovra, dalle parole dell'istruzione (in inglese, italiano e tedesco)
    static func symbol(for instruction: String) -> String {
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
