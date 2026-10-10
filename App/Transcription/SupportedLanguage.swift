import Foundation
import NaturalLanguage

/// Languages the transcription pipeline can detect and transcribe. Adding a
/// new language means adding a case here — everything else (the picker,
/// transcription, study notes) reads from this list.
struct SupportedLanguage: Hashable, Sendable, Codable, CaseIterable {
    let rawValue: String

    private init(builtIn rawValue: String) {
        self.rawValue = rawValue
    }

    static let chineseTraditional = SupportedLanguage(builtIn: "chineseTraditional")
    static let chineseSimplified = SupportedLanguage(builtIn: "chineseSimplified")
    static let cantoneseTraditional = SupportedLanguage(builtIn: "cantoneseTraditional")
    static let cantoneseSimplified = SupportedLanguage(builtIn: "cantoneseSimplified")
    static let japanese = SupportedLanguage(builtIn: "japanese")
    static let german = SupportedLanguage(builtIn: "german")
    static let french = SupportedLanguage(builtIn: "french")
    static let spanish = SupportedLanguage(builtIn: "spanish")
    static let thai = SupportedLanguage(builtIn: "thai")
    static let korean = SupportedLanguage(builtIn: "korean")
    static let vietnamese = SupportedLanguage(builtIn: "vietnamese")
    static let hindi = SupportedLanguage(builtIn: "hindi")
    static let tamil = SupportedLanguage(builtIn: "tamil")
    static let gujarati = SupportedLanguage(builtIn: "gujarati")
    static let italian = SupportedLanguage(builtIn: "italian")
    static let portuguese = SupportedLanguage(builtIn: "portuguese")
    static let danish = SupportedLanguage(builtIn: "danish")
    static let dutch = SupportedLanguage(builtIn: "dutch")
    static let norwegian = SupportedLanguage(builtIn: "norwegian")
    static let swedish = SupportedLanguage(builtIn: "swedish")
    static let turkish = SupportedLanguage(builtIn: "turkish")
    static let english = SupportedLanguage(builtIn: "english")
    static let bengali = SupportedLanguage(builtIn: "bengali")
    static let punjabi = SupportedLanguage(builtIn: "punjabi")
    static let urdu = SupportedLanguage(builtIn: "urdu")
    static let greek = SupportedLanguage(builtIn: "greek")
    static let hebrew = SupportedLanguage(builtIn: "hebrew")
    static let russian = SupportedLanguage(builtIn: "russian")
    static let ukrainian = SupportedLanguage(builtIn: "ukrainian")
    static let indonesian = SupportedLanguage(builtIn: "indonesian")
    static let marathi = SupportedLanguage(builtIn: "marathi")
    static let swahili = SupportedLanguage(builtIn: "swahili")
    static let tagalog = SupportedLanguage(builtIn: "tagalog")
    static let yoruba = SupportedLanguage(builtIn: "yoruba")
    static let quechua = SupportedLanguage(builtIn: "quechua")
    static let telugu = SupportedLanguage(builtIn: "telugu")
    static let kannada = SupportedLanguage(builtIn: "kannada")
    static let amharic = SupportedLanguage(builtIn: "amharic")
    static let finnish = SupportedLanguage(builtIn: "finnish")
    static let estonian = SupportedLanguage(builtIn: "estonian")
    static let polish = SupportedLanguage(builtIn: "polish")
    static let arabic = SupportedLanguage(builtIn: "arabic")

    static let builtIns: [SupportedLanguage] = [
        .chineseTraditional,
        .chineseSimplified,
        .cantoneseTraditional,
        .cantoneseSimplified,
        .japanese,
        .german,
        .french,
        .spanish,
        .thai,
        .korean,
        .vietnamese,
        .hindi,
        .tamil,
        .gujarati,
        .italian,
        .portuguese,
        .danish,
        .dutch,
        .norwegian,
        .swedish,
        .turkish,
        .english,
        .bengali,
        .punjabi,
        .urdu,
        .greek,
        .hebrew,
        .russian,
        .ukrainian,
        .indonesian,
        .marathi,
        .swahili,
        .tagalog,
        .yoruba,
        .quechua,
        .telugu,
        .kannada,
        .amharic,
        .finnish,
        .estonian,
        .polish,
        .arabic
    ]

    /// Built-in languages plus any the user added by connecting a
    /// dictionary in a language not listed above (see CustomLanguageStore) —
    /// e.g. Navajo. Read fresh each time so a newly added language shows up
    /// in every picker/Settings list immediately.
    static var allCases: [SupportedLanguage] {
        builtIns + CustomLanguageStore.load()
    }

    /// nil for a raw value that's neither built in nor a registered custom
    /// language, so stale values in persisted settings are ignored.
    init?(rawValue: String) {
        if let builtIn = Self.builtIns.first(where: { $0.rawValue == rawValue }) {
            self = builtIn
        } else if CustomLanguageStore.name(forRawValue: rawValue) != nil {
            self.rawValue = rawValue
        } else {
            return nil
        }
    }

