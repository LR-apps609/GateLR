import SwiftUI
import MapKit

/// «Varco»: scegli la città e, se vuoi, un indirizzo. Solo città = panoramica delle zone;
/// indirizzo = la risposta per quel punto, adesso o all'ora di arrivo.
struct VarcoView: View {
    @EnvironmentObject var store: Store
    @ObservedObject private var monitor = GateMonitor.shared
    @StateObject private var search = AddressSearch()
    @Binding var showZone: Bool
    @Binding var tab: Tab
    @FocusState private var typing: Bool
    @State private var atArrival = false
    @State private var arrival = TripView.at(dayOffset: 0, hour: 18)
    @State private var resolving = false

    var body: some View {
        TimelineView(.everyMinute) { ctx in
            let date = atArrival ? arrival : ctx.date
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    searchField
                    if typing && !search.query.isEmpty {
                        suggestions
                    } else {
                        whenRow
                        if let place = store.place {
                            placeAnswer(place, at: date)
                        } else {
                            overview(at: date)
                        }
                        StatusBanner(status: store.city.status)
                        Text("Road signs on site always win over the app.")
                            .font(.system(size: 12)).foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
                .animation(.snappy, value: store.place)
                .animation(.snappy, value: atArrival)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(Theme.ground)
        }
        .onAppear { search.focus(on: store.city) }
        .onChange(of: store.cityId) { search.focus(on: store.city) }
    }

    // MARK: Testata e ricerca

    private var header: some View {
        HStack {
            Wordmark()
            Spacer()
            Menu {
                ForEach(store.cities) { c in
                    Button(c.localizedName) { store.place = nil; store.cityId = c.id }
                }
            } label: {
                Label(store.city.localizedName, systemImage: "mappin.and.ellipse")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 14).frame(height: 36)
                    .background(Theme.card, in: Capsule())
                    .foregroundStyle(Theme.ink)
            }
            .accessibilityLabel(String(format: L("City: %@"), store.city.localizedName))
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
            TextField(String(format: L("Address or hotel in %@"), store.city.localizedName), text: $search.query)
                .focused($typing)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .accessibilityIdentifier("varco.search")
            if resolving { ProgressView() }
            if !search.query.isEmpty || store.place != nil {
                Button {
                    search.clear(); store.place = nil; typing = false
                } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.muted) }
                .accessibilityLabel(L("Clear"))
            } else if monitor.location != nil {
                Button { useMyLocation() } label: { Image(systemName: "location.fill").foregroundStyle(Theme.blue) }
                    .accessibilityLabel(L("Use my location"))
            }
        }
        .font(.system(size: 16))
        .padding(.horizontal, 14).frame(height: 50)
        .card(14)
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 0) {
            if search.results.isEmpty {
                Text(search.failed ? L("Search isn't working right now. Check your connection.") : L("Keep typing…"))
                    .font(.system(size: 14)).foregroundStyle(Theme.muted).padding(14)
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
                        Image(systemName: "mappin.circle.fill").font(.system(size: 22)).foregroundStyle(Theme.red)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(r.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                            if !r.subtitle.isEmpty {
                                Text(r.subtitle).font(.system(size: 13)).foregroundStyle(Theme.muted).lineLimit(1)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("varco.result.\(i)")
                if i < search.results.count - 1 { Divider().padding(.leading, 48) }
            }
        }
        .card()
    }

    private func useMyLocation() {
        guard let here = monitor.location else { return }
        store.select(Place(name: L("My position"), address: "",
                           location: Coordinate(lat: here.coordinate.latitude, lon: here.coordinate.longitude)))
    }

    // MARK: Adesso / all'arrivo

    private var whenRow: some View {
        HStack(spacing: 10) {
            Picker(L("When"), selection: $atArrival) {
                Text("Now").tag(false)
                Text("At arrival").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 220)
            Spacer(minLength: 0)
            if atArrival {
                DatePicker(L("Arrival"), selection: $arrival, in: Date()...)
                    .labelsHidden()
                    .transition(.opacity)
            }
        }
    }

    private func heading(_ zone: Zone, _ date: Date) -> String {
        atArrival
            ? "\(zone.shortName) · \(date.formatted(.dateTime.weekday(.abbreviated).hour().minute()))"
            : String(format: L("%@ · now %@"), zone.shortName, date.formatted(date: .omitted, time: .shortened))
    }

    // MARK: Risposta per l'indirizzo

    @ViewBuilder
    private func placeAnswer(_ place: Place, at date: Date) -> some View {
        let hits = store.zones(at: place.location)
        placeCard(place, inside: hits.first?.zone)
        if let hit = hits.first {
            VerdictCard(answer: store.answer(at: date, zone: hit.zone, hotelInside: false),
                        heading: heading(hit.zone, date),
                        source: hit.zone.source,
                        since: atArrival ? nil : store.engine.previousChange(hit.zone, before: date),
                        onWhy: { store.cityId = hit.city.id; store.zoneId = hit.zone.id; showZone = true })
            if hits.count > 1 {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("Also inside")
                    zoneList(hits.dropFirst().map { $0.zone }, at: date)
                }
            }
            if hit.zone.hotelCanRegister {
                hint("Staying at a hotel here? It can register your plate: see Trip.", symbol: "building.2", action: { tab = .trip })
            }
        } else {
            outsideCard(place)
        }
    }

    private func placeCard(_ place: Place, inside zone: Zone?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: zone?.type.symbol ?? "checkmark")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(zone?.type.color ?? Theme.green, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(place.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                Text(zone.map { "\($0.type.title) · \($0.shortName)" } ?? L("Outside the ZTL"))
                    .font(.system(size: 13)).foregroundStyle(Theme.muted).lineLimit(1)
            }
            Spacer()
            Button { tab = .map } label: {
                Image(systemName: "map").font(.system(size: 15, weight: .semibold))
                    .frame(width: 36, height: 36).background(Theme.blueSoft, in: Circle()).foregroundStyle(Theme.blue)
            }
            .accessibilityLabel(L("Show on the map"))
        }
        .padding(12).card()
    }

    private func outsideCard(_ place: Place) -> some View {
        let near = store.nearestZone(to: place.location)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark").font(.system(size: 24, weight: .heavy)).foregroundStyle(Theme.green)
                    .frame(width: 52, height: 52).background(.white, in: Circle())
                VStack(alignment: .leading, spacing: -12) {
                    ForEach(L("Outside|the ZTL").components(separatedBy: "|"), id: \.self) { Text($0).font(Theme.display(34)) }
                }
            }
            Text("This address isn't inside any ZTL we know. You can drive there.").font(.system(size: 16))
            if let near, near.meters < 3_000 {
                let m = Measurement(value: near.meters, unit: UnitLength.meters).formatted(.measurement(width: .abbreviated, usage: .road))
                Text(String(format: L("The nearest zone, %@, is %@ away."), near.zone.shortName, m))
                    .font(.system(size: 14)).opacity(0.92)
                if near.meters < 150 {
                    Label("Very close to the border: follow the signs and don't cross a gate.", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(.white)
        .background(Theme.green, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
    }

    // MARK: Panoramica della città

    @ViewBuilder
    private func overview(at date: Date) -> some View {
        let zones = store.city.zones
        let on = zones.filter { store.answer(at: date, zone: $0).gatesOn }.count
        VStack(alignment: .leading, spacing: 4) {
            Text(store.city.localizedName).font(Theme.display(34)).foregroundStyle(Theme.ink)
            Text(on == 0 ? L("All gates are off right now.") : String(format: L("%lld of %lld zones have the gates on."), on, zones.count))
                .font(.system(size: 15)).foregroundStyle(Theme.muted)
        }
        zoneList(zones, at: date)
        hint("Search your destination for a precise answer.", symbol: "magnifyingglass", action: { typing = true })
        vehicleRow
    }

    private func zoneList(_ zones: [Zone], at date: Date) -> some View {
        VStack(spacing: 0) {
            ForEach(zones) { z in
                let a = store.answer(at: date, zone: z, hotelInside: false)
                Button {
                    if let city = store.cities.first(where: { $0.zones.contains(z) }) { store.cityId = city.id }
                    store.zoneId = z.id
                    showZone = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: z.type.symbol)
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 32, height: 32)
                            .background(z.type.color.opacity(0.16), in: Circle())
                            .foregroundStyle(z.type.color)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(z.localizedName).font(.system(size: 15)).foregroundStyle(Theme.ink).lineLimit(1)
                            Text("\(z.type.title) · \(a.gatesOn ? L("Gates on") : L("Gates off"))")
                                .font(.system(size: 12)).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        VerdictPill(verdict: a.verdict)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if z.id != zones.last?.id { Divider().padding(.leading, 58) }
            }
        }
        .card()
    }

    private func hint(_ text: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol).foregroundStyle(Theme.blue)
                Text(L(text)).font(.system(size: 14)).foregroundStyle(Theme.ink).multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.muted)
            }
            .padding(14)
            .background(Theme.blueSoft.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var vehicleRow: some View {
        Button { tab = .garage } label: {
            HStack(spacing: 10) {
                Image(systemName: store.vehicle.fuel == .electric ? "bolt.car.fill" : "car.fill").foregroundStyle(Theme.blue)
                Text("\(store.vehicle.name) · \(store.vehicle.fuel.label) · Euro \(store.vehicle.euro)")
                    .font(.system(size: 14)).foregroundStyle(Theme.ink).lineLimit(1)
                Spacer()
                Text("Change").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.blue)
            }
            .padding(.horizontal, 14).padding(.vertical, 12).card()
        }
        .buttonStyle(.plain)
    }
}
