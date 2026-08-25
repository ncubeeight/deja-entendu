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
        }
    }

    /// For NLTokenizer — telling it the language up front gives more
    /// reliable word/sentence segmentation than auto-detection, especially
    /// for Chinese/Japanese where there's no whitespace to fall back on.
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
        }
    }
}
