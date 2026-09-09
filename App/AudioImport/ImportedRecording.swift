import Foundation

/// A recording that has been copied into the app's own sandbox,
/// whether it arrived via the Files importer or the Share Extension.
struct ImportedRecording: Identifiable, Codable, Hashable {
    let id: UUID
    let originalFilename: String
    let localURL: URL          // file inside our own container — safe to reopen anytime
    let importedAt: Date
    let source: Source
    let language: SupportedLanguage

    enum Source: String, Codable {
        case filesImporter   // picked via UIDocumentPicker / .fileImporter
        case shareExtension  // arrived via Voice Memos' Share Sheet
        case liveRecording   // recorded directly in-app (LiveRecordingView)
    }

    /// A short, source-specific label rather than the raw filename — the
    /// two main audio journeys (uploading an existing file vs. recording
    /// one in-app) are distinct enough to the user that they deserve a
    /// clear, consistent name instead of whatever the source file was
    /// called. Share Extension imports keep their real filename since
    /// they arrive from a specific named recording elsewhere (e.g. a
    /// Voice Memo), not a generic "upload" or "record" action.
    var displayTitle: String {
        switch source {
        case .filesImporter: "Uploaded Audio"
        case .liveRecording: "Live Audio"
        case .shareExtension: originalFilename
        }
    }
}
