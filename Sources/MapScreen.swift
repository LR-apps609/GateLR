import SwiftUI
import MapKit

/// «Mappa»: i settori della ZTL, i varchi accesi o spenti, i parcheggi fuori zona.
struct MapScreen: View {
    @EnvironmentObject var store: Store
    @Binding var showZone: Bool
    @Binding var tab: Tab
    @State private var camera: MapCameraPosition = .automatic
    @State private var parkings: [Parking] = []
    @State private var searchingParking = false
    @State private var parkingMessage: String?
    @State private var selectedParking: Parking?

    var body: some View {
        let zone = store.zone
        let answer = store.answer()
        MapReader { proxy in
            Map(position: $camera) {
                ForEach(store.city.zones) { z in
                    let selected = z.id == zone.id
                    MapPolygon(coordinates: z.perimeter.map(\.cl))
                        .foregroundStyle(Theme.red.opacity(selected ? 0.18 : 0.06))
                        .stroke(Theme.red.opacity(selected ? 1 : 0.45), style: StrokeStyle(lineWidth: selected ? 3 : 1.5, dash: [8, 5]))
                    Annotation("", coordinate: z.labelPoint, anchor: .center) {
                        Text(z.letter)
                            .font(Theme.display(selected ? 18 : 14))
                            .lineLimit(1).minimumScaleFactor(0.5)
                            .foregroundStyle(selected ? .white : Theme.red)
                            .frame(width: selected ? 30 : 24, height: selected ? 30 : 24)
                            .background(selected ? Theme.red : Color.white.opacity(0.9), in: Circle())
                            .overlay(Circle().stroke(Theme.red, lineWidth: 1.5))
                            .onTapGesture { withAnimation(.snappy) { store.zoneId = z.id } }
                            .accessibilityLabel("Sector \(z.letter)")
                            .accessibilityAddTraits(.isButton)
                    }
                }
                ForEach(store.city.zones.flatMap(\.gates)) { g in
                    Annotation(g.name, coordinate: g.location.cl) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(answer.gatesOn ? Theme.red : Theme.green, in: Circle())
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                    }
                    .annotationTitles(.hidden)
                }
                ForEach(parkings) { p in
                    Annotation(p.name, coordinate: p.coordinate) {
                        Text("P")
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(Color(hex: 0x1F4E9E), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(.white, lineWidth: 2))
                            .onTapGesture { selectedParking = p }
                    }
                }
                UserAnnotation()
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .mapControls { MapUserLocationButton(); MapCompass(); MapScaleView() }
            .onTapGesture { point in
                guard let c = proxy.convert(point, from: .local) else { return }
                if let z = store.city.zones.first(where: { $0.contains(c) && $0.id != zone.id }) {
                    withAnimation(.snappy) { store.zoneId = z.id }
                }
            }
        }
        .safeAreaInset(edge: .top) { legend }
        .safeAreaInset(edge: .bottom) { sheet(zone: zone, answer: answer) }
        .onChange(of: store.cityId) { camera = .automatic; parkings = [] }
        .sheet(item: $selectedParking) { p in ParkingSheet(parking: p).presentationDetents([.height(260)]) }
    }

