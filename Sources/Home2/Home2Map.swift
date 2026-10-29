import CoreLocation
import MapboxMaps
import SwiftUI
import UIKit

/// La striscia di mappa in cima a «Varco»: la città del posto in 3D al crepuscolo (Mapbox), vista da vicino e inclinata,
/// con la camera che gira piano avanti e indietro intorno al posto. Le zone sono velate del colore della risposta
/// (rosso se il varco è attivo, verde se si entra). Con «mapMode» la stessa camera scende sulla mappa intera
/// (vista dall'alto, più lontana) e la mappa si può muovere con le dita. Le zone hanno lo stile della Mappa (MapTheme):
/// colore della risposta per il tuo veicolo, bordo tratteggiato, righe a 45° se attive. Senza token o se Mapbox non si carica,
/// VarcoView mostra la mappa di Apple (onFail).
/// Il posto non è mai un pallino (sembrava «sei qui»): il cartello della ZTL o lo spillo della destinazione, con il nome
/// (StripMarker); la tua posizione è il pallino blu di sempre, e se sei a meno di 5 km la ripresa tiene dentro anche te
/// (StripFrame).
struct Home2Map: UIViewRepresentable {
    var place: Place
    /// Le zone divise per colore e stato: ognuna con la SUA risposta (1.17.2), non quella del posto
    var zones: [AccessCache.Look: [[CLLocationCoordinate2D]]]
    /// La risposta del posto: il colore dello spillo
    var mood: Home2Answer.Mood
    var mapMode: Bool
    var reduceMotion: Bool
    /// Quanto alzare logo e attribuzione di Mapbox dal fondo sicuro (sopra il vetro con la risposta)
    var ornamentBottom: CGFloat
    /// Lo spazio sotto il posto nella ripresa vicina: 360 punti sotto il vetro a tutta pagina, 0 nella striscia della prima pagina
    var focusBottom: CGFloat = 360
    /// Il segno sul posto (nil = nessuno, per esempio quando il posto è la tua posizione)
    var marker: StripMarkerKind? = nil
    /// La tua posizione, solo se iOS la dà (permesso concesso): il pallino blu e la ripresa con te dentro se sei vicino
    var user: Coordinate? = nil
    /// Il lato corto della striscia in punti, per lo zoom della ripresa con te dentro
    var stripPoints: CGFloat = 150
    var onFail: () -> Void

    var stripFrame: StripFrame { StripFrame.make(target: place.location, user: user) }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MapView {
        let mapView = MapView(frame: .zero, mapInitOptions: MapInitOptions(mapStyle: NotteMap.style(),
                                                                           cameraOptions: Coordinator.scenic(stripFrame, bearing: Coordinator.bearing0, bottom: focusBottom,
                                                                                                             points: stripPoints)))
        NotteMap.configure(mapView, ornamentBottom: ornamentBottom)
        context.coordinator.attach(mapView)
        return mapView
    }

    func updateUIView(_ mapView: MapView, context: Context) {
        let old = context.coordinator.parent
        context.coordinator.parent = self
        context.coordinator.update(from: old)
        NotteMap.setOrnamentBottom(mapView, ornamentBottom)
    }

    static func dismantleUIView(_ mapView: MapView, coordinator: Coordinator) {
        coordinator.drift?.cancel()
    }

    @MainActor final class Coordinator {
        var parent: Home2Map
        private weak var mapView: MapView?
        private var cancelables = Set<AnyCancelable>()
        private var ready = false
        private var failed = false
        var drift: Cancelable?
        private var pin: ViewAnnotation?
        private let pinModel = Home2PinModel()
        private var zoneKey = 0

        static let bearing0 = 340.0

        init(_ parent: Home2Map) {
            self.parent = parent
            pinModel.mood = parent.mood
            pinModel.marker = parent.marker
        }

