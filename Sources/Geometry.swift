import Foundation

/// Perimetri semplificati per la mappa vista da lontano (Douglas–Peucker sulle coordinate).
/// Da vicino si disegna il perimetro intero; da lontano bastano molti meno punti e la mappa resta fluida
/// anche con l'Area B di Milano, la Scudo Verde di Firenze e Roma insieme.
enum Simplifier {
    /// Distanza di p dal segmento a–b, in gradi di latitudine (la longitudine è ridotta con cos(lat),
    /// così un grado vale la stessa strada in tutte le direzioni)
    static func segmentDistance(_ p: Coordinate, _ a: Coordinate, _ b: Coordinate) -> Double {
        let k = cos(a.lat * .pi / 180)
        let px = (p.lon - a.lon) * k, py = p.lat - a.lat
        let bx = (b.lon - a.lon) * k, by = b.lat - a.lat
        let len2 = bx * bx + by * by
        guard len2 > 0 else { return (px * px + py * py).squareRoot() }
        let t = max(0, min(1, (px * bx + py * by) / len2))
        let dx = px - t * bx, dy = py - t * by
        return (dx * dx + dy * dy).squareRoot()
    }

    /// Tiene il primo e l'ultimo punto e quelli che si scostano più di «tolerance» (gradi di latitudine)
    /// dalla linea semplificata. Senza ricorsione: perimetri da migliaia di punti non riempiono lo stack.
    static func simplify(_ points: [Coordinate], tolerance: Double) -> [Coordinate] {
        guard points.count > 2, tolerance > 0 else { return points }
        var keep = [Bool](repeating: false, count: points.count)
        keep[0] = true
        keep[points.count - 1] = true
        var stack: [(Int, Int)] = [(0, points.count - 1)]
        while let span = stack.popLast() {
            let first = span.0, last = span.1
            guard last > first + 1 else { continue }
            var farthest = first
            var maxDistance = 0.0
            for i in (first + 1)..<last {
                let d = segmentDistance(points[i], points[first], points[last])
                if d > maxDistance { maxDistance = d; farthest = i }
            }
            if maxDistance > tolerance {
                keep[farthest] = true
                stack.append((first, farthest))
                stack.append((farthest, last))
            }
        }
        var out: [Coordinate] = []
        out.reserveCapacity(points.count / 4 + 2)
        for i in points.indices where keep[i] { out.append(points[i]) }
        return out
    }

    /// Per un poligono: se ne restano meno di 4 punti la forma sparirebbe, e si tiene quella intera
    static func simplifyPolygon(_ points: [Coordinate], tolerance: Double) -> [Coordinate] {
        let out = simplify(points, tolerance: tolerance)
        return out.count < 4 ? points : out
    }
}

/// Livello di dettaglio della mappa: la distanza della camera si arrotonda a pochi gradini,
/// e le forme si ricalcolano solo quando si cambia gradino (alla fine del gesto, non durante)
enum MapDetail {
    /// Fino a questa distanza della camera (metri) il perimetro è quello intero: da vicino la mappa è uguale a prima.
    /// La distanza della camera di MapKit è circa tre volte la larghezza visibile: a 8 km si vede un centro storico intero.
    static let fullDetailDistance: Double = 8_000
    /// Oltre questa distanza (metri) i varchi non si disegnano: si vede una città intera e sarebbero pallini sovrapposti
    static let gateDistance: Double = 40_000
    /// Metri di strada per punto dello schermo, circa, a una certa distanza della camera
    static func metersPerPoint(_ distance: Double) -> Double { distance / 1_300 }

    /// 0 = da vicino (perimetro intero), poi un gradino ogni volta che la distanza raddoppia
    static func bucket(for distance: Double) -> Int {
        guard distance > fullDetailDistance else { return 0 }
        return min(8, 1 + Int(log2(distance / fullDetailDistance)))
    }

    /// La tolleranza della semplificazione (gradi di latitudine): mezzo punto dello schermo
    /// alla distanza più vicina del gradino, quindi la differenza non si vede
    static func tolerance(for bucket: Int) -> Double {
        guard bucket > 0 else { return 0 }
        let near = fullDetailDistance * pow(2, Double(bucket - 1))
        return metersPerPoint(near) * 0.5 / 111_000
    }
}
