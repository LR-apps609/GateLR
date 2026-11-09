import SwiftUI
import UIKit

// 2.3 «Grafica» (tavole S-Colori, S-Tipo, P25-Confronto: direzione C). Giorno e Notte automatici, dal telefono: chiaro
// al sole, blu notte di sera. Il blocco della risposta è IDENTICO nei due temi (stessi pieni, stessi contrasti AA).
// Tutti i colori stanno qui, in ColorToken (valore di Giorno e di Notte); il resto dell'app usa Theme e i colori
// della risposta (Tono, Verdict). Gli stessi valori su Android (android/app/.../UI.kt, Palette) e nei test
// (Tests/GraficaTests.swift calcola i contrasti).
/// Testo tradotto (Resources/Localizations/*.lproj/Localizable.strings); senza traduzione resta l'inglese
func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

/// Un colore con il suo valore di Giorno e di Notte (uguali per i pieni della risposta)
struct ColorToken: Equatable {
    let day: UInt32
    let night: UInt32
    init(day: UInt32, night: UInt32) { self.day = day; self.night = night }
    /// Lo stesso valore nei due temi
    init(_ both: UInt32) { day = both; night = both }
    var color: Color { day == night ? Color(hex: day) : Color(light: day, dark: night) }
    func hex(night isNight: Bool) -> UInt32 { isNight ? night : day }
    /// Il valore di un tema solo (Live Activity e Dynamic Island hanno sempre il fondo scuro)
    func fixedColor(night isNight: Bool) -> Color { Color(hex: hex(night: isNight)) }
    /// Uguale di giorno e di notte?
    var fixed: Bool { day == night }
}

/// I token di S-Colori, in un solo posto
enum Tokens {
    // Superfici e testi
    static let ground = ColorToken(day: 0xF4F6FA, night: 0x0B1530)
    static let surface = ColorToken(day: 0xFFFFFF, night: 0x142049)
    static let surface2 = ColorToken(day: 0xE9EDF5, night: 0x1B2A5C)
    static let line = ColorToken(day: 0xD5DAE6, night: 0x2A3A70)
    static let text = ColorToken(day: 0x0B1530, night: 0xF2F4FA)
    static let text2 = ColorToken(day: 0x4A5675, night: 0xB4BEDB)
    /// Solo testi da 15 punti in su
    static let text3 = ColorToken(day: 0x4A5675, night: 0x8E9AC0)

    /// I pulsanti principali: chiari su Notte, scuri su Giorno; mai rossi
    static let primary = text
    static let onPrimary = ColorToken(day: 0xFFFFFF, night: 0x0B1530)

    // La risposta: pieni uguali di giorno e di notte
    static let noFill = ColorToken(0xC62A24)
    static let yesFill = ColorToken(0x147A3C)
    static let condFill = ColorToken(0xFFC629)
    /// Il grigio pieno: «Fuori dalla ZTL» (e la ZTL non attiva, se un giorno stateOff diventa grigio)
    static let greyFill = ColorToken(0x5E6982)
    static let onNo = ColorToken(0xFFFFFF)
    static let onYes = ColorToken(0xFFFFFF)
    static let onCond = ColorToken(0x0B1530)
    static let onGrey = ColorToken(0xFFFFFF)

    // La risposta detta con una parola su fondo (mappa, righe, avvisi)
    static let noInk = ColorToken(day: 0xB3261E, night: 0xFF6B5E)
    static let yesInk = ColorToken(day: 0x147A3C, night: 0x4FD18B)
    static let condInk = ColorToken(day: 0x8A6100, night: 0xFFC629)
    static let greyInk = ColorToken(day: 0x5E6982, night: 0xB4BEDB)

    // Fondi tenui per gli avvisi e le pillole di stato (mai per la risposta)
    static let amberSoft = ColorToken(day: 0xFFF1C2, night: 0x3A2C0E)
    static let amberSoftInk = ColorToken(day: 0x5C4100, night: 0xFFC629)
    static let greenSoft = ColorToken(day: 0xD9F0E2, night: 0x183021)
    static let greenSoftInk = ColorToken(day: 0x0F5E2E, night: 0x7FD19B)
    static let redSoft = ColorToken(day: 0xF9DCDA, night: 0x3D1A1C)
    static let redSoftInk = ColorToken(day: 0xB3261E, night: 0xF59A96)

    /// Il rosso del marchio: solo nel logo, mai sui pulsanti (non si confonde con «Non entrare»)
    static let brand = ColorToken(0xE5322D)
    /// Il pannello LED: luce neutra bianco caldo su nero, non contraddice mai la risposta
    static let led = ColorToken(0xFFE7B0)
    static let ledGround = ColorToken(0x050505)
    static let ledFrame = ColorToken(0x2A3A70)
    /// Il segno «P» dei parcheggi e il blu dei cartelli (corsie dei bus)
    static let parking = ColorToken(0x0A4FB8)

