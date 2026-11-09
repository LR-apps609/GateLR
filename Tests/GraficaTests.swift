import XCTest
import SwiftUI
import UIKit

/// 2.3 «Grafica» (tavole S-Colori, S-Tipo, S-Risposta, S-Movimento): i token di colore, i contrasti calcolati nei due
/// temi, il blocco della risposta uguale di giorno e di notte, la ZTL non attiva come un solo token, l'accessibilità
/// (VoiceOver in un colpo solo, bersagli da 44 punti, parole mai spezzate con il Dynamic Type fino ad AX5)
final class GraficaTests: XCTestCase {
    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

    // MARK: Colori

    /// Ogni testo su ogni fondo almeno 4,5:1, di giorno e di notte (WCAG AA)
    func testTextContrastInBothThemes() {
        for (name, ink, ground) in Tokens.textPairs {
            for night in [false, true] {
                let r = Contrast.ratio(ink.hex(night: night), ground.hex(night: night))
                XCTAssertGreaterThanOrEqual(r, 4.5, "\(name) \(night ? "Notte" : "Giorno"): \(String(format: "%.2f", r)):1")
            }
        }
    }

    /// I numeri delle tavole (S-Colori): così un token cambiato per sbaglio si vede subito
    func testContrastMatchesTheBoards() {
        XCTAssertEqual(Contrast.ratio(0xFFFFFF, Tokens.noFill.day), 5.59, accuracy: 0.02)
        XCTAssertEqual(Contrast.ratio(0xFFFFFF, Tokens.yesFill.day), 5.41, accuracy: 0.02)
        XCTAssertEqual(Contrast.ratio(Tokens.onCond.day, Tokens.condFill.day), 11.48, accuracy: 0.05)
        XCTAssertEqual(Contrast.ratio(Tokens.led.day, Tokens.ledGround.day), 16.80, accuracy: 0.05)
        XCTAssertEqual(Contrast.ratio(Tokens.text.night, Tokens.ground.night), 16.40, accuracy: 0.05)
    }

    /// Il blocco della risposta è identico nei due temi: i pieni e i loro inchiostri non cambiano con Giorno e Notte
    func testAnswerBlockIsTheSameDayAndNight() {
        for t in [Tokens.noFill, Tokens.yesFill, Tokens.condFill, Tokens.greyFill, Tokens.onNo, Tokens.onYes, Tokens.onCond, Tokens.onGrey] {
            XCTAssertTrue(t.fixed, "\(t)")
        }
        for s in Stato.allCases where s != .nonCoperto {
            let fill = try? XCTUnwrap(s.color.fillToken)
            XCTAssertEqual(fill?.fixed, true, "\(s)")
            XCTAssertTrue(s.color.onFillToken.fixed, "\(s)")
            XCTAssertGreaterThanOrEqual(Contrast.ratio(s.color.onFillToken.day, fill?.day ?? 0), 4.5, "\(s)")
        }
        // Il posto che non conosciamo non ha pieno: contorno tratteggiato sul fondo
        XCTAssertNil(Stato.nonCoperto.color.fillToken)
        XCTAssertTrue(Stato.nonCoperto.dashed)
        // Verdict e pillole con gli stessi pieni
        XCTAssertEqual(Verdict.no(reason: "").fillToken, Tokens.noFill)
        XCTAssertEqual(Verdict.unsure(reason: "").fillToken, Tokens.condFill)
        XCTAssertEqual(Verdict.yes(reason: "").fillToken, Tokens.yesFill)
    }

    /// «ZTL non attiva» è UN token (RispostaFinale.stateOff, oggi verde); «Fuori dalla ZTL» è grigio, mai verde
    func testStateOffIsOneTokenAndOutsideIsGrey() {
        XCTAssertEqual(Stato.ztlNonAttiva.color, RispostaFinale.stateOff)
        XCTAssertEqual(Tono.spento.resolved, RispostaFinale.stateOff)
        XCTAssertEqual(Stato.ztlNonAttiva.color.fillToken, RispostaFinale.stateOff.fillToken)
        XCTAssertEqual(RispostaFinale.stateOff, .verde, "regola di Ledion: oggi verde")
        XCTAssertEqual(Stato.ztlNonAttiva.color.fillToken, Tokens.yesFill)
        XCTAssertEqual(Stato.fuoriZTL.color.fillToken, Tokens.greyFill)
        XCTAssertNotEqual(Stato.fuoriZTL.color.fillToken, Tokens.yesFill)
        XCTAssertEqual(Stato.fuoriZTL.color.inkToken, Tokens.greyInk)
        // Forma diversa anche quando il colore è lo stesso: ZTL non attiva (cerchio con trattino) ed Entra pure (spunta)
        XCTAssertNotEqual(Stato.ztlNonAttiva.symbol, Stato.entraPure.symbol)
    }

