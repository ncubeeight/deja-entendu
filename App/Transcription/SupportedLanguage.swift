import Foundation
import NaturalLanguage

/// Languages the transcription pipeline can detect and transcribe. Adding a
/// new language means adding a case here — everything else (the picker,
/// transcription, study notes) reads from this list.
enum SupportedLanguage: String, CaseIterable, Sendable, Codable {
    case chineseTraditional
    case chineseSimplified
    case japanese
    case german
    case french
    case spanish
    case thai
    case korean
    case vietnamese
    case hindi
    case tamil
    case gujarati
    case italian
    case portuguese
    case danish
    case dutch
    case norwegian
    case swedish
    case turkish
    case english
    case bengali
    case punjabi
    case urdu
    case greek
    case hebrew
    case russian
    case ukrainian
    case indonesian
    case marathi
    case swahili
    case tagalog
    case yoruba
    case quechua
    case telugu
    case kannada
    case amharic

    var locale: Locale {
        switch self {
        case .chineseTraditional:
            Locale(components: .init(languageCode: .chinese, script: .hanTraditional, languageRegion: .taiwan))
        case .chineseSimplified:
            Locale(components: .init(languageCode: .chinese, script: .hanSimplified, languageRegion: .chinaMainland))
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
        }
    }

    /// For NLTokenizer — telling it the language up front gives more
    /// reliable word/sentence segmentation than auto-detection, especially
    /// for Chinese/Japanese where there's no whitespace to fall back on.
    /// Swahili, Tagalog, Yoruba, and Quechua have no NLLanguage constant at
    /// all (checked the full list in the SDK header, not just a naming
    /// mismatch) — they fall back to .undetermined, Apple's own value for
    /// exactly this case, which uses generic script/whitespace-based
    /// segmentation. Since all four are Latin-script, space-delimited
    /// languages, this should still segment reasonably, just without the
    /// language-specific tuning the other cases get.
    var nlLanguage: NLLanguage {
        switch self {
        case .chineseTraditional: .traditionalChinese
        case .chineseSimplified: .simplifiedChinese
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
        }
    }

    var displayName: String {
        switch self {
        case .chineseTraditional: "Chinese (Traditional)"
        case .chineseSimplified: "Chinese (Simplified)"
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
        }
    }
}
