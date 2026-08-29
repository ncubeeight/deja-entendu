import Foundation

/// A photo that's been OCR'd into text via Vision — mirrors ImportedRecording's
/// shape (a permanent local copy plus the language tagged up front), with
/// recognizedText standing in for a transcript.
struct ImportedImageSample: Identifiable, Codable, Hashable {
    let id: UUID
    let originalFilename: String
    let localURL: URL          // copy of the photo inside our own container
    let recognizedText: String
    let importedAt: Date
    let language: SupportedLanguage
}
