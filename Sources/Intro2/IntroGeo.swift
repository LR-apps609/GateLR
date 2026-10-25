import CoreLocation
import Foundation
import SwiftUI

/// La scena della prima pagina: il perimetro vero del Settore A di Firenze e il varco di via Guelfa
/// (Resources/Cities/firenze.json), con due percorsi scritti a mano lungo le strade del centro.
struct IntroScene {
    var perimeter: [CLLocationCoordinate2D]
    var gateName: String
    var gate: CLLocationCoordinate2D
    var zoneName: String
    var cityName: String

    /// Da via Guelfa (lato via San Gallo) verso ovest, il varco, giù per via de' Ginori fino a San Lorenzo e al Duomo
    static let badRoute: [CLLocationCoordinate2D] = coords([
        (43.77845, 11.25715), (43.77810, 11.25580), (43.777767, 11.254444), (43.77690, 11.25462),
        (43.77580, 11.25468), (43.77500, 11.25495), (43.77440, 11.25540), (43.77380, 11.25590),
    ])

    /// Lo stesso punto di partenza, poi verso sud-est restando fuori dal Settore A (a 45 m dal perimetro)
    /// fino al parcheggio vicino a Sant'Ambrogio. Disegnato per il prototipo: non è un percorso calcolato.
    static let goodRoute: [CLLocationCoordinate2D] = coords([
        (43.77845, 11.25715), (43.77770, 11.25700), (43.77610, 11.25750), (43.774467, 11.258100),
        (43.773408, 11.259897), (43.773087, 11.260453), (43.772396, 11.261681), (43.772080, 11.262116),
        (43.771887, 11.262536), (43.771334, 11.262956), (43.771050, 11.263700),
    ])

    static func coords(_ list: [(Double, Double)]) -> [CLLocationCoordinate2D] {
        list.map { CLLocationCoordinate2D(latitude: $0.0, longitude: $0.1) }
    }

    /// L'indice del varco in badRoute
    static let gateIndex = 2

    /// Il centro della ripresa: tra il Duomo e piazza della Signoria, spostato verso il varco
    static let center = CLLocationCoordinate2D(latitude: 43.7755, longitude: 11.2562)

    @MainActor static func load(_ store: Store) -> IntroScene {
        let city = store.cities.first { $0.id == "firenze" }
        let zone = city?.zones.first { $0.id == "firenze-a" }
        let gate = city?.zones.flatMap(\.gates).first { $0.id == "ptm-18" }
        return IntroScene(
            perimeter: (zone?.perimeter ?? []).map(\.cl),
            gateName: gate?.name ?? "Via Guelfa",
            gate: gate?.location.cl ?? badRoute[gateIndex],
            zoneName: zone?.localizedName ?? "Settore A",
            cityName: city?.localizedName ?? "Firenze")
    }
}

/// Un percorso misurato in metri, per far scorrere l'auto a velocità costante
struct IntroPath {
    let points: [CLLocationCoordinate2D]
    let cumulative: [Double]
    var length: Double { cumulative.last ?? 0 }

    init(_ points: [CLLocationCoordinate2D]) {
        self.points = points
        var acc: [Double] = [0]
        for i in 1..<max(points.count, 1) {
            acc.append(acc[i - 1] + IntroPath.meters(points[i - 1], points[i]))
        }
        cumulative = acc
    }

    static func meters(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude).distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    /// La frazione del percorso a cui si trova il punto i
    func fraction(at i: Int) -> Double { length > 0 ? cumulative[i] / length : 0 }

    /// Il punto a una frazione del percorso
    func point(_ f: Double) -> CLLocationCoordinate2D {
        guard points.count > 1 else { return points.first ?? IntroScene.center }
        let d = min(max(f, 0), 1) * length
        var i = 1
        while i < points.count - 1 && cumulative[i] < d { i += 1 }
        let seg = cumulative[i] - cumulative[i - 1]
        let t = seg > 0 ? (d - cumulative[i - 1]) / seg : 0
        let a = points[i - 1], b = points[i]
        return CLLocationCoordinate2D(latitude: a.latitude + (b.latitude - a.latitude) * t,
                                      longitude: a.longitude + (b.longitude - a.longitude) * t)
    }

    /// Il percorso fino alla frazione f (per disegnarlo mentre l'auto avanza)
    func prefix(_ f: Double) -> [CLLocationCoordinate2D] {
        guard points.count > 1 else { return points }
        let d = min(max(f, 0), 1) * length
        var out = [points[0]]
        var i = 1
        while i < points.count && cumulative[i] <= d { out.append(points[i]); i += 1 }
        out.append(point(f))
        return out
    }
}

/// La stessa ripresa inclinata della mappa, calcolata a mano: serve al disegno di riserva senza rete.
/// Prospettiva semplice: camera a «distance» metri dal centro, inclinata di «pitch» gradi dalla verticale.
struct IntroProjector {
    var center: CLLocationCoordinate2D
    var heading: Double        // gradi, come MapCamera
    var pitch: Double          // gradi
    var distance: Double       // metri
    var size: CGSize

    func point(_ c: CLLocationCoordinate2D) -> CGPoint {
        // metri a est e a nord del centro
        let k = cos(center.latitude * .pi / 180)
        let east = (c.longitude - center.longitude) * 111_320 * k
        let north = (c.latitude - center.latitude) * 111_320
        // rotazione: la direzione della camera in alto
        let h = heading * .pi / 180
        let x = east * cos(h) - north * sin(h)
        let y = east * sin(h) + north * cos(h)
        let th = pitch * .pi / 180
        let depth = distance + y * sin(th)
        let focal = Double(size.height) * 1.1
        let sx = x * focal / max(depth, 1)
        let sy = y * cos(th) * focal / max(depth, 1)
        return CGPoint(x: Double(size.width) / 2 + sx, y: Double(size.height) * 0.48 - sy)
    }

    func path(_ coords: [CLLocationCoordinate2D], closed: Bool = false) -> Path {
        var p = Path()
        guard let first = coords.first else { return p }
        p.move(to: point(first))
        for c in coords.dropFirst() { p.addLine(to: point(c)) }
        if closed { p.closeSubpath() }
        return p
    }
}
