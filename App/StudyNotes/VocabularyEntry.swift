import Foundation

/// A single term added to the vocabulary list, typically shared in from
/// Translate (or any app that shares plain text) via the Share Extension.
struct VocabularyEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let text: String
    let addedAt: Date

    // Known when the term came from a tapped transcript word (the recording
    // it came from is already tagged with a language); nil for terms that
    // arrive without one, like a manual entry or a Share Extension text drop
    // — those still ask the flashcard generator to infer the language.
    var language: SupportedLanguage? = nil

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
