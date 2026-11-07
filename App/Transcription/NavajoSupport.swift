import Foundation
import NavajoKit

/// Navajo (Diné bizaad) support from NavajoKit
/// (https://github.com/ncubeeight/navajokit-new, a fork of Daniel Gump's
/// https://gitlab.com/HullBreach/navajokit, CC BY-SA 4.0). No Apple
/// framework covers Navajo, so for the user's custom "Navajo" language this
/// supplies what Apple can't:
/// - word meanings from NavajoKit's lexicon, picked by its part-of-speech
///   tagger (the tooltip on a word in a Sample), and
/// - read-aloud, by spelling each syllable in IPA for an English voice.
/// Word chips need nothing extra — Apple's word tokenizer already splits
/// Navajo correctly, glottal stops included.
enum NavajoSupport {
    static func isNavajo(_ language: SupportedLanguage?) -> Bool {
        guard let language, language.isCustom else { return false }
        if language == .navajo { return true }
        let folded = language.displayName
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .filter(\.isLetter)
        return ["navajo", "dine", "dinebizaad", "navajodine"].contains(folded)
    }

    /// NavajoKit's lexicon spells the glottal stop with ʼ (U+02BC), but
    /// pasted or typed text often has ' or ’ instead.
    static func normalized(_ text: String) -> String {
        text.replacingOccurrences(of: "'", with: "\u{02BC}")
            .replacingOccurrences(of: "\u{2019}", with: "\u{02BC}")
    }

    /// A short English meaning for one Navajo word, or nil when the lexicon
    /// doesn't have it (callers fall back to the on-device model).
    static func gloss(forWord word: String) async -> String? {
        let token = normalized(word).trimmingCharacters(in: .punctuationCharacters.subtracting(["\u{02BC}"]).union(.whitespacesAndNewlines))
        guard !token.isEmpty else { return nil }
        return await NavajoEngine.shared.gloss(forToken: token)
    }

    /// The text with IPA pronunciation attached per syllable, for
    /// AVSpeechUtterance(attributedString:) with an English voice.
    static func pronunciation(for text: String) async -> NSAttributedString {
        await NavajoEngine.shared.pronunciation(for: normalized(text))
    }

    /// The voice NavajoKit's IPA is written for.
    static let voiceLanguage = "en-US"
}

/// Loads NavajoKit lazily, off the main thread, once: the lexicon (about
/// 11,000 words) and tagger take a few seconds to load. NavajoKit's
/// sentence-translation models live in the separate NavajoKitTransformer
/// library, which the app doesn't link, so they aren't bundled.
private actor NavajoEngine {
    static let shared = NavajoEngine()

    private var translator: NVTranslator?
    private var tagger: NVTagger?
    private let synthesizer = NVSpeechSynthesizer()

    func gloss(forToken token: String) async -> String? {
        let translator = translator ?? NVTranslator()
        self.translator = translator
        let tagger = tagger ?? NVTagger()
        self.tagger = tagger

        let tagged = await tagger.tag([token])
        guard let english = translator.translate(words: tagged).first?.translation?.english,
              !english.isEmpty
        else { return nil }
        return english
    }

    func pronunciation(for text: String) async -> NSAttributedString {
        await synthesizer.ipaEncode(text: text)
    }
}