    /// Le coppie testo/fondo da tenere almeno a 4,5:1 (Tests/GraficaTests.swift le controlla in tutti e due i temi)
    static let textPairs: [(name: String, ink: ColorToken, ground: ColorToken)] = [
        ("testo/fondo", text, ground), ("testo/superficie", text, surface), ("testo/superficie 2", text, surface2),
        ("testo 2/fondo", text2, ground), ("testo 2/superficie", text2, surface), ("testo 2/superficie 2", text2, surface2),
        ("testo 3/fondo", text3, ground), ("testo 3/superficie", text3, surface),
        ("pulsante", onPrimary, primary),
        ("no pieno", onNo, noFill), ("sì pieno", onYes, yesFill), ("condizione pieno", onCond, condFill), ("grigio pieno", onGrey, greyFill),
        ("no/fondo", noInk, ground), ("no/superficie", noInk, surface),
        ("sì/fondo", yesInk, ground), ("sì/superficie", yesInk, surface),
        ("condizione/fondo", condInk, ground), ("condizione/superficie", condInk, surface),
        ("grigio/fondo", greyInk, ground), ("grigio/superficie", greyInk, surface),
        ("avviso giallo", amberSoftInk, amberSoft), ("avviso verde", greenSoftInk, greenSoft), ("avviso rosso", redSoftInk, redSoft),
        ("pannello LED", led, ledGround), ("parcheggio", ColorToken(0xFFFFFF), parking),
    ]
}

enum Theme {
    static let ground = Tokens.ground.color
    static let card = Tokens.surface.color
    /// I campi dentro le schede, le icone delle righe
    static let raised = Tokens.surface2.color
    static let ink = Tokens.text.color
    static let muted = Tokens.text2.color
    static let faint = Tokens.text3.color
    /// 1.20.4 (decisione di Ledion del 07/11): «Fuori dalla ZTL» in una città coperta è GRIGIO, mai verde. Un solo valore
    /// per tutta l'app, come inchiostro sul fondo (il pieno è Tokens.greyFill)
    static let outside = Tokens.greyInk.color
    static let line = Tokens.line.color
    /// Il rosso della risposta «no» detto su fondo (testi, icone)
    static let red = Tokens.noInk.color
    /// 2.3: il vecchio «blu» dei testi e dei collegamenti è l'inchiostro del tema (blu notte di giorno, bianco di notte)
    static let blue = Tokens.text.color
    /// Il fondo delle icone delle righe e dei segni dei cartelli (bus, guida): il blu dei cartelli, con il simbolo bianco
    static let blueFill = Tokens.parking.color
    /// I pulsanti principali (chiari su Notte, scuri su Giorno) e il loro testo
    static let primary = Tokens.primary.color
    static let onPrimary = Tokens.onPrimary.color
    /// 2.0 (B79): il rosso dei fondi con il testo bianco, uguale al buio (5,6:1)
    static let redFill = Tokens.noFill.color
    static let blueSoft = Tokens.surface2.color
    static let green = Tokens.yesFill.color
    static let greenSoft = Tokens.greenSoft.color
    static let greenInk = Tokens.yesInk.color
    /// L'ambra scura per i cerchi con il «!» bianco (5,5:1)
    static let amber = Color(hex: 0x8A6100)
    static let amberSoft = Tokens.amberSoft.color
    static let amberInk = Tokens.amberSoftInk.color
    static let brand = Tokens.brand.color
    static let brass = Color(light: 0x8A6100, dark: 0xD6AA62)       // il filo della famiglia LR

    // MARK: Spazi, raggi e bersagli (S-Tipo)

    static let space: [CGFloat] = [4, 8, 12, 16, 24, 32]
    enum Radius { static let small: CGFloat = 12, medium: CGFloat = 16, large: CGFloat = 22, sheet: CGFloat = 28 }
    /// Bersagli di tocco in punti: minimo 44, standard 52, in auto 64, in auto il principale 76
    enum Target { static let minimum: CGFloat = 44, standard: CGFloat = 52, car: CGFloat = 64, carPrimary: CGFloat = 76 }

    // MARK: Caratteri (S-Tipo)

