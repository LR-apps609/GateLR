import CoreLocation
import MapKit
import Foundation
import SwiftUI

/// La scena della prima pagina: la ZTL del centro storico di Firenze (Settori A e B, perimetri veri di
/// Resources/Cities/firenze.json; il Settore A non ha varchi propri, si entra da quelli del B) e il varco di via Cavour.
/// I due percorsi seguono strade vere: calcolati con OSRM sui dati OpenStreetMap da Tools/intro_routes.py
/// (ramo «intro-routes») e copiati qui.
struct IntroScene {
    /// I perimetri da disegnare: prima il Settore B (l'anello esterno), poi il Settore A
    var zones: [[CLLocationCoordinate2D]]
    var gateName: String
    var gate: CLLocationCoordinate2D
    var zoneName: String
    var cityName: String

    /// Viale Lavagnini → piazza della Libertà → varco di via Cavour → giù per via Cavour fino al Duomo
    /// (OSRM, «lavagnini>cavour>duomo», 1,47 km; entra nella ZTL proprio al varco)
    static let badRoute: [CLLocationCoordinate2D] = coords([
        (43.782961, 11.257894), (43.783682, 11.260928), (43.783706, 11.261121), (43.783682, 11.261259),
        (43.783563, 11.261600), (43.783501, 11.261677), (43.783192, 11.262404), (43.778315, 11.258512),
        (43.778216, 11.258478), (43.777930, 11.258230), (43.775801, 11.256577), (43.774789, 11.255849)
    ])

    /// Stessa partenza, sempre fuori dalla ZTL lungo i viali fino al parcheggio Parterre (OSM node/559981489)
    /// (OSRM, «lavagnini>parterre», 1,9 km, nessun punto dentro i Settori A, B, O, F, G)
    static let goodRoute: [CLLocationCoordinate2D] = coords([
        (43.782961, 11.257894), (43.783701, 11.261029), (43.783682, 11.261259), (43.783430, 11.262060),
        (43.783425, 11.262217), (43.783481, 11.262421), (43.783595, 11.262573), (43.783820, 11.262737),
        (43.783959, 11.262806), (43.784084, 11.262771), (43.784174, 11.262657), (43.784517, 11.261784),
        (43.784499, 11.261410), (43.784416, 11.261178), (43.784330, 11.261073), (43.783833, 11.260624),
        (43.783744, 11.260489), (43.783688, 11.260322), (43.783357, 11.258901), (43.784175, 11.258531),
        (43.784816, 11.260981), (43.784825, 11.261076), (43.784805, 11.261211), (43.784358, 11.262463),
        (43.784074, 11.263169), (43.784068, 11.263230), (43.784770, 11.264684), (43.785455, 11.266207),
        (43.786267, 11.265419), (43.786397, 11.265212), (43.785551, 11.264404)
    ])

    /// Il contorno dei Settori A e B uniti (senza il confine interno), per la mappa Mapbox: unione dei perimetri di
    /// firenze.json calcolata con shapely e semplificata a ~4 m (72 punti)
    static let outline: [CLLocationCoordinate2D] = coords([
        (43.774935, 11.236359), (43.776655, 11.237823), (43.777571, 11.239607), (43.777578, 11.240172),
        (43.778030, 11.240624), (43.778748, 11.242899), (43.778883, 11.243028), (43.778955, 11.243230),
        (43.779409, 11.244673), (43.779535, 11.245457), (43.779600, 11.245472), (43.779628, 11.247142),
        (43.779540, 11.247198), (43.779560, 11.247376), (43.780148, 11.249367), (43.780092, 11.249688),
        (43.780126, 11.249825), (43.780471, 11.250170), (43.780575, 11.250525), (43.780712, 11.251666),
        (43.780663, 11.252057), (43.781679, 11.252951), (43.783611, 11.261181), (43.783054, 11.262465),
        (43.780548, 11.264812), (43.780315, 11.264555), (43.780220, 11.264533), (43.779977, 11.264984),
        (43.780147, 11.265196), (43.778165, 11.267030), (43.777770, 11.267206), (43.777138, 11.267642),
        (43.776738, 11.268093), (43.776440, 11.268622), (43.774535, 11.270420), (43.774096, 11.270700),
        (43.773676, 11.270816), (43.771208, 11.270720), (43.771085, 11.270346), (43.770867, 11.270109),
        (43.770540, 11.270207), (43.770343, 11.270475), (43.769766, 11.270142), (43.770272, 11.268635),
        (43.770311, 11.268301), (43.769674, 11.270097), (43.769096, 11.269764), (43.769221, 11.269541),
        (43.769065, 11.269198), (43.768936, 11.269157), (43.768767, 11.269303), (43.768694, 11.269537),
        (43.766861, 11.268459), (43.766978, 11.268103), (43.766940, 11.268052), (43.766360, 11.267989),
        (43.766660, 11.262571), (43.766891, 11.262547), (43.766954, 11.262084), (43.766876, 11.261991),
        (43.766701, 11.261950), (43.766925, 11.259023), (43.766810, 11.258952), (43.767468, 11.256027),
        (43.767741, 11.255130), (43.768455, 11.253317), (43.768459, 11.253165), (43.769324, 11.250766),
        (43.770425, 11.248313), (43.770730, 11.247758), (43.772577, 11.243405), (43.773571, 11.240618)
    ])

