import Foundation
import MapKit
import UIKit
import SwiftUI

/// Il percorso fino alla destinazione con le mappe Apple, il controllo ZTL lungo la strada
/// e, se la destinazione è vietata, il parcheggio fuori zona più vicino.
struct RoutePlan: Equatable {
    var destination: Place
    var path: [Coordinate]
    var distance: CLLocationDistance
    var travelTime: TimeInterval
    var departure: Date
    var crossings: [RouteCrossing]
    var parking: Place?            // dove lasciare l'auto se non si può entrare
    var walkMeters: Double?        // dal parcheggio alla destinazione, in linea d'aria

    var arrival: Date { departure.addingTimeInterval(travelTime) }
    var worst: RouteCrossing? { RouteCheck.worst(crossings) }
    var blocked: Bool { if case .no = worst?.answer.verdict { true } else { false } }
    /// La destinazione stessa è in una zona dove non si può entrare a quell'ora
    var destinationBlocked: Bool {
        crossings.contains { c in
            guard c.isDestination else { return false }
            if case .no = c.answer.verdict { return true }
            return false
        }
    }
}

@MainActor
final class RoutePlanner: ObservableObject {
    static let shared = RoutePlanner()
    @Published private(set) var plan: RoutePlan?
    @Published private(set) var working = false
    @Published private(set) var error: String?
    /// Il percorso Apple completo (con le istruzioni svolta per svolta), per la navigazione dentro l'app
    private(set) var route: MKRoute?

    func clear() { plan = nil; error = nil; route = nil }

    /// Solo per le foto automatiche: «-uiOrigin 45.4850 9.2040» fa partire il percorso da lì (nel simulatore non c'è il GPS)
    static var testOrigin: CLLocationCoordinate2D? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-uiOrigin"), args.count > i + 2,
              let lat = Double(args[i + 1]), let lon = Double(args[i + 2]) else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// departure: nil = adesso. arrival: se chiesta, si parte in modo da arrivare a quell'ora.
    func plan(to place: Place, from origin: CLLocationCoordinate2D?, arrival wanted: Date?, store: Store) async {
        working = true; error = nil
        defer { working = false }
        let request = MKDirections.Request()
        request.source = origin.map { MKMapItem(placemark: MKPlacemark(coordinate: $0)) } ?? .forCurrentLocation()
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: place.location.cl))
        request.transportType = .automobile
        do {
            guard let route = try await MKDirections(request: request).calculate().routes.first else {
                error = L("No route found."); return
            }
            let raw = route.polyline.coordinates.map { Coordinate(lat: $0.latitude, lon: $0.longitude) }
            let path = RouteCheck.densify(raw)
            let departure = wanted.map { $0.addingTimeInterval(-route.expectedTravelTime) } ?? Date()
            let zones = store.cities.flatMap(\.zones)
            let crossings = RouteCheck.crossings(path: path, zones: zones, departure: departure, travelTime: route.expectedTravelTime) {
                store.answer(at: $1, zone: $0, hotelInside: false)
            }
            var plan = RoutePlan(destination: place, path: raw, distance: route.distance, travelTime: route.expectedTravelTime,
                                 departure: departure, crossings: crossings)
            if plan.destinationBlocked,
               let parking = await Self.parkingOutside(near: place, zones: zones, vehicle: store.vehicle, at: plan.arrival) {
                plan.parking = parking
                plan.walkMeters = Self.meters(parking.location, place.location)
            }
            self.route = route
            self.plan = plan
        } catch {
            self.error = origin == nil ? L("Couldn't find your position. Allow location access to plan the drive.")
                                       : L("Couldn't plan the drive right now. Check your connection.")
        }
    }

    /// Il parcheggio fuori dalle zone vietate o a pagamento più vicino alla destinazione
    static func parkingOutside(near place: Place, zones: [Zone], vehicle: Vehicle, at date: Date) async -> Place? {
        let region = MKCoordinateRegion(center: place.location.cl, latitudinalMeters: 3_000, longitudinalMeters: 3_000)
        let poi = MKLocalPointsOfInterestRequest(coordinateRegion: region)
        poi.pointOfInterestFilter = MKPointOfInterestFilter(including: [.parking])
        var items = (try? await MKLocalSearch(request: poi).start().mapItems) ?? []
        if items.isEmpty {
            let text = MKLocalSearch.Request()
            text.naturalLanguageQuery = "parking"
            text.region = region
            items = (try? await MKLocalSearch(request: text).start().mapItems) ?? []
        }
        let outside = items.compactMap { item -> Place? in
            let c = item.placemark.coordinate
            guard !zones.contains(where: { $0.contains(c) && $0.closes(to: vehicle, at: date) }) else { return nil }
            return Place(name: item.name ?? L("Car park"), address: item.placemark.title ?? "", location: Coordinate(lat: c.latitude, lon: c.longitude))
        }
        return outside.min { meters($0.location, place.location) < meters($1.location, place.location) }
    }

    static func meters(_ a: Coordinate, _ b: Coordinate) -> Double {
        let k = cos(a.lat * .pi / 180)
        return hypot((a.lat - b.lat) * 111_000, (a.lon - b.lon) * 111_000 * k)
    }
}

