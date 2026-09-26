import Foundation
import Speech
import AVFoundation

enum TranscriptionError: LocalizedError {
    case localeNotSupported(SupportedLanguage)
    case assetInstallFailed(SupportedLanguage, String)
    case noResult

    var errorDescription: String? {
        switch self {
        case .localeNotSupported(let language):
            return "\(language.displayName) isn't available for on-device transcription on this device/OS version."
        case .assetInstallFailed(let language, let reason):
            return "Couldn't install the \(language.displayName) speech model: \(reason)"
        case .noResult:
            return "Transcription produced no result."
        }
    }
}

struct TranscriptSegment {
    let text: String
    let timeRange: CMTimeRange
}

struct TranscriptionResult {
    let fullText: String
    let segments: [TranscriptSegment]
}

/// Wraps SpeechAnalyzer/SpeechTranscriber for a caller-supplied language —
/// works identically whether the file was just recorded live or imported
/// from Voice Memos, both cases end up as a plain file URL by the time this runs.
actor SpeechTranscriberService {
    private let language: SupportedLanguage

    init(language: SupportedLanguage) {
        self.language = language
    }

    func transcribe(fileAt url: URL) async throws -> TranscriptionResult {
        // 1. Resolve to a locale SpeechTranscriber actually supports (falls
        //    back gracefully if e.g. only a broader locale variant is available).
        guard let resolvedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: language.locale) else {
            throw TranscriptionError.localeNotSupported(language)
        }

        let transcriber = SpeechTranscriber(locale: resolvedLocale, preset: .transcription)

        // 2. Make sure the on-device model assets for this locale are present.
        //    This may trigger a one-time network download; recognition itself
        //    runs fully on-device once assets are installed.
        try await ensureAssetsInstalled(for: transcriber, locale: resolvedLocale)

        // 3. Normalize the input file to something AVAudioFile opens reliably.
        let m4aURL = try await AudioTranscoder.ensureM4A(at: url)
        let audioFile = try AVAudioFile(forReading: m4aURL)

        // 4. Run the analyzer over the whole file.
        let analyzer = SpeechAnalyzer(modules: [transcriber])

        var segments: [TranscriptSegment] = []
        let resultsTask = Task {
            for try await result in transcriber.results {
                segments.append(
                    TranscriptSegment(
                        text: String(result.text.characters[...]),
                        timeRange: result.range
                    )
                )
            }
        }

        if let lastSample = try await analyzer.analyzeSequence(from: audioFile) {
            try await analyzer.finalizeAndFinish(through: lastSample)
        } else {
            try await analyzer.finalizeAndFinishThroughEndOfInput()
        }

        try await resultsTask.value

        guard !segments.isEmpty else { throw TranscriptionError.noResult }

        let fullText = segments.map(\.text).joined()
        return TranscriptionResult(fullText: fullText, segments: segments)
    }

    private func ensureAssetsInstalled(for transcriber: SpeechTranscriber, locale: Locale) async throws {
        do {
            await makeRoomForReservation(of: locale)
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await request.downloadAndInstall()
            }
            // If the request comes back nil, assets are already installed.
            SpeechLocaleUsage.markUsed(locale)
        } catch {
            throw TranscriptionError.assetInstallFailed(language, error.localizedDescription)
        }
    }

    /// Installing a speech model implicitly reserves its locale for this app,
    /// and the system caps reservations at AssetInventory.maximumReservedLocales
    /// (5 on iOS 26). Reservations persist across launches and app updates and
    /// are never released on their own — so every language ever transcribed
    /// keeps a slot, even after it's turned off in Settings, until the next
    /// install fails with "Too many allocated locales".
    ///
    /// Before reserving a new locale, release (1) any reserved locale whose
    /// language is no longer enabled in Settings, then (2) if still full —
    /// more than 5 languages enabled — the least recently transcribed ones.
    /// A released model may be purged by the system and re-downloaded the
    /// next time that language is used; nothing the user saved is affected.
    private func makeRoomForReservation(of locale: Locale) async {
        let target = locale.identifier(.bcp47)
        let reserved = await AssetInventory.reservedLocales
        guard !reserved.contains(where: { $0.identifier(.bcp47) == target }) else { return }

        let enabled = AppSettings.languages(
            from: UserDefaults.standard.string(forKey: AppSettings.enabledLanguagesKey) ?? ""
        )
        var enabledIdentifiers: Set<String> = [target]
        for language in enabled {
            if let resolved = await SpeechTranscriber.supportedLocale(equivalentTo: language.locale) {
                enabledIdentifiers.insert(resolved.identifier(.bcp47))
            }
        }

        var stillReserved: [Locale] = []
        for reservedLocale in reserved {
            if enabledIdentifiers.contains(reservedLocale.identifier(.bcp47)) {
                stillReserved.append(reservedLocale)
            } else {
                await AssetInventory.release(reservedLocale: reservedLocale)
            }
        }

        let overflow = stillReserved.count - AssetInventory.maximumReservedLocales + 1
        guard overflow > 0 else { return }
        let lastUsed = SpeechLocaleUsage.lastUsedDates()
        let leastRecentFirst = stillReserved.sorted {
            (lastUsed[$0.identifier(.bcp47)] ?? .distantPast) < (lastUsed[$1.identifier(.bcp47)] ?? .distantPast)
        }
        for reservedLocale in leastRecentFirst.prefix(overflow) {
            await AssetInventory.release(reservedLocale: reservedLocale)
        }
    }
}

/// When each speech locale was last transcribed with, so that when more
/// languages are enabled than the system's reservation cap allows, the
/// least recently used one gives up its slot rather than an arbitrary one.
private enum SpeechLocaleUsage {
    private static let key = "speechLocaleLastUsedDates"

    static func lastUsedDates() -> [String: Date] {
        let raw = UserDefaults.standard.dictionary(forKey: key) as? [String: Double] ?? [:]
        return raw.mapValues { Date(timeIntervalSince1970: $0) }
    }

    static func markUsed(_ locale: Locale) {
        var raw = UserDefaults.standard.dictionary(forKey: key) as? [String: Double] ?? [:]
        raw[locale.identifier(.bcp47)] = Date.now.timeIntervalSince1970
        UserDefaults.standard.set(raw, forKey: key)
    }
}
