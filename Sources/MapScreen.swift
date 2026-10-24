import SwiftUI
import MapKit

/// «Mappa»: le zone colorate per tipo (rosso vietato, giallo pass, verde basse emissioni), i varchi,
/// i parcheggi fuori zona, stili satellite e 3D, e la vista a livello strada dove c'è.
struct MapScreen: View {
    @EnvironmentObject var store: Store
    @ObservedObject private var planner = RoutePlanner.shared
    @StateObject private var search = AddressSearch()
    @FocusState private var typing: Bool
    @State private var resolving = false
    @State private var showLegend = false
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
                    // Il verde (zone a basse emissioni) pieno e ben visibile; rosso e giallo tratteggiati
                    MapPolygon(coordinates: z.perimeter.map(\.cl))
                        .foregroundStyle(tint.opacity(z.type == .green ? (selected ? 0.30 : 0.20) : (selected ? 0.24 : 0.13)))
                        .stroke(tint.opacity(selected || z.type == .green ? 1 : 0.7),
                                style: StrokeStyle(lineWidth: z.type == .green ? 4 : (selected ? 3 : 2), dash: z.type == .green ? [] : [8, 5]))
                    // Un solo segno piccolo per zona: lettera e colore (la legenda spiega i colori)
                    if z.widthMeters > distance * 0.06 {
                        Annotation("", coordinate: z.labelPoint, anchor: .center) {
                            letterBadge(z, selected: selected)
                                .onTapGesture { withAnimation(.snappy) { select(z) } }
                                .accessibilityLabel("\(z.localizedName), \(z.type.title)")
                                .accessibilityAddTraits(.isButton)
                        }
                    }
                }
                // Da vicino: aree pedonali e telecamere delle corsie bus
                if distance < 4_000 {
                    ForEach(store.cities.filter { isNear($0.center.cl) }) { city in
                        ForEach(city.pedestrian ?? []) { a in
                            MapPolygon(coordinates: a.perimeter.map(\.cl))
                                .foregroundStyle(Theme.red.opacity(0.22))
                                .stroke(Theme.red.opacity(0.7), lineWidth: 1)
                        }
                        ForEach(city.cameras ?? []) { cam in
                            Annotation(cam.name, coordinate: cam.location.cl) {
                                Image(systemName: cam.kind == .bus ? "bus.fill" : "figure.walk")
                                    .font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                                    .frame(width: 20, height: 20)
                                    .background(cam.kind == .bus ? Theme.blueFill : Theme.red, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).stroke(.white, lineWidth: 1.5))
                                    .accessibilityHidden(true)
                            }
                            .annotationTitles(.hidden)
                        }
                    }
                }
                // Ogni varco con lo stato della sua zona
                ForEach(zones.filter { $0.id == zone.id || (distance < 6_000 && isNear($0)) }) { z in
                    let on = store.engine.isActive(z, at: Date())
                    ForEach(z.gates) { g in
                        Annotation(g.name, coordinate: g.location.cl) {
                            Image(systemName: "video.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 20, height: 20)
                                .background(on ? Theme.red : Theme.green, in: Circle())
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                                .accessibilityHidden(true)     // centinaia di varchi: VoiceOver (e i test) restano veloci
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
                                .background(Theme.blueFill, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(.white, lineWidth: 2))
                        }
                    }
                }
                if let place = store.place {
                    Marker(place.name, systemImage: "mappin", coordinate: place.location.cl).tint(placeTint(place))
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
        .safeAreaInset(edge: .bottom) {
            if !typing {
                if let place = store.place { placeSheet(place) } else { sheet(zone: zone, answer: answer) }
            }
        }
        .onAppear { search.focus(on: store.city) }
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

    /// Solo le zone vicine al centro della mappa mostrano i varchi (non serve disegnare quelli di altre città)
    private func isNear(_ z: Zone) -> Bool { isNear(z.labelPoint) }

    private func isNear(_ p: CLLocationCoordinate2D) -> Bool {
        let c = center ?? store.city.center.cl
        return abs(p.latitude - c.latitude) < 0.08 && abs(p.longitude - c.longitude) < 0.11
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
                camera = .camera(MapCamera(centerCoordinate: place.location.cl, distance: 1_500, heading: 0, pitch: 0))
            } else {
                camera = .region(store.zone.region(padding: 1.4))
            }
        }
    }

    private func letterBadge(_ z: Zone, selected: Bool) -> some View {
        let tint = z.type.color
        let size: CGFloat = selected ? 32 : 26
        return Text(z.letter.count > 2 ? String(z.letter.prefix(1)) : z.letter)
            .font(Theme.display(selected ? 17 : 14))
            .lineLimit(1).minimumScaleFactor(0.5)
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint, in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: selected ? 3 : 2))
            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
    }

    private var topBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
                    TextField(String(format: L("Address or hotel in %@"), store.city.localizedName), text: $search.query)
                        .focused($typing).autocorrectionDisabled().submitLabel(.search)
                        .accessibilityIdentifier("map.search")
                    if resolving { ProgressView() }
                    if !search.query.isEmpty || store.place != nil {
                        Button { search.clear(); store.place = nil; typing = false; focus() } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.muted)
                        }
                        .accessibilityLabel(L("Clear"))
                    }
                }
                .font(.system(size: 16))
                .padding(.horizontal, 12).frame(height: 44)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                Button { withAnimation(.snappy) { showLegend.toggle() } } label: {
                    Image(systemName: "info").font(.system(size: 16, weight: .bold))
                        .frame(width: 44, height: 44).background(.regularMaterial, in: Circle()).foregroundStyle(Theme.ink)
                }
                .accessibilityLabel(L("Legend"))
                Menu {
                    Picker(L("Map style"), selection: $style) {
                        ForEach(Style.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                    }
                    Toggle(isOn: $tilted.animation()) { Label("3D buildings", systemImage: "building.2") }
                    Button { Task { await openLookAround() } } label: { Label("Street view", systemImage: "binoculars") }
                } label: {
                    Image(systemName: "square.3.layers.3d")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .background(.regularMaterial, in: Circle())
                        .foregroundStyle(Theme.ink)
                }
                .accessibilityLabel(L("Map style"))
            }
            if typing && !search.query.isEmpty {
                suggestions
            } else if showLegend {
                legend.transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 12).padding(.top, 8)
        .onChange(of: tilted) {
            guard let center else { return }
            withAnimation {
                camera = .camera(MapCamera(centerCoordinate: center, distance: min(distance, 2_500), heading: 0, pitch: tilted ? 60 : 0))
            }
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(ZoneKind.allCases, id: \.self) { k in
                legendRow(k.title, RoundedRectangle(cornerRadius: 3).fill(k.color))
            }
            legendRow(L("Pedestrian area"), RoundedRectangle(cornerRadius: 3).fill(Theme.red.opacity(0.4)))
            legendRow(L("Camera on"), Circle().fill(Theme.red))
            legendRow(L("Camera off"), Circle().fill(Theme.green))
            legendRow(L("Bus lane camera"), RoundedRectangle(cornerRadius: 3).fill(Theme.blueFill))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func legendRow(_ text: String, _ mark: some View) -> some View {
        HStack(spacing: 10) { mark.frame(width: 14, height: 14); Text(text).font(.system(size: 14, weight: .medium)) }
            .foregroundStyle(Theme.ink)
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 0) {
            if search.results.isEmpty {
                Text(search.failed ? L("Search isn't working right now. Check your connection.") : L("Keep typing…"))
                    .font(.system(size: 14)).foregroundStyle(Theme.muted).padding(14)
            }
            ForEach(Array(search.results.enumerated()), id: \.offset) { i, r in
                Button {
                    Task {
                        resolving = true
                        if let place = await search.resolve(r) {
                            store.select(place)
                            search.query = ""
                            typing = false
                        }
                        resolving = false
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill").font(.system(size: 22)).foregroundStyle(Theme.red)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(r.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                            if !r.subtitle.isEmpty { Text(r.subtitle).font(.system(size: 13)).foregroundStyle(Theme.muted).lineLimit(1) }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("map.result.\(i)")
                if i < search.results.count - 1 { Divider().padding(.leading, 48) }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// Il colore dello spillo: verde se si entra, rosso se no, giallo con condizioni
    private func placeTint(_ place: Place) -> Color {
        guard let z = store.zones(at: place.location).first?.zone else { return Theme.green }
        if store.pedestrianArea(at: place.location) != nil { return Theme.red }
        switch store.answer(zone: z, hotelInside: false).verdict {
        case .yes: return Theme.green
        case .no: return Theme.red
        case .conditional: return Color(hex: 0xD99A00)
        case .unsure: return Theme.muted
        }
    }

    /// La scheda del posto cercato: dov'è, in che zona, se adesso si entra
    private func placeSheet(_ place: Place) -> some View {
        let hit = store.zones(at: place.location).first
        let pedestrian = store.pedestrianArea(at: place.location)
        let answer = hit.map { store.answer(zone: $0.zone, hotelInside: false) }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "mappin.circle.fill").font(.system(size: 30)).foregroundStyle(placeTint(place))
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name).font(Theme.display(21)).lineLimit(2).foregroundStyle(Theme.ink)
                    Text(pedestrian.map { String(format: L("Pedestrian area · %@"), $0.name) }
                         ?? hit.map { "\($0.zone.type.title) · \($0.zone.shortName)" } ?? L("Outside the ZTL"))
                        .font(.system(size: 14)).foregroundStyle(Theme.muted)
                }
                Spacer()
                if pedestrian != nil {
                    Pill(text: L("Don't enter"), fill: Verdict.no(reason: "").pillFill, ink: Verdict.no(reason: "").pillInk)
                } else if let answer {
                    VerdictPill(verdict: answer.verdict)
                } else {
                    Pill(text: L("You can enter"), fill: Theme.greenSoft, ink: Theme.greenInk)
                }
            }
            if let answer, pedestrian == nil {
                Text(Self.detail(answer.verdict)).font(.system(size: 14)).foregroundStyle(Theme.ink).lineLimit(3)
            }
            HStack(spacing: 10) {
                if hit != nil {
                    WideButton(title: "Zone details", systemImage: "doc.text") {
                        if let hit { store.cityId = hit.city.id; store.zoneId = hit.zone.id }
                        showZone = true
                    }
                }
                WideButton(title: "Check the drive", systemImage: "car.fill", prominent: hit == nil) { tab = .trip }
            }
        }
        .padding(18)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, y: -2)
        .padding(.horizontal, 8).padding(.bottom, 8)
    }

    private static func detail(_ v: Verdict) -> String {
        switch v {
        case .yes(let r), .no(let r), .unsure(let r): r
        case .conditional(let r, let c): "\(r) \(c)"
        }
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
