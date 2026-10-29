import Foundation
import SwiftUI

/// L'inquadratura della striscia di mappa in cima a «Varco» (Mapbox e mappa di Apple): il posto o la zona, e anche
/// la tua posizione se sei a meno di 5 km, così si vede subito se sei dentro o fuori. Più lontano solo la zona.
struct StripFrame: Equatable {
    /// Il centro della ripresa
    var center: Coordinate
    /// I metri da far stare nella striscia (lato più lungo, con il margine); 0 = la ripresa vicina di sempre
    var spanMeters: Double
    /// Vero se nella ripresa c'è anche la tua posizione
    var includesUser: Bool

    /// Oltre questa distanza la tua posizione non entra nella ripresa (la zona diventerebbe troppo piccola)
    static let maxUserDistance = 5_000.0
    /// Il margine intorno ai due punti: nessuno dei due finisce sul bordo
    static let margin = 1.5
    /// Mai più vicini di così, anche se sei a pochi metri
    static let minSpan = 700.0
    /// Lo zoom della ripresa vicina, quando c'è solo il posto
    static let closeZoom = 15.7

    static func make(target: Coordinate, user: Coordinate?) -> StripFrame {
        guard let user else { return StripFrame(center: target, spanMeters: 0, includesUser: false) }
        let d = meters(target, user)
        guard d <= maxUserDistance else { return StripFrame(center: target, spanMeters: 0, includesUser: false) }
        let mid = Coordinate(lat: (target.lat + user.lat) / 2, lon: (target.lon + user.lon) / 2)
        return StripFrame(center: mid, spanMeters: max(minSpan, d * margin), includesUser: true)
    }

    /// Lo zoom di Mapbox perché «spanMeters» stia in «points» punti dello schermo (il lato corto della striscia);
    /// mai più vicino della ripresa vicina
    func zoom(points: Double) -> Double {
        guard spanMeters > 0, points > 0 else { return Self.closeZoom }
        // Metri per punto allo zoom 0 (tasselli da 512 punti): 40 075 016 m / 512 · cos(lat)
        let perPoint0 = 40_075_016.686 / 512 * cos(center.lat * .pi / 180)
        return min(Self.closeZoom, log2(perPoint0 * points / spanMeters))
    }

    /// Gradi di latitudine e longitudine per la mappa di Apple (una regione quadrata di «spanMeters»)
    var degrees: (lat: Double, lon: Double) {
        let lat = spanMeters / 111_000
        return (lat, lat / max(0.01, cos(center.lat * .pi / 180)))
    }

    /// Basta ridisegnare la camera solo se la ripresa cambia davvero (più di 150 m o la tua posizione entra o esce)
    func differs(from other: StripFrame) -> Bool {
        includesUser != other.includesUser || Self.meters(center, other.center) > 150 || abs(spanMeters - other.spanMeters) > 300
    }

    static func meters(_ a: Coordinate, _ b: Coordinate) -> Double {
        let k = cos((a.lat + b.lat) / 2 * .pi / 180)
        return hypot((a.lat - b.lat) * 111_000, (a.lon - b.lon) * 111_000 * k)
    }
}

/// Il segno del posto sulla striscia: mai un pallino che sembri «sei qui» (quello è il pallino blu di iOS)
enum StripMarkerKind: Equatable {
    /// Senza un posto cercato: il cartello della ZTL (cerchio rosso su bianco, su un palo) con il nome corto della zona
    case zone(String)
    /// Un posto cercato: uno spillo di destinazione del colore della risposta, con il nome
    case destination(String)

    var label: String {
        switch self {
        case .zone(let n), .destination(let n): n
        }
    }

    var accessibilityText: String {
        switch self {
        case .zone(let n): String(format: L("ZTL zone: %@"), n)
        case .destination(let n): String(format: L("Destination: %@"), n)
        }
    }
}

/// Il disegno del segno: la base (la punta dello spillo o il piede del palo) sta sul punto esatto
struct StripMarker: View {
    var kind: StripMarkerKind
    var tint: Color
    static let size = CGSize(width: 160, height: 74)

    var body: some View {
        VStack(spacing: 3) {
            Text(verbatim: kind.label)
                .font(.app(size: 11, weight: .bold)).foregroundStyle(.white)
                .lineLimit(1).truncationMode(.tail)
                .padding(.horizontal, 8).frame(height: 20)
                .background(Color.black.opacity(0.72), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.35), lineWidth: 0.5))
                .frame(maxWidth: Self.size.width)
            switch kind {
            case .zone: sign
            case .destination: pin
            }
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(kind.accessibilityText)
    }

    /// Il cartello della ZTL: disco bianco con l'anello rosso e la scritta, su un palo grigio
    private var sign: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(.white)
                Circle().strokeBorder(Color(hex: 0xD32F2F), lineWidth: 4)
                Text(verbatim: "ZTL").font(.system(size: 7, weight: .heavy)).foregroundStyle(.black)
            }
            .frame(width: 26, height: 26)
            .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
            Rectangle().fill(Color(hex: 0xB8BEC9)).frame(width: 2.5, height: 12)
        }
    }

    /// Lo spillo di destinazione: la goccia con la punta in basso, sul posto
    private var pin: some View {
        ZStack(alignment: .top) {
            Image(systemName: "mappin")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(tint)
                .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
            Circle().fill(.white).frame(width: 7, height: 7).padding(.top, 5)
        }
        .frame(height: 38, alignment: .bottom)
    }
}
