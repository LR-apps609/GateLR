import SwiftUI
import CoreLocation

/// «Adesso»: posso entrare, ora, con questa auto?
struct NowView: View {
    @EnvironmentObject var store: Store
    @ObservedObject private var monitor = GateMonitor.shared
    @Binding var showZone: Bool
    @Binding var tab: Tab

    var body: some View {
        TimelineView(.everyMinute) { ctx in
            let answer = store.answer(at: ctx.date)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    if store.city.isSample { SampleBanner() }
                    vehicleRow
                    VerdictCard(answer: answer,
                                heading: "Right now · \(ctx.date.formatted(date: .omitted, time: .shortened))",
                                source: store.zone.source,
                                onWhy: { showZone = true })
                    Text(store.zone.name).font(.system(size: 13)).foregroundStyle(Theme.muted)
                    arrivingLater
                    gatesNearby(gatesOn: answer.gatesOn)
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
            }
            .background(Theme.ground)
        }
    }

    private var header: some View {
        HStack {
            LogoMark()
            (Text("Gate").foregroundStyle(Theme.ink) + Text("LR").foregroundStyle(Theme.red))
                .font(Theme.display(24))
            Spacer()
            Menu {
                ForEach(store.cities) { c in Button(c.name) { store.cityId = c.id } }
            } label: {
                Label(store.city.name, systemImage: "mappin")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 14).frame(height: 36)
                    .background(Theme.card, in: Capsule())
                    .foregroundStyle(Theme.ink)
            }
        }
    }

    private var vehicleRow: some View {
        Button { tab = .garage } label: {
            HStack(spacing: 12) {
                Image(systemName: "car.fill").foregroundStyle(Theme.blue)
                    .frame(width: 40, height: 40).background(Theme.blueSoft, in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 1) {
                    Text(store.vehicle.name).font(.system(size: 15, weight: .semibold))
                    Text("\(store.vehicle.fuel.label) · Euro \(store.vehicle.euro) · \(permitsLine)")
                        .font(.system(size: 13)).foregroundStyle(Theme.muted)
                }
                Spacer()
                Text("Change").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.blue)
            }
            .padding(12).card()
            .foregroundStyle(Theme.ink)
        }
    }

    private var permitsLine: String {
        let n = store.permits.filter { $0.vehicleId == store.vehicle.id }.count
        return n == 0 ? "no permit" : "\(n) permit\(n == 1 ? "" : "s")"
    }

    private var arrivingLater: some View {
        Button { tab = .trip } label: {
            HStack(spacing: 12) {
                Image(systemName: "calendar").font(.system(size: 20))
                VStack(alignment: .leading) {
                    Text("Arriving later?").font(.system(size: 15, weight: .semibold))
                    Text("Check the day and time you'll get there").font(.system(size: 13)).opacity(0.88)
                }
                Spacer()
                Image(systemName: "chevron.right")
            }
            .padding(14)
            .foregroundStyle(.white)
            .background(Theme.blue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func gatesNearby(gatesOn: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Gates near you")
            VStack(spacing: 0) {
                ForEach(sortedGates) { g in
                    HStack(spacing: 12) {
                        Circle().fill(gatesOn ? Theme.red : Theme.green).frame(width: 10, height: 10)
                        Text(g.name).font(.system(size: 15))
                        Spacer()
                        Text([distance(to: g), gatesOn ? "on" : "off"].compactMap { $0 }.joined(separator: " · "))
                            .font(.system(size: 13)).foregroundStyle(gatesOn ? Theme.red : Theme.muted)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    if g.id != sortedGates.last?.id { Divider().padding(.leading, 36) }
                }
            }
            .card()
        }
    }

    private var sortedGates: [Gate] {
        let gates = store.zone.gates
        guard let here = monitor.location else { return Array(gates.prefix(3)) }
        return Array(gates.sorted { here.distance(from: loc($0)) < here.distance(from: loc($1)) }.prefix(3))
    }
    private func loc(_ g: Gate) -> CLLocation { CLLocation(latitude: g.location.lat, longitude: g.location.lon) }
    private func distance(to g: Gate) -> String? {
        guard let here = monitor.location else { return nil }
        let m = Measurement(value: here.distance(from: loc(g)), unit: UnitLength.meters)
        return m.formatted(.measurement(width: .abbreviated, usage: .road))
    }
}