        /// La ripresa vicina: il posto un po' sopra il centro (sotto c'è il vetro con la risposta), inclinata di 60°.
        /// Con te dentro (StripFrame.includesUser): il punto a metà, lo zoom che tiene tutti e due, meno inclinata
        static func scenic(_ frame: StripFrame, bearing: Double, bottom: CGFloat = 360, points: CGFloat = 150) -> CameraOptions {
            CameraOptions(center: frame.center.cl, padding: UIEdgeInsets(top: 0, left: 0, bottom: bottom, right: 0),
                          zoom: frame.zoom(points: Double(points)), bearing: bearing, pitch: frame.includesUser ? 40 : 60)
        }

        /// La mappa intera: dall'alto, più lontana, il posto al centro
        static func overview(_ c: CLLocationCoordinate2D) -> CameraOptions {
            CameraOptions(center: c, padding: .zero, zoom: 14.0, bearing: 0, pitch: 0)
        }

        func attach(_ mapView: MapView) {
            self.mapView = mapView
            mapView.mapboxMap.onStyleLoaded.observeNext { [weak self] _ in
                Task { @MainActor in self?.styleLoaded() }
            }.store(in: &cancelables)
            mapView.mapboxMap.onMapLoadingError.observe { [weak self] error in
                guard error.type == .style else { return }
                Task { @MainActor in self?.fail() }
            }.store(in: &cancelables)
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(10))
                guard let self, !self.ready else { return }
                self.fail()
            }
        }

        private func fail() {
            guard !failed, !ready else { return }
            failed = true
            parent.onFail()
        }

        private func styleLoaded() {
            guard !ready, !failed, let mapView, let map = mapView.mapboxMap else { return }
            ready = true
            drawZones(map)
            let pinView = HostedAnnotationView(size: StripMarker.size) { Home2Pin(model: pinModel) }
            let pin = ViewAnnotation(coordinate: parent.place.location.cl, view: pinView)
            // La punta dello spillo (o il piede del palo) sul posto
            pin.variableAnchors = [ViewAnnotationAnchorConfig(anchor: .bottom)]
            pin.allowOverlap = true
            mapView.viewAnnotations.add(pin)
            self.pin = pin
            setPuck(mapView)
            startDrift(forward: true)
        }

        private static func key(_ zones: [AccessCache.Look: [[CLLocationCoordinate2D]]]) -> Int {
            var h = Hasher()
            for look in Self.order(zones.keys) {
                let rings = zones[look] ?? []
                h.combine(look)
                h.combine(rings.count)
                for z in rings { h.combine(z.count); if let f = z.first { h.combine(f.latitude); h.combine(f.longitude) } }
            }
            return h.finalize()
        }

        /// Grigio e verde sotto, rosso sopra: dove le zone si sovrappongono si vede la più severa
        nonisolated static func order<S: Sequence>(_ looks: S) -> [AccessCache.Look] where S.Element == AccessCache.Look {
            let rank: [Access: Int] = [.off: 0, .open: 1, .check: 2, .conditional: 3, .closed: 4]
            return looks.sorted { (rank[$0.access] ?? 0, $0.active ? 1 : 0) < (rank[$1.access] ?? 0, $1.active ? 1 : 0) }
        }
        private var drawn: [String] = []

        /// Un livello per colore e stato («zones-closed-1», …), ridisegnati da capo quando cambiano le zone o le loro risposte
        private func drawZones(_ map: MapboxMap) {
            for id in drawn { NotteMap.removeAnswerZones(map, id: id) }
            drawn = []
            for look in Self.order(parent.zones.keys) {
                let rings = parent.zones[look] ?? []
                guard !rings.isEmpty else { continue }
                let id = "zones-\(look.access)-\(look.active ? 1 : 0)"
                NotteMap.addAnswerZones(map, id: id, rings: rings, access: look.access, active: look.active)
                drawn.append(id)
            }
            zoneKey = Self.key(parent.zones)
        }

        /// Il pallino blu della posizione, solo con il permesso (la posizione c'è)
        private func setPuck(_ mapView: MapView) {
            let on = parent.user != nil
            guard (mapView.location.options.puckType != nil) != on else { return }
            mapView.location.options.puckType = on ? .puck2D(.makeDefault(showBearing: false)) : nil
        }

        func update(from old: Home2Map) {
            pinModel.mood = parent.mood
            pinModel.marker = parent.marker
            guard ready, let mapView, let map = mapView.mapboxMap else { return }
            setPuck(mapView)
            if Self.key(parent.zones) != zoneKey { drawZones(map) }
            let c = parent.place.location.cl
            if old.place.location != parent.place.location || (!parent.mapMode && parent.stripFrame.differs(from: old.stripFrame)) {
                pin?.annotatedFeature = .geometry(Point(c))
                if !parent.mapMode {
                    drift?.cancel()
                    mapView.camera.fly(to: Self.scenic(parent.stripFrame, bearing: map.cameraState.bearing, bottom: parent.focusBottom,
                                                       points: parent.stripPoints), duration: 2.2) { [weak self] _ in
                        self?.startDrift(forward: true)
                    }
                } else {
                    mapView.camera.ease(to: Self.overview(c), duration: 1.2)
                }
            }
            if old.mapMode != parent.mapMode {
                drift?.cancel()
                drift = nil
                NotteMap.setGestures(mapView, on: parent.mapMode)
                if parent.mapMode {
                    // La stessa camera scende e si raddrizza: dall'inclinata vicina alla mappa dall'alto
                    mapView.camera.ease(to: Self.overview(c), duration: parent.reduceMotion ? 0.4 : 1.8, curve: .easeInOut)
                } else {
                    mapView.camera.ease(to: Self.scenic(parent.stripFrame, bearing: Self.bearing0, bottom: parent.focusBottom,
                                                        points: parent.stripPoints), duration: parent.reduceMotion ? 0.4 : 1.8,
                                        curve: .easeInOut) { [weak self] _ in self?.startDrift(forward: true) }
                }
            }
        }

        /// La deriva lenta: 24° in 40 secondi, poi indietro, finché non si guarda la mappa
        private func startDrift(forward: Bool) {
            guard !parent.reduceMotion, !parent.mapMode, let mapView else { return }
            let target = Self.bearing0 + (forward ? 24 : 0)
            drift = mapView.camera.ease(to: CameraOptions(bearing: target), duration: 40, curve: .linear) { [weak self] position in
                guard position == .end else { return }
                self?.startDrift(forward: !forward)
            }
        }
    }
}

