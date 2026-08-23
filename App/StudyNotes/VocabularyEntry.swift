import Foundation

/// A single term added to the vocabulary list, typically shared in from
/// Translate (or any app that shares plain text) via the Share Extension.
struct VocabularyEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let text: String
    let addedAt: Date
}
