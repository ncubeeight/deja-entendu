import Foundation

/// A term/definition pair the user has entered themselves — for vocabulary
/// an on-device model wouldn't reliably know (specialized industry jargon,
/// a personal glossary) or simply to have an authoritative answer instead
/// of a generated one. Looked up before/alongside FlashcardGenerator, and
/// available even on devices with no on-device model at all.
struct GlossaryEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let term: String
    let definition: String
    let language: SupportedLanguage
    let addedAt: Date
}
