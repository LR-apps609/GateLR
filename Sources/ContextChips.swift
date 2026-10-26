import SwiftUI

// «Adesso ▾» e «Golf · benzina Euro 6 ▾»: l'ora e il veicolo per cui rispondono la prima pagina, la mappa,
// la scheda del posto e Viaggio. Una sola scelta per tutta l'app (Store.when, Store.activeVehicleId):
// il veicolo resta salvato, l'ora torna «Adesso» a ogni avvio.

/// Il simbolo giusto fra due (i nomi dei simboli fuori dalle frasi da tradurre di Tools/check_strings.py)
enum Symbols {
    static func pick(_ condition: Bool, _ yes: String, else no: String) -> String { condition ? yes : no }
}

/// Le scorciatoie dell'ora, in ora italiana come il motore delle regole
enum TimeChoice {
    /// Le 20:00 di oggi a Roma, se non sono già passate
    static func tonight(now: Date = Date(), calendar: Calendar = RuleEngine.rome) -> Date? {
        guard let t = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now), t > now else { return nil }
        return t
    }

    /// Le 9:00 di domani a Roma
    static func tomorrowMorning(now: Date = Date(), calendar: Calendar = RuleEngine.rome) -> Date {
        let day = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day
    }

    /// L'ora scelta, mai nel passato: nil o un'ora già passata (app ripresa dopo ore) valgono «adesso»
    static func effective(_ when: Date?, now: Date = Date()) -> Date {
        guard let when, when > now else { return now }
        return when
    }

    /// Il testo del chip: «Adesso», «Stasera 20:00», «Domani 09:00», «mar 27 ott, 18:30»
    static func label(_ when: Date?, now: Date = Date(), calendar: Calendar = RuleEngine.rome) -> String {
        guard let when, when > now else { return L("Now") }
        let time = RuleEngine.format(when, .init(date: .omitted, time: .shortened), calendar: calendar)
        if calendar.isDate(when, inSameDayAs: now) {
            return calendar.component(.hour, from: when) >= 18 ? String(format: L("Tonight %@"), time) : String(format: L("Today %@"), time)
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(when, inSameDayAs: tomorrow) {
            return String(format: L("Tomorrow %@"), time)
        }
        return RuleEngine.format(when, .dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute(), calendar: calendar)
    }
}

extension Vehicle {
    /// «Golf · benzina Euro 6» (le elettriche senza classe Euro)
    var chipLabel: String {
        let car = name.isEmpty ? [make ?? "", model].filter { !$0.isEmpty }.joined(separator: " ") : name
        // In tedesco i nomi restano maiuscoli («Benzin»)
        let german = Locale.current.language.languageCode?.identifier == "de"
        let fuelText = german ? fuel.label : fuel.label.lowercased()
        let spec = fuel == .electric ? fuelText : "\(fuelText) Euro \(euro)"
        return car.isEmpty ? spec : "\(car) · \(spec)"
    }
}

extension Store {
    /// L'ora per cui rispondono le pagine: quella scelta nel chip o adesso
    func moment(_ now: Date = Date()) -> Date { TimeChoice.effective(when, now: now) }
}

/// I due chip, uno accanto all'altro. «material»: sopra la mappa, sul vetro smerigliato
struct ContextChips: View {
    @EnvironmentObject var store: Store
    var material = false
    @State private var picking = false
    @State private var newVehicle: Vehicle?
    @State private var newId: UUID?

    var body: some View {
        HStack(spacing: 8) {
            timeMenu
            vehicleMenu
            Spacer(minLength: 0)
        }
        .sheet(isPresented: $picking) { TimePickerSheet().environmentObject(store).presentationDetents([.large]) }
        .sheet(item: $newVehicle, onDismiss: activateNew) { v in VehicleForm(vehicle: v).environmentObject(store) }
    }

    /// Il veicolo appena creato dal chip diventa quello in uso, se è stato salvato
    private func activateNew() {
        if let id = newId, store.vehicles.contains(where: { $0.id == id }) { store.activeVehicleId = id }
        newId = nil
    }

