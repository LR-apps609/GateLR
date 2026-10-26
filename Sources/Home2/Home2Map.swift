import CoreLocation
import MapboxMaps
import SwiftUI
import UIKit

/// Il fondo della prima pagina 2.0: Firenze (o la città del posto) in 3D al crepuscolo, vista da vicino e inclinata,
/// con la camera che gira piano avanti e indietro intorno al posto. Le zone sono velate del colore della risposta
/// (rosso se il varco è attivo, verde se si entra). «Guarda la mappa» abbassa la stessa camera sulla mappa intera
/// (vista dall'alto, più lontana) e la mappa si può muovere con le dita; tornando, la camera risale.
struct Home2Map: UIViewRepresentable {
    var place: Place
    var zones: [[CLLocationCoordinate2D]]
    var mood: Home2Answer.Mood
    var mapMode: Bool
    var reduceMotion: Bool
    var onFail: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MapView {
        let mapView = MapView(frame: .zero, mapInitOptions: MapInitOptions(mapStyle: NotteMap.style(),
                                                                           cameraOptions: Coordinator.scenic(place.location.cl, bearing: Coordinator.bearing0)))
        NotteMap.configure(mapView)
        context.coordinator.attach(mapView)
        return mapView
    }

    func updateUIView(_ mapView: MapView, context: Context) {
        let old = context.coordinator.parent
        context.coordinator.parent = self
        context.coordinator.update(from: old)
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
        }

        /// La ripresa vicina: il posto un po' sopra il centro (sotto c'è il vetro con la risposta), inclinata di 60°
        static func scenic(_ c: CLLocationCoordinate2D, bearing: Double) -> CameraOptions {
            CameraOptions(center: c, padding: UIEdgeInsets(top: 0, left: 0, bottom: 360, right: 0),
                          zoom: 15.7, bearing: bearing, pitch: 60)
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
            NotteMap.addZone(map, id: "zones", rings: parent.zones, fill: 0.14, hex: parent.mood.hex)
            zoneKey = Self.key(parent.zones)
            let pinView = HostedAnnotationView(size: CGSize(width: 64, height: 64)) { Home2Pin(model: pinModel) }
            let pin = ViewAnnotation(coordinate: parent.place.location.cl, view: pinView)
            pin.allowOverlap = true
            mapView.viewAnnotations.add(pin)
            self.pin = pin
            startDrift(forward: true)
        }

        private static func key(_ zones: [[CLLocationCoordinate2D]]) -> Int {
            var h = Hasher()
            h.combine(zones.count)
            for z in zones { h.combine(z.count); if let f = z.first { h.combine(f.latitude); h.combine(f.longitude) } }
            return h.finalize()
        }

        func update(from old: Home2Map) {
            pinModel.mood = parent.mood
            guard ready, let mapView, let map = mapView.mapboxMap else { return }
            if old.mood != parent.mood { NotteMap.setZoneColor(map, id: "zones", hex: parent.mood.hex) }
            let key = Self.key(parent.zones)
            if key != zoneKey {
                zoneKey = key
                NotteMap.setZoneRings(map, id: "zones", rings: parent.zones)
            }
            let c = parent.place.location.cl
            if old.place.location != parent.place.location {
                pin?.annotatedFeature = .geometry(Point(c))
                if !parent.mapMode {
                    drift?.cancel()
                    mapView.camera.fly(to: Self.scenic(c, bearing: map.cameraState.bearing), duration: 2.2) { [weak self] _ in
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
                    mapView.camera.ease(to: Self.scenic(c, bearing: Self.bearing0), duration: parent.reduceMotion ? 0.4 : 1.8,
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

/// Il punto del posto sulla mappa: un cerchio del colore della risposta che pulsa piano
@MainActor final class Home2PinModel: ObservableObject {
    @Published var mood: Home2Answer.Mood = .red
}

private struct Home2Pin: View {
    @ObservedObject var model: Home2PinModel
    @State private var pulse = false
    var body: some View {
        ZStack {
            Circle().fill(model.mood.color.opacity(0.35)).frame(width: 56, height: 56)
                .scaleEffect(pulse ? 1 : 0.4).opacity(pulse ? 0 : 1)
            Circle().fill(model.mood.color).frame(width: 16, height: 16)
                .overlay(Circle().stroke(.white, lineWidth: 3))
                .shadow(color: model.mood.color, radius: 10)
        }
        .frame(width: 64, height: 64)
        .onAppear { withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) { pulse = true } }
    }
}
