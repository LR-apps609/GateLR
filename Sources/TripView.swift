import SwiftUI
import MapKit
import UIKit
import TipKit

/// «Viaggio»: l'unico posto dove si cerca la destinazione o l'hotel. Risposta adesso o all'arrivo,
/// percorso con il controllo delle ZTL, messaggio per l'hotel e viaggi salvati.
struct TripView: View {
    @EnvironmentObject var store: Store
    @ObservedObject private var monitor = GateMonitor.shared
    @StateObject private var search = AddressSearch()
    @ObservedObject private var planner = RoutePlanner.shared
    @Binding var showZone: Bool
    @Binding var tab: Tab
    @FocusState private var typing: Bool
    @State private var resolving = false
    @State private var driving = false
    @State private var hotelName = ""
    // DriveSession non si osserva qui (pubblica a ogni posizione): l'errore lo mostra DriveErrorText
    @State private var language: MessageLanguage = .en
    @State private var copied = false
    @State private var saved = false
    /// La prima pagina chiede il campo di ricerca già attivo quando si arriva da lì
    static var focusSearch = false

    var body: some View {
        TimelineView(.everyMinute) { ctx in
            // L'ora scelta nei chip (la stessa della prima pagina e della mappa); rimasta nel passato vale «adesso»
            let date = store.moment(ctx.date)
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
                            saveButton
                        } else {
                            emptyState
                        }
                        StatusBanner(status: store.city.status)
                        Text("Road signs on site always win over the app.")
                            .font(.app(size: 12)).foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
                .animation(.snappy, value: store.place)
                .animation(.snappy, value: store.when)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(Theme.ground)
        }
        .onAppear {
            search.focus(on: store.city)
            if Self.focusSearch {
                Self.focusSearch = false
                // Nel giro automatico delle foto la tastiera si apre solo con il tocco sul campo, come sempre
                guard !ProcessInfo.processInfo.arguments.contains("-uitest") else { return }
                Task { try? await Task.sleep(for: .milliseconds(350)); typing = true }
            }
        }
        .onChange(of: store.cityId) { search.focus(on: store.city) }
        .onChange(of: store.place) { planner.clear(); hotelName = "" }
        .fullScreenCover(isPresented: $driving) { DriveView() }
        .onChange(of: store.when) { planner.clear() }
        .onChange(of: store.activeVehicleId) { planner.clear() }
    }

    // MARK: Testata e ricerca

    private var header: some View {
        HStack {
            Text("Your trip").font(Theme.display(34)).foregroundStyle(Theme.ink)
            Spacer()
            Menu {
                ForEach(store.cities) { c in
                    Button(c.localizedName) { store.place = nil; store.cityId = c.id }
                }
            } label: {
                Label(store.city.localizedName, systemImage: "mappin.and.ellipse")
                    .font(.app(size: 14, weight: .semibold))
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
            TextField(String(format: L("Destination or hotel in %@"), store.city.localizedName), text: $search.query)
                .focused($typing)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .accessibilityIdentifier("trip.search")
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
        .font(.app(size: 16))
        .padding(.horizontal, 14).frame(height: 50)
        .card(14)
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 0) {
            if search.results.isEmpty {
                Text(search.failed ? L("Search isn't working right now. Check your connection.") : L("Keep typing…"))
                    .font(.app(size: 14)).foregroundStyle(Theme.muted).padding(14)
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
                        Image(systemName: "mappin.circle.fill").font(.app(size: 22)).foregroundStyle(Theme.red)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(r.title).font(.app(size: 15, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                            if !r.subtitle.isEmpty {
                                Text(r.subtitle).font(.app(size: 13)).foregroundStyle(Theme.muted).lineLimit(1)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("trip.result.\(i)")
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

    /// «Adesso ▾» e il veicolo: la stessa scelta della prima pagina e della mappa (Store.when, Store.activeVehicleId)
    private var whenRow: some View {
        ContextChips()
    }

    /// Vero se si guarda un'ora scelta (l'arrivo), non adesso
    private var atArrival: Bool { store.when.map { $0 > Date() } ?? false }

    private func heading(_ zone: Zone, _ date: Date) -> String {
        atArrival
            ? "\(zone.shortName) · \(store.engine.format(date, .dateTime.weekday(.abbreviated).hour().minute()))"
            : String(format: L("%@ · now %@"), zone.shortName, store.engine.format(date, .dateTime.hour().minute()))
    }

    // MARK: Risposta per l'indirizzo

    @ViewBuilder
    private func placeAnswer(_ place: Place, at date: Date) -> some View {
        let hits = store.zones(at: place.location)
        placeCard(place, inside: hits.first?.zone)
        if let area = store.pedestrianArea(at: place.location) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: L("Pedestrian area · %@"), area.name)).font(.app(size: 15, weight: .bold))
                    Text("Cars can't drive in here at any time, except authorised vehicles. Park outside and walk.")
                        .font(.app(size: 14))
                }
            } icon: { Image(systemName: "figure.walk.circle.fill").font(.app(size: 24)) }
            .foregroundStyle(.white)
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.red, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        if let hit = hits.first {
            VerdictCard(answer: store.pedestrianArea(at: place.location) != nil
                            ? Answer(verdict: .no(reason: L("It's a pedestrian area: cars can't drive in at any time, whatever the ZTL hours.")),
                                     gatesOn: true, nextChange: nil)
                            : store.answer(at: date, zone: hit.zone, hotelInside: false),
                        heading: heading(hit.zone, date),
                        source: hit.zone.source,
                        since: atArrival ? nil : store.engine.previousChange(hit.zone, before: date),
                        onWhy: { store.cityId = hit.city.id; store.zoneId = hit.zone.id; showZone = true })
            // Dopo la prima risposta: il guardiano accanto a Google Maps (un riquadro nella pagina, non sopra i pulsanti)
            TipView(StartGuardianTip()).tipBackground(Theme.card)
            if hits.count > 1 {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("Also inside")
                    zoneList(hits.dropFirst().map { $0.zone }, at: date)
                }
            }
            routeCard(place)
            // Rosso o ambra all'ora scelta: i parcheggi fuori da ogni ZTL attiva, poi a piedi
            if PlaceCheck(place, store: store, at: date).suggestsParking {
                ParkOutsideCard(destination: place, arrival: date, onStart: { target in
                    Task {
                        await DriveSession.shared.start(to: target, store: store)
                        driving = DriveSession.shared.active
                    }
                }, onGuardian: { target, navigator in
                    Guardian.shared.start(to: target, with: navigator, store: store)
                })
            }
            if let ticket = hit.zone.ticket, store.engine.isActive(hit.zone, at: date), store.pedestrianArea(at: place.location) == nil {
                TicketCard(zone: hit.zone, ticket: ticket, entry: date)
            }
            if hit.zone.hotelCanRegister {
                HotelStayCard(place: place, zone: hit.zone, arrival: atArrival ? arrivalTime : Date())
                hotelMessage
            }
        } else {
            outsideCard(place)
            TipView(StartGuardianTip()).tipBackground(Theme.card)
            routeCard(place)
        }
    }

    // MARK: Il percorso

    @ViewBuilder
    private func routeCard(_ place: Place) -> some View {
        if let plan = planner.plan, plan.destination == place {
            RouteCard(plan: plan, onMap: { tab = .map }, onStart: { target in
                Task {
                    await DriveSession.shared.start(to: target, store: store)
                    driving = DriveSession.shared.active
                }
            }, onGuardian: { target, navigator in
                StartGuardianTip().invalidate(reason: .actionPerformed)
                Guardian.shared.start(to: target, with: navigator, store: store)
            })
            DriveErrorText()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                WideButton(title: planner.working ? "Planning…" : "Check the drive", systemImage: "car.fill") {
                    Task {
                        await planner.plan(to: place, from: monitor.location?.coordinate ?? RoutePlanner.testOrigin,
                                           arrival: atArrival ? arrivalTime : nil, store: store)
                    }
                }
                .disabled(planner.working)
                .accessibilityIdentifier("trip.route")
                if let error = planner.error {
                    Text(error).font(.app(size: 13)).foregroundStyle(Theme.muted)
                } else {
                    Text("GateLR checks every ZTL on the way at the time you pass it.")
                        .font(.app(size: 12)).foregroundStyle(Theme.muted)
                }
            }
        }
    }

    private func placeCard(_ place: Place, inside zone: Zone?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: zone?.type.symbol ?? "checkmark")
                .font(.app(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(zone?.type.color ?? Theme.green, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(place.name).font(.app(size: 16, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                Text(zone.map { "\($0.type.title) · \($0.shortName)" } ?? L("Outside the ZTL"))
                    .font(.app(size: 13)).foregroundStyle(Theme.muted).lineLimit(1)
            }
            Spacer()
            Button { tab = .map } label: {
                Image(systemName: "map").font(.app(size: 15, weight: .semibold))
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
                Image(systemName: "checkmark").font(.app(size: 24, weight: .heavy)).foregroundStyle(Theme.green)
                    .frame(width: 52, height: 52).background(.white, in: Circle())
                VStack(alignment: .leading, spacing: -12) {
                    ForEach(L("Outside|the ZTL").components(separatedBy: "|"), id: \.self) { Text($0).font(Theme.display(34)) }
                }
            }
            Text("This address isn't inside any ZTL we know. You can drive there.").font(.app(size: 16))
            if let near, near.meters < 3_000 {
                let m = Measurement(value: near.meters, unit: UnitLength.meters).formatted(.measurement(width: .abbreviated, usage: .road))
                Text(String(format: L("The nearest zone, %@, is %@ away."), near.zone.shortName, m))
                    .font(.app(size: 14)).opacity(0.92)
                if near.meters < 150 {
                    Label("Very close to the border: follow the signs and don't cross a gate.", systemImage: "exclamationmark.triangle.fill")
                        .font(.app(size: 14, weight: .semibold))
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(.white)
        .background(Theme.green, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
    }

    // MARK: Senza destinazione

    @ViewBuilder
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Where are you going?", systemImage: "mappin.and.ellipse")
                .font(Theme.display(24)).foregroundStyle(Theme.ink)
            Text("Search your hotel or destination: GateLR tells you if you can drive there at that time, checks the ZTLs on the way and prepares the message for the hotel.")
                .font(.app(size: 15)).foregroundStyle(Theme.muted)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).card()
        hint("Search your destination for a precise answer.", symbol: "magnifyingglass", action: { typing = true })
        if !store.recent.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("Recent")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.recent) { p in
                            Button { store.select(p) } label: {
                                Label(p.name, systemImage: "clock.arrow.circlepath")
                                    .font(.app(size: 14, weight: .semibold)).lineLimit(1)
                                    .padding(.horizontal, 12).frame(height: 36)
                                    .background(Theme.card, in: Capsule())
                                    .foregroundStyle(Theme.ink)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        if store.trips.isEmpty {
            EmptyStateView(symbol: "suitcase.rolling.fill", badge: "bookmark.fill", title: "No saved trips",
                           text: "Search your hotel and tap «Save this trip»: it stays here and on the first page.",
                           action: "Search your hotel", actionSymbol: "magnifyingglass") { typing = true }
                .padding(16).card()
        } else {
            savedTrips
        }
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
                            .font(.app(size: 14, weight: .bold))
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
                if z.id != zones.last?.id { Divider().padding(.leading, 58) }
            }
        }
        .card()
    }

    private func hint(_ text: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol).foregroundStyle(Theme.blue)
                Text(L(text)).font(.app(size: 14)).foregroundStyle(Theme.ink).multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "chevron.right").font(.app(size: 12, weight: .bold)).foregroundStyle(Theme.muted)
            }
            .padding(14)
            .background(Theme.blueSoft.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var saveButton: some View {
        WideButton(title: saved ? "Trip saved" : "Save this trip", systemImage: saved ? "checkmark" : "bookmark", prominent: false) {
            let when = atArrival ? arrivalTime : Date()
            store.trips.insert(Trip(hotel: store.place, hotelName: hotelName.isEmpty ? (store.place?.name ?? "") : hotelName, arrival: when,
                                    departure: when.addingTimeInterval(86_400 * 2), vehicleId: store.vehicle.id), at: 0)
            saved = true
            Task { try? await Task.sleep(for: .seconds(1.5)); saved = false }
        }
        .sensoryFeedback(.success, trigger: saved) { _, new in new }
    }

    private var savedTrips: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Saved trips")
            VStack(spacing: 0) {
                ForEach(store.trips) { t in
                    let zone = t.hotel.flatMap { store.zones(at: $0.location).first?.zone }
                    Button {
                        if let h = t.hotel { store.select(h) }
                        // L'arrivo del viaggio e la sua auto diventano la scelta di tutta l'app
                        store.when = t.arrival > Date() ? t.arrival : nil
                        if let v = t.vehicleId, store.vehicles.contains(where: { $0.id == v }) { store.activeVehicleId = v }
                        hotelName = t.hotelName
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "suitcase.rolling.fill").foregroundStyle(Theme.blue)
                                .frame(width: 36, height: 36).background(Theme.blueSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(t.hotelName.isEmpty ? (t.hotel?.name ?? L("Trip")) : t.hotelName)
                                    .font(.app(size: 15, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                                Text(tripSubtitle(t, zone: zone))
                                    .font(.app(size: 13)).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            if t.arrival < Date() { Pill(text: L("Past"), fill: Theme.raised, ink: Theme.muted) }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) { store.trips.removeAll { $0.id == t.id } } label: { Label("Delete", systemImage: "trash") }
                    }
                    if t.id != store.trips.last?.id { Divider().padding(.leading, 62) }
                }
            }
            .card()
            Text("Touch and hold a trip to delete it.").font(.app(size: 12)).foregroundStyle(Theme.muted)
        }
    }

    private func tripSubtitle(_ t: Trip, zone: Zone?) -> String {
        let when: String = store.engine.format(t.arrival, .dateTime.day().month().hour().minute())
        let where_: String? = zone?.shortName ?? (t.hotel == nil ? nil : L("Outside the ZTL"))
        return [when, where_].compactMap { $0 }.joined(separator: " · ")
    }

    private var hotelMessage: some View {
        let name = hotelName.isEmpty ? store.place?.name : hotelName
        // Le stesse date del riquadro «Registrazione della targa» (di serie: due notti)
        let stay = store.place.flatMap { store.stays[$0.key] }
        let start: Date = stay?.arrival ?? (atArrival ? arrivalTime : Date())
        let end: Date = stay?.departure ?? (RuleEngine.rome.date(byAdding: .day, value: 2, to: start) ?? start)
        let text = language.message(arrival: start,
                                    plate: store.vehicle.plate.isEmpty ? "[PLATE]" : store.vehicle.plate,
                                    hotel: name, departure: end)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel("Message for the hotel")
                Spacer()
                Picker("Message language", selection: $language) {
                    ForEach(MessageLanguage.allCases) { Text($0.rawValue.uppercased()).tag($0) }
                }
                .pickerStyle(.segmented).frame(width: 140)
            }
            Text(text).font(.app(size: 14)).padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .textSelection(.enabled)
            if store.vehicle.plate.isEmpty {
                Label("Add your plate in Garage to fill it in.", systemImage: "info.circle")
                    .font(.app(size: 12)).foregroundStyle(Theme.muted)
            }
            HStack(spacing: 10) {
                ShareLink(item: text) {
                    Label("Send to hotel", systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Color(hex: 0x1F4E9E), in: RoundedRectangle(cornerRadius: 14, style: .continuous)).foregroundStyle(.white)
                }
                Button {
                    UIPasteboard.general.string = text
                    copied = true
                    Task { try? await Task.sleep(for: .seconds(1.5)); copied = false }
                } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Theme.blueSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous)).foregroundStyle(Theme.blue)
                }
                .sensoryFeedback(.success, trigger: copied) { _, new in new }
            }
            .font(.app(size: 15, weight: .semibold))
        }
        .padding(14).card()
    }

    /// L'arrivo scelto, mai nel passato: il selettore lo mostra dal minuto attuale, ma la data salvata
    /// poteva restare quella di ore prima (viaggio salvato, percorso e messaggio per l'hotel con un giorno passato)
    private var arrivalTime: Date { max(store.moment(), Self.minuteFloor(Date())) }

    static func minuteFloor(_ d: Date) -> Date {
        Date(timeIntervalSinceReferenceDate: (d.timeIntervalSinceReferenceDate / 60).rounded(.down) * 60)
    }

    /// La prossima volta che sono le «hour» in Italia (oggi o domani), più «days» giorni
    static func upcoming(hour: Int, days: Int = 0) -> Date {
        let c = RuleEngine.rome
        let next = c.nextDate(after: Date(), matching: DateComponents(hour: hour, minute: 0, second: 0), matchingPolicy: .nextTime) ?? Date()
        return c.date(byAdding: .day, value: days, to: next) ?? next
    }

    static func at(dayOffset: Int, hour: Int) -> Date {
        let c = Calendar.current
        let day = c.date(byAdding: .day, value: dayOffset, to: Date())!
        return c.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
    }

    static func next(weekday: Int, hour: Int) -> Date {
        let c = Calendar.current
        let comps = DateComponents(hour: hour, minute: 0, second: 0, weekday: weekday)
        return c.nextDate(after: Date(), matching: comps, matchingPolicy: .nextTime) ?? Date()
    }
}

