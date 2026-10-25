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
        // Primo avvio (presentazione ancora da vedere): niente novità
        guard onboarded else { return false }
        return seen != version
    }

    private let items: [(symbol: String, tint: Color, title: String, text: String)] = [
        ("waveform", Color(hex: 0x7A4BD1), "Ask Siri about a zone",
         "\"Hey Siri, can I drive into Florence Sector A with GateLR?\": the answer for now or for the time you arrive."),
        ("shield.slash", Theme.red, "Stop the guardian by voice",
         "\"Hey Siri, stop the GateLR guardian\", also from Shortcuts and the Action button."),
        ("shield.lefthalf.filled", Color(hex: 0x1F4E9E), "Guardian widget",
         "On the Home and Lock Screen: your zone right now and one tap to start the guardian."),
    ]

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
