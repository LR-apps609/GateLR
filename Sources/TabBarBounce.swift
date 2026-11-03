import UIKit

/// Il piccolo rimbalzo dell'icona quando scegli una scheda, sulla barra di sistema di iOS.
///
/// SwiftUI copia le icone di `.tabItem` nella barra di UIKit e ignora gli effetti (symbolEffect, scaleEffect), quindi
/// l'effetto si applica all'immagine dentro la barra vera. Se un iOS futuro cambia la barra e l'immagine non si trova,
/// semplicemente non succede niente: nessun errore, il cambio di scheda resta com'è.
///
/// Regole (appena percepibile, la barra si tocca spessissimo): solo la scala, niente ritardi, meno di 0,3 s;
/// con «Riduci movimento» niente animazione. Il contenuto cambia subito, come sempre su iOS.
@MainActor
enum TabBarBounce {
    /// - Parameters:
    ///   - index: la posizione della scheda nella barra (0, 1, 2)
    ///   - symbol: true per i simboli SF (rimbalzo di sistema), false per la scala 1 → 1,12 → 1 (la mappa)
    static func play(index: Int, symbol: Bool) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        // Dopo il giro di disegno in corso, così la barra mostra già la scheda scelta (nessun ritardo percepibile)
        DispatchQueue.main.async {
            guard let bar = tabBar(), let imageView = imageView(in: bar, index: index) else { return }
            if symbol {
                imageView.addSymbolEffect(.bounce, options: .nonRepeating)
            } else {
                scale(imageView)
            }
        }
    }

    /// 1 → 1,12 in 0,09 s, poi ritorno a 1 con una molla senza rimbalzo (smorzamento 1): circa 0,25 s in tutto.
    /// Interrompibile: con tocchi ravvicinati riparte dalla scala attuale (.beginFromCurrentState), senza scatti a 1.
    private static func scale(_ view: UIView) {
        UIView.animate(withDuration: 0.09, delay: 0, options: [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState]) {
            view.transform = CGAffineTransform(scaleX: 1.12, y: 1.12)
        } completion: { _ in
            UIView.animate(withDuration: 0.16, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0,
                           options: [.allowUserInteraction, .beginFromCurrentState]) {
                view.transform = .identity
            }
        }
    }

    // MARK: - Trovare la barra e l'icona

    private static func tabBar() -> UITabBar? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        for window in windows where window.isKeyWindow {
            if let controller = tabController(from: window.rootViewController) { return controller.tabBar }
        }
        return nil
    }

    private static func tabController(from vc: UIViewController?) -> UITabBarController? {
        guard let vc else { return nil }
        if let tab = vc as? UITabBarController { return tab }
        for child in vc.children {
            if let found = tabController(from: child) { return found }
        }
        return nil
    }

    /// L'immagine della scheda: prima per nome (l'etichetta di accessibilità del pulsante è il titolo della scheda),
    /// poi per posizione tra i pulsanti della barra
    private static func imageView(in bar: UITabBar, index: Int) -> UIImageView? {
        if let title = bar.items?[safe: index]?.title,
           let button = firstView(in: bar, where: { $0.isAccessibilityElement && $0.accessibilityLabel == title }),
           let image = firstImageView(in: button) {
            return image
        }
        let buttons = bar.subviews
            .filter { String(describing: type(of: $0)).contains("TabBarButton") }
            .sorted { $0.frame.minX < $1.frame.minX }
        guard let button = buttons[safe: index] else { return nil }
        return firstImageView(in: button)
    }

    private static func firstView(in root: UIView, where match: (UIView) -> Bool) -> UIView? {
        for sub in root.subviews {
            if !sub.isHidden, match(sub) { return sub }
            if let found = firstView(in: sub, where: match) { return found }
        }
        return nil
    }

    private static func firstImageView(in root: UIView) -> UIImageView? {
        firstView(in: root) { ($0 as? UIImageView)?.image != nil && $0.alpha > 0 } as? UIImageView
    }
}

private extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
