import SwiftUI
import MapKit
import CoreLocation

// «Modalità prova»: la parte con le mappe (i varchi sulle strade vere), la striscia «Modalità prova attiva» che si vede
// ovunque e la sezione di Impostazioni. La zona e le regole sono in TestZone.swift.

/// Costruisce la zona di prova intorno a un punto: i varchi dove una strada vera entra nel perimetro (indicazioni
/// in auto di Apple da 350 m fuori verso il centro), il nome della via e il parcheggio finto su una strada fuori
@MainActor
enum TestModeBuilder {
    static func build(at center: Coordinate, active: Bool) async -> TestModeState {
        // Nel giro delle foto niente rete: i varchi restano sul bordo
        if ProcessInfo.processInfo.arguments.contains("-uitest") { return TestZone.make(at: center, active: active) }
        let ring = TestZone.perimeter(around: center)
        var gates: [Gate] = []
        for (i, b) in TestZone.gateBearings.enumerated() {
            let from = TestZone.offset(center, meters: TestZone.radius + 350, bearing: b)
            var spot = TestZone.offset(center, meters: TestZone.radius, bearing: b)
            if let path = await drive(from: from, to: center),
               let entry = TestZone.entry(on: RouteCheck.densify(path, step: 8), perimeter: ring) {
                spot = entry
            }
            // Due strade che entrano dallo stesso punto: basta un varco
            if gates.contains(where: { TestZone.meters($0.location, spot) < 60 }) { continue }
            let street = await streetName(at: spot)
            gates.append(Gate(id: "prova-\(gates.count + 1)", name: TestZone.gateName(gates.count + 1, street: street), location: spot))
        }
        // Il parcheggio: dove arriva la strada verso il punto a sud-est, se resta fuori dalla zona
        var parking = TestZone.offset(center, meters: TestZone.parkingDistance, bearing: TestZone.parkingBearing)
        if let path = await drive(from: center, to: parking), let end = path.last,
           !Zone.inside(ring, lat: end.lat, lon: end.lon), TestZone.meters(end, parking) < 200 {
            parking = end
        }
        return TestZone.make(at: center, gates: gates, parking: parking, active: active)
    }

    private static func drive(from a: Coordinate, to b: Coordinate) async -> [Coordinate]? {
        let r = MKDirections.Request()
        r.source = MKMapItem(placemark: MKPlacemark(coordinate: a.cl))
        r.destination = MKMapItem(placemark: MKPlacemark(coordinate: b.cl))
        r.transportType = .automobile
        guard let route = try? await MKDirections(request: r).calculate().routes.first else { return nil }
        return route.polyline.coordinates.map { Coordinate(lat: $0.latitude, lon: $0.longitude) }
    }

    private static func streetName(at c: Coordinate) async -> String? {
        let mark = try? await CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: c.lat, longitude: c.lon)).first
        return mark?.thoroughfare
    }

    /// Dove sei adesso: la posizione degli avvisi, o l'ultima nota a iOS
    static func currentPosition() -> Coordinate? {
        guard let here = GateMonitor.shared.location ?? CLLocationManager().location else { return nil }
        return Coordinate(lat: here.coordinate.latitude, lon: here.coordinate.longitude)
    }
}

extension Store {
    /// Accende la modalità prova (o sposta la zona) intorno a dove sei; false se la posizione non c'è
    @discardableResult
    func startTestMode(active: Bool? = nil) async -> Bool {
        guard let here = TestModeBuilder.currentPosition() else { return false }
        let state = await TestModeBuilder.build(at: here, active: active ?? testMode?.active ?? true)
        testMode = state
        // La zona appena fatta diventa quella scelta: Varco e Mappa la mostrano subito
        cityId = TestZone.cityId
        zoneId = TestZone.zoneId
        // I cerchi degli avvisi seguono i varchi di prova
        GateMonitor.shared.settingsChanged()
        return true
    }

    func stopTestMode() {
        testMode = nil
        GateMonitor.shared.settingsChanged()
    }

    func setTestZoneActive(_ on: Bool) { testMode?.active = on }
}

/// La striscia viola «Modalità prova attiva», in cima a ogni schermata finché la modalità è accesa: stato della zona,
/// «Sposta la zona qui», accendi/spegni i varchi e l'uscita veloce
struct TestModeBar: View {
    @EnvironmentObject var store: Store
    @State private var moving = false

    static let tint = Color(hex: 0x6B3FA0)

