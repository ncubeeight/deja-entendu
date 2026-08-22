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
        try await ensureAssetsInstalled(for: transcriber)

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

    private func ensureAssetsInstalled(for transcriber: SpeechTranscriber) async throws {
        do {
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await request.downloadAndInstall()
            }
            // If the request comes back nil, assets are already installed.
        } catch {
            throw TranscriptionError.assetInstallFailed(language, error.localizedDescription)
        }
    }
}
