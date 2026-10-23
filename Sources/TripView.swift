import SwiftUI
import UIKit

/// «Viaggio»: l'indirizzo dell'hotel (l'app capisce da sola se è in ZTL), la risposta per l'ora di arrivo,
/// il messaggio pronto per l'hotel e i viaggi salvati.
struct TripView: View {
    @EnvironmentObject var store: Store
    @Binding var showZone: Bool
    @StateObject private var search = AddressSearch()
    @FocusState private var typing: Bool
    @State private var arrival = TripView.at(dayOffset: 3, hour: 18)
    @State private var hotel: Place?
    @AppStorage("hotelName") private var hotelName = ""
    @State private var language: MessageLanguage = .en
    @State private var copied = false
    @State private var saved = false

    /// La zona dell'hotel: dall'indirizzo se c'è, altrimenti dalla scelta a mano
    private var hotelZone: Zone? {
        if let hotel { return store.zones(at: hotel.location).first?.zone }
        return store.hotelInside ? store.zone : nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    hotelCard
                    if typing && !search.query.isEmpty {
                        suggestions
                    } else {
                        arrivalCard
                        if let zone = hotelZone {
                            VerdictCard(answer: store.answer(at: arrival, zone: zone, hotelInside: true),
                                        heading: "\(zone.shortName) · \(arrival.formatted(.dateTime.weekday(.wide).day().month().hour().minute()))",
                                        source: zone.source,
                                        onWhy: { selectZone(zone); showZone = true })
                            if zone.hotelCanRegister { hotelMessage }
                        } else if hotel != nil {
                            outsideCard
                        }
                        saveButton
                        if !store.trips.isEmpty { savedTrips }
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                .animation(.snappy, value: hotel)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(Theme.ground)
            .navigationTitle("Your trip")
            .onAppear { search.focus(on: store.city) }
        }
    }

    // MARK: Hotel

