import CoreLocation
import MapboxMaps
import SwiftUI
import UIKit

/// La prima pagina su Mapbox: Firenze al crepuscolo vista da lontano, ferma per tutti e tre i passi (così si confrontano),
/// rivolta a sud-est: il viale Lavagnini in basso, piazza Beccaria in alto. Il centro storico (Settori A e B) velato di
/// rosso con il bordo acceso; tutti gli edifici in 3D, uguali e trasparenti (Tools/intro_buildings.py), i monumenti
/// di Mapbox restano. Sopra, più evidenti di tutto, il ristorante e il parcheggio; la freccia di navigazione corre sui
/// percorsi veri. Tempi e stati sono quelli di IntroDrive, gli stessi della mappa di Apple e del disegno di riserva.
/// Provato prima con Mapbox GL JS con gli stessi valori.
struct IntroMapboxMap: UIViewRepresentable {
    var scene: IntroScene
    @ObservedObject var drive: IntroDrive
    var reduceMotion: Bool
    /// Quanto alzare logo e attribuzione di Mapbox dal fondo sicuro, sopra il pannello in basso
    var ornamentBottom: CGFloat
    /// Lo stile è arrivato e le linee sono pronte: si può partire
    var onReady: () -> Void
    /// Lo stile non è arrivato: si torna alla mappa di Apple
    var onFail: () -> Void

    /// L'inquadratura: zoom 14, inclinata di 45°, rivolta a 152° (sud-sud-est). Si vedono la partenza, il varco,
    /// tutta la strada dentro la ZTL, i viali intorno, il parcheggio e il ristorante
    static let center = CLLocationCoordinate2D(latitude: 43.7758, longitude: 11.2662)
    static let zoom = 14.0
    static let pitch = 45.0
    static let bearing = 152.0

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MapView {
        let camera = CameraOptions(center: Self.center, zoom: Self.zoom, bearing: Self.bearing, pitch: Self.pitch)
        let mapView = MapView(frame: .zero, mapInitOptions: MapInitOptions(mapStyle: NotteMap.style(standardBuildings: false),
                                                                           cameraOptions: camera))
        NotteMap.configure(mapView, ornamentBottom: ornamentBottom)
        context.coordinator.attach(mapView)
        return mapView
    }

    func updateUIView(_ mapView: MapView, context: Context) {
        context.coordinator.parent = self
        NotteMap.setOrnamentBottom(mapView, ornamentBottom)
    }

    static func dismantleUIView(_ mapView: MapView, coordinator: Coordinator) {
        coordinator.stop()
    }

    /// Gli edifici trasparenti, letti una volta sola (≈ 0,9 MB di GeoJSON)
    static let buildings: String? = {
        guard let url = Bundle.main.url(forResource: "firenze-edifici", withExtension: "geojson", subdirectory: "Intro")
            ?? Bundle.main.url(forResource: "firenze-edifici", withExtension: "geojson"),
              let data = try? Data(contentsOf: url) else { return nil }
        return String(data: data, encoding: .utf8)
    }()

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
            if let buildings = IntroMapboxMap.buildings { NotteMap.addBuildings(map, geojson: buildings) }
            NotteMap.addZone(map, id: "ztl", rings: [IntroScene.outline])
            NotteMap.addRoute(map, id: "direct", coordinates: IntroScene.direct, glowHex: 0xE5322D, coreHex: 0xFF6A5C)
            NotteMap.addRoute(map, id: "around", coordinates: IntroScene.around, glowHex: 0xF2F4FA, coreHex: 0xFFFFFF)
            NotteMap.addRoute(map, id: "park", coordinates: IntroScene.toParking, glowHex: 0xF2F4FA, coreHex: 0xFFFFFF)
            NotteMap.addWalk(map, id: "walk")
            addAnnotations(mapView)
            let link = CADisplayLink(target: DisplayTarget { [weak self] in self?.tick() }, selector: #selector(DisplayTarget.fire))
            link.add(to: .main, forMode: .common)
            self.link = link
            parent.onReady()
        }

        private func addAnnotations(_ mapView: MapView) {
            let drive = parent.drive
            let gate = ViewAnnotation(coordinate: parent.scene.gate,
                                      view: HostedAnnotationView(size: CGSize(width: 320, height: 96)) { IntroGateAnnotation(drive: drive) })
            gate.variableAnchors = [ViewAnnotationAnchorConfig(anchor: .bottom)]
            gate.allowOverlap = true
            mapView.viewAnnotations.add(gate)

            // Il ristorante e il parcheggio: sopra tutto il resto, con il punto esatto in fondo al gambo
            for (coordinate, kind) in [(IntroScene.restaurant, IntroPlacePin.Kind.restaurant), (IntroScene.parking, .parking)] {
                let pin = ViewAnnotation(coordinate: coordinate,
                                         view: HostedAnnotationView(size: IntroPlacePin.size) { IntroPinAnnotation(drive: drive, kind: kind) })
                pin.variableAnchors = [ViewAnnotationAnchorConfig(anchor: .bottom)]
                pin.allowOverlap = true
                pin.priority = 20
                mapView.viewAnnotations.add(pin)
            }

            let carView = HostedAnnotationView(size: CGSize(width: 56, height: 56)) { IntroArrowAnnotation(drive: drive) }
            let car = ViewAnnotation(coordinate: IntroScene.direct[0], view: carView)
            car.allowOverlap = true
            car.priority = 30
            mapView.viewAnnotations.add(car)
            self.car = car
            self.carView = carView
        }

        /// A ogni fotogramma: quanto si vede di ogni percorso, dove sta la freccia e dove guarda
        private func tick() {
            guard let mapView, let map = mapView.mapboxMap else { return }
            let drive = parent.drive
            let now = Date()
            let lines = drive.lines(at: now)
            for (id, line) in [("direct", lines.direct), ("around", lines.around), ("park", lines.park)]
                where changed(id, line.progress * 1000 + line.opacity) {
                NotteMap.setRoute(map, id: id, progress: line.progress, opacity: line.opacity)
            }
            if changed("walk", lines.walk) {
                NotteMap.setWalk(map, id: "walk", coordinates: drive.walk.prefix(lines.walk))
            }
            let here = drive.car(at: now)
            if changed("car", here.latitude * 1e6 + here.longitude) {
                car?.annotatedFeature = .geometry(Point(here))
            }
            let heading = drive.heading(at: now) - map.cameraState.bearing
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

private struct IntroPinAnnotation: View {
    @ObservedObject var drive: IntroDrive
    var kind: IntroPlacePin.Kind
    var body: some View {
        IntroPlacePin(kind: kind, lit: kind == .parking && drive.parked)
    }
}

/// La freccia di navigazione (il colore scelto in Account), con la luce del percorso sotto: rossa dentro la ZTL, bianca fuori
private struct IntroArrowAnnotation: View {
    @ObservedObject var drive: IntroDrive
    var body: some View {
        IntroArrow(glow: drive.step == .direct ? Notte.action : Notte.chalk)
            .frame(width: 56, height: 56)
    }
}
