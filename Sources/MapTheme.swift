import SwiftUI
import MapKit

// Lo stile delle zone sulla mappa, in un posto solo (gli stessi valori del sito: MAP_THEME in web/template.html).
// Ogni informazione ha il suo segno:
// - il COLORE è la risposta per il tuo veicolo all'ora scelta (Access): rosso non puoi entrare, giallo entri a una
//   condizione (con «?»: non siamo sicuri, controlla il cartello), verde puoi entrare, grigio nessuna ZTL attiva;
// - il bordo TRATTEGGIATO dice «qui c'è una ZTL / zona limitata»;
// - le RIGHE A 45° dicono «la ZTL è attiva adesso», per qualunque veicolo;
// - il segno «ZTL» nel colore della risposta (grigio se la zona è spenta); le aree pedonali hanno «PEDONALE» grigio scuro;
// - le zone a forma di via diventano corridoi larghi almeno 10 punti (Resources/Map/zone-shapes.json).

enum MapTheme {
    struct Tone {
        let fillLight: UInt32, lineLight: UInt32, fillDark: UInt32, lineDark: UInt32
        var fill: Color { Color(light: fillLight, dark: fillDark) }
        var line: Color { Color(light: lineLight, dark: lineDark) }
        func fillHex(dark: Bool) -> UInt32 { dark ? fillDark : fillLight }
        func lineHex(dark: Bool) -> UInt32 { dark ? lineDark : lineLight }
    }

    static let red = Tone(fillLight: 0xD64545, lineLight: 0xA82F2F, fillDark: 0xE5544F, lineDark: 0xFF8A80)
    /// Giallo vero (non l'ambra di prima), bordo scuro per il contrasto (≥3:1 sulla mappa chiara)
    static let yellow = Tone(fillLight: 0xE8C21A, lineLight: 0x8A6D00, fillDark: 0xE8C21A, lineDark: 0xF2D24B)
    static let green = Tone(fillLight: 0x3E9F5C, lineLight: 0x2C7543, fillDark: 0x4DB56E, lineDark: 0x86E0A2)
    static let grey = Tone(fillLight: 0x7A8594, lineLight: 0x5B6573, fillDark: 0x7A8594, lineDark: 0x9AA5B5)

    static func tone(_ a: Access) -> Tone {
        switch a {
        case .closed: red
        case .conditional, .check: yellow
        case .open: green
        case .off: grey
        }
    }

    /// Il segno «ZTL»: fondo, scritta e (per il giallo) bordo, uguali in chiaro e scuro
    struct Badge { let fill: UInt32, ink: UInt32, ring: UInt32? }
    static func badge(_ a: Access) -> Badge {
        switch a {
        case .closed: Badge(fill: 0xA82F2F, ink: 0xFFFFFF, ring: nil)
        case .conditional, .check: Badge(fill: 0xE8C21A, ink: 0x2B2300, ring: 0x8A6D00)
        case .open: Badge(fill: 0x2C7543, ink: 0xFFFFFF, ring: nil)
        case .off: Badge(fill: 0x5B6573, ink: 0xFFFFFF, ring: nil)
        }
    }
    static let pedestrianBadge = Badge(fill: 0x3A3F47, ink: 0xFFFFFF, ring: nil)

    /// Il fondo della mappa (alone sotto il bordo)
    static let base = Color(light: 0xF2F3F0, dark: 0x1C1923)
    static func fillOpacity(_ a: Access, dark: Bool) -> Double {
        a == .off ? (dark ? 0.07 : 0.05) : (dark ? 0.16 : 0.12)
    }
    static func hatchOpacity(dark: Bool) -> Double { dark ? 0.28 : 0.22 }

