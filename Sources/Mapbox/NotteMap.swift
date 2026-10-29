import CoreLocation
import MapboxMaps
import SwiftUI
import UIKit

// Mapbox (v11) per la nuova presentazione e per l'anteprima della prima pagina 2.0: lo stile Standard al crepuscolo
// con gli edifici e i monumenti in 3D (il Duomo di Firenze compreso), senza punti d'interesse e fermate, portato nei
// colori «Notte» con la tabella NotteLUT (Tools/notte_lut.py). Provato prima con Mapbox GL JS nello stesso stile.
// Il token pubblico è MBXAccessToken nell'Info.plist (project.yml). Se lo stile non arriva (niente rete, errore),
// chi usa queste mappe torna alla mappa di Apple o al disegno di riserva.

enum NotteMap {
    /// C'è il token pubblico di Mapbox nell'Info.plist (MBXAccessToken)? Senza, si usa subito la mappa di Apple
    static var hasToken: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "MBXAccessToken") as? String)?.hasPrefix("pk.") == true
    }

    /// Lo stile: crepuscolo (ombre lunghe, finestre accese) o notte; strade scure come canali, solo i nomi dei quartieri.
    /// «standardBuildings» false: niente edifici né alberi 3D di Standard (restano i monumenti), per mettere sopra i propri
    /// edifici trasparenti (addBuildings)
    static func style(light: StandardLightPreset = .dusk, standardBuildings: Bool = true) -> MapStyle {
        .standard(
            theme: .custom,
            lightPreset: light,
            showPointOfInterestLabels: false,
            showTransitLabels: false,
            showPlaceLabels: true,
            showRoadLabels: false,
            show3dObjects: true,
            colorMotorways: StyleColor(UIColor(red: 0x4A / 255, green: 0x50 / 255, blue: 0x70 / 255, alpha: 1)),
            colorRoads: StyleColor(UIColor(red: 0x3A / 255, green: 0x3F / 255, blue: 0x55 / 255, alpha: 1)),
            colorTrunks: StyleColor(UIColor(red: 0x40 / 255, green: 0x46 / 255, blue: 0x5E / 255, alpha: 1)),
            show3dBuildings: standardBuildings,
            show3dLandmarks: true,
            show3dTrees: standardBuildings ? nil : false,
            showAdminBoundaries: false,
            showLandmarkIcons: false,
            themeData: NotteLUT.base64)
    }

    /// Il giorno (prima pagina della presentazione): lo Standard chiaro con i suoi colori, senza la tabella «Notte»
    static func dayStyle(standardBuildings: Bool = true) -> MapStyle {
        .standard(
            theme: .default,
            lightPreset: .day,
            showPointOfInterestLabels: false,
            showTransitLabels: false,
            showPlaceLabels: true,
            showRoadLabels: false,
            show3dObjects: true,
            show3dBuildings: standardBuildings,
            show3dLandmarks: true,
            show3dTrees: standardBuildings ? nil : false,
            showAdminBoundaries: false,
            showLandmarkIcons: false)
    }

    /// Dal giorno alla sera senza ricaricare lo stile: crepuscolo e colori «Notte», come style()
    static func setEvening(_ map: MapboxMap) {
        try? map.setStyleImportConfigProperties(for: "basemap", configs: [
            "theme": "custom", "theme-data": NotteLUT.base64, "lightPreset": "dusk",
            "colorMotorways": "#4A5070", "colorRoads": "#3A3F55", "colorTrunks": "#40465E",
        ])
    }

    static func uiColor(_ hex: UInt32, _ alpha: CGFloat = 1) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }

    static func color(_ hex: UInt32) -> StyleColor { StyleColor(uiColor(hex)) }

    /// La mappa senza gesti (si guarda soltanto) e senza bussola né scala. Il logo e l'attribuzione di Mapbox devono restare
    /// visibili (condizioni di Mapbox): «ornamentBottom» li alza sopra ciò che la pagina mette in basso sulla mappa
    static func configure(_ mapView: MapView, interactive: Bool = false, ornamentBottom: CGFloat = 8) {
        mapView.ornaments.options.scaleBar.visibility = .hidden
        mapView.ornaments.options.compass.visibility = .hidden
        setOrnamentBottom(mapView, ornamentBottom)
        setGestures(mapView, on: interactive)
        mapView.backgroundColor = UIColor(red: 0x0B / 255, green: 0x15 / 255, blue: 0x30 / 255, alpha: 1)
    }

    /// Il logo (in basso a sinistra) e il pulsante dell'attribuzione (in basso a destra) a «bottom» punti dal fondo sicuro
    static func setOrnamentBottom(_ mapView: MapView, _ bottom: CGFloat) {
        guard mapView.ornaments.options.logo.margins.y != bottom else { return }
        mapView.ornaments.options.logo.position = .bottomLeading
        mapView.ornaments.options.logo.margins = CGPoint(x: 10, y: bottom)
        mapView.ornaments.options.attributionButton.position = .bottomTrailing
        mapView.ornaments.options.attributionButton.margins = CGPoint(x: 10, y: bottom)
    }

    static func setGestures(_ mapView: MapView, on: Bool) {
        mapView.gestures.options.panEnabled = on
        mapView.gestures.options.pinchEnabled = on
        mapView.gestures.options.rotateEnabled = on
        mapView.gestures.options.pitchEnabled = on
        mapView.gestures.options.doubleTapToZoomInEnabled = on
        mapView.gestures.options.doubleTouchToZoomOutEnabled = on
        mapView.gestures.options.quickZoomEnabled = on
    }

    // MARK: Zone e percorsi

    /// Una zona: velatura rossa sotto gli edifici, bordo acceso con l'alone sopra tutto (slot «top» di Standard)
    static func addZone(_ map: MapboxMap, id: String, rings: [[CLLocationCoordinate2D]], fill: Double = 0.12, hex: UInt32 = 0xFF4D3D) {
        let polygons = rings.filter { $0.count > 2 }.map { Polygon([$0 + [$0[0]]]) }
        guard !polygons.isEmpty else { return }
        var source = GeoJSONSource(id: id)
        source.data = .geometry(.multiPolygon(MultiPolygon(polygons)))
        var fillLayer = FillLayer(id: id + "-fill", source: id)
        fillLayer.slot = .middle
        fillLayer.fillColor = .constant(color(hex))
        fillLayer.fillOpacity = .constant(fill)
        fillLayer.fillEmissiveStrength = .constant(1)
        var glow = LineLayer(id: id + "-glow", source: id)
        glow.slot = .top
        glow.lineColor = .constant(color(hex))
        glow.lineWidth = .constant(14)
        glow.lineBlur = .constant(12)
        glow.lineOpacity = .constant(0.55)
        glow.lineEmissiveStrength = .constant(1)
        var edge = LineLayer(id: id + "-edge", source: id)
        edge.slot = .top
        edge.lineColor = .constant(color(0xFF6A5C))
        edge.lineWidth = .constant(2.2)
        edge.lineOpacity = .constant(0.95)
        edge.lineEmissiveStrength = .constant(1)
        try? map.addSource(source)
        try? map.addLayer(fillLayer)
        try? map.addLayer(glow)
        try? map.addLayer(edge)
    }

    /// Le zone con lo stile della Mappa (MapTheme, toni scuri: lo stile Notte è sempre scuro): riempimento nel colore della
    /// risposta, righe a 45° (fill-pattern) se la ZTL è attiva, alone e bordo tratteggiato (dasharray in unità di spessore:
    /// 5/4 punti a 2 punti di spessore)
    static func addAnswerZones(_ map: MapboxMap, id: String, rings: [[CLLocationCoordinate2D]], access: Access, active: Bool) {
        let polygons = rings.filter { $0.count > 2 }.map { Polygon([$0 + [$0[0]]]) }
        guard !polygons.isEmpty else { return }
        let tone = MapTheme.tone(access)
        var source = GeoJSONSource(id: id)
        source.data = .geometry(.multiPolygon(MultiPolygon(polygons)))
        try? map.addSource(source)
        var fillLayer = FillLayer(id: id + "-fill", source: id)
        fillLayer.slot = .middle
        fillLayer.fillColor = .constant(color(tone.fillHex(dark: true)))
        fillLayer.fillOpacity = .constant(MapTheme.fillOpacity(access, dark: true) + 0.04)
        fillLayer.fillEmissiveStrength = .constant(1)
        try? map.addLayer(fillLayer)
        if active {
            let image = "hatch-\(access)"
            if !map.imageExists(withId: image) { try? map.addImage(hatchImage(tone.lineHex(dark: true)), id: image) }
            var hatch = FillLayer(id: id + "-hatch", source: id)
            hatch.slot = .middle
            hatch.fillPattern = .constant(.name(image))
            hatch.fillEmissiveStrength = .constant(1)
            try? map.addLayer(hatch)
        }
        var halo = LineLayer(id: id + "-halo", source: id)
        halo.slot = .top
        halo.lineColor = .constant(color(0x0B1530))
        halo.lineWidth = .constant(5)
        halo.lineOpacity = .constant(0.4)
        halo.lineEmissiveStrength = .constant(1)
        try? map.addLayer(halo)
        var edge = LineLayer(id: id + "-edge", source: id)
        edge.slot = .top
        edge.lineCap = .constant(.round)
        edge.lineJoin = .constant(.round)
        edge.lineColor = .constant(color(tone.lineHex(dark: true)))
        edge.lineWidth = .constant(2)
        edge.lineDasharray = .constant(MapTheme.dash(access).map { Double($0) / 2 })
        edge.lineOpacity = .constant(access == .off ? 0.7 : 0.9)
        edge.lineEmissiveStrength = .constant(1)
        try? map.addLayer(edge)
    }

    static func removeAnswerZones(_ map: MapboxMap, id: String) {
        for layer in ["-fill", "-hatch", "-halo", "-edge"] { try? map.removeLayer(withId: id + layer) }
        try? map.removeSource(withId: id)
    }

    /// Il motivo delle righe a 45°: righe da 1 punto ogni MapTheme.hatchPitch punti, nel colore del bordo
    static func hatchImage(_ hex: UInt32) -> UIImage {
        let t = (MapTheme.hatchPitch * 2.0.squareRoot()).rounded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        return UIGraphicsImageRenderer(size: CGSize(width: t, height: t), format: format).image { ctx in
            let g = ctx.cgContext
            g.setStrokeColor(uiColor(hex, CGFloat(MapTheme.hatchOpacity(dark: true))).cgColor)
            g.setLineWidth(1)
            g.setLineCap(.square)
            for o in [-t, 0, t] {
                g.move(to: CGPoint(x: o, y: t)); g.addLine(to: CGPoint(x: o + t, y: 0))
            }
            g.strokePath()
        }
    }

    /// Gli edifici 3D trasparenti (Tools/intro_buildings.py, edifici OpenStreetMap uniti in blocchi della stessa altezza):
    /// tutti uguali, grigio-blu che schiarisce verso l'alto, al 40%, così l'auto, i percorsi e la zona si vedono anche
    /// dietro e attraverso. Senza luci e ombre dello stile (emissive 1), con appena un'ombra nei punti di contatto.
    /// Stessi valori del prototipo con Mapbox GL JS.
    static func addBuildings(_ map: MapboxMap, id: String = "buildings", geojson: String) {
        var source = GeoJSONSource(id: id)
        source.data = .string(geojson)
        var layer = FillExtrusionLayer(id: id + "-3d", source: id)
        layer.slot = .middle
        let h = Exp(.get) { "h" }
        layer.fillExtrusionColor = .expression(Exp(.interpolate) {
            Exp(.linear)
            h
            0
            uiColor(0x4F5B80)
            40
            uiColor(0xC3CBE6)
        })
        layer.fillExtrusionHeight = .expression(h)
        layer.fillExtrusionBase = .constant(0)
        layer.fillExtrusionOpacity = .constant(0.4)
        layer.fillExtrusionVerticalGradient = .constant(true)
        layer.fillExtrusionAmbientOcclusionIntensity = .constant(0.3)
        layer.fillExtrusionAmbientOcclusionRadius = .constant(3)
        layer.fillExtrusionEmissiveStrength = .constant(1)
        layer.fillExtrusionCastShadows = .constant(false)
        layer.fillExtrusionCutoffFadeRange = .constant(0)
        try? map.addSource(source)
        try? map.addLayer(layer)
    }

    /// Una linea a puntini (il tratto a piedi), che si allunga con setWalk
    static func addWalk(_ map: MapboxMap, id: String, hex: UInt32 = 0xFFFFFF) {
        var source = GeoJSONSource(id: id)
        source.data = .geometry(.lineString(LineString([])))
        var layer = LineLayer(id: id + "-dots", source: id)
        layer.slot = .top
        layer.lineCap = .constant(.round)
        layer.lineJoin = .constant(.round)
        layer.lineColor = .constant(color(hex))
        layer.lineWidth = .constant(5)
        layer.lineDasharray = .constant([0, 2])
        layer.lineEmissiveStrength = .constant(1)
        try? map.addSource(source)
        try? map.addLayer(layer)
    }

    static func setWalk(_ map: MapboxMap, id: String, coordinates: [CLLocationCoordinate2D]) {
        map.updateGeoJSONSource(withId: id, geoJSON: .geometry(.lineString(LineString(coordinates.count > 1 ? coordinates : []))))
    }

    /// Un percorso che si disegna da sé: alone sfocato e linea piena, accorciati con line-trim-offset (serve lineMetrics)
    static func addRoute(_ map: MapboxMap, id: String, coordinates: [CLLocationCoordinate2D], glowHex: UInt32, coreHex: UInt32) {
        var source = GeoJSONSource(id: id)
        source.data = .geometry(.lineString(LineString(coordinates)))
        source.lineMetrics = true
        try? map.addSource(source)
        for (suffix, width, blur, opacity, hex) in [("-glow", 18.0, 14.0, 0.7, glowHex), ("-core", 5.0, 0.0, 1.0, coreHex)] {
            var layer = LineLayer(id: id + suffix, source: id)
            layer.slot = .top
            layer.lineCap = .constant(.round)
            layer.lineJoin = .constant(.round)
            layer.lineColor = .constant(color(hex))
            layer.lineWidth = .constant(width)
            layer.lineBlur = .constant(blur)
            layer.lineOpacity = .constant(opacity)
            layer.lineEmissiveStrength = .constant(1)
            layer.lineTrimOffset = .constant([0, 1])
            try? map.addLayer(layer)
        }
    }

    /// Quanto del percorso si vede (0…1) e con che opacità
    static func setRoute(_ map: MapboxMap, id: String, progress: Double, opacity: Double) {
        let p = min(max(progress, 0), 1)
        let visible = p > 0.001 && opacity > 0.01
        try? map.setLayerProperty(for: id + "-core", property: "line-trim-offset", value: [visible ? p : 0, 1])
        try? map.setLayerProperty(for: id + "-glow", property: "line-trim-offset", value: [visible ? p : 0, 1])
        try? map.setLayerProperty(for: id + "-core", property: "line-opacity", value: visible ? opacity : 0)
        try? map.setLayerProperty(for: id + "-glow", property: "line-opacity", value: visible ? opacity * 0.7 : 0)
    }
}

