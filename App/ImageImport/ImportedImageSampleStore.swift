import Foundation

/// Persists OCR'd image samples the same way ImportedRecordingStore
/// persists recordings — a JSON file in the app's own container.
enum ImportedImageSampleStore {
    private static let fileName = "imageSamples.json"

    private static func fileURL() throws -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent(fileName)
    }

    static func load() -> [ImportedImageSample] {
        guard
            let url = try? fileURL(),
            let data = try? Data(contentsOf: url),
            let entries = try? JSONDecoder().decode([ImportedImageSample].self, from: data)
        else { return [] }
        return entries
    }

    static func save(_ entries: [ImportedImageSample]) {
        guard let url = try? fileURL(), let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
