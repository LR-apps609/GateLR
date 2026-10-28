import SwiftUI

/// «Fotografa il libretto»: foto della carta di circolazione → targa, marca, modello, anno, alimentazione
/// e classe Euro, da controllare e correggere prima di passarli al modulo del veicolo.
struct RegistrationScanView: View {
    var onUse: (Vehicle) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var result = RegistrationReader.Result()
    @State private var read = false
    @State private var plate = ""
    @State private var make = ""
    @State private var model = ""
    @State private var year: Int?
    @State private var fuel: Fuel = .petrol
    @State private var euro = 6

    private static let thisYear = Calendar.current.component(.year, from: Date())
    /// Le lingue dei libretti europei più comuni sulle strade italiane
    private static let languages = ["it-IT", "de-DE", "fr-FR", "es-ES", "nl-NL", "en-US"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Photograph the front of the registration document (the Italian «libretto», Zulassungsbescheinigung Teil I, carte grise, permiso de circulación…), flat and in good light. It's read on this iPhone: nothing is sent.")
                            .font(.app(size: 15)).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        DocumentCapture(languages: Self.languages, correction: false) { found in
                            text = found
                            apply(RegistrationReader.parse(found))
                        }
                    }
                    if read { review }
                }
                .padding(20)
            }
            .background(Theme.ground)
            .navigationTitle("Registration document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func apply(_ r: RegistrationReader.Result) {
        result = r
        read = true
        plate = r.plate ?? ""
        make = r.make ?? ""
        model = r.model ?? ""
        year = r.year
        fuel = r.fuel ?? .petrol
        euro = r.euro ?? 6
    }

    @ViewBuilder
    private var review: some View {
        if !result.understood {
            Label("I can't read a registration document in this photo. Try again closer, flat and in good light, or fill in the fields by hand.", systemImage: "questionmark.circle")
                .font(.app(size: 14)).foregroundStyle(Theme.amberInk)
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.amberSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Check before saving")
            field(L("Plate"), "A") {
                TextField(L("Plate"), text: $plate).textInputAutocapitalization(.characters).autocorrectionDisabled()
            }
            field(L("Make"), "D.1") { TextField(L("Make"), text: $make) }
            field(L("Model"), "D.3") { TextField(L("Model"), text: $model) }
            field(L("Year"), "B") {
                Picker(L("Year"), selection: $year) {
                    Text("–").tag(Int?.none)
                    ForEach((1990...Self.thisYear).reversed(), id: \.self) { Text(String($0)).tag(Optional($0)) }
                }
                .pickerStyle(.menu)
            }
            field(L("Fuel"), "P.3") {
                Picker(L("Fuel"), selection: $fuel) { ForEach(Fuel.allCases) { Text($0.label).tag($0) } }
                    .pickerStyle(.menu)
            }
            field(L("Euro class"), "V.9") {
                Stepper(String(format: L("Euro %lld"), euro), value: $euro, in: 0...7)
            }
            Text(euroNote)
                .font(.app(size: 13)).foregroundStyle(result.euroSource == .document ? Theme.muted : Theme.amberInk)
                .fixedSize(horizontal: false, vertical: true)
            DisclosureGroup(L("Text read from the photo")) {
                Text(text).font(.app(size: 12, design: .monospaced)).foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
            }
            .font(.app(size: 14))
            WideButton(title: "Use these details", systemImage: "checkmark") {
                var v = Vehicle(name: "", fuel: fuel, euro: euro)
                v.plate = plate.uppercased().trimmingCharacters(in: .whitespaces)
                let m = make.trimmingCharacters(in: .whitespaces)
                v.make = m.isEmpty ? nil : RegistrationReader.make(from: m, makes: CarCatalog.makes)
                v.model = model.trimmingCharacters(in: .whitespaces)
                v.year = year
                onUse(v)
                dismiss()
            }
            .accessibilityIdentifier("registration.use")
        }
        .padding(14).card()
    }

    private var euroNote: String {
        switch result.euroSource {
        case .document:
            return String(format: L("Euro class from the document: «%@»."), result.emissionText ?? "")
        case .year:
            return String(format: L("Field V.9 not found: Euro class suggested from the year of first registration (%@). Check it on the document."), result.year.map(String.init) ?? "–")
        case .none:
            return L("Euro class not found: set it from field V.9 of the document.")
        }
    }

    private func field<Content: View>(_ title: String, _ code: String, @ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 10) {
            Text(code).font(.app(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(Theme.blue)
                .frame(width: 34, height: 22).background(Theme.blueSoft, in: RoundedRectangle(cornerRadius: 6))
                .accessibilityHidden(true)
            Text(title).font(.app(size: 15)).frame(width: 90, alignment: .leading)
            content().font(.app(size: 15, weight: .semibold))
        }
    }
}

/// «Auto a noleggio»: i modelli più comuni nelle flotte in Italia; si sceglie il carburante della propria
struct RentalPresetsView: View {
    var onPick: (Vehicle) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var chosen: RentalPreset?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(CarCatalog.rentals) { p in
                        Button {
                            if p.fuels.count == 1 { pick(p, p.fuels[0]) } else { chosen = p }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: (p.type ?? .car).symbol).foregroundStyle(Theme.blue)
                                    .frame(width: 36, height: 36).background(Theme.blueSoft, in: RoundedRectangle(cornerRadius: 10))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.id).font(.app(size: 16, weight: .semibold)).foregroundStyle(Theme.ink)
                                    Text(p.fuels.map(\.label).joined(separator: " · ")).font(.app(size: 13)).foregroundStyle(Theme.muted)
                                }
                                Spacer()
                                Text(String(format: L("Euro %lld"), p.euro)).font(.app(size: 13)).foregroundStyle(Theme.muted)
                            }
                        }
                    }
                } footer: {
                    Text("Typical rental versions in Italy. Check fuel and Euro class on the registration document in the glovebox (fields P.3 and V.9) or on the rental contract.")
                }
            }
            .navigationTitle("Rental car")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Theme.blue)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .confirmationDialog(L("Which fuel?"), isPresented: Binding(get: { chosen != nil }, set: { if !$0 { chosen = nil } }),
                                titleVisibility: .visible, presenting: chosen) { p in
                ForEach(p.fuels) { f in Button(f.label) { pick(p, f) } }
            }
        }
    }

    private func pick(_ p: RentalPreset, _ fuel: Fuel) {
        var v = Vehicle(name: "", fuel: fuel, euro: p.euro)
        v.make = p.make
        v.model = p.model
        v.type = p.type
        v.isRental = true
        onPick(v)
        dismiss()
    }
}
