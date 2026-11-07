import Foundation
import Speech
import Vision
import Translation
import FoundationModels
import AVFoundation

/// Asks iOS which languages its learning-relevant frameworks support and
/// records any the app doesn't already list (see DiscoveredLanguageStore),
/// so a language Apple adds later appears in Settings without an app
/// update. Also refreshes which languages have a downloadable Translate
/// dictionary pack.
///
/// Sources, in priority order for picking a language's locale:
/// SpeechTranscriber (audio Samples), Vision (photo text), Translation
/// (dictionary packs), the on-device model (study notes), then text-to-
/// speech voices last. A language Apple can only read aloud (Bulgarian,
/// Catalan, Croatian, ... as of iOS 26) still works for pasted-text
/// Samples, word lookup in your own glossary, and pronunciation, so it's
/// included too — just without transcription, photo text or study notes.
///
/// Discovery is add-only and never enables anything — new languages start
/// switched off in Settings' "Languages shown on import".
enum LanguageDiscovery {
    /// "Multiple languages", "undetermined", "no linguistic content".
    private static let excludedLanguageCodes: Set<String> = ["mul", "und", "zxx"]

    static func refresh() async {
        let speech = await SpeechTranscriber.supportedLocales.map { $0.identifier(.bcp47) }
        let vision: [String] = {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            return (try? request.supportedRecognitionLanguages()) ?? []
        }()
        let translationLanguages = await LanguageAvailability().supportedLanguages
        let translation = translationLanguages.map(\.maximalIdentifier)
        let model = SystemLanguageModel.default.supportedLanguages.map(\.maximalIdentifier)
        let voices = AVSpeechSynthesisVoice.speechVoices().map(\.language)

        DiscoveredLanguageStore.add(newRecords(from: speech + vision + translation + model + voices))
        DiscoveredLanguageStore.setDictionaryPackLanguages(packLanguages(for: translationLanguages))
    }

    /// One record per language code + script that nothing in the app
    /// already covers. `candidates` is in priority order, so the first
    /// identifier seen for a language (the SpeechTranscriber one, when
    /// there is one) becomes its locale — it's the one with a transcription
    /// model and usually a voice.
    private static func newRecords(from candidates: [String]) -> [DiscoveredLanguageStore.Record] {
        let english = Locale(identifier: "en")
        let existing = SupportedLanguage.allCases
        let existingKeys = Set(existing.map(\.scriptKey))
        // Names to fold dialects into: each language's own name plus its
        // base-language name (e.g. "Norwegian" and "Norwegian Bokmål").
        let existingNames: [String] = existing.flatMap { language -> [String] in
            let base = language.locale.language.languageCode.flatMap { english.localizedString(forLanguageCode: $0.identifier) }
            return [language.displayName, base].compactMap { $0 }
        }

        var chosen: [(key: String, code: String, identifier: String)] = []
        var seenKeys = existingKeys
        for identifier in candidates {
            let key = SupportedLanguage.scriptKey(forIdentifier: identifier)
            guard
                !seenKeys.contains(key),
                let code = Locale.Language(identifier: identifier).languageCode?.identifier,
                !excludedLanguageCodes.contains(code)
            else { continue }
            seenKeys.insert(key)
            chosen.append((key, code, identifier))
        }

        let codeCounts = Dictionary(chosen.map { ($0.code, 1) }, uniquingKeysWith: +)
        return chosen.compactMap { entry in
            guard let baseName = english.localizedString(forLanguageCode: entry.code) else { return nil }
            // "Arabic, Najdi" → Arabic; "Norwegian Nynorsk" → Norwegian.
            let isVariantOfExisting = existingNames.contains { name in
                baseName.caseInsensitiveCompare(name) == .orderedSame
                    || [",", " (", " "].contains { baseName.hasPrefix(name + $0) }
            }
            guard !isVariantOfExisting else { return nil }

            let name: String
            if codeCounts[entry.code, default: 0] > 1,
               let script = Locale.Language(identifier: entry.identifier).script?.identifier,
               let scriptName = english.localizedString(forScriptCode: script) {
                name = "\(baseName) (\(scriptName))"
            } else {
                name = baseName
            }
            return DiscoveredLanguageStore.Record(
                rawValue: DiscoveredLanguageStore.prefix + entry.key,
                localeIdentifier: Locale(identifier: entry.identifier).identifier(.bcp47),
                name: name
            )
        }
    }

    /// The app's languages that Translation can fetch a pack for, one per
    /// pack — both Spanish variants match "es", and the first (Spain, per
    /// builtIns order) stands for the shared pack.
    private static func packLanguages(for translationLanguages: [Locale.Language]) -> [SupportedLanguage] {
        let all = SupportedLanguage.allCases
        var seenKeys = Set<String>()
        return translationLanguages.compactMap { packLanguage in
            let key = SupportedLanguage.scriptKey(forIdentifier: packLanguage.maximalIdentifier)
            guard !seenKeys.contains(key) else { return nil }
            seenKeys.insert(key)
            return all.first { $0.scriptKey == key }
        }
    }
}
