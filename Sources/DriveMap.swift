import SwiftUI
import MapKit
import QuartzCore

/// La mappa della guida, con MKMapView: la camera e l'auto si spostano a ogni fotogramma (fino a 60 al secondo)
/// seguendo la posizione calcolata tra un GPS e l'altro. Linee, zone, semafori e simboli si aggiungono una volta
/// per percorso; il tratto già fatto si aggiorna spostando l'inizio della linea (strokeStart), senza ricrearla.
struct DriveMapView: UIViewRepresentable {
    let drive: DriveSession
    let store: Store
    var style: DriveView.DriveViewStyle
    var marker: VehicleMarker
    var tint: VehicleColor
    @Binding var following: Bool
    /// Cambia quando si tocca «Panoramica»
    var overviewToken: Int
    /// Cambiano solo quando cambia il percorso o la manovra (non a ogni posizione)
    var routeVersion: Int
    var maneuver: Coordinate?
    var maneuverSymbol: String
    var colorScheme: ColorScheme

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        map.showsCompass = true
        map.showsScale = true
        map.showsUserLocation = false
        map.isPitchEnabled = true
        map.isRotateEnabled = true
        context.coordinator.attach(map)
        context.coordinator.sync(map)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.sync(map)
    }

    static func dismantleUIView(_ map: MKMapView, coordinator: Coordinator) {
        coordinator.detach()
    }

    // MARK: Oggetti sulla mappa

    enum LineRole { case travelled, edge, fill, shine }
    final class RouteLine: MKPolyline { var role: LineRole = .fill }
    final class ZoneShape: MKPolygon { var zone: Zone? }
    final class VehicleAnnotation: MKPointAnnotation {}
    final class SignalAnnotation: MKPointAnnotation { var along: Double = 0; var key = 0 }
    final class EntryAnnotation: MKPointAnnotation { var zone: Zone? }
    final class ManeuverAnnotation: MKPointAnnotation {}
    final class DestinationAnnotation: MKPointAnnotation {}

    /// L'auto: l'immagine sta in una vista interna che gira, così MapKit non tocca la rotazione
    final class VehicleView: MKAnnotationView {
        let inner = UIImageView()
        override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
            super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
            addSubview(inner)
            isEnabled = false
            canShowCallout = false
            displayPriority = .required
            collisionMode = .none
            zPriority = .max
        }
        required init?(coder: NSCoder) { fatalError() }
        func set(_ image: UIImage) {
            inner.image = image
            bounds = CGRect(origin: .zero, size: image.size)
            inner.frame = bounds
        }
    }

    @MainActor
    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: DriveMapView
        private weak var map: MKMapView?
        private var link: CADisplayLink?
        private let vehicle = VehicleAnnotation()
        private weak var vehicleView: VehicleView?
        private var vehicleImage: UIImage?
        private var vehicleKey = ""

        // Quello che è già sulla mappa (si ridisegna solo se cambia)
        private var shownRoute = -1
        private var shownStyle: DriveView.DriveViewStyle?
        private var shownScheme: ColorScheme?
        private var shownOverview = 0
        private var shownBucket = 0
        private var wasFollowing = true
        private var lines: [RouteLine] = []
        private var renderers: [LineRole: MKPolylineRenderer] = [:]
        private var zones: [ZoneShape] = []
        private var entries: [EntryAnnotation] = []
        private var signals: [Int: SignalAnnotation] = [:]
        private var destination: DestinationAnnotation?
        private let maneuver = ManeuverAnnotation()
        private var maneuverShown = false
        private var maneuverKey = ""
        // Le lunghezze della linea in punti della mappa (per strokeStart, che è una frazione della lunghezza)
        private var mapCum: [Double] = []
        private var shownFraction = -1.0
        private var shownSignalsAt = -1_000.0
        private var images: [String: UIImage] = [:]

        // Camera morbida
        private let camera = MKMapCamera()
        private var camDistance: Double = 0
        private var camPitch: Double = 0
        private var camHeading: Double = 0
        private var lastTick: CFTimeInterval = 0
        private var blendFrom: (center: CLLocationCoordinate2D, distance: Double, heading: Double, pitch: Double)?
        private var blendStart: CFTimeInterval = 0

        init(_ parent: DriveMapView) { self.parent = parent }

        func attach(_ map: MKMapView) {
            self.map = map
            // Il dito sulla mappa (spostare, zoom, rotazione, inclinazione): si smette di seguire, compare «Ricentra»
            for g in [UIPanGestureRecognizer(), UIPinchGestureRecognizer(), UIRotationGestureRecognizer()] as [UIGestureRecognizer] {
                g.addTarget(self, action: #selector(touched(_:)))
                g.delegate = self
                g.cancelsTouchesInView = false
                map.addGestureRecognizer(g)
            }
            map.addAnnotation(vehicle)
            let proxy = LinkProxy(self)
            let l = CADisplayLink(target: proxy, selector: #selector(LinkProxy.tick(_:)))
            l.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
            l.add(to: .main, forMode: .common)
            link = l
        }

        func detach() {
            link?.invalidate()
            link = nil
        }

        func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

        @objc private func touched(_ g: UIGestureRecognizer) {
            guard g.state == .began, parent.following else { return }
            parent.following = false
        }

        // MARK: Cambi decisi da SwiftUI (rari)

        func sync(_ map: MKMapView) {
            if shownStyle != parent.style || shownScheme != parent.colorScheme {
                applyStyle(map)
            }
            if shownRoute != parent.routeVersion || shownStyle != parent.style {
                rebuildRoute(map)
            }
            shownStyle = parent.style
            shownScheme = parent.colorScheme
            let key = "\(parent.marker.rawValue)|\(parent.tint.rawValue)"
            if key != vehicleKey {
                vehicleKey = key
                vehicleImage = render(VehicleMarkerView(marker: parent.marker, tint: parent.tint, heading: 0))
                if let vehicleImage { vehicleView?.set(vehicleImage) }
            }
            updateManeuver(map)
            if parent.following && !wasFollowing {
                // «Ricentra»: dalla camera di adesso a quella dietro l'auto in poco più di mezzo secondo
                let c = map.camera
                blendFrom = (c.centerCoordinate, Double(c.centerCoordinateDistance), Double(c.heading), Double(c.pitch))
                blendStart = CACurrentMediaTime()
            }
            wasFollowing = parent.following
            if parent.overviewToken != shownOverview {
                shownOverview = parent.overviewToken
                overview(map)
            }
        }

        private func applyStyle(_ map: MKMapView) {
            let config: MKMapConfiguration
            switch parent.style {
            case .guide:
                let s = MKStandardMapConfiguration(elevationStyle: .realistic, emphasisStyle: .muted)
                s.pointOfInterestFilter = .excludingAll; s.showsTraffic = false
                config = s
            case .classic:
                let s = MKStandardMapConfiguration(elevationStyle: .flat)
                s.pointOfInterestFilter = .excludingAll; s.showsTraffic = true
                config = s
            case .satellite:
                let s = MKHybridMapConfiguration(elevationStyle: .realistic)
                s.pointOfInterestFilter = .excludingAll; s.showsTraffic = true
                config = s
            case .night:
                let s = MKStandardMapConfiguration(elevationStyle: .realistic, emphasisStyle: .muted)
                s.pointOfInterestFilter = .excludingAll; s.showsTraffic = true
                config = s
            }
            map.preferredConfiguration = config
            map.overrideUserInterfaceStyle = parent.style == .night ? .dark : (parent.colorScheme == .dark ? .dark : .light)
        }

        /// Percorso nuovo (o vista diversa): linee, zone, ingressi, semafori e destinazione, una volta sola
        private func rebuildRoute(_ map: MKMapView) {
            shownRoute = parent.routeVersion
            map.removeOverlays(lines + zones)
            lines = []; zones = []; renderers = [:]
            map.removeAnnotations(entries + Array(signals.values) + [destination].compactMap { $0 })
            entries = []; signals = [:]; destination = nil
            shownFraction = -1; shownSignalsAt = -1_000

            let drive = parent.drive
            addZones(map)
            let coords = drive.path.map(\.cl)
            if coords.count > 1 {
                for role in [LineRole.travelled, .edge, .fill, .shine] {
                    let l = RouteLine(coordinates: coords, count: coords.count)
                    l.role = role
                    lines.append(l)
                }
                map.addOverlays(lines, level: .aboveRoads)
                var cum = [0.0]
                for (a, b) in zip(coords, coords.dropFirst()) {
                    cum.append(cum[cum.count - 1] + MKMapPoint(a).distance(to: MKMapPoint(b)))
                }
                mapCum = cum
            } else {
                mapCum = []
            }
            for c in drive.crossings {
                guard let e = c.entry else { continue }
                let a = EntryAnnotation()
                a.coordinate = e.cl; a.zone = c.zone
                entries.append(a)
            }
            map.addAnnotations(entries)
            if let d = drive.destination {
                let a = DestinationAnnotation()
                a.coordinate = d.location.cl; a.title = d.name
                destination = a
                map.addAnnotation(a)
            }
            maneuverKey = ""
            updateManeuver(map)
        }

        private func addZones(_ map: MKMapView) {
            map.removeOverlays(zones)
            zones = parent.drive.crossings.map { c in
                let coords = MapShapes.coords(c.zone, parent.store, bucket: shownBucket)
                let z = ZoneShape(coordinates: coords, count: coords.count)
                z.zone = c.zone
                return z
            }
            for z in zones { map.insertOverlay(z, at: 0, level: .aboveRoads) }
        }

        private func updateManeuver(_ map: MKMapView) {
            let key = parent.maneuver.map { "\($0.lat),\($0.lon)|\(parent.maneuverSymbol)" } ?? ""
            guard key != maneuverKey else { return }
            maneuverKey = key
            if maneuverShown { map.removeAnnotation(maneuver); maneuverShown = false }
            if let m = parent.maneuver {
                maneuver.coordinate = m.cl
                map.addAnnotation(maneuver)
                maneuverShown = true
            }
        }

        private func overview(_ map: MKMapView) {
            guard let r = MapScreen.region(parent.drive.path) else { return }
            blendFrom = nil
            let size = map.bounds.size
            let w = r.span.longitudeDelta * 111_000 * cos(r.center.latitude * .pi / 180)
            let h = r.span.latitudeDelta * 111_000
            let aspect: Double = size.height > 0 ? Double(size.width / size.height) : 0.5
            // La distanza della camera è circa tre volte la larghezza visibile (vedi MapDetail)
            let distance = max(w, h * aspect) * 3 * 1.25
            let cam = MKMapCamera(lookingAtCenter: r.center, fromDistance: distance, pitch: 0, heading: 0)
            map.setCamera(cam, animated: true)
        }

        // MARK: A ogni fotogramma

        func tick() {
            guard let map else { return }
            let now = CACurrentMediaTime()
            let dt = lastTick == 0 ? 1.0 / 60 : min(0.2, now - lastTick)
            lastTick = now
            let drive = parent.drive
            guard let pose = drive.displayPose(at: now) else { return }
            vehicle.coordinate = pose.coordinate.cl

            if parent.following {
                let (base, pitch): (Double, Double) = switch parent.style {
                case .guide: (240, 68)
                case .classic: (420, 45)
                case .satellite, .night: (380, 55)
                }
                // Più lontana quando vai veloce; distanza, inclinazione e direzione si avvicinano piano (niente scatti)
                let target = min(1_100, max(base, base * 0.85 + drive.speed * 8))
                if camDistance == 0 { camDistance = target; camPitch = pitch; camHeading = pose.heading }
                camDistance += (target - camDistance) * (1 - exp(-dt / 1.2))
                camPitch += (pitch - camPitch) * (1 - exp(-dt / 0.5))
                camHeading = Heading.smooth(camHeading, toward: pose.heading, dt: dt, tau: 0.25)
                // La camera guarda un po' più avanti dell'auto, così si vede la strada che arriva
                var center = PathMath.offset(pose.coordinate, meters: camDistance * 0.18, bearing: camHeading).cl
                var distance = camDistance, heading = camHeading, tilt = camPitch
                if let b = blendFrom {
                    let u = min(1, (now - blendStart) / 0.6)
                    let e = u * u * (3 - 2 * u)
                    center = CLLocationCoordinate2D(latitude: b.center.latitude + (center.latitude - b.center.latitude) * e,
                                                    longitude: b.center.longitude + (center.longitude - b.center.longitude) * e)
                    distance = b.distance + (distance - b.distance) * e
                    heading = Heading.lerp(b.heading, heading, e)
                    tilt = b.pitch + (tilt - b.pitch) * e
                    if u >= 1 { blendFrom = nil }
                }
                camera.centerCoordinate = center
                camera.centerCoordinateDistance = distance
                camera.heading = heading
                camera.pitch = tilt
                map.setCamera(camera, animated: false)
            }
            // L'auto girata nella direzione di marcia rispetto alla mappa
            let angle = Heading.delta(Double(map.camera.heading), pose.heading) * .pi / 180
            vehicleView?.inner.transform = CGAffineTransform(rotationAngle: CGFloat(angle))

            updateTravelled(along: pose.along ?? drive.done)
            if abs(drive.done - shownSignalsAt) > 25 { updateSignals(map, done: drive.done) }
        }

        /// Il tratto già fatto: grigio fino all'auto, colorato da lì in poi (ogni 6 m, senza ricreare le linee)
        private func updateTravelled(along: Double) {
            let track = parent.drive.track
            guard mapCum.count == track.points.count, mapCum.count > 1, let total = mapCum.last, total > 0 else { return }
            let (i, t) = track.segment(atAlong: along)
            let f = max(0, min(1, (mapCum[i] + (mapCum[i + 1] - mapCum[i]) * t) / total))
            guard abs(f - shownFraction) * track.length > 6 || (f >= 1 && shownFraction < 1) else { return }
            shownFraction = f
            for (role, r) in renderers {
                if role == .travelled { r.strokeEnd = f } else { r.strokeStart = f }
                r.setNeedsDisplay()
            }
        }

        /// I semafori davanti, entro 900 m: si aggiungono e tolgono solo quelli che cambiano
        private func updateSignals(_ map: MKMapView, done: Double) {
            shownSignalsAt = done
            var want = Set<Int>()
            for (i, s) in parent.drive.signals.enumerated() where s.along > done + 5 && s.along < done + 900 { want.insert(i) }
            let gone = signals.keys.filter { !want.contains($0) }
            map.removeAnnotations(gone.compactMap { signals.removeValue(forKey: $0) })
            var added: [SignalAnnotation] = []
            for i in want where signals[i] == nil {
                let s = parent.drive.signals[i]
                let a = SignalAnnotation()
                a.coordinate = s.point.cl; a.along = s.along; a.key = i
                signals[i] = a
                added.append(a)
            }
            map.addAnnotations(added)
        }

        // MARK: Delegato della mappa

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Allontanando la mappa con le dita i perimetri si semplificano (come nella mappa principale)
            let b = MapDetail.bucket(for: mapView.camera.centerCoordinateDistance)
            if b != shownBucket { shownBucket = b; addZones(mapView) }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let l = overlay as? RouteLine {
                let r = MKPolylineRenderer(polyline: l)
                let guide = parent.style == .guide
                let wide: CGFloat = guide ? 18 : 10
                r.lineCap = .round; r.lineJoin = .round
                switch l.role {
                case .travelled:
                    r.strokeColor = UIColor(Color(hex: 0x9AA3AE).opacity(0.75)); r.lineWidth = 7
                    r.strokeEnd = max(0, shownFraction)
                case .edge:
                    r.strokeColor = UIColor(Color(hex: guide ? 0x0A7A44 : 0x0B2F73).opacity(0.95)); r.lineWidth = wide + 6
                case .fill:
                    r.strokeColor = UIColor(Color(hex: guide ? 0x1ED67F : 0x2F7BFF)); r.lineWidth = wide
                case .shine:
                    r.strokeColor = UIColor(Color(hex: guide ? 0xC8FFE2 : 0x9CCBFF).opacity(0.6)); r.lineWidth = max(2, wide * 0.22)
                }
                if l.role != .travelled { r.strokeStart = max(0, shownFraction) }
                renderers[l.role] = r
                return r
            }
            if let z = overlay as? ZoneShape, let zone = z.zone {
                let r = MKPolygonRenderer(polygon: z)
                let green = zone.type == .green
                r.fillColor = UIColor(zone.type.color.opacity(green ? 0.18 : 0.14))
                r.strokeColor = UIColor(zone.type.color)
                r.lineWidth = green ? 4 : 2.5
                if !green { r.lineDashPattern = [8, 5] }
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            switch annotation {
            case is VehicleAnnotation:
                let v = VehicleView(annotation: annotation, reuseIdentifier: nil)
                if let vehicleImage { v.set(vehicleImage) }
                vehicleView = v
                return v
            case is SignalAnnotation:
                let compact = parent.style != .guide
                let v = imageView(annotation, id: "signal", image: cached("signal|\(compact)") { TrafficLightView(compact: compact) })
                v.centerOffset = CGPoint(x: 0, y: -(v.image?.size.height ?? 0) / 2)
                return v
            case let a as EntryAnnotation:
                guard let zone = a.zone else { return nil }
                return imageView(annotation, id: "entry", image: cached("entry|\(zone.type.rawValue)") {
                    Image(systemName: zone.type.symbol).font(.app(size: 11, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 26, height: 26).background(zone.type.color, in: Circle())
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                })
            case is ManeuverAnnotation:
                let symbol = parent.maneuverSymbol
                let v = imageView(annotation, id: "maneuver", image: cached("maneuver|\(symbol)") {
                    Image(systemName: symbol)
                        .font(.app(size: 16, weight: .heavy)).foregroundStyle(Color(hex: 0x1D4FA8))
                        .frame(width: 34, height: 34).background(.white, in: Circle())
                        .overlay(Circle().stroke(Color(hex: 0x2F7BFF), lineWidth: 3))
                        .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                        .padding(4)
                })
                v.zPriority = .defaultSelected
                return v
            case is DestinationAnnotation:
                let v = mapView.dequeueReusableAnnotationView(withIdentifier: "destination") as? MKMarkerAnnotationView
                    ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "destination")
                v.annotation = annotation
                v.glyphImage = UIImage(systemName: "flag.checkered")
                v.markerTintColor = UIColor(Theme.red)
                v.displayPriority = .required
                return v
            default:
                return nil
            }
        }

        private func imageView(_ annotation: MKAnnotation, id: String, image: UIImage?) -> MKAnnotationView {
            let v = map?.dequeueReusableAnnotationView(withIdentifier: id) ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id)
            v.annotation = annotation
            v.image = image
            v.canShowCallout = false
            v.isEnabled = false
            v.displayPriority = .required
            v.collisionMode = .none
            return v
        }

        private func cached<V: View>(_ key: String, _ content: () -> V) -> UIImage? {
            if let i = images[key] { return i }
            let i = render(content())
            images[key] = i
            return i
        }

        private func render<V: View>(_ view: V) -> UIImage? {
            let r = ImageRenderer(content: view.environment(\.colorScheme, .light))
            r.scale = UIScreen.main.scale
            return r.uiImage
        }
    }

    /// Il display link tiene forte il suo bersaglio: in mezzo un oggetto debole, così la mappa si libera
    private final class LinkProxy: NSObject {
        weak var target: Coordinator?
        init(_ t: Coordinator) { target = t }
        @objc func tick(_ link: CADisplayLink) {
            MainActor.assumeIsolated {
                if let target { target.tick() } else { link.invalidate() }
            }
        }
    }
}
