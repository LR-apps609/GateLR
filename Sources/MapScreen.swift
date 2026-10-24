import SwiftUI
import MapKit

/// «Mappa»: le zone colorate per tipo (rosso vietato, giallo pass, verde basse emissioni), i varchi,
/// i parcheggi fuori zona, stili satellite e 3D, e la vista a livello strada dove c'è.
struct MapScreen: View {
    @EnvironmentObject var store: Store
    @ObservedObject private var planner = RoutePlanner.shared
    @Binding var showZone: Bool
    @Binding var tab: Tab
    @State private var camera: MapCameraPosition = .automatic
    @State private var distance: Double = 8_000         // distanza della camera, per le scritte
    @State private var center: CLLocationCoordinate2D?
    @State private var style: Style = .standard
    @State private var tilted = false
    @State private var parkings: [Parking] = []
    @State private var searchingParking = false
    @State private var parkingMessage: String?
    @State private var selectedParking: Parking?
    @State private var lookAround: MKLookAroundScene?
    @State private var showLookAround = false

    enum Style: String, CaseIterable, Identifiable {
        case standard, hybrid, imagery
        var id: String { rawValue }
        var title: String {
            switch self {
            case .standard: L("Map")
            case .hybrid: L("Hybrid")
            case .imagery: L("Satellite")
            }
        }
        var symbol: String {
            switch self {
            case .standard: "map"
            case .hybrid: "map.fill"
            case .imagery: "globe.europe.africa.fill"
            }
        }
    }

    /// Le scritte grandi («Accesso vietato») si vedono da lontano e svaniscono avvicinandosi;
    /// le lettere dei settori fanno il contrario
    private var bigLabelOpacity: Double { min(1, max(0, (distance - 3_500) / 3_000)) }
    private var letterOpacity: Double { min(1, max(0, (6_500 - distance) / 2_500)) }

    private var mapStyle: MapStyle {
        let elevation: MapStyle.Elevation = tilted ? .realistic : .automatic
        switch style {
        case .standard: return .standard(elevation: elevation, pointsOfInterest: .excludingAll)
        case .hybrid: return .hybrid(elevation: elevation, pointsOfInterest: .excludingAll)
        case .imagery: return .imagery(elevation: elevation)
        }
    }

