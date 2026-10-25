import SwiftUI
import MapKit

/// La schermata di guida: la mappa segue l'auto nella direzione di marcia, manovra in alto,
/// la prossima ZTL sempre in vista, arrivo, velocità e pulsanti in basso.
struct DriveView: View {
    @EnvironmentObject var store: Store
    @ObservedObject var drive = DriveSession.shared
    @Environment(\.dismiss) private var dismiss
    @State private var following = true
    @State private var overviewToken = 0
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
                        Button { following = true } label: {
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
        .statusBarHidden(false)
    }

    // MARK: Mappa

    /// La mappa con MKMapView: camera e auto si muovono a ogni fotogramma, le linee si disegnano una volta per percorso
    private var map: some View {
        DriveMapView(drive: drive, store: store, style: style,
                     marker: VehicleMarker(rawValue: marker) ?? .arrow,
                     tint: VehicleColor(rawValue: markerColor) ?? .blue,
                     following: $following, overviewToken: overviewToken, routeVersion: drive.routeVersion,
                     maneuver: drive.arrived ? nil : drive.nextManeuverPoint,
                     maneuverSymbol: Self.symbol(for: drive.nextInstruction ?? ""),
                     colorScheme: colorScheme)
            .ignoresSafeArea()
    }

    @Environment(\.colorScheme) private var colorScheme

    /// Panoramica del percorso: si smette di seguire l'auto
    private func overview() {
        guard !drive.path.isEmpty else { return }
        following = false
        overviewToken += 1
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
            let start = drive.entryAlong[c.id] ?? max(0, total - PathMath.remaining(from: e, along: drive.path))
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
