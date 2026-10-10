import AVFoundation
import Observation

/// Speaks text aloud in a given language using the system's speech
/// synthesizer — shared by the flashcard and the Samples transcript so both
/// pick voices and configure audio the same way.
@Observable
final class TextSpeaker: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private(set) var isSpeaking = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Only meaningful when the language is known — without it we'd fall
    /// back to the system's default voice, which is available but not
    /// reliably correct, so that case is treated as "available" rather than
    /// blocked. When the language IS known, Apple's speech-synthesis voice
    /// catalog doesn't cover every language this app supports (e.g. no
    /// Gujarati voice exists as of this SDK, and a language added from a
    /// connected dictionary has no voice at all) — checked directly rather
    /// than assumed, since AVSpeechSynthesisVoice(language:) already
    /// returns nil gracefully for an unsupported locale instead of crashing.
    static func isVoiceAvailable(for language: SupportedLanguage?) -> Bool {
        guard let language else { return true }
        return AVSpeechSynthesisVoice(language: language.locale.identifier) != nil
    }

    func speak(_ text: String, language: SupportedLanguage?) {
        // The app never otherwise configures an audio session, so without
        // this the default session category honors the hardware Silent/Ring
        // switch — the speaker button would appear to do nothing on a
        // muted device even though synthesis itself succeeded.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)

        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        if let language {
            utterance.voice = AVSpeechSynthesisVoice(language: language.locale.identifier)
        }
        utterance.rate = SpeechPace.current.utteranceRate
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
}
