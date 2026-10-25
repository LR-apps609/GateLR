import AVFoundation

/// La voce per le indicazioni: la migliore installata nella lingua dei testi dell'app
/// (Premium → Avanzata → base), mai le voci «di fantasia». Le voci migliori si scaricano in
/// Impostazioni → Accessibilità → Contenuto letto ad alta voce → Voci (es. Italiano → Alice Premium).
enum SpeechVoice {
    // AVSpeechSynthesisVoice.speechVoices() è lento (anche un secondo): si chiama una volta sola, in sottofondo,
    // e si rifà solo quando iOS dice che le voci installate sono cambiate. Prima si chiamava due volte a ogni
    // frase e a ogni disegno della pagina Account, sul thread principale.
    private static let lock = NSLock()
    private static var cached: (key: String, voice: AVSpeechSynthesisVoice?)?
    private static let watcher: NSObjectProtocol = NotificationCenter.default.addObserver(
        forName: AVSpeechSynthesizer.availableVoicesDidChangeNotification, object: nil, queue: nil) { _ in
            SpeechVoice.lock.lock(); SpeechVoice.cached = nil; SpeechVoice.lock.unlock()
            SpeechVoice.prepare()
        }

    /// La lingua dei testi che GateLR sta mostrando (it, de, fr, es, nl, pl, zh-Hans, en) con il paese più naturale
    static var language: String {
        switch Bundle.main.preferredLocalizations.first ?? "en" {
        case "it": "it-IT"
        case "de": "de-DE"
        case "fr": "fr-FR"
        case "es": "es-ES"
        case "nl": "nl-NL"
        case "pl": "pl-PL"
        case "zh-Hans": "zh-CN"
        default: Locale.preferredLanguages.first(where: { $0.hasPrefix("en") }) ?? "en-GB"
        }
    }

    /// Sceglie la voce in sottofondo, così la prima frase e la pagina Account non aspettano
    static func prepare() {
        DispatchQueue.global(qos: .utility).async { _ = SpeechVoice.best() }
    }

    static func best() -> AVSpeechSynthesisVoice? {
        _ = watcher
        let lang = language
        lock.lock()
        let hit = cached
        lock.unlock()
        if let hit, hit.key == lang { return hit.voice }
        let prefix = String(lang.prefix(2))
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { v in
            v.language.hasPrefix(prefix) && !v.voiceTraits.contains(.isNoveltyVoice)
                && !v.identifier.lowercased().contains("eloquence")
        }
        let chosen = voices.max { a, b in
            if a.quality != b.quality { return a.quality.rawValue < b.quality.rawValue }
            return (a.language == lang ? 1 : 0) < (b.language == lang ? 1 : 0)   // a parità: prima it-IT, de-DE…
        } ?? AVSpeechSynthesisVoice(language: lang)
        lock.lock(); cached = (lang, chosen); lock.unlock()
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

    /// Come onlyBasicVoice, ma calcolato fuori dal thread principale (per le pagine)
    static func onlyBasicVoiceAsync() async -> Bool {
        await Task.detached(priority: .utility) { SpeechVoice.onlyBasicVoice }.value
    }
}

/// La sessione audio della voce: attivarla e spegnerla può bloccare per centinaia di millisecondi
/// (di più se un'altra app o una chiamata ha l'audio), quindi si fa su una coda tutta sua, in ordine,
/// mai sul thread principale.
enum VoiceSession {
    private static let queue = DispatchQueue(label: "it.ledion.GateLR.voice", qos: .userInitiated)

    /// Voce che abbassa la musica e il navigatore mentre parla
    static func configure() {
        queue.async {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .voicePrompt,
                                                             options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
        }
    }

    static func activate() {
        queue.async { try? AVAudioSession.sharedInstance().setActive(true) }
    }

    /// La musica e il navigatore tornano al volume normale
    static func deactivate() {
        queue.async { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
    }
}
