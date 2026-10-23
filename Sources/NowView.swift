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
                VStack(alignment: .leading, spacing: 16) {
                    header
                    StatusBanner(status: store.city.status)
                    vehicleRow
                    VerdictCard(answer: answer,
                                heading: "\(store.zone.shortName) · now \(ctx.date.formatted(date: .omitted, time: .shortened))",
                                source: store.zone.source,
                                since: store.engine.previousChange(store.zone, before: ctx.date),
                                onWhy: { showZone = true })
                    arrivingLater
                    sectors(at: ctx.date)
                    gatesNearby(gatesOn: answer.gatesOn)
                    Text("Road signs on site always win over the app.")
                        .font(.system(size: 12)).foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
            }
            .background(Theme.ground)
        }
    }

    private var header: some View {
        HStack {
            Wordmark()
            Spacer()
            Menu {
                ForEach(store.cities) { c in Button(c.name) { store.cityId = c.id } }
            } label: {
                Label(store.city.name, systemImage: "mappin.and.ellipse")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 14).frame(height: 36)
                    .background(Theme.card, in: Capsule())
                    .foregroundStyle(Theme.ink)
            }
            .accessibilityLabel("City: \(store.city.name)")
        }
    }

    private var vehicleRow: some View {
        Button { tab = .garage } label: {
            HStack(spacing: 12) {
                Image(systemName: store.vehicle.fuel == .electric ? "bolt.car.fill" : "car.fill").foregroundStyle(Theme.blue)
                    .frame(width: 40, height: 40).background(Theme.blueSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
        .buttonStyle(.plain)
    }

    private var permitsLine: String {
        let n = store.permits.filter { $0.vehicleId == store.vehicle.id }.count
        return n == 0 ? "no permit" : "\(n) permit\(n == 1 ? "" : "s")"
    }

    private var arrivingLater: some View {
        Button { tab = .trip } label: {
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock").font(.system(size: 20))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Arriving later?").font(.system(size: 15, weight: .semibold))
                    Text("Check the day and time you'll get there").font(.system(size: 13)).opacity(0.88)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold))
            }
            .padding(14)
            .foregroundStyle(.white)
            .background(Color(hex: 0x1F4E9E), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// Tutti i settori della città, con la risposta di ciascuno: si tocca per sceglierlo
    private func sectors(at date: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("\(store.city.name) sectors")
            VStack(spacing: 0) {
                ForEach(store.city.zones) { z in
                    let a = store.answer(at: date, zone: z)
                    Button { withAnimation(.snappy) { store.zoneId = z.id } } label: {
                        HStack(spacing: 12) {
                            Text(z.letter)
                                .font(Theme.display(17))
                                .frame(width: 32, height: 32)
                                .background(z.id == store.zone.id ? Theme.red : Theme.raised, in: Circle())
                                .foregroundStyle(z.id == store.zone.id ? .white : Theme.ink)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(z.place).font(.system(size: 15)).foregroundStyle(Theme.ink).lineLimit(1)
                                Text(a.gatesOn ? "Gates on" : "Gates off").font(.system(size: 12)).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            VerdictPill(verdict: a.verdict)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(z.id == store.zone.id ? .isSelected : [])
                    if z.id != store.city.zones.last?.id { Divider().padding(.leading, 58) }
                }
            }
            .card()
        }
    }

    private func gatesNearby(gatesOn: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(monitor.location == nil ? "Gates of \(store.zone.shortName)" : "Gates near you")
            if sortedGates.isEmpty {
                Text("This sector has no gates of its own: you enter it through the gates of the sectors around it.")
                    .font(.system(size: 14)).foregroundStyle(Theme.muted)
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading).card()
            } else {
                VStack(spacing: 0) {
                    ForEach(sortedGates) { g in
                        HStack(spacing: 12) {
                            Image(systemName: "video.fill").font(.system(size: 11))
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(gatesOn ? Theme.red : Theme.green, in: Circle())
                            Text(g.name).font(.system(size: 15)).lineLimit(1)
                            Spacer()
                            Text([distance(to: g), gatesOn ? "on" : "off"].compactMap { $0 }.joined(separator: " · "))
                                .font(.system(size: 13)).foregroundStyle(gatesOn ? Theme.red : Theme.muted)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        if g.id != sortedGates.last?.id { Divider().padding(.leading, 48) }
                    }
                }
                .card()
            }
        }
    }

    private var sortedGates: [Gate] {
        let gates = store.zone.gates
        guard let here = monitor.location else { return Array(gates.prefix(4)) }
        let all = store.city.zones.flatMap(\.gates)
        return Array(all.sorted { here.distance(from: loc($0)) < here.distance(from: loc($1)) }.prefix(4))
    }
    private func loc(_ g: Gate) -> CLLocation { CLLocation(latitude: g.location.lat, longitude: g.location.lon) }
    private func distance(to g: Gate) -> String? {
        guard let here = monitor.location else { return nil }
        let m = Measurement(value: here.distance(from: loc(g)), unit: UnitLength.meters)
        return m.formatted(.measurement(width: .abbreviated, usage: .road))
    }
}

extension Zone {
    /// «B» da «Sector B · Historic Centre»
    var letter: String { name.split(separator: "·").first.map { String($0.split(separator: " ").last ?? "") } ?? "" }
    /// «Historic Centre» da «Sector B · Historic Centre»
    var place: String { name.split(separator: "·").dropFirst().joined(separator: "·").trimmingCharacters(in: .whitespaces) }
    var shortName: String { "Sector \(letter)" }
}