    var body: some View {
        if let state = store.testMode {
            HStack(spacing: 10) {
                Image(systemName: "testtube.2").font(.app(size: 15, weight: .bold)).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Test mode on").font(.app(size: 14, weight: .bold)).lineLimit(1)
                    Text(state.active ? L("Test ZTL active now") : L("Test ZTL off"))
                        .font(.app(size: 12)).opacity(0.9).lineLimit(1)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("testmode.banner")
                Spacer(minLength: 4)
                if moving { ProgressView().tint(.white) }
                Menu {
                    Button { store.setTestZoneActive(!state.active) } label: {
                        if state.active {
                            Label("Turn the test ZTL off", systemImage: "lightswitch.off")
                        } else {
                            Label("Turn the test ZTL on", systemImage: "lightswitch.on")
                        }
                    }
                    Button {
                        Task { moving = true; await store.startTestMode(); moving = false }
                    } label: { Label(L("Move the zone here"), systemImage: "location.viewfinder") }
                } label: {
                    Image(systemName: "ellipsis.circle").font(.app(size: 20, weight: .semibold))
                        .frame(width: 36, height: 36).contentShape(Rectangle())
                }
                .accessibilityLabel(L("Test mode options"))
                .accessibilityIdentifier("testmode.menu")
                Button { withAnimation(.snappy) { store.stopTestMode() } } label: {
                    Text("Turn off").font(.app(size: 13, weight: .bold))
                        .padding(.horizontal, 10).frame(height: 30)
                        .background(.white.opacity(0.22), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("Turn off test mode"))
                .accessibilityIdentifier("testmode.off")
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14).padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(Self.tint)
            .environment(\.colorScheme, .dark)
        }
    }
}

extension View {
    /// La striscia della modalità prova sopra il contenuto (solo quando è accesa)
    func testModeBar() -> some View {
        safeAreaInset(edge: .top, spacing: 0) { TestModeBar() }
    }
}

/// Impostazioni → «Modalità prova»
struct TestModeSection: View {
    @EnvironmentObject var store: Store
    @State private var working = false
    @State private var noPosition = false

    var body: some View {
        Section {
            Toggle(isOn: Binding(get: { store.testMode != nil }, set: { on in
                if on { start() } else { store.stopTestMode() }
            })) {
                Label("Test mode", systemImage: "testtube.2")
            }
            .disabled(working)
            .accessibilityIdentifier("settings.testmode")
            if working {
                HStack { ProgressView(); Text("Looking for the roads around you…").foregroundStyle(Theme.muted) }
            }
            if noPosition {
                Text("Your position isn't available. Allow location access and try again.")
                    .font(.app(size: 13)).foregroundStyle(Theme.red)
            }
            if let state = store.testMode {
                Picker(L("Test ZTL"), selection: Binding(get: { state.active }, set: { store.setTestZoneActive($0) })) {
                    Text("Active now").tag(true)
                    Text("Off").tag(false)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel(L("Test ZTL"))
                Button { start() } label: { Label("Move the zone here", systemImage: "location.viewfinder") }
                    .disabled(working)
                ForEach(state.gates) { g in
                    Label(g.name, systemImage: "video.fill").font(.app(size: 14)).foregroundStyle(Theme.muted)
                }
                Label(L("Test car park"), systemImage: "parkingsign").font(.app(size: 14)).foregroundStyle(Theme.muted)
            }
        } header: { Text("Test mode") } footer: {
            Text("Creates a fake ZTL about 400 m wide around you, with 1–2 gates on the nearby roads and a car park outside, to try answers, alerts, navigation and voice without travelling. Only on this phone: never synced or sent. See docs/prova-sul-campo.md.")
        }
    }

    private func start() {
        noPosition = false
        working = true
        Task {
            noPosition = !(await store.startTestMode())
            working = false
        }
    }
}

extension TestZone {
    /// Il parcheggio finto della modalità prova, come un parcheggio di OpenStreetMap («Parcheggia fuori e cammina»)
    @MainActor static func parkingSpot(at center: Coordinate, store: Store) -> ParkingSpot {
        let p = store.testMode?.parking ?? offset(center, meters: parkingDistance, bearing: parkingBearing)
        return ParkingSpot(id: parkingId, name: L("Test car park"), lat: p.lat, lon: p.lon, kind: "surface", fee: "no", hours: "24/7")
    }
}

/// La scritta sulla mappa sopra la zona di prova
struct TestZoneMapLabel: View {
    var active: Bool
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "testtube.2").font(.system(size: 11, weight: .bold))
            Text(L("TEST ZONE")).font(.app(size: 12, weight: .heavy)).kerning(0.8)
            Text(active ? L("active") : L("off")).font(.app(size: 11, weight: .semibold)).opacity(0.85)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 9).frame(height: 24)
        .background(TestModeBar.tint, in: Capsule())
        .overlay(Capsule().stroke(.white, lineWidth: 1.5))
        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("map.testzone")
    }
}