    /// Tratteggio del bordo in punti: 5 pieni e 4 vuoti; zona spenta più rado
    static func dash(_ a: Access) -> [CGFloat] { a == .off ? [3, 5] : [5, 4] }
    /// Spessore del bordo per zoom (13 → 1, 14–16 → 1,5, 17 → 2)
    static func lineWidth(zoom: Double) -> CGFloat {
        zoom < 13.5 ? 1 : zoom < 16.5 ? 1.5 : 2
    }
    static let hatchPitch: Double = 7            // punti fra le righe a 45°
    static let corridorZoom: Double = 15         // da qui le vie sono corridoi, prima solo il segno
    static let hatchZoom: Double = 15
    static let nameZoom: Double = 15
    static let streetNameZoom: Double = 17
    static let gateZoom: Double = 16
    static let badgeOnlyPoints: Double = 16      // sotto questa misura sullo schermo: solo il segno

    /// Il testo del segno: «ZTL» (LEZ per le zone a basse emissioni), con «?» se da verificare
    static func badgeText(_ a: Access, kind: ZoneKind) -> String {
        (kind == .green ? "LEZ" : "ZTL") + (a == .check ? " ?" : "")
    }
}

// MARK: Zoom

enum MapZoom {
    /// Lo zoom «alla MapLibre» (tasselli da 512 punti) di una regione larga «widthPoints» punti
    static func zoom(span: MKCoordinateSpan, latitude: Double, widthPoints: Double) -> Double {
        let metersPerPoint = span.longitudeDelta * 111_320 * cos(latitude * .pi / 180) / max(widthPoints, 1)
        return log2(78_271.517 * cos(latitude * .pi / 180) / max(metersPerPoint, 0.01))
    }
    static func metersPerPoint(zoom: Double, latitude: Double) -> Double {
        78_271.517 * cos(latitude * .pi / 180) / pow(2, zoom)
    }
    /// Punti di mappa (MKMapPoint) per punto dello schermo: il mondo è 2^28 punti di mappa, 512·2^z punti dello schermo
    static func mapPointsPerPoint(zoom: Double) -> Double { pow(2, 19 - zoom) }
    /// Lo zoom da cui una forma lunga «meters» è grande almeno badgeOnlyPoints sullo schermo
    static func fromZoom(meters: Double, latitude: Double) -> Double {
        log2(78_271.517 * cos(latitude * .pi / 180) * MapTheme.badgeOnlyPoints / max(meters, 1))
    }
}

// MARK: Forme disegnate (corridoi delle vie)

/// Le forme di Tools/build_map_shapes.py: corridoio delle vie strette, punto del segno, asse della via, varchi sul bordo.
/// Solo il disegno: «sei dentro?» usa sempre il perimetro vero.
struct ZoneShape: Decodable, Equatable {
    var n: Int
    var p0: [Double]
    var t: Double
    var corridor: [[Double]]?
    var axis: [[Double]]?
    var label: [Double]
    var ext: Double
    var gates: [[Double]]?

    var corridorCoords: [CLLocationCoordinate2D]? { corridor?.map { CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1]) } }
    var labelCoord: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: label[0], longitude: label[1]) }
    var axisCoords: [CLLocationCoordinate2D]? { axis?.map { CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1]) } }
    var isStreet: Bool { corridor != nil }

    /// La forma è nata da questo perimetro? (città aggiornata e script non rilanciato: no, si usa il perimetro)
    func matches(_ perimeter: [Coordinate]) -> Bool {
        guard let f = perimeter.first, p0.count == 2 else { return false }
        return n == perimeter.count && abs(p0[0] - f.lat) < 1e-6 && abs(p0[1] - f.lon) < 1e-6
    }
}

enum ZoneShapes {
    private struct File: Decodable { var cities: [String: [String: ZoneShape]] }
    private static var table: [String: ZoneShape]?

    static func decode(_ data: Data) throws -> [String: ZoneShape] {
        let f = try JSONDecoder().decode(File.self, from: data)
        var out: [String: ZoneShape] = [:]
        for (_, zones) in f.cities { for (id, s) in zones { out[id] = s } }
        return out
    }

    private static var all: [String: ZoneShape] {
        if let table { return table }
        let url = Bundle.main.url(forResource: "zone-shapes", withExtension: "json", subdirectory: "Map")
        let t = url.flatMap { try? Data(contentsOf: $0) }.flatMap { try? decode($0) } ?? [:]
        table = t
        return t
    }

