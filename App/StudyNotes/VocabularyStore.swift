import Foundation

/// Persists the vocabulary list to a JSON file in the app's own container.
/// Small, local, no syncing — matches the rest of the app's on-device-only
/// design.
enum VocabularyStore {
    private static let fileName = "vocabulary.json"

    private static func fileURL() throws -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent(fileName)
    }

    static func load() -> [VocabularyEntry] {
        guard
            let url = try? fileURL(),
            let data = try? Data(contentsOf: url),
            let entries = try? JSONDecoder().decode([VocabularyEntry].self, from: data)
        else { return [] }
        return entries
    }

    static func save(_ entries: [VocabularyEntry]) {
        guard let url = try? fileURL(), let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
