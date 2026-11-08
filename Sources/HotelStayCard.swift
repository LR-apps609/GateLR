import SwiftUI
import UserNotifications

/// «Hotel sicuro»: i giorni da coprire (anche la partenza), lo stato della registrazione della targa,
/// gli errori più comuni e il promemoria il giorno prima. Con la conferma scritta diventa un permesso nel Garage.
/// 2.0: il permesso resta al veicolo per cui l'hotel registra la targa (B16), uno per ogni zona che accetta la
/// registrazione (B72), mai confermato senza targa; promemoria in ora italiana e solo se iOS lo accetta (B70, B141)
struct HotelStayCard: View {
    @EnvironmentObject var store: Store
    var place: Place
    /// Le zone del posto che accettano la registrazione dell'hotel (zone annidate: anche quella grande che decide)
    var zones: [Zone]
    var arrival: Date
    /// Lo stato scelto che aspetta la conferma nel dialogo
    @State private var pending: HotelStay.Status?
    /// «Confermato» senza targa: prima si aggiunge la targa nel Garage
    @State private var needsPlate = false
    /// Il promemoria non è stato accettato da iOS (notifiche spente)
    @State private var remindersOff = false

    private var stay: HotelStay { store.stay(for: place, arrival: arrival) }

    private func edit(_ change: (inout HotelStay) -> Void) {
        var s = stay
        change(&s)
        s = store.syncHotelPermits(s, zones: zones)
        store.stays[place.key] = s
        Task { remindersOff = !(await store.scheduleStayReminder(for: place, stay: s)) }
    }

    /// Il veicolo per cui l'hotel registra la targa (quello scelto quando l'hai chiesto), se non è quello in uso
    private var otherVehicle: Vehicle? {
        let s = stay
        guard s.status != .notAsked, let id = s.vehicleId, id != store.vehicle.id else { return nil }
        return store.vehicles.first { $0.id == id }
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
            // 1.19.2: «Chiesto» e «Confermato» cambiano la risposta per la zona dell'hotel: si salvano dopo il dialogo.
            // 2.0 (B16): con un altro veicolo in uso si chiede di nuovo il consenso (il permesso passa a lui solo così)
            Picker(L("Status"), selection: Binding(get: { s.status }, set: { v in choose(v, from: s) })) {
                Text("Not asked").tag(HotelStay.Status.notAsked)
                Text("Asked").tag(HotelStay.Status.asked)
                Text("Confirmed").tag(HotelStay.Status.confirmed)
            }
            .pickerStyle(.segmented)
            if let other = otherVehicle {
                Label(String(format: L("The hotel registers the plate of %@. For this vehicle, ask the hotel again."), PlatePrivacy.displayName(other)),
                      systemImage: "car.2.fill")
                    .font(.app(size: 13, weight: .semibold)).foregroundStyle(Theme.amberInk)
                    .accessibilityIdentifier("stay.otherVehicle")
            }
            if needsPlate {
                Label("Add your plate in Garage first.", systemImage: "number.square")
                    .font(.app(size: 13, weight: .semibold)).foregroundStyle(Theme.amberInk)
            }
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
            if remindersOff && s.status != .confirmed { RemindersOffNote() }
        }
        .padding(14).card()
        .confirmationDialog(L(pending == .confirmed ? "Do you have the written confirmation?" : "Save this permit?"),
                            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }), titleVisibility: .visible) {
            Button(L(pending == .confirmed ? "Yes, I have it in writing" : "Save the permit")) {
                if let v = pending { edit { $0.status = v; $0.vehicleId = store.vehicle.id } }
                pending = nil
            }
            Button(L("Cancel"), role: .cancel) { pending = nil }
        } message: {
            Text(verbatim: String(format: L(pending == .confirmed
                    ? "Confirm only if the hotel has confirmed in writing that your plate is registered for every day. GateLR will answer \"yes\" only in %@, only for these days."
                    : "GateLR will answer \"on one condition\" in %@ for these days, until the hotel confirms in writing."),
                                  zones.map(\.localizedName).joined(separator: ", ")))
        }
    }

    /// Un nuovo stato dal selettore: verso il «sì», o per un altro veicolo, solo dopo il dialogo; mai «Confermato» senza targa
    private func choose(_ v: HotelStay.Status, from s: HotelStay) {
        needsPlate = false
        if v == .confirmed && store.vehicle.plate.isEmpty { needsPlate = true; return }
        let otherCar = s.vehicleId.map { $0 != store.vehicle.id } ?? false
        if v != .notAsked && (otherCar || Permit.Status.needsConsent(from: s.status.permitStatus, to: v.permitStatus)) {
            pending = v
        } else {
            edit { $0.status = v }
        }
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
}

