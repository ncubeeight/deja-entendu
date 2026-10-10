import SwiftUI
import AVFoundation

/// Small persisted app preferences, backed by UserDefaults via @AppStorage
/// in the views that read/write them. Centralizing the keys and the
/// encode/decode helpers here keeps every call site in sync.
enum AppSettings {
    static let enabledLanguagesKey = "enabledLanguagesRawValues"
    static let colorSchemeKey = "preferredColorSchemeRawValue"
    static let hasCompletedFirstHomeLaunchKey = "hasCompletedFirstHomeLaunch"
    static let defaultImportLanguageKey = "defaultImportLanguageRawValue"
    static let speechPaceKey = "speechPaceRawValue"

    /// Shown before the user has ever visited Settings. All 46 languages
    /// enabled by default read as overwhelming in the import picker — a
    /// small, broadly useful starter set makes the picker actionable
    /// immediately, while "Turn off languages you don't use" in Settings
    /// still hints there's a much bigger list underneath.
    static let defaultEnabledLanguages: Set<SupportedLanguage> = [
        .english, .french, .german, .chineseTraditional, .chineseSimplified, .japanese
    ]

    /// Decodes the comma-joined raw value @AppStorage stores. An empty or
    /// unparseable value falls back to defaultEnabledLanguages.
    static func languages(from rawValue: String) -> Set<SupportedLanguage> {
        guard !rawValue.isEmpty else { return defaultEnabledLanguages }
        let set = Set(rawValue.split(separator: ",").compactMap { SupportedLanguage(rawValue: String($0)) })
        return set.isEmpty ? defaultEnabledLanguages : set
    }

    static func rawValue(from languages: Set<SupportedLanguage>) -> String {
        languages.map(\.rawValue).joined(separator: ",")
    }

    /// The language of the most recently connected local dictionary (see
    /// ConnectLocalDictionaryView), used to pre-select new Sample imports
    /// so terms parse against the dictionary the user just connected
    /// without them having to re-pick it every time. Falls back to the
    /// first enabled language when nothing's connected, or that language
    /// has since been turned off in "Languages shown on import".
    static func preferredDefaultLanguage(enabledLanguages: [SupportedLanguage]) -> SupportedLanguage {
        if
            let raw = UserDefaults.standard.string(forKey: defaultImportLanguageKey),
            let language = SupportedLanguage(rawValue: raw),
            enabledLanguages.contains(language)
        {
            return language
        }
        return enabledLanguages.first ?? .chineseTraditional
    }
}

enum AppColorScheme: String, CaseIterable {
    case system
    case light
    case dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

/// How fast TextSpeaker reads text aloud — one global choice, applied to
/// every speak button (Samples transcript, word popover, flashcard) at the
/// moment it's tapped, so changing it anywhere affects all of them.
enum SpeechPace: String, CaseIterable {
    case slower
    case normal
    case faster

    /// The saved choice, read fresh rather than cached so a change made in
    /// Settings or a SpeechPaceMenu applies to the very next utterance.
    static var current: SpeechPace {
        UserDefaults.standard.string(forKey: AppSettings.speechPaceKey).flatMap(SpeechPace.init(rawValue:)) ?? .normal
    }

    /// AVSpeechUtterance.rate isn't a speed multiplier — it's a 0...1 scale
    /// with 0.5 as "normal". Values below were measured by synthesizing the
    /// same sentence to audio buffers (en/fr/zh/ja voices) and comparing
    /// durations: 0.59 plays ~1.5× as fast. The synthesizer can't go below
    /// ~0.56× however low the rate is set, so "slower" is simply the
    /// minimum, the closest available to half speed.
    var utteranceRate: Float {
        switch self {
        case .slower: return AVSpeechUtteranceMinimumSpeechRate
        case .normal: return AVSpeechUtteranceDefaultSpeechRate
        case .faster: return 0.59
        }
    }

    var displayName: String {
        switch self {
        case .slower: return "Slower"
        case .normal: return "Normal"
        case .faster: return "Faster"
        }
    }

    var systemImage: String {
        switch self {
        case .slower: return "tortoise.fill"
        case .normal: return "gauge.with.dots.needle.50percent"
        case .faster: return "hare.fill"
        }
    }
}
