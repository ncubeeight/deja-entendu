import Foundation

enum AudioIngestionError: LocalizedError {
    case couldNotAccessSecurityScopedResource
    case couldNotCopyFile(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .couldNotAccessSecurityScopedResource:
            return "iOS didn't grant access to that file. Try picking it again."
        case .couldNotCopyFile(let underlying):
            return "Couldn't copy the recording into the app: \(underlying.localizedDescription)"
        }
    }
}

/// Handles pulling a file the user picked (which lives outside our sandbox,
/// and is only briefly accessible) into a permanent local copy we own.
enum AudioIngestion {

    static func copyIntoAppContainer(
        from sourceURL: URL,
        source: ImportedRecording.Source,
        language: SupportedLanguage
    ) throws -> ImportedRecording {

        // Files handed to us via .fileImporter are "security-scoped" — we must
        // bracket access, and the URL becomes unusable once we stop accessing it.
        let didStartAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer { if didStartAccessing { sourceURL.stopAccessingSecurityScopedResource() } }

        guard didStartAccessing || FileManager.default.isReadableFile(atPath: sourceURL.path) else {
            throw AudioIngestionError.couldNotAccessSecurityScopedResource
        }

        let recordingID = UUID()
        let destinationDirectory = try recordingsDirectory()
        let destinationURL = destinationDirectory
            .appendingPathComponent(recordingID.uuidString)
            .appendingPathExtension(sourceURL.pathExtension.isEmpty ? "m4a" : sourceURL.pathExtension)

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        } catch {
            throw AudioIngestionError.couldNotCopyFile(underlying: error)
        }

        return ImportedRecording(
            id: recordingID,
            originalFilename: sourceURL.lastPathComponent,
            localURL: destinationURL,
            importedAt: .now,
            source: source,
            language: language
        )
    }

    private static func recordingsDirectory() throws -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("ImportedRecordings", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
}