    /// Il rosso del marchio solo nel logo: i pulsanti sono chiari su Notte e scuri su Giorno, mai rossi; il pannello LED
    /// è bianco caldo, né rosso né verde
    func testBrandRedNeverOnButtonsAndNeutralLED() {
        for night in [false, true] {
            let p = Tokens.primary.hex(night: night)
            XCTAssertNotEqual(p, Tokens.brand.day)
            XCTAssertNotEqual(p, Tokens.noFill.day)
            XCTAssertGreaterThanOrEqual(Contrast.ratio(p, Tokens.ground.hex(night: night)), 4.5, "pulsante sul fondo")
        }
        XCTAssertGreaterThan(Contrast.luminance(Tokens.primary.night), Contrast.luminance(Tokens.primary.day), "chiaro di notte")
        let led = Tokens.led.day
        let r = Int(led >> 16 & 0xFF), g = Int(led >> 8 & 0xFF), b = Int(led & 0xFF)
        XCTAssertTrue(r > 200 && g > 200 && b > 150, "bianco caldo, non un colore della risposta")
        XCTAssertNotEqual(Home2Answer.Mood.red.hex, Tokens.led.day)
    }

    /// La mappa usa i token della risposta (S-Mappa): tratteggio 12/8, righe con passo 12, tratto 5, opacità 55%
    func testMapUsesTheTokens() {
        XCTAssertEqual(MapTheme.red.fillLight, Tokens.noFill.day)
        XCTAssertEqual(MapTheme.yellow.fillLight, Tokens.condFill.day)
        XCTAssertEqual(MapTheme.green.fillLight, Tokens.yesFill.day)
        XCTAssertEqual(MapTheme.dash(.closed), [12, 8])
        XCTAssertEqual(MapTheme.hatchPitch, 12)
        XCTAssertEqual(MapTheme.hatchWidth, 5)
        XCTAssertEqual(MapTheme.hatchOpacity(dark: false), 0.55)
        XCTAssertEqual(MapTheme.badge(.closed).fill, Tokens.noFill.day)
    }

    // MARK: Accessibilità

    /// VoiceOver legge la risposta in un colpo solo: parola, zona, frase e per chi, in quest'ordine
    func testVoiceOverReadsTheAnswerAtOnce() {
        let s = RispostaBlock.spoken(title: "Non entrare", line: "Firenze · Settore B · fino alle 20:00", detail: "Varco Via Guelfa a 40 m, davanti a te.",
                                     extra: "Per Golf diesel Euro 5, adesso")
        XCTAssertEqual(s, "Non entrare. Firenze · Settore B · fino alle 20:00. Varco Via Guelfa a 40 m, davanti a te. Per Golf diesel Euro 5, adesso.")
        XCTAssertEqual(RispostaBlock.spoken(title: "Entra pure", line: nil, detail: " ", extra: nil), "Entra pure.")
    }

    /// I bersagli di tocco (S-Tipo): mai sotto 44 punti; in auto 64 e 76
    func testTouchTargets() {
        XCTAssertGreaterThanOrEqual(Theme.Target.minimum, 44)
        XCTAssertGreaterThanOrEqual(Theme.Target.standard, 52)
        XCTAssertGreaterThanOrEqual(Theme.Target.car, 64)
        XCTAssertGreaterThanOrEqual(Theme.Target.carPrimary, 76)
    }

    /// Le parole della risposta vanno a capo solo fra una parola e l'altra; una parola più larga della riga si stringe
    /// nella riga, mai spezzata
    func testWordsWrapOnlyBetweenWords() {
        XCTAssertEqual(AnswerWords.words("Non entrare").count, 2)
        let sizes = [CGSize(width: 100, height: 50), CGSize(width: 250, height: 50), CGSize(width: 400, height: 50)]
        let f = WordFlow.arrange(sizes, width: 300, gap: 10, lineGap: -8)
        XCTAssertEqual(f.count, 3)
        for r in f { XCTAssertLessThanOrEqual(r.maxX, 300.5) }
        XCTAssertEqual(f[0].minY, 0)
        XCTAssertGreaterThan(f[1].minY, 0, "la seconda parola va a capo intera")
        XCTAssertGreaterThan(f[2].minY, f[1].minY)
        XCTAssertEqual(f[2].width, 300, "la parola troppo lunga ha la riga intera e si stringe")
        // Due parole corte sulla stessa riga
        let g = WordFlow.arrange([CGSize(width: 80, height: 40), CGSize(width: 90, height: 40)], width: 300, gap: 10, lineGap: 0)
        XCTAssertEqual(g[1].minY, 0)
        XCTAssertEqual(g[1].minX, 90)
    }

