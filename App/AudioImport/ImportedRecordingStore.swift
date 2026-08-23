import Foundation

/// Persists imported recordings to a JSON file in the app's own container —
/// the same pattern as VocabularyStore. Without this, recordings only lived
/// in VoiceMemoImportView's in-memory @State: gone on relaunch, and
/// invisible to Home's "Continue listening" section, which has no other
/// way to see them.
enum ImportedRecordingStore {
    private static let fileName = "recordings.json"

    private static func fileURL() throws -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent(fileName)
    }

    static func load() -> [ImportedRecording] {
        guard
            let url = try? fileURL(),
            let data = try? Data(contentsOf: url),
            let entries = try? JSONDecoder().decode([ImportedRecording].self, from: data)
        else { return [] }
        return entries
    }

    static func save(_ entries: [ImportedRecording]) {
        guard let url = try? fileURL(), let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
