import SwiftUI
import UIKit
import TipKit

/// «Impostazioni» (Tu → Impostazioni): avvisi, navigatore, lingua, il segno dell'auto e la voce, città offline e le
/// informazioni. Prima versione senza login: tutto resta sul telefono.
struct SettingsView: View {
    @EnvironmentObject var store: Store
    @State private var testSent = false
    @State private var reporting = false
    @AppStorage("navigator") private var preferredNavigator = ""
    @AppStorage("vehicleMarker") private var vehicleMarker = VehicleMarker.arrow.rawValue
    @AppStorage("vehicleColor") private var vehicleColor = VehicleColor.blue.rawValue
    @ObservedObject private var updater = CityUpdater.shared
    /// Calcolato in sottofondo: speechVoices() è lento e prima si chiamava a ogni disegno della pagina
    @State private var basicVoice = false

    var body: some View {
        List {
            Section {
                Toggle("Gate alerts", isOn: $store.alertsOn)
                Stepper(String(format: L("Warn me %lld m before a gate"), Int(store.alertDistance)),
                        value: $store.alertDistance, in: 200...1000, step: 100)
                Button {
                    GateMonitor.shared.sendTest(store: store)
                    testSent = true
                } label: { Label(testSent ? L("Sent: check your notifications") : L("Try an alert"), systemImage: "bell.badge") }
            } header: { Text("Alerts") } footer: {
                Text("Alerts work with the app closed for the saved cities. They need location access \"Always\".")
            }

            // «Modalità prova»: una ZTL finta intorno a te per provare tutto sul posto (TestMode.swift)
            TestModeSection()

            Section {
                Picker(L("Preferred navigator"), selection: $preferredNavigator) {
                    Text("Ask every time").tag("")
                    ForEach(Navigator.allCases) { Text($0.title).tag($0.rawValue) }
                    Text("GateLR navigation").tag("gatelr")
                }
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                } label: {
                    LabeledContent(L("Language"), value: Locale.current.localizedString(forLanguageCode: Locale.current.language.languageCode?.identifier ?? "en")?.capitalized ?? "–")
                }
                .foregroundStyle(Theme.ink)
            } header: { Text("Settings") } footer: {
                Text("GateLR speaks English, Italian, German, French, Spanish, Dutch, Polish and Chinese. The language is chosen in the iPhone Settings.")
            }

            // Navigatore di GateLR: il segno dell'auto e la voce
            Section {
                Picker(L("Vehicle on the map"), selection: $vehicleMarker) {
                    ForEach(VehicleMarker.allCases) { m in Text(m.title).tag(m.rawValue) }
                }
                if vehicleMarker != VehicleMarker.arrow.rawValue {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(VehicleColor.allCases) { c in
                                Button { vehicleColor = c.rawValue } label: {
                                    VehicleMarkerView(marker: VehicleMarker(rawValue: vehicleMarker) ?? .sedan, tint: c, heading: 0)
                                        .frame(width: 60, height: 60)
                                        .background(vehicleColor == c.rawValue ? Theme.blueSoft : .clear, in: RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(c.title)
                                .accessibilityAddTraits(vehicleColor == c.rawValue ? .isSelected : [])
                            }
                        }
                    }
                }
                if basicVoice {
                    // Solo con la voce di base: il consiglio una volta, poi resta il link
                    TipView(BetterVoiceTip())
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    } label: {
                        Label("Better voice: download a Premium or Enhanced voice", systemImage: "waveform")
                    }
                }
            } header: { Text("GateLR navigation") } footer: {
                Text("For clearer street names: Settings → Accessibility → Spoken Content → Voices → your language → a Premium or Enhanced voice (e.g. Alice). GateLR uses the best one installed.")
            }

            Section {
                LabeledContent(L("City data"), value: CityUpdater.label(updater.currentVersion))
                Button {
                    Task { await updater.check(store: store) }
                } label: {
                    HStack {
                        Label(L("Check for updates"), systemImage: "arrow.triangle.2.circlepath")
                        Spacer()
                        switch updater.state {
                        case .checking: ProgressView()
                        case .upToDate: Text("Up to date").foregroundStyle(Theme.greenInk)
                        case .updated: Text("Updated").foregroundStyle(Theme.greenInk)
                        case .failed: Text("Not available now").foregroundStyle(Theme.muted)
                        case .idle: EmptyView()
                        }
                    }
                }
                .disabled(updater.state == .checking)
            } header: { Text("Rules and maps") } footer: {
                Text("Hours, perimeters and gates are updated from GitHub, without a new app version. GateLR checks by itself twice a day.")
            }

