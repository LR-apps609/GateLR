import Foundation
import SwiftUI
import UserNotifications
import UIKit

/// 1.19.3: chi consegna gli avvisi di ThreatEvaluator, per guida, guardiano e avvisi ad app chiusa. Uno solo per l'app:
/// lo stesso avviso non arriva due volte (ThreatDeduper), con l'app aperta è un banner dentro l'app (niente doppione con
/// la notifica di iOS), ad app chiusa una notifica. Il tocco (sul banner o sulla notifica) apre «Parcheggia fuori» per
/// quella zona: prima «Tocca per i parcheggi fuori» apriva solo l'app.
@MainActor
final class ThreatAlerts: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = ThreatAlerts()

    struct Banner: Identifiable, Equatable {
        let id = UUID()
        var title: String
        var body: String
        var level: ThreatLevel
        var park: Place?
    }

    /// Il banner dentro l'app (app aperta)
    @Published var banner: Banner?
    /// «Parcheggia fuori» da aprire: tocco sulla notifica o sul banner
    @Published var parkFor: Place?

    private(set) var deduper = ThreatDeduper()
    private var hide: Task<Void, Never>?
    private static var uitest: Bool { ProcessInfo.processInfo.arguments.contains("-uitest") }

    /// All'avvio dell'app: il tocco su un avviso arriva anche se l'app era chiusa
    func install() {
        UNUserNotificationCenter.current().delegate = self
    }

    /// Avvisa per una zona davanti, se è la prima volta in questo avvicinamento e la risposta non è verde.
    /// «prefix» separa avvisi diversi per la stessa zona («in» = sei appena entrato). Vero se ha avvisato.
    @discardableResult
    func post(_ t: ZoneThreat, prefix: String = "", now: Date = Date(), inApp: Bool? = nil) -> Bool {
        guard let title = t.title else { return false }
        guard deduper.shouldAlert(prefix.isEmpty ? t.candidate.id : "\(prefix)|\(t.candidate.id)", now: now) else { return false }
        deliver(title: title, body: t.body, level: t.level, park: Place(name: t.candidate.name, address: "", location: t.point),
                zoneId: t.candidate.id, id: "threat|\(prefix)|\(t.candidate.id)", inApp: inApp)
        return true
    }

    /// Le zone da cui ti sei allontanato si possono avvisare di nuovo
    func moved(_ distances: [String: Double]) { deduper.moved(distances) }

    /// Un avviso già pronto (prova da Impostazioni, «Sei arrivato»)
    func deliver(title: String, body: String, level: ThreatLevel, park: Place?, zoneId: String, id: String, inApp: Bool? = nil) {
        // 1.19.4: un avviso si vede a telefono bloccato: mai una targa
        let title = PlatePrivacy.clean(title), body = PlatePrivacy.clean(body)
        // App davanti (anche «inattiva» un istante, es. all'avvio): il banner; in sottofondo o a schermo bloccato la notifica
        let foreground = inApp ?? (Self.uitest || UIApplication.shared.applicationState != .background)
        if foreground {
            banner = Banner(title: title, body: body, level: level, park: park)
            UINotificationFeedbackGenerator().notificationOccurred(level == .stop ? .error : .warning)
            // 2.0 (B124): VoiceOver lo dice subito, prima di ogni altra cosa (guardiano e guida parlano, il banner no)
            UIAccessibility.post(notification: .announcement, argument: "\(title). \(body)")
            hide?.cancel()
            // Nel giro delle foto resta, per la foto; con VoiceOver resta finché non lo chiudi (10 s non bastano)
            guard Self.autoHides(uitest: Self.uitest, voiceOver: UIAccessibility.isVoiceOverRunning) else { return }
            hide = Task { [weak self] in
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { return }
                self?.banner = nil
            }
            return
        }
        let c = UNMutableNotificationContent()
        c.title = title
        c.body = body
        c.sound = .default
        c.interruptionLevel = .timeSensitive
        if let park, let url = ParkLink.url(zoneId: zoneId, name: park.name, at: park.location) { c.userInfo = ["url": url.absoluteString] }
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: c, trigger: nil))
    }

    /// Il banner sparisce da solo dopo 10 secondi, tranne nel giro delle foto e con VoiceOver (B124)
    nonisolated static func autoHides(uitest: Bool, voiceOver: Bool) -> Bool { !uitest && !voiceOver }

    /// Tocco sul banner: «Parcheggia fuori» per quella zona
    func openBanner() {
        hide?.cancel()
        parkFor = banner?.park
        banner = nil
    }

    func dismissBanner() {
        hide?.cancel()
        banner = nil
    }

    /// gatelr://park?…: il foglio «Parcheggia fuori»
    func open(_ url: URL) {
        if let p = ParkLink.place(from: url) { parkFor = p }
    }

    // MARK: Notifiche

    /// Tocco sulla notifica: si apre «Parcheggia fuori» per quella zona
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let link = response.notification.request.content.userInfo["url"] as? String
        Task { @MainActor in
            if let link, let url = URL(string: link) { ThreatAlerts.shared.open(url) }
            completionHandler()
        }
    }

    /// Anche con l'app aperta la notifica si vede in alto (l'avviso di prova da Impostazioni)
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

/// Il banner dell'avviso dentro l'app: colore della risposta, titolo con le parole della risposta, tocco = parcheggi fuori
struct ThreatBannerView: View {
    var banner: ThreatAlerts.Banner
    var onTap: () -> Void
    var onClose: () -> Void

    /// Fondo e testo per ogni livello (testabile). 2.0 (B67): sull'ambra il testo è scuro (6,6:1; bianco era 2,45:1)
    static func colors(_ level: ThreatLevel) -> (fill: UInt32, ink: UInt32) {
        switch level {
        case .stop: (0xC1272D, 0xFFFFFF)
        case .condition, .check: (0xD99A00, 0x1B2128)
        case .clear: (0x5B6476, 0xFFFFFF)
        }
    }
    private var fill: Color { Color(hex: Self.colors(banner.level).fill) }
    private var ink: Color { Color(hex: Self.colors(banner.level).ink) }

    private var symbol: String {
        switch banner.level {
        case .stop: "xmark.octagon.fill"
        case .condition: "exclamationmark.triangle.fill"
        case .check, .clear: "questionmark.circle.fill"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).font(.app(size: 22, weight: .bold))
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: banner.title).font(.app(size: 16, weight: .bold)).lineLimit(2)
                Text(verbatim: banner.body).font(.app(size: 13)).lineLimit(3).opacity(0.95)
            }
            Spacer(minLength: 0)
            // 2.0 (B123): la croce prende 44×44 punti (prima ~29: chi la mancava apriva i parcheggi)
            Button(action: onClose) {
                Image(systemName: "xmark").font(.app(size: 13, weight: .bold))
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .padding(.top, -10).padding(.trailing, -10)
            .accessibilityLabel(Text("Close"))
        }
        .foregroundStyle(ink)
        .padding(14)
        .background(fill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("threat.banner")
        .padding(.horizontal, 12)
    }
}
