import SwiftUI

/// 1.19.4 «Privacy onesta»: cosa resta sull'iPhone, cosa esce e verso chi, detto com'è nel codice. Le richieste in rete
/// dell'app sono solo queste: mappe, ricerche e percorsi di Apple (MapKit), mappe 3D di Mapbox (solo con il token),
/// dati delle città da GitHub (CityUpdater), parcheggi da OpenStreetMap con Overpass (ParkingData, il rettangolo intorno
/// alle zone della città, mai la tua posizione), e quello che mandi tu (messaggio per l'hotel, segnalazioni, diario).
/// Se si aggiunge una richiesta in rete, va scritta qui, nel sito (web/privacy) e in docs/app-store.md.
struct PrivacyView: View {
    @AppStorage(MapboxTelemetry.key) private var mapboxTelemetry = false

    var body: some View {
        List {
            Section {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "hand.raised.fill").font(.app(size: 30)).foregroundStyle(Theme.blue)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No account, no ads, no tracking.").font(.app(size: 18, weight: .semibold)).foregroundStyle(Theme.ink)
                        Text("GateLR has no servers that collect your data. Here is exactly what stays on your iPhone and what goes out.")
                            .font(.app(size: 14)).foregroundStyle(Theme.muted)
                    }
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("privacy.header")
            }

            Section("Stays on this iPhone") {
                item("car.fill", "Your vehicles and plates, permits, trips and the drive log.")
                item("location.fill", "Your location: used on the iPhone for the answer, the alerts and the guardian. GateLR doesn't collect it.")
                item("doc.text.viewfinder", "Photos of signs, registration documents and fines: read on the iPhone, never uploaded.")
            }

            Section {
                item("map.fill", "Maps, search and routes: Apple Maps receives the map area, what you search and, for a route, start and destination.")
                item("cube.fill", "3D maps: Mapbox receives the map requests for the area shown and a usage count for billing. Its telemetry is off unless you turn it on.")
                item("arrow.down.circle.fill", "City data: GateLR downloads the ZTL updates from GitHub. Nothing about you is sent.")
                item("parkingsign.circle.fill", "Car parks: if they aren't already in the app, the area around the city's zones goes to OpenStreetMap (Overpass). Not your position.")
                item("paperplane.fill", "What you choose to send (message for the hotel, reports, the drive log) goes only where you send it.")
            } header: {
                Text("What goes out")
            } footer: {
                Text("These services see your IP address, like any internet request. They don't know who you are in GateLR: there is no account.")
            }

            Section {
                item("eye.slash.fill", "Your plate never appears in shared texts, copies, the widget, Siri, notifications or the Live Activity.")
                item("building.2.fill", "Only exception: the message for the hotel, which needs your plate to register you. You send it yourself.")
            } header: {
                Text("Your plate")
            }

            Section {
                Toggle(isOn: $mapboxTelemetry) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mapbox telemetry").font(.app(size: 16, weight: .semibold))
                        Text("Usage and location data sent to Mapbox to improve its maps. Off unless you turn it on.")
                            .font(.app(size: 13)).foregroundStyle(Theme.muted)
                    }
                }
                .accessibilityIdentifier("privacy.mapboxTelemetry")
            } footer: {
                Text("You can also change it from the (i) on the 3D map.")
            }
        }
        .font(.app(size: 14))
        .navigationTitle("Privacy")
        .tint(Theme.blue)
    }

    private func item(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        Label {
            Text(text).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol).foregroundStyle(Theme.blue)
        }
    }
}

/// La telemetria di Mapbox (Maps SDK v11): la chiave «MGLMapboxMetricsEnabled» di UserDefaults è quella che l'SDK legge
/// (EventsManager) e che cambia il suo menu «Telemetria Mapbox» sotto la (i) della mappa. Di serie l'SDK la accende:
/// GateLR la spegne al primo avvio, prima di creare una mappa, e poi rispetta la scelta di chi usa l'app.
enum MapboxTelemetry {
    static let key = "MGLMapboxMetricsEnabled"
    /// Vero dopo la prima volta: da lì decide l'utente (qui in Privacy o nel menu di Mapbox)
    static let appliedKey = "privacy.mapboxTelemetryDefaultApplied"

    static func applyDefault(_ defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: appliedKey) else { return }
        defaults.set(false, forKey: key)
        defaults.set(true, forKey: appliedKey)
    }

    static func isOn(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: key) as? Bool ?? false
    }
}
