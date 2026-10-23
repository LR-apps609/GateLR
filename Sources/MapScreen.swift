import SwiftUI
import MapKit

/// «Mappa»: la ZTL, i varchi accesi o spenti, l'hotel, i parcheggi fuori zona.
struct MapScreen: View {
    @EnvironmentObject var store: Store
    @Binding var showZone: Bool
    @Binding var tab: Tab
    @State private var search = ""
    @State private var camera: MapCameraPosition = .automatic

    var body: some View {
        let zone = store.zone
        let on = store.answer().gatesOn
        Map(position: $camera) {
            MapPolygon(coordinates: zone.perimeter.map(\.cl))
                .foregroundStyle(Theme.red.opacity(0.12))
                .stroke(Theme.red, style: StrokeStyle(lineWidth: 3, dash: [8, 5]))
            ForEach(zone.gates) { g in
                Annotation(g.name, coordinate: g.location.cl) {
                    Circle().fill(on ? Theme.red : .white)
                        .overlay(Circle().stroke(on ? .white : Theme.green, lineWidth: 4))
                        .frame(width: 22, height: 22)
                }
            }
            UserAnnotation()
        }
        .mapControls { MapUserLocationButton() }
        .safeAreaInset(edge: .top) { topBar }
        .safeAreaInset(edge: .bottom) { sheet(zone: zone, on: on) }
    }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
                TextField("City, hotel or address", text: $search)
            }
            .padding(.horizontal, 14).frame(height: 48).card()
            .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
            HStack(spacing: 8) {
                legend("Gate off", Circle().stroke(Theme.green, lineWidth: 3))
                legend("Gate on", Circle().fill(Theme.red))
                legend("Parking", RoundedRectangle(cornerRadius: 3).fill(Theme.blue))
            }
        }
        .padding(.horizontal, 16).padding(.top, 8)
    }

    private func legend(_ text: String, _ mark: some View) -> some View {
        HStack(spacing: 6) { mark.frame(width: 10, height: 10); Text(text) }
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 12).frame(height: 32)
            .background(.white, in: Capsule())
    }

    private func sheet(zone: Zone, on: Bool) -> some View {
        let answer = store.answer()
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(zone.name).font(Theme.display(22))
                    Text("\(store.city.name) · \(zone.gates.count) gates, all \(on ? "on" : "off")")
                        .font(.system(size: 14)).foregroundStyle(Theme.muted)
                }
                Spacer()
                Pill(text: answer.verdict.title, fill: on ? Theme.amberSoft : Theme.greenSoft, ink: on ? Theme.amberInk : Theme.greenInk)
            }
            if store.hotelInside {
                HStack {
                    Image(systemName: "house")
                    Text("Your hotel is **inside** the ZTL")
                    Spacer()
                    Button("What to do") { tab = .trip }.fontWeight(.semibold)
                }
                .font(.system(size: 14))
                .padding(12).background(Theme.ground, in: RoundedRectangle(cornerRadius: 12))
            }
            HStack(spacing: 10) {
                Button { showZone = true } label: {
                    Text("Zone details").frame(maxWidth: .infinity, minHeight: 48)
                        .background(Theme.ink, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(.white)
                }
                Button {} label: {
                    Text("Park outside").frame(maxWidth: .infinity, minHeight: 48)
                        .background(Theme.blueSoft, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(Theme.blue)
                }
            }
            .font(.system(size: 15, weight: .semibold))
        }
        .padding(18)
        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, y: -2)
        .padding(.horizontal, 8).padding(.bottom, 8)
    }
}