    /// Dynamic Type fino ad AX5: la parola più lunga di ogni risposta, in ogni lingua, sta nella riga di un iPhone da
    /// 375 punti stringendosi al massimo fino a RispostaBlock.minScale (misurata con il carattere di sistema nero, più
    /// largo di Titillium: il conto è prudente)
    func testLongestAnswerWordFitsAtAX5() throws {
        let ax5 = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)
        let size = UIFontMetrics(forTextStyle: .largeTitle).scaledValue(for: 40, compatibleWith: ax5)
        XCTAssertGreaterThan(size, 40, "la parola cresce con il Dynamic Type")
        let font = UIFont.systemFont(ofSize: size, weight: .black)
        let width: CGFloat = 375 - 32 - 40
        let dir = Self.root.appendingPathComponent("Resources/Localizations")
        var checked = 0
        for lang in ["it", "de", "fr", "es", "nl", "pl", "zh-Hans"] {
            let text = try String(contentsOf: dir.appendingPathComponent("\(lang).lproj/Localizable.strings"), encoding: .utf8)
            for word in AnswerWord.allCases {
                let key = "\"\(word.key.replacingOccurrences(of: "\"", with: "\\\""))\" = \""
                guard let r = text.range(of: key) else { XCTFail("\(lang): manca «\(word.key)»"); continue }
                let value = String(text[r.upperBound...].prefix { $0 != "\"" })
                for w in AnswerWords.words(value) {
                    let wide = (w as NSString).size(withAttributes: [.font: font]).width
                    XCTAssertLessThanOrEqual(wide * RispostaBlock.minScale, width, "\(lang) «\(w)» ad AX5: \(Int(wide)) punti")
                    checked += 1
                }
            }
        }
        XCTAssertGreaterThan(checked, 50)
    }

    // MARK: Il pannello LED

    /// Il testo del pannello viene dal motore, mai dalla risposta: «ZTL ATTIVA» anche per chi è ammesso (la riga accanto
    /// lo spiega); fuori dalla ZTL e fuori copertura nessun pannello
    func testLEDTextAndCaption() throws {
        let city = SampleData.florence
        let zone = try XCTUnwrap(city.zones.first)
        let place = Place(name: "Prova", address: "", location: city.center)
        let hits = [(city: city, zone: zone)]
        let yesOn = Home2Answer(PlaceCheck(place: place, hits: hits, answer: Answer(verdict: .yes(reason: ""), gatesOn: true, nextChange: nil)), now: Date())
        if yesOn.stato == .entraPure {
            XCTAssertEqual(yesOn.ledText, "ZTL ATTIVA")
            XCTAssertEqual(yesOn.ledCaption, L("The panel will say ZTL ATTIVA: that's fine for you."))
        }
        XCTAssertFalse(yesOn.ledText.contains("ESENTE"))
        let noOn = Home2Answer(PlaceCheck(place: place, hits: hits, answer: Answer(verdict: .no(reason: ""), gatesOn: true, nextChange: nil)), now: Date())
        XCTAssertEqual(noOn.ledText, "ZTL ATTIVA")
        XCTAssertEqual(noOn.ledCaption, L("This is how you'll see it at the gate."))
        XCTAssertTrue(noOn.showsPanel)
        let off = Home2Answer(PlaceCheck(place: place, hits: hits, answer: Answer(verdict: .yes(reason: ""), gatesOn: false, nextChange: nil)), now: Date())
        XCTAssertEqual(off.ledText, "ZTL NON ATTIVA")
        let outside = Home2Answer(PlaceCheck(place: place, hits: [], answer: nil, covered: true), now: Date())
        XCTAssertEqual(outside.stato, .fuoriZTL)
        XCTAssertFalse(outside.showsPanel)
        let uncovered = Home2Answer(PlaceCheck(place: place, hits: [], answer: nil, covered: false), now: Date())
        XCTAssertFalse(uncovered.showsPanel)
    }
}
