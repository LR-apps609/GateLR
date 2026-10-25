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
    /// Livello di dettaglio (MapDetail.bucket) e parte visibile con margine: si aggiornano alla fine dei gesti
    @State private var bucket = MapDetail.bucket(for: 8_000)
    @State private var visibleBox: BBox?
    @State private var style: Style = .standard
    @State private var tilted = false
    @State private var driving = false
    // DriveSession non si osserva qui: pubblica a ogni posizione e ridisegnava tutta la mappa (centinaia di varchi)
    // anche sotto la schermata di guida
    @State private var parkings: [Parking] = []
    @State private var searchingParking = false
    @State private var parkingMessage: String?
    @State private var selectedParking: Parking?
    @State private var lookAround: MKLookAroundScene?
    @State private var showLookAround = false
    /// La mappa scura solo mentre la scheda Mappa è davanti: dietro alle altre schede resta quella normale
    @State private var visible = false
    @Environment(\.colorScheme) private var scheme

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


    /// «night»: il posto cercato su una mappa scura e smorzata, così la zona accesa e la risposta saltano all'occhio
    private func mapStyle(night: Bool) -> MapStyle {
        let elevation: MapStyle.Elevation = tilted ? .realistic : .automatic
        if night { return .standard(elevation: tilted ? .realistic : .flat, emphasis: .muted, pointsOfInterest: .excludingAll) }
        switch style {
        case .standard: return .standard(elevation: elevation, pointsOfInterest: .excludingAll)
        case .hybrid: return .hybrid(elevation: elevation, pointsOfInterest: .excludingAll)
        case .imagery: return .imagery(elevation: elevation)
        }
    }

    var body: some View {
        let zone = store.zone
        let answer = store.answer()
        // Le forme pronte (ordinate, grandi sotto) si calcolano una volta per ogni versione dei dati, non a ogni disegno
        // Da lontano perimetri semplificati e solo le zone nella parte visibile (MapShapes, ricalcolati solo
        // quando cambia il gradino di zoom o la parte visibile alla fine di un gesto)
        let shapes = MapShapes.visible(store, bucket: bucket, in: visibleBox, selected: zone.id)
        // Da lontano niente varchi (pallini sovrapposti a centinaia); da vicino quelli nella parte visibile
        let gateGroups = distance < MapDetail.gateDistance
            ? MapShapes.gates(store, in: visibleBox, selected: zone.id, near: distance < 6_000) : []
        // Il posto cercato: la risposta si calcola una volta per disegno e vale per zone, spillo e scheda
        let check = store.place.map { PlaceCheck($0, store: store) }
        let lit = check?.zoneIds ?? []
        let night = visible && check != nil && style == .standard
        MapReader { proxy in
            Map(position: $camera) {
                ForEach(shapes) { shape in
                    let z = shape.zone
                    let selected = z.id == zone.id
                    let on = lit.contains(z.id)
                    let tint = on ? (check?.neon ?? z.type.color) : z.type.color
                    if check != nil {
                        // Con un posto cercato: accese (rosso o verde, con un bagliore) le zone che lo contengono,
                        // appena accennate le altre
                        if on {
                            MapPolygon(coordinates: shape.coords)
                                .foregroundStyle(.clear)
                                .stroke(tint.opacity(0.3), lineWidth: 12)
                        }
                        MapPolygon(coordinates: shape.coords)
                            .foregroundStyle(on ? tint.opacity(0.18) : tint.opacity(0.05))
                            .stroke(on ? tint : Color.white.opacity(0.22), lineWidth: on ? 2.5 : 1)
                    } else {
                        // Il verde (zone a basse emissioni) pieno e ben visibile; rosso e giallo tratteggiati
                        MapPolygon(coordinates: shape.coords)
                            .foregroundStyle(tint.opacity(z.type == .green ? (selected ? 0.30 : 0.20) : (selected ? 0.24 : 0.13)))
                            .stroke(tint.opacity(selected || z.type == .green ? 1 : 0.7),
                                    style: StrokeStyle(lineWidth: z.type == .green ? 4 : (selected ? 3 : 2), dash: z.type == .green ? [] : [8, 5]))
                    }
                    // Un solo segno piccolo per zona: lettera e colore (la legenda spiega i colori)
                    if shape.width > distance * 0.06 && (check == nil || on) {
                        Annotation("", coordinate: shape.label, anchor: .center) {
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
                        ForEach(MapShapes.pedestrian(city, store)) { a in
                            MapPolygon(coordinates: a.coords)
                                .foregroundStyle(Theme.red.opacity(0.22))
                                .stroke(Theme.red.opacity(0.7), lineWidth: 1)
                        }
                        ForEach(city.cameras ?? []) { cam in
                            Annotation(cam.name, coordinate: cam.location.cl) {
                                Image(systemName: cam.kind == .bus ? "bus.fill" : "figure.walk")
                                    .font(.app(size: 9, weight: .bold)).foregroundStyle(.white)
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
                ForEach(gateGroups) { group in
                    let on = store.engine.isActive(group.zone, at: Date())
                    ForEach(group.gates) { g in
                        Annotation(g.name, coordinate: g.location.cl) {
                            Image(systemName: "video.fill")
                                .font(.app(size: 9, weight: .bold))
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
                    if night {
                        MapPolyline(coordinates: plan.path.map(\.cl))
                            .stroke(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round))
                    }
                    MapPolyline(coordinates: plan.path.map(\.cl))
                        .stroke(night ? Color.white : Theme.blue, style: StrokeStyle(lineWidth: night ? 4 : 5, lineCap: .round, lineJoin: .round))
                    if let p = plan.parking {
                        Annotation(p.name, coordinate: p.location.cl) {
                            Text("P").font(.app(size: 15, weight: .heavy)).foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(Theme.blueFill, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(.white, lineWidth: 2))
                        }
                    }
                }
                if let check {
                    // Il riquadro con la risposta, sopra il posto, legato da una linea sottile
                    Annotation("", coordinate: check.place.location.cl, anchor: .bottom) {
                        PlaceCallout(check: check)
                    }
                    .annotationTitles(.hidden)
                    Annotation(check.place.name, coordinate: check.place.location.cl, anchor: .center) {
                        Circle().fill(check.neon).frame(width: 16, height: 16)
                            .overlay(Circle().stroke(.white, lineWidth: 3))
                            .background(Circle().fill(check.neon.opacity(0.3)).frame(width: 36, height: 36))
                            .shadow(color: check.neon.opacity(0.8), radius: 6)
                            .accessibilityHidden(true)
                    }
                    .annotationTitles(.hidden)
                }
                ForEach(parkings) { p in
                    Annotation(p.name, coordinate: p.coordinate) {
                        Text("P")
                            .font(.app(size: 15, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(Color(hex: 0x1F4E9E), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(.white, lineWidth: 2))
                            .onTapGesture { selectedParking = p }
                    }
                }
                UserAnnotation()
            }
            .mapStyle(mapStyle(night: night))
            .environment(\.colorScheme, night ? .dark : scheme)
            .mapControls { MapUserLocationButton(); MapCompass(); MapPitchToggle(); MapScaleView() }
            // Si aggiorna solo quando lo zoom cambia davvero (più dell'8%): la mappa resta fluida
            .onMapCameraChange(frequency: .continuous) { ctx in
                let d = ctx.camera.distance
                if abs(d - distance) / max(distance, 1) > 0.08 { distance = d }
            }
            .onMapCameraChange(frequency: .onEnd) { ctx in
                distance = ctx.camera.distance
                center = ctx.camera.centerCoordinate
                // Gradino di zoom e parte visibile: cambiano solo alla fine del gesto
                let b = MapDetail.bucket(for: ctx.camera.distance)
                if b != bucket { bucket = b }
                let box = MapShapes.box(ctx.region)
                if box != visibleBox { visibleBox = box }
            }
            .onTapGesture { point in
                guard let c = proxy.convert(point, from: .local) else { return }
                // Le forme sono già ordinate dalla più grande: l'ultima che contiene il punto è la più piccola
                if let z = MapShapes.zones(store).last(where: { $0.zone.contains(c) })?.zone, z.id != zone.id {
                    withAnimation(.snappy) { select(z) }
                }
            }
        }
        // iPad: la mappa a tutto schermo, barra e scheda larghe al massimo 700 punti, al centro
        .safeAreaInset(edge: .top) { topBar.readableFrame() }
        .safeAreaInset(edge: .bottom) {
            if !typing {
                Group {
                    if let check { placeSheet(check) } else { sheet(zone: zone, answer: answer) }
                }
                .readableFrame()
            }
        }
        .onAppear { search.focus(on: store.city) }
        .onAppear { visible = true; focus() }
        .onDisappear { visible = false }
        .onChange(of: store.cityId) { parkings = []; focus() }
        .onChange(of: store.place) { focus() }
        .onChange(of: planner.plan) { focus() }
        .sheet(item: $selectedParking) { p in ParkingSheet(parking: p).presentationDetents([.height(260)]) }
        .fullScreenCover(isPresented: $driving) { DriveView() }
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
                // Si vede tutta la zona che contiene il posto (il confine acceso), se non è enorme
                if let z = store.zones(at: place.location).first?.zone, z.widthMeters < 6_000 {
                    camera = .region(z.region(padding: 1.25))
                } else {
                    camera = .camera(MapCamera(centerCoordinate: place.location.cl, distance: 1_500, heading: 0, pitch: 0))
                }
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
                .font(.app(size: 16))
                .padding(.horizontal, 12).frame(height: 44)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                Button { withAnimation(.snappy) { showLegend.toggle() } } label: {
                    Image(systemName: "info").font(.app(size: 16, weight: .bold))
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
                        .font(.app(size: 16, weight: .semibold))
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
        HStack(spacing: 10) { mark.frame(width: 14, height: 14); Text(text).font(.app(size: 14, weight: .medium)) }
            .foregroundStyle(Theme.ink)
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 0) {
            if search.results.isEmpty {
                Text(search.failed ? L("Search isn't working right now. Check your connection.") : L("Keep typing…"))
                    .font(.app(size: 14)).foregroundStyle(Theme.muted).padding(14)
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
                        Image(systemName: "mappin.circle.fill").font(.app(size: 22)).foregroundStyle(Theme.red)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(r.title).font(.app(size: 15, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                            if !r.subtitle.isEmpty { Text(r.subtitle).font(.app(size: 13)).foregroundStyle(Theme.muted).lineLimit(1) }
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

    /// La scheda del posto cercato: dov'è, in che zona, se adesso si entra
    private func placeSheet(_ check: PlaceCheck) -> some View {
        let place = check.place
        let hit = check.hits.first
        let pedestrian = check.pedestrian
        let answer = check.answer
        let here = GateMonitor.shared.location     // letta, non osservata: la mappa non si ridisegna a ogni passo
        let meters = here.map { CLLocation(latitude: place.location.lat, longitude: place.location.lon).distance(from: $0) }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "mappin.circle.fill").font(.app(size: 30)).foregroundStyle(check.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name).font(Theme.display(21)).lineLimit(2).foregroundStyle(Theme.ink)
                    Text(check.zoneLine)
                        .font(.app(size: 14)).foregroundStyle(Theme.muted)
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
            // Riquadri sottili: fino a quando vale la risposta, quanto sei lontano
            if check.until != nil || meters != nil {
                HStack(spacing: 8) {
                    if let until = check.until { infoBox(L("ZTL hours"), until) }
                    if let meters, meters < 200_000 { infoBox(L("From you"), DriveSession.distanceText(meters)) }
                }
            }
            if let parkingMessage {
                Text(parkingMessage).font(.app(size: 13)).foregroundStyle(Theme.muted)
            }
            if let answer, pedestrian == nil {
                Text(Self.detail(answer.verdict)).font(.app(size: 14)).foregroundStyle(Theme.ink).lineLimit(3)
            }
            // «Avvia» direttamente da qui: il navigatore preferito con gli avvisi di GateLR
            HStack(spacing: 10) {
                StartControls(target: place, label: L("Start"), onStart: { target in
                    Task {
                        await DriveSession.shared.start(to: target, store: store)
                        driving = DriveSession.shared.active
                    }
                }, onGuardian: { target, navigator in
                    Guardian.shared.start(to: target, with: navigator, store: store)
                }, identifier: "map.start")
            }
            HStack(spacing: 10) {
                if hit != nil {
                    WideButton(title: "Zone details", systemImage: "doc.text", prominent: false) {
                        if let hit { store.cityId = hit.city.id; store.zoneId = hit.zone.id }
                        showZone = true
                    }
                }
                WideButton(title: "Trip details", systemImage: "suitcase.rolling", prominent: false) {
                    store.select(place); tab = .trip
                }
            }
        }
        .padding(18)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, y: -2)
        .padding(.horizontal, 8).padding(.bottom, 8)
    }

    private func infoBox(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased()).font(Theme.label(11)).tracking(1).foregroundStyle(Theme.muted)
            Text(value).font(.app(size: 14, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Theme.line, lineWidth: 1))
        .accessibilityElement(children: .combine)
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
                            Image(systemName: "chevron.down").font(.app(size: 13, weight: .bold))
                        }
                        .foregroundStyle(Theme.ink)
                    }
                    HStack(spacing: 6) {
                        Circle().fill(zone.type.color).frame(width: 8, height: 8)
                        Text("\(zone.type.title) · " + String(format: L(answer.gatesOn ? "%lld gates · on now" : "%lld gates · off now"), zone.gates.count))
                            .font(.app(size: 14)).foregroundStyle(Theme.muted)
                    }
                }
                Spacer()
                VerdictPill(verdict: answer.verdict)
            }
            if let parkingMessage {
                Text(parkingMessage).font(.app(size: 13)).foregroundStyle(Theme.muted)
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

/// Le forme delle zone pronte per la mappa: coordinate già convertite, punto della lettera, larghezza,
/// ordine dalla più grande. Prima si ricalcolava tutto a ogni disegno (perimetri da 800 punti, ordinamento
/// che ricalcolava l'area a ogni confronto), anche più volte al secondo.
/// Livello di dettaglio: per ogni gradino di zoom (MapDetail) i perimetri semplificati si calcolano una volta
/// e restano in memoria; si disegnano solo le zone e i varchi dentro la parte di mappa visibile (con margine).
@MainActor
enum MapShapes {
    struct Shape: Identifiable {
        let zone: Zone
        let coords: [CLLocationCoordinate2D]
        let label: CLLocationCoordinate2D
        let width: Double
        let bounds: BBox
        var id: String { zone.id }
    }
    struct Area: Identifiable {
        let id: String
        let coords: [CLLocationCoordinate2D]
    }
    /// I varchi di una zona da disegnare
    struct GateGroup: Identifiable {
        let zone: Zone
        let gates: [Gate]
        var id: String { zone.id }
    }

    private struct VisibleKey: Equatable {
        var bucket: Int, box: BBox?, selected: String
    }
    private struct GateKey: Equatable {
        var box: BBox?, selected: String, near: Bool
    }

    private static var version = -1
    private static var shapes: [Shape] = []
    private static var byId: [String: Int] = [:]
    private static var areas: [String: [Area]] = [:]
    private static var detail: [Int: [Shape]] = [:]
    private static var visibleKey: VisibleKey?
    private static var visibleShapes: [Shape] = []
    private static var gateKey: GateKey?
    private static var gateGroups: [GateGroup] = []

    private static func refresh(_ store: Store) {
        guard version != store.citiesVersion else { return }
        version = store.citiesVersion
        let ranked: [(zone: Zone, area: Double)] = store.cities.flatMap(\.zones).map { (zone: $0, area: $0.roughArea) }
        shapes = ranked.sorted { $0.area > $1.area }                   // le grandi sotto
            .map { r -> Shape in
                let z = r.zone
                let box = z.bounds ?? BBox(z.perimeter) ?? BBox(minLat: 0, minLon: 0, maxLat: 0, maxLon: 0)
                return Shape(zone: z, coords: z.perimeter.map(\.cl), label: z.labelPoint, width: z.widthMeters, bounds: box)
            }
        byId = [:]
        for (i, s) in shapes.enumerated() { byId[s.zone.id] = i }
        areas = [:]
        detail = [:]
        visibleKey = nil
        gateKey = nil
    }

    /// Tutte le zone con il perimetro intero (tocchi sulla mappa, ricerche)
    static func zones(_ store: Store) -> [Shape] {
        refresh(store)
        return shapes
    }

    /// Tutte le zone con il perimetro semplificato per quel gradino di zoom (0 = intero)
    static func zones(_ store: Store, bucket: Int) -> [Shape] {
        refresh(store)
        guard bucket > 0 else { return shapes }
        if let hit = detail[bucket] { return hit }
        let tolerance = MapDetail.tolerance(for: bucket)
        let list = shapes.map { s in
            Shape(zone: s.zone, coords: Simplifier.simplifyPolygon(s.zone.perimeter, tolerance: tolerance).map(\.cl),
                  label: s.label, width: s.width, bounds: s.bounds)
        }
        detail[bucket] = list
        return list
    }

    /// Le zone da disegnare: quelle che toccano la parte visibile (box, già allargato del margine),
    /// più quella scelta. Senza box (prima che la mappa dica dove guarda) tutte.
    static func visible(_ store: Store, bucket: Int, in box: BBox?, selected: String) -> [Shape] {
        let all = zones(store, bucket: bucket)
        let key = VisibleKey(bucket: bucket, box: box, selected: selected)
        if key == visibleKey { return visibleShapes }
        visibleKey = key
        visibleShapes = box.map { b in all.filter { $0.zone.id == selected || $0.bounds.intersects(b) } } ?? all
        return visibleShapes
    }

    /// I varchi da disegnare: quelli della zona scelta e, da vicino («near»), delle zone visibili;
    /// sempre solo quelli dentro la parte visibile della mappa
    static func gates(_ store: Store, in box: BBox?, selected: String, near: Bool) -> [GateGroup] {
        refresh(store)
        let key = GateKey(box: box, selected: selected, near: near)
        if key == gateKey { return gateGroups }
        gateKey = key
        gateGroups = shapes.compactMap { s -> GateGroup? in
            guard s.zone.id == selected || near else { return nil }
            if let box, !s.bounds.expanded(by: 0.05).intersects(box) { return nil }
            let list = box.map { b in s.zone.gates.filter { b.contains(lat: $0.location.lat, lon: $0.location.lon) } } ?? s.zone.gates
            return list.isEmpty ? nil : GateGroup(zone: s.zone, gates: list)
        }
        return gateGroups
    }

    /// Le aree pedonali di una città
    static func pedestrian(_ city: City, _ store: Store) -> [Area] {
        refresh(store)
        if let hit = areas[city.id] { return hit }
        let list = (city.pedestrian ?? []).map { Area(id: $0.id, coords: $0.perimeter.map(\.cl)) }
        areas[city.id] = list
        return list
    }

    /// Il perimetro di una zona già convertito (per la schermata di guida), semplificato per il gradino di zoom
    static func coords(_ zone: Zone, _ store: Store, bucket: Int = 0) -> [CLLocationCoordinate2D] {
        let list = zones(store, bucket: bucket)
        if let i = byId[zone.id], i < list.count { return list[i].coords }
        return zone.perimeter.map(\.cl)
    }

    /// La parte visibile della mappa, allargata di metà per lato: le forme non spariscono spostando la mappa un poco
    nonisolated static func box(_ region: MKCoordinateRegion) -> BBox {
        let c = region.center, s = region.span
        let b = BBox(minLat: c.latitude - s.latitudeDelta / 2, minLon: c.longitude - s.longitudeDelta / 2,
                     maxLat: c.latitude + s.latitudeDelta / 2, maxLon: c.longitude + s.longitudeDelta / 2)
        return b.expanded(by: 0.5)
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
            Label("Outside the ZTL", systemImage: "checkmark.circle.fill").font(.app(size: 13, weight: .semibold)).foregroundStyle(Theme.greenInk)
            Text(parking.name).font(Theme.display(26))
            if let address = parking.item.placemark.title {
                Text(address).font(.app(size: 14)).foregroundStyle(Theme.muted)
            }
            WideButton(title: "Directions in Maps", systemImage: "arrow.triangle.turn.up.right.diamond.fill") {
                parking.item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
            }
            Text("Prices and opening hours: check the car park before you go.").font(.app(size: 12)).foregroundStyle(Theme.muted)
        }
        .padding(20)
    }
}

extension Zone {
    func contains(_ c: CLLocationCoordinate2D) -> Bool { contains(lat: c.latitude, lon: c.longitude) }

    /// Dove mettere la lettera del settore: il centro del rettangolo che contiene il perimetro.
    /// Le zone verdi (che contengono le altre, come l'Area B) hanno la scritta più in alto, per non coprirle.
    var labelPoint: CLLocationCoordinate2D {
        let b = box
        let lat = type == .green ? b.maxLat - (b.maxLat - b.minLat) * 0.18 : (b.minLat + b.maxLat) / 2
        return .init(latitude: lat, longitude: (b.minLon + b.maxLon) / 2)
    }

    /// Il rettangolo del perimetro: quello calcolato alla lettura, se c'è
    private var box: BBox { bounds ?? BBox(perimeter) ?? BBox(minLat: 0, minLon: 0, maxLat: 0, maxLon: 0) }

    /// Larghezza approssimata in metri: le scritte delle zone piccole compaiono solo da vicino
    var widthMeters: Double {
        let b = box
        let k: Double = cos((b.minLat + b.maxLat) / 2 * Double.pi / 180)
        let tall: Double = (b.maxLat - b.minLat) * 111_000
        let wide: Double = (b.maxLon - b.minLon) * 111_000 * k
        return max(tall, wide)
    }

    func region(padding: Double) -> MKCoordinateRegion {
        let b = box
        let center = CLLocationCoordinate2D(latitude: (b.minLat + b.maxLat) / 2, longitude: (b.minLon + b.maxLon) / 2)
        let span = MKCoordinateSpan(latitudeDelta: (b.maxLat - b.minLat) * padding + 0.004,
                                    longitudeDelta: (b.maxLon - b.minLon) * padding + 0.004)
        return MKCoordinateRegion(center: center, span: span)
    }
}

/// Il riquadro sulla mappa scura: «ZTL ATTIVA · NON ENTRARE» o «FUORI DALLA ZTL», con la linea fino al posto
private struct PlaceCallout: View {
    let check: PlaceCheck
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: check.symbol).font(.system(size: 11, weight: .heavy))
                    Text(check.callout.uppercased()).font(Theme.label(13)).tracking(1.1).lineLimit(1)
                }
                .foregroundStyle(check.neon)
                .fixedSize()
                Text(check.place.name).font(.app(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.85)).lineLimit(1)
                if let until = check.until {
                    Text(until).font(.app(size: 11)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .frame(maxWidth: 260, alignment: .leading)
            .background(Color.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(check.neon, lineWidth: 1))
            .shadow(color: check.neon.opacity(0.45), radius: 8)
            Rectangle().fill(check.neon).frame(width: 1, height: 44)
        }
        .accessibilityElement(children: .combine)
    }
}