    /// Titoli: Titillium Web, il carattere dei cartelli (licenza OFL, in Resources/Fonts), interlinea stretta.
    /// 2.3: cresce con il Dynamic Type dello stile vicino (relativeTo), al massimo 1,4× (S-Tipo, «tetto 1,4×»): oltre,
    /// i nomi dei posti a 30 punti si spezzavano a metà parola (B64, B65). La parola della risposta non ha tetto: è
    /// Theme.answerWord, a capo per parole (AnswerWords)
    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .custom(titillium(weight), fixedSize: capped(size, metrics: UIFontMetrics(forTextStyle: style(for: size)), limit: 1.4)).leading(.tight)
    }
    static func label(_ size: CGFloat = 13) -> Font { .custom("TitilliumWeb-SemiBold", fixedSize: capped(size, metrics: UIFontMetrics(forTextStyle: .footnote), limit: 1.4)) }

    /// La parola della risposta (S-Tipo «risposta», Titillium 900): segue il Dynamic Type fino ad AX5 senza tetto e va
    /// a capo per parole (AnswerWords), mai a metà parola. Nella modalità «In auto» (64 punti) il tetto è 1,4×
    static func answerWord(_ size: CGFloat = 40, car: Bool = false) -> Font {
        car ? .custom("TitilliumWeb-Black", fixedSize: capped(size, metrics: UIFontMetrics(forTextStyle: .largeTitle), limit: 1.4)).leading(.tight)
            : .custom("TitilliumWeb-Black", size: size, relativeTo: .largeTitle).leading(.tight)
    }
    /// La riga sotto la parola (S-Tipo «riga risposta», Titillium 700 · 20)
    static func answerLine(_ size: CGFloat = 20) -> Font { .custom("TitilliumWeb-Bold", size: size, relativeTo: .title3) }
    /// Il pannello LED: DotGothic16 a misura fissa (il pannello è un disegno; VoiceOver legge la sua etichetta)
    static func led(_ size: CGFloat) -> Font { .custom("DotGothic16-Regular", fixedSize: size) }

    static func titillium(_ weight: Font.Weight) -> String {
        switch weight {
        case .black, .heavy: "TitilliumWeb-Black"
        case .semibold, .medium: "TitilliumWeb-SemiBold"
        case .regular, .light, .thin, .ultraLight: "TitilliumWeb-Regular"
        default: "TitilliumWeb-Bold"
        }
    }

    /// Lo stile di sistema più vicino a una misura (quanto cresce con il Dynamic Type)
    static func style(for size: CGFloat) -> UIFont.TextStyle {
        switch size {
        case 34...: .largeTitle
        case 26..<34: .title1
        case 21..<26: .title2
        case 19..<21: .title3
        case 16..<19: .body
        case 14..<16: .subheadline
        default: .footnote
        }
    }

    /// La misura con «Testo più grande», al massimo +30% (o «limit»; calcolata una volta: poi il carattere ha misura fissa)
    static func capped(_ size: CGFloat, metrics: UIFontMetrics = .default, traits: UITraitCollection? = nil, limit: CGFloat = 1.3) -> CGFloat {
        min(size * limit, traits.map { metrics.scaledValue(for: size, compatibleWith: $0) } ?? metrics.scaledValue(for: size))
    }
}

extension Font {
    /// Testo dell'app che segue «Testo più grande» dell'iPhone, fino a +30% per non rompere l'impaginazione
    static func app(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        .system(size: min(size * 1.3, UIFontMetrics.default.scaledValue(for: size)), weight: weight, design: design)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
    init(light: UInt32, dark: UInt32) {
        func ui(_ h: UInt32) -> UIColor {
            UIColor(red: CGFloat((h >> 16) & 0xFF) / 255, green: CGFloat((h >> 8) & 0xFF) / 255, blue: CGFloat(h & 0xFF) / 255, alpha: 1)
        }
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? ui(dark) : ui(light) })
    }
}

