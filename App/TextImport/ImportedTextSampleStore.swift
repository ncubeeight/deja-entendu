import Foundation

/// Persists pasted/typed text samples the same way ImportedRecordingStore
/// persists recordings — a JSON file in the app's own container.
enum ImportedTextSampleStore {
    private static let fileName = "textSamples.json"

    private static func fileURL() throws -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent(fileName)
    }

    static func load() -> [ImportedTextSample] {
        guard
            let url = try? fileURL(),
            let data = try? Data(contentsOf: url),
            let entries = try? JSONDecoder().decode([ImportedTextSample].self, from: data)
        else { return [] }
        return entries
    }

    static func save(_ entries: [ImportedTextSample]) {
        guard let url = try? fileURL(), let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