            Section("Offline cities") {
                ForEach(store.cities.filter { !TestZone.isTest(cityId: $0.id) }) { c in
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.greenInk)
                        Text(c.localizedName)
                        Spacer()
                        Text(c.status == .verified ? L("verified") : c.status == .sample ? L("sample data")
                             : String(format: L("draft · %lld zones"), c.zones.count))
                            .font(.app(size: 13)).foregroundStyle(Theme.muted)
                    }
                }
            }

            Section("About GateLR") {
                NavigationLink { AboutView() } label: {
                    Label("Sources, licences and disclaimer", systemImage: "info.circle")
                }
                Button { reporting = true } label: { Label("Report a bug", systemImage: "ladybug") }
                    .foregroundStyle(Theme.ink)
                LabeledContent(L("Version"), value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–")
            }
        }
        .navigationTitle("Settings")
        .tint(Theme.blue)
        .sheet(isPresented: $reporting) { BugReportView() }
        .task { basicVoice = await SpeechVoice.onlyBasicVoiceAsync() }
        .onChange(of: store.alertsOn) { GateMonitor.shared.settingsChanged() }
        .onChange(of: store.alertDistance) { GateMonitor.shared.settingsChanged() }
    }
}

/// «Impara la ZTL»: prima versione con i disegni nostri (cartello, pannello), senza immagini di terzi
struct LearnZTLView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                lesson("What is a ZTL?", "ZTL means Zona a Traffico Limitato, limited traffic zone. Most Italian old towns have one: only residents and authorised vehicles may drive in while it's active.") {
                    ZTLSign().frame(width: 90, height: 110)
                }
                lesson("How to recognise the gate", "At every entrance there's a round no-entry sign with \"Zona Traffico Limitato\" and a camera. An electronic panel says if the ZTL is active.") {
                    GatePanel(on: true).frame(width: 150)
                }
                lesson("\"ZTL attiva\" or \"non attiva\"", "\"ZTL attiva\" (red) means the ban is on and the camera records: don't drive in. \"ZTL non attiva\" (green) means you may pass. Older panels still say \"Varco attivo\" with the same meaning. The panel always wins over the app.") {
                    GatePanel(on: false).frame(width: 150)
                }
                lesson("Read the hours under the sign", "Under the ZTL sign a white panel lists the days and hours when the ban applies, for example \"7.30-20.00 feriali\" (weekdays). Outside those hours you may drive in. \"Festivi\" means public holidays.") {
                    HoursPanel().frame(width: 170)
                }
                lesson("Pedestrian areas", "The blue square sign with people walking means a pedestrian area: no cars at any time, except authorised vehicles. Often there's a camera here too.") {
                    PedestrianSign().frame(width: 90, height: 90)
                }
                lesson("Bus lanes", "Lanes marked \"BUS\" or \"Riservata\" are only for buses and taxis, and many have cameras: driving in one is a separate fine, even outside the ZTL.") {
                    BusLane().frame(width: 150, height: 96)
                }
                lesson("Low-emission zones", "In zones like Milan's Area B the question isn't the time but your car: the most polluting Euro classes can't enter on weekdays. Set your car in Garage and GateLR checks it for you.") {
                    Image(systemName: "leaf.circle.fill").font(.app(size: 64)).foregroundStyle(ZoneKind.green.color)
                }
                lesson("Drove in by mistake?", "Don't drive around inside looking for a way out: every gate you pass can mean another fine. Exit at the nearest point and, if you're staying at a hotel inside, call it straight away: often it can still register your plate.") {
                    Image(systemName: "phone.arrow.up.right").font(.app(size: 34, weight: .semibold)).foregroundStyle(Theme.blue)
                        .frame(width: 70, height: 70).background(Theme.blueSoft, in: Circle())
                }
                if let fine = FineInfo.bundled {
                    lesson("How much is the fine?", String(format: L("From €%lld to €%lld, usually paid with 30%% off within 5 days. No points on the licence. With a rental car, the company adds a fee."), fine.min, fine.max)) {
                        Text("€").font(Theme.display(40)).foregroundStyle(Theme.red)
                            .frame(width: 70, height: 70).background(Theme.red.opacity(0.12), in: Circle())
                    }
                }
            }
            .padding(20)
        }
        .background(Theme.ground)
        .navigationTitle("What is a ZTL?")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func lesson<Art: View>(_ title: String, _ text: String, @ViewBuilder art: () -> Art) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Spacer(); art(); Spacer() }.padding(.vertical, 6)
            Text(L(title)).font(Theme.display(24)).foregroundStyle(Theme.ink)
            Text(L(text)).font(.app(size: 15)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading).card(20)
    }
}

