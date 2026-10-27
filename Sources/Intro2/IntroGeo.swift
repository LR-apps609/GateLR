import CoreLocation
import MapKit
import Foundation
import SwiftUI

/// La scena della prima pagina: la ZTL del centro storico di Firenze (Settori A e B, perimetri veri di
/// Resources/Cities/firenze.json; il Settore A non ha varchi propri, si entra da quelli del B), il varco di via Vittorio
/// Alfieri, un ristorante DENTRO la ZTL (via Faenza, Settore A, vicino al Mercato Centrale; generico, non un locale vero)
/// e il parcheggio che per quel ristorante sceglierebbe l'app stessa («Parcheggia fuori e cammina», ParkOutside.rank):
/// il più vicino fuori da ogni ZTL attiva alle 11:30 di un giorno feriale, Largo Vincenzo Giudice alla Fortezza
/// (OSM way/1452850178, in Resources/Parking/firenze.json; il secondo, Fortezza Fiera, è a 13 minuti).
/// I percorsi seguono strade vere: calcolati con OSRM sui dati OpenStreetMap da Tools/intro_routes.py
/// (ramo «intro-routes») e dal workflow «Scarica pagine», semplificati a ~1 m e copiati qui.
struct IntroScene {
    /// I perimetri da disegnare: prima il Settore B (l'anello esterno), poi il Settore A
    var zones: [[CLLocationCoordinate2D]]
    var gateName: String
    var gate: CLLocationCoordinate2D
    var zoneName: String
    var cityName: String

    /// 1. «La strada più diretta»: dal viale Gramsci dritto al ristorante attraverso il centro: dentro dal varco di via
    /// Vittorio Alfieri, piazza d'Azeglio, via della Colonna, piazza San Marco, via XXVII Aprile, Mercato Centrale
    /// (OSRM, 2,6 km, 1,9 km nella ZTL): la più corta, e la multa
    static let direct: [CLLocationCoordinate2D] = coords([
        (43.776198, 11.269270), (43.776627, 11.268880), (43.776734, 11.268862), (43.777132, 11.268944),
        (43.777283, 11.268946), (43.777502, 11.268859), (43.777714, 11.268708), (43.777943, 11.268464),
        (43.778083, 11.268187), (43.778113, 11.268087), (43.778101, 11.267937), (43.778023, 11.267705),
        (43.777921, 11.267606), (43.777678, 11.267525), (43.777481, 11.267563), (43.777238, 11.267753),
        (43.777022, 11.267983), (43.776837, 11.268224), (43.776591, 11.268610), (43.773999, 11.266329),
        (43.774834, 11.264569), (43.776585, 11.261103), (43.776980, 11.260528), (43.777615, 11.259161),
        (43.777659, 11.259115), (43.777700, 11.259113), (43.777887, 11.259250), (43.778216, 11.258478),
        (43.778024, 11.258330), (43.779252, 11.255474), (43.777842, 11.254332), (43.777408, 11.253609),
        (43.776737, 11.254865), (43.776536, 11.254388), (43.776482, 11.254082), (43.776036, 11.253115),
        (43.775683, 11.252257), (43.776392, 11.251860)
    ])

    /// 2. «Con GateLR»: stessa partenza, intorno lungo i viali Gramsci, Matteotti, Lavagnini e Strozzi fino al parcheggio
    /// (OSRM, 3,9 km, nessun metro nei Settori A, B, O, F, G)
    static let toParking: [CLLocationCoordinate2D] = coords([
        (43.776198, 11.269270), (43.776627, 11.268880), (43.776734, 11.268862), (43.777132, 11.268944),
        (43.777283, 11.268946), (43.777502, 11.268859), (43.777714, 11.268708), (43.777902, 11.268518),
        (43.778041, 11.268283), (43.778143, 11.267963), (43.778228, 11.267510), (43.778276, 11.267401),
        (43.778382, 11.267240), (43.782899, 11.263034), (43.783181, 11.262737), (43.783276, 11.262700),
        (43.783366, 11.262715), (43.783664, 11.262944), (43.783816, 11.263029), (43.783896, 11.263029),
        (43.783997, 11.262974), (43.784098, 11.262842), (43.784517, 11.261784), (43.784499, 11.261410),
        (43.784416, 11.261178), (43.784330, 11.261073), (43.783833, 11.260624), (43.783744, 11.260489),
        (43.783688, 11.260322), (43.781965, 11.252871), (43.781999, 11.252687), (43.782052, 11.252627),
        (43.783031, 11.252206), (43.783161, 11.252123), (43.783421, 11.251723), (43.783507, 11.251487),
        (43.783540, 11.251235), (43.783556, 11.249955), (43.783533, 11.249508), (43.783551, 11.247933),
        (43.783579, 11.247356), (43.783553, 11.247066), (43.783486, 11.246758), (43.783307, 11.246155),
        (43.783058, 11.245464), (43.782791, 11.244380), (43.782679, 11.244153), (43.782293, 11.243541),
        (43.782094, 11.243299), (43.781616, 11.242815), (43.781331, 11.242456), (43.781130, 11.242250),
        (43.779644, 11.241299), (43.779084, 11.241029), (43.778933, 11.241017), (43.778829, 11.241066),
        (43.778622, 11.241319), (43.778608, 11.241402), (43.778942, 11.242485), (43.778981, 11.242953),
        (43.779073, 11.243407), (43.779349, 11.244264), (43.779664, 11.245375), (43.779693, 11.247112),
        (43.779650, 11.247563), (43.779738, 11.247874)
    ])