/// I navigatori: si apre quello che preferisci, con la meta giusta (la destinazione o il parcheggio)
enum Navigator: String, CaseIterable, Identifiable {
    case apple, google, waze
    var id: String { rawValue }
    var title: String {
        switch self {
        case .apple: "Apple Maps"
        case .google: "Google Maps"
        case .waze: "Waze"
        }
    }

    func url(to c: Coordinate) -> URL? {
        switch self {
        case .apple: URL(string: "https://maps.apple.com/?daddr=\(c.lat),\(c.lon)&dirflg=d")
        case .google: URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(c.lat),\(c.lon)&travelmode=driving")
        case .waze: URL(string: "https://waze.com/ul?ll=\(c.lat),\(c.lon)&navigate=yes")
        }
    }

    @MainActor func open(to place: Place) {
        if self == .apple {
            let item = MKMapItem(placemark: MKPlacemark(coordinate: place.location.cl))
            item.name = place.name
            item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
        } else if let url = url(to: place.location) {
            UIApplication.shared.open(url)
        }
    }
}

extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var out = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&out, range: NSRange(location: 0, length: pointCount))
        return out
    }
}

/// Il riepilogo del percorso: tempo, zone attraversate con la risposta al passaggio, parcheggio fuori e navigatori
struct RouteCard: View {
    var plan: RoutePlan
    var onMap: () -> Void
    var onStart: (Place) -> Void = { _ in }

    private var target: Place { plan.destinationBlocked ? (plan.parking ?? plan.destination) : plan.destination }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(VerdictCard.duration(plan.travelTime)).font(Theme.display(28)).foregroundStyle(Theme.ink)
                Text(Measurement(value: plan.distance, unit: UnitLength.meters).formatted(.measurement(width: .abbreviated, usage: .road)))
                    .font(.system(size: 15)).foregroundStyle(Theme.muted)
                Spacer()
                Text(String(format: L("Arrive %@"), plan.arrival.formatted(date: .omitted, time: .shortened)))
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.muted)
            }
            if plan.crossings.isEmpty {
                Label("No ZTL on the way.", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.greenInk)
            } else {
                VStack(spacing: 0) {
                    ForEach(plan.crossings) { c in
                        HStack(spacing: 10) {
                            Image(systemName: c.zone.type.symbol).font(.system(size: 12, weight: .bold))
                                .frame(width: 28, height: 28)
                                .background(c.zone.type.color.opacity(0.16), in: Circle()).foregroundStyle(c.zone.type.color)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(c.zone.shortName).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                                Text(String(format: L(c.isDestination ? "Destination · at %@" : "On the way · at %@"),
                                            c.at.formatted(date: .omitted, time: .shortened)))
                                    .font(.system(size: 12)).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            VerdictPill(verdict: c.answer.verdict)
                        }
                        .padding(.vertical, 7)
                        if c.id != plan.crossings.last?.id { Divider().padding(.leading, 38) }
                    }
                }
            }
            if plan.blocked && !plan.destinationBlocked {
                Label("A zone on the way is active: your navigator may route you through it. Watch the signs and avoid the gates.", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.amberInk)
            }
            if plan.destinationBlocked {
                if let parking = plan.parking {
                    HStack(alignment: .top, spacing: 10) {
                        Text("P").font(.system(size: 15, weight: .heavy)).foregroundStyle(.white)
                            .frame(width: 28, height: 28).background(Theme.blueFill, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: L("Park at %@"), parking.name)).font(.system(size: 15, weight: .semibold))
                            if let m = plan.walkMeters {
                                Text(String(format: L("Outside the ZTL · about %lld min on foot to your destination"), max(1, Int(m * 1.3 / 80))))
                                    .font(.system(size: 13)).foregroundStyle(Theme.muted)
                            }
                        }
                    }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.blueSoft.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    Label("You can't drive into the destination's zone at that time. Look for a car park outside on the map.", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.red)
                }
            }
            HStack(spacing: 10) {
                Button { onStart(target) } label: {
                    Label(plan.destinationBlocked && plan.parking != nil ? L("Drive to the car park") : L("Start"),
                          systemImage: "location.north.fill")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Theme.blueFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("route.start")
                Menu {
                    Section(L("Open in")) {
                        ForEach(Navigator.allCases) { n in Button(n.title) { n.open(to: target) } }
                    }
                } label: {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond").font(.system(size: 18, weight: .semibold))
                        .frame(width: 52, height: 50)
                        .background(Theme.blueSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(Theme.blue)
                }
                .accessibilityLabel(L("Open in another navigator"))
                Button(action: onMap) {
                    Image(systemName: "map").font(.system(size: 17, weight: .semibold))
                        .frame(width: 52, height: 50)
                        .background(Theme.blueSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(Theme.blue)
                }
                .accessibilityLabel(L("Show on the map"))
            }
            Text("GateLR guides you with the voice and warns you before every active ZTL. It doesn't avoid them by itself: watch the gate signs.")
                .font(.system(size: 12)).foregroundStyle(Theme.muted)
        }
        .padding(16).card(20)
    }
}
