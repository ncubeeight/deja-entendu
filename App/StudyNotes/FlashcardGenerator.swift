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

/// The spelled-out pronunciation guide used to come only from the on-device
/// model, which guesses: in testing it gave "seh-er-beh" for cerveza (Spain),
/// "shen-yeh" for 谢谢 and "gah-mahn-sahm" for 감사합니다, often differently
/// on each run — so it didn't match what the system voice actually says.
/// Where Apple's own linguistic data has a reading, use that instead.
enum PronunciationGuide {
    /// A reading from the same kind of data the system voice reads from:
    /// Hepburn romaji for Japanese, pinyin with tone marks for Mandarin.
    /// nil for every other language, whose guide is the model's
    /// approximation.
    static func exact(for term: String, language: SupportedLanguage?) -> String? {
        switch language {
        case .japanese?:
            return JapaneseReading.romaji(for: term)
        case .chineseSimplified?, .chineseTraditional?:
            let pinyin = PinyinConverter.pinyinWithToneMarks(for: term)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return pinyin.isEmpty || pinyin == term ? nil : pinyin
        default:
            return nil
        }
    }

    /// The term spelled letter by letter in Latin letters (감사합니다 →
    /// gamsahabnida, спасибо → spasibo) — it follows the written text, not
    /// sound changes, but unlike the model's guess it's never made up. nil
    /// for terms already in Latin letters, and for scripts whose
    /// romanization misleads: Hebrew and Arabic (usually written without
    /// vowels, so שלום comes out "şlwm"), Thai and Lao (garbled), and
    /// Chinese characters outside Mandarin (Cantonese would get Mandarin
    /// readings).
    static func romanization(for term: String, language: SupportedLanguage?) -> String? {
        guard exact(for: term, language: language) == nil else { return nil }
        let misleadingScripts: [ClosedRange<UInt32>] = [
            0x0590...0x08FF,   // Hebrew, Arabic, Syriac, Thaana, …
            0xFB1D...0xFDFF,   // Hebrew and Arabic presentation forms
            0xFE70...0xFEFF,
            0x0E00...0x0EFF,   // Thai, Lao
            0x3040...0x30FF,   // kana
            0x3400...0x9FFF,   // CJK ideographs
            0xF900...0xFAFF,
            0x20000...0x2FFFF,
        ]
        guard !term.unicodeScalars.contains(where: { scalar in
            misleadingScripts.contains { $0.contains(scalar.value) }
        }) else { return nil }

        guard let latin = term.applyingTransform(.toLatin, reverse: false)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !latin.isEmpty, latin != term
        else { return nil }

        // Anything the transform couldn't convert stays in its own script;
        // a half-converted string is worse than none.
        let isLatin = latin.unicodeScalars.allSatisfy { scalar in
            !scalar.properties.isAlphabetic
                || scalar.value < 0x0250
                || (0x1E00...0x1EFF).contains(scalar.value)
        }
        return isLatin ? latin : nil
    }

