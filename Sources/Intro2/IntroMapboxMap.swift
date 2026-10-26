import CoreLocation
import MapboxMaps
import SwiftUI
import UIKit

/// La prima pagina su Mapbox: Firenze in 3D al crepuscolo vista da lontano (circa 3 km, inclinata di 52°), il centro
/// storico (Settori A e B) velato di rosso con il bordo acceso, fuori niente. Una sola ripresa lenta e continua;
/// l'auto (il segno scelto in Account) corre sul percorso vero, il pannello del varco di via Cavour gira su
/// «VARCO ATTIVO», poi il percorso bianco si disegna da sé intorno alla zona fino al parcheggio Parterre.
/// Tempi e stati sono quelli di IntroDrive, gli stessi della mappa di Apple e del disegno di riserva.
struct IntroMapboxMap: UIViewRepresentable {
    var scene: IntroScene
    @ObservedObject var drive: IntroDrive
    var reduceMotion: Bool
    /// Lo stile è arrivato e le linee sono pronte: si può partire
    var onReady: () -> Void
    /// Lo stile non è arrivato: si torna alla mappa di Apple
    var onFail: () -> Void

    /// L'inquadratura: tra il Duomo, il varco e il Parterre, rivolta a sud-sud-ovest (Duomo in alto, viali in basso)
    static let center = CLLocationCoordinate2D(latitude: 43.7812, longitude: 11.2603)
    static let zoom = 14.6
    static let pitch = 52.0
    static let bearing = 200.0

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MapView {
        let camera = CameraOptions(center: Self.center, zoom: Self.zoom, bearing: Self.bearing, pitch: Self.pitch)
        let mapView = MapView(frame: .zero, mapInitOptions: MapInitOptions(mapStyle: NotteMap.style(), cameraOptions: camera))
        NotteMap.configure(mapView)
        context.coordinator.attach(mapView)
        return mapView
    }

    func updateUIView(_ mapView: MapView, context: Context) {
        context.coordinator.parent = self
    }

    static func dismantleUIView(_ mapView: MapView, coordinator: Coordinator) {
        coordinator.stop()
    }

    @MainActor final class Coordinator {
        var parent: IntroMapboxMap
        private weak var mapView: MapView?
        private var cancelables = Set<AnyCancelable>()
        private var link: CADisplayLink?
        private var ready = false
        private var failed = false
        private var car: ViewAnnotation?
        private var carView: HostedAnnotationView?
        /// Gli ultimi valori mandati a Mapbox: si aggiorna solo quello che cambia
        private var last: [String: Double] = [:]

        init(_ parent: IntroMapboxMap) { self.parent = parent }

