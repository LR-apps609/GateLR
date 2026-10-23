import SwiftUI

/// «Garage»: veicoli, permessi, città salvate per l'uso offline.
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
                                Text([v.model, v.fuel.label, "Euro \(v.euro)", v.plate].filter { !$0.isEmpty }.joined(separator: " · "))
                                    .font(.system(size: 13)).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            if v.id == store.vehicle.id {
                                Pill(text: "In use", fill: Theme.blueSoft, ink: Theme.blue)
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
                                Pill(text: p.status == .confirmed ? "Confirmed" : "Waiting",
                                     fill: p.status == .confirmed ? Theme.greenSoft : Theme.amberSoft,
                                     ink: p.status == .confirmed ? Theme.greenInk : Theme.amberInk)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .onDelete { store.permits.remove(atOffsets: $0) }
                    Button { addingPermit = true } label: { Label("Add a permit", systemImage: "plus.circle") }
                }

                Section("Offline cities") {
                    ForEach(store.cities) { c in
                        HStack {
                            Image(systemName: "checkmark").foregroundStyle(Theme.green)
                            Text(c.name)
                            Spacer()
                            Text(c.status == .verified ? "saved" : c.status == .sample ? "sample data" : "draft · \(c.zones.count) zones").font(.system(size: 13)).foregroundStyle(Theme.muted)
                        }
                    }
                }
            }
            .navigationTitle("Garage")
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

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name (e.g. Rental car)", text: $vehicle.name)
                TextField("Model", text: $vehicle.model)
                TextField("Plate", text: $vehicle.plate).textInputAutocapitalization(.characters)
                Picker("Fuel", selection: $vehicle.fuel) { ForEach(Fuel.allCases) { Text($0.label).tag($0) } }
                Stepper("Euro \(vehicle.euro)", value: $vehicle.euro, in: 0...7)
                Toggle("Rental car", isOn: $vehicle.isRental)
            }
            .navigationTitle(vehicle.name.isEmpty ? "New vehicle" : vehicle.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let i = store.vehicles.firstIndex(where: { $0.id == vehicle.id }) { store.vehicles[i] = vehicle }
                        else { store.vehicles.append(vehicle) }
                        dismiss()
                    }
                    .disabled(vehicle.name.isEmpty)
                }
            }
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
                Text("For \(store.vehicle.name) in \(store.city.name)").foregroundStyle(Theme.muted)
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
