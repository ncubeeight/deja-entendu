import Foundation

/// Bridges files dropped by the Share Extension (which runs as a separate
/// process and can't talk to the main app directly) into the main app.
///
/// Both the main app target AND the Share Extension target must have the
/// SAME App Group capability enabled in Signing & Capabilities:
///   group.com.ncubeeight.dejaentendu
enum SharedContainer {

    private static let appGroupID = "group.com.ncubeeight.dejaentendu"

    static func inboxDirectory() -> URL? {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return nil
        }
        let inbox = container.appendingPathComponent("ShareInbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        return inbox
    }

    /// Called on app launch/foreground: lists anything the extension dropped
    /// off, without copying it in yet. The caller should ask which language
    /// this batch is in, then call `commitPendingFiles(_:language:)`.
    static func pendingFiles() -> [URL] {
        guard let inbox = inboxDirectory() else { return [] }
        return (try? FileManager.default.contentsOfDirectory(
            at: inbox, includingPropertiesForKeys: nil
        )) ?? []
    }

    /// Copies the given share-extension files into the app's own permanent
    /// storage tagged with `language`, then clears them from the inbox.
    static func commitPendingFiles(_ fileURLs: [URL], language: SupportedLanguage) -> [ImportedRecording] {
        var results: [ImportedRecording] = []
        for fileURL in fileURLs {
            do {
                let recording = try AudioIngestion.copyIntoAppContainer(
                    from: fileURL,
                    source: .shareExtension,
                    language: language
                )
                results.append(recording)
                try? FileManager.default.removeItem(at: fileURL)
            } catch {
                // Leave the file in the inbox to retry on next launch.
                continue
            }
        }
        return results
    }
}
