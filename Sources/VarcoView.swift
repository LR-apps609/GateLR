import SwiftUI
import CoreLocation

/// «Varco»: la prima pagina, una sola domanda: «Posso entrare?». Il riquadro resta grigio finché non cerchi
/// un posto (la ricerca è quella di Viaggio), poi diventa verde, rosso o ambra per quel posto adesso.
/// Sotto, piccola, la ZTL vicino a te; poi il prossimo viaggio, le città e le due guide.
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
                    askCard(at: ctx.date)
                    nearYou(at: ctx.date)
                    if let next = store.trips.filter({ $0.arrival > ctx.date }).min(by: { $0.arrival < $1.arrival }) { nextTrip(next) }
                    cities(at: ctx.date)
                    zones(at: ctx.date)
                    HStack(alignment: .top, spacing: 12) {
                        learnCard
                        signCard
                    }
                    StatusBanner(status: store.city.status)
                    Text("Road signs on site always win over the app.")
                        .font(.app(size: 12)).foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
                .animation(.snappy, value: store.place)
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

    // MARK: La domanda: «Posso entrare?»

    /// Grigio finché non cerchi niente; verde, rosso o ambra per il posto cercato (in Viaggio o in Mappa)
    @ViewBuilder
    private func askCard(at date: Date) -> some View {
        if let place = store.place {
            answerCard(PlaceCheck(place, store: store, at: date))
        } else {
            emptyAsk
        }
    }

    private static let neutral = Color(light: 0xE4E7EA, dark: 0x1F262E)

    private var emptyAsk: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L("Can I drive in?").uppercased())
                        .font(Theme.label(13)).tracking(1.2).foregroundStyle(Theme.muted)
                    VStack(alignment: .leading, spacing: -8) {
                        ForEach(L("Find out if you|can drive in").components(separatedBy: "|"), id: \.self) {
                            Text($0).font(Theme.display(34)).foregroundStyle(Theme.ink)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(L("Find out if you|can drive in").replacingOccurrences(of: "|", with: " "))
                    .accessibilityAddTraits(.isHeader)
                }
                Spacer(minLength: 8)
                ZTLSign().scaleEffect(0.45).frame(width: 30, height: 50).accessibilityHidden(true)
            }
            Text("Search a hotel, address or square: GateLR tells you at once if your car can get there.")
                .font(.app(size: 15)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Button { openSearch() } label: {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").font(.app(size: 17, weight: .semibold)).foregroundStyle(Theme.red)
                    Text("Hotel, address or square").font(.app(size: 16)).foregroundStyle(Theme.muted).lineLimit(1)
                    Spacer()
                    Image(systemName: "arrow.right").font(.app(size: 14, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 36, height: 36).background(Theme.red, in: Circle())
                }
                .padding(.leading, 14).padding(.trailing, 8).frame(height: 54)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                .shadow(color: .black.opacity(0.07), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L("Hotel, address or square"))
            .accessibilityIdentifier("varco.plan")
            if !store.recent.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.recent.prefix(4)) { p in
                            Button { store.select(p) } label: {
                                Label(p.name, systemImage: "clock.arrow.circlepath")
                                    .font(.app(size: 13, weight: .semibold)).lineLimit(1)
                                    .padding(.horizontal, 12).frame(height: 32)
                                    .background(Theme.card.opacity(0.7), in: Capsule())
                                    .foregroundStyle(Theme.ink)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Self.neutral, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func answerCard(_ check: PlaceCheck) -> some View {
        let v = check.verdict
        let amber = check.kind == .conditional || check.kind == .unsure
        let fill: Color = amber ? Theme.amberSoft : v.fill
        let ink: Color = amber ? Theme.amberInk : .white
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L("Can I drive in?").uppercased()).font(Theme.label(13)).tracking(1.2).opacity(0.85)
                Spacer()
                Button { withAnimation(.snappy) { store.place = nil } } label: {
                    Image(systemName: "xmark").font(.app(size: 13, weight: .bold))
                        .frame(width: 32, height: 32).background(ink.opacity(0.16), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("Clear"))
                .accessibilityIdentifier("varco.clear")
            }
            Label { Text(verbatim: check.place.name).lineLimit(1) } icon: { Image(systemName: "mappin.and.ellipse") }
                .font(.app(size: 15, weight: .semibold))
            HStack(spacing: 14) {
                Image(systemName: check.symbol).font(.app(size: 26, weight: .heavy))
                    .foregroundStyle(amber ? Color.white : v.fill)
                    .frame(width: 56, height: 56)
                    .background(amber ? Theme.amber : Color.white, in: Circle())
                    .accessibilityHidden(true)
                Text(v.short).font(Theme.display(36)).lineLimit(2).minimumScaleFactor(0.6)
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: check.zoneLine).font(.app(size: 15, weight: .semibold))
                if let until = check.until { Text(verbatim: until).font(.app(size: 14)).opacity(0.9) }
            }
            HStack(spacing: 10) {
                Button { tab = .trip } label: {
                    HStack(spacing: 6) { Text("Details"); Image(systemName: "arrow.right") }
                        .font(.app(size: 15, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(amber ? Theme.amber : Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(amber ? Color.white : v.fill)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("varco.details")
                Button { tab = .map } label: {
                    Image(systemName: "map").font(.app(size: 17, weight: .semibold))
                        .frame(width: 46, height: 46)
                        .background(ink.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("Show on the map"))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(ink)
        .background(fill, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 14, y: 6)
    }

    /// Viaggio con il campo di ricerca già pronto (la ricerca è una sola, quella di Viaggio)
    private func openSearch() {
        TripView.focusSearch = true
        tab = .trip
    }

    /// Solo una riga: la ZTL vicino a te (o quella in cui sei), se adesso è attiva
    @ViewBuilder
    private func nearYou(at date: Date) -> some View {
        if let here = monitor.location {
            let c = Coordinate(lat: here.coordinate.latitude, lon: here.coordinate.longitude)
            let inside = store.zones(at: c).first
            let near = store.nearestZone(to: c)
            let nearby: Zone? = (near?.meters ?? .infinity) < 30_000 ? near?.zone : nil
            if let zone = inside?.zone ?? nearby {
                let on = store.answer(at: date, zone: zone, hotelInside: false).gatesOn
                let distance = inside != nil ? L("you're inside") : DriveSession.distanceText(near?.meters ?? 0)
                Button { select(zone); showZone = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "location.fill").font(.app(size: 13, weight: .semibold)).foregroundStyle(Theme.blue)
                        (Text(verbatim: L("Near you") + ": ").foregroundStyle(Theme.muted)
                         + Text(verbatim: "\(zone.shortName) · \(distance) · ").foregroundStyle(Theme.ink)
                         + Text(verbatim: on ? L("active now") : L("not active now")).foregroundStyle(on ? Theme.red : Theme.greenInk))
                            .font(.app(size: 14, weight: .medium)).lineLimit(1).minimumScaleFactor(0.8)
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right").font(.app(size: 12, weight: .bold)).foregroundStyle(Theme.muted)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .card(14)
                }
                .buttonStyle(.plain)
            } else {
                infoRow("location.fill", L("No ZTL near you"))
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
            Image(systemName: symbol).font(.app(size: 13, weight: .semibold)).foregroundStyle(Theme.blue)
            Text(text).font(.app(size: 14)).foregroundStyle(Theme.muted)
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 12).card(14)
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
        VStack(spacing: 8) {
            tripRow(t)
            // Il viaggio è oggi: si parte con il guardiano verso l'hotel, con un tocco
            if Calendar.current.isDateInToday(t.arrival), let hotel = t.hotel, !guardian.active {
                Menu {
                    ForEach(Navigator.allCases) { n in
                        Button { guardian.start(to: hotel, with: n, store: store) } label: { Label(n.title, systemImage: "shield.lefthalf.filled") }
                    }
                } label: {
                    Label(String(format: L("Leave now for %@"), t.hotelName.isEmpty ? hotel.name : t.hotelName), systemImage: "location.north.fill")
                        .font(.app(size: 15, weight: .bold)).lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Theme.blueFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func tripRow(_ t: Trip) -> some View {
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
            tile(title: "New to ZTLs?", text: "Signs, panels and what to do after a mistake. 1 minute.") {
                ZTLSign().scaleEffect(0.36).frame(width: 24, height: 38)
            }
        }
        .buttonStyle(.plain)
    }

    private var signCard: some View {
        Button { readingSign = true } label: {
            tile(title: "Read the sign", text: "Point the camera at the hours panel.") {
                Image(systemName: "camera.viewfinder").font(.app(size: 28, weight: .semibold)).foregroundStyle(Theme.blue)
                    .frame(height: 38)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("varco.sign")
    }

    private func tile<Icon: View>(title: LocalizedStringKey, text: LocalizedStringKey, @ViewBuilder icon: () -> Icon) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            icon()
            Text(title).font(.app(size: 16, weight: .bold)).foregroundStyle(Theme.ink)
            Text(text).font(.app(size: 13)).foregroundStyle(Theme.muted)
                .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .card()
    }

    private func select(_ z: Zone) {
        if let city = store.cities.first(where: { $0.zones.contains(z) }) { store.cityId = city.id }
        store.zoneId = z.id
    }
}
