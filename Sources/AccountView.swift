import SwiftUI
import UIKit

/// «Account»: impostazioni, avvisi, città offline, abbonamento (presto), la guida alla ZTL e le informazioni.
/// Prima versione senza login: tutto resta sul telefono.
struct AccountView: View {
    @EnvironmentObject var store: Store
    @State private var testSent = false
    @State private var reporting = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 46)).foregroundStyle(Theme.muted.opacity(0.6))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Your GateLR").font(Theme.display(22)).foregroundStyle(Theme.ink)
                            Text("No account needed: your cars, permits and trips stay on this iPhone.")
                                .font(.system(size: 13)).foregroundStyle(Theme.muted)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    NavigationLink { LearnZTLView() } label: {
                        Label("What is a ZTL?", systemImage: "graduationcap")
                    }
                } header: { Text("Learn") } footer: {
                    Text("The signs, the gate panels, and what to do if you drove in by mistake.")
                }

                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "star.circle.fill").font(.system(size: 28)).foregroundStyle(Theme.brass)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("GateLR Plus").font(.system(size: 16, weight: .semibold))
                            Text("Coming soon: more cities, trip alerts and sync between devices.")
                                .font(.system(size: 13)).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Pill(text: L("Soon"), fill: Theme.brass.opacity(0.18), ink: Theme.brass)
                    }
                } header: { Text("Subscription") }

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

                Section {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    } label: {
                        LabeledContent(L("Language"), value: Locale.current.localizedString(forLanguageCode: Locale.current.language.languageCode?.identifier ?? "en")?.capitalized ?? "–")
                    }
                    .foregroundStyle(Theme.ink)
                } header: { Text("Settings") } footer: {
                    Text("GateLR speaks English, Italian and German. The language is chosen in the iPhone Settings.")
                }

                Section("Offline cities") {
                    ForEach(store.cities) { c in
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.green)
                            Text(c.localizedName)
                            Spacer()
                            Text(c.status == .verified ? L("verified") : c.status == .sample ? L("sample data")
                                 : String(format: L("draft · %lld zones"), c.zones.count))
                                .font(.system(size: 13)).foregroundStyle(Theme.muted)
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
            .navigationTitle("Account")
            .tint(Theme.blue)
            .sheet(isPresented: $reporting) { BugReportView() }
        }
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
                lesson("Drove in by mistake?", "Don't drive around inside looking for a way out: every gate you pass can mean another fine. Exit at the nearest point and, if you're staying at a hotel inside, call it straight away: often it can still register your plate.") {
                    Image(systemName: "phone.arrow.up.right").font(.system(size: 34, weight: .semibold)).foregroundStyle(Theme.blue)
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
            Text(L(text)).font(.system(size: 15)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
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
                Text("ZONA").font(.system(size: 9, weight: .heavy))
                Text("TRAFFICO").font(.system(size: 9, weight: .heavy))
                Text("LIMITATO").font(.system(size: 9, weight: .heavy))
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
            Text(verbatim: "ZTL").font(.system(size: 15, weight: .heavy, design: .monospaced))
            Text(verbatim: on ? "ATTIVA" : "NON ATTIVA").font(.system(size: 15, weight: .heavy, design: .monospaced))
        }
        .foregroundStyle(on ? Color(hex: 0xFF4B3E) : Color(hex: 0x4BE37A))
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(Color(hex: 0x111111), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: 0x555555), lineWidth: 3))
        .accessibilityLabel(Text(verbatim: on ? "ZTL attiva" : "ZTL non attiva"))
    }
}