/// Il contrasto WCAG fra due colori (1…21)
enum Contrast {
    static func luminance(_ hex: UInt32) -> Double {
        func channel(_ v: UInt32) -> Double {
            let c = Double(v & 0xFF) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(hex >> 16) + 0.7152 * channel(hex >> 8) + 0.0722 * channel(hex)
    }
    static func ratio(_ a: UInt32, _ b: UInt32) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}

extension Verdict {
    /// 2.3: il pieno della risposta, uguale di giorno e di notte (giallo pieno con l'inchiostro scuro per «!» e «?»)
    var fillToken: ColorToken {
        switch self {
        case .yes: Tokens.yesFill
        case .no: Tokens.noFill
        case .conditional, .unsure: Tokens.condFill
        }
    }
    var onFillToken: ColorToken {
        switch self {
        case .yes: Tokens.onYes
        case .no: Tokens.onNo
        case .conditional, .unsure: Tokens.onCond
        }
    }
    var fill: Color { fillToken.color }
    var onFill: Color { onFillToken.color }
    /// Il cerchio con il simbolo: il colore del testo sul pieno, il simbolo nel colore del pieno
    var badgeFill: Color { onFill }
    var badgeInk: Color { fill }
    var symbol: String {
        switch self {
        case .yes: "checkmark"
        case .no: "xmark"
        case .conditional: "exclamationmark"
        case .unsure: "questionmark"
        }
    }
    /// Il titolo spezzato a mano in righe: Titillium ha un'interlinea ampia, così le righe stanno strette (1.20.3: il
    /// titolo fisso di AnswerWord, «Non|entrare», «Puoi|entrare», «A una|condizione», «Controlla il|cartello»)
    var titleLines: [String] { word(unofficial: false).lines }
    /// Versione breve per pillole e liste: lo stesso titolo fisso (1.20.3)
    var short: String { word(unofficial: false).title }
    /// Il titolo fisso detto con prudenza quando le regole vengono da fonti non ufficiali (1.20.3): un «sì» diventa
    /// «Controlla il cartello»; «Probabilmente sì/no» è solo la spiegazione (unofficialNote)
    func shortText(unofficial: Bool) -> String { word(unofficial: unofficial).title }
    /// La frase breve da dire o scrivere da sola (Siri, Live Activity, avvisi): il titolo fisso e, da fonte non ufficiale,
    /// la spiegazione («Controlla il cartello · Probabilmente sì · fonte non ufficiale»)
    func spokenText(unofficial: Bool) -> String {
        let title = word(unofficial: unofficial).title
        guard let note = unofficialNote(unofficial: unofficial) else { return title }
        return title + " · " + note
    }
    /// Il titolo in righe, con prudenza se la fonte non è ufficiale
    func titleLines(unofficial: Bool) -> [String] { word(unofficial: unofficial).lines }
    /// 2.3 (S-Risposta, taglia S): la pillola è piena come il blocco, con l'inchiostro del pieno
    var pillFill: Color { fill }
    var pillInk: Color { onFill }
}

extension ZoneKind {
    /// Rosso del divieto, giallo del pass, verde della zona a basse emissioni
    var color: Color {
        switch self {
        case .restricted: Tokens.noFill.color
        case .pass: Color(light: 0xD99A00, dark: 0xF2C14E)
        case .green: Tokens.yesFill.color
        }
    }
    var symbol: String {
        switch self {
        case .restricted: "nosign"
        case .pass: "ticket"
        case .green: "leaf"
        }
    }
}

// MARK: 2.1 · I colori della RispostaFinale (shared/risposta-finale.md)

extension Tono {
    /// Lo stesso tono con «spento» risolto in RispostaFinale.stateOff (oggi verde): il cambio sta in quella riga
    var resolved: Tono { self == .spento ? (RispostaFinale.stateOff == .spento ? .grigio : RispostaFinale.stateOff) : self }

    /// Il pieno del blocco della risposta, uguale di giorno e di notte. «neutro» (posto che non conosciamo) non ha pieno:
    /// il contorno tratteggiato sul fondo
    var fillToken: ColorToken? {
        switch resolved {
        case .rosso: Tokens.noFill
        case .giallo: Tokens.condFill
        case .verde: Tokens.yesFill
        case .grigio, .spento: Tokens.greyFill
        case .neutro: nil
        }
    }
    /// L'inchiostro sul pieno (sul fondo per «neutro»)
    var onFillToken: ColorToken {
        switch resolved {
        case .rosso: Tokens.onNo
        case .giallo: Tokens.onCond
        case .verde: Tokens.onYes
        case .grigio, .spento: Tokens.onGrey
        case .neutro: Tokens.text
        }
    }
    /// La parola o l'icona del tono su fondo (righe, mappa, avvisi): almeno 4,5:1 nei due temi
    var inkToken: ColorToken {
        switch resolved {
        case .rosso: Tokens.noInk
        case .giallo: Tokens.condInk
        case .verde: Tokens.yesInk
        case .grigio, .spento: Tokens.greyInk
        case .neutro: Tokens.text2
        }
    }
    /// Il colore pieno di ogni tono semantico (il pieno della risposta; «neutro» il suo inchiostro)
    var color: Color { (fillToken ?? inkToken).color }
    var fill: Color { fillToken?.color ?? .clear }
    var onFill: Color { onFillToken.color }
    var ink: Color { inkToken.color }
}

extension Theme {
    /// La ZTL non attiva: un solo token per tutta l'app (RispostaFinale.stateOff, oggi verde per regola di Ledion)
    static var stateOff: Color { Tono.spento.color }
}

extension Stato {
    /// Il colore dello stato su fondo (icone, righe): l'inchiostro del tono
    var tint: Color { color.ink }
    var fill: Color { color.fill }
    var onFill: Color { color.onFill }
}
