import CoreLocation
import MapKit
import Foundation
import SwiftUI

/// La scena della prima pagina: la ZTL del centro storico di Firenze (Settori A e B, perimetri veri di
/// Resources/Cities/firenze.json; il Settore A non ha varchi propri, si entra da quelli del B), il varco di via Cavour,
/// un ristorante appena fuori dalla ZTL dall'altra parte (via Gioberti, vicino a piazza Beccaria; generico, non un locale
/// vero) e il Parcheggio Beccaria. I percorsi seguono strade vere: calcolati con OSRM sui dati OpenStreetMap da
/// Tools/intro_routes.py (ramo «intro-routes»), semplificati a ~1 m e copiati qui.
struct IntroScene {
    /// I perimetri da disegnare: prima il Settore B (l'anello esterno), poi il Settore A
    var zones: [[CLLocationCoordinate2D]]
    var gateName: String
    var gate: CLLocationCoordinate2D
    var zoneName: String
    var cityName: String

    /// 1. «La strada più diretta»: viale Lavagnini → piazza della Libertà → dentro dal varco di via Cavour → via degli Alfani,
    /// via dei Pilastri, via dei Pepi, via Ghibellina → fuori a piazza Beccaria → via Gioberti (OSRM, 3,5 km, 9,7 min; 2,5 km nella ZTL)
    static let direct: [CLLocationCoordinate2D] = coords([
        (43.782961, 11.257894), (43.783682, 11.260928), (43.783706, 11.261121), (43.783682, 11.261259),
        (43.783563, 11.261600), (43.783501, 11.261677), (43.783192, 11.262404), (43.782339, 11.261742),
        (43.778315, 11.258512), (43.778216, 11.258478), (43.778024, 11.258330), (43.777930, 11.258230),
        (43.776729, 11.257305), (43.775702, 11.259719), (43.773866, 11.263594), (43.773128, 11.264515),
        (43.772175, 11.263914), (43.771400, 11.263488), (43.769979, 11.262754), (43.768574, 11.269661),
        (43.768319, 11.269513), (43.768249, 11.269758), (43.768104, 11.270143), (43.768072, 11.270513),
        (43.768082, 11.271201), (43.769286, 11.271130), (43.768981, 11.273724), (43.769502, 11.274132),
        (43.769585, 11.273885)
    ])

    /// 2. «Con GateLR»: stessa partenza, sempre fuori da ogni ZTL lungo i viali Matteotti, Gramsci e della Giovine Italia
    /// (OSRM, 2,9 km, 5,4 min, nessun metro nei Settori A, B, O, F, G): 4 minuti in meno della strada dentro la ZTL
    static let around: [CLLocationCoordinate2D] = coords([
        (43.782961, 11.257894), (43.783682, 11.260928), (43.783706, 11.261121), (43.783682, 11.261259),
        (43.783563, 11.261600), (43.783501, 11.261677), (43.783101, 11.262588), (43.783050, 11.262663),
        (43.782693, 11.263021), (43.781337, 11.264309), (43.778321, 11.267124), (43.778126, 11.267238),
        (43.777818, 11.267373), (43.777481, 11.267563), (43.777238, 11.267753), (43.776921, 11.268109),
        (43.776518, 11.268728), (43.776377, 11.268903), (43.774957, 11.270248), (43.774429, 11.270710),
        (43.774210, 11.270835), (43.773969, 11.270936), (43.773847, 11.270976), (43.773616, 11.271013),
        (43.771343, 11.270910), (43.771193, 11.270884), (43.771078, 11.270850), (43.770889, 11.270719),
        (43.770769, 11.270666), (43.770675, 11.270648), (43.770433, 11.270656), (43.770291, 11.270615),
        (43.769649, 11.270276), (43.768319, 11.269513), (43.768249, 11.269758), (43.768104, 11.270143),
        (43.768072, 11.270513), (43.768082, 11.271201), (43.769286, 11.271130), (43.768981, 11.273724),
        (43.769502, 11.274132), (43.769585, 11.273885)
    ])

    /// 3. «Oppure parcheggia vicino»: lungo gli stessi viali fino al Parcheggio Beccaria, sotterraneo (OSM way/231098032,
    /// in Resources/Parking/firenze.json) (OSRM, 2,6 km, 4,6 min, sempre fuori dalla ZTL)
    static let toParking: [CLLocationCoordinate2D] = coords([
        (43.782961, 11.257894), (43.783682, 11.260928), (43.783706, 11.261121), (43.783682, 11.261259),
        (43.783563, 11.261600), (43.783501, 11.261677), (43.783146, 11.262506), (43.783050, 11.262663),
        (43.782779, 11.262937), (43.781337, 11.264309), (43.778321, 11.267124), (43.778126, 11.267238),
        (43.777818, 11.267373), (43.777481, 11.267563), (43.777238, 11.267753), (43.776921, 11.268109),
        (43.776518, 11.268728), (43.776377, 11.268903), (43.774712, 11.270475), (43.774429, 11.270710),
        (43.774092, 11.270890), (43.773740, 11.270999), (43.773485, 11.271015), (43.771343, 11.270910),
        (43.771193, 11.270884), (43.771078, 11.270850), (43.770889, 11.270719), (43.770769, 11.270666),
        (43.770675, 11.270648), (43.770433, 11.270656), (43.770291, 11.270615), (43.769649, 11.270276),
        (43.768319, 11.269513), (43.768249, 11.269758), (43.768104, 11.270143), (43.768072, 11.270513),
        (43.768082, 11.271201), (43.769906, 11.271083)
    ])

    /// A piedi dal Parcheggio Beccaria al ristorante, per piazza Beccaria e via Gioberti (OSRM a piedi, 462 m, 6 min)
    static let walk: [CLLocationCoordinate2D] = coords([
        (43.769903, 11.270726), (43.770164, 11.270856), (43.770316, 11.270884), (43.770406, 11.270830),
        (43.770536, 11.270836), (43.770609, 11.270901), (43.770713, 11.270944), (43.770628, 11.271366),
        (43.770585, 11.271443), (43.770624, 11.271468), (43.770572, 11.271688), (43.770634, 11.271710),
        (43.770503, 11.273250), (43.770524, 11.273265), (43.770489, 11.273421), (43.770422, 11.273415),
        (43.770334, 11.274149), (43.769585, 11.273885)
    ])

    /// Il ristorante (la fine dei percorsi 1 e 2) e l'ingresso del Parcheggio Beccaria
    static var restaurant: CLLocationCoordinate2D { direct[direct.count - 1] }
    static let parking = CLLocationCoordinate2D(latitude: 43.769894, longitude: 11.270761)
    /// Minuti risparmiati girando intorno (OSRM: 583 s dentro la ZTL, 324 s intorno) e minuti a piedi (370 s)
    static let minutesSaved = 4
    static let walkMinutes = 6

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

    /// Il centro della scena (lo stesso dell'inquadratura di Mapbox)
    static let center = CLLocationCoordinate2D(latitude: 43.7758, longitude: 11.2662)

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
