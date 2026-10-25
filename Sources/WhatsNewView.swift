import SwiftUI

/// «Novità»: si mostra una volta sola dopo ogni aggiornamento dell'app (mai al primo avvio, c'è la presentazione,
/// e mai nel giro automatico delle foto). L'ultima versione vista resta in UserDefaults («seenVersion»).
struct WhatsNewView: View {
    var done: () -> Void

    private static let key = "seenVersion"
    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "" }

    /// Da mostrare adesso? Segna subito la versione come vista, così non ricompare
    static func shouldShow(onboarded: Bool) -> Bool {
        let args = ProcessInfo.processInfo.arguments
        guard !args.contains("-uitest"), !version.isEmpty else { return false }
        let seen = UserDefaults.standard.string(forKey: key)
        UserDefaults.standard.set(version, forKey: key)
        return shouldShow(version: version, seen: seen, onboarded: onboarded)
    }

    /// La decisione, senza UserDefaults (testabile). Primo avvio (presentazione ancora da vedere): niente novità.
    /// Le versioni di sole correzioni (es. 1.12.1) non hanno novità: niente foglio vuoto o con quelle vecchie.
    static func shouldShow(version: String, seen: String?, onboarded: Bool) -> Bool {
        onboarded && seen != version && !(notes[version] ?? []).isEmpty
    }

    typealias Item = (symbol: String, tint: Color, title: String, text: String)

    /// Le novità di ogni versione che ne ha (chiave: CFBundleShortVersionString)
    static let notes: [String: [Item]] = [
        "1.13.0": [
            ("hand.tap.fill", Theme.green, "Answers in one tap",
             "On the first page, tap your hotel or a recent place: the answer appears right there, without leaving the page."),
            ("figure.wave", Color(hex: 0x1F4E9E), "A friendlier start",
             "The first time, choose where you're going and see why GateLR asks for your location before iOS does."),
            ("lightbulb.fill", Color(hex: 0x7A4BD1), "Tips when you need them",
             "A few short tips in Trip, Map and Account, and empty pages that explain what to do with one button."),
        ],
        "1.12.0": [
            ("map", Theme.green, "Smoother maps",
             "Milan, Florence and Rome move smoothly when you zoom in and out: from far away the borders are lighter and the gates appear as you get closer."),
            ("bolt.fill", Color(hex: 0x1F4E9E), "Quicker answers",
             "Finding the zone of an address or of where you are takes less time, also while you drive."),
            ("ipad.landscape", Color(hex: 0x7A4BD1), "GateLR on iPad",
             "Every orientation, the map full screen and pages that stay easy to read on the big screen."),
        ],
    ]

    private var items: [Item] { Self.notes[Self.version] ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    LogoMark(size: 64).padding(.top, 28)
                    Text(String(format: L("What's new in GateLR %@"), Self.version))
                        .font(Theme.display(32)).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(items, id: \.title) { item in
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: item.symbol)
                                    .font(.app(size: 18, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 40, height: 40)
                                    .background(item.tint, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L(item.title)).font(.app(size: 16, weight: .bold)).foregroundStyle(Theme.ink)
                                    Text(L(item.text)).font(.app(size: 14)).foregroundStyle(Theme.muted)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .padding(16).card()
                }
                .padding(.horizontal, 24).padding(.bottom, 16)
            }
            WideButton(title: "Continue", systemImage: nil) { done() }
                .padding(.horizontal, 24).padding(.vertical, 12)
                .accessibilityIdentifier("whatsnew.continue")
        }
        .background(Theme.ground.ignoresSafeArea())
    }
}