    /// Encoded as its bare raw-value string, same as when this was a
    /// String-backed enum, so previously saved files still decode. Decoding
    /// doesn't require the language to still be registered — a saved term
    /// tagged with a language later removed keeps its tag.
    init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var isCustom: Bool { rawValue.hasPrefix(CustomLanguageStore.prefix) }

    var locale: Locale {
        switch self {
        case .chineseTraditional:
            Locale(components: .init(languageCode: .chinese, script: .hanTraditional, languageRegion: .taiwan))
        case .chineseSimplified:
            Locale(components: .init(languageCode: .chinese, script: .hanSimplified, languageRegion: .chinaMainland))
        // Cantonese as spoken in Hong Kong (Traditional) vs Guangdong
        // (Simplified). SpeechTranscriber resolves these to its zh-HK and
        // yue-CN models respectively (both Cantonese — zh-HK is Apple's
        // identifier for Hong Kong Cantonese, not Mandarin), and Vision to
        // yue-Hant / yue-Hans. Taishanese has no speech, OCR, or voice
        // support in any Apple framework as of iOS 26, so isn't listed.
        case .cantoneseTraditional:
            Locale(identifier: "yue-Hant-HK")
        case .cantoneseSimplified:
            Locale(identifier: "yue-Hans-CN")
        case .japanese:
            Locale(identifier: "ja-JP")
        case .german:
            Locale(identifier: "de-DE")
        case .french:
            Locale(identifier: "fr-FR")
        case .spanish:
            Locale(identifier: "es-ES")
        case .thai:
            Locale(identifier: "th-TH")
        case .korean:
            Locale(identifier: "ko-KR")
        case .vietnamese:
            Locale(identifier: "vi-VN")
        case .hindi:
            Locale(identifier: "hi-IN")
        case .tamil:
            Locale(identifier: "ta-IN")
        case .gujarati:
            Locale(identifier: "gu-IN")
        case .italian:
            Locale(identifier: "it-IT")
        case .portuguese:
            Locale(identifier: "pt-PT")
        case .danish:
            Locale(identifier: "da-DK")
        case .dutch:
            Locale(identifier: "nl-NL")
        case .norwegian:
            Locale(identifier: "nb-NO")
        case .swedish:
            Locale(identifier: "sv-SE")
        case .turkish:
            Locale(identifier: "tr-TR")
        case .english:
            Locale(identifier: "en-US")
        case .bengali:
            Locale(identifier: "bn-IN")
        case .punjabi:
            Locale(identifier: "pa-IN")
        case .urdu:
            Locale(identifier: "ur-PK")
        case .greek:
            Locale(identifier: "el-GR")
        case .hebrew:
            Locale(identifier: "he-IL")
        case .russian:
            Locale(identifier: "ru-RU")
        case .ukrainian:
            Locale(identifier: "uk-UA")
        case .indonesian:
            Locale(identifier: "id-ID")
        case .marathi:
            Locale(identifier: "mr-IN")
        case .swahili:
            Locale(identifier: "sw-KE")
        case .tagalog:
            Locale(identifier: "tl-PH")
        case .yoruba:
            Locale(identifier: "yo-NG")
        case .quechua:
            Locale(identifier: "qu-PE")
        case .telugu:
            Locale(identifier: "te-IN")
        case .kannada:
            Locale(identifier: "kn-IN")
        case .amharic:
            Locale(identifier: "am-ET")
        case .finnish:
            Locale(identifier: "fi-FI")
        case .estonian:
            Locale(identifier: "et-EE")
        case .polish:
            Locale(identifier: "pl-PL")
        case .arabic:
            Locale(identifier: "ar-SA")
        default:
            Locale(identifier: "und")
        }
    }

    /// For NLTokenizer — telling it the language up front gives more
    /// reliable word/sentence segmentation than auto-detection, especially
    /// for Chinese/Japanese where there's no whitespace to fall back on.
    /// Swahili, Tagalog, Yoruba, Quechua, and Estonian have no NLLanguage
    /// constant at all (checked the full list in the SDK header, not just a
    /// naming mismatch) — they fall back to .undetermined, Apple's own value
    /// for exactly this case, which uses generic script/whitespace-based
    /// segmentation. Since all five are Latin-script, space-delimited
    /// languages, this should still segment reasonably, just without the
    /// language-specific tuning the other cases get.
    /// Cantonese has no NLLanguage constant either, but unlike those five it
    /// has no spaces to fall back on — the Chinese tokenizer for the same
    /// script segments it far better than .undetermined would, though
    /// colloquial-only characters (唔, 嘅, 咗, ...) may split less cleanly.
    var nlLanguage: NLLanguage {
        switch self {
        case .chineseTraditional: .traditionalChinese
        case .chineseSimplified: .simplifiedChinese
        case .cantoneseTraditional: .traditionalChinese
        case .cantoneseSimplified: .simplifiedChinese
        case .japanese: .japanese
        case .german: .german
        case .french: .french
        case .spanish: .spanish
        case .thai: .thai
        case .korean: .korean
        case .vietnamese: .vietnamese
        case .hindi: .hindi
        case .tamil: .tamil
        case .gujarati: .gujarati
        case .italian: .italian
        case .portuguese: .portuguese
        case .danish: .danish
        case .dutch: .dutch
        case .norwegian: .norwegian
        case .swedish: .swedish
        case .turkish: .turkish
        case .english: .english
        case .bengali: .bengali
        case .punjabi: .punjabi
        case .urdu: .urdu
        case .greek: .greek
        case .hebrew: .hebrew
        case .russian: .russian
        case .ukrainian: .ukrainian
        case .indonesian: .indonesian
        case .marathi: .marathi
        case .swahili: .undetermined
        case .tagalog: .undetermined
        case .yoruba: .undetermined
        case .quechua: .undetermined
        case .telugu: .telugu
        case .kannada: .kannada
        case .amharic: .amharic
        case .finnish: .finnish
        case .estonian: .undetermined
        case .polish: .polish
        case .arabic: .arabic
        default: .undetermined
        }
    }