    static func coords(_ list: [(Double, Double)]) -> [CLLocationCoordinate2D] {
        list.map { CLLocationCoordinate2D(latitude: $0.0, longitude: $0.1) }
    }

    /// Tutto ciò che è fuori dalla ZTL (Settore B, che contiene il Settore A): un grande rettangolo con il buco della zona
    static func outside(_ scene: IntroScene) -> MKPolygon {
        let c = IntroCamera.frame
        let box = [(0.06, -0.08), (0.06, 0.08), (-0.06, 0.08), (-0.06, -0.08)].map {
            CLLocationCoordinate2D(latitude: c.latitude + $0.0, longitude: c.longitude + $0.1)
        }
        let hole = scene.zones.first ?? []
        return MKPolygon(coordinates: box, count: box.count,
                         interiorPolygons: hole.isEmpty ? nil : [MKPolygon(coordinates: hole, count: hole.count)])
    }

    /// Il varco di via Cavour (ptm-9 in firenze.json), se la città non fosse ancora letta
    static let gatePoint = CLLocationCoordinate2D(latitude: 43.78305, longitude: 11.262289)

    /// Il centro della vista d'insieme (Riduci movimento e disegno di riserva): tra il varco, il Duomo e il Parterre
    static let center = CLLocationCoordinate2D(latitude: 43.7790, longitude: 11.2600)

    @MainActor static func load(_ store: Store) -> IntroScene {
        let city = store.cities.first { $0.id == "firenze" }
        let zoneA = city?.zones.first { $0.id == "firenze-a" }
        let zoneB = city?.zones.first { $0.id == "firenze-b" }
        let gate = city?.zones.flatMap(\.gates).first { $0.id == "ptm-9" }
        return IntroScene(
            zones: [zoneB, zoneA].compactMap { $0?.perimeter.map(\.cl) },
            gateName: gate?.name ?? "Via Cavour",
            gate: gate?.location.cl ?? gatePoint,
            zoneName: "ZTL · " + String(format: L("Sector %@"), "A + B"),
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

    /// La frazione del percorso nel punto più vicino a c (per sapere quando l'auto passa sotto il varco)
    func fraction(near c: CLLocationCoordinate2D) -> Double {
        guard let i = points.indices.min(by: { IntroPath.meters(points[$0], c) < IntroPath.meters(points[$1], c) }) else { return 0 }
        return fraction(at: i)
    }

    /// La direzione generale del percorso, dalla partenza all'arrivo (gradi da nord, come MapCamera.heading)
    var bearing: Double {
        guard let a = points.first, let b = points.last else { return 0 }
        let k = cos(a.latitude * .pi / 180)
        let deg = atan2((b.longitude - a.longitude) * k, b.latitude - a.latitude) * 180 / .pi
        return (deg + 360).truncatingRemainder(dividingBy: 360)
    }

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
