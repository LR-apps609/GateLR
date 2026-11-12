import SwiftUI

// 2.0.2 «Fiducia» (bozza approvata: chip «✓ Controllata …», chip giallo «Non ancora verificata a mano», «Fonte: Comune di …»,
// pulsante bordato «Mandalo al tuo hotel / noleggio», riga piccola con le due pagine). Sotto la risposta, mai al posto suo:
// il colore della risposta non cambia. Come TrustBox di Android e la riga «fid» del sito.

/// Le due pagine della fiducia, dalla risposta (foglio) e da Aiuto e Informazioni
enum FiduciaPage: String, Identifiable, Hashable {
    case checks, fine
    var id: String { rawValue }
}

/// La riga della fiducia sotto una risposta. `zone`: la zona che decide (nil fuori dalle zone: niente data, solo pulsante e
/// link); `place`: il posto cercato (nil o la tua posizione: si condivide la pagina della città, mai dove sei)
struct FiduciaFooter: View {
    @EnvironmentObject var store: Store
    var zone: Zone?
    var city: City?
    var place: Place?
    @State private var page: FiduciaPage?
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let zone {
                let c = Fiducia.control(zone.source, now: Date(), staleAfterDays: store.engine.staleAfterDays)
                // La spunta solo con i dati freschi (verificati o letti da al più 120 giorni, pagina non cambiata)
                chip(c.text, symbol: c.fresh ? "checkmark" : "clock", fill: c.fresh ? Theme.greenSoft : Theme.raised,
                     ink: c.fresh ? Tokens.greenSoftInk.color : Theme.muted)
                    .accessibilityIdentifier("fiducia.checked")
                if !c.byHand {
                    chip(L("Not yet verified by hand"), symbol: nil, fill: Theme.amberSoft, ink: Theme.amberInk)
                        .accessibilityIdentifier("fiducia.byHand")
                }
                // La fonte: il sito non ufficiale con il suo nome, se le regole vengono da lì; altrimenti il Comune
                let unofficial = zone.source.isOfficial ? nil : zone.source.unofficialSource
                Link(destination: unofficial?.url ?? zone.source.pageURL) {
                    Text(verbatim: String(format: L("Source: %@"), unofficial?.name ?? zone.source.localizedAuthority) + " ›")
                        .font(.app(size: 15, weight: .medium)).foregroundStyle(Theme.ink)
                        .underline()
                        .multilineTextAlignment(.leading)
                        .frame(minHeight: Theme.Target.minimum, alignment: .leading)
                }
                .accessibilityIdentifier("fiducia.source")
            }
            ShareLink(item: shareText) {
                VStack(spacing: 2) {
                    Label(L("Send it to your hotel / rental"), systemImage: "square.and.arrow.up")
                        .font(.app(size: 16, weight: .bold)).foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                    Text("Opens in the browser, nothing to install")
                        .font(.app(size: 13)).foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: Theme.Target.standard)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.ink, lineWidth: 1.5))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("fiducia.share")
            // Le due pagine: affiancate, una sotto l'altra con il testo grande
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0)) : AnyLayout(HStackLayout(spacing: 14))
            layout {
                pageLink(L("How we check the data"), .checks).accessibilityIdentifier("fiducia.checks")
                pageLink(L("What to do if you get a fine"), .fine).accessibilityIdentifier("fiducia.fine")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(item: $page) { p in
            NavigationStack {
                FiduciaPageView(page: p)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { page = nil } } }
            }
        }
    }

    /// Il testo con il link: per il posto cercato, o per la città se il posto è la tua posizione
    private var shareText: String {
        let shareCity = city ?? zone.flatMap { z in store.cities.first { $0.zones.contains(z) } }
        let own = place == nil || place?.name == L("My position")
        let url = Fiducia.shareURL(lang: Fiducia.appLanguage, cityId: shareCity?.id, placeName: own ? nil : place?.name,
                                   lat: own ? nil : place?.location.lat, lon: own ? nil : place?.location.lon,
                                   vehicleKey: Fiducia.vehicleKey(store.vehicle))
        return Fiducia.shareText(name: own ? (shareCity?.localizedName ?? "") : (place?.name ?? ""), url: url)
    }

    private func chip(_ text: String, symbol: String?, fill: Color, ink: Color) -> some View {
        HStack(spacing: 5) {
            if let symbol { Image(systemName: symbol).font(.app(size: 13, weight: .bold)).accessibilityHidden(true) }
            Text(verbatim: text).font(.app(size: 15, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(ink)
        .padding(.horizontal, 12).padding(.vertical, 5)
        .background(fill, in: Capsule())
    }

    private func pageLink(_ title: String, _ p: FiduciaPage) -> some View {
        Button { page = p } label: {
            Text(verbatim: title + " ›").font(.app(size: 14)).foregroundStyle(Theme.muted)
                .multilineTextAlignment(.leading)
                .frame(minHeight: Theme.Target.minimum, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// «Come controlliamo i dati» e «Cosa fare se ricevi una multa»: brevi, oneste, dai fatti del repository
struct FiduciaPageView: View {
    var page: FiduciaPage

    /// Le sezioni: titolo e testo (chiavi di Tools/translations.py)
    static func sections(_ page: FiduciaPage) -> [(title: String, body: String)] {
        switch page {
        case .checks:
            return [
                (L("Where the data comes from"), L("Hours, rules and ZTL borders come from the official pages and open data of each city (the Comune). Where a city publishes nothing usable, the source is marked unofficial and those answers are never green.")),
                (L("Checked automatically every morning"), L("Every morning a program opens the city pages we cite and compares them with the last reading. If a page has changed, the answers for that zone turn yellow («Check the sign») until a person reads it again.")),
                (L("The date and the source on every answer"), L("Under every answer you see when we last checked the rules against the official sources, and a link to the city's page, so you can read it yourself.")),
                (L("Verification by hand: still in progress"), L("A person still has to compare each zone with the signs and the official acts. Until that's done, the answer shows the yellow label «Not yet verified by hand». The colour of the answer doesn't change because of it.")),
                (L("When we're not sure: yellow"), L("If the data is older than 120 days, the city's page has changed, the source is unofficial or it's a public holiday we couldn't confirm, the answer is yellow: «Check the sign». We'd rather say we're not sure than say green by mistake.")),
            ]
        case .fine:
            return [
                (L("Check the notice"), L("Read date, time, gate (camera) and plate. Check that the plate is yours and that you really drove there at that time.")),
                (L("Compare with the city's page"), L("Open the city's official page (the link is under every answer) and check the hours that applied that day. Photos of the signs and panels help.")),
                (L("Rental car or hotel?"), L("With a rental car the notice usually reaches the rental company first: ask them what they received and what they charged you. If your hotel was meant to register your plate, ask the hotel in writing whether and when it did.")),
                (L("Appeals in Italy"), L("You can appeal to the Prefetto within 60 days of the notification, or to the Giudice di Pace (justice of the peace) within 30 days (Highway Code, art. 203 and 204-bis). If you pay first, you can no longer appeal. The notice says where and how: what it says counts.")),
            ]
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if page == .fine {
                    // GateLR non rimborsa multe: detto chiaro e gentile, prima di tutto
                    Text("GateLR can't refund fines, and we'd rather say so clearly. This page is general information, not legal advice: here is what you can check.")
                        .font(.app(size: 16, weight: .semibold)).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("fiducia.noRefund")
                }
                ForEach(Array(Self.sections(page).enumerated()), id: \.offset) { _, s in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: s.title).font(Theme.display(20)).foregroundStyle(Theme.ink)
                            .accessibilityAddTraits(.isHeader)
                        Text(verbatim: s.body).font(.app(size: 15)).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading).card(18)
                }
                if page == .fine {
                    VStack(alignment: .leading, spacing: 0) {
                        SectionLabel("Official sources").padding(.bottom, 4)
                        ForEach(Array(Fiducia.fineSources.enumerated()), id: \.offset) { _, s in
                            Link(destination: s.url) {
                                HStack {
                                    Text(verbatim: L(s.title)).multilineTextAlignment(.leading)
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                }
                                .font(.app(size: 14)).frame(minHeight: Theme.Target.minimum)
                            }
                        }
                    }
                    NavigationLink { FineGuideView() } label: {
                        Text(verbatim: L("Got a fine?") + " ›").font(.app(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                            .frame(minHeight: Theme.Target.minimum, alignment: .leading)
                    }
                    Text("For advice on your own case, ask a lawyer or a consumer association.")
                        .font(.app(size: 13)).foregroundStyle(Theme.muted)
                    Text("General information, not legal advice. The notice you receive always wins: read its deadlines and amounts.")
                        .font(.app(size: 12)).foregroundStyle(Theme.muted)
                } else {
                    Text("Road signs on site always win over the app.")
                        .font(.app(size: 13)).foregroundStyle(Theme.muted)
                }
            }
            .padding(20)
        }
        .background(Theme.ground)
        .tint(Theme.blue)
        .navigationTitle(page == .checks ? L("How we check the data") : L("What to do if you get a fine"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