/// Il cartello ZTL disegnato da noi: cerchio rosso di divieto e pannello bianco
struct ZTLSign: View {
    var body: some View {
        VStack(spacing: 4) {
            Circle().fill(.white).overlay(Circle().stroke(Color(hex: 0xC1272D), lineWidth: 9)).frame(width: 64, height: 64)
            VStack(spacing: 0) {
                Text("ZONA").font(.app(size: 9, weight: .heavy))
                Text("TRAFFICO").font(.app(size: 9, weight: .heavy))
                Text("LIMITATO").font(.app(size: 9, weight: .heavy))
            }
            .foregroundStyle(Color(hex: 0x1B2128))
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(.white, in: RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(hex: 0x1B2128), lineWidth: 1))
        }
        .accessibilityHidden(true)
    }
}

/// Il pannello luminoso del varco
struct GatePanel: View {
    var on: Bool
    var body: some View {
        VStack(spacing: 2) {
            Text(verbatim: "ZTL").font(.app(size: 15, weight: .heavy, design: .monospaced))
            Text(verbatim: on ? "ATTIVA" : "NON ATTIVA").font(.app(size: 15, weight: .heavy, design: .monospaced))
        }
        .foregroundStyle(on ? Color(hex: 0xFF4B3E) : Color(hex: 0x4BE37A))
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(Color(hex: 0x111111), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: 0x555555), lineWidth: 3))
        .accessibilityLabel(Text(verbatim: on ? "ZTL attiva" : "ZTL non attiva"))
    }
}

/// Il pannello integrativo con gli orari, sotto il cartello
struct HoursPanel: View {
    var body: some View {
        VStack(spacing: 2) {
            Text(verbatim: "7.30 – 20.00").font(.app(size: 17, weight: .heavy, design: .rounded))
            Text(verbatim: "FERIALI").font(.app(size: 11, weight: .heavy))
            Rectangle().frame(height: 1).padding(.vertical, 3)
            Text(verbatim: "CONTROLLO ELETTRONICO").font(.app(size: 9, weight: .heavy))
        }
        .foregroundStyle(Color(hex: 0x1B2128))
        .padding(10).frame(maxWidth: .infinity)
        .background(.white, in: RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(hex: 0x1B2128), lineWidth: 2))
        .accessibilityHidden(true)
    }
}

/// Il cartello blu di area pedonale
struct PedestrianSign: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8).fill(Color(hex: 0x1F4E9E))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white, lineWidth: 3).padding(4))
            .overlay(HStack(spacing: -4) {
                Image(systemName: "figure.walk").font(.app(size: 34, weight: .bold))
                Image(systemName: "figure.and.child.holdinghands").font(.app(size: 28, weight: .bold))
            }.foregroundStyle(.white))
            .accessibilityHidden(true)
    }
}

/// La corsia riservata con la scritta BUS
struct BusLane: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0x3A3F45))
            HStack(spacing: 0) {
                Rectangle().fill(.white).frame(width: 4)
                Spacer()
                VStack(spacing: 6) { ForEach(0..<4, id: \.self) { _ in Rectangle().fill(.white).frame(width: 4, height: 12) } }
                Spacer()
                Rectangle().fill(.white).frame(width: 4)
            }
            .padding(.horizontal, 12)
            Text(verbatim: "BUS").font(.app(size: 26, weight: .black)).foregroundStyle(Color(hex: 0xF2C14E))
                .offset(x: 34)
        }
        .accessibilityHidden(true)
    }
}
