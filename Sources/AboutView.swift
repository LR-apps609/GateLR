import SwiftUI

/// Fonti, licenze (i dati aperti CC-BY chiedono l'attribuzione) e avvertenze.
struct AboutView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Wordmark(size: 22)
                    Text("Know before the gate.").font(Theme.display(20)).foregroundStyle(Theme.ink)
                    Text("GateLR explains Italy's limited traffic zones in plain words and links every rule to the city's official source.")
                        .font(.app(size: 14)).foregroundStyle(Theme.muted)
                }
                .padding(.vertical, 6)
            }
            Section("Please note") {
                Label("Road signs and gate panels on site always win over the app.", systemImage: "exclamationmark.triangle")
                Label("Cities marked Draft come from official sources but haven't been reviewed by a person yet.", systemImage: "clock")
                Label("GateLR is not affiliated with any city or with the police.", systemImage: "building.columns")
            }
            .font(.app(size: 14))
            ForEach(store.cities) { city in
                Section(city.localizedName) {
                    if let license = city.license { Text(L(license)).font(.app(size: 13)) }
                    ForEach(Array(Set(city.zones.flatMap(\.source.links))).sorted { $0.localizedTitle < $1.localizedTitle }, id: \.self) { l in
                        Link(destination: l.url) {
                            HStack { Text(l.localizedTitle).font(.app(size: 14)).multilineTextAlignment(.leading); Spacer(); Image(systemName: "arrow.up.right").font(.app(size: 12)) }
                        }
                    }
                }
            }
            Section("Typeface and maps") {
                Text("Titillium Web, SIL Open Font License 1.1 (Accademia di Belle Arti di Urbino).").font(.app(size: 13))
                Text("Maps and car parks: Apple Maps.").font(.app(size: 13))
            }
            Section {
                Text("Part of the LR family: AudioLR, OrbitLR, WebcamLR, GateLR.")
                    .font(.app(size: 13)).foregroundStyle(Theme.brass)
            }
        }
        .tint(Theme.blue)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
