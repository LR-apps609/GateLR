import SwiftUI
import UserNotifications

/// «Hotel sicuro»: i giorni da coprire (anche la partenza), lo stato della registrazione della targa,
/// gli errori più comuni e il promemoria il giorno prima. Con la conferma scritta diventa un permesso nel Garage.
struct HotelStayCard: View {
    @EnvironmentObject var store: Store
    var place: Place
    var zone: Zone
    var arrival: Date

    private var stay: HotelStay {
        store.stays[place.key] ?? HotelStay(arrival: arrival, departure: RuleEngine.rome.date(byAdding: .day, value: 2, to: arrival) ?? arrival)
    }

    private func edit(_ change: (inout HotelStay) -> Void) {
        var s = stay
        change(&s)
        store.stays[place.key] = s
        syncPermit(s)
        scheduleReminder(s)
    }

    var body: some View {
        let s = stay
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel("Plate registration")
                Spacer()
                statusPill(s.status)
            }
            DatePicker(L("Arrival"), selection: Binding(get: { s.arrival }, set: { v in edit { $0.arrival = v; if $0.departure < v { $0.departure = v } } }),
                       displayedComponents: [.date])
                .environment(\.timeZone, RuleEngine.rome.timeZone)
            DatePicker(L("Departure"), selection: Binding(get: { s.departure }, set: { v in edit { $0.departure = v } }),
                       in: s.arrival..., displayedComponents: [.date])
                .environment(\.timeZone, RuleEngine.rome.timeZone)
            // I giorni da coprire, uno per uno
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(s.days, id: \.self) { d in
                        VStack(spacing: 1) {
                            // I giorni sono mezzanotti di Roma: scritti in ora italiana, non nel fuso del telefono
                            Text(RuleEngine.format(d, .dateTime.weekday(.abbreviated))).font(.app(size: 11, weight: .semibold))
                            Text(RuleEngine.format(d, .dateTime.day())).font(Theme.display(18))
                        }
                        .frame(width: 44, height: 50)
                        .background(s.status == .confirmed ? Theme.greenSoft : Theme.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .foregroundStyle(s.status == .confirmed ? Theme.greenInk : Theme.ink)
                    }
                }
            }
            Text(String(format: L("%lld days to register, including the day you leave."), s.days.count))
                .font(.app(size: 13)).foregroundStyle(Theme.muted)
            Picker(L("Status"), selection: Binding(get: { s.status }, set: { v in edit { $0.status = v } })) {
                Text("Not asked").tag(HotelStay.Status.notAsked)
                Text("Asked").tag(HotelStay.Status.asked)
                Text("Confirmed").tag(HotelStay.Status.confirmed)
            }
            .pickerStyle(.segmented)
            if store.vehicle.isRental && store.vehicle.plate.isEmpty {
                Label("Rental car: you'll know the plate only at pick-up. Add it in Garage then, and send the message to the hotel straight away.",
                      systemImage: "key.fill")
                    .font(.app(size: 13, weight: .semibold)).foregroundStyle(Theme.blue)
            }
            VStack(alignment: .leading, spacing: 6) {
                tip("A parking permit on the dashboard is not a ZTL registration.")
                tip("Ask for a written confirmation with your plate and every date.")
                tip("Usually one way in and one way out: don't drive in and out of the ZTL.")
                tip("Rental car? Use the plate of the car you actually get.")
            }
            if s.status == .confirmed {
                Label("Saved as a permit in Garage: GateLR now answers \"yes\" for these days.", systemImage: "checkmark.seal.fill")
                    .font(.app(size: 13, weight: .semibold)).foregroundStyle(Theme.greenInk)
            }
        }
        .padding(14).card()
    }

    private func tip(_ text: String) -> some View {
        Label { Text(L(text)).font(.app(size: 13)) } icon: { Image(systemName: "exclamationmark.circle").foregroundStyle(Theme.amberInk) }
            .foregroundStyle(Theme.ink)
    }

    private func statusPill(_ s: HotelStay.Status) -> some View {
        switch s {
        case .notAsked: Pill(text: L("Not asked"), fill: Color(light: 0xF8DADB, dark: 0x3D1A1C), ink: Color(light: 0x9E1F25, dark: 0xF59A96))
        case .asked: Pill(text: L("Waiting"), fill: Theme.amberSoft, ink: Theme.amberInk)
        case .confirmed: Pill(text: L("Confirmed"), fill: Theme.greenSoft, ink: Theme.greenInk)
        }
    }

    /// Confermato per iscritto → permesso «registrazione hotel» per quella zona e quei giorni
    private func syncPermit(_ s: HotelStay) {
        if let id = s.permitId { store.permits.removeAll { $0.id == id } }
        guard s.status != .notAsked else {
            if s.permitId != nil { store.stays[place.key]?.permitId = nil }
            return
        }
        let c = RuleEngine.rome            // il permesso vale dalla mezzanotte alle 23:59 di Roma, come legge il motore
        let to = c.date(bySettingHour: 23, minute: 59, second: 0, of: s.departure) ?? s.departure
        let permit = Permit(kind: .hotelRegistration, cityId: store.cities.first { $0.zones.contains(zone) }?.id ?? store.city.id,
                            zoneId: zone.id, vehicleId: store.vehicle.id, from: c.startOfDay(for: s.arrival), to: to,
                            status: s.status == .confirmed ? .confirmed : .waiting)
        store.permits.append(permit)
        store.stays[place.key]?.permitId = permit.id
    }

    /// Il giorno prima dell'arrivo alle 18, se la conferma non c'è ancora
    private func scheduleReminder(_ s: HotelStay) {
        let center = UNUserNotificationCenter.current()
        let id = "stay|\(place.key)"
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard s.status != .confirmed,
              let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: s.arrival),
              let when = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: dayBefore), when > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = String(format: L("Tomorrow: %@"), place.name)
        content.body = L("Has the hotel confirmed in writing that your plate is registered for every day? Without it, the gates fine you.")
        content.sound = .default
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: when)
        Task {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
            try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
        }
    }
}
