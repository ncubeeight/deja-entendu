import Foundation

/// Languages the transcription pipeline can detect and transcribe. Adding a
/// new language means adding a case here — everything else (detection,
/// transcription, pinyin gating, study notes) reads from this list.
enum SupportedLanguage: String, CaseIterable, Sendable {
    case chineseTaiwan
    case japanese
    case german
    case french

    var locale: Locale {
        switch self {
        case .chineseTaiwan:
            Locale(components: .init(languageCode: .chinese, script: .hanTraditional, languageRegion: .taiwan))
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
        case .chineseTaiwan: "Taiwanese Mandarin"
        case .japanese: "Japanese"
        case .german: "German"
        case .french: "French"
        }
    }

    /// Pinyin only makes sense for Chinese transcripts.
    var isChinese: Bool { self == .chineseTaiwan }
}
