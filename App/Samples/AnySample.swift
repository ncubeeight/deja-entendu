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

    /// The user's own name for this sample (see SampleTitleStore), or the
    /// default one.
    var title: String {
        SampleTitleStore.title(for: id) ?? defaultTitle
    }

    /// The name a sample gets before the user renames it.
    var defaultTitle: String {
        switch self {
        case .audio(let recording): recording.displayTitle
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

    /// Just the language — the import timestamp used to be appended here
    /// too, but a user importing their own sample already knows roughly
    /// when they did it, so it was showing information nobody needed to
    /// read every row. importedAt is kept around for sort order elsewhere.
    var subtitle: String {
        language.displayName
    }

    /// What TranscriptionRunnerView needs to run this sample through the
    /// shared transcript pipeline — audio needs actual transcription, text
    /// and image samples already have their text resolved.
    var runnerInput: SampleInput {
        switch self {
        case .audio(let recording):
            .audio(recording)
        case .text(let sample):
            .readyText(title: defaultTitle, text: sample.body, language: sample.language)
        case .image(let sample):
            .readyText(title: defaultTitle, text: sample.recognizedText, language: sample.language)
        }
    }
}

/// Names the user gave their samples, keyed by sample id. Kept apart from
/// the three sample stores so renaming needs no change to their saved
/// formats (or to the Share Extension, which writes them too). Views that
/// show titles watch `key` with @AppStorage so a rename shows up at once.
enum SampleTitleStore {
    static let key = "sampleCustomTitlesJSON"

    static func load(from json: String? = UserDefaults.standard.string(forKey: key)) -> [UUID: String] {
        guard let data = json?.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return Dictionary(uniqueKeysWithValues: decoded.compactMap { key, value in
            UUID(uuidString: key).map { ($0, value) }
        })
    }

    static func title(for id: UUID) -> String? {
        load()[id]
    }

    /// Saves a new name; an empty one goes back to the default title.
    static func setTitle(_ title: String?, for id: UUID) {
        var titles = load()
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        titles[id] = trimmed.isEmpty ? nil : trimmed
        let encoded = Dictionary(uniqueKeysWithValues: titles.map { ($0.key.uuidString, $0.value) })
        if let data = try? JSONEncoder().encode(encoded), let json = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(json, forKey: key)
        }
    }
}
