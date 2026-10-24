import SwiftUI
import CoreLocation

/// «Varco»: la prima pagina. In un colpo d'occhio cosa fa GateLR, la situazione intorno a te adesso,
/// le città con il loro stato e il pulsante per pianificare. La ricerca vera è nella scheda Viaggio.
struct VarcoView: View {
    @EnvironmentObject var store: Store
    @ObservedObject private var monitor = GateMonitor.shared
    @ObservedObject private var guardian = Guardian.shared
    @Binding var showZone: Bool
    @Binding var tab: Tab
    @State private var learning = false
    @State private var readingSign = false

    var body: some View {
        TimelineView(.everyMinute) { ctx in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if guardian.active { guardianBanner }
                    hero
                    aroundYou(at: ctx.date)
                    planButton
                    cities(at: ctx.date)
                    zones(at: ctx.date)
                    if let next = store.trips.filter({ $0.arrival > ctx.date }).min(by: { $0.arrival < $1.arrival }) { nextTrip(next) }
                    learnCard
                    signCard
                    StatusBanner(status: store.city.status)
                    Text("Road signs on site always win over the app.")
                        .font(.app(size: 12)).foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
            }
            .background(Theme.ground)
        }
        .sheet(isPresented: $learning) { NavigationStack { LearnZTLView() } }
        .sheet(isPresented: $readingSign) { NavigationStack { SignReaderView() } }
    }

    private var header: some View {
        HStack {
            Wordmark()
            Spacer()
            Button { tab = .account } label: {
                Image(systemName: "person.crop.circle").font(.app(size: 26)).foregroundStyle(Theme.muted)
            }
            .accessibilityLabel(L("Account"))
        }
    }

    /// Cos'è GateLR, in tre righe
    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: -8) {
                ForEach(L("Know before|the gate.").components(separatedBy: "|"), id: \.self) {
                    Text($0).font(Theme.display(38)).foregroundStyle(.white)
                }
            }
            Text("Italy's old towns are closed to cars at set hours, with cameras at every gate. GateLR tells you if you can drive in, now or when you arrive, and warns you before a gate.")
                .font(.app(size: 15)).foregroundStyle(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                heroChip("checkmark.circle.fill", "Clear answer")
                heroChip("bell.badge.fill", "Gate alerts")
                heroChip("doc.text.magnifyingglass", "Official sources")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color(hex: 0x1D4FA8), Color(hex: 0x14326E)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Circle().stroke(Theme.red, lineWidth: 10).frame(width: 64, height: 64).opacity(0.85)
                .overlay(Circle().fill(.white.opacity(0.08)))
                .padding(18).accessibilityHidden(true)
        }
        .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
    }

    private func heroChip(_ symbol: String, _ text: String) -> some View {
        Label(L(text), systemImage: symbol)
            .font(.app(size: 12, weight: .semibold))
            .lineLimit(1).minimumScaleFactor(0.8)
            .padding(.horizontal, 10).frame(height: 30)
            .background(.white.opacity(0.16), in: Capsule())
            .foregroundStyle(.white)
    }

    /// La ZTL più vicina a te (o quella in cui sei), con la risposta adesso
    @ViewBuilder
    private func aroundYou(at date: Date) -> some View {
        if let here = monitor.location {
            let c = Coordinate(lat: here.coordinate.latitude, lon: here.coordinate.longitude)
            let inside = store.zones(at: c).first
            let near = store.nearestZone(to: c)
            let nearby: Zone? = (near?.meters ?? .infinity) < 30_000 ? near?.zone : nil
            if let zone = inside?.zone ?? nearby {
                let a = store.answer(at: date, zone: zone, hotelInside: false)
                Button { select(zone); showZone = true } label: {
                    HStack(spacing: 14) {
                        Image(systemName: a.verdict.symbol).font(.app(size: 20, weight: .heavy))
                            .foregroundStyle(a.verdict.badgeInk)
                            .frame(width: 46, height: 46).background(a.verdict.badgeFill, in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(inside != nil ? String(format: L("You're inside %@"), zone.shortName)
                                 : String(format: L("%@ is %@ away"), zone.shortName,
                                          DriveSession.distanceText(near?.meters ?? 0)))
                                .font(.app(size: 13, weight: .semibold)).opacity(0.9)
                            Text(a.verdict.short).font(Theme.display(24))
                            if let next = a.nextChange {
                                Text(String(format: L(a.gatesOn ? "Ends at %@" : "Starts at %@"), next.formatted(date: .omitted, time: .shortened)))
                                    .font(.app(size: 13)).opacity(0.9)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.app(size: 13, weight: .bold)).opacity(0.7)
                    }
                    .foregroundStyle(a.verdict.onFill)
                    .padding(16)
                    .background(a.verdict.fill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                infoRow("location.fill", L("No ZTL near you. GateLR covers Florence, Bologna and Milan for now."))
            }
        } else {
            infoRow("location.slash", L("Allow location access to see the ZTL near you."))
        }
    }

    /// Il guardiano è attivo: cosa vede adesso e il pulsante per fermarlo
    private var guardianBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "shield.lefthalf.filled").font(.app(size: 22, weight: .bold))
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: L("Guardian on · to %@"), guardian.destination?.name ?? "")).font(.app(size: 15, weight: .bold)).lineLimit(1)
                Text(guardian.threat.map { "\($0.zone.shortName) · \(DriveSession.distanceText($0.meters)) · \($0.answer.verdict.short)" }
                     ?? L("No active ZTL ahead"))
                    .font(.app(size: 13)).opacity(0.9)
            }
            Spacer()
            Button(L("Stop")) { guardian.stop() }
                .font(.app(size: 14, weight: .bold))
                .padding(.horizontal, 12).frame(height: 34)
                .background(.white.opacity(0.2), in: Capsule())
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(guardian.threat == nil ? Theme.green : Theme.red, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func infoRow(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(Theme.blue).frame(width: 28)
            Text(text).font(.app(size: 14)).foregroundStyle(Theme.ink)
            Spacer()
        }
        .padding(14).card()
    }

    private var planButton: some View {
        Button { tab = .trip } label: {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass").font(.app(size: 18, weight: .semibold))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Where are you going?").font(.app(size: 17, weight: .bold))
                    Text("Hotel, address or square: answer, route and hotel message").font(.app(size: 13)).opacity(0.85)
                }
                Spacer()
                Image(systemName: "arrow.right").font(.app(size: 16, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(16)
            .background(Theme.red, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("varco.plan")
    }

    /// Le città: quante zone sono attive adesso. Tocco = la città scelta
    private func cities(at date: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Cities")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(store.cities) { c in
                        let on = c.zones.filter { store.engine.isActive($0, at: date) }.count
                        let selected = c.id == store.city.id
                        Button { withAnimation(.snappy) { store.cityId = c.id } } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(c.localizedName).font(Theme.display(20))
                                HStack(spacing: 5) {
                                    Circle().fill(on > 0 ? Theme.red : Theme.green).frame(width: 8, height: 8)
                                    Text(on == 0 ? L("All open") : String(format: L("%lld active"), on))
                                        .font(.app(size: 12, weight: .semibold))
                                }
                            }
                            .foregroundStyle(selected ? .white : Theme.ink)
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .frame(minWidth: 118, alignment: .leading)
                            .background(selected ? Theme.blueFill : Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }
        }
    }

    /// Le zone della città scelta, con la risposta adesso
    private func zones(at date: Date) -> some View {
        VStack(spacing: 0) {
            ForEach(store.city.zones) { z in
                let a = store.answer(at: date, zone: z, hotelInside: false)
                Button { select(z); showZone = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: z.type.symbol).font(.app(size: 14, weight: .bold))
                            .frame(width: 32, height: 32)
                            .background(z.type.color.opacity(0.16), in: Circle())
                            .foregroundStyle(z.type.color)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(z.localizedName).font(.app(size: 15)).foregroundStyle(Theme.ink).lineLimit(2)
                            Text("\(z.type.title) · \(a.gatesOn ? L("ZTL active") : L("ZTL not active"))")
                                .font(.app(size: 12)).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        VerdictPill(verdict: a.verdict)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if z.id != store.city.zones.last?.id { Divider().padding(.leading, 58) }
            }
        }
        .card()
    }

    private func nextTrip(_ t: Trip) -> some View {
        Button { if let h = t.hotel { store.select(h) }; tab = .trip } label: {
            HStack(spacing: 12) {
                Image(systemName: "suitcase.rolling.fill").foregroundStyle(Theme.blue)
                    .frame(width: 40, height: 40).background(Theme.blueSoft, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Your next trip").font(.app(size: 12, weight: .semibold)).foregroundStyle(Theme.muted)
                    Text(t.hotelName.isEmpty ? (t.hotel?.name ?? L("Trip")) : t.hotelName)
                        .font(.app(size: 16, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                    Text(t.arrival.formatted(.dateTime.weekday(.wide).day().month().hour().minute()))
                        .font(.app(size: 13)).foregroundStyle(Theme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.app(size: 13, weight: .bold)).foregroundStyle(Theme.muted)
            }
            .padding(14).card()
        }
        .buttonStyle(.plain)
    }

    private var learnCard: some View {
        Button { learning = true } label: {
            HStack(spacing: 14) {
                ZTLSign().frame(width: 44, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text("New to ZTLs?").font(.app(size: 16, weight: .bold)).foregroundStyle(Theme.ink)
                    Text("The signs, the panels and what to do if you drove in by mistake. 1 minute.")
                        .font(.app(size: 13)).foregroundStyle(Theme.muted).multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.app(size: 13, weight: .bold)).foregroundStyle(Theme.muted)
            }
            .padding(14).card()
        }
        .buttonStyle(.plain)
    }

    private var signCard: some View {
        Button { readingSign = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "camera.viewfinder").font(.app(size: 26, weight: .semibold)).foregroundStyle(Theme.blue)
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Read the sign").font(.app(size: 16, weight: .bold)).foregroundStyle(Theme.ink)
                    Text("Point the camera at the hours panel: GateLR explains it in your language.")
                        .font(.app(size: 13)).foregroundStyle(Theme.muted).multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.app(size: 13, weight: .bold)).foregroundStyle(Theme.muted)
            }
            .padding(14).card()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("varco.sign")
    }

    private func select(_ z: Zone) {
        if let city = store.cities.first(where: { $0.zones.contains(z) }) { store.cityId = city.id }
        store.zoneId = z.id
    }
}