        func attach(_ mapView: MapView) {
            self.mapView = mapView
            mapView.mapboxMap.onStyleLoaded.observeNext { [weak self] _ in
                Task { @MainActor in self?.styleLoaded() }
            }.store(in: &cancelables)
            mapView.mapboxMap.onMapLoadingError.observe { [weak self] error in
                guard error.type == .style else { return }
                Task { @MainActor in self?.fail() }
            }.store(in: &cancelables)
            // Niente stile dopo 9 secondi (rete lentissima, simulatore senza Metal): mappa di Apple
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(9))
                guard let self, !self.ready else { return }
                self.fail()
            }
        }

        private func fail() {
            guard !failed, !ready else { return }
            failed = true
            stop()
            parent.onFail()
        }

        func stop() {
            link?.invalidate()
            link = nil
        }

        private func styleLoaded() {
            guard !ready, !failed, let mapView else { return }
            ready = true
            let map = mapView.mapboxMap!
            let scene = parent.scene
            NotteMap.addZone(map, id: "ztl", rings: [IntroScene.outline])
            NotteMap.addRoute(map, id: "red", coordinates: IntroScene.badRoute, glowHex: 0xE5322D, coreHex: 0xFF6A5C)
            NotteMap.addRoute(map, id: "white", coordinates: IntroScene.goodRoute, glowHex: 0xF2F4FA, coreHex: 0xFFFFFF)
            addAnnotations(mapView, scene: scene)
            let link = CADisplayLink(target: DisplayTarget { [weak self] in self?.tick() }, selector: #selector(DisplayTarget.fire))
            link.add(to: .main, forMode: .common)
            self.link = link
            // Una sola ripresa, lenta e continua per tutta la pagina: la camera gira di 12° e si avvicina appena
            if !parent.reduceMotion {
                mapView.camera.ease(to: CameraOptions(zoom: IntroMapboxMap.zoom + 0.18, bearing: IntroMapboxMap.bearing - 12),
                                    duration: 22, curve: .linear)
            }
            parent.onReady()
        }

        private func addAnnotations(_ mapView: MapView, scene: IntroScene) {
            let drive = parent.drive
            let parking = ViewAnnotation(coordinate: IntroScene.goodRoute.last!,
                                         view: HostedAnnotationView(size: CGSize(width: 40, height: 40)) { IntroParkingAnnotation(drive: drive) })
            parking.allowOverlap = true
            mapView.viewAnnotations.add(parking)

            let gate = ViewAnnotation(coordinate: scene.gate,
                                      view: HostedAnnotationView(size: CGSize(width: 320, height: 96)) { IntroGateAnnotation(drive: drive) })
            gate.variableAnchors = [ViewAnnotationAnchorConfig(anchor: .bottom)]
            gate.allowOverlap = true
            mapView.viewAnnotations.add(gate)

            let carView = HostedAnnotationView(size: CGSize(width: 48, height: 48)) { IntroCarAnnotation(drive: drive) }
            let car = ViewAnnotation(coordinate: IntroScene.badRoute[0], view: carView)
            car.allowOverlap = true
            car.priority = 10
            mapView.viewAnnotations.add(car)
            self.car = car
            self.carView = carView
        }

        /// A ogni fotogramma: quanto dei due percorsi si vede, dove sta l'auto e dove guarda
        private func tick() {
            guard let mapView, let map = mapView.mapboxMap else { return }
            let drive = parent.drive
            let now = Date()
            let good = drive.onGoodRoute
            let badF = drive.phase == .waiting ? 0 : drive.badFraction(now)
            // Il rosso si spegne in 0,9 s quando parte il bianco
            let fadeFrom = drive.goodStart.addingTimeInterval(-IntroDrive.flyBack)
            let badOpacity = good ? max(0, 1 - now.timeIntervalSince(fadeFrom) / 0.9) : 1
            let goodF = good ? drive.goodFraction(now) : 0
            if changed("red", badF * 1000 + badOpacity) { NotteMap.setRoute(map, id: "red", progress: badF, opacity: badOpacity) }
            if changed("white", goodF) { NotteMap.setRoute(map, id: "white", progress: goodF, opacity: 1) }

            let path = good ? drive.good : drive.bad
            let f = good ? goodF : badF
            let here = path.point(f)
            if changed("car", here.latitude * 1e6 + here.longitude) {
                car?.annotatedFeature = .geometry(Point(here))
            }
            let ahead = path.point(min(f + 0.01, 1)), behind = path.point(max(f - 0.01, 0))
            let heading = behind.notteBearing(to: ahead) - mapView.mapboxMap.cameraState.bearing
            if changed("heading", heading) {
                carView?.content.transform = CGAffineTransform(rotationAngle: heading * .pi / 180)
            }
        }

        private func changed(_ key: String, _ value: Double) -> Bool {
            if let old = last[key], abs(old - value) < 0.0001 { return false }
            last[key] = value
            return true
        }
    }
}

/// CADisplayLink tiene forte il suo bersaglio: un oggetto a parte, così il coordinatore non resta in memoria
final class DisplayTarget: NSObject {
    let action: @MainActor () -> Void
    init(_ action: @escaping @MainActor () -> Void) { self.action = action }
    /// CADisplayLink aggiunto al RunLoop principale: chiama sempre sul thread principale
    @objc func fire() { MainActor.assumeIsolated { action() } }
}

// MARK: Le viste sopra la mappa

/// Il pannello del varco sul suo palo, con la base sul punto del varco
private struct IntroGateAnnotation: View {
    @ObservedObject var drive: IntroDrive
    var body: some View {
        GateSign(state: drive.panel, size: 16)
            .frame(width: 320, height: 96, alignment: .bottom)
    }
}

private struct IntroParkingAnnotation: View {
    @ObservedObject var drive: IntroDrive
    var body: some View {
        ParkingPin(lit: drive.phase == .arrived).frame(width: 40, height: 40)
    }
}

/// L'auto: il segno scelto in Account (il modellino della berlina se è ancora la freccia), con la luce del percorso sotto
private struct IntroCarAnnotation: View {
    @ObservedObject var drive: IntroDrive
    @AppStorage("vehicleMarker") private var marker = VehicleMarker.arrow.rawValue
    @AppStorage("vehicleColor") private var tint = VehicleColor.blue.rawValue

    var body: some View {
        let kind = VehicleMarker(rawValue: marker).flatMap { $0 == .arrow ? nil : $0 } ?? .sedan
        let paint = VehicleColor(rawValue: tint) ?? .blue
        let glow = drive.onGoodRoute ? Notte.chalk : Notte.action
        ZStack {
            Circle().fill(glow.opacity(0.55)).frame(width: 30, height: 30).blur(radius: 9)
            VehicleMarkerView(marker: kind, tint: paint, heading: 0)
                .scaleEffect(0.62)
        }
        .frame(width: 48, height: 48)
        .animation(.easeInOut(duration: 0.4), value: drive.onGoodRoute)
    }
}
