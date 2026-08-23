import Foundation

/// Languages the transcription pipeline can detect and transcribe. Adding a
/// new language means adding a case here — everything else (the picker,
/// transcription, study notes) reads from this list.
enum SupportedLanguage: String, CaseIterable, Sendable, Codable {
    case chineseTraditional
    case chineseSimplified
    case japanese
    case german
    case french

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
        }
    }

    var displayName: String {
        switch self {
        case .chineseTraditional: "Chinese (Traditional)"
        case .chineseSimplified: "Chinese (Simplified)"
        case .japanese: "Japanese"
        case .german: "German"
        case .french: "French"
        }
    }
}
