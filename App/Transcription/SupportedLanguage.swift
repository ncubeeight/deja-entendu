import Foundation
import NaturalLanguage

/// Every language the app can tag a Sample, term or dictionary with. Three
/// kinds, all read through `allCases`:
/// - Built-ins (below): hand-tuned locales, tokenizer languages and names.
/// - Discovered: languages iOS reports support for (speech transcription,
///   photo text, Translate, on-device model, read-aloud voices) that aren't
///   built in, found at
///   launch by LanguageDiscovery and stored in DiscoveredLanguageStore — so
///   a language Apple adds later shows up without an app update.
/// - Custom: languages the user added by connecting a dictionary in a
///   language nothing else lists (CustomLanguageStore), e.g. Navajo.
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
    static let spanishLatinAmerica = SupportedLanguage(builtIn: "spanishLatinAmerica")
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
    /// Built in because NavajoKit (see NavajoSupport) supplies word meanings
    /// and read-aloud that no Apple framework offers. Keeps the raw value
    /// "Other language…" → "Navajo" used to create, so Samples and terms
    /// already tagged Navajo stay tagged. Still counts as `isCustom` — Apple
    /// has no speech, photo-text or model support for it.
    static let navajo = SupportedLanguage(builtIn: "custom:navajo")

    static let builtIns: [SupportedLanguage] = [
        .chineseTraditional,
        .chineseSimplified,
        .cantoneseTraditional,
        .cantoneseSimplified,
        .japanese,
        .german,
        .french,
        .spanish,
        .spanishLatinAmerica,
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
        .arabic,
        .navajo
    ]

    /// Built-in languages plus any the user added by connecting a
    /// dictionary in a language not listed above (see CustomLanguageStore) —
    /// e.g. Navajo. Read fresh each time so a newly added language shows up
    /// in every picker/Settings list immediately.
    static var allCases: [SupportedLanguage] {
        builtIns + DiscoveredLanguageStore.load() + CustomLanguageStore.load()
    }

    /// nil for a raw value that's neither built in nor a registered custom
    /// language, so stale values in persisted settings are ignored.
    init?(rawValue: String) {
        if let builtIn = Self.builtIns.first(where: { $0.rawValue == rawValue }) {
            self = builtIn
        } else if CustomLanguageStore.name(forRawValue: rawValue) != nil
                    || DiscoveredLanguageStore.record(forRawValue: rawValue) != nil {
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

    var isDiscovered: Bool { rawValue.hasPrefix(DiscoveredLanguageStore.prefix) }

    /// True for languages written right to left (Arabic, Hebrew, Persian,
    /// Urdu, ...), going by the locale's script.
    var isRightToLeft: Bool {
        Locale.Language(identifier: locale.identifier(.bcp47)).characterDirection == .rightToLeft
    }

    /// Language code + script, from the maximal identifier — e.g. both
    /// "zh-TW" and "zh-Hant" give "zh-Hant", "fr-FR" gives "fr-Latn". Used
    /// to match a language against what Apple's frameworks report, keeping
    /// Traditional and Simplified Chinese distinct while ignoring region.
    static func scriptKey(forIdentifier identifier: String) -> String {
        let maximal = Locale.Language(identifier: Locale.Language(identifier: identifier).maximalIdentifier)
        return "\(maximal.languageCode?.identifier ?? "")-\(maximal.script?.identifier ?? "")"
    }

    var scriptKey: String { Self.scriptKey(forIdentifier: locale.identifier(.bcp47)) }

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
        // Spain vs Latin America, split the same way as the Chinese and
        // Cantonese pairs so each drives its own speech voice and
        // transcription model. Mexico stands in for Latin America: es-419
        // has no synthesis voice or SpeechTranscriber model of its own,
        // while es-MX has both and is the region Apple's own Latin
        // American voices are tagged with.
        case .spanish:
            Locale(identifier: "es-ES")
        case .spanishLatinAmerica:
            Locale(identifier: "es-MX")
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
            Locale(identifier: DiscoveredLanguageStore.record(forRawValue: rawValue)?.localeIdentifier ?? "und")
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
        case .spanishLatinAmerica: .spanish
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
        default:
            // NLLanguage is a raw-string type keyed by language code; for a
            // discovered language that NaturalLanguage doesn't know, the
            // tokenizer treats it as undetermined, same as the cases above.
            if isDiscovered, let code = locale.language.languageCode?.identifier {
                NLLanguage(rawValue: code)
            } else {
                .undetermined
            }
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
        case .spanish: "Spanish (Spain)"
        case .spanishLatinAmerica: "Spanish (Latin America)"
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
        case .navajo: "Navajo"
        default:
            DiscoveredLanguageStore.record(forRawValue: rawValue)?.name
                ?? CustomLanguageStore.name(forRawValue: rawValue)
                ?? rawValue
        }
    }

    /// Name for a dictionary pack row. Packs are per base language (both
    /// Spanish variants share one), so the region qualifier is dropped
    /// rather than implying the pack is Spain-only.
    var dictionaryPackDisplayName: String {
        self == .spanish ? "Spanish" : displayName
    }

    /// Languages the Translation framework can fetch an on-device pack for,
    /// as last reported by LanguageAvailability (see LanguageDiscovery).
    /// Spanish appears once since both variants share the same pack — see
    /// hasDictionaryPack. Falls back to the list below until the first
    /// refresh has run.
    static var translationDictionaryLanguages: [SupportedLanguage] {
        let reported = DiscoveredLanguageStore.dictionaryPackLanguages()
        return reported.isEmpty ? fallbackTranslationDictionaryLanguages : reported
    }

    /// The packs Apple's Translate app offered on iOS 26, shown before
    /// LanguageDiscovery has reported the device's own list.
    static let fallbackTranslationDictionaryLanguages: [SupportedLanguage] = [
        .arabic, .chineseSimplified, .chineseTraditional, .dutch, .english,
        .french, .hindi, .indonesian, .italian, .korean, .polish, .portuguese,
        .russian, .spanish, .thai, .turkish, .ukrainian, .vietnamese
    ]

    /// Matched by language code rather than list membership so Latin
    /// American Spanish counts as covered by the one Spanish pack.
    var hasDictionaryPack: Bool {
        Self.translationDictionaryLanguages.contains {
            $0.locale.language.languageCode == locale.language.languageCode
        }
    }
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

    /// Skips records that are now built in (Navajo, added this way before
    /// it was built in) so they aren't listed twice.
    static func load() -> [SupportedLanguage] {
        let builtIn = Set(SupportedLanguage.builtIns.map(\.rawValue))
        return records()
            .filter { !builtIn.contains($0.rawValue) }
            .map { SupportedLanguage(customRawValue: $0.rawValue) }
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

/// Languages iOS supports that aren't built in, found by LanguageDiscovery
/// (see SupportedLanguage). Add-only: a language Apple stops reporting
/// stays listed so Samples and terms tagged with it keep a valid language.
/// New ones are never turned on automatically — they appear switched off in
/// Settings' "Languages shown on import".
enum DiscoveredLanguageStore {
    static let prefix = "apple:"
    private static let defaultsKey = "discoveredLanguagesJSON"
    private static let packsKey = "dictionaryPackLanguageRawValues"

    struct Record: Codable, Equatable {
        let rawValue: String
        let localeIdentifier: String
        let name: String
    }

    static func records() -> [Record] {
        guard
            let data = UserDefaults.standard.data(forKey: defaultsKey),
            let records = try? JSONDecoder().decode([Record].self, from: data)
        else { return [] }
        return records
    }

    static func load() -> [SupportedLanguage] {
        records().map { SupportedLanguage(customRawValue: $0.rawValue) }
    }

    static func record(forRawValue rawValue: String) -> Record? {
        guard rawValue.hasPrefix(prefix) else { return nil }
        return records().first(where: { $0.rawValue == rawValue })
    }

    /// Appends any records not already stored; returns whether anything
    /// was added.
    @discardableResult
    static func add(_ new: [Record]) -> Bool {
        var all = records()
        let known = Set(all.map(\.rawValue))
        let additions = new.filter { !known.contains($0.rawValue) }
        guard !additions.isEmpty else { return false }
        all += additions
        if let data = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
        return true
    }

    static func dictionaryPackLanguages() -> [SupportedLanguage] {
        (UserDefaults.standard.stringArray(forKey: packsKey) ?? []).compactMap(SupportedLanguage.init(rawValue:))
    }

    static func setDictionaryPackLanguages(_ languages: [SupportedLanguage]) {
        let raw = languages.map(\.rawValue)
        guard raw != UserDefaults.standard.stringArray(forKey: packsKey) else { return }
        UserDefaults.standard.set(raw, forKey: packsKey)
    }
}

extension SupportedLanguage {
    /// For DiscoveredLanguageStore and CustomLanguageStore only.
    fileprivate init(customRawValue: String) {
        self.rawValue = customRawValue
    }
}
