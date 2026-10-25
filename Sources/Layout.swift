import SwiftUI

// iPad: le pagine non si allargano su tutto lo schermo (righe di testo lunghe un metro). Su iPhone, e
// nelle finestre strette dell'iPad (Split View, fogli), non cambia nulla.

/// Il contenuto delle pagine che scorrono (ScrollView, List) al massimo largo «maxWidth», al centro:
/// lo sfondo resta a tutta larghezza, crescono solo i margini
private struct ReadableScrollWidth: ViewModifier {
    @Environment(\.horizontalSizeClass) private var size
    let maxWidth: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if size == .regular {
            GeometryReader { geo in
                content.contentMargins(.horizontal, max(0, (geo.size.width - maxWidth) / 2), for: .scrollContent)
            }
        } else {
            content
        }
    }
}

/// Un blocco (barra di ricerca, scheda sopra la mappa) al massimo largo «maxWidth», al centro
private struct ReadableFrame: ViewModifier {
    @Environment(\.horizontalSizeClass) private var size
    let maxWidth: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if size == .regular {
            content.frame(maxWidth: maxWidth).frame(maxWidth: .infinity)
        } else {
            content
        }
    }
}

extension View {
    /// Per le pagine che scorrono: contenuto al centro, largo al massimo 700 punti sull'iPad
    func readableScrollWidth(_ maxWidth: CGFloat = 700) -> some View {
        modifier(ReadableScrollWidth(maxWidth: maxWidth))
    }

    /// Per un blocco singolo: largo al massimo 700 punti sull'iPad, al centro
    func readableFrame(_ maxWidth: CGFloat = 700) -> some View {
        modifier(ReadableFrame(maxWidth: maxWidth))
    }
}