    private var legend: some View {
        HStack(spacing: 8) {
            legendItem("Gate off", Circle().fill(Theme.green))
            legendItem("Gate on", Circle().fill(Theme.red))
            legendItem("Parking", RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0x1F4E9E)))
            Spacer()
        }
        .padding(.horizontal, 16).padding(.top, 8)
    }

    private func legendItem(_ text: String, _ mark: some View) -> some View {
        HStack(spacing: 6) { mark.frame(width: 10, height: 10); Text(text) }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 12).frame(height: 32)
            .background(.regularMaterial, in: Capsule())
    }

    private func sheet(zone: Zone, answer: Answer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Menu {
                        ForEach(store.city.zones) { z in Button(z.name) { withAnimation(.snappy) { store.zoneId = z.id } } }
                    } label: {
                        HStack(spacing: 4) {
                            Text(zone.name).font(Theme.display(21)).lineLimit(1).minimumScaleFactor(0.7)
                            Image(systemName: "chevron.down").font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(Theme.ink)
                    }
                    Text("\(store.city.name) · \(zone.gates.count) gates · \(answer.gatesOn ? "on" : "off") now")
                        .font(.system(size: 14)).foregroundStyle(Theme.muted)
                }
                Spacer()
                VerdictPill(verdict: answer.verdict)
            }
            if let parkingMessage {
                Text(parkingMessage).font(.system(size: 13)).foregroundStyle(Theme.muted)
            }
            HStack(spacing: 10) {
                WideButton(title: "Zone details", systemImage: "doc.text") { showZone = true }
                WideButton(title: searchingParking ? "Searching…" : "Park outside", systemImage: "parkingsign", prominent: false) {
                    Task { await findParking(zone: zone) }
                }
                .disabled(searchingParking)
            }
        }
        .padding(18)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, y: -2)
        .padding(.horizontal, 8).padding(.bottom, 8)
    }

    /// Parcheggi da Apple Maps intorno alla zona, tenendo solo quelli fuori da tutti i settori
    private func findParking(zone: Zone) async {
        searchingParking = true
        defer { searchingParking = false }
        let request = MKLocalPointsOfInterestRequest(coordinateRegion: zone.region(padding: 2.2))
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.parking])
        do {
            var items = (try? await MKLocalSearch(request: request).start().mapItems) ?? []
            if items.isEmpty {
                // Seconda strada: ricerca per parola nella stessa zona
                let text = MKLocalSearch.Request()
                text.naturalLanguageQuery = "parking"
                text.region = zone.region(padding: 2.4)
                text.resultTypes = .pointOfInterest
                items = try await MKLocalSearch(request: text).start().mapItems
            }
            let outside = items.filter { item in !store.city.zones.contains { $0.contains(item.placemark.coordinate) } }
            parkings = outside.prefix(12).map { Parking(item: $0) }
            parkingMessage = parkings.isEmpty ? "No car parks found just outside the zone." : "\(parkings.count) car parks outside the ZTL. Tap a P for directions."
            if !parkings.isEmpty {
                withAnimation { camera = .region(zone.region(padding: 2.4)) }
            }
        } catch {
            parkingMessage = "Couldn't search car parks right now. Check your connection."
        }
    }
}

struct Parking: Identifiable {
    let id = UUID()
    let item: MKMapItem
    var name: String { item.name ?? "Car park" }
    var coordinate: CLLocationCoordinate2D { item.placemark.coordinate }
}

struct ParkingSheet: View {
    var parking: Parking
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Outside the ZTL", systemImage: "checkmark.circle.fill").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.greenInk)
            Text(parking.name).font(Theme.display(26))
            if let address = parking.item.placemark.title {
                Text(address).font(.system(size: 14)).foregroundStyle(Theme.muted)
            }
            WideButton(title: "Directions in Maps", systemImage: "arrow.triangle.turn.up.right.diamond.fill") {
                parking.item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
            }
            Text("Prices and opening hours: check the car park before you go.").font(.system(size: 12)).foregroundStyle(Theme.muted)
        }
        .padding(20)
    }
}

extension Zone {
    /// Il punto è dentro il perimetro? (ray casting sulle coordinate)
    func contains(_ c: CLLocationCoordinate2D) -> Bool {
        var inside = false
        var j = perimeter.count - 1
        for i in perimeter.indices {
            let a = perimeter[i], b = perimeter[j]
            if (a.lat > c.latitude) != (b.lat > c.latitude),
               c.longitude < (b.lon - a.lon) * (c.latitude - a.lat) / (b.lat - a.lat) + a.lon {
                inside.toggle()
            }
            j = i
        }
        return inside
    }

    /// Dove mettere la lettera del settore: il centro del rettangolo che contiene il perimetro
    var labelPoint: CLLocationCoordinate2D {
        let lats = perimeter.map(\.lat), lons = perimeter.map(\.lon)
        return .init(latitude: ((lats.min() ?? 0) + (lats.max() ?? 0)) / 2, longitude: ((lons.min() ?? 0) + (lons.max() ?? 0)) / 2)
    }

    func region(padding: Double) -> MKCoordinateRegion {
        let lats = perimeter.map(\.lat), lons = perimeter.map(\.lon)
        let span = MKCoordinateSpan(latitudeDelta: ((lats.max() ?? 0) - (lats.min() ?? 0)) * padding + 0.004,
                                    longitudeDelta: ((lons.max() ?? 0) - (lons.min() ?? 0)) * padding + 0.004)
        return MKCoordinateRegion(center: labelPoint, span: span)
    }
}