    /// La forma di una zona o di un'area pedonale, solo se nata dal perimetro di oggi
    static func shape(id: String, perimeter: [Coordinate], in table: [String: ZoneShape]? = nil) -> ZoneShape? {
        guard let s = (table ?? all)[id], s.matches(perimeter) else { return nil }
        return s
    }
}

// MARK: Righe a 45° (MapKit non ha i riempimenti a motivo)

enum Hatch {
    /// I tratti delle righe a 45° dentro un poligono (anelli in MKMapPoint), a «pitch» punti di mappa l'una dall'altra,
    /// solo dentro «clip» (la parte visibile). Pari-dispari: i buchi restano vuoti. Al massimo «limit» tratti.
    static func segments(rings: [[MKMapPoint]], pitch: Double, clip: MKMapRect? = nil, limit: Int = 600) -> [(MKMapPoint, MKMapPoint)] {
        guard pitch > 0 else { return [] }
        // Righe «/» come sul sito (y verso il basso): u = (x − y)/√2 lungo la riga, v = (x + y)/√2 fra le righe
        let s = 1 / 2.0.squareRoot()
        let rot = { (p: MKMapPoint) -> (u: Double, v: Double) in ((p.x - p.y) * s, (p.x + p.y) * s) }
        let back = { (u: Double, v: Double) -> MKMapPoint in MKMapPoint(x: (u + v) * s, y: (v - u) * s) }
        let edges: [((u: Double, v: Double), (u: Double, v: Double))] = rings.flatMap { r -> [((u: Double, v: Double), (u: Double, v: Double))] in
            guard r.count > 2 else { return [] }
            let q = r.map(rot)
            return q.indices.map { (q[$0], q[($0 + 1) % q.count]) }
        }
        guard !edges.isEmpty else { return [] }
        var vMin = edges.map { min($0.0.v, $0.1.v) }.min()!, vMax = edges.map { max($0.0.v, $0.1.v) }.max()!
        if let clip {
            let c = [MKMapPoint(x: clip.minX, y: clip.minY), MKMapPoint(x: clip.maxX, y: clip.minY),
                     MKMapPoint(x: clip.minX, y: clip.maxY), MKMapPoint(x: clip.maxX, y: clip.maxY)].map(rot)
            vMin = max(vMin, c.map { $0.v }.min()!)
            vMax = min(vMax, c.map { $0.v }.max()!)
        }
        guard vMax > vMin else { return [] }
        var out: [(MKMapPoint, MKMapPoint)] = []
        // righe allineate a multipli di pitch: non «scorrono» spostando la mappa
        var v = (vMin / pitch).rounded(.down) * pitch + pitch
        while v < vMax, out.count < limit {
            var us: [Double] = []
            for (a, b) in edges where (a.v <= v) != (b.v <= v) {
                us.append(a.u + (v - a.v) / (b.v - a.v) * (b.u - a.u))
            }
            us.sort()
            var i = 0
            while i + 1 < us.count, out.count < limit {
                var p = back(us[i], v), q = back(us[i + 1], v)
                if let clip, !clipSegment(&p, &q, to: clip) { i += 2; continue }
                out.append((p, q))
                i += 2
            }
            v += pitch
        }
        return out
    }

    /// Liang–Barsky: il tratto dentro il rettangolo (false se ne resta fuori)
    static func clipSegment(_ p: inout MKMapPoint, _ q: inout MKMapPoint, to r: MKMapRect) -> Bool {
        let dx = q.x - p.x, dy = q.y - p.y
        var t0 = 0.0, t1 = 1.0
        for (pp, qq) in [(-dx, p.x - r.minX), (dx, r.maxX - p.x), (-dy, p.y - r.minY), (dy, r.maxY - p.y)] {
            if pp == 0 { if qq < 0 { return false }; continue }
            let t = qq / pp
            if pp < 0 { if t > t1 { return false }; t0 = max(t0, t) } else { if t < t0 { return false }; t1 = min(t1, t) }
        }
        let a = p
        p = MKMapPoint(x: a.x + t0 * dx, y: a.y + t0 * dy)
        q = MKMapPoint(x: a.x + t1 * dx, y: a.y + t1 * dy)
        return true
    }
}

