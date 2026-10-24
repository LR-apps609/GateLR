import AVFoundation

/// La voce per le indicazioni: la migliore installata nella lingua dei testi dell'app
/// (Premium → Avanzata → base), mai le voci «di fantasia». Le voci migliori si scaricano in
/// Impostazioni → Accessibilità → Contenuto letto ad alta voce → Voci (es. Italiano → Alice Premium).
enum SpeechVoice {
    private static var cached: (key: String, voice: AVSpeechSynthesisVoice?)?

    /// La lingua dei testi che GateLR sta mostrando (it, de, en) con il paese più naturale
    static var language: String {
        switch Bundle.main.preferredLocalizations.first ?? "en" {
        case "it": "it-IT"
        case "de": "de-DE"
        default: Locale.preferredLanguages.first(where: { $0.hasPrefix("en") }) ?? "en-GB"
        }
    }

    static func best() -> AVSpeechSynthesisVoice? {
        let lang = language
        let installed = AVSpeechSynthesisVoice.speechVoices().count
        let key = "\(lang)|\(installed)"            // se scarichi una voce nuova, si ricalcola
        if let cached, cached.key == key { return cached.voice }
        let prefix = String(lang.prefix(2))
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { v in
            v.language.hasPrefix(prefix) && !v.voiceTraits.contains(.isNoveltyVoice)
                && !v.identifier.lowercased().contains("eloquence")
        }
        let chosen = voices.max { a, b in
            if a.quality != b.quality { return a.quality.rawValue < b.quality.rawValue }
            return (a.language == lang ? 1 : 0) < (b.language == lang ? 1 : 0)   // a parità: prima it-IT, de-DE…
        } ?? AVSpeechSynthesisVoice(language: lang)
        cached = (key, chosen)
        return chosen
    }

    /// Una frase pronta da dire: voce migliore, velocità naturale
    static func utterance(_ text: String, rate: Float = 1.0) -> AVSpeechUtterance {
        let u = AVSpeechUtterance(string: text)
        u.voice = best()
        u.rate = AVSpeechUtteranceDefaultSpeechRate * rate
        u.pitchMultiplier = 1.0
        return u
    }

    /// Vero se in questa lingua c'è solo la voce base (quella che pronuncia peggio)
    static var onlyBasicVoice: Bool { (best()?.quality ?? .default) == .default }
}
