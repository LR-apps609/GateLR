import SwiftUI

/// «Garage»: veicoli e permessi.
struct GarageView: View {
    @EnvironmentObject var store: Store
    @State private var editing: Vehicle?
    @State private var addingPermit = false

    var body: some View {
        NavigationStack {
            List {
                Section("Vehicles") {
                    ForEach(store.vehicles) { v in
                        HStack(spacing: 12) {
                            Image(systemName: "car.fill")
                                .foregroundStyle(v.id == store.vehicle.id ? Theme.blue : Theme.muted)
                                .frame(width: 44, height: 44)
                                .background(v.id == store.vehicle.id ? Theme.blueSoft : Theme.ground, in: RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(v.name).font(.system(size: 16, weight: .semibold))
                                Text([[v.make, v.model].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " "), v.fuel.label, "Euro \(v.euro)", v.plate].filter { !$0.isEmpty }.joined(separator: " · "))
                                    .font(.system(size: 13)).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            if v.id == store.vehicle.id {
                                Pill(text: L("In use"), fill: Theme.blueSoft, ink: Theme.blue)
                            } else {
                                Button("Use") { store.activeVehicleId = v.id }.fontWeight(.semibold)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { editing = v }
                    }
                    .onDelete { store.vehicles.remove(atOffsets: $0) }
                }

                Section("Permits") {
                    ForEach(store.permits) { p in
                        HStack {
                            Image(systemName: p.kind == .hotelRegistration ? "house" : "checkmark.seal")
                                .foregroundStyle(p.status == .confirmed ? Theme.green : Theme.amber)
                            VStack(alignment: .leading) {
                                Text(p.kind.label)
                                Text("\(p.from.formatted(.dateTime.day().month())) – \(p.to.formatted(.dateTime.day().month()))")
                                    .font(.system(size: 13)).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            Button {
                                if let i = store.permits.firstIndex(of: p) {
                                    store.permits[i].status = p.status == .confirmed ? .waiting : .confirmed
                                }
                            } label: {
                                Pill(text: L(p.status == .confirmed ? "Confirmed" : "Waiting"),
                                     fill: p.status == .confirmed ? Theme.greenSoft : Theme.amberSoft,
                                     ink: p.status == .confirmed ? Theme.greenInk : Theme.amberInk)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .onDelete { store.permits.remove(atOffsets: $0) }
                    Button { addingPermit = true } label: { Label("Add a permit", systemImage: "plus.circle") }
                }

                CarAdvice()
            }
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 4) }
            .navigationTitle("Garage")
            .tint(Theme.blue)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { editing = Vehicle(name: "", fuel: .petrol, euro: 6) } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add a vehicle")
                }
            }
            .sheet(item: $editing) { v in VehicleForm(vehicle: v) }
            .sheet(isPresented: $addingPermit) { PermitForm() }
        }
    }
}

struct VehicleForm: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State var vehicle: Vehicle

    private var models: [String] { CarCatalog.makes.first { $0.make == vehicle.make }?.models ?? [] }
    private static let thisYear = Calendar.current.component(.year, from: Date())

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L("Name (e.g. Rental car)"), text: $vehicle.name)
                    TextField(L("Plate"), text: $vehicle.plate).textInputAutocapitalization(.characters).autocorrectionDisabled()
                    Toggle(L("Rental car"), isOn: $vehicle.isRental)
                }
                Section {
                    Picker(L("Make"), selection: $vehicle.make) {
                        Text("–").tag(String?.none)
                        ForEach(CarCatalog.makes, id: \.make) { Text($0.make).tag(Optional($0.make)) }
                    }
                    .pickerStyle(.navigationLink)
                    .onChange(of: vehicle.make) { vehicle.model = "" }
                    if !models.isEmpty {
                        Picker(L("Model"), selection: $vehicle.model) {
                            Text("–").tag("")
                            ForEach(models, id: \.self) { Text($0).tag($0) }
                            if !vehicle.model.isEmpty && !models.contains(vehicle.model) { Text(vehicle.model).tag(vehicle.model) }
                        }
                        .pickerStyle(.navigationLink)
                    } else {
                        TextField(L("Model"), text: $vehicle.model)
                    }
                    Picker(L("Year"), selection: $vehicle.year) {
                        Text("–").tag(Int?.none)
                        ForEach((1990...Self.thisYear).reversed(), id: \.self) { Text(String($0)).tag(Optional($0)) }
                    }
                    .onChange(of: vehicle.year) { if let y = vehicle.year { vehicle.euro = CarCatalog.euro(forYear: y) } }
                } header: { Text("Car") }
                Section {
                    Picker(L("Fuel"), selection: $vehicle.fuel) { ForEach(Fuel.allCases) { Text($0.label).tag($0) } }
                    Stepper(String(format: L("Euro %lld"), vehicle.euro), value: $vehicle.euro, in: 0...7)
                } header: { Text("Emissions") } footer: {
                    Text(vehicle.year == nil ? L("The Euro class is on the registration document, field V.9.")
                         : L("Euro class suggested from the year. Check it on the registration document, field V.9."))
                }
            }
            .navigationTitle(vehicle.name.isEmpty ? L("New vehicle") : vehicle.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if vehicle.name.isEmpty { vehicle.name = [vehicle.make, vehicle.model].compactMap { $0 }.joined(separator: " ") }
                        if let i = store.vehicles.firstIndex(where: { $0.id == vehicle.id }) { store.vehicles[i] = vehicle }
                        else { store.vehicles.append(vehicle) }
                        dismiss()
                    }
                    .disabled(vehicle.name.isEmpty && vehicle.make == nil)
                }
            }
        }
    }
}

