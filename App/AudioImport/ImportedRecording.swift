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
    }
}
