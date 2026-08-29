import Foundation
import FoundationModels

@Generable
struct FlashcardDetails {
    @Guide(description: """
    A simple phonetic pronunciation guide using plain English spelling, not \
    IPA. It must sound out the term's ENTIRE original text from first \
    syllable to last — never a truncated stem, prefix, or shortened form. \
    e.g. for the 2-syllable term "Bonjour", 'boh-ZHOOR' (both syllables); \
    for the 3-syllable term "réfléchi", 'ray-flay-SHEE' (all three \
    syllables, not just 'ray-flay'). Every syllable of the original term \
    must be represented.
    """)
    var pronunciation: String

    @Guide(description: "A brief, natural English translation or definition of the term.")
    var translation: String

    @Guide(description: "A short, natural example sentence in the term's own language and script, using the term.")
    var exampleSentence: String

    @Guide(description: "An English translation of the example sentence.")
    var exampleTranslation: String
}

enum FlashcardError: LocalizedError {
    case modelUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .modelUnavailable(let reason):
            return "On-device flashcard details aren't available right now: \(reason)"
        }
    }
}

/// Apple's built-in Japanese reading dictionary — the same linguistic data
/// that powers kana input and system text-to-speech — gives a real,
/// dictionary-backed romaji reading for kanji. Far more reliable than
/// asking the on-device LLM to guess one: that guess was inconsistent and
/// sometimes Chinese-pinyin-flavored for kanji compounds (課題, correctly
/// "kadai", came back as "kah-dshah" and later "kah-DEE-shuh" from the
/// model — verified via a standalone script that CFStringTokenizer gets
/// this, and five other real compounds, exactly right).
enum JapaneseReading {
    static func romaji(for text: String) -> String? {
        let cfText = text as CFString
        let length = CFStringGetLength(cfText)
        guard length > 0 else { return nil }

        let locale = CFLocaleCreate(kCFAllocatorDefault, CFLocaleIdentifier(rawValue: "ja-JP" as CFString))
        let tokenizer = CFStringTokenizerCreate(
            kCFAllocatorDefault,
            cfText,
            CFRangeMake(0, length),
            kCFStringTokenizerUnitWordBoundary,
            locale
        )

        var result = ""
        var tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
        while !tokenType.isEmpty {
            if let transcription = CFStringTokenizerCopyCurrentTokenAttribute(tokenizer, kCFStringTokenizerAttributeLatinTranscription) {
                result += (transcription as! CFString) as String
            }
            tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
        }
        return result.isEmpty ? nil : result
    }
}

enum FlashcardGenerator {

    /// When the entry came from a tapped transcript word, `language` is
    /// already known from the recording it was tagged with — pass it so the
    /// model doesn't have to guess (a bare word like "commandera" can look
    /// like Spanish/Italian as easily as French, and got that wrong before
    /// this was threaded through). Entries without a known language (freeform
    /// text from Translate, manual entry) still ask the model to identify it.
    static func generateDetails(forTerm term: String, language: SupportedLanguage?) async throws -> FlashcardDetails {
        let model = SystemLanguageModel.default

        switch model.availability {
        case .available:
            break
        case .unavailable(let reason):
            throw FlashcardError.modelUnavailable(String(describing: reason))
        }

        let japaneseKanjiWarning = """
         Japanese kanji are visually identical to Chinese hanzi, but their \
        pronunciation is completely different — pronounce this using \
        authentic Japanese on'yomi/kun'yomi readings (Hepburn romaji, e.g. \
        課題 → 'ka-dai'), never Mandarin pinyin or Chinese-sounding \
        consonant clusters like 'zh', 'q', 'x', or 'dsh'.
        """

        let instructions: String
        if let language {
            instructions = """
            You are a compact language-learning dictionary. The user will give \
            you a word or short phrase in \(language.displayName) — treat that \
            as certain, do not second-guess or reinterpret it as another \
            language even if it also resembles a word in one. Produce a \
            pronunciation guide, a translation, and a short natural example \
            sentence in \(language.displayName) using the term — plus that \
            sentence's English translation. The pronunciation guide must \
            cover the term's full length, every syllable from start to \
            finish — never just a stem or the first part of a longer word.\
            \(language == .japanese ? japaneseKanjiWarning : "") \
            The example sentence must be written entirely in \(language.displayName), \
            in its native script, and must contain the term itself verbatim. \
            It is NOT the translation field — never write an English dictionary \
            definition or explanation there (e.g. for "library", writing \
            "A library is a building that houses books..." would be wrong — \
            write an actual \(language.displayName) sentence like "私は毎日図書館に \
            行きます" instead). Only exampleTranslation may be in English.
            """
        } else {
            instructions = """
            You are a compact language-learning dictionary. Given a word or \
            short phrase, first identify what language it's in, then produce \
            a pronunciation guide, a translation, and a short natural example \
            sentence using the term in that language — plus that sentence's \
            English translation. The pronunciation guide must cover the \
            term's full length, every syllable from start to finish — never \
            just a stem or the first part of a longer word.\
            \(japaneseKanjiWarning) \
            The example sentence must be written entirely in the term's own \
            language, in its native script, and must contain the term itself \
            verbatim. It is NOT the translation field — never write an \
            English dictionary definition or explanation there. Only \
            exampleTranslation may be in English.
            """
        }

        let session = LanguageModelSession(model: model, instructions: instructions)

        let response = try await session.respond(
            to: "Term: \(term)",
            generating: FlashcardDetails.self,
            options: GenerationOptions(maximumResponseTokens: 300)
        )

        var details = response.content
        if language == .japanese, let romaji = JapaneseReading.romaji(for: term) {
            details.pronunciation = romaji
        }
        return details
    }
}