/// Consigli per l'auto in uso: dove i divieti per classe Euro la fermano, fino a quando può entrare, esenzioni
struct CarAdvice: View {
    @EnvironmentObject var store: Store

    struct Line: Hashable { var city: String; var zone: String; var text: String; var ok: Bool }

    static func lines(for v: Vehicle, cities: [City], at date: Date = Date()) -> [Line] {
        cities.flatMap { city in
            city.zones.compactMap { z -> Line? in
                if z.exemptFuels.contains(v.fuel) {
                    return Line(city: city.localizedName, zone: z.shortName, text: String(format: L("%@ cars may enter"), v.fuel.label), ok: true)
                }
                guard z.bans != nil else { return nil }
                if z.ban(for: v, at: date) != nil {
                    return Line(city: city.localizedName, zone: z.shortName, text: L("Your car can't enter while it's active"), ok: false)
                }
                if let next = z.nextBan(for: v, after: date) {
                    return Line(city: city.localizedName, zone: z.shortName,
                                text: String(format: L("Allowed until %@"), next.date.addingTimeInterval(-86_400).formatted(date: .abbreviated, time: .omitted)), ok: true)
                }
                return Line(city: city.localizedName, zone: z.shortName, text: L("Your car's class is allowed"), ok: true)
            }
        }
    }

    var body: some View {
        let lines = Self.lines(for: store.vehicle, cities: store.cities)
        Section {
            if lines.isEmpty {
                Text("No emission rules for your car in the saved cities.").font(.system(size: 14)).foregroundStyle(Theme.muted)
            }
            ForEach(lines, id: \.self) { l in
                HStack(spacing: 12) {
                    Image(systemName: l.ok ? "checkmark.circle.fill" : "xmark.octagon.fill")
                        .foregroundStyle(l.ok ? Theme.green : Theme.red)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(l.city) · \(l.zone)").font(.system(size: 15, weight: .semibold))
                        Text(l.text).font(.system(size: 13)).foregroundStyle(Theme.muted)
                    }
                }
            }
        } header: { Text(String(format: L("Advice for %@"), store.vehicle.name)) } footer: {
            Text("From the cities' emission calendars. Old towns with a ZTL stay closed to all cars without a permit, whatever the class.")
        }
    }
}

struct PermitForm: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var kind: Permit.Kind = .hotelRegistration
    @State private var from = Date()
    @State private var to = Date().addingTimeInterval(86_400 * 3)

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $kind) { ForEach(Permit.Kind.allCases, id: \.self) { Text($0.label).tag($0) } }
                DatePicker("From", selection: $from)
                DatePicker("To", selection: $to, in: from...)
                Text(String(format: L("For %@ in %@"), store.vehicle.name, store.city.localizedName)).foregroundStyle(Theme.muted)
            }
            .navigationTitle("New permit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.permits.append(Permit(kind: kind, cityId: store.city.id, zoneId: nil, vehicleId: store.vehicle.id,
                                                    from: from, to: to, status: .waiting))
                        dismiss()
                    }
                }
            }
        }
    }
}
