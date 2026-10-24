import Foundation
import SwiftUI

/// I semafori (OpenStreetMap, ODbL) salvati nell'app: Resources/Signals/<città>.json = [[lat, lon], …].
/// Servono a disegnarli lungo il percorso nella vista «Guida 3D». Nessun tempo reale: solo dove sono.
enum TrafficSignals {
    static let all: [Coordinate] = {
        let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "Signals") ?? []
        return urls.flatMap { url -> [Coordinate] in
            guard let data = try? Data(contentsOf: url),
                  let list = try? JSONDecoder().decode([[Double]].self, from: data) else { return [] }
            return list.compactMap { $0.count == 2 ? Coordinate(lat: $0[0], lon: $0[1]) : nil }
        }
    }()

    /// I semafori vicini alla strada (entro «near» metri), con la loro distanza dall'inizio del percorso
    static func along(_ path: [Coordinate], near: Double = 22) -> [(point: Coordinate, along: Double)] {
        guard path.count > 1, !all.isEmpty else { return [] }
        let lats = path.map(\.lat), lons = path.map(\.lon)
        let (s, n, w, e) = (lats.min()! - 0.002, lats.max()! + 0.002, lons.min()! - 0.002, lons.max()! + 0.002)
        let candidates = all.filter { $0.lat > s && $0.lat < n && $0.lon > w && $0.lon < e }
        guard !candidates.isEmpty else { return [] }
        // Distanza cumulata a ogni punto del percorso
        var cum = [0.0]
        for (a, b) in zip(path, path.dropFirst()) { cum.append(cum.last! + PathMath.meters(a, b)) }
        var out: [(Coordinate, Double)] = []
        for c in candidates {
            var best = (d: Double.infinity, i: 0)
            for (i, p) in path.enumerated() { let d = PathMath.meters(c, p); if d < best.d { best = (d, i) } }
            if best.d < near { out.append((c, cum[best.i])) }
        }
        return out.sorted { $0.1 < $1.1 }.map { (point: $0.0, along: $0.1) }
    }
}

/// Il disegno del semaforo: tre luci su fondo scuro, come sui navigatori più nuovi
struct TrafficLightView: View {
    var compact = false
    var body: some View {
        VStack(spacing: compact ? 1.5 : 2) {
            Circle().fill(Color(hex: 0xFF3B30))
            Circle().fill(Color(hex: 0xFFCC00))
            Circle().fill(Color(hex: 0x34C759))
        }
        .padding(compact ? 2.5 : 3)
        .frame(width: compact ? 11 : 14, height: compact ? 28 : 36)
        .background(Color(hex: 0x1C1F24), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(.white.opacity(0.85), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
        .accessibilityLabel(L("Traffic light"))
    }
}