// MARK: Segni senza sovrapposizioni (MapKit non ha le collisioni di MapLibre)

enum BadgeLayout {
    struct Item { let id: String; let point: MKMapPoint; let size: CGSize; let priority: Int; let force: Bool }

    /// Gli id dei segni da mostrare: in ordine di priorità (0 prima), ognuno solo se non copre uno già messo.
    /// Le misure sono in punti dello schermo, convertite con «mapPointsPerPoint». «force»: sempre (la zona scelta).
    static func place(_ items: [Item], mapPointsPerPoint k: Double) -> Set<String> {
        var taken: [MKMapRect] = []
        var shown = Set<String>()
        for it in items.sorted(by: { ($0.force ? -1 : $0.priority, $0.id) < ($1.force ? -1 : $1.priority, $1.id) }) {
            let w = Double(it.size.width) * k, h = Double(it.size.height) * k
            let r = MKMapRect(x: it.point.x - w / 2, y: it.point.y - h / 2, width: w, height: h)
            if !it.force && taken.contains(where: { $0.intersects(r) }) { continue }
            taken.append(r)
            shown.insert(it.id)
        }
        return shown
    }

    /// Priorità come sul sito: attive prima, poi condizioni, aperte, pedonali, LEZ, spente
    static func priority(_ a: Access, kind: ZoneKind?, pedestrian: Bool) -> Int {
        if pedestrian { return 3 }
        if kind == .green { return 4 }
        switch a {
        case .closed: return 0
        case .conditional, .check: return 1
        case .open: return 2
        case .off: return 5
        }
    }
}

// MARK: Viste

/// Il segno «ZTL» / «PEDONALE»: pillola nel colore della risposta, scritta bianca (scura sul giallo)
struct ZoneBadge: View {
    var text: String
    var badge: MapTheme.Badge
    var selected = false
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        Text(verbatim: text)
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(0.42)
            .foregroundStyle(Color(hex: badge.ink))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Color(hex: badge.fill), in: Capsule())
            .overlay {
                if let ring = badge.ring {
                    Capsule().stroke(Color(hex: ring), lineWidth: 1)
                } else if scheme == .dark {
                    Capsule().stroke(.white.opacity(0.25), lineWidth: 1.2)
                }
            }
            .overlay { if selected { Capsule().stroke(.white, lineWidth: 1.5).padding(-2) } }
            .fixedSize()
    }
}

/// Il varco: cerchio nel colore della zona, anello bianco, telecamera
struct GateMark: View {
    var badge: MapTheme.Badge
    var body: some View {
        Image(systemName: "video.fill")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(Color(hex: badge.ink))
            .frame(width: 20, height: 20)
            .background(Color(hex: badge.fill), in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: 1.8))
    }
}

extension MapZoom {
    /// Lo zoom dalla distanza della camera di MapKit (MapDetail.metersPerPoint: circa distanza / 1300 metri per punto)
    static func zoom(distance: Double, latitude: Double) -> Double {
        log2(78_271.517 * cos(latitude * .pi / 180) / max(MapDetail.metersPerPoint(distance), 0.01))
    }
}

/// Una zona disegnata su MapKit: alone nel colore del fondo, riempimento, bordo tratteggiato; la scelta a bordo pieno
/// con l'alone largo; le altre al 40% quando c'è una scelta
struct ZoneOverlay: MapContent {
    var coords: [CLLocationCoordinate2D]
    var access: Access
    var picked: Bool
    var dim: Bool
    var big: Bool
    var zoom: Double
    var dark: Bool