    private var timeMenu: some View {
        let now = Date()
        return Menu {
            Button { store.when = nil } label: { Label(L("Now"), systemImage: Symbols.pick(store.when == nil, "checkmark", else: "clock")) }
            if let t = TimeChoice.tonight(now: now) {
                Button { store.when = t } label: { Text(TimeChoice.label(t, now: now)) }
            }
            let tomorrow = TimeChoice.tomorrowMorning(now: now)
            Button { store.when = tomorrow } label: { Text(TimeChoice.label(tomorrow, now: now)) }
            Button { picking = true } label: { Label(L("Pick a day and time…"), systemImage: "calendar") }
        } label: {
            chip(symbol: Symbols.pick(store.when == nil, "clock", else: "clock.badge.checkmark"), text: TimeChoice.label(store.when, now: now),
                 highlighted: store.when != nil)
        }
        .accessibilityLabel(String(format: L("Time: %@"), TimeChoice.label(store.when, now: now)))
        .accessibilityIdentifier("context.time")
    }

    private var vehicleMenu: some View {
        Menu {
            ForEach(store.vehicles) { v in
                Button { store.activeVehicleId = v.id } label: {
                    if v.id == store.vehicle.id { Label(v.chipLabel, systemImage: "checkmark") } else { Text(v.chipLabel) }
                }
            }
            Divider()
            Button {
                let v = Vehicle(name: "", fuel: .petrol, euro: 6)
                newId = v.id
                newVehicle = v
            } label: { Label(L("Add a vehicle"), systemImage: "plus") }
        } label: {
            chip(symbol: "car.fill", text: store.vehicle.chipLabel, highlighted: false)
        }
        .accessibilityLabel(String(format: L("Vehicle: %@"), store.vehicle.chipLabel))
        .accessibilityIdentifier("context.vehicle")
    }

    private func chip(symbol: String, text: String, highlighted: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.app(size: 12, weight: .semibold))
            Text(verbatim: text).lineLimit(1)
            Image(systemName: "chevron.down").font(.app(size: 10, weight: .bold)).opacity(0.7)
        }
        .font(.app(size: 13, weight: .semibold))
        .padding(.horizontal, 11).frame(height: 32)
        .foregroundStyle(highlighted ? Color.white : Theme.ink)
        .background {
            if highlighted {
                Capsule().fill(Theme.blueFill)
            } else if material {
                Capsule().fill(.regularMaterial)
            } else {
                Capsule().fill(Theme.card)
            }
        }
        .overlay(Capsule().stroke(Theme.line.opacity(highlighted ? 0 : 0.8), lineWidth: 0.5))
        .contentShape(Capsule())
    }
}

/// Giorno e ora a scelta, nel calendario e nel fuso di Roma (le ore dei cartelli)
private struct TimePickerSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            Form {
                DatePicker(L("Day and time"), selection: $date, in: TripView.minuteFloor(Date())..., displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                    .environment(\.timeZone, RuleEngine.rome.timeZone)
                    .environment(\.calendar, RuleEngine.rome)
                Text("Italian time, as on the signs at the gates.")
                    .font(.app(size: 13)).foregroundStyle(Theme.muted)
            }
            .navigationTitle(L("When?"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Now")) { store.when = nil; dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Done")) { store.when = date; dismiss() }
                }
            }
        }
        .onAppear { date = store.moment() }
    }
}

// MARK: Le quattro risposte sulla mappa

/// Il colore di una zona per l'ora e il veicolo scelti. Colore e forma insieme (simbolo e tratto del bordo),
/// così si distinguono anche senza vedere i colori
enum Access: CaseIterable, Hashable {
    case closed, conditional, check, open

    init(_ verdict: Verdict) {
        switch verdict {
        case .no: self = .closed
        case .conditional: self = .conditional
        case .unsure: self = .check
        case .yes: self = .open
        }
    }