/// Una vista SwiftUI dentro una vista annotazione di Mapbox, con una misura fissa (Mapbox la legge con l'AutoLayout).
/// «content» è la vista ospitata: si può girare con transform senza toccare la cornice che muove Mapbox.
final class HostedAnnotationView: UIView {
    let content: UIView
    private let host: UIHostingController<AnyView>

    init<V: View>(size: CGSize, @ViewBuilder _ view: () -> V) {
        host = UIHostingController(rootView: AnyView(view()))
        content = host.view
        super.init(frame: CGRect(origin: .zero, size: size))
        content.backgroundColor = .clear
        backgroundColor = .clear
        isUserInteractionEnabled = false
        content.bounds = CGRect(origin: .zero, size: size)
        content.center = CGPoint(x: size.width / 2, y: size.height / 2)
        addSubview(content)
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([widthAnchor.constraint(equalToConstant: size.width),
                                     heightAnchor.constraint(equalToConstant: size.height)])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) non usato") }

    override func layoutSubviews() {
        super.layoutSubviews()
        content.center = CGPoint(x: bounds.midX, y: bounds.midY)
    }
}

extension CLLocationCoordinate2D {
    /// La direzione da qui a «to», in gradi da nord (come il bearing della camera)
    func notteBearing(to b: CLLocationCoordinate2D) -> Double {
        let k = cos(latitude * .pi / 180)
        let deg = atan2((b.longitude - longitude) * k, b.latitude - latitude) * 180 / .pi
        return (deg + 360).truncatingRemainder(dividingBy: 360)
    }
}