extension HotelStay.Status {
    /// Il permesso che lo stato del soggiorno crea nel Garage (vedi Store.syncHotelPermits)
    var permitStatus: Permit.Status? {
        switch self {
        case .notAsked: nil
        case .asked: .waiting
        case .confirmed: .confirmed
        }
    }
}

extension Store {
    /// Il soggiorno salvato per il posto, o quello di serie (due notti dall'arrivo). 2.0 (B71): se i suoi permessi sono
    /// spariti (cancellati dal Garage) lo stato torna «Non chiesto», invece di dire ancora «Confermato»
    func stay(for place: Place, arrival: Date) -> HotelStay {
        guard var s = stays[place.key] else {
            return HotelStay(arrival: arrival, departure: RuleEngine.rome.date(byAdding: .day, value: 2, to: arrival) ?? arrival)
        }
        let ids = s.allPermitIds
        if s.status != .notAsked, !ids.isEmpty, !permits.contains(where: { ids.contains($0.id) }) {
            s.status = .notAsked; s.permitId = nil; s.permitIds = nil
        }
        return s
    }

    /// Confermato per iscritto (o chiesto) → un permesso «registrazione hotel» per ogni zona e per quei giorni, per il
    /// veicolo del soggiorno. 2.0 (B16): il veicolo è quello scelto alla richiesta (stay.vehicleId), non quello in uso;
    /// mai un permesso confermato per un veicolo senza targa. 2.0 (B72): un permesso per ogni zona (prima una sola)
    func syncHotelPermits(_ stay: HotelStay, zones: [Zone]) -> HotelStay {
        var s = stay
        let old = Set(s.allPermitIds)
        if !old.isEmpty { permits.removeAll { old.contains($0.id) } }
        s.permitId = nil; s.permitIds = nil
        guard s.status != .notAsked else { return s }
        let vehicleId = s.vehicleId ?? vehicle.id
        s.vehicleId = vehicleId
        let plate = vehicles.first { $0.id == vehicleId }?.plate ?? ""
        let status: Permit.Status = s.status == .confirmed && !plate.isEmpty ? .confirmed : .waiting
        let c = RuleEngine.rome            // il permesso vale dalla mezzanotte alle 23:59 di Roma, come legge il motore
        let to = c.date(bySettingHour: 23, minute: 59, second: 0, of: s.departure) ?? s.departure
        let made = zones.map { zone in
            Permit(kind: .hotelRegistration, cityId: cities.first { $0.zones.contains(zone) }?.id ?? city.id,
                   zoneId: zone.id, vehicleId: vehicleId, from: c.startOfDay(for: s.arrival), to: to, status: status)
        }
        permits.append(contentsOf: made)
        s.permitIds = made.map(\.id)
        return s
    }

    /// 2.0 (B71): il soggiorno di un viaggio cancellato sparisce con i suoi permessi e il promemoria
    func removeStay(key: String) {
        guard let s = stays[key] else { return }
        let ids = Set(s.allPermitIds)
        if !ids.isEmpty { permits.removeAll { ids.contains($0.id) } }
        stays[key] = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["stay|\(key)"])
    }

    /// 2.0 (B71): un permesso tolto dal Garage riporta il suo soggiorno a «Non chiesto»
    func forgetStayPermits(_ gone: Set<UUID>) {
        for (key, var s) in stays where !Set(s.allPermitIds).isDisjoint(with: gone) {
            let left = s.allPermitIds.filter { !gone.contains($0) }
            s.permitId = nil
            s.permitIds = left.isEmpty ? nil : left
            if left.isEmpty { s.status = .notAsked }
            stays[key] = s
        }
    }

    /// Il promemoria del soggiorno: il giorno prima dell'arrivo alle 18 ora italiana (2.0, B141: prima nel fuso del
    /// telefono), se la conferma non c'è ancora. Falso se iOS non lo accetta (notifiche spente)
    @discardableResult
    func scheduleStayReminder(for place: Place, stay s: HotelStay, now: Date = Date()) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let id = "stay|\(place.key)"
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard s.status != .confirmed, let when = Self.stayReminderDate(arrival: s.arrival), when > now else { return true }
        let content = UNMutableNotificationContent()
        content.title = String(format: L("Tomorrow: %@"), place.name)
        content.body = L("Has the hotel confirmed in writing that your plate is registered for every day? Without it, the gates fine you.")
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: when.timeIntervalSince(now), repeats: false)
        return await Reminders.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    /// Il giorno prima dell'arrivo alle 18:00 a Roma (testabile)
    nonisolated static func stayReminderDate(arrival: Date) -> Date? {
        let c = RuleEngine.rome
        guard let dayBefore = c.date(byAdding: .day, value: -1, to: c.startOfDay(for: arrival)) else { return nil }
        return c.date(bySettingHour: 18, minute: 0, second: 0, of: dayBefore)
    }
}