    var displayName: String {
        switch self {
        case .chineseTraditional: "Chinese (Traditional)"
        case .chineseSimplified: "Chinese (Simplified)"
        case .cantoneseTraditional: "Cantonese (Traditional)"
        case .cantoneseSimplified: "Cantonese (Simplified)"
        case .japanese: "Japanese"
        case .german: "German"
        case .french: "French"
        case .spanish: "Spanish"
        case .thai: "Thai"
        case .korean: "Korean"
        case .vietnamese: "Vietnamese"
        case .hindi: "Hindi"
        case .tamil: "Tamil"
        case .gujarati: "Gujarati"
        case .italian: "Italian"
        case .portuguese: "Portuguese"
        case .danish: "Danish"
        case .dutch: "Dutch"
        case .norwegian: "Norwegian"
        case .swedish: "Swedish"
        case .turkish: "Turkish"
        case .english: "English"
        case .bengali: "Bengali"
        case .punjabi: "Punjabi"
        case .urdu: "Urdu"
        case .greek: "Greek"
        case .hebrew: "Hebrew"
        case .russian: "Russian"
        case .ukrainian: "Ukrainian"
        case .indonesian: "Indonesian"
        case .marathi: "Marathi"
        case .swahili: "Swahili"
        case .tagalog: "Tagalog"
        case .yoruba: "Yoruba"
        case .quechua: "Quechua"
        case .telugu: "Telugu"
        case .kannada: "Kannada"
        case .amharic: "Amharic"
        case .finnish: "Finnish"
        case .estonian: "Estonian"
        case .polish: "Polish"
        case .arabic: "Arabic"
        default: CustomLanguageStore.name(forRawValue: rawValue) ?? rawValue
        }
    }

    /// The languages Apple's Translate app currently offers as downloadable,
    /// on-device dictionary/translation packs (its Languages tab, iOS 26).
    /// Distinct from the full transcription list above — this is Apple's
    /// smaller, curated set that the Translation framework can actually
    /// fetch language data for.
    static let translationDictionaryLanguages: [SupportedLanguage] = [
        .arabic, .chineseSimplified, .chineseTraditional, .dutch, .english,
        .french, .hindi, .indonesian, .italian, .korean, .polish, .portuguese,
        .russian, .spanish, .thai, .turkish, .ukrainian, .vietnamese
    ]
}

/// Languages the user added by connecting a dictionary file in a language
/// the app doesn't list (see ConnectLocalDictionaryView). They behave like
/// built-in languages everywhere a language is picked or toggled, except
/// that speech/vision/on-device-model support is whatever the OS offers for
/// an unrecognized locale — i.e. none.
enum CustomLanguageStore {
    static let prefix = "custom:"
    private static let defaultsKey = "customLanguagesJSON"

    private struct Record: Codable {
        let rawValue: String
        let name: String
    }

    private static func records() -> [Record] {
        guard
            let data = UserDefaults.standard.data(forKey: defaultsKey),
            let records = try? JSONDecoder().decode([Record].self, from: data)
        else { return [] }
        return records
    }

    static func load() -> [SupportedLanguage] {
        records().map { SupportedLanguage(customRawValue: $0.rawValue) }
    }

    static func name(forRawValue rawValue: String) -> String? {
        records().first(where: { $0.rawValue == rawValue })?.name
    }

    /// Returns the language for `name`, reusing a built-in or an already
    /// registered custom language with the same (case-insensitive) name
    /// rather than creating a duplicate.
    static func register(name: String) -> SupportedLanguage {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = SupportedLanguage.allCases.first(where: { $0.displayName.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return existing
        }
        let slug = trimmed.lowercased().filter { $0.isLetter || $0.isNumber }
        let rawValue = prefix + (slug.isEmpty ? UUID().uuidString : slug)
        var all = records()
        all.append(Record(rawValue: rawValue, name: trimmed))
        if let data = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
        return SupportedLanguage(customRawValue: rawValue)
    }
}

private extension SupportedLanguage {
    init(customRawValue: String) {
        self.rawValue = customRawValue
    }
}
