import CoreLocation
import MapboxMaps
import SwiftUI
import UIKit

/// La prima pagina su Mapbox: Firenze vista da lontano, di giorno (Standard chiaro) e poi la sera (crepuscolo «Notte»,
/// ZTL verde), ferma per tutti i passi (così si confrontano), rivolta a ovest: il viale Gramsci in basso, la Fortezza e
/// il Mercato Centrale in alto. Il centro storico (Settori A e B) velato di rosso con il bordo acceso; tutti gli edifici in 3D, uguali e trasparenti (Tools/intro_buildings.py), i monumenti
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

    /// L'inquadratura: zoom 13,95, inclinata di 45°, rivolta a 275° (ovest): la partenza in basso sul viale Gramsci, il
    /// centro della ZTL in mezzo tra la freccia e il ristorante (la strada dritta si legge come la più corta), i viali a
    /// destra, in alto il ristorante (dentro) e il parcheggio alla Fortezza (fuori), vicini
    static let center = CLLocationCoordinate2D(latitude: 43.7784, longitude: 11.2590)
    static let zoom = 13.95
    static let pitch = 45.0
    static let bearing = 275.0

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MapView {
        let camera = CameraOptions(center: Self.center, zoom: Self.zoom, bearing: Self.bearing, pitch: Self.pitch)
        let mapView = MapView(frame: .zero, mapInitOptions: MapInitOptions(mapStyle: NotteMap.dayStyle(standardBuildings: false),
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
        /// La sera è già sulla mappa (stile notte, ZTL verde)
        private var eveningShown = false

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
            // La strada della freccia in azzurro acceso in tutti i passi (il rosso è della ZTL)
            NotteMap.addRoute(map, id: "direct", coordinates: IntroScene.direct,
                              glowHex: IntroRouteColor.glowHex, coreHex: IntroRouteColor.coreHex)
            NotteMap.addRoute(map, id: "park", coordinates: IntroScene.toParking,
                              glowHex: IntroRouteColor.glowHex, coreHex: IntroRouteColor.coreHex)
            addFootprints(map)
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
            if drive.evening && !eveningShown {
                eveningShown = true
                NotteMap.setEvening(map)
                NotteMap.setZoneColor(map, id: "ztl", hex: 0x3BE07A)
            }
            for (id, line) in [("direct", lines.direct), ("park", lines.park)]
                where changed(id, line.progress * 1000 + line.opacity) {
                NotteMap.setRoute(map, id: id, progress: line.progress, opacity: line.opacity)
            }
            if changed("feet", Double(lines.footprints)) {
                setFootprints(map, count: lines.footprints)
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

        /// Le impronte del tratto a piedi: un livello di simboli (sinistra e destra), girati verso dove si cammina,
        /// sempre dritti verso lo schermo così si leggono anche lontano
        private func addFootprints(_ map: MapboxMap) {
            for left in [true, false] {
                let renderer = ImageRenderer(content: IntroFootprintMark(left: left).padding(3))
                renderer.scale = 3
                if let image = renderer.uiImage { try? map.addImage(image, id: Self.footImage(left)) }
            }
            var source = GeoJSONSource(id: "feet")
            source.data = .featureCollection(FeatureCollection(features: []))
            var layer = SymbolLayer(id: "feet-prints", source: "feet")
            layer.slot = .top
            layer.iconImage = .expression(Exp(.get) { "img" })
            layer.iconRotate = .expression(Exp(.get) { "r" })
            layer.iconRotationAlignment = .constant(.map)
            layer.iconPitchAlignment = .constant(.viewport)
            layer.iconAllowOverlap = .constant(true)
            layer.iconIgnorePlacement = .constant(true)
            layer.iconSize = .constant(1.3)
            layer.iconEmissiveStrength = .constant(1)
            try? map.addSource(source)
            try? map.addLayer(layer)
        }

        private static func footImage(_ left: Bool) -> String { "intro-foot-" + (left ? "l" : "r") }

        private func setFootprints(_ map: MapboxMap, count: Int) {
            let features = parent.drive.footprints.prefix(count).map { fp -> Feature in
                var f = Feature(geometry: .point(Point(fp.coordinate)))
                f.properties = ["r": .number(fp.bearing), "img": .string(Self.footImage(fp.left))]
                return f
            }
            map.updateGeoJSONSource(withId: "feet", geoJSON: .featureCollection(FeatureCollection(features: Array(features))))
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
        IntroArrow(glow: IntroRouteColor.glow)
            .frame(width: 56, height: 56)
    }
}
