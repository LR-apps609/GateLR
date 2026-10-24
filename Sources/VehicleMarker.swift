import SwiftUI

/// Il segno dell'auto sulla mappa di guida: freccia classica oppure un modellino visto dall'alto.
/// Si sceglie in Account (tipo e colore); gira con la direzione di marcia.
enum VehicleMarker: String, CaseIterable, Identifiable {
    case arrow, sedan, suv, city, motorbike
    var id: String { rawValue }
    var title: String {
        switch self {
        case .arrow: L("Arrow")
        case .sedan: L("Sedan")
        case .suv: L("SUV")
        case .city: L("City car")
        case .motorbike: L("Motorbike")
        }
    }
}

enum VehicleColor: String, CaseIterable, Identifiable {
    case blue, red, white, black, silver, green, yellow
    var id: String { rawValue }
    var color: Color {
        switch self {
        case .blue: Color(hex: 0x2F6FE4)
        case .red: Color(hex: 0xD3262E)
        case .white: Color(hex: 0xF4F5F7)
        case .black: Color(hex: 0x23272E)
        case .silver: Color(hex: 0xA9B0B9)
        case .green: Color(hex: 0x2B8A4E)
        case .yellow: Color(hex: 0xF2C230)
        }
    }
}

/// Il disegno, già girato: «heading» è la direzione di marcia rispetto alla mappa
struct VehicleMarkerView: View {
    var marker: VehicleMarker
    var tint: VehicleColor
    var heading: Double

    var body: some View {
        Group {
            switch marker {
            case .arrow:
                Image(systemName: "location.north.fill")
                    .font(.system(size: 22, weight: .bold)).foregroundStyle(tint.color == VehicleColor.white.color ? Color(hex: 0x2F6FE4) : tint.color)
                    .frame(width: 44, height: 44)
                    .background(.white, in: Circle())
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            case .sedan: CarTopView(body: tint.color, length: 50, width: 24, cabin: 0.42)
            case .suv: CarTopView(body: tint.color, length: 52, width: 27, cabin: 0.52)
            case .city: CarTopView(body: tint.color, length: 40, width: 23, cabin: 0.5)
            case .motorbike: MotorbikeTopView(body: tint.color)
            }
        }
        .rotationEffect(.degrees(heading))
        .accessibilityHidden(true)
    }
}

/// Un'auto vista dall'alto: carrozzeria, parabrezza, lunotto, tetto, specchietti e fari
private struct CarTopView: View {
    var body_: Color
    var length: CGFloat
    var width: CGFloat
    var cabin: CGFloat          // quanta parte della lunghezza è abitacolo

    init(body: Color, length: CGFloat, width: CGFloat, cabin: CGFloat) {
        self.body_ = body; self.length = length; self.width = width; self.cabin = cabin
    }

    var body: some View {
        let glass = Color(hex: 0x1B2A3A).opacity(0.85)
        ZStack {
            // ombra a terra
            RoundedRectangle(cornerRadius: width * 0.42).fill(.black.opacity(0.28))
                .frame(width: width + 4, height: length + 4).blur(radius: 3).offset(y: 2)
            // specchietti
            HStack(spacing: width) {
                Capsule().fill(body_).frame(width: 5, height: 4)
                Capsule().fill(body_).frame(width: 5, height: 4)
            }
            .offset(y: -length * 0.12)
            // carrozzeria con un po' di luce
            RoundedRectangle(cornerRadius: width * 0.42)
                .fill(LinearGradient(colors: [body_.opacity(0.95), body_], startPoint: .leading, endPoint: .trailing))
                .overlay(RoundedRectangle(cornerRadius: width * 0.42).stroke(.black.opacity(0.35), lineWidth: 1))
                .frame(width: width, height: length)
            // parabrezza (davanti = in alto)
            RoundedRectangle(cornerRadius: 4).fill(glass)
                .frame(width: width * 0.78, height: length * 0.16)
                .offset(y: -length * (cabin / 2) + length * 0.02)
            // tetto
            RoundedRectangle(cornerRadius: 4).fill(body_.opacity(0.9))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(.white.opacity(0.25), lineWidth: 1))
                .frame(width: width * 0.7, height: length * cabin * 0.62)
                .offset(y: length * 0.03)
            // lunotto
            RoundedRectangle(cornerRadius: 3).fill(glass)
                .frame(width: width * 0.7, height: length * 0.1)
                .offset(y: length * (cabin / 2) + length * 0.04)
            // fari
            HStack(spacing: width * 0.42) {
                Capsule().fill(Color(hex: 0xFFF6C8)).frame(width: 5, height: 3)
                Capsule().fill(Color(hex: 0xFFF6C8)).frame(width: 5, height: 3)
            }
            .offset(y: -length / 2 + 3)
            // luci posteriori
            HStack(spacing: width * 0.46) {
                Capsule().fill(Color(hex: 0xE0262E)).frame(width: 5, height: 2.5)
                Capsule().fill(Color(hex: 0xE0262E)).frame(width: 5, height: 2.5)
            }
            .offset(y: length / 2 - 2.5)
        }
        .frame(width: max(width, length) + 8, height: max(width, length) + 8)
    }
}

/// Una moto vista dall'alto: ruote, serbatoio, sella, manubrio, casco del pilota
private struct MotorbikeTopView: View {
    var body_: Color
    init(body: Color) { body_ = body }

    var body: some View {
        ZStack {
            Capsule().fill(.black.opacity(0.28)).frame(width: 14, height: 46).blur(radius: 3).offset(y: 2)
            Capsule().fill(Color(hex: 0x2A2D33)).frame(width: 6, height: 44)                       // ruote e telaio
            Capsule().fill(Color(hex: 0x3A3E45)).frame(width: 28, height: 4).offset(y: -12)          // manubrio
            Capsule().fill(body_).overlay(Capsule().stroke(.black.opacity(0.35), lineWidth: 1))
                .frame(width: 13, height: 18).offset(y: -2)                                           // serbatoio
            Capsule().fill(Color(hex: 0x1E2126)).frame(width: 11, height: 14).offset(y: 12)          // sella
            Circle().fill(body_.opacity(0.9)).overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 1.5))
                .frame(width: 13, height: 13).offset(y: 5)                                            // casco
            Capsule().fill(Color(hex: 0xFFF6C8)).frame(width: 5, height: 3).offset(y: -22)            // faro
        }
        .frame(width: 54, height: 54)
    }
}