    /// 3. «Poi due passi a piedi»: dal parcheggio al ristorante per viale Strozzi e via Faenza (OSRM a piedi, 670 m, 9 min)
    static let walk: [CLLocationCoordinate2D] = coords([
        (43.780020, 11.247820), (43.779738, 11.247874), (43.779779, 11.248021), (43.779838, 11.248131),
        (43.779796, 11.248154), (43.779829, 11.248290), (43.779677, 11.248354), (43.779713, 11.248504),
        (43.779892, 11.248562), (43.779921, 11.248589), (43.780170, 11.249403), (43.780101, 11.249718),
        (43.779349, 11.250124), (43.778356, 11.250740), (43.777884, 11.250952), (43.777259, 11.251273),
        (43.776864, 11.251588), (43.776545, 11.251794), (43.776392, 11.251860)
    ])

    /// Il ristorante (la fine della strada dritta e del tratto a piedi). Il segno del parcheggio sta 30 m più a nord
    /// dell'ingresso (che è a 7 m dal bordo della ZTL), dalla parte di fuori, così sulla mappa inclinata si legge fuori
    static var restaurant: CLLocationCoordinate2D { walk[walk.count - 1] }
    static let parking = CLLocationCoordinate2D(latitude: 43.78002, longitude: 11.24782)
    /// Il giorno della scena: martedì 17 novembre 2026, non festivo e fuori dalle notti d'estate (dal 2 aprile al 3 ottobre
    /// il Settore A è chiuso anche giovedì, venerdì e sabato dalle 23 alle 3). Alle 11:30 il Settore A è attivo
    /// (feriali 7:30–20), alle 21:00 no: lo controlla IntroMomentTests con il RuleEngine e firenze.json
    static let dayMoment = RuleEngine.rome.date(from: DateComponents(year: 2026, month: 11, day: 17, hour: 11, minute: 30))!
    static let nightMoment = RuleEngine.rome.date(from: DateComponents(year: 2026, month: 11, day: 17, hour: 21, minute: 0))!

    /// «martedì 11:30» in ora italiana, nella lingua del telefono
    static func clock(_ date: Date) -> String {
        RuleEngine.format(date, .dateTime.weekday(.wide)) + " " + time(date)
    }

    /// «11:30»
    static func time(_ date: Date) -> String {
        RuleEngine.format(date, Date.FormatStyle(date: .omitted, time: .shortened))
    }

    /// Minuti a piedi dal parcheggio al ristorante (OSRM a piedi: 513 s dall'ingresso, più i 30 m del segno)
    static let walkMinutes = 9

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

    /// Il varco di via Vittorio Alfieri (ptm-11 in firenze.json), se la città non fosse ancora letta
    static let gatePoint = CLLocationCoordinate2D(latitude: 43.776338, longitude: 11.268385)

    /// Il centro della scena (lo stesso dell'inquadratura di Mapbox)
    static let center = CLLocationCoordinate2D(latitude: 43.7784, longitude: 11.2590)

    @MainActor static func load(_ store: Store) -> IntroScene {
        let city = store.cities.first { $0.id == "firenze" }
        let zoneA = city?.zones.first { $0.id == "firenze-a" }
        let zoneB = city?.zones.first { $0.id == "firenze-b" }
        let gate = city?.zones.flatMap(\.gates).first { $0.id == "ptm-11" }
        return IntroScene(
            zones: [zoneB, zoneA].compactMap { $0?.perimeter.map(\.cl) },
            gateName: gate?.name ?? "Via Vittorio Alfieri",
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

/// Un'impronta del tratto a piedi: dove, verso dove guarda (gradi da nord) e se è il piede sinistro
struct IntroFootprint {
    var coordinate: CLLocationCoordinate2D
    var bearing: Double
    var left: Bool
}

extension IntroPath {
    /// Le impronte lungo il percorso: una ogni «every» metri, alternate a sinistra e a destra di «side» metri
    func footprints(every: Double, side: Double) -> [IntroFootprint] {
        guard length > every else { return [] }
        var out: [IntroFootprint] = []
        var d = every / 2
        var left = true
        let delta = 6 / length
        while d < length {
            let f = d / length
            let c = point(f)
            let bearing = point(max(f - delta, 0)).notteBearing(to: point(min(f + delta, 1)))
            let a = (bearing + (left ? -90 : 90)) * .pi / 180
            let k = cos(c.latitude * .pi / 180)
            let shifted = CLLocationCoordinate2D(latitude: c.latitude + cos(a) * side / 111_320,
                                                 longitude: c.longitude + sin(a) * side / (111_320 * k))
            out.append(IntroFootprint(coordinate: shifted, bearing: bearing, left: left))
            left.toggle()
            d += every
        }
        return out
    }
}