    /// The model sometimes adds notes after the guide ("EYCH-HOHR-NCHEN —
    /// EYCH (stressed), …") or markdown bold; keep just the guide.
    static func cleaned(_ guide: String) -> String {
        var text = guide.replacingOccurrences(of: "*", with: "")
        for separator in [" — ", " – ", " (", "\n"] {
            if let range = text.range(of: separator) {
                text = String(text[..<range.lowerBound])
            }
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        return trimmed.isEmpty ? guide : trimmed
    }

    /// The region whose accent the system voice speaks, e.g. "Spain" for
    /// es-ES, so the model's guide aims at the same accent as the audio.
    static func voiceRegionName(for language: SupportedLanguage) -> String? {
        guard let region = language.locale.region?.identifier else { return nil }
        return Locale(identifier: "en").localizedString(forRegionCode: region)
    }

    /// Instructions shared by full flashcard generation and regenerating
    /// just the guide.
    static func modelInstructions(for language: SupportedLanguage) -> String {
        var text = """
        The pronunciation guide must cover the term's full length, every \
        syllable from start to finish — never just a stem or the first part \
        of a longer word. Write the stressed syllable in capitals. It must \
        match how Apple's \(language.locale.identifier(.bcp47)) text-to-speech \
        voice says the term
        """
        if let region = voiceRegionName(for: language) {
            text += ", in the accent of \(region)"
        }
        text += "."
        switch language {
        case .spanish:
            text += " In Spain, 'z' and 'c' before e/i sound like English 'th' (cerveza → thehr-BEH-thah), and 'v' sounds like 'b'."
        case .portuguese:
            text += " This is European Portuguese, not Brazilian: unstressed vowels are reduced or dropped, and final 'o' sounds like 'oo' (obrigado → oh-bree-GAH-doo)."
        default:
            break
        }
        return text
    }
}

@Generable
struct PronunciationOnly {
    @Guide(description: """
    A simple phonetic pronunciation guide using plain English spelling, not \
    IPA. It must sound out the term's ENTIRE original text from first \
    syllable to last — never a truncated stem, prefix, or shortened form. \
    Every syllable of the original term must be represented, and the \
    stressed syllable written in capitals.
    """)
    var pronunciation: String
}

enum FlashcardGenerator {

    /// A fresh guide for one term — for the flashcard's "try again" button
    /// when a saved guide doesn't match the audio.
    static func regeneratePronunciation(forTerm term: String, language: SupportedLanguage?) async throws -> String {
        if let exact = PronunciationGuide.exact(for: term, language: language) {
            return exact
        }
        let model = SystemLanguageModel.default
        if case .unavailable(let reason) = model.availability {
            throw FlashcardError.modelUnavailable(String(describing: reason))
        }
        var instructions = "You write pronunciation guides for language learners."
        if let language {
            instructions += " The term is in \(language.displayName) — treat that as certain. "
                + PronunciationGuide.modelInstructions(for: language)
        }
        let session = LanguageModelSession(model: model, instructions: instructions)
        let response = try await session.respond(
            to: "Term: \(term)",
            generating: PronunciationOnly.self,
            options: GenerationOptions(maximumResponseTokens: 80)
        )
        return PronunciationGuide.cleaned(response.content.pronunciation)
    }

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

        // Same problem as Japanese from the other direction: the model's
        // default for hanzi is Mandarin, both in how it sounds a term out
        // and in writing Standard Written Chinese example sentences.
        let cantoneseWarning = """
         This is Cantonese, not Mandarin — pronounce the term as it sounds \
        in Cantonese (e.g. 你好 → 'nay-HOH', 唔該 → 'm-GOY'), never with \
        Mandarin pinyin readings like 'nee-how'. Write the example sentence \
        in colloquial spoken Cantonese as a native speaker would text it \
        (using 係, 唔, 嘅, 咗, 喺 where natural), not Standard Written Chinese.
        """
        let isCantonese = language == .cantoneseTraditional || language == .cantoneseSimplified

        let instructions: String
        if let language {
            instructions = """
            You are a compact language-learning dictionary. The user will give \
            you a word or short phrase in \(language.displayName) — treat that \
            as certain, do not second-guess or reinterpret it as another \
            language even if it also resembles a word in one. Produce a \
            pronunciation guide, a translation, and a short natural example \
            sentence in \(language.displayName) using the term — plus that \
            sentence's English translation. \
            \(PronunciationGuide.modelInstructions(for: language))\
            \(language == .japanese ? japaneseKanjiWarning : "")\
            \(isCantonese ? cantoneseWarning : "") \
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
        if let exact = PronunciationGuide.exact(for: term, language: language) {
            details.pronunciation = exact
        } else {
            details.pronunciation = PronunciationGuide.cleaned(details.pronunciation)
        }
        return details
    }
}