extension NotteMap {
    static func setZoneColor(_ map: MapboxMap, id: String, hex: UInt32) {
        let c = uiColor(hex)
        // Il bordo un po' più chiaro della velatura
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let edge = UIColor(hue: h, saturation: s * 0.8, brightness: min(1, b * 1.05), alpha: 1)
        try? map.setLayerProperty(for: id + "-fill", property: "fill-color", value: StyleColor(c).rawValue)
        try? map.setLayerProperty(for: id + "-glow", property: "line-color", value: StyleColor(c).rawValue)
        try? map.setLayerProperty(for: id + "-edge", property: "line-color", value: StyleColor(edge).rawValue)
    }

    static func setZoneRings(_ map: MapboxMap, id: String, rings: [[CLLocationCoordinate2D]]) {
        let polygons = rings.filter { $0.count > 2 }.map { Polygon([$0 + [$0[0]]]) }
        map.updateGeoJSONSource(withId: id, geoJSON: .geometry(.multiPolygon(MultiPolygon(polygons))))
    }
}

/// Il segno del posto sulla mappa: il cartello della ZTL o lo spillo della destinazione (StripMarker), mai un pallino
@MainActor final class Home2PinModel: ObservableObject {
    @Published var mood: Home2Answer.Mood = .red
    @Published var marker: StripMarkerKind?
}

private struct Home2Pin: View {
    @ObservedObject var model: Home2PinModel
    var body: some View {
        if let marker = model.marker {
            StripMarker(kind: marker, tint: model.mood.color)
        } else {
            Color.clear.frame(width: StripMarker.size.width, height: StripMarker.size.height)
        }
    }
}