    var body: some View {
        let zone = store.zone
        let answer = store.answer()
        let zones = store.cities.flatMap(\.zones).sorted { $0.roughArea > $1.roughArea }   // le grandi sotto
        MapReader { proxy in
            Map(position: $camera) {
                ForEach(zones) { z in
                    let selected = z.id == zone.id
                    let tint = z.type.color
                    MapPolygon(coordinates: z.perimeter.map(\.cl))
                        .foregroundStyle(tint.opacity(selected ? 0.22 : (z.type == .green ? 0.06 : 0.12)))
                        .stroke(tint.opacity(selected ? 1 : 0.6), style: StrokeStyle(lineWidth: selected ? 3 : 1.5, dash: z.type == .green ? [] : [8, 5]))
                    Annotation("", coordinate: z.labelPoint, anchor: .center) {
                        ZStack {
                            kindLabel(z)
                                .opacity(z.widthMeters > distance * 0.12 ? bigLabelOpacity : 0)
                            letterBadge(z, selected: selected)
                                .opacity(letterOpacity)
                        }
                        .onTapGesture { withAnimation(.snappy) { select(z) } }
                        .accessibilityLabel("\(z.localizedName), \(z.type.title)")
                        .accessibilityAddTraits(.isButton)
                    }
                }
                // Ogni varco con lo stato della sua zona
                ForEach(zones.filter { $0.id == zone.id || distance < 6_000 }) { z in
                    let on = store.engine.isActive(z, at: Date())
                    ForEach(z.gates) { g in
                        Annotation(g.name, coordinate: g.location.cl) {
                            Image(systemName: "video.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 20, height: 20)
                                .background(on ? Theme.red : Theme.green, in: Circle())
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                        }
                        .annotationTitles(.hidden)
                    }
                }
                if let plan = planner.plan {
                    MapPolyline(coordinates: plan.path.map(\.cl))
                        .stroke(Theme.blue, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    if let p = plan.parking {
                        Annotation(p.name, coordinate: p.location.cl) {
                            Text("P").font(.system(size: 15, weight: .heavy)).foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(Theme.blue, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(.white, lineWidth: 2))
                        }
                    }
                }
                if let place = store.place {
                    Marker(place.name, systemImage: "mappin", coordinate: place.location.cl).tint(Theme.blue)
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
            .mapStyle(mapStyle)
            .mapControls { MapUserLocationButton(); MapCompass(); MapPitchToggle(); MapScaleView() }
            // Si aggiorna solo quando lo zoom cambia davvero (più dell'8%): la mappa resta fluida
            .onMapCameraChange(frequency: .continuous) { ctx in
                let d = ctx.camera.distance
                if abs(d - distance) / max(distance, 1) > 0.08 { distance = d }
            }
            .onMapCameraChange(frequency: .onEnd) { ctx in
                distance = ctx.camera.distance
                center = ctx.camera.centerCoordinate
            }
            .onTapGesture { point in
                guard let c = proxy.convert(point, from: .local) else { return }
                if let z = zones.filter({ $0.contains(c) }).min(by: { $0.roughArea < $1.roughArea }), z.id != zone.id {
                    withAnimation(.snappy) { select(z) }
                }
            }
        }
        .safeAreaInset(edge: .top) { topBar }
        .safeAreaInset(edge: .bottom) { sheet(zone: zone, answer: answer) }
        .onAppear { focus() }
        .onChange(of: store.cityId) { parkings = []; focus() }
        .onChange(of: store.place) { focus() }
        .onChange(of: planner.plan) { focus() }
        .sheet(item: $selectedParking) { p in ParkingSheet(parking: p).presentationDetents([.height(260)]) }
        .sheet(isPresented: $showLookAround) {
            LookAroundPreview(initialScene: lookAround)
                .ignoresSafeArea()
                .presentationDetents([.medium, .large])
        }
    }

    static func region(_ path: [Coordinate]) -> MKCoordinateRegion? {
        guard let first = path.first else { return nil }
        var lo = first, hi = first
        for p in path { lo.lat = min(lo.lat, p.lat); lo.lon = min(lo.lon, p.lon); hi.lat = max(hi.lat, p.lat); hi.lon = max(hi.lon, p.lon) }
        let center = CLLocationCoordinate2D(latitude: (lo.lat + hi.lat) / 2, longitude: (lo.lon + hi.lon) / 2)
        let span = MKCoordinateSpan(latitudeDelta: (hi.lat - lo.lat) * 1.3 + 0.004, longitudeDelta: (hi.lon - lo.lon) * 1.3 + 0.004)
        return MKCoordinateRegion(center: center, span: span)
    }

    private func select(_ z: Zone) {
        if let city = store.cities.first(where: { $0.zones.contains(z) }) { store.cityId = city.id }
        store.zoneId = z.id
    }

    /// La camera va sul posto scelto in Varco, se c'è, altrimenti sulla zona della città
    private func focus() {
        withAnimation {
            if let plan = planner.plan, plan.destination == store.place, let r = Self.region(plan.path) {
                camera = .region(r)
            } else if let place = store.place {
                camera = .region(MKCoordinateRegion(center: place.location.cl, latitudinalMeters: 1_600, longitudinalMeters: 1_600))
            } else {
                camera = .region(store.zone.region(padding: 1.4))
            }
        }
    }

    private func kindLabel(_ z: Zone) -> some View {
        HStack(spacing: 6) {
            Image(systemName: z.type.symbol).font(.system(size: 13, weight: .bold))
            Text(z.type.title.uppercased()).font(Theme.display(15)).tracking(0.6).lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(z.type.color, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.9), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
        .fixedSize()
    }

    private func letterBadge(_ z: Zone, selected: Bool) -> some View {
        let tint = z.type.color
        return Text(z.letter)
            .font(Theme.display(selected ? 18 : 14))
            .lineLimit(1).minimumScaleFactor(0.5)
            .foregroundStyle(selected ? .white : tint)
            .frame(width: selected ? 30 : 24, height: selected ? 30 : 24)
            .background(selected ? tint : Color.white.opacity(0.92), in: Circle())
            .overlay(Circle().stroke(tint, lineWidth: 1.5))
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ZoneKind.allCases, id: \.self) { k in
                        legendItem(k.title, RoundedRectangle(cornerRadius: 3).fill(k.color))
                    }
                    legendItem(L("Camera on"), Circle().fill(Theme.red))
                    legendItem(L("Camera off"), Circle().fill(Theme.green))
                }
            }
            Menu {
                Picker(L("Map style"), selection: $style) {
                    ForEach(Style.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                }
                Toggle(isOn: $tilted.animation()) { Label("3D buildings", systemImage: "building.2") }
                Button { Task { await openLookAround() } } label: { Label("Street view", systemImage: "binoculars") }
            } label: {
                Image(systemName: "square.3.layers.3d")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .background(.regularMaterial, in: Circle())
                    .foregroundStyle(Theme.ink)
            }
            .accessibilityLabel(L("Map style"))
        }
        .padding(.horizontal, 16).padding(.top, 8)
        .onChange(of: tilted) {
            guard let center else { return }
            withAnimation {
                camera = .camera(MapCamera(centerCoordinate: center, distance: min(distance, 2_500), heading: 0, pitch: tilted ? 60 : 0))
            }
        }
    }

    private func legendItem(_ text: String, _ mark: some View) -> some View {
        HStack(spacing: 6) { mark.frame(width: 10, height: 10); Text(text) }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 12).frame(height: 32)
            .background(.regularMaterial, in: Capsule())
    }

    /// Look Around di Apple: dove c'è (molte città italiane), la vista a livello strada del centro della mappa
    private func openLookAround() async {
        let point = center ?? store.place?.location.cl ?? store.zone.labelPoint
        lookAround = try? await MKLookAroundSceneRequest(coordinate: point).scene
        if lookAround != nil { showLookAround = true } else { parkingMessage = L("No street view here. Try another spot.") }
    }

    private func sheet(zone: Zone, answer: Answer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Menu {
                        ForEach(store.city.zones) { z in Button(z.localizedName) { withAnimation(.snappy) { store.zoneId = z.id; focus() } } }
                    } label: {
                        HStack(spacing: 4) {
                            Text(zone.localizedName).font(Theme.display(21)).lineLimit(1).minimumScaleFactor(0.7)
                            Image(systemName: "chevron.down").font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(Theme.ink)
                    }
                    HStack(spacing: 6) {
                        Circle().fill(zone.type.color).frame(width: 8, height: 8)
                        Text("\(zone.type.title) · " + String(format: L(answer.gatesOn ? "%lld gates · on now" : "%lld gates · off now"), zone.gates.count))
                            .font(.system(size: 14)).foregroundStyle(Theme.muted)
                    }
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
            // Fuori dalle zone vietate o a pagamento (dentro l'Area B verde si può parcheggiare)
            let outside = items.filter { item in
                !store.city.zones.contains { $0.contains(item.placemark.coordinate) && $0.closes(to: store.vehicle, at: Date()) }
            }
            parkings = outside.prefix(12).map { Parking(item: $0) }
            parkingMessage = parkings.isEmpty ? L("No car parks found just outside the zone.")
                : String(format: L("%lld car parks outside the ZTL. Tap a P for directions."), parkings.count)
            if !parkings.isEmpty {
                withAnimation { camera = .region(zone.region(padding: 2.4)) }
            }
        } catch {
            parkingMessage = L("Couldn't search car parks right now. Check your connection.")
        }
    }
}

struct Parking: Identifiable {
    let id = UUID()
    let item: MKMapItem
    var name: String { item.name ?? L("Car park") }
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
    func contains(_ c: CLLocationCoordinate2D) -> Bool { contains(lat: c.latitude, lon: c.longitude) }

