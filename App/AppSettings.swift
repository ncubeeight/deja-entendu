import SwiftUI

/// Small persisted app preferences, backed by UserDefaults via @AppStorage
/// in the views that read/write them. Centralizing the keys and the
/// encode/decode helpers here keeps every call site in sync.
enum AppSettings {
    static let enabledLanguagesKey = "enabledLanguagesRawValues"
    static let colorSchemeKey = "preferredColorSchemeRawValue"

    /// Decodes the comma-joined raw value @AppStorage stores. An empty or
    /// unparseable value means "everything enabled" — the default before
    /// the user has ever visited Settings.
    static func languages(from rawValue: String) -> Set<SupportedLanguage> {
        guard !rawValue.isEmpty else { return Set(SupportedLanguage.allCases) }
        let set = Set(rawValue.split(separator: ",").compactMap { SupportedLanguage(rawValue: String($0)) })
        return set.isEmpty ? Set(SupportedLanguage.allCases) : set
    }

    static func rawValue(from languages: Set<SupportedLanguage>) -> String {
        languages.map(\.rawValue).joined(separator: ",")
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
