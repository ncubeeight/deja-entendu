import Foundation

/// A single term added to the vocabulary list, typically shared in from
/// Translate (or any app that shares plain text) via the Share Extension.
struct VocabularyEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let text: String
    let addedAt: Date

    // Generated on-device the first time the flashcard is opened, then
    // cached here so it isn't regenerated on every visit. Optional (and
    // decode-safe for entries persisted before these fields existed).
    var pronunciation: String?
    var translation: String?
    var exampleSentence: String?
    var exampleTranslation: String?

    var hasFlashcardDetails: Bool {
        pronunciation != nil && exampleSentence != nil
    }
}