    /// Come sopra, ma dati di esempio o un punto critico ancora da verificare non danno mai una risposta piena
    init(_ verdict: Verdict, status: City.Status?, pendingCritical: Bool = false) {
        let base = Access(verdict)
        self = (status == .sample || pendingCritical) && base != .closed ? .check : base
    }

    var title: String {
        switch self {
        case .closed: L("You can't enter")
        case .conditional: L("You can enter if…")
        case .check: L("To be checked")
        case .open: L("You can enter")
        }
    }

    var detail: String {
        switch self {
        case .closed: L("The ZTL is active for your vehicle at that time.")
        case .conditional: L("Only with a condition: day ticket, hotel registration or a permit.")
        case .check: L("Unconfirmed holiday, old data or a point still to verify: check the sign.")
        case .open: L("ZTL off, or your vehicle may enter.")
        }
    }

    var color: Color {
        switch self {
        case .closed: Color(light: 0xC1272D, dark: 0xEF5B55)
        case .conditional: Color(light: 0xD99A00, dark: 0xF2C14E)
        case .check: Color(light: 0x5B7A99, dark: 0x8FA9C4)
        case .open: Color(light: 0x0FA34A, dark: 0x3DDC74)
        }
    }

    var symbol: String {
        switch self {
        case .closed: "xmark"
        case .conditional: "exclamationmark"
        case .check: "questionmark"
        case .open: "checkmark"
        }
    }

    /// Bordo pieno per «no» e «sì», tratteggiato per le condizioni, a puntini per «da verificare»
    var dash: [CGFloat] {
        switch self {
        case .closed, .open: []
        case .conditional: [8, 5]
        case .check: [2, 5]
        }
    }

    var fillOpacity: Double {
        switch self {
        case .closed: 0.24
        case .conditional: 0.20
        case .check: 0.16
        case .open: 0.12
        }
    }
}

/// Le risposte delle zone per l'ora e il veicolo scelti: si calcolano una volta per minuto e per scelta,
/// non a ogni disegno della mappa (che si ridisegna a ogni gesto)
@MainActor
enum AccessCache {
    private static var key = ""
    private static var values: [String: Access] = [:]
    private static var statusVersion = -1
    private static var status: [String: City.Status] = [:]

    static func access(_ zone: Zone, store: Store, at date: Date) -> Access {
        if statusVersion != store.citiesVersion {
            statusVersion = store.citiesVersion
            status = [:]
            for c in store.cities { for z in c.zones { status[z.id] = c.status } }
        }
        let minute = Int(date.timeIntervalSinceReferenceDate / 60)
        let v = store.vehicle
        let k = "\(store.citiesVersion)|\(minute)|\(v.id)|\(v.fuel.rawValue)\(v.euro)|\(store.permits.hashValue)"
        if k != key { key = k; values = [:] }
        if let hit = values[zone.id] { return hit }
        let a = Access(store.answer(at: date, zone: zone, hotelInside: false).verdict, status: status[zone.id])
        values[zone.id] = a
        return a
    }
}

/// La legenda delle quattro risposte (mappa)
struct AccessLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(Access.allCases, id: \.self) { a in
                HStack(alignment: .top, spacing: 10) {
                    AccessSwatch(access: a).frame(width: 26, height: 20)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(verbatim: a.title).font(.app(size: 14, weight: .semibold)).foregroundStyle(Theme.ink)
                        Text(verbatim: a.detail).font(.app(size: 12)).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// Il campione della legenda: fondo, bordo con il suo tratto e simbolo, come sulla mappa
struct AccessSwatch: View {
    var access: Access
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4).fill(access.color.opacity(access.fillOpacity + 0.1))
            RoundedRectangle(cornerRadius: 4).strokeBorder(access.color, style: StrokeStyle(lineWidth: 2, dash: access.dash))
            Image(systemName: access.symbol).font(.system(size: 10, weight: .heavy)).foregroundStyle(access.color)
        }
        .accessibilityHidden(true)
    }
}