/// L'errore dell'ultima guida avviata: solo questa piccola vista osserva DriveSession
private struct DriveErrorText: View {
    @ObservedObject private var drive = DriveSession.shared
    var body: some View {
        if let e = drive.error { Text(e).font(.app(size: 13)).foregroundStyle(Theme.red) }
    }
}

enum MessageLanguage: String, CaseIterable, Identifiable {
    case it, en, de
    var id: String { rawValue }

    func message(arrival: Date, plate: String, hotel: String? = nil, departure: Date? = nil) -> String {
        let locale = Locale(identifier: rawValue)
        // Giorni e ora in Italia: l'hotel legge l'ora locale, non quella del telefono di chi scrive
        let day = RuleEngine.format(arrival, .dateTime.weekday(.wide).day().month(.wide).locale(locale))
        let time = RuleEngine.format(arrival, .dateTime.hour().minute().locale(locale))
        let until = departure.map { RuleEngine.format($0, .dateTime.weekday(.wide).day().month(.wide).locale(locale)) }
        switch self {
        case .en:
            let to = hotel.map { "Dear \($0) team,\n\n" } ?? "Hello,\n\n"
            let span = until.map { " I'll leave on \($0). Please register it for every day, including the day I leave, and confirm in writing that it's done." } ?? " Please confirm in writing that it's done."
            return "\(to)I'm arriving by car on \(day) at about \(time). Could you please register my plate \(plate) for the ZTL, so I can reach the hotel without a fine?\(span)\n\nThank you!"
        case .it:
            let to = hotel.map { "Gentile staff di \($0),\n\n" } ?? "Buongiorno,\n\n"
            let span = until.map { " Riparto \($0): vi chiedo di registrarla per tutti i giorni, compreso quello di partenza, e di confermarmelo per iscritto." } ?? " Vi chiedo di confermarmelo per iscritto."
            return "\(to)arrivo in auto \(day) verso le \(time). Potete registrare la mia targa \(plate) per la ZTL, così raggiungo l'hotel senza multa?\(span)\n\nGrazie!"
        case .de:
            let to = hotel.map { "Liebes Team von \($0),\n\n" } ?? "Guten Tag,\n\n"
            let span = until.map { " Ich reise am \($0) ab. Bitte melden Sie es für jeden Tag an, auch für den Abreisetag, und bestätigen Sie es mir schriftlich." } ?? " Bitte bestätigen Sie es mir schriftlich."
            return "\(to)ich komme am \(day) gegen \(time) mit dem Auto an. Könnten Sie bitte mein Kennzeichen \(plate) für die ZTL anmelden, damit ich das Hotel ohne Bußgeld erreiche?\(span)\n\nVielen Dank!"
        }
    }
}
