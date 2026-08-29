import Foundation

/// A block of foreign-language text pasted or typed directly into the app —
/// no transcription step needed, it goes straight into the same
/// segmentation/study-notes pipeline a recording's transcript would.
struct ImportedTextSample: Identifiable, Codable, Hashable {
    let id: UUID
    let body: String
    let importedAt: Date
    let language: SupportedLanguage

    /// Shown in lists in place of a filename — the existing text sample
    /// naming convention doesn't have a user-entered title, so first line
    /// (or first ~40 characters) stands in for one.
    var title: String {
        let firstLine = body.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? body
        if firstLine.count <= 40 { return firstLine }
        return String(firstLine.prefix(40)) + "…"
    }
}
