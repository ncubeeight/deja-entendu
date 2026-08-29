import Foundation

/// A type-erased wrapper over the three kinds of imported sample, so the
/// Samples tab (and Home's "Continue studying") can list, filter, and
/// navigate from them uniformly.
enum AnySample: Identifiable, Hashable {
    case audio(ImportedRecording)
    case text(ImportedTextSample)
    case image(ImportedImageSample)

    var id: UUID {
        switch self {
        case .audio(let recording): recording.id
        case .text(let sample): sample.id
        case .image(let sample): sample.id
        }
    }

    var kind: SampleKind {
        switch self {
        case .audio: .audio
        case .text: .text
        case .image: .image
        }
    }

    var title: String {
        switch self {
        case .audio(let recording): recording.originalFilename
        case .text(let sample): sample.title
        case .image(let sample): sample.originalFilename
        }
    }

    var language: SupportedLanguage {
        switch self {
        case .audio(let recording): recording.language
        case .text(let sample): sample.language
        case .image(let sample): sample.language
        }
    }

    var importedAt: Date {
        switch self {
        case .audio(let recording): recording.importedAt
        case .text(let sample): sample.importedAt
        case .image(let sample): sample.importedAt
        }
    }

    var subtitle: String {
        "\(language.displayName) · \(importedAt.formatted(date: .abbreviated, time: .shortened))"
    }

    /// What TranscriptionRunnerView needs to run this sample through the
    /// shared transcript pipeline — audio needs actual transcription, text
    /// and image samples already have their text resolved.
    var runnerInput: SampleInput {
        switch self {
        case .audio(let recording):
            .audio(recording)
        case .text(let sample):
            .readyText(title: sample.title, text: sample.body, language: sample.language)
        case .image(let sample):
            .readyText(title: sample.originalFilename, text: sample.recognizedText, language: sample.language)
        }
    }
}