    private var hotelCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "building.2").foregroundStyle(Theme.blue)
                TextField(L("Hotel address or name"), text: $search.query)
                    .focused($typing).autocorrectionDisabled()
                    .accessibilityIdentifier("trip.search")
                if !search.query.isEmpty || hotel != nil {
                    Button { search.clear(); hotel = nil } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.muted) }
                        .accessibilityLabel(L("Clear"))
                }
            }
            .padding(14)
            if let hotel, !(typing && !search.query.isEmpty) {
                Divider().padding(.leading, 14)
                let zone = store.zones(at: hotel.location).first?.zone
                HStack(spacing: 12) {
                    Image(systemName: zone?.type.symbol ?? "checkmark")
                        .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(zone?.type.color ?? Theme.green, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(hotel.name).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                        Text(zone.map { String(format: L("Inside the ZTL · %@"), $0.shortName) } ?? L("Outside the ZTL"))
                            .font(.system(size: 13)).foregroundStyle(zone == nil ? Theme.greenInk : Theme.muted)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                Divider().padding(.leading, 14)
                HStack {
                    Text("Name in the message").font(.system(size: 14)).foregroundStyle(Theme.muted)
                    TextField(L("Hotel name"), text: $hotelName).multilineTextAlignment(.trailing).textInputAutocapitalization(.words)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
            } else if hotel == nil && !(typing && !search.query.isEmpty) {
                Divider().padding(.leading, 14)
                Toggle(L("Hotel is inside the ZTL"), isOn: $store.hotelInside).padding(.horizontal, 14).padding(.vertical, 8)
                if store.hotelInside {
                    Divider().padding(.leading, 14)
                    Picker(L("Sector"), selection: $store.zoneId) {
                        ForEach(store.city.zones) { Text($0.localizedName).tag($0.id) }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 4)
                }
            }
        }
        .card()
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
                        if let place = await search.resolve(r) { choose(place) }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(r.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                        if !r.subtitle.isEmpty { Text(r.subtitle).font(.system(size: 13)).foregroundStyle(Theme.muted).lineLimit(1) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("trip.result.\(i)")
                if i < search.results.count - 1 { Divider().padding(.leading, 14) }
            }
        }
        .card()
    }

    private func choose(_ place: Place) {
        hotel = place
        hotelName = place.name
        search.query = ""
        typing = false
        if let hit = store.zones(at: place.location).first { selectZone(hit.zone) }
    }

    private func selectZone(_ zone: Zone) {
        if let city = store.cities.first(where: { $0.zones.contains(zone) }) { store.cityId = city.id }
        store.zoneId = zone.id
    }

    private var outsideCard: some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your hotel is outside the ZTL").font(Theme.display(24))
                Text("You can drive there at any time. Inside the old town, check before you go further.").font(.system(size: 15))
            }
        } icon: {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 28))
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(.white)
        .background(Theme.green, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: Arrivo

    private var arrivalCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            DatePicker(selection: $arrival, in: Date()...) {
                Label("Arrival", systemImage: "calendar").foregroundStyle(Theme.blue)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("Tonight 9 pm", TripView.at(dayOffset: 0, hour: 21))
                    chip("Tomorrow 10 am", TripView.at(dayOffset: 1, hour: 10))
                    chip("Saturday 6 pm", TripView.next(weekday: 7, hour: 18))
                    chip("Sunday noon", TripView.next(weekday: 1, hour: 12))
                }
                .padding(.horizontal, 14).padding(.bottom, 10)
            }
        }
        .card()
    }

    // MARK: Viaggi salvati

    private var saveButton: some View {
        WideButton(title: saved ? "Trip saved" : "Save this trip", systemImage: saved ? "checkmark" : "bookmark", prominent: false) {
            store.trips.insert(Trip(hotel: hotel, hotelName: hotelName, arrival: arrival,
                                    departure: arrival.addingTimeInterval(86_400 * 2), vehicleId: store.vehicle.id), at: 0)
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
                        arrival = max(t.arrival, Date())
                        if let h = t.hotel { choose(h) } else { hotel = nil }
                        hotelName = t.hotelName
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "suitcase.rolling.fill").foregroundStyle(Theme.blue)
                                .frame(width: 36, height: 36).background(Theme.blueSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(t.hotelName.isEmpty ? (t.hotel?.name ?? L("Trip")) : t.hotelName)
                                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                                Text([t.arrival.formatted(.dateTime.day().month().hour().minute()), zone?.shortName ?? (t.hotel == nil ? nil : L("Outside the ZTL"))]
                                        .compactMap { $0 }.joined(separator: " · "))
                                    .font(.system(size: 13)).foregroundStyle(Theme.muted)
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
            Text("Touch and hold a trip to delete it.").font(.system(size: 12)).foregroundStyle(Theme.muted)
        }
    }

    private func chip(_ title: String, _ date: Date) -> some View {
        let on = abs(arrival.timeIntervalSince(date)) < 60
        return Button { withAnimation(.snappy) { arrival = date } } label: {
            Text(title).font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 12).frame(height: 32)
                .background(on ? Color(hex: 0x1F4E9E) : Theme.blueSoft, in: Capsule())
                .foregroundStyle(on ? .white : Theme.blue)
        }
        .buttonStyle(.plain)
    }

    private var hotelMessage: some View {
        let text = language.message(arrival: arrival,
                                    plate: store.vehicle.plate.isEmpty ? "[PLATE]" : store.vehicle.plate,
                                    hotel: hotelName.isEmpty ? nil : hotelName)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel("Message for the hotel")
                Spacer()
                Picker("Message language", selection: $language) {
                    ForEach(MessageLanguage.allCases) { Text($0.rawValue.uppercased()).tag($0) }
                }
                .pickerStyle(.segmented).frame(width: 140)
            }
            Text(text).font(.system(size: 14)).padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .textSelection(.enabled)
            if store.vehicle.plate.isEmpty {
                Label("Add your plate in Garage to fill it in.", systemImage: "info.circle")
                    .font(.system(size: 12)).foregroundStyle(Theme.muted)
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
            .font(.system(size: 15, weight: .semibold))
        }
        .padding(14).card()
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

enum MessageLanguage: String, CaseIterable, Identifiable {
    case it, en, de
    var id: String { rawValue }

    func message(arrival: Date, plate: String, hotel: String? = nil) -> String {
        let locale = Locale(identifier: rawValue)
        let day = arrival.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(locale))
        let time = arrival.formatted(.dateTime.hour().minute().locale(locale))
        switch self {
        case .en:
            let to = hotel.map { "Dear \($0) team,\n\n" } ?? "Hello,\n\n"
            return "\(to)I'm arriving by car on \(day) at about \(time). Could you please register my plate \(plate) for the ZTL, so I can reach the hotel without a fine?\n\nThank you!"
        case .it:
            let to = hotel.map { "Gentile staff di \($0),\n\n" } ?? "Buongiorno,\n\n"
            return "\(to)arrivo in auto \(day) verso le \(time). Potete registrare la mia targa \(plate) per la ZTL, così raggiungo l'hotel senza multa?\n\nGrazie!"
        case .de:
            let to = hotel.map { "Liebes Team von \($0),\n\n" } ?? "Guten Tag,\n\n"
            return "\(to)ich komme am \(day) gegen \(time) mit dem Auto an. Könnten Sie bitte mein Kennzeichen \(plate) für die ZTL anmelden, damit ich das Hotel ohne Bußgeld erreiche?\n\nVielen Dank!"
        }
    }
}