    /// Dove mettere la lettera del settore: il centro del rettangolo che contiene il perimetro.
    /// Le zone verdi (che contengono le altre, come l'Area B) hanno la scritta più in alto, per non coprirle.
    var labelPoint: CLLocationCoordinate2D {
        let lats = perimeter.map(\.lat), lons = perimeter.map(\.lon)
        let lo = lats.min() ?? 0, hi = lats.max() ?? 0
        let lat = type == .green ? hi - (hi - lo) * 0.18 : (lo + hi) / 2
        return .init(latitude: lat, longitude: ((lons.min() ?? 0) + (lons.max() ?? 0)) / 2)
    }

    /// Larghezza approssimata in metri: le scritte delle zone piccole compaiono solo da vicino
    var widthMeters: Double {
        let lats = perimeter.map(\.lat), lons = perimeter.map(\.lon)
        let latLo: Double = lats.min() ?? 0, latHi: Double = lats.max() ?? 0
        let lonLo: Double = lons.min() ?? 0, lonHi: Double = lons.max() ?? 0
        let k: Double = cos((latLo + latHi) / 2 * Double.pi / 180)
        let tall: Double = (latHi - latLo) * 111_000
        let wide: Double = (lonHi - lonLo) * 111_000 * k
        return max(tall, wide)
    }

    func region(padding: Double) -> MKCoordinateRegion {
        let lats = perimeter.map(\.lat), lons = perimeter.map(\.lon)
        let center = CLLocationCoordinate2D(latitude: ((lats.min() ?? 0) + (lats.max() ?? 0)) / 2,
                                            longitude: ((lons.min() ?? 0) + (lons.max() ?? 0)) / 2)
        let span = MKCoordinateSpan(latitudeDelta: ((lats.max() ?? 0) - (lats.min() ?? 0)) * padding + 0.004,
                                    longitudeDelta: ((lons.max() ?? 0) - (lons.min() ?? 0)) * padding + 0.004)
        return MKCoordinateRegion(center: center, span: span)
    }
}
