import SwiftUI

/// «Garage»: veicoli e permessi. Si apre da «Tu» (dentro la sua NavigationStack).
struct GarageView: View {
    @EnvironmentObject var store: Store
    @State private var editing: Vehicle?
    @State private var addingPermit = false
    /// Un permesso senza zona (versioni vecchie): si sceglie la zona
    @State private var zoning: Permit?
    /// Il permesso da confermare (dialogo «Hai la conferma scritta?»)
    @State private var confirming: Permit?
    /// 1.20.2: veicolo o permesso da cancellare, in attesa della conferma (PendingDelete)
    @State private var deleting: PendingDelete?

    var body: some View {
        List {
            Section("Vehicles") {
                if store.vehicles.isEmpty {
                    EmptyStateView(symbol: "car.fill", badge: "plus", title: "No cars yet",
                                   text: "Add your car or rental: GateLR checks its fuel and Euro class against every zone.",
                                   action: "Add a vehicle", actionSymbol: "plus") {
                        editing = Vehicle(name: "", fuel: .petrol, euro: 6)
                    }
                    .listRowBackground(Color.clear)
                }
                ForEach(store.vehicles) { v in
                    HStack(spacing: 12) {
                        Image(systemName: v.kind.symbol)
                            .foregroundStyle(v.id == store.vehicle.id ? Theme.blue : Theme.muted)
                            .frame(width: 44, height: 44)
                            .background(v.id == store.vehicle.id ? Theme.blueSoft : Theme.ground, in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(v.name).font(.app(size: 16, weight: .semibold))
                            Text(Self.subtitle(v))
                                .font(.app(size: 13)).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        if v.id == store.vehicle.id {
                            Pill(text: L("In use"), fill: Theme.blueSoft, ink: Theme.blue)
                        } else {
                            Button("Use") { store.activeVehicleId = v.id }.fontWeight(.semibold).buttonStyle(.borderless)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { editing = v }
                }
                // 1.20.2: prima la conferma, poi si cancella (con i permessi del veicolo)
                .onDelete { offsets in deleting = .vehicles(Set(offsets.map { store.vehicles[$0].id })) }
            }

            Section {
                ForEach(store.permits) { p in
                    HStack {
                        Image(systemName: p.kind == .hotelRegistration ? "house" : "checkmark.seal")
                            .foregroundStyle(p.status == .confirmed && !p.needsZone ? Theme.greenInk : Theme.amberInk)   // le versioni «Ink» si leggono anche al buio
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.kind.label)
                            Text(verbatim: Self.place(p, cities: store.cities))
                                .font(.app(size: 13, weight: .semibold)).foregroundStyle(p.needsZone ? Theme.amberInk : Theme.ink)
                            Text("\(RuleEngine.format(p.from, .dateTime.day().month())) – \(RuleEngine.format(p.to, .dateTime.day().month()))")
                                .font(.app(size: 13)).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Button { tapStatus(p) } label: {
                            if p.needsZone {
                                Pill(text: L("Choose the zone"), fill: Theme.amberSoft, ink: Theme.amberInk)
                            } else if p.status == .confirmed {
                                Pill(text: L("Confirmed"), fill: Theme.greenSoft, ink: Theme.greenInk)
                            } else {
                                Pill(text: L("Waiting"), fill: Theme.amberSoft, ink: Theme.amberInk)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("garage.permit.status")
                    }
                }
                .onDelete { offsets in deleting = .permits(Set(offsets.map { store.permits[$0].id })) }
                Button { addingPermit = true } label: { Label("Add a permit", systemImage: "plus.circle") }
                    .accessibilityIdentifier("garage.addPermit")
            } header: { Text("Permits") } footer: {
                Text("A permit counts only in its zone, for the chosen vehicle and days.")
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
        .sheet(item: $zoning) { p in PermitForm(existing: p) }
        .confirmDelete($deleting, store: store)
        .confirmationDialog(L("Do you have the written confirmation?"), isPresented: Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } }),
                            titleVisibility: .visible, presenting: confirming) { p in
            Button(L("Yes, I have it in writing")) {
                if let i = store.permits.firstIndex(where: { $0.id == p.id }) { store.permits[i].status = .confirmed }
                confirming = nil
            }
            .accessibilityIdentifier("permit.confirm.yes")
            Button(L("Cancel"), role: .cancel) { confirming = nil }
        } message: { p in
            Text(verbatim: Self.confirmText(p, store: store))
        }
    }

    /// Il tocco sulla pillola: confermato → in attesa subito (più prudente); in attesa → confermato solo dopo il dialogo;
    /// senza zona si sceglie prima la zona
    private func tapStatus(_ p: Permit) {
        if p.needsZone { zoning = p; return }
        if p.status == .confirmed {
            if let i = store.permits.firstIndex(where: { $0.id == p.id }) { store.permits[i].status = .waiting }
        } else {
            confirming = p
        }
    }

    /// «Firenze · Settore A», o «Firenze · scegli la zona» per i permessi salvati senza zona
    static func place(_ p: Permit, cities: [City]) -> String {
        let city = cities.first { $0.id == p.cityId }
        let name = city?.localizedName ?? p.cityId
        guard let id = p.zoneId else { return name + " · " + L("no zone: it doesn't count") }
        return name + " · " + (city?.zones.first { $0.id == id }?.localizedName ?? id)
    }

    static func confirmText(_ p: Permit, store: Store) -> String {
        let vehicle = store.vehicles.first { $0.id == p.vehicleId }
        let who = vehicle.map { $0.plate.isEmpty ? $0.name : $0.plate } ?? L("your vehicle")
        return String(format: L("Confirm only if the city or the hotel has confirmed in writing that %@ is registered for %@. GateLR will answer \"yes\" there for these days, and only there."),
                      who, place(p, cities: store.cities))
    }
}

extension GarageView {
    /// «Fiat Panda · Benzina · Euro 6 · AB123CD»; per le moto «Moto / scooter · Honda SH 125 · Benzina · Euro 5»
    static func subtitle(_ v: Vehicle) -> String {
        let car: String = [v.make ?? "", v.model].filter { !$0.isEmpty }.joined(separator: " ")
        let parts: [String] = [v.kind == .motorcycle ? v.kind.label : "", car, v.fuel.label, "Euro \(v.euro)", v.plate]
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

struct VehicleForm: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State var vehicle: Vehicle
    @State private var scanning = false
    @State private var pickingRental = false
    /// I dati appena letti dal libretto o scelti tra le auto a noleggio: i cambi di marca e di anno che arrivano
    /// da qui non cancellano il modello e non ricalcolano la classe Euro (quella del libretto vale più dell'anno)
    @State private var filled: Vehicle?
    private var isNew: Bool { !store.vehicles.contains { $0.id == vehicle.id } }

    private var models: [String] { CarCatalog.makes.first { $0.make == vehicle.make }?.models ?? [] }
    private static let thisYear = Calendar.current.component(.year, from: Date())

    var body: some View {
        NavigationStack {
            Form {
                if isNew {
                    Section {
                        Button { scanning = true } label: { Label("Photograph the registration document", systemImage: "doc.text.viewfinder") }
                            .accessibilityIdentifier("vehicle.scan")
                        Button { pickingRental = true } label: { Label("Rental car: pick the model", systemImage: "car.2.fill") }
                            .accessibilityIdentifier("vehicle.rental")
                    } header: { Text("Car in 10 seconds") } footer: {
                        Text("Plate, make, model, fuel and Euro class read on the iPhone: you check them before saving.")
                    }
                }
                Section {
                    // Auto o moto: nelle ZTL che lasciano entrare le due ruote la risposta cambia
                    Picker(L("Vehicle type"), selection: Binding(get: { vehicle.kind }, set: { vehicle.type = $0 })) {
                        ForEach(VehicleType.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("vehicle.type")
                    .onChange(of: vehicle.type) { if let y = vehicle.year, filled?.year != y { vehicle.euro = CarCatalog.euro(forYear: y, type: vehicle.kind) } }
                    TextField(L("Name (e.g. Rental car)"), text: $vehicle.name)
                    TextField(L("Plate"), text: $vehicle.plate).textInputAutocapitalization(.characters).autocorrectionDisabled()
                    // Subito sotto la targa (accanto, nel campo stretto, la scritta si tagliava)
                    PlateLookupButton()
                    Toggle(L("Rental car"), isOn: $vehicle.isRental)
                }
                Section {
                    if vehicle.kind == .motorcycle {
                        // L'elenco di marche e modelli è per le auto: per moto e scooter si scrivono
                        TextField(L("Make"), text: Binding(get: { vehicle.make ?? "" }, set: { vehicle.make = $0.isEmpty ? nil : $0 }))
                        TextField(L("Model"), text: $vehicle.model)
                    } else {
                        Picker(L("Make"), selection: $vehicle.make) {
                            Text("–").tag(String?.none)
                            ForEach(CarCatalog.makes, id: \.make) { Text($0.make).tag(Optional($0.make)) }
                            if let m = vehicle.make, !CarCatalog.makes.contains(where: { $0.make == m }) { Text(m).tag(Optional(m)) }
                        }
                        .pickerStyle(.navigationLink)
                        .onChange(of: vehicle.make) { vehicle.model = filled?.make == vehicle.make ? (filled?.model ?? "") : "" }
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
                    }
                    Picker(L("Year"), selection: $vehicle.year) {
                        Text("–").tag(Int?.none)
                        ForEach((1990...Self.thisYear).reversed(), id: \.self) { Text(String($0)).tag(Optional($0)) }
                    }
                    .onChange(of: vehicle.year) {
                        if let f = filled, f.year == vehicle.year { vehicle.euro = f.euro }
                        else if let y = vehicle.year { vehicle.euro = CarCatalog.euro(forYear: y, type: vehicle.kind) }
                    }
                } header: { Text(vehicle.kind == .motorcycle ? L("Motorbike / scooter") : L("Car")) }
                Section {
                    Picker(L("Fuel"), selection: $vehicle.fuel) { ForEach(Fuel.allCases) { Text($0.label).tag($0) } }
                    Stepper(String(format: L("Euro %lld"), vehicle.euro), value: $vehicle.euro, in: 0...7)
                    // 1.17.2: alcune zone a basse emissioni (Scudo Verde di Firenze) hanno limiti diversi per ciclomotori
                    // e motori a 2 tempi. Di serie motociclo e 4 tempi
                    if vehicle.kind == .motorcycle {
                        Picker(L("Two-wheeler"), selection: Binding(get: { vehicle.motoCategory }, set: { vehicle.motoClass = $0 })) {
                            ForEach(MotoClass.allCases) { Text($0.label).tag($0) }
                        }
                        .accessibilityIdentifier("vehicle.motoClass")
                        Picker(L("Engine"), selection: Binding(get: { vehicle.strokes }, set: { vehicle.stroke = $0 })) {
                            Text(L("4-stroke")).tag(4)
                            Text(L("2-stroke")).tag(2)
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("vehicle.stroke")
                    }
                } header: { Text("Emissions") } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vehicle.year == nil ? L("The Euro class is on the registration document, field V.9.")
                             : L("Euro class suggested from the year. Check it on the registration document, field V.9."))
                        if vehicle.kind == .motorcycle {
                            Text(L("Some low-emission zones have different limits for mopeds and 2-stroke engines. If you're not sure, leave 4-stroke: almost all motorbikes and scooters made after 2000 are."))
                        }
                    }
                }
            }
            .navigationTitle(vehicle.name.isEmpty ? L("New vehicle") : vehicle.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if vehicle.name.isEmpty {
                            let parts: [String] = [vehicle.make ?? "", vehicle.model].filter { !$0.isEmpty }
                            vehicle.name = parts.joined(separator: " ")
                        }
                        if let i = store.vehicles.firstIndex(where: { $0.id == vehicle.id }) { store.vehicles[i] = vehicle }
                        else { store.vehicles.append(vehicle) }
                        dismiss()
                    }
                    .disabled(vehicle.name.isEmpty && vehicle.make == nil)
                }
            }
            .sheet(isPresented: $scanning) { RegistrationScanView { fill($0) } }
            .sheet(isPresented: $pickingRental) { RentalPresetsView { fill($0) } }
        }
    }

    /// Dal libretto o dalle auto a noleggio al modulo: si salva solo dopo averlo controllato
    private func fill(_ v: Vehicle) {
        filled = v
        if !v.plate.isEmpty { vehicle.plate = v.plate }
        vehicle.make = v.make
        vehicle.model = v.model
        vehicle.year = v.year
        vehicle.fuel = v.fuel
        vehicle.euro = v.euro
        if let t = v.type { vehicle.type = t }
        if v.isRental { vehicle.isRental = true }
    }
}

/// «Cerca dalla targa»: chiuso con il lucchetto finché il servizio non c'è (PlateLookupService.current è il sostituto
/// spento, vedi PlateLookup.swift). Nessuna richiesta in rete.
struct PlateLookupButton: View {
    var service: any PlateLookup = PlateLookupService.current

    var body: some View {
        let on = service.isAvailable
        Button {} label: {
            HStack(spacing: 10) {
                Image(systemName: Symbols.pick(on, "magnifyingglass", else: "lock.fill"))
                    .font(.app(size: 14, weight: .semibold))
                    .frame(width: 22)
                Text("Look up by plate").font(.app(size: 16))
                Spacer(minLength: 8)
                if !on {
                    Text("Coming soon").font(.app(size: 12, weight: .semibold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Theme.raised, in: Capsule())
                }
            }
            .foregroundStyle(Theme.muted)
        }
        .disabled(!on)
        // VoiceOver: «Cerca dalla targa, in arrivo, non disponibile»
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(on ? L("Look up by plate") : L("Look up by plate") + ", " + L("Coming soon"))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("vehicle.plateLookup")
    }
}

/// Consigli per l'auto in uso: dove i divieti per classe Euro la fermano, fino a quando può entrare, esenzioni
struct CarAdvice: View {
    @EnvironmentObject var store: Store

    struct Line: Hashable { var city: String; var zone: String; var text: String; var ok: Bool }

    nonisolated static func lines(for v: Vehicle, cities: [City], at date: Date = Date()) -> [Line] {
        // 1.20.4: una zona di più parti (Area B di Milano) ha una zona per parte con lo stesso nome: una riga sola
        // (le righe uguali erano anche id doppi nel ForEach)
        var seen = Set<Line>()
        return all(for: v, cities: cities, at: date).filter { seen.insert($0).inserted }
    }

    nonisolated private static func all(for v: Vehicle, cities: [City], at date: Date) -> [Line] {
        cities.flatMap { city in
            city.zones.compactMap { z -> Line? in
                if z.exempts(v) {
                    return Line(city: city.localizedName, zone: z.shortName, text: L("Motorbikes and scooters may enter"), ok: true)
                }
                if z.exemptFuels.contains(v.fuel) {
                    return Line(city: city.localizedName, zone: z.shortName, text: String(format: L("%@ cars may enter"), v.fuel.label), ok: true)
                }
                // Per le moto i divieti per classe Euro delle auto non valgono (Zone.ban)
                guard z.bans != nil, v.kind == .car else { return nil }
                if z.ban(for: v, at: date) != nil {
                    return Line(city: city.localizedName, zone: z.shortName, text: L("Your car can't enter while it's active"), ok: false)
                }
                if let next = z.nextBan(for: v, after: date) {
                    // Il giorno prima del divieto, contato e scritto in ora italiana (con -86 400 s e il fuso
                    // del telefono, fuori dall'Italia o nei giorni del cambio d'ora usciva un giorno sbagliato)
                    let engine = RuleEngine()
                    let last = engine.calendar.date(byAdding: .day, value: -1, to: next.date) ?? next.date
                    return Line(city: city.localizedName, zone: z.shortName,
                                text: String(format: L("Allowed until %@"), engine.day(last, style: .abbreviated)), ok: true)
                }
                return Line(city: city.localizedName, zone: z.shortName, text: L("Your car's class is allowed"), ok: true)
            }
        }
    }

    var body: some View {
        let lines = Self.lines(for: store.vehicle, cities: store.cities)
        Section {
            if lines.isEmpty {
                Text("No emission rules for your car in the saved cities.").font(.app(size: 14)).foregroundStyle(Theme.muted)
            }
            ForEach(lines, id: \.self) { l in
                HStack(spacing: 12) {
                    Image(systemName: l.ok ? "checkmark.circle.fill" : "xmark.octagon.fill")
                        .foregroundStyle(l.ok ? Theme.greenInk : Theme.red)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(l.city) · \(l.zone)").font(.app(size: 15, weight: .semibold))
                        Text(l.text).font(.app(size: 13)).foregroundStyle(Theme.muted)
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
    /// Un permesso già salvato senza zona (versioni fino alla 1.19.1): si sceglie la zona e si salva al suo posto
    var existing: Permit? = nil
    @State private var kind: Permit.Kind = .hotelRegistration
    @State private var from = Date()
    @State private var to = Date().addingTimeInterval(86_400 * 3)
    @State private var cityId: String?
    @State private var zoneId: String?
    @State private var asking = false
    @State private var loaded = false

    private var city: City? { store.cities.first { $0.id == (cityId ?? store.city.id) } }
    private var vehicleId: UUID { existing?.vehicleId ?? store.vehicle.id }
    private var draft: Permit? {
        guard let c = city, let z = zoneId, c.zones.contains(where: { $0.id == z }) else { return nil }
        return Permit(id: existing?.id ?? UUID(), kind: kind, cityId: c.id, zoneId: z, vehicleId: vehicleId,
                      from: from, to: to, status: .waiting)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $kind) { ForEach(Permit.Kind.allCases, id: \.self) { Text($0.label).tag($0) } }
                    DatePicker("From", selection: $from)
                    DatePicker("To", selection: $to, in: from...)
                }
                Section {
                    Picker(L("City"), selection: Binding(get: { cityId ?? store.city.id }, set: { cityId = $0; zoneId = nil })) {
                        ForEach(store.cities) { Text($0.localizedName).tag($0.id) }
                    }
                    // La zona è obbligatoria: niente più permessi per tutta la città
                    Picker(L("Zone"), selection: $zoneId) {
                        Text(L("Choose the zone")).tag(String?.none)
                        ForEach(city?.zones ?? []) { Text($0.localizedName).tag(Optional($0.id)) }
                    }
                    .accessibilityIdentifier("permit.zone")
                } header: { Text("Where it counts") } footer: {
                    Text(String(format: L("For %@. The permit counts only in this zone: in the other zones GateLR answers as if you had none."),
                                store.vehicles.first { $0.id == vehicleId }?.name ?? store.vehicle.name))
                }
            }
            .navigationTitle(existing == nil ? L("New permit") : L("Choose the zone"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { asking = true }
                        .disabled(draft == nil)
                        .accessibilityIdentifier("permit.save")
                }
            }
            .confirmationDialog(L("Save this permit?"), isPresented: $asking, titleVisibility: .visible) {
                Button(L("Save the permit")) { save() }
                    .accessibilityIdentifier("permit.save.confirm")
                Button(L("Cancel"), role: .cancel) {}
            } message: {
                if let p = draft { Text(verbatim: Self.consentText(p, cities: store.cities)) }
            }
            .onAppear {
                guard !loaded, let e = existing else { return }
                loaded = true
                kind = e.kind; from = e.from; to = e.to; cityId = e.cityId; zoneId = e.zoneId
            }
        }
    }

    /// Il testo del dialogo: dove vale e cosa cambia nella risposta
    static func consentText(_ p: Permit, cities: [City]) -> String {
        String(format: L("It counts only in %@, from %@ to %@. While it's waiting, GateLR answers \"on one condition\" there instead of \"don't enter\". Save it only if you have really asked for it."),
               GarageView.place(p, cities: cities), RuleEngine.format(p.from, .dateTime.day().month()), RuleEngine.format(p.to, .dateTime.day().month()))
    }

    private func save() {
        guard let p = draft else { return }
        if let i = store.permits.firstIndex(where: { $0.id == p.id }) { store.permits[i] = p } else { store.permits.append(p) }
        dismiss()
    }
}