    var body: some MapContent {
        let tone = MapTheme.tone(access)
        let k = dim ? 0.4 : 1
        let w = MapTheme.lineWidth(zoom: zoom)
        let fill = MapTheme.fillOpacity(access, dark: dark) * (big ? 0.4 : 1) * (picked ? 1.6 : k)
        if picked {
            MapPolygon(coordinates: coords)
                .foregroundStyle(tone.fill.opacity(fill))
                .stroke(MapTheme.base.opacity(0.55), lineWidth: 6)
            MapPolygon(coordinates: coords)
                .foregroundStyle(.clear)
                .stroke(tone.line, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        } else {
            MapPolygon(coordinates: coords)
                .foregroundStyle(tone.fill.opacity(fill))
                .stroke(MapTheme.base.opacity(0.4 * k), lineWidth: w + 3)
            MapPolygon(coordinates: coords)
                .foregroundStyle(.clear)
                .stroke(tone.line.opacity((access == .off ? 0.7 : 0.85) * k),
                        style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round, dash: MapTheme.dash(access)))
        }
    }
}

/// Le righe a 45° di una zona attiva (MapPolyline ritagliate da noi): calcolate per gradino di zoom (15, 16, 17…) e
/// parte visibile, e tenute in memoria finché non cambiano
@MainActor
enum HatchCache {
    struct Line: Identifiable { let id: Int; let a: CLLocationCoordinate2D; let b: CLLocationCoordinate2D }
    private static var cache: [String: [Line]] = [:]

    static func lines(id: String, coords: [CLLocationCoordinate2D], zoom: Double, box: BBox?, limit: Int = 200) -> [Line] {
        let step = min(18, floor(zoom))
        let key = "\(id)|\(step)|\(limit)|\(coords.count)|\(box.map { "\($0.minLat),\($0.minLon),\($0.maxLat),\($0.maxLon)" } ?? "")"
        if let hit = cache[key] { return hit }
        if cache.count > 400 { cache = [:] }
        let clip = box.map { b -> MKMapRect in
            let p = MKMapPoint(CLLocationCoordinate2D(latitude: b.maxLat, longitude: b.minLon))
            let q = MKMapPoint(CLLocationCoordinate2D(latitude: b.minLat, longitude: b.maxLon))
            return MKMapRect(x: p.x, y: p.y, width: q.x - p.x, height: q.y - p.y)
        }
        let segs = Hatch.segments(rings: [coords.map { MKMapPoint($0) }], pitch: MapTheme.hatchPitch * MapZoom.mapPointsPerPoint(zoom: step),
                                  clip: clip, limit: limit)
        let out = segs.enumerated().map { Line(id: $0.offset, a: $0.element.0.coordinate, b: $0.element.1.coordinate) }
        cache[key] = out
        return out
    }
}

/// Il segno della zona con, da z15, il nome sotto
struct ZoneMark: View {
    var text: String
    var badge: MapTheme.Badge
    var name: String?
    var selected: Bool
    var body: some View {
        VStack(spacing: 2) {
            ZoneBadge(text: text, badge: badge, selected: selected)
            if let name {
                Text(verbatim: name)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .shadow(color: MapTheme.base, radius: 1.5)
                    .shadow(color: MapTheme.base, radius: 1.5)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }
}

/// «ZTL · Via …» lungo la via (da z17), girato come l'asse della strada e sempre leggibile dritto
struct StreetLabel: View {
    var text: String
    var color: Color
    var angle: Double
    var body: some View {
        Text(verbatim: text)
            .font(.system(size: 11.5, weight: .bold))
            .foregroundStyle(color)
            .shadow(color: MapTheme.base, radius: 1.5)
            .shadow(color: MapTheme.base, radius: 1.5)
            .fixedSize()
            .rotationEffect(.degrees(angle))
    }

    static func middle(_ axis: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: (axis[0].latitude + axis[1].latitude) / 2, longitude: (axis[0].longitude + axis[1].longitude) / 2)
    }

    /// L'angolo sullo schermo (gradi, in senso orario) dell'asse, tolta la direzione della camera, tra −90° e 90°
    static func angle(_ axis: [CLLocationCoordinate2D], heading: Double) -> Double {
        let k = cos(axis[0].latitude * .pi / 180)
        let dx = (axis[1].longitude - axis[0].longitude) * k, dy = -(axis[1].latitude - axis[0].latitude)
        var a = atan2(dy, dx) * 180 / .pi - heading
        while a > 90 { a -= 180 }
        while a < -90 { a += 180 }
        return a
    }
}
